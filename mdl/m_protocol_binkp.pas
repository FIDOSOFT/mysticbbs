// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
Program BinkPoll;

// Need to include point and multi zones (same with tosser)

{$I M_OPS.PAS}

Uses
  DOS,
  m_Crypt,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_IO_Sockets,
  m_Protocol_Queue,
  bbs_Common;

Var
  bbsConfig : RecConfig;
  TempPath  : String;

Const
  M_NUL  = 0;
  M_ADR  = 1;
  M_PWD  = 2;
  M_FILE = 3;
  M_OK   = 4;
  M_EOB  = 5;
  M_GOT  = 6;
  M_ERR  = 7;
  M_BSY  = 8;
  M_GET  = 9;
  M_SKIP = 10;
  M_DATA = 255;

  BinkPMaxBufferSize = 30 * 1024;
  TempFileTime       = 1363944820;

Const
  BinkCmdStr : Array[0..10] of String[4] = (
    'NUL ',
    'ADR ',
    'PWD ',
    'FILE',
    'OK  ',
    'EOB ',
    'GOT ',
    'ERR ',
    'BSY ',
    'GET ',
    'SKIP'
  );

Type
  TBinkAuthState = (
    SendChallenge,
    SendWelcome,
    SendAddress,
    SendPassword,
    WaitAddress,
    WaitPassword,
    WaitPwdOK,
    AuthOK,
    AuthFailed
  );

  TBinkRxState = (
    RxNone,
    RxWaitFile,
    RxGetData,
    RxDone
  );

  TBinkTxState = (
    TxNone,
    TxNextFile,
    TxSendData,
    TxGetEOF,
    TxDone
  );

  TBinkFrameType = (
    Command,
    Data
  );

  TBinkP = Class
    SetPassword  : String;
    SetBlockSize : Word;
    SetTimeOut   : Word;
    SetOutPath   : String;

    Client       : TIOSocket;
    IsClient     : Boolean;
    UseMD5       : Boolean;
    ForceMD5     : Boolean;
    AuthState    : TBinkAuthState;
    TimeOut      : LongInt;
    TxState      : TBinkTxState;
    RxState      : TBinkRxState;
    RxFrameType  : TBinkFrameType;
    RxCommand    : Byte;
    RxBuffer     : Array[1..BinkPMaxBufferSize] of Char;
    RxBufSize    : LongInt;
    HaveHeader   : Boolean;
    NeedHeader   : Boolean;
    MD5Challenge : String;
    FileList     : TProtocolQueue;

    Constructor Create (Var C: TIOSocket; Var FL: TProtocolQueue; IsCli: Boolean; TOV: Word);
    Destructor  Destroy; Override;

    Procedure   RemoveFilesFromFLO (FN: String);
    Function    GetDataStr : String;
    Procedure   SendFrame     (CmdType: Byte; CmdData: String);
    Procedure   SendDataFrame (Var Buf; BufSize: Word);
    Procedure   DoFrameCheck;
    Function    DoAuthentication : Boolean;
    Procedure   DoTransfers;
  End;

Function GetStateStr (S: TBinkAuthState) : String;
Begin
  Case S of
    SendChallenge : Result := 'SendChallenge';
    SendWelcome   : Result := 'SendWelcome';
    SendAddress   : Result := 'SendAddress';
    SendPassword  : Result := 'SendPassword';
    WaitAddress   : Result := 'WaitAddress';
    WaitPassword  : Result := 'WaitPassword';
    WaitPwdOK     : Result := 'WaitPwdOK';
    AuthOK        : Result := 'AuthOK';
    AuthFailed    : Result := 'AuthFailed';
  Else
    Result := 'Unknown';
  End;
End;

Constructor TBinkP.Create (Var C: TIOSocket; Var FL: TProtocolQueue; IsCli: Boolean; TOV: Word);
Begin
  Inherited Create;

  SetTimeOut   := TOV;
  Client       := C;
  FileList     := FL;
  IsClient     := IsCli;
  UseMD5       := False;
  ForceMD5     := False;
  RxBufSize    := 0;
  RxState      := RxNone;
  TxState      := TxNone;
  TimeOut      := TimerSet(SetTimeout);
  NeedHeader   := True;
  HaveHeader   := False;
  MD5Challenge := '';
  AuthState    := SendWelcome;

  If Not IsClient and UseMD5 Then
    AuthState := SendChallenge;
End;

Destructor TBinkP.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TBinkP.RemoveFilesFromFLO (FN: String);
Var
  Str      : String;
  DirInfo  : SearchRec;
  OrigFile : Text;
  NewFile  : Text;
  Matched  : Boolean;
Begin
  // Scan all FLO files in outbound directory, and PRUNE them all.

  FindFirst (SetOutPath + '*.?lo', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    FileRename (SetOutPath + DirInfo.Name, TempPath + DirInfo.Name);

    Assign  (NewFile, SetOutPath + DirInfo.Name);
    ReWrite (NewFile);
    Append  (NewFile);

    Assign  (OrigFile, TempPath + DirInfo.Name);
    Reset   (OrigFile);

    While Not Eof (OrigFile) Do Begin
      ReadLn (OrigFile, Str);

      If (Str = '') or (Str[1] = '!') Then
        WriteLn (NewFile, Str)
      Else Begin
        Case Str[1] of
          '~',
          '#',
          '^'  : Matched := strUpper(FN) = strUpper(Copy(Str, 2, 255));
        Else
          Matched := (strUpper(FN) = strUpper(Str));
        End;

        If Not Matched Then
          WriteLn (NewFile, Str);
      End;
    End;

    Close (NewFile);
    Close (OrigFile);
    Erase (OrigFile);

    If FileByteSize(SetOutPath + DirInfo.Name) = 0 Then
      FileErase(SetOutPath + DirInfo.Name);

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Function TBinkP.GetDataStr : String;
Var
  SZ : Byte;
Begin
  If RxBufSize > 255 Then
    SZ := 255
  Else
    SZ := RxBufSize;

  Move (RxBuffer[1], Result[1], SZ);

  Result[0] := Char(SZ);
End;

Procedure TBinkP.SendFrame (CmdType: Byte; CmdData: String);
Var
  DataSize : Word;
Begin
  DataSize := (Length(CmdData) + 2) OR $8000;

  Client.BufWriteStr(Char(Hi(DataSize)) + Char(Lo(DataSize)) + Char(CmdType) + CmdData + #0);
  Client.BufFlush;

  WriteLn ('    S ' + BinkCmdStr[CmdType] + ' ' + CmdData);
  //WriteLn ('Put Command Frame (', BinkCmdStr[CmdType], ') Data: ', CmdData);
End;

Procedure TBinkP.SendDataFrame (Var Buf; BufSize: Word);
Var
  SendData : Array[1.. BinkPMaxBufferSize] of Char Absolute Buf;
  HiChar   : Char;
  LoChar   : Char;
Begin
  HiChar := Char(Hi(BufSize));
  LoChar := Char(Lo(BufSize));

  Client.BufFlush;

  Client.WriteBuf (HiChar, 1);
  Client.WriteBuf (LoChar, 1);
  Client.WriteBuf (SendData[1], BufSize);

  TimeOut := TimerSet(SetTimeOut);

//  WriteLn ('Put Data Frame (', BufSize, ')');
End;

Procedure TBinkP.DoFrameCheck;
Var
  CharHi : Char;
  CharLo : Char;
  InPos  : LongInt;
Begin
  If NeedHeader And Not HaveHeader And Client.DataWaiting Then Begin
    Client.ReadBuf (CharHi, 1);
    Client.ReadBuf (CharLo, 1);

    RxBufSize := (Word(CharHi) SHL 8) + Word(CharLo);

    If Byte(CharHi) AND $80 = 0 Then Begin
      RxCommand   := M_DATA;
      RxFrameType := Data;
    End Else Begin
      RxBufSize   := (RxBufSize AND ($8000 - 1)) - 1;
      RxFrameType := Command;

      Client.ReadBuf (RxCommand, 1);
    End;

    If RxBufSize > 0 Then
      For InPos := 1 to RxBufSize Do
        Client.ReadBuf(RxBuffer[InPos], 1);

    If Client.Connected Then Begin
      TimeOut    := TimerSet(SetTimeOut);
      NeedHeader := False;
      HaveHeader := True;
    End;

    Case RxFrameType of
//      Command : If (RxCommand = M_NUL) or (RxCommand = M_ERR) Then
//                  WriteLn ('    R ', BinkCmdStr[RxCommand], ' ', GetDataStr);
        Command : WriteLn ('    R ', BinkCmdStr[RxCommand], ' ', GetDataStr);
//      Data    : WriteLn ('Got Data Frame (Read ', InPos, ' of ', RxBufSize, ')');
    End;
  End;
End;

Function TBinkP.DoAuthentication;
Var
  Str   : String;
  Count : LongInt;
Begin
  //WriteLn ('Begin Authentication');

  Repeat
    DoFrameCheck;

    If Not Client.Connected or (TimerUp(TimeOut)) Then
      AuthState := AuthFailed
    Else
    If HaveHeader and (RxCommand = M_NUL) Then Begin
      // Eat MNUL and get another header but steal MD5 challenge
      // and anything else we want to parse from OPTs, etc

      NeedHeader := True;
      HaveHeader := False;

      Str   := GetDataStr;
      Count := Pos('MD5-', Str);

      If Count > 0 Then
        MD5Challenge := Copy(Str, Count + 4, 255);
    End;

//    WriteLn ('AuthState: ', GetStateStr(AuthState), ', HasHeader: ', HaveHeader, ' Data: ', GetDataStr);

    Case AuthState of
      SendChallenge : Begin  // Send MD5 digest
                      End;
      SendWelcome   : Begin
                        SendFrame (M_NUL, 'SYS ' + bbsConfig.BBSName);
                        SendFrame (M_NUL, 'ZYZ ' + bbsConfig.SysopName);
//                        SendFrame (M_NUL, 'LOC Philadelphia, PA');
                        SendFrame (M_NUL, 'VER Mystic/' + Copy(mysVersion, 1, 4) + ' binkp/1.0');

                        If IsClient Then
                          AuthState := SendAddress
                        Else
                          AuthState := WaitAddress;
                      End;

      SendAddress   : Begin
                        Str := '';

                        For Count := 1 to 30 Do
                          If strAddr2Str(bbsConfig.NetAddress[Count]) <> '0:0/0' Then Begin
                            If Str <> '' Then Str := Str + ' ';

                            Str := Str + strAddr2Str(bbsConfig.NetAddress[Count]);

                            If bbsConfig.NetDomain[Count] <> '' Then
                              Str := Str + '@' + bbsConfig.NetDomain[Count];
                          End;

                        SendFrame (M_ADR, Str);

                        AuthState := SendPassword;
                      End;
      SendPassword  : If HaveHeader Then Begin // wait for header to see if we support CRAMMD5
                        If UseMD5 And (MD5Challenge <> '') Then Begin
                          MD5Challenge := Digest2String(HMAC_MD5(String2Digest(MD5Challenge), SetPassword));

                          SendFrame (M_PWD, 'CRAM-MD5-' + MD5Challenge);
                        End Else
                          If ForceMD5 Then Begin
                            SendFrame (M_ERR, 'Required CRAM-MD5 authentication');

                            AuthState := AuthFailed;
                          End Else
                            SendFrame (M_PWD, SetPassword);

                        Client.BufFlush;

                        HaveHeader := False;
                        NeedHeader := True;

                        If AuthState <> AuthFailed Then
                          AuthState  := WaitPwdOK;
                      End;
      WaitAddress   : Begin
                        // get address
                        AuthState := WaitPassword;
                      End;
      WaitPassword  : ;
      WaitPwdOK     : If HaveHeader Then Begin
                        If RxCommand <> M_OK Then
                          AuthState := AuthFailed
                        Else
                          AuthState := AuthOK;
                      End;
    End;
  Until (AuthState = AuthOK) or (AuthState = AuthFailed);

  Result := AuthState = AuthOK;
End;

Procedure TBinkP.DoTransfers;
Var
  InFile  : File;
  OutFile : File;
  OutSize : LongInt;
  OutBuf  : Array[1..BinkPMaxBufferSize] of Byte;
  Str     : String;
  InFN    : String;
  InSize  : Cardinal;
  InPos   : Cardinal;
  InTime  : Cardinal;
  FSize   : Cardinal;
Begin
  //WriteLn ('Begin File Transfers');

  RxState    := RxWaitFile;
  TxState    := TxNextFile;
  TimeOut    := TimerSet(SetTimeOut);
  NeedHeader := True;
  HaveHeader := False;

  Repeat
    DoFrameCheck;

    // need to update states to handle getting FILE during an xfer
    // and what to do if the file frame goes past file size (fail/quit), etc

//    waitms(100);
//    writeln ('rxstate=', ord(rxstate), '  txstate=', ord(txstate), '  have header ', haveheader, '  need header ', needheader);

    Case RxState of
      RxWaitFile : If HaveHeader Then Begin
                     If RxFrameType = Data Then Begin
                       HaveHeader := False;
                       NeedHeader := True;

                       Continue;
                     End;

                     If RxCommand = M_FILE Then Begin
                       HaveHeader := False;
                       NeedHeader := True;

                       // translate filename, fix up file times

                       Str    := GetDataStr;
                       InFN   := strWordGet(1, Str, ' ');
                       InSize := strS2I(strWordGet(2, Str, ' '));
                       InTime := strS2I(strWordGet(3, Str, ' '));
                       InPos  := strS2I(strWordGet(4, Str, ' '));

                       If FileExist(bbsConfig.InBoundPath + InFN) Then Begin
                         FSize := FileByteSize(bbsConfig.InBoundPath + InFN);

                         // fix timestamp and escape filen

                         If FSize >= InSize Then Begin
                           SendFrame (M_SKIP, InFN + ' ' + strI2S(FSize) + ' ' + strI2S(InTime));

                           Continue;
                         End Else Begin
                           SendFrame (M_GET, InFN + ' ' + strI2S(FSize) + ' ' + strI2S(InTime));

                           InPos := FSize;
                         End;
                       End;

                       Assign (InFile, bbsConfig.InBoundPath + InFN);
                       Reset  (InFile, 1);

                       If IoResult <> 0 Then ReWrite (InFile, 1);

                       Seek (InFile, InPos);

                       RxState := RxGetData;
                     End Else
                     If RxCommand = M_EOB Then Begin
                       NeedHeader := True;
                       HaveHeader := False;
                       RxState    := RxDone;
                     End;
                   End;
      RxGetData  : If HaveHeader And (RxFrameType = Data) Then Begin
                     BlockWrite (InFile, RxBuffer[1], RxBufSize);

                     Inc (InPos, RxBufSize);

                     HaveHeader := False;
                     NeedHeader := True;

                     If InPos = InSize Then Begin
                       // fix time, escape filename

                       Close     (InFile);
                       SendFrame (M_GOT, InFN + ' ' + strI2S(InSize) + ' ' + strI2S(InTime));

                       RxState := RxWaitFile;
                     End;
                   End;
    End;

//    DoFrameCheck;

    Case TxState of
      TxGetEOF   : Begin
                     If HaveHeader Then
                       If RxCommand = M_GOT Then Begin
                         FileList.QData[FileList.QPos].Status := QueueSuccess;

                         FileErase          (FileList.QData[FileList.QPos].FilePath + FileList.QData[FileList.QPos].FileName);
                         RemoveFilesFromFLO (FileList.QData[FileList.QPos].FilePath + FileList.QData[FileList.QPos].FileName);

                         HaveHeader := False;
                         NeedHeader := True;
                         TxState    := TxNextFile;
                       End;
                   End;
      TxNextFile : If FileList.Next Then Begin
                     Assign (OutFile, FileList.QData[FileList.QPos].FilePath + FileList.QData[FileList.QPos].FileName);
                     Reset  (OutFile, 1);

                     If IoResult <> 0 Then Continue;

                     // need to escape filename here and fix file time
                     SendFrame (M_FILE, FileList.QData[FileList.QPos].FileName + ' ' + strI2S(FileList.QData[FileList.QPos].FileSize) + ' ' + strI2S(TempFileTime) + ' 0');

                     TxState := TxSendData;
                   End Else Begin
                     SendFrame (M_EOB, '');

                     TxState := TxDone;
                   End;
      TxSendData : Begin
                     If HaveHeader And (RxCommand = M_GET) Then Begin
                       Str := strWordGet(4, GetDataStr, ' ');

                       Seek (OutFile, strS2I(Str));

                       // fix file time and escape filename
                       SendFrame (M_FILE, FileList.QData[FileList.QPos].FileName + ' ' + Str + ' ' + strI2S(TempFileTime) + ' 0');

                       HaveHeader := False;
                       NeedHeader := True;

                       Continue;
                     End;

                     BlockRead     (OutFile, OutBuf, SizeOf(OutBuf), OutSize);
                     SendDataFrame (OutBuf, OutSize);

                     If OutSize < SizeOf(OutBuf) Then Begin
                       Close (OutFile);

                       TxState    := TxGetEOF;
                       HaveHeader := False;
                       NeedHeader := True;
                     End;
                   End;
    End;
  Until ((RxState = RxDone) and (TxState = TxDone)) or (Not Client.Connected) or (TimerUp(TimeOut));

  If Client.Connected Then Client.BufFlush;
End;

Function IsFTNPrimary (EchoNode: RecEchoMailNode) : Boolean;
Var
  Count : Byte;
Begin
  For Count := 1 to 30 Do
    If (strUpper(EchoNode.Domain) = strUpper(bbsConfig.NetDomain[Count])) and
       (EchoNode.Address.Zone = bbsConfig.NetAddress[Count].Zone) and
       (bbsConfig.NetPrimary[Count]) Then Begin
         Result := True;

         Exit;
    End;

  Result := False;
End;

Function GetFTNOutPath (EchoNode: RecEchoMailNode) : String;
Begin;
  If IsFTNPrimary(EchoNode) Then
    Result := bbsConfig.OutboundPath
  Else
    Result := DirLast(bbsConfig.OutboundPath) + strLower(EchoNode.Domain + '.' + strPadL(strI2H(EchoNode.Address.Zone, 3), 3, '0')) + PathChar;
End;

Function GetFTNFlowName (Dest: RecEchoMailAddr) : String;
Begin
  Result := strI2H((Dest.Net SHL 16) OR Dest.Node, 8);
End;

Procedure PollNode (Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode);
Var
  BinkP  : TBinkP;
  Client : TIOSocket;
  Port   : Word;
Begin
  Client := TIOSocket.Create;

  Client.FTelnetClient := False;
  Client.FTelnetServer := False;

  Write ('- Connecting to ', EchoNode.binkHost, ': ');

  Port := strS2I(strWordGet(2, EchoNode.binkHost, ':'));

  If Port = 0 Then Port := 24554;

  If Not Client.Connect (strWordGet(1, EchoNode.binkHost, ':'), Port) Then Begin
    WriteLn ('UNABLE TO CONNECT');

    Client.Free;

    Exit;
  End;

  WriteLn ('CONNECTED!');

  BinkP := TBinkP.Create(Client, Queue, True, EchoNode.binkTimeOut * 100);

  BinkP.SetOutPath   := GetFTNOutPath(EchoNode);
  BinkP.SetPassword  := EchoNode.binkPass;
  BinkP.SetBlockSize := EchoNode.binkBlock;
  BinkP.UseMD5       := EchoNode.binkMD5 > 0;
  BinkP.ForceMD5     := EchoNode.binkMD5 = 2;

  If BinkP.DoAuthentication Then
    BinkP.DoTransfers
  Else
    WriteLn ('- Unable to authenticate');

  BinkP.Free;
  Client.Free;
End;

Procedure QueueByNode (Var Queue: TProtocolQueue; EchoNode: RecEchoMailNode);
Var
  DirInfo : SearchRec;
  FLOFile : Text;
  Str     : String;
  FN      : String;
  Path    : String;
  OutPath : String;
Begin
  OutPath := GetFTNOutPath(EchoNode);

  FindFirst (OutPath + '*.?lo', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    Write ('- Found ', DirInfo.Name, ' -> Send Type: ');

    Case UpCase(JustFileExt(DirInfo.Name)[1]) of
      'C' : WriteLn ('Crash');
      'D' : WriteLn ('Direct');
      'H' : Begin
              WriteLn ('Hold - SKIPPING');

              FindNext (DirInfo);

              Continue;
            End;
    Else
      WriteLn ('Normal');
    End;

    If Not ((strUpper(JustFileName(DirInfo.Name)) = strUpper(GetFTNFlowName(EchoNode.Address))) and EchoNode.Active and (EchoNode.ProtType = 0)) Then Begin
      FindNext (DirInfo);

      Continue;
    End;

    Assign (FLOFile, OutPath + DirInfo.Name);
    Reset  (FLOFile);

    While Not Eof(FLOFile) Do Begin
      ReadLn (FLOFile, Str);

      If (Str = '') or (Str[1] = '!') Then Continue;

      Str  := strStripB(Copy(Str, 2, 255), ' ');
      FN   := JustFile(Str);
      Path := JustPath(Str);

      Queue.Add (Path, FN);
    End;

    Close (FLOFile);

    WriteLn('- Queued ', Queue.QSize, ' files (', Queue.QFSize, ' bytes) to ', strAddr2Str(EchoNode.Address));

    FindNext (DirInfo);
  End;
End;

Procedure PollAll (OnlyNew: Boolean);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
Begin
  WriteLn ('Polling BINKP nodes...');
  WriteLn;

  Total := 0;
  Queue := TProtocolQueue.Create;

  Assign (EchoFile, bbsConfig.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If Not (EchoNode.Active and (EchoNode.ProtType = 0)) Then Continue;

    Queue.Clear;

    QueueByNode (Queue, EchoNode);

    If OnlyNew and (Queue.QSize = 0) Then Continue;

    Inc (Total);

    WriteLn  ('- Polling node ' + strAddr2Str(EchoNode.Address) + ' (Queued ', Queue.QSize, ' files, ', Queue.QFSize, ' bytes)');
    PollNode (Queue, EchoNode);
  End;

  Close (EchoFile);

  Queue.Free;

  If Total > 0 Then WriteLn;

  WriteLn ('Polled ', Total, ' nodes');
End;

Procedure DoServer;
Begin
End;

Var
  CF  : File of RecConfig;
  Str : String;
Begin
  FileMode := 66;

  WriteLn;
  WriteLn ('BINKPOLL Version ' + mysVersion);
  WriteLn;

  Assign (CF, 'mystic.dat');

  If Not ioReset (CF, SizeOf(RecConfig), fmRWDN) Then Begin
    WriteLn ('Unable to read MYSTIC.DAT');
    Halt(1);
  End;

  Read  (CF, bbsConfig);
  Close (CF);

  If bbsConfig.DataChanged <> mysDataChanged Then Begin
    WriteLn ('Mystic VERSION mismatch');
    Halt(1);
  End;

  If ParamCount = 0 Then Begin
    WriteLn ('BINKPOLL SEND   - Only send/poll if node has new outbound messages');
    WriteLn ('BINKPOLL FORCED - Poll/send to all configured/active BINKP nodes');
    WriteLn ('BINKPOLL SERVER - Start in BINKP server mode (not implmented yet)');

    Halt(1);
  End;

  TempPath := bbsConfig.SystemPath + 'tempftn' + PathChar;

  {$I-}
  MkDir (TempPath);
  {$I+}

  If IoResult <> 0 Then;

  Str := strUpper(strStripB(ParamStr(1), ' '));

  If (Str = 'SEND') or (Str = 'FORCED') Then
    PollAll (Str = 'SEND')
  Else
  If (Str = 'SERVER') Then
    DoServer
  Else
    WriteLn ('Invalid command line');
End.

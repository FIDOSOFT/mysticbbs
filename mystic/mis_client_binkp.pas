Unit MIS_Client_BINKP;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  m_io_Sockets,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_Crypt,
  m_Protocol_Queue,
  MIS_Server,
  MIS_NodeData,
  MIS_Common,
  BBS_Records;

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

  // needs to be 32k... can't remember what the problem was that made me
  // limit it temporarily to 30k

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

  TBinkPStatusUpdate = Procedure (Owner: Pointer; Str: String);

  TBinkP = Class
    Owner        : Pointer;
    StatusUpdate : TBinkPStatusUpdate;
    SetPassword  : String;
    SetBlockSize : Word;
    SetOutPath   : String;
    SetTimeOut   : Word;
    HaveNode     : Boolean;
    EchoNode     : RecEchoMailNode;
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
    AddressList  : String;
    Password     : String;
    PasswordMD5  : Boolean;
    FileList     : TProtocolQueue;

    Constructor Create (O: Pointer; Var C: TIOSocket; Var FL: TProtocolQueue; IsCli: Boolean; TOV: Word);
    Destructor  Destroy; Override;
    Procedure   RemoveFilesFromFLO (FN: String);
    Function    AuthenticateNode (AddrList: String) : Boolean;
    Function    GetDataStr : String;
    Procedure   SendFrame (CmdType: Byte; CmdData: String);
    Procedure   SendDataFrame (Var Buf; BufSize: Word);
    Procedure   DoFrameCheck;
    Function    DoAuthentication : Boolean;
    Procedure   DoTransfers;
  End;

Function CreateBINKP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  TBINKPServer = Class(TServerClient)
    Server   : TServerManager;
    UserName : String[30];

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Procedure   Execute; Override;
//    Procedure   Status (Str: String);
    Destructor  Destroy; Override;
  End;

Implementation

// PROTOCOL CLASS IMPLEMENTATION

Procedure DefaultBinkPStatusProc (Owner: Pointer; Str: String);
Begin
//writeln(str);
End;

Constructor TBinkP.Create (O: Pointer; Var C: TIOSocket; Var FL: TProtocolQueue; IsCli: Boolean; TOV: Word);
Begin
  Inherited Create;

  StatusUpdate := @DefaultBinkPStatusProc;
  SetTimeOut   := TOV;
  Client       := C;
  Owner        := O;
  FileList     := FL;
  IsClient     := IsCli;
  UseMD5       := True;
  ForceMD5     := False;
  RxBufSize    := 0;
  RxState      := RxNone;
  TxState      := TxNone;
  TimeOut      := TimerSet(SetTimeOut);
  NeedHeader   := True;
  HaveHeader   := False;
  AddressList  := '';
  MD5Challenge := '';
  Password     := '';
  HaveNode     := False;
  AuthState    := SendWelcome;

  If Not IsClient and UseMD5 Then
    AuthState := SendChallenge;
End;

Destructor TBinkP.Destroy;
Begin
  Inherited Destroy;
End;

Function TBinkP.AuthenticateNode (AddrList: String) : Boolean;
Var
  EchoFile  : File;
  Count     : Byte;
  Addr1     : String;
  Addr2     : String;
  UseDomain : Boolean;
Begin
  Result := False;

  Assign (EchoFile, bbsConfig.DataPath + 'echonode.dat');

  If Not ioReset(EchoFile, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(EchoFile) Do Begin
    ioRead(EchoFile, EchoNode);

    For Count := 1 to strWordCount(AddrList, ' ') Do Begin
      Addr1     := strWordGet(Count, AddrList, ' ');
      Addr2     := strAddr2Str(EchoNode.Address);
      UseDomain := Pos('@', Addr1) > 0;

      If UseDomain Then
        Addr2 := Addr2 + '@' + EchoNode.Domain;

      If strUpper(Addr1) = strUpper(Addr2) Then Begin
        If PasswordMD5 Then Begin
          If strUpper(Password) = strUpper(Digest2String(HMAC_MD5(String2Digest(MD5Challenge), EchoNode.binkPass))) Then Begin
            Result := True;

            Break;
          End;
        End Else Begin
          If Password = EchoNode.binkPass Then Begin
            Result := True;

            Break;
          End;
        End;
      End;
    End;

    If Result Then Break;
  End;

  Close (EchoFile);
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

  // possible issue if multiple BINKP connections are going.  we need
  // to revamp this to perform appropriate file locking and waiting.
  // also should be moved to mis_common since FTN-FTP will also perform
  // the same procedure.
  // could also perform a critical section as a cheesy way to do this?

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
    SZ := RxBufSize - 1;

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

//  WriteLn ('    S ' + BinkCmdStr[CmdType] + ' ' + CmdData);
//  waitms(1000);
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

//    Case RxFrameType of
//      Command : If (RxCommand = M_NUL) or (RxCommand = M_ERR) Then
//                  WriteLn ('    R ', BinkCmdStr[RxCommand], ' ', GetDataStr);
//        Command : WriteLn ('    R ', BinkCmdStr[RxCommand], ' ', GetDataStr);
//      Data    : WriteLn ('Got Data Frame (Read ', InPos, ' of ', RxBufSize, ')');
//    End;
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

      If Not IsClient Then
        StatusUpdate (Owner, Str);
    End;

//    WriteLn ('AuthState: ', GetStateStr(AuthState), ', HasHeader: ', HaveHeader, ' Data: ', GetDataStr);
//    WriteLn ('AuthState: ', Ord(AuthState), ', HasHeader: ', HaveHeader, ' Data: ', GetDataStr);
//waitms(100);
    Case AuthState of
      SendChallenge : Begin
                        For Count := 1 to 16 Do
                          Str[Count] := Char(Random(255));

                        MD5Challenge := Digest2String(Str);

                        SendFrame (M_NUL, 'OPT MD5-' + MD5Challenge);

                        AuthState := SendWelcome;
                      End;
      SendWelcome   : Begin
                        SendFrame (M_NUL, 'SYS ' + bbsConfig.BBSName);
                        SendFrame (M_NUL, 'ZYZ ' + bbsConfig.SysopName);
                        SendFrame (M_NUL, 'VER Mystic/' + Copy(mysVersion, 1, 4) + ' binkp/1.0');

                        Str := '';

                        For Count := 1 to 30 Do
                          If strAddr2Str(bbsConfig.NetAddress[Count]) <> '0:0/0' Then Begin
                            If Str <> '' Then Str := Str + ' ';

                            Str := Str + strAddr2Str(bbsConfig.NetAddress[Count]);

                            If bbsConfig.NetDomain[Count] <> '' Then
                              Str := Str + '@' + bbsConfig.NetDomain[Count];
                          End;

                        SendFrame (M_ADR, Str);

                        If IsClient Then
                          AuthState := SendPassword
                        Else Begin
                          HaveHeader := False;
                          NeedHeader := True;
                          AuthState  := WaitAddress;
                        End;
                      End;
      SendPassword  : If HaveHeader Then Begin
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
      WaitAddress   : If HaveHeader Then Begin
                        If RxCommand <> M_ADR Then Begin
                          // Client did not send ADR
                          AuthState := AuthFailed;
                        End Else Begin
                          AddressList := GetDataStr;
                          AuthState   := WaitPassword;
                          NeedHeader  := True;
                          HaveHeader  := False;

                          StatusUpdate (Owner, 'ADR ' + AddressList);
                        End;
                      End;
      WaitPassword  : If HaveHeader Then Begin
                        AuthState := AuthFailed;

                        If (RxCommand = M_PWD) Then Begin
                          Password := GetDataStr;

                          If Pos('CRAM-MD5-', Password) > 0 Then Begin
                            Delete(Password, 1, Pos('CRAM-MD5-', Password) + 8);

                            PasswordMD5 := True;

                            If AuthenticateNode(AddressList) Then Begin
                              SendFrame (M_OK, '');

                              AuthState := AuthOK;
                            End;
                          End Else Begin
                            If ForceMD5 Then
                              SendFrame (M_ERR, 'Required CRAM-MD5 authentication')
                            Else Begin
                              PasswordMD5 := False;

                              If AuthenticateNode(AddressList) Then Begin
                                SendFrame (M_OK, '');

                                AuthState := AuthOK;
                              End;
                            End;
                          End;
                        End;

                        If AuthState <> AuthOK Then
                          StatusUpdate(Owner, 'Auth failed');
                      End;
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

                           StatusUpdate(Owner, 'Receiving: ' + InFN);

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
                     SendFrame (M_FILE, FileList.QData[FileList.QPos].FileNew + ' ' + strI2S(FileList.QData[FileList.QPos].FileSize) + ' ' + strI2S(TempFileTime) + ' 0');

                     StatusUpdate (Owner, 'Sending ' + FileList.QData[FileList.QPos].FileNew);

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
                       SendFrame (M_FILE, FileList.QData[FileList.QPos].FileNew + ' ' + Str + ' ' + strI2S(TempFileTime) + ' 0');

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

  If Not IsClient Then
    StatusUpdate(Owner, 'Session complete');

  If Client.Connected Then Client.BufFlush;
End;

// GENERAL FIDO STUFF SHOULD BE RELOCATED SOMEWHERE ELSE?

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

Function GetFTNFlowName (Dest: RecEchoMailAddr) : String;
Begin
  If Dest.Point = 0 Then
    Result := strI2H((Dest.Net SHL 16) OR Dest.Node, 8)
  Else
    Result := strI2H(Dest.Point, 8);
End;

Function GetFTNOutPath (EchoNode: RecEchoMailNode) : String;
Begin;
  If IsFTNPrimary(EchoNode) Then
    Result := bbsConfig.OutboundPath
  Else
    Result := DirLast(bbsConfig.OutboundPath) + strLower(EchoNode.Domain + '.' + strPadL(strI2H(EchoNode.Address.Zone, 3), 3, '0')) + PathChar;

  If EchoNode.Address.Point <> 0 Then
    Result := Result + strI2H((EchoNode.Address.Net SHL 16) OR EchoNode.Address.Node, 8) + '.pnt' + PathChar;
End;

Procedure QueueByNode (Var Queue: TProtocolQueue; SkipHold: Boolean; EchoNode: RecEchoMailNode);
Var
  DirInfo : SearchRec;
  FLOFile : Text;
  Str     : String;
  FN      : String;
  Path    : String;
  OutPath : String;
Begin
  OutPath := GetFTNOutPath(EchoNode);

  // QUEUE BY FLOW FILES

  FindFirst (OutPath + '*.?lo', AnyFile, DirInfo);

  While DosError = 0 Do Begin

    If SkipHold And (UpCase(JustFileExt(DirInfo.Name)[1]) = 'H') Then Begin
      FindNext (DirInfo);

      Continue;
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

      Queue.Add (True, Path, FN, '');
    End;

    Close (FLOFile);

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);

  // QUEUE BY RAW PACKET

  FindFirst (OutPath + '*.?ut', AnyFile, DirInfo);

  While DosError = 0 Do Begin

    If SkipHold And (UpCase(JustFileExt(DirInfo.Name)[1]) = 'H') Then Begin
      FindNext (DirInfo);

      Continue;
    End;

    If Not ((strUpper(JustFileName(DirInfo.Name)) = strUpper(GetFTNFlowName(EchoNode.Address))) and EchoNode.Active and (EchoNode.ProtType = 0)) Then Begin
      FindNext (DirInfo);

      Continue;
    End;

    Queue.Add (True, OutPath, DirInfo.Name, FileNewExt(DirInfo.Name, 'pkt'));

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

// SERVER CLASS IMPLEMENTATION

Function CreateBINKP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TBINKPServer.Create(Owner, CliSock);
End;

Procedure Status (Owner: Pointer; Str: String);
Begin
  TServerManager(Owner).Status(-1, Str);
End;

Constructor TBINKPServer.Create (Owner: TServerManager; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
  Client := CliSock;
End;

Procedure TBINKPServer.Execute;
Var
  Queue   : TProtocolQueue;
  BinkP   : TBinkP;
  Count   : Integer;
  Address : String;
  Before  : LongInt;
Begin
  Queue := TProtocolQueue.Create;
  BinkP := TBinkP.Create (Server, Client, Queue, False, bbsConfig.inetBINKPTimeOut);

  BinkP.StatusUpdate := @Status;

  If BinkP.DoAuthentication Then Begin

    For Count := 1 to strWordCount(BinkP.AddressList, ' ') Do Begin
      Address := strWordGet(Count, BinkP.AddressList, ' ');

      If BinkP.AuthenticateNode(Address) Then Begin
        Before := Queue.QSize;

        QueueByNode(Queue, False, BinkP.EchoNode);

        Server.Status (ProcessID, 'Queued ' + strI2S(Queue.QSize - Before) + ' files for ' + strAddr2Str(BinkP.EchoNode.Address));
      End;
    End;

    BinkP.FileList := Queue;
    BinkP.DoTransfers;
  End;

  BinkP.Free;
  Queue.Free;
End;

Destructor TBINKPServer.Destroy;
Begin
  Inherited Destroy;
End;

End.

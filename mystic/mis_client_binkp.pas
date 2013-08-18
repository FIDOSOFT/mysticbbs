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
  MIS_Common;

Function CreateBINKP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  TBINKPServer = Class(TServerClient)
    Server   : TServerManager;
    UserName : String[30];

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;
  End;

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

Implementation

// SERVER CLASS IMPLEMENTATION

Function CreateBINKP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TBINKPServer.Create(Owner, CliSock);
End;

Constructor TBINKPServer.Create (Owner: TServerManager; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

Procedure TBINKPServer.Execute;
Begin
End;

Destructor TBINKPServer.Destroy;
Begin
  Inherited Destroy;
End;

// PROTOCOL CLASS IMPLEMENTATION

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
                     SendFrame (M_FILE, FileList.QData[FileList.QPos].FileNew + ' ' + strI2S(FileList.QData[FileList.QPos].FileSize) + ' ' + strI2S(TempFileTime) + ' 0');

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

  If Client.Connected Then Client.BufFlush;
End;

End.

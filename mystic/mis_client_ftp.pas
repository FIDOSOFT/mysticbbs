{$I M_OPS.PAS}

Unit MIS_Client_FTP;

// does not send file/directory datestamps
// does not support uploading (need to make bbs functions generic for this
//    and for mbbsutil -fupload command)

Interface

Uses
  SysUtils,
  m_Strings,
  m_FileIO,
  m_Socket_Class,
  m_DateTime,
  MIS_Server,
  MIS_NodeData,
  MIS_Common;

Function CreateFTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Type
  TFTPServer = Class(TServerClient)
    Server     : TServerManager;
    UserName   : String[40];
    Password   : String[20];
    LoggedIn   : Boolean;
    GotQuit    : Boolean;
    IsPassive  : Boolean;
    InTransfer : Boolean;
    Cmd        : String;
    Data       : String;
    DataPort   : Word;
    DataIP     : String;
    DataSocket : TSocketClass;
    User       : RecUser;
    UserPos    : LongInt;
    FBasePos   : LongInt;
    FBase      : FBaseRec;
    SecLevel   : RecSecurity;
    FileMask   : String;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

//    Procedure   dlog (S:String);

    Procedure   ResetSession;
    Procedure   UpdateUserStats (TFBase: FBaseRec; FDir: FDirRec; DirPos: LongInt);
    Function    CheckFileLimits (TempFBase: FBaseRec; FDir: FDirRec) : Byte;
    Function    OpenDataSession : Boolean;
    Procedure   CloseDataSession;
    Function    ValidDirectory (TempBase: FBaseRec) : Boolean;
    Function    FindDirectory (Var TempBase: FBaseRec) : LongInt;

    Procedure   cmdUSER;
    Procedure   cmdPASS;
    Procedure   cmdREIN;
    Procedure   cmdPORT;
    Procedure   cmdPASV;
    Procedure   cmdCWD;
    Procedure   cmdCDUP;
    Procedure   cmdNLST;
    Procedure   cmdLIST;
    Procedure   cmdPWD;
    Procedure   cmdRETR;
    Procedure   cmdSTRU;
    Procedure   cmdMODE;
    Procedure   cmdSYST;
    Procedure   cmdTYPE;
    Procedure   cmdEPRT;
    Procedure   cmdEPSV;
    Procedure   cmdSIZE;
  End;

Implementation

Const
  FTPTimeOut     = 120;  // Make this configurabe in MCFG?
  FileBufSize    = 8 * 1024;

  re_DataOpen    = '125 Data connection already open';
  re_DataOpening = '150 File status okay; about to open data connection.';
  re_CommandOK   = '200 Command okay.';
  re_NoCommand   = '202 Command not implemented, superfluous at this site.';
  re_Greeting    = '220 Mystic FTP server ready';
  re_Goodbye     = '221 Goodbye';
  re_DataClosed  = '226 Closing data connection.';
  re_XferOK      = '226 Transfer OK';
  re_PassiveOK   = '227 Entering Passive Mode ';
  re_LoggedIn    = '230 User logged in, proceed.';
  re_DirOkay     = '257 Working directory is now ';
  re_UserOkay    = '331 User name okay, need password.';
  re_NoData      = '425 Unable to open data connection';
  re_BadCommand  = '503 Bad sequence of commands.';
  re_UserUnknown = '530 Not logged in.';
  re_BadPW       = '530 Login or password incorrect';
  re_BadDir      = '550 Directory change failed';
  re_BadFile     = '550 File not found';
  re_NoAccess    = '550 Access denied';
  re_DLLimit     = '550 Download limit would be exceeded';
  re_DLRatio     = '550 Download/upload ratio would be exceeded';

Function CreateFTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TFTPServer.Create(Owner, CliSock);
End;

Constructor TFTPServer.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

(*
Procedure TFTPServer.dlog (S:String);
Var
  T : Text;
Begin
  Assign (T, 'd:\code\mystic1\misftp.log');
  Append (T);
  If IoResult <> 0 Then Rewrite(T);
  WriteLn(T, S);
  Close(T);
End;
*)

Procedure TFTPServer.ResetSession;
Begin
  If Assigned(DataSocket) Then DataSocket.Free;

  LoggedIn   := False;
  GotQuit    := False;
  UserName   := '';
  Password   := '';
  UserPos    := -1;
  DataIP     := '';
  DataPort   := 20;
  DataSocket := NIL;
  IsPassive  := False;
  FBasePos   := -1;
  InTransfer := False;
End;

Procedure TFTPServer.UpdateUserStats (TFBase: FBaseRec; FDir: FDirRec; DirPos: LongInt);
Var
  HistFile: File of HistoryRec;
  History : HistoryRec;
  FDirFile: File of FDirRec;
  UserFile: File of RecUser;
Begin
  Inc (FDir.DLs);

  Assign  (UserFile, bbsConfig.DataPath + 'users.dat');
  ioReset (UserFile, SizeOf(RecUser), fmReadWrite + fmDenyWrite);
  ioSeek  (UserFile, UserPos - 1);
  ioRead  (UserFile, User);

  If DateDos2Str(User.LastOn, 1) <> DateDos2Str(CurDateDos, 1) Then Begin
    User.CallsToday := 0;
    User.DLsToday   := 0;
    User.DLkToday   := 0;
    User.TimeLeft   := SecLevel.Time
  End;

  // need to check if it were an upload and do things accordingly

  Inc (User.DLs);
  Inc (User.DLsToday);
  Inc (User.DLk, FDir.Size DIV 1024);
  Inc (User.DLkToday, FDir.Size DIV 1024);

  ioSeek  (UserFile, UserPos - 1);
  ioWrite (UserFile, User);
  Close   (UserFile);

  Assign  (FDirFile, bbsConfig.DataPath + TFBase.FileName + '.dir');
  ioReset (FDirFile, SizeOf(FDirRec), fmReadWrite + fmDenyWrite);
  ioSeek  (FDirFile, DirPos - 1);
  ioWrite (FDirFile, FDir);
  Close   (FDirFile);

  Assign  (HistFile, bbsConfig.DataPath + 'history.dat');
  ioReset (HistFile, SizeOf(HistoryRec), fmReadWrite + fmDenyWrite);

  If IoResult <> 0 Then ReWrite(HistFile);

  History.Date := CurDateDos;

  While Not Eof(HistFile) Do Begin
    ioRead (HistFile, History);

    If DateDos2Str(History.Date, 1) = DateDos2Str(CurDateDos, 1) Then Begin
      ioSeek (HistFile, FilePos(HistFile) - 1);
      Break;
    End;
  End;

  If Eof(HistFile) Then Begin
    FillChar(History, SizeOf(History), 0);
    History.Date := CurDateDos;
  End;

  Inc (History.Downloads,  1);
  Inc (History.DownloadKB, FDir.Size DIV 1024);

  ioWrite (HistFile, History);
  Close   (HistFile);
End;

Function TFTPServer.CheckFileLimits (TempFBase: FBaseRec; FDir: FDirRec) : Byte;
{ 0 = OK to download }
{ 1 = Offline or Invalid or Failed or NO ACCESS or no file (prompt 224)}
{ 2 = DL per day limit exceeded (prompt 58) }
{ 3 = UL/DL file ratio bad (prompt 211) }
Begin
  Result := 1;

  If Not FileExist(TempFBase.Path + FDir.Filename) Then Exit;

  If Not CheckAccess(User, True, TempFBase.DLACS) Then Exit;

  If FDir.Flags And FDirOffline <> 0 Then Exit;

  If (FDir.Flags And FDirInvalid <> 0) And Not CheckAccess(User, True, bbsConfig.AcsDLUnvalid) Then Exit;
  If (FDir.Flags And FDirFailed  <> 0) And Not CheckAccess(User, True, bbsConfig.AcsDLFailed)  Then Exit;

  If (FDir.Flags And FDirFree <> 0) or (User.Flags and UserNoRatio <> 0) or (TempFBase.IsFREE) Then Begin
    Result := 0;
    Exit;
  End;

  If (User.DLsToday + 1 > SecLevel.MaxDLs) and (SecLevel.MaxDLs > 0) Then Begin
    Result := 2;
    Exit;
  End;

  If SecLevel.DLRatio > 0 Then
    If (User.ULs * SecLevel.DLRatio) <= (User.DLs + 1) Then Begin
      Result := 3;
      Exit;
    End;

  If SecLevel.DLKRatio > 0 Then
    If (User.ULk * SecLevel.DLkRatio) <= (User.DLk + (FDir.Size DIV 1024)) Then Begin
      Result := 3;
      Exit;
    End;

  If (User.DLkToday + (FDir.Size DIV 1024) > SecLevel.MaxDLk) and (SecLevel.MaxDLk > 0) Then Begin
    Result := 2;
    Exit;
  End;

  Result := 0;
End;

Function TFTPServer.OpenDataSession : Boolean;
Var
  WaitSock : TSocketClass;
Begin
  Result := False;

  If DataSocket <> NIL Then Begin
    Client.WriteLine(re_DataOpen);
    Result := True;
    Exit;
  End;

  Client.WriteLine(re_DataOpening);

  If IsPassive Then Begin
    WaitSock := TSocketClass.Create;

    WaitSock.WaitInit(DataPort);

    DataSocket := WaitSock.WaitConnection;

    If Not Assigned(DataSocket) Then Begin
      WaitSock.Free;
      Client.WriteLine(re_NoData);
      Exit;
    End;

    WaitSock.Free;
  End Else Begin
    DataSocket := TSocketClass.Create;

    If Not DataSocket.Connect(DataIP, DataPort) Then Begin
      Client.WriteLine(re_NoData);
      DataSocket.Free;
      DataSocket := NIL;
      Exit;
    End;
  End;

  Result := True;
End;

Procedure TFTPServer.CloseDataSession;
Begin
  If DataSocket <> NIL Then Begin
    Client.WriteLine(re_DataClosed);
    DataSocket.Free;
    DataSocket := NIL;
  End;
End;

Function TFTPServer.ValidDirectory (TempBase: FBaseRec) : Boolean;
Begin
  Result := CheckAccess(User, True, TempBase.FtpACS) and (TempBase.FtpName <> '');
End;

Function TFTPServer.FindDirectory (Var TempBase: FBaseRec) : LongInt;
Var
  FBaseFile : TBufFile;
  Found     : Boolean;
Begin
  Result   := FBasePos;
  TempBase := FBase;
  FileMask := '*.*';

  If Not LoggedIn Then Exit;
  If Data = '' Then Exit;

  If (Pos('*', Data) > 0) or (Pos('.', Data) > 0) Then Begin
    FileMask := JustFile(Data);
    Data     := JustPath(Data);
  End;

  If Data = '/' Then Begin
    Result := -1;
    Exit;
  End;

  If ((Data[1] = '/') or (Data[1] = '\')) Then Delete(Data, 1, 1);
  If ((Data[Length(Data)] = '/') or (Data[Length(Data)] = '\')) Then Delete(Data, Length(Data), 1);

  If Data = '' Then Exit;

  FBaseFile := TBufFile.Create(FileBufSize);

  If FBaseFile.Open(bbsConfig.DataPath + 'fbases.dat', fmOpen, fmRWDN, SizeOf(FBaseRec)) Then Begin
    Found := False;

    While Not FBaseFile.EOF Do Begin
      FBaseFile.Read(TempBase);

      If (strUpper(TempBase.FtpName) = strUpper(Data)) and ValidDirectory(TempBase) Then Begin
        Result := FBaseFile.FilePos;
        Found  := True;
        Break;
      End;
    End;
  End;

  FBaseFile.Free;

  If Not Found Then Begin
    If Pos('-', Data) > 0 Then
      FileMask := '*.*'
    Else
      FileMask := Data;

    TempBase := FBase;
    Result   := FBasePos;
  End;
End;

Procedure TFTPServer.cmdUSER;
Begin
  ResetSession;

  If SearchForUser(Data, User, UserPos) Then Begin
    Client.WriteLine(re_UserOkay);
    UserName := Data;
  End Else
    Client.WriteLine(re_UserUnknown);
End;

Procedure TFTPServer.cmdPASS;
Begin
  If (UserName = '') or (UserPos = -1) Then Begin
    Client.WriteLine(re_BadCommand);
    Exit;
  End;

  If strUpper(Data) = User.Password Then Begin
    LoggedIn := True;

    Client.WriteLine(re_LoggedIn);

    GetSecurityLevel(User.Security, SecLevel);

    Server.Server.Status (User.Handle + ' logged in');
  End Else
    Client.WriteLine(re_BadPW);
End;

Procedure TFTPServer.cmdREIN;
Begin
  ResetSession;
  Client.WriteLine(re_Greeting);
End;

Procedure TFTPServer.cmdPORT;
Var
  Count : Byte;
Begin
  If LoggedIn Then Begin
    For Count := 1 to 3 Do
      Data[Pos(',', Data)] := '.';

    DataIP := Copy(Data, 1, Pos(',', Data) - 1);

    Delete (Data, 1, Pos(',', Data));

    WordRec(DataPort).Hi := strS2I(Copy(Data, 1, Pos(',', Data) - 1));
    WordRec(DataPort).Lo := strS2I(Copy(Data, Pos(',', Data) + 1, Length(Data)));

    Client.WriteLine(re_CommandOK);

    IsPassive := False;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdPASV;
Var
  WaitSock : TSocketClass;
Begin
  If LoggedIn Then Begin
    DataPort := Random(65535-60000) + 60000;  // make configurable?!

    Client.WriteLine(re_PassiveOK + '(' + strReplace(Client.HostIP, '.', ',') + ',' + strI2S(WordRec(DataPort).Hi) + ',' + strI2S(WordRec(DataPort).Lo) + ').');

    IsPassive := True;

    WaitSock := TSocketClass.Create;

    WaitSock.WaitInit(DataPort);

    DataSocket := WaitSock.WaitConnection;

    If Not Assigned(DataSocket) Then Begin
      WaitSock.Free;
      Client.WriteLine(re_NoData);
      Exit;
    End;

    WaitSock.Free;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdCDUP;
Begin
  Client.WriteLine(re_DirOkay + '"/"');

  FBasePos := -1;
End;

Procedure TFTPServer.cmdCWD;
Var
  TempBase  : FBaseRec;
  TempPos   : LongInt;
Begin
  If LoggedIn Then Begin
    If (Data = '/') or (Copy(Data, 1, 2) = '..') Then Begin
      FBasePos := -1;
      Client.WriteLine(re_DirOkay + '"/"');
      Exit;
    End;

    TempPos := FindDirectory(TempBase);

    If TempPos = -1 Then Begin
      Client.WriteLine(re_BadDir);
      Exit;
    End;

    Client.WriteLine(re_DirOkay + '"/' + TempBase.FtpName + '"');

    FBase    := TempBase;
    FBasePos := TempPos;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdNLST;
Var
  TempBase : FBaseRec;
  TempPos  : LongInt;
  DirFile  : TBufFile;
  Dir      : FDirRec;
Begin
  If LoggedIn Then Begin
    TempPos := FindDirectory(TempBase);

    If TempPos = -1 Then Begin
      OpenDataSession;
      CloseDataSession;
      // list files in root directory, so show nothing
      Exit;
    End;

    OpenDataSession;

    DirFile := TBufFile.Create(FileBufSize);

    If DirFile.Open(bbsConfig.DataPath + TempBase.FileName + '.dir', fmOpenCreate, fmRWDN, SizeOf(FDirRec)) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.Read(Dir);

        If (Dir.Flags And FDirDeleted <> 0) Then Continue;
        If (Dir.Flags And FDirInvalid <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeUnvalid)) Then Continue;
        If (Dir.Flags And FDirFailed <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeFailed)) Then Continue;

        If WildcardMatch(FileMask, Dir.FileName) Then
          DataSocket.WriteLine(Dir.FileName);
      End;
    End;

    DirFile.Free;

    CloseDataSession;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdPWD;
Begin
  If LoggedIn Then Begin
    If FBasePos = -1 Then
      Client.WriteLine(re_DirOkay + '"/"')
    Else
      Client.WriteLine(re_DirOkay + '"/' + FBase.FtpName + '"');
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdLIST;
Var
  TempBase  : FBaseRec;
  TempPos   : LongInt;
  FBaseFile : TBufFile;
  DirFile   : TBufFile;
  Dir       : FDirRec;
Begin
  If LoggedIn Then Begin
    TempPos := FindDirectory(TempBase);

    If TempPos = -1 Then Begin
      OpenDataSession;

      FBaseFile := TBufFile.Create(FileBufSize);

      If FBaseFile.Open(bbsConfig.DataPath + 'fbases.dat', fmOpen, fmRWDN, SizeOf(FBaseRec)) Then Begin
        While Not FBaseFile.EOF Do Begin
          FBaseFile.Read(TempBase);

          If ValidDirectory(TempBase) and WildcardMatch(FileMask, TempBase.FtpName) Then
              DataSocket.WriteLine('drwxr-xr-x   1 ftp      ftp             0 Jul 11 23:35 ' + TempBase.FtpName)
        End;
      End;

      FBaseFile.Free;

      CloseDataSession;

      Exit;
    End;

    OpenDataSession;

    DirFile := TBufFile.Create(FileBufSize);

    If DirFile.Open(bbsConfig.DataPath + TempBase.FileName + '.dir', fmOpenCreate, fmRWDN, SizeOf(FDirRec)) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.Read(Dir);

        If (Dir.Flags And FDirDeleted <> 0) Then Continue;
        If (Dir.Flags And FDirInvalid <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeUnvalid)) Then Continue;
        If (Dir.Flags And FDirFailed  <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeFailed)) Then Continue;

        If WildcardMatch(FileMask, Dir.FileName) Then
          DataSocket.WriteLine('-rw-r--r--   1 ftp      ftp ' + strPadL(strI2S(Dir.Size), 13, ' ') + ' Jul 11 23:35 ' + Dir.FileName)
      End;
    End;

    DirFile.Free;

    CloseDataSession;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdRETR;
Var
  TempPos  : LongInt;
  TempBase : FBaseRec;
  DirFile  : TBufFile;
  Dir      : FDirRec;
  Found    : LongInt;
  F        : File;
  Buf      : Array[1..4096] of Byte;
  Tmp      : LongInt;
  Res      : LongInt;
Begin
  If LoggedIn Then Begin
    TempPos := FindDirectory(TempBase);

    If TempPos = -1 Then Begin
      Client.WriteLine(re_BadFile);
      Exit;
    End;

    DirFile := TBufFile.Create(FileBufSize);
    Found   := -1;

    If DirFile.Open(bbsConfig.DataPath + TempBase.FileName + '.dir', fmOpenCreate, fmRWDN, SizeOf(FDirRec)) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.Read(Dir);

        If WildcardMatch(FileMask, Dir.FileName) Then Begin
          Found := DirFile.FilePos;
          Break;
        End;
      End;

      DirFile.Free;

      If Found = -1 Then Begin
        Client.WriteLine(re_BadFile);
        Exit;
      End;

      Case CheckFileLimits(TempBase, Dir) of
        0 : Begin
              Assign  (F, TempBase.Path + Dir.FileName);
              ioReset (F, 1, fmRWDN);

              InTransfer := True;

              OpenDataSession;

              While Not Eof(F) Do Begin
                BlockRead (F, Buf, SizeOf(Buf), Res);

                Repeat
                  Tmp := DataSocket.WriteBuf(Buf, Res);
                  Dec (Res, Tmp);
                Until Res = 0;
              End;

              Close (F);

              Client.WriteLine (re_XferOK);

              CloseDataSession;

              InTransfer := False;

              UpdateUserStats(TempBase, Dir, Found);
            End;
        1 : Client.WriteLine(re_NoAccess);
        2 : Client.WriteLine(re_DLLimit);
        3 : Client.WriteLine(re_DLRatio);
      End;
    End Else
      Client.WriteLine(re_BadFile);
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdSTRU;
Begin
  If strUpper(Data) = 'F' Then
    Client.WriteLine('200 FILE structure.')
  Else
    Client.WriteLine('504 Only FILE structure supported.');
End;

Procedure TFTPServer.cmdMODE;
Begin
  If strUpper(Data) = 'S' Then
    Client.WriteLine('200 STREAM mode.')
  Else
    Client.WriteLine('504 Only STREAM mode supported.');
End;

Procedure TFTPServer.cmdSYST;
Begin
  Client.WriteLine('215 UNIX Type: L8');
End;

Procedure TFTPServer.cmdTYPE;
Begin
  Client.WriteLine('200 All files sent in BINARY mode.');
End;

Procedure TFTPServer.cmdEPRT;
Var
  DataType : String;
Begin
  If LoggedIn Then Begin
    DataType := strWordGet(1, Data, '|');

    If DataType = '1' Then Begin
      DataIP    := strWordGet(2, Data, '|');
      DataPort  := strS2I(strWordGet(3, Data, '|'));
      IsPassive := False;

      Client.WriteLine(re_CommandOK);
    End Else
      Client.WriteLine('522 Network protocol not supported, use (1)');
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdEPSV;
Var
  WaitSock : TSocketClass;
Begin
  If LoggedIn Then Begin
    If Data = '' Then Begin
      DataPort  := Random(65535 - 60000) + 60000;  // make configuratable
      IsPassive := True;

      Client.WriteLine('229 Entering Extended Passive Mode (|||' + strI2S(DataPort) + '|)');

      WaitSock := TSocketClass.Create;

      WaitSock.WaitInit(DataPort);

      DataSocket := WaitSock.WaitConnection;

      If Not Assigned(DataSocket) Then Begin
        WaitSock.Free;
        Client.WriteLine(re_NoData);
        Exit;
      End;

      WaitSock.Free;
    End Else
    If Data = '1' Then
      Client.WriteLine(re_CommandOK)
    Else
      Client.WriteLine('522 Network protocol not supported, use (1)');

  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdSIZE;
Begin
  Client.WriteLine('550 Not implemented');
End;

Procedure TFTPServer.Execute;
Var
  Str : String;
Begin
  cmdREIN;

  Repeat
    If Client.WaitForData(FTPTimeOut * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

//    dlog(Str);
//server.server.status(str);

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'CDUP' Then cmdCDUP Else
    If Cmd = 'CWD'  Then cmdCWD Else
    If Cmd = 'EPRT' Then cmdEPRT Else
    If Cmd = 'EPSV' Then cmdEPSV Else
    If Cmd = 'LIST' Then cmdLIST Else
    If Cmd = 'MODE' Then cmdMODE Else
    If Cmd = 'NLST' Then cmdNLST Else
    If Cmd = 'NOOP' Then Client.WriteLine(re_CommandOK) Else
    If Cmd = 'PASS' Then cmdPASS Else
    If Cmd = 'PASV' Then cmdPASV Else
    If Cmd = 'PORT' Then cmdPORT Else
    If Cmd = 'PWD'  Then cmdPWD ELse
    If Cmd = 'REIN' Then cmdREIN Else
    If Cmd = 'RETR' Then cmdRETR Else
    If Cmd = 'SIZE' Then cmdSIZE Else
    If Cmd = 'STRU' Then cmdSTRU Else
    If Cmd = 'SYST' Then cmdSYST Else
    If Cmd = 'TYPE' Then cmdTYPE Else
    If Cmd = 'USER' Then cmdUSER Else
    If Cmd = 'XPWD' Then cmdPWD Else
    If Cmd = 'QUIT' Then Begin
      GotQuit := True;
      Break;
    End Else
      Client.WriteLine(re_NoCommand);
  Until Terminated;

  If GotQuit Then Begin
    Client.WriteLine(re_Goodbye);

    Server.Server.Status (User.Handle + ' logged out');
  End;
End;

Destructor TFTPServer.Destroy;
Begin
  If Assigned(DataSocket) Then DataSocket.Free;

  Inherited Destroy;
End;

End.

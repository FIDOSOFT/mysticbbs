Unit MIS_Client_FTP;

{$I M_OPS.PAS}

{.$DEFINE FTPDEBUG}

Interface

Uses
  DOS,
  SysUtils,  //for wordrec only?
  m_io_Base,
  m_io_Sockets,
  m_Strings,
  m_FileIO,
  m_DateTime,
  MIS_Server,
  MIS_NodeData,
  MIS_Common,
  BBS_Records,
  BBS_DataBase;

Function CreateFTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

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
    DataSocket : TIOSocket;
    User       : RecUser;
    UserPos    : LongInt;
    FBasePos   : LongInt;
    FBase      : RecFileBase;
    SecLevel   : RecSecurity;
    FileMask   : String;

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Function    OpenDataSession : Boolean;
    Procedure   CloseDataSession;
    Procedure   ResetSession;
    Procedure   UpdateUserStats (TFBase: RecFileBase; FDir: RecFileList; DirPos: LongInt; IsUpload: Boolean);
    Function    CheckFileLimits (TempFBase: RecFileBase; FDir: RecFileList) : Byte;
    Function    ValidDirectory  (TempBase: RecFileBase) : Boolean;
    Function    FindDirectory   (Var TempBase: RecFileBase) : LongInt;
    Function    GetQWKName      : String;
    Function    GetFTPDate      (DD: LongInt) : String;
    Procedure   SendFile        (Str: String);
    Function    RecvFile        (Str: String; IsAppend: Boolean) : Boolean;

    Function    QWKCreatePacket : Boolean;
    Procedure   QWKProcessREP;

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
    Procedure   cmdSTOR (IsAppend: Boolean);
    Procedure   cmdSTRU;
    Procedure   cmdMODE;
    Procedure   cmdSYST;
    Procedure   cmdTYPE;
    Procedure   cmdEPRT;
    Procedure   cmdEPSV;
    Procedure   cmdSIZE;
  End;

Implementation

Uses
  BBS_MsgBase_QWK;

Const
  FileBufSize    =  4 * 1024;
  FileXferSize   = 32 * 1024;

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
  re_DirOkay     = '250 Working directory is now ';
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

{$IFDEF FTPDEBUG}
Procedure LOG (Str: String);
Var
  T : Text;
Begin
  Assign (T, 'ftpdebug.txt');
  {$I-} Append(T); {$I+}

  If IoResult <> 0 Then ReWrite(T);

  WriteLn(T, Str);

  Close(T);
End;
{$ENDIF}

Function CreateFTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TFTPServer.Create(Owner, CliSock);
End;

Constructor TFTPServer.Create (Owner: TServerManager; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

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

Procedure TFTPServer.UpdateUserStats (TFBase: RecFileBase; FDir: RecFileList; DirPos: LongInt; IsUpload: Boolean);
Var
  HistFile : File of RecHistory;
  History  : RecHistory;
  FDirFile : File of RecFileList;
  UserFile : File of RecUser;
Begin
  // change to getuserbypos
  Assign  (UserFile, bbsConfig.DataPath + 'users.dat');
  ioReset (UserFile, SizeOf(RecUser), fmRWDW);
  ioSeek  (UserFile, UserPos - 1);
  ioRead  (UserFile, User);

  If DateDos2Str(User.LastOn, 1) <> DateDos2Str(CurDateDos, 1) Then Begin
    User.CallsToday := 0;
    User.DLsToday   := 0;
    User.DLkToday   := 0;
    User.TimeLeft   := SecLevel.Time;
    User.LastOn     := CurDateDos;
  End;

  If IsUpload Then Begin
    Inc (User.ULs);
    Inc (User.ULk, FDir.Size DIV 1024);
  End Else Begin
    Inc (FDir.Downloads);
    Inc (User.DLs);
    Inc (User.DLsToday);
    Inc (User.DLk, FDir.Size DIV 1024);
    Inc (User.DLkToday, FDir.Size DIV 1024);

    Assign  (FDirFile, bbsConfig.DataPath + TFBase.FileName + '.dir');
    ioReset (FDirFile, SizeOf(RecFileList), fmRWDW);
    ioSeek  (FDirFile, DirPos - 1);
    ioWrite (FDirFile, FDir);
    Close   (FDirFile);
  End;

  ioSeek  (UserFile, UserPos - 1);
  ioWrite (UserFile, User);
  Close   (UserFile);

  Assign  (HistFile, bbsConfig.DataPath + 'history.dat');
  ioReset (HistFile, SizeOf(RecHistory), fmRWDW);

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

  If IsUpload Then Begin
    Inc (History.Uploads);
    Inc (History.UploadKB, FDir.Size DIV 1024);
  End Else Begin
    Inc (History.Downloads);
    Inc (History.DownloadKB, FDir.Size DIV 1024);
  End;

  ioWrite (HistFile, History);
  Close   (HistFile);
End;

Function TFTPServer.CheckFileLimits (TempFBase: RecFileBase; FDir: RecFileList) : Byte;
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

  If (FDir.Flags And FDirFree <> 0) or (User.Flags and UserNoRatio <> 0) or (TempFBase.Flags and FBFreeFiles <> 0) Then Begin
    Result := 0;
    Exit;
  End;

  If (User.DLsToday + 1 > SecLevel.MaxDLs) and (SecLevel.MaxDLs > 0) Then Begin
    Result := 2;
    Exit;
  End;

  If (SecLevel.DLRatio > 0) and ((User.DLs <> 0) or (User.ULs <> 0)) Then
    If (User.ULs * SecLevel.DLRatio) <= (User.DLs + 1) Then Begin
      Result := 3;
      Exit;
    End;

  If (SecLevel.DLKRatio > 0) and ((User.DLs <> 0) or (User.ULs <> 0)) Then
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
  WaitSock : TIOSocket;
Begin
  Result := False;

  If DataSocket <> NIL Then Begin
    Client.WriteLine(re_DataOpen);

    Result := True;
    Exit;
  End;

  Client.WriteLine(re_DataOpening);

  If IsPassive Then Begin
    WaitSock := TIOSocket.Create;

    WaitSock.FTelnetServer := False;
    WaitSock.FTelnetClient := False;

    WaitSock.WaitInit(bbsConfig.inetInterface, DataPort);

    DataSocket := WaitSock.WaitConnection(10000);

    If Not Assigned(DataSocket) Then Begin
      WaitSock.Free;
      Client.WriteLine(re_NoData);

      Exit;
    End;

    WaitSock.Free;
  End Else Begin
    DataSocket := TIOSocket.Create;

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

Function TFTPServer.ValidDirectory (TempBase: RecFileBase) : Boolean;
Begin
  Result := CheckAccess(User, True, TempBase.FtpACS) and (TempBase.FtpName <> '');
End;

Function TFTPServer.FindDirectory (Var TempBase: RecFileBase) : LongInt;
Var
  FBaseFile : TFileBuffer;
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

  FBaseFile := TFileBuffer.Create(FileBufSize);

  If FBaseFile.OpenStream (bbsConfig.DataPath + 'fbases.dat', SizeOf(TempBase), fmOpen, fmRWDN) Then Begin
    Found := False;

    While Not FBaseFile.EOF Do Begin
      FBaseFile.ReadRecord (TempBase);

      If (strUpper(TempBase.FtpName) = strUpper(Data)) and ValidDirectory(TempBase) Then Begin
        Result := FBaseFile.FilePosRecord;
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

Function TFTPServer.GetFTPDate (DD: LongInt) : String;
Var
  Today  : DateTime;
  TempDT : DateTime;
Begin
  Today := CurDateDT;

  If DD = 0 Then DD := CurDateDos;

  UnPackTime (DD, TempDT);

  Result := FormatDate(TempDT, 'NNN DD ');

  If TempDT.Year = Today.Year Then
    Result := Result + FormatDate(TempDT, 'HH:II')
  Else
    Result := Result + FormatDate(TempDT, ' YYYY');
End;

Function TFTPServer.GetQWKName : String;
Begin
  Result := '';

  If LoggedIn Then Begin  // and allow qwk via ftp
    If (User.Flags AND UserQwkNetwork <> 0) Then
      Result := strLower(User.Handle)
    Else
      Result := strLower(BbsConfig.QwkBBSID);
  End;
End;

Function TFTPServer.RecvFile (Str: String; IsAppend: Boolean) : Boolean;
Var
  F   : File;
  Buf : Array[1..FileXferSize] of Byte;
  Res : LongInt;
Begin
  Result := False;

  If FileExist(Str) And Not IsAppend Then Begin
    Client.WriteLine(re_BadFile);

    Exit;
  End;

  If Not OpenDataSession Then Exit;

  Server.Status (ProcessID, 'Receiving: ' + Str);

  InTransfer := True;
  Result     := True;

  Assign (F, Str);

  If FileExist(Str) And IsAppend Then Begin
    ioReset (F, 1, fmRWDW);
    Seek    (F, FileSize(F));
  End Else Begin
    ioReWrite (F, 1, fmRWDW);

    IsAppend := False;
  End;

  Repeat
    Res := DataSocket.ReadBuf(Buf[1], SizeOf(Buf));

    If Res > 0 Then
      BlockWrite (F, Buf[1], Res)
    Else
      Break;
  Until False;

  Close (F);

  Server.Status(ProcessID, 'Receive complete');

  If Result Then
    Client.WriteLine (re_XferOK);

  CloseDataSession;

  InTransfer := False;
End;

Procedure TFTPServer.SendFile (Str: String);
Var
  F   : File;
  Buf : Array[1..FileXferSize] of Byte;
  Tmp : LongInt;
  Res : LongInt;
Begin
  Assign  (F, Str);
  ioReset (F, 1, fmRWDN);

  InTransfer := True;

  OpenDataSession;

  Server.Status(ProcessID, 'Sending: ' + Str);

  While Not Eof(F) Do Begin
    BlockRead (F, Buf, SizeOf(Buf), Res);

    Repeat
      Tmp := DataSocket.WriteBuf(Buf, Res);

      Dec (Res, Tmp);
    Until Res <= 0;
  End;

  Close (F);

  Server.Status(ProcessID, 'Send complete');

  Client.WriteLine (re_XferOK);

  CloseDataSession;

  InTransfer := False;
End;

Function QWKHasAccess (Owner: Pointer; ACS: String) : Boolean;
Begin
  Result := CheckAccess(TQWKEngine(Owner).UserRecord, True, ACS);
End;

Function TFTPServer.QWKCreatePacket : Boolean;
Var
  QWK : TQwkEngine;
Begin
  // need to change temppath to a unique directory created for this
  // ftp instance.  before that we need to push a unique ID to this
  // session.

  QWK := TQwkEngine.Create(TempPath, GetQWKName, UserPos, User);

  QWK.HasAccess   := @QWKHasAccess;
  QWK.IsNetworked := User.Flags AND UserQWKNetwork <> 0;
  QWK.IsExtended  := User.QwkExtended;

  QWK.CreatePacket;
  QWK.UpdateLastReadPointers;
  QWK.Free;

  ExecuteArchive (TempPath, TempPath + GetQWKName + '.qwk', User.Archive, TempPath + '*', 1);
  SendFile       (TempPath + GetQWKName + '.qwk');

  DirClean (TempPath, '');
End;

Procedure TFTPServer.QWKProcessREP;
Var
  QWK : TQwkEngine;
Begin
  // need to change temppath to a unique directory created for this
  // ftp instance.  before that we need to push a unique ID to this
  // session.

  RecvFile       (TempPath + GetQWKName + '.rep', False);
  ExecuteArchive (TempPath, TempPath + GetQWKName + '.rep', User.Archive, '*', 2);

  QWK := TQwkEngine.Create(TempPath, GetQWKName, UserPos, User);

  QWK.HasAccess   := @QWKHasAccess;
  QWK.IsNetworked := User.Flags AND UserQWKNetwork <> 0;
  QWK.IsExtended  := User.QwkExtended;

  QWK.ProcessReply;
  QWK.Free;

  // update user stats posts and bbs history if not networked
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

    Server.Status (ProcessID, User.Handle + ' logged in');
  End Else
    Client.WriteLine(re_BadPW);
End;

Procedure TFTPServer.cmdREIN;
Begin
  ResetSession;

  If Not Client.WriteFile('220', bbsConfig.DataPath + 'ftpbanner.txt') Then
    Client.WriteLine (re_Greeting);
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
  WaitSock : TIOSocket;
Begin
  If LoggedIn Then Begin
    If Not bbsConfig.inetFTPPassive Then Begin
      Client.WriteLine(re_BadCommand);
      Exit;
    End;

    DataPort := Random(bbsConfig.inetFTPPortMax - bbsConfig.inetFTPPortMin) + bbsConfig.inetFTPPortMin;

    {$IFDEF FTPDEBUG}
      LOG('PASV on host ' + Client.HostIP + ' port ' + strI2S(DataPort));

      Server.Status(ProcessID, re_PassiveOK + '(' + strReplace(Client.HostIP, '.', ',') + ',' + strI2S(WordRec(DataPort).Hi) + ',' + strI2S(WordRec(DataPort).Lo) + ').');
    {$ENDIF}

    Client.WriteLine(re_PassiveOK + '(' + strReplace(Client.HostIP, '.', ',') + ',' + strI2S(WordRec(DataPort).Hi) + ',' + strI2S(WordRec(DataPort).Lo) + ').');

    IsPassive := True;
    WaitSock  := TIOSocket.Create;

    WaitSock.FTelnetServer := False;
    WaitSock.FTelnetClient := False;

    {$IFDEF FTPDEBUG} LOG('PASV Init'); {$ENDIF}

    WaitSock.WaitInit(bbsConfig.inetInterface, DataPort);

    {$IFDEF FTPDEBUG} LOG('PASV Wait'); {$ENDIF}

    DataSocket := WaitSock.WaitConnection(10000);

    {$IFDEF FTPDEBUG} LOG('PASV WaitDone'); {$ENDIF}

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
  TempBase  : RecFileBase;
  TempPos   : LongInt;
Begin
  If LoggedIn Then Begin
    If (Data = '/') or (Copy(Data, 1, 2) = '..') Then Begin
      FBasePos := -1;

      Client.WriteLine(re_DirOkay + '"/"');

      Exit;
    End;

    TempPos := FindDirectory(TempBase);

    If (TempPos = -1) Or Not ValidDirectory(TempBase) Then Begin
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
  TempBase : RecFileBase;
  TempPos  : LongInt;
  DirFile  : TFileBuffer;
  Dir      : RecFileList;
Begin
  If LoggedIn Then Begin
    TempPos := FindDirectory(TempBase);

    If (TempPos = -1) Or Not ValidDirectory(TempBase) Then Begin
      OpenDataSession;
      CloseDataSession;

      Exit;
    End;

    OpenDataSession;

    DirFile := TFileBuffer.Create(FileBufSize);

    If DirFile.OpenStream (bbsConfig.DataPath + TempBase.FileName + '.dir', SizeOf(RecFileList), fmOpenCreate, fmRWDN) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.ReadRecord (Dir);

        If (Dir.Flags And FDirDeleted <> 0) Then Continue;
        If (Dir.Flags And FDirInvalid <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeUnvalid)) Then Continue;
        If (Dir.Flags And FDirFailed <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeFailed)) Then Continue;

        If WildMatch(FileMask, Dir.FileName, False) Then
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
  TempBase  : RecFileBase;
  TempPos   : LongInt;
  FBaseFile : TFileBuffer;
  DirFile   : TFileBuffer;
  Dir       : RecFileList;
Begin
  {$IFDEF FTPDEBUG} LOG('LIST Calling FindDirectory'); {$ENDIF}

  If LoggedIn Then Begin
    TempPos := FindDirectory(TempBase);

    {$IFDEF FTPDEBUG} LOG('Back From FindDirectory.  Result ' + strI2S(TempPos)); {$ENDIF}

    If TempPos = -1 Then Begin
      {$IFDEF FTPDEBUG} LOG('Opening data session'); {$ENDIF}

      OpenDataSession;

      {$IFDEF FTPDEBUG} LOG('Back from data session'); {$ENDIF}

      // if qwlbyFTP.acs then
      DataSocket.WriteLine('-rw-r--r--   1 ftp      ftp ' + strPadL('0', 13, ' ') + ' ' + GetFTPDate(CurDateDos) + ' ' + GetQWKName + '.qwk');

      FBaseFile := TFileBuffer.Create(FileBufSize);

      If FBaseFile.OpenStream (bbsConfig.DataPath + 'fbases.dat', SizeOf(RecFileBase), fmOpen, fmRWDN) Then Begin
        While Not FBaseFile.EOF Do Begin
          FBaseFile.ReadRecord (TempBase);

          If ValidDirectory(TempBase) and WildMatch(FileMask, TempBase.FtpName, False) Then
            DataSocket.WriteLine('drwxr-xr-x   1 ftp      ftp             0 ' + GetFTPDate(TempBase.Created) + ' ' + TempBase.FtpName)
        End;
      End;

      FBaseFile.Free;

      CloseDataSession;

      Exit;
    End;

    If Not ValidDirectory(TempBase) Then Begin
      Client.WriteLine(re_BadCommand);

      Exit;
    End;

    OpenDataSession;

    DirFile := TFileBuffer.Create(FileBufSize);

    If DirFile.OpenStream (bbsConfig.DataPath + TempBase.FileName + '.dir', SizeOf(RecFileList), fmOpenCreate, fmRWDN) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.ReadRecord (Dir);

        If (Dir.Flags And FDirDeleted <> 0) Then Continue;
        If (Dir.Flags and FDirOffline <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeOffline)) Then Continue;
        If (Dir.Flags And FDirInvalid <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeUnvalid)) Then Continue;
        If (Dir.Flags And FDirFailed  <> 0) And (Not CheckAccess(User, True, bbsConfig.AcsSeeFailed))  Then Continue;

        If WildMatch(FileMask, Dir.FileName, False) Then
          DataSocket.WriteLine('-rw-r--r--   1 ftp      ftp ' + strPadL(strI2S(Dir.Size), 13, ' ') + ' ' + GetFTPDate(Dir.DateTime) + ' ' + Dir.FileName)
      End;
    End;

    DirFile.Free;

    DataSocket.WriteLine('-rw-r--r--   1 ftp      ftp ' + strPadL('0', 13, ' ') + ' ' + GetFTPDate(CurDateDos) + ' ' + GetQWKName + '.qwk');

    CloseDataSession;
  End Else
    Client.WriteLine(re_BadCommand);
End;

Procedure TFTPServer.cmdSTOR (IsAppend: Boolean);
Var
  TempPos  : LongInt;
  TempBase : RecFileBase;
  BaseFile : File;
  CurDIR   : String;
  DizFile  : Text;
  Desc     : FileDescBuffer;
  DescSize : Byte;
  Dir      : RecFileList;
  DirPos   : LongInt = -1;
  DesFile  : File;
  Count    : Byte;
Begin
  If Not LoggedIn Then Begin
    Client.WriteLine(re_BadCommand);

    Exit;
  End;

  If strUpper(Data) = strUpper(GetQWKName + '.rep') Then Begin
    QWKProcessREP;

    Exit;
  End;

  TempPos := FindDirectory(TempBase);

  If (TempPos = -1) Or Not ValidDirectory(TempBase) Then Begin
    Client.WriteLine(re_NoAccess + ': Directory not found');

    Exit;
  End;

  If bbsCfg.UploadBase > 0 Then Begin
    Assign  (BaseFile, bbsCfg.DataPath + 'fbases.dat');
    ioReset (BaseFile, SizeOf(RecMessageBase), fmRWDN);

    If ioSeek (BaseFile, bbsCfg.UploadBase - 1) Then
      ioRead (BaseFile, TempBase);

    Close (BaseFile);
  End;

  If (Not CheckAccess (User, True, TempBase.ULACS)) or
     (TempBase.Flags AND FBSlowMedia <> 0) or
     (Length(FileMask) > 70) Then Begin

       Client.WriteLine(re_NoAccess);

       Exit;
  End;

  If bbsCfg.FreeUL > 0 Then Begin
    GetDIR (0, CurDIR);

    {$I-} ChDIR (TempBase.Path); {$I+}

    If (IoResult <> 0) or (DiskFree(0) DIV 1024 < bbsCfg.FreeUL) Then Begin
      ChDIR (CurDIR);

      Client.WriteLine(re_NoAccess + ': No disk space');

      Exit;
    End;

    ChDIR (CurDIR);
  End;

  If Not IsAppend And IsDuplicateFile (TempBase, FileMask, bbsCfg.FDupeScan = 2) Then Begin
    Client.WriteLine(re_BadFile);

    Exit;
  End;

  RecvFile (TempBase.Path + JustFile(Data), IsAppend);

  ImportFileDIZ(Desc, DescSize, TempPath, TempBase.Path + JustFile(Data));

  If DescSize = 0 Then Begin
    DescSize := 1;
    Desc[1]  := 'No Description';
  End;

  Assign (BaseFile, BbsCfg.DataPath + TempBase.FileName + '.dir');

  If Not ioReset (BaseFile, SizeOf(RecFileList), fmRWDW) Then
    ioReWrite (BaseFile, SizeOf(RecFileList), fmRWDW);

  If IsAppend Then Begin
    While Not Eof(BaseFile) Do Begin
      ioRead (BaseFile, Dir);

      If JustFile(Data) = Dir.FileName Then Begin
        DirPos := FilePos(BaseFile);

        Break;
      End;
    End;
  End;

  If DirPos = -1 Then Begin
    FillChar (Dir, SizeOf(Dir), 0);

    Dir.FileName  := JustFile(Data);
    Dir.DateTime  := CurDateDOS;
    Dir.Uploader  := User.Handle;
  End;

  Dir.DescLines := DescSize;
  Dir.Size      := FileByteSize(TempBase.Path + JustFile(Data));

  Assign (DesFile, BbsCfg.DataPath + TempBase.FileName + '.des');

  If Not ioReset (DesFile, 1, fmRWDW) Then
    ioReWrite (DesFile, 1, fmRWDW);

  Dir.DescPtr := FileSize(DesFile);

  Seek (DesFile, Dir.DescPtr);

  For Count := 1 to DescSize Do
    BlockWrite (DesFile, Desc[Count][0], Length(Desc[Count]) + 1);

  Close (DesFile);

  If DirPos = -1 Then
    Seek (BaseFile, FileSize(BaseFile))
  Else
    Seek (BaseFile, DirPos - 1);

  ioWrite (BaseFile, Dir);
  Close   (BaseFile);

  // dreadful things required to do for upload process:

  // find upload base -- done
  // check diskspace -- done
  // check slowmedia -- done
  // check access -- done
  // check filename length -- done
  // duplicate file checking -- done
  // get file -- done
  // update user statistics
  // update history statistics
  // archive testing
  // file_id.diz importing -- done?
  // save file to db (or update if append)
  // test all of it.

  // other things: add no desc and ftp test batch to configuration?
End;

Procedure TFTPServer.cmdRETR;
Var
  TempPos  : LongInt;
  TempBase : RecFileBase;
  DirFile  : TFileBuffer;
  Dir      : RecFileList;
  Found    : LongInt;
Begin
  If LoggedIn Then Begin

    If strUpper(Data) = strUpper(GetQWKName + '.qwk') Then Begin
      QWKCreatePacket;

      Exit;
    End;

    TempPos := FindDirectory(TempBase);

    If TempPos = -1 Then Begin
      Client.WriteLine(re_BadFile);

      Exit;
    End;

    DirFile := TFileBuffer.Create(FileBufSize);
    Found   := -1;

    If DirFile.OpenStream (bbsConfig.DataPath + TempBase.FileName + '.dir', SizeOf(RecFileList), fmOpenCreate, fmRWDN) Then Begin
      While Not DirFile.EOF Do Begin
        DirFile.ReadRecord (Dir);

        If WildMatch(FileMask, Dir.FileName, False) Then Begin
          Found := DirFile.FilePosRecord;

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
              SendFile        (TempBase.Path + Dir.FileName);
              UpdateUserStats (TempBase, Dir, Found, False);
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
  WaitSock : TIOSocket;
Begin
  If LoggedIn Then Begin
    If Data = '' Then Begin
      DataPort  := Random(bbsConfig.inetFTPPortMax - bbsConfig.inetFTPPortMin) + bbsConfig.inetFTPPortMin;
      IsPassive := True;

      Client.WriteLine('229 Entering Extended Passive Mode (|||' + strI2S(DataPort) + '|)');

      WaitSock := TIOSocket.Create;

      WaitSock.WaitInit(bbsConfig.inetInterface, DataPort);

      DataSocket := WaitSock.WaitConnection(10000);

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
    {$IFDEF FTPDEBUG} LOG('Execute loop'); {$ENDIF}

    If Client.WaitForData(bbsConfig.inetFTPTimeout * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    {$IFDEF FTPDEBUG}
      LOG('Cmd: ' + Cmd + ' Data: ' + Data);
    {$ENDIF}

//    Server.Status (ProcessID, 'Cmd: ' + Cmd + ' Data: ' + Data);

    If Cmd = 'APPE' Then cmdSTOR(True) Else
    If Cmd = 'CDUP' Then cmdCDUP Else
    If Cmd = 'CWD'  Then cmdCWD  Else
    If Cmd = 'DELE' Then Client.WriteLine(re_NoAccess) Else
    If Cmd = 'EPRT' Then cmdEPRT Else
    If Cmd = 'EPSV' Then cmdEPSV Else
    If Cmd = 'LIST' Then cmdLIST Else
    If Cmd = 'MKD'  Then Client.WriteLine(re_NoAccess) Else
    If Cmd = 'MODE' Then cmdMODE Else
    If Cmd = 'NLST' Then cmdNLST Else
    If Cmd = 'NOOP' Then Client.WriteLine(re_CommandOK) Else
    If Cmd = 'PASS' Then cmdPASS Else
    If Cmd = 'PASV' Then cmdPASV Else
    If Cmd = 'PORT' Then cmdPORT Else
    If Cmd = 'PWD'  Then cmdPWD  Else
    If Cmd = 'REIN' Then cmdREIN Else
    If Cmd = 'RETR' Then cmdRETR Else
    If Cmd = 'RMD'  Then Client.WriteLine(re_NoAccess) Else
    If Cmd = 'SIZE' Then cmdSIZE Else
    If Cmd = 'STOR' Then cmdSTOR(False) Else
    // implement STOU which in turn calls cmdSTOR after getting filename
    If Cmd = 'STRU' Then cmdSTRU Else
    If Cmd = 'SYST' Then cmdSYST Else
    If Cmd = 'TYPE' Then cmdTYPE Else
    If Cmd = 'USER' Then cmdUSER Else
    If Cmd = 'XPWD' Then cmdPWD  Else
    If Cmd = 'QUIT' Then Begin
      GotQuit := True;

      Break;
    End Else
      Client.WriteLine(re_NoCommand);
  Until Terminated;

  If GotQuit Then Begin
    Client.WriteLine(re_Goodbye);

    Server.Status (ProcessID, User.Handle + ' logged out');
  End;
End;

Destructor TFTPServer.Destroy;
Begin
  If Assigned(DataSocket) Then DataSocket.Free;

  Inherited Destroy;
End;

End.

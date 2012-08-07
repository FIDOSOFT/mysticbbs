Unit bbs_FileBase;

{$I M_OPS.PAS}
{$MODESWITCH NESTEDPROCVARS-}

Interface

Uses
  DOS,
  mkCrap,
  m_Strings,
  m_FileIO,
  m_DateTime,
  bbs_Common,
  bbs_General,
  bbs_NodeInfo,
  AView;

Type
  BatchRec = Record
    FileName : String[70];
    Area     : Integer;
    Size     : LongInt;
  End;

  TFileBase = Class
    FBaseFile    : File of RecFileBase;
    FDirFile     : File of RecFileList;
    FScanFile    : File of FScanRec;
    ProtocolFile : File of RecProtocol;
    FGroupFile   : File of RecGroup;
    ArcFile      : File of RecArchive;
    FBase        : RecFileBase;
    FGroup       : RecGroup;
    FScan        : FScanRec;
    FDir         : RecFileList;
    Arc          : RecArchive;
    Protocol     : RecProtocol;
    BatchNum     : Byte;
    Batch        : Array[1..mysMaxBatchQueue] of BatchRec;

    Constructor Create (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Procedure   dszGetFile            (Var LogFile: Text; Var FName: String; Var Res: Boolean);
    Function    dszSearch             (FName: String) : Boolean;
    Procedure   GetTransferTime       (Size: Longint; Var Mins : Integer; Var Secs: Byte);
    Procedure   ExecuteArchive        (FName: String; Temp: String; Mask: String; Mode: Byte);
    Procedure   ExecuteProtocol       (Send: Boolean; FName: String);
    Function    SelectArchive         : Boolean;
    Function    ListFileAreas         (Compress: Boolean) : Integer;
    Procedure   ChangeFileArea        (Data: String);
    Procedure   DownloadFile;
    Procedure   BatchClear;
    Procedure   BatchAdd;
    Procedure   BatchList;
    Procedure   BatchDelete;
    Procedure   SetFileScan;
    Procedure   GetFileScan;
    Function    SelectProtocol        (Batch : Boolean) : Char;
    Function    WildcardMatch         (Wildcard, FName: String) : Boolean;
    Procedure   CheckFileNameLength   (FPath : String; Var FName : String);
    Procedure   GetFileDescription    (FN: String);
    Function    CheckFileLimits       (DL: Byte; DLK: Integer) : Byte;
    Function    ArchiveList           (FName : String) : Boolean; { was string }
    Function    ImportDIZ             (FN: String) : Boolean;
    Function    IsDupeFile            (FileName : String; Global : Boolean) : Boolean;
    Function    ListFiles             (Mode : Byte; Data : String) : Byte;
    Procedure   SetFileScanDate;
    Function    CopiedToTemp          (FName: String) : Boolean;
    Function    SendFile              (Data: String) : Boolean;
    Procedure   DownloadFileList      (Data: String);
    Function    ExportFileList        (NewFiles: Boolean; Qwk: Boolean) : Boolean;
    Function    ArchiveView           (FName : String) : Boolean;
    Procedure   FileGroupChange       (Ops: String; FirstBase, Intro : Boolean);
    Procedure   UploadFile;
    Procedure   DownloadBatch;
    Procedure   NewFileScan           (Mode: Char);
    Procedure   ViewFile;
    Procedure   ToggleFileNewScan;
    Procedure   FileSearch;
    Procedure   DirectoryEditor       (Edit: Boolean; Mask: String);
    Procedure   MassUpload;
  End;

Implementation

Uses
  bbs_Core,
  MPL_Execute;

Constructor TFileBase.Create (Var Owner: Pointer);
Begin
  Inherited Create;

  FBase.Name  := 'None';
  FGroup.Name := 'None';
  BatchNum    := 0;
End;

Destructor TFileBase.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TFileBase.dszGetFile (Var LogFile: Text; Var FName: String; Var Res: Boolean);
Type
  TLineBuf = Array[0..1024] of Char;
Var
  LineBuf  : TLineBuf;
  TempStr1 : DirStr;
  TempStr2 : NameStr;
  TempStr3 : ExtStr;
  WordPos  : Integer;
  Count    : Integer;
Begin
  FName   := '';
  Res     := False;
  WordPos := 1;
  Count   := 1;

  If EOF(LogFile) Then Exit;

  FillChar(LineBuf, SizeOf(LineBuf), #0);

  ReadLn (LogFile, LineBuf);

  If LineBuf[0] = #0 Then Exit;

  Res := Pos(UpCase(LineBuf[0]), 'RSZ') > 0;

  While WordPos < 11 Do Begin
    If LineBuf[Count] = #32 Then Begin
      Inc (WordPos);
      Repeat
        Inc (Count);
      Until LineBuf[Count] <> #32;
    End Else
      Inc (Count);
  End;

  Repeat
    FName := FName + LineBuf[Count];
    Inc (Count);
  Until (LineBuf[Count] = #32) or (LineBuf[Count] = #0) or (Count = 1024);

  FSplit(FName, TempStr1, TempStr2, TempStr3);

  FName := TempStr2 + TempStr3;
End;

Function TFileBase.dszSearch (FName: String) : Boolean;
Var
  LogFile  : Text;
  FileName : String;
  Status   : Boolean;
Begin
  Result := False;

  Assign (LogFile, Session.TempPath + 'xfer.log');
  {$I-} Reset(LogFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.SystemLog('ERROR: Can''t find xfer.log');
    Exit;
  End;

  While Not Eof(LogFile) Do Begin
    dszGetFile(LogFile, FileName, Status);

    {$IFDEF FS_SENSITIVE}
      If FileName = FName Then Begin
    {$ELSE}
    If strUpper(FileName) = strUpper(FName) Then Begin
    {$ENDIF}
      Result := Status;
      Break;
    End;
  End;

  Close (LogFile);
End;

Procedure TFileBase.ExecuteProtocol (Send: Boolean; FName: String);
Var
  T     : Text;
  Cmd   : String;
  Count : Byte;
  Res   : String;
  Path  : String;
Begin
  If Send Then
    Cmd := Protocol.SendCmd
  Else
    Cmd := Protocol.RecvCmd;

  Res   := '';
  Path  := '';
  Count := 1;

  While Count <= Length(Cmd) Do Begin
    If Cmd[Count] = '%' Then Begin
      Inc(Count);
      {$IFNDEF UNIX}
      If Cmd[Count] = '0' Then Res := Res + strI2S(Session.Client.FSocketHandle) Else
      {$ENDIF}
      If Cmd[Count] = '1' Then Res := Res + '1' Else
      If Cmd[Count] = '2' Then Res := Res + strI2S(Session.Baud) Else
      If Cmd[Count] = '3' Then Res := Res + FName Else
      If Cmd[Count] = '4' Then Res := Res + Session.UserIPInfo Else
      If Cmd[Count] = '5' Then Res := Res + Session.UserHostInfo Else
      If Cmd[Count] = '6' Then Res := Res + strReplace(Session.User.ThisUser.Handle, ' ', '_') Else
      If Cmd[Count] = '7' Then Res := Res + strI2S(Session.NodeNum);
    End Else
      Res := Res + Cmd[Count];

    Inc (Count);
  End;

  {$IFDEF UNIX}
    Assign  (T, Session.TempPath + 'xfer.sh');
    ReWrite (T);
    WriteLn (T, 'export DSZLOG=' + Session.TempPath + 'xfer.log');
    WriteLn (T, Res);
    Close   (T);
  {$ELSE}
    Assign  (T, Session.TempPath + 'xfer.bat');
    ReWrite (T);
    WriteLn (T, 'SET DSZLOG=' + Session.TempPath + 'xfer.log');
    WriteLn (T, Res);
    Close   (T);
  {$ENDIF}

  { If uploading and batch, switch to upload directory via shelldos }
  If Not Send And Protocol.Batch Then Path := FName;

  If Res[1] = '!' Then Begin
    Delete     (Res, 1, 1);
    ExecuteMPL (NIL, Res);
  End Else
  {$IFDEF UNIX}
    ShellDOS (Path, 'sh ' + Session.TempPath + 'xfer.sh');
  {$ELSE}
    ShellDOS (Path, Session.TempPath + 'xfer.bat');
  {$ENDIF}

  DirChange (Config.SystemPath);
End;

Procedure TFileBase.GetTransferTime (Size: Longint; Var Mins : Integer; Var Secs: Byte);
Var
  B : LongInt;
Begin
  B := 0;
  If Not Session.LocalMode Then B := Size DIV (Session.Baud DIV 10);
  Mins := B DIV 60;
  Secs := B MOD 60;
End;

Function TFileBase.ImportDIZ (FN: String) : Boolean;

  Procedure RemoveLine (Num: Byte);
  Var
    A : Byte;
  Begin
    For A := Num To FDir.DescLines - 1 Do
      Session.Msgs.Msgtext[A] := Session.Msgs.MsgText[A + 1];

    Session.Msgs.MsgText[FDir.DescLines] := '';

    Dec (FDir.DescLines);
  End;

Var
  tFile : Text;
Begin
  Result := False;

  ExecuteArchive (FBase.Path + FN, '', 'file_id.diz', 2);

  Assign (tFile, Session.TempPath + 'file_id.diz');
  {$I-} Reset (tFile); {$I+}

  If IoResult = 0 Then Begin
    Result         := True;
    FDir.DescLines := 0;

    While Not Eof(tFile) Do Begin
      Inc    (FDir.DescLines);
      ReadLn (tFile, Session.Msgs.MsgText[FDir.DescLines]);

      Session.Msgs.MsgText[FDir.DescLines] := strStripLOW(Session.Msgs.MsgText[FDir.DescLines]);

      If Length(Session.Msgs.MsgText[FDir.DescLines]) > mysMaxFileDescLen Then Session.Msgs.MsgText[FDir.DescLines][0] := Chr(mysMaxFileDescLen);

      If FDir.DescLines = Config.MaxFileDesc Then Break;
    End;

    Close (tFile);

    FileErase(Session.TempPath + 'file_id.diz');

    While (Session.Msgs.MsgText[1] = '') and (FDir.DescLines > 0) Do
      RemoveLine(1);

    While (Session.Msgs.MsgText[FDir.DescLines] = '') And (FDir.DescLines > 0) Do
      Dec (FDir.DescLines);
  End;
End;

Procedure TFileBase.SetFileScan;
Var
  A    : Integer;
  Temp : FScanRec;
Begin
  Temp.NewScan := FBase.DefScan;
  Temp.LastNew := CurDateDos;

  If Temp.NewScan = 2 Then Dec(Temp.NewScan);

  Assign (FScanFile, Config.DataPath + FBase.FileName + '.scn');
  {$I-} Reset (FScanFile); {$I+}

  If IoResult <> 0 Then ReWrite (FScanFile);

  If FileSize(FScanFile) < Session.User.UserNum - 1 Then Begin
    Seek (FScanFile, FileSize(FScanFile));
    For A := FileSize(FScanFile) to Session.User.UserNum - 1 Do
      Write (FScanFile, Temp);
  End;

  Seek  (FScanFile, Session.User.UserNum - 1);
  Write (FScanFile, FScan);
  Close (FScanFile);
End;

Procedure TFileBase.GetFileScan;
Begin
  FScan.NewScan := FBase.DefScan;
  FScan.LastNew := CurDateDos;

  If FScan.NewScan = 2 Then Dec(FScan.NewScan);

  Assign (FScanFile, Config.DataPath + FBase.FileName + '.scn');
  {$I-} Reset (FScanFile); {$I+}

  If IoResult <> 0 Then Exit;

  If FileSize(FScanFile) >= Session.User.UserNum Then Begin
    Seek (FScanFile, Session.User.UserNum - 1);
    Read (FScanFile, FScan);
  End;

  Close (FScanFile);
End;

Procedure TFileBase.SetFileScanDate;
Var
  L   : LongInt;
  Old : RecFileBase;
  Str : String;
Begin
  Session.io.OutFull (Session.GetPrompt(255));

  If FBase.FileName <> '' Then Begin
    GetFileScan;
    L := FScan.LastNew;
  End Else
    L := CurDateDos;

  Str := Session.io.GetInput(8, 8, 15, DateDos2Str(L, Session.User.ThisUser.DateType));

  If Not DateValid(Str) Then Exit;

  L := DateStr2Dos(Str);

  If Session.io.GetYN (Session.GetPrompt(256), True) Then Begin
    Reset (FBaseFile);
    Old := FBase;

    While Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, FBase);
      GetFileScan;
      FScan.LastNew := L;
      SetFileScan;
    End;

    Close (FBaseFile);
    FBase := Old;
  End Else Begin
    If FBase.FileName = '' Then Begin
      Session.io.OutFullLn (Session.GetPrompt(38));
      Exit;
    End;
    GetFileScan;
    FScan.LastNew := L;
    SetFileScan;
  End;

  Session.io.PromptInfo[1] := DateDos2Str(L, Session.User.ThisUser.DateType);
  Session.io.OutFull (Session.GetPrompt(257));
End;

Function TFileBase.SendFile (Data: String) : Boolean;
Begin
  Result := False;

  If Not FileExist(Data) Then Exit;

  If SelectProtocol(False) = 'Q' Then Exit;

  ExecuteProtocol(True, Data);

  Session.io.OutRawLn ('');

  Session.io.PromptInfo[1] := JustFile(Data);

  If dszSearch(JustFile(Data)) Then Begin
    Result := True;
    Session.io.OutFullLn (Session.GetPrompt(385));
  End Else
    Session.io.OutFullLn (Session.GetPrompt(386));

  DirClean(Session.TempPath, '');
End;

Procedure TFileBase.DownloadFileList (Data: String);
Var
  A        : Byte;
  NewFiles : Boolean;
  FileName : String[12];
Begin
  NewFiles := False;
  FileName := 'allfiles.';

  For A := 1 to strWordCount(Data, ' ') Do
    If Pos('/NEW', strWordGet(A, Data, ' ')) > 0 Then Begin
      NewFiles := True;
      FileName := 'newfiles.';
    End Else
    If Pos('/ALLGROUP', strWordGet(A, Data, ' ')) > 0 Then
      Session.User.IgnoreGroup := True;

  If ExportFileList(NewFiles, False) Then Begin
    If Session.io.GetYN (Session.GetPrompt(227), True) Then Begin
      FileName := FileName + Session.User.ThisUser.Archive;
      ExecuteArchive (Session.TempPath + FileName, Session.User.ThisUser.Archive, Session.TempPath + '*', 1);
    End Else
      FileName := FileName + 'txt';

    SendFile (Session.TempPath + FileName);
  End;

  DirClean(Session.TempPath, '');

  Session.User.IgnoreGroup := False;
End;

Function TFileBase.ExportFileList (NewFiles : Boolean; Qwk: Boolean) : Boolean;
Var
  TF         : Text;
  DF         : File;
  A          : Byte;
  Temp       : String[mysMaxFileDescLen];
  Str        : String;
  AreaFiles  : Integer;
  AreaSize   : LongInt;
  TotalFiles : LongInt;
Begin
  If NewFiles Then Begin
    If Qwk Then Temp := 'newfiles.dat' Else Temp := 'newfiles.txt';
    Session.io.OutFullLn (Session.GetPrompt(219));
  End Else Begin
    Temp := 'allfiles.txt';
    Session.io.OutFullLn (Session.GetPrompt(220));
  End;

  Session.io.OutFullLn (Session.GetPrompt(221));

  Assign  (TF, Session.TempPath + Temp);
  ReWrite (TF);

  TotalFiles := 0;

  Reset (FBaseFile);

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);
    If Session.User.Access(FBase.ListACS) Then Begin
      Session.io.OutFull (Session.GetPrompt(222));

      GetFileScan;

      AreaFiles := 0;
      AreaSize  := 0;

      WriteLn (TF, '');
      WriteLn (TF, '.-' + strRep('-', Length(strStripPipe(FBase.Name))) + '-.');
      WriteLn (TF, '| ' + strStripPipe(FBase.Name) + ' |');
      WriteLn (TF, '`-' + strRep('-', Length(strStripPipe(FBase.Name))) + '-''');
      WriteLn (TF, '.' + strRep('-', 77) + '.');
      WriteLn (TF, '| File     Size    Date    Description                                        |');
      WriteLn (TF, '`' + strRep('-', 77) + '''');

      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
      {$I-} Reset (FDirFile); {$I+}
      If IoResult = 0 Then Begin
        Assign (DF, Config.DataPath + FBase.FileName + '.des');
        {$I-} Reset (DF, 1); {$I+}

        If IoResult <> 0 Then ReWrite (DF, 1);

        While Not Eof(FDirFile) Do Begin
          Read (FDirFile, FDir);
          If (NewFiles and (FDir.DateTime > FScan.LastNew)) or Not NewFiles Then
            If FDir.Flags And FDirDeleted = 0 Then Begin
              Inc (TotalFiles);
              Inc (AreaFiles);
              Inc (AreaSize, FDir.Size DIV 1024);

              WriteLn (TF, FDir.FileName);
              Write   (TF, ' `- ' + strPadL(strComma(FDir.Size), 11, ' ') + '  ' + DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType) + '  ');

              Seek (DF, FDir.DescPtr);
              For A := 1 to FDir.DescLines Do Begin
                BlockRead (DF, Temp[0], 1);
                BlockRead (DF, Temp[1], Ord(Temp[0]));
                If A = 1 Then WriteLn (TF, Temp) Else WriteLn (TF, strRep(' ', 27) + Temp);
              End;
            End;
        End;

        Session.io.PromptInfo[2] := strI2S(FileSize(FDirFile));

        Close (FDirFile);
        Close (DF);

        SetFileScan;

        Str := 'Total files: ' + strI2S(AreaFiles) + ' (' + strI2S(AreaSize) + 'k)';

        WriteLn (TF, '.' + strRep('-', 77) + '.');
        WriteLn (TF, '| ' + strPadR(Str, 76, ' ') + '|');
        WriteLn (TF, '`' + strRep('-', 77) + '''');
      End Else
        Session.io.PromptInfo[2] := '0';

      Session.io.PromptInfo[1] := FBase.Name;
      Session.io.PromptInfo[3] := strI2S(AreaFiles);

      Session.io.OutBS (Screen.CursorX, False);
      Session.io.OutFullLn (Session.GetPrompt(223));
    End;
  End;

  Close (FBaseFile);
  Close (TF);

  Session.io.OutFullLn (Session.GetPrompt(225));

  Result := (TotalFiles = 0);

  If Not Result Then Session.io.OutFullLn(Session.GetPrompt(425));
End;

Function TFileBase.WildcardMatch (Wildcard, FName: String) : Boolean;
Begin
  Result := False;

  If FName = '' Then Exit;

  Case Wildcard[1] of
    '*' : Begin
            If FName[1] = '.' Then Exit;
            If Length(Wildcard) = 1 Then Result := True;
            If (Length(Wildcard) > 1) and (Wildcard[2] = '.') and (Length(FName) > 0) Then
              Result := WildCardMatch(Copy(Wildcard, 3, Length(Wildcard) - 2), Copy(FName, Pos('.', FName) + 1, Length(FName)-Pos('.', FName)));
          End;
    '?' : If Ord(Wildcard[0]) = 1 Then
            Result := True
          Else
            Result := WildCardMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1));
  Else
    If FName[1] = Wildcard[1] Then
      If Length(wildcard) > 1 Then
        Result := WildCardMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1))
      Else
        Result := (Length(FName) = 1) And (Length(Wildcard) = 1);
  End;
End;

Function TFileBase.ArchiveList (FName : String) : Boolean;
Var
  Arc : PArchive;
  SR  : ArcSearchRec;
  D   : DirStr;
  N   : NameStr;
  E   : ExtStr;
Begin
  Result := False;
  Arc    := New(PArchive, Init);

  If Not Arc^.Name(FName) Then Begin
    Dispose (Arc,  Done);

    If FileExist(FName) Then Begin
      ExecuteArchive (FName, '', '_view_.tmp', 3);
      Session.io.OutFile      (Session.TempPath + '_view_.tmp', True, 0);
      FileErase    (Session.TempPath + '_view_.tmp');
    End;
    Exit;
  End;

  Session.io.AllowPause := True;
  Session.io.PausePtr   := 1;

  FSplit (FName, D, N, E);  {make getpath and getfname functions???}

  Session.io.PromptInfo[1] := N + E;

  Session.io.OutFullLn (Session.GetPrompt(192));

  Arc^.FindFirst(SR);

  While SR.Name <> '' Do Begin
    Session.io.PromptInfo[1] := SR.Name;

    If SR.Attr = $10 Then
      Session.io.PromptInfo[2] := '<DIRECTORY>' {++lang}
    Else
      Session.io.PromptInfo[2] := strComma(SR.Size);

    Session.io.PromptInfo[3] := DateDos2Str(SR.Time, Session.User.ThisUser.DateType);
    Session.io.PromptInfo[4] := TimeDos2Str(SR.Time, True);

    Session.io.OutFullLn (Session.GetPrompt(193));

    If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Break;
        'C' : Session.io.AllowPause := False;
      End;

    Arc^.FindNext(SR);
  End;

  Dispose (Arc, Done);

  Result := True;

  Session.io.OutFull (Session.GetPrompt(194));
End;

Function TFileBase.CheckFileLimits (DL: Byte; DLK: Integer) : Byte;
{ 0 = OK to download }
{ 1 = Offline or Invalid or Failed : NO ACCESS (prompt 224)}
{ 2 = DL per day limit exceeded (prompt 58) }
{ 3 = UL/DL file ratio bad (prompt 211) }
Var
  A : Byte;
Begin
  Result := 1;

  If FDir.Flags And FDirOffline <> 0 Then Exit;

  If (FDir.Flags And FDirInvalid <> 0) And Not Session.User.Access(Config.AcsDLUnvalid) Then Exit;
  If (FDir.Flags And FDirFailed  <> 0) And Not Session.User.Access(Config.AcsDLFailed)  Then Exit;

  If (FDir.Flags And FDirFree <> 0) or (Session.User.ThisUser.Flags and UserNoRatio <> 0) or (FBase.Flags and FBFreeFiles <> 0) Then Begin
    Result := 0;
    Exit;
  End;

  If (Session.User.ThisUser.DLsToday + BatchNum + DL > Session.User.Security.MaxDLs) and (Session.User.Security.MaxDLs > 0) Then Begin
    Result := 2;
    Exit;
  End;

  If Session.User.Security.DLRatio > 0 Then
    If (Session.User.ThisUser.ULs * Session.User.Security.DLRatio) <= (Session.User.ThisUser.DLs + BatchNum + DL) Then Begin
      Result := 3;
      Exit;
    End;

  If BatchNum > 0 Then
    For A := 1 to BatchNum Do
      Inc (DLK, Batch[A].Size DIV 1024);

  If Session.User.Security.DLKRatio > 0 Then
    If (Session.User.ThisUser.ULk * Session.User.Security.DLkRatio) <= (Session.User.ThisUser.DLk + DLk) Then Begin
      Result := 3;
      Exit;
    End;

  If (Session.User.ThisUser.DLkToday + DLk > Session.User.Security.MaxDLk) and (Session.User.Security.MaxDLk > 0) Then Begin
    Result := 2;
    Exit;
  End;

  Result := 0;
End;

Function TFileBase.ArchiveView (FName : String) : Boolean;
Var
  Mask : String[70];
Begin
  Result := False;

  If Not ArchiveList(FName) Then Exit;

  Result := True;

  Repeat
    Session.io.OutFull (Session.GetPrompt(304));
    Case Session.io.OneKey('DQRV', True) of
      'D' : Begin
              Session.io.OutFull (Session.GetPrompt(384));

              Mask := Session.io.GetInput (70, 70, 11, '');

              If Mask <> '' Then Begin
                ExecuteArchive (FName, '', Mask, 2);

                If FileExist(Session.TempPath + Mask) Then Begin
                  Case CheckFileLimits (1, GetFileSize(Session.TempPath + Mask) DIV 1024) of
                    0 : If SendFile (Session.TempPath + Mask) Then Begin;
                          Session.SystemLog ('Download from ' + FName + ': ' + Mask);

                          Inc (Session.User.ThisUser.DLs);
                          Inc (Session.User.ThisUser.DLsToday);
                          Inc (Session.User.ThisUser.DLk, FDir.Size DIV 1024);
                          Inc (Session.User.ThisUser.DLkToday, FDir.Size DIV 1024);
                          Inc (Session.HistoryDLs);
                          Inc (Session.HistoryDLKB, FDir.Size DIV 1024);
                        End;
                    1 : Session.io.OutFullLn (Session.GetPrompt(224));
                    2 : Session.io.OutFullLn (Session.GetPrompt(58));
                    3 : Session.io.OutFullLn (Session.GetPrompt(211));
                  End;

                  FileErase(Session.TempPath + Mask);
                End;
              End;
            End;
      'Q' : Exit;
      'R' : ArchiveList(FName);
      'V' : Begin
              Session.io.OutFull (Session.GetPrompt(384));
              Mask := Session.io.GetInput (70, 70, 11, '');
              If Mask <> '' Then Begin
                ExecuteArchive (FName, '', Mask, 2);

                Session.io.PromptInfo[1] := Mask;
                Session.io.OutFullLn(Session.GetPrompt(306));
                Session.io.AllowMCI := False;
                Session.io.OutFile (Session.TempPath + Mask, True, 0);
                Session.io.AllowMCI := True;

                If Session.io.NoFile Then
                  Session.io.OutFullLn (Session.GetPrompt(305))
                Else
                  FileErase(Session.TempPath + Mask);
              End;
            End;
    End;
  Until False;
End;

Procedure TFileBase.ToggleFileNewScan;
Var
  Total : Word;

  Procedure List_Bases;
  Begin
    Session.io.PausePtr   := 1;
    Session.io.AllowPause := True;

    Session.io.OutFullLn (Session.GetPrompt(200));

    Total  := 0;

    Reset (FBaseFile);

    While Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, FBase);

      If Session.User.Access(FBase.ListACS) Then Begin
        Inc (Total);
        Session.io.PromptInfo[1] := strI2S(Total);
        Session.io.PromptInfo[2] := FBase.Name;

        GetFileScan;

        Session.io.PromptInfo[3] := Session.io.OutYN(FScan.NewScan > 0);
        Session.io.OutFull (Session.GetPrompt(201));

        If (Total MOD Config.FColumns = 0) And (Total > 0) Then Session.io.OutRawLn('');
      End;

      If EOF(FBaseFile) and (Total MOD Config.FColumns <> 0) Then Session.io.OutRawLn('');

      If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;

    Session.io.OutFull (Session.GetPrompt(449));
  End;

  Procedure ToggleBase (A : Word);
  Var
    B : Word;
  Begin
    B := 0;
    Reset (FBaseFile);
    Repeat
      Read (FBaseFile, FBase);
      If Session.User.Access(FBase.ListACS) Then Inc(B);
      If A = B Then Break;
    Until False;

    GetFileScan;
    Session.io.PromptInfo[1] := FBase.Name;

    If FBase.DefScan = 2 Then Begin
      FScan.NewScan := 1;
      Session.io.OutFullLn (Session.GetPrompt(289));
    End Else
    If FScan.NewScan = 0 Then Begin
      FScan.NewScan := 1;
      Session.io.OutFullLn (Session.GetPrompt(204));
    End Else Begin
      FScan.NewScan := 0;
      Session.io.OutFullLn (Session.GetPrompt(203));
    End;

    SetFileScan;
  End;

Var
  Old  : RecFileBase;
  Temp : String[11];
  A    : Word;
  N1   : Word;
  N2   : Word;
Begin
  Old := FBase;

  List_Bases;

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(37));
    FBase := Old;
    Exit;
  End;

  Repeat
    Session.io.OutFull (Session.GetPrompt(202));

    Temp := Session.io.GetInput(11, 11, 12, '');

    If (Temp = '') or (Temp = 'Q') Then Break;

    If Temp = '?' Then
      List_Bases
    Else Begin
      If Pos('-', Temp) > 0 Then Begin
        N1 := strS2I(Copy(Temp, 1, Pos('-', Temp) - 1));
        N2 := strS2I(Copy(Temp, Pos('-', Temp) + 1, Length(Temp)));
      End Else Begin
        N1 := strS2I(Temp);
        N2 := N1;
      End;

      For A := N1 to N2 Do
        If (A > 0) and (A <= Total) Then ToggleBase(A);
    End;
  Until False;

  Close (FBaseFile);

  FBase := Old;
End;

Function TFileBase.SelectArchive : Boolean;
Var
  A : SmallInt;
Begin
  Result := False;

  Session.io.OutRawLn ('');

  Reset (ArcFile);

  If Eof(ArcFile) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(169));
    Close (ArcFile);
    Exit;
  End;

  Session.io.OutFullLn (Session.GetPrompt(73));

  While Not Eof(ArcFile) Do Begin
    Read (ArcFile, Arc);

    Session.io.PromptInfo[1] := strI2S(FilePos(ArcFile));
    Session.io.PromptInfo[2] := Arc.Desc;
    Session.io.PromptInfo[3] := Arc.Ext;

    Session.io.OutFullLn (Session.GetPrompt(170));
  End;

  Session.io.OutFull (Session.GetPrompt(171));

  A := strS2I(Session.io.GetInput(2, 2, 12, ''));

  If (A > 0) and (A <= FileSize(ArcFile)) Then Begin
    Seek (ArcFile, A - 1);
    Read (ArcFile, Arc);
  End Else Begin
    Close (ArcFile);
    Exit;
  End;

  Close (ArcFile);

  Session.io.PromptInfo[1] := Arc.Ext;

  Session.io.OutFullLn (Session.GetPrompt(74));

  Session.User.ThisUser.Archive := Arc.Ext;

  Result := True;
End;

Function TFileBase.SelectProtocol (Batch: Boolean) : Char;
Var
  Keys  : String;
  OldP1 : String;
  Ch    : Char;
Begin
  OldP1  := Session.io.PromptInfo[1];
  Result := 'Q';
  Keys   := 'Q';

  Session.io.OutFullLn(Session.GetPrompt(359));

  Reset (ProtocolFile);

  While Not Eof(ProtocolFile) Do Begin
    Read (ProtocolFile, Protocol);
    If Protocol.Active And (Protocol.Batch = Batch) And (Protocol.OSType = OSTYpe) Then Begin
      Keys := Keys + Protocol.Key;

      Session.io.PromptInfo[1] := Protocol.Key;
      Session.io.PromptInfo[2] := Protocol.Desc;

      Session.io.OutFullLn (Session.GetPrompt(61));
    End;
  End;

  Close (ProtocolFile);

  Session.io.OutFull (Session.GetPrompt(62));

  Session.io.PromptInfo[1] := OldP1;

  Ch := Session.io.OneKey(Keys, True);

  If Ch = 'Q' Then Exit;

  Reset (ProtocolFile);
  While Not Eof(ProtocolFile) Do Begin
    Read(ProtocolFile, Protocol);
    If ((Protocol.Active) And (Ch = Protocol.Key) And (Protocol.Batch = Batch) And (Protocol.OSType = OSType)) Then Break;
  End;
  Close(ProtocolFile);

  Session.io.OutFullLn (Session.GetPrompt(65));

  Result := Ch;
End;

Procedure TFileBase.ExecuteArchive (FName: String; Temp: String; Mask: String; Mode: Byte);
{mode: 1 = pack, 2 = unpack, 3 = view}
Var
  A     : Byte;
  Temp2 : String[60];
Begin
  If Temp = '' Then
    Case Get_Arc_Type(FName) of
      'A' : Temp := 'ARJ';
      'L' : Temp := 'LZH';
      'R' : Temp := 'RAR';
      'Z' : Temp := 'ZIP';
      '?' : Temp := strUpper(JustFileExt(FName));
    End;

  Reset (ArcFile);

  Repeat
    If Eof(ArcFile) Then Begin
      Close (ArcFile);
      Exit;
    End;

    Read (ArcFile, Arc);

    If (Not Arc.Active) or (Arc.OSType <> OSType) Then Continue;

    If strUpper(Arc.Ext) = Temp Then Break;
  Until False;

  Close (ArcFile);

  Case Mode of
    1 : Temp2 := Arc.Pack;
    2 : Temp2 := Arc.Unpack;
    3 : Temp2 := Arc.View;
  End;

  If Temp2 = '' Then Exit;

  Temp := '';
  A    := 1;

  While A <= Length(Temp2) Do Begin
    If Temp2[A] = '%' Then Begin
      Inc(A);
      If Temp2[A] = '1' Then Temp := Temp + FName Else
      If Temp2[A] = '2' Then Temp := Temp + Mask Else
      If Temp2[A] = '3' Then Temp := Temp + Session.TempPath;
    End Else
      Temp := Temp + Temp2[A];

    Inc(A);
  End;

  ShellDOS ('', Temp);
End;

(*************************************************************************)

Procedure TFileBase.ViewFile;
Var
  FName : String[70];
  Old   : RecFileBase;
Begin
  Session.io.OutFull (Session.GetPrompt(353));

  FName := Session.io.GetInput(70, 70, 11, '');

  If FName = '' Then Exit;

  Old := FBase;

  Reset (FBaseFile);

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If Session.User.Access(FBase.ListACS) Then Begin

      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
      {$I-} Reset (FDirFile); {$I+}
      If IoResult <> 0 Then ReWrite (FDirFile);

      While Not Eof(FDirFile) Do Begin
        Read (FDirFile, FDir);
        If FDir.FileName = FName Then Begin
          If Not ArchiveView (FBase.Path + FName) Then Session.io.OutFullLn(Session.GetPrompt(191));
          Close (FDirFile);
          Close (FBaseFile);
          FBase := Old;
          Exit;
        End;
      End;
      Close (FDirFile);
    End;
  End;
  Close (FBaseFile);

  FBase := Old;

  Session.io.OutFullLn (Session.GetPrompt(51));
End;

Procedure TFileBase.BatchList;
Var
  A : Byte;
  M : Integer;
  S : Byte;
Begin
  If BatchNum = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(52));
    Exit;
  End;

  Session.io.OutFullLn (Session.GetPrompt(56));

  For A := 1 to BatchNum Do Begin
    GetTransferTime (Batch[A].Size, M, S);

    Session.io.PromptInfo[1] := strI2S(A);
    Session.io.PromptInfo[2] := Batch[A].FileName;
    Session.io.PromptInfo[3] := strComma(Batch[A].Size);
    Session.io.PromptInfo[4] := strI2S(M);
    Session.io.PromptInfo[5] := strI2S(S);

    Session.io.OutFullLn (Session.GetPrompt(57));
  End;

  Session.io.OutFullLn (Session.GetPrompt(428));
End;

Procedure TFileBase.BatchClear;
Begin
  BatchNum := 0;
  Session.io.OutFullLn (Session.GetPrompt(59));
End;

Procedure TFileBase.BatchAdd;
Var
  FName  : String[70];
  A      : Byte;
  Old    : RecFileBase;
  OkSave : Boolean;
Begin
  If BatchNum = mysMaxBatchQueue Then Begin
    Session.io.OutFullLn (Session.GetPrompt(46));
    Exit;
  End;

  Session.io.OutFull   (Session.GetPrompt(47));
  FName := Session.io.GetInput(70, 70, 11, '');

  If FName = '' Then Exit;

  Old := FBase;

  Reset (FBaseFile);

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If Session.User.Access(FBase.ListACS) and Session.User.Access(FBase.DLACS) Then Begin

      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
      {$I-} Reset (FDirFile); {$I+}
      If IoResult <> 0 Then ReWrite (FDirFile);

      While Not Eof(FDirFile) Do Begin
        Read (FDirFile, FDir);
        {$IFDEF FS_SENSITIVE}
        If (FDir.FileName = FName) And (FDir.Flags And FDirDeleted = 0) Then Begin
        {$ELSE}
        If (strUpper(FDir.FileName) = strUpper(FName)) And (FDir.Flags And FDirDeleted = 0) Then Begin
        {$ENDIF}
          okSave := False;
          Case CheckFileLimits(1, FDir.Size DIV 1024) of
            0 : okSave := True;
            1 : Session.io.OutFullLn (Session.GetPrompt(224));
            2 : Session.io.OutFullLn (Session.GetPrompt(58));
            3 : Session.io.OutFullLn (Session.GetPrompt(211));
          End;

          For A := 1 to BatchNum Do
            If FName = Batch[A].FileName Then Begin
              Session.io.OutFullLn (Session.GetPrompt(49));
              OkSave := False;
            End;

          If OkSave Then Begin
            Session.io.PromptInfo[1] := FName;
            Session.io.PromptInfo[2] := strComma(FDir.Size);
            Session.io.OutFullLn (Session.GetPrompt(50));
            Inc (BatchNum);
            Batch[BatchNum].FileName := FName;
            Batch[BatchNum].Area     := FilePos(FBaseFile);
            Batch[BatchNum].Size     := FDir.Size;
          End;

          Close (FDirFile);
          Close (FBaseFile);
          FBase := Old;
          Exit;
        End;
      End;
      Close (FDirFile);
    End;
  End;

  Close (FBaseFile);

  FBase := Old;

  Session.io.OutFullLn (Session.GetPrompt(51));
End;

Procedure TFileBase.BatchDelete;
Var
  A : Byte;
  B : Byte;
Begin
  If BatchNum = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(52));
    Exit;
  End;

  Session.io.PromptInfo[1] := strI2S(BatchNum);
  Session.io.OutFull (Session.GetPrompt(53));
  A := strS2I(Session.io.GetInput(2, 2, 12, ''));

  If (A > 0) and (A <= BatchNum) Then Begin
    Session.io.PromptInfo[1] := FDir.FileName;
    Session.io.PromptInfo[2] := strComma(Batch[A].Size);
    Session.io.OutFullLn (Session.GetPrompt(54));
    For B := A to BatchNum do
      Batch[B] := Batch[B+1];
    Dec (BatchNum);
  End;
End;

Procedure TFileBase.FileGroupChange (Ops: String; FirstBase, Intro: Boolean);
Var
  A      : Word;
  Total  : Word;
  tGroup : recGroup;
  tFBase : RecFileBase;
  tLast  : Word;
  Areas  : Word;
  Data   : Word;
Begin
  tGroup := FGroup;

  If (Ops = '+') or (Ops = '-') Then Begin
    Reset (FGroupFile);

    A := Session.User.ThisUser.LastFGroup - 1;

    Repeat
      Case Ops[1] of
        '+' : Inc(A);
        '-' : Dec(A);
      End;

      {$I-}
      Seek (FGroupFile, A);
      Read (FGroupFile, FGroup);
      {$I+}

      If IoResult <> 0 Then Break;

      If Session.User.Access(FGroup.ACS) Then Begin
        Session.User.ThisUser.LastFGroup := FilePos(FGroupFile);
        Close (FGroupFile);
        If Intro Then Session.io.OutFile ('fgroup' + strI2S(Session.User.ThisUser.LastFGroup), True, 0);

        If FirstBase Then Begin
          Session.User.ThisUser.LastFBase := 0;
          ChangeFileArea ('+');
        End;

        Exit;
      End;
    Until False;

    Close (FGroupFile);

    FGroup := tGroup;
    Exit;
  End;

  Data := strS2I(Ops);

  Reset (FGroupFile);

  If Data > 0 Then Begin
    If Data > FileSize(FGroupFile) Then Begin
      Close (FGroupFile);
      Exit;
    End;

    Seek (FGroupFile, Data-1);
    Read (FGroupFile, FGroup);

    If Session.User.Access(FGroup.ACS) Then Begin
      Session.User.ThisUser.LastFGroup := FilePos(FGroupFile);
      If Intro Then Session.io.OutFile ('fgroup' + strI2S(Data), True, 0);
    End Else
     FGroup := tGroup;

    Close (FGroupFile);

    If FirstBase Then Begin
      Session.User.ThisUser.LastFBase := 0;
      ChangeFileArea ('+');
    End;

    Exit;
  End;

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  Session.io.OutFullLn (Session.GetPrompt(214));

  tLast := Session.User.ThisUser.LastFGroup;
  Total := 0;

  While Not Eof(FGroupFile) Do Begin
    Read (FGroupFile, FGroup);

    If Not FGroup.Hidden And Session.User.Access(FGroup.ACS) Then Begin

      Areas := 0;
      Session.User.ThisUser.LastFGroup := FilePos(FGroupFile);

      Reset (FBaseFile);

      While Not Eof(FBaseFile) Do Begin
        Read (FBaseFile, tFBase);
        If Session.User.Access(tFBase.ListACS) Then Inc(Areas);
      End;

      Close (FBaseFile);

      Inc (Total);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := FGroup.Name;
      Session.io.PromptInfo[3] := strI2S(Areas);

      Session.io.OutFullLn (Session.GetPrompt(215));

      If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;
  End;

  Session.User.ThisUser.LastFGroup := tLast;

  If Total = 0 Then
    Session.io.OutFullLn (Session.GetPrompt(216))
  Else Begin
    Session.io.OutFull (Session.GetPrompt(217));

    A := strS2I(Session.io.GetInput(4, 4, 11, ''));

    If (A > 0) and (A <= Total) Then Begin
      Total := 0;

      Reset (FGroupFile);

      Repeat
        Read (FGroupFile, FGroup);
        If Not FGroup.Hidden And Session.User.Access(FGroup.ACS) Then Inc(Total);
        If A = Total Then Break;
      Until False;

      Session.User.ThisUser.LastFGroup := FilePos(FGroupFile);
      If Intro Then Session.io.OutFile ('fgroup' + strI2S(Session.User.ThisUser.LastFGroup), True, 0);

      Session.User.ThisUser.LastFBase := 0;

      ChangeFileArea ('+');
    End Else
      FGroup := tGroup;
  End;

  Close (FGroupFile);
End;

Function TFileBase.ListFileAreas (Compress: Boolean) : Integer;
Var
  Total    : Word = 0;
  Listed   : Word = 0;
  tDirFile : File of RecFileList;
Begin
  Reset (FBaseFile);

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If Session.User.Access(FBase.ListACS) Then Begin
      Inc (Listed);
      If Listed = 1 Then Session.io.OutFullLn (Session.GetPrompt(33));
      If Compress Then
        Inc (Total)
      Else
        Total := FilePos(FBaseFile);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := FBase.Name;
      Session.io.PromptInfo[3] := '0';

      Assign (TDirFile, Config.DataPath + FBase.FileName + '.dir');
      {$I-} Reset (TDirFile); {$I+}

      If IoResult = 0 Then Begin
        Session.io.PromptInfo[3] := strI2S(FileSize(TDirFile));
        Close (TDirFile);
      End;

      Session.io.OutFull (Session.GetPrompt(34));

      If (Listed MOD Config.FColumns = 0) and (Listed > 0) Then Session.io.OutRawLn('');
    End;

    If EOF(FBaseFile) and (Listed MOD Config.FColumns <> 0) Then Session.io.OutRawLn('');

    If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Begin
                Total := FileSize(FBaseFile);
                Break;
              End;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Close (FBaseFile);

  Result := Total;
End;

Procedure TFileBase.ChangeFileArea (Data: String);
Var
  A        : Word;
  Total    : Word;
  Old      : RecFileBase;
  Str      : String[5];
  Compress : Boolean;
Begin
  Old      := FBase;
  Compress := Config.FCompress;

  If (Data = '+') or (Data = '-') Then Begin
    Reset (FBaseFile);

    A := Session.User.ThisUser.LastFBase - 1;

    Repeat
      Case Data[1] of
        '+' : Inc(A);
        '-' : Dec(A);
      End;

      {$I-}
      Seek (FBaseFile, A);
      Read (FBaseFile, FBase);
      {$I+}

      If IoResult <> 0 Then Break;

      If Session.User.Access(FBase.ListACS) Then Begin
        Session.User.ThisUser.LastFBase := FilePos(FBaseFile);
        Close (FBaseFile);
        Exit;
      End;
    Until False;

    Close (FBaseFile);
    FBase := Old;
    Exit;
  End;

  A := strS2I(Data);

  If A > 0 Then Begin
    Reset (FBaseFile);

    If A <= FileSize(FBaseFile) Then Begin
      Seek (FBaseFile, A-1);
      Read (FBaseFile, FBase);

      If Session.User.Access(FBase.ListACS) Then Begin
        Session.User.ThisUser.LastFBase := FilePos(FBaseFile)
      End Else
        FBase := Old;
    End;

    Close (FBaseFile);

    Exit;
  End;

  If Pos('NOLIST', strUpper(Data)) > 0 Then Begin
    Reset (FBaseFile);
    Total := FileSize(FBaseFile);
    Close (FBaseFile);
  End Else
    Total := ListFileAreas(Compress);

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(37));
    FBase := Old;
  End Else Begin
    Repeat
      Session.io.OutFull (Session.GetPrompt(36));

      Str := Session.io.GetInput(5, 5, 12, '');

      If Str = '?' Then Begin
        Compress := Config.FCompress;
        Total    := ListFileAreas(Compress);
      End Else
        Break;
    Until False;

    A := strS2I(Str);

    If (A > 0) and (A <= Total) Then Begin
      Reset (FBaseFile);
      If Not Compress Then Begin
        Seek (FBaseFile, A - 1);
        Read (FBaseFile, FBase);
        If Not Session.User.Access(FBase.ListACS) Then Begin
          FBase := Old;
          Close (FBaseFile);
          Exit;
        End;
      End Else Begin
        Total := 0;

        While Not Eof(FBaseFile) And (A <> Total) Do Begin
          Read (FBaseFile, FBase);
          If Session.User.Access(FBase.ListACS) Then Inc(Total);
        End;

        If A <> Total Then Begin
          Close (FBaseFile);
          FBase := OLD;
          Exit;
        End;
      End;

      Session.User.ThisUser.LastFBase := FilePos(FBaseFile);

      Close (FBaseFile);
    End Else
      FBase := Old;
  End;
End;

Function TFileBase.ListFiles (Mode: Byte; Data : String) : Byte;
Var
  ListType  : Byte;    { 0 = ascii, 1 = ansi }
  DataFile  : File;
  Lines     : Byte;    { lines already displayed }
  CurPos    : Byte;    { current cursor position }
  ListSize  : Byte;    { number of files in this page listing }
  CurPage   : Word;    { current page number }
  TopPage   : Word;    { top of page file position }
  TopDesc   : Byte;    { top of page description offset }
  BotPage   : Word;    { bot of page file position }
  BotDesc   : Byte;    { bot of page description offset }
  PageSize  : Byte;    { total lines in window/page }
  LastPage  : Boolean; { is the last page displayed? }
  Found     : Boolean; { were any files found? }
  First     : Boolean; { first file on page? }
  IsNotLast : Boolean;
  List      : Array[1..13] of Record
                FileName : String[70];
                RecPos   : Word;
                yPos     : Byte;
                Batch    : Boolean;
              End;
  strListFormat,
  strDesc,
  strExtDesc,
  strUploader,
  strBarON,
  strBarOFF     : String;

  Function OkFile : Boolean;
  Var
    T2   : Boolean;
    A    : Byte;
    Temp : String[mysMaxFileDescLen];
  Begin
    OkFile := False;

    If (FDir.Flags And FDirDeleted <> 0) Then Exit;
    If (FDir.Flags And FDirInvalid <> 0) And (Not Session.User.Access(Config.AcsSeeUnvalid)) Then Exit;
    If (FDir.Flags And FDirFailed  <> 0) And (Not Session.User.Access(Config.AcsSeeFailed)) Then Exit;

    Case Mode of
      1 : If Data <> '' Then
            If Not WildCardMatch (Data, FDir.FileName) Then Exit;
      2 : If FDir.DateTime < FScan.LastNew Then Exit;
      3 : Begin
            T2 := Bool_Search(Data, FDir.FileName);

            If Not T2 Then Begin
              Seek (DataFile, FDir.DescPtr);

              For A := 1 to FDir.DescLines Do Begin
                BlockRead (DataFile, Temp[0], 1);
                BlockRead (DataFile, Temp[1], Length(Temp));

                If Bool_Search(Data, Temp) Then Begin
                  T2 := True;
                  Break;
                End;
              End;
            End;

            If Not T2 Then Exit;
          End;
    End;

    OkFile := True;
  End;

  Procedure ClearWindow;
  Var
    A : Byte;
  Begin
    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y);

    Session.io.OutFull('|16');

    For A := Session.io.ScreenInfo[1].Y to Session.io.ScreenInfo[2].Y Do Begin
      Session.io.AnsiClrEOL;
      Session.io.OutRawLn('');
    End;

    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y);
  End;

  Procedure SearchHighlight (Var Temp: String);
  Var
    Attr : Byte;
  Begin
    If Bool_Search(Data, Temp) Then Begin
      Attr := Screen.TextAttr;

      Screen.TextAttr := 255;

      Insert (
        Session.io.Attr2Ansi(Session.Theme.FileDescLo),
        Temp,
        Pos(Data, strUpper(Temp)) + Length(Data)
      );

      Screen.TextAttr := 255;

      Insert (
        Session.io.Attr2Ansi(Session.Theme.FileDescHi),
        Temp,
        Pos(Data, strUpper(Temp)));

      Screen.TextAttr := Attr;
    End;
  End;

  Procedure NextPage;
  Begin
    Inc (CurPage);

    TopDesc := BotDesc;
    TopPage := BotPage;
    CurPos  := 1;
  End;

  Function ShowText (Str : String) : Boolean;
  Begin
    If Lines = PageSize Then Begin
      ShowText := False;
      Exit;
    End;

    Inc    (BotDesc);
    Inc    (Lines);

    Session.io.OutFullLn (Str);

    Found    := True;
    ShowText := True;
  End;

  Procedure PrevPage;
  Var
    NewPos : LongInt;
    Count  : Word;
  Begin
    If CurPage = 1 Then Exit;

    Dec (CurPage);

    NewPos := TopPage;
    Count  := 0;

    If TopDesc = 0 Then Dec(NewPos);

    While (NewPos >= 0) and (Count < PageSize) Do Begin
      Seek (FDirFile, NewPos);
      Read (FDirFile, FDir);

      Dec (NewPos);

      If Not OkFile Then Continue;

      If TopDesc > 0 Then Begin
        Inc (Count, FDir.DescLines - (FDir.DescLines - TopDesc + 1) + 1);
        If TopDesc = FDir.DescLines + 2 Then Dec(Count);
        TopDesc := 0;
      End Else Begin
        Inc (Count, FDir.DescLines + 1);
        If FBase.Flags And FBShowUpload <> 0 Then Inc(Count);
      End;
    End;

    If NewPos < -1 Then Begin
      CurPage := 1;
      TopPage := 0;
      TopDesc := 0;
    End Else Begin
      TopPage := NewPos + 1;
      TopDesc := Count - PageSize;
    End;
  End;

  Procedure PrintMessage (N : Integer);
  Begin
    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y);
    Session.io.AnsiClrEOL;
    Session.io.OutFull (Session.GetPrompt(N));
    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y);
    Session.io.AnsiClrEOL;

    If Session.User.Access(FBase.SysopACS) Then
      Session.io.OutFull (Session.GetPrompt(339))
    Else
      Session.io.OutFull (Session.GetPrompt(323));
  End;

  Procedure UpdateBatch;
  Begin
    If Session.io.ScreenInfo[4].X = 0 Then Exit;

    Session.io.AnsiGotoXY (Session.io.ScreenInfo[4].X, Session.io.ScreenInfo[4].Y);
    Session.io.AnsiColor  (Session.io.ScreenInfo[4].A);
    Session.io.OutRaw     (strZero(BatchNum));
  End;

  Procedure FullReDraw;
  Begin
    Session.io.ScreenInfo[5].Y := 0;
    Session.io.ScreenInfo[6].Y := 0;

    Session.io.OutFile (FBase.Template, True, 0);

    PageSize := Session.io.ScreenInfo[2].Y - Session.io.ScreenInfo[1].Y + 1;

    BotDesc := TopDesc;
    BotPage := TopPage;

    If Session.User.Access(FBase.SysopACS) Then
      PrintMessage (339)
    Else
      PrintMessage (323);

    UpdateBatch;
  End;

  Function GetFileListSize (SizeInfo: String) : String;
  Var
    A : Cardinal;
  Begin
    If FDir.Flags And FDirOffline <> 0 Then
      GetFileListSize := strWordGet(1, SizeInfo, ' ')
    Else
    If FDir.Flags And FDirFailed <> 0 Then
      GetFileListSize := strWordGet(2, SizeInfo, ' ')
    Else
    If FDir.Flags And FDirInvalid <> 0 Then
      GetFileListSize := strWordGet(3, SizeInfo, ' ')
    Else
    If FDir.Size >= 1024000000 Then Begin
      A := (FDir.Size DIV 1024) DIV 1024;
      GetFileListSize := strI2S(A DIV 1000) + '.' + Copy(strI2S(A MOD 1000), 1, 2) + strWordGet(4, SizeInfo, ' ')
    End Else
    If FDir.Size >= 1024000 Then Begin
      A := FDir.Size DIV 1024;
      GetFileListSize := strI2S(A DIV 1000) + '.' + Copy(strI2S(A MOD 1000), 1, 2) + strWordGet(5, SizeInfo, ' ')
    End Else
    If FDir.Size >= 1024 Then
      GetFileListSize := strI2S(FDir.Size DIV 1024) + strWordGet(6, SizeInfo, ' ')
    Else
      GetFileListSize := strI2S(FDir.Size) + strWordGet(7, SizeInfo, ' ');
  End;

  Procedure HeaderCheck;
  Begin
    Case ListType of
      0 : If First Then Begin
            First := False;
            If Config.FShowHeader or (CurPage = 1) Then Begin
              Session.io.PausePtr := 1;
              Session.io.OutFullLn(Session.GetPrompt(41))
            End Else Begin
              Session.io.OutRawLn('');
              Session.io.PausePtr := 1;
            End;

            PageSize := Session.User.ThisUser.ScreenSize - Session.io.PausePtr - 1;
          End;
      1 : If Not Found Then Begin
            FullReDraw;
            ClearWindow;
            First := False;
          End Else
          If First Then Begin
            ClearWindow;
            First := False;
          End;
    End;
  End;

  Procedure DrawPage;
  Var
    OK      : Boolean;
    Str     : String;
    A       : SmallInt;
    SizeStr : String;
  Begin
    ListSize := 0;
    Lines    := 0;
    SizeStr  := Session.GetPrompt(491);

    Seek (FDirFile, TopPage);
    If TopDesc <> 0 Then Read (FDirFile, FDir);

    BotDesc   := TopDesc;
    OK        := True;
    First     := True;
    IsNotLast := False;

    Repeat
      If BotDesc = 0 Then Begin
        Read (FDirFile, FDir);

        If Not OkFile Then Continue;

        HeaderCheck;

        Session.io.PromptInfo[1] := strZero(ListSize + 1);
        Session.io.PromptInfo[2] := FDir.FileName;
        Session.io.PromptInfo[3] := ' ';
        Session.io.PromptInfo[4] := GetFileListSize(SizeStr);
        Session.io.PromptInfo[5] := DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType);
        Session.io.PromptInfo[6] := strI2S(FDir.Downloads);

        List[ListSize + 1].Batch := False;

        For A := 1 to BatchNum Do
          If Batch[A].FileName = FDir.FileName Then Begin
            List[ListSize + 1].Batch := True;
            Session.io.PromptInfo[3] := Session.Theme.TagChar;

            Break;
          End;

        OK := ShowText(strListFormat);

        If Not OK Then Begin
          IsNotLast := True;

          Break;
        End;

        Inc (ListSize);

        List[ListSize].FileName := FDir.FileName;
        List[ListSize].YPos     := Screen.CursorY - 1;
        List[ListSize].RecPos   := FilePos(FDirFile) - 1;
      End Else
        HeaderCheck;

      If BotDesc <= FDir.DescLines + 2 Then Begin { skip if 1st line is uler }
        Seek (DataFile, FDir.DescPtr);

        For A := 1 to FDir.DescLines Do Begin
          BlockRead (DataFile, Str[0], 1);
          BlockRead (DataFile, Str[1], Ord(Str[0]));

          If A < BotDesc Then Continue;

          If Mode = 3 Then SearchHighlight(Str);

          If A = 1 Then Begin
            Session.io.PromptInfo[1] := GetFileListSize(SizeStr);
            Session.io.PromptInfo[2] := DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType);
            Session.io.PromptInfo[3] := strI2S(FDir.Downloads);
            Session.io.PromptInfo[4] := Str;
            Session.io.PromptInfo[5] := FDir.Uploader;

            OK := ShowText(strDesc);
          End Else Begin
            Session.io.PromptInfo[4] := Str;

            OK := ShowText(strExtDesc);
          End;

          If Not OK Then Break;
        End;
      End;

      If BotDesc > FDir.DescLines Then Begin
        If FBase.Flags and FBShowUpload <> 0 Then Begin
          OK := ShowText(strUploader);
          If OK Then
            BotDesc := 0
          Else
            Inc (BotDesc);
        End Else
          BotDesc := 0;
      End;
    Until EOF(FDirFile) Or Not OK;

    BotPage   := FilePos(FDirFile) - 1;
    LastPage  := Eof(FDirFile) And (BotDesc = 0) And Not IsNotLast;
    IsNotLast := False;
    Str       := Session.io.DrawPercent(Session.Theme.FileBar, BotPage, FileSize(FDirFile), A);

    If Found Then Begin
      If (ListType = 1) and (Session.io.ScreenInfo[5].Y <> 0) Then Begin
        Session.io.AnsiGotoXY   (Session.io.ScreenInfo[5].X, Session.io.ScreenInfo[5].Y);
        Session.io.AnsiColor (Session.io.ScreenInfo[5].A);
        Session.io.OutRaw (strPadL(strI2S(A), 3, ' '));
      End;

      If (ListType = 1) and (Session.io.ScreenInfo[6].Y <> 0) Then Begin
        Session.io.AnsiGotoXY (Session.io.ScreenInfo[6].X, Session.io.ScreenInfo[6].Y);
        Session.io.OutFull (Str);
      End;
    End;
  End;

  Procedure BarOFF;
  Begin
    Session.io.AnsiGotoXY (1, List[CurPos].YPos);

    Session.io.PromptInfo[1] := strZero(CurPos);
    Session.io.PromptInfo[2] := List[CurPos].FileName;

    If List[CurPos].Batch Then
      Session.io.PromptInfo[3] := Session.Theme.TagChar
    Else
      Session.io.PromptInfo[3] := ' ';

    Session.io.OutFull(strBarOFF);
  End;

  Procedure Ansi_List;
  Var
    Ch : Char;
    A  : Byte;
    B  : Integer;
  Begin
    Session.io.AllowArrow := True;
    ListType   := 1;

    strListFormat := Session.GetPrompt(431);
    strBarON      := Session.GetPrompt(432);
    strBarOFF     := Session.GetPrompt(433);
    strDesc       := Session.GetPrompt(434);
    strExtDesc    := Session.GetPrompt(435);
    strUploader   := Session.GetPrompt(436);

    NextPage;
    DrawPage;

    If Found Then Begin
      Repeat
        If ListSize > 0 Then Begin
          Session.io.AnsiGotoXY (1, List[CurPos].yPos);

          Session.io.PromptInfo[1] := strZero(CurPos);
          Session.io.PromptInfo[2] := List[CurPos].FileName;

          If List[CurPos].Batch Then
            Session.io.PromptInfo[3] := Session.Theme.TagChar
          Else
            Session.io.PromptInfo[3] := ' ';

          Session.io.OutFull (strBarON);
        End;

        Session.io.PurgeInputBuffer;

        Ch := UpCase(Session.io.GetKey);

        If Session.io.IsArrow Then Begin
          Case Ch of
            #71 : If CurPage > 1 Then Begin
                    While CurPage > 1 Do PrevPage;
                    CurPos := 1;
                    DrawPage;
                  End Else If CurPos > 1 Then Begin
                    BarOFF;
                    CurPos := 1;
                  End;
            #72 : If (CurPos > 1) and (ListSize > 0) Then Begin
                    BarOFF;
                    Dec (CurPos);
                  End Else If CurPage > 1 Then Begin
                    PrevPage;
                    DrawPage;
                    CurPos := ListSize;
                  End;
            #73,
            #75 : If CurPage > 1 Then Begin
                    PrevPage;
                    DrawPage;
                    CurPos := ListSize;
                  End Else
                  If ListSize > 0 Then Begin
                    BarOFF;
                    CurPos := 1;
                  End;
            #79 : If LastPage Then Begin
                    BarOFF;
                    CurPos := ListSize;
                  End Else Begin
                    While Not LastPage Do Begin
                      NextPage;
                      DrawPage;
                    End;

                    CurPos := ListSize;
                  End;
            #80 : If CurPos < ListSize Then Begin
                    BarOFF;
                    Inc (CurPos);
                  End Else If Not LastPage Then Begin
                    NextPage;
                    DrawPage;
                  End;
            #77,
            #81 : If Not LastPage Then Begin
                    NextPage;
                    DrawPage;
                  End Else If ListSize > 0 Then Begin
                    BarOFF;
                    CurPos := ListSize;
                  End;
          End;
        End Else Begin
          Case Ch of
            #13 : If LastPage Then Begin
                    Result := 2;
                    Break;
                  End Else Begin
                    NextPage;
                    DrawPage;
                  End;
            #27 : Begin
                    Result := 1;
                    Break;
                  End;
            #32 : If Not Session.User.Access(FBase.DLACS) Then
                     PrintMessage(212)
                  Else
                  If ListSize > 0 Then Begin
                    If List[CurPos].Batch Then Begin
                      For A := 1 to BatchNum Do
                        If Batch[A].FileName = List[CurPos].FileName Then Begin
                          For B := A to BatchNum Do Batch[B] := Batch[B+1];
                          Dec (BatchNum);
                          List[CurPos].Batch := False;
                          BarOFF;
                          UpdateBatch;
                          Break;
                        End;
                    End Else
                    If BatchNum < mysMaxBatchQueue Then Begin
                      Seek (FDirFile, List[CurPos].RecPos);
                      Read (FDirFile, FDir);

                      Case CheckFileLimits(1, FDir.Size DIV 1024) of
                        0 : Begin
                              Inc (BatchNum);
                              Batch[BatchNum].FileName := FDir.FileName;
                              If Mode = 1 Then
                                Batch[BatchNum].Area := Session.User.ThisUser.LastFBase
                              Else
                                Batch[BatchNum].Area := FilePos(FBaseFile);
                              Batch[BatchNum].Size   := FDir.Size;

                              List[CurPos].Batch := True;
                              BarOFF;
                              updateBatch;
                            End;
                        1 : PrintMessage (212);
                        2 : PrintMessage (312);
                        3 : PrintMessage (313);
                      End;
                    End Else
                      PrintMessage (314);

                    If CurPos < ListSize Then Begin
                      BarOFF;
                      Inc (CurPos);
                    End Else If Not LastPage Then Begin
                      NextPage;
                      DrawPage;
                    End;
                  End;
              '?' : Begin
                      Session.io.OutFile ('flisthlp', True, 0);
                      If Not Session.io.NoFile Then Begin
                        fullReDraw;
                        drawPage;
                      End;
                    End;
              'E' : If Session.User.Access(FBase.SysopACS) Then Begin
                      { Save file POS if FBaseFile is open }
                      {$I-} B := FilePos(FBaseFile); {$I+}
                      If IoResult = 0 Then
                        Close (FBaseFile)
                      Else
                        B := -1;

                      Close (FDirFile);
                      Close (DataFile);

                      DirectoryEditor(True, List[CurPos].FileName);

                      If B <> -1 Then Begin
                        Reset (FBaseFile);
                        Seek  (FBaseFile, B);
                      End;

                      Reset (FDirFile);
                      Reset (DataFile, 1);

                      FullReDraw;
                      DrawPage;

                      If CurPos > ListSize Then CurPos := ListSize;

                      Session.io.AllowArrow := True;
                    End;
              'N' : If Mode > 1 Then Begin
                      Result := 2;
                      Break;
                    End;
              'V' : Begin
                      Session.io.AnsiGotoXY (1, 23);
                      If ArchiveView(FBase.Path + List[CurPos].FileName) Then Begin
                        FullRedraw;
                        DrawPage;
                      End Else
                        PrintMessage (324);

                      Session.io.AllowArrow := True;
                    End;
          End;
        End;
      Until False;

      Session.io.AnsiGotoXY (1, Session.User.ThisUser.ScreenSize);
    End;

    Session.io.AllowArrow := False;
  End;

  Procedure Ascii_List;
  Var
    A : LongInt;
    B : LongInt;
    okSave : Byte;
  Begin
    ListType := 0;

    strListFormat := Session.GetPrompt(42);
    strDesc       := Session.GetPrompt(43);
    strExtDesc    := Session.GetPrompt(45);
    strUploader   := Session.GetPrompt(437);

    NextPage;
    DrawPage;

    If Not Found Then Exit;

    Result := 2;

    Repeat
      Session.io.OutFull (Session.GetPrompt(44));

      Case Session.io.OneKey(#13'FNPQV', True) of
        #13,
        'N' : If LastPage Then
                Break
              Else Begin
                NextPage;
                DrawPage;
              End;
        'P' : Begin
                PrevPage;
                DrawPage;
              End;
        'Q' : Begin
                Result := 1;
                Break;
              End;
        'V' : Begin
                Session.io.OutFull (Session.GetPrompt(358));

                A := strS2I(Session.io.GetInput(2, 2, 12, ''));

                If (A > 0) and (A <= ListSize) Then
                  If Not ArchiveView (FBase.Path + List[A].FileName) Then
                    Session.io.OutFullLn(Session.GetPrompt(191));

                DrawPage;
              End;
        'F' : If Not Session.User.Access(FBase.DLACS) Then
                Session.io.OutFullLn (Session.GetPrompt(224))
              Else Begin
                Repeat
                  If BatchNum = mysMaxBatchQueue Then Begin
                    Session.io.OutFullLn (Session.GetPrompt(46));
                    Break;
                  End;

                  Session.io.OutFull (Session.GetPrompt(357));
                  A := strS2I(Session.io.GetInput(2, 2, 12, ''));

                  If (A < 1) or (A > ListSize) Then Break;

                  okSave := 0;

                  Seek (FDirFile, List[A].RecPos);
                  Read (FDirFile, FDir);

                  For A := 1 to BatchNum Do
                    If FDir.FileName = Batch[A].FileName Then Begin
                      Session.io.PromptInfo[1] := FDir.FileName;
                      Session.io.PromptInfo[2] := strComma(Batch[A].Size);
                      Session.io.OutFullLn (Session.GetPrompt(54));

                      For B := A to BatchNum Do
                        Batch[B] := Batch[B + 1];

                      Dec (BatchNum);

                      okSave := 2;
                    End;

                  If okSave = 0 Then
                    Case CheckFileLimits(1, FDir.Size DIV 1024) of
                      0 : okSave := 1;
                      1 : Session.io.OutFullLn (Session.GetPrompt(224));
                      2 : Session.io.OutFullLn (Session.GetPrompt(58));
                      3 : Session.io.OutFullLn (Session.GetPrompt(211));
                    End;

                  If okSave = 1 Then Begin
                    Session.io.PromptInfo[1] := FDir.FileName;
                    Session.io.PromptInfo[2] := strComma(FDir.Size);

                    Session.io.OutFullLn (Session.GetPrompt(50));

                    Inc (BatchNum);

                    Batch[BatchNum].FileName := FDir.FileName;
                    Batch[BatchNum].Size     := FDir.Size;

                    If Mode = 1 Then
                      Batch[BatchNum].Area := Session.User.ThisUser.LastFBase
                    Else
                      Batch[BatchNum].Area := FilePos(FBaseFile);
                  End;
              Until False;

              DrawPage;
            End;
      End;
    Until False;

    Session.io.OutRawLn('');
  End;

Begin
  If FBase.FileName = '' Then Begin
    Session.io.OutFullLn(Session.GetPrompt(38));
    Exit;
  End;

  If Not Session.User.Access(FBase.ListACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(39));
    Exit;
  End;

  If (Mode = 1) and (Data = 'SEARCH') Then Begin
    Session.io.OutFull (Session.GetPrompt(195));

    Data := Session.io.GetInput(70, 70, 11, '*.*');

    If Data = '' Then Exit;
  End;

  Set_Node_Action (Session.GetPrompt(350));

  Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
  {$I-} Reset (FDirFile); {$I+}

  If IoResult <> 0 Then Begin
    If Mode = 1 Then Session.io.OutFullLn (Session.GetPrompt(40));
    Exit;
  End;

  If Eof(FDirFile) Then Begin
    If Mode = 1 Then Session.io.OutFullLn (Session.GetPrompt(40));
    Close (FDirFile);
    Exit;
  End;

  Assign (DataFile, Config.DataPath + FBase.FileName + '.des');
  {$I-} Reset (DataFile, 1); {$I+}
  If IoResult <> 0 Then ReWrite (DataFile, 1);

  Result  := 0;
  CurPage := 0;
  TopPage := 0;
  TopDesc := 0;
  BotPage := 0;
  BotDesc := 0;
  Found   := False;

  If (Session.User.ThisUser.FileList = 1) and (Session.io.Graphics > 0) Then
    Ansi_List
  Else
    Ascii_List;

  Close (FDirFile);
  Close (DataFile);
End;

Procedure TFileBase.CheckFileNameLength (FPath : String; Var FName : String);
Var
  D : DirStr;
  N : NameStr;
  E : ExtStr;
  F : File;
  S : String;
Begin
  If Length(FName) > 70 Then Begin
    FSplit(FName, D, N, E);

    S := Copy(N, 1, 70 - Length(E)) + E;

    Repeat
      Assign (F, FPath + FName);
      {$I-} ReName(F, FPath + S); {$I+}

      If IoResult = 0 Then Begin
        FName := S;
        Break;
      End Else Begin
        Session.io.OutFull (Session.GetPrompt(461));
        S := strStripB(Session.io.GetInput(70, 70, 11, S), ' ');
      End;
    Until False;
  End;
End;

Function TFileBase.IsDupeFile (FileName : String; Global : Boolean) : Boolean;
Var
  Res : Boolean;
  OLD : RecFileBase;

  Procedure Check_Area;
  Var
    TempFile : File of RecFileList;
    Temp     : RecFileList;
  Begin
    Assign (TempFile, Config.DataPath + FBase.FileName + '.dir');
    {$I-} Reset (TempFile); {$I+}

    If IoResult <> 0 Then ReWrite (TempFile);

    While Not Eof(TempFile) Do Begin
      Read (TempFile, Temp);
      {$IFDEF FS_SENSITIVE}
      If (Temp.FileName = FileName) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ELSE}
      If (strUpper(Temp.FileName) = strUpper(FileName)) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ENDIF}
        Res := True;
        Break;
      End;
    End;

    Close (TempFile);
  End;

Begin
  Res := False;
  OLD := FBase;

  If Global Then Begin
    Reset (FBaseFile);
    While Not Eof(FBaseFile) And Not Res Do Begin
      Read (FBaseFile, FBase);
      Check_Area;
    End;
    Close (FBaseFile);
  End Else
    Check_Area;

  FBase  := OLD;
  Result := Res;
End;

Procedure TFileBase.GetFileDescription (FN : String);
Var
  A : Byte;
Begin
  Session.io.PromptInfo[1] := strI2S(Config.MaxFileDesc);
  Session.io.PromptInfo[2] := FN;

  Session.io.OutFullLn (Session.GetPrompt(72));

  FDir.DescLines := Config.MaxFileDesc;

  For A := 1 to Config.MaxFileDesc Do Begin
    Session.io.PromptInfo[1] := strZero(A);
    Session.io.OutFull (Session.GetPrompt(207));
    Session.Msgs.MsgText[A] := Session.io.GetInput(mysMaxFileDescLen, mysMaxFileDescLen, 11, '');
    If Session.Msgs.MsgText[A] = '' Then Begin
      FDir.DescLines := Pred(A);
      Break;
    End;
  End;

  If FDir.DescLines = 0 Then Begin
    Session.Msgs.MsgText[1] := Session.GetPrompt(208);
    FDir.DescLines := 1;
  End;
End;

Procedure TFileBase.UploadFile;
Var
  FileName : String;
  A        : LongInt;
  D        : DirStr;
  N        : NameStr;
  E        : ExtStr;
  OLD      : RecFileBase;
  Blind    : Boolean;
  Temp     : String;
  FullName : String;
  DataFile : File;
  TempFile : File;
  Found    : Boolean;
  LogFile  : Text;
  FileStatus : Boolean;
Begin
  OLD   := FBase;
  Found := False;

  If Config.UploadBase > 0 Then Begin
    Session.User.IgnoreGroup := True; { just in case ul area is in another group }

    Reset (FBaseFile);
    {$I-} Seek (FBaseFile, Config.UploadBase - 1); {$I+}

    If IoResult = 0 Then Read (FBaseFile, FBase);

    Close (FBaseFile);

    // reset ignoregroup here?
  End;

  If Not Session.User.Access(FBase.ULacs) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(68));
    FBase := OLD;
    Exit;
  End;

  Session.User.IgnoreGroup := False;

  If FBase.FileName = '' Then Begin
    Session.io.OutFullLn(Session.GetPrompt(38));
    FBase := OLD;
    Exit;
  End;

  If FBase.Flags And FBSlowMedia <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(80));
    FBase := OLD;
    Exit;
  End;

  If Config.FreeUL > 0 Then Begin
    FSplit (FBase.Path, D, N, E);

    // this might be broken?

    If DiskFree(Ord(UpCase(D[1])) - 64) DIV 1024 < Config.FreeUL Then Begin
      Session.io.OutFullLn (Session.GetPrompt(81));
      FBase := OLD;
      Exit;
    End;
  End;

  Blind    := Session.io.GetYN(Session.GetPrompt(375), False);
  FileName := '';

  If Blind Then
    Session.io.OutFile ('blindul', True, 0)
  Else Begin
    Session.io.OutFile ('upload', True, 0);

    Session.io.OutFull (Session.GetPrompt(343));
    FileName := strStripB(Session.io.GetInput(70, 70, 11, ''), ' ');

    If (FileName = '') or (Pos('*', FileName) > 0) or (Pos('?', FileName) > 0) Then Begin
      Session.io.OutFullLn (Session.GetPrompt(69));
      FBase := OLD;
      Exit;
    End;

    If Config.FDupeScan > 0 Then Begin
      Session.io.OutFull (Session.GetPrompt(70));

      If IsDupeFile(FileName, Config.FDupeScan = 2) Then Begin
        Session.io.OutFullLn (Session.GetPrompt(205));
        FBase := OLD;
        Exit;
      End;

      Session.io.OutFullLn (Session.GetPrompt(71));
    End;

    FileName := FBase.Path + FileName;
  End;

  If SelectProtocol(Blind) = 'Q' Then Begin
    FBase := OLD;
    Exit;
  End;

  ExecuteProtocol(False, FBase.Path);

{ ++lang ADD: update node status to transferring file? }

  Session.io.OutFull (Session.GetPrompt(376));

  Assign (DataFile, Config.DataPath + FBase.FileName + '.des');
  {$I-} Reset (DataFile, 1); {$I+}
  If IoResult <> 0 Then ReWrite(DataFile, 1);

  Seek (DataFile, FileSize(DataFile));

  Assign (LogFile, Session.TempPath + 'xfer.log');
  {$I-} Reset(LogFile); {$I+}
  If IoResult = 0 Then Begin
    While Not Eof(LogFile) Do Begin
      dszGetFile (LogFile, FileName, FileStatus);

      If FileName = '' Then Continue;

      CheckFileNameLength(FBase.Path, FileName);

      FullName := FBase.Path + FileName;

      Session.io.PromptInfo[1] := FileName;

      If Not FileStatus Then Begin
        Session.SystemLog ('Failed Upload: ' + FileName + ' to ' + strStripMCI(FBase.Name));

        Session.io.OutFull (Session.GetPrompt(84));

        FileErase(FullName);
      End Else Begin
        Found := True;

        Session.SystemLog ('Uploaded: ' + FileName + ' to ' + strStripMCI(FBase.Name));

        Session.io.OutFull (Session.GetPrompt(83));

        FDir.FileName  := FileName;
        FDir.DateTime  := CurDateDos;
        FDir.Uploader  := Session.User.ThisUser.Handle;
        FDir.Flags     := 0;
        FDir.Downloads := 0;
        FDir.Rating    := 0;

        If Config.FDupeScan > 0 Then Begin
          Session.io.OutFull (Session.GetPrompt(377));

          If IsDupeFile(FileName, Config.FDupeScan = 2) Then Begin
            Session.io.OutFullLn (Session.GetPrompt(378));

            Continue;
          End Else
            Session.io.OutFullLn (Session.GetPrompt(379));
        End;

        If Config.TestUploads and (Config.TestCmdLine <> '') Then Begin
          Session.io.OutFull (Session.GetPrompt(206));

          Temp := '';
          A    := 1;

          While A <= Length(Config.TestCmdLine) Do Begin
            If Config.TestCmdLine[A] = '%' Then Begin
              Inc(A);
              {$IFDEF UNIX}
              If Config.TestCmdLine[A] = '0' Then Temp := Temp + '1' Else
              {$ELSE}
              If Config.TestCmdLine[A] = '0' Then Temp := Temp + strI2S(Session.Client.FSocketHandle) Else
              {$ENDIF}
              If Config.TestCmdLine[A] = '1' Then Temp := Temp + '1' Else
              If Config.TestCmdLine[A] = '2' Then Temp := Temp + '38400' Else
              If Config.TestCmdLine[A] = '3' Then Temp := Temp + FullName {FBase.Path + FileName};
            End Else
              Temp := Temp + Config.TestCmdLine[A];

            Inc(A);
          End;

          If ShellDOS('', Temp) <> Config.TestPassLevel Then Begin
            Session.io.OutFullLn (Session.GetPrompt(35));

            Session.SystemLog (FileName + ' has failed upload test');

            FDir.Flags := FDir.Flags or FDirFailed;
          End Else
            Session.io.OutFullLn (Session.GetPrompt(55));
        End;

        If Config.ImportDIZ Then Begin
          Session.io.OutFull (Session.GetPrompt(380));

          If ImportDIZ(FileName) Then
            Session.io.OutFullLn (Session.GetPrompt(381))
          Else Begin
            Session.io.OutFullLn (Session.GetPrompt(382));

            GetFileDescription(FileName);
          End;
        End Else
          GetFileDescription(FileName);

        FDir.DescPtr := FileSize(DataFile);

        For A := 1 to FDir.DescLines Do
          BlockWrite (DataFile, Session.Msgs.MsgText[A][0], Length(Session.Msgs.MsgText[A]) + 1);

        Assign (TempFile, FBase.Path + FileName);
        {$I-} Reset (TempFile, 1); {$I+}

        If IoResult = 0 Then Begin
          FDir.Size := FileSize(TempFile);
          Close (TempFile);
        End Else Begin
          FDir.Flags := FDir.Flags Or FDirOffline;
          FDir.Size  := 0;
        End;

        If Not Session.User.Access(Config.AcsValidate) Then FDir.Flags := FDir.Flags Or FDirInvalid;

        Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
        {$I-} Reset (FDirFile); {$I+}

        If IoResult <> 0 Then ReWrite (FDirFile);

        Seek  (FDirFile, FileSize(FDirFile));
        Write (FDirFile, FDir);
        Close (FDirFile);

        Inc (Session.User.ThisUser.ULs);
        Inc (Session.User.ThisUser.ULk, FDir.Size DIV 1024);
        Inc (Session.HistoryULs);
        Inc (Session.HistoryULKB, FDir.Size DIV 1024);
      End;
    End;

    Close (LogFile);
  End;

  Close (DataFile);

  FBase := OLD;

  DirClean(Session.TempPath, '');

  If Found Then
    Session.io.OutFullLn (Session.GetPrompt(75))
  Else
    Session.io.OutFullLn (Session.GetPrompt(424));
End;

Function TFileBase.CopiedToTemp (FName: String) : Boolean;
Var
  Copied : Boolean;
Begin
  Copied := False;

  If FBase.Flags And FBSlowMedia <> 0 Then Begin

    Copied := True;

    If Config.FreeCDROM > 0 Then
      Copied := DiskFree(0) DIV 1024 >= Config.FreeCDROM;

    If Copied Then Copied := DiskFree(0) >= FDir.Size;

    If Copied Then Begin
      Session.io.PromptInfo[1] := FName;
      Session.io.OutFullLn (Session.GetPrompt(82));

      Copied := FileCopy(FBase.Path + FName, Session.TempPath + FName)
    End;
  End;

  Result := Copied;
End;

Procedure TFileBase.DownloadFile;
Var
  FName : String[70];
  Dir   : String[40];
  Min   : Integer;
  Sec   : Byte;
Begin
  If FBase.FileName = '' Then Begin
    Session.io.OutFullLn(Session.GetPrompt(38));
    Exit;
  End;

  If Not Session.User.Access(FBase.DLAcs) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(76));
    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(344));

  FName := Session.io.GetInput(70, 70, 11, '');

  If FName = '' Then Exit;

  Session.io.OutFullLn (Session.GetPrompt(77));

  Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
  {$I-} Reset (FDirFile); {$I+}
  If IoResult <> 0 Then ReWrite (FDirFile);

  While Not Eof(FDirFile) Do Begin
    Read (FDirFile, FDir);
    {$IFDEF FS_SENSITIVE}
    If (FDir.FileName = FName) And (FDir.Flags And FDirDeleted = 0) Then Begin
    {$ELSE}
    If (strUpper(FDir.FileName) = strUpper(FName)) And (FDir.Flags And FDirDeleted = 0) Then Begin
    {$ENDIF}
      Case CheckFileLimits (1, FDir.Size DIV 1024) of
        0 : Begin
              Session.io.PromptInfo[1] := FDir.FileName;
              Session.io.PromptInfo[2] := strComma(FDir.Size);
              Session.io.PromptInfo[3] := FDir.Uploader;
              Session.io.PromptInfo[4] := DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType);
              Session.io.PromptInfo[5] := strI2S(FDir.Downloads);

              GetTransferTime (FDir.Size, Min, Sec);

              Session.io.PromptInfo[6] := strI2S(Min);
              Session.io.PromptInfo[7] := strI2S(Sec);

              Session.io.OutFull (Session.GetPrompt(78));

              If CopiedToTemp(FName) Then
                Dir := Session.TempPath
              Else
                Dir := FBase.Path;

              If SendFile(Dir + FName) Then Begin
                Session.SystemLog ('Downloaded: ' + FDir.FileName);

                Inc (Session.User.ThisUser.DLs);
                Inc (Session.User.ThisUser.DLsToday);
                Inc (Session.User.ThisUser.DLk, FDir.Size DIV 1024);
                Inc (Session.User.ThisUser.DLkToday, FDir.Size DIV 1024);
                Inc (FDir.Downloads);
                Inc (Session.HistoryDLs);
                Inc (Session.HistoryDLKB, FDir.Size DIV 1024);

                Seek  (FDirFile, FilePos(FDirFile) - 1);
                Write (FDirFile, FDir);
              End Else
                Session.SystemLog ('Download of ' + FDir.FileName + ' FAILED');

              FileErase(Session.TempPath + FName);
            End;
        1 : Session.io.OutFullLn (Session.GetPrompt(224));
        2 : Session.io.OutFullLn (Session.GetPrompt(58));
        3 : Session.io.OutFullLn (Session.GetPrompt(211));
      End;

      Close (FDirFile);
      Exit;
    End;
  End;

  Close (FDirFile);

  Session.io.OutFullLn (Session.GetPrompt(51));
End;

Procedure TFileBase.DownloadBatch;
Var
  A   : Byte;
  K   : LongInt;
  M   : Integer;
  Dir : String[40];
  Old : RecFileBase;
  FL  : Text;
Begin
  K := 0;

  For A := 1 to BatchNum Do Inc (K, Batch[A].Size);

  GetTransferTime (K, M, A);

  Session.io.PromptInfo[1] := strI2S(BatchNum);
  Session.io.PromptInfo[2] := strComma(K);
  Session.io.PromptInfo[3] := strI2S(M);
  Session.io.PromptInfo[4] := strI2S(A);

  Session.io.OutFullLn (Session.GetPrompt(79));

  If SelectProtocol(True) = 'Q' Then Exit;

  Assign  (FL, Session.TempPath + 'file.lst');
  ReWrite (FL);

  Reset (FBaseFile);

  For A := 1 to BatchNum Do Begin
    Seek (FBaseFile, Batch[A].Area - 1);
    Read (FBaseFile, Old);

    FDir.Size := Batch[A].Size;

    If CopiedToTemp(Batch[A].FileName) Then
      Dir := Session.TempPath
    Else
      Dir := Old.Path;

    WriteLn (FL, Dir + Batch[A].FileName);
  End;

  Close (FBaseFile);
  Close (FL);

  ExecuteProtocol(True, Session.TempPath + 'file.lst');

  Reset (FBaseFile);

  Session.io.OutRawLn ('');
  For A := 1 to BatchNum Do Begin
    Session.io.PromptInfo[1] := JustFile(Batch[A].FileName);

    If dszSearch (Batch[A].FileName) Then Begin
      Session.SystemLog ('Download: ' + Batch[A].FileName);

      Session.io.OutFullLn (Session.GetPrompt(385));

      Inc (Session.User.ThisUser.DLs);
      Inc (Session.User.ThisUser.DLsToday);
      Inc (Session.User.ThisUser.DLk,      Batch[A].Size DIV 1024);
      Inc (Session.User.ThisUser.DLkToday, Batch[A].Size DIV 1024);
      Inc (Session.HistoryDLs);
      Inc (Session.HistoryDLKB, Batch[A].Size DIV 1024);

      Seek (FBaseFile, Batch[A].Area - 1);
      Read (FBaseFile, Old);

      Assign (FDirFile, Config.DataPath + Old.FileName + '.dir');
      Reset  (FDirFile);

      While Not Eof(FDirFile) Do Begin
        Read (FDirFile, FDir);

        If (FDir.FileName = Batch[A].FileName) And (FDir.Flags And FDirDeleted = 0) Then Begin
          Inc (FDir.Downloads);
          Seek  (FDirFile, FilePos(FDirFile) - 1);
          Write (FDirFile, FDir);
          Break;
        End;
      End;

      Close (FDirFile);
    End Else Begin
      Session.SystemLog ('Download: ' + Batch[A].FileName + ' FAILED');

      Session.io.OutFullLn (Session.GetPrompt(386));
    End;
  End;

  Close (FBaseFile);

  BatchNum := 0;

  DirClean (Session.TempPath, '');
End;

Procedure TFileBase.FileSearch;
Var
  Str   : String[40];
  Done  : Boolean;
  Found : Boolean;
  All   : Boolean;

  Procedure Scan_Base;
  Begin
    Session.io.PromptInfo[1] := FBase.Name;
    Session.io.OutBS   (Screen.CursorX, True);
    Session.io.OutFull (Session.GetPrompt(87));
    Session.io.BufFlush;

    Case ListFiles (3, Str) of
      0 : Found := False;
      1 : Begin
            Done  := True;
            Found := True;
          End;
      2 : Found := True;
    End;
  End;

Var
  Old : RecFileBase;
Begin
  Old   := FBase;
  Found := False;
  Done  := False;
  All   := False;

  Session.io.OutFile ('fsearch', True, 0);

  Session.io.OutFull (Session.GetPrompt(196));

  Str := Session.io.GetInput(40, 40, 12, '');

  If Str = '' Then Exit;

  Session.SystemLog ('File search: "' + Str + '"');

  All := Session.io.GetYN(Session.GetPrompt(197), True);

  If All Then Session.User.IgnoreGroup := Session.io.GetYN(Session.GetPrompt(64), True);

  If All Then Begin
    Session.io.OutRawLn ('');

    Reset (FBaseFile);
    While (Not Eof(FBaseFile)) and (Not Done) Do Begin
      Found := False;
      Read (FBaseFile, FBase);
      If Session.User.Access(FBase.ListACS) Then Scan_Base;
    End;

    Close (FBaseFile);
  End Else Begin
    Session.io.OutRawLn ('');
    Reset (FBaseFile);
    Scan_Base;
    Close (FBaseFile);
  End;

  If Not Found Then Session.io.OutFullLn('|CR');

  Session.io.OutFullLn (Session.GetPrompt(198));

  FBase := Old;
  Session.User.IgnoreGroup := False;
End;

Procedure TFileBase.NewFileScan (Mode: Char);
Var
  TempFBase : RecFileBase;
  Found     : Boolean;
  Done      : Boolean;
  NewFiles  : Boolean;

  Procedure Scan_Current_Base;
  Begin
    Session.io.PromptInfo[1] := FBase.Name;

    Session.io.OutBS   (Screen.CursorX, True);
    Session.io.OutFull (Session.GetPrompt(87));
    Session.io.BufFlush;

    Case ListFiles (2, '') of
      0 : Found := False;
      1 : Begin
            Done     := True;
            Found    := True;
            NewFiles := True;
          End;
      2 : Begin
            Found    := True;
            NewFiles := True;
          End;
    End;

    FScan.LastNew := CurDateDos;

    SetFileScan;
  End;

Var
  Global : Boolean;
Begin
  TempFBase := FBase;
  Done      := False;
  Found     := False;
  NewFiles  := False;

  Session.SystemLog ('Scan for new files');

  Case Mode of
    'G' : Global := True;
    'C' : Global := False;
    'A' : Begin
            Global      := True;
            Session.User.IgnoreGroup := True;
          End;
  Else
    Global := Session.io.GetYN(Session.GetPrompt(86), True);
  End;

  Session.io.OutRawLn ('');

  If Global Then Begin
    Reset (FBaseFile);

    While (Not Eof(FBaseFile)) And (Not Done) Do Begin;
      Read (FBaseFile, FBase);
      GetFileScan;
      If (FScan.NewScan > 0) and Session.User.Access(FBase.ListACS) Then Scan_Current_Base;
    End;

    Close (FBaseFile);
  End Else Begin
    If FBase.FileName = '' Then
      Session.io.OutFullLn(Session.GetPrompt(038))
    Else Begin
      GetFileScan;
      Reset (FBaseFile);
      Scan_Current_Base;
      Close (FBaseFile);
    End;
  End;

  If Not Found Then Session.io.OutFullLn('|CR');

  If NewFiles Then
    Session.io.OutFullLn (Session.GetPrompt(89))
  Else
    Session.io.OutFullLn (Session.GetPrompt(88));

  Session.User.IgnoreGroup := False;
  FBase := TempFBase;
End;

(**************************************************************************)
(* FILE SECTION - SYSOP FUNCTIONS                                         *)
(**************************************************************************)

Procedure TFileBase.DirectoryEditor (Edit : Boolean; Mask: String);

Function Get_Next_File (Back: Boolean): Boolean;
Var
  Old : RecFileList;
  Pos : LongInt;
Begin
  Old := FDir;
  Pos := FilePos(FDirFile);

  Result := True;

  Repeat
    If (Eof(FDirFile) And Not Back) or ((FilePos(FDirFile) = 1) and Back) Then Begin
      FDir := Old;

      Seek (FDirFile, Pos);
      Result := False;
      Exit;
    End;
    If Back Then Seek (FDirFile, FilePos(FDirFile) - 2);
    Read (FDirFile, FDir);
    If (FDir.Flags And FDirDeleted = 0) and WildCardMatch(Mask, FDir.FileName) Then
      Break;
  Until False;
End;

Var
  DataFile  : File;
  DataFile2 : File;
  A         : Integer;
  B         : Integer;
  Temp      : String;
  Old       : RecFileBase;
  TF        : Text;
Begin
  If FBase.FileName = '' Then Begin
    Session.io.OutFullLn(Session.GetPrompt(38));
    Exit;
  End;

  If Not Session.User.Access(FBase.SysopACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(39));
    Exit;
  End;

  If Mask = '' Then Begin
    Session.io.OutFull (Session.GetPrompt(195));
    Mask := Session.io.GetInput(70, 70, 11, '*.*');
  End;

  Session.SystemLog ('File DIR editor');

  Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
  {$I-} Reset (FDirFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(40));
    Exit;
  End;

  If Eof(FDirFile) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(40));
    Close (FDirFile);
    Exit;
  End;

  Assign (DataFile, Config.DataPath + FBase.FileName + '.des');
  {$I-} Reset (DataFile, 1); {$I+}
  If IoResult <> 0 Then ReWrite (DataFile, 1);

  If Get_Next_File(False) Then Begin

    If Edit Then Mask := '*.*';

    Repeat
      Session.io.OutFullLn ('|07|CLFile DIR Editor : ' + strI2S(FilePos(FDirFile)) + ' of ' + strI2S(FileSize(FDirFile)));
      Session.io.OutFullLn ('|08|$D79Ä');
      Session.io.OutFullLn ('|031) |14' + FDir.FileName);
      Session.io.OutFullLn ('|08|$D79Ä');

      Session.io.OutFullLn ('|032) File Size : |11' + strPadR(strComma(FDir.Size) + ' bytes', 19, ' ') +
              '|033) Uploader  : |11' + FDir.Uploader);

      Session.io.OutFullLn ('|034) File Date : |11' + strPadR(DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType), 19, ' ') +
              '|035) Downloads : |11' + strI2S(FDir.Downloads));

      Session.io.OutFull   ('|036) Status    : |11');

      Temp := '';

      If FDir.Flags And FDirDeleted <> 0 Then
        Temp := '|12DELETED'
      Else Begin
        If FDir.Flags And FDirInvalid <> 0 Then Temp := 'Invalid ';
        If FDir.Flags And FDirOffline <> 0 Then Temp := Temp + 'Offline ';
        If FDir.Flags And FDirFailed  <> 0 Then Temp := Temp + 'Failed ';
        If FDir.Flags And FDirFree    <> 0 Then Temp := Temp + 'Free';
        If Temp = '' Then Temp := 'Normal';
      End;

      Session.io.OutFullLn (Temp);
      Session.io.OutFullLn ('|08|$D79Ä');

      Seek (DataFile, FDir.DescPtr);

      For A := 1 to 11 Do Begin
        Temp := '';
        If A <= FDir.DescLines Then Begin
          BlockRead (DataFile, Temp[0], 1);
          BlockRead (DataFile, Temp[1], Ord(Temp[0]));
        End;

        If A = 1 Then
          Session.io.OutFullLn ('|03!) Description : |07' + Temp)
        Else
          Session.io.OutFullLn (strRep(' ', 17) + Temp);
      End;

      Session.io.OutFullLn ('|08|$D79Ä');

      Session.io.OutFull ('|09([) Previous (]) Next         (D) Delete     (I) Import DIZ     (U) Update DIZ' +
            '|CR(M) Move     (V) View Archive (E) Email ULer (Q) Quit: ');

      Case Session.io.OneKey('123456[]DEIMQUV!', True) of
        '1' : Begin
                Temp := Session.io.InXY (4, 3, 70, 70, 11, FDir.FileName);

                If FBase.Flags And FBSlowMedia = 0 Then
                  If (Temp <> FDir.FileName) and (Temp <> '') Then Begin
                    If Not FileExist(FBase.Path + Temp) or (strUpper(Temp) = strUpper(FDir.FileName)) Then Begin
                      Assign(TF, FBase.Path + FDir.FileName);
                      {$I-} ReName(TF, FBase.Path + Temp); {$I+}
                      If IoResult = 0 Then FDir.FileName := Temp;
                    End;
                  End;
              End;
        'D' : Begin
                If Session.io.GetYN('|CR|12Delete this entry? |11', False) Then Begin
                  FDir.Flags := FDir.Flags Or FDirDeleted;
                  If FileExist(FBase.Path + FDir.FileName) Then
                    If Session.io.GetYN ('|12Delete ' + FBase.Path + FDir.FileName + '? |11', False) Then
                      FileErase(FBase.Path + FDir.FileName);
                End Else
                  FDir.Flags := FDir.Flags And (Not FDirDeleted);

                Seek  (FDirFile, FilePos(FDirFile) - 1);
                Write (FDirFile, FDir);
              End;
        'E' : Session.Menu.ExecuteCommand ('MW', '/TO:' + strReplace(FDir.Uploader, ' ', '_'));
        'I' : Begin
                Session.io.OutFullLn ('|CR|14Importing file_id.diz...');
                If ImportDIZ(FDir.FileName) Then Begin
                  FDir.DescPtr := FileSize(DataFile);
                  Seek (DataFile, FDir.DescPtr);
                  For A := 1 to FDir.DescLines Do
                    BlockWrite (DataFile, Session.Msgs.MsgText[A][0], Length(Session.Msgs.MsgText[A]) + 1);
                End;
              End;
        'M' : Begin
                Session.User.IgnoreGroup := True;
                Repeat
                  Session.io.OutFull ('|CR|09Move to which base (?/List): ');
                  Temp := Session.io.GetInput(4, 4, 12, '');
                  If Temp = '?' Then Begin
                    Old := FBase;
                    ListFileAreas(False);
                    FBase := Old;
                  End Else Begin
                    Reset (FBaseFile);
                    B := strS2I(Temp);
                    If (B > 0) and (B <= FileSize(FBaseFile)) Then Begin
                      Session.io.OutFull ('|CR|14Moving |15' + FDir.FileName + '|14: ');

                      Old := FBase;
                      Seek (FBaseFile, B - 1);
                      Read (FBaseFile, FBase);

                      If Not FileCopy (Old.Path + FDir.FileName, FBase.Path + FDir.FileName) Then Begin
                        Session.io.OutFull ('ERROR|CR|CR|PA');

                        FBase := Old;
                        Break;
                      End;

                      FileErase(Old.Path + FDir.FileName);

                      A := FilePos(FDirFile);
                      Close (FDirFile);

                      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
                      {$I-} Reset (FDirFile); {$I+}
                      If IoResult <> 0 Then ReWrite(FDirFile);

                      Assign (DataFile2, Config.DataPath + FBase.FileName + '.des');
                      {$I-} Reset (DataFile2, 1); {$I+}
                      If IoResult <> 0 Then ReWrite (DataFile2, 1);

                      Seek (DataFile, FDir.DescPtr);
                      FDir.DescPtr := FileSize(DataFile2);
                      Seek (DataFile2, FDir.DescPtr);

                      For B := 1 to FDir.DescLines Do Begin
                        BlockRead  (DataFile, Temp[0], 1);
                        BlockRead  (DataFile, Temp[1], Ord(Temp[0]));
                        BlockWrite (DataFile2, Temp[0], Length(Temp) + 1);
                      End;

                      Close (DataFile2);
                      Seek  (FDirFile, FileSize(FDirFile));
                      Write (FDirFile, FDir);
                      Close (FDirFile);

                      FBase := Old;

                      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');
                      Reset  (FDirFile);
                      Seek   (FDirFile, A - 1);
                      Read   (FDirFile, FDir);

                      FDir.Flags := FDir.Flags Or FDirDeleted;
                    End;

                    Close (FBaseFile);
                    Break;
                  End;
                Until False;

                Session.User.IgnoreGroup := False;
              End;
        'Q' : Begin
                Seek  (FDirFile, FilePos(FDirFile) - 1);
                Write (FDirFile, FDir);
                Break;
              End;
        'U' : Begin
                Session.io.OutFullLn ('|CR|14Updating FILE_ID.DIZ...');

                Assign (TF, Session.TempPath + 'file_id.diz');
                ReWrite (TF);
                Seek (DataFile, FDir.DescPtr);

                For B := 1 to FDir.DescLines Do Begin
                  BlockRead (DataFile, Temp[0], 1);
                  BlockRead (DataFile, Temp[1], Ord(Temp[0]));
                  WriteLn (TF, Temp);
                End;

                Close (TF);

                ExecuteArchive (FBase.Path + FDir.FileName, '', Session.TempPath + 'file_id.diz', 1);

                FileErase(Session.TempPath + 'file_id.diz');
              End;
        'V' : If Not ArchiveView (FBase.Path + FDir.FileName) Then Session.io.OutFullLn(Session.GetPrompt(191));
        '[' : Begin
                Seek  (FDirFile, FilePos(FDirFile) - 1);
                Write (FDirFile, FDir);

                Get_Next_File(True);
              End;
        ']' : Begin
                Seek  (FDirFile, FilePos(FDirFile) - 1);
                Write (FDirFile, FDir);

                Get_Next_File(False);
              End;
        '!' : Begin
                Seek (DataFile, FDir.DescPtr);
                If FDir.DescLines > Config.MaxFileDesc Then FDir.DescLines := Config.MaxFileDesc;

                For A := 1 to FDir.DescLines Do Begin
                  BlockRead (DataFile, Session.Msgs.MsgText[A][0], 1);
                  BlockRead (DataFile, Session.Msgs.MsgText[A][1], Ord(Session.Msgs.MsgText[A][0]));
                End;

                Temp := 'Description Editor';
                B    := FDir.DescLines;

                If Editor(B, mysMaxFileDescLen, Config.MaxFileDesc, True, False, Temp) Then Begin
                  FDir.DescLines   := B;
                  FDir.DescPtr     := FileSize(DataFile);

                  Seek (DataFile, FDir.DescPtr);

                  For A := 1 to FDir.DescLines Do
                    BlockWrite (DataFile, Session.Msgs.MsgText[A][0], Length(Session.Msgs.MsgText[A]) + 1);
                End;
              End;
        '2' : Begin
                Session.io.OutFull ('Size: ');
                FDir.Size := strS2I(Session.io.GetInput(8, 8, 12, strI2S(FDir.Size)));
              End;
        '4' : FDir.DateTime  := DateStr2Dos(Session.io.InXY(16, 6, 8, 8, 15, DateDos2Str(FDir.DateTime, Session.User.ThisUser.DateType)));
        '3' : FDir.Uploader  := Session.io.InXY(50, 5, 30, 30, 18, FDir.Uploader);
        '5' : FDir.Downloads := strS2I(Session.io.InXY(50, 6, 4, 4, 12, strI2S(FDir.Downloads)));
        '6' : Begin
                Session.io.OutFull('|CRFlags: F(a)iled, (F)ree, (O)ffline, (U)nvalidated, (Q)uit: ');
                Case Session.io.OneKey('AFOUQ', True) of
                  'A' : FDir.Flags := FDir.Flags XOR FDirFailed;
                  'F' : FDir.Flags := FDir.Flags XOR FDirFree;
                  'O' : FDir.Flags := FDir.Flags XOR FDirOffline;
                  'U' : FDir.Flags := FDir.Flags XOR FDirInvalid;
                End;
              End;
      End;
    Until False;
  End;

  Close (FDirFile);
  Close (DataFile);
End;

Procedure TFileBase.MassUpload;
Var
  Done    : Boolean;
  AutoAll : Boolean;

  Procedure Do_Area;
  Var
    A        : Byte;
    OldPos   : Word;
    Skip     : Boolean;
    DataFile : File;
    DirInfo  : SearchRec;
    AutoArea : Boolean;
    Temp     : String;
  Begin
    If FBase.FileName = '' Then Exit;

    AutoArea := AutoAll;

    Session.io.OutFullLn ('|CR|03Processing |14|FB|03...');

    Assign (DataFile, Config.DataPath + FBase.FileName + '.des');
    {$I-} Reset (DataFile, 1); {$I+}

    If IoResult = 0 Then
      Seek (DataFile, FileSize(DataFile))
    Else
      ReWrite (DataFile, 1);

    Assign (FDirFile, Config.DataPath + FBase.FileName + '.dir');

    FindFirst(FBase.Path + '*', Archive, DirInfo);

    While DosError = 0 Do Begin
      OldPos := FilePos(FBaseFile);
      Close (FBaseFile);

      CheckFileNameLength(FBase.Path, DirInfo.Name);

      Skip := IsDupeFile(DirInfo.Name, False);

      Reset (FBaseFile);
      Seek  (FBaseFile, OldPos);

      If Not Skip Then
        Session.io.OutFullLn ('|CR|03File : |14' + DirInfo.Name);

      If Not AutoArea And Not Skip Then Begin
        Session.io.OutFull ('|03Cmd  : |09(Y)es, (N)o, (A)uto, (G)lobal, (S)kip, (Q)uit: ');
        Case Session.io.OneKey('AGNQSY', True) of
          'A' : AutoArea := True;
          'G' : Begin
                  AutoArea := True;
                  AutoAll  := True;
                End;
          'N' : Skip := True;
          'Q' : Begin
                  Done := True;
                  Break;
                End;
          'S' : Break;
        End;
      End;

      If Not Skip Then Begin
        FDir.FileName  := DirInfo.Name;
        FDir.Size      := DirInfo.Size;
        FDir.DateTime  := CurDateDos;
        FDir.Uploader  := Session.User.ThisUser.Handle;
        FDir.Downloads := 0;
        FDir.Flags     := 0;
        FDir.DescLines := 0;
        FDir.Rating    := 0;

        If Config.ImportDIZ Then
          If Not ImportDIZ(DirInfo.Name) Then
            If Not AutoArea Then
              GetFileDescription(DirInfo.Name);

        If FDir.DescLines = 0 Then Begin
          Session.Msgs.MsgText[1] := Session.GetPrompt(208);
          FDir.DescLines := 1;
        End;

        FDir.DescPtr := FileSize(DataFile);

        For A := 1 to FDir.DescLines Do
          BlockWrite (DataFile, Session.Msgs.MsgText[A][0], Length(Session.Msgs.MsgText[A]) + 1);

        If Config.TestUploads and (Config.TestCmdLine <> '') Then Begin
          Temp := '';
          A    := 1;

          While A <= Length(Config.TestCmdLine) Do Begin
            If Config.TestCmdLine[A] = '%' Then Begin
              Inc(A);
              If Config.TestCmdLine[A] = '1' Then Temp := Temp + '1' Else
              If Config.TestCmdLine[A] = '2' Then Temp := Temp + '38400' Else
              If Config.TestCmdLine[A] = '3' Then Temp := Temp + FBase.Path + FDir.FileName;
            End Else
              Temp := Temp + Config.TestCmdLine[A];

            Inc (A);
          End;

          If ShellDOS('', Temp) <> Config.TestPassLevel Then
            FDir.Flags := FDir.Flags OR FDirFailed;
        End;

        {$I-} Reset (FDirFile); {$I+}

        If IoResult <> 0 Then ReWrite(FDirFile);

        Seek  (FDirFile, FileSize(FDirFile));
        Write (FDirFile, FDir);
        Close (FDirFile);
      End;

      FindNext(DirInfo);
    End;

    FindClose(DirInfo);

    Close (DataFile);
  End;

Var
  Old : RecFileBase;
  Pos : LongInt;
Begin
  Session.SystemLog ('Mass upload');

  Old     := FBase;
  Done    := False;
  AutoAll := False;

  Reset (FBaseFile);

  If Session.io.GetYN('|CR|12Upload files in all directories? |11', True) Then Begin {++lang}
    While Not Done and Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, FBase);
      Pos := FilePos(FBaseFile);
      Do_Area;
      Seek (FBaseFile, Pos);
    End;
  End Else
    Do_Area;

  Close (FBaseFile);

  FBase := Old;
End;

End.

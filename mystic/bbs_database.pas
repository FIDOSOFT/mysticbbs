Unit BBS_DataBase;

{$I M_OPS.PAS}

Interface

Uses
  BBS_Records,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Var
  bbsCfg       : RecConfig;
  bbsCfgPath   : String;
  bbsCfgStatus : Byte;

Const
  CfgOK       = 0;
  CfgNotFound = 1;
  CfgMisMatch = 2;

// GENERAL

Function  GetBaseConfiguration  (UseEnv: Boolean; Var TempCfg: RecConfig) : Byte;
Function  PutBaseConfiguration  (Var TempCfg: RecConfig) : Boolean;
Function  ShellDOS              (ExecPath: String; Command: String) : LongInt;

// MESSAGE BASE

Function  MBaseOpenCreate       (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Function  GetMBaseByIndex       (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Procedure GetMessageScan        (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Procedure PutMessageScan        (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);

// FILE BASE

Procedure ExecuteArchive        (TempP: String; FName: String; Temp: String; Mask: String; Mode: Byte);
Function  GetTotalFiles         (Var TempBase: RecFileBase) : LongInt;

// USER

Function IsThisUser             (U: RecUser; Str: String) : Boolean;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings;

Function GetBaseConfiguration (UseEnv: Boolean; Var TempCfg: RecConfig) : Byte;
Var
  TempFile : File;
Begin
  Result     := CfgOK;
  bbsCfgPath := '';

  If Not FileExist('mystic.dat') And UseEnv Then
    If GetENV('mysticbbs') <> '' Then
      bbsCfgPath := DirSlash(GetENV('mysticbbs'));

  Assign (TempFile, bbsCfgPath + 'mystic.dat');

  If ioReset (TempFile, SizeOf(RecConfig), fmRWDN) Then Begin
    ioRead (TempFile, TempCfg);
    Close  (TempFile);
  End Else Begin
    Result := CfgNotFound;

    Exit;
  End;

  If TempCfg.DataChanged <> mysDataChanged Then
    Result := CfgMisMatch;
End;

Function PutBaseConfiguration (Var TempCfg: RecConfig) : Boolean;
Var
  TempFile : File;
Begin
  Result := False;

  Assign (TempFile, bbsCfgPath + 'mystic.dat');

  If ioReset (TempFile, SizeOf(RecConfig), fmRWDW) Then Begin
    ioWrite (TempFile, TempCfg);
    Close   (TempFile);

    bbsCfg := TempCfg;
    Result := True;
  End;
End;

Function ShellDOS (ExecPath: String; Command: String) : LongInt;
Var
  CurDIR : String;
Begin
  GetDIR (0, CurDIR);

  If ExecPath <> '' Then DirChange(ExecPath);

  {$IFDEF UNIX}
    Result := Shell(Command);
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;

    Exec (GetEnv('COMSPEC'), Command);

    Result := DosExitCode;
  {$ENDIF}

  DirChange(CurDIR);
End;

Function GetMBaseByIndex (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempBase);

    If TempBase.Index = Num Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

Procedure GetMessageScan (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Var
  ScanFile : File;
Begin
  TempScan.NewScan := TempBase.DefNScan;
  TempScan.QwkScan := TempBase.DefQScan;

  Assign (ScanFile, TempBase.Path + TempBase.FileName + '.scn');

  If Not ioReset(ScanFile, SizeOf(TempScan), fmRWDN) Then
    Exit;

  If FileSize(ScanFile) >= UN Then Begin
    If ioSeek (ScanFile, UN - 1) Then
      ioRead (ScanFile, TempScan);

    If TempBase.DefNScan = 2 Then TempScan.NewScan := 2;
    If TempBase.DefQScan = 2 Then TempScan.QwkScan := 2;
  End;

  Close (ScanFile);
End;

Procedure PutMessageScan (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);
Var
  ScanFile : File;
  Count    : Cardinal;
  Temp     : MScanRec;
  FileName : String;
Begin
  Temp.NewScan := TempBase.DefNScan;
  Temp.QwkScan := TempBase.DefQScan;

  FileName     := TempBase.Path + TempBase.FileName + '.scn';

  Assign (ScanFile, FileName);

  If Not ioReset (ScanFile, SizeOf(TempScan), fmRWDW) Then Begin
    If FileExist(FileName) Then Exit;

    If Not ioReWrite(ScanFile, SizeOf(TempScan), fmRWDW) Then Exit;
  End;

  If FileSize(ScanFile) < UN - 1 Then Begin
    ioSeek (ScanFile, FileSize(ScanFile));

    For Count := FileSize(ScanFile) to UN - 1 Do
      ioWrite (ScanFile, Temp);
  End;

  ioSeek  (ScanFile, UN - 1);
  ioWrite (ScanFile, TempScan);
  Close   (ScanFile);
End;

Function MBaseOpenCreate (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Begin
  Result := False;

  Case Area.BaseType of
    0 : Msg := New(PMsgBaseJAM, Init);
    1 : Msg := New(PMsgBaseSquish, Init);
  End;

  Msg^.SetMsgPath  (Area.Path + Area.FileName);
  Msg^.SetTempFile (TP + 'msgbuf.');

  If Not Msg^.OpenMsgBase Then
    If Not Msg^.CreateMsgBase (Area.MaxMsgs, Area.MaxAge) Then Begin
      Dispose (Msg, Done);

      Exit;
    End Else
    If Not Msg^.OpenMsgBase Then Begin
      Dispose (Msg, Done);

      Exit;
    End;

  Result := True;
End;

Function GetTotalFiles (Var TempBase: RecFileBase) : LongInt;
Begin
  Result := 0;

  If TempBase.Name = 'None' Then Exit;

  Result := FileByteSize(bbsCfg.DataPath + TempBase.FileName + '.dir');

  If Result > 0 Then
    Result := Result DIV SizeOf(RecFileList);
End;

Function IsThisUser (U: RecUser; Str: String) : Boolean;
Begin
  Str    := strUpper(Str);
  Result := (strUpper(U.RealName) = Str) or (strUpper(U.Handle) = Str);
End;

Procedure ExecuteArchive (TempP: String; FName: String; Temp: String; Mask: String; Mode: Byte);
Var
  ArcFile : File;
  Arc     : RecArchive;
  Count   : LongInt;
  Str     : String;
Begin
  If Temp <> '' Then
    Temp := strUpper(Temp)
  Else
    Temp := strUpper(JustFileExt(FName));

  Assign (ArcFile, bbsCfg.DataPath + 'archive.dat');

  If Not ioReset (ArcFile, SizeOf(RecArchive), fmRWDN) Then Exit;

  Repeat
    If Eof(ArcFile) Then Begin
      Close (ArcFile);

      Exit;
    End;

    ioRead (ArcFile, Arc);

    If (Not Arc.Active) or ((Arc.OSType <> OSType) and (Arc.OSType <> 3)) Then Continue;

    If strUpper(Arc.Ext) = Temp Then Break;
  Until False;

  Close (ArcFile);

  Case Mode of
    1 : Str := Arc.Pack;
    2 : Str := Arc.Unpack;
  End;

  If Str = '' Then Exit;

  Temp  := '';
  Count := 1;

  While Count <= Length(Str) Do Begin
    If Str[Count] = '%' Then Begin
      Inc (Count);

      If Str[Count] = '1' Then Temp := Temp + FName Else
      If Str[Count] = '2' Then Temp := Temp + Mask Else
      If Str[Count] = '3' Then Temp := Temp + TempP;
    End Else
      Temp := Temp + Str[Count];

    Inc (Count);
  End;

  ShellDOS ('', Temp);
End;

Initialization

  bbsCfgStatus := GetBaseConfiguration(True, bbsCfg);

End.

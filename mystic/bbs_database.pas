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

// MESSAGE BASE

Function  MBaseOpenCreate       (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Function  GetMBaseByIndex       (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Procedure GetMessageScan        (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Procedure PutMessageScan        (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);

// FILE BASE

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

Initialization

  bbsCfgStatus := GetBaseConfiguration(True, bbsCfg);

End.

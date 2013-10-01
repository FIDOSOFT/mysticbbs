Unit BBS_DataBase;

// for all functions... need to go through code and remove old stuff and
// replace with this new stuff one at a time.  including moving everything
// to bbscfg.

// add generatembase/fbase/userindex functions?

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_Output,
  m_Input,
  BBS_Records,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Var
  bbsCfg       : RecConfig;
  bbsCfgPath   : String;
  bbsCfgStatus : Byte;
  Console      : TOutput;
  Keyboard     : TInput;

Const
  CfgOK       = 0;
  CfgNotFound = 1;
  CfgMisMatch = 2;

Type
  FileDescBuffer = Array[1..99] of String[50];

// GENERAL

Function  GetBaseConfiguration  (UseEnv: Boolean; Var TempCfg: RecConfig) : Byte;
Function  PutBaseConfiguration  (Var TempCfg: RecConfig) : Boolean;
Function  ExecuteProgram        (ExecPath: String; Command: String) : LongInt;
Function  Addr2Str              (Addr : RecEchoMailAddr) : String;
Function  Str2Addr              (S : String; Var Addr: RecEchoMailAddr) : Boolean;

// MESSAGE BASE

Function  MBaseOpenCreate       (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Function  GetOriginLine         (Var mArea: RecMessageBase) : String;
Function  GetMBaseByIndex       (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Function  GetMBaseByQwkID       (QwkNet, QwkConf: LongInt; Var TempBase: RecMessageBase) : Boolean;
Procedure GetMessageScan        (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Procedure PutMessageScan        (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);
Procedure MBaseAssignData       (Var User: RecUser; Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
Function  GetQWKNetByIndex      (Num: LongInt; Var TempNet: RecQwkNetwork) : Boolean;

// FILE BASE

Procedure ExecuteArchive        (TempP: String; FName: String; Temp: String; Mask: String; Mode: Byte);
Function  GetTotalFiles         (Var TempBase: RecFileBase) : LongInt;
Function  IsDuplicateFile       (Base: RecFileBase; FileName: String; Global: Boolean) : Boolean;
Function  ImportFileDIZ         (Var Desc: FileDescBuffer; Var DescLines: Byte; TempP, FN: String) : Boolean;

// USER

Function IsThisUser             (U: RecUser; Str: String) : Boolean;

// ECHOMAIL

Function GetNodeByAddress (Addr: String; Var TempNode: RecEchoMailNode) : Boolean;
Function GetFTNBundleExt  (IncOnly: Boolean; Str: String) : String;

Implementation

Uses
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  DOS,
  m_FileIO,
  m_DateTime,
  m_Strings;

Function Addr2Str (Addr : RecEchoMailAddr) : String;
Var
  Temp : String[20];
Begin
  Temp := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' +
          strI2S(Addr.Node);

  If Addr.Point <> 0 Then Temp := Temp + '.' + strI2S(Addr.Point);

  Result := Temp;
End;

Function Str2Addr (S: String; Var Addr: RecEchoMailAddr) : Boolean;
Var
  A     : Byte;
  B     : Byte;
  C     : Byte;
  D     : Byte;
  Point : Boolean;
Begin
  Result := False;
  Point  := True;

  D := Pos('@', S);
  A := Pos(':', S);
  B := Pos('/', S);
  C := Pos('.', S);

  If (A = 0) or (B <= A) Then Exit;

  If D > 0 Then
    Delete (S, D, 255);

  If C = 0 Then Begin
    Point      := False;
    C          := Length(S) + 1;
    Addr.Point := 0;
  End;

  Addr.Zone := strS2I(Copy(S, 1, A - 1));
  Addr.Net  := strS2I(Copy(S, A + 1, B - 1 - A));
  Addr.Node := strS2I(Copy(S, B + 1, C - 1 - B));

  If Point Then Addr.Point := strS2I(Copy(S, C + 1, Length(S)));

  Result := True;
End;

Function GetOriginLine (Var mArea: RecMessageBase) : String;
Var
  Loc   : Byte;
  FN    : String;
  TF    : Text;
  Buf   : Array[1..2048] of Char;
  Str   : String;
  Count : LongInt;
  Pick  : LongInt;
Begin
  Result := '';
  Loc    := Pos('@RANDOM=', strUpper(mArea.Origin));

  If Loc > 0 Then Begin
    FN := strStripB(Copy(mArea.Origin, Loc + 8, 255), ' ');

    If Pos(PathChar, FN) = 0 Then FN := bbsCfg.DataPath + FN;

    FileMode := 66;

    Assign     (TF, FN);
    SetTextBuf (TF, Buf, SizeOf(Buf));

    {$I-} Reset (TF); {$I+}

    If IoResult <> 0 Then Exit;

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);
    End;

    If Count = 0 Then Begin
      Close (TF);
      Exit;
    End;

    Pick := Random(Count) + 1;

    Reset (TF);

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);

      If Count = Pick Then Begin
        Result := Str;
        Break;
      End;
    End;

    Close (TF);
  End Else
    Result := mArea.Origin;
End;

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

Function ExecuteProgram (ExecPath: String; Command: String) : LongInt;
Var
  CurDIR : String;
  Image  : TConsoleImageRec;
Begin
  If Console <> NIL Then
    Console.GetScreenImage(1, 1, 80, 25, Image);

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

  If Console <> NIL Then
    Console.PutScreenImage(Image);
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

Function GetMBaseByQwkID (QwkNet, QwkConf: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempBase);

    If (TempBase.QwkNetID = QwkNet) and (TempBase.QwkConfID = QwkConf) Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

Function GetQWKNetByIndex (Num: LongInt; Var TempNet: RecQwkNetwork) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'qwknet.dat');

  If Not ioReset(F, SizeOf(RecQwkNetwork), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempNet);

    If TempNet.Index = Num Then Begin
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

Procedure MBaseAssignData (Var User: RecUser; Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
Var
  SemFile : Text;
Begin
  Msg^.StartNewMsg;

  If TempBase.Flags And MBRealNames <> 0 Then
    Msg^.SetFrom(User.RealName)
  Else
    Msg^.SetFrom(User.Handle);

  Msg^.SetLocal (True);

  If TempBase.NetType > 0 Then Begin
    If TempBase.NetType = 3 Then
      Msg^.SetMailType(mmtNetMail)
    Else
      Msg^.SetMailType(mmtEchoMail);

    Msg^.SetOrig(bbsCfg.NetAddress[TempBase.NetAddr]);

    Case TempBase.NetType of
      1 : If TempBase.QwkConfID = 0 Then
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileEchoOut)
          Else
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileQwk);
      2 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNews);
      3 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNet);
    End;

    ReWrite (SemFile);
    Close   (SemFile);
  End Else
    Msg^.SetMailType(mmtNormal);

  Msg^.SetPriv (TempBase.Flags and MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, 0));
  Msg^.SetSent (False);
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

  ExecuteProgram ('', Temp);
End;

Function IsDuplicateFile (Base: RecFileBase; FileName: String; Global: Boolean) : Boolean;

  Procedure CheckOneArea;
  Var
    TempFile : TFileBuffer;
    Temp     : RecFileList;
  Begin
    TempFile := TFileBuffer.Create(8 * 1024);

    If Not TempFile.OpenStream (bbsCfg.DataPath + Base.FileName + '.dir', SizeOf(RecFileList), fmOpen, fmRWDN) Then Begin
      TempFile.Free;

      Exit;
    End;

    While Not TempFile.EOF Do Begin
      TempFile.ReadRecord(Temp);

      {$IFDEF FS_SENSITIVE}
      If (Temp.FileName = FileName) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ELSE}
      If (strUpper(Temp.FileName) = strUpper(FileName)) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ENDIF}
        Result := True;

        Break;
      End;
    End;

    TempFile.Free;
  End;

Var
  BaseFile : File;
Begin
  Result := False;

  If Global Then Begin
    Assign (BaseFile, bbsCfg.DataPath + 'fbases.dat');

    If ioReset (BaseFile, SizeOf(RecFileBase), fmRWDN) Then Begin
      While Not EOF(BaseFile) And Not Result Do Begin
        ioRead (BaseFile, Base);

        CheckOneArea;
      End;

      Close (BaseFile);
    End;
  End Else
    CheckOneArea;
End;

Function ImportFileDIZ (Var Desc: FileDescBuffer; Var DescLines: Byte; TempP, FN: String) : Boolean;

  Procedure RemoveLine (Num: Byte);
  Var
    Count : Byte;
  Begin
    For Count := Num To DescLines - 1 Do
      Desc[Count] := Desc[Count + 1];

    Desc[DescLines] := '';

    Dec (DescLines);
  End;

Var
  DizFile : Text;
Begin
  Result    := False;
  DescLines := 0;

  ExecuteArchive (TempP, FN, '', 'file_id.diz', 2);

  Assign (DizFile, FileFind(TempP + 'file_id.diz'));

  {$I-} Reset (DizFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(DizFile) Do Begin
      Inc    (DescLines);
      ReadLn (DizFile, Desc[DescLines]);

      Desc[DescLines] := strStripLow(Desc[DescLines]);

      If DescLines = bbsCfg.MaxFileDesc Then Break;
    End;

    Close (DizFile);
    Erase (DizFile);

    While (Desc[1] = '') and (DescLines > 0) Do
      RemoveLine(1);

    While (Desc[DescLines] = '') And (DescLines > 0) Do
      Dec (DescLines);

    Result := True;
  End;
End;

Function GetNodeByAddress (Addr: String; Var TempNode: RecEchoMailNode) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) And Not Result Do Begin
    ioRead(F, TempNode);

    Result := Addr2Str(TempNode.Address) = Addr;
  End;

  Close (F);
End;

Function GetFTNBundleExt (IncOnly: Boolean; Str: String) : String;
Var
  FN    : String;
  Ext   : String;
  Last  : Byte;
  First : Byte;
Begin
  FN  := JustFileName(Str);
  Ext := strLower(JustFileExt(Str));

  Last := Byte(Ext[Length(Ext)]);

  If Not (Last in [48..57, 97..122]) Then Last := 48;

  First := Last;

  Repeat
    Result := FN + '.' + Ext;
    Result[Length(Result)] := Char(Last);

    If IncOnly Then Begin
      If First <> Last Then
        Break;
    End Else
      If Not FileExist(Result) Then Break;

    Inc (Last);

    If Last = 58  Then Last := 97;
    If Last = 123 Then Last := 48; // loop

    If First = Last Then Begin
      Result[Length(Result)] := Char(123);
      Break;
    End;
  Until False;
End;

Initialization

  bbsCfgStatus := GetBaseConfiguration(True, bbsCfg);
  Console      := NIL;
  Keyboard     := NIL;

Finalization

  If Assigned(Console)  Then Console.Free;
  If Assigned(Keyboard) Then Keyboard.Free;

End.

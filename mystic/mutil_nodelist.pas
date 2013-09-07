Unit mUtil_NodeList;

{$I M_OPS.PAS}

Interface

Procedure uMergeNodeList;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings,
  m_DateTime,
  BBS_DataBase,
  mUtil_Common,
  mUtil_Status;

Var
  NodeListNoPrivate : Boolean;
  NodeListNoDown    : Boolean;

Procedure FileAppend (F1, F2: String);
Var
  BufIn,
  BufOut : Array[1..8*1024] of Char;
  TF1    : Text;
  TF2    : Text;
  Str    : String;
Begin
  Assign (TF1, F1);

  {$I-} Reset(TF1); {$I+}

  If IoResult <> 0 Then Exit;

  SetTextBuf (TF1, BufIn);

  Assign (TF2, F2);
  {$I-} Append(TF2); {$I+}

  If (IoResult = 2) Then
    ReWrite (TF2);

  SetTextBuf (TF2, BufOut);

  While Not Eof(TF1) Do Begin
    ReadLn  (TF1, Str);

    If (Str[1] = ';') Then
      Continue;

    If NodeListNoDown And (Copy(Str, 1, 4) = 'Down') Then
      Continue;

    If NodeListNoPrivate And (Copy(Str, 1, 3) = 'Pvt') Then
      Continue;

    WriteLn (TF2, Str);
  End;

  Close (TF1);
  Close (TF2);
End;

Procedure ExtractNodeLists (BaseFile: String);
Var
  DirInfo  : SearchRec;
  FileChar : Char;
  FileNum  : LongInt;
  ArcType  : String;
Begin
  DirClean (TempPath, '');

  FindFirst (BaseFile + '.*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory <> 0 Then Begin
      FindNext (DirInfo);

      Continue;
    End;

    FileChar := UpCase(JustFileExt(DirInfo.Name)[1]);
    FileNum  := strS2I(Copy(JustFileExt(DirInfo.Name), 2, 255));

    If (FileChar in ['A','L','R','Z']) and (FileNum > 0) Then Begin
      Case FileChar of
        'A' : ArcType := 'ARJ';
        'L' : ArcType := 'LZH';
        'R' : ArcType := 'RAR';
        'Z' : ArcType := 'ZIP';
      End;

      ProcessStatus  ('Extracting ' + JustFile(DirInfo.Name), False);
      ExecuteArchive (TempPath, JustPath(BaseFile) + DirInfo.Name, ArcType, '*', 2);
    End;

    FindNext(DirInfo);
  End;

  FindClose(DirInfo);
End;

Function CompareFileInfo (F1: SearchRec; F2: SearchRec; Var Winner: Byte) : SearchRec;
Var
  DT1 : DateTime;
  DT2 : DateTime;
Begin
  Winner := 0;

  UnpackTime (F1.Time, DT1);
  UnpackTime (F2.Time, DT2);

  Log (3, '+', '   Compare ' + F1.Name + ' ' + FormatDate(DT1, 'YYYY') + ' / ' + F2.Name + ' ' + FormatDate(DT2, 'YYYY'));

  If strS2I(JustFileExt(F1.Name)) >= strS2I(JustFileExt(F2.Name)) Then
    If DT1.Year >= DT2.Year Then Begin
      Result := F1;
      Winner := 1;
    End Else Begin
      Result := F2;
      Winner := 2;
    End;

  If strS2I(JustFileExt(F2.Name)) >= strS2I(JustFileExt(F1.Name)) Then
    If DT2.Year >= DT1.Year Then Begin
      Result := F2;
      Winner := 2;
    End Else Begin
      Result := F1;
      Winner := 1;
    End;

  Log (3, '+', '      Result ' + strI2S(Winner));
End;

Function FindNodeListFile (Var Res: SearchRec; BaseFile: String) : Boolean;
Var
  DirInfo : SearchRec;
  Temp    : Byte;
Begin
  Result := False;

  FillChar (Res, SizeOf(Res), 0);

  FindFirst (BaseFile + '.*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory <> 0 Then Begin
      FindNext (DirInfo);

      Continue;
    End;

    If strS2I(JustFileExt(DirInfo.Name)) > 0 Then Begin
      Result := True;
      Res    := CompareFileInfo(DirInfo, Res, Temp);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Procedure ProcessNodeList (BaseFile: String);
Var
  Winner   : Byte;
  Dir1     : SearchRec;
  Dir2     : SearchRec;
  Res      : SearchRec;
  ResPath  : String;
  Got1     : Boolean;
  Got2     : Boolean;
  NotFound : Boolean;
Begin
  ExtractNodeLists (BaseFile);

  Got1 := FindNodeListFile (Dir1, BaseFile);
  Got2 := FindNodeListFile (Dir2, TempPath + JustFile(BaseFile));

  NotFound := False;

  If Got1 And Got2 Then Begin
    Res := CompareFileInfo(Dir1, Dir2, Winner);

    If Winner = 1 Then
      ResPath := JustPath(BaseFile)
    Else
      ResPath := TempPath;
  End Else
  If Got1 Then Begin
    Res     := Dir1;
    ResPath := JustPath(BaseFile);
  End Else
  If Got2 Then Begin
    Res     := Dir2;
    ResPath := TempPath;
  End Else
    NotFound := True;

  If Not NotFound Then Begin
    ProcessStatus  ('Merging ' + ResPath + Res.Name, False);
    FileAppend     (ResPath + Res.Name, bbsCfg.DataPath + 'nodelist.txt');
  End;

  DirClean(TempPath, '');
End;

Procedure uMergeNodeList;
Var
  Done  : LongInt = 0;
  Total : LongInt = 0;
  List  : String;
Begin
  ProcessName   ('Merging Nodelists', True);
  ProcessResult (rWORKING, False);

  FileErase  (bbsCfg.DataPath + 'nodelist.$$$');
  FileReName (bbsCfg.DataPath + 'nodelist.txt', bbsCfg.DataPath + 'nodelist.$$$');

  NodeListNoDown    := Ini.ReadBoolean(Header_NODELIST, 'strip_down', False);
  NodeListNoPrivate := Ini.ReadBoolean(Header_NODELIST, 'strip_private', False);

  Ini.SetSequential(True);

  Repeat
    List := INI.ReadString(Header_NODELIST, 'nodefile', '');

    If List = '' Then Break;

    Inc (Total);
  Until False;

  Ini.SetSequential(True);

  Repeat
    List := INI.ReadString(Header_NODELIST, 'nodefile', '');

    If List = '' Then Break;

    Inc (Done);

    ProcessStatus ('Merging ' + JustFile(List), False);
    BarOne.Update (Done, Total);

    ProcessNodeList(List);
  Until False;

  If FileExist (bbsCfg.DataPath + 'nodelist.txt') Then
    FileErase (bbsCfg.DataPath + 'nodelist.$$$')
  Else
    FileReName (bbsCfg.DataPath + 'nodelist.$$$', bbsCfg.DataPath + 'nodelist.txt');

  ProcessStatus ('Merged |15' + strI2S(Done) + ' |07of |15' + strI2S(Total) + ' |07nodelist(s)', True);
  ProcessResult (rDONE, True);
End;

End.

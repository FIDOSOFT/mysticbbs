Unit MUTIL_Common;

{$I M_OPS.PAS}

Interface

Uses
  INIFiles,
  m_Output,
  mutil_Status;

{$I RECORDS.PAS}

Var
  Console      : TOutput;
  INI          : TINIFile;
  BarOne       : TStatusBar;
  BarAll       : TStatusBar;
  ProcessTotal : Byte = 0;
  ProcessPos   : Byte = 0;
  bbsConfig    : RecConfig;
  TempPath     : String;
  StartPath    : String;

Const
  Header_GENERAL  = 'General';
  Header_IMPORTNA = 'Import_FIDONET.NA';
  Header_UPLOAD   = 'MassUpload';

Function  strAddr2Str        (Addr : RecEchoMailAddr) : String;
Function  GenerateMBaseIndex : LongInt;
Function  IsDupeMBase        (FN: String) : Boolean;
Procedure AddMessageBase     (Var MBase: RecMessageBase);
Function  ShellDOS           (ExecPath: String; Command: String) : LongInt;
Procedure ExecuteArchive     (FName: String; Temp: String; Mask: String; Mode: Byte);

Implementation

Uses
  {$IFDEF UNIX}
    Unix
  {$ENDIF}
  DOS,
  m_Types,
  m_Strings,
  m_FileIO;

Function strAddr2Str (Addr : RecEchoMailAddr) : String;
Var
  Temp : String[20];
Begin
  Temp := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' +
          strI2S(Addr.Node);

  If Addr.Point <> 0 Then Temp := Temp + '.' + strI2S(Addr.Point);

  Result := Temp;
End;

Function IsDupeMBase (FN: String) : Boolean;
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
Begin
  Result := False;

  Assign (MBaseFile, bbsConfig.DataPath + 'mbases.dat');
  {$I-} Reset (MBaseFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If strUpper(MBase.FileName) = strUpper(FN) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (MBaseFile);
End;

Function GenerateMBaseIndex : LongInt;
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
Begin
  Assign (MBaseFile, bbsConfig.DataPath + 'mbases.dat');
  Reset  (MBaseFile);

  Result := FileSize(MBaseFile);

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If MBase.Index = Result Then Begin
      Inc   (Result);
      Reset (MBaseFile);
    End;
  End;

  Close (MBaseFile);
End;

Procedure AddMessageBase (Var MBase: RecMessageBase);
Var
  MBaseFile : File of RecMessageBase;
Begin
  Assign (MBaseFile, bbsConfig.DataPath + 'mbases.dat');
  Reset  (MBaseFile);
  Seek   (MBaseFile, FileSize(MBaseFile));
  Write  (MBaseFile, MBase);
  Close  (MBaseFile);
End;

Function ShellDOS (ExecPath: String; Command: String) : LongInt;
Var
  Image : TConsoleImageRec;
Begin
  Console.GetScreenImage(1, 1, 80, 25, Image);

  If ExecPath <> '' Then DirChange(ExecPath);

  {$IFDEF UNIX}
    Result := Shell(Command);
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;

    Exec (GetEnv('COMSPEC'), Command);

    Result := DosExitCode;
  {$ENDIF}

  DirChange(StartPath);

  Console.PutScreenImage(Image);
End;

Procedure ExecuteArchive (FName: String; Temp: String; Mask: String; Mode: Byte);
Var
  ArcFile : File of RecArchive;
  Arc     : RecArchive;
  Count   : LongInt;
  Str     : String;
Begin
  Temp := strUpper(JustFileExt(FName));

  Assign (ArcFile, bbsConfig.DataPath + 'archive.dat');
  {$I-} Reset (ArcFile); {$I+}

  If IoResult <> 0 Then Exit;

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
      If Str[Count] = '3' Then Temp := Temp + TempPath;
    End Else
      Temp := Temp + Str[Count];

    Inc (Count);
  End;

  ShellDOS ('', Temp);
End;

End.

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

Const
  Header_GENERAL  = 'General';
  Header_IMPORTNA = 'Import_FIDONET.NA';

Function  strAddr2Str        (Addr : RecEchoMailAddr) : String;
Function  GenerateMBaseIndex : LongInt;
Function  IsDupeMBase        (FN: String) : Boolean;
Procedure AddMessageBase     (Var MBase: RecMessageBase);

Implementation

Uses
  m_Strings;

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

    {$IFDEF FS_SENSITIVE}
    If MBase.FileName = FN Then Begin
    {$ELSE}
    If strUpper(MBase.FileName) = strUpper(FN) Then Begin
    {$ENDIF}
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

End.

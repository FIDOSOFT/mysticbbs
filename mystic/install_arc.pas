Unit Install_Arc;

{ MYS archive procedures }

Interface

Const
  maVersion = 3;
  maHeader  = 'MYS' + #26;

Type
  maHeaderRec = Record
    Header  : String[4];
    Version : Word;
    Files   : LongInt;
  End;

  maFileHdrRec = Record
    Header   : String[4];
    FileName : String[80];
    FileSize : LongInt;
    Execute  : Boolean;
    EID      : String[6];
  End;

Var
  maHdr     : maHeaderRec;
  maFileHdr : maFileHdrRec;

Function  maOpenExtract   (FN : String; EID: String; ExtractDIR : String) : Boolean;
Function  maOpenCreate    (FN : String; Add: Boolean) : Boolean;
Function  maAddFile       (Path, EID, FN : String) : Boolean;
Function  maNextFile      : Boolean;
Function  maExtractFile   : Boolean;
Procedure maCloseFile;

Implementation

{$IFDEF UNIX}
  Uses
    BaseUnix,
    Unix;
{$ENDIF}

Function LoCase (C: Char): Char;
Begin
  If (C in ['A'..'Z']) Then
    LoCase := Chr(Ord(C) + 32)
  Else
    LoCase := C;
End;

Function Lower (Str : String) : String;
Var
  A : Byte;
Begin
  For A := 1 to Length(Str) Do Str[A] := LoCase(Str[A]);
  Lower := Str;
End;

Const
  OpMode : Byte = 0;  { 0 = not opened, 1 = add, 2 = extract }

Var
  OutFile : File;
  InFile  : File;
  ExtDIR  : String;
  CurEID  : String;

Function maOpenExtract (FN : String; EID: String; ExtractDIR : String) : Boolean;
Begin
  maOpenExtract := False;
  ExtDIR        := ExtractDIR;
  CurEID        := EID;

  Assign (InFile, FN + '.mys');
  {$I-} Reset(InFile, 1); {$I+}
  If IoResult <> 0 Then Exit;

  BlockRead (InFile, maHdr, SizeOf(maHdr));

  If (maHdr.Version <> maVersion) or (maHdr.Header <> maHeader) Then Begin
    Close (InFile);
    Exit;
  End;

  OpMode        := 2;
  maOpenExtract := True;
End;

Function maOpenCreate (FN : String; Add: Boolean) : Boolean;
Var
  BRead  : Word;
  Create : Boolean;
Begin
  maOpenCreate := False;
  Create       := True;

  Assign (OutFile, FN + '.mys');

  If Add Then Begin
    {$I-} Reset(OutFile, 1); {$I+}
    If IoResult = 0 Then Begin
      BlockRead (OutFile, maHdr, SizeOf(maHdr), BRead);

      If (maHdr.Header <> maHeader) or (maHdr.Version <> maVersion) Then Begin
        Close (OutFile);
        Exit;
      End;

      Seek (OutFile, FileSize(OutFile));

      Create := False;
    End;
  End;

  If Create Then Begin
    {$I-} ReWrite(OutFile, 1); {$I+}
    If IoResult <> 0 Then Exit;

    maHdr.Header  := maHeader;
    maHdr.Version := maVersion;
    maHdr.Files   := 0;

    BlockWrite (OutFile, maHdr, SizeOf(maHdr));
  End;

  OpMode       := 1;
  maOpenCreate := True;
End;

Function maNextFile : Boolean;
Var
  BRead : Word;
Begin
  maNextFile := False;

  Repeat
    BlockRead (InFile, maFileHdr, SizeOf(maFileHdr), BRead);

    If BRead <> SizeOf(maFileHdr) Then Exit;
    If maFileHdr.Header <> maHeader Then Exit;

    If maFileHdr.EID <> CurEID Then Begin
      {$I+} Seek (InFile, FilePos(InFile) + maFileHdr.FileSize); {$I-}
      If IoResult <> 0 Then Exit;
    End Else
      Break;
  Until False;

  maNextFile := True;
End;

Procedure maCloseFile;
Begin
  Case OpMode of
    1 : Begin
          Seek       (OutFile, 0);
          BlockWrite (OutFile, maHdr, SizeOf(maHdr));
          Close      (OutFile);
        End;
    2 : Close(InFile);
  End;

  OpMode := 0;
End;

Function maAddFile (Path, EID, FN : String) : Boolean;
Var
  F      : File;
  Buf    : Array[1..8096] of Byte;
  BRead  : Word;
  BWrite : Word;
Begin
  maAddFile := False;

  Assign (F, Path + FN);
  {$I-} Reset(F, 1); {$I+}
  If IoResult <> 0 Then Exit;

  Inc (maHdr.Files);

  maFileHdr.FileName := Lower(FN);
  maFileHdr.FileSize := FileSize(F);
  maFileHdr.EID      := EID;
  maFileHdr.Header   := maHeader;
  {$IFDEF UNIX}
    maFileHdr.Execute := fpAccess(Path + FN, X_OK) = 0;
  {$ELSE}
    maFileHdr.Execute := False;
  {$ENDIF}

  BlockWrite (OutFile, maFileHdr, SizeOf(maFileHdr));

  Repeat
    BlockRead  (F, Buf, SizeOf(Buf), BRead);
    BlockWrite (OutFile, Buf, BRead, BWrite);
  Until (BRead = 0) or (BRead <> BWrite);

  Close (F);

  maAddFile := True;
End;

Function maExtractFile : Boolean;
Var
  F        : File;
  Buf      : Array[1..8096] of Byte;
  Done     : Boolean;
  ReadSize : Word;
  BRead    : Word;
Begin
  maExtractFile := False;
  Done          := False;

  Assign (F, ExtDIR + maFileHdr.FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IoResult <> 0 Then Exit;

  Repeat
    If maFileHdr.FileSize < SizeOf(Buf) Then Begin
      ReadSize := maFileHdr.FileSize;
      Done     := True;
    End Else
      ReadSize := SizeOf(Buf);

    BlockRead  (InFile, Buf, ReadSize, BRead);

    If BRead <> ReadSize Then Begin
      Close (F);
      Exit;
    End;

    BlockWrite (F, Buf, ReadSize);

    Dec (maFileHdr.FileSize, ReadSize);
  Until Done;

  Close (F);

  {$IFDEF UNIX}
    If maFileHdr.Execute Then
      fpChMod (ExtDIR + maFileHdr.FileName, &777);
  {$ENDIF}

  maExtractFile := True;
End;

End.

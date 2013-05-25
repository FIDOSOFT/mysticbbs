Unit MKCRAP;

{$I M_OPS.PAS}

// this is various functions and procedures used by JAM/Squish...
// these should be removed and/or incorporated into mystic's code base as
// soon as possible.

// CHANGE JAM TEMP BUFFER.. ADD SETBUFFERFILE METHOD TO MSGBASE OBJECTS!!!!

Interface

Uses
  DOS;

Function  ToUnixDate    (DosDate: LongInt): LongInt;
Function  DTToUnixDate  (DT: DateTime): LongInt;
Procedure UnixToDT      (SecsPast: LongInt; Var Dt: DateTime);
Procedure Str2Az        (Str: String; MaxLen: Byte; Var AZStr); {Convert string to asciiz}
Function  LoadFilePos   (FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
Function  ExtendFile    (FN: String; ToSize: LongInt): Word;
Function  SaveFilePos   (FN: String; Var Rec; FS: Word; FPos: LongInt): Word;

Implementation

Uses
  m_FileIO,
  m_DateTime,
  m_Strings;

Const
  DATEC1970 = 2440588;
//  DATED0    =    1461;
//  DATED1    =  146097;
//  DATED2    = 1721119;

Function DTToUnixDate (DT: DateTime): LongInt;
Var
  SecsPast, DaysPast: LongInt;
Begin
  DateG2J (DT.Year, DT.Month, DT.Day, DaysPast);

  DaysPast := DaysPast - DATEc1970;
  SecsPast := DaysPast * 86400;
  SecsPast := SecsPast + (LongInt(DT.Hour) * 3600) + (DT.Min * 60) + (DT.Sec);

  DTToUnixDate := SecsPast;
End;

Function ToUnixDate (DosDate: LongInt): LongInt;
Var
  DT: DateTime;
Begin
  UnpackTime(DosDate, DT);

  ToUnixDate := DTToUnixDate(DT);
End;

Procedure UnixToDT (SecsPast: LongInt; Var DT: DateTime);
Var
  DateNum : LongInt;  //might be able to remove this
Begin
  Datenum := (SecsPast Div 86400) + DATEc1970;

  FillChar(DT, SizeOf(DT), 0);

  DateJ2G(DateNum, SmallInt(DT.Year), SmallInt(DT.Month), SmallInt(DT.Day));

  SecsPast := SecsPast Mod 86400;
  DT.Hour  := SecsPast Div 3600;
  SecsPast := SecsPast Mod 3600;
  DT.Min   := SecsPast Div 60;
  DT.Sec   := SecsPast Mod 60;
End;

Function SaveFilePos (FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
Var
  F     : File;
  Error : Word;
  Temp  : LongInt;
Begin
  Error := 0;

  Assign (F, FN);

  FileMode := fmReadWrite + fmDenyNone;

  If FileExist (FN) Then Begin
    Reset (F, 1);
    If IoResult <> 0 Then Error := IoResult;
  End Else Begin
    ReWrite (F,1);
    Error := IoResult;
  End;
  If Error = 0 Then Begin
    Seek(F, FPos);
    Error := IoResult;
  End;
  If Error = 0 Then
    If FS > 0 Then Begin
      If Not ioBlockWrite(F, Rec, FS, Temp) Then Error := ioCode;
    End;
  If Error = 0 Then Begin
    Close(F);
    Error := IoResult;
  End;
  SaveFilePos := Error;
End;

Procedure Str2Az(Str: String; MaxLen: Byte; Var AZStr); {Convert string to asciiz}
Begin
  If Length(Str) >= MaxLen Then Begin
    Str[MaxLen] := #0;
    Move(Str[1], AZStr, MaxLen);
  End Else Begin
    Str[Length(Str) + 1] := #0;
    Move(Str[1], AZStr, Length(Str) + 1);
  End;
End;

Function LoadFilePos(FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
Var
  F: File;
  Error: Word;
  NumRead: LongInt;
Begin
  Error := 0;
  If Not FileExist(FN) Then Error := 8888;
  If Error = 0 Then assign (f, fn);
  FileMode := fmReadWrite + fmDenyNone;
  reset (f, 1);
  error := ioresult;
  If Error = 0 Then Begin
    Seek(F, FPos);
    Error := IoResult;
  End;
  If Error = 0 Then
    If Not ioBlockRead(F, Rec, FS, NumRead) Then
      Error := ioCode;
  If Error = 0 Then
    Begin
    Close(F);
    Error := IoResult;
    End;
  LoadFilePos := Error;
  End;

Function ExtendFile(FN: String; ToSize: LongInt): Word;
{Pads file with nulls to specified size}
  Type
    FillType = Array[1..8000] of Byte;

  Var
    F: File;
    Error: Word;
    FillRec: ^FillType;
    temp:longint;

  Begin
  Error := 0;
  New(FillRec);
  If FillRec = Nil Then
    Error := 10;
  If Error = 0 Then
    Begin
    FillChar(FillRec^, SizeOf(FillRec^), 0);
    Assign(F, FN);
    FileMode := fmReadWrite + fmDenyNone;
    If FileExist(FN) Then Begin
      reset(f,1);
      if ioresult <> 0 then error := ioresult;
    End
    Else
      Begin
      ReWrite(F,1);
      Error := IoResult;
      End;
    End;
  If Error = 0 Then
    Begin
    Seek(F, FileSize(F));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    While ((FileSize(F) < (ToSize - SizeOf(FillRec^))) and (Error = 0)) Do
      Begin
      If Not ioBlockWrite(F, FillRec^, SizeOf(FillRec^), Temp) Then
        Error := ioCode;
      End;
    End;
  If ((Error = 0) and (FileSize(F) < ToSize)) Then Begin
    If Not ioBlockWrite(F, FillRec^, ToSize - FileSize(F), temp) Then
      Error := ioCode;
  End;
  If Error = 0 Then Begin
    Close(F);
    Error := IoResult;
  End;
  Dispose(FillRec);
  ExtendFile := Error;
  End;

End.

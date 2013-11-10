// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
Unit m_io_stdio;

{$I M_OPS.PAS}

Interface

Uses
  BaseUnix,
  m_io_Base;

Const
  STDIO_IN  = 0;
  STDIO_OUT = 1;

Type
  TSTDIO = Class(TIOBase)
    Constructor Create; Override;
    Destructor  Destroy; Override;
    Function    DataWaiting      : Boolean; Override;
    Function    WriteBuf         (Var Buf; Len: LongInt) : LongInt; Override;
    Function    ReadBuf          (Var Buf; Len: LongInt) : LongInt; Override;
    Procedure   BufWriteChar     (Ch: Char); Override;
    Procedure   BufWriteStr      (Str: String); Override;
    Procedure   BufFlush;        Override;
    Function    WriteLine        (Str: String) : LongInt; Override;
    Function    ReadLine         (Var Str: String) : LongInt; Override;
    Function    WaitForData      (TimeOut: LongInt) : LongInt; Override;
    Function    PeekChar         (Num: Byte) : Char; Override;
    Function    ReadChar         : Char; Override;
  End;

Implementation

Constructor TSTDIO.Create;
Begin
  Inherited Create;

  FInBufPos  := 0;
  FInBufEnd  := 0;
  FOutBufPos := 0;
End;

Destructor TSTDIO.Destroy;
Begin
  Inherited Destroy;
End;

Function TSTDIO.DataWaiting : Boolean;
Begin
  Result := (FInBufPos < FInBufEnd) or (WaitForData(1) > 0);
End;

Function TSTDIO.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := fpWrite(STDIO_OUT, Buf, Len);
End;

Procedure TSTDIO.BufFlush;
Begin
  If FOutBufPos > 0 Then Begin
    fpWrite (STDIO_OUT, FOutBuf, FOutBufPos);

    FOutBufPos := 0;
  End;
End;

Procedure TSTDIO.BufWriteChar (Ch: Char);
Begin
  FOutBuf[FOutBufPos] := Ch;

  Inc(FOutBufPos);

  If FOutBufPos > TIOBufferSize Then
    BufFlush;
End;

Procedure TSTDIO.BufWriteStr (Str: String);
Var
  Count : LongInt;
Begin
  For Count := 1 to Length(Str) Do
    BufWriteChar(Str[Count]);
End;

Function TSTDIO.ReadChar : Char;
Begin
  ReadBuf(Result, 1);
End;

Function TSTDIO.PeekChar (Num: Byte) : Char;
Begin
  If (FInBufPos = FInBufEnd) and DataWaiting Then
    ReadBuf(Result, 0);

  If FInBufPos + Num < FInBufEnd Then
    Result := FInBuf[FInBufPos + Num];
End;

Function TSTDIO.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  If FInBufPos = FInBufEnd Then Begin
    FInBufEnd := fpRead(STDIO_IN, @FInBuf, TIOBufferSize);
    FInBufPos := 0;

    If FInBufEnd <= 0 Then Begin
      FInBufEnd := 0;
      Result    := -1;
      Exit;
    End;
  End;

  If Len > FInBufEnd - FInBufPos Then Len := FInBufEnd - FInBufPos;

  Move (FInBuf[FInBufPos], Buf, Len);
  Inc  (FInBufPos, Len);

  Result := Len;
End;

Function TSTDIO.ReadLine (Var Str: String) : LongInt;
Var
  Ch  : Char;
  Res : LongInt;
Begin
  Str := '';
  Res := 0;

  Repeat
    If FInBufPos = FInBufEnd Then Res := ReadBuf(Ch, 0);

    Ch := FInBuf[FInBufPos];

    Inc (FInBufPos);

    If (Ch <> #10) And (Ch <> #13) And (FInBufEnd > 0) Then Str := Str + Ch;
  Until (Ch = #10) Or (Res < 0) Or (FInBufEnd = 0);

  If Res < 0 Then Result := -1 Else Result := Length(Str);
End;

Function TSTDIO.WriteLine (Str: String) : LongInt;
Begin
  Str    := Str + #13#10;
  Result := fpWrite(STDIO_OUT, Str[1], Length(Str));
End;

Function TSTDIO.WaitForData (TimeOut: LongInt) : LongInt;
Var
  FDSIN : TFDSET;
Begin
  fpFD_Zero (FDSIN);
  fpFD_Set  (STDIO_IN, FDSIN);

  Result := fpSelect (STDIO_IN + 1, @FDSIN, NIL, NIL, TimeOut);
End;

End.

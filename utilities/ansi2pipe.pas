Program Ansi2Pipe;

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

{$I M_OPS.PAS}

Uses
  m_FileIO,
  m_Strings;

Const
  Version = '1.0';

Type
  RecAnsiBufferChar = Record
                        Ch   : Char;
                        Attr : Byte;
                      End;

  RecAnsiBufferLine = Array[1..80] of RecAnsiBufferChar;
  RecAnsiBuffer     = Array[1..1000] of RecAnsiBufferLine;

  TAnsiLoader = Class
    GotAnsi  : Boolean;
    GotPipe  : Boolean;
    GotClear : Boolean;
    PipeCode : String[2];
    Owner    : Pointer;
    Data     : RecAnsiBuffer;
    Code     : String;
    Lines    : Word;
    CurY     : Word;
    Escape   : Byte;
    SavedX   : Byte;
    SavedY   : Byte;
    CurX     : Byte;
    Attr     : Byte;
    LastChar : Char;

    Procedure   SetFore (Color: Byte);
    Procedure   SetBack (Color: Byte);
    Procedure   ResetControlCode;
    Function    ParseNumber : Integer;
    Function    AddChar (Ch: Char) : Boolean;
    Procedure   MoveXY (X, Y: Word);
    Procedure   MoveUP;
    Procedure   MoveDOWN;
    Procedure   MoveLEFT;
    Procedure   MoveRIGHT;
    Procedure   MoveCursor;
    Procedure   CheckCode (Ch: Char);
    Procedure   ProcessChar (Ch: Char);

    Constructor Create;
    Destructor  Destroy; Override;

    Procedure   Clear;
    Function    ProcessBuf   (Var Buf; BufLen: Word) : Boolean;
    Function    GetLineLength (Line: Word) : Byte;
  End;

Constructor TAnsiLoader.Create;
Begin
  Inherited Create;

  Clear;
End;

Destructor TAnsiLoader.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TAnsiLoader.Clear;
Begin
  Lines    := 1;
  CurX     := 1;
  CurY     := 1;
  Attr     := 7;
  GotAnsi  := False;
  GotPipe  := False;
  GotClear := False;
  PipeCode := '';

  FillChar (Data, SizeOf(Data), #0);

  ResetControlCode;
End;

Procedure TAnsiLoader.ResetControlCode;
Begin
  Escape := 0;
  Code   := '';
End;

Procedure TAnsiLoader.SetFore (Color: Byte);
Begin
  Attr := Color + ((Attr SHR 4) AND 7) * 16;
End;

Procedure TAnsiLoader.SetBack (Color: Byte);
Begin
  Attr := (Attr AND $F) + Color * 16;
End;

Function TAnsiLoader.AddChar (Ch: Char) : Boolean;
Begin
  AddChar := False;

  Data[CurY][CurX].Ch   := Ch;
  Data[CurY][CurX].Attr := Attr;

  If CurX < 80 Then
    Inc (CurX)
  Else Begin
    If CurY = 1000 Then Begin
      AddChar := True;
      Exit;
    End Else Begin
      CurX := 1;
      Inc (CurY);
    End;
  End;
End;

Function TAnsiLoader.ParseNumber : Integer;
Var
  Res : LongInt;
  Str : String;
Begin
  Val(Code, Result, Res);

  If Res = 0 Then
    Code := ''
  Else Begin
    Str := Copy(Code, 1, Pred(Res));

    Delete (Code, 1, Res);
    Val    (Str, Result, Res);
  End;
End;

Procedure TAnsiLoader.MoveXY (X, Y: Word);
Begin
  If X > 80   Then X := 80;
  If Y > 1000 Then Y := 1000;

  CurX := X;
  CurY := Y;
End;

Procedure TAnsiLoader.MoveCursor;
Var
  X : Byte;
  Y : Byte;
Begin
  Y := ParseNumber;

  If Y = 0 Then Y := 1;

  X := ParseNumber;

  If X = 0 Then X := 1;

  MoveXY (X, Y);

  ResetControlCode;
End;

Procedure TAnsiLoader.MoveUP;
Var
  NewPos : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then Offset := 1;

  If (CurY - Offset) < 1 Then
    NewPos := 1
  Else
    NewPos := CurY - Offset;

  MoveXY (CurX, NewPos);

  ResetControlCode;
End;

Procedure TAnsiLoader.MoveDOWN;
Var
  NewPos : Byte;
Begin
  NewPos := ParseNumber;

  If NewPos = 0 Then NewPos := 1;

  MoveXY (CurX, CurY + NewPos);

  ResetControlCode;
End;

Procedure TAnsiLoader.MoveLEFT;
Var
  NewPos : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then Offset := 1;

  If CurX - Offset < 1 Then
    NewPos := 1
  Else
    NewPos := CurX - Offset;

  MoveXY (NewPos, CurY);

  ResetControlCode;
End;

Procedure TAnsiLoader.MoveRIGHT;
Var
  NewPos : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then Offset := 1;

  If CurX + Offset > 80 Then Begin
    NewPos := 80;
  End Else
    NewPos := CurX + Offset;

  MoveXY (NewPos, CurY);

  ResetControlCode;
End;

Procedure TAnsiLoader.CheckCode (Ch: Char);
Var
  Temp1 : Byte;
  Temp2 : Byte;
Begin
  Case Ch of
    '0'..
    '9',
    ';',
    '?' : Code := Code + Ch;
    'H',
    'f' : MoveCursor;
    'A' : MoveUP;
    'B' : MoveDOWN;
    'C' : MoveRIGHT;
    'D' : MoveLEFT;
    'J' : ResetControlCode;
    'K' : Begin
            Temp1 := CurX;

            For Temp2 := CurX To 80 Do
              AddChar(' ');

            MoveXY (Temp1, CurY);
            ResetControlCode;
          End;
    'h' : ResetControlCode;
    'm' : Begin
            While Length(Code) > 0 Do Begin
              Case ParseNumber of
                0 : Attr := 7;
                1 : Attr := Attr OR $08;
                5 : Attr := Attr OR $80;
                7 : Begin
                      Attr := Attr AND $F7;
                      Attr := ((Attr AND $70) SHR 4) + ((Attr AND $7) SHL 4) + Attr AND $80;
                    End;
                30: Attr := (Attr AND $F8) + 0;
                31: Attr := (Attr AND $F8) + 4;
                32: Attr := (Attr AND $F8) + 2;
                33: Attr := (Attr AND $F8) + 6;
                34: Attr := (Attr AND $F8) + 1;
                35: Attr := (Attr AND $F8) + 5;
                36: Attr := (Attr AND $F8) + 3;
                37: Attr := (Attr AND $F8) + 7;
                40: SetBack (0);
                41: SetBack (4);
                42: SetBack (2);
                43: SetBack (6);
                44: SetBack (1);
                45: SetBack (5);
                46: SetBack (3);
                47: SetBack (7);
              End;
            End;

            ResetControlCode;
          End;
    's' : Begin
            SavedX := CurX;
            SavedY := CurY;
            ResetControlCode;
          End;
    'u' : Begin
            MoveXY (SavedX, SavedY);
            ResetControlCode;
          End;
  Else
    ResetControlCode;
  End;
End;

Procedure TAnsiLoader.ProcessChar (Ch: Char);

  Procedure OneChar (C: Char);
  Begin
    Case Escape of
      0 : Begin
            Case C of
              #0  : ;
              #9  : MoveXY (CurX + 8, CurY);
              #12 : GotClear := True;
              #13 : CurX     := 1;
              #27 : Escape   := 1;
            Else
              If C = '|' Then
                GotPipe := True
              Else
                AddChar (C);

              ResetControlCode;
            End;
          End;
      1 : If C = '[' Then Begin
             Escape  := 2;
             Code    := '';
             GotAnsi := True;
           End Else
             Escape := 0;

      2 : CheckCode(C);
    Else
      ResetControlCode;
    End;

    LastChar := C;
  End;

Begin
  If GotPipe Then Begin
    PipeCode := PipeCode + Ch;

    If Length(PipeCode) = 2 Then Begin
      If PipeCode = '00' Then
        SetFore(0)
      Else
        Case strS2I(PipeCode) of
          01..
          15 : SetFore(strS2I(PipeCode));
          16..
          23 : SetBack(strS2I(PipeCode) - 16);
        Else
          AddChar('|');
          OneChar(PipeCode[1]);
          OneChar(PipeCode[2]);
      End;

      GotPipe  := False;
      PipeCode := '';
    End;

    Exit;
  End;

  OneChar (Ch);
End;

Function TAnsiLoader.ProcessBuf (Var Buf; BufLen: Word) : Boolean;
Var
  Count  : Word;
  Buffer : Array[1..4096] of Char Absolute Buf;
Begin
  Result := False;

  For Count := 1 to BufLen Do Begin
    If CurY > Lines Then Lines := CurY;

    Case Buffer[Count] of
      #10 : If CurY = 1000 Then Begin
              Result  := True;
              GotAnsi := False;

              Break;
            End Else Begin
              Inc (CurY);

              If LastChar <> #13 Then CurX := 1;
            End;
      #26 : Begin
              Result := True;
              Break;
            End;
    Else
      ProcessChar(Buffer[Count]);
    End;
  End;
End;

Function TAnsiLoader.GetLineLength (Line: Word) : Byte;
Begin
  Result := 79;

  While (Result > 0) and (Data[Line][Result].Ch = #0) Do
    Dec (Result);
End;

Const
  CRLF = #13#10;
Var
  Ansi    : TAnsiLoader;
  InFile  : File;
  Buf     : Array[1..4096] of Char;
  BufLen  : LongInt;
  OutFile : Text;
  CountY  : LongInt;
  CountX  : Byte;
  CurAttr : Byte;
  CurFG   : Byte;
  NewFG   : Byte;
  CurBG   : Byte;
  NewBG   : Byte;
Begin
  WriteLn;
  WriteLn ('ANSI2PIPE v', Version, ' : Convert ANSI files to Pipe color files');
  WriteLn;

  If ParamCount <> 2 Then Begin
    WriteLn ('Usage: ansi2pipe [Input ANSI file] [Output Pipe file]');
    Halt;
  End;

  Ansi := TAnsiLoader.Create;

  Assign (InFile, ParamStr(1));

  If Not ioReset (InFile, 1, fmReadWrite + fmDenyNone) Then Begin
    WriteLn ('Unable to open input file');
    Ansi.Free;
    Halt;
  End;

  Write ('Converting ... ');

  While Not Eof(InFile) Do Begin
    ioBlockRead (InFile, Buf, SizeOf(Buf), BufLen);
    If Ansi.ProcessBuf (Buf, BufLen) Then Break;
  End;

  Close (InFile);

  Assign  (OutFile, ParamStr(2));
  ReWrite (OutFile);

  CurAttr := 7;

  Write (OutFile, '|07|16|CL');

  For CountY := 1 to Ansi.Lines Do Begin
    For CountX := 1 to Ansi.GetLineLength(CountY) Do Begin
      CurBG := (CurAttr SHR 4) AND 7;
      CurFG := CurAttr AND $F;
      NewBG := (Ansi.Data[CountY][CountX].Attr SHR 4) AND 7;
      NewFG := Ansi.Data[CountY][CountX].Attr AND $F;

      If CurFG <> NewFG Then Write (OutFile, '|' + strZero(NewFG));
      If CurBG <> NewBG Then Write (OutFile, '|' + strZero(16 + NewBG));

      If Ansi.Data[CountY][CountX].Ch in [#0, #255] Then
        Ansi.Data[CountY][CountX].Ch := ' ';

      Write (OutFile, Ansi.Data[CountY][CountX].Ch);

      CurAttr := Ansi.Data[CountY][CountX].Attr;
    End;

    Write (OutFile, CRLF);
  End;

  Close (OutFile);

  WriteLn ('Complete');
End.

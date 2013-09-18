Unit BBS_MsgBase_Ansi;

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  BBS_Records;

Type
  RecAnsiBufferChar = Record
                        Ch   : Char;
                        Attr : Byte;
                      End;

  RecAnsiBufferLine = Array[1..80] of RecAnsiBufferChar;
  RecAnsiBuffer     = Array[1..mysMaxMsgLines] of RecAnsiBufferLine;

  TMsgBaseAnsi = Class
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

    Constructor Create (O: Pointer; Msg: Boolean);
    Destructor  Destroy; Override;

    Procedure   Clear;
    Function    ProcessBuf   (Var Buf; BufLen: Word) : Boolean;
    Procedure   WriteLine    (Line: Word; Flush: Boolean);
    Procedure   DrawLine     (Y, Line: Word; Flush: Boolean);
    Procedure   DrawPage     (pStart, pEnd, pLine: Word);
    Procedure   SetLineColor (NewAttr, Line: Word);
    Procedure   RemoveLine   (Line: Word);
  End;

Implementation

Uses
  BBS_Core;

Constructor TMsgBaseAnsi.Create (O: Pointer; Msg: Boolean);
Begin
  Inherited Create;

  Owner := O;

  Clear;
End;

Destructor TMsgBaseAnsi.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TMsgBaseAnsi.Clear;
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

Procedure TMsgBaseAnsi.ResetControlCode;
Begin
  Escape := 0;
  Code   := '';
End;

Procedure TMsgBaseAnsi.SetFore (Color: Byte);
Begin
  Attr := Color + ((Attr SHR 4) AND 7) * 16;
End;

Procedure TMsgBaseAnsi.SetBack (Color: Byte);
Begin
  Attr := (Attr AND $F) + Color * 16;
End;

Function TMsgBaseAnsi.AddChar (Ch: Char) : Boolean;
Begin
  AddChar := False;

  Data[CurY][CurX].Ch   := Ch;
  Data[CurY][CurX].Attr := Attr;

  If CurX < 80 Then
    Inc (CurX)
  Else Begin
    If CurY = mysMaxMsgLines Then Begin
      AddChar := True;
      Exit;
    End Else Begin
      CurX := 1;
      Inc (CurY);
    End;
  End;
End;

Function TMsgBaseAnsi.ParseNumber : Integer;
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

Procedure TMsgBaseAnsi.MoveXY (X, Y: Word);
Begin
  If X > 80             Then X := 80;
  If Y > mysMaxMsgLines Then Y := mysMaxMsgLines;

  CurX := X;
  CurY := Y;
End;

Procedure TMsgBaseAnsi.MoveCursor;
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

Procedure TMsgBaseAnsi.MoveUP;
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

Procedure TMsgBaseAnsi.MoveDOWN;
Var
  NewPos : Byte;
Begin
  NewPos := ParseNumber;

  If NewPos = 0 Then NewPos := 1;

  MoveXY (CurX, CurY + NewPos);

  ResetControlCode;
End;

Procedure TMsgBaseAnsi.MoveLEFT;
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

Procedure TMsgBaseAnsi.MoveRIGHT;
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

Procedure TMsgBaseAnsi.CheckCode (Ch: Char);
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

(*
Procedure TMsgBaseAnsi.ProcessChar (Ch: Char);
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
          AddChar(PipeCode[1]);
          AddChar(PipeCode[2]);
      End;

      GotPipe  := False;
      PipeCode := '';
    End;

    Exit;
  End;

  Case Escape of
    0 : Begin
          Case Ch of
            #0  : ;
            #9  : MoveXY (CurX + 8, CurY);
            #12 : GotClear := True;
            #13 : CurX     := 1;
            #27 : Escape   := 1;
          Else
            If Ch = '|' Then
              GotPipe := True
            Else
              AddChar (Ch);

            ResetControlCode;
          End;
        End;
    1 : If Ch = '[' Then Begin
           Escape  := 2;
           Code    := '';
           GotAnsi := True;
         End Else
           Escape := 0;

    2 : CheckCode(Ch);
  Else
    ResetControlCode;
  End;

  LastChar := Ch;
End;
*)

Procedure TMsgBaseAnsi.ProcessChar (Ch: Char);

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
      If (PipeCode[1] in ['0'..'2']) and (PipeCode[2] in ['0'..'9']) Then Begin
        If PipeCode = '00' Then
          SetFore(0)
        Else Begin
          Case strS2I(PipeCode) of
            01..
            15 : SetFore(strS2I(PipeCode));
            16..
            23 : SetBack(strS2I(PipeCode) - 16);
          Else
            AddChar ('|');
            OneChar (PipeCode[1]);
            OneChar (PipeCode[2]);
          End;
        End;
      End Else Begin
        AddChar ('|');
        OneChar (PipeCode[1]);
        OneChar (PipeCode[2]);
      End;

      GotPipe  := False;
      PipeCode := '';
    End;

    Exit;
  End;

  OneChar (Ch);
End;

Function TMsgBaseAnsi.ProcessBuf (Var Buf; BufLen: Word) : Boolean;
Var
  Count  : Word;
  Buffer : Array[1..4096] of Char Absolute Buf;
Begin
  Result := False;

  For Count := 1 to BufLen Do Begin
    If CurY > Lines Then Lines := CurY;

    Case Buffer[Count] of
      #10 : If CurY = mysMaxMsgLines Then Begin
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

Procedure TMsgBaseAnsi.WriteLine (Line: Word; Flush: Boolean);
Var
  Count : Byte;
Begin
  If Line > Lines Then Exit;

  For Count := 1 to 79 Do Begin
    Session.io.BufAddStr (Session.io.Attr2Ansi(Data[Line][Count].Attr));

    If Data[Line][Count].Ch in [#0, #255] Then
      Session.io.BufAddStr(' ')
    Else
      Session.io.BufAddStr (Data[Line][Count].Ch);
  End;

  Session.io.BufAddStr(#13#10);

  If Flush Then Session.io.BufFlush;

  Inc (Session.io.PausePtr);
End;

Procedure TMsgBaseAnsi.DrawLine (Y, Line: Word; Flush: Boolean);
Var
  Count : Byte;
Begin
  Session.io.AnsiGotoXY(1, Y);

  If Line > Lines Then Begin
   Session.io.BufAddStr(Session.io.Attr2Ansi(Session.io.ScreenInfo[1].A));
   Session.io.AnsiClrEOL;
  End Else
    For Count := 1 to 80 Do Begin
      Session.io.BufAddStr (Session.io.Attr2Ansi(Data[Line][Count].Attr));
      If Data[Line][Count].Ch in [#0, #255] Then
        Session.io.BufAddStr(' ')
      Else
        Session.io.BufAddStr (Data[Line][Count].Ch);
    End;

  If Flush Then Session.io.BufFlush;
End;

Procedure TMsgBaseAnsi.DrawPage (pStart, pEnd, pLine: Word);
Var
  Count : Word;
Begin
  For Count := pStart to pEnd Do Begin
    DrawLine (Count, pLine, False);
    Inc      (pLine);
  End;

  Session.io.BufFlush;
End;

Procedure TMsgBaseAnsi.SetLineColor (NewAttr, Line: Word);
Var
  Count : Word;
Begin
  For Count := 1 to 80 Do
    Data[Line][Count].Attr := NewAttr;
End;

Procedure TMsgBaseAnsi.RemoveLine (Line: Word);
Var
  Count : Word;
Begin
  For Count := Line to Lines - 1 Do
    Data[Count] := Data[Count + 1];

  Dec (Lines);
End;

End.

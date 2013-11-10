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

Unit m_Output_Darwin;

Interface

Uses
  TermIO,
  BaseUnix,
  m_Types;

Const
  ConIn      = 0;
  ConOut     = 1;
  ConBufSize = 4096;

Type
  TOutputDarwin = Class
  Private
    TermInfo   : TermIos;
    TermInRaw  : Boolean;
    TermOutRaw : Boolean;
    OutBuffer  : Array[1..ConBufSize] of Char;
    FTextAttr  : Byte;
    FWinTop    : Byte;
    FCursorX   : Byte;
    FCursorY   : Byte;

    Procedure   SetTextAttr (Attr: Byte);
  Public
    OutBufPos  : Word;
    ScreenSize : Byte;
    Buffer     : TConsoleScreenRec;
    Active     : Boolean;
    SavedTerm  : TermIOS;
    FWinBot    : Byte;

    Function    AttrToAnsi (Attr: Byte) : String;
    Procedure   BufFlush;
    Procedure   BufAddStr (Str: String);
    Procedure   SaveRawSettings (Var TIo: TermIos);
    Procedure   RestoreRawSettings (TIo: TermIos);
    Procedure   SetRawMode (SetOn: Boolean);
    Procedure   WriteXY (X, Y, A: Byte; Text: String);
    Procedure   WriteXYPipe (X, Y, Attr, Pad: Integer; Text: String);
    Procedure   GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
    Procedure   PutScreenImage (Image: TConsoleImageRec);
    Procedure   LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);

    Constructor Create (A: Boolean);
    Destructor  Destroy; Override;
    Procedure   ClearScreen; Virtual;
    Procedure   ScrollWindow; Virtual;
    Procedure   ClearEOL;
    Procedure   CursorXYRaw (X, Y: Byte);
    Procedure   CursorXY (X, Y: Byte);
    Procedure   SetWindow (X1, Y1, X2, Y2: Byte; Home: Boolean);
    Procedure   SetScreenSize (Mode: Byte);
    Procedure   SetWindowTitle (Str: String);
    Procedure   WriteChar (Ch: Char);
    Procedure   WriteLine (Str: String);
    Procedure   WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
    Procedure   WriteStr (Str: String);
    Procedure   RawWriteStr (Str: String);
    Function    ReadCharXY (X, Y: Byte) : Char;
    Function    ReadAttrXY (X, Y: Byte) : Byte;
    Procedure   ShowBuffer;

    Property TextAttr : Byte Read FTextAttr Write SetTextAttr;
    Property CursorX  : Byte Read FCursorX;
    Property CursorY  : Byte Read FCursorY;
  End;

Implementation

Uses
  m_Strings;

Procedure TOutputDarwin.WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
Var
  Count : LongInt;
Begin
  CursorXY(1, YPos);

  For Count := 1 to 80 Do
    BufAddStr(AttrToAnsi(Line[Count].Attributes) + Line[Count].UnicodeChar);

  BufFlush;

//  For Count := 1 to 80 Do Begin
//    FTextAttr := Line[Count].Attributes;
//    WriteChar(Line[Count].UnicodeChar);
//  End;

  Buffer[YPos] := Line;
End;

Constructor TOutputDarwin.Create (A: Boolean);
Begin
  Inherited Create;

//  SaveRawSettings(SavedTerm);

  SetRawMode(True);

  Active     := A;
  OutBufPos  := 0;
  FTextAttr  := 7;
  FWinTop    := 1;
  FWinBot    := 25;
  ScreenSize := 25;

  RawWriteStr (#27 + '(U' + #27 + '[0m');

  ClearScreen;
End;

Destructor TOutputDarwin.Destroy;
Begin
  WriteLine('');

  BufFlush;

//  RestoreRawSettings(SavedTerm);
  SetRawMode(False);

  Inherited Destroy;
End;

Const
  AnsiTable : String[8] = '04261537';

Function TOutputDarwin.AttrToAnsi (Attr: Byte) : String;
Var
  Str   : String[16];
  OldFG : LongInt;
  OldBG : LongInt;
  FG    : LongInt;
  BG    : LongInt;

  Procedure AddSep (Ch: Char);
  Begin
    If Length(Str) > 0 Then
      Str := Str + ';';
    Str := Str + Ch;
  End;

Begin
  If Attr = FTextAttr Then Begin
    AttrToAnsi := '';
    Exit;
  End;

  Str   := '';
  FG    := Attr and $F;
  BG    := Attr shr 4;
  OldFG := FTextAttr and $F;
  OldBG := FTextAttr shr 4;

  If (OldFG <> 7) or (FG = 7) or ((OldFG > 7) and (FG < 8)) or ((OldBG > 7) and (BG < 8)) Then Begin
    Str   := '0';
    OldFG := 7;
    OldBG := 0;
  End;

  If (FG > 7) and (OldFG < 8) Then Begin
    AddSep('1');
    OldFG := OldFG or 8;
  End;

  If (BG and 8) <> (OldBG and 8) Then Begin
    AddSep('5');
    OldBG := OldBG or 8;
  End;

  If (FG <> OldFG) Then Begin
    AddSep('3');
    Str := Str + AnsiTable[(FG and 7) + 1];
  End;

  If (BG <> OldBG) Then Begin
    AddSep('4');
    Str := Str + AnsiTable[(BG and 7) + 1];
  End;

  FTextAttr  := FG + BG * 16;
  AttrToAnsi := #27 + '[' + Str + 'm';
End;

Procedure TOutputDarwin.BufFlush;
Begin
  If OutBufPos > 0 Then Begin
    If Active Then fpWrite (ConOut, OutBuffer[1], OutBufPos);
    OutBufPos := 0;
  End;
End;

Procedure TOutputDarwin.BufAddStr (Str: String);
Var
  Count : LongInt;
Begin
  For Count := 1 to Length(Str) Do Begin
    Inc (OutBufPos);
    OutBuffer[OutBufPos] := Str[Count];
    If OutBufPos = ConBufSize Then BufFlush;
  End;
End;

Procedure TOutputDarwin.SetTextAttr (Attr: Byte);
Begin
  If Attr = FTextAttr Then Exit;

  BufAddStr(AttrToAnsi(Attr));

  FTextAttr := Attr;
End;

Procedure TOutputDarwin.CursorXYRaw (X, Y: Byte);
Begin
  If (Y < 1)  Then Y := 1 Else
  If (Y > ScreenSize) Then Y := ScreenSize;
  If (X < 1)  Then X := 1 Else
  If (X > 80) Then X := 80;

  BufAddStr(#27 + '[' + strI2S(Y) + ';' + strI2S(X) + 'H');
  BufFlush;

  FCursorX := X;
  FCursorY := Y;
End;

Procedure TOutputDarwin.CursorXY (X, Y: Byte);
Begin
  If (Y < 1)  Then Y := 1 Else
  If (Y > FWinBot) Then Y := FWinBot; {changed 109a4}
  If (X < 1)  Then X := 1 Else
  If (X > 80) Then X := 80;

  BufAddStr(#27 + '[' + strI2S(Y) + ';' + strI2S(X) + 'H');
  BufFlush;

  FCursorX := X;
  FCursorY := Y;
End;

Procedure TOutputDarwin.ClearScreen;
Var
  Fill  : TCharInfo;
  Count : Byte;
Begin
  BufFlush;

  Fill.Attributes  := FTextAttr;
  Fill.UnicodeChar := ' ';

  If (FWinTop = 1) and (FWinBot = {25}ScreenSize) Then Begin
    BufAddStr(#27 + '[2J');
    FillWord (Buffer, SizeOf(Buffer) DIV 2, Word(Fill));
  End Else Begin
    For Count := FWinTop to FWinBot Do Begin
      BufAddStr (#27 + '[' + strI2S(Count) + ';1H' + #27 + '[K');
      FillWord (Buffer[Count][1], SizeOf(TConsoleLineRec) DIV 2, Word(Fill));
    End;
  End;

  CursorXY (1, FWinTop);
End;

Procedure TOutputDarwin.SetScreenSize (Mode: Byte);
Begin
  FWinBot    := Mode;
  ScreenSize := Mode;

  BufFlush;
  RawWriteStr(#27 + '[8;' + strI2S(Mode) + ';80t');
  SetWindow(1, 1, 80, Mode, False);
//need to figure this out.

//esc[8;h;w
End;

Procedure TOutputDarwin.SetWindow (X1, Y1, X2, Y2: Byte; Home: Boolean);
Begin
  // X1 and X2 are ignored in Darwin and are only here for compatibility
  // reasons.

  FWinTop := Y1;
  FWinBot := Y2;

  BufAddStr (#27 + '[' + strI2S(Y1) + ';' + strI2S(Y2) + 'r');
  BufFlush;

  If Home Then CursorXY (1, Y1);

  If (FCursorY > Y2) Then CursorXY (CursorX, Y2);

//  If Home or (FCursorY < Y1) or (FCursorY > Y2) Then CursorXY(1, Y1);
  { this home thing is shady.  compare it to win.  going from 50 to 25 }
  { will screw up the buffers - this has to be more elegant. }
End;

Procedure TOutputDarwin.SetWindowTitle (Str: String);
Begin
  RawWriteStr (#27 + ']0;' + Str + #07);
End;

Procedure TOutputDarwin.ClearEOL;
Var
  Fill  : TCharInfo;
Begin
  BufAddStr(#27 + '[K');

  Fill.Attributes := FTextAttr;
  Fill.UnicodeChar := ' ';

  FillWord (Buffer[CursorY][CursorX], (80 - CursorX) * 2, Word(Fill));
End;

Procedure TOutputDarwin.ScrollWindow;
Begin
  Move (Buffer[2][1], Buffer[1][1], SizeOf(TConsoleLineRec) * (FWinBot - 1));
  FillChar(Buffer[FWinBot][1], SizeOf(TConsoleLineRec), 0);
End;

Procedure TOutputDarwin.WriteChar (Ch: Char);
Var
  A : Byte;
Begin
  If Ch <> #10 Then BufAddStr(Ch);

  Case Ch of
    #08 : If FCursorX > 1 Then
            Dec(FCursorX);
    #10 : Begin
            If FCursorY < FWinBot Then Begin
              BufAddStr(Ch);
              Inc (FCursorY)
            End Else Begin
              A := FTextAttr;
              SetTextAttr(7);
              BufAddStr(Ch);
              ScrollWindow;
              SetTextAttr(A);
            End;

            FCursorX := 1;
            CursorXY(FCursorX, FCursorY);

            BufFlush;
          End;
    #13 : FCursorX := 1;
  Else
   Buffer[FCursorY][FCursorX].Attributes  := FTextAttr;
   Buffer[FCursorY][FCursorX].UnicodeChar := Ch;

    If FCursorX < 80 Then
      Inc (FCursorX)
    Else Begin
      FCursorX := 1;

      If FCursorY < FWinBot Then
        Inc (FCursorY)
      Else Begin
        ScrollWindow;
        BufFlush;
      End;
    End;
  End;
End;

Procedure TOutputDarwin.WriteStr (Str: String);
Var
  Count : Byte;
Begin
  For Count := 1 to Length(Str) Do
    WriteChar(Str[Count]);

  BufFlush;
End;

Procedure TOutputDarwin.WriteLine (Str: String);
Var
  Count : Byte;
Begin
  Str := Str + #13#10;

  For Count := 1 To Length(Str) Do
    WriteChar(Str[Count]);

  BufFlush;
End;

Procedure TOutputDarwin.RawWriteStr (Str: String);
Begin
  fpWrite (ConOut, Str[1], Length(Str));
End;

Procedure TOutputDarwin.SaveRawSettings (Var TIo: TermIos);
Begin
  With TIo Do Begin
    TermInRaw :=
      ((c_iflag and (IGNBRK or BRKINT or PARMRK or ISTRIP or
                               INLCR or IGNCR or ICRNL or IXON)) = 0) and
      ((c_lflag and (ECHO or ECHONL or ICANON or ISIG or IEXTEN)) = 0);
    TermOutRaw :=
      ((c_oflag and OPOST) = 0) and
      ((c_cflag and (CSIZE or PARENB)) = 0) and
      ((c_cflag and CS8) <> 0);
  End;
End;

Procedure TOutputDarwin.RestoreRawSettings (TIo: TermIos);
Begin
  With TIo Do Begin
    If TermInRaw Then Begin
      c_iflag := c_iflag and (not (IGNBRK or BRKINT or PARMRK or ISTRIP or
                 INLCR or IGNCR or ICRNL or IXON));
      c_lflag := c_lflag and
                 (not (ECHO or ECHONL or ICANON or ISIG or IEXTEN));
    End;

    If TermOutRaw Then Begin
      c_oflag := c_oflag and not(OPOST);
      c_cflag := c_cflag and not(CSIZE or PARENB) or CS8;
    End;
  End;
End;

Procedure TOutputDarwin.SetRawMode (SetOn: Boolean);
Var
  Tio : TermIos;
Begin
  If SetOn Then Begin
    TCGetAttr(1, Tio);
    SaveRawSettings(Tio);
    TermInfo := Tio;
    CFMakeRaw(Tio);
  End Else Begin
    RestoreRawSettings(TermInfo);
    Tio := TermInfo;
  End;

  TCSetAttr(1, TCSANOW, Tio);
End;

Function TOutputDarwin.ReadCharXY (X, Y: Byte) : Char;
Begin
  ReadCharXY := Buffer[Y][X].UnicodeChar;
End;

Function TOutputDarwin.ReadAttrXY (X, Y: Byte) : Byte;
Begin
  ReadAttrXY := Buffer[Y][X].Attributes;
End;

Procedure TOutputDarwin.WriteXY (X, Y, A: Byte; Text: String);
Var
  OldAttr : Byte;
  OldX    : Byte;
  OldY    : Byte;
  Count   : Byte;
Begin
  If X > 80 Then Exit;

  OldAttr := FTextAttr;
  OldX    := FCursorX;
  OldY    := FCursorY;

  CursorXYRaw (X, Y);
  SetTextAttr (A);

  For Count := 1 to Length(Text) Do
    If FCursorX <= 80 Then Begin
      Buffer[FCursorY][FCursorX].Attributes  := FTextAttr;
      Buffer[FCursorY][FCursorX].UnicodeChar := Text[Count];

      Inc (FCursorX);

      BufAddStr(Text[Count]);
    End Else
      Break;

  SetTextAttr (OldAttr);
  CursorXYRaw (OldX, OldY);

  BufFlush;
End;

Procedure TOutputDarwin.WriteXYPipe (X, Y, Attr, Pad: Integer; Text: String);

  Procedure AddChar (Ch: Char);
  Begin
    If CursorX > 80 Then Exit;

    Buffer[CursorY][CursorX].Attributes  := FTextAttr;
    Buffer[CursorY][CursorX].UnicodeChar := Ch;

    BufAddStr(Ch);

    Inc (FCursorX);
  End;

Var
  Count   : Byte;
  Code    : String[2];
  CodeNum : Byte;
  OldAttr : Byte;
  OldX    : Byte;
  OldY    : Byte;
Begin
  OldAttr := FTextAttr;
  OldX    := FCursorX;
  OldY    := FCursorY;

  CursorXYRaw (X, Y);
  SetTextAttr (Attr);

  Count := 1;

  While Count <= Length(Text) Do Begin
    If Text[Count] = '|' Then Begin
      Code    := Copy(Text, Count + 1, 2);
      CodeNum := strS2I(Code);

      If (Code = '00') or ((CodeNum > 0) and (CodeNum < 24) and (Code[1] <> '&') and (Code[1] <> '$')) Then Begin
        Inc (Count, 2);
        If CodeNum in [00..15] Then
          SetTextAttr (CodeNum + ((FTextAttr SHR 4) AND 7) * 16)
        Else
          SetTextAttr ((FTextAttr AND $F) + (CodeNum - 16) * 16);
      End Else Begin
        AddChar(Text[Count]);
        Dec (Pad);
      End;
    End Else Begin
      AddChar(Text[Count]);
      Dec (Pad);
    End;

    If Pad = 0 Then Break;

    Inc (Count);
  End;

  While Pad > 0 Do Begin
    AddChar(' ');
    Dec(Pad);
  End;

  SetTextAttr (OldAttr);
  CursorXYRaw (OldX, OldY);

  BufFlush;
End;

Procedure TOutputDarwin.GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
Var
  Count : Byte;
Begin
//  If X2 > 80 Then X2 := 80;
//  If Y2 > FWinBot Then Y2 := FWinBot;

  FillChar(Image, SizeOf(Image), #0);

  Image.Data := Buffer;
//  For Count := Y1 to Y2 Do Begin
//    Image.Data[Count] := Buffer[Count];

  Image.CursorX := FCursorX;
  Image.CursorY := FCursorY;
  Image.CursorA := FTextAttr;
  Image.X1      := X1;
  Image.X2      := X2;
  Image.Y1      := Y1;
  Image.Y2      := Y2;
End;

Procedure TOutputDarwin.PutScreenImage (Image: TConsoleImageRec);
Var
  CountX : Byte;
  CountY : Byte;
  OT, OB : Byte;
Begin
  OT := FWinTop;
  OB := FWinBot;

  SetWindow (1, 1, 80, ScreenSize, False);

  For CountY := Image.Y1 to Image.Y2 Do Begin
    CursorXY (Image.X1, CountY);

//    Move (Image.Data[CountY][Image.X1], Buffer[CountY + Image.Y1 - 1][Image.X1], (Image.X2 - Image.X1 + 1) * SizeOf(TCharInfo));

    For CountX := Image.X1 to Image.X2 Do Begin
      SetTextAttr(Image.Data[CountY][CountX].Attributes);
      If Image.Data[CountY][CountX].UnicodeChar = #0 Then BufAddStr(' ') Else BufAddStr(Image.Data[CountY][CountX].UnicodeChar);
      Buffer[CountY][CountX] := Image.Data[CountY][CountX];
    End;
  End;

  SetTextAttr (Image.CursorA);
  CursorXY    (Image.CursorX, Image.CursorY);
  SetWindow   (1, OT, 80, OB, False);

  BufFlush;
End;

(*
Procedure TOutputDarwin.GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
Var
  Count : Byte;
  Line  : Byte;
  Temp  : TConsoleLineRec;
Begin
  Line := 1;

  If X2 > 80 Then X2 := 80;
  If Y2 > FWinBot Then Y2 := FWinBot;

  FillChar(Image, SizeOf(Image), #0);

  For Count := Y1 to Y2 Do Begin
    Move (Buffer[Count][X1], Image.Data[Line][1], (X2 - X1 + 1) * SizeOf(TCharInfo));
    Inc (Line);
  End;

  Image.CursorX := FCursorX;
  Image.CursorY := FCursorY;
  Image.CursorA := FTextAttr;
  Image.X1      := X1;
  Image.X2      := X2;
  Image.Y1      := Y1;
  Image.Y2      := Y2;
End;

Procedure TOutputDarwin.PutScreenImage (Var Image: TConsoleImageRec);
Var
  CountX : Byte;
  CountY : Byte;
Begin
  For CountY := 1 to (Image.Y2 - Image.Y1 + 1) Do Begin
    CursorXY (Image.X1, CountY + Image.Y1 - 1);

    Move (Image.Data[CountY][1], Buffer[CountY + Image.Y1 - 1][Image.X1], (Image.X2 - Image.X1 + 1) * SizeOf(TCharInfo));

    For CountX := 1 to (Image.X2 - Image.X1 + 1) Do Begin
      SetTextAttr(Image.Data[CountY][CountX].Attributes);
      BufAddStr(Image.Data[CountY][CountX].UnicodeChar);
    End;
  End;

  SetTextAttr (Image.CursorA);
  CursorXY (Image.CursorX, Image.CursorY);

  BufFlush;
End;
*)

Procedure TOutputDarwin.LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);
Var
  Image    : TConsoleImageRec;
  Data     : Array[1..8000] of Byte Absolute DataPtr;
  PosX     : Word;
  PosY     : Byte;
  Attrib   : Byte;
  Count    : Word;
  A        : Byte;
  B        : Byte;
  C        : Byte;
Begin
  PosX     := 1;
  PosY     := 1;
  Attrib   := 7;
  Count    := 1;

  FillChar(Image.Data, SizeOf(Image.Data), #0);

  While (Count <= Len) Do begin
    Case Data[Count] of
      00..
      15  : Attrib := Data[Count] + ((Attrib SHR 4) and 7) * 16;
      16..
      23  : Attrib := (Attrib And $F) + (Data[Count] - 16) * 16;
      24  : Begin
              Inc (PosY);
              PosX := 1;
            End;
      25  : Begin
              Inc (Count);

              For A := 0 to Data[Count] Do Begin
                Image.Data[PosY][PosX].UnicodeChar := ' ';
                Image.Data[PosY][PosX].Attributes  := Attrib;

                Inc (PosX);
              End;
            End;
      26  : Begin
              A := Data[Count + 1];
              B := Data[Count + 2];

              Inc (Count, 2);

              For C := 0 to A Do Begin
                Image.Data[PosY][PosX].UnicodeChar := Char(B);
                Image.Data[PosY][PosX].Attributes  := Attrib;

                Inc (PosX);
              End;
            End;
      27..
      31  : ;
    Else
      Image.Data[PosY][PosX].UnicodeChar := Char(Data[Count]);
      Image.Data[PosY][PosX].Attributes  := Attrib;

      Inc (PosX);
    End;

    Inc(Count);
  End;

  If PosY > ScreenSize Then PosY := ScreenSize;

  Image.CursorX := PosX;
  Image.CursorY := PosY;
  Image.CursorA := Attrib;
  Image.X1      := X;
  Image.X2      := Width;
  Image.Y1      := Y;
  Image.Y2      := PosY;

  PutScreenImage(Image);
End;

Procedure TOutputDarwin.ShowBuffer;
Begin
End;

End.

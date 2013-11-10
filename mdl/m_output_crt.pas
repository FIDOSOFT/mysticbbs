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
Unit m_Output_CRT;

{$I M_OPS.PAS}

// This is a generic implementation of the Output class which relies on the
// FPC CRT unit.  This is not really suitable to use but it can sometimes
// be useful when beginning to port an MDL application to a new operating
// system.  The CRT based I/O implementions not only rely on a usable CRT
// implementation for that platform, but also are very inefficient.  They
// should NOT be used.

Interface

Uses
  m_Types;

Type
  TCharInfo = Record
    Attributes  : Byte;
    UnicodeChar : Char;
  End;

  TOutputCRT = Class
  Private
    FTextAttr  : Byte;
    FWinTop    : Byte;
    FCursorX   : Byte;
    FCursorY   : Byte;

    Procedure   SetTextAttr (Attr: Byte);
  Public
    ScreenSize : Byte;
    Buffer     : TConsoleScreenRec;
    Active     : Boolean;
    FWinBot    : Byte;

    Procedure   BufFlush;
    Procedure   BufAddStr (Str: String);
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
    Procedure   CursorXY (X, Y: Byte);
    Procedure   SetWindow (X1, Y1, X2, Y2: Byte; Home: Boolean);
    Procedure   SetScreenSize (Mode: Byte);
    Procedure   SetWindowTitle (Str: String);
    Procedure   WriteChar (Ch: Char);
    Procedure   WriteLine (Str: String);
    Procedure   WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
    Procedure   WriteStr (Str: String);
    Function    ReadCharXY (X, Y: Byte) : Char;
    Function    ReadAttrXY (X, Y: Byte) : Byte;
    Procedure   ShowBuffer;

    Property TextAttr : Byte Read FTextAttr Write SetTextAttr;
    Property CursorX  : Byte Read FCursorX;
    Property CursorY  : Byte Read FCursorY;
  End;

Implementation

Uses
  CRT,
  m_Strings;

Procedure TOutputCRT.WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
Var
  Count : LongInt;
Begin
  CursorXY (1, YPos);

  For Count := 1 to 80 Do Begin
    SetTextAttr (Line[Count].Attributes);
    WriteChar   (Line[Count].UnicodeChar);
  End;

  Buffer[YPos] := Line;
End;

Constructor TOutputCRT.Create (A: Boolean);
Begin
  Inherited Create;

  Active     := A;
  FTextAttr  := 7;
  FWinTop    := 1;
  FWinBot    := 25;
  ScreenSize := 25;

  SetWindow (1, 1, 80, 25, False);

  ClearScreen;
End;

Destructor TOutputCRT.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TOutputCRT.BufFlush;
Begin
End;

Procedure TOutputCRT.BufAddStr (Str: String);
Begin
  If Active Then Write(Str);
End;

Procedure TOutputCRT.SetTextAttr (Attr: Byte);
Begin
  CRT.TextAttr := Attr;
  FTextAttr    := Attr;
End;

Procedure TOutputCRT.CursorXY (X, Y: Byte);
Begin
  If (Y < 1)  Then Y := 1 Else
//  If (Y > FWinBot) Then Y := FWinBot; {changed 109a4}
  If (Y > ScreenSize) Then Y := ScreenSize;
  If (X < 1)  Then X := 1 Else
  If (X > 80) Then X := 80;

  If Active Then CRT.GotoXY(X, Y);

  FCursorX := X;
  FCursorY := Y;
End;

Procedure TOutputCRT.ClearScreen;
Var
  Fill  : TCharInfo;
  Count : Byte;
Begin
  Fill.Attributes  := FTextAttr;
  Fill.UnicodeChar := ' ';

  If (FWinTop = 1) and (FWinBot = ScreenSize) Then Begin
    If Active Then CRT.ClrScr;

    FillWord (Buffer, SizeOf(Buffer) DIV 2, Word(Fill));
  End Else Begin
    For Count := FWinTop to FWinBot Do Begin
      If Active Then Begin
        CRT.GotoXY (1, Count);
        CRT.ClrEOL;
      End;

      FillWord (Buffer[Count][1], SizeOf(TConsoleLineRec) DIV 2, Word(Fill));
    End;
  End;

  CursorXY (1, FWinTop);
End;

Procedure TOutputCRT.SetScreenSize (Mode: Byte);
Begin
  FWinBot    := Mode;
  ScreenSize := Mode;

  SetWindow(1, 1, 80, Mode, False);
End;

Procedure TOutputCRT.SetWindow (X1, Y1, X2, Y2: Byte; Home: Boolean);
Begin
  FWinTop := Y1;
  FWinBot := Y2;

  If Active Then CRT.Window(X1, Y1, X2, Y2);

  If Home Then CursorXY (1, Y1);

  If (FCursorY > Y2) Then CursorXY (CursorX, Y2);
End;

Procedure TOutputCRT.SetWindowTitle (Str: String);
Begin
  // does nothing
End;

Procedure TOutputCRT.ClearEOL;
Var
  Fill  : TCharInfo;
Begin
  If Active Then CRT.ClrEOL;

  Fill.Attributes := 7;
  Fill.UnicodeChar := ' ';

  FillWord (Buffer[CursorY][CursorX], (80 - CursorX) * 2, Word(Fill));
End;

Procedure TOutputCRT.ScrollWindow;
Begin
  Move (Buffer[2][1], Buffer[1][1], SizeOf(TConsoleLineRec) * (FWinBot - 1));

  FillChar(Buffer[FWinBot][1], SizeOf(TConsoleLineRec), 0);
End;

Procedure TOutputCRT.WriteChar (Ch: Char);
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
      Else
        ScrollWindow;

      BufFlush;
    End;
  End;
End;

Procedure TOutputCRT.WriteStr (Str: String);
Var
  Count : Byte;
Begin
  For Count := 1 to Length(Str) Do
    WriteChar(Str[Count]);

  BufFlush;
End;

Procedure TOutputCRT.WriteLine (Str: String);
Var
  Count : Byte;
Begin
  Str := Str + #13#10;

  For Count := 1 To Length(Str) Do
    WriteChar(Str[Count]);

  BufFlush;
End;

Function TOutputCRT.ReadCharXY (X, Y: Byte) : Char;
Begin
  ReadCharXY := Buffer[Y][X].UnicodeChar;
End;

Function TOutputCRT.ReadAttrXY (X, Y: Byte) : Byte;
Begin
  ReadAttrXY := Buffer[Y][X].Attributes;
End;

Procedure TOutputCRT.WriteXY (X, Y, A: Byte; Text: String);
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

  CursorXY (X, Y);
  SetTextAttr (A);

  For Count := 1 to Length(Text) Do
    If FCursorX <= 80 Then Begin
      Buffer[FCursorY][FCursorX].Attributes  := FTextAttr;
      Buffer[FCursorY][FCursorX].UnicodeChar := Text[Count];

      Inc (FCursorX);

      BufAddStr(Text[Count]);
    End Else
      Break;

  SetTextAttr(OldAttr);
  CursorXY (OldX, OldY);
End;

Procedure TOutputCRT.WriteXYPipe (X, Y, Attr, Pad: Integer; Text: String);

  Procedure AddChar (Ch: Char);
  Begin
    If FCursorX > 80 Then Exit;

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

  CursorXY (X, Y);
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

  SetTextAttr(OldAttr);
  CursorXY (OldX, OldY);
End;

Procedure TOutputCRT.GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
Begin
  FillChar(Image, SizeOf(Image), #0);

  Image.Data := Buffer;

  Image.CursorX := FCursorX;
  Image.CursorY := FCursorY;
  Image.CursorA := FTextAttr;
  Image.X1      := X1;
  Image.X2      := X2;
  Image.Y1      := Y1;
  Image.Y2      := Y2;
End;

Procedure TOutputCRT.PutScreenImage (Image: TConsoleImageRec);
Var
  CountX : Byte;
  CountY : Byte;
Begin
  For CountY := Image.Y1 to Image.Y2 Do Begin
    CursorXY (Image.X1, CountY);

    For CountX := Image.X1 to Image.X2 Do Begin
      If (CountX = 80) And (CountY = ScreenSize) Then Break;

      SetTextAttr(Image.Data[CountY][CountX].Attributes);
      BufAddStr(Image.Data[CountY][CountX].UnicodeChar);

      Buffer[CountY][CountX] := Image.Data[CountY][CountX];
    End;
  End;

  SetTextAttr (Image.CursorA);
  CursorXY (Image.CursorX, Image.CursorY);
End;

Procedure TOutputCRT.LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);
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

Procedure TOutputCRT.ShowBuffer;
Begin
End;

End.

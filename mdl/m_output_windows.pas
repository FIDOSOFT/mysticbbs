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
Unit m_Output_Windows;

{$I M_OPS.PAS}

Interface

Uses
  Windows,
  m_Types;

Type
  TOutputWindows = Class
  Private
    ConOut : THandle;
    Cursor : TCoord;
  Public
    ScreenSize : Byte;
    Active     : Boolean;
    TextAttr   : Byte;
    Buffer     : TConsoleScreenRec;
    LineBuf    : TConsoleLineRec;
    Window     : TSmallRect;

    Constructor Create (A: Boolean);
    Destructor  Destroy; Override;
    Procedure   ClearScreen; Virtual;
    Procedure   ClearScreenNoUpdate;
    Procedure   ScrollWindow; Virtual;
    Procedure   ClearEOL;
    Procedure   CursorXY (X, Y: Byte);
    Function    CursorX : Byte;
    Function    CursorY : Byte;
    Procedure   SetScreenSize (Mode: Byte);
    Procedure   SetWindowTitle (Title: String);
    Procedure   SetWindow (X1, Y1, X2, Y2: Byte; Home: Boolean);
    Procedure   GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
    Procedure   PutScreenImage (Var Image: TConsoleImageRec);
    Procedure   LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);
    Procedure   WriteXY (X, Y, A: Byte; Text: String);
    Procedure   WriteXYNoUpdate (X, Y, A: Byte; Text: String);
    Procedure   WriteXYPipe (X, Y, Attr, Pad: Integer; Text: String);
    Procedure   WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
    Function    ReadCharXY (X, Y: Byte) : Char;
    Function    ReadAttrXY (X, Y: Byte) : Byte;
    Procedure   WriteChar (Ch: Char);
    Procedure   WriteLine (Str: String);
    Procedure   WriteStr (Str: String);
    Procedure   ShowBuffer;
    Procedure   BufFlush; // Linux compatibility only

//    Property ScreenSize : Byte Read FScreenSize;
//    Property TextAttr   : Byte Read FTextAttr    Write FTextAttr;
  End;

Implementation

Uses
  m_Strings;

Procedure TOutputWindows.WriteLineRec (YPos: Integer; Line: TConsoleLineRec);
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
Begin
  BufSize.X     := 80;
  BufSize.Y     := 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := 0;
  Region.Top    := YPos - 1;
  Region.Right  := 79;
  Region.Bottom := YPos - 1;

  WriteConsoleOutput(ConOut, @Line, BufSize, BufCoord, Region);

  Buffer[YPos] := Line;
End;

Procedure TOutputWindows.SetWindow (X1, Y1, X2, Y2 : Byte; Home: Boolean);
Begin
  If (X1 > X2) or (X2 > 80) or
     (Y1 > Y2) or (Y2 > ScreenSize) Then Exit;

  Window.Left   := X1 - 1;
  Window.Top    := Y1 - 1;
  Window.Right  := X2 - 1;
  Window.Bottom := Y2 - 1;

  If Home Then CursorXY (X1, Y1) Else CursorXY (Cursor.X + 1, Cursor.Y + 1);
End;

Constructor TOutputWindows.Create (A: Boolean);
Var
  ScreenMode : TConsoleScreenBufferInfo;
  CursorInfo : TConsoleCursorInfo;
Begin
  Inherited Create;

  Active := A;
  ConOut := GetStdHandle(STD_OUTPUT_HANDLE);

  GetConsoleScreenBufferInfo(ConOut, ScreenMode);

  Case ScreenMode.dwSize.Y of
    25 : ScreenSize := 25;
    50 : ScreenSize := 50;
  Else
    SetScreenSize(25);

    ScreenSize := 25;
  End;

  CursorInfo.bVisible := True;
  CursorInfo.dwSize   := 15;

  SetConsoleCursorInfo(ConOut, CursorInfo);

  Window.Top    := 0;
  Window.Left   := 0;
  Window.Right  := 79;
  Window.Bottom := ScreenSize - 1;

  TextAttr := 7;

  ClearScreen;
End;

Destructor TOutputWindows.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TOutputWindows.SetScreenSize (Mode: Byte);
Var
  Size : TCoord;
Begin
  If (Mode = ScreenSize) Or Not (Mode in [25, 50]) Then Exit;

  Size.X := 80;
  Size.Y := Mode;

  Window.Top    := 0;
  Window.Left   := 0;
  Window.Right  := Size.X - 1;
  Window.Bottom := Size.Y - 1;

  SetConsoleScreenBufferSize (ConOut, Size);
  SetConsoleWindowInfo       (ConOut, True, Window);
  SetConsoleScreenBufferSize (ConOut, Size);

  ScreenSize := Mode;
End;

Procedure TOutputWindows.CursorXY (X, Y: Byte);
Begin
  // don't move to x/y coordinate outside of window

  Cursor.X := X - 1;
  Cursor.Y := Y - 1;

  If Cursor.X < Window.Left   Then Cursor.X := Window.Left Else
  If Cursor.X > Window.Right  Then Cursor.X := Window.Right;
  If Cursor.Y < Window.Top    Then Cursor.Y := Window.Top Else
  If Cursor.Y > Window.Bottom Then Cursor.Y := Window.Bottom;

  If Active Then
    SetConsoleCursorPosition(ConOut, Cursor);
End;

Procedure TOutputWindows.ClearEOL;
Var
  Count    : Byte;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
Begin
  Count := Window.Right - Cursor.X + 1;

  FillDWord (Buffer[Cursor.Y + 1][Cursor.X + 1], Count, (Word(TextAttr) SHL 16) OR Word($0020));

  If Active Then Begin
    BufSize.X     := Count - 1;
    BufSize.Y     := 1;
    BufCoord.X    := 0;
    BufCoord.Y    := 0;
    Region.Left   := Cursor.X;
    Region.Top    := Cursor.Y;
    Region.Right  := Cursor.X + Count - 1;
    Region.Bottom := Cursor.Y;

    WriteConsoleOutput(ConOut, @Buffer[Cursor.Y + 1][Cursor.X + 1], BufSize, BufCoord, Region);
  End;
End;

(*
Procedure TOutputWindows.ClearEOL;
Var
  Count : Byte;
  Res   : LongInt;
Begin
  Count := Window.Right - Cursor.X + 1;

  FillDWord (Buffer[Cursor.Y + 1][Cursor.X + 1], Count, (Word(TextAttr) SHL 16) OR Word($0020));

  If Active Then Begin
    FillConsoleOutputCharacter (ConOut, ' ', Count, Cursor, @Res);
    FillConsoleOutputAttribute (ConOut, TextAttr, Count, Cursor, @Res);
  End;
End;
*)
Procedure TOutputWindows.ClearScreenNoUpdate;
Var
  Res   : ULong;
  Count : Byte;
  Size  : Byte;
  Cell  : TCharInfo;
Begin
  Size             := Window.Right - Window.Left + 1;
  Cursor.X         := Window.Left;
  Cell.Attributes  := TextAttr;
  Cell.UnicodeChar := ' ';

  For Count := Window.Top To Window.Bottom Do Begin
    Cursor.Y := Count;

    FillConsoleOutputAttribute(ConOut, Cell.Attributes, Size, Cursor, Res);
    FillConsoleOutputCharacter(ConOut, ' ', Size, Cursor, Res);
  End;
End;

Procedure TOutputWindows.ClearScreen;
Var
  Res   : ULong;
  Count : Byte;
  Size  : Byte;
  Cell  : TCharInfo;
Begin
  Size             := Window.Right - Window.Left + 1;
  Cursor.X         := Window.Left;
  Cell.Attributes  := TextAttr;
  Cell.UnicodeChar := ' ';

  If Active Then Begin
    For Count := Window.Top To Window.Bottom Do Begin
      Cursor.Y := Count;

      FillConsoleOutputAttribute(ConOut, Cell.Attributes, Size, Cursor, Res);
      FillConsoleOutputCharacter(ConOut, ' ', Size, Cursor, Res);
    End;
  End;

  FillChar (Buffer, SizeOf(Buffer), 0);

  CursorXY (Window.Left + 1, Window.Top + 1);
End;

Procedure TOutputWindows.SetWindowTitle (Title: String);
Begin
  Title := Title + #0;
  SetConsoleTitle(@Title[1]);
End;

Procedure TOutputWindows.WriteXY (X, Y, A: Byte; Text: String);
Var
  Buf      : Array[1..80] of TCharInfo;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
  Count    : Byte;
Begin
  Count := 1;

  While Count <= Length(Text) Do Begin
    Buf[Count].Attributes  := A;
    Buf[Count].UnicodeChar := Text[Count];

    Inc (Count);
  End;

  Move (Buf[1], Buffer[Y][X], (Count - 1) * SizeOf(TCharInfo));

  If Active Then Begin
    BufSize.X     := Count - 1;
    BufSize.Y     := 1;
    BufCoord.X    := 0;
    BufCoord.Y    := 0;
    Region.Left   := X - 1;
    Region.Top    := Y - 1;
    Region.Right  := X + Count - 1;
    Region.Bottom := Y - 1;

    If Region.Right > 79 Then Region.Right := 79;

    WriteConsoleOutput(ConOut, @Buf, BufSize, BufCoord, Region);
  End;
End;

Procedure TOutputWindows.WriteXYNoUpdate (X, Y, A: Byte; Text: String);
Var
  Buf      : Array[1..80] of TCharInfo;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
  Count    : Byte;
Begin
  Count := 1;

  While Count <= Length(Text) Do Begin
    Buf[Count].Attributes  := A;
    Buf[Count].UnicodeChar := Text[Count];

    Inc (Count);
  End;

  BufSize.X     := Count - 1;
  BufSize.Y     := 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := X - 1;
  Region.Top    := Y - 1;
  Region.Right  := X + Count - 1;
  Region.Bottom := Y - 1;

  If Region.Right > 79 Then Region.Right := 79;

  WriteConsoleOutput(ConOut, @Buf, BufSize, BufCoord, Region);
End;

Procedure TOutputWindows.WriteXYPipe (X, Y, Attr, Pad: Integer; Text: String);
Var
  Buf      : Array[1..80] of TCharInfo;
  BufPos   : Byte;
  Count    : Byte;
  Code     : String[2];
  CodeNum  : Byte;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;

  Procedure AddChar;
  Begin
    Inc (BufPos);

    Buf[BufPos].Attributes  := Attr;
    Buf[BufPos].UnicodeChar := Text[Count];
  End;

Begin
  FillChar(Buf, SizeOf(Buf), #0);

  Count  := 1;
  BufPos := 0;

  While Count <= Length(Text) Do Begin
    If Text[Count] = '|' Then Begin
      Code    := Copy(Text, Count + 1, 2);
      CodeNum := strS2I(Code);

      If (Code = '00') or ((CodeNum > 0) and (CodeNum < 24) and (Code[1] <> '$') and (Code[1] <> '&')) Then Begin
        Inc (Count, 2);

        If CodeNum in [00..15] Then
          Attr := CodeNum + ((Attr SHR 4) AND 7) * 16
        Else
          Attr := (Attr AND $F) + (CodeNum - 16) * 16;
      End Else
        AddChar;
    End Else
      AddChar;

    If BufPos = Pad Then Break;

    Inc (Count);
  End;

  Text[1] := #32;
  Count   := 1;

  While BufPos < Pad Do AddChar;

  BufSize.X     := Pad;
  BufSize.Y     := 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := X - 1;
  Region.Top    := Y - 1;
  Region.Right  := X + Pad;
  Region.Bottom := Y - 1;

  If Region.Right > 79 Then Region.Right := 79;

  Move (Buf[1], Buffer[Y][X], BufSize.X * SizeOf(TCharInfo));

  If Active Then
    WriteConsoleOutput(ConOut, @Buf, BufSize, BufCoord, Region);
End;

Function TOutputWindows.CursorX : Byte;
Begin
  CursorX := Cursor.X + 1;
End;

Function TOutputWindows.CursorY : Byte;
Begin
  CursorY := Cursor.Y + 1;
End;

Procedure TOutputWindows.WriteChar (Ch: Char);
Var
  BufferSize,
  BufferCoord : TCoord;
  WriteRegion : TSmallRect;
  OneCell     : TCharInfo;
//  Res         : LongInt;
Begin
  Case Ch of
    #08 : If Cursor.X > Window.Left Then Begin
            Dec(Cursor.X);

            If Active Then SetConsoleCursorPosition(ConOut, Cursor);
          End;
    #10 : Begin
            If Cursor.Y = Window.Bottom Then
              ScrollWindow
            Else Begin
              Inc (Cursor.Y);

              Cursor.X := Window.Left;
            End;

            If Active Then SetConsoleCursorPosition(ConOut, Cursor);
          End;
    #13 : Cursor.X := Window.Left;
  Else
    If Active Then Begin
      OneCell.UnicodeChar := Ch;
      OneCell.Attributes  := TextAttr;

      BufferSize.X  := 1;
      BufferSize.Y  := 1;
      BufferCoord.X := 0;
      BufferCoord.Y := 0;

      WriteRegion.Left   := Cursor.X;
      WriteRegion.Top    := Cursor.Y;
      WriteRegion.Right  := Cursor.X;
      WriteRegion.Bottom := Cursor.Y;
//      FillConsoleOutputCharacter (ConOut, Ch, 1, Cursor, @Res);
//      FillConsoleOutputAttribute (ConOut, TextAttr, 1, Cursor, @Res);

      WriteConsoleOutput (ConOut, @OneCell, BufferSize, BufferCoord, WriteRegion);
    End;

    Buffer[Cursor.Y + 1][Cursor.X + 1].UnicodeChar := Ch;
    Buffer[Cursor.Y + 1][Cursor.X + 1].Attributes  := TextAttr;

    If Cursor.X < Window.Right Then
      Inc (Cursor.X)
    Else Begin
      If (Cursor.X = Window.Right) And (Cursor.Y = Window.Bottom - 1) Then Begin
        Inc (Cursor.X);
        Exit;
      End;

      Cursor.X := Window.Left;

      If Cursor.Y = Window.Bottom Then
        ScrollWindow
      Else
        Inc (Cursor.Y);
    End;

    If Active Then SetConsoleCursorPosition(ConOut, Cursor);
  End;
End;

(*
Procedure TOutputWindows.WriteChar (Ch: Char);
Var
  BufferSize,
  BufferCoord : TCoord;
  WriteRegion : TSmallRect;
  OneCell     : TCharInfo;
Begin
  Case Ch of
    #08 : If Cursor.X > Window.Left Then Begin
            Dec(Cursor.X);
            If Active Then SetConsoleCursorPosition(ConOut, Cursor);
          End;
    #10 : Begin
            If Cursor.Y = Window.Bottom Then
              ScrollWindow
            Else Begin
              Inc (Cursor.Y);
              Cursor.X := Window.Left;
            End;

            If Active Then SetConsoleCursorPosition(ConOut, Cursor);
          End;
    #13 : Cursor.X := Window.Left;
  Else
    If Active Then Begin
      OneCell.UnicodeChar := Ch;
      OneCell.Attributes  := TextAttr;

      BufferSize.X  := 1;
      BufferSize.Y  := 1;
      BufferCoord.X := 0;
      BufferCoord.Y := 0;

      WriteRegion.Left   := Cursor.X;
      WriteRegion.Top    := Cursor.Y;
      WriteRegion.Right  := Cursor.X;
      WriteRegion.Bottom := Cursor.Y;

      WriteConsoleOutput (ConOut, @OneCell, BufferSize, BufferCoord, WriteRegion);
    End;

    Buffer[Cursor.Y + 1][Cursor.X + 1].UnicodeChar := Ch;
    Buffer[Cursor.Y + 1][Cursor.X + 1].Attributes  := TextAttr;

    If Cursor.X < Window.Right Then
      Inc (Cursor.X)
    Else Begin
      If (Cursor.X = Window.Right) And (Cursor.Y = Window.Bottom - 1) Then Begin
        Inc (Cursor.X);
        Exit;
      End;

      Cursor.X := Window.Left;

      If Cursor.Y = Window.Bottom Then
        ScrollWindow
      Else
        Inc (Cursor.Y);
    End;

    If Active Then SetConsoleCursorPosition(ConOut, Cursor);
  End;
End;
*)

Procedure TOutputWindows.WriteLine (Str: String);
Var
  Count : Byte;
Begin
  Str := Str + #13#10;

  For Count := 1 to Length(Str) Do WriteChar(Str[Count]);
End;

Procedure TOutputWindows.WriteStr (Str: String);
Var
  Count : Byte;
Begin
  For Count := 1 to Length(Str) Do WriteChar(Str[Count]);
End;

Procedure TOutputWindows.ScrollWindow;
Var
  DestCoord  : TCoord;
  Fill       : TCharInfo;
Begin
  Fill.UnicodeChar := ' ';
  Fill.Attributes  := 7;

  DestCoord.X := Window.Left;
  DestCoord.Y := Window.Top - 1;

  If Active Then
    ScrollConsoleScreenBuffer(ConOut, Window, Window, DestCoord, Fill);

  Move     (Buffer[2][1], Buffer[1][1], SizeOf(TConsoleLineRec) * 49);
  FillChar (Buffer[Window.Bottom + 1][1], SizeOf(TConsoleLineRec), #0);
End;

Procedure TOutputWindows.GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
Var
  CountY : Byte;
  CountX : Byte;
  BufPos : Integer;
  NewBuf : Array[1..SizeOf(TConsoleScreenRec) DIV 2] of Word Absolute Image.Data;
Begin
  Image.X1      := X1;
  Image.X2      := X2;
  Image.Y1      := Y1;
  Image.Y2      := Y2;
  Image.CursorX := CursorX;
  Image.CursorY := CursorY;
  Image.CursorA := TextAttr;

  BufPos := 1;

  For CountY := Y1 to Y2 Do Begin
    For CountX := X1 to X2 Do Begin
      NewBuf[BufPos]   := Word(Buffer[CountY][CountX].UnicodeChar);
      NewBuf[BufPos+1] := Buffer[CountY][CountX].Attributes;
      Inc (BufPos, 2);
    End;
  End;
End;

(*
Procedure TOutputWindows.GetScreenImage (X1, Y1, X2, Y2: Byte; Var Image: TConsoleImageRec);
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
//  x,y,cx,cy:byte;
Begin
  BufSize.X     := X2 - X1 + 1;
  BufSize.Y     := Y2 - Y1 + 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := X1 - 1;
  Region.Top    := Y1 - 1;
  Region.Right  := X2 - 1;
  Region.Bottom := Y2 - 1;
  Image.X1      := X1;
  Image.X2      := X2;
  Image.Y1      := Y1;
  Image.Y2      := Y2;
  Image.CursorX := CursorX;
  Image.CursorY := CursorY;
  Image.CursorA := TextAttr;

  If Active Then
    ReadConsoleOutput (ConOut, @Image.Data[1][1], BufSize, BufCoord, Region)
  Else
    Image.Data := Buffer;
End;
*)

Procedure TOutputWindows.ShowBuffer;
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
Begin
  BufSize.X     := 80;
  BufSize.Y     := ScreenSize;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := 0;
  Region.Top    := 0;
  Region.Right  := 79;
  Region.Bottom := ScreenSize - 1;

  WriteConsoleOutput (ConOut, @Buffer[1][1], BufSize, BufCoord, Region);

  CursorXY (Cursor.X + 1, Cursor.Y + 1);
End;

Procedure TOutputWindows.PutScreenImage (Var Image: TConsoleImageRec);
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;

  CountX  : Byte;
  CountY  : Byte;
  BufPos  : Integer;
  TempBuf : Array[1..SizeOf(TConsoleScreenRec) DIV 2] of LongInt Absolute Image.Data;
Begin
  BufSize.X     := Image.X2 - Image.X1 + 1;
  BufSize.Y     := Image.Y2 - Image.Y1 + 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := Image.X1 - 1;
  Region.Top    := Image.Y1 - 1;
  Region.Right  := Image.X2 - 1;
  Region.Bottom := Image.Y2 - 1;

  WriteConsoleOutput (ConOut, @Image.Data[1][1], BufSize, BufCoord, Region);

  BufPos := 1;

  For CountY := Image.Y1 to Image.Y2 Do
    For CountX := Image.X1 to Image.X2 Do Begin
      Buffer[CountY][CountX] := TCharInfo(TempBuf[BufPos]);
      Inc(BufPos);
    End;

  CursorXY (Image.CursorX, Image.CursorY);

  TextAttr := Image.CursorA;
End;

Procedure TOutputWindows.LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);
Var
  Image  : TConsoleImageRec;
  Data   : Array[1..8000] of Byte Absolute DataPtr;
  PosX   : Word;
  PosY   : Byte;
  Attrib : Byte;
  Count  : Word;
  A      : Byte;
  B      : Byte;
  C      : Byte;
Begin
  PosX   := 1;
  PosY   := 1;
  Attrib := 7;
  Count  := 1;

  FillChar(Image.Data, SizeOf(Image.Data), #0);

  While (Count <= Len) Do Begin
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
                Image.data[PosY][PosX].Attributes  := Attrib;

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

    Inc (Count);
  End;

  Image.X1      := X;
  Image.X2      := Width;
  Image.Y1      := Y;
  Image.Y2      := PosY;
  Image.CursorX := PosX;
  Image.CursorY := PosY;
  Image.CursorA := Attrib;

  PutScreenImage(Image);
End;

(*
Procedure TOutputWindows.LoadScreenImage (Var DataPtr; Len, Width, X, Y: Integer);
Var
  Screen   : TConsoleScreenRec;
  Data     : Array[1..8000] of Byte Absolute DataPtr;
  PosX     : Word;
  PosY     : Byte;
  Attrib   : Byte;
  Count    : Word;
  A        : Byte;
  B        : Byte;
  C        : Byte;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
Begin
  PosX   := 1;
  PosY   := 1;
  Attrib := 7;
  Count  := 1;

  FillChar(Screen, SizeOf(Screen), #0);

  While (Count <= Len) Do Begin
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
                Screen[PosY][PosX].UnicodeChar := ' ';
                Screen[PosY][PosX].Attributes  := Attrib;

                Inc (PosX);
              End;
            End;
      26  : Begin
              A := Data[Count + 1];
              B := Data[Count + 2];

              Inc (Count, 2);

              For C := 0 to A Do Begin
                Screen[PosY][PosX].UnicodeChar := Char(B);
                Screen[PosY][PosX].Attributes  := Attrib;

                Inc (PosX);
              End;
            End;
      27..
      31  : ;
    Else
      Screen[PosY][PosX].UnicodeChar := Char(Data[Count]);
      Screen[PosY][PosX].Attributes  := Attrib;

      Inc (PosX);
    End;

    Inc (Count);
  End;

  BufSize.Y     := PosY - (Y - 1);
  BufSize.X     := Width;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := X - 1;
  Region.Top    := Y - 1;
  Region.Right  := Width - 1;
  Region.Bottom := PosY - 1;

  WriteConsoleOutput (ConOut, @Screen[1][1], BufSize, BufCoord, Region);

  CursorXY(PosX, PosY);
End;
*)

Function TOutputWindows.ReadCharXY (X, Y: Byte) : Char;
Begin
  Result := Buffer[Y][X].UnicodeChar;
End;

Function TOutputWindows.ReadAttrXY (X, Y: Byte) : Byte;
Begin
  Result := Buffer[Y][X].Attributes;
End;

Procedure TOutputWindows.BufFlush;
Begin
End;

End.

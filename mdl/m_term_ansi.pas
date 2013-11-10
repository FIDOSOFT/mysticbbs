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

Unit m_Term_Ansi;

Interface

Uses
  m_Output,
  m_io_Base,
  m_Strings;

Type
  TTermAnsi = Class
    Screen   : TOutput;
    WasValid : Boolean;
  Private
    Client  : TIOBase;
    State   : Byte;
    SavedX  : Byte;
    SavedY  : Byte;
    Options : String;
    LastCh  : Char;

    Procedure   CheckCode (Ch: Char);
    Function    ParseNumber : Integer;
    Procedure   ResetState;
    Procedure   CursorUp;
    Procedure   CursorMove;
    Procedure   CursorDown;
    Procedure   CursorRight;
    Procedure   CursorLeft;
  Public
    Constructor Create (Var Con: TOutput);
    Destructor  Destroy; Override;
    Procedure   Process (Ch: Char);
    Procedure   ProcessBuf (Var Buf; BufLen : Word);
    Procedure   SetReplyClient (Var Cli: TIOBase);
  End;

Implementation

Const
  ColorTable : Array[30..47] of Byte = (0, 4, 2, 6, 1, 5, 3, 7, 0, 0, 0, 64, 32, 96, 16, 80, 48, 112);

Constructor TTermAnsi.Create (Var Con: TOutput);
Begin
  Inherited Create;

  Screen   := Con;
  Client   := NIL;
  WasValid := False;

  ResetState;
End;

Destructor TTermAnsi.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TTermAnsi.SetReplyClient (Var Cli: TIOBase);
Begin
  Client := Cli;
End;

Function TTermAnsi.ParseNumber : Integer;
Var
  Res : LongInt;
  Str : String;
Begin
  Val (Options, Result, Res);

  If Res = 0 Then
    Options := ''
  Else Begin
    Str := Copy(Options, 1, Pred(Res));

    Delete (Options, 1, Res);
    Val    (Str, Result, Res);
  End;
End;

Procedure TTermAnsi.ResetState;
Begin
  State   := 0;
  Options := '';
End;

Procedure TTermAnsi.CursorMove;
Var
  X : Byte;
  Y : Byte;
Begin
  Y := ParseNumber;

  If Y = 0 Then Y := 1;

  X := ParseNumber;

  If X = 0 Then X := 1;

  Screen.CursorXY (X, Y);

  ResetState;
End;

Procedure TTermAnsi.CursorUp;
Var
  Y      : Integer;
  NewY   : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then Offset := 1;

  Y := Screen.CursorY;

  If (Y - Offset) < 1 Then
    NewY := 1
  Else
    NewY := Y - Offset;

  Screen.CursorXY (Screen.CursorX, NewY);

  ResetState;
End;

Procedure TTermAnsi.CursorDown;
Var
  NewY : Byte;
Begin
  NewY := ParseNumber;

  If NewY = 0 Then NewY := 1;

  NewY := NewY + Screen.CursorY;

  Screen.CursorXY (Screen.CursorX, NewY);

  ResetState;
End;

Procedure TTermAnsi.CursorRight;
Var
  X      : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then Offset := 1;

  X := Screen.CursorX;

  If (X + Offset) > 80 Then Begin
     Screen.CursorXY (80, Screen.CursorY);
    //Screen.WriteChar(#10);  // force lf incase we have to scroll
    //Screen.CursorXY(X + Offset - 80, Screen.CursorY);
  End Else
    Screen.CursorXY (x + offset, Screen.CursorY);

  ResetState;
End;

Procedure TTermAnsi.CursorLeft;
Var
  X      : Integer;
  NewX   : Integer;
  Offset : Integer;
Begin
  Offset := ParseNumber;

  If Offset = 0 Then offset := 1;

  X := Screen.CursorX;

  If (X - Offset) < 1 Then
    NewX := 1
  Else
    NewX := X - Offset;

  Screen.CursorXY (NewX, Screen.CursorY);

  ResetState;
End;

Procedure TTermAnsi.CheckCode (Ch : Char);
Var
  Temp : Byte;
Begin
  Case Ch of
    'h'           : ResetState;
    '0'..'9',
    '?', ';'      : Options := Options + Ch;
    'H', 'f'      : CursorMove;
    'A'           : CursorUp;
    'B'           : CursorDown;
    'C'           : CursorRight;
    'D'           : CursorLeft;
    'J'           : Begin
                      Screen.ClearScreen;
                      ResetState;
                    End;
    'K'           : Begin
                      Screen.ClearEOL;
                      ResetState;
                    End;
    'm'           : Begin
                      If Length(Options) = 0 Then Begin
                        Screen.TextAttr := 7;

                        ResetState;
                      End Else
                      While Length(Options) > 0 Do Begin
                        Temp := ParseNumber;

                        Case Temp of
                          0 : Screen.TextAttr := 7;
                          1 : Screen.TextAttr := Screen.TextAttr OR $08;
                          5 : Screen.TextAttr := Screen.TextAttr OR $80;
                          7 : Begin
                                Screen.TextAttr := Screen.TextAttr AND $F7;
                                Screen.TextAttr := (((Screen.TextAttr AND $70) SHR 4) + ((Screen.TextAttr AND $7) SHL 4) + Screen.TextAttr AND $80);
                              End;
                          30..
                          37: Screen.TextAttr := (Screen.TextAttr AND $F8 + ColorTable[Temp]);
                          40..
                          47: Screen.TextAttr := (Screen.TextAttr AND $F + ColorTable[Temp]);
                        End;
                      End;

                      ResetState;
                    End;
    'n'           : Begin
                      If Client <> NIL Then
                        Client.WriteStr(#27 + '[' + strI2S(Screen.CursorY) + ';' + strI2S(Screen.CursorX) + 'R');

                      ResetState;
                    End;
    's'           : Begin
                      SavedX := Screen.CursorX;
                      SavedY := Screen.CursorY;

                      ResetState;
                    End;
    'u'           : Begin
                      Screen.CursorXY (SavedX, SavedY);

                      ResetState;
                    End;
  Else
    ResetState;
  End;
End;

Procedure TTermAnsi.Process (Ch : Char);
Begin
  WasValid := False;

  Case State of
    0 : Begin
          Case Ch of
            #0  : ;
            #27 : State := 1;
            #9  : Screen.CursorXY (Screen.CursorX + 8, Screen.CursorY);
            #10 : Begin
                    If LastCh <> #13 Then
                      Screen.WriteChar(#13);
                    Screen.WriteChar(#10);
                  End;
            #12 : Screen.ClearScreen;
            {$IFDEF UNIX}
            #14,
            #15 : Screen.WriteChar('X');
            {$ENDIF}
          Else
            Screen.WriteChar(Ch);

            State    := 0;
            WasValid := True;
          End;
        End;
    1 : If Ch = '[' Then Begin
           State   := 2;
           Options := '';
         End Else
           State := 0;
     2 : CheckCode(Ch);
   Else
     ResetState;
   End;

   LastCh := Ch;
End;

Procedure TTermAnsi.ProcessBuf (Var Buf; BufLen : Word);
Var
  Count : Word;
  Data  : Array[1..16384] of Char Absolute Buf;
Begin
  For Count := 1 to BufLen Do Begin
    WasValid := False;

    Case State of
      0 : Begin
            Case Data[Count] of
              #0  : ;
              #27 : State := 1;
              #9  : Screen.CursorXY (Screen.CursorX + 8, Screen.CursorY);
              #12 : Screen.ClearScreen;
              {$IFDEF UNIX}
              #14,
              #15 : Screen.WriteChar('X');
              {$ENDIF}
            Else
              Screen.WriteChar(Data[Count]);
              WasValid := True;
              State    := 0;
            End;
          End;
      1 : If Data[Count] = '[' Then Begin
             State   := 2;
             Options := '';
           End Else
             State := 0;
       2 : CheckCode(Data[Count]);
     Else
       ResetState;
     End;
  End;

  Screen.BufFlush;
End;

End.

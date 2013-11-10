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

Unit m_MenuInput;

Interface

Uses
  m_Strings,
  m_Input,
  m_Output;

Type
  TMenuInput = Class
  Private
    Console  : TOutput;
  Public
    Key      : TInput;
    HiChars  : String;
    LoChars  : String;
    ExitCode : Char;
    Attr     : Byte;
    FillChar : Char;
    FillAttr : Byte;
    Changed  : Boolean;

    Constructor Create (Var Screen: TOutput);
    Destructor  Destroy; Override;
    Function    GetStr (X, Y, Field, Len, Mode: Byte; Default: String) : String;
    Function    GetNum (X, Y, Field, Len: Byte; Min, Max, Default: LongInt) : LongInt;
    Function    GetChar (X, Y : Byte; Default: Char) : Char;
    Function    GetEnter (X, Y, Len: Byte; Default : String) : Boolean;
    Function    GetYN (X, Y : Byte; Default: Boolean) : Boolean;

    Function    KeyWaiting : Boolean;
    Function    ReadKey : Char;
  End;

Implementation

Constructor TMenuInput.Create (Var Screen: TOutput);
Begin
  Inherited Create;

  Console  := Screen;
  Key      := TInput.Create;
  LoChars  := #13;
  HiChars  := '';
  Attr     := 15 + 1 * 16;
  FillAttr := 7  + 1 * 16;
  FillChar := '°';
  Changed  := False;
End;

Destructor TMenuInput.Destroy;
Begin
  Key.Free;

  Inherited Destroy;
End;

Function TMenuInput.GetYN (X, Y : Byte; Default: Boolean) : Boolean;
Var
  Ch  : Char;
  Res : Boolean;
  YS  : Array[False..True] of String[3] = ('No ', 'Yes');
Begin
  ExitCode := #0;
  Changed  := False;

  Console.CursorXY (X, Y);

  Res := Default;

  Repeat
    Console.WriteXY (X, Y, Attr, YS[Res]);

    Ch := ReadKey;
    Case Ch of
      #00 : Begin
              Ch := ReadKey;
              If Pos(Ch, HiChars) > 0 Then Begin
                ExitCode := Ch;
                Break;
              End;
            End;
      #13,
      #32 : Res := Not Res;
    Else
      If Pos(Ch, LoChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;
    End;
  Until False;

  Changed := (Res <> Default);
  GetYN   := Res;
End;

Function TMenuInput.GetChar (X, Y : Byte; Default: Char) : Char;
Var
  Ch  : Char;
  Res : Char;
Begin
  ExitCode := #0;
  Changed  := False;
  Res      := Default;

  Console.CursorXY (X, Y);

  Repeat
    Console.WriteXY (X, Y, Attr, Res);

    Ch := ReadKey;

    Case Ch of
      #00 : Begin
              Ch := ReadKey;
              If Pos(Ch, HiChars) > 0 Then Begin
                ExitCode := Ch;
                Break;
              End;
            End;
    Else
      If Ch = #27 Then Res := Default;

      If Pos(Ch, LoChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;

      If Ord(Ch) > 31 Then Res := Ch;
    End;
  Until False;

  GetChar := Res;
End;

Function TMenuInput.GetEnter (X, Y, Len: Byte; Default : String) : Boolean;
Var
  Ch  : Char;
  Res : Boolean;
Begin
  ExitCode := #0;
  Changed  := False;

  Console.WriteXY (X, Y, Attr, strPadR(Default, Len, ' '));
  Console.CursorXY (X, Y);

  Repeat
    Ch  := ReadKey;
    Res := Ch = #13;
    Case Ch of
      #00 : Begin
              Ch := ReadKey;
              If Pos(Ch, HiChars) > 0 Then Begin
                ExitCode := Ch;
                Break;
              End;
            End;
      Else
        If Pos(Ch, LoChars) > 0 Then Begin
          ExitCode := Ch;
          Break;
        End;
    End;
  Until Res;

  Changed  := Res;
  GetEnter := Res;
End;

Function TMenuInput.GetStr (X, Y, Field, Len, Mode : Byte; Default : String) : String;
{ mode options:      }
{   0 = numbers only }
{   1 = as typed     }
{   2 = all caps     }
{   3 = date input   }
Var
  Ch     : Char;
  Str    : String;
  StrPos : Integer;
  Junk   : Integer;
  CurPos : Integer;

  Procedure ReDraw;
  Var
    T : String;
  Begin
    T := Copy(Str, Junk, Field);

    Console.WriteXY  (X, Y, Attr, T);
    Console.WriteXY  (X + Length(T), Y, FillAttr, strRep(FillChar, Field - Length(T)));
    Console.CursorXY (X + CurPos - 1, Console.CursorY);
  End;

  Procedure ReDrawPart;
  Var
    T : String;
  Begin
    T := Copy(Str, StrPos, Field - CurPos + 1);

    Console.WriteXY  (Console.CursorX, Y, Attr, T);
    Console.WriteXY  (Console.CursorX + Length(T), Y, FillAttr, strRep(FillChar, (Field - CurPos + 1) - Length(T)));
    Console.CursorXY (X + CurPos - 1, Y);
  End;

  Procedure ScrollRight;
  Begin
    Inc (Junk);
    If Junk > Length(Str) Then Junk := Length(Str);
    If Junk > Len then Junk := Len;
    CurPos := StrPos - Junk + 1;
    ReDraw;
  End;

  Procedure ScrollLeft;
  Begin
    If Junk > 1 Then Begin
      Dec (Junk);
      CurPos := StrPos - Junk + 1;
      ReDraw;
    End;
  End;

  Procedure Add_Char (Ch : Char);
  Begin
    If Length(Str) >= Len Then Exit;

    If (CurPos >= Field) and (Field <> Len) Then ScrollRight;

    Insert (Ch, Str, StrPos);
    If StrPos < Length(Str) Then ReDrawPart;

    Inc (StrPos);
    Inc (CurPos);

    Console.WriteXY  (Console.CursorX, Console.CursorY, Attr, Ch);
    Console.CursorXY (Console.CursorX + 1, Console.CursorY);
  End;

Begin
  Changed := False;
  Str     := Default;
  StrPos  := Length(Str) + 1;
  Junk    := Length(Str) - Field + 1;

  If Junk < 1 Then Junk := 1;

  CurPos  := StrPos - Junk + 1;

  Console.CursorXY (X, Y);
  Console.TextAttr := Attr;

  ReDraw;

  Repeat
    Ch := Key.ReadKey;

    Case Ch of
      #00 : Begin
              Ch := Key.ReadKey;

              Case Ch of
                #77 : If StrPos < Length(Str) + 1 Then Begin
                        If (CurPos = Field) and (StrPos < Length(Str)) Then ScrollRight;
                        Inc (CurPos);
                        Inc (StrPos);
                        Console.CursorXY (Console.CursorX + 1, Console.CursorY);
                      End;
                #75 : If StrPos > 1 Then Begin
                        If CurPos = 1 Then ScrollLeft;
                        Dec (StrPos);
                        Dec (CurPos);
                        Console.CursorXY (Console.CursorX - 1, Console.CursorY);
                      End;
                #71 : If StrPos > 1 Then Begin
                        StrPos := 1;
                        Junk   := 1;
                        CurPos := 1;
                        ReDraw;
                      End;
                #79 : Begin
                        StrPos := Length(Str) + 1;
                        Junk   := Length(Str) - Field + 1;
                        If Junk < 1 Then Junk := 1;
                        CurPos := StrPos - Junk + 1;
                        ReDraw;
                      End;
                #83 : If (StrPos <= Length(Str)) and (Length(Str) > 0) Then Begin
                        Delete (Str, StrPos, 1);
                        ReDrawPart;
                      End;
                #115: Begin
                        If (StrPos > 1) and (Str[StrPos] = ' ') or (Str[StrPos - 1] = ' ') Then Begin
                          If CurPos = 1 Then ScrollLeft;
                          Dec(StrPos);
                          Dec(CurPos);

                          While (StrPos > 1) and (Str[StrPos] = ' ') Do Begin
                            If CurPos = 1 Then ScrollLeft;
                            Dec(StrPos);
                            Dec(CurPos);
                          End;
                        End;

                        While (StrPos > 1) and (Str[StrPos] <> ' ') Do Begin
                          If CurPos = 1 Then ScrollLeft;
                          Dec(StrPos);
                          Dec(CurPos);
                        End;

                        While (StrPos > 1) and (Str[StrPos] <> ' ') Do Begin
                          If CurPos = 1 Then ScrollLeft;
                          Dec(StrPos);
                          Dec(CurPos);
                        End;

                        If (Str[StrPos] = ' ') and (StrPos > 1) Then Begin
                          Inc(StrPos);
                          Inc(CurPos);
                        End;

                        ReDraw;
                      End;
                #116: Begin
                        While StrPos < Length(Str) + 1 Do Begin
                          If (CurPos = Field) and (StrPos < Length(Str)) Then ScrollRight;
                          Inc (CurPos);
                          Inc (StrPos);

                          If Str[StrPos] = ' ' Then Begin
                            If StrPos < Length(Str) + 1 Then Begin
                              If (CurPos = Field) and (StrPos < Length(Str)) Then ScrollRight;
                              Inc (CurPos);
                              Inc (StrPos);
                            End;
                            Break;
                          End;
                        End;
                        Console.CursorXY (X + CurPos - 1, Y);
                      End;
              Else
                If Pos(Ch, HiChars) > 0 Then Begin
                  ExitCode := Ch;
                  Break;
                End;
              End;
            End;
      #08 : If StrPos > 1 Then Begin
              Dec (StrPos);
              Delete (Str, StrPos, 1);
              If CurPos = 1 Then
                ScrollLeft
              Else Begin
                Console.CursorXY (Console.CursorX - 1, Console.CursorY);
                Dec (CurPos);
                ReDrawPart;
              End;
            End;
      ^Y  : Begin
              Str    := '';
              StrPos := 1;
              Junk   := 1;
              CurPos := 1;
              ReDraw;
            End;
      #32..
      #254: Case Mode of
              0 : If Ch in ['0'..'9', '-'] Then Add_Char(Ch);
              1 : Add_Char (Ch);
              2 : Add_Char (UpCase(Ch));
              3 : If (Ch > '/') and (Ch < ':') Then
                    Case StrPos of
                      2,5 : Begin
                              Add_Char (Ch);
                              Add_Char ('/');
                            End;
                      3,6 : Begin
                              Add_Char ('/');
                              Add_Char (Ch);
                            End;
                    Else
                      Add_Char (Ch);
                    End;
            End;
    Else
      If Pos(Ch, LoChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
       End;
    End;
  Until False;

  Changed := (Str <> Default);
  Result  := Str;
End;

Function TMenuInput.GetNum (X, Y, Field, Len: Byte; Min, Max, Default: LongInt) : LongInt;
Var
  N : LongInt;
Begin
  N := Default;
  N := strS2I(Self.GetStr(X, Y, Field, Len, 0, strI2S(N)));

  If N < Min Then N := Min;
  If N > Max Then N := Max;

  GetNum := N;
End;

Function TMenuInput.KeyWaiting : Boolean;
Begin
  Result := Key.KeyPressed;
End;

Function TMenuInput.ReadKey : Char;
Begin
  Result := Key.ReadKey;
End;

End.

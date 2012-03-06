Unit bbs_Ansi_MenuInput;

// ANSI ports of MDL menu/input libraries

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  bbs_Ansi_MenuBox;

Type
  TAnsiMenuInput = Class
    HiChars  : String[40];
    LoChars  : String[40];
    ExitCode : Char;
    Attr     : Byte;
    FillChar : Char;
    FillAttr : Byte;
    Changed  : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;

    Function    GetStr   (X, Y, Field, Len, Mode: Byte; Default: String) : String;
    Function    GetNum   (X, Y, Field, Len: Byte; Min, Max, Default: LongInt) : LongInt;
    Function    GetChar  (X, Y : Byte; Default: Char) : Char;
    Function    GetEnter (X, Y, Len: Byte; Default : String) : Boolean;
    Function    GetYN    (X, Y : Byte; Default: Boolean) : Boolean;
  End;

Implementation

Uses
  bbs_Core,
  bbs_Common,
  bbs_IO;

Constructor TAnsiMenuInput.Create;
Begin
  Inherited Create;

  LoChars  := #13;
  HiChars  := '';
  Attr     := 15 + 1 * 16;
  FillAttr := 7  + 1 * 16;
  FillChar := '°';
  Changed  := False;
End;

Destructor TAnsiMenuInput.Destroy;
Begin
  Inherited Destroy;
End;

Function TAnsiMenuInput.GetYN (X, Y : Byte; Default: Boolean) : Boolean;
Var
  Ch  : Char;
  Res : Boolean;
  YS  : Array[False..True] of String[3] = ('No ', 'Yes');
Begin
  ExitCode := #0;
  Changed  := False;

  Session.io.AnsiGotoXY (X, Y);

  Res := Default;

  Repeat
    WriteXY (X, Y, Attr, YS[Res]);

    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      If Pos(Ch, HiChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;
    End Else
      Case Ch of
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

Function TAnsiMenuInput.GetChar (X, Y : Byte; Default: Char) : Char;
Var
  Ch  : Char;
  Res : Char;
Begin
  ExitCode := #0;
  Changed  := False;
  Res      := Default;

  Session.io.AnsiGotoXY (X, Y);

  Repeat
    WriteXY (X, Y, Attr, Res);

    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      If Pos(Ch, HiChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;
    End Else Begin
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

Function TAnsiMenuInput.GetEnter (X, Y, Len: Byte; Default : String) : Boolean;
Var
  Ch  : Char;
  Res : Boolean;
Begin
  ExitCode := #0;
  Changed  := False;

  WriteXY (X, Y, Attr, strPadR(Default, Len, ' '));

  Session.io.AnsiGotoXY (X, Y);

  Repeat
    Ch  := Session.io.GetKey;
    Res := Ch = #13;

    If Session.io.IsArrow Then Begin
      If Pos(Ch, HiChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;
    End Else
      If Pos(Ch, LoChars) > 0 Then Begin
        ExitCode := Ch;
        Break;
      End;
  Until Res;

  Changed  := Res;
  GetEnter := Res;
End;

// 0 = numbers only  1 = as typed   2 = all caps  3 = date input
Function TAnsiMenuInput.GetStr (X, Y, Field, Len, Mode : Byte; Default : String) : String;
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

    WriteXY  (X, Y, Attr, T);
    WriteXY  (X + Length(T), Y, FillAttr, strRep(FillChar, Field - Length(T)));

    Session.io.AnsiGotoXY (X + CurPos - 1, Screen.CursorY);
  End;

  Procedure ReDrawPart;
  Begin
    Session.io.AnsiColor (Attr);
    Session.io.BufAddStr (Copy(Str, StrPos, Field - CurPos + 1));
    Session.io.AnsiColor (FillAttr);
    Session.io.BufAddStr (strRep(FillChar, (Field - CurPos + 1) - Length(Copy(Str, StrPos, Field - CurPos + 1))));
    Session.io.AnsiMoveX (X + CurPos - 1);
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

  Procedure AddChar (Ch : Char);
  Begin
    If Length(Str) >= Len Then Exit;

    If (CurPos >= Field) and (Field <> Len) Then ScrollRight;

    Insert (Ch, Str, StrPos);

    If StrPos < Length(Str) Then ReDrawPart;

    Inc (StrPos);
    Inc (CurPos);

    Session.io.AnsiColor  (Attr);
    Session.io.BufAddChar (Ch);
  End;

Begin
  Changed := False;
  Str     := Default;
  StrPos  := Length(Str) + 1;
  Junk    := Length(Str) - Field + 1;

  If Junk < 1 Then Junk := 1;

  CurPos := StrPos - Junk + 1;

  ReDraw;

  Repeat
    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #77 : If StrPos < Length(Str) + 1 Then Begin
                If (CurPos = Field) and (StrPos < Length(Str)) Then ScrollRight;

                 Inc (CurPos);
                 Inc (StrPos);

                 Session.io.AnsiGotoXY (Screen.CursorX + 1, Screen.CursorY);
              End;
        #75 : If StrPos > 1 Then Begin
                If CurPos = 1 Then ScrollLeft;

                Dec (StrPos);
                Dec (CurPos);

                Session.io.AnsiGotoXY (Screen.CursorX - 1, Screen.CursorY);
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
      Else
        If Pos(Ch, HiChars) > 0 Then Begin
          ExitCode := Ch;

          Break;
        End;
      End;
    End Else
      Case Ch of
        #08 : If StrPos > 1 Then Begin
                Dec (StrPos);

                Delete (Str, StrPos, 1);

                If CurPos = 1 Then
                  ScrollLeft
                Else Begin
                  Session.io.AnsiMoveX(Screen.CursorX - 1);

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
                0 : If Ch in ['0'..'9', '-'] Then AddChar(Ch);
                1 : AddChar (Ch);
                2 : AddChar (UpCase(Ch));
                3 : If (Ch > '/') and (Ch < ':') Then
                      Case StrPos of
                        2,5 : Begin
                                AddChar (Ch);
                                AddChar ('/');
                              End;
                        3,6 : Begin
                                AddChar ('/');
                                AddChar (Ch);
                              End;
                      Else
                        AddChar (Ch);
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

Function TAnsiMenuInput.GetNum (X, Y, Field, Len: Byte; Min, Max, Default: LongInt) : LongInt;
Var
  N : LongInt;
Begin
  N := Default;
  N := strS2I(Self.GetStr(X, Y, Field, Len, 0, strI2S(N)));

  If N < Min Then N := Min;
  If N > Max Then N := Max;

  GetNum := N;
End;

End.

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

    Function    GetStr (X, Y, Field, Len, Mode: Byte; Default: String) : String;
    Function    GetNum (X, Y, Field, Len: Byte; Min, Max, Default: LongInt) : LongInt;
    Function    GetChar (X, Y : Byte; Default: Char) : Char;
    Function    GetEnter (X, Y, Len: Byte; Default : String) : Boolean;
    Function    GetYN (X, Y : Byte; Default: Boolean) : Boolean;
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

Function TAnsiMenuInput.GetStr (X, Y, Field, Len, Mode : Byte; Default : String) : String;
{ mode options:      }
{   0 = numbers only }
{   1 = as typed     }
{   2 = all caps     }
{   3 = date input   }
Var
  Str : String;
Begin
  Session.io.AnsiGotoXY(X, Y);

  Case Mode of
    0,
    1 : Str := Session.io.GetInput(Field, Len, 11, Default);
    2 : Str := Session.io.GetInput(Field, Len, 12, Default);
    3 : Str := Session.io.GetInput(Field, Len, 15, Default);
  End;

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

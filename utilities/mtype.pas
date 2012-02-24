Program MTYPE;

{$I M_OPS.PAS}

// Add screen pause option
// Add delay option similar to Mystic
// Processing formatting MCI codes, etc

Uses
  m_Output,
  m_Strings,
  m_DateTime,
  m_Term_Ansi;

Var
  Screen   : TOutput;
  Terminal : TTermAnsi;
  Buffer   : Array[1..4096] of Char;
  dFile    : File;
  Ext      : String[4];
  Code     : String[2];
  dRead    : LongInt;
  Old      : Boolean;
  Str      : String;
  A        : Word;
  Ch       : Char;
  Done     : Boolean;

  Function GetChar : Char;
  Begin
    If A = dRead Then Begin
      BlockRead (dFile, Buffer, SizeOf(Buffer), dRead);
      A := 0;
      If dRead = 0 Then Begin
        Done      := True;
        Buffer[1] := #26;
      End;
    End;

    Inc (A);
    GetChar := Buffer[A];
  End;

  Function Ansi_Color (B : Byte) : String;
  Var
    S : String;
  Begin
    S          := '';
    Ansi_Color := '';

    Case B of
      00: S := #27 + '[0;30m';
      01: S := #27 + '[0;34m';
      02: S := #27 + '[0;32m';
      03: S := #27 + '[0;36m';
      04: S := #27 + '[0;31m';
      05: S := #27 + '[0;35m';
      06: S := #27 + '[0;33m';
      07: S := #27 + '[0;37m';
      08: S := #27 + '[1;30m';
      09: S := #27 + '[1;34m';
      10: S := #27 + '[1;32m';
      11: S := #27 + '[1;36m';
      12: S := #27 + '[1;31m';
      13: S := #27 + '[1;35m';
      14: S := #27 + '[1;33m';
      15: S := #27 + '[1;37m';
    End;

    If B in [00..07] Then B := (Screen.TextAttr SHR 4) and 7 + 16;

    Case B of
      16: S := S + #27 + '[40m';
      17: S := S + #27 + '[44m';
      18: S := S + #27 + '[42m';
      19: S := S + #27 + '[46m';
      20: S := S + #27 + '[41m';
      21: S := S + #27 + '[45m';
      22: S := S + #27 + '[43m';
      23: S := S + #27 + '[47m';
    End;

    Ansi_Color := S;
  End;

  Procedure OutStr (S: String);
  Begin
    Terminal.ProcessBuf(S[1], Length(S));
  End;

Begin
  WriteLn;

  If ParamCount <> 1 Then Begin
    WriteLn('MTYPE [filename]');
    Exit;
  End;

  Assign (dFile, ParamStr(1));
  Reset  (dFile, 1);

  If IoResult <> 0 Then Begin
    WriteLn('MTYPE: File ' + ParamStr(1) + ' not found.');
    Exit;
  End;

  Screen   := TOutput.Create(True);
  Terminal := TTermAnsi.Create(Screen);

  Done  := False;
  A     := 0;
  dRead := 0;
  Ch    := #0;

  While Not Done Do Begin
    Ch := GetChar;

    If Ch = #26 Then
      Break
    Else
    If Ch = #10 Then Begin
      Terminal.Process(#10);
    End Else
    If Ch = '|' Then Begin
      Code := GetChar;
      Code := Code + GetChar;

      If Code = '00' Then OutStr(Ansi_Color(0)) Else
      If Code = '01' Then OutStr(Ansi_Color(1)) Else
      If Code = '02' Then OutStr(Ansi_Color(2)) Else
      If Code = '03' Then OutStr(Ansi_Color(3)) Else
      If Code = '04' Then OutStr(Ansi_Color(4)) Else
      If Code = '05' Then OutStr(Ansi_Color(5)) Else
      If Code = '06' Then OutStr(Ansi_Color(6)) Else
      If Code = '07' Then OutStr(Ansi_Color(7)) Else
      If Code = '08' Then OutStr(Ansi_Color(8)) Else
      If Code = '09' Then OutStr(Ansi_Color(9)) Else
      If Code = '10' Then OutStr(Ansi_Color(10)) Else
      If Code = '11' Then OutStr(Ansi_Color(11)) Else
      If Code = '12' Then OutStr(Ansi_Color(12)) Else
      If Code = '13' Then OutStr(Ansi_Color(13)) Else
      If Code = '14' Then OutStr(Ansi_Color(14)) Else
      If Code = '15' Then OutStr(Ansi_Color(15)) Else
      If Code = '16' Then OutStr(Ansi_Color(16)) Else
      If Code = '17' Then OutStr(Ansi_Color(17)) Else
      If Code = '18' Then OutStr(Ansi_Color(18)) Else
      If Code = '19' Then OutStr(Ansi_Color(19)) Else
      If Code = '20' Then OutStr(Ansi_Color(20)) Else
      If Code = '21' Then OutStr(Ansi_Color(21)) Else
      If Code = '22' Then OutStr(Ansi_Color(22)) Else
      If Code = '23' Then OutStr(Ansi_Color(23)) Else
      Begin
        Terminal.Process('|');
        Dec (A, 2);
        Continue;
      End;
    End Else
      Terminal.Process(Ch);
  End;

  Close (dFile);

  Terminal.Free;
  Screen.Free;
End.

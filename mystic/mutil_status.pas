Unit MUTIL_Status;

{$I M_OPS.PAS}

Interface

Type
  TStatusBar = Class
    LastPercent  : Byte;
    LinePosition : Byte;

    Constructor Create (LinePos: Byte);
    Destructor  Destroy; Override;

    Procedure   Reset;
    Procedure   Update (Part, Whole: LongInt);
  End;

  TProcessResult = (rDONE, rWARN, rWORKING, rFATAL);

Procedure ProcessName   (Str: String; Start: Boolean);
Procedure ProcessStatus (Str: String);
Procedure ProcessResult (Res: TProcessResult; Done: Boolean);

Implementation

Uses
  m_Strings,
  mutil_Common;

Procedure ProcessName (Str: String; Start: Boolean);
Begin
  Console.WriteXYPipe (5, Console.CursorY, 7, 26, Str);

  If Start Then Begin
    Inc (ProcessPos);

    BarOne.Reset;
  End;
End;

Procedure ProcessStatus (Str: String);
Begin
  Console.WriteXYPipe (33, Console.CursorY, 7, 31, Str);
End;

Procedure ProcessResult (Res: TProcessResult; Done: Boolean);
Begin
  Case Res of
    rDONE    : Console.WriteXYPipe(66, Console.CursorY, 10, 11, 'DONE');
    rWARN    : Console.WriteXYPipe(66, Console.CursorY, 12, 11, 'WARNING');
    rWORKING : Console.WriteXYPipe(66, Console.CursorY, 15, 11, 'WORKING');
    rFATAL   : Console.WriteXYPipe(66, Console.CursorY, 12, 11, 'FATAL');
  End;

  If Done Then Begin
    Console.WriteLine('');

    BarOne.Update (100, 100);
    BarAll.Update (ProcessPos, ProcessTotal);
  End;
End;

Procedure TStatusBar.Reset;
Begin
  Console.WriteXY (24, LinePosition,     8, strRep(#176, 50));
  Console.WriteXY (24, LinePosition + 1, 8, strRep(#176, 50));

  Console.WriteXY (75, LinePosition + 1, 7, '0  ');

  LastPercent := 0;
End;

Procedure TStatusBar.Update (Part, Whole: LongInt);
Var
  Percent : Byte;
  PerStr  : String;
Begin
  Percent := Round(Part / Whole * 100);

  If Percent <> LastPercent Then Begin
    LastPercent := Percent;

    If Percent >= 2 Then Begin
      PerStr := strRep(' ', (Percent DIV 2) - 1) + #222;

      Console.WriteXY (24, LinePosition,     25, PerStr);
      Console.WriteXY (24, LinePosition + 1, 25, PerStr);
    End;

    Console.WriteXY (75, LinePosition + 1,  15, strPadR(strI2S(Percent), 3, ' '));
  End;
End;

Constructor TStatusBar.Create (LinePos: Byte);
Begin
  Inherited Create;

  LinePosition := LinePos;

  Reset;
End;

Destructor TStatusBar.Destroy;
Begin
  Inherited Destroy;
End;

End.

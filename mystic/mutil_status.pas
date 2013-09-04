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
Procedure ProcessStatus (Str: String; Last: Boolean);
Procedure ProcessResult (Res: TProcessResult; Done: Boolean);

Implementation

Uses
  m_Strings,
  BBS_DataBase,
  mUtil_Common;

Procedure ProcessName (Str: String; Start: Boolean);
Begin
  Console.WriteXYPipe (5, Console.CursorY, 7, 26, Str);

  If Start Then Begin
    Inc (ProcessPos);

    BarOne.Reset;

    Console.WriteXY (71, 10, 8,  strPadL('(' + strI2S(ProcessPos) + '/' + strI2S(ProcessTotal) + ')', 7, ' '));

    Log (1, '+', 'Process: ' + Str);
  End;
End;

Procedure ProcessStatus (Str: String; Last: Boolean);
Begin
  Console.WriteXYPipe (33, Console.CursorY, 7, 31, Str);

  If Last Then
    Log (1, '+', 'Results: ' + strStripPipe(Str))
  Else
    Log (2, '+', '   ' + Str);
End;

Procedure ProcessResult (Res: TProcessResult; Done: Boolean);
Begin
  Case Res of
    rDONE    : Console.WriteXYPipe(66, Console.CursorY, 10, 11, 'DONE');
    rWARN    : Begin
                 Console.WriteXYPipe(66, Console.CursorY, 12, 11, 'WARNING');

                 Log (2, '!', 'Status: WARNING');
               End;
    rWORKING : Console.WriteXYPipe(66, Console.CursorY, 15, 11, 'WORKING');
    rFATAL   : Begin
                 Console.WriteXYPipe(66, Console.CursorY, 12, 11, 'FATAL');

                 Log (1, '!', 'Status: FATAL');
               End;
  End;

  If Done Then Begin
    If ProcessPos < ProcessTotal Then Console.WriteLine('');

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

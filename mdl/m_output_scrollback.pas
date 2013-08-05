Unit m_Output_ScrollBack;

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_Output;

Const
  MaxScrollBufferSize = 1000;

Type
  TConsoleScrollback = Class(TOutput)
    ScrollBuf : Array[1..MaxScrollBufferSize] of TConsoleLineRec;
    ScrollPos : SmallInt;
    Capture   : Boolean;

    Constructor Create (A: Boolean);
    Destructor  Destroy; Override;

    Procedure   ClearBuffer;
    Procedure   AddLine     (Line: Word);
    Function    IsBlankLine (Line: Word) : Boolean;
    Procedure   ClearScreen; Override;
    Procedure   ScrollWindow; Override;
  End;

Implementation

Constructor TConsoleScrollback.Create (A: Boolean);
Begin
  Inherited Create(A);

  ClearBuffer;

  Capture := False;
End;

Destructor TConsoleScrollback.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TConsoleScrollback.ClearBuffer;
Var
  Count1 : LongInt;
  Count2 : LongInt;
Begin
  ScrollPos := 0;

  For Count1 := 1 to MaxScrollBufferSize Do
    For Count2 := 1 to 80 Do Begin
      ScrollBuf[Count1][Count2].Attributes  := 7;
      ScrollBuf[Count1][Count2].UnicodeChar := ' ';
    End;
End;

Procedure TConsoleScrollback.AddLine (Line: Word);
Begin
  If ScrollPos = MaxScrollBufferSize Then Begin
    Move(ScrollBuf[2][1], ScrollBuf[1][1], SizeOf(TConsoleLineRec) * (MaxScrollBufferSize - 1));
    Dec(ScrollPos);
  End;

  Inc  (ScrollPos);
  Move (Buffer[Line][1], ScrollBuf[ScrollPos][1], SizeOf(TConsoleLineRec));
End;

Function TConsoleScrollback.IsBlankLine (Line: Word) : Boolean;
Var
  Count : LongInt;
Begin
  Result := True;

  For Count := 1 to 80 Do
//    If (Buffer[Line][Count].UnicodeChar <> #0) and ((Buffer[Line][Count].UnicodeChar <> ' ') and (Buffer[Line][Count].Attributes <> 7)) Then Begin
    If (Buffer[Line][Count].UnicodeChar <> #0) and ((Buffer[Line][Count].UnicodeChar <> ' ') or (Buffer[Line][Count].Attributes <> 7)) Then Begin
      Result := False;

      Exit;
    End;
End;

Procedure TConsoleScrollback.ClearScreen;
Var
  Line  : LongInt;
  Count : LongInt;
Begin
  If Capture Then Begin
    {$IFDEF WIN32}
      Line := Window.Bottom + 1;
    {$ELSE}
      Line := FWinBot;
    {$ENDIF}

    While Line > 0 Do Begin
      If Not IsBlankLine(Line) Then Break;

      Dec(Line);
    End;

    If Line <> 0 Then
      For Count := 1 to Line Do
        AddLine(Count);
  End;

  Inherited ClearScreen;
End;

Procedure TConsoleScrollBack.ScrollWindow;
Begin
  If Capture Then AddLine(1);

  Inherited ScrollWindow;
End;

End.

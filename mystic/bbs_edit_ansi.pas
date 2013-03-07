Unit bbs_Edit_Ansi;

{$I M_OPS.PAS}

// modes
//   viewer
//   msgedit
//   ansiedit

Interface

Uses
  bbs_MsgBase_ANSI;

Type
  TEditorANSI = Class
    Owner      : Pointer;
    ANSI       : TMsgBaseANSI;
    WinY1      : Byte;
    WinY2      : Byte;
    WinX1      : Byte;
    WinX2      : Byte;
    WinSize    : Byte;
    RowSize    : Byte;
    CurX       : Byte;
    CurY       : SmallInt;
    CurAttr    : Byte;
    CurLength  : Byte;
    TopLine    : LongInt;
    CurLine    : LongInt;
    InsertMode : Boolean;
    DrawMode   : Boolean;
    GlyphMode  : Boolean;
    WrapMode   : Boolean;
    ClearEOL   : Boolean;
    LastLine   : LongInt;

    Constructor Create (Var O: Pointer);
    Destructor  Destroy; Override;

    Function    IsAnsiLine    (Line: LongInt) : Boolean;
    Function    IsBlankLine   (Var Line; LineSize: Byte) : Boolean;
    Function    GetLineLength (Var Line; LineSize: Byte) : Byte;
    Function    GetWrapPos    (Var Line; LineSize, WrapPos: Byte) : Byte;
    Procedure   TrimLine      (Var Line; LineSize: Byte);
    Procedure   DeleteLine    (Line: LongInt);
    Procedure   InsertLine    (Line: LongInt);
    Function    GetLineText   (Line: Word) : String;
    Procedure   SetLineText   (Line: LongInt; Str: String);
    Procedure   FindLastLine;
    Procedure   Reformat;
    Procedure   LocateCursor;
    Procedure   ReDrawTemplate;
    Procedure   DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
    Procedure   ScrollUp;
    Procedure   ScrollDown;
    Function    LineUp : Boolean;
    Function    LineDown (Reset: Boolean) : Boolean;
    Procedure   PageUp;
    Procedure   PageDown;
    Procedure   DrawLine (Line: LongInt; XP, YP: Byte);
    Procedure   DoEnter;
    Procedure   DoBackSpace;
    Procedure   DoDelete;
    Procedure   DoChar (Ch: Char);
    Function    Edit : Boolean;
    Procedure   LoadANSI;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core,
  bbs_Common,
  bbs_Ansi_MenuBox;

Constructor TEditorANSI.Create (Var O: Pointer);
Begin
  Inherited Create;

  Owner      := O;
  ANSI       := TMsgBaseANSI.Create(NIL, False);
  WinX1      := 1;
  WinX2      := 79;
  WinY1      := 2;
  WinY2      := 23;
  WinSize    := WinY2 - WinY1 + 1;
  RowSize    := WinX2 - WinX1 + 1;
  CurX       := 1;
  CurY       := 1;
  CurLine    := 1;
  TopLine    := 1;
  CurAttr    := 7;
  InsertMode := True;
  DrawMode   := False;
  GlyphMode  := False;
  WrapMode   := True;
  ClearEOL   := RowSize >= 79;
  LastLine   := 1;
End;

Destructor TEditorANSI.Destroy;
Begin
  Inherited Destroy;

  ANSI.Free;
End;

Function TEditorANSI.GetLineText (Line: Word) : String;
Var
  Count : Word;
Begin
  Result := '';

  For Count := 1 to GetLineLength(ANSI.Data[Line], RowSize) Do
    Result := Result + ANSI.Data[Line][Count].Ch;
End;

Procedure TEditorANSI.SetLineText (Line: LongInt; Str: String);
Var
  Count : Byte;
Begin
  FillChar (ANSI.Data[Line], SizeOf(ANSI.Data[Line]), 0);

  For Count := 1 to Length(Str) Do Begin
    ANSI.Data[Line][Count].Ch   := Str[Count];
    ANSI.Data[Line][Count].Attr := CurAttr;
  End;
End;

Procedure TEditorANSI.FindLastLine;
Var
  Count : LongInt;
Begin
  LastLine := mysMaxMsgLines;

  While (LastLine > 1) And IsBlankLine(ANSI.Data[LastLine], 80) Do
    Dec(LastLine);
End;

Function TEditorANSI.IsAnsiLine (Line: LongInt) : Boolean;
Var
  Count : Byte;
Begin
  Result := False;

  If GetLineLength(ANSI.Data[Line], 80) >= Rowsize Then Begin
    Result := True;

    Exit;
  End;

  For Count := 1 to 80 Do
    If (Ord(ANSI.Data[Line][Count].Ch) < 32) or (Ord(ANSI.Data[Line][Count].Ch) > 128) Then Begin
      Result := True;

      Exit;
    End;
End;

Function TEditorANSI.IsBlankLine (Var Line; LineSize: Byte) : Boolean;
Var
  EndPos : Byte;
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  EndPos := LineSize;

  While (EndPos > 0) and (Data[EndPos].Ch = #0) Do
    Dec (EndPos);

  Result := EndPos = 0;
End;

Procedure TEditorANSI.TrimLine (Var Line; LineSize: Byte);
Var
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
  EndPos : Byte;
Begin
  EndPos := 1;

  While (EndPos <= LineSize) and (Data[1].Ch = ' ') Do Begin
    Move (Data[2], Data[1], SizeOf(RecAnsiBufferChar) * (LineSize - 1));

    Data[LineSize].Ch := #0;

    Inc (EndPos);
  End;

  EndPos := LineSize;

  While (EndPos > 0) and ((Data[EndPos].Ch = ' ') or (Data[EndPos].Ch = #0)) Do Begin
    Data[EndPos].Ch := #0;

    Dec (EndPos);
  End;
End;

Procedure TEditorANSI.DeleteLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := Line to mysMaxMsgLines - 1 Do
    ANSI.Data[Count] := ANSI.Data[Count + 1];

  FillChar (ANSI.Data[mysMaxMsgLines], SizeOf(RecAnsiBufferLine), #0);

  If LastLine > 1 Then Dec(LastLine);
End;

Procedure TEditorANSI.InsertLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := mysMaxMsgLines DownTo Line + 1 Do
    ANSI.Data[Count] := ANSI.Data[Count - 1];

  FillChar(ANSI.Data[Line], SizeOf(RecAnsiBufferLine), #0);

  If LastLine < mysMaxMsgLines Then Inc(LastLine);
End;

Function TEditorANSI.GetWrapPos (Var Line; LineSize: Byte; WrapPos: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  If GetLineLength(Line, LineSize) < WrapPos Then Begin
    Result := 0;

    Exit;
  End;

  Result := LineSize;

  While (Result > 0) and ((Data[Result].Ch <> ' ') or (Result > WrapPos)) Do
    Dec (Result);
End;

Function TEditorANSI.GetLineLength (Var Line; LineSize: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  Result := LineSize;

  While (Result > 0) and (Data[Result].Ch = #0) Do
    Dec (Result);
End;

Procedure TEditorANSI.Reformat;
Var
  WrapData  : Array[1..255] of RecAnsiBufferChar;
  TempStr   : Array[1..255] of RecAnsiBufferChar;
  NewLine   : Array[1..255] of RecAnsiBufferChar;
  Count     : LongInt;
  LineSize  : Byte;
  StartY    : Byte;
  StartLine : LongInt;
  EndLine   : LongInt;
  First     : Boolean = True;

  Procedure Update;
  Var
    NewY : LongInt;
  Begin
    NewY := StartY + EndLine - StartLine + 1;

    If NewY > WinSize Then NewY := WinSize;

    If CurY > WinSize Then
      ScrollDown
    Else
      DrawPage (StartY, NewY, True);
  End;

Begin
  FillChar (WrapData, SizeOf(WrapData), #0);

  Count     := CurLine;
  StartY    := CurY;
  StartLine := Count;

  While Count <= mysMaxMsgLines Do Begin
    If Count > LastLine Then LastLine := Count;

    FillChar (TempStr, SizeOf(TempStr), #0);
    Move     (Ansi.Data[Count], TempStr, SizeOf(Ansi.Data[Count]));

    If Not IsBlankLine(WrapData, 255) Then Begin
      If IsBlankLine(TempStr, 255) Then Begin
        If Count < LastLine Then Begin
          InsertLine(Count);
          EndLine := mysMaxMsgLines;
        End Else
          EndLine := Count;

        Move (WrapData, ANSI.Data[Count], SizeOf(Ansi.Data[Count]));

        Update;

        Exit;
      End;

      FillChar (NewLine, SizeOf(NewLine), #0);

      LineSize := GetLineLength(WrapData, 255);

      Move (WrapData, NewLine, LineSize * SizeOf(RecAnsiBufferChar));

      NewLine[LineSize + 1].Ch   := ' ';
      NewLine[LineSize + 1].Attr := WrapData[LineSize].Attr;

      Move (TempStr, NewLine[LineSize + 2], GetLineLength(TempStr, 255) * SizeOf(RecAnsiBufferChar));
      Move (NewLine, TempStr, SizeOf(NewLine));
    End;

    FillChar (WrapData, SizeOf(WrapData), #0);

    LineSize := GetWrapPos(TempStr, 255, RowSize);

    If LineSize > 0 Then Begin
      Move     (TempStr[LineSize], WrapData, (GetLineLength(TempStr, 255) - LineSize + 1) * SizeOf(RecAnsiBufferChar));
      FillChar (TempStr[LineSize], (255 - LineSize) * SizeOf(RecAnsiBufferChar), #0);

      TrimLine (WrapData, 255);

      If First Then Begin
        If CurX > LineSize Then Begin
          CurX := CurX - LineSize;

          Inc (CurY);
          Inc (CurLine);
        End;

        First := False;
      End;
    End;

    FillChar (ANSI.Data[Count], SizeOf(ANSI.Data[Count]), #0);
    Move     (TempStr, ANSI.Data[Count], RowSize * SizeOf(RecAnsiBufferChar));

    If LineSize = 0 Then Begin
      If First Then Begin
        CurX := 1;

        Inc (CurLine);
        Inc (CurY);

        If CurLine > LastLine Then LastLine := CurLine;

        EndLine := Count + 1;
      End Else
        EndLine := Count;

      Update;

      Exit;
    End;

    Inc (Count);
  End;

//  Update;
End;

Procedure TEditorANSI.ReDrawTemplate;
// temp stuff to be replaced by real template
Var
  B : TAnsiMenuBox;
Begin
  TBBSCore(Owner).io.AllowArrow := True;

  TBBSCore(Owner).io.AnsiColor(7);
  TBBSCore(Owner).io.AnsiClear;

(*
  B := TAnsiMenuBox.Create;

  B.FrameType := 1;

  B.Open (5, 2, 75, 23);
  B.Free;

  WinX1    := 6;
  WinX2    := 74;
  WinY1    := 3;
  WinY2    := 22;
*)

  WinX1    := 1;
  WinX2    := 79;
  WinY1    := 2;
  WinY2    := 23;

  WinSize  := WinY2 - WinY1 + 1;
  RowSize  := WinX2 - WinX1 + 1;
  CurX     := 1;
  CurY     := 1;
  ClearEOL := RowSize >= 79;

  //LoadANSI;
  FindLastLine;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.LocateCursor;
Begin
  CurLength := GetLineLength(ANSI.Data[CurLine], RowSize);

  If CurX < 1         Then CurX := 1;
  If CurX > CurLength Then CurX := CurLength + 1;
  If CurY < 1         Then CurY := 1;

  While TopLine + CurY - 1 > LastLine Do
    Dec (CurY);

  If Not DrawMode Then Begin
    If (CurX > 1) and (CurX = CurLength + 1) Then
      CurAttr := ANSI.Data[CurLine][CurX - 1].Attr
    Else
      CurAttr := ANSI.Data[CurLine][CurX].Attr;

    If CurAttr = 0 Then CurAttr := 7;
  End;

  With TBBSCore(Owner).io Do Begin

    //AnsiGotoXY (1, 1);
    //BufAddStr  ('X:' + strI2S(CurX) + ' Y:' + strI2S(CurY) + ' CL:' + strI2S(CurLine) + ' TL:' + strI2S(TopLine) + ' Last:' + strI2S(LastLine) + ' Len:' + strI2S(GetLineLength(ANSI.Data[CurLine], 80)) + ' Row:' + strI2S(RowSize) + '       ');

    AnsiGotoXY (WinX1 + CurX - 1, WinY1 + CurY - 1);
    AnsiColor  (CurAttr);

    BufFlush;
  End;
End;

Procedure TEditorANSI.DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
Var
  CountY : LongInt;
  CountX : Byte;
Begin
  For CountY := StartY to EndY Do Begin
    If TopLine + CountY - 1 > LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (7);

      If ClearEOL Then
        TBBSCore(Owner).io.AnsiClrEOL
      Else
        TBBSCore(Owner).io.BufAddStr (strRep(' ', RowSize));
    End Else
    If TopLine + CountY - 1 = LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (12);
      TBBSCore(Owner).io.BufAddStr  (strPadC('-----END-----', RowSize, ' '));

      If ExitEOF Then Break;
    End Else
      DrawLine (TopLine + CountY - 1, 1, CountY);
  End;
End;

Procedure TEditorANSI.ScrollUp;
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine - (WinSize DIV 2) + 1;

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.ScrollDown;
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine + (WinSize DIV 2) + 1;

  While NewTop >= mysMaxMsgLines Do
    Dec (NewTop, 2);

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Function TEditorANSI.LineUp : Boolean;
Begin
  Result := False;

  If CurLine = 1 Then Exit;

  Dec (CurLine);
  Dec (CurY);

  If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY < 1 Then Begin
    ScrollUp;

    Result := True;
  End;
End;

Function TEditorANSI.LineDown (Reset: Boolean) : Boolean;
Begin
  Result := False;

  If CurLine >= mysMaxMsgLines Then Exit;

  Inc (CurLine);
  Inc (CurY);

  If Reset Then CurX := 1;

  If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY > WinSize Then Begin
    Result := True;

    ScrollDown;
  End;
End;
(*
Procedure TEditorANSI.DrawLine (Line: LongInt; XP, YP: Byte);
Var
  Count : Byte;
Begin
  TBBSCore(Owner).io.AnsiGotoXY (WinX1 + XP - 1, WinY1 + YP - 1);

  For Count := XP to RowSize Do Begin
    If ANSI.Data[Line][Count].Ch = #0 Then Begin
      TBBSCore(Owner).io.AnsiColor  (7);
      TBBSCore(Owner).io.BufAddChar (' ');
    End Else Begin
      TBBSCore(Owner).io.AnsiColor  (ANSI.Data[Line][Count].Attr);
      TBBSCore(Owner).io.BufAddChar (ANSI.Data[Line][Count].Ch);
    End;
  End;
End;
*)

Procedure TEditorANSI.DrawLine (Line: LongInt; XP, YP: Byte);
Var
  Count   : Byte;
  LineLen : Byte;
Begin
  TBBSCore(Owner).io.AnsiGotoXY (WinX1 + XP - 1, WinY1 + YP - 1);

  LineLen := GetLineLength(ANSI.Data[Line], RowSize);

  For Count := XP to LineLen Do Begin
    If ANSI.Data[Line][Count].Ch = #0 Then Begin
      TBBSCore(Owner).io.AnsiColor  (7);
      TBBSCore(Owner).io.BufAddChar (' ');
    End Else Begin
      TBBSCore(Owner).io.AnsiColor  (ANSI.Data[Line][Count].Attr);
      TBBSCore(Owner).io.BufAddChar (ANSI.Data[Line][Count].Ch);
    End;
  End;

  If LineLen < RowSize Then
    If ClearEOL Then Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.AnsiClrEOL;
    End Else Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.BufAddStr (strRep(' ', LineLen - RowSize));
    End;
End;

Procedure TEditorANSI.DoDelete;
Var
  JoinLen : Byte;
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX <= CurLength Then Begin
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], (CurLength - 1) * SizeOf(RecAnsiBufferChar));

    ANSI.Data[CurLine][CurLength].Ch := #0;

    DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine < LastLine Then
    If (CurLength = 0) and (LastLine > 1) Then Begin
      DeleteLine (CurLine);
      DrawPage   (CurY, WinSize, False);
    End Else Begin
      JoinLen := GetLineLength(ANSI.Data[CurLine + 1], RowSize);

      If CurLength + JoinLen <= RowSize Then Begin
        Move       (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * JoinLen);
        DeleteLine (CurLine + 1);
        DrawPage   (CurY, WinSize, False); //optimize
      End Else Begin
        JoinPos := GetWrapPos(ANSI.Data[CurLine + 1], RowSize, RowSize - CurLength);

        If JoinPos > 0 Then Begin
          Move     (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));

          FillChar (JoinBuf, SizeOf(JoinBuf), #0);
          Move     (ANSI.Data[CurLine + 1][JoinPos + 1], JoinBuf, (JoinLen - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
          Move     (JoinBuf, ANSI.Data[CurLine + 1], RowSize * SizeOf(RecAnsiBufferChar));

          DrawPage (CurY, CurY + 1, True);
        End;
      End;

    End;
End;

Procedure TEditorANSI.DoBackSpace;
Var
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX > 1 Then Begin
    Dec  (CurX);
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

    ANSI.Data[CurLine][80].Ch := #0;

    If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then
      TBBSCore(Owner).io.OutBS(1, True)
    Else
      DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine > 1 Then Begin
    If GetLineLength(ANSI.Data[CurLine - 1], 80) + CurLength <= RowSize Then Begin
      CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

      Move (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * CurLength);

      DeleteLine (CurLine);

      If Not LineUp Then DrawPage (CurY, WinSize, False); //optimize
    End Else Begin
      JoinPos := GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize - GetLineLength(ANSI.Data[CurLine - 1], RowSize));

      If JoinPos > 0 Then Begin
        CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

        Move     (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));
        FillChar (JoinBuf, SizeOf(JoinBuf), #0);
        Move     (ANSI.Data[CurLine][JoinPos + 1], JoinBuf, (CurLength - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
        Move     (JoinBuf, ANSI.Data[CurLine], RowSize * SizeOf(RecAnsiBufferChar));

        If Not LineUp Then DrawPage (CurY, WinSize, False);
      End Else Begin
        LineUp;

        CurX := CurLength + 1;
      End;
    End;
  End;
End;

Procedure TEditorANSI.DoChar (Ch: Char);
Begin
  If InsertMode Then Begin
    Move (ANSI.Data[CurLine][CurX], ANSI.Data[CurLine][CurX + 1], SizeOf(RecAnsiBufferChar) * (CurLength - CurX + 1));

    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CurAttr;

    If CurLength < RowSize {-1} Then Begin
      If CurX <= CurLength Then
        DrawLine (CurLine, CurX, CurY)
      Else Begin
        TBBSCore(Owner).io.AnsiColor  (CurAttr);
        TBBSCore(Owner).io.BufAddChar (Ch);
      End;

      Inc (CurX);
    End Else Begin
      Inc (CurX);

      Reformat;
    End;
  End Else
  If CurX <= RowSize Then Begin
    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CurAttr;

    TBBSCore(Owner).io.AnsiColor  (CurAttr);
    TBBSCore(Owner).io.BufAddChar (Ch);

    Inc (CurX);
  End;
End;

Procedure TEditorANSI.PageUp;
Var
  NewTop : LongInt;
Begin
  If CurLine = 1 Then Exit;

  If TopLine = 1 Then Begin
    CurLine := 1;
    CurY    := 1;
    CurX    := 1;

    Exit;
  End;

  Dec (CurLine, WinSize);

  If CurLine < 1 Then Begin
    CurLine := 1;
    NewTop  := 1;
  End Else Begin
    NewTop := TopLine - WinSize;

    If NewTop < 1 Then NewTop := 1;
  End;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.PageDown;
Var
  NewTop : LongInt;
Begin
  If CurLine = LastLine Then Exit;

  If (LastLine > TopLine) And (LastLine <= TopLine + WinSize - 1) Then Begin
    CurLine := LastLine;
    CurY    := CurLine - TopLine + 1;
    CurX    := 1;

    Exit;
  End;

  Inc (CurLine, WinSize);

  If CurLine > LastLine Then CurLine := LastLine;

  NewTop := TopLine + WinSize;

  While NewTop >= LastLine - (WinSize DIV 2) Do
    Dec (NewTop);

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.LoadANSI;
Var
  F  : File;
  B  : Array[1..1024] of Char;
  BR : LongInt;
  A  : LongInt;
  C  : LongINt;
Begin
  Assign (F, '\code\mystic1\text\gj-glue1.ans');
  Reset  (F, 1);

  While Not Eof(F) Do Begin
    BlockRead (F, B, SizeOf(B), BR);

    If BR = 0 Then Break;

    ANSI.ProcessBuf(B, BR);
  End;

  Close(F);

  For A := 1 to ANSI.Lines Do
    For C := RowSize + 1 to 80 Do Begin
      ANSI.Data[A][C].Ch   := #0;
      ANSI.Data[A][C].Attr := 0;
    End;
End;

Procedure TEditorANSI.DoEnter;
Var
  TempLine : RecAnsiBufferLine;
Begin
  If InsertMode and IsBlankLine(ANSI.Data[mysMaxMsgLines], 80) Then Begin
    If CurX > CurLength Then Begin
      InsertLine (CurLine + 1);

      If Not LineDown(True) Then DrawPage(CurY, WinSize, True);
    End Else Begin
      TempLine := ANSI.Data[CurLine];

      InsertLine (CurLine + 1);

      FillChar (ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1), #0);
      Move     (TempLine[CurX], ANSI.Data[CurLine + 1][1], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

      If Not LineDown(True) Then
        DrawPage (CurY - 1, WinSize, True);
    End;
  End Else
    LineDown(True);
End;

Function TEditorANSI.Edit : Boolean;
Var
  Ch   : Char;
  Attr : Byte;
Begin
  Result := False;

  ReDrawTemplate;

  While Not TBBSCore(Owner).ShutDown Do Begin
    LocateCursor;

    Ch := TBBSCore(Owner).io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : CurX := 1;
        #79 : CurX := CurLength + 1;
        #72 : LineUp;
        #80 : If CurLine < LastLine Then LineDown(False);
        #75 : If CurX > 1 Then Dec(CurX);
        #77 : If CurX <= RowSize Then Inc(CurX);
        #73 : PageUp;
        #81 : PageDown;
        #83      : DoDelete;
      End;
    End Else
      Case Ch of
        ^V   : InsertMode := Not InsertMode; //update on screen
        ^Y   : Begin
                 DeleteLine (CurLine);

                 If CurLine > LastLine Then
                   InsertLine (CurLine);

                 DrawPage (CurY, WinSize, False);
               End;
        ^Z   : Break;
        #08  : DoBackSpace;
        #13  : DoEnter;
        #32..
        #254 : If (CurLength >= RowSize) and (GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize) = 0) Then Begin
                 If CurX = CurLength + 1 Then Begin
                   LineDown(True);
                 End;
               End Else
                 DoChar(Ch);
      End;
  End;

  Result := True;
End;

End.

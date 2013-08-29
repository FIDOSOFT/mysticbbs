Unit bbs_Ansi_Help;

{$I M_OPS.PAS}

Interface

Const
  mysMaxHelpTest      = 200;
  mysMaxHelpKeyLen    = 20;
  mysMaxHelpLineLinks = 10;

Type
  TLinkInfoRec = Record
    Key     : String[mysMaxHelpKeyLen];
    LinkPos : Byte;
    LinkLen : Byte;
  End;

  TLineInfoRec = Record
    Text  : String;
    Links : Byte;
    Link  : Array[1..mysMaxHelpLineLinks] of TLinkInfoRec
  End;

  TAnsiMenuHelp = Class
    HelpFile : Text;
    CurKey   : String[mysMaxHelpKeyLen];
    Text     : Array[1..mysMaxHelpTest] of TLineInfoRec;
    Lines    : Word;

    Constructor Create;
    Destructor  Destroy; Override;

    Function    ReadKeywordData : Boolean;
    Procedure   OpenHelp   (Str: String);
    Function    StripLinks (Str: String) : String;
  End;

Implementation

Uses
  m_Strings,
  BBS_Records,
  BBS_Ansi_MenuBox,
  BBS_Core,
  MPL_Execute;

Constructor TAnsiMenuHelp.Create;
Begin
  Inherited Create;
End;

Destructor TAnsiMenuHelp.Destroy;
Begin
  Inherited Destroy;
End;

Function TAnsiMenuHelp.StripLinks (Str: String) : String;
Var
  A : Byte;
  B : Byte;
Begin
  A := 255;

  While A > 0 Do Begin
    A := Pos('<link=', Str);

    If A > 0 Then Begin
      B := 1;
      While Str[A + 6 + B] <> '>' Do Inc(B);
      Delete (Str, A, 7 + B);

      A := Pos('</link>', Str);
      If A = 0 Then A := Length(Str);
      Delete (Str, A, 7);
    End;
  End;

  Result := Str;
End;

Function TAnsiMenuHelp.ReadKeywordData : Boolean;
Var
  Str    : String;
  Key    : String;
  Temp1  : Byte;
  Temp2  : Byte;
  Done   : Boolean;
  Buffer : Array[1..2048] of Char;
Begin
  SetTextBuf (HelpFile, Buffer);
  Reset      (HelpFile);

  Done := False;

  While Not Eof(HelpFile) And Not Done Do Begin
    ReadLn (HelpFile, Str);

    Temp1 := Pos('<keyword> ', Str);

    If Temp1 = 0 Then Continue;

    Key := Copy(Str, Temp1 + 10, Length(Str));

    If Key <> CurKey Then Continue;

    Lines := 0;

    While Not Eof(HelpFile) Do Begin
      ReadLn (HelpFile, Str);

      If Pos('<end>', Str) > 0 Then Begin
        Done := True;
        Break;
      End;

      Inc (Lines);

      Text[Lines].Text  := StripLinks(Str);
      Text[Lines].Links := 0;
      Str               := strStripPipe(Str);

      Repeat
        Temp1 := Pos('<link=', Str);

        If Temp1 = 0 Then Break;

        Inc (Text[Lines].Links);

        Text[Lines].Link[Text[Lines].Links].LinkPos := Temp1;

        Temp2 := 0;
        Key   := '';

        While Str[Temp1 + 6 + Temp2] <> '>' Do Begin
          Key := Key + Str[Temp1 + 6 + Temp2];
          Inc (Temp2);
        End;

        Delete (Str, Temp1, 7 + Temp2);
        Temp2 := Pos('</link>', Str);
        Delete (Str, Temp2, 7);

        Text[Lines].Link[Text[Lines].Links].LinkLen := Temp2 - Temp1;
        Text[Lines].Link[Text[Lines].Links].Key     := Key;
      Until False;
    End;
  End;

  Close (HelpFile);

  Result := Done And (Lines > 0);
End;

Procedure TAnsiMenuHelp.OpenHelp (Str: String);
Const
  WinX1 : Byte = 2;
  WinY1 : Byte = 2;
  WinX2 : Byte = 78;
  WinY2 : Byte = 22;
Var
  FN       : String;
  Template : String[20];
  Keyword  : String;
  TopPage  : Integer;
  CurLine  : Integer;
  CurLPos  : Byte = 1;
  WinSize  : Integer;
  LastPos  : Byte;
  LastKey  : Array[1..10] of String[mysMaxHelpKeyLen];

  Procedure LinkOFF (LineNum: Word; YPos, LPos: Byte);
  Var
    S : String;
  Begin
    If Text[LineNum].Links = 0 Then Exit;

    With Text[LineNum] Do
      S := Copy(strStripPipe(Text), Link[LPos].LinkPos, Link[LPos].LinkLen);

    WriteXY (WinX1 + Text[LineNum].Link[LPos].LinkPos - 1, YPos, 9, S);
  End;

  Procedure DrawPage;
  Var
    Count1 : Byte;
    Count2 : Byte;
  Begin
    For Count1 := 1 to WinSize Do Begin
      If TopPage + Count1 - 1 <= Lines Then Begin
        WriteXYPipe (WinX1, Count1 + WinY1 - 1, 7, WinX2 - WinX1 + 1, Text[TopPage + Count1 - 1].Text);

        For Count2 := 1 to Text[TopPage + Count1 - 1].Links Do
          LinkOFF (TopPage + Count1 - 1, Count1 + WinY1 - 1, Count2);
      End Else
        WriteXYPipe (WinX1, Count1 + WinY1 - 1, 7, WinX2 - WinX1 + 1, '');
    End;
  End;

  Procedure LinkON;
  Var
    S : String;
  Begin
    With Text[TopPage + CurLine - 1] Do
      S := Copy(strStripPipe(Text), Link[CurLPos].LinkPos, Link[CurLPos].LinkLen);

    WriteXY (WinX1 + Text[TopPage + CurLine - 1].Link[CurLPos].LinkPos - 1, WinY1 + CurLine - 1, 31, S);

    Session.io.AnsiGotoXY (WinX1 + Text[TopPage + CurLine - 1].Link[CurLPos].LinkPos - 1, WinY1 + CurLine - 1);
  End;

  Procedure UpdateCursor;
  Begin
    If Text[TopPage + CurLine - 1].Links > 0 Then Begin
      If CurLPos > Text[TopPage + CurLine - 1].Links Then CurLPos := Text[TopPage + CurLine - 1].Links;
      If CurLPos < 1 Then CurLPos := 1;

      LinkON;
    End Else Begin
      CurLPos := 1;

      Session.io.AnsiGotoXY (WinX1, WinY1 + CurLine - 1);
    End;
  End;

  Procedure PageDown;
  Begin
    If Lines > WinSize Then Begin
      If TopPage + WinSize <= Lines - WinSize Then Begin
        Inc (TopPage, WinSize);
      End Else Begin
        TopPage := Lines - WinSize + 1;
        CurLine := WinSize;
      End;
    End Else
      CurLine := Lines;
  End;

  Procedure ShowTemplate;
  Begin
    Session.io.OutFile(Template, False, 0);

    WinX1 := Session.io.ScreenInfo[1].X;
    WinY1 := Session.io.ScreenInfo[1].Y;
    WinX2 := Session.io.ScreenInfo[2].X;
    WinY2 := Session.io.SCreenInfo[2].Y;
  End;

  Procedure ExecuteMenuCommands;
  Var
    Key  : String;
    Temp : String;
    Cmd  : String[2];
    Data : String;
  Begin
    Session.io.AnsiColor(7);

    Key := Text[TopPage + CurLine - 1].Link[CurLPos].Key;

    Repeat
      Delete (Key, 1, 1);

      Temp := strWordGet(1, Key, ']');
      Cmd  := strWordGet(1, Temp, ';');
      Data := strWordGet(2, Temp, ';');

      Delete (Key, 1, Length(Temp) + 1);

      Session.Menu.ExecuteCommand (Cmd, Data);
    Until Key = '';

    ShowTemplate;
  End;

Var
  OK    : Boolean;
  Count : Byte;
  Ch    : Char;
Begin
  FillChar(LastKey, SizeOf(LastKey), 0);

  FN       := strWordGet(1, Str, ';');
  Template := strWordGet(2, Str, ';');
  Keyword  := strWordGet(3, Str, ';');

  If Pos(PathChar, FN) = 0 Then FN := Session.Theme.TextPath + FN;

  Assign (HelpFile, FN + '.hlp');
  {$I-} Reset (HelpFile); {$I+}

  If IoResult <> 0 Then Exit;

  Close  (HelpFile);

  ShowTemplate;

  TopPage := 1;
  CurLine := 1;
  LastPos := 0;
  WinSize := WinY2 - WinY1 + 1;
  CurKey  := Keyword;
  OK      := ReadKeywordData;

  If Not OK and (CurKey <> 'INDEX') Then Begin
    CurKey := 'INDEX';
    OK     := ReadKeywordData;
  End;

  If Not OK Then Exit;

  While OK Do Begin
    TopPage := 1;
    CurLine := 1;

    DrawPage;

    For Count := 1 to WinSize Do
      If Text[Count].Links > 0 Then Begin
        CurLine := Count;
        Break;
      End;

    UpdateCursor;

    Session.io.AllowArrow := True;

    Repeat
      Ch := Session.io.GetKey;

      If Session.io.IsArrow Then Begin
        Case Ch of
          #71 : If (TopPage > 1) or (CurLine > 1) Then Begin
                  TopPage := 1;
                  CurLine := 1;

                  DrawPage;
                  UpdateCursor;
                End;
          #72 : Begin
                  If (CurLine = 1) and (TopPage > 1) Then Begin
                    Dec (TopPage);

                    DrawPage;

                    UpdateCursor;
                  End Else If CurLine > 1 Then Begin
                    LinkOFF(TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                    Dec (CurLine);

                    UpdateCursor;
                  End;
                End;
          #73 : Begin
                  If TopPage - WinSize > 0 Then Begin
                    Dec (TopPage, WinSize);

                    DrawPage;
                    UpdateCursor;
                  End Else If CurLine > 1 Then Begin
                    TopPage := 1;
                    CurLine := 1;

                    DrawPage;
                    UpdateCursor;
                  End;
                End;
          #75 : If (CurLPos > 1) and (Text[TopPage + CurLine - 1].Links > 0) Then Begin
                  LinkOFF(TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                  Dec(CurLPos);

                  LinkON;
                End;
          #77 : If CurLPos < Text[TopPage + CurLine - 1].Links Then Begin
                  LinkOFF(TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                  Inc(CurLPos);

                  LinkON;
                End;
          #79 : If TopPage + WinSize <= Lines Then Begin
                  Repeat
                    PageDown;
                  Until TopPage >= Lines - WinSize - 1;

                  DrawPage;
                  UpdateCursor;
                End Else
                If TopPage + CurLine <= Lines Then Begin
                  LinkOFF (TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                  CurLine := Lines - TopPage + 1;

                  UpdateCursor;
                End;
          #80 : Begin
                  If (CurLine = WinSize) and (TopPage + WinSize <= Lines) Then Begin
                    Inc(TopPage);

                    DrawPage;

                    UpdateCursor;
                  End Else
                  If (CurLine < WinSize) And (TopPage + CurLine <= Lines) Then Begin
                    LinkOFF(TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                    Inc(CurLine);

                    UpdateCursor;
                  End;
                End;
          #81 : If TopPage + WinSize <= Lines Then Begin
                  PageDown;

                  DrawPage;

                  UpdateCursor;
                End Else
                If TopPage + CurLine <= Lines Then Begin
                  LinkOFF (TopPage + CurLine - 1, WinY1 + CurLine - 1, CurLPos);

                  CurLine := Lines - TopPage + 1;

                  UpdateCursor;
                End;

        End;
      End Else Begin
        Case Ch of
          #08 : Begin
                  If LastPos = 0 Then
                    CurKey := Keyword
                  Else Begin
                    CurKey := LastKey[LastPos];

                    Dec (LastPos);
                  End;

                  OK := ReadKeywordData;

                  If Not OK Then Begin
                    CurKey := 'INDEX';
                    OK     := ReadKeywordData;
                  End;

                  Break;
                End;
          #13 : If Text[TopPage + CurLine - 1].Links > 0 Then Begin
                  If Text[TopPage + CurLine - 1].Link[CurLPos].Key = '@PREV' Then Begin
                    If LastPos = 0 Then
                      CurKey := Keyword
                    Else Begin
                      CurKey := LastKey[LastPos];
                      Dec (LastPos);
                    End;
                  End Else Begin
                    Case Text[TopPage + CurLine - 1].Link[CurLPos].Key[1] of
                      '!' : Begin
                              Session.io.AnsiColor(7);

                              ExecuteMPL (NIL, Copy(Text[TopPage + CurLine - 1].Link[CurLPos].Key, 2, 255));

                              ShowTemplate;
                            End;
                      '[' : ExecuteMenuCommands;
                    Else
                      If LastPos < 10 Then
                        Inc (LastPos)
                      Else
                        For Count := 1 to 9 Do LastKey[Count] := LastKey[Count + 1];

                      LastKey[LastPos] := CurKey;

                      CurKey := Text[TopPage + CurLine - 1].Link[CurLPos].Key;
                    End;
                  End;

                  OK := ReadKeywordData;

                  If Not OK Then Begin
                    CurKey := 'INDEX';
                    OK     := ReadKeywordData;
                  End;

                  Break;
                End;
          #27 : Begin
                  OK := False;
                  Break;
                End;
        End;
      End;
    Until False;
  End;
End;

End.

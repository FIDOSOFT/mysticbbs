Unit bbs_Ansi_Help;

// leet online ansi help system (html-like with pipe colors too)
// ripped from genesis engine (my ansi editor) and slowly port into mystic

// 2. completely redo loading so text is stored in pointer of records...
//    we can allow larger help files.
// 4. needs to use ansi template
// 5. quickjump/sitemap option
// 6. add linking to OTHER .hlp files?
// 7. how to better integrate with the bbs?  execute MPL command? what else?
//
// needs to support lines longer than 255 characters too
//
// template, percentage bar, what to do with topic?
// export to text / download

{$I M_OPS.PAS}

Interface

Uses
  bbs_Ansi_MenuBox;

Const
  mysMaxHelpTest      = 200;
  mysMaxHelpKeyLen    = 20;
  mysMaxHelpLineLinks = 10;

Type
  TLineInfoRec = Record  // make into pointer
    Text  : String;  // make into pointer of string
    Links : Byte;
    Link  : Array[1..mysMaxHelpLineLinks] of Record  //make into pointer
              Key     : String[mysMaxHelpKeyLen];
              LinkPos : Byte;
              LinkLen : Byte;
            End;
  End;

  TAnsiMenuHelp = Class
    Box      : TAnsiMenuBox;
    HelpFile : Text;
    CurKey   : String[mysMaxHelpKeyLen];
    Text     : Array[1..mysMaxHelpTest] of TLineInfoRec;
    Lines    : Word;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   OpenHelp (X1, Y1, X2, Y2: Byte; FN, Keyword: String);
    Function    ReadKeywordData : Boolean;
    Function    StripLinks (Str: String) : String;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core;

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
      while Str[A + 6 + B] <> '>' Do Inc(B);
      Delete (Str, A, 7 + B);

      A := Pos('</link>', Str);
      If A = 0 Then A := Length(Str);
      Delete (Str, A, 7);
    End;
  End;

  Result := Str;
End;

Constructor TAnsiMenuHelp.Create;
Begin
  Inherited Create;
End;

Destructor TAnsiMenuHelp.Destroy;
Begin
  Inherited Destroy;
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

Procedure TAnsiMenuHelp.OpenHelp (X1, Y1, X2, Y2: Byte; FN, Keyword: String);
Var
  TopPage : Integer;
  CurLine : Integer;
  CurLPos : Byte;
  WinSize : Integer;
  LastPos : Byte;
  LastKey : Array[1..10] of String[mysMaxHelpKeyLen];

  Procedure LinkOFF (LineNum: Word; YPos, LPos: Byte);
  Var
    S : String;
  Begin
    If Text[LineNum].Links = 0 Then Exit;

    With Text[LineNum] Do
      S := Copy(strStripPipe(Text), Link[LPos].LinkPos, Link[LPos].LinkLen);

    WriteXY (X1 + Text[LineNum].Link[LPos].LinkPos, YPos, 9, S);
  End;

  Procedure DrawPage;
  Var
    Count1 : Byte;
    Count2 : Byte;
  Begin
    For Count1 := Y1 to WinSize Do Begin
      If TopPage + Count1 - Y1 <= Lines Then Begin
       WriteXYPipe (X1 + 1, (Count1 - Y1) + Y1 + 1, 7, X2 - X1 - 1, Text[TopPage + (Count1 - Y1)].Text);

       For Count2 := 1 to Text[TopPage + Count1 - 1].Links Do
         LinkOFF (TopPage + Count1 - 1, Count1 - Y1 + Y1 + 1, Count2);
      End Else
       WriteXYPipe (X1 + 1, (Count1 - Y1) + Y1 + 1, 7, X2 - X1 - 1, '');
    End;
  End;

  Procedure LinkON;
  Var
    S : String;
  Begin
    With Text[TopPage + CurLine - 1] Do
      S := Copy(strStripPipe(Text), Link[CurLPos].LinkPos, Link[CurLPos].LinkLen);

    WriteXY  (X1 + Text[TopPage + CurLine - 1].Link[CurLPos].LinkPos, Y1 + CurLine, 31, S);

    Session.io.AnsiGotoXY (X1 + Text[TopPage + CurLine - 1].Link[CurLPos].LinkPos, Y1 + CurLine);
  End;

  Procedure UpdateCursor;
  Begin
    If Text[TopPage + CurLine - 1].Links > 0 Then Begin
      If CurLPos > Text[TopPage + CurLine - 1].Links Then CurLPos := Text[TopPage + CurLine - 1].Links;
      If CurLPos < 1 Then CurLPos := 1;
      LinkON;
    End Else Begin
      CurLPos := 1;
      Session.io.AnsiGotoXY (X1 + 1, Y1 + CurLine);
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

Var
  OK    : Boolean;
  Count : Byte;
  Ch    : Char;
Begin
  Assign (HelpFile, FN);
  Reset  (HelpFile);

  If IoResult <> 0 Then Exit;

  Close  (HelpFile);

  TopPage := 1;
  CurLine := 1;
  LastPos := 0;
  WinSize := Y2 - Y1 - 1;
  CurKey  := Keyword;
  OK      := ReadKeywordData;

  If Not OK and (CurKey <> 'INDEX') Then Begin
    CurKey := 'INDEX';
    OK := ReadKeywordData;
  End;

  If Not OK Then Exit;

  Box := TAnsiMenuBox.Create;

  Box.Shadow    := False;
  Box.FrameType := 1;
  Box.BoxAttr   := 8;
  Box.BoxAttr2  := 8;
  Box.HeadAttr  := 15;
  Box.Box3D     := False;
  Box.Header    := ' Section : ' + CurKey + ' ';

  Box.Open (X1, Y1, X2, Y2);

  DrawPage;
  UpdateCursor;

  While OK Do Begin
//    Box.UpdateHeader (' Section : ' + CurKey + ' ');

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
                    LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
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
                  LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
                  Dec(CurLPos);
                  LinkON;
                End;
          #77 : If CurLPos < Text[TopPage + CurLine - 1].Links Then Begin
                  LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
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
                  LinkOFF (TopPage + CurLine - 1, CurLine + 1, CurLPos);
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
                    LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
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
                  LinkOFF (TopPage + CurLine - 1, CurLine + 1, CurLPos);
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
                    If LastPos < 10 Then
                      Inc (LastPos)
                    Else
                      For Count := 1 to 9 Do LastKey[Count] := LastKey[Count + 1];

                    LastKey[LastPos] := CurKey;

                    CurKey := Text[TopPage + CurLine - 1].Link[CurLPos].Key;
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

  Box.Close;
  Box.Free;
End;

End.

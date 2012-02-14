Unit bbs_Ansi_Help;

// very old online-help class from Genesis Engine (my ansi editor)
// updated to compile with mystic but needs a lot of touch ups.
// idea is to template this out and have .hlp files that can be used in
// all help areas if they exist instead of just a display file.
// and of course a menu command to active this with ANY hlp files so sysops
// can use it however they'd like
//
// hlp files are text files which can have embedded pipe color codes in them
// and also have keywords and the ability to link around them, sort of like
// a very basic HTML system for BBS with an ansi interface to scroll around
// and follow links.

// first port to class system from object -- DONE
// second make sure it even works --- DONE (buggy)
// then:

// 1. change "<a href=" to "<link="
// 2. completely redo loading so text is stored in pointer of records...
//    we can allow larger help files.
// 3. text file read needs to be buffered
// 4. needs to use ansi template
// 5. quickjump/sitemap option
// 6. add linking to OTHER .hlp files?
// 7. how to better integrate with the bbs?  execute MPL command? what else?
//
// after this is done... port the ansi editor itself for online ansi editing
// goodness!  and also make file manager for sysops
// needs to support lines better than 255 characters too

{$I M_OPS.PAS}

Interface

Uses
  bbs_Ansi_MenuBox;

Const
  geMaxHelpTest      = 200;
  geMaxHelpKeyLen    = 20;
  geMaxHelpLineLinks = 10;

Type
  TLineInfoRec = Record  // make into pointer
    Text  : String;  // make into pointer of string
    Links : Byte;
    Link  : Array[1..geMaxHelpLineLinks] of Record  //make into pointer
              Key     : String[geMaxHelpKeyLen];
              LinkPos : Byte;
              LinkLen : Byte;
            End;
  End;

  TAnsiMenuHelp = Class
    Box      : TAnsiMenuBox;
    HelpFile : Text;
    CurKey   : String[geMaxHelpKeyLen];
    Text     : Array[1..geMaxHelpTest] of TLineInfoRec;
    Lines    : Word;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   OpenHelp (X1, Y1, X2, Y2: Byte; FN, Keyword: String);
    Function    ReadKeywordData : Boolean;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core;

function striplinks (s:string):string;
var
  a : byte;
  B : byte;
begin
  a := 255;

  while a > 0 do begin
    a := pos('<a href=', s);
    if a > 0 then begin
      b := 1;
      while s[a+8+b] <> '>' do inc(b);
      Delete (S, a, 9 + b);
      a := Pos('</a>', S);
      If a = 0 Then a := Length(S);
      Delete (S, a, 4);
    end;
  end;

  striplinks := s;
end;

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
        Temp1 := Pos('<a href=', Str);

        If Temp1 = 0 Then Break;

        Inc (Text[Lines].Links);

        Text[Lines].Link[Text[Lines].Links].LinkPos := Temp1;

        Temp2 := 0;
        Key   := '';

        While Str[Temp1 + 8 + Temp2] <> '>' Do Begin
          Key := Key + Str[Temp1 + 8 + Temp2];
          Inc(Temp2);
        End;

        Delete (Str, Temp1, 9 + Temp2);
        Temp2 := Pos('</a>', Str);
        Delete (Str, Temp2, 4);

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
  LastKey : Array[1..10] of String[geMaxHelpKeyLen];

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
        Inc (CurLine, WinSize);
      End Else Begin
        TopPage := Lines - WinSize - 1;
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
                  End Else If CurLine > 1 Then Begin
                    LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
                    Dec (CurLine)
                  End;
                  UpdateCursor;
                End;
          #73 : Begin
                  If TopPage - WinSize > 0 Then Begin
                    Dec (TopPage, WinSize);
                    Dec (CurLine, WinSize);
                  End Else Begin
                    TopPage := 1;
                    CurLine := 1;
                  End;
                  DrawPage;
                  UpdateCursor;
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
          #79 : Begin
                  Repeat
                    PageDown;
                  Until TopPage >= Lines - WinSize - 1;
                  DrawPage;
                  UpdateCursor;
                End;
          #80 : Begin
                  If (CurLine = WinSize) and (TopPage + WinSize <= Lines) Then Begin
                    Inc(TopPage);
                    DrawPage;
                  End Else
                  If (CurLine < WinSize) And (TopPage + CurLine <= Lines) Then Begin
                    LinkOFF(TopPage + CurLine - 1, CurLine + 1, CurLPos);
                    Inc(CurLine);
                  End;
                  UpdateCursor;
                End;
          #81 : Begin
                  PageDown;
                  DrawPage;
                  UpdateCursor;
                End;
        End;
      End Else Begin
        Case Ch of
          #13 : If Text[CurLine].Links > 0 Then Begin
                  If Text[CurLine].Link[CurLPos].Key = '@PREV' Then Begin
                    If LastPos = 0 Then
                      CurKey := 'INDEX'
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
                    CurKey := Text[CurLine].Link[CurLPos].Key;
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

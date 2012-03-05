Unit bbs_cfg_Theme;

{$I M_OPS.PAS}

Interface

Function Configuration_ThemeEditor (Select: Boolean) : String;

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_Common,
  bbs_Cfg_Common;

Procedure EditBars (Var Theme: RecTheme);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09Theme Edit|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Open (12, 5, 69, 16);

  VerticalLine (30, 7, 14);
  VerticalLine (59, 7, 10);

  Form.AddBar ('M', ' Message Reader',  14,  7, 32,  7, 16, @Theme.MsgBar, Topic);
  Form.AddBar ('R', ' Reader Index',    16,  8, 32,  8, 14, @Theme.IndexBar, Topic);
  Form.AddBar ('E', ' Message Area',    16,  9, 32,  9, 14, @Theme.MAreaBar, Topic);
  Form.AddBar ('S', ' Message Group',   15, 10, 32, 10, 15, @Theme.MGroupBar, Topic);
  Form.AddBar ('A', ' Message List',    16, 11, 32, 11, 14, @Theme.MAreaList, Topic);
  Form.AddBar ('G', ' Gallery',         21, 12, 32, 12,  9, @Theme.GalleryBar, Topic);
  Form.AddBar ('V', ' Voting',          22, 13, 32, 13,  8, @Theme.VotingBar, Topic);
  Form.AddBar ('F', ' File List',       19, 14, 32, 14, 11, @Theme.FileBar, Topic);

  Form.AddBar ('H', ' Help',            53,  7, 61,  7,  6, @Theme.HelpBar, Topic);
  Form.AddBar ('I', ' File Viewer',     46,  8, 61,  8, 13, @Theme.ViewerBar, TopiC);
  Form.AddBar ('L', ' File Area',       48,  9, 61,  9, 11, @Theme.FAreaBar, Topic);
  Form.AddBar ('O', ' File Group',      47, 10, 61, 10, 12, @Theme.FGroupBar, Topic);

  Repeat
    Case Form.Execute of
      #27 : Break;
    End;
  Until False;

  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure EditOptions (Var Theme: RecTheme);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
  Count : Byte;
Begin
  Topic := '|03(|09Theme Edit|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Open (5, 5, 75, 20);

  Box.Header := ' Theme Edit ';

  VerticalLine (28, 7, 16);
  VerticalLine (63, 7, 18);

  Form.AddBits ('U', ' Use Lightbar Yes/No',  7,  7, 30,  7, 21, ThmLightbarYN, @Theme.Flags, Topic);
  Form.AddChar ('P', ' Password Echo',       13,  8, 30,  8, 15, 32, 255, @Theme.EchoChar, Topic);
  Form.AddChar ('F', ' File Tag',            18,  9, 30,  9, 10, 32, 255, @Theme.TagChar, Topic);
  Form.AddChar ('N', ' New Message',         15, 10, 30, 10, 13, 32, 255, @Theme.NewMsgChar, Topic);
  Form.AddChar ('W', ' New Vote',            18, 11, 30, 11, 10, 32, 255, @Theme.NewVoteChar, Topic);
  Form.AddChar ('I', ' Input Field',         15, 12, 30, 12, 13, 32, 255, @Theme.FieldChar, Topic);
  Form.AddAttr ('E', ' Field Color 1',       13, 13, 30, 13, 15, @Theme.FieldColor1, Topic);
  Form.AddAttr ('L', ' Field Color 2',       13, 14, 30, 14, 15, @Theme.FieldColor2, Topic);
  Form.AddAttr ('H', ' File Highlight Lo',    9, 15, 30, 15, 19, @Theme.FileDescLo, Topic);
  Form.AddAttr ('G', ' File Highlight Hi',    9, 16, 30, 16, 19, @Theme.FileDescHi, Topic);

  For Count := 0 to 9 Do
    Form.AddAttr (strI2S(Count)[1], ' Theme Color #' + strI2S(Count), 47, 7 + Count,  65,  7 + Count, 16, @Theme.Colors[Count], Topic + 'Custom theme color');

  Form.AddAttr ('C', ' Line Chat #1', 49, 17, 65, 17, 14, @Theme.LineChat1, Topic + 'Line chat color 1');
  Form.AddAttr ('T', ' Line Chat #2', 49, 18, 65, 18, 14, @Theme.LineChat2, Topic + 'Line chat color 2');

  Repeat
    Case Form.Execute of
      #27 : Break;
    End;
  Until False;

  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure EditTheme (Var Theme: RecTheme);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09Theme Edit|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Open (5, 5, 75, 17);

  Box.Header := ' Theme Edit ';

  VerticalLine (23, 7, 15);

  Form.AddStr  ('F', ' File Name'      , 12,  7, 25,  7, 11, 20, 20, @Theme.FileName, Topic + 'Root theme filename');
  Form.AddStr  ('D', ' Description'    , 10,  8, 25,  8, 13, 30, 40, @Theme.Desc, Topic + 'Theme description');
  Form.AddPath ('T', ' Text Path'      , 12,  9, 25,  9, 11, 30, 80, @Theme.TextPath, Topic + 'Text path');
  Form.AddPath ('M', ' Menu Path'      , 12, 10, 25, 10, 11, 30, 80, @Theme.MenuPath, Topic + 'Menu path');
  Form.AddPath ('S', ' Script Path'    , 10, 11, 25, 11, 13, 30, 80, @Theme.ScriptPath, Topic + 'Script path');
  Form.AddPath ('T', ' Template Path'  ,  8, 12, 25, 12, 15, 30, 80, @Theme.TemplatePath, Topic + 'Template path');
  Form.AddBits ('F', ' Allow Fallback' ,  7, 13, 25, 13, 16, ThmFallback, @Theme.Flags, Topic + 'Allow fallback to default paths?');
  Form.AddBits ('C', ' Allow ASCII'    , 10, 14, 25, 14, 13, ThmAllowASCII, @Theme.Flags, Topic + 'Allow ASCII users to use this theme?');
  Form.AddBits ('N', ' Allow ANSI'     , 11, 15, 25, 15, 12, ThmAllowANSI, @Theme.Flags, Topic + 'Allow ANSI users to use this theme?');

  Form.AddNone ('1', ' 1: Prompts'     , 57,  7, 17, Topic + 'Edit prompts for this theme');
  Form.AddNone ('2', ' 2: Options'     , 57,  8, 17, Topic + 'Edit general options for this theme');
  Form.AddNone ('3', ' 3: Percent Bars', 57,  9, 17, Topic + 'Edit percentage bars used in this theme');

  Repeat
    Case Form.Execute of
      '2' : EditOptions(Theme);
      '3' : Begin
              Box.Hide;
              EditBars(Theme);
              Box.Show;
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;

  Form.Free;
  Box.Free;
End;

Function Configuration_ThemeEditor (Select: Boolean) : String;
Var
  Box       : TAnsiMenuBox;
  List      : TAnsiMenuList;
  ThemeFile : TBufFile;
  Theme     : RecTheme;
  Copied    : RecTheme;
  HasCopy   : Boolean = False;
Begin
  ThemeFile := TBufFile.Create(SizeOf(RecTheme));

  If Not ThemeFile.Open(Config.DataPath + 'theme.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(RecTheme)) Then Begin
    ThemeFile.Free;
    Exit;
  End;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Themes ';
  List.LoChars  := #13#27#47;
  List.NoWindow := True;

  Box.Open (8, 6, 73, 18);

  WriteXY (10,  8, 112, 'File Name             Description');
  WriteXY (10,  9, 112, strRep(#196, 62));
  WriteXY (10, 16, 112, strRep(#196, 62));
  WriteXY (29, 17, 112, cfgCommandList);

  Repeat
    List.Clear;

    ThemeFile.Reset;

    While Not ThemeFile.EOF Do Begin
      ThemeFile.Read(Theme);

      List.Add (strPadR(Theme.FileName, 20, ' ') + '  ' + Theme.Desc, 0);
    End;

    List.Add ('', 0);

    List.Open (8, 9, 73, 16);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(9, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : Begin
                      ThemeFile.RecordInsert(List.Picked);

                      FillChar(Theme, SizeOf(Theme), 0);

                      With Theme Do Begin
                        Flags        := ThmAllowANSI OR ThmAllowASCII OR ThmFallback OR ThmLightbarYN;
                        FileName     := 'new';
                        Desc         := FileName;
                        TextPath     := Config.TextPath;
                        MenuPath     := Config.MenuPath;
                        ScriptPath   := Config.ScriptPath;
                        TemplatePath := Config.TextPath;
                        Colors[0]    := 1;
                        Colors[1]    := 9;
                        Colors[2]    := 11;
                        Colors[3]    := 8;
                        Colors[4]    := 7;
                        Colors[5]    := 15;
                        Colors[6]    :=  8 + 1 * 16;
                        Colors[7]    :=  7 + 1 * 16;
                        Colors[8]    :=  9 + 1 * 16;
                        Colors[9]    := 15 + 1 * 16;
                        FieldColor1  := 15 + 1 * 16;
                        FieldColor2  :=  9 + 1 * 16;
                        FieldChar    := #176;
                        EchoChar     := '*';
                        TagChar      := '*';
                        NewVoteChar  := '*';
                        LineChat1    := 9;
                        Linechat2    := 11;
                        NewMsgChar   := '*';
                        QuoteColor   := 31;
                        FileDescHi   := 112;
                        FileDescLo   := 11;

                        VotingBar.BarLength := 10;
                        VotingBar.LoChar    := '°';
                        VotingBar.LoAttr    := 8;
                        VotingBar.HiChar    := #219;
                        VotingBar.HiAttr    := 25;
                        VotingBar.Format    := 0;
                        VotingBar.StartY    := 1;
                        VotingBar.StartX    := 79;

                        FileBar    := VotingBar;
                        MsgBar     := VotingBar;
                        GalleryBar := VotingBar;
                        HelpBar    := VotingBar;
                        ViewerBar  := VotingBar;
                        IndexBar   := VotingBar;
                        FAreaBar   := VotingBar;
                        FGroupBar  := VotingBar;
                        MAreaBar   := VotingBar;
                        MGroupBar  := VotingBar;
                        MAreaList  := VotingBar;
                      End;

                      ThemeFile.Write(Theme);
                    End;
              'D' : If List.Picked <> List.ListMax Then
                      If ShowMsgBox(1, 'Delete this entry?') Then
                        ThemeFile.RecordDelete (List.Picked);
              'C' : If List.Picked <> List.ListMax Then Begin
                      ThemeFile.Seek (List.Picked - 1);
                      ThemeFile.Read (Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      ThemeFile.RecordInsert (List.Picked);
                      ThemeFile.Write        (Copied);
                    End;

            End;
      #13 : If (List.ListMax > 0) And (List.Picked <> List.ListMax) Then
              If Select Then Begin
                ThemeFile.Seek (List.Picked - 1);
                ThemeFile.Read (Theme);

                Result := strStripB(Copy(List.List[List.Picked]^.Name, 1, 20), ' ');

                Break;
              End Else Begin
                Box.Hide;

                ThemeFile.Seek (List.Picked - 1);
                ThemeFile.Read (Theme);

                EditTheme (Theme);

                ThemeFile.Seek  (List.Picked - 1);
                ThemeFile.Write (Theme);

                Box.Show;
              End;
      #27 : Break;
    End;
  Until False;

  Box.Close;
  Box.Free;
  List.Free;
  ThemeFile.Free;
End;

End.

Uses
  m_Types,
  m_Output,
  m_Strings,
  m_FileIO,
  m_MenuInput,
  m_MenuBox,
  m_MenuForm,
  MCFG_Common;

Procedure CompileTheme;

  Procedure UpdateBar (Cur : Integer);
  Var
    Percent : Byte;
  Begin
    Percent := Round(Cur / mysMaxThemeText * 100 / 5);

    Console.WriteXY (34, 12, 113, strRep(#178, Percent) + strRep(#176, 20 - Percent) +
                       strPadL(strI2S(Percent * 5) + '%', 5, ' '));
  End;

Var
  InFile     : Text;
  PromptFile : File of RecPrompt;
  Prompt     : RecPrompt;
  Count      : LongInt;
  Done       : Array[0..mysMaxThemeText] of Boolean;
  Temp       : String;
  DoneNum    : LongInt;
Begin
  Assign  (PromptFile, BbsConfig.PathData + Theme.FileName + '.thm');
  ReWrite (PromptFile);

  If IoResult <> 0 Then Begin
    ShowMsgBox(0, 'Cannot compile theme when Mystic is loaded');
    Exit;
  End;

  Assign (InFile, BbsConfig.PathSystem + Theme.FileName + '.txt');
  Reset  (InFile);

  ShowMsgBox (3, 'Compiling:                          ');

  Prompt  := '';
  DoneNum := 0;

  For Count := 0 to mysMaxThemeText Do Begin
    Done[Count] := False;
    Write (PromptFile, Prompt);
  End;

  Reset (PromptFile);

  While Not Eof(InFile) Do Begin
    ReadLn (InFile, Temp);

    If Copy(Temp, 1, 3) = '000'      Then Count := 0 Else
    If strS2I(Copy(Temp, 1, 3)) > 0 Then Count := strS2I(Copy(Temp, 1, 3)) Else
    Count := -1;

    If Count <> -1 Then Begin
      Inc (DoneNum);

      UpdateBar(DoneNum);

      If Count > mysMaxThemeText Then Begin
        CloseMsgBox;
        ShowMsgBox(0, 'Prompt #' + strI2S(Count) + ' was not expected');
        Close (InFile);
        Close (PromptFile);
        Erase (PromptFile);
        Exit;
      End;

      Done[Count] := True;
      Seek (PromptFile, Count);
      Prompt := Copy(Temp, 5, Length(Temp));
      Write (PromptFile, Prompt);
    End;
  End;

  Close (InFile);
  Close (PromptFile);

  For Count := 0 to mysMaxThemeText Do Begin
    If Not Done[Count] Then Begin
      CloseMsgBox;
      ShowMsgBox (0, 'Prompt #' + strI2S(Count) + ' was not found');
      Erase (PromptFile);
      Break;
    End;
  End;

  CloseMsgBox;
End;

Const
  LinesPerPage = 16;
  LineWidth    = 72;
  WinStartX    = 5;
  WinStartY    = 2;
  WinCommentY  = 20;

Type
  TopicRec = Record
    Position : Word;
    Name     : String[50];
  End;

Var
  AreaData    : Array[1..65535] of ^TopicRec;
  TextData    : Array[1..65535] of ^String;
  PageData    : Array[1..65535] of ^Word;
  TextSize    : Word;
  AreaSize    : Word;
  PageSize    : Word;
  Total       : Word;
  Comment     : Array[1..LinesPerPage] of Array[1..3] of String[LineWidth];
  CurPageData : Array[1..LinesPerPage] of Word;
  CurPageSize : Byte;
  CurPage     : Word;
  CurLine     : Word;
  LastArea    : LongInt;
  SearchMask  : String;

Procedure DrawPage (Silent: Boolean);
Var
  Str   : String;
  A     : Byte;
  Count : Word;
Begin
  For A := 1 to LinesPerPage Do Begin
    Comment[A][1] := '';
    Comment[A][2] := '';
    Comment[A][3] := '';
  End;

  CurPageSize := 0;
  Count       := PageData[CurPage]^;

  While (CurPageSize < LinesPerPage) and (Count <= TextSize) Do Begin
    Str := TextData[Count]^;
    Inc (Count);
    If Str[1] = ';' Then Begin
      Delete (Str, 1, 2);

      Comment[CurPageSize + 1][1] := Comment[CurPageSize + 1][2];
      Comment[CurPageSize + 1][2] := Comment[CurPageSize + 1][3];
      Comment[CurPageSize + 1][3] := Str;
    End Else
    If (Str <> '') and (Str[1] <> '#') and (Str[1] <> '$') Then Begin
      Inc(CurPageSize);
      CurPageData[CurPageSize] := Count - 1;
      If Not Silent Then
        Console.WriteXYPipe (WinStartX, WinStartY + CurPageSize, 7, LineWidth, Copy(Str, 5, 255));
    End;
  End;

  If Not Silent Then
    If CurPageSize < LinesPerPage Then
      For A := CurPageSize + 1 to LinesPerPage Do
        Console.WriteXY (WinStartX, A + WinStartY, 7, strRep(' ', LineWidth));
End;

Procedure Search (Again: Boolean);
Var
  Temp    : String;
  Start   : Byte;
  A       : Byte;
  B       : Integer;
  PageEnd : Integer;
  LineNum : Integer;
Begin
  If (Not Again) or ((Again) and (SearchMask = '')) Then Begin
    SearchMask := GetStr('Search', 'Enter search text:', SearchMask, 50, 255);

    If SearchMask = '' Then Begin
      DrawPage(False);
      Exit;
    End;

    Start := 1;
    Again := False;
  End Else
    Start := CurPage;

  For A := Start to PageSize Do Begin

    If A = PageSize Then
      PageEnd := Total
    Else
      PageEnd := PageData[A+1]^ - 1;

    LineNum := 0;

    For B := PageData[A]^ to PageEnd Do Begin
      Temp := TextData[B]^;
      If (Temp[1] <> ';') and (Temp[1] <> '#') Then Begin
        Inc (LineNum);

        If Again and (A = CurPage) Then
          If (LineNum <= CurLine) and (LineNum < LinesPerPage) Then Continue;

        If Pos(strUpper(SearchMask), strUpper(strStripMCI(TextData[B]^))) > 0 Then Begin
          If Not ((A = CurPage) and (CurLine = LineNum)) Then Begin
            CurPage := A;
            CurLine := LineNum;
            DrawPage(False);
            Exit;
          End;
        End;
      End;
    End;
  End;

  ShowMsgBox(0, 'No matching text was found');
  DrawPage(False);
End;

Function GetPromptArea (LineNum: Byte) : Word;
Var
  Count : LongInt;
Begin
  Result := AreaSize;

  For Count := AreaSize DownTo 1 Do
    If CurPageData[LineNum] < AreaData[Count]^.Position Then
      If Count > 1 Then Begin
        If CurPageData[LineNum] > AreaData[Count - 1]^.Position Then Begin
          Result := Count - 1;
          Break;
        End;
      End Else
        Result := 1;
End;

Procedure DrawComments;
Var
  Area : Word;
Begin
  Console.WriteXY (WinStartX, WinCommentY    , 15, strPadR(Comment[CurLine][1], LineWidth, ' '));
  Console.WriteXY (WinStartX, WinCommentY + 1, 15, strPadR(Comment[CurLine][2], LineWidth, ' '));
  Console.WriteXY (WinStartX, WinCommentY + 2, 15, strPadR(Comment[CurLine][3], LineWidth, ' '));

  Area := GetPromptArea(CurLine);

  If LastArea <> Area Then Begin
    Console.WriteXY (4, WinCommentY - 1, 3, strRep('Ä', 74));
    Console.WriteXY (4, WinCommentY - 1, 3, '(' + strRep(' ', Length(AreaData[Area]^.Name)) + ')');
    Console.WriteXY (5, WinCommentY - 1, 7, AreaData[Area]^.Name);

    LastArea := Area;
  End;
End;

Function LoadPromptFile (FN: String) : Byte;
Const
  MemoryCheck = 32 * 1024;
Var
  TF    : Text;
  Buf   : Array[1..4096] of Char;
  Str   : String;
  Count : LongInt;
  Lines : LongInt;
  Last  : LongInt;
Begin
  Result   := 0;
  TextSize := 0;
  AreaSize := 0;
  PageSize := 0;
  LastArea := -1;

  Assign     (TF, FN);
  SetTextBuf (TF, Buf, 4096);
  Reset      (TF);

  If IoResult <> 0 Then Exit;

  While Not Eof(TF) Do Begin

    {$IFNDEF FPC}
    If MaxAvail < MemoryCheck Then Begin
      Result := 2;
      Close (TF);
      Exit;
    End;
    {$ENDIF}

    ReadLn (TF, Str);
    Inc    (TextSize);
    New    (TextData[TextSize]);

    TextData[TextSize]^ := Str;
  End;

  Close (TF);

  // FIND PROMPT SECTIONS

  For Count := 1 to TextSize Do
    If TextData[Count]^[1] = '$' Then Begin
      {$IFNDEF FPC}
      If MaxAvail < MemoryCheck Then Begin
        Result := 2;
        Exit;
      End;
      {$ENDIF}

      Inc (AreaSize);
      New (AreaData[AreaSize]);

      AreaData[AreaSize]^.Position := Count;
      AreaData[AreaSize]^.Name     := strStripB(Copy(TextData[Count]^, 2, Length(TextData[Count]^)), ' ');
    End;

  // FIND PAGE BREAKS

  Total := 0;
  Lines := 0;
  Last  := 1;

  For Count := 1 to TextSize Do Begin
    Str := strStripL(TextData[Count]^, ' ');

    If (Str <> '') and (Str[1] <> ';') and (Str[1] <> '#') and (Str[1] <> '$') Then Begin
      Inc (Total);
      Inc (Lines);

      If Lines = 1 Then Begin
        {$IFNDEF FPC}
        If MaxAvail < MemoryCheck Then Begin
          Result := 2;
          Exit;
        End;
        {$ENDIF}

        Inc (PageSize);
        New (PageData[PageSize]);

        PageData[PageSize]^ := Last;
      End;
    End;

    If Lines = LinesPerPage Then Begin
      Lines := 0;
      Last  := Count + 1;
    End;
  End;

  Result := 1;
End;

Procedure DisposeData;
Var
  Count : LongInt;
Begin
  For Count := AreaSize DownTo 1 Do Dispose(AreaData[Count]);
  For Count := PageSize DownTo 1 Do Dispose(PageData[Count]);
  For Count := TextSize DownTo 1 Do Dispose(TextData[Count]);
End;

Procedure JumpToArea;
Var
  List  : TMenuList;
  Count : Word;
  Page  : LongInt;
Begin
  List := TMenuList.Create(Console);

  List.Box.Header := ' Select Prompt Category ';

  For Count := 1 to AreaSize Do
    List.Add(AreaData[Count]^.Name, 0);

  List.Open (19, 7, 62, 18);
  List.Close;

  If List.ExitCode = #13 Then Begin
    For Count := 1 To PageSize Do
      If Count < PageSize Then Begin
        If AreaData[List.Picked]^.Position > PageData[Count]^ Then
          If AreaData[List.Picked]^.Position < PageData[Count + 1]^ Then Begin
            Page := Count;
            Break;
          End;
      End Else Begin
        Page := PageSize;
        Break;
      End;

    CurPage := Page;

    DrawPage(False);

    For Count := 1 to LinesPerPage Do
      If GetPromptArea(Count) = List.Picked Then Begin
        CurLine := Count;
        Break;
      End;
  End;

  List.Free;
End;

Procedure EditPrompts;
Var
  Box      : TMenuBox;
  Input    : TMenuInput;
  Image    : TConsoleImageRec;
  Res      : LongInt;
  Changed  : Boolean;
  EditStr  : String;
  UndoStr  : String;
  CurStr   : String[3];
  CopyStr  : String;
  NeedUndo : Boolean;
  Saved    : Boolean;
  InFile   : Text;
Begin
  Console.GetScreenImage(1, 1, 80, 25, Image);

  Console.WriteXY (1, 1,  8,   strRep('°', 80));
  Console.WriteXY (1, 2,  8,   strRep('°', 80));
  Console.WriteXY (1, 3,  8,   strRep('°', 80));
  Console.WriteXY (1, 24, 8,   strRep('°', 80));

  ShowMsgBox(3, 'Loading prompt data...');

  Res := LoadPromptFile(bbsConfig.PathSystem + Theme.FileName + '.txt');

  CloseMsgBox;

  Case Res of
    0 : Begin
          DisposeData;
          ShowMsgBox(0, bbsConfig.PathSystem + 'Unable to open: ' + Theme.FileName + '.txt');
          Console.PutScreenImage(Image);
          Exit;
        End;
    2 : Begin
          DisposeData;
          ShowMsgBox(0, 'Out of memory');
          Console.PutScreenImage(Image);
          Exit;
        End;
  End;

  Box   := TMenuBox.Create(Console);
  Input := TMenuInput.Create(Console);

  Box.Shadow    := False;
  Box.FrameType := 1;
  Box.Box3D     := False;
  Box.BoxAttr   := 3;

  Box.Open (3, 2, 78, 23);

  Console.WriteXY (4, 2, 3, '(   /   )');
  Console.WriteXY (72 - Length(Theme.FileName), 2, 3, '(' + strRep(' ', Length(Theme.FileName) + 4) + ')');
  Console.WriteXY (9, 2, 7, strI2S(Total));
  Console.WriteXY (73 - Length(Theme.FileName), 2, 7, Theme.FileName + '.txt');
  Console.WriteXY (1, 25, 112, '          CTRL+ (K) Copy   (P)aste   (U)ndo   (F)ind   (A)gain  (J)ump          ');
  Console.WriteXY (78, 3,  3, #25);
  Console.WriteXY (78, 18, 3, #24);

  Changed  := False;
  CurPage  := 1;
  CurLine  := 1;
  NeedUndo := True;

  DrawPage(False);

  Input.HiChars := #72#73#80#81#117#119;
  Input.LoChars := #01#06#10#11#16#21#27;

  Repeat
    For Res := 4 To 17 Do
      Console.WriteXY (78, Res, 3, '°');

    Res := (CurPage * 15) DIV PageSize;
    If CurPage = PageSize Then Res := 14;
    If (Res < 0) Then Res := 0;
    Console.WriteXY (78, 3 + Res, 3, '²');

    DrawComments;

    CurStr  := Copy(TextData[CurPageData[CurLine]]^, 1, 3);
    EditStr := Copy(TextData[CurPageData[CurLine]]^, 5, 255);

    If NeedUndo Then
      UndoStr := EditStr
    Else
      NeedUndo := True;

    Console.WriteXY (5, 2, 7, CurStr);

    EditStr := Input.GetStr(WinStartX, WinStartY + CurLine, LineWidth, 254, 1, EditStr);

    Case Input.ExitCode of
      #16 : If CopyStr <> '' Then Begin
              UndoStr  := EditStr;
              EditStr  := CopyStr;
              Changed  := True;
              NeedUndo := False;
            End;
      #21 : Begin
              EditStr := UndoStr;
            End;
    End;

    Console.WriteXYPipe (WinStartX, WinStartY + CurLine, 7, LineWidth, EditStr);
    TextData[CurPageData[CurLine]]^ := CurStr + ' ' + EditStr;

    Changed := Changed or Input.Changed;

    Case Input.ExitCode of
      #01 : Search(True);
      #06 : Search(False);
      #10 : JumpToArea;
      #11 : CopyStr := EditStr;
      #27 : Break;
      #72 : If CurLine > 1 Then
              Dec(CurLine)
            Else Begin
              If CurPage > 1 Then Begin
                Dec (CurPage);
                DrawPage(False);
                CurLine := CurPageSize;
              End;
            End;
      #73 : If CurPage > 1 Then Begin
              Dec (CurPage);
              DrawPage(False);
            End Else
              CurLine := 1;
      #80 : If CurLine < CurPageSize Then
              Inc(CurLine)
            Else Begin
              If CurPage < PageSize Then Begin
                Inc (CurPage);
                DrawPage(False);
                CurLine := 1;
              End;
            End;
      #81 : If CurPage < PageSize Then Begin
              Inc (CurPage);
              DrawPage(False);
              If CurLine > CurPageSize Then CurLine := CurPageSize;
            End Else
              CurLine := CurPageSize;
      #117: Begin
              CurPage := PageSize;
              DrawPage(False);
              CurLine := CurPageSize;
            End;
      #119: Begin
              CurPage := 1;
              CurLine := 1;
              DrawPage(False);
            End;
    End;
  Until False;

  Input.Free;

  Saved := False;

  If Changed Then
    If ShowMsgBox(1, 'Save changes?') Then Begin
      Saved := True;

      Assign  (InFile, BbsConfig.PathSystem + Theme.FileName + '.txt');
      ReWrite (InFile);

      For Res := 1 to TextSize Do Begin
        EditStr := TextData[Res]^;
        WriteLn (InFile, EditStr);
      End;

      Close (InFile);
    End;

  DisposeData;

  If Saved Then
    If ShowMsgBox(1, 'Compile changed theme file?') Then
      CompileTheme;

  Box.Close;
  Box.Free;

  Console.PutScreenImage(Image);
End;

Procedure EditSettings;
Var
  Box   : TMenuBox;
  Form  : TMenuForm;
  Topic : String;
Begin
  Box  := TMenuBox.Create(Console);
  Form := TMenuForm.Create(Console);

  Topic      := '|03(|09Theme|03) |01-|09> |15';
  Box.Header := ' Theme Settings ';

  Form.AddBol  ('L', ' Use Lightbar Yes/No ',  7,  7, 30,  7, 21, 3,       @Theme.LightbarYN,   Topic + 'Use lightbar Yes/No prompts');
  Form.AddChar ('W', ' Password Echo Char ' ,  8,  8, 30,  8, 20, 32, 255, @Theme.PasswordEcho, Topic + 'Password input mask character');
  Form.AddChar ('I', ' Input Field Char '   , 10,  9, 30,  9, 18, 32, 225, @Theme.InputChar,    Topic + 'Input field fill character');
  Form.AddAttr ('N', ' Input Field Color 1 ',  7, 11, 30, 11, 21,          @Theme.InputField1,  Topic + 'Input field text color');
  Form.AddAttr ('P', ' Input Field Color 2 ',  7, 12, 30, 12, 21,          @Theme.InputField2,  Topic + 'Input field fill color');
  Form.AddTog  ('F', ' Username Input Type ',  7, 13, 30, 13, 21, 9, 0, 4, 'AsTyped Uppercase Lowercase Proper eLiTe', @Theme.UserInputFmt, Topic + 'User name input format');

  Form.AddAttr ('0', ' Theme Color #0 ', 45, 7,  63,  7, 16, @Theme.Colors[0], Topic);
  Form.AddAttr ('1', ' Theme Color #1 ', 45, 8,  63,  8, 16, @Theme.Colors[1], Topic);
  Form.AddAttr ('2', ' Theme Color #2 ', 45, 9,  63,  9, 16, @Theme.Colors[2], Topic);
  Form.AddAttr ('3', ' Theme Color #3 ', 45, 10, 63, 10, 16, @Theme.Colors[3], Topic);
  Form.AddAttr ('4', ' Theme Color #4 ', 45, 11, 63, 11, 16, @Theme.Colors[4], Topic);
  Form.AddAttr ('5', ' Theme Color #5 ', 45, 12, 63, 12, 16, @Theme.Colors[5], Topic);
  Form.AddAttr ('6', ' Theme Color #6 ', 45, 13, 63, 13, 16, @Theme.Colors[6], Topic);
  Form.AddAttr ('7', ' Theme Color #7 ', 45, 14, 63, 14, 16, @Theme.Colors[7], Topic);
  Form.AddAttr ('8', ' Theme Color #8 ', 45, 15, 63, 15, 16, @Theme.Colors[8], Topic);
  Form.AddAttr ('9', ' Theme Color #9 ', 45, 16, 63, 16, 16, @Theme.Colors[9], Topic);
  Form.AddAttr ('E', ' Line Chat #1 '  , 47, 18, 63, 18, 14, @Theme.LineChat1, Topic);
  Form.AddAttr ('C', ' Line Chat #2 '  , 47, 19, 63, 19, 14, @Theme.LineChat2, Topic);

  Box.Open (5, 5, 73, 20);

  VerticalLine (28,  7, 9);
  VerticalLine (28, 11, 13);
  VerticalLine (61,  7, 16);
  VerticalLine (61, 18, 19);

  Form.Execute;

  Box.Close;

  Form.Free;
  Box.Free;

  If Theme.InputChar < #32 Then Theme.InputChar := ' ';
End;

Procedure EditTheme;
Var
  Box   : TMenuBox;
  Form  : TMenuForm;
  Topic : String;
Begin
  Box  := TMenuBox.Create(Console);
  Form := TMenuForm.Create(Console);

  Topic      := '|03(|09Themes|03) |01-|09> |15';
  Box.Header := ' Theme Editor ';

  Form.LoExitChars := #05#16#27;

  Form.AddStr  ('F', ' File Name '    , 16,  8, 29,  8, 11, 20, 20, @Theme.FileName,     Topic + 'File name of theme');
  Form.AddStr  ('D', ' Description '  , 14,  9, 29,  9, 13, 40, 40, @Theme.Description,  Topic + 'Theme description');
  Form.AddPath ('T', ' Text Path '    , 16, 10, 29, 10, 11, 40, 60, @Theme.PathText,     Topic + 'Path where display files are stored');
  Form.AddPath ('M', ' Template Path ', 12, 11, 29, 11, 15, 40, 60, @Theme.PathTemplate, Topic + 'Path where template files are stored');
  Form.AddPath ('U', ' Menu Path '    , 16, 12, 29, 12, 11, 40, 60, @Theme.PathMenu,     Topic + 'Path where menu files are stored');
  Form.AddPath ('S', ' Scripts Path ' , 13, 13, 29, 13, 14, 40, 60, @Theme.PathScripts,  Topic + 'Path where MPL scripts are stored');
  Form.AddBol  ('B', ' Path Fallback ', 12, 15, 29, 15, 15,  3,     @Theme.PathFallback, Topic + 'Theme checks default paths if file not found');
  Form.AddBol  ('C', ' Allow ASCII '  , 14, 16, 29, 16, 13,  3,     @Theme.AllowASCII,   Topic + 'Theme allows ASCII graphics');
  Form.AddBol  ('A', ' Allow ANSI '   , 15, 17, 29, 17, 12,  3,     @Theme.AllowANSI,    Topic + 'Theme allows ANSI graphics');

  Box.Open (11, 6, 70, 20);

  VerticalLine    (27,  8, 13);
  VerticalLine    (27, 15, 17);
  Console.WriteXY (13, 19, 112, '(CTRL-P) Edit Prompts              (CTRL-E) Edit Options');

  Repeat
    Case Form.Execute of
      #05 : Begin
              Box.Hide;
              EditSettings;
              Box.Show;
            End;
      #16 : EditPrompts;
      #27 : Break;
    End;
  Until False;

  Box.Close;
  Form.Free;
  Box.Free;
End;

Function ThemeGetFileName (Select: Boolean) : String;
Var
  Box       : TMenuBox;
  List      : TMenuList;
  ThemeFile : TBufFile;
Begin
  ThemeFile := TBufFile.Create(SizeOf(recTheme));

  If Not ThemeFile.Open (bbsConfig.PathData + 'themes.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(recTheme)) Then Begin
    ShowMsgBox(0, 'Unable to open/create themes.dat');
    ThemeFile.Free;
    Exit;
  End;

  Box  := TMenuBox.Create(Console);
  List := TMenuList.Create(Console);

  Box.Header    := ' Theme ';
  List.LoChars  := #1#4#13#27;
  List.NoWindow := True;
  List.HiAttr   := 31;

  If Select Then
    Box.Header := Box.Header + 'Selector '
  Else
    Box.Header := Box.Header + 'Editor ';

  Box.Open (8, 6, 73, 18);

  Console.WriteXY (10,  8, 112, 'File Name             Description');
  Console.WriteXY (10,  9, 112, strRep('Ä', 62));
  Console.WriteXY (10, 16, 112, strRep('Ä', 62));

  If Not Select Then
    Console.WriteXY (10, 17, 112, '(CTRL-A) Add            (CTRL-D) Delete           (ENTER) Edit');

  Repeat
    List.Clear;

    ThemeFile.Reset;

    While Not ThemeFile.EOF Do Begin
      ThemeFile.Read(Theme);
      List.Add (strPadR(Theme.FileName, 20, ' ') + '  ' + Theme.Description, 0);
    End;

    List.Add ('', 0);

    List.Open (8, 9, 73, 16);
    List.Close;

    Case List.ExitCode of
      #13 : If (List.ListMax > 0) And (List.Picked <> List.ListMax) Then
              If Select Then Begin
                ThemeFile.Seek (List.Picked - 1);
                ThemeFile.Read (Theme);
                Result := strStripB(Copy(List.List[List.Picked]^.Name, 1, 20), ' ');
                Break;
              End Else Begin
                Box.Hide;
                ThemeFile.Seek (List.Picked - 1);
                ThemeFile.Read (Theme);
                EditTheme;
                ThemeFile.Seek  (List.Picked - 1);
                ThemeFile.Write (Theme);
                Box.Show;
              End;
      #27 : Break;
      #01 : If Not Select Then Begin
              ThemeFile.RecordInsert(List.Picked);

              With Theme Do Begin
                FileName       := 'new';
                Description    := 'New Theme';
                PathText       := bbsConfig.PathText;
                PathMenu       := bbsConfig.PathMenu;
                PathScripts    := bbsConfig.PathScripts;
                PathTemplate   := bbsConfig.PathTemplate;
                PathFallback   := True;
                AllowAnsi      := True;
                AllowAscii     := True;
                LightbarYN     := True;
                UserInputFmt   := 0;
                PasswordEcho   := '*';
                InputChar      := '°';
                InputField1    := 31;
                InputField2    := 23;
                LineChat1      := 9;
                LineChat2      := 11;
                Colors[0]      := 1;
                Colors[1]      := 9;
                Colors[2]      := 11;
                Colors[3]      := 8;
                Colors[4]      := 7;
                Colors[5]      := 15;
                Colors[6]      :=  8 + 1 * 16;
                Colors[7]      :=  7 + 1 * 16;
                Colors[8]      :=  9 + 1 * 16;
                Colors[9]      := 15 + 1 * 16;
              End;

              ThemeFile.Write(Theme);
            End;
      #04 : If Not Select Then
              If List.Picked <> List.ListMax Then
                ThemeFile.RecordDelete(List.Picked);
    End;
  Until False;

  Box.Close;
  Box.Free;
  List.Free;
  ThemeFile.Free;
End;

End.

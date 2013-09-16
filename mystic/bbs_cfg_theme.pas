Unit bbs_cfg_Theme;

{$I M_OPS.PAS}

Interface

Function Configuration_ThemeEditor (Select: Boolean) : String;

Implementation

Uses
  m_Types,
  m_FileIO,
  m_Strings,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Ansi_MenuInput,
  BBS_Core,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_Cfg_Common;

(*
Procedure CompileTheme (Var Theme: RecTheme);
Var
  LastPer : Byte = 0;

  Procedure UpdateBar (Cur : Integer);
  Var
    Percent : Byte;
  Begin
    Percent := Round(Cur / mysMaxThemeText * 100 / 5);

    If Percent <> LastPer Then Begin
      LastPer := Percent;
      WriteXY (34, 12, 113, strRep(#178, Percent) + strRep(#176, 20 - Percent) + strPadL(strI2S(Percent * 5) + '%', 5, ' '));
    End;
  End;

Var
  InFile     : Text;
  PromptFile : File of RecPrompt;
  Prompt     : RecPrompt;
  Count      : Integer;
  Done       : Array[0..mysMaxThemeText] of Boolean;
  Temp       : String;
  DoneNum    : Integer;
Begin
  Assign (PromptFile, bbsCfg.DataPath + Theme.FileName + '.thm');

  {$I-} ReWrite (PromptFile); {$I+}

  If IoResult <> 0 Then Begin
    ShowMsgBox(0, 'Cannot compile theme while using it');
    Exit;
  End;

  Assign (InFile, bbsCfg.SystemPath + Theme.FileName + '.txt');
  Reset  (InFile);

  ShowMsgBox (3, 'Compiling:                           ');

  Prompt  := '';
  DoneNum := 0;

  For Count := 0 to mysMaxThemeText Do Begin
    Done[Count] := False;
    Write (PromptFile, Prompt);
  End;

  Reset (PromptFile);

  While Not Eof(InFile) Do Begin
    ReadLn (InFile, Temp);

    If Copy(Temp, 1, 3) = '000'     Then Count := 0 Else
    If strS2I(Copy(Temp, 1, 3)) > 0 Then Count := strS2I(Copy(Temp, 1, 3)) Else
    Count := -1;

    If Count <> -1 Then Begin
      Inc (DoneNum);

      UpdateBar(DoneNum);

      If Count > mysMaxThemeText Then Begin
        ShowMsgBox(0, 'String #' + strI2S(Count) + ' was not expected');

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
      ShowMsgBox (0, 'String #' + strI2S(Count) + ' was not found');
      Erase (PromptFile);
      Break;
    End;
  End;
End;
*)

Procedure EditPrompts (Var Theme: RecTheme);
Const
  MaxText      = 3000;
  LinesPerPage = 16;
  WinStartX    = 3;
  WinStartY    = 1;
Var
  Box          : TAnsiMenuBox;
  Input        : TAnsiMenuInput;
  InFile       : Text;
  TotalText    : Word;
  StrData      : Array[1..MaxText] of ^String;
  Comment      : Array[1..LinesPerPage] of Array[1..3] of String[75];
  PageData     : Array[1..LinesPerPage] of Integer;
  PageStart    : Array[1..100] of Integer;
  PageTotal    : Integer;
  CurPage      : Byte = 1;
  CurLine      : Byte = 1;
  CurPageLines : Byte;
  TotalPrompt  : Integer;
  SearchMask   : String = '';
  CopyStr      : String = '';

  Procedure DisposeStringData;
  Var
    Count : Word;
  Begin
    For Count := TotalText DownTo 1 Do
      Dispose (StrData[Count]);
  End;

  Function LoadStringData : Boolean;
  Var
    Str    : String;
    Buffer : Array[1..4096] of Byte;
  Begin
    Result := False;

    Assign     (InFile, bbsCfg.DataPath + Theme.FileName + '.txt');
    SetTextBuf (InFile, Buffer, SizeOf(Buffer));

    {$I-} Reset (InFile); {$I+}

    If IoResult <> 0 Then Begin
      ShowMsgBox (0, 'Unable to open ' + bbsCfg.DataPath + Theme.FileName + '.txt');
      Exit;
    End;

    ShowMsgBox (2, 'Loading ' + Theme.FileName + '.txt');

    TotalText := 0;

    While Not Eof(InFile) Do Begin
      If TotalText = MaxText Then Begin
        Close (InFile);

        ShowMsgBox (0, 'File too large');

        DisposeStringData;
        Exit;
      End;

      ReadLn (InFile, Str);
      Inc    (TotalText);

      New (StrData[TotalText]);

      StrData[TotalText]^ := Str;
    End;

    Close (InFile);

    Result := True;
  End;

  Procedure GetTotalPages;
  Var
    Str   : String;
    Count : Integer;
    Lines : Integer;
    Last  : Integer;
  Begin
    PageTotal   := 0;
    Lines       := 0;
    Last        := 1;
    Count       := 0;
    TotalPrompt := -1;

    While Count < TotalText Do Begin
      Inc (Count);

      Str := StrData[Count]^;

      If (Str <> '') and (Str[1] <> ';') and (Str[1] <> '#') Then Begin
        Inc (TotalPrompt);
        Inc (Lines);

        If Lines = 1 Then Begin
          Inc (PageTotal);

          PageStart[PageTotal] := Last;
        End;
      End;

      If Lines = LinesPerPage Then Begin
        Lines := 0;
        Last  := Count + 1;
      End;
    End;
  End;

  Procedure DrawPage (Silent: Boolean);
  Var
    Str   : String;
    A     : Byte;
    Count : Integer;
  Begin
    For A := 1 to LinesPerPage Do Begin
      Comment[A][1] := '';
      Comment[A][2] := '';
      Comment[A][3] := '';
    End;

    CurPageLines := 0;
    Count        := PageStart[CurPage];

    While (CurPageLines < LinesPerPage) and (Count <= TotalText) Do Begin
      Str := StrData[Count]^;

      Inc (Count);

      If Str[1] = ';' Then Begin
        Delete (Str, 1, 2);

        Comment[CurPageLines + 1][1] := Comment[CurPageLines + 1][2];
        Comment[CurPageLines + 1][2] := Comment[CurPageLines + 1][3];
        Comment[CurPageLines + 1][3] := Str;
      End Else
      If (Str <> '') and (Str[1] <> '#') Then Begin
        Inc(CurPageLines);

        PageData[CurPageLines] := Count - 1;

        If Not Silent Then
          WriteXYPipe (WinStartX, WinStartY + CurPageLines, 7, 75, Copy(Str, 5, 255));
      End;
    End;

    If Not Silent Then
      If CurPageLines < LinesPerPage Then
        For A := CurPageLines + 1 to LinesPerPage Do
          WriteXY (WinStartX, A + WinStartY, 7, strRep(' ', 75));
  End;

  Procedure DrawComments;
  Begin
    WriteXY (3, 19, 15, strPadR(Comment[CurLine][1], 75, ' '));
    WriteXY (3, 20, 15, strPadR(Comment[CurLine][2], 75, ' '));
    WriteXY (3, 21, 15, strPadR(Comment[CurLine][3], 75, ' '));
  End;

  Procedure JumpToPrompt (Cur : Word);
  Var
    Box     : TAnsiMenuBox;
    Input   : TAnsiMenuInput;
    Num     : Word;
    Count   : Word;
    PageEnd : Word;
    LineNum : Word;
    B       : Word;
  Begin
    Box   := TAnsiMenuBox.Create;
    Input := TAnsiMenuInput.Create;

    Box.Open (27, 8, 53, 12);

    WriteXY (30, 10, 112, 'Jump to prompt #:');

    Num := Input.GetNum(48, 10, 4, 4, 0, mysMaxThemeText, Cur);

    Box.Close;
    Input.Free;
    Box.Free;

    If Num <> Cur Then
      For Count := 1 to PageTotal Do Begin
        If Count = PageTotal Then
          PageEnd := TotalText
        Else
          PageEnd := PageStart[Count + 1] - 1;

        LineNum := 0;

        For B := PageStart[Count] to PageEnd Do Begin
          If (StrData[B]^[1] <> ';') and (StrData[B]^[1] <> '#') Then Begin
            Inc (LineNum);

            If strS2I(Copy(StrData[B]^, 1, 3)) = Num Then Begin
              If Not ((Count = CurPage) and (CurLine = LineNum)) Then Begin
                CurPage := Count;
                CurLine := LineNum;

                DrawPage(False);

                Exit;
              End;
            End;
          End;
        End;
      End;

    DrawPage(False);
  End;

  Procedure Search (Again : Boolean);
  Var
    Temp    : String;
    Start   : Byte;
    A       : Byte;
    B       : Integer;
    PageEnd : Integer;
    LineNum : Integer;
    Box     : TAnsiMenuBox;
    Input   : TAnsiMenuInput;
  Begin
    If (Not Again) or ((Again) and (SearchMask = '')) Then Begin
      Box   := TAnsiMenuBox.Create;
      Input := TAnsiMenuInput.Create;

      Box.Header := ' Search ';

      Box.Open(14, 8, 67, 10);

      SearchMask := Input.GetStr(16, 9, 50, 50, 1, SearchMask);

      Input.Free;
      Box.Free;

      If SearchMask = '' Then Begin
        DrawPage(False);
        Exit;
      End;

      Start := 1;
      Again := False;
    End Else
      Start := CurPage;

    For A := Start to PageTotal Do Begin

      If A = PageTotal Then
        PageEnd := TotalText
      Else
        PageEnd := PageStart[A+1]-1;

      LineNum := 0;

      For B := PageStart[A] to PageEnd Do Begin
        Temp := StrData[B]^;

        If (Temp[1] <> ';') and (Temp[1] <> '#') Then Begin
          Inc (LineNum);

          If Again and (A = CurPage) Then
            If (LineNum <= CurLine) and (LineNum < LinesPerPage) Then Continue;

          If Pos(strUpper(SearchMask), strUpper(strStripPipe(StrData[B]^))) > 0 Then Begin
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

    ShowMsgBox(0, 'No maching text was found');

    DrawPage(False);
  End;

  Procedure SimulatePrompt;
  Var
    SimStr  : String;
    SavedX  : Byte;
    SavedY  : Byte;
  Begin
    Repeat
      SimStr := Copy(StrData[PageData[CurLine]]^, 5, 255);

      Session.io.AnsiColor(7);
      Session.io.AnsiClear;

      Session.io.OutFull(SimStr);

      SavedX := Console.CursorX;
      SavedY := Console.CursorY;

      WriteXY (1, 23, 112, strPadC('Simulating Prompt', 79, ' '));

      Session.io.AnsiGotoXY(SavedX, SavedY);

      Case Session.io.GetKey of
        #13,
        #27 : Break;
      End;
    Until False;
  End;

  Procedure FullReDraw;
  Begin
    Session.io.AnsiColor(7);
    Session.io.AnsiClear;

    Box.FrameType := 1;
    Box.BoxAttr   := 8;
    Box.Box3D     := False;
    Box.Shadow    := False;

    Input.HiChars := #72#73#80#81;
    Input.LoChars := #01#02#06#07#11#13#16#20#21#27;

    Box.Open (1, 1, 79, 22);

    WriteXY (2, 18, 8, strRep('Ä', 77));
    WriteXY (3,  1, 8, '    /    ');
    WriteXY (8,  1, 7, strI2S(TotalPrompt));
    WriteXY (73 - Length(Theme.FileName), 1, 7, ' ' + Theme.FileName + '.txt ');

    WriteXYPipe (1, 23, 112, 79, ' Prompts ³  |01Press |15CTRL |01+ |15T|01op |15B|01ottom |15F|01ind |15A|01gain |15G|01oto |15K|01ut |15P|01aste |15U|01ndo  |00³ ESC/Quit ');

    DrawPage(False);
  End;

Var
  EditStr    : String;
  UndoStr    : String;
  CurStr     : String[3];
  Changed    : Boolean = False;
//  Saved      : Boolean = False;
  Count      : Integer;
  Image      : TConsoleImageRec;
  SavedTheme : RecTheme;
Begin
  Console.GetScreenImage(1, 1, 79, 24, Image);

  If Not LoadStringData Then Exit;

  GetTotalPages;

  SavedTheme := Session.Theme;

  Move (Theme.Colors, Session.Theme.Colors, SizeOf(Theme.Colors));

  Box   := TAnsiMenuBox.Create;
  Input := TAnsiMenuInput.Create;

  FullReDraw;

  Repeat
    DrawComments;

    CurStr  := Copy(StrData[PageData[CurLine]]^, 1, 3);
    EditStr := Copy(StrData[PageData[CurLine]]^, 5, 255);
    UndoStr := EditStr;

    WriteXY (4, 1, 7, CurStr);

    EditStr := Input.GetStr(WinStartX, WinStartY + CurLine, 75, 254, 1, EditStr);

    Case Input.ExitCode of
      #16 : If CopyStr <> '' Then Begin
              EditStr       := CopyStr;
              Input.Changed := True;
            End;
      #21 : Begin
              EditStr       := UndoStr;
              Input.Changed := False;
            End;
    End;

    WriteXYPipe (WinStartX, WinStartY + CurLine, 7, 75, EditStr);

    StrData[PageData[CurLine]]^ := CurStr + ' ' + EditStr;

    If Input.Changed Then Changed := True;

    Case Input.ExitCode of
      #01 : Search(True);
      #02 : Begin
              CurPage := PageTotal;

              DrawPage(False);

              CurLine := CurPageLines;
            End;

      #06 : Search(False);
      #07 : JumpToPrompt(strS2I(CurStr));
      #11 : CopyStr := EditStr;
      #13 : Begin
              SimulatePrompt;
              FullRedraw;
            End;
      #20 : Begin
              CurPage := 1;
              CurLine := 1;

              DrawPage(False);
            End;
      #27 : Break;
      #72 : If CurLine > 1 Then
              Dec(CurLine)
            Else Begin
              If CurPage > 1 Then Begin
                Dec (CurPage);

                DrawPage(False);

                CurLine := CurPageLines;
              End;
            End;
      #73 : If CurPage > 1 Then Begin
              Dec (CurPage);

              DrawPage(False);
            End Else
              CurLine := 1;
      #80 : If CurLine < CurPageLines Then
              Inc(CurLine)
            Else Begin
              If CurPage < PageTotal Then Begin
                Inc (CurPage);

                DrawPage(False);

                CurLine := 1;
              End;
            End;
      #81 : If CurPage < PageTotal Then Begin
              Inc (CurPage);

              DrawPage(False);

              CurLine := 1;
            End Else
              CurLine := CurPageLines;
    End;
  Until False;

  If Changed Then
    If ShowMsgBox(1, 'Save changes?') Then Begin
//      Saved := True;

      Assign  (InFile, bbsCfg.DataPath + Theme.FileName + '.txt');
      ReWrite (InFile);

      For Count := 1 to TotalText Do Begin
        EditStr := StrData[Count]^;
        WriteLn (InFile, EditStr);
      End;

      Close (InFile);
    End;

  DisposeStringData;

//  If Saved Then
//    CompileTheme(Theme);

  Box.Free;
  Input.Free;

  Session.io.RemoteRestore(Image);

  Session.Theme := SavedTheme;
End;

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

  Box.Open (5, 5, 75, 18);

  Box.Header := ' Theme Edit ';

  VerticalLine (23, 7, 16);

  Form.AddStr  ('F', ' File Name'      , 12,  7, 25,  7, 11, 20, 20, @Theme.FileName, Topic + 'Root theme filename');
  Form.AddStr  ('D', ' Description'    , 10,  8, 25,  8, 13, 30, 40, @Theme.Desc, Topic + 'Theme description');
  Form.AddPath ('T', ' Text Path'      , 12,  9, 25,  9, 11, 30, 80, @Theme.TextPath, Topic + 'Text path');
  Form.AddPath ('M', ' Menu Path'      , 12, 10, 25, 10, 11, 30, 80, @Theme.MenuPath, Topic + 'Menu path');
  Form.AddPath ('S', ' Script Path'    , 10, 11, 25, 11, 13, 30, 80, @Theme.ScriptPath, Topic + 'Script path');
  Form.AddBits ('F', ' Allow Fallback' ,  7, 13, 25, 13, 16, ThmFallback, @Theme.Flags, Topic + 'Allow fallback to default paths?');
  Form.AddBits ('C', ' Allow ASCII'    , 10, 14, 25, 14, 13, ThmAllowASCII, @Theme.Flags, Topic + 'Allow ASCII users to use this theme?');
  Form.AddBits ('N', ' Allow ANSI'     , 11, 15, 25, 15, 12, ThmAllowANSI, @Theme.Flags, Topic + 'Allow ANSI users to use this theme?');
  Form.AddTog  ('O', ' Column Size'    , 10, 16, 25, 16, 13, 9, 0, 1, '80_Column 40_Column', @Theme.ColumnSize, Topic + 'Column size of this theme');

  Form.AddNone ('1', ' 1: Prompts'     , 57,  7, 57, 7, 17, Topic + 'Edit prompts for this theme');
  Form.AddNone ('2', ' 2: Options'     , 57,  8, 57, 8, 17, Topic + 'Edit general options for this theme');
  Form.AddNone ('3', ' 3: Percent Bars', 57,  9, 57, 9, 17, Topic + 'Edit percentage bars used in this theme');

  Repeat
    Case Form.Execute of
      '1' : EditPrompts(Theme);
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
  ThemeFile : File of RecTheme;
  Theme     : RecTheme;
  Copied    : RecTheme;
  HasCopy   : Boolean = False;
Begin
  Assign (ThemeFile, bbsCfg.DataPath + 'theme.dat');

  If Not ioReset(ThemeFile, Sizeof(RecTheme), fmRWDN) Then
    If Not ioReWrite(ThemeFile, SizeOf(RecTheme), fmRWDN) Then
      Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Themes ';
  List.LoChars  := #13#27#47;
  List.NoWindow := True;
  List.SearchY  := 19;

  Box.Open (8, 6, 73, 19);

  WriteXY (10,  8, 112, 'File Name             Description');
  WriteXY (10,  9, 112, strRep(#196, 62));
  WriteXY (10, 17, 112, strRep(#196, 62));
  WriteXY (29, 18, 112, cfgCommandList);

  Repeat
    List.Clear;

    Reset(ThemeFile);

    While Not EOF(ThemeFile) Do Begin
      Read (ThemeFile, Theme);

      List.Add (strPadR(Theme.FileName, 20, ' ') + '  ' + Theme.Desc, 0);
    End;

    List.Add ('', 0);

    List.Open (8, 9, 73, 17);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(9, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : Begin
                      AddRecord (ThemeFile, List.Picked, SizeOf(RecTheme));

                      FillChar(Theme, SizeOf(Theme), 0);

                      With Theme Do Begin
                        Flags        := ThmAllowANSI OR ThmAllowASCII OR ThmFallback OR ThmLightbarYN;
                        FileName     := 'new';
                        Desc         := FileName;
                        TextPath     := bbsCfg.TextPath;
                        MenuPath     := bbsCfg.MenuPath;
                        ScriptPath   := bbsCfg.ScriptPath;
                        TemplatePath := bbsCfg.TextPath;
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

                      Write (ThemeFile, Theme);
                    End;
              'D' : If List.Picked <> List.ListMax Then
                      If ShowMsgBox(1, 'Delete this entry?') Then
                        KillRecord (ThemeFile, List.Picked, SizeOf(RecTheme));
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (ThemeFile, List.Picked - 1);
                      Read (ThemeFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (ThemeFile, List.Picked, SizeOf(RecTheme));
                      Write     (ThemeFile, Copied);
                    End;
            End;
      #13 : If (List.ListMax > 0) And (List.Picked <> List.ListMax) Then
              If Select Then Begin
                Seek (ThemeFile, List.Picked - 1);
                Read (ThemeFile, Theme);

                Result := strStripB(Copy(List.List[List.Picked]^.Name, 1, 20), ' ');

                Break;
              End Else Begin
                Box.Hide;

                Seek (ThemeFile, List.Picked - 1);
                Read (ThemeFile, Theme);

                EditTheme (Theme);

                Seek  (ThemeFile, List.Picked - 1);
                Write (ThemeFile, Theme);

                Box.Show;
              End;
      #27 : Break;
    End;

  Until False;

  Close (ThemeFile);

  Box.Close;
  Box.Free;
  List.Free;
End;

End.

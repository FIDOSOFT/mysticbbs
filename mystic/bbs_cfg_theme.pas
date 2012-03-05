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

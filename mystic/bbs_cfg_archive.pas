Unit bbs_cfg_Archive;

{$I M_OPS.PAS}

Interface

Procedure Configuration_ArchiveEditor;

Implementation

Uses
  m_FileIO,
  m_Strings,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Cfg_Common;

Procedure EditArchive (Var Arc: RecArchive);
Var
  Box      : TAnsiMenuBox;
  Form     : TAnsiMenuForm;
Begin
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Archive Editor: ' + Arc.Desc + ' ';

  Box.Open (13, 5, 67, 15);

  Form.HelpSize := 0;

  VerticalLine (28, 7, 13);

  Form.AddBol  ('A', ' Active '         , 20,  7, 30,  7,  8, 3, @Arc.Active, '');
  Form.AddStr  ('X', ' Extension '      , 17,  8, 30,  8, 11, 4, 4, @Arc.Ext, '');
  Form.AddTog  ('O', ' OS '             , 24,  9, 30,  9,  4, 7, 0, 4, 'Windows Linux OSX All OS/2', @Arc.OSType, '');
  Form.AddStr  ('D', ' Description '    , 15, 10, 30, 10, 13, 30, 30, @Arc.Desc, '');
  Form.AddStr  ('P', ' Pack Cmd '       , 18, 11, 30, 11, 10, 35, 80, @Arc.Pack, '');
  Form.AddStr  ('U', ' Unpack Cmd '     , 16, 12, 30, 12, 12, 35, 80, @Arc.Unpack, '');
  Form.AddStr  ('V', ' View Cmd '       , 18, 13, 30, 13, 10, 35, 80, @Arc.View, '');

  Form.Execute;
  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure Configuration_ArchiveEditor;
Var
  Box     : TAnsiMenuBox;
  List    : TAnsiMenuList;
  ArcFile : File of RecArchive;
  Arc     : RecArchive;
  Copied  : RecArchive;
  HasCopy : Boolean = False;

  Procedure MakeList;
  Var
    OS : String;
  Begin
    List.Clear;

    ioReset (ArcFile, SizeOf(RecArchive), fmRWDN);

    While Not Eof(ArcFile) Do Begin
      Read (ArcFile, Arc);

      Case Arc.OSType of
        0 : OS := 'Windows';
        1 : OS := 'Linux  ';
        2 : OS := 'OSX    ';
        3 : OS := 'All    ';
        4 : OS := 'OS/2   ';
      End;

      List.Add (strPadR(YesNoStr[Arc.Active], 5, ' ') + strPadR(Arc.Ext, 7, ' ') + OS + '   ' + Arc.Desc, 0);
    End;

    List.Add ('', 2);
  End;

Begin
  Assign (ArcFile, bbsCfg.DataPath + 'archive.dat');

  If Not ioReset(ArcFile, SizeOf(RecArchive), fmRWDN) Then
    If Not ioReWrite(ArcFile, SizeOf(RecArchive), fmRWDN) Then
      Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Archive Editor ';
  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.SearchY  := 20;

  Box.Open (13, 5, 67, 20);

  WriteXY (15,  7, 112, 'Use  Ext    OSID      Description');
  WriteXY (15,  8, 112, strRep('Ä', 51));
  WriteXY (15, 18, 112, strRep('Ä', 51));
  WriteXY (29, 19, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (13, 8, 67, 18);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : Begin
                      AddRecord (ArcFile, List.Picked, SizeOf(RecArchive));

                      Arc.OSType := OSType;
                      Arc.Active := False;
                      Arc.Desc   := 'New archive';
                      Arc.Ext    := 'NEW';
                      Arc.Pack   := '';
                      Arc.Unpack := '';
                      Arc.View   := '';

                      Write (ArcFile, Arc);

                      MakeList;
                    End;
              'D' : If ShowMsgBox(1, 'Delete this entry?') Then Begin
                      KillRecord (ArcFile, List.Picked, SizeOf(RecArchive));

                      MakeList;
                    End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (ArcFile, List.Picked - 1);
                      Read (ArcFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (ArcFile, List.Picked, SizeOf(RecArchive));
                      Write     (ArcFile, Copied);

                      MakeList;
                    End;
            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              Seek (ArcFile, List.Picked - 1);
              Read (ArcFile, Arc);

              EditArchive(Arc);

              Seek  (ArcFile, List.Picked - 1);
              Write (ArcFile, Arc);
            End;
      #27 : Break;
    End;
  Until False;

  Close (ArcFile);

  Box.Close;
  List.Free;
  Box.Free;
End;

End.

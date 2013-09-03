Unit bbs_cfg_Protocol;

{$I M_OPS.PAS}

Interface

Procedure Configuration_ProtocolEditor;

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

Procedure EditProtocol (Var Prot: RecProtocol);
Var
  Box  : TAnsiMenuBox;
  Form : TAnsiMenuForm;
Begin
  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Form.HelpSize := 0;

  Box.Header := ' Protocol Editor: ' + Prot.Desc + ' ';

  Box.Open (6, 5, 75, 15);

  VerticalLine (22, 7, 13);

  Form.AddBol  ('A', ' Active '      , 14,  7, 24,  7,  8, 3, @Prot.Active, '');
  Form.AddTog  ('O', ' OS '          , 18,  8, 24,  8,  4, 7, 0, 4, 'Windows Linux OSX All OS/2', @Prot.OSType, '');
  Form.AddBol  ('B', ' Batch '       , 15,  9, 24,  9,  7, 3, @Prot.Batch, '');
  Form.AddChar ('K', ' Hot Key '     , 13, 10, 24, 10,  9, 1, 254, @Prot.Key, '');
  Form.AddStr  ('D', ' Description ' ,  9, 11, 24, 11, 13, 40, 40, @Prot.Desc, '');
  Form.AddStr  ('S', ' Send Command ',  8, 12, 24, 12, 14, 50, 100, @Prot.SendCmd, '');
  Form.AddStr  ('R', ' Recv Command ',  8, 13, 24, 13, 14, 50, 100, @Prot.RecvCmd, '');

  Form.Execute;
  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure Configuration_ProtocolEditor;
Var
  Box      : TAnsiMenuBox;
  List     : TAnsiMenuList;
  ProtFile : File of RecProtocol;
  Prot     : RecProtocol;
  Copied   : RecProtocol;
  HasCopy  : Boolean = False;

  Procedure MakeList;
  Var
    OS : String;
  Begin
    List.Clear;

    ioReset (ProtFile, SizeOf(RecProtocol), fmRWDN);

    While Not EOF(ProtFile) Do Begin
      Read (ProtFile, Prot);

      Case Prot.OSType of
        0 : OS := 'Windows';
        1 : OS := 'Linux  ';
        2 : OS := 'OSX';
        3 : OS := 'All';
        4 : OS := 'OS/2';
      End;

      //'Active   OSID   Batch   Key   Description');

      List.Add (strPadR(strYN(Prot.Active), 6, ' ') + '   ' + strPadR(OS, 7, ' ') + '   ' + strPadR(strYN(Prot.Batch), 5, ' ') + '   ' + strPadR(Prot.Key, 4, ' ') + Prot.Desc, 0);
    End;

    List.Add ('', 2);
  End;

Begin
  Assign (ProtFile, bbsCfg.DataPath + 'protocol.dat');

  If Not ioReset(ProtFile, SizeOf(RecProtocol), fmRWDN) Then
    If Not ioReWrite(ProtFile, SizeOf(RecProtocol), fmRWDN) Then
      Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Protocol Editor ';
  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.SearchY  := 20;

  Box.Open (13, 5, 67, 20);

  WriteXY (15,  7, 112, 'Active   OSID     Batch   Key  Description');
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
                      AddRecord (ProtFile, List.Picked, SizeOf(RecProtocol));

                      Prot.OSType    := OSType;
                      Prot.Desc    := 'New protocol';
                      Prot.Key     := '!';
                      Prot.Active  := False;
                      Prot.Batch   := False;
                      Prot.SendCmd := '';
                      Prot.RecvCmd := '';

                      Write (ProtFile, Prot);

                      MakeList;
                    End;
              'D' : If List.Picked < List.ListMax Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        KillRecord (ProtFile, List.Picked, SizeOf(RecProtocol));
                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (ProtFile, List.Picked - 1);
                      Read (ProtFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (ProtFile, List.Picked, SizeOf(RecProtocol));
                      Write     (ProtFile, Copied);

                      MakeList;
                    End;

            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              Seek (ProtFile, List.Picked - 1);
              Read (ProtFile, Prot);

              EditProtocol(Prot);

              Seek  (ProtFile, List.Picked - 1);
              Write (ProtFile, Prot);
            End;
      #27 : Break;
    End;
  Until False;

  Close (ProtFile);

  Box.Close;
  List.Free;
  Box.Free;
End;

End.

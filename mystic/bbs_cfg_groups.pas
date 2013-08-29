Unit bbs_Cfg_Groups;

Interface

Procedure Configuration_GroupEditor (Msg: Boolean);

Implementation

Uses
  m_FileIO,
  m_Strings,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Cfg_Common,
  BBS_Records,
  BBS_DataBase,
  BBS_Common;

Procedure EditGroup (Var Group: RecGroup);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09Group Editor|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Open (14, 10, 67, 16);

  VerticalLine (24, 12, 14);

  Form.AddStr ('N', ' Name'  , 18, 12, 26, 12, 6, 30, 30, @Group.Name, Topic + 'Description of group');
  Form.AddStr ('A', ' Access', 16, 13, 26, 13, 8, 30, 30, @Group.ACS, Topic + 'Access level to access this group');
  Form.AddBol ('H', ' Hidden', 16, 14, 26, 14, 8,  3, @Group.Hidden, Topic + 'Group is hidden from group listing?');

  Form.Execute;

  Box.Close;
  Form.Free;
  Box.Free;
End;

Procedure Configuration_GroupEditor (Msg: Boolean);
Var
  Box       : TAnsiMenuBox;
  List      : TAnsiMenuList;
  GroupFile : File of RecGroup;
  Group     : RecGroup;
  Copied    : RecGroup;
  HasCopy   : Boolean = False;

  Procedure MakeList;
  Begin
    List.Clear;

    ioReset (GroupFile, SizeOf(RecGroup), fmRWDN);

    While Not EOF(GroupFile) Do Begin
      Read (GroupFile, Group);

      List.Add(strPadR(strI2S(FilePos(GroupFile)), 3, ' ') + '  ' + strStripPipe(Group.Name), 0);
    End;

    List.Add('', 2);
  End;

Begin
  If Msg Then
    Assign (GroupFile, bbsCfg.DataPath + 'groups_g.dat')
  Else
    Assign (GroupFile, bbsCfg.DataPath + 'groups_f.dat');

  If Not ioReset(GroupFile, SizeOf(RecGroup), fmRWDN) Then
    If Not ioReWrite(GroupFile, SizeOf(RecGroup), fmRWDN) Then
      Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.SearchY  := 20;
  List.LoChars  := #13#27#47;

  If Msg Then
    Box.Header := ' Message Group Editor '
  Else
    Box.Header := ' File Group Editor ';

  Box.Open (21, 6, 59, 20);

  If Msg Then
    WriteXY (23, 8, 112, '###  Message Group Name')
  Else
    WriteXY (23, 8, 112, '###  File Group Name');

  WriteXY (22, 9, 112,  strRep(#196, 37));
  WriteXY (22, 18, 112, strRep(#196, 37));
  WriteXY (29, 19, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (21, 9, 59, 18);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : If List.Picked > 0 Then Begin
                      AddRecord (GroupFile, List.Picked, SizeOf(RecGroup));

                      Group.Name   := 'New Group';
                      Group.ACS    := '';
                      Group.Hidden := False;

                      Write (GroupFile, Group);

                      MakeList;
                    End;
              'D' : If (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        Seek (GroupFile, List.Picked - 1);
                        Read (GroupFile, Group);

                        KillRecord (GroupFile, List.Picked, SizeOf(RecGroup));

                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (GroupFile, List.Picked - 1);
                      Read (GroupFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (GroupFile, List.Picked, SizeOf(RecGroup));
                      Write     (GroupFile, Copied);

                      MakeList;
                    End;
            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              Seek (GroupFile, List.Picked - 1);
              Read (GroupFile, Group);

              EditGroup(Group);

              Seek  (GroupFile, List.Picked - 1);
              Write (GroupFile, Group);
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;
  List.Free;
  Box.Free;

  Close (GroupFile);
End;

End.

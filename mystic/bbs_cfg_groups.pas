Unit bbs_Cfg_Groups;

Interface

Procedure Configuration_GroupEditor (Msg: Boolean);

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_cfg_Common,
  bbs_Common;

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

  Form.AddStr ('N', ' Name'  , 18, 12, 26, 12, 6, 40, 40, @Group.Name, Topic + 'Description of group');
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
  GroupFile : TBufFile;
  Group     : RecGroup;
  Copied    : RecGroup;
  HasCopy   : Boolean = False;

  Procedure MakeList;
  Begin
    List.Clear;

    GroupFile.Reset;

    While Not GroupFile.EOF Do Begin
      GroupFile.Read (Group);

      List.Add(strPadR(strI2S(GroupFile.FilePos), 3, ' ') + '  ' + strStripPipe(Group.Name), 0);
    End;

    List.Add('', 2);
  End;

Begin
  GroupFile := TBufFile.Create(2048);

  If Msg Then Begin
    If Not GroupFile.Open(Config.DataPath + 'groups_g.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(RecGroup)) Then Begin
      GroupFile.Free;
      Exit;
    End;
  End Else Begin
    If Not GroupFile.Open(Config.DataPath + 'groups_f.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(RecGroup)) Then Begin
      GroupFile.Free;
      Exit;
    End;
  End;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
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
                      GroupFile.RecordInsert (List.Picked);

                      Group.Name   := 'New Group';
                      Group.ACS    := '';
                      Group.Hidden := False;

                      GroupFile.Write (Group);

                      MakeList;
                    End;
              'D' : If (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        GroupFile.Seek (List.Picked - 1);
                        GroupFile.Read (Group);

                        GroupFile.RecordDelete (List.Picked);

                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      GroupFile.Seek (List.Picked - 1);
                      GroupFile.Read (Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      GroupFile.RecordInsert (List.Picked);
                      GroupFile.Write        (Copied);

                      MakeList;
                    End;
            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              GroupFile.Seek (List.Picked - 1);
              GroupFile.Read (Group);

              EditGroup(Group);

              GroupFile.Seek  (List.Picked - 1);
              GroupFile.Write (Group);
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;

  GroupFile.Free;
  List.Free;
  Box.Free;
End;

End.

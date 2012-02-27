Unit bbs_cfg_MsgBase;

{$I M_OPS.PAS}

Interface

Procedure Configuration_MessageBaseEditor;

Implementation

Uses
  m_Strings,
  m_FileIO,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_Cfg_Common,
  bbs_Cfg_SysCfg,
  bbs_Common;

Procedure EditMessageBase (Var MBase: RecMessageBase);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09Message Base Edit|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Index ' + strI2S(MBase.Index) + ' ';

  Box.Open (3, 5, 77, 21);

  VerticalLine (17,  6, 20);
  VerticalLine (66,  6, 20);

  Form.AddStr  ('N', ' Name'        , 11,  6, 19,  6,  6, 30, 40, @MBase.Name, Topic + 'Message base description');
  Form.AddStr  ('W', ' Newsgroup'   ,  6,  7, 19,  7, 11, 30, 60, @MBase.NewsName, Topic + 'Newsgroup name');
  Form.AddStr  ('Q', ' QWK Name'    ,  7,  8, 19,  8, 10, 13, 13, @MBase.QwkName, Topic + 'Qwk Short name');
  Form.AddStr  ('F', ' File Name'   ,  6,  9, 19,  9, 11, 30, 40, @MBase.FileName, Topic + 'Message base storage file name');
  Form.AddPath ('P', ' Path'        , 11, 10, 19, 10,  6, 30, 80, @MBase.Path, Topic + 'Message base storage path');
  Form.AddStr  ('L', ' List ACS'    ,  7, 11, 19, 11, 10, 30, 30, @MBase.ListACS, Topic + 'Access required to see in base list');
  Form.AddStr  ('R', ' Read ACS'    ,  7, 12, 19, 12, 10, 30, 30, @MBase.ReadACS, Topic + 'Access required to read messages');
  Form.AddStr  ('P', ' Post ACS'    ,  7, 13, 19, 13, 10, 30, 30, @MBase.PostACS, Topic + 'Access required to post messages');
  Form.AddStr  ('Y', ' Sysop ACS'   ,  6, 14, 19, 14, 11, 30, 30, @MBase.SysopACS, Topic + 'Access required for Sysop access');
  Form.AddNone ('D', ' Net Address' ,  4, 15, 13, Topic + 'NetMail Address');
  Form.AddStr  ('I', ' Origin'      ,  9, 16, 19, 16,  8, 30, 50, @MBase.Origin, Topic + 'Message base origin line');
  Form.AddStr  ('S', ' Sponsor'     ,  8, 17, 19, 17,  9, 30, 30, @MBase.Sponsor, Topic + 'User name of base''s sponser');
  Form.AddStr  ('H', ' Header'      ,  9, 18, 19, 18,  8, 20, 20, @MBase.Header, Topic + 'Display file name of msg header');
  Form.AddStr  ('T', ' R Template'  ,  5, 19, 19, 19, 12, 20, 20, @MBase.RTemplate, Topic + 'Template for full screen reader');
  Form.AddStr  ('M', ' L Template'  ,  5, 20, 19, 20, 12, 20, 20, @MBase.ITemplate, Topic + 'Template for lightbar message list');

  Form.AddAttr ('Q', ' Quote Color' , 53,  6, 68,  6, 13, @MBase.ColQuote, Topic + 'Color for quoted text');
  Form.AddAttr ('X', ' Text Color'  , 54,  7, 68,  7, 12, @MBase.ColText, Topic + 'Color for message text');
  Form.AddAttr ('E', ' Tear Color'  , 54,  8, 68,  8, 12, @MBase.ColTear, Topic + 'Color for tear line');
  Form.AddAttr ('G', ' Origin Color', 52,  9, 68,  9, 14, @MBase.ColOrigin, Topic + 'Color for origin line');
  Form.AddAttr ('K', ' Kludge Color', 52, 10, 68, 10, 14, @MBase.ColKludge, Topic + 'Color for kludge line');
  Form.AddWord ('M', ' Max Msgs'    , 56, 11, 68, 11, 10, 5, 0, 65535, @MBase.MaxMsgs, Topic + 'Maximum number of message in base');
  Form.AddWord ('1', ' Max Msg Age' , 53, 12, 68, 12, 13, 5, 0, 65535, @MBase.MaxAge, Topic + 'Maximum age (days) to keep messages');
  Form.AddTog  ('2', ' New Scan'    , 56, 13, 68, 13, 10, 6, 0, 2, 'No Yes Forced', @MBase.DefNScan, Topic + 'Newscan default for users');
  Form.AddTog  ('3', ' QWK Scan'    , 56, 14, 68, 14, 10, 6, 0, 2, 'No Yes Forced', @MBase.DefQScan, Topic + 'QWKscan default for users');
  Form.AddBits ('4', ' Real Names'  , 54, 15, 68, 15, 12, MBRealNames, @MBase.Flags, Topic + 'Use real names in this base?');
  Form.AddBits ('5', ' Autosigs'    , 56, 16, 68, 16, 10, MBAutoSigs, @MBase.Flags, Topic + 'Allow auto signatures in this base?');
  Form.AddBits ('6', ' Kill Kludge' , 53, 17, 68, 17, 13, MBKillKludge, @MBase.Flags, Topic + 'Filter out kludge lines');
  Form.AddBits ('V', ' Private'     , 57, 18, 68, 18,  9, MBPrivate, @MBase.Flags, Topic + 'Is this a private base?');
  Form.AddTog  ('A', ' Base Type'   , 55, 19, 68, 19, 11,  9,  0, 3, 'Local EchoMail Newsgroup Netmail', @MBase.NetType, Topic + 'Message base type');
  Form.AddTog  ('B', ' Base Format' , 53, 20, 68, 20, 13,  6,  0, 1, 'JAM Squish', @MBase.BaseType, Topic + 'Message base storage format');

  Repeat
    WriteXY (19, 15, 113, strPadR(strAddr2Str(Config.NetAddress[MBase.NetAddr]), 19, ' '));

    Case Form.Execute of
      'D' : MBase.NetAddr := Configuration_EchoMailAddress(False);
      #27 : Break;
    End;
  Until False;

  MBase.NewsName := strReplace(MBase.NewsName, ' ', '.');

  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure Configuration_MessageBaseEditor;
Var
  Box       : TAnsiMenuBox;
  List      : TAnsiMenuList;
  MIndex    : LongInt;
  Copied    : RecMessageBase;
  HasCopy   : Boolean = False;
  MBaseFile : TBufFile;
  MBase     : RecMessageBase;

  Procedure MakeList;
  Var
    Tag : Byte;
  Begin
    List.Clear;

    MBaseFile.Reset;

    While Not MBaseFile.EOF Do Begin
      If MBaseFile.FilePos = 0 Then Tag := 2 Else Tag := 0;

      MBaseFile.Read (MBase);

      List.Add(strPadR(strI2S(MBaseFile.FilePos - 1), 5, ' ') + '  ' + strStripMCI(MBase.Name), Tag);
    End;

    List.Add('', 2);
  End;

  Procedure AssignRecord (Email: Boolean);
  Begin
    MIndex := List.Picked;

    MBaseFile.Reset;

    While Not MBaseFile.EOF Do Begin
      MBaseFile.Read (MBase);

      If MIndex = MBase.Index Then Begin
        Inc (MIndex);
        MBaseFile.Reset;
      End;
    End;

    MBaseFile.RecordInsert (List.Picked);

    FillChar (MBase, SizeOf(RecMessageBase), 0);

    With MBase Do Begin
      Index       := MIndex;
      FileName    := 'new';
      Path        := Config.MsgsPath;
      Name        := 'New Base';
      DefNScan    := 1;
      DefQScan    := 1;
      MaxMsgs     := 500;
      MaxAge      := 365;
      Header      := 'msghead';
      RTemplate   := 'ansimrd';
      ITemplate   := 'ansimlst';
      SysopACS    := 's255';
      NetAddr     := 1;
      ColQuote    := Config.ColorQuote;
      ColText     := Config.ColorText;
      ColTear     := Config.ColorTear;
      ColOrigin   := Config.ColorOrigin;
      ColKludge   := Config.ColorKludge;
      Flags       := MBAutoSigs or MBKillKludge;

      If Email Then Begin
        FileName := 'email';
        Name     := 'Electronic Mail';
        Index    := 1;
        ListACS  := '%';
        Flags    := Flags or MBPrivate;
      End;
    End;

    MBaseFile.Write(MBase);
  End;

Begin
  MBaseFile := TBufFile.Create(4096);

  If Not MBaseFile.Open(Config.DataPath + 'mbases.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(RecMessageBase)) Then Begin
    MBaseFile.Free;
    Exit;
  End;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.AllowTag := True;

  If MBaseFile.FileSize = 0 Then AssignRecord(True);

  Box.Open (15, 5, 65, 21);

  WriteXY (17,  6, 112, '#####  Message Base Description');
  WriteXY (16,  7, 112, strRep('Ä', 49));
  WriteXY (16, 19, 112, strRep('Ä', 49));
  WriteXY (29, 20, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (15, 7, 65, 19);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : If List.Picked > 1 Then Begin
                      AssignRecord(False);
                      MakeList;
                    End;
              'D' : If (List.Picked > 1) and (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        MBaseFile.Seek (List.Picked - 1);
                        MBaseFile.Read (MBase);

                        MBaseFile.RecordDelete (List.Picked);

                        If ShowMsgBox(1, 'Delete data files?') Then Begin
                          FileErase (MBase.Path + MBase.FileName + '.jhr');
                          FileErase (MBase.Path + MBase.FileName + '.jlr');
                          FileErase (MBase.Path + MBase.FileName + '.jdt');
                          FileErase (MBase.Path + MBase.FileName + '.jdx');
                          FileErase (MBase.Path + MBase.FileName + '.sqd');
                          FileErase (MBase.Path + MBase.FileName + '.sqi');
                          FileErase (MBase.Path + MBase.FileName + '.sql');
                          FileErase (MBase.Path + MBase.FileName + '.scn');
                        End;

                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      MBaseFile.Seek (List.Picked - 1);
                      MBaseFile.Read (Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      MBaseFile.RecordInsert (List.Picked);
                      MBaseFile.Write        (Copied);

                      MakeList;
                    End;

            End;
      #13 : If List.Picked < List.ListMax Then Begin
              MBaseFile.Seek (List.Picked - 1);
              MBaseFile.Read (MBase);

              EditMessageBase (MBase);

              MBaseFile.Seek  (List.Picked - 1);
              MBaseFile.Write (MBase);
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;

  MBaseFile.Close;
  MBaseFile.Free;
  List.Free;
  Box.Free;
End;

End.

Unit bbs_cfg_MsgBase;

{$I M_OPS.PAS}

Interface

Procedure Configuration_MessageBaseEditor;

Implementation

Uses
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_Bits,
  m_QuickSort,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_Cfg_Common,
  bbs_Cfg_SysCfg,
  bbs_Common;

Type
  RecMessageBaseFile = File of RecMessageBase;

Procedure SortMessageBases (Var List: TAnsiMenuList; Var MBaseFile: RecMessageBaseFile);
Var
  TempBase  : RecMessageBase;
  TempFile  : File of RecMessageBase;
  Sort      : TQuickSort;
  SortFirst : Word;
  SortLast  : Word;
  SortType  : Byte;
  Count     : Word;
Begin
  If Not GetSortRange(List, SortFirst, SortLast) Then Exit;

  Case GetCommandOption(10, 'B-Base Name|F-File Name|N-Network|A-Abort|') of
    'B' : SortType := 1;
    'F' : SortType := 2;
    'N' : SortType := 3;
    'A' : Exit;
  End;

  ShowMsgBox (3, ' Sorting... ');

  Sort := TQuickSort.Create;

  For Count := SortFirst to SortLast Do Begin
    Seek (MBaseFile, Count - 1);
    Read (MBaseFile, TempBase);

    Case SortType of
      1 : Sort.Add (strUpper(strStripPipe(TempBase.Name)), Count - 1);
      2 : Sort.Add (strUpper(TempBase.FileName), Count - 1);
      3 : Sort.Add (strI2S(TempBase.NetAddr), Count - 1);
    End;
  End;

  Sort.Sort (1, Sort.Total, qAscending);

  Close  (MBaseFile);
  ReName (MBaseFile, Config.DataPath + 'mbases.sortbak');

  Assign (TempFile, Config.DataPath + 'mbases.sortbak');
  Reset  (TempFile);

  Assign  (MBaseFile, Config.DataPath + 'mbases.dat');
  ReWrite (MBaseFile);

  While FilePos(TempFile) < SortFirst - 1 Do Begin
    Read  (TempFile, TempBase);
    Write (MBaseFile, TempBase);
  End;

  For Count := 1 to Sort.Total Do Begin
    Seek  (TempFile, Sort.Data[Count]^.Ptr);
    Read  (TempFile, TempBase);
    Write (MBaseFile, TempBase);
  End;

  Seek (TempFile, SortLast);

  While Not Eof(TempFile) Do Begin
    Read  (TempFile, TempBase);
    Write (MBaseFile, TempBase);
  End;

  Close (TempFile);
  Erase (TempFile);

  Sort.Free;
End;

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
  Form.AddStr  ('C', ' Post ACS'    ,  7, 13, 19, 13, 10, 30, 30, @MBase.PostACS, Topic + 'Access required to post messages');
  Form.AddStr  ('Y', ' Sysop ACS'   ,  6, 14, 19, 14, 11, 30, 30, @MBase.SysopACS, Topic + 'Access required for Sysop access');
  Form.AddNone ('D', ' Net Address' ,  4, 15, 19, 15, 13, Topic + 'NetMail Address');
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
  Copied    : RecMessageBase;
  HasCopy   : Boolean = False;
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;

  Procedure GlobalEdit (Global: RecMessageBase);
  Const
    ChangeStr = 'Change this value for all tagged bases?';
  Var
    GBox   : TAnsiMenuBox;
    Form   : TAnsiMenuForm;
    Active : Array[1..26] of Boolean;
    Count  : LongInt;
    Topic  : String;
  Begin
    FillChar (Active, SizeOf(Active), 0);

    Topic := '|03(|09Global MsgBase Edit|03) |01-|09> |15';
    GBox  := TAnsiMenuBox.Create;
    Form  := TAnsiMenuForm.Create;

    GBox.Header := ' CTRL-U/Update  ESC/Abort ';

    GBox.Open (6, 5, 75, 21);

    VerticalLine (26, 7, 19);
    VerticalLine (64, 7, 19);

    For Count := 1 to 13 Do
      Form.AddBol ('!', '> ',  8, 6 + Count, 10, 6 + Count, 2, 3, @Active[Count], Topic + ChangeStr);

    Form.AddPath ('P', ' Path'        , 20,  7, 28,  7,  6, 16, 80, @Global.Path, Topic + 'Message base storage path');
    Form.AddStr  ('L', ' List ACS'    , 16,  8, 28,  8, 10, 16, 30, @Global.ListACS, Topic + 'Access required to see in base list');
    Form.AddStr  ('R', ' Read ACS'    , 16,  9, 28,  9, 10, 16, 30, @Global.ReadACS, Topic + 'Access required to read messages');
    Form.AddStr  ('C', ' Post ACS'    , 16, 10, 28, 10, 10, 16, 30, @Global.PostACS, Topic + 'Access required to post messages');
    Form.AddStr  ('Y', ' Sysop ACS'   , 15, 11, 28, 11, 11, 16, 30, @Global.SysopACS, Topic + 'Access required for Sysop access');
    Form.AddNone ('D', ' Net Address' , 13, 12, 28, 12, 13, Topic + 'NetMail Address');
    Form.AddStr  ('I', ' Origin'      , 18, 13, 28, 13,  8, 16, 50, @Global.Origin, Topic + 'Message base origin line');
    Form.AddStr  ('S', ' Sponsor'     , 17, 14, 28, 14,  9, 16, 30, @Global.Sponsor, Topic + 'User name of base''s sponser');
    Form.AddStr  ('H', ' Header'      , 18, 15, 28, 15,  8, 16, 20, @Global.Header, Topic + 'Display file name of msg header');
    Form.AddStr  ('T', ' R Template'  , 14, 16, 28, 16, 12, 16, 20, @Global.RTemplate, Topic + 'Template for full screen reader');
    Form.AddStr  ('M', ' L Template'  , 14, 17, 28, 17, 12, 16, 20, @Global.ITemplate, Topic + 'Template for lightbar message list');
    Form.AddTog  ('A', ' Base Type'   , 15, 18, 28, 18, 11,  9,  0, 3, 'Local EchoMail Newsgroup Netmail', @Global.NetType, Topic + 'Message base type');
    Form.AddTog  ('B', ' Base Format' , 13, 19, 28, 19, 13,  6,  0, 1, 'JAM Squish', @Global.BaseType, Topic + 'Message base storage format');

    For Count := 1 to 13 Do
      Form.AddBol ('!', '> ', 45, 6 + Count, 47, 6 + Count, 2, 3, @Active[Count + 13], Topic + ChangeStr);

    Form.AddAttr ('Q', ' Quote Color' , 51,  7, 66,  7, 13, @Global.ColQuote, Topic + 'Color for quoted text');
    Form.AddAttr ('X', ' Text Color'  , 52,  8, 66,  8, 12, @Global.ColText, Topic + 'Color for message text');
    Form.AddAttr ('E', ' Tear Color'  , 52,  9, 66,  9, 12, @Global.ColTear, Topic + 'Color for tear line');
    Form.AddAttr ('G', ' Origin Color', 50, 10, 66, 10, 14, @Global.ColOrigin, Topic + 'Color for origin line');
    Form.AddAttr ('K', ' Kludge Color', 50, 11, 66, 11, 14, @Global.ColKludge, Topic + 'Color for kludge line');
    Form.AddWord ('M', ' Max Msgs'    , 54, 12, 66, 12, 10, 5, 0, 65535, @Global.MaxMsgs, Topic + 'Maximum number of message in base');
    Form.AddWord ('1', ' Max Msg Age' , 51, 13, 66, 13, 13, 5, 0, 65535, @Global.MaxAge, Topic + 'Maximum age (days) to keep messages');
    Form.AddTog  ('2', ' New Scan'    , 54, 14, 66, 14, 10, 6, 0, 2, 'No Yes Forced', @Global.DefNScan, Topic + 'Newscan default for users');
    Form.AddTog  ('3', ' QWK Scan'    , 54, 15, 66, 15, 10, 6, 0, 2, 'No Yes Forced', @Global.DefQScan, Topic + 'QWKscan default for users');
    Form.AddBits ('4', ' Real Names'  , 52, 16, 66, 16, 12, MBRealNames, @Global.Flags, Topic + 'Use real names in this base?');
    Form.AddBits ('5', ' Autosigs'    , 54, 17, 66, 17, 10, MBAutoSigs, @Global.Flags, Topic + 'Allow auto signatures in this base?');
    Form.AddBits ('6', ' Kill Kludge' , 51, 18, 66, 18, 13, MBKillKludge, @Global.Flags, Topic + 'Filter out kludge lines');
    Form.AddBits ('V', ' Private'     , 55, 19, 66, 19,  9, MBPrivate, @Global.Flags, Topic + 'Is this a private base?');

    Form.LoExitChars := #21#27;

    Repeat
      WriteXY (28, 12, 113, strPadR(strAddr2Str(Config.NetAddress[Global.NetAddr]), 19, ' '));

      Case Form.Execute of
        'D' : Global.NetAddr := Configuration_EchoMailAddress(False);
        #21 : If ShowMsgBox(1, 'Update with these settings?') Then Begin
                For Count := 1 to List.ListMax Do
                  If List.List[Count]^.Tagged = 1 Then Begin
                    Seek (MBaseFile, Count - 1);
                    Read (MBaseFile, MBase);

                    If Active[01] Then MBase.Path := Global.Path;
                    If Active[02] Then MBase.ListACS := Global.ListACS;
                    If Active[03] Then MBase.ReadACS := Global.ReadACS;
                    If Active[04] Then MBase.PostACS := Global.PostACS;
                    If Active[05] Then MBase.SysopACS := Global.SysopACS;
                    If Active[06] Then MBase.NetAddr := Global.NetAddr;
                    If Active[07] Then MBase.Origin := Global.Origin;
                    If Active[08] Then MBase.Sponsor := Global.Sponsor;
                    If Active[09] Then MBase.Header := Global.Header;
                    If Active[10] Then MBase.RTemplate := Global.RTemplate;
                    If Active[11] Then MBase.ITemplate := Global.ITemplate;
                    If Active[12] Then MBase.NetType := Global.NetType;
                    If Active[13] Then MBase.BaseType := Global.BaseType;

                    If Active[14] Then MBase.ColQuote := Global.ColQuote;
                    If Active[15] Then MBase.ColText := Global.ColText;
                    If Active[16] Then MBase.ColTear := Global.ColTear;
                    If Active[17] Then MBase.ColOrigin := Global.ColOrigin;
                    If Active[18] Then MBase.ColKludge := Global.ColKludge;
                    If Active[19] Then MBase.MaxMsgs := Global.MaxMsgs;
                    If Active[20] Then MBase.MaxAge := Global.MaxAge;
                    If Active[21] Then MBase.DefNScan := Global.DefNScan;
                    If Active[22] Then MBase.DefQScan := Global.DefQScan;
                    If Active[23] Then BitSet(1, 4, MBase.Flags, (Global.Flags AND MBRealNames <> 0));
                    If Active[24] Then BitSet(3, 4, MBase.Flags, (Global.Flags AND MBAutoSigs <> 0));
                    If Active[25] Then BitSet(2, 4, MBase.Flags, (Global.Flags AND MBKillKludge <> 0));
                    If Active[26] Then BitSet(5, 4, MBase.Flags, (Global.Flags AND MBPrivate <> 0));

                    Seek  (MBaseFile, Count - 1);
                    Write (MBaseFile, MBase);
                  End;

                Break;
              End;
        #27 : Break;
      End;
    Until False;

    Form.Free;

    GBox.Close;
    GBox.Free;
  End;

  Procedure MakeList;
  Var
    Tag : Byte;
  Begin
    List.Clear;

    Reset (MBaseFile);

    While Not EOF(MBaseFile) Do Begin
      If FilePos(MBaseFile) = 0 Then Tag := 2 Else Tag := 0;

      Read (MBaseFile, MBase);

      List.Add(strPadR(strI2S(FilePos(MBaseFile) - 1), 5, ' ') + '  ' + strPadR(strStripMCI(MBase.Name), 35, ' ') + ' ' + strPadL(strAddr2Str(Config.NetAddress[MBase.NetAddr]), 12, ' '), Tag);
    End;

    List.Add('', 2);
  End;

  Function GetPermanentIndex (Start: LongInt) : LongInt;
  Var
    TempBase : RecMessageBase;
    SavedRec : LongInt;
  Begin
    Result   := Start;
    SavedRec := FilePos(MBaseFile);

    Reset (MBaseFile);

    While Not EOF(MBaseFile) Do Begin
      Read (MBaseFile, TempBase);

      If Result = TempBase.Index Then Begin
        If Result >= 2000000 Then Result := 0;

        Inc   (Result);
        Reset (MBaseFile);
      End;
    End;

    Seek (MBaseFile, SavedRec);
  End;

  Procedure AssignRecord (Email: Boolean);
  Begin
    AddRecord (MBaseFile, List.Picked, SizeOf(RecMessageBase));

    FillChar (MBase, SizeOf(RecMessageBase), 0);

    With MBase Do Begin
      Index       := GetPermanentIndex(FileSize(MBaseFile));
      Created     := CurDateDos;
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
      Origin      := Config.Origin;
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

    Write(MBaseFile, MBase);
  End;

Begin
  Assign (MBaseFile, Config.DataPath + 'mbases.dat');

  If Not ioReset(MBaseFile, SizeOf(MBase), fmRWDN) Then
    Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.AllowTag := True;
  List.SearchY  := 20;

  If FileSize(MBaseFile) = 0 Then AssignRecord(True);

  Box.Open (11, 5, 69, 20);

  WriteXY (13,  6, 112, '#####  Message Base Description                 Network');
  WriteXY (12,  7, 112, strRep('Ä', 57));
  WriteXY (12, 18, 112, strRep('Ä', 57));
  WriteXY (29, 19, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (11, 7, 69, 18);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(8, 'I-Insert|D-Delete|C-Copy|P-Paste|G-Global|S-Sort|') of
              'I' : If List.Picked > 1 Then Begin
                      AssignRecord(False);
                      MakeList;
                    End;
              'D' : If (List.Picked > 1) and (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        Seek (MBaseFile, List.Picked - 1);
                        Read (MBaseFile, MBase);

                        KillRecord (MBaseFile, List.Picked, SizeOf(MBase));

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
                      Seek (MBaseFile, List.Picked - 1);
                      Read (MBaseFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy And (List.Picked > 1) Then Begin
                      AddRecord (MBaseFile, List.Picked, SizeOf(MBase));

                      Copied.Index   := GetPermanentIndex(FileSize(MBaseFile));
                      Copied.Created := CurDateDos;

                      Write (MBaseFile, Copied);

                      MakeList;
                    End;
              'G' : If List.Marked = 0 Then
                      ShowMsgBox(0, 'Use TAB to tag areas for global edit')
                    Else Begin
                      If (List.Picked > 1) And (List.Picked < List.ListMax) Then Begin
                        Seek (MBaseFile, List.Picked - 1);
                        Read (MBaseFile, MBase);
                      End Else
                        FillChar (MBase, SizeOf(MBase), 0);

                      GlobalEdit (MBase);
                    End;
              'S' : SortMessageBases (List, MBaseFile);
            End;
      #13 : If List.Picked < List.ListMax Then Begin
              Seek (MBaseFile, List.Picked - 1);
              Read (MBaseFile, MBase);

              EditMessageBase (MBase);

              Seek  (MBaseFile, List.Picked - 1);
              Write (MBaseFile, MBase);
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;

  Close (MBaseFile);

  List.Free;
  Box.Free;
End;

End.

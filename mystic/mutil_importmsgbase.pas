Unit MUTIL_ImportMsgBase;

{$I M_OPS.PAS}

Interface

Procedure uImportMessageBases;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings,
  mUtil_Common,
  mUtil_Status,
  bbs_Common;

Procedure uImportMessageBases;
Var
  CreatedBases : LongInt = 0;
  MBase        : RecMessageBase;
  Info         : SearchRec;
  BaseName     : String;
  BaseExt      : String;
  Count        : Byte;
Begin
  ProcessName   ('Import Message Bases', True);
  ProcessResult (rWORKING, False);

  FindFirst (bbsConfig.MsgsPath + '*', AnyFile, Info);

  While DosError = 0 Do Begin
    BaseName := JustFileName(Info.Name);
    BaseExt  := strUpper(JustFileExt(Info.Name));

    If ((BaseExt = 'JHR') or (BaseExt = 'SQD')) And (BaseName <> '') And Not IsDupeMBase(BaseName) Then Begin
      ProcessStatus (BaseName, False);

      FillChar (MBase, SizeOf(MBase), #0);
      Inc      (CreatedBases);

      MBase.Index     := GenerateMBaseIndex;
      MBase.Name      := BaseName;
      MBase.QWKName   := BaseName;
      MBase.NewsName  := strReplace(BaseName, ' ', '.');
      MBase.FileName  := BaseName;
      MBase.Path      := bbsConfig.MsgsPath;
      MBase.NetType   := INI.ReadInteger(Header_IMPORTMB, 'net_type', 0);
      MBase.ColQuote  := bbsConfig.ColorQuote;
      MBase.ColText   := bbsConfig.ColorText;
      MBase.ColTear   := bbsConfig.ColorTear;
      MBase.ColOrigin := bbsConfig.ColorOrigin;
      MBase.ColKludge := bbsConfig.ColorKludge;
      MBase.Origin    := bbsConfig.Origin;
      MBase.BaseType  := Ord(BaseExt = 'SQD');
      MBase.ListACS   := INI.ReadString(Header_IMPORTMB, 'acs_list', '');
      MBase.ReadACS   := INI.ReadString(Header_IMPORTMB, 'acs_read', '');
      MBase.PostACS   := INI.ReadString(Header_IMPORTMB, 'acs_post', '');
      MBase.NewsACS   := INI.ReadString(Header_IMPORTMB, 'acs_news', '');
      MBase.SysopACS  := INI.ReadString(Header_IMPORTMB, 'acs_sysop', 's255');
      MBase.Header    := INI.ReadString(Header_IMPORTMB, 'header', 'msghead');
      MBase.RTemplate := INI.ReadString(Header_IMPORTMB, 'read_template', 'ansimrd');
      MBase.ITemplate := INI.ReadString(Header_IMPORTMB, 'index_template', 'ansimlst');
      MBase.MaxMsgs   := INI.ReadInteger(Header_IMPORTMB, 'max_msgs', 500);
      MBase.MaxAge    := INI.ReadInteger(Header_IMPORTMB, 'max_msgs_age', 365);
      MBase.DefNScan  := INI.ReadInteger(Header_IMPORTMB, 'new_scan', 1);
      MBase.DefQScan  := INI.ReadInteger(Header_IMPORTMB, 'qwk_scan', 1);
      MBase.NetAddr   := 1;

      For Count := 1 to 30 Do
        If strAddr2Str(bbsConfig.NetAddress[Count]) = INI.ReadString(Header_IMPORTNA, 'netaddress', '') Then Begin
          MBase.NetAddr := Count;

          Break;
        End;

      If INI.ReadString(Header_IMPORTMB, 'use_autosig', '1') = '1' Then
        MBase.Flags := MBase.Flags OR MBAutoSigs;

      If INI.ReadString(Header_IMPORTMB, 'use_realname', '0') = '1' Then
        MBase.Flags := MBase.Flags OR MBRealNames;

      If INI.ReadString(Header_IMPORTMB, 'kill_kludge', '1') = '1' Then
        MBase.Flags := MBase.Flags OR MBKillKludge;

      If INI.ReadString(Header_IMPORTMB, 'private_base', '0') = '1' Then
        MBase.Flags := MBase.Flags OR MBPrivate;

      AddMessageBase(MBase);
    End;

    FindNext(Info);
  End;

  FindClose(Info);

  ProcessStatus ('Created |15' + strI2S(CreatedBases) + ' |07base(s)', True);
  ProcessResult (rDONE, True);
End;

End.

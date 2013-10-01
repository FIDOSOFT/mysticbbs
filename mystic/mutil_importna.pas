Unit MUTIL_ImportNA;

{$I M_OPS.PAS}

Interface

Procedure uImportNA;

Implementation

Uses
  m_Strings,
  mUtil_Common,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase;

Procedure uImportNA;
Var
  CreatedBases : LongInt = 0;
  InFile       : Text;
  Str          : String;
  Buffer       : Array[1..2048] of Byte;
  TagName      : String;
  BaseName     : String;
  MBase        : RecMessageBase;
  Count        : Byte;
Begin
  ProcessName   ('Import FIDONET.NA', True);
  ProcessResult (rWORKING, False);

  Assign     (InFile, INI.ReadString(Header_IMPORTNA, 'filename', 'fidonet.na'));
  SetTextBuf (InFile, Buffer);

  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot find NA file', True);
    ProcessResult (rWARN, True);

    Exit;
  End;

  While Not Eof(InFile) Do Begin
    ReadLn(InFile, Str);

    Str := strReplace(strStripB(Str, ' '), #9, ' ');

    If (Str[1] = ';') or (Str = '') Then Continue;

    TagName  := strStripLow(strWordGet(1, Str, ' '));
    BaseName := strStripLow(strStripB(Copy(Str, Pos(' ', Str), 255), ' '));

    ProcessStatus (BaseName, False);

    If Not IsDupeMBase(TagName) Then Begin
      FillChar (MBase, SizeOf(MBase), #0);
      Inc      (CreatedBases);

      MBase.Index     := GenerateMBaseIndex;
      MBase.Name      := BaseName;
      MBase.QWKName   := TagName;
      MBase.NewsName  := strReplace(BaseName, ' ', '.');
      MBase.EchoTag   := TagName;
      MBase.FileName  := TagName;
      MBase.Path      := bbsCfg.MsgsPath;
      MBase.NetType   := 1;
      MBase.ColQuote  := bbsCfg.ColorQuote;
      MBase.ColText   := bbsCfg.ColorText;
      MBase.ColTear   := bbsCfg.ColorTear;
      MBase.ColOrigin := bbsCfg.ColorOrigin;
      MBase.ColKludge := bbsCfg.ColorKludge;
      MBase.Origin    := bbsCfg.Origin;
      MBase.BaseType  := strS2I(INI.ReadString(Header_IMPORTNA, 'base_format', '0'));
      MBase.ListACS   := INI.ReadString(Header_IMPORTNA, 'acs_list', '');
      MBase.ReadACS   := INI.ReadString(Header_IMPORTNA, 'acs_read', '');
      MBase.PostACS   := INI.ReadString(Header_IMPORTNA, 'acs_post', '');
      MBase.NewsACS   := INI.ReadString(Header_IMPORTNA, 'acs_news', '');
      MBase.SysopACS  := INI.ReadString(Header_IMPORTNA, 'acs_sysop', 's255');
      MBase.Header    := INI.ReadString(Header_IMPORTNA, 'header', 'msghead');
      MBase.RTemplate := INI.ReadString(Header_IMPORTNA, 'read_template', 'ansimrd');
      MBase.ITemplate := INI.ReadString(Header_IMPORTNA, 'index_template', 'ansimlst');
      MBase.MaxMsgs   := strS2I(INI.ReadString(Header_IMPORTNA, 'max_msgs', '500'));
      MBase.MaxAge    := strS2I(INI.ReadString(Header_IMPORTNA, 'max_msgs_age', '365'));
      MBase.DefNScan  := strS2I(INI.ReadString(Header_IMPORTNA, 'new_scan', '1'));
      MBase.DefQScan  := strS2I(INI.ReadString(Header_IMPORTNA, 'qwk_scan', '1'));
      MBase.NetAddr   := 1;

      MBase.FileName := strReplace(MBase.FileName, '/', '_');
      MBase.FileName := strReplace(MBase.FileName, '\', '_');

      For Count := 1 to 30 Do
        If Addr2Str(bbsCfg.NetAddress[Count]) = INI.ReadString(Header_IMPORTNA, 'netaddress', '') Then Begin
          MBase.NetAddr := Count;
          Break;
        End;

      If INI.ReadString(Header_IMPORTNA, 'lowercase_filename', '1') = '1' Then
        MBase.FileName := strLower(MBase.FileName);

      If INI.ReadString(Header_IMPORTNA, 'use_autosig', '1') = '1' Then
        MBase.Flags := MBase.Flags OR MBAutoSigs;

      If INI.ReadString(Header_IMPORTNA, 'use_realname', '0') = '1' Then
        MBase.Flags := MBase.Flags OR MBRealNames;

      If INI.ReadString(Header_IMPORTNA, 'kill_kludge', '1') = '1' Then
        MBase.Flags := MBase.Flags OR MBKillKludge;

      If INI.ReadString(Header_IMPORTNA, 'private_base', '0') = '1' Then
        MBase.Flags := MBase.Flags OR MBPrivate;

      AddMessageBase(MBase);
    End;
  End;

  Close (InFile);

  ProcessStatus ('Created |15' + strI2S(CreatedBases) + ' |07base(s)', True);
  ProcessResult (rDONE, True);
End;

End.

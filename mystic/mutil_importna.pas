Unit MUTIL_ImportNA;

{$I M_OPS.PAS}

Interface

Procedure uImportNA;

Implementation

Uses
  m_Strings,
  mutil_Common,
  mutil_Status;

Procedure uImportNA;
Var
  CreatedBases : LongInt = 0;
  InFile       : Text;
  Str          : String;
  Buffer       : Array[1..2048] of Byte;
  TagName      : String;
  BaseName     : String;
  MBaseFile    : File of RecMessageBase;
  MBase        : RecMessageBase;
  Count        : Byte;
Begin
  ProcessName   ('Import FIDONET.NA', True);
  ProcessResult (rWORKING, False);

  Assign     (InFile, INI.ReadString(Header_IMPORTNA, 'filename', 'fidonet.na'));
  SetTextBuf (InFile, Buffer);

  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot find NA file');
    ProcessResult (rWARN, True);

    Exit;
  End;

  While Not Eof(InFile) Do Begin
    ReadLn(InFile, Str);

    Str := strStripB(Str, ' ');

    If (Str[1] = ';') or (Str = '') Then Continue;

    TagName  := strWordGet(1, Str, ' ');
    BaseName := strStripB(Copy(Str, Pos(' ', Str), 255), ' ');

    ProcessStatus (BaseName);

    If Not IsDupeMBase(TagName) Then Begin
      FillChar (MBase, SizeOf(MBase), #0);
      Inc      (CreatedBases);

      MBase.Index     := GenerateMBaseIndex;
      MBase.Name      := BaseName;
      MBase.QWKName   := TagName;
      MBase.NewsName  := strReplace(BaseName, ' ', '.');
      MBase.FileName  := TagName;
      MBase.Path      := bbsConfig.MsgsPath;
      MBase.NetType   := 1;
      MBase.ColQuote  := bbsConfig.ColorQuote;
      MBase.ColText   := bbsConfig.ColorText;
      MBase.ColTear   := bbsConfig.ColorTear;
      MBase.ColOrigin := bbsConfig.ColorOrigin;
      MBase.ColKludge := bbsConfig.ColorKludge;
      MBase.Origin    := bbsConfig.Origin;
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

      For Count := 1 to 30 Do
        If strAddr2Str(bbsConfig.NetAddress[Count]) = INI.ReadString(Header_IMPORTNA, 'netaddress', '') Then Begin
          MBase.NetAddr := Count;
          Break;
        End;

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

  ProcessStatus ('Created |15' + strI2S(CreatedBases) + ' |07base(s)');
  ProcessResult (rDONE, True);

  BarOne.Update (100, 100);
  BarAll.Update (ProcessPos, ProcessTotal);
End;

End.

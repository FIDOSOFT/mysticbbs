Unit MUTIL_EchoImport;

{$I M_OPS.PAS}

Interface

Procedure uEchoImport;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings,
  BBS_Common,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish,
  mUtil_Common,
  mUtil_Status,
  mUtil_EchoCore;

// Also create SavePKTMsgToFile and change export to use it... and for
// downlinks too

Procedure SavePKTMsgToBase (Var MB: PMsgBaseABS; Var PKT: TPKTReader; Netmail: Boolean);
Var
  Count : LongInt;
Begin
  MB^.StartNewMsg;

  If NetMail Then
    MB^.SetMailType (mmtNetMail)
  Else
    MB^.SetMailType (mmtEchoMail);

  MB^.SetLocal (False);
  MB^.SetOrig  (PKT.Orig);
  MB^.SetDest  (PKT.Dest);

  MB^.SetPriv     ((PKT.MsgHDR.Attribute AND pktPrivate <> 0) OR NetMail);
  MB^.SetCrash    (PKT.MsgHDR.Attribute AND pktCrash    <> 0);
  MB^.SetRcvd     (PKT.MsgHDR.Attribute AND pktReceived <> 0);
  //MB^.SetSent   (PKT.MsgHDR.Attribute AND pktSent     <> 0);
  MB^.SetSent     (False);  // force to send to downlinks?
  MB^.SetHold     (PKT.MsgHDR.Attribute AND pktHold     <> 0);
  MB^.SetKillSent (PKT.MsgHDR.Attribute AND pktKillSent <> 0);

  MB^.SetFrom     (PKT.MsgFrom);
  MB^.SetTo       (PKT.MsgTo);
  MB^.SetSubj     (PKT.MsgSubj);
  MB^.SetDate     (PKT.MsgDate);
  MB^.SetTime     (PKT.MsgTime);

  For Count := 1 to PKT.MsgLines Do Begin
    If {strip seenbys and } Copy(PKT.MsgText[Count]^, 1, 9) = 'SEEN-BY: ' Then
      Continue;

    MB^.DoStringLn(PKT.MsgText[Count]^);
  End;

  MB^.WriteMsg;
End;

Procedure uEchoImport;
Var
  TotalEcho   : LongInt;
  TotalNet    : LongInt;
  TotalDupes  : LongInt;
  EchoNode    : RecEchoMailNode;
  DupeIndex   : LongInt;
  DupeMBase   : RecMessageBase;
  CreateBases : Boolean;
  Dupes       : TPKTDupe;

  Procedure ImportNetMailpacket (ArcFN: String);
  Var
    PKT     : TPKTReader;
    MBase   : RecMessageBase;
    MsgBase : PMsgBaseABS;
  Begin
    PKT := TPKTReader.Create;

    If PKT.Open (bbsConfig.InboundPath + ArcFN) Then Begin
      If GetMBaseByNetZone (PKT.PKTHeader.DestZone, MBase) Then Begin
        MessageBaseOpen(MsgBase, MBase);

        While PKT.GetMessage(True) Do Begin
          // Check for AreaFix, etc here

          SavePKTMsgToBase(MsgBase, PKT, True);

          Log (2, '+', '      Netmail ' + MBase.EchoTag + ' from ' + PKT.MsgFrom + ' to ' + PKT.MsgTo);

          Inc (TotalNet);
        End;

        MsgBase^.CloseMsgBase;

        Dispose (MsgBase, Done);
      End Else
        Log (3, '!', '   No NETMAIL base for zone ' + strI2S(PKT.PKTHeader.DestZone));
    End Else
      Log (3, '!', '   ' + ArcFN + ' is not valid PKT');

    PKT.Free;

    FileErase (bbsConfig.InBoundPath + ArcFN);
  End;

  Procedure ImportEchoMailPacket (ArcFN: String);
  Var
    DirInfo  : SearchRec;
    FoundPKT : Boolean;
    CurTag   : String;
    MsgBase  : PMsgBaseABS;
    PKT      : TPKTReader;
    MBase    : RecMessageBase;
    Part     : LongInt;
    Whole    : LongInt;
    Count    : LongInt;
  Begin
    FoundPKT := False;
    PKT      := TPKTReader.Create;
    MsgBase  := NIL;
    Part     := 0;

    ProcessStatus (ArcFN + ' from ' + strAddr2Str(EchoNode.Address), False);

    ExecuteArchive (bbsConfig.InboundPath + ArcFN, EchoNode.ArcType, '*', 2);

    Whole := DirFiles(TempPath);

    BarOne.Reset;

    FindFirst (TempPath + '*', AnyFile, DirInfo);

    While DosError = 0 Do Begin
      If DirInfo.Attr And Directory = 0 Then Begin
        Inc (Part);

        BarOne.Update (Part, Whole);

        If strUpper(JustFileExt(DirInfo.Name)) = 'PKT' Then Begin
          FoundPKT := True;
          CurTag   := '';

          If Not PKT.Open(TempPath + DirInfo.Name) Then Begin
            Log (3, '!', '   ' + DirInfo.Name + ' is not valid PKT');

            FindNext(DirInfo);

            Continue;
          End;

          While PKT.GetMessage(False) Do Begin
            If Dupes.IsDuplicate(PKT.MsgCRC) Then Begin
              Log (3, '!', '      Duplicate message found in ' + PKT.MsgArea);

              If DupeIndex <> -1 Then Begin
                If (MsgBase <> NIL) and (CurTag <> '-DUPEMSG-') Then Begin
                  MsgBase^.CloseMsgBase;

                  Dispose (MsgBase, Done);

                  MsgBase := NIL;
                  CurTag  := '-DUPEMSG-';
                End;

                If MsgBase = NIL Then
                  MessageBaseOpen (MsgBase, DupeMBase);

                SavePKTMsgToBase (MsgBase, PKT, False);
              End;

              Inc (TotalDupes);
            End Else Begin
              If CurTag <> PKT.MsgArea Then Begin
                If Not GetMBaseByTag(PKT.MsgArea, MBase) Then Begin
                  Log (2, '!', '   Area ' + PKT.MsgArea + ' does not exist');

                  If Not CreateBases then Continue;

                  If FileExist(bbsConfig.MsgsPath + PKT.MsgArea + '.sqd') or
                     FileExist(bbsConfig.MsgsPath + PKT.MsgArea + '.jhr') Then Continue;

                   FillChar (MBase, SizeOf(MBase), #0);

                   MBase.Index     := GenerateMBaseIndex;
                   MBase.Name      := PKT.MsgArea;
                   MBase.QWKName   := PKT.MsgArea;
                   MBase.NewsName  := PKT.MsgArea;
                   MBase.FileName  := PKT.MsgArea;
                   MBase.EchoTag   := PKT.MsgArea;
                   MBase.Path      := bbsConfig.MsgsPath;
                   MBase.NetType   := 1;
                   MBase.ColQuote  := bbsConfig.ColorQuote;
                   MBase.ColText   := bbsConfig.ColorText;
                   MBase.ColTear   := bbsConfig.ColorTear;
                   MBase.ColOrigin := bbsConfig.ColorOrigin;
                   MBase.ColKludge := bbsConfig.ColorKludge;
                   MBase.Origin    := bbsConfig.Origin;
                   MBase.BaseType  := INI.ReadInteger(Header_ECHOIMPORT, 'base_type', 0);
                   MBase.ListACS   := INI.ReadString (Header_ECHOIMPORT, 'acs_list', '');
                   MBase.ReadACS   := INI.ReadString (Header_ECHOIMPORT, 'acs_read', '');
                   MBase.PostACS   := INI.ReadString (Header_ECHOIMPORT, 'acs_post', '');
                   MBase.NewsACS   := INI.ReadString (Header_ECHOIMPORT, 'acs_news', '');
                   MBase.SysopACS  := INI.ReadString (Header_ECHOIMPORT, 'acs_sysop', 's255');
                   MBase.Header    := INI.ReadString (Header_ECHOIMPORT, 'header', 'msghead');
                   MBase.RTemplate := INI.ReadString (Header_ECHOIMPORT, 'read_template', 'ansimrd');
                   MBase.ITemplate := INI.ReadString (Header_ECHOIMPORT, 'index_template', 'ansimlst');
                   MBase.MaxMsgs   := INI.ReadInteger(Header_ECHOIMPORT, 'max_msgs', 500);
                   MBase.MaxAge    := INI.ReadInteger(Header_ECHOIMPORT, 'max_msgs_age', 365);
                   MBase.DefNScan  := INI.ReadInteger(Header_ECHOIMPORT, 'new_scan', 1);
                   MBase.DefQScan  := INI.ReadInteger(Header_ECHOIMPORT, 'qwk_scan', 1);
                   MBase.NetAddr   := 1;

                   For Count := 1 to 30 Do
                     If bbsConfig.NetAddress[Count].Zone = PKT.PKTHeader.DestZone Then Begin
                       MBase.NetAddr := Count;
                       Break;
                     End;

                  If INI.ReadString(Header_ECHOIMPORT, 'use_autosig', '1') = '1' Then
                    MBase.Flags := MBase.Flags OR MBAutoSigs;

                  If INI.ReadString(Header_ECHOIMPORT, 'use_realname', '0') = '1' Then
                    MBase.Flags := MBase.Flags OR MBRealNames;

                  If INI.ReadString(Header_ECHOIMPORT, 'kill_kludge', '1') = '1' Then
                    MBase.Flags := MBase.Flags OR MBKillKludge;

                  // ADD DOWNLINK INFORMATION HERE INTO ECHONODES??

                  AddMessageBase(MBase);
                End;

                If MsgBase <> NIL Then Begin
                  MsgBase^.CloseMsgBase;

                  Dispose (MsgBase, Done);

                  MsgBase := NIL;
                End;

                MessageBaseOpen(MsgBase, MBase);

                CurTag := PKT.MsgArea;
              End;

              SavePKTMsgToBase (MsgBase, PKT, False);

              Dupes.AddDuplicate(PKT.MsgCRC);

              Inc (TotalEcho);

              Log (2, '+', '      Added Msg #' + strI2S(MsgBase^.GetHighMsgNum) + ' to ' + strStripPipe(MBase.Name));
            End;
          End;

          If MsgBase <> NIL Then Begin
            MsgBase^.CloseMsgBase;

            Dispose (MsgBase, Done);

            MsgBase := NIL;
          End;

          PKT.MsgFile.Close;
        End;

        FileErase (TempPath + DirInfo.Name);
      End;

      FindNext (DirInfo);
    End;

    FindClose (DirInfo);

    If MsgBase <> NIL Then Begin
      MsgBase^.CloseMsgBase;

      Dispose (MsgBase, Done);

      MsgBase := NIL;
    End;

    If Not FoundPKT Then
      Log (2, '!', '   Unable to find PKT in packet. Archive issue?');

    PKT.Free;

    FileErase (bbsConfig.InboundPath + ArcFN);
  End;

Var
  DirInfo     : SearchRec;
  NodeFile    : File of RecEchoMailNode;
  Count       : LongInt;
  FoundPacket : Byte;
Begin
  TotalEcho  := 0;
  TotalNet   := 0;
  TotalDupes := 0;

  ProcessName   ('Importing EchoMail', True);
  ProcessResult (rWORKING, False);

  DirClean (TempPath, '');

  If Not DirExists(bbsConfig.InboundPath) Then Begin
    ProcessStatus ('Inbound directory does not exist', True);
    ProcessResult (rFATAL, True);

    Exit;
  End;

  // read INI values

  CreateBases := INI.ReadBoolean(Header_ECHOIMPORT, 'auto_create', False);
  DupeIndex   := INI.ReadInteger(Header_ECHOIMPORT, 'dupe_msg_index', -1);
  Count       := INI.ReadInteger(Header_ECHOIMPORT, 'dupe_db_size', 32000);

  Dupes := TPKTDupe.Create(Count);

  If DupeIndex <> -1 Then
    If Not GetMBaseByIndex (DupeIndex, DupeMBase) Then
      DupeIndex := -1;

  FindFirst (bbsConfig.InboundPath + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory = 0 Then Begin
      FoundPacket := 0;

      If strUpper(JustFileExt(DirInfo.Name)) = 'PKT' Then Begin
        FoundPacket := 2;
        // NETMAIL
      End Else Begin
        // ECHOMAIL
        Assign (NodeFile, bbsConfig.DataPath + 'echonode.dat');

        If ioReset(NodeFile, Sizeof(RecEchoMailNode), fmRWDN) Then Begin
          While Not Eof(NodeFile) Do Begin
            Read (NodeFile, EchoNode);

            For Count := 1 to 30 Do Begin
              If strUpper(JustFileName(DirInfo.Name)) = strUpper(GetFTNArchiveName(EchoNode.Address, bbsConfig.NetAddress[Count])) Then Begin
                FoundPacket := 1;

                Break;
              End;
            End;
          End;

          Close (NodeFile);
        End;
      End;

      Case FoundPacket of
        0 : Log (2, '!', '   Unknown inbound file: ' + DirInfo.Name);
        1 : ImportEchoMailPacket (DirInfo.Name);
        2 : ImportNetMailPacket  (DirInfo.Name);
      End;
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);

  Dupes.Free;

  ProcessStatus ('Total |15' + strI2S(TotalEcho) + ' |07echo |15' + strI2S(TotalNet) + ' |07net |15' + strI2S(TotalDupes) + ' |07dupe', True);
  ProcessResult (rDONE, True);
 End;

End.

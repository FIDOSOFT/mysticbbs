Unit MUTIL_EchoImport;

{$I M_OPS.PAS}

Interface

Procedure uEchoImport;

Implementation

Uses
  DOS,
  Classes,
  m_FileIO,
  m_Strings,
  m_DateTime,
  AView,
  BBS_Records,
  BBS_DataBase,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish,
  mUtil_Common,
  mUtil_Status,
  mUtil_EchoCore,
  mUtil_EchoFix;

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
  MB^.SetOrig  (PKT.PKTOrig);
  MB^.SetDest  (PKT.PKTDest);

  MB^.SetPriv     ((PKT.MsgHDR.Attribute AND pktPrivate <> 0) OR NetMail);
  MB^.SetCrash    (PKT.MsgHDR.Attribute AND pktCrash    <> 0);
  MB^.SetRcvd     (PKT.MsgHDR.Attribute AND pktReceived <> 0);
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
  DupeIndex   : LongInt;
  DupeMBase   : RecMessageBase;
  CreateBases : Boolean;
  PKT         : TPKTReader;
  Dupes       : TPKTDupe;
  Status      : LongInt;
  ForwardList : Array[1..50] of String[35];
  ForwardSize : Byte = 0;
  //TwitList    : Array[1..50] of String[35];
  //TwitSize    : Byte = 0;

  Procedure ImportPacketFile (PktFN: String);
  Var
    MsgBase  : PMsgBaseABS;
    CurTag   : String;
    MBase    : RecMessageBase;
    Count    : LongInt;
    Route    : RecEchoMailNode;
  Begin
    If Not PKT.Open(PktFN) Then Begin
      Log (3, '!', '   ' + JustFile(PktFN) + ' is not valid PKT');

      Exit;
    End;

    If Not IsValidAKA(PKT.PKTDest.Zone, PKT.PKTDest.Net, PKT.PKTDest.Node, 0) Then Begin
      Log (3, '!', '   ' + JustFile(PktFN) + ' does not match an AKA');

      PKT.Close;

      Exit;
    End;

    ProcessStatus ('Importing ' + JustFile(PktFN), False);

    BarOne.Reset;

    CurTag  := '';
    MsgBase := NIL;
    Status  := 20;

    While PKT.GetMessage Do Begin
      If Status MOD 20 = 0 Then
        BarOne.Update (PKT.MsgFile.FilePosRaw, PKT.MsgFile.FileSizeRaw);

      Inc (Status);

      If PKT.MsgArea = 'NETMAIL' Then Begin

        If Not ProcessedByAreaFix(PKT) Then
          If IsValidAKA(PKT.MsgDest.Zone, PKT.MsgDest.Net, PKT.MsgDest.Node, PKT.MsgDest.Point) Then Begin

            If GetMBaseByNetZone(PKT.MsgDest.Zone, MBase) Then Begin
              For Count := 1 to ForwardSize Do
                If strUpper(strStripB(strWordGet(1, ForwardList[Count], ';'), ' ')) = strUpper(PKT.MsgTo) Then
                  PKT.MsgTo := strStripB(strWordGet(2, ForwardList[Count], ';'), ' ');

              CurTag := '';

              If MsgBase <> NIL Then Begin
                MsgBase^.CloseMsgBase;

                Dispose (MsgBase, Done);

                MsgBase := NIL;
              End;

              MessageBaseOpen  (MsgBase, MBase);
              SavePKTMsgToBase (MsgBase, PKT, True);

              Log (2, '+', '      Netmail from ' + PKT.MsgFrom + ' to ' + PKT.MsgTo);

              Inc (TotalNet);
            End;
          End Else
          If GetNodeByRoute(PKT.MsgDest, Route) Then Begin
            If Route.Active Then Begin
              // generate outbound packet name etc etc
              // add Via to the bottom
              // write OUT file
            End;
            Log (1, '!', '   DEBUG Pass-through netmail located to ' + Addr2Str(Route.Address));
          End Else
            Log (2, '!', '   No netmail destination: ' + PKT.MsgTo + ' ' + Addr2Str(PKT.MsgDest));
            // option to toss to badmsg?
      End Else Begin
        // Echomail msg

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

              If Not CreateBases Then Continue;

              If FileExist(bbsCfg.MsgsPath + PKT.MsgArea + '.sqd') or
                 FileExist(bbsCfg.MsgsPath + PKT.MsgArea + '.jhr') Then Continue;

              FillChar (MBase, SizeOf(MBase), #0);

              MBase.Index     := GenerateMBaseIndex;
              MBase.Name      := PKT.MsgArea;
              MBase.QWKName   := PKT.MsgArea;
              MBase.NewsName  := PKT.MsgArea;
              MBase.FileName  := PKT.MsgArea;
              MBase.EchoTag   := PKT.MsgArea;
              MBase.Path      := bbsCfg.MsgsPath;
              MBase.NetType   := 1;
              MBase.ColQuote  := bbsCfg.ColorQuote;
              MBase.ColText   := bbsCfg.ColorText;
              MBase.ColTear   := bbsCfg.ColorTear;
              MBase.ColOrigin := bbsCfg.ColorOrigin;
              MBase.ColKludge := bbsCfg.ColorKludge;
              MBase.Origin    := bbsCfg.Origin;
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

              MBase.FileName := strReplace(MBase.FileName, '/', '_');
              MBase.FileName := strReplace(MBase.FileName, '\', '_');

              For Count := 1 to 30 Do
                If bbsCfg.NetAddress[Count].Zone = PKT.PKTHeader.DestZone Then Begin
                  MBase.NetAddr := Count;
                  Break;
                End;

              If INI.ReadString(Header_ECHOIMPORT, 'lowercase_filename', '1') = '1' Then
                MBase.FileName := strLower(MBase.FileName);

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
    End;

    If MsgBase <> NIL Then Begin
      MsgBase^.CloseMsgBase;

      Dispose (MsgBase, Done);

      MsgBase := NIL;
    End;

    PKT.Close;

    FileErase (PktFN);

    BarOne.Update (1, 1);
  End;

  Procedure ImportPacketBundle (PktBundle: String);
  Var
    DirInfo    : SearchRec;
    NodeFile   : File of RecEchoMailNode;
    EchoNode   : RecEchoMailNode;
    ArcType    : String[4] = '';
    Count      : LongInt;
    BundleList : TStringList;
  Begin
    Assign (NodeFile, bbsCfg.DataPath + 'echonode.dat');

    If ioReset(NodeFile, Sizeof(RecEchoMailNode), fmRWDN) Then Begin
      While Not Eof(NodeFile) Do Begin
        Read (NodeFile, EchoNode);

        For Count := 1 to 30 Do Begin
          If strUpper(JustFileName(PktBundle)) = strUpper(GetFTNArchiveName(EchoNode.Address, bbsCfg.NetAddress[Count])) Then Begin
            ArcType := EchoNode.ArcType;

            Break;
          End;
        End;
      End;

      Close (NodeFile);
    End;

    If ArcType = '' Then Begin
      Case GetArchiveType(bbsCfg.InboundPath + PktBundle) of
        'A' : ArcType := 'ARJ';
        'R' : ArcType := 'RAR';
        'Z' : ArcType := 'ZIP';
        'L' : ArcType := 'LZH';
      Else
        Log (2, '!', '   Cannot find arctype for ' + PktBundle + '; skipping');

        Exit;
      End;
    End;

    ProcessStatus ('Extracting ' + PktBundle, False);

    ExecuteArchive (TempPath, bbsCfg.InboundPath + PktBundle, ArcType, '*', 2);

    BundleList := TStringList.Create;

    FindFirst (TempPath + '*', AnyFile, DirInfo);

    While DosError = 0 Do Begin
      If DirInfo.Attr And Directory = 0 Then Begin
        If strUpper(JustFileExt(DirInfo.Name)) = 'PKT' Then
          BundleList.Add(FormatDate(DateDos2DT(DirInfo.Time), 'YYYYMMDDHHIISS') + ' ' + DirInfo.Name);
      End;

      FindNext (DirInfo);
    End;

    FindClose (DirInfo);

    BundleList.Sort;

    If BundleList.Count = 0 Then
      Log (2, '!', '   Unable to extract bundle; skipping')
    Else Begin
      For Count := 1 to BundleList.Count Do
        ImportPacketFile (TempPath + strWordGet(2, BundleList.Strings[Count - 1], ' '));

      FileErase (bbsCfg.InboundPath + PktBundle);
    End;

    BundleList.Free;
  End;

Var
  DirInfo  : SearchRec;
  Count    : LongInt;
  FileExt  : String;
  PktList  : TStringList;
  FileName : String;
Begin
  TotalEcho  := 0;
  TotalNet   := 0;
  TotalDupes := 0;

  ProcessName   ('Importing EchoMail', True);
  ProcessResult (rWORKING, False);

  DirClean (TempPath, '');

  If Not DirExists(bbsCfg.InboundPath) Then Begin
    ProcessStatus ('Inbound directory does not exist', True);
    ProcessResult (rFATAL, True);

    Exit;
  End;

  // read INI values

  CreateBases := INI.ReadBoolean(Header_ECHOIMPORT, 'auto_create', False);
  DupeIndex   := INI.ReadInteger(Header_ECHOIMPORT, 'dupe_msg_index', -1);
  Count       := INI.ReadInteger(Header_ECHOIMPORT, 'dupe_db_size', 32000);

  // Read in forward list from INI

  FillChar (ForwardList, SizeOf(ForwardList), #0);

  Ini.SetSequential(True);

  Repeat
    FileExt := INI.ReadString(Header_ECHOIMPORT, 'forward', '');

    If FileExt = '' Then Break;

    Inc (ForwardSize);

    ForwardList[ForwardSize] := strStripB(FileExt, ' ');
  Until ForwardSize = 50;

(*  global blacklist.txt  and/or revamp of -mtrash and trashcan.txt
  FillChar (TwitList, SizeOf(TwitList), #0);

  Ini.SetSequential(True);

  Repeat
    FileExt := INI.ReadString(Header_ECHOIMPORT, 'twit', '');

    If FileExt = '' Then Break;

    Inc (TwitSize);

    TwitList[TwitSize] := strStripB(FileExt, ' ');
  Until TwitSize = 50;
*)

  INI.SetSequential(False);

  Dupes := TPKTDupe.Create(Count);
  PKT   := TPKTReader.Create;

  If DupeIndex <> -1 Then
    If Not GetMBaseByIndex (DupeIndex, DupeMBase) Then
      DupeIndex := -1;

  PktList := TStringList.Create;

  FindFirst (bbsCfg.InboundPath + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory = 0 Then
      PktList.Add(FormatDate(DateDos2DT(DirInfo.Time), 'YYYYMMDDHHIISS') + ' ' + DirInfo.Name);

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);

  PktList.Sort;

  For Count := 1 to PktList.Count Do Begin
    FileName := strWordGet(2, PktList.Strings[Count - 1], ' ');
    FileExt  := Copy(strUpper(JustFileExt(FileName)), 1, 2);

    If FileExt = 'PK' Then
      ImportPacketFile(bbsCfg.InboundPath + FileName)
    Else
    If (FileExt = 'SU') or
       (FileExt = 'MO') or
       (FileExt = 'TU') or
       (FileExt = 'WE') or
       (FileExt = 'TH') or
       (FileExt = 'FR') or
       (FileExt = 'SA') Then
         ImportPacketBundle(FileName)
    Else
      Log (2, '!', '   Unknown inbound file ' + FileName);
  End;

  PKT.Free;
  Dupes.Free;
  PktList.Free;

  ProcessStatus ('Total |15' + strI2S(TotalEcho) + ' |07echo |15' + strI2S(TotalNet) + ' |07net |15' + strI2S(TotalDupes) + ' |07dupe', True);
  ProcessResult (rDONE, True);

  FileErase (bbsCfg.SemaPath + fn_SemFileEchoIn);
End;

End.

Unit MUTIL_EchoExport;

{$I M_OPS.PAS}

Interface

Procedure uEchoExport;

Implementation

Uses
  DOS,
  m_Strings,
  m_FileIO,
  m_DateTime,
  mUtil_Common,
  mUtil_Status,
  mUtil_EchoCore,
  BBS_Records,
  BBS_DataBase,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

// Adds packet name into a FLO-type file if it does not exist already
Procedure AddToFLOQueue (FloName, PacketFN: String);
Var
  T   : Text;
  Str : String;
Begin
  FileMode := 66;

  Assign (T, FloName);
  {$I-} Reset (T); {$I+}

  If IoResult <> 0 Then Begin
    {$I-} ReWrite(T); {$I+}
    Reset(T);
  End;

  While Not Eof(T) Do Begin
    ReadLn (T, Str);

    If (strUpper(Str) = strUpper(PacketFN)) or (strUpper(Copy(Str, 2, 255)) = strUpper(PacketFN)) Then Begin
      Close (T);
      Exit;
    End;
  End;

  Append  (T);
  WriteLn (T, '^' + PacketFN);
  Close   (T);
End;

Procedure BundleMessages;
Var
  F          : File;
  PH         : RecPKTHeader;
  DirInfo    : SearchRec;
  NodeIndex  : LongInt;
  EchoNode   : RecEchoMailNode;
  PKTName    : String;
  BundleName : String;
  BundlePath : String;
  FLOName    : String;
  OrigAddr   : RecEchoMailAddr;
Begin
  FindFirst (TempPath + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr AND Directory = 0 Then Begin
      NodeIndex  := strS2I(JustFileExt(DirInfo.Name));
      PKTName    := JustFileName(DirInfo.Name) + '.pkt';

      GetNodeByIndex(NodeIndex, EchoNode);

      FileReName (TempPath + DirInfo.Name, TempPath + PKTName);

      Assign    (F, TempPath + PKTName);
      Reset     (F, 1);
      BlockRead (F, PH, SizeOf(PH));
      Close     (F);

      OrigAddr.Zone := PH.OrigZone;
      OrigAddr.Net  := PH.OrigNet;
      OrigAddr.Node := PH.OrigNode;

      BundlePath := GetFTNOutPath(EchoNode);

      DirCreate (BundlePath);

      FLOName    := BundlePath + GetFTNFlowName(EchoNode.Address);
      BundleName := BundlePath + GetFTNArchiveName(OrigAddr, EchoNode.Address) + '.' + strLower(DayString[DayOfWeek(CurDateDos)]);

      Case EchoNode.MailType of
        0 : FLOName := FLOName + '.flo';
        1 : FLOName := FLOName + '.clo';
        2 : FLOName := FLOName + '.dlo';
        3 : FLOName := FLOName + '.hlo';
      End;

      // TODO
      // check for existance, packet size limitations, etc and increment
      // from 0-9 A-Z

      BundleName[Length(BundleName)] := '0';

      ExecuteArchive (TempPath, BundleName, EchoNode.ArcType, TempPath + PKTName, 1);
      FileErase      (TempPath + PKTName);
      AddToFLOQueue  (FLOName, BundleName);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Procedure uEchoExport;
Var
  TotalEcho   : LongInt;
  TotalNet    : LongInt;
  MBaseFile   : File of RecMessageBase;
  MBase       : RecMessageBase;
  ExportFile  : File of RecEchoMailExport;
  ExportIndex : RecEchoMailExport;
  EchoNode    : RecEchoMailNode;
  PKTBase     : String;
  MsgBase     : PMsgBaseABS;

  Procedure ExportMessage;
  Var
    PH   : RecPKTHeader;
    MH   : RecPKTMessageHdr;
    DT   : DateTime;
    Temp : Word;
    F    : File;

    Procedure WriteStr (Str: String; EndChar: Char);
    Var
      L : Byte;
    Begin
      L := Length(Str);

      Move (Str[1], Str[0], L);

      Str[L] := EndChar;

      BlockWrite (F, Str[0], L + 1);
    End;

  Var
    TempStr1 : String;
    TempStr2 : String;
    TempStr3 : String;
  Begin
    // if msg originated from this echomail address then do not export

    If (EchoNode.Address.Zone  = MsgBase^.GetOrigAddr.Zone) and
       (EchoNode.Address.Net   = MsgBase^.GetOrigAddr.Net)  and
       (EchoNode.Address.Node  = MsgBase^.GetOrigAddr.Node) and
       (EchoNode.Address.Point = MsgBase^.GetOrigAddr.Point) Then Exit;

    Log (2, '+', '      Export #' + strI2S(MsgBase^.GetMsgNum) + ' to ' + strAddr2Str(EchoNode.Address));

    GetDate (DT.Year, DT.Month, DT.Day, Temp);
    GetTime (DT.Hour, DT.Min,   DT.Sec, Temp);

    If MBase.NetType = 3 Then Begin
      TempStr3 := GetFTNOutPath(EchoNode);

      DirCreate (TempStr3);

      TempStr1 := TempStr3 + GetFTNFlowName(EchoNode.Address);
      TempStr2 := TempStr3 + GetFTNFlowName(EchoNode.Address);

      Case EchoNode.MailType of
        1 : Begin
              TempStr1 := TempStr1 + '.cut';
              TempStr2 := TempStr2 + '.clo';
            End;
        2 : Begin
              TempStr1 := TempStr1 + '.dut';
              TempStr2 := TempStr2 + '.dlo';
            End;
        3 : Begin
              TempStr1 := TempStr1 + '.hut';
              TempStr2 := TempStr2 + '.hlo';
            End;
      Else
        TempStr1 := TempStr1 + '.out';
        TempStr2 := TempStr2 + '.flo';
      End;

      Assign (F, TempStr1);

//      AddToFloQueue (TempStr2, TempStr1);

      Inc (TotalNet);
    End Else Begin
      Assign (F, TempPath + PKTBase + '.' + strI2S(EchoNode.Index));

      Inc (TotalEcho);
    End;

    If ioReset(F, 1, fmRWDN) Then Begin
      ioSeek (F, FileSize(F) - 2);  // we want to overwrite packet term chars
    End Else Begin
      ioReWrite (F, 1, fmRWDN);

      FillChar (PH, SizeOf(PH), 0);

      PH.OrigNode := MsgBase^.GetOrigAddr.Node;
      PH.DestNode := EchoNode.Address.Node;
      PH.Year     := DT.Year;
      PH.Month    := DT.Month;
      PH.Day      := DT.Day;
      PH.Hour     := DT.Hour;
      PH.Minute   := DT.Min;
      PH.Second   := DT.Sec;
      PH.PKTType  := 2;
      PH.OrigNet  := MsgBase^.GetOrigAddr.Net;
      PH.DestNet  := EchoNode.Address.Net;
      PH.ProdCode := 254; // RESEARCH THIS
      PH.OrigZone := MsgBase^.GetOrigAddr.Zone;
      PH.DestZone := EchoNode.Address.Zone;
      //Password : Array[1..8] of Char;  // RESEARCH THIS

      BlockWrite (F, PH, SizeOf(PH));
    End;

    FillChar (MH, SizeOf(MH), 0);

    MH.MsgType  := 2;
    MH.OrigNode := MsgBase^.GetOrigAddr.Node;
    MH.DestNode := EchoNode.Address.Node;
    MH.OrigNet  := MsgBase^.GetOrigAddr.Net;
    MH.DestNet  := EchoNode.Address.Net;

    TempStr1 := FormatDate(DT, 'DD NNN YY  HH:II:SS') + #0;
    Move (TempStr1[1], MH.DateTime[0], 20);

    If MsgBase^.IsLocal    Then MH.Attribute := MH.Attribute OR pktLocal;
    If MsgBase^.IsCrash    Then MH.Attribute := MH.Attribute OR pktCrash;
    If MsgBase^.IsKillSent Then MH.Attribute := MH.Attribute OR pktKillSent;
    If MsgBase^.IsRcvd     Then MH.Attribute := MH.Attribute OR pktReceived;
    If MsgBase^.IsPriv     Then MH.Attribute := MH.Attribute OR pktPrivate;

    BlockWrite (F, MH, SizeOf(MH));

    WriteStr (MsgBase^.GetTo,   #0);
    WriteStr (MsgBase^.GetFrom, #0);
    WriteStr (MsgBase^.GetSubj, #0);

    If MBase.NetType <> 3 Then
      WriteStr ('AREA:' + MBase.EchoTag, #13);

    If MBase.NetType = 3 Then
      WriteStr (#1 + 'INTL ' + strAddr2Str(EchoNode.Address) + ' ' + strAddr2Str(MsgBase^.GetOrigAddr), #13);

    WriteStr (#1 + 'TID: ' + mysSoftwareID + ' ' + mysVersion, #13);

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM Do
      WriteStr (MsgBase^.GetString(79), #13);

    // SEEN-BY needs to include yourself and ANYTHING it is sent to (downlinks)
    // so we need to cycle through nodes for this mbase and add ALL of them

    TempStr1 := 'SEEN-BY: ' + strI2S(MsgBase^.GetOrigAddr.Net) + '/' + strI2S(MsgBase^.GetOrigAddr.Node) + ' ';

    If MsgBase^.GetOrigAddr.Net <> EchoNode.Address.Net Then
      TempStr1 := TempStr1 + strI2S(EchoNode.Address.Net) + '/';

    TempStr1 := TempStr1 + strI2S(EchoNode.Address.Node);

    WriteStr (TempStr1, #13);
    WriteStr (#1 + 'PATH: ' + strI2S(MsgBase^.GetOrigAddr.Net) + '/' + strI2S(MsgBase^.GetOrigAddr.Node), #13);
    WriteStr (#0#0, #0);

    Close (F);
  End;

Begin
  TotalEcho := 0;
  TotalNet  := 0;
  PKTBase   := GetFTNPKTName;

  ProcessName   ('Exporting EchoMail', True);
  ProcessResult (rWORKING, False);

  DirClean (TempPath, '');

  If Not DirExists(bbsCfg.OutboundPath) Then Begin
    ProcessStatus ('Outbound directory does not exist', True);
    ProcessResult (rFATAL, True);

    Exit;
  End;

  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');

  If ioReset(MBaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin
    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      BarOne.Update (FilePos(MBaseFile), FileSize(MBaseFile));

      If MBase.NetType = 0 Then Continue;

      If MBase.EchoTag = '' Then Begin
        Log (1, '!', '   WARNING: No TAG for ' + strStripPipe(MBase.Name));

        Continue;
      End;

      ProcessStatus (strStripPipe(MBase.Name), False);

      If Not MessageBaseOpen(MsgBase, MBase) Then Continue;

      MsgBase^.SeekFirst(1);

      While MsgBase^.SeekFound Do Begin
        MsgBase^.MsgStartUp;

        // uncomment islocal if/when we build downlinks on import instead
        // of export

        If {MsgBase^.IsLocal And } Not MsgBase^.IsSent Then Begin
          Log (3, '!', '   Found msg for export');

          Assign (ExportFile, MBase.Path + MBase.FileName + '.lnk');

          If ioReset(ExportFile, SizeOf(RecEchoMailExport), fmRWDN) Then Begin
            While Not Eof(ExportFile) Do Begin
              Read (ExportFile, ExportIndex);

              If MBase.NetType = 3 Then Begin
                If GetNodeByRoute(MsgBase^.GetDestAddr, EchoNode) Then
                  If EchoNode.Active Then Begin
                    ExportMessage;

                    Break;
                  End;
              End Else
              If GetNodeByIndex(ExportIndex, EchoNode) Then
                If EchoNode.Active Then
                  ExportMessage;
            End;

            Close (ExportFile);
          End;

          MsgBase^.SetSent(True);
          MsgBase^.ReWriteHdr;
        End;

        MsgBase^.SeekNext;
      End;

      MsgBase^.CloseMsgBase;

      Dispose (MsgBase, Done);
    End;

    Close (MBaseFile);
  End;

  BundleMessages;

  ProcessStatus ('Total |15' + strI2S(TotalEcho) + ' |07echo |15' + strI2S(TotalNet) + ' |07net', True);
  ProcessResult (rDONE, True);
End;

End.

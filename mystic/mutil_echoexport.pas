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

(*
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
  BundleSize : Cardinal;
  Temp       : String;
  FLOName    : String;
  OrigAddr   : RecEchoMailAddr;
  CheckInc   : Boolean;
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
      CheckInc   := False;

      DirCreate (BundlePath);

      If Not (EchoNode.LPKTPtr in [48..57, 97..122]) Then
        EchoNode.LPKTPtr := 48;

      If EchoNode.LPKTDay <> DayOfWeek(CurDateDos) Then Begin
        EchoNode.LPKTDay := DayOfWeek(CurDateDos);
        EchoNode.LPKTPtr := 48;
      End Else
        CheckInc := True;

      FLOName    := BundlePath + GetFTNFlowName(EchoNode.Address);
      BundleName := BundlePath + GetFTNArchiveName(OrigAddr, EchoNode.Address) + '.' + Copy(strLower(DayString[DayOfWeek(CurDateDos)]), 1, 2) + Char(EchoNode.LPKTPtr);

      If CheckInc And Not FileExist(BundleName) Then Begin
        BundleName := GetFTNBundleExt(True, BundleName);

        EchoNode.LPKTPtr := Byte(BundleName[Length(BundleName)]);
      End;

      SaveEchoMailNode(EchoNode);

      Case EchoNode.MailType of
        0 : FLOName := FLOName + '.flo';
        1 : FLOName := FLOName + '.clo';
        2 : FLOName := FLOName + '.dlo';
        3 : FLOName := FLOName + '.hlo';
      End;

      ExecuteArchive (TempPath, BundleName, EchoNode.ArcType, TempPath + PKTName, 1);
      FileErase      (TempPath + PKTName);
      AddToFLOQueue  (FLOName, BundleName);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;
*)

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
  BundleSize : Cardinal;
  Temp       : String;
  FLOName    : String;
  OrigAddr   : RecEchoMailAddr;
  CheckInc   : Boolean;
Begin
  FindFirst (TempPath + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr AND Directory = 0 Then Begin
      NodeIndex := strS2I(JustFileExt(DirInfo.Name));
      PKTName   := JustFileName(DirInfo.Name) + '.pkt';

      GetNodeByIndex (NodeIndex, EchoNode);
      FileReName     (TempPath + DirInfo.Name, TempPath + PKTName);

      Assign    (F, TempPath + PKTName);
      Reset     (F, 1);
      BlockRead (F, PH, SizeOf(PH));
      Close     (F);

      OrigAddr.Zone := PH.OrigZone;
      OrigAddr.Net  := PH.OrigNet;
      OrigAddr.Node := PH.OrigNode;

      BundlePath := GetFTNOutPath(EchoNode);
      FLOName    := BundlePath + GetFTNFlowName(EchoNode.Address);
      CheckInc   := False;

      DirCreate (BundlePath);

      Case EchoNode.MailType of
        0 : FLOName := FLOName + '.flo';
        1 : FLOName := FLOName + '.clo';
        2 : FLOName := FLOName + '.dlo';
        3 : FLOName := FLOName + '.hlo';
      End;

      If EchoNode.ArcType = '' Then Begin
        FileReName    (TempPath + PKTName, BundlePath + PKTName);
        AddToFLOQueue (FLOName, BundlePath + PKTName);
      End Else Begin
        If Not (EchoNode.LPKTPtr in [48..57, 97..122]) Then
          EchoNode.LPKTPtr := 48;

        If EchoNode.LPKTDay <> DayOfWeek(CurDateDos) Then Begin
          EchoNode.LPKTDay := DayOfWeek(CurDateDos);
          EchoNode.LPKTPtr := 48;
        End Else
          CheckInc := True;

        BundleName := BundlePath + GetFTNArchiveName(OrigAddr, EchoNode.Address) + '.' + Copy(strLower(DayString[DayOfWeek(CurDateDos)]), 1, 2) + Char(EchoNode.LPKTPtr);

        If CheckInc And Not FileExist(BundleName) Then Begin
          BundleName := GetFTNBundleExt(True, BundleName);

          EchoNode.LPKTPtr := Byte(BundleName[Length(BundleName)]);
        End;

        SaveEchoMailNode(EchoNode);

        ExecuteArchive (TempPath, BundleName, EchoNode.ArcType, TempPath + PKTName, 1);
        FileErase      (TempPath + PKTName);
        AddToFLOQueue  (FLOName, BundleName);
      End;
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

    // if netmail is TO someone on this system do not export

    If MBase.NetType = 3 Then
      If IsValidAKA(MsgBase^.GetDestAddr.Zone, MsgBase^.GetDestAddr.Net, MsgBase^.GetDestAddr.Node, MsgBase^.GetDestAddr.Point) Then
        Exit;

    Log (2, '+', '      Export #' + strI2S(MsgBase^.GetMsgNum) + ' to ' + Addr2Str(EchoNode.Address));

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

      PH.OrigZone  := MsgBase^.GetOrigAddr.Zone;
      PH.OrigNet   := MsgBase^.GetOrigAddr.Net;
      PH.OrigNode  := MsgBase^.GetOrigAddr.Node;
      PH.OrigPoint := MsgBase^.GetOrigAddr.Point;
      PH.DestZone  := EchoNode.Address.Zone;
      PH.DestNet   := EchoNode.Address.Net;
      PH.DestNode  := EchoNode.Address.Node;
      PH.DestPoint := EchoNode.Address.Point;
      PH.Year      := DT.Year;
      PH.Month     := DT.Month;
      PH.Day       := DT.Day;
      PH.Hour      := DT.Hour;
      PH.Minute    := DT.Min;
      PH.Second    := DT.Sec;
      PH.PKTType   := 2;
      PH.ProdCode  := 254;

      // Map current V2 values to V2+ values

      PH.ProdCode2 := PH.ProdCode;
      PH.OrigZone2 := PH.OrigZone;
      PH.DestZone2 := PH.DestZone;
      PH.Compat    := $0000000000000001;

      BlockWrite (F, PH, SizeOf(PH));
    End;

    FillChar (MH, SizeOf(MH), 0);

    MH.MsgType := 2;

    If MBase.NetType = 3 Then Begin
      MH.DestNode := MsgBase^.GetDestAddr.Node;
      MH.DestNet  := MsgBase^.GetDestAddr.Net;
    End Else Begin
      MH.DestNode := EchoNode.Address.Node;
      MH.DestNet  := EchoNode.Address.Net;
    End;

    MH.OrigNode := MsgBase^.GetOrigAddr.Node;
    MH.OrigNet  := MsgBase^.GetOrigAddr.Net;

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

    If MBase.NetType = 3 Then Begin
      WriteStr (#1 + 'INTL ' + Addr2Str(MsgBase^.GetDestAddr) + ' ' + Addr2Str(MsgBase^.GetOrigAddr), #13);
    End;

    WriteStr (#1 + 'TID: ' + mysSoftwareID + ' ' + mysVersion, #13);

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM Do
      WriteStr (MsgBase^.GetString(79), #13);

    If MBase.NetType <> 3 Then Begin
      // SEEN-BY needs to include yourself and ANYTHING it is sent to (downlinks)
      // so we need to cycle through nodes for this mbase and add ALL of them

      TempStr1 := 'SEEN-BY: ' + strI2S(MsgBase^.GetOrigAddr.Net) + '/' + strI2S(MsgBase^.GetOrigAddr.Node) + ' ';

      If MsgBase^.GetOrigAddr.Net <> EchoNode.Address.Net Then
        TempStr1 := TempStr1 + strI2S(EchoNode.Address.Net) + '/';

      TempStr1 := TempStr1 + strI2S(EchoNode.Address.Node);

      WriteStr (TempStr1, #13);
      WriteStr (#1 + 'PATH: ' + strI2S(MsgBase^.GetOrigAddr.Net) + '/' + strI2S(MsgBase^.GetOrigAddr.Node), #13);
    End;// Else
//      WriteStr (#1 + 'Via ' + Addr2Str(MsgBase^.GetOrigAddr) + ' @' + FormatDate(CurDateDT, 'YYYYMMDD.HHIISS') + '.UTC ' + mysSoftwareID + ' ' + mysVersion, #13);

    WriteStr (#0#0, #0);
    Close    (F);
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

  FileErase (bbsCfg.SemaPath + fn_SemFileEchoOut);
End;

End.

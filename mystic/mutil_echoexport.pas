Unit MUTIL_EchoExport;

{$I M_OPS.PAS}

Interface

Procedure uEchoExport;

Implementation

Uses
  DOS,
  MKCRAP,
  m_Strings,
  m_FileIO,
  m_DateTime,
  mUtil_Common,
  mUtil_Status,
  bbs_Common,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

Procedure BundleMessages;
Var
  F          : File;
  T          : Text;
  PH         : RecPKTHeader;
  DirInfo    : SearchRec;
  NodeIndex  : LongInt;
  EchoNode   : RecEchoMailNode;
  PKTName    : String;
  BundleName : String;
  FLOName    : String;
  OrigAddr   : RecEchoMailAddr;
Begin
  //update/create .FLO or whatever... need to research

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

      // TODO: if crash etc change char F in FLO extension

      FLOName    := bbsConfig.OutboundPath + GetFTNFlowName(EchoNode.Address) + '.flo';
      BundleName := bbsConfig.OutboundPath + GetFTNArchiveName(OrigAddr, EchoNode.Address) + '.' + DayString[DayOfWeek(CurDateDos)];

      BundleName[Length(BundleName)] := '0';

      ExecuteArchive (BundleName, EchoNode.ArcType, TempPath + PKTName, 1);

      FileErase (TempPath + PKTName);

      {$I-}

      Assign (T, FLOName);
      Append (T);

      If IoResult <> 0 Then ReWrite(T);

      WriteLn (T, '^' + BundleName);
      Close   (T);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Procedure uEchoExport;
Var
  TotalMessages : LongInt;
  MBaseFile     : File of RecMessageBase;
  MBase         : RecMessageBase;
  ExportFile    : File of RecEchoMailExport;
  ExportIndex   : RecEchoMailExport;
  EchoNode      : RecEchoMailNode;
  PKTBase       : String;
  MsgBase       : PMsgBaseABS;

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
    TempStr : String;
  Begin
    Inc (TotalMessages);

    Log (2, '+', '      Export Msg #' + strI2S(MsgBase^.GetMsgNum) + ' to ' + strAddr2Str(EchoNode.Address));

    GetDate  (DT.Year, DT.Month, DT.Day, Temp);
    GetTime  (DT.Hour, DT.Min, DT.Sec, Temp);

    Assign (F, TempPath + PKTBase + '.' + strI2S(EchoNode.Index));

    If ioReset(F, 1, fmRWDN) Then Begin
      ioSeek (F, FileSize(F));
    End Else Begin
      ioReWrite (F, 1, fmRWDN);

      FillChar (PH, SizeOf(PH), 0);

      PH.OrigNode := bbsConfig.NetAddress[MBase.NetAddr].Node;
      PH.DestNode := EchoNode.Address.Node;
      PH.Year     := DT.Year;
      PH.Month    := DT.Month;
      PH.Day      := DT.Day;
      PH.Hour     := DT.Hour;
      PH.Minute   := DT.Min;
      PH.Second   := DT.Sec;
      PH.PKTType  := 2;
      PH.OrigNet  := bbsConfig.NetAddress[MBase.NetAddr].Net;
      PH.DestNet  := EchoNode.Address.Net;
      PH.ProdCode := 254; // RESEARCH THIS
      PH.OrigZone := bbsConfig.NetAddress[MBase.NetAddr].Zone;
      PH.DestZone := EchoNode.Address.Zone;
      //Password : Array[1..8] of Char;  // RESEARCH THIS

      BlockWrite (F, PH, SizeOf(PH));
    End;

    FillChar (MH, SizeOf(MH), 0);

    MH.MsgType  := $0200;
    MH.OrigNode := bbsConfig.NetAddress[MBase.NetAddr].Node;
    MH.DestNode := EchoNode.Address.Node;
    MH.OrigNet  := bbsConfig.NetAddress[MBase.NetAddr].Net;
    MH.DestNet  := EchoNode.Address.Net;

    TempStr := FormattedDate(DT, 'DD NNN YY  HH:MM:SS');
    Move (TempStr[1], MH.DateTime[0], 19);

    If MsgBase^.IsLocal    Then MH.Attribute := MH.Attribute OR pktLocal;
    If MsgBase^.IsCrash    Then MH.Attribute := MH.Attribute OR pktCrash;
    If MsgBase^.IsKillSent Then MH.Attribute := MH.Attribute OR pktKillSent;
    If MsgBase^.IsRcvd     Then MH.Attribute := MH.Attribute OR pktReceived;
    If MsgBase^.IsPriv     Then MH.Attribute := MH.Attribute OR pktPrivate;

    BlockWrite (F, MH, SizeOf(MH));

    WriteStr (MsgBase^.GetTo,   #0);
    WriteStr (MsgBase^.GetFrom, #0);
    WriteStr (MsgBase^.GetSubj, #0);
    WriteStr ('AREA:' + MBase.EchoTag, #13);

    WriteStr (#1 + 'INTL ' + strAddr2Str(EchoNode.Address) + ' ' + strAddr2Str(bbsConfig.NetAddress[MBase.NetAddr]), #13);
    WriteStr (#1 + 'TID: Mystic BBS ' + mysVersion, #13);

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM Do
      WriteStr (MsgBase^.GetString(79), #13);

    WriteStr('', #0);

    Close (F);
  End;

Begin
  TotalMessages := 0;
  PKTBase       := GetFTNPKTName;

  ProcessName   ('Exporting Echomail', True);
  ProcessResult (rWORKING, False);

  DirClean (TempPath, '');

  If Not DirExists(bbsConfig.OutboundPath) Then Begin
    ProcessStatus ('Outbound directory does not exist', True);
    ProcessResult (rFATAL, True);

    Exit;
  End;

  Assign  (MBaseFile, bbsConfig.DataPath + 'mbases.dat');

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

        If MsgBase^.IsLocal And Not MsgBase^.IsSent Then Begin
          Assign (ExportFile, MBase.Path + MBase.FileName + '.lnk');

          If ioReset(ExportFile, SizeOf(RecEchoMailExport), fmRWDN) Then Begin
            While Not Eof(ExportFile) Do Begin
              Read (ExportFile, ExportIndex);

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

  ProcessStatus ('Exported |15' + strI2S(TotalMessages) + ' |07msgs', True);
  ProcessResult (rDONE, True);
End;

End.

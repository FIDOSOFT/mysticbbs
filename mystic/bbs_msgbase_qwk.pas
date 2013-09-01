Unit bbs_MsgBase_QWK;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  BBS_Records,
  BBS_DataBase,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Const
  QWK_EOL     = #13#10;
  QWK_CONTROL = 'MYSTICQWK';

Type
  BSingle = Array [0..3] of Byte;

  QwkNdxHdr = Record
    MsgPos : BSingle;
    Junk   : Byte;
  End;

  QwkDATHdr = Record {128 bytes}
    Status   : Char;
    MSGNum   : Array [1..7] of Char;
    Date     : Array [1..8] of Char;
    Time     : Array [1..5] of Char;
    UpTO     : Array [1..25] of Char;
    UpFROM   : Array [1..25] of Char;
    Subject  : Array [1..25] of Char;
    PassWord : Array [1..12] of Char;
    ReferNum : Array [1..8] of Char;
    NumChunk : Array [1..6] of Char;
    Active   : Char; {225 active, 226 killed}
    ConfNum  : Word;
    Junk     : Word;
    NetTag   : Char;
  End;

  QwkLRRec = Record
    Base : Word;
    Pos  : LongInt;
  End;

  TQWKEngine_HasAccess = Function  (Sender: Pointer; AcsStr: String) : Boolean;
  TQWKEngine_Status    = Procedure (Sender: Pointer; State: Byte);

  TQWKEngine = Class
    StatusUpdate  : TQWKEngine_Status;
    HasAccess     : TQWKEngine_HasAccess;
    IsExtended    : Boolean;
    IsNetworked   : Boolean;
    WorkPath      : String;
    PacketID      : String;
    UserRecord    : RecUser;
    UserNumber    : Cardinal;
    TotalMessages : LongInt;
    TotalBases    : LongInt;
    RepOK         : LongInt;
    RepFailed     : LongInt;
    RepBaseAdd    : LongInt;
    RepBaseDel    : LongInt;
    DataFile      : TFileBuffer;
    MBaseFile     : File;
    MBase         : RecMessageBase;
    QwkLR         : QwkLRRec;
    QwkLRFile     : File of QwkLRRec;
    MsgBase       : PMsgBaseABS;

    Constructor Create            (QwkPath, QwkID: String; UN: Cardinal; UR: RecUser);
    Procedure   LONG2MSB          (Index: LongInt; Var MS: BSingle);
    Procedure   WriteDOORID;
    Procedure   WriteTOREADEREXT;
    Procedure   WriteCONTROLDAT;
    Function    WriteMSGDAT : LongInt;
    Procedure   UpdateLastReadPointers;
    Procedure   CreatePacket;
    Function    ProcessReply : Boolean;
  End;

Implementation

Uses
  m_Strings,
  m_DateTime;

Constructor TQWKEngine.Create (QwkPath, QwkID: String; UN: Cardinal; UR: RecUser);
Begin
  Inherited Create;

  WorkPath      := QwkPath;
  PacketID      := QwkID;
  UserNumber    := UN;
  UserRecord    := UR;
  IsExtended    := False;
  IsNetworked   := False;
  TotalMessages := 0;
  TotalBases    := 0;
  RepOK         := 0;
  RepFailed     := 0;
  RepBaseAdd    := 0;
  RepBaseDel    := 0;

  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');
End;

Procedure TQWKEngine.LONG2MSB (Index : LongInt; Var MS : BSingle);
Var
  Exp : Byte;
Begin
  If Index <> 0 Then Begin
    Exp := 0;

    While Index And $800000 = 0 Do Begin
      Inc (Exp);
      Index := Index SHL 1
    End;

    Index := Index And $7FFFFF;
  End Else
    Exp := 152;

  MS[0] := Index AND $FF;
  MS[1] := (Index SHR 8) AND $FF;
  MS[2] := (Index SHR 16) AND $FF;
  MS[3] := 152 - Exp;
End;

Procedure TQWKEngine.WriteDOORID;
Var
  TempFile : Text;
Begin
  If IsNetworked Then Exit;

  Assign  (TempFile, WorkPath + 'door.id');
  ReWrite (TempFile);
  Write   (TempFile, 'DOOR = ' + mysSoftwareID + QWK_EOL);
  Write   (TempFile, 'VERSION = ' + mysVersion + QWK_EOL);
  Write   (TempFile, 'SYSTEM = ' + mysSoftwareID + ' ' + mysVersion + QWK_EOL);
  Write   (TempFile, 'CONTROLNAME = ' + QWK_CONTROL + QWK_EOL);
  Write   (TempFile, 'CONTROLTYPE = ADD' + QWK_EOL);
  Write   (TempFile, 'CONTROLTYPE = DROP' + QWK_EOL);
  Close   (TempFile);
End;

Procedure TQWKEngine.WriteTOREADEREXT;
Var
  TempFile : Text;
  Flags    : String;
  Base     : RecMessageBase;
Begin
  If IsNetworked Or (Not IsExtended) Then Exit;

  Assign  (TempFile, WorkPath + 'toreader.ext');
  ReWrite (TempFile);
  Write   (TempFile, 'ALIAS ' + UserRecord.Handle + QWK_EOL);

  If ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    While Not Eof(MBaseFile) Do Begin
      ioRead (MBaseFile, Base);

      If HasAccess(Self, Base.ReadACS) Then Begin
        Flags := ' ';

        If Base.Flags AND MBPrivate = 0 Then
          Flags := Flags + 'aO'
        Else
          Flags := Flags + 'pP';

        If Base.Flags AND MBRealNames = 0 Then
          Flags := Flags + 'H';

        If Not HasAccess(Self, Base.PostACS) Then
          Flags := Flags + 'BRZ';

        Case Base.NetType of
          0 : Flags := Flags + 'L';
          1 : Flags := Flags + 'E';
          2 : Flags := Flags + 'U';
          3 : Flags := Flags + 'N';
        End;

        If Base.DefQScan = 2 Then
          Flags := Flags + 'F';

        Write (TempFile, 'AREA ' + strI2S(Base.Index) + Flags, QWK_EOL);
      End;
    End;

    Close (MBaseFile);
  End;

  Close (TempFile);
End;

Procedure TQWKEngine.WriteCONTROLDAT;
Var
  TempFile : Text;
  BaseFile : File;
  Base     : RecMessageBase;
Begin
  If IsNetworked Then Exit;

  Assign  (TempFile, WorkPath + 'control.dat');
  ReWrite (TempFile);

  Write (TempFile, bbsCfg.BBSName + QWK_EOL);
  Write (TempFile, QWK_EOL);
  Write (TempFile, QWK_EOL);
  Write (TempFile, bbsCfg.SysopName + QWK_EOL);
  Write (TempFile, '0,' + PacketID + QWK_EOL);
  Write (TempFile, DateDos2Str(CurDateDos, 1), ',', TimeDos2Str(CurDateDos, 0) + QWK_EOL);
  Write (TempFile, strUpper(UserRecord.Handle) + QWK_EOL);
  Write (TempFile, QWK_EOL);
  Write (TempFile, '0' + QWK_EOL);
  Write (TempFile, TotalMessages, QWK_EOL);
  Write (TempFile, TotalBases - 1, QWK_EOL);

  If ioReset (BaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    While Not Eof(BaseFile) Do Begin
      ioRead (BaseFile, Base);

      If HasAccess(Self, Base.ReadACS) Then Begin
        Write (TempFile, Base.Index, QWK_EOL);

        If IsExtended Then
          Write (TempFile, strStripMCI(Base.Name) + QWK_EOL)
        Else
          Write (TempFile, Base.QwkName + QWK_EOL);
      End;
    End;

    Close (BaseFile);
  End;

  Write (TempFile, JustFile(bbsCfg.qwkWelcome) + QWK_EOL);
  Write (TempFile, JustFile(bbsCfg.qwkNews) + QWK_EOL);
  Write (TempFile, JustFile(bbsCfg.qwkGoodbye) + QWK_EOL);

  Close (TempFile);
End;

Function TQWKEngine.WriteMSGDAT : LongInt;
Var
  NdxFile  : File of QwkNdxHdr;
  NdxHdr   : QwkNdxHdr;
  Header   : String[128];
  BufStr   : String[128];
  Chunks   : Word;
  MsgAdded : LongInt;
  LastRead : LongInt;
  QwkIndex : LongInt;
  TooBig   : Boolean;

  Procedure DoString (Str: String);
  Var
    Count : SmallInt;
  Begin
    For Count := 1 to Length(Str) Do Begin
      BufStr := BufStr + Str[Count];

      If BufStr[0] = #128 Then Begin
        DataFile.WriteBlock (BufStr[1], 128);

        BufStr := '';
      End;
    End;
  End;

Var
  TempStr : String;
Begin
  MsgAdded := 0;

  If Not MBaseOpenCreate(MsgBase, MBase, WorkPath) Then Exit;

  LastRead := MsgBase^.GetLastRead(UserNumber) + 1;

  MsgBase^.SeekFirst (LastRead);

  While MsgBase^.SeekFound Do Begin

    If Not IsNetworked Then
      If ((bbsCfg.QwkMaxBase > 0)   and (MsgAdded = bbsCfg.QwkMaxBase)) or
         ((bbsCfg.QwkMaxPacket > 0) and (TotalMessages = bbsCfg.QwkMaxPacket)) Then Break;

    MsgBase^.MsgStartUp;

    If MsgBase^.IsPriv And Not IsThisUser(UserRecord, MsgBase^.GetTo) Then Begin
      MsgBase^.SeekNext;

      Continue;
    End;

    Inc (MsgAdded);
    Inc (TotalMessages);

    LastRead := MsgBase^.GetMsgNum;
    Chunks   := 0;
    BufStr   := '';
    TooBig   := False;
    QwkIndex := DataFile.FileSizeRaw DIV 128 + 1;

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM Do Begin
      TempStr := MsgBase^.GetString(79);

      If TempStr[1] = #1 Then Continue;

      Inc (Chunks, Length(TempStr));
    End;

    If Chunks MOD 128 = 0 Then
      Chunks := Chunks DIV 128 + 1
    Else
      Chunks := Chunks DIV 128 + 2;

    Header :=
      ' ' +
      strPadR(strI2S(MsgBase^.GetMsgNum), 7, ' ') +
      MsgBase^.GetDate +
      MsgBase^.GetTime +
      strPadR(strUpper(MsgBase^.GetTo), 25, ' ') +
      strPadR(strUpper(MsgBase^.GetFrom), 25, ' ') +
      strPadR(strUpper(MsgBase^.GetSubj), 25, ' ') +
      strPadR('', 12, ' ') +
      strPadR(strI2S(MsgBase^.GetRefer), 8, ' ') +
      strPadR(strI2S(Chunks), 6, ' ') +
      #255 +
      '  ' +
      '  ' +
      ' ';

    If Not IsNetworked Then Begin
      If MsgAdded = 1 Then Begin
        Assign  (NdxFile, WorkPath + strPadL(strI2S(MBase.Index), 3, '0') + '.ndx');
        ReWrite (NdxFile);
      End;

      LONG2MSB   (QwkIndex, NdxHdr.MsgPos);
      Write      (NdxFile, NdxHdr);
    End;

    DataFile.WriteBlock (Header[1], 128);

    If IsExtended Then Begin
      If Length(MsgBase^.GetFrom) > 25 Then Begin
        DoString('From: ' + MsgBase^.GetFrom + #227);

        TooBig := True;
      End;

      If Length(MsgBase^.GetTo) > 25 Then Begin
        DoString('To: ' + MsgBase^.GetTo + #227);

        TooBig := True;
      End;

      If Length(MsgBase^.GetSubj) > 25 Then Begin
        DoString('Subject: ' + MsgBase^.GetSubj + #227);

        TooBig := True;
      End;

      If TooBig Then DoString(#227);
    End;

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM Do Begin
      TempStr := MsgBase^.GetString(79) + #227;

      If TempStr[1] = #1 Then Continue;

      DoString (TempStr);
    End;

    If BufStr <> '' Then Begin
      BufStr := strPadR (BufStr, 128, ' ');

      DataFile.WriteBlock (BufStr[1], 128);
    End;

    MsgBase^.SeekNext;
  End;

  If Not IsNetworked And (MsgAdded > 0) Then
    Close (NdxFile);

  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);

  Result := LastRead;
End;

Procedure TQWKEngine.UpdateLastReadPointers;
Begin
  Reset   (QwkLRFile);
  ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN);

  While Not Eof(QwkLRFile) Do Begin
    Read (QwkLRFile, QwkLR);

    If ioSeek (MBaseFile, QwkLR.Base - 1) Then Begin
      ioRead (MBaseFile, MBase);

      If MBaseOpenCreate (MsgBase, MBase, WorkPath) Then Begin
        MsgBase^.SetLastRead (UserNumber, QwkLR.Pos);
        MsgBase^.CloseMsgBase;
      End;

      Dispose(MsgBase, Done);
    End;
  End;

  Close (QwkLRFile);
  Close (MBaseFile);
End;

Procedure TQWKEngine.CreatePacket;
Var
  Temp  : String;
  MScan : MScanRec;
Begin
  DataFile := TFileBuffer.Create(4 * 1024);

  DataFile.OpenStream (WorkPath + 'messages.dat', 1, fmCreate, fmRWDN);

  Temp := strPadR('Produced By ' + mysSoftwareID + ' v' + mysVersion + '. ' + mysCopyNotice, 128, ' ');

  DataFile.WriteBlock (Temp[1], 128);

  Assign  (QwkLRFile, WorkPath + 'qlr.dat');
  ReWrite (QwkLRFile);

  If ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    If IsNetworked Then
      ioRead (MBaseFile, MBase);

    While Not Eof(MBaseFile) Do Begin
      ioRead (MBaseFile, MBase);

      If IsNetworked And (MBase.Flags AND MBAllowQWKNet = 0) Then
        Continue;

      If HasAccess(Self, MBase.ReadACS) Then Begin

        GetMessageScan (UserNumber, MBase, MScan);

        If MScan.QwkScan > 0 Then Begin
          Inc (TotalBases);

          QwkLR.Base := FilePos(MBaseFile);
          QwkLR.Pos  := WriteMSGDAT;

          Write (QwkLRFile, QwkLR);
        End;
      End;
    End;

    Close (MBaseFile);
  End;

  Close (QwkLRFile);

  DataFile.Free;

  If Not IsNetworked Then Begin
    WriteControlDAT;
    WriteDOORID;
    WriteTOREADEREXT;
  End;
End;

Function TQWKEngine.ProcessReply : Boolean;

  Procedure QwkControl (Idx: LongInt; Mode: Byte);
  Var
    TempBase : RecMessageBase;
    TempScan : MScanRec;
  Begin
    If GetMBaseByIndex(Idx, TempBase) Then Begin
      GetMessageScan (UserNumber, TempBase, TempScan);

      TempScan.QwkScan := Mode;

      If Mode = 0 Then Inc (RepBaseDel);
      If Mode = 1 Then Inc (RepBaseAdd);

      PutMessageScan (UserNumber, TempBase, TempScan);
    End;
  End;

Var
  QwkBlock   : String[128];
  QwkHeader  : QwkDATHdr;
  Chunks     : SmallInt;
  Line       : String;
  LineCount  : SmallInt;
  IsControl  : Boolean;
  GotControl : Boolean;
  ExtFile    : Text;
  Count1     : SmallInt;
  Count2     : SmallInt;
Begin
  Result := False;

  DataFile := TFileBuffer.Create(4 * 1024);

  If Not DataFile.OpenStream (FileFind(WorkPath + PacketID + '.msg'), 1, fmOpen, fmRWDN) Then Begin
    DataFile.Free;

    DirClean (WorkPath, '');

    Exit;
  End;

  DataFile.ReadBlock(QwkBlock[1], 128);
  QwkBlock[0] := #128;

  If Pos(strUpper(PacketID), strUpper(QwkBlock)) = 0 Then Begin
    DataFile.Free;

    DirClean(WorkPath, '');

    Exit;
  End;

  While Not DataFile.EOF Do Begin
    DataFile.ReadBlock(QwkHeader, SizeOf(QwkHeader));

    Move (QwkHeader.MsgNum, QwkBlock[1], 7);

    QwkBlock[0] := #7;

    If GetMBaseByIndex(strS2I(QwkBlock), MBase) Then Begin

      If MBaseOpenCreate(MsgBase, MBase, WorkPath) Then Begin

        MBaseAssignData(UserRecord, MsgBase, MBase);

        QwkBlock[0] := #25;
        Move (QwkHeader.UpTo, QwkBlock[1], 25);
        MsgBase^.SetTo(strStripR(QwkBlock, ' '));

        Move (QwkHeader.Subject, QwkBlock[1], 25);
        MsgBase^.SetSubj(strStripR(QwkBlock, ' '));

        Move (QwkHeader.ReferNum, QwkBlock[1], 6);
        QwkBlock[0] := #6;

        MsgBase^.SetRefer(strS2I(strStripR(QwkBlock, ' ')));

        Move (QwkHeader.NumChunk, QwkBlock[1], 6);

        Chunks     := strS2I(QwkBlock) - 1;
        Line       := '';
        LineCount  := 0;
        IsControl  := MsgBase^.GetTo = QWK_CONTROL;
        GotControl := False;

        // disable control in network packets (for now?)

        If IsNetworked Then
          IsControl := False;

        If IsControl And ((MsgBase^.GetSubj = 'ADD') or (MsgBase^.GetSubj = 'DROP')) Then
          QwkControl (MBase.Index, Ord(MsgBase^.GetSubj = 'ADD'));

        For Count1 := 1 to Chunks Do Begin
          DataFile.ReadBlock (QwkBlock[1], 128);

          QwkBlock[0] := #128;
          QwkBlock    := strStripR(QwkBlock, ' ');

          For Count2 := 1 to Length(QwkBlock) Do Begin
            If QwkBlock[Count2] = #227 Then Begin
              Inc (LineCount);

              If (LineCount < 4) and (Copy(Line, 1, 5) = 'From:') Then Begin
                GotControl := True;

                // ignore from name unless its networked

                If IsNetworked Then
                  MsgBase^.SetTo(strStripB(Copy(Line, 6, Length(Line)), ' '));
              End Else
              If (LineCount < 4) and (Copy(Line, 1, 3) = 'To:') Then Begin
                MsgBase^.SetTo(strStripB(Copy(Line, 4, Length(Line)), ' '));
                GotControl := True;
              End Else
              If (LineCount < 4) and (Copy(Line, 1, 8) = 'Subject:') Then Begin
                MsgBase^.SetSubj(strStripB(Copy(Line, 9, Length(Line)), ' '));
                GotControl := True;
              End Else
                If GotControl And (Line = '') Then
                  GotControl := False
                Else
                  MsgBase^.DoStringLn(Line);

              Line := '';
            End Else
              Line := Line + QwkBlock[Count2];
          End;
        End;

        If Line <> '' Then
          MsgBase^.DoStringLn(Line);

        If MBase.NetType > 0 Then Begin
          If IsNetworked Then Begin
            MsgBase^.DoStringLn (#13 + '--- ' + mysSoftwareID + '/QWK v' + mysVersion + ' (' + OSID + ')');
            MsgBase^.DoStringLn (' * Origin: ' + GetOriginLine(MBase));
          End Else Begin
            MsgBase^.DoStringLn (#13 + '--- ' + mysSoftwareID + '/QWK v' + mysVersion + ' (' + OSID + ')');
            MsgBase^.DoStringLn (' * Origin: ' + GetOriginLine(MBase) + ' (' + Addr2Str(MsgBase^.GetOrigAddr) + ')');
          End;
        End;

        If Not IsControl Then Begin
          If HasAccess(Self, MBase.PostACS) Then Begin
            MsgBase^.WriteMsg;
            Inc (RepOK);   // must increase user and history posts by repOK
          End Else
            Inc (RepFailed);
        End;

        MsgBase^.CloseMsgBase;

        Dispose (MsgBase, Done);
      End Else
        Inc (RepFailed);
    End Else
      Inc (RepFailed);
  End;

  DataFile.Free;

  Assign (ExtFile, FileFind(WorkPath + 'todoor.ext'));
  {$I-} Reset (ExtFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(ExtFile) Do Begin
      ReadLn (ExtFile, Line);

      If strWordGet(1, Line, ' ') = 'AREA' Then Begin
        QwkBlock := strWordGet(3, Line, ' ');

        If Pos('a', QwkBlock) > 0 Then QwkControl(strS2I(strWordGet(2, Line, ' ')), 1);
        If Pos('D', QwkBlock) > 0 Then QwkControl(strS2I(strWordGet(2, Line, ' ')), 0);
      End;
    End;

    Close (ExtFile);
  End;

  DirClean (WorkPath, '');

  Result := True;
End;

End.

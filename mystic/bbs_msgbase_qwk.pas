Unit bbs_MsgBase_QWK;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  BBS_Records,
  BBS_DataBase;

Const
  QWK_EOL = #13#10;

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

  TQWKEngine_HasAccess = Function  (AcsStr: String) : Boolean;
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
    MBase         : RecMessageBase;

    Constructor Create            (QwkPath, QwkID: String; UN: Cardinal; UR: RecUser);
    Procedure   LONG2MSB          (Index: LongInt; Var MS: BSingle);
    Procedure   WriteDOORID;
    Procedure   WriteTOREADEREXT;
    Procedure   WriteCONTROLDAT;
    Function    WriteMSGDAT : LongInt;
    Procedure   CreatePacket;
    Function    ProcessReply : Boolean;
  End;

Implementation

Uses
  m_Strings,
  m_DateTime,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

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
  Write   (TempFile, 'CONTROLNAME = MYSTICQWK' + QWK_EOL);
  Write   (TempFile, 'CONTROLTYPE = ADD' + QWK_EOL);
  Write   (TempFile, 'CONTROLTYPE = DROP' + QWK_EOL);
  Close   (TempFile);
End;

Procedure TQWKEngine.WriteTOREADEREXT;
Var
  TempFile : Text;
  BaseFile : File;
  Flags    : String;
  Base     : RecMessageBase;
Begin
  If IsNetworked Or (Not IsExtended) Then Exit;

  Assign  (TempFile, WorkPath + 'toreader.ext');
  ReWrite (TempFile);
  Write   (TempFile, 'ALIAS ' + UserRecord.Handle + QWK_EOL);

  Assign (BaseFile, bbsCfg.DataPath + 'mbases.dat');

  If ioReset (BaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    While Not Eof(BaseFile) Do Begin
      ioRead (BaseFile, Base);

      If HasAccess(Base.ReadACS) Then Begin
        Flags := ' ';

        If Base.Flags AND MBPrivate = 0 Then
          Flags := Flags + 'aO'
        Else
          Flags := Flags + 'pP';

        If Base.Flags AND MBRealNames = 0 Then
          Flags := Flags + 'H';

        If Not HasAccess(Base.PostACS) Then
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

    Close (BaseFile);
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

  Assign (BaseFile, bbsCfg.DataPath + 'mbases.dat');

  If ioReset (BaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    While Not Eof(BaseFile) Do Begin
      ioRead (BaseFile, Base);

      If HasAccess(Base.ReadACS) Then Begin
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
  MsgBase  : PMsgBaseABS;

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
      If ((bbsCfg.QwkMaxBase > 0) and (MsgAdded = bbsCfg.QwkMaxBase)) or
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

Procedure TQWKEngine.CreatePacket;
Var
  Temp      : String;
  QwkLR     : QwkLRRec;
  QwkLRFile : File of QwkLRRec;
  MBaseFile : File;
  MScan     : MScanRec;
Begin
  DataFile := TFileBuffer.Create(4 * 1024);

  DataFile.OpenStream (WorkPath + 'messages.dat', 1, fmCreate, fmRWDN);

  Temp := strPadR('Produced By ' + mysSoftwareID + ' v' + mysVersion + '. ' + mysCopyNotice, 128, ' ');

  DataFile.WriteBlock (Temp[1], 128);

  Assign  (QwkLRFile, WorkPath + 'qlr.dat');
  ReWrite (QwkLRFile);

  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');

  If ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN) Then Begin

    If IsNetworked Then
      ioRead (MBaseFile, MBase);

    While Not Eof(MBaseFile) Do Begin
      ioRead (MBaseFile, MBase);

      If IsNetworked And (MBase.Flags AND MBAllowQWKNet = 0) Then
        Continue;

      If HasAccess(MBase.ReadACS) Then Begin

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
Begin
  Result := False;
End;

End.

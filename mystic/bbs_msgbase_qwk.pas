Unit bbs_MsgBase_QWK;

// networking notes:
// no control files
// no file list
// no index files
// extended = selectable by user's setting
// archive = selectable by user's setting

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  bbs_DataBase;

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

  TQWKEngine_HasAccess = Function (AcsStr: String) : Boolean;

  TQWKEngine = Class
    IsExtended    : Boolean;
    IsNetworked   : Boolean;
    WorkPath      : String;
    PacketID      : String;
    UserRecord    : RecUser;
    UserNumber    : Cardinal;
    HasAccess     : TQWKEngine_HasAccess;
    TotalMessages : Cardinal;
    TotalBases    : Cardinal;
    RepOK         : LongInt;
    RepFailed     : LongInt;
    RepBaseAdd    : LongInt;
    RepBaseDel    : LongInt;
    DataFile      : TFileBuffer;

    Constructor Create            (QwkPath, QwkID: String; UN: Cardinal; UR: RecUser);
    Procedure   LONG2MSB          (Index : LongInt; Var MS : BSingle);
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
  Write (TempFile, '0,' + bbsCfg.qwkBBSID + QWK_EOL);
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

  If Not OpenCreateBase(MsgBase, MBase) Then Exit;

  LastRead := MsgBase^.GetLastRead(UserNumber) + 1;

  MsgBase^.SeekFirst (LastRead);

  While MsgBase^.SeekFound Do Begin

    If Not IsNetworked Then
      If ((bbsCfg.QwkMaxBase > 0) and (MsgAdded = bbsCfg.QwkMaxBase)) or
         ((bbsCfg.QwkMaxPacket > 0) and (TotalMsgs = bbsCfg.QwkMaxPacket)) Then Break;

    MsgBase^.MsgStartUp;

    If MsgBase^.IsPriv And Not Session.User.IsThisUser(MsgBase^.GetTo) Then Begin
      MsgBase^.SeekNext;

      Continue;
    End;

    Inc (MsgAdded);
    Inc (TotalMsgs);

    LastRead := MsgBase^.GetMsgNum;
    Chunks   := 0;
    BufStr   := '';
    TooBig   := False;
    QwkIndex := FileSize(DataFile) DIV 128 + 1;

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

    If MsgAdded = 1 Then Begin
      Assign  (NdxFile, WorkPath + strPadL(strI2S(MBase.Index), 3, '0') + '.ndx');
      ReWrite (NdxFile);
    End;

    LONG2MSB   (QwkIndex, NdxHdr.MsgPos);
    Write      (NdxFile, NdxHdr);

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

  If MsgAdded > 0 Then Close (NdxFile);

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
  MBase     : RecMessageBase;
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







Function TMsgBase.WriteMSGDAT (Extended: Boolean) : LongInt;
Var
  DataFile : File;
  NdxFile  : File of QwkNdxHdr;
  NdxHdr   : QwkNdxHdr;
  Header   : String[128];
  Chunks   : Word;
  BufStr   : String[128];
  MsgAdded : Integer;
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
        BlockWrite (DataFile, BufStr[1], 128);

        BufStr := '';
      End;
    End;
  End;

Var
  TempStr : String;
Begin
  MsgAdded := 0;

  If Not OpenCreateBase(MsgBase, MBase) Then Exit;

  Session.io.OutFull (Session.GetPrompt(231));

  Assign (DataFile, Session.TempPath + 'messages.dat');
  Reset  (DataFile, 1);
  Seek   (DataFile, FileSize(DataFile));

  LastRead := MsgBase^.GetLastRead(Session.User.UserNum) + 1;

  MsgBase^.SeekFirst (LastRead);

  While MsgBase^.SeekFound Do Begin
    If ((bbsCfg.QwkMaxBase > 0) and (MsgAdded = bbsCfg.QwkMaxBase)) or
    ((bbsCfg.QwkMaxPacket > 0) and (TotalMsgs = bbsCfg.QwkMaxPacket)) Then Break;

    MsgBase^.MsgStartUp;

    If MsgBase^.IsPriv And Not Session.User.IsThisUser(MsgBase^.GetTo) Then Begin
      MsgBase^.SeekNext;

      Continue;
    End;

    Inc (MsgAdded);
    Inc (TotalMsgs);

    LastRead := MsgBase^.GetMsgNum;
    Chunks   := 0;
    BufStr   := '';
    TooBig   := False;
    QwkIndex := FileSize(DataFile) DIV 128 + 1;

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

    If MsgAdded = 1 Then Begin
      Assign  (NdxFile, Session.TempPath + strPadL(strI2S(MBase.Index), 3, '0') + '.ndx');
      ReWrite (NdxFile);
    End;

    LONG2MSB   (QwkIndex, NdxHdr.MsgPos);
    Write      (NdxFile, NdxHdr);
    BlockWrite (DataFile, Header[1], 128);

    If Extended Then Begin
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

      BlockWrite (DataFile, BufStr[1], 128);
    End;

    MsgBase^.SeekNext;
  End;

  Close (DataFile);

  If MsgAdded > 0 Then Close (NdxFile);

  Session.io.PromptInfo[1] := strI2S(MBase.Index);
  Session.io.PromptInfo[2] := MBase.Name;
  Session.io.PromptInfo[3] := MBase.QwkName;
  Session.io.PromptInfo[4] := strI2S(MsgBase^.NumberOfMsgs);
  Session.io.PromptInfo[5] := strI2S(MsgAdded);

  MsgBase^.CloseMsgBase;
  Dispose (MsgBase, Done);

  Session.io.OutBS     (Screen.CursorX, True);
  Session.io.OutFullLn (Session.GetPrompt(232));

  Result := LastRead;
End;

Procedure TMsgBase.DownloadQWK (Extended: Boolean; Data: String);
Type
  QwkLRRec = Record
    Base : Word;
    Pos  : LongInt;
  End;
Var
  Old       : RecMessageBase;
  DataFile  : File;
  Temp      : String;
  QwkLR     : QwkLRRec;
  QwkLRFile : File of QwkLRRec;
Begin
  If Session.User.ThisUser.QwkFiles Then
    Session.FileBase.ExportFileList(True, True);

  FileMode := 66;
  Old      := MBase;
  Temp     := strPadR('Produced By ' + mysSoftwareID + ' v' + mysVersion + '. ' + CopyID, 128, ' ');

  Assign     (DataFile, Session.TempPath + 'messages.dat');
  ReWrite    (DataFile, 1);
  BlockWrite (DataFile, Temp[1], 128);
  Close      (DataFile);

  Assign  (QwkLRFile, Session.TempPath + 'qlr.dat');
  ReWrite (QwkLRFile);
  Reset   (MBaseFile);

  Session.io.OutFullLn (Session.GetPrompt(230));

  TotalMsgs := 0;
  TotalConf := 0;

  Session.User.IgnoreGroup := Pos('/ALLGROUP', strUpper(Data)) > 0;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      Inc (TotalConf);

      GetMessageScan;

      If MScan.QwkScan > 0 Then Begin
        QwkLR.Base := FilePos(MBaseFile);
        QwkLR.Pos  := WriteMsgDAT(Extended);

        Write (QwkLRFile, QwkLR);
      End;
    End;
  End;

  Close (QwkLRFile);

  WriteControlDAT (Extended);
  WriteDOORID     (Extended);

  If Extended Then WriteTOREADEREXT;

  If TotalMsgs > 0 Then Begin
    Session.io.PromptInfo[1] := strI2S(TotalMsgs);
    Session.io.PromptInfo[2] := strI2S(TotalConf);

    Session.io.OutFullLn (Session.GetPrompt(233));

    Temp := bbsCfg.qwkBBSID + '.qwk';

    Session.io.OutFullLn (Session.GetPrompt(234));

    Session.io.PromptInfo[1] := Temp;

    If FileExist(bbsCfg.QwkWelcome) Then FileCopy(bbsCfg.qwkWelcome, Session.TempPath + JustFile(bbsCfg.qwkWelcome));
    If FileExist(bbsCfg.QwkNews)    Then FileCopy(bbsCfg.qwkNews,    Session.TempPath + JustFile(bbsCfg.qwkNews));
    If FileExist(bbsCfg.QwkGoodbye) Then FileCopy(bbsCfg.qwkGoodbye, Session.TempPath + JustFile(bbsCfg.qwkGoodbye));

//    Session.SystemLog('DEBUG: Archiving QWK packet');

    If Session.LocalMode Then Begin
      FileErase (bbsCfg.QWKPath + Temp);

      Session.FileBase.ExecuteArchive (bbsCfg.QWKPath + Temp, Session.User.ThisUser.Archive, Session.TempPath + '*', 1);

      Session.io.OutFullLn (Session.GetPrompt(235));
    End Else Begin
      Session.FileBase.ExecuteArchive (Session.TempPath + Temp, Session.User.ThisUser.Archive, Session.TempPath + '*', 1);
      Session.FileBase.SendFile (Session.TempPath + Temp);
    End;

    If Session.io.GetYN (Session.GetPrompt(236), True) Then Begin
      Reset (MBaseFile);
      Reset (QwkLRFile);

      While Not Eof(QwkLRFile) Do Begin
        Read (QwkLRFile, QwkLR);
        Seek (MBaseFile, QwkLR.Base - 1);
        Read (MBaseFile, MBase);

        Case MBase.BaseType of
          0 : MsgBase := New(PMsgBaseJAM, Init);
          1 : MsgBase := New(PMsgBaseSquish, Init);
        End;

        MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

        If MsgBase^.OpenMsgBase Then Begin
          MsgBase^.SetLastRead (Session.User.UserNum, QwkLR.Pos);
          MsgBase^.CloseMsgBase;
        End;

        Dispose(MsgBase, Done);
      End;
      Close (QwkLRFile);
    End;
  End Else
    Session.io.OutFullLn (Session.GetPrompt(228));

  Session.User.IgnoreGroup := False;

  Close (MBaseFile);

  MBase := Old;

  DirClean (Session.TempPath, '');
End;

Procedure TMsgBase.UploadREP;
Var
  DataFile    : File;
  TempBase    : RecMessageBase;
  OldBase     : RecMessageBase;
  QwkHeader   : QwkDATHdr;
  QwkBlock    : String[128];
  Line        : String;
  A           : SmallInt;
  B           : SmallInt;
  Chunks      : SmallInt;
  LineCount   : SmallInt;
  IsControl   : Boolean;
  GotControl  : Boolean;
  ExtFile     : Text;
  StatOK      : LongInt = 0;
  StatFailed  : LongInt = 0;
  StatBaseAdd : LongInt = 0;
  StatBaseDel : LongInt = 0;

  Procedure QwkControl (Idx: LongInt; Mode: Byte);
  Begin
    OldBase := MBase;

    If GetBaseByIndex(Idx, MBase) Then Begin
      GetMessageScan;

      MScan.QwkScan := Mode;

      If Mode = 0 Then Inc (StatBaseDel);
      If Mode = 1 Then Inc (StatBaseAdd);

      SetMessageScan;
    End;

    MBase := OldBase;
  End;

Begin
  If Session.LocalMode Then
    Session.FileBase.ExecuteArchive (bbsCfg.QWKPath + bbsCfg.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  Else Begin
    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, Session.TempPath + bbsCfg.qwkBBSID + '.rep');

    If Not Session.FileBase.DszSearch(bbsCfg.qwkBBSID + '.rep') Then Begin
      Session.io.PromptInfo[1] := bbsCfg.qwkBBSID + '.rep';

      Session.io.OutFullLn (Session.GetPrompt(84));

      Exit;
    End;

    Session.FileBase.ExecuteArchive (Session.TempPath + bbsCfg.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  End;

  Assign (DataFile, FileFind(Session.TempPath + bbsCfg.qwkBBSID + '.msg'));

  If Not ioReset(DataFile, 1, fmRWDN) Then Begin
    Session.io.OutFull (Session.GetPrompt(238));
    DirClean (Session.TempPath, '');
    Exit;
  End;

  BlockRead (DataFile, QwkBlock[1], 128);
  QwkBlock[0] := #128;

  If Pos(strUpper(bbsCfg.qwkBBSID), strUpper(QwkBlock)) = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(239));
    Close (DataFile);
    DirClean(Session.TempPath, '');
    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(240));

  While Not Eof(DataFile) Do Begin
    BlockRead (DataFile, QwkHeader, SizeOf(QwkHeader));
    Move      (QwkHeader.MsgNum, QwkBlock[1], 7);

    QwkBlock[0] := #7;

    If GetBaseByIndex(strS2I(QwkBlock), TempBase) Then Begin

      If OpenCreateBase(MsgBase, TempBase) Then Begin

        AssignMessageData(MsgBase, TempBase);

        QwkBlock[0] := #25;
        Move (QwkHeader.UpTo, QwkBlock[1], 25);
        MsgBase^.SetTo(strStripR(QwkBlock, ' '));

        Move (QwkHeader.Subject, QwkBlock[1], 25);
        MsgBase^.SetSubj(strStripR(QwkBlock, ' '));

        Move (QwkHeader.ReferNum, QwkBlock[1], 6);
        QwkBlock[0] := #6;
        MsgBase^.SetRefer(strS2I(strStripR(QwkBlock, ' ')));

        Move(QwkHeader.NumChunk, QwkBlock[1], 6);

        Chunks     := strS2I(QwkBlock) - 1;
        Line       := '';
        LineCount  := 0;
        IsControl  := MsgBase^.GetTo = qwkControlName;
        GotControl := False;

        If IsControl And ((MsgBase^.GetSubj = 'ADD') or (MsgBase^.GetSubj = 'DROP')) Then
          QwkControl (TempBase.Index, Ord(MsgBase^.GetSubj = 'ADD'));

        For A := 1 to Chunks Do Begin
          BlockRead (DataFile, QwkBlock[1], 128);

          QwkBlock[0] := #128;
          QwkBlock    := strStripR(QwkBlock, ' ');

          For B := 1 to Length(QwkBlock) Do Begin
            If QwkBlock[B] = #227 Then Begin
              Inc (LineCount);

              If (LineCount < 4) and (Copy(Line, 1, 5) = 'From:') Then
                GotControl := True
                // Mystic uses the username of the person who uploaded the
                // reply package, based on the alias/realname setting of the
                // base itself.  This prevents people from spoofing "From"
                // fields.
                // If QWK networking will need to allow this of course
              Else
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
              Line := Line + QwkBlock[B];
          End;
        End;

        If Line <> '' Then MsgBase^.DoStringLn(Line);

        If TempBase.NetType > 0 Then Begin
          MsgBase^.DoStringLn (#13 + '--- ' + mysSoftwareID + '/QWK v' + mysVersion + ' (' + OSID + ')');
          MsgBase^.DoStringLn (' * Origin: ' + ResolveOrigin(TempBase) + ' (' + strAddr2Str(MsgBase^.GetOrigAddr) + ')');
        End;

        If Not IsControl Then Begin
          MsgBase^.WriteMsg;

          Inc (StatOK);
          Inc (Session.User.ThisUser.Posts);
          Inc (Session.HistoryPosts);
        End;

        MsgBase^.CloseMsgBase;

        Dispose (MsgBase, Done);
      End Else
        Inc (StatFailed);
    End Else
      Inc (StatFailed);
  End;

  Close (DataFile);

  Assign (ExtFile, FileFind(Session.TempPath + 'todoor.ext'));
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

  DirClean (Session.TempPath, '');

  Session.io.PromptInfo[1] := strI2S(StatOK);
  Session.io.PromptInfo[2] := strI2S(StatFailed);
  Session.io.PromptInfo[3] := strI2S(StatBaseAdd);
  Session.io.PromptInfo[4] := strI2S(StatBaseDel);

  Session.io.OutFullLn(Session.GetPrompt(503));
End;

End.

// need one of these for the file list compiler now too which MAYBE can be
// used in MUTIL also.  lets template and build that out first.. then...
// create and upload QWK/REP packets without relying on BBS specific stuff

Type
  TMsgBaseQWK = Class
    User     : RecUser;
    Extended : Boolean;

    Constructor Create (UD: RecUser; Ext: Boolean);
    Function    CreatePacket : Boolean;
    Function    ProcessReply (bbsid, temppath, usernum, var user, forcefrom ): Boolean;
    Destructor  Destroy; Override;
  End;

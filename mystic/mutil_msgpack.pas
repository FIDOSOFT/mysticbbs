Unit MUTIL_MsgPack;

{$I M_OPS.PAS}

Interface

Procedure uPackMessageBases;

Implementation

Uses
  m_Strings,
  m_FileIO,
  mUtil_Common,
  mUtil_Status,
  BBS_DataBase,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

{$I RECORDS.PAS}

Procedure uPackMessageBases;
Type
  RecMsgLink = Record
    OldNum : Cardinal;
    NewNum : Cardinal;
  End;

Var
  LinkFile   : TFileBuffer;
  BaseKills  : Cardinal = 0;
  BaseTotal  : Cardinal = 0;
  TotalKills : Cardinal = 0;

  Function GetMessageLink (OldNum: Cardinal; Zero: Boolean) : Cardinal;
  Var
    L   : RecMsgLink;
    Res : LongInt;
  Begin
    LinkFile.SeekRaw(0);

    While Not LinkFile.EOF Do Begin
      LinkFile.ReadBlock (L, SizeOf(L), Res);

      If L.OldNum = OldNum Then Begin
        Result := L.NewNum;
        Exit;
      End;
    End;

    If Zero Then
      Result := 0
    Else
      Result := OldNum;
  End;

  Procedure PackOneBase (Var MsgBase: RecMessageBase);
  Const
    TempName = 'msgpacktemp';
  Var
    MsgData   : PMsgBaseABS;
    NewData   : PMsgBaseABS;
    SaveMsg   : Boolean = False;
    UserTotal : Cardinal;
    Link      : RecMsgLink;
    Count     : Cardinal;
  Begin
    FileMode  := 66;
    BaseKills := 0;

    Inc (BaseTotal);

    Case MsgBase.BaseType of
      0 : Begin
            MsgData := New(PMsgBaseJAM, Init);
            NewData := New(PMsgBaseJAM, Init);
          End;
      1 : Begin
            MsgData := New(PMsgBaseSquish, Init);
            NewData := New(PMsgBaseSquish, Init);
          End;
    End;

    MsgData^.SetMsgPath  (MsgBase.Path + MsgBase.FileName);
    MsgData^.SetTempFile (TempPath + 'msgbuf.old');

    NewData^.SetMsgPath  (TempPath + TempName);
    NewData^.SetTempFile (TempPath + 'msgbuf.new');

    If Not MsgData^.OpenMsgBase Then Begin
      Dispose (MsgData, Done);
      Dispose (NewData, Done);

      Exit;
    End;

    If Not NewData^.CreateMsgBase (MsgBase.MaxMsgs, MsgBase.MaxAge) Then Begin
      Dispose (MsgData, Done);
      Dispose (NewData, Done);

      Exit;
    End;

    If Not NewData^.OpenMsgBase Then Begin
      Dispose (MsgData, Done);
      Dispose (NewData, Done);

      Exit;
    End;

    LinkFile := TFileBuffer.Create (8 * 1024);

    LinkFile.OpenStream (TempPath + TempName + '.tmp', 1, fmCreate, fmRWDN);

    MsgData^.SeekFirst(1);

    While MsgData^.SeekFound Do Begin
      MsgData^.MsgStartUp;

      SaveMsg := True;

      // option:
      // if private/netmail message area check to make sure users are valid
      // and delete if they are not.

      // also do kludges make it successfully?  replyID etc?

      If SaveMsg Then Begin
        NewData^.StartNewMsg;

        NewData^.SetFrom     (MsgData^.GetFrom);
        NewData^.SetTo       (MsgData^.GetTo);
        NewData^.SetSubj     (MsgData^.GetSubj);
        NewData^.SetDate     (MsgData^.GetDate);
        NewData^.SetTime     (MsgData^.GetTime);
        NewData^.SetLocal    (MsgData^.IsLocal);
        NewData^.SetPriv     (MsgData^.IsPriv);
        NewData^.SetSent     (MsgData^.IsSent);
        NewData^.SetCrash    (MsgData^.IsCrash);
        NewData^.SetRcvd     (MsgData^.IsRcvd);
//        NewData^.SetHold     (MsgData^.IsHold);
        NewData^.SetEcho     (Not MsgData^.IsEchoed);
        NewData^.SetKillSent (MsgData^.IsKillSent);
        NewData^.SetRefer    (MsgData^.GetRefer);
        NewData^.SetSeeAlso  (MsgData^.GetSeeAlso);

        Case MsgBase.NetType of
          0    : NewData^.SetMailType(mmtNormal);
          1..2 : NewData^.SetMailType(mmtEchoMail);
          3    : NewData^.SetMailType(mmtNetMail);
        End;

        NewData^.SetOrig (MsgData^.GetOrigAddr);
        NewData^.SetDest (MsgData^.GetDestAddr);

        MsgData^.MsgTxtStartUp;

        While Not MsgData^.EOM Do
          NewData^.DoStringLn(MsgData^.GetString(79));

        NewData^.WriteMsg;

        Link.OldNum := MsgData^.GetMsgNum;
        Link.NewNum := NewData^.GetHighMsgNum;

        LinkFile.WriteBlock (Link, SizeOf(Link));
      End;

      MsgData^.SeekNext;
    End;

    // cycle through old lastread pointers and generate new ones

    UserTotal := GetUserBaseSize;

    For Count := 1 to UserTotal Do Begin
      Link.OldNum := MsgData^.GetLastRead (Count);
      NewData^.SetLastRead (Count, GetMessageLink(Link.OldNum, False));
    End;

    // cycle through all messages and update referto/seealso

    NewData^.SeekFirst(1);

    While NewData^.SeekFound Do Begin
      NewData^.MsgStartUp;

      Link.OldNum := NewData^.GetRefer;
      Link.NewNum := NewData^.GetSeeAlso;

      If (Link.OldNum <> 0) Then Link.OldNum := GetMessageLink(Link.OldNum, True);
      If (Link.NewNum <> 0) Then Link.NewNum := GetMessageLink(Link.NewNum, True);

      If (Link.OldNum <> NewData^.GetRefer) or (Link.NewNum <> NewData^.GetSeeAlso) Then Begin
        NewData^.SetRefer   (Link.OldNum);
        NewData^.SetSeeAlso (Link.NewNum);

        NewData^.ReWriteHdr;
      End;

      NewData^.SeekNext;
    End;

    BaseKills := MsgData^.GetHighMsgNum - NewData^.GetHighMsgNum;

    Inc (TotalKills, BaseKills);

    MsgData^.CloseMsgBase;
    NewData^.CloseMsgBase;

    Dispose (MsgData, Done);
    Dispose (NewData, Done);

    LinkFile.Free;

    FileErase (TempPath + TempName + '.tmp');

    Case MsgBase.BaseType of
      0 : Begin
            FileErase (MsgBase.Path + MsgBase.FileName + '.jhr');
            FileErase (MsgBase.Path + MsgBase.FileName + '.jdt');
            FileErase (MsgBase.Path + MsgBase.FileName + '.jdx');
            FileErase (MsgBase.Path + MsgBase.FileName + '.jlr');

            FileRename (TempPath + TempName + '.jhr', MsgBase.Path + MsgBase.FileName + '.jhr');
            FileRename (TempPath + TempName + '.jdt', MsgBase.Path + MsgBase.FileName + '.jdt');
            FileRename (TempPath + TempName + '.jdx', MsgBase.Path + MsgBase.FileName + '.jdx');
            FileRename (TempPath + TempName + '.jlr', MsgBase.Path + MsgBase.FileName + '.jlr');
          End;
      1 : Begin
            FileErase (MsgBase.Path + MsgBase.FileName + '.sqd');
            FileErase (MsgBase.Path + MsgBase.FileName + '.sqi');
            FileErase (MsgBase.Path + MsgBase.FileName + '.sql');

            FileRename (TempPath + TempName + '.sqd', MsgBase.Path + MsgBase.FileName + '.sqd');
            FileRename (TempPath + TempName + '.sqi', MsgBase.Path + MsgBase.FileName + '.sqi');
            FileRename (TempPath + TempName + '.sql', MsgBase.Path + MsgBase.FileName + '.sql');
          End;
    End;

    Log (2, '+', '      Removed ' + strI2S(BaseKills) + ' msgs');
  End;

Var
  BaseFile : File of RecMessageBase;
  Base     : RecMessageBase;
Begin
  ProcessName   ('Packing Message Bases', True);
  ProcessResult (rWORKING, False);

  Assign (BaseFile, bbsCfg.DataPath + 'mbases.dat');

  If ioReset (BaseFile, SizeOf(Base), fmRWDN) Then Begin
    While Not Eof(BaseFile) Do Begin
      Read (BaseFile, Base);

      ProcessStatus (Base.Name, False);
      BarOne.Update (FilePos(BaseFile), FileSize(BaseFile));

      PackOneBase (Base);
    End;

    Close (BaseFile);
  End;

  ProcessStatus ('Removed |15' + strI2S(TotalKills) + ' |07msgs in |15' + strI2S(BaseTotal) + ' |07bases', True);
  ProcessResult (rDONE, True);
End;

End.

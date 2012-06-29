Unit bbs_MsgBase;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  m_DateTime,
  bbs_Common,
  bbs_General,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

Type
  TMsgBase = Class
    MBaseFile : File of RecMessageBase;
    MScanFile : File of MScanRec;
    GroupFile : File of RecGroup;
    TotalMsgs : Integer;
    TotalConf : Integer;
    MsgBase   : PMsgBaseABS;
    MBase     : RecMessageBase;
    MScan     : MScanRec;
    Group     : RecGroup;
    MsgText   : RecMessageText;
    WereMsgs  : Boolean;
    Reading   : Boolean;

    Constructor Create   (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Function    OpenCreateBase      (Var Msg: PMsgBaseABS; Var Area: RecMessageBase) : Boolean;
    Procedure   AppendMessageText   (Var Msg: PMsgBaseABS; Lines: Integer; ReplyID: String);
    Procedure   AssignMessageData   (Var Msg: PMsgBaseABS);
    Function    GetTotalMessages    (Var TempBase: RecMessageBase) : LongInt;
    Procedure   PostTextFile        (Data: String; AllowCodes: Boolean);
    Function    SaveMessage         (mArea: RecMessageBase; mFrom, mTo, mSubj: String; mAddr: RecEchoMailAddr; mLines: Integer) : Boolean;
    Function    ListAreas           (Compress: Boolean) : Integer;
    Procedure   ChangeArea          (Data: String);
    Procedure   SetMessageScan;
    Procedure   GetMessageScan;
    Procedure   SendMassEmail;
    Procedure   MessageUpload       (Var CurLine: SmallInt);
    Procedure   ReplyMessage        (Email: Boolean; ListMode: Byte; ReplyID: String);
    Procedure   EditMessage;
    Function    ReadMessages        (Mode : Char; SearchStr: String) : Boolean;
    Procedure   ToggleNewScan       (QWK: Boolean);
    Procedure   MessageGroupChange  (Ops: String; FirstBase, Intro : Boolean);
    Procedure   PostMessage         (Email: Boolean; Data: String);
    Procedure   CheckEMail;
    Procedure   MessageNewScan      (Data: String);
    Procedure   MessageQuickScan    (Data: String);
    Procedure   GlobalMessageSearch (Mode: Char);
    Procedure   SetMessagePointers;
    Procedure   ViewSentEmail;
    Procedure   DownloadQWK         (Data: String);
    Procedure   UploadREP;
    Procedure   WriteCONTROLDAT;
    Function    WriteMSGDAT : LongInt;
    Function    ResolveOrigin       (var mArea: RecMessageBase) : String;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core,
  bbs_User,
  bbs_NodeInfo,
  bbs_cfg_UserEdit;

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

Constructor TMsgBase.Create (Var Owner: Pointer);
Begin
  Inherited Create;

  MBase.Name := 'None';
  Group.Name := 'None';
  WereMsgs   := False;
  Reading    := False;
End;

Destructor TMsgBase.Destroy;
Begin
  Inherited Destroy;
End;

Function TMsgBase.OpenCreateBase (Var Msg: PMsgBaseABS; Var Area: RecMessageBase) : Boolean;
Begin
  Result := False;

  Case Area.BaseType of
    0 : Msg := New(PMsgBaseJAM, Init);
    1 : Msg := New(PMsgBaseSquish, Init);
  End;

  Msg^.SetMsgPath  (Area.Path + Area.FileName);
  Msg^.SetTempFile (Session.TempPath + 'msgbuf.');

  If Not Msg^.OpenMsgBase Then
    If Not Msg^.CreateMsgBase (Area.MaxMsgs, Area.MaxAge) Then Begin
      Dispose (Msg, Done);
      Exit;
    End Else
    If Not Msg^.OpenMsgBase Then Begin
      Dispose (Msg, Done);
      Exit;
    End;

  Result := True;
End;

Function TMsgBase.GetTotalMessages (Var TempBase: RecMessageBase) : LongInt;
Var
  TempMsg : PMsgBaseABS;
Begin
  Result := 0;

  If TempBase.Name = 'None' Then Exit;

  If OpenCreateBase(TempMsg, TempBase) Then Begin
    Result := TempMsg^.NumberOfMsgs;

    TempMsg^.CloseMsgBase;

    Dispose (TempMsg, Done);
  End;
End;

Procedure TMsgBase.SetMessageScan;
Var
  Count : Integer;
  Temp  : MScanRec;
Begin
  Temp.NewScan  := MBase.DefNScan;
  Temp.QwkScan  := MBase.DefQScan;

  Assign (MScanFile, MBase.Path + MBase.FileName + '.scn');
  {$I-} Reset (MScanFile); {$I+}

  If IoResult <> 0 Then ReWrite (MScanFile);

  If FileSize(MScanFile) < Session.User.UserNum - 1 Then Begin
    Seek (MScanFile, FileSize(MScanFile));

    For Count := FileSize(MScanFile) to Session.User.UserNum - 1 Do
      Write (MScanFile, Temp);
  End;

  Seek  (MScanFile, Session.User.UserNum - 1);
  Write (MScanFile, MScan);
  Close (MScanFile);
End;

Procedure TMsgBase.GetMessageScan;
Begin
  MScan.NewScan := MBase.DefNScan;
  MScan.QwkScan := MBase.DefQScan;

  Assign (MScanFile, MBase.Path + MBase.FileName + '.scn');
  {$I-} Reset (MScanFile); {$I+}

  If IoResult <> 0 Then Exit;

  If FileSize(MScanFile) >= Session.User.UserNum Then Begin    {filesize and usernum are }
    Seek (MScanFile, Session.User.UserNum - 1);                {not zero based           }
    Read (MScanFile, MScan);

    { added security measure for forced reading bases }

    If MBase.DefNScan = 2 Then MScan.NewScan := 2;
    If MBase.DefQScan = 2 Then MScan.QwkScan := 2;
  End;

  Close (MScanFile);
End;

Procedure TMsgBase.AppendMessageText (Var Msg: PMsgBaseABS; Lines: Integer; ReplyID: String);
Var
  DF : File;
  S  : String;
  A  : SmallInt;
Begin
  If MBase.NetType > 0 Then Begin
    Msg^.DoStringLn (#1 + 'MSGID: ' + strAddr2Str(Config.NetAddress[MBase.NetAddr]) + ' ' + strI2H(CurDateDos));

    If ReplyID <> '' Then
      Msg^.DoStringLn (#1 + 'REPLY: ' + ReplyID);
  End;

  For A := 1 to Lines Do
    Msg^.DoStringLn(MsgText[A]);

  If Session.User.ThisUser.SigUse and (Session.User.ThisUser.SigLength > 0) Then Begin

    Assign (DF, Config.DataPath + 'autosig.dat');
    Reset  (DF, 1);
    Seek   (DF, Session.User.ThisUser.SigOffset);

    Msg^.DoStringLn('');

    For A := 1 to Session.User.ThisUser.SigLength Do Begin
      BlockRead (DF, S[0], 1);
      BlockRead (DF, S[1], Ord(S[0]));
      Msg^.DoStringLn(S);
    End;

    Close (DF);
  End;

  If MBase.NetType > 0 Then Begin
    Msg^.DoStringLn (#13 + '--- ' + mysSoftwareID + ' BBS v' + mysVersion + ' (' + OSID + ')');
    Msg^.DoStringLn (' * Origin: ' + ResolveOrigin(MBase) + ' (' + strAddr2Str(Config.NetAddress[MBase.NetAddr]) + ')');
  End;
End;

Procedure TMsgBase.AssignMessageData (Var Msg: PMsgBaseABS);
Var
  Addr    : RecEchoMailAddr;
  SemFile : Text;
Begin
  Msg^.StartNewMsg;

  If MBase.Flags And MBRealNames <> 0 Then
    Msg^.SetFrom(Session.User.ThisUser.RealName)
  Else
    Msg^.SetFrom(Session.User.ThisUser.Handle);

  Msg^.SetLocal (True);

  If MBase.NetType > 0 Then Begin
    If MBase.NetType = 3 Then
      Msg^.SetMailType(mmtNetMail)
    Else
      Msg^.SetMailType(mmtEchoMail);

    Addr := Config.NetAddress[MBase.NetAddr];

    Msg^.SetOrig(Addr);

    Case MBase.NetType of
      1 : Begin
            Assign (SemFile, Config.SemaPath + fn_SemFileEcho);
            If Session.ExitLevel > 5 Then Session.ExitLevel := 7 Else Session.ExitLevel := 5;
          End;
      2 : Begin
            Assign (SemFile, Config.SemaPath + fn_SemFileNews);
            If Session.ExitLevel > 5 Then Session.ExitLevel := 7 Else Session.ExitLevel := 5;
          End;
      3 : Begin
            Assign (SemFile, Config.SemaPath + fn_SemFileNet);
            If Session.ExitLevel = 5 Then Session.ExitLevel := 7 Else Session.ExitLevel := 6;
          End;
    End;

    ReWrite (SemFile);
    Close   (SemFile);

  End Else
    Msg^.SetMailType(mmtNormal);

  Msg^.SetPriv (MBase.Flags and MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, False));
End;

Procedure TMsgBase.ChangeArea (Data: String);
Var
  Count    : LongInt;
  Total    : Word;
  Old      : RecMessageBase;
  Str      : String[5];
  Compress : Boolean;
Begin
  Compress := Config.MCompress;
  Old      := MBase;

  {$IFDEF LOGGING}
    Session.SystemLog('MsgAreaChange: ' + Data);
    Session.SystemLog('      CurArea: ' + strI2S(Session.User.ThisUser.LastMBase));
  {$ENDIF}

  If (Data = '+') or (Data = '-') Then Begin
    Reset (MBaseFile);

    Count := Session.User.ThisUser.LastMBase - 1;

    Repeat
      Case Data[1] of
        '+' : Inc(Count);
        '-' : Dec(Count);
      End;

      {$I-}
      Seek (MBaseFile, Count);
      Read (MBaseFile, MBase);
      {$I+}

      If IoResult <> 0 Then Break;

      If Session.User.Access(MBase.ListACS) Then Begin
        Session.User.ThisUser.LastMBase := FilePos(MBaseFile);
        Close (MBaseFile);
        Exit;
      End;
    Until False;

    Close (MBaseFile);

    MBase := Old;

    Exit;
  End;

  Count := strS2I(Data);

  {$IFDEF LOGGING}
    Session.SystemLog('Numeric change converstion: ' + strI2S(Count));
  {$ENDIF}

  If Count > 0 Then Begin
    Inc (Count);

    Reset (MBaseFile);

    If Count <= FileSize(MBaseFile) Then Begin
      Seek (MBaseFile, Count - 1);
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ListACS) Then Begin
        Session.User.ThisUser.LastMBase := FilePos(MBaseFile)
      End Else
        MBase := Old;
    End;

    Close (MBaseFile);

    Exit;
  End;

  If Pos('NOLIST', strUpper(Data)) > 0 Then Begin
    Reset (MBaseFile);
    Total := FileSize(MBaseFile);
    Close (MBaseFile);
  End Else
    Total := ListAreas(Compress);

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(94));
    MBase := Old;
  End Else Begin
    Repeat
      Session.io.OutFull (Session.GetPrompt(102));

      Str := Session.io.GetInput(5, 5, 12, '');

      If Str = '?' Then Begin
        Compress := Config.MCompress;
        Total    := ListAreas(Compress);
      End Else
        Break;
    Until False;

    Count := strS2I(Str);

    If (Count > 0) and (Count <= Total) Then Begin
      Reset (MBaseFile);
      If Not Compress Then Begin
        Seek (MBaseFile, Count - 1);
        Read (MBaseFile, MBase);

        If Not Session.User.Access(MBase.ListACS) Then Begin
          MBase := Old;
          Close (MBaseFile);
          Exit;
        End;
      End Else Begin
        Total := 0;

        While Not Eof(MBaseFile) And (Count <> Total) Do Begin
          Read (MBaseFile, MBase);
          If Session.User.Access(MBase.ListACS) Then Inc(Total);
        End;

        If Count <> Total Then Begin
          Close (MBaseFile);
          MBase := OLD;
          Exit;
        End;
      End;

      Session.User.ThisUser.LastMBase := FilePos(MBaseFile);

      Close (MBaseFile);
    End Else
      MBase := Old;
  End;
End;

Procedure TMsgBase.ToggleNewScan (QWK: Boolean);
Var
  Total: LongInt;

  Procedure List_Bases;
  Begin
    Session.io.PausePtr   := 1;
    Session.io.AllowPause := True;

    If QWK Then
      Session.io.OutFullLn (Session.GetPrompt(90))
    Else
      Session.io.OutFullLn (Session.GetPrompt(91));

    Session.io.OutFullLn (Session.GetPrompt(92));

    Total := 0;

    Reset (MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ListACS) Then Begin
        Inc (Total);

        Session.io.PromptInfo[1] := strI2S(Total);
        Session.io.PromptInfo[2] := MBase.Name;

        GetMessageScan;

        If ((MScan.NewScan > 0) And Not QWK) or ((MScan.QwkScan > 0) And QWK) Then
          Session.io.PromptInfo[3] := 'Yes'
        Else
          Session.io.PromptInfo[3] := 'No';

        Session.io.OutFull (Session.GetPrompt(93));

        If (Total MOD 2 = 0) And (Total > 0) Then Session.io.OutRawLn('');
      End;

      If EOF(MBaseFile) and (Total MOD 2 <> 0) Then Session.io.OutRawLn('');

      If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;

    Session.io.OutFull (Session.GetPrompt(430));
  End;

  Procedure ToggleBase (A : Word);
  Var
    B : Word;
  Begin
    B := 0;

    Reset (MBaseFile);

    Repeat
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ListACS) Then Inc(B);

      If A = B Then Break;
    Until False;

    GetMessageScan;

    Session.io.PromptInfo[1] := MBase.Name;

    If QWK Then Begin
      Case MScan.QwkScan of
        0 : Begin
              MScan.QwkScan := 1;
              Session.io.OutFullLn (Session.GetPrompt(97));
            End;
        1 : Begin
              MScan.QwkScan := 0;
              Session.io.OutFullLn (Session.GetPrompt(96));
            End;
        2 : Session.io.OutFullLn (Session.GetPrompt(302));
      End;
    End Else Begin
      Case MScan.NewScan of
        0 : Begin
              MScan.NewScan := 1;
              Session.io.OutFullLn (Session.GetPrompt(99));
            End;
        1 : Begin
              MScan.NewScan := 0;
              Session.io.OutFullLn (Session.GetPrompt(98));
            End;
        2 : Session.io.OutFullLn (Session.GetPrompt(302));
      End;
    End;

    SetMessageScan;
  End;

Var
  Old  : RecMessageBase;
  Temp : String[11];
  A    : Word;
  N1   : Word;
  N2   : Word;
Begin
  Old := MBase;

  List_Bases;

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(94));
    MBase := Old;
    Exit;
  End;

  Repeat
    Session.io.OutFull (Session.GetPrompt(95));

    Temp := Session.io.GetInput(11, 11, 12, '');

    If (Temp = '') or (Temp = 'Q') Then Break;

    If Temp = '?' Then
      List_Bases
    Else Begin
      If Pos('-', Temp) > 0 Then Begin
        N1 := strS2I(Copy(Temp, 1, Pos('-', Temp) - 1));
        N2 := strS2I(Copy(Temp, Pos('-', Temp) + 1, Length(Temp)));
      End Else Begin
        N1 := strS2I(Temp);
        N2 := N1;
      End;

      For A := N1 to N2 Do
        If (A > 0) and (A <= Total) Then ToggleBase(A);
    End;
  Until False;

  Close (MBaseFile);

  MBase := Old;
End;

Procedure TMsgBase.MessageGroupChange (Ops : String; FirstBase, Intro : Boolean);
Var
  A      : Word;
  Total  : Word;
  tGroup : RecGroup;
  tMBase : RecMessageBase;
  tLast  : Word;
  Areas  : Word;
  Data   : Word;
Begin
  tGroup := Group;

  If (Ops = '+') or (Ops = '-') Then Begin
    Reset (GroupFile);

    A := Session.User.ThisUser.LastMGroup - 1;

    Repeat
      Case Ops[1] of
        '+' : Inc(A);
        '-' : Dec(A);
      End;

      {$I-}
      Seek (GroupFile, A);
      Read (GroupFile, Group);
      {$I+}

      If IoResult <> 0 Then Break;

      If Session.User.Access(Group.ACS) Then Begin
        Session.User.ThisUser.LastMGroup := FilePos(GroupFile);
        Close (GroupFile);

        If Intro Then Session.io.OutFile ('group' + strI2S(Session.User.ThisUser.LastMGroup), True, 0);

        If FirstBase Then Begin
          Session.User.ThisUser.LastMBase := 0;
          ChangeArea('+');
        End;

        Exit;
      End;
    Until False;

    Close (GroupFile);

    Group := tGroup;

    Exit;
  End;

  Data := strS2I(Ops);

  Reset (GroupFile);

  If Data > 0 Then Begin
    If Data > FileSize(GroupFile) Then Begin
      Close (GroupFile);
      Exit;
    End;

    Seek (GroupFile, Data-1);
    Read (GroupFile, Group);

    If Session.User.Access(Group.ACS) Then Begin
      Session.User.ThisUser.LastMGroup := FilePos(GroupFile);
      If Intro Then Session.io.OutFile ('group' + strI2S(Data), True, 0);
    End Else
      Group := tGroup;

    Close (GroupFile);

    If FirstBase Then Begin
      Session.User.ThisUser.LastMBase := 1;
      ChangeArea('+');
    End;

    Exit;
  End;

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  Session.io.OutFullLn (Session.GetPrompt(174)); { was after reset(groupfile) }

  tLast := Session.User.ThisUser.LastMGroup;
  Total := 0;

  While Not Eof(GroupFile) Do Begin
    Read (GroupFile, Group);

    If Not Group.Hidden And Session.User.Access(Group.ACS) Then Begin

      Areas := 0;
      Session.User.ThisUser.LastMGroup := FilePos(GroupFile);

      If Config.MShowBases Then Begin
        Reset (MBaseFile);
        Read  (MBaseFile, tMBase); { Skip EMAIL base }

        While Not Eof(MBaseFile) Do Begin
          Read (MBaseFile, tMBase);
          If Session.User.Access(tMBase.ListACS) Then Inc(Areas);
        End;

        Close (MBaseFile);
      End;

      Inc (Total);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := Group.Name;
      Session.io.PromptInfo[3] := strI2S(Areas);

      Session.io.OutFullLn (Session.GetPrompt(175));

      If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;
  End;

  Session.User.ThisUser.LastMGroup := tLast;

  If Total = 0 Then
    Session.io.OutFullLn (Session.GetPrompt(176))
  Else Begin
    Session.io.OutFull (Session.GetPrompt(177));

    A := strS2I(Session.io.GetInput(5, 5, 11, ''));

    If (A > 0) and (A <= Total) Then Begin
      Total := 0;

      Reset (GroupFile);

      Repeat
        Read (GroupFile, Group);
        If Not Group.Hidden And Session.User.Access(Group.ACS) Then Inc(Total);
        If A = Total Then Break;
      Until False;

      Session.User.ThisUser.LastMGroup := FilePos(GroupFile);

      If Intro Then Session.io.OutFile ('group' + strI2S(Session.User.ThisUser.LastMGroup), True, 0);

      Session.User.ThisUser.LastMBase := 1;

      ChangeArea('+');
    End Else
      Group := tGroup;
  End;

  Close (GroupFile);
End;

Function TMsgBase.ListAreas (Compress: Boolean) : Integer;
Var
  Total    : Word = 0;
  Listed   : Word = 0;
  TempBase : RecMessageBase;
Begin
  Reset (MBaseFile);

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, TempBase);

    If Session.User.Access(TempBase.ListACS) Then Begin
      Inc (Listed);

      If Listed = 1 Then
        Session.io.OutFullLn(Session.GetPrompt(100));

      If Compress Then
        Inc (Total)
      Else
        Total := FilePos(MBaseFile);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := TempBase.Name;
      Session.io.PromptInfo[3] := strI2S(GetTotalMessages(TempBase));

      Session.io.OutFull (Session.GetPrompt(101));

      If (Listed MOD Config.MColumns = 0) and (Listed > 0) Then Session.io.OutRawLn('');
    End;

    If Eof(MBaseFile) and (Listed MOD Config.MColumns <> 0) Then Session.io.OutRawLn('');

    If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Begin
                Total := FileSize(MBaseFile);
                Break;
              End;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Close (MBaseFile);

  Result := Total;
End;

Procedure TMsgBase.ReplyMessage (Email: Boolean; ListMode: Byte; ReplyID: String);
Var
  ToWho  : String[30];
  Subj   : String[60];
  Addr   : RecEchomailAddr;
  MsgNew : PMsgBaseABS;
  Temp1  : String;
  Temp2  : String[2];
  Temp3  : String[80];
  tFile  : Text;
  Lines  : SmallInt;
Begin
  If Not Session.User.Access(MBase.PostACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(105));
    Exit;
  End;

  Set_Node_Action (Session.GetPrompt(349));

  If ListMode = 0 Then
    Session.io.OutFull (Session.GetPrompt(407))
  Else
    Session.io.OutFull (Session.GetPrompt(408));

  Repeat
    ToWho := Session.io.GetInput(30, 30, 18, MsgBase^.GetFrom);

    If ToWho = '' Then Exit;

    If Not Email Then Break;

    If Not Session.User.FindUser(ToWho, False) Then Begin
      Session.io.PromptInfo[1] := ToWho;

      Session.io.OutFullLn (Session.GetPrompt(161));

      ToWho := MsgBase^.GetFrom;
    End Else
      Break;
  Until False;

  If MBase.NetType = 3 Then Begin
    Session.io.OutFull (Session.GetPrompt(342));

    MsgBase^.GetOrig(Addr);

    Temp3 := Session.io.GetInput(20, 20, 12, strAddr2Str(Addr));

    If Not strStr2Addr (Temp3, Addr) Then Exit;
  End;

  Subj := MsgBase^.GetSubj;

  If Pos ('Re:', Subj) = 0 Then Subj := 'Re: ' + Subj;

  Session.io.OutFull (Session.GetPrompt(451));

  Subj := Session.io.GetInput (60, 60, 11, Subj);

  If Subj = '' Then Exit;

  Assign (tFile, Session.TempPath + 'msgtmp');
  {$I-} ReWrite (tFile); {$I+}
  If IoResult = 0 Then Begin
    Temp3 := MsgBase^.GetFrom;
    Temp2 := Temp3[1];

    If Pos(' ', Temp3) > 0 Then
      Temp2 := Temp2 + Temp3[Succ(Pos(' ', Temp3))];

    Temp1 := Session.GetPrompt(464);

    Temp1 := strReplace(Temp1, '|&1', MsgBase^.GetDate);
    Temp1 := strReplace(Temp1, '|&2', MsgBase^.GetFrom);
    Temp1 := strReplace(Temp1, '|&3', Temp2);

    WriteLn (tFile, Temp1);
    WriteLn (tFile, ' ');

    Lines := 0;

    MsgBase^.MsgTxtStartUp;

    While Not MsgBase^.EOM and (Lines < mysMaxMsgLines - 2) Do Begin
      Inc (Lines);

      Temp3 := MsgBase^.GetString(79);

      If Temp3[1] <> #1 Then
        WriteLn (tFile, Temp2 + '> ' + Copy(Temp3, 1, 74));
    End;

    Close (tFile);
  End;

  Lines := 0;

  Session.io.PromptInfo[1] := ToWho;
  Session.io.PromptInfo[2] := Subj;

  If Editor(Lines, 78, mysMaxMsgLines, False, False, Subj) Then Begin

    Session.io.OutFull (Session.GetPrompt(107));

    Case MBase.BaseType of
      0 : MsgNew := New(PMsgBaseJAM, Init);
      1 : MsgNew := New(PMsgBaseSquish, Init);
    End;

    MsgNew^.SetMsgPath (MBase.Path + MBase.FileName);

    If Not MsgNew^.OpenMsgBase Then Begin
      Dispose (MsgNew, Done);
      Exit;
    End;

    AssignMessageData(MsgNew);

    Case MBase.NetType of
      2 : MsgNew^.SetTo('All');
      3 : Begin
            MsgNew^.SetDest     (Addr);
            MsgNew^.SetCrash    (Config.netCrash);
            MsgNew^.SetHold     (Config.netHold);
            MsgNew^.SetKillSent (Config.netKillSent);
            MsgNew^.SetTo       (ToWho);

            Addr := Config.NetAddress[MBase.NetAddr];
            MsgNew^.SetOrig (Addr);
          End;
    Else
      MsgNew^.SetTo(ToWho);
    End;

    MsgNew^.SetSubj(Subj);
    MsgNew^.SetRefer(MsgBase^.GetMsgNum);

    AppendMessageText (MsgNew, Lines, ReplyID);

    MsgNew^.WriteMsg;
    MsgNew^.CloseMsgBase;

    If MsgBase^.GetSeeAlso = 0 Then Begin
      MsgBase^.MsgStartUp;
      MsgBase^.SetSeeAlso(MsgNew^.GetMsgNum);
      MsgBase^.ReWriteHdr;
    End;

    If Email Then Begin
      Session.SystemLog ('Sent Email to ' + MsgNew^.GetTo);

      Inc (Session.User.ThisUser.Emails);
      Inc (Session.HistoryEmails);
    End Else Begin
      Session.SystemLog ('Posted #' + strI2S(MsgNew^.GetMsgNum) + ': "' + Subj + '" to ' + strStripMCI(MBase.Name));

      Inc (Session.User.ThisUser.Posts);
      Inc (Session.HistoryPosts);
    End;

    Dispose (MsgNew, Done);

    Session.io.OutFullLn (Session.GetPrompt(122));
  End Else
    Session.io.OutFullLn (Session.GetPrompt(109));

  FileErase(Session.TempPath + 'msgtmp');
End;

Procedure TMsgBase.EditMessage;
Var
  A        : Integer;
  Lines    : Integer;
  Temp1    : String;
  DestAddr : RecEchoMailAddr;

  Procedure ReadText;
  Begin
    MsgBase^.MsgTxtStartUp;

    Lines := 0;

    While Not MsgBase^.EOM and (Lines < mysMaxMsgLines) Do Begin
      Inc (Lines);
      MsgText[Lines] := MsgBase^.GetString(79);
    End;

    If Lines < mysMaxMsgLines Then Begin
      Inc (Lines);
      MsgText[Lines] := '';
    End;
  End;

Begin
  ReadText;

  Repeat
    Session.io.PromptInfo[1] := MsgBase^.GetTo;
    Session.io.PromptInfo[2] := MsgBase^.GetSubj;

    If MBase.NetType = 3 Then Begin
      MsgBase^.GetDest(DestAddr);
      Session.io.PromptInfo[1] := Session.io.PromptInfo[1] + ' (' + strAddr2Str(DestAddr) + ')';
    End;

    Session.io.OutFull (Session.GetPrompt(296));

    Case Session.io.OneKey('ABQ!', True) of
      'A' : Begin
              Session.io.OutFull (Session.GetPrompt(297));

              If MBase.NetType = 3 Then Begin
                Temp1 := Session.io.GetInput(30, 30, 11, MsgBase^.GetTo);

                Session.io.OutFull (Session.GetPrompt(298));

                If strStr2Addr(Session.io.GetInput(20, 20, 12, strAddr2Str(DestAddr)), DestAddr) Then Begin
                  MsgBase^.SetTo(Temp1);
                  MsgBase^.SetDest(DestAddr)
                End;
              End Else
              If MBase.Flags And MBPrivate <> 0 Then Begin
                Temp1 := Session.io.GetInput (30, 30, 11, MsgBase^.GetTo);

                If Session.User.SearchUser(Temp1, MBase.Flags and MBRealNames <> 0) Then
                  MsgBase^.SetTo(Temp1);
              End Else
                MsgBase^.SetTo(Session.io.GetInput(30, 30, 11, MsgBase^.GetTo));
            End;
      'B' : Begin
              Session.io.OutFull (Session.GetPrompt(299));

              MsgBase^.SetSubj(Session.io.GetInput(50, 50, 11, MsgBase^.GetSubj));
            End;
      '!' : Begin
              Temp1 := MsgBase^.GetSubj;

              If Editor(Lines, 78, mysMaxMsgLines, False, False, Temp1) Then
                MsgBase^.SetSubj(Temp1)
              Else
                ReadText;
            End;
      'Q' : Begin
              If Session.io.GetYN(Session.GetPrompt(300), True) Then Begin
                MsgBase^.EditMsgInit;

                For A := 1 to Lines Do
                  MsgBase^.DoStringLn(MsgText[A]);

                MsgBase^.EditMsgSave;
              End;
              Break;
            End;

    End;
  Until False;
End;

Procedure TMsgBase.MessageUpload (Var CurLine: SmallInt);
Var
  FN : String[100];
  TF : Text;
  T1 : String[30];
  T2 : String[60];
  OK : Boolean;
Begin
  OK := False;

  T1 := Session.io.PromptInfo[1];
  T2 := Session.io.PromptInfo[2];

  Session.io.OutFull (Session.GetPrompt(352));

  If Session.LocalMode Then Begin
    FN := Session.io.GetInput(70, 70, 11, '');

    If FN = '' Then Exit;

    OK := FileExist(FN);
  End Else Begin
    FN := Session.TempPath + Session.io.GetInput(70, 70, 11, '');

    If Session.FileBase.SelectProtocol(False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(False, FN);

    OK := Session.FileBase.dszSearch(JustFile(FN));
  End;

  If OK Then Begin
    Assign (TF, FN);
    Reset  (TF);

    While Not Eof(TF) and (CurLine < mysMaxMsgLines) Do Begin
      ReadLn (TF, MsgText[CurLine]);
      Inc    (CurLine);
    End;

    Close (TF);
  End;

  If Not Session.LocalMode Then FileErase(FN);

  DirClean(Session.TempPath, 'msgtmp');

  Session.io.PromptInfo[1] := T1;
  Session.io.PromptInfo[2] := T2;
End;

Function TMsgBase.ReadMessages (Mode : Char; SearchStr : String) : Boolean;
Var
  ReadRes   : Boolean;
  ScanMode  : Byte;
  ValidKeys : String;
  HelpFile  : String[8];
  LastRead  : LongInt;
  ListMode  : Byte;
  ReplyID   : String[31];

  Procedure Set_Message_Security;
  Begin
    If Mode = 'E' Then Begin
      ValidKeys := 'ADJLNPQRX?'#13;
      HelpFile  := 'emailhlp';
    End Else
    If Session.User.Access(MBase.SysopACS) or Session.User.IsThisUser(MsgBase^.GetFrom) Then Begin
      ValidKeys := 'ADEGHIJLMNPQRTX[]?'#13;
      HelpFile  := 'readshlp';
    End Else Begin
      ValidKeys := 'AGHIJLNPQRTX[]?'#13;
      HelpFile  := 'readhlp';
    End;
  End;

  Function Move_Message : Boolean;
  Var
    MsgNew   : PMsgBaseABS;
    Str      : String;
    TempBase : RecMessageBase;
    Area     : Integer;
    Addr     : RecEchoMailAddr;
  Begin
    Result := False;
    Session.User.IgnoreGroup  := True;

    Repeat
      Session.io.OutFull (Session.GetPrompt(282));

      Str := Session.io.GetInput(4, 4, 12, '');

      If Str = '?' Then
        ListAreas(False)
      Else Begin
        Reset (MBaseFile);

        Area := strS2I(Str) - 1;

        If (Area > 0) and (Area < FileSize(MBaseFile) - 1) Then Begin
          Seek  (MBaseFile, Area);
          Read  (MBaseFile, TempBase);
          Close (MBaseFile);

          If Not Session.User.Access(TempBase.PostACS) Then Begin
            Session.io.OutFullLn (Session.GetPrompt(105));
            Break;
          End;

          Session.io.PromptInfo[1] := TempBase.Name;

          Session.io.OutFullLn (Session.GetPrompt(318));

          If Not OpenCreateBase(MsgNew, TempBase) Then Break;

          MsgNew^.StartNewMsg;
          MsgNew^.SetFrom (MsgBase^.GetFrom);
          MsgNew^.SetLocal (True);

          Case TempBase.NetType of
            0 : MsgNew^.SetMailType(mmtNormal);
            3 : MsgNew^.SetMailType(mmtNetMail);
          Else
            MsgNew^.SetMailType(mmtEchoMail);
          End;

          MsgBase^.GetOrig(Addr);
          MsgNew^.SetOrig(Addr);
          MsgNew^.SetPriv(MsgBase^.IsPriv);
          MsgNew^.SetDate(MsgBase^.GetDate);
          MsgNew^.SetTime(MsgBase^.GetTime);
          MsgNew^.SetTo(MsgBase^.GetTo);
          MsgNew^.SetSubj(MsgBase^.GetSubj);

          MsgBase^.MsgTxtStartUp;

          While Not MsgBase^.EOM Do Begin
            Str := MsgBase^.GetString(79);
            MsgNew^.DoStringLn(Str);
          End;

          MsgNew^.WriteMsg;

          MsgNew^.CloseMsgBase;

          Session.SystemLog('Moved msg to ' + strStripMCI(TempBase.Name));

          Dispose (MsgNew, Done);

          MsgBase^.DeleteMsg;

          Move_Message := True;
          Break;
        End Else Begin
          Close (MBaseFile);
          Break;
        End;
      End;
    Until False;

    Session.User.IgnoreGroup := False;
  End;

  Procedure Export_Message;
  Var
    FN   : String;
    Temp : String;
    TF   : Text;
  Begin
    If Session.LocalMode Then Begin
      If ListMode = 0 Then
        Session.io.OutFull (Session.GetPrompt(363))
      Else
        Session.io.OutFull (Session.GetPrompt(415));

      FN := Session.io.GetInput(70, 70, 11, '');
    End Else Begin
      If ListMode = 0 Then
        Session.io.OutFull (Session.GetPrompt(326))
      Else
        Session.io.OutFull (Session.GetPrompt(414));

      FN := Session.TempPath + Session.io.GetInput(70, 70, 11, '');
    End;

    If FN = '' Then Exit;

    Session.io.PromptInfo[1] := JustFileName(FN);

    Assign  (TF, FN);
    {$I-} ReWrite (TF); {$I+}
    If IoResult = 0 Then Begin
      WriteLn (TF, 'From: ' + MsgBase^.GetFrom);
      WriteLn (TF, '  To: ' + MsgBase^.GetTo);
      WriteLn (TF, 'Subj: ' + MsgBase^.GetSubj);
      WriteLn (TF, 'Date: ' + MsgBase^.GetDate + ' ' + MsgBase^.GetTime);
      WriteLn (TF, 'Base: ' + MBase.Name);
      WriteLn (TF, '');

      MsgBase^.MsgTxtStartUp;

      While Not MsgBase^.EOM Do Begin
        Temp := MsgBase^.GetString(79);
        If Temp[1] <> #1 Then WriteLn (TF, Temp);
      End;

      Close (TF);

      Session.io.OutFullLn (Session.GetPrompt(327));

      If Not Session.LocalMode Then Begin
        Session.FileBase.SendFile(FN);
        FileErase(FN);
      End;
    End;
  End;

  Function SeekNextMsg (First, Back: Boolean): Boolean;
  Var
    Res : Boolean;
    Str : String;
  Begin
    Res := False;

    If (ScanMode = 3) and First Then Begin
      If Mode = 'S' Then Session.io.OutRawLn('');
      Session.io.OutFull (Session.GetPrompt(130));
    End;

    If Not First Then
      If Back Then
        MsgBase^.SeekPrior
      Else
        MsgBase^.SeekNext;

    While Not Res And MsgBase^.SeekFound Do Begin
      MsgBase^.MsgStartUp;

      Case ScanMode of
        0 : Res := True;
        1 : Res := Session.User.IsThisUser(MsgBase^.GetTo);
        2 : Res := Session.User.IsThisUser(MsgBase^.GetTo) or Session.User.IsThisUser(MsgBase^.GetFrom);
        3 : Begin
              Res := (Pos(SearchStr, strUpper(MsgBase^.GetTo)) > 0) or (Pos(SearchStr, strUpper(MsgBase^.GetFrom)) > 0) or
                     (Pos(SearchStr, strUpper(MsgBase^.GetSubj)) > 0);

              If Not Res Then Begin
                MsgBase^.MsgTxtStartUp;

                While Not Res And Not MsgBase^.EOM Do Begin
                  Str := strUpper(MsgBase^.GetString(79));
                  Res := Pos(SearchStr, Str) > 0;
                End;
              End;
            End;
        4 : Res := Session.User.IsThisUser(MsgBase^.GetFrom);
      End;

      If Not Res Then
        If Back Then
          MsgBase^.SeekPrior
        Else
          MsgBase^.SeekNext;
    End;

    If (ScanMode = 3) And First Then
      Session.io.OutBS (Screen.CursorX, True);

    If Not WereMsgs Then WereMsgs := Res;

    SeekNextMsg := Res;
  End;

  Procedure Assign_Header_Info;
  Var
    NetAddr : RecEchoMailAddr;
  Begin
    Session.io.PromptInfo[1] := MsgBase^.GetFrom;

    If MBase.NetType = 3 Then Begin
      MsgBase^.GetOrig(NetAddr);

      Session.io.PromptInfo[1] := Session.io.PromptInfo[1] + ' (' + strAddr2Str(NetAddr) + ')';
    End;

    Session.io.PromptInfo[2] := MsgBase^.GetTo;

    If MBase.NetType = 3 Then Begin
      MsgBase^.GetDest(NetAddr);
      Session.io.PromptInfo[2] := Session.io.PromptInfo[2] + ' (' + strAddr2Str(NetAddr) + ')';
    End;

    Session.io.PromptInfo[3]  := MsgBase^.GetSubj;
    Session.io.PromptInfo[4]  := MsgBase^.GetDate;
    Session.io.PromptInfo[10] := MsgBase^.GetTime;
    Session.io.PromptInfo[5]  := strI2S(MsgBase^.GetMsgNum);
    Session.io.PromptInfo[6]  := strI2S(MsgBase^.GetHighMsgNum);
    Session.io.PromptInfo[7]  := strI2S(MsgBase^.GetRefer);
    Session.io.PromptInfo[8]  := strI2S(MsgBase^.GetSeeAlso);

    If MsgBase^.IsLocal   Then Session.io.PromptInfo[9] := 'Local' Else Session.io.PromptInfo[9] := 'Echo'; //++lang
    If MsgBase^.IsPriv    Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' Private'; //++lang
    If MsgBase^.IsSent    Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' Sent'; //++lang
    If MsgBase^.IsDeleted Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' Deleted'; //++lang
  End;

  Procedure Send_Msg_Text (Str : String);
  Var
    B : Byte;
  Begin
    B := Pos('>', strStripL(Str, ' '));

    If (B > 0) and (B < 5) Then Begin
      Session.io.AnsiColor(MBase.ColQuote);
      Session.io.OutPipe (Str);
      Session.io.AnsiColor(MBase.ColText);
    End Else
    If Copy(Str, 1, 4) = '--- ' Then Begin
      Session.io.AnsiColor(MBase.ColTear);
      Session.io.OutPipe (Str);
      Session.io.AnsiColor(MBase.ColText);
    End Else
    If Copy(Str, 1, 2) = ' *' Then Begin
      Session.io.AnsiColor(MBase.ColOrigin);
      Session.io.OutPipe (Str);
      Session.io.AnsiColor(MBase.ColText);
    End Else
      Session.io.OutPipe (Str);

    If ListMode = 1 Then
      Session.io.AnsiClrEOL;

    Session.io.OutRawLn('');
  End;

(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)

  Function Ansi_View_Message : Boolean;
  Var
    Lines     : SmallInt;
    PageSize  : SmallInt;
    PageStart : SmallInt;
    PageEnd   : SmallInt;

    Procedure Draw_Msg_Text;
    Var
      A    : SmallInt;
      Temp : String;
    Begin
      PageEnd := PageStart;

      Session.io.AnsiGotoXY   (1, Session.io.ScreenInfo[1].Y);
      Session.io.AnsiColor (MBase.ColText);

      For A := 1 to PageSize Do
        If PageEnd <= Lines Then Begin
          Send_Msg_Text(MsgText[PageEnd]);
          Inc (PageEnd);
        End Else Begin
          Session.io.AnsiClrEOL;
          Session.io.OutRawLn ('');
        End;

      Temp := Session.io.DrawPercent(Session.Lang.MsgBar, PageEnd - 1, Lines, A);

      If Session.io.ScreenInfo[4].Y <> 0 Then Begin
        Session.io.AnsiGotoXY (Session.io.ScreenInfo[4].X, Session.io.ScreenInfo[4].Y);
        Session.io.AnsiColor  (Session.io.ScreenInfo[4].A);
        Session.io.OutRaw     (strPadL(strI2S(A), 3, ' '));
      End;

      If Session.io.ScreenInfo[5].Y <> 0 Then Begin
        Session.io.AnsiGotoXY (Session.io.ScreenInfo[5].X, Session.io.ScreenInfo[5].Y);
        Session.io.OutFull    (Temp);
      End;
    End;

  Var
    Ch     : Char;
    A      : LongInt;
    CurMsg : LongInt;
  Begin
    Ansi_View_Message := False;

    Repeat
      Set_Node_Action (Session.GetPrompt(348));

      Set_Message_Security;

      If MsgBase^.GetMsgNum > LastRead Then LastRead := MsgBase^.GetMsgNum;

      CurMsg    := MsgBase^.GetMsgNum;
      Lines     := 0;
      PageStart := 1;

      Session.io.AllowArrow := True;

      MsgBase^.MsgTxtStartUp;

      While Not MsgBase^.EOM And (Lines < mysMaxMsgLines) Do Begin
        Inc (Lines);

        MsgText[Lines] := MsgBase^.GetString(79);

        If MsgText[Lines][1] = #1 Then Begin
          If Copy(MsgText[Lines], 1, 6) = #1 + 'MSGID' Then
            ReplyID := Copy(MsgText[Lines], 9, Length(MsgText[Lines]));

          Dec (Lines);
        End;
      End;

      Assign_Header_Info;

      Session.io.ScreenInfo[4].Y := 0;
      Session.io.ScreenInfo[5].Y := 0;

      Session.io.OutFile (MBase.RTemplate, True, 0);

      PageSize := Session.io.ScreenInfo[2].Y - Session.io.ScreenInfo[1].Y + 1;

      Draw_Msg_Text;

      Repeat
        Session.io.PurgeInputBuffer;

        Repeat
          Ch := UpCase(Session.io.GetKey);
        Until (Pos(Ch, #27 + ValidKeys) > 0) or Session.io.IsArrow;

        If Session.io.IsArrow Then Begin
          Case Ch of
            #71 : If PageStart > 1 Then Begin
                    PageStart := 1;
                    Draw_Msg_Text;
                  End;
            #72 : If PageStart > 1 Then Begin
                    Dec (PageStart);
                    Draw_Msg_Text;
                  End;
            #73 : If PageStart > 1 Then Begin
                    If PageStart - PageSize > 0 Then
                      Dec (PageStart, PageSize)
                    Else
                      PageStart := 1;
                    Draw_Msg_Text;
                  End;
            #75 : If SeekNextMsg(False, True) Then
                    Break
                  Else Begin
                    MsgBase^.SeekFirst(CurMsg);
                    SeekNextMsg(True, False);
                  End;
            #77 : If SeekNextMsg(False, False) Then
                    Break
                  Else Begin
                    MsgBase^.SeekFirst(CurMsg);
                    SeekNextMsg(True, False);
                  End;
            #79 : Begin
                    PageStart := Lines - PageSize + 1;

                    If PageStart < 1 Then PageStart := 1;

                    Draw_Msg_Text;
                  End;
            #80 : If PageEnd <= Lines Then Begin
                    Inc (PageStart);
                    Draw_Msg_Text;
                  End;
            #81 : If (Lines > PageSize) and (PageEnd <= Lines) Then Begin
                    If PageStart + PageSize <= Lines - PageSize Then
                      Inc (PageStart, PageSize)
                    Else
                      PageStart := Lines - PageSize + 1;

                    Draw_Msg_Text;
                  End;
          End;
        End Else
          Case Ch of
            'A' : Break;
            'D' : Begin
                    If Session.io.GetYN(Session.GetPrompt(402), True) Then Begin
                      MsgBase^.DeleteMsg;

                      If Not SeekNextMsg(False, False) Then Begin
                        Ansi_View_Message := True;
                        Exit;
                      End;
                    End Else
                      MsgBase^.SeekFirst(CurMsg);
                    Break;
                  End;
            'E' : Begin
                    EditMessage;
                    Break;
                  End;
            'G' : Begin
                    Ansi_View_Message := True;
                    Exit;
                  End;
            'H' : Begin
                    LastRead := CurMsg - 1;
                  End;
            'I' : Begin
                    LastRead          := MsgBase^.GetHighMsgNum;
                    Ansi_View_Message := True;
                    Exit;
                  End;
            'J' : Begin
                    Session.io.PromptInfo[1] := strI2S(CurMsg);
                    Session.io.PromptInfo[2] := strI2S(MsgBase^.GetHighMsgNum);

                    Session.io.OutFull (Session.GetPrompt(403));

                    A := strS2I(Session.io.GetInput(9, 9, 12, ''));

                    If (A > 0) and (A <= MsgBase^.GetHighMsgNum) Then Begin
                      MsgBase^.SeekFirst(A);
                      If Not SeekNextMsg(True, False) Then Begin
                        MsgBase^.SeekFirst(CurMsg);
                        SeekNextMsg(True, False);
                      End;
                    End;
                    Break;
                  End;
            'L' : Exit;
            'M' : Begin
                    If Move_Message Then
                      If Not SeekNextMsg(False, False) Then Begin
                        Ansi_View_Message := True;
                        Exit;
                      End;

                    Break;
                  End;
            #13 : If (Lines > PageSize) and (PageEnd <= Lines) Then Begin
                    If PageStart + PageSize <= Lines - PageSize Then
                      Inc (PageStart, PageSize)
                    Else
                      PageStart := Lines - PageSize + 1;

                    Draw_Msg_Text;
                  End Else Begin
                    If SeekNextMsg(False, False) Then
                      Break
                    Else Begin
                      Ansi_View_Message := True;
                      Exit;
                    End;
                  End;
            'N' : If SeekNextMsg(False, False) Then
                    Break
                  Else Begin
                    Ansi_View_Message := True;
                    Exit;
                  End;
            'P' : If SeekNextMsg(False, True) Then
                    Break
                  Else Begin
                    MsgBase^.SeekFirst(CurMsg);
                    SeekNextMsg(True, False);
                  End;
            #27,
            'Q' : Begin
                    GetMessageScan;

                    If MScan.NewScan = 2 Then
                      Session.io.OutFullLn(Session.GetPrompt(406))
                    Else Begin
                      ReadRes := False;
                      Ansi_View_Message := True;

                      Exit;
                    End;
                  End;
            'R' : Begin
                    ReplyMessage (Mode = 'E', ListMode, ReplyID);

                    Break;
                  End;
            'T' : Begin
                    Session.io.PromptInfo[1] := MBase.Name;

                    GetMessageScan;

                    Case MScan.NewScan of
                      0 : Begin
                            MScan.NewScan := 1;
                            Session.io.OutFull (Session.GetPrompt(405));
                          End;
                      1 : Begin
                            MScan.NewScan := 0;
                            Session.io.OutFull (Session.GetPrompt(404));
                          End;
                      2 : Session.io.OutFull (Session.GetPrompt(406));
                    End;

                    SetMessageScan;

                    Break;
                  End;
            'X' : Begin
                    Export_Message;

                    Break;
                  End;
            '[' : If MsgBase^.GetRefer > 0 Then Begin
                    MsgBase^.SeekFirst(MsgBase^.GetRefer);
                    MsgBase^.MsgStartUp;

                    Break;
                  End;
            ']' : If MsgBase^.GetSeeAlso > 0 Then Begin
                    MsgBase^.SeekFirst(MsgBase^.GetSeeAlso);
                    MsgBase^.MsgStartUp;

                    Break;
                  End;
            '?' : Begin
                    Session.io.OutFile ('amsghlp2', True, 0);
                    Break;
                  End;
          End;
      Until False;
    Until False;
  End;

(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)

  Procedure Ansi_Read_Messages;
  Type
    MsgInfoRec = Record
      Num     : LongInt;
      MsgFrom : String[30];
      MsgTo   : String[30];
      Subj    : String[60];
      NewMsgs : Boolean;
    End;

  Var
    PageSize  : SmallInt;
    PagePos   : SmallInt;
    PageTotal : SmallInt;
    CurPage   : Word;
    MsgInfo   : Array[1..24] of MsgInfoRec;
    FirstPage : Boolean;

    Procedure DrawPage;
    Var
      A : SmallInt;
    Begin
      Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y);

      For A := 1 to PageSize Do
        If A <= PageTotal Then Begin
          With MsgInfo[A] Do Begin
            Session.io.PromptInfo[1] := strI2S(Num);
            Session.io.PromptInfo[2] := Subj;
            Session.io.PromptInfo[3] := MsgFrom;
            Session.io.PromptInfo[4] := MsgTo;

            If NewMsgs Then
              Session.io.PromptInfo[5] := Session.Lang.NewMsgChar
            Else
              Session.io.PromptInfo[5] := ' ';
          End;

          Session.io.OutFull (Session.GetPrompt(399));
          Session.io.AnsiClrEOL;
          Session.io.OutRawLn('');
        End Else Begin
          Session.io.AnsiClrEOL;
          Session.io.OutRawLn('');
        End;
    End;

    Procedure FullReDraw;
    Begin
      Session.io.OutFile (MBase.ITemplate, True, 0);

      PageSize := Session.io.ScreenInfo[2].Y - Session.io.ScreenInfo[1].Y + 1;
    End;

    Function Read_Page (First, Back, NoDraw : Boolean) : Boolean;
    Var
      A    : SmallInt;
      B    : SmallInt;
      Temp : MsgInfoRec;
    Begin
      Read_Page := False;
      FirstPage := False;

      If SeekNextMsg(First, Back) Then Begin

        If First Then Begin
          FullReDraw;
          CurPage := 0;
        End;

        // add scanning prompt here
        //if (scanmode=3) then begin
        //    Session.io.AnsiGotoXY(32, 11);
        //    Session.io.OutFull ('|08.---------------.');
        //    Session.io.AnsiGotoXY(32, 12);
        //    Session.io.OutFull ('| |07searching ... |08|');
        //    Session.io.AnsiGotoXY(32, 13);
        //    Session.io.OutFull ('`---------------''');
        //end;

        PageTotal := 0;
        Read_Page  := True;

        Repeat
          Inc (PageTotal);
          MsgInfo[PageTotal].Num     := MsgBase^.GetMsgNum;
          MsgInfo[PageTotal].MsgFrom := MsgBase^.GetFrom;
          MsgInfo[PageTotal].MsgTo   := MsgBase^.GetTo;
          MsgInfo[PageTotal].Subj    := MsgBase^.GetSubj;
          MsgInfo[PageTotal].NewMsgs := MsgBase^.GetMsgNum > LastRead;
        Until (PageTotal = PageSize) or (Not SeekNextMsg(False, Back));

        If Back Then Begin { reverse message order }
          Dec (CurPage);

          B := PageTotal;

          For A := 1 to PageTotal DIV 2 Do Begin
            Temp       := MsgInfo[A];
            MsgInfo[A] := MsgInfo[B];
            MsgInfo[B] := Temp;
            Dec (B);
          End;

          // if backwards and page is not filled, fill it going foward.

          If PageTotal < PageSize Then Begin
            FirstPage := True;

            MsgBase.SeekFirst(MsgInfo[PageTotal].Num);

            While SeekNextMsg(False, False) and (PageTotal < PageSize) Do Begin
              Inc (PageTotal);
              MsgInfo[PageTotal].Num     := MsgBase^.GetMsgNum;
              MsgInfo[PageTotal].MsgFrom := MsgBase^.GetFrom;
              MsgInfo[PageTotal].MsgTo   := MsgBase^.GetTo;
              MsgInfo[PageTotal].Subj    := MsgBase^.GetSubj;
              MsgInfo[PageTotal].NewMsgs := MsgBase^.GetMsgNum > LastRead;
            End;

            Read_Page := False;
          End;
        End Else Begin
          Inc (CurPage);
          Read_Page := True;
        End;

        If Not NoDraw Then DrawPage;
      End;
    End;

    Procedure UpdateBar (On : Boolean);
    Begin
      If PageTotal = 0 Then Exit;

      Session.io.PromptInfo[1] := strI2S(MsgInfo[PagePos].Num);
      Session.io.PromptInfo[2] := MsgInfo[PagePos].Subj;
      Session.io.PromptInfo[3] := MsgInfo[PagePos].MsgFrom;
      Session.io.PromptInfo[4] := MsgInfo[PagePos].MsgTo;

      If MsgInfo[PagePos].NewMsgs Then
        Session.io.PromptInfo[5] := Session.Lang.NewMsgChar
      Else
        Session.io.PromptInfo[5] := ' ';

      Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y + PagePos - 1);

      If On Then
        Session.io.OutFull (Session.GetPrompt(400))
      Else
        Session.io.OutFull (Session.GetPrompt(401));
    End;

  Procedure Ansi_Message_Index;
  Var
    Ch  : Char;
    SN  : LongInt;
    A   : Byte;
  Begin
    If Read_Page (True, False, False) Then Begin
      WereMsgs := True;
      PagePos  := 1;

      Repeat
        Session.io.AllowArrow := True;

        UpdateBar(True);

        Session.io.PurgeInputBuffer;

        Ch := UpCase(Session.io.GetKey);

        If Session.io.IsArrow Then Begin
          Case Ch of
            #71 : Begin
                    UpdateBar(False);

                    While Read_Page(False, True, True) Do;

                    PagePos := 1;

                    DrawPage;
                  End;
            #72 : Begin
                    UpdateBar(False);

                    If PagePos > 1 Then
                      Dec (PagePos)
                    Else Begin
                      SN := MsgInfo[PagePos].Num;

                      MsgBase^.SeekFirst(MsgInfo[1].Num);

                      If Not Read_Page(False, True, False) Then
                        PagePos := 1
                      Else
                      If Not FirstPage Then
                        PagePos := PageTotal
                      Else Begin
                        For A := 1 to PageTotal Do
                          If MsgInfo[A].Num = SN Then Begin
                            PagePos := A - 1;
                            Break;
                          End;

                        If PagePos < 1 Then PagePos := 1;
                      End;
                    End;
                  End;
            #73,
            #75 : Begin
                    UpdateBar(False);

                    MsgBase^.SeekFirst(MsgInfo[1].Num);

                    If Not Read_Page(False, True, False) Then
                      PagePos := 1
                    Else
                      If PagePos > PageTotal Then PagePos := PageTotal;
                  End;
            #80 : Begin
                    UpdateBar(False);

                    If PagePos < PageTotal Then
                      Inc (PagePos)
                    Else Begin
                      MsgBase^.SeekFirst(MsgInfo[PageTotal].Num);
                      If Read_Page(False, False, False) Then PagePos := 1;
                    End;
                  End;
            #77,
            #81 : Begin
                    MsgBase^.SeekFirst(MsgInfo[PageTotal].Num);

                    If Read_Page(False, False, False) Then Begin
                      If PagePos > PageTotal Then PagePos := PageTotal;
                    End Else Begin
                      UpdateBar(False);
                      PagePos := PageTotal;
                    End;
                  End;
            #79 : Begin
                    UpdateBar(False);
                    While Read_Page(False, False, True) Do;
                    PagePos := PageTotal;
                    DrawPage;
                  End;
          End;
        End Else
          Case Ch of
            #13 : Begin
                    MsgBase^.SeekFirst(MsgInfo[PagePos].Num);

                    SeekNextMsg (True, False);

                    If Ansi_View_Message Then Break;

                    MsgBase^.SeekFirst(MsgInfo[1].Num);

                    If Not Read_Page(True, False, False) Then Begin
                      PageTotal := 0;
                      FullReDraw;
                      DrawPage;
                    End;
                  End;
            'Q',
            #27 : Begin
                    GetMessageScan;

                    If MScan.NewScan = 2 Then
                      Session.io.OutFullLn(Session.GetPrompt(406))
                    Else Begin
                      ReadRes := False;
                      Break;
                    End;
                  End;
            'G' : Break;
            'I' : Begin
                    LastRead := MsgBase^.GetHighMsgNum;
                    Break;
                  End;
            '?' : Begin
                    Session.io.OutFile('amsghlp1', True, 0);
                    FullReDraw;
                    DrawPage;
                  End;
          End;
      Until False;
    End;

    Session.io.AllowArrow := False;

    If WereMsgs Then Begin
      Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y);
      Session.io.OutRawLn('');
    End;
  End;

  Begin
    If ((Mode = 'E') and Session.User.ThisUser.UseLBMIdx) or ((Mode <> 'E') and Session.User.ThisUser.UseLBIndex) Then
      Ansi_Message_Index
    Else Begin
      If SeekNextMsg(True, False) Then
        If Not Ansi_View_Message Then
          Ansi_Message_Index;
    End;
  End;

(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
(**************************************************************************)

  Procedure Ascii_Read_Messages;

    Procedure Display_Header;
    Begin
      Session.io.PausePtr := 1;

      Session.io.OutFile (MBase.Header, True, 0);

      If Session.io.NoFile Then Begin
        Session.io.OutFullLn ('|CL|03From : |14|$R40|&1 |03Msg #    : |14|&5 |03of |14|&6');
        Session.io.OutFullLn ('|03To   : |10|$R40|&2 |03Refer to : |10|&7');
        Session.io.OutFullLn ('|03Subj : |12|$R40|&3 |03See Also : |12|&8');
        Session.io.OutFullLn ('|03Date : |11|&4 |$R31|&0 |03Status   : |13|&9');
        Session.io.OutFullLn ('|03Base : |14|MB|CR');
      End;

      Session.io.AnsiColor (MBase.ColText);
    End;

  Var
    Str : String;
    A   : LongInt;
    B   : LongInt;
  Begin
    If SeekNextMsg(True, False) Then
    Repeat
//      Set_Node_Action (Session.GetPrompt(348));

      If MsgBase^.GetMsgNum > LastRead Then LastRead := MsgBase^.GetMsgNum;

      Set_Message_Security;
      Assign_Header_Info;
      Display_Header;

      MsgBase^.MsgTxtStartUp;

      WereMsgs              := True;
      Session.io.AllowPause := True;

      While Not MsgBase^.EOM Do Begin
        Str := MsgBase^.GetString(79);

        If Str[1] = #1 Then Begin
          If Copy(Str, 1, 6) = #1 + 'MSGID' Then
            ReplyID := Copy(Str, 9, Length(Str));
        End Else
          Send_Msg_Text (Str);

        If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then Begin
          Case Session.io.MorePrompt of
            'N' : Break;
            'C' : Session.io.AllowPause := False;
          End;

          If Config.MShowHeader Then Display_Header;
        End;
      End;

      Session.io.AllowPause := False;

      Repeat
        Session.io.PromptInfo[1]  := strI2S(MsgBase^.GetMsgNum);
        Session.io.PromptInfo[2]  := strI2S(MsgBase^.GetHighMsgNum);

        If Mode = 'E' Then
          Session.io.OutFull (Session.GetPrompt(115))
        Else
        If Session.User.Access(MBase.SysopACS) or Session.User.IsThisUser(MsgBase^.GetFrom) Then
          Session.io.OutFull (Session.GetPrompt(213))
        Else
          Session.io.OutFull (Session.GetPrompt(116));

        Str := Session.io.OneKey(ValidKeys, True);
        Case Str[1] of
          'A' : Break;
          'D' : If Session.io.GetYN (Session.GetPrompt(117), True) Then Begin {Delete E-mail}
                  MsgBase^.DeleteMsg;
                  If Not SeekNextMsg(False, False) Then Exit;
                  Break;
                End;
          'E' : Begin
                  EditMessage;
                  Break;
                End;
          'G' : Exit;
          'H' : LastRead := MsgBase^.GetMsgNum - 1;
          'I' : Begin
                  LastRead := MsgBase^.GetHighMsgNum;
                  Exit;
                 End;
          'J' : Begin
                  B := MsgBase^.GetMsgNum;

                  Session.io.OutFull (Session.GetPrompt(334));

                  A := strS2I(Session.io.GetInput(9, 9, 12, ''));

                  If (A > 0) and (A <= MsgBase^.GetHighMsgNum) Then Begin
                    MsgBase^.SeekFirst(A);

                    If Not SeekNextMsg(True, False) Then Begin
                      MsgBase^.SeekFirst(B);
                      SeekNextMsg(True, False);
                    End;
                  End;

                  Break;
                End;
          'L' : Begin
                  Session.io.PausePtr   := 1;
                  Session.io.AllowPause := True;
                  A          := MsgBase^.GetMsgNum;

                  Session.io.OutFullLn(Session.GetPrompt(411));

                  While SeekNextMsg(False, False) Do Begin
                    Assign_Header_Info;

                    Session.io.OutFullLn (Session.GetPrompt(412));

                    If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
                      Case Session.io.MorePrompt of
                        'N' : Break;
                        'C' : Session.io.AllowPause := False;
                      End;
                  End;

                  Session.io.OutFull (Session.GetPrompt(413));

                  MsgBase^.SeekFirst(A);
                  MsgBase^.MsgStartup;
                End;
          'M' : Begin
                  If Move_Message Then
                    If Not SeekNextMsg(False, False) Then Exit;

                  Break;
                End;
          #13,
          'N' : If SeekNextMsg(False, False) Then Break Else Exit;
          'P' : Begin
                  If Not SeekNextMsg(False, True) Then Begin
                    MsgBase^.SeekFirst(MsgBase^.GetMsgNum);
                    SeekNextMsg(True, False);
                  End;

                  Break;
                End;
          'Q' : Begin
                  GetMessageScan;

                  If MScan.NewScan = 2 Then
                    Session.io.OutFullLn(Session.GetPrompt(302))
                  Else Begin
                    ReadRes := False;
                    Exit;
                  End;
                End;
          'R' : Begin
                  ReplyMessage (Mode = 'E', ListMode, ReplyID);
                  Break;
                End;
          'T' : Begin
                  Session.io.PromptInfo[1] := MBase.Name;

                  GetMessageScan;

                  Case MScan.NewScan of
                    0 : Begin
                          MScan.NewScan := 1;
                          Session.io.OutFull (Session.GetPrompt(99));
                        End;
                    1 : Begin
                          MScan.NewScan := 0;
                          Session.io.OutFull (Session.GetPrompt(98));
                        End;
                    2 : Session.io.OutFull (Session.GetPrompt(302));
                  End;

                  SetMessageScan;
                End;
          'X' : Export_Message;
          '?' : Session.io.OutFile(HelpFile, True, 0);
          '[' : If MsgBase^.GetRefer > 0 Then Begin
                  MsgBase^.SeekFirst(MsgBase^.GetRefer);
                  MsgBase^.MsgStartUp;

                  Break;
                End Else
                  Session.io.OutFullLn (Session.GetPrompt(128));
          ']' : If MsgBase^.GetSeeAlso > 0 Then Begin
                  MsgBase^.SeekFirst(MsgBase^.GetSeeAlso);
                  MsgBase^.MsgStartUp;

                  Break;
                End Else
                  Session.io.OutFullLn (Session.GetPrompt(199));
        End;
      Until False;
    Until False;
  End;

(**************************************************************************)
(**************************************************************************)
(**************************************************************************)
{ F = Forward               S = Search         E = Electronic Mail
  N = New messages          Y = Your messages  G = Global scan
  P = Global personal scan  B = By You         T = Global text search }

Var
  MsgNum : LongInt;
Begin
  ReadMessages := True;
  ReadRes      := True;
  WereMsgs     := False;
  ReplyID      := '';

  If MBase.FileName = '' Then Begin
    Session.io.OutFullLn (Session.GetPrompt(110));

    Exit;
  End;

  If Not Session.User.Access(MBase.ReadACS) Then Begin
    If Not (Mode in ['G', 'P', 'T']) Then Session.io.OutFullLn (Session.GetPrompt(111));
    Exit;
  End;

  If Not (Mode in ['B', 'T', 'S', 'E', 'F', 'G', 'N', 'P', 'Y']) Then Begin
    Session.io.OutFull (Session.GetPrompt(112));

    Mode := Session.io.OneKey('BFNSYQ', True);
  End;

  Case Mode of
    'Q' : Exit;
    'S' : If SearchStr = '' Then Begin
            Session.io.OutFull (Session.GetPrompt(396));

            SearchStr := Session.io.GetInput(50, 50, 12, '');

            If SearchStr = '' Then Exit;
          End;
  End;

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgbaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    If Mode = 'E' Then
      Session.io.OutFullLn (Session.GetPrompt(124))
    Else
      If Not (Mode in ['G', 'P', 'T']) Then Session.io.OutFullLn (Session.GetPrompt(114));

    Dispose (MsgBase, Done);

    Exit;
  End;

  If Mode = 'E' Then
    ScanMode := 1
  Else
  If (MBase.Flags and MBPrivate <> 0) or (Mode = 'Y') or (Mode = 'P') Then
    ScanMode := 2
  Else
  If (Mode = 'S') or (Mode = 'T') Then
    ScanMode := 3
  Else
  If Mode = 'B' Then
    ScanMode := 4
  Else
    ScanMode := 0;

  LastRead := MsgBase^.GetLastRead(Session.User.UserNum);
  MsgNum   := 1;

  If Mode = 'F' Then Begin
    Session.io.PromptInfo[1] := strI2S(MsgBase^.GetHighMsgNum);

    Session.io.OutFull (Session.GetPrompt(338));

    MsgNum := strS2I(Session.io.GetInput(6, 6, 12, ''));
  End;

  Set_Node_Action (Session.GetPrompt(348));

  If Mode in ['B', 'S', 'T', 'Y', 'E', 'F'] Then
    MsgBase^.SeekFirst(MsgNum)
  Else
    MsgBase^.SeekFirst(LastRead + 1);

  Set_Message_Security;

  Reading := True;

  If (Session.User.ThisUser.MReadType = 1) and (Session.io.Graphics > 0) Then Begin
    ListMode := 1;
    Ansi_Read_Messages;
  End Else Begin
    ListMode := 0;
    Ascii_Read_Messages;
  End;

  If Not (Mode in ['E', 'S', 'T']) Then MsgBase^.SetLastRead (Session.User.UserNum, LastRead);

  MsgBase^.CloseMsgBase;
  Dispose (MsgBase, Done);

  Reading := False;

  If WereMsgs Then Begin
    If Not (Mode in ['B', 'E', 'P']) And ReadRes Then
      If ListMode = 0 Then Begin

        Session.io.OutFull('|CR');

        If Session.io.GetYN(Session.GetPrompt(383), False) Then
          PostMessage (False, '');
      End Else
        If Session.io.GetYN(Session.GetPrompt(438), False) Then
          PostMessage (False, '');
  End Else
    Case Mode of
      'S' : Session.io.OutFullLn (Session.GetPrompt(113));
      'B',
      'Y',
      'N' : Session.io.OutFullLn ('|CR' + Session.GetPrompt(113));
    End;

  Result := ReadRes;
End;

Procedure TMsgBase.PostMessage (Email: Boolean; Data: String);
Var
  MsgTo    : String[30];
  MsgSubj  : String[60];
  MsgAddr  : String[20];
  TempStr  : String;
  DestAddr : RecEchoMailAddr;
  A        : Integer;
  Lines    : Integer;
  Forced   : Boolean;
  Old      : RecMessageBase;
Begin
  Old := MBase;

  If Email Then Begin
    Reset (MBaseFile);
    Read  (MBaseFile, MBase);
    Close (MBaseFile);
  End;

  If MBase.FileName = '' Then Begin
    Session.io.OutFullLn (Session.GetPrompt(110));
    MBase := Old;
    Exit;
  End;

  If Not Session.User.Access(MBase.PostACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(105));
    MBase := Old;
    Exit;
  End;

  Set_Node_Action (Session.GetPrompt(349));

  MsgTo    := '';
  MsgSubj  := '';
  MsgAddr  := '';
  Forced   := False;

  For A := 1 to strWordCount(Data, ' ') Do Begin
    TempStr := strWordGet(A, Data, ' ');

    If Pos ('/F', strUpper(TempStr)) > 0 Then
      Forced := True
    Else
    If Pos ('/TO:', strUpper(TempStr)) > 0 Then
      MsgTo := strReplace(Copy(TempStr, Pos('/TO:', strUpper(TempStr)) + 4, Length(TempStr)), '_', ' ')
    Else
    If Pos ('/SUBJ:', strUpper(TempStr)) > 0 Then
      MsgSubj := strReplace(Copy(TempStr, Pos('/SUBJ:', strUpper(TempStr)) + 6, Length(TempStr)), '_', ' ')
    Else
    If Pos('/ADDR:', strUpper(TempStr)) > 0 Then
      MsgAddr := strReplace(Copy(TempStr, Pos('/ADDR:', strUpper(TempStr)) + 6, Length(TempStr)), '_', ' ');
  End;

  If MBase.NetType = 2 Then           { UseNet Base: To = "All" }
    MsgTo := 'All'
  Else
  If MBase.NetType = 3 Then Begin     { NetMail Base: Get To *and* Address }
    If MsgTo = '' Then Begin
      Session.io.OutFull (Session.GetPrompt(119));

      MsgTo := Session.io.GetInput (30, 30, 18, '');
    End;

    If MsgAddr = '' Then Begin
      Session.io.OutFull (Session.GetPrompt(342));

      MsgAddr := Session.io.GetInput (20, 20, 12, '');

      If Not strStr2Addr(MsgAddr, DestAddr) Then MsgTo := '';
    End;
  End Else
  If MBase.Flags and MBPrivate <> 0 Then Begin
    If MsgTo = '' Then Begin
      Session.io.OutFull (Session.GetPrompt(450));

      MsgTo := Session.io.GetInput (30, 30, 18, '');

      If Not Session.User.SearchUser(MsgTo, MBase.Flags and MBRealNames <> 0) Then MsgTo := '';
    End Else
      If strUpper(MsgTo) = 'SYSOP' Then MsgTo := Config.SysopName;

    If Session.User.FindUser(MsgTo, False) Then Begin
      Session.io.PromptInfo[1] := MsgTo;

      Session.io.OutFullLn (Session.GetPrompt(108));
    End Else
      MsgTo := '';
  End Else Begin
    Session.io.OutFull (Session.GetPrompt(119));

    MsgTo := Session.io.GetInput (30, 30, 18, 'All');
  End;

  If MsgTo = '' Then Begin
    MBase := Old;
    Exit;
  End;

  If MsgSubj = '' Then
    Repeat
      Session.io.OutFull (Session.GetPrompt(120));

      MsgSubj := Session.io.GetInput (60, 60, 11, '');

      If MsgSubj = '' Then
        If Forced Then
          Session.io.OutFull (Session.GetPrompt(307))
        Else Begin
          MBase := Old;
          Exit;
        End;
    Until MsgSubj <> '';

  Lines := 0;

  Session.io.PromptInfo[1] := MsgTo;
  Session.io.PromptInfo[2] := MsgSubj;

  If Editor(Lines, 78, mysMaxMsgLines, False, Forced, MsgSubj) Then Begin
    Session.io.OutFull (Session.GetPrompt(107));

    { all of this below should be replaced with a SaveMessage function   }
    { the same should be used for Replying and also for TextFile post    }
    { and then the automated e-mails can be added where mystic will send }
    { notifications out to the sysop for various things (configurable)   }
    { also could be used in mass email rewrite and qwk .REP rewrite      }

    If Not OpenCreateBase(MsgBase, MBase) Then Begin
      MBase := Old;
      Exit;
    End;

    AssignMessageData(MsgBase);

    MsgBase^.SetTo   (MsgTo);
    MsgBase^.SetSubj (MsgSubj);

    If MBase.NetType = 3 Then Begin
      MsgBase^.SetDest     (DestAddr);
      MsgBase^.SetCrash    (Config.netCrash);
      MsgBase^.SetHold     (Config.netHold);
      MsgBase^.SetKillSent (Config.netKillSent);

      DestAddr := Config.NetAddress[MBase.NetAddr];

      MsgBase^.SetOrig (DestAddr);
    End;

    AppendMessageText (MsgBase, Lines, '');

    MsgBase^.WriteMsg;

    MsgBase^.CloseMsgBase;

    If Email Then Begin
      Session.SystemLog ('Sent Email to ' + MsgTo);

      Inc (Session.User.ThisUser.Emails);
      Inc (Session.HistoryEmails);

      A := IsUserOnline(MsgTo);

      If A <> 0 Then Begin
        TempStr := Session.GetPrompt(465);
        TempStr := strReplace(TempStr, '|&1', Session.User.ThisUser.Handle);
        TempStr := strReplace(TempStr, '|&2', MsgSubj);

        Send_Node_Message(2, strI2S(A) + ';' + TempStr, 0);
      End;
    End Else Begin
      Session.SystemLog ('Posted #' + strI2S(MsgBase^.GetMsgNum) + ': "' + MsgSubj + '" to ' + strStripMCI(MBase.Name));

      Inc (Session.User.ThisUser.Posts);
      Inc (Session.HistoryPosts);
    End;

    Dispose (MsgBase, Done);
    Session.io.OutFullLn (Session.GetPrompt(122));
  End Else
    Session.io.OutFullLn (Session.GetPrompt(109));

  MBase := Old;
End;

Procedure TMsgBase.CheckEMail;
Var
  Old     : RecMessageBase;
  Total   : Integer;
Begin
  Session.io.OutFull (Session.GetPrompt(123));

  Session.io.BufFlush;

  Old := MBase;

  Reset (MBaseFile);
  Read  (MBaseFile, MBase);
  Close (MBaseFile);

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    Session.io.OutFullLn (Session.GetPrompt(124));
    Dispose (MsgBase, Done);
    MBase := Old;
    Exit;
  End;

  Total := 0;

  MsgBase^.YoursFirst(Session.User.ThisUser.RealName, Session.User.ThisUser.Handle);

  If MsgBase^.YoursFound Then Begin
    Session.io.OutFullLn (Session.GetPrompt(125));

    Total := 0;

    While MsgBase^.YoursFound Do Begin
      MsgBase^.MsgStartUp;

      Inc (Total);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := MsgBase^.GetFrom;
      Session.io.PromptInfo[3] := MsgBase^.GetSubj;
      Session.io.PromptInfo[4] := MsgBase^.GetDate;

      Session.io.OutFullLn (Session.GetPrompt(126));

      MsgBase^.YoursNext;
    End;

    If Session.io.GetYN (Session.GetPrompt(127), True) Then Begin
      MsgBase^.CloseMsgBase;
      Dispose (MsgBase, Done);

      ReadMessages('E', '');

      Session.io.OutFullLn (Session.GetPrompt(118));

      MBase := Old;
      Exit;
    End;
  End Else
    Session.io.OutFullLn (Session.GetPrompt(124));

  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);

  MBase := Old;
End;

Procedure TMsgBase.SetMessagePointers;
Var
  NewDate : LongInt;

  Procedure UpdateBase;
  Var
    Found : Boolean;
  Begin
    Found := False;

    Case MBase.BaseType of
      0 : MsgBase := New(PMsgBaseJAM, Init);
      1 : MsgBase := New(PMsgBaseSquish, Init);
    End;

    MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

    If MsgBase^.OpenMsgBase Then Begin
      MsgBase^.SeekFirst(1);

      While MsgBase^.SeekFound Do Begin
        MsgBase^.MsgStartUp;
        If DateStr2Dos(MsgBase^.GetDate) >= NewDate Then Begin
          MsgBase^.SetLastRead(Session.User.UserNum, MsgBase^.GetMsgNum - 1);
          Found := True;
          Break;
        End;
        MsgBase^.SeekNext;
      End;

      If Not Found Then
        MsgBase^.SetLastRead(Session.User.UserNum, MsgBase^.GetHighMsgNum);
    End;

    Dispose (MsgBase, Done);
  End;

Var
  Global : Boolean;
  InDate : String[8];
Begin
  Session.io.OutFull (Session.GetPrompt(458));

  InDate := Session.io.GetInput(8, 8, 15, '');

  If Not DateValid(InDate) Then Exit;

  NewDate := DateStr2Dos(InDate);
  Global  := Session.io.GetYN(Session.GetPrompt(459), False);

  Session.io.OutFullLn (Session.GetPrompt(460));

  If Global Then Begin
    ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN);
    ioRead  (MBaseFile, MBase);

    While Not Eof(MBaseFile) Do Begin
      ioRead (MBaseFile, MBase);
      UpdateBase;
    End;
  End Else
    UpdateBase;
End;

Procedure TMsgBase.MessageNewScan (Data : String);
{ menu data commands: }
{    /P : scan for personal mail in all bases }
{    /M : scan only mandatory bases           }
{    /G : scan all bases in all groups        }
Var
  Old  : RecMessageBase;
  Mode : Char;
  Mand : Boolean;
Begin
  Old  := MBase;
  Mand := False;

  Reset (MBaseFile);

  If Pos ('/P', Data) > 0 Then Begin
    Mode := 'P';

    Session.SystemLog ('Scan for personal messages');
  End Else Begin
    Mand := Pos('/M', Data) > 0;
    Mode := 'G';

    Read (MBaseFile, MBase);

    Session.SystemLog ('Scan for new messages');
  End;

  Session.User.IgnoreGroup := Pos('/G', Data) > 0;
  WereMsgs         := False;

  Session.io.OutRawLn ('');

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      GetMessageScan;

      If ((Mand) and (MBase.DefNScan = 2)) or ((Not Mand) and (MScan.NewScan > 0)) Then Begin
        Session.io.OutBS (Screen.CursorX, True);
        Session.io.OutFull (Session.GetPrompt(130));

        If Not ReadMessages(Mode, '') Then Begin
          Session.io.OutRawLn('');
          Break;
        End;

        If WereMsgs Then Session.io.OutRawLn('');
      End;
    End;
  End;

  If Not WereMsgs Then Session.io.OutFullLn('|CR');

  Session.io.OutFull (Session.GetPrompt(131));

  Close (MBaseFile);

  Session.User.IgnoreGroup := False;
  MBase            := OLD;
End;

Procedure TMsgBase.GlobalMessageSearch (Mode : Char);
{ C = current area }
{ G = all areas in group }
{ A = all areas in all groups }
Var
  SearchStr : String;
  Old       : RecMessageBase;
Begin
  If Not (Mode in ['A', 'C', 'G']) Then Mode := 'G';

  Session.io.OutFull (Session.GetPrompt(310));

  SearchStr := Session.io.GetInput(50, 50, 12, '');

  If SearchStr = '' Then Exit;

  OLD         := MBase;
  WereMsgs    := False;
  Session.User.IgnoreGroup := Mode = 'A';

  If Mode = 'C' Then
    ReadMessages('S', SearchStr)
  Else Begin
    Session.io.OutRawLn ('');

    Reset (MBaseFile);
    Read  (MBaseFile, MBase); {skip email base}

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ReadACS) Then Begin
        GetMessageScan;

        If MScan.NewScan > 0 Then Begin
          If Not ReadMessages('T', SearchStr) Then Begin
            Session.io.OutRawLn('');
            Break;
          End;

          If WereMsgs Then Session.io.OutRawLn('');
        End;
      End;
    End;

    Session.io.OutFull  (Session.GetPrompt(311));
    Close (MBaseFile);
  End;

  Session.User.IgnoreGroup := False;
  MBase       := OLD;
End;

Procedure TMsgBase.SendMassEmail;
Var
  Mode    : Char;
  Names   : Array[1..25] of String[35];
  NamePos : SmallInt;
  ACS     : String[20];
  Str     : String[30];
  A       : SmallInt;
  MsgFrom : String[30];
  MsgTo   : String[30];
  MsgSubj : String[60];
  Lines   : Integer;
  Old     : RecMessageBase;
  OldUser : RecUser;

  Procedure Write_Mass_Msg;
  Begin
    Session.SystemLog ('Sending mass mail to ' + MsgTo);

    AssignMessageData(MsgBase);

    MsgBase^.SetFrom (MsgFrom);
    MsgBase^.SetTo   (MsgTo);
    MsgBase^.SetSubj (MsgSubj);

    AppendMessageText (MsgBase, Lines, '');

    MsgBase^.WriteMsg;
  End;

Begin
  MsgFrom := Session.User.ThisUser.Handle;

  Session.io.OutFull (Session.GetPrompt(387));

  Mode := Session.io.OneKey('123Q', True);

  Case Mode of
    '1' : Begin
            Session.io.OutFull (Session.GetPrompt(388));
            ACS := Session.io.GetInput(20, 20, 11, '');

            If ACS = '' Then Exit;

            Session.io.OutFullLn (Session.GetPrompt(391));

            OldUser := Session.User.ThisUser;

            Reset (Session.User.UserFile);

            While Not Eof(Session.User.UserFile) Do Begin
              If (Session.User.ThisUser.Flags AND UserDeleted = 0) and Session.User.Access(ACS) Then Begin
                Read (Session.User.UserFile, Session.User.ThisUser);

                Session.io.PromptInfo[1] := Session.User.ThisUser.Handle;

                Session.io.OutFullLn (Session.GetPrompt(392));
              End;
            End;

            Close (Session.User.UserFile);

            Session.User.ThisUser := OldUser;

            If Not Session.io.GetYN(Session.GetPrompt(393), True) Then
              Exit;
          End;
    '2' : Begin
            NamePos := 0;

            Session.io.OutFull (Session.GetPrompt(389));

            While NamePos < 25 Do Begin
              Session.io.PromptInfo[1] := strI2S(NamePos);
              Session.io.OutFull (Session.GetPrompt(390));

              Str := Session.io.GetInput (30, 30, 18, '');

              If Str <> '' Then Begin
                If Session.User.SearchUser(Str, MBase.Flags And MBRealNames <> 0) Then Begin
                  Inc (NamePos);
                  Names[NamePos] := Str;
                End;
              End Else
              If NamePos = 0 Then
                Exit
              Else
                Break;
            End;

            Session.io.OutFullLn (Session.GetPrompt(391));

            For A := 1 to NamePos Do Begin
              Session.io.PromptInfo[1] := Names[A];
              Session.io.OutFullLn (Session.GetPrompt(392));
            End;

            If Not Session.io.GetYN(Session.GetPrompt(393), True) Then
              Exit;
          End;
    '3' : Begin
            Mode := '1';
            ACS  := '^';
          End;
    'Q' : Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(416));

  MsgSubj := Session.io.GetInput (60, 60, 11, '');

  If MsgSubj = '' Then Exit;

  Session.io.PromptInfo[1] := 'Mass Mail';
  Session.io.PromptInfo[2] := MsgSubj;

  Lines := 0;

  If Editor(Lines, 78, mysMaxMsgLines, False, False, MsgSubj) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(394));

    OLD := MBase;

    Reset (MBaseFile);
    Read  (MBaseFile, MBase);
    Close (MBaseFile);

    Case MBase.BaseType of
      0 : MsgBase := New(PMsgBaseJAM, Init);
      1 : MsgBase := New(PMsgBaseSquish, Init);
    End;

    MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

    If Not MsgBase^.OpenMsgBase Then
      If Not MsgBase^.CreateMsgBase (MBase.MaxMsgs, MBase.MaxAge) Then Begin
        Dispose (MsgBase, Done);
        MBase := Old;
        Exit;
      End Else
      If Not MsgBase^.OpenMsgBase Then Begin
        Dispose (MsgBase, Done);
        MBase := Old;
        Exit;
      End;

    Case Mode of
      '1' : Begin
              OldUser := Session.User.ThisUser;

              Reset (Session.User.UserFile);

              While Not Eof(Session.User.UserFile) Do Begin
                Read (Session.User.UserFile, Session.User.ThisUser);

                If (Session.User.ThisUser.Flags AND UserDeleted = 0) and Session.User.Access(ACS) Then Begin
                  MsgTo := Session.User.ThisUser.Handle;
                  Session.User.ThisUser := OldUser;
                  Write_Mass_Msg;
                  {// appends wrong autosig so we add thisuser := olduser?}
                  // shitty kludge all of these var swaps should be
                  // rewritten.. probably do away with global MBAse records
                End;
              End;

              Close (Session.User.UserFile);

              Session.User.ThisUser := OldUser;
            End;
      '2' : For A := 1 to NamePos Do Begin
              MsgTo := Names[A];
              Write_Mass_Msg;
            End;
    End;

    MsgBase^.CloseMsgBase;

    Dispose (MsgBase, Done);
  End;
End;

Procedure TMsgBase.ViewSentEmail;
Var
  Old : RecMessageBase;
Begin
  Old := MBase;

  Reset (MBaseFile);
  Read  (MBaseFile, MBase);
  Close (MBaseFile);

  ReadMessages('B', '');

  MBase := Old;
End;

{ QWK OPTIONS }

// this unbuffered foulness should be rewritten... if only people actually
// used QWK... low priority.  also it doesnt copy the welcome, etc files.

Procedure TMsgBase.WriteCONTROLDAT;
Const
  CRLF = #13#10; { for eventually having option for linux OR dos text files }
Var
  tFile : Text;
Begin
  Assign  (tFile, Session.TempPath + 'control.dat');
  ReWrite (tFile);

  Write (tFile, Config.BBSName + CRLF);
  Write (tFile, CRLF); {bbs City/State}
  Write (tFile, CRLF); {bbs Phone number}
  Write (tFile, Config.SysopName + CRLF);
  Write (tFile, '0,' + Config.qwkBBSID + CRLF);
  Write (tFile, DateDos2Str(CurDateDos, 1), ',', TimeDos2Str(CurDateDos, False) + CRLF);
  Write (tFile, strUpper(Session.User.ThisUser.Handle) + CRLF);
  Write (tFile, CRLF);
  Write (tFile, '0' + CRLF); {What is this line?}
  Write (tFile, TotalMsgs, CRLF); {TOTAL MSG IN PACKET}
  Write (tFile, TotalConf - 1, CRLF); {TOTAL CONF - 1}

  Reset (MBaseFile);
  Read  (MBaseFile, MBase); {SKIP EMAIL BASE}

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      GetMessageScan;

      If MScan.QwkScan > 0 Then Begin
        Write (tFile, MBase.Index, CRLF); {conf #}
        Write (tFile, MBase.QwkName, CRLF); {conf name}
      End;
    End;
  End;

  Write (tFile, JustFile(Config.qwkWelcome) + CRLF);
  Write (tFile, JustFile(Config.qwkNews) + CRLF);
  Write (tFile, JustFile(Config.qwkGoodbye) + CRLF);

  Close (tFile);
End;

{ converts TP real to Microsoft 4 bytes single }
{ what kind of stupid standard uses this var type!? }

Procedure Long2msb (Index : LongInt; Var MS : BSingle);
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

Function TMsgBase.WriteMSGDAT : LongInt;
{ returns last message added to qwk packet }
Var
  DataFile : File;
  NdxFile  : File of QwkNdxHdr;
  NdxHdr   : QwkNdxHdr;
  QwkHdr   : QwkDATHdr;
  Temp     : String;
  MsgAdded : Integer; {# of message added in packet}
  LastRead : LongInt;
  BufStr   : String[128];
  Blocks   : Word;
  Index    : LongInt;
  Count    : SmallInt;
Begin
  Inc (TotalConf);

  MsgAdded := 0;

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    Dispose (MsgBase, Done);
    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(231));

  Assign (DataFile, Session.TempPath + 'messages.dat');
  Reset  (DataFile, 1);
  Seek   (DataFile, FileSize(DataFile));

  LastRead := MsgBase^.GetLastRead(Session.User.UserNum) + 1;

  MsgBase^.SeekFirst(LastRead);
  While MsgBase^.SeekFound Do Begin
    If ((Config.qwkMaxBase > 0) and (MsgAdded = Config.qwkMaxBase)) or
    ((Config.qwkMaxPacket > 0) and (TotalMsgs = Config.qwkMaxPacket)) Then Break;

    FillChar (QwkHdr, 128, ' ');

    MsgBase^.MsgStartUp;

    If MsgBase^.IsPriv Then
      If Not ((MsgBase^.GetTo = Session.User.ThisUser.RealName) or (MsgBase^.GetTo = Session.User.ThisUser.Handle)) Then Begin
        MsgBase^.SeekNext;
        Continue;
      End;

    Inc (MsgAdded);
    Inc (TotalMsgs);

    LastRead := MsgBase^.GetMsgNum;

    Temp := strPadR(strUpper(MsgBase^.GetFrom), 25, ' ');
    Move (Temp[1], QwkHdr.UPFrom, 25);
    Temp := strPadR(strUpper(MsgBase^.GetTo), 25, ' ');
    Move (Temp[1], QwkHdr.UPTo, 25);
    Temp := strPadR(MsgBase^.GetSubj, 25, ' ');
    Move (Temp[1], QwkHdr.Subject, 25);
    Temp := MsgBase^.GetDate;
    Move (Temp[1], QwkHdr.Date, 8);
    Temp := MsgBase^.GetTime;
    Move (Temp[1], QwkHdr.Time, 5);
    Temp := strPadR(strI2S(MsgBase^.GetMsgNum), 7, ' ');
    Move (Temp[1], QwkHdr.MSGNum, 7);
    Temp := strPadR(strI2S(MsgBase^.GetRefer), 8, ' ');
    Move (Temp[1], QwkHdr.ReferNum, 8);

    QwkHdr.Active  := #225;
    QwkHdr.ConfNum := MBase.Index;
    QwkHdr.Status  := ' ';

    MsgBase^.MsgTxtStartUp;

    Blocks := MsgBase^.GetTextLen DIV 128;
    If MsgBase^.GetTextLen MOD 128 > 0 Then Inc(Blocks, 2) Else Inc(Blocks);
    Temp := strPadR(strI2S(Blocks), 6, ' ');
    Move (Temp[1], QwkHdr.NumChunk, 6);

    If MsgAdded = 1 Then Begin
      Assign  (NdxFile, Session.TempPath + strPadL(strI2S(MBase.Index), 3, '0') + '.ndx');
      ReWrite (NdxFile);
    End;

    Index := FileSize(DataFile) DIV 128 + 1;

    long2msb (Index, NdxHdr.MsgPos);

    Write (NdxFile, NdxHdr);

    BlockWrite (DataFile, QwkHdr, 128);

    BufStr  := '';

    While Not MsgBase^.EOM Do Begin
      Temp := MsgBase^.GetString(79) + #227;

      If Temp[1] = #1 Then Continue;

      For Count := 1 to Length(Temp) Do Begin
        BufStr := BufStr + Temp[Count];

        If BufStr[0] = #128 Then Begin
          BlockWrite (DataFile, BufStr[1], 128);
          BufStr := '';
        End;
      End;
    End;

    If BufStr <> '' Then Begin
      BufStr := strPadR(BufStr, 128, ' ');
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

  Session.io.OutBS (Screen.CursorX, True);
  Session.io.OutFullLn (Session.GetPrompt(232));

  Result := LastRead;
End;

Procedure TMsgBase.UploadREP;
Var
  DataFile : File;
  OldMBase : RecMessageBase;
  QwkHdr   : QwkDATHdr;
  Temp     : String[128];
  A        : SmallInt;
  B        : SmallInt;
  Chunks   : SmallInt;
Begin
  If Session.LocalMode Then
    Session.FileBase.ExecuteArchive (Config.QWKPath + Config.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  Else Begin
    If Session.FileBase.SelectProtocol(False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(False, Session.TempPath + Config.qwkBBSID + '.rep');

    If Not Session.FileBase.dszSearch(Config.qwkBBSID + '.rep') Then Begin
      Session.io.PromptInfo[1] := Config.qwkBBSID + '.rep';
      Session.io.OutFullLn (Session.GetPrompt(84));
      Exit;
    End;

    Session.FileBase.ExecuteArchive (Session.TempPath + Config.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  End;

  Assign (DataFile, Session.TempPath + Config.qwkBBSID + '.msg');
  {$I-} Reset (DataFile, 1); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFull (Session.GetPrompt(238));
    DirClean(Session.TempPath, '');
    Exit;
  End;

  BlockRead (DataFile, Temp[1], 128);
  Temp[0] := #128;

  If Pos(strUpper(Config.qwkBBSID), strUpper(Temp)) = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(239));
    Close (DataFile);
    DirClean(Session.TempPath, '');
    Exit;
  End;

  Session.io.OutFullLn (Session.GetPrompt(240));

  OldMBase := MBase;

  While Not Eof(DataFile) Do Begin
    BlockRead (DataFile, QwkHdr, SizeOf(QwkHdr));
    Move (QwkHdr.MsgNum, Temp[1], 7);
    Temp[0] := #7;

    Reset (MBaseFile);
    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);
      If (strS2I(Temp) = MBase.Index) and (Session.User.Access(MBase.PostACS)) Then Begin

        Case MBase.BaseType of
          0 : MsgBase := New(PMsgBaseJAM, Init);
          1 : MsgBase := New(PMsgBaseSquish, Init);
        End;

        MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

        If MsgBase^.OpenMsgBase Then Begin

          AssignMessageData(MsgBase);

          Temp[0] := #25;
          Move (QwkHdr.UpTo, Temp[1], 25);
          MsgBase^.SetTo(strStripR(Temp, ' '));
          Move (QwkHdr.Subject, Temp[1], 25);
          MsgBase^.SetSubj(strStripR(Temp, ' '));
          Move (QwkHdr.ReferNum, Temp[1], 6);
          Temp[0] := #6;
          MsgBase^.SetRefer(strS2I(strStripR(Temp, ' ')));

          Move(QwkHdr.NumChunk, Temp[1], 6);
          Chunks := strS2I(Temp) - 1;

          For A := 1 to Chunks Do Begin
            BlockRead(DataFile, Temp[1], 128);
            Temp[0] := #128;
            Temp := strStripR(Temp, ' ');
            For B := 1 to Length(Temp) Do Begin
              If Temp[B] = #227 Then Temp[B] := #13;
              MsgBase^.DoChar(Temp[B]);
            End;
          End;

          If MBase.NetType > 0 Then Begin
            MsgBase^.DoStringLn(#13 + '--- ' + mysSoftwareID + ' BBS v' + mysVersion + ' (' + OSID + ')');
            MsgBase^.DoStringLn(' * Origin: ' + ResolveOrigin(MBase) + ' (' + strAddr2Str(Config.NetAddress[MBase.NetAddr]) + ')');
          End;

          MsgBase^.WriteMsg;

          MsgBase^.CloseMsgBase;

          Inc (Session.User.ThisUser.Posts);
        End;
        Dispose (MsgBase, Done);
        Break;
      End;
    End;
    Close (MBaseFile);
  End;

  Close    (DataFile);
  DirClean (Session.TempPath, '');

  MBase := OldMBase;
End;

Procedure TMsgBase.DownloadQWK (Data: String);
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

  Old  := MBase;
  Temp := strPadR('Produced By ' + mysSoftwareID + ' BBS v' + mysVersion + '. ' + CopyID, 128, ' ');

  Assign     (DataFile, Session.TempPath + 'messages.dat');
  ReWrite    (DataFile, 1);
  BlockWrite (DataFile, Temp[1], 128);
  Close      (DataFile);

  Assign  (QwkLRFile, Session.TempPath + 'qlr.dat');
  ReWrite (QwkLRFile);

  Reset  (MBaseFile);
  Read   (MBaseFile, MBase); {Skip Email base}

  Session.io.OutFullLn (Session.GetPrompt(230));

  TotalMsgs   := 0;
  TotalConf   := 0;
  Session.User.IgnoreGroup := Pos('/ALLGROUP', strUpper(Data)) > 0;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);
    If Session.User.Access(MBase.ReadACS) Then Begin
      GetMessageScan;
      If MScan.QwkScan > 0 Then Begin
        QwkLR.Base := FilePos(MBaseFile);
        QwkLR.Pos  := WriteMsgDAT;
        Write (QwkLRFile, QwkLR);
      End;
    End;
  End;

  WriteControlDAT;

  Close (QwkLRFile);

  If TotalMsgs > 0 Then Begin
    Session.io.PromptInfo[1] := strI2S(TotalMsgs);
    Session.io.PromptInfo[2] := strI2S(TotalConf);
    Session.io.OutFullLn (Session.GetPrompt(233));

    Temp := Config.qwkBBSID + '.qwk';

    Session.io.OutFullLn (Session.GetPrompt(234));

    Session.io.PromptInfo[1] := Temp;

    If FileExist(Config.QwkWelcome) Then FileCopy(Config.qwkWelcome, Session.TempPath + JustFile(Config.qwkWelcome));
    If FileExist(Config.QwkNews)    Then FileCopy(Config.qwkNews,    Session.TempPath + JustFile(Config.qwkNews));
    If FileExist(Config.QwkGoodbye) Then FileCopy(Config.qwkGoodbye, Session.TempPath + JustFile(Config.qwkGoodbye));

    If Session.LocalMode Then Begin
      Session.FileBase.ExecuteArchive (Config.QWKPath + Temp, Session.User.ThisUser.Archive, Session.TempPath + '*', 1);
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

Procedure TMsgBase.MessageQuickScan (Data: String);
// defaults to ALL mode
//   /CURRENT = scan only current message base
//   /GROUP   = scan only current group bases
//   /ALL     = scan all bases in all groups
// options:
//   /NOSCAN  = do not show "scanning" prompt
//   /NOFOOT  = do not show "end of scan" prompt
//   /NOHEAD  = do not show "starting quickscan" prompt
// Only scans bases that they have selected in Newscan, of course
Const
  Global_CurBase    : LongInt = 1;
  Global_TotalBases : LongInt = 1;
  Global_TotalMsgs  : LongInt = 0;
  Global_NewMsgs    : LongInt = 0;
  Global_YourMsgs   : LongInt = 0;
  ShowIfNew         : Boolean = False;
  ShowIfYou         : Boolean = False;
  ShowScanPrompt    : Boolean = True;
  ShowHeadPrompt    : Boolean = True;
  ShowFootPrompt    : Boolean = True;
  Mode              : Char    = 'A';

  Procedure ScanBase;
  Var
    MsgBase   : PMsgBaseABS;
    NewMsgs   : LongInt;
    YourMsgs  : LongInt;
    TotalMsgs : LongInt;
    MsgTo     : String;
  Begin
    Session.io.PromptInfo[1]  := MBase.Name;
    Session.io.PromptInfo[2]  := strI2S(Global_CurBase);
    Session.io.PromptInfo[3]  := strI2S(Global_TotalBases);

    NewMsgs   := 0;
    YourMsgs  := 0;
    TotalMsgs := 0;

    If ShowScanPrompt Then
      Session.io.OutFull(Session.GetPrompt(487));

    Case MBase.BaseType of
      0 : MsgBase := New(PMsgBaseJAM, Init);
      1 : MsgBase := New(PMsgBaseSquish, Init);
    End;

    MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

    If MsgBase^.OpenMsgBase Then Begin
      TotalMsgs := MsgBase^.NumberOfMsgs;

      MsgBase^.SeekFirst(MsgBase^.GetLastRead(Session.User.UserNum) + 1);

      While MsgBase^.SeekFound Do Begin
        Inc (NewMsgs);

        MsgBase^.MsgStartUp;

        MsgTo := strUpper(MsgBase^.GetTo);

        If (MsgTo = strUpper(Session.User.ThisUser.Handle)) or (MsgTo = strUpper(Session.User.ThisUser.RealName)) Then
          Inc(YourMsgs);

        MsgBase^.SeekNext;
      End;

      MsgBase^.CloseMsgBase;
    End;

    Inc (Global_TotalMsgs, TotalMsgs);
    Inc (Global_NewMsgs,   NewMsgs);
    Inc (Global_YourMsgs,  YourMsgs);

    Session.io.PromptInfo[4] := strI2S(TotalMsgs);
    Session.io.PromptInfo[5] := strI2S(NewMsgs);
    Session.io.PromptInfo[6] := strI2S(YourMsgs);
    Session.io.PromptInfo[7] := strI2S(Global_TotalMsgs);
    Session.io.PromptInfo[8] := strI2S(Global_NewMsgs);
    Session.io.PromptInfo[9] := strI2S(Global_YourMsgs);

    If ShowScanPrompt Then
      Session.io.OutBS(Screen.CursorX, True);

    If (ShowIfNew And (NewMsgs > 0)) or (ShowIfYou And (YourMsgs > 0)) or (Not ShowIfNew And Not ShowIfYou) Then
      Session.io.OutFullLn(Session.GetPrompt(488));

    Dispose (MsgBase, Done);
  End;

Var
  Old : RecMessageBase;
Begin
  FillChar(Session.io.PromptInfo, SizeOf(Session.io.PromptInfo), 0);

  If Pos('/GROUP',   Data) > 0 Then Mode := 'G';
  If Pos('/CURRENT', Data) > 0 Then Mode := 'C';

  ShowScanPrompt := Pos('/NOSCAN', Data) = 0;
  ShowHeadPrompt := Pos('/NOHEAD', Data) = 0;
  ShowFootPrompt := Pos('/NOFOOT', Data) = 0;

  Old                      := MBase;
  Session.User.IgnoreGroup := Mode = 'A';

  If ShowHeadPrompt Then
    Session.io.OutFullLn (Session.GetPrompt(486));

  If Mode = 'C' Then
    ScanBase
  Else Begin
    Reset (MBaseFile);
    Read  (MBaseFile, MBase); {skip email base}

    Global_TotalBases := FileSize(MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      Global_CurBase := FilePos(MBaseFile);

      If Session.User.Access(MBase.ReadACS) Then Begin
        GetMessageScan;
        If MScan.NewScan > 0 Then ScanBase;
      End;
    End;

    Close (MBaseFile);
  End;

  If ShowFootPrompt Then
    Session.io.OutFullLn(Session.GetPrompt(489));

  Session.User.IgnoreGroup := False;
  MBase                    := Old;
End;

Function TMsgBase.SaveMessage (mArea: RecMessageBase; mFrom, mTo, mSubj: String; mAddr: RecEchoMailAddr; mLines: Integer) : Boolean;
Var
  SemFile : File;
  Count   : SmallInt;
  Msg     : PMsgBaseABS;
Begin
// things to do:
// 2) see if we can use assignmessagedata, etc
// 3) add autosig?  if we cannot use the assignmsgdata things
  Result := False;

  If Not OpenCreateBase(Msg, mArea) Then Exit;

  Msg^.StartNewMsg;
  Msg^.SetLocal (True);

  If mArea.NetType > 0 Then Begin
    If mArea.NetType = 2 Then Begin
      Msg^.SetMailType (mmtNetMail);
      Msg^.SetCrash    (Config.netCrash);
      Msg^.SetHold     (Config.netHold);
      Msg^.SetKillSent (Config.netKillSent);
      Msg^.SetDest     (mAddr);
    End Else
      Msg^.SetMailType (mmtEchoMail);

    Msg^.SetOrig(Config.NetAddress[mArea.NetAddr]);

    Case mArea.NetType of
      1 : Assign (SemFile, Config.SemaPath + fn_SemFileEcho);
      2 : Assign (SemFile, Config.SemaPath + fn_SemFileNews);
      3 : Assign (SemFile, Config.SemaPath + fn_SemFileNet);
    End;

    ReWrite (SemFile);
    Close   (SemFile);
  End Else
    Msg^.SetMailType (mmtNormal);

  Msg^.SetPriv (mArea.Flags And MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, False));
  Msg^.SetFrom (mFrom);
  Msg^.SetTo   (mTo);
  Msg^.SetSubj (mSubj);

  For Count := 1 to mLines Do
    Msg^.DoStringLn(MsgText[Count]);

  If mArea.NetType > 0 Then Begin
    Msg^.DoStringLn (#13 + '--- ' + mysSoftwareID + ' BBS v' + mysVersion + ' (' + OSID + ')');
    Msg^.DoStringLn (' * Origin: ' + ResolveOrigin(mArea) + ' (' + strAddr2Str(Config.NetAddress[mArea.NetAddr]) + ')');
  End;

  Msg^.WriteMsg;
  Msg^.CloseMsgBase;

  Dispose (Msg, Done);

  Result := True;
End;

Procedure TMsgBase.PostTextFile (Data: String; AllowCodes: Boolean);
Const
  MaxLines = 10000;
Var
  MBaseFile : File;
  mName     : String;
  mArea     : Word;
  mFrom     : String;
  mTo       : String;
  mSubj     : String;
  mAddr     : RecEchoMailAddr;
  mLines    : Integer;
  InFile    : Text;
  TextBuf   : Array[1..2048] of Char;
  Buffer    : Array[1..MaxLines] of ^String;
  Str       : String[79];
  Lines     : Integer;
  Pages     : Integer;
  Count     : Integer;
  Offset    : Integer;
  TempBase  : RecMessageBase;
Begin
  mName := strWordGet(1, Data, ';');
  mArea := strS2I(strWordGet(2, Data, ';'));
  mFrom := strWordGet(3, Data, ';');
  mTo   := strWordGet(4, Data, ';');
  mSubj := strWordGet(5, Data, ';');

  Str := strWordGet(6, Data, ';');
  If (Str = '') Then Str := '0:0/0';
  strStr2Addr (Str, mAddr);

  If FileExist(Config.DataPath + mName) Then
    mName := Config.DataPath + mName
  Else
  If Not FileExist(mName) Then Begin
    Session.SystemLog('AutoPost: ' + mName + ' not found');
    Exit;
  End;

  Assign  (MBaseFile, Config.DataPath + 'mbases.dat');
  ioReset (MBaseFile, SizeOf(RecMessageBase), fmReadWrite + fmDenyNone);

  If Not ioSeek (MBaseFile, mArea) Then Begin
    Close (MBaseFile);
    Exit;
  End;

  If Not ioRead (MBaseFile, TempBase) Then Begin
    Close (MBaseFile);
    Exit;
  End;

  Close (MBaseFile);

  Assign     (InFile, mName);
  SetTextBuf (InFile, TextBuf, SizeOf(TextBuf));
  Reset      (InFile);

  Lines := 0;

  While Not Eof(InFile) And (Lines < MaxLines) Do Begin
    ReadLn (InFile, Str);

    If AllowCodes Then Str := Session.io.StrMci(Str);

    Inc (Lines);
    New (Buffer[Lines]);

    Buffer[Lines]^ := Str;
  End;

  Close (InFile);

  Pages := Lines DIV mysMaxMsgLines + 1;

  If (Lines MOD mysMaxMsgLines = 0) Then Dec(Pages);

  For Count := 1 to Pages Do Begin
    Offset := mysMaxMsgLines * Pred(Count);
    mLines := 0;

    While (Offset < Lines) and (mLines < mysMaxMsgLines) Do Begin
      Inc (mLines);
      Inc (Offset);

      MsgText[mLines] := Buffer[Offset]^;
    End;

    If Pages > 1 Then
      Str := mSubj + ' (' + strI2S(Count) + '/' + strI2S(Pages) + ')'
    Else
      Str := mSubj;

    If Not SaveMessage (TempBase, mFrom, mTo, Str, mAddr, mLines) Then Break;
  End;

  While Lines > 0 Do Begin
    Dispose (Buffer[Lines]);
    Dec     (Lines);
  End;
End;

Function TMsgBase.ResolveOrigin (Var mArea: RecMessageBase) : String;
Var
  Loc   : Byte;
  FN    : String;
  TF    : Text;
  Buf   : Array[1..2048] of Char;
  Str   : String;
  Count : LongInt;
  Pick  : LongInt;
Begin
  Result := '';
  Loc    := Pos('@RANDOM=', mArea.Origin);

  If Loc > 0 Then Begin
    FN := strStripB(Copy(mArea.Origin, Loc + 8, 255), ' ');

    If Pos(PathChar, FN) = 0 Then FN := Config.DataPath + FN;

    FileMode := 66;

    Assign     (TF, FN);
    SetTextBuf (TF, Buf, SizeOf(Buf));
    Reset      (TF);

    If IoResult <> 0 Then Exit;

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);
    End;

    If Count = 0 Then Begin
      Close (TF);
      Exit;
    End;

    Pick := Random(Count) + 1;

    Reset (TF);

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);

      If Count = Pick Then Begin
        Result := Str;
        Break;
      End;
    End;

    Close (TF);
  End Else
    Result := mArea.Origin;
End;

End.

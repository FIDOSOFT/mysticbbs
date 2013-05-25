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
  bbs_MsgBase_Squish,
  bbs_Edit_ANSI;

Type
  TMsgBase = Class
    MBaseFile   : File of RecMessageBase;
    MScanFile   : File of MScanRec;
    GroupFile   : File of RecGroup;
    TotalMsgs   : Integer;
    TotalConf   : Integer;
    MsgBase     : PMsgBaseABS;
    MBase       : RecMessageBase;
    MScan       : MScanRec;
    Group       : RecGroup;
    MsgText     : RecMessageText;
    MsgTextSize : SmallInt;
    WereMsgs    : Boolean;
    Reading     : Boolean;

    Constructor Create   (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Function    IsQuotedText        (Str: String) : Boolean;
    Function    OpenCreateBase      (Var Msg: PMsgBaseABS; Var Area: RecMessageBase) : Boolean;
    Procedure   AppendMessageText   (Var Msg: PMsgBaseABS; Lines: Integer; ReplyID: String);
    Procedure   AssignMessageData   (Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
    Function    GetBaseByNum        (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
    Function    GetBaseCompressed   (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
    Function    GetBaseByIndex      (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
    Function    GetMessageStats     (List, ShowPrompt, ShowYou: Boolean; Var ListPtr: LongInt; Var TempBase: RecMessageBase; NoFrom, NoRead: Boolean; Var Total, New, Yours: LongInt) : Boolean;
    Procedure   GetMailStats        (Var Total, UnRead: LongInt);
    Function    GetMatchedAddress   (Orig, Dest: RecEchoMailAddr) : RecEchoMailAddr;
    Function    GetTotalBases       (Compressed: Boolean) : LongInt;
    Function    GetTotalMessages    (Var TempBase: RecMessageBase) : LongInt;
    Procedure   PostTextFile        (Data: String; AllowCodes: Boolean);
    Function    SaveMessage         (mArea: RecMessageBase; mFrom, mTo, mSubj: String; mAddr: RecEchoMailAddr; mLines: Integer) : Boolean;
    Function    NetmailLookup       (FromMenu: Boolean; MsgTo, DefAddr: String) : String;
    Function    ListAreas           (Compress: Boolean) : Integer;
    Procedure   ChangeArea          (Data: String);
    Procedure   SetMessageScan;
    Procedure   GetMessageScan;
    Procedure   SendMassEmail;
    Procedure   ReplyMessage        (Email: Boolean; ListMode: Byte; ReplyID: String);
    Procedure   EditMessage;
    Function    ReadMessages        (Mode: Char; CmdData, SearchStr: String) : Boolean;
    Procedure   ToggleNewScan       (QWK: Boolean; Data: String);
    Procedure   MessageGroupChange  (Ops: String; FirstBase, Intro : Boolean);
    Procedure   PostMessage         (Email: Boolean; Data: String);
    Procedure   CheckEMail          (CmdData: String);
    Procedure   MessageNewScan      (Data: String);
    Procedure   MessageQuickScan    (Data: String);
    Procedure   GlobalMessageSearch (Mode: Char);
    Procedure   SetMessagePointers;
    Procedure   ViewSentEmail;
    Function    ResolveOrigin       (Var mArea: RecMessageBase) : String;
    // QWK and QWKE goodies
    Procedure   DownloadQWK         (Extended: Boolean; Data: String);
    Procedure   UploadREP;
    Procedure   WriteCONTROLDAT     (Extended: Boolean);
    Procedure   WriteTOREADEREXT;
    Procedure   WriteDOORID         (Extended: Boolean);
    Function    WriteMSGDAT         (Extended: Boolean) : LongInt;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core,
  bbs_User,
  bbs_NodeInfo,
  bbs_NodeList,
  bbs_cfg_UserEdit;

Const
  QwkControlName = 'MYSTICQWK';

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

  MBase.Name  := 'None';
  Group.Name  := 'None';
  WereMsgs    := False;
  Reading     := False;
  MsgTextSize := 0;
End;

Destructor TMsgBase.Destroy;
Begin
  Inherited Destroy;
End;

Function TMsgBase.GetMatchedAddress (Orig, Dest: RecEchoMailAddr) : RecEchoMailAddr;
Var
  Count : Byte;
Begin
  Result := Orig;

  If Orig.Zone = Dest.Zone Then Exit;

  For Count := 1 to 30 Do
    If Config.NetAddress[Count].Zone = Dest.Zone Then Begin
      Result := Config.NetAddress[Count];

      Exit;
    End;
End;

Function TMsgBase.NetmailLookup (FromMenu: Boolean; MsgTo, DefAddr: String) : String;

  Procedure ShowNode (ShowType: Byte; NodeData: RecNodeSearch; Ext: Boolean);
  Var
    Str : String;
  Begin
    Case ShowType of
      0  : Str := strAddr2Str(NodeData.Address);
      1,
      2  : If NodeData.Keyword = 'ZONE' Then
             Str := 'ZONE' + strPadL(strI2S(NodeData.Address.Zone), 8, ' ')
           Else
           If NodeData.Keyword = 'REGION' Then
             Str := 'REGION' + strPadL(strI2S(NodeData.Address.Net), 6, ' ')
           Else
           If NodeData.Keyword = 'HOST' Then
             Str := 'NET' + strPadL(strI2S(NodeData.Address.Net), 9, ' ');
    End;

    Session.io.PromptInfo[1] := Str;
    Session.io.PromptInfo[2] := NodeData.BBSName;
    Session.io.PromptInfo[3] := NodeData.Location;
    Session.io.PromptInfo[4] := NodeData.SysopName;
    Session.io.PromptInfo[5] := NodeData.Phone;
    Session.io.PromptInfo[6] := NodeData.Internet;

    If Ext Then
      Session.io.OutFullLn(Session.GetPrompt(500))
    Else
      Session.io.OutFullLn(Session.GetPrompt(499));
  End;

Var
  NodeList  : TNodeListSearch;
  FirstNode : RecNodeSearch;
  NodeData  : RecNodeSearch;
  Listed    : LongInt;
  ListType  : Byte;
  HasList   : Boolean;
  Addr      : RecEchoMailAddr;
Begin
  HasList  := FileExist(Config.DataPath + 'nodelist.txt');
  NodeList := TNodeListSearch.Create;

  If HasList Then
    Session.io.OutFile ('nodesearch', False, 0);

  Repeat
    If FromMenu Then
      Session.io.OutFull (Session.GetPrompt(497))
    Else
      If HasList Then
        Session.io.OutFull (Session.GetPrompt(496))
      Else
        Session.io.OutFull (Session.GetPrompt(342));

    Result := strUpper(Session.io.GetInput(25, 25, 11, DefAddr));

    If Result = '' Then Break;

    If (Result = '?') and HasList Then Begin
      Session.io.OutFile('nodesearch', False, 0);

      Continue;
    End;

    If Not HasList Then Break;

    ListType := 0;

    If Pos('LIST ZONE', Result) > 0 Then Begin
      ListType := 1;
      Result   := '?:?/?';
    End;

    If Pos('LIST NET', Result) > 0 Then Begin
      ListType := 2;
      Result   := strWordGet(3, Result, ' ') + ':?/?';
    End;

    Listed := 0;

    Session.io.PausePtr   := 1;
    Session.io.AllowPause := True;

    NodeList.ResetSearch (Config.DataPath + 'nodelist.txt', Result);

    While NodeList.FindNext(NodeData) Do Begin
      Case ListType of
        1 : If NodeData.Keyword <> 'ZONE' Then Continue;
        2 : If (NodeData.Keyword <> 'ZONE') and (NodeData.Keyword <> 'REGION') and (NodeData.Keyword <> 'HOST') Then Continue;
      End;

      Inc (Listed);

      If Listed = 1 Then
        FirstNode := NodeData
      Else Begin
        If Listed = 2 Then Begin
          Session.io.OutFullLn (Session.GetPrompt(498));

          ShowNode (ListType, FirstNode, False);
        End;

        ShowNode (ListType, NodeData, False);
      End;

      If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;

    If (Listed = 1) and (ListType = 0) Then Begin
      ShowNode(ListType, FirstNode, True);

      If FromMenu Then Continue;

      Session.io.PromptInfo[7] := MsgTo;

      If Session.io.GetYN(Session.GetPrompt(502), True) Then Begin
        Result := strAddr2Str(NodeData.Address);

        Break;
      End;
    End Else
    If (Listed = 0) And Not FromMenu And Not Config.ForceNodelist Then Begin
      If strStr2Addr(Result, Addr) Then Begin
        Session.io.PromptInfo[1] := strAddr2Str(Addr);
        Session.io.PromptInfo[7] := MsgTo;

        If Session.io.GetYN(Session.GetPrompt(502), True) Then Begin
          Result := strAddr2Str(Addr);

          Break;
        End;
      End;
    End Else Begin
      Session.io.PromptInfo[1] := strComma(Listed);

      Session.io.OutFullLn(Session.GetPrompt(501));
    End;
  Until False;

  NodeList.Free;
End;

Function TMsgBase.IsQuotedText (Str: String) : Boolean;
Var
  Temp : Byte;
Begin
  Temp := Pos('>', Str);
//  Temp   := Pos('>', strStripL(Str, ' '));
  Result := (Temp > 0) and (Temp < 5);
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

Function TMsgBase.GetBaseByNum (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  If ioSeek(F, Num) And (ioRead(F, TempBase)) Then
    Result := True;

  Close (F);
End;

Function TMsgBase.GetBaseCompressed (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F     : File;
  Count : LongInt;
Begin
  If Not Config.MCompress Then Begin
    Result := GetBaseByNum(Num, TempBase);

    Exit;
  End;

  Result := False;

  Assign (F, Config.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  Count := 0;

  While Not Eof(F) And (Count <> Num) Do Begin
    ioRead (F, TempBase);

    If Session.User.Access(TempBase.ListACS) Then Inc(Count);
  End;

  Close (F);

  Result := Count = Num;
End;

Function TMsgBase.GetBaseByIndex (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempBase);

    If TempBase.Index = Num Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (F);
End;

Function TMsgBase.GetTotalBases (Compressed: Boolean) : LongInt;
Var
  F        : File;
  TempBase : RecMessageBase;
Begin
  Result := 0;

  Assign (F, Config.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  If Not Compressed Then
    Result := FileSize(F)
  Else Begin
    While Not Eof(F) Do Begin
      ioRead (F, TempBase);

      If Session.User.Access(TempBase.ListACS) Then
        Inc (Result);
    End;
  End;

  Close (F);
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

Function TMsgBase.GetMessageStats (List, ShowPrompt, ShowYou: Boolean; Var ListPtr: LongInt; Var TempBase: RecMessageBase; NoFrom, NoRead: Boolean; Var Total, New, Yours: LongInt) : Boolean;
Var
  TempMsg : PMsgBaseABS;
Begin
  Total  := 0;
  New    := 0;
  Yours  := 0;
  Result := False;

  If TempBase.Name = 'None' Then Exit;

  If OpenCreateBase(TempMsg, TempBase) Then Begin
    Total := TempMsg^.NumberOfMsgs;

    TempMsg^.SeekFirst(TempMsg^.GetLastRead(Session.User.UserNum) + 1);

    While TempMsg^.SeekFound Do Begin
      TempMsg^.MsgStartUp;

      If NoFrom And Session.User.IsThisUser(TempMsg^.GetFrom) Then Begin
        TempMsg^.SeekNext;

        Continue;
      End;

      If (TempBase.Flags AND MBPrivate <> 0) And Not Session.User.IsThisUser(TempMsg^.GetTo) Then Begin
        TempMsg^.SeekNext;

        Continue;
      End;

      If TempMsg^.IsPriv And Not Session.User.IsThisUser(TempMsg^.GetTo) Then Begin
        TempMsg^.SeekNext;

        Continue;
      End;

      If NoRead And Session.User.IsThisUser(TempMsg^.GetTo) And TempMsg^.IsRcvd Then Begin
        TempMsg^.SeekNext;

        Continue;
      End;

      If List Then Begin
        If (ShowYou And Not Session.User.IsThisUser(TempMsg^.GetTo)) Then Begin
          TempMsg^.SeekNext;

          Continue;
        End;

        If ShowPrompt Then
          Session.io.OutBS(Screen.CursorX, True);

        Inc (ListPtr);

        Session.io.PromptInfo[1] := strI2S(ListPtr);
        Session.io.PromptInfo[2] := TempBase.Name;
        Session.io.PromptInfo[3] := TempMsg^.GetFrom;
        Session.io.PromptInfo[4] := TempMsg^.GetTo;
        Session.io.PromptInfo[5] := TempMsg^.GetSubj;
        Session.io.PromptInfo[6] := DateDos2Str(DateStr2Dos(TempMsg^.GetDate), Session.User.ThisUser.DateType);

        If ListPtr = 1 Then
          Session.io.OutFullLn(Session.GetPrompt(506));

        Session.io.OutFullLn(Session.GetPrompt(507));

        //write('ptr:', session.io.pauseptr, ' size:', session.user.thisuser.screensize, ' allow:', session.io.allowpause);session.io.getkey;

        If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
          Case Session.io.MorePrompt of
            'N' : Begin
                    Result := True;

                    Break;
                  End;
            'C' : Session.io.AllowPause := False;
          End;

//        If ShowPrompt Then
//          Session.io.OutFull(Session.GetPrompt(487));

        Session.io.BufFlush;
      End;

      Inc (New);

      If Session.User.IsThisUser(TempMsg^.GetTo) Then
        Inc(Yours);

      TempMsg^.SeekNext;
    End;

    TempMsg^.CloseMsgBase;

    Dispose (TempMsg, Done);
  End;
End;

Procedure TMsgBase.GetMailStats (Var Total, UnRead: LongInt);
Var
  MsgBase  : PMsgBaseABS;
  TempBase : RecMessageBase;
Begin
  Total    := 0;
  UnRead   := 0;
  FileMode := 66;

  Reset (MBaseFile);
  Read  (MBaseFile, TempBase);
  Close (MBaseFile);

  If OpenCreateBase (MsgBase, TempBase) Then Begin
    MsgBase^.SeekFirst (1);

    While MsgBase^.SeekFound Do Begin
      MsgBase^.MsgStartUp;

      If Session.User.IsThisUser(MsgBase^.GetTo) Then Begin
        Inc (Total);

        If Not MsgBase^.IsRcvd Then Inc (UnRead);
      End;

      MsgBase^.SeekNext;
    End;

    MsgBase^.CloseMsgBase;

    Dispose (MsgBase, Done);
  End;
End;

Procedure TMsgBase.SetMessageScan;
Var
  Count : Integer;
  Temp  : MScanRec;
Begin
  Temp.NewScan := MBase.DefNScan;
  Temp.QwkScan := MBase.DefQScan;

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

  FileMode := 66;

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
  If (MBase.NetType > 0) and (MBase.NetType <> 3) Then Begin
    Msg^.DoStringLn (#1 + 'MSGID: ' + strAddr2Str(Config.NetAddress[MBase.NetAddr]) + ' ' + strI2H(CurDateDos, 8));

    If ReplyID <> '' Then
      Msg^.DoStringLn (#1 + 'REPLY: ' + ReplyID);
  End;

  For A := 1 to Lines Do
    Msg^.DoStringLn(MsgText[A]);

  If (MBase.Flags AND MBAutoSigs <> 0) and Session.User.ThisUser.SigUse and (Session.User.ThisUser.SigLength > 0) Then Begin

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
    Msg^.DoStringLn (#13 + '--- ' + mysSoftwareID + ' v' + mysVersion + ' (' + OSID + ')');
    Msg^.DoStringLn (' * Origin: ' + ResolveOrigin(MBase) + ' (' + strAddr2Str(Msg^.GetOrigAddr) + ')');
  End;
End;

Procedure TMsgBase.AssignMessageData (Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
Var
  SemFile : Text;
Begin
  Msg^.StartNewMsg;

  If TempBase.Flags And MBRealNames <> 0 Then
    Msg^.SetFrom(Session.User.ThisUser.RealName)
  Else
    Msg^.SetFrom(Session.User.ThisUser.Handle);

  Msg^.SetLocal (True);

  If TempBase.NetType > 0 Then Begin
    If TempBase.NetType = 3 Then
      Msg^.SetMailType(mmtNetMail)
    Else
      Msg^.SetMailType(mmtEchoMail);

    Msg^.SetOrig(Config.NetAddress[TempBase.NetAddr]);

    Case TempBase.NetType of
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

  Msg^.SetPriv (TempBase.Flags and MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, 0));
End;

Procedure TMsgBase.ChangeArea (Data: String);
Var
  Count    : LongInt;
  Total    : Word;
  TempBase : RecMessageBase;
Begin
  If (Data = '+') or (Data = '-') Then Begin
    Count := Session.User.ThisUser.LastMBase;

    Repeat
      Case Data[1] of
        '+' : Inc(Count);
        '-' : Dec(Count);
      End;

      If Not GetBaseByNum(Count, TempBase) Then Exit;

      If Session.User.Access(TempBase.ListACS) Then Begin
        Session.User.ThisUser.LastMBase := Count;
        MBase                           := TempBase;

        Exit;
      End;
    Until False;
  End;

  Count := strS2I(Data);

  If Count > 0 Then Begin
    If GetBaseByNum (Count, TempBase) Then
      If Session.User.Access(TempBase.ListACS) Then Begin
        Session.User.ThisUser.LastMBase := Count;
        MBase                           := TempBase;
      End;

    Exit;
  End;

  If Pos('NOLIST', strUpper(Data)) > 0 Then
    Total := GetTotalBases(Config.MCompress)
  Else
    Total := ListAreas(Config.MCompress);

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(94));

    Exit;
  End;

  Repeat
    Session.io.OutFull (Session.GetPrompt(102));

    Case Session.io.OneKeyRange(#13 + '?Q', 1, Total) of
      #13,
      'Q': Exit;
      '?': Total := ListAreas(Config.MCompress);
    Else
      Break;
    End;
  Until False;

  Count := Session.io.RangeValue;

  If GetBaseCompressed(Count, TempBase) Then
    If Session.User.Access(MBase.ListACS) Then Begin
      MBase                           := TempBase;
      Session.User.ThisUser.LastMBase := Count;
    End;
End;

Procedure TMsgBase.ToggleNewScan (QWK: Boolean; Data: String);
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

    Total    := 0;
    FileMode := 66;

    Reset (MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ListACS) Then Begin
        Inc (Total);

        Session.io.PromptInfo[1] := strI2S(Total);
        Session.io.PromptInfo[2] := MBase.Name;

        GetMessageScan;

        If ((MScan.NewScan > 0) And Not QWK) or ((MScan.QwkScan > 0) And QWK) Then
          Session.io.PromptInfo[3] := 'Yes' {++lang++}
        Else
          Session.io.PromptInfo[3] := 'No'; {++lang++}

        Session.io.OutFull (Session.GetPrompt(93));

        If (Total MOD Config.MColumns = 0) And (Total > 0) Then Session.io.OutRawLn('');
      End;

      If EOF(MBaseFile) and (Total MOD Config.MColumns <> 0) Then Session.io.OutRawLn('');

      If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;

    Close (MBaseFile);

    Session.io.OutFull (Session.GetPrompt(430));
  End;

  Procedure ToggleCurrent (Forced: LongInt);
  Begin
    GetMessageScan;

    Session.io.PromptInfo[1] := MBase.Name;

    If QWK Then Begin
      Case MScan.QwkScan of
        0 : Begin
              If Forced <> -1 Then
                MScan.QwkScan := Forced
              Else Begin
                MScan.QwkScan := 1;

                Session.io.OutFullLn (Session.GetPrompt(97));
              End;
            End;
        1 : Begin
              If Forced <> -1 Then
                MScan.QwkScan := Forced
              Else Begin
                MScan.QwkScan := 0;

                Session.io.OutFullLn (Session.GetPrompt(96));
              End;
            End;
        2 : If Forced <> -1 Then
              Session.io.OutFullLn (Session.GetPrompt(302));
      End;
    End Else Begin
      Case MScan.NewScan of
        0 : Begin
              If Forced <> -1 Then
                MScan.NewScan := Forced
              Else Begin
                MScan.NewScan := 1;

                Session.io.OutFullLn (Session.GetPrompt(99));
              End;
            End;
        1 : Begin
              If Forced <> -1 Then
                MScan.NewScan := Forced
              Else Begin
                MScan.NewScan := 0;

                Session.io.OutFullLn (Session.GetPrompt(98));
              End;
            End;
        2 : If Forced <> -1 Then
              Session.io.OutFullLn (Session.GetPrompt(302));
      End;
    End;

    SetMessageScan;
  End;

  Procedure ToggleAll (Value: Byte);
  Begin
    Reset (MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ListACS) Then
        ToggleCurrent(Value);
    End;

    Close (MBaseFile);
  End;

  Procedure ToggleByNumber (BaseNumber: LongInt);
  Begin
    If (BaseNumber > 0) And GetBaseCompressed(BaseNumber, MBase) Then
      ToggleCurrent(-1);
  End;

Var
  Old    : RecMessageBase;
  Temp   : String[40];
  Count1 : LongInt;
  Count2 : LongInt;
  Num1   : String[40];
  Num2   : String[40];
Begin
  Old      := MBase;
  FileMode := 66;

  Session.User.IgnoreGroup := Pos('/ALLGROUP', strUpper(Data)) > 0;

  List_Bases;

  If Total = 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(94));

    MBase := Old;

    Session.User.IgnoreGroup := False;

    Exit;
  End;

  Repeat
    Session.io.OutFull (Session.GetPrompt(95));

    Temp := Session.io.GetInput(10, 40, 12, '');

    If (Temp = '') or (Temp = 'Q') Then Break;

    If Temp = 'A' Then
      ToggleAll(1)
    Else
    If Temp = 'D' Then
      ToggleAll(0)
    Else
    If Temp = '?' Then
      // do nothing
    Else Begin
      Num1 := '';
      Num2 := '';

      For Count1 := 1 to Length(Temp) Do Begin
        If Temp[Count1] = ' ' Then Continue;

        If Temp[Count1] = ',' Then Begin
          If Num2 <> '' Then Begin
            For Count2 := strS2I(Num2) to strS2I(Num1) Do
              ToggleByNumber(Count2);
          End Else
            ToggleByNumber(strS2I(Num1));

          Num1 := '';
          Num2 := '';
        End Else
        If Temp[Count1] = '-' Then Begin
          Num2 := Num1;
          Num1 := '';
        End Else
          Num1 := Num1 + Temp[Count1];
      End;

      If Num2 <> '' Then Begin
        For Count1 := strS2I(Num2) to strS2I(Num1) Do
          ToggleByNumber(Count1);
      End Else
        ToggleByNumber(strS2I(Num1));
    End;

    List_Bases;
  Until False;

  MBase := Old;

  Session.User.IgnoreGroup := False;
End;

Procedure TMsgBase.MessageGroupChange (Ops : String; FirstBase, Intro : Boolean);
Var
  Count  : Word;
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

    Count := Session.User.ThisUser.LastMGroup - 1;

    Repeat
      Case Ops[1] of
        '+' : Inc(Count);
        '-' : Dec(Count);
      End;

      {$I-}
      Seek (GroupFile, Count);
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

    Seek (GroupFile, Data - 1);
    Read (GroupFile, Group);

    If Session.User.Access(Group.ACS) Then Begin
      Session.User.ThisUser.LastMGroup := FilePos(GroupFile);

      If Intro Then
        Session.io.OutFile ('group' + strI2S(Data), True, 0);
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

    Session.io.OneKeyRange(#13 + 'Q', 1, Total);

    Count := Session.io.RangeValue;

    If (Count > 0) and (Count <= Total) Then Begin
      Total := 0;

      Reset (GroupFile);

      Repeat
        Read (GroupFile, Group);

        If Not Group.Hidden And Session.User.Access(Group.ACS) Then Inc(Total);

        If Count = Total Then Break;
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
  Total    : LongInt = 0;
  Listed   : LongInt = 0;
  TempBase : RecMessageBase;
  TempFile : File;
Begin
  Result := 1;

  Assign (TempFile, Config.DataPath + 'mbases.dat');

  If Not ioReset(TempFile, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  While Not Eof(TempFile) Do Begin
    ioRead (TempFile, TempBase);

    If Session.User.Access(TempBase.ListACS) Then Begin
      Inc (Listed);

      If Listed = 1 Then
        Session.io.OutFullLn(Session.GetPrompt(100));

      If Compress Then
        Inc (Total)
      Else
        Total := FilePos(TempFile);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := TempBase.Name;
      Session.io.PromptInfo[3] := strI2S(GetTotalMessages(TempBase));

      Session.io.OutFull (Session.GetPrompt(101));

      If (Listed MOD Config.MColumns = 0) and (Listed > 0) Then Session.io.OutRawLn('');
    End;

    If Eof(TempFile) and (Listed MOD Config.MColumns <> 0) Then Session.io.OutRawLn('');

    If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Begin
                Total := FileSize(TempFile);
                Break;
              End;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Close (TempFile);

  Result := Total;
End;

Procedure TMsgBase.ReplyMessage (Email: Boolean; ListMode: Byte; ReplyID: String);
Var
  ToWho     : String[30];
  Subj      : String[60];
  Addr      : RecEchomailAddr;
  MsgNew    : PMsgBaseABS;
  TempStr   : String;
  Initials  : String[4];
  WrapData  : String;
  DoWrap    : Boolean = True;
  QuoteFile : Text;
  Lines     : SmallInt;
  Total     : LongInt;
  ReplyBase : RecMessageBase;
  IsPrivate : Boolean;
  IsIgnore  : Boolean;
Begin
  ReplyBase := MBase;

  If Not Email And Session.User.Access(Config.AcsExtReply) Then Begin
    Session.io.PromptInfo[1] := MBase.Name;
    Session.io.PromptInfo[2] := MsgBase^.GetFrom;
    Session.io.PromptInfo[3] := MsgBase^.GetSubj;

    If ListMode = 0 Then
      Session.io.OutFull(Session.GetPrompt(509))
    Else
      Session.io.OutFull(Session.GetPrompt(510));

    Case Session.io.OneKey (#13#27 + 'QBE', True) of
      'Q',
      #27 : Exit;
      'B' : Begin
              IsIgnore := Session.User.IgnoreGroup;

              Session.User.IgnoreGroup := True;

              Total := ListAreas(Config.MCompress);

              Repeat
                Session.io.OutFull(Session.GetPrompt(511));

                Case Session.io.OneKeyRange(#13 + '?Q', 1, Total) of
                  #13,
                  'Q': Begin
                         Session.User.IgnoreGroup := IsIgnore;

                         Exit;
                       End;
                  '?': Total := ListAreas(Config.MCompress);
                Else
                  Break;
                End;
              Until False;

              If Not GetBaseCompressed(Session.io.RangeValue, ReplyBase) Then Begin
                Session.User.IgnoreGroup := IsIgnore;

                Exit;
              End;

              Session.User.IgnoreGroup := IsIgnore;
            End;
      'E' : Begin
              Reset (MBaseFile);
              Read  (MBaseFile, ReplyBase);
              Close (MBaseFile);

              Email := True;
            End;
    End;
  End;

  Session.io.PromptInfo[1] := ReplyBase.Name;

  Session.io.OutFullLn(Session.GetPrompt(512));

  If Not Session.User.Access(ReplyBase.PostACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(105));
    Exit;
  End;

  Set_Node_Action (Session.GetPrompt(349));

  IsPrivate := (ReplyBase.Flags AND MBPrivate <> 0) or (ReplyBase.NetType = 3);

  If (ReplyBase.Flags AND MBPrivate = 0) AND (ReplyBase.Flags AND MBPrivReply <> 0) Then
    IsPrivate := Session.io.GetYN(Session.GetPrompt(514), False);

  Repeat
    If ListMode = 0 Then
      Session.io.OutFull (Session.GetPrompt(407))
    Else
      Session.io.OutFull (Session.GetPrompt(408));

    ToWho := Session.io.GetInput(30, 30, 11, MsgBase^.GetFrom);

    If ToWho = '' Then Exit;

    If (ReplyBase.NetType = 3) Or Not (Email or IsPrivate) Then Break;

    If Not Session.User.FindUser(ToWho, False) Then Begin
      Session.io.PromptInfo[1] := ToWho;

      Session.io.OutFullLn (Session.GetPrompt(161));

      ToWho := MsgBase^.GetFrom;
    End Else
      Break;
  Until False;

  If ReplyBase.NetType = 3 Then Begin
    MsgBase^.GetOrig(Addr);

    TempStr := NetmailLookup(False, ToWho, strAddr2Str(Addr));

    If Not strStr2Addr (TempStr, Addr) Then Exit;
  End;

  Subj := MsgBase^.GetSubj;

  If Pos ('Re:', Subj) = 0 Then Subj := 'Re: ' + Subj;

  Session.io.OutFull (Session.GetPrompt(451));

  Subj := Session.io.GetInput (60, 60, 11, Subj);

  If Subj = '' Then Exit;

  Assign (QuoteFile, Session.TempPath + 'msgtmp');
  {$I-} ReWrite (QuoteFile); {$I+}

  If IoResult = 0 Then Begin
    Initials := strInitials(MsgBase^.GetFrom) + '> ';
    TempStr  := Session.GetPrompt(464);

    TempStr := strReplace(TempStr, '|&1', MsgBase^.GetDate);
    TempStr := strReplace(TempStr, '|&2', MsgBase^.GetFrom);
    TempStr := strReplace(TempStr, '|&3', Initials);

    WriteLn (QuoteFile, TempStr);
    WriteLn (QuoteFile, ' ');

    MsgBase^.MsgTxtStartUp;

    WrapData := '';

    While Not MsgBase^.EOM Do Begin
      TempStr := MsgBase^.GetString(79);

      If TempStr[1] = #1 Then Continue;

      DoWrap := Not IsQuotedText(TempStr);

      If DoWrap Then Begin
        If WrapData <> '' Then Begin
          If TempStr = '' Then Begin
            WriteLn (QuoteFile, ' ' + Initials + strStripB(WrapData, ' '));
            WriteLn (QuoteFile, ' ' + Initials);

            WrapData := '';

            Continue;
          End;

          TempStr := strStripB(WrapData, ' ') + ' ' + strStripL(TempStr, ' ');
        End;

        strWrap (TempStr, WrapData, 74);

        WriteLn (QuoteFile, ' ' + Initials + Copy(TempStr, 1, 75));
      End Else
        WriteLn (QuoteFile, ' ' + Initials + Copy(TempStr, 1, 75));
    End;

    Close (QuoteFile);
  End;

  Lines := 0;

  Session.io.PromptInfo[1] := ToWho;

  If Editor(Lines, ColumnValue[Session.Theme.ColumnSize] - 2, mysMaxMsgLines, False, fn_tplMsgEdit, Subj) Then Begin
    Session.io.OutFull (Session.GetPrompt(107));

    If Not OpenCreateBase(MsgNew, ReplyBase) Then Exit;

    AssignMessageData(MsgNew, ReplyBase);

    Case ReplyBase.NetType of
      2 : MsgNew^.SetTo('All');  //Lang++
      3 : Begin
            MsgNew^.SetDest     (Addr);
            MsgNew^.SetOrig     (GetMatchedAddress(Config.NetAddress[ReplyBase.NetAddr], Addr));
            MsgNew^.SetCrash    (Config.netCrash);
            MsgNew^.SetHold     (Config.netHold);
            MsgNew^.SetKillSent (Config.netKillSent);
            MsgNew^.SetTo       (ToWho);
          End;
    Else
      MsgNew^.SetTo (ToWho);
    End;

    MsgNew^.SetSubj  (Subj);
    MsgNew^.SetRefer (MsgBase^.GetMsgNum);
    MsgNew^.SetPriv  (IsPrivate);

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
      Session.SystemLog ('Posted #' + strI2S(MsgNew^.GetMsgNum) + ': "' + Subj + '" to ' + strStripMCI(ReplyBase.Name));

      Inc (Session.User.ThisUser.Posts);
      Inc (Session.HistoryPosts);
    End;

    Dispose (MsgNew, Done);

    Session.io.OutFullLn (Session.GetPrompt(122));
  End Else
    Session.io.OutFullLn (Session.GetPrompt(109));

  DirClean (Session.TempPath, '');
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
    Session.io.PromptInfo[3] := Session.io.OutYN(MsgBase^.IsSent);

    If MBase.NetType = 3 Then Begin
      MsgBase^.GetDest(DestAddr);

      Session.io.PromptInfo[1] := Session.io.PromptInfo[1] + ' (' + strAddr2Str(DestAddr) + ')';
    End;

    Session.io.OutFull (Session.GetPrompt(296));

    Case Session.io.OneKey('ABCQ!', True) of
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
      'C' : MsgBase^.SetSent(NOT MsgBase^.IsSent);
      '!' : Begin
              Temp1 := MsgBase^.GetSubj;

              If Editor(Lines, ColumnValue[Session.Theme.ColumnSize] - 2, mysMaxMsgLines, False, fn_tplMsgEdit, Temp1) Then
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

(*
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

    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, FN);

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

  DirClean (Session.TempPath, 'msgtmp');

  Session.io.PromptInfo[1] := T1;
  Session.io.PromptInfo[2] := T2;
End;
*)

Function TMsgBase.ReadMessages (Mode: Char; CmdData, SearchStr: String) : Boolean;
Var
  ReadRes   : Boolean;
  NoFrom    : Boolean;
  NoRead    : Boolean;
  ScanMode  : Byte;
  ValidKeys : String;
  HelpFile  : String[8];
  LastRead  : LongInt;
  ListMode  : Byte;
  ReplyID   : String[60];
  TempStr   : String;

  Procedure SetMessageSecurity;
  Begin
    If Mode = 'E' Then Begin
      ValidKeys := 'ADJLNPQRX?'#13;
      HelpFile  := 'emailhlp';
    End Else
    If Session.User.Access(MBase.SysopACS) or Session.User.IsThisUser(MsgBase^.GetFrom) Then Begin
      ValidKeys := 'ADEFGHIJLMNPQRTX[]?'#13;
      HelpFile  := 'readshlp';
    End Else Begin
      ValidKeys := 'AGHIJLNPQRTX[]?'#13;
      HelpFile  := 'readhlp';
    End;
  End;

  Function MoveMessage (IsCopy: Boolean) : Boolean;
  Var
    Total    : LongInt;
    TempBase : RecMessageBase;
    MsgNew   : PMsgBaseABS;
    Str      : String;
    Addr     : RecEchoMailAddr;
    Ignore   : Boolean;
  Begin
    Result := False;
    Ignore := Session.User.IgnoreGroup;

    Session.User.IgnoreGroup := True;

    Repeat
      Total := ListAreas(Config.MCompress);

      If IsCopy Then
        Session.io.OutFull (Session.GetPrompt(492))
      Else
        Session.io.OutFull (Session.GetPrompt(282));

      Case Session.io.OneKeyRange('Q?', 1, Total) of
        #00: If GetBaseCompressed(Session.io.RangeValue, TempBase) Then Begin
               If Not Session.User.Access(TempBase.PostACS) Then Begin
                 Session.io.OutFullLn (Session.GetPrompt(105));
                 Break;
               End;

               Session.io.PromptInfo[1] := TempBase.Name;

               Session.io.OutFullLn (Session.GetPrompt(318));

               If Not OpenCreateBase(MsgNew, TempBase) Then Break;

               MsgNew^.StartNewMsg;

               MsgNew^.SetFrom  (MsgBase^.GetFrom);
               MsgNew^.SetLocal (True);

               Case TempBase.NetType of
                 0 : MsgNew^.SetMailType(mmtNormal);
                 3 : MsgNew^.SetMailType(mmtNetMail);
               Else
                 MsgNew^.SetMailType(mmtEchoMail);
               End;

               MsgBase^.GetOrig (Addr);
               MsgNew^.SetOrig  (Addr);
               MsgNew^.SetPriv  (MsgBase^.IsPriv);
               MsgNew^.SetDate  (MsgBase^.GetDate);
               MsgNew^.SetTime  (MsgBase^.GetTime);
               MsgNew^.SetTo    (MsgBase^.GetTo);
               MsgNew^.SetSubj  (MsgBase^.GetSubj);

               MsgBase^.MsgTxtStartUp;

               While Not MsgBase^.EOM Do Begin
                 Str := MsgBase^.GetString(79);

                 MsgNew^.DoStringLn(Str);
               End;

               MsgNew^.WriteMsg;
               MsgNew^.CloseMsgBase;

               Dispose (MsgNew, Done);

               If IsCopy Then
                 Session.SystemLog('Forward msg to ' + strStripMCI(TempBase.Name))
               Else Begin
                 Session.SystemLog('Moved msg to ' + strStripMCI(TempBase.Name));

                 MsgBase^.DeleteMsg;
               End;

               Result := True;

               Break;
             End;
        #13,
        'Q': Break;
      End;
    Until False;

    Session.User.IgnoreGroup := Ignore;
  End;

  Procedure ExportMessage;
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

    Session.io.PromptInfo[1] := JustFile(FN);

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
      Session.io.BufFlush;
    End;

    If Not First Then
      If Back Then
        MsgBase^.SeekPrior
      Else
        MsgBase^.SeekNext;

    While Not Res And MsgBase^.SeekFound Do Begin
      MsgBase^.MsgStartUp;

      Case ScanMode of
        0 : If MsgBase^.IsPriv Then
              Res := Session.User.IsThisUser(MsgBase^.GetTo) or Session.User.IsThisUser(MsgBase^.GetFrom)
            Else
              Res := True;
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

      If NoFrom And Session.User.IsThisUser(MsgBase^.GetFrom) Then
        Res := False;

      If NoRead And Session.User.IsThisUser(MsgBase^.GetTo) And MsgBase^.IsRcvd Then
        Res := False;

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

  Procedure AssignHeaderInfo;
  Var
    NetAddr : RecEchoMailAddr;
  Begin
    FillChar (Session.io.PromptInfo, SizeOf(Session.io.PromptInfo), 0);

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
    Session.io.PromptInfo[4]  := DateDos2Str(DateStr2Dos(MsgBase^.GetDate), Session.User.ThisUser.DateType);
    Session.io.PromptInfo[10] := MsgBase^.GetTime;
    Session.io.PromptInfo[5]  := strI2S(MsgBase^.GetMsgNum);
    Session.io.PromptInfo[6]  := strI2S(MsgBase^.GetHighMsgNum);
    Session.io.PromptInfo[7]  := strI2S(MsgBase^.GetRefer);
    Session.io.PromptInfo[8]  := strI2S(MsgBase^.GetSeeAlso);

    TempStr := Session.GetPrompt(490);

    If MsgBase^.IsLocal   Then Session.io.PromptInfo[9] := strWordGet(1, TempStr, ',');
    If MsgBase^.IsEchoed  Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' ' + strWordGet(2, TempStr, ',');
    If MsgBase^.IsPriv    Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' ' + strWordGet(3, TempStr, ',');
    If MsgBase^.IsSent    Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' ' + strWordGet(4, TempStr, ',');
    If MsgBase^.IsRcvd    Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' ' + strWordGet(6, TempStr, ',');
    If MsgBase^.IsDeleted Then Session.io.PromptInfo[9] := Session.io.PromptInfo[9] + ' ' + strWordGet(5, TempStr, ',');

    Session.io.PromptInfo[9] := strStripB(Session.io.PromptInfo[9], ' ');
  End;

  Procedure Send_Msg_Text (Str: String);
  Begin
    If IsQuotedText(Str) Then Begin
      Session.io.AnsiColor (MBase.ColQuote);
      Session.io.OutPipe   (Str);
      Session.io.AnsiColor (MBase.ColText);
    End Else
    If Copy(Str, 1, 4) = '--- ' Then Begin
      Session.io.AnsiColor (MBase.ColTear);
      Session.io.OutPipe   (Str);
      Session.io.AnsiColor (MBase.ColText);
    End Else
    If Copy(Str, 1, 2) = ' *' Then Begin
      Session.io.AnsiColor (MBase.ColOrigin);
      Session.io.OutPipe   (Str);
      Session.io.AnsiColor (MBase.ColText);
    End Else
      Session.io.OutPipe(Str);

    If ListMode = 1 Then
      Session.io.AnsiClrEOL;

    Session.io.OutRawLn('');
  End;

  Procedure RemoveNewScan (PromptNumber: SmallInt);
  Begin
    GetMessageScan;

    If MScan.NewScan = 1 Then
      If Session.io.GetYN(Session.GetPrompt(PromptNumber), False) Then Begin
        MScan.NewScan := 0;

        SetMessageScan;
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

      Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y);
      Session.io.AnsiColor  (MBase.ColText);

      For A := 1 to PageSize Do
        If PageEnd <= Lines Then Begin
          Send_Msg_Text(MsgText[PageEnd]);
          Inc (PageEnd);
        End Else Begin
          Session.io.AnsiClrEOL;
          Session.io.OutRawLn ('');
        End;

      Temp := Session.io.DrawPercent(Session.Theme.MsgBar, PageEnd - 1, Lines, A);

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
    CurMsg : LongInt;
  Begin
    Result := False;

    Repeat
      Set_Node_Action (Session.GetPrompt(348));

      SetMessageSecurity;

      If Session.User.IsThisUser(MsgBase^.GetTo) And Not MsgBase^.IsRcvd Then Begin
        MsgBase^.SetRcvd(True);
        MsgBase^.ReWriteHDR;
      End;

      CurMsg    := MsgBase^.GetMsgNum;
      Lines     := 0;
      PageStart := 1;

      If CurMsg > LastRead Then LastRead := CurMsg;

      Session.io.AllowArrow := True;

      // create ReadMessageText function?

      MsgBase^.MsgTxtStartUp;

      While Not MsgBase^.EOM And (Lines < mysMaxMsgLines) Do Begin
        Inc (Lines);

        MsgText[Lines] := MsgBase^.GetString(79);

        If MsgText[Lines][1] = #1 Then Begin
          If Copy(MsgText[Lines], 2, 5) = 'MSGID' Then
            ReplyID := Copy(MsgText[Lines], 9, Length(MsgText[Lines]));

          Dec (Lines);
        End;
      End;

      AssignHeaderInfo;

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
            'F' : Begin
                    MoveMessage(True);
                    Break;
                  End;
            'G' : Begin
                    Ansi_View_Message := True;
                    Exit;
                  End;
            'H' : Begin
                    LastRead := CurMsg - 1;

                    Session.io.PromptInfo[1] := strI2S(LastRead);

                    Session.io.OutFullLn(Session.GetPrompt(504));

                    Break;
                  End;
            'I' : Begin
                    LastRead  := MsgBase^.GetHighMsgNum;
                    Result    := True;

                    RemoveNewScan(495);

                    Exit;
                  End;
            'J' : Begin
                    Session.io.PromptInfo[1] := strI2S(CurMsg);
                    Session.io.PromptInfo[2] := strI2S(MsgBase^.GetHighMsgNum);

                    Session.io.OutFull (Session.GetPrompt(403));

                    If Session.io.OneKeyRange(#13 + 'Q', 1, MsgBase^.GetHighMsgNum) = #0 Then Begin
                      MsgBase^.SeekFirst(Session.io.RangeValue);

                      If Not SeekNextMsg(True, False) Then Begin
                        MsgBase^.SeekFirst(CurMsg);
                        SeekNextMsg(True, False);
                      End;
                    End;

                    Break;
                  End;
            'L' : Exit;
            'M' : Begin
                    If MoveMessage(False) Then
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
                    ExportMessage;

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
    AskRemove : Boolean;

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
              Session.io.PromptInfo[5] := Session.Theme.NewMsgChar
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
        Session.io.PromptInfo[5] := Session.Theme.NewMsgChar
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
    AskRemove := False;

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
                    LastRead  := MsgBase^.GetHighMsgNum;
                    AskRemove := True;

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

      If AskRemove Then
        RemoveNewScan(495);
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
        Session.io.OutFullLn ('|03To   : |10|$R40|&2 |03Date     : |11|&4 |&0');
        Session.io.OutFullLn ('|03Subj : |12|$R40|&3 |03Refer to : |10|&7');
        Session.io.OutFullLn ('|03Stat : |13|$R40|&9 |03See Also : |12|&8');

(*
        Session.io.OutFullLn ('|03To   : |10|$R40|&2 |03Refer to : |10|&7');
        Session.io.OutFullLn ('|03Subj : |12|$R40|&3 |03See Also : |12|&8');
        Session.io.OutFullLn ('|03Stat : |13|$R40|&9 |03Date     : |11|&4 |&0');
*)
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

      If Session.User.IsThisUser(MsgBase^.GetTo) And Not MsgBase^.IsRcvd Then Begin
        MsgBase^.SetRcvd(True);
        MsgBase^.ReWriteHDR;
      End;

      SetMessageSecurity;
      AssignHeaderInfo;
      Display_Header;

      MsgBase^.MsgTxtStartUp;

      WereMsgs              := True;
      Session.io.AllowPause := True;

      While Not MsgBase^.EOM Do Begin
        Str := MsgBase^.GetString(79);

        If Str[1] = #1 Then Begin
          If Copy(Str, 2, 5) = 'MSGID' Then
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

        Str := Session.io.OneKeyRange(ValidKeys, 1, MsgBase^.GetHighMsgNum);

        Case Str[1] of
          #00 : Begin
                  B := MsgBase^.GetMsgNum;

                  MsgBase^.SeekFirst(Session.io.RangeValue);

                  If Not SeekNextMsg(True, False) Then Begin
                    MsgBase^.SeekFirst(B);
                    SeekNextMsg(True, False);
                  End;

                  Break;
                End;
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
          'F' : Begin
                  MoveMessage(True);
                  Break;
                End;
          'G' : Exit;
          'H' : Begin
                  LastRead := MsgBase^.GetMsgNum - 1;

                  Session.io.PromptInfo[1] := strI2S(LastRead);

                  Session.io.OutFullLn(Session.GetPrompt(505));

                  Break;
                End;
          'I' : Begin
                  LastRead := MsgBase^.GetHighMsgNum;

                  RemoveNewScan(494);

                  Exit;
                 End;
          'J' : Begin
                  B := MsgBase^.GetMsgNum;

                  Session.io.OutFull (Session.GetPrompt(334));

                  If Session.io.OneKeyRange(#13 + 'Q', 1, MsgBase^.GetHighMsgNum) = #0 Then Begin
                    MsgBase^.SeekFirst(Session.io.RangeValue);

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
                  A                     := MsgBase^.GetMsgNum;

                  Session.io.OutFullLn(Session.GetPrompt(411));

                  While SeekNextMsg(False, False) Do Begin
                    AssignHeaderInfo;

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

                  Session.io.PromptInfo[1]  := strI2S(MsgBase^.GetMsgNum);
                  Session.io.PromptInfo[2]  := strI2S(MsgBase^.GetHighMsgNum);
                End;
          'M' : Begin
                  If MoveMessage(False) Then
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
          'X' : ExportMessage;
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
  MsgNum     : LongInt;
  NoLastRead : Boolean;
Begin
  ReadMessages := True;
  ReadRes      := True;
  WereMsgs     := False;
  ReplyID      := '';
  NoLastRead   := Pos('/NOLR', strUpper(CmdData)) > 0;
  NoFrom       := Pos('/NOFROM', strUpper(CmdData)) > 0;
  NoRead       := Pos('/NOREAD', strUpper(CmdData)) > 0;

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

    Mode := Session.io.OneKey(#13 + 'BFNSYQ', True);
  End;

  Case Mode of
    #13 : Mode := 'F';
    'Q' : Exit;
    'S' : If SearchStr = '' Then Begin
            Session.io.OutFull (Session.GetPrompt(396));

            SearchStr := Session.io.GetInput(50, 50, 12, '');

            If SearchStr = '' Then Exit;
          End;
  End;

{ start here opencreate... }

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgbaseSquish, Init);
  End;

  MsgBase^.SetMsgPath  (MBase.Path + MBase.FileName);
  MsgBase^.SetTempFile (Session.TempPath + 'msgbuf.');

  If Not MsgBase^.OpenMsgBase Then Begin
    If Mode = 'E' Then
      Session.io.OutFullLn (Session.GetPrompt(124))
    Else
      If Not (Mode in ['G', 'P', 'T']) Then Session.io.OutFullLn (Session.GetPrompt(114));

    Dispose (MsgBase, Done);

    Exit;
  End;

  {end here }

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

    If Session.io.PromptInfo[1] = '0' Then Begin
      Session.io.OutFullLn(Session.GetPrompt(114));

      MsgBase^.CloseMsgBase;
      Dispose (MsgBase, Done);

      Exit;
    End;

    Session.io.OutFull (Session.GetPrompt(338));

    Session.io.OneKeyRange(#13, 1, MsgBase^.GetHighMsgNum);

    MsgNum := Session.io.RangeValue;
  End;

  Set_Node_Action (Session.GetPrompt(348));

  If Mode in ['B', 'S', 'T', 'Y', 'E', 'F'] Then
    MsgBase^.SeekFirst(MsgNum)
  Else
    MsgBase^.SeekFirst(LastRead + 1);

  SetMessageSecurity;

  Reading := True;

  If (Session.User.ThisUser.MReadType = 1) and (Session.io.Graphics > 0) Then Begin
    ListMode := 1;
    Ansi_Read_Messages;
  End Else Begin
    ListMode := 0;
    Ascii_Read_Messages;
  End;

  If Not (Mode in ['E', 'S', 'T']) And Not NoLastRead Then
    MsgBase^.SetLastRead (Session.User.UserNum, LastRead);

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
  MsgTo      : String[30];
  MsgSubj    : String[60];
  MsgAddr    : String[20];
  TempStr    : String;
  DestAddr   : RecEchoMailAddr;
  A          : Integer;
  Lines      : Integer;
  Forced     : Boolean;
  Old        : RecMessageBase;
  SaveGroup  : Boolean;
  IsPrivate  : Boolean;
Begin
  Old       := MBase;
  SaveGroup := Session.User.IgnoreGroup;

  If Email Then Begin
    Reset (MBaseFile);
    Read  (MBaseFile, MBase);
    Close (MBaseFile);

    Session.User.IgnoreGroup := True;
  End;

  If MBase.FileName = '' Then Begin
    Session.io.OutFullLn (Session.GetPrompt(110));

    MBase                    := Old;
    Session.User.IgnoreGroup := SaveGroup;

    Exit;
  End;

  If Not Session.User.Access(MBase.PostACS) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(105));

    MBase                    := Old;
    Session.User.IgnoreGroup := SaveGroup;

    Exit;
  End;

  Set_Node_Action (Session.GetPrompt(349));

  MsgTo     := '';
  MsgSubj   := '';
  MsgAddr   := '';
  Forced    := False;
  IsPrivate := MBase.Flags AND MBPrivate <> 0;

  If (MBase.Flags AND MBPrivate = 0) AND (MBase.Flags AND MBPrivReply <> 0) Then
    IsPrivate := Session.io.GetYN(Session.GetPrompt(513), False);

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
    If Pos('/ADDR:', strUpper(TempStr)) > 0 Then Begin
      MsgAddr := strReplace(Copy(TempStr, Pos('/ADDR:', strUpper(TempStr)) + 6, Length(TempStr)), '_', ' ');

      If Not strStr2Addr(MsgAddr, DestAddr) Then MsgAddr := '';
    End;
  End;

  If MBase.NetType = 2 Then           { UseNet Base: To = "All" }
    MsgTo := 'All'
  Else
  If MBase.NetType = 3 Then Begin     { NetMail Base: Get To *and* Address }
    If MsgTo = '' Then Begin
      Session.io.OutFull (Session.GetPrompt(119));

      MsgTo := Session.io.GetInput (30, 30, 18, '');
    End;

    If MsgTo <> '' Then
      If MsgAddr = '' Then Begin
        MsgAddr := NetmailLookup(False, MsgTo, '');

        If Not strStr2Addr(MsgAddr, DestAddr) Then MsgTo := '';
      End;
  End Else
  If IsPrivate Then Begin
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
    MBase                    := Old;
    Session.User.IgnoreGroup := SaveGroup;

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
          MBase                    := Old;
          Session.User.IgnoreGroup := SaveGroup;

          Exit;
        End;
    Until MsgSubj <> '';

  Lines := 0;

  Session.io.PromptInfo[1] := MsgTo;
//  Session.io.PromptInfo[2] := MsgSubj;

  If Editor(Lines, ColumnValue[Session.Theme.ColumnSize] - 2, mysMaxMsgLines, Forced, fn_tplMsgEdit, MsgSubj) Then Begin
    Session.io.OutFull (Session.GetPrompt(107));

    { all of this below should be replaced with a SaveMessage function   }
    { the same should be used for Replying and also for TextFile post    }
    { and then the automated e-mails can be added where mystic will send }
    { notifications out to the sysop for various things (configurable)   }
    { also could be used in mass email rewrite and qwk .REP rewrite      }

    If Not OpenCreateBase(MsgBase, MBase) Then Begin
      MBase                    := Old;
      Session.User.IgnoreGroup := SaveGroup;

      Exit;
    End;

    AssignMessageData(MsgBase, MBase);

    MsgBase^.SetTo   (MsgTo);
    MsgBase^.SetSubj (MsgSubj);
    MsgBase^.SetPriv (IsPrivate);

    If MBase.NetType = 3 Then Begin
      MsgBase^.SetDest     (DestAddr);
      MsgBase^.SetCrash    (Config.netCrash);
      MsgBase^.SetHold     (Config.netHold);
      MsgBase^.SetKillSent (Config.netKillSent);
      MsgBase^.SetOrig     (GetMatchedAddress(Config.NetAddress[MBase.NetAddr], DestAddr));
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

  MBase                    := Old;
  Session.User.IgnoreGroup := SaveGroup;
End;

Procedure TMsgBase.CheckEMail (CmdData: String);
Var
  MsgBase  : PMsgBaseABS;
  TempBase : RecMessageBase;
  Total    : Integer;
  UnRead   : Integer;
Begin
  TempBase := MBase;
  Total    := 0;
  UnRead   := 0;
  FileMode := 66;

  Session.io.OutFull (Session.GetPrompt(123));
  Session.io.BufFlush;

  Reset (MBaseFile);
  Read  (MBaseFile, MBase);
  Close (MBaseFile);

  If Pos('/NOLIST', strUpper(CmdData)) > 0 Then Begin
      ReadMessages('E', '', '');

      Session.io.OutFullLn (Session.GetPrompt(118));

      MBase := TempBase;

      Exit;
  End;

  If OpenCreateBase (MsgBase, MBase) Then Begin
    MsgBase^.SeekFirst (1);

    While MsgBase^.SeekFound Do Begin
      MsgBase^.MsgStartUp;

      If Session.User.IsThisUser(MsgBase^.GetTo) Then Begin
        Inc (Total);

        If Not MsgBase^.IsRcvd Then Inc (UnRead);

        If Total = 1 Then
          Session.io.OutFullLn (Session.GetPrompt(125));

        Session.io.PromptInfo[1] := strI2S(Total);
        Session.io.PromptInfo[2] := MsgBase^.GetFrom;
        Session.io.PromptInfo[3] := MsgBase^.GetSubj;
        Session.io.PromptInfo[4] := MsgBase^.GetDate;

        Session.io.OutFullLn (Session.GetPrompt(126));
      End;

      MsgBase^.SeekNext;
    End;

    MsgBase^.CloseMsgBase;

    Dispose (MsgBase, Done);
  End;

  Session.LastScanHadNew := UnRead > 0;

  If Total = 0 Then
    Session.io.OutFullLn (Session.GetPrompt(124))
  Else Begin
    Session.io.PromptInfo[1] := strI2S(Total);
    Session.io.PromptInfo[2] := strI2S(UnRead);

    If Session.io.GetYN (Session.GetPrompt(127), UnRead > 0) Then Begin
      ReadMessages('E', '', '');

      Session.io.OutFullLn (Session.GetPrompt(118));
    End;
  End;

  MBase := TempBase;
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

      MsgBase^.CloseMsgBase;
    End;

    Dispose (MsgBase, Done);
  End;

Var
  Global : Boolean;
  InDate : String[8];
Begin
  Session.io.OutFull (Session.GetPrompt(458));

  InDate := Session.io.GetInput(8, 8, 15, DateDos2Str(CurDateDos, Session.User.ThisUser.DateType));

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

Procedure TMsgBase.MessageNewScan (Data: String);
{ menu data commands: }
{    /P : scan for personal mail in all bases }
{    /M : scan only mandatory bases           }
{    /G : scan all bases in all groups        }
Var
  Old     : RecMessageBase;
  Mode    : Char;
  Mand    : Boolean;
  CmdData : String;
Begin
  Old      := MBase;
  Mand     := False;
  FileMode := 66;

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
  WereMsgs                 := False;

  CmdData := '';

  If Pos('/NOLR', Data) > 0   Then CmdData := '/NOLR';
  If Pos('/NOFROM', Data) > 0 Then CmdData := CmdData + '/NOFROM';
  If Pos('/NOREAD', Data) > 0 Then CmdData := CmdData + '/NOREAD';

  Session.io.OutRawLn ('');

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      GetMessageScan;

      If ((Mand) and (MBase.DefNScan = 2)) or ((Not Mand) and (MScan.NewScan > 0)) Then Begin
        Session.io.OutBS   (Screen.CursorX, True);
        Session.io.OutFull (Session.GetPrompt(130));
        Session.io.BufFlush;

        If Not ReadMessages(Mode, CmdData, '') Then Begin
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
  MBase                    := OLD;
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
    ReadMessages('S', '', SearchStr)
  Else Begin
    Session.io.OutRawLn ('');

    Reset (MBaseFile);
    Read  (MBaseFile, MBase);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      If Session.User.Access(MBase.ReadACS) Then Begin
        GetMessageScan;

        If MScan.NewScan > 0 Then Begin
          If Not ReadMessages('T', '', SearchStr) Then Begin
            Session.io.OutRawLn('');
            Break;
          End;

          If WereMsgs Then Session.io.OutRawLn('');
        End;
      End;
    End;

    Session.io.OutFull (Session.GetPrompt(311));

    Close (MBaseFile);
  End;

  Session.User.IgnoreGroup := False;
  MBase                    := OLD;
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

    AssignMessageData (MsgBase, MBase);

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
              Read (Session.User.UserFile, Session.User.ThisUser);

              If (Session.User.ThisUser.Flags AND UserDeleted = 0) and Session.User.Access(ACS) Then Begin
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

  If Editor(Lines, ColumnValue[Session.Theme.ColumnSize] - 2, mysMaxMsgLines, False, fn_tplMsgEdit, MsgSubj) Then Begin
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

  ReadMessages('B', '', '');

  MBase := Old;
End;

Procedure TMsgBase.MessageQuickScan (Data: String);
// Defaults to ALL groups/bases
//   /CURRENT = scan only current message base
//   /GROUP   = scan only current group bases
// other options:
//   /LIST   = List messages
//   /NEW    = only show/list if base has new or msg is new
//   /YOU    = only show/list if base has your msgs or is your msg
//   /NOFOOT = dont show footer prompt
//   /NOSCAN = do not show "scanning" prompt
//   /NOFROM = bypass messages posted FROM the user
//   /NOREAD = bypass messages addressed to, and read by, the user
Var
  Aborted           : Boolean;
  NoFrom            : Boolean;
  NoRead            : Boolean;
  ShowIfNew         : Boolean;
  ShowIfYou         : Boolean;
  ShowScanPrompt    : Boolean;
  ShowFootPrompt    : Boolean;
  ShowMessage       : Boolean;
  ShowMessagePTR    : LongInt;
  Global_CurBase    : LongInt;
  Global_TotalBases : LongInt;
  Global_TotalMsgs  : LongInt;
  Global_NewMsgs    : LongInt;
  Global_YourMsgs   : LongInt;
  Mode              : Char;

  Procedure ScanBase;
  Var
    NewMsgs   : LongInt;
    YourMsgs  : LongInt;
    TotalMsgs : LongInt;
    Res       : Boolean;
  Begin
    Session.io.PromptInfo[1]  := MBase.Name;
    Session.io.PromptInfo[2]  := strI2S(Global_CurBase);
    Session.io.PromptInfo[3]  := strI2S(Global_TotalBases);

    NewMsgs   := 0;
    YourMsgs  := 0;
    TotalMsgs := 0;

    If ShowScanPrompt Then Begin
      Session.io.OutFull(Session.GetPrompt(487));

      Session.io.BufFlush;
    End;

    Aborted := GetMessageStats(ShowMessage, ShowScanPrompt, ShowIfYou, ShowMessagePTR, MBase, NoFrom, NoRead, TotalMsgs, NewMsgs, YourMsgs);

    If ShowMessage And Aborted Then Exit;

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

      If Not ShowMessage Then
    If (ShowIfNew And (NewMsgs > 0)) or (ShowIfYou And (YourMsgs > 0)) or (Not ShowIfNew And Not ShowIfYou) Then Begin
      Session.io.OutFullLn(Session.GetPrompt(488));
      Session.io.BufFlush;
    End;
  End;

Var
  Old : RecMessageBase;
Begin
  Session.io.AllowPause  := True;
  Session.io.PausePtr    := 1;
  Session.LastScanHadNew := False;
  Session.LastScanHadYou := False;

  Global_CurBase    := 1;
  Global_TotalBases := 1;
  Global_TotalMsgs  := 0;
  Global_NewMsgs    := 0;
  Global_YourMsgs   := 0;
  ShowMessagePTR    := 0;
  Mode              := 'A';

  FillChar(Session.io.PromptInfo, SizeOf(Session.io.PromptInfo), 0);

  If Pos('/GROUP',   Data) > 0 Then Mode := 'G';
  If Pos('/CURRENT', Data) > 0 Then Mode := 'C';

  ShowMessage    := Pos('/LIST',   Data) > 0;
  ShowFootPrompt := Pos('/NOFOOT', Data) = 0;
  ShowScanPrompt := Pos('/NOSCAN', Data) = 0;
  ShowIfNew      := Pos('/NEW',    Data) > 0;
  ShowIfYou      := Pos('/YOU',    Data) > 0;
  NoFrom         := Pos('/NOFROM', Data) > 0;
  NoRead         := Pos('/NOREAD', Data) > 0;

  Old                      := MBase;
  Session.User.IgnoreGroup := Mode = 'A';

  FileMode := 66;

  If Mode = 'C' Then
    ScanBase
  Else Begin
    Reset (MBaseFile);

    Global_TotalBases := FileSize(MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, MBase);

      Global_CurBase := FilePos(MBaseFile);

      If Session.User.Access(MBase.ReadACS) Then Begin
        GetMessageScan;

        If MScan.NewScan > 0 Then ScanBase;

        If ShowMessage And Aborted Then Break;
      End;
    End;

    Close (MBaseFile);
  End;

  Session.LastScanHadNew := Global_NewMsgs  > 0;
  Session.LastScanHadYou := Global_YourMsgs > 0;

  Session.io.PromptInfo[1] := strComma(Global_TotalMsgs);
  Session.io.PromptInfo[2] := strComma(Global_NewMsgs);
  Session.io.PromptInfo[3] := strComma(Global_YourMsgs);

  If ShowMessagePTR > 0 Then
    Session.io.OutFull(Session.GetPrompt(508));

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
    If mArea.NetType = 3 Then Begin
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
  Msg^.SetTime (TimeDos2Str(CurDateDos, 0));
  Msg^.SetFrom (mFrom);
  Msg^.SetTo   (mTo);
  Msg^.SetSubj (mSubj);

  For Count := 1 to mLines Do
    Msg^.DoStringLn(MsgText[Count]);

  If mArea.NetType > 0 Then Begin
    Msg^.DoStringLn (#13 + '--- ' + mysSoftwareID + ' v' + mysVersion + ' (' + OSID + ')');
    Msg^.DoStringLn (' * Origin: ' + ResolveOrigin(mArea) + ' (' + strAddr2Str(Msg^.GetOrigAddr) + ')');
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
  Loc    := Pos('@RANDOM=', strUpper(mArea.Origin));

  If Loc > 0 Then Begin
    FN := strStripB(Copy(mArea.Origin, Loc + 8, 255), ' ');

    If Pos(PathChar, FN) = 0 Then FN := Config.DataPath + FN;

    FileMode := 66;

    Assign     (TF, FN);
    SetTextBuf (TF, Buf, SizeOf(Buf));

    {$I-} Reset (TF); {$I+}

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

// ==========================================================================
// QWK/QWKE OPTIONS
// ==========================================================================

Procedure TMsgBase.WriteDOORID (Extended: Boolean);
Const
  CRLF = #13#10;
Var
  tFile : Text;
Begin
  Assign  (tFile, Session.TempPath + 'door.id');
  ReWrite (tFile);

  Write (tFile, 'DOOR = ' + mysSoftwareID + CRLF);
  Write (tFile, 'VERSION = ' + mysVersion + CRLF);
  Write (tFile, 'SYSTEM = ' + mysSoftwareID + ' ' + mysVersion + CRLF);
  Write (tFile, 'CONTROLNAME = ' + qwkControlName + CRLF);
  Write (tFile, 'CONTROLTYPE = ADD' + CRLF);
  Write (tFile, 'CONTROLTYPE = DROP' + CRLF);

  Close (tFile);
End;

Procedure TMsgBase.WriteTOREADEREXT;
Const
  CRLF = #13#10;
Var
  tFile : Text;
  Flags : String;
Begin
  Assign  (tFile, Session.TempPath + 'toreader.ext');
  ReWrite (tFile);
  Write   (tFile, 'ALIAS ' + Session.User.ThisUser.Handle + CRLF);

  Reset (MBaseFile);

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      Flags := ' ';

      If MBase.Flags AND MBPrivate = 0 Then
        Flags := Flags + 'aO'
      Else
        Flags := Flags + 'pP';

      If MBase.Flags AND MBRealNames = 0 Then
        Flags := Flags + 'H';

      If Not Session.User.Access(MBase.PostACS) Then
        Flags := Flags + 'BRZ';

      Case MBase.NetType of
        0 : Flags := Flags + 'L';
        1 : Flags := Flags + 'E';
        2 : Flags := Flags + 'U';
        3 : Flags := Flags + 'N';
      End;

      If MBase.DefQScan = 2 Then
        Flags := Flags + 'F';

      Write (tFile, 'AREA ' + strI2S(MBase.Index) + Flags, CRLF);
    End;
  End;

  Close (tFile);
End;

Procedure TMsgBase.WriteCONTROLDAT (Extended: Boolean);
Const
  CRLF = #13#10; { for eventually having option for linux OR dos text files }
Var
  tFile : Text;
Begin
  Assign  (tFile, Session.TempPath + 'control.dat');
  ReWrite (tFile);

  Write (tFile, Config.BBSName + CRLF);
  Write (tFile, CRLF);
  Write (tFile, CRLF);
  Write (tFile, Config.SysopName + CRLF);
  Write (tFile, '0,' + Config.qwkBBSID + CRLF);
  Write (tFile, DateDos2Str(CurDateDos, 1), ',', TimeDos2Str(CurDateDos, 0) + CRLF);
  Write (tFile, strUpper(Session.User.ThisUser.Handle) + CRLF);
  Write (tFile, CRLF);
  Write (tFile, '0' + CRLF);
  Write (tFile, TotalMsgs, CRLF); {TOTAL MSG IN PACKET}
  Write (tFile, TotalConf - 1, CRLF); {TOTAL CONF - 1}

  Reset (MBaseFile);

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If Session.User.Access(MBase.ReadACS) Then Begin
      Write (tFile, MBase.Index, CRLF); {conf #}

      If Extended Then
        Write (tFile, strStripMCI(MBase.Name) + CRLF)
      Else
        Write (tFile, MBase.QwkName + CRLF);
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
    If ((Config.QwkMaxBase > 0) and (MsgAdded = Config.QwkMaxBase)) or
    ((Config.QwkMaxPacket > 0) and (TotalMsgs = Config.QwkMaxPacket)) Then Break;

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

    Temp := Config.qwkBBSID + '.qwk';

    Session.io.OutFullLn (Session.GetPrompt(234));

    Session.io.PromptInfo[1] := Temp;

    If FileExist(Config.QwkWelcome) Then FileCopy(Config.qwkWelcome, Session.TempPath + JustFile(Config.qwkWelcome));
    If FileExist(Config.QwkNews)    Then FileCopy(Config.qwkNews,    Session.TempPath + JustFile(Config.qwkNews));
    If FileExist(Config.QwkGoodbye) Then FileCopy(Config.qwkGoodbye, Session.TempPath + JustFile(Config.qwkGoodbye));

//    Session.SystemLog('DEBUG: Archiving QWK packet');

    If Session.LocalMode Then Begin
      FileErase (Config.QWKPath + Temp);

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
    Session.FileBase.ExecuteArchive (Config.QWKPath + Config.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  Else Begin
    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, Session.TempPath + Config.qwkBBSID + '.rep');

    If Not Session.FileBase.DszSearch(Config.qwkBBSID + '.rep') Then Begin
      Session.io.PromptInfo[1] := Config.qwkBBSID + '.rep';

      Session.io.OutFullLn (Session.GetPrompt(84));

      Exit;
    End;

    Session.FileBase.ExecuteArchive (Session.TempPath + Config.qwkBBSID + '.rep', Session.User.ThisUser.Archive, '*', 2)
  End;

  Assign (DataFile, FileFind(Session.TempPath + Config.qwkBBSID + '.msg'));

  If Not ioReset(DataFile, 1, fmRWDN) Then Begin
    Session.io.OutFull (Session.GetPrompt(238));
    DirClean (Session.TempPath, '');
    Exit;
  End;

  BlockRead (DataFile, QwkBlock[1], 128);
  QwkBlock[0] := #128;

  If Pos(strUpper(Config.qwkBBSID), strUpper(QwkBlock)) = 0 Then Begin
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
    Function    ProcessReplies : Boolean;
    Destructor  Destroy; Override;
  End;

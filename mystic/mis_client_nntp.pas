Unit MIS_Client_NNTP;

{$I M_OPS.PAS}

// RFC 977

Interface

Uses
  SysUtils,
  m_Strings,
  m_FileIO,
  m_Socket_Class,
  m_DateTime,
  MIS_Server,
  MIS_NodeData,
  MIS_Common;

Function CreateNNTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Type
  TNNTPServer = Class(TServerClient)
    Server     : TServerManager;
    UserName   : String[30];
    LoggedIn   : Boolean;
    Cmd        : String;
    Data       : String;
    User       : RecUser;
    UserPos    : LongInt;
    MBase      : RecMessageBase;
    MBasePos   : LongInt;
    CurArticle : LongInt;
    EndSession : Boolean;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ClientWriteLine (Str: String);
    Procedure   ResetSession;

    Procedure   cmd_ARTICLE;
    Procedure   cmd_AUTHINFO;
    Procedure   cmd_GROUP;
    Procedure   cmd_LIST;
    Procedure   cmd_POST;
    Procedure   cmd_XOVER;
  End;

Implementation

Uses
  Classes,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

Const
  FileReadBuffer   = 2048;
  HackThreshold    = 10000;

  re_Greeting      = '200 Mystic BBS NNTP server ready';
  re_Goodbye       = '205 Goodbye';
  re_ListFollows   = '215 List follows';
  re_AuthOK        = '281 Authentication accepted';
  re_AuthBad       = '381 Authentication rejected';
  re_AuthPass      = '381 Password required';
  re_AuthReq       = '450 Auth required';
  re_AuthSync      = '482 Bad Authentication sequence';
  re_Unknown       = '500 Unknown command';
  re_UnknownOption = '501 Unknown option';

Function CreateNNTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TNNTPServer.Create(Owner, CliSock);
End;

Constructor TNNTPServer.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

Procedure TNNTPServer.ClientWriteLine (Str: String);
Begin
  Server.Server.Status('S:' + Str);
  Client.WriteLine(Str);
End;

Procedure TNNTPServer.ResetSession;
Begin
  LoggedIn   := False;
  UserName   := '';
  UserPos    := -1;
  MBasePos   := -1;
  CurArticle := 0;
  EndSession := False;
End;

Procedure TNNTPServer.cmd_AUTHINFO;
Var
  NewCmd  : String;
  NewData : String;
Begin
  NewCmd  := strWordGet(1, Data, ' ');
  NewData := Copy(Data, Pos(' ', Data) + 1, 255);

  If NewCmd = 'USER' Then Begin
    If SearchForUser(NewData, User, UserPos) Then Begin
      ClientWriteLine(re_AuthPass);

      UserName := NewData;
    End Else
      ClientWriteLine(re_AuthBad);
  End Else
  If NewCmd = 'PASS' Then Begin
    If UserPos = -1 Then
      ClientWriteLine(re_AuthSync)
    Else
    If strUpper(NewData) = User.Password Then Begin
      ClientWriteLine(re_AuthOK);
      LoggedIn := True;
    End Else
      ClientWriteLine(re_AuthBad);
  End Else
    ClientWriteLine(re_UnknownOption);

  If LoggedIn Then
    Server.Server.Status('Logged in as ' + UserName);
End;

Procedure TNNTPServer.cmd_GROUP;
Var
  MBaseFile : TBufFile;
  TempBase  : RecMessageBase;
  MsgBase   : PMsgBaseABS;
  Active    : LongInt = 0;
  Low       : LongInt = 0;
  High      : LongInt = 0;
  Found     : Boolean = False;
Begin
  If Not LoggedIn Then Begin
    ClientWriteLine(re_AuthReq);
    Exit;
  End;

  MBaseFile := TBufFile.Create(FileReadBuffer);

  If MBaseFile.Open(bbsConfig.DataPath + 'mbases.dat', fmOpen, fmRWDN, SizeOf(RecMessageBase)) Then Begin
    MBaseFile.Read(TempBase);

    While Not MBaseFile.EOF Do Begin
      MBaseFile.Read(TempBase);

      If (TempBase.NewsName = Data) and CheckAccess(User, True, TempBase.ReadACS) Then Begin
        Found := True;

        Case TempBase.BaseType of
          0 : MsgBase := New(PMsgBaseJAM, Init);
          1 : MsgBase := New(PMsgBaseSquish, Init);
        End;

        MsgBase^.SetMsgPath (TempBase.Path + TempBase.FileName);

        If MsgBase^.OpenMsgBase Then Begin
          Low    := 1;
          High   := MsgBase^.GetHighMsgNum;
          Active := MsgBase^.NumberOfMsgs;
        End;

        Dispose (MsgBase, Done);

        MBase      := TempBase;
        MBasePos   := MBaseFile.FilePos;
        CurArticle := 0;  // does GROUP reset cur article?  find out

        ClientWriteLine('211 ' + strI2S(Active) + ' ' + strI2S(Low) + ' ' + strI2S(High) + ' ' + TempBase.NewsName);

        Break;
      End;
    End;
  End;

  MBaseFile.Free;

  If Not Found Then
    ClientWriteLine('411 No such newsgroup');
End;

Procedure TNNTPServer.cmd_LIST;
Var
  MBaseFile   : TBufFile;
  TempBase    : RecMessageBase;
  MsgBase     : PMsgBaseABS;
  LowMessage  : LongInt;
  HighMessage : LongInt;
  PostAbility : Char;
Begin
  If Not LoggedIn Then Begin
    ClientWriteLine(re_AuthReq);
    Exit;
  End;

  ClientWriteLine(re_ListFollows);

  If Data = 'OVERVIEW.FMT' Then Begin
    ClientWriteLine ('Subject:');
    ClientWriteLine ('From:');
    ClientWriteLine ('Date:');
    ClientWriteLine ('Message-ID:');
    ClientWriteLine ('References:');
    ClientWriteLine ('Bytes:');
    ClientWriteLine ('Lines:');
    ClientWriteLine ('.');
    // find this in RFC to make sure this website isnt wrong
    Exit;
  End;

  MBaseFile := TBufFile.Create(FileReadBuffer);

  If MBaseFile.Open(bbsConfig.DataPath + 'mbases.dat', fmOpen, fmRWDN, SizeOf(RecMessageBase)) Then Begin
    MBaseFile.Read(TempBase);

    While Not MBaseFile.EOF Do Begin
      MBaseFile.Read(TempBase);

      If TempBase.NewsName = '' Then Continue;

      If CheckAccess(User, True, TempBase.ListACS) Then Begin
        LowMessage  := 0;
        HighMessage := 0;

        Case CheckAccess(User, True, TempBase.PostACS) of
          False : PostAbility := 'n';
          True  : PostAbility := 'y';
        End;

        Case TempBase.BaseType of
          0 : MsgBase := New(PMsgBaseJAM, Init);
          1 : MsgBase := New(PMsgBaseSquish, Init);
        End;

        MsgBase^.SetMsgPath (TempBase.Path + TempBase.FileName);

        If MsgBase^.OpenMsgBase Then Begin
          LowMessage  := 1;
          HighMessage := MsgBase^.GetHighActiveMsgNum;
        End;

        Dispose (MsgBase, Done);

        ClientWriteLine (TempBase.NewsName + ' ' + strI2S(LowMessage) + ' ' + strI2S(HighMessage) + ' ' + PostAbility);
      End;
    End;
  End;

  MBaseFile.Free;

  ClientWriteLine('.');
End;

Procedure TNNTPServer.cmd_POST;
Var
  MsgBase   : PMsgBaseABS;
  MBaseFile : TBufFile;
  TempBase  : RecMessageBase;
  MsgText   : TStringList;
  Subject   : String;
  Newsgroup : String;
  InData    : String;
  HackCount : LongInt;
  Count     : LongInt;
  GotStart  : Boolean;
  Found     : Boolean;
  SemFile   : File;
Begin
  If Not LoggedIn Then Begin
    ClientWriteLine(re_AuthReq);
    Exit;
  End;

  ClientWriteLine('340 Send article to be posted.  End with <CRLF>.<CRLF>');

  Subject   := '';
  Newsgroup := '';
  GotStart  := False;
  MsgText   := TStringList.Create;

  Repeat
    Client.ReadLine(InData);

    If InData = '.' Then Break;

    If Not GotStart And (Pos('Newsgroups:', InData) > 0) Then Begin
      Newsgroup := Copy(InData, 13, 255);

      Continue;
    End;

    If Not GotStart And (Pos('Subject:', InData) > 0) Then Begin
      Subject := Copy(InData, 10, 255);

      Continue;
    End;

    If (InData = '') And Not GotStart Then Begin
      GotStart := True;
      Continue;
    End;

    If MsgText.Count >= mysMaxMsgLines Then Begin
      HackCount := 0;

      While Not Terminated And (InData <> '.') Do Begin
        Client.ReadLine(InData);

        Inc (HackCount);

        If HackCount >= HackThreshold Then Begin
          EndSession := True;   // someone is being a douchebag

          Server.Server.Status('Flood attempt from ' + Client.PeerIP + '. Goodbye');

          MsgText.Free;

          Exit;
        End;
      End;

      Break;
    End;

    If GotStart Then MsgText.Add(InData);
  Until Terminated;

  If Terminated Then Exit;

  If (Subject = '') Then Begin
    MsgText.Free;

    ClientWriteLine('441 No subject; message not posted');

    Exit;
  End;

  Found     := False;
  MBaseFile := TBufFile.Create(FileReadBuffer);

  If MBaseFile.Open(bbsConfig.DataPath + 'mbases.dat', fmOpen, fmRWDN, SizeOf(RecMessageBase)) Then Begin
    MBaseFile.Read(TempBase);

    While Not MBaseFile.EOF Do Begin
      MBaseFile.Read(TempBase);

      If TempBase.NewsName = Newsgroup Then Begin
        Found := True;

        Break;
      End;
    End;
  End;

  MBaseFile.Free;

  If Not Found or (Newsgroup = '') Then Begin
    MsgText.Free;

    ClientWriteLine('441 No newsgroup selected');

    Exit;
  End;

  If Not CheckAccess(User, True, TempBase.PostACS) or (TempBase.NetType = 3) Then Begin
    MsgText.Free;

    ClientWriteLine('441 No post access');

    Exit;
  End;

  Case TempBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (TempBase.Path + TempBase.FileName);

  If Not MsgBase^.OpenMsgBase Then
    If Not MsgBase^.CreateMsgBase (TempBase.MaxMsgs, TempBase.MaxAge) Then Begin
      Dispose(MsgBase, Done);
      MsgText.Free;
      Client.WriteLine('441 Cannot save');
      Exit;
    End Else
      If Not MsgBase^.OpenMsgBase Then Begin
        Dispose(MsgBase, Done);
        MsgText.Free;
        Client.WriteLine('411 Cannot save');
        Exit;
      End;

  MsgBase^.StartNewMsg;

  MsgBase^.SetLocal (True);
  MsgBase^.SetDate  (FormatDateTime('mm/dd/yy', Now));
  MsgBase^.SetTime  (FormatDateTime('hh:nn', Now));
  MsgBase^.SetTo    ('All');
  MsgBase^.SetSubj  (Subject);

  If TempBase.Flags And MBRealNames <> 0 Then
    MsgBase^.SetFrom(User.RealName)
  Else
    MsgBase^.SetFrom(User.Handle);

  If TempBase.NetType > 0 Then Begin
    MsgBase^.SetMailType(mmtEchoMail);

    Case TempBase.NetType of
      1 : Assign (SemFile, bbsConfig.SemaPath + fn_SemFileEcho);
      2 : Assign (SemFile, bbsConfig.SemaPath + fn_SemFileNews);
    End;

    ReWrite (SemFile);
    Close   (SemFile);
  End Else
    MsgBase^.SetMailType(mmtNormal);

  MsgBase^.SetPriv (TempBase.Flags and MBPrivate <> 0);

  For Count := 1 to MsgText.Count Do Begin
    InData := MsgText.Strings[Count - 1];

    If Length(InData) > 79 Then InData[0] := #79;

    MsgBase^.DoStringLn(InData);
  End;

  MsgBase^.WriteMsg;
  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);

  MsgText.Free;

  ClientWriteLine ('240 Article posted ok');
End;

Procedure TNNTPServer.cmd_ARTICLE;
Var
  ArticleNum : LongInt = 0;
  Found      : Boolean = False;
  MsgBase    : PMsgBaseABS;
Begin
  If Not LoggedIn Then Begin
    ClientWriteLine(re_AuthReq);
    Exit;
  End;

  If MBasePos = -1 Then Begin
    ClientWriteLine('412 No newsgroup selected');
    Exit;
  End;

  ArticleNum := strS2I(Data);

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    ClientWriteLine('423 No such article');

    Dispose (MsgBase, Done);

    Exit;
  End;

  MsgBase^.SeekFirst(ArticleNum);

  Found := MsgBase^.SeekFound;

  If Found Then Begin
    MsgBase^.MsgStartUp;

    Found := MsgBase^.GetMsgNum = ArticleNum;
  End;

  If Not Found Then Begin
    ClientWriteLine('423 No such article');

    Dispose (MsgBase, Done);

    Exit;
  End;

  MsgBase^.MsgTxtStartUp;

  Client.WriteLine('220 0 ' + strI2S(ArticleNum));

  Client.WriteLine('From: ' + MsgBase^.GetFrom);
  Client.WriteLine('Newsgroups: ' + MBase.NewsName);
  Client.WriteLine('Subject: ' + MsgBase^.GetSubj);
  Client.WriteLine('Date: ' + MsgBase^.GetDate);
  Client.WriteLine('');

  While Not MsgBase^.EOM Do
    Client.WriteLine(MsgBase^.GetString(79));

  Client.WriteLine ('.');

  Dispose (MsgBase, Done);
End;

Procedure TNNTPServer.cmd_XOVER;
Var
  First   : LongInt = 0;
  Last    : LongInt = 0;
  Found   : Boolean = False;
  MsgBase : PMsgBaseABS;
  MsgText : TStringList;
Begin
  If Not LoggedIn Then Begin
    ClientWriteLine(re_AuthReq);
    Exit;
  End;

  If MBasePos = -1 Then Begin
    ClientWriteLine('412 No newsgroup selected');
    Exit;
  End;

  If Pos('-', Data) > 0 Then Begin
    First := strS2I(strWordGet(1, Data, '-'));
    Last  := strS2I(strWordGet(2, Data, '-'));
  End Else Begin
    First := strS2I(Data);
    Last  := First;
  End;

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    ClientWriteLine('420 No article(s) selected');

    Dispose (MsgBase, Done);

    Exit;
  End;

  If Last = 0 Then Last := MsgBase^.GetHighMsgNum;

  MsgText := TStringList.Create;

  MsgBase^.SeekFirst(First);

  While MsgBase^.SeekFound Do Begin
    If Not Found Then Begin
      Found := True;

      ClientWriteLine('224 Overview information follows');
    End;

    MsgBase^.MsgStartUp;
    MsgBase^.MsgTxtStartUp;

    MsgText.Clear;

    While Not MsgBase^.EOM Do
      MsgText.Add(MsgBase^.GetString(79));

    Client.WriteStr(strI2S(MsgBase^.GetMsgNum) + #9);
    Client.WriteStr(MsgBase^.GetSubj + #9);
    Client.WriteStr(MsgBase^.GetFrom + #9);
    Client.WriteStr(MsgBase^.GetDate + #9);
    Client.WriteStr(#9); //msgID
    Client.WriteStr(#9); //refs
    Client.WriteStr(strI2S(Length(MsgText.Text)) + #9);
    Client.WriteStr(strI2S(MsgText.Count) + #13#10);

    If MsgBase^.GetMsgNum >= Last Then Break;

    MsgBase^.SeekNext;
  End;

  Client.WriteLine('.');

  MsgText.Free;

  Dispose (MsgBase, Done);

  If Not Found Then
    ClientWriteLine('420 No article(s) selected');
End;

Procedure TNNTPServer.Execute;
Var
  Str : String;
Begin
  ResetSession;

  ClientWriteLine(re_Greeting);

  Repeat
    If Client.WaitForData(bbsConfig.inetNNTPTimeout * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    Server.Server.Status('C:' + Str);

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'ARTICLE'  Then cmd_ARTICLE Else
    If Cmd = 'AUTHINFO' Then cmd_AUTHINFO Else
    If Cmd = 'GROUP'    Then cmd_GROUP Else
    If Cmd = 'LIST'     Then cmd_LIST Else
    If Cmd = 'POST'     Then cmd_POST Else
    If Cmd = 'QUIT'     Then Break Else
    If Cmd = 'XOVER'    Then cmd_XOVER Else
      ClientWriteLine(re_Unknown);
  Until Terminated or EndSession;

  If Not Terminated Then ClientWriteLine(re_Goodbye);
End;

Destructor TNNTPServer.Destroy;
Begin
  Inherited Destroy;
End;

End.

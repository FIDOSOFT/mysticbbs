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
    Server   : TServerManager;
    UserName : String[30];
    Password : String[15];
    LoggedIn : Boolean;
    Cmd      : String;
    Data     : String;
    User     : RecUser;
    UserPos  : LongInt;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ClientWriteLine (Str: String);

    Procedure   ResetSession;

    Procedure   cmd_AUTHINFO;
    Procedure   cmd_GROUP;
    Procedure   cmd_LIST;
  End;

Implementation

Uses
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

Const
  FileReadBuffer   = 2048;

  re_Greeting      = '200 Mystic BBS NNTP server ready';
  re_Goodbye       = '205 Goodbye';
  re_ListFollows   = '215 List of newsgroups follows';
  re_AuthOK        = '281 Authentication accepted';
  re_AuthBad       = '381 Authentication rejected';
  re_AuthPass      = '381 Password required';
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
  Password   := '';
  UserPos    := -1;
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
Begin
// 211 number_of_estimated_articles first_msg last_msg newsname
// 411 nosuchnewsgroup
// this selects the "current" base
End;

Procedure TNNTPServer.cmd_LIST;
Var
  MBaseFile   : TBufFile;
  TempBase    : RecMessageBase;
  MsgBase     : PMsgBaseABS;
  LowMessage  : LongInt = 0;
  HighMessage : LongInt = 0;
  PostAbility : Char;
Begin
  ClientWriteLine(re_ListFollows);

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

    If Cmd = 'AUTHINFO' Then cmd_AUTHINFO Else
    If Cmd = 'GROUP'    Then cmd_GROUP Else
    If Cmd = 'LIST'     Then cmd_LIST Else
    If Cmd = 'QUIT'     Then Break Else
      ClientWriteLine(re_Unknown);
  Until Terminated;

  If Not Terminated Then ClientWriteLine(re_Goodbye);
End;

Destructor TNNTPServer.Destroy;
Begin
  Inherited Destroy;
End;

End.

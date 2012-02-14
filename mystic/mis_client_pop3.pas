{$I M_OPS.PAS}

Unit MIS_Client_POP3;

// RFC 1939
// optional TOP and APOP not implemented
// needs to reformat long messages > 79 chars?

Interface

Uses
  MD5,
  Classes,
  SysUtils,
  m_Strings,
  m_FileIO,
  m_Socket_Class,
  m_DateTime,
  MIS_Server,
  MIS_NodeData,
  MIS_Common,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Function CreatePOP3 (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Const
  MaxMailBoxSize = 1000;

Type
  PMailMessageRec = ^TMailMessageRec;
  TMailMessageRec = Record
    MsgSize : LongInt;
    MD5     : String[32];
    Deleted : Boolean;
    GotRETR : Boolean;
    Text    : TStringList;
  End;

  TPOP3Server = Class(TServerClient)
    Server   : TServerManager;
    UserName : String[40];
    Password : String[20];
    LoggedIn : Boolean;
    GotQuit  : Boolean;
    Cmd      : String;
    Data     : String;
    User     : RecUser;
    UserPos  : LongInt;
    MailInfo : Array[1..MaxMailBoxSize] of PMailMessageRec;
    MailSize : LongInt;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ResetSession;
    Procedure   CreateMailBoxData;
    Procedure   DeleteMessages;
    Function    GetMessageUID (Var MsgBase: PMsgBaseABS) : String;
    Procedure   GetMessageCount (Var TotalMsg: LongInt; Var TotalSize: LongInt);

    Procedure   cmdLIST;
    Procedure   cmdUSER;
    Procedure   cmdPASS;
    Procedure   cmdSTAT;
    Procedure   cmdUIDL;
    Procedure   cmdRETR;
    Procedure   cmdRSET;
    Procedure   cmdDELE;
    Procedure   cmdTOP;
  End;

Implementation

Const
  POP3TimeOut  : SmallInt = 900;   { MCFG? }
  DeleteOnRETR : Boolean  = False; { MCFG? }

  re_OK    = '+OK ';
  re_Error = '-ERR ';

  re_UnknownCommand = re_Error + 'Unknown command';
  re_UnknownUser    = re_Error + 'Unknown user';
  re_BadLogin       = re_Error + 'Bad credentials';
  re_NotLoggedIn    = re_Error + 'Not logged in';
  re_UnknownMail    = re_Error + 'Unknown message';

  re_Greeting       = re_OK + 'Mystic POP3 Server';
  re_Goodbye        = re_OK + 'Goodbye';
  re_SendUserPass   = re_OK + 'Send user password';
  re_LoggedIn       = re_OK + 'Welcome';
  re_GetMessage     = re_OK + 'Sending message ';
  re_ResetOK        = re_OK + 'Messages reset';
  re_MsgDeleted     = re_OK + 'Message deleted';

Function CreatePOP3 (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TPOP3Server.Create(Owner, CliSock);
End;

Constructor TPOP3Server.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server   := Owner;
  MailSize := 0;
End;

Procedure TPOP3Server.ResetSession;
Var
  Count : LongInt;
Begin
  LoggedIn := False;
  GotQuit  := False;
  UserName := '';
  Password := '';
  UserPos  := -1;

  For Count := 1 to MailSize Do
    If MailInfo[Count] <> NIL Then Begin
      If Assigned(MailInfo[Count].Text) Then
        MailInfo[Count].Text.Free;

      Dispose (MailInfo[Count]);
    End;

  MailSize := 0;
End;

Procedure TPOP3Server.GetMessageCount (Var TotalMsg: LongInt; Var TotalSize: LongInt);
Var
  Count : LongInt;
Begin
  TotalMsg  := 0;
  TotalSize := 0;

  For Count := 1 to MailSize Do
    If Not MailInfo[Count].Deleted Then Begin
      Inc (TotalMsg);
      Inc (TotalSize, MailInfo[Count].MsgSize);
    End;
End;

Function TPOP3Server.GetMessageUID (Var MsgBase: PMsgBaseABS) : String;
Var
  TempStr : String;
Begin
  // FP might calc this wrong if we do it all at once, so annoying

  TempStr := strI2S(User.PermIdx);
  TempStr := TempStr + MsgBase^.GetFrom;
  TempStr := TempStr + MsgBase^.GetDate;
  TempStr := TempStr + MsgBase^.GetTime;

  Result  := MD5Print(MD5String(TempStr));
End;

Procedure TPOP3Server.CreateMailBoxData;
Var
  MBaseFile : File of MBaseRec;
  MBase     : MBaseRec;
  MsgBase   : PMsgBaseABS;

  Function ParseDateTime (Date, Time : String) : String;
  Begin
    DateSeparator := '-';
    ParseDateTime := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss', StrToDateTime(Date + ' ' + Time));
  End;

  Procedure AddLine (Str: String);
  Begin
    MailInfo[MailSize].Text.Add(Str);

    Inc (MailInfo[MailSize].MsgSize, Length(Str) + 2); {CRLF}
  End;

Begin
  Assign (MBaseFile, bbsConfig.DataPath + 'mbases.dat');

  If Not ioReset(MBaseFile, SizeOf(MBaseRec), fmRWDN) Then Exit;

  ioRead (MBaseFile, MBase);
  Close  (MBaseFile);

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    Dispose (MsgBase, Done);
    Exit;
  End;

  MsgBase^.YoursFirst(User.RealName, User.Handle);

  While MsgBase^.YoursFound Do Begin
    MsgBase^.MsgStartup;
    MsgBase^.MsgTxtStartup;

    Inc (MailSize);

    New (MailInfo[MailSize]);

    MailInfo[MailSize].Text := TStringList.Create;

    AddLine ('Date: ' + ParseDateTime(MsgBase^.GetDate, MsgBase^.GetTime));
    AddLine ('From: ' + MsgBase^.GetFrom + ' <' + strReplace(MsgBase^.GetFrom, ' ', '_') + '@' + bbsConfig.inetDomain + '>');
    AddLine ('X-Mailer: Mystic BBS ' + mysVersion);
    AddLine ('To: ' + MsgBase^.GetTo + ' <' + strReplace(MsgBase^.GetTo, ' ', '_') + '@' + bbsConfig.inetDomain + '>');
    AddLine ('Subject: ' + MsgBase^.GetSubj);
    AddLine ('Content-Type: text/plain; charset=us-ascii');
    AddLine ('');

    While Not MsgBase^.EOM Do
      AddLine(MsgBase^.GetString(79));

    MailInfo[MailSize].MD5     := GetMessageUID(MsgBase);
    MailInfo[MailSize].GotRETR := False;
    MailInfo[MailSize].Deleted := False;

    MsgBase^.YoursNext;
  End;

  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);
End;

Procedure TPOP3Server.DeleteMessages;
Var
  Count     : LongInt;
  MBaseFile : File of MBaseRec;
  MBase     : MBaseRec;
  MsgBase   : PMsgBaseABS;
Begin
  Assign (MBaseFile, bbsConfig.DataPath + 'mbases.dat');

  If Not ioReset(MBaseFile, SizeOf(MBaseRec), fmRWDN) Then Exit;

  ioRead (MBaseFile, MBase);
  Close  (MBaseFile);

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then Begin
    Dispose (MsgBase, Done);
    Exit;
  End;

  For Count := 1 to MailSize Do Begin
    If MailInfo[Count].Deleted or (MailInfo[Count].GotRETR and DeleteOnRETR) Then Begin
      MsgBase^.YoursFirst(User.RealName, User.Handle);

      While MsgBase^.YoursFound Do Begin
        MsgBase^.MsgStartUp;

        If GetMessageUID(MsgBase) = MailInfo[Count].MD5 Then Begin
          MsgBase^.DeleteMsg;
          Break;
        End;

        MsgBase^.YoursNext;
      End;
    End;
  End;

  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);
End;

Procedure TPOP3Server.cmdUSER;
Begin
  ResetSession;

  If SearchForUser(Data, User, UserPos) Then Begin
    Client.WriteLine(re_SendUserPass);
    UserName := Data;
  End Else
    Client.WriteLine(re_UnknownUser);
End;

Procedure TPOP3Server.cmdPASS;
Begin
  If (UserName = '') or (UserPos = -1) Then Begin
    Client.WriteLine(re_UnknownUser);
    Exit;
  End;

  If strUpper(Data) = User.Password Then Begin
    LoggedIn := True;

    CreateMailboxData;

    Client.WriteLine(re_LoggedIn);

    Server.Server.Status(User.Handle + ' logged in');
  End Else
    Client.WriteLine(re_BadLogin);
End;

Procedure TPOP3Server.cmdSTAT;
Var
  DataSize : LongInt;
  DataMsg  : LongInt;
Begin
  If LoggedIn Then Begin
    GetMessageCount(DataMsg, DataSize);

    Client.WriteLine(re_OK + strI2S(DataMsg) + ' ' + strI2O(Datasize));
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdLIST;
Var
  MsgNum  : LongInt;
  MsgSize : LongInt;
  Count   : LongInt;
Begin
  If LoggedIn Then Begin

    If Data <> '' Then Begin
      MsgNum := strS2I(Data);

      If (MsgNum > 0) and (MsgNum <= MailSize) and (Not MailInfo[MsgNum].Deleted) Then
        Client.WriteLine(re_OK + strI2S(MsgNum) + ' ' + strI2O(MailInfo[MsgNum].MsgSize))
      Else
        Client.WriteLine(re_UnknownMail);
    End Else Begin
      GetMessageCount(MsgNum, MsgSize);

      Client.WriteLine (re_OK + strI2S(MsgNum) + ' messages (' + strI2O(MsgSize) + ' octets)');

      For Count := 1 to MailSize Do
        If Not MailInfo[Count].Deleted Then
          Client.WriteLine (strI2S(Count) + ' ' + strI2O(MailInfo[Count].MsgSize));

      Client.WriteLine('.');
    End;
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdUIDL;
Var
  MsgNum : LongInt;
  Count  : LongInt;
Begin
  If LoggedIn Then Begin
    If Data <> '' Then Begin
      MsgNum := strS2I(Data);

      If (MsgNum > 0) and (MsgNum <= MailSize) and (Not MailInfo[MsgNum].Deleted) Then
        Client.WriteLine(re_OK + strI2S(MsgNum) + ' ' + MailInfo[MsgNum].MD5)
      Else
        Client.WriteLine(re_UnknownMail);
    End Else Begin
      Client.WriteLine (re_OK + 'Message list follows');

      For Count := 1 to MailSize Do
        If Not MailInfo[Count].Deleted Then Begin
          Client.WriteLine (strI2S(Count) + ' ' + MailInfo[Count].MD5);
        End;
      Client.WriteLine('.');
    End;
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdRETR;
Var
  MsgNum : LongInt;
  Count  : LongInt;
Begin
  If LoggedIn Then Begin
    MsgNum := strS2I(Data);

    If (MsgNum > 0) and (MsgNum <= MailSize) and (Not MailInfo[MsgNum].Deleted) Then Begin
      Client.WriteLine (re_GetMessage + strI2S(MsgNum));

      For Count := 0 to MailInfo[MsgNum].Text.Count - 1 Do
        Client.WriteLine(MailInfo[MsgNum].Text[Count]);

      Client.WriteLine('.');

      MailInfo[MsgNum].GotRETR := True;
    End Else
      Client.WriteLine(re_UnknownMail);
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdRSET;
Var
  Count : LongInt;
Begin
  If LoggedIn Then Begin
    For Count := 1 to MailSize Do
      MailInfo[Count].Deleted := False;

    Client.WriteLine (re_ResetOK);
  End Else
    Client.WriteLine (re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdDELE;
Var
  MsgNum : LongInt;
Begin
  If LoggedIn Then Begin
    MsgNum := strS2I(Data);

    If (MsgNum > 0) and (MsgNum <= MailSize) and (Not MailInfo[MsgNum].Deleted) Then Begin
      MailInfo[MsgNum].Deleted := True;

      Client.WriteLine(re_MsgDeleted);
    End Else
      Client.WriteLine(re_UnknownMail);
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.cmdTOP;
Begin
  If LoggedIn Then Begin
  End Else
    Client.WriteLine(re_NotLoggedIn);
End;

Procedure TPOP3Server.Execute;
Var
  Str : String;
Begin
  ResetSession;

  Client.WriteLine(re_Greeting);

  Repeat
    If Client.WaitForData(POP3TimeOut * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

//    If Cmd = 'APOP' Then cmdAPOP Else
    If Cmd = 'DELE' Then cmdDELE Else
    If Cmd = 'LIST' Then cmdLIST Else
    If Cmd = 'NOOP' Then Client.WriteLine(re_OK) Else
    If Cmd = 'PASS' Then cmdPASS Else
    If Cmd = 'RETR' Then cmdRETR Else
    If Cmd = 'RSET' Then cmdRSET Else
    If Cmd = 'STAT' Then cmdSTAT Else
//    If Cmd = 'TOP'  Then cmdTOP Else
    If Cmd = 'UIDL' Then cmdUIDL Else
    If Cmd = 'USER' Then cmdUSER Else
    If Cmd = 'QUIT' Then Begin
      GotQuit := True;
      Break;
    End Else
      Client.WriteLine(re_UnknownCommand);
  Until Terminated;

  If GotQuit Then Begin
    Client.WriteLine(re_Goodbye);

    Server.Server.Status (User.Handle + ' logged out');

    DeleteMessages;
  End;
End;

Destructor TPOP3Server.Destroy;
Begin
  ResetSession;

  Inherited Destroy;
End;

End.

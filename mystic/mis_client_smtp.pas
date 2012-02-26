{$I M_OPS.PAS}

Unit MIS_Client_SMTP;

{ update e-mails post stats }
{ update bbs history }

Interface

Uses
  Classes,
  SysUtils,
  m_Strings,
  m_FileIO,
  m_Socket_Class,
  m_DateTime,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish,
  MIS_Server,
  MIS_NodeData,
  MIS_Common;

Function CreateSMTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Type
  TSMTPServer = Class(TServerClient)
    Server     : TServerManager;
    User       : RecUser;
    UserPos    : LongInt;
    Cmd        : String;
    Data       : String;
    EndSession : Boolean;
    FromName   : String;
    FromPos    : LongInt;
    ToList     : TStringList;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ResetSession;
    Function    ValidateNameAndDomain (IsFrom: Boolean) : Boolean;

    Procedure   cmdHELO;
    Procedure   cmdRSET;
    Procedure   cmdMAIL;
    Procedure   cmdRCPT;
    Procedure   cmdDATA;
  End;

Implementation

Const
  SMTPTimeOut    = 120; { MCFG }
  SMTPHackThresh = 10000;

  re_Goodbye      = '221 Goodbye';
  re_UnknownCmd   = '502 Unknown command';
  re_OK           = '250 OK';
  re_BadUser      = '550 No such user here';
  re_NeedMail     = '503 Must send MAIL FROM: first';
  re_NeedRcpt     = '503 Must send RCPT TO: first';
  re_ErrorSending = '550 Mailbox not found';

Function CreateSMTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TSMTPServer.Create(Owner, CliSock);
End;

Constructor TSMTPServer.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

Function TSMTPServer.ValidateNameAndDomain (IsFrom: Boolean) : Boolean;
Var
  InName   : String;
  InDomain : String;
Begin
  Result := False;

  InName   := strReplace(Copy(Data, Pos('<', Data) + 1, Pos('@', Data) - Pos('<', Data) - 1), '_', ' ');
  InDomain := Copy(Data, Pos('@', Data) + 1, Pos('>', Data) - Pos('@', Data) - 1);

  If IsFrom Then
    Server.Server.Status('User: ' + InName + ' Domain: ' + InDomain);

  If InDomain <> bbsConfig.iNetDomain Then Begin
    Server.Server.Status('Refused by domain: ' + InName + '@' + InDomain);
    Exit;
  End;

  Result := SearchForUser(InName, User, UserPos);

  If Not Result Then
    Server.Server.Status('Refused by name: ' + InName + '@' + InDomain);
End;

Procedure TSMTPServer.ResetSession;
Begin
  UserPos    := -1;
  FromName   := '';
  FromPos    := -1;
  EndSession := False;

  If Assigned(ToList) Then ToList.Free;

  ToList := TStringList.Create;
End;

Procedure TSMTPServer.cmdHELO;
Begin
  Client.WriteLine('250 ' + bbsConfig.inetDomain);
End;

Procedure TSMTPServer.cmdRSET;
Begin
  ResetSession;

  Client.WriteLine(re_OK);
End;

Procedure TSMTPServer.cmdMAIL;
Begin
  If ValidateNameAndDomain(True) Then Begin
    FromName := User.Handle;

    Client.WriteLine (re_OK)
  End Else
    Client.WriteLine (re_BadUser);
End;

Procedure TSMTPServer.cmdRCPT;
Begin
  If FromName = '' Then Begin
    Client.WriteLine (re_NeedMail);
    Exit;
  End;

  If ValidateNameAndDomain(False) Then Begin
    ToList.Add(User.Handle);

    Client.WriteLine (re_OK);
  End Else
    Client.WriteLine (re_BadUser);
End;

Procedure TSMTPServer.cmdDATA;
Var
  InData     : String;
  HackCount  : LongInt;
  MBaseFile  : File of RecMessageBase;
  MBase      : RecMessageBase;
  MsgBase    : PMsgBaseABS;
  MsgText    : TStringList;
  MsgSubject : String;
  MsgLoop    : LongInt;
  Count      : LongInt;
  Count2     : LongInt;
  Str        : String;
Begin
  If FromName = '' Then Begin
    Client.WriteLine (re_NeedMail);
    Exit;
  End;

  If ToList.Count = 0 Then Begin
    Client.WriteLine (re_NeedRcpt);
    Exit;
  End;

  Client.WriteLine ('354 Start mail input; end with <CRLF>.<CRLF>');

  MsgText := TStringList.Create;

  Repeat
    Client.ReadLine(InData);

    If InData = '.' Then Break;

    If MsgText.Count >= mysMaxMsgLines Then Begin
      HackCount := 0;

      While Not Terminated And (InData <> '.') Do Begin
        // todo: what happens if they never send an EOL... could still flood

        Client.ReadLine(InData);
        Inc (HackCount);

        If HackCount >= SMTPHackThresh Then Begin
          EndSession := True;   // someone is being a douchebag
          Server.Server.Status('Flood attempt from ' + FromName + ' (' + Client.PeerIP + '); Goodbye');
          MsgText.Free;
          Exit;
        End;
      End;

      Break;
    End;

    MsgText.Add(InData);
  Until False;

  Assign  (MBaseFile, bbsConfig.DataPath + 'mbases.dat');
  ioReset (MBaseFile, SizeOf(RecMessageBase), fmRWDN);
  ioRead  (MBaseFile, MBase);
  Close   (MBaseFile);

  Case MBase.BaseType of
    0 : MsgBase := New(PMsgBaseJAM, Init);
    1 : MsgBase := New(PMsgBaseSquish, Init);
  End;

  MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

  If Not MsgBase^.OpenMsgBase Then
    If Not MsgBase^.CreateMsgBase (MBase.MaxMsgs, MBase.MaxAge) Then Begin
      Dispose(MsgBase, Done);
      MsgText.Free;
      Client.WriteLine(re_ErrorSending);
      Exit;
    End Else
      If Not MsgBase^.OpenMsgBase Then Begin
        Dispose(MsgBase, Done);
        MsgText.Free;
        Client.WriteLine(re_ErrorSending);
        Exit;
      End;

  MsgSubject := '';
  Count      := 0;

  While Count < MsgText.Count Do Begin
    If Pos('Subject:', MsgText.Strings[Count]) > 0 Then
      MsgSubject := Copy(MsgText.Strings[Count], 10, Length(MsgText.Strings[Count]))
    Else
      If MsgText.Strings[Count] = '' Then Begin
        While (MsgText.Strings[Count] = '') And (Count < MsgText.Count) Do Inc(Count);
        Break;
      End;

    Inc (Count);
  End;

  If Count = MsgText.Count Then Begin
    Client.WriteLine(re_ErrorSending);
    MsgText.Free;
    Exit;
  End;

  For MsgLoop := 0 To ToList.Count - 1 Do Begin
    Server.Server.Status('Sending mail from ' + FromName + ' to ' + ToList.Strings[MsgLoop]);

    MsgBase^.StartNewMsg;

    MsgBase^.SetLocal    (True);
    MsgBase^.SetMailType (mmtNormal);
    MsgBase^.SetPriv     (True);
    MsgBase^.SetDate     (FormatDateTime('mm/dd/yy', Now));
    MsgBase^.SetTime     (FormatDateTime('hh:nn', Now));
    MsgBase^.SetFrom     (FromName);
    MsgBase^.SetTo       (ToList.Strings[MsgLoop]);
    MsgBase^.SetSubj     (MsgSubject);

    For Count2 := Count to MsgText.Count - 1 Do Begin
      Str := MsgText.Strings[Count2];

      If Length(Str) > 79 Then Str[0] := #79;

      MsgBase^.DoStringLn(Str);
    End;

    MsgBase^.WriteMsg;
  End;

  MsgBase^.CloseMsgBase;

  Dispose (MsgBase, Done);

  Client.WriteLine(re_OK);
End;

Procedure TSMTPServer.Execute;
Var
  Str : String;
Begin
  ResetSession;

  Client.WriteLine('220 ' + bbsConfig.iNetDomain + ' Mystic SMTP Ready');

  Repeat
    If Client.WaitForData(SMTPTimeOut * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'DATA' Then cmdDATA Else
    If Cmd = 'EHLO' Then cmdHELO Else
    If Cmd = 'HELO' Then cmdHELO Else
    If Cmd = 'MAIL' Then cmdMAIL Else
    If Cmd = 'NOOP' Then Client.WriteLine(re_OK) Else
    If Cmd = 'RCPT' Then cmdRCPT Else
    If Cmd = 'RSET' Then cmdRSET Else
    If Cmd = 'QUIT' Then Break Else
      Client.WriteLine(re_UnknownCmd);
  Until Terminated or EndSession;

  If Not Terminated And Not EndSession Then Client.WriteLine(re_Goodbye);
End;

Destructor TSMTPServer.Destroy;
Begin
  If Assigned(ToList) Then ToList.Free;

  Inherited Destroy;
End;

End.

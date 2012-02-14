{$I M_OPS.PAS}

Unit MIS_Client_HTTP;

// placeholder for HTTP server if Mystic needs one?
// based off off initial POP3 server footprint

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

Function CreatePOP3 (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Type
  TPOP3Server = Class(TServerClient)
    Server     : TServerManager;
    UserName   : String[40];
    Password   : String[20];
    LoggedIn   : Boolean;
    Cmd        : String;
    Data       : String;
    User       : UserRec;
    UserPos    : LongInt;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ResetSession;

    Procedure   cmdUSER;
    Procedure   cmdPASS;
  End;

Implementation

Const
  POP3TimeOut    = 120;
  FileBufSize    = 8 * 1024;

  re_OK    = '+OK ';
  re_Error = '-ERR ';

  re_UnknownCommand = re_Error + 'Unknown command';
  re_UnknownUser    = re_Error + 'Unknown user';
  re_BadLogin       = re_Error + 'Bad credentials';

  re_Greeting       = 'Mystic POP3 Server';
  re_Goodbye        = re_OK + 'Goodbye';
  re_SendUserPass   = re_OK + 'Send user password';
  re_LoggedIn       = re_OK + 'Welcome';

Function CreatePOP3 (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TPOP3Server.Create(Owner, CliSock);
End;

Constructor TPOP3Server.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

Procedure TPOP3Server.ResetSession;
Begin
  LoggedIn   := False;
  UserName   := '';
  Password   := '';
  UserPos    := -1;
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

    Client.WriteLine(re_LoggedIn);
  End Else
    Client.WriteLine(re_BadLogin);
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

server.server.status(str);

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'PASS' Then cmdPASS Else
    If Cmd = 'QUIT' Then Break Else
    If Cmd = 'USER' Then cmdUSER Else
      Client.WriteLine(re_UnknownCommand);
  Until Terminated;

  If Not Terminated Then Client.WriteLine(re_Goodbye);
End;

Destructor TPOP3Server.Destroy;
Begin
  Inherited Destroy;
End;

End.

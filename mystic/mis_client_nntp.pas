{$I M_OPS.PAS}

Unit MIS_Client_NNTP;

// lookup:
// how to send greeting and goodbye?
// how to send capabilities so far only AUTHINFO
// determine base feature-set required

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

Function CreateNNTP (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass) : TServerClient;

Type
  TNNTPServer = Class(TServerClient)
    Server   : TServerManager;
    UserName : String[40];
    Password : String[20];
    LoggedIn : Boolean;
    Cmd      : String;
    Data     : String;
    User     : RecUser;
    UserPos  : LongInt;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ResetSession;

    Procedure   cmd_AUTHINFO;
  End;

Implementation

Const
  NNTPTimeOut = 180;  // make configurable

  re_Greeting      = 'Mystic BBS NNTP Server';
  re_Goodbye       = 'Goodbye';

  re_AuthOK        = '281 Authentication accepted';
  re_AuthBad       = '381 Authentication rejected';
  re_AuthPass      = '381 Password required';
  re_AuthSync      = '482 Bad Authentication sequence';
  re_Unknown       = '500 Unknown command';
  re_UnknownOption = '501 Unknown option';

Function CreateNNTP (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TNNTPServer.Create(Owner, CliSock);
End;

Constructor TNNTPServer.Create (Owner: TServerManager; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
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
  ResetSession;

  NewCmd  := strWordGet(1, Data, ' ');
  NewData := Copy(Data, Pos(' ', Data) + 1, 255);

  If NewCmd = 'USER' Then Begin
    If SearchForUser(NewData, User, UserPos) Then Begin
      Client.WriteLine(re_AuthPass);
      UserName := NewData;
    End Else
      Client.WriteLine(re_AuthBad);
  End Else
  If NewCmd = 'PASS' Then Begin
    If UserPos = -1 Then
      Client.WriteLine(re_AuthSync)
    Else
    If strUpper(NewData) = User.Password Then Begin
      Client.WriteLine(re_AuthOK);
      LoggedIn := True;
    End Else
      Client.WriteLine(re_AuthBad);
  End Else
    Client.WriteLine(re_UnknownOption);
End;

Procedure TNNTPServer.Execute;
Var
  Str : String;
Begin
  ResetSession;

  Client.WriteLine(re_Greeting);

  Repeat
    If Client.WaitForData(NNTPTimeOut * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    //server.server.status(str);

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'AUTHINFO' Then cmd_AUTHINFO Else
    If Cmd = 'QUIT' Then Break Else
      Client.WriteLine(re_Unknown);
  Until Terminated;

  If Not Terminated Then Client.WriteLine(re_Goodbye);
End;

Destructor TNNTPServer.Destroy;
Begin
  Inherited Destroy;
End;

End.
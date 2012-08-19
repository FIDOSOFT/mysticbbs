{$I M_OPS.PAS}

Unit MIS_Server;

Interface

Uses
  Classes,
  m_io_Base,
  m_io_Sockets,
  MIS_Common,
  MIS_NodeData;

Const
  MaxStatusText = 20;

Type
  TServerManager    = Class;
  TServerClient     = Class;
  TServerCreateProc = Function (Manager: TServerManager; Config: RecConfig; ND: TNodeData; Client: TIOSocket): TServerClient;

  TServerManager = Class(TThread)
    Critical      : TRTLCriticalSection;
    NodeInfo      : TNodeData;
    Server        : TIOSocket;
    ServerStatus  : TStringList;
    StatusUpdated : Boolean;
    ClientList    : TList;
    NewClientProc : TServerCreateProc;
    Config        : RecConfig;
    ClientMax     : LongInt;
    ClientMaxIPs  : LongInt;
    ClientRefused : LongInt;
    ClientBlocked : LongInt;
    ClientTotal   : LongInt;
    ClientActive  : LongInt;
    Port          : LongInt;
    TextPath      : String[80];

    Constructor Create       (Config: RecConfig; PortNum: Word; CliMax: Word; ND: TNodeData; CreateProc: TServerCreateProc);
    Destructor  Destroy;     Override;
    Procedure   Execute;     Override;
    Procedure   Status       (Str: String);
    Function    CheckIP      (IP, Mask: String) : Boolean;
    Function    IsBlockedIP  (Var Client: TIOSocket) : Boolean;
    Function    DuplicateIPs (Var Client: TIOSocket) : Byte;
  End;

  TServerClient = Class(TThread)
    Client  : TIOSocket;
    Manager : TServerManager;

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Destructor  Destroy; Override;
  End;

Implementation

Uses
  m_Strings,
  m_DateTime;

Constructor TServerManager.Create (Config: RecConfig; PortNum: Word; CliMax: Word; ND: TNodeData; CreateProc: TServerCreateProc);
Var
  Count : Byte;
Begin
  Inherited Create(False);

  InitCriticalSection(Critical);

  Port          := PortNum;
  ClientMax     := CliMax;
  ClientRefused := 0;
  ClientBlocked := 0;
  ClientTotal   := 0;
  ClientActive  := 0;
  ClientMaxIPs  := 1;
  NewClientProc := CreateProc;
  Server        := TIOSocket.Create;
  ServerStatus  := TStringList.Create;
  StatusUpdated := False;
  ClientList    := TList.Create;
  TextPath      := Config.DataPath;
  NodeInfo      := ND;
  Config        := Config;

  For Count := 1 to ClientMax Do
    ClientList.Add(NIL);

  FreeOnTerminate := False;
End;

Function TServerManager.CheckIP (IP, Mask: String) : Boolean;
Var
  A     : Byte;
  Count : Byte;
  Str   : String;
  Str2  : String;
Begin
  Result := True;

  For Count := 1 to 4 Do Begin
    If Count < 4 Then Begin
      Str  := Copy(IP, 1, Pos('.', IP) - 1);
      Str2 := Copy(Mask, 1, Pos('.', Mask) - 1);
      Delete (IP, 1, Pos('.', IP));
      Delete (Mask, 1, Pos('.', Mask));
    End Else Begin
      Str  := Copy(IP, 1, Length(IP));
      Str2 := Copy(Mask, 1, Length(Mask));
    End;

    For A := 1 to Length(Str) Do
      If Str2[A] = '*' Then
        Break
      Else
      If Str[A] <> Str2[A] Then Begin
        Result := False;
        Break;
      End;

    If Not Result Then Break;
  End;
End;

Function TServerManager.IsBlockedIP (Var Client: TIOSocket) : Boolean;
Var
  TF  : Text;
  Str : String;
Begin
  Result   := False;
  FileMode := 66;

  Assign (TF, TextPath + 'badip.txt');
  Reset (TF);

  If IoResult = 0 Then Begin
    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If CheckIP (Client.PeerIP, Str) Then Begin
        Result := True;
        Break;
      End;
    End;

    Close (TF);
  End;
End;

Function TServerManager.DuplicateIPs (Var Client: TIOSocket) : Byte;
Var
  Count : Byte;
Begin
  Result := 0;

  For Count := 0 to ClientMax - 1 Do
    If Assigned(ClientList[Count]) Then Begin
      If Client.PeerIP = TServerClient(ClientList[Count]).Client.FPeerIP Then
        Inc(Result);
    End;
End;

Procedure TServerManager.Status (Str: String);
Var
  Res : String;
Begin
  If ServerStatus = NIL Then Exit;

  EnterCriticalSection(Critical);

  Try
    If ServerStatus.Count > MaxStatusText Then
      ServerStatus.Delete(0);

    Res := '(' + Copy(DateDos2Str(CurDateDos, 1), 1, 5) + ' ' + TimeDos2Str(CurDateDos, False) + ') ' + Str;

    If Length(Res) > 74 Then Begin
      ServerStatus.Add(Copy(Res, 1, 74));

      If ServerStatus.Count > MaxStatusText Then
        ServerStatus.Delete(0);

      ServerStatus.Add(strRep(' ', 14) + Copy(Res, 75, 255));
    End Else
      ServerStatus.Add(Res);
  Except
    { ignore exceptions here -- happens when socketstatus is NIL}
    { need to review criticals now that they are in FP's RTL}
  End;

  StatusUpdated := True;

  LeaveCriticalSection(Critical);
End;

Procedure TServerManager.Execute;
Var
  NewClient : TIOSocket;
Begin
  Repeat Until Server <> NIL;  // Synchronize with server class
  Repeat Until ServerStatus <> NIL; // Syncronize with status class

  Server.WaitInit(Port);

  If Terminated Then Exit;

  If ClientMax = 0 Then
  	Status('WARNING: At least one server is configured with 0 max clients.');

  Status('Opening server socket on port ' + strI2S(Port));

  Repeat
    NewClient := Server.WaitConnection;

    If NewClient = NIL Then Break; // time to shutdown the server...

    If (ClientMax > 0) And (ClientActive >= ClientMax) Then Begin
      Inc (ClientRefused);
      Status ('BUSY: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'busy.txt') Then NewClient.WriteLine('BUSY');
      WaitMS(3000);
      NewClient.Free;
    End Else
    If IsBlockedIP(NewClient) Then Begin
      Inc (ClientBlocked);
      Status('BLOCK: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'blocked.txt') Then NewClient.WriteLine('BLOCKED');
      WaitMS(3000);
      NewClient.Free;
    End Else
    If (ClientMaxIPs > 0) and (DuplicateIPs(NewClient) >= ClientMaxIPs) Then Begin
      Inc (ClientRefused);
      Status('MULTI: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'dupeip.txt') Then NewClient.WriteLine('Only ' + strI2S(ClientMaxIPs) + ' connection(s) per user');
      WaitMS(3000);
      NewClient.Free;
    End Else Begin
      Inc (ClientTotal);
      Inc (ClientActive);
      Status ('Connect: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');

      NewClientProc(Self, Config, NodeInfo, NewClient);
    End;
  Until Terminated;

  Status ('Shutting down server...');
End;

Destructor TServerManager.Destroy;
Var
  Count : LongInt;
  Angry : Byte;
Begin
  Angry := 20; // about 5 seconds before we get mad at thread...

  ClientList.Pack;

  While (ClientList.Count > 0) and (Angry > 0) Do Begin
    For Count := 0 To ClientList.Count - 1 Do
      If ClientList[Count] <> NIL Then Begin
        TServerClient(ClientList[Count]).Client.Disconnect;
        TServerClient(ClientList[Count]).Terminate;
      End;

    WaitMS(250);

    Dec (Angry);

    ClientList.Pack;
  End;

  DoneCriticalSection(Critical);

  ClientList.Free;
  ServerStatus.Free;
  Server.Free;

  Inherited Destroy;
End;

Constructor TServerClient.Create (Owner: TServerManager; CliSock: TIOSocket);
Var
  Count : Byte;
Begin
  Manager := Owner;
  Client  := CliSock;

  For Count := 0 to Manager.ClientMax - 1 Do
    If Manager.ClientList[Count] = NIL Then Begin
      Manager.ClientList[Count] := Self;
      Break;
    End;

  Inherited Create(False);

  FreeOnTerminate := True;
End;

Destructor TServerClient.Destroy;
Begin
  Client.Free;

  Manager.ClientList[Manager.ClientList.IndexOf(Self)] := NIL;

  If Manager.Server <> NIL Then
    Manager.StatusUpdated := True;

  Dec (Manager.ClientActive);

  Inherited Destroy;
End;

End.

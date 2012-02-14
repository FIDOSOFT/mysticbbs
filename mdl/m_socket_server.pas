{$I M_OPS.PAS}

Unit m_Socket_Server;

Interface

Uses
  Classes,
  m_Socket_Class;

Type
  TServerManager    = Class;
  TServerClient     = Class;
  TServerCreateProc = Function (Manager: TServerManager; Client: TSocketClass): TServerClient;

  TServerManager = Class(TThread)
    Server        : TSocketClass;
    ClientList    : TList;
    NewClientProc : TServerCreateProc;
    ClientMax     : LongInt;
    ClientMaxIPs  : LongInt;
    ClientRefused : LongInt;
    ClientBlocked : LongInt;
    ClientTotal   : LongInt;
    ClientActive  : LongInt;
    Port          : LongInt;
    TextPath      : String[80];

    Constructor Create (PortNum, Max: Word; CreateProc: TServerCreateProc);
    Destructor  Destroy; Override;
    Procedure   Execute; Override;
    Function    CheckIP (IP, Mask: String) : Boolean;
    Function    IsBlockedIP (Var Client: TSocketClass) : Boolean;
    Function    DuplicateIPs (Var Client: TSocketClass) : Byte;
//    Procedure   Status (Str: String);
  End;

  TServerClient = Class(TThread)
    Client  : TSocketClass;
    Manager : TServerManager;

    Constructor Create (Owner: TServerManager; CliSock: TSocketClass);
    Destructor  Destroy; Override;
  End;

  //TServerTextClient = Class(TServerClient)
  //End;

Implementation

Uses
  m_Strings,
  m_DateTime;

Constructor TServerManager.Create (PortNum, Max: Word; CreateProc: TServerCreateProc);
Var
  Count : Byte;
Begin
  Inherited Create(False);

  Port          := PortNum;
  ClientMax     := Max;
  ClientRefused := 0;
  ClientBlocked := 0;
  ClientTotal   := 0;
  ClientActive  := 0;
  ClientMaxIPs  := 0;
  NewClientProc := CreateProc;
  Server        := TSocketClass.Create;
  ClientList    := TList.Create;
  TextPath      := '';

  For Count := 1 to ClientMax Do
    ClientList.Add(NIL);

  FreeOnTerminate := False;
End;

(*
Procedure TServerManager.Status (Str: String);
Begin
  If Server.SocketStatus = NIL Then
    While Server.SocketStatus = NIL Do Begin
      WriteLn('ITS NIL');
    End;

  Server.Status(Str);
End;
*)

Function TServerManager.CheckIP (IP, Mask: String) : Boolean;
Var
  A     : Byte;
  Count : Byte;
  Str   : String;
  Str2  : String;
  EndIt : Byte;
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

Function TServerManager.IsBlockedIP (Var Client: TSocketClass) : Boolean;
Var
  TF  : Text;
  Str : String;
Begin
  Result   := False;
  FileMode := 66;

  Assign (TF, TextPath + 'badip.txt');
  Reset  (TF);

  If IoResult <> 0 Then Exit;

  While Not Eof(TF) Do Begin
    ReadLn (TF, Str);
    If CheckIP (Client.PeerIP, Str) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (TF);
End;

Function TServerManager.DuplicateIPs (Var Client: TSocketClass) : Byte;
Var
  Count : Byte;
Begin
  Result := 0;

  For Count := 0 to ClientMax - 1 Do
    If ClientList[Count] <> NIL Then
      If Client.PeerIP = TSocketClass(ClientList[Count]).PeerIP Then
        Inc(Result);
End;

Procedure TServerManager.Execute;
Var
  NewClient : TSocketClass;
Begin
  Repeat Until Server <> NIL;  // Synchronize with server class
  Repeat Until Server.SocketStatus <> NIL; // Syncronize with status class

  Server.WaitInit(Port);

  If Terminated Then Exit;

  Server.Status('Opening server socket on port ' + strI2S(Port));

  Repeat
    NewClient := Server.WaitConnection;

    If NewClient = NIL Then Break;  // time to shutdown the server...

    If (ClientMax > 0) And (ClientActive >= ClientMax) Then Begin
      Inc (ClientRefused);
      Server.Status ('BUSY: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'busy.txt') Then NewClient.WriteLine('BUSY');
      NewClient.Free;
    End Else
    If IsBlockedIP(NewClient) Then Begin
      Inc (ClientBlocked);
      Server.Status('BLOCK: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'blocked.txt') Then NewClient.WriteLine('BLOCKED');
      NewClient.Free;
    End Else
    If (ClientMaxIPs > 0) and (DuplicateIPs(NewClient) > ClientMaxIPs) Then Begin
      Inc (ClientRefused);
      Server.Status('MULTI: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      If Not NewClient.WriteFile(TextPath + 'dupeip.txt') Then NewClient.WriteLine('Only ' + strI2S(ClientMaxIPs) + ' connection(s) per user');
      NewClient.Free;
    End Else Begin
      Inc (ClientTotal);
      Inc (ClientActive);
      Server.Status ('Connect: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');
      NewClientProc(Self, NewClient);
    End;
  Until Terminated;

  Server.Status ('Shutting down server...');
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

  ClientList.Free;
  Server.Free;

  Inherited Destroy;
End;

Constructor TServerClient.Create (Owner: TServerManager; CliSock: TSocketClass);
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
    Manager.Server.StatusUpdated := True;

  Dec (Manager.ClientActive);

  Inherited Destroy;
End;

End.

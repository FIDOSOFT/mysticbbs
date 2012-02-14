{$I M_OPS.PAS}

Unit MIS_Client_Telnet;

Interface

Uses
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  {$IFDEF WIN32}
    Windows,
  {$ENDIF}
  m_Strings,
  m_Socket_Class,
  MIS_Common,
  MIS_NodeData,
  MIS_Server;

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
{ must match server create or there will be access violations }

Type
  TTelnetServer = Class(TServerClient)
    ND : TNodeData;
    Constructor Create (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;
  End;

Implementation

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TSocketClass) : TServerClient;
Begin
  Result := TTelnetServer.Create(Owner, ND, CliSock);
End;

Constructor TTelnetServer.Create (Owner: TServerManager; ND: TNodeData; CliSock: TSocketClass);
Begin
  Inherited Create(Owner, CliSock);

  Self.ND := ND;
End;

{$IFDEF WIN32}
Procedure TTelnetServer.Execute;
Var
  Cmd : String;
  SI  : TStartupInfo;
  PI  : TProcessInformation;
  Num : LongInt;
  NI  : TNodeInfoRec;
  PassHandle : LongInt;
Begin
    If Not DuplicateHandle (
      GetCurrentProcess,
      Client.FSocketHandle,
      GetCurrentProcess,
      @PassHandle,
      0,
      TRUE,
      DUPLICATE_SAME_ACCESS) Then Exit;

  Num := ND.GetFreeNode;
  Cmd := 'mystic.exe -n' + strI2S(Num) + ' -TID' + strI2S(PassHandle) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName + #0;

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

	ND.SetNodeInfo(Num, NI);

  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);

  SI.dwFlags     := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_SHOWMINNOACTIVE;

  If CreateProcess(NIL, PChar(@Cmd[1]),
    NIL, NIL, True, create_new_console + normal_priority_class, NIL, NIL, SI, PI) Then
      WaitForSingleObject (PI.hProcess, INFINITE);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);
End;
{$ENDIF}

{$IFDEF UNIX}
Procedure TTelnetServer.Execute;
Var
  Cmd : String;
  Num : LongInt;
  NI  : TNodeInfoRec;
  PassHandle : LongInt;
Begin
  PassHandle := Client.FSocketHandle;

  Num := ND.GetFreeNode;
  Cmd := './mystic -n' + strI2S(Num) + ' -TID' + strI2S(PassHandle) + ' -UID' + Client.FPeerIP;

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

	ND.SetNodeInfo(Num, NI);

  fpSystem(Cmd);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);
End;
{$ENDIF}

Destructor TTelnetServer.Destroy;
Begin
  Inherited Destroy;
End;

End.

{$I M_OPS.PAS}

Unit MIS_Client_Telnet;

Interface

Uses
  {$IFDEF UNIX}
    Unix,
    Classes,
    Process,
    SysUtils,
    m_FileIO,
  {$ENDIF}
  {$IFDEF WINDOWS}
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
    ND       : TNodeData;
    Snooping : Boolean;
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

  Self.ND  := ND;
  Snooping := False;
End;

{$IFDEF WINDOWS}
Procedure TTelnetServer.Execute;
Var
  Cmd        : String;
  SI         : TStartupInfo;
  PI         : TProcessInformation;
  Num        : LongInt;
  NI         : TNodeInfoRec;
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
    NIL, NIL, True, Create_New_Console + Normal_Priority_Class, NIL, NIL, SI, PI) Then
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
Const
  BufferSize = 4096;
Var
  Cmd    : String;
  Num    : LongInt;
  NI     : TNodeInfoRec;
  Proc   : TProcess;
  Buffer : Array[1..BufferSize] of Char;
  bRead  : LongInt;
  bWrite : LongInt;
Begin
  Proc := TProcess.Create(Nil);
  Num  := ND.GetFreeNode;

  Proc.CommandLine := 'mystic -n' + strI2S(Num) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName;
  Proc.Options     := [poUsePipes];

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  Proc.Execute;

  While Proc.Running Do Begin
    If Proc.Output.NumBytesAvailable > 0 Then Begin
      While Proc.Output.NumBytesAvailable > 0 Do Begin
        bRead := Proc.Output.Read(Buffer, BufferSize);
        Client.WriteBuf (Buffer, bRead);

        If Snooping Then
          Term.ProcessBuf(Buffer[1], bRead);
      End;
    End Else
    If Client.DataWaiting Then Begin
      bWrite := Client.ReadBuf(Buffer, BufferSize);

      If bWrite < 0 Then Break;

      If bWrite > 0 Then Begin
        Proc.Input.Write(Buffer, bWrite);
      End;
    End Else
      Sleep(10);
  End;

  Proc.Free;

  FileErase (bbsConfig.DataPath + 'chat' + strI2S(NI.Num) + '.dat');

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

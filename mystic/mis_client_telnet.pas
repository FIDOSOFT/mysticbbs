Unit MIS_Client_Telnet;

{$I M_OPS.PAS}

Interface

{$IFDEF DARWIN}
  {$DEFINE USEPROCESS}
{$ELSE}
  {$IFDEF UNIX}
    {$DEFINE USEFORK}
  {$ENDIF}

  {$IFDEF USEFORK}
    {$IFDEF CPU32}
      {$LinkLib libutil.a}
    {$ENDIF}
    {$IFDEF CPU64}
      {$LinkLib libutil.a}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

Uses
  {$IFDEF USEPROCESS}
    Process,
    m_DateTime,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
    Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
    Windows,
  {$ENDIF}
  m_io_Base,
  m_io_Sockets,
  m_FileIO,
  m_Strings,
  MIS_Common,
  MIS_NodeData,
  MIS_Server,
  BBS_Records,
  BBS_DataBase;

{$IFDEF USEFORK}
  function forkpty(__amaster:Plongint; __name:Pchar; __termp:Pointer; __winp:Pointer):longint;cdecl;external 'c' name 'forkpty';
{$ENDIF}

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  TTelnetServer = Class(TServerClient)
    ND : TNodeData;

    Constructor Create (Owner: TServerManager; NewND: TNodeData; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;
  End;

Implementation

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TTelnetServer.Create(Owner, ND, CliSock);
End;

Constructor TTelnetServer.Create (Owner: TServerManager; NewND: TNodeData; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Self.ND := NewND;
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

  SI.dwFlags := STARTF_USESHOWWINDOW;

  If bbsCfg.inetTNHidden Then
    SI.wShowWindow := SW_HIDE
  Else
    SI.wShowWindow := SW_SHOWMINNOACTIVE;

  If CreateProcess(NIL, PChar(@Cmd[1]),
    NIL, NIL, True, Create_New_Console + Normal_Priority_Class, NIL, NIL, SI, PI) Then
      WaitForSingleObject (PI.hProcess, INFINITE);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(Num) + '.dat');
End;
{$ENDIF}

{$IFDEF USEFORK}
Procedure TTelnetServer.Execute;
Var
  Num     : LongInt;
  NI      : TNodeInfoRec;
  PID     : LongInt;
  PTYFD   : LongInt;
  RDFDSET : TFDSet;
  Count   : LongInt;
  Buffer  : Array[1..8 * 1024] of Char;
  MaxFD   : LongInt;
Begin
  Client.FTelnetServer := True;

  Num := ND.GetFreeNode;

  PID := ForkPTY (@PTYFD, NIL, NIL, NIL);

  If PID = 0 Then Begin
    fpSetSID;
    //tcSetPGrp (0, fpGetPID);

    fpExecLP ('./mystic', ['-n' + strI2S(Num), '-TID' + strI2S(Client.FSocketHandle), '-IP' + Client.FPeerIP, '-HOST' + Client.FPeerName]);

    Exit;
  End Else
  If PID = -1 Then
    Exit;

  FillChar (NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  MaxFD := Client.FSocketHandle;

  If PTYFD > Client.FSocketHandle Then MaxFD := PTYFD;

  Repeat
    fpFD_ZERO (RDFDSET);
    fpFD_SET  (PTYFD, RDFDSET);
    fpFD_SET  (Client.FSocketHandle, RDFDSET);

    If fpSelect (MaxFD + 1, @RDFDSET, NIL, NIL, 3000) < 0 Then Break;

    If fpFD_ISSET(PTYFD, RDFDSET) = 1 Then Begin
      Count := fpRead (PTYFD, Buffer, SizeOf(Buffer));

      If Count <= 0 Then Break;

      Client.WriteBuf (Buffer, Count);
    End;

    If fpFD_ISSET(Client.FSocketHandle, RDFDSET) = 1 Then Begin
      Count := Client.ReadBuf (Buffer, SizeOf(Buffer));

      If Count < 0 Then Break;

      If fpWrite (PTYFD, Buffer, Count) <> Count Then Break;
    End;
  Until False;

  fpClose (PTYFD);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

{$IFDEF USEPROCESS}
Procedure TTelnetServer.Execute;
Var
  Cmd    : String;
  Num    : LongInt;
  NI     : TNodeInfoRec;
  Proc   : TProcess;
  Buffer : TIOBuffer;
  bRead  : LongInt;
  bWrite : LongInt;
Begin
  Client.FTelnetServer := True;

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

  While Proc.Running Or (Proc.Output.NumBytesAvailable > 0) Do Begin
    If Proc.Output.NumBytesAvailable > 0 Then Begin
      bRead := Proc.Output.Read(Buffer, TIOBufferSize);
      Client.WriteBufEscaped (Buffer, bRead);
    End Else
    If Client.DataWaiting Then Begin
      bWrite := Client.ReadBuf(Buffer, TIOBufferSize);

      If bWrite < 0 Then Break;

      If bWrite > 0 Then Begin
        Proc.Input.Write(Buffer, bWrite);
      End;
    End Else
      WaitMS(10);
  End;

  Proc.Free;

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

Destructor TTelnetServer.Destroy;
Begin
  Inherited Destroy;
End;

End.

{$I M_OPS.PAS}

Unit MIS_Client_Telnet;

Interface

Uses
  {$IFDEF UNIX}
    Unix,
    Classes,
    Process,
    SysUtils,
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
      End;
    End Else
    If Client.DataWaiting Then Begin
      bWrite := Client.ReadBuf(Buffer, BufferSize);

      If bWrite < 0 Then Break;

      If bWrite > 0 Then
        Proc.Input.Write(Buffer, bWrite);
    End Else
      Sleep(25);
  End;

  Proc.Free;

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



program procoutlarge;
{
    Copyright (c) 2004-2011 by Marc Weustink and contributors

    This example is created in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}
// This is a
// WORKING
// demo program that shows
// how to launch an external program
// and read from its output.

uses
  Classes, Process, SysUtils;

const
  READ_BYTES = 2048;

var
  OurCommand: String;
  OutputLines: TStringList;
  MemStream: TMemoryStream;
  OurProcess: TProcess;
  NumBytes: LongInt;
  BytesRead: LongInt;

begin
  // A temp Memorystream is used to buffer the output
  MemStream := TMemoryStream.Create;
  BytesRead := 0;

  OurProcess := TProcess.Create(nil);
  // Recursive dir is a good example.
  OurCommand:='invalid command, please fix the IFDEFS.';
  {$IFDEF Windows}
  //Can't use dir directly, it's built in
  //so we just use the shell:
  OurCommand:='cmd.exe /c "dir /s d:\dev\code\mystic\"';
  {$ENDIF Windows}
  {$IFDEF Unix}
  //Needs to be tested on Linux/Unix:
  OurCommand := 'ls --recursive --all -l /';
  {$ENDIF Unix}
  writeln('-- Going to run: ' + OurCommand);
  OurProcess.CommandLine := OurCommand;

  // We cannot use poWaitOnExit here since we don't
  // know the size of the output. On Linux the size of the
  // output pipe is 2 kB; if the output data is more, we
  // need to read the data. This isn't possible since we are
  // waiting. So we get a deadlock here if we use poWaitOnExit.
  OurProcess.Options := [poUsePipes];
  WriteLn('-- External program run started');
  OurProcess.Execute;
  while OurProcess.Running do
  begin
    // make sure we have room
    MemStream.SetSize(BytesRead + READ_BYTES);

    // try reading it
    NumBytes := OurProcess.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
    if NumBytes > 0
    then begin
      Inc(BytesRead, NumBytes);
      Write('.') //Output progress to screen.
    end
    else begin
      // no data, wait 100 ms
      Sleep(100);
    end;
  end;
  // read last part
  repeat
    // make sure we have room
    MemStream.SetSize(BytesRead + READ_BYTES);
    // try reading it
    NumBytes := OurProcess.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
    if NumBytes > 0
    then begin
      Inc(BytesRead, NumBytes);
      Write('.');
    end;
  until NumBytes <= 0;
  if BytesRead > 0 then WriteLn;
  MemStream.SetSize(BytesRead);
  WriteLn('-- External program run complete');

  OutputLines := TStringList.Create;
  OutputLines.LoadFromStream(MemStream);
  WriteLn('-- External program output line count = ', OutputLines.Count, ' --');
  for NumBytes := 0 to OutputLines.Count - 1 do
  begin
    WriteLn(OutputLines[NumBytes]);
  end;
  WriteLn('-- Program end');
  OutputLines.Free;
  OurProcess.Free;
  MemStream.Free;
end.

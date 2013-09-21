Program FidoPoll;

{$I M_OPS.PAS}

Uses
  DOS,
  m_Crypt,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_IO_Sockets,
  m_Protocol_Queue,
  BBS_Records,
  BBS_DataBase,
  MIS_Client_BINKP;

Var
  TempPath : String;

Procedure PrintStatus (Owner: Pointer; Level: Byte; Str: String);
Var
  TF : Text;
Begin
  If Level = 1 Then
    WriteLn (Str)
  Else
    Str := '   ' + Str;

  Str      := FormatDate(CurDateDT, 'NNN DD HH:II') + ' ' + Str;
  FileMode := 66;

  Assign (TF, bbsCfg.LogsPath + 'fidopoll.log');

  {$I-} Append (TF); {$I+}

  If (IoResult <> 0) and (IoResult <> 5) Then
    {$I-} ReWrite(TF); {$I+}

  If IoResult = 0 Then Begin
    WriteLn (TF, Str);
    Close   (TF);
  End;
End;

Function PollNodeDirectory (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Begin
  Result := False;
End;

Function PollNodeFTP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus(NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling FTP node ' + Addr2Str(EchoNode.Address));
End;

Function PollNodeBINKP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  BinkP  : TBinkP;
  Client : TIOSocket;
  Port   : Word;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus(NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling BINKP node ' + Addr2Str(EchoNode.Address));

  Client := TIOSocket.Create;

  Client.FTelnetClient := False;
  Client.FTelnetServer := False;

  PrintStatus (NIL, 1, 'Connecting to ' + EchoNode.binkHost);

  Port := strS2I(strWordGet(2, EchoNode.binkHost, ':'));

  If Port = 0 Then Port := 24554;

  If Not Client.Connect (strWordGet(1, EchoNode.binkHost, ':'), Port) Then Begin
    PrintStatus (NIL, 1, 'UNABLE TO CONNECT');

    Client.Free;

    Exit;
  End;

  PrintStatus(NIL, 1, 'Connected');

  BinkP := TBinkP.Create(Client, Client, Queue, True, EchoNode.binkTimeOut * 100);

  BinkP.StatusUpdate := @PrintStatus;
  BinkP.SetOutPath   := GetFTNOutPath(EchoNode);
  BinkP.SetPassword  := EchoNode.binkPass;
  BinkP.SetBlockSize := EchoNode.binkBlock;
  BinkP.UseMD5       := EchoNode.binkMD5 > 0;
  BinkP.ForceMD5     := EchoNode.binkMD5 = 2;

  If BinkP.DoAuthentication Then Begin
    Result := True;

    BinkP.DoTransfers;
  End;

  BinkP.Free;
  Client.Free;
End;

Function PollByAddress (Addr: String) : Boolean;
Var
  Queue    : TProtocolQueue;
  PollTime : LongInt;
  EchoNode : RecEchoMailNode;
Begin
  PollTime := CurDateDos;
  Queue    := TProtocolQueue.Create;

  Result := GetNodeByAddress(Addr, EchoNode);

  If Result And EchoNode.Active Then Begin
    Case EchoNode.ProtType of
      0 : If PollNodeBINKP(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
      1 : If PollNodeFTP(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
      2 : If PollNodeDirectory(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
    End;

    // needs to save updated polltime
  End Else
    Result := False;

  Queue.Free;
End;

Procedure PollAll (OnlyNew: Boolean);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
  PollTime : LongInt;
Begin
  PollTime := CurDateDos;

  WriteLn ('Polling nodes...');
  WriteLn;

  Total := 0;
  Queue := TProtocolQueue.Create;

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If EchoNode.Active Then Begin
      Case EchoNode.ProtType of
        0 : If PollNodeBINKP(OnlyNew, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
        1 : If PollNodeFTP(OnlyNew, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
        2 : If PollNodeDirectory(False, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
      End;

      Seek  (EchoFile, FilePos(EchoFile) - 1);
      Write (EchoFile, EchoNode);
    End;
  End;

  Close (EchoFile);

  Queue.Free;

  WriteLn;
  PrintStatus (NIL, 1, 'Polled ' + strI2S(Total) + ' nodes');
End;

Var
  Str : String;
Begin
  FileMode := 66;

  WriteLn;
  WriteLn ('FIDOPOLL Version ' + mysVersion);
  WriteLn;

  Case bbsCfgStatus of
    CfgNotFound : Begin
                    WriteLn ('Unable to read MYSTIC.DAT');
                    Halt(1);
                  End;
    CfgMisMatch : Begin
                    WriteLn ('Mystic VERSION mismatch');
                    Halt(1);
                  End;
  End;

  If ParamCount = 0 Then Begin
    WriteLn ('This will likely be a temporary program which will be fused into');
    WriteLn ('either MIS or MUTIL in the future (or both). Note only BINKP is');
    WriteLn ('currently supported.  FTN via FTP may be included in the future');
    WriteLn;
    WriteLn ('FIDOPOLL SEND      - Only send/poll if node has new outbound messages');
    WriteLn ('FIDOPOLL FORCED    - Poll/send to all configured/activenodes');
    WriteLn ('FIDOPOLL [Address] - Poll/send echomail node [Address] (ex: 46:1/100)');

    Halt(1);
  End;

  TempPath := bbsCfg.SystemPath + 'tempftn' + PathChar;

  DirCreate(TempPath);

  Str := strUpper(strStripB(ParamStr(1), ' '));

  If (Str = 'SEND') or (Str = 'FORCED') Then
    PollAll (Str = 'SEND')
  Else
  If Not PollByAddress(Str) Then
    PrintStatus (NIL, 1, 'Invalid command line or address');
End.

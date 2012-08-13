// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

{$I M_OPS.PAS}

Program MIS;

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  {$IFDEF UNIX}
    cThreads,
    BaseUnix,
  {$ENDIF}
  DOS,
  m_Output,
  m_Input,
  m_DateTime,
  m_io_Base,
  m_io_Sockets,
  m_FileIO,
  m_Strings,
  m_Term_Ansi,
  MIS_Common,
  MIS_NodeData,
  MIS_Server,
  MIS_Client_Telnet,
  MIS_Client_SMTP,
  MIS_Client_POP3,
  MIS_Client_FTP,
  MIS_Client_NNTP;

Const
  FocusTelnet = 0;
  FocusSMTP   = 1;
  FocusPOP3   = 2;
  FocusFTP    = 3;
  FocusNNTP   = 4;
  FocusMax    = 4;

Var
  Keyboard     : TInput;
  TelnetServer : TServerManager;
  FTPServer    : TServerManager;
  POP3Server   : TServerManager;
  SMTPServer   : TServerManager;
  NNTPServer   : TServerManager;
  FocusPTR     : TServerManager;
  FocusCurrent : Byte;
  TopPage      : Integer;
  BarPos       : Integer;
  NodeData     : TNodeData;
  DaemonMode   : Boolean = False;

{$I MIS_ANSIWFC.PAS}

Procedure ReadConfiguration;
Var
  FileConfig : TBufFile;
  DatLoc     : String;
Begin
  DatLoc := GetEnv('mysticbbs');

  If DatLoc <> '' Then DatLoc := DirSlash(DatLoc);

  FileConfig := TBufFile.Create(SizeOf(RecConfig));

  If Not FileConfig.Open(DatLoc + 'mystic.dat', fmOpen, fmReadWrite + fmDenyNone, SizeOf(RecConfig)) Then Begin
    WriteLn;
    WriteLn ('ERROR: Unable to read MYSTIC.DAT.  This file must exist in the same');
    WriteLn ('directory as MIS');
    Halt (1);
  End;

  FileConfig.Read(bbsConfig);
  FileConfig.Free;

  If bbsConfig.DataChanged <> mysDataChanged Then Begin
    WriteLn('ERROR: Data files are not current and must be upgraded.');
    Halt(1);
  End;

  DirChange(bbsConfig.SystemPath);
End;

Procedure ReadChatData;
Var
  ChatFile : File of ChatRec;
  Chat     : ChatRec;
  Nodes    : LongInt;
  Count    : LongInt;
  NI       : TNodeInfoRec;
Begin
  Nodes := NodeData.GetNodeTotal;

  For Count := 1 to Nodes Do
    If NodeData.GetNodeInfo(Count, NI) Then Begin
      Assign (ChatFile, bbsConfig.DataPath + 'chat' + strI2S(NI.Num) + '.dat');

      If ioReset(ChatFile, SizeOf(ChatRec), fmReadWrite + fmDenyNone) Then Begin
        If ioRead(ChatFile, Chat) Then Begin
          If Chat.Active Then Begin
            NI.User   := Chat.Name;
            NI.Action := Chat.Action;

            NodeData.SetNodeInfo(NI.Num, NI);
          End;
        End;
      	Close (ChatFile);
      End;
    End;
End;

Function GetFocusPtr : TServerManager;
Begin
  Result := NIL;

  Case FocusCurrent of
    FocusTelnet : GetFocusPtr := TelnetServer;
    FocusSMTP   : GetFocusPtr := SMTPServer;
    FocusPOP3   : GetFocusPtr := POP3Server;
    FocusFTP    : GetFocusPtr := FTPServer;
    FocusNNTP   : GetFocusPtr := NNTPServer;
  End;
End;

Procedure UpdateConnectionList;
Var
  Count : Byte;
  Attr  : Byte;
  PosY  : Byte;
  NI    : TNodeInfoRec;
Begin
  If FocusPtr = NIL Then Exit;

  ReadChatData;

  PosY := 0;

  For Count := TopPage to TopPage + 7 Do Begin
  	NodeData.GetNodeInfo(Count, NI);

    Inc (PosY);

    If Count = BarPos Then Attr := 31 Else Attr := 7;

    Case FocusCurrent of
        0 : If (Count <= FocusPtr.ClientList.Count) And (FocusPtr.ClientList[Count - 1] <> NIL) Then Begin
              Console.WriteXY (3, 3 + PosY, Attr,
      	        strPadL(strI2S(NI.Num), 3, '0') + ' ' +
                strPadR(NI.User, 12, ' ') + ' ' +
                strPadR(NI.Action, 18, ' ') + ' ' +
                strPadL(NI.IP, 15, ' '));
            End Else
            If Count <= FocusPtr.ClientMax Then
              Console.WriteXY (3, 3 + PosY, Attr, strPadL(strI2S(NI.Num), 3, '0') + strPadR(' Waiting', 48, ' '))
            Else
              Console.WriteXY (3, 3 + PosY, Attr, strRep(' ', 51));
        1,
        2,
        3,
        4: If (Count <= FocusPtr.ClientList.Count) And (FocusPtr.ClientList[Count - 1] <> NIL) Then Begin
              Console.WriteXY (3, 3 + PosY, Attr,
                strPadL(strI2S(Count), 3, '0') + ' ' +
                strPadR(TFTPServer(FocusPtr.ClientList[Count - 1]).User.Handle, 31, ' ') + ' ' +
                strPadL(TFTPServer(FocusPtr.ClientList[Count - 1]).Client.PeerIP, 15, ' '));
            End Else
            If Count <= FocusPtr.ClientMax Then
              Console.WriteXY (3, 3 + PosY, Attr, strPadL(strI2S(Count), 3, '0') + strPadR(' Waiting', 48, ' '))
            Else
              Console.WriteXY (3, 3 + PosY, Attr, strRep(' ', 51));
    End;
  End;
End;

Procedure UpdateStatus;
Var
  Offset : Integer;
  Count  : Integer;
Begin
  If FocusPtr = NIL Then Exit;

  FocusPtr.StatusUpdated := False;

  // UPDATE CONNECTION STATS

  Console.WriteXY (69,  7, 7, strPadR(strI2S(FocusPtr.ClientActive), 5, ' '));
  Console.WriteXY (69,  8, 7, strPadR(strI2S(FocusPtr.ClientBlocked), 5, ' '));
  Console.WriteXY (69,  9, 7, strPadR(strI2S(FocusPtr.ClientRefused), 5, ' '));
  Console.WriteXY (69, 10, 7, strPadR(strI2S(FocusPtr.ClientTotal), 5, ' '));

  // UPDATE STATUS MESSAGES

  Offset := FocusPtr.ServerStatus.Count;

  For Count := 22 DownTo 15 Do Begin
    If Offset > 0 Then Begin
      Dec(Offset);
      Console.WriteXY (4, Count, 7, strPadR(FocusPtr.ServerStatus.Strings[Offset], 74, ' '));
    End Else
      Console.WriteXY (4, Count, 7, strPadR(' ', 74, ' '));
  End;

  UpdateConnectionList;
End;

Procedure SwitchFocus;
Begin
  BarPos  := 1;
  TopPage := 1;

  Repeat
    If FocusCurrent = FocusMax Then FocusCurrent := 0 Else Inc(FocusCurrent);

    Case FocusCurrent of
      FocusTelnet : If TelnetServer <> NIL Then Break;
      FocusSMTP   : If SmtpServer <> NIL Then Break;
      FocusPOP3   : If Pop3Server <> NIL Then Break;
      FocusFTP    : If FtpServer <> NIL Then Break;
      FocusNNTP   : If NNTPServer <> NIL Then Break;
    End;
  Until False;

  Console.WriteXY (50, 1, 112, 'telnet/smtp/pop3/ftp/nntp/http');

  Case FocusCurrent of
    FocusTelnet : Console.WriteXY (50, 1, 113, 'TELNET');
    FocusSMTP   : Console.WriteXY (57, 1, 113, 'SMTP');
    FocusPOP3   : Console.WriteXY (62, 1, 113, 'POP3');
    FocusFTP    : Console.WriteXY (67, 1, 113, 'FTP');
    FocusNNTP   : Console.WriteXY (71, 1, 113, 'NNTP');
  End;

  FocusPtr := GetFocusPtr;

  If FocusPtr <> NIL Then Begin
    Console.WriteXY (69, 5, 7, strPadR(strI2S(FocusPtr.Port), 5, ' '));
    Console.WriteXY (69, 6, 7, strPadR(strI2S(FocusPtr.ClientMax), 5, ' '));

    UpdateStatus;
  End;
End;

Procedure LocalLogin;
Const
  BufferSize = 1024 * 4;
Var
  Client : TIOSocket;
  Res    : LongInt;
  Buffer : Array[1..BufferSize] of Char;
  Done   : Boolean;
  Ch     : Char;
Begin
  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.WriteStr ('Connecting to 127.0.0.1... ');

  Client := TIOSocket.Create;

  If Not Client.Connect('127.0.0.1', bbsConfig.InetTNPort) Then
    Console.WriteLine('Unable to connect')
  Else Begin
    Done := False;
    Term := TTermAnsi.Create(Console);

    Console.SetWindow (1, 1, 80, 24, True);
    Console.WriteXY   (1, 25, 112, strPadC('Local TELNET: ALT-X to Quit', 80, ' '));

    Term.SetReplyClient(TIOBase(Client));

    Repeat
      If Client.WaitForData(0) > 0 Then Begin
        Repeat
          Res := Client.ReadBuf (Buffer, BufferSize);

          If Res < 0 Then Begin
            Done := True;
            Break;
          End;

          Term.ProcessBuf(Buffer, Res);
        Until Res <> BufferSize;
      End Else
      If Keyboard.KeyPressed Then Begin
        Ch := Keyboard.ReadKey;
        Case Ch of
          #00 : Case Keyboard.ReadKey of
                  #45 : Break;
                  #71 : Client.WriteStr(#27 + '[H');
                  #72 : Client.WriteStr(#27 + '[A');
                  #73 : Client.WriteStr(#27 + '[V');
                  #75 : Client.WriteStr(#27 + '[D');
                  #77 : Client.WriteStr(#27 + '[C');
                  #79 : Client.WriteStr(#27 + '[K');
                  #80 : Client.WriteStr(#27 + '[B');
                  #81 : Client.WriteStr(#27 + '[U');
                  #83 : Client.WriteStr(#127);
                End;
        Else
          Client.WriteBuf(Ch, 1);
          If Client.FTelnetEcho Then Term.Process(Ch);
        End;
      End Else
        WaitMS(5);
    Until Done;

    Term.Free;
  End;

  Client.Free;

  Console.TextAttr := 7;
  Console.SetWindow (1, 1, 80, 25, True);

  FocusCurrent := FocusMax;
  DrawStatusScreen;
  SwitchFocus;
End;

{$IFDEF UNIX}
Procedure SetUserOwner;
Var
  Info   : Stat;
  MysLoc : String;
Begin
  MysLoc := GetEnv('mysticbbs');

  If MysLoc <> '' Then MysLoc := DirSlash(MysLoc);

  If fpStat(MysLoc + 'mis', Info) = 0 Then Begin
    fpSetGID (Info.st_GID);
    fpSetUID (Info.st_UID);
  End;
End;
{$ENDIF}

Function ServerStartup : Boolean;
Begin
  Result := False;

  ReadConfiguration;

  TelnetServer := NIL;
  FTPServer    := NIL;
  POP3Server   := NIL;
  NNTPServer   := NIL;
  NodeData     := TNodeData.Create(bbsConfig.INetTNNodes);

  If bbsConfig.InetTNUse Then Begin
    TelnetServer := TServerManager.Create(bbsConfig, bbsConfig.InetTNPort, bbsConfig.INetTNNodes, NodeData, @CreateTelnet);

    TelnetServer.Server.FTelnetServer := True;
    TelnetServer.ClientMaxIPs         := bbsConfig.InetTNDupes;

    Result := True;
  End;

  If bbsConfig.InetSMTPUse Then Begin
    SMTPServer := TServerManager.Create(bbsConfig, bbsConfig.INetSMTPPort, bbsConfig.inetSMTPMax, NodeData, @CreateSMTP);

    SMTPServer.Server.FTelnetServer := False;
    SMTPServer.ClientMaxIPs         := bbsConfig.INetSMTPDupes;

    Result := True;
  End;

  If bbsConfig.InetPOP3Use Then Begin
    POP3Server := TServerManager.Create(bbsConfig, bbsConfig.INetPOP3Port, bbsConfig.inetPOP3Max, NodeData, @CreatePOP3);

    POP3Server.Server.FTelnetServer := False;
    POP3Server.ClientMaxIPs         := bbsConfig.inetPOP3Dupes;

    Result := True;
  End;

  If bbsConfig.InetFTPUse Then Begin
    FTPServer := TServerManager.Create(bbsConfig, bbsConfig.InetFTPPort, bbsConfig.inetFTPMax, NodeData, @CreateFTP);

    FTPServer.Server.FTelnetServer := False;
    FTPServer.ClientMaxIPs         := bbsConfig.inetFTPDupes;

    Result := True;
  End;

  If bbsConfig.InetNNTPUse Then Begin
    NNTPServer := TServerManager.Create(bbsConfig, bbsConfig.InetNNTPPort, bbsConfig.inetNNTPMax, NodeData, @CreateNNTP);

    NNTPServer.Server.FTelnetServer := False;
    NNTPServer.ClientMaxIPs         := bbsConfig.inetNNTPDupes;

    Result := True;
  End;

  {$IFDEF UNIX}
    SetUserOwner;
  {$ENDIF}
End;

{$IFDEF UNIX}
Procedure Snoop;
Begin
  If FocusCurrent <> FocusTelnet Then Exit;

  If FocusPtr.ClientList[BarPos - 1] <> NIL Then Begin
    Term := TTermAnsi.Create(Console);

    Console.TextAttr := 7;

    Console.ClearScreen;

    Console.SetWindow (1, 1, 80, 24, True);
    Console.WriteXY   (1, 25, 112, strPadC('Snooping : Press [ESC] to Quit', 80, ' '));

    TTelnetServer(FocusPtr.ClientList[BarPos - 1]).Snooping := True;

    Repeat Until Keyboard.ReadKey = #27;

    If TTelnetServer(FocusPtr.ClientList[BarPos - 1]) <> NIL Then
      TTelnetServer(FocusPtr.ClientList[BarPos - 1]).Snooping := False;

    Term.Free;

    Console.TextAttr := 7;

    Console.SetWindow (1, 1, 80, 25, True);

    FocusCurrent := FocusMax;

    DrawStatusScreen;

    SwitchFocus;
  End;
End;

Procedure DaemonEventSignal (Sig : LongInt); cdecl;
Begin
  Case Sig of
    SIGTERM : Begin
                TelnetServer.Free;
                SMTPServer.Free;
                POP3Server.Free;
                FTPServer.Free;
                NNTPServer.Free;
                NodeData.Free;
                Halt(0);
              End;

  End;
End;

Procedure ExecuteDaemon;
Var
  PID : TPID;
  SID : TPID;
Begin
  WriteLn('- [MIS] Executing Mystic Internet Server in daemon mode');

  PID := fpFork;

  If PID < 0 Then Halt(1);
  If PID > 0 Then Halt(0);

  SID := fpSetSID;

  If SID < 0 Then Halt(1);

  Close (Input);
  Close (Output);
  //CLOSE STDERR?

  If Not ServerStartup Then Begin
    NodeData.Free;
    Halt(1);
  End;

  fpSignal (SIGTERM, DaemonEventSignal);

  Repeat
    WaitMS(60000);  // Heartbeat
  Until False;
End;
{$ENDIF}

Const
  WinTitle = 'Mystic Internet Server';

Var
  Count : Integer;
Begin
  {$IFDEF UNIX}
    DaemonMode := Pos('-D', strUpper(ParamStr(1))) > 0;
  {$ENDIF}

  Randomize;

  {$IFDEF DEBUG}
    SetHeapTraceOutput('mis.mem');
  {$ENDIF}

  {$IFDEF UNIX}
    If DaemonMode Then ExecuteDaemon;
  {$ENDIF}

  Console  := TOutput.Create(True);
  Keyboard := TInput.Create;

  Console.SetWindowTitle(WinTitle);

  If Not ServerStartup Then Begin
    Console.ClearScreen;
    Console.WriteLine('ERROR: No servers are configured as active.  Run MYSTIC -CFG to configure');
    Console.WriteLine('Internet server options.');

    NodeData.Free;
    Keyboard.Free;
    Console.Free;

    Halt(10);
  End;

  Count := 0;

  DrawStatusScreen;

  FocusCurrent := FocusMax;

  SwitchFocus;

  Repeat
    If Keyboard.KeyWait(500) Then
      Case Keyboard.ReadKey of
        #00 : Case Keyboard.ReadKey of
                #72 : If BarPos > TopPage Then Begin
                        Dec(BarPos);
                        UpdateConnectionList;
                      End Else
                      If TopPage > 1 Then Begin
                        Dec(TopPage);
                        Dec(BarPos);

                        UpdateConnectionList;
                      End;
                #75 : Begin
                        Dec (TopPage, 8);
                        Dec (BarPos, 8);

                        If TopPage < 1 Then TopPage := 1;
                        If BarPos  < 1 Then BarPos  := TopPage;

                        UpdateConnectionList;
                      End;
                #77 : Begin
                        Inc (TopPage, 8);
                        Inc (BarPos, 8);

                        If TopPage + 7 > FocusPtr.ClientList.Count Then TopPage := FocusPtr.ClientList.Count - 7;
                        If BarPos > FocusPtr.ClientList.Count Then BarPos := FocusPtr.ClientList.Count;
                        If TopPage < 1 Then TopPage := 1;
                        UpdateConnectionList;
                      End;

                #80 : If (BarPos < FocusPtr.ClientMax) and (BarPos < TopPage + 7) Then Begin
                        Inc(BarPos);
                        UpdateConnectionList;
                      End Else
                      If (TopPage + 7 < FocusPtr.ClientMax) Then Begin
                        Inc(TopPage);
                        Inc(BarPos);
                        UpdateConnectionList;
                      End;
              End;
        #09 : SwitchFocus;
        #13 : {$IFDEF UNIX}Snoop{$ENDIF};
        #27 : Break;
      	#32 : LocalLogin;
      End;

    If (FocusPtr <> NIL) Then
      If FocusPtr.StatusUpdated Then Begin
        UpdateStatus;
        Count := 1;
      End Else
      If Count = 10 Then Begin  // force update every 10 seconds since mystic
        UpdateStatus;           // cannot yet talk to MIS directly
        Count := 1;
      End Else
        Inc (Count);
  Until False;

  Console.TextAttr := 7;

  Console.ClearScreen;

  Console.WriteLine ('Mystic Internet Server Version ' + mysVersion);
  Console.WriteLine ('');
  Console.WriteStr  ('Shutting down servers: TELNET');

  TelnetServer.Free;

  Console.WriteStr (' SMTP');
  SMTPServer.Free;

  Console.WriteStr (' POP3');
  POP3Server.Free;

  Console.WriteStr (' FTP');
  FTPServer.Free;

  Console.WriteStr (' NNTP');
  NNTPServer.Free;

  Console.WriteLine (' (DONE)');

  NodeData.Free;
  Keyboard.Free;
  Console.Free;

  Halt(255);
End.

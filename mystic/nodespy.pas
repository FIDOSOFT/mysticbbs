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

Program NodeSpy;

// page chat notification
// user editor
// split chat
// terminal mode

{$I M_OPS.PAS}

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
  {$ENDIF}
  DOS,
  m_FileIO,
  m_DateTime,
  m_Strings,
  m_Pipe,
  m_Input,
  m_Output,
  m_Term_Ansi,
  m_IniReader,
  NodeSpy_Common,
  NodeSpy_Term;

Const
  HiddenNode  = 255;
  UpdateNode  = 500;
  UpdateStats = 6000 * 10;  // 10 minutes

  AutoSnoop   : Boolean = False;
  AutoSnoopID : LongInt = 0;

Type
  StatsRec = Record
    TotalDays      : LongInt;
    TodayCalls     : LongInt;
    TotalCalls     : LongInt;
    TodayNewUsers  : LongInt;
    TotalNewUsers  : LongInt;
    TodayPosts     : LongInt;
    TotalPosts     : LongInt;
    TodayEmail     : LongInt;
    TotalEmail     : LongInt;
    TodayDownloads : LongInt;
    TotalDownloads : LongInt;
    TodayUploads   : LongInt;
    TotalUploads   : LongInt;
    Weekly         : Array[0..6] of LongInt;
    Monthly        : Array[1..12] of LongInt;
    Hourly         : Array[0..23] of LongInt;
  End;

  PNodeInfo = ^TNodeInfo;
  TNodeInfo = Record
    ID     : LongInt;
    Node   : Byte;
    User   : String[30];
    Action : String[50];
  End;

Var
  Stats      : StatsRec;
  NodeInfo   : Array[1..255] of PNodeInfo;
  ChatFile   : File of ChatRec;
  Chat       : ChatRec;
  NodeFile   : File of NodeMsgRec;
  Msg        : NodeMsgRec;
  BasePath   : String;

{$I NODESPY_ANSI.PAS}

Procedure ApplicationShutdown;
Var
  Count : Byte;
Begin
  For Count := Config.inetTNNodes DownTo 1 Do
    If Assigned(NodeInfo[Count]) Then
      Dispose(NodeInfo[Count]);

  Keyboard.Free;
  Screen.Free;
End;

Procedure ApplicationInit;
Var
{$IFDEF UNIX}
  Info : Stat;
{$ENDIF}
  Count : Byte;
  INI   : TIniReader;
Begin
  {$IFDEF UNIX}
  If fpStat('nodespy', Info) = 0 Then Begin
    fpSetGID (Info.st_GID);
    fpSetUID (Info.st_UID);
  End;
  {$ENDIF}

  ExitProc := @ApplicationShutdown;
  Screen   := TOutput.Create(True);
  Keyboard := TInput.Create;

  INI := TIniReader.Create('nodespy.ini');

  AutoSnoop := INI.ReadString('General', 'autosnoop', '0') = '1';

  INI.Free;

  Assign (ConfigFile, 'mystic.dat');
  Reset  (ConfigFile);

  If IoResult <> 0 Then Begin
    BasePath := GetENV('mysticbbs');

    If BasePath <> '' Then BasePath := DirSlash(BasePath);

    Assign (ConfigFile, BasePath + 'mystic.dat');
    Reset  (ConfigFile);

    If IoResult <> 0 Then Begin
      Screen.WriteLine ('ERROR: Unable to read MYSTIC.DAT' + #13#10);
      Screen.WriteLine ('MYSTIC.DAT must exist in the same directory as NodeSpy, or in the');
      Screen.WriteLine ('path defined by the MYSTICBBS environment variable.');

      Halt (1);
    End;
  End;

  Read  (ConfigFile, Config);
  Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    Screen.WriteLine ('ERROR: NodeSpy has detected a version mismatch' + #13#10);
    Screen.WriteLine ('NodeSpy or another BBS utility is an older incompatible version.  Make');
    Screen.WriteLine ('sure you have upgraded properly!');

    Halt (1);
  End;

  DirCreate(Config.SystemPath + 'temp' + strI2S(HiddenNode));

  For Count := 1 to Config.inetTNNodes Do
    New (NodeInfo[Count]);
End;

Procedure MakeChatRecord;
Begin
  Assign (ChatFile, Config.DataPath + 'chat' + strI2S(HiddenNode) + '.dat');

  If Not ioReWrite (ChatFile, SizeOf(ChatFile), fmRWDN) Then Exit;

  Chat.Active    := True;
  Chat.Available := True;
  Chat.Name      := 'Sysop';
  Chat.Invisible := False;

  Write (ChatFile, Chat);
  Close (ChatFile);
End;

Function GetChatRecord (Node: Byte; Var Chat: ChatRec) : Boolean;
Begin
  Result := False;

  FillChar(Chat, SizeOf(Chat), 0);

  Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Node) + '.dat');

  If Not ioReset(ChatFile, SizeOf(ChatFile), fmRWDN) Then Exit;

  Read  (ChatFile, Chat);
  Close (ChatFile);

  Result := True;
End;

Function GetNodeMessage : Boolean;
Begin
  Result := False;

  Assign (NodeFile, Config.SystemPath + 'temp' + strI2S(HiddenNode) + PathChar + 'chat.tmp');

  If Not ioReset(NodeFile, SizeOf(Msg), fmReadWrite + fmDenyAll) Then
    Exit;

  If FileSize(NodeFile) = 0 Then Begin
    Close (NodeFile);
    Exit;
  End;

  Result := True;

  Read    (NodeFile, Msg);
  ReWrite (NodeFile);
  Close   (NodeFile);
End;

Procedure SendNodeMessage (Node, Cmd: Byte);
Begin
  If Not GetChatRecord(Node, Chat) Then Exit;

  If Not Chat.Active Then Exit;

  Msg.FromNode := HiddenNode;
  Msg.MsgType  := Cmd;
  FileMode     := 66;

  Assign  (NodeFile, Config.SystemPath + 'temp' + strI2S(Node) + PathChar + 'chat.tmp');

  If Not ioReset (NodeFile, SizeOf(Msg), fmReadWrite + fmDenyAll) Then
    ioReWrite(NodeFile, SizeOf(Msg), fmReadWrite + fmDenyAll);

  Seek  (NodeFile, FileSize(NodeFile));
  Write (NodeFile, Msg);
  Close (NodeFile);
End;

Procedure DoUserChat (Node: Byte);
Var
  TempChat : ChatRec;
  Count    : Byte;
  fOut     : File;
  fIn      : File;
  Ch       : Char;
  InRemote : Byte;
  Str1     : String = '';
  Str2     : String = '';
Begin
  If (Not GetChatRecord(Node, TempChat)) or
     (Not TempChat.Active) or (Not TempChat.Available) or (TempChat.InChat) Then Begin
       ShowMsgBox(0, 'User is not available for chat (in chat or door?)');
       Exit;
  End;

  ShowMsgBox(3, 'Sending chat request...');

  FileErase (Config.DataPath + 'userchat.' + strI2S(Node));
  FileErase (Config.DataPath + 'userchat.' + strI2S(HiddenNode));

  MakeChatRecord;

  SendNodeMessage(Node, 9);

  For Count := 1 to 100 Do Begin
    WaitMS(100);

    If GetNodeMessage Then
      If Msg.MsgType = 10 Then
        Break
      Else
        If Count = 20 Then Begin
          FileErase (Config.DataPath + 'chat' + strI2S(HiddenNode) + '.dat');
          Exit;
        End;
  End;

  FileErase (Config.DataPath + 'chat' + strI2S(HiddenNode) + '.dat');

  Screen.TextAttr := 7;
  Screen.ClearScreen;

  Screen.WriteXY  ( 1, 1, 31, strRep(' ', 79));
  Screen.WriteXY  ( 2, 1, 31, 'Chat mode engaged');
  Screen.WriteXY  (71, 1, 31, 'ESC/Quit');
  Screen.CursorXY (1, 3);

  FileMode := 66;

  Assign (fOut, Config.DataPath + 'userchat.' + strI2S(Node));
  Assign (fIn,  Config.DataPath + 'userchat.' + strI2S(HiddenNode));

  ReWrite (fOut, 1);
  ReWrite (fIn,  1);

  Repeat
    If Not Eof(fIn) Then Begin
      BlockRead (fIn, Ch, 1);

      If Ch = #255 Then Break;

      InRemote := 1;

      Screen.TextAttr := 11;
    End Else Begin
      If Keyboard.KeyWait(200) Then
        Ch := Keyboard.ReadKey
      Else
        Continue;

      Screen.TextAttr := 9;

      BlockWrite (fOut, Ch, 1);

      InRemote := 0;
    End;

    Case Ch of
      #08 : If Length(Str1) > 0 Then Begin
              Screen.WriteStr(#08#32#08);
              Dec (Str1[0]);
            End;
      #10 : ;
      #13 : Begin
              Str1 := '';
              Screen.WriteLine('');
            End;
      #27 : If InRemote = 0 Then Begin
              Ch := #255;
              BlockWrite(fOut, Ch, 1);
              Break;
            End;
    Else
      Str1 := Str1 + Ch;

      If Length(Str1) > 79 Then Begin
        strWrap(Str1, Str2, 79);

        For Count := 1 to Length(Str2) Do
          Screen.WriteStr(#08#32#08);

        Screen.WriteLine('');

        Str1 := Str2;

        Screen.WriteStr(Str1);
      End Else
        Screen.WriteChar(Ch);
    End;

    Screen.BufFlush;
  Until False;

  Close(fOut);
  Close(fIn);

  Erase(fOut);
  Erase(fIn);

  Screen.TextAttr := 7;

  Screen.ClearScreen;
End;

Procedure SnoopNode (Node: Byte);
Var
  Pipe    : TPipe;
  Buffer  : Array[1..4 * 1024] of Char;
  BufRead : LongWord;
  Update  : LongInt;

  Procedure DrawStatus;
  Var
    SX, SY, SA : Byte;
  Begin
    If Config.UseStatusBar Then Begin
      SX := Screen.CursorX;
      SY := Screen.CursorY;
      SA := Screen.TextAttr;

      Screen.WriteXY   ( 1, 25, Config.StatusColor1, strRep(' ', 79));
      Screen.WriteXY   ( 2, 25, Config.StatusColor1, 'User');
      Screen.WriteXY   ( 7, 25, Config.StatusColor2, Chat.Name);
      Screen.WriteXY   (54, 25, Config.StatusColor3, 'ALT (C)hat (K)ick e(X)it');
      Screen.SetWindow ( 1,  1, 80, 24, True);

      Screen.CursorXY (SX, SY);

      Screen.TextAttr := SA;
    End;
  End;

Begin
  ShowMsgBox (3, 'Requesting snoop session for node ' + strI2S(Node));

  SendNodeMessage(Node, 11);

  Pipe := TPipe.Create(Config.DataPath, True, Node);

  If Not Pipe.ConnectPipe(800) Then Begin
    ShowMsgBox (0, 'Unable to establish a session.  Try again');
    Pipe.Free;
    Exit;
  End;

  Term := TTermAnsi.Create(Screen);

  Screen.SetWindowTitle('NodeSpy/Snoop ' + strI2S(Node));

  DrawStatus;

  Screen.TextAttr := 7;
  Screen.ClearScreen;

  Update := TimerSet(UpdateNode);

  While Pipe.Connected Do Begin
    If Pipe.DataWaiting Then Begin
      Pipe.ReadFromPipe(Buffer, SizeOf(Buffer), BufRead);

      If BufRead <= 0 Then
        WaitMS(200)
      Else
        Term.ProcessBuf(Buffer, BufRead);
    End;

    If Keyboard.KeyPressed Then
      Case Keyboard.ReadKey of
        #00 : Case Keyboard.ReadKey of
                #37 : If ShowMsgBox(1, 'Kick this user?') Then Begin
                        SendNodeMessage(Node, 13);
                        Break;
                      End;
                #45 : Break;
                #46 : DoUserChat(Node);
              End;
        #27 : Break;
      End;

    If TimerUp(Update) Then Begin
      GetChatRecord (Node, Chat);

      If Not Chat.Active Then Break;

      DrawStatus;

      Update := TimerSet(UpdateNode);
    End;
  End;

  If Chat.Active Then SendNodeMessage(Node, 12);

  Screen.SetWindow (1, 1, 80, 25, False);
  Screen.CursorXY  (1, Screen.ScreenSize);

  Screen.TextAttr := 7;

  Pipe.Disconnect;
  Pipe.Free;
  Term.Free;

  AutoSnoopID := NodeInfo[Node]^.ID;
End;

Procedure UpdateOnlineStatus;
Var
  Count : LongInt;
Begin
  For Count := 1 to Config.inetTNNodes Do
    If GetChatRecord(Count, Chat) and (Chat.Active) Then Begin
      NodeInfo[Count]^.Node   := Count;
      NodeInfo[Count]^.User   := Chat.Name;
      NodeInfo[Count]^.Action := Chat.Action;

      If NodeInfo[Count]^.ID = 0 Then
        NodeInfo[Count]^.ID := CurDateDos + Count;
    End Else Begin
      NodeInfo[Count]^.ID     := 0;
      NodeInfo[Count]^.Node   := Count;
      NodeInfo[Count]^.User   := 'Waiting';
      NodeInfo[Count]^.Action := 'Waiting';
    End;
End;

Procedure MainMenu;
Var
  NodeTimer : LongInt;
  TopPage   : SmallInt = 1;
  CurNode   : SmallInt = 1;

  Procedure DrawStats;

    Procedure DrawBar (PosX: Byte; Value: Byte);
    Var
      Count : Byte;
    Begin
      For Count := 1 to 5 Do
        Screen.WriteXY (PosX, 23 - Count, 1, ' ');

      For Count := 1 to Value Do
        Screen.WriteXY (PosX, 23 - Count, 1, #219);
    End;

  Var
    Count : Byte;
  Begin
    Screen.WriteXY (12, 18, 9, strPadL(strI2S(Stats.TodayCalls), 6, ' '));
    Screen.WriteXY (12, 19, 9, strPadL(strI2S(Stats.TodayNewUsers), 6, ' '));
    Screen.WriteXY (12, 20, 9, strPadL(strI2S(Stats.TodayPosts), 6, ' '));
    Screen.WriteXY (12, 21, 9, strPadL(strI2S(Stats.TodayEmail), 6, ' '));
    Screen.WriteXY (12, 22, 9, strPadL(strI2S(Stats.TodayDownloads), 6, ' '));
    Screen.WriteXY (12, 23, 9, strPadL(strI2S(Stats.TodayUploads), 6, ' '));

    Screen.WriteXY (19, 18, 9, strPadL(strComma(Stats.TotalCalls), 12, ' '));
    Screen.WriteXY (19, 19, 9, strPadL(strComma(Stats.TotalNewUsers), 12, ' '));
    Screen.WriteXY (19, 20, 9, strPadL(strComma(Stats.TotalPosts), 12, ' '));
    Screen.WriteXY (19, 21, 9, strPadL(strComma(Stats.TotalEmail), 12, ' '));
    Screen.WriteXY (19, 22, 9, strPadL(strComma(Stats.TotalDownloads), 12, ' '));
    Screen.WriteXY (19, 23, 9, strPadL(strComma(Stats.TotalUploads), 12, ' '));

    For Count := 0 to 6 Do
      DrawBar (59 + Count, Stats.Weekly[Count]);

    For Count := 1 to 12 Do
      DrawBar (67 + Count, Stats.Monthly[Count]);

    For Count := 0 to 23 Do
      DrawBar (33 + Count, Stats.Hourly[Count]);
  End;

  Procedure UpdateStats;
  Var
    HistFile : File of RecHistory;
    Hist     : RecHistory;
    Count    : LongInt;
    Highest  : LongInt;
    Temp     : Real;
  Begin
    ShowMsgBox(3, 'Calculating statistics');

    FileMode := 66;

    Assign (HistFile, Config.DataPath + 'history.dat');
    Reset  (HistFile);

    If IoResult <> 0 Then Exit;

    FillChar (Stats, SizeOf(Stats), 0);

    While Not Eof(HistFile) Do Begin
      Read (HistFile, Hist);

      Inc (Stats.TotalDays);

      Inc (Stats.TotalCalls, Hist.Calls);
      Inc (Stats.TotalNewUsers, Hist.NewUsers);
      Inc (Stats.TotalDownloads, Hist.Downloads);
      Inc (Stats.TotalPosts, Hist.Posts);
      Inc (Stats.TotalEmail, Hist.Emails);
      Inc (Stats.TotalUploads, Hist.Uploads);

      If DateDos2Str(Hist.Date, 1) = DateDos2Str(CurDateDos, 1) Then Begin
        Inc (Stats.TodayCalls, Hist.Calls);
        Inc (Stats.TodayNewUsers, Hist.NewUsers);
        Inc (Stats.TodayDownloads, Hist.Downloads);
        Inc (Stats.TodayPosts, Hist.Posts);
        Inc (Stats.TodayEmail, Hist.Emails);
        Inc (Stats.TodayUploads, Hist.Uploads);
      End;

      Inc (Stats.Monthly[strS2I(Copy(DateDos2Str(Hist.Date, 1), 1, 2))], Hist.Calls);
      Inc (Stats.Weekly[DayOfWeek(Hist.Date)], Hist.Calls);

      For Count := 0 to 23 Do
        Inc (Stats.Hourly[Count], Hist.Hourly[Count]);
    End;

    Highest := 0;

    For Count := 1 to 12 Do
      If Stats.Monthly[Count] > Highest Then Highest := Stats.Monthly[Count];

    For Count := 1 to 12 Do
      If Stats.Monthly[Count] > 0 Then Begin
        Temp := Stats.Monthly[Count] / Highest * 100;
        Stats.Monthly[Count] := Trunc(Temp) DIV 20;
      End;

    Highest := 0;

    For Count := 0 to 6 Do
      If Stats.Weekly[Count] > Highest Then Highest := Stats.Weekly[Count];

    For Count := 0 to 6 Do
      If Stats.Weekly[Count] > 0 Then Begin
        Temp := Stats.Weekly[Count] / Highest * 100;
        Stats.Weekly[Count] := Trunc(Temp) DIV 20;
      End;

    Highest := 0;

    For Count := 0 to 23 Do
      If Stats.Hourly[Count] > Highest Then Highest := Stats.Hourly[Count];

    For Count := 0 to 23 Do
      If Stats.Hourly[Count] > 0 Then Begin
        Temp := Stats.Hourly[Count] / Highest * 100;
        Stats.Hourly[Count] := Trunc(Temp) DIV 20;
      End;

    Close (HistFile);
  End;

  Procedure DrawNodes;
  Var
    CN    : Byte;
    Count : Byte;
    Attr  : Byte;
  Begin
    For Count := 1 to 5 Do Begin
      CN := Count + TopPage - 1;

      If CN > Config.inetTNNodes Then Break;

      If CurNode = CN Then Attr := 31 Else Attr := 7;

      Screen.WriteXY (1, 10 + Count, Attr,
                       '  ' +
                       strPadL(strI2S(NodeInfo[CN]^.Node), 3, ' ') + '    ' +
                       strPadR(NodeInfo[CN]^.User, 25, ' ') + ' ' +
                       strPadR(NodeInfo[CN]^.Action, 43, ' ') + ' '
                     );

    End;
  End;

  Procedure FullReDraw;
  Begin
    UpdateStats;
    UpdateOnlineStatus;
    DrawNodeSpyScreen;
    DrawNodes;
    DrawStats;

    Screen.SetWindowTitle('NodeSpy/Main');
  End;

Var
  Count : Byte;
Begin
  FullReDraw;

  NodeTimer := TimerSet(UpdateNode);

  Repeat
    If Keyboard.KeyWait(1000) Then
      Case UpCase(Keyboard.ReadKey) of
        #00 : Case Keyboard.ReadKey of
                #71 : Begin
                        TopPage := 1;
                        CurNode := 1;

                        DrawNodes;
                      End;
                #72 : If CurNode > 1 Then Begin
                        Dec (CurNode);

                        If CurNode < TopPage Then Dec(TopPage);

                        DrawNodes;
                      End;
                #73,
                #75 : Begin
                        Dec (TopPage, 5);
                        Dec (CurNode, 5);

                        If TopPage < 1 Then TopPage := 1;
                        If CurNode < 1 Then CurNode := 1;

                        DrawNodes;
                      End;
                #77,
                #81 : Begin
                        Inc (TopPage, 5);
                        Inc (CurNode, 5);

                        If TopPage + 4 > Config.inetTNNodes Then TopPage := Config.inetTNNodes - 4;
                        If CurNode > Config.inetTNNodes Then CurNode := Config.inetTNNodes;

                        If TopPage < 1 Then TopPage := 1;

                        DrawNodes;
                      End;
                #79 : Begin
                        TopPage := Config.inetTNNodes - 4;
                        CurNode := Config.inetTNNodes;

                        If Toppage < 1 Then TopPage := 1;

                        DrawNodes;
                      End;
                #80 : If CurNode < Config.inetTNNodes Then Begin
                        Inc (CurNode);
                        If TopPage + 4 < CurNode Then Inc(TopPage);
                        DrawNodes;
                      End;
              End;
        #13 : Begin
                GetChatRecord(NodeInfo[CurNode]^.Node, Chat);

                If Not Chat.Active Then Begin
                  ShowMsgBox(0, 'Node ' + strI2S(NodeInfo[CurNode]^.Node) + ' is not in use');
                  Continue;
                End;

                Case GetCommandOption(10, 'S-Snoop|C-User Chat|K-Kick User|G-Kill Ghost|') of
                  'S' : Begin
                          SnoopNode(NodeInfo[CurNode]^.Node);
                          FullReDraw;
                        End;
                  'G' : If ShowMsgBox(1, 'Kill Ghost on Node ' + strI2S(NodeInfo[CurNode]^.Node)) Then Begin
                          FileErase(Config.DataPath + 'chat' + strI2S(NodeInfo[CurNode]^.Node) + '.dat');

                          UpdateOnlineStatus;
                          DrawNodes;

                          NodeTimer := TimerSet(UpdateNode);
                        End;
                  'K' : If ShowMsgBox(1, 'Kick this user?') Then
                          SendNodeMessage(NodeInfo[CurNode]^.Node, 13);
                  'C' : Begin
                          DoUserChat(NodeInfo[CurNode]^.Node);
                          FullReDraw;
                        End;
                End;
              End;
        #32 : Begin
                Terminal;
                FullReDraw;
              End;
        #27 : Break;
      End;

    If TimerUp(NodeTimer) Then Begin
      UpdateOnlineStatus;
      DrawNodes;

      NodeTimer := TimerSet(UpdateNode);

      If AutoSnoop Then
        For Count := 1 to Config.inetTNNodes Do
          If (NodeInfo[Count]^.User <> 'Waiting') and
             (NodeInfo[Count]^.ID <> AutoSnoopID) Then Begin
            SnoopNode(NodeInfo[Count]^.Node);
            FullReDraw;
          End;
    End;
  Until False;

  Screen.TextAttr := 7;
  Screen.ClearScreen;
  Screen.WriteLine('NodeSpy Shutdown');
End;

Begin
  {$IFDEF DEBUG}
    SetHeapTraceOutput('nodespy.mem');
  {$ENDIF}

  ApplicationInit;

  MainMenu;
End.

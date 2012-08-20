Program NodeSpy;

{$I M_OPS.PAS}

Uses
  {$IFDEF UNIX}
    BaseUnix,
  {$ENDIF}
  DOS,
  Math,
  m_FileIO,
  m_DateTime,
  m_Strings,
  m_Pipe_Disk,
  m_Input,
  m_Output,
  m_Term_Ansi,
  m_MenuBox,
  m_MenuInput;

{$I RECORDS.PAS}

Const
  HiddenNode  = 255;
  UpdateTimer = 500;

Var
  ChatFile   : File of ChatRec;
  Chat       : ChatRec;
  ConfigFile : File of RecConfig;
  Config     : RecConfig;
  NodeFile   : File of NodeMsgRec;
  Msg        : NodeMsgRec;
  BasePath   : String;
  Screen     : TOutput;
  Keyboard   : TInput;

Function ShowMsgBox (BoxType: Byte; Str: String) : Boolean;
Var
  Len    : Byte;
  Len2   : Byte;
  Pos    : Byte;
  MsgBox : TMenuBox;
  Offset : Byte;
  SavedX : Byte;
  SavedY : Byte;
  SavedA : Byte;
Begin
  ShowMsgBox := True;
  SavedX     := Screen.CursorX;
  SavedY     := Screen.CursorY;
  SavedA     := Screen.TextAttr;

  MsgBox := TMenuBox.Create(TOutput(Screen));

  Len := (80 - (Length(Str) + 2)) DIV 2;
  Pos := 1;

  MsgBox.FrameType := 6;
  MsgBox.Header    := ' Info ';
  MsgBox.HeadAttr  := 1 + 7 * 16;

  MsgBox.Box3D := True;

  If Screen.ScreenSize = 50 Then Offset := 12 Else Offset := 0;

  If BoxType < 2 Then
    MsgBox.Open (Len, 10 + Offset, Len + Length(Str) + 3, 15 + Offset)
  Else
    MsgBox.Open (Len, 10 + Offset, Len + Length(Str) + 3, 14 + Offset);

  Screen.WriteXY (Len + 2, 12 + Offset, 112, Str);

  Case BoxType of
    0 : Begin
          Len2 := (Length(Str) - 4) DIV 2;

          Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 30, ' OK ');

          Repeat
            Keyboard.ReadKey;
          Until Not Keyboard.KeyPressed;
        End;
    1 : Repeat
          Len2 := (Length(Str) - 9) DIV 2;

          Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 113, ' YES ');
          Screen.WriteXY (Len + Len2 + 7, 14 + Offset, 113, ' NO ');

          If Pos = 1 Then
            Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 30, ' YES ')
          Else
            Screen.WriteXY (Len + Len2 + 7, 14 + Offset, 30, ' NO ');

          Case UpCase(Keyboard.ReadKey) of
            #00 : Case Keyboard.ReadKey of
                    #75 : Pos := 1;
                    #77 : Pos := 0;
                  End;
            #13 : Begin
                    ShowMsgBox := Boolean(Pos);
                    Break;
                  End;
            #32 : If Pos = 0 Then Inc(Pos) Else Pos := 0;
            'N' : Begin
                    ShowMsgBox := False;
                    Break;
                  End;
            'Y' : Begin
                    ShowMsgBox := True;
                    Break;
                  End;
          End;
        Until False;
  End;

  If BoxType < 2 Then MsgBox.Close;

  MsgBox.Free;

  Screen.CursorXY (SavedX, SavedY);
  Screen.TextAttr := SavedA;
End;

Function GetStr (Header, Text, Def: String; Len, MaxLen: Byte) : String;
Var
  Box     : TMenuBox;
  Input   : TMenuInput;
  Offset  : Byte;
  Str     : String;
  WinSize : Byte;
Begin
  WinSize := (80 - Max(Len, Length(Text)) + 2) DIV 2;

  Box   := TMenuBox.Create(TOutput(Screen));
  Input := TMenuInput.Create(TOutput(Screen));

  Box.FrameType := 6;
  Box.Header    := ' ' + Header + ' ';
  Box.HeadAttr  := 1 + 7 * 16;
  Box.Box3D     := True;

  Input.Attr     := 15 + 4 * 16;
  Input.FillAttr :=  7 + 4 * 16;
  Input.LoChars  := #13#27;

  If Screen.ScreenSize = 50 Then Offset := 12 Else Offset := 0;

  Box.Open (WinSize, 10 + Offset, WinSize + Max(Len, Length(Text)) + 2, 15 + Offset);

  Screen.WriteXY (WinSize + 2, 12 + Offset, 112, Text);
  Str := Input.GetStr(WinSize + 2, 13 + Offset, Len, MaxLen, 1, Def);

  Box.Close;

  If Input.ExitCode = #27 Then Str := '';

  Input.Free;
  Box.Free;

  Result := Str;
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

  Screen.WriteXY  (1, 1, 31, strRep(' ', 79));
  Screen.WriteXY  (2, 1, 31, 'Chat mode engaged');
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
  Pipe    : TPipeDisk;
  Term    : TTermAnsi;
  Buffer  : Array[1..4 * 1024] of Char;
  BufRead : LongInt;
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
      Screen.WriteXY   (56, 25, Config.StatusColor3, 'ALT: C)hat K)ick e(X)it');
      Screen.SetWindow ( 1,  1, 80, 24, True);

      Screen.CursorXY (SX, SY);
      Screen.TextAttr := SA;
    End;
  End;

Begin
  WriteLn;
  WriteLn('Requesting snoop session for node ', Node, '...');
  WriteLn;

  SendNodeMessage(Node, 11);

  Pipe := TPipeDisk.Create(Config.DataPath, True, Node);

  If Not Pipe.ConnectPipe(1500) Then Begin
    WriteLn('NodeSpy was not able to establish a snoop session.  Sessions');
    WriteLn('cannot be created if a user is in a door or a file transfer.');

    Pipe.Free;

    Exit;
  End;

  WriteLn('Connection established');

  Keyboard := TInput.Create;
  Screen   := TOutput.Create(True);
  Term     := TTermAnsi.Create(Screen);

  Screen.SetWindowTitle('Snooping node ' + strI2S(Node));

  DrawStatus;

  Update := TimerSet(UpdateTimer);

  While Pipe.Connected Do Begin
    Pipe.ReadFromPipe(Buffer, SizeOf(Buffer), BufRead);

    If BufRead = 0 Then
      WaitMS(200)
    Else
      Term.ProcessBuf(Buffer, BufRead);

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
      End;

    If TimerUp(Update) Then Begin
      GetChatRecord (Node, Chat);

      If Not Chat.Active Then Break;

      DrawStatus;

      Update := TimerSet(UpdateTimer);
    End;
  End;

  If Chat.Active Then SendNodeMessage(Node, 12);

  Screen.SetWindow (1, 1, 80, 25, False);
  Screen.CursorXY  (1, Screen.ScreenSize);

  Screen.TextAttr := 7;

  Pipe.Disconnect;
  Pipe.Free;
  Term.Free;
  Screen.Free;

  WriteLn;
  WriteLn;
  WriteLn ('Session closed');
End;

Procedure ShowWhosOnline;
Var
  Count : Word;
Begin
  WriteLn;
  WriteLn('###   UserName                   Action');
  WriteLn(strRep('=', 79));

  For Count := 1 to Config.INetTNNodes Do Begin
    If GetChatRecord(Count, Chat) Then Begin
      WriteLn (strPadL(strI2S(Count), 3, '0') + '   ' +
               strPadR(Chat.Name, 25, ' ') + '  ' +
               strPadR(Chat.Action, 45, ' '));
    End Else
      WriteLn (strPadL(strI2S(Count), 3, '0') + '   ' +
               strPadR('Waiting', 25, ' ') + '  ' +
               strPadR('Waiting', 45, ' '));
  End;

  WriteLn (strRep('=', 79));
  WriteLn ('Execute NodeSpy [node number] to spy on a node');
End;

Var
  NodeNum : Byte;
  {$IFDEF UNIX}
  Info    : Stat;
  {$ENDIF}
Begin
  {$IFDEF UNIX}
  If fpStat('nodespy', Info) = 0 Then Begin
    fpSetGID (Info.st_GID);
    fpSetUID (Info.st_UID);
  End;
  {$ENDIF}

  Assign (ConfigFile, 'mystic.dat');
  Reset  (ConfigFile);

  If IoResult <> 0 Then Begin
    BasePath := GetENV('mysticbbs');

    If BasePath <> '' Then BasePath := DirSlash(BasePath);

    Assign (ConfigFile, BasePath + 'mystic.dat');
    Reset  (ConfigFile);

    If IoResult <> 0 Then Begin
      WriteLn ('ERROR: Unable to read MYSTIC.DAT');
      WriteLn;
      WriteLn ('MYSTIC.DAT must exist in the same directory as NodeSpy, or in the');
      WriteLn ('path defined by the MYSTICBBS environment variable.');
      Halt    (1);
    End;
  End;

  Read  (ConfigFile, Config);
  Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn ('ERROR: NodeSpy has detected a version mismatch');
    WriteLn;
    WriteLn ('NodeSpy or another BBS utility is an older incompatible version.  Make');
    WriteLn ('sure you have upgraded properly!');
    Halt (1);
  End;

  DirCreate(Config.SystemPath + 'temp' + strI2S(HiddenNode));

  If ParamCount < 1 Then
    ShowWhosOnline
  Else Begin
    NodeNum := strS2I(ParamStr(1));

    If (NodeNum > 0) and (NodeNum <= Config.INetTNNodes) Then
      SnoopNode(NodeNum);
  End;
End.

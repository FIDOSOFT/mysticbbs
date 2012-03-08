Unit bbs_NodeInfo;

{$I M_OPS.PAS}

Interface

Function  Is_User_Online    (Name : String) : Word;
Procedure Show_Whos_Online;
Procedure Send_Node_Message (MsgType: Byte; Data: String; Room: Byte);
Function  CheckNodeMessages : Boolean;
Procedure Set_Node_Action   (Action: String);

Implementation

Uses
  m_Types,
  m_DateTime,
  m_Strings,
  m_FileIO,
  bbs_Common,
  bbs_Core,
  bbs_User,
  bbs_UserChat;

Function Is_User_Online (Name: String) : Word;
Var
  TempChat : ChatRec;
  Count    : Word;
Begin
  Result := 0;

  For Count := 1 to Config.INetTNNodes Do Begin
    Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Count) + '.dat');

    {$I-} Reset(ChatFile); {$I+}

    If IoResult <> 0 Then Continue;

    Read  (ChatFile, TempChat);
    Close (ChatFile);

    If (Count <> Session.NodeNum) and (TempChat.Active) and (TempChat.Name = Name) Then Begin
      Result := Count;
      Exit;
    End;
  End;
End;

Procedure Set_Node_Action (Action: String);
Begin
  Assign  (ChatFile, Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  ReWrite (ChatFile);

  If Action <> '' Then Begin
    Chat.Active    := True;
    Chat.Name      := Session.User.ThisUser.Handle;
    Chat.Location  := Session.User.ThisUser.City;
    Chat.Action    := Action;
    Chat.Gender    := Session.User.ThisUser.Gender;
    Chat.Age       := DaysAgo(Session.User.ThisUser.Birthday) DIV 365;
    If Session.LocalMode Then
      Chat.Baud := 'LOCAL' {++lang}
    Else
      Chat.Baud := 'TELNET'; {++lang}
  End Else Begin
    Chat.Active    := False;
    Chat.Invisible := False;
    Chat.Available := False;
    Chat.Age       := 0;
    Chat.Gender    := '?';
  End;

  Write  (ChatFile, Chat);
  Close  (ChatFile);

  {$IFDEF WINDOWS}
    Screen.SetWindowTitle (WinConsoleTitle + strI2S(Session.NodeNum) + ' - ' + Session.User.ThisUser.Handle + ' - ' + Action);
  {$ENDIF}
End;

Procedure Show_Whos_Online;
Var
  TChat : ChatRec;
  Count : Word;
Begin
  Session.io.OutFullLn (Session.GetPrompt(138));

  For Count := 1 to Config.INetTNNodes Do Begin
    Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Count) + '.dat');

    {$I-} Reset(ChatFile); {$I+}

    If IoResult <> 0 Then Continue;

    Read  (ChatFile, TChat);
    Close (ChatFile);

    If TChat.Active and ((Not TChat.Invisible) or (TChat.Invisible and Session.User.Access(Config.AcsSeeInvis))) Then Begin
      Session.io.PromptInfo[1] := strI2S(Count);
      Session.io.PromptInfo[2] := TChat.Name;
      Session.io.PromptInfo[3] := TChat.Action;
      Session.io.PromptInfo[4] := TChat.Location;
      Session.io.PromptInfo[5] := TChat.Baud;
      Session.io.PromptInfo[6] := TChat.Gender;
      Session.io.PromptInfo[7] := strI2S(TChat.Age);
      Session.io.PromptInfo[8] := Session.io.OutYN(TChat.Available);

      Session.io.OutFullLn (Session.GetPrompt(139));
    End Else Begin
      Session.io.PromptInfo[1] := strI2S(Count);

      Session.io.OutFullLn (Session.GetPrompt(268));
    End;
  End;

  Session.io.OutFull (Session.GetPrompt(140));
End;

Procedure Send_Node_Message (MsgType: Byte; Data: String; Room: Byte);
Var
  ToNode  : Byte;
  A, B, C : Byte;
  Temp    : ChatRec;
  Str     : String[3];
Begin
  If Data = '' Then Begin
    Repeat
      Session.io.OutFull (Session.GetPrompt(146));
      Str := Session.io.GetInput(3, 3, 12, '');
      If Str = '?' Then Show_Whos_Online Else Break;
    Until False;

    ToNode := strS2I(Str);

    If (ToNode < 0) or (ToNode > Config.INetTNNodes) Then Begin
      Session.io.OutFullLn (Session.GetPrompt(147));
      Exit;
    End;

    B := ToNode;
    C := ToNode;
  End Else Begin
    If Pos(';', Data) = 0 Then Exit;

    ToNode := strS2I(Copy(Data, 1, Pos(';', Data)-1));

    Delete (Data, 1, Pos(';', Data));

    If ToNode = 0 Then Begin
      B := 1;
      C := Config.INetTNNodes;
      If MsgType = 3 Then MsgType := 2;
    End Else Begin
      B := ToNode;
      C := ToNode;
    End;
  End;

  For A := B to C Do Begin
    FileMode := 66;

    Assign (ChatFile, Config.DataPath + 'chat' + strI2S(A) + '.dat');

    {$I-} Reset (ChatFile); {$I+}

    If IoResult = 0 Then Begin
      Read  (ChatFile, Temp);
      Close (ChatFile);

      If (Not Temp.Active) and (ToNode > 0) Then Begin
        Session.io.OutFullLn (Session.GetPrompt(147));
        Exit;
      End;

       If (Not Temp.Available) and not (MsgType in [1, 4..7]) and (ToNode > 0) Then Begin
        Session.io.OutFullLn (Session.GetPrompt(395));
        Exit;
      End;

      If Temp.Active and (Temp.Available or Temp.InChat) Then Begin
        If Data = '' Then Begin
          Session.io.PromptInfo[1] := Temp.Name;
          Session.io.PromptInfo[2] := strI2S(A);

          Session.io.OutFullLn (Session.GetPrompt(148));

          NodeMsg.Message := Session.io.GetInput(79, 79, 11, '');
        End Else
          NodeMsg.Message := Data;

        If NodeMsg.Message = '' Then Exit;

        NodeMsg.FromNode := Session.NodeNum;
        NodeMsg.ToWho    := Temp.Name;
        NodeMsg.MsgType  := MsgType;
        NodeMsg.Room     := Room;
        NodeMsg.FromWho  := Session.User.ThisUser.Handle;

        FileMode := 66;

        Assign (NodeMsgFile, Config.SystemPath + 'temp' + strI2S(A) + PathChar + 'chat.tmp');

        If Not ioReset (NodeMsgFile, SizeOf(NodeMsg), fmReadWrite + fmDenyAll) Then
          ioReWrite(NodeMsgFile, SizeOf(NodeMsg), fmReadWrite + fmDenyAll);

        Seek  (NodeMsgFile, FileSize(NodeMsgFile));
        Write (NodeMsgFile, NodeMsg);
        Close (NodeMsgFile);
      End;
    End;
  End;
End;

Function CheckNodeMessages : Boolean;
Var
  Str   : String;
  Image : TConsoleImageRec;
Begin
  Result   := False;
  FileMode := 66;

  Assign (NodeMsgFile, Session.TempPath + 'chat.tmp');

  If Not ioReset(NodeMsgFile, SizeOf(NodeMsg), fmReadWrite + fmDenyAll) Then
    Exit;

  If FileSize(NodeMsgFile) = 0 Then Begin
    Close (NodeMsgFile);
    Exit;
  End;

  Session.InMessage := True;
  CheckNodeMessages := True;

  Read       (NodeMsgFile, NodeMsg);
  KillRecord (NodeMsgFile, 1, SizeOf(NodeMsg));
  Close      (NodeMsgFile);

  Screen.GetScreenImage (1, 1, 79, 24, Image);

  Session.io.PromptInfo[1] := NodeMsg.FromWho;
  Session.io.PromptInfo[2] := strI2S(NodeMsg.FromNode);
  Session.io.PromptInfo[3] := NodeMsg.Message;

  Case NodeMsg.MsgType of
    2 : Begin
          Session.io.OutFullLn (Session.GetPrompt(179) + NodeMsg.Message);
          Session.io.OutFullLn (Session.GetPrompt(180));
        End;
    3 : Begin
          Session.io.OutFullLn (Session.GetPrompt(144) + '|CR' + NodeMsg.Message);
          Session.io.OutFull (Session.GetPrompt(145));
        End;
    8 : If Session.io.GetYN('|CL|15|&1 is requesting user to user chat.  Accept? |11', True) Then Begin
          Send_Node_Message (10,  strI2S(NodeMsg.FromNode) + ';C', 0);
          OpenUserChat(False, NodeMsg.FromNode);
        End;
    9 : Begin
          Send_Node_Message (10, strI2S(NodeMsg.FromNode) + ';C', 0);
          OpenUserChat(True, NodeMsg.FromNode);
        End;
    10: OpenUserChat(False, NodeMsg.FromNode);
  End;

  If Result And (NodeMsg.MsgType = 3) Then
    If Session.io.OneKey(#13 + 'R', True) = 'R' Then Begin
      Session.io.OutFullLn(Session.GetPrompt(360));

      Str := Session.io.GetInput(79, 79, 11, '');

      If Str <> '' Then Send_Node_Message(3, Session.io.PromptInfo[2] + ';' + Str, 0);
    End;

  Session.io.RemoteRestore(Image);

  Session.InMessage := False;
End;

End.

Unit bbs_NodeChat;

{$I M_OPS.PAS}

Interface

Procedure Node_Chat;

Implementation

Uses
  m_Strings,
  m_DateTime,
  m_FileIO,
  bbs_NodeInfo,
  bbs_Common,
  bbs_User,
  bbs_Core;

Var
  ChatSize   : Byte;
  ChatUpdate : LongInt;
  TextPos    : Byte;
  TopPage    : Byte;
  LinePos    : Byte;
  Full       : Boolean;

Procedure FullReDraw;
Var
  Count   : Byte;
  Temp    : Byte;
Begin
  If Not Full Then Exit;

  Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[1].Y);

  Temp := TopPage;

  For Count := 0 to ChatSize Do Begin
    Session.io.AnsiClrEOL;
    If Temp <= TextPos Then Begin
      Session.io.OutPipeLn (Session.Msgs.MsgText[Temp]);
      Inc (Temp);
    End Else
      Session.io.OutRawLn('');
  End;
End;

Procedure Change_Room (R : Byte);
Var
  CF : File of ChatRec;
Begin
  If (R < 1) or (R > 99) Then Exit;

  Reset (RoomFile);
  Seek  (RoomFile, R-1);
  Read  (RoomFile, Room);
  Close (RoomFile);

  Chat.Room := R;
  CurRoom   := R;

  Assign (CF, Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (CF);
  Write  (CF, Chat);
  Close  (CF);

  Send_Node_Message (5, strI2S(Session.NodeNum) + ';' + 'Now chatting in channel ' + strI2S(CurRoom), 0); //++lang
End;

Procedure Update_Topic;
Begin
  If Not Full Then Exit;

  { look around and make common function called goscreeninfo(num) that }
  { goes to an x/y position and changes the attribute }

  Session.io.AnsiGotoXY   (Session.io.ScreenInfo[4].X, Session.io.ScreenInfo[4].Y);
  Session.io.AnsiColor (Session.io.ScreenInfo[4].A);

  Session.io.OutRaw (strPadR(strI2S(CurRoom), 2, ' '));

  Session.io.AnsiGotoXY   (Session.io.ScreenInfo[5].X, Session.io.ScreenInfo[5].Y);
  Session.io.AnsiColor (Session.io.ScreenInfo[5].A);

  Session.io.OutRaw (strPadR(Room.Name, 40, ' '));
End;

Function GetKeyNodeChatFunc (Forced : Boolean) : Boolean;
{ 1 = node chat broadcast message (if room = 0)
      node chat regular text (if room = room user is in)
  4 = node chat private message
  5 = chat broadcast (ie: xxx has entered chat)
  6 = chat action (ie: g00r00 claps his hands)
  7 = chat topic update }

  Procedure AddText (Str : String);
  Var
    Count : Byte;
  Begin
    If TextPos < 200 Then
      Inc (TextPos)
    Else
      For Count := 2 to 200 Do
        Session.Msgs.MsgText[Count - 1] := Session.Msgs.MsgText[Count];

    Session.Msgs.MsgText[TextPos] := Str;
  End;

Var
  Str     : String;
  StrLen  : Byte;
  Indent  : Byte;
  Lines   : Byte;
  OldAttr : Byte;
  OldX    : Byte;
  OldY    : Byte;
Begin
  GetKeyNodeChatFunc := False;

  If Session.User.InChat or Session.InUserEdit Then Exit;

  If (TimerSeconds - ChatUpdate <> 0) or Forced Then Begin

    Assign (NodeMsgFile, Session.TempPath + 'chat.tmp');
    FileMode := 66;
    {$I-} Reset (NodeMsgFile); {$I+}
    If IoResult = 0 Then Begin

      OldAttr := Screen.TextAttr;
      OldX    := Screen.CursorX;
      OldY    := Screen.CursorY;

      While Not Eof(NodeMsgFile) Do Begin
        Read (NodeMsgFile, NodeMsg);

        If NodeMsg.MsgType in [1, 4..7] Then Begin
          Session.io.OutRaw (Session.io.Pipe2Ansi(16));

          Case NodeMsg.MsgType of
            1 : If NodeMsg.Room = 0 Then
                  Str := strReplace(Session.GetPrompt(319), '|&1', NodeMsg.FromWho)
                Else
                If NodeMsg.Room = CurRoom Then
                  Str := strReplace(Session.GetPrompt(181), '|&1', NodeMsg.FromWho)
                Else
                  Continue;
            4 : Str := strReplace(Session.GetPrompt(218), '|&1', NodeMsg.FromWho);
            5 : Str := Session.GetPrompt(226);
            6 : Str := strReplace(Session.GetPrompt(229), '|&1', NodeMsg.FromWho);
            7 : Begin
                  Reset (RoomFile);
                  Seek  (RoomFile, CurRoom - 1);
                  Read  (RoomFile, Room);
                  Close (RoomFile);

                  Update_Topic;
                  Str := Session.GetPrompt(226);
                End;
          End;

          If Full Then Begin
            StrLen := Length(Str);
            Indent := Length(strStripMCI(Str));
            Lines  := 0;

            Repeat
              Inc (Lines);

              If Length(Str + NodeMsg.Message) > 79 Then Begin
                Str := Str + Copy(NodeMsg.Message, 1, 79 - StrLen);
                AddText(Str);
                Delete (NodeMsg.Message, 1, 79 - StrLen);
                Str := strRep(' ', Indent);
              End Else Begin
                AddText(Str + NodeMsg.Message);
                Break;
              End;
            Until False;

            If LinePos + Lines > Session.io.ScreenInfo[2].Y Then Begin
              Indent  := (ChatSize DIV 2) - 2;
              TopPage := TextPos - Indent;
              LinePos := Session.io.ScreenInfo[1].Y + Indent + 1;
              FullReDraw;
            End Else Begin
              Session.io.AnsiGotoXY(1, LinePos);
              For Indent := Lines DownTo 1 Do Begin
                Session.io.AnsiClrEOL;
                Session.io.OutPipeLn(Session.Msgs.MsgText[TextPos - Indent + 1]);
                Inc (LinePos);
              End;
            End;

            Session.io.AnsiGotoXY (OldX, OldY);
          End Else Begin
            If Session.io.Graphics = 0 Then
              Session.io.OutBS (Screen.CursorX, True)
            Else Begin
              Session.io.AnsiMoveX(1);
              Session.io.AnsiClrEOL;
            End;

            Session.io.OutPipe (Str);
            Session.io.OutPipeLn (NodeMsg.Message);
          End;
        End;
      End;

      Close (NodeMsgFile);
      Erase (NodeMsgFile);

      If Not Full And Not Forced Then Begin
        Session.io.PromptInfo[1] := Session.User.ThisUser.Handle;
        Session.io.OutFull ('|CR' + Session.GetPrompt(427));
      End;

      Session.io.AnsiColor (OldAttr);

      GetKeyNodeChatFunc := True;
    End;

    ChatUpdate := TimerSeconds;
  End;
End;

Procedure Node_Chat;

  Procedure Chat_Template;
  Begin
    If Not Full Then Begin
      Session.io.OutFile('teleconf', True, 0);
      Exit;
    End;

    Session.io.PromptInfo[1] := strI2S(CurRoom);
    Session.io.PromptInfo[2] := Room.Name;

    Session.io.OutFile ('ansitele', True, 0);

    ChatSize := Session.io.ScreenInfo[2].Y - Session.io.ScreenInfo[1].Y;

    Update_Topic;
  End;

  Procedure Show_Users_In_Chat;
  Var
    A    : Byte;
    Temp : ChatRec;
    RM   : RoomRec;
  Begin
    Session.io.OutFullLn (Session.GetPrompt(332));

    For A := 1 to Config.INetTNNodes Do Begin
      Assign (ChatFile, Config.DataPath + 'chat' + strI2S(A) + '.dat');
      {$I-} Reset (ChatFile); {$I+}
      If IoResult = 0 Then Begin
        Read (ChatFile, Temp);
        Close (ChatFile);
        If Temp.InChat Then Begin
          Reset (RoomFile);
          Seek  (RoomFile, Temp.Room - 1);
          Read  (RoomFile, RM);
          Close (RoomFile);
          Session.io.PromptInfo[1] := Temp.Name;
          Session.io.PromptInfo[2] := strI2S(A);
          Session.io.PromptInfo[3] := strI2S(Temp.Room);
          Session.io.PromptInfo[4] := RM.Name;
          Session.io.OutFullLn (Session.GetPrompt(333));
        End;
      End;
    End;

    Session.io.OutFullLn (Session.GetPrompt(453));

    Chat_Template;
    FullReDraw;
  End;

  Procedure Send_Private_Message (Str : String);
  Var
    UserName : String;
    Text     : String;
    Count    : Byte;
    Temp     : ChatRec;
  Begin
    UserName := strUpper(strReplace(strWordGet(2, Str, ' '), '_', ' '));
    Text     := Copy(Str, strWordPos(3, Str, ' '), Length(Str));

    If Text = '' Then Exit;

    For Count := 1 to Config.INetTNNodes Do Begin
      Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Count) + '.dat');
      {$I-} Reset (ChatFile); {$I+}
      If IoResult = 0 Then Begin
        Read  (ChatFile, Temp);
        Close (ChatFile);
        If strUpper(Temp.Name) = UserName Then Begin
          Send_Node_Message (4, strI2S(Count) + ';' + Text, 0);
          Exit;
        End;
      End;
    End;

    Send_Node_Message (5, strI2S(Session.NodeNum) + ';' + 'User ' + UserName + ' not found', 0); //++lang
  End;

  Procedure ChatScrollBack;
  Var
    Ch      : Char;
    TopSave : Byte;
  Begin
    If Not Full Then Exit;

    TopSave := TopPage;

    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y);
    Session.io.AnsiClrEOL;
    Session.io.OutFull (Session.GetPrompt(237));

    Repeat
      Ch := Session.io.GetKey;

      If Ch = #27 Then Break;

      If Session.io.IsArrow Then
        Case Ch of
          #71 : If TopPage > 1 Then Begin
                  TopPage := 1;
                  FullReDraw;
                End;
          #72 : If TopPage > 1 Then Begin
                  Dec(TopPage);
                  FullReDraw;
                End;
          #73,
          #75 : If TopPage > 1 Then Begin
                  If TopPage < ChatSize Then
                    TopPage := 1
                  Else
                    Dec (TopPage, ChatSize);
                  FullReDraw;
                End;
          #79 : If TopPage < TopSave Then Begin
                  TopPage := TopSave;
                  FullReDraw;
                End;
          #80 : If TopPage < TopSave Then Begin
                  Inc(TopPage);
                  FullReDraw;
                End;
          #77,
          #81 : If TopPage < TopSave Then Begin
                  If TopPage + ChatSize > TopSave Then
                    TopPage := TopSave
                  Else
                    Inc (TopPage, ChatSize);
                  FullReDraw;
                End;
        End;
    Until False;

    TopPage := TopSave;
    FullReDraw;
  End;

Var
  Str   : String;
  Str2  : String;
  Avail : Boolean;
Begin
  Full := Session.User.ThisUser.UseFullChat And (Session.io.Graphics > 0);

  Set_Node_Action (Session.GetPrompt(347));

  Avail          := Chat.Available;
  Chat.InChat    := True;
  Chat.Available := False;

  Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (ChatFile);
  Write  (ChatFile, Chat);
  Close  (ChatFile);

  FileErase(Session.TempPath + 'chat.tmp');

  Send_Node_Message (5, '0;' + Session.User.ThisUser.Handle + ' has entered chat', 0); //++lang

  Change_Room (1);

  Chat_Template;

  TopPage := 1;
  TextPos := 0;
  LinePos := Session.io.ScreenInfo[1].Y;

  FullReDraw;

  GetKeyFunc := GetKeyNodeChatFunc;

  Repeat
    Session.io.PromptInfo[1] := Session.User.ThisUser.Handle;

    If Full Then Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y) Else Session.io.OutRawLn('');

    Session.io.OutFull (Session.GetPrompt(427));

    If Full Then
      Str := Session.io.GetInput (79 - Screen.CursorX + 1, 250, 19, '')
    Else
      Str := Session.io.GetInput (79 - Screen.CursorX + 1, 250, 11, '');

    If Str[1] = '/' Then Begin
      GetKeyFunc := NoGetKeyFunc;

      Str2 := strUpper(strWordGet(1, Str, ' '));

      If Str2 = '/B' Then Begin
        Str2 := Copy(Str, strWordPos(2, Str, ' '), Length(Str));
        If Str2 <> '' Then
          Send_Node_Message (1, '0;' + Str2, 0)
      End Else
      If Str2 = '/CLS' Then Begin
        TopPage := 1;
        TextPos := 0;
        LinePos := Session.io.ScreenInfo[1].Y;

        FullReDraw;
      End Else
      If Str2 = '/?' Then Begin
        Session.io.OutFile ('telehelp', True, 0);
        Chat_Template;
        FullReDraw
      End Else
      If Str2 = '/SCROLL' Then
        ChatScrollBack
      Else
      If Str2 = '/Q' Then
        Break
      Else
      If Str2 = '/ME' Then Begin
        Str := Copy(Str, 5, Length(Str));

        If Str <> '' Then
          Send_Node_Message (6, '0;' + Str, CurRoom);
      End Else
      If Str2 = '/MSG' Then
        Send_Private_Message(Str)
      Else
      If Str2 = '/NAMES' Then
        Show_Users_In_Chat
      Else
      If Str2 = '/JOIN' Then Begin
        Change_Room (strS2I(strWordGet(2, Str, ' ')));
        Update_Topic;
      End Else
      If Str2 = '/WHO' Then Begin
        Session.io.AnsiClear;
        Show_Whos_Online;
        Chat_Template;
        FullReDraw;
      End Else
      If Str2 = '/TOPIC' Then Begin
        Room.Name := Copy(Str, strWordPos(2, Str, ' '), Length(Str));

        Reset (RoomFile);
        Seek  (RoomFile, CurRoom - 1);
        Write (RoomFile, Room);
        Close (RoomFile);

        Send_Node_Message (7, '0;Topic changed to "' + Room.Name + '"', CurRoom); // ++lang
      End;

      GetKeyFunc := GetKeyNodeChatFunc;
    End Else
    If Str <> '' Then Begin
      Send_Node_Message (1, '0;' + Str, CurRoom);
      If Not Full Then Session.io.OutRawLn('');
      GetKeyNodeChatFunc(True);
    End;
  Until False;

  GetKeyFunc     := NoGetKeyFunc;
  Chat.InChat    := False;
  Chat.Available := Avail;

  Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (ChatFile);
  Write  (ChatFile, Chat);
  Close  (ChatFile);

  FileErase(Session.TempPath + 'chat.tmp');

  Send_Node_Message (5, '0;' + Session.User.ThisUser.Handle + ' has left chat', 0); //++lang
End;

End.

Unit bbs_NodeChat;

{$I M_OPS.PAS}

Interface

Procedure Node_Chat;

Implementation

Uses
  m_Strings,
  m_DateTime,
  m_FileIO,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_NodeInfo,
  BBS_User,
  BBS_Core;

Var
  ChatSize   : Integer;
  ChatUpdate : LongInt;
  TextPos    : Integer;
  TopPage    : Integer;
  LinePos    : Integer;
  Full       : Boolean;

Procedure FullReDraw;
Var
  Count : Integer;
  Temp  : Integer;
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

  Reset (Session.RoomFile);
  Seek  (Session.RoomFile, R - 1);
  Read  (Session.RoomFile, Session.Room);
  Close (Session.RoomFile);

  Session.Chat.Room := R;
  Session.CurRoom   := R;

  Assign (CF, bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (CF);
  Write  (CF, Session.Chat);
  Close  (CF);

  Send_Node_Message (5, strI2S(Session.NodeNum) + ';' + 'Now chatting in channel ' + strI2S(Session.CurRoom), 0); //++lang
End;

Procedure Update_Topic;
Begin
  If Not Full Then Exit;

  { look around and make common function called goscreeninfo(num) that }
  { goes to an x/y position and changes the attribute }

  Session.io.AnsiGotoXY   (Session.io.ScreenInfo[4].X, Session.io.ScreenInfo[4].Y);
  Session.io.AnsiColor (Session.io.ScreenInfo[4].A);

  Session.io.OutRaw (strPadR(strI2S(Session.CurRoom), 2, ' '));

  Session.io.AnsiGotoXY (Session.io.ScreenInfo[5].X, Session.io.ScreenInfo[5].Y);
  Session.io.AnsiColor  (Session.io.ScreenInfo[5].A);

  Session.io.OutRaw (strPadR(Session.Room.Name, 40, ' '));
End;

Function GetKeyNodeChatFunc (Forced: Boolean) : Boolean;
{ 1 = node chat broadcast message (if room = 0)
      node chat regular text (if room = room user is in)
  4 = node chat private message
  5 = chat broadcast (ie: xxx has entered chat)
  6 = chat action (ie: g00r00 claps his hands)
  7 = chat topic update }

  Procedure AddText (Str : String);
  Var
    Count : Integer;
  Begin
    If TextPos < mysMaxMsgLines Then
      Inc (TextPos)
    Else
      For Count := 2 to mysMaxMsgLines Do
        Session.Msgs.MsgText[Count - 1] := Session.Msgs.MsgText[Count];

    Session.Msgs.MsgText[TextPos] := Str;
  End;

Var
  Str     : String;
  StrLen  : Integer;
  Indent  : Integer;
  Lines   : Integer;
  OldAttr : Byte;
  OldX    : Byte;
  OldY    : Byte;
  MsgFile : File of NodeMsgRec;
  Msg     : NodeMsgRec;
Begin
  GetKeyNodeChatFunc := False;

  If Session.User.InChat or Session.InUserEdit Then Exit;

  If (TimerSeconds - ChatUpdate <> 0) or Forced Then Begin

    Assign (MsgFile, Session.TempPath + 'chat.tmp');

    If ioReset(MsgFile, SizeOf(Msg), fmRWDN) Then Begin

      OldAttr := Console.TextAttr;
      OldX    := Console.CursorX;
      OldY    := Console.CursorY;

      While Not Eof(MsgFile) Do Begin
        Read (MsgFile, Msg);

        If Msg.MsgType in [1, 4..7] Then Begin
          Session.io.OutRaw (Session.io.Pipe2Ansi(16));

          Case Msg.MsgType of
            1 : If Msg.Room = 0 Then
                  Str := strReplace(Session.GetPrompt(319), '|&1', Msg.FromWho)
                Else
                If Msg.Room = Session.CurRoom Then
                  Str := strReplace(Session.GetPrompt(181), '|&1', Msg.FromWho)
                Else
                  Continue;
            4 : Str := strReplace(Session.GetPrompt(218), '|&1', Msg.FromWho);
            5 : Str := Session.GetPrompt(226);
            6 : Str := strReplace(Session.GetPrompt(229), '|&1', Msg.FromWho);
            7 : Begin
                  Reset (Session.RoomFile);
                  Seek  (Session.RoomFile, Session.CurRoom - 1);
                  Read  (Session.RoomFile, Session.Room);
                  Close (Session.RoomFile);

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

              If Length(Str + Msg.Message) > 79 Then Begin
                Str := Str + Copy(Msg.Message, 1, 79 - StrLen);
                AddText(Str);
                Delete (Msg.Message, 1, 79 - StrLen);
                Str := strRep(' ', Indent);
              End Else Begin
                AddText(Str + Msg.Message);
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
              Session.io.OutBS (Console.CursorX, True)
            Else Begin
              Session.io.AnsiMoveX(1);
              Session.io.AnsiClrEOL;
            End;

            Session.io.OutPipe   (Str);
            Session.io.OutPipeLn (Msg.Message);
          End;
        End;
      End;

      Close (MsgFile);
      Erase (MsgFile);

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

    Session.io.PromptInfo[1] := strI2S(Session.CurRoom);
    Session.io.PromptInfo[2] := Session.Room.Name;

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

    For A := 1 to bbsCfg.INetTNNodes Do
      If GetChatRecord(A, Temp) Then
        If Temp.InChat Then Begin
          Reset (Session.RoomFile);
          Seek  (Session.RoomFile, Temp.Room - 1);
          Read  (Session.RoomFile, RM);
          Close (Session.RoomFile);

          Session.io.PromptInfo[1] := Temp.Name;
          Session.io.PromptInfo[2] := strI2S(A);
          Session.io.PromptInfo[3] := strI2S(Temp.Room);
          Session.io.PromptInfo[4] := RM.Name;

          Session.io.OutFullLn (Session.GetPrompt(333));
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

    For Count := 1 to bbsCfg.INetTNNodes Do
      If GetChatRecord(Count, Temp) Then
        If strUpper(Temp.Name) = UserName Then Begin
          Send_Node_Message (4, strI2S(Count) + ';' + Text, 0);
          Exit;
        End;

    Send_Node_Message (5, strI2S(Session.NodeNum) + ';' + 'User ' + UserName + ' not found', 0); //++lang
  End;

  Procedure ChatScrollBack;
  Var
    Ch      : Char;
    TopSave : Integer;
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

  Avail                  := Session.Chat.Available;
  Session.Chat.InChat    := True;
  Session.Chat.Available := False;

  Assign (Session.ChatFile, bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (Session.ChatFile);
  Write  (Session.ChatFile, Session.Chat);
  Close  (Session.ChatFile);

  FileErase(Session.TempPath + 'chat.tmp');

  Send_Node_Message (5, '0;' + Session.User.ThisUser.Handle + ' has entered chat', 0); //++lang

  Change_Room (1);

  Chat_Template;

  TopPage := 1;
  TextPos := 0;
  LinePos := Session.io.ScreenInfo[1].Y;

  FullReDraw;

  Session.AllowMessages := False;

  Session.io.GetKeyCallBack := @GetKeyNodeChatFunc;

  Repeat
    Session.io.PromptInfo[1] := Session.User.ThisUser.Handle;

    If Full Then Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[3].Y) Else Session.io.OutRawLn('');

    Session.io.OutFull (Session.GetPrompt(427));

    If Full Then
      Str := Session.io.GetInput (79 - Console.CursorX + 1, 250, 19, '')
    Else
      Str := Session.io.GetInput (79 - Console.CursorX + 1, 250, 11, '');

    If Str[1] = '/' Then Begin
      Session.io.GetKeyCallBack := NIL;

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
          Send_Node_Message (6, '0;' + Str, Session.CurRoom);
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
        WhosOnline;
        Chat_Template;
        FullReDraw;
      End Else
      If Str2 = '/TOPIC' Then Begin
        Session.Room.Name := Copy(Str, strWordPos(2, Str, ' '), Length(Str));

        Reset (Session.RoomFile);
        Seek  (Session.RoomFile, Session.CurRoom - 1);
        Write (Session.RoomFile, Session.Room);
        Close (Session.RoomFile);

        Send_Node_Message (7, '0;Topic changed to "' + Session.Room.Name + '"', Session.CurRoom); // ++lang
      End;

      Session.io.GetKeyCallBack := @GetKeyNodeChatFunc;
    End Else
    If Str <> '' Then Begin
      Send_Node_Message (1, '0;' + Str, Session.CurRoom);
      If Not Full Then Session.io.OutRawLn('');
      GetKeyNodeChatFunc(True);
    End;
  Until False;

  Session.io.GetKeyCallBack := NIL;

  Session.Chat.InChat    := False;
  Session.Chat.Available := Avail;

  Session.AllowMessages := True;

  Assign (Session.ChatFile, bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
  Reset  (Session.ChatFile);
  Write  (Session.ChatFile, Session.Chat);
  Close  (Session.ChatFile);

  FileErase(Session.TempPath + 'chat.tmp');

  Send_Node_Message (5, '0;' + Session.User.ThisUser.Handle + ' has left chat', 0); //++lang
End;

End.

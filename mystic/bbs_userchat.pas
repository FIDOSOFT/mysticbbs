Unit bbs_UserChat;

{$I M_OPS.PAS}

Interface

Procedure PageUserForChat;
Procedure OpenUserChat (Forced: Boolean; ToNode: Byte);

Implementation

Uses
  m_Strings,
  m_FileIO,
  m_DateTime,
  bbs_Core,
  bbs_Common,
  bbs_NodeInfo;

Procedure PageUserForChat;
Var
  Str     : String;
  ToNode  : Byte;
  ReqType : Byte = 8;
Begin
  Repeat
    Session.io.OutFull ('|CR|09Enter node to chat with (?/List): ');

    Str := Session.io.GetInput(3, 3, 12, '');

    If Str = '?' Then Show_Whos_Online Else
    If Str = 'Q' Then Exit Else Break;
  Until False;

  ToNode := strS2I(Str);

  // pull chat record

  If (ToNode = Session.NodeNum) {or user unavailable} Then Begin
    Session.io.OutFull('|CR|15That user is marked unavailable|CR|CR|PA');
    Exit;
  End;

  If Session.User.Access(Config.ACSSysop) Then
    If Session.io.GetYN('|CR|12Force user into chat? ', False) Then
      ReqType := 9;

  FileErase (Config.DataPath + 'userchat.' + strI2S(ToNode));
  FileErase (Config.DataPath + 'userchat.' + strI2S(Session.NodeNum));

  Session.io.OutFull('|CRSending chat request to <username>...|DE|DE|CR');

  Send_Node_Message (ReqType, strI2S(ToNode) + ';C' + Str, 0);
End;

Procedure OpenUserChat (Forced: Boolean; ToNode: Byte);
Begin
  session.io.outfull('|CRstarting user2user chat|CR|PA');
End;

End.
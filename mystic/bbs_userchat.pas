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
  Str      : String;
  ToNode   : Byte;
  ReqType  : Byte = 8;
  TempChat : ChatRec;
Begin
  Repeat
    Session.io.OutFull ('|CR|09Enter node to chat with |01[|10?|01/|10List|01]|09: ');

    Str := Session.io.GetInput(3, 3, 12, '');

    If Str = '?' Then Show_Whos_Online Else
    If Str = 'Q' Then Exit Else Break;
  Until False;

  ToNode := strS2I(Str);

  If (Not GetChatRecord(ToNode, TempChat)) or (ToNode = Session.NodeNum) or
     (Not TempChat.Active) or (Not TempChat.Available) Then Begin
       Session.io.OutFull('|CR|15That user is marked unavailable.|CR|CR|PA');
       Exit;
  End;

  If Session.User.Access(Config.ACSSysop) Then
    If Session.io.GetYN('|CR|12Force user into chat? ', False) Then
      ReqType := 9;

  FileErase (Config.DataPath + 'userchat.' + strI2S(ToNode));
  FileErase (Config.DataPath + 'userchat.' + strI2S(Session.NodeNum));

  Session.io.PromptInfo[1] := TempChat.Name;

  Session.io.OutFull('|CRSending chat request to |&1...|DE|DE|CR');

  Send_Node_Message (ReqType, strI2S(ToNode) + ';C' + Str, 0);
End;

Procedure OpenUserChat (Forced: Boolean; ToNode: Byte);
Var
  fOut : File;
  fIn  : File;
  Ch   : Char;
  Done : Boolean = False;
Begin
  Session.io.OutFullLn('|CR|15Chat mode begin.|CR');

  Assign (fOut, Config.DataPath + 'userchat.' + strI2S(ToNode));
  Assign (fIn,  Config.DataPath + 'userchat.' + strI2S(Session.NodeNum));

  FileMode := 66;

  ReWrite (fOut, 1);
  ReWrite (fIn, 1);

  While Not Done Do Begin
    If Not Eof(fIn) Then
      While Not Eof(fIn) Do Begin
        BlockRead (fIn, Ch, 1);

        If Ch = #255 Then Begin
          Done := True;
          Break;
        End;

        Session.io.AnsiColor  (Session.Lang.LineChat2);
        Session.io.BufAddChar (Ch);
      End;

    Session.io.BufFlush;

    If Done Then Break;

    Ch := Session.io.InKey(25);

    Case Ch of
      #27 : If Not Forced Then Begin
              Ch := #255;
              BlockWrite (fOut, Ch, 1);
              Break;
            End;
    Else
      If Ch in [#32..#254] Then Begin
        BlockWrite (fOut, Ch, 1);

        Session.io.AnsiColor  (Session.Lang.LineChat1);
        Session.io.BufAddChar (Ch);
      End;
    End;
  End;

  Close(fOut);
  Close(fIn);

  Erase(fOut);
  Erase(fIn);

  Session.io.OutFullLn('|CR|CR|15Chat mode complete.|DE|DE|DE');
End;

End.

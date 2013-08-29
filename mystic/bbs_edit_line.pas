Unit bbs_Edit_Line;

{$I M_OPS.PAS}

Interface

Function LineEditor (Var Lines : SmallInt; MaxLen: Byte; MaxLine: SmallInt; TEdit: Boolean; Forced: Boolean;
                     Var Subj: String) : Boolean;

Implementation

Uses
  m_Strings,
  m_FileIO,
  BBS_Common,
  BBS_Records,
  BBS_DataBase,
  BBS_Core,
  BBS_FileBase,
  BBS_User;

Var
  CurLine : Integer;
  Done,
  Save    : Boolean;

Procedure MessageUpload (Var CurLine: SmallInt);
Var
  FN : String[100];
  TF : Text;
  T1 : String[30];
  T2 : String[60];
  OK : Boolean;
Begin
  OK := False;

  T1 := Session.io.PromptInfo[1];
  T2 := Session.io.PromptInfo[2];

  Session.io.OutFull (Session.GetPrompt(352));

  If Session.LocalMode Then Begin
    FN := Session.io.GetInput(70, 70, 11, '');

    If FN = '' Then Exit;

    OK := FileExist(FN);
  End Else Begin
    FN := Session.TempPath + Session.io.GetInput(70, 70, 11, '');

    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, FN);

    OK := Session.FileBase.dszSearch(JustFile(FN));
  End;

  If OK Then Begin
    Assign (TF, FN);
    Reset  (TF);

    While Not Eof(TF) and (CurLine < mysMaxMsgLines) Do Begin
      ReadLn (TF, Session.Msgs.MsgText[CurLine]);
      Inc    (CurLine);
    End;

    Close (TF);
  End;

  If Not Session.LocalMode Then FileErase(FN);

  DirClean (Session.TempPath, 'msgtmp');

  Session.io.PromptInfo[1] := T1;
  Session.io.PromptInfo[2] := T2;
End;

Procedure Quote;
Var
  InFile : Text;
  Start,
  Finish : Integer;
  Lines  : Integer;
  Text   : Array[1..mysMaxMsgLines] of String[80];
Begin
  Assign (InFile, Session.TempPath + 'msgtmp');
  {$I-} Reset (InFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(158));
    Exit;
  End;

  Lines      := 0;
  Session.io.AllowPause := True;

        While Not Eof(InFile) Do Begin
                Inc (Lines);
                ReadLn (InFile, Text[Lines]);
        End;

        Close (InFile);

        Session.io.OutFullLn(Session.GetPrompt(452));

        For Start := 1 to Lines Do Begin
    Session.io.PromptInfo[1] := strI2S(Start);
    Session.io.PromptInfo[2] := Text[Start];

    Session.io.OutFullLn (Session.GetPrompt(341));

    If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Break;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Session.io.AllowPause := True;

  Session.io.OutFull (Session.GetPrompt(159));
  Start := strS2I(Session.io.GetInput(3, 3, 11, ''));

  Session.io.OutFull (Session.GetPrompt(160));
  Finish := strS2I(Session.io.GetInput(3, 3, 11, ''));

  If (Start > 0) and (Start <= Lines) and (Finish <= Lines) Then Begin
                If Finish = 0 Then Finish := Start;
    For Lines := Start to Finish Do Begin
      If CurLine = mysMaxMsgLines Then Break;
      Session.Msgs.MsgText[CurLine] := Text[Lines];
      Inc (CurLine);
    End;
        End;
End;

Function LineEditor (Var Lines : Integer; MaxLen: Byte; MaxLine: Integer; TEdit, Forced : Boolean; Var Subj: String) : Boolean;

  Procedure Commands;
  Var
    Ch : Char;
  Begin
    Done := False;
    Save := False;

    Repeat
      Session.io.OutFull (Session.GetPrompt(166));

      Ch := Session.io.OneKey ('?ACQRSU', True);

      Case Ch of
        '?' : Session.io.OutFullLn (Session.GetPrompt(167));
        'A' : If Forced Then Begin
                Session.io.OutFull (Session.GetPrompt(307));
                Exit;
              End Else
                Done := Session.io.GetYN(Session.GetPrompt(168), False);
        'C' : Exit;
        'Q' : Begin
                Quote;
                Exit;
              End;
        'R' : Exit;
        'S' : Begin
                Save := True;
                Done := True;
              End;
        'U' : Begin
                MessageUpload(CurLine);
                Exit;
              End;
      End;
    Until Done;
  End;

  Procedure FullReDraw;
  Var
    A : Integer;
  Begin
    Session.io.PromptInfo[1] := strI2S(MaxLen);
    Session.io.PromptInfo[2] := strI2S(MaxLine);

    Session.io.OutFullLn(Session.GetPrompt(162));

    Session.io.OutFullLn(Session.GetPrompt(163));
    For A := 1 to CurLine Do Begin
      Session.io.OutRaw (Session.Msgs.MsgText[A]);
      If A <> CurLine Then Session.io.OutRawLn('');
    End;
  End;

  Procedure GetText;
  Var
    Ch : Char;
  Begin
    Repeat
      Ch := Session.io.GetKey;
      Case Ch of
        ^R  : FullReDraw;
        #8  : If Length(Session.Msgs.MsgText[CurLine]) > 0 Then Begin
                Session.io.OutBS(1, True);
                Dec(Session.Msgs.MsgText[CurLine][0]);
              End Else If CurLine > 1 Then Begin
                Dec(CurLine);

                Session.io.PromptInfo[1] := strI2S(CurLine);

                Session.io.OutFullLn (Session.GetPrompt(165));

                Session.io.OutRaw (Session.Msgs.MsgText[CurLine]);

                If Session.Msgs.MsgText[CurLine] <> '' Then Begin
                  Session.io.OutBS(1, True);
                  Dec(Session.Msgs.MsgText[CurLine][0]);
                End;
              End;
        #13 : Begin
                If CurLine < MaxLine Then Begin
                  Inc(CurLine);

                  Session.io.OutRaw (#13#10);
                End;
              End;
      Else
        If (Ch = '/') and (Length(Session.Msgs.MsgText[CurLine]) = 0) Then Begin
          Commands;
          If (Not Save) and (Not Done) Then FullReDraw;
        End Else
        If Ch in [#32..#254] Then Begin
          If Length(Session.Msgs.MsgText[Curline]) < MaxLen Then Begin
            Session.Msgs.MsgText[CurLine] := Session.Msgs.MsgText[CurLine] + Ch;

            Session.io.BufAddChar (Ch);
          End;
          If (Length(Session.Msgs.MsgText[CurLine]) > MaxLen-1) and (CurLine < MaxLine) Then Begin
            strWrap (Session.Msgs.MsgText[CurLine], Session.Msgs.MsgText[Succ(CurLine)], MaxLen);

            Inc (CurLine);

            Session.io.OutBS    (Length(Session.Msgs.MsgText[CurLine]), True);
            Session.io.OutRawLn ('');
            Session.io.OutRaw   (Session.Msgs.MsgText[CurLine]);
          End;
        End;
      End;
    Until Done;
  End;

Var
  A : Integer;
Begin
  CurLine := Lines;

  If CurLine < MaxLine Then Inc(CurLine);

  Done := False;

  For A := Lines + 1 to mysMaxMsgLines Do Session.Msgs.MsgText[A] := '';

  FullReDraw;

  GetText;

  If Save Then Begin
    Lines      := CurLine - 1;
    LineEditor := True;
  End Else
    LineEditor := False;
End;

End.

Unit bbs_General;

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  m_DateTime,
  {$IFNDEF UNIX}
    Windows,
    bbs_SysopChat,
  {$ENDIF}
  BBS_Records,
  BBS_Common,
  bbs_Edit_ANSI,
  bbs_Edit_Line;

Function  Editor (Var Lines: SmallInt; MaxLen, MaxLine: SmallInt; Forced: Boolean; Template: String; Var Subj: String) : Boolean;
Procedure Upgrade_User_Level (Now : Boolean; Var U : RecUser; Sec: Byte);
Procedure View_BBS_List (Long: Boolean; Data: String);
Procedure Add_BBS_List (Name : String);

Procedure AutoSig_Edit;
Procedure AutoSig_View;

Procedure ShowUserList     (Data: String);
Procedure ShowLastCallers;
Procedure ShowBBSHistory   (LastDays: Word);
Procedure ShowOneLiners    (Data: String);
Procedure ShowRandomQuote;

Procedure Add_TimeBank;
Procedure Get_TimeBank;
Procedure Add_Booth;
Procedure Voting_Booth (Forced: Boolean; Num: Integer);
Procedure Voting_Result (Data: Integer);
Procedure Voting_Booth_New;
Procedure Voting_Booth_Delete;
Procedure View_Directory (Data: String; ViewType: Byte);
Procedure AnsiViewer (Bar: RecPercent; Data: String);

{$IFNDEF UNIX}
  Procedure PageForSysopChat (Forced: Boolean);
{$ENDIF}

Implementation

Uses
  DOS,
  m_FileIO,
  m_QuickSort,
  bbs_Core,
  BBS_DataBase,
  bbs_MsgBase_Ansi,
  bbs_NodeInfo;

Function AnsiEditor (Var Lines: SmallInt; WrapPos: Byte; MaxLines: SmallInt; Forced: Boolean; Template: String; Var Subj: String) : Boolean;
Var
  Editor : TEditorANSI;
  Count  : LongInt;
Begin
  Editor := TEditorANSI.Create(Pointer(Session), Template);

  Editor.Forced      := Forced;
  Editor.Subject     := Subj;
  Editor.MaxMsgLines := MaxLines;
  Editor.MaxMsgCols  := WrapPos;

  For Count := 1 to Lines Do
    Editor.SetLineText (Count, Session.Msgs.MsgText[Count]);

  Result := Editor.Edit;
  Subj   := Editor.Subject;

  If Result Then Begin
    For Count := 1 to Editor.LastLine Do
      Session.Msgs.MsgText[Count] := Editor.GetLineText(Count);

    Lines := Editor.LastLine;
  End;

  Editor.Free;
End;

Function Editor (Var Lines: SmallInt; MaxLen, MaxLine: SmallInt; Forced: Boolean; Template: String; Var Subj: String) : Boolean;
Begin
  If (Session.io.Graphics > 0) and ((Session.User.ThisUser.EditType = 1) or ((Session.User.ThisUser.EditType = 2) and Session.io.GetYN(Session.GetPrompt(106), True))) Then
    Editor := AnsiEditor(Lines, MaxLen, MaxLine, Forced, Template, Subj)
  Else
    Editor := LineEditor(Lines, MaxLen, MaxLine, False, Forced, Subj);
End;

Procedure Upgrade_User_Level (Now: Boolean; Var U: RecUser; Sec: Byte);
Var
  Flags   : Char;
  TempSec : RecSecurity;
Begin
  Assign (Session.User.SecurityFile, bbsCfg.DataPath + 'security.dat');
  Reset  (Session.User.SecurityFile);
  Seek   (Session.User.SecurityFile, Sec - 1);
  Read   (Session.User.SecurityFile, TempSec);
  Close  (Session.User.SecurityFile);

  U.Security  := Sec;
  U.StartMenu := TempSec.StartMenu;
  U.TimeLeft  := TempSec.Time;
  U.Expires   := '00/00/00';
  U.ExpiresTo := TempSec.ExpiresTo;

  If TempSec.Expires > 0 Then
    U.Expires := DateJulian2Str(CurDateJulian + TempSec.Expires, 1);

  For Flags := 'A' to 'Z' Do
    If Ord(Flags) - 64 in TempSec.AF1 Then
      U.AF1 := U.AF1 + [Ord(Flags) - 64]
    Else
      If TempSec.Hard Then
        U.AF1 := U.AF1 - [Ord(Flags) - 64];

  For Flags := 'A' to 'Z' Do
    If Ord(Flags) - 64 in TempSec.AF2 Then
      U.AF2 := U.AF2 + [Ord(Flags) - 64]
    Else
      If TempSec.Hard Then
        U.AF2 := U.AF2 - [Ord(Flags) - 64];

  If Now Then Session.User.Security := TempSec;
End;

Procedure AutoSig_Edit;
Var
  DF    : File;
  Lines : Integer;
  Str   : String;
Begin
  If bbsCfg.MaxAutoSig = 0 Then Exit;

  Assign (DF, bbsCfg.DataPath + 'autosig.dat');

  If Session.User.ThisUser.SigLength > 0 Then Begin
    Reset (DF, 1);
    Seek  (DF, Session.User.ThisUser.SigOffset);

    For Lines := 1 to Session.User.ThisUser.SigLength Do Begin
      BlockRead (DF, Session.Msgs.MsgText[Lines][0], 1);
      BlockRead (DF, Session.Msgs.MsgText[Lines][1], Ord(Session.Msgs.MsgText[Lines][0]));
    End;

    Close (DF);
  End Else
    Lines := 0;

  Str := 'Signature Editor'; {++lang}

  If Editor (Lines, 78, bbsCfg.MaxAutoSig, False, fn_tplMsgEdit, Str) Then Begin
    {$I-} Reset (DF, 1); {$I+}

    If IoResult <> 0 Then ReWrite (DF, 1);

    Session.User.ThisUser.SigLength := Lines;
    Session.User.ThisUser.SigOffset := FileSize(DF);

    Seek (DF, Session.User.ThisUser.SigOffset);

    For Lines := 1 to Lines Do
      BlockWrite (DF, Session.Msgs.MsgText[Lines][0], Length(Session.Msgs.MsgText[Lines]) + 1);

    Close (DF);
  End;
End;

Procedure AutoSig_View;
Var
  DF : File;
  A  : Byte;
  S  : String[79];
Begin
  If Session.User.ThisUser.SigLength > 0 Then Begin
    Assign (DF, bbsCfg.DataPath + 'autosig.dat');
    Reset  (DF, 1);
    Seek   (DF, Session.User.ThisUser.SigOffset);

    For A := 1 to Session.User.ThisUser.SigLength Do Begin
      BlockRead (DF, S[0], 1);
      BlockRead (DF, S[1], Ord(S[0]));

      Session.io.OutFullLn (S);
    End;

    Close (DF);
  End Else
    Session.io.OutFull (Session.GetPrompt(336));
End;

Procedure ShowRandomQuote;
Var
  TF     : Text;
  TxtBuf : Array[1..2048] of Char;
  Total  : Integer;
  Count  : Integer;
  Str    : String;
Begin
  Assign     (TF, bbsCfg.DataPath + 'quotes.dat');
  SetTextBuf (TF, TxtBuf);

  {$I-} Reset (TF); {$I+}

  If IoResult <> 0 Then Exit;

  Total := 0;

  While Not Eof(TF) Do Begin
    ReadLn (TF, Str);

    If Str[1] = '*' Then Inc(Total);
  End;

  If Total = 0 Then Begin
    Close (TF);
    Exit;
  End;

  Count := Random(Total) + 1;
  Total := 0;

  Reset (TF);

  While Total <> Count Do Begin
    ReadLn (TF, Str);
    If Str[1] = '*' Then Inc(Total);
  End;

  While Not Eof(TF) Do Begin
    ReadLn (TF, Str);
    If Str[1] = '*' Then Break Else Session.io.OutFullLn (Str);
  End;

  Close (TF);
End;

Function SearchBBS (Str: String; Temp: BBSListRec) : Boolean;
Begin
  Str := strUpper(Str);

  SearchBBS := Bool_Search(Str, Temp.BBSName) or
               Bool_Search(Str, Temp.SysopName) or
               Bool_Search(Str, Temp.Software) or
               Bool_Search(Str, Temp.Telnet) or
               Bool_Search(Str, Temp.Phone) or
               Bool_Search(Str, Temp.Location);
End;

Procedure Add_BBS_List (Name : String);
Var
  BBSFile : File of BBSListRec;
  BBSList : BBSListRec;
  Temp    : BBSListRec;
Begin
  If Name = '' Then Exit;

  Session.io.OutFull (Session.GetPrompt(361));
  Case Session.io.OneKey ('DTBQ', True) of
    'D' : BBSList.cType := 0;
    'T' : BBSList.cType := 1;
    'B' : BBSList.cType := 2;
    'Q' : Exit;
  End;

  Session.io.OutRawLn('');

  If BBSList.cType in [0, 2] Then Begin
    Session.io.OutFull (Session.GetPrompt(283));
    BBSList.Phone := Session.io.GetInput(15, 15, 12, '');
    If BBSList.Phone = '' Then Exit;
  End Else
    BBSList.Phone := 'None';  //++lang

  If BBSList.cType in [1, 2] Then Begin
    Session.io.OutFull (Session.GetPrompt(330));
    BBSList.Telnet := Session.io.GetInput(40, 40, 11, '');
    If BBSList.Telnet = '' Then Exit;
  End Else
    BBSList.Telnet := 'None'; //++lang

  Assign (BBSFile, bbsCfg.DataPath + Name + '.bbi');
  {$I-} Reset(BBSFile); {$I+}
  If IoResult <> 0 Then ReWrite(BBSFile);

  While Not Eof(BBSFile) Do Begin
    Read (BBSFile, Temp);

    If ((strUpper(BBSList.Phone)  = strUpper(Temp.Phone))  and (Temp.Phone  <> 'None')) or
       ((strUpper(BBSList.Telnet) = strUpper(Temp.Telnet)) and (Temp.Telnet <> 'None')) Then Begin
      Session.io.OutFullLn(Session.GetPrompt(362));
      Close (BBSFile);
      Exit;
    End;
  End;
  Close (BBSFile);

  Session.io.OutFull (Session.GetPrompt(284));
  BBSList.BBSName := Session.io.GetInput(30, 30, 11, '');

  Session.io.OutFull (Session.GetPrompt(285));
  BBSList.Location := Session.io.GetInput(25, 25, 18, '');

  Session.io.OutFull (Session.GetPrompt(286));
  BBSList.SysopName := Session.io.GetInput(30, 30, 11, '');

  Session.io.OutFull (Session.GetPrompt(287));
  BBSList.BaudRate := Session.io.GetInput(6, 6, 11, '');

  Session.io.OutFull (Session.GetPrompt(288));
  BBSList.Software := Session.io.GetInput(10, 10, 11, '');

  If Session.io.GetYN(Session.GetPrompt(290), True) Then Begin
    BBSList.Deleted  := False;
    BBSList.AddedBy  := Session.User.ThisUser.Handle;
    BBSList.Verified := CurDateDos;

    Reset (BBSFile);
    Seek  (BBSFile, FileSize(BBSFile));
    Write (BBSFile, BBSList);
    Close (BBSFile);
  End;
End;

Procedure View_BBS_List (Long : Boolean; Data : String);
Var
  BBSFile : File of BBSListRec;
  BBSList : BBSListRec;
  Name    : String[8];
  Str     : String;
  Search  : Boolean;
Begin
  Search := False;

  If Pos(';', Data) > 0 Then Begin
    Name   := Copy(Data, 1, Pos(';', Data) - 1);
    Search := Pos(';SEARCH', strUpper(Data)) > 0;
  End Else
    Name := Data;

  If Name = '' Then Exit;

  FileMode := 66;

  Assign (BBSFile, bbsCfg.DataPath + Name + '.bbi');
  {$I-} Reset(BBSFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(291));
    Exit;
  End;

  If Search Then Begin
    Session.io.OutFull (Session.GetPrompt(292));
    Str := Session.io.GetInput(30, 30, 11, '');
  End;

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  If Long Then
    Session.io.OutFullLn (Session.GetPrompt(264))
  Else
    Session.io.OutFullLn (Session.GetPrompt(260));

  While Not EOF(BBSFile) Do Begin
    Read (BBSFile, BBSList);

    If BBSList.Deleted Then Continue;

    If (Search and SearchBBS(Str, BBSList)) or Not Search Then Begin
      Session.io.PromptInfo[1] := BBSList.BBSName;

      Case BBSList.cType of
        0 : Begin
              Session.io.PromptInfo[3] := BBSList.Phone;
              Session.io.PromptInfo[2] := 'DIALUP'; //++lang
            End;
        1 : Begin
              Session.io.PromptInfo[3] := BBSList.Telnet;
              Session.io.PromptInfo[2] := 'TELNET'; //++lang
            End;
        2 : Begin
              Session.io.PromptInfo[3] := BBSList.Telnet;
              Session.io.PromptInfo[2] := 'DU/TEL'; //++lang
            End;
      End;

      If (BBSList.cType = 0) and Long Then Session.io.PromptInfo[3] := BBSList.Telnet;

      Session.io.PromptInfo[4]  := BBSList.Software;
      Session.io.PromptInfo[5]  := BBSList.Location;
      Session.io.PromptInfo[6]  := BBSList.SysopName;
      Session.io.PromptInfo[7]  := BBSList.BaudRate;
      Session.io.PromptInfo[8]  := BBSList.AddedBy;
      Session.io.PromptInfo[9]  := BBSList.Phone;
      Session.io.PromptInfo[10] := DateDos2Str(BBSList.Verified, Session.User.ThisUser.DateType);

      If Long Then Begin
        Session.io.OutFullLn (Session.GetPrompt(265));
        Session.io.OutFull   (Session.GetPrompt(267));
        Case Session.io.OneKey('DQV'#13, True) of
          'D' : If Session.User.Access(bbsCfg.AcsSysop) or (strUpper(BBSList.AddedBy) = strUpper(Session.User.ThisUser.Handle)) Then Begin
                  If Session.io.GetYN(Session.GetPrompt(294), False) Then Begin
                    BBSList.Deleted := True;
                    Seek  (BBSFile, FilePos(BBSFile) - 1);
                    Write (BBSFile, BBSList);
                  End;
                End Else
                  Session.io.OutFullLn (Session.GetPrompt(295));
          'Q' : Break;
          'V' : If Session.io.GetYN(Session.GetPrompt(266), False) Then Begin
                  BBSList.Verified := CurDateDos;

                  Seek  (BBSFile, FilePos(BBSFile) - 1);
                  Write (BBSFile, BBSList);
                End;
        End;
      End Else Begin
        Session.io.OutFullLn (Session.GetPrompt(261));

        If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
          Case Session.io.MorePrompt of
            'N' : Break;
            'C' : Session.io.AllowPause := False;
          End;
      End;
    End;
  End;

  Close (BBSFile);

  If Not Long Then
    Session.io.OutFullLn (Session.GetPrompt(262));
End;

Procedure ShowUserList (Data: String);
Var
  Total    : Integer;
  TempUser : RecUser;
Begin
  If Data = 'SEARCH' Then Begin
    Session.io.OutFull (Session.GetPrompt(32));
    Data := Session.io.GetInput (30, 30, 12, '');
  End;

  Reset  (Session.User.UserFile);

  Session.io.PausePtr   := 1;
  Session.io.AllowPause := True;

  Session.io.OutFullLn (Session.GetPrompt(29));

  Total := 0;

  While Not Eof(Session.User.UserFile) Do Begin
    Read (Session.User.UserFile, TempUser);

    If (TempUser.Flags AND UserDeleted <> 0) and
       (TempUser.Flags AND UserQWKNetwork <> 0) Then Continue;

    Session.io.PromptInfo[1]  := TempUser.Handle;
    Session.io.PromptInfo[2]  := TempUser.City;
    Session.io.PromptInfo[3]  := DateDos2Str(TempUser.LastOn, Session.User.ThisUser.DateType);
    Session.io.PromptInfo[4]  := TempUser.Gender;
    Session.io.PromptInfo[5]  := strI2S(TempUser.Security);
    Session.io.PromptInfo[6]  := TempUser.Address;
    Session.io.PromptInfo[7]  := strI2S(DaysAgo(TempUser.Birthday, 1) DIV 365);
    Session.io.PromptInfo[8]  := TempUser.Email;
    Session.io.PromptInfo[9]  := TempUser.UserInfo;
    Session.io.PromptInfo[10] := TempUser.OptionData[1];
    Session.io.PromptInfo[11] := TempUser.OptionData[2];
    Session.io.PromptInfo[12] := TempUser.OptionData[3];

    If (Data = '') or (Pos(Data, strUpper(TempUser.Handle)) > 0) Then Begin
      Session.io.OutFullLn (Session.GetPrompt(30));
      Inc (Total);

      If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;
  End;

  Close (Session.User.UserFile);

  Session.io.PromptInfo[1] := strI2S(Total);

  Session.io.OutFull (Session.GetPrompt(31));
End;

Procedure ShowLastCallers;
Begin
  Session.io.OutFullLn (Session.GetPrompt(141));

  Reset (Session.LastOnFile);

  While Not Eof(Session.LastOnFile) Do Begin
    Read (Session.LastOnFile, Session.LastOn);

    Session.io.PromptInfo[1]  := Session.LastOn.Handle;
    Session.io.PromptInfo[2]  := strI2S(Session.LastOn.Node);
    Session.io.PromptInfo[3]  := Session.LastOn.City;
    Session.io.PromptInfo[4]  := DateDos2Str(Session.LastOn.DateTime, Session.User.ThisUser.DateType);
    Session.io.PromptInfo[5]  := TimeDos2Str(Session.LastOn.DateTime, 1);
    Session.io.PromptInfo[7]  := strI2S(Session.LastOn.CallNum);
    Session.io.PromptInfo[8]  := Session.LastOn.Address;
    Session.io.PromptInfo[9]  := Session.LastOn.UserInfo;
    Session.io.PromptInfo[10] := Session.LastOn.EmailAddr;
    Session.io.PromptInfo[11] := Session.LastOn.OptionData[1];
    Session.io.PromptInfo[12] := Session.LastOn.OptionData[2];
    Session.io.PromptInfo[13] := Session.LastOn.OptionData[3];

    Session.io.OutFullLn (Session.GetPrompt(142));
  End;

  Close (Session.LastOnFile);

  Session.io.OutFull (Session.GetPrompt(143));
End;

Procedure Add_TimeBank;
Var
  A : Integer;
Begin
  Session.io.OutFull (Session.GetPrompt(172));

  A := strS2I(Session.io.GetInput(4, 4, 11, ''));

  If A > 0 Then
    If (A < Session.TimeLeft - 4) Then Begin
      If (Session.User.Security.MaxTB > 0) and (Session.User.ThisUser.TimeBank + A > Session.User.Security.MaxTB) Then Begin
        Session.io.OutFullLn (Session.GetPrompt(209));
        Exit;
      End;

      Inc (Session.User.ThisUser.TimeBank, A);

      Session.SetTimeLeft (Session.TimeLeft - A);
    End Else
      Session.io.OutFullLn (Session.GetPrompt(210));
End;

Procedure Get_TimeBank;
Var
  A : Integer;
Begin
  Session.io.OutFull (Session.GetPrompt(173));

  A := strS2I(Session.io.GetInput(4, 4, 11, ''));

  If (A > 0) and (A <= Session.User.ThisUser.TimeBank) Then Begin
    Dec (Session.User.ThisUser.TimeBank, A);

    Session.SetTimeLeft (Session.TimeLeft + A);
  End;
End;

Procedure ShowOneLiners (Data : String);
Const
  MaxLines : Byte = 9;
  MaxLen   : Byte = 75;
  MaxField : Byte = 75;
Var
  OneLineFile : File of OneLineRec;
  OneLine     : OneLineRec;
  Str         : String;
  A           : Byte;
Begin
  A := Pos(';', Data);

  If A > 0 Then Begin
    MaxLines := strS2I(Copy(Data, 1, A - 1)) - 1;

    Delete (Data, 1, A);
    A := Pos(';', Data);

    MaxLen   := strS2I(Copy(Data, 1, A - 1));
    MaxField := strS2I(Copy(Data, A + 1, Length(Data)));
  End;

  FileMode := 66;

  Assign (OneLineFile, bbsCfg.DataPath + 'oneliner.dat');
  {$I-} Reset (OneLineFile); {$I+}

  If IoResult <> 0 Then ReWrite (OneLineFile);

  Repeat
    Reset  (OneLineFile);
    Session.io.OutFullLn (Session.GetPrompt(188));

    While Not Eof(OneLineFile) Do Begin
      Read (OneLineFile, OneLine);

      Session.io.PromptInfo[1] := OneLine.Text;
      Session.io.PromptInfo[2] := OneLine.From;
      Session.io.PromptInfo[3] := OneLine.From[1];

      If Pos(' ', OneLine.From) > 0 Then
        Session.io.PromptInfo[3] := Session.io.PromptInfo[3] + OneLine.From[Pos(' ', OneLine.From) + 1];

      Session.io.OutFullLn (Session.GetPrompt(337));
    End;

    If Session.io.GetYN(Session.GetPrompt(189), False) Then Begin
      Session.io.OutFull (Session.GetPrompt(190));

      Str := Session.io.GetInput (MaxField, MaxLen, 11, '');

      If Str <> '' Then Begin
        If FileSize(OneLineFile) > MaxLines Then
          KillRecord (OneLineFile, 1, SizeOf(OneLineRec));

        OneLine.Text := Str;
        OneLine.From := Session.User.ThisUser.Handle;

        Seek  (OneLineFile, FileSize(OneLineFile));
        Write (OneLineFile, OneLine);
      End;
    End Else
      Break;
  Until False;

  Close (OneLineFile);
End;

Procedure Add_Booth;
Var
  A : Byte;
Begin
  If Not Session.io.GetYN (Session.GetPrompt(275), True) Then Exit;

  Reset (Session.VoteFile);

  If FileSize (Session.VoteFile) = mysMaxVoteQuestion Then Begin
    Close (Session.VoteFile);
    Session.io.OutFull (Session.GetPrompt(276));
    Exit;
  End;

  Close (Session.VoteFile);

  Session.io.OutFull (Session.GetPrompt(277));
  Session.Vote.Question := Session.io.GetInput(78, 78, 11, '');

  If Session.Vote.Question = '' Then Exit;

  Session.io.OutFullLn (Session.GetPrompt(278));

  A := 1;

  While A <= 15 Do Begin
    Session.io.PromptInfo[1] := strI2S(A);
    Session.io.OutFull (Session.GetPrompt(279));
    Session.Vote.Answer[A].Text := Session.io.GetInput(40, 40, 11, '');

    If Session.Vote.Answer[A].Text = '' Then Begin
      Dec (A);
      Break;
    End;

    Session.Vote.Answer[A].Votes := 0;

    Inc(A);
  End;

  If A = 0 Then Exit;

  Session.Vote.AnsNum   := A;
  Session.Vote.Votes    := 0;
  Session.Vote.ACS      := '';
  Session.Vote.AddACS   := 's999';
  Session.Vote.ForceACS := 's999';

  If Session.io.GetYN(Session.GetPrompt(280), True) Then Session.Vote.AddACS := '';

  If Session.io.GetYN(Session.GetPrompt(281), True) Then Begin
    Reset (Session.VoteFile);
    Seek  (Session.VoteFile, FileSize(Session.VoteFile));
    Write (Session.VoteFile, Session.Vote);
    Close (Session.VoteFile);
  End;
End;

{ VOTING BOOTH SHIT }

Function Voting_List : Byte;
Var
  Total : Byte;
Begin
  Reset (Session.VoteFile);

  Session.io.OutFullLn (Session.GetPrompt(241));

  Total := 0;

  While Not Eof(Session.VoteFile) Do Begin
    Read (Session.VoteFile, Session.Vote);

    If Session.User.Access(Session.Vote.ACS) Then Begin
      Inc (Total);

      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.PromptInfo[2] := Session.Vote.Question;

      If Session.User.ThisUser.Vote[FilePos(Session.VoteFile)] = 0 Then
        Session.io.PromptInfo[3] := '*'  //++lang
      Else
        Session.io.PromptInfo[3] := ' ';
      Session.io.OutFullLn (Session.GetPrompt(242));
    End;
  End;

  Close (Session.VoteFile);

  If Total = 0 Then Session.io.OutFullLn (Session.GetPrompt(243));

  Voting_List := Total;
End;

Procedure Voting_Result (Data : Integer);
Var
  A : SmallInt;
  P : SmallInt;
Begin
  Reset (Session.VoteFile);

  If (Data > 0) and (Data <= FileSize(Session.VoteFile)) Then Begin
    Seek  (Session.VoteFile, Data - 1);
    Read  (Session.VoteFile, Session.Vote);
    Close (Session.VoteFile);
  End Else Begin
    A := Voting_List;

    If A = 0 Then Exit;

    Repeat
      Session.io.PromptInfo[1] := strI2S(A);
      Session.io.OutFull (Session.GetPrompt(263));
      P := strS2I(Session.io.GetInput(2, 2, 12, ''));
      If P = 0 Then Exit;
      If P <= A Then Break;
    Until False;

    Reset (Session.VoteFile);
    A := 0;
    Repeat
      Read (Session.VoteFile, Session.Vote);
      If Session.User.Access(Session.Vote.ACS) Then Inc(A);
    Until A = P;
    Close (Session.VoteFile);
  End;

  Session.io.PromptInfo[1] := Session.Vote.Question;
  Session.io.PromptInfo[2] := strI2S(Session.Vote.Votes);

  Session.io.OutFullLn (Session.GetPrompt(249));

  For A := 1 to Session.Vote.AnsNum Do Begin
    Session.io.PromptInfo[1] := strI2S(A);
    Session.io.PromptInfo[2] := Session.Vote.Answer[A].Text;
    Session.io.PromptInfo[3] := strI2S(Session.Vote.Answer[A].Votes);

    If Session.Vote.Votes = 0 Then Begin
      Session.io.PromptInfo[4] := '0';
      Session.io.PromptInfo[5] := '';
    End Else Begin
      Session.io.PromptInfo[5] := Session.io.DrawPercent(Session.Theme.VotingBar, Session.Vote.Answer[A].Votes, Session.Vote.Votes, P);
      Session.io.PromptInfo[4] := strI2S(P);
    End;

    Session.io.OutFullLn (Session.GetPrompt(250));
  End;

  Session.io.OutFull (Session.GetPrompt(251));
End;

Procedure Voting_Booth_New;
Var
  NewQues : Array[1..mysMaxVoteQuestion] of Boolean;
  Pos     : Byte;
Begin
  Reset (Session.VoteFile);

  While Not Eof(Session.VoteFile) Do Begin
    Read (Session.VoteFile, Session.Vote);
    If Session.User.Access(Session.Vote.ACS) Then
      NewQues[FilePos(Session.VoteFile)] := (Session.User.ThisUser.Vote[FilePos(Session.VoteFile)] = 0)
    Else
      NewQues[FilePos(Session.VoteFile)] := False;
  End;

  Close (Session.VoteFile);

  For Pos := 1 to mysMaxVoteQuestion Do
    If NewQues[Pos] Then Voting_Booth (False, Pos);
End;

Procedure Voting_Booth (Forced: Boolean; Num: Integer);
Var
  VPos  : Byte;
  Temp  : Byte;
  Total : Byte;
  Str   : String[40];
Begin

  If Not Forced And (Num = 0) Then Begin
    Total := Voting_List;

    If Total = 0 Then Exit;

    Repeat
      Session.io.PromptInfo[1] := strI2S(Total);
      Session.io.OutFull (Session.GetPrompt(244));
      Temp := strS2I(Session.io.GetInput(2, 2, 12, ''));
      If Temp = 0 Then Exit;
      If Temp <= Total Then Break;
    Until False;

    Total := 0;
    Reset (Session.VoteFile);
    Repeat
      Read (Session.VoteFile, Session.Vote);
      If Session.User.Access(Session.Vote.ACS) Then Inc(Total);
    Until Total = Temp;
  End Else Begin
    Reset (Session.VoteFile);
    If Num > FileSize(Session.VoteFile) Then Begin
      Close (Session.VoteFile);
      Exit;
    End;
    Seek (Session.VoteFile, Num - 1);
    Read (Session.VoteFile, Session.Vote);
  End;

  VPos := FilePos(Session.VoteFile);

  Repeat
    Session.io.PromptInfo[1] := Session.Vote.Question;
    Session.io.OutFullLn (Session.GetPrompt(245));
    For Temp := 1 to Session.Vote.AnsNum Do Begin
      Session.io.PromptInfo[1] := strI2S(Temp);
      Session.io.PromptInfo[2] := Session.Vote.Answer[Temp].Text;
      If Session.User.ThisUser.Vote[VPos] = Temp Then
        Session.io.PromptInfo[3] := '*' //++lang
      Else
        Session.io.PromptInfo[3] := ' ';
      Session.io.OutFullLn (Session.GetPrompt(246));
    End;

    If Session.User.Access(Session.Vote.AddACS) and (Session.Vote.AnsNum < 15) Then Begin
      Session.io.PromptInfo[1] := strI2S(Session.Vote.AnsNum + 1);
      Session.io.PromptInfo[2] := Session.GetPrompt(252);
      Session.io.PromptInfo[3] := ' ';
      Session.io.OutFullLn (Session.GetPrompt(246));
    End;

    Session.io.OutFull (Session.GetPrompt(247));
    Temp := strS2I(Session.io.GetInput(2, 2, 12, ''));

    If (Session.Vote.AnsNum < 15) and Session.User.Access(Session.Vote.AddACS) and (Temp = Succ(Session.Vote.AnsNum)) Then Begin
      Session.io.OutFull (Session.GetPrompt(253));
      Str := Session.io.GetInput (40, 40, 11, '');
      If Str <> '' Then Begin
        Inc (Session.Vote.AnsNum);
        Session.Vote.Answer[Session.Vote.AnsNum].Text  := Str;
        Session.Vote.Answer[Session.Vote.AnsNum].Votes := 0;
      End;
    End;

    If (Temp > 0) and (Temp <= Session.Vote.AnsNum) Then Begin
      If Session.User.ThisUser.Vote[VPos] <> 0 Then Begin
        Dec (Session.Vote.Answer[Session.User.ThisUser.Vote[VPos]].Votes);
        Dec (Session.Vote.Votes);
      End;
      Inc(Session.Vote.Answer[Temp].Votes);
      Inc(Session.Vote.Votes);
      Session.User.ThisUser.Vote[VPos] := Temp;

      Seek  (Session.VoteFile, VPos - 1);
      Write (Session.VoteFile, Session.Vote);
      Break;
    End Else
      If Forced Then Session.io.OutFull (Session.GetPrompt(254)) Else Break;
  Until False;

  Close (Session.VoteFile);
  If Session.io.GetYN (Session.GetPrompt(248), True) Then Voting_Result(VPos);
End;

Procedure Voting_Booth_Delete;
Var
  Max : LongInt;
  A   : LongInt;
  C   : LongInt;
Begin
  Max := Voting_List;

  Session.io.OutFull('|CR|09Delete which question? ');

  A := strS2I(Session.io.GetInput(2, 2, 12, ''));

  If (A > 0) and (A <= Max) Then Begin
    Max := 0;

    Reset (Session.VoteFile);

    Repeat
      Read (Session.VoteFile, Session.Vote);

      If Session.User.Access(Session.Vote.ACS) Then Inc(Max);
    Until Max = A;

    A := FilePos(Session.VoteFile);

    Session.io.OutFullLn ('|CR|12Deleting...');

    KillRecord (Session.VoteFile, A, SizeOf(VoteRec));

    Close (Session.VoteFile);

    Reset (Session.User.UserFile);

    While Not Eof(Session.User.UserFile) Do Begin
      Read (Session.User.UserFile, Session.User.TempUser);

      For C := A To 19 Do
        Session.User.TempUser.Vote[C] := Session.User.TempUser.Vote[C+1];

      Session.User.TempUser.Vote[20] := 0;

      Seek  (Session.User.UserFile, FilePos(Session.User.UserFile) - 1);
      Write (Session.User.UserFile, Session.User.TempUser);
    End;

    Close (Session.User.UserFile);

    For C := A to 19 Do
      Session.User.ThisUser.Vote[C] := Session.User.ThisUser.Vote[C+1];

    Session.User.ThisUser.Vote[20] := 0;
  End;
End;

Procedure ShowBBSHistory (LastDays: Word);
Var
  Temp : RecHistory;
  Days : Word;
Begin
  Assign (Session.HistoryFile, bbsCfg.DataPath + 'history.dat');
  {$I-} Reset(Session.HistoryFile); {$I+}

  If IoResult <> 0 Then
    Session.io.OutFullLn (Session.GetPrompt(454))
  Else Begin
    If (LastDays > 0) And (FileSize(Session.HistoryFile) >= LastDays) Then
      Seek (Session.HistoryFile, FileSize(Session.HistoryFile) - LastDays);

    Session.io.AllowPause := True;
    Session.io.PausePtr   := 1;
    Days       := 0;

    Session.io.OutFullLn (Session.GetPrompt(455));

    While Not Eof(Session.HistoryFile) Do Begin
      Read (Session.HistoryFile, Temp);

      Session.io.PromptInfo[1] := DateDos2Str(Temp.Date, Session.User.ThisUser.DateType);
      Session.io.PromptInfo[2] := strI2S(Temp.Calls);
      Session.io.PromptInfo[3] := strI2S(Temp.NewUsers);
      Session.io.PromptInfo[4] := strI2S(Temp.Posts);
      Session.io.PromptInfo[5] := strI2S(Temp.Emails);
      Session.io.PromptInfo[6] := strI2S(Temp.Downloads);
      Session.io.PromptInfo[7] := strI2S(Temp.DownloadKB);
      Session.io.PromptInfo[8] := strI2S(Temp.Uploads);
      Session.io.PromptInfo[9] := strI2S(Temp.UploadKB);

      Session.io.OutFullLn (Session.GetPrompt(456));

      Inc (Days);

      If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
        Case Session.io.MorePrompt of
          'N' : Break;
          'C' : Session.io.AllowPause := False;
        End;
    End;

    Close (Session.HistoryFile);

    Session.io.PromptInfo[1] := strI2S(Days);

    Session.io.OutFullLn (Session.GetPrompt(457));
  End;
End;

Function ReadSauceInfo (FN: String; Var Sauce: RecSauceInfo) : Boolean;
Var
  DF  : File;
  Str : String;
  Res : LongInt;
Begin
  Result := False;

  Assign (DF, FN);

  {$I-} Reset (DF, 1); {$I+}

  If IoResult <> 0 Then Exit;

  {$I-} Seek (DF, FileSize(DF) - 130); {$I+}

  If IoResult <> 0 Then Begin
    Close (DF);
    Exit;
  End;

  BlockRead (DF, Str[1], 130);

  Str[0] := #130;

  Close (DF);

  Res := Pos('SAUCE', Copy(Str, 1, 7));

  If Res > 0 Then Begin
    Result := True;

    Sauce.Title  := strReplace(Copy(Str,  7 + Res, 35), #0, #32);
    Sauce.Author := strReplace(Copy(Str, 42 + Res, 20), #0, #32);
    Sauce.Group  := strReplace(Copy(Str, 62 + Res, 20), #0, #32);
  End;
End;

Procedure View_Directory (Data: String; ViewType: Byte);
Const
  vtMaxList = 1000;

Type
  DirRec = Record
    Desc   : String[160];
    Size   : LongInt;
    Date   : LongInt;
    IsDir  : Boolean;
    Title  : String[34];
    Author : String[19];
    Group  : String[19];
  End;

Var
  WinTop   : Byte;
  WinBot   : Byte;
  WinSize  : Byte;
  DirList  : Array[1..vtMaxList] of ^DirRec;
  DirCount : LongInt = 0;
  CurTop   : LongInt = 1;
  CurBot   : LongInt = 1;
  CurPos   : LongInt = 1;
  CurPath  : String;
  Root     : String;

  Procedure BuildDirectory (Path: String);
  Var
    SR       : SearchRec;
    Count    : Word;
    Sauce    : RecSauceInfo;
    Temp     : String;
    SortLoop : Word;
    SortPos  : Word;
    Sort     : TQuickSort;
  Begin
    For Count := DirCount Downto 1 Do
      Dispose(DirList[Count]);

    Sort     := TQuickSort.Create;
    Temp     := Session.GetPrompt(473);
    DirCount := 0;

    For Count := 1 to 2 Do Begin
      FindFirst (Path + '*', AnyFile, SR);

      While (DosError = 0) And (DirCount < vtMaxList) Do Begin
        If (SR.Name = '.') or ((Path = Root) And (SR.Name = '..')) Then Begin
          FindNext (SR);
          Continue;
        End;

        If ((Count = 1) And (SR.Attr And Directory = 0)) or
           ((Count = 2) And (SR.Attr And Directory <> 0)) Then Begin
             FindNext(SR);
             Continue;
        End;

        Inc (DirCount);

        New (DirList[DirCount]);

        DirList[DirCount]^.Desc  := SR.Name;
        DirList[DirCount]^.Size  := SR.Size;
        DirList[DirCount]^.Date  := SR.Time;

        If (SR.Attr And Directory) = 0 Then Begin
          DirList[DirCount]^.IsDir := False;

          If ReadSauceInfo(Path + SR.Name, Sauce) Then Begin
            DirList[DirCount]^.Title  := Sauce.Title;
            DirList[DirCount]^.Author := Sauce.Author;
            DirList[DirCount]^.Group  := Sauce.Group;
          End Else Begin
            DirList[DirCount]^.Title  := strWordGet(1, Temp, ';');
            DirList[DirCount]^.Author := strWordGet(2, Temp, ';');
            DirList[DirCount]^.Group  := strWordGet(3, Temp, ';');
          End;
        End Else
          DirList[DirCount]^.IsDir := True;

        FindNext (SR);
      End;

      FindClose (SR);

      Case Count of
        1 : Begin
              SortPos := DirCount;

              For SortLoop := 1 to DirCount Do
                Sort.Add(strUpper(DirList[SortLoop]^.Desc), LongInt(@DirList[SortLoop]^));

              Sort.Sort(1, DirCount, qAscending);

              For SortLoop := 1 to DirCount Do
                DirList[SortLoop] := Pointer(Sort.Data[SortLoop]^.Ptr);
            End;
        2 : If SortPos <> DirCount Then Begin
              Sort.Clear;

              For SortLoop := Succ(SortPos) to DirCount Do
                Sort.Add(strUpper(DirList[SortLoop]^.Desc), LongInt(@DirList[SortLoop]^));

              Sort.Sort(1, DirCount - SortPos, qAscending);

              For SortLoop := 1 to DirCount - SortPos Do
                DirList[SortLoop + SortPos] := Pointer(Sort.Data[SortLoop]^.Ptr);
            End;
      End;
    End;

    Sort.Free;
  End;

  Procedure SetBarInfo (BarPos: Word);
  Begin
    Session.io.PromptInfo[1] := DirList[BarPos]^.Desc;
    Session.io.PromptInfo[2] := strComma(DirList[BarPos]^.Size);
    Session.io.PromptInfo[3] := DateDos2Str(DirList[BarPos]^.Date, Session.User.ThisUser.DateType);
    Session.io.PromptInfo[7] := TimeDos2Str(DirList[BarPos]^.Date, 1);

    If DirList[BarPos]^.IsDir Then Begin
      Session.io.PromptInfo[4] := '';
      Session.io.PromptInfo[5] := '';
      Session.io.PromptInfo[6] := '';
    End Else Begin
      Session.io.PromptInfo[4] := DirList[BarPos]^.Author;
      Session.io.PromptInfo[5] := DirList[BarPos]^.Title;
      Session.io.PromptInfo[6] := DirList[BarPos]^.Group;
    End;
  End;

  Procedure DrawPage;
  Var
    Count : SmallInt;
    Start : Word;
  Begin
    Start := CurTop;

    For Count := WinTop to WinBot Do Begin
      Session.io.AnsiGotoXY(1, Count);

      If Start <= DirCount Then Begin
        SetBarInfo(Start);

        Case DirList[Start]^.IsDir of
          False : Session.io.OutFull(Session.GetPrompt(467));
          True  : Session.io.OutFull(Session.GetPrompt(469));
        End;
      End Else Begin
        Session.io.PromptInfo[1] := '';
        Session.io.PromptInfo[2] := '';
        Session.io.PromptInfo[3] := '';
        Session.io.PromptInfo[4] := '';
        Session.io.PromptInfo[5] := '';
        Session.io.PromptInfo[6] := '';
        Session.io.PromptInfo[7] := '';

        Session.io.OutFull(Session.GetPrompt(467));
      End;

      Inc (Start);
    End;

    CurBot := Start - 1;

    If CurPos > CurBot Then CurPos := CurBot;

    Session.io.PromptInfo[1] := Session.io.DrawPercent(Session.Theme.GalleryBar, CurBot, DirCount, Count);
    Session.io.PromptInfo[2] := strI2S(Count);

    Session.io.OutFull(Session.GetPrompt(472));
  End;

  Procedure DrawBar (Selected: Boolean);
  Begin
    SetBarInfo(CurPos);

    Session.io.AnsiGotoXY (1, CurPos - CurTop + WinTop);

    If Selected Then
      Case DirList[CurPos]^.IsDir of
        False : Session.io.OutFull(Session.GetPrompt(468));
        True  : Session.io.OutFull(Session.GetPrompt(470));
      End
    Else
      Case DirList[CurPos]^.IsDir of
        False : Session.io.OutFull(Session.GetPrompt(467));
        True  : Session.io.OutFull(Session.GetPrompt(469));
      End;
  End;

  Procedure UpdatePath;
  Var
    Temp : String;
  Begin
    Temp := CurPath;

    Delete (Temp, 1, Length(Root) - 1);

    If Length(Temp) > 70 Then
      Session.io.PromptInfo[1] := '..' + Copy(Temp, (Length(Temp) - 68), 255)
    Else
      Session.io.PromptInfo[1] := Temp;

    Session.io.PromptInfo[2] := strComma(DirCount);

    Session.io.OutFull(Session.GetPrompt(471));
  End;

  Procedure FullReDraw;
  Begin
    Session.io.OutFile('ansigal', False, 0);

    WinTop  := Session.io.ScreenInfo[1].Y;
    WinBot  := Session.io.ScreenInfo[2].Y;
    WinSize := WinBot - WinTop + 1;

    UpdatePath;
    DrawPage;
    DrawBar(True);
  End;

  Function FindCharacter (Ch: Char) : Byte;
  Var
    Loop     : Boolean;
    StartPos : Word;
    EndPos   : Word;
    Count    : Word;
  Begin
    Result   := 0;
    Loop     := True;
    StartPos := CurPos + 1;
    EndPos   := DirCount;

    If StartPos > DirCount Then StartPos := 1;

    Count := StartPos;

    While (Count <= EndPos) Do Begin
      If UpCase(DirList[Count]^.Desc[1]) = Ch Then Begin
        Result := 1;

        While Count <> CurPos Do Begin
          If CurPos < Count Then Begin
            If CurPos < DirCount Then Inc (CurPos);
            If CurPos >= CurTop + WinSize Then Begin
              Inc (CurTop);
              Result := 2;
            End;
          End Else
          If CurPos > Count Then Begin
            If CurPos > 1 Then Dec (CurPos);
            If CurPos < CurTop Then Begin
              Dec (CurTop);
              Result := 2;
            End;
          End;
        End;
        Break;
      End;

      If (Count = DirCount) and Loop Then Begin
        Count    := 0;
        StartPos := 1;
        EndPos   := CurPos - 1;
        Loop     := False;
      End;

      Inc (Count);
    End;
  End;

Var
  Ch      : Char;
  Count   : Word;
  Speed   : Byte;
  UseFull : Boolean;
Begin
  If Session.io.Graphics = 0 Then Begin
    Session.io.OutFullLn(Session.GetPrompt(466));
    Exit;
  End;

  Session.io.AllowArrow := True;

  Root    := DirSlash(strWordGet(1, Data, ';'));
  Speed   := strS2I(strWordGet(2, Data, ';'));
  UseFull := Not (strUpper(strWordGet(3, Data, ';')) = 'DISPLAY');
  CurPath := Root;

  If Not DirExists(Root) Then Exit;

  BuildDirectory(CurPath);

  FullReDraw;

  Repeat
    Ch := UpCase(Session.io.GetKey);

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : If CurPos > 1 Then Begin
                CurPos := 1;
                CurTop := 1;

                DrawPage;
                DrawBar(True);
              End;
        #72 : If CurPos > 1 Then Begin
                If CurPos = CurTop Then Begin
                  Dec (CurTop);
                  Dec (CurPos);

                  DrawPage;
                  DrawBar(True);
                End Else Begin
                  DrawBar(False);
                  Dec(CurPos);
                  DrawBar(True);
                End;
              End;
        #73,
        #75 : If CurTop - WinSize >= 1 Then Begin
                Dec (CurTop, WinSize);
                Dec (CurPos, WinSize);

                DrawPage;
                DrawBar(True);
              End Else
              If CurPos > 1 Then Begin
                CurPos := 1;
                CurTop := 1;

                DrawPage;
                DrawBar(True);
              End;
        #79 : If CurPos < DirCount Then Begin
                CurPos := DirCount;
                CurTop := DirCount - WinSize + 1;

                If CurTop < 1 Then CurTop := 1;

                DrawPage;
                DrawBar(True);
              End;
        #80 : If CurPos < DirCount Then Begin
                If CurPos = CurBot Then Begin
                  Inc (CurTop);
                  Inc (CurPos);
                  DrawPage;
                  DrawBar(True);
                End Else Begin
                  DrawBar(False);
                  Inc(CurPos);
                  DrawBar(True);
                End;
              End;
        #77,
        #81 : If CurTop + WinSize <= DirCount - WinSize Then Begin
                Inc (CurPos, WinSize);
                Inc (CurTop, WinSize);

                DrawPage;
                DrawBar(True);
              End Else
              If CurPos < DirCount Then Begin
                CurPos := DirCount;
                CurTop := DirCount - WinSize + 1;

                If CurTop < 1 Then CurTop := 1;

                DrawPage;
                DrawBar(True);
              End;
      End;
    End Else
      Case Ch of
        #08 : If CurPath <> Root Then Begin
                Delete (CurPath, Length(CurPath), 1);

                While CurPath[Length(CurPath)] <> PathChar Do
                  Delete (CurPath, Length(CurPath), 1);

                BuildDirectory(CurPath);

                CurPos := 1;
                CurTop := 1;

                UpdatePath;
                DrawPage;
                DrawBar(True);
              End;
        #13 : If DirList[CurPos]^.IsDir Then Begin
                If DirList[CurPos]^.Desc = '..' Then Begin
                  Delete (CurPath, Length(CurPath), 1);

                  While CurPath[Length(CurPath)] <> PathChar Do
                    Delete (CurPath, Length(CurPath), 1);
                End Else
                  CurPath := CurPath + DirList[CurPos]^.Desc + PathChar;

                BuildDirectory(CurPath);

                CurPos := 1;
                CurTop := 1;

                UpdatePath;
                DrawPage;
                DrawBar(True);
              End Else Begin
                Session.io.AllowMCI := True;
                Session.io.AnsiColor(7);
                Session.io.AnsiClear;

                If UseFull Then
                  AnsiViewer (Session.Theme.ViewerBar, 'ansigalv;ansigalh;' + strI2S(Speed) + ';' + CurPath + DirList[CurPos]^.Desc)
                Else Begin
                  Session.io.OutFile (CurPath + DirList[CurPos]^.Desc, False, Speed);
                  Session.io.PauseScreen;
                End;

                FullReDraw;
              End;
        #27 : Break;
        '?' : Begin
                Session.io.OutFile('ansigalh', False, 0);
                FullRedraw;
              End;
        '!' : If Not DirList[CurPos]^.IsDir Then Begin
                Session.io.AnsiColor(7);
                Session.io.AnsiGotoXY(1, Session.User.ThisUser.ScreenSize);

                If Session.io.GetYN(Session.GetPrompt(474), False) Then
                  Session.FileBase.SendFile(CurPath + DirList[CurPos]^.Desc);

                FullReDraw;
              End;
      Else
        DrawBar(False);

        Case FindCharacter(Ch) of
          0,
          1 : DrawBar(True);
          2 : Begin
                DrawPage;
                DrawBar(True);
              End;
        End;
      End;
  Until Session.ShutDown;

  Session.io.AnsiColor(7);
  Session.io.AnsiGotoXY(1, 24);

  For Count := DirCount DownTo 1 Do
    Dispose (DirList[Count]);
End;

{$IFNDEF UNIX}
Procedure PageForSysopChat (Forced: Boolean);
Var
  Temp  : String;
  Count : Integer;
Begin
  If Forced or ((TimerMinutes DIV 60 >= bbsCfg.ChatStart) and (TimerMinutes DIV 60 <= bbsCfg.ChatEnd)) Then Begin
    Session.io.OutFull (Session.GetPrompt(23));

    Temp := Session.io.GetInput(50, 50, 11, '');

    If Temp = '' Then Exit;

    Session.SystemLog('Chat Page: ' + Temp);

    UpdateStatusLine (0, ' ' + strPadR(Session.User.ThisUser.Handle, 17, ' ') + ' ' + strPadR(Temp, 40, ' ') + ' ALT+(S)plit (C)Line');

    Session.io.OutFull(Session.GetPrompt(24));

    For Count := 1 to 10 Do Begin
      Session.io.OutFull(Session.GetPrompt(25));
      Session.io.BufFlush;

      MessageBeep(0);

      If Keyboard.KeyPressed Then
        If Keyboard.ReadKey = #0 Then Begin
          Case Keyboard.ReadKey of
            #31 : OpenChat(True);
            #46 : OpenChat(False);
          End;

          Exit;
        End;

      WaitMS(1000);
    End;
  End;

  UpdateStatusLine (Session.StatusPtr, '');

  Session.io.OutFull (Session.GetPrompt(28));

  If bbsCfg.ChatFeedback Then
    If Session.io.GetYN(Session.GetPrompt(178), False) Then
      Session.Msgs.PostMessage (True, '/TO:' + strReplace(bbsCfg.SysopName, ' ', '_') + ' /SUBJ:Chat_Feedback');
End;
{$ENDIF}

Procedure AnsiViewer (Bar: RecPercent; Data: String);
Var
  Buf      : Array[1..4096] of Char;
  BufLen   : LongInt;
  TopLine  : LongInt;
  WinSize  : LongInt;
  Ansi     : TMsgBaseAnsi;
  AFile    : File;
  Ch       : Char;
  FN       : String;
  Template : String;
  HelpFile : String;
  Speed    : Byte;
  Str      : String;
  Sauce    : RecSauceInfo;

  Procedure Update;
  Var
    Per : SmallInt;
  Begin
    If Session.io.ScreenInfo[3].X <> 0 Then Begin
      Session.io.AnsiGotoXY (Session.io.ScreenInfo[3].X, Session.io.ScreenInfo[4].Y);
      Session.io.OutRaw     (Session.io.DrawPercent(Bar, TopLine + WinSize - 1, Ansi.Lines, Per));
      Session.io.AnsiGotoXY (Session.io.ScreenInfo[4].X, Session.io.ScreenInfo[4].Y);
      Session.io.AnsiColor  (Session.io.Screeninfo[4].A);
      Session.io.OutRaw     (strPadL(strI2S(Per), 3, ' '));
    End;

    Ansi.DrawPage (Session.io.ScreenInfo[1].Y, Session.io.ScreenInfo[2].Y, TopLine);
  End;

  Procedure ReDraw;
  Begin
    Session.io.AllowArrow      := True;
    Session.io.ScreenInfo[3].X := 0;

    Session.io.OutFile(Template, False, 0);

    WinSize := Session.io.ScreenInfo[2].Y - Session.io.ScreenInfo[1].Y + 1;

    If strUpper(strWordGet(4, Data, ';')) = 'END' Then Begin
      TopLine := Ansi.Lines - WinSize + 1;

      If TopLine < 1 Then TopLine := 1;
    End Else
      TopLine := 1;

    Update;
  End;

Begin
  Template := strWordGet(1, Data, ';');
  HelpFile := strWordGet(2, Data, ';');
  Speed    := strS2I(strWordGet(3, Data, ';'));
  FN       := strWordGet(4, Data, ';');

  If Pos(PathChar, FN) = 0 Then
    FN := Session.Theme.TextPath + FN;

  If Pos('.', FN) = 0 Then
    FN := FN + '.ans';

  If Not FileExist(FN) Then Exit;

  If ReadSauceInfo(FN, Sauce) Then Begin
    Session.io.PromptInfo[2] := Sauce.Title;
    Session.io.PromptInfo[3] := Sauce.Author;
    Session.io.PromptInfo[4] := Sauce.Group;
  End Else Begin
    Str := Session.GetPrompt(473);

    Session.io.PromptInfo[2] := strWordGet(1, Str, ';');
    Session.io.PromptInfo[3] := strWordGet(2, Str, ';');
    Session.io.PromptInfo[4] := strWordGet(3, Str, ';');
  End;

  Session.io.PromptInfo[1] := JustFile(FN);

  Ansi := TMsgBaseAnsi.Create(Session, False);

  Assign  (AFile, FN);
  ioReset (AFile, 1, fmReadWrite + fmDenyNone);

  While Not Eof(AFile) Do Begin
    ioBlockRead (AFile, Buf, SizeOf(Buf), BufLen);
    If Ansi.ProcessBuf (Buf, BufLen) Then Break;
  End;

  Close (AFile);

  ReDraw;

  While Not Session.ShutDown Do Begin
    Ch := UpCase(Session.io.GetKey);

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : If TopLine > 1 Then Begin
                TopLine := 1;

                Update;
              End;
        #72 : If TopLine > 1 Then Begin
                Dec (TopLine);

                Update;
              End;
        #73,
        #75 : If TopLine > 1 Then Begin
                Dec (TopLine, WinSize);

                If TopLine < 1 Then TopLine := 1;

                Update;
              End;
        #79 : If TopLine + WinSize <= Ansi.Lines Then Begin
                TopLine := Ansi.Lines - WinSize + 1;

                Update;
              End;
        #80 : If TopLine + WinSize <= Ansi.Lines Then Begin
                Inc (TopLine);

                Update;
              End;
        #77,
        #81 : If TopLine < Ansi.Lines - WinSize Then Begin
                Inc (TopLine, WinSize);

                If TopLine + WinSize > Ansi.Lines Then TopLine := Ansi.Lines - WinSize + 1;

                Update;
              End;
      End;
    End Else
      Case Ch of
        '?' : Begin
                Session.io.OutFile(HelpFile, True, 0);

                If Not Session.io.NoFile Then
                  ReDraw;
              End;
        #32 : Begin
                Session.io.AnsiColor(7);
                Session.io.AnsiClear;
                Session.io.OutFile(FN, False, Speed);
                Session.io.PauseScreen;

                ReDraw;
              End;
        'P' : If TopLine < Ansi.Lines - WinSize Then Begin
                Inc (TopLine, WinSize);

                If TopLine + WinSize > Ansi.Lines Then TopLine := Ansi.Lines - WinSize + 1;

                Update;
              End;
        'N',
        #13 : If TopLine < Ansi.Lines - WinSize Then Begin
                Inc (TopLine, WinSize);

                If TopLine + WinSize > Ansi.Lines Then TopLine := Ansi.Lines - WinSize + 1;

                Update;
              End;

        #27 : Break;
      End;
  End;

  Ansi.Free;

  Session.io.AnsiGotoXY (1, Session.User.ThisUser.ScreenSize);
End;

End.

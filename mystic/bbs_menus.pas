Unit bbs_Menus;

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  bbs_Common,
  bbs_Doors;

Type
  TMenuSystem = Class
    LBMenuPos : Byte;
    CmdNum    : Byte;
    Menu      : MenuRec;
    MenuList  : Array[1..mysMaxMenuCmds] of MenuCmdRec;
    MenuOld   : String[mysMaxMenuNameLen];
    MenuName  : String[mysMaxMenuNameLen];
    MenuStack : Array[1..8] of String[mysMaxMenuNameLen];
    StackNum  : Byte;

    Constructor Create (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Function    StripSecurity     (Str : String) : String;
    Function    ReplaceSecurity   (Str : String) : String;
    Procedure   ToggleAccessFlags (Data: String; Var Flags: AccessFlagType);
    Function    LoadMenu          (CheckSec: Boolean; RunCmd: Boolean; Global: Boolean) : Byte;
    Procedure   ExecuteMenu       (FallBack, Global, View: Boolean);
    Function    ExecuteCommand    (Cmd: String; Data: String) : Boolean; {True if menu is to be reloaded}
  End;

Implementation

Uses
  bbs_Core,
  bbs_MsgBase,
  bbs_FileBase,
  bbs_General,
  bbs_User,
  bbs_NodeChat,
  bbs_NodeInfo,
  bbs_ansi_Help,
  MPL_Execute,
  bbs_cfg_MenuEdit,
  bbs_cfg_FileBase,
  bbs_cfg_UserEdit,
  bbs_cfg_MsgBase,
  bbs_cfg_SecLevel,
  bbs_cfg_Groups,
  bbs_cfg_Events,
  bbs_cfg_Vote,
  bbs_Cfg_Main;

Constructor TMenuSystem.Create (Var Owner: Pointer);
Begin
  Inherited Create;

  StackNum := 0;
End;

Destructor TMenuSystem.Destroy;
Begin
  Inherited Destroy;
End;

Function TMenuSystem.StripSecurity (Str : String) : String;
Begin
  Delete (Str, Pos('@S', Str), 2);

  Result := Str;
End;

Function TMenuSystem.ReplaceSecurity (Str : String) : String;
Var
  A : Byte;
Begin
  A := Pos('@', Str);

  If A > 0 Then Begin
    Delete (Str, A, 2);
    Insert (strI2S(Session.User.ThisUser.Security), Str, A);
  End;

  Result := Str;
End;

Procedure TMenuSystem.ToggleAccessFlags (Data: String; Var Flags: AccessFlagType);
Var
  A : Byte;
Begin
  A := 1;

  While A <= Length(Data) Do Begin
    If (Data[A] in ['+','-','!']) and (Data[A+1] in ['A'..'Z']) Then Begin
      Case Data[A] of
        '+' : Flags := Flags + [Ord(Data[A+1]) - 64];
        '-' : Flags := Flags - [Ord(Data[A+1]) - 64];
        '!' : If Ord(Data[2]) - 64 in Flags Then
                Flags := Flags - [Ord(Data[A+1]) - 64]
              Else
                Flags := Flags + [Ord(Data[A+1]) - 64];

      End;
      Inc (A);
    End;
    Inc(A);
  End;

  {$IFNDEF UNIX}
     UpdateStatusLine(StatusPTR, '');
  {$ENDIF}
End;

Function TMenuSystem.ExecuteCommand (Cmd: String; Data: String) : Boolean;
Var
  A : Integer;
  Help : TAnsiMenuHelp;
Begin
  Result := False;

  {$IFDEF LOGGING} Session.SystemLog('Exec MenuCmd: ' + Cmd + ' ' + Data); {$ENDIF}

  If Length(Cmd) <> 2 Then Exit;

  Case Cmd[1] of
    '-' : Case Cmd[2] of
            'D' : ToggleAccessFlags(Data, Session.User.ThisUser.AF2);
            'F' : ToggleAccessFlags(Data, Session.User.ThisUser.AF1);
            'N' : Session.User.AcsOkFlag := Session.io.GetYN(Data, False);
            'P' : Session.User.AcsOkFlag := Session.io.GetPW(Copy(Data, 1, Pos(';', Data) - 1), Session.GetPrompt(417),
                                                strUpper(Copy(Data, Pos(';', Data) + 1, Length(Data))));
            'S' : Session.SystemLog(Data);
            'Y' : Session.User.AcsOkFlag := Session.io.GetYN(Data, True);
          End;
    'A' : Case Cmd[2] of
            'E' : AutoSig_Edit;
            'T' : Session.User.ThisUser.SigUse := Session.io.GetYN(Session.GetPrompt(335), False);
            'V' : AutoSig_View;
          End;
    'D' : Case Cmd[2] of
            '-' : ExecuteDoor (0, Data);
            'C' : ExecuteDoor (3, Data);
            'D' : ExecuteDoor (1, Data);
            'G' : ExecuteDoor (2, Data);
            '3' : ExecuteDoor (4, Data);
          End;
    'F' : Case Cmd[2] of
            'A' : Session.FileBase.ChangeFileArea(Data);
            'D' : Begin
                    Session.io.OutFile ('download', True, 0);

                    If (Session.FileBase.BatchNum > 0) and (Session.io.GetYN(Session.GetPrompt(85), True)) Then
                      Session.FileBase.DownloadBatch
                    Else
                      Session.FileBase.DownloadFile;
                  End;
            'F' : Session.FileBase.DownloadFileList (strUpper(Data));
            'G' : Session.FileBase.FileGroupChange (Data, True, True);
            'L' : Session.FileBase.ListFiles (1, strUpper(Data));
            'N' : Session.FileBase.NewFileScan(UpCase(Data[1]));
            'P' : Session.FileBase.SetFileScanDate;
            'S' : Session.FileBase.FileSearch;
            'U' : Session.FileBase.UploadFile;
            'V' : Session.FileBase.ViewFile;
            'Z' : Session.FileBase.ToggleFileNewScan;
            '1' : Session.FileBase.MassUpload;
            '2' : Session.FileBase.DirectoryEditor(False, '');
            '3' : Session.FileBase.SendFile (Data);
          End;
    'B' : Case Cmd[2] of
            'A' : Add_BBS_List  (Data);
            'L' : View_BBS_List (True, Data);
            'S' : View_BBS_List (False, Data);
          End;
    'G' : Case Cmd[2] of
            '1' : ShowBBSHistory(strS2I(Data));
            'A' : View_Directory(Data, 0);
            'D' : Session.io.OutFile (Data, True, 0);
            'E' : Session.User.Edit_User_Settings(strS2I(Data));
            'H',
            'I' : Begin
                    If Cmd[2] = 'H' Then Begin
                      If Session.FileBase.BatchNum > 0 Then Begin
                        Session.io.PromptInfo[1] := strI2S(Session.FileBase.BatchNum);
                        If Session.io.GetYN(Session.GetPrompt(121), False) Then
                          Session.FileBase.DownloadBatch;
                      End;
                      Session.io.OutFile ('logoff', True, 0);
                    End;
                    Session.SystemLog ('User logged off');
                    Halt(0);
                  End;
            'L' : ShowLastCallers;
            'O' : Begin
                    MenuOld  := MenuName;
                    MenuName := Data;
                    Result   := True;
                  End;
            'N' : ShowOneLiners (Data);
            'P' : {$IFNDEF UNIX} PageForSysopChat (Pos('/F', strUpper(Data)) > 0) {$ENDIF};
            'R' : Begin
                    If StackNum > 0 Then Begin
                      MenuOld  := MenuName;
                      MenuName := MenuStack[StackNum];
                      Result   := True;

                      Dec (StackNum);
                    End;
                  End;
            'S' : Begin
                    MenuOld := MenuName;

                    If StackNum = 8 Then Begin
                      For A := 1 to 7 Do
                        MenuStack[A + 1] := MenuStack[A];

                      Dec (StackNum);
                    End;

                    Inc (StackNum);

                    MenuStack[StackNum] := MenuName;
                    MenuName            := Data;
                    Result              := True;
                  End;
            'T' : Session.io.OutFull (Data);
            'U' : ShowUserList (strUpper(Data));
            'X' : Result := ExecuteMPL(NIL, Data) = 2;
            '?' : Begin
                    // online ANSI help system (BBSHTML) prototype
                    Help := TAnsiMenuHelp.Create;
                    Help.OpenHelp (Session.Lang.TextPath + Data + ';ansihelp;INDEX');
                    Help.Free;
                  End;
          End;
    'M' : Case Cmd[2] of
            'A' : Session.Msgs.ChangeArea(Data);
            'C' : Session.Msgs.CheckEMail;
            'D' : Session.Msgs.SetMessagePointers;
            'G' : Session.Msgs.MessageGroupChange (Data, True, True);
            'M' : Session.Msgs.SendMassEmail;
            'N' : Session.Msgs.MessageNewScan (strUpper(Data));
            'P' : Session.Msgs.PostMessage (False, Data);
//            'Q' : Session.Msgs.Message_QuickScan(UpCase(Data[1]));
            'R' : Begin
                    If Data = '' Then Data := ' ';

                    Session.Msgs.ReadMessages(UpCase(Data[1]), '');
                  End;
            'S' : Session.Msgs.GlobalMessageSearch(UpCase(Data[1]));
            'V' : Session.Msgs.ViewSentEmail;
            'W' : Session.Msgs.PostMessage (True, Data);
            'X' : Session.Msgs.PostTextFile(Data, False);
            'Z' : Session.Msgs.ToggleNewScan(False);
          End;
    'N' : Case Cmd[2] of
            'A' : Set_Node_Action (Data);
            'C' : Node_Chat;
            'S' : Send_Node_Message (3, Data, 0);
            'W' : Show_Whos_Online;
          End;
    'O' : Case Cmd[2] of
            'S' : Session.Msgs.ToggleNewScan(True);
            'D' : Session.Msgs.DownloadQWK(Data);
            'U' : Session.Msgs.UploadREP;
          End;
    'Q' : Case Cmd[2] of
            'A' : Session.FileBase.BatchAdd;
            'C' : Session.FileBase.BatchClear;
            'D' : Session.FileBase.BatchDelete;
            'L' : Session.FileBase.BatchList;
          End;
    'T' : Case Cmd[2] of
            'D' : Add_TimeBank;
            'W' : Get_TimeBank;
          End;
    'V' : Case Cmd[2] of
            'A' : Add_Booth;
            'N' : Voting_Booth_New;
            'R' : Voting_Result (strS2I(Data));
            'V' : Voting_Booth (False, strS2I(Data));
          End;
    'X' : Case Cmd[2] of
            'A' : Begin
                    Session.io.OutFile('newuser', True, 0);
                    If Session.io.GetYN(Session.GetPrompt(269), True) Then Begin
                      Session.User.CreateNewUser('');
                      Session.User.User_Logon2;

                      MenuName := Config.MatrixMenu;
                      Result   := True;
                    End;
                  End;
            'C' : If Session.User.GetMatrixUser Then Begin
                    If Session.User.Access(Config.MatrixAcs) Then Begin
                      Session.io.PromptInfo[1] := Config.MatrixPW;
                      Session.io.OutFull (Session.GetPrompt(270));
                    End Else
                      Session.io.OutFull (Session.GetPrompt(271));
                  End;
            'L' : If Session.io.GetPW (Session.GetPrompt(272), Session.GetPrompt(423), Config.MatrixPW) Then Begin
                    Session.User.MatrixOK := True;
                    Result                := True;
                  End;
            'P' : {$IFNDEF UNIX} If Session.User.GetMatrixUser Then
                    PageForSysopChat (Pos('/F', strUpper(Data)) > 0) {$ENDIF};
          End;
    '*' : Begin
            If Not Session.io.GetPW ('|CR|09Sysop Password: ', Session.GetPrompt(417), Config.SysopPW) Then Exit; {++lang}

            Case Cmd[2] of
              '#' : Begin
                      Menu_Editor;
                      Result := True;
                    End;
              'A' : Configuration_ExecuteEditor('A');
              'E' : Event_Editor;
              'F' : Configuration_ExecuteEditor('F');
              'G' : Configuration_ExecuteEditor('G');
              'L' : Configuration_ExecuteEditor('L');
              'M' : Configuration_ExecuteEditor('B');
              'P' : Configuration_ExecuteEditor('P');
              'S' : Configuration_MainMenu;
              'U' : User_Editor(False, False);
              'V' : Vote_Editor;
            End;
          End;
  End;
End;

Function TMenuSystem.LoadMenu (CheckSec: Boolean; RunCmd: Boolean; Global: Boolean) : Byte;
{ 0 = Menu not found: Load fallback menu
  1 = Menu loaded.
  2 = Re-load menu: ie GO in FIRSTCMD }
Var
  MenuFile : Text;
  Buffer   : Array[1..2048] of Char;
  Temp     : String;
Begin
  Result := 0;

  {$IFDEF LOGGING} Session.SystemLog('Load menu: ' + MenuName); {$ENDIF}

  Assign (MenuFile, Session.Lang.MenuPath + MenuName + '.mnu');
  {$I-} Reset (MenuFile); {$I+}

  If IoResult <> 0 Then Begin
    If Not Global Then Begin
      Session.io.OutFullLn ('|CR|14Menu not found, loading fallback.');
      Session.SystemLog    ('Menu: ' + MenuName + ' not found');
    End;

    Exit;
  End;

  SetTextBuf (MenuFile, Buffer, SizeOf(Buffer));

  If CheckSec Then Begin
    ReadLn (MenuFile, Temp);  {Header}
    ReadLn (MenuFile, Temp);  {Prompt}
    ReadLn (MenuFile, Temp);  {Display columns}
    ReadLn (MenuFile, Temp);  {ACS}

    If Not Session.User.Access(Temp) Then Begin
      Close (MenuFile);

      MenuName := MenuOld;
      Result   := 2;

      If Not Global Then
        Session.io.OutFullLn (Session.GetPrompt(149));

      Exit;
    End;

    ReadLn (MenuFile, Temp);

    If Temp <> '' Then
      If Not Session.io.GetPW(Session.GetPrompt(150), Session.GetPrompt(417), Temp) Then Begin
        Close (MenuFile);

        Result   := 2;
        MenuName := MenuOld;

        Exit;
      End;
  End;

  Reset  (MenuFile);

  ReadLn (MenuFile, Menu.Header);
  ReadLn (MenuFile, Menu.Prompt);
  ReadLn (MenuFile, Menu.DispCols);
  ReadLn (MenuFile, Menu.ACS);
  ReadLn (MenuFile, Menu.Password);
  ReadLn (MenuFile, Menu.TextFile);
  ReadLn (MenuFile, Menu.FallBack);
  ReadLn (MenuFile, Menu.MenuType);
  ReadLn (MenuFile, Menu.InputType);
  ReadLn (MenuFile, Menu.DoneX);
  ReadLn (MenuFile, Menu.DoneY);
  ReadLn (MenuFile, Menu.Global);

  If Not Global Then CmdNum := 0;

  While (CmdNum < mysMaxMenuCmds) And (Not Eof(MenuFile)) Do Begin
    Inc (CmdNum);

    ReadLn (MenuFile, MenuList[CmdNum].Text);
    ReadLn (MenuFile, MenuList[CmdNum].HotKey);
    ReadLn (MenuFile, MenuList[CmdNum].LongKey);
    ReadLn (MenuFile, MenuList[CmdNum].ACS);
    ReadLn (MenuFile, MenuList[CmdNum].Command);
    ReadLn (MenuFile, MenuList[CmdNum].Data);
    ReadLn (MenuFile, MenuList[CmdNum].X);
    ReadLn (MenuFile, MenuList[CmdNum].Y);
    ReadLn (MenuFile, MenuList[CmdNum].cUP);
    ReadLn (MenuFile, MenuList[CmdNum].cDOWN);
    ReadLn (MenuFile, MenuList[CmdNum].cLEFT);
    ReadLn (MenuFile, MenuList[CmdNum].cRIGHT);
    ReadLn (MenuFile, MenuList[CmdNum].LText);
    ReadLn (MenuFile, MenuList[CmdNum].LHText);

    If (RunCmd) and (MenuList[CmdNum].HotKey = 'FIRSTCMD') Then Begin
      If Session.User.Access(MenuList[CmdNum].ACS) Then
        If ExecuteCommand (MenuList[CmdNum].Command, MenuList[CmdNum].Data) Then Begin
          Result := 2;
          Close (MenuFile);
          Exit;
        End;
      Dec (CmdNum);
    End;
  End;
  Close (MenuFile);

  LBMenuPos := 0;
  Result    := 1;
End;

Procedure TMenuSystem.ExecuteMenu (FallBack, Global, View: Boolean);
{If fallback is false, Run_Menu will not try to load any fallback menus.
if the MenuName variable doesn't exist}
Var
  Keys    : String[mysMaxMenuCmds];
  ExtKeys : String[mysMaxMenuCmds];
  HotKeys : Boolean;
  Done    : Boolean;

  Function ExecuteAfterCommands : Boolean;
  Var
    A : Byte;
  Begin
    ExecuteAfterCommands := False;

    For A := 1 to CmdNum Do
      If (MenuList[A].HotKey = 'AFTER') And Session.User.Access(MenuList[A].ACS) Then
        If ExecuteCommand(MenuList[A].Command, MenuList[A].Data) Then Begin
          ExecuteAfterCommands := True;
          Done                 := True;
          Exit;
        End;
  End;

  Function ValidLightBar (Pos : Byte) : Boolean;
  Begin
    ValidLightBar := False;

    If Pos = 0 Then Exit;

    ValidLightBar := (MenuList[Pos].HotKey <> 'EVERY') and
                     (MenuList[Pos].HotKey <> 'AFTER') and
                     (MenuList[Pos].LText <> '') and
                     (MenuList[Pos].LHText <> '');
{ we need to add LINEFEED?! }
  End;

  Procedure Do_LightBar_Menu;
  Var
    A       : Byte;
    Ch      : Char;
    TempPos : Byte;
    TempStr : String;
  Begin
    If View Then Begin
      Done      := False;
      LBMenuPos := 0;
    End;

    Session.io.OutFile (ReplaceSecurity(Menu.TextFile), True, 0);

    If Session.io.NoFile and (Pos('@S', Menu.TextFile) > 0) Then
      Session.io.OutFile (StripSecurity(Menu.TextFile), True, 0);

    For A := 1 to CmdNum Do
      If ValidLightBar(A) Then Begin
        If LBMenuPos = 0 Then LBMenuPos := A;
        Session.io.AnsiGotoXY (MenuList[A].X, MenuList[A].Y);
        Session.io.OutFull (MenuList[A].LText);
      End;

    Session.io.AllowArrow := True;

    If ExecuteAfterCommands Then Exit;

    Session.io.PurgeInputBuffer;

    Repeat
      Session.io.AnsiGotoXY (MenuList[LBMenuPos].X, MenuList[LBMenuPos].Y);
      Session.io.OutFull (MenuList[LBMenuPos].LHText);

      Ch := Session.io.GetKey;

      Case Ch of
        #13 : Begin
                TempStr := MenuList[LBMenuPos].HotKey;

                For A := 1 To CmdNum Do
                  If MenuList[A].HotKey = TempStr Then
                    If Session.User.Access(MenuList[A].ACS) Then Begin
                      Session.io.AnsiGotoXY (Menu.DoneX, Menu.DoneY);
                      If View Then Exit;
                      If ExecuteCommand(MenuList[A].Command, MenuList[A].Data) Then
                        Done := True;
                    End;
                Exit;
              End;
        #72,
        #75 : Begin {Up, Left}
                Session.io.AnsiGotoXY (MenuList[LBMenuPos].X, MenuList[LBMenuPos].Y);
                Session.io.OutFull (MenuList[LBMenuPos].LText);

                If Menu.MenuType = 1 Then Begin
                  TempPos := LBMenuPos;
                  Repeat
                    Dec (TempPos);
                    If ValidLightBar(TempPos) Then Begin
                      LBMenuPos := TempPos;
                      Break;
                    End;
                  Until TempPos <= 1;
                End Else
                  Case Ch of
                    #72 : If ValidLightBar(MenuList[LBMenuPos].cUP) Then
                            LBMenuPos := MenuList[LBMenuPos].cUP;
                    #75 : If ValidLightBar(MenuList[LBMenuPos].cLEFT) Then
                            LBMenuPos := MenuList[LBMenuPos].cLEFT;
                  End;
              End;
        #80,
        #77 : Begin {Down, Right}
                Session.io.AnsiGotoXY (MenuList[LBMenuPos].X, MenuList[LBMenuPos].Y);
                Session.io.OutFull (MenuList[LBMenuPos].LText);

                If Menu.MenuType = 1 Then Begin
                  If LBMenuPos < CmdNum Then Begin
                    TempPos := LBMenuPos;
                    Repeat
                      Inc (TempPos);
                      If ValidLightBar(TempPos) Then Begin
                        LBMenuPos := TempPos;
                        Break;
                      End;
                    Until TempPos >= CmdNum;
                  End;
                End Else Begin
                  Case Ch of
                    #77 : If ValidLightBar(MenuList[LBMenuPos].cRIGHT) Then
                            LBMenuPos := MenuList[LBMenuPos].cRIGHT;
                    #80 : If ValidLightBar(MenuList[LBMenuPos].cDOWN) Then
                            LBMenuPos := MenuList[LBMenuPos].cDOWN;
                  End;
                End;
              End;
      Else
        If Pos(UpCase(Ch), Keys) > 0 Then begin
          For A := 1 to CmdNum Do Begin
            If ((Ch = #27) and (MenuList[A].HotKey = 'ESCAPE')) or
               ((Ch = #9)  and (MenuList[A].HotKey = 'TAB')) or
               (UpCase(Ch) = MenuList[A].HotKey) Then
              If Session.User.Access(MenuList[A].ACS) Then Begin
                Session.io.AnsiGotoXY (Menu.DoneX, Menu.DoneY);
                If View Then Exit;
                If ExecuteCommand(MenuList[A].Command, MenuList[A].Data) Then
                  Done := True;
              End;
          End;
          Exit;
        End;
      End;
    Until Done;
  End;

  Procedure Do_Internal_Menu;
  Var
    Format : Byte;
    A      : Byte;
    Listed : Byte;
    Temp   : String[8];
    Ch     : Char;
    Found  : Boolean;
  Begin
    Session.io.OutFile (ReplaceSecurity(Menu.TextFile), True, 0);

    If Session.io.NoFile and (Pos('@S', Menu.TextFile) > 0) Then
      Session.io.OutFile (StripSecurity(Menu.TextFile), True, 0);

    If Session.io.NoFile Then Begin
      Case Menu.DispCols of
        1 : Format := 79;
        2 : Format := 39;
        3 : Format := 26;
      End;

      Session.io.OutFullLn (Menu.Header);

      Listed := 0;

      For A := 1 to CmdNum Do Begin
        If MenuList[A].Text <> '' Then
          If (MenuList[A].HotKey <> 'EVERY') and (MenuList[A].HotKey <> 'AFTER') Then
            If Session.User.Access(MenuList[A].ACS) Then Begin
              If MenuList[A].HotKey = 'LINEFEED' Then Begin
                If Listed MOD Menu.DispCols <> 0 Then Session.io.OutRawLn('');
                Session.io.OutFull(MenuList[A].Text);
                While Listed Mod Menu.DispCols <> 0 Do Inc(Listed);
              End Else Begin
                Inc (Listed);
                If Format <> 79 Then
                  Session.io.OutFull (strPadR(MenuList[A].Text, Format + (Length(MenuList[A].Text) - strMCILen(MenuList[A].Text)), ' '))
                Else
                  Session.io.OutFull (MenuList[A].Text);
                While Screen.CursorX < Format Do Session.io.BufAddChar(' ');
                If Listed Mod Menu.DispCols = 0 Then Session.io.OutRawLn ('');
              End;
            End;
      End;

      If Listed Mod Menu.DispCols <> 0 Then Session.io.OutRawLn ('');
    End;

    If ExecuteAfterCommands Then Exit;

    If Menu.Prompt <> '' Then Session.io.OutFull (Menu.Prompt);

    Session.io.PurgeInputBuffer;

    Listed     := 0;
    Session.io.AllowArrow := True;

    If HotKeys Then Begin
      Repeat
        Temp := UpCase(Session.io.GetKey);

        If Session.io.IsArrow Then Begin
          If Pos(Temp, ExtKeys) > 0 Then Break;
        End Else
          If Pos(Temp, Keys) > 0 Then
            If Temp = '/' Then Begin
              Session.io.BufAddChar (Temp[1]);
              Repeat
                Ch := UpCase(Session.io.GetKey);
                Case Ch of
                  #08 : If Length(Temp) > 0 Then Begin
                          Dec (Temp[0]);
                          Session.io.OutBS(1, True);
                        End;
                  #13 : Begin
                          Session.io.OutRawLn(Ch);
                          Exit;
                        End;
                  #32..
                  #126: Begin
                          Found := False;
                          For A := 1 to CmdNum Do
                            If Pos (Temp + Ch, MenuList[A].HotKey) > 0 Then Begin
                              If Not Found Then Begin
                                Temp  := Temp + Ch;
                                Found := True;
                                Session.io.BufAddChar (Ch);
                              End;
                              If Temp = MenuList[A].HotKey Then
                                If Session.User.Access(MenuList[A].ACS) Then Begin
                                  If View Then Exit;
                                  If Listed = 0 Then Session.io.OutRawLn('');
                                  Listed := A;
                                  ExecuteCommand (MenuList[A].Command, MenuList[A].Data);
                                  Done := True;
                                End;
                            End;
                          If Done Then Exit;
                        End;
                End;
              Until Temp = '';
            End Else
              Break;
      Until False;

      If Ord(Temp[1]) > 32 Then Session.io.OutRawLn(Temp) Else Session.io.OutRawLn('');

{ needs to ignore LINEFEED? }

      For A := 1 to CmdNum Do
        If ((Temp = #27) and (MenuList[A].HotKey = 'ESCAPE')) or
           ((Temp = #13) and (MenuList[A].HotKey = 'ENTER')) or
           ((Temp = #9)  and (MenuList[A].HotKey = 'TAB')) or
           (Session.io.IsArrow and (Temp = #72) and (MenuList[A].HotKey = 'UP')) or
           (Session.io.IsArrow and (Temp = #75) and (MenuList[A].HotKey = 'LEFT')) or
           (Session.io.IsArrow and (Temp = #77) and (MenuList[A].HotKey = 'RIGHT')) or
           (Session.io.IsArrow and (Temp = #80) and (MenuList[A].HotKey = 'DOWN')) or
           (Not Session.io.IsArrow and (Temp = MenuList[A].HotKey)) Then

              If Session.User.Access(MenuList[A].ACS) Then
                If ExecuteCommand (MenuList[A].Command, MenuList[A].Data) Then Begin
                  Done := True;
                  Exit;
                End;
    End Else Begin { non hotkey input }
      Temp := Session.io.GetInput (8, 8, 2, '');

      If Temp = '' Then Temp := 'ENTER';
      { temporary support for ENTER in non hotkey mode }

      For A := 1 to CmdNum Do
        If Temp = MenuList[A].LongKey Then
          If Session.User.Access(MenuList[A].ACS) Then Begin
            If View Then Exit;
            If ExecuteCommand (MenuList[A].Command, MenuList[A].Data) Then Begin
              Done := True;
              Exit;
            End;
          End;
    End;
  End;

Var
  A  : Byte;
  MR : MenuRec;
Begin
  If View Then Begin
    Keys := #13;
    If (Menu.MenuType > 0) and (Session.io.Graphics = 1) Then Begin
      Do_LightBar_Menu;
      Session.io.AnsiGotoXY (Menu.DoneX, Menu.DoneY);
    End Else
      Do_Internal_Menu;
    Exit;
  End;

  Repeat
    Case LoadMenu(True, True, False) of
      0 : Begin
          { 1. Try Menu.FallBack   }
          { 2. Try Config.dFallMNU }
          { 3. Give error and halt }
            If Not FallBack Then Exit;

            If (MenuName = Config.MatrixMenu) or (MenuName = Config.DefFallMenu) Then Begin
              Session.io.OutFullLn ('|CRError Loading ' + MenuName + '.mnu');
              Session.SystemLog ('Error Loading Menu: ' + MenuName);
              Halt(1);
            End;

            If (Menu.FallBack <> '') and (MenuName <> Menu.FallBack) Then
              MenuName := Menu.Fallback
            Else
              MenuName := Config.DefFallMenu;
            Exit;
          End;
      1 : Break;
      2 : Exit;
    End;
  Until False;

  If Global and (Menu.Global = 1) Then Begin
    Keys     := MenuName;
    MR       := Menu;
    MenuName := 'global';

    LoadMenu(True, True, True);

    MenuName := Keys;
    Menu     := MR;
  End;

  If Menu.InputType = 0 Then
    HotKeys := Session.User.ThisUser.HotKeys
  Else
    HotKeys := Not Boolean(Menu.InputType - 1);

  Repeat
    Done := False;

    Set_Node_Action (Session.GetPrompt(346));

    CheckNodeMessages;

    Keys    := #13;
    ExtKeys := '';

    For A := 1 to CmdNum Do
      If Session.User.Access(MenuList[A].ACS) Then
        If MenuList[A].HotKey = 'EVERY' Then Begin
          If ExecuteCommand (MenuList[A].Command, MenuList[A].Data) Then Exit;
        End Else
        If MenuList[A].HotKey = 'TAB' Then
          Keys := Keys + #9
        Else
        If MenuList[A].HotKey = 'ESCAPE' Then
          Keys := Keys + #27
        Else
        If MenuList[A].HotKey = 'UP' Then
          ExtKeys := ExtKeys + #72
        Else
        If MenuList[A].HotKey = 'LEFT' Then
          ExtKeys := ExtKeys + #75
        Else
        If MenuList[A].HotKey = 'RIGHT' Then
          ExtKeys := ExtKeys + #77
        Else
        If MenuList[A].HotKey = 'DOWN' Then
          ExtKeys := ExtKeys + #80
        Else
          Keys := Keys + MenuList[A].HotKey[1];

    If (Menu.MenuType > 0) and (Session.io.Graphics = 1) Then
      Do_LightBar_Menu
    Else
      Do_Internal_Menu;
  Until Done;
End;

End.

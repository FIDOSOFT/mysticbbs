Unit BBS_Menus;

{$I M_OPS.PAS}

Interface

Uses
  BBS_Common,
  BBS_MenuData,
  MPL_Execute;

Type
  TMenuEngine = Class
    Owner       : Pointer;
    Data        : TMenuData;
    Stack       : Array[1..mysMaxMenuStack] of String[mysMaxMenuNameLen];
    StackPos    : Byte;
    MenuName    : String[20];
    MenuOld     : String[20];
    ExtKeys     : String;
    UseHotKeys  : Boolean;
    ReDraw      : Boolean;
    SetAction   : Boolean;
    UseTimer    : Boolean;
    TimerCount  : LongInt;
    TimerReload : Boolean;
    ViewOnly    : Boolean;

    Constructor Create (O: Pointer);
    Destructor  Destroy; Override;
    Function    StripSecurity      (Str: String) : String;
    Function    ReplaceSecurity    (Str: String; SecLevel: Byte) : String;
    Procedure   ToggleAccessFlags  (Cmd: String; Var Flags: AccessFlagType);
    Function    LoadMenu           (Forced: Boolean) : Boolean;
    Procedure   ExecuteMenu        (Load, Forced, View, Action: Boolean);
    Function    ExecuteCommandList (Num, JumpID: LongInt) : Byte;
    Function    ExecuteByHotkey    (Key: String; Interval: LongInt) : Byte;
    Function    ExecuteCommand     (Cmd, CmdData: String) : Boolean;
    Function    SpecialKey         (Str: String) : Boolean;
    Function    MenuGetKey : Char;
    Function    ShowMenu : Boolean;
    Procedure   GenerateMenu;
    Procedure   DoStandardMenu;
    Procedure   DoLightBarMenu;
  End;

Implementation

Uses
  m_Strings,
  m_DateTime,
  BBS_Core,
  BBS_IO,
  BBS_NodeInfo,
  BBS_General,
  BBS_Doors,
  BBS_NodeChat,
  BBS_UserChat,
  BBS_Ansi_Help,
  BBS_Cfg_Main,
  BBS_Cfg_Events,
  BBS_Cfg_UserEdit,
  BBS_Cfg_Vote;

Constructor TMenuEngine.Create (O: Pointer);
Begin
  Inherited Create;

  StackPos   := 0;
  MenuName   := '';
  MenuOld    := '';
  Owner      := O;
  Data       := TMenuData.Create;
  Redraw     := True;
End;

Destructor TMenuEngine.Destroy;
Begin
  Data.Free;

  Inherited Destroy;
End;

Function TMenuEngine.StripSecurity (Str : String) : String;
Begin
  Delete (Str, Pos('@S', Str), 2);

  Result := Str;
End;

Function TMenuEngine.ReplaceSecurity (Str: String; SecLevel: Byte) : String;
Var
  A : Byte;
Begin
  A := Pos('@', Str);

  If A > 0 Then Begin
    Delete (Str, A, 2);
    Insert (strI2S(SecLevel), Str, A);
  End;

  Result := Str;
End;

Procedure TMenuEngine.ToggleAccessFlags (Cmd: String; Var Flags: AccessFlagType);
Var
  Count : Byte;
Begin
  Count := 1;

  While Count <= Length(Cmd) Do Begin
    If (Cmd[Count] in ['+','-','!']) and (Cmd[Count + 1] in ['A'..'Z']) Then Begin
      Case Cmd[Count] of
        '+' : Flags := Flags + [Ord(Cmd[Count + 1]) - 64];
        '-' : Flags := Flags - [Ord(Cmd[Count + 1]) - 64];
        '!' : If Ord(Cmd[2]) - 64 in Flags Then
                Flags := Flags - [Ord(Cmd[Count + 1]) - 64]
              Else
                Flags := Flags + [Ord(Cmd[Count + 1]) - 64];

      End;
      Inc (Count);
    End;

    Inc (Count);
  End;
End;

Function TMenuEngine.ExecuteCommand (Cmd, CmdData: String) : Boolean;
Var
  Loop1 : LongInt;
  Help  : TAnsiMenuHelp;
Begin
  Result := False;

  If Cmd[0] <> #2 Then Exit;

  Case Cmd[1] of
    '-' : Case Cmd[2] of
            'D' : ToggleAccessFlags(CmdData, Session.User.ThisUser.AF2);
            'F' : ToggleAccessFlags(CmdData, Session.User.ThisUser.AF1);
            'I' : TimerCount := strS2I(CmdData);
            'N' : Session.User.AcsOkFlag := Session.io.GetYN(CmdData, False);
            'P' : Session.User.AcsOkFlag := Session.io.GetPW(Copy(CmdData, 1, Pos(';', CmdData) - 1), Session.GetPrompt(417),
                                                strUpper(Copy(CmdData, Pos(';', CmdData) + 1, Length(CmdData))));
            'S' : Session.SystemLog(CmdData);
            'Y' : Session.User.AcsOkFlag := Session.io.GetYN(CmdData, True);
          End;
    'A' : Case Cmd[2] of
            'E' : AutoSig_Edit;
            'T' : Session.User.ThisUser.SigUse := Session.io.GetYN(Session.GetPrompt(335), False);
            'V' : AutoSig_View;
          End;
    'D' : Case Cmd[2] of
            '-' : ExecuteDoor (0, CmdData);
            'C' : ExecuteDoor (3, CmdData);
            'D' : ExecuteDoor (1, CmdData);
            'G' : ExecuteDoor (2, CmdData);
            '3' : ExecuteDoor (4, CmdData);
          End;
    'F' : Case Cmd[2] of
            'A' : Session.FileBase.ChangeFileArea(CmdData);
            'D' : Begin
                    Session.io.OutFile ('download', True, 0);

                    If (Session.FileBase.BatchNum > 0) and (Session.io.GetYN(Session.GetPrompt(85), True)) Then
                      Session.FileBase.DownloadBatch
                    Else
                      Session.FileBase.DownloadFile;
                  End;
            'F' : Session.FileBase.DownloadFileList (strUpper(CmdData));
            'G' : Session.FileBase.FileGroupChange (CmdData, True, True);
            'L' : Session.FileBase.ListFiles (1, strUpper(CmdData));
            'N' : Session.FileBase.NewFileScan(UpCase(CmdData[1]));
            'P' : Session.FileBase.SetFileScanDate;
            'S' : Session.FileBase.FileSearch;
            'U' : Session.FileBase.UploadFile;
            'V' : Session.FileBase.ViewFile;
            'Z' : Session.FileBase.ToggleFileNewScan;
            '1' : Session.FileBase.MassUpload;
            '2' : Session.FileBase.DirectoryEditor(False, '');
            '3' : Session.FileBase.SendFile (CmdData);
          End;
    'B' : Case Cmd[2] of
            'A' : Add_BBS_List  (CmdData);
            'L' : View_BBS_List (True, CmdData);
            'S' : View_BBS_List (False, CmdData);
          End;
    'G' : Case Cmd[2] of
            '1' : ShowBBSHistory(strS2I(CmdData));
            'A' : View_Directory(CmdData, 0);
            'D' : Session.io.OutFile (CmdData, True, 0);
            'E' : Session.User.Edit_User_Settings(strS2I(CmdData));
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
                    MenuName := CmdData;
                    Result   := True;
                  End;
            'N' : ShowOneLiners (CmdData);
            'P' : {$IFNDEF UNIX} PageForSysopChat (Pos('/F', strUpper(CmdData)) > 0) {$ENDIF};
            'R' : Begin
                    If StackPos > 0 Then Begin
                      MenuOld  := MenuName;
                      MenuName := Stack[StackPos];
                      Result   := True;

                      Dec (StackPos);
                    End;
                  End;
            'S' : Begin
                    MenuOld := MenuName;

                    If StackPos = 8 Then Begin
                      For Loop1 := 1 to 7 Do
                        Stack[Loop1 + 1] := Stack[Loop1];

                      Dec (StackPos);
                    End;

                    Inc (StackPos);

                    Stack[StackPos] := MenuName;
                    MenuName            := CmdData;
                    Result              := True;
                  End;
            'T' : Begin
                    Session.io.OutFull (CmdData);
                    Session.io.BufFlush;
                  End;
            'U' : ShowUserList (strUpper(CmdData));
            'X' : Result := ExecuteMPL(NIL, CmdData) = 2;
            '?' : Begin
                    // online ANSI help system (BBSHTML) prototype
                    Help := TAnsiMenuHelp.Create;
                    Help.OpenHelp (Session.Theme.TextPath + CmdData + ';ansihelp;INDEX');
                    Help.Free;
                  End;
          End;
    'M' : Case Cmd[2] of
            'A' : Session.Msgs.ChangeArea(CmdData);
            'C' : Session.Msgs.CheckEMail;
            'D' : Session.Msgs.SetMessagePointers;
            'G' : Session.Msgs.MessageGroupChange (CmdData, True, True);
            'M' : Session.Msgs.SendMassEmail;
            'N' : Session.Msgs.MessageNewScan (strUpper(CmdData));
            'P' : Session.Msgs.PostMessage (False, CmdData);
            'Q' : Session.Msgs.MessageQuickScan(strUpper(CmdData));
            'R' : Begin
                    If CmdData = '' Then CmdData := ' ';

                    Session.Msgs.ReadMessages(UpCase(CmdData[1]), '');
                  End;
            'S' : Session.Msgs.GlobalMessageSearch(UpCase(CmdData[1]));
            'V' : Session.Msgs.ViewSentEmail;
            'W' : Session.Msgs.PostMessage (True, CmdData);
            'X' : Session.Msgs.PostTextFile(CmdData, False);
            'Z' : Session.Msgs.ToggleNewScan(False);
          End;
    'N' : Case Cmd[2] of
            'A' : Set_Node_Action (CmdData);
            'C' : Node_Chat;
            'P' : PageUserForChat;
            'S' : Send_Node_Message (3, CmdData, 0);
            'W' : Show_Whos_Online;
          End;
    'O' : Case Cmd[2] of
            'S' : Session.Msgs.ToggleNewScan(True);
            'D' : Session.Msgs.DownloadQWK(CmdData);
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
            'R' : Voting_Result (strS2I(CmdData));
            'V' : Voting_Booth (False, strS2I(CmdData));
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
                    PageForSysopChat (Pos('/F', strUpper(CmdData)) > 0) {$ENDIF};
          End;
    '*' : Begin
            If Not Session.io.GetPW (Session.GetPrompt(493), Session.GetPrompt(417), Config.SysopPW) Then Exit;

            Case Cmd[2] of
              '#' : Begin
                      Configuration_ExecuteEditor('M');
                      Result := True;
                    End;
              'A' : Configuration_ExecuteEditor('A');
              'E' : Event_Editor;
              'F' : Configuration_ExecuteEditor('F');
              'G' : Configuration_ExecuteEditor('G');
              'L' : Configuration_ExecuteEditor('L');
              'M' : Configuration_ExecuteEditor('B');
              'P' : Configuration_ExecuteEditor('P');
              'R' : Configuration_ExecuteEditor('R');
              'S' : Configuration_MainMenu;
              'U' : Configuration_UserEditor;
              'V' : Vote_Editor;
            End;
          End;
  End;
End;

Function TMenuEngine.ExecuteCommandList (Num, JumpID: LongInt) : Byte;
// 0 = no commands ran, 1 = commands ran, 2 = load new menu
Var
  Count : LongInt;
Begin
  Result := 0;

  If ViewOnly Then Exit;

  If Not TBBSCore(Owner).User.Access(Data.Item[Num]^.Access) Then Exit;

  Redraw := Boolean(Data.Item[Num]^.Redraw);

  For Count := 1 to Data.Item[Num]^.Commands Do Begin
    If JumpID <> -1 Then
      If JumpID <> Data.Item[Num]^.CmdData[Count]^.JumpID Then Continue;

    If TBBSCore(Owner).User.Access(Data.Item[Num]^.CmdData[Count]^.Access) Then Begin
      Result := 1;

      If ExecuteCommand(Data.Item[Num]^.CmdData[Count]^.MenuCmd, Data.Item[Num]^.CmdData[Count]^.Data) Then Begin
        Result := 2;
        Exit;
      End;
    End;
  End;
End;

Function TMenuEngine.ExecuteByHotkey (Key: String; Interval: LongInt) : Byte;
// 0 = no commands ran, 1 = commands ran, 2 = load new menu
Var
  Count : LongInt;
Begin
  Result := 0;
  Key    := strUpper(Key);

  For Count := 1 to Data.NumItems Do Begin
    If Data.Item[Count] = Nil Then Begin
      Result := 2;
      Break;
    End;

    If Data.Item[Count]^.HotKey = Key Then Begin
      If Key <> 'TIMER' Then
        Result := ExecuteCommandList(Count, -1)
      Else
      If (Interval MOD Data.Item[Count]^.Timer <> 0) Then
        Continue
      Else Begin
        Case Data.Item[Count]^.TimerType of
          0 : Result := ExecuteCommandList(Count, -1);
          1,
          2 : If Data.Item[Count]^.TimerShow Then Begin
                Result := ExecuteCommandList(Count, -1);
                Data.Item[Count]^.TimerShow := False;
              End;
        End;
      End;

      If Result = 2 Then Break;
    End;
  End;
End;

Function TMenuEngine.ShowMenu : Boolean;
Begin
  With TBBSCore(Owner) Do Begin
    Result := Not io.OutFile (ReplaceSecurity(Data.Info.DispFile, User.ThisUser.Security), False, 0);

    If Result And (Pos('@S', Data.Info.DispFile) > 0) Then
      Result := Not io.OutFile(StripSecurity(Data.Info.DispFile), False, 0);
  End;
End;

Function TMenuEngine.SpecialKey (Str: String) : Boolean;
Begin
  Result :=
    (Str = 'AFTER') or
    (Str = 'EVERY') or
    (Str = 'FIRSTCMD') or
    (Str = 'LINEFEED') or
    (Str = 'TIMER');
End;

Procedure TMenuEngine.GenerateMenu;
Var
  Format : Byte;
  Listed : Word;
  Count  : LongInt;
Begin
  If UseTimer Then Begin
    For Count := 1 to Data.NumItems Do
      If Data.Item[Count]^.TimerType = 2 Then
        Data.Item[Count]^.TimerShow := True;
  End;

  If ShowMenu Then Begin
    Case Data.Info.DispCols of
      1 : Format := 79;
      2 : Format := 39;
      3 : Format := 26;
      4 : Format := 19;
    End;

    TBBSCore(Owner).io.OutFullLn (Data.Info.Header);

    Listed := 0;

    For Count := 1 to Data.NumItems Do Begin
      If (Data.Item[Count]^.ShowType = 2) or
         (Data.Item[Count]^.Text = '') or
         (Data.Item[Count]^.HotKey = 'EVERY') or
         (Data.Item[Count]^.HotKey = 'AFTER') or
         (Data.Item[Count]^.HotKey = 'FIRSTCMD') or
         ((Data.Item[Count]^.ShowType = 0) And (Not TBBSCore(Owner).User.Access(Data.Item[Count]^.Access)))
      Then Continue;

      If Data.Item[Count]^.HotKey = 'LINEFEED' Then Begin
        If Listed MOD Data.Info.DispCols <> 0 Then Session.io.OutRawLn('');

        Session.io.OutFull(Data.Item[Count]^.Text);

        While Listed Mod Data.Info.DispCols <> 0 Do Inc(Listed);
      End Else Begin
        Inc (Listed);

        If Format = 79 Then
          TBBSCore(Owner).io.OutFull(Data.Item[Count]^.Text)
        Else
          TBBSCore(Owner).io.OutFull(strPadR(Data.Item[Count]^.Text, Format + Length(Data.Item[Count]^.Text) - strMCILen(Data.Item[Count]^.Text), ' '));

        While Screen.CursorX < Format Do
          Session.io.BufAddChar(' ');

        If Listed MOD Data.Info.DispCols = 0 Then
          TBBSCore(Owner).io.OutFullLn ('');
      End;
    End;

    If Listed MOD Data.Info.DispCols <> 0 Then
      TBBSCore(Owner).io.OutFullLn ('');

    TBBSCore(Owner).io.BufFlush;
  End;

  If ExecuteByHotKey('AFTER', 0) = 2 Then Exit;

  If Data.Info.Footer <> '' Then
    TBBSCore(Owner).io.OutFull(Data.Info.Footer);

  TBBSCore(Owner).io.BufFlush;
End;

Procedure TMenuEngine.DoStandardMenu;
Var
  Ch       : Char;
  Temp     : String[mysMaxMenuInput];
  Count    : LongInt;
  Found    : Boolean;
  ValidKey : Boolean;

  Procedure Translate;
  Begin
    Case Ch of
      #09 : Temp := 'TAB';
      #27 : Temp := 'ESCAPE';
      #71 : Temp := 'HOME';
      #72 : Temp := 'UP';
      #73 : Temp := 'PAGEUP';
      #75 : Temp := 'LEFT';
      #77 : Temp := 'RIGHT';
      #79 : Temp := 'END';
      #80 : Temp := 'DOWN';
      #81 : Temp := 'PAGEDOWN'
    End;
  End;

  Procedure AddChar;
  Begin
    Temp := Temp + UpCase(Ch);

    Case Data.Info.CharType of
      0 : TBBSCore(Owner).io.OutRaw(UpCase(Ch));
      1 : TBBSCore(Owner).io.OutRaw(LoCase(Ch));
      2 : {hidden};
    End;
  End;

Begin
  While Not TBBSCore(Owner).ShutDown Do Begin
    If Not ViewOnly Then
      If ExecuteByHotKey('EVERY', 0) = 2 Then Exit;

    If ReDraw Then GenerateMenu;

    TBBSCore(Owner).io.AllowArrow := True;

    If SetAction Then
      If Data.Info.NodeStatus <> '' Then
        Set_Node_Action(Data.Info.NodeStatus)
      Else
        Set_Node_Action(TBBSCore(Owner).GetPrompt(346));

    Temp := '';

    While Not TBBSCore(Owner).ShutDown Do Begin
      Ch := MenuGetKey;

      If TBBSCore(Owner).ShutDown Then Exit;

      If UseTimer And (Ch = #02) Then Begin
        If TimerReload Then Exit;
        If ReDraw Then Break;
      End;

      Case Ch of
        #08 : If Length(Temp) > 0 Then Begin
                Dec (Temp[0]);

                TBBSCore(Owner).io.OutBS(1, True);
              End;
        #09,
        #27 : If Pos(Ch, ExtKeys) > 0 Then Begin
                Translate;

                Break;
              End;
        #13 : Begin
                If Temp = '' Then Temp := 'ENTER';

                Break;
              End;
        #32..
        #126: If Length(Temp) < mysMaxMenuInput Then Begin
                If TBBSCore(Owner).io.IsArrow And (Pos(Ch, ExtKeys) > 0) Then Begin
                  Translate;
                  Break;
                End;

                If UseHotKeys Then Begin
                  ValidKey := False;
                  Found    := False;
                  Count    := 0;

                  Repeat
                    Inc (Count);

                    If SpecialKey(Data.Item[Count]^.HotKey) Then Continue;

                    Found := Data.Item[Count]^.HotKey = Temp + UpCase(Ch);

                    If Not ValidKey Then
                      ValidKey := Temp + UpCase(Ch) = Copy(Data.Item[Count]^.HotKey, 1, Length(Temp + Ch));
                  Until Found or (Count >= Data.NumItems);

                  If Found And (TBBSCore(Owner).User.Access(Data.Item[Count]^.Access)) Then Begin
                    AddChar;
                    Break;
                  End Else
                    If ValidKey Then AddChar;
                End Else
                  AddChar;
              End;
      End;
    End;

    If Data.Info.CharType <> 2 Then
      TBBSCore(Owner).io.OutRawLn('');

    If ViewOnly Then Exit;

    If Not TBBSCore(Owner).ShutDown Then
      If ExecuteByHotKey(Temp, 0) = 2 Then
        Exit;
  End;
End;

Function TMenuEngine.MenuGetKey : Char;
Var
  LastSec : LongInt;
Begin
  Session.io.BufFlush;
  Session.io.PurgeInputBuffer;

  LastSec := TimerSeconds;

  While Not TBBSCore(Owner).ShutDown Do Begin
    Result := TBBSCore(Owner).io.InKey(1000);

    If TBBSCore(Owner).ShutDown Then Exit;

    If TimerSeconds <> LastSec Then Begin
      LastSec := TimerSeconds;

      If Session.io.DoInputEvents(Result) Then Exit;

      If UseTimer Then Begin
        Inc (TimerCount);

        Case ExecuteByHotkey('TIMER', TimerCount) of
          1 : If ReDraw Then Begin
                Result := #02;
                Exit;
              End;
          2 : Begin
                TimerReload := True;
                Result      := #02;
                Exit;
              End;
        End;

        If TimerCount = 1000000000 Then TimerCount := 0;
      End;
    End;

    If Result <> #255 Then Break;
  End;
End;

Procedure TMenuEngine.DoLightBarMenu;
Var
  TempStr : String;
  PromptX : Byte;
  PromptY : Byte;
  PromptA : Byte;

  Function ValidLightBar (BarPos: Word) : Boolean;
  Begin
    Result := False;

    If BarPos = 0 Then Exit;

    Result := (Data.Item[BarPos]^.HotKey <> 'EVERY') And
              (Data.Item[BarPos]^.HotKey <> 'AFTER') And
              (Data.Item[BarPos]^.HotKey <> 'FIRSTCMD') And
              (Data.Item[BarPos]^.TextLo <> '') And
              (Data.Item[BarPos]^.TextHi <> '') And
              (Data.Item[BarPos]^.ShowType <> 2) And
              ((((Data.Item[BarPos]^.ShowType = 0) And (TBBSCore(Owner).User.Access(Data.Item[BarPos]^.Access)) Or (Data.Item[BarPos]^.ShowType = 1)))
              );
  End;

  Procedure DrawBar (Num: Word; High: Boolean);
  Var
    Str : String;
  Begin
    If Num = 0 Then Exit;

    If High Then
      Str := Data.Item[Num]^.TextHi
    Else
      Str := Data.Item[Num]^.TextLo;

    If Str = '' Then Exit;

    TBBSCore(Owner).io.AnsiGotoXY(Data.Item[Num]^.X, Data.Item[Num]^.Y);
    TBBSCore(Owner).io.OutFull(Str);
  End;

  Procedure AddChar (Ch: Char);
  Var
    SavedAttr : Byte;
    Str       : String = '';
    Offset    : Byte;
  Begin
    If Data.Info.CharType = 2 Then Begin  // hidden
      TempStr := TempStr + UpCase(Ch);
      Exit;
    End;

    SavedAttr := Screen.TextAttr; // tbbscore

    If Ch = #08 Then
      Offset := Length(TempStr) + 1
    Else
      Offset := Length(TempStr);

    TBBSCore(Owner).io.BufAddStr  (#27 + '[s');
    TBBSCore(Owner).io.AnsiGotoXY (PromptX + Offset, PromptY);
    TBBSCore(Owner).io.AnsiColor  (PromptA);

    If Ch = #08 Then
      Str := Str + #8#32#8
    Else Begin
      Case Data.Info.CharType of
        0 : Ch := UpCase(Ch);
        1 : Ch := LoCase(Ch);
      End;

      Str     := Str + Ch;
      TempStr := TempStr + UpCase(Ch);
    End;

    TBBSCore(Owner).io.BufAddStr(Str);
    TBBSCore(Owner).io.AnsiColor(SavedAttr);
    TBBSCore(Owner).io.BufAddStr(#27 + '[u');
    TBBSCore(Owner).io.BufFlush;
  End;

Var
  Count     : Word;
  CursorPos : Word;
  TempPos   : Word;
  Ch        : Char;
  Found     : Boolean;
  ValidKey  : Boolean;
Begin
  CursorPos := 0;

  While Not TBBSCore(Owner).ShutDown Do Begin
    If Not ViewOnly Then
      ExecuteByHotKey('EVERY', 0);

    If SetAction Then
      If Data.Info.NodeStatus <> '' Then
        Set_Node_Action(Data.Info.NodeStatus)
      Else
        Set_Node_Action(TBBSCore(Owner).GetPrompt(346));

    If ReDraw Then Begin
      If UseTimer Then Begin
        For Count := 1 to Data.NumItems Do
          If Data.Item[Count]^.TimerType = 2 Then
            Data.Item[Count]^.TimerShow := True;
      End;

      ShowMenu;

      If Data.Info.Header <> '' Then
        TBBSCore(Owner).io.OutFull(Data.Info.Header);

      If Data.Info.Footer <> '' Then
        TBBSCore(Owner).io.OutFull(Data.Info.Footer);

      TBBSCore(Owner).io.BufFlush;

      PromptX := Screen.CursorX; //tbbscore
      PromptY := Screen.CursorY; //tbbscore
      PromptA := Screen.TextAttr; //tbbscore
    End;

    For Count := 1 to Data.NumItems Do
      If ValidLightBar(Count) Then Begin
        If CursorPos = 0 Then CursorPos := Count;
        DrawBar (Count, False);
      End;

    TBBSCore(Owner).io.AllowArrow := True;

    If Not ViewOnly Then
      ExecuteByHotKey('AFTER', 0);

    DrawBar (CursorPos, True);

    TempStr := '';

    While Not TBBSCore(Owner).ShutDown Do Begin
      Ch := MenuGetKey;

      If UseTimer And (Ch = #02) Then Begin
        If TimerReload Then Exit;
        If ReDraw Then Break;
      End;

      If TBBSCore(Owner).ShutDown Then Exit;

      If TBBSCore(Owner).io.IsArrow Then Begin
        Case Ch of
          #72,
          #75 : Case Data.Info.MenuType of
                  1 : Begin
                        TempPos := CursorPos;

                        While TempPos > 1 Do Begin
                          Dec (TempPos);
                          If ValidLightBar(TempPos) Then Begin
                            DrawBar (CursorPos, False);
                            DrawBar (TempPos, True);
                            CursorPos := TempPos;
                            Break;
                          End;
                        End;
                      End;
                  2 : Case Ch of
                        #72 : If ValidLightBar(Data.Item[CursorPos]^.JumpUp) Then Begin
                                ExecuteCommandList(CursorPos, 1);
                                DrawBar (CursorPos, False);
                                CursorPos := Data.Item[CursorPos]^.JumpUp;
                                DrawBar (CursorPos, True);
                              End;
                        #75 : If ValidLightBar(Data.Item[CursorPos]^.JumpLeft) Then Begin
                                ExecuteCommandList(CursorPos, 3);
                                DrawBar (CursorPos, False);
                                CursorPos := Data.Item[CursorPos]^.JumpLeft;
                                DrawBar (CursorPos, True);
                              End;
                      End;
                End;
          #77,
          #80 : Case Data.Info.MenuType of
                  1 : Begin
                        TempPos := CursorPos;

                        While TempPos < Data.NumItems Do Begin
                          Inc (TempPos);
                          If ValidLightBar(TempPos) Then Begin
                            DrawBar (CursorPos, False);
                            DrawBar (TempPos, True);
                            CursorPos := TempPos;
                            Break;
                          End;
                        End;
                      End;
                  2 : Case Ch of
                        #77 : If ValidLightBar(Data.Item[CursorPos]^.JumpRight) Then Begin
                                ExecuteCommandList (CursorPos, 4);
                                DrawBar (CursorPos, False);
                                CursorPos := Data.Item[CursorPos]^.JumpRight;
                                DrawBar (CursorPos, True);
                              End;
                        #80 : If ValidLightBar(Data.Item[CursorPos]^.JumpDown) Then Begin
                                ExecuteCommandList (CursorPos, 2);
                                DrawBar (CursorPos, False);
                                CursorPos := Data.Item[CursorPos]^.JumpDown;
                                DrawBar (CursorPos, True);
                              End;
                      End;
                End;
          #71 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 9) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
          #73 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 7) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
          #79 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 10) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
          #81 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 8) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
        End;
      End Else
        Case Ch of
          #08 : If Length(TempStr) > 0 Then Begin
                  Dec (TempStr[0]);
                  AddChar(#8);
                End;
          #09 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 5) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
          #13 : Begin
                  TBBSCore(Owner).io.AnsiGotoXY(Data.Info.DoneX, Data.Info.DoneY);

                  If ViewOnly Then Exit;

                  If Data.Info.MenuType = 1 Then
                    Found := ExecuteCommandList(CursorPos, -1) = 2
                  Else
                    Found := ExecuteCommandList(CursorPos, 0) = 2;

                  If Found Then Exit Else Break;
                End;
          #27 : If Data.Info.MenuType = 2 Then
                  Case ExecuteCommandList(CursorPos, 6) of
                    0 : ;
                    1 : Break;
                    2 : Exit;
                  End;
        Else
          If Length(TempStr) < mysMaxMenuInput Then Begin
            Found    := False;
            ValidKey := False;
            Count    := 0;

            Repeat
              Inc (Count);

              If SpecialKey(Data.Item[Count]^.HotKey) Then Continue;

              Found := Data.Item[Count]^.HotKey = TempStr + UpCase(Ch);

              If Not ValidKey Then
                ValidKey := TempStr + UpCase(Ch) = Copy(Data.Item[Count]^.HotKey, 1, Length(TempStr + Ch));

            Until Found or (Count >= Data.NumItems);

            If Found And (TBBSCore(Owner).User.Access(Data.Item[Count]^.Access)) Then Begin
              If Length(TempStr) > 0 Then AddChar (Ch);

              If ValidLightBar(Count) Then Begin
                DrawBar(CursorPos, False);
                CursorPos := Count;
                DrawBar(CursorPos, True);
              End;

              TBBSCore(Owner).io.AnsiGotoXY(Data.Info.DoneX, Data.Info.DoneY);

              If Data.Info.MenuType = 1 Then
                Found := ExecuteCommandList(CursorPos, -1) = 2
              Else
                Found := ExecuteCommandList(CursorPos, 0) = 2;

              If Found Then Exit Else Break;
            End Else
              If ValidKey Then AddChar(Ch);
          End;
        End;
    End;
  End;
End;

Function TMenuEngine.LoadMenu (Forced: Boolean) : Boolean;
Begin
  Result := True;

  If Not Data.Load (False, TBBSCore(Owner).Theme.MenuPath + MenuName + '.mnu') Then Begin
    Result := False;

    If TBBSCore(Owner).Theme.Flags AND thmFallback <> 0 Then
      Result := Data.Load (False, Config.MenuPath + MenuName + '.mnu');

    If Not Result Then Begin
      If Forced Then Begin
        Session.io.OutFullLn ('|CRError Loading ' + MenuName + '.mnu');
        Session.SystemLog ('Error Loading Menu: ' + MenuName);

        Halt(1);
      End;

      Exit;
    End;
  End;
End;

Procedure TMenuEngine.ExecuteMenu (Load, Forced, View, Action: Boolean);
Var
  Count : LongInt;
Begin
  SetAction  := Action;
  ViewOnly   := View;

  If ViewOnly Then Begin
    Case Data.Info.MenuType of
      0 : DoStandardMenu;
      1,
      2 : If TBBSCore(Owner).io.Graphics > 0 Then
            DoLightBarMenu
          Else
            DoStandardMenu;
    End;

    Exit;
  End;

  If Load Then
    If Not LoadMenu(Forced) Then Exit;

  If Not TBBSCore(Owner).User.Access(Data.Info.Access) Then Begin
    MenuName := MenuOld;

    TBBSCore(Owner).io.OutFull(TBBSCore(Owner).GetPrompt(149));
    Exit;
  End;

  If Data.Info.Global Then
    If Not Data.Load (True, TBBSCore(Owner).Theme.MenuPath + 'global.mnu') Then
      If TBBSCore(Owner).Theme.Flags AND thmFallback <> 0 Then
        Data.Load (True, Config.MenuPath + 'global.mnu');

  If Data.Info.InputType = 0 Then
    UseHotKeys := TBBSCore(Owner).User.ThisUser.HotKeys
  Else
    UseHotKeys := Not Boolean(Data.Info.InputType - 1);

  ExtKeys     := '';
  UseTimer    := False;
  ReDraw      := True;
  TimerCount  := 0;
  TimerReload := False;

  For Count := 1 to Data.NumItems Do Begin
    If (Data.Item[Count]^.HotKey = 'EVERY') or
       Not TBBSCore(Owner).User.Access(Data.Item[Count]^.Access) Then
         Continue;

    If Data.Item[Count]^.HotKey = 'FIRSTCMD' Then Begin
      If ExecuteCommandList(Count, -1) = 2 Then Exit;
    End Else
    If Data.Item[Count]^.HotKey = 'TAB'      Then ExtKeys := ExtKeys + #09 Else
    If Data.Item[Count]^.HotKey = 'ESCAPE'   Then ExtKeys := ExtKeys + #27 Else
    If Data.Item[Count]^.HotKey = 'UP'       Then ExtKeys := ExtKeys + #72 Else
    If Data.Item[Count]^.HotKey = 'PAGEUP'   Then ExtKeys := ExtKeys + #73 Else
    If Data.Item[Count]^.HotKey = 'LEFT'     Then ExtKeys := ExtKeys + #75 Else
    If Data.Item[Count]^.HotKey = 'RIGHT'    Then ExtKeys := ExtKeys + #77 Else
    If Data.Item[Count]^.HotKey = 'DOWN'     Then ExtKeys := ExtKeys + #80 Else
    If Data.Item[Count]^.HotKey = 'PAGEDOWN' Then ExtKeys := ExtKeys + #81 Else
    If Data.Item[Count]^.HotKey = 'HOME'     Then ExtKeys := ExtKeys + #71 Else
    If Data.Item[Count]^.HotKey = 'END'      Then ExtKeys := ExtKeys + #79 Else
    If Data.Item[Count]^.HotKey = 'TIMER'    Then UseTimer := True;
  End;

  Case Data.Info.MenuType of
    0 : DoStandardMenu;
    1,
    2 : If TBBSCore(Owner).io.Graphics > 0 Then
          DoLightBarMenu
        Else
          DoStandardMenu;
  End;
End;

End.

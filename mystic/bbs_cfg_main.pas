Unit bbs_Cfg_Main;

{$I M_OPS.PAS}

Interface

Procedure Configuration_MainMenu;
Procedure Configuration_ExecuteEditor (Mode: Char);

Implementation

Uses
  m_Types,
  m_Strings,
  bbs_Core,
  bbs_IO,
  bbs_Common,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_cfg_SysCfg,
  bbs_cfg_Archive,
  bbs_cfg_Protocol,

  //old editors to be rewritten
  bbs_cfg_useredit,
  bbs_cfg_groups,
  bbs_cfg_events,
  bbs_cfg_filebase,
  bbs_cfg_language,
  bbs_cfg_msgbase,
  bbs_cfg_seclevel,
  bbs_cfg_vote,
  bbs_cfg_menuedit;

Procedure Configuration_ExecuteEditor (Mode: Char);
Var
  TmpImage : TConsoleImageRec;
Begin
  Screen.GetScreenImage (1, 1, 79, 24, TmpImage);

  Case Mode of
    'A' : Configuration_ArchiveEditor;
    'P' : Configuration_ProtocolEditor;
  End;

  Session.io.RemoteRestore(TmpImage);
End;

Var
  MenuPtr : Byte = 0;

Procedure DrawStatus (Item: FormItemRec);
Var
  Topic : String[30];
  Desc  : String[60];
Begin
  Case MenuPtr of
    0 : Topic := 'Main';
    1 : Topic := 'Configuration';
    2 : Topic := 'Servers';
    3 : Topic := 'Editors';
    4 : Topic := 'Info';
  End;

  Desc := Item.Help;

  If Desc = '' Then Desc := Copy(Item.Desc, 4, 255);

  Session.io.AnsiGotoXY (5, 24);
  Session.io.OutPipe ('|16|03(|09' + Topic + '|03) |01-|09> |15' + Desc + '|15.|07.|08.');
  Session.io.AnsiClrEOL;
End;

Procedure Configuration_MainMenu;
Var
  Form    : TAnsiMenuForm;
  Box     : TAnsiMenuBox;
  Image   : TConsoleImageRec;
  MenuPos : Array[0..4] of Byte = (1, 1, 1, 1, 1);
  Res     : Char;

  Procedure BoxOpen (X1, Y1, X2, Y2: Byte);
  Begin
    Box := TAnsiMenuBox.Create;
    Box.Open (X1, Y1, X2, Y2);
  End;

  Procedure CoolBoxOpen (X1: Byte; Text: String);
  Var
    Len : Byte;
  Begin
    Len := Length(Text) + 6;

    Screen.GetScreenImage(X1, 1, X1 + Len, 3, Image);

    WriteXYPipe (X1, 1, 8, Len, 'Ü|15Ü|11ÜÜ|03ÜÜ|09Ü|03Ü|09' + strRep('Ü', Len - 9) + '|08Ü');
    WriteXYPipe (X1, 2, 8, Len, 'Ý|09|17² |15' + Text + ' |00°|16|08Þ');
    WriteXYPipe (X1, 3, 8, Len, 'ß|01²|17 |11À|03ÄÄ|08' + strRep('Ä', Length(Text) - 4) + '|00¿ ±|16|08ß');
  End;

  Procedure CoolBoxClose;
  Begin
    Session.io.RemoteRestore(Image);

    Box.Close;
    Box.Free;
  End;

  Procedure ExecuteOldConfiguration (Mode: Char);
  Var
    TmpImage : TConsoleImageRec;
  Begin
    Screen.GetScreenImage (1, 1, 79, 24, TmpImage);

    Session.io.AnsiColor(7);
    Session.io.AnsiClear;

    Case Mode of
      'U' : User_Editor(False, False);
      'M' : Menu_Editor;
      'T' : Lang_Editor;
      'B' : Message_Base_Editor;
      'G',
      'R' : Group_Editor;
      'F' : File_Base_Editor;
      'S' : Levels_Editor;
      'E' : Event_Editor;
      'V' : Vote_Editor;
    End;

    Session.io.RemoteRestore(TmpImage);
  End;

Begin
  Session.io.OutFile(Config.DataPath + 'cfgroot', False, 0);

  Form := TAnsiMenuForm.Create;

  Form.HelpProc := @DrawStatus;

  Repeat
    Form.Clear;

    Form.ItemPos := MenuPos[MenuPtr];
    MenuPos[0]   := MenuPtr;

    If MenuPtr = 0 Then Begin
      Form.HiExitChars := #80;
      Form.ExitOnFirst := False;
    End Else Begin
      Form.HiExitChars := #75#77;
      Form.ExitOnFirst := True;
    End;

    Case MenuPtr of
      0 : Begin
            Form.AddNone('C', ' Configuration ',  5, 2, 15, 'BBS configuration settings');
            Form.AddNone('S', ' Servers ',       26, 2,  9, 'Mystic Internet Server (MIS) settings');
            Form.AddNone('E', ' Editors ',       41, 2,  9, 'BBS configuration editors');
            Form.AddNone('I', ' Info ',          56, 2,  6, 'BBS Information and Monitors');
            Form.AddNone('X', ' Exit ' ,         69, 2,  6, 'Exit configuration');

            Res := Form.Execute;

            If Form.WasHiExit Then
              If Form.ItemPos = 5 Then
                Break
              Else
                MenuPtr := Form.ItemPos
            Else
              Case Res of
                #27,
                'X' : Break;
                'C' : MenuPtr := 1;
                'S' : MenuPtr := 2;
                'E' : MenuPtr := 3;
                'I' : MenuPtr := 4;
              End;
          End;
      1 : Begin
            BoxOpen      (4, 4, 33, 15);
            CoolBoxOpen  (3, 'Configuration');

            Form.AddNone ('S', ' S System Paths',             5,  5, 28, '');
            Form.AddNone ('G', ' G General Settings',         5,  6, 28, '');
            Form.AddNone ('L', ' L Login/Matrix Settings',    5,  7, 28, '');
            Form.AddNone ('1', ' 1 New User Settings 1',      5,  8, 28, '');
            Form.AddNone ('2', ' 2 New User Settings 2',      5,  9, 28, '');
            Form.AddNone ('3', ' 3 New User Optional Fields', 5, 10, 28, '');
            Form.AddNone ('F', ' F File Base Settings',       5, 11, 28, '');
            Form.AddNone ('M', ' M Message Base Settings',    5, 12, 28, '');
            Form.AddNone ('E', ' E Echomail Addresses',       5, 13, 28, '');
            Form.AddNone ('O', ' O Offline Mail Settings',    5, 14, 28, '');

            Res        := Form.Execute;
            MenuPos[1] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 4;
                #77 : MenuPtr := 2;
              End;
            End Else
              Case Res of
                'S' : Configuration_SysPaths;
                'L' : Configuration_LoginMatrix;
                'E' : Configuration_EchoMailAddress(True);
                '3' : Configuration_OptionalFields;
                'F' : Configuration_FileSettings;
                'O' : Configuration_QWKSettings;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      2 : Begin
            BoxOpen      (25, 4, 53, 11);
            CoolBoxOpen  (24, 'Servers');

            Form.AddNone ('I', ' I Internet Server Options', 26,  5, 27, '');
            Form.AddNone ('1', ' 1 Telnet Server Options',   26,  6, 27, '');
            Form.AddNone ('2', ' 2 FTP Server Options',      26,  7, 27, '');
            Form.AddNone ('3', ' 3 POP3 Server Options',     26,  8, 27, '');
            Form.AddNone ('4', ' 4 SMTP Server Options',     26,  9, 27, '');
            Form.AddNone ('5', ' 5 NNTP Server Options',     26, 10, 27, '');

            Res        := Form.Execute;
            MenuPos[2] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 1;
                #77 : MenuPtr := 3;
              End;
            End Else
              Case Res of
                'I' : Configuration_Internet;
                '1' : Configuration_TelnetServer;
                '2' : Configuration_FTPServer;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      3 : Begin
            BoxOpen      (38, 4, 64, 18);
            CoolBoxOpen  (39, 'Editors');

            Form.AddNone ('U', ' U User Editor',           39,  5, 25, '');
            Form.AddNone ('M', ' M Menu Editor',           39,  6, 25, '');
            Form.AddNone ('T', ' T Theme/Prompt Editor',   39,  7, 25, '');
            Form.AddNone ('B', ' B Message Base Editor',   39,  8, 25, '');
            Form.AddNone ('G', ' G Message Group Editor',  39,  9, 25, '');
            Form.AddNone ('F', ' F File Base Editor',      39, 10, 25, '');
            Form.AddNone ('R', ' R File Group Editor',     39, 11, 25, '');
            Form.AddNone ('S', ' S Security Level Editor', 39, 12, 25, '');
            Form.AddNone ('A', ' A Archive Editor',        39, 13, 25, '');
            Form.AddNone ('P', ' P Protocol Editor',       39, 14, 25, '');
            Form.AddNone ('E', ' E Event Editor',          39, 15, 25, '');
            Form.AddNone ('V', ' V Voting Editor',         39, 16, 25, '');
            Form.AddNone ('L', ' L BBS List Editor',       39, 17, 25, '');

            Res        := Form.Execute;
            MenuPos[3] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 2;
                #77 : MenuPtr := 4;
              End;
            End Else
              Case Res of
                'A' : Configuration_ArchiveEditor;
                'P' : Configuration_ProtocolEditor;
                'U',
                'M',
                'T',
                'B',
                'G',
                'R',
                'F',
                'S',
                'E',
                'V' : ExecuteOldConfiguration(Res);
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      4 : Begin
            BoxOpen      (54, 4, 64, 6);
            CoolBoxOpen  (54, 'Info');

            Form.AddNone ('A', ' A About',         55, 5, 9, '');

            Res        := Form.Execute;
            MenuPos[4] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 3;
                #77 : MenuPtr := 1;
              End;
            End Else
              Case Res of
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
    End;
  Until False;

  Form.Free;

  ReWrite (ConfigFile);
  Write   (ConfigFile, Config);
  Close   (ConfigFile);

End;

End.

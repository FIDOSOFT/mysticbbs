Unit bbs_cfg_MenuEdit;

{$I M_OPS.PAS}

Interface

Procedure Configuration_MenuEditor;

Implementation

Uses
  DOS,
  m_Types,
  m_Output,
  m_Strings,
  m_QuickSort,
  m_FileIO,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  BBS_Core,
  BBS_Common,
  BBS_MenuData,
  bbs_cfg_Theme,
  bbs_cfg_Common;

Type
  CmdRec = Record
    Name : String[2];
    Desc : String[30];
  End;

Const
  Num_Cmds = 96;
  MenuCmds : Array[1..Num_Cmds] of CmdRec = (
    // AUTOSIG MENU COMMANDS
    (  Name: 'AE';   Desc: 'Autosig editor'               ),
    (  Name: 'AT';   Desc: 'Toggle autosig on/off'        ),
    (  Name: 'AV';   Desc: 'View autosig'                 ),

    // BBS LIST MENU COMMANDS
    (  Name: 'BA';   Desc: 'BBS list add'                 ),
    (  Name: 'BL';   Desc: 'BBS list view extended'       ),
    (  Name: 'BS';   Desc: 'BBS list view'                ),

    // DOOR EXECUTION MENU COMMANDS
    (  Name: 'D-';   Desc: 'Exec door (no dropfile)'      ),
    (  Name: 'D3';   Desc: 'Exec door (door32.sys)'       ),
    (  Name: 'DC';   Desc: 'Exec door (CHAIN.TXT)'        ),
    (  Name: 'DD';   Desc: 'Exec door (DORINFO1.DEF)'     ),
    (  Name: 'DG';   Desc: 'Exec door (DOOR.SYS)'         ),

    // FILE BASE MENU COMMANDS
    (  Name: 'FA';   Desc: 'File area change'             ),
    (  Name: 'FD';   Desc: 'Download file'                ),
    (  Name: 'FF';   Desc: 'Download filelist'            ),
    (  Name: 'FG';   Desc: 'File group change'            ),
    (  Name: 'FL';   Desc: 'List files'                   ),
    (  Name: 'FN';   Desc: 'New file scan'                ),
    (  Name: 'FP';   Desc: 'Set new filescan date'        ),
    (  Name: 'FS';   Desc: 'Search for files'             ),
    (  Name: 'FU';   Desc: 'Upload files'                 ),
    (  Name: 'FV';   Desc: 'View archive'                 ),
    (  Name: 'FZ';   Desc: 'Toggle newscan bases'         ),
    (  Name: 'F1';   Desc: '(SYSOP) Mass upload'          ),
    (  Name: 'F2';   Desc: '(SYSOP) Directory editor'     ),
    (  Name: 'F3';   Desc: 'Send file by location'        ),

    // GENERAL MENU COMMANDS
    (  Name: 'G1';   Desc: 'Show BBS history'             ),
    (  Name: 'GA';   Desc: 'ANSI art gallery'             ),
    (  Name: 'GD';   Desc: 'Display a file'               ),
    (  Name: 'GE';   Desc: 'Edit user settings'           ),
    (  Name: 'GH';   Desc: 'Hangup'                       ),
    (  Name: 'GI';   Desc: 'Hangup immediately'           ),
    (  Name: 'GL';   Desc: 'Show last callers'            ),
    (  Name: 'GO';   Desc: 'Go to new menu'               ),
    (  Name: 'GN';   Desc: 'Show one-liners'              ),
    (  Name: 'GP';   Desc: 'Page Sysop for chat'          ),
    (  Name: 'GR';   Desc: 'Return from gosub menu'       ),
    (  Name: 'GS';   Desc: 'Gosub to new menu'            ),
    (  Name: 'GT';   Desc: 'Display a line of text'       ),
    (  Name: 'GU';   Desc: 'Display user list'            ),
    (  Name: 'GX';   Desc: 'Execute MPL program'          ),
    (  Name: 'G?';   Desc: 'Open ANSI help browser'       ),

    // MESSAGE BASE MENU COMMANDS
    (  Name: 'MA';   Desc: 'Message area change'          ),
    (  Name: 'MC';   Desc: 'Check e-mail'                 ),
    (  Name: 'MD';   Desc: 'Set msg newscan date'         ),
    (  Name: 'MG';   Desc: 'Message group change'         ),
    (  Name: 'MM';   Desc: 'Send mass e-mail'             ),
    (  Name: 'MN';   Desc: 'Message new scan'             ),
    (  Name: 'MP';   Desc: 'Post a message'               ),
    (  Name: 'MQ';   Desc: 'Message quick scan'           ),
    (  Name: 'MR';   Desc: 'Read messages'                ),
    (  Name: 'MS';   Desc: 'Global message search'        ),
    (  Name: 'MV';   Desc: 'View sent e-mail'             ),
    (  Name: 'MW';   Desc: 'Send new e-mail'              ),
    (  Name: 'MX';   Desc: 'Post text file to base'       ),
    (  Name: 'MZ';   Desc: 'Toggle new scan bases'        ),

    // NODE MENU COMMANDS
    (  Name: 'NA';   Desc: 'Set node action'              ),
    (  Name: 'NC';   Desc: 'Enter teleconference chat'    ),
    (  Name: 'NP';   Desc: 'Page user for private chat'   ),
    (  Name: 'NS';   Desc: 'Send node message'            ),
    (  Name: 'NW';   DEsc: 'Show whos online'             ),

    // OFFLINE MAIL MENU COMMANDS
    (  Name: 'OS';   Desc: 'Set QWK scanned bases'        ),
    (  Name: 'OD';   Desc: 'Download QWK packet'          ),
    (  Name: 'OU';   Desc: 'Upload REP packet'            ),

    // DOWNLOAD QUEUE MENU COMMANDS
    (  Name: 'QA';   Desc: 'Add file to batch queue'      ),
    (  Name: 'QC';   Desc: 'Clear batch queue'            ),
    (  Name: 'QD';   Desc: 'Delete from batch queue'      ),
    (  Name: 'QL';   Desc: 'List batch queue'             ),

    // TIME BANK MENU COMMANDS
    (  Name: 'TD';   Desc: 'Deposit to time bank'         ),
    (  Name: 'TW';   Desc: 'Withdraw from time bank'      ),

    // VOTING BOOTH MENU COMMANDS
    (  Name: 'VA';   Desc: 'Create voting poll'           ),
    (  Name: 'VN';   Desc: 'Vote on new polls'            ),
    (  Name: 'VR';   Desc: 'See poll results'             ),
    (  Name: 'VV';   Desc: 'Vote on a poll'               ),

    // MATRIX LOGIN MENU COMMANDS
    (  Name: 'XA';   Desc: 'Matrix apply for access'      ),
    (  Name: 'XC';   Desc: 'Matrix check for access'      ),
    (  Name: 'XL';   Desc: 'Matrix login'                 ),
    (  Name: 'XP';   Desc: 'Matrix page sysop'            ),

    // OTHER MENU COMMANDS
    (  Name: '-D';   Desc: 'Set access flags (set 2)'     ),
    (  Name: '-F';   Desc: 'Set access flags (set 1)'     ),
    (  Name: '-K';   Desc: 'Add keys to input buffer'     ),
    (  Name: '-N';   Desc: 'Ask Yes/No (default No)'      ),
    (  Name: '-P';   Desc: 'Prompt for a password'        ),
    (  Name: '-S';   Desc: 'Add text to Sysop log'        ),
    (  Name: '-Y';   Desc: 'Ask Yes/No (default Yes)'     ),

    // SYSOP/EDITORS MENU COMMANDS
    (  Name: '*#';   Desc: '(SYSOP) Menu editor'          ),
    (  Name: '*A';   Desc: '(SYSOP) Archive editor'       ),
    (  Name: '*E';   Desc: '(SYSOP) Event editor'         ),
    (  Name: '*F';   Desc: '(SYSOP) File base editor'     ),
    (  Name: '*G';   Desc: '(SYSOP) Message group editor' ),
    (  Name: '*L';   Desc: '(SYSOP) Security level editor'),
    (  Name: '*B';   Desc: '(SYSOP) Message base editor'  ),
    (  Name: '*P';   Desc: '(SYSOP) Protocol editor'      ),
    (  Name: '*R';   Desc: '(SYSOP) File group editor'    ),
    (  Name: '*S';   Desc: '(SYSOP) System configuration' ),
    (  Name: '*U';   Desc: '(SYSOP) User editor'          ),
    (  Name: '*V';   Desc: '(SYSOP) Voting booth editor'  )
  );                       {123456789012345678901234567890}

Var
  Menu     : TMenuData;
  MenuName : String;
  Changed  : Boolean;

Procedure ViewMenu;
Var
  OldData  : TMenuData;
  TmpImage : TConsoleImageRec;
Begin
  Screen.GetScreenImage (1, 1, 79, 24, TmpImage);

  Session.io.OutFull('|07|16|CL');
  Session.io.BufFlush;

  OldData := Session.Menu.Data;

  Session.Menu.Data := Menu;

  Session.Menu.ExecuteMenu(False, False, True, False);

  Session.Menu.Data := OldData;

  Session.io.RemoteRestore(TmpImage);
End;

Function GetCommandDesc (Str: String) : String;
Var
  Count : Byte;
Begin
  Result := 'Unknown Command';
  For Count := 1 to Num_Cmds Do
    If Str = MenuCmds[Count].Name Then Begin
      Result := MenuCmds[Count].Desc;
      Break;
    End;
End;

Function GetCommand (Str: String) : String;
Var
  List  : TAnsiMenuList;
  Count : Byte;
Begin
  List := TAnsiMenuList.Create;

  For Count := 1 to Num_Cmds Do Begin
    List.Add (MenuCmds[Count].Name + '   ' + MenuCmds[Count].Desc, 0);
    If Str = MenuCmds[Count].Name Then
      List.Picked := Count;
  End;

  List.Open (21, 4, 59, 19);
  List.Close;

  If List.ExitCode = #13 Then Begin
    Changed := Str = MenuCmds[List.Picked].Name;
    Str     := MenuCmds[List.Picked].Name;
  End;

  List.Free;

  Result := Str;
End;

Procedure GetExtendedKey (Var Key: String);
Var
  List : TAnsiMenuList;
Begin
  List := TAnsiMenuList.Create;

  List.Add ('FIRSTCMD', 0);
  List.Add ('EVERY', 0);
  List.Add ('AFTER', 0);
  List.Add ('LINEFEED', 0);
  List.Add ('TIMER', 0);
  List.Add ('UP', 0);
  List.Add ('DOWN', 0);
  List.Add ('LEFT', 0);
  List.Add ('RIGHT', 0);
  List.Add ('ENTER', 0);
  List.Add ('TAB', 0);
  List.Add ('ESCAPE', 0);
  List.Add ('HOME', 0);
  List.Add ('END', 0);
  List.Add ('PAGEUP', 0);
  List.Add ('PAGEDOWN', 0);

  List.Open (35, 4, 46, 21);
  List.Close;

  If List.ExitCode <> #27 Then Begin
    Changed := List.List[List.Picked]^.Name <> Key;
    Key     := List.List[List.Picked]^.Name;
  End;

  List.Free;
End;

Procedure EditCommand (Num, CmdNum: Word);
Var
  Box    : TAnsiMenuBox;
  Form   : TAnsiMenuForm;
  Topic  : String;
  CmdStr : String;
Begin
  Topic := '|03(|09Menu Cmd Editor|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Menu (' + MenuName + '): Command #' + strI2S(Num) + ' ';

  Box.Open (13, 9, 68, 16);

  VerticalLine (24, 11, 14);

  Form.AddNone ('C', ' Command ', 15, 11,  9, Topic + 'Menu command function');
  Form.AddStr  ('A', ' Access ' , 16, 12, 26, 12,  8, 30, 30, @Menu.Item[Num]^.CmdData[CmdNum]^.Access, Topic + 'Access level to run this command');
  Form.AddStr  ('D', ' Data '   , 18, 13, 26, 13,  6, 40, 80, @Menu.Item[Num]^.CmdData[CmdNum]^.Data, Topic + 'Menu command optional data');
  Form.AddTog  ('G', ' Execute ', 15, 14, 26, 14,  9,  6,  0, 8, 'Selected Up Down Left Right Tab Escape PgUp PgDn', @Menu.Item[Num]^.CmdData[CmdNum]^.JumpID, Topic + '(Grid) Execute command on what Grid event?');

  Repeat
    CmdStr := '(' + Menu.Item[Num]^.CmdData[CmdNum]^.MenuCmd + ') ' + GetCommandDesc(Menu.Item[Num]^.CmdData[CmdNum]^.MenuCmd);
    WriteXY (26, 11, 113, strPadR(CmdStr, 40, ' '));

    Case Form.Execute of
      #27 : Break;
      'C' : Begin
              Menu.Item[Num]^.CmdData[CmdNum]^.MenuCmd := GetCommand(Menu.Item[Num]^.CmdData[CmdNum]^.MenuCmd);
              Changed := True;
            End;
    End;

    Changed := Changed or Form.Changed;
  Until False;

  Changed := Changed or Form.Changed;

  Box.Close;

  Box.Free;
  Form.Free;
End;

Procedure EditItem (Num: Word);
Const
  Status1 = '(TAB) to edit menu commands';
  Status2 = '(TAB) Switch   (/) Commands';
Var
  Box   : TAnsiMenuBox;
  List  : TAnsiMenuList;
  Form  : TAnsiMenuForm;
  Topic : String;

  Procedure MakeList;
  Var
    Count : Word;
  Begin
    List.Clear;

    For Count := 1 to Menu.Item[Num]^.Commands Do
      With Menu.Item[Num]^.CmdData[Count]^ Do Begin
        List.Add(strPadR('(' + MenuCmd + ') ' + GetCommandDesc(MenuCmd), 26, ' ') + ' ' +
                 strPadR(Access, 12, ' ') + ' ' + Data, 0);
      End;

    List.Add ('', 0);
  End;

Begin
  Box   := TAnsiMenuBox.Create;
  List  := TAnsiMenuList.Create;
  Form  := TAnsiMenuForm.Create;

  Form.LoExitChars := #09#12#27;
  List.LoChars     := #09#13#27#47;
  List.LoAttr      := 113;
  List.NoInput     := True;
  List.NoWindow    := True;
  Box.Header       := ' Command #' + strI2S(Num) + ' (' + MenuName + ') ';
  Topic            := '|03(|09Menu Editor|03) |01-|09> |15';

  Box.Open (3, 2, 77, 21);

  VerticalLine (20, 4, 10);
  VerticalLine (71, 3, 11);

  WriteXY (5, 12, 112, 'Command                     Access       Data');
  WriteXY (5, 13, 112, strRep('Ä', 71));
  WriteXY (5, 20, 112, strPadC(Status1, 72, ' '));
  WriteXY (5, 19, 112, strRep('Ä', 71));

  MakeList;

  List.Open (4, 13, 77, 19);
  List.Picked := 0;
  List.Update;

  Form.AddPipe ('D', ' Display Text ' ,  6,  4, 22,  4, 14, 40, 160, @Menu.Item[Num]^.Text,    Topic + 'Text displayed on generated menus');
  Form.AddPipe ('O', ' LightBar Low ' ,  6,  5, 22,  5, 14, 40, 160, @Menu.Item[Num]^.TextLo,  Topic + 'Normal text in lightbar menu');
  Form.AddPipe ('I', ' LightBar High ',  5,  6, 22,  6, 15, 40, 160, @Menu.Item[Num]^.TextHi,  Topic + 'Highlighted text in lightbar menu');
  Form.AddCaps ('H', ' Hot Key '      , 11,  7, 22,  7,  9, 12, mysMaxMenuInput, @Menu.Item[Num]^.HotKey,  Topic + 'Key to run this command (CTRL-L/Extended Key List)');
  Form.AddStr  ('A', ' Access '       , 12,  8, 22,  8,  8, 30, 30, @Menu.Item[Num]^.Access, Topic + 'ACS level required to access this command');
  Form.AddTog  ('N', ' Display Type ' ,  6,  9, 22,  9, 14,  6,  0, 2, 'Access Always Never', @Menu.Item[Num]^.ShowType, Topic + 'How should this command be displayed?');
  Form.AddByte ('X', 'X'              , 16, 10, 22, 10,  1,  2,  0, 80, @Menu.Item[Num]^.X,   Topic + 'X coordinate of lightbar');
  Form.AddByte ('Y', 'Y'              , 18, 10, 25, 10,  1,  2,  0, 50, @Menu.Item[Num]^.Y,   Topic + 'Y coordinate of lightbar');
  Form.AddByte ('U', ' Up '           , 67,  3, 73,  3,  4,  3,  0, 255, @Menu.Item[Num]^.JumpUp, Topic + '(Grid) Item # to jump to when UP is pressed');
  Form.AddByte ('D', ' Down '         , 65,  4, 73,  4,  6,  3,  0, 255, @Menu.Item[Num]^.JumpDown, Topic + '(Grid) Item # to jump to when DOWN is pressed');
  Form.AddByte ('L', ' Left '         , 65,  5, 73,  5,  6,  3,  0, 255, @Menu.Item[Num]^.JumpLeft, Topic + '(Grid) Item # to jump to when LEFT is pressed');
  Form.AddByte ('R', ' Right '        , 64,  6, 73,  6,  7,  3,  0, 255, @Menu.Item[Num]^.JumpRight, Topic + '(Grid) Item # to jump to when RIGHT is pressed');
  Form.AddByte ('E', ' Escape '       , 63,  7, 73,  7,  8,  3,  0, 255, @Menu.Item[Num]^.JumpEscape, Topic + '(Grid) Item # to jump to when ESCAPE is pressed');
  Form.AddByte ('T', ' Tab '          , 66,  8, 73,  8,  5,  3,  0, 255, @Menu.Item[Num]^.JumpTab, Topic + '(Grid) Item # to jump to when TAB is pressed');
  Form.AddByte ('P', ' PageUp '       , 63,  9, 73,  9,  8,  3,  0, 255, @Menu.Item[Num]^.JumpPgUp, Topic + '(Grid) Item # to jump to when PGUP is pressed');
  Form.AddByte ('G', ' PageDn '       , 63, 10, 73, 10,  8,  3,  0, 255, @Menu.Item[Num]^.JumpPgDn, Topic + '(Grid) Item # to jump to when PGDN is pressed');
  Form.AddBol  ('W', ' Redraw '       , 63, 11, 73, 11,  8,  3,  @Menu.Item[Num]^.ReDraw, Topic + 'Redraw menu after running this command?');

  Repeat
    Case Form.Execute of
      #09 : Begin
              Repeat
                MakeList;

                WriteXY (5, 20, 112, strPadC(Status2, 72, ' '));

                List.NoInput := False;
                List.Open (4, 13, 77, 19);

                Case List.ExitCode of
                  '/' : Case GetCommandOption(10, 'A-Add|D-Delete|') of
                          'A' : Begin
                                  Menu.InsertCommand(Num, List.Picked);
                                  Changed := True;
                                End;
                          'D' : If List.Picked <> List.ListMax Then Begin
                                  Menu.DeleteCommand(Num, List.Picked);
                                  Changed := True;
                                End;
                        End;
                  #09 : Begin
                          List.Picked := 0;
                          List.Update;
                          Break;
                        End;
                  #13 : If List.Picked <> List.ListMax Then EditCommand(Num, List.Picked);
                  #27 : Break;
                End;
              Until False;

              WriteXY (5, 20, 112, strPadC(Status1, 72, ' '));

              If List.ExitCode = #27 Then Break;
            End;
      #12 : GetExtendedKey(Menu.Item[Num]^.HotKey);
      #27 : Break;
    End;

    Changed := Changed or Form.Changed;
  Until False;

  Changed := Changed or Form.Changed;

  Box.Close;

  Form.Free;
  List.Free;
  Box.Free;
End;

Procedure EditFlags;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Menu Flags (' + MenuName + ') ';
  Topic      := '|03(|09Menu Flags|03) |01-|09> |15';;

  Box.Open (6, 5, 75, 20);

  VerticalLine (22, 7, 19);

  Form.AddStr  ('D', ' Description ' ,   9,  7, 24,  7, 13, 30, 30, @Menu.Info.Description, Topic + 'Description of menu');
  Form.AddStr  ('A', ' Access '      ,  14,  8, 24,  8,  8, 30, 30, @Menu.Info.Access, Topic + 'Security requirements to access this menu');
  Form.AddTog  ('T', ' Menu Type '   ,  11,  9, 24,  9, 11, 13,  0, 2, 'Standard Lightbar Lightbar/Grid', @Menu.Info.MenuType, Topic + 'Type of menu');
  Form.AddTog  ('I', ' Input Type '  ,  10, 10, 24, 10, 12, 12,  0, 2, 'User_Defined HotKey LongKey', @Menu.Info.InputType, Topic + 'Input type for this menu');
  Form.AddTog  ('C', ' Input Chars ' ,   9, 11, 24, 11, 13,  9,  0, 2, 'Uppercase Lowercase Hidden', @Menu.Info.CharType, Topic + 'Input format display');
  Form.AddBol  ('G', ' Use Global '  ,  10, 12, 24, 12, 12,  3, @Menu.Info.Global, Topic + 'Include global menu options in this menu?');
  Form.AddStr  ('N', ' Node Status ' ,   9, 13, 24, 13, 13, 30, 30, @Menu.Info.NodeStatus, Topic + 'Node/User status set when this menu is loaded');
  Form.AddStr  ('F', ' Display File ',   8, 14, 24, 14, 14, 20, 20, @Menu.Info.DispFile, Topic + 'Display file shown instead of generated menu');
  Form.AddTog  ('L', ' Display Cols ',   8, 15, 24, 15, 14,  1,  1,  4, '1 2 3 4', @Menu.Info.DispCols, Topic + 'Number of columns in generated menu');
  Form.AddPipe ('H', ' Menu Header ' ,   9, 16, 24, 16, 13, 50, 160, @Menu.Info.Header, Topic + 'Menu header displayed in generated menu');
  Form.AddPipe ('P', ' Menu Prompt ' ,   9, 17, 24, 17, 13, 50, 160, @Menu.Info.Footer, Topic + 'Menu prompt displayed in generated menu');
  Form.AddByte ('X', ' X '           ,  19, 18, 24, 18,  3,  2,  0,  80, @Menu.Info.DoneX, Topic + 'Locate to X coordinate after lightbar menu');
  Form.AddByte ('Y', ' Y '           ,  19, 19, 24, 19,  3,  2,  0,  50, @Menu.Info.DoneY, Topic + 'Locate to Y coordinate after lightbar menu');

  Form.Execute;

  Changed := Changed Or Form.Changed;

  Box.Close;

  Box.Free;
  Form.Free;
End;

Procedure EditMenu;
Var
  Box      : TAnsiMenuBox;
  List     : TAnsiMenuList;
  Count    : Word;
  CopyItem : Word;
  Str      : String;
Begin
  Menu := TMenuData.Create;

  Menu.Load (False, Session.Theme.MenuPath + MenuName + '.mnu');

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  Box.Header    := ' Command list (' + MenuName + ') ';

  Box.Open (9, 5, 72, 21);

  WriteXY (11,  6, 112, 'Hot Key        Text                                     Exec');
  WriteXY (11,  7, 112, strRep('Ä', 60));
  WriteXY (11, 19, 112, strRep('Ä', 60));
  WriteXY (29, 20, 112, cfgCommandList);

  CopyItem := 0;

  Repeat
    List.Clear;

    For Count := 1 to Menu.NumItems Do Begin
      Str := strStripMCI(Menu.Item[Count]^.Text);

      If (Str = '') And (Menu.Item[Count]^.TextLo <> '') Then
        Str := strStripMCI(Menu.Item[Count]^.TextLo);

      List.Add (strPadR(Menu.Item[Count]^.HotKey, 15, ' ') +
                strPadR(Str, 43, ' ') +
                strPadL(strI2S(Menu.Item[Count]^.Commands), 2, ' '), 0);
    End;

    List.Add ('', 0);

    List.Open (9, 7, 72, 19);

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'F-Flags|A-Add|D-Delete|C-Copy|P-Paste|V-View|') of
              'A' : Begin
                      Menu.InsertItem(List.Picked);
                      Changed := True;
                    End;
              'C' : If List.Picked <> List.ListMax Then
                      CopyItem := List.Picked;
              'D' : If List.Picked <> List.ListMax Then Begin
                      Menu.DeleteItem(List.Picked);
                      Changed := True;
                    End;
              'F' : EditFlags;
              'P' : If (CopyItem > 0) And (CopyItem < List.ListMax) And (Menu.Item[CopyItem] <> NIL) Then Begin
                      Menu.CopyItem(CopyItem, List.Picked);
                      Changed := True;
                    End;
              'V' : ViewMenu;
            End;
      #13 : If List.Picked <> List.ListMax Then
              EditItem (List.Picked);
      #27 : Break;
    End;
  Until False;

  Box.Close;

  List.Free;
  Box.Free;

  If Changed Then
    If ShowMsgBox(1, 'Save changes to ' + MenuName + '?') Then
      If Not Menu.Save(Session.Theme.MenuPath + MenuName + '.mnu') Then
        ShowMsgBox(0, 'Unable to save menu');

  Menu.Free;
End;

Function GetMenuName (OldName: String) : String;
Var
  Box  : TAnsiMenuBox;
  List : TAnsiMenuList;
  MF   : Text;

  Procedure MakeList;
  Var
    Dir   : SearchRec;
    Sort  : TQuickSort;
    Count : Word;
    Desc  : String;
  Begin
    Sort := TQuickSort.Create;

    FindFirst (Session.Theme.MenuPath + '*.mnu', Archive, Dir);

    While DosError = 0 Do Begin
      Sort.Add(JustFileName(Dir.Name), 0);
      FindNext (Dir);
    End;

    FindClose(Dir);

    Sort.Sort(1, Sort.Total, qAscending);

    List.Clear;

    For Count := 1 to Sort.Total Do Begin
      Assign (MF, Session.Theme.MenuPath + Sort.Data[Count]^.Name + '.mnu');

      {$I-} Reset (MF); {$I+}

      If IoResult = 0 Then Begin
        ReadLn (MF, Desc);
        Close  (MF);
      End Else
        Desc := '';

      List.Add(strPadR(Sort.Data[Count]^.Name, 22, ' ') + Desc, 0);

      If Sort.Data[Count]^.Name = OldName Then
        List.Picked := List.ListMax;
    End;

    Sort.Free;
  End;

  Procedure CopyMenu (Orig: String);
  Var
    Str : String;
  Begin
    Str := InBox('Copy menu', 'New menu name: ', '', 20, 20);

    If Str = '' Then Exit;

    Str := Session.Theme.MenuPath + Str + '.mnu';

    If FileExist(Str) Then
      If ShowMsgBox(1, JustFile(Str) + ' already exists. Overwrite?') Then
        FileErase(Str);

    FileCopy(Session.Theme.MenuPath + Orig + '.mnu', Str);
  End;

  Procedure InsertMenu;
  Var
    Str : String;
    OK  : Boolean;
  Begin
    Str := InBox('Insert Menu', 'New menu name: ', '', 20, 20);

    If Str = '' Then Exit;

    OK := Not FileExist(Session.Theme.MenuPath + Str + '.mnu');

    If Not OK Then
      OK := ShowMsgBox(1, Str + ' already exists.  Overwrite?');

    If OK Then Begin
      Menu := TMenuData.Create;

      Menu.CreateNewMenu(Session.Theme.MenuPath + Str + '.mnu');

      Menu.Free;
    End;
  End;

Begin
  Result := '';

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  Box.Header    := ' Menu Editor (' + Session.Theme.Desc + ') ';

  Box.Open (12, 5, 68, 21);

  WriteXY (14,  6, 112, 'Menu Name             Description');
  WriteXY (14,  7, 112, strRep('Ä', 53));
  WriteXY (14, 19, 112, strRep('Ä', 53));
  WriteXY (29, 20, 112, cfgCommandList);

  Repeat
    Changed := False;

    MakeList;

    List.Open (12, 7, 68, 19);

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|') of
              'C' : If List.ListMax > 0 Then
                      CopyMenu(strWordGet(1, List.List[List.Picked]^.Name, ' '));
              'I' : InsertMenu;
              'D' : If List.ListMax > 0 Then
                      If ShowMsgBox(1, 'Delete menu: ' + strWordGet(1, List.List[List.Picked]^.Name, ' ')) Then
                        FileErase (Session.Theme.MenuPath + strWordGet(1, List.List[List.Picked]^.Name, ' ') + '.mnu');
            End;
      #13 : Begin
              If List.ListMax <> 0 Then
                Result := strWordGet(1, List.List[List.Picked]^.Name, ' ');
              Break;
            End;
      #27 : Break;
    End;
  Until False;

  Box.Close;

  List.Free;
  Box.Free;
End;

Procedure Configuration_MenuEditor;
Var
  Saved : String;
Begin
  Saved    := '';
  MenuName := Configuration_ThemeEditor(True);

  If MenuName = '' Then Exit;

  Repeat
    MenuName := GetMenuName(Saved);
    Saved    := MenuName;

    If MenuName = '' Then Exit;

    EditMenu;
  Until False;
End;

End.

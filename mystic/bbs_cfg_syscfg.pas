Unit bbs_cfg_syscfg;

{$I M_OPS.PAS}

Interface

Procedure Configuration_SysPaths;
Procedure Configuration_GeneralSettings;
Procedure Configuration_LoginMatrix;
Procedure Configuration_OptionalFields;
Function  Configuration_EchomailAddress (Edit: Boolean) : Byte;
Procedure Configuration_FileSettings;
Procedure Configuration_QWKSettings;
Procedure Configuration_Internet;
Procedure Configuration_FTPServer;
Procedure Configuration_TelnetServer;
Procedure Configuration_POP3Server;
Procedure Configuration_SMTPServer;
Procedure Configuration_NNTPServer;
Procedure Configuration_MessageSettings;
Procedure Configuration_NewUser1Settings;
Procedure Configuration_NewUser2Settings;
Procedure Configuration_ConsoleSettings;

Implementation

Uses
  m_Strings,
  bbs_Common,
  bbs_ansi_MenuBox,
  bbs_ansi_MenuForm;

Procedure Configuration_SysPaths;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09System Paths|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' System Directories ';

  Box.Open (5, 6, 75, 18);

  VerticalLine (26, 8, 16);

  Form.AddPath ('S', ' System Path',       13,  8, 28,  8, 13, 45, mysMaxPathSize, @Config.SystemPath,   Topic + 'Root Mystic BBS directory');
  Form.AddPath ('D', ' Data File Path',    10,  9, 28,  9, 16, 45, mysMaxPathSize, @Config.DataPath,     Topic + 'Data file directory');
  Form.AddPath ('L', ' Log File Path',     11, 10, 28, 10, 15, 45, mysMaxPathSize, @Config.LogsPath,     Topic + 'Log file directory');
  Form.AddPath ('M', ' Message Base Path',  7, 11, 28, 11, 19, 45, mysMaxPathSize, @Config.MsgsPath,     Topic + 'Message base directory');
  Form.AddPath ('A', ' File Attach Path',   8, 12, 28, 12, 18, 45, mysMaxPathSize, @Config.AttachPath,   Topic + 'File attachment directory');
  Form.AddPath ('E', ' Semaphore Path',    10, 13, 28, 13, 16, 45, mysMaxPathSize, @Config.SemaPath,     Topic + 'Semaphore file directory');
  Form.AddPath ('U', ' Menu File Path',    10, 14, 28, 14, 16, 45, mysMaxPathSize, @Config.MenuPath,     Topic + 'Default menu file directory');
  Form.AddPath ('T', ' Text File Path',    10, 15, 28, 15, 16, 45, mysMaxPathSize, @Config.TextPath,     Topic + 'Default display file directory');
//  Form.AddPath ('P', ' Template Path',     11, 16, 29, 16, 15, 45, mysMaxPathSize, @Config.TemplatePath, Topic + 'Default template file directory');
  Form.AddPath ('R', ' Script Path',       13, 16, 28, 16, 13, 45, mysMaxPathSize, @Config.ScriptPath,   Topic + 'Default script (MPL) directory');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_GeneralSettings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09General Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Open (5, 5, 75, 17);

  VerticalLine (24, 7, 15);
  VerticalLine (67, 7, 12);

  Form.AddStr  ('B', ' BBS Name',         14,  7, 26,  7, 10, 25, 30, @Config.BBSName, Topic);
  Form.AddStr  ('S', ' Sysop Name',       12,  8, 26,  8, 12, 25, 30, @Config.SysopName, Topic);
  Form.AddPass ('Y', ' Sysop Password',    8,  9, 26,  9, 16, 15, 15, @Config.SysopPW, Topic);
  Form.AddPass ('T', ' System Password',   7, 10, 26, 10, 17, 15, 15, @Config.SystemPW, Topic);
  Form.AddStr  ('O', ' Sysop ACS',        13, 11, 26, 11, 11, 25, 30, @Config.ACSSysop, Topic);
  Form.AddStr  ('F', ' Feedback To',      11, 12, 26, 12, 13, 25, 30, @Config.FeedbackTo, Topic);
  Form.AddStr  ('A', ' Start Menu',       12, 13, 26, 13, 12, 20, 20, @Config.DefStartMenu, Topic);
  Form.AddStr  ('H', ' Theme',            17, 14, 26, 14,  7, 20, 20, @Config.DefThemeFile, Topic);
  Form.AddTog  ('E', ' Terminal',         14, 15, 26, 15, 10, 10, 0, 3, 'Ask Detect Detect/Ask ANSI', @Config.DefTermMode, Topic);

  Form.AddBol  ('L', ' Chat Logging',     53,  7, 69,  7, 14,  3, @Config.ChatLogging, Topic);
  Form.AddByte ('R', ' Hours Start',      54,  8, 69,  8, 13,  2, 0, 24, @Config.ChatStart, Topic);
  Form.AddByte ('N', ' Hours End',        56,  9, 69,  9, 11,  2, 0, 24, @Config.ChatEnd, Topic);
  Form.AddBol  ('D', ' Chat Feedback',    52, 10, 69, 10, 15,  3, @Config.ChatFeedback, Topic);
  Form.AddByte ('Z', ' Screen Size',      54, 11, 69, 11, 13,  2, 1, 25, @Config.DefScreenSize, Topic);
  Form.AddWord ('I', ' Inactivity',       55, 12, 69, 12, 12,  5, 0, 65535, @Config.Inactivity, Topic + 'Inactivity timeout (seconds) 0/Disable');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_LoginMatrix;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09Login/Matrix|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Login/Matrix ';

  Box.Open (12, 6, 68, 20);

  VerticalLine (35, 7, 19);

  Form.AddByte ('A', ' Login Attempts',      19,  7, 37,  7, 16,  3,  1, 255,   @Config.LoginAttempts,  Topic + 'Maximum login attempts before disconnect');
  Form.AddByte ('T', ' Login Time',          23,  8, 37,  8, 12,  3,  1, 255,   @Config.LoginTime,      Topic + 'Max time in minutes to give for user login');
  Form.AddWord ('C', ' Password Change',     18,  9, 37,  9, 17,  5,  0, 65535, @Config.PWChange,       Topic + 'Days before forcing PW change (0/Disabled)');
  Form.AddBol  ('I', ' Password Inquiry',    17, 10, 37, 10, 18,  3,            @Config.PWInquiry,      Topic + 'Allow password inquiry e-mails?');
  Form.AddByte ('W', ' Password Attempts',   16, 11, 37, 11, 19,  2,  1, 99,    @Config.PWAttempts,     Topic + 'Max Password attempts');

  Form.AddBol  ('U', ' Use Matrix Login',    17, 13, 37, 13, 18,  3,            @Config.UseMatrix,      Topic + 'Use Matrix login menu?');
  Form.AddStr  ('M', ' Matrix Menu',         22, 14, 37, 14, 13, 20, 20,        @Config.MatrixMenu,     Topic + 'Matrix menu file name');
  Form.AddPass ('P', ' Matrix Password',     18, 15, 37, 15, 17, 15, 15,        @Config.MatrixPW,       Topic + 'Matrix password to login (Blank/Disabled)');
  Form.AddStr  ('S', ' Matrix ACS',          23, 16, 37, 16, 12, 30, 30,        @Config.MatrixACS,      Topic + 'ACS to see matrix password or login');
  Form.AddStr  ('V', ' Invisible Login ACS', 14, 17, 37, 17, 21, 30, 30,        @Config.AcsInvisLogin,  Topic + 'ACS to login as invisible user');
  Form.AddStr  ('N', ' See Invisible ACS',   16, 18, 37, 18, 19, 30, 30,        @Config.AcsSeeInvis,    Topic + 'ACS to see invisible users');
  Form.AddStr  ('L', ' Multi Login ACS',     18, 19, 37, 19, 17, 30, 30,        @Config.AcsMultiLogin,  Topic + 'ACS to login to multiple nodes at once');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_OptionalFields;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
  Count : Byte;
Begin
  Topic := '|03(|09Optional Fields|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Optional User Fields ';

  For Count := 1 to 10 Do Begin
    Form.AddBol  ('1', 'Ask' ,   8, 7 + Count, 12, 7 + Count, 3, 3,      @Config.OptionalField[Count].Ask, Topic + 'Ask optional field #' + strI2S(Count));
    Form.AddStr  ('2', 'Desc',  18, 7 + Count, 23, 7 + Count, 4, 13, 13, @Config.OptionalField[Count].Desc, Topic + 'Description of field (for user editor)');
    Form.AddTog  ('3', 'Type',  41, 7 + Count, 46, 7 + Count, 4, 8, 1, 8, 'Standard Upper Proper Phone Date Password Lower Yes/No', @Config.OptionalField[Count].iType, Topic + 'Field input type');
    Form.AddByte ('4', 'Field', 57, 7 + Count, 63, 7 + Count, 5, 2, 1, 60, @Config.OptionalField[Count].iField, Topic + 'Size of input field');
    Form.AddByte ('5', 'Max'  , 68, 7 + Count, 72, 7 + Count, 3, 2, 1, 60, @Config.OptionalField[Count].iMax, Topic + 'Maximum size of input');
  End;

  Box.Open (6, 6, 75, 19);

  Form.Execute;

  Box.Close;
  Form.Free;
  Box.Free;
End;

Function Configuration_EchomailAddress (Edit: Boolean) : Byte;

  Procedure EditAddress (Num: Byte);
  Var
    Box   : TAnsiMenuBox;
    Form  : TAnsiMenuForm;
    Topic : String;
  Begin
    Topic := '|03(|09Echomail Network|03) |01-|09> |15';
    Box   := TAnsiMenuBox.Create;
    Form  := TAnsiMenuForm.Create;

    Box.Open (14, 6, 66, 17);

    VerticalLine (29,  9, 12);
    VerticalLine (29, 14, 15);
    VerticalLine (54,  9, 12);

    WriteXY (21, 8, 112, 'Address');
    WriteXY (47, 8, 112, 'Uplink');

    Form.AddWord ('Z', ' Zone'       , 23,  9, 31,  9,  6,  5,  0, 65535, @Config.NetAddress[Num].Zone, Topic + 'Network Zone');
    Form.AddWord ('N', ' Net'        , 24, 10, 31, 10,  5,  5,  0, 65535, @Config.NetAddress[Num].Net, Topic + 'Network Net');
    Form.AddWord ('O', ' Node'       , 23, 11, 31, 11,  6,  5,  0, 65535, @Config.NetAddress[Num].Node, Topic + 'Network Node');
    Form.AddWord ('P', ' Point'      , 22, 12, 31, 12,  7,  5,  0, 65535, @Config.NetAddress[Num].Point, Topic + 'Network Point');

    Form.AddStr  ('M', ' Domain',      21, 14, 31, 14,  8,  8,  8, @Config.NetDomain[Num], Topic + 'Network domain');
    Form.AddStr  ('D', ' Description', 16, 15, 31, 15, 13, 25, 25, @Config.NetDesc[Num], Topic + 'Network description');

    Form.AddWord ('Z', ' Zone'       , 48,  9, 56,  9,  6,  5,  0, 65535, @Config.NetUplink[Num].Zone, Topic + 'Uplink Zone');
    Form.AddWord ('N', ' Net'        , 49, 10, 56, 10,  5,  5,  0, 65535, @Config.NetUplink[Num].Net, Topic + 'Uplink Net');
    Form.AddWord ('O', ' Node'       , 48, 11, 56, 11,  6,  5,  0, 65535, @Config.NetUplink[Num].Node, Topic + 'Uplink Node');
    Form.AddWord ('P', ' Point'      , 47, 12, 56, 12,  7,  5,  0, 65535, @Config.NetUplink[Num].Point, Topic + 'Uplink Point');

    Form.Execute;

    Box.Close;

    Form.Free;
    Box.Free;
  End;

Var
  Box  : TAnsiMenuBox;
  List : TAnsiMenuList;

  Procedure CreateList;
  Var
    A : Byte;
  Begin
    List.Clear;

    For A := 1 to 30 Do
      List.Add(strPadL(strAddr2Str(Config.NetAddress[A]), 23, ' ') + ' ' + strPadL(Config.NetDesc[A], 20, ' '), 0);
  End;

Begin
  Result := 0;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;

  Box.Open (17, 6, 64, 21);

  WriteXY (27, 7, 112, 'Network Address          Description');
  WriteXY (19, 8, 112, strRep('Ä', 44));

  Repeat
    CreateList;

    List.Open (17, 8, 64, 21);

    Case List.ExitCode of
      #13 : If Edit Then
              EditAddress(List.Picked)
            Else Begin
              Result := List.Picked;
              Break;
            End;
      #27 : Break;
    End;
  Until False;

  List.Close;
  Box.Close;

  List.Free;
  Box.Free;
End;

Procedure Configuration_FileSettings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09File Base Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' File Base Settings ';

  Box.Open (5, 5, 76, 21);

  VerticalLine (26, 7, 19);
  VerticalLine (58, 7, 14);

  Form.AddBol  ('L', ' List Compression',    8,  7, 28,  7, 18,  3, @Config.FCompress, Topic + '');
  Form.AddTog  ('I', ' List Columns',       12,  8, 28,  8, 14,  1, 1, 2, '1 2', @Config.FColumns, Topic + '');
  Form.AddBol  ('B', ' Bases in Groups',     9,  9, 28,  9, 17,  3, @Config.FShowBases, Topic + '');
  Form.AddBol  ('R', ' Reshow File Header',  6, 10, 28, 10, 20,  3, @Config.FShowHeader, Topic + '');
  Form.AddTog  ('U', ' Upload Dupe Scan',    8, 11, 28, 11, 18,  7, 0, 2, 'None Current All', @Config.FDupeScan, Topic + '');
  Form.AddWord ('P', ' Upload Base',        13, 12, 28, 12, 13,  5, 0, 65535, @Config.UploadBase, Topic + '');
  Form.AddByte ('D', ' Description Lines',   7, 13, 28, 13, 19,  2, 1, 99, @Config.MaxFileDesc, Topic + '');
  Form.AddBol  ('I', ' Import FILE_ID.DIZ',  6, 14, 28, 14, 20,  3, @Config.ImportDIZ, Topic + '');
  Form.AddByte ('M', ' Max Comment Lines',   7, 15, 28, 15, 19,  2, 1, 99, @Config.FCommentLines, Topic + '');
  Form.AddByte ('A', ' Max Comment Cols',    8, 16, 28, 16, 18,  2, 1, 79, @Config.FCommentLen, Topic + '');
  Form.AddBol  ('T', ' Test Uploads',       12, 17, 28, 17, 14,  3, @Config.TestUploads, Topic + '');
  Form.AddByte ('S', ' Pass Level',         14, 18, 28, 18, 12,  3, 0, 255, @Config.TestPassLevel, Topic + '');
  Form.AddStr  ('O', ' Command Line',       12, 19, 28, 19, 14, 45, 80, @Config.TestCmdLine, Topic + '');

  Form.AddStr  ('U', ' Auto Validate',      43,  7, 60,  7, 15, 15, mysMaxAcsSize, @Config.AcsValidate, Topic + 'ACS to auto-validate uploads');
  Form.AddStr  ('E', ' See Unvalidated',    41,  8, 60,  8, 17, 15, mysMaxAcsSize, @Config.AcsSeeUnvalid, Topic + 'ACS to see unvalidated files');
  Form.AddStr  ('N', ' DL Unvalidated',     42,  9, 60,  9, 16, 15, mysMaxAcsSize, @Config.AcsDLUnvalid, Topic + 'ACS to download unvalidated files');
  Form.AddStr  ('F', ' See Failed',         46, 10, 60, 10, 12, 15, mysMaxAcsSize, @Config.AcsSeeFailed, Topic + 'ACS to see failed files');
  Form.AddStr  (#0,  ' DL Failed',          47, 11, 60, 11, 11, 15, mysMaxAcsSize, @Config.AcsDLFailed, Topic + 'ACS to download failed files');
  Form.AddLong ('C', ' Min Upload Space',   40, 12, 60, 12, 18,  9, 0, 999999999, @Config.FreeUL, Topic + 'Min space to allow uploads (kb)');
  Form.AddLong ('-', ' Min CD-ROM Space',   40, 13, 60, 13, 18,  9, 0, 999999999, @Config.FreeCDROM, Topic + 'Min space for CD-ROM copy (kb)');
  Form.AddChar (#0,  ' Default Protocol',   40, 14, 60, 14, 18,  32, 96, @Config.FProtocol, Topic + 'Default Protocol hotkey');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_QWKSettings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09Offline Mail|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Offline Mail ';

  Box.Open (8, 7, 74, 18);

  VerticalLine (31, 9, 16);

  Form.AddPath ('L', ' Local QWK Path',         15,  9, 33,  9, 16, 40, mysMaxPathSize,        @Config.QWKPath,     Topic + 'Directory for local QWK packets');
  Form.AddStr  ('I', ' QWK Packet ID',          16, 10, 33, 10, 15,  8, 8, @Config.QwkBBSID, Topic + 'QWK packet filename');
  Form.AddStr  ('A', ' QWK Archive',            18, 11, 33, 11, 13,  4, 4, @Config.QwkArchive, Topic + 'QWK Archive');
  Form.AddWord ('P', ' Max Messages/Packet',    10, 12, 33, 12, 21,  5, 0, 65535, @Config.QwkMaxPacket, Topic + 'Max messages per packet (0/Unlimited)');
  Form.AddWord ('B', ' Max Messages/Base',      12, 13, 33, 13, 19,  5, 0, 65535, @Config.QwkMaxBase, Topic + 'Max message per base (0/Unlimited)');
  Form.AddStr  ('W', ' Welcome File',           17, 14, 33, 14, 14, 40, mysMaxPathSize, @Config.QWKWelcome, Topic + 'Welcome filename');
  Form.AddStr  ('N', ' News File',              20, 15, 33, 15, 11, 40, mysMaxPathSize, @Config.QWKNews, Topic + 'New filename');
  Form.AddStr  ('G', ' Goodbye File',           17, 16, 33, 16, 14, 40, mysMaxPathSize, @Config.QWKGoodbye, Topic + 'Goodbye filename');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_Internet;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09Internet Servers|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Internet Servers ';

  Box.Open (16, 9, 64, 15);

  VerticalLine (31, 11, 13);

  Form.AddStr  ('D', ' Domain',          23, 11, 33, 11,  8, 25, 25, @Config.inetDomain, Topic + 'Internet domain name');
  Form.AddBol  ('B', ' IP Blocking',     18, 12, 33, 12, 13, 3, @Config.inetIPBlocking, Topic + 'Enable IP blocking');
  Form.AddBol  ('L', ' IP Logging',      19, 13, 33, 13, 12, 3, @Config.inetIPLogging, Topic + 'Enable IP logging');

  Form.Execute;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_FTPServer;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09FTP Server|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' FTP Server ';

  Box.Open (26, 7, 55, 18);

  VerticalLine (47, 9, 16);

  Form.AddBol  ('U', ' Use FTP Server',     31,  9, 49,  9, 16,  3, @Config.inetFTPUse, Topic + 'Enable FTP server');
  Form.AddWord ('P', ' Server Port',        34, 10, 49, 10, 13,  5, 0, 65535, @Config.inetFTPPort, Topic + 'FTP Server port');
  Form.AddWord ('M', ' Max Connections',    30, 11, 49, 11, 17,  5, 0, 65535, @Config.inetFTPMax, Topic + 'Max concurrent connections');
  Form.AddWord ('C', ' Connection Timeout', 27, 12, 49, 12, 20,  5, 0, 65535, @Config.inetFTPTimeout, Topic + 'Connection timeout (seconds)');
  Form.AddByte ('D', ' Dupe IP Limit',      32, 13, 49, 13, 15,  3, 2, 255,   @Config.inetFTPDupes, Topic + 'Max connections with same IP');
  Form.AddWord ('I', ' Data Port Min',      32, 14, 49, 14, 15,  5, 0, 65535, @Config.inetFTPPortMin, Topic + 'Passive port range (minimum)');
  Form.AddWord ('A', ' Data Port Max',      32, 15, 49, 15, 15,  5, 0, 65535, @Config.inetFTPPortMax, Topic + 'Passive port range (maximum)');
  Form.AddBol  ('Y', ' Allow Anonymous',    30, 16, 49, 16, 17,  3, @Config.inetFTPAnon, Topic + 'Allow anonymous users');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_TelnetServer;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09Telnet Server|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Telnet Server ';

  Box.Open (26, 9, 54, 16);

  VerticalLine (46, 11, 14);

  Form.AddBol  ('U', ' Use Telnet Server',  27, 11, 48, 11, 19, 3, @Config.inetTNUse, Topic + 'Enable Telnet server');
  Form.AddByte ('N', ' Telnet Nodes',       32, 12, 48, 12, 14, 3, 1, 255, @Config.inetTNNodes, Topic + 'Max telnet nodes to allow');
  Form.AddWord ('P', ' Server Port',        33, 13, 48, 13, 13, 5, 0, 65535, @Config.inetTNPort, Topic + 'Telnet Server port');
  Form.AddByte ('D', ' Dupe IP Limit',      31, 14, 48, 14, 15, 3, 1, 255,   @Config.inetTNDupes, Topic + 'Max connections with same IP');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_POP3Server;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09POP3 Server|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' POP3 Server ';

  Box.Open (27, 8, 53, 17);

  VerticalLine (45, 10, 15);

  Form.AddBol  ('U', ' Use Server',      33, 10, 47, 10, 12, 3, @Config.inetPOP3Use, Topic + 'Enable POP3 server');
  Form.AddWord ('P', ' Server Port',     32, 11, 47, 11, 13, 5, 0, 65535, @Config.inetPOP3Port, Topic + 'POP3 Server port');
  Form.AddByte ('N', ' Max Connections', 28, 12, 47, 12, 17, 3, 1, 255, @Config.inetPOP3Max, Topic + 'Max Connections');
  Form.AddByte ('I', ' Dupe IP Limit',   30, 13, 47, 13, 15, 3, 1, 255,   @Config.inetPOP3Dupes, Topic + 'Max connections with same IP');
  Form.AddWord ('T', ' Timeout',         36, 14, 47, 14,  9, 5, 0, 65535, @Config.inetPOP3Timeout, Topic + 'Connection timeout (seconds)');
  Form.AddBol  ('D', ' Delete',          37, 15, 47, 15,  8, 3, @Config.inetPOP3Delete, Topic + 'Delete email on retreive');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_SMTPServer;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09SMTP Server|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' SMTP Server ';

  Box.Open (27, 8, 53, 16);

  VerticalLine (45, 10, 14);

  Form.AddBol  ('U', ' Use Server',      33, 10, 47, 10, 12, 3, @Config.inetSMTPUse, Topic + 'Enable SMTP server');
  Form.AddWord ('P', ' Server Port',     32, 11, 47, 11, 13, 5, 0, 65535, @Config.inetSMTPPort, Topic + 'Server port');
  Form.AddByte ('N', ' Max Connections', 28, 12, 47, 12, 17, 3, 1, 255, @Config.inetSMTPMax, Topic + 'Max Connections');
  Form.AddByte ('I', ' Dupe IP Limit',   30, 13, 47, 13, 15, 3, 1, 255,   @Config.inetSMTPDupes, Topic + 'Max connections with same IP');
  Form.AddWord ('T', ' Timeout',         36, 14, 47, 14,  9, 5, 0, 65535, @Config.inetSMTPTimeout, Topic + 'Connection timeout (seconds)');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_NNTPServer;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09NNTP Server|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' NNTP Server ';

  Box.Open (27, 8, 53, 16);

  VerticalLine (45, 10, 14);

  Form.AddBol  ('U', ' Use Server',      33, 10, 47, 10, 12, 3, @Config.inetNNTPUse, Topic + 'Enable NNTP server');
  Form.AddWord ('P', ' Server Port',     32, 11, 47, 11, 13, 5, 0, 65535, @Config.inetNNTPPort, Topic + 'Server port');
  Form.AddByte ('N', ' Max Connections', 28, 12, 47, 12, 17, 3, 1, 255, @Config.inetNNTPMax, Topic + 'Max Connections');
  Form.AddByte ('I', ' Dupe IP Limit',   30, 13, 47, 13, 15, 3, 1, 255,   @Config.inetNNTPDupes, Topic + 'Max connections with same IP');
  Form.AddWord ('T', ' Timeout',         36, 14, 47, 14,  9, 5, 0, 65535, @Config.inetNNTPTimeout, Topic + 'Connection timeout (seconds)');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_MessageSettings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09Message Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Message Base Settings ';

  Box.Open (4, 5, 77, 19);

  VerticalLine (27, 7, 17);
  VerticalLine (65, 7, 14);

  Form.AddBol  ('C', ' List Compression',      9,  7, 29,  7, 18, 3, @Config.MCompress, Topic + 'Compress numbers in area list?');
  Form.AddByte ('I', ' List Columns',         13,  8, 29,  8, 14, 3, 1, 2, @Config.MColumns, Topic + 'Columns in area list');
  Form.AddBol  ('S', ' Show Message Header',   6,  9, 29,  9, 21, 3, @Config.MShowHeader, Topic + 'Redisplay header after each page');
  Form.AddBol  ('B', ' Bases in Group List',   6, 10, 29, 10, 21, 3, @Config.MShowBases, Topic + 'Calculate bases in group list?');
  Form.AddByte ('X', ' Max AutoSig Lines',     8, 11, 29, 11, 19, 3, 1, 99, @Config.MaxAutoSig, Topic + 'Max autosig lines');
  Form.AddStr  ('R', ' Crosspost ACS',        12, 12, 29, 12, 15, 20, 30, @Config.AcsCrossPost, Topic + 'ACS to allow crosspost messages');
  Form.AddStr  ('A', ' Attachment ACS',       11, 13, 29, 13, 16, 20, 30, @Config.AcsFileAttach, Topic + 'ACS to allow file attachments');
  Form.AddStr  ('S', ' Node Lookup ACS',      10, 14, 29, 14, 17, 20, 30, @Config.AcsNodeLookup, Topic + 'ACS to allow nodelist search');
  Form.AddBol  ('T', ' External FSE',         13, 15, 29, 15, 14, 3, @Config.FSEditor, Topic + 'Use external editor');
  Form.AddStr  ('F', ' FSE Command Line',      9, 16, 29, 16, 18, 40, 60, @Config.FSCommand, Topic + 'FSE command line');
  Form.AddStr  ('D', ' Default Origin',       11, 17, 29, 17, 16, 40, 50, @Config.Origin, Topic + 'Origin line for new bases');

  Form.AddAttr ('Q', ' Quote Color',          52,  7, 67,  7, 13, @Config.ColorQuote, Topic + 'Color for quoted text');
  Form.AddAttr ('E', ' Text Color'  ,         53,  8, 67,  8, 12, @Config.ColorText, Topic + 'Color for message text');
  Form.AddAttr ('O', ' Tear Color'  ,         53,  9, 67,  9, 12, @Config.ColorTear, Topic + 'Color for tear line');
  Form.AddAttr ('L', ' Origin Color',         51, 10, 67, 10, 14, @Config.ColorOrigin, Topic + 'Color for origin line');
  Form.AddAttr ('K', ' Kludge Color',         51, 11, 67, 11, 14, @Config.ColorKludge, Topic + 'Color for kludge line');
  Form.AddBol  ('N', ' Netmail Crash',        50, 12, 67, 12, 15, 3, @Config.NetCrash, Topic + 'Use netmail crash flag');
  Form.AddBol  ('M', ' Netmail Hold',         51, 13, 67, 13, 14, 3, @Config.NetHold, Topic + 'Use netmail hold flag');
  Form.AddBol  ('1', ' Netmail Killsent',     47, 14, 67, 14, 18, 3, @Config.NetKillsent, Topic + 'Use netmail killsent flag');

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_NewUser1Settings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09New User Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' New User Settings 1 ';

  Box.Open (18, 5, 63, 16);

  VerticalLine (39, 7, 14);

  Form.AddBol  ('A', ' Allow New Users',    22,  7, 41,  7, 17, 3, @Config.AllowNewUsers, Topic);
  Form.AddByte ('S', ' Security',           29,  8, 41,  8, 10, 3, 1, 255, @Config.NewUserSec, Topic);
  Form.AddStr  ('P', ' Password',           29,  9, 41,  9, 10, 15, 15, @Config.NewUserPW, Topic);
  Form.AddBol  ('N', ' New User Feedback',  20, 10, 41, 10, 19, 3, @Config.NewUserEmail, Topic);
  Form.AddBol  ('U', ' Use USA Phone',      24, 11, 41, 11, 15, 3, @Config.UseUSAPhone, Topic);
  Form.AddTog  ('E', ' User Name Format',   21, 12, 41, 12, 18, 8, 0, 3, 'As_Typed Upper Lower Proper', @Config.UserNameFormat, Topic);
  Form.AddWord ('T', ' Start Msg Group',    22, 13, 41, 13, 17, 5, 0, 65535, @Config.StartMGroup, Topic);
  Form.AddWord ('R', ' Start File Group',   21, 14, 41, 14, 18, 5, 0, 65535, @Config.StartFGroup, Topic);

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_NewUser2Settings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
Begin
  Topic := '|03(|09New User Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' New User Settings 2 ';

  Box.Open (8, 5, 73, 21);

  VerticalLine (25, 7, 19);
  VerticalLine (58, 7, 16);

  Form.AddBol  ('A', ' Ask Theme',      14,  7, 27,  7, 11, 3, @Config.AskTheme, Topic);
  Form.AddBol  ('S', ' Ask Real Name',  10,  8, 27,  8, 15, 3, @Config.AskRealName, Topic);
  Form.AddBol  ('K', ' Ask Alias',      14,  9, 27,  9, 11, 3, @Config.AskAlias, Topic);
  Form.AddBol  ('T', ' Ask Street',     13, 10, 27, 10, 12, 3, @Config.AskStreet, Topic);
  Form.AddBol  ('C', ' Ask City/State',  9, 11, 27, 11, 16, 3, @Config.AskCityState, Topic);
  Form.AddBol  ('Z', ' Ask ZipCode',    12, 12, 27, 12, 13, 3, @Config.AskZipCode, Topic);
  Form.AddBol  ('H', ' Ask Home Phone',  9, 13, 27, 13, 16, 3, @Config.AskHomePhone, Topic);
  Form.AddBol  ('E', ' Ask Cell Phone',  9, 14, 27, 14, 16, 3, @Config.AskDataPhone, Topic);
  Form.AddBol  ('I', ' Ask Birthdate',  10, 15, 27, 15, 15, 3, @Config.AskBirthdate, Topic);
  Form.AddBol  ('G', ' Ask Gender',     13, 16, 27, 16, 12, 3, @Config.AskGender, Topic);
  Form.AddBol  ('M', ' Ask Email',      14, 17, 27, 17, 11, 3, @Config.AskEmail, Topic);
  Form.AddBol  ('L', ' Ask UserNote',   11, 18, 27, 18, 14, 3, @Config.AskUserNote, Topic);
  Form.AddBol  ('R', ' Ask Screensize',  9, 19, 27, 19, 16, 3, @Config.AskScreenSize, Topic);

  Form.AddTog  ('D', ' Date Type',      47,  7, 60,  7, 11, 8, 1, 4, 'MM/DD/YY DD/MM/YY YY/DD/MM Ask', @Config.UserDateType, Topic);
  Form.AddTog  ('O', ' Hot Keys',       48,  8, 60,  8, 10, 3, 0, 2, 'No Yes Ask', @Config.UserHotKeys, Topic);
  Form.AddBol  ('P', ' Ask Protocol',   44,  9, 60,  9, 14, 3, @Config.UserProtocol, Topic);
  Form.AddTog  ('N', ' Node Chat',      47, 10, 60, 10, 11, 6, 0, 2, 'Normal ANSI Ask', @Config.UserFullChat, Topic);
  Form.AddTog  ('F', ' File List',      47, 11, 60, 11, 11, 6, 0, 2, 'Normal ANSI Ask', @Config.UserFileList, Topic);
  Form.AddTog  ('1', ' Message Reader', 42, 12, 60, 12, 16, 6, 0, 2, 'Normal ANSI Ask', @Config.UserReadType, Topic);
  Form.AddTog  ('2', ' Read at Index',  43, 13, 60, 13, 15, 3, 0, 2, 'No Yes Ask', @Config.UserReadIndex, Topic);
  Form.AddTog  ('3', ' Email at Index', 42, 14, 60, 14, 16, 3, 0, 2, 'No Yes Ask', @Config.UserMailIndex, Topic);
  Form.AddTog  ('4', ' Message Editor', 42, 15, 60, 15, 16, 4, 0, 2, 'Line Full Ask', @Config.UserEditorType, Topic);
  Form.AddTog  ('5', ' Quote Mode',     46, 16, 60, 16, 12, 6, 0, 2, 'Line Window Ask', @Config.UserQuoteWin, Topic);

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

Procedure Configuration_ConsoleSettings;
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String[80];
  Count : Byte;
Begin
  Topic := '|03(|09Console Settings|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header := ' Console Settings ';

  Box.Open (5, 5, 76, 16);

  VerticalLine (17, 7, 14);
  VerticalLine (64, 7, 10);

  For Count := 1 to 8 Do
    Form.AddStr (strI2S(Count)[1], ' F' + strI2S(Count) + ' Macro', 7, 6 + Count, 19, 6 + Count, 10, 30, 60, @Config.SysopMacro[Count], Topic);

  Form.AddBol  ('S', ' Status Bar',  52,  7, 66,  7, 12, 3, @Config.UseStatusBar, Topic);
  Form.AddAttr ('1', ' Color 1',     55,  8, 66,  8,  9, @Config.StatusColor1, Topic);
  Form.AddAttr ('2', ' Color 2',     55,  9, 66,  9,  9, @Config.StatusColor2, Topic);
  Form.AddAttr ('3', ' Color 3',     55, 10, 66, 10,  9, @Config.StatusColor3, Topic);

  Form.Execute;
  Form.Free;

  Box.Close;
  Box.Free;
End;

End.

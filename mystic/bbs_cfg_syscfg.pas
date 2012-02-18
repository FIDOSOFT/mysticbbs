Unit bbs_cfg_syscfg;

{$I M_OPS.PAS}

Interface

Procedure Configuration_SysPaths;
Procedure Configuration_LoginMatrix;
Procedure Configuration_OptionalFields;
Function  Configuration_EchomailAddress (Edit: Boolean) : Byte;
Procedure Configuration_FileSettings;
Procedure Configuration_QWKSettings;
Procedure Configuration_Internet;
Procedure Configuration_FTPServer;
Procedure Configuration_TelnetServer;
Procedure Configuration_POP3Server;

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

  Box.Open (5, 7, 75, 17);

  VerticalLine (27, 8, 16);

  Form.AddPath ('S', ' System Path',       13,  8, 29,  8, 13, 45, mysMaxPathSize, @Config.SystemPath,   Topic + 'Root Mystic BBS directory');
  Form.AddPath ('D', ' Data File Path',    10,  9, 29,  9, 16, 45, mysMaxPathSize, @Config.DataPath,     Topic + 'Data file directory');
  Form.AddPath ('L', ' Log File Path',     11, 10, 29, 10, 15, 45, mysMaxPathSize, @Config.LogsPath,     Topic + 'Log file directory');
  Form.AddPath ('M', ' Message Base Path',  7, 11, 29, 11, 19, 45, mysMaxPathSize, @Config.MsgsPath,     Topic + 'Message base directory');
  Form.AddPath ('A', ' File Attach Path',   8, 12, 29, 12, 18, 45, mysMaxPathSize, @Config.AttachPath,   Topic + 'File attachment directory');
  Form.AddPath ('E', ' Semaphore Path',    10, 13, 29, 13, 16, 45, mysMaxPathSize, @Config.SemaPath,     Topic + 'Semaphore file directory');
  Form.AddPath ('U', ' Menu File Path',    10, 14, 29, 14, 16, 45, mysMaxPathSize, @Config.MenuPath,     Topic + 'Default menu file directory');
  Form.AddPath ('T', ' Text File Path',    10, 15, 29, 15, 16, 45, mysMaxPathSize, @Config.TextPath,     Topic + 'Default display file directory');
//  Form.AddPath ('P', ' Template Path',     11, 16, 29, 16, 15, 45, mysMaxPathSize, @Config.TemplatePath, Topic + 'Default template file directory');
  Form.AddPath ('R', ' Script Path',       13, 16, 29, 16, 13, 45, mysMaxPathSize, @Config.ScriptPath,   Topic + 'Default script (MPL) directory');

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
    Topic := '|03(|09Echomail Address|03) |01-|09> |15';
    Box   := TAnsiMenuBox.Create;
    Form  := TAnsiMenuForm.Create;

    Box.Open (21, 8, 60, 16);

    VerticalLine (36, 10, 14);

    Form.AddWord ('Z', ' Zone'       , 30, 10, 38, 10,  6,  5,  0, 65535, @Config.NetAddress[Num].Zone, Topic + 'Network Zone number');
    Form.AddWord ('N', ' Net'        , 31, 11, 38, 11,  5,  5,  0, 65535, @Config.NetAddress[Num].Net, Topic + 'Network Net number');
    Form.AddWord ('O', ' Node'       , 30, 12, 38, 12,  6,  5,  0, 65535, @Config.NetAddress[Num].Node, Topic + 'Network Node number');
    Form.AddWord ('P', ' Point'      , 29, 13, 38, 13,  7,  5,  0, 65535, @Config.NetAddress[Num].Point, Topic + 'Network Pointer number');
    Form.AddStr  ('D', ' Description', 23, 14, 38, 14, 13, 20, 20,        @Config.NetDesc[Num], Topic + 'Network description');

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
  VerticalLine (58, 7, 13);

  Form.AddBol  ('X', ' List Compression',    8,  7, 28,  7, 18,  3, @Config.FCompress, Topic + '');
  Form.AddTog  ('X', ' List Columns',       12,  8, 28,  8, 14,  1, 1, 2, '1 2', @Config.FColumns, Topic + '');
  Form.AddBol  ('X', ' Bases in Groups',     9,  9, 28,  9, 17,  3, @Config.FShowBases, Topic + '');
  Form.AddBol  ('X', ' Reshow File Header',  6, 10, 28, 10, 20,  3, @Config.FShowHeader, Topic + '');
  Form.AddTog  ('X', ' Upload Dupe Scan',    8, 11, 28, 11, 18,  7, 0, 2, 'None Current All', @Config.FDupeScan, Topic + '');
  Form.AddWord ('X', ' Upload Base',        13, 12, 28, 12, 13,  5, 0, 65535, @Config.UploadBase, Topic + '');
  Form.AddByte ('X', ' Description Lines',   7, 13, 28, 13, 19,  2, 1, 99, @Config.MaxFileDesc, Topic + '');
  Form.AddBol  ('X', ' Import FILE_ID.DIZ',  6, 14, 28, 14, 20,  3, @Config.ImportDIZ, Topic + '');
  Form.AddByte ('X', ' Max Comment Lines',   7, 15, 28, 15, 19,  2, 1, 99, @Config.FCommentLines, Topic + '');
  Form.AddByte ('X', ' Max Comment Cols',    8, 16, 28, 16, 18,  2, 1, 79, @Config.FCommentLen, Topic + '');
  Form.AddBol  ('X', ' Test Uploads',       12, 17, 28, 17, 14,  3, @Config.TestUploads, Topic + '');
  Form.AddByte ('X', ' Pass Level',         14, 18, 28, 18, 12,  3, 0, 255, @Config.TestPassLevel, Topic + '');
  Form.AddStr  ('X', ' Command Line',       12, 19, 28, 19, 14, 45, 80, @Config.TestCmdLine, Topic + '');

  Form.AddStr  ('X', ' Auto Validate',      43,  7, 60,  7, 15, 15, mysMaxAcsSize, @Config.AcsValidate, Topic + '');
  Form.AddStr  ('X', ' See Unvalidated',    41,  8, 60,  8, 17, 15, mysMaxAcsSize, @Config.AcsSeeUnvalid, Topic + '');
  Form.AddStr  ('X', ' DL Unvalidated',     42,  9, 60,  9, 16, 15, mysMaxAcsSize, @Config.AcsDLUnvalid, Topic + '');
  Form.AddStr  ('X', ' See Failed',         46, 10, 60, 10, 12, 15, mysMaxAcsSize, @Config.AcsSeeFailed, Topic + '');
  Form.AddStr  ('X', ' DL Failed',          47, 11, 60, 11, 11, 15, mysMaxAcsSize, @Config.AcsDLFailed, Topic + '');
  Form.AddLong ('X', ' Min Upload Space',   40, 12, 60, 12, 18,  9, 0, 999999999, @Config.FreeUL, Topic + '');
  Form.AddLong ('X', ' Min CD-ROM Space',   40, 13, 60, 13, 18,  9, 0, 999999999, @Config.FreeCDROM, Topic + '');

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

End.

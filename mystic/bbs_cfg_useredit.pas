Unit bbs_Cfg_UserEdit;

Interface

Uses
  BBS_Records;

Procedure Configuration_EditUser       (Var U: RecUser);
Procedure Configuration_UserEditor;
Procedure Configuration_LocalUserEdit;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_io,
  bbs_Core,
  bbs_General,
  BBS_Common,
  BBS_DataBase,
  BBS_Cfg_SecLevel,
  BBS_Cfg_QwkNet;

Procedure Configuration_EditUser (Var U: RecUser);
Var
  Box      : TAnsiMenuBox;
  Form     : TAnsiMenuForm;
  BoxImage : TConsoleImageRec;
  PagePos  : Byte = 1;
  Topic    : String;
  Changed  : Boolean = False;
  NeedForm : Boolean = False;

  Procedure UpdatePage (Restore: Boolean);
  Begin
    If Restore Then Session.io.RemoteRestore(BoxImage);

    VerticalLine (21, 6, 20);

    WriteXY (62,  6, 112, 'Information');
    WriteXY (63,  7, 112, 'Settings 1');
    WriteXY (63,  8, 112, 'Settings 2');
    WriteXY (63,  9, 112, 'Statistics');
    WriteXY (60, 10, 112, 'Optional Data');
    WriteXY (68, 11, 112, 'Flags');

    WriteXY (59, 13, 120, 'CTRL-U/Upgrade');

    WriteXY (65, 20, 112, 'Page ' + strI2S(PagePos) + '/6');

    Case PagePos of
      1 : WriteXY (62,  6, 127, 'INFORMATION');
      2 : WriteXY (63,  7, 127, 'SETTINGS 1');
      3 : WriteXY (63,  8, 127, 'SETTINGS 2');
      4 : WriteXY (63,  9, 127, 'STATISTICS');
      5 : WriteXY (60, 10, 127, 'OPTIONAL DATA');
      6 : WriteXY (68, 11, 127, 'FLAGS');
    End;

    NeedForm := True;
  End;

Var
  Birthdate : String[8];
  FirstCall : String[8];
  LastCall  : String[8];
  Temp      : Integer;
  SavedUser : RecUser;
  QwkNet    : RecQwkNetwork;
Begin
  Topic     := '|03(|09User Editor|03) |01-|09> |15';
  SavedUser := U;

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Header       := ' ' + U.Handle + ' (ID ' + strI2S(U.PermIdx) + ') ';
  Form.LoExitChars := #21;
  Form.HiExitChars := #71#73#79#81;

  Box.Open (6, 5, 74, 21);

  Console.GetScreenImage (6, 5, 74, 21, BoxImage);

  Birthdate := DateJulian2Str(U.Birthday, 1);
  FirstCall := DateDos2Str(U.FirstOn, 1);
  LastCall  := DateDos2Str(U.LastOn, 1);

  UpdatePage(False);

  Repeat
    Form.ExitOnFirst := True;
    Form.ExitOnLast  := True;

    Case PagePos of
      1 : Form.ExitOnFirst := False;
      6 : Form.ExitOnLast  := False;
    End;

    If NeedForm Then
    Case PagePos of
      1 : Begin
            WriteXY ( 8, 19, 112, 'Caller ID');
            WriteXY (23, 19, 113, U.PeerHost);
            WriteXY (23, 20, 113, U.PeerIP);

            Form.Clear;

            Form.AddStr  ('H', ' Handle'    ,  7,  6, 23,  6, 14, 30, 30, @U.Handle, Topic + 'User''s account handle');
            Form.AddStr  ('R', ' Real Name' ,  7,  7, 23,  7, 14, 30, 30, @U.RealName, Topic + 'User''s real name');
            Form.AddPass ('W', ' Password'  ,  7,  8, 23,  8, 14, 20, 20, @U.Password, Topic + 'User''s password');
            Form.AddStr  ('A', ' Address'   ,  7,  9, 23,  9, 14, 30, 30, @U.Address, Topic + 'User''s street address');
            Form.AddStr  ('C', ' City'      ,  7, 10, 23, 10, 14, 25, 25, @U.City, Topic + 'User''s city and state');
            Form.AddStr  ('Z', ' Zip Code'  ,  7, 11, 23, 11, 14, 10, 10, @U.ZipCode, Topic + 'User''s postal code');
            Form.AddStr  ('P', ' Home Phone',  7, 12, 23, 12, 14, 15, 15, @U.HomePhone, Topic + 'User''s home phone number');
            Form.AddStr  ('O', ' Data Phone',  7, 13, 23, 13, 14, 15, 15, @U.DataPhone, Topic + 'User''s data phone number');
            Form.AddStr  ('E', ' E-Mail'    ,  7, 14, 23, 14, 14, 40, 40, @U.Email, Topic + 'User''s email address');
            Form.AddStr  ('U', ' User Note' ,  7, 15, 23, 15, 14, 40, 40, @U.UserInfo, Topic + 'User''s user note');
            Form.AddChar ('G', ' Gender'    ,  7, 16, 23, 16, 14, 32, 254, @U.Gender, Topic + 'User''s gender. M/Male, F/Female');
            Form.AddDate ('B', ' Birthdate' ,  7, 17, 23, 17, 14, @Birthdate, Topic + 'User''s birthdate (MM/DD/YY)');
          End;
      2 : Begin
            Form.Clear;

            Form.AddByte ('S', ' Security'  , 7,  6, 23,  6, 14,  3, 0, 255, @U.Security, Topic + 'User''s security level');
            Form.AddFlag ('1', ' Flags #1'  , 7,  7, 23,  7, 14, @U.AF1, Topic + 'User''s access flags: Set 1');
            Form.AddFlag ('2', ' Flags #2'  , 7,  8, 23,  8, 14, @U.AF2, Topic + 'User''s access flags: Set 2');
            Form.AddWord ('T', ' Time Left' , 7,  9, 23,  9, 14, 4, 0, 1440, @U.TimeLeft, Topic + 'Total number of minutes left for today');
            Form.AddWord ('I', ' Time Bank' , 7, 10, 23, 10, 14,  5, 0, 65000, @U.TimeBank, Topic + 'Total minutes in time bank');
            Form.AddDate ('X', ' Expires'   , 7, 11, 23, 11, 14, @U.Expires, Topic + 'User''s account expiration date (00/00/00: Disabled)');
            Form.AddByte ('O', ' To'        , 7, 12, 23, 12, 14, 3, 0, 255, @U.ExpiresTo, Topic + 'Security profile to give user after expiration');
            Form.AddStr  ('T', ' Theme'     , 7, 13, 23, 13, 14, 20,  20, @U.Theme, Topic + 'Filename of user''s theme');
            Form.AddStr  ('A', ' Start Menu', 7, 14, 23, 14, 14, 20, 20, @U.StartMenu, Topic + 'User is sent to this menu after logging in');
            Form.AddStr  ('V', ' Archive'   , 7, 15, 23, 15, 14,  4,  4, @U.Archive, Topic + 'User''s archive type extension');
            Form.AddChar ('P', ' Protocol'  , 7, 16, 23, 16, 14, 32, 96, @U.Protocol, Topic + 'Default protocol hotkey');
            Form.AddByte ('C', ' Screensize', 7, 17, 23, 17, 14,  2,  0, 50, @U.ScreenSize, Topic + 'User''s terminal size in lines');
            Form.AddBol  ('K', ' Hot Keys'  , 7, 18, 23, 18, 14,  3,  @U.HotKeys, Topic + 'User''s hotkey input status');
            Form.AddBol  ('U', ' Auto-Sig'  , 7, 19, 23, 19, 14,  3,  @U.SigUse, Topic + 'Use auto signature?');
            Form.AddBol  ('Q', ' QWK Files' , 7, 20, 23, 20, 14,  3,  @U.QwkFiles, Topic + 'New files in QWK?');
          End;
      3 : Begin
            Form.Clear;

            Form.AddTog  ('D', ' Date Format' , 7,  6, 23,  6, 14,  8,  1,  3, 'MM/DD/YY DD/MM/YY YY/MM/DD', @U.DateType, Topic + 'User''s date format');
            Form.AddTog  ('E', ' FS Editor'   , 7,  7, 23,  7, 14,  4,  0,  1, 'Line Full', @U.EditType, Topic + 'User''s full screen editor setting');
            Form.AddBol  ('Q', ' Quote Window', 7,  8, 23,  8, 14,  3,  @U.UseLBQuote, Topic + 'User''s FS editor quote window status');
            Form.AddTog  ('F', ' File Listing', 7,  9, 23,  9, 14,  8,  0,  1, 'Standard Full', @U.FileList, Topic + 'User''s file listing type');
            Form.AddTog  ('M', ' Msg Reader'  , 7, 10, 23, 10, 14,  8,  0,  1, 'Standard Full', @U.MReadType, Topic + 'Full screen message reader status');
            Form.AddBol  ('X', ' Msg Index'   , 7, 11, 23, 11, 14,  3,  @U.UseLBIndex, Topic + 'Start reading at message index');
            Form.AddBol  ('I', ' Mail Index'  , 7, 12, 23, 12, 14,  3,  @U.UseLBMIdx, Topic + 'Start reading email at message index');
            Form.AddTog  ('N', ' Node Chat'   , 7, 13, 23, 13, 14,  8,  0,  1, 'Standard Full', @U.UseFullChat, Topic + 'User''s node chat type');
            Form.AddTog  ('C', ' Code Page'   , 7, 14, 23, 14, 14,  5,  0,  1, 'CP437 UTF-8', @U.CodePage, Topic + 'User''s character translation');
            Form.AddBol  ('Q', ' QWKE Packet' , 7, 15, 23, 15, 14,  3,  @U.QwkExtended, Topic + 'Use QWKE (instead of QWK)');
          End;
      4 : Begin
            Form.Clear;

            Form.AddDate ('F', ' First Call'    ,  7,  6, 23,  6, 14, @FirstCall, Topic + 'Date of first call (MM/DD/YY)');
            Form.AddDate ('A', ' Last Call'     ,  7,  7, 23,  7, 14, @LastCall, Topic + 'Date of last call (MM/DD/YY)');
            Form.AddLong ('C', ' Calls'         ,  7,  8, 23,  8, 14,  7, 0, 9999999, @U.Calls, Topic + 'Total number of calls to the BBS');
            Form.AddWord ('L', ' Calls Today'   ,  7,  9, 23,  9, 14,  5, 0, 65000, @U.CallsToday, Topic + 'Total number of calls today');
            Form.AddWord ('D', ' Downloads'     ,  7, 10, 23, 10, 14,  7, 0, 65000, @U.DLs, Topic + 'Total number of downloads');
            Form.AddWord ('T', ' DLs Today'     ,  7, 11, 23, 11, 14,  5, 0, 65000, @U.DLsToday, Topic + 'Total downloads today');
            Form.AddLong ('W', ' DL KB'         ,  7, 12, 23, 12, 14, 10, 0, 2000000000, @U.DLk, Topic + 'Total downloads in kilobytes');
            Form.AddLong ('K', ' DL KB Today'   ,  7, 13, 23, 13, 14, 10, 0, 2000000000, @U.DLkToday, Topic + 'Downloads in kilobytes today');
            Form.AddLong ('U', ' Uploads'       ,  7, 14, 23, 14, 14, 10, 0, 2000000000, @U.ULs, Topic + 'Total number of uploads');
            Form.AddLong ('B', ' Upload KB'     ,  7, 15, 23, 15, 14, 10, 0, 2000000000, @U.ULk, Topic + 'Total uploads in kilobytes');
            Form.AddLong ('M', ' Msg Posts'     ,  7, 16, 23, 16, 14, 10, 0, 2000000000, @U.Posts, Topic + 'Total number of message posts');
            Form.AddLong ('E', ' E-Mails'       ,  7, 17, 23, 17, 14,  5, 0, 65000, @U.Emails, Topic + 'Number of e-mails sent');
            Form.AddLong ('I', ' File Ratings'  ,  7, 18, 23, 18, 14, 10, 0, 2000000000, @U.FileRatings, Topic + 'Total file ratings');
            Form.AddLong ('N', ' File Comments' ,  7, 19, 23, 19, 14, 10, 0, 2000000000, @U.FileComment, Topic + 'Total file comments');
            Form.AddDate ('P', ' Last PW Date'  ,  7, 20, 23, 20, 14, @U.LastPWChange, Topic + 'Date of last password change');
          End;
      5 : Begin
            Form.Clear;

            For Temp := 1 to 9 Do
              Form.AddStr (strI2S(Temp)[1], ' ' + bbsCfg.OptionalField[Temp].Desc, 7, 5 + Temp, 23, 5 + Temp, 14, 33, 60, @U.OptionData[Temp], Topic + 'User optional field #' + strI2S(Temp));

            Form.AddStr ('0', ' ' + bbsCfg.OptionalField[10].Desc, 7, 15, 23, 15, 14, 33, 60, @U.OptionData[10], Topic + 'User optional field #10');
          End;
      6 : Begin
            Form.Clear;

            Form.AddBits ('D', ' Deleted'     , 7,  6, 23,  6, 14, UserDeleted,    @U.Flags, Topic + 'Is this account marked as deleted?');
            Form.AddBits ('L', ' Locked Out'  , 7,  7, 23,  7, 14, UserLockedOut,  @U.Flags, Topic + 'Is this account locked out of the system?');
            Form.AddBits ('N', ' No Ratios'   , 7,  8, 23,  8, 14, UserNoRatio,    @U.Flags, Topic + 'Ignore file ratios?');
            Form.AddBits ('C', ' No CallStats', 7,  9, 23,  9, 14, UserNoLastCall, @U.Flags, Topic + 'Exclude from caller stats?');
            Form.AddBits ('P', ' No PW Change', 7, 10, 23, 10, 14, UserNoPWChange, @U.Flags, Topic + 'Exclude from forced password change');
            Form.AddBits ('H', ' No History'  , 7, 11, 23, 11, 14, UserNoHistory,  @U.Flags, Topic + 'Exclude from BBS history stats');
            Form.AddBits ('T', ' No Timeout'  , 7, 12, 23, 12, 14, UserNoTimeout,  @U.Flags, Topic + 'Exclude from inactivity timeout');
            Form.AddBits ('Q', ' Qwk Account' , 7, 13, 23, 13, 14, UserQWKNetwork, @U.Flags, Topic + 'User is a QWK network account');
            Form.AddNone ('N', ' Qwk Network' , 7, 14, 23, 14, 14, Topic + 'Member of which QWK network');
          End;
    End;

    NeedForm := False;

    If Form.WasFirstExit Then Form.ItemPos := Form.Items;
    If Form.WasLastExit  Then Form.ItemPos := 1;

    If PagePos = 6 Then Begin
      QwkNet.Description := 'None';

      If (U.QwkNetwork <> 0) And (Not GetQwkNetByIndex(U.QwkNetwork, QwkNet)) Then
        QwkNet.Description := 'None';

      WriteXY (23, 14, 113, strPadR(QwkNet.Description, 30, ' '));
    End;

    Case Form.Execute of
      'N' : U.QwkNetwork := Configuration_QwkNetworks(False);
      #21 : Begin
              Temp := Configuration_SecurityEditor(False);

              If Temp <> -1 Then Begin
                NeedForm := True;
                Changed  := True;

                Upgrade_User_Level(Session.User.IsThisUser(U.Handle), U, Temp);
              End;
            End;
      #27 : Begin
              Changed := Changed or Form.Changed;
              Break;
            End;
      #71 : If PagePos <> 1 Then Begin
              PagePos := 1;
              UpdatePage(True);
            End;
      #72,
      #73 : If PagePos > 1 Then Begin
              Dec(PagePos);
              UpdatePage(True);
            End;
      #79 : If PagePos <> 6 Then Begin
              PagePos := 6;
              UpdatePage(True);
            End;
      #80,
      #81 : If PagePos < 6 Then Begin
              Inc (PagePos);
              UpdatePage(True);
            End Else
              Form.ItemPos := Form.Items;
    End;

    Changed := Changed or Form.Changed;
  Until False;

  U.Birthday := DateStr2Julian(Birthdate);
  U.FirstOn  := DateStr2Dos(FirstCall);
  U.LastOn   := DateStr2Dos(LastCall);

  Box.Close;
  Box.Free;
  Form.Free;

  If Changed Then
    If Not ShowMsgBox(1, 'Save changes?') Then
      U := SavedUser;
End;

Procedure Configuration_UserEditor;
Var
  Box      : TAnsiMenuBox;
  List     : TAnsiMenuList;
  UserFile : File of RecUser;
  User     : RecUser;

  Procedure MakeList;
  Begin
    List.Clear;

    ioReset (UserFile, SizeOf(RecUser), fmRWDN);

    While Not EOF(UserFile) Do Begin
      Read (UserFile, User);

      If User.Flags AND UserDeleted <> 0 Then
        List.Add (strPadR(User.Handle, 37, ' ') + 'DELETED', 0)
      Else
        List.Add (strPadR(User.Handle, 32, ' ') +
                  strPadL(strI2S(User.Security), 5, ' ') +
                  strPadL(strI2S(User.PermIdx), 10, ' '), 0);
    End;
  End;

Begin
  Assign (UserFile, bbsCfg.DataPath + 'users.dat');

  If Not ioReset(UserFile, SizeOf(RecUser), fmRWDN) Then
    If (FileExist(bbsCfg.DataPath + 'users.dat')) OR NOT
       (ioReWrite(UserFile, SizeOf(RecUser), fmRWDN)) Then
         Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27;

  Box.Header := ' User Editor ';

  Box.Open (15, 5, 65, 21);

  WriteXY (17, 7, 112, 'User Name                       Level    UserID');
  WriteXY (16, 8, 112,  strRep(#196, 49));

  Repeat
    MakeList;

    List.Open (15, 8, 65, 21);
    List.Close;

    Case List.ExitCode of
      #13 : If List.ListMax <> 0 Then Begin
              Seek (UserFile, List.Picked - 1);
              Read (UserFile, User);

              Configuration_EditUser(User);

              Seek  (UserFile, List.Picked - 1);
              Write (UserFile, User);
            End;
      #27 : Break;
    End;
  Until False;

  Close (UserFile);

  Box.Close;
  List.Free;
  Box.Free;
End;

Procedure Configuration_LocalUserEdit;
Var
  SavedLocal : Boolean;
Begin
  Session.io.BufFlush;

  SavedLocal := Session.LocalMode;

  Session.InUserEdit := True;
  Session.LocalMode  := True;

  Configuration_EditUser (Session.User.ThisUser);

  Console.WriteXY (1, 24, 7, strRep(' ', 80));

  Session.InUserEdit := False;
  Session.LocalMode  := SavedLocal;

  Session.SetTimeLeft(Session.User.ThisUser.TimeLeft);

  {$IFNDEF UNIX}
    UpdateStatusLine(Session.StatusPtr, '');
  {$ENDIF}
End;

End.

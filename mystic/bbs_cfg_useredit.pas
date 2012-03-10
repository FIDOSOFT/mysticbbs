Unit bbs_cfg_UserEdit;

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_DateTime,
  m_Strings,
  bbs_Common,
  bbs_Core;

Procedure User_Editor (LocalEdit, OneUser : Boolean);

Implementation

Uses
  bbs_User,
  bbs_NodeInfo,
  bbs_General;

Procedure User_Editor (LocalEdit, OneUser : Boolean);
Const
        ModeTypeStr : Array[0..1] of String[8] = ('Standard', 'Lightbar');
        More        : Boolean = False;
Var
        ValidStr  : String;
        UserNode  : Word;
        LocalSave : Boolean;
        Image     : TConsoleImageRec;
        Str       : String;
        A         : LongInt;
Begin
        Reset (Session.User.UserFile);

        If Eof(Session.User.UserFile) Then Begin
                Close (Session.User.UserFile);
                Exit;
        End;

        Session.SystemLog ('*USER EDIT*');

        Session.InUserEdit := True;

  {$IFNDEF UNIX}
        If LocalEdit Then Begin
                Screen.GetScreenImage(1, 1, 80, 25, Image);
                LocalSave := Session.LocalMode;
                Session.LocalMode := True;
                Session.User.TempUser := Session.User.ThisUser;
        End;
  {$ENDIF}

        If Not OneUser Then Begin
                Read (Session.User.UserFile, Session.User.TempUser);

                If Session.User.UserNum = FilePos(Session.User.UserFile) Then
                        Session.User.TempUser := Session.User.ThisUser;
        End;

  Repeat
                UserNode := IsUserOnline(Session.User.TempUser.Handle);

    Session.io.OutFull ('|16|CL|14User Editor: ' + strI2S(FilePos(Session.User.UserFile)) + ' of ' + strI2S(FileSize(Session.User.UserFile)) +
                                        ' |03(Idx: ' + strI2S(Session.User.TempUser.PermIdx) + ')');

                If UserNode > 0 Then
                        Session.io.OutFull (' |10(On Node ' + strI2S(UserNode) + ')');

    If LocalEdit Then
      Session.io.OutFullLn (' |12(Local Display)')
    Else
      Session.io.OutRawLn ('');

    Session.io.OutFullLn ('|08|$D79Ä|03');

                If More Then Begin
                        Session.io.OutFullLn ('|12Additional settings for ' + Session.User.TempUser.Handle + ':|03|CR');

                        Session.io.OutRawLn ('A. Full NodeChat ' + Session.io.OutYN(Session.User.TempUser.UseFullChat));
                        Session.io.OutRawLn ('B. Expires Date  ' + Session.User.TempUser.Expires);
                        Session.io.OutRawLn ('C. Expires To    ' + strI2S(Session.User.TempUser.ExpiresTo));

            For A := 1 to 10 Do Session.io.OutRawLn('');

            Session.io.OutFullLn ('|10(1)|08|$D24Ä|10(2)|08|$D23Ä|10(3)|08|$D23Ä|03');

            Session.io.OutRawLn ('Calls        ' + strPadR(strI2S(Session.User.TempUser.Calls), 14, ' ') +
                    'First Call  ' + strPadR(DateDos2Str(Session.User.TempUser.FirstOn, Session.User.ThisUser.DateType), 14, ' ') +
                  'Msg Posts   ' + strI2S(Session.User.TempUser.Posts));
            Session.io.OutRawLn ('Calls Today  ' + strPadR(strI2S(Session.User.TempUser.CallsToday), 14, ' ') +
                    'Last Call   ' + strPadR(DateDos2Str(Session.User.TempUser.LastOn, Session.User.ThisUser.DateType), 14, ' ') +
                  'Sent Email  ' + strI2S(Session.User.TempUser.Emails));
            Session.io.OutRawLn ('Downloads    ' + strPadR(strI2S(Session.User.TempUser.DLs), 14, ' ') +
                    'Download K  ' + strPadR(strI2S(Session.User.TempUser.DLk), 14, ' ') +
                  'Uploads     ' + strI2S(Session.User.TempUser.ULs));
            Session.io.OutRawLn ('DLs Today    ' + strPadR(strI2S(Session.User.TempUser.DLsToday), 14, ' ') +
                    'DLk Today   ' + strPadR(strI2S(Session.User.TempUser.DLkToday), 14, ' ') +
                  'Upload KB   ' + strI2S(Session.User.TempUser.ULk));

                        Session.io.OutFullLn ('|08|$D79Ä');
            Session.io.OutFull   ('|09(Q)uit: ');

                        If UserNode > 0 Then
                                ValidStr := 'Q'
                        Else
                                ValidStr := 'ABC123Q';

                        Case Session.io.OneKey(ValidStr, True) of
                                'A' : Session.User.TempUser.UseFullChat := Not Session.User.TempUser.UseFullChat;
                                'B' : Session.User.TempUser.Expires := Session.io.InXY(18, 6, 8, 8, 5, Session.User.TempUser.Expires);
                                'C' : Session.User.TempUser.ExpiresTo := strS2I(Session.io.InXY(18, 7, 3, 3, 1, strI2S(Session.User.TempUser.ExpiresTo)));
                                'Q' : More := False;
              '1' : Begin
                    Session.User.TempUser.Calls      := strS2I(Session.io.InXY(14, 17, 5, 5, 12, strI2S(Session.User.TempUser.Calls)));
                  Session.User.TempUser.CallsToday := strS2I(Session.io.InXY(14, 18, 5, 5, 12, strI2S(Session.User.TempUser.CallsToday)));
                Session.User.TempUser.DLs        := strS2I(Session.io.InXY(14, 19, 5, 5, 12, strI2S(Session.User.TempUser.DLs)));
                      Session.User.TempUser.DLsToday   := strS2I(Session.io.InXY(14, 20, 5, 5, 12, strI2S(Session.User.TempUser.DLsToday)));
                  End;
          '2' : Begin
                Session.User.TempUser.FirstOn  := DateStr2Dos(Session.io.InXY(40, 17, 8, 8, 15, DateDos2Str(Session.User.TempUser.FirstOn, Session.User.ThisUser.DateType)));
                      Session.User.TempUser.LastOn   := DateStr2Dos(Session.io.InXY(40, 18, 8, 8, 15, DateDos2Str(Session.User.TempUser.LastOn, Session.User.ThisUser.DateType)));
                    Session.User.TempUser.DLK      := strS2I(Session.io.InXY(40, 19, 10, 10, 12, strI2S(Session.User.TempUser.DLK)));
                      Session.User.TempUser.DLKToday := strS2I(Session.io.InXY(40, 20, 10, 10, 12, strI2S(Session.User.TempUser.DLKToday)));
                  End;
          '3' : Begin
                Session.User.TempUser.Posts  := strS2I(Session.io.InXY(66, 17, 10, 10, 12, strI2S(Session.User.TempUser.Posts)));
                      Session.User.TempUser.Emails := strS2I(Session.io.InXY(66, 18, 10, 10, 12, strI2S(Session.User.TempUser.Emails)));
                    Session.User.TempUser.ULS    := strS2I(Session.io.InXY(66, 19, 10, 10, 12, strI2S(Session.User.TempUser.ULS)));
                  Session.User.TempUser.ULK    := strS2I(Session.io.InXY(66, 20, 10, 10, 12, strI2S(Session.User.TempUser.ULK)));
              End;
                        End;
                End Else Begin
                        Session.io.OutRawLn ('A.      Alias  ' + strPadR(Session.User.TempUser.Handle, 32, ' ') +
                                                                'V.  Start Menu  ' + Session.User.TempUser.StartMeNU);

                        Session.io.OutRawLn ('B.  Real Name  ' + strPadR(Session.User.TempUser.RealName, 32, ' ') +
                                                                'W.    Language  ' + Session.User.TempUser.Theme);

                        Session.io.OutRawLn ('C.    Address  ' + strPadR(Session.User.TempUser.Address, 32, ' ') +
                                                                'X.    Hot Keys  ' + Session.io.OutYN(Session.User.TempUser.HotKeys));

                        Session.io.OutRawLn ('D.       City  ' + strPadR(Session.User.TempUser.City, 32, ' ') +
                                                                'Y.   Date Type  ' + DateTypeStr[Session.User.TempUser.DateType]);

                        Session.io.OutRawLn ('E.   Zip Code  ' + strPadR(Session.User.TempUser.ZipCode, 32, ' ') +
                                                                'Z.  FList Type  ' + ModeTypeStr[Session.User.TempUser.FileList]);

                        Session.io.OutRaw   ('F.  Birthdate  ' + DateJulian2Str(Session.User.TempUser.Birthday, Session.User.ThisUser.DateType) +
                                                                ' - Age ' + strPadR(strI2S(DaysAgo(Session.User.TempUser.Birthday) DIV 365), 17, ' ') +
                                                                '1.  Msg Editor  ');

            Case Session.User.TempUser.EditType of
            0 : Session.io.OutRawLn ('Line');
          1 : Session.io.OutRawLn ('Full');
              2 : Session.io.OutRawLn ('Ask');
            End;

                        Session.io.OutRawLn ('G.     Gender  ' + strPadR(Session.User.TempUser.Gender, 32, ' ') +
                                                                '2.   Msg Quote  ' + ModeTypeStr[Ord(Session.User.TempUser.UseLBQuote)]);

                        Session.io.OutRawLn ('H. Home Phone  ' + strPadR(Session.User.TempUser.HomePhone, 32, ' ') +
                                                                '3.  Msg Reader  ' + ModeTypeStr[Session.User.TempUser.MReadType]);

                        Session.io.OutRawLn ('I. Data Phone  ' + strPadR(Session.User.TempUser.DataPhone, 32, ' ') +
                                                                '4.       Index  ' + Session.io.OutYN(Session.User.TempUser.UseLBIndex));

                        Session.io.OutRawLn ('J.     E-mail  ' + strPadR(Session.User.TempUser.Email, 32, ' ') +
                                                                '5.  Mail Index  ' + Session.io.OutYN(Session.User.TempUser.UseLBMIdx));

                        Session.io.OutRawLn ('K. ' + strPadL(Config.OptionalField[1].Desc, 10, ' ') + '  ' + strPadR(Session.User.TempUser.OptionData[1], 32, ' ') +
                                                                '6.   Time Left  ' + strI2S(Session.User.TempUser.TimeLeft));

                        Session.io.OutRawLn ('L. ' + strPadL(Config.OptionalField[2].Desc, 10, ' ') + '  ' + strPadR(Session.User.TempUser.OptionData[2], 32, ' ') +
                                                                '7.   Time Bank  ' + strI2S(Session.User.TempUser.TimeBank));

                        Session.io.OutRawLn ('N. ' + strPadL(Config.OptionalField[3].Desc, 10, ' ') + '  ' + strPadR(Session.User.TempUser.OptionData[3], 32, ' ') +
                                                                '8. Screen Size  ' + strI2S(Session.User.TempUser.ScreenSize));

                        Session.io.OutRawLn ('O.  User Note  ' + strPadR(Session.User.TempUser.UserInfo, 32, ' ') +
                                                                '!.   Ignore LC  ' + Session.io.OutYN(Session.User.TempUser.Flags AND UserNoCaller <> 0));

                        Session.io.OutRawLn ('P.   Security  ' + strPadR(strI2S(Session.User.TempUser.Security), 36, ' ') +
                                                                'Locked out  ' + Session.io.OutYN(Session.User.TempUser.Flags AND UserLockedOut <> 0));

                        Session.io.OutRawLn ('R.   Password  ' + strPadR(strRep('*', Length(Session.User.TempUser.Password)), 39, ' ') +
                                                                'Deleted  ' + Session.io.OutYN(Session.User.TempUser.Flags AND UserDeleted <> 0));

                        Session.io.OutRawLn ('S.   Flags #1  ' + DrawAccessFlags(Session.User.TempUser.AF1) + '           ' +
                                                                'No Delete  ' + Session.io.OutYN(Session.User.TempUser.Flags AND UserNoKill <> 0));

                        Session.io.OutRawLn ('T.   Flags #2  ' + DrawAccessFlags(Session.User.TempUser.AF2) + '           ' +
                                                                'No Ratios  ' + Session.io.OutYN(Session.User.TempUser.Flags AND UserNoRatio <> 0));

                        Session.io.OutFullLn ('|08|$D79Ä');
            Session.io.OutFull   ('|09([) Prev, (]) Next, (U)pgrade, (*) Search, (M)ore, (Q)uit: ');

                        If UserNode > 0 Then
                                ValidStr := '[]*Q'
                        Else
                                ValidStr := '[]*ABCDEFGHIJKLMNOPQRSTUVWXYZ12345678!';

                        Case Session.io.OneKey(ValidStr, True) of
                                'A' : Session.User.TempUser.Handle   := Session.io.InXY(16, 3, 30, 30, 18, Session.User.TempUser.Handle);
                                'B' : Session.User.TempUser.RealName := Session.io.InXY(16, 4, 30, 30, 18, Session.User.TempUser.RealName);
                                'C' : Session.User.TempUser.Address  := Session.io.InXY(16, 5, 30, 30, 18, Session.User.TempUser.Address);
                                'D' : Session.User.TempUser.City     := Session.io.InXY(16, 6, 25, 25, 18, Session.User.TempUser.City);
                                'E' : Session.User.TempUser.ZipCode  := Session.io.InXY(16, 7,  9,  9, 12, Session.User.TempUser.ZipCode);
                                'F' : Session.User.TempUser.Birthday     := DateStr2Julian(Session.io.InXY (16, 8, 8, 8, 15, DateJulian2Str(Session.User.TempUser.Birthday, Session.User.ThisUser.DateType)));
                                'G' : If Session.User.TempUser.Gender = 'M' Then Session.User.TempUser.Gender := 'F' Else Session.User.TempUser.Gender := 'M';
                                'H' : Session.User.TempUser.HomePhone := Session.io.InXY (16, 10, 15, 15, 12, Session.User.TempUser.HomePhone);
                                'I' : Session.User.TempUser.DataPhone := Session.io.InXY (16, 11, 15, 15, 12, Session.User.TempUser.DataPhone);
                                'J' : Session.User.TempUser.Email     := Session.io.InXY (16, 12, 30, 35, 11, Session.User.TempUser.Email);
                                'K' : Session.User.TempUser.OptionData[1]   := Session.io.InXY (16, 13, 30, 35, 11, Session.User.TempUser.OptionData[1]);
                                'L' : Session.User.TempUser.OptionData[2]   := Session.io.InXY (16, 14, 30, 35, 11, Session.User.TempUser.OptionData[2]);
                                'N' : Session.User.TempUser.OptionData[3]   := Session.io.InXY (16, 15, 30, 35, 11, Session.User.TempUser.OptionData[3]);
                                'O' : Session.User.TempUser.UserInfo  := Session.io.InXY (16, 16, 30, 30, 11, Session.User.TempUser.UserInfo);
                                'P' : Begin
                                        Session.User.TempUser.Security := strS2I(Session.io.InXY(16, 17,  3,  3, 12, strI2S(Session.User.TempUser.Security)));
                                        If (Session.User.TempUser.Security > 255) or (Session.User.TempUser.Security < 0) Then Session.User.TempUser.Security := 0;
                                      End;
                                'R' : Session.User.TempUser.Password := Session.io.InXY (16, 18, 15, 15, 12, Session.User.TempUser.Password);
                                'S' : EditAccessFlags(Session.User.TempUser.AF1);
                                'T' : EditAccessFlags(Session.User.TempUser.AF2);
                                'V' : Session.User.TempUser.StartMeNU := Session.io.InXY (64, 3, 8, 8, 11, Session.User.TempUser.StartMeNU);
                                'W' : Session.User.TempUser.Theme := Session.io.InXY (64, 4, 8, 8, 11, Session.User.TempUser.Theme);
                                'X' : Session.User.TempUser.HotKeys := Not Session.User.TempUser.HotKeys;
                                'Y' : If Session.User.TempUser.DateType < 3 Then Inc (Session.User.TempUser.DateType) Else Session.User.TempUser.DateType := 1;
                                'Z' : Session.User.TempUser.FileList := Ord(Not Boolean(Session.User.TempUser.FileList));
                                '1' : If Session.User.TempUser.EditType < 2 Then Inc (Session.User.TempUser.EditType) Else Session.User.TempUser.EditType := 0;
                                '2' : Session.User.TempUser.UseLBQuote := Not Session.User.TempUser.UseLBQuote;
                                '3' : Session.User.TempUser.MReadType  := Ord(Not Boolean(Session.User.TempUser.MReadType));
                                '4' : Session.User.TempUser.UseLBIndex := Not Session.User.TempUser.UseLBIndex;
                                '5' : Session.User.TempUser.UseLBMIdx  := Not Session.User.TempUser.UseLBMIdx;
                                '6' : Begin
                                        Session.User.TempUser.TimeLeft := strS2I(Session.io.InXY(64, 13, 3, 3, 12, strI2S(Session.User.TempUser.TimeLeft)));
                                        If OneUser or (Session.User.UserNum = FilePos(Session.User.UserFile)) Then
                                          Session.SetTimeLeft(Session.User.TempUser.TimeLeft);
                                      End;
                                '7' : Session.User.TempUser.TimeBank   := strS2I(Session.io.InXY(64, 14, 3, 3, 12, strI2S(Session.User.TempUser.TimeBank)));
                                '8' : Session.User.TempUser.ScreenSize := strS2I(Session.io.InXY(64, 15, 2, 2, 12, strI2S(Session.User.TempUser.ScreenSize)));
              '!' : Begin
                    Session.io.OutRaw ('(C)aller, (D)elete, (I)gnore Ratios, (L)ockOut, (N)oKill, (Q)uit: ');
                  Case Session.io.OneKey('CDILNQ', True) of
                                                                        'C' : Session.User.TempUser.Flags := Session.User.TempUser.Flags XOR UserNoCaller;
                        'D' : Session.User.TempUser.Flags := Session.User.TempUser.Flags XOR UserDeleted;
                        'I' : Session.User.TempUser.Flags := Session.User.TempUser.Flags XOR UserNoRatio;
                        'L' : Session.User.TempUser.Flags := Session.User.TempUser.Flags XOR UserLockedOut;
                                                                        'N' : Session.User.TempUser.Flags := Session.User.TempUser.Flags XOR UserNoKill;
                    End;
                End;
                                '[' : If Not OneUser Then Begin

                                                                If Session.User.UserNum = FilePos(Session.User.UserFile) Then
                                                                        Session.User.ThisUser := Session.User.TempUser;

                                                                Seek  (Session.User.UserFile, Pred(FilePos(Session.User.UserFile)));
                                                                Write (Session.User.UserFile, Session.User.TempUser);

                                                                If FilePos(Session.User.UserFile) > 1 Then Begin
                              Seek (Session.User.UserFile, FilePos(Session.User.UserFile)-2);
                            Read (Session.User.UserFile, Session.User.TempUser);
                                                                End Else Begin
                                                                        Seek (Session.User.UserFile, FileSize(Session.User.UserFile) - 1);
                                                                        Read (Session.User.UserFile, Session.User.TempUser);
                                                                End;
                                                        End;
              ']' : If Not OneUser Then Begin
                                                                If Session.User.UserNum = FilePos(Session.User.UserFile) Then
                                                                        Session.User.ThisUser := Session.User.TempUser;

                    Seek  (Session.User.UserFile, Pred(FilePos(Session.User.UserFile)));
                  Write (Session.User.UserFile, Session.User.TempUser);
                                                                If Eof(Session.User.UserFile) Then Reset(Session.User.UserFile);
                      Read  (Session.User.UserFile, Session.User.TempUser);
                                                        End;
                                '*' : If Not OneUser Then Begin
                                                                Session.io.OutFull ('User name / number: ');
                                                                Str := Session.io.GetInput(30, 30, 12, '');

                                                                If Session.User.UserNum = FilePos(Session.User.UserFile) Then
                                                                        Session.User.ThisUser := Session.User.TempUser;

                                                                A := FilePos(Session.User.UserFile) - 1;
                                                                Seek  (Session.User.UserFile, A);
                                                                Write (Session.User.UserFile, Session.User.TempUser);

           If (strS2I(Str) > 0) and (strS2I(Str) < FileSize(Session.User.UserFile)) Then
                                                                        A := strS2I(Str) - 1
                                                                Else Begin
                                                                        Reset (Session.User.UserFile);
                                                                        While Not Eof(Session.User.UserFile) Do Begin
                                                                                Read (Session.User.UserFile, Session.User.TempUser);
                                     If (Pos(Str, strUpper(Session.User.TempUser.Handle)) > 0) or (Pos(Str, strUpper(Session.User.TempUser.RealName)) > 0) Then Begin
                                                                                  Session.io.PromptInfo[1] := Session.User.TempUser.Handle;
                                                                                    If Session.io.GetYN(Session.GetPrompt(155), True) Then Begin
                                                                                                A := FilePos(Session.User.UserFile) - 1;
                                                                                                Break;
                                                                                        End;
                                                                                End;
                                                                        End;
                                                                End;

                                                                Seek (Session.User.UserFile, A);
                                                                Read (Session.User.UserFile, Session.User.TempUser);
                                                        End;
                                'M' : More := True;
                                'Q' : Break;
                                'U' : Begin
                                                                Session.io.OutFull ('|CR|09Upgrade to level (0-255): ');
                                                                A := strS2I(Session.io.GetInput(3, 3, 12, strI2S(Session.User.TempUser.Security)));
                                                                If (A > 255) or (A <= 0) Then A := 1;
                                                                Upgrade_User_Level(False, Session.User.TempUser, A);
                                                        End;
                        End;
                End;

        Until False;

        If Not OneUser Then Begin
                If Session.User.UserNum = FilePos(Session.User.UserFile) Then
                        Session.User.ThisUser := Session.User.TempUser;

          Seek  (Session.User.UserFile, Pred(FilePos(Session.User.UserFile)));
          Write (Session.User.UserFile, Session.User.TempUser);
        End;

  {$IFNDEF UNIX}
        If LocalEdit Then Begin
                Session.LocalMode := LocalSave;
                Session.User.ThisUser := Session.User.TempUser;

                Screen.PutScreenImage(Image);

                Session.SetTimeLeft (Session.User.TempUser.TimeLeft);
                UpdateStatusLine    (StatusPtr, '');
        End;
        {$ENDIF}

        Close (Session.User.UserFile);

  Session.InUserEdit := False;
End;

End.

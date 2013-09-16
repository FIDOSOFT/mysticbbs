Unit bbs_User;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  m_Strings,
  m_DateTime,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_General,
  BBS_MsgBase,
  BBS_FileBase,
  BBS_Menus,
  BBS_NodeInfo,
  MPL_Execute;

Type
  TBBSUser = Class
    UserFile     : File of RecUser;
    SecurityFile : File of RecSecurity;
    Security     : RecSecurity;
    ThisUser     : RecUser;
    TempUser     : RecUser;
    UserNum      : LongInt;
    AcsOkFlag    : Boolean;
    IgnoreGroup  : Boolean;
    InChat       : Boolean;
    MatrixOK     : Boolean;

    Constructor Create (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Procedure   InitializeUserData;
    Function    IsThisUser         (Str: String) : Boolean;
    Function    Access             (Str: String) : Boolean;
    Function    SearchUser         (Var Str : String; Real : Boolean) : Boolean;
    Function    FindUser           (Str: String; Adjust: Boolean) : Boolean;
    Function    GetMatrixUser      : Boolean;
    Procedure   DetectGraphics;
    Procedure   GetGraphics;
    Procedure   GetDateFormat      (Edit: Boolean);
    Procedure   GetAddress         (Edit: Boolean);
    Procedure   GetCityState       (Edit: Boolean);
    Procedure   GetZipCode         (Edit: Boolean);
    Procedure   GetHomePhone       (Edit: Boolean);
    Procedure   GetDataPhone       (Edit: Boolean);
    Procedure   GetBirthDate       (Edit: Boolean);
    Procedure   GetGender          (Edit: Boolean);
    Procedure   GetScreenLength    (Edit: Boolean);
    Procedure   GetPassword        (Edit: Boolean);
    Procedure   GetRealName        (Edit: Boolean);
    Procedure   GetAlias           (Edit: Boolean; Def: String);
    Procedure   GetEditor          (Edit: Boolean);
    Procedure   GetFileList        (Edit: Boolean);
    Procedure   GetMsgList         (Edit: Boolean);
    Procedure   GetHotKeys         (Edit: Boolean);
    Procedure   GetEmail           (Edit: Boolean);
    Procedure   GetUserNote        (Edit: Boolean);
    Procedure   GetOption1         (Edit: Boolean);
    Procedure   GetOption2         (Edit: Boolean);
    Procedure   GetOption3         (Edit: Boolean);
    Procedure   GetTheme;
    Procedure   UserLogon1         (Var MPE : String);
    Procedure   UserLogon2;
    Procedure   UserLogon3;
    Procedure   CreateNewUser      (DefName: String);
    Procedure   EditUserSettings   (Data: String);
    Function    Check_Trash        (Name: String) : Boolean;
  End;

Implementation

Uses
  BBS_Core;

Constructor TBBSUser.Create (Var Owner: Pointer);
Begin
  InitializeUserData;
End;

Destructor TBBSUser.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TBBSUser.InitializeUserData;
Begin
  FillChar (ThisUser, SizeOf(ThisUser), #0);
  FillChar (Security, SizeOf(Security), #0);

  UserNum              := -1;
  ThisUser.ScreenSize  := bbsCfg.DefScreenSize;
  ThisUser.Theme       := bbsCfg.DefThemeFile;
  ThisUser.StartMenu   := bbsCfg.DefStartMenu;
  ThisUser.DateType    := 1;
  ThisUser.HotKeys     := True;
  ThisUser.RealName    := 'Unknown';
  ThisUser.Handle      := ThisUser.RealName;
  ThisUser.EditType    := 1;
  ThisUser.Birthday    := CurDateJulian;
  ThisUser.Gender      := 'U';
  ThisUser.FirstOn     := CurDateDos;
  ThisUser.TimeLeft    := bbsCfg.LoginTime;
  ThisUser.Archive     := bbsCfg.qwkArchive;
  ThisUser.LastFGroup  := bbsCfg.StartFGroup;
  ThisUser.LastMGroup  := bbsCfg.StartMGroup;
  ThisUser.UseLBQuote  := True;
  ThisUser.UseFullChat := True;
  ThisUser.CodePage    := bbsCfg.StartCodePage;

  IgnoreGroup   := False;
  InChat        := False;
  AcsOkFlag     := False;
  MatrixOK      := False;
End;

Function TBBSUser.IsThisUser (Str: String) : Boolean;
Begin
  Str := strUpper(Str);

  //If Str = 'SYSOP' Then Str := bbsCfg.SysopName;

  Result := (strUpper(ThisUser.RealName) = Str) or (strUpper(ThisUser.Handle) = Str);
End;

Function TBBSUser.Access (Str: String) : Boolean;
Const
  OpCmds  = ['%', '^', '(', ')', '&', '!', '|'];
  AcsCmds = ['A', 'D', 'E', 'F', 'G', 'H', 'M', 'N', 'O', 'S', 'T', 'U', 'W', 'Z'];

Var
  Key   : Char;
  Data  : String;
  Check : Boolean;
  Out   : String;
  First : Boolean;

  Procedure CheckCommand;
  Var
    Res   : Boolean;
    Temp1 : LongInt;
    Temp2 : LongInt;
  Begin
    Res := False;

    Case Key of
      'A' : Res := DaysAgo(ThisUser.Birthday, 1) DIV 365 >= strS2I(Data);
      'D' : Res := (Ord(Data[1]) - 64) in ThisUser.AF2;
      'E' : Case Data[1] of
              '1' : Res := Session.io.Graphics = 1;
              '0' : Res := Session.io.Graphics = 0;
            End;
      'F' : Res := (Ord(Data[1]) - 64) in ThisUser.AF1;
      'G' : If IgnoreGroup Then Begin
              First := True;
              Check := False;
              Data  := '';

              Exit;
            End Else
              Res := ThisUser.LastMGroup = strS2I(Data);
      'H' : Res := strS2I(Data) < strS2I(Copy(TimeDos2Str(CurDateDos, 0), 1, 2));
      'M' : Res := strS2I(Data) < strS2I(Copy(TimeDos2Str(CurDateDos, 0), 4, 2));
      'N' : Res := strS2I(Data) = Session.NodeNum;
      'O' : Case Data[1] of
              'A' : Res := Session.Chat.Available;
              'I' : Res := Session.Chat.Invisible;
              'K' : Res := AcsOkFlag;
              'M' : Begin
                      Res := Access(Session.Msgs.MBase.SysopACS);

                      If Session.Msgs.Reading Then
                        Res := Res or IsThisUser(Session.msgs.MsgBase^.GetFrom);
                    End;
              'N' : Res := Session.LastScanHadNew;
              'P' : If (ThisUser.Calls > 0) And (ThisUser.Flags AND UserNoRatio = 0) Then Begin
                      Temp1 := Round(Security.PCRatio / 100 * 100);
                      Temp2 := Round(ThisUser.Posts / ThisUser.Calls * 100);
                      Res   := (Temp2 >= Temp1);
                    End Else
                      Res := True;
              'Y' : Res := Session.LastScanHadYou;
            End;
      'S' : Res := ThisUser.Security >= strS2I(Data);
      'T' : Res := Session.TimeLeft > strS2I(Data);
      'U' : Res := ThisUser.PermIdx = strS2I(Data);
      'W' : Res := strS2I(Data) = DayOfWeek(CurDateDos);
      'Z' : If IgnoreGroup Then Begin
              Check := False;
              First := True;
              Data  := '';

              Exit;
            End Else
              Res := strS2I(Data) = ThisUser.LastFGroup;
    End;

    If Res Then
      Out := Out + '^'
    Else
      Out := Out + '%';

    Check := False;
    First := True;
    Data  := '';
  End;

Var
  Count  : Byte;
  Paran1 : Byte;
  Paran2 : Byte;
  Ch1    : Char;
  Ch2    : Char;
  S1     : String;

Begin
  Data  := '';
  Out   := '';
  Check := False;
  Str   := strUpper(Str);
  First := True;

  For Count := 1 to Length(Str) Do
    If Str[Count] in OpCmds Then Begin
      If Check Then CheckCommand;
      Out := Out + Str[Count];
    End Else
    If (Str[Count] in AcsCmds) and (First or Check) Then Begin
      If Check Then CheckCommand;
      Key := Str[Count];
      If First Then First := False;
    End Else Begin
      Data  := Data + Str[Count];
      Check := True;

      If Count = Length(Str) Then CheckCommand;
    End;

  Out := '(' + Out + ')';

  While Pos('&', Out) <> 0 Do Delete
    (Out, Pos('&', Out), 1);

  While Pos('(', Out) <> 0 Do Begin
    Paran2 := 1;

    While ((Out[Paran2] <> ')') And (Paran2 <= Length(Out))) Do Begin
      If (Out[Paran2] = '(') Then Paran1 := Paran2;

      Inc (Paran2);
    End;

    S1 := Copy(Out, Paran1 + 1, (Paran2 - Paran1) - 1);

    While Pos('!', S1) <> 0 Do Begin
      Count := Pos('!', S1) + 1;

      If S1[Count] = '^' Then S1[Count] := '%' Else
      If S1[Count] = '%' Then S1[Count] := '^';

      Delete (S1, Count - 1, 1);
    End;

    While Pos('|', S1) <> 0 Do Begin
      Count := Pos('|', S1) - 1;
      Ch1   := S1[Count];
      Ch2   := S1[Count + 2];

      If (Ch1 in ['%', '^']) and (Ch2 in ['%', '^']) Then Begin
        Delete (S1, Count, 3);

        If (Ch1 = '^') or (Ch2 = '^') Then
          Insert ('^', S1, Count)
        Else
          Insert ('%', S1, Count)
      End Else
        Delete (S1, Count + 1, 1);
    End;

    While Pos('%%', S1) <> 0 Do Delete (S1, Pos('%%', S1), 1);
    While Pos('^^', S1) <> 0 Do Delete (S1, Pos('^^', S1), 1);
    While Pos('%^', S1) <> 0 Do Delete (S1, Pos('%^', S1) + 1, 1);
    While Pos('^%', S1) <> 0 Do Delete (S1, Pos('^%', S1), 1);

    Delete (Out, Paran1, (Paran2 - Paran1) + 1);
    Insert (S1, Out, Paran1);
  End;

  Result := (Pos('%', Out) = 0);
End;

Function TBBSUser.SearchUser (Var Str : String; Real : Boolean) : Boolean;
Var
  Found : Boolean;
  First : Boolean;
Begin
  Str := strUpper(Str);

  If Str = 'SYSOP' Then
    Str := strUpper(bbsCfg.SysopName);

  Found := False;
  First := True;

  Reset (UserFile);

  While Not Eof(UserFile) Do Begin
    Read (UserFile, TempUser);

    If (TempUser.Flags AND UserDeleted <> 0) Then Continue;

//    If (TempUser.Flags AND UserDeleted <> 0) or
//       (TempUser.Flags AND UserQWKNetwork <> 0) Then Continue;

    If Pos(Str, strUpper(TempUser.Handle)) > 0 Then Begin
      If First Then Begin
        Session.io.OutRawLn ('');
        First := False;
      End;

      Session.io.PromptInfo[1] := TempUser.Handle;

      If Session.io.GetYN (Session.GetPrompt(155), True) Then Begin
        If Real Then
          Str := TempUser.RealName
        Else
          Str := TempUser.Handle;
        Found := True;
        Break;
      End;
    End;
  End;

  Close (UserFile);

  If Not Found Then
    Session.io.OutFullLn (Session.GetPrompt(156));

  Result := Found;
End;

Function TBBSUser.FindUser (Str: String; Adjust: Boolean) : Boolean;
Var
  RecNum : LongInt;
Begin
  Result := False;

  If Str = '' Then Exit;

  Str    := strUpper(Str);
  RecNum := strS2I(Str);

  Reset (UserFile);

  While Not Eof(UserFile) Do Begin
    Read (UserFile, TempUser);

    If (((RecNum > 0) And (TempUser.PermIdx = RecNum)) or (strUpper(TempUser.RealName) = Str) or (strUpper(TempUser.Handle) = Str)) and (TempUser.Flags And UserDeleted = 0) Then Begin
      //If ExcludeQWK and (TempUser.Flags AND UserQWKNetwork <> 0) Then Continue;

      If Adjust Then UserNum := FilePos(UserFile);

      Result := True;

      Break;
    End;
  End;

  Close (UserFile);
End;

Function TBBSUser.GetMatrixUser : Boolean;
Var
  SavedNum : LongInt;
  Str      : String;
Begin
  Result := False;

  If UserNum <> -1 Then Begin
    Result := True;

    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(273));

  Str := Session.io.GetInput(30, 30, 18, '');

  If Not FindUser(Str, True) Then Exit;

  SavedNum := UserNum;
  UserNum  := -1;

  If Not Session.io.GetPW(Session.GetPrompt(274), Session.GetPrompt(293), TempUser.Password) Then Begin
    If bbsCfg.PWInquiry Then
      If Session.io.GetYN(Session.GetPrompt(475), False) Then
        Session.Msgs.PostMessage(True, '/TO:' + strReplace(bbsCfg.FeedbackTo, ' ', '_') + ' /SUBJ:Password_Inquiry');

    Session.Msgs.PostTextFile('hackwarn.txt;0;' + bbsCfg.SysopName + ';' + TempUser.Handle + ';Possible hack attempt', True);

    Exit;
  End;

  ThisUser := TempUser;
  UserNum  := SavedNum;
  Result   := True;
End;

{$IFDEF UNIX}
Procedure TBBSUser.DetectGraphics;
Var
  Loop : Byte;
Begin
  If Session.Theme.Flags AND ThmAllowANSI = 0 Then Begin
    Session.io.Graphics := 0;
    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(258));
  Session.io.BufFlush;

  Console.BufAddStr(#27 + '[6n');
  Console.BufFlush;

  For Loop := 1 to 24 Do Begin
    While Input.KeyPressed Do
      If Input.ReadKey in [#27, '[', '0'..'9', ';', 'R'] Then Begin
        Session.io.Graphics := 1;
        Break;
      End;

    If Session.io.Graphics = 1 Then Break;

    WaitMS(250);
  End;

  While Input.KeyPressed Do Loop := Byte(Input.ReadKey);

  Session.io.OutFullLn (Session.GetPrompt(259));
  Session.io.BufFlush;
End;
{$ELSE}
Procedure TBBSUser.DetectGraphics;
Var
  Loop : Byte;
Begin
  If Session.Theme.Flags AND ThmAllowANSI = 0 Then Begin
    Session.io.Graphics := 0;

    Exit;
  End;

  Session.io.OutFull (Session.GetPrompt(258));

  If Session.LocalMode Then
    Session.io.Graphics := 1
  Else Begin
    Session.Client.PurgeInputData(100);

    Session.io.OutRaw (#27 + '[6n');
    Session.io.BufFlush;

    For Loop := 1 to 6 Do Begin
      If Session.Client.WaitForData(1000) > 0 Then
        If Session.Client.ReadChar in [#27, '[', '0'..'9', ';', 'R'] Then Begin
          Session.io.Graphics := 1;

          Break;
        End;
    End;

    Session.Client.PurgeInputData(100);
  End;

  Session.io.OutFullLn (Session.GetPrompt(259));
End;
{$ENDIF}

Procedure TBBSUser.GetGraphics;
Begin
  Session.io.OutFull (Session.GetPrompt(154));

  Session.io.Graphics := strS2I(Session.io.OneKey('01', True));
End;

Procedure TBBSUser.GetEmail (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(440))
  Else
    Session.io.OutFull (Session.GetPrompt(439));

  ThisUser.EMail := Session.io.GetInput(35, 35, 11, ThisUser.Email);
End;

Procedure TBBSUser.GetUserNote (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(442))
  Else
    Session.io.OutFull (Session.GetPrompt(441));

  ThisUser.UserInfo := Session.io.GetInput(30, 30, 11, ThisUser.UserInfo);
End;

Procedure TBBSUser.GetOption1 (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(444))
  Else
    Session.io.OutFull (Session.GetPrompt(443));

  ThisUser.OptionData[1] := Session.io.GetInput(35, 35, 11, ThisUser.OptionData[1]);
End;

Procedure TBBSUser.GetOption2 (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(446))
  Else
    Session.io.OutFull (Session.GetPrompt(445));

  ThisUser.OptionData[2] := Session.io.GetInput(35, 35, 11, ThisUser.OptionData[2]);
End;

Procedure TBBSUser.GetOption3 (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(448))
  Else
    Session.io.OutFull (Session.GetPrompt(447));

  ThisUser.OptionData[3] := Session.io.GetInput(35, 35, 11, ThisUser.OptionData[3]);
End;

Procedure TBBSUser.GetEditor (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(373))
  Else
    Session.io.OutFull (Session.GetPrompt(303));

  ThisUser.EditType := strS2I(Session.io.OneKey('012', True));
End;

Function TBBSUser.Check_Trash (Name: String) : Boolean;
Var
  tFile : Text;
  Str   : String[30];
Begin
  Result := False;
  Name   := strUpper(Name);

  Assign (tFile, bbsCfg.DataPath + 'trashcan.dat');
  {$I-} Reset (tFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(tFile) Do Begin
    ReadLn (tFile, Str);

    If strUpper(Str) = Name Then Begin
      Result := True;

      Session.io.OutFullLn (Session.GetPrompt(309));

      Break;
    End;
  End;

  Close (tFile);
End;

Procedure TBBSUser.GetRealName (Edit: Boolean);
Var
  Str : String[30];
Begin
  Repeat
    Session.io.OutFull (Session.GetPrompt(6));

    Str := strStripB(Session.io.GetInput(30, 30, 18, ''), ' ');

    If Pos(' ', Str) = 0 Then Begin
      Session.io.OutFullLn (Session.GetPrompt(7));
      Str := '';
    End Else
    If Check_Trash(Str) Then
      Str := ''
    Else
    If FindUser(Str, False) Then Begin
      If Edit and (Str = ThisUser.RealName) Then Break;
      Session.io.OutFullLn (Session.GetPrompt(8));
      Str := '';
    End;
  Until Str <> '';

  ThisUser.RealName := Str;
End;

Procedure TBBSUser.GetAlias (Edit: Boolean; Def: String);
Var
  Str : String[30];
Begin
  Repeat
    Session.io.OutFull (Session.GetPrompt(9));

    Str := strStripB(Session.io.GetInput(30, 30, 18, Def), ' ');

    If Check_Trash(Str) Then
      Str := ''
    Else
    If FindUser(Str, False) Then Begin
      If Edit and (Str = ThisUser.Handle) Then Break;
      Session.io.OutFullLn (Session.GetPrompt(8));
      Str := '';
    End;
  Until Str <> '';

  ThisUser.Handle := Str;
End;

Procedure TBBSUser.GetAddress (Edit: Boolean);
Var
  Str: String[30];
Begin
  If Edit Then Str := ThisUser.Address Else Str := '';

  Repeat
    If Edit Then
      Session.io.OutFull (Session.GetPrompt(364))
    Else
      Session.io.OutFull (Session.GetPrompt(10));
    Str := Session.io.GetInput(30, 30, 18, Str);
  Until Str <> '';

  ThisUser.Address := Str;
End;

Procedure TBBSUser.GetCityState (Edit: Boolean);
Var
  Str : String[25];
Begin
  If Edit Then Str := ThisUser.City Else Str := '';

  Repeat
    If Edit Then
      Session.io.OutFull (Session.GetPrompt(365))
    Else
      Session.io.OutFull (Session.GetPrompt(11));
    Str := Session.io.GetInput(25, 25, 18, Str);
  Until Str <> '';

  ThisUser.City := Str;
End;

Procedure TBBSUser.GetZipCode (Edit: Boolean);
Var
  Str : String[9];
Begin
  If Edit Then Str := ThisUser.ZipCode Else Str := '';

  Repeat
    If Edit Then
      Session.io.OutFull (Session.GetPrompt(366))
    Else
      Session.io.OutFull (Session.GetPrompt(12));
    Str := Session.io.GetInput(9, 9, 12, Str);
  Until Str <> '';

  ThisUser.ZipCode := Str;
End;

Procedure TBBSUser.GetHomePhone (Edit: Boolean);
Var
  Str : String[15];
Begin
  If Edit Then Str := ThisUser.HomePhone Else Str := '';

  Repeat
    If Edit Then
      Session.io.OutFull (Session.GetPrompt(367))
    Else
      Session.io.OutFull (Session.GetPrompt(13));
    If bbsCfg.UseUSAPhone Then
      Str := Session.io.GetInput(12, 12, 14, Str)
    Else
      Str := Session.io.GetInput(15, 15, 12, Str);
  Until (Length(Str) = 12) or (Not bbsCfg.UseUSAPhone and (Str <> ''));

  ThisUser.HomePhone := Str;
End;

Procedure TBBSUser.GetDataPhone (Edit: Boolean);
Var
  Str : String[15];
Begin
  If Edit Then Str := ThisUser.DataPhone Else Str := '';

  Repeat
    If Edit Then
      Session.io.OutFull (Session.GetPrompt(368))
    Else
      Session.io.OutFull (Session.GetPrompt(14));
    If bbsCfg.UseUSAPhone Then
      Str := Session.io.GetInput(12, 12, 14, Str)
    Else
      Str := Session.io.GetInput(15, 15, 12, Str);
  Until (Length(Str) = 12) or (Not bbsCfg.UseUSAPhone and (Str <> ''));

  ThisUser.DataPhone := Str;
End;

Procedure TBBSUser.GetBirthDate (Edit: Boolean);
Var
  Str : String[8];
Begin
  If Edit Then Str := DateJulian2Str(ThisUser.Birthday, ThisUser.DateType) Else Str := '';
  Repeat
    If Edit Then
      Session.io.OutFull(Session.GetPrompt(369))
    Else
      Session.io.OutFull (Session.GetPrompt(15));
    Str := Session.io.GetInput(8, 8, 15, '');
  Until Length(Str) = 8;

  ThisUser.Birthday := DateStr2Julian(Str);
End;

Procedure TBBSUser.GetGender (Edit: Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(370))
  Else
    Session.io.OutFull (Session.GetPrompt(16));

  ThisUser.Gender := Session.io.OneKey('MF', True);
End;

Procedure TBBSUser.GetDateFormat (Edit : Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(371))
  Else
    Session.io.OutFull (Session.GetPrompt(152));

  ThisUser.DateType := strS2I(Session.io.OneKey('123', True));
End;

Procedure TBBSUser.GetHotKeys (Edit: Boolean);
Begin
  If Edit Then
    ThisUser.HotKeys := Session.io.GetYN(Session.GetPrompt(409), True)
  Else
    ThisUser.HotKeys := Session.io.GetYN(Session.GetPrompt(410), True);
End;

Procedure TBBSUser.GetMsgList (Edit: Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(397))
  Else
    Session.io.OutFull (Session.GetPrompt(398));

  ThisUser.MReadType := strS2I(Session.io.OneKey('01', True));
End;

Procedure TBBSUser.GetFileList (Edit: Boolean);
Begin
  If Edit Then
    Session.io.OutFull (Session.GetPrompt(374))
  Else
    Session.io.OutFull (Session.GetPrompt(320));

  ThisUser.FileList := strS2I(Session.io.OneKey('01', True));
End;

Procedure TBBSUser.GetScreenLength (Edit: Boolean);
Var
  A : Byte;
Begin
  Session.io.PromptInfo[1] := strI2S(bbsCfg.DefScreenSize);

  If Edit Then
    Session.io.OutFull (Session.GetPrompt(372))
  Else
    Session.io.OutFull (Session.GetPrompt(153));

  A := strS2I(Session.io.GetInput(2, 2, 12, strI2S(bbsCfg.DefScreenSize)));

  If (A < 1) or (A > 255) Then A := bbsCfg.DefScreenSize;

  ThisUser.ScreenSize := A;
End;

Procedure TBBSUser.GetPassword (Edit: Boolean);
Var
  Str1 : String[15];
  Str2 : String[15];
Begin
  If Edit Then Begin
    Session.io.OutFull(Session.GetPrompt(151));

    Str1 := Session.io.GetInput(15, 15, 16, '');

    If Str1 <> ThisUser.Password Then Begin
      Session.io.OutFullLn (Session.GetPrompt(418));
      Exit;
    End;
  End;

  Repeat
    Repeat
      If Edit Then
        Session.io.OutFull (Session.GetPrompt(419))
      Else
        Session.io.OutFull (Session.GetPrompt(17));

      Str1 := Session.io.GetInput(15, 15, 16, '');

      If Length(Str1) < 4 Then
        If Edit Then
          Session.io.OutFullLn (Session.GetPrompt(420))
        Else
          Session.io.OutFullLn (Session.GetPrompt(18));
    Until Length(Str1) >= 4;

    If Edit Then
      Session.io.OutFull (Session.GetPrompt(421))
    Else
      Session.io.OutFull (Session.GetPrompt(19));

    Str2 := Session.io.GetInput(15, 15, 16, '');

    If Str1 <> Str2 Then
      If Edit Then
        Session.io.OutFullLn (Session.GetPrompt(418))
      Else
        Session.io.OutFullLn (Session.GetPrompt(20));
  Until (Str1 = Str2) or (Edit);

  If Str1 = Str2 Then Begin
    ThisUser.Password     := Str1;
    ThisUser.LastPWChange := DateDos2Str(CurDateDos, 1);
  End;
End;

Procedure TBBSUser.GetTheme;
Var
  Old : RecTheme;
  T   : Byte;
  A   : Byte;
Begin
  T   := 0;
  Old := Session.Theme;

  Session.io.OutFullLn (Session.GetPrompt(182));

  Reset (Session.ThemeFile);

  Repeat
    Read (Session.ThemeFile, Session.Theme);

    If ((Session.Theme.Flags AND ThmAllowASCII = 0) and (Session.io.Graphics = 0)) or
       ((Session.Theme.Flags AND ThmAllowANSI  = 0) and (Session.io.Graphics = 1)) Then Continue;

    Inc (T);

    Session.io.PromptInfo[1] := strI2S(T);
    Session.io.PromptInfo[2] := Session.Theme.Desc;

    Session.io.OutFullLn (Session.GetPrompt(183));
  Until Eof(Session.ThemeFile);

  Session.io.OutFull (Session.GetPrompt(184));

  A := strS2I(Session.io.GetInput(2, 2, 12, ''));

  If (A < 1) or (A > T) Then A := 1;

  T := 0;

  Reset (Session.ThemeFile);

  Repeat
    Read (Session.ThemeFile, Session.Theme);

    If ((Session.Theme.Flags AND ThmAllowASCII = 0) and (Session.io.Graphics = 0)) or
       ((Session.Theme.Flags AND ThmAllowANSI  = 0) and (Session.io.Graphics = 1)) Then Continue;

    Inc (T);
  Until T = A;

  Close (Session.ThemeFile);

  If Not Session.LoadThemeData(Session.Theme.FileName) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(185));

    Session.Theme := Old;
  End Else
    ThisUser.Theme := Session.Theme.FileName;
End;

Procedure TBBSUser.CreateNewUser (DefName: String);
Begin
  If Not bbsCfg.AllowNewUsers Then Begin
    Session.io.OutFile ('nonewusr', True, 0);

    Halt(0);
  End;

  If bbsCfg.NewUserPW <> '' Then
    If Not Session.io.GetPW(Session.GetPrompt(5), Session.GetPrompt(422), bbsCfg.NewUserPW) Then Halt(0);

  Session.SystemLog ('NEW USER');

  InitializeUserData;

  Session.io.OutFile ('newuser1', True, 0);

  If ExecuteMPL (NIL, 'newuserapp') > 0 Then Begin
    If ThisUser.RealName = '' Then ThisUser.RealName := ThisUser.Handle;
    If ThisUser.Handle   = '' Then ThisUser.Handle   := ThisUser.RealName;

    If { Test validity of user data }
      FindUser(ThisUser.RealName, False) or
      FindUser(ThisUser.Handle, False) or
      (ThisUser.Password = '') or
      (ThisUser.RealName = '') or
      (ThisUser.Handle   = '')
    Then Begin
      Session.SystemLog('newuserapp.mpx does not set minimum data elements');

      Halt(1);
    End;
  End Else Begin
    If strUpper(DefName) = 'NEW' Then DefName := '';

    With bbsCfg Do Begin
      If AskTheme      Then GetTheme Else ThisUser.Theme := DefThemeFile;
      If AskAlias      Then GetAlias(False, DefName);
      If AskRealName   Then GetRealName(False);
      If AskStreet     Then GetAddress(False);
      If AskCityState  Then GetCityState(False);
      If AskZipCode    Then GetZipCode(False);
      If AskHomePhone  Then GetHomePhone(False);
      If AskDataPhone  Then GetDataPhone(False);
      If AskGender     Then GetGender(False);
      If UserDateType = 4 Then GetDateFormat(False) Else ThisUser.DateType := UserDateType;
      If AskBirthdate  Then GetBirthdate(False);
      If AskEmail      Then GetEmail(False);
      If AskUserNote   Then GetUserNote(False);
      If OptionalField[1].Ask Then GetOption1(False);
      If OptionalField[2].Ask Then GetOption2(False);
      If OptionalField[3].Ask Then GetOption3(False);
      If UserEditorType = 2 Then GetEditor(False) Else ThisUser.EditType := UserEditorType;

      If UserQuoteWin = 2 Then
        ThisUser.UseLBQuote := Session.io.GetYN(Session.GetPrompt(60), False)
      Else
        ThisUser.UseLBQuote := Boolean(UserQuoteWin);

      If UserFileList = 2 Then GetFileList(False) Else ThisUser.FileList := UserFileList;
      If UserReadType = 2 Then GetMsgList(False) Else ThisUser.MReadType := UserReadType;

      If UserReadIndex = 2 Then
        ThisUser.UseLBIndex := Session.io.GetYN(Session.GetPrompt(429), False)
      Else
        ThisUser.UseLBIndex := Boolean(UserReadIndex);

      If UserMailIndex = 2 Then
        ThisUser.UseLBMIdx := Session.io.GetYN(Session.GetPrompt(331), False)
      Else
        ThisUser.UseLBMIdx := Boolean(UserMailIndex);

      If UserFullChat = 2 Then
        ThisUser.UseFullChat := Session.io.GetYN(Session.GetPrompt(187), True)
      Else
        ThisUser.UseFullChat := Boolean(UserFullChat);

      If UserHotKeys = 2 Then GetHotKeys(False) Else ThisUser.HotKeys := Boolean(UserHotKeys);
    End;

    If bbsCfg.AskScreenSize Then
      GetScreenLength(False)
    Else
      ThisUser.ScreenSize := bbsCfg.DefScreenSize;

    Case bbsCfg.UserProtocol of
      0 : ThisUser.Protocol := #0;
      1 : ThisUser.Protocol := bbsCfg.FProtocol;
      2 : ThisUser.Protocol := Session.FileBase.SelectProtocol(False, True);
    End;

    GetPassword(False);
  End;

  Upgrade_User_Level (True, ThisUser, bbsCfg.NewUserSec);

//  ThisUser.FirstOn    := CurDateDos;
//  ThisUser.Archive    := bbsCfg.qwkArchive;
//  ThisUser.LastFBase  := 0;
//  ThisUser.LastFGroup := bbsCfg.StartFGroup;
//  ThisUser.LastMGroup := bbsCfg.StartMGroup;
//  ThisUser.LastMBase  := 0;
//  ThisUser.Flags      := 0;

  If Not bbsCfg.AskRealName Then ThisUser.RealName := ThisUser.Handle;
  If Not bbsCfg.AskAlias    Then ThisUser.Handle   := ThisUser.RealName;
  {If either handles or realnames are toggled off, fill the gaps}

  Session.Menu.MenuName := 'newinfo';
  Session.Menu.ExecuteMenu (True, False, False, True);

  Session.io.OutFullLn (Session.GetPrompt(21));

  Reset (UserFile);
  UserNum := Succ(FileSize(UserFile));

  Inc (bbsCfg.UserIdxPos);
  ThisUser.PermIdx := bbsCfg.UserIdxPos;

  Seek  (UserFile, UserNum - 1);
  Write (UserFile, ThisUser);
  Close (UserFile);

  PutBaseConfiguration(bbsCfg);

//  Reset (ConfigFile);
//  Write (ConfigFile, bbsCfg);
//  Close (ConfigFile);

  Session.SystemLog ('Created Account: ' + ThisUser.Handle);

  If bbsCfg.NewUserEmail Then Begin
    Session.io.OutFile('feedback', True, 0);
    If Session.Menu.ExecuteCommand ('MW', '/TO:' + strReplace(bbsCfg.FeedbackTo, ' ', '_') + ' /SUBJ:New_User_Feedback /F') Then;
  End;

  If FileExist(bbsCfg.ScriptPath + 'newuser.mpx') Then
    ExecuteMPL(NIL, 'newuser');

  If FileExist(bbsCfg.DataPath + 'newletter.txt') Then
    Session.Msgs.PostTextFile('newletter.txt;0;' + bbsCfg.SysopName + ';' + ThisUser.Handle + ';Welcome', True);

  If FileExist(bbsCfg.DataPath + 'sysletter.txt') Then
    Session.Msgs.PostTextFile('sysletter.txt;0;' + bbsCfg.SysopName + ';' + bbsCfg.SysopName + ';New account created', True);
End;

Procedure TBBSUser.UserLogon3;
Var
  Count : Byte;
  Ch    : Char;
Begin
  If ThisUser.Flags and UserQWKNetwork <> 0 Then Exit;

  {$IFDEF LOGGING} Session.SystemLog('Logon3'); {$ENDIF}

  Session.Chat.Available := True;

  If Access(bbsCfg.AcsInvisLogin) Then
    Session.Chat.Invisible := Session.io.GetYN(Session.GetPrompt(308), False);

{ update last caller information }

  If Not Session.LocalMode And Not Session.Chat.Invisible And (ThisUser.Flags AND UserNoLastCall = 0) Then Begin
    Reset (Session.LastOnFile);

    If FileSize(Session.LastOnFile) >= 10 Then
      KillRecord (Session.LastOnFile, 1, SizeOf(RecLastOn));

    Session.LastOn.Handle        := ThisUser.Handle;
    Session.LastOn.City          := ThisUser.City;
    Session.LastOn.Node          := Session.NodeNum;
    Session.LastOn.DateTime      := CurDateDos;
    Session.LastOn.CallNum       := bbsCfg.SystemCalls;
    Session.LastOn.Address       := ThisUser.Address;
    Session.LastOn.EmailAddr     := ThisUser.Email;
    Session.LastOn.UserInfo      := ThisUser.UserInfo;
    Session.LastOn.Gender        := ThisUser.Gender;
    Session.LastOn.PeerIP        := Session.UserIPInfo;
    Session.LastOn.PeerHost      := Session.UserHostInfo;
    Session.LastOn.NewUser       := ThisUser.Calls = 0;

    For Count := 1 to 10 Do
      Session.LastOn.OptionData[Count] := ThisUser.OptionData[Count];

    Seek  (Session.LastOnFile, FileSize(Session.LastOnFile));
    Write (Session.LastOnFile, Session.LastOn);
    Close (Session.LastOnFile);
  End;

{ update node info / settings }

  Set_Node_Action(Session.GetPrompt(345));

{ this (below) causes runtime 201 when range checking is ON }

  For Count := 1 to 9 Do
    Session.io.OutFile ('logon' + strI2S(Count), True, 0);

  Session.io.OutFile ('sl' + strI2S(ThisUser.Security), True, 0);

  For Ch := 'A' to 'Z' Do
    If Ord(Ch) - 64 in ThisUser.AF1 Then Session.io.OutFile ('flag1' + Ch, True, 0);

  For Ch := 'A' to 'Z' Do
    If Ord(Ch) - 64 in ThisUser.AF2 Then Session.io.OutFile ('flag2' + Ch, True, 0);

  If DateDos2Str(CurDateDos, 1) = DateJulian2Str(ThisUser.Birthday, 1) Then Session.io.OutFile ('birthday', True, 0);

  { Check for forced voting questions }

  Reset (Session.VoteFile);

  While Not Eof(Session.VoteFile) Do Begin
    Read (Session.VoteFile, Session.Vote);

    If Access(Session.Vote.ACS) and Access(Session.Vote.ForceACS) and (ThisUser.Vote[FilePos(Session.VoteFile)] = 0) Then Begin
      Count := FilePos(Session.VoteFile);

      Close (Session.VoteFile);

      Voting_Booth (True, Count);

      Reset (Session.VoteFile);
      Seek  (Session.VoteFile, Count);
    End;
  End;

  Close (Session.VoteFile);

  { END forced voting check }
End;

Procedure TBBSUser.UserLogon2;
Begin
  {$IFDEF LOGGING} Session.SystemLog('Logon2'); {$ENDIF}

  Reset  (SecurityFile);
  Seek   (SecurityFile, Pred(ThisUser.Security));
  Read   (SecurityFile, Security);
  Close  (SecurityFile);

  If DateDos2Str(ThisUser.LastOn, 1) <> DateDos2Str(CurDateDos, 1) Then Begin
    ThisUser.CallsToday := 0;
    ThisUser.DLsToday   := 0;
    ThisUser.DLkToday   := 0;
    ThisUser.TimeLeft   := Security.Time;
  End;

  If Not Session.LocalMode And (ThisUser.Flags AND UserNoLastCall = 0) Then Begin
    Reset (Session.ConfigFile);
    Read  (Session.ConfigFile, bbsCfg);
    Inc   (bbsCfg.SystemCalls);

    Reset (Session.ConfigFile);
    Write (Session.ConfigFile, bbsCfg);
    Close (Session.ConfigFile);
  End;

  Inc (ThisUser.Calls);
  Inc (ThisUser.CallsToday);

  If (Not Access(bbsCfg.AcsMultiLogin)) and (IsUserOnline(ThisUser.Handle) <> 0) Then Begin
    Session.io.OutFullLn(Session.GetPrompt(426));
    Halt(0);
  End;

  If ThisUser.Flags And UserLockedOut <> 0 Then Begin
    Session.io.OutFull (Session.GetPrompt(129));
    Session.SystemLog ('User has been locked out');
    Halt(0);
  End;

  If (ThisUser.CallsToday >= Security.MaxCalls) and (Security.MaxCalls > 0) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(157));
    Halt(0);
  End;

  {Find last message/file base and group}

  If ThisUser.LastMGroup > 0 Then
    Session.Msgs.MessageGroupChange (strI2S(ThisUser.LastMGroup), False, False)
  Else
    Session.Msgs.MessageGroupChange ('+', True, False);

  If ThisUser.LastMBase > 0 Then
    Session.Msgs.ChangeArea(strI2S(ThisUser.LastMBase))
  Else
    Session.Msgs.ChangeArea('+');

  If ThisUser.LastFGroup > 0 Then
    Session.FileBase.FileGroupChange(strI2S(ThisUser.LastFGroup), False, False)
  Else
    Session.FileBase.FileGroupChange('+', True, False);

  If ThisUser.LastFBase > 0 Then
    Session.FileBase.ChangeFileArea(strI2S(ThisUser.LastFBase))
  Else
    Session.FileBase.ChangeFileArea('+');

  If (Session.TimeOffset = 0) or (Session.TimeOffset > ThisUser.TimeLeft) Then
    Session.SetTimeLeft (ThisUser.TimeLeft);

    // check auto-upgrades posts/calls/downloads/uploads/etc

  If DateValid(Session.User.ThisUser.Expires) Then
    If CurDateJulian - DateStr2Julian(Session.User.ThisUser.Expires) >= 0 Then Begin
      Session.SystemLog('Account expired to level ' + strI2S(Session.User.ThisUser.ExpiresTo));

      Upgrade_User_Level(True, Session.User.ThisUser, Session.User.ThisUser.ExpiresTo);

      If Session.User.ThisUser.Security = 0 Then Begin
        Session.io.OutFullLn(Session.GetPrompt(477));
        Session.User.ThisUser.Flags := Session.User.ThisUser.Flags AND UserDeleted;

        Exit;
      End Else
        Session.io.OutFullLn(Session.GetPrompt(476));
    End;

  If (bbsCfg.PWChange > 0) and (Session.User.ThisUser.Flags AND UserNoPWChange = 0) Then
    If Not DateValid(Session.User.ThisUser.LastPWChange) Then
      Session.User.ThisUser.LastPWChange := DateDos2Str(CurDateDos, 1)
    Else
    If CurDateJulian - DateStr2Julian(Session.User.ThisUser.LastPWChange) >= bbsCfg.PWChange Then Begin
      Session.SystemLog('Required password change');
      Session.io.OutFullLn(Session.GetPrompt(478));
      Session.User.GetPassword(False);
    End;

  {$IFNDEF UNIX}
    UpdateStatusLine(Session.StatusPtr, '');
  {$ENDIF}
End;

Procedure TBBSUser.UserLogon1 (Var MPE: String);
Var
  A     : Integer;
  Count : Byte;
  Str   : String;
Begin
  {$IFDEF LOGGING} Session.SystemLog('Logon1'); {$ENDIF}

  Set_Node_Action (Session.GetPrompt(345));

  Session.io.Graphics := 0;

  Session.SystemLog ('-');
  Session.SystemLog ('Connect from ' + Session.UserIPInfo + ' (' + Session.UserHostInfo + ')');

  Session.HistoryHour := strS2I(Copy(TimeDos2Str(CurDateDos, 0), 1, 2));

  If bbsCfg.SystemPW <> '' Then
    If Not Session.io.GetPW(Session.GetPrompt(4), Session.GetPrompt(417), bbsCfg.SystemPW) Then Begin
      Session.io.OutFile ('closed', True, 0);

      Session.SystemLog('Failed system password');

      Halt(0);
    End;

  Session.io.OutFullLn ('|CL' + mysSoftwareID + ' v' + mysVersion + ' for ' + OSID + ' Node |ND');
  Session.io.OutFullLn (mysCopyNotice);

  If bbsCfg.DefTermMode = 0 Then
    GetGraphics
  Else
  If bbsCfg.DefTermMode = 3 Then
    Session.io.Graphics := 1
  Else Begin
    DetectGraphics;

    If (Session.io.Graphics = 0) and (bbsCfg.DefTermMode = 2) Then GetGraphics;
  End;

  If FileExist(bbsCfg.ScriptPath + 'startup.mpx') Then
    ExecuteMPL(NIL, 'startup');

  If bbsCfg.ThemeOnStart Then GetTheme;

  If (Session.Theme.Flags AND ThmAllowASCII = 0) and (Session.io.Graphics = 0) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(321));
    Session.SystemLog ('ASCII login disabled');
    Halt(0);
  End Else
  If (Session.Theme.Flags AND ThmAllowANSI = 0) and (Session.io.Graphics = 1) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(322));
    Session.SystemLog ('ANSI login disabled');
    Halt(0);
  End;

  If Session.UserLoginName <> '' Then Begin
//    session.systemlog('DEBUG: auto login: ' + session.userloginname);

    If Not FindUser(Session.UserLoginName, True) Then
      Halt;

//    session.systemlog('DEBUG: pw check: ' + tempuser.handle);

    If strUpper(Session.UserLoginPW) <> TempUser.Password Then Begin
      UserNum := -1;

      Halt;
    End;

    ThisUser := TempUser;
  End Else Begin
    If bbsCfg.UseMatrix Then Begin
      Repeat
        Session.Menu.MenuName := bbsCfg.MatrixMenu;

        Session.Menu.ExecuteMenu (True, True, False, True);
      Until MatrixOK or Session.ShutDown;
    End;

    Session.io.OutFile ('prelogon', True, 0);

    If UserNum = -1 Then Begin
      Count := 1;

      Repeat
        If Count > bbsCfg.LoginAttempts Then Halt;

        Session.io.PromptInfo[1] := strI2S(Count);
        Session.io.PromptInfo[2] := strI2S(bbsCfg.LoginAttempts);
        Session.io.PromptInfo[3] := strI2S(bbsCfg.LoginAttempts - Count);

        Session.io.OutFull (Session.GetPrompt(0));

        Str := strStripB(Session.io.GetInput(30, 30, 18, ''), ' ');

        If Not FindUser(Str, True) Then Begin
          Session.io.OutFile ('newuser', True, 0);

          If Session.io.GetYN(Session.GetPrompt(1), False) Then Begin
            CreateNewUser(Str);
            UserLogon2;
            UserLogon3;

            Exit;
          End;

          Inc (Count);
        End Else
          Break;
      Until False;

      A := UserNum;   {If user would drop carrier here itd save their info }
      UserNum := -1;  {which is only User.ThisUser.realname at this time        }

      If Not Session.io.GetPW(Session.GetPrompt(2), Session.GetPrompt(3), TempUser.Password) Then Begin
        If bbsCfg.PWInquiry Then
          If Session.io.GetYN(Session.GetPrompt(475), False) Then
            Session.Msgs.PostMessage(True, '/TO:' + strReplace(bbsCfg.FeedbackTo, ' ', '_') + ' /SUBJ:Password_Inquiry');

        Session.Msgs.PostTextFile('hackwarn.txt;0;' + bbsCfg.SysopName + ';' + TempUser.Handle + ';Possible hack attempt', True);

        Halt(0);
      End;

      UserNum  := A;
      ThisUser := TempUser;
    End;

//    ThisUser := TempUser;
  End;

  Session.SystemLog (ThisUser.Handle + ' logged in');

  If bbsCfg.ThemeOnStart Then
    ThisUser.Theme := Session.Theme.FileName
  Else
  If Not Session.LoadThemeData(ThisUser.Theme) Then Begin
    Session.io.OutFullLn (Session.GetPrompt(186));

    If Session.LoadThemeData(bbsCfg.DefThemeFile) Then
      ThisUser.Theme := bbsCfg.DefThemeFile;
  End;

  UserLogon2;

  If MPE <> '' Then Begin
    ExecuteMPL(NIL, MPE);

    Halt;
  End Else
    UserLogon3;
End;

Procedure TBBSUser.EditUserSettings (Data: String);
Var
  What : Byte;
Begin
  What := strS2I(strWordGet(1, Data, ' '));

  If strWordCount(Data, ' ') > 1 Then
    Data := strStripB(Copy(Data, strWordPos(2, Data, ' '), 255), ' ')
  Else
    Data := '';

  Case What of
    1   : GetAddress(True);
    2   : GetCityState(True);
    3   : GetZipCode(True);
    4   : GetHomePhone(True);
    5   : GetDataPhone(True);
    6   : GetBirthDate(True);
    7   : GetGender(True);
    8   : GetDateFormat(True);
    9   : Repeat
            GetGraphics;
            If ((Session.Theme.Flags AND ThmAllowASCII = 0) and (Session.io.Graphics = 0)) or ((Session.Theme.Flags AND ThmAllowANSI = 0) and (Session.io.Graphics = 1)) Then
              Session.io.OutFullLn (Session.GetPrompt(325))
            Else
              Break;
          Until False;
    10  : GetScreenLength(True);
    11  : GetPassword(True);
    12  : GetRealName(True);
    13  : GetAlias(True, '');
    14  : If Data = '' Then
            GetTheme
          Else
            Session.LoadThemeData(Data);
    15  : GetEditor(True);
    16  : If Access(bbsCfg.AcsInvisLogin) Then Begin
            Session.Chat.Invisible := Not Session.Chat.Invisible;
            Set_Node_Action (Session.Chat.Action);
          End;
    17  : GetFileList(True);
    18  : Session.Chat.Available := Not Session.Chat.Available;
    19  : GetHotKeys(True);
    20  : GetMsgList(True);
    21  : ThisUser.UseLBIndex := Not ThisUser.UseLBIndex;
    22  : GetEmail(True);
    23  : GetUserNote(True);
    24  : GetOption1(True);
    25  : GetOption2(True);
    26  : GetOption3(True);
    27  : ThisUser.UseLBQuote := Not ThisUser.UseLBQuote;
    28  : ThisUser.UseLBMIdx := Not ThisUser.UseLBMIdx;
    29  : ThisUser.UseFullChat := Not ThisUser.UseFullChat;
    30  : ThisUser.QwkFiles := Not ThisUser.QwkFiles;
    31  : Session.FileBase.SelectArchive;
    32  : ThisUser.Protocol := Session.FileBase.SelectProtocol(False, True);
    33  : ThisUser.QwkExtended := Not ThisUser.QwkExtended;
  End;
End;

End.

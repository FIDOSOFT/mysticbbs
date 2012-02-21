Unit bbs_Doors;

{$I M_OPS.PAS}

Interface

Procedure ExecuteDoor (Format: Byte; Cmd: String);

Implementation

Uses
  {$IFDEF WIN32}
    Windows,
  {$ENDIF}
  m_Types,
  m_Strings,
  m_DateTime,
  bbs_Common,
  bbs_Core,
  bbs_User;

Const
  Ending : String[2] = #13#10;

Procedure Write_DOOR32 (cHandle : LongInt);
Var
  tFile : Text;
Begin
  Assign  (tFile, Session.TempPath + 'door32.sys');
  ReWrite (tFile);

  If Session.LocalMode Then
    Write (tFile, '0' + Ending)
  Else
    Write (tFile, '2' + Ending);

  If Session.LocalMode Then
    Write (tFile, '0' + Ending)
  Else
    Write (tFile, cHandle, Ending);

  Write (tFile, Session.Baud, Ending);
  Write (tFile, 'Mystic ' + mysVersion + Ending);
  Write (tFile, Session.User.UserNum, Ending);
  Write (tFile, Session.User.ThisUser.RealName + Ending);
  Write (tFile, Session.User.ThisUser.Handle + Ending);
  Write (tFile, Session.User.ThisUser.Security, Ending);
  Write (tFile, Session.TimeLeft, Ending);
  Write (tFile, Session.io.Graphics, Ending);
  Write (tFile, Session.NodeNum, Ending);

  Close (tFile);
End;

Procedure Write_DORINFO;
Var
  tFile : Text;
  A     : Byte;
Begin
  Assign (tFile, Session.TempPath + 'DORINFO1.DEF');
  Rewrite (tFile);

  Write (tFile, Config.BBSName + Ending);

  A := Pos(' ', Config.SysopName);
  If A > 0 Then
    Write (tFile, Copy(Config.SysopName, 1, A-1) + Ending)
  Else
    Write (tFile, Config.SysopName + Ending);

  If A > 0 Then
    Write (tFile, Copy(Config.SysopName, A+1, 255) + Ending)
  Else
    Write (tFile, '' + Ending);

  If Session.LocalMode Then Write (tFile, 'COM0' + Ending) Else Write (tFile, 'COM1', Ending);
  Write (tFile, Session.Baud, ' BAUD,N,8,1' + Ending);
  Write (tFile, '0' + Ending);

  A := Pos(' ', Session.User.ThisUser.Handle);
  If A > 0 Then
    Write (tFile, Copy(Session.User.ThisUser.Handle, 1, A-1) + Ending)
  Else
    Write (tFile, Session.User.ThisUser.Handle + Ending);

  If A > 0 Then
    Write (tFile, Copy(Session.User.ThisUser.Handle, A+1, 255) + Ending)
  Else
    Write (tFile, '' + Ending);

  Write (tFile, Session.User.ThisUser.City + Ending);
  Write (tFile, Session.io.Graphics, Ending);
  Write (tFile, Session.User.ThisUser.Security, Ending);
  Write (tFile, Session.TimeLeft, Ending);
  Write (tFile, '-1' + Ending); {-1 FOSSIL, 0=NOT... ???}

  Close (tFile);
End;

Procedure Write_CHAINTXT;
Var
  tFile : Text;
Begin
  Assign  (tFile, Session.TempPath + 'CHAIN.TXT');
  ReWrite (tFile);

  Write (tFile, Session.User.UserNum, Ending);
  Write (tFile, Session.User.ThisUser.Handle + Ending);
  Write (tFile, Session.User.ThisUser.RealName + Ending);
  Write (tFile, '' + Ending);
  Write (tFile, DaysAgo(Session.User.ThisUser.Birthday) DIV 365, Ending);  { User's AGE }
  Write (tFile, Session.User.ThisUser.Gender + Ending);
  Write (tFile, '0' + Ending);  { User's gold }
  Write (tFile, DateDos2Str(Session.User.ThisUser.LastOn, 1) + Ending);
  Write (tFile, '80' + Ending);
  Write (tFile, Session.User.ThisUser.ScreenSize, Ending);
  Write (tFile, Session.User.ThisUser.Security, Ending);
  Write (tFile, '0' + Ending);
  Write (tFile, '0' + Ending);
  Write (tFile, Session.io.Graphics, Ending);
  Write (tFile, Ord(Not Session.LocalMode), Ending);
  Write (tFile, (Session.TimeLeft * 60), Ending);
  Write (tFile, Session.Lang.TextPath + Ending);
  Write (tFile, Config.DataPath + Ending);
  Write (tFile, 'SYSOP.', Session.NodeNum, Ending);
  If Session.LocalMode Then
    Write (tFile, 'KB' + Ending)
  Else
    Write (tFile, Session.Baud, Ending);
  Write (tFile, '1', Ending);
  Write (tFile, Config.BBSName + Ending);
  Write (tFile, Config.SysopName + Ending);
  Write (tFile, TimerSeconds, Ending);
  Write (tFile, '0' + Ending); {seconds online}
  Write (tFile, Session.User.ThisUser.ULk, Ending);
  Write (tFile, Session.User.ThisUser.ULs, Ending);
  Write (tFile, Session.User.ThisUser.DLk, Ending);
  Write (tFile, Session.User.ThisUser.DLs, Ending);
  Write (tFile, '8N1' + Ending);
  Close (tFile);
End;

Procedure Write_DOORSYS;
Var
  tFile : Text;
{ Temp  : LongInt;}
Begin
  Assign (tFile, Session.TempPath + 'DOOR.SYS');
  Rewrite (tFile);

  If Session.LocalMode Then Write (tFile, 'COM0:' + Ending) Else Write (tFile, 'COM1:' + Ending);
  Write (tFile, Session.Baud, Ending);
  Write (tFile, '8' + Ending);
  Write (tFile, Session.NodeNum, Ending);
  Write (tFile, Session.Baud, Ending); {locked rate}
  Write (tFile, 'Y' + Ending); {screen display}
  Write (tFile, 'N' + Ending);
  Write (tFile, 'Y' + Ending); {page bell}
  Write (tFile, 'Y' + Ending);
  Write (tFile, Session.User.ThisUser.RealName + Ending);
  Write (tFile, Session.User.ThisUser.City + Ending);
  Write (tFile, Session.User.ThisUser.HomePhone + Ending);
  Write (tFile, Session.User.ThisUser.DataPhone + Ending);
  Write (tFile, Session.User.ThisUser.Password + Ending);
  Write (tFile, Session.User.ThisUser.Security, Ending);
  Write (tFile, Session.User.ThisUser.Calls, Ending);
  Write (tFile, DateDos2Str(Session.User.ThisUser.LastOn, 1) + Ending);

  Write (tFile, (Session.TimeLeft * 60), Ending); {seconds left}
  Write (tFile, Session.TimeLeft, Ending); {mins left}

  If Session.io.Graphics = 1 Then Write (tFile, 'GR' + Ending) Else Write (tFile, 'NG' + Ending);

  Write (tFile, Session.User.ThisUser.ScreenSize, Ending);   {page length}
  Write (tFile, 'N' + Ending);    {Y=expert, N=novice}
  Write (tFile, '' + Ending);
  Write (tFile, '' + Ending);
  Write (tFile, '' + Ending);  {user account expiration date}
  Write (tFile, Session.User.UserNum, Ending); {user record number}
  Write (tFile, '' + Ending); {default protocol}
  Write (tFile, Session.User.ThisUser.ULs, Ending);
  Write (tFile, Session.User.ThisUser.DLs, Ending);
  Write (tFile, Session.User.ThisUser.DLk, Ending);
  Write (tFile, Session.User.Security.MaxDLk, Ending);
  Write (tFile, Session.User.ThisUser.Birthday, Ending);
  Write (tFile, Config.DataPath + Ending);
  Write (tFile, Config.MsgsPath + Ending);
  Write (tFile, Config.SysopName + Ending);
  Write (tFile, Session.User.ThisUser.Handle + Ending);
  Write (tFile, TimeDos2Str(Session.NextEvent.ExecTime, False) + Ending); {next event start time hh:mm}
  Write (tFile, 'Y' + Ending); {error-free connection}
  Write (tFile, 'N' + Ending); {ansi in NG mode}
  Write (tFile, 'Y' + Ending); {record locking}
  Write (tFile, '3' + Ending); {default BBS color}
  Write (tFile, '0' + Ending); {time credits per minute}
  Write (tFile, '00/00/00' + Ending); {last new filescan date}
  Write (tFile, TimeDos2Str(Session.User.ThisUser.LastOn, False) + Ending); {time of this call}
  Write (tFile, TimeDos2Str(Session.User.ThisUser.LastOn, False) + Ending); {time of last call}
  Write (tFile, '32768' + Ending); {max daily files (??) }
  Write (tFile, Session.User.ThisUser.DLsToday, Ending);
  Write (tFile, Session.User.ThisUser.ULk, Ending);
  Write (tFile, Session.User.ThisUser.DLk, Ending);
  Write (tFile, '' + Ending); {user comment}
  Write (tFile, '0' + Ending); {total doors opened}
  Write (tFile, Session.User.ThisUser.Posts, Ending); {total posts}
  Close (tFile);
End;

{$IFDEF WIN32}
Procedure Shell_DOOR32 (Cmd : String);
Var
  PI         : TProcessInformation;
  SI         : TStartupInfo;
  Image      : TConsoleImageRec;
  PassHandle : LongInt;
Begin
  PassHandle := 0;

  If Not Session.LocalMode Then
    PassHandle := Session.Client.FSocketHandle;

  If Session.User.UserNum <> -1 Then Begin
    Reset (Session.User.UserFile);
    Seek  (Session.User.UserFile, Session.User.UserNum - 1);
    Write (Session.User.UserFile, Session.User.ThisUser);
    Close (Session.User.UserFile);
  End;

  WRITE_DOOR32(PassHandle);

  Screen.GetScreenImage(1,1,80,25, Image);

  Cmd := Cmd + #0;

  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);

  SI.CB          := SizeOf(TStartupInfo);
  SI.wShowWindow := SW_SHOWMINNOACTIVE;
  SI.dwFlags     := SI.dwFlags or STARTF_USESHOWWINDOW;

  If CreateProcess(NIL, @Cmd[1],
    NIL,
    NIL,
    True,
    CREATE_SEPARATE_WOW_VDM,
    NIL,
    NIL,
    SI,
    PI) Then
      WaitForSingleObject (PI.hProcess, INFINITE);

  ChangeDir(Config.SystemPath);

  If Session.User.UserNum <> -1 Then Begin
    Reset  (Session.User.UserFile);
    Seek   (Session.User.UserFile, Session.User.UserNum - 1);
    Read   (Session.User.UserFile, Session.User.ThisUser);
    Close  (Session.User.UserFile);
  End;

  Screen.SetWindowTitle(WinConsoleTitle + strI2S(Session.NodeNum));
  Screen.PutScreenImage(Image);

  Update_Status_Line(StatusPtr, '');

  Session.TimeOut := TimerSeconds;
End;
{$ENDIF}

Procedure ExecuteDoor (Format: Byte; Cmd: String);
{Format:
  0 = None
  1 = DORINFO1.DEF
  2 = DOOR.SYS
  3 = CHAIN.TXT
}
Var
  A    : LongInt;
  Temp : String;
Begin
  A := Pos('/DOS', strUpper(Cmd));

  If A > 0 Then Begin
    Delete (Cmd, A, 4);
    Ending := #13#10;
  End Else
    Ending := LineTerm;

  Temp := '';
  A    := 1;

  While A <= Length(Cmd) Do Begin
    If Cmd[A] = '%' Then Begin
      Inc(A);
      {$IFDEF UNIX}
      If Cmd[A] = '0' Then Temp := Temp + '1' Else
      {$ELSE}
      If Cmd[A] = '0' Then Temp := Temp + strI2S(Session.Client.FSocketHandle) Else
      {$ENDIF}
      If Cmd[A] = '1' Then Temp := Temp + '1' Else
      If Cmd[A] = '2' Then Temp := Temp + strI2S(Session.Baud) Else
      If Cmd[A] = '3' Then Temp := Temp + strI2S(Session.NodeNum) Else
      If Cmd[A] = '4' Then Temp := Temp + Session.UserIPInfo Else
      If Cmd[A] = '5' Then Temp := Temp + Session.UserHostInfo Else
      If Cmd[A] = '#' Then Temp := Temp + strI2S(Session.User.ThisUser.PermIdx) Else
      If Cmd[A] = 'T' Then Temp := Temp + strI2S(Session.TimeLeft) Else
      If Cmd[A] = 'P' Then Temp := Temp + Session.TempPath Else
      If Cmd[A] = 'U' Then Temp := Temp + strReplace(Session.User.ThisUser.Handle, ' ', '_');
    End Else
      Temp := Temp + Cmd[A];

    Inc (A);
  End;

  Session.SystemLog ('Executed Door: ' + Temp);

  A := TimerMinutes; { save current timer for event check after door }

  Case Format of
    1 : Write_DORINFO;
    2 : Write_DOORSYS;
    3 : Write_CHAINTXT;
  {$IFDEF UNIX}
    4 : Write_DOOR32(0);
  {$ENDIF}
  End;

  {$IFDEF WIN32}
    If Format = 4 Then
      Shell_DOOR32(Temp)
    Else
      ShellDOS ('', Temp);
  {$ELSE}
    ShellDOS ('', Temp);
  {$ENDIF}

  { Check to see if event was missed while user was in door }

  If Session.NextEvent.Active Then
    If (TimerMinutes < A) and (A < Session.NextEvent.ExecTime) Then Begin { midnight roll over }
      Session.MinutesUntilEvent(Session.NextEvent.ExecTime);
    End Else
    If (A < Session.NextEvent.ExecTime) and (TimerMinutes > Session.NextEvent.ExecTime) Then
      Session.MinutesUntilEvent(Session.NextEvent.ExecTime);
End;

End.

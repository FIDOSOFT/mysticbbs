// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

Program Mystic;

{$I M_OPS.PAS}

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  {$IFDEF WINDOWS}
    m_io_Base,
    m_io_Sockets,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
  {$ENDIF}
  m_FileIO,
  m_Strings,
  m_DateTime,
  m_Output,
  m_Input,
  bbs_Common,
  bbs_Core,
  bbs_NodeInfo,
  bbs_Cfg_Main;

Procedure InitClasses;
Begin
  Assign (ConfigFile, 'mystic.dat');

  if ioReset(ConfigFile, SizeOf(RecConfig), fmReadWrite + fmDenyNone) Then Begin
    Read (ConfigFile, Config);
    Close (ConfigFile);
  End Else Begin
    WriteLn('ERROR: Unable to read mystic.dat');
    Halt(1);
  End;

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn('ERROR: Data files are not current and must be upgraded');
    Halt(1);
  End;

  Screen  := TOutput.Create(True);
  Input   := TInput.Create;
  Session := TBBSCore.Create;
End;

Procedure DisposeClasses;
Begin
  Session.Free;
  Input.Free;
  Screen.Free;
End;

Var
  ExitSave : Pointer;

Procedure ExitHandle;
Begin
  Set_Node_Action('');

  Session.UpdateHistory;

  ExitProc := ExitSave;

  If ErrorAddr <> NIL Then ExitCode := 1;

  If Session.User.UserNum <> -1 Then Begin
    Session.User.ThisUser.LastOn   := CurDateDos;
    Session.User.ThisUser.PeerIP   := Session.UserIPInfo;
    Session.User.ThisUser.PeerHost := Session.UserHostInfo;

    If Session.TimerOn Then
      If (Session.TimeOffset > 0) and (Session.TimeSaved > Session.TimeOffset) Then
        Session.User.ThisUser.TimeLeft := Session.TimeSaved - (Session.TimeOffset - Session.TimeLeft)
      Else
        Session.User.ThisUser.TimeLeft := Session.TimeLeft;

    Reset (Session.User.UserFile);
    Seek  (Session.User.UserFile, Session.User.UserNum - 1);
    Write (Session.User.UserFile, Session.User.ThisUser);
    Close (Session.User.UserFile);
  End;

  If Session.EventExit or Session.EventRunAfter Then Begin
    Reset (Session.EventFile);

    While Not Eof(Session.EventFile) Do Begin
      Read (Session.EventFile, Session.Event);

      If Session.Event.Name = Session.NextEvent.Name Then Begin
        Session.Event.LastRan := CurDateDos;
        Seek  (Session.EventFile, FilePos(Session.EventFile) - 1);
        Write (Session.EventFile, Session.Event);
      End;
    End;

    Close (Session.EventFile);
  End;

  If Session.ExitLevel <> 0 Then ExitCode := Session.ExitLevel;
  If Session.EventRunAfter  Then ExitCode := Session.NextEvent.ErrLevel;

  FileMode := 66;

  DirClean  (Session.TempPath, '');
  FileErase (Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');

  {$IFNDEF LOGGING}
    {$IFNDEF UNIX}
      Screen.TextAttr := 14;

      Screen.SetWindow (1, 1, 80, 25, False);
      Screen.ClearScreen;
      Screen.WriteLine ('Exiting with Errorlevel ' + strI2S(ExitCode));
    {$ENDIF}
  {$ENDIF}

  DisposeClasses;

  Halt (ExitCode);
End;

Procedure CheckDIR (Dir: String);
Begin
  If Not DirExists(Dir) Then Begin
    Screen.WriteLine ('ERROR: ' + Dir + ' does not exist.');

    DisposeClasses;

    Halt(1);
  End;
End;

{$IFDEF UNIX}
Procedure LinuxEventSignal (Sig : LongInt); cdecl;
Begin
  FileMode := 66;

  Case Sig of
//    SIGHUP  : Halt;
//    SIGTERM : Halt;
    SIGHUP  : Begin
                FileErase (Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
                Halt;
              End;
    SIGTERM : Begin
                FileErase (Config.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
                Halt;
              End;
    SIGUSR1 : Session.CheckTimeOut := False;
    SIGUSR2 : Begin
                Session.CheckTimeOut := True;
                Session.TimeOut      := TimerSeconds;
              End;
  End;
End;

Procedure Linux_Init;
Var
  Count : Word;
  TChat : ChatRec;
Begin
  Session.NodeNum := 0;

  For Count := 1 to Config.INetTNNodes Do Begin
    Assign (ChatFile, Config.DataPath + 'chat' + strI2S(Count) + '.dat');

    {$I-} Reset(ChatFile); {$I+}

    If IoResult <> 0 Then Begin
      Session.NodeNum := Count;
      Break;
    End;

    Read  (ChatFile, TChat);
    Close (ChatFile);

    If Not TChat.Active Then Begin
      Session.NodeNum := Count;
      Break;
    End;
  End;

  If Session.NodeNum = 0 Then Begin
    WriteLn ('BUSY'); {++lang}

    DisposeClasses;

    Halt;
  End;

  fpSignal (SIGTERM, LinuxEventSignal);
  fpSignal (SIGHUP,  LinuxEventSignal);

  Write (#27 + '(U');
End;
{$ENDIF}

Procedure CheckPathsAndDataFiles;
Var
  Count : Byte;
Begin
  Randomize;

  Session.TempPath := Config.SystemPath + 'temp' + strI2S(Session.NodeNum) + PathChar;

  {$I-}
  MkDir (Config.SystemPath + 'temp' + strI2S(Session.NodeNum));
  {$I+}

  If IoResult <> 0 Then;

  DirClean (Session.TempPath, '');

  Assign (Session.User.UserFile, Config.DataPath + 'users.dat');
  {$I-} Reset (Session.User.UserFile); {$I+}
  If IoResult <> 0 Then Begin
    If FileExist(Config.DataPath + 'users.dat') Then Begin
      Screen.WriteLine ('ERROR: Unable to access USERS.DAT');
      DisposeClasses;
      Halt(1);
    End;

    ReWrite(Session.User.UserFile);
  End;
  Close (Session.User.UserFile);

  Assign (Session.VoteFile, Config.DataPath + 'votes.dat');
  {$I-} Reset (Session.VoteFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.VoteFile);
  Close (Session.VoteFile);

  Assign (Session.ThemeFile, Config.DataPath + 'theme.dat');
  {$I-} Reset (Session.ThemeFile); {$I+}
  If IoResult <> 0 Then Begin
    Screen.WriteLine ('ERROR: No theme configuration.');
    DisposeClasses;
    Halt(1);
  End;
  Close (Session.ThemeFile);

  If Not Session.LoadThemeData(Config.DefThemeFile) Then Begin
    If Not Session.ConfigMode Then Begin
      Screen.WriteLine ('ERROR: Default theme prompts not found [' + Config.DefThemeFile + '.thm]');
      DisposeClasses;
      Halt(1);
    End;
  End;

  If Session.ConfigMode Then Exit;

  CheckDIR (Config.SystemPath);
  CheckDIR (Config.AttachPath);
  CheckDIR (Config.DataPath);
  CheckDIR (Config.MsgsPath);
  CheckDIR (Config.SemaPath);
  CheckDIR (Config.QwkPath);
  CheckDIR (Config.ScriptPath);
  CheckDIR (Config.LogsPath);

  Assign (RoomFile, Config.DataPath + 'chatroom.dat');
  {$I-} Reset (RoomFile); {$I+}
  If IoResult <> 0 Then Begin
    ReWrite (RoomFile);
    Room.Name := 'None';
    For Count := 1 to 99 Do
      Write (RoomFile, Room);
  End;
  Close (RoomFile);

  Assign (Session.FileBase.FBaseFile, Config.DataPath + 'fbases.dat');
  {$I-} Reset(Session.FileBase.FBaseFile); {$I+}
  If IoResult <> 0 Then ReWrite(Session.FileBase.FBaseFile);
  Close (Session.FileBase.FBaseFile);

  Assign (Session.Msgs.MBaseFile, Config.DataPath + 'mbases.dat');
  {$I-} Reset(Session.Msgs.MBaseFile); {$I+}
  If IoResult <> 0 Then Begin
    Screen.WriteLine ('ERROR: No message base configuration. Use MYSTIC -CFG');
    DisposeClasses;
    Halt(1);
  End;
  Close (Session.Msgs.MBaseFile);

  Assign (Session.Msgs.GroupFile, Config.DataPath + 'groups_g.dat');
  {$I-} Reset (Session.Msgs.GroupFile); {$I-}
  If IoResult <> 0 Then ReWrite(Session.Msgs.GroupFile);
  Close (Session.Msgs.GroupFile);

  Assign (Session.FileBase.FGroupFile, Config.DataPath + 'groups_f.dat');
  {$I-} Reset (Session.FileBase.FGroupFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.FileBase.FGroupFile);
  Close (Session.FileBase.FGroupFile);

  Assign (Session.User.SecurityFile, Config.DataPath + 'security.dat');
  {$I-} Reset (Session.User.SecurityFile); {$I+}
  If IoResult <> 0 Then Begin
    ReWrite(Session.User.SecurityFile);

    For Count := 1 to 255 Do
      Write (Session.User.SecurityFile, Session.User.Security);
  End;
  Close (Session.User.SecurityFile);

  Assign (LastOnFile, Config.DataPath + 'callers.dat');
  {$I-} Reset(LastOnFile); {$I+}
  If IoResult <> 0 Then ReWrite(LastOnFile);
  Close (LastOnFile);

  Assign (Session.FileBase.ArcFile, Config.DataPath + 'archive.dat');
  {$I-} Reset(Session.FileBase.ArcFile); {$I+}
  If IoResult <> 0 Then ReWrite(Session.FileBase.ArcFile);
  Close (Session.FileBase.ArcFile);

  Assign (Session.FileBase.ProtocolFile, Config.DataPath + 'protocol.dat');
  {$I-} Reset (Session.FileBase.ProtocolFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.FileBase.ProtocolFile);
  Close (Session.FileBase.ProtocolFile);
End;

Var
  Count    : Byte;
  Temp     : String[120];
  UserName : String[30];
  Password : String[15];
  Script   : String[120];
Begin
  {$IFDEF DEBUG}
    SetHeapTraceOutput('mystic.mem');
  {$ENDIF}

  DirChange(JustPath(ParamStr(0)));

  InitClasses;

  Screen.TextAttr := 7;
  Screen.WriteLine('');

  For Count := 1 to ParamCount Do Begin
    Temp := strUpper(ParamStr(Count));

    If Pos('-TID', Temp) > 0 Then Begin
      Session.CommHandle := strS2I(Copy(Temp, 5, Length(Temp)));
      Session.Baud       := 38400;
    End Else
    If Pos('-B', Temp) > 0 Then Begin
      Session.Baud := strS2I(Copy(Temp, 3, Length(Temp)));
      If Session.Baud = 0 Then Session.LocalMode := True;
    End Else
    If Pos('-T', Temp) > 0 Then
      Session.TimeOffset := strS2I(Copy(Temp, 3, Length(Temp)))
    Else
    If Pos('-N', Temp) > 0 Then
      Session.NodeNum := strS2I(Copy(Temp, 3, Length(Temp)))
    Else
    If Pos('-CFG', Temp) > 0 Then Begin
      Session.ConfigMode := True;
      Session.LocalMode  := True;
      Session.NodeNum    := 0;
    End Else
    If Pos('-IP', Temp) > 0 Then
      Session.UserIPInfo := Copy(Temp, 4, Length(Temp))
    Else
    If Pos('-UID', Temp) > 0 Then
      Session.UserHostInfo := Copy(Temp, 5, Length(Temp))
    Else
    If Pos('-HOST', Temp) > 0 Then
      Session.UserHostInfo := Copy(Temp, 6, Length(Temp))
    Else
    If Pos('-U', Temp) > 0 Then
      UserName := strReplace(Copy(Temp, 3, Length(Temp)), '_', ' ')
    Else
    If Pos('-P', Temp) > 0 Then
      Password := Copy(Temp, 3, Length(Temp))
    Else
    If Pos('-X', Temp) > 0 Then
      Script := strReplace(Copy(Temp, 3, Length(Temp)), '_', ' ')
    Else
    If Temp = '-L' Then Session.LocalMode := True;
  End;

  FileMode := 66;

  {$IFDEF UNIX}
    Linux_Init;
    Session.Baud := 38400;
  {$ENDIF}

  CheckPathsAndDataFiles;

  {$IFNDEF UNIX}
    Session.LocalMode := Session.CommHandle = -1;

    If Not Session.LocalMode Then Begin
      TIOSocket(Session.Client).FSocketHandle := Session.CommHandle;

      Session.io.LocalScreenDisable;
    End;
  {$ENDIF}

  ExitSave := ExitProc;
  ExitProc := @ExitHandle;

  If Session.ConfigMode Then Begin
    Configuration_MainMenu;

    Screen.TextAttr := 7;
    Screen.ClearScreen;
    Screen.BufFlush;

    Halt(0);
  End;

  Session.FindNextEvent;

  If Session.TimeOffset > 0 Then
    Session.SetTimeLeft(Session.TimeOffset)
  Else
    Session.SetTimeLeft(Config.LoginTime);

  If Session.Baud = -1 Then Session.Baud := 0;

  {$IFNDEF UNIX}
    Screen.TextAttr := 7;
    Screen.ClearScreen;
  {$ENDIF}

  {$IFNDEF UNIX}
    UpdateStatusLine(0, '');
  {$ENDIF}

  Set_Node_Action (Session.GetPrompt(345));

  Session.User.User_Logon (UserName, Password, Script);

  If Session.TimeOffset > 0 Then
    Session.TimeSaved := Session.User.ThisUser.TimeLeft;

  If Session.User.ThisUser.StartMenu <> '' Then
    Session.Menu.MenuName := Session.User.ThisUser.StartMenu
  Else
    Session.Menu.MenuName := Config.DefStartMenu;

  Repeat
    Session.Menu.ExecuteMenu (True, True, False, True);
  Until False;
End.

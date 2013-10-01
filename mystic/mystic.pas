// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
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
  m_Pipe,
  BBS_Records,
  BBS_Common,
  BBS_DataBase,
  BBS_Core,
  BBS_NodeInfo,
  {$IFDEF TESTEDITOR}
    BBS_Edit_Ansi,
  {$ENDIF}
  BBS_Cfg_Main;

{$IFDEF TESTEDITOR}
Procedure TestEditor;
Var
  T : TEditorANSI;
Begin
  T := TEditorANSI.Create(Pointer(Session), 'ansiedit');

  T.Edit;
  T.Free;
End;
{$ENDIF}

Procedure InitClasses;
Begin
  Case BBSCfgStatus of
    CfgNotFound : Begin
                    WriteLn('ERROR: Unable to read mystic.dat');
                    Halt(1);
                  End;
    CfgMisMatch : Begin
                    WriteLn('ERROR: Data files are not current and must be upgraded');
                    Halt(1);
                  End;
  End;

  Console  := TOutput.Create(True);
  Keyboard := TInput.Create;
  Session  := TBBSCore.Create;

  Assign (Session.ConfigFile, bbsCfgPath + 'mystic.dat');
End;

Procedure DisposeClasses;
Begin
  Session.Free;
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
  If Session.EventRunAfter  Then ExitCode := Session.NextEvent.ExecLevel;

  // would be nice flush if not local and still conected: Session.io.BufFlush;

  FileMode := 66;

  DirClean  (Session.TempPath, '');
  FileErase (bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');

  {$IFNDEF LOGGING}
    {$IFNDEF UNIX}
      Console.TextAttr := 14;

      Console.SetWindow (1, 1, 80, 25, False);
      Console.ClearScreen;
      Console.WriteLine ('Exiting with Errorlevel ' + strI2S(ExitCode));
    {$ENDIF}
  {$ENDIF}

  DisposeClasses;

  Halt (ExitCode);
End;

Procedure CheckDIR (Dir: String);
Begin
  If Not DirExists(Dir) Then Begin
    Console.WriteLine ('ERROR: ' + Dir + ' does not exist.');

    DisposeClasses;

    Halt(1);
  End;
End;

Procedure CalculateNodeNumber;
Var
  Count : Word;
  TChat : ChatRec;
Begin
  Session.NodeNum := 0;

  For Count := 1 to bbsCfg.INetTNNodes Do Begin
    Assign (Session.ChatFile, bbsCfg.DataPath + 'chat' + strI2S(Count) + '.dat');

    If Not ioReset (Session.ChatFile, Sizeof(ChatRec), fmRWDN) Then Begin
      Session.NodeNum := Count;

      Break;
    End Else Begin
      ioRead (Session.ChatFile, TChat);
      Close  (Session.ChatFile);

      If Not TChat.Active Then Begin
        Session.NodeNum := Count;

        Break;
      End;
    End;
  End;
End;

{$IFDEF UNIX}
Procedure LinuxEventSignal (Sig : LongInt); cdecl;
Begin
  FileMode := 66;

  Session.SystemLog('DEBUG: Signal received: ' + strI2S(Sig));

  Case Sig of
//    SIGHUP  : Halt;
//    SIGTERM : Halt;
    SIGHUP  : Begin
                FileErase (bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
                Halt;
              End;
    SIGTERM : Begin
                FileErase (bbsCfg.DataPath + 'chat' + strI2S(Session.NodeNum) + '.dat');
                Halt;
              End;
    SIGUSR1 : Session.CheckTimeOut := False;
    SIGUSR2 : Begin
                Session.CheckTimeOut := True;
                Session.TimeOut      := TimerSeconds;
              End;
  End;
End;

Procedure InitializeUnix;
Var
  Info : Stat;
Begin
  If fpStat('mystic', Info) = 0 Then Begin
    fpSetGID (Info.st_GID);
    fpSetUID (Info.st_UID);
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

  FileMode         := 66;
  Session.TempPath := bbsCfg.SystemPath + 'temp' + strI2S(Session.NodeNum) + PathChar;
  Session.Pipe     := TPipe.Create(bbsCfg.DataPath, False, Session.NodeNum);

(*
  {$I-}
  MkDir (bbsCfg.SystemPath + 'temp' + strI2S(Session.NodeNum));
  {$I+}

  If IoResult <> 0 Then;
*)
  DirCreate (Session.TempPath);
  DirClean  (Session.TempPath, '');

  Assign (Session.User.UserFile, bbsCfg.DataPath + 'users.dat');
  {$I-} Reset (Session.User.UserFile); {$I+}
  If IoResult <> 0 Then Begin
    If FileExist(bbsCfg.DataPath + 'users.dat') Then Begin
      Console.WriteLine ('ERROR: Unable to access USERS.DAT');
      DisposeClasses;
      Halt(1);
    End;

    ReWrite(Session.User.UserFile);
  End;
  Close (Session.User.UserFile);

  Assign (Session.VoteFile, bbsCfg.DataPath + 'votes.dat');
  {$I-} Reset (Session.VoteFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.VoteFile);
  Close (Session.VoteFile);

  Assign (Session.ThemeFile, bbsCfg.DataPath + 'theme.dat');
  {$I-} Reset (Session.ThemeFile); {$I+}
  If IoResult <> 0 Then Begin
    Console.WriteLine ('ERROR: No theme configuration');
    DisposeClasses;
    Halt(1);
  End;
  Close (Session.ThemeFile);

  If Not Session.LoadThemeData(bbsCfg.DefThemeFile) Then Begin
    If Not Session.ConfigMode Then Begin
      Console.WriteLine ('ERROR: Default theme prompts not found: ' + bbsCfg.DefThemeFile + '.txt');
      DisposeClasses;
      Halt(1);
    End;
  End;

  If Session.ConfigMode Then Exit;

  CheckDIR (bbsCfg.SystemPath);
  CheckDIR (bbsCfg.AttachPath);
  CheckDIR (bbsCfg.DataPath);
  CheckDIR (bbsCfg.MsgsPath);
  CheckDIR (bbsCfg.SemaPath);
  CheckDIR (bbsCfg.QwkPath);
  CheckDIR (bbsCfg.ScriptPath);
  CheckDIR (bbsCfg.LogsPath);

  Assign (Session.RoomFile, bbsCfg.DataPath + 'chatroom.dat');
  {$I-} Reset (Session.RoomFile); {$I+}
  If IoResult <> 0 Then Begin
    ReWrite (Session.RoomFile);
    Session.Room.Name := 'None';
    For Count := 1 to 99 Do
      Write (Session.RoomFile, Session.Room);
  End;
  Close (Session.RoomFile);

  Assign (Session.FileBase.FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset(Session.FileBase.FBaseFile); {$I+}
  If IoResult <> 0 Then ReWrite(Session.FileBase.FBaseFile);
  Close (Session.FileBase.FBaseFile);

  Assign (Session.Msgs.MBaseFile, bbsCfg.DataPath + 'mbases.dat');
  {$I-} Reset(Session.Msgs.MBaseFile); {$I+}
  If IoResult <> 0 Then Begin
    Console.WriteLine ('ERROR: No message base configuration. Use MYSTIC -CFG');
    DisposeClasses;
    Halt(1);
  End;
  Close (Session.Msgs.MBaseFile);

  Assign (Session.Msgs.GroupFile, bbsCfg.DataPath + 'groups_g.dat');
  {$I-} Reset (Session.Msgs.GroupFile); {$I-}
  If IoResult <> 0 Then ReWrite(Session.Msgs.GroupFile);
  Close (Session.Msgs.GroupFile);

  Assign (Session.FileBase.FGroupFile, bbsCfg.DataPath + 'groups_f.dat');
  {$I-} Reset (Session.FileBase.FGroupFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.FileBase.FGroupFile);
  Close (Session.FileBase.FGroupFile);

  Assign (Session.User.SecurityFile, bbsCfg.DataPath + 'security.dat');
  {$I-} Reset (Session.User.SecurityFile); {$I+}
  If IoResult <> 0 Then Begin
    ReWrite(Session.User.SecurityFile);

    For Count := 1 to 255 Do
      Write (Session.User.SecurityFile, Session.User.Security);
  End;
  Close (Session.User.SecurityFile);

  Assign (Session.LastOnFile, bbsCfg.DataPath + 'callers.dat');
  {$I-} Reset(Session.LastOnFile); {$I+}
  If IoResult <> 0 Then ReWrite(Session.LastOnFile);
  Close (Session.LastOnFile);

  Assign (Session.FileBase.ArcFile, bbsCfg.DataPath + 'archive.dat');
  {$I-} Reset(Session.FileBase.ArcFile); {$I+}
  If IoResult <> 0 Then ReWrite(Session.FileBase.ArcFile);
  Close (Session.FileBase.ArcFile);

  Assign (Session.FileBase.ProtocolFile, bbsCfg.DataPath + 'protocol.dat');
  {$I-} Reset (Session.FileBase.ProtocolFile); {$I+}
  If IoResult <> 0 Then ReWrite (Session.FileBase.ProtocolFile);
  Close (Session.FileBase.ProtocolFile);
End;

Var
  Count  : Byte;
  Temp   : String[120];
  Script : String[120];
Begin
  {$IFDEF DEBUG}
    SetHeapTraceOutput('mystic.mem');
  {$ENDIF}

  DirChange(JustPath(ParamStr(0)));

  //FileMode := 66;

  InitClasses;

  Console.TextAttr := 7;
  Console.WriteLine('');

  For Count := 1 to ParamCount Do Begin
    Temp := strUpper(ParamStr(Count));

    If Copy(Temp, 1, 4) = '-TID' Then
      Session.CommHandle := strS2I(Copy(Temp, 5, Length(Temp)))
    Else
    If Copy(Temp, 1, 2) = '-B' Then
      Session.Baud := strS2I(Copy(Temp, 3, Length(Temp)))
    Else
    If Copy(Temp, 1, 2) = '-T' Then
      Session.TimeOffset := strS2I(Copy(Temp, 3, Length(Temp)))
    Else
    If Copy(Temp, 1, 2) = '-N' Then
      Session.NodeNum := strS2I(Copy(Temp, 3, Length(Temp)))
    Else
    If Copy(Temp, 1, 4) = '-CFG' Then Begin
      Session.ConfigMode := True;
      Session.LocalMode  := True;
      Session.NodeNum    := 0;
    End Else
    If Copy(Temp, 1, 3) = '-IP' Then
      Session.UserIPInfo := Copy(Temp, 4, Length(Temp))
    Else
    If Copy(Temp, 1, 4) = '-UID' Then
      Session.UserHostInfo := Copy(Temp, 5, Length(Temp))
    Else
    If Copy(Temp, 1, 5) = '-HOST' Then
      Session.UserHostInfo := Copy(ParamStr(Count), 6, Length(Temp))
    Else
    If Copy(Temp, 1, 2) = '-U' Then
      Session.UserLoginName := strReplace(Copy(Temp, 3, Length(Temp)), '_', ' ')
    Else
    If Copy(Temp, 1, 2) = '-P' Then
      Session.UserLoginPW := Copy(Temp, 3, Length(Temp))
    Else
    If Copy(Temp, 1, 2) = '-X' Then
      Script := strReplace(Copy(ParamStr(Count), 3, Length(Temp)), '_', ' ')
    Else
    If Temp = '-L' Then Session.LocalMode := True;
  End;

  {$IFDEF UNIX}
    InitializeUnix;
  {$ENDIF}

  If Session.NodeNum = 0 Then CalculateNodeNumber;

  If Session.NodeNum = 0 Then Begin
    WriteLn ('BUSY');

    DisposeClasses;

    Halt;
  End;

  CheckPathsAndDataFiles;

  {$IFNDEF UNIX}
    Session.LocalMode := Session.CommHandle = -1;

    If Not Session.LocalMode Then Begin
      TIOSocket(Session.Client).FSocketHandle := Session.CommHandle;
      TIOSocket(Session.Client).FTelnetServer := True;

      Session.io.LocalScreenDisable;
    End;
  {$ENDIF}

  ExitSave := ExitProc;
  ExitProc := @ExitHandle;

  If Session.ConfigMode Then Begin
    Session.NodeNum             := 0;
    Session.User.ThisUser.Flags := Session.User.ThisUser.Flags XOR UserNoTimeout;

    Console.SetWindowTitle ('Mystic Configuration');

    Configuration_MainMenu;

    Console.TextAttr := 7;
    Console.ClearScreen;
    Console.BufFlush;

    Halt(0);
  End;

  Session.FindNextEvent;

  If Session.TimeOffset > 0 Then
    Session.SetTimeLeft(Session.TimeOffset)
  Else
    Session.SetTimeLeft(bbsCfg.LoginTime);

(*
  {$IFNDEF UNIX}
    Screen.TextAttr := 7;
    Screen.ClearScreen;
  {$ENDIF}
*)

  {$IFNDEF UNIX}
    UpdateStatusLine(0, '');
  {$ENDIF}

  Set_Node_Action (Session.GetPrompt(345));

  {$IFDEF TESTEDITOR}
    TestEditor;
    Halt(0);
  {$ENDIF}

  Session.User.UserLogon1 (Script);

  If Session.TimeOffset > 0 Then
    Session.TimeSaved := Session.User.ThisUser.TimeLeft;

  If (Session.User.ThisUser.Flags AND UserQWKNetwork <> 0) and (bbsCfg.QwkNetMenu <> '') Then
    Session.Menu.MenuName := bbsCfg.QwkNetMenu
  Else
  If Session.User.ThisUser.StartMenu <> '' Then
    Session.Menu.MenuName := Session.User.ThisUser.StartMenu
  Else
    Session.Menu.MenuName := bbsCfg.DefStartMenu;

  Repeat
    Session.Menu.ExecuteMenu (True, True, False, True);
  Until False;
End.

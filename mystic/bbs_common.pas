Unit bbs_Common;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF WINDOWS}
    m_io_Base,
    m_io_Sockets,
  {$ENDIF}
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  m_Types,
  m_Strings,
  m_Output,
  m_Input,
  m_DateTime,
  m_FileIO;

{$I RECORDS.PAS}

// This unit is very old (like 1994) and its functions need to be phased out
// This is the stuff that hasn't been worked into a class somewhere or
// replace with MDL/FP RTL functions

Const
  WinConsoleTitle = mysSoftwareID + ' Node ';
  CopyID          = 'Copyright (C) ' + mysCopyYear + ' By James Coyle';
  DateTypeStr : Array[1..4] of String[8] = ('MM/DD/YY', 'DD/MM/YY', 'YY/DD/MM', 'Ask     ');

Var
  Screen      : TOutput;
  Input       : TInput;
  CurRoom     : Byte;
  ConfigFile  : File of RecConfig;
  ChatFile    : File of ChatRec;
  RoomFile    : File of RoomRec;
  Chat        : ChatRec;
  Room        : RoomRec;
  LastOnFile  : File of RecLastOn;
  LastOn      : RecLastOn;
  Config      : RecConfig;
  StatusPtr   : Byte = 1;

Function  DrawAccessFlags (Var Flags: AccessFlagType) : String;
Procedure KillRecord      (Var dFile; RecNum: LongInt; RecSize: Word);
Procedure AddRecord       (var dFile; RecNum: LongInt; RecSize: Word);
Function  Bool_Search     (Mask: String; Str: String) : Boolean;
Function  strAddr2Str     (Addr: RecEchoMailAddr) : String;
Function  strStr2Addr     (S : String; Var Addr: RecEchoMailAddr) : Boolean;
Function  ShellDOS        (ExecPath: String; Command: String) : LongInt;

{$IFNDEF UNIX}
Procedure UpdateStatusLine    (Mode: Byte; Str: String);
Procedure ProcessSysopCommand (Cmd: Char);
{$ENDIF}

Implementation

Uses
  DOS,
  bbs_Core,
  {$IFNDEF UNIX}
    bbs_SysOpChat,
  {$ENDIF}
  bbs_cfg_UserEdit,
  bbs_General,
  MPL_Execute;

Function DrawAccessFlags (Var Flags: AccessFlagType) : String;
Var
  Ch : Char;
Begin
  Result := '';

  For Ch := 'A' to 'Z' Do
    If Ord(Ch) - 64 in Flags Then
      Result := Result + Ch
    Else
      Result := Result + '-';
End;

Procedure AddRecord (var dFile; RecNum: LongInt; RecSize: Word);
Var
  F      : File Absolute dFile;
  A      : LongInt;
  Buffer : Pointer;
Begin
  If (RecNum < 1) or (RecNum > FileSize(F) + 1) Then Exit;

  GetMem (Buffer, RecSize);

  Dec (RecNum);

  For A := FileSize(F) - 1 DownTo RecNum Do Begin
    Seek       (F, A);
    BlockRead  (F, Buffer^, 1);
    BlockWrite (F, Buffer^, 1);
  End;

  Seek (F, RecNum);

  FreeMem (Buffer, RecSize);
End;

Procedure KillRecord (var dFile; RecNum: LongInt; RecSize: Word);
Var
  F      : File Absolute dFile;
  Count  : LongInt;
  Buffer : Pointer;
Begin
  If (RecNum < 1) or (RecNum > FileSize(F)) Then Exit;

  GetMem (Buffer, RecSize);

  Dec (RecNum);

  For Count := RecNum to FileSize(F) - 2 Do Begin
    Seek       (F, Count + 1);
    BlockRead  (F, Buffer^, 1);
    Seek       (F, Count);
    BlockWrite (F, Buffer^, 1);
  End;

  Seek     (F, FileSize(F) - 1);
  Truncate (F);

  FreeMem (Buffer, RecSize);
End;

Function Bool_Search (Mask: String; Str: String) : Boolean;
{ place holder for this functionality someday... need to pass in a buffer }
{ to search }
Begin
  Bool_Search := True;

  If Mask = '' Then Exit;

  Bool_Search := Pos(strUpper(Mask), strUpper(Str)) > 0;
End;

Function strStr2Addr (S : String; Var Addr: RecEchoMailAddr) : Boolean;
{ converts address string to type.  returns false is invalid string }
Var
  A     : Byte;
  B     : Byte;
  C     : Byte;
  Point : Boolean;
Begin
  Result := False;
  Point  := True;

  A := Pos(':', S);
  B := Pos('/', S);
  C := Pos('.', S);

  If (A = 0) or (B <= A) Then Exit;

  If C = 0 Then Begin
    Point      := False;
    C          := Length(S) + 1;
    Addr.Point := 0;
  End;

  Addr.Zone := strS2I(Copy(S, 1, A - 1));
  Addr.Net  := strS2I(Copy(S, A + 1, B - 1 - A));
  Addr.Node := strS2I(Copy(S, B + 1, C - 1 - B));

  If Point Then Addr.Point := strS2I(Copy(S, C + 1, Length(S)));

  Result := True;
End;

Function strAddr2Str (Addr : RecEchoMailAddr) : String;
Var
  Temp : String[20];
Begin
  Temp := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' +
          strI2S(Addr.Node);

  If Addr.Point <> 0 Then Temp := Temp + '.' + strI2S(Addr.Point);

  Result := Temp;
End;

Function ShellDOS (ExecPath: String; Command: String) : LongInt;
Begin
  Session.SystemLog('DEBUG: In ShellOS for: (' + ExecPath + ') ' + Command);

  Session.io.BufFlush;

  {$IFDEF WINDOWS}
    ExecInheritsHandles := True;
  {$ENDIF}

  If Session.User.UserNum <> -1 Then Begin
    Reset (Session.User.UserFile);
    Seek  (Session.User.UserFile, Session.User.UserNum - 1);
    Write (Session.User.UserFile, Session.User.ThisUser);
    Close (Session.User.UserFile);
  End;

  {$IFNDEF UNIX}
    Screen.SetWindow (1, 1, 80, 25, False);
    Screen.TextAttr := 7;
    Screen.ClearScreen;
  {$ENDIF}

  {$IFDEF UNIX}
    Screen.SetRawMode(False);
  {$ENDIF}

  If ExecPath <> '' Then Begin
    Session.SystemLog('DEBUG: ShellOS changing DIR to: ' + ExecPath);

    DirChange(ExecPath);
  End;

  {$IFDEF UNIX}
    Result := Shell (Command);
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;

    Session.SystemLog('DEBUG: ShellOS EXEC' + GetEnv('COMSPEC') + ' ' + Command);

    Exec (GetEnv('COMSPEC'), Command);
    Result := DosExitCode;

    Session.SystemLog('DEBUG: ShellOS returned: ' + strI2S(Result));
  {$ENDIF}

  {$IFDEF UNIX}
    Screen.SetRawMode(True);
  {$ENDIF}

  {$IFDEF WINDOWS}
    Screen.SetWindowTitle (WinConsoleTitle + strI2S(Session.NodeNum));
  {$ENDIF}

  DirChange(Config.SystemPath);

  If Session.User.UserNum <> -1 Then Begin
    Reset  (Session.User.UserFile);
    Seek   (Session.User.UserFile, Session.User.UserNum - 1);
    Read   (Session.User.UserFile, Session.User.ThisUser);
    Close  (Session.User.UserFile);
  End;

  Reset (Session.PromptFile);

  {$IFNDEF UNIX}
    If Screen.Active Then
      Session.io.LocalScreenEnable
    Else
      Session.io.LocalScreenDisable;
  {$ENDIF}

  Session.TimeOut := TimerSeconds;
End;

{$IFNDEF UNIX}
Procedure UpdateStatusLine (Mode: Byte; Str: String);
Begin
  If Not Config.UseStatusBar Then Exit;

  Screen.SetWindow (1, 1, 80, 25, False);

  Case Mode of
    0 : Screen.WriteXY (1, 25, Config.StatusColor3, strPadC(Str, 80, ' '));
    1 : Begin
          Screen.WriteXY ( 1, 25, Config.StatusColor1, ' Alias ' + strRep(' ', 35) + 'Age       SecLevel      TimeLeft      ');
          Screen.WriteXY ( 8, 25, Config.StatusColor2, Session.User.ThisUser.Handle);
          Screen.WriteXY (47, 25, Config.StatusColor2, Session.User.ThisUser.Gender + '/' + strI2S(DaysAgo(Session.User.ThisUser.Birthday, 1) DIV 365));
          Screen.WriteXY (62, 25, Config.StatusColor2, strI2S(Session.User.ThisUser.Security));
          Screen.WriteXY (76, 25, Config.StatusColor2, strI2S(Session.TimeLeft));
        End;
    2 : Begin
          Screen.WriteXY ( 1, 25, Config.StatusColor1, ' Email ' + strRep(' ', 35) + ' Location ' + strRep(' ', 27) + ' ');
          Screen.WriteXY ( 8, 25, Config.StatusColor2, strPadR(Session.User.ThisUser.Email, 36, ' '));
          Screen.WriteXY (53, 25, Config.StatusColor2, strPadR(Session.User.ThisUser.City, 27, ' '));
        End;
    3 : Begin
          Screen.WriteXY ( 1, 25, Config.StatusColor1, ' IP ' + strRep(' ', 19) + ' Host ' + strRep(' ', 49) + ' ');
          Screen.WriteXY ( 5, 25, Config.StatusColor2, Session.UserIPInfo);
          Screen.WriteXY (31, 25, Config.StatusColor2, strPadR(Session.UserHostInfo, 49, ' '));
        End;
    4 : Begin
          Screen.WriteXY ( 1, 25, Config.StatusColor1, ' Flags 1 ' + strRep(' ', 35) + ' Flags 2 ');
          Screen.WriteXY (10, 25, Config.StatusColor2, DrawAccessFlags(Session.User.ThisUser.AF1));
          Screen.WriteXY (54, 25, Config.StatusColor2, DrawAccessFlags(Session.User.ThisUser.AF2));
        End;
    5 : Screen.WriteXY (1, 25, Config.StatusColor3, '  ALTS/C Chat ALTE Edit ALTH Hangup ALT+/- Time ALTB Info ALTT Bar ALTV Screen  ');
  End;

  Screen.SetWindow (1, 1, 80, 24, False);
End;

Procedure ProcessSysopCommand (Cmd: Char);
Begin
  If Not Screen.Active And (Cmd <> #47) Then Exit;

  Case Cmd of
{E} #18 : If (Not Session.InUserEdit) and (Session.User.UserNum <> -1) Then
            Configuration_LocalUserEdit;
{T} #20 : Begin
            Config.UseStatusBar := Not Config.UseStatusBar;

            If Not Config.UseStatusBar Then Begin
              Screen.WriteXY   (1, 25, 0, strRep(' ', 80));
              Screen.SetWindow (1, 1, 80, 25, False);
            End Else
              UpdateStatusLine (StatusPtr, '');
          End;
{S} #31 : If Not Session.User.InChat Then OpenChat(True);
{H} #35 : Begin
            Session.SystemLog('SysOp hungup on user.');
            Halt(0);
          End;
{C} #46 : If Not Session.User.InChat Then OpenChat(False);
{V} #47 : If Screen.Active Then
            Session.io.LocalScreenDisable
          Else
            Session.io.LocalScreenEnable;
{B} #48 : Begin
            If StatusPtr < 5 Then
              Inc (StatusPtr)
            Else
              StatusPtr := 1;

            UpdateStatusLine (StatusPtr, '');
          End;
    #59..
    #62 : Begin
            Session.io.InMacroStr := Config.SysopMacro[Ord(Cmd) - 58];

            If Session.io.InMacroStr[1] = '!' Then
              ExecuteMPL (NIL, Copy(Session.io.InMacroStr, 2, 255))
            Else Begin
              Session.io.InMacroPos := 1;
              Session.io.InMacro    := Session.io.InMacroStr <> '';
            End;
          End;
{+} #130: If Session.TimeLeft > 1 Then Begin
            Session.SetTimeLeft(Session.TimeLeft-1);
            UpdateStatusLine(StatusPtr, '');
          End;
{-} #131: If Session.TimeLeft < 999 Then Begin
            Session.SetTimeLeft(Session.TimeLeft+1);
            UpdateStatusLine(StatusPtr, '');
          End;
  End;
End;
{$ENDIF}

End.

Unit bbs_Common;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  m_Types,
  m_Strings,
  m_Output,
  m_Input,
  m_DateTime,
  m_FileIO,
  m_Socket_Class;

{$I RECORDS.PAS}

// This unit is very old (like 1994) and its functions need to be phased out
// This is the stuff that hasn't been worked into a class somewhere or
// replace with MDL/FP RTL functions

Const
  WinConsoleTitle = 'Mystic Node ';
  CopyID          = 'Copyright (C) ' + mysCopyYear + ' By James Coyle.  All Rights Reserved.';
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

  If (A = 0) or (B = 0) Then Exit;

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

  If ExecPath <> '' Then DirChange(ExecPath);

  {$IFDEF UNIX}
    Result := Shell (Command);
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;
    Exec (GetEnv('COMSPEC'), Command);
    Result := DosExitCode;
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

  Function DrawAccessFlags (Var Flags : AccessFlagType) : String;
  Var
    S  : String;
    Ch : Char;
  Begin
    S := '';

    For Ch := 'A' to 'Z' Do
      If Ord(Ch) - 64 in Flags Then S := S + Ch Else S := S + '-';

    Result := S;
  End;

Begin
  If Not Config.UseStatusBar Then Exit;

  Screen.SetWindow (1, 1, 80, 25, False);

  Case Mode of
    0 : Screen.WriteXY (1, 25, 120, strPadC(Str, 80, ' '));
    1 : Begin
          Screen.WriteXY ( 1, 25, 112, ' [Alias]                                [Baud]          [Sec]       [Time]      ');
          Screen.WriteXY (10, 25, 112, Session.User.ThisUser.Handle);
          Screen.WriteXY (48, 25, 112, strI2S(Session.Baud));
          Screen.WriteXY (63, 25, 112, strI2S(Session.User.ThisUser.Security));
          Screen.WriteXY (76, 25, 112, strI2S(Session.TimeLeft));
        End;
    2 : Begin
          Screen.WriteXY ( 1, 25, 112, ' [Name]                                [Flag1]                                  ');
          Screen.WriteXY ( 9, 25, 112, Session.User.ThisUser.RealName);
          Screen.WriteXY (48, 25, 112, DrawAccessFlags(Session.User.ThisUser.AF1));
        End;
    3 : Begin
          Screen.WriteXY ( 1, 25, 112, ' [Address]                                                                      ');
          Screen.WriteXY (12, 25, 112, Session.User.ThisUser.Address);
          Screen.WriteXY (43, 25, 112, Session.User.ThisUser.City);
          Screen.WriteXY (69, 25, 112, Session.User.ThisUser.ZipCode);
        End;
    4 : Begin
          Screen.WriteXY ( 1, 25, 112, ' [BDay]           [Sex]     [Home PH]                 [Data PH]                 ');
          Screen.WriteXY ( 9, 25, 112, DateDos2Str(Session.User.ThisUser.Birthday, Session.User.ThisUser.DateType));
          Screen.WriteXY (25, 25, 112, Session.User.ThisUser.Gender);
          Screen.WriteXY (39, 25, 112, Session.User.ThisUser.HomePhone);
          Screen.WriteXY (65, 25, 112, Session.User.ThisUser.DataPhone);
        End;
    5 : Begin
          Screen.WriteXY ( 1, 25, 112, ' [Email]                                     [Flag2]                           ');
          Screen.WriteXY (10, 25, 112, Session.User.ThisUser.Email);
          Screen.WriteXY (54, 25, 112, DrawAccessFlags(Session.User.ThisUser.AF2));
        End;
    6 : Screen.WriteXY ( 1, 25, 112, ' ALT (C)hat  (S)plit  (E)dit  (H)angup  (J) DOS  (U)pgrade  (B) Status Bar      ');
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
            If StatusPtr < 6 Then
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

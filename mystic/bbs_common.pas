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
  CopyID          = 'Copyright (C) 1997-2012 By James Coyle.  All Rights Reserved.';
  DateTypeStr : Array[1..4] of String[8] = ('MM/DD/YY', 'DD/MM/YY', 'YY/DD/MM', 'Ask     ');
  GetKeyFunc  : Function (Forced : Boolean) : Boolean = NIL;

Var
  Screen      : TOutput;
  Input       : TInput;
  CurRoom     : Byte;
  NodeMsgFile : File of NodeMsgRec;
  NodeMsg     : NodeMsgRec;
  ConfigFile  : File of RecConfig;
  ChatFile    : File of ChatRec;
  RoomFile    : File of RoomRec;
  VoteFile    : File of VoteRec;
  Vote        : VoteRec;
  Chat        : ChatRec;
  Room        : RoomRec;
  LastOnFile  : File of RecLastOn;
  LastOn      : RecLastOn;
  Config      : RecConfig;
  StatusPtr   : Byte = 1;

Procedure EditAccessFlags (Var Flags : AccessFlagType);
Function  DrawAccessFlags (Var Flags : AccessFlagType) : String;
Function  NoGetKeyFunc    (Forced : Boolean) : Boolean;
Function  getColor        (A: Byte) : Byte;
Procedure KillRecord      (Var dFile; RecNum: LongInt; RecSize: Word);
Procedure AddRecord       (var dFile; RecNum: LongInt; RecSize: Word);
Function  Bool_Search     (Mask: String; Str: String) : Boolean;
Function  strAddr2Str     (Addr: RecEchoMailAddr) : String;
Function  strStr2Addr     (S : String; Var Addr: RecEchoMailAddr) : Boolean;
Function  CheckPath       (Str: String) : String;
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

Function DrawAccessFlags (Var Flags : AccessFlagType) : String;
Var
  S  : String;
  Ch : Char;
Begin
  S := '';

  For Ch := 'A' to 'Z' Do
    If Ord(Ch) - 64 in Flags Then S := S + Ch Else S := S + '-';

  DrawAccessFlags := S;
End;

Procedure EditAccessFlags (Var Flags : AccessFlagType);
Var
  Ch : Char;
Begin
  Repeat
    Session.io.OutFull ('Toggle: [' + DrawAccessFlags(Flags) + '] (Enter/Done): ');

    Ch := Session.io.OneKey('ABCDEFGHIJKLMNOPQRSTUVWXYZ'#13, True);

    If Ch = #13 Then Break;

    If Ord(Ch) - 64 in Flags Then
      Flags := Flags - [Ord(Ch) - 64]
    Else
      Flags := Flags + [Ord(Ch) - 64];
  Until False;
End;

Function GetColor (A: Byte) : Byte;
{ Used by SYSOPx.PAS files only }
Var
  FG,
  BG : Byte;
Begin
  Session.io.OutFull ('|CRFG Color: ');
  FG := strS2I(Session.io.GetInput(2, 2, 12, strI2S(A AND $F)));
  Session.io.OutFull ('BG Color: ');
  BG := strS2I(Session.io.GetInput(2, 2, 12, strI2S((A SHR 4) AND 7)));
  getColor := FG + BG * 16;
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

Function NoGetKeyFunc (Forced : Boolean): Boolean;
Begin
  Result := False;
End;

Function CheckPath (Str: String) : String;
Begin
  While Str[Length(Str)] = PathChar Do Dec(Str[0]);

  If Not DirExists(Str) Then Begin
    If Session.io.GetYN ('|CR|12Directory doesn''t exist.  Create? |11', True) Then Begin

      {$I-} MkDir (Str); {$I+}

      If IoResult <> 0 Then
        Session.io.OutFull ('|CR|14Error creating directory!|CR|PA');
    End;
  End;

  CheckPath := Str + PathChar;
End;

Function ShellDOS (ExecPath: String; Command: String) : LongInt;
  {$IFNDEF UNIX}
  Var
    Image : TConsoleImageRec;
  {$ENDIF}
Begin
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
  Screen.GetScreenImage(1, 1, 80, 25, Image);
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
  Screen.PutScreenImage(Image);
  UpdateStatusLine(StatusPtr, '');
  {$ENDIF}

  Session.TimeOut  := TimerSeconds;
End;

{$IFNDEF UNIX}
Procedure UpdateStatusLine (Mode: Byte; Str: String);
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
Var
  A  : Integer;
  X,
  Y  : Byte;
  LS : Boolean;
Begin
  If Not Screen.Active And (Cmd <> #47) Then Exit;

  Case Cmd of
{U} #22 : Begin
            X := Screen.CursorX;
            Y := Screen.CursorY;
            UpdateStatusLine (0, 'Upgrade Security Level: ');
            Screen.SetWindow (1, 25, 80, 25, False);
            Screen.TextAttr := 8 + 7 * 16;
            Screen.CursorXY (52, 2);
            LS := Session.LocalMode;
            Session.LocalMode := True;
            A := strS2I(Session.io.GetInput(3, 3, 9, strI2S(Session.User.ThisUser.Security)));
            Session.LocalMode := LS;
            If (A > 0) and (A < 256) Then Begin
              Upgrade_User_Level (True, Session.User.ThisUser, A);
              Session.SetTimeLeft(Session.User.ThisUser.TimeLeft);
            End;

            UpdateStatusLine(StatusPtr, '');

            Screen.CursorXY (X, Y);
          End;
{E} #18 : If (Not Session.InUserEdit) and (Session.User.UserNum <> -1) Then User_Editor(True, True);
{T} #20 : Begin
//            X := Screen.CursorX;
//            Y := Screen.CursorY;

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

Begin
  GetKeyFunc := NoGetKeyFunc;
End.

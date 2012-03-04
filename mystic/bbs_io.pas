Unit BBS_IO;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF WINDOWS}
    Windows,
    WinSock2,
  {$ENDIF}
  m_Types,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_Term_Ansi,
  bbs_Common;

Const
  TBBSIOBufferSize = 4 * 1024 - 1;
  MaxPromptInfo    = 15;

Type
  TBBSIO = Class
    Core         : Pointer;
    Term         : TTermAnsi;
    ScreenInfo   : Array[0..9] of Record X, Y, A : Byte; End;
    PromptInfo   : Array[1..MaxPromptInfo] of String[89];
    FmtString    : Boolean;
    FmtLen       : Byte;
    FmtType      : Byte;
    InMacro      : Boolean;
    InMacroPos   : Byte;
    InMacroStr   : String;
    BaudEmulator : Byte;
    AllowPause   : Boolean;
    AllowMCI     : Boolean;
    LocalInput   : Boolean;
    AllowArrow   : Boolean;
    IsArrow      : Boolean;
    UseInField   : Boolean;
    UseInLimit   : Boolean;
    UseInSize    : Boolean;
    InLimit      : Byte;
    InSize       : Byte;
    AllowAbort   : Boolean;
    Aborted      : Boolean;
    NoFile       : Boolean;
    Graphics     : Byte;
    PausePtr     : Byte;
    InputData    : Array[1..mysMaxInputHistory] of String[255];
    LastMCIValue : String;
    InputPos     : Byte;

    {$IFDEF WINDOWS}
    OutBuffer    : Array[0..TBBSIOBufferSize] of Char;
    OutBufPos    : SmallInt;
    SocketEvent  : THandle;
    {$ENDIF}

    Constructor Create (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Procedure   BufAddChar       (Ch: Char);
    Procedure   BufAddStr        (Str: String);
    Procedure   BufFlush;
    Function    ParseMCI         (Display : Boolean; Code: String) : Boolean;
    Function    StrMci           (Str: String) : String;
    Function    Attr2Ansi        (Attr: Byte) : String;
    Function    Pipe2Ansi        (Color : Byte) : String;
    Procedure   AnsiGotoXY       (X : Byte; Y:Byte);
    Procedure   AnsiMoveX        (X : Byte);
    Procedure   AnsiMoveY        (Y : Byte);
    Procedure   AnsiColor        (A : Byte);
    Procedure   AnsiClear;
    Procedure   AnsiClrEOL;
    Procedure   OutPipe          (Str: String);
    Procedure   OutPipeLn        (Str: String);
    Procedure   OutRaw           (Str : String);
    Procedure   OutRawLn         (Str: String);
    Procedure   OutBS            (Num : Byte; Del: Boolean);
    Procedure   OutFull          (Str : String);
    Procedure   OutFullLn        (Str : String);
    Procedure   OutFile          (FName : String; DoPause: Boolean; Speed: Byte);
    Function    OutYN            (Y : Boolean) : String;
    Function    OutON            (O : Boolean) : String;
    Procedure   PauseScreen;
    Function    MorePrompt       : Char;
    Function    DrawPercent      (Bar : RecPercent; Part, Whole : SmallInt; Var Percent : SmallInt) : String;
    Function    GetInput         (Field, Max, Mode: Byte; Default : String) : String;
    Function    InXY             (X, Y, Field, Max, Mode: Byte; Default: String) : String;
    Function    InKey            : Char;
    Function    GetYNL           (Str: String; Yes: Boolean) : Boolean;
    Function    GetKey           : Char;
    Function    GetYN            (Str: String; Yes: Boolean) : Boolean;
    Function    GetPW            (Str : String; BadStr : String; PW : String) : Boolean;
    Function    OneKey           (Str: String; Echo: Boolean) : Char;
    Procedure   RemoteRestore    (Var Image: TConsoleImageRec);
    Procedure   PurgeInputBuffer;

    {$IFDEF WINDOWS}
    Procedure   LocalScreenDisable;
    Procedure   LocalScreenEnable;
    {$ENDIF}
  End;

Implementation

Uses
  DOS,
  bbs_Core,
  bbs_General;

Constructor TBBSIO.Create (Var Owner: Pointer);
Begin
  Core          := Owner;
  FmtString     := False;
  FmtLen        := 0;
  FmtType       := 0;
  InMacro       := False;
  InMacroPos    := 0;
  InMacroStr    := '';
  AllowPause    := False;
  AllowMCI      := True;
  LocalInput    := False;
  AllowArrow    := False;
  IsArrow       := False;
  UseInField    := True;
  UseInLimit    := False;
  UseInSize     := False;
  InLimit       := 0;
  InSize        := 0;
  AllowAbort    := False;
  Aborted       := False;
  NoFile        := False;
  Graphics      := 1;
  PausePtr      := 1;
  LastMCIValue  := '';
  InputPos      := 0;

  {$IFDEF WINDOWS}
    FillChar(OutBuffer, SizeOf(OutBuffer), 0);
    OutBufPos := 0;

    If Not TBBSCore(Core).LocalMode Then
      SocketEvent := WSACreateEvent;
  {$ENDIF}

  Term := TTermAnsi.Create(Screen);
End;

Destructor TBBSIO.Destroy;
Begin
  {$IFDEF WINDOWS}
    If Not TBBSCore(Core).LocalMode Then WSACloseEvent(SocketEvent);
  {$ENDIF}

  Term.Free;

  Inherited Destroy;
End;

Procedure TBBSIO.BufAddChar (Ch: Char);
Begin
  {$IFDEF WINDOWS}
  OutBuffer[OutBufPos] := Ch;

  Inc (OutBufPos);

  If OutBufPos = TBBSIOBufferSize Then BufFlush;
  {$ENDIF}

  Term.Process(Ch);
End;

Procedure TBBSIO.BufAddStr (Str: String);
Var
  Count : Word;
Begin
  For Count := 1 to Length(Str) Do
    BufAddChar(Str[Count]);
End;

Procedure TBBSIO.BufFlush;
Var
  Res : LongInt;
Begin
  {$IFDEF WINDOWS}
  If OutBufPos > 0 Then Begin
    If Not TBBSCore(Core).LocalMode Then Begin
      Res := TBBSCore(Core).Client.WriteBuf(OutBuffer, OutBufPos);

      While (Res = -1) and (WSAGetLastError = EWOULDBLOCK) Do Begin
        WaitMS(10);
        Res := TBBSCore(Core).Client.WriteBuf(OutBuffer, OutBufPos);
      End;
    End;

    OutBufPos := 0;
  End;
  {$ENDIF}

  {$IFDEF UNIX}
    Screen.BufFlush;
  {$ENDIF}
End;

Procedure TBBSIO.AnsiMoveY (Y : Byte);
Var
  T : Byte;
Begin
  If Graphics = 0 Then Exit;

  T := Screen.CursorY;

  If Y > T Then BufAddStr (#27 + '[' + strI2S(Y-T) + 'B') Else
  If Y < T Then BufAddStr (#27 + '[' + strI2S(T-Y) + 'A');
End;

Procedure TBBSIO.AnsiMoveX (X : Byte);
Var
  T : Byte;
Begin
  If Graphics = 0 Then Exit;

  T := Screen.CursorX;

  If X > T Then BufAddStr (#27 + '[' + strI2S(X-T) + 'C') Else
  If X < T Then BufAddStr (#27 + '[' + strI2S(T-X) + 'D');
End;

Procedure TBBSIO.PauseScreen;
Var
  Attr : Byte;
  Ch   : Char;
Begin
  Attr := Screen.TextAttr;

  OutFull (TBBSCore(Core).GetPrompt(22));

  PurgeInputBuffer;

  Repeat
    Ch := GetKey;
  Until Ch <> '';

  AnsiColor(Attr);

  BufAddStr(#13#10);
End;

Function TBBSIO.MorePrompt : Char;
Var
  SavedAttr : Byte;
  SavedMCI  : Boolean;
  Ch        : Char;
Begin
  SavedMCI  := AllowMCI;
  AllowMCI  := True;
  SavedAttr := Screen.TextAttr;

  OutFull (TBBSCore(Core).GetPrompt(132));

  PurgeInputBuffer;

  Ch := OneKey('YNC' + #13, False);

  OutBS     (Screen.CursorX, True);
  AnsiColor (SavedAttr);

  PausePtr := 1;
  AllowMCI := SavedMCI;
  Result   := Ch;
End;

Procedure TBBSIO.OutBS (Num: Byte; Del: Boolean);
Var
  A   : Byte;
  Str : String[7];
Begin
  If Del Then Str := #8#32#8 Else Str := #8;

  For A := 1 to Num Do
    OutRaw (Str);
End;

Procedure TBBSIO.OutPipe (Str: String);
Var
  Count : Byte;
  Code  : String[2];
Begin
  If FmtString Then Begin
    FmtString := False;
    Case FmtType of
      1  : Str := strPadR(Str, FmtLen + Length(Str) - Length(strStripPipe(Str)), ' ');
      2  : Str := strPadL(Str, FmtLen + Length(Str) - Length(strStripPipe(Str)), ' ');
      3  : Str := strPadC(Str, FmtLen + Length(Str) - Length(strStripPipe(Str)), ' ');
    End;
  End;

  Count := 1;

  While Count <= Length(Str) Do Begin
    If (Str[Count] = '|') and (Count < Length(Str) - 1) Then Begin
      Code := Copy(Str, Count + 1, 2);
      If Code = '00' Then BufAddStr(Pipe2Ansi(0)) Else
      If Code = '01' Then BufAddStr(Pipe2Ansi(1)) Else
      If Code = '02' Then BufAddStr(Pipe2Ansi(2)) Else
      If Code = '03' Then BufAddStr(Pipe2Ansi(3)) Else
      If Code = '04' Then BufAddStr(Pipe2Ansi(4)) Else
      If Code = '05' Then BufAddStr(Pipe2Ansi(5)) Else
      If Code = '06' Then BufAddStr(Pipe2Ansi(6)) Else
      If Code = '07' Then BufAddStr(Pipe2Ansi(7)) Else
      If Code = '08' Then BufAddStr(Pipe2Ansi(8)) Else
      If Code = '09' Then BufAddStr(Pipe2Ansi(9)) Else
      If Code = '10' Then BufAddStr(Pipe2Ansi(10)) Else
      If Code = '11' Then BufAddStr(Pipe2Ansi(11)) Else
      If Code = '12' Then BufAddStr(Pipe2Ansi(12)) Else
      If Code = '13' Then BufAddStr(Pipe2Ansi(13)) Else
      If Code = '14' Then BufAddStr(Pipe2Ansi(14)) Else
      If Code = '15' Then BufAddStr(Pipe2Ansi(15)) Else
      If Code = '16' Then BufAddStr(Pipe2Ansi(16)) Else
      If Code = '17' Then BufAddStr(Pipe2Ansi(17)) Else
      If Code = '18' Then BufAddStr(Pipe2Ansi(18)) Else
      If Code = '19' Then BufAddStr(Pipe2Ansi(19)) Else
      If Code = '20' Then BufAddStr(Pipe2Ansi(20)) Else
      If Code = '21' Then BufAddStr(Pipe2Ansi(21)) Else
      If Code = '22' Then BufAddStr(Pipe2Ansi(22)) Else
      If Code = '23' Then BufAddStr(Pipe2Ansi(23)) Else
      BufAddStr(Str[Count] + Code);
      Inc (Count, 2);
    End Else
      BufAddChar(Str[Count]);

    Inc (Count);
  End;
End;

Procedure TBBSIO.OutPipeLn (Str : String);
Begin
  OutPipe (Str + #13#10);
  Inc (PausePtr);
End;

Procedure TBBSIO.OutRaw (Str: String);
Begin
  If FmtString Then Begin

    FmtString := False;

    Case FmtType of
      1 : Str := strPadR(Str, FmtLen, ' ');
      2 : Str := strPadL(Str, FmtLen, ' ');
      3 : Str := strPadC(Str, FmtLen, ' ');
    End;
  End;

  BufAddStr(Str);
End;

Procedure TBBSIO.OutRawLn (Str: String);
Begin
  BufAddStr (Str + #13#10);
  Inc (PausePtr);
End;

Function TBBSIO.ParseMCI (Display: Boolean; Code: String) : Boolean;
Var
  A : LongInt;
Begin
  LastMCIValue := #255;
  Result       := True;

  If Not AllowMCI Then Begin
    Result := False;
    Exit;
  End;

  Case Code[1] of
    '!' : If Code[2] in ['0'..'9'] Then Begin
            A := strS2I(Code[2]);

            ScreenInfo[A].X := Screen.CursorX;
            ScreenInfo[A].Y := Screen.CursorY;
            ScreenInfo[A].A := Screen.TextAttr;
          End Else Begin
            Result := False;

            Exit;
          End;
    '$' : Case Code[2] of
            'C' : Begin
                    FmtString := True;
                    FmtType   := 3;
                  End;
            'D' : Begin
                    FmtString := True;
                    FmtType   := 4;
                  End;
            'L' : Begin
                    FmtString := True;
                    FmtType   := 2;
                  End;
            'R' : Begin
                    FmtString := True;
                    FmtType   := 1;
                  End;
          End;
    '&' : Case Code[2] of
            '1' : LastMCIValue := PromptInfo[1];
            '2' : LastMCIValue := PromptInfo[2];
            '3' : LastMCIValue := PromptInfo[3];
            '4' : LastMCIValue := PromptInfo[4];
            '5' : LastMCIValue := PromptInfo[5];
            '6' : LastMCIValue := PromptInfo[6];
            '7' : LastMCIValue := PromptInfo[7];
            '8' : LastMCIValue := PromptInfo[8];
            '9' : LastMCIValue := PromptInfo[9];
            '0' : LastMCIValue := PromptInfo[10];
            'A' : LastMCIValue := PromptInfo[11];
            'B' : LastMCIValue := PromptInfo[12];
            'C' : LastMCIValue := PromptInfo[13];
            'D' : LastMCIValue := PromptInfo[14];
            'E' : LastMCIValue := PromptInfo[15];
          End;
    '0' : Case Code[2] of
            '0' : LastMCIValue := Pipe2Ansi(0);
            '1' : LastMCIValue := Pipe2Ansi(1);
            '2' : LastMCIValue := Pipe2Ansi(2);
            '3' : LastMCIValue := Pipe2Ansi(3);
            '4' : LastMCIValue := Pipe2Ansi(4);
            '5' : LastMCIValue := Pipe2Ansi(5);
            '6' : LastMCIValue := Pipe2Ansi(6);
            '7' : LastMCIValue := Pipe2Ansi(7);
            '8' : LastMCIValue := Pipe2Ansi(8);
            '9' : LastMCIValue := Pipe2Ansi(9);
          End;
    '1' : Case Code[2] of
            '0' : LastMCIValue := Pipe2Ansi(10);
            '1' : LastMCIValue := Pipe2Ansi(11);
            '2' : LastMCIValue := Pipe2Ansi(12);
            '3' : LastMCIValue := Pipe2Ansi(13);
            '4' : LastMCIValue := Pipe2Ansi(14);
            '5' : LastMCIValue := Pipe2Ansi(15);
            '6' : LastMCIValue := Pipe2Ansi(16);
            '7' : LastMCIValue := Pipe2Ansi(17);
            '8' : LastMCIValue := Pipe2Ansi(18);
            '9' : LastMCIValue := Pipe2Ansi(19);
          End;
    '2' : Case Code[2] of
            '0' : LastMCIValue := Pipe2Ansi(20);
            '1' : LastMCIValue := Pipe2Ansi(21);
            '2' : LastMCIValue := Pipe2Ansi(22);
            '3' : LastMCIValue := Pipe2Ansi(23);
          End;
    'A' : Case Code[2] of
            'G' : LastMCIValue := strI2S(DaysAgo(TBBSCore(Core).User.ThisUser.Birthday) DIV 365);
            'S' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.SigUse);
            'V' : LastMCIValue := OutYN(Chat.Available);
          End;
    'B' : Case Code[2] of
            'D' : If TBBSCore(Core).LocalMode Then
                    LastMCIValue := 'LOCAL' {++lang add these to lang file }
                  Else
                    LastMCIValue := 'TELNET'; {++lang }
            'E' : LastMCIValue := ^G;
            'I' : LastMCIValue := DateJulian2Str(TBBSCore(Core).User.ThisUser.Birthday, TBBSCore(Core).User.ThisUser.DateType);
            'N' : LastMCIValue := Config.BBSName;
            'S' : OutBS(1, True);
          End;
    'C' : Case Code[2] of
            'L' : AnsiClear;
            'M' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.UseFullChat);
            'R' : OutRawLn ('');
            'S' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.Calls);
            'T' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.CallsToday);
          End;
    'D' : Case Code[2] of
            'A' : LastMCIValue := DateDos2Str(CurDateDos, TBBSCore(Core).User.ThisUser.DateType);
            'E' : Begin
                    BufFlush;
                    WaitMS(500);
                  End;
            'F' : Begin
                    FmtString := True;
                    FmtType   := 5;
                  End;
            'I' : Begin
                    FmtString := True;
                    FmtType   := 16;
                  End;
            'K' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.DLk);
            'L' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.DLs);
            'T' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.DLsToday);
          End;
    'F' : Case Code[2] of
            'B' : LastMCIValue := TBBSCore(Core).FileBase.FBase.Name;
            'G' : LastMCIValue := TBBSCore(Core).FileBase.FGroup.Name;
            'K' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.ULk);
            'O' : LastMCIValue := DateDos2Str(TBBSCore(Core).User.ThisUser.FirstOn, TBBSCore(Core).User.ThisUser.DateType);
            'U' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.ULs);
          End;
    'H' : Case Code[2] of
            'K' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.HotKeys);
          End;
    'I' : Case Code[2] of
            'F' : UseInField := False;
            'N' : Begin
                    FmtString := True;
                    FmtType   := 12;
                  End;
            'L' : LastMCIValue := OutON(Chat.Invisible);
            'S' : Begin
                    FmtString := True;
                    FmtType   := 14;
                  End;
          End;
    'K' : Case Code[2] of
            'T' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.DLkToday);
          End;
    'L' : Case Code[2] of
            'O' : LastMCIValue := DateDos2Str(TBBSCore(Core).User.ThisUser.LastOn, TBBSCore(Core).User.ThisUser.DateType);
          End;
    'M' : Case Code[2] of
            'B' : LastMCIValue := TBBSCore(Core).Msgs.MBase.Name;
            'E' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.Emails);
            'G' : LastMCIValue := TBBSCore(Core).Msgs.Group.Name;
            'L' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.UseLBIndex);
            'N' : LastMCIValue := Config.NetDesc[TBBSCore(Core).Msgs.MBase.NetAddr];
            'P' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.Posts);
            'T' : LastMCIValue := strI2S(TBBSCore(Core).Msgs.GetTotalMessages(TBBSCore(Core).Msgs.MBase));
          End;
    'N' : Case Code[2] of
            'D' : LastMCIValue := strI2S(TBBSCore(Core).NodeNum);
            'E' : LastMCIValue := strI2S(TBBSCore(Core).MinutesUntilEvent(TBBSCore(Core).NextEvent.ExecTime));
          End;
    'O' : Case Code[2] of
            'S' : LastMCIValue := OSID;
          End;
    'P' : Case Code[2] of
            'A' : PauseScreen;
            'B' : PurgeInputBuffer;
            'C' : Begin
                    A := 0;
                    If TBBSCore(Core).User.ThisUser.Calls > 0 Then
                      A := Round(TBBSCore(Core).User.ThisUser.Posts / TBBSCore(Core).User.ThisUser.Calls * 100);
                    LastMCIValue := strI2S(A);
                  End;
            'I' : BufAddChar('|');
            'N' : Repeat Until GetKey <> '';
            'O' : AllowPause := False;
            'W' : LastMCIValue := strI2S(Config.PWChange);
          End;
    'Q' : Case Code[2] of
            'A' : LastMCIValue := TBBSCore(Core).User.ThisUser.Archive;
            'L' : LastMCIValue := OutYN (TBBSCore(Core).User.ThisUser.QwkFiles);
            'O' : ShowRandomQuote;
          End;
    'R' : Case Code[2] of
            'D' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.DLRatio);
            'K' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.DLkRatio);
            'P' : Begin
                    FmtString := True;
                    FmtType   := 13;
                  End;
          End;
    'S' : Case Code[2] of
            'B' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.MaxTB);
            'C' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.MaxCalls);
            'D' : LastMCIValue := TBBSCore(Core).User.Security.Desc;
            'K' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.MaxDLK);
            'L' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.Security);
            'N' : LastMCIValue := Config.SysopName;
            'P' : Begin
                    A := Round(TBBSCore(Core).User.Security.PCRatio / 100 * 100);
                    LastMCIValue := strI2S(A);
                  End;
            'T' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.Time);
            'X' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.MaxDLs);
          End;
    'T' : Case Code[2] of
            'B' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.TimeBank);
            'C' : LastMCIValue := strI2S(Config.SystemCalls);
            'E' : If Graphics = 1 Then LastMCIValue := 'Ansi' Else LastMCIValue := 'Ascii'; //++lang
            'I' : LastMCIValue := TimeDos2Str(CurDateDos, True);
            'L' : LastMCIValue := strI2S(TBBSCore(Core).TimeLeft);
            'O' : LastMCIValue := strI2S(TBBSCore(Core).ElapsedTime);
          End;
    'U' : Case Code[2] of
            '#' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.PermIdx);
            '1' : LastMCIValue := TBBSCore(Core).User.ThisUser.OptionData[1];
            '2' : LastMCIValue := TBBSCore(Core).User.ThisUser.OptionData[2];
            '3' : LastMCIValue := TBBSCore(Core).User.ThisUser.OptionData[3];
            'A' : LastMCIValue := TBBSCore(Core).User.ThisUser.Address;
            'B' : Case TBBSCore(Core).User.ThisUser.FileList of
                    0 : LastMCIValue := 'Normal';
                    1 : LastMCIValue := 'Lightbar'; {++lang}
                  End;
            'C' : LastMCIValue := TBBSCore(Core).User.ThisUser.City;
            'D' : LastMCIValue := TBBSCore(Core).User.ThisUser.DataPhone;
            'E' : Case TBBSCore(Core).User.ThisUser.EditType of
                    0 : LastMCIValue := 'Line'; {++lang}
                    1 : LastMCIValue := 'Full';
                    2 : LastMCIValue := 'Ask';
                  End;
            'F' : LastMCIValue := DateTypeStr[TBBSCore(Core).User.ThisUser.DateType];
            'G' : If TBBSCore(Core).User.ThisUser.Gender = 'M' Then
                    LastMCIValue := 'Male'
                  Else
                    LastMCIValue := 'Female';  {++lang}
            'H' : LastMCIValue := TBBSCore(Core).User.ThisUser.Handle;
            'I' : LastMCIValue := TBBSCore(Core).User.ThisUser.UserInfo;
            'J' : Case TBBSCore(Core).User.ThisUser.MReadType of
                    0 : LastMCIValue := 'Normal';
                    1 : LastMCIValue := 'Lightbar'; {++lang}
                  End;
            'K' : LastMCIValue := TBBSCore(Core).User.ThisUser.Email;
            'L' : LastMCIValue := TBBSCore(Core).Lang.Desc;
            'M' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.UseLBMIdx);
            'N' : LastMCIValue := TBBSCore(Core).User.ThisUser.RealName;
            'P' : LastMCIValue := TBBSCore(Core).User.ThisUser.HomePhone;
            'Q' : Case TBBSCore(Core).User.ThisUser.UseLBQuote of
                    False : LastMCIValue := 'Standard';
                    True  : LastMCIValue := 'Lightbar'; {++langfile++}
                  End;
            'S' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.ScreenSize);
            'X' : LastMCIValue := TBBSCore(Core).UserHostInfo;
            'Y' : LastMCIValue := TBBSCore(Core).UserIPInfo;
            'Z' : LastMCIValue := TBBSCore(Core).User.ThisUser.ZipCode;
          End;
    'V' : Case Code[2] of
            'R' : LastMCIValue := mysVersion;
          End;
    'X' : Case Code[2] of
            'D' : If DateValid(Session.User.ThisUser.Expires) Then
                    LastMCIValue := strI2S(Abs(CurDateJulian - DateStr2Julian(Session.User.ThisUser.Expires)))
                  Else
                    LastMCIValue := '0';
            'S' : LastMCIValue := strI2S(Session.User.ThisUser.ExpiresTo);
            'X' : LastMCIValue := '';
          End;
    '[' : Case Code[2] of
            'A' : Begin
                    FmtString := True;
                    FmtType   := 8;
                  End;
            'B' : Begin
                    FmtString := True;
                    FmtType   := 9;
                  End;
            'C' : Begin
                    FmtString := True;
                    FmtType   := 10;
                  End;
            'D' : Begin
                    FmtString := True;
                    FmtType   := 11;
                  End;
            'K' : AnsiClrEOL;
            'L' : Begin
                    FmtString := True;
                    FmtType   := 15;
                  End;
            'X' : Begin
                    FmtString := True;
                    FmtType   := 6;
                  End;
            'Y' : Begin
                    FmtString := True;
                    FmtType   := 7;
                  End;
          End;
  Else
    Result := False;
  End;

  If Display And (LastMCIValue <> #255) Then
    OutPipe(LastMCIValue);
End;

Procedure TBBSIO.OutFull (Str : String);
Var
  A : Byte;
  B : Byte;
  D : DirStr;
  N : NameStr;
  E : ExtStr;
Begin
  A := 1;

  While A <= Length(Str) Do Begin
    If (Str[A] = '|') and (A < Length(Str) - 1) Then Begin

      If Not ParseMCI (True, Copy(Str, A + 1, 2)) Then Begin
        BufAddChar(Str[A]);
        Inc(A);
        Continue;
      End;

      Inc (A, 2);

      If FmtString Then Begin
        If FmtType = 5 Then Begin
          FmtString := False;

          B := A + 1;

          While (Str[B] <> ' ') and (Str[B] <> '|') and (B <= Length(Str)) Do
            Inc (B);

          FSplit  (strStripLOW(Copy(Str, A + 1, B - A - 1)), D, N, E);
          OutFile (TBBSCore(Core).Lang.TextPath + N + E, True, 0);

          A := B;

          Continue;
        End;

        FmtLen := strS2I(Copy(Str, A + 1, 2));
        Inc (A, 2);

        Case FmtType of
          4 : Begin
                Inc (A);
                FmtString := False;
                BufAddStr (strRep(Str[A], FmtLen));
              End;
          6 : Begin
                AnsiMoveX (FmtLen);
                FmtString := False;
              End;
          7 : Begin
                AnsiMoveY (FmtLen);
                FmtString := False;
              End;
          8 : Begin
                AnsiMoveY (Screen.CursorY - FmtLen);
                FmtString := False;
              End;
          9 : Begin
                AnsiMoveY (Screen.CursorY + FmtLen);
                FmtString := False;
              End;
          10: Begin
                AnsiMoveX (Screen.CursorX + FmtLen);
                FmtString := False;
              End;
          11: Begin
                AnsiMoveX (Screen.CursorX - FmtLen);
                FmtString := False;
              End;
          12: Begin
                UseInLimit := True;
                InLimit    := FmtLen;
                FmtString  := False;
              End;
          13: Begin
                PausePtr  := FmtLen;
                FmtString := False;
              End;
          14: Begin
                UseInSize := True;
                InSize    := FmtLen;
                FmtString := False;
              End;
          15: Begin
                While Screen.CursorX > FmtLen Do
                  OutBS(1, True);

                FmtString := False;
              End;
        End;
      End;
    End Else
      BufAddChar (Str[A]);

    Inc(A);
  End;
End;

Procedure TBBSIO.OutFullLn (Str : String);
Begin
  OutFull (Str + #13#10);
  Inc (PausePtr);
End;

Procedure TBBSIO.AnsiClrEOL;
Begin
  BufAddStr (#27 + '[K');
End;

Function TBBSIO.Pipe2Ansi (Color: Byte) : String;
Var
  CurFG  : Byte;
  CurBG  : Byte;
  Prefix : String[2];
Begin
  Result := '';

  If Graphics = 0 Then Exit;

  CurBG  := (Screen.TextAttr SHR 4) AND 7;
  CurFG  := Screen.TextAttr AND $F;
  Prefix := '';

  If Color < 16 Then Begin
    If Color = CurFG Then Exit;

//    Screen.TextAttr := Color + CurBG * 16;

    If (Color < 8) and (CurFG > 7) Then Prefix := '0;';
    If (Color > 7) and (CurFG < 8) Then Prefix := '1;';
    If Color > 7 Then Dec(Color, 8);

    Case Color of
      00: Result := #27 + '[' + Prefix + '30';
      01: Result := #27 + '[' + Prefix + '34';
      02: Result := #27 + '[' + Prefix + '32';
      03: Result := #27 + '[' + Prefix + '36';
      04: Result := #27 + '[' + Prefix + '31';
      05: Result := #27 + '[' + Prefix + '35';
      06: Result := #27 + '[' + Prefix + '33';
      07: Result := #27 + '[' + Prefix + '37';
    End;

    If Prefix <> '0;' Then
      Result := Result + 'm'
    Else
      Case CurBG of
        00: Result := Result + ';40m';
        01: Result := Result + ';44m';
        02: Result := Result + ';42m';
        03: Result := Result + ';46m';
        04: Result := Result + ';41m';
        05: Result := Result + ';45m';
        06: Result := Result + ';43m';
        07: Result := Result + ';47m';
      End;
  End Else Begin
    If (Color - 16) = CurBG Then Exit;

//    Screen.TextAttr := CurFG + (Color - 16) * 16;

    Case Color of
      16: Result := #27 + '[40m';
      17: Result := #27 + '[44m';
      18: Result := #27 + '[42m';
      19: Result := #27 + '[46m';
      20: Result := #27 + '[41m';
      21: Result := #27 + '[45m';
      22: Result := #27 + '[43m';
      23: Result := #27 + '[47m';
    End;
  End;
End;

Function TBBSIO.Attr2Ansi (Attr: Byte) : String;
Begin
  Result := '';

  If Graphics = 0 Then Exit;

  Result := Pipe2Ansi(Attr AND $F) + Pipe2Ansi(((Attr SHR 4) AND 7) + 16);
End;

Procedure TBBSIO.AnsiColor (A : Byte);
Begin
  If Graphics = 0 Then Exit;

  BufAddStr(Attr2Ansi(A));
End;

Procedure TBBSIO.AnsiGotoXY (X: Byte; Y: Byte);
Begin
  If Graphics = 0 Then Exit;

  If X = 0 Then X := Screen.CursorX;
  If Y = 0 Then Y := Screen.CursorY;

  BufAddStr (#27'[' + strI2S(Y) + ';' + strI2S(X) + 'H');
End;

Procedure TBBSIO.AnsiClear;
Begin
  If Graphics > 0 Then
    BufAddStr (#27 + '[2J')
  Else
    BufAddChar (#12);

  PausePtr := 1;
End;

Function TBBSIO.OutYN (Y: Boolean) : String;
Begin
  If Y Then OutYN := 'Yes' Else OutYN := 'No'; {++lang?}
End;

Function TBBSIO.OutON (O : Boolean) : String;
Begin
  If O Then OutON := 'On' Else OutON := 'Off'; {++lang}
End;

Procedure TBBSIO.OutFile (FName : String; DoPause: Boolean; Speed: Byte);
Var
  Buffer  : Array[1..4096] of Char;
  BufPos  : LongInt;
  BufSize : LongInt;
  dFile   : File;
  Ext     : String[4];
  Code    : String[2];
  Old     : Boolean;
  Str     : String;
  Ch      : Char;
  Done    : Boolean;

  Function GetChar : Char;
  Begin
    If BufPos = BufSize Then Begin
      BlockRead (dFile, Buffer, SizeOf(Buffer), BufSize);

      BufPos := 0;

      If BufSize = 0 Then Begin
        Done      := True;
        Buffer[1] := #26;
      End;
    End;

    Inc (BufPos);

    Result := Buffer[BufPos];
  End;

Begin
  If Pos(PathChar, FName) = 0 Then
    FName := TBBSCore(Core).Lang.TextPath + FName;

  If Pos('.', FName) > 0 Then
    Ext := ''
  Else
  If (Graphics = 1) and (FileExist(FName + '.ans')) Then
    Ext := '.ans'
  Else
    Ext := '.asc';

  If FileExist(FName + Copy(Ext, 1, 3) + '1') Then Begin
    Repeat
      BufPos := Random(9);
      If BufPos = 0 Then
        Code := Ext[Length(Ext)]
      Else
        Code := strI2S(BufPos);
    Until FileExist(FName + Copy(Ext, 1, 3) + Code);

    Ext := Copy(Ext, 1, 3) + Code;
  End;

  Assign (dFile, FName + Ext);
  {$I-} Reset(dFile, 1); {$I+}
  If IoResult <> 0 Then Begin
    NoFile := True;
    Exit;
  End;

  NoFile       := False;
  Old          := AllowPause;
  AllowPause   := DoPause;
  PausePtr     := 1;
  Done         := False;
  BufPos       := 0;
  BufSize      := 0;
  Ch           := #0;
  BaudEmulator := Speed;

  While Not Done Do Begin
    Ch := GetChar;

    If BaudEmulator > 0 Then Begin
      BufFlush;

      If BufPos MOD BaudEmulator = 0 Then WaitMS(6);
    End;

    Case Ch of
      #10 : Begin
              BufAddChar (#10);
              Inc (PausePtr);

              If (PausePtr = TBBSCore(Core).User.ThisUser.ScreenSize) and (AllowPause) Then
                Case MorePrompt of
                  'N' : Break;
                  'C' : AllowPause := False;
                End;
            End;
      #26 : Break;
      '|' : Begin
              Code := GetChar;
              Code := Code + GetChar;

              If Not ParseMCI(True, Code) Then Begin
                BufAddStr('|' + Code);
                Continue;
              End;

              If FmtString Then Begin
                If FmtType = 5 Then Begin
                  FmtString := False;
                  Str       := '';

                  While Not Done Do Begin
                    Ch := GetChar;
                    If Ch in [#10, '|'] Then Break;
                    Str := Str + GetChar;
                  End;

                  OutFile (TBBSCore(Core).Lang.TextPath + strStripLOW(Str), True, 0);

                  Continue;
                End;

                Code   := GetChar;
                Code   := Code + GetChar;
                FmtLen := strS2I(Code);

                Case FmtType of
                  4 : Begin
                        BufAddStr (strRep(GetChar, FmtLen));
                        FmtString := False;
                      End;
                  6 : Begin
                        AnsiMoveX (FmtLen);
                        FmtString := False;
                      End;
                  7 : Begin
                        AnsiMoveY (FmtLen);
                        FmtString := False;
                      End;
                  8 : Begin
                        AnsiMoveY (Screen.CursorY - FmtLen);
                        FmtString := False;
                      End;
                  9 : Begin
                        AnsiMoveY (Screen.CursorY + FmtLen);
                        FmtString := False;
                      End;
                  10: Begin
                        AnsiMoveX (Screen.CursorX + FmtLen);
                        FmtString := False;
                      End;
                  11: Begin
                        AnsiMoveX (Screen.CursorX - FmtLen);
                        FmtString := False;
                      End;
                  12: Begin
                        UseInLimit := True;
                        InLimit    := FmtLen;
                        FmtString  := False;
                      End;
                  13: Begin
                        PausePtr  := FmtLen;
                        FmtString := True;
                      End;
                  14: Begin
                        UseInSize := True;
                        InSize    := FmtLen;
                        FmtString := False;
                      End;
                  15: Begin
                        While Screen.CursorX > FmtLen Do
                          OutBS(1, True);

                        FmtString := False;
                      End;
                  16: Begin
                        BaudEmulator := FmtLen;
                        FmtString    := False;
                      End;
                End;
              End;
            End;
    Else
      BufAddChar(Ch);
    End;
  End;

  AllowPause := Old;
  Close (dFile);

  BufFlush;
End;

{$IFDEF UNIX}
Function TBBSIO.InKey : Char;
Begin
  Result  := #1;
  IsArrow := False;

  If Input.KeyWait(1000) Then Begin
    Result     := Input.ReadKey;
    LocalInput := True;

    If Result = #0 Then Begin
      Result := Input.ReadKey;

      If (AllowArrow) and (Result in [#71..#73, #75, #77, #79..#83]) Then Begin
        IsArrow := True;
        Exit;
      End;

      Result := #1;
    End;
  End;
End;
{$ENDIF}

{$IFDEF WINDOWS}
Function TBBSIO.InKey : Char;
Var
  Handles : Array[0..1] of THandle;
  InType  : Byte;
Begin
  Result := #1;

  Handles[0] := Input.ConIn;

  If Not TBBSCore(Core).LocalMode Then Begin
    Handles[1] := SocketEvent;

    WSAResetEvent  (Handles[1]);
    WSAEventSelect (TBBSCore(Core).Client.FSocketHandle, Handles[1], FD_READ OR FD_CLOSE);

    Case WaitForMultipleObjects(2, @Handles, False, 1000) of
      WAIT_OBJECT_0     : InType := 1;
      WAIT_OBJECT_0 + 1 : InType := 2;
    Else
      Exit;
    End;
  End Else
    Case WaitForSingleObject (Handles[0], 1000) of
      WAIT_OBJECT_0 : InType := 1;
    Else
      Exit;
    End;

  Case InType of
    1 : Begin // LOCAL input event
          If Not Input.ProcessQueue Then Exit;

          Result     := Input.ReadKey;
          LocalInput := True;
          IsArrow    := False;

          If Result = #0 Then Begin
            Result := Input.ReadKey;

            If (AllowArrow) and (Result in [#71..#73, #75, #77, #79..#83]) and (Screen.Active) Then Begin
              IsArrow := True;
              Exit;
            End;

            ProcessSysopCommand(Result);

            Result := #1;
          End;

          If Not Screen.Active Then Result := #1;
        End;
    2 : Begin // SOCKET read event
          If TBBSCore(Core).Client.ReadBuf(Result, 1) < 0 Then Begin
            TBBSCore(Core).SystemLog ('User dropped carrier');
            Halt(0);
          End;

          LocalInput := False;

          If AllowArrow Then Begin
            IsArrow := True;

            Case Result of
              #03 : Result := #81; { pgdn  }
              #04 : Result := #77; { right }
              #05 : Result := #72; { up    }
              #18 : Result := #73; { pgup  }
              #19 : Result := #75; { left  }
              #24 : Result := #80; { down  }
              #27 : Begin
                      If Not TBBSCore(Core).Client.DataWaiting Then WaitMS(25);
                      If Not TBBSCore(Core).Client.DataWaiting Then WaitMS(25);
                      If TBBSCore(Core).Client.DataWaiting Then Begin
                        If TBBSCore(Core).Client.ReadChar = '[' Then
                          Case TBBSCore(Core).Client.ReadChar of
                            'A' : Result := #72; { ansi up     }
                            'B' : Result := #80; { ansi down   }
                            'C' : Result := #77; { ansi right  }
                            'D' : Result := #75; { ansi left   }
                            'H' : Result := #71; { ansi home   }
                            'K' : Result := #79; { ansi end    }
                            'V' : Result := #73; { ansi pageup }
                            'U' : Result := #81; { ansi pgdown }
                           End;
                      End Else
                        IsArrow := False;
                    End;
              #127: Result := #83; { delete }
            Else
              IsArrow := False;
            End;
          End;
        End;
  End;
End;
{$ENDIF}

Function TBBSIO.GetKey : Char;
Var
  TimeCount : LongInt;
  LastSec   : LongInt;
Begin
  Result := #1;

  TBBSCore(Core).TimeOut := TimerSeconds;

  BufFlush;

  Repeat
    If LastSec <> TimerSeconds Then Begin

      If GetKeyFunc(False) Then Begin
        Result := #02;
        Exit;
      End;

      LastSec := TimerSeconds;

      If InMacro Then
        If InMacroPos <= Length(InMacroStr) Then Begin
          Result := InMacroStr[InMacroPos];
          Inc (InMacroPos);
          Exit;
        End Else
          InMacro := False;

      If TBBSCore(Core).CheckTimeOut Then
        If TimerSeconds - TBBSCore(Core).TimeOut >= Config.Inactivity Then Begin
          TBBSCore(Core).SystemLog('Inactivity timeout');
          OutFullLn (TBBSCore(Core).GetPrompt(136));
          Halt(0);
        End;

      TimeCount := TBBSCore(Core).TimeLeft;

      If TimeCount <> Session.LastTimeLeft Then Begin
        Session.LastTimeLeft := TimeCount;

        {$IFNDEF UNIX}
        UpdateStatusLine(StatusPtr, '');
        {$ENDIF}

        If TBBSCore(Core).TimerOn Then Begin
          If TimeCount = 5 Then Begin
            If Not TBBSCore(Core).TimeChecked Then Begin
              TBBSCore(Core).TimeChecked := True;
              OutFullLn (TBBSCore(Core).GetPrompt(134));
            End;
          End Else
          If TimeCount < 1 Then Begin
            If Not TBBSCore(Core).TimeChecked Then Begin
              TBBSCore(Core).TimeChecked := True;
              OutFullLn (TBBSCore(Core).GetPrompt(135));
              TBBSCore(Core).SystemLog ('User ran out of time');
              Halt(0);
            End;
          End Else
            TBBSCore(Core).TimeChecked := False;
        End;

        If TBBSCore(Core).NextEvent.Active Then
          If (TBBSCore(Core).MinutesUntilEvent(TBBSCore(Core).NextEvent.ExecTime) = TBBSCore(Core).NextEvent.Warning) And
             (Not TBBSCore(Core).EventWarn) And (TBBSCore(Core).NextEvent.Forced) Then Begin
               TBBSCore(Core).EventWarn := True;
               OutFullLn (TBBSCore(Core).GetPrompt(133));
          End;
      End;
    End;

    Result := InKey;
  Until Result <> #1;
End;

Function TBBSIO.GetYNL (Str: String; Yes: Boolean) : Boolean;
Var
  Ch   : Char;
  X    : Byte;
  Temp : Boolean;
Begin
  PurgeInputBuffer;

  OutFull (Str);

  Temp       := AllowArrow;
  AllowArrow := True;
  X          := Screen.CursorX;

  Repeat
    AnsiMoveX (X);

    If Yes Then
      OutFull (TBBSCore(Core).GetPrompt(316))
    Else
      OutFull (TBBSCore(Core).GetPrompt(317));

    Ch := UpCase(GetKey);

    If IsArrow Then Begin
      If Ch = #77 Then Yes := False;
      If Ch = #75 Then Yes := True;
    End Else
    If Ch = #13 Then Break Else
    If Ch = #32 Then Yes := Not Yes Else
    If Ch = 'Y' Then Begin
      Yes := True;

      AnsiMoveX (X);
      OutFull   (TBBSCore(Core).GetPrompt(316));

      Break;
    End Else
    If Ch = 'N' Then Begin
      Yes := False;

      AnsiMoveX (X);
      OutFull   (TBBSCore(Core).GetPrompt(317));

      Break;
    End;
  Until False;

  OutRawLn('');

  AllowArrow := Temp;
  Result     := Yes;
End;

Function TBBSIO.GetYN (Str: String; Yes: Boolean) : Boolean;
Begin
  If (TBBSCore(Core).Lang.Flags AND ThmLightbarYN <> 0) and (Graphics = 1) Then Begin
    GetYN := GetYNL(Str, Yes);
    Exit;
  End;

  OutFull (Str);

  Case OneKey(#13'YN', False) of
    'Y' : Yes := True;
    'N' : Yes := False;
  End;

  OutFullLn (OutYN(Yes));

  Result := Yes;
End;

Function TBBSIO.GetPW (Str: String; BadStr: String; PW: String) : Boolean;
Var
  Loop : Byte;
  Temp : String[15];
Begin
  Result := True;

  If PW = '' Then Exit;

  Loop := 0;

  Repeat
    OutFull (Str);
    Temp := GetInput(15, 15, 16, '');
    If Temp = PW Then
      Exit
    Else Begin
      OutFullLn(BadStr);
      Inc (Loop);

      If (TBBSCore(Core).User.ThisUser.Handle <> '') and (Loop = 1) Then
        TBBSCore(Core).SystemLog ('User: ' + TBBSCore(Core).User.ThisUser.Handle);

      TBBSCore(Core).SystemLog ('Bad PW: ' + Temp);
    End;
  Until Loop = Config.PWAttempts;

  Result := False;
End;

Function TBBSIO.OneKey (Str: String; Echo: Boolean): Char;
Var
  Ch : Char;
Begin
  PurgeInputBuffer;

  Repeat
    Ch := UpCase(GetKey);
  Until Pos (Ch, Str) > 0;

  If Echo Then OutRawLn (Ch);

  Result := Ch;
End;

Function TBBSIO.GetInput (Field, Max, Mode: Byte; Default: String) : String;
(*
{ input modes: }
{ 1 = standard input
{ 2 = upper case }
{ 3 = proper }
{ 4 = usa phone number }
{ 5 = date }
{ 6 = password }
{ 7 = lower cased }
{ 8 = user defined input }
{ 9 = standard input with no CRLF }
*)
Var
  FieldCh   : Char;
  Ch        : Char;
  Str       : String;
  StrPos    : Integer;
  xPos      : Byte;
  Junk      : Integer;
  CurPos    : Integer;
  ArrowSave : Boolean;
  BackPos   : Byte;
  BackSaved : String;

  Procedure pWrite (Str : String);
  Begin
    If (Mode = 6) and (Str <> '') Then
      BufAddStr (strRep(TBBSCore(Core).Lang.EchoChar, Length(Str)))
    Else
      BufAddStr (Str);
  End;

  Procedure ReDraw;
  Begin
    AnsiMoveX (xPos);

    pWrite (Copy(Str, Junk, Field));
    If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor2);
    pWrite (strRep(FieldCh, Field - Length(Copy(Str, Junk, Field))));
    If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor1);

    AnsiMoveX (xPos + CurPos - 1);
  End;

  Procedure ReDrawPart;
  Begin
    pWrite (Copy(Str, StrPos, Field - CurPos + 1));
    If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor2);
    pWrite (strRep(FieldCh, (Field - CurPos + 1) - Length(Copy(Str, StrPos, Field - CurPos + 1))));
    If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor1);

    AnsiMoveX (xPos + CurPos - 1);
  End;

  Procedure ScrollRight;
  Begin
    Inc (Junk, Field DIV 2); {scroll size}
    If Junk > Length(Str) Then Junk := Length(Str);
    If Junk > Max Then Junk := Max;
    CurPos := StrPos - Junk + 1;
    ReDraw;
  End;

  Procedure ScrollLeft;
  Begin
    Dec (Junk, Field DIV 2); {scroll size}
    If Junk < 1 Then Junk := 1;
    CurPos := StrPos - Junk + 1;
    ReDraw;
  End;

  Procedure AddChar (Ch : Char);
  Begin
    If CurPos > Field then ScrollRight;

    Insert (Ch, Str, StrPos);
    If StrPos < Length(Str) Then ReDrawPart;

    Inc (StrPos);
    Inc (CurPos);

    pWrite (Ch);
  End;

Begin
  If UseInLimit Then Begin
    Field := InLimit;
    UseInLimit := False;
  End;

  If UseInSize Then Begin
    UseInSize := False;
    If InSize <= Max Then Max := InSize;
  End;

  xPos    := Screen.CursorX;
  FieldCh := ' ';

  // this is poorly implemented but to expand on it will require MPL
  // programs to change. :(  we are stuck at the cap for input types
  // because of this.

  If Mode > 10 Then Begin
    Dec (Mode, 10);

    If UseInField and (Graphics = 1) Then Begin
      FieldCh := TBBSCore(Core).Lang.FieldChar;

      AnsiColor (TBBSCore(Core).Lang.FieldColor2);
      BufAddStr (strRep(FieldCh, Field));
      AnsiColor (TBBSCore(Core).Lang.FieldColor1);
      AnsiMoveX (xPos);
    End Else
      UseInField := False;
  End Else
    UseInField := False;

  If Mode = 8 Then
    Case Config.UserNameFormat of
      0 : Mode := 1;
      1 : Mode := 2;
      2 : Mode := 7;
      3 : Mode := 3;
    End;

  ArrowSave  := AllowArrow;
  AllowArrow := (Mode in [1..3, 7..9]) and (Graphics > 0);

  BackPos := 0;
  Str     := Default;
  StrPos  := Length(Str) + 1;
  Junk    := StrPos - Field;

  If Junk < 1 Then Junk := 1;

  CurPos := StrPos - Junk + 1;

  PWrite (Copy(Str, Junk, Field));

  PurgeInputBuffer;

  Repeat
    Ch := GetKey;

    If IsArrow Then Begin
      Case Ch of
        #71 : If StrPos > 1 Then Begin
                StrPos := 1;
                Junk   := 1;
                CurPos := 1;
                ReDraw;
              End;
        #72 : If (BackPos < mysMaxInputHistory) And (BackPos < InputPos) Then Begin
                Inc (BackPos);

                If BackPos = 1 Then BackSaved := Str;

                Str := InputData[BackPos];
                StrPos := Length(Str) + 1;
                Junk   := StrPos - Field;
                If Junk < 1 Then Junk := 1;
                CurPos := StrPos - Junk + 1;
                ReDraw;
              End;
        #75 : If StrPos > 1 Then Begin
                If CurPos = 1 Then ScrollLeft;
                Dec (StrPos);
                Dec (CurPos);
                If CurPos < 1 then CurPos := 1;
                AnsiMoveX (Screen.CursorX - 1);
              End;
        #77 : If StrPos < Length(Str) + 1 Then Begin
                If (CurPos = Field) and (StrPos < Length(Str)) Then ScrollRight;
                Inc (CurPos);
                Inc (StrPos);
                AnsiMoveX (Screen.CursorX + 1);
              End;
        #79 : Begin
                StrPos := Length(Str) + 1;
                Junk   := StrPos - Field;
                If Junk < 1 Then Junk := 1;
                CurPos := StrPos - Junk + 1;
                ReDraw;
              End;
        #80 : If (BackPos > 0) Then Begin
                Dec (BackPos);

                If BackPos = 0 Then
                  Str := BackSaved
                Else
                  Str := InputData[BackPos];

                StrPos := Length(Str) + 1;
                Junk   := StrPos - Field;
                If Junk < 1 Then Junk := 1;
                CurPos := StrPos - Junk + 1;
                ReDraw;
              End;
        #83 : If (StrPos <= Length(Str)) and (Length(Str) > 0) Then Begin
                Delete(Str, StrPos, 1);
                ReDrawPart;
              End;
      End;
    End Else
      Case Ch of
        #02 : ReDraw;
        #08 : If StrPos > 1 Then Begin
                Dec    (StrPos);
                Delete (Str, StrPos, 1);

                If CurPos = 1 Then
                  ScrollLeft
                Else
                If StrPos = Length(Str) + 1 Then Begin
                  If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor2);
                  BufAddStr (#8 + FieldCh + #8);
                  If UseInField Then AnsiColor(TBBSCore(Core).Lang.FieldColor1);
                  Dec (CurPos);
                End Else Begin
                  BufAddChar (#8);
                  Dec (CurPos);
                  ReDrawPart;
                End;
              End;
        #13 : Break;
        ^Y  : Begin
                Str    := '';
                StrPos := 1;
                Junk   := 1;
                CurPos := 1;
                ReDraw;
              End;
        #32..
        #254: If Length(Str) < Max Then
              Case Mode of
                1 : AddChar (Ch);
                2 : AddChar (UpCase(Ch));
                3 : Begin
                      If (CurPos = 1) or (Str[StrPos-1] in [' ', '.']) Then
                        Ch := UpCase(Ch)
                      Else
                        Ch := LoCase(Ch);

                      AddChar(Ch);
                    End;
                4 : If (Ord(Ch) > 47) and (Ord(Ch) < 58) Then
                      Case StrPos of
                        4,8 : Begin
                                AddChar ('-');
                                AddChar (Ch);
                              End;
                        3,7 : Begin
                                AddChar (Ch);
                                AddChar ('-');
                              End;
                      Else
                        AddChar(Ch);
                      End;
                5 : If (Ord(Ch) > 47) and (Ord(Ch) < 58) Then
                      Case StrPos of
                        2,5 : Begin
                                AddChar (Ch);
                                AddChar ('/');
                              End;
                        3,6 : Begin
                                AddChar ('/');
                                AddChar (Ch);
                              End;
                      Else
                        AddChar (Ch);
                      End;
                6 : AddChar(UpCase(Ch));
                7 : AddChar(LoCase(Ch));
                9 : AddChar(Ch);
              End;
      End;
  Until False;

  If Mode <> 6 Then Begin
    For Junk := 4 DownTo 2 Do
      InputData[Junk] := InputData[Junk - 1];

    InputData[1] := Str;

    If InputPos < mysMaxInputHistory Then Inc(InputPos);
  End;

  If Mode = 9 Then
    OutFull ('|16')
  Else
    OutFullLn ('|16');

  Case Mode of
    5 : Case TBBSCore(Core).User.ThisUser.DateType of  { Convert to MM/DD/YY }
          {DD/MM/YY}
          2 : Str := Copy(Str, 4, 2) + '/' + Copy(Str, 1, 2) + '/' + Copy(Str, 7, 2);
          {YY/DD/MM}
          3 : Str := Copy(Str, 7, 2) + '/' + Copy(Str, 4, 2) + '/' + Copy(Str, 1, 2);
        End;
  End;

  UseInField := True;
  AllowArrow := ArrowSave;
  Result     := Str;
End;

Function TBBSIO.InXY (X, Y, Field, Max, Mode: Byte; Default: String) : String;
Begin
  If Graphics = 0 Then
    OutFull ('|CR: ')
  Else
    AnsiGotoXY (X, Y);

  InXY := GetInput (Field, Max, Mode, Default);
End;

Function TBBSIO.DrawPercent (Bar: RecPercent; Part, Whole: SmallInt; Var Percent : SmallInt) : String;
Var
  FillSize : Byte;
Begin
  Screen.TextAttr := 0;  // kludge to force it to return full ansi codes

  If (Part = 0) or (Whole = 0) or (Part > Whole) Then Begin
    FillSize := 0;
    Percent  := 0;
//    FillSize := Bar.BarLen;
//    Percent  := 100;
// this needs work...
  End Else Begin
    FillSize := Round(Part / Whole * Bar.BarLength);
    Percent  := Round(Part / Whole * 100);
  End;

  DrawPercent := Attr2Ansi(Bar.HiAttr) + strRep(Bar.HiChar, FillSize) +
                 Attr2Ansi(Bar.LoAttr) + strRep(Bar.LoChar, Bar.BarLength - FillSize);
End;

{$IFDEF UNIX}
Procedure TBBSIO.RemoteRestore (Var Image: TConsoleImageRec);
Var
  CountX : Byte;
  CountY : Byte;
Begin
  For CountY := Image.Y1 to Image.Y2 Do Begin
    Session.io.AnsiGotoXY (Image.X1, CountY);

    For CountX := Image.X1 to Image.X2 Do Begin
      Session.io.AnsiColor(Image.Data[CountY][CountX].Attributes);
      Session.io.BufAddChar(Image.Data[CountY][CountX].UnicodeChar);
    End;
  End;

  Session.io.AnsiColor  (Image.CursorA);
  Session.io.AnsiGotoXY (Image.CursorX, Image.CursorY);

  Session.io.BufFlush;
End;
{$ELSE}
Procedure TBBSIO.RemoteRestore (Var Image: TConsoleImageRec);
Var
  CountX   : Byte;
  CountY   : Byte;
  BufPos   : Integer;
  Buffer   : Array[1..SizeOf(TConsoleScreenRec) DIV 2] of Word Absolute Image.Data;
  TempChar : Char;
Begin
  BufPos := 1;

  For CountY := Image.Y1 to Image.Y2 Do Begin
    Session.io.AnsiGotoXY (Image.X1, CountY);

    For CountX := Image.X1 to Image.X2 Do Begin

      Session.io.AnsiColor(Buffer[BufPos+1]);

      TempChar := Char(Buffer[BufPos]);

      If TempChar = #0 Then TempChar := ' ';

      Session.io.BufAddChar(TempChar);
      Inc (BufPos, 2);
    End;
  End;

  Session.io.AnsiColor  (Image.CursorA);
  Session.io.AnsiGotoXY (Image.CursorX, Image.CursorY);

  Session.io.BufFlush;
End;
{$ENDIF}

Function TBBSIO.StrMci (Str: String) : String;
Var
  Count : Byte;
  Code  : String[2];
Begin
  Result := '';
  Count  := 1;

  While Count <= Length(Str) Do Begin
    If (Str[Count] = '|') and (Count < Length(Str) - 1) Then Begin
      Code := Copy(Str, Count + 1, 2);
      Inc (Count, 2);
      Case Code[1] of
        '0' : Result := Result + '|' + Code;
        '1' : Result := Result + '|' + Code;
        '2' : Result := Result + '|' + Code;
      Else
        If ParseMCI(False, Code) Then
          Result := Result + LastMCIValue
        Else
          Result := Result + '|' + Code;
      End;
    End Else
      Result := Result + Str[Count];

    Inc(Count);
  End;
End;

Procedure TBBSIO.PurgeInputBuffer;
Begin
  While Input.KeyPressed Do Input.ReadKey;
  {$IFDEF WINDOWS}
  If Not TBBSCore(Core).LocalMode Then TBBSCore(Core).Client.PurgeInputData;
  {$ENDIF}
End;

{$IFDEF WINDOWS}
Procedure TBBSIO.LocalScreenDisable;
Begin
  Screen.ClearScreenNoUpdate;
  Screen.WriteXYNoUpdate(1, 1, 7, 'Screen disabled. Press ALT-V to view user');
  Screen.Active := False;
End;

Procedure TBBSIO.LocalScreenEnable;
Begin
  Screen.Active := True;
  Screen.ShowBuffer;
  UpdateStatusLine(StatusPtr, '');
End;
{$ENDIF}

End.

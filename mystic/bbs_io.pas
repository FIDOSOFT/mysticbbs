Unit BBS_IO;

{$I M_OPS.PAS}

Interface

{.$DEFINE USEUTF8}

Uses
  {$IFDEF WINDOWS}
    Windows,
    WinSock2,
    m_io_Base,
    m_io_Sockets,
  {$ENDIF}
  m_Types,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_Term_Ansi,
  BBS_Records;

Const
  TBBSIOBufferSize = 4 * 1024 - 1;
  MaxPromptInfo    = 15;

Type
  TGetKeyCallBack = Function (Forced: Boolean) : Boolean;// Is Nested;

  TBBSIO = Class
    Core           : Pointer;
    Term           : TTermAnsi;
    ScreenInfo     : Array[0..9] of Record X, Y, A : Byte; End;
    PromptInfo     : Array[1..MaxPromptInfo] of String[160];
    FmtString      : Boolean;
    FmtLen         : Byte;
    FmtType        : Byte;
    InMacro        : Boolean;
    InMacroPos     : Byte;
    InMacroStr     : String;
    BaudEmulator   : Byte;
    AllowPause     : Boolean;
    AllowMCI       : Boolean;
    LocalInput     : Boolean;
    AllowArrow     : Boolean;
    IsArrow        : Boolean;
    UseInField     : Boolean;
    UseInLimit     : Boolean;
    UseInSize      : Boolean;
    InLimit        : Byte;
    InSize         : Byte;
    AllowAbort     : Boolean;
    NoFile         : Boolean;
    Graphics       : Byte;
    PausePtr       : Byte;
    InputData      : Array[1..mysMaxInputHistory] of String[255];
    LastMCIValue   : String;
    InputPos       : Byte;
    GetKeyCallBack : TGetKeyCallBack;
    LastSecond     : LongInt;
    OutBuffer      : Array[0..TBBSIOBufferSize] of Char;
    OutBufPos      : SmallInt;
    RangeValue     : LongInt;

    {$IFDEF WINDOWS}
      SocketEvent : THandle;
    {$ENDIF}

    Constructor Create (Var Owner: Pointer);
    Destructor  Destroy; Override;

    Procedure   BufAddChar       (Ch: Char);
    Procedure   BufAddStr        (Str: String);
    Procedure   BufFlush;
    Function    ParseMCI         (Display: Boolean; Code: String) : Boolean;
    Function    StrMci           (Str: String) : String;
    Function    Attr2Ansi        (Attr: Byte) : String;
    Function    Pipe2Ansi        (Color: Byte) : String;
    Procedure   AnsiGotoXY       (X: Byte; Y:Byte);
    Procedure   AnsiMoveX        (X: Byte);
    Procedure   AnsiMoveY        (Y: Byte);
    Procedure   AnsiColor        (A: Byte);
    Procedure   AnsiClear;
    Procedure   AnsiClrEOL;
    Procedure   OutPipe          (Str: String);
    Procedure   OutPipeLn        (Str: String);
    Procedure   OutRaw           (Str: String);
    Procedure   OutRawLn         (Str: String);
    Procedure   OutBS            (Num: Byte; Del: Boolean);
    Procedure   OutFull          (Str: String);
    Procedure   OutFullLn        (Str: String);
    Function    OutFile          (FName: String; DoPause: Boolean; Speed: Byte) : Boolean;
    Function    OutYN            (Y: Boolean) : String;
    Function    OutON            (O: Boolean) : String;
    Procedure   PauseScreen;
    Function    MorePrompt       : Char;
    Function    DrawPercent      (Bar: RecPercent; Part, Whole: SmallInt; Var Percent : SmallInt) : String;
    Function    GetInput         (Field, Max, Mode: Byte; Default: String) : String;
    Function    InXY             (X, Y, Field, Max, Mode: Byte; Default: String) : String;
    Function    InKey            (Wait: LongInt) : Char;
    Function    GetYNL           (Str: String; Yes: Boolean) : Boolean;
    Function    DoInputEvents    (Var Ch: Char) : Boolean;
    Function    GetKey           : Char;
    Function    GetYN            (Str: String; Yes: Boolean) : Boolean;
    Function    GetPW            (Str: String; BadStr: String; PW: String) : Boolean;
    Function    OneKey           (Str: String; Echo: Boolean) : Char;
    Function    OneKeyRange      (Str: String; Lo, Hi: LongInt) : Char;
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
  BBS_Core,
  BBS_DataBase,
  BBS_Common,
  bbs_General,
  bbs_NodeInfo;

{$IFDEF USEUTF8}
Function UTF8Encode(Ch : LongInt) : String;
Const
  CP437_Map : Array[0..255] of LongInt = (
    $2007, $263A, $263B, $2665, $2666, $2663, $2660, $2022,
    $25D8, $25CB, $25D9, $2642, $2640, $266A, $266B, $263C,
    $25BA, $25C4, $2195, $203C, $00B6, $00A7, $25AC, $21A8,
    $2191, $2193, $2192, $2190, $221F, $2194, $25B2, $25BC,
    $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027,
    $0028, $0029, $002a, $002b, $002c, $002d, $002e, $002f,
    $0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037,
    $0038, $0039, $003a, $003b, $003c, $003d, $003e, $003f,
    $0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047,
    $0048, $0049, $004a, $004b, $004c, $004d, $004e, $004f,
    $0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057,
    $0058, $0059, $005a, $005b, $005c, $005d, $005e, $005f,
    $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067,
    $0068, $0069, $006a, $006b, $006c, $006d, $006e, $006f,
    $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077,
    $0078, $0079, $007a, $007b, $007c, $007d, $007e, $007f,
    $00c7, $00fc, $00e9, $00e2, $00e4, $00e0, $00e5, $00e7,
    $00ea, $00eb, $00e8, $00ef, $00ee, $00ec, $00c4, $00c5,
    $00c9, $00e6, $00c6, $00f4, $00f6, $00f2, $00fb, $00f9,
    $00ff, $00d6, $00dc, $00a2, $00a3, $00a5, $20a7, $0192,
    $00e1, $00ed, $00f3, $00fa, $00f1, $00d1, $00aa, $00ba,
    $00bf, $2310, $00ac, $00bd, $00bc, $00a1, $00ab, $00bb,
    $2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
    $2555, $2563, $2551, $2557, $255d, $255c, $255b, $2510,
    $2514, $2534, $252c, $251c, $2500, $253c, $255e, $255f,
    $255a, $2554, $2569, $2566, $2560, $2550, $256c, $2567,
    $2568, $2564, $2565, $2559, $2558, $2552, $2553, $256b,
    $256a, $2518, $250c, $2588, $2584, $258c, $2590, $2580,
    $03b1, $00df, $0393, $03c0, $03a3, $03c3, $00b5, $03c4,
    $03a6, $0398, $03a9, $03b4, $221e, $03c6, $03b5, $2229,
    $2261, $00b1, $2265, $2264, $2320, $2321, $00f7, $2248,
    $00b0, $2219, $00b7, $221a, $207f, $00b2, $25a0, $00a0);

Begin
  If (Ch <= $FF) Then Begin
    Case Ch Of
       $00, $1B, $0D, $0A, $07, $08, $09 : { NOP } ;
    Else
      Ch := CP437_Map[Ch];
    End;
  End;

  If (Ch <= $7F) Then Begin
    Result := Chr(Ch);
    Exit;
  End;

  If (Ch <= $7FF) Then Begin
		Result := Chr($C0 or ((Ch shr  6) and $1F)) +
              Chr($80 or  (Ch         and $3F));
    Exit;
  End;

	If (Ch <= $FFFF) Then Begin
		Result := Chr($E0 or ((Ch shr 12) and $0F)) +
              Chr($80 or ((Ch shr  6) and $3F)) +
              Chr($80 or  (Ch         and $3F));
    Exit;
	End;

	If (ch <= $10FFFF) Then Begin
		Result := Chr($F0 or ((Ch shr 18) and $07)) +
              Chr($80 or ((Ch shr 12) and $3F)) +
              Chr($80 or ((Ch shr  6) and $3F)) +
              Chr($80 or  (Ch         and $3F));
    Exit;
	End;

  Result := ' ';
End;
{$ENDIF}

Constructor TBBSIO.Create (Var Owner: Pointer);
Begin
  Core           := Owner;
  FmtString      := False;
  FmtLen         := 0;
  FmtType        := 0;
  InMacro        := False;
  InMacroPos     := 0;
  InMacroStr     := '';
  AllowPause     := False;
  AllowMCI       := True;
  LocalInput     := False;
  AllowArrow     := False;
  IsArrow        := False;
  UseInField     := True;
  UseInLimit     := False;
  UseInSize      := False;
  InLimit        := 0;
  InSize         := 0;
  NoFile         := False;
  Graphics       := 1;
  PausePtr       := 1;
  LastMCIValue   := '';
  InputPos       := 0;
  GetKeyCallBack := NIL;

  FillChar(OutBuffer, SizeOf(OutBuffer), 0);

  OutBufPos := 0;

  {$IFDEF WINDOWS}
    If Not TBBSCore(Core).LocalMode Then
      SocketEvent := WSACreateEvent;
  {$ENDIF}

  Term := TTermAnsi.Create(Console);
End;

Destructor TBBSIO.Destroy;
Begin
  {$IFDEF WINDOWS}
    If Not TBBSCore(Core).LocalMode Then WSACloseEvent(SocketEvent);
  {$ENDIF}

  Term.Free;

  Inherited Destroy;
End;

{$IFDEF USEUTF8}
Procedure TBBSIO.BufAddChar (Ch: Char);
Var
  S : String;
  C : Byte;
Begin
  {$IFDEF WINDOWS}
    Term.Process(Ch);
  {$ENDIF}

  If Session.User.ThisUser.CodePage = 1 Then Begin
    S := UTF8Encode(LongInt(Ch));

    For C := 1 to Length(S) Do Begin
      {$IFDEF UNIX}
        Term.Process(S[C]);
      {$ENDIF}

      OutBuffer[OutBufPos] := S[C];

      Inc (OutBufPos);

      If OutBufPos = TBBSIOBufferSize Then BufFlush;
    End;
  End Else Begin
    {$IFDEF UNIX}
      Term.Process(Ch);
    {$ENDIF}

    OutBuffer[OutBufPos] := Ch;

    Inc (OutBufPos);

    If OutBufPos = TBBSIOBufferSize Then BufFlush;
  End;
End;
{$ELSE}
Procedure TBBSIO.BufAddChar (Ch: Char);
Begin
  Term.Process(Ch);

  OutBuffer[OutBufPos] := Ch;

  Inc (OutBufPos);

  If OutBufPos = TBBSIOBufferSize Then BufFlush;
End;
{$ENDIF}

Procedure TBBSIO.BufAddStr (Str: String);
Var
  Count : Word;
Begin
  For Count := 1 to Length(Str) Do
    BufAddChar(Str[Count]);
End;

Procedure TBBSIO.BufFlush;
Begin
  {$IFDEF WINDOWS}
  If OutBufPos > 0 Then Begin
    If Not TBBSCore(Core).LocalMode Then
      TBBSCore(Core).Client.WriteBuf(OutBuffer, OutBufPos);

    If Session.Pipe.Connected Then
      Session.Pipe.SendToPipe(OutBuffer, OutBufPos);

    OutBufPos := 0;
  End;
  {$ENDIF}

  {$IFDEF UNIX}
    // UTF8 considerations?

    If Session.Pipe.Connected Then
      Session.Pipe.SendToPipe(OutBuffer, OutBufPos);

    OutBufPos := 0;

    Console.BufFlush;
  {$ENDIF}
End;

Procedure TBBSIO.AnsiMoveY (Y : Byte);
Var
  T : Byte;
Begin
  If Graphics = 0 Then Exit;

  T := Console.CursorY;

  If Y > T Then BufAddStr (#27 + '[' + strI2S(Y-T) + 'B') Else
  If Y < T Then BufAddStr (#27 + '[' + strI2S(T-Y) + 'A');
End;

Procedure TBBSIO.AnsiMoveX (X : Byte);
Var
  T : Byte;
Begin
  If Graphics = 0 Then Exit;

  T := Console.CursorX;

  If X > T Then BufAddStr (#27 + '[' + strI2S(X-T) + 'C') Else
  If X < T Then BufAddStr (#27 + '[' + strI2S(T-X) + 'D');
End;

Procedure TBBSIO.PauseScreen;
Var
  Attr : Byte;
  Ch   : Char;
Begin
  Attr := Console.TextAttr;

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
  SavedAttr := Console.TextAttr;

  OutFull (TBBSCore(Core).GetPrompt(132));

  Ch := OneKey('YNC' + #13, False);

  OutBS     (Console.CursorX, True);
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
      If Code = '[X' Then Begin
        Inc (Count, 2);

        Code := Copy(Str, Count + 1, 2);

        AnsiMoveX(strS2I(Code));
      End Else
      If Code = '[Y' Then Begin
        Inc (Count, 2);

        Code := Copy(Str, Count + 1, 2);

        AnsiMoveY(strS2I(Code));
      End Else
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
      1  : Str := strPadR(Str, FmtLen, ' ');
      2  : Str := strPadL(Str, FmtLen, ' ');
      3  : Str := strPadC(Str, FmtLen, ' ');
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

            ScreenInfo[A].X := Console.CursorX;
            ScreenInfo[A].Y := Console.CursorY;
            ScreenInfo[A].A := Console.TextAttr;
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
            'X' : Begin
                    FmtString := True;
                    FmtType   := 17;
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
            'G' : LastMCIValue := strI2S(DaysAgo(TBBSCore(Core).User.ThisUser.Birthday, 1) DIV 365);
            'O' : AllowAbort := False;
            'S' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.SigUse);
            'V' : LastMCIValue := OutYN(Session.Chat.Available);
          End;
    'B' : Case Code[2] of
            'D' : If TBBSCore(Core).LocalMode Then
                    LastMCIValue := 'LOCAL' {++lang add these to lang file }
                  Else
                    LastMCIValue := 'TELNET'; {++lang }
            'E' : LastMCIValue := ^G;
            'I' : LastMCIValue := DateJulian2Str(TBBSCore(Core).User.ThisUser.Birthday, TBBSCore(Core).User.ThisUser.DateType);
            'N' : LastMCIValue := bbsCfg.BBSName;
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
            'T' : LastMCIValue := strI2S(GetTotalFiles(TBBSCore(Core).FileBase.FBase));
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
            'L' : LastMCIValue := OutON(Session.Chat.Invisible);
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
            'D' : If Session.Menu.Data <> NIL Then
                    LastMCIValue := Session.Menu.Data.Info.Description
                  Else
                    LastMCIValue := '';
            'E' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.Emails);
            'G' : LastMCIValue := TBBSCore(Core).Msgs.Group.Name;
            'L' : LastMCIValue := OutON(TBBSCore(Core).User.ThisUser.UseLBIndex);
            'N' : LastMCIValue := bbsCfg.NetDesc[TBBSCore(Core).Msgs.MBase.NetAddr];
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
            'W' : LastMCIValue := strI2S(bbsCfg.PWChange);
          End;
    'Q' : Case Code[2] of
            'A' : LastMCIValue := TBBSCore(Core).User.ThisUser.Archive;
            'E' : LastMCIValue := OutYN (TBBSCore(Core).User.ThisUser.QwkExtended);
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
            'N' : LastMCIValue := bbsCfg.SysopName;
            'P' : Begin
                    A := Round(TBBSCore(Core).User.Security.PCRatio / 100 * 100);
                    LastMCIValue := strI2S(A);
                  End;
            'T' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.Time);
            'X' : LastMCIValue := strI2S(TBBSCore(Core).User.Security.MaxDLs);
          End;
    'T' : Case Code[2] of
            '0'..
            '9' : LastMCIValue := Attr2Ansi(Session.Theme.Colors[strS2I(Code[2])]);
            'B' : LastMCIValue := strI2S(TBBSCore(Core).User.ThisUser.TimeBank);
            'C' : LastMCIValue := strI2S(bbsCfg.SystemCalls);
            'E' : If Graphics = 1 Then LastMCIValue := 'Ansi' Else LastMCIValue := 'Ascii'; //++lang
            'I' : LastMCIValue := TimeDos2Str(CurDateDos, 1);
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
            'L' : LastMCIValue := TBBSCore(Core).Theme.Desc;
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

          OutFile (JustFile(strStripLOW(Copy(Str, A + 1, B - A - 1))), True, 0);

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
                AnsiMoveY (Console.CursorY - FmtLen);
                FmtString := False;
              End;
          9 : Begin
                AnsiMoveY (Console.CursorY + FmtLen);
                FmtString := False;
              End;
          10: Begin
                AnsiMoveX (Console.CursorX + FmtLen);
                FmtString := False;
              End;
          11: Begin
                AnsiMoveX (Console.CursorX - FmtLen);
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
                While Console.CursorX > FmtLen Do
                  OutBS(1, True);

                FmtString := False;
              End;
          17: Begin
                Inc (A);
                FmtString := False;

                If Console.CursorX < FmtLen Then
                  BufAddStr (strRep(Str[A], FmtLen - Console.CursorX + 1));
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

(*
Function TBBSIO.Pipe2Ansi (Color: Byte) : String;
Begin
  Result := '';

  If Graphics = 0 Then Exit;

  Case Color of
    00: Result := #27 + '[0;30m';
    01: Result := #27 + '[0;34m';
    02: Result := #27 + '[0;32m';
    03: Result := #27 + '[0;36m';
    04: Result := #27 + '[0;31m';
    05: Result := #27 + '[0;35m';
    06: Result := #27 + '[0;33m';
    07: Result := #27 + '[0;37m';
    08: Result := #27 + '[1;30m';
    09: Result := #27 + '[1;34m';
    10: Result := #27 + '[1;32m';
    11: Result := #27 + '[1;36m';
    12: Result := #27 + '[1;31m';
    13: Result := #27 + '[1;35m';
    14: Result := #27 + '[1;33m';
    15: Result := #27 + '[1;37m';
  End;

  If Color in [00..07] Then
    Color := (Console.TextAttr SHR 4) and 7 + 16;

  Case Color of
    16: Result := Result + #27 + '[40m';
    17: Result := Result + #27 + '[44m';
    18: Result := Result + #27 + '[42m';
    19: Result := Result + #27 + '[46m';
    20: Result := Result + #27 + '[41m';
    21: Result := Result + #27 + '[45m';
    22: Result := Result + #27 + '[43m';
    23: Result := Result + #27 + '[47m';
  End;
End;
*)

Function TBBSIO.Pipe2Ansi (Color: Byte) : String;
Var
  CurFG  : Byte;
  CurBG  : Byte;
  Prefix : String[2];
Begin
  Result := '';

  If Graphics = 0 Then Exit;


  CurBG  := (Console.TextAttr SHR 4) AND 7;
  CurFG  := Console.TextAttr AND $F;
  Prefix := '';

  If Color < 16 Then Begin
    If Color = CurFG Then Exit;

//    Console.TextAttr := Color + CurBG * 16;

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

//    Console.TextAttr := CurFG + (Color - 16) * 16;

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

(*
Function TBBSIO.Attr2Ansi (Attr: Byte) : String;
Begin
  Result := '';

  If Graphics = 0 Then Exit;

  Result := Pipe2Ansi(Attr AND $F) + Pipe2Ansi(((Attr SHR 4) AND 7) + 16);
End;
*)

Function TBBSIO.Attr2Ansi (Attr: Byte) : String;
Const
  AnsiTable : String[8] = '04261537';
Var
  OldFG : LongInt;
  OldBG : LongInt;
  FG    : LongInt;
  BG    : LongInt;

  Procedure AddSep (Ch: Char);
  Begin
    If Length(Result) > 0 Then
      Result := Result + ';';

    Result := Result + Ch;
  End;

Begin
  Result := '';

  If (Attr = Console.TextAttr) or (Graphics = 0) Then Exit;

  FG    := Attr and $F;
  BG    := Attr shr 4;
  OldFG := Console.TextAttr and $F;
  OldBG := Console.TextAttr shr 4;

  If (OldFG <> 7) or (FG = 7) or ((OldFG > 7) and (FG < 8)) or ((OldBG > 7) and (BG < 8)) Then Begin
    Result := '0';
    OldFG  := 7;
    OldBG  := 0;
  End;

  If (FG > 7) and (OldFG < 8) Then Begin
    AddSep('1');

    OldFG := OldFG or 8;
  End;

//  If (BG and 8) <> (OldBG and 8) Then Begin
//    AddSep('5');

//    OldBG := OldBG or 8;
//  End;

  If (FG <> OldFG) Then Begin
    AddSep('3');

    Result := Result + AnsiTable[(FG and 7) + 1];
  End;

  If (BG <> OldBG) Then Begin
    AddSep('4');

    Result := Result + AnsiTable[(BG and 7) + 1];
  End;

  Result := #27 + '[' + Result + 'm';
End;

Procedure TBBSIO.AnsiColor (A : Byte);
Begin
  If Graphics = 0 Then Exit;

  BufAddStr(Attr2Ansi(A));
End;

Procedure TBBSIO.AnsiGotoXY (X: Byte; Y: Byte);
Begin
  If Graphics = 0 Then Exit;

//  If (X = Console.CursorX) and (Y = Console.CursorY) Then Exit;

  If X = 0 Then X := Console.CursorX;
  If Y = 0 Then Y := Console.CursorY;

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

Function TBBSIO.OutFile (FName: String; DoPause: Boolean; Speed: Byte) : Boolean;
Var
  Buffer     : Array[1..4096] of Char;
  BufPos     : LongInt;
  BufSize    : LongInt;
  dFile      : File;
  Ext        : String[4] = '';
  Code       : String[2];
  SavedPause : Boolean;
  SavedAbort : Boolean;
  Str        : String;
  Ch         : Char;
  Done       : Boolean;

  Function CheckFileInPath (Path: String) : Boolean;
  Var
    Temp : String;
  Begin
    Result := False;
    Temp   := Path + FName;

    If (Graphics = 1) and (FileExist(Temp + '.ans')) Then Begin
      Ext    := '.ans';
      FName  := Temp;
      Result := True;
    End Else
    If FileExist(Temp + '.asc') Then Begin
      Ext    := '.asc';
      FName  := Temp;
      Result := True;
    End Else
    If FileExist(Temp) Then Begin
      Ext    := '.' + JustFileExt(FName);
      FName  := Path + JustFileName(FName);
      Result := True;
    End;
  End;

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
  Result   := False;
  NoFile   := True;
  FileMode := 66;

  If (Pos(PathSep, FName) > 0) Then Begin
    If Not FileExist(FName) Then
      If Not CheckFileInPath('') Then Exit;
  End Else Begin
    If Not CheckFileInPath(Session.Theme.TextPath) Then
      If Session.Theme.Flags AND thmFallBack <> 0 Then Begin
        If Not CheckFileInPath(bbsCfg.TextPath) Then Exit;
      End Else
        Exit;
  End;

  If (Pos('.', FName) = 0) Then
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

  If IoResult <> 0 Then Exit;

  NoFile       := False;
  Result       := True;
  SavedPause   := AllowPause;
  SavedAbort   := AllowAbort;
  AllowPause   := DoPause;
  AllowAbort   := True;
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

    If AllowAbort And (BufPos MOD 128 = 0) And Not Session.LocalMode Then
      If InKey(0) = #32 Then Begin
        AnsiColor(7);
        Break;
      End;
(*
    If AllowAbort And (InKey(0) = #32) Then Begin
      AnsiColor(7);
      Break;
    End;
*)

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

                  OutFile (JustFile(strStripLOW(Str)), True, 0);

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
                        AnsiMoveY (Console.CursorY - FmtLen);
                        FmtString := False;
                      End;
                  9 : Begin
                        AnsiMoveY (Console.CursorY + FmtLen);
                        FmtString := False;
                      End;
                  10: Begin
                        AnsiMoveX (Console.CursorX + FmtLen);
                        FmtString := False;
                      End;
                  11: Begin
                        AnsiMoveX (Console.CursorX - FmtLen);
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
                        While Console.CursorX > FmtLen Do
                          OutBS(1, True);

                        FmtString := False;
                      End;
                  16: Begin
                        BaudEmulator := FmtLen;
                        FmtString    := False;
                      End;
                  17: Begin
                        FmtString := False;

                        If Console.CursorX < FmtLen Then
                          BufAddStr (strRep(GetChar, FmtLen - Console.CursorX + 1));
                      End;
                End;
              End;
            End;
    Else
      BufAddChar(Ch);
    End;
  End;

  AllowPause := SavedPause;
  AllowAbort := SavedAbort;

  Close (dFile);

  BufFlush;
End;

{$IFDEF UNIX}
Function TBBSIO.InKey (Wait: LongInt) : Char;
Begin
  Result  := #255;
  IsArrow := False;

  If Keyboard.KeyWait(Wait) Then Begin
    Result     := Keyboard.ReadKey;
    LocalInput := True;

    If Result = #0 Then Begin
      Result := Keyboard.ReadKey;

      If (AllowArrow) and (Result in [#71..#73, #75, #77, #79..#83]) Then Begin
        IsArrow := True;
        Exit;
      End;

      Result := #255;
    End;
  End;
End;
{$ENDIF}

{$IFDEF WINDOWS}
Function TBBSIO.InKey (Wait: LongInt) : Char;
Var
  Handles : Array[0..1] of THandle;
  InType  : Byte;
Begin
  Result := #255;

  Handles[0] := Keyboard.ConIn;

  If Not TBBSCore(Core).LocalMode Then Begin
    If TBBSCore(Core).Client.FInBufPos < TBBSCore(Core).Client.FInBufEnd Then
      InType := 2
    Else Begin
      Handles[1] := SocketEvent;

      WSAResetEvent  (Handles[1]);
      WSAEventSelect (TIOSocket(TBBSCore(Core).Client).FSocketHandle, Handles[1], FD_READ OR FD_CLOSE);

      Case WaitForMultipleObjects(2, @Handles, False, Wait) of
        WAIT_OBJECT_0     : InType := 1;
        WAIT_OBJECT_0 + 1 : InType := 2;
      Else
        Exit;
      End;
    End;
  End Else
    Case WaitForSingleObject (Handles[0], Wait) of
      WAIT_OBJECT_0 : InType := 1;
    Else
      Exit;
    End;

  Case InType of
    1 : Begin // LOCAL input event
          If Not Keyboard.ProcessQueue Then Exit;

          Result     := Keyboard.ReadKey;
          LocalInput := True;
          IsArrow    := False;

          If Result = #0 Then Begin
            Result := Keyboard.ReadKey;

            If (AllowArrow) and (Result in [#71..#73, #75, #77, #79..#83]) and (Console.Active) Then Begin
              IsArrow := True;
              Exit;
            End;

            ProcessSysopCommand(Result);

            Result := #255;
          End;

          If Not Console.Active Then Result := #255;
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
                      If Not TBBSCore(Core).Client.DataWaiting Then WaitMS(50);

                      If TBBSCore(Core).Client.PeekChar(0) = '[' Then Begin
                        TBBSCore(Core).Client.ReadChar;

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

Function TBBSIO.DoInputEvents (Var Ch: Char) : Boolean;
Var
  TimeCount : LongInt;
Begin
  Result := False;

  If InMacro Then
    If InMacroPos <= Length(InMacroStr) Then Begin
      Ch     := InMacroStr[InMacroPos];
      Result := True;

      Inc (InMacroPos);
      Exit;
    End Else
      InMacro := False;

  If TBBSCore(Core).CheckTimeOut Then
    If (bbsCfg.Inactivity > 0) and (Session.User.ThisUser.Flags And UserNoTimeOut = 0) and (TimerSeconds - TBBSCore(Core).TimeOut >= bbsCfg.Inactivity) Then Begin
      TBBSCore(Core).SystemLog('Inactivity timeout');
      OutFullLn (TBBSCore(Core).GetPrompt(136));
      BufFlush;
      Halt(0);
    End;

  If Session.AllowMessages And Not Session.InMessage Then Begin
    Dec (Session.MessageCheck);

    If Session.MessageCheck = 0 Then Begin
      CheckNodeMessages;

      Session.MessageCheck := mysMessageThreshold;
    End;
  End;

  TimeCount := TBBSCore(Core).TimeLeft;

  If TimeCount <> Session.LastTimeLeft Then Begin
    Session.LastTimeLeft := TimeCount;

    {$IFNDEF UNIX}
      UpdateStatusLine(Session.StatusPtr, '');
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

Function TBBSIO.GetKey : Char;
Begin
  Result := #255;

  TBBSCore(Core).TimeOut := TimerSeconds;

  BufFlush;

  Repeat
    If InMacro Then
      If DoInputEvents(Result) Then Exit;

    If LastSecond <> TimerSeconds Then Begin
      LastSecond := TimerSeconds;

      If Assigned(GetKeyCallBack) Then
        If GetKeyCallBack(False) Then Begin
          Result := #02;
          Exit;
        End;

      If DoInputEvents(Result) Then Exit;
    End;

    Result := InKey(1000);
  Until Result <> #255;
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
  X          := Console.CursorX;

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
  If (TBBSCore(Core).Theme.Flags AND ThmLightbarYN <> 0) and (Graphics = 1) Then Begin
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
  Until Loop = bbsCfg.PWAttempts;

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

Function TBBSIO.OneKeyRange (Str: String; Lo, Hi: LongInt) : Char;
Var
  Ch     : Char;
  CurStr : String = '';
  HiStr  : String[10];
  Field  : Byte;
  xPos   : Byte;
Begin
  PurgeInputBuffer;

  RangeValue := -1;
  HiStr      := strI2S(Hi);
  Field      := Length(strI2S(Hi));
  xPos       := Console.CursorX;

  If UseInField and (Graphics = 1) Then Begin
    AnsiColor (TBBSCore(Core).Theme.FieldColor2);
    BufAddStr (strRep(Session.Theme.FieldChar, Field));
    AnsiColor (TBBSCore(Core).Theme.FieldColor1);
    AnsiMoveX (xPos);
  End Else
    UseInField := False;

  Repeat
    Ch := UpCase(GetKey);

    If (Pos(Ch, Str) > 0) and (CurStr = '') Then Begin
      Result := Ch;

      OutRaw(Ch);

      Break
    End Else
      Case Ch of
        #08 : If CurStr <> '' Then Begin
                Dec    (CurStr[0]);

                If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor2);
                BufAddStr (#8 + Session.Theme.FieldChar + #8);
                If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor1);
              End;
        #13 : If CurStr <> '' Then Begin
                RangeValue := strS2I(CurStr);
                Result     := #0;

                Break;
              End Else
              If Pos(#13, Str) > 0 Then Begin
                Result := #13;
                Break;
              End;
        '0'..
        '9' : If (strS2I(CurStr + Ch) >= Lo) and (strS2I(CurStr + Ch) <= Hi) Then Begin
                CurStr := CurStr + Ch;

                If Length(CurStr) = Length(HiStr) Then Begin
                  OutRaw(Ch);

                  RangeValue := strS2I(CurStr);
                  Result     := #0;

                  Break;
                End Else
                  OutRaw (Ch);
              End;
      End;
  Until False;

  OutFullLn ('|16');
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
      BufAddStr (strRep(TBBSCore(Core).Theme.EchoChar, Length(Str)))
    Else
      BufAddStr (Str);
  End;

  Procedure ReDraw;
  Begin
    AnsiMoveX (xPos);

    pWrite (Copy(Str, Junk, Field));
    If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor2);

    pWrite (strRep(FieldCh, Field - Length(Copy(Str, Junk, Field))));
    If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor1);

    AnsiMoveX (xPos + CurPos - 1);
  End;

  Procedure ReDrawPart;
  Begin
    pWrite (Copy(Str, StrPos, Field - CurPos + 1));
    If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor2);

    pWrite (strRep(FieldCh, (Field - CurPos + 1) - Length(Copy(Str, StrPos, Field - CurPos + 1))));
    If UseInField Then AnsiColor(TBBSCore(Core).Theme.FieldColor1);

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

  Procedure Clear;
  Begin
    Str    := '';
    StrPos := 1;
    Junk   := 1;
    CurPos := 1;

    ReDraw;
  End;

Begin
//  PurgeInputBuffer;

  If UseInLimit Then Begin
    Field      := InLimit;
    UseInLimit := False;
  End;

  If UseInSize Then Begin
    UseInSize := False;

    If InSize <= Max Then Max := InSize;
  End;

  xPos    := Console.CursorX;
  FieldCh := ' ';

  // this is poorly implemented but to expand on it will require MPL
  // programs to change. :(  we are stuck at the cap for input types
  // because of this.

  If Mode > 10 Then Begin
    Dec (Mode, 10);

    If UseInField and (Graphics = 1) Then Begin
      FieldCh := TBBSCore(Core).Theme.FieldChar;

      AnsiColor (TBBSCore(Core).Theme.FieldColor2);
      BufAddStr (strRep(FieldCh, Field));
      AnsiColor (TBBSCore(Core).Theme.FieldColor1);
      AnsiMoveX (xPos);
    End Else
      UseInField := False;
  End Else
    UseInField := False;

  If Mode = 8 Then
    Case bbsCfg.UserNameFormat of
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

                Str    := InputData[BackPos];
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

                AnsiMoveX (Console.CursorX - 1);
              End;
        #77 : If StrPos < Length(Str) + 1 Then Begin
                If (CurPos = Field) and (StrPos < Length(Str)) Then
                  ScrollRight;

                Inc (CurPos);
                Inc (StrPos);

                AnsiMoveX (Console.CursorX + 1);
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
                If (Default <> '') And (Str = Default) Then Begin
                  Clear;

                  Continue;
                End;

                Dec    (StrPos);
                Delete (Str, StrPos, 1);

                If CurPos = 1 Then
                  ScrollLeft
                Else
                If StrPos = Length(Str) + 1 Then Begin
                  If UseInField Then
                    AnsiColor(TBBSCore(Core).Theme.FieldColor2);

                  BufAddStr (#8 + FieldCh + #8);

                  If UseInField Then
                    AnsiColor(TBBSCore(Core).Theme.FieldColor1);

                  Dec (CurPos);
                End Else Begin
                  BufAddChar (#8);

                  Dec (CurPos);

                  ReDrawPart;
                End;
              End;
        #13 : Break;
        ^Y  : Clear;
        #32..
        #254: Begin
              If (Default <> '') And (Str = Default) Then Clear;

              If Length(Str) < Max Then
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

Function TBBSIO.DrawPercent (Bar: RecPercent; Part, Whole: SmallInt; Var Percent: SmallInt) : String;
Var
  FillSize : Byte;
  Attr     : Byte;
Begin
  Attr := Console.TextAttr;

  Console.TextAttr := 0;  // kludge to force it to return full ansi codes

  If Part > Whole Then Part := Whole;

  If (Part = 0) or (Whole = 0) Then Begin
    FillSize := 0;
    Percent  := 0;
  End Else Begin
    FillSize := Round(Part / Whole * Bar.BarLength);
    Percent  := Round(Part / Whole * 100);
  End;

  Result := Attr2Ansi(Bar.HiAttr) + strRep(Bar.HiChar, FillSize) +
            Attr2Ansi(Bar.LoAttr) + strRep(Bar.LoChar, Bar.BarLength - FillSize) +
            Pipe2Ansi(16) + Attr2Ansi(Attr);
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
  {$IFDEF UNIX}
  While Keyboard.KeyPressed Do Keyboard.ReadKey;
  {$ENDIF}
  {$IFDEF WINDOWS}
  If Not TBBSCore(Core).LocalMode Then TBBSCore(Core).Client.PurgeInputData(100);
  If TBBSCore(Core).LocalMode Then While Keyboard.KeyPressed Do Keyboard.ReadKey;
  {$ENDIF}
End;

{$IFDEF WINDOWS}
Procedure TBBSIO.LocalScreenDisable;
Begin
  Console.ClearScreenNoUpdate;
  Console.WriteXYNoUpdate(1, 1, 7, 'Screen disabled. Press ALT-V to view user');
  Console.Active := False;
End;

Procedure TBBSIO.LocalScreenEnable;
Begin
  Console.Active := True;
  Console.ShowBuffer;
  UpdateStatusLine(Session.StatusPtr, '');
End;
{$ENDIF}

End.

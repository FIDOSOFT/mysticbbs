
Function VarType2Char (T: TIdentTypes) : Char;
Begin
  Case T of
    iString   : Result := 's';
    iChar     : Result := 'c';
    iByte     : Result := 'b';
    iShort    : Result := 'h';
    iWord     : Result := 'w';
    iInteger  : Result := 'i';
    iLongInt  : Result := 'l';
    iCardinal : Result := 'a';
    iReal     : Result := 'r';
    iBool     : Result := 'o';
    iFile     : Result := 'f';
    iRecord   : Result := 'x';
    iPointer  : Result := 'p';
  Else
    Result := ' ';
  End;
End;

Function Char2VarType (C: Char) : TIdentTypes;
Begin
  Case UpCase(C) of
    'S' : Result := iString;
    'C' : Result := iChar;
    'B' : Result := iByte;
    'H' : Result := iShort;
    'W' : Result := iWord;
    'I' : Result := iInteger;
    'L' : Result := iLongInt;
    'A' : Result := iCardinal;
    'R' : Result := iReal;
    'O' : Result := iBool;
    'F' : Result := iFile;
    'X' : Result := iRecord;
    'P' : Result := iPointer;
  Else
    Result := iNone;
  End;
End;

Function GetVarSize (T: TIdentTypes) : Word;
Begin
  Case T of
    iRecord,
    iNone     : Result := 0;
    iString   : Result := 256;
    iChar     : Result := 1;
    iByte     : Result := 1;
    iShort    : Result := 1;
    iWord     : Result := 2;
    iInteger  : Result := 2;
    iLongInt  : Result := 4;
    iCardinal : Result := 4;
    iReal     : Result := SizeOf(Real); // {$IFDEF FPC}8{$ELSE}6{$ENDIF};
    iBool     : Result := 1;
    iFile     : Result := SizeOf(File); // was 128;
  End;
End;

Procedure InitProcedures (O: Pointer; S: Pointer; Var CV: VarDataRec; Var X: Word; Var IW: Word; Mode: Byte);

  Procedure AddProc ({$IFDEF MPLPARSER} I: String; {$ENDIF} P: String; T: TIdentTypes);
  Begin
    Inc(X);
    New(CV[X]);

    With CV[X]^ Do Begin
      VarID     := IW;
      Inc(IW);
      vType  := T;
      Move(P[1], Params, Ord(P[0]));
      NumParams := Ord(p[0]);
    {$IFNDEF MPLPARSER}
      VarSize  := 0;
      DataSize := 0;
      Data     := NIL;
      ProcPos  := 0;
      Kill     := True;
      FillChar (pID, SizeOf(pID), 0);
    {$ELSE}
      Ident  := I;
      InProc := False;
      Proc   := True;
    {$ENDIF}
      ArrPos := 0;
    End;
  End;

  Procedure AddStr ({$IFDEF MPLPARSER} I: String; {$ENDIF} T: TIdentTypes; SI: Word);
  Begin
    Inc(X);
    New(CV[X]);

    With cV[x]^ Do Begin
      VarID     := IW;
      Inc(IW);
      vType  := T;
      NumParams := 0;
    {$IFNDEF MPLPARSER}
      VarSize   := SI + 1;
      DataSize  := VarSize;
      GetMem   (Data,  DataSize);
      FillChar (Data^, DataSize, 0);
      FillChar (pID, SizeOf(pID), 0);  //cant we just assign it to 0 here?
      ProcPos   := 0;
      Kill   := True;
    {$ELSE}
      Ident  := I;
      InProc := False;
      Proc := False;
    {$ENDIF}
      ArrPos := 0;
    End;
  End;

  Procedure AddVar ({$IFDEF MPLPARSER} I: String; {$ENDIF} T: TIdentTypes);
  Begin
    AddStr ({$IFDEF MPLPARSER} I, {$ENDIF} T, GetVarSize(T) - 1);
  End;

  Procedure AddPointer ({$IFDEF MPLPARSER} I: String; {$ENDIF} T: TIdentTypes; SI: Word; PD: Pointer);
  Begin
    Inc(x);
    New(cV[x]);

    With cV[x]^ Do Begin
      VarID     := IW;
      Inc(IW);
      vType  := t;
      NumParams := 0;
    {$IFNDEF MPLPARSER}
      If T = iString Then VarSize := SI + 1 Else VarSize := SI;
      DataSize  := VarSize;
      Data   := PD;
      FillChar (pID, SizeOf(pID), 0);
      ProcPos := 0;
      Kill   := False;
    {$ELSE}
      Ident  := I;
      InProc := False;
      Proc := False;
    {$ENDIF}
      ArrPos := 0;
    End;
  End;

Begin
  Case Mode of
    0 : Begin
          IW := 0;

          AddProc    ({$IFDEF MPLPARSER} 'write',          {$ENDIF} 's',      iNone);    // 0
          AddProc    ({$IFDEF MPLPARSER} 'writeln',        {$ENDIF} 's',      iNone);    // 1
          AddProc    ({$IFDEF MPLPARSER} 'clrscr',         {$ENDIF} '',       iNone);    // 2
          AddProc    ({$IFDEF MPLPARSER} 'clreol',         {$ENDIF} '',       iNone);    // 3
          AddProc    ({$IFDEF MPLPARSER} 'gotoxy',         {$ENDIF} 'bb',     iNone);    // 4
          AddProc    ({$IFDEF MPLPARSER} 'wherex',         {$ENDIF} '',       iByte);    // 5
          AddProc    ({$IFDEF MPLPARSER} 'wherey',         {$ENDIF} '',       iByte);    // 6
          AddProc    ({$IFDEF MPLPARSER} 'readkey',        {$ENDIF} '',       iString);  // 7
          AddProc    ({$IFDEF MPLPARSER} 'delay',          {$ENDIF} 'l',      iNone);    // 8
          AddProc    ({$IFDEF MPLPARSER} 'random',         {$ENDIF} 'l',      iLongInt); // 9
          AddProc    ({$IFDEF MPLPARSER} 'chr',            {$ENDIF} 'b',      iChar);    // 10
          AddProc    ({$IFDEF MPLPARSER} 'ord',            {$ENDIF} 's',      iByte);    // 11
          AddProc    ({$IFDEF MPLPARSER} 'copy',           {$ENDIF} 'sll',    iString);  // 12
          AddProc    ({$IFDEF MPLPARSER} 'delete',         {$ENDIF} 'Sll',    iNone);    // 13
          AddProc    ({$IFDEF MPLPARSER} 'insert',         {$ENDIF} 'sSl',    iNone);    // 14
          AddProc    ({$IFDEF MPLPARSER} 'length',         {$ENDIF} 's',      iLongInt); // 15
          AddProc    ({$IFDEF MPLPARSER} 'odd',            {$ENDIF} 'l',      iBool);    // 16
          AddProc    ({$IFDEF MPLPARSER} 'pos',            {$ENDIF} 'ss',     iLongInt); // 17
          AddProc    ({$IFDEF MPLPARSER} 'keypressed',     {$ENDIF} '',       iBool);    // 18
          AddProc    ({$IFDEF MPLPARSER} 'padrt',          {$ENDIF} 'sbs',    iString);  // 19
          AddProc    ({$IFDEF MPLPARSER} 'padlt',          {$ENDIF} 'sbs',    iString);  // 20
          AddProc    ({$IFDEF MPLPARSER} 'padct',          {$ENDIF} 'sbs',    iString);  // 21
          AddProc    ({$IFDEF MPLPARSER} 'upper',          {$ENDIF} 's',      iString);  // 22
          AddProc    ({$IFDEF MPLPARSER} 'lower',          {$ENDIF} 's',      iString);  // 23
          AddProc    ({$IFDEF MPLPARSER} 'strrep',         {$ENDIF} 'sb',     iString);  // 24
          AddProc    ({$IFDEF MPLPARSER} 'strcomma',       {$ENDIF} 'l',      iString);  // 25
          AddProc    ({$IFDEF MPLPARSER} 'int2str',        {$ENDIF} 'l',      iString);  // 26
          AddProc    ({$IFDEF MPLPARSER} 'str2int',        {$ENDIF} 's',      iLongInt); // 27
          AddProc    ({$IFDEF MPLPARSER} 'int2hex',        {$ENDIF} 'l',      iString);  // 28
          AddProc    ({$IFDEF MPLPARSER} 'wordget',        {$ENDIF} 'bss',    iString);  // 29
          AddProc    ({$IFDEF MPLPARSER} 'wordpos',        {$ENDIF} 'bss',    iByte);    // 30
          AddProc    ({$IFDEF MPLPARSER} 'wordcount',      {$ENDIF} 'ss',     iByte);    // 31
          AddProc    ({$IFDEF MPLPARSER} 'stripl',         {$ENDIF} 'ss',     iString);  // 32
          AddProc    ({$IFDEF MPLPARSER} 'stripr',         {$ENDIF} 'ss',     iString);  // 33
          AddProc    ({$IFDEF MPLPARSER} 'stripb',         {$ENDIF} 'ss',     iString);  // 34
          AddProc    ({$IFDEF MPLPARSER} 'striplow',       {$ENDIF} 's',      iString);  // 35
          AddProc    ({$IFDEF MPLPARSER} 'stripmci',       {$ENDIF} 's',      iString);  // 36
          AddProc    ({$IFDEF MPLPARSER} 'mcilength',      {$ENDIF} 's',      iByte);    // 37
          AddProc    ({$IFDEF MPLPARSER} 'initials',       {$ENDIF} 's',      iString);  // 38
          AddProc    ({$IFDEF MPLPARSER} 'strwrap',        {$ENDIF} 'SSb',    iByte);    // 39
          AddProc    ({$IFDEF MPLPARSER} 'replace',        {$ENDIF} 'sss',    iString);  // 40
          AddProc    ({$IFDEF MPLPARSER} 'readenv',        {$ENDIF} 's',      iString);  // 41
          AddProc    ({$IFDEF MPLPARSER} 'fileexist',      {$ENDIF} 's',      iBool);    // 42
          AddProc    ({$IFDEF MPLPARSER} 'fileerase',      {$ENDIF} 's',      iNone);    // 43
          AddProc    ({$IFDEF MPLPARSER} 'direxist',       {$ENDIF} 's',      iBool);    // 44
          AddProc    ({$IFDEF MPLPARSER} 'timermin',       {$ENDIF} '',       iLongInt); // 45
          AddProc    ({$IFDEF MPLPARSER} 'timer',          {$ENDIF} '',       iLongInt); // 46
          AddProc    ({$IFDEF MPLPARSER} 'datetime',       {$ENDIF} '',       iLongInt); // 47
          AddProc    ({$IFDEF MPLPARSER} 'datejulian',     {$ENDIF} '',       iLongInt); // 48
          AddProc    ({$IFDEF MPLPARSER} 'datestr',        {$ENDIF} 'lb',     iString);  // 49
          AddProc    ({$IFDEF MPLPARSER} 'datestrjulian',  {$ENDIF} 'lb',     iString);  // 50
          AddProc    ({$IFDEF MPLPARSER} 'date2dos',       {$ENDIF} 's',      iLongInt); // 51
          AddProc    ({$IFDEF MPLPARSER} 'date2julian',    {$ENDIF} 's',      iLongInt); // 52
          AddProc    ({$IFDEF MPLPARSER} 'dateg2j',        {$ENDIF} 'lllL',   iNone);    // 53
          AddProc    ({$IFDEF MPLPARSER} 'datej2g',        {$ENDIF} 'liii',   iNone);    // 54
          AddProc    ({$IFDEF MPLPARSER} 'datevalid',      {$ENDIF} 's',      iString);  // 55
          AddProc    ({$IFDEF MPLPARSER} 'timestr',        {$ENDIF} 'lo',     iString);  // 56
          AddProc    ({$IFDEF MPLPARSER} 'dayofweek',      {$ENDIF} '',       iByte);    // 57
          AddProc    ({$IFDEF MPLPARSER} 'daysago',        {$ENDIF} 'l',      iLongInt); // 58
          AddProc    ({$IFDEF MPLPARSER} 'justfile',       {$ENDIF} 's',      iString);  // 59
          AddProc    ({$IFDEF MPLPARSER} 'justfilename',   {$ENDIF} 's',      iString);  // 60
          AddProc    ({$IFDEF MPLPARSER} 'justfileext',    {$ENDIF} 's',      iString);  // 61
          AddProc    ({$IFDEF MPLPARSER} 'fassign',        {$ENDIF} 'Fsl',    iNone);    // 62
          AddProc    ({$IFDEF MPLPARSER} 'freset',         {$ENDIF} 'F',      iNone);    // 63
          AddProc    ({$IFDEF MPLPARSER} 'frewrite',       {$ENDIF} 'F',      iNone);    // 64
          AddProc    ({$IFDEF MPLPARSER} 'fclose',         {$ENDIF} 'F',      iNone);    // 65
          AddProc    ({$IFDEF MPLPARSER} 'fseek',          {$ENDIF} 'Fl',     iNone);    // 66
          AddProc    ({$IFDEF MPLPARSER} 'feof',           {$ENDIF} 'F',      iBool);    // 67
          AddProc    ({$IFDEF MPLPARSER} 'fsize',          {$ENDIF} 'F',      iLongInt); // 68
          AddProc    ({$IFDEF MPLPARSER} 'fpos',           {$ENDIF} 'F',      iLongInt); // 69
          AddProc    ({$IFDEF MPLPARSER} 'fread',          {$ENDIF} 'F*w',    iNone);    // 70
          AddProc    ({$IFDEF MPLPARSER} 'fwrite',         {$ENDIF} 'F*w',    iNone);    // 71
          AddProc    ({$IFDEF MPLPARSER} 'freadln',        {$ENDIF} 'FS',     iNone);    // 72
          AddProc    ({$IFDEF MPLPARSER} 'fwriteln',       {$ENDIF} 'Fs',     iNone);    // 73
          AddProc    ({$IFDEF MPLPARSER} 'pathchar',       {$ENDIF} '',       iChar);    // 74
          AddProc    ({$IFDEF MPLPARSER} 'bitcheck',       {$ENDIF} 'b*',     iBool);    // 75
          AddProc    ({$IFDEF MPLPARSER} 'bittoggle',      {$ENDIF} 'b*',     iNone);    // 76
          AddProc    ({$IFDEF MPLPARSER} 'bitset',         {$ENDIF} 'b*o',    iNone);    // 77
          AddProc    ({$IFDEF MPLPARSER} 'findfirst',      {$ENDIF} 'sw',     iNone);    // 78
          AddProc    ({$IFDEF MPLPARSER} 'findnext',       {$ENDIF} '',       iNone);    // 79
          AddProc    ({$IFDEF MPLPARSER} 'findclose',      {$ENDIF} '',       iNone);    // 80
          AddProc    ({$IFDEF MPLPARSER} 'justpath',       {$ENDIF} 's',      iString);  // 81
          AddProc    ({$IFDEF MPLPARSER} 'randomize',      {$ENDIF} '',       iNone);    // 82
          AddProc    ({$IFDEF MPLPARSER} 'paramcount',     {$ENDIF} '',       iByte);    // 83
          AddProc    ({$IFDEF MPLPARSER} 'paramstr',       {$ENDIF} 'b',      iString);  // 84
          AddProc    ({$IFDEF MPLPARSER} 'textattr',       {$ENDIF} '',       iByte);    // 85
          AddProc    ({$IFDEF MPLPARSER} 'textcolor',      {$ENDIF} 'b',      iNone);    // 86
          AddProc    ({$IFDEF MPLPARSER} 'addslash',       {$ENDIF} 's',      iString);  // 87
          AddProc    ({$IFDEF MPLPARSER} 'strippipe',      {$ENDIF} 's',      iString);  // 88
          AddProc    ({$IFDEF MPLPARSER} 'sizeof',         {$ENDIF} '*',      iLongInt); // 89
          AddProc    ({$IFDEF MPLPARSER} 'fillchar',       {$ENDIF} '*lc',    iNone);    // 90
          AddProc    ({$IFDEF MPLPARSER} 'fwriterec',      {$ENDIF} 'Fx',     iNone);    // 91
          AddProc    ({$IFDEF MPLPARSER} 'freadrec',       {$ENDIF} 'Fx',     iNone);    // 92

          IW := 500; // BEGIN BBS-SPECIFIC STUFF

          AddProc    ({$IFDEF MPLPARSER} 'input',          {$ENDIF} 'bbbs',   iString);  // 500
          AddProc    ({$IFDEF MPLPARSER} 'getuser',        {$ENDIF} 'l',      iBool);    // 501
          AddProc    ({$IFDEF MPLPARSER} 'onekey',         {$ENDIF} 'so',     iChar);    // 502
          AddProc    ({$IFDEF MPLPARSER} 'getthisuser',    {$ENDIF} '',       iNone);    // 503
          AddProc    ({$IFDEF MPLPARSER} 'inputyn',        {$ENDIF} 's',      iBool);    // 504
          AddProc    ({$IFDEF MPLPARSER} 'inputny',        {$ENDIF} 's',      iBool);    // 505
          AddProc    ({$IFDEF MPLPARSER} 'dispfile',       {$ENDIF} 's',      iBool);    // 506
          AddProc    ({$IFDEF MPLPARSER} 'filecopy',       {$ENDIF} 'ss',     iBool);    // 507
          AddProc    ({$IFDEF MPLPARSER} 'menucmd',        {$ENDIF} 'ss',     iNone);    // 508
          AddProc    ({$IFDEF MPLPARSER} 'stuffkey',       {$ENDIF} 's',      iNone);    // 509
          AddProc    ({$IFDEF MPLPARSER} 'acs',            {$ENDIF} 's',      iBool);    // 510
          AddProc    ({$IFDEF MPLPARSER} 'upuser',         {$ENDIF} 'i',      iNone);    // 511
          AddProc    ({$IFDEF MPLPARSER} 'setusertime',    {$ENDIF} 'i',      iNone);    // 512
          AddProc    ({$IFDEF MPLPARSER} 'hangup',         {$ENDIF} '',       iNone);    // 513
          AddProc    ({$IFDEF MPLPARSER} 'getmbase',       {$ENDIF} 'l',      iBool);    // 514
          AddProc    ({$IFDEF MPLPARSER} 'getprompt',      {$ENDIF} 'l',      iString);  // 515
          AddProc    ({$IFDEF MPLPARSER} 'getmgroup',      {$ENDIF} 'l',      iBool);    // 516
          AddProc    ({$IFDEF MPLPARSER} 'purgeinput',     {$ENDIF} '',       iNone);    // 517
          AddProc    ({$IFDEF MPLPARSER} 'getfbase',       {$ENDIF} 'l',      iBool);    // 518
          AddProc    ({$IFDEF MPLPARSER} 'getfgroup',      {$ENDIF} 'l',      iBool);    // 519
          AddProc    ({$IFDEF MPLPARSER} 'sysoplog',       {$ENDIF} 's',      iNone);    // 520
          AddProc    ({$IFDEF MPLPARSER} 'movex',          {$ENDIF} 'b',      iNone);    // 521
          AddProc    ({$IFDEF MPLPARSER} 'movey',          {$ENDIF} 'b',      iNone);    // 522
          AddProc    ({$IFDEF MPLPARSER} 'writepipe',      {$ENDIF} 's',      iNone);    // 523
          AddProc    ({$IFDEF MPLPARSER} 'writepipeln',    {$ENDIF} 's',      iNone);    // 524
          AddProc    ({$IFDEF MPLPARSER} 'writeraw',       {$ENDIF} 's',      iNone);    // 525
          AddProc    ({$IFDEF MPLPARSER} 'writerawln',     {$ENDIF} 's',      iNone);    // 526
          AddProc    ({$IFDEF MPLPARSER} 'mci2str',        {$ENDIF} 's',      iString);  // 527
          AddProc    ({$IFDEF MPLPARSER} 'getusertime',    {$ENDIF} '',       iInteger); // 528
          AddProc    ({$IFDEF MPLPARSER} 'getscreeninfo',  {$ENDIF} 'bBBB',   iNone);    // 529
          AddProc    ({$IFDEF MPLPARSER} 'setprompt',      {$ENDIF} 'bs',     iNone);    // 530
          AddProc    ({$IFDEF MPLPARSER} 'moreprompt',     {$ENDIF} '',       iChar);    // 531
          AddProc    ({$IFDEF MPLPARSER} 'pause',          {$ENDIF} '',       iNone);    // 532
          AddProc    ({$IFDEF MPLPARSER} 'setpromptinfo',  {$ENDIF} 'bs',     iNone);    // 533
          AddProc    ({$IFDEF MPLPARSER} 'bufflush',       {$ENDIF} '',       iNone);    // 534
          AddProc    ({$IFDEF MPLPARSER} 'strmci',         {$ENDIF} 's',      iString);  // 535
          AddProc    ({$IFDEF MPLPARSER} 'getcharxy',      {$ENDIF} 'bb',     iChar);    // 536
          AddProc    ({$IFDEF MPLPARSER} 'getattrxy',      {$ENDIF} 'bb',     iByte);    // 537
          AddProc    ({$IFDEF MPLPARSER} 'putthisuser',    {$ENDIF} '',       iNone);    // 538
          AddProc    ({$IFDEF MPLPARSER} 'putuser',        {$ENDIF} 'l',      iNone);    // 539
          AddProc    ({$IFDEF MPLPARSER} 'isuser',         {$ENDIF} 's',      iBool);    // 540

{ END OF PROCEDURE DEFINITIONS }

          AddPointer ({$IFDEF MPLPARSER} 'ioresult',     {$ENDIF} iLongInt,   4, {$IFNDEF MPLPARSER} @TInterpEngine(S).IoError           {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'doserror',     {$ENDIF} iInteger,   2, {$IFNDEF MPLPARSER} @DosError                           {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'progparams',   {$ENDIF} iString,  256, {$IFNDEF MPLPARSER} @TInterpEngine(S).ParamsStr         {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'progname',     {$ENDIF} iString,  256, {$IFNDEF MPLPARSER} @TInterpEngine(S).MPEName           {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'graphics',     {$ENDIF} iByte,      1, {$IFNDEF MPLPARSER} @Session.io.Graphics                {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'isarrow',      {$ENDIF} iBool,      1, {$IFNDEF MPLPARSER} @Session.io.IsArrow                 {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'nodenum',      {$ENDIF} iByte,      1, {$IFNDEF MPLPARSER} @Session.NodeNum                    {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'local',        {$ENDIF} iBool,      1, {$IFNDEF MPLPARSER} @Session.LocalMode                  {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'allowarrow',   {$ENDIF} iBool,      1, {$IFNDEF MPLPARSER} @Session.io.AllowArrow              {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'ignoregroups', {$ENDIF} iBool,      1, {$IFNDEF MPLPARSER} @Session.User.IgnoreGroup           {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'pausepos',     {$ENDIF} iByte,      1, {$IFNDEF MPLPARSER} @Session.io.PausePtr                {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'allowmci',     {$ENDIF} iBool,      1, {$IFNDEF MPLPARSER} @Session.io.PausePtr                {$ELSE} NIL {$ENDIF});

          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarDir := X + 1; {$ENDIF}

          AddPointer ({$IFDEF MPLPARSER} 'dirname',    {$ENDIF} iString,  256, {$IFNDEF MPLPARSER} @TInterpEngine(S).DirInfo.Name {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'dirsize',    {$ENDIF} iLongInt,   4, {$IFNDEF MPLPARSER} @TInterpEngine(S).DirInfo.Size {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'dirtime',    {$ENDIF} iLongInt,   4, {$IFNDEF MPLPARSER} @TInterpEngine(S).DirInfo.Time {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'dirattr',    {$ENDIF} iLongInt,   SizeOf(SearchRec.Attr), {$IFNDEF MPLPARSER} @TInterpEngine(S).DirInfo.Attr {$ELSE} NIL {$ENDIF});
        End;
    1 : Begin
          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarUser := X + 1; {$ENDIF}

          AddVar ({$IFDEF MPLPARSER} 'userindex',     {$ENDIF} iLongInt);
          AddStr ({$IFDEF MPLPARSER} 'username',      {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'useralias',     {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'useraddress',   {$ENDIF} iString, 30);
          AddVar ({$IFDEF MPLPARSER} 'usersec',       {$ENDIF} iInteger);
          AddVar ({$IFDEF MPLPARSER} 'usersex',       {$ENDIF} iChar);
          AddVar ({$IFDEF MPLPARSER} 'userfirston',   {$ENDIF} iLongInt);
          AddVar ({$IFDEF MPLPARSER} 'userlaston',    {$ENDIF} iLongInt);
          AddVar ({$IFDEF MPLPARSER} 'userdatetype',  {$ENDIF} iByte);
          AddVar ({$IFDEF MPLPARSER} 'usercalls',     {$ENDIF} iLongInt);
          AddStr ({$IFDEF MPLPARSER} 'userpassword',  {$ENDIF} iString, 15);
          AddVar ({$IFDEF MPLPARSER} 'userflags',     {$ENDIF} iLongInt);
        End;
    2 : Begin
          AddPointer ({$IFDEF MPLPARSER} 'cfgsyspath',     {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.SystemPath     {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgdatapath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.DataPath       {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfglogspath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.LogsPath       {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgmsgspath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.MsgsPath       {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgattpath',     {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.AttachPath     {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgqwkpath',     {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.QwkPath        {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgmenupath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Session.Theme.MenuPath {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgtextpath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Session.Theme.TextPath {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgmpepath',     {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Config.ScriptPath     {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgtemppath',    {$ENDIF} iString, mysMaxPathSize, {$IFNDEF MPLPARSER} @Session.TempPath      {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgtimeout',     {$ENDIF} iWord,   4,              {$IFNDEF MPLPARSER} @Config.Inactivity     {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgseeinvis',    {$ENDIF} iString, 20,             {$IFNDEF MPLPARSER} @Config.AcsSeeInvis    {$ELSE} NIL {$ENDIF});
          AddPointer ({$IFDEF MPLPARSER} 'cfgtnnodes',     {$ENDIF} iByte,    1,             {$IFNDEF MPLPARSER} @Config.INetTNNodes    {$ELSE} NIL {$ENDIF});
        End;
    3 : Begin
          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarMBase := X + 1; {$ENDIF}

          AddVar ({$IFDEF MPLPARSER} 'mbaseindex',    {$ENDIF} iInteger);
          AddStr ({$IFDEF MPLPARSER} 'mbasename',     {$ENDIF} iString, 40);
          AddStr ({$IFDEF MPLPARSER} 'mbaseacs',      {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'mbaseracs',     {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'mbasepacs',     {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'mbasesacs',     {$ENDIF} iString, 30);
        End;
    4 : Begin
          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarMGroup := X + 1; {$ENDIF}

          AddStr ({$IFDEF MPLPARSER} 'mgroupname',    {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'mgroupacs',     {$ENDIF} iString, 30);
          AddVar ({$IFDEF MPLPARSER} 'mgrouphidden',  {$ENDIF} iBool);
        End;
    5 : Begin
          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarFBase := X + 1; {$ENDIF}

          AddStr ({$IFDEF MPLPARSER} 'fbasename',     {$ENDIF} iString, 40);
          AddStr ({$IFDEF MPLPARSER} 'fbaseacs',      {$ENDIF} iString, 30);
        End;
    6 : Begin
          {$IFNDEF MPLPARSER} TInterpEngine(S).IdxVarFGroup := X + 1; {$ENDIF}

          AddStr ({$IFDEF MPLPARSER} 'fgroupname',    {$ENDIF} iString, 30);
          AddStr ({$IFDEF MPLPARSER} 'fgroupacs',     {$ENDIF} iString, 30);
          AddVar ({$IFDEF MPLPARSER} 'fgrouphidden',  {$ENDIF} iBool);
        End;
  End;
End;

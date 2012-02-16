Unit bbs_Ansi_MenuBox;

{$I M_OPS.PAS}

Interface

Uses
  m_Types;

Procedure WriteXY          (X, Y, A: Byte; S: String);
Procedure WriteXYPipe      (X, Y, A, SZ : Byte; S: String);
Function  InXY             (X, Y, Field, Max, Mode: Byte; Default: String) : String;
Procedure VerticalLine     (X, Y1, Y2 : Byte);
Function  ShowMsgBox       (BoxType : Byte; Str : String) : Boolean;

Type
  TAnsiMenuBox = Class
    Image      : TConsoleImageRec;
    HideImage  : ^TConsoleImageRec;
    FrameType  : Byte;
    BoxAttr    : Byte;
    Box3D      : Boolean;
    BoxAttr2   : Byte;
    BoxAttr3   : Byte;
    BoxAttr4   : Byte;
    Shadow     : Boolean;
    ShadowAttr : Byte;
    HeadAttr   : Byte;
    HeadType   : Byte;
    Header     : String;
    WasOpened  : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   Open (X1, Y1, X2, Y2: Byte);
    Procedure   Close;
    Procedure   Hide;
    Procedure   Show;
  End;

  TAnsiMenuListStatusProc = Procedure (Num: Word; Str: String);

  TAnsiMenuListBoxRec = Record
    Name   : String;
    Tagged : Byte;                     { 0 = false, 1 = true, 2 = never }
  End;

  TAnsiMenuList = Class
    List       : Array[1..65535] of ^TAnsiMenuListBoxRec;
    Box        : TAnsiMenuBox;
    HiAttr     : Byte;
    LoAttr     : Byte;
    PosBar     : Boolean;
    Format     : Byte;
    LoChars    : String;
    HiChars    : String;
    ExitCode   : Char;
    Picked     : Integer;
    TopPage    : Integer;
    NoWindow   : Boolean;
    ListMax    : Integer;
    AllowTag   : Boolean;
    TagChar    : Char;
    TagKey     : Char;
    TagPos     : Byte;
    TagAttr    : Byte;
    Marked     : Word;
    StatusProc : TAnsiMenuListStatusProc;
    Width      : Integer;
    WinSize    : Integer;
    X1         : Byte;
    Y1         : Byte;
    NoInput    : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   Open (BX1, BY1, BX2, BY2: Byte);
    Procedure   Close;
    Procedure   Add (Str: String; B: Byte);
    Procedure   Get (Num: Word; Var Str: String; Var B: Boolean);
    Procedure   SetStatusProc (P: TAnsiMenuListStatusProc);
    Procedure   Clear;
    Procedure   Delete (RecPos : Word);
    Procedure   Update;
  End;

Implementation

Uses
  m_Strings,
  BBS_Core,
  BBS_IO,
  BBS_Common;

Procedure WriteXY (X, Y, A: Byte; S: String);
Begin
  Session.io.AnsiGotoXY(X, Y);
  Session.io.AnsiColor(A);
  Session.io.OutRaw(S);
End;

Procedure WriteXYPipe (X, Y, A, SZ: Byte; S: String);
Begin
  Session.io.AnsiGotoXY(X, Y);
  Session.io.AnsiColor(A);
  Session.io.OutPipe(S);

  While Screen.CursorX < SZ Do Session.io.BufAddChar(' ');
End;

Function InXY (X, Y, Field, Max, Mode: Byte; Default: String) : String;
Begin
  Session.io.AnsiGotoXY (X, Y);

  InXY := Session.io.GetInput (Field, Max, Mode, Default);
End;

Procedure VerticalLine (X, Y1, Y2: Byte);
Var
  Count : Byte;
Begin
  For Count := Y1 to Y2 Do
    WriteXY (X, Count, 112, '³');
End;

Function ShowMsgBox (BoxType : Byte; Str : String) : Boolean;
Var
  Len    : Byte;
  Len2   : Byte;
  Pos    : Byte;
  MsgBox : TAnsiMenuBox;
  Ch     : Char;
Begin
  Result := True;

{ 0 = ok box }
{ 1 = y/n box }
{ 2 = just box }
{ 3 = just box dont close }

  MsgBox := TAnsiMenuBox.Create;

  Len := (80 - (Length(Str) + 3)) DIV 2;
  Pos := 1;

  MsgBox.Header := ' Info ';

  If BoxType < 2 Then
    MsgBox.Open (Len, 10, Len + Length(Str) + 3, 15)
  Else
    MsgBox.Open (Len, 10, Len + Length(Str) + 3, 14);

  WriteXY (Len + 2,  12, 113, Str);

  Case BoxType of
    0 : Begin
          Len2 := (Length(Str) - 4) DIV 2;
          WriteXY (Len + Len2 + 2, 14, 30, ' OK ');
          Ch := Session.io.GetKey;
        End;
    1 : Repeat
          Len2 := (Length(Str) - 9) DIV 2;

          WriteXY (Len + Len2 + 2, 14, 113, ' YES ');
          WriteXY (Len + Len2 + 7, 14, 113, ' NO ');

          If Pos = 1 Then
            WriteXY (Len + Len2 + 2, 14, 30, ' YES ')
          Else
            WriteXY (Len + Len2 + 7, 14, 30, ' NO ');

          Ch := Session.io.GetKey;

          If Session.io.IsArrow Then
            Case Ch of
              #75 : Pos := 1;
              #77 : Pos := 0;
            End
          Else
            Case Ch of
              #13 : Begin
                      Result := Boolean(Pos);
                      Break;
                    End;
              #32 : If Pos = 0 Then Inc(Pos) Else Pos := 0;
              'N' : Pos := 0;
              'Y' : Pos := 1;
            End;
        Until False;
  End;

  MsgBox.Close;
  MsgBox.Free;
End;

Constructor TAnsiMenuBox.Create;
Begin
  Inherited Create;

  Shadow     := True;
  ShadowAttr := 0;
  Header     := '';
  FrameType  := 6;
  Box3D      := True;
  BoxAttr    := 15 + 7 * 16;
  BoxAttr2   := 8  + 7 * 16;
  BoxAttr3   := 15 + 7 * 16;
  BoxAttr4   := 8  + 7 * 16;
  HeadAttr   := 0  + 7 * 16;
  HeadType   := 0;
  HideImage  := NIL;
  WasOpened  := False;

  FillChar(Image, SizeOf(TConsoleImageRec), 0);

  Session.io.BufFlush;
End;

Destructor TAnsiMenuBox.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TAnsiMenuBox.Open (X1, Y1, X2, Y2: Byte);
Const
  BF : Array[1..8] of String[8] =
        ('ÚÄ¿³³ÀÄÙ',
         'ÉÍ»ººÈÍ¼',
         'ÖÄ·ººÓÄ½',
         'ÕÍ¸³³ÔÍ¾',
         'ÛßÛÛÛÛÜÛ',
         'ÛßÜÛÛßÜÛ',
         '        ',
         '.-.||`-''');
Var
  A  : Integer;
  B  : Integer;
  Ch : Char;
Begin
  If Not WasOpened Then
    If Shadow Then
      Screen.GetScreenImage(X1, Y1, X2 + 2{3}, Y2 + 1, Image)
    Else
      Screen.GetScreenImage(X1, Y1, X2, Y2, Image);

  WasOpened := True;

  B := X2 - X1 - 1;

  If Not Box3D Then Begin
    BoxAttr2 := BoxAttr;
    BoxAttr3 := BoxAttr;
    BoxAttr4 := BoxAttr;
  End;

  WriteXY (X1, Y1, BoxAttr, BF[FrameType][1] + strRep(BF[FrameType][2], B));
  WriteXY (X2, Y1, BoxAttr4, BF[FrameType][3]);

  For A := Y1 + 1 To Y2 - 1 Do Begin
    WriteXY (X1, A, BoxAttr, BF[FrameType][4] + strRep(' ', B));
    WriteXY (X2, A, BoxAttr2, BF[FrameType][5]);
  End;

  WriteXY (X1,   Y2, BoxAttr3, BF[FrameType][6]);
  WriteXY (X1+1, Y2, BoxAttr2, strRep(BF[FrameType][7], B) + BF[FrameType][8]);

  If Header <> '' Then
    Case HeadType of
      0 : WriteXY (X1 + 1 + (B - Length(Header)) DIV 2, Y1, HeadAttr, Header);
      1 : WriteXY (X1 + 1, Y1, HeadAttr, Header);
      2 : WriteXY (X2 - Length(Header), Y1, HeadAttr, Header);
    End;

  If Shadow Then Begin
    For A := Y1 + 1 to Y2 + 1 Do
      For B := X2 to X2 + 1 Do Begin
        Ch := Screen.ReadCharXY(B, A);
        WriteXY (B + 1, A, ShadowAttr, Ch);
      End;

    A := Y2 + 1;

    For B := (X1 + 2) To (X2 + 2) Do Begin
      Ch := Screen.ReadCharXY(B, A);
      WriteXY (B, A, ShadowAttr, Ch);
    End;
  End;
End;

Procedure TAnsiMenuBox.Close;
Begin
  If WasOpened Then Session.io.RemoteRestore(Image);
End;

Procedure TAnsiMenuBox.Hide;
Begin
  If Assigned(HideImage) Then FreeMem(HideImage, SizeOf(TConsoleImageRec));

  GetMem (HideImage, SizeOf(TConsoleImageRec));

  Screen.GetScreenImage (Image.X1, Image.Y1, Image.X2, Image.Y2, HideImage^);

  Session.io.RemoteRestore(Image);
End;

Procedure TAnsiMenuBox.Show;
Begin
  If Assigned (HideImage) Then Begin
    Session.io.RemoteRestore(HideImage^);
    FreeMem (HideImage, SizeOf(TConsoleImageRec));
    HideImage := NIL;
  End;
End;

Constructor TAnsiMenuList.Create;
Begin
  Inherited Create;

  Box        := TAnsiMenuBox.Create;
  ListMax    := 0;
  HiAttr     := 15 + 1 * 16;
  LoAttr     := 1  + 7 * 16;
  PosBar     := True;
  Format     := 0;
  LoChars    := #13#27;
  HiChars    := '';
  NoWindow   := False;
  AllowTag   := False;
  TagChar    := '*';
  TagKey     := #32;
  TagPos     := 0;
  TagAttr    := 15 + 7 * 16;
  Marked     := 0;
  Picked     := 1;
  NoInput    := False;
  StatusProc := NIL;

  Session.io.BufFlush;
End;

Procedure TAnsiMenuList.Clear;
Var
  Count : Word;
Begin
  For Count := 1 to ListMax Do
    Dispose(List[Count]);

  ListMax := 0;
  Marked  := 0;
End;

Procedure TAnsiMenuList.Delete (RecPos : Word);
Var
  Count : Word;
Begin
  If List[RecPos] <> NIL Then Begin
    Dispose (List[RecPos]);

    For Count := RecPos To ListMax - 1 Do
      List[Count] := List[Count + 1];

    Dec (ListMax);
  End;
End;

Destructor TAnsiMenuList.Destroy;
Begin
  Box.Free;

  Clear;

  Inherited Destroy;
End;

// this class is very inefficient and needs to have updates redone
// BarON
// BarOFF
// UpdatePercent

Procedure TAnsiMenuList.Update;
Var
  A : LongInt;
  S : String;
  B : Integer;
  C : Integer;
Begin
  For A := 0 to WinSize - 1 Do Begin
    C := TopPage + A;

    If C <= ListMax Then Begin
      S := ' ' + List[C]^.Name + ' ';
      Case Format of
        0 : S := strPadR (S, Width, ' ');
        1 : S := strPadL (S, Width, ' ');
        2 : S := strPadC (S, Width, ' ');
      End;
    End Else
      S := strRep(' ', Width);

    If C = Picked Then B := HiAttr Else B := LoAttr;

    WriteXY (X1 + 1, Y1 + 1 + A, B, S);

    If PosBar Then
      WriteXY (X1 + Width + 1, Y1 + 1 + A, Box.BoxAttr2, #176);

    If AllowTag Then
      If (C <= ListMax) and (List[C]^.Tagged = 1) Then
        WriteXY (TagPos, Y1 + 1 + A, TagAttr, TagChar)
      Else
        WriteXY (TagPos, Y1 + 1 + A, TagAttr, ' ');
  End;

  If PosBar Then
    If (ListMax > 0) and (WinSize > 0) Then Begin
      A := (Picked * WinSize) DIV ListMax;
      If Picked >= ListMax Then A := Pred(WinSize);
      If (A < 0) or (Picked = 1) Then A := 0;
      WriteXY (X1 + Width + 1, Y1 + 1 + A, Box.BoxAttr2, #178);
    End;
End;

Procedure TAnsiMenuList.Open (BX1, BY1, BX2, BY2 : Byte);
Var
  Ch    : Char;
  A     : Word;
  sPos  : Word;
  ePos  : Word;
  First : Boolean;
Begin
  If Not NoWindow Then
    Box.Open (BX1, BY1, BX2, BY2);

  X1 := BX1;
  Y1 := BY1;

  If (Picked < TopPage) or (Picked < 1) or (Picked > ListMax) or (TopPage < 1) or (TopPage > ListMax) Then Begin
    Picked  := 1;
    TopPage := 1;
  End;

  Width   := BX2 - X1 - 1;
  WinSize := BY2 - Y1 - 1;
  TagPos  := X1 + 1;

  If NoInput Then Exit;

  Update;

  Repeat
    If Assigned(StatusProc) Then
      If ListMax > 0 Then
        StatusProc(Picked, List[Picked]^.Name)
      Else
        StatusProc(Picked, '');

    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : If Picked > 1 Then Begin { home }
                Picked  := 1;
                TopPage := 1;
                Update;
              End;
        #72 : If (TopPage > 1) Or (Picked > 1) Then Begin { up arrow }
                If Picked > 1 Then Dec (Picked);
                If Picked < TopPage Then Dec (TopPage);
                Update;
              End;
        #73,
        #75 : If (TopPage > 1) or (Picked > 1) Then Begin { page up / left arrow }
                If Picked - WinSize > 1 Then Dec (Picked, WinSize) Else Picked := 1;
                If TopPage - WinSize < 1 Then TopPage := 1 Else Dec(TopPage, WinSize);
                Update;
              End;
        #79 : If Picked < ListMax Then Begin { end }
                If ListMax > WinSize Then TopPage := ListMax - WinSize + 1;
                Picked := ListMax;
                Update;
              End;
        #80 : Begin { down arrow }
                If Picked < ListMax Then Inc (Picked);
                If Picked > TopPage + WinSize - 1 Then Inc (TopPage);
                Update;
              End;
        #77,
        #81 : If ListMax > 0 Then Begin { page down / right arrow }
                If ListMax > WinSize Then Begin
                  If Picked + WinSize > ListMax Then
                    Picked := ListMax
                  Else
                    Inc (Picked, WinSize);
                  Inc (TopPage, WinSize);
                  If TopPage + WinSize > ListMax Then TopPage := ListMax - WinSize + 1;
                End Else Begin
                  Picked := ListMax;
                End;
                Update;
              End;
      Else
        If Pos(Ch, HiChars) > 0 Then Begin
          ExitCode := Ch;
          Exit;
        End;
      End;
    End Else
      If AllowTag and (Ch = TagKey) and (List[Picked]^.Tagged <> 2) Then Begin
        If (List[Picked]^.Tagged = 1) Then Begin
          Dec (List[Picked]^.Tagged);
          Dec (Marked);
        End Else Begin
          List[Picked]^.Tagged := 1;
          Inc (Marked);
        End;
        If Picked < ListMax Then Inc (Picked);
        If Picked > TopPage + WinSize - 1 Then Inc (TopPage);
      End Else
      If Pos(Ch, LoChars) > 0 Then Begin
        ExitCode := Ch;
        Exit;
      End Else Begin
        Ch    := UpCase(Ch);
        First := True;
        sPos  := Picked + 1;
        ePos  := ListMax;

        If sPos > ListMax Then sPos := 1;

        A := sPos;

        While (A <= ePos) Do Begin
          If UpCase(List[A]^.Name[1]) = Ch Then Begin
            While A <> Picked Do Begin
              If Picked < A Then Begin
                If Picked < ListMax Then Inc (Picked);
                If Picked > TopPage + WinSize - 1 Then Inc (TopPage);
              End Else
              If Picked > A Then Begin
                If Picked > 1 Then Dec (Picked);
                If Picked < TopPage Then Dec (TopPage);
              End;
            End;
            Break;
          End;

          If (A = ListMax) and First Then Begin
            A     := 0;
            sPos  := 1;
            ePos  := Picked - 1;
            First := False;
          End;

          Inc (A);
        End;
      End;
  Until False;
End;

Procedure TAnsiMenuList.Close;
Begin
  If Not NoWindow Then Box.Close;
End;

Procedure TAnsiMenuList.Add (Str : String; B : Byte);
Begin
  Inc (ListMax);
  New (List[ListMax]);

  List[ListMax]^.Name   := Str;
  List[ListMax]^.Tagged := B;

  If B = 1 Then Inc(Marked);
End;

Procedure TAnsiMenuList.Get (Num : Word; Var Str : String; Var B : Boolean);
Begin
  Str := '';
  B   := False;

  If Num <= ListMax Then Begin
    Str := List[Num]^.Name;
    B   := List[Num]^.Tagged = 1;
  End;
End;

Procedure TAnsiMenuList.SetStatusProc (P : TAnsiMenuListStatusProc);
Begin
  StatusProc := P;
End;

End.

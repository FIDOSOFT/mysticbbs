{$I M_OPS.PAS}

Unit m_MenuBox;

Interface

Uses
  m_Types,
  m_Input,
  m_Output;

Type
  TMenuBox = Class
    Console    : TOutput;
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

    Constructor Create (Var Screen: TOutput);
    Destructor  Destroy; Override;
    Procedure   Open (X1, Y1, X2, Y2: Byte);
    Procedure   Close;
    Procedure   Hide;
    Procedure   Show;
  End;

  TMenuListStatusProc = Procedure (Num: Word; Str: String);

  TMenuListBoxRec = Record
    Name   : String;
    Tagged : Byte;                     { 0 = false, 1 = true, 2 = never }
  End;

  TMenuList = Class
    Screen     : TOutput;
    List       : Array[1..65535] of ^TMenuListBoxRec;
    Box        : TMenuBox;
    InKey      : TInput;
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
    StatusProc : TMenuListStatusProc;
    Width      : Integer;
    Length     : Integer;
    X1         : Byte;
    Y1         : Byte;
    NoInput    : Boolean;

    Constructor Create (Var S: TOutput);
    Destructor  Destroy; Override;
    Procedure   Open (BX1, BY1, BX2, BY2: Byte);
    Procedure   Close;
    Procedure   Add (Str: String; B: Byte);
    Procedure   Get (Num: Word; Var Str: String; Var B: Boolean);
    Procedure   SetStatusProc (P: TMenuListStatusProc);
    Procedure   Clear;
    Procedure   Delete (RecPos : Word);
{    Procedure   Focus (Num: Word);}
    Procedure   Update;
  End;

Implementation

Uses
  m_Strings;

Constructor TMenuBox.Create (Var Screen: TOutput);
Begin
  Inherited Create;

  Console    := Screen;
  Shadow     := True;
  ShadowAttr := 0;
  Header     := '';
  FrameType  := 6;
  Box3D      := True;
  BoxAttr    := 15 + 7 * 16;
  BoxAttr2   := 8  + 7 * 16;
  BoxAttr3   := 15 + 7 * 16;
  BoxAttr4   := 8  + 7 * 16;
  HeadAttr   := 15 + 1 * 16;
  HeadType   := 0;
  HideImage  := NIL;
  WasOpened  := False;

  FillChar(Image, SizeOf(TConsoleImageRec), 0);

  Console.BufFlush;
End;

Destructor TMenuBox.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TMenuBox.Open (X1, Y1, X2, Y2: Byte);
Const
  BF : Array[1..8] of String[8] =
        ('⁄ƒø≥≥¿ƒŸ',
         '…Õª∫∫»Õº',
         '÷ƒ∑∫∫”ƒΩ',
         '’Õ∏≥≥‘Õæ',
         '€ﬂ€€€€‹€',
         '€ﬂ‹€€ﬂ‹€',
         '        ',
         '.-.||`-''');
Var
  A  : Integer;
  B  : Integer;
  Ch : Char;
Begin
  If Not WasOpened Then
    If Shadow Then
      Console.GetScreenImage(X1, Y1, X2 + 2{3}, Y2 + 1, Image)
    Else
      Console.GetScreenImage(X1, Y1, X2, Y2, Image);

  WasOpened := True;

  B := X2 - X1 - 1;

  If Not Box3D Then Begin
    BoxAttr2 := BoxAttr;
    BoxAttr3 := BoxAttr;
    BoxAttr4 := BoxAttr;
  End;

  Console.WriteXY (X1, Y1, BoxAttr, BF[FrameType][1] + strRep(BF[FrameType][2], B));
  Console.WriteXY (X2, Y1, BoxAttr4, BF[FrameType][3]);

  For A := Y1 + 1 To Y2 - 1 Do Begin
    Console.WriteXY (X1, A, BoxAttr, BF[FrameType][4] + strRep(' ', B));
    Console.WriteXY (X2, A, BoxAttr2, BF[FrameType][5]);
  End;

  Console.WriteXY (X1,   Y2, BoxAttr3, BF[FrameType][6]);
  Console.WriteXY (X1+1, Y2, BoxAttr2, strRep(BF[FrameType][7], B) + BF[FrameType][8]);

  If Header <> '' Then
    Case HeadType of
      0 : Console.WriteXY (X1 + 1 + (B - Length(Header)) DIV 2, Y1, HeadAttr, Header);
      1 : Console.WriteXY (X1 + 1, Y1, HeadAttr, Header);
      2 : Console.WriteXY (X2 - Length(Header), Y1, HeadAttr, Header);
    End;

  If Shadow Then Begin
    For A := Y1 + 1 to Y2 + 1 Do
      For B := X2 to X2 + 1 Do Begin
        Ch := Console.ReadCharXY(B, A);
        Console.WriteXY (B + 1, A, ShadowAttr, Ch);
      End;

    A := Y2 + 1;
    For B := (X1 + 2) To (X2 + 2) Do Begin
      Ch := Console.ReadCharXY(B, A);
      Console.WriteXY (B, A, ShadowAttr, Ch);
    End;
  End;
End;

Procedure TMenuBox.Close;
Begin
  If WasOpened Then Console.PutScreenImage(Image);
End;

Procedure TMenuBox.Hide;
Begin
  If Assigned(HideImage) Then FreeMem(HideImage, SizeOf(TConsoleImageRec));

  GetMem (HideImage, SizeOf(TConsoleImageRec));

  Console.GetScreenImage (Image.X1, Image.Y1, Image.X2, Image.Y2, HideImage^);
  Console.PutScreenImage (Image);
End;

Procedure TMenuBox.Show;
Begin
  If Assigned (HideImage) Then Begin
    Console.PutScreenImage(HideImage^);
    FreeMem (HideImage, SizeOf(TConsoleImageRec));
    HideImage := NIL;
  End;
End;

Constructor TMenuList.Create (Var S: TOutput);
Begin
  Inherited Create;

  Screen     := S;
  Box        := TMenuBox.Create(S);
  InKey      := TInput.Create;
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

  Screen.BufFlush;
End;

Procedure TMenuList.Clear;
Var
  A : Word;
Begin
  For A := 1 to ListMax Do Dispose(List[A]);
  ListMax := 0;
  Marked  := 0;
End;

(*
Procedure TMenuList.Focus (Num: Word);
Var
  NewPicked  : Word;
  NewTopPage : Word;
  Count      : Word;
Begin
  If Num > ListMax Then Exit;

  Picked := 1;
  ListMax :=

  For Count := 1 to ListMax Do

  If Picked < ListMax Then Inc (Picked);
  If Picked > TopPage + Length - 1 Then Inc (TopPage);
End;
*)

Procedure TMenuList.Delete (RecPos : Word);
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

Destructor TMenuList.Destroy;
Begin
  Box.Free;
  InKey.Free;

  Clear;

  Inherited Destroy;
End;

Procedure TMenuList.Update;
Var
  A : LongInt;
  S : String;
  B : Integer;
  C : Integer;
Begin
  For A := 0 to Length - 1 Do Begin
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

    Screen.WriteXY (X1 + 1, Y1 + 1 + A, B, S);
    If PosBar Then
      Screen.WriteXY (X1 + Width + 1, Y1 + 1 + A, Box.BoxAttr2, '∞');

    If AllowTag Then
      If (C <= ListMax) and (List[C]^.Tagged = 1) Then
        Screen.WriteXY (TagPos, Y1 + 1 + A, TagAttr, TagChar)
      Else
        Screen.WriteXY (TagPos, Y1 + 1 + A, TagAttr, ' ');
  End;

  If PosBar Then
    If (ListMax > 0) and (Length > 0) Then Begin
      A := (Picked * Length) DIV ListMax;
      If Picked >= ListMax Then A := Pred(Length);
      If (A < 0) or (Picked = 1) Then A := 0;
      Screen.WriteXY (X1 + Width + 1, Y1 + 1 + A, Box.BoxAttr2, '≤');
    End;
End;

Procedure TMenuList.Open (BX1, BY1, BX2, BY2 : Byte);
Var
  Ch       : Char;
  A        : Word;
  sPos     : Word;
  ePos     : Word;
  First    : Boolean;
Begin
  If Not NoWindow Then
    Box.Open (BX1, BY1, BX2, BY2);

  X1 := BX1;
  Y1 := BY1;

  If (Picked < TopPage) or (Picked < 1) or (Picked > ListMax) or (TopPage < 1) or (TopPage > ListMax) Then Begin
    Picked  := 1;
    TopPage := 1;
  End;

  Width  := BX2 - X1 - 1;
  Length := BY2 - Y1 - 1;
  TagPos := X1 + 1;

  If NoInput Then Exit;

  Repeat
    Update;

    If Assigned(StatusProc) Then
      If ListMax > 0 Then
        StatusProc(Picked, List[Picked]^.Name)
      Else
        StatusProc(Picked, '');

    Ch := InKey.ReadKey;
    Case Ch of
      #00 : Begin
              Ch := InKey.ReadKey;
              Case Ch of
                #71 : Begin { home }
                        Picked  := 1;
                        TopPage := 1;
                      End;
                #72 : Begin { up arrow }
                        If Picked > 1 Then Dec (Picked);
                        If Picked < TopPage Then Dec (TopPage);
                      End;
                #73 : Begin { page up }
                        If Picked - Length > 1 Then Dec (Picked, Length) Else Picked := 1;
                        If TopPage - Length < 1 Then TopPage := 1 Else Dec(TopPage, Length);
                      End;
                #79 : Begin { end }
                        If ListMax > Length Then TopPage := ListMax - Length + 1;
                        Picked := ListMax;
                      End;
                #80 : Begin { down arrow }
                        If Picked < ListMax Then Inc (Picked);
                        If Picked > TopPage + Length - 1 Then Inc (TopPage);
                      End;
                #81 : If ListMax > 0 Then Begin { page down }
                        If ListMax > Length Then Begin
                          If Picked + Length > ListMax Then
                            Picked := ListMax
                          Else
                            Inc (Picked, Length);
                          Inc (TopPage, Length);
                          If TopPage + Length > ListMax Then TopPage := ListMax - Length + 1;
                        End Else Begin
                          Picked := ListMax;
                        End;
                      End;
              Else
                If Pos(Ch, HiChars) > 0 Then Begin
                  ExitCode := Ch;
                  Exit;
                End;
              End;
            End;
    Else
      If AllowTag and (Ch = TagKey) and (List[Picked]^.Tagged <> 2) Then Begin
        If (List[Picked]^.Tagged = 1) Then Begin
          Dec (List[Picked]^.Tagged);
          Dec (Marked);
        End Else Begin
          List[Picked]^.Tagged := 1;
          Inc (Marked);
        End;
        If Picked < ListMax Then Inc (Picked);
        If Picked > TopPage + Length - 1 Then Inc (TopPage);
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
                If Picked > TopPage + Length - 1 Then Inc (TopPage);
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
    End;
  Until False;
End;

Procedure TMenuList.Close;
Begin
  If Not NoWindow Then Box.Close;
End;

Procedure TMenuList.Add (Str : String; B : Byte);
Begin
  Inc (ListMax);
  New (List[ListMax]);
  List[ListMax]^.Name   := Str;
  List[ListMax]^.Tagged := B;

  If B = 1 Then Inc(Marked);
End;

Procedure TMenuList.Get (Num : Word; Var Str : String; Var B : Boolean);
Begin
  Str := '';
  B   := False;
  If Num <= ListMax Then Begin
    Str := List[Num]^.Name;
    B   := List[Num]^.Tagged = 1;
  End;
End;

Procedure TMenuList.SetStatusProc (P : TMenuListStatusProc);
Begin
  StatusProc := P;
End;

End.

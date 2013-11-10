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
Unit m_MenuBox;

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_Input,
  m_Output;

Const
  BoxFrameType : Array[1..8] of String[8] =
        ('ÚÄ¿³³ÀÄÙ',
         'ÉÍ»ººÈÍ¼',
         'ÖÄ·ººÓÄ½',
         'ÕÍ¸³³ÔÍ¾',
         'ÛßÛÛÛÛÜÛ',
         'ÛßÜÛÛßÜÛ',
         '        ',
         '.-.||`-''');

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
  TMenuListSearchProc = Procedure (Var Owner: Pointer; Str: String);

  TMenuListBoxRec = Record
    Name   : String;
    Tagged : Byte;                     { 0 = false, 1 = true, 2 = never }
  End;

  TMenuList = Class
    InKey      : TInput;
    List       : Array[1..10000] of ^TMenuListBoxRec;
    Box        : TMenuBox;
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
    WinSize    : Integer;
    X1         : Byte;
    Y1         : Byte;
    NoInput    : Boolean;
    LastBarPos : Byte;
    SearchProc : TMenuListSearchProc;
    SearchX    : Byte;
    SearchY    : Byte;
    SearchA    : Byte;

    Constructor Create (Var S: TOutput);
    Destructor  Destroy; Override;
    Procedure   Open (BX1, BY1, BX2, BY2: Byte);
    Procedure   Close;
    Procedure   Add (Str: String; B: Byte);
    Procedure   Get (Num: Word; Var Str: String; Var B: Boolean);
    Procedure   SetStatusProc (P: TMenuListStatusProc);
    Procedure   SetSearchProc (P: TMenuListSearchProc);
    Procedure   Clear;
    Procedure   Delete (RecPos : Word);
    Procedure   UpdatePercent;
    Procedure   UpdateBar (X, Y: Byte; RecPos: Word; IsHi: Boolean);
    Procedure   Update;
  End;

Implementation

Uses
  m_Strings;

Procedure DefListBoxSearch (Var Owner: Pointer; Str: String);
Begin
  If Str = '' Then
    Str := strRep(BoxFrameType[TMenuList(Owner).Box.FrameType][7], 17)
  Else Begin
    If Length(Str) > 15 Then
      Str := Copy(Str, Length(Str) - 15 + 1, 255);

    Str := '[' + strLower(Str) + ']';

    While Length(Str) < 17 Do
      Str := Str + BoxFrameType[TMenuList(Owner).Box.FrameType][7];
  End;

  TMenuList(Owner).Box.Console.WriteXY (
           TMenuList(Owner).SearchX,
           TMenuList(Owner).SearchY,
           TMenuList(Owner).SearchA,
           Str);
End;

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

  Console.WriteXY (X1, Y1, BoxAttr, BoxFrameType[FrameType][1] + strRep(BoxFrameType[FrameType][2], B));
  Console.WriteXY (X2, Y1, BoxAttr4, BoxFrameType[FrameType][3]);

  For A := Y1 + 1 To Y2 - 1 Do Begin
    Console.WriteXY (X1, A, BoxAttr, BoxFrameType[FrameType][4] + strRep(' ', B));
    Console.WriteXY (X2, A, BoxAttr2, BoxFrameType[FrameType][5]);
  End;

  Console.WriteXY (X1,   Y2, BoxAttr3, BoxFrameType[FrameType][6]);
  Console.WriteXY (X1+1, Y2, BoxAttr2, strRep(BoxFrameType[FrameType][7], B) + BoxFrameType[FrameType][8]);

  If Header <> '' Then
    Case HeadType of
      0 : Console.WriteXY (X1 + 1 + (B - Length(Header)) DIV 2, Y1, HeadAttr, Header);
      1 : Console.WriteXY (X1 + 1, Y1, HeadAttr, Header);
      2 : Console.WriteXY (X2 - Length(Header), Y1, HeadAttr, Header);
    End;

  If Shadow Then Begin
    For A := Y1 + 1 to Y2 + 1 Do
      For B := X2 + 1 to X2 + 2 Do Begin
        Ch := Console.ReadCharXY(B, A);
        Console.WriteXY (B, A, ShadowAttr, Ch);
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
  TagKey     := #09;
  TagPos     := 0;
  TagAttr    := 15 + 7 * 16;
  Marked     := 0;
  Picked     := 1;
  NoInput    := False;
  LastBarPos := 0;
  StatusProc := NIL;
  SearchProc := NIL;
  SearchProc := @DefListBoxSearch;
  SearchX    := 0;
  SearchY    := 0;
  SearchA    := 0;
  TopPage    := 1;
End;

Procedure TMenuList.Clear;
Var
  Count : Word;
Begin
  For Count := 1 to ListMax Do
    Dispose(List[Count]);

  ListMax := 0;
  Marked  := 0;
End;

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

Procedure TMenuList.UpdateBar (X, Y: Byte; RecPos: Word; IsHi: Boolean);
Var
  Str  : String;
  Attr : Byte;
Begin
  If IsHi Then
    Attr := HiAttr
  Else
    Attr := LoAttr;

  If RecPos <= ListMax Then Begin
    Str := ' ' + List[RecPos]^.Name + ' ';

    Case Format of
      0 : Str := strPadR(Str, Width, ' ');
      1 : Str := strPadL(Str, Width, ' ');
      2 : Str := strPadC(Str, Width, ' ');
    End;
  End Else
    Str := strRep(' ', Width);

  Box.Console.WriteXY (X, Y, Attr, Str);

  If AllowTag Then
    If (RecPos <= ListMax) and (List[RecPos]^.Tagged = 1) Then
      Box.Console.WriteXY (TagPos, Y, TagAttr, TagChar)
    Else
      Box.Console.WriteXY (TagPos, Y, TagAttr, ' ');
End;

Procedure TMenuList.UpdatePercent;
Var
  NewPos : LongInt;
Begin
  If Not PosBar Then Exit;

  If (ListMax > 0) and (WinSize > 0) Then Begin
    NewPos := (Picked * WinSize) DIV ListMax;

    If Picked >= ListMax Then NewPos := Pred(WinSize);

    If (NewPos < 0) or (Picked = 1) Then NewPos := 0;

    NewPos := Y1 + 1 + NewPos;

    If LastBarPos <> NewPos Then Begin
      If LastBarPos > 0 Then
        Box.Console.WriteXY (X1 + Width + 1, LastBarPos, Box.BoxAttr2, #176);

      LastBarPos := NewPos;

      Box.Console.WriteXY (X1 + Width + 1, NewPos, Box.BoxAttr2, #178);
    End;
  End;
End;

Procedure TMenuList.Update;
Var
  Loop   : LongInt;
  CurRec : Integer;
Begin
  For Loop := 0 to WinSize - 1 Do Begin
    CurRec := TopPage + Loop;

    UpdateBar (X1 + 1, Y1 + 1 + Loop, CurRec, CurRec = Picked);
  End;

  UpdatePercent;
End;

Procedure TMenuList.Open (BX1, BY1, BX2, BY2 : Byte);

  Procedure DownArrow;
  Begin
    If Picked < ListMax Then Begin
      If Picked >= TopPage + WinSize - 1 Then Begin
        Inc (TopPage);
        Inc (Picked);

        Update;
      End Else Begin
        UpdateBar (X1 + 1, Y1 + Picked - TopPage + 1, Picked, False);

        Inc (Picked);

        UpdateBar (X1 + 1, Y1 + Picked - TopPage + 1, Picked, True);

        UpdatePercent;
      End;
    End;
  End;

Var
  Ch          : Char;
  Count       : Word;
  StartPos    : Word;
  EndPos      : Word;
  First       : Boolean;
  SavedRec    : Word;
  SavedTop    : Word;
  SearchStr   : String;
  LastWasChar : Boolean;
Begin
  If Not NoWindow Then
    Box.Open (BX1, BY1, BX2, BY2);

  If SearchX = 0 Then SearchX := BX1 + 2;
  If SearchY = 0 Then SearchY := BY2;
  If SearchA = 0 Then SearchA := Box.BoxAttr4;

  X1 := BX1;
  Y1 := BY1;

  If (Picked < TopPage) or (Picked < 1) or (Picked > ListMax) or (TopPage < 1) or (TopPage > ListMax) Then Begin
    Picked  := 1;
    TopPage := 1;
  End;

  Width   := BX2 - X1 - 1;
  WinSize := BY2 - Y1 - 1;
  TagPos  := X1 + 1;

  While Picked > TopPage + WinSize - 1 Do
    Inc (TopPage);

  If PosBar Then
    For Count := 1 to WinSize Do
      Box.Console.WriteXY (X1 + Width + 1, Y1 + Count, Box.BoxAttr2, #176);

  If NoInput Then Exit;

  Update;

  LastWasChar := False;
  SearchStr   := '';

  Repeat
    If Not LastWasChar Then Begin
      If Assigned(SearchProc) And (SearchStr <> '') Then
        SearchProc (Self, '');

      SearchStr := ''
    End Else
      LastWasChar := False;

    If Assigned(StatusProc) Then
      If ListMax > 0 Then
        StatusProc(Picked, List[Picked]^.Name)
      Else
        StatusProc(Picked, '');

    Ch := InKey.ReadKey;

    Case Ch of
      #00 : Begin
              Ch := InKey.ReadKey;

              If Pos(Ch, HiChars) > 0 Then Begin
                If SearchStr <> '' Then Begin
                  SearchStr := '';
                  If Assigned(SearchProc) Then
                    SearchProc(Self, SearchStr);
                End;

                ExitCode := Ch;

                Exit;
              End;

              Case Ch of
                #71 : If Picked > 1 Then Begin { home }
                        Picked  := 1;
                        TopPage := 1;
                        Update;
                      End;
                #72 : If (Picked > 1) Then Begin
                        If Picked <= TopPage Then Begin
                          Dec (Picked);
                          Dec (TopPage);

                          Update;
                        End Else Begin
                          UpdateBar (X1 + 1, Y1 + Picked - TopPage + 1, Picked, False);

                          Dec (Picked);

                          UpdateBar (X1 + 1, Y1 + Picked - TopPage + 1, Picked, True);

                          UpdatePercent;
                        End;
                      End;
                #73,
                #75 : If (TopPage > 1) or (Picked > 1) Then Begin
                        If Picked - WinSize > 1 Then Dec (Picked, WinSize) Else Picked := 1;
                        If TopPage - WinSize < 1 Then TopPage := 1 Else Dec(TopPage, WinSize);
                        Update;
                      End;
                #79 : If Picked < ListMax Then Begin
                        If ListMax > WinSize Then TopPage := ListMax - WinSize + 1;
                        Picked := ListMax;
                        Update;
                      End;
                #80 : DownArrow;
                #77,
                #81 : If (Picked <> ListMax) Then Begin
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

        DownArrow;
      End Else
      If Pos(Ch, LoChars) > 0 Then Begin
        If SearchStr <> '' Then Begin
          SearchStr := '';
          If Assigned(SearchProc) Then
            SearchProc(Self, SearchStr);
        End;

        ExitCode := Ch;
        Exit;
      End Else Begin
        If Ch <> #01 Then Begin
          If Ch = #25 Then Begin
            LastWasChar := False;
            Continue;
          End;

          If Ch = #8 Then Begin
            If Length(SearchStr) > 0 Then
              Dec(SearchStr[0])
            Else
              Continue;
          End Else
            If Ord(Ch) < 32 Then
              Continue
            Else
              SearchStr := SearchStr + UpCase(Ch);
        End;

        SavedTop    := TopPage;
        SavedRec    := Picked;
        LastWasChar := True;
        First       := True;
        StartPos    := Picked + 1;
        EndPos      := ListMax;

        If Assigned(SearchProc) Then
          SearchProc(Self, SearchStr);

        If StartPos > ListMax Then StartPos := 1;

        Count := StartPos;

        While (Count <= EndPos) Do Begin
          If Pos(strUpper(SearchStr), strUpper(List[Count]^.Name)) > 0 Then Begin

            While Count <> Picked Do Begin
              If Picked < Count Then Begin
                If Picked < ListMax Then Inc (Picked);
                If Picked > TopPage + WinSize - 1 Then Inc (TopPage);
              End Else
              If Picked > Count Then Begin
                If Picked > 1 Then Dec (Picked);
                If Picked < TopPage Then Dec (TopPage);
              End;
            End;
            Break;
          End;

          If (Count = ListMax) and First Then Begin
            Count    := 0;
            StartPos := 1;
            EndPos   := Picked - 1;
            First    := False;
          End;

          Inc (Count);
        End;

        If TopPage <> SavedTop Then
          Update
        Else
        If Picked <> SavedRec Then Begin
          UpdateBar (X1 + 1, Y1 + SavedRec - SavedTop + 1, SavedRec, False);
          UpdateBar (X1 + 1, Y1 + Picked - TopPage + 1, Picked, True);
          UpdatePercent;
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

Procedure TMenuList.SetSearchProc (P: TMenuListSearchProc);
Begin
  SearchProc := P;
End;

Procedure TMenuList.SetStatusProc (P: TMenuListStatusProc);
Begin
  StatusProc := P;
End;

End.

Unit BBS_MenuData;

{$I M_OPS.PAS}

Interface

Uses
  m_Strings;

{$I RECORDS.PAS}

Type
  TMenuData = Class
    Menu     : Text;
    Info     : RecMenuInfo;
    Item     : Array[1..mysMaxMenuItems] of PtrMenuItem;
    NumItems : Byte;

    Constructor Create;
    Destructor  Destroy; Override;
    Function    CreateNewMenu (FN: String) : Boolean;
    Function    Load          (Append: Boolean; FN: String) : Boolean;
    Function    Save          (FN: String) : Boolean;
    Procedure   Unload;
    Procedure   InsertItem    (Num: Word);
    Procedure   DeleteItem    (Num: Word);
    Procedure   CopyItem      (Source, Dest: Word);
    Procedure   InsertCommand (Num, CmdNum: Word);
    Procedure   DeleteCommand (Num, CmdNum: Word);
  End;

Implementation

Constructor TMenuData.Create;
Begin
  Inherited Create;

  FillChar (Info, SizeOf(Info), 0);

  NumItems := 0;
End;

Destructor TMenuData.Destroy;
Begin
  Unload;

  Inherited Destroy;
End;

Procedure TMenuData.Unload;
Var
  Count1 : LongInt;
  Count2 : LongInt;
Begin
  For Count1 := NumItems DownTo 1 Do Begin
    For Count2 := Item[Count1]^.Commands DownTo 1 Do
      Dispose (Item[Count1]^.CmdData[Count2]);

    Dispose (Item[Count1]);
  End;

  NumItems := 0;
End;

Function TMenuData.Load (Append: Boolean; FN: String) : Boolean;
Var
  Count : LongInt;
  Junk  : RecMenuInfo;
  Buf   : Array[1..4096] of Byte;
  Str   : String;
  Flags : String;
Begin
  If Not Append Then Unload;

  Result := False;

  If FN = '' Then Exit;

  Assign     (Menu, FN);
  SetTextBuf (Menu, Buf);

  {$I-} Reset (Menu); {$I+}

  If IoResult <> 0 Then Exit;

  ReadLn (Menu, Junk.Description);
  ReadLn (Menu, Junk.Access);
  ReadLn (Menu, Junk.Fallback);
  ReadLn (Menu, Flags);
  ReadLn (Menu, Str);  // resv
  ReadLn (Menu, Junk.NodeStatus);
  ReadLn (Menu, Junk.Header);
  ReadLn (Menu, Junk.Footer);
  ReadLn (Menu, Junk.DispFile);
  ReadLn (Menu, Junk.DoneX);
  ReadLn (Menu, Junk.DoneY);
  ReadLn (Menu, Str);  // resv
  ReadLn (Menu, Str);  // resv
  ReadLn (Menu, Str);  // resv

  Junk.CharType  := strS2I(Flags[1]);
  Junk.MenuType  := strS2I(Flags[2]);
  Junk.InputType := strS2I(Flags[3]);
  Junk.DispCols  := strS2I(Flags[4]);
  Junk.Global    := Boolean(strS2I(Flags[5]));

  If Not Append Then Info := Junk;

  While Not Eof(Menu) And (NumItems <= mysMaxMenuItems) Do Begin
    Inc (NumItems);

    New (Item[NumItems]);

    ReadLn (Menu, Item[NumItems]^.Text);
    ReadLn (Menu, Item[NumItems]^.TextLo);
    ReadLn (Menu, Item[NumItems]^.TextHi);
    ReadLn (Menu, Item[NumItems]^.HotKey);
    ReadLn (Menu, Item[NumItems]^.Access);
    ReadLn (Menu, Flags);
    ReadLn (Menu, Item[NumItems]^.Timer);
    ReadLn (Menu, Item[NumItems]^.X);
    ReadLn (Menu, Item[NumItems]^.Y);
    ReadLn (Menu, Str);
    ReadLn (Menu, Str);
    ReadLn (Menu, Str);
    ReadLn (Menu, Item[NumItems]^.JumpUp);
    ReadLn (Menu, Item[NumItems]^.JumpDown);
    ReadLn (Menu, Item[NumItems]^.JumpLeft);
    ReadLn (Menu, Item[NumItems]^.JumpRight);
    ReadLn (Menu, Item[NumItems]^.JumpEscape);
    ReadLn (Menu, Item[NumItems]^.JumpTab);
    ReadLn (Menu, Item[NumItems]^.JumpPgUp);
    ReadLn (Menu, Item[NumItems]^.JumpPgDn);
    ReadLn (Menu, Item[NumItems]^.JumpHome);
    ReadLn (Menu, Item[NumItems]^.JumpEnd);
    ReadLn (Menu, Item[NumItems]^.Commands);

    Item[NumItems]^.TimerShow := True;
    Item[NumItems]^.ReDraw    := strS2I(Flags[1]);
    Item[NumItems]^.TimerType := strS2I(Flags[2]);
    Item[NumItems]^.ShowType  := strS2I(Flags[3]);

    For Count := 1 to Item[NumItems]^.Commands Do Begin
      New (Item[NumItems]^.CmdData[Count]);

      ReadLn (Menu, Item[NumItems]^.CmdData[Count]^.MenuCmd);
      ReadLn (Menu, Item[NumItems]^.CmdData[Count]^.Access);
      ReadLn (Menu, Item[NumItems]^.CmdData[Count]^.Data);
      ReadLn (Menu, Item[NumItems]^.CmdData[Count]^.JumpID);
      ReadLn (Menu, Str);
      ReadLn (Menu, Str);
    End;
  End;

  Close (Menu);

  Result := True;
End;

Function TMenuData.Save (FN: String) : Boolean;
Var
  Count  : LongInt;
  Count2 : LongInt;
  Flags  : String;
  Buf    : Array[1..4096] of Byte;
Begin
  Result := False;

  Assign     (Menu, FN);
  SetTextBuf (Menu, Buf);
  ReWrite    (Menu);

  Flags := strPadR(
    strI2S(Info.CharType)  +
    strI2S(Info.MenuType)  +
    strI2S(Info.InputType) +
    strI2S(Info.DispCols)  +
    strI2S(Ord(Info.Global))
  , 20, '0');

  WriteLn (Menu, Info.Description);
  WriteLn (Menu, Info.Access);
  WriteLn (Menu, Info.Fallback);
  WriteLn (Menu, Flags);
  WriteLn (Menu, '');  // resv
  WriteLn (Menu, Info.NodeStatus);
  WriteLn (Menu, Info.Header);
  WriteLn (Menu, Info.Footer);
  WriteLn (Menu, Info.DispFile);
  WriteLn (Menu, Info.DoneX);
  WriteLn (Menu, Info.DoneY);
  WriteLn (Menu, '');  // resv
  WriteLn (Menu, '');  // resv
  WriteLn (Menu, '');  // resv

  For Count := 1 to NumItems Do Begin
    Flags := strPadR(
      strI2S(Item[Count]^.ReDraw) +
      strI2S(Item[Count]^.TimerType) +
      strI2S(Item[Count]^.ShowType)
    , 20, '0');

    WriteLn (Menu, Item[Count]^.Text);
    WriteLn (Menu, Item[Count]^.TextLo);
    WriteLn (Menu, Item[Count]^.TextHi);
    WriteLn (Menu, Item[Count]^.HotKey);
    WriteLn (Menu, Item[Count]^.Access);
    WriteLn (Menu, Flags);
    WriteLn (Menu, Item[Count]^.Timer);
    WriteLn (Menu, Item[Count]^.X);
    WriteLn (Menu, Item[Count]^.Y);
    WriteLn (Menu, '');
    WriteLn (Menu, '');
    WriteLn (Menu, '');
    WriteLn (Menu, Item[Count]^.JumpUp);
    WriteLn (Menu, Item[Count]^.JumpDown);
    WriteLn (Menu, Item[Count]^.JumpLeft);
    WriteLn (Menu, Item[Count]^.JumpRight);
    WriteLn (Menu, Item[Count]^.JumpEscape);
    WriteLn (Menu, Item[Count]^.JumpTab);
    WriteLn (Menu, Item[Count]^.JumpPgUp);
    WriteLn (Menu, Item[Count]^.JumpPgDn);
    WriteLn (Menu, Item[Count]^.JumpHome);
    WriteLn (Menu, Item[Count]^.JumpEnd);
    WriteLn (Menu, Item[Count]^.Commands);

    For Count2 := 1 to Item[Count]^.Commands Do Begin
      WriteLn (Menu, Item[Count]^.CmdData[Count2]^.MenuCmd);
      WriteLn (Menu, Item[Count]^.CmdData[Count2]^.Access);
      WriteLn (Menu, Item[Count]^.CmdData[Count2]^.Data);
      WriteLn (Menu, Item[Count]^.CmdData[Count2]^.JumpID);
      WriteLn (Menu, '');
      WriteLn (Menu, '');
    End;
  End;

  Close (Menu);

  Result := True;
End;

Procedure TMenuData.DeleteItem (Num: Word);
Var
  Count : Word;
Begin
  If NumItems = 0 Then Exit;

  For Count := 1 to Item[Num]^.Commands Do
    Dispose (Item[Num]^.CmdData[Count]);

  Dispose (Item[Num]);

  For Count := Num To NumItems - 1 Do
    Item[Count] := Item[Count + 1];

  Dec(NumItems);
End;

Procedure TMenuData.DeleteCommand (Num, CmdNum: Word);
Var
  Count : Word;
Begin
  If Item[Num]^.Commands = 0 Then Exit;

  Dispose (Item[Num]^.CmdData[CmdNum]);

  For Count := CmdNum To Item[Num]^.Commands - 1 Do
    Item[Num]^.CmdData[Count] := Item[Num]^.CmdData[Count + 1];

  Dec (Item[Num]^.Commands);
End;

Procedure TMenuData.InsertCommand (Num, CmdNum: Word);
Var
  Count : Word;
Begin
  If Item[Num]^.Commands = mysMaxMenuCmds Then Exit;

  Inc (Item[Num]^.Commands);

  For Count := Item[Num]^.Commands DownTo CmdNum + 1 Do
    Item[Num]^.CmdData[Count] := Item[Num]^.CmdData[Count - 1];

  New (Item[Num]^.CmdData[CmdNum]);

  With Item[Num]^.CmdData[CmdNum]^ Do Begin
    MenuCmd := 'GO';
    Access  := '';
    Data    := 'main';
    JumpID  := 0;
  End;
End;

Procedure TMenuData.InsertItem (Num: Word);
Var
  Count : Word;
Begin
  If NumItems = mysMaxMenuItems Then Exit;

  Inc (NumItems);

  For Count := NumItems DownTo Num + 1 Do
    Item[Count] := Item[Count - 1];

  New (Item[Num]);

  FillChar (Item[Num]^, SizeOf(Item[Num]^), #0);

  With Item[Num]^ Do Begin
    Text       := '|09(|10Q|09) |03Quit to Main Menu';
    TextLo     := '|07Quit to Main Menu';
    TextHi     := '|15Quit to Main Menu';
    HotKey     := 'Q';
    Redraw     := 1;
  End;

  InsertCommand(Num, 1);
End;

Function TMenuData.CreateNewMenu (FN: String) : Boolean;
Begin
  Info.Description := 'New Mystic BBS menu';
  Info.Header      := '|CR|14New Menu Header|CR';
  Info.Footer      := '|CR|09Selection|03: |11';
  Info.DispCols    := 3;

  InsertItem(1);

  Result := Save(FN);
End;

Procedure TMenuData.CopyItem (Source, Dest: Word);
Var
  Count : Word;
Begin
  If NumItems = mysMaxMenuItems Then Exit;

  Inc (NumItems);

  For Count := NumItems DownTo Dest + 1 Do
    Item[Count] := Item[Count - 1];

  New (Item[Dest]);

  Item[Dest]^ := Item[Source]^;

  For Count := 1 to Item[Source]^.Commands Do Begin
    New (Item[Dest]^.CmdData[Count]);

    Item[Dest]^.CmdData[Count]^ := Item[Source]^.CmdData[Count]^;
  End;
End;

End.

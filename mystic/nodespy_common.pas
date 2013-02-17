Unit NodeSpy_Common;

{$I M_OPS.PAS}

Interface

Uses
  Math,
  m_Input,
  m_Output,
  m_Output_ScrollBack,
  m_Term_Ansi,
  m_MenuBox,
  m_MenuForm,
  m_MenuInput;

Function ShowMsgBox       (BoxType: Byte; Str: String) : Boolean;
Function GetStr           (Header, Text, Def: String; Len, MaxLen: Byte) : String;
Function GetCommandOption (StartY: Byte; CmdStr: String) : Char;

{$I RECORDS.PAS}

Var
  Screen     : TConsoleScrollback;
  Keyboard   : TInput;
  Term       : TTermAnsi;
  ConfigFile : File of RecConfig;
  Config     : RecConfig;
  XferPath   : String;
  AutoZmodem : Boolean;

Implementation

Function ShowMsgBox (BoxType: Byte; Str: String) : Boolean;
Var
  Len    : Byte;
  Len2   : Byte;
  Pos    : Byte;
  MsgBox : TMenuBox;
  Offset : Byte;
  SavedX : Byte;
  SavedY : Byte;
  SavedA : Byte;
Begin
  ShowMsgBox := True;
  SavedX     := Screen.CursorX;
  SavedY     := Screen.CursorY;
  SavedA     := Screen.TextAttr;

  MsgBox := TMenuBox.Create(TOutput(Screen));

  Len := (80 - (Length(Str) + 2)) DIV 2;
  Pos := 1;

  MsgBox.FrameType := 6;
  MsgBox.Header    := ' Info ';
  MsgBox.HeadAttr  := 1 + 7 * 16;

  MsgBox.Box3D := True;

  If Screen.ScreenSize = 50 Then Offset := 12 Else Offset := 0;

  If BoxType < 2 Then
    MsgBox.Open (Len, 10 + Offset, Len + Length(Str) + 3, 15 + Offset)
  Else
    MsgBox.Open (Len, 10 + Offset, Len + Length(Str) + 3, 14 + Offset);

  Screen.WriteXY (Len + 2, 12 + Offset, 112, Str);

  Case BoxType of
    0 : Begin
          Len2 := (Length(Str) - 4) DIV 2;

          Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 30, ' OK ');

          Repeat
            Keyboard.ReadKey;
          Until Not Keyboard.KeyPressed;
        End;
    1 : Repeat
          Len2 := (Length(Str) - 9) DIV 2;

          Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 113, ' YES ');
          Screen.WriteXY (Len + Len2 + 7, 14 + Offset, 113, ' NO ');

          If Pos = 1 Then
            Screen.WriteXY (Len + Len2 + 2, 14 + Offset, 30, ' YES ')
          Else
            Screen.WriteXY (Len + Len2 + 7, 14 + Offset, 30, ' NO ');

          Case UpCase(Keyboard.ReadKey) of
            #00 : Case Keyboard.ReadKey of
                    #75 : Pos := 1;
                    #77 : Pos := 0;
                  End;
            #13 : Begin
                    ShowMsgBox := Boolean(Pos);
                    Break;
                  End;
            #32 : If Pos = 0 Then Inc(Pos) Else Pos := 0;
            'N' : Begin
                    ShowMsgBox := False;
                    Break;
                  End;
            'Y' : Begin
                    ShowMsgBox := True;
                    Break;
                  End;
          End;
        Until False;
  End;

  If BoxType <> 2 Then MsgBox.Close;

  MsgBox.Free;

  Screen.CursorXY (SavedX, SavedY);

  Screen.TextAttr := SavedA;
End;

Function GetStr (Header, Text, Def: String; Len, MaxLen: Byte) : String;
Var
  Box     : TMenuBox;
  Input   : TMenuInput;
  Offset  : Byte;
  Str     : String;
  WinSize : Byte;
Begin
  WinSize := (80 - Max(Len, Length(Text)) + 2) DIV 2;

  Box   := TMenuBox.Create(TOutput(Screen));
  Input := TMenuInput.Create(TOutput(Screen));

  Box.FrameType := 6;
  Box.Header    := ' ' + Header + ' ';
  Box.HeadAttr  := 1 + 7 * 16;
  Box.Box3D     := True;

  Input.Attr     := 15 + 4 * 16;
  Input.FillAttr :=  7 + 4 * 16;
  Input.LoChars  := #13#27;

  If Screen.ScreenSize = 50 Then Offset := 12 Else Offset := 0;

  Box.Open (WinSize, 10 + Offset, WinSize + Max(Len, Length(Text)) + 2, 15 + Offset);

  Screen.WriteXY (WinSize + 2, 12 + Offset, 112, Text);
  Str := Input.GetStr(WinSize + 2, 13 + Offset, Len, MaxLen, 1, Def);

  Box.Close;

  If Input.ExitCode = #27 Then Str := '';

  Input.Free;
  Box.Free;

  Result := Str;
End;

Function GetCommandOption (StartY: Byte; CmdStr: String) : Char;
Var
  Box     : TMenuBox;
  Form    : TMenuForm;
  Count   : Byte;
  Cmds    : Byte;
  CmdData : Array[1..10] of Record
              Key  : Char;
              Desc : String[18];
            End;
Begin
  Cmds := 0;

  While Pos('|', CmdStr) > 0 Do Begin
    Inc (Cmds);

    CmdData[Cmds].Key  := CmdStr[1];
    CmdData[Cmds].Desc := Copy(CmdStr, 3, Pos('|', CmdStr) - 3);

    Delete (CmdStr, 1, Pos('|', Cmdstr));
  End;

  Box  := TMenuBox.Create(TOutput(Screen));
  Form := TMenuForm.Create(TOutput(Screen));

  Form.HelpSize := 0;

  Box.Open (30, StartY, 51, StartY + Cmds + 1);

  For Count := 1 to Cmds Do
    Form.AddNone (CmdData[Count].Key, ' ' + CmdData[Count].Key + ' ' + CmdData[Count].Desc, 31, StartY + Count, 20, '');

  Result := Form.Execute;

  Form.Free;
  Box.Close;
  Box.Free;
End;

End.

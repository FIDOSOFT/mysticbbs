Program Test7;

{$I M_OPS.PAS}

Uses
  m_Types,
  m_Strings,
  m_Output,
  m_Input,
  m_MenuBox;

Var
  Screen : TOutput;
  Input  : TInput;

Procedure UpdateBottom (Num: Word; Str: String);
Var
  Image : TConsoleImageRec;
  Count : Byte;
Begin
  Screen.GetScreenImage(1, 1, 80, 25, Image);

  For Count := 1 to 24 Do
    Screen.WriteLineRec(26 + Count, Image.Data[Count]);
End;

Var
  Box    : TMenuBox;
  List   : TMenuList;
  Count  : Byte;
  Image  : TConsoleImageRec;
Begin
  Screen := TOutput.Create(True);
  Input  := TInput.Create;

  Screen.SetScreenSize(50);
  Screen.ClearScreen;

  For Count := 1 to 24 Do
    Screen.WriteXY(1, Count, 8, strRep('°', 80));

  For Count := 1 to 24 Do
    If Odd(Count) Then
        Screen.WriteXY(5, Count, 8, '123456789012345678901234567890123456789012345678901234567890123456789012345')
    Else
        Screen.WriteXY(5, Count, 9, '098765432109876543210987654321098765432109876543210987654321098765432109876');


  For Count := 1 to 25 Do
    Screen.WriteXY(1, Count, 7, strI2S(Count));

  UpdateBottom(1, '');

  Input.ReadKey;

  Screen.WriteXY(3, 5, 7, 'This is a test of some random text');
  Screen.WriteXYPipe(3,6, 7, 80, '|12And this is also random text');
  Screen.CursorXY (50, 15);
  Screen.WriteStr('And some more text here too!');

  UpdateBottom(1, '');

  Input.ReadKey;

  Box := TMenuBox.Create(Screen);

  Box.Open(3, 6, 75, 23);

  UpdateBottom(1, '');

  Input.ReadKey;

  Screen.GetScreenImage(1, 1, 80, 25, Image);

  Screen.ClearScreen;
  Screen.WriteLine('Press a key to restore screen.');
  Input.ReadKey;
  Screen.PutScreenImage(Image);

  UpdateBottom(1, '');

  Input.ReadKey;

 // Screen.WriteXY(20, 18, 15, '12345678901234567890123456789012345678901234567890');
  Box.Close;
  Box.Free;

  UpdateBottom(1, '');

  Input.ReadKey;

  Repeat
    List := TMenuList.Create(Screen);

    List.Add('Option 1', 0);
    List.Add('Option 2', 0);
    List.Add('Exit', 0);

    List.SetStatusProc(@UpdateBottom);

    List.Open(20, 8, 70, 17);
    List.Close;
    List.Free;
  Until List.Picked = 3;

  UpdateBottom(1, '');

  Input.ReadKey;

  Screen.ClearScreen;

  Screen.WriteLine('Press a key to end');

  UpdateBottom(1, '');

  Input.ReadKey;

  Input.Free;
  Screen.Free;
End.

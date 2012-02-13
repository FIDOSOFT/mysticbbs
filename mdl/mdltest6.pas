Program Test6;

{$I M_OPS.PAS}

Uses
  m_Input,
  m_Output;

Var
  Keyboard  : TInput;
  Screen    : TOutput;
  TempChar  : Char;
Begin
  Keyboard := TInput.Create;
  Screen   := TOutput.Create(True);

  Screen.WriteLine('MDL: Input/Output test program. (ESCAPE) to Quit');
  Screen.SetWindow(1, 3, 80, 25, True);

  Repeat
    If Keyboard.KeyPressed Then Begin
      TempChar := Keyboard.ReadKey;

      If TempChar = #27 Then
        Break
      Else
        Screen.WriteLine('Key pressed: ' + TempChar);
    End;
  Until False;

  Keyboard.Free;
  Screen.Free;
End.

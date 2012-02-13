Program TestIO_1;

{$I M_OPS.PAS}

Uses
  m_Input,
  m_Output,
  m_Strings;

Var
  Keyboard  : TInput;
  Screen    : TOutput;
  TempChar  : Char;
  IdleCount : LongInt;
Begin
  Keyboard := TInput.Create;
  Screen   := TOutput.Create(True);

  Screen.SetWindowTitle('MDL: TEST #1');
  Screen.WriteLine('MDL: Input/Output test program. (ESCAPE) to Quit');
  Screen.SetWindow(1, 3, 80, 25, True);

  IdleCount := 0;

  Repeat
    If Keyboard.KeyWait(1000) Then Begin
      IdleCount := 0;
      TempChar  := Keyboard.ReadKey;
      Case TempChar of
        #0  : Screen.WriteLine('Extended key: ' + strI2S(Ord(Keyboard.ReadKey)));
        #27 : Begin
                Screen.WriteLine('Escape pressed!');
                Break;
              End;
      Else
        Screen.WriteLine('Key pressed: ' + TempChar);
      End;
    End Else Begin
      Inc (IdleCount);
      Screen.WriteLine('No key has been pressed (for ' + strI2S(IdleCount) + ' seconds)');
    End;
  Until False;

  Keyboard.Free;
  Screen.Free;
End.

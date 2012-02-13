Program Test8;

Uses
  m_Output,
  m_DateTime,
  m_Strings;

Procedure WriteLine(S:String);
Var
  A:Byte;
Begin
  for a := 1 to length(s) do write(s[a]);
End;


Var
  StartTime,
  EndTime   : LongInt;
  Count     : LongInt;
  Screen    : TOutput;
Begin
  Screen := TOutput.Create(True);

  StartTime := TimerSeconds;

  For Count := 1 to 5000 Do
    Screen.WriteStr('This is a test of the emergency broadcast system and I hope it is fast' + #13#10);

  EndTime := TimerSeconds;

  screen.WriteLine('Time was: ' + strI2S(EndTime - StartTime));
End.

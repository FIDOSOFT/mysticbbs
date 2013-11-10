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

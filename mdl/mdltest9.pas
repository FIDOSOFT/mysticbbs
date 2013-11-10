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
Program MDLTEST9;

Uses
  m_SDLCRT;

Var
  Console : TSDLConsole;
  Ch      : Char;
Begin
  Console := TSDLConsole.Create(Mode_80x25);

  Console.SetTitle('SDL TEST Program [ESC/Quit]');

  Console.TestStuff;

  Repeat
    Ch := Console.ReadKey;

    Case Ch of
      #00 : Case Console.ReadKey of
              keyUP     : WriteLn('Got Up arrow');
              keyDOWN   : WriteLn('Got down arrow');
              keyLEFT   : WriteLn('Got left arrow');
              keyRIGHT  : WriteLn('Got right arrow');
              keyHOME   : WriteLn('Got HOME');
              keyEND    : WriteLn('Got END');
              keyPGUP   : WriteLn('Got PAGE UP');
              keyPGDN   : WriteLn('Got PAGE Down');
              keyINSERT : WriteLn('Got INSERT');
              keyDELETE : WriteLn('Got DELETE');
            End;
      #27 : Begin
              WriteLn('Got escape.  Shutting down');
              Break;
            End;
      Else
        WriteLn('Got: ' + Ch);
    End;
  Until False;

  Console.Free;
End.

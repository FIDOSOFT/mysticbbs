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
Program Test4;

Uses
  m_io_Sockets;

Var
  Client : TIOSocket;
  Str    : String;
Begin
  Client := TIOSocket.Create;

  WriteLn ('Attempting to connect to localhost port 23 for TEST3 server test');

  Client.ConnectInit('localhost', 23);
  Client.SetBlocking(False);

  Repeat
  Until Client.Connect;

//  If Not Client.Connect ('localhost', 23) Then Begin
//    WriteLn ('Connection failed');
//    Client.Free;
//    Halt;
//  End;

  Client.ReadLine(Str);

  WriteLn('Received: ', Str);
  Client.WriteLine ('Client connection successful!');

  Client.Free;
End.

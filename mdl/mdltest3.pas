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
Program Test3;

{$I m_ops.pas}

Uses
  m_io_Sockets;

Var
  Server : TIOSocket;
  Client : TIOSocket;
  Str    : String;
Begin
  Server := TIOSocket.Create;

  Server.WaitInit('0.0.0.0', 23);

  WriteLn('Waiting on port 23 for TEST4 client example...');

  Client := Server.WaitConnection(5000);

  If Client = NIL Then Begin
    WriteLn ('An error has occured; no client detected');
    Server.Free;
    Halt;
  End;

  WriteLn;
  WriteLn ('Got connection from:');
  WriteLn ('  Host: ', Client.FPeerName);
  WriteLn ('    IP: ', Client.FPeerIP);
  WriteLn;

  Client.WriteLine('Welcome to the MDL test server!');
  Client.ReadLine(Str);

  WriteLn('Received: ', Str);

  Server.Free;
  Client.Free;
End.

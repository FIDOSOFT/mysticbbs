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

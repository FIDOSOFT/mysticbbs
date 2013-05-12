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

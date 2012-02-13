Program Test4;

Uses
  m_Socket_Class;

Var
  Client : TSocketClass;
  Str    : String;
Begin
  Client := TSocketClass.Create;

  WriteLn ('Attempting to connect to localhost port 23 for TEST3 server test');

  If Not Client.Connect ('localhost', 23) Then Begin
    WriteLn ('Connection failed');
    Client.Free;
    Halt;
  End;

  Client.ReadLine(Str);

  WriteLn('Received: ', Str);
  Client.WriteLine ('Client connection successful!');

  Client.Free;
End.

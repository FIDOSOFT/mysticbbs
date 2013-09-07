Unit m_TCP_Client;

{$I M_OPS.PAS}

Interface

Uses
  Classes,
  m_Strings,
  m_IO_Sockets;

Type
  TTCPClient = Class
    Client       : TIOSocket;
    ResponseType : Integer;
    ResponseStr  : String;
    ResponseData : TStringList;
    NetInterface : String;

    Constructor Create (NetI: String); Virtual;
    Destructor  Destroy; Override;
    Function    Connect (Address: String; Port: Word) : Boolean; Virtual;
    Function    SendCommand (Str: String) : Integer;
    Function    GetResponse : Integer;
  End;

Implementation

Constructor TTCPClient.Create (NetI: String);
Begin
  Inherited Create;

  Client       := NIL;
  NetInterface := NetI;
  ResponseData := TStringList.Create;
End;

Destructor TTCPClient.Destroy;
Begin
  Client.Free;
  ResponseData.Free;

  Inherited Destroy;
End;

Function TTCPClient.Connect (Address: String; Port: Word) : Boolean;
Begin
  Client := TIOSocket.Create;

  Result := Client.Connect(Address, Port);
End;

Function TTCPClient.SendCommand (Str: String) : Integer;
Begin
  Result := -1;

  If Client.FSocketHandle = -1 Then Exit;

WriteLn ('DEBUG SEND ' + Str);

  Client.PurgeInputData(1);

  Client.WriteLine(Str);

  Result := GetResponse;
End;

Function TTCPClient.GetResponse : Integer;
Var
  Str : String;
  Res : LongInt;
Begin
  Result := -1;

  If Client.FSocketHandle = -1 Then Exit;

  If Client.WaitForData(10000) > 0 Then
    If Client.ReadLine(ResponseStr) > 0 Then Begin
      ResponseType := strS2I(Copy(ResponseStr, 1, 3));
      Result       := ResponseType;

      If ResponseStr[4] = '-' Then Begin
        ResponseData.Clear;

        Repeat
          Res := Client.ReadLine(Str);

          If Res < 0 Then
            Break;

          If Res > 0 Then
            ResponseData.Add(Str);
        Until Copy(Str, 1, 4) = strI2S(ResponseType) + ' ';
      End;
    End;

  writeln('DEBUG RECV ' + ResponseStr);
End;

End.

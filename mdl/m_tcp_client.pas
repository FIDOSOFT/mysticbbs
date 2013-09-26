Unit m_TCP_Client;

{$I M_OPS.PAS}

Interface

{$DEFINE USESTRINGLIST}

Uses
  {$IFDEF USESTRINGLIST}
    Classes,
  {$ENDIF}
  m_Strings,
  m_IO_Sockets;

Type
  TTCPClient = Class
    Client       : TIOSocket;
    ResponseType : Integer;
    ResponseStr  : String;
    {$IFDEF USESTRINGLIST}
      ResponseData : TStringList;
    {$ENDIF}
    NetInterface : String;

    Constructor Create      (NetI: String); Virtual;
    Destructor  Destroy;    Override;
    Function    Connect     (Address: String; Port: Word) : Boolean; Virtual;
    Function    SendCommand (Str: String) : Integer;
    Function    GetResponse : Integer;
  End;

Implementation

Constructor TTCPClient.Create (NetI: String);
Begin
  Inherited Create;

  Client       := NIL;
  NetInterface := NetI;

  {$IFDEF USESTRINGLIST}
    ResponseData := TStringList.Create;
  {$ENDIF}
End;

Destructor TTCPClient.Destroy;
Begin
  Client.Free;

  {$IFDEF USESTRINGLIST}
    ResponseData.Free;
  {$ENDIF}

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

  WriteLn ('DEBUG SENT ' + Str);

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

//  writeln ('debug in getresponse');

  If Client.WaitForData(10000) > 0 Then
    If Client.ReadLine(ResponseStr) > 0 Then Begin
      ResponseType := strS2I(Copy(ResponseStr, 1, 3));
      Result       := ResponseType;

       WriteLn ('DEBUG RECV ' + ResponseStr);

//       writeln('debug restype=', responsetype);

      If ResponseStr[4] = '-' Then Begin
//        WriteLn ('DEBUG RECV EXT RES');
        {$IFDEF USESTRINGLIST}
          ResponseData.Clear;
        {$ENDIF}

        Repeat
          Res := Client.ReadLine(Str);

//          writeln ('debug got extended res:', res);

          If Res < 0 Then
            Break;

          {$IFDEF USESTRINGLIST}
            If Res > 0 Then
              ResponseData.Add(Str);
          {$ENDIF}
        Until Copy(Str, 1, 4) = strI2S(ResponseType) + ' ';
      End;
    End;

//  writeln ('debug getres done');
End;

End.

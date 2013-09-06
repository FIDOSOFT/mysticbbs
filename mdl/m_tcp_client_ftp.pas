Unit m_Tcp_Client_FTP;

{$I M_OPS.PAS}

Interface

Uses
  SysUtils,   // wordrec get rid of it
  m_io_Sockets,
  m_Tcp_Client;

Type
  TFTPClient = Class(TTCPClient)
    DataPort     : Word;
    DataIP       : String;
    DataSocket   : TIOSocket;
    IsPassive    : Boolean;
    NetInterface : String;

    Constructor Create; Override;

    Function  OpenDataSession : Boolean;
    Procedure CloseDataSession;
    Function  SetPassive      (IsOn: Boolean) : Boolean;

    Function  OpenConnection  (HostName: String) : Boolean;
    Function  Authenticate    (Login, Password: String) : Boolean;
    Function  ChangeDirectory (Str: String) : Boolean;
    Function  SendFile        (Passive: Boolean; FileName: String) : Boolean;
    Function  GetFile         (Passive: Boolean; FileName: String) : Boolean;
    Procedure CloseConnection;
  End;

Implementation

Uses
  m_FileIO,
  m_Strings;

Constructor TFTPClient.Create;
Begin
  Inherited Create;

  IsPassive    := False;
  NetInterface := '';
  DataIP       := '';
  DataPort     := 10000;
End;

Function TFTPClient.OpenDataSession : Boolean;
Var
  WaitSock : TIOSocket;
Begin
  Result := False;

  If DataSocket <> NIL Then Begin
    DataSocket.Free;
    DataSocket := NIL;
  End;

  If IsPassive Then Begin
    DataSocket := TIOSocket.Create;

    If Not DataSocket.Connect(DataIP, DataPort) Then Begin
      DataSocket.Free;
      DataSocket := NIL;

      Exit;
    End;
  End Else Begin
    WaitSock := TIOSocket.Create;

    WaitSock.FTelnetServer := False;
    WaitSock.FTelnetClient := False;

    WaitSock.WaitInit(NetInterface, DataPort);

    DataSocket := NIL;
    DataSocket := WaitSock.WaitConnection(10000);

    If Not Assigned(DataSocket) Then Begin
      WaitSock.Free;

      Exit;
    End;

    WaitSock.Free;
  End;

  Result := True;
End;

Procedure TFTPClient.CloseDataSession;
Begin
  If DataSocket <> NIL Then Begin
    DataSocket.Free;

    DataSocket := NIL;
  End;
End;

Function TFTPClient.OpenConnection (HostName: String) : Boolean;
Var
  Port : Word;
Begin
  Result := False;

  Port := strS2I(strWordGet(2, HostName, ':'));

  If Port = 0 Then Port := 21;

  Result := Connect(strWordGet(1, HostName, ':'), Port);

  If Result Then GetResponse; // eat banner/info tag
End;

Function TFTPClient.Authenticate (Login, Password: String) : Boolean;
Begin
  Result := False;

  If SendCommand('USER ' + Login) <> 331 Then Exit;
  If SendCommand('PASS ' + Password) <> 230 Then Exit;

  Result := True;
End;

Function TFTPClient.SetPassive (IsOn: Boolean) : Boolean;
Var
  Str   : String;
  Count : Byte;
Begin
  If IsOn Then Begin
    Result := SendCommand('PASV') = 227;

    If Result Then Begin
      Str := (strWordGet(1, strWordGet(2, ResponseStr, '('), ')'));

      For Count := 1 to 3 Do
        Str[Pos(',', Str)] := '.';

      DataIP := Copy(Str, 1, Pos(',', Str) - 1);

      Delete (Str, 1, Pos(',', Str));

      WordRec(DataPort).Hi := strS2I(Copy(Str, 1, Pos(',', Str) - 1));
      WordRec(DataPort).Lo := strS2I(Copy(Str, Pos(',', Str) + 1, Length(Str)));

      IsPassive := True;
    End;
  End Else Begin
    IsPassive := False;
    DataPort  := 10000;  // Calc and make configurable?
    Result    := SendCommand('PORT ' + strReplace(Client.PeerIP, '.', ',') + ',' + strI2S(WordRec(DataPort).Hi) + ',' + strI2S(WordRec(DataPort).Lo)) = 200;
  End;
End;

Function TFTPClient.SendFile (Passive: Boolean; FileName: String) : Boolean;
Var
  F      : File;
  Buffer : Array[1..8*1024] of Char;
  Res    : LongInt;
Begin
  Result := False;

  If Not FileExist(FileName) Then Exit;

  SetPassive(Passive);

  Client.WriteLine ('STOR ' + JustFile(FileName));

  OpenDataSession;

  If GetResponse = 150 Then Begin
    Assign (F, FileName);

    If ioReset(F, 1, fmRWDN) Then Begin
      Repeat
        BlockRead (F, Buffer, SizeOf(Buffer), Res);

        If Res > 0 Then
          DataSocket.WriteBuf(Buffer, Res)
        Else
          Break;
      Until False;

      Close (F);
    End;

    CloseDataSession;

    Result := GetResponse = 226;
  End Else
    CloseDataSession;
End;

Function TFTPClient.GetFile (Passive: Boolean; FileName: String) : Boolean;
Var
  F      : File;
  Res    : LongInt;
  Buffer : Array[1..8*1024] of Char;
Begin
  Result := False;

  If FileExist(FileName) Then Exit;

  SetPassive(Passive);

  Client.WriteLine('RETR ' + JustFile(FileName));

  OpenDataSession;

  If GetResponse = 150 Then Begin
    Assign (F, FileName);

    If ioReWrite(F, 1, fmRWDW) Then Begin
      Repeat
        Res := DataSocket.ReadBuf (Buffer, SizeOf(Buffer));

        If Res > 0 Then
          BlockWrite (F, Buffer, Res)
        Else
          Break;
      Until False;

      Close (F);
    End;

    CloseDataSession;

    Result := GetResponse = 226;
  End Else
    CloseDataSession;
End;

Function TFTPClient.ChangeDirectory (Str: String) : Boolean;
Begin
  Result := SendCommand('CWD ' + Str) = 250;
End;

Procedure TFTPClient.CloseConnection;
Begin
  If Client.Connected Then
    Client.WriteLine('QUIT');
End;

End.

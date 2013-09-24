Unit m_Tcp_Client_FTP;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Sockets,
  m_Tcp_Client;

Const
  ftpResOK      = 0;
  ftpResFailed  = 1;
  ftpResBadData = 2;
  ftpResNoFile  = 3;

Type
  WordRec = Record
    Lo : Byte;
    Hi : Byte;
  End;

  TFTPClient = Class(TTCPClient)
    DataPort   : Word;
    DataIP     : String;
    DataSocket : TIOSocket;
    IsPassive  : Boolean;
    MinPort    : Word;
    MaxPort    : Word;

    Constructor Create            (NetI: String); Override;
    Function    OpenDataSession   : Boolean;
    Procedure   CloseDataSession;
    Function    SetPassive        (IsOn: Boolean) : Boolean;
    Function    OpenConnection    (HostName: String) : Boolean;
    Function    Authenticate      (Login, Password: String) : Boolean;
    Function    ChangeDirectory   (Str: String) : Boolean;
    Function    GetDirectoryList  (Passive, Change: Boolean; Str: String) : Boolean;
    Function    SendFile          (Passive: Boolean; LocalFile, RemoteFile: String) : Byte;
    Function    GetFile           (Passive: Boolean; FileName: String) : Byte;
    Procedure   CloseConnection;
  End;

Implementation

Uses
  m_FileIO,
  m_Strings;

Constructor TFTPClient.Create (NetI: String);
Begin
  Inherited Create(NetI);

  IsPassive := False;
  DataIP    := '';
  MinPort   := 49152;
  MaxPort   := 65535;
  DataPort  := Random(MaxPort - MinPort) + MinPort;
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

    DataSocket := WaitSock.WaitConnection(10000);

    WaitSock.Free;

    If Not Assigned(DataSocket) Then
      Exit;
  End;

  Result := True;
End;

Procedure TFTPClient.CloseDataSession;
Begin
  If DataSocket <> NIL Then Begin
    //DataSocket.Disconnect;
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

  // tossing in BIN mode here for lack of a better place

  If SendCommand('TYPE I') = 200 Then;

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
    DataPort  := Random(MaxPort - MinPort) + MinPort;
    Result    := SendCommand('PORT ' + strReplace(Client.PeerIP, '.', ',') + ',' + strI2S(WordRec(DataPort).Hi) + ',' + strI2S(WordRec(DataPort).Lo)) = 200;
  End;
End;

Function TFTPClient.SendFile (Passive: Boolean; LocalFile, RemoteFile: String) : Byte;
Var
  F      : File;
  Buffer : Array[1..8 * 1024] of Char;
  Res    : LongInt;
  OK     : Boolean;
Begin
  Result := ftpResFailed;

  If Not FileExist(LocalFile) Then Exit;

  SetPassive(Passive);

  Client.WriteLine ('STOR ' + JustFile(RemoteFile));

  OK  := OpenDataSession;
  Res := GetResponse;

  If OK and (Res = 150) Then Begin
    Assign (F, LocalFile);

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

    If GetResponse = 226 Then
      Result := ftpResOK;
  End Else Begin
    If Res = 550 Then
      Result := ftpResNoFile
    Else
      Result := ftpResBadData;

    CloseDataSession;
  End;
End;

Function TFTPClient.GetFile (Passive: Boolean; FileName: String) : Byte;
Var
  F      : File;
  Res    : LongInt;
  Buffer : Array[1..8 * 1024] of Char;
  OK     : Boolean;
Begin
  Result := ftpResFailed;

  If FileExist(FileName) Then Exit;

  SetPassive(Passive);

  Client.WriteLine('RETR ' + JustFile(FileName));

  OK  := OpenDataSession;
  Res := GetResponse;

  If OK And (Res = 150) Then Begin
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

    If GetResponse = 226 Then
      Result := ftpResOK;
  End Else Begin
    If Res = 550 Then
      Result := ftpResNoFile
    Else
      Result := ftpResBadData;

    CloseDataSession;
  End;
End;

Function TFTPClient.ChangeDirectory (Str: String) : Boolean;
Begin
  Result := SendCommand('CWD ' + Str) = 250;
End;

Function TFTPClient.GetDirectoryList (Passive, Change: Boolean; Str: String) : Boolean;
Begin
  Result := False;

  If Change Then Begin
    Result := ChangeDirectory(Str);

    If Not Result Then Exit;
  End;

  SetPassive(Passive);

  Client.WriteLine ('NLST');

  If OpenDataSession and (GetResponse = 150) Then Begin

    ResponseData.Clear;

    Repeat
      If DataSocket.ReadLine(Str) <> -1 Then
        ResponseData.Add(Str)
      Else
        Break;
    Until Not DataSocket.Connected;

    Result := GetResponse = 226;
  End;

  CloseDataSession;
End;

Procedure TFTPClient.CloseConnection;
Begin
  If Client.Connected Then
    Client.WriteLine('QUIT');
End;

End.

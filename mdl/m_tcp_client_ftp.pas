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
    Function    SendDataCommand   (UsePassive: Boolean; Cmd: String) : LongInt;
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
//  writeln('DEBUG data socket was not NIL');
    DataSocket.Free;

    DataSocket := NIL;
  End;

  If IsPassive Then Begin
    DataSocket := TIOSocket.Create;

//    writeln ('DEBUG connecting PASV to ', dataip, ':', dataport);

    If Not DataSocket.Connect(DataIP, DataPort) Then Begin
      DataSocket.Free;
      DataSocket := NIL;

      Exit;
    End;

//    writeln ('DEBUG connected PASV');
  End Else Begin
    WaitSock := TIOSocket.Create;

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

  // Setup misc session crap here

  If SendCommand('TYPE I') = 200 Then;
  If SendCommand('MODE S') = 200 Then;

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
  Buffer : Array[1..16 * 1024] of Char;
  Res    : LongInt;
Begin
  Result := ftpResFailed;

  If Not FileExist(LocalFile) Then Exit;

  Res := SendDataCommand(Passive, 'STOR ' + JustFile(RemoteFile));

  If (Res = 150) Then Begin
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
  Buffer : Array[1..16 * 1024] of Char;
Begin
  Result := ftpResFailed;

  If FileExist(FileName) Then Exit;

  Res := SendDataCommand (Passive, 'RETR ' + JustFile(FileName));

  If (Res = 150) Then Begin
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

Function TFTPClient.SendDataCommand (UsePassive: Boolean; Cmd: String) : LongInt;
Var
  OK : Boolean;
Begin
  SetPassive (UsePassive);

  If UsePassive Then Begin
    OK := OpenDataSession;

    If OK Then
      Result := SendCommand(Cmd);
  End Else Begin
    Result := SendCommand(Cmd);
    OK     := OpenDataSession;
  End;

  If Not OK Then Result := -1;
End;

Function TFTPClient.GetDirectoryList (Passive, Change: Boolean; Str: String) : Boolean;
Var
  Res : LongInt;
Begin
  If Change Then Begin
    Result := ChangeDirectory(Str);

    If Not Result Then Exit;
  End;

  Res    := SendDataCommand(Passive, 'NLST');
  Result := Res = 550;

  If (Res = 125) or (Res = 150) Then Begin
    ResponseData.Clear;

    Repeat
      If DataSocket.ReadLine(Str) <> -1 Then
        ResponseData.Add(Str)
      Else
        Break;
    Until Not DataSocket.Connected;

    Res    := GetResponse;
    Result := Res = 226;
  End;

  CloseDataSession;
End;

Procedure TFTPClient.CloseConnection;
Begin
  If Client.Connected Then
    Client.WriteLine('QUIT');
End;

End.

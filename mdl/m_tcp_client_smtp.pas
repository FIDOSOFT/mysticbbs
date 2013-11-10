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
Unit m_TCP_Client_SMTP;

{$I M_OPS.PAS}

Interface

Uses
  Classes,
  m_Strings,
  m_DateTime,
  m_Crypt,
  m_IO_Sockets,
  m_TCP_Client;

Type
  TSMTPClient = Class(TTCPClient)
    ServerID : String;
    FromAddr : String[60];
    FromName : String[60];
    ToAddr   : String[60];
    ToName   : String[60];
    Subject  : String;
    MsgText  : TStringList;
    Opened   : Boolean;

    Constructor Create            (NetI: String); Override;
    Destructor  Destroy;          Override;
    Function    OpenConnection    (HostName: String) : Boolean;
    Function    Authenticate      (AuthType: Byte; Login, Password: String) : Boolean;
    Function    SendMessage       : Boolean;
  End;

Implementation

Constructor TSMTPClient.Create (NetI: String);
Begin
  Inherited Create(NetI);

  MsgText := TStringList.Create;
  Opened  := False;
End;

Destructor TSMTPClient.Destroy;
Begin
  MsgText.Free;

  If Opened Then
    Client.WriteLine('QUIT');

  Inherited Destroy;
End;

Function TSMTPClient.OpenConnection (HostName: String) : Boolean;
Var
  Port : Word;
Begin
  Result := False;

  Port := strS2I(strWordGet(2, HostName, ':'));

  If Port = 0 Then Port := 25;

  If Connect(strWordGet(1, HostName, ':'), Port) Then
    If GetResponse = 220 Then Begin
      Result := SendCommand('EHLO ' + ServerID) = 250;

      If Not Result Then
        Result := SendCommand('HELO ' + ServerID) = 250;
    End;
End;

Function TSMTPClient.Authenticate (AuthType: Byte; Login, Password: String) : Boolean;
// 0=None, 1=Login, 2=Plain, 3=CRAM-MD5
Var
  Str   : String;
  Count : Byte;
Begin
  Result := False;

  Case AuthType of
    0 : Result := True;
    1 : If SendCommand('AUTH LOGIN') = 334 Then
          If SendCommand(B64Encode(Login)) = 334 Then
            Result := SendCommand(B64Encode(Password)) = 235;
    2 : Result := SendCommand('AUTH PLAIN ' + B64Encode(Login + #0 + Login + #0 + Password)) = 235;
    3 : If SendCommand('AUTH CRAM-MD5') = 334 Then Begin
          Str    := B64Decode(Copy(ResponseStr, 5, 255));
          Str    := B64Encode(Login + ' ' + Digest2String(HMAC_MD5(Str, Password)));
          Result := SendCommand(Str) = 235;
        End;
  End;
End;

Function TSMTPClient.SendMessage : Boolean;

  Function NameStr (SN, SA: String) : String;
  Begin
    If SN <> '' Then
      Result := '"' + SN + '" <' + SA + '>'
    Else
      Result := SA;
  End;

Var
  Count : LongInt;
Begin
  Result := False;

  If SendCommand('MAIL FROM:<' + FromAddr + '>') <> 250 Then Exit;
  If SendCommand('RCPT TO:<' + ToAddr + '>') <> 250 Then Exit;
  If SendCommand('DATA') <> 354 Then Exit;

  Client.WriteLine('From: ' + NameStr(FromName, FromAddr));
  Client.WriteLine('To: ' + NameStr(ToName, ToAddr));
  Client.WriteLine('Date: ' + DayString[DayOfWeek(CurDateDos)] + ', ' + FormatDate(CurDateDT, 'DD NNN YYYY HH:II:SS'));
  Client.WriteLine('Subject: ' + Subject);
  Client.WriteLine('');

  For Count := 0 to MsgText.Count - 1 Do
    Client.WriteLine (MsgText.Strings[Count]);

  Client.WriteLine('.');

  Result := GetResponse = 250;
End;

End.

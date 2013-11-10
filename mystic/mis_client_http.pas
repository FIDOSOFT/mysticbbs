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

Unit MIS_Client_HTTP;

{$I M_OPS.PAS}

Interface

Uses
  MD5,
  Classes,
  SysUtils,
  m_Strings,
  m_FileIO,
  m_io_Sockets,
  m_DateTime,
  MIS_Server,
  MIS_NodeData,
  MIS_Common,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Function CreateHTTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  THTTPServer = Class(TServerClient)
    Server   : TServerManager;
    UserName : String[30];
    LoggedIn : Boolean;
    GotQuit  : Boolean;
    Cmd      : String;
    Data     : String;

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   ResetSession;
  End;

Implementation

Function CreateHTTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := THTTPServer.Create(Owner, CliSock);
End;

Constructor THTTPServer.Create (Owner: TServerManager; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Server := Owner;
End;

Procedure THTTPServer.ResetSession;
Var
  Count : LongInt;
Begin
  LoggedIn := False;
  GotQuit  := False;
End;

Procedure THTTPServer.Execute;
Var
  Str : String;
Begin
  ResetSession;

//  Client.WriteLine(re_Greeting);

  Repeat
    If Client.WaitForData(60 * 1000) = 0 Then Break;

    If Terminated Then Exit;

    If Client.ReadLine(Str) = -1 Then Exit;

    Cmd := strUpper(strWordGet(1, Str, ' '));

    If Pos(' ', Str) > 0 Then
      Data := strStripB(Copy(Str, Pos(' ', Str) + 1, Length(Str)), ' ')
    Else
      Data := '';

    If Cmd = 'QUIT' Then Begin
      GotQuit := True;

      Break;
    End Else
      Client.WriteLine(re_UnknownCommand);
  Until Terminated;

  If GotQuit Then Begin
    Client.WriteLine(re_Goodbye);

    Server.Server.Status (User.Handle + ' logged out');
  End;
End;

Destructor THTTPServer.Destroy;
Begin
  ResetSession;

  Inherited Destroy;
End;

End.

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
Unit m_Protocol_Base;

{$I M_OPS.PAS}

Interface

Uses
  m_DateTime,
  m_Input,
  m_io_Base,
  m_Protocol_Queue;

Type
  RecProtocolStatus = Record
    Protocol    : String[15];
    Sender      : Boolean;
    FilePath    : String;
    FileName    : String;
    FileSize    : Int64;
    Position    : Int64;
    BlockSize   : Word;
    Errors      : Word;
    StartTime   : LongInt;
    StartPos    : Int64;
    LastMessage : String[80];
  End;

  TProtocolStatusProc = Procedure (Starting, Ending: Boolean; Status: RecProtocolStatus);
  TProtocolAbortProc  = Function : Boolean;

  TProtocolBase = Class
    Status      : RecProtocolStatus;
    StatusProc  : TProtocolStatusProc;
    AbortProc   : TProtocolAbortProc;
    Client      : TIOBase;
    Queue       : TProtocolQueue;
    EndTransfer : Boolean;
    Connected   : Boolean;
    StatusCheck : Word;
    StatusTimer : LongInt;
    ReceivePath : String;

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Virtual;
    Destructor  Destroy; Override;

    Function    AbortTransfer   : Boolean;
    Procedure   StatusUpdate    (Starting, Ending: Boolean);
    Function    ReadByteTimeOut (hSec: LongInt) : SmallInt;

    Procedure   QueueReceive; Virtual;
    Procedure   QueueSend; Virtual;
  End;

Implementation

Function NoAbortProc : Boolean;
Begin
  Result := False;
End;

Constructor TProtocolBase.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Client      := C;
  Queue       := Q;
  EndTransfer := False;
  Connected   := True;
  ReceivePath := '';
  StatusProc  := NIL;
  AbortProc   := @NoAbortProc;
  StatusCheck := 100;
  StatusTimer := 0;

  FillChar(Status, SizeOf(Status), 0);
End;

Destructor TProtocolBase.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TProtocolBase.StatusUpdate (Starting, Ending: Boolean);
Begin
  If Assigned(StatusProc) Then
    StatusProc(Starting, Ending, Status);
End;

Function TProtocolBase.ReadByteTimeOut (hSec: LongInt) : SmallInt;
Var
  Res : Byte;
Begin
  Result := -1;

  If Client.DataWaiting Then Begin
    Connected := Client.ReadBuf(Res, 1) >= 0;
    Result    := Res;
  End Else
    Case Client.WaitForData(hSec * 10) of
      -1 : Connected := False;
      0  : ;
    Else
      Client.ReadBuf(Res, 1);
      Result := Res;
    End;
End;

Function TProtocolBase.AbortTransfer : Boolean;
Begin
  If Not EndTransfer Then
    EndTransfer := (Not Connected) or AbortProc;

  AbortTransfer := EndTransfer;
End;

Procedure TProtocolBase.QueueReceive;
Begin
End;

Procedure TProtocolBase.QueueSend;
Begin
End;

End.

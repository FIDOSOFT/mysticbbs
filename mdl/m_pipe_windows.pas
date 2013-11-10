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
Unit m_Pipe_Windows;

{$I M_OPS.PAS}

Interface

Uses
  Windows,
  m_DateTime,
  m_FileIO,
  m_Strings;

Const
  TPipeBufSize = 8 * 1024;

Type
  TPipeWindows = Class
    PipeID     : Word;
    Connected  : Boolean;
    IsClient   : Boolean;
    PipeHandle : LongInt;

    Constructor Create       (Dir: String; Client: Boolean; ID: Word);
    Destructor  Destroy;     Override;
    // Server functions
    Function    CreatePipe   : Boolean;
    Function    WaitForPipe  (Secs: LongInt) : Boolean;
    // Client functions
    Function    ConnectPipe  (Secs: LongInt) : Boolean;
    // General functions
    Procedure   SendToPipe   (Var Buf; Len: Longint);
    Procedure   ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongInt);
    Procedure   Disconnect;
    Function    DataWaiting : Boolean;
  End;

Implementation

Constructor TPipeWindows.Create (Dir: String; Client: Boolean; ID: Word);
Begin
  Connected  := False;
  IsClient   := Client;
  PipeID     := ID;
  PipeHandle := -1;
End;

Destructor TPipeWindows.Destroy;
Begin
  If Connected Then Disconnect;

  Inherited Destroy;
End;

Function TPipeWindows.DataWaiting : Boolean;
Var
  Temp  : LongWord;
  Avail : LongWord;
Begin
  Result := False;
  Temp   := 0;

  If PipeHandle = -1 Then Exit;

  PeekNamedPipe (PipeHandle,
                 NIL,
                 Temp,
                 NIL,
                 @Avail,
                 NIL);

  Result := (Avail > 0);
End;

Function TPipeWindows.CreatePipe : Boolean;
Var
  SecAttr  : TSecurityAttributes;
  PipeName : String;
Begin
  IsClient := False;

  FillChar (SecAttr, SizeOf(SecAttr), 0);

  SecAttr.nLength              := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := NIL;
  SecAttr.bInheritHandle       := True;

  PipeName   := '\\.\PIPE\MYSTIC_' + strI2S(PipeID) + #0;
  PipeHandle := CreateNamedPipe (@PipeName[1],
                                  PIPE_ACCESS_DUPLEX OR FILE_FLAG_WRITE_THROUGH,
                                  PIPE_TYPE_BYTE OR PIPE_READMODE_BYTE OR PIPE_NOWAIT,
                                  2,         //MaxPipes
                                  TPipeBufSize,  //Buffer size
                                  TPipeBufSize,
                                  1000,       //Pipe wait
                                  @SecAttr
                                );

  Result := PipeHandle <> INVALID_HANDLE_VALUE;
End;

Procedure TPipeWindows.SendToPipe (Var Buf; Len: LongInt);
Var
  Written : LongWord;
Begin
  If Not Connected Then Exit;

  WriteFile (PipeHandle, Buf, Len, Written, NIL);

  If Written <= 0 Then
    Disconnect;  // was ERROR_SUCCESS check
End;

Procedure TPipeWindows.ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongInt);
Begin
  bRead := 0;

  If Not Connected Then Exit;

  ReadFile (PipeHandle, Buf, Len, LongWord(bRead), NIL);

  If GetLastError <> ERROR_SUCCESS Then
    Disconnect;
End;

Function TPipeWindows.WaitForPipe (Secs: LongInt) : Boolean;
Var
  Res     : LongBool;
  LE      : LongInt;
  TimeOut : LongInt;
Begin
  Result := Connected;

  If Connected Then Exit;

  TimeOut := TimerSet(Secs);

  Repeat
    Res := ConnectNamedPipe (PipeHandle, NIL);
    LE  := GetLastError;

    Connected := (LE = ERROR_PIPE_CONNECTED) or (Res);
  Until Connected or TimerUp(TimeOut);

  Result := Connected;
End;

Function TPipeWindows.ConnectPipe (Secs: LongInt) : Boolean;
Var
  SecAttr  : TSecurityAttributes;
  PipeName : String;
  TimeOut  : LongInt;
Begin
  IsClient := True;

  Disconnect;

  FillChar (SecAttr, SizeOf(SecAttr), 0);

  SecAttr.nLength              := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := NIL;
  SecAttr.bInheritHandle       := True;

  PipeName := '\\.\PIPE\MYSTIC_' + strI2S(PipeID) + #0;
  TimeOut  := TimerSet(Secs);

  Repeat
    PipeHandle := CreateFile (@PipeName[1],
                              GENERIC_READ OR GENERIC_WRITE,
                              0,
                              @SecAttr,
                              OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL OR FILE_FLAG_WRITE_THROUGH,
                              0);

    Connected := GetLastError = ERROR_SUCCESS;
  Until Connected or TimerUp(TimeOut);

  Result := Connected;
End;

Procedure TPipeWindows.Disconnect;
Begin
  If PipeHandle = -1 Then Exit;

  DisconnectNamedPipe (PipeHandle);
  CloseHandle         (PipeHandle);

  PipeHandle := -1;
  Connected  := False;
End;

End.

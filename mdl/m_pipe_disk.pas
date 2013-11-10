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
Unit m_Pipe_Disk;

{$I M_OPS.PAS}

Interface

Uses
  m_DateTime,
  m_FileIO,
  m_Strings;

Const
  PipeClientResetTimer = 6000;  //  60 seconds
  PipeServerTimeout    = 9000;  //  90 seconds

  PipeInFileName  = '__mys_in.';
  PipeOutFileName = '__mys_out.';
  PipeCmdFileName = '__mys_cmd.';

Type
  TPipeDiskBuffer = Array[0..8 * 1024 - 1] of Char;

  TPipeDisk = Class
    PipeID     : Word;
    PipeInput  : File;
    PipeOutput : File;
    Connected  : Boolean;
    ResetTimer : LongInt;
    IsClient   : Boolean;
    PipeDir    : String;

    Constructor Create       (Dir: String; Client: Boolean; ID: Word);
    Destructor  Destroy;     Override;
    // Server functions
    Function    CreatePipe   : Boolean;
    Function    WaitForPipe  (Secs: LongInt) : Boolean;
    // Client functions
    Function    ConnectPipe  (Secs: LongInt) : Boolean;
    // General functions
    Procedure   DeleteFiles;
    Procedure   SendToPipe   (Var Buf; Len: Longint);
    Procedure   ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongWord);
    Procedure   Disconnect;
  End;

Implementation

Procedure TPipeDisk.DeleteFiles;
Begin
  If IsClient Then
    FileErase (PipeDir + PipeCmdFileName + strI2S(PipeID))
  Else Begin
    FileErase (PipeDir + PipeInFileName  + strI2S(PipeID));
    FileErase (PipeDir + PipeOutFileName + strI2S(PipeID));
  End;
End;

Constructor TPipeDisk.Create (Dir: String; Client: Boolean; ID: Word);
Begin
  Connected  := False;
  IsClient   := Client;
  ResetTimer := 0;
  PipeDir    := DirSlash(Dir);
  FileMode   := 66;
  PipeID     := ID;

  DeleteFiles;
End;

Destructor TPipeDisk.Destroy;
Begin
  If Connected Then Disconnect;

  DeleteFiles;

  Inherited Destroy;
End;

Function TPipeDisk.CreatePipe : Boolean;
Begin
  Result   := False;
  FileMode := 66;
  IsClient := False;

  Assign  (PipeInput,  PipeDir + PipeInFileName + strI2S(PipeID));
  ReWrite (PipeInput, 1);

  If IoResult <> 0 Then Exit;

  Assign  (PipeOutput, PipeDir + PipeOutFileName + strI2S(PipeID));
  ReWrite (PipeOutput, 1);

  If IoResult <> 0 Then Begin
    Close (PipeInput);
    Exit;
  End;

  Result := True;
End;

Procedure TPipeDisk.SendToPipe (Var Buf; Len: LongInt);
Var
  bWrite : LongInt;
Begin
  If Not Connected Then Exit;

  FileMode := 66;

  If Not IsClient Then Begin
    If FilePos(PipeInput) <> FileSize(PipeInput) Then Begin
      ReWrite (PipeOutput, 1);
      Seek    (PipeInput, FileSize(PipeInput));

      ResetTimer := TimerSet(PipeServerTimeout);
    End;

    If TimerUp(ResetTimer) Then Begin
      Disconnect;
      Exit;
    End;
  End;

  If Len = 0 Then Exit;

  BlockWrite (PipeOutput, Buf, Len, bWrite);
End;

Procedure TPipeDisk.ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongWord);
Var
  Buffer  : TPipeDiskBuffer Absolute Buf;
  Ch      : Char;
  OldSize : LongInt;
Begin
  bRead := 0;

  If Not Connected Then Exit;

  FileMode := 66;

  BlockRead (PipeInput, Buffer[0], Len, bRead);

  If IsClient And TimerUp(ResetTimer) Then Begin

    Ch := #1;

    SendToPipe(Ch, 1);

    OldSize := FileSize(PipeInput);

    Close (PipeInput);

    Repeat
      WaitMS(100);

      Assign (PipeInput, PipeDir + PipeOutFileName + strI2S(PipeID));
      Reset  (PipeInput, 1);
    Until FileSize(PipeInput) < OldSize;

    ResetTimer := TimerSet(PipeClientResetTimer);
  End;
End;

Function TPipeDisk.WaitForPipe (Secs: LongInt) : Boolean;
Var
  TimeOut : LongInt;
Begin
  Result   := Connected;
  FileMode := 66;

  If Connected Then Exit;

  TimeOut := TimerSet(Secs);

  While Not TimerUp(TimeOut) Do Begin
    If FileExist(PipeDir + PipeCmdFileName + strI2S(PipeID)) Then Begin
      Connected  := True;
      ResetTimer := TimerSet(PipeServerTimeout);
      Break;
    End;

    WaitMS(100);
  End;

  Result := Connected;
End;

Function TPipeDisk.ConnectPipe (Secs: LongInt) : Boolean;
Var
  TempStr : String;
  TimeOut : LongInt;
Begin
  Result    := False;
  Connected := False;
  TimeOut   := TimerSet(Secs);
  FileMode  := 66;
  IsClient  := True;

  While Not TimerUp(TimeOut) Do Begin
    Assign  (PipeInput, PipeDir + PipeCmdFileName + strI2S(PipeID));
    ReWrite (PipeInput, 1);
    Close   (PipeInput);

    Assign (PipeInput, PipeDir + PipeOutFileName + strI2S(PipeID));
    Reset  (PipeInput, 1);

    If IoResult <> 0 Then Begin
      WaitMS(100);
      Continue;
    End;

    Assign (PipeOutput, PipeDir + PipeInFileName + strI2S(PipeID));
    Reset  (PipeOutput, 1);

    If IoResult <> 0 Then Begin
      Close (PipeInput);
      WaitMS (100);
      Continue;
    End Else Begin
      Connected  := True;
      ResetTimer := TimerSet(PipeClientResetTimer);

      Break;
    End;
  End;

  Result := Connected;
End;

Procedure TPipeDisk.Disconnect;
Begin
  If Not Connected Then Exit;

  Connected := False;

  Close (PipeInput);
  Close (PipeOutput);

  DeleteFiles;
End;

End.

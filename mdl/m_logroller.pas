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
Unit m_LogRoller;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  m_Strings,
  m_DateTime;

Const
  CRLF     = {$IFDEF WINDOWS} #13#10; {$ENDIF}
             {$IFDEF UNIX}    #10;    {$ENDIF}
             {$IFDEF OS2}     #13#10; {$ENDIF}
  log      = 1;
  logStart = 2;

Type
  TLogRoller = Class
    PreFix   : String;
    LogFile  : TFileBuffer;
    BufSize  : LongInt;
    MaxSize  : LongInt;
    MaxLogs  : Byte;
    CurLevel : Byte;

    Constructor Create (FN: String; Max: LongInt; ML, Level: Byte);
    Destructor  Destroy; Override;
    Procedure   Add (LogType, LogLevel: Byte; LogChar: Char; LogStr: String);
  End;

Implementation

Constructor TLogRoller.Create (FN: String; Max: LongInt; ML, Level: Byte);
Begin
  Inherited Create;

  MaxSize  := Max * 1024;
  MaxLogs  := ML;
  BufSize  := 8 * 1024;
  CurLevel := Level;
  PreFix   := FN;

  LogFile := TFileBuffer.Create(BufSize);

  LogFile.OpenStream (PreFix + '_1.log', 1, fmOpenCreate, 66);
End;

Destructor TLogRoller.Destroy;
Begin
  LogFile.Free;

  Inherited Destroy;
End;

Procedure TLogRoller.Add (LogType, LogLevel: Byte; LogChar: Char; LogStr: String);
Var
  Count : Byte;
Begin
  If CurLevel < LogLevel Then Exit;

  If (MaxSize > 0) And (System.FileSize(LogFile.InFile) + LogFile.BufPos > MaxSize) Then Begin
    LogFile.CloseStream;

    FileErase (PreFix + '_' + strI2S(MaxLogs) + '.log');

    For Count := MaxLogs - 1 DownTo 1 Do
      FileReName (PreFix + '_' + strI2S(Count) + '.log', PreFix + '_' + strI2S(Count + 1) + '.log');

    LogFile.OpenStream (PreFix + '_1.log', 1, fmOpenAppend, 66);
  End;

  Case LogType of
    logStart : LogStr := '----------  ' + LogStr + ', ' + FormatDate(CurDateDT, 'NNN DD YYYY') + CRLF;
    log      : LogStr := LogChar + ' ' + FormatDate(CurDateDT, 'HH:II:SS') + '  ' + LogStr + CRLF;
  End;

  LogFile.WriteBlock (LogStr[1], Length(LogStr));
End;

End.

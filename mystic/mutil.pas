Program MUTIL;

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

{$I M_OPS.PAS}

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  m_Output,
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_IniReader,
  mUtil_Common,
  mUtil_Status,
  mUtil_ImportNA,
  mUtil_ImportMsgBase,
  mUtil_FileBone,
  mUtil_Upload,
  mUtil_TopLists,
  mUtil_FilesBBS,
  mUtil_AllFiles,
  mUtil_MsgPurge,
  mUtil_MsgPack,
  mUtil_MsgPost,
  bbs_Common;

{$I MUTIL_ANSI.PAS}

Function CheckProcess (pName: String) : Boolean;
Begin
  Result := INI.ReadBoolean(Header_General, pName, False);

  If Result Then Begin
    Inc (ProcessTotal);

    Log (2, '+', '   EXEC ' + pName);
  End Else
    Log (2, '+', '   SKIP ' + pName);
End;

Procedure ApplicationShutdown;
Begin
  Log (1, '+', '=> Shutdown');
  Log (1, '+', '');

  If Assigned(Console) Then Begin
    Console.SetWindow (1, 1, 80, 25, False);
    Console.CursorXY  (3, 22);

    Console.TextAttr := 15;
    Console.WriteLine('> Execution of ' + strI2S(ProcessTotal) + ' processes complete');
    Console.TextAttr := 7;
  End;

  BarOne.Free;
  BarAll.Free;
  INI.Free;
  Console.Free;
End;

Procedure ApplicationStartup;
Var
  FN : String;
  CF : File of RecConfig;
Begin
  ExitProc := @ApplicationShutdown;
  Console  := TOutput.Create(strUpper(ParamStr(2)) <> '-NOSCREEN');

  If Console.Active Then DrawStatusScreen;

  Console.SetWindow(5, 14, 76, 20, True);

  If FileExist(ParamStr(1)) Then
    FN := ParamStr(1)
  Else
  If FileExist('mutil.ini') Then
    FN := 'mutil.ini'
  Else Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing file', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  INI := TINIReader.Create(FN);

  Console.WriteXY (26, 10, 8, FN);

  Assign (CF, INI.ReadString(Header_GENERAL, 'mystic_directory', 'mystic.dat'));

  {$I-} Reset(CF); {$I+}

  If IoResult <> 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing MYSTIC.DAT', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  Read  (CF, bbsConfig);
  Close (CF);

  If bbsConfig.DataChanged <> mysDataChanged Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Version mismatch', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  TempPath := bbsConfig.SystemPath + 'temp0' + PathChar;

  GetDIR (0, StartPath);

  {$I-}
  MkDir (TempPath);
  {$I+}

  If IoResult <> 0 Then;

  DirClean (TempPath, '');

  LogFile := INI.ReadString(Header_GENERAL, 'logfile', '');

  If (LogFile <> '') and (Pos(PathChar, LogFile) = 0) Then
    LogFile := bbsConfig.LogsPath + LogFile;

  LogLevel := INI.ReadInteger(Header_GENERAL, 'loglevel', 1);

  BarOne := TStatusBar.Create(3);
  BarAll := TStatusBar.Create(6);
End;

Var
  DoImportNA   : Boolean;
  DoFilesBBS   : Boolean;
  DoFileBone   : Boolean;
  DoMassUpload : Boolean;
  DoTopLists   : Boolean;
  DoAllFiles   : Boolean;
  DoMsgPurge   : Boolean;
  DoMsgPack    : Boolean;
  DoMsgPost    : Boolean;
  DoImportMB   : Boolean;
Begin
  ApplicationStartup;

  Log (1, '+', '=> Startup using ' + JustFile(INI.FileName));

  // Build process list

  DoImportNA   := CheckProcess(Header_IMPORTNA);
  DoImportMB   := CheckProcess(Header_IMPORTMB);
  DoFileBone   := CheckProcess(Header_FILEBONE);
  DoMassUpload := CheckProcess(Header_UPLOAD);
  DoTopLists   := CheckProcess(Header_TOPLISTS);
  DoFilesBBS   := CheckProcess(Header_FILESBBS);
  DoAllFiles   := CheckProcess(Header_ALLFILES);
  DoMsgPurge   := CheckProcess(Header_MSGPURGE);
  DoMsgPack    := CheckProcess(Header_MSGPACK);
  DoMsgPost    := CheckProcess(Header_MSGPOST);

  // Exit with an error if nothing is configured

  If ProcessTotal = 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('No processes configured!', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  // We're good lets execute this stuff!

  If DoImportNA   Then uImportNA;
  If DoImportMB   Then uImportMessageBases;
  If DoFileBone   Then uImportFileBone;
  If DoFilesBBS   Then uImportFilesBBS;
  If DoMassUpload Then uMassUpload;
  If DoTopLists   Then uTopLists;
  If DoAllFiles   Then uAllFilesList;
  If DoMsgPurge   Then uPurgeMessageBases;
  If DoMsgPack    Then uPackMessageBases;
  If DoMsgPost    Then uPostMessages;
End.

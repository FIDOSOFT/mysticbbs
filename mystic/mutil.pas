Program MUTIL;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
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

// MBBSUTIL replacement WIP
//
// Eventually all of MBBSUTIL stuff will be incorporated into this program.
// MBBSUTIL and MYSTPACK will be phased out in favor of this program.
//
// The goal of this program is to have basically everything under the sun
// all in one utility.  Eventually it may even have a full blown FIDO-style
// tosser too.  TOP 10 generators, etc.  It's all planned for MUTIL.

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  INIFiles,
  m_Output,
  m_DateTime,
  m_Strings,
  m_FileIO,
  mutil_Common,
  mutil_Status,
  mutil_ImportNA,
  mutil_Upload;

{$I MUTIL_ANSI.PAS}

Function CheckProcess (pName: String) : Boolean;
Begin
  Result := False;

  If strUpper(INI.ReadString(Header_General, pName, 'FALSE')) = 'TRUE' Then Begin
    Result := True;

    Inc (ProcessTotal);
  End;
End;

Procedure ApplicationShutdown;
Begin
  If Assigned(Console) Then Begin
    Console.SetWindow (1, 1, 80, 25, False);
    Console.CursorXY  (3, 22);

    Console.TextAttr := 15;
    Console.WriteLine('> Execution complete');
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
  Console  := TOutput.Create(True);

  DrawStatusScreen;

  Console.SetWindow(5, 14, 76, 21, True);

  If FileExist(ParamStr(1)) Then
    FN := ParamStr(1)
  Else
  If FileExist('mutil.cfg') Then
    FN := 'mutil.cfg'
  Else Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing file');
    ProcessResult (rFATAL, True);

    Halt(1);
  End;

  INI := TINIFile.Create(FN);

  Console.WriteXY (26, 10, 8, FN);

  Assign (CF, INI.ReadString(Header_GENERAL, 'mystic_directory', 'mystic.dat'));

  {$I-} Reset(CF); {$I+}

  If IoResult <> 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing MYSTIC.DAT');
    ProcessResult (rFATAL, True);

    Halt(1);
  End;

  Read  (CF, bbsConfig);
  Close (CF);

  If bbsConfig.DataChanged <> mysDataChanged Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Version mismatch');
    ProcessResult (rFATAL, True);

    Halt(1);
  End;

  TempPath := bbsConfig.SystemPath + 'temp0' + PathChar;

  GetDIR (0, StartPath);

  {$I-}
  MkDir (TempPath);
  {$I+}

  DirClean (TempPath, '');

  BarOne := TStatusBar.Create(3);
  BarAll := TStatusBar.Create(6);
End;

Var
  DoImportNA   : Boolean;
  DoMassUpload : Boolean;
Begin
  ApplicationStartup;

  // Build process list

  DoImportNA   := CheckProcess(Header_IMPORTNA);
  DoMassUpload := CheckProcess(Header_UPLOAD);

  // Exit with an error if nothing is configured

  If ProcessTotal = 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('No processes are configured!');
    ProcessResult (rFATAL, True);

    Halt(1);
  End;

  // We're good lets execute this stuff!

  If DoImportNA   Then uImportNA;
  If DoMassUpload Then uMassUpload;
End.

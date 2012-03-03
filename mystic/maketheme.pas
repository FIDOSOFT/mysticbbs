Program MakeTheme;

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

Uses
  DOS,
  m_Strings,
  m_FileIO;

{$I RECORDS.PAS}

Var
  bbsConfig  : RecConfig;
  BasePath   : String;
  InFN       : String;
  OutFN      : String;
  Action     : String;
  ConfigFile : File of RecConfig;
  ThemeFile  : File of RecPrompt;
  Theme      : RecPrompt;
  Found      : Array[0..mysMaxThemeText] of Boolean;
  FDir       : DirStr;
  FName      : NameStr;
  FExt       : ExtStr;
  Buffer     : Array[1..2048] of Byte;
  TF         : Text;

Procedure CompileTheme;
Var
  Count : LongInt;
  Temp  : String;
Begin
  FSplit (InFN, FDir, FName, FExt);

  Assign     (TF, FName + FExt);
  SetTextBuf (TF, Buffer, SizeOf(Buffer));
  Reset      (TF);

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Theme file (' + FName + FExt + ') not found.');
    Halt (1);
  End;

  Write ('Compiling Theme file: ');

  Assign  (ThemeFile, bbsConfig.DataPath + FName + '.thm');
  ReWrite (ThemeFile);

  If IoResult <> 0 Then Begin
    WriteLn;
    WriteLn;
    WriteLn ('ERROR: Cannot run while Mystic is loaded.');
    Halt(1);
  End;

  Theme := '';

  For Count := 0 to mysMaxThemeText Do Begin
    Found[Count] := False;
    Write (ThemeFile, Theme);
  End;

  Reset (ThemeFile);

  While Not Eof(TF) Do Begin
    ReadLn (TF, Temp);

    If Copy(Temp, 1, 3) = '000' Then
      Count := 0
    Else
    If strS2I(Copy(Temp, 1, 3)) > 0 Then
      Count := strS2I(Copy(Temp, 1, 3))
    Else
      Count := -1;

    If Count <> -1 Then Begin
      If Count > mysMaxThemeText Then Begin
        WriteLn;
        WriteLn;
        WriteLn ('ERROR: Prompt #', Count, ' was not expected.  Theme file not created.');
        Close (ThemeFile);
        Erase (ThemeFile);
        Halt(1);
      End;

      If Found[Count] Then Begin
        WriteLn;
        WriteLn;
        WriteLn ('ERROR: Prompt #', Count, ' was found twice.  Theme file not created.');
        Close (ThemeFile);
        Erase (ThemeFile);
        Halt  (1);
      End;

      Found[Count] := True;
      Seek (ThemeFile, Count);
      Theme := Copy(Temp, 5, Length(Temp));
      Write (ThemeFile, Theme);
    End;
  End;

  Close (TF);
  Close (ThemeFile);

  WriteLn ('Done.');

  For Count := 0 to mysMaxThemeText Do Begin
    If Not Found[Count] Then Begin
      WriteLn;
      WriteLn (^G'ERROR: Prompt #', Count, ' was not found.  Theme file not created.');
      Erase (ThemeFile);
      Halt (1);
    End;
  End;
End;

Procedure ExtractTheme;
Var
  Count : LongInt;
Begin
  FSplit (InFN, FDir, FName, FExt);

  Assign (ThemeFile, bbsConfig.DataPath + FName + '.thm');
  Reset  (ThemeFile);

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Input file (' + bbsConfig.DataPath + FName + '.thm) not found');
    Halt (1);
  End;

  Assign (TF, OutFN);
  ReWrite(TF);

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to create output file.');
    Halt(1);
  End;

  Write ('Decompiling Theme file ... ');

  Count := 0;

  While Not Eof(ThemeFile) Do Begin
    Read (ThemeFile, Theme);
    WriteLn (TF, strPadL(strI2S(Count), 3, '0') + ' ' + Theme);
    Inc (Count);
  End;

  WriteLn (Count - 1, ' prompts.');

  Close (TF);
  Close (ThemeFile);
End;

Begin
  WriteLn;
  WriteLn ('MAKETHEME : Mystic BBS Theme Compiler Version ' + mysVersion);
  WriteLn ('Copyright (C) ' + mysCopyYear + ' By James Coyle.  All Rights Reserved');
  WriteLn;

  If ParamCount < 2 Then Begin
    WriteLn ('Usage: MakeTheme [Action] [Input File] <Output File>');
    WriteLn;
    WriteLn ('<Action> Options:');
    WriteLn ('   COMPILE : Compiles [Input File] into a Mystic Theme file');
    WriteLn ('   EXTRACT : Decompiles [Input File] into a text file ([Output File])');
    WriteLn;
    WriteLn ('Examples:');
    WriteLn ('   MakeTheme compile default.txt');
    WriteLn ('   MakeTheme extract default prompts.txt');
    WriteLn;
    WriteLn ('Note: Since MakeTheme does not compile comments into a compiled theme file,');
    WriteLn ('      comments will not be included when decompiling a theme file.');
    Halt (1);
  End;

  BasePath := GetENV('mysticbbs');
  Action   := strUpper(ParamStr(1));
  InFN     := ParamStr(2);
  OutFN    := ParamStr(3);
  FileMode := 2;

  Assign (ConfigFile, BasePath + 'mystic.dat');
  Reset  (ConfigFile);

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to read MYSTIC.DAT');
    WriteLn;
    WriteLn ('MYSTIC.DAT must exist in the same directory as MakeTheme, or in the');
    WriteLn ('path defined by the MYSTICBBS environment variable.');
    Halt    (1);
  End;

  Read  (ConfigFile, bbsConfig);
  Close (ConfigFile);

  If bbsConfig.DataChanged <> mysDataChanged Then Begin
    WriteLn ('ERROR: MakeTheme has detected a version mismatch');
    WriteLn;
    WriteLn ('MakeTheme or another BBS utility is an older incompatible version.  Make');
    WriteLn ('sure you have upgraded properly!');
    Halt (1);
  End;

  If Action = 'COMPILE' Then CompileTheme Else
  If Action = 'EXTRACT' Then ExtractTheme Else
  Begin
    WriteLn ('Invalid <action> option');
    Halt (1);
  End;
End.

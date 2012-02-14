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

Program MakeLang;

{$I M_OPS.PAS}

Uses
	DOS,
  m_Strings;

{$I RECORDS.PAS}

Var
	ConfigFile : File of RecConfig;
	PromptFile : File of PromptRec;
	Config		 : RecConfig;
	Prompt		 : PromptRec;
	Done			 : Array[0..mysMaxLanguageStr] of Boolean;
	tFile 		 : Text;
	A 				 : Integer;
	Temp			 : String;
	FName 		 : NameStr;
	FExt			 : ExtStr;
	FDir			 : DirStr;

Begin
	WriteLn;
	WriteLn ('MAKELANG (' + OSID + ') - Mystic Language Compiler v', mysVersion);
	WriteLn ('Copyright (C) 1997-2011 By James Coyle.  All Rights Reserved.');
	WriteLn;

	Assign (ConfigFile, 'mystic.dat');
	{$I-}Reset (ConfigFile);{$I+}
	If IoResult <> 0 Then Begin
		WriteLn ('ERROR: MYSTIC.DAT not found.  Run from main BBS directory.');
		Halt(1);
	End;
	Read (ConfigFile, Config);
	Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn('ERROR: Data files are not current and must be upgraded.');
    Halt(1);
  End;


	If ParamCount <> 1 Then Begin
		WriteLn ('Usage: MAKELANG [language_file]');
		Halt(1);
	End;

	FSplit (ParamStr(1), FDir, FName, FExt);

	Assign (tFile, FName + FExt);
	{$I-} Reset (tFile); {$I+}
	If IoResult <> 0 Then Begin
		WriteLn ('ERROR: Language file (' + FName + FExt + ') not found.');
		Halt(1);
	End;

	Write ('Compiling language file: ');

	Assign (PromptFile, Config.DataPath + FName + '.lng');
	{$I-} ReWrite (PromptFile); {$I+}

	If IoResult <> 0 Then Begin
		WriteLn;
		WriteLn;
		WriteLn (^G'ERROR: Cannot run while Mystic is loaded.');
		Halt(1);
	End;

	Prompt := '';
	For A := 0 to mysMaxLanguageStr Do Begin
		Done[A] := False;
		Write (PromptFile, Prompt);
	End;
	Reset (PromptFile);

	While Not Eof(tFile) Do Begin
		ReadLn (tFile, Temp);

		If Copy(Temp, 1, 3) = '000'      Then A := 0 Else
		If strS2I(Copy(Temp, 1, 3)) > 0 Then A := strS2I(Copy(Temp, 1, 3)) Else
		A := -1;

		If A <> -1 Then Begin
			If A > mysMaxLanguageStr Then Begin
				WriteLn;
				WriteLn;
				WriteLn (^G'ERROR: String #', A, ' was not expected.  Language file not created.');
				Close (PromptFile);
				Erase (PromptFile);
				Halt(1);
			End;

			Done[A] := True;
			Seek (PromptFile, A);
			Prompt := Copy(Temp, 5, Length(Temp));
			Write (PromptFile, Prompt);
		End;
	End;

	Close (tFile);
	Close (PromptFile);

	WriteLn ('Done.');

	For A := 0 to mysMaxLanguageStr Do Begin
		If Not Done[A] Then Begin
			WriteLn;
			WriteLn (^G'ERROR: String #', A, ' was not found.  Language file not created.');
			Erase (PromptFile);
		End;
	End;
End.

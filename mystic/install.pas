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

Program Install;

{$I M_OPS.PAS}
{$MODESWITCH NESTEDPROCVARS-}

Uses
  m_FileIO,
  m_Strings,
  m_Input,
  m_Output,
  m_DateTime,
  DOS,
	Install_Arc;

Var
  Screen : TOutput;
  Keys   : TInput;

{$I RECORDS.PAS}
{$I INSTALL_ANSI.PAS}

Procedure Clear_Screen;
Var
	A : Byte;
	B : Byte;
Begin
	A := 1;
	B := 25;

	Repeat
		If A > 1 Then Begin
			Screen.WriteXY (1, A-1, 0, strRep(' ', 80));
			Screen.WriteXY (1, B+1, 0, strRep(' ', 80));
		End;

		Screen.WriteXY (1, A, 8, 'ú-' + strRep('Ä', 75) + '--ú');
		Screen.WriteXY (1, B, 8, 'ú-' + strRep('Ä', 75) + '--ú');

		WaitMS(15);

		Inc (A);
		Dec (B);
	Until A = 14;

	A := 76;

	Repeat
		Dec (A, 2);
		Screen.WriteXY (1, 13, 8, strPadC('ú-' + strRep('Ä', A) + '--ú', 80, ' '));
		WaitMS(7);
	Until A = 0;

	Screen.TextAttr := 7;
	Screen.ClearScreen;
End;

Procedure ClearDisplay;
Var
	Count : Byte;
Begin
	For Count := 13 to 24 Do Begin
		Screen.CursorXY (1, Count);
		Screen.WriteStr (strRep(' ', 79));
	End;
End;

Procedure ShowError (Str : String);
Begin
	ClearDisplay;

  Screen.WriteXY (11, 15, 12, strPadC('ERROR: ' + Str, 60, ' '));
  Screen.WriteXY (19, 19,  7, 'An error has occured.  Press any key to exit');

	Keys.ReadKey;
	Clear_Screen;

  Screen.Free;
  Keys.Free;

	Halt;
End;

Function Path (Str: String) : String;
Begin
	If Str[Length(Str)] <> PathChar Then Str := Str + PathChar;
	Path := Str;
End;

Function IsDIR (Dir: String) : Boolean;
Var
	fHandle : File;
	wAttr 	: Word;
Begin
	While Dir[Length(Dir)] = PathChar Do Dec(Dir[0]);
	Dir := Dir + PathChar + '.';
	Assign	 (fHandle, Dir);
	GetFAttr (fHandle, wAttr);

	IsDir := ((wAttr And Directory) = Directory);
End;

Function MakeDir (Str: String) : Boolean;
Var
  PathPos : Byte;
  CurDIR  : String;
  Prefix  : String;
Begin
  Result := True;

  If DirExists(Str) Then Exit;

  Prefix  := '';
  PathPos := Pos(PathChar, Str);

  While (PathPos > 0) Do Begin
    CurDIR := Copy(Str, 1, PathPos);

    Delete (Str, 1, PathPos);

    Prefix := Prefix + CurDIR;

    If Not IsDir(Prefix) Then Begin
      {$I-} MkDIR (Prefix); {$I+}
      If IoResult <> 0 Then Begin
        ShowError('Unable to create: ' + Prefix);
      End;
    End;

    PathPos := Pos(PathChar, Str);
  End;
End;

Var
	Code : Char;

Function Input (X, Y, FieldLen: Byte; MaxLen: Byte; Default: String) : String;
Var
	Res 			: String;
	CursorPos : Integer;
	Done			: Boolean;
	Ch				: Char;
Begin
	Res 			:= Default;
	Done			:= False;
	CursorPos := Length(Res) + 1;
	Code			:= #0;
	Repeat
		Screen.WriteXY (X, Y, 63, strRep(' ', FieldLen));
		Screen.WriteXY (X, Y, 63, Copy(Res, CursorPos-FieldLen+1, FieldLen));

		If CursorPos > FieldLen Then
			Screen.CursorXY (X + FieldLen - 1, Y)
		Else
			Screen.CursorXY (X + CursorPos - 1, Y);

		Ch := Keys.ReadKey;
		Case Ch of
			#0	: Case Keys.ReadKey of
							#60 : Begin
											Code := #60;
											Done := True;
										End;
							#71 : CursorPos := 1;
							#72 : Begin
											Code := #72;
											Done := True;
										End;
							#73 : Begin
											Code := #73;
											Done := True;
										End;
							#75 : If CursorPos > 1 Then Dec(CursorPos);
							#77 : If CursorPos < Succ(Length(Res)) Then Inc(CursorPos);
							#79 : CursorPos := Succ(Length(Res));
							#80 : Begin
											Code := #80;
											Done := True;
										End;
							#81 : Begin
											Code := #81;
											Done := True;
										End;
							#83 : Delete(Res, CursorPos, 1);
						End;
			#8	: If CursorPos > 1 Then Begin
							Dec(CursorPos);
							Delete(Res, CursorPos, 1);
						End;
			#13 : Begin
							Code := #80;
							Done := True;
						End;
			#19 : Begin
							Code := #19;
							Done := True;
						End;
			#27 : Begin
							Code := #27;
							Done := True;
						End;
			Else
				If Length(Res) < MaxLen Then Begin
          Insert(Ch, Res, CursorPos);
          Inc(CursorPos);
				End;
		End;
	Until Done;

	Input := Res;
End;

Type
	CharRec = Record
							Ch : Char;
							A  : Byte;
						End;

	LineRec = Array[1..80] of CharRec;
	TxtRec = String[79];

Var
	Txt : Array[1..5000] of ^TxtRec;
	Config : RecConfig;
	Lang	 : RecTheme;

Procedure ViewTextFile (FN : String);
Const
  WinSize = 12;
Var
	T 		 : Text;
	Count  : Word;
	A 		 : Word;
	Line	 : Integer;
	Per 	 : LongInt;
	Per10  : Byte;
	BarPos : Byte = 0;
Begin
	Assign (T, FN);
	{$I-} Reset(T); {$I+}
	If IoResult <> 0 Then Exit;

	Count := 0;

	While Not Eof(T) Do Begin
		Inc (Count);
		New (Txt[Count]);
		ReadLn (T, Txt[Count]^);
	End;

	Close(T);

	DrawMainMenu;

  Screen.WriteXY (1, 25, 8, strRep('Ü', 79));
	Screen.WriteXY (2, 25, 7, ' ' + FN + ' ');

	Line := 1;

	Repeat
		If Line > Count - WinSize Then Line := Count - WinSize;
		If Line < 1 Then Line := 1;

		Per 	:= Round(Line / (Count - WinSize) * 100);
		Per10 := Per DIV 10;

		Screen.WriteXY (53, 25, 8, ' [' + strPadL(strI2S(Per), 3, ' ') + '%] ');

		If Per10 <> BarPos Then Begin
			Screen.WriteXY (64, 25, 8, ' [°°°°°°°°°°] ');

      BarPos := 0;

			While BarPos < Per10 Do Begin
				Inc (BarPos);

				Case BarPos of
          1 : Screen.WriteXY (66, 25, 1,  '²');
          2 : Screen.WriteXY (67, 25, 25, '°');
          3 : Screen.WriteXY (68, 25, 25, '±');
          4 : Screen.WriteXY (69, 25, 25, '²');
          5 : Screen.WriteXY (70, 25, 25, 'Û');
          6 : Screen.WriteXY (71, 25, 27, '°');
          7 : Screen.WriteXY (72, 25, 27, '±');
          8 : Screen.WriteXY (73, 25, 27, '²');
          9 : Screen.WriteXY (74, 25, 11, 'Û');
          10: Screen.WriteXY (75, 25, 15, 'Û');
				End;
			End;

			BarPos := Per10;
		End;

		For A := 0 to WinSize Do
			Screen.WriteXY (1, A + 11, 7, strPadR(Txt[Line + A]^, 80, ' '));

		Case Keys.ReadKey of
			#00 : Case Keys.ReadKey of
							#71 : Line := 1;
							#72 : Dec (Line);
							#73,
              #75 : Dec (Line, WinSize);
							#79 : Line := Count - WinSize;
							#80 : Inc (Line);
              #77,
							#81 : Inc (Line, WinSize);
						End;
			#27 : Break;
		End;
	Until False;

	For A := 1 to Count Do
		Dispose (Txt[A]);
End;

Procedure CompileLanguageFile;
Type
	PromptRec = String[255];
Var
	InFile		 : Text;
	PromptFile : File of PromptRec;
	Prompt		 : PromptRec;
	Str 			 : String;
	Count 		 : Integer;
Begin
	Assign (InFile, Config.SystemPath + 'default.txt');
	Reset  (InFile);

	Assign	(PromptFile, Config.DataPath + 'default.thm');
	ReWrite (PromptFile);

	While Not Eof(InFile) Do Begin
		ReadLn (InFile, Str);

		If Copy(Str, 1, 3) = '000'      Then Count := 0 Else
		If strS2I(Copy(Str, 1, 3)) > 0 Then Count := strS2I(Copy(Str, 1, 3)) Else
		Count := -1;

		If Count <> -1 Then Begin
			Seek (PromptFile, Count);
			Prompt := Copy(Str, 5, Length(Str));
			Write (PromptFile, Prompt);
		End;
	End;

	Close (PromptFile);
	Close (InFile);
End;

Procedure CreateDirectories;
Begin
  Screen.WriteXYPipe (23, 13, 7, 45, '|08[|15û|08] |07Creating directories|08...');

	MakeDir (Config.SystemPath);
	MakeDir (Config.DataPath);
	MakeDir (Lang.TextPath);
	MakeDir (Lang.MenuPath);
	MakeDir (Config.LogsPath);
	MakeDir (Config.MsgsPath);
	MakeDir (Config.SemaPath);
	MakeDir (Config.ScriptPath);
	MakeDir (Config.AttachPath);
  MakeDir (Config.QwkPath);
	MakeDir (Config.SystemPath + 'files');
	MakeDir (Config.SystemPath + 'files' + PathChar + 'uploads');
End;

Procedure ExtractFile (Y : Byte; Desc, FN, EID, DestPath : String);
Begin
  Screen.WriteXYPipe (23, Y, 7, 45, Desc);

	If Not maOpenExtract (FN, EID, DestPath) Then
		ShowError('Unable to find ' + FN + '.mys');

	While maNextFile Do
		If Not maExtractFile Then
			ShowError ('Unable to extract file (disk full?)');

	maCloseFile;
End;

Procedure UpdateDataFiles;
Var
	CfgFile 	: File of RecConfig;
	MBaseFile : File of RecMessageBase;
	FBaseFile : File of RecFileBase;
	LangFile	: File of RecTheme;
	Cfg 			: RecConfig;
	MBase 		: RecMessageBase;
	FBase 		: RecFileBase;
	TLang 		: RecTheme;
Begin
  Screen.WriteXYPipe (23, 19, 7, 45, '|08[|15û|08] |07Updating data files|08...');

	Assign (CfgFile, Config.SystemPath + 'mystic.dat');
	Reset  (CfgFile);
	Read	 (CfgFile, Cfg);

  Cfg.DataChanged := mysDataChanged;
	Cfg.SystemPath  := Config.SystemPath;
	Cfg.AttachPath  := Config.AttachPath;
	Cfg.DataPath	  := Config.DataPath;
	Cfg.MsgsPath	  := Config.MsgsPath;
	Cfg.SemaPath	  := Config.SemaPath;
	Cfg.QwkPath 	  := Config.QwkPath;
	Cfg.ScriptPath  := Config.ScriptPath;
	Cfg.LogsPath	  := Config.LogsPath;
  Cfg.MenuPath    := Lang.MenuPath;
  Cfg.TextPath    := Lang.TextPath;
	Cfg.UserIdxPos  := 0;
  Cfg.SystemCalls := 0;

	Reset (CfgFile);
	Write (CfgFile, Cfg);
	Close (CfgFile);

	Assign (MBaseFile, Config.DataPath + 'mbases.dat');
	Reset  (MBaseFile);

	While Not Eof(MBaseFile) Do Begin
		Read (MBaseFile, MBase);

		MBase.Path := Config.MsgsPath;

		Seek	(MBaseFile, FilePos(MBaseFile) - 1);
		Write (MBaseFile, MBase);
	End;

	Close (MBaseFile);

	Assign (FBaseFile, Config.DataPath + 'fbases.dat');
	Reset  (FBaseFile);

	While Not Eof(FBaseFile) Do Begin
		Read (FBaseFile, FBase);

    FBase.Path := Config.SystemPath + 'files' + PathChar + FBase.FileName + PathChar;

		Seek	(FBaseFile, FilePos(FBaseFile) - 1);
		Write (FBaseFile, FBase);
	End;
	Close (FBaseFile);

	Assign (LangFile, Config.DataPath + 'theme.dat');
	Reset  (LangFile);

	While Not Eof(LangFile) Do Begin
		Read (LangFile, TLang);

    TLang.FileName     := 'default';
		TLang.TextPath     := Lang.TextPath;
		TLang.MenuPath     := Lang.MenuPath;
    TLang.TemplatePath := Lang.TextPath;
    TLang.ScriptPath   := Config.ScriptPath;

		Seek	(LangFile, FilePos(LangFile) - 1);
		Write (LangFile, TLang);
	End;

	Close (LangFile);

	CompileLanguageFile;
End;

Procedure DoInstall;
Begin
	ClearDisplay;
	CreateDirectories;

  ExtractFile (14, '|08[|15û|08] |07Installing root files|08...',    'install_data', 'ROOT',   Config.SystemPath);
	ExtractFile (15, '|08[|15û|08] |07Installing display files|08...', 'install_data', 'TEXT',   Lang.TextPath);
	ExtractFile (16, '|08[|15û|08] |07Installing menu files|08...',    'install_data', 'MENUS',  Lang.MenuPath);
	ExtractFile (17, '|08[|15û|08] |07Installing script files|08...',  'install_data', 'SCRIPT', Config.ScriptPath);
	ExtractFile (18, '|08[|15û|08] |07Installing data files|08...',    'install_data', 'DATA',   Config.DataPath);

	UpdateDataFiles;

  Screen.WriteXY (23, 21, 11, 'Installation completed.  Press any key.');
	Keys.ReadKey;

  Clear_Screen;
  Screen.WriteLine ('Switch to the Mystic directory (' + Config.SystemPath + ') and then:');
  Screen.WriteLine('');
  {$IFDEF WINDOWS}
    Screen.WriteLine ('Type "MYSTIC" to run Mystic in local mode');
    Screen.WriteLine ('Type "MYSTIC -CFG" to run the configuration utility');
    Screen.WriteLine('');
    Screen.WriteLine ('As always, read the documentation!');
  {$ENDIF}
  {$IFDEF LINUX}
    Screen.WriteLine ('Please read linux.install.doc for installation instructions');
    Screen.WriteLine ('and notes on using Mystic under Linux');
    Screen.WriteLine('');
    Screen.WriteLine ('Set your terminal to 80x25 lines with an IBM characterset font!');
    Screen.WriteLine('');
    Screen.WriteLine ('Type "./mystic" from the installed directory to login locally');
    Screen.WriteLine ('Type "./mystic -cfg" to run the configuration utility');
  {$ENDIF}
  {$IFDEF DARWIN}
    Screen.WriteLine ('Please read osx.install.doc for installation instructions');
    Screen.WriteLine ('and notes on using Mystic under OSX');
    Screen.WriteLine('');
    Screen.WriteLine ('Set your terminal to 80x25 lines with an IBM characterset font!');
    Screen.WriteLine ('See documentation for more terminal suggestions!');
    Screen.WriteLine('');
    Screen.WriteLine ('Type "./mystic" from the installed directory to login locally');
    Screen.WriteLine ('Type "./mystic -cfg" to run the configuration utility');
  {$ENDIF}

  Screen.WriteLine('');
  Screen.WriteStr('Press any key to close');

  Keys.ReadKey;

  ChDIR(Copy(Config.SystemPath, 1, Length(Config.SystemPath) - 1));

  Screen.Free;
  Keys.Free;
  Halt;
End;

Function GetPaths : Boolean;
Var
	Str : String;

	Function Change (NewStr : String) : String;
	Var
		A : Byte;
	Begin
                A := Pos(Config.SystemPath, NewStr);
		If A > 0 Then Begin
                        Delete (NewStr, A, Length(Config.SystemPath));
			Insert (Str, NewStr, A);
		End;
		Change := NewStr;
	End;

Var
	Pos : Byte;
Begin
	ClearDisplay;

  Screen.WriteXY (13, 13, 7, 'System Directory');
  Screen.WriteXY (15, 14, 7, 'Data Directory');
  Screen.WriteXY (15, 15, 7, 'Text Directory');
  Screen.WriteXY (15, 16, 7, 'Menu Directory');
  Screen.WriteXY (11, 17, 7, 'Msg Base Directory');
  Screen.WriteXY (10, 18, 7, 'Semaphore Directory');
  Screen.WriteXY (13, 19, 7, 'Script Directory');
  Screen.WriteXY (13, 20, 7, 'Attach Directory');
  Screen.WriteXY (15, 21, 7, 'Logs Directory');

  Screen.WriteXYPipe (19, 23, 7, 64, 'Press |08[|15F2|08] |07to begin install or |08[|15ESC|08] |07to Quit');

	Pos := 1;

	{$IFDEF UNIX}
    Config.SystemPath := '/mystic/';
  {$ELSE}
    Config.SystemPath := 'c:\mystic\';
  {$ENDIF}

  Config.DataPath   := Config.SystemPath + 'data' + PathChar;
  Lang.TextPath     := Config.SystemPath + 'text' + PathChar;
  Lang.MenuPath     := Config.SystemPath + 'menus' + PathChar;
  Config.MsgsPath   := Config.SystemPath + 'msgs' + PathChar;
  Config.SemaPath   := Config.SystemPath + 'semaphore' + PathChar;
  Config.ScriptPath := Config.SystemPath + 'scripts' + PathChar;
  Config.AttachPath := Config.SystemPath + 'attach' + PathChar;
  Config.LogsPath   := Config.SystemPath + 'logs' + PathChar;

	Repeat
    Screen.WriteXY (30, 13, 15, strPadR(Config.SystemPath,    40, ' '));
    Screen.WriteXY (30, 14, 15, strPadR(Config.DataPath,   40, ' '));
    Screen.WriteXY (30, 15, 15, strPadR(Lang.TextPath,     40, ' '));
    Screen.WriteXY (30, 16, 15, strPadR(Lang.MenuPath,     40, ' '));
    Screen.WriteXY (30, 17, 15, strPadR(Config.MsgsPath,   40, ' '));
    Screen.WriteXY (30, 18, 15, strPadR(Config.SemaPath,   40, ' '));
    Screen.WriteXY (30, 19, 15, strPadR(Config.ScriptPath, 40, ' '));
    Screen.WriteXY (30, 20, 15, strPadR(Config.AttachPath, 40, ' '));
    Screen.WriteXY (30, 21, 15, strPadR(Config.LogsPath,   40, ' '));

		Case Pos of
			1 : Begin
            Str := Path(Input(30, 13, 40, 40, Config.SystemPath));

            If Str <> Config.SystemPath Then Begin
							Config.DataPath 	:= Change(Config.DataPath);
							Lang.TextPath 		:= Change(Lang.TextPath);
							Lang.MenuPath 		:= Change(Lang.MenuPath);
							Config.MsgsPath 	:= Change(Config.MsgsPath);
              Config.SemaPath   := Change(Config.SemaPath);
							Config.ScriptPath := Change(Config.ScriptPath);
							Config.AttachPath := Change(Config.AttachPath);
							Config.LogsPath 	:= Change(Config.LogsPath);
              Config.SystemPath := Str;
						End;
					End;
			2 : Config.DataPath 	:= Path(Input(30, 14, 40, 40, Config.DataPath));
			3 : Lang.TextPath 		:= Path(Input(30, 15, 40, 40, Lang.TextPath));
			4 : Lang.MenuPath 		:= Path(Input(30, 16, 40, 40, Lang.MenuPath));
			5 : Config.MsgsPath 	:= Path(Input(30, 17, 40, 40, Config.MsgsPath));
      6 : Config.SemaPath   := Path(Input(30, 18, 40, 40, Config.SemaPath));
			7 : Config.ScriptPath := Path(Input(30, 19, 40, 40, Config.ScriptPath));
			8 : Config.AttachPath := Path(Input(30, 20, 40, 40, Config.AttachPath));
			9 : Config.LogsPath 	:= Path(Input(30, 21, 40, 40, Config.LogsPath));
		End;

		Case Code of
			#19 : Begin
							GetPaths := True;
							Break;
						End;
			#27 : Begin
							GetPaths := False;
							Break;
						End;
			#60 : Begin
							GetPaths := True;
              Break;
						End;
			#72 : If Pos > 1 Then Dec(Pos) Else Pos := 9;
			#80 : If Pos < 9 Then Inc(Pos) Else Pos := 1;
		End;
	Until False;

  { update paths not on the list }

  Config.QwkPath := Config.SystemPath + 'localqwk' + PathChar;
End;

Const
	Items : Array[1..3] of String[32] = (
						'     %  INSTALL MYSTIC BBS     ',
						'     %  READ WHATS NEW         ',
						'     %  ABORT INSTALLATION     '
					);

Var
	Pos : Byte;
	A 	: Byte;
Begin
  Screen := TOutput.Create(True);
  Keys   := TInput.Create;

	DrawMainMenu;

	Pos := 2;

	Repeat
		For A := 1 to 3 Do
			If A = Pos Then
        Screen.WriteXY (25, 16 + A, 15 + 3 * 16, Items[A])
			Else
        Screen.WriteXY (25, 16 + A,  7, Items[A]);

		Case Keys.ReadKey of
			#00 : Case Keys.ReadKey of
							#72 : If Pos > 1 Then Dec(Pos);
							#80 : If Pos < 3 THen Inc(Pos);
						End;
			#13 : Case Pos of
							1 : Begin
										If GetPaths Then
											DoInstall
										Else
											DrawMainMenu;
									End;
							2 : Begin
										ViewTextFile('whatsnew.txt');
										DrawMainMenu;
									End;
							3 : Break;
						End;

			#27 : Break;
		End;
	Until False;

	Clear_Screen;

  Keys.Free;
  Screen.Free;
End.

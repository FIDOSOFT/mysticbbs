Unit bbs_cfg_menuedit;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  m_Strings,
  m_FileIO,
  bbs_Common,
  bbs_Core,
  bbs_User,
  bbs_Menus;

Procedure Menu_Editor;

Implementation

Var
	MenuFile : Text;

Procedure Menu_Editor;

Procedure ModifyMenu;
var a,b{,c} : byte;
{ tempcmd : menucmdrec;}
Begin
  Session.io.OutRaw ('Menu to Edit: ');
  Session.Menu.MenuName := Session.io.GetInput(mysMaxMenuNameLen, mysMaxMenuNameLen, 11, '');

	If Session.Menu.LoadMenu(False, False, False) <> 1 Then Exit;

	Repeat
    Session.io.OutFullLn ('|CL|14Menu Command List|CR|03');
    Session.io.OutFullLn ('|15## Hot-Key  Cmd Text                   ## Hot-Key  Cmd Text');
    Session.io.OutFullLn ('|09-- -------- --- ---------------------  -- -------- --- ---------------------|03');

		For A := 1 to Session.Menu.CmdNum Do Begin
      Session.io.OutRaw (strPadR(strI2S(A), 3, ' ') + strPadR(Session.Menu.MenuList[A].HotKey, 9, ' ') +
							strPadR(Session.Menu.MenuList[A].Command, 4, ' ') + strPadR(Session.Menu.MenuList[A].Text, 21, ' ') + '  ');
      If (A = Session.Menu.CmdNum) or (A Mod 2 = 0) Then Session.io.OutRawLn('');
		End;

    Session.io.OutFull ('|CR|09(E)dit, (I)nsert, (D)elete, (F)lags, (V)iew, (Q)uit: ');
		Case Session.io.OneKey('EIDFVQ', True) of
			'D' : begin
              Session.io.OutRaw('Delete which? ');
              a := strS2I(Session.io.GetInput(2, 2, 11, ''));
							if (a > 0) and (a <= Session.Menu.CmdNum) then begin
								for b := a to Session.Menu.CmdNum do
									Session.Menu.Menulist[b] := Session.Menu.Menulist[b+1];
								dec (Session.Menu.cmdnum);
							end;
						end;
			'I' : if Session.Menu.CmdNum < mysMaxMenuCmds Then Begin
                Session.io.OutRaw ('Insert before which (1-' + strI2S(Session.Menu.CmdNum + 1) + '): ');
                A := strS2I(Session.io.GetInput(2, 2, 11, ''));
								If (A > 0) And (A <= Session.Menu.CmdNum + 1) Then Begin
									Inc (Session.Menu.CmdNum);
									For B := Session.Menu.CmdNum DownTo A + 1 Do
										Session.Menu.MenuList[B] := Session.Menu.MenuList[B - 1];
									Session.Menu.MenuList[A].Text		 := '[XXX] New Command';
									Session.Menu.MenuList[A].HotKey	 := 'XXX';
								  Session.Menu.MenuList[A].LongKey  := 'XXX';
								  Session.Menu.MenuList[A].ACS 		 := '';
								  Session.Menu.MenuList[A].Command  := '';
								  Session.Menu.MenuList[A].X 			 := 0;
								  Session.Menu.MenuList[A].Y 			 := 0;
								  Session.Menu.MenuList[A].lText 	 := '';
								  Session.Menu.MenuList[A].lhText	 := '';
								End;
						End;
			'F' : Begin
							repeat
                Session.io.OutFullLn ('|CL|14Menu Flags (' + Session.Menu.MenuName + ')|CR|03');
                Session.io.OutRawLn ('A. Menu Header   : ' + strPadR(Session.Menu.Menu.header, 59, ' '));
                Session.io.OutRawLn ('B. Menu Prompt   : ' + strPadR(Session.Menu.menu.prompt, 59, ' '));
                Session.io.OutRawLn ('C. Display Cols  : ' + strI2S(Session.Menu.Menu.DispCols));
                Session.io.OutRawLn ('D. ACS           : ' + Session.Menu.menu.acs);
                Session.io.OutRawLn ('E. Password      : ' + Session.Menu.menu.password);
                Session.io.OutRawLn ('F. Display File  : ' + Session.Menu.Menu.TextFile);
                Session.io.OutRawLn ('G. Fallback Menu : ' + Session.Menu.Menu.Fallback);
                Session.io.OutRaw   ('H. Menu Type     : ');

								Case Session.Menu.Menu.MenuType of
                  0 : Session.io.OutRawLn ('Standard');
                  1 : Session.io.OutRawLn ('Lightbar');
                  2 : Session.io.OutRawLn ('Lightbar Grid');
								End;

                Session.io.OutRawLn ('I. Finish X/Y    : ' + strPadR(strI2S(Session.Menu.menu.donex), 3, ' ') + strI2S(Session.Menu.menu.doney));
                Session.io.OutRawLn ('J. Use Global MNU: ' + Session.io.OutYN(Session.Menu.Menu.Global=1));
                Session.io.OutRaw   ('K. Input Type    : ');

								Case Session.Menu.Menu.InputType of
                  0 : Session.io.OutRawLn ('User setting');
                  1 : Session.io.OutRawLn ('Hotkey');
                  2 : Session.io.OutRawLn ('Longkey');
								End;

                Session.io.OutFull ('|CR|09(V)iew or (Q)uit: ');
								Case Session.io.OneKey('ABCDEFGHIJKQV', True) of
                  'A' : Session.Menu.Menu.Header   := Session.io.InXY(20, 3, 60, 255, 11, Session.Menu.Menu.Header);
                  'B' : Session.Menu.Menu.Prompt   := Session.io.InXY(20, 4, 60, 255, 11, Session.Menu.Menu.Prompt);
									'C' : Begin
                          Session.Menu.Menu.DispCols := strS2I(Session.io.InXY(20, 5, 1, 1, 12, strI2S(Session.Menu.Menu.DispCols)));
                          If Session.Menu.Menu.DispCols < 1 Then Session.Menu.Menu.DispCols := 1;
                          If Session.Menu.Menu.DispCols > 3 Then Session.Menu.Menu.DispCols := 3;
												End;
                  'D' : Session.Menu.Menu.ACS      := Session.io.InXY(20, 6, 20, 20, 11, Session.Menu.Menu.ACS);
                  'E' : Session.Menu.Menu.Password := Session.io.InXY(20, 7, 15, 15, 12, Session.Menu.Menu.Password);
                  'F' : Session.Menu.Menu.TextFile := Session.io.InXY(20, 8, 20, 20, 11, Session.Menu.Menu.TextFile);
                  'G' : Session.Menu.Menu.Fallback := Session.io.InXY(20, 9, mysMaxMenuNameLen, mysMaxMenuNameLen, 11, Session.Menu.Menu.Fallback);
                  'H' : If Session.Menu.Menu.MenuType = 2 Then Session.Menu.Menu.MenuType := 0 Else Inc(Session.Menu.Menu.MenuType);
									'I' : Begin
                          Session.Menu.Menu.donex := strS2I(Session.io.InXY(20, 11, 2, 2, 12, strI2S(Session.Menu.Menu.donex)));
                          Session.Menu.Menu.doney := strS2I(Session.io.InXY(23, 11, 2, 2, 12, strI2S(Session.Menu.Menu.doney)));
												End;
                  'J' : If Session.Menu.Menu.Global = 1 Then dec(Session.Menu.Menu.global) else Session.Menu.Menu.global := 1;
                  'K' : If Session.Menu.Menu.InputType = 2 Then Session.Menu.Menu.InputType := 0 Else Inc(Session.Menu.Menu.InputType);
									'Q' : Break;
                  'V' : Session.Menu.ExecuteMenu (False, False, True);
								End;
							Until False;
						End;
			'E' : Begin
              Session.io.OutRaw ('Edit which? ');
              a := strS2I(Session.io.GetInput(2, 2, 11, ''));
              If (a > 0) and (a <= Session.Menu.CmdNum) then Begin
								Repeat
                  Session.io.OutFullLn ('|CL|14Menu command ' + strI2S(a) + ' of ' + strI2S(Session.Menu.CmdNum) + '|CR|03');
                  Session.io.OutRawln ('A. Text    : ' + Session.Menu.MenuList[A].text);
                  Session.io.OutRawln ('B. Hot Key : ' + Session.Menu.MenuList[A].HotKey);
                  Session.io.OutRawLn ('C. Long Key: ' + Session.Menu.MenuList[A].LongKey);
                  Session.io.OutRawln ('D. ACS     : ' + Session.Menu.MenuList[A].acs);
                  Session.io.OutRawln ('E. Command : ' + Session.Menu.MenuList[A].command);
                  Session.io.OutRawln ('F. Data    : ' + Session.Menu.MenuList[A].data);
                  Session.io.OutFullLn ('|CRG. Lightbar X/Y  : ' + strPadR(strI2S(Session.Menu.MenuList[a].x), 3, ' ') + strI2S(Session.Menu.MenuList[a].y));
                  Session.io.OutRawln ('H. Lightbar Text : ' + Session.Menu.MenuList[a].ltext);
                  Session.io.OutRawln ('I. Lightbar High : ' + Session.Menu.MenuList[a].lhtext);
                  Session.io.OutRawln ('');
                  Session.io.OutRawln ('J. Lightbar Up   : ' + strI2S(Session.Menu.MenuList[a].cUP));
                  Session.io.OutRawln ('K. Lightbar Down : ' + strI2S(Session.Menu.MenuList[a].cDOWN));
                  Session.io.OutRawln ('L. Lightbar Left : ' + strI2S(Session.Menu.MenuList[a].cLEFT));
                  Session.io.OutRawln ('M. Lightbar Right: ' + strI2S(Session.Menu.MenuList[a].cRIGHT));

                  Session.io.OutFull ('|CR|09([) Previous, (]) Next, (Q)uit: ');
									case session.io.onekey('[]ABCDEFGHIJKLMQ', True) of
										'[' : If A > 1 Then Dec(A);
                    ']' : If A < Session.Menu.CmdNum Then Inc(A);
                    'A' : Session.Menu.MenuList[A].Text    := Session.io.InXY(14, 3, 60, 79, 11, Session.Menu.MenuList[A].Text);
                    'B' : Session.Menu.MenuList[A].HotKey  := Session.io.InXY(14, 4,  8,  8, 12, Session.Menu.MenuList[A].HotKey);
                    'C' : Session.Menu.MenuList[A].LongKey := Session.io.InXY(14, 5,  8,  8, 12, Session.Menu.MenuList[A].LongKey);
                    'D' : Session.Menu.MenuList[A].ACS     := Session.io.InXY(14, 6, 20, 20, 11, Session.Menu.MenuList[A].ACS);
										'E' : Repeat
                            Session.io.OutFull ('|09Menu Command (?/List): ');
                            Session.Menu.MenuList[A].command := Session.io.GetInput(2, 2, 12, '');
                            If Session.Menu.MenuList[A].Command = '?' Then
															session.io.OutFile ('menucmds', True, 0)
														Else
															Break;
													Until False;
                    'F' : Session.Menu.MenuList[A].Data := Session.io.InXY(14, 8, 60, 79, 11, Session.Menu.MenuList[a].data);
										'G' : Begin
                            Session.Menu.MenuList[A].X := strS2I(Session.io.InXY(20, 10, 2, 2, 12, strI2S(Session.Menu.MenuList[A].X)));
                            Session.Menu.MenuList[A].Y := strS2I(Session.io.InXY(23, 10, 2, 2, 12, strI2S(Session.Menu.MenuList[A].Y)));
													End;
                    'H' : Session.Menu.MenuList[A].LText  := Session.io.InXY(20, 11, 59, 79, 11, Session.Menu.MenuList[A].LText);
                    'I' : Session.Menu.MenuList[A].LHText := Session.io.InXY(20, 12, 59, 79, 11, Session.Menu.MenuList[A].LHText);
                    'J' : Session.Menu.MenuList[A].cUP    := strS2I(Session.io.InXY(20, 14,  2,  2, 12, strI2S(Session.Menu.MenuList[A].cUP)));
                    'K' : Session.Menu.MenuList[A].cDOWN  := strS2I(Session.io.InXY(20, 15,  2,  2, 12, strI2S(Session.Menu.MenuList[A].cDOWN)));
                    'L' : Session.Menu.MenuList[A].cLEFT  := strS2I(Session.io.InXY(20, 16,  2,  2, 12, strI2S(Session.Menu.MenuList[A].cLEFT)));
                    'M' : Session.Menu.MenuList[A].cRIGHT := strS2I(Session.io.InXY(20, 17,  2,  2, 12, strI2S(Session.Menu.MenuList[A].cRIGHT)));
										'Q' : Break;
									end;
								until false;
							End;
						End;
(*
			'P' : begin
              Session.io.OutRaw('Move which? ');
              a := strS2I(Session.io.GetInput(2, 2, 11, ''));
              Session.io.OutRaw('Move before which (1-' + strI2S(Session.Menu.CmdNum+1) + '): ');
              b := strS2I(Session.io.GetInput(2, 2, 11, ''));
						end;
*)
			'Q' : break;
      'V' : Session.Menu.ExecuteMenu(False, False, True);

		end;
	Until false;

  Session.io.OutFullLn ('|14Saving...');
	assign (menufile, Session.Theme.menupath + Session.Menu.menuname + '.mnu');
	rewrite (menufile);
  writeln (menufile, Session.Menu.Menu.header);
  writeln (menufile, Session.Menu.Menu.prompt);
  writeln (menufile, Session.Menu.Menu.dispcols);
  writeln (menufile, Session.Menu.Menu.acs);
  writeln (menufile, Session.Menu.Menu.password);
  writeln (menufile, Session.Menu.Menu.textfile);
  WriteLn (MenuFile, Session.Menu.Menu.Fallback);
  writeln (menufile, Session.Menu.Menu.MenuType);
  WriteLn (MenuFile, Session.Menu.Menu.InputType);
  WriteLn (MenuFile, Session.Menu.Menu.DoneX);
  WriteLn (MenuFile, Session.Menu.Menu.DoneY);
  WriteLn (MenuFile, Session.Menu.Menu.Global);
  for a := 1 to Session.Menu.CmdNum do begin
    writeln (menufile, Session.Menu.MenuList[a].text);
    writeln (menufile, Session.Menu.MenuList[a].HotKey);
    WriteLn (MenuFile, Session.Menu.MenuList[A].LongKey);
    writeln (menufile, Session.Menu.MenuList[a].acs);
    writeln (menufile, Session.Menu.MenuList[a].command);
    writeln (menufile, Session.Menu.MenuList[a].data);
    writeln (menufile, Session.Menu.MenuList[a].x);
    writeln (menufile, Session.Menu.MenuList[a].y);
    writeln (menufile, Session.Menu.MenuList[a].cUP);
    WriteLn (MenuFile, Session.Menu.MenuList[A].cDOWN);
    WriteLn (MenuFile, Session.Menu.MenuList[A].cLEFT);
    WriteLn (MenuFile, Session.Menu.MenuList[A].cRIGHT);
    writeln (menufile, Session.Menu.MenuList[a].ltext);
    writeln (menufile, Session.Menu.MenuList[a].lhtext);
	end;
	close (menufile);
End;

Var
	Old : String[8];
	OldLang : RecTheme;
	DirInfo: SearchRec;
	A : Byte; {format dir output}
Begin
  If session.Theme.filename = '' then exit;

	Old 		:= Session.Menu.MenuName;
	OldLang := Session.Theme;
	Session.SystemLog ('*MENU EDITOR*');

  Session.io.OutFull ('|CL');
	Session.User.GetLanguage;

	Repeat
    Session.io.OutFullLn ('|CL|14Menu Editor (Language: ' + Session.Theme.Desc + ')|CR');
    Session.io.OutFullLn ('|08Directory of ' + Session.Theme.MenuPath + '*.MNU|CR|03');

		a := 0;
		FindFirst (Session.Theme.MenuPath + '*.mnu', Archive, DirInfo);
		While DosError = 0 Do Begin
			inc (a);
      Session.io.OutRaw (strPadR(DirInfo.Name, 25, ' '));
			FindNext (DirInfo);
			if (a = 3) or (DosError <> 0) then begin
        Session.io.OutRawln('');
				a := 0
			end;

		End;

    Session.io.OutFull ('|CR|09(E)dit, (I)nsert, (D)elete, (Q)uit? ');
		Case session.io.OneKey('EIDQ', True) of
			'E' : ModifyMenu;
			'I' : Begin;
              Session.io.OutRaw ('Menu Name: ');
              Session.menu.MenuName := Session.io.GetInput(mysMaxMenuNameLen, mysMaxMenuNameLen, 11, '');
							If Session.Menu.MenuName <> '' Then Begin
								Assign (MenuFile, Session.Theme.MenuPath + Session.Menu.MenuName + '.mnu');
								{$I-} Reset(MenuFile); {$I+}
								If IoResult = 0 Then
                  Session.io.OutRawLn ('Menu already exists')
								Else Begin
									Rewrite (MenuFile);
									WriteLn (MenuFile, 'New Menu');
									WriteLn (MenuFile, 'Command: ');
									WriteLn (MenuFile, '2');
									WriteLn (MenuFile, '');
									WriteLn (MenuFile, '');
									WriteLn (MenuFile, '');
                  WriteLn (MenuFile, 'main');
                  WriteLn (MenuFile, '0');
									WriteLn (MenuFile, '0');
									WriteLn (MenuFile, '0');
									WriteLn (MenuFile, '0');
									WriteLn (MenuFile, '1');
									Close (MenuFile);
								End;
							End;
						End;
			'D' : Begin
              Session.io.OutRaw ('Menu to delete: ');
              Session.Menu.MenuName := Session.io.GetInput(mysMaxMenuNameLen, mysMaxMenuNameLen, 11, '');
							FileErase(Session.Theme.MenuPath + Session.Menu.MenuName + '.mnu');
						End;
			'Q' : Break;
		End;
	Until False;
	Session.Menu.MenuName := Old;
	Session.Theme := OldLang;
	Close (Session.PromptFile);
	Assign (Session.PromptFile, Config.DataPath + Session.Theme.FileName + '.thm');
	Reset (Session.PromptFile);
End;

End.

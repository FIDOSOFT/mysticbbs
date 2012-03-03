Unit bbs_cfg_Language;

{$I M_OPS.PAS}

Interface

Procedure Lang_Editor;

Implementation

Uses
  m_Strings,
  bbs_Common,
  bbs_Core;

Procedure Lang_Editor;
var
	a   : SmallInt;
  Old : RecTheme;
Begin
	Session.SystemLog ('*LANG EDITOR*');
	Old := Session.Lang;
{	Reset (LangFile);}
	Repeat
    Session.io.OutFullLn ('|CL|14Language Editor|CR|CR|15##  FileName  Description|CR|09--  --------  ------------------------------');
    Reset (Session.LangFile);
    while not eof(Session.LangFile) do begin
      read (Session.LangFile, Session.Lang);
      Session.io.OutFullLn ('|15' + strPadR(strI2S(filepos(Session.LangFile)), 4, ' ') +
							'|14' + strPadR(Session.Lang.FileName, 10, ' ') + '|10' + Session.Lang.Desc);
		end;
		Session.Lang := Old;
    Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (Q)uit? ');
		case Session.io.OneKey ('DIEQ', True) of
			'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if filesize(Session.LangFile) = 1 then
                Session.io.OutFullLn ('|CR|14You must have at least one language definition.|CR|PA')
							Else
                KillRecord (Session.LangFile, A, SizeOf(RecTheme));
      			end;
			'I' : begin
              Session.io.OutRaw ('Insert before? (1-' + strI2S(filesize(Session.LangFile)+1) + '): ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.LangFile)+1) then begin
                AddRecord (Session.LangFile, A, SizeOf(RecTheme));
								Session.lang.filename := '';
								Session.lang.textpath := '';
								Session.lang.menupath := '';
                write (Session.LangFile, Session.Lang);
							end;
      			end;
			'E' : begin
              Session.io.OutRaw ('Edit which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.LangFile)) then begin
                seek (Session.LangFile, a-1);
                read (Session.LangFile, Session.Lang);
								repeat
                  Session.io.OutFullLn ('|CL|14Language ' + strI2S(FilePos(Session.LangFile)) + ' of ' + strI2S(FileSize(Session.LangFile)) + '|CR|03');
                  Session.io.OutRawln ('A. Description: ' + Session.Lang.Desc);
                  Session.io.OutRawln ('B. Filename   : ' + Session.Lang.FileName);
                  Session.io.OutRawln ('C. Text Path  : ' + Session.Lang.TextPath);
                  Session.io.OutRawln ('D. Menu Path  : ' + Session.Lang.MenuPath);
                  Session.io.OutRawln ('M. Allow ASCII: ' + Session.io.OutYN(Session.Lang.Flags AND ThmAllowASCII <> 0));
                  Session.io.OutRawln ('N. Allow ANSI : ' + Session.io.OutYN(Session.Lang.Flags AND ThmAllowANSI <> 0));

                  Session.io.OutFullLn ('|CRE. Use Lightbar Y/N : ' + Session.io.OutYN(Session.Lang.Flags AND ThmLightbarYN <> 0));
                  Session.io.OutFull   ('|03|16H. Input Field Color: ');
                  Session.io.AnsiColor(Session.Lang.FieldColor1);
                  Session.io.OutFullLn ('Test|03|16');

                  Session.io.OutRaw ('I. Quote Bar Color  : ');
                  Session.io.AnsiColor(Session.Lang.QuoteColor);
                  Session.io.OutFullLn ('Test|03|16');

                  Session.io.OutRawLn ('J. Echo Character   : ' + Session.Lang.EchoChar);
                  Session.io.OutRawLn ('K. Input Character  : ' + Session.Lang.FieldChar);
                  Session.io.OutRawLn ('L. File Tag Char    : ' + Session.Lang.TagChar);

                  Session.io.OutRaw   ('O. File Search Hi   : ');
                  Session.io.AnsiColor(Session.Lang.FileDescHI);
                  Session.io.OutFullLn ('Test|03|16');

                  Session.io.OutRaw   ('P. File Desc. Lo    : ');
                  Session.io.AnsiColor(Session.Lang.FileDescLO);
                  Session.io.OutFullLn ('Test|03|16');

                  Session.io.OutRawLn ('R. LB New Msg Char  : ' + Session.Lang.NewMsgChar);

                  Session.io.OutFull ('|CR|09Command (Q/Quit): ');
									case Session.io.onekey('ABCDEFGHIJKLMNOPQR', True) of
                    'A' : Session.Lang.Desc       := Session.io.InXY(17, 3, 30, 30, 11, Session.Lang.Desc);
                    'B' : Session.Lang.filename   := Session.io.InXY(17, 4,  8,  8, 11, Session.Lang.filename);
                    'C' : Session.Lang.textpath   := CheckPath(Session.io.InXY(17, 5, 40, 40, 11, Session.Lang.textpath));
                    'D' : Session.Lang.menupath   := CheckPath(Session.io.InXY(17, 6, 40, 40, 11, Session.Lang.MenuPath));
                    'E' : Session.Lang.Flags      := Session.Lang.Flags XOR ThmLightbarYN;
                    'H' : Session.Lang.FieldColor1  := getColor(Session.Lang.FieldColor1);
										'I' : Session.Lang.QuoteColor := getColor(Session.Lang.QuoteColor);
                    'J' : Begin Session.io.OutRaw ('Char: '); Session.Lang.EchoChar := Session.io.GetKey; End;
										'K' : Begin
                            Session.io.OutRaw ('Char: ');
                            Session.Lang.FieldChar := Session.io.GetKey;
                            If Not (Session.Lang.FieldChar in [#32..#255]) Then
                              Session.Lang.FieldChar := ' ';
													End;
                    'L' : Begin Session.io.OutRaw ('Char: '); Session.Lang.TagChar   := Session.io.GetKey; End;
                    'M' : Session.Lang.Flags := Session.Lang.Flags XOR ThmAllowASCII;
                    'N' : Session.Lang.Flags := Session.Lang.Flags XOR ThmAllowANSI;
                    'O' : Session.Lang.FileDescHI := getColor(Session.Lang.FileDescHI);
                    'P' : Session.Lang.FileDescLo := GetColor(Session.Lang.FileDescLO);
										'Q' : break;
                    'R' : Begin Session.io.OutRaw('Char: '); Session.Lang.NewMsgChar := Session.io.GetKey; End;
									end;
								until false;
                seek (Session.LangFile, filepos(Session.LangFile)-1);
                write (Session.LangFile, Session.Lang);
							end;
						end;
			'Q' : break;
		end;

	until False;
  close (Session.LangFile);

	If Not Session.LoadThemeData(Old.FileName) Then Session.Lang := Old;
End;

End.

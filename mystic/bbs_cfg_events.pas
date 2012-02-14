Unit bbs_cfg_Events;

{$I M_OPS.PAS}

Interface

Procedure Event_Editor;

Implementation

Uses
  m_Strings,
  m_DateTime,
  bbs_Core,
  bbs_Common,
  bbs_User;

Procedure Event_Editor;
Var
	A, B : Integer;
Begin
	Session.SystemLog ('*EVENT EDITOR*');

  Assign (Session.EventFile, Config.DataPath + 'events.dat');
  Reset (Session.EventFile);
	Repeat
    Session.io.OutFullLn ('|CL|14Event Editor|CR|CR|09###  Name|CR---  ------------------------------  -----|14');
    Reset (Session.EventFile);
    While Not Eof(Session.EventFile) do begin
      read (Session.EventFile, session.event);
      if session.event.active then Session.io.BufAddChar('+') else Session.io.BufAddChar('-');
      Session.io.OutFullLn ('|15' + strPadR(strI2S(filepos(Session.EventFile)), 4, ' ') + '|14' + strPadR(session.event.name, 32, ' ') +
      strZero(session.event.exectime div 60) + ':' + strZero(session.event.exectime mod 60));
		end;
    Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (Q)uit? ');
    case Session.io.OneKey ('DIEQ', True) of
			'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              KillRecord (Session.EventFile, A, SizeOf(EventRec));
      			end;
			'I' : begin
              Session.io.OutRaw ('Insert before? (1-' + strI2S(filesize(Session.EventFile)+1) + '): ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.EventFile)+1) then begin
                AddRecord (Session.EventFile, A, SizeOf(EventRec));
								session.event.active   := false;
                Session.Event.Name     := 'New Event';
                Session.Event.errlevel := 0;
                Session.Event.exectime := 0;
                Session.Event.warning  := 0;
                Session.Event.lastran  := 0;
                Session.Event.offhook  := false;
                Session.Event.node     := 0;
                write (Session.EventFile, Session.event);
							end;
      			end;
			'E' : begin
              Session.io.OutRaw ('Edit which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.EventFile)) then begin
                seek (Session.EventFile, a-1);
                read (Session.EventFile, Session.event);
								repeat
                  Session.io.OutFullLn ('|CL|14Event ' + strI2S(FilePos(Session.EventFile)) + ' of ' + strI2S(FileSize(Session.EventFile)) + '|CR|03');
                  Session.io.OutRawln ('!. Active         : ' + Session.io.OutYN(Session.Event.active));
                  Session.io.OutRawln ('A. Description    : ' + Session.Event.Name);
                  Session.io.OutRawln ('B. Forced         : ' + Session.io.OutYN(Session.Event.forced));
                  Session.io.OutRawln ('C. Errorlevel     : ' + strI2S(Session.Event.ErrLevel));
                  Session.io.OutRaw   ('D. Execution Time : ');
                  a := Session.Event.exectime div 60;
                  b := Session.Event.exectime mod 60;
                  Session.io.OutRawln (strZero(a) + ':' + strZero(b));
                  Session.io.OutRawln ('E. Busy Warning   : ' + strI2S(Session.Event.Warning));
                  Session.io.OutRawln ('F. Last Ran on    : ' + DateDos2Str(Session.Event.LastRan, Session.User.ThisUser.DateType));
                  Session.io.OutRawln ('G. Offhook Modem  : ' + Session.io.OutYN(Session.Event.Offhook));
                  Session.io.OutRaw   ('H. Node Number    : ');
                  If Session.Event.Node = 0 Then
                    Session.io.OutRawLn ('All')
									Else
                    Session.io.OutRawLn (strI2S(Session.Event.Node));
                  Session.io.OutFull ('|CR|09Command (Q/Quit): ');
                  case Session.io.OneKey('[]!ABCDEFGHQ', True) of
                    '[' : If FilePos(Session.EventFile) > 1 Then Begin
                            Seek  (Session.EventFile, FilePos(Session.EventFile)-1);
                            Write (Session.EventFile, Session.Event);
                            Seek  (Session.EventFile, FilePos(Session.EventFile)-2);
                            Read  (Session.EventFile, Session.Event);
													End;
                    ']' : If FilePos(Session.EventFile) < FileSize(Session.EventFile) Then Begin
                            Seek (Session.EventFile, FilePos(Session.EventFile)-1);
                            Write (Session.EventFile, Session.Event);
                            Read (Session.EventFile, Session.Event);
													End;
                    '!' : Session.Event.active   := not Session.Event.active;
                    'A' : Session.Event.name     := Session.io.InXY(21, 4, 30, 30, 11, Session.Event.name);
                    'B' : Session.Event.forced   := not Session.Event.forced;
                    'C' : Session.Event.errlevel := strS2I(Session.io.InXY(21, 6, 3, 3, 12, strI2S(Session.Event.errlevel)));
										'D' : Begin
                            a := strS2I(Session.io.InXY(21, 7, 2, 2, 12, ''));
                            b := strS2I(Session.io.InXY(24, 7, 2, 2, 12, ''));
														if (a > -1) and (a < 24) and (b >= 0) and (b < 60) then
                              Session.Event.exectime := (a * 60) + b;
													end;
                    'E' : Session.Event.Warning := strS2I(Session.io.InXY(21, 8, 2, 2, 12, strI2S(Session.Event.Warning)));
                    'F' : Session.Event.LastRan := DateStr2Dos(Session.io.InXY(21, 9, 8, 8, 15, DateDos2Str(Session.Event.lastran, Session.User.ThisUser.DateType)));
                    'G' : Session.Event.Offhook := Not Session.Event.Offhook;
                    'H' : Session.Event.Node    := strS2I(Session.io.InXY(21, 11, 3, 3, 12, strI2S(Session.Event.Node)));
										'Q' : Break;
									end
								until false;
                seek (Session.EventFile, filepos(Session.EventFile)-1);
                write (Session.EventFile, Session.Event);
							end;
						end;
			'Q' : break;
		end;
	until False;

  Close (Session.EventFile);

	Session.FindNextEvent;
End;

End.

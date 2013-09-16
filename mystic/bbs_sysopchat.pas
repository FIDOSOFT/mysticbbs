Unit bbs_SysOpChat;

{$I M_OPS.PAS}

Interface

Procedure OpenChat (Split : Boolean);

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  bbs_Common,
  bbs_DataBase,
  bbs_Core,
  bbs_User;

Var
  tFile : Text;

Procedure Split_Chat;
Var
  Update   : LongInt = 0;
  LastUser : Boolean;
  UserStr  : String;
  SysopStr : String;
  Temp1,
  Temp2    : String;
  Ch       : Char;
  UserX,
  UserY    : Byte;
  SysopX,
  SysopY   : Byte;
  X, Y, A  : Byte;

Procedure Total_ReDraw;
Begin
  Session.io.PromptInfo[1] := Session.User.ThisUser.Handle;
  Session.io.PromptInfo[2] := bbsCfg.SysopName;

  Session.io.ScreenInfo[9].X := 0;
  Session.io.ScreenInfo[0].X := 0;

  Session.io.OutFile ('ansichat', True, 0);

  UserStr  := '';
  UserX    := Session.io.ScreenInfo[3].X;
  UserY    := Session.io.ScreenInfo[1].Y;
  SysopX   := Session.io.ScreenInfo[7].X;
  SysopY   := Session.io.ScreenInfo[5].Y;
  SysopStr := '';

  Session.io.AnsiGotoXY (SysopX, SysopY);
  Session.io.AnsiColor  (Session.io.ScreenInfo[5].A);

  LastUser := False;
End;

Begin
  Total_ReDraw;

  Repeat
    If Update <> TimerMinutes Then Begin
      X := Console.CursorX;
      Y := Console.CursorY;
      A := Console.TextAttr;

      If Session.io.ScreenInfo[9].X <> 0 Then Begin
        Session.io.AnsiGotoXY (Session.io.ScreenInfo[9].X, Session.io.ScreenInfo[9].Y);
        Session.io.AnsiColor  (Session.io.ScreenInfo[9].A);

        Session.io.OutFull ('|$L04|TL');
      End;

      If Session.io.ScreenInfo[0].X <> 0 Then Begin
        Session.io.AnsiGotoXY (Session.io.ScreenInfo[0].X, Session.io.ScreenInfo[0].Y);
        Session.io.AnsiColor  (Session.io.ScreenInfo[0].A);

        Session.io.OutFull ('|TI');
      End;

      Session.io.AnsiGotoXY (X, Y);
      Session.io.AnsiColor  (A);

      Update := TimerMinutes;
    End;

    Ch := Session.io.GetKey;

    If Not Session.io.LocalInput and Not LastUser Then Begin
      Session.io.AnsiGotoXY (UserX, UserY);
      Session.io.AnsiColor  (Session.io.ScreenInfo[1].A);

      LastUser := True;
    End Else
    If Session.io.LocalInput and LastUser Then Begin
      Session.io.AnsiGotoXY (SysopX, SysopY);
      Session.io.AnsiColor  (Session.io.ScreenInfo[5].A);

      LastUser := False;
    End;

    Case Ch of
      #00 : If Session.io.LocalInput Then ProcessSysopCommand(Keyboard.ReadKey);
      ^R  : If Session.io.LocalInput Then Total_ReDraw;
      #08 : If Session.io.LocalInput Then Begin
              If SysopX > Session.io.ScreenInfo[7].X Then Begin
                Session.io.OutBS (1, True);

                Dec (SysopX);
                Dec (SysopStr[0]);
              End;
            End Else Begin
              If UserX > Session.io.ScreenInfo[3].X Then Begin
                Session.io.OutBS (1, True);

                Dec (UserX);
                Dec (UserStr[0]);
              End;
            End;
      #10 : ;
      #13 : If Session.io.LocalInput Then Begin
              sysopx := Session.io.ScreenInfo[7].x;
              if sysopy = Session.io.ScreenInfo[6].y then begin
                for sysopy := Session.io.ScreenInfo[6].y downto Session.io.ScreenInfo[5].y do begin
                  Session.io.AnsiGotoXY(Session.io.ScreenInfo[7].x, sysopy);
                  Session.io.OutRaw (strRep(' ', Session.io.ScreenInfo[8].x - Session.io.ScreenInfo[7].x + 1));
                  Session.io.AnsiGotoXY(Session.io.ScreenInfo[7].x, sysopy);
                end;
                Session.io.OutRaw(sysopstr);
              end;
              If bbsCfg.ChatLogging Then WriteLn (tFile, 'S> ' + SysopSTR);
              inc (sysopy);
              sysopstr := '';
              Session.io.AnsiGotoXY (sysopx, sysopy);
            End Else Begin
              userx := Session.io.ScreenInfo[3].x;
              if usery = Session.io.ScreenInfo[2].y then begin
                for usery := Session.io.ScreenInfo[2].y downto Session.io.ScreenInfo[1].y do begin
                  Session.io.AnsiGotoXY(userx, usery);
                  Session.io.OutRaw (strRep(' ', Session.io.ScreenInfo[4].x - Session.io.ScreenInfo[3].x + 1));
                  Session.io.AnsiGotoXY(userx, usery);
                end;
                Session.io.OutRaw(userstr);
              end;
              inc (usery);
              If bbsCfg.ChatLogging Then WriteLn (tFile, 'U> ' + UserSTR);
              userstr := '';
              Session.io.AnsiGotoXY (userx, usery);
            End;
      #27 : If Session.io.LocalInput Then Break;
    Else
      If Session.io.LocalInput Then Begin
        Session.io.BufAddChar (ch);
        inc (sysopx);
        sysopstr := sysopstr + ch;
        if sysopx > Session.io.ScreenInfo[8].x then begin
          strwrap (sysopstr, temp2, Session.io.ScreenInfo[8].x - session.io.screeninfo[7].x + 1);
          temp1 := sysopstr;
          If bbsCfg.ChatLogging Then WriteLn (tFile, 'S> ' + SysopSTR);
          sysopstr := temp2;
          Session.io.OutBS (length(temp2), True);
          if sysopy=Session.io.ScreenInfo[6].y then begin
            for sysopy := Session.io.ScreenInfo[6].y downto Session.io.ScreenInfo[5].y do begin
              Session.io.AnsiGotoXY(Session.io.ScreenInfo[7].x, sysopy);
              Session.io.OutRaw (strRep(' ', Session.io.ScreenInfo[8].x - Session.io.ScreenInfo[7].x + 1));
            end;
            Session.io.AnsiGotoXY(Session.io.ScreenInfo[7].x, sysopy);
            Session.io.OutRaw(temp1);
          end;
          inc (sysopy);
          Session.io.AnsiGotoXY(Session.io.ScreenInfo[7].x, sysopy);
          Session.io.OutRaw (sysopstr);
          sysopx := Console.CursorX;
        end;
      End Else Begin
        Session.io.BufAddChar (ch);
        inc (userx);
        userstr := userstr + ch;
        if userx > Session.io.ScreenInfo[4].x then begin
          strwrap (userstr, temp2, Session.io.ScreenInfo[4].x - session.io.screeninfo[3].x + 1);
          temp1 := userstr;
          If bbsCfg.ChatLogging Then WriteLn (tFile, 'U> ' + UserSTR);
          userstr := temp2;
          Session.io.OutBS (length(temp2), True);
          if usery=Session.io.ScreenInfo[2].y then begin
            for usery := Session.io.ScreenInfo[2].y downto Session.io.ScreenInfo[1].y do begin
              Session.io.AnsiGotoXY(Session.io.ScreenInfo[3].x, usery);
              Session.io.OutRaw (strRep(' ', Session.io.ScreenInfo[4].x - Session.io.ScreenInfo[3].x + 1));
            end;
            Session.io.AnsiGotoXY(Session.io.ScreenInfo[3].x, usery);
            Session.io.OutRawln(temp1);
          end;
          inc(usery);
          Session.io.AnsiGotoXY (Session.io.ScreenInfo[3].x, usery);
          Session.io.OutRaw(userstr);
          userx := Console.CursorX;
        end;
      end;
    End;
  Until False;

  Session.io.AnsiGotoXY (1, Session.User.ThisUser.ScreenSize);

  Session.io.OutFull ('|16' + Session.GetPrompt(27));
End;

Procedure Line_Chat;
Var
  Ch   : Char;
  Str1 : String[160];
  Str2 : String[160];
Begin
  Str1 := '';
  Str2 := '';

  Session.io.OutFullLn (Session.GetPrompt(26));

  Repeat
    Ch := Session.io.GetKey;

    Case Ch of
      #27 : If Session.io.LocalInput Then Break;
      #13 : Begin
              If bbsCfg.ChatLogging Then WriteLn (tFile, Str1);
              Session.io.OutRawLn('');
              Str1 := '';
            End;
      #8  : If Str1 <> '' Then Begin
              Session.io.OutBS(1, True);
              Dec(Str1[0]);
            End;
    Else
      Str1 := Str1 + Ch;

      Session.io.BufAddChar(Ch);

      If Length(Str1) > 78 Then Begin
        strWrap (Str1, Str2, 78);
        Session.io.OutBS(Length(Str2), True);
        Session.io.OutRawLn ('');
        Session.io.OutRaw (Str2);

        If bbsCfg.ChatLogging Then WriteLn (tFile, Str1);

        Str1 := Str2;
      End;
    End;
  Until False;

  Session.io.OutFull (Session.GetPrompt(27));
End;

Procedure OpenChat (Split: Boolean);
Var
	Image : TConsoleImageRec;
Begin
  Session.User.InChat := True;

  Console.GetScreenImage(1,1,79,24,Image);

  UpdateStatusLine (0, '(ESC) to Quit, (Ctrl-R) to Redraw');

  If bbsCfg.ChatLogging Then Begin
    Assign (tFile, bbsCfg.LogsPath + 'chat.log');
    {$I-} Append (tFile); {$I+}

    If IoResult <> 0 Then ReWrite (tFile);

    WriteLn (tFile, '');
    WriteLn (tFile, 'Chat recorded ' + DateDos2Str(CurDateDos, 1) + ' ' + TimeDos2Str(CurDateDos, 1) +
                    ' with ' + Session.User.ThisUser.Handle);
    WriteLn (tFile, strRep('-', 70));
  End;

  If ((Split) And (Session.io.Graphics > 0)) Then Split_Chat Else Line_Chat;

  If bbsCfg.ChatLogging Then Begin
    WriteLn (tFile, strRep('-', 70));
    Close (tFile);
  End;

  Session.User.InChat := False;
  Session.TimeOut     := TimerSeconds;

  Session.io.RemoteRestore(Image);

  UpdateStatusLine (Session.StatusPtr, '');
End;

End.

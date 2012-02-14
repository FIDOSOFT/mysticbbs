Unit bbs_cfg_SecLevel;

{$I M_OPS.PAS}

Interface

Procedure Levels_Editor;

Implementation

Uses
  m_Strings,
  bbs_Common,
  bbs_Core,
  bbs_User;

Procedure Levels_Editor;
Var
	A   : Integer;
	Old : RecSecurity;
Begin
	Session.SystemLog('*LEVEL EDITOR*');

  Old := Session.User.Security;

  Reset (Session.User.SecurityFile);
  Read (Session.User.SecurityFile, Session.User.Security);
	Repeat
    Session.io.OutFullLn ('|CL|14Security Level ' + strI2S(FilePos(Session.User.SecurityFile)) + ' of 255|CR|03');
    Session.io.OutRawLn ('A. Description          : ' + Session.User.Security.Desc);
    Session.io.OutRawLn ('B. Time allowed/day     : ' + strI2S(Session.User.Security.Time));
    Session.io.OutRawLn ('C. Max calls/day        : ' + strI2S(Session.User.Security.MaxCalls));
    Session.io.OutRawLn ('D. Max downloads/day    : ' + strI2S(Session.User.Security.MaxDLs));
    Session.io.OutRawLn ('E. Max download K/day   : ' + strI2S(Session.User.Security.MaxDLk));
    Session.io.OutRawLn ('F. Max mins in time bank: ' + strI2S(Session.User.Security.MaxTB));

    Session.io.OutRaw   ('G. UL/DL ratio          : ');
    If Session.User.Security.DLRatio = 0 Then
      Session.io.OutRawLn ('Disabled')
		Else
      Session.io.OutRawLn ('1 UL for every ' + strI2S(Session.User.Security.DLRatio) + ' DLs');

    Session.io.OutRaw   ('H. UL/DL Kb ratio       : ');
    If Session.User.Security.DLKRatio = 0 Then
      Session.io.OutRawLn ('Disabled')
		Else
      Session.io.OutRawLn ('1 UL kb for every ' + strI2S(Session.User.Security.DLKRatio) + ' DL kb');

    Session.io.OutRaw ('I. Post / Call Ratio    : ');
    If Session.User.Security.PCRatio = 0 Then
      Session.io.OutRawLn ('Disabled')
		Else
      Session.io.OutRawLn (strI2S(Session.User.Security.PCRatio) + ' posts for every 100 calls');

    Session.io.OutFullLn ('|CRK. Upgraded Flags Set 1 : ' + DrawAccessFlags(Session.User.Security.AF1));
    Session.io.OutFullLn ('L. Upgraded Flags Set 2 : ' + DrawAccessFlags(Session.User.Security.AF2));

    Session.io.OutFullLn   ('|CRM. Hard AF Upgrade      : ' + Session.io.OutYN(Session.User.Security.Hard));

    Session.io.OutRawLn ('N. Start Menu           : ' + Session.User.Security.StartMeNU);

    Session.io.OutFull ('|CR|09([) Previous, (]), Next, (J)ump, (Q)uit: ');
		Case Session.io.OneKey('[]ABCDEFGHIJKLMNQ', True) of
      '[' : If FilePos(Session.User.SecurityFile) > 1 Then Begin
              Seek (Session.User.SecurityFile, FilePos(Session.User.SecurityFile)-1);
              Write (Session.User.SecurityFile, Session.User.Security);
              Seek (Session.User.SecurityFile, FilePos(Session.User.SecurityFile)-2);
              Read (Session.User.SecurityFile, Session.User.Security);
						End;
      ']' : If FilePos(Session.User.SecurityFile) < 255 Then Begin
              Seek (Session.User.SecurityFile, FilePos(Session.User.SecurityFile)-1);
              Write (Session.User.SecurityFile, Session.User.Security);
              Read (Session.User.SecurityFile, Session.User.Security);
						End;
      'A' : Session.User.Security.Desc     := Session.io.InXY(27, 3, 30, 30, 11, Session.User.Security.Desc);
      'B' : Session.User.Security.Time     := strS2I(Session.io.InXY(27,  4, 3, 3, 12, strI2S(Session.User.Security.Time)));
      'C' : Session.User.Security.MaxCalls := strS2I(Session.io.InXY(27,  5, 4, 4, 11, strI2S(Session.User.Security.MaxCalls)));
      'D' : Session.User.Security.MaxDLs   := strS2I(Session.io.InXY(27,  6, 4, 4, 11, strI2S(Session.User.Security.MaxDLs)));
      'E' : Session.User.Security.MaxDLK   := strS2I(Session.io.InXY(27,  7, 4, 4, 11, strI2S(Session.User.Security.MaxDLK)));
      'F' : Session.User.Security.MaxTB    := strS2I(Session.io.InXY(27,  8, 4, 4, 11, strI2S(Session.User.Security.MaxTB)));
      'G' : Session.User.Security.DLRatio  := strS2I(Session.io.InXY(27,  9, 2, 2, 12, strI2S(Session.User.Security.DLRatio)));
      'H' : Session.User.Security.DLKRatio := strS2I(Session.io.InXY(27, 10, 4, 4, 12, strI2S(Session.User.Security.DLKRatio)));
      'I' : Session.User.Security.PCRatio  := strS2I(Session.io.InXY(27, 11, 4, 4, 12, strI2S(Session.User.Security.PCRatio)));
			'J' : Begin
              Session.io.OutRaw ('Jump to (1-255): ');
              A := strS2I(Session.io.GetInput(3, 3, 12, ''));
							If (A > 0) and (A < 256) Then Begin
                Seek (Session.User.SecurityFile, FilePos(Session.User.SecurityFile)-1);
                Write (Session.User.SecurityFile, Session.User.Security);
                Seek (Session.User.SecurityFile, A-1);
                Read (Session.User.SecurityFile, Session.User.Security);
							End;
						End;
      'K' : EditAccessFlags(Session.User.Security.AF1);
      'L' : EditAccessFlags(Session.User.Security.AF2);
      'M' : Session.User.Security.Hard     := Not Session.User.Security.Hard;
      'N' : Session.User.Security.StartMenu := Session.io.InXY(27, 17, 8, 8, 11, Session.User.Security.startmenu);
			'Q' : Break;
		End;
	Until False;
  Seek (Session.User.SecurityFile, FilePos(Session.User.SecurityFile)-1);
  Write (Session.User.SecurityFile, Session.User.Security);
  Close (Session.User.SecurityFile);
  Session.User.Security := Old;
End;

End.

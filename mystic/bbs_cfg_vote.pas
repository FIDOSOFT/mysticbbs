Unit bbs_cfg_Vote;

{$I M_OPS.PAS}

Interface

Procedure Vote_Editor;

Implementation

Uses
  m_Strings,
  bbs_Common,
  bbs_Core,
  bbs_User;

Procedure Vote_Editor;
var
	A,
	B    : Integer;
	C    : Byte;
	Temp : String[2];
Begin
	Session.SystemLog ('*VOTE EDITOR*');

	Repeat
    Session.io.OutFullLn ('|CL|14Voting Booth Editor|CR|CR|15##  Question|CR|09--  ---------------------------------------');

		Reset (Session.VoteFile);

		While Not Eof(Session.VoteFile) Do Begin
			Read (Session.VoteFile, Session.Vote);

      Session.io.OutFullLn ('|15' + strPadR(strI2S(FilePos(Session.VoteFile)), 4, ' ') + '|14' + Session.Vote.Question);
		End;

    Session.io.OutFull ('|CR|09(A)dd, (D)elete, (E)dit, (Q)uit? ');

    Case Session.io.OneKey ('ADEQ', True) of
			'A' : If FileSize(Session.VoteFile) = mysMaxVoteQuestion Then
              Session.io.OutFullLn ('|CR|14Max # of questions is ' + strI2S(mysMaxVoteQuestion))
						Else Begin
							Session.Vote.Votes           := 0;
							Session.Vote.AnsNum          := 1;
							Session.Vote.ACS             := 's999';
							Session.Vote.AddACS          := 's999';
							Session.Vote.ForceACS        := 's999';
							Session.Vote.Question        := 'New Question';
							Session.Vote.Answer[1].Text  := 'New voting answer';
							Session.Vote.Answer[1].Votes := 0;

							Seek  (Session.VoteFile, FileSize(Session.VoteFile));
							Write (Session.VoteFile, Session.Vote);
						End;
			'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
							If (A > 0) And (A <= FileSize(Session.VoteFile)) Then Begin
                Session.io.OutFullLn ('|CRDeleting...');
								KillRecord (Session.VoteFile, A, SizeOf(VoteRec));

                Reset (Session.User.UserFile);
                While Not Eof(Session.User.UserFile) Do Begin
                  Read (Session.User.UserFile, Session.User.TempUser);
									For C := A To 19 Do
                    Session.User.TempUser.Vote[C] := Session.User.TempUser.Vote[C+1];
                  Session.User.TempUser.Vote[20] := 0;
                  Seek (Session.User.UserFile, FilePos(Session.User.UserFile) - 1);
                  Write (Session.User.UserFile, Session.User.TempUser);
								End;
                Close (Session.User.UserFile);
								For C := A to 19 Do
                  Session.User.ThisUser.Vote[C] := Session.User.ThisUser.Vote[C+1];
                Session.User.ThisUser.Vote[20] := 0;
							End;
      			end;
		'E' 	: begin
              Session.io.OutRaw ('Edit which? ');
              A := strS2I(Session.io.GetInput(3, 3, 11, ''));
							If (A > 0) And (A <= FileSize(Session.VoteFile)) then begin
								Seek (Session.VoteFile, A - 1);
								Read (Session.VoteFile, Session.Vote);
								repeat
                  Session.io.OutFullLn ('|CL|14Question ' + strI2S(FilePos(Session.VoteFile)) + ' of ' + strI2S(FileSize(Session.VoteFile)) + '|CR|03');
                  Session.io.OutRawln ('A. Question   : ' + strPadR(Session.Vote.Question, 60, ' '));
                  Session.io.OutRawLn ('B. Votes      : ' + strI2S(Session.Vote.Votes));
                  Session.io.OutRawLn ('C. Vote ACS   : ' + Session.Vote.ACS);
                  Session.io.OutRawLn ('E. Add ACS    : ' + Session.Vote.AddACS);
                  Session.io.OutRawLn ('F. Forced ACS : ' + Session.Vote.ForceACS);
                  Session.io.OutFullLn ('|CR|15## Answer                              ## Answer');
                  Session.io.OutFullLn ('|09-- ----------------------------------- -- ------------------------------------');

                  For B := 1 to Session.Vote.AnsNum Do Begin
                    Session.io.OutFull ('|11' + strZero(B) + ' |14' + strPadR(Session.Vote.Answer[B].Text, 35, ' ') + ' ');
                    If (B Mod 2 = 0) or (B = Session.Vote.AnsNum) Then Session.io.OutRawLn ('');
									End;
                  Session.io.OutFull ('|CR|09(D)elete, (I)nsert, (Q)uit: ');
                  Temp := Session.io.GetInput(2, 2, 12, '');
                  If Temp = 'A' Then Session.Vote.Question := Session.io.InXY(17, 3, 60, 70, 11, Session.Vote.Question) Else
                  If Temp = 'B' Then Session.Vote.Votes    := strS2I(Session.io.InXY(17, 4, 5, 5, 12, strI2S(Session.Vote.Votes))) Else
                  If Temp = 'C' Then Session.Vote.ACS      := Session.io.InXY(17, 5, 20, 20, 11, Session.Vote.ACS) Else
									If Temp = 'D' Then Begin
                    Session.io.OutFull ('Delete which answer? ');
                    A := strS2I(Session.io.GetInput(2, 2, 12, ''));
										If (A > 0) and (A <= Session.Vote.AnsNum) Then Begin
											For C := A to Session.Vote.AnsNum-1 Do
												Session.Vote.Answer[C] := Session.Vote.Answer[C+1];
											Dec (Session.Vote.AnsNum);

                      Reset (Session.User.UserFile);
                      While Not Eof(Session.User.UserFile) Do Begin
                        Read (Session.User.UserFile, Session.User.TempUser);
                        If Session.User.TempUser.Vote[FilePos(Session.VoteFile)] = A Then Begin
                          Session.User.TempUser.Vote[FilePos(Session.VoteFile)] := 0;
                          Seek (Session.User.UserFile, FilePos(Session.User.UserFile) - 1);
                          Write (Session.User.UserFile, Session.User.TempUser);
												End;
											End;
                      Close (Session.User.UserFile);
                      If Session.User.ThisUser.Vote[FilePos(Session.VoteFile)] = A Then
                        Session.User.ThisUser.Vote[FilePos(Session.VoteFile)] := 0;
										End;
									End Else
                  If Temp = 'E' Then Session.Vote.AddACS   := Session.io.InXY(17, 6, 20, 20, 11, Session.Vote.AddACS)   Else
                  If Temp = 'F' Then Session.Vote.ForceACS := Session.io.InXY(17, 7, 20, 20, 11, Session.Vote.ForceACS) Else
									If (Temp = 'I') and (Session.Vote.AnsNum < 15) Then Begin
										Inc (Session.Vote.AnsNum);
                    Session.Vote.Answer[Session.Vote.AnsNum].Text  := '';
                    Session.Vote.Answer[Session.Vote.AnsNum].Votes := 0;
									End Else
									If Temp = 'Q' Then Break Else Begin
                    A := strS2I(Temp);
										If (A > 0) and (A < 21) Then Begin
                      Session.io.OutRaw ('Answer: ');
                      Session.Vote.Answer[A].Text := Session.io.GetInput (40, 40, 11, Session.Vote.Answer[A].Text);
                      Session.io.OutRaw ('Votes : ');
                      Session.Vote.Answer[A].Votes := strS2I(Session.io.GetInput(5, 5, 12, strI2S(Session.Vote.Answer[A].Votes)));
										End;
									End;
								until false;
								seek (Session.VoteFile, filepos(Session.VoteFile)-1);
								write (Session.VoteFile, Session.Vote);
							end;
						end;
			'Q' : break;
		end;

	Until False;

	Close (Session.VoteFile);
End;

End.

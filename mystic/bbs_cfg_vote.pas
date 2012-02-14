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
		Reset (VoteFile);
		While Not Eof(VoteFile) do begin
			Read (VoteFile, Vote);
      Session.io.OutFullLn ('|15' + strPadR(strI2S(filepos(VoteFile)), 4, ' ') + '|14' + Vote.Question);
		End;
    Session.io.OutFull ('|CR|09(A)dd, (D)elete, (E)dit, (Q)uit? ');
    case Session.io.OneKey ('ADEQ', True) of
			'A' : If FileSize(VoteFile) = mysMaxVoteQuestion Then
              Session.io.OutFullLn ('|CR|14Max # of questions is ' + strI2S(mysMaxVoteQuestion))
						Else Begin
							Vote.Votes    := 0;
							Vote.AnsNum   := 1;
							Vote.ACS      := 's999';
							Vote.AddACS   := 's999';
							Vote.ForceACS := 's999';
							Vote.Question := 'New Question';
							Vote.Answer[1].Text  := 'New voting answer';
							Vote.Answer[1].Votes := 0;
							Seek (VoteFile, FileSize(VoteFile));
							Write (VoteFile, Vote);
						End;
			'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
							If (A > 0) And (A <= FileSize(VoteFile)) Then Begin
                Session.io.OutFullLn ('|CRDeleting...');
								KillRecord (VoteFile, A, SizeOf(VoteRec));

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
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
							if (a > 0) and (a <= filesize(VoteFile)) then begin
								seek (VoteFile, a-1);
								read (VoteFile, Vote);
								repeat
                  Session.io.OutFullLn ('|CL|14Question ' + strI2S(FilePos(VoteFile)) + ' of ' + strI2S(FileSize(VoteFile)) + '|CR|03');
                  Session.io.OutRawln ('A. Question   : ' + strPadR(Vote.Question, 60, ' '));
                  Session.io.OutRawLn ('B. Votes      : ' + strI2S(Vote.Votes));
                  Session.io.OutRawLn ('C. Vote ACS   : ' + Vote.ACS);
                  Session.io.OutRawLn ('E. Add ACS    : ' + Vote.AddACS);
                  Session.io.OutRawLn ('F. Forced ACS : ' + Vote.ForceACS);
                  Session.io.OutFullLn ('|CR|15## Answer                              ## Answer');
                  Session.io.OutFullLn ('|09-- ----------------------------------- -- ------------------------------------');
									For B := 1 to Vote.AnsNum Do Begin
                    Session.io.OutFull ('|11' + strZero(B) + ' |14' + strPadR(Vote.Answer[B].Text, 35, ' ') + ' ');
                    If (B Mod 2 = 0) or (B = Vote.AnsNum) Then Session.io.OutRawLn ('');
									End;
                  Session.io.OutFull ('|CR|09(D)elete, (I)nsert, (Q)uit: ');
                  Temp := Session.io.GetInput(2, 2, 12, '');
                  If Temp = 'A' Then Vote.Question := Session.io.InXY(17, 3, 60, 70, 11, Vote.Question) Else
                  If Temp = 'B' Then Vote.Votes    := strS2I(Session.io.InXY(17, 4, 5, 5, 12, strI2S(Vote.Votes))) Else
                  If Temp = 'C' Then Vote.ACS      := Session.io.InXY(17, 5, 20, 20, 11, Vote.ACS) Else
									If Temp = 'D' Then Begin
                    Session.io.OutFull ('Delete which answer? ');
                    A := strS2I(Session.io.GetInput(2, 2, 12, ''));
										If (A > 0) and (A <= Vote.AnsNum) Then Begin
											For C := A to Vote.AnsNum-1 Do
												Vote.Answer[C] := Vote.Answer[C+1];
											Dec (Vote.AnsNum);

                      Reset (Session.User.UserFile);
                      While Not Eof(Session.User.UserFile) Do Begin
                        Read (Session.User.UserFile, Session.User.TempUser);
                        If Session.User.TempUser.Vote[FilePos(VoteFile)] = A Then Begin
                          Session.User.TempUser.Vote[FilePos(VoteFile)] := 0;
                          Seek (Session.User.UserFile, FilePos(Session.User.UserFile) - 1);
                          Write (Session.User.UserFile, Session.User.TempUser);
												End;
											End;
                      Close (Session.User.UserFile);
                      If Session.User.ThisUser.Vote[FilePos(VoteFile)] = A Then
                        Session.User.ThisUser.Vote[FilePos(VoteFile)] := 0;
										End;
									End Else
                  If Temp = 'E' Then Vote.AddACS   := Session.io.InXY(17, 6, 20, 20, 11, Vote.AddACS)   Else
                  If Temp = 'F' Then Vote.ForceACS := Session.io.InXY(17, 7, 20, 20, 11, Vote.ForceACS) Else
									If (Temp = 'I') and (Vote.AnsNum < 15) Then Begin
										Inc (Vote.AnsNum);
                    Vote.Answer[Vote.AnsNum].Text  := '';
                    Vote.Answer[Vote.AnsNum].Votes := 0;
									End Else
									If Temp = 'Q' Then Break Else Begin
                    A := strS2I(Temp);
										If (A > 0) and (A < 21) Then Begin
                      Session.io.OutRaw ('Answer: ');
                      Vote.Answer[A].Text := Session.io.GetInput (40, 40, 11, Vote.Answer[A].Text);
                      Session.io.OutRaw ('Votes : ');
                      Vote.Answer[A].Votes := strS2I(Session.io.GetInput(5, 5, 12, strI2S(Vote.Answer[A].Votes)));
										End;
									End;
								until false;
								seek (VoteFile, filepos(VoteFile)-1);
								write (VoteFile, Vote);
							end;
						end;
			'Q' : break;
		end;

	until False;
	close (VoteFile);
End;

End.

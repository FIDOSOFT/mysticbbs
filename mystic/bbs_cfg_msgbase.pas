Unit bbs_cfg_MsgBase;

{$I M_OPS.PAS}

Interface

Procedure Message_Base_Editor;

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Common,
  bbs_Core,
  bbs_User;

Procedure Message_Base_Editor;
Const
        BT : Array[0..1] of String[6] = ('JAM', 'Squish');
        NT : Array[0..3] of String[8] = ('Local   ', 'EchoMail', 'UseNet  ', 'NetMail ');
        ST : Array[0..2] of String[6] = ('No', 'Yes', 'Always');
Var
        A,
        B  : Word; { was integer }
Begin
        Session.SystemLog ('*MBASE EDITOR*');

        Repeat
                Session.io.AllowPause := True;

                Session.io.OutFullLn ('|CL|14Message Base Editor|CR|CR|09###  Name|$D37 Type      Format|CR---  |$D40- -------   ------');

                Reset (Session.Msgs.MBaseFile);
                While Not Eof(Session.Msgs.MBaseFile) Do Begin
                        Read (Session.Msgs.MBaseFile, Session.Msgs.MBase);

                        Session.io.OutFullLn ('|15' + strPadR(strI2S(FilePos(Session.Msgs.MBaseFile) - 1), 3, ' ') + '  |14|$R41|MB|10' +
                        NT[Session.Msgs.MBase.NetType] + '  ' + BT[Session.Msgs.MBase.BaseType]);

                        If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
                                Case Session.io.MorePrompt of
                                        'N' : Break;
                                        'C' : Session.io.AllowPause := False;
                                End;
                End;
                Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (M)ove, (Q)uit? ');
                case Session.io.OneKey (#13'DIEMQ', True) of
                  'D' : begin
                          Session.io.OutFull ('Delete which? ');
                          a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                          If (A > 0) and (A <= FileSize(Session.Msgs.MBaseFile)) Then Begin
                            Seek (Session.Msgs.MBaseFile, A);
                            Read (Session.Msgs.MBaseFile, Session.Msgs.MBase);

                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.jhr');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.jlr');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.jdt');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.jdx');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.sqd');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.sqi');
                            FileErase (config.msgspath + Session.Msgs.MBase.filename + '.sql');

                            KillRecord (Session.Msgs.MBaseFile, A+1, SizeOf(MBaseRec));
                          End;
                        end;
                        'I' : begin
                                                        Session.io.OutFull ('Insert before? (1-' + strI2S(filesize(Session.Msgs.MBaseFile)) + '): ');
                                                        a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                                                        if (a > 0) and (a <= filesize(Session.Msgs.MBaseFile)) then begin
                                                                AddRecord (Session.Msgs.MBaseFile, A, SizeOf(Session.Msgs.MBaseFile));

                                                                {find permanent mbase index}
                                                                b := a + 1;
                                                                reset (Session.Msgs.MBaseFile);
                                                                while not eof(Session.Msgs.MBaseFile) do begin
                                                                        read (Session.Msgs.MBaseFile, Session.Msgs.mbase);
                                                                        if B = Session.Msgs.MBase.index then begin
                                                                                inc (b);
                                                                                reset (Session.Msgs.MBaseFile);
                                                                        end;
                                                                end;
                                                                Session.Msgs.MBase.name                      := 'New Message Base';
                                                                Session.Msgs.MBase.qwkname   := 'New Messages';
                                                                Session.Msgs.MBase.filename  := 'NEW';
                                                                Session.Msgs.MBase.Path                      := config.msgspath;
                                                                Session.Msgs.MBase.nettype   := 0;
                                                                Session.Msgs.MBase.posttype := 0;
                                                                Session.Msgs.MBase.acs                       := 's255';
                                                                Session.Msgs.MBase.readacs   := 's255';
                                                                Session.Msgs.MBase.postacs   := 's255';
                                                                Session.Msgs.MBase.sysopacs  := 's255';
                                                                Session.Msgs.MBase.index             := B;
                                                                Session.Msgs.MBase.netaddr   := 1;
                                                                Session.Msgs.MBase.origin            := config.origin;
                                                                Session.Msgs.MBase.usereal   := false;
                                                                Session.Msgs.MBase.colquote  := config.colorquote;
                                                                Session.Msgs.MBase.coltext   := config.colortext;
                                                                Session.Msgs.MBase.coltear   := config.colortear;
                                                                Session.Msgs.MBase.colorigin := config.colororigin;
                                                                Session.Msgs.MBase.defnscan  := 1;
                                                                Session.Msgs.MBase.defqscan  := 1;
                                                                Session.Msgs.MBase.basetype  := 0;
                                                                seek (Session.Msgs.MBaseFile, a);
                                                                write (Session.Msgs.MBaseFile, Session.Msgs.mbase);
                                                        end;
                                                end;
                        'E' : begin
                                                        Session.io.OutFull ('Edit which? ');
                                                        a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                                                        if (a >= 0) and (a < filesize(Session.Msgs.MBaseFile)) then begin
                                                                seek (Session.Msgs.MBaseFile, a);
                                                                read (Session.Msgs.MBaseFile, Session.Msgs.mbase);
                                                                repeat
                 Session.io.OutFullLn ('|CL|14Message Base '+strI2S(FilePos(Session.Msgs.MBaseFile)-1)+' of '+strI2S(FileSize(Session.Msgs.MBaseFile)-1)+' |08[Perm Idx:' + strI2S(Session.Msgs.MBase.index) + ']|CR|03');
                                                                        Session.io.OutRawln ('A. Name         : ' + Session.Msgs.MBase.name);
                                                                        Session.io.OutRawln ('B. QWK Name     : ' + Session.Msgs.MBase.qwkname);
                                                                        Session.io.OutRawln ('C. Filename     : ' + Session.Msgs.MBase.filename);
                                                                        Session.io.OutRawln ('D. Storage Path : ' + Session.Msgs.MBase.path);
                                                                        Session.io.OutRaw   ('E. Post Type    : ');
                              If Session.Msgs.MBase.PostType = 0 Then Session.io.OutRaw ('Public ') Else Session.io.OutRaw ('Private');
                             Session.io.OutRawLn (strRep(' ', 23) + 'Y. Base Format  : ' + BT[Session.Msgs.MBase.BaseType]);

     Session.io.OutFull ('|CRF. List ACS     : ' + strPadR(Session.Msgs.MBase.acs, 30, ' '));
                                                                        Session.io.OutFull ('O. Quote Color  : ');
                                                                        Session.io.AnsiColor(Session.Msgs.MBase.ColQuote);
                                                                        Session.io.OutFullLn ('XX> Quote|03|16');

     Session.io.OutRaw ('G. Read ACS     : ' + strPadR(Session.Msgs.MBase.readacs, 30, ' '));
                                                                        Session.io.OutFull     ('P. Text Color   : ');
                                                                        Session.io.AnsiColor(Session.Msgs.MBase.ColText);
                                                                        Session.io.OutFullLn ('Text|03|16');

     Session.io.OutRaw ('H. Post ACS     : ' + strPadR(Session.Msgs.MBase.postacs, 30, ' '));
                                                                        Session.io.OutFull     ('R. Tear Color   : ');
                                                                        Session.io.AnsiColor(Session.Msgs.MBase.ColTear);
                                                                        Session.io.OutFullLn ('--- Tear|03|16');

    Session.io.OutRaw ('I. Sysop ACS    : ' + strPadR(Session.Msgs.MBase.sysopacs, 30, ' '));
                                                                        Session.io.OutFull     ('S. Origin Color : ');
                                                                        Session.io.AnsiColor(Session.Msgs.MBase.ColOrigin);
                                                                        Session.io.OutFullLn ('* Origin:|03|16');

            Session.io.OutRaw   ('J. Password     : ' + strPadR(Session.Msgs.MBase.password, 30, ' '));
                                                                        Session.io.OutRawln ('T. Header File  : ' + Session.Msgs.MBase.Header);
                                                                        Session.io.OutRawLn ('K. Base Type    : ' + NT[Session.Msgs.MBase.NetType]);
              Session.io.OutRawln ('L. Net Address  : ' + strAddr2Str(config.netaddress[Session.Msgs.MBase.netaddr]) + ' (' + Config.NetDesc[Session.Msgs.MBase.NetAddr] + ')');
                                                                        Session.io.OutRawln ('M. Origin line  : ' + Session.Msgs.MBase.origin);
                   Session.io.OutRawLn ('N. Use Realnames: ' + Session.io.OutYN(Session.Msgs.MBase.UseReal));

                 Session.io.OutFullLn ('|CRU. Default New Scan: ' + strPadR(ST[Session.Msgs.MBase.DefNScan], 27, ' ') +
                                      'W. Max Messages : ' + strI2S(Session.Msgs.MBase.MaxMsgs));

            Session.io.OutRawLn ('V. Default QWK Scan: ' + strPadR(ST[Session.Msgs.MBase.DefQScan], 27, ' ') +
             'X. Max Msg Age  : ' + strI2S(Session.Msgs.MBase.MaxAge) + ' days');

                                                                        Session.io.OutFull ('|CR|09([) Prev, (]) Next, (Q)uit: ');
                                                                        case Session.io.OneKey('[]ABCDEFGHIJKLMNOPQRSTUVWXY', True) of
                                                                                '[' : If FilePos(Session.Msgs.MBaseFile) > 1 Then Begin
                 Seek    (Session.Msgs.MBaseFile, FilePos(Session.Msgs.MBaseFile)-1);
                 Write (Session.Msgs.MBaseFile, Session.Msgs.MBase);
                 Seek    (Session.Msgs.MBaseFile, FilePos(Session.Msgs.MBaseFile)-2);
                                               Read    (Session.Msgs.MBaseFile, Session.Msgs.MBase);
                                                                                                        End;
       ']' : If FilePos(Session.Msgs.MBaseFile) < FileSize(Session.Msgs.MBaseFile) Then Begin
                                                  Seek (Session.Msgs.MBaseFile, FilePos(Session.Msgs.MBaseFile)-1);
                                                  Write (Session.Msgs.MBaseFile, Session.Msgs.MBase);
                                                  Read (Session.Msgs.MBaseFile, Session.Msgs.MBase);
                                                                                                        End;
                                                  'A' : Session.Msgs.MBase.Name     := Session.io.InXY(19,  3, 40, 40, 11, Session.Msgs.MBase.Name);
                                                  'B' : Session.Msgs.MBase.QwkName  := Session.io.InXY(19,  4, 13, 13, 11, Session.Msgs.MBase.QwkName);
                                                  'C' : Session.Msgs.MBase.FileName := Session.io.InXY(19,  5,  40,  40, 11, Session.Msgs.MBase.filename);
                                                  'D' : Session.Msgs.MBase.Path     := CheckPath(Session.io.InXY(19, 6, 39, 39, 11, Session.Msgs.MBase.Path));
                                                  'E' : If Session.Msgs.MBase.PostType = 0 Then Inc(Session.Msgs.MBase.PostType) Else Dec(Session.Msgs.MBase.PostType);
                                                  'F' : Session.Msgs.MBase.ACS      := Session.io.InXY(19,  9, 20, 20, 11, Session.Msgs.MBase.acs);
                                                  'G' : Session.Msgs.MBase.ReadACS  := Session.io.InXY(19, 10, 20, 20, 11, Session.Msgs.MBase.readacs);
                                                  'H' : Session.Msgs.MBase.PostACS  := Session.io.InXY(19, 11, 20, 20, 11, Session.Msgs.MBase.postacs);
                                                  'I' : Session.Msgs.MBase.SysopACS := Session.io.InXY(19, 12, 20, 20, 11, Session.Msgs.MBase.sysopacs);
                                                  'J' : Session.Msgs.MBase.Password := Session.io.InXY(19, 13, 15, 15, 12, Session.Msgs.MBase.password);
                                                  'K' : If Session.Msgs.MBase.NetType < 3 Then Inc(Session.Msgs.MBase.NetType) Else Session.Msgs.MBase.NetType := 0;
                                                                                'L' : begin
                                                                                                                Session.io.OutFullLn ('|03');
                                                                      For A := 1 to 30 Do Begin
     Session.io.OutRaw (strPadR(strI2S(A) + '.', 5, ' ') + strPadR(strAddr2Str(Config.NetAddress[A]), 30, ' '));
                                                                                 If A Mod 2 = 0 then Session.io.OutRawLn('');
                                                                                                                End;
                                    Session.io.OutFull ('|CR|09Address: ');
                                   a := strS2I(Session.io.GetInput(2, 2, 12, ''));
                           if (a > 0) and (a < 31) then Session.Msgs.MBase.netaddr := a;
                                                                                                        end;
      'M' : Session.Msgs.MBase.origin    := Session.io.InXY(19, 16, 50, 50, 11, Session.Msgs.MBase.origin);
                                                                                'N' : Session.Msgs.MBase.usereal   := Not Session.Msgs.MBase.UseReal;
      'O' : Session.Msgs.MBase.ColQuote  := getColor(Session.Msgs.MBase.ColQuote);
      'P' : Session.Msgs.MBase.ColText   := getColor(Session.Msgs.MBase.ColText);
      'R' : Session.Msgs.MBase.ColTear   := getColor(Session.Msgs.MBase.ColTear);
      'S' : Session.Msgs.MBase.ColOrigin := getColor(Session.Msgs.MBase.ColOrigin);
      'T' : Session.Msgs.MBase.Header   := Session.io.InXY(67, 13, 8, 8, 11, Session.Msgs.MBase.Header);
                            'U' : If Session.Msgs.MBase.DefNScan < 2 Then Inc(Session.Msgs.MBase.DefNScan) Else Session.Msgs.MBase.DefNScan := 0;
                            'V' : If Session.Msgs.MBase.DefQScan < 2 Then Inc(Session.Msgs.MBase.DefQScan) Else Session.Msgs.MBase.DefQScan := 0;
                            'W' : Session.Msgs.MBase.MaxMsgs  := strS2I(Session.io.InXY(67, 19, 5, 5, 12, strI2S(Session.Msgs.MBase.MaxMsgs)));
                            'X' : Session.Msgs.MBase.MaxAge   := strS2I(Session.io.InXY(67, 20, 5, 5, 12, strI2S(Session.Msgs.MBase.MaxAge)));
                            'Y' : If Session.Msgs.MBase.BaseType = 0 Then Session.Msgs.MBase.BaseType := 1 Else Session.Msgs.MBase.BaseType := 0;
                            'Q' : Break;
                                                                        End;
                                                                Until False;
                                                                Seek    (Session.Msgs.MBaseFile, FilePos(Session.Msgs.MBaseFile) - 1);
                                                                Write (Session.Msgs.MBaseFile, Session.Msgs.MBase);
                                                        End;
                                                End;
                        'M' : Begin
                                                        Session.io.OutRaw ('Move which? ');
                                                        A := strS2I(Session.io.GetInput(3, 3, 12, ''));

                                                        Session.io.OutRaw ('Move before? (1-' + strI2S(FileSize(Session.Msgs.MBaseFile)) + '): ');
                                                        B := strS2I(Session.io.GetInput(3, 3, 12, ''));

                         If (A > 0) and (A <= FileSize(Session.Msgs.MBaseFile)) and (B > 0) and (B <= FileSize(Session.Msgs.MBaseFile)) Then Begin
                                                                Seek (Session.Msgs.MBaseFile, A);
                                                                Read (Session.Msgs.MBaseFile, Session.Msgs.MBase);

                                                                AddRecord (Session.Msgs.MBaseFile, B+1, SizeOf(MBaseRec));
                                                                Write  (Session.Msgs.MBaseFile, Session.Msgs.MBase);

                                                                If A > B Then Inc(A);

                                                                KillRecord (Session.Msgs.MBaseFile, A+1, SizeOf(MBaseRec));
                                                        End;
                                                End;
                        'Q' : break;
                end;

        until False;
        close (Session.Msgs.MBaseFile);
end;

end.

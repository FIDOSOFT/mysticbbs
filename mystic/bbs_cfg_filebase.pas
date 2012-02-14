Unit bbs_cfg_FileBase;

{$I M_OPS.PAS}

Interface

Procedure File_Base_Editor;

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Common,
  bbs_Core,
  bbs_User;

Procedure File_Base_Editor;
Const
   ST : Array[0..2] of String[6] = ('No', 'Yes', 'Always');
Var
        A,
        B  : LongInt;
Begin
        Session.SystemLog ('*FBASE EDITOR*');
        Reset(Session.FileBase.FBaseFile);

        Repeat
                Session.io.AllowPause := True;

                Session.io.OutFullLn ('|CL|14File Base Editor|CR|CR|09###  Name|CR---  |$D40-');

                Reset (Session.FileBase.FBaseFile);
                While Not Eof(Session.FileBase.FBaseFile) Do Begin
                        Read     (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                        Session.io.OutFullLn ('|15' + strPadR(strI2S(FilePos(Session.FileBase.FBaseFile)), 3, ' ') + '  |14|FB');

                        If (Session.io.PausePtr = Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
                                Case Session.io.MorePrompt of
                                        'N' : Break;
                                        'C' : Session.io.AllowPause := False;
                                End;
                End;

                Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (M)ove, (Q)uit? ');
                Case Session.io.OneKey (#13'DEIMQ', True) of
                        'D' : begin
                                Session.io.OutRaw ('Delete which base? ');
                                a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                                If (A > 0) and (A <= FileSize(Session.FileBase.FBaseFile)) Then Begin
                                  Seek (Session.FileBase.FBaseFile, A - 1);
                                  Read (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                  FileErase (config.datapath + Session.FileBase.FBase.filename + '.dir');
                                  FileErase (config.datapath + Session.FileBase.FBase.filename + '.des');
                                  FileErase (config.datapath + Session.FileBase.FBase.filename + '.scn');
                                  KillRecord (Session.FileBase.FBaseFile, A, SizeOf(FBaseRec));
                                End;
                              End;
                        'I' : begin
                                Session.io.OutRaw ('Insert before which? (1-' + strI2S(filesize(Session.FileBase.FBaseFile)+1) + '): ');
                                                        a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                                                        if (a > 0) and (a <= filesize(Session.FileBase.FBaseFile)+1) then begin
                                                                AddRecord (Session.FileBase.FBaseFile, A, SizeOf(Session.FileBase.FBaseFile));

                                                                Session.FileBase.FBase.Name               := 'New File Base';
                                                                Session.FileBase.FBase.FtpName := 'New_File_Base';
                                                                Session.FileBase.FBase.Filename := 'NEW';
                                                                Session.FileBase.FBase.Dispfile := '';
                                                                Session.FileBase.FBase.ListACS                := 's255';
                                                                Session.FileBase.FBase.FtpACS := 's255';
                                                                Session.FileBase.FBase.SysopACS := 's255';
                                                                Session.FileBase.FBase.UlACS      := 's255';
                                                                Session.FileBase.FBase.DlACS      := 's255';
                                                                Session.FileBase.FBase.Path               := '';
                                                                Session.FileBase.FBase.Password := '';
                                                                Session.FileBase.FBase.ShowUL     := True;
                                                                Session.FileBase.FBase.IsCDROM  := False;
                                                                Session.FileBase.FBase.DefScan  := 1;

                                                                Write (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                                        end;
                                                end;
                        'E' : begin
                                                        Session.io.OutRaw ('Edit which? ');
                                                        a := strS2I(Session.io.GetInput(3, 3, 11, ''));
                                                        if (a > 0) and (a <= filesize(Session.FileBase.FBaseFile)) then begin
                                                                seek (Session.FileBase.FBaseFile, a-1);
                                                                read (Session.FileBase.FBaseFile, Session.FileBase.fbase);
                                                                repeat
            Session.io.OutFullLn ('|CL|14File Base ' + strI2S(FilePos(Session.FileBase.FBaseFile)) + ' of ' + strI2S(FileSize(Session.FileBase.FBaseFile)) + '|CR|03');
                                                                        Session.io.OutRawln ('A. Name             : ' + Session.FileBase.FBase.name);
                                                                        Session.io.OutRawln ('B. Filename         : ' + Session.FileBase.FBase.filename);
                                                                        Session.io.OutRawln ('C. Display File     : ' + Session.FileBase.FBase.dispfile);
                                                                        Session.io.OutRawln ('D. List ACS         : ' + Session.FileBase.FBase.Listacs);
                                                                        Session.io.OutRawln ('E. Sysop ACS        : ' + Session.FileBase.FBase.SysopACS);
                                                                        Session.io.OutRawln ('F. Upload ACS       : ' + Session.FileBase.FBase.ulacs);
                                                                        Session.io.OutRawln ('G. Download ACS     : ' + Session.FileBase.FBase.dlacs);
                                                                        Session.io.OutRawln ('H. Storage Path     : ' + Session.FileBase.FBase.path);
                                                                        Session.io.OutRawln ('I. Password         : ' + Session.FileBase.FBase.password);
                          Session.io.OutRawln ('J. Show Uploader    : ' + Session.io.OutYN(Session.FileBase.FBase.ShowUL));
                          Session.io.OutRawLn ('K. Default New Scan : ' + ST[Session.FileBase.FBase.DefScan]);
                          Session.io.OutRawLn ('L. CD-ROM Area      : ' + Session.io.OutYN(Session.FileBase.FBase.IsCDROM));
                          Session.io.OutRawLn ('M. All Files Free   : ' + Session.io.OutYN(Session.FileBase.FBase.IsFREE));
                          Session.io.OutRawLn ('N. FTP Base Name    : ' + Session.FileBase.FBase.FTPName);
                          Session.io.OutRawLn ('O. FTP List ACS     : ' + Session.FileBase.FBase.FTPACS);
                                                                        Session.io.OutFull ('|CR|09([) Prev, (]) Next, (Q)uit: ');
                                                                        case Session.io.OneKey('[]ABCDEFGHIJKLMNOQ', True) of
                                                                                '[' : If FilePos(Session.FileBase.FBaseFile) > 1 Then Begin
                                                                            Seek    (Session.FileBase.FBaseFile, FilePos(Session.FileBase.FBaseFile)-1);
                                                                          Write (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                             Seek    (Session.FileBase.FBaseFile, FilePos(Session.FileBase.FBaseFile)-2);
                                          Read    (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                                                                                        End;
                                   ']' : If FilePos(Session.FileBase.FBaseFile) < FileSize(Session.FileBase.FBaseFile) Then Begin
                                     Seek (Session.FileBase.FBaseFile, FilePos(Session.FileBase.FBaseFile)-1);
                                 Write (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                                     Read (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                                                                                        End;
                                        'A' : Session.FileBase.FBase.Name     := Session.io.InXY(23, 3, 40, 40, 11, Session.FileBase.FBase.Name);
                                        'B' : Session.FileBase.FBase.FileName := Session.io.InXY(23, 4, 40, 40, 11, Session.FileBase.FBase.FileName);
                                        'C' : Session.FileBase.FBase.DispFile := Session.io.InXY(23, 5,  8,  8, 11, Session.FileBase.FBase.DispFile);
                                        'D' : Session.FileBase.FBase.ListACS      := Session.io.InXY(23, 6, 20, 20, 11, Session.FileBase.FBase.ListACS);
                                        'E' : Session.FileBase.FBase.SysopACS := Session.io.InXY(23, 7, 20, 20, 11, Session.FileBase.FBase.SysopACS);
                                        'F' : Session.FileBase.FBase.ULacs    := Session.io.InXY(23, 8, 20, 20, 11, Session.FileBase.FBase.ULacs);
                                        'G' : Session.FileBase.FBase.DLacs    := Session.io.InXY(23, 9, 20, 20, 11, Session.FileBase.FBase.DLacs);
                                        'H' : Session.FileBase.FBase.Path     := CheckPath(Session.io.InXY(23, 10, 39, 39, 11, Session.FileBase.FBase.Path));
                                        'I' : Session.FileBase.FBase.Password := Session.io.InXY(23, 11, 15, 15, 12, Session.FileBase.FBase.Password);
                                        'J' : Session.FileBase.FBase.ShowUL  := Not Session.FileBase.FBase.ShowUL;
                                        'K' : If Session.FileBase.FBase.DefScan > 1 Then Session.FileBase.FBase.DefScan := 0 Else Inc(Session.FileBase.FBase.DefScan);
                                                                                'L' : Session.FileBase.FBase.IsCDROM := Not Session.FileBase.FBase.IsCDROM;
                                                                                'M' : Session.FileBase.FBase.IsFREE  := Not Session.FileBase.FBase.IsFREE;
                                                                                'N' : Session.FileBase.FBase.FtpName := Session.io.InXY(23, 16, 40, 60, 11, Session.FileBase.FBase.FtpName);
                                                                                'O' : Session.FileBase.FBase.FtpACS  := Session.io.InXY(23, 17, 30, 30, 11, Session.FileBase.FBase.FtpACS);
                                                                                'Q' : Break;
                                                                        End;
                                                                Until False;
                                                                Seek    (Session.FileBase.FBaseFile, FilePos(Session.FileBase.FBaseFile) - 1);
                                                                Write (Session.FileBase.FBaseFile, Session.FileBase.FBase);
                                                        End;
                                                End;

                        'M' : Begin
                                                        Session.io.OutRaw ('Move which? ');
                                                        A := strS2I(Session.io.GetInput(3, 3, 12, ''));

                                                        Session.io.OutRaw ('Move before? (1-' + strI2S(FileSize(Session.FileBase.FBaseFile) + 1) + '): ');
                                                        B := strS2I(Session.io.GetInput(3, 3, 12, ''));

                         If (A > 0) and (A <= FileSize(Session.FileBase.FBaseFile)) and (B > 0) and (B <= FileSize(Session.FileBase.FBaseFile) + 1) Then Begin
                                                                Seek (Session.FileBase.FBaseFile, A - 1);
                                                                Read (Session.FileBase.FBaseFile, Session.FileBase.FBase);

                                                                AddRecord (Session.FileBase.FBaseFile, B, SizeOf(FBaseRec));
                                                                Write  (Session.FileBase.FBaseFile, Session.FileBase.FBase);

                                                                If A > B Then Inc(A);

                                                                KillRecord (Session.FileBase.FBaseFile, A, SizeOf(FBaseRec));
                                                        End;
                                                End;
                        'Q' : Break;
                End;
        Until False;
        Close (Session.FileBase.FBaseFile);
End;

End.

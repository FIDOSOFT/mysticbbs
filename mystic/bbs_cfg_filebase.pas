Unit bbs_cfg_FileBase;

{$I M_OPS.PAS}

Interface

Procedure Configuration_FileBaseEditor;

Implementation

Uses
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_QuickSort,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_Cfg_Common;

Type
  RecFileBaseFile = File of RecFileBase;

Procedure SortFileBases (Var List: TAnsiMenuList; Var FBaseFile: RecFileBaseFile);
Var
  TempBase  : RecFileBase;
  TempFile  : File of RecFileBase;
  Sort      : TQuickSort;
  SortFirst : Word;
  SortLast  : Word;
  Count     : Word;
Begin
  If Not GetSortRange(List, SortFirst, SortLast) Then Exit;

  ShowMsgBox (3, ' Sorting... ');

  Sort := TQuickSort.Create;

  For Count := SortFirst to SortLast Do Begin
    Seek (FBaseFile, Count - 1);
    Read (FBaseFile, TempBase);

    Sort.Add (strUpper(strStripPipe(TempBase.Name)), Count - 1);
  End;

  Sort.Sort (1, Sort.Total, qAscending);

  Close  (FBaseFile);
  ReName (FBaseFile, bbsCfg.DataPath + 'fbases.sortbak');

  Assign (TempFile, bbsCfg.DataPath + 'fbases.sortbak');
  Reset  (TempFile);

  Assign  (FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  ReWrite (FBaseFile);

  While FilePos(TempFile) < SortFirst - 1 Do Begin
    Read  (TempFile, TempBase);
    Write (FBaseFile, TempBase);
  End;

  For Count := 1 to Sort.Total Do Begin
    Seek  (TempFile, Sort.Data[Count]^.Ptr);
    Read  (TempFile, TempBase);
    Write (FBaseFile, TempBase);
  End;

  Seek (TempFile, SortLast);

  While Not Eof(TempFile) Do Begin
    Read  (TempFile, TempBase);
    Write (FBaseFile, TempBase);
  End;

  Close (TempFile);
  Erase (TempFile);

  Sort.Free;
End;

Procedure EditFileBase (Var FBase: RecFileBase);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09File Base Edit|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Index ' + strI2S(FBase.Index) + ' ';

  Box.Open (6, 5, 75, 21);

  VerticalLine (22, 7, 19);
  VerticalLine (69, 7, 9);

  Form.AddStr  ('N', ' Base Name'    , 11,  7, 24,  7, 11, 30, 40, @FBase.Name, Topic + 'File base name');
  Form.AddStr  ('F', ' FTP Name'     , 12,  8, 24,  8, 10, 30, 60, @FBase.FTPName, Topic + 'Base name in FTP directory list');
  Form.AddStr  ('D', ' Display File' ,  8,  9, 24,  9, 14, 20, 20, @FBase.DispFile, Topic + 'Display file shown before listing');
  Form.AddStr  ('T', ' Template'     , 12, 10, 24, 10, 10, 20, 20, @FBase.Template, Topic + 'Lightbar list template');
  Form.AddStr  ('L', ' List ACS '    , 12, 11, 24, 11, 10, 30, 30, @FBase.ListACS, Topic + 'ACS to list files');
  Form.AddStr  ('U', ' Upload ACS '  , 10, 12, 24, 12, 12, 30, 30, @FBase.ULACS, Topic + 'ACS to upload files');
  Form.AddStr  ('D', ' Download ACS ',  8, 13, 24, 13, 14, 30, 30, @FBase.DLACS, Topic + 'ACS to download files');
  Form.AddStr  ('C', ' Comment ACS ' ,  9, 14, 24, 14, 13, 30, 30, @FBase.CommentACS, Topic + 'ACS to comment and rate files');
  Form.AddStr  ('P', ' FTP ACS'      , 13, 15, 24, 15,  9, 30, 30, @FBase.FTPACS, Topic + 'ACS to access via FTP');
  Form.AddStr  ('S', ' Sysop ACS '   , 11, 16, 24, 16, 11, 30, 30, @FBase.SysopACS, Topic + 'ACS for Sysop access');
  Form.AddTog  ('E', ' Default Scan' ,  8, 17, 24, 17, 14,  6, 0, 2, 'No Yes Always', @FBase.DefScan, Topic + 'Default scan setting');
  Form.AddPath ('I', ' File Path'    , 11, 18, 24, 18, 11, 50, 120, @FBase.Path, Topic + 'Directory where files are stored');
  Form.AddStr  ('A', ' Data File'    , 11, 19, 24, 19, 11, 30, 40,  @FBase.FileName, Topic + 'Data file name');

  Form.AddBits ('R', ' Free Files'   , 57,  7, 71,  7, 12, FBFreeFiles, @FBase.Flags, Topic + 'Files in base are free?');
  Form.AddBits ('M', ' Slow Media'   , 57,  8, 71,  8, 12, FBSlowMedia, @FBase.Flags, Topic + 'Files stored on slow media device?');
  Form.AddBits (#01, ' Uploader'     , 59,  9, 71,  9, 10, FBShowUpload, @FBase.Flags, Topic + 'Show upload in listing');

  Repeat
    Case Form.Execute of
      #27 : Break;
    End;
  Until False;

  FBase.FTPName := strReplace(FBase.FTPName, '/', '_');
  FBase.FTPName := strReplace(FBase.FTPName, '\', '_');

  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure Configuration_FileBaseEditor;
Var
  Box       : TAnsiMenuBox;
  List      : TAnsiMenuList;
  Copied    : RecFileBase;
  HasCopy   : Boolean = False;
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;

  Function GetPermanentIndex (Start: LongInt) : LongInt;
  Var
    TempBase : RecFileBase;
    SavedRec : LongInt;
  Begin
    Result   := Start;
    SavedRec := FilePos(FBaseFile);

    Reset (FBaseFile);

    While Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, TempBase);

      If Result = TempBase.Index Then Begin
        If Result >= 2000000 Then Result := 0;

        Inc   (Result);
        Reset (FBaseFile);
      End;
    End;

    Seek (FBaseFile, SavedRec);
  End;

  Procedure MakeList;
  Begin
    List.Clear;

    Reset (FBaseFile);

    While Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, FBase);

      List.Add(strPadR(strI2S(FilePos(FBaseFile)), 5, ' ') + '  ' + strStripPipe(FBase.Name), 0);
    End;

    List.Add('', 2);
  End;

  Procedure InsertRecord;
  Begin
    AddRecord (FBaseFile, List.Picked, SizeOf(RecFileBase));

    FillChar (FBase, SizeOf(RecFileBase), 0);

    With FBase Do Begin
      FileName := 'new';
      Path     := bbsCfg.SystemPath + 'files' + PathChar + 'new' + PathChar;
      Name     := 'New File Base';
      FtpName  := Name;
      DefScan  := 1;
      SysopACS := 's255';
      Template := 'ansiflst';
      Flags    := FBShowUpload;
      Created  := CurDateDos;
      Index    := GetPermanentIndex(FileSize(FBaseFile));
    End;

    Write (FBaseFile, FBase);
  End;

Var
  KillData : Boolean;
  Count    : LongInt;
Begin
  Assign (FBaseFile, bbsCfg.DataPath + 'fbases.dat');

  If Not ioReset(FBaseFile, SizeOf(FBase), fmRWDN) Then
    Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.AllowTag := True;
  List.SearchY  := 21;

  //If FileSize(FBaseFile) = 0 Then InsertRecord;

  Box.Open (15, 5, 65, 21);

  WriteXY (17,  6, 112, '#####  File Base Description');
  WriteXY (16,  7, 112, strRep(#196, 49));
  WriteXY (16, 19, 112, strRep(#196, 49));
  WriteXY (29, 20, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (15, 7, 65, 19);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|P-Paste|S-Sort|') of
              'I' : Begin
                      InsertRecord;
                      MakeList;
                    End;
              'D' : If List.Marked > 0 Then Begin
                      If ShowMsgBox(1, 'Delete ' + strI2S(List.Marked) + ' bases?') Then Begin
                        KillData := ShowMsgBox(1, 'Delete data files for ' + strI2S(List.Marked) + ' bases?');

                        For Count := List.ListMax DownTo 1 Do
                          If List.List[Count]^.Tagged = 1 Then Begin
                            Seek (FBaseFile, Count - 1);
                            Read (FBaseFile, FBase);

                            KillRecord (FBaseFile, Count, SizeOf(FBase));

                            If KillData Then Begin
                              FileErase (bbsCfg.DataPath + FBase.FileName + '.dir');
                              FileErase (bbsCfg.DataPath + FBase.FileName + '.dat');
                              FileErase (bbsCfg.DataPath + FBase.FileName + '.scn');
                            End;
                          End;

                        MakeList;
                      End;
                    End Else
                    If (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        Seek (FBaseFile, List.Picked - 1);
                        Read (FBaseFile, FBase);

                        KillRecord (FBaseFile, List.Picked, SizeOf(FBase));

                        If ShowMsgBox(1, 'Delete data files?') Then Begin
                          FileErase (bbsCfg.DataPath + FBase.FileName + '.dir');
                          FileErase (bbsCfg.DataPath + FBase.FileName + '.dat');
                          FileErase (bbsCfg.DataPath + FBase.FileName + '.scn');
                        End;

                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (FBaseFile, List.Picked - 1);
                      Read (FBaseFile, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (FBaseFile, List.Picked, SizeOf(FBase));

                      Copied.Index   := GetPermanentIndex(FileSize(FBaseFile));
                      Copied.Created := CurDateDos;

                      Write (FBaseFile, Copied);

                      MakeList;
                    End;
              'S' : SortFileBases (List, FBaseFile);
            End;
      #13 : If List.Picked < List.ListMax Then Begin
              Seek (FBaseFile, List.Picked - 1);
              Read (FBaseFile, FBase);

              EditFileBase(FBase);

              Seek  (FBaseFile, List.Picked - 1);
              Write (FBaseFile, FBase);
            End;
      #27 : Break;
    End;
  Until False;

  Close (FBaseFile);

  Box.Close;
  List.Free;
  Box.Free;
End;

End.

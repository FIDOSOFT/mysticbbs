Unit MUTIL_AllFiles;

{$I M_OPS.PAS}

Interface

Procedure uAllFilesList;

Implementation

Uses
  m_DateTime,
  m_Strings,
  m_FileIO,
  mUtil_Common,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase;

Const
  TotalFiles : Cardinal = 0;
  TotalSize  : Cardinal = 0;
  TotalBases : Cardinal = 0;
  BaseFiles  : Cardinal = 0;
  BaseSize   : Cardinal = 0;

Procedure uAllFilesList;
Var
  OutFile  : Text;
  Buffer   : Array[1..1024 * 4] of Char;
  BaseFile : File of RecFileBase;
  ListFile : File of RecFileList;
  DescFile : File;
  Base     : RecFileBase;
  List     : RecFileList;
  DescStr  : String[50];
  Count    : LongInt;
Begin
  ProcessName   ('Generating AllFiles List', True);
  ProcessResult (rWORKING, False);

  Assign     (OutFile, INI.ReadString(Header_ALLFILES, 'filename', 'allfiles.txt'));
  SetTextBuf (OutFile, Buffer);
  ReWrite    (OutFile);

  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot create output file', True);
    ProcessResult (rWARN, True);

    Exit;
  End;

  Assign (BaseFile, bbsCfg.DataPath + 'fbases.dat');

  If Not ioReset (BaseFile, SizeOf(RecFileBase), fmRWDN) Then Begin
    ProcessStatus ('Cannot open fbases.dat', True);
    ProcessResult (rWARN, True);

    Close (OutFile);

    Exit;
  End;

  While Not Eof(BaseFile) Do Begin
    BaseFiles := 0;
    BaseSize  := 0;

    Read (BaseFile, Base);

    // If Excludedbase then continue;

    Assign (ListFile, bbsCfg.DataPath + Base.FileName + '.dir');
    Assign (DescFile, bbsCfg.DataPath + Base.FileName + '.des');

    If Not ioReset (ListFile, SizeOf(RecFileList), fmRWDN) Then Continue;

    If Not ioReset (DescFile, 1, fmRWDN) Then Begin
      Close (ListFile);

      Continue;
    End;

    While Not Eof(ListFile) Do Begin
      Read (ListFile, List);

      If List.Flags AND FDirDeleted <> 0 Then Continue;
      // check exclude offline, exclude failed, etc

      If BaseFiles = 0 Then Begin
        Inc (TotalBases);

        WriteLn (OutFile, '');
        WriteLn (OutFile, strStripPipe(Base.Name));
        WriteLn (OutFile, strRep('=', strMCILen(Base.Name)));
        WriteLn (OutFile, '');
        WriteLn (OutFile, 'Filename   Size    Date    Description');
        WriteLn (OutFile, strrep('-', 79));
      End;

      Inc (BaseFiles);
      Inc (TotalFiles);
      Inc (BaseSize,  List.Size DIV 1024);
      Inc (TotalSize, List.Size DIV 1024);

      WriteLn (OutFile, List.FileName);
      Write   (OutFile, '    ' + strPadL(strComma(List.Size), 11, ' ') + '  ' + DateDos2Str(List.DateTime, 1 {dateformat}) + '  ');

      Seek (DescFile, List.DescPtr);

      For Count := 1 to List.DescLines Do Begin
        BlockRead (DescFile, DescStr[0], 1);
        BlockRead (DescFile, DescStr[1], Ord(DescStr[0]));

        If Count = 1 Then
          WriteLn (OutFile, DescStr)
        Else
          WriteLn (OutFile, strRep(' ', 27) + DescStr);
      End;
    End;

    Close (ListFile);
    Close (DescFile);

    If BaseFiles > 0 Then Begin
      WriteLn (OutFile, strRep('-', 79));
      WriteLn (OutFile, 'Total files: ' + strComma(BaseFiles) + ' (' + strComma(BaseSize DIV 1024) + 'mb)');
    End;
  End;

  If TotalFiles > 0 Then Begin
    WriteLn (OutFile, '');
    WriteLn (OutFile, '* Total bases: ' + strComma(TotalBases));
    WriteLn (OutFile, '* Total files: ' + strComma(TotalFiles));
    WriteLn (OutFile, '* Total  size: ' + strComma(TotalSize DIV 1024) + 'mb');
  End;

  Close (BaseFile);
  Close (OutFile);

  ProcessStatus ('Added |15' + strI2S(TotalFiles) + ' |07file(s)', True);
  ProcessResult (rDONE, True);
End;

End.

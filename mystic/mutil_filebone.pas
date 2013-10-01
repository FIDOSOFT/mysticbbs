Unit MUTIL_FileBone;

{$I M_OPS.PAS}

Interface

Procedure uImportFileBone;

Implementation

Uses
  m_Types,
  m_Strings,
  m_FileIO,
  mUtil_Common,
  mUtil_Status,
  BBS_Records;

Procedure uImportFileBone;
Var
  InFile       : Text;
  Buffer       : Array[1..2048] of Byte;
  Str          : String;
  CreatedBases : LongInt = 0;
  RootDir      : String;
  BaseName     : String;
  BaseTag      : String;
  FBase        : RecFileBase;
Begin
  ProcessName   ('Import FILEBONE.NA', True);
  ProcessResult (rWORKING, False);

  Assign     (InFile, INI.ReadString(Header_FILEBONE, 'filename', 'filebone.na'));
  SetTextBuf (InFile, Buffer);

  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot find NA file', True);
    ProcessResult (rWARN, True);

    Exit;
  End;

  RootDir := DirSlash(INI.ReadString(Header_FILEBONE, 'root_dir', ''));

  If RootDir = PathSep Then Begin
    ProcessStatus ('No root directory', True);
    ProcessResult (rFATAL, True);

    Exit;
  End;

  If Not DirExists(RootDir) Then Begin
    ProcessStatus ('Root directory does not exist', True);
    ProcessResult (rFATAL, True);

    // While DirCreate can 'recursively' create, this is added to prevent
    // user mistakes in configuration! :)

    Exit;
  End;

  While Not Eof(InFile) Do Begin
    ReadLn(InFile, Str);

    Str := strReplace(strStripB(Str, ' '), #9, ' ');

    If strWordGet(1, strUpper(Str), ' ') <> 'AREA' Then Continue;

    If Pos('!', strWordGet(4, Str, ' ')) = 0 Then Continue;

    BaseName := strStripLow(strStripB(Copy(Str, strWordPos(5, str, ' '), 255), ' '));
    BaseTag  := strStripLow(strWordGet(2, Str, ' '));

    ProcessStatus (BaseName, False);

    If Not IsDupeFBase(BaseTag) Then Begin
      FillChar (FBase, SizeOf(FBase), 0);
      Inc      (CreatedBases);

      If INI.ReadString(Header_FILEBONE, 'lowercase_filename', '1') = '1' Then
        BaseTag := strLower(BaseTag);

      FBase.Index      := GenerateFBaseIndex;
      FBase.Name       := BaseName;
      FBase.FTPName    := strReplace(BaseName, ' ', '_');
      FBase.FileName   := BaseTag;
      FBase.Path       := DirSlash(RootDir + BaseTag);
      FBase.DefScan    := strS2I(INI.ReadString(Header_FILEBONE, 'new_scan', '1'));
      FBase.DispFile   := INI.ReadString(Header_FILEBONE, 'dispfile', '');
      FBase.Template   := INI.ReadString(Header_FILEBONE, 'template', 'ansiflst');
      FBase.ListACS    := INI.ReadString(Header_FILEBONE, 'acs_list', '');
      FBase.FTPACS     := INI.ReadString(Header_FILEBONE, 'acs_ftp', '');
      FBase.DLACS      := INI.ReadString(Header_FILEBONE, 'acs_download', '');
      FBase.ULACS      := INI.ReadString(Header_FILEBONE, 'acs_upload', '');
      FBase.CommentACS := INI.ReadString(Header_FILEBONE, 'acs_comment', '');
      FBase.SysopACS   := INI.ReadString(Header_FILEBONE, 'acs_sysop', 's255');

      FBase.FileName := strReplace(FBase.FileName, '/', '_');
      FBase.FileName := strReplace(FBase.FileName, '\', '_');

      If INI.ReadString(Header_FILEBONE, 'free_files', '0') = '1' Then
        FBase.Flags := FBase.Flags OR FBFreeFiles;

      If INI.ReadString(Header_FILEBONE, 'show_uploader', '1') = '1' Then
        FBase.Flags := FBase.Flags OR FBShowUpload;

      DirCreate   (FBase.Path);
      AddFileBase (FBase);
    End;
  End;

  Close (InFile);

  ProcessStatus ('Created |15' + strI2S(CreatedBases) + ' |07base(s)', True);
  ProcessResult (rDONE, True);
End;

End.

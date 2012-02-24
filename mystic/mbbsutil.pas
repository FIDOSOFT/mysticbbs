// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

Program MBBSUTIL;

// post a text file to msg base?
// auto mass upload
// export AREAS.BBS?
// import FIDONET.NA
// .TIC stuff?

{$I M_OPS.PAS}

Uses
  CRT,
  Dos,
  m_DateTime,
  m_Strings,
  m_QuickSort,
  m_FileIO,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

{$I RECORDS.PAS}

Const
  FilePack   : Boolean = False;
  FileSort   : Boolean = False;
  FileCheck  : Boolean = False;
  FileUpload : Boolean = False;
  BBSPack    : Boolean = False;
  BBSSort    : Boolean = False;
  BBSKill    : Boolean = False;
  UserKill   : Boolean = False;
  UserPack   : Boolean = False;
  MsgTrash   : Boolean = False;
  NodeCheck  : Boolean = True;

  UserKillDays : Integer = 0;
  BBSSortID    : String  = '';
  BBSSortType  : Byte    = 0;
  BBSKillID    : String  = '';
  BBSKillDays  : Integer = 0;
  TrashFile    : String  = '';
  TempPath     : String  = '';

Var
  ConfigFile : File of RecConfig;
  Config     : RecConfig;

Type
  JamLastType = Record
    NameCrc  : LongInt;
    UserNum  : LongInt;
    LastRead : LongInt;
    HighRead : LongInt;
  End;

  SquLastType = LongInt;

Function ShellDOS (ExecPath: String; Command: String) : LongInt;
Begin
  // needs to save/restore screen

  If ExecPath <> '' Then DirChange(ExecPath);

  {$IFDEF UNIX}
    Result := Shell (Command);
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;

    Exec (GetEnv('COMSPEC'), Command);

    Result := DosExitCode;
  {$ENDIF}

  DirChange(Config.SystemPath);
End;

Procedure ExecuteArchive (FName: String; Temp: String; Mask: String; Mode: Byte);
{mode: 1 = pack, 2 = unpack}
Var
  A       : Byte;
  Temp2   : String[60];
  ArcFile : File of RecArchive;
  Arc     : RecArchive;
Begin
  Temp := strUpper(JustFileExt(FName));

  Assign (ArcFile, Config.DataPath + 'archive.dat');
  {$I-} Reset (ArcFile); {$I+}

  If IoResult <> 0 Then Exit;

  Repeat
    If Eof(ArcFile) Then Begin
      Close (ArcFile);
      Exit;
    End;

    Read (ArcFile, Arc);

    If (Not Arc.Active) or (Arc.OSType <> OSType) Then Continue;

    If strUpper(Arc.Ext) = Temp Then Break;
  Until False;

  Close (ArcFile);

  Case Mode of
    1 : Temp2 := Arc.Pack;
    2 : Temp2 := Arc.Unpack;
  End;

  If Temp2 = '' Then Exit;

  Temp := '';
  A    := 1;

  While A <= Length(Temp2) Do Begin
    If Temp2[A] = '%' Then Begin
      Inc(A);
      If Temp2[A] = '1' Then Temp := Temp + FName Else
      If Temp2[A] = '2' Then Temp := Temp + Mask Else
      If Temp2[A] = '3' Then Temp := Temp + TempPath;
    End Else
      Temp := Temp + Temp2[A];

    Inc(A);
  End;

  ShellDOS ('', Temp);
End;

Procedure Update_Status (Str: String);
Begin
  GotoXY (44, WhereY);
  Write  (strPadR(Str, 35, ' '));
End;

Procedure Update_Bar (Cur, Total: Integer);
Var
  Percent : Byte;
Begin
  Percent := Round(Cur / Total * 100 / 10);

  GotoXY (24, WhereY);
  Write  (strRep(#178, Percent));
  Write  (strRep(#176, 10 - Percent));
  Write  (strPadL(strI2S(Percent * 10) + '%', 5, ' '));
End;

Procedure Show_Help;
Begin
  WriteLn ('Usage: MBBSUTIL <Options>');
  WriteLn;
  WriteLn ('The following command line options are available:');
  WriteLn;
  WriteLn ('-BKILL  <ID> <Days> Delete BBSes which haven''t been verified in <DAYS>');
  WriteLn ('-BPACK              Pack all BBS lists');
  WriteLn ('-BSORT  <ID> <Type> Sorts and packs BBS list by <type>');
  WriteLn ('-FCHECK             Checks file entries for correct size and status');
  WriteLn ('-FPACK              Pack file bases');
  WriteLn ('-FSORT              Sort file base entries by filename');
  WriteLn ('-FUPLOAD            Mass upload all files into filebases');
  WriteLn ('-MTRASH <File>      Delete messages to/from users listed in <File>');
  WriteLn ('-NOCHECK            Bypass online user check at startup');
  WriteLn ('-UKILL  <Days>      Delete users who have not called in <DAYS>');
  WriteLn ('-UPACK              Pack user database');
End;

(***************************************************************************)
(***************************************************************************)
(***************************************************************************)

Procedure Sort_File_Bases;
Var
  SortList  : TQuickSort;
  FBaseFile : File of FBaseRec;
  FBase     : FBaseRec;
  FDirFile  : File of RecFileList;
  TFDirFile : File of RecFileList;
  FDir      : RecFileList;
  A         : Word;
Begin
  Write ('Sorting File Bases   : ');

  Assign (FBaseFile, Config.DataPath + 'fbases.dat');
  {$I-} Reset (FBaseFile); {$I+}
  If IoResult <> 0 Then Exit;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    Update_Bar    (FilePos(FBaseFile), FileSize(FBaseFile));
    Update_Status (strStripMCI(FBase.Name));

    If FileRename (Config.DataPath + FBase.FileName + '.dir', Config.DataPath + FBase.FileName + '.dib') Then Begin
      Assign (FDirFile, Config.DataPath + FBase.FileName + '.dib');
      Reset  (FDirFile);

      Assign  (TFDirFile, Config.DataPath + FBase.FileName + '.dir');
      ReWrite (TFDirFile);

      SortList := TQuickSort.Create;

      While Not Eof(FDirFile) Do Begin
        Read (FDirFile, FDir);
        If (FDir.Flags AND FDirDeleted = 0) Then
          {$IFDEF FS_SENSITIVE}
            SortList.Add(FDir.FileName, FilePos(FDirFile) - 1);
          {$ELSE}
            SortList.Add(strUpper(FDir.FileName), FilePos(FDirFile) - 1);
          {$ENDIF}
      End;

      SortList.Sort(1, SortList.Total, qDescending);

      For A := 1 to SortList.Total Do Begin
        Seek  (FDirFile, SortList.Data[A]^.Ptr);
        Read  (FDirFile, FDir);
        Write (TFDirFile, FDir);
      End;

      SortList.Free;

      Close (FDirFile);
      Erase (FDirFile);
      Close (TFDirFile);
    End;
  End;

  Close (FBaseFile);

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Pack_File_Bases;
Var
  A         : Byte;
  Temp      : String[50];
  FDirFile  : File of RecFileList;
  TFDirFile : File of RecFileList;
  FDir      : RecFileList;
  DataFile  : File;
  TDataFile : File;
  FBaseFile : File of FBaseRec;
  FBase     : FBaseRec;
Begin
  Write ('Packing File Bases   : ');

  Assign (FBaseFile, Config.DataPath + 'fbases.dat');
  {$I-} Reset (FBaseFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    Update_Bar    (FilePos(FBaseFile), FileSize(FBaseFile));
    Update_Status (strStripPipe(FBase.Name));

    If FileRename (Config.DataPath + FBase.FileName + '.dir', Config.DataPath + FBase.FileName + '.dib') Then Begin
      Assign  (FDirFile, Config.DataPath + FBase.FileName + '.dib');
      Reset   (FDirFile);
      Assign  (TFDirFile, Config.DataPath + FBase.FileName + '.dir');
      ReWrite (TFDirFile);

      If FileRename (Config.DataPath + FBase.FileName + '.des', Config.DataPath + FBase.FileName + '.deb') Then Begin

        Assign (TDataFile, Config.DataPath + FBase.FileName + '.deb');
        Reset  (TDataFile, 1);

        Assign (DataFile, Config.DataPath + FBase.FileName + '.des');
        ReWrite (DataFile, 1);

        While Not Eof(FDirFile) Do Begin
          Read (FDirFile, FDir);
          If FDir.Flags AND FDirDeleted = 0 Then Begin
            Seek (TDataFile, FDir.DescPtr);

            FDir.DescPtr := FilePos(DataFile);

            For A := 1 to FDir.DescLines Do Begin
              BlockRead (TDataFile, Temp[0], 1);
              BlockRead (TDataFile, Temp[1], Ord(Temp[0]));

              BlockWrite (DataFile, Temp[0], 1);
              BlockWrite (DataFile, Temp[1], Ord(Temp[0]));
            End;

            Write (TFDirFile, FDir);
          End;

        End;

        Close (TDataFile);
        Erase (TDataFile); {delete backup file}
        Close (DataFile);
      End;

      Close (FDirFile);
      Erase (FDirFile); {delete backup file}
      Close (TFDirFile);
    End;
  End;

  Close (FBaseFile);

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Check_File_Bases;
Var
  FBaseFile : File of FBaseRec;
  FBase     : FBaseRec;
  FDirFile  : File of RecFileList;
  FDir      : RecFileList;
  TFDirFile : File of RecFileList;
  DF        : File of Byte;
Begin
  Write ('Checking File Bases  : ');

  Assign (FBaseFile, Config.DataPath + 'fbases.dat');
  {$I-} Reset (FBaseFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    Update_Bar    (FilePos(FBaseFile), FileSize(FBaseFile));
    Update_Status (strStripPipe(FBase.Name));

    If FileRename (Config.DataPath + FBase.FileName + '.dir', Config.DataPath + FBase.FileName + '.dib') Then Begin
      Assign  (FDirFile, Config.DataPath + FBase.FileName + '.dib');
      Reset   (FDirFile);
      Assign  (TFDirFile, Config.DataPath + FBase.FileName + '.dir');
      ReWrite (TFDirFile);

      While Not Eof(FDirFile) Do Begin
        Read (FDirFile, FDir);

        If FDir.Flags And FDirDeleted = 0 Then Begin
          Assign (DF, FBase.Path + FDir.FileName);
          {$I-} Reset (DF); {$I+}
          If IoResult <> 0 Then
            FDir.Flags := FDir.Flags AND FDirOffline
          Else Begin
            FDir.Size := FileSize(DF);

            If FDir.Size = 0 Then
              FDir.Flags := FDir.Flags OR FDirOffline
            Else
              FDir.Flags := FDir.Flags AND NOT FDirOffline;

            Close (DF);
          End;

          Write (TFDirFile, FDir);
        End;
      End;

      Close (FDirFile); {delete backup file}
      Erase (FDirFile);
      Close (TFDirFile);
    End;
  End;

  Close (FBaseFile);

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Pack_BBS_List;
Var
  TBBSFile : File of BBSListRec;
  BBSFile  : File of BBSListRec;
  BBSList  : BBSListRec;
  Dir      : SearchRec;
  D        : DirStr;
  N        : NameStr;
  E        : ExtStr;
Begin
  Write ('Packing BBS File     :');

  FindFirst (Config.DataPath + '*.bbi', AnyFile - Directory, Dir);

  While DosError = 0 Do Begin

    FSplit (Dir.Name, D, N, E);

    If FileRename (Config.DataPath + Dir.Name, Config.DataPath + N + '.bbz') Then Begin

      Assign (TBBSFile, Config.DataPath + N + '.bbz');
      Reset  (TBBSFile);

      Assign  (BBSFile, Config.DataPath + Dir.Name);
      ReWrite (BBSFile);

      While Not Eof(TBBSFile) Do Begin
        Read (TBBSFile, BBSList);

        If Not BBSList.Deleted Then Write (BBSFile, BBSList);

        Update_Bar    (FilePos(TBBSFile), FileSize(TBBSFile));
        Update_Status (BBSList.BBSName);
      End;

      Close (TBBSFile);
      Erase (TBBSFile);
      Close (BBSFile);
    End;

    FindNext(Dir);
  End;

  FindClose(Dir);

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Sort_BBS_List;

  Procedure SortList;
  Var
    TBBSFile,
    BBSFile  : File of BBSListRec;
    BBS      : BBSListRec;
    SortList : TQuickSort;
    Str      : String;
    A        : Word;
  Begin
    If FileRename (Config.DataPath + BBSSortID + '.bbi', Config.DataPath + BBSSortID + '.bbz') Then Begin

      Update_Status (BBSSortID);

      Assign (TBBSFile, Config.DataPath + BBSSortID + '.bbz');
      Reset  (TBBSFile);

      Assign  (BBSFile, Config.DataPath + BBSSortID + '.bbi');
      ReWrite (BBSFile);

      SortList := TQuickSort.Create;

      While Not Eof(TBBSFile) Do Begin
        Read (TBBSFile, BBS);

        Update_Bar (FilePos(TBBSFile), FileSize(TBBSFile));

        If Not BBS.Deleted Then Begin
          Case BBSSortType of
            0 : Str := strUpper(BBS.Phone);
            1 : Str := strUpper(BBS.Telnet);
            2 : Str := strUpper(BBS.BBSName);
            3 : Str := strUpper(BBS.Location);
          End;

          SortList.Add(Str, FilePos(TBBSFile) - 1);
        End;
      End;

      SortList.Sort(1, SortList.Total, qDescending);

      For A := 1 to SortList.Total Do Begin
        Seek  (TBBSFile, SortList.Data[A]^.Ptr);
        Read  (TBBSFile, BBS);
        Write (BBSFile, BBS);
      End;

      SortList.Free;

      Close (TBBSFile);
      Erase (TBBSFile);
      Close (BBSFile);
    End;
  End;

Var
  D   : DirStr;
  N   : NameStr;
  E   : ExtStr;
  Dir : SearchRec;
Begin
  Write ('Sorting BBS File     :');

  If strUpper(BBSSortID) = 'ALL' Then Begin
    FindFirst (Config.DataPath + '*.bbi', AnyFile - Directory, Dir);

    While DosError = 0 Do Begin
      FSplit (Dir.Name, D, N, E);
      BBSSortID := N;
      SortList;
      FindNext(Dir);
    End;

    FindClose(Dir);
  End Else
    SortList;

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Kill_BBS_List;

  Procedure PackFile;
  Var
    TBBSFile : File of BBSListRec;
    BBSFile  : File of BBSListRec;
    BBS      : BBSListRec;
  Begin
    If FileRename (Config.DataPath + BBSKillID + '.bbi', Config.DataPath + BBSKillID + '.bbb') Then Begin

      Assign (TBBSFile, Config.DataPath + BBSKillID + '.bbb');
      Reset  (TBBSFile);

      Assign  (BBSFile, Config.DataPath + BBSKillID + '.bbi');
      ReWrite (BBSFile);

      While Not Eof(TBBSFile) Do Begin
        Read (TBBSFile, BBS);

        Update_Bar (FilePos(TBBSFile), FileSize(TBBSFile));

        If DaysAgo(BBS.Verified) >= BBSKillDays Then Begin
          BBS.Deleted := True;
          BBSPack     := True;

          Update_Status ('Killing ' + BBS.BBSName);
        End;

        Write (BBSFile, BBS);
      End;

      Close (BBSFile);
      Close (TBBSFile);
      Erase (TBBSFile);
    End;
  End;

Var
  D   : DirStr;
  N   : NameStr;
  E   : ExtStr;
  Dir : SearchRec;
Begin
  Write ('Killing BBS List   :');

  If strUpper(BBSKillID) = 'ALL' Then Begin
    FindFirst (Config.DataPath + '*.bbi', AnyFile - Directory, Dir);

    While DosError = 0 Do Begin
      FSplit (Dir.Name, D, N, E);
      BBSKillID := N;
      PackFile;

      FindNext(Dir);
    End;

    FindClose(Dir);
  End Else
    PackFile;

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Kill_User_File;
Var
  tUserFile,
  UserFile  : File of RecUser;
  User      : RecUser;
Begin
  Write ('Killing User File    :');

  If FileRename (Config.DataPath + 'users.dat', Config.DataPath + 'users.dab') Then Begin

    Assign (TUserFile, Config.DataPath + 'users.dab');
    Reset  (TUserFile);

    Assign  (UserFile, Config.DataPath + 'users.dat');
    ReWrite (UserFile);

    While Not Eof(TUserFile) Do Begin
      Read (TUserFile, User);

      Update_Bar (FilePos(TUserFile), FileSize(TUserFile));

      If (DaysAgo(User.LastOn) >= UserKillDays) And (User.Flags AND UserNoKill = 0) Then Begin
        User.Flags := User.Flags OR UserDeleted;
        Update_Status ('Killing ' + User.Handle);
        UserPack := True;
      End;

      Write (UserFile, User);
    End;

    Close (UserFile);
    Close (tUserFile);
    Erase (tUserFile);
  End;

  Update_Status ('Completed');

  WriteLn;
End;

Procedure Pack_User_File;
Var
  SquLRFile  : File of SquLastType;
  SquLR      : SquLastType;
  UserFile   : File of RecUser;
  TUserFile  : File of RecUser;
  User       : RecUser;
  MBaseFile  : File of MBaseRec;
  MBase      : MBaseRec;
  MScanFile  : File of MScanRec;
  MScan      : MScanRec;
  FBaseFile  : File of FBaseRec;
  FBase      : FBaseRec;
  FScanFile  : File of FScanRec;
  FScan      : FScanRec;
  JamLRFile  : File of JamLastType;
  TJamLRFile : File of JamLastType;
  JamLR      : JamLastType;
  Deleted    : LongInt;
  Count      : LongInt;
  MsgBase    : PMsgBaseABS;
Begin
  Write ('Packing User File    :');

  If FileRename (Config.DataPath + 'users.dat', Config.DataPath + 'users.dab') Then Begin

    Assign (TUserFile, Config.DataPath + 'users.dab');
    Reset  (TUserFile);

    Assign  (UserFile, Config.DataPath + 'users.dat');
    ReWrite (UserFile);

    Deleted := 0;

    While Not Eof(TUserFile) Do Begin
      Read (TUserFile, User);

      Update_Bar (FilePos(TUserFile), FileSize(TUserFile));

      If (User.Flags AND UserDeleted <> 0) And (User.Flags AND UserNoKill = 0) Then Begin

        Update_Status ('Deleted ' + User.Handle);

        { DELETE MESSAGES FROM ANY PRIVATE MSG BASE }

        Assign (MBaseFile, Config.DataPath + 'mbases.dat');
        {$I-} Reset (MBaseFile); {$I+}
        If IoResult = 0 Then Begin
          While Not Eof(MBaseFile) Do Begin
            Read (MBaseFile, MBase);

            If MBase.PostType <> 1 Then Continue;

            Case MBase.BaseType of
              0 : MsgBase := New(PMsgBaseJAM, Init);
              1 : MsgBase := New(PMsgBaseSquish, Init);
            End;

            MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

            If Not MsgBase^.OpenMsgBase Then Begin
              Dispose (MsgBase, Done);
              Continue;
            End;

            MsgBase^.SeekFirst(1);

            While MsgBase^.SeekFound Do Begin
              MsgBase^.MsgStartUp;

              If (strUpper(MsgBase^.GetFrom) = strUpper(User.RealName)) or
                 (strUpper(MsgBase^.GetFrom) = strUpper(User.Handle)) or
                 (strUpper(MsgBase^.GetTo)   = strUpper(User.RealName)) or
                 (strUpper(MsgBase^.GetTo)   = strUpper(User.Handle)) Then
                   MsgBase^.DeleteMsg;

              MsgBase^.SeekNext;
            End;

            MsgBase^.CloseMsgBase;

            Dispose(MsgBase, Done);
          End;

          Close (MBaseFile);
        End;

        { DELETE LASTREAD AND SCAN SETTINGS FOR MESSAGE BASES }

        Assign (MBaseFile, Config.DataPath + 'mbases.dat');
        {$I-} Reset (MBaseFile); {$I+}
        If IoResult = 0 Then Begin
          While Not Eof(MBaseFile) Do Begin
            Read (MBaseFile, MBase);

            Case MBase.BaseType of
              0 : Begin
                    { DELETE JAM LASTREAD RECORDS }

                    If FileRename (MBase.Path + MBase.FileName + '.jlr', MBase.Path + MBase.FileName + '.jlb') Then Begin
                      Assign (TJamLRFile, MBase.Path + MBase.FileName + '.jlb');
                      Reset  (TJamLRFile);

                      Assign  (JamLRFile, MBase.Path + MBase.FileName + '.jlr');
                      ReWrite (JamLRFile);

                      Count := FilePos(TUserFile);

                      While Not Eof(TJamLRFile) Do Begin
                        Read (TJamLRFile, JamLR);

                        If JamLR.UserNum = Count - Deleted Then Continue;
                        If JamLR.UserNum > Count - Deleted Then Dec(JamLR.UserNum);

                        Write (JamLRFile, JamLR);
                      End;

                      Close (TJamLRFile);
                      Erase (TJamLRFile);
                      Close (JamLRFile);
                    End;
                  End;
              1 : Begin
                    { DELETE SQUISH LASTREAD RECORDS }

                    Assign (SquLRFile, Config.MsgsPath + MBase.FileName + '.sql');
                    {$I-} Reset (SquLRFile); {$I+}
                    If IoResult = 0 Then Begin
                      If FilePos(TUserFile) - 1 <= FileSize(SquLRFile) Then Begin
                        For Count := FilePos(TUserFile) - 1 to FileSize(SquLRFile) - 2 Do Begin
                          Seek  (SquLRFile, Count + 1);
                          Read  (SquLRFile, SquLR);
                          Seek  (SquLRFile, Count);
                          Write (SquLRFile, SquLR);
                        End;
                        Seek (SquLRFile, FileSize(SquLRFile) - 1);
                        Truncate (SquLRFile);
                      End;

                      Close (SquLRFile);
                    End;
                  End;
            End;

            { DELETE MSCAN RECORDS }

            Assign (MScanFile, Config.MsgsPath + MBase.FileName + '.scn');
            {$I-} Reset (MScanFile); {$I+}
            If IoResult = 0 Then Begin
              If FilePos(TUserFile) - 1 - Deleted <{=} FileSize(MScanFile) Then Begin
                For Count := FilePos(TUserFile) - 1 - Deleted to FileSize(MScanFile) - 2 Do Begin
                  Seek  (MScanFile, Count + 1);
                  Read  (MScanFile, MScan);
                  Seek  (MScanFile, Count);
                  Write (MScanFile, MScan);
                End;
                Seek (MScanFile, FileSize(MScanFile) - 1);
                Truncate (MScanFile);
              End;

              Close (MScanFile);
            End;
          End;

          Close (MBaseFile);
        End;

        { DELETE FSCAN RECORDS }

        Assign (FBaseFile, Config.DataPath + 'fbases.dat');
        {$I-} Reset (FBaseFile); {$I+}
        If IoResult = 0 Then Begin
          While Not Eof(FBaseFile) Do Begin
            Read (FBaseFile, FBase);
            Assign (FScanFile, Config.DataPath + FBase.FileName + '.scn');
            {$I-} Reset (FScanFile); {$I+}

            If IoResult = 0 Then Begin
              If FilePos(TUserFile) - 1 - Deleted <{=} FileSize(FScanFile) Then Begin
                For Count := FilePos(TUserFile) - 1 - Deleted to FileSize(FScanFile) - 2 Do Begin
                  Seek  (FScanFile, Count + 1);
                  Read  (FScanFile, FScan);
                  Seek  (FScanFile, Count);
                  Write (FScanFile, FScan);
                End;

                Seek (FScanFile, FileSize(FScanFile) - 1);
                Truncate (FScanFile);
              End;

              Close (FScanFile);
            End;
          End;

          Close (FBaseFile);
        End;

        Inc (Deleted);
      End Else
        Write (UserFile, User);
    End;
    Close (TUserFile);
    Erase (TUserFile);
    Close (UserFile);
  End;

  Update_Status ('Completed');

  WriteLn;
End;

Procedure MsgBase_Trash;
Var
  TF        : Text;
  BadName   : String;
  MBaseFile : File of MBaseRec;
  MBase     : MBaseRec;
  MsgBase   : PMsgBaseABS;
Begin
  Write ('Trashing Messages    :');

  Assign (TF, TrashFile);
  {$I-} Reset(TF); {$I+}
  If IoResult = 0 Then Begin
    While Not Eof(TF) Do Begin
      ReadLn(TF, BadName);

      BadName := strUpper(strStripB(BadName, ' '));

      If BadName = '' Then Continue;

      Update_Status(BadName);

      Assign (MBaseFile, Config.DataPath + 'mbases.dat');
      {$I-} Reset(MBaseFile); {$I+}
      If IoResult <> 0 Then Continue;
      Read (MBaseFile, MBase);

      While Not Eof(MBaseFile) Do Begin
        Read (MBaseFile, MBase);

        Update_Bar(FilePos(MBaseFile), FileSize(MBaseFile));

        Case MBase.BaseType of
          0 : MsgBase := New(PMsgBaseJAM, Init);
          1 : MsgBase := New(PMsgBaseSquish, Init);
        End;

        MsgBase^.SetMsgPath (MBase.Path + MBase.FileName);

        If Not MsgBase^.OpenMsgBase Then Begin
          Dispose (MsgBase, Done);
          Continue;
        End;

        MsgBase^.SeekFirst(1);

        While MsgBase^.SeekFound Do Begin
          MsgBase^.MsgStartUp;

          If (strUpper(MsgBase^.GetFrom) = BadName) or
             (strUpper(MsgBase^.GetTo)   = BadName) Then
               MsgBase^.DeleteMsg;

          MsgBase^.SeekNext;
        End;

        MsgBase^.CloseMsgBase;

        Dispose(MsgBase, Done);
      End;

      Close (MBaseFile);
    End;

    Close (TF);
  End;

  Update_Bar(100, 100);
  Update_Status('Completed');

  WriteLn;
End;

Procedure Upload_File_Bases;
Const
  NoDescStr = 'No Description';
Var
  BaseFile : File of FBaseRec;
  ListFile : File of RecFileList;
  DescFile : File;
  DizFile  : Text;
  Base     : FBaseRec;
  List     : RecFileList;
  DirInfo  : SearchRec;
  Found    : Boolean;
  Desc     : Array[1..99] of String[50];
  Count    : Integer;

  Procedure RemoveDesc (Num: Byte);
  Var
    A : Byte;
  Begin
    For A := Num To List.DescLines - 1 Do
      Desc[A] := Desc[A + 1];

    Desc[List.DescLines] := '';

    Dec (List.DescLines);
  End;

Begin
  Write ('Mass Upload Files    :');

  Assign (BaseFile, Config.DataPath + 'fbases.dat');
  {$I-} Reset (BaseFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(BaseFile) Do Begin
      Read (BaseFile, Base);

      Update_Status (strStripPipe(Base.Name));
      Update_Bar    (FilePos(BaseFile), FileSize(BaseFile));

      If Not FileDirExists(Base.Path) Then Continue;

      FindFirst (Base.Path + '*', AnyFile, DirInfo);

      While DosError = 0 Do Begin
        If (DirInfo.Attr And Directory <> 0) or
           (Length(DirInfo.Name) > 70) Then Begin
             FindNext(DirInfo);
             Continue;
        End;

        // should technically rename the file like Mystic does if > 70 chars

        Assign (ListFile, Config.DataPath + Base.FileName + '.dir');

        If FileExist(Config.DataPath + Base.FileName + '.dir') Then
          ioReset (ListFile, SizeOf(RecFileList), fmRWDN)
        Else
          ReWrite (ListFile);

        Found := False;

        While Not Eof(ListFile) And Not Found Do Begin
          Read (ListFile, List);

          If List.Flags and FDirDeleted <> 0 Then Continue;

          {$IFDEF FS_SENSITIVE}
            Found := List.FileName = DirInfo.Name;
          {$ELSE}
            Found := strUpper(List.FileName) = strUpper(DirInfo.Name);
          {$ENDIF}
        End;

        If Not Found Then Begin
          Seek (ListFile, FileSize(ListFile));

          List.FileName  := DirInfo.Name;
          List.Size      := DirInfo.Size;
          List.DateTime  := CurDateDos;
          List.Uploader  := 'MBBSUTIL';
          List.Flags     := 0;
          List.Downloads := 0;
          List.Rating    := 0;

          ExecuteArchive (Base.Path + List.FileName, '', 'file_id.diz', 2);

          Assign (DizFile, TempPath + 'file_id.diz');
          {$I-} Reset (DizFile); {$I+}

          If IoResult = 0 Then Begin
            List.DescLines := 0;

            While Not Eof(DizFile) Do Begin
              Inc    (List.DescLines);
              ReadLn (DizFile, Desc[List.DescLines]);

              Desc[List.DescLines] := strStripLOW(Desc[List.DescLines]);

              If Length(Desc[List.DescLines]) > mysMaxFileDescLen Then Desc[List.DescLines][0] := Chr(mysMaxFileDescLen);

              If List.DescLines = Config.MaxFileDesc Then Break;
            End;

            Close (DizFile);

            While (Desc[1] = '') and (List.DescLines > 0) Do
              RemoveDesc(1);

            While (Desc[List.DescLines] = '') And (List.DescLines > 0) Do
              Dec (List.DescLines);
          End Else Begin
            List.DescLines := 1;
            Desc[1]        := NoDescStr;
          End;

          FileErase (TempPath + 'file_id.diz');

          Assign (DescFile, Config.DataPath + Base.FileName + '.des');

          If FileExist(Config.DataPath + Base.FileName + '.des') Then
            Reset (DescFile, 1)
          Else
            ReWrite (DescFile, 1);

          List.DescPtr := FileSize(DescFile);

          Seek (DescFile, List.DescPtr);

          For Count := 1 to List.DescLines Do
            BlockWrite (DescFile, Desc[Count][0], Length(Desc[Count]) + 1);

          Close (DescFile);

          Write (ListFile, List);
        End;

        Close (ListFile);

        FindNext(DirInfo);
      End;

      FindClose(DirInfo);
    End;

    Close (BaseFile);
  End;

  Update_Bar    (100, 100);
  Update_Status ('Completed');

  WriteLn;
End;

Var
  A        : Byte;
  Temp     : String;
  ChatFile : File of ChatRec;
  Chat     : ChatRec;
Begin
  TextAttr := 7;

  WriteLn;
  WriteLn ('MBBSUTIL: ', mysSoftwareID, ' BBS Utilities Version ', mysVersion, ' (', OSID, ')');
  WriteLn ('Copyright (C) 1997-2012 By James Coyle.  All Rights Reserved.');
  WriteLn;

  FileMode := 66;

  Assign (ConfigFile, 'mystic.dat');
  {$I-} Reset(ConfigFile); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('Error reading MYSTIC.DAT.  Run MBBSUTIL from the main BBS directory.');
    Halt(1);
  End;

  Read  (ConfigFile, Config);
  Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn('ERROR: Data files are not current and must be upgraded.');
    Halt(1);
  End;

  If ParamCount = 0 Then Begin
    Show_Help;
    Exit;
  End;

  A := 1;

  While (A <= ParamCount) Do Begin
    Temp := strUpper(ParamStr(A));

    If Temp = '-BKILL' Then Begin
      BBSKillID   := ParamStr(A+1);
      BBSKillDays := strS2I(ParamStr(A+2));
      Inc(A, 2);
      If (strUpper(BBSKillID) <> 'ALL') And Not FileExist(Config.DataPath + BBSKillID + '.bbi') Then Begin
        WriteLn ('ERROR: -BKILL: List ID (' + BBSKillID + ') does not exist.');
        Halt(1);
      End Else
      If BBSKillDays < 1 Then Begin
        WriteLn ('ERROR: -BKILL days must be set to a LEAST 1.');
        Halt(1);
      End Else
        BBSKill := True;
    End;

    If Temp = '-BPACK'  Then BBSPack   := True;
    If Temp = '-BSORT'  Then Begin
      BBSSortID := ParamStr(A+1);
      Temp      := strUpper(ParamStr(A+2));

      Inc (A, 2);

      If Temp = 'PHONE' Then
        BBSSortType := 0
      Else
      If Temp = 'TELNET' Then
        BBSSortType := 1
      Else
      If Temp = 'BBSNAME' Then
        BBSSortType := 2
      Else
      If Temp = 'LOCATION' Then
        BBSSortType := 3
      Else Begin
        WriteLn ('ERROR: -BSORT: Invalid sort type.');
        Halt(1);
      End;

      If (strUpper(BBSSortID) <> 'ALL') And Not FileExist(Config.DataPath + BBSSortID + '.bbi') Then Begin
        WriteLn ('ERROR: -BSORT: List ID (' + BBSSortID + ') does not exist.');
        Halt(1);
      End Else
        BBSSort := True;
    End;
    If Temp = '-FCHECK' Then FileCheck := True;
    If Temp = '-FPACK'  Then FilePack  := True;
    If Temp = '-FSORT'  Then FileSort  := True;
    If Temp = '-FUPLOAD' Then FileUpload := True;
    If Temp = '-UKILL'  Then Begin
      UserKill := True;

      Inc(A);

      UserKillDays := strS2I(ParamStr(A));

      If UserKillDays < 5 Then Begin
        WriteLn ('ERROR: -UKILL days must be set to at LEAST 5.');
        Halt(1);
      End;
    End;
    If Temp = '-MTRASH' Then Begin
      Inc(A);

      MsgTrash  := True;
      TrashFile := strStripB(ParamStr(A), ' ');

      If (TrashFile <> '') And Not FileExist(TrashFile) Then Begin
        WriteLn('ERROR: Trash file does not exist.');
        Halt(1);
      End;

      If TrashFile = '' Then TrashFile := Config.DataPath + 'trashcan.dat';
    End;
    If Temp = '-UPACK'  Then UserPack  := True;

    Inc (A);
  End;

  If NodeCheck Then
    For A := 1 to Config.INetTNNodes Do Begin
      Assign (ChatFile, Config.DataPath + 'chat' + strI2S(A) + '.dat');
      {$I-} Reset (ChatFile); {$I+}

      If IoResult = 0 Then Begin
        Read (ChatFile, Chat);

        If Chat.Active Then Begin
          WriteLn ('ERROR: MBBSUTIL has detected that a user is online at this time.');
          WriteLn ('       In order to prevent corruption of the system data files,');
          WriteLn ('       this program should only be ran when there are NO users');
          WriteLn ('       logged in to the BBS system.');
          WriteLn ('');
          WriteLn ('Create a system event to log off all users before running this program.');
          WriteLn;
          WriteLn ('If there are NO users online and MBBSUTIL detects that there are, try');
          WriteLn ('changing to the data directory and deleting "chat*.dat" then re-run');
          WriteLn ('MBBSUTIL');
          WriteLn;
          WriteLn ('Using the -NOCHECK option will bypass this check');

          Halt(1);
        End;
      End;
    End;

  {$I-}
  MkDir (Config.SystemPath + 'temp0');
  If IoResult <> 0 Then;
  {$I+}

  TempPath := Config.SystemPath + 'temp0' + PathChar;

  DirClean (TempPath, '');

  If FileUpload Then Upload_File_Bases;
  If FileSort   Then Sort_File_Bases;
  If FileCheck  Then Check_File_Bases;
  If FilePack   Then Pack_File_Bases;
  If BBSKill    Then Kill_BBS_List;
  If BBSPack    Then Pack_BBS_List;
  If BBSSort    Then Sort_BBS_List;
  If UserKill   Then Kill_User_File;
  If UserPack   Then Pack_User_File;
  If MsgTrash   Then MsgBase_Trash;
End.

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
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
  DOS,
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
  BBSPack    : Boolean = False;
  BBSSort    : Boolean = False;
  BBSKill    : Boolean = False;
  UserKill   : Boolean = False;
  UserPack   : Boolean = False;
  MsgTrash   : Boolean = False;
  NodeCheck  : Boolean = True;
  AreasOut   : Boolean = False;
  FixIndex   : Boolean = False;

  UserKillDays : Integer = 0;
  BBSSortID    : String  = '';
  BBSSortType  : Byte    = 0;
  BBSKillID    : String  = '';
  BBSKillDays  : Integer = 0;
  TrashFile    : String  = '';
  TempPath     : String  = '';
  AreasFile    : String  = '';
  FCheckKill   : Boolean = False;

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

Function strAddr2Str (Addr : RecEchoMailAddr) : String;
Var
  Temp : String[20];
Begin
  Temp := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' +
          strI2S(Addr.Node);

  If Addr.Point <> 0 Then Temp := Temp + '.' + strI2S(Addr.Point);

  Result := Temp;
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
  WriteLn ('-AREASOUT <File>            Export AREAS.BBS format file in <File>');
  WriteLn ('-BKILL    <ID> <Days>       Delete BBSes which haven''t been verified in <DAYS>');
  WriteLn ('-BPACK                      Pack all BBS lists');
  WriteLn ('-BSORT    <ID> <Type>       Sorts and packs BBS list by <type>');
  WriteLn ('-FCHECK   <KILL>            Check filelist for correct size/status');
  WriteLn ('-FIXINDEX                   Fix wrong perm index for user/msg/file bases');
  WriteLn ('-FPACK                      Pack file bases');
  WriteLn ('-FSORT                      Sort file base entries by filename');
  WriteLn ('-MTRASH   <File>            Delete messages to/from users listed in <File>');
  WriteLn ('-NOCHECK                    Bypass online user check at startup');
  WriteLn ('-UKILL    <Days>            Delete users who have not called in <DAYS>');
  WriteLn ('-UPACK                      Pack user database');
End;

(***************************************************************************)
(***************************************************************************)
(***************************************************************************)

Procedure Sort_File_Bases;
Var
  SortList  : TQuickSort;
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;
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

      SortList.Sort(1, SortList.Total, qAscending);

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
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;
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
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;
  FDirFile  : File of RecFileList;
  FDir      : RecFileList;
  TFDirFile : File of RecFileList;
  DF        : File;
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

        If FDir.Flags AND FDirDeleted <> 0 Then Continue;

        Assign (DF, FBase.Path + FDir.FileName);
        {$I-} Reset (DF, 1); {$I+}

        If IoResult <> 0 Then
          FDir.Flags := FDir.Flags OR FDirOffline
        Else Begin
          FDir.Size := FileSize(DF);

          If FDir.Size = 0 Then
            FDir.Flags := FDir.Flags OR FDirOffline
          Else
            FDir.Flags := FDir.Flags AND NOT FDirOffline;

          Close (DF);
        End;

        If (FDir.Flags AND FDirOffline <> 0) and FCheckKill Then Continue;

        Write (TFDirFile, FDir);
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

      SortList.Sort(1, SortList.Total, qAscending);

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

        If DaysAgo(BBS.Verified, 2) >= BBSKillDays Then Begin
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
  FileMode := 66;

  Write ('Killing User File    :');

  If FileRename (Config.DataPath + 'users.dat', Config.DataPath + 'users.dab') Then Begin

    Assign (TUserFile, Config.DataPath + 'users.dab');
    Reset  (TUserFile);

    Assign  (UserFile, Config.DataPath + 'users.dat');
    ReWrite (UserFile);

    While Not Eof(TUserFile) Do Begin
      Read (TUserFile, User);

      Update_Bar (FilePos(TUserFile), FileSize(TUserFile));

      If (DaysAgo(User.LastOn, 2) >= UserKillDays) And (User.Flags AND UserNoKill = 0) Then Begin
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
  MBaseFile  : File of RecMessageBase;
  MBase      : RecMessageBase;
  MScanFile  : File of MScanRec;
  MScan      : MScanRec;
  FBaseFile  : File of RecFileBase;
  FBase      : RecFileBase;
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

            If MBase.Flags And MBPrivate = 0 Then Continue;

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
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
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

Procedure ExportAreasBBS;
Var
  MBaseFile : TFileBuffer;
  MBase     : RecMessageBase;
  OutFile   : Text;
Begin
  Write ('Exporting AREAS.BBS  : ');

  Assign (OutFile, AreasFile);
  {$I-} ReWrite(OutFile); {$I+}

  If IoResult <> 0 Then Exit;

  MBaseFile := TFileBuffer.Create(8192);

  If MBaseFile.OpenStream (Config.DataPath + 'mbases.dat', fmOpen, fmRWDN) Then Begin
    MBaseFile.BlockRead (MBase, SizeOf(MBase));

    While Not MBaseFile.EOF Do Begin
      MBaseFile.BlockRead (MBase, SizeOf(MBase));

      Update_Bar    (MBaseFile.FilePos, MBaseFile.FileSize);
      Update_Status (strStripPipe(MBase.Name));

      If MBase.NetType <> 1 Then Continue;

      WriteLn (OutFile, '!' + Config.DataPath + MBase.FileName + ' ' + MBase.FileName + ' ' + '0:0/0');
    End;
  End;

  Close (OutFile);

  MBaseFile.Free;

  Update_Status ('Completed');

  WriteLn;
End;

Procedure FixIndexes;
Var
  ConfigFile : File of RecConfig;
  MBaseFile  : File of RecMessageBase;
  FBaseFile  : File of RecFileBase;
  UserFile   : File of RecUser;
  Config     : RecConfig;
  MBase      : RecMessageBase;
  FBase      : RecFileBase;
  User       : RecUser;

  Function IsDupeMBaseIndex (SavedPos, Idx: LongInt) : Boolean;
  Var
    TempBase : RecMessageBase;
  Begin
    Result := False;

    Reset (MBaseFile);

    While Not Eof(MBaseFile) Do Begin
      Read (MBaseFile, TempBase);

      If (TempBase.Index = Idx) and (FilePos(MBaseFile) <> SavedPos) Then Begin
        Result := True;
        Break;
      End;
    End;

    Seek (MBaseFile, SavedPos);
  End;

  Function IsDupeUserIndex (SavedPos, Idx: LongInt) : Boolean;
  Var
    TempUser : RecUser;
  Begin
    Result := False;

//    Close (UserFile);
    Reset (UserFile);

    While Not Eof(UserFile) Do Begin
      Read (UserFile, TempUser);

      If (TempUser.PermIdx = Idx) and (FilePos(UserFile) <> SavedPos) Then Begin
        Result := True;
        Break;
      End;
    End;

//    Reset (UserFile);
    Seek  (UserFile, SavedPos);
  End;

  Function IsDupeFBaseIndex (SavedPos, Idx: LongInt) : Boolean;
  Var
    TempBase : RecFileBase;
  Begin
    Result := False;

    Reset (FBaseFile);

    While Not Eof(FBaseFile) Do Begin
      Read (FBaseFile, TempBase);

      If (TempBase.Index = Idx) and (FilePos(FBaseFile) <> SavedPos) Then Begin
        Result := True;
        Break;
      End;
    End;

    Seek (FBaseFile, SavedPos);
  End;

Var
  NewIndex : Cardinal;
  MaxUser  : Cardinal;
Begin
  Write ('Fixing Indexes       :');

  Assign (ConfigFile, 'mystic.dat');

  {$I-} Reset(ConfigFile); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('Must be executed in same directory as MYSTIC.DAT file');
    Halt(1);
  End;

  Read  (ConfigFile, Config);
  Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn ('This program is not compatible with the current version of Mystic');
    Halt(1);
  End;

  Assign (MBaseFile, Config.DataPath + 'mbases.dat');
  Reset  (MBaseFile);

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    Update_Bar (FilePos(MBaseFile), FileSize(MBaseFile));

    If IsDupeMBaseIndex(FilePos(MBaseFile), MBase.Index) Then Begin
      NewIndex := 0;

      While IsDupeMBaseIndex(FilePos(MBaseFile), NewIndex) Do
        Inc (NewIndex);

      MBase.Index := NewIndex;
    End;

    If (MBase.Created = 0) Or Not DateValid(DateDos2Str(MBase.Created, 1)) Then Begin
      MBase.Created := CurDateDos;
    End;

    Seek  (MBaseFile, FilePos(MBaseFile) - 1);
    Write (MBaseFile, MBase);
  End;

  Close (MBaseFile);

  Assign (FBaseFile, Config.DataPath + 'fbases.dat');
  Reset  (FBaseFile);

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    Update_Bar (FilePos(FBaseFile), FileSize(FBaseFile));

    If IsDupeFBaseIndex(FilePos(FBaseFile), FBase.Index) Then Begin
      NewIndex := 0;

      While IsDupeFBaseIndex(FilePos(FBaseFile), NewIndex) Do
        Inc (NewIndex);

      FBase.Index := NewIndex;
    End;

    If (FBase.Created = 0) Or Not DateValid(DateDos2Str(FBase.Created, 1)) Then Begin
      FBase.Created := CurDateDos;
    End;

    Seek  (FBaseFile, FilePos(FBaseFile) - 1);
    Write (FBaseFile, FBase);
  End;

  Close (FBaseFile);

  Assign (UserFile, Config.DataPath + 'users.dat');
  Reset  (UserFile);

  MaxUser := 0;

  While Not Eof(UserFile) Do Begin
    Read (UserFile, User);

    If User.PermIdx > MaxUser Then MaxUser := User.PermIdx;

    Update_Bar (FilePos(UserFile), FileSize(UserFile));

    If IsDupeUserIndex(FilePos(UserFile), User.PermIdx) Then Begin
      NewIndex := 0;

      While IsDupeUserIndex(FilePos(UserFile), NewIndex) Do
        Inc (NewIndex);

      User.PermIdx := NewIndex;

      If User.PermIdx > MaxUser Then MaxUser := User.PermIdx;
    End;

    Seek  (UserFile, FilePos(UserFile) - 1);
    Write (UserFile, User);
  End;

  Close (UserFile);

  If MaxUser <> Config.UserIdxPos Then Begin
    Config.UserIdxPos := MaxUser + 1;

    Reset (ConfigFile);
    Write (ConfigFile, Config);
    Close (ConfigFile);
  End;

  Update_Bar(100, 100);
  Update_Status('Completed');

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
  WriteLn ('MBBSUTIL: ', mysSoftwareID, ' Utilities Version ', mysVersion, ' (', OSID, ')');
  WriteLn ('Copyright (C) ', mysCopyYear, ' By James Coyle.  All Rights Reserved.');
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

    If Temp = '-AREASOUT' Then Begin
      AreasFile := ParamStr(A+1);

      Inc(A);

      AreasOut := True;

      If AreasFile = '' Then Begin
        WriteLn('Missing parameter');
        Halt(1);
      End;
    End;

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
    If Temp = '-FCHECK' Then Begin
      FileCheck := True;

      FCheckKill := strUpper(ParamStr(A+1)) = 'KILL';

      If FCheckKill Then Inc(A);
    End;
    If Temp = '-FIXINDEX' Then FixIndex := True;
    If Temp = '-FPACK'  Then FilePack  := True;
    If Temp = '-FSORT'  Then FileSort  := True;
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
    If Temp = '-NOCHECK' Then NodeCheck := False;

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

  If FileSort   Then Sort_File_Bases;
  If FileCheck  Then Check_File_Bases;
  If FilePack   Then Pack_File_Bases;
  If BBSKill    Then Kill_BBS_List;
  If BBSPack    Then Pack_BBS_List;
  If BBSSort    Then Sort_BBS_List;
  If UserKill   Then Kill_User_File;
  If UserPack   Then Pack_User_File;
  If MsgTrash   Then MsgBase_Trash;
  If AreasOut   Then ExportAreasBBS;
  If FixIndex   Then FixIndexes;
End.

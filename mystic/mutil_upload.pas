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
Unit mutil_Upload;

Interface

Procedure uMassUpload;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings,
  m_DateTime,
  mUtil_Common,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase;

Procedure uMassUpload;
Var
  BaseFile   : File of RecFileBase;
  ListFile   : File of RecFileList;
  DescFile   : File;
  DizFile    : Text;
  DizName    : String;
  Base       : RecFileBase;
  List       : RecFileList;
  DirInfo    : SearchRec;
  Found      : Boolean;
  Desc       : Array[1..99] of String[50];
  Count      : Integer;
  FilesAdded : LongInt = 0;
  IgnoreList : Array[1..100] of String[80];
  IgnoreSize : Byte = 0;

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
  ProcessName   ('Mass Upload Files', True);
  ProcessResult (rWORKING, False);

  // Read in ignore list

  FillChar (Ignorelist, SizeOf(IgnoreList), #0);

  Ini.SetSequential(True);

  Repeat
    DizName := INI.ReadString(Header_UPLOAD, 'ignore', '');

    If DizName = '' Then Break;

    Inc (IgnoreSize);

    IgnoreList[IgnoreSize] := DizName;
  Until IgnoreSize = 100;

  INI.SetSequential(False);

  // get the show on the road

  Assign (BaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset (BaseFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(BaseFile) Do Begin
      Read (BaseFile, Base);

      ProcessStatus (Base.Name, False);
      BarOne.Update (FilePos(BaseFile), FileSize(BaseFile));

      If Not DirExists(Base.Path) Then Continue;

      FindFirst (Base.Path + '*', AnyFile, DirInfo);

      While DosError = 0 Do Begin
        If (DirInfo.Attr And Directory <> 0) or
           (Length(DirInfo.Name) > 70) Then Begin
             FindNext(DirInfo);
             Continue;
        End;

        // should technically rename the file like Mystic does if > 70 chars

        Assign (ListFile, bbsCfg.DataPath + Base.FileName + '.dir');

        If FileExist(bbsCfg.DataPath + Base.FileName + '.dir') Then
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

        For Count := 1 to IgnoreSize Do
          If WildMatch (IgnoreList[Count], DirInfo.Name, True) Then Begin
            Found := True;

            Break;
          End;

        If Not Found Then Begin
          Log (1, '+', '   Add: ' + DirInfo.Name + ' To: ' + strStripPipe(Base.Name));

          Inc  (FilesAdded);
          Seek (ListFile, FileSize(ListFile));

          List.FileName  := DirInfo.Name;
          List.Size      := DirInfo.Size;
          List.DateTime  := CurDateDos;
          List.Uploader  := INI.ReadString(Header_UPLOAD, 'uploader_name', 'MUTIL');
          List.Flags     := 0;
          List.Downloads := 0;
          List.Rating    := 0;

          If INI.ReadString(Header_UPLOAD, 'import_fileid', '1') = '1' Then Begin

            ExecuteArchive (TempPath, Base.Path + List.FileName, '', 'file_id.diz', 2);

            DizName := FileFind(TempPath + 'file_id.diz');

            Assign (DizFile, DizName);
            {$I-} Reset (DizFile); {$I+}

            If IoResult = 0 Then Begin
              List.DescLines := 0;

              While Not Eof(DizFile) Do Begin
                Inc    (List.DescLines);
                ReadLn (DizFile, Desc[List.DescLines]);

                Desc[List.DescLines] := strStripLow(Desc[List.DescLines]);

                If Length(Desc[List.DescLines]) > mysMaxFileDescLen Then Desc[List.DescLines][0] := Chr(mysMaxFileDescLen);

                If List.DescLines = bbsCfg.MaxFileDesc Then Break;
              End;

              Close (DizFile);

              While (Desc[1] = '') and (List.DescLines > 0) Do
                RemoveDesc(1);

              While (Desc[List.DescLines] = '') And (List.DescLines > 0) Do
                Dec (List.DescLines);
            End Else Begin
              List.DescLines := 1;
              Desc[1]        := INI.ReadString(Header_UPLOAD, 'no_description', 'No Description');
            End;

            FileErase (DizName);
          End Else Begin
            List.DescLines := 1;
            Desc[1]        := INI.ReadString(Header_UPLOAD, 'no_description', 'No Description');
          End;

          Assign (DescFile, bbsCfg.DataPath + Base.FileName + '.des');

          If FileExist(bbsCfg.DataPath + Base.FileName + '.des') Then
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

  ProcessStatus ('Uploaded |15' + strI2S(FilesAdded) + ' |07file(s)', True);
  ProcessResult (rDONE, True);
End;

End.

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
Unit mUtil_FilesBBS;

{$I M_OPS.PAS}

Interface

Procedure uImportFilesBBS;

Implementation

Uses
  m_Strings,
  m_FileIO,
  m_DateTime,
  mUtil_Common,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase;

Procedure uImportFilesBBS;
Var
  FilesAdded  : LongInt = 0;
  BaseFile    : File of RecFileBase;
  ListFile    : File of RecFileList;
  DescFile    : File;
  bbsFile     : Text;
  bbsBuffer   : Array[1..4096] of Char;
  OneLine     : String;
  Base        : RecFileBase;
  List        : RecFileList;
  FileName    : String;
  FSize       : Int64;
  Desc        : Array[1..99] of String[50];
  DescLines   : Byte;
  DescPos     : Byte;
  DescChar    : String[1];
  DescCharPos : Byte;
  ImportName  : String;
  UploadName  : String;
  EraseAfter  : Boolean;
  NeedWrite   : Boolean = False;

  Procedure SaveDescription;
  Var
    Count : Byte;
  Begin
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
  End;

  Procedure AddFile;
  Var
    Found : Boolean;
  Begin
    NeedWrite := False;
    Found     := False;
    FileName  := JustFile(FileName);

    If FSize = -1 Then Exit;

    Assign (ListFile, bbsCfg.DataPath + Base.FileName + '.dir');
    {$I-} Reset(ListFile); {$I+}

    If IoResult <> 0 Then ReWrite(ListFile);

    While Not Eof(ListFile) And Not Found Do Begin
      Read (ListFile, List);

      Found := strUpper(List.FileName) = strUpper(FileName);

      If Found and (FSize <> List.Size) Then Begin
        Inc (FilesAdded);

        List.Size     := FSize;
        List.DateTime := CurDateDos;

        SaveDescription;

        Seek  (ListFile, FilePos(ListFile) - 1);
        Write (ListFile, List);
        Close (ListFile);

        Exit;
      End;
    End;

    If Not Found Then Begin
      Inc (FilesAdded);

      FillChar (List, SizeOf(List), 0);

      List.FileName  := FileName;
      List.Size      := FSize;
      List.DateTime  := CurDateDos;
      List.Uploader  := UploadName;
      List.DescLines := DescLines;

      SaveDescription;

      Write (ListFile, List);
    End;

    Close (ListFile);
  End;

Begin
  ProcessName   ('Import FILES.BBS', True);
  ProcessResult (rWORKING, False);

  EraseAfter  := INI.ReadInteger(Header_FILESBBS, 'delete_after', 0) = 1;
  DescPos     := INI.ReadInteger(Header_FILESBBS, 'desc_start', 14);
  DescCharPos := INI.ReadInteger(Header_FILESBBS, 'desc_charpos', 1);
  DescChar    := INI.ReadString(Header_FILESBBS, 'desc_char', ' ');
  UploadName  := INI.ReadString(Header_FILESBBS, 'uploader_name', 'Mystic BBS');

  If DescChar = '' Then DescChar := ' ';

  Assign (BaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset (BaseFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(BaseFile) Do Begin
      Read (BaseFile, Base);

      ImportName := FileFind(Base.Path + 'files.bbs');

      Assign     (bbsFile, ImportName);
      SetTextBuf (bbsFile, bbsBuffer);

      {$I-} Reset(bbsFile); {$I+}

      If IoResult <> 0 Then Continue;

      While Not Eof(bbsFile) Do Begin
        ReadLn (bbsFile, OneLine);

        If strStripB(OneLine, ' ') = '' Then Continue;

        If OneLine[DescCharPos] <> DescChar Then Begin
          If NeedWrite Then AddFile;

          NeedWrite := True;
          FileName  := FileFind(Base.Path + strStripB(strWordGet(1, OneLine, ' '), ' '));
          FSize     := FileByteSize(FileName);
          DescLines := 1;
          Desc[1]   := strStripB(Copy(OneLine, strWordPos(2, OneLine, ' '), 255), ' ');
        End Else Begin
          If DescLines < bbsCfg.MaxFileDesc Then Begin
            Inc (DescLines);
            Desc[DescLines] := strStripB(Copy(OneLine, DescPos, 255), ' ');
          End;
        End;
      End;

      If NeedWrite Then AddFile;

      Close (bbsFile);

      If EraseAfter Then
        FileErase(ImportName);
    End;

    Close (BaseFile);
  End;

  ProcessStatus ('Uploaded |15' + strI2S(FilesAdded) + ' |07file(s)', True);
  ProcessResult (rDONE, True);
End;

End.

Program PCB2MBBS;

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

{$I M_OPS.PAS}

Uses
  CRT,
  DOS,
  m_Strings,
  m_DateTime;

{$I RECORDS.PAS}

Var
  InFile    : Text;
  DesFile   : File;
  FDirFile  : File of RecFileList;
  FDir      : RecFileList;
  Desc      : Array[1..99] of String[50];
  Str       : String = '';
  A         : Byte;
  Total     : Integer;
  NoSave    : Boolean;
  DupeCheck : Boolean;
  D         : DirStr;
  N         : NameStr;
  E         : ExtStr;

Function IsDupeFile (FN : String) : Boolean;
Begin
  IsDupeFile := False;

  If Not DupeCheck Then Exit;

  Reset (FDirFile);

  While Not Eof(FDirFile) Do Begin
    Read (FDirFile, FDir);

    If FDir.Flags and FDirDeleted <> 0 Then Continue;

    {$IFDEF FS_SENSITIVE}
      If FDir.FileName = FN Then Begin
    {$ELSE}
      If strUpper(FDir.FileName) = strUpper(FN) Then Begin
    {$ENDIF}
      Result := True;
      Exit;
    End;
  End;
End;

Begin
  WriteLn;
  WriteLn ('PCB2MBBS : PCBoard to Mystic BBS File Base Converter');
  WriteLn ('Copyright (C) 1998-2012 By James Coyle.  All Rights Reserved');
  WriteLn;
  WriteLn ('Compiled for Mystic BBS v' + mysVersion);
  WriteLn;

  If ParamCount < 2 Then Begin
    WriteLn ('Usage: [PCBoard File]  [Mystic BBS File]  -DUPE');
    Halt(1);
  End;

  DupeCheck := strUpper(ParamStr(3)) = '-DUPE';

  Assign (InFile, ParamStr(1));
  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: PCBoard file listing (', ParamStr(1), ') not found.');
    Halt    (1);
  End;

  FSplit (ParamStr(2), D, N, E);

  Assign (FDirFile, D + N + '.dir');
  {$I-} Reset (FDirFile); {$I+}

  If IoResult <> 0 Then ReWrite (FDirFile);

  Assign (DesFile, D + N + '.des');
  {$I-} Reset (DesFile, 1); {$I+}

  If IoResult <> 0 Then ReWrite (DesFile, 1);

  Total := 0;

  Write ('Processing: ');

  While Not Eof(inFile) Do Begin
    If (Str[26] = '-') and (Str[29] = '-') Then Begin
      If IsDupeFile(Copy(Str, 1, Pos(' ', Str) - 1)) Then
        NoSave := True
      Else Begin
        NoSave := False;

        Inc    (Total);
        GotoXY (13, WhereY);
        Write  (Total, ' files ... ');
      End;

      FillChar (FDir, SizeOf(FDir), #0);

      FDir.FileName  := Copy(Str, 1, Pos(' ', Str) - 1);
      FDir.Size      := strS2I(Copy(Str, 13, 9));
      FDir.DateTime  := DateStr2Dos(Copy(Str, 24, 8));
      FDir.Uploader  := 'PCB2MBBS';
      FDir.DescLines := 1;
      FDir.DescPtr   := FileSize(DesFile);

      Desc[1]  := Copy(Str, 34, Length(Str));

      Repeat
        ReadLn (inFile, Str);

        If Str[32] = '|' Then Begin
          Inc (FDir.DescLines);
          Desc[FDir.DescLines] := Copy(Str, 34, Length(Str));
        End;
      Until (Str[32] <> '|') or Eof(inFile);

      If Not NoSave Then Begin
        Write (FDirFile, FDir);
        Seek  (DesFile, FDir.DescPtr);

        For A := 1 to FDir.DescLines Do Begin
          BlockWrite (desFile, Desc[A][0], 1);
          BlockWrite (desFile, Desc[A][1], Ord(Desc[A][0]));
        End;
      End;
    End Else
      If Not Eof(InFile) Then ReadLn (inFile, Str);
  End;

  Close (InFile);
  Close (FDirFile);
  Close (DesFile);

  WriteLn ('DONE.');
End.

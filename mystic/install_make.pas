Program install_make;

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

Uses
  DOS,
  m_FileIO,
  Install_Arc;

Var
  oName : String;
  oMask : String;
  oEID  : String;
  Dir   : SearchRec;
Begin
  WriteLn;
  WriteLn('Install Make utility for .MYS files');
  WriteLn;

  If ParamCount <> 3 Then Begin
    WriteLn('Received: ', ParamCount, ' parameters.');
    WriteLn('PS: ', ParamStr(1) + ' ' + ParamStr(2) + ' ' + ParamStr(3));
    WriteLn;
    WriteLn('Syntax: install_make [NAME of MYS FILE] [FILEMASK] [EID]');
    Halt(1);
  End;

  oName := ParamStr(1);
  oMask := ParamStr(2);
  oEID  := ParamStr(3);

  If Not maOpenCreate(oName, True) Then Begin
    WriteLn('Unable to create: ' + oName + '.mys');
    Halt(1);
  End;

  FindFirst(oMask, Archive, Dir);

  While DosError = 0 Do Begin
    If Not maAddFile(JustPath(oMask), oEID, Dir.Name) Then Begin
      WriteLn('Unable to add file: ' + Dir.Name);
      Halt(1);
    End Else
      WriteLn('  - Added: ' + Dir.Name);

    FindNext(Dir);
  End;

  FindClose(Dir);
  maCloseFile;
End.

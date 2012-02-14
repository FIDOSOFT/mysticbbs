Program install_make;

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

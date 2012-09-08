Unit MUTIL_AllFiles;

{$I M_OPS.PAS}

Interface

Procedure uAllFilesList;

Implementation

Uses
  m_Strings,
  mUtil_Common,
  mUtil_Status;

Const
  AddedFiles : Cardinal = 0;

Procedure uAllFilesList;
Begin
  ProcessName   ('Generating AllFiles List', True);
  ProcessResult (rWORKING, False);

  ProcessStatus ('Added |15' + strI2S(AddedFiles) + ' |07file(s)');
  ProcessResult (rDONE, True);
End;

End.

Unit MUTIL_MsgPack;

{$I M_OPS.PAS}

Interface

Procedure uPackMessageBases;

Implementation

Uses
  m_Strings,
  mUtil_Common,
  mUtil_Status;

Procedure uPackMessageBases;
Begin
  ProcessName   ('Packing Message Bases', True);
  ProcessResult (rWORKING, False);

  ProcessStatus ('Complete');
  ProcessResult (rDONE, True);
End;

End.

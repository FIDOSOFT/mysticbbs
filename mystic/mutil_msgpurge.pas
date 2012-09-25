Unit MUTIL_MsgPurge;

{$I M_OPS.PAS}

Interface

Procedure uPurgeMessageBases;

Implementation

Uses
  m_Strings,
  mUtil_Common,
  mUtil_Status;

Procedure uPurgeMessageBases;
Begin
  ProcessName   ('Purging Message Bases', True);
  ProcessResult (rWORKING, False);

  ProcessStatus ('Complete', True);
  ProcessResult (rDONE, True);
End;

End.

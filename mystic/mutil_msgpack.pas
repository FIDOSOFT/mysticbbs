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

  ProcessStatus ('Removed X Msgs in X Bases', True);
  ProcessResult (rDONE, True);
End;

End.

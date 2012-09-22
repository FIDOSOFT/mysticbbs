Unit m_Pipe;

{$I M_OPS.PAS}

Interface

{$IFDEF UNIX}
  Uses m_Pipe_Unix;
  Type TPipe = Class(TPipeUnix);
{$ENDIF}

{$IFDEF WINDOWS}
  Uses m_Pipe_Windows;
  Type TPipe = Class(TPipeWindows);
{$ENDIF}

{$IFDEF OS2}
  Uses m_Pipe_Disk;
  Type TPipe = Class(TPipeDisk);
{$ENDIF}

Implementation

End.

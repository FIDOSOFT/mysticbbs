{$I M_OPS.PAS}

Unit m_Output;

Interface

{$IFDEF WINDOWS}
  Uses
    m_Output_Windows;

  Type
    TOutput = Class(TOutputWindows);
{$ENDIF}

{$IFDEF LINUX}
  Uses m_Output_Linux;

  Type
    TOutput = Class(TOutputLinux);
{$ENDIF}

{$IFDEF DARWIN}
  Uses m_Output_Darwin;

  Type
    TOutput = Class(TOutputDarwin);
{$ENDIF}

Implementation

End.

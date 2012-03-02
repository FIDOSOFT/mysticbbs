{$I M_OPS.PAS}

Unit m_Output;

Interface

{.$DEFINE USE_CRT_OUTPUT}

{$IFDEF OS2}
  {$DEFINE USE_CRT_OUTPUT}
{$ENDIF}

{$IFDEF USE_CRT_OUTPUT}
  {$WARNING ***** GENERIC CRT OUTPUT IS ENABLED *****}
  Uses m_Output_CRT;
  Type TOutput = Class(TOutputCRT);
{$ELSE}
  {$IFDEF WINDOWS}
    Uses m_Output_Windows;
    Type TOutput = Class(TOutputWindows);
  {$ENDIF}

  {$IFDEF LINUX}
    Uses m_Output_Linux;
    Type TOutput = Class(TOutputLinux);
  {$ENDIF}

  {$IFDEF DARWIN}
    Uses m_Output_Darwin;
    Type TOutput = Class(TOutputDarwin);
  {$ENDIF}
{$ENDIF}

Implementation

End.

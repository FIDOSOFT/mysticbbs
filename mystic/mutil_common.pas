Unit MUTIL_Common;

{$I M_OPS.PAS}

Interface

Uses
  INIFiles,
  m_Output,
  mutil_Status;

{$I RECORDS.PAS}

Var
  Console      : TOutput;
  INI          : TINIFile;
  BarOne       : TStatusBar;
  BarAll       : TStatusBar;
  ProcessTotal : Byte = 0;
  ProcessPos   : Byte = 0;
  bbsConfig    : RecConfig;

Const
  Header_GENERAL  = 'General';
  Header_IMPORTNA = 'Import_FIDONET.NA';

Implementation

Uses
  m_Strings;

End.

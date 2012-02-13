{
  Mystic Software Development Library
  ===========================================================================
  File    | M_TYPES.PAS
  Desc    | Common types used throughout the development library.
  Created | August 22, 2002
  ---------------------------------------------------------------------------
}

Unit m_Types;

{$I M_OPS.PAS}

Interface

{$IFDEF WINDOWS}
Uses
  Windows;
{$ENDIF}

Const
  {$IFDEF UNIX}
    PathSep = '/';
  {$ELSE}
    PathSep = '\';
  {$ENDIF}

Type
  TMenuFormFlagsRec = Set of 1..26;

  {$IFNDEF WINDOWS}
  TCharInfo = Record
    Attributes  : Byte;
    UnicodeChar : Char;
  End;
  {$ENDIF}

  TConsoleLineRec   = Array[1..80] of TCharInfo;
  TConsoleScreenRec = Array[1..50] of TConsoleLineRec;

  TConsoleImageRec  = Record
    Data    : TConsoleScreenRec;
    CursorX : Byte;
    CursorY : Byte;
    CursorA : Byte;
    X1      : Byte;
    X2      : Byte;
    Y1      : Byte;
    Y2      : Byte;
  End;

Implementation

End.

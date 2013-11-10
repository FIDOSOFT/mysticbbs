// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
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

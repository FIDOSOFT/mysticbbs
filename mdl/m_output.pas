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

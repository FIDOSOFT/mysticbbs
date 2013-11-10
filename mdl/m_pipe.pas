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

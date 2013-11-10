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
Unit m_Protocol_XModem;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_Protocol_Base,
  m_Protocol_Queue;

Type
  TProtocolXmodem = Class(TProtocolBase)
    DoCRC : Boolean;
    Do1K  : Boolean;

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;
  End;

Implementation

Constructor TProtocolXmodem.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  DoCRC := True;
  Do1K  := True;
End;

Destructor TProtocolXmodem.Destroy;
Begin
  Inherited Destroy;
End;

End.

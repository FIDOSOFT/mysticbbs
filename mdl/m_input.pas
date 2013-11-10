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
Unit m_Input;

{$I M_OPS.PAS}

Interface

{.$DEFINE USE_CRT_INPUT}

{$IFDEF OS2}
  {$DEFINE USE_CRT_INPUT}
{$ENDIF}

{$IFDEF USE_CRT_INPUT}
  {$WARNING ***** GENERIC CRT INPUT IS ENABLED *****}

  Uses
    m_Input_CRT;

  Type
    TInput = Class(TInputCRT);
{$ELSE}
  {$IFDEF WINDOWS}
    Uses m_Input_Windows;
    Type TInput = Class(TInputWindows);
  {$ENDIF}

  {$IFDEF LINUX}
    Uses m_Input_Linux;
    Type TInput = Class(TInputLinux);
  {$ENDIF}

  {$IFDEF DARWIN}
    Uses m_Input_Darwin;
    Type TInput = Class(TInputDarwin);
  {$ENDIF}
{$ENDIF}

Const
  keyALTA  = #30;
  keyALTB  = #48;
  keyALTC  = #46;
  keyALTD  = #32;
  keyALTE  = #18;
  keyALTH  = #35;
  keyALTI  = #23;
  keyALTJ  = #36;
  keyALTL  = #38;
  keyALTM  = #50;
  keyALTO  = #24;
  keyALTP  = #25;
  keyALTQ  = #16;
  keyALTR  = #19;
  keyALTS  = #31;
  keyALTT  = #20;
  keyALTX  = #45;
  keyALTY  = #21;
  keyALTZ  = #44;

  keyF1    = #59;
  keyF2    = #60;
  keyF3    = #61;
  keyF4    = #62;
  keyF5    = #63;
  keyF6    = #64;
  keyF7    = #65;
  keyF8    = #66;
  keyF9    = #67;
  keyF10   = #68;

  keyUP    = #72;
  keyDOWN  = #80;
  keyLEFT  = #75;
  keyRIGHT = #77;
  keyPGUP  = #73;
  keyPGDN  = #81;
  keyHOME  = #71;
  keyEND   = #79;
  keyDEL   = #83;

Implementation

End.

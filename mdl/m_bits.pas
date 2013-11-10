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

Unit m_Bits;

Interface

Function  BitCheck  (B: Byte; Size: Byte; Var Temp) : Boolean;
Procedure BitToggle (B: Byte; Size: Byte; Var Temp);
Procedure BitSet    (B: Byte; Size: Byte; Var Temp; IsOn: Boolean);

Implementation

Const
  Bit : Array[1..32] of Cardinal = (
          $00000001,  $00000002,
          $00000004,  $00000008,
          $00000010,  $00000020,
          $00000040,  $00000080,
          $00000100,  $00000200,
          $00000400,  $00000800,
          $00001000,  $00002000,
          $00004000,  $00008000,
          $00010000,  $00020000,
          $00040000,  $00080000,
          $00100000,  $00200000,
          $00400000,  $00800000,
          $01000000,  $02000000,
          $04000000,  $08000000,
          $10000000,  $20000000,
          $40000000,  $80000000
        );

Function BitCheck (B: Byte; Size: Byte; Var Temp) : Boolean;
Begin
  Result := False;
  Case Size of
    1 : Result := Byte(Temp) And Bit[B] <> 0;
    2 : Result := Word(Temp) And Bit[B] <> 0;
    4 : Result := LongInt(Temp) And Bit[B] <> 0;
  End;
End;

Procedure BitToggle (B: Byte; Size: Byte; Var Temp);
Begin
  Case Size of
    1 : Byte(Temp)    := Byte(Temp) XOR Bit[B];
    2 : Word(Temp)    := Word(Temp) XOR Bit[B];
    4 : LongInt(Temp) := LongInt(Temp) XOR Bit[B];
  End;
End;

Procedure BitSet (B: Byte; Size: Byte; Var Temp; IsOn: Boolean);
Begin
  If IsOn Then
    Case Size of
      1 : Byte(Temp)    := Byte(Temp) or Bit[B];
      2 : Word(Temp)    := Word(Temp) or Bit[B];
      4 : LongInt(Temp) := LongInt(Temp) or Bit[B];
    End
  Else
    Case Size of
      1 : Byte(Temp)    := Byte(Temp) And Not Bit[B];
      2 : Word(Temp)    := Word(Temp) And Not Bit[B];
      4 : LongInt(Temp) := LongInt(Temp) And Not Bit[B];
    End;
End;

End.

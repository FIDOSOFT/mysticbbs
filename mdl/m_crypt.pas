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
Unit m_Crypt;

{$I M_OPS.PAS}

Interface

// m_CRC should be merged into this

Function B64Encode     (S: String) : String;
Function B64Decode     (S: String) : String;
Function HMAC_MD5      (Text, Key: String) : String;
Function MD5           (Const Value: String) : String;
Function Digest2String (Digest: String) : String;
Function String2Digest (Str: String) : String;

Implementation

Uses
  m_Strings;

{$Q-}{$R-}

Type
  TMDTransform = Procedure (Var Buf: Array of LongInt; Const Data: Array of LongInt);

  TMDCtx = Record
    State       : array[0..3] of Integer;
    Count       : array[0..1] of Integer;
    BufAnsiChar : array[0..63] of Byte;
    BufLong     : array[0..15] of Integer;
  End;

Const
  B64Codes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

Function B64Encode (S: String) : String;
Var
  I : Integer;
  A : Integer;
  X : Integer;
  B : Integer;
Begin
  Result := '';
  A      := 0;
  B      := 0;

  For I := 1 to Length(S) Do Begin
    X := Byte(S[I]);
    B := B * 256 + X;
    A := A + 8;

    While A >= 6 Do Begin
      A      := A - 6;
      X      := B DIV (1 SHL a);
      B      := B MOD (1 SHL a);
      Result := Result + B64Codes[X + 1];
    End;
  End;

  If A > 0 Then Begin
    X      := B SHL (6 - A);
    Result := Result + B64Codes[X + 1];

    If A = 4 Then Result := Result + '=';
    If A = 2 Then Result := Result + '==';
  End;
End;

Function B64Decode (S: String) : String;
Var
  I : Integer;
  A : Integer;
  X : Integer;
  B : Integer;
Begin
  Result := '';
  A      := 0;
  B      := 0;

  For I := 1 to Length(S) Do Begin
    X := Pos(s[I], B64Codes) - 1;

    If X >= 0 Then Begin
      B := B * 64 + X;
      A := A + 6;

      If A >= 8 Then Begin
        A      := A - 8;
        X      := B SHR A;
        B      := B MOD (1 SHL A);
        X      := X MOD 256;
        Result := Result + Chr(X);
      End;
    End Else
      Exit;
  End;
End;

Function Digest2String (Digest: String) : String;
Var
  Count : Byte;
Begin
  Result := '';

  For Count := 1 to 16 Do
    Result :=  Result + Byte2Hex(Byte(Digest[Count]));

  Result[0] := #32;
End;

Function String2Digest (Str: String) : String;
Var
  Count : Byte;
Begin
  Result := '';
  Count  := 1;

  While Count < Length(Str) Do Begin
    Result := Result + Char(strH2I(Copy(Str, Count, 2)));
    Inc (Count, 2);
  End;
End;

Procedure MDInit(var MDContext: TMDCtx);
Var
  N: Integer;
Begin
  MDContext.Count[0] := 0;
  MDContext.Count[1] := 0;

  For N := 0 to High(MDContext.BufAnsiChar) Do
    MDContext.BufAnsiChar[n] := 0;

  For N := 0 to High(MDContext.BufLong) Do
    MDContext.BufLong[n] := 0;

  MDContext.State[0] := Integer($67452301);
  MDContext.State[1] := Integer($EFCDAB89);
  MDContext.State[2] := Integer($98BADCFE);
  MDContext.State[3] := Integer($10325476);
End;

Procedure ArrLongToByte (Var ArLong: Array of Integer; Var ArByte: Array of Byte);
Begin
  If (High(ArByte) + 1) < ((High(ArLong) + 1) * 4) Then
    Exit;

  Move (ArLong[0], ArByte[0], High(ArByte) + 1);
End;

Procedure ArrByteToLong (Var ArByte: Array of Byte; Var ArLong: Array of Integer);
Begin
  if (High(ArByte) + 1) > ((High(ArLong) + 1) * 4) Then
    Exit;

  Move (ArByte[0], ArLong[0], High(ArByte) + 1);
End;

Procedure MDUpdate (Var MDContext: TMDCtx; Const Data: String; Transform: TMDTransform);
Var
  Index, partLen, InputLen, I: Integer;
Begin
  InputLen := Length(Data);

  With MDContext do begin
    Index := (Count[0] shr 3) and $3F;

    Inc(Count[0], InputLen shl 3);

    If Count[0] < (InputLen shl 3) then
      Inc(Count[1]);

    Inc(Count[1], InputLen shr 29);

    PartLen := 64 - Index;

    if InputLen >= partLen then begin
      ArrLongToByte(BufLong, BufAnsiChar);

      Move(Data[1], BufAnsiChar[Index], partLen);

      ArrByteToLong(BufAnsiChar, BufLong);

      Transform(State, Buflong);

      I := partLen;

      while I + 63 < InputLen do begin
        ArrLongToByte(BufLong, BufAnsiChar);
        Move(Data[I+1], BufAnsiChar, 64);
        ArrByteToLong(BufAnsiChar, BufLong);
        Transform(State, Buflong);
        inc(I, 64);
      end;

      Index := 0;
    End Else
      I := 0;

    ArrLongToByte(BufLong, BufAnsiChar);
    Move(Data[I+1], BufAnsiChar[Index], InputLen-I);
    ArrByteToLong(BufAnsiChar, BufLong);
  End
End;

Procedure MD5Transform (Var Buf: Array of LongInt; const Data: Array of LongInt);
Var
  A, B, C, D: LongInt;

  Procedure Round1 (Var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  Begin
    Inc(W, (Z xor (X and (Y xor Z))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  End;

  Procedure Round2 (Var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  Begin
    Inc(W, (Y xor (Z and (X xor Y))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  End;

  Procedure Round3 (Var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  Begin
    Inc(W, (X xor Y xor Z) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  End;

  Procedure Round4 (Var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  Begin
    Inc(W, (Y xor (X or not Z)) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  End;

Begin
  A := Buf[0];
  B := Buf[1];
  C := Buf[2];
  D := Buf[3];

  Round1 (A, B, C, D, Data[0] + Longint($D76AA478), 7);
  Round1 (D, A, B, C, Data[1] + Longint($E8C7B756), 12);
  Round1 (C, D, A, B, Data[2] + Longint($242070DB), 17);
  Round1 (B, C, D, A, Data[3] + Longint($C1BDCEEE), 22);
  Round1 (A, B, C, D, Data[4] + Longint($F57C0FAF), 7);
  Round1 (D, A, B, C, Data[5] + Longint($4787C62A), 12);
  Round1 (C, D, A, B, Data[6] + Longint($A8304613), 17);
  Round1 (B, C, D, A, Data[7] + Longint($FD469501), 22);
  Round1 (A, B, C, D, Data[8] + Longint($698098D8), 7);
  Round1 (D, A, B, C, Data[9] + Longint($8B44F7AF), 12);
  Round1 (C, D, A, B, Data[10] + Longint($FFFF5BB1), 17);
  Round1 (B, C, D, A, Data[11] + Longint($895CD7BE), 22);
  Round1 (A, B, C, D, Data[12] + Longint($6B901122), 7);
  Round1 (D, A, B, C, Data[13] + Longint($FD987193), 12);
  Round1 (C, D, A, B, Data[14] + Longint($A679438E), 17);
  Round1 (B, C, D, A, Data[15] + Longint($49B40821), 22);

  Round2 (A, B, C, D, Data[1] + Longint($F61E2562), 5);
  Round2 (D, A, B, C, Data[6] + Longint($C040B340), 9);
  Round2 (C, D, A, B, Data[11] + Longint($265E5A51), 14);
  Round2 (B, C, D, A, Data[0] + Longint($E9B6C7AA), 20);
  Round2 (A, B, C, D, Data[5] + Longint($D62F105D), 5);
  Round2 (D, A, B, C, Data[10] + Longint($02441453), 9);
  Round2 (C, D, A, B, Data[15] + Longint($D8A1E681), 14);
  Round2 (B, C, D, A, Data[4] + Longint($E7D3FBC8), 20);
  Round2 (A, B, C, D, Data[9] + Longint($21E1CDE6), 5);
  Round2 (D, A, B, C, Data[14] + Longint($C33707D6), 9);
  Round2 (C, D, A, B, Data[3] + Longint($F4D50D87), 14);
  Round2 (B, C, D, A, Data[8] + Longint($455A14ED), 20);
  Round2 (A, B, C, D, Data[13] + Longint($A9E3E905), 5);
  Round2 (D, A, B, C, Data[2] + Longint($FCEFA3F8), 9);
  Round2 (C, D, A, B, Data[7] + Longint($676F02D9), 14);
  Round2 (B, C, D, A, Data[12] + Longint($8D2A4C8A), 20);

  Round3 (A, B, C, D, Data[5] + Longint($FFFA3942), 4);
  Round3 (D, A, B, C, Data[8] + Longint($8771F681), 11);
  Round3 (C, D, A, B, Data[11] + Longint($6D9D6122), 16);
  Round3 (B, C, D, A, Data[14] + Longint($FDE5380C), 23);
  Round3 (A, B, C, D, Data[1] + Longint($A4BEEA44), 4);
  Round3 (D, A, B, C, Data[4] + Longint($4BDECFA9), 11);
  Round3 (C, D, A, B, Data[7] + Longint($F6BB4B60), 16);
  Round3 (B, C, D, A, Data[10] + Longint($BEBFBC70), 23);
  Round3 (A, B, C, D, Data[13] + Longint($289B7EC6), 4);
  Round3 (D, A, B, C, Data[0] + Longint($EAA127FA), 11);
  Round3 (C, D, A, B, Data[3] + Longint($D4EF3085), 16);
  Round3 (B, C, D, A, Data[6] + Longint($04881D05), 23);
  Round3 (A, B, C, D, Data[9] + Longint($D9D4D039), 4);
  Round3 (D, A, B, C, Data[12] + Longint($E6DB99E5), 11);
  Round3 (C, D, A, B, Data[15] + Longint($1FA27CF8), 16);
  Round3 (B, C, D, A, Data[2] + Longint($C4AC5665), 23);

  Round4 (A, B, C, D, Data[0] + Longint($F4292244), 6);
  Round4 (D, A, B, C, Data[7] + Longint($432AFF97), 10);
  Round4 (C, D, A, B, Data[14] + Longint($AB9423A7), 15);
  Round4 (B, C, D, A, Data[5] + Longint($FC93A039), 21);
  Round4 (A, B, C, D, Data[12] + Longint($655B59C3), 6);
  Round4 (D, A, B, C, Data[3] + Longint($8F0CCC92), 10);
  Round4 (C, D, A, B, Data[10] + Longint($FFEFF47D), 15);
  Round4 (B, C, D, A, Data[1] + Longint($85845DD1), 21);
  Round4 (A, B, C, D, Data[8] + Longint($6FA87E4F), 6);
  Round4 (D, A, B, C, Data[15] + Longint($FE2CE6E0), 10);
  Round4 (C, D, A, B, Data[6] + Longint($A3014314), 15);
  Round4 (B, C, D, A, Data[13] + Longint($4E0811A1), 21);
  Round4 (A, B, C, D, Data[4] + Longint($F7537E82), 6);
  Round4 (D, A, B, C, Data[11] + Longint($BD3AF235), 10);
  Round4 (C, D, A, B, Data[2] + Longint($2AD7D2BB), 15);
  Round4 (B, C, D, A, Data[9] + Longint($EB86D391), 21);

  Inc (Buf[0], A);
  Inc (Buf[1], B);
  Inc (Buf[2], C);
  Inc (Buf[3], D);
End;

Function MDFinal (Var MDContext: TMDCtx; Transform: TMDTransform) : String;
Var
  Cnt    : Word;
  P      : Byte;
  Digest : Array[0..15] of Byte;
  I      : Integer;
  N      : Integer;
Begin
  For I := 0 to 15 Do
    Digest[I] := I + 1;

  With MDContext Do Begin
    Cnt := (Count[0] shr 3) and $3F;
    P := Cnt;
    BufAnsiChar[P] := $80;
    Inc(P);
    Cnt := 64 - 1 - Cnt;

    if Cnt < 8 then begin
      for n := 0 to cnt - 1 do
        BufAnsiChar[P + n] := 0;

      ArrByteToLong(BufAnsiChar, BufLong);
      Transform(State, BufLong);
      ArrLongToByte(BufLong, BufAnsiChar);

      For N := 0 to 55 Do
        BufAnsiChar[N] := 0;

      ArrByteToLong(BufAnsiChar, BufLong);
    End Else Begin
      For N := 0 to Cnt - 8 - 1 Do
        BufAnsiChar[p + n] := 0;

      ArrByteToLong(BufAnsiChar, BufLong);
    End;

    BufLong[14] := Count[0];
    BufLong[15] := Count[1];

    Transform(State, BufLong);
    ArrLongToByte(State, Digest);

    Result := '';

    For I := 0 to 15 Do
      Result := Result + Char(Digest[I]);
  End;
End;

Function MD5 (Const Value: String): String;
Var
  MDContext: TMDCtx;
Begin
  MDInit   (MDContext);
  MDUpdate (MDContext, Value, @MD5Transform);

  Result := MDFinal(MDContext, @MD5Transform);
End;

Function HMAC_MD5(Text, Key: string): string;
Var
  ipad, opad, s: string;
  n: Integer;
  MDContext: TMDCtx;
Begin
  If Length(Key) > 64 then
    Key := md5(Key);

  ipad := StringOfChar(#$36, 64);
  opad := StringOfChar(#$5C, 64);

  For n := 1 to Length(Key) do begin
    ipad[n] := char(Byte(ipad[n]) xor Byte(Key[n]));
    opad[n] := char(Byte(opad[n]) xor Byte(Key[n]));
  End;

  MDInit(MDContext);
  MDUpdate(MDContext, ipad, @MD5Transform);
  MDUpdate(MDContext, Text, @MD5Transform);

  S := MDFinal(MDContext, @MD5Transform);

  MDInit(MDContext);
  MDUpdate(MDContext, opad, @MD5Transform);
  MDUpdate(MDContext, s, @MD5Transform);

  Result := MDFinal(MDContext, @MD5Transform);
End;

End.

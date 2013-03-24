Unit m_Crypt;

{$I M_OPS.PAS}

Interface

// merge in m_Crc, rewrite googled and shitty hextobyte function

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

// rewrite the terribad functions now that this stuff is working

function HexToByte (Hex: String) : byte;
var
  n, n2, sayi: Integer;
Begin
  n  := 0;
  n2 := 0;

  Case Hex[1] Of
    'A','a': n:= 10;
    'B','b': n:= 11;
    'C','c': n:= 12;
    'D','d': n:= 13;
    'E','e': n:= 14;
    'F','f': n:= 15;
  End;

  If Hex[1] in ['0','1','2','3','4','5','6','7','8','9'] Then
    n := strS2I(Hex[1]);

  Case Hex[2] Of
    'A','a': n2:= 10;
    'B','b': n2:= 11;
    'C','c': n2:= 12;
    'D','d': n2:= 13;
    'E','e': n2:= 14;
    'F','f': n2:= 15;
  End;

  If Hex[2] in ['0','1','2','3','4','5','6','7','8','9'] Then
    n2 := strS2I(Hex[2]);

  sayi   := n * 16 + n2;
  Result := sayi;
End;

Function Byte2Hex (numb: Byte) : String;
Const
  HexChars : Array[0..15] of Char = '0123456789abcdef';
begin
//  setlength(result, 2);
  Byte2Hex[0] := #2;
  Byte2Hex[1] := HexChars[numb shr 4];
  Byte2Hex[2] := HexChars[numb and 15];
end;

Function Digest2String (Digest: String) : String;
var
  count : byte;
Begin
  result := '';

  for count := 1 to 16 do
    result :=  result + byte2hex(byte(digest[count]));

  result[0] := #32;
End;

Function String2Digest (Str: string) : string;
var
  count : byte;
begin
  result := '';
  count  := 1;

  while count < length(str) do begin
    result := result + char(hextobyte(copy(str, count, 2)));
    inc (count, 2);
  end;
end;

procedure MDInit(var MDContext: TMDCtx);
var
  n: integer;
begin
  MDContext.Count[0] := 0;
  MDContext.Count[1] := 0;

  for n := 0 to high(MDContext.BufAnsiChar) do
    MDContext.BufAnsiChar[n] := 0;

  for n := 0 to high(MDContext.BufLong) do
    MDContext.BufLong[n] := 0;

  MDContext.State[0] := Integer($67452301);
  MDContext.State[1] := Integer($EFCDAB89);
  MDContext.State[2] := Integer($98BADCFE);
  MDContext.State[3] := Integer($10325476);
end;

procedure ArrLongToByte(var ArLong: Array of Integer; var ArByte: Array of byte);
begin
  if (High(ArByte) + 1) < ((High(ArLong) + 1) * 4) then
    Exit;

  Move(ArLong[0], ArByte[0], High(ArByte) + 1);
end;

procedure ArrByteToLong(var ArByte: Array of byte; var ArLong: Array of Integer);
begin
  if (High(ArByte) + 1) > ((High(ArLong) + 1) * 4) then
    Exit;

  Move(ArByte[0], ArLong[0], High(ArByte) + 1);
end;

procedure MDUpdate(var MDContext: TMDCtx; const Data: string; transform: TMDTransform);
var
  Index, partLen, InputLen, I: integer;
begin
  InputLen := Length(Data);

  with MDContext do begin
    Index := (Count[0] shr 3) and $3F;
    Inc(Count[0], InputLen shl 3);
    if Count[0] < (InputLen shl 3) then
      Inc(Count[1]);
    Inc(Count[1], InputLen shr 29);
    partLen := 64 - Index;

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
    end else
      I := 0;

    ArrLongToByte(BufLong, BufAnsiChar);
    Move(Data[I+1], BufAnsiChar[Index], InputLen-I);
    ArrByteToLong(BufAnsiChar, BufLong);
  end
end;

procedure MD5Transform(var Buf: array of LongInt; const Data: array of LongInt);
var
  A, B, C, D: LongInt;

  procedure Round1(var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  begin
    Inc(W, (Z xor (X and (Y xor Z))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  procedure Round2(var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  begin
    Inc(W, (Y xor (Z and (X xor Y))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  procedure Round3(var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  begin
    Inc(W, (X xor Y xor Z) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  procedure Round4(var W: LongInt; X, Y, Z, Data: LongInt; S: Byte);
  begin
    Inc(W, (Y xor (X or not Z)) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;
begin
  A := Buf[0];
  B := Buf[1];
  C := Buf[2];
  D := Buf[3];

  Round1(A, B, C, D, Data[0] + Longint($D76AA478), 7);
  Round1(D, A, B, C, Data[1] + Longint($E8C7B756), 12);
  Round1(C, D, A, B, Data[2] + Longint($242070DB), 17);
  Round1(B, C, D, A, Data[3] + Longint($C1BDCEEE), 22);
  Round1(A, B, C, D, Data[4] + Longint($F57C0FAF), 7);
  Round1(D, A, B, C, Data[5] + Longint($4787C62A), 12);
  Round1(C, D, A, B, Data[6] + Longint($A8304613), 17);
  Round1(B, C, D, A, Data[7] + Longint($FD469501), 22);
  Round1(A, B, C, D, Data[8] + Longint($698098D8), 7);
  Round1(D, A, B, C, Data[9] + Longint($8B44F7AF), 12);
  Round1(C, D, A, B, Data[10] + Longint($FFFF5BB1), 17);
  Round1(B, C, D, A, Data[11] + Longint($895CD7BE), 22);
  Round1(A, B, C, D, Data[12] + Longint($6B901122), 7);
  Round1(D, A, B, C, Data[13] + Longint($FD987193), 12);
  Round1(C, D, A, B, Data[14] + Longint($A679438E), 17);
  Round1(B, C, D, A, Data[15] + Longint($49B40821), 22);

  Round2(A, B, C, D, Data[1] + Longint($F61E2562), 5);
  Round2(D, A, B, C, Data[6] + Longint($C040B340), 9);
  Round2(C, D, A, B, Data[11] + Longint($265E5A51), 14);
  Round2(B, C, D, A, Data[0] + Longint($E9B6C7AA), 20);
  Round2(A, B, C, D, Data[5] + Longint($D62F105D), 5);
  Round2(D, A, B, C, Data[10] + Longint($02441453), 9);
  Round2(C, D, A, B, Data[15] + Longint($D8A1E681), 14);
  Round2(B, C, D, A, Data[4] + Longint($E7D3FBC8), 20);
  Round2(A, B, C, D, Data[9] + Longint($21E1CDE6), 5);
  Round2(D, A, B, C, Data[14] + Longint($C33707D6), 9);
  Round2(C, D, A, B, Data[3] + Longint($F4D50D87), 14);
  Round2(B, C, D, A, Data[8] + Longint($455A14ED), 20);
  Round2(A, B, C, D, Data[13] + Longint($A9E3E905), 5);
  Round2(D, A, B, C, Data[2] + Longint($FCEFA3F8), 9);
  Round2(C, D, A, B, Data[7] + Longint($676F02D9), 14);
  Round2(B, C, D, A, Data[12] + Longint($8D2A4C8A), 20);

  Round3(A, B, C, D, Data[5] + Longint($FFFA3942), 4);
  Round3(D, A, B, C, Data[8] + Longint($8771F681), 11);
  Round3(C, D, A, B, Data[11] + Longint($6D9D6122), 16);
  Round3(B, C, D, A, Data[14] + Longint($FDE5380C), 23);
  Round3(A, B, C, D, Data[1] + Longint($A4BEEA44), 4);
  Round3(D, A, B, C, Data[4] + Longint($4BDECFA9), 11);
  Round3(C, D, A, B, Data[7] + Longint($F6BB4B60), 16);
  Round3(B, C, D, A, Data[10] + Longint($BEBFBC70), 23);
  Round3(A, B, C, D, Data[13] + Longint($289B7EC6), 4);
  Round3(D, A, B, C, Data[0] + Longint($EAA127FA), 11);
  Round3(C, D, A, B, Data[3] + Longint($D4EF3085), 16);
  Round3(B, C, D, A, Data[6] + Longint($04881D05), 23);
  Round3(A, B, C, D, Data[9] + Longint($D9D4D039), 4);
  Round3(D, A, B, C, Data[12] + Longint($E6DB99E5), 11);
  Round3(C, D, A, B, Data[15] + Longint($1FA27CF8), 16);
  Round3(B, C, D, A, Data[2] + Longint($C4AC5665), 23);

  Round4(A, B, C, D, Data[0] + Longint($F4292244), 6);
  Round4(D, A, B, C, Data[7] + Longint($432AFF97), 10);
  Round4(C, D, A, B, Data[14] + Longint($AB9423A7), 15);
  Round4(B, C, D, A, Data[5] + Longint($FC93A039), 21);
  Round4(A, B, C, D, Data[12] + Longint($655B59C3), 6);
  Round4(D, A, B, C, Data[3] + Longint($8F0CCC92), 10);
  Round4(C, D, A, B, Data[10] + Longint($FFEFF47D), 15);
  Round4(B, C, D, A, Data[1] + Longint($85845DD1), 21);
  Round4(A, B, C, D, Data[8] + Longint($6FA87E4F), 6);
  Round4(D, A, B, C, Data[15] + Longint($FE2CE6E0), 10);
  Round4(C, D, A, B, Data[6] + Longint($A3014314), 15);
  Round4(B, C, D, A, Data[13] + Longint($4E0811A1), 21);
  Round4(A, B, C, D, Data[4] + Longint($F7537E82), 6);
  Round4(D, A, B, C, Data[11] + Longint($BD3AF235), 10);
  Round4(C, D, A, B, Data[2] + Longint($2AD7D2BB), 15);
  Round4(B, C, D, A, Data[9] + Longint($EB86D391), 21);

  Inc(Buf[0], A);
  Inc(Buf[1], B);
  Inc(Buf[2], C);
  Inc(Buf[3], D);
end;

function MDFinal(var MDContext: TMDCtx; transform: TMDTransform): string;
var
  Cnt: Word;
  P: Byte;
  digest: array[0..15] of Byte;
  i: Integer;
  n: integer;
begin
  for I := 0 to 15 do
    Digest[I] := I + 1;

  with MDContext do begin
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

      for n := 0 to 55 do
        BufAnsiChar[n] := 0;

      ArrByteToLong(BufAnsiChar, BufLong);
    end else begin
      for n := 0 to Cnt - 8 - 1 do
        BufAnsiChar[p + n] := 0;

      ArrByteToLong(BufAnsiChar, BufLong);
    end;

    BufLong[14] := Count[0];
    BufLong[15] := Count[1];

    Transform(State, BufLong);
    ArrLongToByte(State, Digest);

    Result := '';

    for i := 0 to 15 do
      Result := Result + char(digest[i]);
  end;
end;

function MD5(const Value: string): string;
var
  MDContext: TMDCtx;
begin
  MDInit(MDContext);
  MDUpdate(MDContext, Value, @MD5Transform);

  Result := MDFinal(MDContext, @MD5Transform);
end;

function HMAC_MD5(Text, Key: string): string;
var
  ipad, opad, s: string;
  n: Integer;
  MDContext: TMDCtx;
begin
  if Length(Key) > 64 then
    Key := md5(Key);

  ipad := StringOfChar(#$36, 64);
  opad := StringOfChar(#$5C, 64);

  for n := 1 to Length(Key) do begin
    ipad[n] := char(Byte(ipad[n]) xor Byte(Key[n]));
    opad[n] := char(Byte(opad[n]) xor Byte(Key[n]));
  end;

  MDInit(MDContext);
  MDUpdate(MDContext, ipad, @MD5Transform);
  MDUpdate(MDContext, Text, @MD5Transform);

  s := MDFinal(MDContext, @MD5Transform);

  MDInit(MDContext);
  MDUpdate(MDContext, opad, @MD5Transform);
  MDUpdate(MDContext, s, @MD5Transform);

  Result := MDFinal(MDContext, @MD5Transform);
end;

end.

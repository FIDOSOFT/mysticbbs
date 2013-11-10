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
Unit m_Strings;

{$I M_OPS.PAS}

Interface

Function strPadR      (Str: String; Len: Byte; Ch: Char) : String;
Function strPadC      (Str: String; Len: Byte; Ch: Char) : String;
Function strPadL      (Str: String; Len: Byte; Ch: Char) : String;
Function strUpper     (Str: String) : String;
Function strLower     (Str: String) : String;
Function strRep       (Ch: Char; Len: Byte) : String;
Function strZero      (Num: LongInt) : String;
Function strComma     (Num: LongInt) : String;
Function strI2S       (Num: LongInt) : String;
Function strH2I       (Str: String) : LongInt;
Function strI2H       (Num: LongInt; Idx: Byte) : String;
//Function strI2Base    (Base: Byte; Num: Int64; Pad: Integer) : String;
Function strS2I       (Str: String) : Int64;
Function strI2O       (Num: LongInt) : String;
Function strR2S       (Num: Real; Deci: Byte) : String;
Function strWordGet   (Num: Byte; Str: String; Ch: Char) : String;
Function strWordPos   (Num: Byte; Str: String; Ch: Char) : Byte;
Function strWordCount (Str: String; Ch: Char) : Byte;
Function strStripL    (Str: String; Ch: Char) : String;
Function strStripR    (Str: String; Ch: Char) : String;
Function strStripB    (Str: String; Ch: Char) : String;
Function strStripLow  (Str: String) : String;
Function strStripPipe (Str: String) : String;
Function strStripMCI  (Str: String) : String;
Function strMCILen    (Str: String) : Byte;
Function strInitials  (Str: String) : String;
Function strWrap      (Var Str1, Str2: String; WrapPos: Byte) : Byte;
Function strReplace   (Str, OldStr, NewStr: String) : String;
Function strWide2Str  (Var Str: String; MaxLen: Byte) : String;
Function strYN        (Bol: Boolean) : String;
Function LoCase       (Ch: Char) : Char;
Function Byte2Hex     (Num: Byte) : String;

Implementation

Function strPadR (Str: String; Len: Byte; Ch: Char) : String;
Begin
  If Length(Str) > Len Then
    Str := Copy(Str, 1, Len)
  Else
    While Length(Str) < Len Do Str := Str + Ch;

  Result := Str;
End;

Function strPadC (Str: String; Len: Byte; Ch: Char) : String;
Var
  Space : Byte;
  Temp  : Byte;
Begin
  If Length(Str) > Len Then Begin
    Str[0] := Chr(Len);
    Result := Str;

    Exit;
  End;

  Space  := (Len - Length(Str)) DIV 2;
  Temp   := Len - ((Space * 2) + Length(Str));
  Result := strRep(Ch, Space) + Str + strRep(Ch, Space + Temp);
End;

Function strPadL (Str: String; Len: Byte; Ch: Char): String;
Var
  TStr : String;
Begin
  If Length(Str) >= Len Then
    Result := Copy(Str, 1, Len)
  Else Begin
    FillChar  (TStr[1], Len, Ch);
    SetLength (TStr, Len - Length(Str));

    Result  := TStr + Str;
  End;
End;

Function strLower (Str: String) : String;
Var
  Count : Byte;
Begin
  For Count := 1 to Length(Str) Do
    Str[Count] := LoCase(Str[Count]);

  Result := Str;
End;

Function strUpper (Str: String) : String;
Var
  Count : Byte;
Begin
  For Count := 1 to Length(Str) Do
    Str[Count] := UpCase(Str[Count]);

  Result := Str;
End;

Function strWide2Str (Var Str: String; MaxLen: Byte) : String;
Var
  i: Word;
  TmpStr: String;
Begin
  Move(Str, TmpStr[1], MaxLen);
  TmpStr[0] := Chr(MaxLen);
  i := Pos(#0, TmpStr);
  If i > 0 Then TmpStr[0] := Chr(i - 1);
  Result := TmpStr;
End;

Function strRep (Ch: Char; Len: Byte) : String;
Var
  Count : Byte;
  Str   : String;
Begin
  Str := '';
  For Count := 1 to Len Do Str := Str + Ch;
  Result := Str;
End;

Function strZero (Num: LongInt) : String;
Begin
  If Length(strI2S(Num)) = 1 Then
    Result := '0' + strI2S(Num)
  Else
    Result := Copy(strI2S(Num), 1, 2);
End;

Function strComma (Num: LongInt) : String;
Var
  Res   : String;
  Count : Integer;
Begin
  Str (Num:0, Res);

  Count := Length(Res) - 2;

  While Count > 1 Do Begin
    Insert (',', Res, Count);
    Dec (Count, 3);
  End;

  Result := Res;
End;

Function strH2I (Str: String) : LongInt;
Var
  Count : Byte;
Begin
  Result := 0;
  Count  := 1;

  If Str = '' Then Exit;

  If Str[1] = '$' Then Inc(Count);

  While Count <= Length(Str) Do Begin
    If Str[Count] in ['0'..'9'] Then
      Result := (Result SHL 4) OR (Ord(Str[Count]) - Ord('0'))
    Else
    If UpCase(Str[Count]) in ['A'..'F'] Then
      Result := (Result SHL 4) OR (Ord(UpCase(Str[Count])) - Ord('A') + 10)
    Else
      Break;

    Inc (Count);
  End;
End;

(*
Function strI2Base (Base: Byte; Num: Int64; Pad: Integer) : String;
Const
  B36Codes = '0123456789abcdefghijklmnopqrstuvwxyz';
Begin
  Result := '';

  Repeat
    Result := B36Codes[Num MOD Base + 1] + Result;
    Num    := Num DIV Base;
  Until Num = 0;

  If Pad > 0 Then
    Result := strPadL(Result, Pad, '0');
End;
*)

Function strI2H (Num: LongInt; Idx: Byte) : String;
Var
  Ch : Char;
Begin
  Result := strRep('0', Idx);

  While Num <> 0 Do Begin
    Ch := Chr(48 + Byte(Num) AND $0F);

    If Ch > '9' Then Inc (Ch, 39);

    Result[Idx] := Ch;
    Dec (Idx);
    Num := Num SHR 4;
  End;
End;

Function strI2O (Num: LongInt) : String; { int to octal string }
Var
  Count : LongInt;
  Res   : String;
Begin
  strI2O := '';
  Count  := 0;

  While True Do Begin
    Count := Count + 1;
    Res   := OctStr(Num, Count);

    If (Res[1] = '0') And Not ((Num = 8) And (Count = 1)) Then Begin
      If Length(Res) > 1 Then Delete (Res, 1, 1);
      Break;
    End;
  End;

  strI2O := Res;
End;

Function strI2S (Num: LongInt) : String;
Begin
  Str(Num, Result);
End;

Function strR2S (Num: Real; Deci: Byte) : String;
Begin
  Str (Num:0:Deci, Result);
End;

Function strS2I (Str: String) : Int64;
Var
  Res  : LongInt;
  Temp : Int64;
Begin
  Val (strStripB(Str, ' '), Temp, Res);

  If Res = 0 Then
    Result := Temp
  Else
    Result := 0;
End;

Function strWordCount (Str: String; Ch: Char) : Byte;
Var
  Start : Byte;
Begin
  Result := 0;

  If Ch = ' ' Then
    While Str[1] = Ch Do
      Delete (Str, 1, 1);

  If Str = '' Then Exit;

  Result := 1;

  While Pos(Ch, Str) > 0 Do Begin
    Inc (Result);

    Start := Pos(Ch, Str);

    If Ch = ' ' Then Begin
      While Str[Start] = Ch Do
        Delete (Str, Start, 1);
    End Else
      Delete (Str, Start, 1);
  End;
End;

Function strWordPos (Num: Byte; Str: String; Ch: Char) : Byte;
Var
  Count : Byte;
  Temp  : Byte;
Begin
  Result := 1;
  Count  := 1;

  While Count < Num Do Begin
    Temp := Pos(Ch, Str);

    If Temp = 0 Then Exit;

    Delete (Str, 1, Temp);

    While Str[1] = Ch Do Begin
      Delete (Str, 1, 1);
      Inc (Temp);
    End;

    Inc (Count);

    Inc (Result, Temp);
  End;
End;

Function strWordGet (Num: Byte; Str: String; Ch: Char) : String;
Var
  Count : Byte;
  Temp  : String;
  Start : Byte;
Begin
  Result := '';
  Count  := 1;
  Temp   := Str;

  If Ch = ' ' Then
    While Temp[1] = Ch Do
      Delete (Temp, 1, 1);

  While Count < Num Do Begin
    Start := Pos(Ch, Temp);

    If Start = 0 Then Exit;

    If Ch = ' ' Then Begin
      While Temp[Start] = Ch Do
        Inc (Start);

      Dec(Start);
    End;

    Delete (Temp, 1, Start);
    Inc    (Count);
  End;

  If Pos(Ch, Temp) > 0 Then
    Result := Copy(Temp, 1, Pos(Ch, Temp) - 1)
  Else
    Result := Temp;
End;

Function strStripLow (Str: String) : String;
Var
  Count : Byte;
Begin
  Count := 1;

  While Count <= Length(Str) Do
   If Str[Count] in [#00..#31] Then
     Delete (Str, Count, 1)
   Else
     Inc(Count);

  strStripLow := Str;
End;

Function strStripPipe (Str: String) : String;
Var
  Count : Byte;
  Code  : String[2];
Begin
  Result := '';
  Count  := 1;

  While Count <= Length(Str) Do Begin
    If (Str[Count] = '|') and (Count < Length(Str) - 1) Then Begin
      Code := Copy(Str, Count + 1, 2);
      If (Code = '00') or ((strS2I(Code) > 0) and (strS2I(Code) < 24)) Then
      Else
        Result := Result + '|' + Code;

      Inc (Count, 2);
    End Else
      Result := Result + Str[Count];

    Inc (Count);
  End;
End;

Function strStripMCI (Str: String) : String;
Begin
  While Pos('|', Str) > 0 Do
    Delete (Str, Pos('|', Str), 3);

  Result := Str;
End;

Function strMCILen (Str: String) : Byte;
Var
  A : Byte;
Begin
  Repeat
    A := Pos('|', Str);
    If (A > 0) and (A < Length(Str) - 1) Then
      Delete (Str, A, 3)
    Else
      Break;
  Until False;

  Result := Length(Str);
End;

Function strInitials (Str: String) : String;
Begin
  Result := Str[1];

  If Pos(' ', Str) > 0 Then
    Result := Result + Str[Succ(Pos(' ', Str))]
  Else
    Result := Result + Str[2];
End;

Function strWrap (Var Str1, Str2: String; WrapPos: Byte) : Byte;
Var
  Count : Byte;
Begin
  Result := 0;
  Str2   := '';

  If (Pos(' ', Str1) = 0) or (Length(Str1) < WrapPos) Then Exit;

  For Count := Length(Str1) DownTo 1 Do
    If (Str1[Count] = ' ') and (Count < WrapPos) Then Begin
      Str2 := Copy(Str1, Succ(Count), Length(Str1));
      Delete (Str1, Count, Length(Str1));
      Result := Count;
      Exit;
    End;
End;

Function strReplace (Str, OldStr, NewStr: String) : String;
Var
  A : Byte;
Begin
  While Pos(OldStr, Str) > 0 Do Begin
    A := Pos(OldStr, Str);
    Delete (Str, A, Length(OldStr));
    Insert (NewStr, Str, A);
  End;

  Result := Str;
End;

Function LoCase (Ch: Char) : Char;
Begin
  If (Ch in ['A'..'Z']) Then
    LoCase := Chr(Ord(Ch) + 32)
  Else
    LoCase := Ch;
End;

Function strStripL (Str: String; Ch: Char) : String;
Begin
  While ((Str[1] = Ch) and (Length(Str) > 0)) Do
    Str := Copy(Str, 2, Length(Str));

  Result := Str;
End;

Function strStripR (Str: String; Ch: Char) : String;
Begin
  While Str[Length(Str)] = Ch Do Dec(Str[0]);
  Result := Str;
End;

Function strStripB (Str: String; Ch: Char) : String;
Begin
  Result := strStripR(strStripL(Str, Ch), Ch);
End;

Function strYN (Bol: Boolean) : String;
Begin
  If Bol Then Result := 'Yes' Else Result := 'No';
End;

Function Byte2Hex (Num: Byte) : String;
Const
  HexChars : Array[0..15] of Char = '0123456789abcdef';
Begin
  Byte2Hex[0] := #2;
  Byte2Hex[1] := HexChars[Num SHR 4];
  Byte2Hex[2] := HexChars[Num AND 15];
End;

End.

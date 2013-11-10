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
Unit m_IniReader;

{$I M_OPS.PAS}

Interface

Type
  TIniReader = Class
    FileName   : String;
    IniFile    : Text;
    Buffer     : Array[1..1024*4] of Char;
    Opened     : Boolean;
    Sequential : Boolean;
    CurrentCat : String;

    Constructor Create (FN: String);
    Destructor  Destroy; Override;
    Procedure   SetSequential (S: Boolean);
    Function    ReadString    (Category, Value, DefValue: String) : String;
    Function    ReadInteger   (Category, Value: String; DefValue: LongInt) : LongInt;
    Function    ReadBoolean   (Category, Value: String; DefValue: Boolean) : Boolean;
  End;

Implementation

Uses
  m_Strings;

Constructor TIniReader.Create (FN: String);
Begin
  Sequential := False;
  CurrentCat := '';
  FileName   := FN;
  FileMode   := 66;

  Assign     (IniFile, FileName);
  SetTextBuf (IniFile, Buffer);
  Reset      (IniFile);

  Opened := IoResult = 0;
End;

Destructor TIniReader.Destroy;
Begin
  If Opened Then Close(IniFile);
End;

Procedure TIniReader.SetSequential (S: Boolean);
Begin
  Sequential := S;
  CurrentCat := '';

  If Opened Then Reset(IniFile);
End;

Function TIniReader.ReadString (Category, Value, DefValue: String) : String;
Var
  RawStr : String;
  NewStr : String;
  GotCat : Boolean = False;
Begin
  Result := DefValue;

  If Not Opened Then Exit;

  Category := strUpper(Category);
  Value    := strUpper(Value);

  If Not Sequential Then Reset (IniFile);

  If Sequential and (CurrentCat = Category) Then
    GotCat := True
  Else
    While Not GotCat And Not Eof(IniFile) Do Begin
      ReadLn (IniFile, RawStr);

      RawStr := strStripB(RawStr, ' ');
      NewStr := strUpper(strStripLOW(RawStr));

      If (RawStr = '') or (RawStr[1] = ';') Then Continue;

      GotCat := Pos('[' + Category + ']', NewStr) > 0;
    End;

  If Not GotCat Then Exit;

  CurrentCat := Category;

  While Not Eof(IniFile) Do Begin
    ReadLn (IniFile, RawStr);

    RawStr := strStripB(RawStr, ' ');
    NewStr := strUpper(strStripLOW(RawStr));

    If (RawStr = '') or (RawStr[1] = ';') Then Continue;

    If RawStr[1] = '[' Then Exit;

    If (Pos(Value, NewStr) = 1) and (Pos('=', NewStr) > 0) Then Begin
      Result := strStripB(Copy(RawStr, Pos('=', RawStr) + 1, 255), ' ');
      Exit;
    End;
  End;
End;

Function TIniReader.ReadInteger (Category, Value: String; DefValue: LongInt) : LongInt;
Begin
  Result := strS2I(ReadString(Category, Value, strI2S(DefValue)));
End;

Function TIniReader.ReadBoolean (Category, Value: String; DefValue: Boolean) : Boolean;
Var
  DefStr : String;
Begin
  If DefValue Then
    DefStr := 'TRUE'
  Else
    DefStr := 'FALSE';

  Result := strUpper(ReadString(Category, Value, DefStr)) = 'TRUE';
End;


End.

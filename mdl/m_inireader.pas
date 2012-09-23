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
    Function    ReadString  (Category, Value, DefValue: String) : String;
    Function    ReadInteger (Category, Value: String; DefValue: LongInt) : LongInt;
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

End.

Unit MIS_Common;

{$I M_OPS.PAS}

Interface

Uses
  m_Output,
  m_Term_Ansi;

{$I RECORDS.PAS}

Var
  bbsConfig : RecConfig;
  Console   : TOutput;
  Term      : TTermAnsi;

Function SearchForUser    (UN: String; Var Rec: RecUser; Var RecPos: LongInt) : Boolean;
Function CheckAccess      (User: RecUser; IgnoreGroup: Boolean; Str: String) : Boolean;
Function WildcardMatch    (Wildcard, FName: String) : Boolean;
Function GetSecurityLevel (Level: Byte; SecLevel: RecSecurity) : Boolean;

Implementation

Uses
  m_FileIO,
  m_DateTime,
  m_Strings;

Function SearchForUser (UN: String; Var Rec: RecUser; Var RecPos: LongInt) : Boolean;
Var
  UserFile : TBufFile;
Begin
  Result := False;
  UN     := strUpper(UN);

  If UN = '' Then Exit;

  UserFile := TBufFile.Create(4096);

  If UserFile.Open(bbsConfig.DataPath + 'users.dat', fmOpen, fmRWDN, SizeOf(RecUser)) Then
    While Not UserFile.EOF Do Begin
      UserFile.Read(Rec);

      If Rec.Flags AND UserDeleted <> 0 Then Continue;

      If (UN = strUpper(Rec.RealName)) or (UN = strUpper(Rec.Handle)) Then Begin
        RecPos := UserFile.FilePos;
        Result := True;
        Break;
      End;
    End;

  UserFile.Free;
End;

Function CheckAccess (User: RecUser; IgnoreGroup: Boolean; Str: String) : Boolean;
Const
  OpCmds  = ['%', '^', '(', ')', '&', '!', '|'];
  AcsCmds = ['A', 'D', 'E', 'F', 'G', 'H', 'M', 'N', 'O', 'S', 'T', 'U', 'W', 'Z'];
Var
  Key   : Char;
  Data  : String;
  Check : Boolean;
  Out   : String;
  First : Boolean;

  Procedure CheckCommand;
  Var
    Res : Boolean;
  Begin
    Res := False;

    Case Key of
      'A' : Res := True;
      'D' : Res := (Ord(Data[1]) - 64) in User.AF2;
      'E' : Case Data[1] of
              '1' : Res := True;
              '0' : Res := True;
            End;
      'F' : Res := (Ord(Data[1]) - 64) in User.AF1;
      'G' : If IgnoreGroup Then Begin
              First := True;
              Check := False;
              Data  := '';
              Exit;
            End Else
              Res := User.LastMGroup = strS2I(Data);
      'H' : Res := strS2I(Data) < strS2I(Copy(TimeDos2Str(CurDateDos, False), 1, 2));
      'M' : Res := strS2I(Data) < strS2I(Copy(TimeDos2Str(CurDateDos, False), 4, 2));
      'N' : Res := True;
      'O' : Case Data[1] of
              'A' : Res := True;
              'I' : Res := True;
              'K' : Res := True;
              'P' : If (User.Calls > 0) And (User.Flags AND UserNoRatio = 0) Then Begin
                      //Temp1  := Round(Security.PCRatio / 100 * 100);
                      //Temp2  := Round(User.ThisUser.Posts / User.ThisUser.Calls * 100);
                      //Res := (Temp2 >= Temp1);
                      Res := True;
                    End Else
                      Res := True;
            End;
      'S' : Res := User.Security >= strS2I(Data);
      'T' : Res := True;
      'U' : Res := User.PermIdx = strS2I(Data);
      'W' : Res := strS2I(Data) = m_DateTime.DayOfWeek(CurDateDos);
      'Z' : If IgnoreGroup Then Begin
              Check := False;
              First := True;
              Data  := '';
              Exit;
            End Else
              Res := strS2I(Data) = User.LastFGroup;
    End;

    If Res Then Out := Out + '^' Else Out := Out + '%';

    Check := False;
    First := True;
    Data  := '';
  End;

Var
  A      : Byte;
  Paran1 : Byte;
  Paran2 : Byte;
  Ch1    : Char;
  Ch2    : Char;
  S1     : String;
Begin
  Data  := '';
  Out   := '';
  Check := False;
  Str   := strUpper(Str);
  First := True;

  For A := 1 to Length(Str) Do
    If Str[A] in OpCmds Then Begin
      If Check Then CheckCommand;
      Out := Out + Str[A];
    End Else
    If (Str[A] in AcsCmds) and (First or Check) Then Begin
      If Check Then CheckCommand;
      Key := Str[A];
      If First Then First := False;
    End Else Begin
      Data  := Data + Str[A];
      Check := True;
      If A = Length(Str) Then CheckCommand;
    End;

  Out := '(' + Out + ')';

  While Pos('&',  Out) <> 0 Do Delete (Out, Pos('&',  Out), 1);

  While Pos('(', Out) <> 0 Do Begin
    Paran2 := 1;
    While ((Out[Paran2] <> ')') And (Paran2 <= Length(Out))) Do Begin
      If (Out[Paran2] = '(') Then Paran1 := Paran2;
      Inc (Paran2);
    End;

    S1 := Copy(Out, Paran1 + 1, (Paran2 - Paran1) - 1);

    While Pos('!', S1) <> 0 Do Begin
      A := Pos('!', S1) + 1;
      If S1[A] = '^' Then S1[A] := '%' Else
      If S1[A] = '%' Then S1[A] := '^';
      Delete (S1, A - 1, 1);
    End;

    While Pos('|', S1) <> 0 Do Begin
      A   := Pos('|', S1) - 1;
      Ch1 := S1[A];
      Ch2 := S1[A + 2];

      If (Ch1 in ['%', '^']) and (Ch2 in ['%', '^']) Then Begin
        Delete (S1, A, 3);
        If (Ch1 = '^') or (Ch2 = '^') Then
          Insert ('^', S1, A)
        Else
          Insert ('%', S1, A)
      End Else
        Delete (S1, A + 1, 1);
    End;

    While Pos('%%', S1) <> 0 Do Delete (S1, Pos('%%', S1), 1);
    While Pos('^^', S1) <> 0 Do Delete (S1, Pos('^^', S1), 1);
    While Pos('%^', S1) <> 0 Do Delete (S1, Pos('%^', S1) + 1, 1);
    While Pos('^%', S1) <> 0 Do Delete (S1, Pos('^%', S1), 1);

    Delete (Out, Paran1, (Paran2 - Paran1) + 1);
    Insert (S1, Out, Paran1);
  End;

  Result := Pos('%', Out) = 0;
End;

Function WildcardMatch (Wildcard, FName: String) : Boolean;
Begin
  Result := False;

  If FName = '' Then Exit;

  Case Wildcard[1] of
    '*' : Begin
            If FName[1] = '.' Then Exit;
            If Length(Wildcard) = 1 Then Result := True;
            If (Length(Wildcard) > 1) and (Wildcard[2] = '.') and (Length(FName) > 0) Then
              Result := WildCardMatch(Copy(Wildcard, 3, Length(Wildcard) - 2), Copy(FName, Pos('.', FName) + 1, Length(FName)-Pos('.', FName)));
          End;
    '?' : If Ord(Wildcard[0]) = 1 Then
            Result := True
          Else
            Result := WildCardMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1));
  Else
    If FName[1] = Wildcard[1] Then
      If Length(wildcard) > 1 Then
        Result := WildCardMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1))
      Else
        Result := (Length(FName) = 1) And (Length(Wildcard) = 1);
  End;
End;

Function GetSecurityLevel (Level: Byte; SecLevel: RecSecurity) : Boolean;
Var
  SecLevelFile : File of RecSecurity;
Begin
  Result := False;

  Assign (SecLevelFile, bbsConfig.DataPath + 'security.dat');

  If Not ioReset (SecLevelFile, SizeOf(SecLevel), fmRWDN) Then Exit;

  ioSeek (SecLevelFile, Level - 1);
  ioRead (SecLevelFile, SecLevel);
  Close  (SecLevelFile);

  Result := True;
End;

End.

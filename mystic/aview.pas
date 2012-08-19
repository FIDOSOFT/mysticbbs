Unit AView;

{$I M_OPS.PAS}

Interface

Uses Dos;

Type
  ArcSearchRec = Record
    Name : String[50];
    Size : LongInt;
    Time : LongInt;
    Attr : Byte;
  End;

Type
  PGeneralArchive = ^TGeneralArchive;
  TGeneralArchive = Object
    ArcFile : File;
    Constructor Init;
    Destructor  Done; Virtual;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  End;

Type
  PArchive = ^TArchive;
  TArchive = Object
    Constructor Init;
    Destructor  Done;
    Function    Name      (N: String) : Boolean;
    Procedure   FindFirst (Var SR: ArcSearchRec);
    Procedure   FindNext  (Var SR: ArcSearchRec);
  Private
    _Name    : String;
    _Archive : PGeneralArchive;
  End;

Function GetArchiveType (Name: String) : Char;

Implementation

Uses
  AViewZIP,
  AViewARJ,
  AViewLZH,
  AViewRAR;

Function GetArchiveType (Name: String) : Char;
Var
  ArcFile : File;
  Buf     : Array[1..5] of Char;
  Res     : LongInt;
Begin
  Result := '?';

  If Name = '' Then Exit;

  Assign (ArcFile, Name);
  {$I-} Reset (ArcFile, 1); {$I+}
  If IoResult <> 0 Then Exit;

  BlockRead (ArcFile, Buf, SizeOf(Buf), Res);
  Close (ArcFile);

  If Res = 0 Then Exit;

  If (Buf[1] = 'R') and (Buf[2] = 'a') and (Buf[3] = 'r') Then
    Result := 'R'
  Else
  If (Buf[1] = #$60) And (Buf[2] = #$EA) Then
    Result := 'A'
  Else
  If (Buf[1] = 'P') And (Buf[2] = 'K') Then
    Result := 'Z'
  Else
  If (Buf[3] = '-') and (Buf[4] = 'l') and (Buf[5] in ['h', 'z']) Then
    Result := 'L';
End;

Constructor TGeneralArchive.Init;
Begin
End;

Destructor TGeneralArchive.Done;
Begin
End;

Procedure TGeneralArchive.FindFirst(var sr:ArcSearchRec);
Begin
End;

Procedure TGeneralArchive.FindNext(var sr:ArcSearchRec);
Begin
End;

Constructor TArchive.Init;
Begin
  _Name    := '';
  _Archive := Nil;
End;

Destructor TArchive.Done;
Begin
  If _Archive <> Nil Then Begin
    Close   (_Archive^.ArcFile);
    Dispose (_Archive, Done);
  End;
End;

Function TArchive.Name (N: String): Boolean;
Var
  SR : SearchRec;
Begin
  If _Archive <> Nil Then Begin
    Close   (_Archive^.ArcFile);
    Dispose (_Archive, Done);
    _Archive := Nil;
  End;

  Name  := False;
  _Name := N;

  Dos.FindFirst(_Name, AnyFile, SR);
  FindClose (SR);

  If DosError <> 0 Then Exit;

  Case GetArchiveType(_Name) of
    '?' : Exit;
    'A' : _Archive := New(PArjArchive, Init);
    'Z' : _Archive := New(PZipArchive, Init);
    'L' : _Archive := New(PLzhArchive, Init);
    'R' : _Archive := New(PRarArchive, Init);
  End;

  Assign(_Archive^.ArcFile, N);
  {$I-} Reset(_Archive^.ArcFile, 1); {$I+}
  If IoResult <> 0 Then Begin
    Dispose (_Archive, Done);
    Exit;
  End;

  Name := True;
End;

Procedure TArchive.FindFirst (Var SR : ArcSearchRec);
Begin
  FillChar(SR, SizeOf(SR), 0);
  If _Archive = Nil Then Exit;
  _Archive^.FindFirst(SR);
End;

Procedure TArchive.FindNext(var sr:ArcSearchRec);
Begin
  FillChar(SR, SizeOf(SR), 0);
  If _Archive = Nil Then Exit;
  _Archive^.FindNext(SR);
End;

End.

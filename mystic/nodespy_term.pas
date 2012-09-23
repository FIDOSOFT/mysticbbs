Unit NodeSpy_Term;

{$I M_OPS.PAS}

Interface

Implementation

Uses
  m_Strings,
  m_FileIO,
  m_IniReader,
  NodeSpy_Common;

{$I NODESPY_ANSITERM.PAS}

Type
  PhoneRec = Record
    Name      : String[40];
    Address   : String[60];
    User      : String[30];
    Password  : String[20];
    StatusBar : Boolean;
  End;

Var
  Book : Array[1..200] of PhoneRec;

Procedure InitializeBook;
Var
  Count : Byte;
Begin
  FillChar (Book, SizeOf(Book), 0);

  For Count := 1 to 200 Do
    Book[Count].StatusBar := True;

  Book[1].Name    := 'Mystic BBS Local Login';
  Book[1].Address := 'localhost:' + strI2S(Config.INetTNPort);
End;

Procedure WriteBook;
Var
  OutFile : Text;
  Buffer  : Array[1..4096] of Char;
  Count   : SmallInt;
Begin
  Assign     (OutFile, 'nodespy.phn');
  SetTextBuf (OutFile, Buffer);
  ReWrite    (OutFile);

  For Count := 1 to 200 Do Begin
    WriteLn(OutFile, '[' + strI2S(Count) + ']');
    WriteLn(OutFile, #9 + 'name=' + Book[Count].Name);
    WriteLn(OutFile, #9 + 'address=' + Book[Count].Address);
    WriteLn(OutFile, #9 + 'user=' + Book[Count].User);
    WriteLn(OutFile, #9 + 'pass=' + Book[Count].Password);
    WriteLn(OutFile, #9 + 'statusbar=', Ord(Book[Count].StatusBar));
    WriteLn(OutFile, '');
  End;

  Close (OutFile);
End;

Procedure LoadBook;
Var
  INI   : TIniReader;
  Count : SmallInt;
Begin
  ShowMsgBox (2, 'Loading phonebook');

  INI := TIniReader.Create('nodespy.phn');

  For Count := 1 to 200 Do Begin
    Book[Count].Name      := INI.ReadString(strI2S(Count), 'name', '');
    Book[Count].Address   := INI.ReadString(strI2S(Count), 'address', '');
    Book[Count].User      := INI.ReadString(strI2S(Count), 'user', '');
    Book[Count].Password  := INI.ReadString(strI2S(Count), 'pass', '');
    Book[Count].StatusBar := INI.ReadString(strI2S(Count), 'statusbar', '1') = '1';
  End;

  INI.Free;
End;

Procedure Terminal;
Begin
  If Not FileExist('nodespy.phn') Then Begin
    ShowMsgBox(2, 'Creating phone book');

    InitializeBook;
    WriteBook;
  End Else
    LoadBook;

  DrawTerminalAnsi;
End;

End.
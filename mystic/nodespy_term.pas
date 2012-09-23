Unit NodeSpy_Term;

{$I M_OPS.PAS}

Interface

Procedure Terminal;

Implementation

Uses
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_IniReader,
  m_io_Base,
  m_io_Sockets,
  m_Term_Ansi,
  m_MenuBox,
  m_MenuForm,
  NodeSpy_Common;

{$I NODESPY_ANSITERM.PAS}

Type
  PhoneRec = Record
    Name      : String[26];
    Address   : String[60];
    User      : String[30];
    Password  : String[20];
    StatusBar : Boolean;
    LastCall  : String[8];
    Calls     : String[5];
  End;

  PhoneBookRec = Array[1..100] of PhoneRec;

Var
  IsBookLoaded : Boolean;

Function StripAddressPort (Str : String) : String;
Var
  A : Byte;
Begin
  A := Pos(':', Str);

  If A > 0 Then
    StripAddressPort := Copy(Str, 1, A - 1)
  Else
    StripAddressPort := Str;
End;

Function GetAddressPort (Addr : String) : Word;
Var
  A : Byte;
Begin
  A := Pos(':', Addr);

  If A > 0 Then
    GetAddressPort := strS2I(Copy(Addr, A+1, Length(Addr)))
  Else
    GetAddressPort := 23;
End;

Procedure InitializeBook (Var Book: PhoneBookRec);
Var
  Count : SmallInt;
Begin
  FillChar (Book, SizeOf(Book), 0);

  For Count := 1 to 100 Do Begin
    Book[Count].StatusBar := True;
    Book[Count].LastCall  := '00/00/00';
    Book[Count].Calls     := '0';
  End;

  Book[1].Name    := 'Local Login';
  Book[1].Address := 'localhost:' + strI2S(Config.INetTNPort);
End;

Procedure WriteBook (Var Book: PhoneBookRec);
Var
  OutFile : Text;
  Buffer  : Array[1..4096] of Char;
  Count   : SmallInt;
Begin
  ShowMsgBox (2, 'Saving phonebook');

  Assign     (OutFile, 'nodespy.phn');
  SetTextBuf (OutFile, Buffer);
  ReWrite    (OutFile);

  For Count := 1 to 100 Do Begin
    WriteLn (OutFile, '[' + strI2S(Count) + ']');
    WriteLn (OutFile, #9 + 'name=' + Book[Count].Name);
    WriteLn (OutFile, #9 + 'address=' + Book[Count].Address);
    WriteLn (OutFile, #9 + 'user=' + Book[Count].User);
    WriteLn (OutFile, #9 + 'pass=' + Book[Count].Password);
    WriteLn (OutFile, #9 + 'statusbar=', Ord(Book[Count].StatusBar));
    WriteLn (OutFile, #9 + 'last=' + Book[Count].LastCall);
    WriteLn (OutFile, #9 + 'calls=' + Book[Count].Calls);
    WriteLn (OutFile, '');
  End;

  Close (OutFile);
End;

Procedure LoadBook (Var Book: PhoneBookRec);
Var
  INI   : TIniReader;
  Count : SmallInt;
Begin
  ShowMsgBox (2, 'Loading phonebook');

  INI := TIniReader.Create('nodespy.phn');

  INI.Sequential := True;

  For Count := 1 to 100 Do Begin
    Book[Count].Name      := INI.ReadString(strI2S(Count), 'name', '');
    Book[Count].Address   := INI.ReadString(strI2S(Count), 'address', '');
    Book[Count].User      := INI.ReadString(strI2S(Count), 'user', '');
    Book[Count].Password  := INI.ReadString(strI2S(Count), 'pass', '');
    Book[Count].StatusBar := INI.ReadString(strI2S(Count), 'statusbar', '1') = '1';
    Book[Count].LastCall  := INI.ReadString(strI2S(Count), 'last', '');
    Book[Count].Calls     := INI.ReadString(strI2S(Count), 'calls', '');
  End;

  INI.Free;
End;

Procedure TelnetClient (Dial: PhoneRec);
Const
  BufferSize = 1024 * 4;
Var
  Client : TIOSocket;
  Res    : LongInt;
  Buffer : Array[1..BufferSize] of Char;
  Done   : Boolean;
  Ch     : Char;
Begin
  ShowMsgBox (2, 'Connecting to ' + Dial.Address);

  Client := TIOSocket.Create;

  Client.FTelnetClient := True;

  If Not Client.Connect(StripAddressPort(Dial.Address), GetAddressPort(Dial.Address)) Then
    ShowMsgBox (0, 'Unable to connect')
  Else Begin
    Screen.TextAttr := 7;
    Screen.ClearScreen;

    Done := False;
    Term := TTermAnsi.Create(Screen);

    If Dial.StatusBar Then Begin
      Screen.SetWindow (1, 1, 80, 24, True);
      Screen.WriteXY   (1, 25, Config.StatusColor3, strPadC('ALT-X/Quit', 80, ' '));
    End;

    Term.SetReplyClient(TIOBase(Client));

    Repeat
      If Client.DataWaiting Then Begin
        Res := Client.ReadBuf (Buffer, BufferSize);

        If Res < 0 Then Begin
          Done := True;
          Break;
        End;

        Term.ProcessBuf(Buffer, Res);
      End Else
      If Keyboard.KeyPressed Then Begin
        Ch := Keyboard.ReadKey;

        Case Ch of
          #00 : Case Keyboard.ReadKey of
                  #45 : Break;
                  #71 : Client.WriteStr(#27 + '[H');
                  #72 : Client.WriteStr(#27 + '[A');
                  #73 : Client.WriteStr(#27 + '[V');
                  #75 : Client.WriteStr(#27 + '[D');
                  #77 : Client.WriteStr(#27 + '[C');
                  #79 : Client.WriteStr(#27 + '[K');
                  #80 : Client.WriteStr(#27 + '[B');
                  #81 : Client.WriteStr(#27 + '[U');
                  #83 : Client.WriteStr(#127);
                End;
        Else
          Client.WriteBuf(Ch, 1);

          If Client.FTelnetEcho Then Term.Process(Ch);
        End;
      End Else
        WaitMS(10);
    Until Done;

    Term.Free;
  End;

  Client.Free;

  Screen.TextAttr := 7;
  Screen.SetWindow (1, 1, 80, 25, True);
End;

Procedure EditEntry (Var Book: PhoneBookRec; Num: SmallInt);
Var
  Box    : TMenuBox;
  Form   : TMenuForm;
  NewRec : PhoneRec;
Begin
  NewRec := Book[Num];
  Box    := TMenuBox.Create(Screen);
  Form   := TMenuForm.Create(Screen);

  Box.Header := ' Book Editor ';

  Box.Open (18, 8, 63, 16);

  Form.AddStr ('N', ' Name'   , 24, 10, 32, 10, 6, 26, 26, @NewRec.Name, '');
  Form.AddStr ('A', ' Address', 21, 11, 32, 11, 9, 30, 60, @NewRec.Address, '');

  Form.Execute;

  If Form.Changed Then
    If ShowMsgBox(1, 'Save changes?') Then Begin
      Book[Num] := NewRec;
      WriteBook(Book);
    End;

  Form.Free;

  Box.Close;
  Box.Free;
End;

Function GetTerminalEntry (Var Book: PhoneBookRec; Var Dial: PhoneRec) : Boolean;
Var
  Count : SmallInt;
  List  : TMenuList;
Begin
  Result := False;

  If Not FileExist('nodespy.phn') Then Begin
    ShowMsgBox (2, 'Creating phone book');
    WriteBook  (Book);

    IsBookLoaded := True;
  End Else
    If Not IsBookLoaded Then Begin
      LoadBook(Book);
      IsBookLoaded := True;
    End;

  DrawTerminalAnsi;

  Repeat
    List := TMenuList.Create(Screen);

    List.NoWindow := True;
    List.AllowTag := False;
    List.LoAttr   := 7;
    List.HiAttr   := 9 + 1 * 16;
    List.LoChars  := #13#27;
    List.HiChars  := #18;

    For Count := 1 to 100 Do
      List.Add(strPadR(Book[Count].Name, 26, ' ') + '   ' +
               strPadR(Book[Count].Address, 26, ' ') + '   ' +
               Book[Count].LastCall + '   ' +
               strPadL(Book[Count].Calls, 6, ' '),
               2);

    List.Open(1, 12, 80, 22);

    Case List.ExitCode of
      #13 : If Book[List.Picked].Address = '' Then
              ShowMsgBox(0, 'Address is empty')
            Else Begin
              With Book[List.Picked] Do Begin
                LastCall := DateDos2Str(CurDateDos, 1);
                Calls    := strI2S(strS2I(Calls) + 1);
              End;

              WriteBook(Book);

              Dial   := Book[List.Picked];
              Result := True;

              Break;
            End;
      #18 : EditEntry(Book, List.Picked);
      #27 : Break;
    End;

    List.Free;
  Until False;
End;

Procedure Terminal;
Var
  Dial : PhoneRec;
  Book : PhoneBookRec;
Begin
  Screen.SetWindowTitle('NodeSpy/Terminal');

  InitializeBook(Book);

  IsBookLoaded := False;

  Repeat
    If Not GetTerminalEntry(Book, Dial) Then Break;

    TelnetClient(Dial);
  Until False;
End;

End.

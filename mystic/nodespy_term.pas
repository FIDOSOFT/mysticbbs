Unit NodeSpy_Term;

{$I M_OPS.PAS}

Interface

Procedure Terminal;

Implementation

Uses
  DOS,
  m_Types,
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_IniReader,
  m_QuickSort,
  m_io_Base,
  m_io_Sockets,
  m_Protocol_Base,
  m_Protocol_Queue,
  m_Protocol_Zmodem,
  m_Input,
  m_Output,
  m_Term_Ansi,
  m_MenuBox,
  m_MenuForm,
  m_MenuInput,
  NodeSpy_Common;

{$I NODESPY_ANSITERM.PAS}

Type
  PhoneRec = Record
    Position  : LongInt;
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

Function GetTransferType : Byte;
Var
  List : TMenuList;
Begin
  List := TMenuList.Create(TOutput(Screen));

  List.Box.Header    := ' Transfer Type ';
  List.Box.HeadAttr  := 1 + 7 * 16;
  List.Box.FrameType := 6;
  List.Box.Box3D     := True;
  List.PosBar        := False;

  List.Add('Zmodem: Download', 0);
  List.Add('Zmodem: Upload', 0);

  List.Open (30, 11, 49, 14);
  List.Box.Close;

  Case List.ExitCode of
    #27 : GetTransferType := 0;
  Else
    GetTransferType := List.Picked;
  End;

  List.Free;
End;

Function GetNewRecord : PhoneRec;
Begin
  FillChar (Result, SizeOf(PhoneRec), 0);

  Result.StatusBar := True;
  Result.LastCall  := '00/00/00';
  Result.Calls     := '0';
End;

Procedure InitializeBook (Var Book: PhoneBookRec);
Var
  Count : SmallInt;
Begin
  For Count := 1 to 100 Do
    Book[Count] := GetNewRecord;

  Book[1].Name    := 'Local Login';
  Book[1].Address := 'localhost:' + strI2S(Config.INetTNPort);
End;

Procedure WriteBook (Var Book: PhoneBookRec);
Var
  OutFile : Text;
  Buffer  : Array[1..4096] of Char;
  Count   : SmallInt;
Begin
  //ShowMsgBox (2, 'Saving phonebook');

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
    Book[Count].Position  := Count;
  End;

  INI.Free;
End;

Procedure ActivateScrollback;
Var
  TopPage : Integer;
  BotPage : Integer;
  WinSize : Byte;
  Image   : TConsoleImageRec;

  Procedure DrawPage;
  Var
    Count : Integer;
    YPos  : Integer;
  Begin
    YPos := 1;

    For Count := TopPage to BotPage Do Begin
      Screen.WriteLineRec (YPos, Screen.ScrollBuf[Count + 1]);
      Inc (YPos);
    End;
  End;

Var
  Per      : Byte;
  LastPer  : Byte;
  BarPos   : Byte;
  Offset   : Byte;
  StatusOn : Boolean;

  Procedure DrawStatus;
  Begin
    LastPer  := 0;
    StatusOn := True;

    Screen.WriteXY (1, 23 + Offset, 15, strRep('Ü', 80));
    Screen.WriteXY (1, 25 + Offset,  8, strRep('ß', 80));
    Screen.WriteXYPipe (1, 24 + Offset, 112, 80, ' Scrollback         |01ESC|00/|01Quit        |01Space|00/|01Status                    |00(    /|01' + strPadR(strI2S(Screen.ScrollPos-1), 4, ' ') + '|00) ');
  End;

Begin
  If Screen.ScrollPos <= 0 Then Begin
    ShowMsgBox(0, 'No scrollback data');
    Exit;
  End;

  Case Screen.ScreenSize of
    25 : Begin
           Offset  := 0;
           WinSize := 21;
         End;
    50 : Begin
           Offset  := 25;
           WinSize := 46;
         End;
  End;

  Screen.GetScreenImage(1, 1, 80, Screen.ScreenSize, Image);
  Screen.ClearScreen;

  TopPage := Screen.ScrollPos - WinSize - 1;
  BotPage := Screen.ScrollPos - 1;

  If TopPage < 0 Then TopPage := 0;

  DrawStatus;
  DrawPage;

  Repeat
    If StatusOn Then Begin
      Screen.WriteXY (70, 24 + Offset, 113, strPadL(strI2S(BotPage), 4, ' '));

      Per := Round(BotPage / Screen.ScrollPos * 100 / 10);

      If Per = 0 Then Per := 1;

      If LastPer <> Per Then Begin
        BarPos := 0;

        Screen.WriteXY (58, 24 + Offset, 8, '°°°°°°°°°°');

        Repeat
          Inc (BarPos);

          Case BarPos of
            1 : Screen.WriteXY (58, 24 + Offset,  1, '°');
            2 : Screen.WriteXY (59, 24 + Offset,  1, '±');
            3 : Screen.WriteXY (60, 24 + Offset,  1, '²');
            4 : Screen.WriteXY (61, 24 + Offset,  1, 'Û');
            5 : Screen.WriteXY (62, 24 + Offset, 25, '°');
            6 : Screen.WriteXY (63, 24 + Offset, 25, '±');
            7 : Screen.WriteXY (64, 24 + Offset, 25, '²');
            8 : Screen.WriteXY (65, 24 + Offset,  9, 'Û');
            9 : Screen.WriteXY (66, 24 + Offset, 27, '±');
            10: Screen.WriteXY (67, 24 + Offset, 27, '²');
          End;
        Until BarPos = Per;

        LastPer := Per;
      End;
    End;

    Case Keyboard.ReadKey of
      #00 : Case Keyboard.ReadKey of
              keyHOME : If TopPage > 0 Then Begin
                          TopPage := 0;
                          BotPage := WinSize;
                          DrawPage;
                        End;
              keyEND  : If BotPage <> Screen.ScrollPos - 1 Then Begin
                          TopPage := Screen.ScrollPos - 1 - WinSize;
                          BotPage := Screen.ScrollPos - 1;
                          DrawPage;
                        End;
              keyUP   : If TopPage > 0 Then Begin
                          Dec (TopPage);
                          Dec (BotPage);
                          DrawPage;
                        End;
              keyDOWN : If BotPage < Screen.ScrollPos - 1 Then Begin
                          Inc (TopPage);
                          Inc (BotPage);
                          DrawPage;
                        End;
              keyPGUP : If TopPage - WinSize > 0 Then Begin
                          Dec (TopPage, WinSize);
                          Dec (BotPage, WinSize);
                          DrawPage;
                        End Else Begin
                          TopPage := 0;
                          BotPage := WinSize;
                          DrawPage;
                        End;
              keyPGDN : If BotPage + WinSize < Screen.ScrollPos - 1 Then Begin
                          Inc (TopPage, WinSize + 1);
                          Inc (BotPage, WinSize + 1);
                          DrawPage;
                        End Else Begin
                          TopPage := Screen.ScrollPos - WinSize - 1;
                          BotPage := Screen.ScrollPos - 1;
                          DrawPage;
                        End;
            End;
      #27 : Break;
      #32 : Begin
              If StatusOn Then Begin
                Case Screen.ScreenSize of
                  25 : WinSize := 24;
                  50 : WinSize := 49;
                End;
                StatusOn := False;

                Inc (BotPage, 3);

                If BotPage > Screen.ScrollPos - 1 Then Begin
                  TopPage := Screen.ScrollPos - WinSize - 1;
                  BotPage := Screen.ScrollPos - 1;
                  If TopPage < 0 Then TopPage := 0;
                End;

                DrawPage;
              End Else Begin
                StatusOn := True;

                Case Screen.ScreenSize of
                  25 : WinSize := 21;
                  50 : WinSize := 46;
                End;

                Dec (BotPage, 3);
                DrawStatus;
                DrawPage;
              End;
            End;
    End;
  Until False;

  Screen.PutScreenImage(Image);
End;

Function ProtocolAbort : Boolean;
Begin
  Result := Keyboard.KeyPressed and (KeyBoard.ReadKey = #27);
End;

Procedure ProtocolStatusUpdate (Starting, Ending, Status: RecProtocolStatus);
Var
  KBRate  : LongInt;
Begin
  Screen.WriteXY (19, 10, 113, strPadR(Status.FileName, 56, ' '));
  Screen.WriteXY (19, 11, 113, strPadR(strComma(Status.FileSize), 15, ' '));
  Screen.WriteXY (19, 12, 113, strPadR(strComma(Status.Position), 15, ' '));
  Screen.WriteXY (64, 11, 113, strPadR(strI2S(Status.Errors), 3, ' '));

  KBRate := 0;

  If (TimerSeconds - Status.StartTime > 0) and (Status.Position > 0) Then
    KBRate := Round((Status.Position / (TimerSeconds - Status.StartTime)) / 1024);

  Screen.WriteXY (64, 12, 113, strPadR(strI2S(KBRate) + ' k/sec', 12, ' '));
End;

Procedure ProtocolStatusDraw;
Var
  Box : TMenuBox;
Begin
  Box := TMenuBox.Create(TOutput(Screen));

  Box.Open (6, 8, 76, 14);

  Box.Header := ' Zmodem File Transfer ';

  (*
  Screen.WriteXY (6,  8, 120, '+' + strRep('-', 69) + '+');
  Screen.WriteXY (6,  9, 120, '+' + strRep(' ', 69) + '+');
  Screen.WriteXY (6, 10, 120, '+' + strRep(' ', 69) + '+');
  Screen.WriteXY (6, 11, 120, '+' + strRep(' ', 69) + '+');
  Screen.WriteXY (6, 12, 120, '+' + strRep(' ', 69) + '+');
  Screen.WriteXY (6, 13, 120, '+' + strRep(' ', 69) + '+');
  Screen.WriteXY (6, 14, 120, '+' + strRep('-', 69) + '+');
  *)

  Screen.WriteXY ( 8, 10, 112, 'File Name:');
  Screen.WriteXY (13, 11, 112, 'Size:');
  Screen.WriteXY ( 9, 12, 112, 'Position:');
  Screen.WriteXY (56, 11, 112, 'Errors:');
  Screen.WriteXY (58, 12, 112, 'Rate:');

  Box.Free;
End;

Function GetUploadFileName : String;
Const
  ColorBox = 31;
  ColorBar = 7 + 0 * 16;
Var
  DirList  : TMenuList;
  FileList : TMenuList;
  InStr    : TMenuInput;
  Str      : String;
  Path     : String;
  Mask     : String;
  OrigDIR  : String;

  Procedure UpdateInfo;
  Begin
    Screen.WriteXY (8,  7, 31, strPadR(Path, 40, ' '));
    Screen.WriteXY (8, 21, 31, strPadR(Mask, 40, ' '));
  End;

  Procedure CreateLists;
  Var
    Dir      : SearchRec;
    DirSort  : TQuickSort;
    FileSort : TQuickSort;
    Count    : LongInt;
  Begin
    DirList.Clear;
    FileList.Clear;

    While Path[Length(Path)] = PathSep Do Dec(Path[0]);

    ChDir(Path);

    Path := Path + PathSep;

    If IoResult <> 0 Then Exit;

    DirList.Picked  := 1;
    FileList.Picked := 1;

    UpdateInfo;

    DirSort  := TQuickSort.Create;
    FileSort := TQuickSort.Create;

    FindFirst (Path + '*', AnyFile - VolumeID, Dir);

    While DosError = 0 Do Begin
      If (Dir.Attr And Directory = 0) or ((Dir.Attr And Directory <> 0) And (Dir.Name = '.')) Then Begin
        FindNext(Dir);
        Continue;
      End;

      DirSort.Add (Dir.Name, 0);
      FindNext    (Dir);
    End;

    FindClose(Dir);

    FindFirst (Path + Mask, AnyFile - VolumeID, Dir);

    While DosError = 0 Do Begin
      If Dir.Attr And Directory <> 0 Then Begin
        FindNext(Dir);

        Continue;
      End;

      FileSort.Add(Dir.Name, 0);
      FindNext(Dir);
    End;

    FindClose(Dir);

    DirSort.Sort  (1, DirSort.Total,  qAscending);
    FileSort.Sort (1, FileSort.Total, qAscending);

    For Count := 1 to DirSort.Total Do
      DirList.Add(DirSort.Data[Count]^.Name, 0);

    For Count := 1 to FileSort.Total Do
      FileList.Add(FileSort.Data[Count]^.Name, 0);

    DirSort.Free;
    FileSort.Free;

    Screen.WriteXY (14, 9, 113, strPadR('(' + strComma(FileList.ListMax) + ')', 7, ' '));
    Screen.WriteXY (53, 9, 113, strPadR('(' + strComma(DirList.ListMax) + ')', 7, ' '));
  End;

Var
  Box  : TMenuBox;
  Done : Boolean;
  Mode : Byte;
Begin
  Result   := '';
  Path     := XferPath;
  Mask     := '*.*';
  Box      := TMenuBox.Create(TOutput(Screen));
  DirList  := TMenuList.Create(TOutput(Screen));
  FileList := TMenuList.Create(TOutput(Screen));

  GetDIR (0, OrigDIR);

  FileList.NoWindow   := True;
  FileList.LoChars    := #9#13#27;
  FileList.HiChars    := #77;
  FileList.HiAttr     := ColorBar;
  FileList.LoAttr     := ColorBox;

  DirList.NoWindow    := True;
  DirList.NoInput     := True;
  DirList.HiAttr      := ColorBox;
  DirList.LoAttr      := ColorBox;

  Box.Header := ' Upload file ';

  Box.Open (6, 5, 74, 22);

  Screen.WriteXY ( 8,  6, 113, 'Directory');
  Screen.WriteXY ( 8,  9, 113, 'Files');
  Screen.WriteXY (41,  9, 113, 'Directories');
  Screen.WriteXY ( 8, 20, 113, 'File Mask');
  Screen.WriteXY ( 8, 21,  31, strRep(' ', 40));

  CreateLists;

  DirList.Open (40, 9, 72, 19);
  DirList.Update;

  Done := False;

  Repeat
    FileList.Open (7, 9, 39, 19);

    Case FileList.ExitCode of
      #09,
      #77 : Begin
              FileList.HiAttr := ColorBox;
              DirList.NoInput := False;
              DirList.LoChars := #09#13#27;
              DirList.HiChars := #75;
              DirList.HiAttr  := ColorBar;

              FileList.Update;

              Repeat
                DirList.Open(40, 9, 72, 19);

                Case DirList.ExitCode of
                  #09 : Begin
                          DirList.HiAttr := ColorBox;
                          DirList.Update;

                          Mode  := 1;
                          InStr := TMenuInput.Create(TOutput(Screen));
                          InStr.LoChars := #09#13#27;

                          Repeat
                            Case Mode of
                              1 : Begin
                                    Str := InStr.GetStr(8, 21, 40, 255, 1, Mask);

                                    Case InStr.ExitCode of
                                      #09 : Mode := 2;
                                      #13 : Begin
                                              Mask := Str;
                                              CreateLists;
                                              FileList.Update;
                                              DirList.Update;
                                            End;
                                      #27 : Begin
                                              Done := True;
                                              Break;
                                            End;
                                    End;
                                  End;
                              2 : Begin
                                    UpdateInfo;

                                    Str := InStr.GetStr(8, 7, 40, 255, 1, Path);

                                    Case InStr.ExitCode of
                                      #09 : Break;
                                      #13 : Begin
                                              ChDir(Str);

                                              If IoResult = 0 Then Begin
                                                Path := Str;
                                                CreateLists;
                                                FileList.Update;
                                                DirList.Update;
                                              End;
                                            End;
                                      #27 : Begin
                                              Done := True;
                                              Break;
                                            End;
                                    End;
                                  End;
                            End;
                          Until False;

                          InStr.Free;

                          UpdateInfo;

                          Break;
                        End;
                  #13 : If DirList.ListMax > 0 Then Begin
                          ChDir  (DirList.List[DirList.Picked]^.Name);
                          GetDir (0, Path);

                          Path := Path + PathSep;

                          CreateLists;
                          FileList.Update;
                        End;
                  #27 : Done := True;
                  #75 : Break;
                End;
              Until Done;

              DirList.NoInput := True;
              DirList.HiAttr  := ColorBox;
              FileList.HiAttr := ColorBar;
              DirList.Update;
            End;
      #13 : If FileList.ListMax > 0 Then Begin
              Result := Path + FileList.List[FileList.Picked]^.Name;
              Break;
            End;
      #27 : Break;
    End;
  Until Done;

  ChDIR(OrigDIR);

  FileList.Free;
  DirList.Free;
  Box.Close;
  Box.Free;
End;

Procedure DoZmodemDownload (Var Client: TIOBase);
Var
  Zmodem : TProtocolZmodem;
  Image  : TConsoleImageRec;
  Queue  : TProtocolQueue;
Begin
  If Not DirExists(XferPath) Then Begin
    ShowMsgBox (0, 'Download directory does not exist');

    Exit;
  End;

  Queue  := TProtocolQueue.Create;
  Zmodem := TProtocolZmodem.Create(Client, Queue);

  Screen.GetScreenImage(1, 1, 80, Screen.ScreenSize, Image);

  ProtocolStatusDraw;

  Zmodem.StatusProc  := @ProtocolStatusUpdate;
  Zmodem.AbortProc   := @ProtocolAbort;
  Zmodem.ReceivePath := XferPath;
  Zmodem.CurBufSize  := 8 * 1024;

  Zmodem.QueueReceive;

  Zmodem.Free;
  Queue.Free;

  Screen.PutScreenImage(Image);
End;

Procedure DoZmodemUpload (Var Client: TIOBase);
Var
  FileName : String;
  Zmodem   : TProtocolZmodem;
  Image    : TConsoleImageRec;
  Queue    : TProtocolQueue;
Begin
  FileName := GetUploadFileName;

  If FileName = '' Then Exit;

  Queue  := TProtocolQueue.Create;
  Zmodem := TProtocolZmodem.Create(Client, Queue);

  Screen.GetScreenImage(1, 1, 80, Screen.ScreenSize, Image);

  ProtocolStatusDraw;

  Zmodem.StatusProc := @ProtocolStatusUpdate;
  Zmodem.AbortProc  := @ProtocolAbort;

  Queue.Add(True, JustPath(FileName), JustFile(FileName), '');

  Zmodem.QueueSend;

  Zmodem.Free;
  Queue.Free;

  Screen.PutScreenImage(Image);
End;

Procedure EditEntry (Var Book: PhoneBookRec; Num: SmallInt);
Var
  Box    : TMenuBox;
  Form   : TMenuForm;
  NewRec : PhoneRec;
Begin
  NewRec := Book[Num];
  Box    := TMenuBox.Create(TOutput(Screen));
  Form   := TMenuForm.Create(TOutput(Screen));

  Box.HeadAttr := 1 + 7 * 16;
  Box.Header   := ' Book Editor ';

  Box.Open (17, 8, 63, 16);

  Form.HelpSize := 0;

  Form.AddStr  ('N', ' Name'   ,   24, 10, 32, 10,  6, 26, 26, @NewRec.Name, '');
  Form.AddStr  ('A', ' Address',   21, 11, 32, 11,  9, 30, 60, @NewRec.Address, '');
  Form.AddStr  ('U', ' User Name', 19, 12, 32, 12, 11, 30, 30, @NewRec.User, '');
  Form.AddPass ('P', ' Password',  20, 13, 32, 13, 10, 20, 20, @NewRec.Password, '');
  Form.AddBol  ('S', ' StatusBar', 19, 14, 32, 14, 11,  3, @NewRec.StatusBar, '');

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

Procedure TelnetClient (Var Book: PhoneBookRec; Dial: PhoneRec);

  Procedure DrawStatus (Toggle: Boolean);
  Begin
    If Dial.StatusBar Then Begin
      Screen.SetWindow (1, 1, 80, 24, False);
      Screen.WriteXY   (1, 25, Config.StatusColor3, strPadC('ALT/B-Scrollback   ALT/L-Send Login   ALT/T-Zmodem    ALT-E/Edit    ALT-X/Quit', 80, ' '));
    End Else
    If Toggle Then Begin
      Screen.SetWindow (1, 1, 80, 25, False);
      Screen.WriteXY   (1, 25, 7, strRep(' ', 79));
    End;
  End;

Const
  BufferSize = 1024 * 4;

Var
  Client : TIOSocket;
  Res    : LongInt;
  Buffer : Array[1..BufferSize] of Char;
  Done   : Boolean;
  Ch     : Char;
  Count  : LongInt;
Begin
  ShowMsgBox (2, 'Connecting to ' + Dial.Address);

  Client := TIOSocket.Create;

  Client.FTelnetClient := True;

  If Not Client.Connect(StripAddressPort(Dial.Address), GetAddressPort(Dial.Address)) Then
    ShowMsgBox (0, 'Unable to connect')
  Else Begin
    Book[Dial.Position].LastCall := DateDos2Str(CurDateDos, 1);
    Book[Dial.Position].Calls    := strI2S(strS2I(Dial.Calls) + 1);

    WriteBook(Book);

    Dial := Book[Dial.Position];

    Screen.TextAttr := 7;
    Screen.ClearScreen;

    Done := False;
    Term := TTermAnsi.Create(TOutput(Screen));

    DrawStatus(False);

    Term.SetReplyClient(TIOBase(Client));

    Repeat
      If Client.DataWaiting Then Begin
        Res := Client.ReadBuf (Buffer, BufferSize);

        If Res < 0 Then Begin
          Done := True;

          Break;
        End;

        Screen.Capture := True;

        If Not AutoZmodem Then
          Term.ProcessBuf(Buffer, Res)
        Else Begin
          For Count := 1 to Res Do
            If (Buffer[Count] = #24) and (Count <= Res - 3) Then Begin
              If (Buffer[Count + 1] <> 'B') or (Buffer[Count + 2] <> '0') Then
                Term.Process(#24)
              Else Begin
                Screen.BufFlush;

                Case Buffer[Count + 3] of
                  '0' : DoZmodemDownload(TIOBase(Client));
                  '1' : DoZmodemUpload(TIOBase(Client));
                End;
              End;
            End Else
              Term.Process(Buffer[Count]);

          Screen.BufFlush;
        End;

        Screen.Capture := False;
      End Else
      If Keyboard.KeyPressed Then Begin
        Ch := Keyboard.ReadKey;

        Case Ch of
          #00 : Case Keyboard.ReadKey of
                  #18 : Begin
                          EditEntry(Book, Dial.Position);

                          If Dial.StatusBar <> Book[Dial.Position].StatusBar Then Begin
                            Dial := Book[Dial.Position];

                            DrawStatus (True);
                          End Else
                            Dial := Book[Dial.Position];
                        End;
                  #20 : Begin
                          Case GetTransferType of
                            1 : DoZmodemDownload(TIOBase(Client));
                            2 : DoZmodemUpload(TIOBase(Client));
                          End;

                          DrawStatus(False);
                        End;
                  #35 : Done := True;
                  #38 : Begin
                          Client.WriteStr (Dial.User + #13);
                          Client.WriteStr (Dial.Password + #13);
                        End;
                  #45 : Break;
                  #48 : Begin
                          ActivateScrollBack;
                          DrawStatus(False);
                        End;
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

  ShowMsgBox (0, 'Connection terminated');

  Screen.TextAttr := 7;
  Screen.SetWindow (1, 1, 80, 25, True);
End;

Procedure SearchEntry (Var Owner: Pointer; Str: String);
Begin
  If Str = '' Then
    Str := strRep(' ', 17)
  Else Begin
    If Length(Str) > 15 Then
      Str := Copy(Str, Length(Str) - 15 + 1, 255);

    Str := '[' + strLower(Str) + ']';

    While Length(Str) < 17 Do
      Str := Str + ' ';
  End;

  Screen.WriteXY (TMenuList(Owner).SearchX,
                  23,
                  8 + 7 * 16,
                  Str);
End;

Function GetTerminalEntry (Var Book: PhoneBookRec; Var Dial: PhoneRec) : Boolean;
Var
  Count  : SmallInt;
  Count2 : SmallInt;
  List   : TMenuList;
  Found  : Boolean;
  Picked : SmallInt;
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

  Picked := 1;

  List := TMenuList.Create(TOutput(Screen));

  List.NoWindow := True;
  List.LoAttr   := 7;
  List.HiAttr   := 9 + 1 * 16;
  List.LoChars  := #13#27;
  List.HiChars  := #18#82#83;
  List.SetSearchProc(SearchEntry);

  Repeat
    List.Clear;

    List.Picked := Picked;

    For Count := 1 to 100 Do
      List.Add(strPadR(Book[Count].Name, 26, ' ') + '   ' +
               strPadR(Book[Count].Address, 26, ' ') + '   ' +
               Book[Count].LastCall + '   ' +
               strPadL(Book[Count].Calls, 6, ' '),
               2);

    List.Open(1, 12, 80, 22);

    Picked := List.Picked;

    Case List.ExitCode of
      #13 : If Book[List.Picked].Address = '' Then
              ShowMsgBox(0, 'Address is empty')
            Else Begin
              Dial   := Book[List.Picked];
              Result := True;

              Break;
            End;
      #18 : EditEntry(Book, List.Picked);
      #27 : Break;
      #82 : Begin
              Found := False;

              For Count := List.Picked to 100 Do
                If (Book[Count].Name = '') and (Book[Count].Address = '') and (Book[Count].Calls = '0') Then Begin
                  Found := True;
                  Break;
                End;

              If Not Found Then
                ShowMsgBox (0, 'No blank entries available')
              Else Begin
                For Count2 := Count DownTo List.Picked + 1 Do
                  Book[Count2] := Book[Count2 - 1];

                Book[List.Picked] := GetNewRecord;

                WriteBook(Book);
              End;
            End;
      #83 : If ShowMsgBox(1, 'Delete this record?') Then Begin
              For Count := List.Picked to 100 - 1 Do
                Book[Count] := Book[Count + 1];

              Book[100] := GetNewRecord;

              WriteBook(Book);
            End;
    End;
  Until False;

  List.Free;
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

    TelnetClient(Book, Dial);
  Until False;
End;

End.

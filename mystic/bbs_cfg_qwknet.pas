Unit BBS_Cfg_QwkNet;

{$I M_OPS.PAS}

Interface

Function Configuration_QwkNetworks (Edit: Boolean) : LongInt;

Implementation

Uses
  m_Strings,
  m_FileIO,
  BBS_Records,
  BBS_Common,
  BBS_DataBase,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Cfg_Common;

Procedure EditNetwork (Var QwkNet: RecQwkNetwork);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09QWK Network|03) |01-|09> |15';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Index ' + strI2S(QwkNet.Index) + ' ';

  Box.Open     (16, 5, 65, 17);
  VerticalLine (32, 7, 15);

  Form.AddStr  ('D', ' Network Name', 18,  7, 34,  7, 14, 30, 30, @QwkNet.Description, Topic + 'Network name');
  Form.AddTog  ('M', ' Member Type',  19,  8, 34,  8, 13, 4, 0, 1, 'HUB Node', @QwkNet.MemberType, Topic + 'Are you a HUB or a Node of this network?');
  Form.AddStr  ('H', ' FTP Host',     22,  9, 34,  9, 10, 30, 60, @QwkNet.HostName, Topic + 'Hostname:Port of HUB (if you are a node)');
  Form.AddStr  ('L', ' Login',        25, 10, 34, 10,  7, 20, 20, @QwkNet.Login, Topic + 'FTP login');
  Form.AddMask ('P', ' Password',     22, 11, 34, 11, 10, 20, 20, @QwkNet.Password, Topic + 'FTP password');
  Form.AddBol  ('U', ' Use Passive',  19, 12, 34, 12, 13, 3, @QwkNet.UsePassive, Topic + 'Use passive FTP with HUB');
  Form.AddStr  ('I', ' Packet ID',    21, 13, 34, 13, 11, 20, 20, @QwkNet.PacketID, Topic + 'QWK packet name to use with HUB');
  Form.AddCaps ('A', ' Archive Type', 18, 14, 34, 14, 14,  4,  4, @QwkNet.ArcType, Topic + 'Archive type used for packets');
  Form.AddBol  ('E', ' Use QWKE',     22, 15, 34, 15, 10, 3, @QwkNet.UseQWKE, Topic + 'Create QWKE packets for HUB');

  Form.Execute;

  Box.Close;

  Form.Free;
  Box.Free;
End;

Function Configuration_QwkNetworks (Edit: Boolean) : LongInt;
Var
  Box     : TAnsiMenuBox;
  List    : TAnsiMenuList;
  QwkFile : File of RecQwkNetwork;
  QwkNet  : RecQwkNetwork;

  Function GetPermanentIndex (Start: LongInt) : LongInt;
  Var
    TempNet  : RecQwkNetwork;
    SavedRec : LongInt;
  Begin
    Result   := Start;
    SavedRec := FilePos(QwkFile);

    If Result = 0 Then Inc(Result);

    Seek (QwkFile, 0);

    While Not Eof(QwkFile) Do Begin
      Read (QwkFile, TempNet);

      If Result = TempNet.Index Then Begin
        If Result >= 2000000 Then Result := 1;

        Inc  (Result);
        Seek (QwkFile, 0);
      End;
    End;

    Seek (QwkFile, SavedRec);
  End;

  Procedure MakeList;
  Const
    NetType : Array[0..1] of String[4] = ('HUB ', 'Node');
  Begin
    List.Clear;

    If Not Edit Then
      List.Add('0    None', 2);

    Seek (QwkFile, 0);

    While Not Eof(QwkFile) Do Begin
      Read (QwkFile, QwkNet);

      List.Add(strPadR(strI2S(FilePos(QwkFile)), 5, ' ') + strPadR(QwkNet.Description, 32, ' ') + NetType[QwkNet.MemberType], 0);
    End;

    List.Add('', 2);
  End;

  Procedure InsertRecord;
  Begin
    AddRecord (QwkFile, List.Picked, SizeOf(RecQwkNetwork));

    FillChar (QwkNet, SizeOf(QwkNet), 0);

    With QwkNet Do Begin
      Description := 'New QWK Network';
      ArcType     := 'ZIP';
      Index       := GetPermanentIndex(FileSize(QwkFile));
    End;

    Write (QwkFile, QwkNet);
  End;

Begin
  Result := 0;

  Assign (QwkFile, bbsCfg.DataPath + 'qwknet.dat');

  If Not ioReset(QwkFile, SizeOf(RecQwkNetwork), fmRWDN) Then
    If Not ioReWrite(QwkFile, SizeOf(RecQwkNetwork), fmRWDN) Then
      Exit;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.SearchY  := 20;

  Box.Header := ' QWK Network ';

  If Not Edit Then Box.Header := ' Select' + Box.Header;

  Box.Open (17, 5, 64, 20);

  WriteXY (19,  6, 112, '###  Description                     Type');
  WriteXY (19,  7, 112, strRep(#196, 44));
  WriteXY (19, 18, 112, strRep(#196, 44));
  WriteXY (28, 19, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (17, 7, 64, 18);
    List.Close;

    Case List.ExitCode of
      '/' : If Edit Then
            Case GetCommandOption(10, 'I-Insert|D-Delete|') of
              'I' : Begin
                      InsertRecord;
                      MakeList;
                    End;
              'D' : If (List.Picked < List.ListMax) Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
//                        Seek (QwkFile, List.Picked - 1);
//                        Read (QwkFile, QwkNet);

                        KillRecord (QwkFile, List.Picked, SizeOf(RecQwkNetwork));

                        // unlink bases and users?

                        MakeList;
                      End;
            End;
      #13 : If List.Picked < List.ListMax Then Begin
              If Not Edit And (List.Picked = 1) Then Begin
                Result := 0;

                Break;
              End Else Begin
                If Edit Then
                  Seek (QwkFile, List.Picked - 1)
                Else
                  Seek (QwkFile, List.Picked - 2);

                Read (QwkFile, QwkNet);

                If Not Edit Then Begin
                  Result := QwkNet.Index;

                  Break;
                End;
              End;

              EditNetwork (QwkNet);

              If Edit Then
                Seek (QwkFile, List.Picked - 1)
              Else
                Seek (QwkFile, List.Picked - 2);

              Write (QwkFile, QwkNet);
            End;
      #27 : Break;
    End;
  Until False;

  Close (QwkFile);

  Box.Close;
  List.Free;
  Box.Free;
End;

End.

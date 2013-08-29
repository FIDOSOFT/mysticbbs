Unit BBS_Cfg_Events;

{$I M_OPS.PAS}

Interface

Procedure Configuration_Events;

Implementation

Uses
  m_Strings,
  m_DateTime,
  m_FileIO,
  BBS_Records,
  BBS_DataBase,
  BBS_Common,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Cfg_Common;

Procedure EditEvent (Var Event: RecEvent);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Hour  : Byte;
  Min   : Byte;
  Count : Byte;
Begin
  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Form.HelpSize := 0;

  Box.Open (11, 6, 69, 20);

  VerticalLine (26, 8, 18);
  VerticalLine (63, 9, 15);

  Hour := Event.ExecTime DIV 60;
  Min  := Event.ExecTime MOD 60;

  Form.AddStr  ('D', ' Description' , 13,  8, 28,  8, 13, 30, 40, @Event.Name, '');
  Form.AddBol  ('A', ' Active'      , 18,  9, 28,  9,  8,  3, @Event.Active, '');
  Form.AddTog  ('Y', ' Exec Type'   , 15, 10, 28, 10, 11, 9, 0, 2, 'BBS Semaphore Shell', @Event.ExecType, '');
  Form.AddByte ('E', ' Exec Hour'   , 15, 11, 28, 11, 11, 2, 0, 23, @Hour, '');
  Form.AddByte ('M', ' Exec Min'    , 16, 12, 28, 12, 10, 2, 0, 59, @Min, '');
  Form.AddStr  ('H', ' Shell'       , 19, 13, 28, 13,  7, 30, 80, @Event.Shell, '');
  Form.AddStr  ('S', ' Semaphore'   , 15, 14, 28, 14, 11, 30, 40, @Event.SemaFile, '');
  Form.AddBol  ('F', ' Forced'      , 18, 15, 28, 15,  8,  3, @Event.Forced, '');
  Form.AddByte ('N', ' Node'        , 20, 16, 28, 16,  6, 3, 0, 250, @Event.Node, '');
  Form.AddByte ('W', ' Warning'     , 17, 17, 28, 17,  9, 3, 0, 255, @Event.Warning, '');
  Form.AddByte ('X', ' Exit Level'  , 14, 18, 28, 18, 12, 3, 0, 255, @Event.ExecLevel, '');

  For Count := 0 to 6 Do
    Form.AddBol ('0', ' ' + DayString[Count], 58, 9 + Count, 65, 9 + Count,  5, 3, @Event.ExecDays[Count], '');

  Form.Execute;

  Event.ExecTime := (Hour * 60) + Min;

  Box.Close;
  Form.Free;
  Box.Free;
End;

Procedure Configuration_Events;
Var
  Box     : TAnsiMenuBox;
  List    : TAnsiMenuList;
  F       : File of RecEvent;
  Event   : RecEvent;
  Copied  : RecEvent;
  HasCopy : Boolean = False;

  Procedure MakeList;
  Var
    Count   : Byte;
    DL      : String[7] = '';
    Hour    : Byte;
    Min     : Byte;
    TypeStr : String;
  Begin
    List.Clear;

    Reset(F);

    While Not Eof(F) Do Begin
      Read (F, Event);

      For Count := 0 to 6 Do
        If Event.ExecDays[Count] Then
          DL := DL + DayString[Count][1]
        Else
          DL := DL + '-';

      Hour := Event.ExecTime DIV 60;
      Min  := Event.ExecTime MOD 60;

      Case Event.ExecType of
        0 : TypeStr := 'BBS';
        1 : TypeStr := 'Semaphore';
        2 : TypeStr := 'Shell';
//        3 : TypeStr := 'PollMail';
//        4 : TypeStr := 'SendMail';
      End;

      List.Add (strPadR(strYN(Event.Active), 7, ' ') + ' ' + strPadR(TypeStr, 15, ' ') + '  ' + strPadR(Event.Name, 25, ' ') + '  ' + strZero(Hour) + ':' + strZero(Min) + '  ' + DL, 0);
    End;

    List.Add ('', 2);
  End;

Begin
  Assign (F, bbsCfg.DataPath + 'event.dat');

  If Not ioReset(F, SizeOf(Event), fmRWDN) Then
    ioReWrite (F, SizeOf(Event), fmRWDN);

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Event Editor ';
  List.NoWindow := True;
  List.LoChars  := #13#27#47;
  List.SearchY  := 20;

  Box.Open (6, 5, 75, 20);

  WriteXY (8,  7, 112, 'Active  Type             Description                Time   Days');
  WriteXY (8,  8, 112, strRep('Ä', 66));
  WriteXY (8, 18, 112, strRep('Ä', 66));
  WriteXY (29, 19, 112, cfgCommandList);

  Repeat
    MakeList;

    List.Open (6, 8, 75, 18);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(10, 'I-Insert|D-Delete|C-Copy|P-Paste|') of
              'I' : Begin
                      AddRecord (F, List.Picked, SizeOf(Event));

                      FillChar (Event, SizeOf(Event), 0);

                      Event.Name := 'New Event';

                      Write (F, Event);

                      MakeList;
                    End;
              'D' : If List.Picked < List.ListMax Then
                      If ShowMsgBox(1, 'Delete this entry?') Then Begin
                        KillRecord (F, List.Picked, SizeOf(Event));
                        MakeList;
                      End;
              'C' : If List.Picked <> List.ListMax Then Begin
                      Seek (F, List.Picked - 1);
                      Read (F, Copied);

                      HasCopy := True;
                    End;
              'P' : If HasCopy Then Begin
                      AddRecord (F, List.Picked, SizeOf(Event));
                      Write     (F, Copied);

                      MakeList;
                    End;

            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              Seek (F, List.Picked - 1);
              Read (F, Event);

              EditEvent(Event);

              Seek  (F, List.Picked - 1);
              Write (F, Event);
            End;
      #27 : Break;
    End;
  Until False;

  Close(F);

  Box.Close;
  List.Free;
  Box.Free;
End;

End.

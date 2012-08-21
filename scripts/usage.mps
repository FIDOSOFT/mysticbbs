// ==========================================================================
// USAGE.MPS : On the fly usage graph calculation for Mystic BBS v1.10+
//    Author : g00r00
//   Version : 1.0
//   License : Part of with Mystic BBS distribution / GPL repository
// --------------------------------------------------------------------------
//
// This MPL calculates a monthly usage graph based on the BBS history data
// file.  Simply copy it to the scripts directory, compile it and execute it
// from your menu with the GX menu command (optional data 'usage').
//
// I may continue to add different types of graphs in the future.  The latest
// version can be found on Mystic BBS sourceforge page.
//
// ==========================================================================

Uses CFG

Const
  fmRWDN = 66;

Type
  RecHistory = Record                        // From records.pas 1.10
    Date       : LongInt;
    Emails     : Word;
    Posts      : Word;
    Downloads  : Word;
    Uploads    : Word;
    DownloadKB : LongInt;
    UploadKB   : LongInt;
    Calls      : LongInt;
    NewUsers   : Word;
    Telnet     : Word;
    FTP        : Word;
    POP3       : Word;
    SMTP       : Word;
    NNTP       : Word;
    HTTP       : Word;
    Hourly     : Array[0..23] of Byte;
    Reserved   : Array[1..2] of Byte;
  End;

Var
  Days  : LongInt;
  Calls : LongInt;
  Month : Array[1..12] of Cardinal;
  Week  : Array[0..6] of Cardinal;
  Hour  : Array[0..23] of Cardinal;

Procedure DrawBar (XPos, Value: Byte);
Var
  Temp : Byte;
Begin
  For Temp := 1 to Value Do
    WriteXY (XPos, 18 - Temp, 1, #219 + #219 + #219);
End;

Procedure DisplayMonthly;
Var
  Count  : Byte;
  Count2 : Byte;
Begin
  WriteLn ('|CL|09|17 ' + #176 + ' |15Monthly Usage Graph ' + PadLT(strComma(Days) + '|07 days, |15' + strComma(Calls) + ' |07calls ', 63, ' ') + '|09' + #176 + ' |16');

  GotoXY  (6, 18);

  For Count := 1 to 12 Do
    Write ('|08' + #196 + #196 + #196 + '   ');

  WriteXY (6, 19, 14, 'Jan   Feb   Mar   Apr   May   Jun   Jul   Aug   Sep   Oct   Nov   Dec');
  WriteXY (2, 21, 08, strRep(#196, 78));

  For Count := 1 to 12 Do
    For Count2 := 15 DownTo 1 Do Begin
      GotoXY (Count * 6, 2 + Count2);
      Write  (#250 + #250 + #250);
    End;

  For Count := 1 to 12 Do
    DrawBar (6 * Count, Month[Count]);
End;

Procedure DisplayWeekly;
Var
  Count  : Byte;
  Count2 : Byte;
Begin
  WriteLn ('|CL|09|17 ' + #176 + ' |15Weekly Usage Graph ' + PadLT(strComma(Days) + '|07 days, |15' + strComma(Calls) + ' |07calls ', 64, ' ') + '|09' + #176 + ' |16');

  For Count := 0 to 6 Do Begin
    GotoXY (10 * (Count + 1), 18);
    Write ('|08' + #196 + #196 + #196);
  End;

  WriteXY (10, 19, 14, 'Sun       Mon       Tue       Wed       Thu       Fri       Sat');
  WriteXY ( 2, 21, 08, strRep(#196, 78));

  For Count := 0 to 6 Do
    For Count2 := 15 DownTo 1 Do Begin
      GotoXY (10 * (Count + 1), 2 + Count2);
      Write  (#250 + #250 + #250);
    End;

  For Count := 0 to 6 Do
    DrawBar (10 * (Count + 1), Week[Count]);
End;

Procedure CalculateHistory;
Var
  HistFile : File;
  OneDay   : RecHistory;
  TempLong : Cardinal;
  TempReal : Real;
  Count    : LongInt;
  Highest  : Cardinal;
Begin
  fAssign (HistFile, CfgDataPath + 'history.dat', fmRWDN);
  fReset  (HistFile);

  If IoResult <> 0 Then Exit;

  If fSize(HistFile) = 0 Then Begin
    WriteLn ('|CRNo BBS history to calculate|CR|CR|PA');
    Halt;
  End;

  Days := fSize(HistFile) / SizeOf(OneDay);

  WriteLn ('|16|CL|15Calculating usage for last ' + strComma(Days) + ' days...');

  While Not fEof(HistFile) Do Begin
    fReadRec(HistFile, OneDay);

    Calls           := Calls + OneDay.Calls;
    TempLong        := Str2Int(Copy(DateStr(OneDay.Date, 1), 1, 2));
    Month[TempLong] := Month[TempLong] + OneDay.Calls;
    TempLong        := DayOfWeek(OneDay.Date);
    Week[TempLong]  := Week[TempLong] + OneDay.Calls;

    For Count := 0 to 23 Do
      Hour[Count] := Hour[Count] + OneDay.Hourly[Count];
  End;

  Highest := 0;

  For Count := 1 to 12 Do
    If Month[Count] > Highest Then
      Highest := Month[Count];

  For Count := 1 to 12 Do
    If Month[Count] > 0 Then Begin
      TempReal     := (Month[Count] / Highest * 100);
      Month[Count] := TempReal / 7 + 1;
    End;

  Highest := 0;

  For Count := 0 to 6 Do
    If Week[Count] > Highest Then
      Highest := Week[Count];

  For Count := 0 to 6 Do
    If Week[Count] > 0 Then Begin
      TempReal    := (Week[Count] / Highest * 100);
      Week[Count] := TempReal / 7 + 1;
    End;

  Highest := 0;

  For Count := 0 to 23 Do
    If Hour[Count] > Highest Then
      Highest := Hour[Count];

  For Count := 0 to 23 Do
    If Hour[Count] > 0 Then Begin
      TempReal    := (Hour[Count] / Highest * 100);
      Hour[Count] := TempReal / 7 + 1;
    End;

  fClose (HistFile);
End;

Var
  ShowMode : Byte;
Begin
  If Graphics = 0 Then Begin
    WriteLn ('|CRSorry, usage graphs require ANSI graphics|CR|CR|PA');
    Exit;
  End;

  CalculateHistory;

  If ParamCount > 0 Then Begin
    Case Upper(ParamStr(1)) of
      'MONTHLY' : DisplayMonthly;
      'WEEKLY'  : DisplayWeekly;
//      'HOURLY'  : DisplayHourly;
    Else
      WriteLn ('USAGE.MPS: Invalid command line option.|PN');
    End;
  End Else Begin
    ShowMode := 1;

    Repeat
      Case ShowMode of
        1 : DisplayMonthly;
        2 : DisplayWeekly;
//        3 : DisplayHourly;
      End;

      WriteXYPipe (22, 23, 7, 0, 'Press |08[|15TAB|08] |07for more or |08[|15ENTER|08] |07to Quit');

      Case OneKey(#09 + #13, False) of
        #09 : If ShowMode < 2 Then ShowMode := ShowMode + 1 Else ShowMode := 1;
        #13 : Break;
      End;
    Until False;
  End;
End

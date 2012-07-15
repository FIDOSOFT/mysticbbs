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
  RecHistory = Record                        // from records.pas 1.10
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
    Reserved   : Array[1..26] of Byte;
  End;

Function DisplayMonthly : Boolean;
Var
  HistFile   : File;
  Days       : Cardinal;
  OneDay     : RecHistory;
  Months     : Array[1..12] of Cardinal;
  CurMonth   : Byte;
  TotalCalls : Cardinal;
  Loop1      : Byte;
  Loop2      : Byte;

  Procedure DrawBar (XPos, Value: Byte);
  Var
    Temp : Byte;
  Begin
    Write ('|01');

    For Temp := 1 to Value Do Begin
      GotoXY (XPos, 18 - Temp);
      Write  (#219 + #219 + #219);
    End;
  End;

Begin
  DisplayMonthly := False;
  
  fAssign (HistFile, CfgDataPath + 'history.dat', fmRWDN);
  fReset  (HistFile);

  If IoResult <> 0 Then Exit;

  If fSize(HistFile) = 0 Then Begin
    WriteLn ('|CRNo BBS history to calculate|CR|CR|PA');
    Halt;
  End;

  Days := fSize(HistFile) / SizeOf(OneDay);

  WriteLn ('|16|CL|15Calculating Monthly usage (' + strComma(Days) + ' days)...');

  While Not fEof(HistFile) Do Begin
    fReadRec(HistFile, OneDay);

    CurMonth         := Str2Int(Copy(DateStr(OneDay.Date, 1), 1, 2));
    Months[CurMonth] := Months[CurMonth] + OneDay.Calls;
    TotalCalls       := TotalCalls       + OneDay.Calls;
  End;

  fClose (HistFile);

  For Loop1 := 1 to 12 Do Begin
    If Months[Loop1] > 0 Then
      Months[Loop1] := Months[Loop1] / TotalCalls * 15
    Else
      Months[Loop1] := 1;
  End;

  WriteLn ('|CL|09|17 ' + #176 + ' |15Monthly Usage Graph ' + PadLT(strComma(Days) + '|07 days, |15' + strComma(TotalCalls) + ' |07calls ', 63, ' ') + '|09' + #176 + ' |16');

  GotoXY  (6, 18);

  For Loop1 := 1 to 12 Do
    Write ('|08' + #196 + #196 + #196 + '   ');

  GotoXY (6, 19);
  Write  ('|14Jan   Feb   Mar   Apr   May   Jun   Jul   Aug   Sep   Oct   Nov   Dec');

  GotoXY (2, 21);
  Write  ('|08|$D78' + #196);

  For Loop1 := 1 to 12 Do
    For Loop2 := 15 DownTo 1 Do Begin
      GotoXY (Loop1 * 6, 2 + Loop2);
      Write  (#250 + #250 + #250);
    End;

  For Loop1 := 1 to 12 Do
    DrawBar (6 * Loop1, Months[Loop1]);

  DisplayMonthly := True; 
End;

Begin
  If Graphics = 0 Then Begin
    WriteLn ('|CRSorry, usage graphs require ANSI graphics|CR|CR|PA');
    Exit;
  End;

  If DisplayMonthly Then Begin
    GotoXY (28, 22);
    Write  ('|07Press |08[|15ENTER|08] |07to continue|PN');
  End;
End

Unit MUTIL_ImportNA;

{$I M_OPS.PAS}

Interface

Procedure uImportNA;

Implementation

Uses
  m_Strings,
  mutil_Common,
  mutil_Status;

Procedure uImportNA;
Var
  CreatedBases : LongInt = 0;
  InFile       : Text;
  Str          : String;
  Buffer       : Array[1..2048] of Byte;
  TagName      : String;
  BaseName     : String;
Begin
  ProcessName   ('Import FIDONET.NA', True);
  ProcessResult (rWORKING, False);

  Assign     (InFile, INI.ReadString(Header_IMPORTNA, 'filename', 'fidonet.na'));
  SetTextBuf (InFile, Buffer);

  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot find NA file');
    ProcessResult (rWARN, True);

    Exit;
  End;

  While Not Eof(InFile) Do Begin
    ReadLn(InFile, Str);

    Str := strStripB(Str, ' ');

    If (Str[1] = ';') or (Str = '') Then Continue;

    TagName  := strWordGet(1, Str, ' ');
    BaseName := strStripB(strWordGet(2, Str, ' '), ' ');

    ProcessStatus (BaseName);
  End;

  Close (InFile);

  ProcessStatus ('Created |15' + strI2S(CreatedBases) + ' |07base(s)');
  ProcessResult (rDONE, True);

  BarOne.Update(100, 100);
  BarAll.Update(ProcessPos, ProcessTotal);
End;

End.

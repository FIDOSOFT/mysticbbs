Unit m_io_Base;

{$I M_OPS.PAS}

Interface

Const
  TIOBufferSize = 16 * 1024 - 1;

Type
  TIOBuffer = Array[0..TIOBufferSize] of Char;

  TIOBase = Class
    FInBuf     : TIOBuffer;
    FInBufPos  : LongInt;
    FInBufEnd  : LongInt;
    FOutBuf    : TIOBuffer;
    FOutBufPos : LongInt;
    Connected  : Boolean;

    Constructor Create; Virtual;
    Destructor  Destroy; Override;
    Procedure   PurgeInputData  (DrainWait: LongInt);
    Procedure   PurgeOutputData;
    Function    DataWaiting     : Boolean; Virtual;
    Function    WriteBuf        (Var Buf; Len: LongInt) : LongInt; Virtual;
    Function    ReadBuf         (Var Buf; Len: LongInt) : LongInt; Virtual;
    Procedure   BufWriteChar    (Ch: Char); Virtual;
    Procedure   BufWriteStr     (Str: String); Virtual;
    Procedure   BufFlush; Virtual;
    Function    WriteStr (Str: String) : LongInt; Virtual;
    Function    WriteLine       (Str: String) : LongInt; Virtual;
    Function    ReadLine        (Var Str: String) : LongInt; Virtual;
    Function    WaitForData     (TimeOut: LongInt) : LongInt; Virtual;
    Function    PeekChar        (Num: Byte) : Char; Virtual;
    Function    ReadChar        : Char; Virtual;
  End;

Implementation

Uses
  m_DateTime;

Constructor TIOBase.Create;
Begin
  Inherited Create;

  FInBufPos  := 0;
  FInBufEnd  := 0;
  FOutBufPos := 0;
  Connected  := True;
End;

Destructor TIOBase.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TIOBase.PurgeOutputData;
Begin
  FOutBufPos := 0;
End;

Procedure TIOBase.PurgeInputData (DrainWait: LongInt);
Var
  Buf : Array[1..2048] of Char;
Begin
  FInBufPos := 0;
  FInBufEnd := 0;

  If DrainWait > 0 Then Begin
    DrainWait := TimerSet(DrainWait);

    While DataWaiting And Not TimerUp(DrainWait) Do Begin
      ReadBuf(Buf, SizeOf(Buf));
      If FInBufEnd <= 0 Then Break;
    End;
  End;
End;

Function TIOBase.DataWaiting : Boolean;
Begin
  Result := False;
End;

Function TIOBase.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := 0;
End;

Procedure TIOBase.BufFlush;
Begin
End;

Procedure TIOBase.BufWriteChar (Ch: Char);
Begin
End;

Procedure TIOBase.BufWriteStr (Str: String);
Begin
End;

Function TIOBase.ReadChar : Char;
Begin
  Result := #0;
End;

Function TIOBase.PeekChar (Num: Byte) : Char;
Begin
  Result := #0;
End;

Function TIOBase.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := 0;
End;

Function TIOBase.ReadLine (Var Str: String) : LongInt;
Begin
  Result := 0;
End;

Function TIOBase.WriteStr (Str: String) : LongInt;
Begin
  Result := 0;
End;

Function TIOBase.WriteLine (Str: String) : LongInt;
Begin
  Result := 0;
End;

Function TIOBase.WaitForData (TimeOut: LongInt) : LongInt;
Begin
  Result := 0;
End;

End.

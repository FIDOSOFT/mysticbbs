Unit m_io_Base;

{$I M_OPS.PAS}

Interface

Const
  TIOBufferSize = 8 * 1024 - 1;

Type
  TIOBuffer = Array[0..TIOBufferSize] of Char;

  TIOBase = Class
    FInBuf     : TIOBuffer;
    FInBufPos  : LongInt;
    FInBufEnd  : LongInt;
    FOutBuf    : TIOBuffer;
    FOutBufPos : LongInt;

    Constructor Create; Virtual;
    Destructor  Destroy; Override;
    Procedure   PurgeInputData;
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

Constructor TIOBase.Create;
Begin
  Inherited Create;

  FInBufPos  := 0;
  FInBufEnd  := 0;
  FOutBufPos := 0;
End;

Destructor TIOBase.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TIOBase.PurgeOutputData;
Begin
  FOutBufPos := 0;
End;

Procedure TIOBase.PurgeInputData;
//Var
//  Buf : Array[1..2048] of Char;
Begin
  FInBufPos := 0;
  FInBufEnd := 0;

//  While DataWaiting Do
//    ReadBuf(Buf, SizeOf(Buf));
End;

Function TIOBase.DataWaiting : Boolean;
Begin
End;

Function TIOBase.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
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
End;

Function TIOBase.PeekChar (Num: Byte) : Char;
Begin
End;

Function TIOBase.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
End;

Function TIOBase.ReadLine (Var Str: String) : LongInt;
Begin
End;

Function TIOBase.WriteStr (Str: String) : LongInt;
Begin
End;

Function TIOBase.WriteLine (Str: String) : LongInt;
Begin
End;

Function TIOBase.WaitForData (TimeOut: LongInt) : LongInt;
Begin
End;

End.

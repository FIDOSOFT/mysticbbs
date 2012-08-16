Unit MPL_FileIO;

{$I M_OPS.PAS}

// all file io units should be compiled into one source file...
// also, make this ONLY allocate the size of the file if the file size is
// less than the buffer.

Interface

Const
  MaxBufferSize = 64 * 1024;

Type
  PCharRec = ^TCharRec;
  TCharRec = Array[0..MaxBufferSize - 1] of Char;

  PCharFile = ^TCharFile;
  TCharFile = Object
    BufSize  : LongInt;
    Buffer   : PCharRec;
    BufRead  : LongInt;
    BufStart : LongInt;
    BufEnd   : LongInt;
    BufPos   : LongInt;
    InFile   : File;
    BufEOF   : Boolean;
    Opened   : Boolean;

    Constructor Init (BufferSize: LongInt);
    Destructor  Done;

    Function  Open (FN : String) : Boolean;
    Procedure Close;
    Function  Read : Char;
    Procedure BlockRead (Var Buf; Size: LongInt; Var Count: LongInt);
    Procedure Seek (FP : LongInt);
    Function  FilePos : LongInt;
    Function  FileSize : LongInt;
    Function  EOF : Boolean;
    Procedure FillBuffer;
  End;

Implementation

Function TCharFile.FilePos : LongInt;
Begin
  FilePos := BufStart + BufPos;
End;

Procedure TCharFile.FillBuffer;
Var
  Start : LongInt;
Begin
  Start := System.FilePos(InFile);

  System.BlockRead (InFile, Buffer^[0], BufSize, BufRead);

  BufStart := Start;
  BufEnd   := Start + BufRead;
  BufPos   := 0;
  BufEOF   := System.EOF(InFile);
End;

Constructor TCharFile.Init (BufferSize: LongInt);
Begin
  BufSize  := BufferSize;
  BufStart := 0;
  BufEnd   := 0;
  BufPos   := 0;
  BufEOF   := False;
  BufRead  := 0;
  Buffer   := NIL;
  Opened   := False;
End;

Destructor TCharFile.Done;
Begin
  If Assigned(Buffer) Then Begin
    FreeMem (Buffer, BufSize);
    Buffer := NIL;
  End;
End;

Function TCharFile.Open (FN : String) : Boolean;
Begin
  Open     := False;
  Opened   := False;
  FileMode := 66;

  Assign (InFile, FN);
  Reset  (InFile, 1);

  If IoResult <> 0 Then Exit;

  If BufSize > System.FileSize(InFile) Then
    BufSize := System.FileSize(InFile);

  If Assigned(Buffer) Then Done;

  GetMem (Buffer, BufSize);

  FillBuffer;

  Open   := True;
  Opened := True;
End;

Procedure TCharFile.Close;
Begin
  System.Close (InFile);
  Opened := False;

  Done;
End;

Function TCharFile.Read : Char;
Begin
  If BufPos >= BufSize Then FillBuffer;

  Read := Buffer^[BufPos];

  Inc (BufPos);
End;

Procedure TCharFile.BlockRead (Var Buf; Size: LongInt; Var Count: LongInt);
Begin
  If BufPos + Size >= BufRead Then Begin
    If Size > BufSize Then Size := BufSize;
    System.Seek(InFile, BufStart + BufPos);
    FillBuffer;
    If BufRead < Size Then Size := BufRead;
  End;

  Move (Buffer^[BufPos], Buf, Size);

  Inc (BufPos, Size);

  Count := Size;
End;

Procedure TCharFile.Seek (FP : LongInt);
Begin
  If (FP >= BufStart) and (FP < BufEnd) Then
    BufPos := (BufEnd - (BufEnd - FP)) - BufStart
  Else Begin
    System.Seek(InFile, FP);
    FillBuffer;
  End;
End;

Function TCharFile.EOF : Boolean;
Begin
  EOF := (BufStart + BufPos >= BufEnd) and BufEOF;
End;

Function TCharFile.FileSize : LongInt;
Begin
  FileSize := System.FileSize(InFile);
End;

End.

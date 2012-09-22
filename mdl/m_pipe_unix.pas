Unit m_Pipe_Unix;

{$I M_OPS.PAS}

Interface

Uses
  BaseUnix,
  m_DateTime,
  m_FileIO,
  m_Strings;

Type
  TPipeUnix = Class
    PipeID     : Word;
    Connected  : Boolean;
    IsClient   : Boolean;
    PipeHandle : THandle;

    Constructor Create       (Dir: String; Client: Boolean; ID: Word);
    Destructor  Destroy;     Override;
    // Server functions
    Function    CreatePipe   : Boolean;
    Function    WaitForPipe  (Secs: LongInt) : Boolean;
    // Client functions
    Function    ConnectPipe  (Secs: LongInt) : Boolean;
    // General functions
    Procedure   SendToPipe   (Var Buf; Len: Longint);
    Procedure   ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongWord);
    Procedure   Disconnect;
  End;

Implementation

Constructor TPipeUnix.Create (Dir: String; Client: Boolean; ID: Word);
Begin
  Connected  := False;
  IsClient   := Client;
  PipeID     := ID;
  PipeHandle := -1;
End;

Destructor TPipeUnix.Destroy;
Begin
  If Connected Then Disconnect;

  Inherited Destroy;
End;

Function TPipeUnix.CreatePipe : Boolean;
Var
  PipeName : String;
Begin
  IsClient := False;
  PipeName := '/tmp/mystic_' + strI2S(PipeID);

  If Not FileExist(PipeName) Then
    fpMkFIFO(PipeName, 438);

  PipeHandle := fpOpen(PipeName, O_WRONLY, O_NONBLOCK);
  Result     := PipeHandle >= 0;
End;

Procedure TPipeUnix.SendToPipe (Var Buf; Len: LongInt);
Begin
  If Not Connected Then Exit;

  If fpWrite (PipeHandle, Buf, Len) < 0 Then
    Disconnect;
End;

Procedure TPipeUnix.ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongWord);
Begin
  bRead := 0;

  If Not Connected Then Exit;

  bRead := fpRead (PipeHandle, Buf, Len);

  If bRead < 0 Then Disconnect;
End;

Function TPipeUnix.WaitForPipe (Secs: LongInt) : Boolean;
Begin
  Connected := PipeHandle > -1;
  Result    := Connected;
End;

Function TPipeUnix.ConnectPipe (Secs: LongInt) : Boolean;
Var
  PipeName : String;
  TimeOut  : LongInt;
Begin
  IsClient := True;

  Disconnect;

  PipeName := '/tmp/mystic_' + strI2S(PipeID);
  TimeOut  := TimerSet(Secs);

  Repeat
    PipeHandle := fpOpen(PipeName, O_RDONLY, O_NONBLOCK);
    Connected  := PipeHandle >= 0;
  Until Connected or TimerUp(TimeOut);

  Result := Connected;
End;

Procedure TPipeUnix.Disconnect;
Begin
  If PipeHandle = -1 Then Exit;

  fpClose (PipeHandle);

  PipeHandle := -1;
  Connected  := False;
End;

End.

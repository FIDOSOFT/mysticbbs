Unit m_Pipe_Unix;

{$I M_OPS.PAS}

Interface

Uses
  m_DateTime,
  m_FileIO,
  m_Strings;

Type
  TPipeUnix = Class
    PipeID     : Word;
    Connected  : Boolean;
    IsClient   : Boolean;
    PipeDir    : String;

    Constructor Create       (Dir: String; Client: Boolean; ID: Word);
    Destructor  Destroy;     Override;
    // Server functions
    Function    CreatePipe   : Boolean;
    Function    WaitForPipe  (Secs: LongInt) : Boolean;
    // Client functions
    Function    ConnectPipe  (Secs: LongInt) : Boolean;
    // General functions
    Procedure   SendToPipe   (Var Buf; Len: Longint);
    Procedure   ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongInt);
    Procedure   Disconnect;
  End;

Implementation

Constructor TPipeUnix.Create (Dir: String; Client: Boolean; ID: Word);
Begin
  Connected  := False;
  IsClient   := Client;
  PipeDir    := DirSlash(Dir);
  PipeID     := ID;
End;

Destructor TPipeUnix.Destroy;
Begin
  If Connected Then Disconnect;

  Inherited Destroy;
End;

Function TPipeUnix.CreatePipe : Boolean;
Begin
  Result   := False;
  IsClient := False;

  Result := True;
End;

Procedure TPipeUnix.SendToPipe (Var Buf; Len: LongInt);
Begin
  If Not Connected Then Exit;
End;

Procedure TPipeUnix.ReadFromPipe (Var Buf; Len: LongInt; Var bRead: LongInt);
Begin
  bRead := 0;

  If Not Connected Then Exit;
End;

Function TPipeUnix.WaitForPipe (Secs: LongInt) : Boolean;
Begin
  Result := Connected;

  If Connected Then Exit;

  Result := Connected;
End;

Function TPipeUnix.ConnectPipe (Secs: LongInt) : Boolean;
Begin
  Result    := False;
  Connected := False;
  IsClient  := True;

  Result := Connected;
End;

Procedure TPipeUnix.Disconnect;
Begin
  If Not Connected Then Exit;

  Connected := False;
End;

End.

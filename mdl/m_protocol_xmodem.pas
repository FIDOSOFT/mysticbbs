Unit m_Protocol_XModem;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_Protocol_Base,
  m_Protocol_Queue;

Type
  TProtocolXmodem = Class(TProtocolBase)
    DoCRC : Boolean;
    Do1K  : Boolean;

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;
  End;

Implementation

Constructor TProtocolXmodem.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  DoCRC := True;
  Do1K  := True;
End;

Destructor TProtocolXmodem.Destroy;
Begin
  Inherited Destroy;
End;

End.

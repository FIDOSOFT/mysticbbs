Unit m_Protocol_YModem;

{$I M_OPS.PAS}

Interface

Uses
  m_Socket_Class,
  m_Protocol_Queue,
  m_Protocol_Xmodem;

Type
  TProtocolYmodem = Class(TProtocolXmodem)
    UseG : Boolean;

    Constructor Create (Var C: TSocketClass; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;
  End;

Implementation

Constructor TProtocolYModem.Create (Var C: TSocketClass; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  UseG := False;
End;

Destructor TProtocolYModem.Destroy;
Begin
  Inherited Destroy;
End;

End.
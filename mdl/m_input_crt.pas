{$I M_OPS.PAS}

Unit m_Input_CRT;

// This is a generic implementation of the Input class which relies on the
// FPC CRT unit.  This is not really suitable to use but it can sometimes
// be useful when beginning to port an MDL application to a new operating
// system.  The CRT based I/O implementions not only rely on a usable CRT
// implementation for that platform, but also are very inefficient.  They
// should NOT be used.

Interface

Type
  TInputCRT = Class

    Constructor Create;
    Destructor  Destroy; Override;

    Function    ProcessQueue : Boolean;
    Function    KeyWait (MS: LongInt) : Boolean;
    Function    KeyPressed : Boolean;
    Function    ReadKey : Char;
  End;

Implementation

Uses
  CRT;

Constructor TInputCRT.Create;
Begin
  Inherited Create;
End;

Destructor TInputCRT.Destroy;
Begin
  Inherited Destroy;
End;

Function TInputCRT.ProcessQueue : Boolean;
Begin
  Result := CRT.KeyPressed;
End;

Function TInputCRT.KeyWait (MS: LongInt) : Boolean;
Var
  WaitTimer : LongInt = 0;
Begin
  Result := CRT.KeyPressed;

  While Not Result And (WaitTimer < MS) Do Begin
    CRT.Delay (20);

    Inc (WaitTimer, 20);

    Result := KeyPressed;
  End;
End;

Function TInputCRT.ReadKey : Char;
Begin
  Result := CRT.ReadKey;
End;

Function TInputCRT.KeyPressed : Boolean;
Begin
  Result := CRT.KeyPressed;
End;

End.

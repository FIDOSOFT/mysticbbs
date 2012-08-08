Unit m_Protocol_Queue;

{$I M_OPS.PAS}

Interface

Const
  QueueMaxSize     = 100;
  QueueMaxPathSize = 120;
  QueueMaxNameSize = 120;
  QueuePending     = 0;
  QueueSuccess     = 1;
  QueueFailed      = 2;
  QueueInTransit   = 3;
  QueueSkipped     = 4;
  QueueNoFile      = 5;

Type
  TProtocolQueuePTR = ^TProtocolQueueRec;
  TProtocolQueueRec = Record
    FilePath : String[QueueMaxPathSize];
    FileName : String[QueueMaxNameSize];
    FileSize : Int64;
    Status   : Byte;
  End;

  TProtocolQueue = Class
    QSize : Word;
    QPos  : Word;
    QData : Array[1..QueueMaxSize] of TProtocolQueuePTR;

    Constructor Create;
    Destructor  Destroy; Override;

    Function    Add    (fPath, fName: String) : Boolean;
    Procedure   Delete (Idx: Word);
    Procedure   Clear;
    Function    Next : Boolean;
  End;

Implementation

Constructor TProtocolQueue.Create;
Begin
  Inherited Create;

  QSize := 0;
  QPos  := 0;
End;

Destructor TProtocolQueue.Destroy;
Begin
  Clear;
End;

Function TProtocolQueue.Add (fPath, fName: String) : Boolean;
Var
  F : File;
Begin
  Add := False;

  If (QSize = QueueMaxSize) Then Exit;

  Inc (QSize);

  New (QData[QSize]);

  QData[QSize]^.FilePath := fPath;
  QData[QSize]^.FileName := fName;
  QData[Qsize]^.FileSize := 0;

  Assign (F, fPath + fName);

  {$I-} Reset(F, 1); {$I+}
  If IoResult = 0 Then Begin
    QData[QSize]^.FileSize := FileSize(F);
    QData[QSize]^.Status   := QueuePending;
    Close(F);
  End Else
    QData[QSize]^.Status := QueueNoFile;

  Add := True;
End;

Procedure TProtocolQueue.Delete (Idx: Word);
Var
  Count : Word;
Begin
  If QData[Idx] <> NIL Then Begin
    Dispose (QData[Idx]);

    For Count := Idx To QueueMaxSize - 1 Do
      QData[Count] := QData[Count + 1];

    Dec (QSize);

    If QPos >= Idx Then Dec(QPos);
  End;
End;

Function TProtocolQueue.Next : Boolean;
Begin
  Next := False;

  If QPos < QSize Then
    Repeat
      Inc (QPos);

      If QData[QPos]^.Status <> QueueNoFile Then Begin
        Next := True;
        Break;
      End;
    Until (QPos = QSize);
End;

Procedure TProtocolQueue.Clear;
Var
  Count : Word;
Begin
  For Count := 1 to QSize Do Begin
    Dispose (QData[Count]);
    QData[Count] := NIL;
  End;

  QSize := 0;
  QPos  := 0;
End;

End.

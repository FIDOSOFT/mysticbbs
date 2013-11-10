// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
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
    FileNew  : String[QueueMaxNameSize];
    Extra    : String[QueueMaxPathSize];
    FileSize : Int64;
    Status   : Byte;
  End;

  TProtocolQueue = Class
    QFSize : Cardinal;
    QSize  : Word;
    QPos   : Word;
    QData  : Array[1..QueueMaxSize] of TProtocolQueuePTR;

    Constructor Create;
    Destructor  Destroy; Override;

    Function    Add    (CheckValid: Boolean; fPath, fName, fNew: String) : Boolean;
    Procedure   Delete (Idx: Word);
    Procedure   Clear;
    Function    Next : Boolean;
  End;

Implementation

Constructor TProtocolQueue.Create;
Begin
  Inherited Create;

  QFSize := 0;
  QSize  := 0;
  QPos   := 0;
End;

Destructor TProtocolQueue.Destroy;
Begin
  Clear;
End;

Function TProtocolQueue.Add (CheckValid: Boolean; fPath, fName, fNew: String) : Boolean;
Var
  F : File;
Begin
  Result := False;

  If (QSize = QueueMaxSize) Then Exit;

  Inc (QSize);

  New (QData[QSize]);

  QData[QSize]^.FilePath := fPath;
  QData[QSize]^.FileName := fName;
  QData[QSize]^.FileNew  := fNew;
  QData[Qsize]^.FileSize := 0;

  If fNew = '' Then
    QData[QSize]^.FileNew := fName;

  Assign (F, fPath + fName);

  {$I-} Reset(F, 1); {$I+}

  If IoResult = 0 Then Begin
    QData[QSize]^.FileSize := FileSize(F);
    QData[QSize]^.Status   := QueuePending;

    Inc (QFSize, QData[QSize]^.FileSize);

    Close(F);
  End Else
  If CheckValid Then Begin
    Dispose (QData[QSize]);
    Dec     (QSize);

    Exit;
  End Else
    QData[QSize]^.Status := QueueNoFile;

  Result := True;
End;

Procedure TProtocolQueue.Delete (Idx: Word);
Var
  Count : Word;
Begin
  If QData[Idx] <> NIL Then Begin
    Dec (QFSize, QData[QSize]^.FileSize);

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

  QFSize := 0;
  QSize  := 0;
  QPos   := 0;
End;

End.

{$I M_OPS.PAS}

Unit MIS_NodeData;

// annoying node data class used until we fuse MIS and Mystic together

Interface

Uses
  MIS_Common;

Type
  TNodeInfoRec = Record
    Num    : Byte;
    Busy   : Boolean;
    User   : String;
    Action : String;
    IP     : String;
  End;

  TNodeData = Class
    NodeInfo  : Array[1..199] of TNodeInfoRec;
    NodeTotal : Byte;
    Critical  : TRTLCriticalSection;

    Constructor Create (Nodes: Byte);
    Destructor  Destroy; Override;
    Function    GetNodeTotal : LongInt;
    Function    GetNodeInfo (Num: Byte; Var NI: TNodeInfoRec): Boolean;
    Procedure   SetNodeInfo (Num: Byte; NI: TNodeInfoRec);
    Function    GetFreeNode : LongInt;
  End;

Implementation

Uses
  m_FileIO,
  m_Strings;

Function TNodeData.GetFreeNode : LongInt;
Var
  Count : LongInt;
Begin
  EnterCriticalSection(Critical);

  Result := -1;

  For Count := 1 to NodeTotal Do
    If Not NodeInfo[Count].Busy Then Begin
      NodeInfo[Count].Busy := True;
      Result := NodeInfo[Count].Num;
      Break;
    End;

  LeaveCriticalSection(Critical);
End;

Function TNodeData.GetNodeInfo (Num: Byte; Var NI: TNodeInfoRec) : Boolean;
Begin
  EnterCriticalSection(Critical);

  Result := False;

  FillChar(NI, SizeOf(NI), 0);

  If Num <= NodeTotal Then Begin
    NI     := NodeInfo[Num];
    Result := True;
  End;

  LeaveCriticalSection(Critical);
End;

Procedure TNodeData.SetNodeInfo (Num: Byte; NI: TNodeInfoRec);
Var
  Count : LongInt;
Begin
  EnterCriticalSection(Critical);

  For Count := 1 to NodeTotal Do
    If NodeInfo[Count].Num = Num Then
      NodeInfo[Count] := NI;

  LeaveCriticalSection(Critical);
End;

Function TNodeData.GetNodeTotal : LongInt;
Begin
  EnterCriticalSection(Critical);

  Result := NodeTotal;

  LeaveCriticalSection(Critical);
End;

Constructor TNodeData.Create (Nodes: Byte);
Var
  Count : SmallInt;
Begin
  InitCriticalSection(Critical);

  NodeTotal := Nodes;

  For Count := 1 to NodeTotal Do
    NodeInfo[Count].Num := Count;
End;

Destructor TNodeData.Destroy;
Begin
  DoneCriticalSection(Critical);

  Inherited Destroy;
End;

End.

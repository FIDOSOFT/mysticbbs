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

{$I M_OPS.PAS}

Unit MIS_NodeData;

// annoying node data class used until we fuse MIS and Mystic together

Interface

Uses
  BBS_DataBase,
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

    Procedure   SynchronizeNodeData;
    Function    GetNodeTotal : LongInt;
    Function    GetNodeInfo (Num: Byte; Var NI: TNodeInfoRec): Boolean;
    Procedure   SetNodeInfo (Num: Byte; NI: TNodeInfoRec);
    Function    GetFreeNode : LongInt;
  End;

Implementation

Uses
  m_FileIO,
  m_Strings,
  BBS_Records;

Procedure TNodeData.SynchronizeNodeData;
Var
  ChatFile : File of ChatRec;
  Chat     : ChatRec;
  Count    : LongInt;
  NI       : TNodeInfoRec;
Begin
  For Count := 1 to NodeTotal Do Begin
    GetNodeInfo (Count, NI);

    Assign (ChatFile, bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');

    If ioReset(ChatFile, SizeOf(ChatRec), fmRWDN) Then Begin
      ioRead (ChatFile, Chat);
      Close  (ChatFile);

      NI.Busy   := Chat.Active;
      NI.User   := Chat.Name;
      NI.Action := Chat.Action;
    End Else
      NI.Busy := False;

    SetNodeInfo (NI.Num, NI);
  End;
End;

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

  SynchronizeNodeData;
End;

Destructor TNodeData.Destroy;
Begin
  DoneCriticalSection(Critical);

  Inherited Destroy;
End;

End.

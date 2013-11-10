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
Unit MUTIL_EchoFix;

{$I M_OPS.PAS}

Interface

Uses
  mUtil_EchoCore;

Function ProcessedByAreaFix (Var PKT: TPKTReader) : Boolean;

Implementation

Uses
  m_Strings,
  BBS_Records;

Function ProcessedByAreaFix (Var PKT: TPKTReader) : Boolean;
Var
  IsAreaFix : Boolean;
  IsFileFix : Boolean;
  EchoNode  : RecEchoMailNode;
Begin
  Result    := False;
  IsAreaFix := strUpper(PKT.MsgTo) = 'AREAFIX';
  IsFileFix := strUpper(PKT.MsgTo) = 'FILEFIX';

  If Not (IsAreaFix or IsFileFix) Then Exit;

(*Function GetNodeByAuth (Addr: RecEchoMailAddr; PW: String; Var TempNode: RecEchoMailNode) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) And Not Result Do Begin
    ioRead(F, TempNode);

    Result := (strUpper(PW) = strUpper(TempNode.AreaFixPass)) and
              (Addr.Zone = TempNode.Address.Node) and
              (Addr.Net  = TempNode.Address.Net) and
              (Addr.Node = TempNode.Address.Node);
  End;

  Close (F);
End;
*)


  // find recechomailnode
  // check subject against session password
  // problem is that the PKTMSG header doesnt have ZONE or POINT
  //   so how do we do this without shite security?

  // if bad password do we respond back or just ignore?
  // if no node config found then do we toss to badmsgs?



  // commands (AREAFIX):
  // %LIST
  // %RESCAN optional can have ,R=100 where 100 is last X messages
  // %HELP
  // [+]ECHOTAG or -ECHOTAG to add/remove base
  // =ECHOTAG to rescan a single base? optional ,R=100 same as RESCAN
  // %COMPRESS <NAME> or ? to list packers.
  // %PWD <pw>
End;

End.

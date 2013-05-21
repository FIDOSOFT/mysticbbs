Unit MUTIL_EchoFix;

{$I M_OPS.PAS}

Interface

Uses
  mUtil_EchoCore;

Function ProcessedByAreaFix (Var PKT: TPKTReader) : Boolean;

Implementation

Uses
  m_Strings;

Function ProcessedByAreaFix (Var PKT: TPKTReader) : Boolean;
Var
  IsAreaFix : Boolean;
  IsFileFix : Boolean;
Begin
  Result    := False;
  IsAreaFix := strUpper(PKT.MsgTo) = 'AREAFIX';
  IsFileFix := strUpper(PKT.MsgTo) = 'FILEFIX';

  If Not (IsAreaFix or IsFileFix) Then Exit;

  // find recechomailnode
  // check subject against session password
  //    if bad password do we respond back or just ignore?
  // if none found then do we toss to badmsgs?

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

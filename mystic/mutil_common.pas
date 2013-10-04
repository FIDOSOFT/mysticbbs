Unit MUTIL_Common;

{$I M_OPS.PAS}

Interface

Uses
  m_Output,
  m_IniReader,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase,
  BBS_MsgBase_ABS,
  BBS_MsgBase_Squish,
  BBS_MsgBase_JAM;

Var
  INI          : TINIReader;
  BarOne       : TStatusBar;
  BarAll       : TStatusBar;
  ProcessTotal : Byte = 0;
  ProcessPos   : Byte = 0;
  TempPath     : String;
  StartPath    : String;
  LogFile      : String;
  LogLevel     : Byte = 1;

Const
  Header_GENERAL    = 'General';
  Header_IMPORTNA   = 'Import_FIDONET.NA';
  Header_IMPORTMB   = 'Import_MessageBase';
  Header_ECHOEXPORT = 'ExportEchoMail';
  Header_ECHOIMPORT = 'ImportEchoMail';
  Header_FILEBONE   = 'Import_FILEBONE.NA';
  Header_FILESBBS   = 'Import_FILES.BBS';
  Header_UPLOAD     = 'MassUpload';
  Header_TOPLISTS   = 'GenerateTopLists';
  Header_ALLFILES   = 'GenerateAllFiles';
  Header_MSGPURGE   = 'PurgeMessageBases';
  Header_MSGPACK    = 'PackMessageBases';
  Header_MSGPOST    = 'PostTextFiles';
  Header_NODELIST   = 'MergeNodeLists';

Procedure Log                (Level: Byte; Code: Char; Str: String);
Function  GetUserBaseSize    : Cardinal;
Function  GenerateMBaseIndex : LongInt;
Function  GenerateFBaseIndex : LongInt;
Function  IsDupeMBase        (FN: String) : Boolean;
Function  IsDupeFBase        (FN: String) : Boolean;
Procedure AddMessageBase     (Var MBase: RecMessageBase);
Procedure AddFileBase        (Var FBase: RecFileBase);
Function  GetMBaseByIndex    (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Function  GetMBaseByTag      (Tag: String; Var TempBase: RecMessageBase) : Boolean;
Function  GetMBaseByNetZone  (Zone: Word; Var TempBase: RecMessageBase) : Boolean;
Function  MessageBaseOpen    (Var Msg: PMsgBaseABS; Var Area: RecMessageBase) : Boolean;
Function  SaveMessage        (mArea: RecMessageBase; mFrom, mTo, mSubj: String; mAddr: RecEchoMailAddr; mText: RecMessageText; mLines: Integer) : Boolean;
Function  GetFTNArchiveName  (Orig, Dest: RecEchoMailAddr) : String;
Function  GetFTNFlowName     (Dest: RecEchoMailAddr) : String;
Function  GetFTNOutPath      (EchoNode: RecEchoMailNode) : String;
Function  GetNodeByRoute     (Dest: RecEchoMailAddr; Var TempNode: RecEchoMailNode) : Boolean;
Function  IsValidAKA         (Zone, Net, Node, Point: Word) : Boolean;

Implementation

Uses
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  DOS,
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO;

Procedure Log (Level: Byte; Code: Char; Str: String);
Var
  T : Text;
Begin
  If (LogLevel < Level) or (LogFile = '') Then Exit;

  Assign (T, LogFile);
  Append (T);

  If Str = '' Then
    WriteLn (T, '')
  Else
    WriteLn (T, Code + ' ' + FormatDate(CurDateDT, 'NNN DD YYYY HH:II') + ' ' + Str);

  Close (T);
End;

Function GetUserBaseSize : Cardinal;
Begin
  Result := FileByteSize(bbsCfg.DataPath + 'users.dat');

  If Result > 0 Then Result := Result DIV SizeOf(RecUser);
End;

Function IsDupeMBase (FN: String) : Boolean;
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
Begin
  Result := False;

  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');
  {$I-} Reset (MBaseFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If strUpper(MBase.FileName) = strUpper(FN) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (MBaseFile);
End;

Function IsDupeFBase (FN: String) : Boolean;
Var
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;
Begin
  Result := False;

  Assign (FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset (FBaseFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If strUpper(FBase.FileName) = strUpper(FN) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (FBaseFile);
End;

Function GenerateMBaseIndex : LongInt;
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
Begin
  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');
  Reset  (MBaseFile);

  Result := FileSize(MBaseFile);

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If MBase.Index = Result Then Begin
      Inc   (Result);
      Reset (MBaseFile);
    End;
  End;

  Close (MBaseFile);
End;

Function GenerateFBaseIndex : LongInt;
Var
  FBaseFile : File of RecFileBase;
  FBase     : RecFileBase;
Begin
  Assign (FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  Reset  (FBaseFile);

  Result := FileSize(FBaseFile);

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If FBase.Index = Result Then Begin
      Inc   (Result);
      Reset (FBaseFile);
    End;
  End;

  Close (FBaseFile);
End;

Procedure AddMessageBase (Var MBase: RecMessageBase);
Var
  MBaseFile : File of RecMessageBase;
Begin
  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');
  Reset  (MBaseFile);
  Seek   (MBaseFile, FileSize(MBaseFile));
  Write  (MBaseFile, MBase);
  Close  (MBaseFile);
End;

Procedure AddFileBase (Var FBase: RecFileBase);
Var
  FBaseFile : File of RecFileBase;
Begin
  Assign (FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  Reset  (FBaseFile);
  Seek   (FBaseFile, FileSize(FBaseFile));
  Write  (FBaseFile, FBase);
  Close  (FBaseFile);
End;

Function GetMBaseByIndex (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead(F, TempBase);

    If TempBase.Index = Num Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (F);
End;

Function GetMBaseByTag (Tag: String; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead(F, TempBase);

    If Tag = strUpper(TempBase.EchoTag) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close (F);
End;

Function GetMBaseByNetZone (Zone: Word; Var TempBase: RecMessageBase) : Boolean;
// get netmail base with matching zone, or at least A netmail base if no match
Var
  F      : File;
  One    : RecMessageBase;
  GotOne : Boolean;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead(F, TempBase);

    If (TempBase.NetType = 3) Then Begin
      One    := TempBase;
      GotOne := True;

      If Zone = bbsCfg.NetAddress[TempBase.NetAddr].Zone Then Begin
        Result := True;

        Break;
      End;
    End;
  End;

  Close (F);

  If Not Result And GotOne Then Begin
    Result   := True;
    TempBase := One;
  End;
End;

Function MessageBaseOpen (Var Msg: PMsgBaseABS; Var Area: RecMessageBase) : Boolean;
Begin
  Result := False;

  Case Area.BaseType of
    0 : Msg := New(PMsgBaseJAM, Init);
    1 : Msg := New(PMsgBaseSquish, Init);
  End;

  Msg^.SetMsgPath  (Area.Path + Area.FileName);
  Msg^.SetTempFile (TempPath + 'msgbuf.tmp');

  If Not Msg^.OpenMsgBase Then
    If Not Msg^.CreateMsgBase (Area.MaxMsgs, Area.MaxAge) Then Begin
      Dispose (Msg, Done);
      Exit;
    End Else
    If Not Msg^.OpenMsgBase Then Begin
      Dispose (Msg, Done);
      Exit;
    End;

  Result := True;
End;

Function SaveMessage (mArea: RecMessageBase; mFrom, mTo, mSubj: String; mAddr: RecEchoMailAddr; mText: RecMessageText; mLines: Integer) : Boolean;
Var
  SemFile : File;
  Count   : SmallInt;
  Msg     : PMsgBaseABS;
Begin
  Result := False;

  If Not MessageBaseOpen(Msg, mArea) Then Exit;

  Msg^.StartNewMsg;
  Msg^.SetLocal (True);

  If mArea.NetType > 0 Then Begin
    If mArea.NetType = 2 Then Begin
      Msg^.SetMailType (mmtNetMail);
      Msg^.SetCrash    (bbsCfg.netCrash);
      Msg^.SetHold     (bbsCfg.netHold);
      Msg^.SetKillSent (bbsCfg.netKillSent);
      Msg^.SetDest     (mAddr);
    End Else
      Msg^.SetMailType (mmtEchoMail);

    Msg^.SetOrig(bbsCfg.NetAddress[mArea.NetAddr]);

    Case mArea.NetType of
      1 : If mArea.QwkConfID = 0 Then
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileEchoOut)
          Else
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileQwk);
      2 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNews);
      3 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNet);
    End;

    ReWrite (SemFile);
    Close   (SemFile);
  End Else
    Msg^.SetMailType (mmtNormal);

  Msg^.SetPriv (mArea.Flags And MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, 0));
  Msg^.SetFrom (mFrom);
  Msg^.SetTo   (mTo);
  Msg^.SetSubj (mSubj);

  If (mArea.NetType > 0) and (mArea.QwkNetID = 0) Then
    Msg^.DoStringLn (#1 + 'MSGID: ' + Addr2Str(bbsCfg.NetAddress[mArea.NetAddr]) + ' ' + strI2H(CurDateDos, 8));

  For Count := 1 to mLines Do
    Msg^.DoStringLn(mText[Count]);

  If mArea.NetType > 0 Then Begin
    Msg^.DoStringLn (#13 + '--- ' + mysSoftwareID + ' v' + mysVersion + ' (' + OSID + ')');
    Msg^.DoStringLn (' * Origin: ' + mArea.Origin + ' (' + Addr2Str(bbsCfg.NetAddress[mArea.NetAddr]) + ')');
  End;

  Msg^.WriteMsg;
  Msg^.CloseMsgBase;

  Dispose (Msg, Done);

  Result := True;
End;

Function GetFTNArchiveName (Orig, Dest: RecEchoMailAddr) : String;
Var
  Net  : LongInt;
  Node : LongInt;
Begin
  If Dest.Point = 0 Then Begin
    Net  := Orig.Net  - Dest.Net;
    Node := Orig.Node - Dest.Node;

    If Net  < 0 Then Net  := 65536 + Net;
    If Node < 0 Then Node := 65536 + Node;

    Result := strI2H((Net SHL 16) OR Node, 8);
  End Else
    Result := strI2H(Dest.Point, 8);
End;

Function GetFTNFlowName (Dest: RecEchoMailAddr) : String;
Begin
  If Dest.Point = 0 Then
    Result := strI2H((Dest.Net SHL 16) OR Dest.Node, 8)
  Else
    Result := strI2H(Dest.Point, 8);
End;

Function IsFTNPrimary (EchoNode: RecEchoMailNode) : Boolean;
Var
  Count : Byte;
Begin
  For Count := 1 to 30 Do
    If (strUpper(EchoNode.Domain) = strUpper(bbsCfg.NetDomain[Count])) and
       (EchoNode.Address.Zone = bbsCfg.NetAddress[Count].Zone) and
       (bbsCfg.NetPrimary[Count]) Then Begin
         Result := True;

         Exit;
    End;

  Result := False;
End;

Function GetFTNOutPath (EchoNode: RecEchoMailNode) : String;
Begin;
  If IsFTNPrimary(EchoNode) Then
    Result := bbsCfg.OutboundPath
  Else
    Result := DirLast(bbsCfg.OutboundPath) + strLower(EchoNode.Domain + '.' + strPadL(strI2H(EchoNode.Address.Zone, 3), 3, '0')) + PathChar;

  If EchoNode.Address.Point <> 0 Then
    Result := Result + strI2H((EchoNode.Address.Net SHL 16) OR EchoNode.Address.Node, 8) + '.pnt' + PathChar;
End;

Function GetNodeByRoute (Dest: RecEchoMailAddr; Var TempNode: RecEchoMailNode) : Boolean;

  Function IsMatch (Str: String) : Boolean;

    Function IsOneMatch (Mask: String) : Boolean;
    Var
      Zone  : String;
      Net   : String;
      Node  : String;
      Point : String;
      A     : Byte;
      B     : Byte;
      C     : Byte;
    Begin
      Result := False;
      Zone   := '';
      Net    := '';
      Node   := '';
      Point  := '';
      A      := Pos(':', Mask);
      B      := Pos('/', Mask);
      C      := Pos('.', Mask);

      If A <> 0 Then Begin
        Zone := Copy(Mask, 1, A - 1);

        If B = 0 Then B := 255;
        If C = 0 Then C := 255;

        Net   := Copy(Mask, A + 1, B - 1 - A);
        Node  := Copy(Mask, B + 1, C - 1 - B);
        Point := Copy(Mask, C + 1, 255);
      End;

      If Zone  = '' Then Zone  := '*';
      If Net   = '' Then Net   := '*';
      If Node  = '' Then Node  := '*';
      If Point = '' Then Point := '*';

      If (Zone <> '*')  and (Dest.Zone  <> strS2I(Zone))  Then Exit;
      If (Net  <> '*')  and (Dest.Net   <> strS2I(Net))   Then Exit;
      If (Node <> '*')  and (Dest.Node  <> strS2I(Node))  Then Exit;
      If (Point <> '*') and (Dest.Point <> strS2I(Point)) Then Exit;

      Result := True;
    End;

  Var
    Mask   : String = '';
    OneRes : Boolean;

    Procedure GetNextAddress;
    Begin
      If Pos('!', Str) > 0 Then Begin
        Mask := Copy(Str, 1, Pos('!', Str) - 1);

        Delete (Str, 1, Pos('!', Str) - 1);
      End Else
      If Pos(' ', Str) > 0 Then Begin
        Mask := Copy(Str, 1, Pos(' ', Str) - 1);

        Delete (Str, 1, Pos(' ', Str));
      End Else Begin
        Mask := Str;
        Str  := '';
      End;
    End;

  Begin
    Result := False;
    Str    := strStripB(Str, ' ');

    If Str = '' Then Exit;

    Repeat
      GetNextAddress;

      If Mask = '' Then Break;

      OneRes := IsOneMatch(Mask);

      While (Str[1] = '!') and (Mask <> '') Do Begin
        Delete (Str, 1, 1);

        GetNextAddress;

        OneRes := OneRes AND (NOT IsOneMatch(Mask));
      End;

      Result := Result OR OneRes;
    Until Str = '';
  End;

Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) And Not Result Do Begin
    ioRead(F, TempNode);

    Result := IsMatch(TempNode.RouteInfo);
  End;

  Close (F);
End;

Function IsValidAKA (Zone, Net, Node, Point: Word) : Boolean;
Var
  Count : Byte;
Begin
  Result := False;

  For Count := 1 to 30 Do Begin
    Result := (bbsCfg.NetAddress[Count].Zone  = Zone) And
              (bbsCfg.NetAddress[Count].Net   = Net)  And
              (bbsCfg.NetAddress[Count].Node  = Node) And
              (bbsCfg.NetAddress[Count].Point = Point);

    If Result Then Break;
  End;
End;

End.

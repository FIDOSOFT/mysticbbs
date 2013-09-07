Program QwkPoll;

{$I M_OPS.PAS}

Uses
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_TCP_Client_FTP,
  BBS_Records,
  BBS_DataBase,
  BBS_MsgBase_QWK;

Var
  TempPath : String;

Function PollByQWKNet (QwkNet: RecQwkNetwork) : Boolean;
Var
  QWK  : TQwkEngine;
  FTP  : TFTPClient;
  User : RecUser;
Begin
  Result := False;

  If (QwkNet.MemberType <> 1) or
     (QwkNet.PacketID = '') or
     (QwkNet.ArcType = '') Then Exit;

  WriteLn ('- Exchanging Mail for ' + QwkNet.Description);

  User.Handle     := QwkNet.PacketID;
  User.QwkNetwork := QwkNet.Index;

  QWK := TQwkEngine.Create (TempPath, QwkNet.PacketID, 1, User);

  QWK.IsNetworked := True;
  QWK.IsExtended  := QwkNet.UseQWKE;

  QWK.ExportPacket(True);

  ExecuteArchive (TempPath, TempPath + QwkNet.PacketID + '.rep', QwkNet.ArcType, TempPath + '*', 1);

  WriteLn ('      - Exported @' + QwkNet.PacketID + '.rep -> ', QWK.TotalMessages, ' msgs ');
  WriteLn ('      - Connecting via FTP to ' + QWkNet.HostName);

  FTP := TFTPClient.Create;

  If FTP.OpenConnection(QwkNet.HostName) Then Begin
  writeln('DEBUG connected');
    If FTP.Authenticate(QwkNet.Login, QwkNet.Password) Then Begin
    writeln('DEBUG authenticated; sending REP');
      FTP.SendFile (QwkNet.UsePassive, TempPath + QwkNet.PacketID + '.rep');

      // if was sent successfully THEN update by setting
      // isSent on all messages UP until the QLR.DAT information?
      // also need to remove the SetLocal crap and make an UpdateSentFlags
      // in QWK class if we do this.

      DirClean       (TempPath, '');
      writeln ('DEBUG downloading QWK packet');
      FTP.GetFile    (QwkNet.UsePassive, TempPath + QwkNet.PacketID + '.qwk');
      writeln ('DEBUG unpacking QWK');
      ExecuteArchive (TempPath, TempPath + QwkNet.PacketID + '.qwk', QwkNet.ArcType, '*', 2);

      writeln ('DEBUG importing QWK');
      QWK.ImportPacket(True);
      writeln ('DEBUG imported QWK TODO add stats here');
    End;
  End;

  writeln ('DEBUG disposing memory');

  FTP.Free;
  QWK.Free;

  DirClean (TempPath, '');

  WriteLn;
End;

Var
  Str    : String;
  F      : File;
  QwkNet : RecQwkNetwork;
  Count  : Byte = 0;
  Mode   : Byte;
Begin
  WriteLn;
  WriteLn ('QWKPOLL Version ' + mysVersion);
  WriteLn;

  Case bbsCfgStatus of
    1 : WriteLn ('Unable to read MYSTIC.DAT');
    2 : WriteLn ('Data file version mismatch');
  End;

  If bbsCfgStatus <> 0 Then Halt(1);

  TempPath := bbsCfg.SystemPath + 'tempqwk' + PathChar;

  DirCreate (TempPath);

  WriteLn ('Program session start at ' + FormatDate(CurDateDT, 'NNN DD YYYY HH:II:SS'));
  WriteLn;

  Str := strUpper(strStripB(ParamStr(1), ' '));

  If strUpper(ParamStr(2)) = 'EXPORT' Then
    Mode := 1
  Else
  If strUpper(ParamStr(2)) = 'IMPORT' Then
    Mode := 2
  Else
    Mode := 0;

  If (Str = 'ALL') Then Begin
    Assign (F, bbsCfg.DataPath + 'qwknet.dat');

    If ioReset (F, SizeOf(RecQwkNetwork), fmRWDN) Then Begin
      While Not Eof(F) Do Begin
        ioRead (F, QwkNet);

        Case Mode of
          0 : If PollByQwkNet(QwkNet) Then
                Inc (Count);
        End;
      End;

      Close (F);
    End;
  End Else
  If strS2I(Str) > 0 Then Begin
    If GetQwkNetByIndex(strS2I(Str), QwkNet) Then
      Case Mode of
        0 : If PollByQwkNet(QwkNet) Then
              Inc (Count);
      End;
  End Else Begin
    WriteLn ('Invalid command line.');
    WriteLn;
    WriteLn ('Syntax: QWKPOLL [ALL]');
    WriteLn ('                [Qwk Network Index]');
    WriteLn;
    WriteLn ('                [EXPORT] [QwkNet Index] [PATH TO CREATE REP]');
    WriteLn ('                [IMPORT] [QwkNet Index] [PATH OF QWK PACKET]');
    WriteLn;
    WriteLn ('Ex: QWKPOLL ALL                  - Exchange with ALL QWK hubs via FTP');
    WriteLn ('    QWKPOLL 1                    - Exchange with only Qwk Network #1');
    WriteLn ('    QWKPOLL 1 EXPORT /bbs/qwknet - Create REP packet in /bbs/qwknet');
    WriteLn ('    QWKPOLL 1 IMPORT /bbs/qwknet - Import QWK packet from /bbs/qwknet');
    WriteLn;
    WriteLn ('NOTE: QWKPOLL automatically deals with QWK and REP packets during polling');
    WriteLn ('      The export and import functions are not needed, and only provided');
    WriteLn ('      for systems that may want to use an alternative transport method');
    WriteLn;
  End;

  WriteLn ('Processed ', Count, ' QWK networks');
End.

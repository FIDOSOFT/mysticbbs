Program FidoPoll;

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

Uses
  DOS,
  m_Crypt,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_IO_Sockets,
  m_Protocol_Queue,
  m_tcp_Client_FTP,
  BBS_Records,
  BBS_DataBase,
  MIS_Client_BINKP;

Var
  TempPath : String;

Procedure PrintStatus (Owner: Pointer; Level: Byte; Str: String);
Var
  TF : Text;
Begin
  If Level = 1 Then
    WriteLn (Str)
  Else
    Str := '   ' + Str;

  Str      := FormatDate(CurDateDT, 'NNN DD HH:II') + ' ' + Str;
  FileMode := 66;

  Assign (TF, bbsCfg.LogsPath + 'fidopoll.log');

  {$I-} Append (TF); {$I+}

  If (IoResult <> 0) and (IoResult <> 5) Then
    {$I-} ReWrite(TF); {$I+}

  If IoResult = 0 Then Begin
    WriteLn (TF, Str);
    Close   (TF);
  End;
End;

Function PollNodeFTP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  FTP : TFTPClient;

  Function ExistsOnServer (Str: String) : Boolean;
  Var
    Count : LongInt;
  Begin
    Result := False;

//    writeln ('debug checking exists ', str, '  files:', ftp.responsedata.count);

    For Count := 1 to FTP.ResponseData.Count Do Begin
//      writeln('debug    remote: ', FTP.ResponseData.Strings[Count - 1]);

      If strUpper(JustFile(Str)) = strUpper(FTP.ResponseData.Strings[Count - 1]) Then Begin
        Result := True;

        Break;
      End;
    End;
  End;

Var
  Count  : LongInt;
  OldFN  : String;
  NewFN  : String;
  IsDupe : Boolean;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus (NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus (NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus (NIL, 1, 'Polling FTP node ' + Addr2Str(EchoNode.Address));

  FTP := TFTPClient.Create(bbsCfg.iNetInterface);

  If FTP.OpenConnection(EchoNode.ftpOutHost) Then Begin
    PrintStatus (NIL, 1, 'Connected');

    If FTP.Authenticate(EchoNode.ftpOutLogin, EchoNode.ftpOutPass) Then Begin
      If FTP.GetDirectoryList(EchoNode.ftpPassive, True, EchoNode.ftpInDir) Then Begin
        For Count := 1 to FTP.ResponseData.Count Do Begin
          PrintStatus (NIL, 1, 'Receiving ' + FTP.ResponseData.Strings[Count - 1]);

          If FTP.GetFile (EchoNode.ftpPassive, bbsCfg.InboundPath + FTP.ResponseData.Strings[Count - 1]) = ftpResOK Then Begin
            If FTP.SendCommand('DELE ' + FTP.ResponseData.Strings[Count - 1]) <> 250 Then Begin
              PrintStatus (NIL, 1, 'Unable to delete from server ' + FTP.ResponseData.Strings[Count - 1]);
              FileErase(bbsCfg.InboundPath + FTP.ResponseData.Strings[Count - 1]);
            End;
          End Else
            PrintStatus (NIL, 1, 'Failed');
        End;
      End Else
        PrintStatus (NIL, 1, 'Unable to list ' + EchoNode.ftpInDir);

      If Queue.QSize > 0 Then Begin
        If FTP.GetDirectoryList(EchoNode.ftpPassive, True, EchoNode.ftpOutDir) Then Begin
          For Count := 1 to Queue.QSize Do Begin
            OldFN  := Queue.QData[Count]^.FileNew;
            NewFN  := OldFN;
            IsDupe := False;

            Repeat
              If ExistsOnServer(NewFN) Then Begin
                NewFN := GetFTNBundleExt(True, NewFN);

                If NewFN = OldFN Then Begin
                  IsDupe := True;

                  Break;
                End;
              End Else
                Break;
            Until False;

            If IsDupe Then
              PrintStatus (NIL, 1, 'Cannot send ' + OldFN + '; already exists')
            Else Begin
              PrintStatus (NIL, 1, 'Sending ' + OldFN + ' as ' + NewFN);

              If FTP.SendFile(EchoNode.ftpPassive, Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName, NewFN) = ftpResOK Then Begin
                // only remove by markings... or move to removefilesfromflo
                FileErase          (Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName);
                RemoveFilesFromFLO (GetFTNOutPath(EchoNode), TempPath, Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName);
              End Else
                PrintStatus (NIL, 1, 'Failed');
            End;
          End;
        End Else
          PrintStatus (NIL, 1, 'Unable to list ' + EchoNode.ftpOutDir);
      End;
    End Else
      PrintStatus (NIL, 1, 'Unable to authenticate');
  End Else
    PrintStatus (NIL, 1, 'Unable to connect');

  PrintStatus (NIL, 1, 'Session complete');

  FTP.Free;
End;

Function PollNodeDirectory (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  Count   : LongInt;
  DirInfo : SearchRec;
  PKTName : String;
  NewName : String;
  OutPath : String;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus (NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, False, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling DIRECTORY node ' + Addr2Str(EchoNode.Address));

  OutPath := GetFTNOutPath(EchoNode);

  For Count := 1 to Queue.QSize Do Begin
    PKTName := Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName;
    NewName := GetFTNBundleExt(False, EchoNode.DirInDir + Queue.QData[Count]^.FileNew);

    PrintStatus (NIL, 1, 'Move ' + PKTName + ' to ' + NewName);

    If (Not FileExist(NewName)) And FileReName(PKTName, NewName) Then
      RemoveFilesFromFLO (OutPath, TempPath, PKTName)
    Else
      PrintStatus (NIL, 1, 'Failed to move to ' + NewName);
  End;

  FindFirst (EchoNode.DirOutDir + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory = 0 Then Begin
      PrintStatus (NIL, 1, 'Move ' + EchoNode.DirOutDir + DirInfo.Name + ' to ' + bbsCfg.InboundPath);

      If (Not FileExist(bbsCfg.InboundPath + DirInfo.Name)) and (Not FileReName(EchoNode.DirOutDir + DirInfo.Name, bbsCfg.InboundPath + DirInfo.Name)) Then
        PrintStatus (NIL, 1, 'Failed to move to ' + EchoNode.DirOutDir + DirInfo.Name);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Function PollNodeBINKP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  BinkP  : TBinkP;
  Client : TIOSocket;
  Port   : Word;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus(NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling BINKP node ' + Addr2Str(EchoNode.Address));

  Client := TIOSocket.Create;

  Client.FTelnetClient := False;
  Client.FTelnetServer := False;

  PrintStatus (NIL, 1, 'Connecting to ' + EchoNode.binkHost);

  Port := strS2I(strWordGet(2, EchoNode.binkHost, ':'));

  If Port = 0 Then Port := 24554;

  If Not Client.Connect (strWordGet(1, EchoNode.binkHost, ':'), Port) Then Begin
    PrintStatus (NIL, 1, 'UNABLE TO CONNECT');

    Client.Free;

    Exit;
  End;

  PrintStatus(NIL, 1, 'Connected');

  BinkP := TBinkP.Create(Client, Client, Queue, True, EchoNode.binkTimeOut * 100);

  BinkP.StatusUpdate := @PrintStatus;
  BinkP.SetOutPath   := GetFTNOutPath(EchoNode);
  BinkP.SetPassword  := EchoNode.binkPass;
  BinkP.SetBlockSize := EchoNode.binkBlock;
  BinkP.UseMD5       := EchoNode.binkMD5 > 0;
  BinkP.ForceMD5     := EchoNode.binkMD5 = 2;

  If BinkP.DoAuthentication Then Begin
    Result := True;

    BinkP.DoTransfers;
  End;

  BinkP.Free;
  Client.Free;
End;

Function PollByAddress (Addr: String) : Boolean;
Var
  Queue    : TProtocolQueue;
  PollTime : LongInt;
  EchoNode : RecEchoMailNode;
Begin
  PollTime := CurDateDos;
  Queue    := TProtocolQueue.Create;

  Result := GetNodeByAddress(Addr, EchoNode);

  If Result And EchoNode.Active Then Begin
    Case EchoNode.ProtType of
      0 : If PollNodeBINKP(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
      1 : If PollNodeFTP(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
      2 : If PollNodeDirectory(False, Queue, EchoNode) Then
            EchoNode.LastSent := PollTime;
    End;

    // needs to save updated polltime
  End Else
    Result := False;

  Queue.Free;
End;

Procedure PollAll (OnlyNew: Boolean);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
  PollTime : LongInt;
Begin
  PollTime := CurDateDos;

  WriteLn ('Polling nodes...');
  WriteLn;

  Total := 0;
  Queue := TProtocolQueue.Create;

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If EchoNode.Active Then Begin
      Case EchoNode.ProtType of
        0 : If PollNodeBINKP(OnlyNew, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
        1 : If PollNodeFTP(OnlyNew, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
        2 : If PollNodeDirectory(False, Queue, EchoNode) Then
              EchoNode.LastSent := PollTime;
      End;

      Seek  (EchoFile, FilePos(EchoFile) - 1);
      Write (EchoFile, EchoNode);
    End;
  End;

  Close (EchoFile);

  Queue.Free;

  WriteLn;
  PrintStatus (NIL, 1, 'Polled ' + strI2S(Total) + ' nodes');
End;

Var
  Str : String;
Begin
  FileMode := 66;

  WriteLn;
  WriteLn ('FIDOPOLL Version ' + mysVersion);
  WriteLn;

  Case bbsCfgStatus of
    CfgNotFound : Begin
                    WriteLn ('Unable to read MYSTIC.DAT');
                    Halt(1);
                  End;
    CfgMisMatch : Begin
                    WriteLn ('Mystic VERSION mismatch');
                    Halt(1);
                  End;
  End;

  If ParamCount = 0 Then Begin
    WriteLn ('This program will send and retreive echomail packets for configured');
    WriteLn ('echomail nodes using any of BINKP, FTP, or Directory-based transmission');
    WriteLn;
    WriteLn ('FIDOPOLL SEND      - Only send/poll if node has new outbound messages');
    WriteLn ('FIDOPOLL FORCED    - Poll/send to all configured/activenodes');
    WriteLn ('FIDOPOLL [Address] - Poll/send echomail node [Address] (ex: 46:1/100)');

    Halt(1);
  End;

  TempPath := bbsCfg.SystemPath + 'tempftn' + PathChar;

  DirCreate(TempPath);

  Str := strUpper(strStripB(ParamStr(1), ' '));

  If (Str = 'SEND') or (Str = 'FORCED') Then
    PollAll (Str = 'SEND')
  Else
  If Not PollByAddress(Str) Then
    PrintStatus (NIL, 1, 'Invalid command line or address');
End.

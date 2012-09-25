// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
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

Program MystPack;

{ when DELETEing a message, the pointers are one less than they should be }
{ should be fixed, but may cause other problems. commented out the last }
{ read updating in the msgkill part of the program }

{ also when a user is reading a base, it could cause MP to crash with an }
{ RTE 005: access violation error }

{$I M_OPS.PAS}

Uses
  m_FileIO,
  m_Strings,
  m_DateTime,
  CRT,
  DOS;

{$I RECORDS.PAS}

Const
  PackVer       = '1.2';
  Jam_Deleted   = $80000000;
  JamSubBufSize = 4096;

Type
  JamSubBuffer = Array[1..JamSubBufSize] of Char;

  JamHdrType = Record
    Signature     : Array[1..4] of Char;
    Created       : LongInt;
    ModCounter    : LongInt;
    ActiveMsgs    : LongInt;
    PwdCRC        : LongInt;
    BaseMsgNum    : LongInt;
    HighWaterMark : Longint;
    Extra         : Array[1..996] of Char;
  End;

  JamMsgHdrType = Record
    Signature   : Array[1..4] of Char;
    Rev         : Word;
    Resvd       : Word;
    SubFieldLen : LongInt;
    TimesRead   : LongInt;
    MsgIdCrc    : LongInt;
    ReplyCrc    : LongInt;
    ReplyTo     : LongInt;
    ReplyFirst  : LongInt;
    ReplyNext   : LongInt;
    DateWritten : LongInt;
    DateRcvd    : LongInt;
    DateArrived : LongInt;
    MsgNumber   : LongInt;
    Attr1       : LongInt;
    Attr2       : LongInt;
    TextOfs     : LongInt;
    TextLen     : LongInt;
    PwdCrc      : LongInt;
    Cost        : LongInt;
  End;

  JamIdxType = Record
    MsgToCrc : LongInt;
    HdrLoc   : LongInt;
  End;

  JamLastType = Record
    NameCrc  : LongInt;
    UserNum  : LongInt;
    LastRead : LongInt;
    HighRead : LongInt;
  End;

  SubFieldType = Record
    LoId    : Word;
    HiId    : Word;
    DataLen : LongInt;
    Data    : Array[1..1000] of Char;
  End;

  TxtType = Array[1..65000] of Char;

  JamType = Record
    Hdr      : JamHdrType;
    MsgHdr   : JamMsgHdrType;
    HdrFile  : File;
    Idx      : JamIdxType;
    IdxFile  : File of JamIdxType;
    Last     : JamLastType;
    LastFile : File of JamLastType;
    TxtFile  : File;
    SubField : SubFieldType;
  End;

Const
  SpinStr   : String[8] = ('\|/-\|/-');
  SpinPos   : Byte = 1;
  SkipFirst : Boolean = False;
  PackMsgs  : Boolean = False;

Var
  ConfigFile : File of RecConfig;
  MBaseFile  : File of RecMessageBase;
  Config     : RecConfig;
  MBase      : RecMessageBase;

Const
  DATEC1970 = 2440588;
  DATED0    =    1461;
  DATED1    =  146097;
  DATED2    = 1721119;

Procedure UnixToDT(SecsPast: LongInt; Var Dt: DateTime);
Var
  DateNum : LongInt;
  N1      : Word;
Begin
  Datenum := (SecsPast Div 86400) + DATEc1970;

  DateJ2G(DateNum, SmallInt(N1), SmallInt(DT.Month), SmallInt(DT.day));
  DT.Year := N1;

  SecsPast := SecsPast Mod 86400;
  DT.Hour  := SecsPast Div 3600;
  SecsPast := SecsPast Mod 3600;
  DT.Min   := SecsPast Div 60;
  DT.Sec   := SecsPast Mod 60;
End;

Procedure PWrite (Str : String);
Var
  A    : Byte;
  Code : String[2];
Begin
  A := 1;
  While A <= Length(Str) Do Begin
    If (Str[A] = '|') and (A < Length(Str) - 1) Then Begin
      Code := Copy(Str, A + 1, 2);

      If (Code = '00') or (strS2I(Code) > 0) Then Begin
        If strS2I(Code) < 16 Then
          TextColor(strS2I(Code))
        Else
          TextBackground(strS2I(Code) - 16);
      End Else
        Write(Str[A] + Code);

      Inc (A, 2);
    End Else
      Write(Str[A]);

      Inc(A);
  End;
End;

Procedure PWriteLN (Str : String);
Begin
  PWrite (Str + #13#10);
End;

Procedure UpdateSpin;
Begin
  Write (#8 + SpinStr[SpinPos]);
  Inc (SpinPos);

  If SpinPos > 8 Then SpinPos := 1;
End;

Procedure PackJAMBase (Var TotalKilled : LongInt; Var SavedBytes : LongInt);
Var
  BasePath    : String;
  OldHdrFile  : File;
  OldTxtFile  : File;
  OldIdxFile  : File of JamIdxType;
  NewHdrFile  : File;
  NewTxtFile  : File;
  NewIdxFile  : File of JamIdxType;
  TmpHdrFile  : File;
  LastFile    : File of JamLastType;
  Last        : JamLastType;
  SigHdr      : JamHdrType;
  MsgHdr      : JamMsgHdrType;
  TmpSigHdr   : JamHdrType;
  TmpMsgHdr   : JamMsgHdrType;
  MsgIdx      : JamIdxType;
  TxtBuf      : ^TxtType;
  SubField    : SubFieldType;
  Count       : LongInt;
  Killed      : Boolean;
  KillOffset  : LongInt;
  LimitKill   : Boolean;
  TotalMsgs   : LongInt;
  MsgDateTime : DateTime;
  Temp        : LongInt;
  HaveHdr     : Boolean;
Begin
  PWrite ('|07Processing |08-> |07' + strPadR(MBase.Name, 35, ' ') + '|08 ->  |07');

  BasePath := MBase.Path + MBase.FileName;

  Assign (OldHdrFile, BasePath + '.jhr');
  Assign (OldTxtFile, BasePath + '.jdt');
  Assign (OldIdxFile, BasePath + '.jdx');

  {$I-} Reset (OldHdrFile, 1); {$I+}
  If IOResult <> 0 Then Exit;

  {$I-} Reset (OldTxtFile, 1); {$I+}
  If IOResult <> 0 Then Begin
    Close (OldHdrFile);
    Exit;
  End;

  {$I-} Reset (OldIdxFile); {$I+}
  If IoResult <> 0 Then Begin
    Close (OldHdrFile);
    Close (OldTxtFile);
    Exit;
  End;

  Assign  (LastFile, BasePath + '.jlr');
  {$I-} Reset (LastFile); {$I+}
  If IoResult <> 0 Then ReWrite (LastFile);
  Close (LastFile);

  Assign  (NewHdrFile, BasePath + '._hr');
  ReWrite (NewHdrFile, 1);
  Assign  (NewTxtFile, BasePath + '._dt');
  ReWrite (NewTxtFile, 1);
  Assign  (NewIdxFile, BasePath + '._dx');
  ReWrite (NewIdxFile);

  BlockRead (OldHdrFile, SigHdr, SizeOf(SigHdr));

  Inc (SigHdr.ModCounter);

  BlockWrite (NewHdrFile, SigHdr, SizeOf(SigHdr));

  If SigHdr.ActiveMsgs > MBase.MaxMsgs Then
    KillOffset := SigHdr.ActiveMsgs - MBase.MaxMsgs
  Else
    KillOffset := 0;

  TotalMsgs   := 0;
  TotalKilled := 0;

  New (TxtBuf);

  While Not Eof(OldIdxFile) Do Begin
    UpdateSpin;

    Read (OldIdxFile, MsgIdx);

    If MsgIdx.HdrLoc = -1 Then Begin
      Killed    := True;
      LimitKill := False;
      HaveHdr   := False;
    End Else Begin
      Seek (OldHdrFile, MsgIdx.HdrLoc);

      BlockRead (OldHdrFile, MsgHdr, SizeOf(MsgHdr));

      LimitKill := False;
      Killed    := MsgHdr.Attr1 and Jam_Deleted <> 0;
      HaveHdr   := True;

      If MBase.MaxAge > 0 Then Begin
        UnixToDT (MsgHdr.DateWritten, MsgDateTime);
        PackTime (MsgDateTime, Temp);

        LimitKill := DaysAgo(Temp, 2) > MBase.MaxAge;
        Killed    := Killed or LimitKill;
      End;

      If MBase.MaxMsgs > 0 Then
        If KillOffset > 0 Then Begin
          Dec (KillOffset);
          LimitKill := True;
          Killed    := True;
        End;

      If SkipFirst and (MBase.NetType = 0) and (TotalMsgs = 0) and (MsgHdr.Attr1 and Jam_Deleted = 0) Then
        Killed := False;
    End;

    If Killed Then Begin
      Inc (TotalKilled);

(*
      Reset (LastFile);
      While Not Eof(LastFile) Do Begin
        Read (LastFile, Last);
        If (Last.LastRead > TotalMsgs) And Not LimitKill Then Begin
          Dec   (Last.LastRead);
          Seek  (LastFile, FilePos(LastFile) - 1);
          Write (LastFile, Last);
        End;
      End;
      Close (LastFile);
*)
      If HaveHdr And (MsgHdr.ReplyFirst <> 0) Then Begin
        Assign (TmpHdrFile, BasePath + '.jhr');
        Reset  (TmpHdrFile, 1);

        BlockRead (TmpHdrFile, TmpSigHdr, SizeOf(TmpSigHdr));

        While Not Eof(TmpHdrFile) Do Begin
          BlockRead (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));

          If TmpMsgHdr.ReplyTo = MsgHdr.MsgNumber Then Begin
            TmpMsgHdr.ReplyTo := 0;
            Seek (TmpHdrFile, FilePos(TmpHdrFile) - SizeOf(TmpMsgHdr));
            BlockWrite (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));
          End;

          Seek (TmpHdrFile, FilePos(TmpHdrFile) + TmpMsgHdr.SubFieldLen);
        End;
        Close (TmpHdrFile);
      End;

    End Else Begin
      Inc (TotalMsgs);

      If TotalKilled > 0 Then Begin
        Reset (LastFile);
        While Not Eof(LastFile) Do Begin
          Read (LastFile, Last);
          If Last.LastRead = MsgHdr.MsgNumber Then Begin
            Last.LastRead := TotalMsgs;
            Seek  (LastFile, FilePos(LastFile) - 1);
            Write (LastFile, Last);
          End;
        End;
        Close (LastFile);
      End;

      If (TotalKilled > 0) and (MsgHdr.ReplyFirst <> 0) Then Begin
        Assign (TmpHdrFile, BasePath + '.jhr');
        Reset  (TmpHdrFile, 1);

        BlockRead (TmpHdrFile, TmpSigHdr, SizeOf(TmpSigHdr));

        While Not Eof(TmpHdrFile) Do Begin
          BlockRead (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));

          If TmpMsgHdr.ReplyTo = MsgHdr.MsgNumber Then Begin
            TmpMsgHdr.ReplyTo := TotalMsgs;
            Seek (TmpHdrFile, FilePos(TmpHdrFile) - SizeOf(TmpMsgHdr));
            BlockWrite (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));
          End;

          Seek (TmpHdrFile, FilePos(TmpHdrFile) + TmpMsgHdr.SubFieldLen);
        End;
        Close (TmpHdrFile);
      End;

      If (TotalKilled > 0) and (MsgHdr.ReplyTo <> 0) Then Begin
        Assign (TmpHdrFile, BasePath + '._hr');
        Reset  (TmpHdrFile, 1);

        BlockRead (TmpHdrFile, TmpSigHdr, SizeOf(TmpSigHdr));

        While Not Eof(TmpHdrFile) Do Begin
          BlockRead (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));

          If TmpMsgHdr.ReplyFirst = MsgHdr.MsgNumber Then Begin
            TmpMsgHdr.ReplyFirst := TotalMsgs;
            Seek (TmpHdrFile, FilePos(TmpHdrFile) - SizeOf(TmpMsgHdr));
            BlockWrite (TmpHdrFile, TmpMsgHdr, SizeOf(TmpMsgHdr));
          End;

          Seek (TmpHdrFile, FilePos(TmpHdrFile) + TmpMsgHdr.SubFieldLen);
        End;
        Close (TmpHdrFile);
      End;

      MsgHdr.MsgNumber := TotalMsgs;
      MsgIdx.HdrLoc    := FilePos(NewHdrFile);

      (* write text from old file to new file *)

      If MsgHdr.TextLen > 65000 Then MsgHdr.TextLen := 65000;
      // Why did I put this limitation here?  Prob should be removed
      // need to be tested.

      Seek       (OldTxtFile, MsgHdr.TextOfs);
      BlockRead  (OldTxtFile, TxtBuf^, MsgHdr.TextLen);

      MsgHdr.TextOfs := FileSize(NewTxtFile);

      BlockWrite (NewTxtFile, TxtBuf^, MsgHdr.TextLen);

      (* write header from old to new file *)

      BlockWrite (NewHdrFile, MsgHdr, SizeOf(MsgHdr));

      (* write subfield data if it exists *)

      If MsgHdr.SubFieldLen > 0 Then Begin
        Count := 1;

        While (Count <= MsgHdr.SubFieldLen) Do Begin
          BlockRead  (OldHdrFile, SubField, 8);
          BlockRead  (OldHdrFile, SubField.Data, SubField.DataLen);
          BlockWrite (NewHdrFile, SubField, 8);
          BlockWrite (NewHdrFile, SubField.Data, SubField.DataLen);

          Inc (Count, 8 + SubField.DataLen);
        End;
      End;

      (* write new index to index file *)

      Write (NewIdxFile, MsgIdx);
    End;
  End;

  Dispose (TxtBuf);

  SigHdr.ActiveMsgs := TotalMsgs;
  SigHdr.BaseMsgNum := 1;

  Reset (NewHdrFile, 1);
  BlockWrite (NewHdrFile, SigHdr, SizeOf(SigHdr));

  SavedBytes := (FileSize(OldHdrFile) - FileSize(NewHdrFile)) +
                (FileSize(OldTxtFile) - FileSize(NewTxtFile)) +
                ((FileSize(OldIdxFile) - FileSize(NewIdxFile)) * SizeOf(MsgIdx));

  Close (OldHdrFile);
  Close (OldTxtFile);
  Close (OldIdxFile);
  Close (NewHdrFile);
  Close (NewTxtFile);
  Close (NewIdxFile);

  Erase (OldHdrFile);
  Erase (OldTxtFile);
  Erase (OldIdxFile);

  ReName (NewHdrFile, BasePath + '.jhr');
  ReName (NewTxtFile, BasePath + '.jdt');
  ReName (NewIdxFile, BasePath + '.jdx');

  If TotalKilled > 0 Then Begin
    Reset (LastFile);
    While Not Eof(LastFile) Do Begin
      Read (LastFile, Last);
      If Last.LastRead > TotalMsgs Then Last.LastRead := TotalMsgs;
      If Last.HighRead > Last.LastRead Then Last.HighRead := Last.LastRead;
      Seek (LastFile, FilePos(LastFile) - 1);
      Write (LastFile, Last);
    End;
    Close (LastFile);
  End;
End;

Procedure ShowHelp;
Begin
  WriteLn ('Invalid command line options');
  WriteLn;
  WriteLn ('-PACK      : Pack all jam message bases');
  WriteLn ('-SKIPFIRST : Skips the first message of each local message base');
  WriteLn;
  PWriteLn ('|12NOTE: This program can sometimes crash if users are online.|07');
  Halt(1);
End;

Var
  TotalMsgs  : LongInt;
  TotalBytes : LongInt;
  Msgs       : LongInt;
  Bytes      : LongInt;
  Count      : Byte;
  Str        : String;
Begin
  FileMode := 66;

  ClrScr;
  PWriteLn ('|08-> |15MYSTPACK ' + PackVer + ' : JAM message base packer');
  PWriteLn ('|08-> |07Compatible with Mystic BBS software v' + mysVersion);
  PWriteLn ('|08컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�|07');
  WriteLn;

  Window (1, 5, 80, 24);

  If ParamCount = 0 Then ShowHelp;

  For Count := 1 to ParamCount Do Begin
    Str := strUpper(ParamStr(Count));

    If Str = '-PACK' Then
      PackMsgs := True
    Else
    If Str = '-SKIPFIRST' Then
      SkipFirst := True
    Else
      ShowHelp;
  End;

  Assign (ConfigFile, 'mystic.dat');
  {$I-} Reset (ConfigFile); {$I+}
  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to read MYSTIC.DAT.  Run from root Mystic directory');
    Halt(1);
  End;
  Read (ConfigFile, Config);
  Close (ConfigFile);

  If Config.DataChanged <> mysDataChanged Then Begin
    WriteLn('ERROR: Data files are not current and must be upgraded.');
    Halt(1);
  End;

  Assign (MBaseFile, Config.DataPath + 'mbases.dat');
  {$I-} Reset(MBaseFile); {$I+}
  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to read message area data');
    Halt(1);
  End;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    If MBase.BaseType = 0 Then Begin
      PackJAMBase(Msgs, Bytes);
      WriteLn (#8 + 'Killed ', Msgs, '; ', Bytes, ' bytes');

      Inc (TotalMsgs, Msgs);
      Inc (TotalBytes, Bytes);
    End;
  End;

  Close (MBaseFile);

  WriteLn;
  PWriteLn ('|08[|07-|08] |07Killed |15' + strI2S(TotalMsgs) + '|07 Msgs; Removed |15' + strI2S(TotalBytes) + '|07 bytes');

  Window (1, 1, 80, 25);
End.

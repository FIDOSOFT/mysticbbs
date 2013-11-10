{$I M_OPS.PAS}

// things to do:
// 2. make readmsgtext read directly into msgtext record?
// 3. make squish use temporary buffer file
// 4. remove all mkcrap stuff... basically rewrite everything 1 by 1

Unit BBS_MsgBase_JAM;

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

Interface

Uses
  m_Strings,
  BBS_Records,
  BBS_MsgBase_ABS;

Const
  JamIdxBufSize = 200;
  JamSubBufSize = 4000;
  JamTxtBufSize = 4000;
  TxtSubBufSize = 2000;

  Jam_Local =        $00000001;
  Jam_InTransit =    $00000002;
  Jam_Priv =         $00000004;
  Jam_Rcvd =         $00000008;
  Jam_Sent =         $00000010;
  Jam_KillSent =     $00000020;
  Jam_AchvSent =     $00000040;
  Jam_Hold =         $00000080;
  Jam_Crash =        $00000100;
  Jam_Imm =          $00000200;
  Jam_Direct =       $00000400;
  Jam_Gate =         $00000800;
  Jam_Freq =         $00001000;
  Jam_FAttch =       $00002000;
  Jam_TruncFile =    $00004000;
  Jam_KillFile =     $00008000;
  Jam_RcptReq =      $00010000;
  Jam_ConfmReq =     $00020000;
  Jam_Orphan =       $00040000;
  Jam_Encrypt =      $00080000;
  Jam_Compress =     $00100000;
  Jam_Escaped =      $00200000;
  Jam_FPU =          $00400000;
  Jam_TypeLocal =    $00800000;
  Jam_TypeEcho =     $01000000;
  Jam_TypeNet =      $02000000;
  Jam_NoDisp =       $20000000;
  Jam_Locked =       $40000000;
  Jam_Deleted =      $80000000;

Type
  JamHdrType = Record
    Signature  : Array[1..4] of Char;
    Created    : LongInt;
    ModCounter : LongInt;
    ActiveMsgs : LongInt;
    PwdCRC     : LongInt;
    BaseMsgNum : LongInt;
    Extra      : Array[1..1000] of Char;
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
    MsgNum      : LongInt;
    Attr1       : Cardinal;
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

  JamIdxArrayType = Array[0..JamIdxBufSize] of JamIdxType;
  JamSubBuffer    = Array[1..JamSubBufSize] of Char;
  JamTxtBufType   = Array[0..JamTxtBufSize] Of Char;

  HdrType = Record
    JamHdr : JamMsgHdrType;
    SubBuf : JamSubBuffer;
  End;

  JamMsgType = Record
    HdrFile     : File;
    TxtFile     : File;
    IdxFile     : File;
    MsgPath     : String[128];
    BaseHdr     : JamHdrType;
    Dest        : RecEchoMailAddr;
    Orig        : RecEchoMailAddr;
    MsgFrom     : String[65];
    MsgTo       : String[65];
    MsgSubj     : String[100];
    MsgDate     : String[8];
    MsgTime     : String[5];
    CurrMsgNum  : LongInt;
    YourName    : String[35];
    YourHdl     : String[35];
    NameCrc     : LongInt;
    HdlCrc      : LongInt;
    TxtPos      : LongInt;
    TxtEnd      : LongInt;
    TxtBufStart : LongInt;
    TxtRead     : Word;
    IdxRead     : Word;
    MailType    : MsgMailType;
    BufFile     : File;
    LockCount   : LongInt;
    IdxStart    : LongInt;
    TxtSubBuf   : Array[0..TxtSubBufSize] of Char;
    TxtSubChars : Integer;
  End;

  PMsgBaseJAM = ^TMsgBaseJAM;
  TMsgBaseJAM = Object(TMsgBaseABS)
    JM     : ^JamMsgType;
    MsgHdr : ^HdrType;
    JamIdx : ^JamIdxArrayType;
    TxtBuf : ^JamTxtBufType;
    Error  : Word;

    Procedure   EditMsgInit; Virtual;
    Procedure   EditMsgSave; Virtual;
    Constructor Init;
    Destructor  Done; Virtual;
    Procedure   SetMsgPath     (St: String); Virtual; {Set netmail path}
    Function    GetHighMsgNum  : LongInt; Virtual; {Get highest netmail msg number in area}
    Function    LockMsgBase    : Boolean; Virtual; {Lock the message base}
    Function    UnLockMsgBase  : Boolean; Virtual; {Unlock the message base}
    Procedure   SetDest        (Addr: RecEchoMailAddr); Virtual; {Set Zone/Net/Node/Point for Dest}
    Procedure   SetOrig        (Addr: RecEchoMailAddr); Virtual; {Set Zone/Net/Node/Point for Orig}
    Procedure   SetFrom        (Name: String); Virtual; {Set message from}
    Procedure   SetTo          (Name: String); Virtual; {Set message to}
    Procedure   SetSubj        (Str: String); Virtual; {Set message subject}
    Procedure   SetCost        (SCost: Word); Virtual; {Set message cost}
    Procedure   SetRefer       (SRefer: LongInt); Virtual; {Set message reference}
    Procedure   SetSeeAlso     (SAlso: LongInt); Virtual; {Set message see also}
    Function    GetNextSeeAlso : LongInt; Virtual;
    Procedure   SetNextSeeAlso (SAlso: LongInt); Virtual;
    Procedure   SetDate        (SDate: String); Virtual; {Set message date}
    Procedure   SetTime        (STime: String); Virtual; {Set message time}
    Procedure   SetLocal       (LS: Boolean); Virtual; {Set local status}
    Procedure   SetRcvd        (RS: Boolean); Virtual; {Set received status}
    Procedure   SetPriv        (PS: Boolean); Virtual; {Set priveledge vs public status}
    Procedure   SetHold        (SS: Boolean); Virtual; {set hold netmail status}
    Procedure   SetCrash       (SS: Boolean); Virtual; {Set crash netmail status}
    Procedure   SetKillSent    (SS: Boolean); Virtual; {Set kill/sent netmail status}
    Procedure   SetSent        (SS: Boolean); Virtual; {Set sent netmail status}
    Procedure   SetFAttach     (SS: Boolean); Virtual; {Set file attach status}
    Procedure   SetReqRct      (SS: Boolean); Virtual; {Set request receipt status}
    Procedure   SetReqAud      (SS: Boolean); Virtual; {Set request audit status}
    Procedure   SetRetRct      (SS: Boolean); Virtual; {Set return receipt status}
    Procedure   SetFileReq     (SS: Boolean); Virtual; {Set file request status}
    Procedure   DoString       (Str: String); Virtual; {Add string to message text}
    Procedure   DoChar         (Ch: Char); Virtual; {Add character to message text}
    Procedure   DoStringLn     (Str: String); Virtual; {Add string and newline to msg text}
    Procedure   DoKludgeLn     (Str: String); Virtual; {Add ^AKludge line to msg}
    Function    WriteMsg       : Word; Virtual;
    Function    GetChar        : Char; Virtual;
    Procedure   MsgStartUp;    Virtual; {set up msg for reading}
    Function    EOM            : Boolean; Virtual; {No more msg text}
    Function    GetString      (MaxLen: Word): String; Virtual; {Get wordwrapped string}
    Procedure   SeekFirst      (MsgNum: LongInt); Virtual; {Seek msg number}
    Procedure   SeekNext;      Virtual; {Find next matching msg}
    Procedure   SeekPrior;     Virtual; {Seek prior matching msg}
    Function    GetFrom        : String; Virtual; {Get from name on current msg}
    Function    GetTo          : String; Virtual; {Get to name on current msg}
    Function    GetSubj        : String; Virtual; {Get subject on current msg}
//    Function    GetCost        : Word; Virtual; {Get cost of current msg}
    Function    GetDate        : String; Virtual; {Get date of current msg}
    Function    GetTime        : String; Virtual; {Get time of current msg}
    Function    GetRefer       : LongInt; Virtual; {Get reply to of current msg}
    Function    GetSeeAlso     : LongInt; Virtual; {Get see also of current msg}
    Function    GetMsgNum      : LongInt; Virtual; {Get message number}
    Procedure   GetOrig        (Var Addr: RecEchoMailAddr); Virtual; {Get origin address}

    Function GetOrigAddr : RecEchoMailAddr; Virtual;
    Function GetDestAddr : RecEchoMailAddr; Virtual;

    Procedure   GetDest        (Var Addr: RecEchoMailAddr); Virtual; {Get destination address}
    Function    GetTextLen     : LongInt; Virtual; {returns length of text in msg}
    Function    IsLocal        : Boolean; Virtual; {Is current msg local}
    Function    IsCrash        : Boolean; Virtual; {Is current msg crash}
    Function    IsKillSent     : Boolean; Virtual; {Is current msg kill sent}
    Function    IsSent         : Boolean; Virtual; {Is current msg sent}
    Function    IsFAttach      : Boolean; Virtual; {Is current msg file attach}
//    Function  IsReqRct: Boolean; Virtual; {Is current msg request receipt}
//    Function  IsReqAud: Boolean; Virtual; {Is current msg request audit}
//    Function  IsRetRct: Boolean; Virtual; {Is current msg a return receipt}
    Function    IsFileReq      : Boolean; Virtual; {Is current msg a file request}
    Function    IsRcvd         : Boolean; Virtual; {Is current msg received}
    Function    IsPriv         : Boolean; Virtual; {Is current msg priviledged/private}
    Function    IsDeleted      : Boolean; Virtual; {Is current msg deleted}
//    Function    IsEchoed       : Boolean; Virtual; {Msg should be echoed}
    Function    GetMsgLoc      : LongInt; Virtual; {Msg location}
    Procedure   SetMsgLoc      (ML: LongInt); Virtual; {Msg location}
//    Procedure   YoursFirst     (Name: String; Handle: String); Virtual; {Seek your mail}
//    Procedure   YoursNext;     Virtual; {Seek next your mail}
//    Function    YoursFound     : Boolean; Virtual; {Message found}
    Procedure   StartNewMsg;   Virtual;
    Function    OpenMsgBase    : Boolean; Virtual;
    Procedure   CloseMsgBase;  Virtual;
//    Function    MsgBaseExists  : Boolean; Virtual; {Does msg base exist}
    Function    CreateMsgBase  (MaxMsg: Word; MaxDays: Word): Boolean; Virtual;
    Function    SeekFound      : Boolean; Virtual;
    Procedure   SetMailType    (MT: MsgMailType); Virtual; {Set message base type}
//    Function    GetSubArea     : Word; Virtual; {Get sub area number}
    Procedure   ReWriteHdr;    Virtual; {Rewrite msg header after changes}
    Procedure   DeleteMsg;     Virtual; {Delete current message}
    Function    NumberOfMsgs   : LongInt; Virtual; {Number of messages}
    Function    GetLastRead    (UNum: LongInt): LongInt; Virtual; {Get last read for user num}
    Procedure   SetLastRead    (UNum: LongInt; LR: LongInt); Virtual; {Set last read}
    Procedure   MsgTxtStartUp; Virtual; {Do message text start up tasks}
    Function    GetTxtPos      : LongInt; Virtual; {Get indicator of msg text position}
    Procedure   SetTxtPos      (TP: LongInt); Virtual; {Set text position}
    Procedure   SetAttr1       (Mask: Cardinal; St: Boolean); {Set attribute 1}
    Function    ReadIdx        : Word;
    Function    WriteIdx       : Word;
    Procedure   AddSubField    (id: Word; Data: String);
    Function    FindLastRead   (Var LastFile: File; UNum: LongInt): LongInt;
    Function    ReReadIdx      (Var IdxLoc : LongInt) : Word;
  End;

Function JamStrCrc (St: String): LongInt;

Implementation

Uses
  DOS,
  m_CRC,
  m_FileIO,
  m_DateTime,
  BBS_DataBase,
  MKCRAP;

Type
  SubFieldPTR  = ^SubFieldType;
  SubFieldType = Record
    LoId    : Word;
    HiId    : Word;
    DataLen : LongInt;
    Data    : Array[1..1000] of Char;
  End;

Constructor TMsgBaseJAM.Init;
Begin
  New (JM);
  New (JamIdx);
  New (MsgHdr); { this new here messes everything up }
  New (TxtBuf);

  If ((JM = Nil) Or (JamIdx = Nil) or (MsgHdr = Nil) or (TxtBuf = Nil)) Then Begin
    If JM     <> Nil Then Dispose(JM);
    If JamIdx <> Nil Then Dispose(JamIdx);
    If MsgHdr <> Nil Then Dispose(MsgHdr);
    If TxtBuf <> Nil Then Dispose(TxtBuf);
    Fail;
    Exit;
  End Else Begin
    FillChar(JM^, SizeOf(JM^), #0);

    JM^.MsgPath  := '';
    JM^.IdxStart := -30;
    JM^.IdxRead  := 0;
    Error        := 0;
  End;
End;

Destructor TMsgBaseJAM.Done;
Begin
  If JM     <> Nil Then Dispose(JM);
  If JamIdx <> Nil Then Dispose(JamIdx);
  If MsgHdr <> Nil Then Dispose(MsgHdr);
  If TxtBuf <> Nil Then Dispose(TxtBuf);
End;

Function JamStrCrc (St: String): LongInt;
Var
  i: Word;
  crc: LongInt;
Begin
  Crc := -1;

  For i := 1 to Length(St) Do
    Crc := Crc32(Ord(LoCase(St[i])), Crc);

  JamStrCrc := Crc;
End;

Procedure TMsgBaseJAM.SetMsgPath (St: String);
Begin
  JM^.MsgPath := Copy(St, 1, 124);
End;

Function TMsgBaseJAM.GetHighMsgNum: LongInt;
Begin
  GetHighMsgNum := JM^.BaseHdr.BaseMsgNum + FileSize(JM^.IdxFile) - 1;
End;

Procedure TMsgBaseJAM.SetDest (Addr: RecEchoMailAddr);
Begin
  JM^.Dest := Addr;
End;

Procedure TMsgBaseJAM.SetOrig (Addr: RecEchoMailAddr);
Begin
  JM^.Orig := Addr;
End;

Procedure TMsgBaseJAM.SetFrom (Name: String);
Begin
  JM^.MsgFrom := Name;
End;

Procedure TMsgBaseJAM.SetTo (Name: String);
Begin
  JM^.MsgTo := Name;
End;

Procedure TMsgBaseJAM.SetSubj (Str: String);
Begin
  JM^.MsgSubj := Str;
End;

Procedure TMsgBaseJAM.SetCost (SCost: Word);
Begin
  MsgHdr^.JamHdr.Cost := SCost;
End;

Procedure TMsgBaseJAM.SetRefer (SRefer: LongInt);
Begin
  MsgHdr^.JamHdr.ReplyTo := SRefer;
End;

Procedure TMsgBaseJAM.SetSeeAlso (SAlso: LongInt);
Begin
  MsgHdr^.JamHdr.ReplyFirst := SAlso;
End;

Procedure TMsgBaseJAM.SetDate (SDate: String);
Begin
  JM^.MsgDate := SDate;
End;

Procedure TMsgBaseJAM.SetTime (STime: String);
Begin
  JM^.MsgTime := STime;
End;

Procedure TMsgBaseJAM.SetAttr1 (Mask: Cardinal; St: Boolean);
  Begin
  If St Then
    MsgHdr^.JamHdr.Attr1 := MsgHdr^.JamHdr.Attr1 Or Mask
  Else
    MsgHdr^.JamHdr.Attr1 := MsgHdr^.JamHdr.Attr1 And (Not Mask);
  End;

Procedure TMsgBaseJAM.SetLocal (LS: Boolean);
Begin
  SetAttr1(Jam_Local, LS);
End;

Procedure TMsgBaseJAM.SetRcvd (RS: Boolean);
Begin
  SetAttr1(Jam_Rcvd, RS);
End;

Procedure TMsgBaseJAM.SetPriv (PS: Boolean);
Begin
  SetAttr1(Jam_Priv, PS);
End;

Procedure TMsgBaseJAM.SetHold (SS: Boolean);
Begin
  SetAttr1 (Jam_Hold, SS);
End;

Procedure TMsgBaseJAM.SetCrash (SS: Boolean);
Begin
  SetAttr1(Jam_Crash, SS);
End;

Procedure TMsgBaseJAM.SetKillSent (SS: Boolean);
Begin
  SetAttr1(Jam_KillSent, SS);
End;

Procedure TMsgBaseJAM.SetSent (SS: Boolean);
Begin
  SetAttr1(Jam_Sent, SS);
End;

Procedure TMsgBaseJAM.SetFAttach (SS: Boolean);
Begin
  SetAttr1(Jam_FAttch, SS);
End;

Procedure TMsgBaseJAM.SetReqRct (SS: Boolean);
Begin
  SetAttr1(Jam_RcptReq, SS);
End;

Procedure TMsgBaseJAM.SetReqAud (SS: Boolean);
Begin
  SetAttr1(Jam_ConfmReq, SS);
End;

Procedure TMsgBaseJAM.SetRetRct (SS: Boolean);
Begin
End;

Procedure TMsgBaseJAM.SetFileReq (SS: Boolean);
Begin
  SetAttr1(Jam_Freq, SS);
End;


Procedure TMsgBaseJAM.DoString (Str: String);
Var
  i: Word;
Begin
  i := 1;
  While i <= Length(Str) Do Begin
    DoChar(Str[i]);
    Inc(i);
  End;
End;

Procedure TMsgBaseJAM.DoChar(Ch: Char);
Var
//  TmpStr: String;
  NumWrite: Word;
Begin
  Case ch of
    #13: LastSoft := False;
    #10:;
  Else
    LastSoft := True;
  End;
  If (JM^.TxtPos - JM^.TxtBufStart) >= JamTxtBufSize Then Begin
    If JM^.TxtBufStart = 0 Then Begin
//      GetDir(0, TmpStr);
//      TmpStr := GetTempName(TmpStr);
      Assign(JM^.BufFile, TempFile);
      FileMode := fmReadWrite + fmDenyNone;
      ReWrite(JM^.BufFile, 1);
    End;
    NumWrite := JM^.TxtPos - JM^.TxtBufStart;
    BlockWrite(JM^.BufFile, TxtBuf^, NumWrite);
    Error := IoResult;
    JM^.TxtBufStart := FileSize(JM^.BufFile);
  End;

  TxtBuf^[JM^.TxtPos - JM^.TxtBufStart] := Ch;

  Inc(JM^.TxtPos);
End;

Procedure TMsgBaseJAM.DoStringLn(Str: String);
Begin
  DoString(Str);
  DoChar(#13);
End;

Procedure TMsgBaseJAM.DoKludgeLn(Str: String);
Var
  TmpStr: String;

Begin
  If Str[1] = #1 Then
    Str := Copy(Str,2,255);

  If Copy(Str,1,3) = 'PID' Then Begin
    TmpStr := strStripL(Copy(Str,4,255),':');
    TmpStr := Copy(strStripB(TmpStr, ' '),1,40);
    AddSubField(7, TmpStr);
  End Else
  If Copy(Str,1,5) = 'MSGID' Then Begin
    TmpStr := strStripL(Copy(Str,6,255),':');
    TmpStr := Copy(strStripB(TmpStr,' '),1,100);
    AddSubField(4, TmpStr);
    MsgHdr^.JamHdr.MsgIdCrc := JamStrCrc(TmpStr);
  End Else
  If Copy(Str,1,4) = 'INTL' Then Begin {ignore}
  End Else
  If Copy(Str,1,4) = 'TOPT' Then Begin {ignore}
  End Else
  If Copy(Str,1,4) = 'FMPT' Then Begin {ignore}
  End Else
  If Copy(Str,1,5) = 'REPLY' Then Begin
    TmpStr := strStripL(Copy(Str,8,255),':');
    TmpStr := Copy(strStripB(TmpStr,' '),1,100);
    AddSubField(5, TmpStr);
    MsgHdr^.JamHdr.ReplyCrc := JamStrCrc(TmpStr);
  End Else
  If Copy(Str,1,4) = 'PATH' Then Begin
    TmpStr := strStripL(Copy(Str,5,255),':');
    TmpStr := strStripB(TmpStr,' ');
    AddSubField(2002, TmpStr);
  End Else Begin
    AddSubField(2000, strStripB(Str,' '));
  End;
End;

Procedure TMsgBaseJAM.AddSubField(id: Word; Data: String);
Type
  SubFieldPTR  = ^SubFieldType;
  SubFieldType = Record
    LoID    : Word;
    HiID    : Word;
    DataLen : LongInt;
    Data    : Array[1..256] of Char;
  End;

Var
  SubField: SubFieldPTR;

Begin
  SubField := SubFieldPTR(@MsgHdr^.SubBuf[MsgHdr^.JamHdr.SubFieldLen + 1]);

  If (MsgHdr^.JamHdr.SubFieldLen + 8 + Length(Data) < JamSubBufSize) Then Begin
    Inc(MsgHdr^.JamHdr.SubFieldLen, 8 + Length(Data));

    SubField^.LoId := Id;
    SubField^.HiId := 0;
    SubField^.DataLen := Length(Data);
    Move(Data[1], SubField^.Data[1], Length(Data));
  End;
End;

Procedure TMsgBaseJAM.EditMsgInit;
Begin
  JM^.TxtBufStart := 0;
  JM^.TxtPos      := 0;

  MsgHdr^.JamHdr.SubFieldLen := 0;

  FillChar(MsgHdr^.SubBuf, SizeOf(MsgHdr^.SubBuf), #0);
End;

(*
Procedure TMsgBaseJAM.EditMsgSave;
Var
{$IFDEF MSDOS}
  iPos   : Word;
{$ELSE}
  iPos   : LongInt;
{$ENDIF}
  TmpIdx : JamIdxType;
  TmpHdr : JamMsgHdrType;
  IdxLoc : LongInt;
Begin
  MsgHdr^.JamHdr.TextOfs := FileSize(JM^.TxtFile);
  MsgHdr^.JamHdr.TextLen := JM^.TxtPos;

  If JM^.TxtBufStart > 0 Then Begin
    iPos := JM^.TxtPos - JM^.TxtBufStart;

    BlockWrite(JM^.BufFile, TxtBuf^, iPos);

    Seek (JM^.BufFile, 0);
    Seek (JM^.TxtFile, FileSize(JM^.TxtFile));

    While Not Eof(JM^.BufFile) Do Begin
      BlockRead (JM^.BufFile, TxtBuf^, SizeOf(TxtBuf^), iPos);

      JM^.TxtBufStart := FilePos(JM^.TxtFile);
      JM^.TxtRead     := iPos;

      BlockWrite(JM^.TxtFile, TxtBuf^, iPos);
    End;

    Close(JM^.BufFile);
    Erase(JM^.BufFile);
  End Else Begin                      {Write text using TxtBuf only}
    Seek (JM^.Txtfile, FileSize(JM^.TxtFile));
    BlockWrite (JM^.TxtFile, TxtBuf^, JM^.TxtPos);
    JM^.TxtRead := JM^.TxtPos;
  End;

  If ReReadIdx(IdxLoc) = 0 Then;

  TmpHdr         := MsgHdr^.JamHdr;
  TmpHdr.Attr1   := TmpHdr.Attr1 AND Jam_Deleted;
  TmpHdr.TextLen := 0;

  Seek (JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
  BlockWrite (JM^.HdrFile, TmpHdr, SizeOf(TmpHdr));

  JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc := FileSize(JM^.HdrFile);

  If Length(JM^.MsgTo)   > 0 Then AddSubField(3, JM^.MsgTo);
  If Length(JM^.MsgFrom) > 0 Then AddSubField(2, JM^.MsgFrom);
  If Length(JM^.MsgSubj) > 0 Then Begin
    If IsFileReq Then
      AddSubField(11, JM^.MsgSubj)
    Else
      AddSubField(6, JM^.MsgSubj);
  End;

  If ((JM^.Dest.Zone <> 0) or (JM^.Dest.Net <> 0) or
    (JM^.Dest.Node <> 0) or (JM^.Dest.Point <> 0)) Then
    AddSubField(1, AddrType2Str(JM^.Dest));

  If ((JM^.Orig.Zone <> 0) or (JM^.Orig.Net <> 0) or
    (JM^.Orig.Node <> 0) or (JM^.Orig.Point <> 0)) Then
    AddSubField(0, AddrType2Str(JM^.Orig));

  JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc := JamStrCrc(JM^.MsgTo);

  Seek (JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
  BlockWrite (JM^.HdrFile, MsgHdr^, SizeOf(MsgHdr^.JamHdr) + MsgHdr^.JamHdr.SubFieldLen);

  If WriteIdx = 0  Then;
  If UnLockMsgBase Then;
End;
*)

Procedure TMsgBaseJAM.EditMsgSave;
Var
  iPos       : LongInt;
  WriteError : Word;
//  TmpIdx     : JamIdxType;
  TmpHdr     : JamMsgHdrType;
  IdxLoc     : LongInt;
Begin
  WriteError := 0;

  MsgHdr^.JamHdr.TextOfs := FileSize(JM^.TxtFile);
  MsgHdr^.JamHdr.TextLen := JM^.TxtPos;

  If JM^.TxtBufStart > 0 Then Begin     {Write text using buffer file}
    iPos := JM^.TxtPos - JM^.TxtBufStart;
    BlockWrite(JM^.BufFile, TxtBuf^, iPos);
    WriteError := IoResult;
    If WriteError = 0 Then Begin
      Seek(JM^.BufFile, 0);
      WriteError := IoResult;
    End;
    If WriteError = 0 Then Begin
      Seek(JM^.TxtFile, FileSize(JM^.TxtFile));
      WriteError := IoResult;
    End;
    While ((Not Eof(JM^.BufFile)) and (WriteError = 0)) Do Begin                          {copy buffer file to text file}
      BlockRead(JM^.BufFile, TxtBuf^, SizeOf(TxtBuf^), iPos);
      WriteError := IoResult;
      If WriteError = 0 Then Begin
        JM^.TxtBufStart := FilePos(JM^.TxtFile);
        JM^.TxtRead := iPos;
        BlockWrite(JM^.TxtFile, TxtBuf^, iPos);
        Error := IoResult;
      End;
    End;
    Close(JM^.BufFile);
    Error := IoResult;
    Erase(JM^.BufFile);
    Error := IoResult;
  End Else Begin                      {Write text using TxtBuf only}
    Seek(JM^.Txtfile, FileSize(JM^.TxtFile));
    WriteError := IoResult;
    If WriteError = 0 Then Begin
      BlockWrite(JM^.TxtFile, TxtBuf^, JM^.TxtPos);
      WriteError := IoResult;
      JM^.TxtRead := JM^.TxtPos;
    End;
  End;

  If WriteError = 0 Then Begin             {Add subfields as needed}
    If Length(JM^.MsgTo)   > 0 Then AddSubField(3, JM^.MsgTo);
    If Length(JM^.MsgFrom) > 0 Then AddSubField(2, JM^.MsgFrom);
    If Length(JM^.MsgSubj) > 0 Then Begin
      If IsFileReq Then
        AddSubField(11, JM^.MsgSubj)
      Else
        AddSubField(6, JM^.MsgSubj);
    End;
    If ((JM^.Dest.Zone <> 0) or (JM^.Dest.Net <> 0) or
      (JM^.Dest.Node <> 0) or (JM^.Dest.Point <> 0)) Then
      AddSubField(1, Addr2Str(JM^.Dest));
    If ((JM^.Orig.Zone <> 0) or (JM^.Orig.Net <> 0) or
      (JM^.Orig.Node <> 0) or (JM^.Orig.Point <> 0)) Then
      AddSubField(0, Addr2Str(JM^.Orig));
    WriteError := IoResult;
  End;

  ReReadIdx(IdxLoc);

(* new shit begin *)
  TmpHdr         := MsgHdr^.JamHdr;
  TmpHdr.TextLen := 0;
  TmpHdr.Attr1   := Jam_Deleted;

  Seek (JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
  BlockWrite (JM^.HdrFile, TmpHdr, SizeOf(TmpHdr));

(* new shit end *)

  JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc   := FileSize(JM^.HdrFile);
  JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc := JamStrCrc(JM^.MsgTo);

  Seek       (JM^.HdrFile, FileSize(JM^.HdrFile));
  BlockWrite (JM^.HdrFile, MsgHdr^, SizeOf(MsgHdr^.JamHdr) + MsgHdr^.JamHdr.SubFieldLen);

  WriteIdx;

  UnLockMsgBase;
End;

Function TMsgBaseJAM.WriteMsg: Word;
Var
  DT: DateTime;
  WriteError: Word;
  i: longint;
  TmpIdx: JamIdxType;
Begin
  WriteError := 0;

  If LastSoft Then Begin
    DoChar(#13);
    DoChar(#10);
  End;

  If WriteError = 0 Then Begin
    MsgHdr^.JamHdr.Signature[1] := 'J';{Set signature}
    MsgHdr^.JamHdr.Signature[2] := 'A';
    MsgHdr^.JamHdr.Signature[3] := 'M';
    MsgHdr^.JamHdr.Signature[4] := #0;

    Case JM^.MailType of
      mmtNormal   : SetAttr1 (Jam_TypeLocal, True);
      mmtEchoMail : SetAttr1 (Jam_TypeEcho,  True);
      mmtNetMail  : SetAttr1 (Jam_TypeNet,   True);
    End;

    MsgHdr^.JamHdr.Rev := 1;
    MsgHdr^.JamHdr.DateArrived := DateDos2Unix(CurDateDos); {Get date processed}

    DT.Year  := strS2I(Copy(JM^.MsgDate, 7, 2)); {Convert date written}
    DT.Month := strS2I(Copy(JM^.MsgDate, 1, 2));
    DT.Day   := strS2I(Copy(JM^.MsgDate, 4, 2));

    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);

    DT.Sec  := 0;
    DT.Hour := strS2I(Copy(JM^.MsgTime, 1, 2));
    DT.Min  := strS2I(Copy(JM^.MsgTime, 4, 2));

    MsgHdr^.JamHdr.DateWritten := DateDT2Unix(DT);
  End;

  If WriteError = 0 Then Begin             {Lock message base for update}
    If Not LockMsgBase Then
      WriteError := 5;
  End;

  If WriteError = 0 Then Begin             {Handle message text}
    MsgHdr^.JamHdr.TextOfs := FileSize(JM^.TxtFile);
    MsgHdr^.JamHdr.MsgNum := GetHighMsgNum + 1;
    MsgHdr^.Jamhdr.TextLen := JM^.TxtPos;

    If JM^.TxtBufStart > 0 Then Begin     {Write text using buffer file}
      i := JM^.TxtPos - JM^.TxtBufStart;
      BlockWrite(JM^.BufFile, TxtBuf^, i); {write buffer to file}
      WriteError := IoResult;
      If WriteError = 0 Then Begin        {seek start of buffer file}
        Seek(JM^.BufFile, 0);
        WriteError := IoResult;
      End;
      If WriteError = 0 Then Begin        {seek end of text file}
        Seek(JM^.TxtFile, FileSize(JM^.TxtFile));
        WriteError := IoResult;
      End;
      While ((Not Eof(JM^.BufFile)) and (WriteError = 0)) Do Begin                          {copy buffer file to text file}
        BlockRead(JM^.BufFile, TxtBuf^, SizeOf(TxtBuf^), i);
        WriteError := IoResult;
        If WriteError = 0 Then Begin
          JM^.TxtBufStart := FilePos(JM^.TxtFile);
          JM^.TxtRead := i;
          BlockWrite(JM^.TxtFile, TxtBuf^, i);
          Error := IoResult;
        End;
      End;
      Close(JM^.BufFile);
      Error := IoResult;
      Erase(JM^.BufFile);
      Error := IoResult;
    End Else Begin                      {Write text using TxtBuf only}
      Seek(JM^.Txtfile, FileSize(JM^.TxtFile));
      WriteError := IoResult;
      If WriteError = 0 Then
        Begin
        BlockWrite(JM^.TxtFile, TxtBuf^, JM^.TxtPos);
        WriteError := IoResult;
        JM^.TxtRead := JM^.TxtPos;
        End;
      End;
    If WriteError = 0 Then             {Add index record}
      Begin
      TmpIdx.HdrLoc := FileSize(JM^.HdrFile);
      TmpIdx.MsgToCrc := JamStrCrc(JM^.MsgTo);
      Seek(JM^.IdxFile, FileSize(JM^.IdxFile));
      WriteError := IoResult;
      End;
    If WriteError = 0 Then             {write index record}
      Begin
      BlockWrite(JM^.IdxFile, TmpIdx, 1);
      WriteError := IoResult;
      End;
    If WriteError = 0 Then Begin             {Add subfields as needed}
      If Length(JM^.MsgTo)   > 0 Then AddSubField(3, JM^.MsgTo);
      If Length(JM^.MsgFrom) > 0 Then AddSubField(2, JM^.MsgFrom);
      If Length(JM^.MsgSubj) > 0 Then Begin
        If IsFileReq Then
          AddSubField(11, JM^.MsgSubj)
        Else
          AddSubField(6, JM^.MsgSubj);
      End;
      If ((JM^.Dest.Zone <> 0) or (JM^.Dest.Net <> 0) or
        (JM^.Dest.Node <> 0) or (JM^.Dest.Point <> 0)) Then
        AddSubField(1, Addr2Str(JM^.Dest));
      If ((JM^.Orig.Zone <> 0) or (JM^.Orig.Net <> 0) or
        (JM^.Orig.Node <> 0) or (JM^.Orig.Point <> 0)) Then
        AddSubField(0, Addr2Str(JM^.Orig));
      Seek(JM^.HdrFile, FileSize(JM^.HdrFile)); {Seek to end of .jhr file}
      WriteError := IoResult;
      End;
    If WriteError = 0 Then Begin           {write msg header}
      BlockWrite(JM^.HdrFile, MsgHdr^, SizeOf(MsgHdr^.JamHdr) +
        MsgHdr^.JamHdr.SubFieldLen);
      WriteError := IoResult;
      End;
    If WriteError = 0 Then Begin          {update msg base header}
      Inc(JM^.BaseHdr.ActiveMsgs);
      Inc(JM^.BaseHdr.ModCounter);
    End;
    If UnLockMsgBase Then;             {unlock msg base}
    End;
  WriteMsg := WriteError;              {return result of writing msg}
  End;


Function TMsgBaseJAM.GetChar: Char;
Begin
  If JM^.TxtPos < 0 Then Begin
    GetChar := JM^.TxtSubBuf[JM^.TxtSubChars + JM^.TxtPos];
    Inc(JM^.TxtPos);
    If JM^.TxtPos >= 0 Then
      JM^.TxtPos := MsgHdr^.JamHdr.TextOfs;
  End Else Begin
    If ((JM^.TxtPos < JM^.TxtBufStart) Or
    (JM^.TxtPos >= JM^.TxtBufStart + JM^.TxtRead)) Then Begin
      JM^.TxtBufStart := JM^.TxtPos - 80;
      If JM^.TxtBufStart < 0 Then JM^.TxtBufStart := 0;
      Seek(JM^.TxtFile, JM^.TxtBufStart);
      Error := IoResult;
      If Error = 0 Then Begin
        BlockRead(JM^.TxtFile, TxtBuf^, SizeOf(TxtBuf^), JM^.TxtRead);
        Error := IoResult;
      End;
    End;
    GetChar := TxtBuf^[JM^.TxtPos - JM^.TxtBufStart];
    Inc(JM^.TxtPos);
  End;
End;

(*
Procedure TMsgBaseJAM.AddTxtSub(St: String);
  Var
    i: Word;

  Begin
  For i := 1 to Length(St) Do
    Begin
    If JM^.TxtSubChars <= TxtSubBufSize Then
      Begin
      JM^.TxtSubBuf[JM^.TxtSubChars] := St[i];
      Inc(JM^.TxtSubChars);
      End;
    End;
  If JM^.TxtSubChars <= TxtSubBufSize Then
    Begin
    JM^.TxtSubBuf[JM^.TxtSubChars] := #13;
    Inc(JM^.TxtSubChars);
    End;
  End;
*)

Procedure TMsgBaseJAM.MsgStartUp;
  Var
    SubCtr: LongInt;
    SubPtr: SubFieldPTR;
    NumRead: LongInt;
    DT: DateTime;
    IdxLoc: LongInt;
    TmpStr: String;
{    TmpAddr: AddrType;}

  Begin
  Error := 0;
  LastSoft := False;
  JM^.MsgFrom := '';
  JM^.MsgTo := '';
  JM^.MsgSubj := '';
  JM^.TxtSubChars := 0;
  If SeekFound Then Begin
    Error := ReReadIdx(IdxLoc);
    If Error = 0 Then Begin
      Seek(JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
      Error := IoResult;
    End;
    If Error = 0 Then Begin
      BlockRead(JM^.HdrFile, MsgHdr^, SizeOf(MsgHdr^), NumRead);
      Error := IoResult;
    End;
    If Error = 0 Then Begin
      DT := DateUnix2DT(MsgHdr^.JamHdr.DateWritten);

      JM^.MsgDate := strZero(DT.Month) + '-' + strZero(DT.Day) + '-' + Copy(strI2S(DT.Year), 3, 2);
      JM^.MsgTime := strZero(DT.Hour)  + ':' + strZero(DT.Min);

      SubCtr := 1;
      While ((SubCtr <= MsgHdr^.JamHdr.SubFieldLen) and (SubCtr < JamSubBufSize)) Do
        Begin
        SubPtr := SubFieldPTR(@MsgHdr^.SubBuf[SubCtr]);
        Inc(SubCtr, SubPtr^.DataLen + 8);
        Case(SubPtr^.LoId) Of
          0: Begin {Orig}
             FillChar(JM^.Orig, SizeOf(JM^.Orig), #0);
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 128 Then TmpStr[0] := #128;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             If Str2Addr(TmpStr, JM^.Orig) Then;
             End;
          1: Begin {Dest}
             FillChar(JM^.Dest, SizeOf(JM^.Dest), #0);
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 128 Then
               TmpStr[0] := #128;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
            If Str2Addr(TmpStr, JM^.Dest) Then;
             End;
          2: Begin {MsgFrom}
             JM^.MsgFrom[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(JM^.MsgFrom[0]) > 65 Then
               JM^.MsgFrom[0] := #65;
             Move(SubPtr^.Data, JM^.MsgFrom[1], Ord(JM^.MsgFrom[0]));
             End;
          3: Begin {MsgTo}
             JM^.MsgTo[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(JM^.MsgTo[0]) > 65 Then JM^.MsgTo[0] := #65;
             Move(SubPtr^.Data, JM^.MsgTo[1], Ord(JM^.MsgTo[0]));
             End;
(*
          4: Begin {MsgId}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'MSGID: ' + TmpStr);
             End;
*)
(*
          5: Begin {Reply}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'REPLY: ' + TmpStr);
             End;
*)
          6: Begin {MsgSubj}
             JM^.MsgSubj[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(JM^.MsgSubj[0]) > 100 Then
               JM^.MsgSubj[0] := #100;
             Move(SubPtr^.Data, JM^.MsgSubj[1], Ord(JM^.MsgSubj[0]));
             End;
(*
          7: Begin {PID}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'PID: ' + TmpStr);
             End;
*)
(*
          8: Begin {VIA}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'Via ' + TmpStr);
             End;
*)
          9: Begin {File attached}
               If IsFAttach Then Begin
                 JM^.MsgSubj[0] := Chr(SubPtr^.DataLen and $ff);
                 If Ord(JM^.MsgSubj[0]) > 100 Then
                   JM^.MsgSubj[0] := #100;
                 Move(SubPtr^.Data, JM^.MsgSubj[1], Ord(JM^.MsgSubj[0]));
               End
             End;
          11: Begin {File request}
             If IsFileReq Then
               Begin
               JM^.MsgSubj[0] := Chr(SubPtr^.DataLen and $ff);
               If Ord(JM^.MsgSubj[0]) > 100 Then
                 JM^.MsgSubj[0] := #100;
               Move(SubPtr^.Data, JM^.MsgSubj[1], Ord(JM^.MsgSubj[0]));
               End
             End;
(*
          2000: Begin {Unknown kludge}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1 + TmpStr);
             End;
*)
(*
          2001: Begin {SEEN-BY}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'SEEN-BY: ' + TmpStr);
             End;
*)
(*
          2002: Begin {PATH}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'PATH: ' + TmpStr);
             End;
*)
(*
          2003: Begin {FLAGS}
             TmpStr[0] := Chr(SubPtr^.DataLen and $ff);
             If Ord(TmpStr[0]) > 240 Then
               TmpSTr[0] := #240;
             Move(SubPtr^.Data, TmpStr[1], Ord(TmpStr[0]));
             AddTxtSub(#1'FLAGS: ' + TmpStr);
             End;
*)
          End;
        End;
      End;
    End;
  End;

Procedure TMsgBaseJAM.MsgTxtStartUp;
Begin
  LastSoft   := False;
  JM^.TxtEnd := MsgHdr^.JamHdr.TextOfs + MsgHdr^.JamHdr.TextLen - 1;

  If JM^.TxtSubChars > 0 Then
    JM^.TxtPos := - JM^.TxtSubChars
  Else
    JM^.TxtPos := MsgHdr^.JamHdr.TextOfs;
End;

Function TMsgBaseJAM.GetString (MaxLen: Word) : String;
Var
  WPos      : LongInt;
  WLen      : Byte;
  StrDone   : Boolean;
  StartSoft : Boolean;
  CurrLen   : Word;
  TmpCh     : Char;
Begin
  StrDone   := False;
  CurrLen   := 0;
  WPos      := 0;
  WLen      := 0;
  StartSoft := LastSoft;
  LastSoft  := True;
  TmpCh     := GetChar;

  While ((Not StrDone) And (CurrLen <= MaxLen) And (Not EOM)) Do Begin
    Case TmpCh of
      #$00: ;
      #$0d: Begin
              StrDone  := True;
              LastSoft := False;
            End;
      #$8d: ;
      #$0a: ;
      #$20: Begin
              If ((CurrLen <> 0) or (Not StartSoft)) Then Begin
                Inc(CurrLen);
                WLen := CurrLen;
                GetString[CurrLen] := TmpCh;
                WPos := JM^.TxtPos;
              End Else
                StartSoft := False;
            End;
    Else
      Inc(CurrLen);
      GetString[CurrLen] := TmpCh;
    End;

    If Not StrDone Then
      TmpCh := GetChar;
  End;

  If StrDone Then Begin
    GetString[0] := Chr(CurrLen);
  End Else
  If EOM Then Begin
    GetString[0] := Chr(CurrLen);
  End Else Begin
    If WLen = 0 Then Begin
      GetString[0] := Chr(CurrLen);
      Dec(JM^.TxtPos);
    End Else Begin
      GetString[0] := Chr(WLen);
      JM^.TxtPos := WPos;
    End;
  End;
End;

Function TMsgBaseJAM.EOM: Boolean;
Begin
  EOM := (((JM^.TxtPos < MsgHdr^.JamHdr.TextOfs) Or
    (JM^.TxtPos > JM^.TxtEnd)) And (JM^.TxtPos >= 0));
End;

(*
Function TMsgBaseJAM.WasWrap: Boolean;
  Begin
  WasWrap := LastSoft;
  End;
*)

Function TMsgBaseJAM.GetFrom: String; {Get from name on current msg}
Begin
  GetFrom := JM^.MsgFrom;
End;

Function TMsgBaseJAM.GetTo: String; {Get to name on current msg}
Begin
  GetTo := JM^.MsgTo;
End;

Function TMsgBaseJAM.GetSubj: String; {Get subject on current msg}
Begin
  GetSubj := JM^.MsgSubj;
End;

//Function TMsgBaseJAM.GetCost: Word; {Get cost of current msg}
//Begin
//  GetCost := MsgHdr^.JamHdr.Cost;
//End;

Function TMsgBaseJAM.GetDate: String; {Get date of current msg}
Begin
  GetDate := JM^.MsgDate;
End;

Function TMsgBaseJAM.GetTime: String; {Get time of current msg}
Begin
  GetTime := JM^.MsgTime;
End;

Function TMsgBaseJAM.GetRefer: LongInt; {Get reply to of current msg}
Begin
  GetRefer := MsgHdr^.JamHdr.ReplyTo;
End;

Function TMsgBaseJAM.GetSeeAlso: LongInt; {Get see also of current msg}
Begin
  GetSeeAlso := MsgHdr^.JamHdr.ReplyFirst;
End;

Function TMsgBaseJAM.GetMsgNum: LongInt; {Get message number}
Begin
  GetMsgNum := MsgHdr^.JamHdr.MsgNum;
End;

Function TMsgBaseJAM.GetOrigAddr : RecEchoMailAddr;
Begin
  Result := JM^.Orig;
End;

Function TMsgBaseJAM.GetDestAddr : RecEchoMailAddr;
Begin
  Result := JM^.Dest;
End;

Procedure TMsgBaseJAM.GetOrig(Var Addr: RecEchoMailAddr); {Get origin address}
Begin
  Addr := JM^.Orig;
End;

Procedure TMsgBaseJAM.GetDest(Var Addr: RecEchoMailAddr); {Get destination address}
Begin
  Addr := JM^.Dest;
End;

Function TMsgBaseJAM.GetTextLen : LongInt; {returns length of text in msg}
Begin
  GetTextLen := MsgHdr^.JamHdr.TextLen;
End;

Function TMsgBaseJAM.IsLocal: Boolean; {Is current msg local}
Begin
  IsLocal := (MsgHdr^.JamHdr.Attr1 and Jam_Local) <> 0;
End;

Function TMsgBaseJAM.IsCrash: Boolean; {Is current msg crash}
Begin
  IsCrash := (MsgHdr^.JamHdr.Attr1 and Jam_Crash) <> 0;
End;

Function TMsgBaseJAM.IsKillSent: Boolean; {Is current msg kill sent}
Begin
  IsKillSent := (MsgHdr^.JamHdr.Attr1 and Jam_KillSent) <> 0;
End;

Function TMsgBaseJAM.IsSent: Boolean; {Is current msg sent}
Begin
  IsSent := (MsgHdr^.JamHdr.Attr1 and Jam_Sent) <> 0;
End;

Function TMsgBaseJAM.IsFAttach: Boolean; {Is current msg file attach}
Begin
  IsFAttach := (MsgHdr^.JamHdr.Attr1 and Jam_FAttch) <> 0;
End;


//Function TMsgBaseJAM.IsReqRct: Boolean; {Is current msg request receipt}
//  Begin
//  IsReqRct := (MsgHdr^.JamHdr.Attr1 and Jam_RcptReq) <> 0;
//  End;


//Function TMsgBaseJAM.IsReqAud: Boolean; {Is current msg request audit}
//  Begin
//  IsReqAud := (MsgHdr^.JamHdr.Attr1 and Jam_ConfmReq) <> 0;
//  End;


//Function TMsgBaseJAM.IsRetRct: Boolean; {Is current msg a return receipt}
//  Begin
//  IsRetRct := False;
//  End;

Function TMsgBaseJAM.IsFileReq: Boolean; {Is current msg a file request}
Begin
  IsFileReq := (MsgHdr^.JamHdr.Attr1 and Jam_Freq) <> 0;
End;

Function TMsgBaseJAM.IsRcvd: Boolean; {Is current msg received}
Begin
  IsRcvd := (MsgHdr^.JamHdr.Attr1 and Jam_Rcvd) <> 0;
End;

Function TMsgBaseJAM.IsPriv: Boolean; {Is current msg priviledged/private}
Begin
  IsPriv := (MsgHdr^.JamHdr.Attr1 and Jam_Priv) <> 0;
End;

Function TMsgBaseJAM.IsDeleted: Boolean; {Is current msg deleted}
Begin
  IsDeleted := (MsgHdr^.JamHdr.Attr1 and Jam_Deleted) <> 0;
End;

//Function TMsgBaseJAM.IsEchoed: Boolean; {Is current msg echoed}
//Begin
//  IsEchoed := True;
//End;

Procedure TMsgBaseJAM.SeekFirst(MsgNum: LongInt); {Start msg seek}
Begin
  JM^.CurrMsgNum := MsgNum - 1;

  If JM^.CurrMsgNum < (JM^.BaseHdr.BaseMsgNum - 1) Then
    JM^.CurrMsgNum := JM^.BaseHdr.BaseMsgNum - 1;

  SeekNext;
End;

Procedure TMsgBaseJAM.SeekNext; {Find next matching msg}
Var
  IdxLoc: LongInt;
Begin
  If JM^.CurrMsgNum <= GetHighMsgNum Then
    Inc (JM^.CurrMsgNum);

  Error := ReReadIdx(IdxLoc);

  While (((JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc < 0) or (JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc = -1)) And (JM^.CurrMsgNum <= GetHighMsgNum)) Do Begin
    Inc (JM^.CurrMsgNum);

    Error := ReReadIdx(IdxLoc);
  End;
End;

Procedure TMsgBaseJAM.SeekPrior;
Var
  IdxLoc: LongInt;
Begin
  If JM^.CurrMsgNum >= JM^.BaseHdr.BaseMsgNum Then
    Dec(JM^.CurrMsgNum);

  Error := ReReadIdx(IdxLoc);

  If JM^.CurrMsgNum >= JM^.BaseHdr.BaseMsgNum Then
    While (IdxLoc >= 0) And (((JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc < 0) or (JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc = -1)) And (JM^.CurrMsgNum >= JM^.BaseHdr.BaseMsgNum)) Do Begin
      Dec (JM^.CurrMsgNum);
      Error := ReReadIdx(IdxLoc);
    End;
End;

Function TMsgBaseJAM.SeekFound: Boolean;
Begin
  SeekFound := ((JM^.CurrMsgNum >= JM^.BaseHdr.BaseMsgNum) and (JM^.CurrMsgNum <= GetHighMsgNum));
End;

Function TMsgBaseJAM.GetMsgLoc: LongInt; {Msg location}
Begin
  GetMsgLoc := GetMsgNum;
End;

Procedure TMsgBaseJAM.SetMsgLoc(ML: LongInt); {Msg location}
  Begin
  JM^.CurrMsgNum := ML;
  End;
(*
Procedure TMsgBaseJAM.YoursFirst (Name: String; Handle: String);
Begin
  JM^.YourName   := Name;
  JM^.YourHdl    := Handle;
  JM^.NameCrc    := JamStrCrc(Name);
  JM^.HdlCrc     := JamStrCrc(Handle);
  JM^.CurrMsgNum := JM^.BaseHdr.BaseMsgNum - 1;

  YoursNext;
End;

Procedure TMsgBaseJAM.YoursNext;
Var
  Found   : Boolean;
  IdxLoc  : LongInt;
  NumRead : LongInt;
  SubCtr  : LongInt;
  SubPtr  : SubFieldPTR;
Begin
  Error := 0;
  Found := False;

  Inc(JM^.CurrMsgNum);

  While ((Not Found) and (JM^.CurrMsgNum <= GetHighMsgNum) And (Error = 0)) Do Begin
    Error := ReReadIdx(IdxLoc);

    If Error = 0 Then Begin                     {Check CRC values}
      If ((JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc = JM^.NameCrc) or
      (JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc = JM^.HdlCrc)) Then Begin
        Seek(JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
        Error := IoResult;
        If Error = 0 Then              {Read message header}
          Begin
          BlockRead(JM^.HdrFile, MsgHdr^, SizeOf(MsgHdr^), NumRead);
          Error := IoResult;
          End;
        If ((Error = 0) and (Not IsRcvd)) Then Begin
          SubCtr := 1;
          While ((SubCtr <= MsgHdr^.JamHdr.SubFieldLen) and
          (SubCtr < JamSubBufSize)) Do Begin
            SubPtr := SubFieldPTR(@MsgHdr^.SubBuf[SubCtr]);
            Inc(SubCtr, SubPtr^.DataLen + 8);
            Case(SubPtr^.LoId) Of
              3: Begin {MsgTo}
                 JM^.MsgTo[0] := Chr(SubPtr^.DataLen and $ff);
                 If Ord(JM^.MsgTo[0]) > 65 Then
                   JM^.MsgTo[0] := #65;
                 Move(SubPtr^.Data, JM^.MsgTo[1], Ord(JM^.MsgTo[0]));
                 If ((strUpper(JM^.MsgTo) = strUpper(JM^.YourName)) Or
                 (strUpper(JM^.MsgTo) = strUpper(JM^.YourHdl))) Then
                   Found := True;
                 End;
              End;
            End;
          End;
        End;
      End;
    If (Not Found) Then
      Inc(JM^.CurrMsgNum);
    End;
  End;

Function TMsgBaseJAM.YoursFound: Boolean;
Begin
  YoursFound := ((JM^.CurrMsgNum >= JM^.BaseHdr.BaseMsgNum) and (JM^.CurrMsgNum <= GetHighMsgNum));
End;
*)

Procedure TMsgBaseJAM.StartNewMsg;
Begin
  JM^.TxtBufStart := 0;
  JM^.TxtPos      := 0;

  FillChar(MsgHdr^, SizeOf(MsgHdr^), #0);

  MsgHdr^.JamHdr.SubFieldLen := 0;
  MsgHdr^.JamHdr.MsgIdCrc    := -1;
  MsgHdr^.JamHdr.ReplyCrc    := -1;
  MsgHdr^.JamHdr.PwdCrc      := -1;

  JM^.MsgTo   := '';
  JM^.MsgFrom := '';
  JM^.MsgSubj := '';

  FillChar(JM^.Orig, SizeOf(JM^.Orig), #0);
  FillChar(JM^.Dest, SizeOf(JM^.Dest), #0);

  JM^.MsgDate := DateDos2Str(CurDateDos, 1);
  JM^.MsgTime := TimeDos2Str(CurDateDos, 0);
End;


//Function TMsgBaseJAM.MsgBaseExists: Boolean;
//  Begin
//  MsgBaseExists := (FileExist(JM^.MsgPath + '.jhr'));
//  End;


Function TMsgBaseJAM.ReadIdx: Word;
Begin
  If JM^.IdxStart < 0 Then JM^.IdxStart := 0;

  Seek      (JM^.IdxFile, JM^.IdxStart);
  BlockRead (JM^.IdxFile, JamIdx^, JamIdxBufSize, JM^.IdxRead);

  ReadIdx := IoResult;
End;

Function TMsgBaseJAM.WriteIdx: Word;
Begin
  Seek       (JM^.IdxFile, JM^.IdxStart);
  BlockWrite (JM^.IdxFile, JamIdx^, JM^.IdxRead);

  WriteIdx := IoResult;
End;

Function TMsgBaseJAM.OpenMsgBase: Boolean;
Var
  OpenError : Word;
Begin
  OpenError     := 0;
  JM^.LockCount := 0;

  Assign(JM^.HdrFile, JM^.MsgPath + '.jhr');
  Assign(JM^.TxtFile, JM^.MsgPath + '.jdt');
  Assign(JM^.IdxFile, JM^.MsgPath + '.jdx');

  FileMode := fmReadWrite + fmDenyNone;

  Reset(JM^.HdrFile, 1);

  OpenError := IoResult;

  If OpenError = 0 Then Begin
    Seek(JM^.HdrFile, 1);
    BlockRead(JM^.HdrFile, JM^.BaseHdr.Signature[2] , SizeOf(JM^.BaseHdr) - 1);
    OpenError := IoResult;
  End;

  If OpenError = 0 Then Begin
    FileMode := fmReadWrite + fmDenyNone;
    Reset(JM^.TxtFile, 1);
    OpenError := IoResult;
  End;

  If OpenError = 0 Then Begin
    FileMode := fmReadWrite + fmDenyNone;
    Reset(JM^.IdxFile, SizeOf(JamIdxType));
    OpenError := IoResult;
  End;

  JM^.IdxStart    := -10;
  JM^.IdxRead     := 0;
  JM^.TxtBufStart := - 10;
  JM^.TxtRead     := 0;
  OpenMsgBase     := (OpenError = 0);
End;

Procedure TMsgBaseJAM.CloseMsgBase;
Begin
  Close (JM^.HdrFile);
  Close (JM^.TxtFile);
  Close (JM^.IdxFile);
End;

Function TMsgBaseJAM.CreateMsgBase (MaxMsg: Word; MaxDays: Word): Boolean;
Var
  TmpHdr      : ^JamHdrType;
  CreateError : Word;
Begin
  CreateError := 0;

  New(TmpHdr);

  If TmpHdr = Nil Then
    CreateError := 500
  Else Begin;
    FillChar(TmpHdr^, SizeOf(TmpHdr^), #0);

    TmpHdr^.Signature[1] :=  'J';
    TmpHdr^.Signature[2] :=  'A';
    TmpHdr^.Signature[3] :=  'M';
    TmpHdr^.BaseMsgNum   := 1;
    TmpHdr^.Created      := DateDos2Unix(CurDateDos);
    TmpHdr^.PwdCrc       := -1;
    CreateError          := SaveFilePos(JM^.MsgPath + '.jhr', TmpHdr^, SizeOf(TmpHdr^), 0);

    Dispose(TmpHdr);

    If CreateError = 0 Then
      CreateError := SaveFilePos(JM^.MsgPath + '.jlr', CreateError, 0, 0);

    If CreateError = 0 Then
      CreateError := SaveFilePos(JM^.MsgPath + '.jdt', CreateError, 0, 0);

    If CreateError = 0 Then
      CreateError := SaveFilePos(JM^.MsgPath + '.jdx', CreateError , 0, 0);

    If IoResult <> 0 Then;
  End;

  CreateMsgBase := CreateError = 0;
End;

Procedure TMsgBaseJAM.SetMailType(MT: MsgMailType);
Begin
  JM^.MailType := MT;
End;

//Function TMsgBaseJAM.GetSubArea: Word;
//Begin
//  GetSubArea := 0;
//End;

Procedure TMsgBaseJAM.ReWriteHdr;
Var
  IdxLoc : LongInt;
Begin
  If LockMsgBase Then
    Error := 0
  Else
    Error := 5;

  Error := ReReadIdx(IdxLoc);

  If Error = 0 Then Begin
    Seek (JM^.HdrFile, JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc);
    Error := IoResult;
  End;

  If Error = 0 Then Begin
    BlockWrite (JM^.HdrFile, MsgHdr^.JamHdr, SizeOf(MsgHdr^.JamHdr));
    Error := IoResult;
  End;

  UnLockMsgBase;
End;

Procedure TMsgBaseJAM.DeleteMsg;
Var
  DelError : Word;
  IdxLoc   : LongInt;
Begin
  If Not IsDeleted Then Begin
    If LockMsgBase Then
      DelError := 0
    Else
      DelError := 5;

    If DelError = 0 Then Begin
      SetAttr1 (Jam_Deleted, True);
      Dec (JM^.BaseHdr.ActiveMsgs);
      DelError := ReReadIdx(IdxLoc);
    End;

    If DelError = 0 Then ReWriteHdr;

    If DelError = 0 Then Begin
      Inc(JM^.BaseHdr.ModCounter);

      JamIdx^[IdxLoc - JM^.IdxStart].MsgToCrc := -1;
      JamIdx^[IdxLoc - JM^.IdxStart].HdrLoc := -1;

      WriteIdx;
    End;

    UnLockMsgBase;
  End;
End;

Function TMsgBaseJAM.NumberOfMsgs: LongInt;
Begin
  NumberOfMsgs := JM^.BaseHdr.ActiveMsgs;
End;

Function TMsgBaseJAM.FindLastRead (Var LastFile: File; UNum: LongInt): LongInt;
Const
  LastSize = 100;
Type
  LastArray = Array[1..LastSize] of JamLastType;
Var
  LastBuf   : ^LastArray;
  LastError : Word;
  NumRead   : LongInt;
  Found     : Boolean;
  Count     : Word;
  LastStart : LongInt;
Begin
  FindLastRead := -1;
  Found        := False;

  New  (LastBuf);
  Seek (LastFile, 0);

  LastError := IoResult;

  While ((Not Eof(LastFile)) and (LastError = 0) And (Not Found)) Do Begin
    LastStart := FilePos(LastFile);

    BlockRead (LastFile, LastBuf^, LastSize, NumRead);

    LastError := IoResult;

    For Count := 1 to NumRead Do Begin
      If LastBuf^[Count].UserNum = UNum Then Begin
        Found        := True;
        FindLastRead := LastStart + Count - 1;
      End;
    End;
  End;

  Dispose (LastBuf);
End;

Function TMsgBaseJAM.GetLastRead (UNum: LongInt) : LongInt;
Var
  RecNum   : LongInt;
  LastFile : File;
  TmpLast  : JamLastType;
Begin
  Assign (LastFile, JM^.MsgPath + '.jlr');

  FileMode := fmReadWrite + fmDenyNone;

  Reset (LastFile, SizeOf(JamLastType));

  Error  := IoResult;
  RecNum := FindLastRead(LastFile, UNum);

  If RecNum >= 0 Then Begin
    Seek (LastFile, RecNum);

    If Error = 0 Then Begin
      BlockRead (LastFile, TmpLast, 1);

      Error       := IoResult;
      GetLastRead := TmpLast.HighRead;
    End;
  End Else
    GetLastRead := 0;

  Close (LastFile);

  Error := IoResult;
End;

Procedure TMsgBaseJAM.SetLastRead (UNum: LongInt; LR: LongInt);
Var
  RecNum   : LongInt;
  LastFile : File;
  TmpLast  : JamLastType;
Begin
  Assign (LastFile, JM^.MsgPath + '.jlr');

  FileMode := fmReadWrite + fmDenyNone;

  Reset (LastFile, SizeOf(JamLastType));

  Error := IoResult;

  If Error <> 0 Then ReWrite(LastFile, SizeOf(JamLastType));

  Error  := IoResult;
  RecNum := FindLastRead(LastFile, UNum);

  If RecNum >= 0 Then Begin
    Seek (LastFile, RecNum);

    If Error = 0 Then Begin
      BlockRead (LastFile, TmpLast, 1);

      Error := IoResult;

      TmpLast.HighRead := LR;
      TmpLast.LastRead := LR;

      If Error = 0 Then Begin
        Seek (LastFile, RecNum);
        Error := IoResult;
      End;

      If Error = 0 Then Begin
        BlockWrite (LastFile, TmpLast, 1);
        Error := IoResult;
      End;
    End;
  End Else Begin
    TmpLast.UserNum  := UNum;
    TmpLast.HighRead := Lr;
    TmpLast.NameCrc  := UNum;
    TmpLast.LastRead := Lr;

    Seek (LastFile, FileSize(LastFile));

    Error := IoResult;

    If Error = 0 Then Begin
      BlockWrite (LastFile, TmpLast, 1);
      Error := IoResult;
    End;
  End;

  Close (LastFile);

  Error := IoResult;
End;

Function TMsgBaseJAM.GetTxtPos : LongInt;
Begin
  GetTxtPos := JM^.TxtPos;
End;

Procedure TMsgBaseJAM.SetTxtPos (TP: LongInt);
Begin
  JM^.TxtPos := TP;
End;

Function TMsgBaseJAM.LockMsgBase: Boolean;
Var
  LockError: Word;
Begin
  LockError := 0;
  If JM^.LockCount = 0 Then Begin
    If LockError = 0 Then Begin
//      LockError := shLock(JM^.HdrFile, 0, 1);
    End;
    If LockError = 0 Then Begin
      Seek(JM^.HdrFile, 0);
      LockError := IoResult;
    End;
    If LockError = 0 Then Begin
      BlockRead(JM^.HdrFile, JM^.BaseHdr , SizeOf(JM^.BaseHdr));
      LockError := IoResult;
    End;
  End;

  Inc (JM^.LockCount);

  LockMsgBase := (LockError = 0);
End;

Function TMsgBaseJAM.UnLockMsgBase: Boolean;
Var
  LockError: Word;
Begin
  LockError := 0;

  If JM^.LockCount > 0 Then Dec(JM^.LockCount);

  If JM^.LockCount = 0 Then Begin
    If LockError = 0 Then Begin
//      LockError := UnLockFile(JM^.HdrFile, 0, 1);
    End;
    If LockError = 0 Then Begin
      Seek(JM^.HdrFile, 0);
      LockError := IoResult;
    End;
    If LockError = 0 Then Begin
      BlockWrite(JM^.HdrFile, JM^.BaseHdr, SizeOf(JM^.BaseHdr));
      LockError := IoResult;
    End;
  End;

  UnLockMsgBase := (LockError = 0);
End;

Procedure TMsgBaseJAM.SetNextSeeAlso(SAlso: LongInt);
Begin
  MsgHdr^.JamHdr.ReplyNext := SAlso;
End;

Function TMsgBaseJAM.GetNextSeeAlso: LongInt; {Get next see also of current msg}
Begin
  GetNextSeeAlso := MsgHdr^.JamHdr.ReplyNext;
End;

Function TMsgBaseJAM.ReReadIdx (Var IdxLoc : LongInt) : Word;
Begin
  ReReadIdx := 0;
  IdxLoc    := JM^.CurrMsgNum - JM^.BaseHdr.BaseMsgNum;

  If ((IdxLoc < JM^.IdxStart) OR (IdxLoc >= (JM^.IdxStart + JM^.IdxRead))) Then Begin
    JM^.IdxStart := IdxLoc - 30;

    If JM^.IdxStart < 0 Then JM^.IdxStart := 0;

    ReReadIdx := ReadIdx;
  End;
End;

End.

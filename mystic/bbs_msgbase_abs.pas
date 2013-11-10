Unit BBS_MsgBase_ABS;

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

{$WARNINGS OFF}

Interface

Uses
  BBS_Records;

Type
  MsgMailType = (mmtNormal, mmtEchoMail, mmtNetMail);

  PMsgBaseABS = ^TMsgBaseABS;
  TMsgBaseABS = Object
    LastSoft : Boolean;
    TempFile : String;

    Procedure EditMsgInit; Virtual;
    Procedure EditMsgSave; Virtual;

    Constructor Init; {Initialize}
    Destructor Done; Virtual; {Done}
    Procedure SetMsgPath(MP: String); Virtual; {Set msg path/other info}
    Function  OpenMsgBase : Boolean; Virtual; {Open the message base}
    Procedure CloseMsgBase; Virtual; {Close the message base}
    Function  CreateMsgBase(MaxMsg: Word; MaxDays: Word): Boolean; Virtual;
//    Function  MsgBaseExists: Boolean; Virtual; {Does msg base exist}
    Function  LockMsgBase: Boolean; Virtual; {Lock the message base}
    Function  UnLockMsgBase: Boolean; Virtual; {Unlock the message base}
    Procedure SetDest (Addr: RecEchoMailAddr); Virtual; {Set Zone/Net/Node/Point for Dest}
    Procedure SetOrig (Addr: RecEchoMailAddr); Virtual; {Set Zone/Net/Node/Point for Orig}
    Procedure SetFrom(Name: String); Virtual; {Set message from}
    Procedure SetTo(Name: String); Virtual; {Set message to}
    Procedure SetSubj(Str: String); Virtual; {Set message subject}
    Procedure SetCost(SCost: Word); Virtual; {Set message cost}
    Procedure SetRefer(SRefer: LongInt); Virtual; {Set message reference}
    Procedure SetSeeAlso(SAlso: LongInt); Virtual; {Set message see also}
    Procedure SetDate(SDate: String); Virtual; {Set message date}
    Procedure SetTime(STime: String); Virtual; {Set message time}
    Procedure SetLocal(LS: Boolean); Virtual; {Set local status}
    Procedure SetRcvd(RS: Boolean); Virtual; {Set received status}
    Procedure SetPriv(PS: Boolean); Virtual; {Set priveledge vs public status}
    Procedure SetCrash(SS: Boolean); Virtual; {Set crash netmail status}
    Procedure SetHold(SS: Boolean); Virtual; {Set hold netmail status}
    Procedure SetKillSent(SS: Boolean); Virtual; {Set kill/sent netmail status}
    Procedure SetSent(SS: Boolean); Virtual; {Set sent netmail status}
    Procedure SetFAttach(SS: Boolean); Virtual; {Set file attach status}
    Procedure SetReqRct(SS: Boolean); Virtual; {Set request receipt status}
    Procedure SetReqAud(SS: Boolean); Virtual; {Set request audit status}
    Procedure SetRetRct(SS: Boolean); Virtual; {Set return receipt status}
    Procedure SetFileReq(SS: Boolean); Virtual; {Set file request status}
    Procedure DoString(Str: String); Virtual; {Add string to message text}
    Procedure DoChar(Ch: Char); Virtual; {Add character to message text}
    Procedure DoStringLn(Str: String); Virtual; {Add string and newline to msg text}
    Procedure DoKludgeLn(Str: String); Virtual; {Add ^A kludge line to msg}
    Function  WriteMsg: Word; Virtual; {Write msg to msg base}
    Function  GetChar: Char; Virtual; {Get msg text character}
    Function  EOM: Boolean; Virtual; {No more msg text}
    Function  GetString(MaxLen: Word): String; Virtual; {Get wordwrapped string}
    Function  GetNoKludgeStr(MaxLen: Word): String; Virtual; {Get ww str no ^A lines}
    Function  GetFrom: String; Virtual; {Get from name on current msg}
    Function  GetTo: String; Virtual; {Get to name on current msg}
    Function  GetSubj: String; Virtual; {Get subject on current msg}
//    Function  GetCost: Word; Virtual; {Get cost of current msg}
    Function  GetDate: String; Virtual; {Get date of current msg}
    Function  GetTime: String; Virtual; {Get time of current msg}
    Function  GetRefer: LongInt; Virtual; {Get reply to of current msg}
    Function  GetSeeAlso: LongInt; Virtual; {Get see also of current msg}
    Function  GetNextSeeAlso: LongInt; Virtual;
    Procedure SetNextSeeAlso(SAlso: LongInt); Virtual;
    Function  GetMsgNum: LongInt; Virtual; {Get message number}
    Function  GetTextLen: LongInt; Virtual; {Get text length}
    Procedure GetOrig (Var Addr : RecEchoMailAddr); Virtual; {Get origin address}
    Function  GetOrigAddr : RecEchoMailAddr; Virtual;
    Procedure GetDest (Var Addr : RecEchoMailAddr); Virtual; {Get destination address}
    Function  GetDestAddr : RecEchoMailAddr; Virtual;
    Function  IsLocal: Boolean; Virtual; {Is current msg local}
    Function  IsCrash: Boolean; Virtual; {Is current msg crash}
    Function  IsKillSent: Boolean; Virtual; {Is current msg kill sent}
    Function  IsSent: Boolean; Virtual; {Is current msg sent}
    Function  IsFAttach: Boolean; Virtual; {Is current msg file attach}
//    Function  IsReqRct: Boolean; Virtual; {Is current msg request receipt}
//    Function  IsReqAud: Boolean; Virtual; {Is current msg request audit}
//    Function  IsRetRct: Boolean; Virtual; {Is current msg a return receipt}
    Function  IsFileReq: Boolean; Virtual; {Is current msg a file request}
    Function  IsRcvd: Boolean; Virtual; {Is current msg received}
    Function  IsPriv: Boolean; Virtual; {Is current msg priviledged/private}
    Function  IsDeleted: Boolean; Virtual; {Is current msg deleted}
    Function  IsEchoed: Boolean; Virtual; {Is current msg unmoved echomail msg}
    Function  GetMsgLoc: LongInt; Virtual; {To allow reseeking to message}
    Procedure SetMsgLoc(ML: LongInt); Virtual; {Reseek to message}
    Procedure MsgStartUp; Virtual; {Do message set-up tasks}
    Procedure MsgTxtStartUp; Virtual; {Do message text start up tasks}
    Procedure StartNewMsg; Virtual; {Initialize for adding message}
    Procedure SeekFirst(MsgNum: LongInt); Virtual; {Start msg seek}
    Procedure SeekNext; Virtual; {Find next matching msg}
    Procedure SeekPrior; Virtual; {Prior msg}
    Function  SeekFound: Boolean; Virtual; {Msg was found}
//    Procedure YoursFirst(Name: String; Handle: String); Virtual; {Seek your mail}
//    Procedure YoursNext; Virtual; {Seek next your mail}
//    Function  YoursFound: Boolean; Virtual; {Message found}
    Function  GetHighMsgNum: LongInt; Virtual; {Get highest msg number}
    Procedure SetMailType(MT: MsgMailType); Virtual; {Set message base type}
//    Function  GetSubArea: Word; Virtual; {Get sub area number}
    Procedure ReWriteHdr; Virtual; {Rewrite msg header after changes}
    Procedure DeleteMsg; Virtual; {Delete current message}
    Procedure SetEcho(ES: Boolean); Virtual; {Set echo status}
    Function  NumberOfMsgs: LongInt; Virtual; {Number of messages}
    Function  GetLastRead(UNum: LongInt): LongInt; Virtual; {Get last read for user num}
    Procedure SetLastRead(UNum: LongInt; LR: LongInt); Virtual; {Set last read}
    Function  GetMsgDisplayNum: LongInt; Virtual; {Get msg number to display}
    Function  GetTxtPos: LongInt; Virtual; {Get indicator of msg text position}
    Procedure SetTxtPos(TP: LongInt); Virtual; {Set text position}
    Function  GetHighActiveMsgNum: LongInt; Virtual; {Get highest active msg num}
    Procedure SetTempFile (TF: String);
  End;

Implementation

Procedure TMsgBaseABS.SetTempFile (TF: String);
Begin
  TempFile := TF;
End;

Constructor TMsgBaseABS.Init;
Begin
End;

Destructor TMsgBaseABS.Done;
Begin
End;

Procedure TMsgBaseABS.SetMsgPath(MP: String);
Begin
End;

Function TMsgBaseABS.OpenMsgBase: Boolean;
Begin
End;

Procedure TMsgBaseABS.CloseMsgBase;
Begin
End;

Function TMsgBaseABS.LockMsgBase: Boolean;
Begin
End;

Function TMsgBaseABS.UnLockMsgBase: Boolean;
Begin
End;

Procedure TMsgBaseABS.SetDest (Addr: RecEchoMailAddr);
Begin
End;

Procedure TMsgBaseABS.SetOrig (Addr: RecEchoMailAddr);
Begin
End;

Procedure TMsgBaseABS.SetFrom(Name: String);
Begin
End;

Procedure TMsgBaseABS.SetTo(Name: String);
Begin
End;

Procedure TMsgBaseABS.SetSubj(Str: String);
Begin
End;

Procedure TMsgBaseABS.SetCost(SCost: Word);
Begin
End;

Procedure TMsgBaseABS.SetRefer(SRefer: LongInt);
Begin
End;

Procedure TMsgBaseABS.SetSeeAlso(SAlso: LongInt);
Begin
End;

Procedure TMsgBaseABS.SetDate(SDate: String);
Begin
End;

Procedure TMsgBaseABS.SetTime(STime: String);
Begin
End;

Procedure TMsgBaseABS.SetLocal(LS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetRcvd(RS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetPriv(PS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetHold (SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetCrash(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetKillSent(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetSent(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetFAttach(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetReqRct(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetReqAud(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetRetRct(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.SetFileReq(SS: Boolean);
Begin
End;

Procedure TMsgBaseABS.DoString (Str: String);
Var
  Count : Word;
Begin
  For Count := 1 to Length(Str) Do
    DoChar(Str[Count]);
End;

Procedure TMsgBaseABS.DoChar(Ch: Char);
Begin
End;

Procedure TMsgBaseABS.DoStringLn(Str: String);
Begin
  DoString(Str + #13);
//  DoChar(#13);
End;

Procedure TMsgBaseABS.DoKludgeLn(Str: String);
Begin
  DoStringLn(Str);
End;

Function TMsgBaseABS.WriteMsg: Word;
Begin
End;

Function TMsgBaseABS.GetChar: Char;
Begin
End;

Function TMsgBaseABS.EOM: Boolean;
Begin
End;

Function TMsgBaseABS.GetString(MaxLen: Word): String;
(*
  Var
    WPos: LongInt;
    WLen: Byte;
    StrDone: Boolean;
    TxtOver: Boolean;
    StartSoft: Boolean;
    CurrLen: Word;
    PPos: LongInt;
    TmpCh: Char;
    OldPos: LongInt;

  Begin
  If EOM Then
    GetString := ''
  Else
    Begin
    StrDone := False;
    CurrLen := 0;
    PPos := GetTxtPos;
    WPos := GetTxtPos;
    WLen := 0;
    StartSoft := LastSoft;
    LastSoft := True;
    OldPos := GetTxtPos;
    TmpCh := GetChar;
    While ((Not StrDone) And (CurrLen < MaxLen) And (Not EOM)) Do
      Begin
      Case TmpCh of
        #$00:;
        #$0d: Begin
              StrDone := True;
              LastSoft := False;
              End;
        #$8d:;
        #$0a:;
        #$20: Begin
              If ((CurrLen <> 0) or (Not StartSoft)) Then
                Begin
                Inc(CurrLen);
                WLen := CurrLen;
                GetString[CurrLen] := TmpCh;
                WPos := GetTxtPos;
                End
              Else
                StartSoft := False;
              End;
        Else
          Begin
          Inc(CurrLen);
          GetString[CurrLen] := TmpCh;
          End;
        End;
      If Not StrDone Then
        Begin
        OldPos := GetTxtPos;
        TmpCh := GetChar;
        End;
      End;
    If StrDone Then
      Begin
      GetString[0] := Chr(CurrLen);
      End
    Else
      If EOM Then
        Begin
        GetString[0] := Chr(CurrLen);
        End
      Else
        Begin
        If WLen = 0 Then
          Begin
          GetString[0] := Chr(CurrLen);
          SetTxtPos(OldPos);
          End
        Else
          Begin
          GetString[0] := Chr(WLen);
          SetTxtPos(WPos);
          End;
        End;
    End;
*)
{ the above stuff could be used to write universal GETSTRING and GETCHAR }
{ functions for ANY message base format. }
Begin
End;

Procedure TMsgBaseABS.SeekFirst(MsgNum: LongInt);
Begin
End;

Procedure TMsgBaseABS.SeekNext;
Begin
End;

Function TMsgBaseABS.GetFrom: String;
Begin
End;

Function TMsgBaseABS.GetTo: String;
Begin
End;

Function TMsgBaseABS.GetSubj: String;
Begin
End;

//Function TMsgBaseABS.GetCost: Word;
//Begin
//End;

Function TMsgBaseABS.GetDate: String;
Begin
End;

Function TMsgBaseABS.GetTime: String;
Begin
End;

Function TMsgBaseABS.GetRefer: LongInt;
Begin
End;

Function TMsgBaseABS.GetSeeAlso: LongInt;
Begin
End;

Function TMsgBaseABS.GetMsgNum: LongInt;
Begin
End;

Function TMsgBaseABS.GetTextLen : LongInt;
Begin
End;

Procedure TMsgBaseABS.GetOrig(Var Addr: RecEchoMailAddr);
Begin
End;

Function TMsgBaseABS.GetOrigAddr : RecEchoMailAddr;
Begin
End;

Procedure TMsgBaseABS.GetDest(Var Addr: RecEchoMailAddr);
Begin
End;

Function TMsgBaseABS.GetDestAddr : RecEchoMailAddr;
Begin
End;

Function TMsgBaseABS.IsLocal: Boolean;
Begin
End;

Function TMsgBaseABS.IsCrash: Boolean;
Begin
End;

Function TMsgBaseABS.IsKillSent: Boolean;
Begin
End;

Function TMsgBaseABS.IsSent: Boolean;
Begin
End;

Function TMsgBaseABS.IsFAttach: Boolean;
Begin
End;

//Function TMsgBaseABS.IsReqRct: Boolean;
//Begin
//End;

//Function TMsgBaseABS.IsReqAud: Boolean;
//Begin
//End;

//Function TMsgBaseABS.IsRetRct: Boolean;
//Begin
//End;

Function TMsgBaseABS.IsFileReq: Boolean;
Begin
End;

Function TMsgBaseABS.IsRcvd: Boolean;
Begin
End;

Function TMsgBaseABS.IsPriv: Boolean;
Begin
End;

Function TMsgBaseABS.IsDeleted: Boolean;
Begin
End;

Function TMsgBaseABS.IsEchoed: Boolean;
Begin
End;

Function TMsgBaseABS.GetMsgLoc: LongInt;
Begin
End;

Procedure TMsgBaseABS.SetMsgLoc(ML: LongInt);
Begin
End;

Procedure TMsgBaseABS.MsgStartUp;
Begin
End;

Procedure TMsgBaseABS.MsgTxtStartUp;
Begin
End;

(*
Procedure TMsgBaseABS.YoursFirst(Name: String; Handle: String);
Begin
End;

Procedure TMsgBaseABS.YoursNext;
Begin
End;

Function TMsgBaseABS.YoursFound: Boolean;
Begin
End;
*)
Function TMsgBaseABS.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Boolean;
Begin
End;

(*
Function TMsgBaseABS.MsgBaseExists: Boolean;
Begin
End;
*)

Procedure TMsgBaseABS.StartNewMsg;
Begin
End;

Function TMsgBaseABS.GetHighMsgNum: LongInt;
Begin
End;

Function TMsgBaseABS.SeekFound: Boolean;
Begin
End;

Procedure TMsgBaseABS.SetMailType(MT: MsgMailType);
Begin
End;

//Function TMsgBaseABS.GetSubArea: Word;
//Begin
//  GetSubArea := 0;
//End;

Procedure TMsgBaseABS.ReWriteHdr;
Begin
End;

Procedure TMsgBaseABS.DeleteMsg;
Begin
End;

Procedure TMsgBaseABS.SetEcho(ES: Boolean);
Begin
End;

Procedure TMsgBaseABS.SeekPrior;
Begin
End;

Function TMsgBaseABS.NumberOfMsgs: LongInt;
Begin
End;

Function TMsgBaseABS.GetLastRead(UNum: LongInt): LongInt;
Begin
End;

Procedure TMsgBaseABS.SetLastRead(UNum: LongInt; LR: LongInt);
Begin
End;

Function TMsgBaseABS.GetMsgDisplayNum: LongInt;
Begin
  GetMsgDisplayNum := GetMsgNum;
End;

Function TMsgBaseABS.GetTxtPos: LongInt;
Begin
  GetTxtPos := 0;
End;

Procedure TMsgBaseABS.SetTxtPos(TP: LongInt);
Begin
End;

Procedure TMsgBaseABS.SetNextSeeAlso(SAlso: LongInt);
Begin
End;

Function TMsgBaseABS.GetNextSeeAlso: LongInt;
Begin
  GetNextSeeAlso:=0;
End;

Function  TMsgBaseABS.GetNoKludgeStr(MaxLen: Word): String;
Begin
  Result := GetString(MaxLen);
  While ((Length(Result) > 0) and (Result[1] = #1) and (Not EOM)) Do
    Result := GetString(MaxLen);
End;

Function TMsgBaseABS.GetHighActiveMsgNum: LongInt;
Begin
  SeekFirst(GetHighMsgNum);

  If Not SeekFound Then
    SeekPrior;

  If SeekFound Then
    GetHighActiveMsgNum := GetMsgNum
  Else
    GetHighActiveMsgNum := 0;
End;

Procedure TMsgBaseABS.EditMsgInit;
Begin
End;

Procedure TMsgBaseABS.EditMsgSave;
Begin
End;

End.

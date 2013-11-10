Unit BBS_MsgBase_Squish;

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

Interface

Uses
  BBS_Records,
  BBS_MsgBase_ABS,
  DOS;

Const
  SqHdrId     = $AFAE4453;
  SqLinkNext  = 0;
  SqLinkPrev  = 1;
  SqNullFrame = 0;
  SqFrameMsg  = 0;
  SqFrameFree = 1;
//  SqFrameRLE  = 2;
//  SqFrameLZW  = 3;
  SqFromSize  = 36;
  SqToSize    = 36;
  SqSubjSize  = 72;
  SqMaxReply  = 10;

Type
  SqBaseType = Record
    Len        : Word;                         { Length of this record                                                                        }
    Rsvd1      : Word;                         { Future use                                                                                                           }
    NumMsg     : LongInt;      { Number of messages                                                                           }
    HighMsg    : LongInt;      { Highest msg                                                                                                          }
    SkipMsg    : LongInt;      { # of msgs to keep in beginning of area }
    HighWater  : LongInt;    { High water UMsgId                                                                                    }
    Uid        : LongInt;      { Next UMsgId                                                                                                          }
    Base       : String[79]; { Base name of Squish file                                                       }
    BeginFrame : LongInt;    { Offset of first frame in file                                        }
    LastFrame  : LongInt;    { Offset of last frame in file                                         }
    FirstFree  : LongInt;    { Offset of first free frame in file           }
    LastFree   : LongInt;      { Offset of last free frame in file                    }
    EndFrame   : LongInt;      { Pointer to end of file                                                               }
    MaxMsg     : LongInt;      { Maximum number of messages                                           }
    KeepDays   : Word;                         { Maximum age of messages                                                              }
    SqHdrSize  : Word;                       { Size of frame header                                                                         }
    Rsvd2      : Array[1..124] of Byte;
  End;

  SqFrameHdrType = Record
    Id            : Cardinal; { Must equal SqHdrId                                                                                         }
    NextFrame     : LongInt; { Next msg frame                                                                                                     }
    PrevFrame     : LongInt; { Prior msg frame                                                                                                    }
    FrameLength   : LongInt; { Length of this frame not counting header }
    MsgLength     : LongInt; { Length of message                                                                                          }
    ControlLength : LongInt; { Length of control information                                                }
    FrameType     : Word;          { Type of message frame                                                                                }
    Rsvd          : Word;          { Future use                                                                                                                   }
  End;

  SqMsgHdrType = Record
    Attr        : LongInt;                                                                                               { Msg attribute                                                }
    MsgFrom     : String[SqFromSize - 1];                                { Nul Term from name                   }
    MsgTo       : String[SqToSize - 1];                                          { Nul term to name                             }
    Subj        : String[SqSubjSize - 1];                                { Nul term subject                             }
    Orig        : RecEchoMailAddr;                                                                                      { Origin address                                       }
    Dest        : RecEchoMailAddr;                                                                                      { Destination address                  }
    DateWritten : LongInt;                                                                                           { Date msg written                             }
    DateArrived : LongInt;                                                                                           { Date msg arrived here                }
    UtcOffset   : Word;                                                                                                          { Minutes offset from UTC      }
    ReplyTo     : LongInt;                                                                                               { Original msg                                                 }
    Replies     : Array[1..SqMaxReply] of LongInt; { Replies                                                                    }
    AzDate      : String[19];                                                                            { AsciiZ "Fido" style date }
  End;

  SqIdxType = Record
    Ofs    : LongInt; { Offset of frame header }
    UMsgId : LongInt; { Unique message id            }
    Hash   : LongInt; { Hash of MsgTo name                 }
  End;

Const
  SqIdxArraySize = 5200;  {5200}

Type
  SqIdxArrayType = Array[1..SqIdxArraySize] of SqIdxType;
  SqIdxPtrType   = ^SqIdxArrayType;

  FreeListType = Record
    FreePos  : LongInt;
    FreeSize : LongInt;
  End;

Const
  MaxFree = 500;

Type
  FreeArrayType = Array[1..MaxFree] of FreeListType;

Const
  SqBSize : Word = SizeOf(SqBaseType);
  SqFSize : Word = SizeOf(SqFrameHdrType);
  SqMSize : Word = SizeOf(SqMsgHdrType);
  SqISize : Word = SizeOf(SqIdxType);

Const
  SqTxtBufferSize = 16000;
                                                                                                                {handle 200 lines x 80 chars EASILY                      }
Type
  SqInfoType = Record
    FN              : String[80];
    MsgChars        : Array[1..SqTxtBufferSize] of Char;
    Error           : Word;
    SqdFile         : File;
    SqIFile         : File;
    SqBase          : SqBaseType;
    SqBaseExtra     : Array[1..100] of Char;
    SqdOpened       : Boolean;
    SqiOpened       : Boolean;
    SqiAlloc        : Word;
    Locked          : Boolean;
    FreeLoaded      : Boolean;
    HighestFree     : Word;
    Frame           : SqFrameHdrType;
    MsgHdr          : SqMsgHdrType;
    Extra           : Array[1..100] of Char;
    TxtCtr          : Word;
    MsgDone         : Boolean;
    CurrIdx         : Word;
    StrDate         : String[8];
    StrTime         : String[8];
    CurrentFramePos : LongInt;
    CurrentUID      : LongInt;
    SName           : String[35];
    SHandle         : String[35];
    HName           : LongInt;
    HHandle         : LongInt;
  End;

Type
  PMsgBaseSquish = ^TMsgBaseSquish;
  TMsgBaseSquish = Object(TMsgBaseAbs)
    SqInfo    : ^SqInfoType;
    SqIdx     : ^SqIdxArrayType;
    FreeArray : ^FreeArrayType;

    Procedure EditMsgInit; Virtual;
    Procedure EditMsgSave; Virtual;

    Constructor Init; {Initialize}
    Destructor Done; Virtual; {Done cleanup and dispose}
    Function        OpenMsgBase: Boolean; Virtual; {Open message base}
    Procedure CloseMsgBase; Virtual; {Close message base}
    Function        CreateMsgBase(MaxMsg: Word; MaxDays: Word): Boolean; Virtual;
//    Function        MsgBaseExists: Boolean; Virtual;
    Procedure SetMsgPath(FN: String); Virtual; {Set filepath and name - no extension}
    Function        SqdOpen: Boolean; Virtual; {Open squish data file}
    Function        SqiOpen: Boolean; Virtual; {Open squish index file}
    Procedure SqdClose; Virtual; {Close squish data file}
    Procedure SqiClose; Virtual; {Close squish index file}
    Function        LockMsgBase: Boolean; Virtual; {Lock msg base}
    Function        UnLockMsgBase: Boolean; Virtual; {Unlock msg base}
    Procedure ReadBase; Virtual; {Read base data record}
    Procedure WriteBase; Virtual; {Write base data record}
    Function        GetBeginFrame: LongInt; Virtual; {Get beginning frame pos}
    Function        GetHighWater: LongInt; Virtual; {Get high water umsgid}
    Function        GetHighMsgNum: LongInt; Virtual; {Get highest msg number}
    Procedure ReadFrame(FPos: LongInt); Virtual; {Read frame at FPos}
    Procedure ReadVarFrame(Var Frame: SqFrameHdrType; FPos: LongInt); Virtual; {Read frame at FPos into Frame}
    Procedure WriteFrame(FPos: LongInt); Virtual; {Write frame at FPos}
    Procedure WriteVarFrame(Var Frame: SqFrameHdrType; FPos: LongInt); Virtual;
    Procedure UnlinkFrame(Var Frame: SqFrameHdrType); Virtual; {Unlink frame from linked list}
    Procedure LinkFrameNext(Var Frame: SqFrameHdrType; OtherFrame: LongInt;
                FramePos: LongInt); Virtual; {Link frame after other frame}
    Procedure KillMsg(MsgNum: LongInt); {Kill msg msgnum}
    Procedure KillExcess; {Kill msg in excess of limit}
    Procedure FindFrame(Var FL: LongInt; Var FramePos: LongInt); Virtual;
    Function        GetNextFrame: LongInt; Virtual; {Get next frame pos}
    Procedure ReadMsgHdr(FPos: LongInt); Virtual; {Read msg hdr for frame at FPos}
    Procedure WriteMsgHdr(FPos: LongInt); Virtual; {Read msg hdr for frame at FPos}
    Procedure WriteText(FPos: LongInt); Virtual; {Write text buffer for frame at Fpos}
    Function        SqHashName(Name: String): LongInt; Virtual; {Convert name to hash value}
    Procedure StartNewMsg; Virtual; {Initialize msg header}
    Function        GetFrom: String; Virtual; {Get message from}
    Function        GetTo: String; Virtual; {Get message to}
    Function        GetSubj: String; Virtual; {Get message subject}
    Function        GetTextLen: LongInt; Virtual; {Get text length}
    Procedure SetFrom(Str: String); Virtual; {Set message from}
    Procedure SetTo(Str: String); Virtual; {Set message to}
    Procedure SetSubj(Str: String); Virtual; {Set message subject}
    Procedure SetDate(Str: String); Virtual; {Set message date}
    Procedure SetTime(Str: String); Virtual; {Set message time}
    Function        GetDate: String; Virtual; {Get message date mm-dd-yy}
    Function        GetTime: String; Virtual; {Get message time hh:mm}
    Function        GetRefer: LongInt; Virtual; {Get reply to of current msg}
    Procedure SetRefer(Num: LongInt); Virtual; {Set reply to of current msg}
    Function        GetSeeAlso: LongInt; Virtual; {Get see also msg}
    Procedure SetSeeAlso(Num: LongInt); Virtual; {Set see also msg}
    Procedure ReadText(FPos: LongInt); Virtual;
    Function        GetChar: Char; Virtual;
    Function        GetString(MaxLen: Word): String; Virtual;
    Procedure GetOrig(Var Addr: RecEchoMailAddr); Virtual;
    Procedure SetOrig(Addr: RecEchoMailAddr); Virtual;
    Procedure GetDest(Var Addr: RecEchoMailAddr); Virtual;
    Procedure SetDest (Addr: RecEchoMailAddr); Virtual;

    Function GetOrigAddr : RecEchoMailAddr; Virtual;
    Function GetDestAddr : RecEchoMailAddr; Virtual;

    Function        EOM: Boolean; Virtual;
(*
        Function        WasWrap: Boolean; Virtual;
*)
    Procedure InitText; Virtual;
    Procedure DoString(Str: String); Virtual; {Add string to message text}
    Procedure DoChar(Ch: Char); Virtual; {Add character to message text}
    Procedure DoStringLn(Str: String); Virtual; {Add string and newline to msg text}
    Function  WriteMsg: Word; Virtual; {Write msg to msg base}
    Procedure ReadIdx; Virtual;
    Procedure WriteIdx; Virtual;
    Procedure SeekFirst(MsgNum: LongInt); Virtual; {Seeks to 1st msg >= MsgNum}
    Function        GetMsgNum: LongInt; Virtual;
    Procedure SeekNext; Virtual;
    Procedure SeekPrior; Virtual;
    Function        SeekFound: Boolean; Virtual;
    Function        GetIdxFramePos: LongInt; Virtual;
    Function        GetIdxHash: LongInt; Virtual;
    Function        IsLocal: Boolean; Virtual; {Is current msg local}
    Function        IsCrash: Boolean; Virtual; {Is current msg crash}
    Function        IsKillSent: Boolean; Virtual; {Is current msg kill sent}
    Function        IsSent: Boolean; Virtual; {Is current msg sent}
    Function        IsFAttach: Boolean; Virtual; {Is current msg file attach}
//        Function        IsReqRct: Boolean; Virtual; {Is current msg request receipt}
//        Function        IsReqAud: Boolean; Virtual; {Is current msg request audit}
//        Function        IsRetRct: Boolean; Virtual; {Is current msg a return receipt}
    Function        IsFileReq: Boolean; Virtual; {Is current msg a file request}
    Function        IsRcvd: Boolean; Virtual; {Is current msg received}
    Function        IsPriv: Boolean; Virtual; {Is current msg priviledged/private}
    Function        IsDeleted: Boolean; Virtual; {Is current msg deleted}
    Procedure SetAttr(St: Boolean; Mask: LongInt); Virtual; {Set attribute}
    Procedure SetLocal(St: Boolean); Virtual; {Set local status}
    Procedure SetRcvd(St: Boolean); Virtual; {Set received status}
    Procedure SetPriv(St: Boolean); Virtual; {Set priveledge vs public status}
    Procedure SetCrash(St: Boolean); Virtual; {Set crash netmail status}
    Procedure SetHold (ST: Boolean); Virtual;
    Procedure SetKillSent(St: Boolean); Virtual; {Set kill/sent netmail status}
    Procedure SetSent(St: Boolean); Virtual; {Set sent netmail status}
    Procedure SetFAttach(St: Boolean); Virtual; {Set file attach status}
    Procedure SetReqRct(St: Boolean); Virtual; {Set request receipt status}
    Procedure SetReqAud(St: Boolean); Virtual; {Set request audit status}
    Procedure SetRetRct(St: Boolean); Virtual; {Set return receipt status}
    Procedure SetFileReq(St: Boolean); Virtual; {Set file request status}
    Procedure MsgStartUp; Virtual; {Set up message}
    Procedure MsgTxtStartUp; Virtual; {Set up for msg text}
    Procedure SetMailType(MT: MsgMailType); Virtual; {Set message base type}
//        Function        GetSubArea: Word; Virtual; {Get sub area number}
    Procedure ReWriteHdr; Virtual; {Rewrite msg header after changes}
    Procedure DeleteMsg; Virtual; {Delete current message}
    Procedure LoadFree; Virtual; {Load freelist into memory}
    Function        NumberOfMsgs: LongInt; Virtual; {Number of messages}
    Procedure SetEcho(ES: Boolean); Virtual; {Set echo status}
    Function        IsEchoed: Boolean; Virtual; {Is current msg unmoved echomail msg}
    Function        GetLastRead(UNum: LongInt): LongInt; Virtual; {Get last read for user num}
    Procedure SetLastRead(UNum: LongInt; LR: LongInt); Virtual; {Set last read}
    Function        GetMsgLoc: LongInt; Virtual; {To allow reseeking to message}
    Procedure SetMsgLoc(ML: LongInt); Virtual; {Reseek to message}
    Function        IdxHighest: LongInt; Virtual; { *** }
//    Procedure YoursFirst(Name: String; Handle: String); Virtual; {Seek your mail}
//    Procedure YoursNext; Virtual; {Seek next your mail}
//    Function        YoursFound: Boolean; Virtual; {Message found}
    Function        GetMsgDisplayNum: LongInt; Virtual; {Get msg number to display}
    Function        GetTxtPos: LongInt; Virtual; {Get indicator of msg text position}
    Procedure SetTxtPos(TP: LongInt); Virtual; {Set text position}
  End;

Implementation

Uses
  mkcrap,
  m_Strings,
  m_DateTime,
  m_FileIO;

Const
  SqMsgPriv    = $00001;
  SqMsgCrash   = $00002;
  SqMsgRcvd    = $00004;
  SqMsgSent    = $00008;
  SqMsgFile    = $00010;
  SqMsgFwd     = $00020;
  SqMsgOrphan  = $00040;
  SqMsgKill    = $00080;
  SqMsgLocal   = $00100;
  SqMsgHold    = $00200;
  SqMsgXX2     = $00400;
  SqMsgFreq    = $00800;
  SqMsgRrq     = $01000;
  SqMsgCpt     = $02000;
  SqMsgArq     = $04000;
  SqMsgUrg     = $08000;
  SqMsgScanned = $10000;

Constructor TMsgBaseSquish.Init;
Begin
  New (SqInfo);
  New (FreeArray);

  If ((SqInfo = nil) or (FreeArray = nil)) Then Begin
    If SqInfo <> Nil Then Dispose(SqInfo);
    If FreeArray <> Nil Then Dispose(FreeArray);
    Fail;
    Exit;
  End;

  SqInfo^.SqdOpened  := False;
  SqInfo^.SqiOpened  := False;
  SqInfo^.FN         := '';
  SqInfo^.Error      := 0;
  SqInfo^.Locked     := False;
  SqInfo^.FreeLoaded := False;
  SqInfo^.SqiAlloc   := 0;
End;

Destructor TMsgBaseSquish.Done;
Begin
  If SqInfo^.SqdOpened Then SqdClose;
  If SqInfo^.SqiOpened Then SqiClose;

  If SqInfo^.SqIAlloc > 0 Then
    If SqIdx <> Nil Then
      FreeMem (SqIdx, SqInfo^.SqiAlloc * SizeOf(SqIdxType));

  Dispose (FreeArray);
  Dispose (SqInfo);
End;

Procedure TMsgBaseSquish.SetMsgPath (FN: String);
Begin
  SqInfo^.FN := FExpand(FN);

  If Pos('.', SqInfo^.FN) > 0 Then
    SqInfo^.FN := Copy(SqInfo^.FN,1,Pos('.', SqInfo^.FN) - 1);
End;

Function TMsgBaseSquish.OpenMsgBase: Boolean;
Begin
  If SqiOpen Then Begin
    OpenMsgBase := SqdOpen;

    ReadIdx;
  End Else
    OpenMsgBase := False;
End;

Function TMsgBaseSquish.SqdOpen: Boolean;
Var
  NumRead: LongInt;
Begin
  If Not SqInfo^.SqdOpened Then Begin

    Assign(SqInfo^.SqdFile, SqInfo^.FN + '.sqd');

    FileMode := 66; {ReadWrite + DenyNone}

    If Not ioReset(SqInfo^.SqdFile, 1, fmreadwrite + fmdenynone) Then
      SqdOpen := False
    Else Begin
      SqInfo^.SqdOpened := True;
      SqdOpen := True;
      If Not ioBlockRead(SqInfo^.SqdFile, SqInfo^.SqBase, 2, NumRead) Then
        SqdOpen := False
      Else Begin
        If SqInfo^.SqBase.Len = 0 Then
          SqInfo^.SqBase.Len := SqBSize;
          If SqInfo^.SqBase.Len > (SizeOf(SqBaseType) + 100) Then
            SqdOpen := False
          Else Begin
            SqBSize := SqInfo^.SqBase.Len;
            ReadBase;
          End;
      End;
    End;
  End Else
    SqdOpen := True;
End;

Function TMsgBaseSquish.SqiOpen: Boolean;
Begin
  If Not SqInfo^.SqiOpened Then Begin
    Assign (SqInfo^.SqiFile, SqInfo^.FN + '.sqi');

    If Not ioReset(SqInfo^.SqiFile, SizeOf(SqIdxType), fmReadWrite + fmDenyNone) Then
      SqiOpen := False
    Else Begin
      SqInfo^.SqiOpened := True;
      SqiOpen := True;
    End;
  End Else
    SqiOpen := True;
End;

Procedure TMsgBaseSquish.CloseMsgBase;
Begin
  SqdClose;
  SqiClose;

  FileMode := fmRWDN; { shouldn't be needed... }
End;

Function TMsgBaseSquish.CreateMsgBase (MaxMsg: Word; MaxDays: Word): Boolean;
Begin
  If Not SqInfo^.SqdOpened Then Begin
    FillChar(SqInfo^.SqBase, SizeOf(SqInfo^.SqBase), 0);

    SqInfo^.SqBase.Len       := 256;
    SqInfo^.SqBase.SqHdrSize := SqFSize;
    SqInfo^.SqBase.UID       := 1;
    SqInfo^.SqBase.NumMsg    := 0;
    SqInfo^.SqBase.Base      := SqInfo^.FN;

    Str2Az(SqInfo^.FN, 78, SqInfo^.SqBase.Base);

    SqInfo^.SqBase.MaxMsg   := MaxMsg;
    SqInfo^.SqBase.KeepDays := MaxDays;
    SqInfo^.SqBase.EndFrame := SqInfo^.SqBase.Len;

    CreateMsgBase := (SaveFilePos(SqInfo^.FN + '.sqd', SqInfo^.SqBase, SqInfo^.SqBase.Len, 0) = 0);

    SaveFilePos (SqInfo^.FN + '.sqi', SqInfo^.SqBase, 0, 0);
    SaveFilePos (SqInfo^.FN + '.sql', SqInfo^.SqBase, 0, 0);
  End Else
    CreateMsgBase := False;
End;

//Function TMsgBaseSquish.MsgBaseExists: Boolean;
//Begin
//  MsgBaseExists := FileExist(SqInfo^.FN + '.sqd');
//End;

Procedure TMsgBaseSquish.SqdClose;
Begin
  If SqInfo^.SqdOpened Then Close(SqInfo^.SqdFile);

  If IOResult <> 0 Then;

  SqInfo^.SqdOpened := False;
End;

Function TMsgBaseSquish.LockMsgBase: Boolean; {Lock msg base}
Begin
  If Not SqInfo^.Locked Then Begin
    sqinfo^.locked := true;
{                SqInfo^.Locked := shLock(SqInfo^.SqdFile, 0, 1) = 0;}
    LockMsgBase := SqInfo^.Locked;
    ReadBase;
    ReadIdx;
    SqInfo^.FreeLoaded := False;
  End;
End;

Function TMsgBaseSquish.UnLockMsgBase: Boolean; {Unlock msg base}
Begin
  If SqInfo^.Locked Then Begin
    WriteBase;
    WriteIdx;
    sqinfo^.locked := false;
//                SqInfo^.Locked := Not UnLockFile(SqInfo^.SqdFile, 0, 1) < 2;
    UnLockMsgBase  := Not SqInfo^.Locked;
  End;
End;

Procedure TMsgBaseSquish.SqiClose;
Begin
  If SqInfo^.SqiOpened Then Close(SqInfo^.SqiFile);
  If IoResult <> 0 Then;
  SqInfo^.SqiOpened := False;
End;

Procedure TMsgBaseSquish.ReadBase;
Var
  NumRead: LongInt;
Begin
  Seek (SqInfo^.SqdFile, 0);
  If Not ioBlockRead(SqInfo^.SqdFile, SqInfo^.SqBase, SqBSize, NumRead) Then
    SqInfo^.Error := ioCode;

  If SqInfo^.SqBase.SqHdrSize = 0 Then
    SQInfo^.SqBase.SqHdrSize := SqFSize;

  SqFSize := SqInfo^.SqBase.SqHdrSize;
End;

Procedure TMsgBaseSquish.WriteBase;
Var
  Res : LongInt;
Begin
  Seek (SqInfo^.SqdFile, 0);

  If Not ioBlockWrite(SqInfo^.SqdFile, SqInfo^.SqBase, SQBSize, Res) Then
    SqInfo^.Error := ioCode;
End;

Procedure TMsgBaseSquish.StartNewMsg; {Initialize msg header}
Begin
  FillChar (SqInfo^.MsgHdr, SizeOf(SqInfo^.MsgHdr), 0);
  FillChar (SqInfo^.Frame, SizeOf(SqInfo^.Frame),   0);

  SqInfo^.TxtCtr  := 0;
  SqInfo^.StrDate := '';
  SqInfo^.StrTime := '';
End;

Function TMsgBaseSquish.GetFrom: String; {Get message from}
Begin
  GetFrom := strWide2Str(SqInfo^.MsgHdr.MsgFrom, 35);
End;

Function TMsgBaseSquish.GetTo: String; {Get message to}
Begin
  GetTo := strWide2Str(SqInfo^.MsgHdr.MsgTo, 35);
End;

Function TMsgBaseSquish.GetSubj: String; {Get message subject}
Begin
  GetSubj := strWide2Str(SqInfo^.MsgHdr.Subj, 72);
End;

Function TMsgBaseSquish.GetTextLen: LongInt; {Get text length}
Begin
{       GetTextLen := SqInfo^.TxtCtr;}
  GetTextLen := SqInfo^.Frame.MsgLength - 320;
End;

Procedure TMsgBaseSquish.SetFrom(Str: String); {Set message from}
Begin
  Str2Az(Str, 35, SqInfo^.MsgHdr.MsgFrom);
End;

Procedure TMsgBaseSquish.SetTo(Str: String); {Set message to}
Begin
  Str2Az(Str,35, SqInfo^.MsgHdr.MsgTo);
End;

Procedure TMsgBaseSquish.SetSubj(Str: String); {Set message subject}
Begin
  Str2Az(Str,72, SqInfo^.MSgHdr.Subj);
End;

Function TMsgBaseSquish.GetDate: String; {Get message date mm-dd-yy}
Var
  TmpDate: LongInt;
Begin
  TmpDate := (SqInfo^.MsgHdr.DateWritten shr 16) + ((SqInfo^.MsgHdr.DateWritten and $ffff) shl 16);
  GetDate := DateDos2Str(TmpDate, 1);
End;

Function TMsgBaseSquish.GetTime: String; {Get message time hh:mm}
Var
  TmpDate: LongInt;
Begin
  TmpDate := (SqInfo^.MsgHdr.DateWritten shr 16) + ((SqInfo^.MsgHdr.DateWritten and $ffff) shl 16);
  GetTime := TimeDos2Str(TmpDate, 0);
End;

Procedure TMsgBaseSquish.SetDate(Str: String);
Begin
  SqInfo^.StrDate := Copy(Str,1,8);
End;

Procedure TMsgBaseSquish.SetTime(Str: String);
Begin
  SqInfo^.StrTime := Copy(Str,1,8);
End;

Procedure TMsgBaseSquish.GetOrig(Var Addr: RecEchoMailAddr);
Begin
  Addr := SqInfo^.MsgHdr.Orig;
End;

Function TMsgBaseSquish.GetOrigAddr : RecEchoMailAddr;
Begin
  Result := SqInfo^.MsgHdr.Orig;
End;

Procedure TMsgBaseSquish.SetOrig(Addr: RecEchoMailAddr);
Begin
  SqInfo^.MsgHdr.Orig := Addr;
End;

Procedure TMsgBaseSquish.GetDest(Var Addr: RecEchoMailAddr);
Begin
  Addr := SqInfo^.MsgHdr.Dest;
End;

Function TMsgBaseSquish.GetDestAddr : RecEchoMailAddr;
Begin
  Result := SqInfo^.MsgHdr.Dest;
End;

Procedure TMsgBaseSquish.SetDest (Addr: RecEchoMailAddr);
Begin
  SqInfo^.MsgHdr.Dest := Addr;
End;

Function TMsgBaseSquish.SqHashName(Name: String): LongInt;
Var
  Hash    : LongInt;
  Tmp     : LongInt;
  Counter : Word;
Begin
  Hash    := 0;
  Counter := 1;

  While Counter <= Length(Name) Do Begin

    Hash := (Hash shl 4) + Ord(LoCase(Name[Counter]));
    Tmp  := Hash and $F0000000;

    If (Tmp <> 0) Then Hash := (Hash or (Tmp shr 24)) or Tmp;

    Inc (Counter);
  End;

  SqHashName := Hash and $7fffffff;
End;

Procedure TMsgBaseSquish.ReadFrame(FPos: LongInt); {Read frame at FPos}
Begin
  ReadVarFrame (SqInfo^.Frame, FPos);
End;

Procedure TMsgBaseSquish.ReadVarFrame(Var Frame: SqFrameHdrType; FPos: LongInt); {Read frame at FPos}
Var
  NumRead : LongInt;
Begin
  Seek (SqInfo^.SqdFile, FPos);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If Not ioBlockRead (SqInfo^.SqdFile, Frame, SizeOf(SqFrameHdrType), NumRead) Then
      SqInfo^.Error := ioCode;
  End;
End;

Procedure TMsgBaseSquish.WriteFrame(FPos: LongInt); {Read frame at FPos}
Begin
  WriteVarFrame(SqInfo^.Frame, FPos);
End;

Procedure TMsgBaseSquish.WriteVarFrame(Var Frame: SqFrameHdrType; FPos: LongInt); {Write frame at FPos}
Var
  Res : LongInt;
Begin
  Seek (SqInfo^.SqdFile, FPos);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If Not ioBlockWrite(SqInfo^.SqdFile, Frame, SizeOf(SqFrameHdrType), Res) Then
      SqInfo^.Error := ioCode;
  End;
End;

Procedure TMsgBaseSquish.UnlinkFrame(Var Frame: SqFrameHdrType);
Var
  TmpFrame: SqFrameHdrType;
Begin
  If Frame.PrevFrame <> 0 Then Begin
    ReadVarFrame(TmpFrame, Frame.PrevFrame);

    TmpFrame.NextFrame := Frame.NextFrame;

    WriteVarFrame(TmpFrame, Frame.PrevFrame);
  End;

  If Frame.NextFrame <> 0 Then Begin
    ReadVarFrame(TmpFrame, Frame.NextFrame);

    TmpFrame.PrevFrame := Frame.PrevFrame;

    WriteVarFrame(TmpFrame, Frame.NextFrame);
  End;
End;

Procedure TMsgBaseSquish.LoadFree;
Var
  Count    : Word;
  TmpFrame : SqFrameHdrType;
  TmpPos   : LongInt;
Begin
  For Count := 1 to MaxFree Do Begin
    FreeArray^[Count].FreePos  := 0;
    FreeArray^[Count].FreeSize := 0;
  End;

  SqInfo^.FreeLoaded := True;
  Count              := 0;
  TmpPos             := SqInfo^.SqBase.FirstFree;

  While ((TmpPos <> 0) and (Count < MaxFree)) Do Begin
    ReadVarFrame (TmpFrame, TmpPos);
    Inc          (Count);

    FreeArray^[Count].FreeSize := TmpFrame.FrameLength;
    FreeArray^[Count].FreePos  := TmpPos;
    TmpPos                     := TmpFrame.NextFrame;
  End;

  SqInfo^.HighestFree := Count;
End;

Procedure TMsgBaseSquish.FindFrame (Var FL: LongInt; Var FramePos: LongInt);
Var
  TmpFrame      : SqFrameHdrType;
  BestFoundPos  : LongInt;
  BestFoundSize : LongInt;
  BestIdx       : Word;
  i             : Word;
Begin
  If Not SqInfo^.FreeLoaded Then LoadFree;

  BestFoundPos  := 0;
  BestFoundSize := 0;

  For i := 1 to SqInfo^.HighestFree Do Begin
    If (FreeArray^[i].FreeSize > FL) Then Begin
      If ((BestFoundSize = 0) or (FreeArray^[i].FreeSize < BestFoundSize)) Then Begin
        BestFoundSize := FreeArray^[i].FreeSize;
        BestFoundPos  := FreeArray^[i].FreePos;
        BestIdx       := i;
      End;
    End
  End;

  FramePos := BestFoundPos;

  If FramePos <> 0 Then Begin
    ReadVarFrame(TmpFrame, FramePos);

    FreeArray^[BestIdx].FreePos  := 0;
    FreeArray^[BestIdx].FreeSize := 0;
  End;

  If FramePos = 0 Then Begin
    FL       := 0;
    FramePos := SqInfo^.SqBase.EndFrame;
  End Else Begin
    UnLinkFrame(TmpFrame);

    If TmpFrame.PrevFrame = 0 Then SqInfo^.SqBase.FirstFree := TmpFrame.NextFrame;
    If TmpFrame.NextFrame = 0 Then SqInfo^.SqBase.LastFree  := TmpFrame.PrevFrame;

    FL := TmpFrame.FrameLength;
  End;
End;

Procedure TMsgBaseSquish.LinkFrameNext(Var Frame: SqFrameHdrType; OtherFrame: LongInt; FramePos: LongInt);
Var
  TmpFrame: SqFrameHdrType;
Begin
  If OtherFrame <> 0 Then Begin
    ReadVarFrame (TmpFrame, OtherFrame);

    TmpFrame.NextFrame := FramePos;
    Frame.PrevFrame    := OtherFrame;

    WriteVarFrame (TmpFrame, OtherFrame);
  End;
End;

Procedure TMsgBaseSquish.KillMsg (MsgNum: LongInt);
Var
  i             : Word;
  KillPos       : LongInt;
  IndexPos      : LongInt;
  KillFrame     : SqFrameHdrType;
  TmpFrame      : SqFrameHdrType;
  CurrMove      : LongInt;
  AlreadyLocked : Boolean;
  FreeCtr       : Word;
Begin
  AlreadyLocked := SqInfo^.Locked;

  If Not AlreadyLocked Then
    If LockMsgBase Then;

  If SqIdx = Nil Then
    SqInfo^.Error := 999
  Else Begin
    i := 1;

    While ((i <= SqInfo^.SqBase.NumMsg) and (MsgNum <> SqIdx^[i].UMsgId)) Do
      Inc(i);

    If MsgNum = SqIdx^[i].UMsgId Then Begin
      IndexPos := i;
      KillPos  := SqIdx^[i].Ofs;

      ReadVarFrame (KillFrame, KillPos);

      If KillFrame.PrevFrame = 0 Then
        SqInfo^.SqBase.BeginFrame := KillFrame.NextFrame;

      If KillFrame.NextFrame = 0 Then
        SqInfo^.SqBase.LastFrame := KillFrame.PrevFrame;

      KillFrame.FrameType := sqFrameFree;

      UnLinkFrame (KillFrame);

      If ((SqInfo^.SqBase.FirstFree = 0) or (SqInfo^.SqBase.LastFree = 0)) Then Begin
        SqInfo^.SqBase.FirstFree := KillPos;
        SqInfo^.SqBase.LastFree  := KillPos;
        KillFrame.PrevFrame      := 0;
        KillFrame.NextFrame      := 0;
      End Else Begin
        KillFrame.NextFrame := 0;
        KillFrame.PrevFrame := SqInfo^.SqBase.LastFree;

        ReadVarFrame (TmpFrame, SqInfo^.SqBase.LastFree);

        TmpFrame.NextFrame := KillPos;

        WriteVarFrame(TmpFrame, SqInfo^.SqBase.LastFree);

        SqInfo^.SqBase.LastFree := KillPos;
      End;

      WriteVarFrame(KillFrame, KillPos);

      FreeCtr := 1;

      While ((FreeCtr < MaxFree) and (FreeArray^[FreeCtr].FreePos <> 0)) Do
        Inc(FreeCtr);

      If FreeArray^[FreeCtr].FreePos = 0 Then Begin
        FreeArray^[FreeCtr].FreePos  := KillPos;
        FreeArray^[FreeCtr].FreeSize := KillFrame.FrameLength;
      End;

      If FreeCtr > SqInfo^.HighestFree Then
        SqInfo^.HighestFree := FreeCtr;

      Dec (SqInfo^.SqBase.NumMsg);
      Dec (SqInfo^.SqBase.HighMsg);

      CurrMove := IndexPos;

      While CurrMove <= SqInfo^.SqBase.NumMsg Do Begin
        SqIdx^[CurrMove] := SqIdx^[CurrMove + 1];
        Inc (CurrMove);
      End;
    End;
  End;

  If Not AlreadyLocked Then
    If UnlockMsgBase Then;
End;

Procedure TMsgBaseSquish.ReadMsgHdr(FPos: LongInt); {Read msg hdr for frame at FPos}
Var
  NumRead: LongInt;
Begin
  Seek (SqInfo^.SqdFile, FPos + SqFSize);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If Not ioBlockRead(SqInfo^.SqdFile, SqInfo^.MsgHdr, SizeOf(SqMsgHdrType), NumRead) Then
      SqInfo^.Error := ioCode;
  End;
End;

Procedure TMsgBaseSquish.WriteMsgHdr(FPos: LongInt); {Read msg hdr for frame at FPos}
Var
  Res : LongInt;
Begin
  Seek (SqInfo^.SqdFile, FPos + SqFSize);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If Not ioBlockWrite(SqInfo^.SqdFile, SqInfo^.MsgHdr, SizeOf(SqMsgHdrType), Res) Then
      SqInfo^.Error := ioCode;
  End;
End;

Procedure TMsgBaseSquish.WriteText(FPos: LongInt); {Write text buffer for frame at Fpos}
Var
  Res : LongInt;
Begin
  Seek (SqInfo^.SqdFile, FPos + SqFSize + SqMSize);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If Not ioBlockWrite(SqInfo^.SqdFile, SqInfo^.MsgChars, SqInfo^.TxtCtr, Res) Then
      SqInfo^.Error := ioCode;
  End;
End;

Function TMsgBaseSquish.GetBeginFrame: LongInt; {Get beginning frame pos}
Begin
  GetBeginFrame := SqInfo^.SqBase.BeginFrame;
End;

Function TMsgBaseSquish.GetNextFrame: LongInt; {Get next frame pos}
Begin
  GetNextFrame := SqInfo^.Frame.NextFrame;
End;

Procedure TMsgBaseSquish.ReadText(FPos: LongInt);
Begin
  Seek(SqInfo^.SqdFile, FPos + SqFSize + SqMSize);

  SqInfo^.Error := IoResult;

  If SqInfo^.Error = 0 Then Begin
    If SqInfo^.Frame.MsgLength > SqTxtBufferSize Then
      BlockRead(SqInfo^.SqdFile, SqInfo^.MsgChars, SqTxtBufferSize)
    Else
      BlockRead(SqInfo^.SqdFile, SqInfo^.MsgChars, SqInfo^.Frame.MsgLength);

    SqInfo^.Error := IoResult;
  End;

  SqInfo^.TxtCtr  := 1 + SqInfo^.Frame.ControlLength;
  SqInfo^.MsgDone := False;
  LastSoft        := False;
End;

Procedure TMsgBaseSquish.InitText;
Begin
  SqInfo^.TxtCtr := 0;
End;

Procedure TMsgBaseSquish.DoString (Str: String);
Var
  Count : Word;
Begin
  For Count := 1 to Length(Str) Do
    DoChar(Str[Count]);
End;

Procedure TMsgBaseSquish.DoChar (Ch: Char); {Add character to message text}
Begin
  If SqInfo^.TxtCtr < SqTxtBufferSize Then Begin
    Inc (SqInfo^.TxtCtr);

    SqInfo^.MsgChars[SqInfo^.TxtCtr] := Ch;
  End;
End;

Procedure TMsgBaseSquish.DoStringLn(Str: String); {Add string and newline to msg text}
Begin
  DoString (Str);
  DoChar   (#13);
End;

Procedure TMsgBaseSquish.KillExcess;
Var
        AlreadyLocked: Boolean;
Begin
        AlreadyLocked := SqInfo^.Locked;
        If Not AlreadyLocked Then
                If LockMsgBase Then;
        If SqIdx = Nil Then
                SqInfo^.error := 999
        Else Begin
                If ((SqInfo^.SqBase.MaxMsg > 0) and
                (SqInfo^.SqBase.MaxMsg > SqInfo^.SqBase.SkipMsg)) Then Begin
                        While (SqInfo^.SqBase.NumMsg > SqInfo^.SqBase.MaxMsg) Do
                                KillMsg(SqIdx^[SqInfo^.SqBase.SkipMsg + 1].UMsgId);
                End;
        End;
        If Not AlreadyLocked Then
                If UnlockMsgBase Then;
End;

Function TMsgBaseSquish.WriteMsg: Word; {Write msg to msg base}
Var
  MsgSize       : LongInt;
  FrameSize     : LongInt;
  FramePos      : LongInt;
  TmpFrame      : SqFrameHdrType;
  TmpDate       : LongInt;
  TmpDT         : DateTime;
  TmpStr        : String;
  AlreadyLocked : Boolean;
Begin
  DoChar(#0);

  TmpDT.Year := strS2I(Copy(SqInfo^.StrDate,7,2));

  If TmpDT.Year > 79 Then
    Inc (TmpDT.Year, 1900)
  Else
    Inc (TmpDT.Year, 2000);

  TmpDT.Month := strS2I(Copy(SqInfo^.StrDate,1,2));
  TmpDT.Day   := strS2I(Copy(SqInfo^.StrDate,4,2));
  TmpDt.Hour  := strS2I(Copy(SqInfo^.StrTime,1,2));
  TmpDt.Min   := strS2I(Copy(SqInfo^.StrTime, 4,2));
  TmpDt.Sec   := 0;
  TmpStr      := FormatDate(TmpDT, 'DD NNN YY  ') + Copy(SqInfo^.StrTime, 1, 5) + ':00';

  PackTime (TmpDT, TmpDate);

  SqInfo^.MsgHdr.DateWritten := (TmpDate shr 16) + ((TmpDate and $ffff) shl 16);

  TmpDate := CurDateDos;

  SqInfo^.MsgHdr.DateArrived := (TmpDate shr 16) + ((TmpDate and $ffff) shl 16);

  Str2AZ(TmpStr, 20, SqInfo^.MsgHdr.AZDate);

  AlreadyLocked := SqInfo^.Locked;

  If Not AlreadyLocked Then
    If LockMsgBase Then;

  If SqInfo^.Locked Then Begin
    MsgSize   := SqInfo^.TxtCtr + SqMSize;
    FrameSize := MsgSize;

    FindFrame (FrameSize, FramePos);

    If SqInfo^.SqBase.LastFrame <> 0 Then Begin
      ReadVarFrame (TmpFrame, SqInfo^.SqBase.LastFrame);

      TmpFrame.NextFrame := FramePos;

      WriteVarFrame(TmpFrame, SqInfo^.SqBase.LastFrame);

      TmpFrame.PrevFrame := SqInfo^.SqBase.LastFrame;
    End Else Begin
      SqInfo^.SqBase.BeginFrame := FramePos;
      TmpFrame.PrevFrame        := 0;
    End;

    TmpFrame.Id              := SqHdrId;
    TmpFrame.FrameType       := SqFrameMsg;
    SqInfo^.SqBase.LastFrame := FramePos;
    TmpFrame.NextFrame       := 0;
    TmpFrame.FrameLength     := FrameSize;
    TmpFrame.MsgLength       := MsgSize;
    TmpFrame.ControlLength   := 0;

    If TmpFrame.FrameLength = 0 Then Begin
      TmpFrame.FrameLength    := TmpFrame.MsgLength + 0; {slack to minimize free frames}
      SqInfo^.SqBase.EndFrame := FramePos + SqFSize + TmpFrame.FrameLength;
    End;

    If SqInfo^.SqBase.NumMsg >= SqInfo^.SqiAlloc Then Begin
      WriteIdx;
      ReadIdx;
    End;

    If SqIdx = Nil Then Begin
      SqInfo^.Error := 999;
      WriteMsg      := 999;
    End Else Begin
      WriteVarFrame (TmpFrame, FramePos);
      WriteMsgHdr   (FramePos);
      WriteText     (FramePos);

      Inc (SqInfo^.SqBase.NumMsg);

      SqIdx^[SqInfo^.SqBase.NumMsg].Ofs    := FramePos;
      SqIdx^[SqInfo^.SqBase.NumMsg].UMsgId := SqInfo^.SqBase.UID;
      SqIdx^[SqInfo^.SqBase.NumMsg].Hash   := SqHashName(strWide2Str(SqInfo^.MsgHdr.MsgTo, 35));

      Inc(SqInfo^.SqBase.UId);

      SqInfo^.SqBase.HighMsg := SqInfo^.SqBase.NumMsg;

      KillExcess;

      SqInfo^.CurrIdx := SqInfo^.SqBase.NumMsg;

      WriteMsg := 0;
    End;

    If Not AlreadyLocked Then
      If UnLockMsgBase Then;
  End Else
    WriteMsg := 5;
End;

Function TMsgBaseSquish.GetString (MaxLen: Word): String;
Var
  WPos      : Word;
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

  While ((Not StrDone) And (CurrLen < MaxLen) And (Not SqInfo^.MsgDone)) Do Begin
    TmpCh := GetChar;

    Case TmpCh of
      #00,
      #13 : Begin
              StrDone  := True;
              LastSoft := False;
            End;
      #10,
      #141: ;
      #32 : Begin
              If ((CurrLen <> 0) or (Not StartSoft)) Then Begin
                Inc (CurrLen);
                WLen := CurrLen;
                GetString[CurrLen] := TmpCh;
                WPos := SqInfo^.TxtCtr;
              End Else
                StartSoft := False;
            End;
    Else
      Inc(CurrLen);
      GetString[CurrLen] := TmpCh;
    End;
  End;

  If StrDone Then Begin
    GetString[0] := Chr(CurrLen);
  End Else
    If SqInfo^.MsgDone Then Begin
      GetString[0] := Chr(CurrLen);
    End Else Begin
      If WLen = 0 Then Begin
        GetString[0] := Chr(CurrLen);
        Dec(SqInfo^.TxtCtr);
      End Else Begin
        GetString[0] := Chr(WLen);
        SqInfo^.TxtCtr := WPos;
      End;
    End;
End;

Function TMsgBaseSquish.EOM: Boolean;
Begin
  EOM := (SqInfo^.TxtCtr >= SqInfo^.Frame.MsgLength) or (SqInfo^.MsgChars[SqInfo^.TxtCtr] = #0);
End;

Function TMsgBaseSquish.GetChar: Char;
Begin
  If (SqInfo^.TxtCtr >= SqInfo^.Frame.MsgLength) or (SqInfo^.MsgChars[SqInfo^.TxtCtr] = #0) Then Begin
    GetChar         := #0;
    SqInfo^.MsgDone := True;
  End Else Begin
    GetChar := SqInfo^.MsgChars[SqInfo^.TxtCtr];

    Inc(SqInfo^.TxtCtr);
  End;
End;

Function TMsgBaseSquish.GetHighWater: LongInt; {Get high water umsgid}
Begin
  GetHighWater := LongInt(SqInfo^.SqBase.HighWater);
End;

Function TMsgBaseSquish.GetHighMsgNum: LongInt; {Get highest msg number}
Begin
  GetHighMsgNum := LongInt(SqInfo^.SqBase.Uid) - 1;
End;

Procedure TMsgBaseSquish.ReadIdx;
Var
  NumRead: LongInt;
Begin
  If SqInfo^.SqiAlloc > 0 Then
    If SqIdx <> Nil Then
      FreeMem(SqIdx, SqInfo^.SqiAlloc * SizeOf(SqIdxType));

  SqInfo^.SqiAlloc := FileSize(SqInfo^.SqiFile) + 100;

  If SqInfo^.SqiAlloc > SqIdxArraySize Then
    SqInfo^.SqiAlloc := SqIdxArraySize;

  GetMem (SqIdx, SqInfo^.SqiAlloc * SizeOf(SqIdxType));

  If SqIdx = nil Then
    SqInfo^.Error := 999
  Else Begin
    Seek(SqInfo^.SqiFile, 0);

    If IoResult = 0 Then Begin
      If Not ioBlockRead(SqInfo^.SqiFile, SqIdx^, SqInfo^.SqiAlloc, NumRead) Then
        SqInfo^.Error := ioCode;
    End Else
      SqInfo^.Error := 300;
  End;
End;

Procedure TMsgBaseSquish.WriteIdx;
Var
  Res : LongInt;
Begin
  If SqIdx = nil Then
    SqInfo^.Error := 999
  Else Begin
    Seek     (SqInfo^.SqiFile, 0);
    Truncate (SqInfo^.SqiFile);

    If IoResult = 0 Then Begin
      If Not ioBlockWrite(SqInfo^.SqiFile, SqIdx^, SqInfo^.SqBase.NumMsg, Res) Then
        SqInfo^.Error := ioCode;
    End Else
      SqInfo^.Error := 300;
  End;
End;

Procedure TMsgBaseSquish.SeekFirst(MsgNum: LongInt);
Begin
  SqInfo^.CurrIdx := 1;

  ReadIdx;

  While ((SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg) and (MsgNum > LongInt(SqIdx^[SqInfo^.CurrIdx].UMsgId))) Do
    SeekNext;
End;

Function TMsgBaseSquish.IdxHighest: LongInt;
Var
  i   : Word;
  Tmp : LongInt;
Begin
  Tmp := 0;
  i   := 1;

  While i <= SqInfo^.SqBase.NumMsg Do Begin
    If SqIdx^[i].UMsgId > Tmp Then Tmp := SqIdx^[i].UMsgId;
    Inc(i);
  End;

  IdxHighest := Tmp;
End;

Function TMsgBaseSquish.GetMsgNum: LongInt;
Begin
  If ((SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg) and (SqInfo^.CurrIdx > 0)) Then
    GetMsgNum := LongInt(SqIdx^[SqInfo^.CurrIdx].UMsgId)
  Else
    GetMsgNum := -1;
End;

Procedure TMsgBaseSquish.SeekNext;
Begin
  Inc(SqInfo^.CurrIdx);
End;

Procedure TMsgBaseSquish.SeekPrior;
Begin
  If SqInfo^.CurrIdx > 1 Then
    Dec(SqInfo^.CurrIdx)
  Else
    SqInfo^.CurrIdx := 0;
End;

Function TMsgBaseSquish.SeekFound: Boolean;
Begin
  SeekFound := GetMsgNum >= 0;
End;

Function TMsgBaseSquish.GetIdxFramePos: LongInt;
Begin
  If SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg Then
    GetIdxFramePos := SqIdx^[SqInfo^.CurrIdx].Ofs
  Else
    GetIdxFramePos := -1;
End;

Function TMsgBaseSquish.GetIdxHash: LongInt;
Begin
  If SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg Then
    GetIdxHash := SqIdx^[SqInfo^.CurrIdx].Hash
  Else
    GetIdxHash := 0;
End;

Function TMsgBaseSquish.IsLocal: Boolean; {Is current msg local}
Begin
  IsLocal := ((SqInfo^.MsgHdr.Attr and SqMsgLocal) <> 0);
End;

Function TMsgBaseSquish.IsCrash: Boolean; {Is current msg crash}
Begin
  IsCrash := ((SqInfo^.MsgHdr.Attr and SqMsgCrash) <> 0);
End;

Function TMsgBaseSquish.IsKillSent: Boolean; {Is current msg kill sent}
Begin
  IsKillSent := ((SqInfo^.MsgHdr.Attr and SqMsgKill) <> 0);
End;

Function TMsgBaseSquish.IsSent: Boolean; {Is current msg sent}
Begin
  IsSent := ((SqInfo^.MsgHdr.Attr and SqMsgSent) <> 0);
End;

Function TMsgBaseSquish.IsFAttach: Boolean; {Is current msg file attach}
Begin
  IsFAttach := ((SqInfo^.MsgHdr.Attr and SqMsgFile) <> 0);
End;

Function TMsgBaseSquish.IsFileReq: Boolean; {Is current msg a file request}
Begin
  IsFileReq := ((SqInfo^.MsgHdr.Attr and SqMsgFreq) <> 0);
End;

Function TMsgBaseSquish.IsRcvd: Boolean; {Is current msg received}
Begin
  IsRcvd := ((SqInfo^.MsgHdr.Attr and SqMsgRcvd) <> 0);
End;

Function TMsgBaseSquish.IsPriv: Boolean; {Is current msg priviledged/private}
Begin
  IsPriv := ((SqInfo^.MsgHdr.Attr and SqMsgPriv) <> 0);
End;

Function TMsgBaseSquish.IsEchoed: Boolean;
Begin
        IsEchoed := ((SqInfo^.MsgHdr.Attr and SqMsgScanned) = 0);
End;

Function TMsgBaseSquish.IsDeleted: Boolean; {Is current msg deleted}
Begin
  IsDeleted := False;
End;

Function TMsgBaseSquish.GetRefer: LongInt; {Get reply to of current msg}
Begin
  GetRefer := LongInt(SqInfo^.MsgHdr.ReplyTo);
End;

Procedure TMsgBaseSquish.SetRefer(Num: LongInt); {Set reply to of current msg}
Begin
  SqInfo^.MsgHdr.ReplyTo := LongInt(Num);
End;

Function TMsgBaseSquish.GetSeeAlso: LongInt; {Get see also msg}
Begin
  GetSeeAlso := LongInt(SqInfo^.MsgHdr.Replies[1]);
End;

Procedure TMsgBaseSquish.SetSeeAlso(Num: LongInt); {Set see also msg}
Begin
  SqInfo^.MsgHdr.Replies[1] := LongInt(Num);
End;

Procedure TMsgBaseSquish.SetAttr(St: Boolean; Mask: LongInt); {Set attribute}
Begin
  If St Then
    SqInfo^.MsgHdr.Attr := SqInfo^.MsgHdr.Attr or Mask
  Else
    SqInfo^.MsgHdr.Attr := SqInfo^.MsgHdr.Attr and (Not Mask);
End;

Procedure TMsgBaseSquish.SetLocal(St: Boolean); {Set local status}
Begin
  SetAttr(St, SqMsgLocal);
End;

Procedure TMsgBaseSquish.SetRcvd(St: Boolean); {Set received status}
Begin
  SetAttr(St, SqMsgRcvd);
End;

Procedure TMsgBaseSquish.SetPriv(St: Boolean); {Set priveledge vs public status}
Begin
  SetAttr(St, SqMsgPriv);
End;

Procedure TMsgBaseSquish.SetEcho(ES: Boolean);
Begin
  SetAttr(Not ES, SqMsgScanned);
End;

Procedure TMsgBaseSquish.SetCrash(St: Boolean); {Set crash netmail status}
Begin
  SetAttr(St, SqMsgCrash);
End;

Procedure TMsgBaseSquish.SetHold (ST: Boolean);
Begin
  SetAttr (ST, SqMsgHold);
End;

Procedure TMsgBaseSquish.SetKillSent(St: Boolean); {Set kill/sent netmail status}
Begin
  SetAttr(St, SqMsgKill);
End;

Procedure TMsgBaseSquish.SetSent(St: Boolean); {Set sent netmail status}
Begin
  SetAttr(St, SqMsgSent);
End;

Procedure TMsgBaseSquish.SetFAttach(St: Boolean); {Set file attach status}
Begin
  SetAttr(St, SqMsgFile);
End;

Procedure TMsgBaseSquish.SetReqRct(St: Boolean); {Set request receipt status}
Begin
  SetAttr(St, SqMsgRrq);
End;

Procedure TMsgBaseSquish.SetReqAud(St: Boolean); {Set request audit status}
Begin
  SetAttr(St, SqMsgarq);
End;

Procedure TMsgBaseSquish.SetRetRct(St: Boolean); {Set return receipt status}
Begin
  SetAttr(St, SqMsgCpt);
End;

Procedure TMsgBaseSquish.SetFileReq(St: Boolean); {Set file request status}
Begin
  SetAttr(St, SqMsgFreq);
End;

Procedure TMsgBaseSquish.MsgStartUp;
Begin
  SqInfo^.CurrentFramePos := GetIdxFramePos;
  SqInfo^.CurrentUID      := SqIdx^[SqInfo^.CurrIdx].UMsgId;

  ReadFrame  (SqInfo^.CurrentFramePos);
  ReadMsgHdr (SqInfo^.CurrentFramePos);
End;

Procedure TMsgBaseSquish.MsgTxtStartUp;
Begin
  ReadText(SqInfo^.CurrentFramePos);
End;

Procedure TMsgBaseSquish.SetMailType(MT: MsgMailType);
Begin
End;

Procedure TMsgBaseSquish.ReWriteHdr;
Var
  AlreadyLocked : Boolean;
  I             : LongInt;
Begin
  AlreadyLocked := SqInfo^.Locked;

  If Not AlreadyLocked Then
    If LockMsgBase Then;

  WriteFrame  (SqInfo^.CurrentFramePos);
  WriteMsgHdr (SqInfo^.CurrentFramePos);

  i := 1;

  While ((i <= SqInfo^.SqBase.NumMsg) and (SqInfo^.CurrentFramePos <> SqIdx^[i].Ofs)) Do
    Inc(i);

  If SqIdx^[i].Ofs = SqInfo^.CurrentFramePos Then Begin
    If IsRcvd Then
      SqIdx^[i].Hash := 0
    Else
      SqIdx^[i].Hash := SqHashName(SqInfo^.MsgHdr.MsgTo);
  End;

  If Not AlreadyLocked Then
    If UnLockMsgBase Then;
End;

Procedure TMsgBaseSquish.DeleteMsg;
Begin
        KillMsg(SqInfo^.CurrentUID);
End;

Function TMsgBaseSquish.NumberOfMsgs: LongInt;
Var
  TmpBase: SqBaseType;
Begin
   If LoadFilePos(SqInfo^.FN + '.sqd', TmpBase, SizeOf(TmpBase), 0) = 0 Then
     NumberOfMsgs := TmpBase.NumMsg
   Else
     NumberOfMsgs := 0;
End;

Function TMsgBaseSquish.GetLastRead (UNum: LongInt) : LongInt;
Begin
  If LoadFilePos(SqInfo^.FN + '.sql', Result, 4, UNum * 4) <> 0 Then
    Result := 0;
End;

Procedure TMsgBaseSquish.SetLastRead (UNum: LongInt; LR: LongInt);
Begin
  If ((UNum + 1) * SizeOf(LR)) > FileByteSize(SqInfo^.FN + '.sql') Then
    ExtendFile (SqInfo^.FN + '.sql', (UNum + 1) * SizeOf(LR));

  SaveFilePos (SqInfo^.FN + '.sql', LR, SizeOf(LR), UNum * SizeOf(LR));
End;

Function TMsgBaseSquish.GetMsgLoc: LongInt;
Begin
  GetMsgLoc := GetMsgNum;
End;

Procedure TMsgBaseSquish.SetMsgLoc(ML: LongInt);
Begin
  SeekFirst(ML);
End;

(*
Procedure TMsgBaseSquish.YoursFirst (Name: String; Handle: String);
Begin
  SqInfo^.CurrIdx := 0;

  ReadIdx;

  SqInfo^.SName   := strUpper(Name);
  SqInfo^.SHandle := strUpper(Handle);
  SqInfo^.HName   := SqHashName(Name);
  SqInfo^.HHandle := SqHashName(Handle);

  YoursNext;
End;

Procedure TMsgBaseSquish.YoursNext;
Var
  WasFound: Boolean;
Begin
  WasFound := False;

  Inc (SqInfo^.CurrIdx);

  While ((SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg) and (Not WasFound)) Do Begin
    While ((SqIdx^[SqInfo^.CurrIdx].Hash <> SqInfo^.HName) And (SqIdx^[SqInfo^.CurrIdx].Hash <> SqInfo^.HHandle) And (SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg)) Do
      Inc(SqInfo^.CurrIdx);

    If SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg Then Begin
      MsgStartUp;

      If ((Not IsRcvd) and ((strUpper(GetTo) = SqInfo^.SName) or (strUpper(GetTo) = SqInfo^.SHandle))) Then
        WasFound := True
      Else
        Inc (SqInfo^.CurrIdx);
    End;
  End;
End;

Function TMsgBaseSquish.YoursFound: Boolean;
Begin
  YoursFound := SqInfo^.CurrIdx <= SqInfo^.SqBase.NumMsg;
End;
*)
Function TMsgBaseSquish.GetMsgDisplayNum: LongInt;
Begin
  GetMsgDisplayNum := SqInfo^.CurrIdx;
End;

Function TMsgBaseSquish.GetTxtPos: LongInt;
Begin
  GetTxtPos := SqInfo^.TxtCtr;
End;

Procedure TMsgBaseSquish.SetTxtPos(TP: LongInt);
Begin
  SqInfo^.TxtCtr := TP;
End;

Procedure TMsgBaseSquish.EditMsgInit;
Begin
  SqInfo^.TxtCtr := 0;
End;

Procedure TMsgBaseSquish.EditMsgSave;
Begin
(*
        DeleteMsg;

        Dec(SqInfo^.CurrentUID);
        Dec(SqInfo^.SqBase.UId);

        WriteMsg;
*)
  ReWriteHdr;
End;

End.

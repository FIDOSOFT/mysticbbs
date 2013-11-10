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
Unit m_Protocol_Zmodem;

{$I M_OPS.PAS}

{.$DEFINE ZDEBUG}
{.$DEFINE ZCHARLOG}

Interface

// Ported from ZMODEM.C

Uses
  DOS,
  m_CRC,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_Input,
  m_io_Base,
  m_Protocol_Base,
  m_Protocol_Queue;

Const
  ZAttnLen    = 32;
  MaxBufSize  = 1024 * 8;
  RxTimeOut   : Word = 500;

Type
  ZHdrType = Array[0..3] of Byte;
  ZBufType = Array[0..MaxBufSize - 1] of Byte;

  TProtocolZmodem = Class(TProtocolBase)
    CurBufSize : Word;
    UseCRC32   : Boolean;
    EscapeAll  : Boolean;
    LastSent   : Byte;
    Attn       : String[ZAttnLen];
    TxHdr      : ZHdrType;
    TxBuf      : ZBufType;
    RxBuf      : ZBufType;
    RxFrameIdx : SmallInt;
    RxType     : Byte;
    TxPos      : LongInt;
    RxPos      : LongInt;
    RxHdr      : ZHdrType;
    RxBufLen   : SmallInt;
    WrkFile    : File;
    RxBytes    : LongInt;
    RxCount    : LongInt;

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;

    Procedure   QueueReceive; Override;
    Procedure   QueueSend; Override;

    Function    ZInitReceiver        : SmallInt;
    Function    ZGetByte             : SmallInt;
    Function    ZDLRead              : SmallInt;
    Function    ZGetHex              : SmallInt;
    Function    ZSendFile            : SmallInt;
    Function    ZInitSender          : SmallInt;
    Function    ZReceiveFile         : SmallInt;
    Procedure   ZPutHex                (B: Byte);
    Procedure   ZPutLong               (Pos: LongInt);
    Procedure   ZSendHexHeader         (FrameType: Byte);
    Function    ZGetHeader             (Var Hdr: ZHdrType) : SmallInt;
    Function    ZReceiveHexHeader      (Var Hdr: ZHdrType) : SmallInt;
    Function    ZReceiveBinaryHeader   (Var Hdr: ZHdrType) : SmallInt;
    Function    ZReceiveBinaryHeader32 (Var Hdr: ZHdrType) : SmallInt;
    Function    ZGetLong               (Var Hdr: ZHdrType) : LongInt;
    Procedure   ZSendBinaryHeader      (FrameType: Byte);
    Procedure   SendEscaped            (B: SmallInt);
    Procedure   ZSendData              (BufSize : SmallInt; FrameEnd : Byte);
    Function    ZReceiveData           (Var Buf: ZBufType; Len: SmallInt): SmallInt;
    Procedure   ZAckBiBi;
    Procedure   ZEndSender;
    Procedure   DoAbortSequence;
  End;

Implementation

Const
  CANBRK     = 4;
  EscAll     = $0040;
  ZCRC       = 13;
  ZABORT     = 7;
  ZRQINIT    = 0;
  ZPAD       = 42;
  ZDLE       = 24;
  ZHEX       = 66;
  ZACK       = 3;
  ZFIN       = 8;
  ZERROR     = -1;
  ZTIMEOUT   = -2;
  RCDO       = -3;
  ZBIN32     = 67;
  XON        = 17;
  XOFF       = 19;
  CAN        = 24;
  ZCAN       = 16;
  DLE        = 16;
  ZBIN       = 65;
  GOTCAN     = 272;
  ZCRCE      = 104;
  ZCRCG      = 105;
  ZCRCQ      = 106;
  ZCRCW      = 107;
  GOTOR      = 256;
  ZRUB0      = 108;
  ZRUB1      = 109;
  ZP0        = 0;
  ZP1        = 1;
  ZP2        = 2;
  ZP3        = 3;
  CANFDX     = 1;
  CANOVIO    = 2;
  CANBREAK   = 4;
  CANFC32    = 32;
  ZCHALLENGE = 14;
  ZRINIT     = 1;
  ZF0        = 3;
  ZOK        = 0;
  ZSKIP      = 5;
  ZCRESUM    = 3;
  ZDATA      = 10;
  ZFILE      = 4;
  ZRPOS      = 9;
  ZEOF       = 11;
  ZCOMMAND   = 18;
  ZNAK       = 6;
  GOTCRCE    = 360;
  GOTCRCG    = 361;
  GOTCRCQ    = 362;
  GOTCRCW    = 363;
  ZSINIT     = 2;
  ZFREECNT   = 17;
  ZCOMPL     = 15;
  DleHi      = Dle OR $80;
  XonHi      = Xon OR $80;
  XoffHi     = Xoff OR $80;

  CancelStr : String = #24#24#24#24#24#24#24#24#8#8#8#8#8#8#8#8;

{$IFDEF ZDEBUG}
Function HeaderType (B: SmallInt) : String;
Begin
  Case B of
    ZERROR  : Result := 'ZERROR';
    RCDO    : Result := 'RCDO';
    ZTIMEOUT: Result := 'ZTIMEOUT';
    ZBIN    : Result := 'ZBIN';
    ZBIN32  : Result := 'ZBIN32';
    ZHEX    : Result := 'ZHEX';
    CAN     : Result := 'CAN';
    ZRQINIT : Result := 'ZRQINIT';
    ZEOF    : Result := 'ZEOF';
    ZFILE   : Result := 'ZFILE';
    ZRPOS   : Result := 'ZRPOS';
    ZRINIT  : Result := 'ZRINIT';
    ZSINIT  : Result := 'ZSINIT';
    ZFREECNT: Result := 'ZFREECNT';
    ZCOMMAND: Result := 'ZCOMMAND';
    ZCOMPL  : Result := 'ZCOMPL';
    ZFIN    : Result := 'ZFIN';
    ZCAN    : Result := 'ZCAN';
    ZDATA   : Result := 'ZDATA';
    GOTCRCE : Result := 'GOTCRCE';
    GOTCRCG : Result := 'GOTCRCG';
    GOTCRCQ : Result := 'GOTCRCQ';
    GOTCRCW : Result := 'GOTCRCW';
    ZCRC    : Result := 'ZCRC';
  Else
    Result := 'UNKNOWN';
  End;

  Result := Result + ' Ord:' + strI2S(Ord(B));
End;
{$ENDIF}

{$IFDEF ZDEBUG}
Procedure ZLOG (Str: String);
Var
  T : Text;
Begin
  Assign (T, 'zlog.txt');
  {$I-} Append(T); {$I+}

  If IoResult <> 0 Then ReWrite(T);

  WriteLn(T, Str);

  Close(T);
End;
{$ENDIF}

Constructor TProtocolZmodem.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create (C, Q);

  Status.Protocol := 'Zmodem';
  LastSent        := 0;
  EscapeAll       := False;
  Attn            := '';
  CurBufSize      := 1024;
End;

Destructor TProtocolZmodem.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TProtocolZmodem.ZPutLong (Pos : LongInt);
Begin
  TxHdr[ZP0] := Byte(Pos);
  TxHdr[ZP1] := Byte(Pos SHR 8);
  TxHdr[ZP2] := Byte(Pos SHR 16);
  TxHdr[ZP3] := Byte(Pos SHR 24);
End;

Procedure TProtocolZmodem.ZPutHex (B: Byte);
Const
  Digits : Array[0..15] of Char = '0123456789abcdef';
Begin
  Client.BufWriteChar (Digits[B SHR 4]);
  Client.BufWriteChar (Digits[B AND $0F]);
End;

Procedure TProtocolZmodem.ZSendHexHeader (FrameType: Byte);
Var
  CRC   : SmallInt;
  Count : Byte;
Begin
  Client.BufWriteChar (Char(ZPAD));
  Client.BufWriteChar (Char(ZPAD));
  Client.BufWriteChar (Char(ZDLE));
  Client.BufWriteChar (Char(ZHEX));

  ZPutHex (FrameType);

  CRC := Crc16(FrameType, 0);

  For Count := 0 to 3 Do Begin
    ZPutHex (TxHdr[Count]);
    CRC := Crc16(TxHdr[Count], CRC);
  End;

  CRC := Crc16(0, CRC);
  CRC := Crc16(0, CRC);

  ZPutHex (Lo(SmallInt(CRC SHR 8)));
  ZPutHex (Lo(CRC));

  Client.BufWriteChar (#13);
  Client.BufWriteChar (Char(10 or $80));

  If (FrameType <> ZFIN) And (FrameType <> ZACK) Then
    Client.BufWriteChar (Char(XON));

  Client.BufFlush;
End;

Function TProtocolZmodem.ZGetByte : SmallInt;
Begin
  While Connected Do Begin
    Result := ReadByteTimeOut(RxTimeOut);

    If Result < 0 Then Begin
      Result := ZTIMEOUT;
      Exit;
    End;

    Result := Result AND $007F;

    Case Result of
      XON,
      XOFF : Continue;
    Else
      {$IFDEF ZCHARLOG} Zlog('ZGetByte -> ' + strI2S(Result)); {$ENDIF}

      Exit;
    End;
  End;

  Result := RCDO;
End;

Function TProtocolZmodem.ZDLRead : SmallInt;
Begin
  Result := ReadByteTimeOut(RxTimeOut);

  If Result <> ZDLE Then Begin
    {$IFDEF ZCHARLOG} ZLog('ZDLRead -> Did not get ZDLE: ' + strI2S(Result)); {$ENDIF}
    Exit;
  End;

  Result := ReadByteTimeOut(RxTimeOut);

  If Result = CAN Then Begin
    Result := ReadByteTimeOut(RxTimeOut);
    If Result = CAN Then Begin
      Result := ReadByteTimeOut(RxTimeOut);
      If Result = CAN Then
        Result := ReadByteTimeOut(RxTimeOut);
    End
  End;

  Case Result of
    CAN    : Result := GOTCAN;
    ZCRCE,
    ZCRCG,
    ZCRCQ,
    ZCRCW  : Result := (Result OR 256);
    ZRUB0  : Result := $007F;
    ZRUB1  : Result := $00FF;
  Else
//    If ((Result AND $60) = $40) Then
      Result := Result XOR $40
//    Else Begin
//      Result := ZERROR;
//      {$IFDEF ZDEBUG} ZLog('ZDLRead -> Got ZERROR'); {$ENDIF}
//    End;
  End;

  {$IFDEF ZCHARLOG} ZLog('ZDLRead -> ' + HeaderType(Result)); {$ENDIF}
End;

(*
Function TProtocolZmodem.ZDLRead : SmallInt;
Begin
  Result := ReadByteTimeOut(RxTimeOut);

  If Result <> ZDLE Then Exit;

  Result := ReadByteTimeOut(RxTimeOut);

  If Result = CAN Then Begin
    Result := ReadByteTimeOut(RxTimeOut);
    If Result = CAN Then Begin
      Result := ReadByteTimeOut(RxTimeOut);
      If Result = CAN Then
        Result := ReadByteTimeOut(RxTimeOut);
    End
  End;

  Case Result of
    CAN    : Result := GOTCAN;
    ZCRCE,
    ZCRCG,
    ZCRCQ,
    ZCRCW  : Result := (Result OR 256);
    ZRUB0  : Result := $007F;
    ZRUB1  : Result := $00FF;
  Else
    If Result > 0 Then
      If ((Result AND $60) = $40) Then
        Result := Result XOR $40
      Else
        Result := ZERROR;
  End;
End;
*)

Function TProtocolZmodem.ZReceiveBinaryHeader (Var Hdr: ZHdrType) : SmallInt;
Var
  C   : SmallInt;
  N   : SmallInt;
  CRC : Word;
Begin
  C := ZDLRead;

  If C < 0 Then Begin
    ZReceiveBinaryHeader := C;
    Exit;
  End;

  RxType := C;
  CRC    := Crc16(RxType, 0);

  For N := 0 To 3 Do Begin
    C := ZDLRead;

    If Hi(C) <> 0 Then Begin
      ZReceiveBinaryHeader := C;
      Exit;
    End;

    Hdr[N] := Lo(C);
    CRC    := Crc16(Lo(C), CRC);
  End;

  C := ZDLRead;

  If Hi(C) <> 0 Then Begin
    ZReceiveBinaryHeader := C;
    Exit;
  End;

  CRC := Crc16(Lo(C), CRC);

  C := ZDLRead;

  If Hi(C) <> 0 Then Begin
    ZReceiveBinaryHeader := C;
    Exit;
  End;

  CRC := Crc16(Lo(C), CRC);

  If CRC <> 0 Then Begin
    {$IFDEF ZDEBUG} ZLog('ZReceiveBinaryHeader -> CRC error'); {$ENDIF}

    ZReceiveBinaryHeader := ZERROR;
    Exit;
  End;

  ZReceiveBinaryHeader := RxType;
End;

Function TProtocolZmodem.ZReceiveBinaryHeader32 (Var Hdr: ZHdrType) : SmallInt;
Var
  C    : SmallInt;
  Loop : Byte;
  CRC  : LongInt;
Begin
  C := ZDLRead;

  If C < 0 Then Begin
    ZReceiveBinaryHeader32 := C;
    Exit;
  End;

  RxType := C;
  CRC    := Crc32(RxType, LongInt($FFFFFFFF));

  For Loop := 0 To 3 Do Begin
    C := ZDLRead;

    If Hi(C) <> 0 Then Begin
      ZReceiveBinaryHeader32 := C;
      Exit;
    End;

    Hdr[Loop] := Lo(C);
    CRC       := Crc32(Lo(C), CRC);
  End;

  For Loop := 0 To 3 Do Begin
    C := ZDLRead;

    If Hi(C) <> 0 Then Begin
      ZReceiveBinaryHeader32 := C;
      Exit;
    End;

    CRC := Crc32(Lo(C), CRC);
  End;

  If CRC <> LongInt($DEBB20E3) Then Begin
    {$IFDEF ZDEBUG} ZLog('ZReceieveBinaryHeader32 -> CRC error'); {$ENDIF}

    ZReceiveBinaryHeader32 := ZERROR;
    Exit;
  End;

  ZReceiveBinaryHeader32 := RxType;
End;

Procedure TProtocolZmodem.SendEscaped (B: SmallInt);
Begin
  Case B of
    DLE,
    DLEHI,
    XON,
    XONHI,
    XOFF,
    XOFFHI,
    ZDLE :  Begin
              Client.BufWriteChar(Char(ZDLE));
              LastSent := B XOR $40;
            End;
    13,
    13 OR $80 : If EscapeAll And (LastSent AND $7F = Ord('@')) Then Begin
                  Client.BufWriteChar(Char(ZDLE));
                  LastSent := B XOR $40;
                End Else
                  LastSent := B;
    255     : Begin
                Client.BufWriteChar(Char(ZDLE));
                LastSent := ZRUB1;
              End;

  Else
    If (EscapeAll) and ((B AND $60) = 0) Then Begin
      Client.BufWriteChar(Char(ZDLE));
      LastSent := B XOR $40;
    End Else
      LastSent := B;
  End;

  Client.BufWriteChar(Char(LastSent));
End;

Procedure TProtocolZmodem.ZSendBinaryHeader (FrameType : Byte);
Var
  ulCRC : LongInt;
  CRC   : SmallInt;
  Count : SmallInt;
Begin
  Client.BufWriteChar(Char(ZPAD));
  Client.BufWriteChar(Char(ZDLE));

  If UseCRC32 Then Begin
    Client.BufWriteChar(Char(ZBIN32));

    SendEscaped (FrameType);

    ulCRC := Crc32(FrameType, LongInt($FFFFFFFF));

    For Count := 0 to 3 Do Begin
      SendEscaped (TxHdr[Count]);
      ulCRC := Crc32 (TxHdr[Count], ulCRC);
    End;

    ulCRC := Not ulCRC;

    For Count := 0 to 3 Do Begin
      SendEscaped (Byte(ulCRC));
      ulCRC := ulCRC SHR 8;
    End;
  End Else Begin
    Client.BufWriteChar(Char(ZBIN));

    SendEscaped (FrameType);

    CRC := Crc16(FrameType, 0);

    For Count := 0 to 3 Do Begin
      SendEscaped (TxHdr[Count]);
      CRC := Crc16 (TxHdr[Count], CRC);
    End;

    CRC := Crc16(0, CRC);
    CRC := Crc16(0, CRC);

    SendEscaped (Lo(SmallInt(CRC SHR 8)));
    SendEscaped (Lo(CRC));
  End;

  Client.BufFlush;

  If FrameType <> ZDATA Then WaitMS(250); { do we need this? }
End;

Function TProtocolZmodem.ZGetHex : SmallInt;
Var
  C : SmallInt;
  N : SmallInt;
Begin
  C := ZGetByte;

  If C < 0 Then Begin
    ZGetHex := C;
    Exit;
  End;

  N := C - 48;

  If N > 9 Then
    N := N - 39;

  If (N AND $FFF0) <> 0 Then Begin
    ZGetHex := ZERROR;
    Exit;
  End;

  C := ZGetByte;

  If C < 0 Then Begin
    ZGetHex := C;
    Exit;
  End;

  C := C - 48;

  If C > 9 Then
    C := C - 39;

  If (C AND $FFF0) <> 0 Then Begin
    ZGetHex := ZERROR;
    Exit;
  End;

  C := C + (N SHL 4);

  ZGetHex := C;
End;

Function TProtocolZmodem.ZGetLong (Var Hdr: ZHdrType) : LongInt;
Begin
  Result := Hdr[ZP3];
  Result := (Result SHL 8) OR Hdr[ZP2];
  Result := (Result SHL 8) OR Hdr[ZP1];
  Result := (Result SHL 8) OR Hdr[ZP0];
End;

Function TProtocolZmodem.ZReceiveHexHeader (Var Hdr : ZHdrType) : SmallInt;
Var
  N   : SmallInt;
  C   : SmallInt;
  CRC : Word;
Begin
  C := ZGetHex;

  If C < 0 Then Begin
    ZReceiveHexHeader := C;
    Exit;
  End;

  RxType := C;
  CRC    := Crc16(RxType, 0);

  For N := 0 To 3 Do Begin
    C := ZGetHex;

    If C < 0 Then Begin
      ZReceiveHexHeader := C;
      Exit;
    End;

    Hdr[N] := Lo(C);
    CRC    := Crc16(Lo(C), CRC);
  End;

  C := ZGetHex;

  If C < 0 Then Begin
    ZReceiveHexHeader := C;
    Exit;
  End;

  CRC := Crc16(Lo(C), CRC);

  C := ZGetHex;

  If C < 0 Then Begin
    ZReceiveHexHeader := C;
    Exit;
  End;

  CRC := Crc16(Lo(C), CRC);

  If (CRC <> 0) Then Begin
    {$IFDEF ZDEBUG} ZLog('ZReceieveHexHeader -> CRC error'); {$ENDIF}
    ZReceiveHexHeader := ZERROR;
    Exit;
  End;

  If ReadByteTimeOut(20) = 13 Then
    C := ReadByteTimeOut(20);

  ZReceiveHexHeader := RxType;
End;

Function TProtocolZmodem.ZGetHeader (Var Hdr: ZHdrType) : SmallInt;
Label
  Again,
  Again2,
  Splat,
  Finished;
Var
  C         : SmallInt;
  SyncTries : SmallInt;
  CanCount  : SmallInt;
Begin
  SyncTries  := 32;
  CanCount   := 5;
  RxFrameIdx := 0;
  RxType     := 0;

Again:

  C := ZGetByte;

  Case C of
    ZPAD    : Goto Splat;
    RCDO,
    ZTIMEOUT: Goto Finished;
    CAN     : Begin
                Dec (CanCount);
                If CanCount <= 0 Then Begin
                  C := ZCAN;
                  Goto Finished;
                End;
              End;
  Else

Again2:

    Dec (SyncTries);

    If SyncTries = 0 Then Begin
      ZGetHeader := ZERROR;
      Exit;
    End;

    If C <> CAN Then
      CanCount := 5;

    Goto Again;
  End;

  CanCount := 5;

Splat:

  C := ZGetByte;

  Case C of
    ZPAD    : Goto Splat;
    RCDO,
    ZTIMEOUT: Goto Finished;
    ZDLE    : ;
  Else
    Goto Again2;
  End;

  C := ZGetByte;

  {$IFDEF ZDEBUG}
    ZLog ('ZGetHeader -> Checking Frame Index: ' + HeaderType(C));
  {$ENDIF}

  Case C of
    RCDO,
    ZTIMEOUT: Goto Finished;
    ZBIN    : Begin
                RxFrameIdx := ZBIN;
                C := ZReceiveBinaryHeader(Hdr);
              End;
    ZBIN32  : Begin
                RxFrameIdx := ZBIN32;
                C := ZReceiveBinaryHeader32(Hdr);
              End;
    ZHEX    : Begin
                RxFrameIdx := ZHEX;
                C := ZReceiveHexHeader(Hdr);
              End;
    CAN     : Begin
                Dec (CanCount);

                If CanCount <= 0 Then Begin
                  C := ZCAN;
                  Goto Finished;
                End;
                Goto Again2;
              End;
    Else
      Goto Again2;
    End;

  RxPos := ZGetLong(Hdr);

Finished:

  If C = GOTCAN Then C := ZCAN;

  {$IFDEF ZDEBUG} ZLog('ZGetHeader -> Result ' + HeaderType(C)); {$ENDIF}

  Result := C;
End;

Function TProtocolZmodem.ZInitReceiver : SmallInt;
Var
  I : SmallInt;
Begin
  ZPutLong (0);
  ZSendHexHeader (ZRQINIT);

  {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> begin ZRQINIT want ZRINIT'); {$ENDIF}

  For I := 0 to 10 Do Begin
    If AbortTransfer Then Break;

    Case ZGetHeader(RxHdr) of
      ZCHALLENGE: Begin
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> Got ZCHALLENGE'); {$ENDIF}

                    ZPutLong (RxPos);
                    ZSendHexHeader (ZACK);
                  End;
      ZCOMMAND  : Begin
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> Got ZCOMMAND'); {$ENDIF}

                    ZPutLong (0);
                    ZSendHexHeader (ZRQINIT);
                  End;
      ZRINIT    : Begin
                    RxBufLen      := (Word(RxHdr[ZP1]) SHL 8) OR RxHdr[ZP0];
                    UseCrc32      := (RxHdr[ZF0] AND CANFC32) <> 0;
                    EscapeAll     := (RxHdr[ZF0] AND ESCALL) = ESCALL;
                    ZInitReceiver := ZOK;

                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> ZRINIT'); {$ENDIF}
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> CRC32:' + strI2S(Ord(UseCrc32))); {$ENDIF}
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> EscapeAll:' + strI2S(Ord(EscapeAll))); {$ENDIF}
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> BlockSize:' + strI2S(RxBufLen)); {$ENDIF}

                    Exit;
                  End;
      RCDO,
      ZCAN,
      ZTIMEOUT  : Begin
                    {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> Got TIMEOUT/CAN'); {$ENDIF}

                    ZInitReceiver := ZERROR;
                    Exit;
                  End;
      ZRQINIT   : {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> Got ZRQINIT response') {$ENDIF};
    Else
      {$IFDEF ZDEBUG} ZLog('ZInitReceiver -> Unknown sending ZNAK'); {$ENDIF}
      ZSendHexHeader (ZNAK);
    End;
  End;

  Result := ZERROR;
End;

Procedure TProtocolZmodem.ZSendData (BufSize: SmallInt; FrameEnd: Byte);
Var
  ulCRC : LongInt;
  CRC   : SmallInt;
  Count : LongInt;
Begin
  If UseCRC32 Then Begin
    ulCRC := LongInt($FFFFFFFF);

    For Count := 0 to BufSize - 1 Do Begin
      SendEscaped (TxBuf[Count]);
      ulCRC := Crc32(TxBuf[Count], ulCRC);
    End;

    ulCRC := Crc32(FrameEnd, ulCRC);
    ulCRC := Not ulCRC;

    Client.BufWriteChar(Char(ZDLE));
    Client.BufWriteChar(Char(FrameEnd));

    For Count := 0 to 3 Do Begin
      SendEscaped (Byte(ulCRC));
      ulCRC := ulCRC SHR 8;
    End;

  End Else Begin
    CRC := 0;

    For Count := 0 to BufSize - 1 Do Begin
      SendEscaped (TxBuf[Count]);
      CRC := Crc16(TxBuf[Count], CRC);
    End;

    CRC := Crc16(FrameEnd, CRC);

    Client.BufWriteChar(Char(ZDLE));
    Client.BufWriteChar(Char(FrameEnd));

    CRC := Crc16(0, CRC);
    CRC := Crc16(0, CRC);

    SendEscaped (Lo(SmallInt(CRC SHR 8)));
    SendEscaped (Lo(CRC));
	End;

  If FrameEnd = ZCRCW Then Begin
    Client.BufWriteChar(Char(XON));
//    WaitMS(250);
  End;

  Client.BufFlush;
End;

Function TProtocolZmodem.ZSendFile : SmallInt;
Label
  Start;
Var
  FTime      : LongInt;
  TmpStr     : String;
  C          : SmallInt;
  Res        : LongInt;
  FileDone   : Boolean;
  GoodBlks   : Word;
  GoodNeeded : Word;
Begin
  {$IFDEF ZDEBUG} ZLog(''); {$ENDIF}
  {$IFDEF ZDEBUG} ZLog('ZSendFile -> begin'); {$ENDIF}
  {$IFDEF ZDEBUG} ZLog('ZSendFile -> file:' + Queue.QData[Queue.QPos].FileName); {$ENDIF}

  Result := ZERROR;

  Assign (WrkFile, Queue.QData[Queue.QPos]^.FilePath + Queue.QData[Queue.QPos]^.FileName);

  If Not ioReset (WrkFile, 1, fmReadWrite + fmDenyNone) Then Exit;

  GetFTime (WrkFile, FTime);

  Status.FileName  := Queue.QData[Queue.QPos]^.FileName;
  Status.FilePath  := Queue.QData[Queue.QPos]^.FilePath;
  Status.FileSize  := Queue.QData[Queue.QPos]^.FileSize;
  Status.Position  := 0;
  Status.StartPos  := 0;
  Status.StartTime := TimerSeconds;

  StatusUpdate(False, False);

  Repeat
    If AbortTransfer Then Begin
      Close (WrkFile);
      Exit;
    End;

    FillChar (TxHdr, SizeOf(TxHdr), 0);
    FillChar (TxBuf, SizeOf(TxBuf), 0);

    TxHdr[ZF0] := ZCRESUM;
    // do we need to send more stuff here?  maybe that is why syncterm is
    // puking?

    TmpStr := Status.FileName + #0 + strI2S(Status.FileSize);

    Move (TmpStr[1], TxBuf[0], Length(TmpStr));

    ZSendBinaryHeader (ZFILE);
    ZSendData (Length(TmpStr), ZCRCW);

    {$IFDEF ZDEBUG} ZLog('ZSendFile -> Sending ZFILE want ZRPOS'); {$ENDIF}

    WaitMS(500);  // Delay for older terminal programs apparently

    Repeat
      C := ZGetHeader(RxHdr);

      {$IFDEF ZDEBUG} ZLog('ZSendFile -> Handshake header ' + HeaderType(C)); {$ENDIF}

      Case C of
        ZRINIT    : ;
        RCDO,
        ZCAN,
        ZABORT,
        ZFIN,
        ZTIMEOUT  : Begin
                      Close (WrkFile);

                      Exit;
                    End;
        ZSKIP     : Begin
                      Close (WrkFile);
                      ZSendFile := ZSKIP;

                      Exit;
                    End;
        ZCRC :      Begin
                      {$IFDEF ZDEBUG} ZLog('ZSendFile -> Sending File CRC response'); {$ENDIF}

                      ZPutLong(FileCRC32(Status.FilePath + Status.FileName));
                      ZSendHexHeader(ZCRC);

                      RxPos := 0;

                      // SYNCTERM expects ZDATA after a ZCRC i am not sure
                      // this is correct because how do we know the ZPOS from
                      // receiver if it works this way?  zmodem doc isnt very
                      // clear on this.  Lets try it...

                      Goto Start; //Continue;
                    End;
(* is SYNCTERM really asking for the FREENCNT here????? WTF
looks like ZOC might too.  something is wrong with what we expect here.
        ZFREECNT: Begin
                  ZPutLong (LongInt($FFFFFFFF));
                  ZSendHexHeader (ZACK);

                  Continue;
                End;
*)
        ZRPOS     : Goto Start;
      End;
    Until (C <> ZRINIT);
  Until False;

Start:

  {$IFDEF ZDEBUG} ZLog('ZSendFile -> Start transfer at ' + strI2S(RxPos)); {$ENDIF}

  Seek (WrkFile, RxPos);

  TxPos      := RxPos;
  FileDone   := False;
  GoodBlks   := 0;
  GoodNeeded := 0;
  RxBufLen   := CurBufSize;

  Status.Position  := RxPos;
  Status.BlockSize := RxBufLen;

  StatusUpdate(False, False);

  If TxPos < Status.FileSize Then Begin
    ZPutLong (TxPos);
    ZSendBinaryHeader (ZDATA);
  End;

  StatusTimer := TimerSet(StatusCheck);

  While Not EndTransfer Do Begin
    If Not FileDone Then Begin
      ioBlockRead (WrkFile, TxBuf, RxBufLen, Res);

      If Res > 0 Then Begin
        If Res < RxBufLen Then
          ZSendData (Res, ZCRCE)
        Else
          ZSendData (Res, ZCRCG);

        Inc (TxPos, Res);

        Status.Position  := TxPos;
        Status.BlockSize := Res;

        If TimerUp(StatusTimer) Then Begin
          If AbortTransfer Then Break;
          StatusUpdate(False, False);
          StatusTimer := TimerSet(StatusCheck);
        End;

        {$IFDEF ZDEBUG} ZLog('ZSendFile -> Sent ZDATA block position now: ' + strI2S(TxPos)); {$ENDIF}
      End Else Begin
        {$IFDEF ZDEBUG} ZLog('ZSendFile -> Sending ZEOF want ZRINIT'); {$ENDIF}

        FileDone := True;
        ZPutLong (TxPos);
        ZSendBinaryHeader (ZEOF);

        StatusUpdate(False, False);
      End;
    End;

    Inc (GoodBlks);

    If (RxBufLen < CurBufSize) And (GoodBlks > GoodNeeded) Then Begin
      If ((RxBufLen SHL 1) < CurBufSize) Then
        RxBufLen := RxBufLen SHL 1
      Else
        RxBufLen := CurBufSize;

      GoodBlks := 0;
    End;

    While Client.DataWaiting And Not AbortTransfer Do Begin
      {$IFDEF ZDEBUG} ZLog('ZSendFile -> Might have packet response, checking'); {$ENDIF}

      C := ReadByteTimeOut(200);

      If (C = CAN) or (C = ZPAD) Then Begin
        C := ZGetHeader(RxHdr);

        {$IFDEF ZDEBUG} ZLog('ZSendFile -> Got packet response ' + HeaderType(C)); {$ENDIF}

        Case C of
          ZACK    : Continue;
          ZRINIT  : Begin
                      Close (WrkFile);
                      Result := ZOK;
                      Exit;
                    End;
          ZRPOS   : Begin
                      TxPos    := RxPos;
                      FileDone := False;

                      ioSeek (WrkFile, TxPos);

                      {$IFDEF ZDEBUG} ZLog('ZSendFile -> Got ZRPOS Sending ZDATA position: ' + strI2S(TxPos)); {$ENDIF}

//                      Client.PurgeInputData;
//                      Client.PurgeOutputData;

                      If TxPos < Status.FileSize Then Begin
                        ZPutLong (TxPos);
                        ZSendBinaryHeader (ZDATA);
                      End;

                      If RxPos > 0 Then Begin
                        If (RxBufLen SHR 2) > 64 Then
                          RxBufLen := RxBufLen SHR 2
                        Else
                          RxBufLen := 64;

                        GoodBlks := 0;

                        If GoodNeeded SHL 1 > 16 Then
                          GoodNeeded := 16
                        Else
                          GoodNeeded := GoodNeeded SHL 1;
                      End;

                      Status.Position  := RxPos;
                      Status.BlockSize := RxBufLen;

                      StatusUpdate(False, False);

                      Break;
                    End;
          ZSKIP   : Begin
                      Close (WrkFile);
                      ZSendFile := ZSKIP;
                      Exit;
                    End;
        End;
      End {$IFDEF ZDEBUG}Else ZLog('ZSendFile -> Nonsense response: ' + HeaderType(C)) {$ENDIF};
    End;
  End;

  Close (WrkFile);
End;

Procedure TProtocolZmodem.ZEndSender;
Var
  TimeOut : LongInt;
  C       : SmallInt;
Begin
  {$IFDEF ZDEBUG} ZLog('ZEndSender -> begin'); {$ENDIF}

  TimeOut := TimerSet(500);

  While Not AbortTransfer And Not TimerUp(TimeOut) Do Begin
    ZPutLong (0);
    ZSendBinaryHeader (ZFIN);

    If Not Client.DataWaiting Then
      WaitMS(500)
    Else
      C := ZGetHeader(RxHdr);

      {$IFDEF ZDEBUG} ZLog('ZEndSender -> Got header:' + HeaderType(C)); {$ENDIF}

      Case C of
        ZFIN: Begin
                Client.BufWriteStr('OO');
                Client.BufFlush;
                Break;
              End;
        ZCAN,
        ZTIMEOUT,
        RCDO: Break;
      End;
  End;
End;

Procedure TProtocolZmodem.ZAckBiBi;
Var
  Count : Byte;
  Ch    : SmallInt;
Begin
  {$IFDEF ZDEBUG} ZLog('ZAckBiBi -> begin'); {$ENDIF}

  ZPutLong (0);

  // Send ZFIN and wait up to 5 seconds for OO

  For Count := 1 to 5 Do Begin
    If AbortTransfer Then Break;

    ZSendHexHeader (ZFIN);

    Ch := ReadByteTimeOut(100);

    {$IFDEF ZDEBUG} ZLog('ZAckBiBi -> ZFIN response is ' + HeaderType(Ch)); {$ENDIF}

    Case Ch of
      Ord('O')  : Begin
                    {$IFDEF ZDEBUG} ZLog('ZAckBiBi -> Got ending O'); {$ENDIF}
                    ReadByteTimeOut(1);
                    Break;
                  End;
      ZTIMEOUT,
      RCDO      : Break;
    End;
  End;
End;

Function TProtocolZmodem.ZInitSender : SmallInt;
Label
  Again;
Var
  Tmp    : SmallInt;
  N      : SmallInt;
Begin
  UseCRC32      := True;
  Status.Errors := 0;

  {$IFDEF ZDEBUG} ZLog('ZInitSender -> begin'); {$ENDIF}

  For N := 1 to 10 Do Begin
    If AbortTransfer Then Break;

    FillChar (TxHdr, SizeOf(TxHdr), 0); // zero out all flags

    TxHdr[ZF0] := CANFDX OR CANOVIO OR CANFC32 OR CANBRK;

    If EscapeAll Then
      TxHdr[ZF0] := TxHdr[ZF0] or ESCALL;

    {$IFDEF ZDEBUG} ZLog('ZInitSender -> Sending ZRINIT'); {$ENDIF}

    ZSendHexHeader (ZRINIT);

Again:

    If Status.Errors > 10 Then Begin
      ZInitSender := ZERROR;
      Exit;
    End;

    Tmp := ZGetHeader(RxHdr);

    {$IFDEF ZDEBUG} ZLog('ZInitSender -> Got response ' + HeaderType(Tmp)); {$ENDIF}

    Case Tmp of
      ZRQINIT : Continue;
      ZEOF    : Continue;
      ZTIMEOUT: Continue;
      ZFILE   : Begin
                  If ZReceiveData(RxBuf, CurBufSize) = GOTCRCW Then Begin
                    ZInitSender := ZFILE;
                    Exit;
                  End;

                  Inc (Status.Errors);

                  ZSendHexHeader (ZNAK);

                  Goto Again;
                End;
      ZSINIT  : Begin
                  If ZReceiveData (RxBuf, ZATTNLEN) = GOTCRCW Then Begin
                    Attn := '';
                    Tmp  := 0;

                    While RxBuf[Tmp] <> 0 Do Begin
                      Attn := Attn + Chr(RxBuf[Tmp]);
                      Inc (Tmp);
                    End;

                    ZPutLong (1);
                    ZSendHexHeader (ZACK);
                  End Else
                    ZSendHexHeader (ZNAK);
(*
                  RxBufLen  := (Word(RxHdr[ZP1]) SHL 8) OR RxHdr[ZP0];
                  UseCrc32  := (RxHdr[ZF0] AND CANFC32) <> 0;
                  EscapeAll := (RxHdr[ZF0] AND ESCALL) = ESCALL;

                  {$IFDEF ZDEBUG} ZLog('ZInitSender -> ZSINIT'); {$ENDIF}
                  {$IFDEF ZDEBUG} ZLog('ZInitSender -> CRC32:' + strI2S(Ord(UseCrc32))); {$ENDIF}
                  {$IFDEF ZDEBUG} ZLog('ZInitSender -> EscapeAll:' + strI2S(Ord(EscapeAll))); {$ENDIF}
                  {$IFDEF ZDEBUG} ZLog('ZInitSender -> BlockSize:' + strI2S(RxBufLen)); {$ENDIF}
*)
                  Inc (Status.Errors);

                  Goto Again;
                End;
      ZFREECNT: Begin
                  ZPutLong (LongInt($FFFFFFFF));
                  ZSendHexHeader (ZACK);

                  Goto Again;
                End;
      ZCOMMAND: Begin
                  If ZReceiveData (RxBuf, CurBufSize) = GOTCRCW Then Begin
                    ZPutLong (0);

                    Repeat
                      ZSendHexHeader (ZCOMPL);
                      Inc (Status.Errors);
                    Until (Status.Errors >= 10) or (ZGetHeader(RxHdr) = ZFIN);

                    ZAckBiBi;
                    ZInitSender := ZCOMPL;
                    Exit;
                  End Else
                    ZSendHexHeader (ZNAK);

                  Goto Again;
                End;
      ZCOMPL  : Continue;
      ZFIN    : Begin
                  ZAckBiBi;
                  ZInitSender := ZCOMPL;
                  Exit;
                End;
      RCDO,
      ZCAN    : Begin
                  {$IFDEF ZDEBUG} ZLog('ZInitSender -> Got RCDO/ZCAN'); {$ENDIF}
                  ZInitSender := ZERROR;
                  Exit;
                End;
    End;
  End;

  ZInitSender := ZOK;
End;

Function TProtocolZmodem.ZReceiveData (Var Buf: ZBufType; Len: SmallInt) : SmallInt;
Label
  ErrorCRC16,
  ErrorCRC32;
Var
  C, D  : SmallInt;
  CRC   : SmallInt;
  ulCRC : LongInt;
  Count : SmallInt;
Begin
  RxCount := 0;

  {$IFDEF ZDEBUG} ZLog('ZReceiveData -> begin (frameindex=' + HeaderType(RxFrameIdx) + ')'); {$ENDIF}

  If RxFrameIdx = ZBIN32 Then Begin
    ulCRC := LongInt($FFFFFFFF);

    While (Len >= 0) Do Begin
      C := ZDLRead;

      If Hi(C) <> 0 Then Begin

ErrorCRC32:

        Case C of
          GOTCRCE,
          GOTCRCG,
          GOTCRCQ,
          GOTCRCW : Begin
                      D     := C;
                      ulCRC := Crc32(Lo(C), ulCRC);

                      For Count := 1 to 4 Do Begin
                        C := ZDLRead;

                        If Hi(C) <> 0 Then Goto ErrorCRC32;

                        ulCRC := Crc32(Lo(C), ulCRC);
                      End;

                      If (ulCRC <> LongInt($DEBB20E3)) Then Begin
                        {$IFDEF ZDEBUG} ZLog('ZReceiveData -> CRC32 error'); {$ENDIF}
                        Result := ZERROR;
                        Exit;
                      End;

                      {$IFDEF ZDEBUG} ZLog('ZReceiveData -> Successful packet ' + HeaderType(D) + ' size ' + strI2S(RxCount)); {$ENDIF}

                      Result := D;

                      Exit;
                    End;
          GOTCAN  : Begin
                      ZReceiveData := ZCAN;
                      Exit;
                    End;
        Else
          {$IFDEF ZDEBUG} ZLog('ZReceiveData -> Got bad frame type? ' + HeaderType(C)); {$ENDIF}

          ZReceiveData := C;
          Exit;
        End;
      End;

      Buf[RxCount] := Lo(C);

      Dec (Len);
      Inc (RxCount);

      ulCRC := Crc32(Lo(C), ulCRC);
    End;
  End Else Begin
    CRC := 0;

     While Len >= 0 Do Begin
      C := ZDLRead;

      If Hi(C) <> 0 Then Begin

ErrorCRC16:

        Case C of
          GOTCRCE,
          GOTCRCG,
          GOTCRCQ,
          GOTCRCW : Begin
                      D := C;

                      For Count := 1 to 2 Do Begin
                        CRC := Crc16(Lo(C), CRC);

                        C := ZDLRead;

                        If Hi(C) <> 0 Then Goto ErrorCRC16;
                      End;

                      CRC := Crc16(Lo(C), CRC);

                      If CRC <> 0 Then Begin
                        {$IFDEF ZDEBUG} ZLog('ZReceiveData -> CRC16 error'); {$ENDIF}
                        ZReceiveData := ZERROR
                      End Else
                        ZReceiveData := D;

                      Exit;
                    End;
          GOTCAN  : Begin
                      ZReceiveData := ZCAN;
                      Exit;
                    End;
        Else
          ZReceiveData := C;
          Exit;
        End;

        Buf[RxCount] := Lo(C);

        Inc(RxCount);
        Dec(Len);

        CRC := Crc16(Lo(C), CRC);
      End;
    End;
  End;

  {$IFDEF ZDEBUG}
    ZLog('ZReceiveData -> Long packet (frameidx=' + HeaderType(RxFrameIdx) + '; rxcount=' + strI2S(RxCount));
  {$ENDIF}

  ZReceiveData := ZERROR;
End;

Function TProtocolZmodem.ZReceiveFile : SmallInt;
Label
  NextHeader,
  MoreData;
Var
  Tmp        : LongInt;
  Str        : String;
  FName      : String;
  FSize      : LongInt;
  RetryCount : SmallInt;
  C          : SmallInt;
Begin
  {$IFDEF ZDEBUG} ZLog(''); {$ENDIF}
  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> begin'); {$ENDIF}

  FName   := '';
  Str     := '';
  RxBytes := 0;

  Tmp := 0;
  While RxBuf[Tmp] <> 0 Do Begin
    FName := FName + Chr(RxBuf[Tmp]);
    Inc (Tmp);
  End;

  // Strip path if exists, and leading/trailing spaces
  FName := JustFile(strStripB(FName, ' '));

  Inc (Tmp);

  While (RxBuf[Tmp] <> 32) and (RxBuf[Tmp] <> 0) Do Begin
    Str := Str + Char(RxBuf[Tmp]);
    Inc (Tmp);
  End;

  FSize := strS2I(Str);

  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> File:' + FName); {$ENDIF}
  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> Size:' + strI2S(FSize)); {$ENDIF}

  Queue.Add(False, ReceivePath, FName, '');

  Queue.QData[Queue.QSize]^.FileSize := FSize;
  Queue.QData[Queue.QSize]^.Status   := QueueIntransit;

  Assign (WrkFile, ReceivePath + FName);

  {$I-} Reset (WrkFile, 1); {$I+}

  If IoResult = 0 Then Begin
    If FSize = FileSize(WrkFile) Then Begin
      // Same size file, SKIP it
      Close (WrkFile);

      Queue.QData[Queue.QSize]^.Status := QueueSkipped;

      ZSendHexHeader (ZSKIP);

      ZReceiveFile := ZEOF;

      Exit;
    End Else
    If FileSize(WrkFile) < FSize Then Begin
      // Resume transfer
      RxBytes := FileSize(WrkFile);

      Seek (WrkFile, RxBytes);
    End Else Begin
      // If adding rename/overwrite support do it either
      // but for now we just ZSKIP

      Close (WrkFile);

      Queue.QData[Queue.QSize]^.Status := QueueSkipped;

      ZSendHexHeader (ZSKIP);

      ZReceiveFile := ZEOF;

      Exit;
    End;
  End Else Begin
    {$I-} ReWrite (WrkFile, 1); {$I+}

    If IoResult <> 0 Then Begin
      ZSendHexHeader (ZSKIP);
      ZReceiveFile := ZEOF;

      Exit;
    End;
  End;

  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> Begin data'); {$ENDIF}

  Status.FilePath  := ReceivePath;
  Status.FileName  := FName;
  Status.FileSize  := FSize;
  Status.BlockSize := 0;
  Status.Position  := RxBytes;
  Status.StartTime := TimerSeconds;

  StatusUpdate(False, False);

  RetryCount := 25;

  Queue.QData[Queue.QSize]^.Status := QueueFailed;

  StatusTimer := TimerSet(StatusCheck);

  While Not EndTransfer Do Begin

    {$IFDEF ZDEBUG} ZLog('ZRecvFile -> Sending ZRPOS ' + strI2S(RxBytes)); {$ENDIF}

    Client.PurgeOutputData;

    ZPutLong (RxBytes);
    ZSendBinaryHeader (ZRPOS);

//    Client.BufFlush;

    {$IFDEF UNIX}
    Client.PurgeInputData(100);
    {$ELSE}
    Client.PurgeInputData(100);
    {$ENDIF}

NextHeader:

    C := ZGetHeader(RxHdr);

    {$IFDEF ZDEBUG} ZLog('ZRecvFile -> NextHeader -> Got ' + HeaderType(C)); {$ENDIF}

    Case C of
      ZNAK,
      ZTIMEOUT: Begin
                  Dec (RetryCount);

                  If RetryCount < 0 Then Begin
                    Close (WrkFile);
                    ZReceiveFile := ZERROR;
                    Exit;
                  End;
                End;
      ZFILE   : Begin
                  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> Got ZFILE expected data sending ZRPOS'); {$ENDIF}
                  ZReceiveData(RxBuf, CurBufSize);
                  Continue;
                End;
      ZEOF    : Begin
                  If ZGetLong(RxHdr) <> RxBytes Then Continue;

                  Status.Position  := RxBytes;
                  Status.BlockSize := RxCount;

                  StatusUpdate(False, False);

                  Close (WrkFile);

                  Queue.QData[Queue.QSize]^.Status := QueueSuccess;

                  ZReceiveFile := C;

                  Exit;
                End;
      RCDO    : Begin
                  Close (WrkFile);
                  ZReceiveFile := ZERROR;
                  Exit;
                End;
      ZERROR  : Begin
                  Dec (RetryCount);

                  If RetryCount < 0 Then Begin
                    Close (WrkFile);
                    ZReceiveFile := ZERROR;
                    Exit;
                  End;

                  Client.BufWriteStr(Attn);
                  Client.BufFlush;

                  Continue;
                End;
      ZDATA   : Begin
                  If ZGetLong(RxHdr) <> RxBytes Then Begin
                    {$IFDEF ZDEBUG} ZLog('ZRecvFile -> NextHeader -> ZDATA -> Size not ' + strI2S(RxBytes)); {$ENDIF}

                    Dec(RetryCount);

                    If RetryCount < 0 Then Begin
                      Close (WrkFile);
                      ZReceiveFile := ZERROR;
                      Exit;
                    End;

                    Client.BufWriteStr(Attn);
                    Client.BufFlush;

                    Continue;
                  End;

MoreData:

                  If TimerUp(StatusTimer) Then Begin
                    If AbortTransfer Then Break;

                    StatusUpdate(False, False);

                    StatusTimer := TimerSet(StatusCheck);
                  End;

                  C := ZReceiveData(RxBuf, CurBufSize);

                  {$IFDEF ZDEBUG} ZLog('ZRecvFile -> MoreData -> Got ' + HeaderType(C) + ' want data packet'); {$ENDIF}

                  Case C of { we can combine zreceivedata and case here }
                    ZCAN    : Begin
                                Close (WrkFile);
                                ZReceiveFile := ZERROR;
                                Exit;
                              End;
                    ZERROR  : Begin
                                Dec(RetryCount);

                                If RetryCount < 0 Then Begin
                                  Close (WrkFile);
                                  ZReceiveFile := ZERROR;
                                  Exit;
                                End;

                                Client.BufWriteStr(Attn);
                                Client.BufFlush;
                              End;
                    ZTIMEOUT: Begin
                                Dec(RetryCount);

                                If RetryCount < 0 Then Begin
                                  Close (WrkFile);
                                  ZReceiveFile := ZERROR;
                                  Exit;
                                End;

                                Continue;
                              End;
                    GOTCRCW : Begin
                                RetryCount := 25;

                                BlockWrite (WrkFile, RxBuf, RxCount);

                                RxBytes := RxBytes + RxCount;

                                ZPutLong (RxBytes);
                                ZSendBinaryHeader (ZACK);

                                Status.Position  := RxBytes;
                                Status.BlockSize := RxCount;

                                Goto NextHeader;
                              End;
                    GOTCRCQ : Begin
                                RetryCount := 25;

                                BlockWrite (WrkFile, RxBuf, RxCount);

                                RxBytes := RxBytes + RxCount;

                                ZPutLong (RxBytes);
                                ZSendBinaryHeader (ZACK);

                                Status.Position  := RxBytes;
                                Status.BlockSize := RxCount;

                                Goto MoreData;
                              End;
                    GOTCRCG : Begin
                                RetryCount := 25;

                                BlockWrite (WrkFile, RxBuf, RxCount);

                                Rxbytes := RxBytes + RxCount;

                                Status.Position  := RxBytes;
                                Status.BlockSize := RxCount;

                                Goto MoreData;
                              End;
                    GOTCRCE : Begin
                                RetryCount := 25;

                                BlockWrite (WrkFile, RxBuf, RxCount);

                                RxBytes := RxBytes + RxCount;

                                Status.Position  := RxBytes;
                                Status.BlockSize := RxCount;

                                Goto NextHeader;
                              End;
                  End;
                End;

    End;
  End;

  Close (WrkFile);

  ZReceiveFile := ZERROR;
End;

Procedure TProtocolZmodem.DoAbortSequence;
Begin
  If Not Connected Then Exit;

  {$IFDEF ZDEBUG} ZLog('DoAbortSequence -> begin'); {$ENDIF}

  Client.PurgeInputData(0);
  Client.PurgeOutputData;

  Client.BufWriteStr(Attn);
  Client.BufWriteStr(CancelStr);
  Client.BufFlush;
End;

Procedure TProtocolZmodem.QueueReceive;
Begin
  Status.Sender := False;

  StatusUpdate(True, False);

  RxBufLen := CurBufSize;

  While Not AbortTransfer Do Begin
    If ZInitSender = ZFILE Then Begin
      If ZReceiveFile <> ZEOF Then Break;
    End Else
      Break;
  End;

  If AbortTransfer Then DoAbortSequence;

  {$IFDEF ZDEBUG} Zlog('QueueReceive -> Final status update'); {$ENDIF}

//  StatusUpdate(False, True);
End;

Procedure TProtocolZmodem.QueueSend;
Begin
  Status.Sender := True;

  StatusUpdate (True, False);

  Queue.QPos := 0;

  While Queue.Next And Not AbortTransfer Do Begin
    If Queue.QPos = 1 Then
      If ZInitReceiver <> ZOK Then Break;

    Case ZSendFile of
      ZOK     : Queue.QData[Queue.QPos]^.Status := QueueSuccess;
      ZSKIP   : Queue.QData[Queue.QPos]^.Status := QueueSkipped;
      ZERROR  : Queue.QData[Queue.QPos]^.Status := QueueFailed;
    End;
  End;

  If AbortTransfer Then
    DoAbortSequence
  Else
    ZEndSender;

  StatusUpdate(False, True);
End;

End.

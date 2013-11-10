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
Unit m_Prot_Zmodem;

{$I M_OPS.PAS}

Interface

Uses
  Dos,
  m_CRC,
  m_FileIO,
  m_DateTime,
  m_Strings,
  m_IO_Base,
  m_Prot_Base;

Const
  MaxAttentionLen = 32;
  ZMaxBlockSize   = 8192;
  ZHandshakeWait  = 3000;

  DefFinishWait  : Word = 100;       {Wait time for ZFins, 10 secs}
  DefFinishRetry : Word = 3;         {Retry ZFin 3 times}
  MaxBadBlocks   : Byte = 20;        {Quit if this many bad blocks}

  ZMaxBlk : Array[Boolean] of Word = (1024, 8192);
  ZMaxWrk : Array[Boolean] of Word = (2048, 16384);

  ZPad       = '*';
  ZDle       = ^X;
  ZDleE      = 'X';
  ZBin       = 'A';
  ZHex       = 'B';
  ZBin32     = 'C';
  ZrQinit    = #0;
  ZrInit     = #1;
  ZsInit     = #2;
  ZAck       = #3;
  ZFile      = #4;
  ZSkip      = #5;
  ZNak       = #6;
  ZAbort     = #7;
  ZFin       = #8;
  ZRpos      = #9;
  ZData      = #10;
  ZEof       = #11;
  ZFerr      = #12;
  ZCrc       = #13;
  ZChallenge = #14;
  ZCompl     = #15;
  ZCan       = #16;
  ZFreeCnt   = #17;
  ZCommand   = #18;

//  WriteNewerLonger = 1;          {Transfer if new, newer or longer}
//  WriteCrc         = 2;          {Not supported, same as WriteNewer}
  WriteAppend      = 3;          {Transfer if new, append if exists}
  WriteClobber     = 4;          {Transfer regardless}
  WriteNewer       = 5;          {Transfer if new or newer}
  WriteDifferent   = 6;          {Transfer if new or diff dates/lens}
  WriteProtect     = 7;          {Transfer only if new}

Type
  Str2 = String[2];

  ZmodemStateType = (
    tzInitial,       {0  Allocates buffers, sends zrqinit}
    tzHandshake,     {1  Wait for hdr (zrinit), rsend zrqinit on timout}
    tzGetFile,       {2  Call NextFile, build ZFile packet}
    tzSendFile,      {3  Send ZFile packet}
    tzCheckFile,     {4  Wait for hdr (zrpos), set next state to tzData}
    tzStartData,     {5  Send ZData and next data subpacket}
    tzEscapeData,    {6  Check for header, escape next block}
    tzSendData,      {7  Wait for free space in buffer, send escaped block}
    tzSendEof,       {8  Send eof}
    tzWaitAck,       {9  Wait for Ack on ZCRCW packets}
    tzDrainEof,      {10 Wait for output buffer to drain}
    tzCheckEof,      {11 Wait for hdr (zrinit)}
    tzSendFinish,    {12 Send zfin}
    tzCheckFinish,   {13 Wait for hdr (zfin)}
    tzError,         {14 Cleanup after errors}
    tzCleanup,       {15 Release buffers and other cleanup}
    tzDone,          {16 Signal end of protocol}

    {Receive states}
    rzRqstFile,      {17 Send zrinit}
    rzWaitFile,      {19 Waits for hdr (zrqinit, zrfile, zsinit, etc)}
    rzCollectFile,   {20 Collect file info into work block}
    rzSendInit,      {21 Extract send init info}
    rzSendBlockPrep, {22 Collect post-hexhdr chars}                    {!!.03}
    rzSendBlock,     {23 Collect sendinit block}
    rzSync,          {24 Send ZrPos with current file position}
    rzStartFile,     {25 Extract file info, prepare writing, etc., put zrpos}
    rzStartData,     {26 Wait for hdr (zrdata)}
    rzCollectData,   {27 Collect data subpacket}
    rzGotData,       {28 Got dsp, put it}
    rzWaitEof,       {29 Wait for hdr (zreof)}
    rzEndOfFile,     {30 Close file, log it, etc}
    rzSendFinish,    {31 Send ZFin, goto rzWaitOO}
    rzCollectFinish, {32 Check for OO, goto rzFinish}
    rzError,         {33 Handle errors while file was open}
    rzCleanup,       {35 Clean up buffers, etc.}
    rzDone);         {36 Signal end of protocol}

  HeaderStateType = (
    hsNone,          {Not currently checking for a header}
    hsGotZPad,       {Got initial or second asterisk}
    hsGotZDle,       {Got ZDle}
    hsGotZBin,       {Got start of binary header}
    hsGotZBin32,     {Got start of binary 32 header}
    hsGotZHex,       {Got start of hex header}
    hsGotHeader);    {Got complete header}

  HexHeaderStates = (
    hhFrame,         {Processing frame type char}
    hhPos1,          {Processing 1st position info byte}
    hhPos2,          {Processing 2nd position info byte}
    hhPos3,          {Processing 3rd position info byte}
    hhPos4,          {Processing 4th position info byte}
    hhCrc1,          {Processing 1st CRC byte}
    hhCrc2);         {Processing 2nd CRC byte}

  BinaryHeaderStates = (
    bhFrame,         {Processing frame type char}
    bhPos1,          {Processing 1st position info byte}
    bhPos2,          {Processing 2nd position info byte}
    bhPos3,          {Processing 3rd position info byte}
    bhPos4,          {Processing 1th position info byte}
    bhCrc1,          {Processing 1st CRC byte}
    bhCrc2,          {Processing 2nd CRC byte}
    bhCrc3,          {Processing 3rd CRC byte}
    bhCrc4);         {Processing 4th CRC byte}

  ReceiveBlockStates = (
    rbData,          {Receiving data bytes}
    rbCrc);          {Receiving block check bytes}

  WorkBlockType = Array[1..2 * ZMaxBlockSize] of Char;

  PosFlagsType  = Array[0..3] of Byte;

  ZmodemProtocolPtr = ^ZmodemProtocol;

  ZmodemProtocol = object(AbstractProtocol)
    UseCrc32         : Boolean;         {True when using 32bit CRCs}
    CanCrc32         : Boolean;         {True when Crc32 capable}
    LastFileOfs      : LongInt;         {File position reported by remote}
    AttentionStr     : Array[1..MaxAttentionLen] of Byte;   {Attn string value}
    FileMgmtOpts     : Byte;            {File mgmt opts rqst by sender}
    FileMgmtOverride : Boolean;         {True to override senders file mg opts}
    AllowResume      : Boolean;
    FinishWait       : Word;            {Wait time for ZFin response}
    FinishRetry      : Byte;            {Times to resend ZFin}
    LastFrame        : Char;
    EscapeAll        : Boolean;
    Use8KBlocks      : Boolean;
    TookHit          : Boolean;         {True if we got ZrPos packet}
    GoodAfterBad     : Word;
    ZmodemState      : ZmodemStateType;
    HeaderState      : HeaderStateType;
    ReplyTimer       : LongInt;
    WorkSize         : LongInt;         {Index into working buffer}
    LastBlock        : Boolean;         {True if no more blocks}
    Terminator       : Char;            {Current block type}
    HexByte          : Byte;            {Used to assemble hex byte}
    HexPending       : Boolean;         {True for next char in hex pair}
    EscapePending    : Boolean;         {True for next char in esc pair}
    ControlCharSkip  : Boolean;
    HeaderType       : Char;            {Current header type}
    HexHdrState      : HexHeaderStates; {Current hex header state}
    BinHdrState      : BinaryHeaderStates; {Current binary header state}
    RcvBlockState    : ReceiveBlockStates; {Current receive block state}
    FilesSent        : Boolean;         {True if at least one file sent}
    CanCount         : Byte;            {Track contiguous <cancels>}
    SaveStatus       : Word;            {Maintain status across parts}
    CrcCnt           : Byte;            {Number of CRC chars expected}
    LastStatus       : Word;            {Status to set in zpReceiveBlock}
    OCnt             : Byte;            {Count of O's recvd (for 'OO')}
    DataInTransit    : Word;            {Bytes transmitted in window}
    WasHex           : Boolean;         {True if last header was hex}
    DiscardCnt       : Word;            {Count chars before sendblock}
    DataBlock        : ^DataBlockType;   {Standard data block}
    DataBlockLen     : Word;             {Count of valid data in DataBlock}
    WorkBlock        : ^WorkBlockType;   {Holds fully escaped data block}
    RcvHeader        : PosFlagsType;    {Received header}
    RcvFrame         : Char;            {Type of last received frame}
    TransHeader      : PosFlagsType;    {Header to transmit}
    RcvBuffLen       : Word;
    LastChar         : Char;

    Constructor Init (C: TIOBase; Use8K: Boolean);
    Destructor  Done; Virtual;

    Procedure SetFileMgmtOptions   (Override, SkipNoFile: Boolean; FOpt: Byte);
    Procedure SetFinishWait        (NewWait: Word; NewRetry: Byte);
    Procedure PrepareTransmitPart; Virtual;
    Function  ProtocolTransmitPart : ProtocolStateType; virtual;
    Procedure PrepareReceivePart;  Virtual;
    Function  ProtocolReceivePart  : ProtocolStateType; virtual;
    Procedure UpdateBlockCheck     (CurByte: Byte); virtual;
    Procedure SendBlockCheck;      Virtual;
    Function  VerifyBlockCheck     : Boolean; virtual;
    Procedure CancelTransfer;      Virtual;
    Procedure GetCharStripped      (Var C: Char);
    Procedure PutAttentionString;
    Procedure PutCharHex           (C: Char);
    Procedure PutHexHeader         (FrameType: Char);
    Procedure GetCharEscaped       (Var C: Char);
    Procedure zpGetCharHex         (Var C: Char);
    Function  zpCollectHexHeader   : Boolean;
    Function  zpCollectBinaryHeader (Crc32: Boolean) : Boolean;
    Procedure zpCheckForHeader;
    Procedure apPrepareWriting;    Virtual;
    Procedure apFinishWriting;     Virtual;
    Procedure WriteDataBlock;
    Function  ReceiveBlock         (Var Block: DataBlockType; Var BlockSize: Word; Var Handshake: Char) : Boolean;
    Procedure ExtractFileInfo;
    Procedure InsertFileInfo;      Virtual;
    Procedure ExtractReceiverInfo;
    Procedure PutCharEscaped       (C: Char);
    Function  EscapeCharacter      (C: Char) : Str2;
    Procedure zpPutBinaryHeader    (FrameType : Char);
    Procedure EscapeBlock          (Var Block: DataBlockType; BLen: Word);
    Procedure TransmitBlock;
  End;

Implementation

(*
procedure zlog (s: string);
var
  t : text;
begin
  assign (t, '\dev\code\mystic\zm.log');
  {$I-}append(t); {$I+}
  if ioresult <> 0 then rewrite(t);
  writeln (t, s);
  close (t);
end;
*)

Const
  HexDigits : Array[0..15] of Char = '0123456789abcdef';

  FileMgmtMask = 7;                {Isolate file mgmnt values}
  FileSkipMask = $80;              {Skip file if dest doesn't exist}

//  FileRecover = $03;               {Resume interrupted file transfer}

  ZCrcE      = 'h';                {End  - last data subpacket of file}
  ZCrcG      = 'i';                {Go   - no response necessary}
  ZCrcQ      = 'j';                {Ack  - requests ZACK or ZRPOS}
  ZCrcW      = 'k';                {Wait - sender waits for answer}
  ZRub0      = 'l';                {Translate to $7F}
  ZRub1      = 'm';                {Translate to $FF}

  ZF0 = 3;
  ZF1 = 2;
  ZF2 = 1;
  ZF3 = 0;
  ZP0 = 0;
  ZP1 = 1;
  ZP2 = 2;
  ZP3 = 3;

  CanFdx  = $0001;
  CanOvIO = $0002;
  CanBrk  = $0004;
  CanFc32 = $0020;
  EscAll  = $0040;
  Hibit   = $80;
  cDleHi  = Char(Ord(cDle) + HiBit);
  cXonHi  = Char(Ord(cXon) + HiBit);
  cXoffHi = Char(Ord(cXoff) + HiBit);

Constructor ZmodemProtocol.Init (C: TIOBase; Use8K: Boolean);
Begin
  DataBlock := NIL;
  WorkBlock := NIL;

  AbstractProtocol.Init(C);

  Use8KBlocks := Use8K;

  FillChar(AttentionStr, MaxAttentionLen, 0);

  FileOfs          := 0;
  LastFileOfs      := 0;
  UseCrc32         := True;
  CanCrc32         := True;
  AllowResume      := True;
  BlockLen         := ZMaxBlk[Use8KBlocks];
  FileMgmtOpts     := WriteNewer;
  FileMgmtOverride := False;
  FileOpen         := False;
  HandshakeWait    := ZHandshakeWait;
  TookHit          := False;
  GoodAfterBad     := 0;
  EscapePending    := False;
  HexPending       := False;
  FinishWait       := DefFinishWait;
  FinishRetry      := DefFinishRetry;
  EscapeAll        := False;

  DataBlock := GetMem (ZMaxBlk[Use8KBlocks]);
  WorkBlock := GetMem (ZMaxWrk[Use8KBlocks]);
End;

Destructor ZmodemProtocol.Done;
Begin
  FreeMem (DataBlock, ZMaxBlk[Use8KBlocks]);
  FreeMem (WorkBlock, ZMaxWrk[Use8KBlocks]);

  AbstractProtocol.Done;
End;

Procedure ZmodemProtocol.SetFileMgmtOptions (Override, SkipNoFile: Boolean; FOpt: Byte);
Var
  SkipMask : Byte;
Begin
  FileMgmtOverride := Override;

  If SkipNoFile Then
    SkipMask := $80
  else
    SkipMask := 0;

  FileMgmtOpts := (FOpt and FileMgmtMask) or SkipMask;
End;

Procedure ZModemProtocol.SetFinishWait (NewWait: Word; NewRetry: Byte);
Begin
  If NewWait <> 0 Then
    FinishWait := NewWait;

  FinishRetry := NewRetry;
End;

Procedure ZmodemProtocol.UpdateBlockCheck (CurByte: Byte);
Begin
  If UseCrc32 Then
    BlockCheck := Crc32(CurByte, BlockCheck)
  Else
    BlockCheck := Crc16(CurByte, BlockCheck);
End;

Procedure ZmodemProtocol.SendBlockCheck;
Type
  QB = array[1..4] of char;
Var
  I : Byte;
Begin
  If UseCrc32 Then Begin
    BlockCheck := Not BlockCheck;

    For I := 1 to 4 Do
      PutCharEscaped (QB(BlockCheck)[I]);
  End Else Begin
    UpdateBlockCheck (0);
    UpdateBlockCheck (0);

    PutCharEscaped (Char(Hi(SmallInt(BlockCheck))));
    PutCharEscaped (Char(Lo(SmallInt(BlockCheck))));
  End;
End;

Function ZmodemProtocol.VerifyBlockCheck : Boolean;
Begin
  Result := False;

  If UseCrc32 Then Begin
    If BlockCheck <> LongInt($DEBB20E3) Then
      Exit
  End Else Begin
    UpdateBlockCheck (0);
    UpdateBlockCheck (0);

    If BlockCheck <> 0 Then
      Exit;
  End;

  Result := True;
End;

Procedure ZmodemProtocol.CancelTransfer;
Const
  CancelStr = #24#24#24#24#24#24#24#24#8#8#8#8#8#8#8#8#8#8;
Begin
  APort.PurgeOutputData;
  APort.BufWriteStr(CancelStr);
  APort.BufFlush;

  ProtocolStatus := ecCancelRequested;
End;

Procedure ZmodemProtocol.GetCharStripped (Var C: Char);
Begin
  Repeat
    With APort Do
      If DataWaiting Then
        C := ReadChar
      Else
        ProtocolStatus := ecBufferIsEmpty
  Until Not (C in [cXon, cXoff]) or (ProtocolStatus <> ecOk) or not APort.Connected;

  C := Char(Ord(C) and Ord(#$7F));

  If C = cCan Then Begin
    Inc (CanCount);

    If CanCount >= 5 Then
      ProtocolStatus := ecCancelRequested;
  End Else
    CanCount := 0;
End;

Procedure ZmodemProtocol.PutAttentionString;
Var
  Count : Word;
Begin
  Count := 1;

  While AttentionStr[Count] <> 0 Do Begin
    Case AttentionStr[Count] of
      $DD : ;
      $DE : WaitMS(1000);
    Else
      APort.BufWriteChar(Chr(AttentionStr[Count]));
    End;

    Inc (Count);
  End;

  APort.BufFlush;
End;

Procedure ZmodemProtocol.PutCharHex (C: Char);
Var
  B : Byte Absolute C;
Begin
  APort.BufWriteChar(HexDigits[B shr 4]);
  APort.BufWriteChar(HexDigits[B and $0F]);
End;

Procedure ZmodemProtocol.PutHexHeader (FrameType: Char);
Var
  Check     : Word;
  Count     : Byte;
  SaveCrc32 : Boolean;
Begin
  SaveCrc32      := UseCrc32;
  UseCrc32       := False;
  BlockCheck     := 0;
  ProtocolStatus := ecOK;

  APort.BufWriteStr (ZPAD + ZPAD + ZDLE + ZHEX);

  PutCharHex       (FrameType);
  UpdateBlockCheck (Ord(FrameType));

  For Count := 0 to SizeOf(TransHeader) - 1 Do Begin
    PutCharHex       (Char(TransHeader[Count]));
    UpdateBlockCheck (TransHeader[Count]);
  end;

  UpdateBlockCheck (0);
  UpdateBlockCheck (0);

  Check := Word(BlockCheck);

  PutCharHex (Char(Hi(Check)));
  PutCharHex (Char(Lo(Check)));

  APort.BufWriteChar (cCR);
  APort.BufWriteChar (Chr(Ord(cLF) or $80));

  If (FrameType <> ZFIN) and (FrameType <> ZACK) Then
    APort.BufWriteChar (cXON);

  LastFrame := FrameType;
  UseCrc32  := SaveCrc32;

  APort.BufFlush;
End;

Procedure ZmodemProtocol.GetCharEscaped (Var C: Char);
Label
  Escape;
Begin
  ControlCharSkip := False;
  ProtocolStatus  := ecOK;

  If EscapePending Then
    Goto Escape;

  C := APort.ReadChar;

  Case C of
    cXON,
    cXOFF,
    cXONHI,
    cXOFFHI : Begin
                ControlCharSkip := True;

                Exit;
              End;
    ZDLE    : Begin
                Inc (CanCount);

                If CanCount > 5 Then Begin
                  ProtocolStatus := ecCancelRequested;

                  Exit;
                End;
              End;
  Else
    CanCount := 0;

    Exit;
  End;

Escape:

  If APort.DataWaiting Then Begin
    EscapePending := False;
    C             := APort.ReadChar;

    If C = cCAN Then Begin
      Inc (CanCount);

      If CanCount >= 5 Then
        ProtocolStatus := ecCancelRequested;
    End Else Begin
      CanCount := 0;

      Case C of
        ZCrcE: ProtocolStatus := ecGotCrcE;
        ZCrcG: ProtocolStatus := ecGotCrcG;
        ZCrcQ: ProtocolStatus := ecGotCrcQ;
        ZCrcW: ProtocolStatus := ecGotCrcW;
        ZRub0: C := #$7F;
        ZRub1: C := #$FF;
      Else
        C := Char(Ord(C) xor $40)
      End;
    End;
  End Else
    EscapePending := True;
End;

  procedure ZmodemProtocol.zpGetCharHex(var C : Char);
  label
    Hex;

    function NextHexNibble : Byte;
    var
      B : Byte;
      C : Char;
    begin
      NextHexNibble  := 0;
      ProtocolStatus := ecok;

      C := APort.ReadChar;

      if C = cCan then begin
        Inc(CanCount);
        if CanCount >= 5 then begin
          ProtocolStatus := ecCancelRequested;
          Exit;
        end;
      end else
        CanCount := 0;

      B := Pos(C, HexDigits);
      if B <> 0 then
        Dec(B);

      if B <> 0 then
        NextHexNibble := B
      else
        NextHexNibble := 0;
    end;

  begin
    if HexPending then
      goto Hex;
    HexByte := NextHexNibble shl 4;
Hex:
    if APort.DataWaiting then begin
      HexPending := False;
      HexByte := HexByte + NextHexNibble;
      C := Chr(HexByte);
    end else
      HexPending := True;
  end;

  function ZmodemProtocol.zpCollectHexHeader : Boolean;
  var
    C : Char;
  begin
    zpCollectHexHeader := False;

    if APort.DataWaiting then begin
      zpGetCharHex(C);
      if HexPending then
        Exit;
      if ProtocolStatus = ecCancelRequested then
        Exit;

      if HexHdrState = hhFrame then
        BlockCheck := 0;

      UseCrc32 := False;

      UpdateBlockCheck(Ord(C));

      case HexHdrState of
        hhFrame :
          RcvFrame := C;
        hhPos1..hhPos4 :
          RcvHeader[Ord(HexHdrState)-1] := Ord(C);
        hhCrc1 :
          {just keep going} ;
        hhCrc2 :
          if not VerifyBlockCheck then begin
            ProtocolStatus := ecBlockCheckError;
            Inc(TotalErrors);
            HeaderState := hsNone;
          end else begin
            {Say we got a good header}
            zpCollectHexHeader := True;
          end;
      end;

      if (HexHdrState < High(HexHdrState)) then
        Inc(HexHdrState)
         else HexHdrState := Low(HexHdrState);

    end;
  end;

  function ZmodemProtocol.zpCollectBinaryHeader(Crc32 : Boolean) : Boolean;
  var
    C : Char;
  begin
    zpCollectBinaryHeader := False;

    if APort.DataWaiting then begin
      GetCharEscaped(C);
      if EscapePending or ControlCharSkip then                         {!!.01}
        Exit;
      if ProtocolStatus = ecCancelRequested then
        Exit;

      {Init block check on startup}
      if BinHdrState = bhFrame then begin
        UseCrc32 := Crc32;
        if UseCrc32 then
          BlockCheck := LongInt($FFFFFFFF)
        else
          BlockCheck := 0;
      end;

      {Always update the block check}
      UpdateBlockCheck(Ord(C));

      {Process this character}
      case BinHdrState of
        bhFrame :
          RcvFrame := C;
        bhPos1..bhPos4 :
          RcvHeader[Ord(BinHdrState)-1] := Ord(C);
        bhCrc2 :
          if not UseCrc32 then begin
            if not VerifyBlockCheck then begin
              ProtocolStatus := ecBlockCheckError;
              Inc(TotalErrors);
              HeaderState := hsNone;
            end else begin
              {Say we got a good header}
              zpCollectBinaryHeader := True;
            end;
          end;
        bhCrc4 :
          {Check the Crc value}
          if not VerifyBlockCheck then begin
            ProtocolStatus := ecBlockCheckError;
            Inc(TotalErrors);
            HeaderState := hsNone;
          end else begin
            {Say we got a good header}
            zpCollectBinaryHeader := True;
          end;
      end;

      if (BinHdrState < High(BinHdrState)) then
        Inc(BinHdrState)
         else BinhdrState := Low(BinHdrState);
    end;
  end;

  procedure ZmodemProtocol.zpCheckForHeader;
  var
    C : Char;
  begin
    ProtocolStatus := ecNoHeader;

    while aport.connected and APort.DataWaiting do begin
      {Only get the next char if we don't know the header type yet}
      case HeaderState of
        hsNone, hsGotZPad, hsGotZDle :
          begin
            GetCharStripped(C); // only used here
            if ProtocolStatus = ecCancelRequested then
              Exit;
          end;
      end;

      ProtocolStatus := ecNoHeader;

      case HeaderState of
        hsNone :
          if C = ZPad then
            HeaderState := hsGotZPad;
        hsGotZPad :
          case C of
            ZPad : ;
            ZDle : HeaderState := hsGotZDle;
            else   HeaderState := hsNone;
          end;
        hsGotZDle :
          case C of
            ZBin   :
              begin
                WasHex := False;
                HeaderState := hsGotZBin;
                BinHdrState := bhFrame;
                EscapePending := False;
                if zpCollectBinaryHeader(False) then
                  HeaderState := hsGotHeader;
              end;
            ZBin32 :
              begin
                WasHex := False;
                HeaderState := hsGotZBin32;
                BinHdrState := bhFrame;
                EscapePending := False;
                if zpCollectBinaryHeader(True) then
                  HeaderState := hsGotHeader;
              end;
            ZHex   :
              begin
                WasHex := True;
                HeaderState := hsGotZHex;
                HexHdrState := hhFrame;
                HexPending := False;
                if zpCollectHexHeader then
                  HeaderState := hsGotHeader;
              end;
            else
              HeaderState := hsNone;
          end;
        hsGotZBin :
          if zpCollectBinaryHeader(False) then
            HeaderState := hsGotHeader;
        hsGotZBin32 :
          if zpCollectBinaryHeader(True) then
            HeaderState := hsGotHeader;
        hsGotZHex :
          if zpCollectHexHeader then
            HeaderState := hsGotHeader;
      end;

      if HeaderState = hsGotHeader then begin
        ProtocolStatus := ecGotHeader;
        case LastFrame of
          ZrPos, ZAck, ZData, ZEof :
             LastFileOfs := LongInt(RcvHeader);
        end;

        LastFrame := RcvFrame;

        Exit;
      end;

      if (ProtocolStatus <> ecOk) and (ProtocolStatus <> ecNoHeader) then
        Exit;
    end;
  end;

Function ZmodemProtocol.ReceiveBlock (Var Block: DataBlockType; Var BlockSize: Word; Var Handshake: Char) : Boolean;
Var
  C : Char;
Begin
  ReceiveBlock := False;

  While APort.DataWaiting Do Begin
    If (DataBlockLen = 0) and (RcvBlockState = rbData) Then Begin
      If UseCrc32 Then
        BlockCheck := LongInt($FFFFFFFF)
      Else
        BlockCheck := 0;
    End;

    GetCharEscaped(C);

    If EscapePending or ControlCharSkip Then
      Exit;

    If ProtocolStatus = ecCancelRequested Then
      Exit;

    UpdateBlockCheck(Ord(C));

    Case RcvBlockState of
      rbData : Case ProtocolStatus of
                 ecOk : Begin
                          Inc (DataBlockLen);

                          If DataBlockLen > BlockLen Then Begin
                            ProtocolStatus := ecLongPacket;

                            Inc (TotalErrors);
                            Inc (BlockErrors);

                            ReceiveBlock := True;

                            Exit;
                          End;

                          Block[DataBlockLen] := C;
                        End;

                 ecGotCrcE,
                 ecGotCrcG,
                 ecGotCrcQ,
                 ecGotCrcW : Begin
                               RcvBlockState := rbCrc;
                               CrcCnt        := 0;
                               LastStatus    := ProtocolStatus;
                             End;
                 ecCancelRequested : Exit;
            Else Begin
              Inc (DataBlockLen);

              If DataBlockLen > BlockLen Then Begin
                ProtocolStatus := ecLongPacket;

                Inc (TotalErrors);
                Inc (BlockErrors);

                ReceiveBlock := True;

                Exit;
              End;

              Block[DataBlockLen] := C;
            End;
          End;

        rbCrc :
          begin
            Inc(CrcCnt);
            if (UseCrc32 and (CrcCnt = 4)) or
               (not UseCrc32 and (CrcCnt = 2)) then begin
              if not VerifyBlockCheck then begin
                Inc(BlockErrors);
                Inc(TotalErrors);
                ProtocolStatus := ecBlockCheckError;
              end else
                ProtocolStatus := LastStatus;

              ReceiveBlock := True;
              Exit;
            end;
          end;
      end;
    end;
  end;

Procedure ZmodemProtocol.ExtractFileInfo;
Var
  Tmp : Word   = 1;
  Str : String = '';
Begin
  PathName := '';

  While DataBlock^[Tmp] <> #0 Do Begin
    PathName := PathName + DataBlock^[Tmp];

    Inc (Tmp);
  End;

  PathName := DestDir + JustFile(PathName);

  Inc (Tmp);

  While (DataBlock^[Tmp] <> #32) and (DataBlock^[Tmp] <> #0) Do Begin
    Str := Str + DataBlock^[Tmp];

    Inc (Tmp);
  End;

  SrcFileLen       := strS2I(Str);
  BytesRemaining   := SrcFileLen;
  BytesTransferred := 0;
End;

  procedure ZmodemProtocol.apPrepareWriting;
    {-Prepare to save protocol blocks (usually opens a file)}
  var
    Result : Word;
    FileExists : Boolean;
    FileLen : LongInt;
//    FileDate : LongInt;
    FileOpt : Byte;
    FileSkip : Boolean;
    SeekPoint : LongInt;
    FileStartOfs : LongInt;


  label
    ExitPoint;

  begin
    ProtocolStatus := ecOk;

    {Set file mgmt options}
    FileSkip := (FileMgmtOpts and FileSkipMask) = FileSkipMask;
    FileOpt := FileMgmtOpts and FileMgmtMask;

    {Does the file exist already?}
    SaveMode := FileMode;                                              {!!.02}
    FileMode := 66;                                   {!!.02}{!!.03}
    Assign(WorkFile, PathName);
    {$i-}
    Reset(WorkFile, 1);
    FileMode := SaveMode;                                              {!!.02}
    Result := IOResult;

    {Exit on errors other than FileNotFound}
    if (Result <> 0) and (Result <> 2) and (Result <> 110) then begin
      ProtocolStatus := Result;
      goto ExitPoint;
    end;

    {Note if file exists, its size and timestamp}
    FileExists := (Result = 0);
    if FileExists then begin
      FileLen := FileSize(WorkFile);
//      GetFTime(WorkFile, FileDate);
//      FileDate := apPackToYMTimeStamp(FileDate);
    end;
    Close(WorkFile);
    if IOResult = 0 then ;

    if FileExists and (SrcFileLen > FileLen) and (AllowResume) then begin
      SeekPoint    := FileLen;
      FileStartOfs := FileLen;
      InitFilePos  := FileLen;
    end else begin
      InitFilePos := 0;

      if FileSkip and not FileExists then begin
        ProtocolStatus := ecFileDoesntExist;
        goto ExitPoint;
      end;

      SeekPoint    := 0;
      FileStartOfs := 0;

      case FileOpt of
(*
        WriteNewerLonger : {Transfer only if new, newer or longer}
          if FileExists then
            if (SrcFileDate <= FileDate) and
               (SrcFileLen <= FileLen) then begin
              ProtocolStatus := ecCantWriteFile;
              goto ExitPoint;
          end;
*)
        WriteAppend :      {Transfer regardless, append if exists}
          if FileExists then
            SeekPoint := FileLen;
        WriteClobber :     {Transfer regardless, overwrite} ;
          {Nothing to do, this is the normal behavior}
        WriteDifferent :   {Transfer only if new, size diff, or dates diff}
          if FileExists then
            if {(SrcFileDate = FileDate) and}
               (SrcFileLen = FileLen) then begin
              ProtocolStatus := ecCantWriteFile;
              goto ExitPoint;
            end;
        WriteProtect :     {Transfer only if dest file doesn't exist}
          if FileExists then begin
            ProtocolStatus := ecCantWriteFile;
            goto ExitPoint;
          end;
(*
        WriteCrc,          {Not supported, treat as WriteNewer}
        WriteNewer :       {Transfer only if new or newer}
          if FileExists then
            if SrcFileDate <= FileDate then begin
              ProtocolStatus := ecCantWriteFile;
              goto ExitPoint;
            end;
*)
      end;
    end;

    {Rewrite or append to file}
    Assign(WorkFile, Pathname);
    if SeekPoint = 0 then begin
      {New or overwriting destination file}
      Rewrite(WorkFile, 1);
    end else begin
      {Appending to file}
      {$i-}
      Reset(WorkFile, 1);
      Seek(WorkFile, SeekPoint);
    end;
    Result := IOResult;
    if Result <> 0 then begin
      ProtocolStatus := Result;
      goto ExitPoint;
    end;

    {Initialized the buffer management vars}
    FileOfs := FileStartOfs;
    StartOfs := FileStartOfs;
    LastOfs := FileStartOfs;
    EndOfs := StartOfs + FileBufferSize;
    FileOpen := True;
    Exit;

ExitPoint:
    Close(WorkFile);
    if IOResult <> 0 then ;
    {FreeMemCheck(FileBuffer, FileBufferSize);}                        {!!.01}
  end;

  procedure ZmodemProtocol.apFinishWriting;
    {-Cleans up after saving all protocol blocks}
  var
    BytesToWrite : Word;
    BytesWritten : LongInt;
    Result : Word;
//    PackTime : LongInt;
  begin
    if FileOpen then begin
      {Error or end-of-file, commit buffer}
      BytesToWrite := FileOfs - StartOfs;
      BlockWrite(WorkFile, FileBuffer^, BytesToWrite, BytesWritten);
      Result := IOResult;
      if (Result <> 0) or (BytesToWrite <> BytesWritten) then
        ProtocolStatus := Result;

      {Set the timestamp to that of the source file}
//      PackTime := apYMTimeStampToPack(SrcFileDate);
//      SetFTime(WorkFile, PackTime);

      {Clean up}
      Close(WorkFile);
      if IOResult <> 0 then ;
      {FreeMemCheck(FileBuffer, FileBufferSize);}                      {!!.01}
      FileOpen := False;
    end;
  end;

Procedure ZmodemProtocol.WriteDataBlock;
Var
  Failed     : Boolean;
  TempStatus : Word;
Begin
  Failed := apWriteProtocolBlock (DataBlock^, DataBlockLen);

  If Failed Then Begin
    TempStatus := ProtocolStatus;

    CancelTransfer;

    ProtocolStatus := TempStatus;
  End Else Begin
    Inc (FileOfs,          DataBlockLen);
    Dec (BytesRemaining,   DataBlockLen);
    Inc (BytesTransferred, DataBlockLen);
  End;
End;

Procedure ZmodemProtocol.PrepareReceivePart;
Begin
  GotOneFile := False;

  apResetStatus;
  apShowFirstStatus;

  StatusTimer := TimerSet(StatusInterval);

  APort.PurgeInputData(0);

  HeaderType     := ZrInit;
  ZmodemState    := rzRqstFile;
  HeaderState    := hsNone;
  SaveStatus     := ecOk;
  ProtocolStatus := ecOk;
End;

Function ZmodemProtocol.ProtocolReceivePart : ProtocolStateType;
Label
  ExitPoint;
Var
  BlockSize : Word;
  Handshake : Char;
  C         : Char;
Begin
  ProtocolStatus := SaveStatus;

  If {ForceStatus or} TimerUp(StatusTimer) Then Begin
    If Not APort.Connected or (apHandleAbort and (ProtocolStatus <> ecCancelRequested)) Then Begin
      CancelTransfer;

      ZmodemState := rzError;
    End;

    apUserStatus(False, False);

    StatusTimer := TimerSet(StatusInterval);
    ForceStatus := False;
  End;

  Case ZmodemState of
    rzWaitFile,
    rzStartData,
    rzWaitEof    : Begin
                     If Not APort.DataWaiting {And APort.Connected} Then
                       APort.WaitForData(1000);

                     If APort.DataWaiting Then Begin
                       zpCheckForHeader;

                       If ProtocolStatus = ecCancelRequested Then
                         ZmodemState := rzError;
                     End Else If TimerUp(ReplyTimer) Then
                       ProtocolStatus := ecTimeout
                     Else
                       ProtocolStatus := ecNoHeader;
                   End;
  End;

//zlog('main rcv state loop: ' + strI2S(Ord(ZmodemState)));

  Case ZmodemState of

    rzRqstFile:

      Begin
        CanCount             := 0;
        LongInt(TransHeader) := 0;
        TransHeader[ZF0]     := CanFDX or CanOVIO or CanFc32;{ or CanBrk;}

        WaitMS(500);

        PutHexHeader(HeaderType);

        ZmodemState := rzWaitFile;
        HeaderState := hsNone;
        ReplyTimer  := TimerSet(HandshakeWait);
      End;

    rzSendBlockPrep:

      If APort.DataWaiting then begin
        C := APort.ReadChar;

        Inc (DiscardCnt);

        If DiscardCnt = 2 Then
          ZmodemState := rzSendBlock;

      End Else
      If TimerUp(ReplyTimer) Then Begin
        Inc (BlockErrors);
        Inc (TotalErrors);

        If TotalErrors < HandshakeRetry Then
          ZmodemState := rzRqstFile
        Else
          ZmodemState := rzCleanup;
      End;

    rzSendBlock:

      if APort.DataWaiting then begin

          if ReceiveBlock(DataBlock^, BlockSize, Handshake) then
            if ProtocolStatus = ecBlockCheckError then
              {Error receiving block, go try again}
              ZmodemState := rzRqstFile
            else
              {Got block OK, go process}
              ZmodemState := rzSendInit
          else if ProtocolStatus = ecCancelRequested then
            ZmodemState := rzError;
        end else if TimerUp(ReplyTimer) then begin
          Inc(BlockErrors);

          if BlockErrors < HandshakeRetry then begin
            PutHexHeader(ZNak);

            ReplyTimer  := TimerSet(HandshakeWait);
            ZmodemState := rzWaitFile;
            HeaderState := hsNone;
          end else
            ZmodemState := rzCleanup;
        end;

      rzSendInit :
        begin
          Move(DataBlock^, AttentionStr, MaxAttentionLen);

          EscapeAll := (RcvHeader[ZF0] and EscAll) = EscAll;

          PutHexHeader(ZAck);
          ZmodemState := rzWaitFile;

          ReplyTimer := TimerSet(HandshakeWait);
        end;

      rzWaitFile : begin
//      zlog('rzWaitFile -> start');
//      zlog('rzWaitFile -> status=' + stri2s(ProtocolStatus));
        case ProtocolStatus of
          ecGotHeader :
            begin
              case RcvFrame of
                ZrQInit : {Go send ZrInit again}
                  ZmodemState := rzRqstFile;
                ZFile : {Beginning of file transfer attempt}
                  begin
//                  zlog('rzWaitFile --> got zFile');
                    {Save conversion and transport options}
//                    ConvertOpts := RcvHeader[ZF0];
//                    TransportOpts := RcvHeader[ZF2];

                    {Save file mgmt options (if not overridden)}
                    if not FileMgmtOverride then
                      FileMgmtOpts := RcvHeader[ZF1];

                    {Set file mgmt default if none specified}
                    if FileMgmtOpts = 0 then
                      FileMgmtOpts := WriteNewer;

                    {Start collecting the ZFile's data subpacket}
                    ZmodemState := rzCollectFile;
                    BlockErrors := 0;
                    DataBlockLen := 0;
                    RcvBlockState := rbData;
                    ReplyTimer := TimerSet(HandShakeWait);
                  end;

                ZSInit :
                  begin
                    BlockErrors := 0;
                    DataBlockLen := 0;
                    RcvBlockState := rbData;
                    ReplyTimer := TimerSet(HandShakeWait);
                    if WasHex then begin
                      ZmodemState := rzSendBlockPrep;
                      DiscardCnt := 0;
                    end else
                      ZmodemState := rzSendBlock;
                  end;

                ZFreeCnt : {Sender is requesting a count of our freespace}
                  begin
                    LongInt(TransHeader) := DiskFree(0);
                    PutHexHeader(ZAck);
                  end;

                ZCommand : {Commands not implemented}
                  begin
                    PutHexHeader(ZNak);
                  end;

                ZCompl,
                ZFin:      {Finished}
                  begin
                    ZmodemState := rzSendFinish;
                    BlockErrors := 0;
                  end;
              end;
              ReplyTimer := TimerSet(HandshakeWait);
            end;
          ecNoHeader :
            {Keep waiting for a header} ;
          ecBlockCheckError,
          ecTimeout :
            begin
              Inc(BlockErrors);
              if BlockErrors < HandshakeRetry then
                ZmodemState := rzRqstFile
              else begin
                {Failed to handsake}
                ProtocolStatus := ecFailedToHandshake;
                ZmodemState := rzCleanup;
              end;
            end;
        end;
      end;

      rzCollectFile :
        if APort.DataWaiting then begin
          if ReceiveBlock(DataBlock^, BlockSize, Handshake) then
            if ProtocolStatus = ecBlockCheckError then
              {Error getting block, go try again}
              ZmodemState := rzRqstFile
            else
              {Got block OK, go extract file info}
              ZmodemState := rzStartFile
          else if ProtocolStatus = ecCancelRequested then
            ZmodemState := rzError;
        end else if TimerUp(ReplyTimer) then begin
          Inc(BlockErrors);
          if BlockErrors < HandshakeRetry then begin
            PutHexHeader(ZNak);
            ReplyTimer := TimerSet(HandshakeWait);
          end else
            ZmodemState := rzCleanup;
        end;

      rzStartFile :
        begin
          {Got the data subpacket to the ZFile, extract the file information}
          ExtractFileInfo;

          {Call user's LogFile function}
          LogFile(@Self, lfReceiveStart);

          {Accept this file}
          if not AcceptFile(@Self) then begin
            HeaderType := ZSkip;
            LogFile(@Self, lfReceiveSkip);
            ZmodemState := rzRqstFile;
            ProtocolStatus := ecCantWriteFile;

            apUserStatus(False, False);
//            ForceStatus := True;

            goto ExitPoint;
          end;

          {Prepare to write this file}
          apPrepareWriting;

          case ProtocolStatus mod 10000 of
            0 :                 {Fall thru} ;
            ecCantWriteFile,
            ecFileDoesntExist : {Skip this file}
              begin
                HeaderType := ZSkip;
                LogFile(@Self, lfReceiveSkip);
                ZmodemState := rzRqstFile;
                ForceStatus := True;
                goto ExitPoint;
              end;
            else begin          {Fatal error opening file}
              SaveStatus := ProtocolStatus;

              CancelTransfer;

              ProtocolStatus := SaveStatus;
              ZModemState    := rzError;

              goto ExitPoint;
            end;
          end;

          {Go send the initial ZrPos}
          ZmodemState := rzSync;
          ForceStatus := True;
          StartTimer  := TimerSeconds;
        end;

      rzSync :
        begin
          APort.PurgeInputData(0);

          ReplyTimer := TimerSet(HandshakeWait);

          LongInt(TransHeader) := FileOfs;

          PutHexHeader(ZrPos);

          BytesRemaining   := SrcFileLen - FileOfs;
          BytesTransferred := FileOfs;
          ZmodemState      := rzStartData;
          HeaderState      := hsNone;
        end;

      rzStartData :
        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZData :
                begin
                  if FileOfs <> LastFileOfs then begin
                    Inc (BlockErrors);
                    Inc (TotalErrors);

                    If BlockErrors > MaxBadBlocks Then Begin
                      CancelTransfer;

                      ProtocolStatus := ecTooManyErrors;
                      ZmodemState    := rzError;

                      Goto ExitPoint;
                    End;

                    PutAttentionString;

                    ZmodemState := rzSync;
                  End Else Begin
                    BlockErrors   := 0;
                    ZmodemState   := rzCollectData;
                    DataBlockLen  := 0;
                    RcvBlockState := rbData;
                    ReplyTimer    := TimerSet(HandshakeWait);
                  End;
                End;
              ZNak : {Nak received}
                begin
                  Inc(TotalErrors);
                  Inc(BlockErrors);
                  if BlockErrors > MaxBadBlocks then begin
                    CancelTransfer;
                    ProtocolStatus := ecTooManyErrors;
                    ZmodemState := rzError;
                  end else
                    {Resend ZrPos}
                    ZmodemState := rzSync;
                end;
              ZFile : {File frame}
                {Already got a File frame, just go send ZrPos again}
                ZmodemState := rzSync;
              ZEof : {End of current file}
                begin
                  GotOneFile := True;
                  ProtocolStatus := ecEndFile;
                  ZmodemState := rzEndOfFile;
                end;
              else begin
                {Error during GetHeader}
                Inc(TotalErrors);
                Inc(BlockErrors);
                if BlockErrors > MaxBadBlocks then begin
                  CancelTransfer;
                  ProtocolStatus := ecTooManyErrors;
                  ZmodemState := rzError;
                  goto ExitPoint;
                end;
                PutAttentionString;
                ZmodemState := rzSync;
              end;
            end;
          ecNoHeader :
            {Just keep waiting for header} ;
          ecBlockCheckError,
          ecTimeout :
            begin
              Inc(BlockErrors);
              Inc(TotalErrors);
              if BlockErrors > HandshakeRetry then begin
                {Never got ZData header}
                ProtocolStatus := ecFailedToHandshake;
                ZmodemState := rzError;
              end else
                {Timeout out waiting for ZData, go send ZrPos}
                ZmodemState := rzSync;
            end;
        end;

      rzCollectData :
        if APort.DataWaiting then begin
          ReplyTimer := TimerSet(HandshakeWait);
          {Collect the data subpacket}

          if ReceiveBlock(DataBlock^, BlockSize, Handshake) then begin
            SaveStatus := ProtocolStatus;
            {Got a block or an error -- process it}
            case ProtocolStatus of
              ecCancelRequested : {Cancel requested}
                ZmodemState := rzError;
              ecGotCrcW : {Send requests a wait}
                begin
                  {Write this block}
                  WriteDataBlock;
                  if ProtocolStatus = ecOk then begin
                    {Acknowledge with the current file position}
                    LongInt(TransHeader) := FileOfs;
                    PutHexHeader(ZAck);
                    ZmodemState := rzStartData;
                    HeaderState := hsNone;
                  end else
                    ZmodemState := rzError;
                end;
              ecGotCrcQ : {Zack requested}
                begin
                  {Write this block}
                  WriteDataBlock;
                  if ProtocolStatus = ecOk then begin
                    LongInt(TransHeader) := FileOfs;
                    PutHexHeader(ZAck);
                    {Don't change state - will get next data subpacket}
                  end else
                    ZmodemState := rzError;
                end;
              ecGotCrcG : {Normal subpacket - no response necessary}
                begin
                  {Write this block}
                  WriteDataBlock;
                  if ProtocolStatus <> ecOk then
                    ZmodemState := rzError;
                end;
              ecGotCrcE : {Last data subpacket}
                begin
                  {Write this block}
                  WriteDataBlock;
                  if ProtocolStatus = ecOk then begin
                    ZmodemState := rzWaitEof;
                    HeaderState := hsNone;
                    BlockErrors := 0;
                  end else
                    ZmodemState := rzError;
                end;
              else begin {Error during ReceiveBlock}
                if BlockErrors < MaxBadBlocks then begin
                  PutAttentionString;
                  ZmodemState := rzSync;
                end else begin
                  ProtocolStatus := ecGarbage;
                  ZmodemState := rzError;
                end;
              end;
            end;

            {Restore ProtocolStatus so user status routine can see it}
            if ProtocolStatus = ecOk then
              ProtocolStatus := SaveStatus;

            {Prepare to collect next block}
//            ForceStatus := True;
            DataBlockLen := 0;
            RcvBlockState := rbData;
          end else if ProtocolStatus = ecCancelRequested then
            ZmodemState := rzError
        end else if TimerUp(ReplyTimer) then begin
          Inc(BlockErrors);

          if BlockErrors < MaxBadBlocks then begin
            PutAttentionString;

            Inc(TotalErrors);
            Inc(BlockErrors);

            ZmodemState := rzSync;
          end else
            ZmodemState := rzError;
        end;

      rzWaitEof :
        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZEof : {End of current file}
                begin
                  GotOneFile := True;
                  ProtocolStatus := ecEndFile;
                  apUserStatus(False, False);
                  apFinishWriting;
                  if ProtocolStatus = ecEndFile then
                    LogFile(@Self, lfReceiveOk)
                  else
                    LogFile(@Self, lfReceiveFail);

                  {Go get the next file}
                  ZmodemState := rzRqstFile;
                end;
              else begin
                {Error during GetHeader}
                Inc(TotalErrors);
                Inc(BlockErrors);
                if BlockErrors > MaxBadBlocks then begin
                  CancelTransfer;
                  ProtocolStatus := ecTooManyErrors;
                  ZmodemState := rzError;
                  goto ExitPoint;
                end;
                PutAttentionString;
                ZmodemState := rzSync;
              end;
            end;
          ecNoHeader :
            {Just keep waiting for header} ;
          ecBlockCheckError,
          ecTimeout :
            begin
              Inc(BlockErrors);
              Inc(TotalErrors);
              if BlockErrors > HandshakeRetry then begin
                {Never got ZData header}
                ProtocolStatus := ecFailedToHandshake;
                ZmodemState := rzError;
              end else
                {Timeout out waiting for ZData, go send ZrPos}
                ZmodemState := rzSync;
            end;
        end;

      rzEndOfFile :
        if FileOfs = LastFileOfs then begin
          apFinishWriting;

          {Send Proper status to user logging routine}
          if ProtocolStatus = ecEndFile then
            LogFile(@Self, lfReceiveOk)
          else
            LogFile(@Self, lfReceiveFail);

          ZmodemState := rzRqstFile;
        end else
          ZmodemState := rzSync;

      rzSendFinish :
        begin
          {Insert file position into header}
          LongInt(TransHeader) := FileOfs;
          PutHexHeader(ZFin);
          ZmodemState := rzCollectFinish;
          ReplyTimer := TimerSet(FinishWait);
          OCnt := 0;
        end;

      rzCollectFinish :
        begin
          if APort.DataWaiting then begin
            C := APort.ReadChar;
            if C = 'O' then begin
              Inc(OCnt);
              if OCnt = 2 then
                ZmodemState := rzCleanup;
            end;
          end else if TimerUp(ReplyTimer) then begin
            {Retry 3 times only (same as DSZ)}
            Inc(BlockErrors);
            if BlockErrors < FinishRetry then
              {Go send ZFin again}
              ZmodemState := rzSendFinish
            else
              {Cleanup anyway}
              ZmodemState := rzCleanup;
          end;
        end;

      rzError :
        begin
          if FileOpen then begin
            SaveStatus := ProtocolStatus;
            apFinishWriting;
            ProtocolStatus := SaveStatus;
            LogFile(@Self, lfReceiveFail);
          end;
          ZmodemState := rzCleanup;

          APort.BufFlush;
          ZModemState := rzCleanup;
        end;

//      rzWaitCancel :
//          ZmodemState := rzCleanup;

      rzCleanup :
        begin
          apShowLastStatus;
          APort.PurgeInputData(0);
          ZmodemState := rzDone;
        end;
    end;

ExitPoint:

    case ZmodemState of
      rzRqstFile,
      rzSendInit,
      rzSendBlockPrep,                                                 {!!.03}
      rzSendBlock,
      rzSync,
      rzStartFile,
      rzGotData,
      rzEndOfFile,
      rzSendFinish,
      rzError,
      rzCleanup :              ProtocolReceivePart := psReady;

      rzCollectFinish,
//      rzDelay,
//      rzWaitCancel,
      rzWaitFile,
      rzCollectFile,
      rzStartData,
      rzCollectData,
      rzWaitEof :              ProtocolReceivePart := psWaiting;

      rzDone :                 ProtocolReceivePart := psFinished;
    end;

    {Clear header state if we just processed a header}
    if (ProtocolStatus = ecGotHeader) or (ProtocolStatus = ecNoHeader) then
      ProtocolStatus := ecOk;
    if HeaderState = hsGotHeader then
      HeaderState := hsNone;

    {Store ProtocolStatus}
    SaveStatus := ProtocolStatus;
  end;

Procedure ZmodemProtocol.PrepareTransmitPart;
Begin
  FileListIndex := 0;
  HeaderState   := hsNone;

  apResetStatus;
  apShowFirstStatus;

  StatusTimer    := TimerSet(StatusInterval);
  ForceStatus    := False;
  ZmodemState    := tzInitial;
  FilesSent      := False;
  SaveStatus     := ecOk;
  ProtocolStatus := ecOk;
End;

  function ZmodemProtocol.ProtocolTransmitPart : ProtocolStateType;
  label
    ExitPoint;
  const
    RZcommand : array[1..4] of Char = 'rz'+cCr+#0;
  begin
    ProtocolStatus := SaveStatus;

    if {ForceStatus or} TimerUp(StatusTimer) then begin
      If Not APort.Connected or (apHandleAbort and (ProtocolStatus <> ecCancelRequested)) Then Begin
        CancelTransfer;

        ZmodemState := tzError;
      End;

      apUserStatus(False, False);

      StatusTimer := TimerSet(StatusInterval);
      ForceStatus := False;
    end;

    {Preprocess header requirements}
    case ZmodemState of
      tzHandshake,
      tzCheckFile,
      tzCheckEOF,
      tzCheckFinish,
      tzSendData,
      tzWaitAck : begin
        if (zmodemstate <> tzsenddata) and not aport.datawaiting then aport.waitfordata(1000);
        {Header might be present, try to get one}
        if APort.DataWaiting then begin
          zpCheckForHeader;

          if ProtocolStatus = ecCancelRequested then
            ZmodemState := tzError;

        end else if TimerUp(ReplyTimer) then
          ProtocolStatus := ecTimeout
        else
          ProtocolStatus := ecNoHeader;
      end;
    end;

    {Process the current state}
    case ZmodemState of
      tzInitial :
        begin
          CanCount := 0;

          {Send RZ command (via the attention string)}
          Move(RZcommand, AttentionStr, SizeOf(RZcommand));
          PutAttentionString;
          FillChar(AttentionStr, SizeOf(AttentionStr), 0);

          {Send ZrQinit header (requests receiver's ZrInit)}
          LongInt(TransHeader) := 0;
          PutHexHeader(ZrQInit);

          ReplyTimer := TimerSet(HandshakeWait);
          ZmodemState := tzHandshake;
          HeaderState := hsNone;

//          zlog('tzInitial -> sent ZRQINIT');
        end;

      tzHandshake : begin

//      zlog('tzHandshake -> ProtocolStatus = ' + stri2s(ProtocolStatus));
//      zlog('tzHandshake -> rcvFrame = ' + stri2s(ord(rcvframe)));

        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZrInit :     {Got ZrInit, extract info}
                begin
                  ExtractReceiverInfo;
                  ZmodemState := tzGetFile;
                end;
              ZChallenge : {Receiver is challenging, respond with same number}
                begin
                  TransHeader := RcvHeader;
                  PutHexHeader(ZAck);
                end;
              ZCommand :   {Commands not supported}
                PutHexHeader(ZNak);
              ZrQInit :    {Remote is trying to transmit also, do nothing}
                ;
              else         {Unexpected reply, nak it}
                PutHexHeader(ZNak);
            end;
          ecNoHeader :
            {Keep waiting for header} ;
          ecBlockCheckError,
          ecTimeout  : {Send another ZrQinit}
            begin
              Inc(BlockErrors);
              Inc(TotalErrors);
              if BlockErrors > HandshakeRetry then begin
                {Never got ZrInit}
                ProtocolStatus := ecFailedToHandshake;
                ZmodemState := tzError;
              end else begin
                PutHexHeader(ZrQInit);
                ReplyTimer := TimerSet(HandshakeWait);
              end;
            end;
          end;
        end;

      tzGetFile :
        begin
//          zlog('tzGetFile -> start');
          {Get the next file to send}
          if not NextFile(@Self, Pathname) then begin
//            zlog('tzGetFile -> no next file');
            ZmodemState := tzSendFinish;
            goto ExitPoint;
          end else
            FilesSent := True;

          {Show file name to user logging routine}
          LogFile(@Self, lfTransmitStart);

          {Prepare to read file blocks}
          apPrepareReading;

          if ProtocolStatus <> ecOk then begin
            SaveStatus := ProtocolStatus;
            CancelTransfer;
            ProtocolStatus := SaveStatus;
            LogFile(@Self, lfTransmitFail);
            ZmodemState := tzCleanup;
            goto ExitPoint;
          end;

          StartTimer := TimerSeconds;

          LongInt(TransHeader) := 0;
          TransHeader[ZF1] := FileMgmtOpts;

          if AllowResume then
            TransHeader[ZF0] := $03;

          {Insert file information into header}
          InsertFileInfo;
          ForceStatus := True;
          ZmodemState := tzSendFile;

          BlockErrors := 0;
        end;

      tzSendFile :
        begin
//          zlog('tzSendFile -> start');
          {Send the ZFile header and data subpacket with file info}

          zpPutBinaryHeader(ZFile);
          Terminator := ZCrcW;
          EscapeBlock(DataBlock^, DataBlockLen);
          TransmitBlock;

          {Clear status vars that zpTransmitBlock changed}
          BytesTransferred := 0;
          BytesRemaining := 0;

          {Go wait for response}
          ReplyTimer := TimerSet(HandshakeWait);
          ZmodemState := tzCheckFile;
          HeaderState := hsNone;
        end;

      tzCheckFile : begin
//      zlog('tzCheckFile -> status=' + stri2s(ProtocolStatus));
//      zlog('tzCheckFile -> rcvframe=' + stri2s(ord(rcvframe)));
        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZrInit : ;
              ZCrc :
                begin
                  LongInt(TransHeader) := FileCRC32(PathName);
                  PutHexHeader(ZCrc);
                end;
              ZSkip :  {Receiver wants to skip this file}
                begin
                  ProtocolStatus := ecSkipFile;
                  apUserStatus(False, False);
                  ProtocolStatus := ecOk;

                  {Close file and log skip}
                  apFinishReading;
                  LogFile(@Self, lfTransmitSkip);

                  {Go look for another file}
                  ZmodemState := tzGetFile;
                end;
              ZrPos :  {Receiver tells us where to seek in our file}
                begin
                  {Get file offset}
                  FileOfs := LongInt(RcvHeader);
                  BytesTransferred := FileOfs;
                  InitFilePos := FileOfs;
                  BytesRemaining := SrcFileLen - BytesTransferred;

                  {Go send the data subpackets}
                  ZModemState := tzStartData;
                end;
            end;
          ecNoHeader : ;// zlog('tzCheckFile -> no header');{Keep waiting for header}
          ecBlockCheckError,
          ecTimeout :  {Timeout waiting for response to ZFile}
            begin
              Inc(BlockErrors);
              Inc(TotalErrors);
              if BlockErrors > HandshakeRetry then begin
                {Never got response to ZFile}
                ProtocolStatus := ecTimeout;
                ZmodemState := tzError;
              end else begin
                {Resend ZFile}
                ZmodemState := tzSendFile;
              end;
            end;
        end;
      end;

      tzStartData :
        begin
//        zlog('tzStartData -> start');
          {Get ready}
          DataInTransit := 0;
          BlockErrors := 0;

          {Send ZData header}
          LongInt(TransHeader) := FileOfs;
          zpPutBinaryHeader(ZData);

          ZmodemState := tzEscapeData;
        end;

      tzEscapeData :
        begin
          {Get a block to send}
          if TookHit then begin
            Inc(GoodAfterBad);
            if GoodAfterBad > 4 then begin
              TookHit := False;
              if BlockLen < ZMaxBlk[Use8KBlocks] then
                BlockLen := ZMaxBlk[Use8KBlocks];
            end;
          end;
          DataBlockLen := BlockLen;
          LastBlock := apReadProtocolBlock(DataBlock^, DataBlockLen);
          if ProtocolStatus <> ecOk then begin
            SaveStatus := ProtocolStatus;
            CancelTransfer;
            ProtocolStatus := SaveStatus;
            ZmodemState := tzError;
            goto ExitPoint;
          end;

          {Show the new data on the way}
          if RcvBuffLen <> 0 then
            Inc(DataInTransit, DataBlockLen);

          {Set the terminator}
          if LastBlock then
            {Tell receiver its the last subpacket}
            Terminator := ZCrcE
          else if (RcvBuffLen <> 0) and (DataInTransit >= RcvBuffLen) then begin
            {Receiver's buffer is nearly full, wait for acknowledge}
            Terminator := ZCrcW;
            {NoFallBack := True;}
          end else
            {Normal data subpacket, no special action}
            Terminator := ZCrcG;

          EscapeBlock(DataBlock^, DataBlockLen);

          ZmodemState := tzSendData;
          ReplyTimer := TimerSet(TransTimeout);
          BlockErrors := 0;
        end;

      tzSendData :
        case ProtocolStatus of
          ecNoHeader : {Nothing from receiver, keep going}
            begin
              {Wait for buffer free space}
//              if APort.OutBuffFree > WorkSize + FreeMargin then begin
                TransmitBlock;
                if LastBlock then begin
                  ZmodemState := tzSendEof;
                  BlockErrors := 0;
                end else if Terminator = ZCrcW then begin
                  ReplyTimer := TimerSet(TransTimeout);
                  ZmodemState := tzWaitAck;
                end else
                  ZmodemState := tzEscapeData;
                ForceStatus := True;
//              end else
                {Timeout will be handled at top of state machine}
            end;

          ecGotHeader : {Got a header from the receiver, process it}
            begin
              case RcvFrame of
                ZCan, ZAbort : {Receiver says quit}
                  begin
                    ProtocolStatus := ecCancelRequested;
                    ZmodemState    := tzError;
                  end;
                ZrPos :        {Receiver is sending its desired file position}
                  begin
                    FileOfs := LongInt(RcvHeader);
                    BytesTransferred := FileOfs;
                    BytesRemaining := SrcFileLen - BytesTransferred;

                    Inc(TotalErrors);
                    {We got a hit, reduce block size by 1/2}
                    if BlockLen > 256 then
                      BlockLen := BlockLen shr 1;
                    TookHit := True;
                    GoodAfterBad := 0;
                    APort.PurgeOutputData;
                    ZModemState := tzStartData;
                  end;
                ZAck :         {Response to last CrcW data subpacket}
                  ;
                ZSkip, ZrInit : {Finished with this file}
                  ;
                else begin
                  {Garbage, send Nak}
                  zpPutBinaryHeader(ZNak);
                end;
              end;
            end;

          ecBlockCheckError :
            zpPutBinaryHeader(ZNak);

          ecTimeout :
            if TimerUp(ReplyTimer) then begin
              ProtocolStatus := ecBufferIsFull;
              ZmodemState := tzError;
            end;
        end;

      tzWaitAck :
        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZCan, ZAbort : {Receiver says quit}
                begin
                  ProtocolStatus := ecCancelRequested;
                  ZmodemState := tzError;
                end;
              ZAck :
                ZmodemState := tzStartData;
              ZrPos :        {Receiver is sending its desired file position}
                begin
                  FileOfs := LongInt(RcvHeader);
                  BytesTransferred := FileOfs;
                  BytesRemaining := SrcFileLen - BytesTransferred;
                  Inc(TotalErrors);
                  if BlockLen > 256 then
                    BlockLen := BlockLen shr 1;
                  TookHit := True;
                  GoodAfterBad := 0;
                  APort.PurgeOutputData;
                  ZmodemState := tzStartData;
                end;
              else begin
                {Garbage, send Nak}
                zpPutBinaryHeader(ZNak);
              end;
            end;
          ecBlockCheckError,
          ecTimeout :
            begin
              Inc(TotalErrors);
              if TotalErrors > MaxBadBlocks then
                ZmodemState := tzError
              else
                ZmodemState := tzStartData;
            end;
        end;

      tzSendEof :
        begin
          {Send the eof}
          LongInt(TransHeader) := FileOfs;
          zpPutBinaryHeader(ZEof);
          ReplyTimer := TimerSet(TransTimeout);
          ZModemState := tzDrainEof;
//          NewTimer(StatusTimer, DrainingStatusInterval);
        end;

      tzDrainEof :
      begin
      APort.BufFlush;
      zmodemstate := tzCheckEof;
      HeaderState := hsNone;
      ReplyTimer := TimerSet(FinishWait);
    End;

      tzCheckEof :
        case ProtocolStatus of
          ecGotHeader :
            begin
              case RcvFrame of
                ZCan, ZAbort : {Receiver says quit}
                  begin
                    ProtocolStatus := ecCancelRequested;
                    ZmodemState := tzError;
                  end;
                ZrPos :        {Receiver is sending its desired file position}
                  begin
                    FileOfs := LongInt(RcvHeader);
                    BytesTransferred := FileOfs;
                    BytesRemaining := SrcFileLen - BytesTransferred;

                    {We got a hit, reduce block size by 1/2}
                    if BlockLen > 256 then
                      BlockLen := BlockLen shr 1;
                    TookHit := True;
                    GoodAfterBad := 0;
                    APort.PurgeOutputData;
                    ZModemState := tzStartData;
                  end;
                ZAck :         {Response to last CrcW data subpacket}
                  ;
                ZSkip, ZrInit : {Finished with this file}
                  begin
                    {Close file and log success}
                    apFinishReading;
                    ProtocolStatus := ecOk;
                    LogFile(@Self, lfTransmitOk);

                    {Go look for another file}
                    ZmodemState := tzGetFile;
                  end;
                else begin
                  {Garbage, send Nak}
                  zpPutBinaryHeader(ZNak);
                end;
              end;
            end;
          ecNoHeader :
            {Keep waiting for header} ;
          ecBlockCheckError,
          ecTimeout :
            begin
              Inc(BlockErrors);
              Inc(TotalErrors);
              if BlockErrors > MaxBadBlocks then
                ZmodemState := tzError
              else
                ZmodemState := tzSendEof;
            end;
        end;

      tzSendFinish :
        begin
          LongInt(TransHeader) := FileOfs;
          PutHexHeader(ZFin);
          ReplyTimer := TimerSet(FinishWait);
          BlockErrors := 0;
          ZmodemState := tzCheckFinish;
          HeaderState := hsNone;
        end;

      tzCheckFinish :
        case ProtocolStatus of
          ecGotHeader :
            case RcvFrame of
              ZFin :
                begin
                  APort.BufWriteChar('O');
                  APort.BufWriteChar('O');
                  APort.BufFlush;
                  ZmodemState := tzCleanup;
                end;
              else begin
                ProtocolStatus := ecOk;
                ZmodemState := tzCleanup;
              end;
            end;
          ecNoHeader :
            {Keep waiting for header} ;
          ecBlockCheckError,
          ecTimeout :
            begin
              {Just give up}
              ZmodemState := tzCleanup;
              ProtocolStatus := ecOk;
            end;
        end;

      tzError :
        begin
          if FileOpen then begin
            apFinishReading;
            LogFile(@Self, lfTransmitFail);
          end;
          ZmodemState := tzCleanup;
          APort.PurgeOutputData;
        end;

      tzCleanup:
        begin
          apShowLastStatus;

          APort.PurgeInputData(0);

          ZmodemState := tzDone;
        end;
    end;

ExitPoint:
    case ZmodemState of
      tzHandshake,
      tzCheckFile,
      tzEscapeData,
      tzSendData,
      tzWaitAck,
      tzDrainEof,
      tzCheckEof,
      tzCheckFinish   : ProtocolTransmitPart := psWaiting;

      tzInitial,
      tzGetFile,
      tzSendFile,
      tzStartData,
      tzSendEof,
      tzSendFinish,
      tzError,
      tzCleanup       : ProtocolTransmitPart := psReady;

      tzDone          : ProtocolTransmitPart := psFinished;
    end;

    {Clear header state if we just processed a header}
    if (ProtocolStatus = ecGotHeader) or (ProtocolStatus = ecNoHeader) then
      ProtocolStatus := ecOk;

    if HeaderState = hsGotHeader then
      HeaderState := hsNone;

    {Store ProtocolStatus}
    SaveStatus := ProtocolStatus;
  end;

Procedure ZmodemProtocol.PutCharEscaped (C: Char);
Var
  C1: Char;
  C2: Char;
Begin
  ProtocolStatus := ecOK;

  If EscapeAll and ((Byte(C) and $60) = 0) Then Begin
    APort.BufWriteChar(ZDLE);

    LastChar := Char(Byte(C) XOR $40);
  End Else If ((Byte(C) AND $11) = 0) Then
    LastChar := C
  Else Begin
    C1 := Char(Byte(C) AND $7F);
    C2 := Char(Byte(LastChar) AND $7F);

    Case C of
      cXON,
      cXOFF,
      cDLE,
      cXONHI,
      cXOFFHI,
      cDLEHI,
      ZDLE     : Begin
                   APort.BufWriteChar(ZDle);

                   LastChar := Char(Byte(C) XOR $40);
                 End;
      #255     : Begin
                   APort.BufWriteChar (ZDLE);

                   LastChar := ZRUB1;
                 End;
    Else
      If ((C1 = cCR) AND (C2 = #$40)) Then Begin
        APort.BufWriteChar (ZDLE);

        LastChar := Char(Byte(C) XOR $40);
      End Else
        LastChar := C;
    End;
  End;

  APort.BufWriteChar (LastChar);
End;

Procedure ZmodemProtocol.zpPutBinaryHeader (FrameType: Char);
Var
  I : Integer;
Begin
  UseCrc32 := CanCrc32;

  With APort Do Begin
    BufWriteChar (ZPAD);
    BufWriteChar (ZDLE);

    If UseCrc32 Then Begin
      PutCharEscaped(ZBIN32);

      BlockCheck := LongInt($FFFFFFFF);
    End Else Begin
      PutCharEscaped(ZBIN);

      BlockCheck := 0;
    End;

    PutCharEscaped   (FrameType);
    UpdateBlockCheck (Ord(FrameType));

    For I := 0 to 3 Do Begin
      PutCharEscaped   (Char(TransHeader[I]));
      UpdateBlockCheck (Ord(TransHeader[I]))
    End;

    SendBlockCheck;
  End;

  LastFrame := FrameType;
End;

Function ZmodemProtocol.EscapeCharacter (C: Char) : Str2;
Var
  C1 : Char;
  C2 : Char;
Begin
  If EscapeAll and ((Byte(C) and $60) = 0) Then Begin
    Result := ZDLE + Char(Byte(C) XOR $40);

    Exit;
  End Else If ((Byte(C) and $11) = 0) Then
    LastChar := C
  Else Begin
    C1 := Char(Byte(C) AND $7F);
    C2 := Char(Byte(LastChar) AND $7F);

    Case C of
      cXON,
      cXOFF,
      cDLE,
      cXONHI,
      cXOFFHI,
      cDLEHI,
      ZDLE     : Begin
                   LastChar := Char(Byte(C) XOR $40);
                   Result   := ZDLE + LastChar;

                   Exit;
                 End;
      #255     : Begin
                   LastChar := ZRUB1;
                   Result   := ZDLE + ZRUB1;

                   Exit;
                 End;
    Else
      If ((C1 = cCR) and (C2 = #$40)) Then Begin
        LastChar := Char(Byte(C) XOR $40);
        Result   := ZDLE + LastChar;

        Exit;
      End Else
        LastChar := C;
    End;
  End;

  Result := LastChar;
End;

Procedure ZmodemProtocol.EscapeBlock (Var Block: DataBlockType; BLen: Word);
Var
  I  : Word;
  S2 : String[2];
Begin
  If CanCrc32 Then Begin
    UseCrc32   := True;
    BlockCheck := LongInt($FFFFFFFF);
  End Else Begin
    UseCrc32   := False;
    BlockCheck := 0;
  End;

  If BLen > 0 Then Begin
    WorkSize := 1;
    I        := 1;

    Repeat
      S2 := EscapeCharacter(Block[I]);

      UpdateBlockCheck(Byte(Block[I]));

      Move(S2[1], WorkBlock^[WorkSize], Length(S2));

      Inc (I);
      Inc (WorkSize, Length(S2));
    Until I > BLen;

    Dec (WorkSize);
  End Else
    WorkSize := 0;
End;

Procedure ZmodemProtocol.TransmitBlock;
Var
  Count : LongInt;
Begin
  For Count := 1 to WorkSize Do
    APort.BufWriteChar(WorkBlock^[Count]);

  UpdateBlockCheck (Byte(Terminator));

  APort.BufWriteChar (ZDLE);
  APort.BufWriteChar (Terminator);

  SendBlockCheck;

  If Terminator = ZCrcW Then
    APort.BufWriteChar(cXon);

  Inc (FileOfs,          DataBlockLen);
  Inc (BytesTransferred, DataBlockLen);
  Dec (BytesRemaining,   DataBlockLen);

  APort.BufFlush;
End;

Procedure ZmodemProtocol.InsertFileInfo;
Var
  PacketStr : String;
  PacketLen : Byte;
Begin
  FillChar (DataBlock^, ZMaxBlk[Use8KBlocks] , 0);

  PacketStr := JustFile(PathName);

  If ConvertToLower Then
    PacketStr := strLower(PacketStr);

  PacketStr := PacketStr + #0 + strI2S(SrcFileLen) + #0;
  PacketLen := Length(PacketStr);

  Move(PacketStr[1], DataBlock^, PacketLen);

  DataBlockLen     := PacketLen;
  BytesRemaining   := SrcFileLen;
  BytesTransferred := 0;
End;

Procedure ZmodemProtocol.ExtractReceiverInfo;
Begin
  RcvBuffLen := RcvHeader[ZP0] + ((RcvHeader[ZP1]) SHL 8);
  CanCrc32   := (RcvHeader[ZF0] and CanFC32) = CanFC32;
  EscapeAll  := (RcvHeader[ZF0] and EscAll) = EscAll;
End;

End.

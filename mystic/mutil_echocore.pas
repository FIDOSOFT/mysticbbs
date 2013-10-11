Unit MUTIL_EchoCore;

{$I M_OPS.PAS}

Interface

Uses
  m_CRC,
  m_FileIO,
  m_Strings,
  m_DateTime,
  BBS_Records,
  BBS_DataBase,
  mUtil_Common;

Const
  MaxDupeSize = 250000;

Type
  RecMsgDupe = Record
    Header : Cardinal;
    Text   : Cardinal;
  End;

  RecDupePTR   = ^RecDupeArray;
  RecDupeArray = Array[1..MaxDupeSize] of RecMsgDupe;

Type
  TPKTDupe = Class
    DupeData   : RecDupePTR;
    MaxDupes   : Cardinal;
    CurDupes   : Cardinal;
    TotalDupes : Cardinal;

    Constructor Create (Max: Cardinal);
    Destructor  Destroy; Override;

    Function    IsDuplicate  (Var D: RecMsgDupe) : Boolean;
    Procedure   AddDuplicate (Var D: RecMsgDupe);
  End;

Const
  pktPrivate    = $0001;
  pktCrash      = $0002;
  pktReceived   = $0004;
  pktSent       = $0008;
  pktFileAttach = $0010;
  pktInTransit  = $0020;
  pktOrphan     = $0040;
  pktKillSent   = $0080;
  pktLocal      = $0100;
  pktHold       = $0200;
  pktUnused     = $0400;
  pktFileReq    = $0800;
  pktReturnReq  = $1000;
  pktIsReceipt  = $2000;
  pktAuditReq   = $4000;
  pktFileUpdate = $8000;

Type
  RecPKTMessageHdr = Record
    MsgType,
    OrigNode  : System.Word;
    DestNode  : System.Word;
    OrigNet   : System.Word;
    DestNet   : System.Word;
    Attribute : System.Word;
    Cost      : System.Word;
    DateTime  : String[19];
  End;
(*
  RecPKTHeader = Record
    OrigNode : System.Word;
    DestNode : System.Word;
    Year     : System.Word;
    Month    : System.Word;
    Day      : System.Word;
    Hour     : System.Word;
    Minute   : System.Word;
    Second   : System.Word;
    Baud     : System.Word;
    PKTType  : System.Word;
    OrigNet  : System.Word;
    DestNet  : System.Word;
    ProdCode : System.Word;
    Password : Array[1..8] of Char;
    OrigZone : System.Word;
    DestZone : System.Word;
    Filler   : Array[1..20] of Char;
  End;
*)

  RecPKTHeader = Record
    OrigNode  : System.Word;
    DestNode  : System.Word;
    Year      : System.Word;
    Month     : System.Word;
    Day       : System.Word;
    Hour      : System.Word;
    Minute    : System.Word;
    Second    : System.Word;
    Baud      : System.Word;
    PKTType   : System.Word;
    OrigNet   : System.Word;
    DestNet   : System.Word;
    ProdCode  : Byte;
    ProdRev   : Byte;
    Password  : Array[1..8] of Char;
    OrigZone  : System.Word;
    DestZone  : System.Word;
    Filler    : Array[1..4] of Char;
    ProdCode2 : Byte;
    ProdRev2  : Byte;
    Compat    : System.Word;
    OrigZone2 : System.Word;
    DestZone2 : System.Word;
    OrigPoint : System.Word;
    DestPoint : System.Word;
    ProdData  : LongInt;
  End;

  RecMsgLine = String[79];

  TPKTReader = Class
    PKTHeader : RecPKTHeader;
    PKTOrig   : RecEchoMailAddr;
    PKTDest   : RecEchoMailAddr;
    MsgOrig   : RecEchoMailAddr;
    MsgDest   : RecEchoMailAddr;
    MsgHdr    : RecPKTMessageHdr;
    MsgFile   : TFileBuffer;
    MsgTo     : String[50];
    MsgFrom   : String[50];
    MsgSubj   : String[80];
    MsgDate   : String[20];
    MsgTime   : String[5];
    MsgText   : Array[1..mysMaxMsgLines] of ^RecMsgLine;
    MsgSize   : LongInt;
    MsgLines  : LongInt;
    MsgArea   : String[60];
    MsgCRC    : RecMsgDupe;
    Opened    : Boolean;
    //IsNetMail : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   DisposeText;

    Function    Open (FN: String) : Boolean;
    Procedure   Close;
    Function    GetMessage : Boolean;
  End;

  TPKTWriter = Class
    MsgFile : TFileBuffer;

    Constructor Create;
    Destructor  Destroy; Override;
  End;

Implementation

Constructor TPKTWriter.Create;
Begin
  Inherited Create;

  MsgFile := TFileBuffer.Create(8 * 1024);
End;

Destructor TPKTWriter.Destroy;
Begin
  MsgFile.Free;

  Inherited Destroy;
End;

Constructor TPKTDupe.Create (Max: Cardinal);
Var
  F : File;
Begin
  Inherited Create;

  If Max > MaxDupeSize Then Max := MaxDupeSize;

  MaxDupes   := Max;
  TotalDupes := 0;

  GetMem (DupeData, MaxDupes * SizeOf(RecMsgDupe));

  Assign (F, bbsCfg.DataPath + 'echodupes.dat');
  {$I-} Reset (F, 1); {$I+}

  If IoResult <> 0 Then ReWrite (F, 1);

  BlockRead (F, DupeData^, MaxDupes * SizeOf(RecMsgDupe), TotalDupes);
  Close     (F);

  If TotalDupes > 0 Then
    TotalDupes := TotalDupes DIV SizeOf(RecMsgDupe);

  CurDupes := TotalDupes;
End;

Function TPKTDupe.IsDuplicate (Var D: RecMsgDupe) : Boolean;
Var
  Count : Cardinal;
Begin
  Result := False;

  For Count := 1 to TotalDupes Do
    If (D.Header = DupeData^[Count].Header) and (D.Text = DupeData^[Count].Text) Then Begin
      Result := True;

      Exit;
    End;
End;

Procedure TPKTDupe.AddDuplicate (Var D: RecMsgDupe);
Begin
  If CurDupes = MaxDupes Then Begin
    TotalDupes := MaxDupes;
    CurDupes   := 0;
  End;

  Inc (CurDupes);

  If TotalDupes < CurDupes Then
    TotalDupes := CurDupes;

  DupeData^[CurDupes] := D;
End;

Destructor TPKTDupe.Destroy;
Var
  F : File;
Begin
  Assign     (F, bbsCfg.DataPath + 'echodupes.dat');
  ReWrite    (F, 1);
  BlockWrite (F, DupeData^, TotalDupes * SizeOf(RecMsgDupe));
  Close      (F);

  FreeMem (DupeData, MaxDupes * SizeOf(RecMsgDupe));

  Inherited Destroy;
End;

Constructor TPKTReader.Create;
Begin
  Opened   := False;
  MsgLines := 0;
  MsgFile  := TFileBuffer.Create(16 * 1024);
End;

Destructor TPKTReader.Destroy;
Begin
  DisposeText;
  MsgFile.Free;

  Inherited Destroy;
End;

Procedure TPKTReader.DisposeText;
Var
  Count : LongInt;
Begin
  For Count := MsgLines DownTo 1 Do
    Dispose (MsgText[Count]);

  MsgLines := 0;
End;

Procedure TPKTReader.Close;
Begin
  DisposeText;

  If MsgFile.IsOpened Then MsgFile.CloseStream;
End;

Function TPKTReader.Open (FN: String) : Boolean;
Var
  Res : LongInt;
Begin
  Result := False;

  If Not MsgFile.OpenStream (FN, 1, fmOpen, fmRWDN) Then Exit;

  MsgFile.ReadBlock (PKTHeader, SizeOf(PKTHeader), Res);

  If (Res <> SizeOf(PKTHeader)) or (PKTHeader.PKTType <> $0002) Then Begin
    MsgFile.CloseStream;

    Opened := False;
  End Else Begin
    PKTOrig.Zone  := PKTHeader.OrigZone;
    PKTOrig.Net   := PKTHeader.OrigNet;
    PKTOrig.Node  := PKTHeader.OrigNode;
    PKTOrig.Point := PKTHeader.OrigPoint; //V2+
    PKTDest.Zone  := PKTHeader.DestZone;
    PKTDest.Net   := PKTHeader.DestNet;
    PKTDest.Node  := PKTHeader.DestNode;
    PKTDest.Point := PKTHeader.DestPoint; //V2+
    Result        := True;
    Opened        := True;
  End;
End;

Function TPKTReader.GetMessage : Boolean;
Var
  Res   : LongInt;
  Ch    : Char;
  First : Boolean;

  Function GetStr (TermChar: Char) : String;
  Begin
    Result := '';

    While Not MsgFile.Eof Do Begin
      Ch := MsgFile.ReadChar;

      If Ch = TermChar Then Break;

      Result := Result + Ch;
    End;
  End;

Var
  Tmp : String[3];
Begin
  Result := False;

  If Not Opened Then Exit;

  MsgFile.ReadBlock (MsgHdr, SizeOf(MsgHdr), Res);

  If Res <> SizeOf(MsgHdr) Then Exit;

  MsgDate := strWide2Str (MsgHdr.DateTime, 20);
  MsgTo   := GetStr (#0);
  MsgFrom := GetStr (#0);
  MsgSubj := GetStr (#0);
  MsgTime := Copy(MsgDate, 12, 5);
  MsgOrig := PKTOrig;
  MsgDest := PKTDest;

  Tmp := strUpper(Copy(MsgDate, 4, 3));

  For Res := 1 to 12 Do
    If strUpper(MonthString[Res]) = Tmp Then Begin
      Tmp := strZero(Res);
      Break;
    End;

  MsgDate := Tmp + '/' + Copy(MsgDate, 1, 2) + '/' + Copy(MsgDate, 8, 2);

  DisposeText;

  First         := True;
  MsgSize       := 0;
  Result        := True;
  MsgLines      := 1;
  MsgCRC.Header := StringCRC32(MsgDate + MsgTime + MsgArea + MsgFrom + MsgTo + MsgSubj);
  MsgCRC.Text   := $FFFFFFFF;

  New (MsgText[MsgLines]);

  MsgText[MsgLines]^ := '';

  Repeat
    Ch := MsgFile.ReadChar;

    Case Ch of
      #000 : Break;
      #010 : ;
      #013 : Begin
               If MsgLines = mysMaxMsgLines Then Begin
                 Repeat
                   Ch := MsgFile.ReadChar;
                 Until (Ch = #0) or (MsgFile.EOF);

                 Break;
               End;

               If First Then Begin
                 First := False;

                 If Copy(MsgText[MsgLines]^, 1, 5) = 'AREA:' Then Begin
                   MsgArea := strUpper(Copy(MsgText[MsgLines]^, 6, 255));

                   MsgText[MsgLines]^ := '';

                   Continue;
                 End Else Begin
                   MsgArea   := 'NETMAIL';
//                   IsNetMail := True;
                 End;
               End;

               If MsgText[MsgLines]^[1] = #1 Then Begin
                 If Copy(MsgText[MsgLines]^, 2, 4) = 'INTL' Then
                   Str2Addr(strWordGet(2, MsgText[MsgLines]^, ' '), MsgDest)
                 Else
                 If (Copy(MsgText[MsgLines]^, 2, 5) = 'MSGID') Then
                   Str2Addr(strWordGet(2, MsgText[MsgLines]^, ' '), MsgOrig);
               End;

               Inc (MsgSize, Length(MsgText[MsgLines]^));
               Inc (MsgLines);

               New (MsgText[MsgLines]);

               MsgText[MsgLines]^ := '';
             End;
      #141 : ;
    Else
      If Length(MsgText[MsgLines]^) = 79 Then Begin
        If (Ch <> ' ') and (Pos(' ', MsgText[MsgLines]^) > 0) and (MsgLines < mysMaxMsgLines) Then Begin
          For Res := Length(MsgText[MsgLines]^) DownTo 1 Do
            If MsgText[MsgLines]^[Res] = ' ' Then Begin
              Inc (MsgLines);

              New (MsgText[MsgLines]);

              MsgText[MsgLines]^ := Copy(MsgText[MsgLines - 1]^, Res + 1, 255);

              Delete (MsgText[MsgLines - 1]^, Res, 255);

              Break;
            End;
        End Else Begin
          If MsgLines = mysMaxMsgLines Then Begin
            Repeat
              Ch := MsgFile.ReadChar;
            Until (Ch = #0) or (MsgFile.EOF);

            Break;
          End;

          Inc (MsgLines);

          New (MsgText[MsgLines]);

          MsgText[MsgLines]^ := '';
        End;
      End;

      MsgText[MsgLines]^ := MsgText[MsgLines]^ + Ch;
      MsgCRC.Text        := Crc32(Byte(Ch), MsgCRC.Text);
    End;
  Until False;
End;

End.

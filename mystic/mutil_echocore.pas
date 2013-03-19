Unit MUTIL_EchoCore;

{$I M_OPS.PAS}

Interface

Uses
  m_CRC,
  m_FileIO,
  m_Strings,
  m_DateTime,
  MPL_FileIO,
  BBS_Common,
  mUtil_Common;

Const
  MaxDupeChecks = 40000;

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

  RecMsgDupe = Record
    Header : Cardinal;
    Text   : Cardinal;
  End;

  RecMsgLine = String[79];

  TPKTReader = Class
    PKTHeader : RecPKTHeader;
    Orig      : RecEchoMailAddr;
    Dest      : RecEchoMailAddr;
    MsgHdr    : RecPKTMessageHdr;
    MsgFile   : PCharFile;
    DupeFile  : PCharFile;
    MsgTo     : String[50];
    MsgFrom   : String[50];
    MsgSubj   : String[80];
    MsgDate   : String[20];
    MsgTime   : String[5];
    MsgText   : Array[1..mysMaxMsgLines] of ^RecMsgLine;
    MsgSize   : LongInt;
    MsgLines  : LongInt;
    MsgArea   : String;
    MsgCRC    : RecMsgDupe;
    Opened    : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   DisposeText;

    Function    Open (FN: String) : Boolean;
    Function    GetMessage (NetMail: Boolean) : Boolean;
    Function    IsDuplicate : Boolean;
    Procedure   AddDuplicate;
  End;

Implementation

Constructor TPKTReader.Create;
Begin
  Opened   := False;
  MsgLines := 0;
  MsgFile  := New (PCharFile, Init(1024 * 4));
  DupeFile := New (PCharFile, Init(1024 * 8));
End;

Destructor TPKTReader.Destroy;
Begin
  DisposeText;

  If MsgFile.Opened Then MsgFile.Close;
  If DupeFile.Opened Then DupeFile.Close;

  Dispose (MsgFile, Done);
  Dispose (DupeFile, Done);

  // TRIM DUPLICATE FILE HERE

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

Function TPKTReader.Open (FN: String) : Boolean;
Var
  Res : LongInt;
Begin
  Result := False;

  If Not MsgFile.Open(FN) Then Exit;

  MsgFile.BlockRead (PKTHeader, SizeOf(PKTHeader), Res);

  If (Res <> SizeOf(PKTHeader)) or (PKTHeader.PKTType <> $0002) Then Begin
    MsgFile.Close;
    Opened := False;
  End Else Begin
    Orig.Zone := PKTHeader.OrigZone;
    Orig.Net  := PKTHeader.OrigNet;
    Orig.Node := PKTHeader.OrigNode;
    Dest.Zone := PKTHeader.DestZone;
    Dest.Net  := PKTHeader.DestNet;
    Dest.Node := PKTHeader.DestNode;
    Result    := True;
    Opened    := True;
  End;
End;

Function TPKTReader.GetMessage (NetMail: Boolean) : Boolean;
Var
  Res : LongInt;
  Ch  : Char;

  Function GetStr (TermChar: Char) : String;
  Begin
    Result := '';

    While Not MsgFile.Eof Do Begin
      Ch := MsgFile.Read;

      If Ch = TermChar Then Break;

      Result := Result + Ch;
    End;
  End;

Var
  Tmp : String[3];
Begin
  Result := False;

  If Not Opened Then Exit;

  MsgFile.BlockRead (MsgHdr, SizeOf(MsgHdr), Res);

  If Res <> SizeOf(MsgHdr) Then Exit;

  MsgDate := strWide2Str (MsgHdr.DateTime, 20);
  MsgTo   := GetStr (#0);
  MsgFrom := GetStr (#0);
  MsgSubj := GetStr (#0);
  MsgTime := Copy(MsgDate, 12, 5);

  If Not NetMail Then Begin
    MsgArea := GetStr (#13);

    Delete (MsgArea, Pos('AREA:', MsgArea), 5);
  End;

  Tmp := strUpper(Copy(MsgDate, 4, 3));

  For Res := 1 to 12 Do
    If strUpper(MonthString[Res]) = Tmp Then Begin
      Tmp := strZero(Res);
      Break;
    End;

  MsgDate := Tmp + '/' + Copy(MsgDate, 1, 2) + '/' + Copy(MsgDate, 8, 2);

  DisposeText;

  MsgSize       := 0;
  Result        := True;
  MsgLines      := 1;
  MsgCRC.Header := StringCRC32(MsgDate + MsgTime + MsgArea + MsgFrom + MsgTo + MsgSubj);
  MsgCRC.Text   := $FFFFFFFF;

  New (MsgText[MsgLines]);

  MsgText[MsgLines]^ := '';

  Repeat
    Ch := MsgFile.Read;

    Case Ch of
      #000 : Break;
      #010 : ;
      #013 : Begin
               If MsgLines = mysMaxMsgLines Then Begin
                 Repeat
                   Ch := MsgFile.Read;
                 Until (Ch = #0) or (MsgFile.EOF);

                 Break;
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
              Ch := MsgFile.Read;
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

Procedure TPKTReader.AddDuplicate;
Var
  F: File;
Begin
  Assign (F, bbsConfig.DataPath + 'echodupes.dat');

  If Not ioReset (F, 1, fmRWDN) Then
    ioReWrite (F, 1, fmRWDN);

  Seek       (F, FileSize(F));
  BlockWrite (F, MsgCRC, SizeOf(RecMsgDupe));
  Close      (F);
End;

Function TPKTReader.IsDuplicate : Boolean;
Var
  Dupe : RecMsgDupe;
  Res  : LongInt;
Begin
  Result := False;

  If Not DupeFile.Open (bbsConfig.DataPath + 'echodupes.dat') Then Exit;

  While Not DupeFile.EOF Do Begin
    DupeFile.BlockRead (Dupe, SizeOf(RecMsgDupe), Res);

    If (Dupe.Text = MsgCRC.Text) and (Dupe.Header = MsgCRC.Header) Then Begin
      Result := True;

      Break;
    End;
  End;

  DupeFile.Close;
End;

End.

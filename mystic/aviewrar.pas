Unit AViewRAR;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  RarHeaderRec = Record
    CRC     : Word;
    HdrType : Byte;
    Flags   : Word;
    Size    : Word;
  End;

  RarFileRec = Record
    PackSize : LongInt;
    Size     : LongInt;
    HostOS   : Byte;
    FileCRC  : LongInt;
    Time     : LongInt;
    Version  : Byte;
    Method   : Byte;
    FNSize   : SmallInt;
    Attr     : Longint;
  End;

  PRarArchive = ^TRarArchive;
  TRarArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  Private
    RAR     : RarFileRec;
    Hdr     : RarHeaderRec;
    ArcHdr  : Array[1..7] of Byte;
    NextPos : LongInt;
    Offset  : LongInt;
  End;

Implementation

Constructor TRarArchive.Init;
Begin
End;

Procedure TRarArchive.FindFirst (Var SR : ArcSearchRec);
Begin
  If Eof(ArcFile) Then Exit;

  BlockRead (ArcFile, ArcHdr[1], 7);      // marker header
  BlockRead (ArcFile, Hdr, SizeOf(Hdr));  // archive header

  If Hdr.HdrType <> $73 Then Exit;

  NextPos := FilePos(ArcFile) + Hdr.Size - 7;

  FindNext (SR);
End;

Procedure TRarArchive.FindNext (Var SR: ArcSearchRec);
Begin
  Repeat
    Seek (ArcFile, NextPos);

    If Eof(ArcFile) Then Exit;

    BlockRead (ArcFile, Hdr, SizeOf(Hdr));

    If (Hdr.HdrType = $74) Then Begin
      BlockRead (ArcFile, RAR, SizeOf(RAR));
      BlockRead (ArcFile, SR.Name[1], RAR.FNSize);

      SR.Name[0] := Chr(RAR.FNSize);

      If RAR.Attr = 16 Then SR.Attr := $10;

      SR.Time := RAR.Time;
      SR.Size := RAR.Size;

      NextPos := NextPos + Hdr.Size + RAR.PackSize;

      Break;
    End Else Begin
      If (Hdr.Flags And $8000) = 0 Then
        NextPos := NextPos + Hdr.Size
      Else Begin
        BlockRead (ArcFile, Offset , 4);

        NextPos := NextPos + Hdr.Size + Offset;
      End;
    End;
  Until Eof(ArcFile);
End;

End.

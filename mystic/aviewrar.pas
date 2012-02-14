Unit AViewRAR;

{$I M_OPS.PAS}

(* DOES NOT WORK IF FILE HAS COMMENTS... NEED TO READ SKIP ADDSIZE IF NOT $74

1. Read and check marker block
2. Read archive header
3. Read or skip HEAD_SIZE-sizeof(MAIN_HEAD) bytes
4. If end of archive encountered then terminate archive processing,
   else read 7 bytes into fields HEAD_CRC, HEAD_TYPE, HEAD_FLAGS,
   HEAD_SIZE.
5. Check HEAD_TYPE.
   if HEAD_TYPE==0x74
     read file header ( first 7 bytes already read )
     read or skip HEAD_SIZE-sizeof(FILE_HEAD) bytes
     if (HEAD_FLAGS & 0x100)
       read or skip HIGH_PACK_SIZE*0x100000000+PACK_SIZE bytes
     else
       read or skip PACK_SIZE bytes
   else
     read corresponding HEAD_TYPE block:
       read HEAD_SIZE-7 bytes
       if (HEAD_FLAGS & 0x8000)
         read ADD_SIZE bytes
6. go to 4.
*)

Interface

Uses
  DOS,
  AView;

Type
  RarHeaderRec = Record
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
    Procedure   FindFirst (Var SR : ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR : ArcSearchRec); Virtual;
  Private
    RAR    : RarHeaderRec;
    Buf    : Array[1..12] of Byte;
    Offset : Word;
  End;

Implementation

Constructor TRarArchive.Init;
Begin
End;

Procedure TRarArchive.FindFirst (Var SR : ArcSearchRec);
Begin
  If Eof(ArcFile) Then Exit;

  BlockRead (ArcFile, Buf[1], 12);

  If Buf[10] <> $73 Then Exit;

  BlockRead (ArcFile, offset, 2);
  BlockRead (ArcFile, Buf[1], 6);

  Seek (ArcFile, FilePos(ArcFile) + (offset - 13));
  FindNext (SR);
End;

Procedure TRarArchive.FindNext (Var SR: ArcSearchRec);
Begin
  If Eof(ArcFile) Then Exit;

  BlockRead (ArcFile, Buf[1], 5);

  If Buf[3] <> $74 Then Exit;

  BlockRead (ArcFile, Offset, 2);
  BlockRead (ArcFile, RAR, SizeOf(RAR));
  BlockRead (ArcFile, SR.Name[1], RAR.FNSize);

  SR.Name[0] := Chr(RAR.FNSize);

  SR.Time := RAR.Time;
  SR.Size := RAR.Size;

  If RAR.Attr = 16 Then SR.Attr := $10;

  Seek(ArcFile, FilePos(ArcFile) + (Offset - (SizeOf(RAR) + 7 + Length(SR.Name))) + RAR.PackSize);
End;

End.
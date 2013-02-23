Unit AViewZip;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  ZFLocalHeader = Record
    Signature  : LongInt;
    Version,
    GPBFlag,
    Compress,
    Date,
    Time       : Word;
    CRC32,
    CSize,
    USize      : LongInt;
    FNameLen,
    ExtraField : Word;
  End;

  ZFCentralHeader = Record
    Signature  : LongInt;
    Version    : Word;
    Needed     : Word;
    Flags      : Word;
    Compress   : Word;
    Date       : Word;
    Time       : Word;
    Crc32      : LongInt;
    CSize      : LongInt;
    USize      : LongInt;
    FNameLen   : Word;
    ExtraField : Word;
    CommentLen : Word;
    DiskStart  : Word;
    iFileAttr  : Word;
    eFileAttr  : LongInt;
    Offset     : LongInt;
  End;

Type
  PZipArchive = ^TZipArchive;

  TZipArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR : ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR : ArcSearchRec); Virtual;

    Private
                Hdr   : ZFLocalHeader;
                cHdr  : ZFCentralHeader;
                cFile : Word;
                tFile : Word;
                Procedure GetHeader (Var SR : ArcSearchRec);
  End;

Implementation

Const
  LocalSig   = $04034B50;
  CentralSig = $02014b50;

Constructor TZipArchive.Init;
Begin
  tFile  := 0;
  cFile  := 0;
End;

Procedure TZipArchive.GetHeader (Var SR : ArcSearchRec);
Var
  S : String;
Begin
  FillChar (SR, SizeOf(SR), 0);
  S := '';

  If Eof(ArcFile) or (cFile = tFile) Then Exit;

  BlockRead (ArcFile, cHdr, SizeOf(cHdr));
  BlockRead (ArcFile, S[1], cHdr.FNameLen);

  S[0] := Chr(cHdr.FNameLen);

  If cHdr.Signature = CentralSig Then Begin
    Inc (cFile);

    If (S[Length(S)] = '/') and (cHdr.uSize = 0) Then SR.Attr := 16;

    SR.Name := S;
    SR.Size := cHdr.uSize;
    SR.Time := cHdr.Date + cHdr.Time * LongInt(256 * 256);
  End;

  Seek (ArcFile, FilePos(ArcFile) + cHdr.ExtraField + cHdr.CommentLen);
End;

Procedure TZipArchive.FindFirst (Var SR : ArcSearchRec);
Var
  CurPos : LongInt;
  bRead  : LongInt;
Begin
  BlockRead (ArcFile, Hdr, SizeOf(Hdr));

  While Hdr.Signature = LocalSig Do Begin
    Inc (tFile);

    CurPos := FilePos(ArcFile) + Hdr.FNameLen + Hdr.ExtraField + Hdr.cSize;

    Seek (ArcFile, CurPos);

    BlockRead (ArcFile, Hdr, SizeOf(Hdr), bRead);

    If bRead <> SizeOf(Hdr) Then Exit;
  End;

  Seek (ArcFile, CurPos);

  GetHeader(SR);
End;

Procedure TZipArchive.FindNext (Var SR : ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.

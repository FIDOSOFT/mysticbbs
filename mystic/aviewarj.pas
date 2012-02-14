Unit AViewARJ;

{$I M_OPS.PAS}

Interface

Uses
  Dos,
  AView;

Const
  flag_DIR = $10;

Type
  AFHeader = Record
    HeadId  : Word;
    BHdrSz  : Word;
    HdrSz   : Byte;
    AVNo    : Byte;
    MAVX    : Byte;
    HostOS  : Byte;
    Flags   : Byte;
    SVer    : Byte;
    FType   : Byte;
    Res1    : Byte;
    DOS_DT  : LongInt;
    CSize   : LongInt;
    OSize   : LongInt;
    SEFP    : LongInt;
    FSFPos  : Word;
    SEDLgn  : Word;
    Res2    : Word;
    NameDat : Array[1..120] of Char;
    Res3    : Array[1..10] of Char;
  End;

Type
  PArjArchive = ^TArjArchive;
  TArjArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR : ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR : ArcSearchRec); Virtual;
  Private
    _FHdr : AFHeader;
    _SL   : LongInt;
    Procedure GetHeader (Var SR : ArcSearchRec);
  End;

Implementation

Const
  BSize = 4096;

Var
  BUFF : Array[1..BSize] of Byte;

Constructor TArjArchive.Init;
Begin
  FillChar (_FHdr, SizeOf(_FHdr), 0);
End;

Procedure TArjArchive.GetHeader(var sr:ArcSearchRec);
Var
  {$IFDEF MSDOS}
  BC : Word;
  {$ELSE}
  BC : LongInt;
  {$ENDIF}
  B  : Byte;
Begin
  FillChar (_FHdr, SizeOf(_FHdr), #0);
  FillChar (Buff, BSize, #0);
  Seek (ArcFile, _SL);
  BlockRead (ArcFile, BUFF, BSIZE, BC);
  Move(BUFF[1], _FHdr, SizeOf(_FHdr));
  With _FHdr Do Begin
    If BHdrSz > 0 Then Begin
      B       := 1;
      SR.Name := '';
      While NameDat[B] <> #0 Do Begin
        If NameDat[B] = '/' Then
          SR.Name := ''
        Else
          SR.Name := SR.Name + NameDat[B];
        Inc(B);
      End;
      SR.Size := BHdrSz + CSize;
      If FType = 2 Then SR.Size := BHdrSz;
      If BHdrSz = 0 Then SR.Size := 0;
      Inc(_SL, SR.Size + 10);
      SR.Time := DOS_DT;
{      If Flags and flag_DIR > 0 Then SR.Attr := 16 Else SR.Attr := 0;}
{		If (SR.Name[Length(SR.Name)] = '/') and (SR.Size = 0) Then SR.Attr := 16;}

    End;
  End;
End;

Procedure TArjArchive.FindFirst (Var SR : ArcSearchRec);
Begin
  _SL := 0;
  GetHeader (SR);
  GetHeader (SR);
End;

Procedure TArjArchive.FindNext (Var SR : ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.

Unit aviewlzh;

{$I M_OPS.PAS}

Interface

Uses      Dos,aview;

Type      LFHeader=Record
                     Headsize,Headchk          :byte;
                     HeadID                    :packed Array[1..5] of char;
                     Packsize,Origsize,Filetime:longint;
                     Attr                      :word;
                     Filename                  :string[12];
                     f32                       :pathstr;
                     dt                        :DateTime;
                   end;


type      PLzhArchive=^TLzhArchive;
          TLzhArchive=object(TGeneralArchive)
                        constructor Init;
                        procedure FindFirst(var sr:ArcSearchRec);virtual;
                        procedure FindNext(var sr:ArcSearchRec);virtual;
                      private
                        _FHdr:LFHeader;
                        _SL:longint;
                        procedure GetHeader(var sr:ArcSearchRec);
                      end;


Implementation


constructor TLzhArchive.Init;
begin
  _SL:=0;
  FillChar(_FHdr,sizeof(_FHdr),0);
end;


procedure TLzhArchive.GetHeader(var sr:ArcSearchRec);
Var
  {$IFDEF MSDOS}
  NR : Word;
  {$ELSE}
  NR : LongInt;
  {$ENDIF}
begin
  fillchar(sr,sizeof(sr),0);
  seek(ArcFile,_SL);
  if eof(ArcFile) then Exit;
  blockread(ArcFile,_FHdr,sizeof(LFHeader),nr);
  if _FHdr.headsize=0 then exit;
  inc(_SL,_FHdr.headsize);
  inc(_SL,2);
  inc(_SL,_FHdr.packsize);
  if _FHdr.headsize<>0 then
    UnPackTime(_FHdr.FileTime,_FHdr.DT);
  sr.Name:=_FHdr.FileName;
  sr.Size:=_FHdr.OrigSize;
  sr.Time:=_FHdr.FileTime;
end;


procedure TLzhArchive.FindFirst(var sr:ArcSearchRec);
begin
  _SL:=0;
  GetHeader(sr);
end;


procedure TLzhArchive.FindNext(var sr:ArcSearchRec);
begin
  GetHeader(sr);
end;


end.

{ CUT ----------------------------------------------------------- }

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
Unit m_FileIO;

{$I M_OPS.PAS}

Interface

{ FILE ACCESS FUNCTIONS }

Function ioReset      (Var F: File; RecSize: Word; Mode: Byte) : Boolean;
Function ioReWrite    (Var F: File; RecSize: Word; Mode: Byte) : Boolean;
Function ioSeek       (Var F: File; FPos: LongInt) : Boolean;
Function ioRead       (Var F: File; Var Rec) : Boolean;
Function ioWrite      (Var F: File; Var Rec) : Boolean;
Function ioBlockRead  (Var F: File; Var Rec; dSize: LongInt; Var Res: LongInt) : Boolean;
Function ioBlockWrite (Var F: File; Var Rec; dSize: LongInt; Var Res: LongInt) : Boolean;

{ FILE MANIPULATION FUNCTIONS }

Function  FileExist       (Str: String) : Boolean;
Function  FileErase       (Str: String) : Boolean;
Function  JustFileName    (Str: String) : String;
Function  JustFile        (Str: String) : String;
Function  JustFileExt     (Str: String) : String;
Function  JustPath        (Str: String) : String;
Function  WildMatch       (WildCard, FName: String; IgnoreCase: Boolean) : Boolean;
Function  DirCreate       (Str: String) : Boolean;
Function  DirExists       (Str: String) : Boolean;
Function  DirSlash        (Str: String) : String;
Function  DirLast         (CurPath: String) : String;
Function  DirChange       (Dir: String) : Boolean;
Procedure DirClean        (Path: String; Exempt: String);
Function  DirFiles        (Str: String) : LongInt;
Function  FileRename      (OldFN, NewFN: String) : Boolean;
Function  FileCopy        (Source, Target: String) : Boolean;
Function  FileFind        (FN: String) : String;
Function  FileByteSize    (FN: String) : Int64;
Function  FileNewExt      (FN, NewExt: String) : String;

{ GLOBAL FILEIO VARIABLES AND CONSTANTS }

Var
  ioCode : LongInt;

Const
  fmReadOnly  = 0;
  fmWriteOnly = 1;
  fmReadWrite = 2;
  fmDenyAll   = 16;
  fmDenyWrite = 32;
  fmDenyRead  = 48;
  fmDenyNone  = 64;
  fmNoInherit = 128;
  fmRWDN      = 66;
  fmRWDR      = 50;
  fmRWDW      = 34;

{ STREAMING CLASS OPTIONS }

Const
  MaxFileBufferSize = 64 * 1024;

Type
  TFileBufferOpenType = (
    fmOpen,
    fmOpenCreate,
    fmOpenAppend,
    fmCreate
  );

  PFileBufferRec = ^TFileBufferRec;
  TFileBufferRec = Array[0..MaxFileBufferSize - 1] of Char;

  TFileBuffer = Class
    RecSize  : LongInt;
    BufSize  : LongInt;
    Buffer   : PFileBufferRec;
    BufRead  : LongInt;
    BufStart : LongInt;
    BufEnd   : LongInt;
    BufPos   : LongInt;
    InFile   : File;
    BufEOF   : Boolean;
    BufDirty : Boolean;
    IsOpened : Boolean;

    Constructor Create (BufferSize: LongInt);
    Destructor  Destroy; Override;

    Function    OpenStream   (FN: String; RS: LongInt; OpenType: TFileBufferOpenType; OpenMode: Byte) : Boolean;
    Procedure   CloseStream;
    Function    ReadChar     : Char;
//    Function    ReadLine     : String;
    Procedure   ReadBlock    (Var Buf; Size: LongInt; Var Count: LongInt); Overload;
    Procedure   ReadBlock    (Var Buf; Size: LongInt); Overload;
    Procedure   ReadRecord   (Var Buf);
    Procedure   SeekRecord   (RP: LongInt);
    Procedure   SeekRaw      (FP: LongInt);
    Procedure   WriteBlock   (Var Buf; Size: LongInt);
    Procedure   WriteRecord  (Var Buf);

    Function    FilePosRaw     : LongInt;
    Function    FilePosRecord  : LongInt;
    Function    FileSizeRaw    : LongInt;
    Function    FileSizeRecord : LongInt;
    Function    EOF            : Boolean;

    Procedure   FillBuffer;
    Procedure   FlushBuffer;
  End;

Implementation

Uses
  {$IFDEF WINDOWS}   // FileErase (FPC Erase) hardly EVER WORKS
    Windows,
  {$ENDIF}
  DOS,
  m_Types,
  m_Strings,
  m_DateTime;

Const
  ioRetries  = 20;
  ioWaitTime = 100;

Function ioReset (Var F: File; RecSize: Word; Mode: Byte) : Boolean;
Var
  Count : Word;
Begin
  FileMode := Mode;
  Count    := 0;
  ioCode   := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    {$I-} Reset (F, RecSize); {$I+}
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  Result := (ioCode = 0);
End;

Function ioReWrite (Var F: File; RecSize: Word; Mode: Byte) : Boolean;
Var
  Count : Word;
Begin
  FileMode := Mode;
  Count    := 0;
  ioCode   := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    ReWrite (F, RecSize);
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioReWrite := (ioCode = 0);
End;

Function ioSeek (Var F: File; FPos: LongInt) : Boolean;
Var
  Count : Word;
Begin
  Count  := 0;
  ioCode := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    {$I-} Seek (F, FPos); {$I+}
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioSeek := (ioCode = 0);
End;

Function ioBlockRead (Var F: File; Var Rec; dSize: LongInt; Var Res: LongInt) : Boolean;
Var
  Count : Word;
Begin
  Count  := 0;
  ioCode := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    BlockRead (F, Rec, dSize, Res);
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioBlockRead := (ioCode = 0);
End;

Function ioBlockWrite (Var F: File; Var Rec; dSize: LongInt; Var Res: LongInt) : Boolean;
Var
  Count : Word;
Begin
  Count  := 0;
  ioCode := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    BlockWrite (F, Rec, dSize, Res);
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioBlockWrite := (ioCode = 0);
End;

Function ioRead (Var F: File; Var Rec) : Boolean;
Var
  Count : Word;
Begin
  Count  := 0;
  ioCode := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    {$I-} BlockRead (F, Rec, 1); {$I+}
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioRead := (ioCode = 0);
End;

Function ioWrite (Var F: File; Var Rec) : Boolean;
Var
  Count : Word;
Begin
  Count  := 0;
  ioCode := 5;

  While (Count < ioRetries) and (ioCode = 5) Do Begin
    BlockWrite (F, Rec, 1);
    ioCode := IoResult;
    Inc (Count);
    If ioCode = 5 Then WaitMS(ioWaitTime);
  End;

  ioWrite := (ioCode = 0);
End;

Function FileCopy (Source, Target: String) : Boolean;
Var
  SF      : File;
  TF      : File;
  BRead   : LongInt;
  BWrite  : LongInt;
  FileBuf : Array[1..4096] of Char;
Begin
  Result   := False;
  FileMode := 66;

  Assign (SF, Source);
  {$I-} Reset(SF, 1); {$I+}

  If IOResult <> 0 Then Exit;

  Assign (TF, Target);
  {$I-} ReWrite(TF, 1); {$I+}

  If IOResult <> 0 then Exit;

  Repeat
    BlockRead  (SF,  FileBuf, SizeOf(FileBuf), BRead);
    BlockWrite (TF, FileBuf, BRead, BWrite);
  Until (BRead = 0) or (BRead <> BWrite);

  Close(SF);
  Close(TF);

  Result := BRead = BWrite;
End;

Function FileRename (OldFN, NewFN: String) : Boolean;
Var
  OldF : File;
Begin
  Assign (OldF, NewFN);
  {$I-} Erase (OldF); {$I+}
  If IoResult = 0 Then;

  Assign (OldF, OldFN);
  {$I-} ReName (OldF, NewFN); {$I+}

  Result := (IoResult = 0);
End;

Function DirCreate (Str: String) : Boolean;
Var
  Count  : Byte;
  CurDir : String;
  Prefix : String;
Begin
  Result := True;
  Prefix := '';
  Str    := DirSlash(Str);

  If DirExists(Str) Then Exit;

  Count := Pos(PathSep, Str);

  While (Count > 0) Do Begin
    CurDir := Copy(Str, 1, Count);

    Delete (Str, 1, Count);

    Prefix := Prefix + CurDir;

    If Not DirExists(Prefix) Then Begin
      {$I-} MkDIR (Prefix); {$I+}
      If IoResult <> 0 Then Begin
        Result := False;
        Exit;
      End;
    End;

    Count := Pos(PathSep, Str);
  End;
End;

Procedure DirClean (Path: String; Exempt: String);
Var
  DirInfo: SearchRec;
Begin
  FindFirst(Path + '*', Archive, DirInfo);

  While DosError = 0 Do Begin
    If strUpper(Exempt) <> strUpper(DirInfo.Name) Then
      FileErase(Path + DirInfo.Name);

    FindNext(DirInfo);
  End;
    FindClose(DirInfo);
End;

Function DirChange (Dir: String) : Boolean;
Begin
  While Dir[Length(Dir)] = PathSep Do Dec(Dir[0]);

  Dir := Dir + PathSep;

  {$I-} ChDir(Dir); {$I+}

  Result := IoResult = 0;
End;

Function DirSlash (Str: String) : String;
Begin
  If Copy(Str, Length(Str), 1) <> PathSep Then
    Str := Str + PathSep;

  Result := Str;
End;

Function DirLast (CurPath: String) : String;
Begin
  If CurPath[Length(CurPath)] = PathSep Then
    Delete (CurPath, Length(CurPath), 1);

  While (CurPath[Length(CurPath)] <> PathSep) and (CurPath <> '') Do
    Delete (CurPath, Length(CurPath), 1);

  Result := DirSlash(CurPath);
End;

Function JustPath (Str: String) : String;
Var
  Count : Byte;
Begin
  For Count := Ord(Str[0]) DownTo 1 Do
    If (Str[Count] = '/') or (Str[Count] = '\') Then Begin
      Delete (Str, Count + 1, 255);
      Break;
    End;

  Result := Str;
End;

Function JustFile (Str: String) : String;
Var
  Count : Byte;
Begin
  For Count := Length(Str) DownTo 1 Do
    If (Str[Count] = '/') or (Str[Count] = '\') Then Begin
      Delete (Str, 1, Count);
      Break;
    End;

  Result := Str;
End;

Function JustFileName (Str: String) : String;
Var
  Temp : Byte;
Begin
  Result := Str;

  For Temp := Length(Result) DownTo 1 Do
    If Result[Temp] = '.' Then Begin
      Delete (Result, Temp, 255);
      Break;
    End;
End;

Function JustFileExt (Str: String) : String;
Var
  Temp : Byte;
Begin
  Result := '';

  For Temp := Length(Str) DownTo 1 Do
    If Str[Temp] = '.' Then Begin
      Result := Copy(Str, Temp + 1, Length(Str));
      Exit;
    End;
End;

Function WildMatch (WildCard, FName: String; IgnoreCase: Boolean) : Boolean;
Begin
  Result := False;

  If FName = '' Then Exit;

  If IgnoreCase Then Begin
    WildCard := strUpper(WildCard);
    FName    := strUpper(FName);
  End;

  Case Wildcard[1] of
    '*' : Begin
            If FName[1] = '.' Then Exit;
            If Length(Wildcard) = 1 Then Result := True;
            If (Length(Wildcard) > 1) and (Wildcard[2] = '.') and (Length(FName) > 0) Then
              Result := WildMatch(Copy(Wildcard, 3, Length(Wildcard) - 2), Copy(FName, Pos('.', FName) + 1, Length(FName)-Pos('.', FName)), False);
          End;
    '?' : If Ord(Wildcard[0]) = 1 Then
            Result := True
          Else
            Result := WildMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1), False);
  Else
    If FName[1] = Wildcard[1] Then
      If Length(Wildcard) > 1 Then
        Result := WildMatch(Copy(Wildcard, 2, Length(Wildcard) - 1), Copy(FName, 2, Length(FName) - 1), False)
      Else
        Result := (Length(FName) = 1) And (Length(Wildcard) = 1);
  End;
End;

{$IFDEF WINDOWS}
Function FileErase (Str: String) : Boolean;
Begin
  Str    := Str + #0;
  Result := Windows.DeleteFile(PChar(@Str[1]));
End;
{$ELSE}
Function FileErase (Str: String) : Boolean;
Var
  F : File;
Begin
  {$I-}

  Assign (F, Str);
  Erase  (F);

  Result := IoResult = 0;
End;
{$ENDIF}
Function FileExist (Str: String) : Boolean;
Var
  DF   : File;
  Attr : Word;
Begin
  Assign   (DF, Str);
  GetFattr (DF, Attr);

  Result := (DosError = 0) and (Attr And Directory = 0);
End;

Function DirExists (Str: String) : Boolean;
Var
  F    : File;
  Attr : Word;
Begin
  Result := False;

  If Str = '' Then Exit;

  While Str[Length(Str)] = PathSep Do Dec(Str[0]);
  Str := Str + PathSep + '.';

  Assign   (F, Str);
  GetFAttr (F, Attr);

  Result := ((Attr And Directory) = Directory);
End;

Function FileFind (FN: String) : String;
Var
  Dir : SearchRec;
Begin
  Result := FN;

  FindFirst (JustPath(FN) + '*', AnyFile, Dir);

  While DosError = 0 Do Begin
    If strUpper(Dir.Name) = strUpper(JustFile(FN)) Then Begin
      Result := JustPath(FN) + Dir.Name;
      Break;
    End;

    FindNext(Dir);
  End;

  FindClose(Dir);
End;

Function FileByteSize (FN: String) : Int64;
Var
  Dir : SearchRec;
Begin
  Result := 0;

  FindFirst (FN, AnyFile, Dir);

  If DosError = 0 Then Result := Dir.Size;

  FindClose(Dir);
End;

Function DirFiles (Str: String) : LongInt;
Var
  DirInfo : SearchRec;
Begin
  Result := 0;

  FindFirst (Str + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory = 0 Then
      Inc (Result);

    FindNext(DirInfo);
  End;

  FindClose (DirInfo);
End;

Function FileNewExt (FN, NewExt: String) : String;
Var
  Temp : Byte;
Begin
  For Temp := Length(FN) DownTo 1 Do
    If FN[Temp] = '.' Then Begin
      Result := Copy(FN, 1, Temp) + NewExt;
      Exit;
    End;

  Result := FN + '.' + NewExt;
End;

{ FILE STREAMING FUNCTIONS }

Constructor TFileBuffer.Create (BufferSize: LongInt);
Begin
  Inherited Create;

  RecSize  := 1;
  BufSize  := BufferSize;
  BufStart := 0;
  BufEnd   := 0;
  BufPos   := 0;
  BufEOF   := False;
  BufRead  := 0;
  Buffer   := NIL;
  BufDirty := False;
  IsOpened := False;
End;

Destructor TFileBuffer.Destroy;
Begin
  If IsOpened Then CloseStream;
End;

Function TFileBuffer.OpenStream (FN: String; RS: LongInt; OpenType: TFileBufferOpenType; OpenMode: Byte) : Boolean;
Begin
  Result  := False;
  RecSize := RS;

  If IsOpened Then CloseStream;

  Assign (InFile, FN);

  Case OpenType of
    fmOpen       : If Not ioReset (InFile, 1, OpenMode) Then Exit;
    fmOpenCreate,
    fmOpenAppend : If Not ioReset (InFile, 1, OpenMode) Then
                     If Not FileExist(FN) Then Begin
                       If Not ioReWrite (InFile, 1, OpenMode) Then Exit;
                     End Else
                       Exit;
    fmCreate     : If Not ioReWrite (InFile, 1, OpenMode) Then Exit;
  End;

  If OpenType = fmOpenAppend Then
    ioSeek (InFile, System.FileSize(InFile));

  GetMem (Buffer, BufSize);

  FillBuffer;

  BufDirty := False;
  IsOpened := True;
  Result   := True;
End;

Procedure TFileBuffer.CloseStream;
Begin
  If IsOpened Then Begin
    If BufDirty Then FlushBuffer;

    System.Close (InFile);
  End;

  If Assigned(Buffer) Then Begin
    FreeMem (Buffer, BufSize);

    Buffer := NIL;
  End;

  IsOpened := False;
End;

Function TFileBuffer.FilePosRaw : LongInt;
Begin
  Result := BufStart + BufPos;
End;

Function TFileBuffer.FilePosRecord : LongInt;
Begin
  Result := (BufStart + BufPos) DIV RecSize;
End;

Procedure TFileBuffer.FillBuffer;
Var
  Start : LongInt;
Begin
  Start := System.FilePos(InFile);

  System.BlockRead (InFile, Buffer^[0], BufSize, BufRead);

  BufStart := Start;
  BufEnd   := Start + BufRead;
  BufPos   := 0;
  BufEOF   := System.EOF(InFile);
End;

Function TFileBuffer.ReadChar : Char;
Begin
  If BufPos >= BufSize Then FillBuffer;

  Result := Buffer^[BufPos];

  Inc (BufPos);
End;

(*
Function TFileBuffer.ReadLine : String;
Var
  Ch : Char;
Begin
  Result := '';

  While Not Self.EOF Do Begin
    Ch := Self.ReadChar;

    If LineEnding[1] = Ch Then Begin
      If Length(LineEnding) = 1 Then Break;

      Ch := Self.ReadChar;

      If LineEnding[2] = Ch Then Break;

      Result := Result + LineEnding[1];
    End;

    Result := Result + Ch;
  End;
End;
*)

Procedure TFileBuffer.ReadRecord (Var Buf);
Begin
  Self.ReadBlock (Buf, RecSize);
End;

Procedure TFileBuffer.SeekRecord (RP: LongInt);
Begin
  Self.SeekRaw (RP * RecSize);
End;

Procedure TFileBuffer.WriteBlock (Var Buf; Size: LongInt);
Var
  Offset : LongInt;
Begin
  If BufPos + Size > BufSize Then Begin
    Offset := BufSize - BufPos;

    If Offset > 0 Then
      Move (Buf, Buffer^[BufPos], Offset);

    BufRead := BufSize;

    FlushBuffer;

    // -----
    Move (TFileBufferRec(Buf)[Offset], Buffer^[0], Size - Offset);

    BufStart := System.FilePos(InFile);
    BufEnd   := BufStart + Size - Offset;
    BufPos   := Size - Offset;
    BufEOF   := System.EOF(InFile);
    BufRead  := BufPos;

(*  the above replaces the 3 lines below... but is it reliable?
    FillBuffer;

    Move (TFileBufferRec(Buf)[Offset], Buffer^[BufPos], Size - Offset);

    BufPos := BufPos + Size - Offset;
*)
  End Else Begin
    Move (Buf, Buffer^[BufPos], Size);
    Inc  (BufPos, Size);
  End;

  If BufPos > BufEnd  Then BufEnd  := BufPos;
  If BufPos > BufRead Then BufRead := BufPos;

  BufDirty := True;
End;

Procedure TFileBuffer.WriteRecord (Var Buf);
Begin
  Self.WriteBlock (Buf, RecSize);
End;

Procedure TFileBuffer.ReadBlock (Var Buf; Size: LongInt);
Var
  Res : LongInt;
Begin
  Self.ReadBlock (Buf, Size, Res);
End;

Procedure TFileBuffer.ReadBlock (Var Buf; Size: LongInt; Var Count: LongInt);
Begin
  If BufPos + Size >= BufRead Then Begin
    If BufDirty Then FlushBuffer;

    If Size > BufSize Then Size := BufSize;

    System.Seek(InFile, BufStart + BufPos);

    FillBuffer;

    If BufRead < Size Then Size := BufRead;
  End;

  Move (Buffer^[BufPos], Buf, Size);
  Inc  (BufPos, Size);

  Count := Size;
End;

Procedure TFileBuffer.SeekRaw (FP : LongInt);
Begin
  If (FP >= BufStart) and (FP < BufEnd) Then
    BufPos := (BufEnd - (BufEnd - FP)) - BufStart
  Else Begin
    If BufDirty Then FlushBuffer;

    System.Seek(InFile, FP);

    FillBuffer;
  End;
End;

Function TFileBuffer.EOF : Boolean;
Begin
  Result := (BufStart + BufPos >= BufEnd) and BufEOF;
End;

Function TFileBuffer.FileSizeRaw : LongInt;
Begin
  If BufDirty Then FlushBuffer;

  Result := System.FileSize(InFile);
End;

Function TFileBuffer.FileSizeRecord : LongInt;
Begin
  If BufDirty Then FlushBuffer;

  Result := System.FileSize(InFile) DIV RecSize;
End;

Procedure TFileBuffer.FlushBuffer;
Var
  Res : LongInt;
Begin
  System.Seek       (InFile, BufStart);
  System.BlockWrite (InFile, Buffer^, BufRead, Res);

  BufDirty := False;
End;

End.

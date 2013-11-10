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
Unit m_Prot_Base;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  m_FileIO,
  m_io_Base;

Const
  ecUserAbort              = 2926;  {User aborted during "wait"}
  ecCancelRequested        = 9902;  {Cancel requested}
  ecDirNotFound            = 9905;  {Directory not found in protocol transmit}
  ecNoMatchingFiles        = 9906;  {No matching files in protocol transmit}
  ecLongPacket             = 9907;  {Long packet received during protocol}
  ecEndFile                = 9908;  {End of transmitted file}
  ecHandshakeInProgress    = 9909;  {Initial protocol handshake in progress}
  ecFileRenamed            = 9910;  {Incoming file was renamed}
  ecFileAlreadyExists      = 9911;  {Incoming file already exists}
  ecBlockCheckError        = 9915;  {Incorrect CRC or checksum received}
  ecTooManyErrors          = 9920;  {Too many errors received during protocol}
  ecBadFileList            = 9921;  {No end of list marker found in file list}
  ecGotCrcE                = 9925;  {Zmodem - got CrcE DataSubpacket}
  ecGotCrcW                = 9926;  {Zmodem - got CrcW DataSubpacket}
  ecGotCrcQ                = 9927;  {Zmodem - got CrcQ DataSubpacket}
  ecGotCrcG                = 9928;  {Zmodem - got CrcG DataSubpacket}
  ecGarbage                = 9929;  {Zmodem - got garbage from remote}
  ecSkipFile               = 9930;  {Zmodem - skip file}
  ecFileDoesntExist        = 9932;  {Zmodem - specified file doesn't exist}
  ecCantWriteFile          = 9933;  {Zmodem - not allowed to overwrite file}
  ecFailedToHandshake      = 9934;  {Zmodem - never got proper handshake}
  ecNoFilesToReceive       = 9935;  {Zmodem - no files to receive}
  ecBuffersTooSmall        = 9936;  {ZModem - port buffers too small}
  ecGotHeader              = 9937;  {Zmodem - got a complete header}
  ecNoHeader               = 9938;  {Zmodem - (internal) no header yet}
  ecTimeout                = 2923;  {Timed out waiting for something}
  ecBufferIsFull           = 2921;  {No room for new char in buffer}
  ecBufferIsEmpty          = 2922;  {No characters to get}
  ecOutOfMemory            = 0008;  {Insufficient memory}
  ecOk                     = 0;     {Reset value for AsyncStatus}
  ecFileNotFound           = 0002;  {File not found}
  ecDiskFull               = 0101;  {Disk is full}
  ecNotOpen                = 0103;  {File not open}

Const
  cCan  = #24;
  cStx  = #2;
  cSoh  = #1;
  cBS   = #8;
  cNak  = #21;
  cAck  = #6;
  cEot  = #4;
  cDle  = #16;
  cXon  = #17;
  cXoff = #19;
  cCR   = #13;
  cLF   = #10;

const
  FileBufferSize    = 8192;    {Size of working buffer for receive/xmit files}
  DefHandshakeWait  = 1000;   {Wait time for resp during handshake (10 sec)}
  DefHandshakeRetry = 10;   {Number of times to retry handshake}
  DefTransTimeout   = 3000;   {Tics to wait for receiver flow control release}
  DefStatusInterval = 100;

  BlockFillChar : Char = ^Z;     {Fill character for partial protocol blocks}
type
  AbstractProtocolPtr = ^AbstractProtocol;

  ProtocolStateType = (
    psReady,
    psWaiting,
    psFinished);

  WriteFailOptions = (WriteFail, WriteRename, WriteAnyway, WriteResume);

  DataBlockType   = Array[1..1024] of Char;
  FileBufferArray = Array[0..FileBufferSize - 1] of Byte;

  FileListType = Array[0..65535 - 1] of Char;
  FileListPtr  = ^FileListType;

  LogFileType = (lfReceiveStart,
                 lfReceiveOk,
                 lfReceiveFail,
                 lfReceiveSkip,
                 lfTransmitStart,
                 lfTransmitOk,
                 lfTransmitFail,
                 lfTransmitSkip);

  ShowStatusProc = Procedure (AP: AbstractProtocolPtr; Starting, Ending: Boolean);
  NextFileFunc   = Function  (AP: AbstractProtocolPtr; Var FName: PathStr) : Boolean;
  LogFileProc    = Procedure (AP: AbstractProtocolPtr; LogFileStatus: LogFileType);
  AcceptFileFunc = Function  (AP: AbstractProtocolPtr) : Boolean;

  AbstractProtocol = Object
    ConvertToLower : Boolean;
    UserAbort      : Boolean;
    ProtocolStatus : Word;

    APort            : TIOBase;
    SrcFileLen       : LongInt;           {Size of file (in bytes)}
    UserStatus       : ShowStatusProc;    {Hook for user display}
    BlockCheck       : LongInt;           {Block check value}
    HandshakeWait    : Word;              {Wait seconds during handshaking}
    HandshakeRetry   : Byte;              {Attempts to retry handshaking}
    HandshakeAttempt : Word;              {Current handshake attempt}
    BlockLen         : Word;              {Either 128 or 1024}
    BlockNum         : Word;              {Current block number}
    apFlags          : Word;              {AbstractProtocol options}
    TransTimeout     : Word;              {Tics to wait for trans freespace}
    GotOneFile       : Boolean;           {True if we've received one file}
    InitFilePos      : LongInt;           {Initial file pos during resumes}

    {For getting the next file to transmit}
    PathName         : PathStr;           {Complete path name of current file}
    NextFile         : NextFileFunc;      {NextFile function}
    FileList         : FileListPtr;       {NextFileList list pointer}
    FileListIndex    : Word;              {NextFileList index}

    {When receiving files}
    DestDir          : DirStr;            {Destination directory}

    {Miscellaneous hooks}
    LogFile          : LogFileProc;       {User proc to call when file received}
    AcceptFile       : AcceptFileFunc;    {User proc to accept rcvd files}

    {New fields that don't need to be stored in streams}
    FileListMax      : Word;              {Size of file list}

    {Status...}
    BytesRemaining   : LongInt;           {Bytes not yet transferred}
    BytesTransferred : LongInt;           {Bytes already transferred}
    BlockErrors      : Word;              {Number of tries for block}
    TotalErrors      : Word;              {Number of total tries}
    StartTimer       : LongInt;
    InProgress       : Byte;              {Non-zero if protocol in progress}
    StatusTimer      : LongInt;           {How often to show status}
    ForceStatus      : Boolean;           {Force status update}
    StatusInterval   : Word;              {Tics between status updates}

    {File buffer managment...}
    WorkFile         : File;              {Temp file for Get/PutProtocolBlock}
    FileBuffer       : ^FileBufferArray;  {For reading/writing files}
    StartOfs         : LongInt;           {Holds starting offset of file}
    EndOfs           : LongInt;           {Holds ending offset of file}
    LastOfs          : LongInt;           {FileOfs of last Get/Put}
    FileOfs          : LongInt;           {Current file offset}
    EndOfDataOfs     : LongInt;           {Ofs of buffer of end-of-file}
    EndPending       : Boolean;           {True when end-of-file is in buffer}
    WriteFailOpt     : WriteFailOptions;  {Rules for overwriting files}
    FileOpen         : Boolean;           {True if file open in protocol}
    SaveMode         : Byte;              {Save FileMode}              {!!.02}

    Constructor Init (AP: TIOBase);

    destructor Done; virtual;
    procedure SetShowStatusProc(SProc : ShowStatusProc);
    procedure SetNextFileFunc(NFFunc : NextFileFunc);
    procedure SetFileList(FLP : FileListPtr);
    procedure MakeFileList(var FLP : FileListPtr; Size : Word);
    procedure DisposeFileList(var FLP : FileListPtr; Size : Word);     {!!.01}
    procedure AddFileToList(FLP : FileListPtr; PName : PathStr);
    procedure SetDestinationDirectory(Dir : DirStr);
    procedure SetReceiveFilename(Fname : PathStr);
    procedure SetLogFileProc(LFP : LogFileProc);
    procedure SetAcceptFileFunc(AFP : AcceptFileFunc);
    procedure SetHandshakeWait(NewHandshake, NewRetry : Word);
    procedure SetOverwriteOption(Opt : WriteFailOptions);
    procedure PrepareTransmitPart; virtual;
    function ProtocolTransmitPart : ProtocolStateType ; virtual;
    procedure ProtocolTransmit; virtual;
    procedure PrepareReceivePart; virtual;
    function ProtocolReceivePart : ProtocolStateType ; virtual;
    procedure ProtocolReceive; virtual;

    procedure apResetStatus;
    procedure apShowFirstStatus;
    procedure apShowLastStatus;
    function apNextFile(var FName : PathStr) : Boolean; virtual;
    procedure apPrepareReading; virtual;
    function apReadProtocolBlock(var Block : DataBlockType;
                                 var BlockSize : Word) : Boolean; virtual;
    procedure apFinishReading; virtual;
    procedure apPrepareWriting; virtual;
    function apWriteProtocolBlock(var Block : DataBlockType; BlockSize : Word) : Boolean; virtual;
    procedure apFinishWriting; virtual;
    function apHandleAbort : Boolean;
    procedure apUserStatus(Starting, Ending : Boolean); virtual;
  end;

  function NoAcceptFile(AP : AbstractProtocolPtr) : Boolean;
  procedure NoStatus (AP : AbstractProtocolPtr; Starting, Ending : Boolean);
  function NoNextFile(AP : AbstractProtocolPtr) : Boolean;
  procedure NoLogFile(AP : AbstractProtocolPtr; LogFileStatus : LogFileType);
  procedure NoUserBack(AP : AbstractProtocolPtr);

  function NextFileList(AP : AbstractProtocolPtr; var FName : PathStr) : Boolean;
  function AcceptOneFile(AP : AbstractProtocolPtr) : Boolean;
  function locasemac (ch:char) : char;

implementation

  function LoCaseMac(Ch : Char) : Char;
  begin
    if CH in ['A'..'Z'] then LoCaseMac := Chr(Ord(CH) OR $20)
      else LoCaseMac := CH;
  end;

Constructor AbstractProtocol.Init (AP: TIOBase);
Begin
  ProtocolStatus := ecOk;
  APort       := AP;
  apFlags     := 0;

  UserStatus := @NoStatus;
  HandshakeWait := DefHandshakeWait;
  HandshakeRetry := DefHandshakeRetry;
  BlockLen := 128;
  PathName := '';
  SrcFileLen := 0;
  BytesRemaining := 0;
  BytesTransferred := 0;
  InProgress := 0;
  UserAbort := False;
  WriteFailOpt := WriteFail;
  FileOpen := False;
  NextFile := @NextFileList;
  apFlags := 0;
  LogFile := @NoLogFile;
  AcceptFile := @NoAcceptFile;
  DestDir := '';
  TransTimeout := DefTransTimeout;
  InitFilePos := 0;
  StatusInterval := DefStatusInterval;

  ConvertToLower := False;

  GetMem(FileBuffer, FileBufferSize);
End;

  destructor AbstractProtocol.Done;
    {-Destroys a protocol}
  begin
    FreeMem(FileBuffer, FileBufferSize);
  end;

  procedure AbstractProtocol.SetShowStatusProc(SProc : ShowStatusProc);
    {-Sets a user status function}
  begin
    UserStatus := SProc;
  end;

  procedure AbstractProtocol.SetNextFileFunc(NFFunc : NextFileFunc);
    {-Sets function for batch protocols to call to get file to transmit}
  begin
    NextFile := NFFunc;
  end;

  procedure AbstractProtocol.SetFileList(FLP : FileListPtr);
    {-Sets the file list to use for the built-in NextFileList function}
  begin
    FileList := FLP;
  end;

  procedure AbstractProtocol.MakeFileList(var FLP : FileListPtr; Size : Word);
    {-Allocates a new file list of Size bytes}
  begin
    ProtocolStatus := ecOk;
    GetMem(FLP, Size);
    FillChar(FLP^, Size, 0);
    FileListMax := Size;
  end;

  procedure AbstractProtocol.DisposeFileList(var FLP : FileListPtr;    {!!.01}
                                             Size : Word);             {!!.01}
    {-Disposes of file list FLP}
  begin
    FreeMem(FLP, Size);
  end;

  procedure AbstractProtocol.AddFileToList(FLP : FileListPtr; PName : PathStr);
    {-Adds pathname PName to file list FLP}
  const
    Separator = ';';
    EndOfListMark = #0;
  var
    I : Word;
  begin
    ProtocolStatus := ecOk;

    {Search for the current end of the list}
    i := 0;
    while i < FileListMax - 1 do
     begin
       if FLP^[I] = EndOfListMark then begin
        {Found the end of the list -- try to add the new file}
        if (LongInt(I)+Length(PName)+1) >= FileListMax then begin
          {Not enough room to add file}
          ProtocolStatus := ecOutOfMemory;
          Exit;
        end else begin
          {There's room -- add the file}
          if I <> 0 then begin
            FLP^[I] := Separator;
            Inc(I);
          end;
          Move(PName[1], FLP^[I], Length(PName));
          FLP^[I+Length(PName)] := EndOfListMark;
          Exit;
        end;
      end;

      inc(i);
     end; { while }
    {Never found endoflist marker}
    ProtocolStatus := ecBadFileList;
  end;

  procedure AbstractProtocol.SetDestinationDirectory(Dir : DirStr);
    {-Set the destination directory for received files}
  begin
    DestDir := Dir;
  end;

  procedure AbstractProtocol.SetReceiveFilename(Fname : PathStr);
    {-Give a name to the file to be received}
  begin
    if (DestDir <> '') and (JustPath(Fname) = '') then
      Pathname := DirSlash(DestDir)+Fname
    else
      Pathname := Fname;
  end;

  procedure AbstractProtocol.SetLogFileProc(LFP : LogFileProc);
    {-Sets a procedure to be called when a file is received}
  begin
    LogFile := LFP;
  end;

  procedure AbstractProtocol.SetAcceptFileFunc(AFP : AcceptFileFunc);
    {-Sets a procedure to be called when a file is received}
  begin
    AcceptFile := AFP;
  end;

  procedure AbstractProtocol.SetHandshakeWait(NewHandshake,
                                              NewRetry : Word);
    {-Set the wait tics for the initial handshake}
  begin
    if NewHandshake <> 0 then
      HandshakeWait := NewHandshake;

    if NewRetry <> 0 then
      HandshakeRetry := NewRetry;
  end;

  procedure AbstractProtocol.SetOverwriteOption(Opt : WriteFailOptions);
    {-Set option for what to do when the destination file already exists}
  begin
    WriteFailOpt := Opt;
  end;

  procedure AbstractProtocol.PrepareTransmitPart;
    {-Prepare to transmit in parts}
  begin
    FileListIndex := 0;
    ProtocolStatus := ecOk;
  end;

  function AbstractProtocol.ProtocolTransmitPart : ProtocolStateType;
    {-Abstract - must be overridden}
  begin
    ProtocolTransmitPart := psFinished;
  end;

  procedure AbstractProtocol.ProtocolTransmit;
    {-Used the derived part methods to transmit all files}
  var
    State : ProtocolStateType;
  begin

    PrepareTransmitPart;
    if ProtocolStatus <> ecOk then
      Exit;
    repeat
      State := ProtocolTransmitPart;

      aport.bufflush;
    until State = psFinished;
  end;

  procedure AbstractProtocol.PrepareReceivePart;
    {-Parent-level inits for derived protocols}
  begin
    GotOneFile     := False;
    ProtocolStatus := ecOk;
  end;

  function AbstractProtocol.ProtocolReceivePart : ProtocolStateType;
    {-Receive a batch of files}
  begin
    ProtocolReceivePart := psFinished;
  end;

  procedure AbstractProtocol.ProtocolReceive;
    {-Use the derived part methods to receive all files}
  var
    State : ProtocolStateType;
  begin
    PrepareReceivePart;

    if ProtocolStatus <> ecOk then exit;

    repeat
      State := ProtocolReceivePart;

      aport.bufflush;
    until (State = psFinished) or not aport.connected;
  end;

  procedure AbstractProtocol.apResetStatus;
    {-Conditionally reset all status vars}
  begin
    if InProgress = 0 then begin
      {New protocol, reset status vars}
      SrcFileLen := 0;
      BytesRemaining := 0;
    end;
    BytesTransferred := 0;
    BlockErrors := 0;
    BlockNum := 0;
    TotalErrors := 0;
  end;

  procedure AbstractProtocol.apShowFirstStatus;
    {-Show (possible) first status}
  begin
    apUserStatus((InProgress = 0), False);
    Inc(InProgress);
  end;

  procedure AbstractProtocol.apShowLastStatus;
    {-Reset field and show last status}
  begin
    if InProgress <> 0 then begin
      Dec(InProgress);
      apUserStatus(False, (InProgress = 0));
    end;
  end;

  procedure AbstractProtocol.apPrepareReading;
    {-Prepare to send protocol blocks (usually opens a file)}
  var
    Result : Word;
  begin
    ProtocolStatus := ecOk;

    {If file is already open then leave without doing anything}
    if FileOpen then
      Exit;

    {Report notfound error for empty filename}
    if PathName = '' then begin
      ProtocolStatus := ecFileNotFound;
      Exit;
    end;

    {Open up the previously specified file}
    SaveMode := FileMode;                                              {!!.02}
    FileMode := 66;
    Assign(WorkFile, PathName);
    {$i-}
    Reset(WorkFile, 1);
    FileMode := SaveMode;                                              {!!.02}
    Result := IOResult;
    if Result <> 0 then begin
      ProtocolStatus := Result;
      Exit;
    end;

    {Show file name and size}
    SrcFileLen := FileSize(WorkFile);
    BytesRemaining := SrcFileLen;
    apUserStatus(False, False);

    {Note file date/time stamp (for those protocols that care)}
//    GetFTime(WorkFile, SrcFileDate);

    {Initialize the buffering variables}
    StartOfs := 0;
    EndOfs := 0;
    LastOfs := 0;
    EndPending := False;
    FileOpen := True;
  end;

  procedure AbstractProtocol.apFinishReading;
    {-Clean up after reading protocol blocks (usually closes a file)}
  begin
    if FileOpen then begin
      {Error or end-of-protocol, clean up}
      Close(WorkFile);
      if IOResult <> 0 then ;
      {FreeMemCheck(FileBuffer, FileBufferSize);}                      {!!.01}
      FileOpen := False;
    end;
  end;

  function AbstractProtocol.apReadProtocolBlock(var Block : DataBlockType;
                                                var BlockSize : Word) : Boolean;
    {-Return with a block to transmit (True to quit)}
  var
    BytesRead : LongInt;
    BytesToMove : Word;
    BytesToRead : LongInt;
    ResultTmp : Word;
  begin
    ProtocolStatus := ecOk;

    {Check for a request to start further along in the file (recovering)}
    {if (LastOfs = 0) and (FileOfs > 0) then}
    if FileOfs > EndOfs then
      {First call to read is asking to skip blocks -- force a reread}
      EndOfs := FileOfs;

    {Check for a request to retransmit an old block}
    if FileOfs < LastOfs then
      {Retransmit - reset end-of-buffer to force a reread}
      EndOfs := FileOfs;

    if (FileOfs + BlockSize) > EndOfs then begin
      {Buffer needs to be updated, First shift end section to beginning}
      BytesToMove := EndOfs - FileOfs;
      if BytesToMove > 0 then
        Move(FileBuffer^[FileOfs - StartOfs], FileBuffer^, BytesToMove);

      {Fill end section from file}
      BytesToRead := FileBufferSize - BytesToMove;
      Seek(WorkFile, EndOfs);
      BlockRead(WorkFile, FileBuffer^[BytesToMove], BytesToRead, BytesRead);
      ResultTmp := IOResult;
      if (ResultTmp <> 0) then begin
        {Exit on error}
        ProtocolStatus := ResultTmp;
        apReadProtocolBlock := True;
        BlockSize := 0;
        Exit;
      end else begin
        {Set buffering variables}
        StartOfs := FileOfs;
        EndOfs := FileOfs + FileBufferSize;
      end;

      {Prepare for the end of the file}
      if BytesRead < BytesToRead then begin
        EndOfDataOfs := BytesToMove + BytesRead;
        FillChar(FileBuffer^[EndofDataOfs], FileBufferSize - EndOfDataOfs,
                 BlockFillChar);
        Inc(EndOfDataOfs, StartOfs);
        EndPending := True;
      end else
        EndPending := False;
    end;

    {Return the requested block}
    Move(FileBuffer^[(FileOfs - StartOfs)], Block, BlockSize);
    apReadProtocolBlock := False;
    LastOfs := FileOfs;

    {If it's the last block then say so}
    if EndPending and ((FileOfs + BlockSize) >= EndOfDataOfs) then begin
      apReadProtocolBlock := True;
      BlockSize := EndOfDataOfs - FileOfs;
    end;
  end;

  function AbstractProtocol.apNextFile(var FName : PathStr) : Boolean;
    {-Virtual method for calling NextFile procedure}
  begin
    apNextFile := NextFile(@Self, FName);
  end;

  procedure AbstractProtocol.apPrepareWriting;
    {-Prepare to save protocol blocks (usually opens a file)}
  var
    Dir : DirStr;
    Name : NameStr;
    Ext : ExtStr;
    ResultTmp : Word;
  label
    ExitPoint;
  begin
    {Does the file exist already?}
    SaveMode := FileMode;                                              {!!.02}
    FileMode := 66;                                   {!!.02}{!!.03}
    Assign(WorkFile, PathName);
    {$i-}
    Reset(WorkFile, 1);
    FileMode := SaveMode;                                              {!!.02}
    ResultTmp := IOResult;

    {Exit on errors other than FileNotFound}
    if (ResultTmp <> 0) and (ResultTmp <> 2) and (ResultTmp <> 110) then begin
      ProtocolStatus := ResultTmp;
      goto ExitPoint;
    end;

    {Exit if file exists and option is WriteFail}
    if (ResultTmp = 0) and (WriteFailOpt = WriteFail) then begin
      ProtocolStatus := ecFileAlreadyExists;
      goto ExitPoint;
    end;

    Close(WorkFile);
    if IOResult = 0 then ;

    {Change the file name if it already exists the option is WriteRename}
    if (ResultTmp = 0) and (WriteFailOpt = WriteRename) then begin
      FSplit(Pathname, Dir, Name, Ext);
      Name[1] := '$';
      Pathname := Dir + Name + Ext;
      ProtocolStatus := ecFileRenamed;
    end;

    {Give status a chance to show that the file was renamed}
    apUserStatus(False, False);
    ProtocolStatus := ecOk;

    {Ok to rewrite file now}
    Assign(WorkFile, Pathname);
    Rewrite(WorkFile, 1);
    ResultTmp := IOResult;
    if ResultTMp <> 0 then begin
      ProtocolStatus := ResultTmp;
      goto ExitPoint;
    end;

    {Initialized the buffer management vars}
    StartOfs := 0;
    LastOfs := 0;
    EndOfs := StartOfs + FileBufferSize;
    FileOpen := True;
    Exit;

ExitPoint:
    Close(WorkFile);
    if IOResult <> 0 then ;
  end;

  procedure AbstractProtocol.apFinishWriting;
    {-Cleans up after saving all protocol blocks}
  var
    BytesToWrite : Word;
    BytesWritten : LongInt;
    ResultTmp : Word;
  begin
    if FileOpen then begin
      {Error or end-of-protocol, commit buffer and cleanup}
      BytesToWrite := FileOfs - StartOfs;
      BlockWrite(WorkFile, FileBuffer^, BytesToWrite, BytesWritten);
      ResultTmp := IOResult;

      if (ResultTmp <> 0) then
        ProtocolStatus := ResultTmp;

      if (BytesToWrite <> BytesWritten) then
        ProtocolStatus := ecDiskFull;

      {Get file size and time for those protocols that don't know}
      SrcFileLen := FileSize(WorkFile);
//      GetFTime(WorkFile, SrcFileDate);

      Close(WorkFile);
      if IOResult <> 0 then ;

      FileOpen := False;
    end;
  end;

  function AbstractProtocol.apWriteProtocolBlock(var Block : DataBlockType;
                                               BlockSize : Word) : Boolean;
    {-Write a protocol block (return True to quit)}
  var
    ResultTmp : Word;
    BytesToWrite : Word;
    BytesWritten : LongInt;

    procedure BlockWriteRTS;
    begin
      with APort do begin
        BlockWrite(WorkFile, FileBuffer^, BytesToWrite, BytesWritten);
        ProtocolStatus := ecOK;
      end;
    end;

  begin
    ProtocolStatus := ecOk;
    apWriteProtocolBlock := True;

    if not FileOpen then begin
      ProtocolStatus := ecNotOpen;
      Exit;
    end;

    if FileOfs < LastOfs then
      {This is a retransmitted block}
      if FileOfs > StartOfs then begin
        {FileBuffer has some good data, commit that data now}
        Seek(WorkFile, StartOfs);
        BytesToWrite := FileOfs - StartOfs;
        BlockWriteRTS;
        ResultTmp := IOResult;
        if (ResultTmp <> 0) then begin
          ProtocolStatus := ResultTmp;
          Exit;
        end;
        if (BytesToWrite <> BytesWritten) then begin
          ProtocolStatus := ecDiskFull;
          Exit;
        end;
      end else begin
        {Block is before data in buffer, discard data in buffer}
        StartOfs := FileOfs;
        EndOfs := StartOfs + FileBufferSize;
        {Position file just past last good data}
        Seek(WorkFile, FileOfs);
        ResultTmp := IOResult;
        if ResultTmp <> 0 then begin
          ProtocolStatus := ResultTmp;
          Exit;
        end;
      end;

    {Will this block fit in the buffer?}
    if (FileOfs + BlockSize) > EndOfs then begin
      {Block won't fit, commit current buffer to disk}
      BytesToWrite := FileOfs - StartOfs;
      BlockWriteRTS;
      ResultTmp := IOResult;
      if (ResultTmp <> 0) then begin
        ProtocolStatus := ResultTmp;
        Exit;
      end;
      if (BytesToWrite <> BytesWritten) then begin
        ProtocolStatus := ecDiskFull;
        Exit;
      end;

      {Reset the buffer management vars}
      StartOfs := FileOfs;
      EndOfs := StartOfs + FileBufferSize;
      LastOfs := FileOfs;
    end;

    {Add this block to the buffer}
    Move(Block, FileBuffer^[FileOfs - StartOfs], BlockSize);
    Inc(LastOfs, BlockSize);
    apWriteProtocolBlock := False;
  end;

  function AbstractProtocol.apHandleAbort : Boolean;
  begin
    result := false;
  end;

  procedure AbstractProtocol.apUserStatus(Starting, Ending : Boolean);
    {-Calls user status routine while preserving current ProtocolStatus}
  var
    SaveStatus : Word;
  begin
    SaveStatus := ProtocolStatus;
    if ProtocolStatus = ecNoHeader then
      ProtocolStatus := ecOk;
    UserStatus(@Self, Starting, Ending);
    ProtocolStatus := SaveStatus;
  end;

  procedure NoStatus(AP : AbstractProtocolPtr;
                     Starting, Ending : Boolean);
    {-Empty show status procedure}
  begin
  end;

  function NoNextFile(AP : AbstractProtocolPtr) : Boolean;
    {-Empty next file function -- always returns False}
  begin
    NoNextFile := False;
  end;

  procedure NoLogFile(AP : AbstractProtocolPtr; LogFileStatus : LogFileType);
    {-Empty LogFile procedure}
  begin
  end;

  function NoAcceptFile(AP : AbstractProtocolPtr) : Boolean;
    {-Empty AcceptFile function}
  begin
    NoAcceptFile := True;
  end;

  procedure NoUserBack(AP : AbstractProtocolPtr);
    {-Empty UserBack procedure}
  begin
  end;

  function AcceptOneFile(AP : AbstractProtocolPtr) : Boolean;
    {-Built-in function that accepts one file only}
  begin
    with AP^ do begin
      AcceptOneFile := not GotOneFile;
      GotOneFile := True;
    end;
  end;

  function NextFileList(AP : AbstractProtocolPtr;
                        var FName : PathStr) : Boolean;
    {-Built-in function that works with a list of files}
  const
    Separator = ';';
    EndOfListMark = #0;
    MaxLen = SizeOf(PathStr);
  var
    MaxNext : Word;
    I : Word;
    Len : Word;
  begin
    AP^.ProtocolStatus := 0;

    with AP^ do begin
      {Return immediately if no more files}
      if FileList^[FileListIndex] = EndOfListMark then begin
        NextFileList := False;
        FName := '';
        Exit;
      end;

      {Increment past the last separator}
      if FileListIndex <> 0 then
        Inc(FileListIndex);

      {Define how far to look for the next marker}
      if LongInt(FileListIndex) + MaxLen > 65535 then
        MaxNext := 65535
      else
        MaxNext := FileListIndex + MaxLen;

      {Look for the next marker}
      for I := FileListIndex to MaxNext do begin
        if (FileList^[I] = Separator) or
           (FileList^[I] = EndOfListMark) then begin
          {Extract the pathname}
          Len := I - FileListIndex;
          Move(FileList^[FileListIndex], FName[1], Len);
          FName[0] := Char(Len);
          NextFileList := True;
          Inc(FileListIndex, Len);
          Exit;
        end;
      end;

      {Bad format list (no separator) -- show error}
      ProtocolStatus := ecBadFileList;
      NextFileList := False;
      FName := '';
    end;
  end;

begin
end.

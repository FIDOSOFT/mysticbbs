Unit m_Socket_Class;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF OS2}
    WinSock,
  {$ENDIF}
  {$IFDEF WIN32}
    Windows,
    Winsock2,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
    cNetDB,
  {$ENDIF}
  Sockets,
  Classes,
  m_DateTime,
  m_Strings;

Const
  TSocketBufferSize = 8 * 1024 - 1;

Type
  TSocketBuffer = Array[0..TSocketBufferSize] of Char;

  TSocketClass = Class
    SocketStatus   : TStringList;
    StatusUpdated  : Boolean;
    FSocketHandle  : LongInt;
    FPort          : LongInt;
    FPeerName      : String;
    FPeerIP        : String;
    FHostIP        : String;
    FInBuf         : TSocketBuffer;
    FInBufPos      : LongInt;
    FInBufEnd      : LongInt;
    FOutBuf        : TSocketBuffer;
    FOutBufPos     : LongInt;
    FTelnetState   : Byte;
    FTelnetReply   : Array[1..14] of Char;
    FTelnetCmd     : Char;
    FTelnetSubCmd  : Char;
    FTelnetLen     : Byte;
    FTelnetEcho    : Boolean;
    FTelnetSubData : String;
    FTelnetClient  : Boolean;
    FTelnetServer  : Boolean;
    FDisconnect    : Boolean;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   Disconnect;
    Function    DataWaiting     : Boolean;
    Function    WriteBuf        (Var Buf; Len: LongInt) : LongInt;
    Procedure   BufFlush;
    Procedure   BufWriteChar    (Ch: Char);
    Procedure   BufWriteStr     (Str: String);
    Function    WriteLine       (Str: String) : LongInt;
    Function    WriteStr        (Str: String) : LongInt;
    Function    WriteFile       (Str: String) : Boolean;
    Function    WriteBufEscaped (Var Buf: TSocketBuffer; Var Len: LongInt) : LongInt;
    Procedure   TelnetInBuffer  (Var Buf: TSocketBuffer; Var Len: LongInt);
    Function    ReadBuf         (Var Buf; Len: LongInt) : LongInt;
    Function    ReadLine        (Var Str: String) : LongInt;
    Function    SetBlocking     (Block: Boolean): LongInt;
    Function    WaitForData     (TimeOut: LongInt) : LongInt;
    Function    Connect         (Address: String; Port: Word) : Boolean;
    Function    ResolveAddress  (Host: String) : LongInt;
    Procedure   WaitInit        (Port: Word);
    Function    WaitConnection  : TSocketClass;
    Procedure   PurgeInputData;
    Procedure   PurgeOutputData;
    Function    PeekChar        (Num: Byte) : Char;
    Function    ReadChar        : Char;
    Function    WriteChar       (Ch: Char) : LongInt;
    Procedure   Status          (Str: String);

    Property SocketHandle : LongInt READ FSocketHandle WRITE FSocketHandle;
    Property PeerPort     : LongInt READ FPort         WRITE FPort;
    Property PeerName     : String  READ FPeerName     WRITE FPeerName;
    Property PeerIP       : String  READ FPeerIP       WRITE FPeerIP;
    Property HostIP       : String  READ FHostIP       WRITE FHostIP;
  End;

Implementation

{ TELNET NEGOTIATION CONSTANTS }

Const
  MaxStatusText = 20;

  Telnet_IAC    = #255;
  Telnet_DONT   = #254;
  Telnet_DO     = #253;
  Telnet_WONT   = #252;
  Telnet_WILL   = #251;
  Telnet_SB     = #250;
  Telnet_BINARY = #000;
  Telnet_ECHO   = #001;
  Telnet_SE     = #240;
  Telnet_TERM   = #24;
  Telnet_SGA    = #003;

  FPSENDOPT     = 0;
  FPRECVOPT     = 0;

Constructor TSocketClass.Create;
Begin
  Inherited Create;

  FSocketHandle := -1;
  FPort         := 0;
  FPeerName     := 'Unknown';
  FPeerIP       := FPeerName;
  FInBufPos     := 0;
  FInBufEnd     := 0;
  FOutBufPos    := 0;
  FTelnetState  := 0;
  FTelnetEcho   := False;
  FTelnetClient := False;
  FTelnetServer := False;
  FDisconnect   := True;
  FHostIP       := '';
  StatusUpdated := False;

  SocketStatus := TStringList.Create;
End;

Destructor TSocketClass.Destroy;
Begin
  If FDisconnect Then Disconnect;

  SocketStatus.Free;

  Inherited Destroy;
End;

Procedure TSocketClass.PurgeOutputData;
Begin
  FOutBufPos := 0;
End;

Procedure TSocketClass.PurgeInputData;
//Var
//  Buf : Array[1..1024] of Char;
Begin
//  If FSocketHandle = -1 Then Exit;

  FInBufPos := 0;
  FInBufEnd := 0;

//  If DataWaiting Then
//    Repeat
//    Until ReadBuf(Buf, SizeOf(Buf)) <> 1024;
End;

Procedure TSocketClass.Disconnect;
Begin
  If FSocketHandle <> -1 Then Begin
    fpShutdown(FSocketHandle, 2);
    CloseSocket(FSocketHandle);

    FSocketHandle := -1;
  End;
End;

Function TSocketClass.DataWaiting : Boolean;
Begin
  Result := (FInBufPos < FInBufEnd) or (WaitForData(0) > 0);
End;

Function TSocketClass.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Buf, Len, FPSENDOPT);

  While (Result = -1) and (SocketError = ESOCKEWOULDBLOCK) Do Begin
    WaitMS(10);

    Result := fpSend(FSocketHandle, @Buf, Len, FPSENDOPT);
  End;
End;

Procedure TSocketClass.BufFlush;
Begin
  If FOutBufPos > 0 Then Begin
    If FTelnetClient or FTelnetServer Then
      WriteBufEscaped(FOutBuf, FOutBufPos)
    Else
      WriteBuf(FOutBuf, FOutBufPos);

    FOutBufPos := 0;
  End;
End;

Procedure TSocketClass.BufWriteChar (Ch: Char);
Begin
  FOutBuf[FOutBufPos] := Ch;

  Inc(FOutBufPos);

  If FOutBufPos > TSocketBufferSize Then
    BufFlush;
End;

Procedure TSocketClass.BufWriteStr (Str: String);
Var
  Count : LongInt;
Begin
  For Count := 1 to Length(Str) Do
    BufWriteChar(Str[Count]);
End;

Function TSocketClass.WriteLine (Str: String) : LongInt;
Begin
  Str    := Str + #13#10;
  Result := fpSend(FSocketHandle, @Str[1], Length(Str), FPSENDOPT);
End;

Function TSocketClass.WriteChar (Ch: Char) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Ch, 1, FPSENDOPT);
End;

Function TSocketClass.WriteStr (Str: String) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Str[1], Length(Str), FPSENDOPT);
End;

Function TSocketClass.WriteFile (Str: String) : Boolean;
Var
  Buf  : Array[1..4096] of Char;
  Size : LongInt;
  F    : File;
Begin
  Result := False;

  FileMode := 66;

  Assign (F, Str);
  Reset  (F, 1);

  If IoResult <> 0 Then Exit;

  Repeat
    BlockRead (F, Buf, SizeOf(Buf), Size);

    If Size = 0 Then Break;

    If Buf[Size] = #26 Then Dec(Size);

    WriteBuf (Buf, Size);
  Until Size <> SizeOf(Buf);

  Result := True;
End;

Function TSocketClass.WriteBufEscaped (Var Buf: TSocketBuffer; Var Len: LongInt) : LongInt;
Var
  Temp    : Array[0..TSocketBufferSize * 2] of Char;
  TempPos : LongInt;
  Count   : LongInt;
Begin
  TempPos := 0;

  For Count := 0 to Len Do
    If Buf[Count] = TELNET_IAC Then Begin
      Temp[TempPos] := TELNET_IAC;
      Inc (TempPos);
      Temp[TempPos] := TELNET_IAC;
      Inc (TempPos);
    End Else Begin
      Temp[TempPos] := Buf[Count];
      Inc (TempPos);
    End;

  Dec(TempPos);

  Result := fpSend(FSocketHandle, @Temp, TempPos, FPSENDOPT);

  While (Result = -1) and (SocketError = ESOCKEWOULDBLOCK) Do Begin
    WaitMS(10);

    Result := fpSend(FSocketHandle, @Temp, TempPos, FPSENDOPT);
  End;
End;

Procedure TSocketClass.TelnetInBuffer (Var Buf: TSocketBuffer; Var Len: LongInt);

  Procedure SendCommand (YesNo, CmdType: Char);
  Var
    Reply : String[3];
  Begin
    Reply[1] := Telnet_IAC;
    Reply[2] := Char(YesNo); {DO/DONT, WILL/WONT}
    Reply[3] := CmdType;

    fpSend (FSocketHandle, @Reply[1], 3, FPSENDOPT);
  End;

  Procedure SendData (CmdType: Char; Data: String);
  Var
    Reply   : String;
    DataLen : Byte;
  Begin
    DataLen  := Length(Data);
    Reply[1] := Telnet_IAC;
    Reply[2] := Telnet_SB;
    Reply[3] := CmdType;
    Reply[4] := #0;

    Move (Data[1], Reply[5], DataLen);

    Reply[5 + DataLen] := #0;
    Reply[6 + DataLen] := Telnet_IAC;
    Reply[7 + DataLen] := Telnet_SE;

    fpSend (FSocketHandle, @Reply[1], 7 + DataLen, FPSENDOPT);
  End;

Var
  Count     : LongInt;
  TempPos   : LongInt;
  Temp      : TSocketBuffer;
  ReplyGood : Char;
  ReplyBad  : Char;
Begin
  TempPos := 0;

  For Count := 0 to Len - 1 Do Begin
    Case FTelnetState of
      1 : If Buf[Count] = Telnet_IAC Then Begin
            FTelnetState := 0;
            Temp[TempPos] := Telnet_IAC;
            Inc (TempPos);
          End Else Begin
            Inc (FTelnetState);
            FTelnetCmd := Buf[Count];
          End;
      2 : Begin
            FTelnetState := 0;

            Case FTelnetCmd of
              Telnet_WONT : Begin
//                              FTelnetSubCmd := Telnet_DONT;
//                              SockSend(FSocketHandle, FTelnetSubCmd, 1, 0);
                            End;
              Telnet_DONT : Begin
//                              FTelnetSubCmd := Telnet_WONT;
//                              SockSend(FSocketHandle, FTelnetSubCmd, 1, 0);
                            End;
              Telnet_SB   : Begin
                              FTelnetState  := 3;
                              FTelnetSubCmd := Buf[Count];
                            End;
              Telnet_WILL,
              Telnet_DO   : Begin
                              If FTelnetCmd = Telnet_DO Then Begin
                                ReplyGood := Telnet_WILL;
                                ReplyBad  := Telnet_WONT;
                              End Else Begin
                                ReplyGood := Telnet_DO;
                                ReplyBad  := Telnet_DONT;
                              End;

                              If FTelnetClient Then Begin
                                Case Buf[Count] of
                                  Telnet_BINARY,
                                  Telnet_ECHO,
                                  Telnet_SGA,
                                  Telnet_TERM : SendCommand(ReplyGood, Buf[Count])
                                Else
                                  SendCommand(ReplyBad, Buf[Count]);
                                End;

                                If Buf[Count] = Telnet_Echo Then
                                  FTelnetEcho := (FTelnetCmd = Telnet_DO);
                              End Else Begin
                                Case Buf[Count] of
                                  Telnet_ECHO : FTelnetEcho := True;
                                  Telnet_SGA  : ;
                                Else
                                  SendCommand(ReplyBad, Buf[Count]);
                                End;
                              End;
                            End;
            End;
          End;
      3 : If Buf[Count] = Telnet_SE Then Begin
            If FTelnetClient Then
              Case FTelnetSubCmd of
                Telnet_TERM : SendData(Telnet_TERM, 'vt100');
              End;

            FTelnetState   := 0;
            FTelnetSubData := '';
          End Else
            FTelnetSubData := FTelnetSubData + Buf[Count];
    Else
      If Buf[Count] = Telnet_IAC Then Begin
        Inc (FTelnetState);
      End Else Begin
        Temp[TempPos] := Buf[Count];
        Inc (TempPos);
      End;
    End;
  End;

  Buf := Temp;
  Len := TempPos;
End;

Function TSocketClass.ReadChar : Char;
Begin
  ReadBuf(Result, 1);
End;

Function TSocketClass.PeekChar (Num: Byte) : Char;
Begin
  If (FInBufPos = FInBufEnd) and DataWaiting Then
    ReadBuf(Result, 0);

  If FInBufPos + Num < FInBufEnd Then
    Result := FInBuf[FInBufPos + Num];
End;

Function TSocketClass.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  If FInBufPos = FInBufEnd Then Begin
    FInBufEnd := fpRecv(FSocketHandle, @FInBuf, TSocketBufferSize, FPRECVOPT);
    FInBufPos := 0;

    If FInBufEnd <= 0 Then Begin
      FInBufEnd := 0;
      Result    := -1;
      Exit;
    End;

    If FTelnetClient or FTelnetServer Then TelnetInBuffer(FInBuf, FInBufEnd);
  End;

  If Len > FInBufEnd - FInBufPos Then Len := FInBufEnd - FInBufPos;

  Move (FInBuf[FInBufPos], Buf, Len);
  Inc  (FInBufPos, Len);

  Result := Len;
End;

Function TSocketClass.ReadLine (Var Str: String) : LongInt;
Var
  Ch  : Char;
  Res : LongInt;
Begin
  Str := '';
  Res := 0;

  Repeat
    If FInBufPos = FInBufEnd Then Res := ReadBuf(Ch, 0);

    Ch := FInBuf[FInBufPos];

    Inc (FInBufPos);

    If (Ch <> #10) And (Ch <> #13) And (FInBufEnd > 0) Then Str := Str + Ch;
  Until (Ch = #10) Or (Res < 0) Or (FInBufEnd = 0);

  If Res < 0 Then Result := -1 Else Result := Length(Str);
End;

Function TSocketClass.SetBlocking (Block: Boolean): LongInt;
//Var
//  Data : DWord;
Begin
  If FSocketHandle = -1 Then Begin
    Result := FSocketHandle;
    Exit;
  End;

//  Data   := Ord(Not Block);
//  Result := ioctlSocket(FSocketHandle, FIONBIO, Data);
End;

Function TSocketClass.WaitForData (TimeOut: LongInt) : LongInt;
Var
  T      : TTimeVal;
  rFDSET,
  wFDSET,
  eFDSET : TFDSet;
Begin
  T.tv_sec  := 0;
  T.tv_usec := TimeOut * 1000;

  {$IFDEF UNIX}
    fpFD_Zero(rFDSET);
    fpFD_Zero(wFDSET);
    fpFD_Zero(eFDSET);
    fpFD_Set(FSocketHandle, rFDSET);
    Result := fpSelect(FSocketHandle + 1, @rFDSET, @wFDSET, @eFDSET, @T);
  {$ELSE}
    FD_Zero(rFDSET);
    FD_Zero(wFDSET);
    FD_Zero(eFDSET);
    FD_Set(FSocketHandle, rFDSET);
    Result := Select(FSocketHandle + 1, @rFDSET, @wFDSET, @eFDSET, @T);
  {$ENDIF}
End;

Function TSocketClass.ResolveAddress (Host: String) : LongInt;
Var
  HostEnt : PHostEnt;
Begin
  Host    := Host + #0;
  HostEnt := GetHostByName(@Host[1]);

  If Assigned(HostEnt) Then
    Result := PInAddr(HostEnt^.h_addr_list^)^.S_addr
  Else
    Result := LongInt(StrToNetAddr(Host));
End;

Function TSocketClass.Connect (Address: String; Port: Word) : Boolean;
Var
  Sin : TINetSockAddr;
Begin
  Result        := False;
  FSocketHandle := fpSocket(PF_INET, SOCK_STREAM, 0);

  If FSocketHandle = -1 Then Exit;

  FPeerName := Address;

  FillChar(Sin, SizeOf(Sin), 0);

  Sin.sin_Family      := PF_INET;
  Sin.sin_Port        := htons(Port);
  Sin.sin_Addr.S_Addr := ResolveAddress(Address);

  FPeerIP := NetAddrToStr(Sin.Sin_Addr);
  Result  := fpConnect(FSocketHandle, @Sin, SizeOf(Sin)) = 0;
End;

Procedure TSocketClass.WaitInit (Port: Word);
Var
  SIN : TINetSockAddr;
  Opt : LongInt;
Begin
  FSocketHandle := fpSocket(PF_INET, SOCK_STREAM, 0);

  Opt := 1;

  fpSetSockOpt (FSocketHandle, SOL_SOCKET, SO_REUSEADDR, @Opt, SizeOf(Opt));

  SIN.sin_family      := PF_INET;
  SIN.sin_addr.s_addr := 0;
  SIN.sin_port        := htons(Port);

  fpBind(FSocketHandle, @SIN, SizeOf(SIN));

  SetBlocking(True);
End;

Function TSocketClass.WaitConnection : TSocketClass;
Var
  Sock   : LongInt;
  Client : TSocketClass;
  PHE    : PHostEnt;
  SIN    : TINetSockAddr;
  Temp   : LongInt;
  SL     : TSockLen;
Begin
  Result := NIL;

  If fpListen(FSocketHandle, 5) = -1 Then Exit;

  Temp := SizeOf(SIN);
  Sock := fpAccept(FSocketHandle, @SIN, @Temp);

  If Sock = -1 Then Exit;

  FPeerIP := NetAddrToStr(SIN.sin_addr);
  PHE     := GetHostByAddr(@SIN.sin_addr, 4, PF_INET);

  If Not Assigned(PHE) Then
    FPeerName := 'Unknown'
  Else
    FPeerName := StrPas(PHE^.h_name);

  SL := SizeOf(SIN);

  fpGetSockName(FSocketHandle, @SIN, @SL);

  FHostIP := NetAddrToStr(SIN.sin_addr);
  Client  := TSocketClass.Create;

  Client.SocketHandle  := Sock;
  Client.PeerName      := FPeerName;
  Client.PeerIP        := FPeerIP;
  Client.PeerPort      := FPort;
  Client.HostIP        := FHostIP;
  Client.FTelnetServer := FTelnetServer;
  Client.FTelnetClient := FTelnetClient;

  If FTelnetServer Then
    Client.WriteStr(#255#251#001#255#251#003);  // IAC WILL ECHO

  Result := Client;
End;

Procedure TSocketClass.Status (Str: String);
Var
  Res : String;
Begin
  If SocketStatus = NIL Then Exit;

  Try
    If SocketStatus.Count > MaxStatusText Then
      SocketStatus.Delete(0);

    Res := '(' + Copy(DateDos2Str(CurDateDos, 1), 1, 5) + ' ' + TimeDos2Str(CurDateDos, False) + ') ' + Str;

    If Length(Res) > 74 Then Begin
      SocketStatus.Add(Copy(Res, 1, 74));

      If SocketStatus.Count > MaxStatusText Then
        SocketStatus.Delete(0);

      SocketStatus.Add(strRep(' ', 14) + Copy(Res, 75, 255));
    End Else
      SocketStatus.Add(Res);
  Except
    { ignore exceptions here -- happens when socketstatus is NIL}
    { need to review criticals now that they are in FP's RTL}
  End;

  StatusUpdated := True;
End;

End.

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
Unit m_Socket_Class;

{$link m_resolve_address.o}
{$linklib c}

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
  m_DateTime,
  m_Strings,
  libmysticbbs;

Const
  TSocketBufferSize = 8 * 1024 - 1;

Type
  TSocketBuffer = Array[0..TSocketBufferSize] of Char;

  TSocketClass = Class
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
    Function 	ResolveAddress 	(Host: String; Remote_Address: PChar):Integer;
    Procedure   WaitInit        (Port: Word);
    Function    WaitConnection  : TSocketClass;
    Procedure   PurgeInputData;
    Procedure   PurgeOutputData;
    Function    PeekChar        (Num: Byte) : Char;
    Function    ReadChar        : Char;
    Function    WriteChar       (Ch: Char) : LongInt;

    Property SocketHandle : LongInt READ FSocketHandle WRITE FSocketHandle;
    Property PeerPort     : LongInt READ FPort         WRITE FPort;
    Property PeerName     : String  READ FPeerName     WRITE FPeerName;
    Property PeerIP       : String  READ FPeerIP       WRITE FPeerIP;
    Property HostIP       : String  READ FHostIP       WRITE FHostIP;
  End;

Implementation

{ TELNET NEGOTIATION CONSTANTS }

Const
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
End;

Destructor TSocketClass.Destroy;
Begin
  If FDisconnect Then Disconnect;

  Inherited Destroy;
End;

Procedure TSocketClass.PurgeOutputData;
Begin
  FOutBufPos := 0;
End;

Procedure TSocketClass.PurgeInputData;
Begin
  FInBufPos := 0;
  FInBufEnd := 0;
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

Function ResolveAddress_IPv6(Host:PChar; Remote_Address:PChar):Integer; cdecl; external;

Function TIOSocket.ResolveAddress (Host: String; Remote_Address: pchar):Integer;
Begin
        Host := Host + Char(0);
	Result := ResolveAddress_IPv6(@Host, Remote_Address);
End;

Function TIOSocket.Connect (Address: String; Port: Word) : Boolean;
Var
	Sin6     	:  TINetSockAddr6;
	Sin4     	:  TINetSockAddr;
	Remote_Addr 	:  String;
	Family   	:  Integer;
Begin
	Result := False;
	Family := 0;
	Remote_Addr := '';
	
	Family := ResolveAddress (Address, @Remote_Addr);

	if Family = 0 Then Begin
		if Pos(Address, ':') > 0 then Begin
			Family := AF_INET6;
			Remote_Addr := Address;
		End else Begin
			Family := AF_INET;
			Remote_Addr := Address;
		End;
	End;

 	FSocketHandle := fpSocket(Family, SOCK_STREAM, 0);
 	If FSocketHandle = -1 Then Begin
		Exit;
	End;

  	FPeerName := Address;
        
	if Family = AF_INET6 then Begin
		FillChar(Sin6, SizeOf(Sin6), 0);
		Sin6.sin6_Family   := AF_INET6;
		Sin6.sin6_Port     := htons(Port);
		Sin6.sin6_Addr     := StrToNetAddr6(Remote_Addr);
		FPeerIP 	   := NetAddrToStr6(Sin6.Sin6_addr);
		Result   	   := fpConnect(FSocketHandle, @Sin6, SizeOf(Sin6)) = 0;
	End else Begin
		FillChar(Sin4, SizeOf(Sin4), 0);
		Sin4.sin_Family    := AF_INET;
		Sin4.sin_Port      := htons(Port);
		Sin4.sin_Addr      := StrToNetAddr(Remote_Addr);
		FPeerIP   	   := NetAddrToStr(Sin4.Sin_addr);
		Result  	   := fpConnect(FSocketHandle, @Sin4, SizeOf(Sin4)) = 0;
	End;
End;

Procedure TIOSocket.WaitInit (NetInterface: String; Port: Word);
Var
  SIN : TINetSockAddr6;
  Opt : LongInt;
Begin
  If NetInterface = '0.0.0.0' Then
  	NetInterface := '::'
  else if NetInterface = '127.0.0.1' then
	NetInterface := '::1';

  FSocketHandle := fpSocket(AF_INET6, SOCK_STREAM, 0);

  Opt := 1;

  fpSetSockOpt (FSocketHandle, SOL_SOCKET, SO_REUSEADDR, @Opt, SizeOf(Opt));

  SIN.sin6_family := AF_INET6;
  SIN.sin6_port   := htons(Port);
  SIN.sin6_addr   := StrToNetAddr6(NetInterface);

  fpBind(FSocketHandle, @SIN, SizeOf(SIN));

  SetBlocking(True);
End;

Function TIOSocket.WaitConnection (TimeOut: LongInt) : TIOSocket;
Var
  Sock   : LongInt;
  Client : TIOSocket;
  PHE    : PHostEnt;
  SIN    : TINetSockAddr6;
  Temp   : LongInt;
  SL     : TSockLen;
  Code   : Integer;
  Hold	 : LongInt;
Begin
  Result := NIL;

  If TimeOut > 0 Then Begin
    SetBlocking(False);

    If fpListen(FSocketHandle, 5) = -1 Then Begin
      SetBlocking(True);

      Exit;
    End;

    If WaitForData(TimeOut) <= 0 Then Begin
      SetBlocking(True);

      Exit;
    End;
  End Else
    If fpListen(FSocketHandle, 5) = -1 Then Exit;

  Temp := SizeOf(SIN);
  Sock := fpAccept(FSocketHandle, @SIN, @Temp);

  If Sock = -1 Then Exit;

  {
	We Need to Determine if this is actually IPv4 Mapped as Six
	so that we can display and store the IP 4 Address.  This is 
	necessary to we can make FTP and BINKP work properly by
	opening returning ports on IPv4 and not IPv6, which won't work
        nor clear firewall with input accept established rule, the norm.
  }
  FPeerIP := Upcase(NetAddrToStr6(SIN.sin6_addr));
  if Length (FPeerIP) > 7 Then
	Begin
		If Pos('::FFFF:', FPeerIP) = 1 Then			// Is IPv4 mapped in 6?
		Begin
			Delete(FPeerIP, 1, 7);				// Strip off ::FFFF:
                        Delete(FPeerIP, 5, 1);				// Remove middle :
                        val('$' + FPeerIP, Hold, Code);		        // Convert to IPv4 Addy
		     	FPeerIP := HostAddrToStr(in_addr(Hold));
		End;
	End;
 
  PHE     := GetHostByAddr(@SIN.sin6_addr, 16, AF_INET6);

  If Not Assigned(PHE) Then
    FPeerName := 'Unknown'
  Else
    FPeerName := StrPas(PHE^.h_name);

  SL := SizeOf(SIN);

  fpGetSockName(FSocketHandle, @SIN, @SL);

  FHostIP := NetAddrToStr6(SIN.sin6_addr);
  Client  := TIOSocket.Create;

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

End.

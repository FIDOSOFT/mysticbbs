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
{$I M_OPS.PAS}

Unit m_Input_Linux;

Interface

Const
  ttyIn         = 0;
  ttyInBufSize  = 256;
  KeyBufferSize = 20;
  ttyOut        = 1;
  InSize        = 256;

  AltKeyStr  : string[38]='qwertyuiopasdfghjklzxcvbnm1234567890-=';
  AltCodeStr : string[38]=#016#017#018#019#020#021#022#023#024#025#030#031#032#033#034#035#036#037#038+
                          #044#045#046#047#048#049#050#120#121#122#123#124#125#126#127#128#129#130#131;
Type
  TInputLinux = Class
    InBuf     : Array[0..ttyInBufSize - 1] of Char;
    InCnt     : LongInt;
    InHead    : LongInt;
    InTail    : LongInt;
    KeyBuffer : Array[0..KeyBufferSize - 1] of Char;
    KeyPut,
    KeySend   : LongInt;

    Function    ttyRecvChar : Char;
    Procedure   PushKey (Ch : Char);
    Function    PopKey : Char;
    Procedure   PushExt (B : Byte);
    Function    FAltKey (Ch : Char) : Byte;
    Function    sysKeyPressed : Boolean;
    Function    KeyWait (MS: LongInt) : Boolean;
    Function    KeyPressed : Boolean;
    Function    ReadKey : Char;
    Procedure   PurgeInputData;
    Constructor Create;
    Destructor  Destroy; Override;
  End;

Implementation

Uses
  baseunix,
  m_DateTime;

Constructor TInputLinux.Create;
Begin
  Inherited Create;
End;

Destructor TInputLinux.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TInputLinux.PurgeInputData;
Begin
  While KeyPressed Do
    ReadKey;
End;

Function TInputLinux.ttyRecvChar : Char;
var
  Readed,i : longint;
begin
{Buffer Empty? Yes, Input from StdIn}
  if (InHead=InTail) then
   begin
   {Calc Amount of Chars to Read}
     i:=InSize-InHead;
     if InTail>InHead then
      i:=InTail-InHead;
   {Read}
     Readed:=fpRead(TTYIn,InBuf[InHead],i);
   {Increase Counters}
     inc(InCnt,Readed);
     inc(InHead,Readed);
   {Wrap if End has Reached}
     if InHead>=InSize then
      InHead:=0;
   end;
{Check Buffer}
  if (InCnt=0) then
   ttyRecvChar:=#0
  else
   begin
     ttyRecvChar:=InBuf[InTail];
     dec(InCnt);
     inc(InTail);
     if InTail>=InSize then
      InTail:=0;
   end;
end;

Procedure TInputLinux.PushKey(Ch:char);
Var
  Tmp : Longint;
Begin
  Tmp:=KeyPut;
  Inc(KeyPut);
  If KeyPut>=KeyBufferSize Then
   KeyPut:=0;
  If KeyPut<>KeySend Then
   KeyBuffer[Tmp]:=Ch
  Else
   KeyPut:=Tmp;
End;

Function TInputLinux.PopKey:char;
Begin
  If KeyPut<>KeySend Then
   Begin
     PopKey:=KeyBuffer[KeySend];
     Inc(KeySend);
     If KeySend>=KeyBufferSize Then
      KeySend:=0;
   End
  Else
   PopKey:=#0;
End;

Procedure TInputLinux.PushExt(b:byte);
begin
  PushKey(#0);
  PushKey(chr(b));
end;

Function TInputLinux.FAltKey(ch:char):byte;
var
  Idx : longint;
Begin
  Idx:=Pos(ch,AltKeyStr);
  if Idx>0 then
   FAltKey:=byte(AltCodeStr[Idx])
  else
   FAltKey:=0;
End;

{ This one doesn't care about keypresses already processed by readkey  }
{ and waiting in the KeyBuffer, only about waiting keypresses at the   }
{ TTYLevel (including ones that are waiting in the TTYRecvChar buffer) }

function TInputLinux.sysKeyPressed: boolean;
var
  fdsin : tfdSet;
begin
  if (InCnt>0) then
   sysKeyPressed:=true
  else
   begin
     fpFD_Zero(fdsin);
     fpFD_Set(TTYin,fdsin);
     sysKeypressed:=(fpSelect(TTYIn+1,@fdsin,nil,nil,0)>0);
   end;
end;

Function TInputLinux.KeyWait (MS : LongInt) : Boolean;
var
  fdsin : tfdset;
begin
  result := true;

  if (keysend <> keyput) or (incnt > 0) then exit;

  fpFD_Zero(fdsin);
  fpFD_Set(ttyin,fdsin);
  if fpSelect(ttyin+1,@fdsin,nil,nil,ms) <= 0 then
    result := false;
end;

Function TInputLinux.KeyPressed:Boolean;
Begin
  Keypressed := (KeySend<>KeyPut) or sysKeyPressed;
End;

Function TInputLinux.ReadKey:char;
Var
  ch       : char;
  OldState,
  State    : longint;
  FDS      : tFDSet;
Begin
{Check Buffer first}
  if KeySend<>KeyPut then
   begin
     ReadKey:=PopKey;
     exit;
   end;
{Wait for Key}
{ Only if none are waiting! (JM) }
  if not sysKeyPressed then
    begin
      fpFD_Zero (FDS);
      fpFD_Set (0,FDS);
      fpSelect (ttyin+1,@FDS,nil,nil,nil);
    end;

  ch:=ttyRecvChar;
{Esc Found ?}
  CASE ch OF
  #27: begin
     State:=1;
     WaitMS(10);


     { This has to be sysKeyPressed and not "keyPressed", since after }
     { one iteration keyPressed will always be true because of the    }
     { pushKey commands (JM)                                          }
     while (State<>0) and (sysKeyPressed) do
      begin
        ch:=ttyRecvChar;
        OldState:=State;
        State:=0;
        case OldState of
        1 : begin {Esc}
              case ch of
          'a'..'z',
          '0'..'9',
           '-','=' : PushExt(FAltKey(ch));
               #10 : PushKey(#10);
               '[' : State := 2;
                'O': State := 7;
               else
                begin
                  PushKey(ch);
                  PushKey(#27);
                end;
               end;
            end;
        2 : begin {Esc[}
              case ch of
               '[' : State := 3;
               'A' : PushExt(72);
               'B' : PushExt(80);
               'C' : PushExt(77);
               'D' : PushExt(75);
               'G' : PushKey('5'); {Center key, Linux}
               'H' : PushExt(71);
               'K' : PushExt(79);
               'U' : PushExt(81); //syncterm nonsense
               'V' : PushExt(73); //syncterm nonsense
               '1' : State:=4;
               '2' : State:=5;
               '3' : State:=6;
               '4' : PushExt(79);
               '5' : PushExt(73);
               '6' : PushExt(81);
              else
               begin
                 PushKey(ch);
                 PushKey('[');
                 PushKey(#27);
               end;
              end;
              if ch in ['4'..'6'] then
               State:=255;
            end;
        3 : begin {Esc[[}
              case ch of
               'A' : PushExt(59);
               'B' : PushExt(60);
               'C' : PushExt(61);
               'D' : PushExt(62);
               'E' : PushExt(63);
              end;
            end;
        4 : begin {Esc[1}
              case ch of
               '~' : PushExt(71);
               '5' : State := 8;
               '7' : PushExt(64);
               '8' : PushExt(65);
               '9' : PushExt(66);
              end;
              if not (Ch in ['~', '5']) then
               State:=255;
            end;
        5 : begin {Esc[2}
              case ch of
               '~' : PushExt(82);
               '0' : pushExt(67);
               '1' : PushExt(68);
               '3' : PushExt(133); {F11}
                {Esc[23~ is also shift-F1,shift-F11}
               '4' : PushExt(134); {F12}
                {Esc[24~ is also shift-F2,shift-F12}
               '5' : PushExt(86); {Shift-F3}
               '6' : PushExt(87); {Shift-F4}
               '8' : PushExt(88); {Shift-F5}
               '9' : PushExt(89); {Shift-F6}
              end;
              if (Ch<>'~') then
               State:=255;
            end;
        6 : begin {Esc[3}
              case ch of
               '~' : PushExt(83); {Del}
               '1' : PushExt(90); {Shift-F7}
               '2' : PushExt(91); {Shift-F8}
               '3' : PushExt(92); {Shift-F9}
               '4' : PushExt(93); {Shift-F10}
              end;
              if (Ch<>'~') then
               State:=255;
            end;
        7 : begin {Esc[O}
              case ch of
               'A' : PushExt(72);
               'B' : PushExt(80);
               'C' : PushExt(77);
               'D' : PushExt(75);
               'F' : PushExt(79);
               'H' : PushExt(71);
               'P' : PushExt(59);
               'Q' : PushExt(60);
               'R' : PushExt(61);
               'S' : PushExt(62);
              end;
          end;
        8 : begin {Esc[15}
            case ch of
              '~' : PushExt(63);
            end;
          end;
      255 : ;
        end;
        if State<>0 then
         WaitMS(10);
      end;
     if State=1 then
      PushKey(ch);
   end;
  #127: PushKey(#8);
  else PushKey(ch);
  End;
  ReadKey:=PopKey;
End;

End.

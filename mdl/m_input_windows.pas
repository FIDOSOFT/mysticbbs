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
Unit m_Input_Windows;

{$I M_OPS.PAS}

Interface

Uses
  Windows;

Type
  TInputWindows = Class
    ConIn         : THandle;
    Buffer        : Array[1..64] of Char;
    BufPos        : Byte;
    BufSize       : Byte;
    DoingNumChars : Boolean;
    DoingNumCode  : Byte;

    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   AddBuffer (Ch: Char);
    Function    RemapScanCode (ScanCode: Word; CtrlKeyState: dWord; Keycode: Word) : Byte;
    Function    ProcessQueue : Boolean;
    Function    KeyWait (MS: Cardinal) : Boolean;
    Function    KeyPressed : Boolean;
    Function    ReadKey : Char;
  End;

Implementation

Constructor TInputWindows.Create;
Begin
  Inherited Create;

  ConIn := GetStdHandle(STD_INPUT_HANDLE);

  SetConsoleMode (ConIn, 0);

  BufPos  := 0;
  BufSize := 0;
End;

Destructor TInputWindows.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TInputWindows.AddBuffer (Ch: Char);
Begin
  Inc (BufSize);

  If BufSize > 64 Then BufSize := 1;

  Buffer[BufSize] := Ch;
End;

Function TInputWindows.RemapScanCode (ScanCode: Word; CtrlKeyState: dWord; keycode: Word) : Byte;
Var
  AltKey,
  CtrlKey,
  ShiftKey : Boolean;
Const
  CtrlKeypadKeys: Array[$47..$53] of Byte = (
    $77,
    $8D,
    $84,
    $8E,
    $73,
    $8F,
    $74,
    $4E,
    $75,
    $91,
    $76,
    $92,
    $93
  );
Begin
  AltKey   := ((CtrlKeyState AND (RIGHT_ALT_PRESSED OR LEFT_ALT_PRESSED)) > 0);
  CtrlKey  := ((CtrlKeyState AND (RIGHT_CTRL_PRESSED OR LEFT_CTRL_PRESSED)) > 0);
  ShiftKey := ((CtrlKeyState AND SHIFT_PRESSED) > 0);

  If AltKey Then Begin
    Case KeyCode of
      VK_NUMPAD0 ..
      VK_NUMPAD9    : Begin
                       DoingNumChars := True;
                       DoingNumCode  := Byte((DoingNumCode * 10) + (KeyCode - VK_NUMPAD0));
                      End;
    End;

    Case ScanCode of
      $02..$0D: Inc(ScanCode, $76);  // Digits, -, =
      $3B..$44: Inc(ScanCode, $2D);  // Function keys
      $57..$58: Inc(ScanCode, $34);  // Function keys
      $47..$49,
      $4B, $4D,
      $4F..$53: Inc(ScanCode, $50);
      $1C     : ScanCode := $A6;   // Enter
      $35     : ScanCode := $A4;   // /
    End
  End Else If CtrlKey Then
    Case ScanCode of
      $0F     : ScanCode := $94;     // TAB
      $3B..$44: Inc(ScanCode, $23);  // Function keys
      $57..$58: Inc(ScanCode, $32);  // Function keys
      $35:      ScanCode := $95;     // \
      $37:      ScanCode := $96;     // *
      $47..$53: ScanCode := CtrlKeypadKeys[ScanCode];
    End
  Else If ShiftKey Then
    Case ScanCode of
      $3B..$44: Inc(ScanCode, $19);
      $57..$58: Inc(ScanCode, $30);
    End
  Else
    Case ScanCode of
      $57..$58: Inc(Scancode, $2E); // F11 and F12
    End;

  Result := ScanCode;
End;

Function TInputWindows.ProcessQueue : Boolean;
Var
  InputRec : TInputRecord;
  NumRead  : ULong;
Begin
  Result := False;

  Repeat
    ReadConsoleInput(ConIn, InputRec, 1, NumRead);

    If InputRec.EventType = key_event then
      If InputRec.Event.KeyEvent.bKeyDown then begin
        If not(InputRec.Event.KeyEvent.wVirtualKeyCode in [VK_SHIFT, VK_MENU, VK_CONTROL, VK_CAPITAL, VK_NUMLOCK, VK_SCROLL]) then begin

          If (Ord(InputRec.Event.KeyEvent.AsciiChar) = 0) or (InputRec.Event.KeyEvent.dwControlKeyState and (LEFT_ALT_PRESSED or ENHANCED_KEY or RIGHT_ALT_PRESSED) > 0) Then Begin
            If (Ord(InputRec.Event.KeyEvent.AsciiChar) = 13) and (InputRec.Event.KeyEvent.wVirtualKeyCode = VK_RETURN) Then Begin
              addBuffer(#13);
              Result := True;
              Exit;
            End Else
            If ((InputRec.Event.KeyEvent.dwControlKeyState AND (RIGHT_ALT_PRESSED OR LEFT_CTRL_PRESSED)) = (RIGHT_ALT_PRESSED OR LEFT_CTRL_PRESSED)) and (Ord(InputRec.Event.KeyEvent.AsciiChar) <> 0) Then Begin
              AddBuffer(Chr(Ord(InputRec.Event.KeyEvent.AsciiChar)));
              Result := True;
              Exit;
            End Else Begin
              addBuffer(#0);
              addBuffer(Chr(RemapScanCode(InputRec.Event.KeyEvent.wVirtualScanCode, InputRec.Event.KeyEvent.dwControlKeyState, InputRec.Event.KeyEvent.wVirtualKeyCode)));
              Result := True;
              Exit;
            End;
          End Else Begin
            addBuffer(Chr(Ord(InputRec.Event.KeyEvent.AsciiChar)));
            Result := True;
            Exit;
          End;
        end;
      End Else
        If (InputRec.Event.KeyEvent.wVirtualKeyCode in [VK_MENU]) Then
          If DoingNumChars Then
            If DoingNumCode > 0 Then Begin
              AddBuffer(Chr(DoingNumCode));

              DoingNumChars := False;
              DoingNumCode  := 0;

              Result := True;
              Break;
            End;

    GetNumberOfConsoleInputEvents(ConIn, NumRead);
  Until NumRead = 0;
End;

Function TInputWindows.KeyWait (MS: Cardinal) : Boolean;
Begin
  If BufPos <> BufSize Then Begin
    Result := True;
    Exit;
  End;

  Repeat
    Case WaitForSingleObject(ConIn, MS) of
      Wait_Object_0 : Result := ProcessQueue;
    Else
      Result := False;
      Break;
    End;
  Until Result;
End;

Function TInputWindows.ReadKey : Char;
Begin
  If BufPos = BufSize then
    keyWait (Infinite);

  Inc (BufPos);

  If BufPos > 64 Then BufPos := 1;

  Result := Buffer[BufPos];
End;

Function TInputWindows.KeyPressed : Boolean;
Var
  Temp : ULong;
Begin
  If BufPos = BufSize Then Begin
    GetNumberOfConsoleInputEvents(ConIn, Temp);
    If Temp > 0 Then keyWait(1);
  End;

  Result := BufPos <> BufSize;
End;

End.

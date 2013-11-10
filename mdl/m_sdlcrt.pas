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
Unit m_SDLCRT;

{$I M_OPS.PAS}

(*
Goals:

- Cross platform input and output capable of 80x25, 80x50, 132x50
- Input events remapped as compatible with current code base
- Full screen mode in Windows, OSX, and Linux if possible
- Direct access (read only) to a virtual screen buffer something like:
    TSDLScreenBuffer = Record
      Line : Array[1..132] of Record
               Ch   : Char;
               Attr : Byte;
             End;
- Current X location
- Current Y location
- Current Text Attribute
- Window function to set scroll points
- GotoXY
- Clear Screen (window based)
- Clear to end of line (with current attribute)
- Set Window title
- Hide screen
- Show Buffer
- KeyPressed : Boolean
- KeyWait (Timeout in seconds or MS) : Boolean
- ReadKey (from buffer, or waits infinity if nothing)
- Ability to wait for input event based on handle for WaitForMultipleObj ?
- Ability to play a .WAV/MP3/MIDI file or at least some sound?
- How to handle shutdown and resize window events?  Lock resize?
- How to handle minimize?  Minimize to tray in Windows?
*)

Interface

Uses
  SDL,
  SDL_TTF;

Const
  keyENTER             = #13;
  keyESCAPE            = #27;
  keyHOME              = #71;
  keyUP                = #72;
  keyPGUP              = #73;
  keyLEFT              = #75;
  keyRIGHT             = #77;
  keyEND               = #79;
  keyDOWN              = #80;
  keyPGDN              = #81;
  keyINSERT            = #82;
  keyDELETE            = #83;

  AppInputSize         = 128;
  SDLFontSize   : Byte = 24;
  SDLFontSpace  : Byte = 0;
  SDLAppWindowX : Word = 800;
  SDLAppWindowY : Word = 600;

Type
  TSDLScreenMode = (mode_80x25, mode_80x50, mode_132x50);

  TSDLKeyMap = Record
    SDL   : Word;
    Key   : String[2];
    Shift : String[2];
    Alt   : String[2];
    Ctrl  : String[2];
  End;

  TSDLConsole = Class
    InputEvent  : pSDL_EVENT;
    Screen      : pSDL_SURFACE;
    Font        : pTTF_Font;

    InputBuffer : Array[1..AppInputSize] of Char;
    InputPos    : Integer;
    InputSize   : Integer;

    CursorX     : Byte;
    CursorY     : Byte;
    TextAttr    : Byte;

    // INIT STUFF
    Constructor Create           (InitMode: TSDLScreenMode);
    Destructor  Destroy;         Override;
    // INTERNAL STUFF
    Procedure   PushInput        (Ch: Char);
    Procedure   PushExt          (Ch: Char);
    Procedure   PushStr          (Str: String);
    Procedure   ProcessEvent;
//    Function    GetDosForeground (Color: Byte) : TSDL_Color;
//    Function    GetDosBackground (Color: Byte) : TSDL_Color;
    // FUNCTIONAL
    Function    KeyPressed       : Boolean;
    Function    ReadKey          : Char;
    Procedure   Delay            (MS: LongInt);
    Procedure   SetTitle         (Title: String);
    Procedure   ShowBuffer;
    //NONSENSE
    Procedure   TestStuff;
  End;

Implementation

// SDL fails hard with keyboard handling.  I think we need to use
// a lookup table that can be externalized into a data file so different
// countries can load their specific keyboard set.
//
// I just assumed things like this would NOT be a problem in SDL. Pretty
// disappointing actually.  So below is the US mapping as I get time to
// work on it.

Const
  SDLKeyMapSize = 3;

  SDLKeyMapUS : Array[1..SDLKeyMapSize] of TSDLKeyMap = (
    (SDL:SDLK_1;      Key:'1';   Shift:'!';   Alt:'1';   CTRL:'1'),
    (SDL:SDLK_2;      Key:'2';   Shift:'@';   Alt:'2';   CTRL:'2'),
    (SDL:SDLK_SLASH;  Key:'/';   Shift:'?';   Alt:'/';   CTRL:'/')
  );

  SDLDosColor : Array[0..15] of TSDL_Color = (
    (R:000;   G:000;   B:000;  Unused: 0), //00
    (R:000;   G:000;   B:128;  Unused: 0), //01
    (R:000;   G:128;   B:000;  Unused: 0), //02
    (R:000;   G:128;   B:128;  Unused: 0), //03
    (R:170;   G:000;   B:000;  Unused: 0), //04
    (R:128;   G:000;   B:128;  Unused: 0), //05
    (R:128;   G:128;   B:000;  Unused: 0), //06
    (R:192;   G:192;   B:192;  Unused: 0), //07
    (R:128;   G:128;   B:128;  Unused: 0), //08
    (R:000;   G:000;   B:255;  Unused: 0), //09
    (R:000;   G:255;   B:000;  Unused: 0), //10
    (R:000;   G:255;   B:255;  Unused: 0), //11
    (R:255;   G:000;   B:000;  Unused: 0), //12
    (R:255;   G:000;   B:255;  Unused: 0), //13
    (R:255;   G:255;   B:000;  Unused: 0), //14
    (R:255;   G:255;   B:255;  Unused: 0)  //15
  );

Constructor TSDLConsole.Create (InitMode: TSDLScreenMode);
Begin
  Inherited Create;

  SDL_INIT(SDL_INIT_VIDEO);

//  Screen := SDL_SetVideoMode(SDLAppWindowX, SDLAppWindowY, 32, SDL_HWSURFACE or SDL_FULLSCREEN);
  Screen := SDL_SetVideoMode(SDLAppWindowX, SDLAppWindowY, 32, SDL_HWSURFACE);

  If Screen = NIL Then Halt;

  If TTF_Init = -1 Then Halt;

//  Font := TTF_OpenFont('ASCII.ttf', SDLFontSize);
  Font := TTF_OpenFont('\dev\sdl\Perfect DOS VGA 437.ttf', SDLFontSize);

  If Font = NIL Then Halt;

  New (InputEvent);

  InputSize := 0;
  InputPos  := 0;
  CursorX   := 1;
  CursorY   := 1;
  TextAttr  := 7;
End;

Destructor TSDLConsole.Destroy;
Begin
  Dispose (InputEvent);

  TTF_CloseFont(Font);

  TTF_Quit;

  SDL_QUIT;

  Inherited Destroy;
End;

Procedure TSDLConsole.PushInput (Ch: Char);
Begin
  Inc (InputSize);

  If InputSize > AppInputSize Then Begin
    InputSize := 1;
    InputPos  := 0;
  End;

  InputBuffer[InputSize] := Ch;
End;

Procedure TSDLConsole.PushExt (Ch: Char);
Begin
  PushInput(#0);
  PushInput(Ch);
End;

Procedure TSDLConsole.PushStr (Str: String);
Begin
  PushInput (Str[1]);

  If Length(Str) > 1 Then PushInput (Str[2]);
End;

Procedure TSDLConsole.ProcessEvent;
Var
  IsShift : Boolean = False;
  IsCaps  : Boolean = False;
  IsAlt   : Boolean = False;
  IsCtrl  : Boolean = False;
  Found   : Boolean;
  Count   : Integer;
Begin
  IsShift := (InputEvent^.Key.KeySym.Modifier AND KMOD_SHIFT <> 0);
  IsCaps  := (InputEvent^.Key.KeySym.Modifier AND KMOD_CAPS  <> 0);
  IsAlt   := (InputEvent^.Key.KeySym.Modifier AND KMOD_ALT   <> 0);
  IsCtrl  := (InputEvent^.Key.KeySym.Modifier AND KMOD_CTRL  <> 0);

  Case InputEvent^.Type_ of
    SDL_KEYDOWN : Begin
                    Case InputEvent^.Key.KeySym.Sym of
                      SDLK_A..
                      SDLK_Z        : Begin
                                        If IsShift or IsCaps Then Dec (InputEvent^.Key.KeySym.Sym, 32);
                                        PushInput (Chr(InputEvent^.Key.KeySym.Sym));
                                      End;
                      SDLK_DELETE   : PushExt(keyDELETE);
                      SDLK_UP       : PushExt(keyUP);
                      SDLK_DOWN     : PushExt(keyDOWN);
                      SDLK_RIGHT    : PushExt(keyRIGHT);
                      SDLK_LEFT     : PushExt(keyLEFT);
                      SDLK_INSERT   : PushExt(keyINSERT);
                      SDLK_HOME     : PushExt(keyHome);
                      SDLK_END      : PushExt(keyEnd);
                      SDLK_PAGEUP   : PushExt(keyPGUP);
                      SDLK_PAGEDOWN : PushExt(keyPGDN);
                      SDLK_NUMLOCK..
                      SDLK_COMPOSE  : //ignore mod keys;
                    Else
                      Found := False;

                      For Count := 1 to SDLKeyMapSize Do
                        If InputEvent^.Key.KeySym.Sym = SDLKeyMapUS[Count].SDL Then Begin
                          If IsShift Then
                            PushStr(SDLKeyMapUS[Count].Shift)
                          Else
                          If IsAlt Then
                            PushStr(SDLKeyMapUS[Count].Alt)
                          Else
                          If IsCTRL Then
                            PushStr(SDLKeyMapUS[Count].CTRL)
                          Else
                            PushStr(SDLKeyMapUS[Count].Key);

                          Found := True;

                          Break;
                        End;

                        If Not Found Then PushInput(Chr(InputEvent^.Key.KeySym.Sym));
                    End;
                  End;
    SDL_QUITEV  : Halt;
  End;
End;

Function TSDLConsole.KeyPressed : Boolean;
Begin
  If SDL_PollEvent(InputEvent) > 0 Then
    ProcessEvent;

  Result := InputPos <> InputSize;
End;

Function TSDLConsole.ReadKey : Char;
Begin
  If InputPos = InputSize Then
    Repeat
      SDL_WaitEvent(InputEvent);
      ProcessEvent;
    Until (InputSize <> InputPos);

  Inc (InputPos);

  Result := InputBuffer[InputPos];

  If InputPos = InputSize Then Begin
    InputPos  := 0;
    InputSize := 0;
  End;
End;

Procedure TSDLConsole.Delay (MS: LongInt);
Begin
  SDL_DELAY(MS);
End;

Procedure TSDLConsole.SetTitle (Title: String);
Begin
  Title := Title + #0;

  SDL_WM_SetCaption(PChar(@Title[1]), PChar(@Title[1]));
End;

Procedure TSDLConsole.TestStuff;
Var
  Rect    : TSDL_Rect  = (X:0; Y:0; W:0; H:0);
  Surface : PSDL_Surface;
  Text    : String;
  Count   : Byte;
Begin
  Text := #176 + 'SDL Demo!  Press Escape to quit!' + #0;

  Surface := TTF_RenderText_Shaded (Font, PChar(@Text[1]), SDLDosColor[7], SDLDosColor[0]);

  SDL_BlitSurface (Surface, NIL, Screen, @Rect);
  SDL_FreeSurface (Surface);

  For Count := 3 to 17 Do Begin
    Text    := #219 + '2345678901234567890123456789012345678901234567890123456789012345678901234567890';
    Rect.Y  := (Count - 1) * SDLFontSize + SDLFontSpace;
    Surface := TTF_RenderText_Shaded (Font, PChar(@Text[1]), SDLDosColor[Count-2], SDLDosColor[0]);

    SDL_BlitSurface (Surface, NIL, Screen, @Rect);
    SDL_FreeSurface (Surface);
  End;

  For Count := 18 to 25 Do Begin
    Text    := #219 + '2345678901234567890123456789012345678901234567890123456789012345678901234567890';
    Rect.Y  := (Count - 1) * SDLFontSize + SDLFontSpace;
    Surface := TTF_RenderText_Shaded (Font, PChar(@Text[1]), SDLDosColor[7], SDLDosColor[0]);

    SDL_BlitSurface (Surface, NIL, Screen, @Rect);
    SDL_FreeSurface (Surface);
  End;

  SDL_Flip(Screen);
End;

Procedure TSDLConsole.ShowBuffer;
Begin
  SDL_Flip(Screen);
End;

End.

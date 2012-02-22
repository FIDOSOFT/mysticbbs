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
  SDL;

Const
  AppWindowX   = 800;
  AppWindowY   = 600;
  AppInputSize = 128;

Type
  TSDLScreenMode = (mode_80x25, mode_80x50, mode_132x50);

  TSDLConsole = Class
    InputBuffer : Array[1..AppInputSize] of Char;
    InputPos    : Integer;
    InputSize   : Integer;

    InputEvent : pSDL_EVENT;
    Screen     : pSDL_SURFACE;

    Constructor Create     (InitMode: TSDLScreenMode);
    Destructor  Destroy;

    Procedure   PushInput  (Ch: Char);
    Procedure   ProcessEvent;
    Function    KeyPressed : Boolean;
    Procedure   Delay      (MS: LongInt);
  End;

Implementation

Constructor TSDLConsole.Create (InitMode: TSDLScreenMode);
Begin
  Inherited Create;

  SDL_INIT(SDL_INIT_VIDEO OR SDL_INIT_EVENTTHREAD);

  Screen := SDL_SetVideoMode(AppWindowX, AppWindowY, 32, SDL_SWSURFACE);

  If Screen = NIL Then Halt;

  New (InputEvent);

  InputSize := 0;
  InputPos  := 0;
End;

Destructor TSDLConsole.Destroy;
Begin
  Dispose (InputEvent);

  SDL_QUIT;

  Inherited Destroy;
End;

Procedure TSDLConsole.PushInput (Ch: Char);
Begin
  Inc (InputSize);

  If InputSize > AppInputSize Then Begin
    InputSize := 1;
    InputPos  := 1;
  End;

  InputBuffer[InputSize] := Ch;
End;

Procedure TSDLConsole.ProcessEvent;
Begin
  Case InputEvent^.Type_ of
    SDL_KEYDOWN : Case InputEvent^.Key.KeySym.Sym of
                    // remap SDL keys to pascal CRT
                    27 : PushInput(#27);
                  Else
                    PushInput(Chr(InputEvent^.Key.KeySym.Sym));
                  End;
  End;
End;

Function TSDLConsole.KeyPressed : Boolean;
Var
  Queued : LongInt;
Begin
  Result := False;

  Queued := SDL_PollEvent(InputEvent);

  If Queued > 0 Then
    ProcessEvent;

  Result := InputSize > 0;
End;

Procedure TSDLConsole.Delay (MS: LongInt);
Begin
  SDL_DELAY(MS);
End;

End.

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
  AppWindowX = 640;
  AppWindowY = 480;

Type
  TSDLScreenMode = (mode_80x25, mode_80x50, mode_132x50);

  TSDLConsole = Class
    InputEvent : pSDL_EVENT;
    Screen     : pSDL_SURFACE;

    Constructor Create;
    Destructor  Destroy;
  End;

Implementation

Constructor TSDLConsole.Create;
Begin
  Inherited Create;

  SDL_INIT(SDL_INIT_VIDEO OR SDL_INIT_EVENTTHREAD);
End;

Destructor TSDLConsole.Destroy;
Begin
  SDL_QUIT;

  Inherited Destroy;
End;

End.

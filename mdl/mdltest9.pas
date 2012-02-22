Program MDLTEST9;

Uses
  m_SDLCRT;

Var
  Console : TSDLConsole;

Begin
  Console := TSDLConsole.Create(Mode_80x25);

  Repeat
  Until Console.KeyPressed;

  Console.Free;
End.

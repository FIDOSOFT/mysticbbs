Program MDLTEST9;

Uses
  m_SDLCRT;

Var
  Console : TSDLConsole;
  Ch      : Char;
Begin
  Console := TSDLConsole.Create(Mode_80x25);

  Repeat
    Ch := Console.ReadKey;

    Case Ch of
      #00 : Case Console.ReadKey of
              keyUP     : WriteLn('Got Up arrow');
              keyDOWN   : WriteLn('Got down arrow');
              keyLEFT   : WriteLn('Got left arrow');
              keyRIGHT  : WriteLn('Got right arrow');
              keyHOME   : WriteLn('Got HOME');
              keyEND    : WriteLn('Got END');
              keyPGUP   : WriteLn('Got PAGE UP');
              keyPGDN   : WriteLn('Got PAGE Down');
              keyINSERT : WriteLn('Got INSERT');
              keyDELETE : WriteLn('Got DELETE');
            End;
      #27 : Begin
              WriteLn('Got escape.  Shutting down');
              Break;
            End;
      Else
        WriteLn('Got: ' + Ch);
    End;
  Until False;

  Console.Free;
End.

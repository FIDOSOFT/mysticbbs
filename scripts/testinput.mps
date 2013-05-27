// =========================================================================
// TESTINPUT : MPL example of using the ANSI input and box classes
// =========================================================================

Var
  Box   : LongInt;
  In    : LongInt;
  InPos : Byte    = 1;
  Str   : String  = 'Input default';
  Num   : LongInt = 1;
Begin
  PurgeInput;

  ClassCreate (Box, 'box');
  ClassCreate (In, 'input');

  BoxHeader (Box, 0, 31, ' Input Demo ');

  InputOptions (In,          // Input class handle
                31,          // Attribute of inputted text
                25,          // Attribute to use for field input filler
                #176,        // Character to use for field input filler
                #9,          // Input will exit on these "low" ascii characters
                             // TAB
                #72 + #80);  // Input will exit on these "extended" characters
                             // UP and DOWN arrows

  BoxOpen (Box, 20, 5, 60, 12);

  Repeat
    WriteXY (22,  7, 112, 'String Input > ' + PadRT(Str, 22, ' '));
    WriteXY (22,  8, 112, 'Number Input > ' + PadRT(Int2Str(Num), 5, ' '));
    WriteXY (38, 10, 112, ' DONE ');

    Case InPos of
      1 : Str := InputString (In, 37, 7, 22, 22, 1, Str);
      2 : Num := InputNumber (In, 37, 8, 5, 5, 1, 65000, Num);
      3 : If InputEnter (In, 38, 10, 6, ' DONE ') Then Break;
    End;

    Case InputExit(In) of
      #09,
      #80 : If InPos < 3 Then InPos := InPos + 1 Else InPos := 1;
      #72 : If InPos > 1 Then InPos := InPos - 1 Else InPos := 3;
    End;
  Until False;

  BoxClose  (Box);
  ClassFree (Box);
  ClassFree (In);
End.

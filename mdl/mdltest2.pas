Program TESTIO_2;

{$I M_OPS.PAS}

Uses
  m_Types,
  m_Strings,
  m_Input,
  m_Output,
  m_MenuBox,
  m_MenuForm;

Const
  { TheDraw Pascal Crunched Screen Image.  Date: 09/03/02 }
  TESTMAIN_WIDTH=80;
  TESTMAIN_LENGTH=128;
  TESTMAIN : array [1..128] of Char = (
    #15,#16,#26,'N','Ü', #7,'Ü',#24,#15,'Û',#23,#25,'M', #8,#16,'Û',#24,
     #7,'ß', #8,#26,'N','ß',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O',
    '°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',
    #24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,
    #26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,
    'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O','°',#24,#26,'O',
    '°',#24,#26,'@','Ä',' ',#26, #3,'Ä',' ','Ä','Ä',' ',' ','Ä',' ',' ',
    'ù',#24,#15,':', #7,':', #8,':',#24);

Var
  Screen       : TOutput;
  Menu         : TMenuForm;
  Box          : TMenuBox;
  Image        : TConsoleImageRec;
  MenuPosition : Byte;
  Res          : Char;

Procedure BoxOpen (X1, Y1, X2, Y2: Byte);
Begin
  Box := TMenuBox.Create(Screen);

  Box.Open(X1, Y1, X2, Y2);
End;

Procedure BoxClose;
Begin
  Box.Close;
  Box.Free;
End;

Procedure CoolBoxOpen (X1: Byte; Text: String);
Var
  Len : Byte;
Begin
  Len := Length(Text) + 6;

  Screen.GetScreenImage(X1, 1, X1 + Len, 3, Image);

  Screen.WriteXYPipe (X1, 1, 8, Len, 'Ü|15Ü|11ÜÜ|03ÜÜ|09Ü|03Ü|09' + strRep('Ü', Len - 9) + '|08Ü');
  Screen.WriteXYPipe (X1 ,2, 8, Len, 'Ý|09|17² |15' + Text + ' |00°|16|08Þ');
  Screen.WriteXYPipe (X1, 3, 8, Len, 'ß|01²|17 |11À|03ÄÄ|08' + strRep('Ä', Length(Text) - 4) + '|00¿ ±|16|08ß');
End;

Procedure CoolBoxClose;
Begin
  Screen.PutScreenImage(Image);
End;

Procedure AboutBox;
Begin
  BoxOpen (19, 7, 62, 19);

  Screen.WriteXY (21,  8,  31, strPadC('Test IO Program', 40, ' '));
  Screen.WriteXY (21,  9, 112, strRep('-', 40));
  Screen.WriteXY (26, 11, 113, 'Copyright (C) 2003 By No One');
  Screen.WriteXY (31, 12, 113, 'All Rights Reserved');
  Screen.WriteXY (21, 14, 113, strPadC('Version 1.00', 40, ' '));
  Screen.WriteXY (32, 16, 113, 'www.someplace.com');
  Screen.WriteXY (21, 17, 112, strRep('-', 40));
  Screen.WriteXY (21, 18,  31, strPadC('(PRESS A KEY)', 40, ' '));

  Menu.Input.ReadKey;

  BoxClose;
End;

Procedure FormTest;
Var
  MyBox  : TMenuBox;
  MyForm : TMenuForm;
  Data   : Array[1..9] of String;
Begin
  MyBox  := TMenuBox.Create(Screen);
  MyForm := TMenuForm.Create(Screen);

  MyBox.Header := ' Input Test ';

  MyBox.Open   (5, 6, 75, 18);

  MyForm.AddStr ('1', ' String Test #1 ', 8,  8, 28,  8, 16, 45, 60, @Data[1], 'String input test #1');
  MyForm.AddStr ('2', ' String Test #2 ', 8,  9, 28,  9, 16, 45, 60, @Data[2], 'String input test #2');
  MyForm.AddStr ('3', ' String Test #3 ', 8, 10, 28, 10, 16, 45, 60, @Data[3], 'String input test #3');
  MyForm.AddStr ('4', ' String Test #4 ', 8, 11, 28, 11, 16, 45, 60, @Data[4], 'String input test #4');
  MyForm.AddStr ('5', ' String Test #5 ', 8, 12, 28, 12, 16, 45, 60, @Data[5], 'String input test #5');
  MyForm.AddStr ('6', ' String Test #6 ', 8, 13, 28, 13, 16, 45, 60, @Data[6], 'String input test #6');
  MyForm.AddStr ('7', ' String Test #7 ', 8, 14, 28, 14, 16, 45, 60, @Data[7], 'String input test #7');
  MyForm.AddStr ('8', ' String Test #8 ', 8, 15, 28, 15, 16, 45, 60, @Data[8], 'String input test #8');
  MyForm.AddStr ('9', ' String Test #9 ', 8, 16, 28, 16, 16, 45, 60, @Data[9], 'String input test #9');

  MyForm.Execute;

  Box.Close;

  MyForm.Free;
  MyBox.Free;
End;

Begin
  Screen := TOutput.Create(True);
  Menu   := TMenuForm.Create(Screen);

  Screen.SetWindowTitle('IO TEST #2');
  Screen.LoadScreenImage(TESTMAIN, TESTMAIN_LENGTH, TESTMAIN_WIDTH, 1, 1);

  MenuPosition := 0;

  Repeat
    Menu.Clear;

    If MenuPosition = 0 Then Begin
      Menu.HiExitChars := #80;
      Menu.ExitOnFirst := False;
    End Else Begin
      Menu.HiExitChars := #75#77;
      Menu.ExitOnFirst := True;
    End;

    Case MenuPosition of
      0 : Begin
            Menu.AddNone('M', ' Main Menu ',  3, 2, 11, 'Menu menu options');
            Menu.AddNone('X', ' Exit '     , 16, 2, 6,  'Exit/About options');

            Res := Menu.Execute;

            If Menu.WasHiExit Then
              MenuPosition := Menu.ItemPos
            Else
              Case Res of
                #27 : Break;
                'M' : MenuPosition := 1;
                'X' : MenuPosition := 2;
              End;
          End;
      1 : Begin
            BoxOpen (2, 4, 20, 9);
            CoolBoxOpen (1, 'Main Menu');

            Menu.AddNone ('F', ' Form/Input Test ', 3, 5, 17, 'Test form and input functions');
            Menu.AddNone ('N', ' Nothing #1'      , 3, 6, 17, 'Nothing at all #1');
            Menu.AddNone ('N', ' Nothing #2'      , 3, 7, 17, 'Nothing at all #2');
            Menu.AddNone ('N', ' Nothing #3'      , 3, 8, 17, 'Nothing at all #3');

            Res := Menu.Execute;

            BoxClose;
            CoolBoxClose;

            If Menu.WasHiExit Then Begin
              Case Res of
                #75 : MenuPosition := 2;
                #77 : MenuPosition := 2;
              End;
            End Else
              Case Res of
                'F' : FormTest;
                'N' : ;
              Else
                MenuPosition := 0;
              End;
          End;
      2 : Begin
            BoxOpen (15, 4, 23, 7);
            CoolBoxOpen (14, 'Exit');

            Menu.AddNone ('A', ' About ', 16, 5, 7, 'About this test program');
            Menu.AddNone ('X', ' Exit ' , 16, 6, 7, 'Exit this program');

            Res := Menu.Execute;

            BoxClose;
            CoolBoxClose;

            If Menu.WasHiExit Then Begin
              Case Res of
                #75 : MenuPosition := 1;
                #77 : MenuPosition := 1;
              End;
            End Else
              Case Res of
                'A' : AboutBox;
                'X' : Break;
              Else
                MenuPosition := 0;
              End;
          End;
    End;
  Until False;

  Screen.ClearScreen;
  Screen.WriteLine('MDL: Test Program #2 Completed');

  Menu.Free;
  Screen.Free;
End.

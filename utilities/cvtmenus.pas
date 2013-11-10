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
Program CvtMenus;

{$I M_OPS.PAS}

Uses
  lineinfo,
  DOS,
  m_Strings,
  m_FileIO,
  Classes;

{$I RECORDS.PAS}

Type
  OldMenuFlags = Record
    Header    : String[255];
    Prompt    : String[255];
    DispCols  : Byte;
    Access    : String[30];
    Password  : String[15];
    DispFile  : String[20];
    FallBack  : String[20];
    MenuType  : Byte; { 0 = standard, 1 = lightbar, 2 = lightbar grid }
    InputType : Byte; { 0 = user setting, 1 = longkey, 2 = hotkey }
    DoneX     : Byte;
    DoneY     : Byte;
    Global    : Byte; { 0 = no, 1 = yes }
  End;

  OldMenuItem = Record
    Text    : String[79];
    TextLo  : String[79];
    TextHi  : String[79];
    HotKey  : String[8];
    LongKey : String[8];
    Access  : string[30];
    Command : String[2];
    Data    : String[79];
    X       : Byte;
    Y       : Byte;
    cUp     : Byte;
    cDown   : Byte;
    cLeft   : Byte;
    cRight  : Byte;
  End;

Procedure PurgeWildcard (WC: String);
Var
  D : SearchRec;
Begin
  FindFirst (WC, AnyFile, D);

  While DosError = 0 Do Begin
    If D.Attr AND Directory <> 0 Then Continue;

    FileErase (D.Name);

    FindNext(D);
  End;

  FindClose(D);
End;

Function RenameFile (Old, New: String) : Boolean;
Var
  OldF : File;
Begin
  FileErase(New);

  Assign (OldF, Old);
  {$I-} ReName (OldF, New); {$I+}

  Result := (IoResult = 0);
End;

Procedure ConvertMenuDirectory (Path: String);
Var
  Dir      : SearchRec;
  OldF     : Text;
  NewF     : Text;
  Menu     : OldMenuFlags;
  MenuCmd  : Array[1..100] of OldMenuItem;
  Cmds     : LongInt;
  FlagStr  : String[20];
  NewItem  : Array[1..100] of RecMenuItem;
  NewItems : LongInt;
  NewCmds  : LongInt;
  DoneList : TStringList;
  Count    : LongInt;
  Loop     : LongInt;

  Function FindGridJump (Mode: Byte; Loc: Word) : Word;
  Var
    TempKey  : String;
    TempLoop : Word;
  Begin
    Result := 0;

    Case Mode of
      1 : If MenuCmd[Loc].cUP    = 0 Then Exit;
      2 : If MenuCmd[Loc].cDOWN  = 0 Then Exit;
      3 : If MenuCmd[Loc].cLEFT  = 0 Then Exit;
      4 : If MenuCmd[Loc].cRIGHT = 0 Then Exit;
    End;

    // look at hotkey for jump command and then find it in new menu

    Case Mode of
      1 : TempKey := MenuCmd[MenuCmd[Loc].cUP].HotKey;
      2 : TempKey := MenuCmd[MenuCmd[Loc].cDOWN].HotKey;
      3 : TempKey := MenuCmd[MenuCmd[Loc].cLEFT].HotKey;
      4 : TempKey := MenuCmd[MenuCmd[Loc].cRIGHT].HotKey;
    End;

    For TempLoop := 1 to NewItems Do
      If NewItem[TempLoop].HotKey = TempKey Then Begin
        Result := TempLoop;
        Exit;
      End;
  End;

Begin
  Path := DirSlash(Path);

  FindFirst (Path + '*.mnu', AnyFile, Dir);

  While DosError = 0 Do Begin

    WriteLn ('Converting: ' + Dir.Name);

    If Not ReNameFile(Path + Dir.Name, Path + JustFileName(Dir.Name) + '.oldmnu') Then Begin
      WriteLn('Unable to rename menu file: ' + Dir.Name);
      Halt;
    End;

    Assign (OldF, Path + JustFileName(Dir.Name) + '.oldmnu');
    Reset  (OldF);

    Assign  (NewF, Path + Dir.Name);
    ReWrite (NewF);

    ReadLn  (OldF, Menu.Header);
    ReadLn  (OldF, Menu.Prompt);
    ReadLn  (OldF, Menu.DispCols);  //toggle
    ReadLn  (OldF, Menu.Access);
    ReadLn  (OldF, Menu.Password);
    ReadLn  (OldF, Menu.DispFile);
    ReadLn  (OldF, Menu.FallBack);
    ReadLn  (OldF, Menu.MenuType); //toggle
    ReadLn  (OldF, Menu.InputType);  //toggle
    ReadLn  (OldF, Menu.DoneX);
    ReadLn  (OldF, Menu.DoneY);
    ReadLn  (OldF, Menu.Global); //toggle

    Cmds := 0;

    While Not Eof(OldF) Do Begin
      Inc (Cmds);

      ReadLn (OldF, MenuCmd[Cmds].Text);
      ReadLn (OldF, MenuCmd[Cmds].HotKey);
      ReadLn (OldF, MenuCmd[Cmds].LongKey);
      ReadLn (OldF, MenuCmd[Cmds].Access);
      ReadLn (OldF, MenuCmd[Cmds].Command);
      ReadLn (OldF, MenuCmd[Cmds].Data);
      ReadLn (OldF, MenuCmd[Cmds].X);
      ReadLn (OldF, MenuCmd[Cmds].Y);
      ReadLn (OldF, MenuCmd[Cmds].cUP);
      ReadLn (OldF, MenuCmd[Cmds].cDOWN);
      ReadLn (OldF, MenuCmd[Cmds].cLEFT);
      ReadLn (OldF, MenuCmd[Cmds].cRIGHT);
      ReadLn (OldF, MenuCmd[Cmds].TextLo);
      ReadLn (OldF, MenuCmd[Cmds].TextHi);

      If MenuCmd[Cmds].HotKey = '' Then MenuCmd[Cmds].HotKey := MenuCmd[Cmds].LongKey;
    End;

    DoneList := TStringList.Create;
    NewItems := 0;

    FillChar (NewItem, SizeOf(NewItem), #0);

    For Count := 1 to Cmds Do Begin
      If DoneList.IndexOf(MenuCmd[Count].HotKey) <> -1 Then Continue;

      DoneList.Add(MenuCmd[Count].HotKey);

      Inc (NewItems);

      NewItem[NewItems].Hotkey  := MenuCmd[Count].HotKey;
      NewItem[NewItems].Access  := MenuCmd[Count].Access;
      NewItem[NewItems].Text    := MenuCmd[Count].Text;
      NewItem[NewItems].X       := MenuCmd[Count].X;
      NewItem[NewItems].Y       := MenuCmd[Count].Y;
      NewItem[NewItems].TextLo  := MenuCmd[Count].TextLo;
      NewItem[NewItems].TextHi  := MenuCmd[Count].TextHi;

      NewItem[NewItems].Commands := 0;

      For Loop := Count to Cmds Do
        If MenuCmd[Count].HotKey = MenuCmd[Loop].HotKey Then Begin
          If Length(MenuCmd[Loop].Command) < 2 Then Continue;

          // if lb menus check x/y/lo/hi values and assign if they were blank
          If (Menu.MenuType > 0) And ((NewItem[NewItems].TextLo = '') or (NewItem[NewItems].TextHi = '')) Then Begin
            NewItem[NewItems].X      := MenuCmd[Loop].X;
            NewItem[NewItems].Y      := MenuCmd[Loop].Y;
            NewItem[NewItems].TextLo := MenuCmd[Loop].TextLo;
            NewItem[NewItems].TextHi := MenuCmd[Loop].TextHi;
          End;

          Inc (NewItem[NewItems].Commands);

          NewCmds := NewItem[NewItems].Commands;

          New (NewItem[NewItems].CmdData[NewCmds]);

          NewItem[NewItems].CmdData[NewCmds].MenuCmd := MenuCmd[Loop].Command;
          NewItem[NewItems].CmdData[NewCmds].Access  := MenuCmd[Loop].Access;
          NewItem[NewItems].CmdData[NewCmds].Data    := MenuCmd[Loop].Data;
        End;

      NewItem[NewItems].JumpUp    := FindGridJump(1, Count);
      NewItem[NewItems].JumpDown  := FindGridJump(2, Count);
      NewItem[NewItems].JumpLeft  := FindGridJump(3, Count);
      NewItem[NewItems].JumpRight := FindGridJump(4, Count);
    End;

    DoneList.Free;

    // New engine will send header/footer for lightbar menus
    // old engine did not, so zero these out just in case

    If Menu.MenuType > 0 Then Begin
      Menu.Header := '';
      Menu.Prompt := '';
    End;

    FlagStr := strPadR(
      '0' +                         // char type
      strI2S(Menu.MenuType)  +
      strI2S(Menu.InputType) +
      strI2S(Menu.DispCols)  +
      strI2S(Menu.Global)
    , 20, '0');

    WriteLn (NewF, 'Menu description');
    WriteLn (NewF, Menu.Access);
    WriteLn (NewF, Menu.Fallback);
    WriteLn (NewF, FlagStr);
    WriteLn (NewF, '');
    WriteLn (NewF, ''); // node status
    WriteLn (NewF, Menu.Header);
    WriteLn (NewF, Menu.Prompt);
    WriteLn (NewF, Menu.DispFile);
    WriteLn (NewF, Menu.DoneX);
    WriteLn (NewF, Menu.DoneY);
    WriteLn (NewF, '');
    WriteLn (NewF, '');
    WriteLn (NewF, '');

    For Count := 1 to NewItems Do Begin
      NewItem[Count].ReDraw    := 1;
      NewItem[Count].TimerType := 0;
      NewItem[Count].ShowType  := 0;

      If (NewItem[Count].Text = '') and (Menu.MenuType = 0) Then
        NewItem[Count].ShowType := 2;

      FlagStr := strPadR(
        strI2S(NewItem[Count].ReDraw) +
        strI2S(NewItem[Count].TimerType) +
        strI2S(NewItem[Count].ShowType)
      , 20, '0');

      WriteLn (NewF, NewItem[Count].Text);
      WriteLn (NewF, NewItem[Count].TextLo);
      WriteLn (NewF, NewItem[Count].TextHi);
      WriteLn (NewF, NewItem[Count].HotKey);
      WriteLn (NewF, NewItem[Count].Access);
      WriteLn (NewF, FlagStr);
      WriteLn (NewF, NewItem[Count].Timer);
      WriteLn (NewF, NewItem[Count].X);
      WriteLn (NewF, NewItem[Count].Y);
      WriteLn (NewF, '');
      WriteLn (NewF, '');
      WriteLn (NewF, '');
      WriteLn (NewF, NewItem[Count].JumpUp);
      WriteLn (NewF, NewItem[Count].JumpDown);
      WriteLn (NewF, NewItem[Count].JumpLeft);
      WriteLn (NewF, NewItem[Count].JumpRight);
      WriteLn (NewF, NewItem[Count].JumpEscape);
      WriteLn (NewF, NewItem[Count].JumpTab);
      WriteLn (NewF, NewItem[Count].JumpPgUp);
      WriteLn (NewF, NewItem[Count].JumpPgDn);
      WriteLn (NewF, NewItem[Count].JumpHome);
      WriteLn (NewF, NewItem[Count].JumpEnd);

      WriteLn (NewF, NewItem[Count].Commands);

      For Loop := 1 to NewItem[Count].Commands Do Begin
        WriteLn (NewF, NewItem[Count].CmdData[Loop].MenuCmd);
        WriteLn (NewF, NewItem[Count].CmdData[Loop].Access);
        WriteLn (NewF, NewItem[Count].CmdData[Loop].Data);
        WriteLn (NewF, NewItem[Count].CmdData[Loop].JumpID);
        WriteLn (NewF, '');
        WriteLn (NewF, '');
      End;
    End;

    Close  (NewF);
    Close  (OldF);

    FindNext(Dir);
  End;

  FindClose(Dir);

  PurgeWildcard('*.oldmnu');
End;

Begin
  WriteLn;
  WriteLn ('Mystic BBS Menu File Converter for Mystic BBS v1.10 A15');
  WriteLn;
  WriteLn ('THIS SHOULD ONLY BE EXECUTED ONCE IN YOUR MENUS DIRECTORY!');
  WriteLn;

  ConvertMenuDirectory(JustPath(ParamStr(0)));
End.

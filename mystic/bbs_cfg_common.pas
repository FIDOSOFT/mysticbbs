Unit bbs_cfg_Common;

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

Interface

Uses
  bbs_Ansi_MenuBox;

Const
  cfgCommandList = 'Press / for command list';

Function GetCommandOption (StartY: Byte; CmdStr: String) : Char;
Function GetSortRange     (List: TAnsiMenuList; Var First, Last: Word) : Boolean;

Implementation

Uses
  m_Strings,
  m_QuickSort,
  bbs_ansi_MenuForm;

Function GetCommandOption (StartY: Byte; CmdStr: String) : Char;
Var
  Box     : TAnsiMenuBox;
  Form    : TAnsiMenuForm;
  Count   : Byte;
  Cmds    : Byte;
  CmdData : Array[1..10] of Record
              Key  : Char;
              Desc : String[18];
            End;
Begin
  Cmds := 0;

  While Pos('|', CmdStr) > 0 Do Begin
    Inc (Cmds);

    CmdData[Cmds].Key  := CmdStr[1];
    CmdData[Cmds].Desc := Copy(CmdStr, 3, Pos('|', CmdStr) - 3);

    Delete (CmdStr, 1, Pos('|', Cmdstr));
  End;

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Form.HelpSize := 0;

  Box.Open (30, StartY, 51, StartY + Cmds + 1);

  For Count := 1 to Cmds Do
    Form.AddNone (CmdData[Count].Key, ' ' + CmdData[Count].Key + ' ' + CmdData[Count].Desc, 31, StartY + Count, 31, StartY + Count, 20, '');

  Result := Form.Execute;

  Form.Free;
  Box.Close;
  Box.Free;
End;

Function GetSortRange (List: TAnsiMenuList; Var First, Last: Word) : Boolean;
Var
  Count  : Word;
  Str    : String;
  Tagged : Boolean;
Begin
  First  := 0;
  Last   := 0;
  Result := False;

  For Count := 1 to List.ListMax Do Begin
    List.Get (Count, Str, Tagged);

    If Tagged Then Begin
      If First = 0 Then First := Count Else
      If Last  > 0 Then Break;
    End Else
      If (First > 0) and (Last = 0) Then Last := Count - 1;
  End;

  If (First > 0) and (Last = 0) Then Last := List.ListMax - 1;

  If First = 0 Then Begin
    ShowMsgBox (0, 'Use TAB to tag a range first');
    Exit;
  End;

  If Last - First > mdlMaxSortSize Then Begin
    ShowMsgBox(0, 'Cannot sort more than ' + strI2S(mdlMaxSortSize) + ' items');
    Exit;
  End;

  Result := True;
End;

End.

Unit bbs_cfg_Common;

{$I M_OPS.PAS}

Interface

Const
  cfgCommandList = 'Press / for command list';

Function GetCommandOption (StartY: Byte; CmdStr: String) : Char;

Implementation

Uses
  bbs_ansi_MenuBox,
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
    Form.AddNone (CmdData[Count].Key, ' ' + CmdData[Count].Key + ' ' + CmdData[Count].Desc, 31, StartY + Count, 20, '');

  Result := Form.Execute;

  Form.Free;
  Box.Close;
  Box.Free;
End;

End.

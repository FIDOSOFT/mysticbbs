Unit bbs_cfg_SecLevel;

{$I M_OPS.PAS}

Interface

Function Configuration_SecurityEditor (Edit: Boolean) : LongInt;

Implementation

Uses
  m_Strings,
  m_FileIO,
  BBS_Records,
  BBS_DataBase,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Cfg_Common;

Procedure EditLevel (Var Sec: RecSecurity);
Var
  Box   : TAnsiMenuBox;
  Form  : TAnsiMenuForm;
  Topic : String;
Begin
  Topic := '|03(|09Security|03) |01-|09> |15';

  Box  := TAnsiMenuBox.Create;
  Form := TAnsiMenuForm.Create;

  Box.Open (12, 5, 68, 21);

  VerticalLine (35, 6, 20);

  Form.AddStr  ('D', ' Description '        , 22,  6, 37,  6, 13, 30, 30, @Sec.Desc, Topic + 'Description of security level');
  Form.AddWord ('T', ' Time Per Day '       , 21,  7, 37,  7, 14,  4,  0, 9999, @Sec.Time, Topic + 'Minutes per day');
  Form.AddWord ('C', ' Calls Per Day '      , 20,  8, 37,  8, 15,  5,  0, 65000, @Sec.MaxCalls, Topic + 'Maximum calls allowed per day');
  Form.AddWord ('P', ' Post/Call Ratio '    , 18,  9, 37,  9, 17,  5,  0, 65000, @Sec.PCRatio, Topic + 'Must post X messages per 100 calls');
  Form.AddWord ('E', ' Download Per Day '   , 17, 10, 37, 10, 18,  5,  0, 65000, @Sec.MaxDLs, Topic + 'Maximum downloads allowed per day');
  Form.AddLong ('K', ' Download KB Per Day ', 14, 11, 37, 11, 21,  7,  0, 9999999, @Sec.MaxDLk, Topic + 'Maximum downloaded kilobytes per day');
  Form.AddByte ('U', ' UL/DL Ratio '        , 22, 12, 37, 12, 13,  3,  0, 255, @Sec.DLRatio, Topic + 'Must upload 1 file for every X downloaded');
  Form.AddWord ('B', ' UL/DL KB Ratio '     , 19, 13, 37, 13, 16,  5,  0, 65000, @Sec.DLKRatio, Topic + 'Must upload 1KB for every X downloaded');
  Form.AddWord ('M', ' Max Time in Bank '   , 17, 14, 37, 14, 18,  5,  0, 65000, @Sec.MaxTB, Topic + 'Maximum minutes allowed in time bank');
  Form.AddStr  ('S', ' Start Menu '         , 23, 15, 37, 15, 12, 20, 20, @Sec.StartMenu, Topic + 'Menu name to load first when user logs in');
  Form.AddWord ('X', ' Expires '            , 26, 16, 37, 16,  9,  4,  0, 9999, @Sec.Expires, Topic + 'Number of days before level expires');
  Form.AddByte ('O', ' Expires To '         , 23, 17, 37, 17, 12,  3,  0, 255, @Sec.ExpiresTo, Topic + 'Security level to expire to');
  Form.AddFlag ('1', ' Access Flags 1 '     , 19, 18, 37, 18, 16, @Sec.AF1, Topic + 'Access flags: Set 1');
  Form.AddFlag ('2', ' Access Flags 2 '     , 19, 19, 37, 19, 16, @Sec.AF2, Topic + 'Access flags: Set 2');
  Form.AddBol  ('H', ' Hard Flag Upgrade '  , 16, 20, 37, 20, 19, 3, @Sec.Hard, Topic + 'Hard access flag upgrade?');

  Form.Execute;

  Box.Close;

  Box.Free;
  Form.Free;
End;

Function Configuration_SecurityEditor (Edit: Boolean) : LongInt;
Var
  List     : TAnsiMenuList;
  Box      : TAnsiMenuBox;
  HideMode : Boolean;
  SecFile  : File;
  Sec      : RecSecurity;

  Procedure MakeList;
  Var
    Count : LongInt;
  Begin
    List.Clear;

    ioReset(SecFile, SizeOf(RecSecurity), fmReadWrite + fmDenyNone);

    For Count := 1 to 255 Do Begin
      ioRead (SecFile, Sec);

      If Not HideMode Then
        List.Add(strPadR(strI2S(Count), 5, ' ') + Sec.Desc, 0)
      Else
        If Sec.Desc <> '' Then
          List.Add(strPadR(strI2S(Count), 5, ' ') + Sec.Desc, 0);
    End;
  End;

Var
  Count : Byte;
Begin
  HideMode := True;

  Assign (SecFile, bbsCfg.DataPath + 'security.dat');

  If Not ioReset(SecFile, SizeOf(RecSecurity), fmReadWrite + fmDenyNone) Then Begin
    ReWrite (SecFile, SizeOf(RecSecurity));
    For Count := 1 to 255 Do ioWrite (SecFile, Sec);
  End;

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Security Levels ';
  List.LoChars  := #13#27#47;
  List.NoWindow := True;
  List.SearchY  := 21;

  Box.Open (21, 5, 59, 21);

  WriteXY (23,  7, 112, 'Lvl  Description');
  WriteXY (22,  8, 112, strRep('Ä', 37));
  WriteXY (22, 19, 112, strRep('Ä', 37));
  WriteXY (29, 20, 112, cfgCommandList);

  Repeat
    MakeList;

    If HideMode and (List.ListMax = 0) Then Begin
      HideMode := False;
      MakeList;
    End;

    List.Open (21, 8, 59, 19);
    List.Close;

    Case List.ExitCode of
      '/' : Case GetCommandOption(11, 'H-Toggle Hide|') of
              'H' : HideMode := Not HideMode;
            End;
      #13 : Begin
              Count := strS2I(Copy(List.List[List.Picked]^.Name, 1, 3));

              If Edit Then Begin
                ioSeek (SecFile, Count - 1);
                ioRead (SecFile, Sec);

                EditLevel(Sec);

                ioSeek  (SecFile, Count - 1);
                ioWrite (SecFile, Sec);
              End Else Begin
                Result := Count;
                Break;
              End;
            End;
      #27 : Begin
              Result := -1;
              Break;
            End;
    End;
  Until False;

  Close (SecFile);

  Box.Close;
  Box.Free;
  List.Free;
End;

End.

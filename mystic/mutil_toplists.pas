Unit MUTIL_TopLists;

{$I M_OPS.PAS}

Interface

Procedure uTopLists;

Implementation

Uses
  m_QuickSort,
  m_Strings,
  m_FileIO,
  mUtil_Common,
  mUtil_Status,
  BBS_Records,
  BBS_DataBase;

Type
  TopListType = (TopCall, TopPost, TopDL, TopUL, TopPCR);

Var
  CreatedLists : LongInt = 0;

Function GenerateList (ListType: TopListType) : Boolean;
Var
  UserFile : File of RecUser;
  User     : RecUser;
  Sort     : TQuickSort;

  Function GetValue : Cardinal;
  Begin
    Result := 0;

    Case ListType of
      TopCall : Result := User.Calls;
      TopPost : Result := User.Posts;
      TopDL   : Result := User.DLs;
      TopUL   : Result := User.ULs;
      TopPCR  : If User.Calls > 0 Then Result  := Round(User.Posts / User.Calls * 100);
    End;
  End;

  Procedure GenerateOutput;
  Var
    InFile  : File;
    OutFile : Text;
    Buffer  : Array[1..2048] of Char;
    BufPos  : LongInt = 0;
    BufSize : LongInt = 0;
    Done    : Boolean = False;

    Function GetChar : Char;
    Begin
      If BufPos = BufSize Then Begin
        BlockRead (InFile, Buffer, SizeOf(Buffer), BufSize);

        BufPos := 0;

        If BufSize = 0 Then Begin
          Done      := True;
          Buffer[1] := #26;
        End;
      End;

      Inc (BufPos);

      Result := Buffer[BufPos];
    End;

  Var
    CfgName  : String;
    Template : String;
    OutName  : String;
    Desc     : String;
    NameLen  : Byte;
    DataLen  : Byte;
    Code     : String[2];
    CodeVal  : String[2];
    Ch       : Char;
  Begin
    Case ListType of
      TopCall : CfgName := '_call_';
      TopPost : CfgName := '_post_';
      TopDL   : CfgName := '_dl_';
      TopUL   : CfgName := '_ul_';
      TopPCR  : CfgName := '_pcr_';
    End;

    Template := INI.ReadString  (Header_TopLists, 'top' + CfgName + 'template', 'template.txt');
    OutName  := INI.ReadString  (Header_TopLists, 'top' + CfgName + 'output', 'top.asc');
    Desc     := INI.ReadString  (Header_TopLists, 'top' + CfgName + 'desc', 'None');
    NameLen  := INI.ReadInteger (Header_TopLists, 'top' + CfgName + 'namelen', 30);
    DataLen  := INI.ReadInteger (Header_TopLists, 'top' + CfgName + 'datalen', 10);

    If Not FileExist(Template) Then Begin
      ProcessStatus('Template not found', True);
      Exit;
    End;

    Inc (CreatedLists);

    Assign (InFile, Template);
    Reset  (InFile, 1);

    Assign  (OutFile, OutName);
    ReWrite (OutFile);

    While Not Done Do Begin
      Ch := GetChar;

      Case Ch of
        #26 : Break;
        '@' : Begin
                Code := GetChar;
                Code := Code + GetChar;

                If Code = 'DE' Then
                  Write (OutFile, Desc)
                Else
                If (Code = 'NA') or (Code = 'DA') Then Begin
                  CodeVal := GetChar;
                  CodeVal := CodeVal + GetChar;

                  If (CodeVal[1] in ['0'..'9']) And (CodeVal[2] in ['0'..'9']) Then Begin
                    If Sort.Data[strS2I(CodeVal)] <> NIL Then Begin
                      Seek (UserFile, Pred(Sort.Data[strS2I(CodeVal)]^.Ptr));
                      Read (UserFile, User);
                    End Else Begin
                      FillChar (User, SizeOf(User), 0);

                      User.Handle := INI.ReadString(Header_TopLists, 'no_user', 'No one');
                    End;

                    If Code = 'NA' Then
                      Write (OutFile, strPadR(User.Handle, NameLen, ' '))
                    Else
                      Write (OutFile, strPadL(strComma(GetValue), DataLen, ' '));

                  End Else
                    Write(OutFile, '@' + Code + CodeVal);

                End Else
                  Write (OutFile, '@' + Code);
              End;
      Else
        Write (OutFile, Ch);
      End;
    End;

    Close (InFile);
    Close (OutFile);
  End;

Var
  ExclFile : Text;
  ExclName : String;
  Str      : String;
  Excluded : Boolean;
  SortMode : TSortMethod;
Begin
  Result   := True;
  FileMode := 66;

  Case ListType of
    TopCall : ProcessStatus('Top Callers', False);
    TopPost : ProcessStatus('Top Posts', False);
    TopDL   : ProcessStatus('Top Downloaders', False);
    TopUL   : ProcessStatus('Top Uploaders', False);
    TopPCR  : ProcessStatus('Top Post/Call Ratio', False);
  End;

  ExclName := INI.ReadString(Header_TopLists, 'exclude_list', 'exclude.txt');

  If INI.ReadInteger(Header_TopLists, 'sort_top', 1) = 1 Then
    SortMode := qDescending
  Else
    SortMode := qAscending;

  BarOne.Reset;

  Sort := TQuickSort.Create;

  Assign (UserFile, bbsCfg.DataPath + 'users.dat');

  If ioReset(UserFile, SizeOf(RecUser), fmRWDN) Then Begin
    While Not EOF(UserFile) Do Begin
      Read (UserFile, User);

      If (User.Flags And UserDeleted <> 0) or
         (User.Flags And UserQWKNetwork <> 0) Then Continue;

      BarOne.Update(FilePos(UserFile), FileSize(UserFile));

      Excluded := False;

      Assign (ExclFile, ExclName);

      {$I-} Reset(ExclFile); {$I+}

      If IoResult = 0 Then Begin
        While Not Eof(ExclFile) Do Begin
          ReadLn(ExclFile, Str);

          Str := strUpper(strStripB(Str, ' '));

          If (Str = '') or (Str[1] = ';') Then Continue;

          If (strUpper(User.Handle) = Str) or (strUpper(User.RealName) = Str) Then Begin
            Excluded := True;

            Break;
          End;
        End;

        Close(ExclFile);
      End;

      If Not Excluded Then
        Sort.Conditional(strPadL(strI2S(GetValue), 10, '0'), FilePos(UserFile), 99, SortMode);
    End;

    Sort.Sort (1, Sort.Total, SortMode);

    GenerateOutput;

    Close (UserFile);
  End Else
    Result := False;

  BarOne.Update(100, 100);

  Sort.Free;
End;

Procedure uTopLists;
Begin
  ProcessName   ('Generating Top Lists', True);
  ProcessResult (rWORKING, False);

  If INI.ReadString(Header_TopLists, 'top_call', '0') = '1' Then GenerateList(TopCall);
  If INI.ReadString(Header_TopLists, 'top_post', '0') = '1' Then GenerateList(TopPost);
  If INI.ReadString(Header_TopLists, 'top_dl',   '0') = '1' Then GenerateList(TopDL);
  If INI.ReadString(Header_TopLists, 'top_ul',   '0') = '1' Then GenerateList(TopUL);
  If INI.ReadString(Header_TopLists, 'top_pcr',  '0') = '1' Then GenerateList(TopPCR);

  ProcessStatus ('Created |15' + strI2S(CreatedLists) + ' |07list(s)', True);
  ProcessResult (rDONE, True);
End;

End.

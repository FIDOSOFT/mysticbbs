// remove token label
// remove extra parse block?

Unit MPL_Compile;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  m_Strings,
  m_FileIO;

{$DEFINE MPLPARSER}

{$I RECORDS.PAS}
{$I MPL_TYPES.PAS}

Type
  TParserUpdateMode = (
    StatusStart,
    StatusUpdate,
    StatusInclude,
    StatusDone
  );

  TParserUpdateInfo = Record
    FileName     : String;
    FilePosition : LongInt;
    FileSize     : LongInt;
    FileLine     : LongInt;
    Percent      : Byte;
    Mode         : TParserUpdateMode;
    ErrorType    : Byte;
    ErrorText    : String;
    ErrorLine    : LongInt;
    ErrorCol     : Byte;
  End;

  TParserUpdateProc = Procedure (Mode: TParserUpdateInfo);

  TParserSourceFile = Record
    DataFile  : TFileBuffer;
    Position  : LongInt;
    PosSaved  : LongInt;
    Size      : LongInt;
    SavedInfo : TParserUpdateInfo;
  End;

  TParserVarInfoRec = Record
    Ident    : Array[1..mplMaxVarDeclare] of String[mplMaxIdentLen];
    vType    : TIdentTypes;
    ArrDem   : Byte;
    ArrStart : Array[1..mplMaxArrayDem] of LongInt;
    ArrEnd   : Array[1..mplMaxArrayDem] of LongInt;
    NumVars  : Word;
    StrLen   : Byte;
    VarSize  : LongInt;
    DataSize : LongInt;
    RecID    : Word;
  End;

  PRecordRec = ^TRecordRec;
  TRecordRec = Record
    Ident     : String[mplMaxIdentLen];
    RecID     : Word;
    Fields    : Array[1..mplMaxRecFields] of TParserVarInfoRec;
    NumFields : Word;
    DataSize  : LongInt;
  End;

  PConstRec = ^TConstRec;
  TConstRec = Record
    Ident : String[mplMaxIdentLen];
    vType : TIdentTypes;
    Data  : String;
  End;

  TParserEngine = Class
  Private
    InFile      : Array[1..mplMaxInclude] of TParserSourceFile;
    OutFile     : File;
    CurFile     : Byte;
    Ch          : Char;
    LastCharPos : LongInt;
    IdentStr    : String;
    AllowOutput : Boolean;
    GotBlock    : Boolean;
    UpdateProc  : TParserUpdateProc;
    UpdateInfo  : TParserUpdateInfo;
    VarData     : VarDataRec;
//    GotoData    : Array[1..mplMaxGotos]   of PGotoRec;
    RecData     : Array[1..mplMaxRecords] of PRecordRec;
    ConstData   : Array[1..mplMaxConsts]  of PConstRec;
    CurVarNum   : Word;
    CurGotoNum  : Word;
    CurRecNum   : Word;
    CurConstNum : Word;
    CurVarID    : Word;
    CurRecID    : Word;
    CurDepth    : LongInt;
    UsesUSER    : Boolean;
    UsesCFG     : Boolean;
    UsesMBASE   : Boolean;
    UsesMGROUP  : Boolean;
    UsesFBASE   : Boolean;
    UsesFGROUP  : Boolean;

 // LOW LEVEL PARSER FUNCTIONS
    Procedure GetChar;
    Procedure NextChar;
    Procedure PrevChar;
    Function  GetStr            (Str: String; Forced, CheckSpace: Boolean) : Boolean;
    Function  GetIdent          (Forced: Boolean) : Boolean;
    Function  GetDirective      : String;
    Function  IsEndOfLine       : Boolean;
    Function  CurFilePos        : LongInt;
    Procedure SavePosition;
    Procedure LoadPosition;
 // OUTPUT FUNCTIONS
    Procedure OutWord           (W: Word);
    Procedure OutString         (Str: String);
    Procedure OutPosition       (P: LongInt; W: Word);
 // SEARCH FUNCTIONS
    Function  FindVariable      (Str: String) : Integer;
//    Function  FindGoto          (Str: String) : Integer;
    Function  FindRecord        (Str: String) : Integer;
    Function  FindConst         (Str: String) : Integer;
    Function  FindIdent         (Str: String) : Boolean;
 // CODE PROCESSING
    Function  GetDataSize       (Info: TParserVarInfoRec) : LongInt;
    Procedure CreateVariable    (Var Info: TParserVarInfoRec);
    Function  ParseVariableInfo (Param: Boolean; IsRec: Boolean; Var Info: TParserVarInfoRec) : LongInt;
    Procedure ParseIdent;
    Procedure ParseBlock        (VarStart: Word; OneLine, CheckBlock, IsRepeat: Boolean);

    Procedure ParseVarNumber    (DoOps: Boolean);
    Procedure ParseVarString;
    Procedure ParseVarFile;
    Procedure ParseVarBoolean;
    Procedure ParseVarChar;
    Procedure ParseVarRecord;
    Procedure ParseVariable     (VT: TIdentTypes);
    Procedure ParseArray        (VN: Word; Forced: Boolean);
    Function  ParseElement      (VN: Word; TypeCheck: Boolean; VT: TIdentTypes) : TIdentTypes;
    Function  ParseElementType  (VN: Word; SkipIdent: Boolean) : TIdentTypes;

    Procedure DefineRecordType;
    Procedure DefineVariable;
    Procedure DefineConst;
//    Procedure DefineGoto;
    Procedure DefineProc;

    Procedure ExecuteProcedure (VN: Word; Res: Boolean);
    Function  SetProcResult    (VN: Word) : Boolean;

    Procedure StatementCase;
    Procedure StatementIfThenElse;
    Procedure StatementRepeatUntil;
    Procedure StatementWhileDo;
    Procedure StatementForLoop;
//    Procedure StatementGoto;
    Procedure StatementUses;

 // MISC FUNCTIONS
    Procedure OpenSourceFile    (FN: String);
    Procedure CloseSourceFile;
    Procedure UpdateStatus      (Mode: TParserUpdateMode);
    Function  GetErrorMessage   (Str: String) : String;
    Procedure Error             (ErrNum: Byte; Str: String);

    Procedure NewBooleanCrap;
  Public
    tkw     : TTokenWordType;
    tkwType : Byte;

    Constructor Create (Update: TParserUpdateProc);
    Destructor  Destroy; Override;
    Function    Compile (FN: String) : Boolean;
  End;

Implementation

{$I MPL_COMMON.PAS}

Constructor TParserEngine.Create (Update: TParserUpdateProc);
Begin
  Inherited Create;

  tkw         := wTokensPascal;
  tkwType     := 1;
  Ch          := #0;
  IdentStr    := '';
  CurVarID    := 0;
  CurRecID    := 0;
  CurFile     := 0;
  CurVarNum   := 0;
  CurGotoNum  := 0;
  CurRecNum   := 0;
  CurConstNum := 0;
  CurDepth    := 0;
  UpdateProc  := Update;
  AllowOutput := True;

  UpdateInfo.ErrorType := 0;
  UpdateInfo.ErrorText := '';

  InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 0);
End;

Destructor TParserEngine.Destroy;
Var
  Count : LongInt;
Begin
  For Count := 1 to CurVarNum  Do Dispose (VarData[Count]);
//  For Count := 1 to CurGotoNum Do Dispose (GotoData[Count]);
  For Count := 1 to CurRecNum  Do Dispose (RecData[Count]);

  CurVarNum  := 0;
  CurGotoNum := 0;
  CurRecNum  := 0;

  Inherited Destroy;
End;

Function TParserEngine.GetErrorMessage (Str: String) : String;
Begin
  Result := '';

  Case UpdateInfo.ErrorType of
    mpsEndOfFile       : Result := 'Unexpected end of file';
    mpsFileNotFound    : Result := 'File not found: '+ Str;
    mpsFileRecurse     : Result := 'Too many include files: Max ' + strI2S(mplMaxFiles);
    mpsOutputFile      : Result := 'Error writing output file: ' + Str;
    mpsExpected        : Result := 'Expected: ' + Str;
    mpsUnknownIdent    : Result := 'Unknown identifier: ' + Str;
    mpsInStatement     : Result := 'Error in statement';
    mpsIdentTooLong    : Result := 'Identifier too long: ' + Str + ' (Max ' + strI2S(mplMaxIdentLen) + ')';
    mpsExpIdentifier   : Result := 'Identifier expected';
    mpsTooManyVars     : Result := 'Too many variables: Max ' + strI2S(mplMaxVars);
    mpsDupIdent        : Result := 'Duplicate identifier: '+ Str;
    mpsOverMaxDec      : Result := 'Too many vars in statement: Max ' + strI2S(mplMaxVarDeclare);
    mpsTypeMismatch    : Result := 'Type mismatch';
    mpsSyntaxError     : Result := 'Syntax error ' + Str;
    mpsStringNotClosed : Result := 'String exceeds end of line';
    mpsStringTooLong   : Result := 'String too long: Max 255 characters';
    mpsTooManyParams   : Result := 'Too many parameters: Max ' + strI2S(mplMaxProcParams);
    mpsBadProcRef      : Result := 'Invalid procedure reference';
    mpsNumExpected     : Result := 'Numeric variable expected';
    mpsToOrDowntoExp   : Result := 'Expected TO or DOWNTO';
    mpsExpOperator     : Result := 'Operator expected';
    mpsOverArrayDim    : Result := 'Too many dimensions in array: Max ' + strI2S(mplMaxArrayDem);
    mpsNoInitArray     : Result := 'Cannot init array with value';
//    mpsTooManyGotos    : Result := 'Too many GOTO labels: Max ' + strI2S(mplMaxGotos);
    mpsDupLabel        : Result := 'Duplicate label: ' + Str;
    mpsLabelNotFound   : Result := 'Label not found: ' + Str;
    mpsFileParamVar    : Result := 'File parameters must be type FILE';
    mpsBadFunction     : Result := 'Invalid function result type';
    mpsOperation       : Result := 'Operand types do not match';
    mpsOverMaxCase     : Result := 'Too many vars in one case statement: Max ' + strI2S(mplMaxCaseNums);
    mpsTooManyFields   : Result := 'Too many fields in record: Max ' + strI2S(mplMaxRecFields);
    mpsDataTooBig      : Result := 'Structure too large: Max ' + strI2S(mplMaxDataSize) + ' bytes';
    mpsMaxConsts       : Result := 'Too many const vars: Max ' + strI2S(mplMaxConsts);
  End;
End;

Procedure TParserEngine.Error (ErrNum: Byte; Str: String);
Var
  LastLineCol : SmallInt;
Begin
  If UpdateInfo.ErrorType > 0 Then Exit;

  UpdateInfo.ErrorType := ErrNum;
  UpdateInfo.ErrorText := GetErrorMessage(Str);
  UpdateInfo.ErrorLine := 1;
  UpdateInfo.ErrorCol  := 0;

  If Assigned(InFile[CurFile].DataFile) And InFile[CurFile].DataFile.IsOpened Then Begin
    InFile[CurFile].DataFile.SeekRaw(0);

    While Not InFile[CurFile].DataFile.EOF And (InFile[CurFile].DataFile.FilePosRaw < InFile[CurFile].Position) Do Begin
      Case InFile[CurFile].DataFile.ReadChar of
        #10 : Begin
                Inc (UpdateInfo.ErrorLine);

                LastLineCol         := UpdateInfo.ErrorCol;
                UpdateInfo.ErrorCol := 0;
              End;
        #09,
        #13 : ;
      Else
        Inc (UpdateInfo.ErrorCol);
      End;
    End;
  End;

  If (UpdateInfo.ErrorCol = 0) and (UpdateInfo.ErrorLine > 1) Then Begin
    Dec (UpdateInfo.ErrorLine);

    UpdateInfo.ErrorCol := LastLineCol + 1;
  End;
End;

Function TParserEngine.CurFilePos : LongInt;
Begin
  Result := FilePos(OutFile) - mplVerLength;
End;

Function TParserEngine.FindVariable (Str: String) : Integer;
Var
  Count : LongInt;
Begin
  Result := 0;
  Count  := 1;
  Str    := strUpper(Str);

  If CurVarNum = 0 Then Exit;

  Repeat
    If strUpper(VarData[Count]^.Ident) = Str Then Begin
      Result := Count;
      Exit;
    End;

    Inc (Count);
  Until (Count > CurVarNum);
End;

Function TParserEngine.FindConst (Str: String) : Integer;
Var
  Count : LongInt;
Begin
  Result := 0;
  Count  := 1;
  Str    := strUpper(Str);

  If CurConstNum = 0 Then Exit;

  Repeat
    If strUpper(ConstData[Count]^.Ident) = Str Then Begin
      Result := Count;
      Exit;
    End;

    Inc (Count);
  Until (Count > CurConstNum);
End;

Function TParserEngine.FindIdent (Str: String) : Boolean;
Begin
  Result := (FindVariable(Str) <> 0) or (FindConst(Str) <> 0) or (FindRecord(Str) <> 0);
End;

(*
Function TParserEngine.FindGoto (Str: String) : Integer;
Var
  Count : LongInt;
Begin
  Result := 0;
  Count  := 1;
  Str    := strUpper(Str);

  If CurGotoNum = 0 Then Exit;

  Repeat
    If strUpper(GotoData[Count]^.Ident) = Str Then Begin
      Result := Count;
      Exit;
    End;

    Inc (Count);
  Until (Count > CurGotoNum);
End;
*)
Function TParserEngine.FindRecord (Str: String) : Integer;
Var
  Count : LongInt;
Begin
  Result := 0;
  Count  := 1;
  Str    := strUpper(Str);

  If CurRecNum = 0 Then Exit;

  Repeat
    If strUpper(RecData[Count]^.Ident) = Str Then Begin
      Result := Count;
      Exit;
    End;

    Inc (Count);
  Until (Count > CurRecNum);
End;

Procedure TParserEngine.OutString (Str: String);
Begin
  If (Not AllowOutput) or (UpdateInfo.ErrorType <> 0) Then Exit;

  BlockWrite (OutFile, Str[1], Byte(Str[0]));
End;

Procedure TParserEngine.OutWord (W: Word);
Begin
  If (Not AllowOutput) or (UpdateInfo.ErrorType <> 0) Then Exit;

  BlockWrite (OutFile, W, 2);
End;

Procedure TParserEngine.UpdateStatus (Mode: TParserUpdateMode);
Var
  Percent : LongInt;
Begin
  If Not Assigned(UpdateProc) Then Exit;

  UpdateInfo.Mode := Mode;

  If Mode = StatusUpdate Then Begin
    If InFile[CurFile].Size > 0 Then
      Percent := (InFile[CurFile].Position * 100) DIV InFile[CurFile].Size
    Else
      Percent := 0;

    If Percent = UpdateInfo.Percent Then Exit;

    UpdateInfo.Percent      := Percent;
    UpdateInfo.FilePosition := InFile[CurFile].Position;
    UpdateInfo.FileSize     := InFile[CurFile].Size;
  End;

  UpdateProc(UpdateInfo);
End;

Procedure TParserEngine.GetChar;
Begin
  Ch := #0;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If Not InFile[CurFile].DataFile.Eof Then Begin
    Ch := InFile[CurFile].DataFile.ReadChar;

    Inc (InFile[CurFile].Position);
  End Else
  If InFile[CurFile].DataFile.Eof and (CurFile > 1) Then Begin
    CloseSourceFile;
    UpdateInfo := InFile[CurFile].SavedInfo;
    LoadPosition;
//    GetChar; // read the } of the include ?
  End Else
    Error (mpsEndOfFile, '');

  UpdateStatus (StatusUpdate);
End;

Procedure TParserEngine.PrevChar;
Begin
  With InFile[CurFile] Do Begin
    If Position <= 1 Then Exit;

    Dec (Position);

    DataFile.SeekRaw (DataFile.FilePosRaw - 1);
  End;
End;

Function TParserEngine.IsEndOfLine : Boolean;
Begin
  Result := Ch in [#10, #13];
End;

Function TParserEngine.GetDirective : String;
Begin
  Result := '';

  Repeat
    GetChar;

    If Ch in [#10, #13, '}'] Then Break;

    Result := Result + LoCase(Ch);
  Until UpdateInfo.ErrorType <> 0;

  Result := strStripB(Result, ' ');
End;

Procedure TParserEngine.NextChar;
Var
  BlockCount : Byte;
  BlockStart : Char;
  Str        : String;
Begin
  LastCharPos := InFile[CurFile].Position;

  GetChar;

  While Not UpdateInfo.ErrorType <> 0 Do Begin
    Case Ch of
      // SKIP WHITESPACE
      #10,
      #13,
      #09,
      #32,
      #59  : {ignore};
      // SKIP SINGLE LINE COMMENTS
      // SKIP BLOCK COMMENTS
      '/',
      '('  : Begin
               BlockStart := Ch;
               BlockCount := 1;

               GetChar;

               Case Ch of
                 '/' : Repeat
                         GetChar;
                       Until IsEndOfLine or (UpdateInfo.ErrorType <> 0);
                 '*' : Repeat
                         GetChar;

                         Case Ch of
                           '*' : Begin
                                  GetChar;
                                  If ((BlockStart = '(') and (Ch = ')') or
                                     (BlockStart = '/') and (Ch = '/')) Then
                                       Dec(BlockCount);
                                 End;
                           '/',
                           '(' : If BlockStart = Ch Then Begin
                                   GetChar;

                                   If Ch = '*' Then Inc(BlockCount);
                                 End;
                         End;
                       Until (UpdateInfo.ErrorType <> 0) or (BlockCount = 0);
               Else
                 Ch := BlockStart;
                 PrevChar;
                 Exit;
               End;
             End;
      '{'  : Case tkwType of
               2 : Begin
                     GetChar;

                     If Ch = '$' Then Begin
                       If GetIdent(False) Then Begin
                         If IdentStr = 'syntax' Then Begin
                           Str := GetDirective;
                           If Str = 'pascal' Then Begin
                             tkwType := 1;
                             tkw     := wTokensPascal;
                             getchar;
                             continue;
                           End Else
                           If Str = 'iplc' Then Begin
                             tkwType := 2;
                             tkw     := wTokensIPLC;
                             getchar;
                             continue;
                           End Else
                             Error(mpsSyntaxError, '');

                           If UpdateInfo.ErrorType <> 0 Then Exit;
                         End Else
                           Error (mpsExpected, 'syntax type');
                       End Else
                         Error (mpsExpected, 'compiler directive');
                     End Else Begin
                       PrevChar;
                       Ch := '{';
                       Exit;
                     End;
                   End;
               1 : Begin
                     BlockCount := 1;

                     Repeat
                       GetChar;

                       If IsEndOfLine Then Continue;

                       Case Ch of
                         '$' : If (BlockCount = 1) And GetIdent(False) Then Begin
                                 If IdentStr = 'syntax' Then Begin
                                   Str := GetDirective;
                                   If Str = 'pascal' Then Begin
                                     tkwType := 1;
                                     tkw     := wTokensPascal;
                                     Break;
                                   End Else
                                   If Str = 'iplc' Then Begin
                                     tkwType := 2;
                                     tkw     := wTokensIPLC;
                                     Break;
                                   End Else Begin
                                     Error (mpsExpected, 'syntax type');
                                     Exit;
                                   End;
                                 End;
                               End;
                         '{' : Inc(BlockCount);
                         '}' : Dec(BlockCount);
                       End;
                     Until (UpdateInfo.ErrorType <> 0) or (BlockCount = 0);
                   End;
             End;
    Else
      Exit;
    End;

    GetChar;
  End;
End;

Function TParserEngine.GetStr (Str: String; Forced, CheckSpace: Boolean) : Boolean;
Var
  Count : Byte;
  Saved : LongInt;
Begin
  Result := False;
  Count  := 1;
  Saved  := LastCharPos;

  If Not Forced Then SavePosition;

  Repeat
    NextChar;

    If UpCase(Ch) <> UpCase(Str[Count]) Then
      If Forced Then Begin
        InFile[CurFile].Position := Saved;
        Error(mpsExpected, Str)
      End Else Begin
        LoadPosition;
        Exit;
      End;

    Inc (Count);
  Until (UpdateInfo.ErrorType <> 0) or (Count > Ord(Str[0]));

  If CheckSpace And (Count > Ord(Str[0])) Then Begin
    GetChar;

    If Not (Ch in [#09, #10, #13, #32, #46, #59]) Then Begin
      If Forced Then
        Error (mpsSyntaxError, '')
      Else Begin
        LoadPosition;
        Exit;
      End
    End Else
      PrevChar;
  End;

  Result := (UpdateInfo.ErrorType = 0);
End;

Function TParserEngine.GetIdent (Forced: Boolean) : Boolean;
Begin
  Result   := False;
  IdentStr := '';

  NextChar;

  If Not (Ch In chIdent1) Then
    If Forced Then
      Error (mpsExpIdentifier, '')
    Else
      Exit;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  While (UpdateInfo.ErrorType = 0) And (Ch in ChIdent2) Do Begin
    IdentStr := IdentStr + Ch;
    GetChar;
  End;

  PrevChar;

  If IdentStr = '' Then
    Error (mpsExpIdentifier, '');

  If Length(IdentStr) > mplMaxIdentLen Then
    Error (mpsIdentTooLong, IdentStr);

  If Forced And (FindVariable(IdentStr) = 0) Then
    Error (mpsUnknownIdent, IdentStr);

  Result := UpdateInfo.ErrorType = 0;
End;

Procedure TParserEngine.SavePosition;
Begin
  With InFile[CurFile] Do Begin
    PosSaved := DataFile.FilePosRaw + 1;
  End;
End;

Procedure TParserEngine.LoadPosition;
Begin
  With InFile[CurFile] Do Begin
    Position := PosSaved;

    DataFile.SeekRaw (Position - 1);
  End;
End;

Procedure TParserEngine.OutPosition (P: LongInt; W: Word);
Var
  SavedPos : LongInt;
Begin
  If (Not AllowOutput) or (UpdateInfo.ErrorType <> 0) Then Exit;

  SavedPos := FilePos(OutFile);
//  SavedPos := CurFilePos;

  Seek    (OutFile, P + mplVerLength);
  OutWord (W);
//  Seek    (OutFile, SavedPos + mplVerLength);
  Seek (OutFile, SavedPos);
End;

Procedure TParserEngine.ParseArray (VN: Word; Forced: Boolean);
Var
  X : Word;
Begin
  If VarData[VN]^.ArrPos > 0 Then Begin
    GetStr(tkw[wOpenArray], True, False);

    For X := 1 to VarData[VN]^.ArrPos Do Begin
      ParseVarNumber(True);

      If X < VarData[VN]^.ArrPos Then
        GetStr(tkw[wArrSep], True, False)
      Else
        GetStr(tkw[wCloseArray], True, False);
    End;
  End;
End;

Function TParserEngine.ParseElementType (VN: Word; SkipIdent: Boolean) : TIdentTypes;
Var
  Element  : String;
  Count    : Word;
  Found    : Boolean = False;
  SavedPos : LongInt;
Begin
  Result := VarData[VN]^.vType;

  If Result <> iRecord Then Exit;

  SavedPos := InFile[CurFile].DataFile.FilePosRaw;

  If SkipIdent Then GetIdent(False);

  AllowOutput := False;

  If VarData[VN]^.ArrPos > 0 Then Begin
    GetStr(tkw[wOpenArray], True, False);

    For Count := 1 to VarData[VN]^.ArrPos Do Begin
      ParseVarNumber(True);

      If Count < VarData[VN]^.ArrPos Then
        GetStr(tkw[wArrSep], True, False)
      Else
        GetStr(tkw[wCloseArray], True, False);
    End;
  End;

  AllowOutput := True;

  NextChar;

  If (Ch <> '.') Then Begin
    InFile[CurFile].DataFile.SeekRaw(SavedPos);
    Exit;
  End;

  GetIdent(False);

  Element := strUpper(IdentStr);

  For Count := 1 to RecData[VarData[VN]^.RecID]^.NumFields Do Begin
    If strUpper(RecData[VarData[VN]^.RecID]^.Fields[Count].Ident[1]) = Element Then Begin
      Found  := True;
      Result := RecData[VarData[VN]^.RecID]^.Fields[Count].vType;
    End;
  End;

  If Not Found Then
    Error (mpsUnknownIdent, '');

  InFile[CurFile].DataFile.SeekRaw(SavedPos);
End;

Function TParserEngine.ParseElement (VN: Word; TypeCheck: Boolean; VT: TIdentTypes) : TIdentTypes;
Var
  Element : String;
  Count   : Word;
  Found   : Boolean;
  Offset  : LongInt;
  X       : Word;
Begin
  Result := VarData[VN]^.vType;

  If Result <> iRecord Then Exit;

  NextChar;

  If Ch <> '.' Then Begin
    PrevChar;

    OutString (VarType2Char(iRecord));
    OutWord   (RecData[VarData[VN]^.RecID]^.DataSize);
    OutWord   (0); // offset
    OutWord   (0); // array element

    Exit;
  End;

  GetIdent(False);

  Element := strUpper(IdentStr);
  Offset  := 0;

  For Count := 1 to RecData[VarData[VN]^.RecID]^.NumFields Do Begin
    If strUpper(RecData[VarData[VN]^.RecID]^.Fields[Count].Ident[1]) = Element Then Begin
      Found  := True;
      Result := RecData[VarData[VN]^.RecID]^.Fields[Count].vType;

      OutString (VarType2Char(RecData[VarData[VN]^.RecID]^.Fields[Count].vType));

      Case RecData[VarData[VN]^.RecID]^.Fields[Count].vType of
        iString : OutWord(RecData[VarData[VN]^.RecID]^.Fields[Count].StrLen);
      Else
        OutWord (GetVarSize(RecData[VarData[VN]^.RecID]^.Fields[Count].vType));
      End;

      OutWord (Offset);
      OutWord (RecData[VarData[VN]^.RecID]^.Fields[Count].ArrDem);

      If RecData[VarData[VN]^.RecID]^.Fields[Count].ArrDem > 0 Then Begin
        GetStr(tkw[wOpenArray], True, False);

        // output if zero based here asdf asdf

        For X := 1 to RecData[VarData[VN]^.RecID]^.Fields[Count].ArrDem Do Begin

          OutWord(RecData[VarData[VN]^.RecID]^.Fields[Count].ArrStart[X]);

//          If RecData[VarData[VN]^.RecID]^.Fields[Count].ArrStart[X] = 0 Then
//            OutWord(0)
//          Else
//            OutWord(1);

          ParseVarNumber(True);

          If X < RecData[VarData[VN]^.RecID]^.Fields[Count].ArrDem Then
            GetStr(tkw[wArrSep], True, False)
          Else
            GetStr(tkw[wCloseArray], True, False);
        End;
      End;

      Break;
    End;

    Inc (Offset, RecData[VarData[VN]^.RecID]^.Fields[Count].VarSize);
  End;

  If Not Found Then
    Error (mpsUnknownIdent, '');
End;

Procedure TParserEngine.ParseVarNumber (DoOps: Boolean);
var
  IsDecimal : Boolean;
  IsLast    : Boolean;
  Found     : Boolean;
  VarNum    : LongInt;
  TempStr   : String;
begin
  IsLast   := False;
  Found    := False;

  If DoOps Then
    OutString (Char(opOpenNum));

  Repeat
    If Not IsLast Then Begin
      If GetStr(tkw[wExpAnd], False, True) Then Begin
        If Not Found Then Error(mpsInStatement, '');
        IsLast := False;
        OutString('&');
      End Else
      If GetStr(tkw[wExpOr], False, True) Then Begin
        If Not Found Then Error(mpsInStatement, '');
        IsLast := False;
        OutString('|');
      End;
      If GetStr(tkw[wExpXOr], False, True) Then Begin
        If Not Found Then Error(mpsInStatement, '');
        IsLast := False;
        OutString('@');
      End;
      If GetStr(tkw[wExpShl], False, True) Then Begin
        If Not Found Then Error(mpsInStatement, '');
        IsLast := False;
        OutString('<');
      End;
      If GetStr(tkw[wExpShr], False, True) Then Begin
        If Not Found Then Error(mpsInStatement, '');
        IsLast := False;
        OutString('>');
      End;
    End;

    NextChar;

    If Ch = tkw[wHexPrefix, 1] Then Begin
      TempStr   := '';
      IsLast    := True;
      IsDecimal := False;
      Found     := True;

      Repeat
        GetChar;
        TempStr := TempStr + Ch;
      Until Not (Ch in chHexDigit);

      Dec(TempStr[0]);

      If UpdateInfo.ErrorType = 0 Then
        OutString (strI2S(strH2I(TempStr)));
    End Else
    If Ch in chDigit Then Begin
      If IsLast Then Begin
        PrevChar;
        Break;
      End;

      IsLast    := True;
      IsDecimal := False;
      Found     := True;

      OutString (Ch);

      Repeat
        GetChar;

        If Ch = '.' Then Begin
          GetChar;
          If Ch = '.' Then Begin
            PrevChar;
            Break;
          End;

          If IsDecimal Then
            Error (mpsInStatement, '')
          Else
            IsDecimal := True;
        End;

        If Ch in chNumber Then
          OutString (Ch);
      Until (UpdateInfo.ErrorType <> 0) or (Not (Ch in chNumber));

      If UpdateInfo.ErrorType = 0 Then PrevChar;
    End Else
    If Ch in chIdent1 Then Begin
      PrevChar;

      If Not IsLast Then Begin
        Found  := True;
        IsLast := True;

        If GetIdent(False) Then Begin
          VarNum := FindConst(IdentStr);

          If VarNum > 0 Then Begin
            If Not (ConstData[VarNum]^.vType in vNums) Then
              Error (mpsTypeMismatch, '');

            OutString (ConstData[VarNum]^.Data);
          End Else Begin
            VarNum := FindVariable(IdentStr);

            If VarNum = 0 Then
              Error (mpsUnknownIdent, IdentStr)
            Else
            If Not (ParseElementType(VarNum, False) in vNums) Then
              Error (mpsTypeMismatch, '');

            If UpdateInfo.ErrorType <> 0 Then Exit;

            If VarData[VarNum]^.Proc Then
              ExecuteProcedure (VarNum, True)
            Else Begin
              OutString    (Char(opVariable));
              OutWord      (VarData[VarNum]^.VarID);
              ParseArray   (VarNum, True);
              ParseElement (VarNum, False, iLongInt);
            End;
          End;
        End Else
          Error (mpsUnknownIdent, IdentStr);
      End Else
        Break;
    End Else
    If Ch in ['%', '+', '-', '/', '*', '^'] Then Begin
      IsLast := False;
      OutString(Ch);
    End Else
    If Ch = tkw[wLeftParan, 1] Then Begin
      OutString (Char(opLeftParan));

      Self.ParseVarNumber(False);

      GetStr    (tkw[wRightParan], True, False);
      OutString (Char(opRightParan));

      Found := True;
      IsLast := True;
    End Else Begin
      PrevChar;
      Break;
    End;
  Until (UpdateInfo.ErrorType <> 0);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If Not Found Then Error (mpsInStatement, '');

  If DoOps Then
    OutString (Char(opCloseNum));
End;

Procedure TParserEngine.ParseVarChar;
Var
  Some   : Boolean;
  VarNum : Word;
  X      : String;
  Z      : Char;

  Function OutTextStr : String;
  Begin
    Result := '';

    GetStr    (tkw[wOpenString], True, False);
    OutString (Char(opOpenString));

    While UpdateInfo.ErrorType = 0 Do Begin
      GetChar;

      If IsEndOfLine Then
        Error (mpsStringNotClosed, '')
      Else
      If Ch = tkw[wCloseString, 1] Then Begin
        GetChar;
        If Ch = tkw[wCloseString, 1] Then
          Result := Result + Ch
        Else Begin
          PrevChar;
          Break;
        End;
      End Else
        Result := Result + Ch;
    End;

    If Length(Result) > 1 Then Error (mpsStringTooLong, '');

    OutString(Result[0]);
    OutString(Result);
  End;

Begin
  Some := False;

  NextChar;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If Ch = tkw[wOpenString, 1] Then Begin
    PrevChar;
    OutTextStr;
    If UpdateInfo.ErrorType = 0 Then Some := True;
  End Else
  If Ch in chIdent1 Then Begin
    PrevChar;
    If GetIdent(False) Then Begin
      VarNum := FindConst(IdentStr);

      If VarNum > 0 Then Begin
        If Not (ConstData[VarNum]^.vType in vStrings) Then
          Error (mpsTypeMismatch, '');

        OutString (Char(opOpenString));
        OutString (ConstData[VarNum]^.Data[0]);
        OutString (ConstData[VarNum]^.Data);
      End Else Begin
        VarNum := FindVariable(IdentStr);

        If VarNum = 0 Then
          Error (mpsUnknownIdent, IdentStr)
        Else
        If Not (VarData[VarNum]^.vType in vStrings) And (VarData[VarNum]^.vType <> iRecord) Then
          Error (mpsTypeMismatch, '');

        If UpdateInfo.ErrorType <> 0 Then Exit;

        If VarData[VarNum]^.Proc Then
          ExecuteProcedure(VarNum, True)
        Else Begin
          OutString    (Char(opVariable));
          OutWord      (VarData[VarNum]^.VarID);
          ParseArray   (VarNum, True);
          ParseElement (VarNum, True, iChar);
        End;
      End;

      Some := True;
    End Else
      Error (mpsUnknownIdent, IdentStr);
  End Else
    If Ch = tkw[wCharPrefix, 1] Then Begin
      X := '';

      Repeat
        GetChar;
        X := X + Ch;
      Until Not (Ch in chDigit);

      Dec(X[0]);

      If UpdateInfo.ErrorType = 0 Then Begin
        Z := Chr(strS2I(X));
        OutString (Char(opOpenString));
        OutString (#01);
        OutString (Z);
        PrevChar;
        Some := True;
      End;
    End Else
    If Ch in chDigit Then
      Error (mpsTypeMismatch, '')
    Else
      Error (mpsInStatement, '');

    If UpdateInfo.ErrorType <> 0 Then Exit;

  NextChar;

  If Ch = tkw[wOpenArray] Then Begin
    OutString (Char(opStrArray));
    ParseVarNumber(True);
    GetStr (tkw[wCloseArray], True, False);
    NextChar;
  End;

  If Ch = tkw[wStrAdd] Then Begin
    OutString (Char(opStrAdd));
    ParseVarString;
  End Else
    PrevChar;

  If Not Some Then Error (mpsInStatement, '');
End;

Procedure TParserEngine.ParseVarString;
Var
  Some   : Boolean;
  VarNum : Word;
  X      : String;
  Z      : Char;

  Function OutTextStr : String;
  Begin
    Result := '';

    GetStr    (tkw[wOpenString], True, False);
    OutString (Char(opOpenString));

    While UpdateInfo.ErrorType = 0 Do Begin
      GetChar;

      If IsEndOfLine Then
        Error (mpsStringNotClosed, '')
      Else
      If Ch = tkw[wCloseString, 1] Then Begin
        GetChar;
        If Ch = tkw[wCloseString, 1] Then
          Result := Result + Ch
        Else Begin
          PrevChar;
          Break;
        End;
      End Else
        Result := Result + Ch;
    End;

    If Length(Result) >= 255 Then Error (mpsStringTooLong, '');

    OutString(Result[0]);
    OutString(Result);
  End;

Begin
  Some := False;

  NextChar;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If Ch = tkw[wOpenString, 1] Then Begin
    PrevChar;
    OutTextStr;
    If UpdateInfo.ErrorType = 0 Then Some := True;
  End Else
  If Ch in chIdent1 Then Begin
    PrevChar;
    If GetIdent(False) Then Begin
      VarNum := FindConst(IdentStr);

      If VarNum > 0 Then Begin
        If ConstData[VarNum]^.vType <> iString Then
          Error (mpsTypeMismatch, '');

        OutString (Char(opOpenString));
        OutString (ConstData[VarNum]^.Data[0]);
        OutString (ConstData[VarNum]^.Data);
      End Else Begin
        VarNum := FindVariable(IdentStr);

        If VarNum = 0 Then
          Error (mpsUnknownIdent, IdentStr)
        Else
        If Not (ParseElementType(VarNum, False) in vStrings) Then
          Error (mpsTypeMismatch, '');

        If UpdateInfo.ErrorType <> 0 Then Exit;

        If VarData[VarNum]^.Proc Then
          ExecuteProcedure(VarNum, True)
        Else Begin
          OutString    (Char(opVariable));
          OutWord      (VarData[VarNum]^.VarID);
          ParseArray   (VarNum, True);
          ParseElement (VarNum, True, iString);
        End;
      End;

      Some := True;
    End Else
      Error (mpsUnknownIdent, IdentStr);
  End Else
    If Ch = tkw[wCharPrefix, 1] Then Begin
      X := '';

      Repeat
        GetChar;
        X := X + Ch;
      Until Not (Ch in chDigit);

      Dec(X[0]);

      If UpdateInfo.ErrorType = 0 Then Begin
        Z := Chr(strS2I(X));
        OutString (Char(opOpenString));
        OutString (#01);
        OutString (Z);
        PrevChar;
        Some := True;
      End;
    End Else
    If Ch in chDigit Then
      Error (mpsTypeMismatch, '')
    Else
      Error (mpsInStatement, '');

    If UpdateInfo.ErrorType <> 0 Then Exit;

  NextChar;

  If Ch = tkw[wOpenArray] Then Begin
    OutString (Char(opStrArray));
    ParseVarNumber(True);
    GetStr (tkw[wCloseArray], True, False);
    NextChar;
  End;

  If Ch = tkw[wStrAdd] Then Begin
    OutString (Char(opStrAdd));
    ParseVarString;
  End Else
    PrevChar;

  If Not Some Then Error (mpsInStatement, '');
End;

Procedure TParserEngine.ParseVarFile;
Var
  VarNum: Word;
Begin
  GetIdent(True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  VarNum := FindVariable(IdentStr);

  // need to create a file type parser in execute
  // so we can output the record size and support "file of records"

  If VarData[VarNum]^.vType <> iFile Then Error (mpsTypeMismatch, '');
End;

Procedure TParserEngine.ParseVarRecord;
Var
  VarNum : Word;
Begin
  GetIdent(True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  VarNum := FindVariable(IdentStr);

  If VarData[VarNum]^.vType <> iRecord Then
    Error (mpsTypeMismatch, '');

  OutWord (VarData[VarNum]^.VarID);

  ParseArray   (VarNum, True);
  ParseElement (VarNum, False, iLongInt);
  // added array and element 1.10a14 for onecard := deck[1] problem
End;

Procedure TParserEngine.NewBooleanCrap;
Var
  VarNum : Word;
Begin
  GetIdent(False);

  If strLower(IdentStr) = tkw[wTrue] Then
    OutString(Char(opTrue))
  Else
  If strLower(IdentStr) = tkw[wFalse] Then
    OutString(Char(opFalse))
  Else Begin
    VarNum := FindConst(IdentStr);

    If VarNum > 0 Then Begin
      If ConstData[VarNum]^.vType <> iBool Then
        Error(mpsTypeMismatch, '');

      Case ConstData[VarNum]^.Data[1] of
        '0' : OutString(Char(opFalse));
        '1' : OutString(Char(opTrue));
      End;
    End Else Begin
      VarNum := FindVariable(IdentStr);

      If VarNum = 0 Then
        Error (mpsUnknownIdent, IdentStr)
      Else
      If ParseElementType(VarNum, False) <> iBool Then
        Error (mpsTypeMismatch, '')
      Else
      If VarData[VarNum]^.Proc Then
        ExecuteProcedure(VarNum, True)
      Else Begin
        OutString    (Char(opVariable));
        OutWord      (VarData[VarNum]^.VarID);
        ParseArray   (VarNum, True);
        ParseElement (VarNum, True, iBool);
      End;
    End;
  End;
End;

(* MPL PROBLEM -- WIP

if ((tempint * b) > a) then
                ^

IF causes a ParseVarBoolean.
  ParseVarBoolean calls GetIdent
    GetIdent sees first ( and calls ParseVarBoolean
      ParseVarboolean calls GetIdent
        GetIdent see second ( and callse ParseVarBoolean
          ParseVarboolean calls GetIdent
            GetIdent gets identifier and calls ParseNumber
            GetIdent returns VarType NUMBER (confirm)
          ParseVarBoolean has VARTYPE1 NUMBER and ) as next char  ERROR exp OP

// maybe adding "wasrecursivenumber" check after parsenumber
// and eat the ) if it was

SOLUTION TRY 1

if ((tempint * b) > a) then
                  ^

IF causes a ParseVarBoolean.
  ParseVarBoolean calls GetIdent
    GetIdent sees first ( and calls ParseVarBoolean
      ParseVarboolean calls GetIdent
        GetIdent see second ( and callse ParseVarBoolean
          ParseVarboolean calls GetIdent
            GetIdent gets identifier and calls ParseNumber
            GetIdent returns VarType NUMBER (confirm)
          After GETIDENT, ParBarBoolean checks if Recursive and EXITs it is
        GetIdent Reads trailing ) and returns VarType BOOLEAN
      ParseVarboolean has VARTYPE1 BOOLEAN
      ParseVarboolean is recursive and exits
    GetIdent tries to read ) and gets > ERROR.

SOLUTION TRY 2 (will compile will not execute)

if ((tempint * b) > a) then

IF causes a ParseVarBoolean.
  ParseVarBoolean calls GetIdent
    GetIdent sees first ( and calls ParseVarBoolean
      ParseVarboolean calls GetIdent
        GetIdent see second ( and callse ParseVarBoolean
          ParseVarboolean calls GetIdent
            GetIdent gets identifier and calls ParseNumber
            GetIdent returns VarType NUMBER (confirm)
          After GETIDENT, ParBarBoolean checks if Recursive
            Sets ParseVarBoolean result to NUMBER and EXITs (its recursive)
        GetIdent Reads trailing ) and returns VarType NUMBER from exiting parsevar
      ParseVarboolean has VARTYPE1 NUMBER
      ParseVarboolean is recursive and exits returning NUMBER
    GetIdent sees its NOT recursive AND its not boolean and skips reading the )
  ParseVar has VARTYPE1 NUMBER
  ParseVarBoolean looks for operator does its thing
  ParseVarBoolean has a check for ) if its *has* CALLED recursive
    then it ignores it if its a number

THOUGHTS:

the deal is... MPL needs to realize its a NUMERIC variable in ( ) and not
expect the trailing ) if it is because it should know it needs a second
parameter to be a proper boolean statement
*)

Procedure TParserEngine.ParseVarBoolean;

  Procedure GetEvalIdent (Var VarType: TIdentTypes);
  Var
    VarNum: Word;
  Begin
    If GetStr(tkw[wNot], False, False) Then
      OutString(Char(opNot));

    NextChar;

    If Ch = tkw[wLeftParan] Then Begin
      OutString (Char(opLeftParan));

      ParseVarBoolean;

      OutString (Char(opRightParan));
      GetStr    (tkw[wRightParan], True, False);

      VarType := iBool;  // this is wrong if its not a bool it shouldnt be
      // a bool here.  it COULD be a math equation we dont know...
    End Else
    If Ch in chIdent1 Then Begin
      PrevChar;
      SavePosition;

      If Not GetIdent(False) Then Error (mpsUnknownIdent, IdentStr);

      LoadPosition;

      VarNum := FindConst(IdentStr);

      If VarNum > 0 Then
        VarType := ConstData[VarNum]^.vType
      Else Begin
        VarNum := FindVariable(IdentStr);

        If VarNum > 0 Then
          VarType := ParseElementType(VarNum, True) //VarData[VarNum]^.vType
        Else Begin
          IdentStr := strLower(IdentStr);

          If (IdentStr = tkw[wTrue]) or (IdentStr = tkw[wFalse]) Then
            VarType := iBool
          Else
            Error (mpsUnknownIdent, IdentStr);
        End;
      End;

      Case VarType of
        iChar     : ParseVarChar;
        iString   : ParseVarString;
        iByte,
        iShort,
        iWord,
        iInteger,
        iLongInt,
        iCardinal,
        iReal     : ParseVarNumber(True);
        iBool     : NewBooleanCrap;
      Else
        Error (mpsOperation, '');
      End;
    End Else
    If (Ch in chDigit) or (Ch = '-') Then Begin
      PrevChar;
      ParseVarNumber(True);
      VarType := iReal;
    End Else
    If Ch = tkw[wHexPrefix] Then Begin
      PrevChar;
      ParseVarNumber(True);
      VarType := iReal;
    End Else
    If Ch in [tkw[wCharPrefix, 1], tkw[wOpenString, 1]] Then Begin
      PrevChar;
      ParseVarString;
      VarType := iString;
    End Else
      Error (mpsExpIdentifier, '');
  End;

Const
  tOpNone     = 0;
  tOpEqual    = 1;
  tOpNotEqual = 2;
  tOpGreater  = 3;
  tOpLess     = 4;
  tOpEqGreat  = 5;
  tOpEqLess   = 6;

Var
  VarType1 : TIdentTypes;
  VarType2 : TIdentTypes;
  OpType   : Byte;
begin
  VarType1 := iNone;
  VarType2 := iNone;
  OpType   := tOpNone;

  GetEvalIdent (VarType1);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If GetStr(tkw[wOpEqual],    False, False) Then Begin OutString(Char(OpEqual));    OpType := topEqual; End Else
  If GetStr(tkw[wOpNotEqual], False, False) Then Begin OutString(Char(OpNotEqual)); OpType := topNotEqual; End Else
  If GetStr(tkw[wOpEqGreat],  False, False) Then Begin OutString(Char(OpEqGreat));  OpType := topEqGreat; End Else
  If GetStr(tkw[wOpEqLess],   False, False) Then Begin OutString(Char(OpEqLess));   OpType := topEqLess; End Else
  If GetStr(tkw[wOpGreater],  False, False) Then Begin OutString(Char(OpGreater));  OpType := topGreater; End Else
  If GetStr(tkw[wOpLess],     False, False) Then Begin OutString(Char(OpLess));     OpType := topLess; End Else
  If VarType1 <> iBool then Error(mpsExpOperator, '');

  If OpType <> tOpNone then begin
    GetEvalIdent(VarType2);

    If UpdateInfo.ErrorType <> 0 Then Exit;

    If ((VarType1 in vStrings) and (Not (VarType2 in vStrings))) or
       ((VarType1 = iBool) and (VarType2 <> iBool)) or
       ((VarType1 = iFile) and (VarType2 <> iFile)) or
       ((VarType1 in vNums) and (not (VarType2 in vNums))) Then
         Error(mpsTypeMismatch, '');
  End;

  If GetStr(tkw[wAnd], False, False) Then Begin
    OutString(Char(opAnd));
    ParseVarBoolean;
  End Else
  If GetStr(tkw[wOr], False, False) Then Begin
    OutString(Char(opOr));
    ParseVarBoolean;
  End;
End;

Procedure TParserEngine.ParseVariable (VT: TIdentTypes);
Begin
  If VT in vNums  Then ParseVarNumber(True) Else
  If VT = iString Then ParseVarString Else
  If VT = iChar   Then ParseVarChar Else
  If VT = iBool   Then ParseVarBoolean Else
  If VT = iRecord Then ParseVarRecord Else
  If VT = iFile   Then Error(mpsInStatement,'');

  // pointer
End;

Function TParserEngine.GetDataSize (Info: TParserVarInfoRec) : LongInt;
Var
  DimSize : LongInt;
  OneSize : LongInt;
  Count   : Byte;
Begin
  OneSize := Info.VarSize;

  If Info.ArrDem = 0 Then
    DimSize := OneSize
  Else Begin
    DimSize := (Info.ArrEnd[Info.ArrDem] - Info.ArrStart[Info.ArrDem] + 1) * OneSize;

    For Count := Pred(Info.ArrDem) DownTo 1 Do
      DimSize := DimSize * (Info.ArrEnd[Count] - Info.ArrStart[Count] + 1);
  End;

  Result := DimSize;
End;

Function TParserEngine.ParseVariableInfo (Param: Boolean; IsRec: Boolean; Var Info: TParserVarInfoRec) : LongInt;

  Function ParseNum : LongInt;
  Var
    Temp : String;
    Num  : LongInt;
  Begin
    Temp := '';

    SavePosition;

    If GetIdent(False) Then Begin
      Num := FindConst(IdentStr);

      If (Num = 0) Or Not (ConstData[Num]^.vType in vNums) Then Begin
        Error (mpsNumExpected, '');
        Exit;
      End;

      Result := strS2I(ConstData[Num]^.Data);

      Exit;
    End Else
      LoadPosition;

    Repeat
      NextChar;

      If Ch in chDigit Then
        Temp := Temp + Ch
      Else
        Break;
    Until UpdateInfo.ErrorType <> 0;

    PrevChar;

    Result := strS2I(Temp);
  End;

  Procedure ParseVarIdent;
  Var
    Count : LongInt;
  Begin
    Repeat
      If CurVarNum + Info.NumVars > mplMaxVars Then
        Error (mpsTooManyVars, '')
      Else
      If GetIdent(False) Then Begin
        If FindIdent (IdentStr) Then
          Error (mpsDupIdent, IdentStr)
        Else Begin
          For Count := 1 to Info.NumVars Do
            If strUpper(IdentStr) = strUpper(Info.Ident[Count]) Then
              Error (mpsDupIdent, IdentStr);

          If UpdateInfo.ErrorType = 0 Then Begin
            Inc (Info.NumVars);
            If Info.NumVars > mplMaxVarDeclare Then
              Error (mpsOverMaxDec, '')
            Else
              Info.Ident[Info.NumVars] := IdentStr;
          End;
        End;
      End;
    Until (UpdateInfo.ErrorType <> 0) Or (Not GetStr(tkw[wVarSep], False, False));
  End;

  Procedure ParseVarType;
  Begin
    GetIdent(False);

    If UpdateInfo.ErrorType <> 0 Then Exit;

    IdentStr := strLower(IdentStr);

    // separate function?
    If IdentStr = tkv[iString  ] Then Info.vType := iString   Else
    If IdentStr = tkv[iChar    ] Then Info.vType := iChar     Else
    If IdentStr = tkv[iByte    ] Then Info.vType := iByte     Else
    If IdentStr = tkv[iShort   ] Then Info.vType := iShort    Else
    If IdentStr = tkv[iWord    ] Then Info.vType := iWord     Else
    If IdentStr = tkv[iInteger ] Then Info.vType := iInteger  Else
    If IdentStr = tkv[iLongInt ] Then Info.vType := iLongInt  Else
    If IdentStr = tkv[iCardinal] Then Info.vType := iCardinal Else
    If IdentStr = tkv[iReal    ] Then Info.vType := iReal     Else
    If IdentStr = tkv[iBool    ] Then Info.vType := iBool     Else
    If IdentStr = tkv[iFile    ] Then Begin
      If IsRec Then Error(mpsSyntaxError, 'Cannot define file in record');
      Info.vType := iFile;
    End Else Begin
      Info.RecID := FindRecord(IdentStr);

      If Info.RecID = 0 Then
        Error(mpsUnknownIdent, IdentStr)
      Else If IsRec Then
        Error(mpsSyntaxError, 'Cannot define record in record')
      Else Begin
        Info.vType := iRecord;
      End;
    End;

    Case Info.vType of
      iString  : Begin
                   Info.StrLen := 255;

                   If Not Param Then
                     If GetStr(tkw[wOpenStrSize], False, False) Then Begin
                       Info.StrLen := ParseNum;
                       GetStr(tkw[wCloseStrSize], True, False);
                     End;

                   Info.VarSize := Info.StrLen + 1;
                 End;
      iRecord  : Info.VarSize := RecData[Info.RecID]^.DataSize;
    Else
      Info.VarSize := GetVarSize(Info.vType);
    End;

    If Info.ArrDem > 0 Then
      Info.VarSize := GetDataSize(Info);

    If Info.VarSize > mplMaxDataSize Then
      Error (mpsDataTooBig, '');
  End;

Begin
  Result := 0;

  FillChar (Info, SizeOf(Info), 0);

  Case tkwType of
    1 : Begin
          ParseVarIdent;
          GetStr(tkw[wVarSep2], True, False);

          If UpdateInfo.ErrorType <> 0 Then Exit;

          If Not Param Then
            If GetStr(tkw[wArray], False, False) Then Begin
              GetStr(tkw[wOpenArray], True, False);

              Repeat
                Inc (Info.ArrDem);

                If Info.ArrDem > mplMaxArrayDem Then Error (mpsOverArrayDim, '');

                Info.ArrStart[Info.ArrDem] := ParseNum;
                GetStr(tkw[wNumRange], True, False);
                Info.ArrEnd[Info.ArrDem] := ParseNum;
              Until (UpdateInfo.ErrorType <> 0) or (Not GetStr(tkw[wArrSep], False, False));

              GetStr(tkw[wCloseArray], True, False);
              GetStr(tkw[wCaseOf], True, False);
            End;

          If UpdateInfo.ErrorType <> 0 Then Exit;

          ParseVarType;
        End;
    2 : Begin
          ParseVarType;

          If Not Param Then
            If GetStr(tkw[wOpenArray], False, False) Then Begin
              Repeat
                Inc (Info.ArrDem);

                If Info.ArrDem > mplMaxArrayDem Then Error (mpsOverArrayDim, '');

                Info.ArrStart[Info.ArrDem] := 1;
                Info.ArrEnd  [Info.ArrDem] := ParseNum;
              Until (UpdateInfo.ErrorType <> 0) or (Not GetStr(tkw[wArrSep], False, False));

              GetStr(tkw[wCloseArray], True, False);
            End;

          ParseVarIdent;
        End;
  End;
End;

Procedure TParserEngine.DefineConst;
Begin
  If CurConstNum = mplMaxConsts Then
    Error(mpsMaxConsts, '');

  SavePosition;

  If Not GetIdent(False) Then Begin
    LoadPosition;
    Exit;
  End;

  If FindConst(IdentStr) <> 0 Then
    Error(mpsDupIdent, '');

  GetStr(tkw[wVarDef], True, False);

  Inc (CurConstNum);
  New (ConstData[CurConstNum]);

  FillChar (ConstData[CurConstNum]^, SizeOf(TConstRec), 0);

  ConstData[CurConstNum]^.Ident := IdentStr;

  If GetStr(tkw[wFalse], False, False) Then Begin
    ConstData[CurConstNum]^.vType := iBool;
    ConstData[CurConstNum]^.Data  := '0';
  End Else
  If GetStr(tkw[wTrue], False, False) Then Begin
    ConstData[CurConstNum]^.vType := iBool;
    ConstData[CurConstNum]^.Data  := '1';
  End Else
  If GetStr(tkw[wOpenString], False, False) Then Begin
    ConstData[CurConstNum]^.vType := iString;
    Repeat
      GetChar;
      If Ch = tkw[wOpenString] Then Begin
        GetChar;
        If Ch = tkw[wOpenString] Then
          ConstData[CurConstNum]^.Data := ConstData[CurConstNum]^.Data + Ch
        Else Begin
          PrevChar;
          Break;
        End;
      End Else
        ConstData[CurConstNum]^.Data := ConstData[CurConstNum]^.Data + Ch;
    Until False;
  End Else Begin
    NextChar;

    If Ch = tkw[wCharPrefix, 1] Then Begin
      ConstData[CurConstNum]^.vType := iString;
      Constdata[CurConstNum]^.Data  := '';

      Repeat
        GetChar;
        ConstData[CurConstNum]^.Data := ConstData[CurConstNum]^.Data + Ch;
      Until Not (Ch in chDigit);

      Dec(ConstData[CurConstNum]^.Data[0]);

      If UpdateInfo.ErrorType = 0 Then Begin
        ConstData[CurConstNum]^.Data := Chr(strS2I(ConstData[CurConstNum]^.Data));
        PrevChar;
      End;
    End Else
    If Ch = tkw[wHexPrefix, 1] Then Begin
      ConstData[CurConstNum]^.vType := iLongInt;
      Constdata[CurConstNum]^.Data  := '';

      Repeat
        GetChar;
        ConstData[CurConstNum]^.Data := ConstData[CurConstNum]^.Data + Ch;
      Until Not (Ch in chHexDigit);

      Dec(ConstData[CurConstNum]^.Data[0]);

      If UpdateInfo.ErrorType = 0 Then Begin
        ConstData[CurConstNum]^.Data := strI2S(strH2I(ConstData[CurConstNum]^.Data));
        PrevChar;
      End;
    End Else
    If (Ch in chNumber) or (Ch = '-') Then Begin
      While (Ch in chNumber) or (Ch = '-') Do Begin
        ConstData[CurConstNum]^.Data := ConstData[CurConstNum]^.Data + Ch;
        GetChar;
      End;
      PrevChar;

      If Pos('.', ConstData[CurConstNum]^.Data) > 0 Then
        ConstData[CurConstNum]^.vType := iReal
      Else
        ConstData[CurConstNum]^.vType := iLongInt;
    End Else
      Error(mpsInStatement, '');
  End;
End;

Procedure TParserEngine.DefineVariable;
Var
  Info : TParserVarInfoRec;
Begin
  ParseVariableInfo (False, False, Info);
  CreateVariable    (Info);
End;

Procedure TParserEngine.CreateVariable (Var Info: TParserVarInfoRec);
Var
  Count  : LongInt;
Begin
  OutString (Char(opVarDeclare));
  OutString (VarType2Char(Info.vType));

  If (Info.vType = iString) and (Info.StrLen > 0) Then
    OutString (Char(opStrSize) + Char(opOpenNum) + strI2S(Info.StrLen) + Char(opCloseNum));

  If Info.vType = iRecord Then Begin
    OutString (Char(opTypeRec));
    OutWord   (RecData[Info.RecID]^.DataSize);
  End;

  If Info.ArrDem = 0 Then
    OutString (Char(opVarNormal))
  Else Begin
    OutString (Char(opArrDef));
    OutWord   (Info.ArrDem);

    For Count := 1 to Info.ArrDem Do
      OutString (Char(opOpenNum) + strI2S(Info.ArrEnd[Count]) + Char(opCloseNum));
  End;

  OutWord (Info.NumVars);

  For Count := 1 To Info.NumVars Do Begin
    Inc (CurVarNum);
    New (VarData[CurVarNum]);

    With VarData[CurVarNum]^ Do Begin
      VarID := CurVarID;

      OutWord (CurVarID);
      Inc     (CurVarID);

      Ident     := Info.Ident[Count];
      vType     := Info.vType;
      Proc      := False;
      ArrPos    := Info.ArrDem;
      RecID     := Info.RecID;
      NumParams := 0;

      FillChar(Params, SizeOf(Params), 0);
    End;
  End;

  If GetStr(tkw[wVarDef], False, False) Then Begin
    If Info.ArrDem > 0 Then
      Error (mpsNoInitArray, '')
    Else Begin
      OutString(Char(OpEqual));
      ParseVariable(Info.vType);
    End;
  End;
End;

Procedure TParserEngine.DefineRecordType;
Var
  Ident : String;
  Info  : TParserVarInfoRec;
Begin
  GetIdent(False);

  Ident  := IdentStr;

  If FindIdent(IdentStr) Then
    Error (mpsDupIdent, IdentStr);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  GetStr(tkw[wVarDef], True, False);
  GetStr(tkv[iRecord], True, False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  Inc (CurRecNum);
  New (RecData[CurRecNum]);

  RecData[CurRecNum]^.Ident     := Ident;
  RecData[CurRecNum]^.NumFields := 0;
  RecData[CurRecNum]^.DataSize  := 0;
  RecData[CurRecNum]^.RecID     := CurRecID;

  Inc (CurRecID);

  Repeat
    Inc (RecData[CurRecNum]^.NumFields);

    If RecData[CurRecNum]^.NumFields > mplMaxRecFields Then
      Error (mpsTooManyFields, '');

    ParseVariableInfo(False, True, Info);

    RecData[CurRecNum]^.Fields[RecData[CurRecNum]^.NumFields] := Info;

    Inc (RecData[CurRecNum]^.DataSize, Info.VarSize);
  Until (UpdateInfo.ErrorType <> 0) or GetStr(tkw[wBlockClose], False, tkwType = 1);

  If RecData[CurRecNum]^.DataSize > mplMaxDataSize Then
    Error (mpsDataTooBig, '');
End;

Procedure TParserEngine.DefineProc;
Var
  Info    : TParserVarInfoRec;
  IsVar   : Boolean;
  Params  : Word;
  Count   : Word;
  ProcVar : Word;
  VarChar : Char;
  VarType : TIdentTypes;
Begin
  OutString (Char(opProcDef));

  GetIdent (False);

  If FindVariable(IdentStr) <> 0 Then
    Error (mpsDupIdent, IdentStr)
  Else
  If CurVarNum >= mplMaxVars Then
    Error (mpsTooManyVars, '');

  If UpdateInfo.ErrorType <> 0 Then Exit;

  Inc (CurVarNum);
  New (VarData[CurVarNum]);

  With VarData[CurVarNum]^ Do Begin
    VarID     := CurVarID;

    OutWord (CurVarID);
    Inc     (CurVarID);

    Ident     := IdentStr;
    vType     := iNone;
    NumParams := 0;
    Proc      := True;
    ArrPos    := 0;

    FillChar (Params, SizeOf(Params), 0);
  End;

  ProcVar := CurVarNum;
  Params  := 0;

  // GET PARAMS

  If (GetStr(tkw[wOpenParam], False, False)) And (Not GetStr(tkw[wCloseParam], False, False)) Then Begin
    Repeat
      IsVar := GetStr(tkw[wVarDeclare], False, False);

      ParseVariableInfo(True, False, Info);  // might want this true for isrec?

      If Params + Info.NumVars >= mplMaxProcParams Then
        Error (mpsTooManyParams,'');

      VarChar := VarType2Char(Info.vType);

      If Info.vType = iFile Then
        Error (mpsFileParamVar, '');

      If IsVar Then VarChar := UpCase(VarChar);

      OutString(VarChar);

      If UpdateInfo.ErrorType <> 0 Then Exit;

      OutWord (Info.NumVars);

      For Count := 1 to Info.NumVars Do Begin
        Inc (Params);
        Inc (VarData[ProcVar]^.NumParams);

        VarData[ProcVar]^.Params[Params] := VarChar;

        Inc (CurVarNum);
        New (VarData[CurVarNum]);

        With VarData[CurVarNum]^ Do Begin
           VarID := CurVarID;

           OutWord (CurVarID);
           Inc     (CurVarID);

           Ident := Info.Ident[Count];
           vType := Info.vType;

           FillChar (Params, SizeOf(Params), 0);

           NumParams := 0;
           Proc      := False;
           ArrPos    := 0;
         End;
      End;
    Until (UpdateInfo.ErrorType <> 0) Or (GetStr(tkw[wCloseParam], False, False));
  End;

  If GetStr(tkw[wFuncSpec], False, False) Then Begin
    GetIdent(False);

    IdentStr := strLower(IdentStr);

    // make this into a separate function???
    If IdentStr = tkv[iString  ] Then VarType := iString   Else
    If IdentStr = tkv[iChar    ] Then VarType := iChar     Else
    If IdentStr = tkv[iByte    ] Then VarType := iByte     Else
    If IdentStr = tkv[iShort   ] Then VarType := iShort    Else
    If IdentStr = tkv[iWord    ] Then VarType := iWord     Else
    If IdentStr = tkv[iInteger ] Then VarType := iInteger  Else
    If IdentStr = tkv[iLongInt ] Then VarType := iLongInt  Else
    If IdentStr = tkv[iCardinal] Then VarType := iCardinal Else
    If IdentStr = tkv[iReal    ] Then VarType := iReal     Else
    If IdentStr = tkv[iBool    ] Then VarType := iBool     Else
    If IdentStr = tkv[iFile    ] Then
      Error (mpsBadFunction, '')
    Else
      Error (mpsUnknownIdent, IdentStr);

    // need to support records here

    VarChar := VarType2Char(VarType);

    VarData[ProcVar]^.vType := VarType;

    OutString (Char(opProcType));
    OutString (VarChar);
  End;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  VarData[ProcVar]^.InProc := True;

  ParseBlock (CurVarNum - Params, False, False, False);

  VarData[ProcVar]^.InProc := False;
End;

Procedure TParserEngine.ExecuteProcedure (VN: Word; Res: Boolean);
Var
  Count : Byte;
  RV    : Word;
Begin
  OutString (Char(opProcExec));
  OutWord   (VarData[VN]^.VarID);

  If VarData[vn]^.NumParams > 0 Then Begin
    GetStr(tkw[wOpenParam], True, False);

    For Count := 1 to VarData[VN]^.NumParams Do Begin
      If VarData[VN]^.Params[Count] = UpCase(VarData[VN]^.Params[Count]) Then Begin
        // if its '*' then parsethevar type like below otherwise do:
        // or just check for string type and look for opstrlength

        GetIdent(True);

        If UpdateInfo.ErrorType <> 0 Then Exit;

        RV := FindVariable(IdentStr);

        If (VarData[RV]^.vType <> Char2VarType(VarData[VN]^.Params[Count])) And (VarData[VN]^.Params[Count] <> '*') Then
          Error (mpsTypeMismatch, '');

        OutWord      (VarData[RV]^.VarID);
        ParseArray   (RV, False);
        ParseElement (RV, VarData[VN]^.Params[Count] <> '*', VarData[RV]^.vType);

        // if = '*' and type iString then...do the string index
      End Else Begin
        If Char2VarType(VarData[VN]^.Params[Count]) in vNums  Then ParseVarNumber(True) Else
        If Char2VarType(VarData[VN]^.Params[Count]) = iString Then ParseVarString       Else
        If Char2VarType(VarData[VN]^.Params[Count]) = iChar   Then ParseVarChar         Else
        If Char2VarType(VarData[VN]^.Params[Count]) = iBool   Then ParseVarBoolean      Else
        If Char2VarType(VarData[VN]^.Params[Count]) = iFile   Then ParseVarFile         Else
        If Char2VarType(VarData[VN]^.Params[Count]) = iRecord Then ParseVarRecord;
      End;

      OutString(Char(opParamSep));

      If Count < VarData[VN]^.NumParams Then GetStr(tkw[wParamSep], True, False);
    End;

    GetStr(tkw[wCloseParam], True, False);
  End Else Begin
    If GetStr(tkw[wOpenParam], False, False) Then GetStr(tkw[wCloseParam], True, False);
    If Res And (VarData[VN]^.vType = iNone) Then Error (mpsBadProcRef, '');
  End;
End;

Procedure TParserEngine.StatementForLoop;
Var
  VC : Word;
Begin
  OutString (Char(opFor));
  GetIdent  (True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  VC := FindVariable(IdentStr);

  If Not (VarData[VC]^.vType in vNums) And (VarData[VC]^.vType <> iRecord) Then
    Error(mpsNumExpected, '');

  If UpdateInfo.ErrorType <> 0 Then Exit;

  OutWord      (VarData[VC]^.VarID);
  ParseArray   (VC, True);
  ParseElement (VC, True, iLongInt);
  GetStr       (tkw[wSetVar], True, False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  ParseVarNumber(True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If GetStr(tkw[wTo], False, False) Then
    OutString(Char(opTo))
  Else
  If GetStr(tkw[wDownTo], False, False) Then
    OutString(Char(opDownTo))
  Else
    Error(mpsToOrDowntoExp,'');

  If UpdateInfo.ErrorType <> 0 Then Exit;

  ParseVarNumber(True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If tkwType = 1 Then GetStr(tkw[wDo], True, False);

  If GetStr(tkw[wBlockOpen], False, False) Then
    ParseBlock(CurVarNum, False, True, False)
  Else
    ParseBlock(CurVarNum, True, False, False);
End;

Procedure TParserEngine.StatementWhileDo;
Begin
  OutString(Char(opWhile));

  ParseVarBoolean;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If tkwType = 1 Then GetStr(tkw[wDo], True, False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If GetStr(tkw[wBlockOpen], False, False) Then
    ParseBlock (CurVarNum, False, True, False)
  Else
    ParseBlock (CurVarNum, True, False, False);
End;

Procedure TParserEngine.StatementRepeatUntil;
Begin
  OutString(Char(opRepeat));

  ParseBlock(CurVarNum, False, True, True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  ParseVarBoolean;
End;

Procedure TParserEngine.StatementCase;
Var
  VarNum     : LongInt;
  SavedPos   : LongInt;
  Count      : LongInt;
  TargetType : TIdentTypes;
Begin
  OutString(Char(opCase));

  SavedPos := CurFilePos;

  OutWord(0);

  SavePosition;

  GetIdent(True);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  LoadPosition;

  VarNum := FindVariable(IdentStr);

  If VarNum = 0 Then Begin
    Error (mpsExpIdentifier, '');
    Exit;
  End;

  TargetType := VarData[VarNum]^.vType;

  If TargetType = iRecord Then
    TargetType := ParseElementType(VarNum, True);

  OutString(Char(Byte(TargetType)));

  Case TargetType of
    iString    : ParseVarString;
    iChar      : ParseVarChar;
    iBool      : ParseVarBoolean;
    iByte,
    iShort,
    iWord,
    iInteger,
    iLongInt,
    iCardinal,
    iReal      : ParseVarNumber(True);
  Else
    Error (mpsTypeMismatch, '');
  End;


(*

  If VarData[VarNum]^.vType = iString Then
    ParseVarString
  Else
  If VarData[VarNum]^.vType = iChar Then
    ParseVarChar
  Else
  If VarData[VarNum]^.vType = iBool Then
    ParseVarBoolean
  Else
  If VarData[VarNum]^.vType in vNums Then
    ParseVarNumber(True)
  Else
  If VarData[VarNum]^.vType = iRecord Then
    ParseVarRecord
  Else
    Error (mpsTypeMismatch, '');
*)

  Case tkwType of
    1 : GetStr (tkw[wCaseOf], True, False);
    2 : GetStr (tkw[wBlockOpen], True, False);
  End;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  Repeat
    Count := 1;

    NextChar;
    PrevChar;

    Case TargetType of
      iChar,
      iString: Repeat
                 ParseVarString;

                 If GetStr(tkw[wParamSep], False, False) Then
                   OutString(Char(opParamSep))
                 Else
                   Break;
               Until UpdateInfo.ErrorType <> 0;
      iByte,
      iShort,
      iWord,
      iInteger,
      iLongInt,
      iCardinal,
      iReal  : Repeat
                 ParseVarNumber(True);

                 If GetStr(tkw[wParamSep], False, False) Then
                   OutString(Char(opParamSep))
                 Else
                 If GetStr(tkw[wNumRange], False, False) Then
                   OutString(Char(opNumRange))
                 Else
                   Break;

                 Inc (Count);

                 If Count > mplMaxCaseNums Then
                   Error (mpsOverMaxCase, '');
               Until UpdateInfo.ErrorType <> 0;
      iBool  : NewBooleanCrap;
    Else
      Error (mpsTypeMismatch, '');
    End;

    GetStr(tkw[wVarSep2], True, False);

    If GetStr(tkw[wBlockOpen], False, False) Then
      ParseBlock(CurVarNum, False, True, False)
    Else
      ParseBlock(CurVarNum, True, False, False);

    If UpdateInfo.ErrorType <> 0 Then Exit;

    If GetStr(tkw[wElse], False, True) Then Begin
      OutString(Char(opElse));
      If GetStr(tkw[wBlockOpen], False, False) Then;
      ParseBlock (CurVarNum, False, True, False);
      Break;
    End Else
    If GetStr(tkw[wBlockClose], False, tkwType = 1) Then Begin
      OutString(Char(opBlockClose));
      Break;
    End;
  Until UpdateInfo.ErrorType <> 0;

  OutPosition (SavedPos, CurFilePos - SavedPos - 2);
End;

Procedure TParserEngine.StatementIfThenElse;
Begin
  OutString (Char(opIf));
  ParseVarBoolean;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If tkwType = 1 Then GetStr(tkw[wThen], True, False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  If GetStr(tkw[wBlockOpen], False, False) Then
    ParseBlock (CurVarNum, False, True, False)
  Else
    ParseBlock (CurVarNum, True, False, False);

  If GetStr(tkw[wElse], False, True) Then Begin
    OutString(Char(opElse));

    If GetStr(tkw[wBlockOpen], False, False) Then
      ParseBlock
      (CurVarNum, False, True, False)
    Else
      ParseBlock (CurVarNum, True, False, False);
  End;
End;

(*
Procedure TParserEngine.StatementGoto;
Var
  GotoNum : LongInt;
Begin
  OutString (Char(opGoto));
  GetIdent  (False);

writeln('opGoto found at depth ', curdepth);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  GotoNum := FindGoto(IdentStr);

  If GotoNum = 0 Then Begin
    If CurGotoNum >= mplMaxGotos Then
      Error (mpsTooManyGotos,'')
    Else Begin
      Inc (CurGotoNum);
      New (GotoData[CurGotoNum]);

      GotoData[CurGotoNum]^.Ident    := IdentStr;
      GotoData[CurGotoNum]^.Position := CurFilePos;
      GotoData[CurGotoNum]^.State    := 1;

      OutWord(0);
    End;
  End Else Begin
    GotoData[GotoNum]^.State := 0;

    OutWord (GotoData[GotoNum]^.Position);
  End;
End;
*)

Procedure TParserEngine.StatementUses;
Var
  GotOne : Boolean;
Begin
  // Does not output if already called
  // opUses + WordCode + [ParamSep + WordCode]

  GotOne := False;

  Repeat
    GetIdent(False);

    IdentStr := strUpper(IdentStr);

    If (IdentStr = 'FGROUP') Then Begin
      If Not UsesFGROUP Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(6);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 6);
        UsesFGROUP := True;
        GotOne     := True;
      End;
    End Else
    If (IdentStr = 'FBASE') Then Begin
      If Not UsesFBASE Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(5);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 5);
        UsesFBASE := True;
        GotOne    := True;
      End;
    End Else
    If (IdentStr = 'MGROUP') Then Begin
      If Not UsesMGROUP Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(4);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 4);
        UsesMGroup := True;
        GotOne     := True;
      End;
    End Else
    If (IdentStr = 'MBASE') Then Begin
      If Not UsesMBASE Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(3);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 3);
        UsesMBASE := True;
        GotOne    := True;
      End;
    End Else
    If (IdentStr = 'CFG') then Begin
      If Not UsesCFG Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(2);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 2);
        UsesCFG := True;
        GotOne  := True;
      End;
    End Else
    If (IdentStr = 'USER') Then Begin
      If Not UsesUSER Then Begin
        If Not GotOne Then OutString (Char(opUses));
        OutWord(1);
        InitProcedures (NIL, NIL, VarData, CurVarNum, CurVarID, 1);
        UsesUSER := True;
        GotOne   := True;
      End;
    End Else
      Error (mpsExpected, 'module type');

    If Not GotOne Then Break;

    If GetStr(tkw[wParamSep], False, False) Then
      OutString(Char(opParamSep))
    Else
      Break;
  Until UpdateInfo.ErrorType <> 0;
End;

(*
Procedure TParserEngine.DefineGoto;
Var
  GotoNum : Word;
  Temp    : LongInt;
Begin
  GetIdent(False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  GotoNum := FindGoto(IdentStr);

  If GotoNum = 0 Then Begin
    If CurGotoNum >= mplMaxGotos Then
      Error (mpsTooManyGotos, '')
    Else Begin
      Inc (CurGotoNum);
      New (GotoData[CurGotoNum]);

      GotoData[CurGotoNum]^.Ident    := IdentStr;
      GotoData[CurGotoNum]^.Position := CurFilePos;
      GotoData[CurGotoNum]^.State    := 2;
    End;
  End Else Begin
    If GotoData[GotoNum]^.State = 1 Then Begin
      GotoData[GotoNum]^.State := 0;
      Temp := CurFilePos;
      OutPosition(GotoData[GotoNum]^.Position, Temp);
      GotoData[GotoNum]^.Position := Temp;
    End Else
      Error (mpsDupLabel, GotoData[GotoNum]^.Ident);
  End;
End;
*)
Function TParserEngine.SetProcResult (VN: Word) : Boolean;
Begin
  SetProcResult := False;

  If Not VarData[vn]^.InProc Then Exit;

  If GetStr(tkw[wSetVar], False, False) Then Begin
    OutString     (Char(opSetVar));
    OutWord       (VarData[VN]^.VarID);
    ParseVariable (VarData[VN]^.vType);

    SetProcResult := True;
  End;
End;

Procedure TParserEngine.ParseIdent;
Var
  VarNum : LongInt;
  VT     : TIdentTypes;
Begin
  PrevChar;
  GetIdent(False);

  If UpdateInfo.ErrorType <> 0 Then Exit;

  VarNum := FindVariable(IdentStr);

  If VarNum = 0 Then Begin
    IdentStr := strLower(IdentStr);

// move this other stuff to main parseblock function???  and just have it
// error here if varnum = 0???

    If IdentStr = tkw[wFor]       Then StatementForLoop       Else
    If IdentStr = tkw[wIf]        Then StatementIfThenElse    Else
    If IdentStr = tkw[wWhile]     Then StatementWhileDo       Else
    If IdentStr = tkw[wRepeat]    Then StatementRepeatUntil   Else
    If IdentStr = tkw[wCaseStart] Then StatementCase          Else
//    If IdentStr = tkw[wGoto]      Then StatementGoto          Else
      Error(mpsUnknownIdent, IdentStr);
  End Else Begin
    If VarData[VarNum]^.Proc Then Begin
      If Not SetProcResult(VarNum) Then ExecuteProcedure(VarNum, False);
    End Else Begin
      OutString  (Char(opSetVar));
      OutWord    (VarData[VarNum]^.VarID);
      ParseArray (VarNum, True);

      VT := ParseElement (VarNum, False, iNone);

      GetChar;

      // prob shoud be iString check here.  also need to
      If (Ch = tkw[wOpenArray]) Then Begin
        OutString(Char(opStrArray));
        ParseVarNumber(True);
        // check here to make sure is <= string length?
        GetStr(tkw[wCloseArray], True, False);
      End Else
        PrevChar;

      If Not GetStr(tkw[wSetVar], True, False) Then Exit;

      ParseVariable(VT);
    End;
  End;
End;

Procedure TParserEngine.ParseBlock (VarStart: Word; OneLine, CheckBlock, IsRepeat: Boolean);
Var
  Count      : LongInt;
  SavedVar   : LongInt;
//  SavedGoto  : LongInt;
  SavedPos   : LongInt;
  SavedConst : LongInt;
  SavedRec   : LongInt;
  GotOpen    : Boolean;  // make parsemode var to replace all these bools
  GotVar     : Boolean;
  GotConst   : Boolean;
  IncName    : String;
Begin
  GotOpen  := CheckBlock;
  GotVar   := False;
  GotConst := False;

  If UpdateInfo.ErrorType <> 0 Then Exit;

  Inc (CurDepth);

  OutString (Char(opBlockOpen));

  SavedPos   := CurFilePos;
//  SavedGoto  := CurGotoNum;
  SavedConst := CurConstNum;
  SavedVar   := VarStart;
  SavedRec   := CurRecNum;

  OutWord(0);

  Repeat
    NextChar;
    PrevChar;

    // stupid kludge for syntax changing...
    // need to find a way to make this all a case statement... while still
    // being lazy and not rewriting all the token parsing...  that would
    // speed up parsing... but meh its only the compiler who cares lol

    If GetStr(tkw[wInclude], False, False) Then Begin
      IncName := GetDirective;

      SavePosition;

      InFile[CurFile].SavedInfo := UpdateInfo;

      OpenSourceFile(IncName);
    End Else
    If GetStr(tkw[wBlockOpen], False, False) Then Begin
      If GotOpen And Not OneLine Then Begin
//        PrevChar;
//        ParseBlock (CurVarNum, False, False, False);
        GotVar   := False;
        GotConst := False;
      End Else Begin
        GotVar   := False;
        GotConst := False;
        GotOpen  := True;
      End;
    End Else
    If GetStr(tkw[wBlockClose], False, tkwType = 1) Then Begin
      If Not GotOpen Then
        Error (mpsExpected, tkw[wBlockOpen])
      Else
        Break;
    End Else
    If GetStr(tkw[wConst], False, True) Then Begin
      If Not GotOpen Then GotConst := True;
      DefineConst;
    End Else
    If GetStr(tkw[wVarDeclare], False, True) Then Begin
      If Not GotOpen Then GotVar := True;
      DefineVariable;
    End Else
    If GetStr(tkw[wType], False, True) Then Begin
      DefineRecordType;
      GotVar   := False;
      GotConst := False;
    End Else
    If GetStr(tkw[wLabel], False, False) Then Begin
      If Not GotOpen Then Error(mpsExpected, 'begin');
//      DefineGoto;
      GotVar   := False;
      GotConst := False;
    End Else
    If GetStr(tkw[wProcDef], False, False) Then Begin
      DefineProc;
      GotVar   := False;
      GotConst := False;
    End Else
    If GetStr(tkw[wFuncDef], False, False) Then Begin
      DefineProc;
      GotVar   := False;
      GotConst := False;
    End Else
    If GetStr(tkw[wBreak], False, False) Then
      OutString(Char(opBreak))
    Else
    If GetStr(tkw[wContinue], False, True) Then
      OutString(Char(opContinue))
    Else
    If IsRepeat and (GetStr(tkw[wUntil], False, False)) Then
      Break
    Else
    If GetStr(tkw[wHalt], False, False) Then
      OutString (Char(opHalt))
    Else
    If GetStr(tkw[wExit], False, False) Then
      OutString (Char(opExit))
    Else
    If GetStr(tkw[wUses], False, False) Then Begin
      If GotBlock Then
        Error(mpsSyntaxError, 'USES must be first statement')
      Else Begin
        StatementUses;
        GotBlock := False;
        Continue;
      End;
    End Else Begin
      NextChar;

      If Ch in chIdent1 Then Begin
        If Not GotOpen And Not OneLine And Not GotVar And Not GotConst Then
          Error (mpsExpected, tkw[wBlockOpen])
        Else
          If GotVar Then Begin
            PrevChar;
            DefineVariable;
          End Else
          If GotConst Then Begin
            PrevChar;
            DefineConst;
          End Else
            ParseIdent // ONLY called from here!  could combine...
      End Else
        Error (mpsSyntaxError, '');
    End;

    GotBlock := True;
  Until (UpdateInfo.ErrorType <> 0) or OneLine;

  Dec (CurDepth);

  For Count := CurVarNum DownTo SavedVar + 1 Do
    Dispose(VarData[Count]);

  CurVarNum := SavedVar;
(*
  For Count := CurGotoNum DownTo SavedGoto + 1 Do Begin
    If GotoData[Count]^.State = 1 Then
      Error(mpsLabelNotFound, GotoData[Count]^.Ident);

    Dispose (GotoData[Count]);
  End;

  CurGotoNum := SavedGoto;
*)
  For Count := CurRecNum DownTo SavedRec + 1 Do
    Dispose (RecData[Count]);

  CurRecNum := SavedRec;

  For Count := CurConstNum DownTo SavedConst + 1 Do
    Dispose (ConstData[Count]);

  CurConstNum := SavedConst;

  OutString   (Char(opBlockClose));
  OutPosition (SavedPos, CurFilePos - SavedPos - 2);
End;

Procedure TParserEngine.OpenSourceFile (FN: String);
Begin
  UpdateInfo.FileName := FN;
  UpdateInfo.Percent  := 255;

  If CurFile = mplMaxInclude Then Begin
    Error (mpsFileRecurse, '');
    Exit;
  End Else
    Inc (CurFile);

  FillChar (InFile[CurFile], SizeOf(InFile[CurFile]), 0);

  InFile[CurFile].Position := 1;
  InFile[CurFile].PosSaved := -1;
  InFile[CurFile].Size     := 1;

  If CurFile = 1 Then
    UpdateStatus(StatusStart)
  Else
    UpdateStatus(StatusInclude);

  InFile[CurFile].DataFile := TFileBuffer.Create(8 * 1024);

  If Not InFile[CurFile].DataFile.OpenStream(FN, 1, fmOpen, fmRWDN) Then Begin
    InFile[CurFile].DataFile.Free;
    InFile[CurFile].DataFile := NIL;

    Error (mpsFileNotFound, FN);

    If CurFile > 1 Then Dec (CurFile);

    Exit;
  End;

  InFile[CurFile].Size := InFile[CurFile].DataFile.FileSizeRaw;
End;

Procedure TParserEngine.CloseSourceFile;
Begin
  InFile[CurFile].Position := InFile[CurFile].Size;

  If (UpdateInfo.ErrorType = 0) Then
    UpdateStatus(StatusUpdate);

  InFile[CurFile].DataFile.Free;
  InFile[CurFile].DataFile := NIL;

  Dec(CurFile);
End;

Function TParserEngine.Compile (FN: String) : Boolean;
Var
  VerStr : String;
  Count  : Byte;
Begin
  Result     := False;
  VerStr     := mplVersion;
  UsesUSER   := False;
  UsesCFG    := False;
  UsesMBASE  := False;
  UsesMGROUP := False;
  UsesFBASE  := False;
  UsesFGROUP := False;
  GotBlock   := False;

  Assign  (OutFile, JustFileName(FN) + mplExtExecute);
  ReWrite (OutFile, 1);

  If IoResult <> 0 Then Begin
    Error (mpsOutputFile, 'File could be in use');
    Exit;
  End;

  BlockWrite (OutFile, VerStr[1], mplVerLength);

  OpenSourceFile (JustFileName(FN) + mplExtSource);
  ParseBlock     (CurVarNum, False, False, False);

  CloseSourceFile;

  For Count := 1 to CurFile Do
    InFile[Count].DataFile.Free;

  UpdateStatus(StatusDone);

  Close (OutFile);

  If UpdateInfo.ErrorType = 0 Then
    Result := True
  Else
    Erase(OutFile);
End;

End.

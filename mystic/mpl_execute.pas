Unit MPL_Execute;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  MPL_FileIO,
  BBS_Common;

{$I MPL_TYPES.PAS}

Const
  mplExecuteBuffer = 8 * 1024;

Type
  TInterpEngine = Class
    Owner        : Pointer;
    ErrStr       : String;
    ErrNum       : Byte;
    DataFile     : PCharFile;
    CurVarNum    : Word;
    CurVarID     : Word;
    CurRecNum    : Word;
    VarData      : VarDataRec;
    RecData      : RecDataRec;
    Ch           : Char;
    W            : Word;
    IoError      : LongInt;
    ReloadMenu   : Boolean;
    DirInfo      : SearchRec;
    IdxVarDir    : Word;
    IdxVarUser   : Word;
    IdxVarMBase  : Word;
    IdxVarMGroup : Word;
    IdxVarFBase  : Word;
    IdxVarFGroup : Word;
    ParamsStr    : String;
    MPEName      : String;
    Done         : Boolean;
    ExitProc     : Boolean;
    SavedMCI     : Boolean;
    SavedGroup   : Boolean;
    SavedArrow   : Boolean;
    {$IFDEF LOGGING}
      Depth      : LongInt;
    {$ENDIF}

    Function  GetErrorMsg : String;
    Procedure Error (Err: Byte; Str: String);
    Procedure MoveToPos (Num: LongInt);
    Procedure SkipBlock;
    Function  CurFilePos : LongInt;
    Procedure NextChar;
    Procedure NextWord;
    Procedure PrevChar;
    Function  GetDataPtr   (VN: Word; Var A: TArrayInfo) : Pointer;
    Function  GetDataSize  (VarNum: Word) : Word;
    Function  FindVariable (ID: Word) : Word;
    Procedure CheckArray   (VN: Word; Var A: TArrayInfo);
    Function  GetNumber    (VN: Word; Var A: TArrayInfo) : Real;
    Function  RecastNumber (Var Num; T: TIdentTypes) : Real;

    Function  EvaluateNumber : Real;
    Function  EvaluateString : String;
    Function  EvaluateBoolean : Boolean;

    Procedure SetString   (VarNum: Word; Var A: TArrayInfo; Str: String);
    Procedure SetNumber   (VN: Word; R: Real; Var A: TArrayInfo);
    Procedure SetVariable (VarNum: Word);

    Function  DefineVariable : LongInt;
    Procedure DefineProcedure;
    Procedure DefineRecord;

    Procedure StatementRepeatUntil;
    Function  StatementIfThenElse : Byte;
    Function  StatementCase : Byte;
    Procedure StatementForLoop;
    Procedure StatementWhileDo;

    Function  ExecuteProcedure (DP: Pointer) : TIdentTypes;
    Function  ExecuteBlock     (StartVar, StartRec: Word) : Byte;

 // BBS DATA ACCESS FUNCTIONS
    Procedure FileReadLine  (Var F: File; Var Str: String);
    Procedure FileWriteLine (Var F: File; Str: String);

    Procedure GetUserVars     (Var U: RecUser);
    Function  GetUserRecord   (Num: LongInt) : Boolean;
    Procedure GetMBaseVars    (Var M: RecMessageBase);
    Function  GetMBaseRecord  (Num: LongInt) : Boolean;
    Procedure GetMGroupVars   (Var G: RecGroup);
    Function  GetMGroupRecord (Num: LongInt) : Boolean;
    Procedure GetFBaseVars    (Var F: RecFileBase);
    Function  GetFBaseRecord  (Num: LongInt) : Boolean;
    Procedure GetFGroupVars   (Var G: RecGroup);
    Function  GetFGroupRecord (Num: LongInt) : Boolean;

    Constructor Create (O: Pointer);
    Destructor  Destroy; Override;
    Function    Execute (FN: String) : Byte;

    {$IFDEF LOGGING}
    Procedure LogVarInformation (Num: LongInt);
    {$ENDIF}
  End;

Function ExecuteMPL (Owner: Pointer; Str: String) : Byte;

Implementation

Uses
  m_Bits,
  m_Strings,
  m_DateTime,
  m_Types,
  m_FileIO,
  BBS_Core,
  BBS_IO,
  BBS_General;

{$I MPL_COMMON.PAS}

{$IFDEF LOGGING}
Procedure TInterpEngine.LogVarInformation (Num: LongInt);
Begin
  Session.SystemLog('     DUMP VAR ' + strI2S(Num));

  With VarData[Num]^ Do Begin
    Session.SystemLog('           ID: ' + strI2S(VarID));
    Session.SystemLog('         Type: ' + strI2S(Ord(vType)));
    Session.SystemLog('     DataSize: ' + strI2S(DataSize));
    Session.SystemLog('      VarSize: ' + strI2S(VarSize));
    Session.SystemLog('         Kill: ' + strI2S(Ord(Kill)));

    If Data <> NIL Then
      Session.SystemLog('         Data: Assigned')
    Else
      Session.SystemLog('         Data: NIL');
  End;

//       Params    : Array[1..mplMaxProcParams] of Char;
//       NumParams : Byte;
//       pID       : Array[1..mplMaxProcParams] of Word;
//       ProcPos   : LongInt;
//       Data      : PStack;
//       ArrPos    : Byte;
//       ArrDim    : TArrayInfo;

End;
{$ENDIF}

Procedure TInterpEngine.GetUserVars (Var U: RecUser);
Begin
  Move (U.PermIdx,  VarData[IdxVarUser     ]^.Data^, SizeOf(U.PermIdx));
  Move (U.RealName, VarData[IdxVarUser + 1 ]^.Data^, SizeOf(U.RealName));
  Move (U.Handle,   VarData[IdxVarUser + 2 ]^.Data^, SizeOf(U.Handle));
  Move (U.Address,  VarData[IdxVarUser + 3 ]^.Data^, SizeOf(U.Address));
  Move (U.Security, VarData[IdxVarUser + 4 ]^.Data^, SizeOf(U.Security));
  Move (U.Gender,   VarData[IdxVarUser + 5 ]^.Data^, SizeOf(U.Gender));
  Move (U.FirstOn,  VarData[IdxVarUser + 6 ]^.Data^, SizeOf(U.FirstOn));
  Move (U.LastOn,   VarData[IdxVarUser + 7 ]^.Data^, SizeOf(U.LastOn));
  Move (U.DateType, VarData[IdxVarUser + 8 ]^.Data^, SizeOf(U.DateType));
  Move (U.Calls,    VarData[IdxVarUser + 9 ]^.Data^, SizeOf(U.Calls));
  Move (U.Password, VarData[IdxVarUser + 10]^.Data^, SizeOf(U.Password));
  Move (U.Flags,    VarData[IdxVarUser + 11]^.Data^, SizeOf(U.Flags));
End;

Function TInterpEngine.GetUserRecord (Num: LongInt) : Boolean;
Var
  F : File;
  U : RecUser;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'users.dat');
  If Not ioReset(F, SizeOf(RecUser), fmRWDN) Then Exit;

  If ioSeek(F, Pred(Num)) And (ioRead(F, U)) Then Begin
    GetUserVars(U);
    Result := True;
  End;

  Close (F);
End;

Procedure TInterpEngine.GetMBaseVars (Var M: RecMessageBase);
Begin
  Move (M.Index,    VarData[IdxVarMBase     ]^.Data^, SizeOf(M.Index));
  Move (M.Name,     VarData[IdxVarMBase + 1 ]^.Data^, SizeOf(M.Name));
  Move (M.ListACS,  VarData[IdxVarMBase + 2 ]^.Data^, SizeOf(M.ListACS));
  Move (M.ReadACS,  VarData[IdxVarMBase + 3 ]^.Data^, SizeOf(M.ReadACS));
  Move (M.PostACS,  VarData[IdxVarMBase + 4 ]^.Data^, SizeOf(M.PostACS));
  Move (M.SysopACS, VarData[IdxVarMBase + 5 ]^.Data^, SizeOf(M.SysopACS));
End;

Function TInterpEngine.GetMBaseRecord (Num: LongInt) : Boolean;
Var
  F : File;
  M : RecMessageBase;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'mbases.dat');
  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  If ioSeek(F, Num) And (ioRead(F, M)) Then Begin
    GetMBaseVars(M);
    Result := True;
  End;

  Close (F);
End;

Procedure TInterpEngine.GetMGroupVars (Var G: RecGroup);
Begin
  Move (G.Name,     VarData[IdxVarMGroup     ]^.Data^, SizeOf(G.Name));
  Move (G.ACS,      VarData[IdxVarMGroup + 1 ]^.Data^, SizeOf(G.ACS));
  Move (G.Hidden,   VarData[IdxVarMGroup + 2 ]^.Data^, SizeOf(G.Hidden));
End;

Function TInterpEngine.GetMGroupRecord (Num: LongInt) : Boolean;
Var
  F : File;
  G : RecGroup;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'groups_g.dat');
  If Not ioReset(F, SizeOf(RecGroup), fmRWDN) Then Exit;

  If ioSeek(F, Pred(Num)) And (ioRead(F, G)) Then Begin
    GetMGroupVars(G);
    Result := True;
  End;

  Close (F);
End;

Procedure TInterpEngine.GetFBaseVars (Var F: RecFileBase);
Begin
  Move (F.Name,     VarData[IdxVarFBase     ]^.Data^, SizeOf(F.Name));
  Move (F.ListACS,  VarData[IdxVarFBase + 1 ]^.Data^, SizeOf(F.ListACS));
End;

Function TInterpEngine.GetFBaseRecord (Num: LongInt) : Boolean;
Var
  F  : File;
  FB : RecFileBase;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'fbases.dat');
  If Not ioReset(F, SizeOf(RecFileBase), fmRWDN) Then Exit;

  If ioSeek(F, Pred(Num)) And (ioRead(F, FB)) Then Begin
    GetFBaseVars(FB);
    Result := True;
  End;

  Close (F);
End;

Procedure TInterpEngine.GetFGroupVars (Var G: RecGroup);
Begin
  Move (G.Name,     VarData[IdxVarFGroup     ]^.Data^, SizeOf(G.Name));
  Move (G.ACS,      VarData[IdxVarFGroup + 1 ]^.Data^, SizeOf(G.ACS));
  Move (G.Hidden,   VarData[IdxVarFGroup + 2 ]^.Data^, SizeOf(G.Hidden));
End;

Function TInterpEngine.GetFGroupRecord (Num: LongInt) : Boolean;
Var
  F : File;
  G : RecGroup;
Begin
  Result := False;

  Assign (F, Config.DataPath + 'groups_f.dat');
  If Not ioReset(F, SizeOf(RecGroup), fmRWDN) Then Exit;

  If ioSeek(F, Pred(Num)) And (ioRead(F, G)) Then Begin
    GetFGroupVars(G);
    Result := True;
  End;

  Close (F);
End;

Constructor TInterpEngine.Create (O: Pointer);
Begin
  Inherited Create;

  Owner     := O;
  ErrNum    := 0;
  ErrStr    := '';
  Ch        := #0;
  W         := 0;

  {$IFDEF LOGGING}
    Depth   := 0;
  {$ENDIF}
End;

Destructor TInterpEngine.Destroy;
Var
  Count : LongInt;
Begin
  For Count := 1 to CurVarNum Do Begin
    If (VarData[Count]^.Kill) And (VarData[Count]^.Data <> NIL) Then
      FreeMem(VarData[Count]^.Data, VarData[Count]^.DataSize);

    Dispose(VarData[Count]);
  End;

  For Count := 1 to CurRecNum Do
    Dispose(RecData[Count]);

  CurVarNum := 0;
  CurRecNum := 0;

  Inherited Destroy;
End;

Function TInterpEngine.GetErrorMsg : String;
Begin
  Result := '';

  Case ErrNum of
    mpxEndOfFile      : Result := 'Unexpected end of file';
    mpxInvalidFile    : Result := 'Invalid executable: ' + ErrStr;
    mpxVerMismatch    : Result := 'Version mismatch: ' + ErrStr + ' / ' + mplVersion;
    mpxUnknownOp      : Result := 'Unknown Token: ' + ErrStr;
    mpxMultiInit      : Result := 'Unable to initialize variable';
    mpxDivisionByZero : Result := 'Division by zero';
    mpxMathematical   : Result := 'Parsing error';
  End;
End;

Procedure TInterpEngine.Error (Err: Byte; Str: String);
Begin
  If ErrNum > 0 Then Exit;

  ErrNum := Err;
  ErrStr := Str;
End;

Procedure TInterpEngine.MoveToPos (Num: LongInt);
Begin
  DataFile^.Seek (Num + mplVerLength);
End;

Function TInterpEngine.CurFilePos : LongInt;
Begin
  Result := DataFile^.FilePos - mplVerLength;
End;

Procedure TInterpEngine.NextChar;
Begin
  Ch := DataFile^.Read;
End;

Procedure TInterpEngine.NextWord;
Var
  Res  : LongInt;
Begin
  DataFile^.BlockRead (W, 2, Res);
End;

Procedure TInterpEngine.PrevChar;
Begin
  MoveToPos (CurFilePos - 1);
End;

Function TInterpEngine.FindVariable (ID: Word) : Word;
Var
  Count : LongInt;
Begin
  Result := 0;
  Count  := CurVarNum;

  If CurVarNum = 0 Then Exit;

  Repeat
    If VarData[Count]^.VarID = ID Then Begin
      Result := Count;
      Exit;
    End;

    Dec (Count);
  Until (Count = 0);
End;

Function TInterpEngine.GetDataPtr (VN: Word; Var A: TArrayInfo) : Pointer;
Begin
  With VarData[VN]^ Do
    Case ArrPos of
      0 : Result := Data;
      1 : Result := @Data^[VarSize * (A[1] - 1) + 1];
      2 : Result := @Data^[VarSize * ((A[1] - 1) * ArrDim[2] + A[2])];
      3 : Result := @Data^[VarSize * ((A[1] - 1) * (ArrDim[2] * ArrDim[3]) + (A[2] - 1) * ArrDim[3] + A[3])];
    End;
End;

Procedure TInterpEngine.CheckArray (VN: Word; Var A: TArrayInfo);
Var
  Count : Word;
Begin
  For Count := 1 to mplMaxArrayDem Do A[Count] := 1;

  If VarData[VN]^.ArrPos = 0 Then Exit;

  For Count := 1 to VarData[VN]^.ArrPos Do
    A[Count] := Trunc(EvaluateNumber);
End;

Function TInterpEngine.GetNumber(VN: Word; Var A: TArrayInfo) : Real;
Begin
  Case VarData[VN]^.vType of
    iByte    : Result := Byte(GetDataPtr(VN, A)^);
    iShort   : Result := ShortInt(GetDataPtr(VN, A)^);
    iWord    : Result := Word(GetDataPtr(VN, A)^);
    iInteger : Result := Integer(GetDataPtr(VN, A)^);
    iLongInt : Result := LongInt(GetDataPtr(VN, A)^);
    iReal    : Result := Real(GetDataPtr(VN, A)^);
  End;
End;

Function TInterpEngine.RecastNumber (Var Num; T: TIdentTypes) : Real;
Begin
  Case T of
    iByte    : Result := Byte(Num);
    iShort   : Result := ShortInt(Num);
    iWord    : Result := Word(Num);
    iInteger : Result := Integer(Num);
    iLongInt : Result := LongInt(Num);
    iReal    : Result := Real(Num);
  End;
End;

Function TInterpEngine.EvaluateNumber : Real;
Var
  CheckChar : Char;
  VarNum    : Word;
  PowerRes  : Real;

  Procedure ParseNext;
  Begin
    NextChar;
    If Ch = Char(opCloseNum) Then CheckChar := ^M Else CheckChar := Ch;
  End;

  Function AddSubtract : Real;
  Var
    OpChar : Char;

    Function MultiplyDivide : Real;
    Var
      OpChar : Char;

      Function Power : Real;

        Function SignedOp : Real;

          Function UnsignedOp : Real;
          Var
            Start     : LongInt;
            ArrayInfo : TArrayInfo;
            NumStr    : String;
          Begin
            Case TTokenOpsRec(Byte(CheckChar)) of
              opLeftParan : Begin
                              ParseNext;
                              Result := AddSubtract;
                              ParseNext;
                            End;
              opVariable  : Begin
                              NextWord;
                              VarNum := FindVariable(w);
                              CheckArray(VarNum, ArrayInfo);
                              Result := GetNumber(VarNum, ArrayInfo);
                              ParseNext;
                            End;
              opProcExec  : Begin
                              Result := RecastNumber(Result, ExecuteProcedure(@Result));
                              ParseNext;
                            End;
            Else
              NumStr := '';

              Repeat
                NumStr := NumStr + CheckChar;
                ParseNext;
              Until Not (CheckChar in ['0'..'9', '.', 'E']);

              Val(NumStr, Result, Start);
            End;
          End;

        Begin
          If CheckChar = '-' Then Begin
            ParseNext;
            Result := -UnsignedOp;
          End Else
            Result := UnsignedOp;
        End;

      Begin
        Result := SignedOp;

        While CheckChar = '^' Do Begin
          ParseNext;
          If Result <> 0 Then
            Result := Exp(Ln(Abs(Result)) * SignedOp)
          Else
            Result := 0;
        End;
      End;

    Begin
      Result := Power;
      While CheckChar in ['%','*','/'] Do Begin
        OpChar := CheckChar;
        ParseNext;
        Case OpChar of
          '%' : Result := Trunc(Result) MOD Trunc(Power);
          '*' : Result := Result * Power;
          '/' : Begin
                  PowerRes := Power;
                  If PowerRes = 0 Then
                    Error (mpxDivisionByZero, '')
                  Else
                    Result := Result / PowerRes;
                End;
        End;
      End;
    End;

  Begin
    Result := MultiplyDivide;

    While CheckChar in ['+','-','&','|','@','<','>'] Do Begin
      OpChar := CheckChar;
      ParseNext;
      Case OpChar of
        '+' : Result := Result + MultiplyDivide;
        '-' : Result := Result - MultiplyDivide;
        '&' : Result := Trunc(Result) AND Trunc(MultiplyDivide);
        '|' : Result := Trunc(Result) OR  Trunc(MultiplyDivide);
        '@' : Result := Trunc(Result) XOR Trunc(MultiplyDivide);
        '<' : Result := Trunc(Result) SHL Trunc(MultiplyDivide);
        '>' : Result := Trunc(Result) SHR Trunc(MultiplyDivide);
      End;
    End;
  End;
Begin
  NextChar;
  ParseNext;
  Result := AddSubtract;
End;

Function TInterpEngine.EvaluateString : String;
Var
  VarNum    : Word;
  ArrayData : TArrayInfo;
  Res       : LongInt;
Begin
  Result := '';

  NextChar;

  Case TTokenOpsRec(Byte(Ch)) of
    opVariable   : Begin
                     NextWord;
                     VarNum := FindVariable(W);
                     CheckArray (VarNum, ArrayData);
                     If VarData[VarNum].vType = iChar Then Begin
                       Result[0] := #1;
                       Result[1] := Char(GetDataPtr(VarNum, ArrayData)^);
                     End Else
                       Result := String(GetDataPtr(VarNum, ArrayData)^);
                   End;
    opOpenString : Begin
                     NextChar;
                     Result[0] := Ch;
                     DataFile^.BlockRead (Result[1], Byte(Ch), Res);
                   End;
    opProcExec   : Case ExecuteProcedure(@Result) of
                     iChar : Begin // convert to string if its a char
                               Result[1] := Result[0];
                               Result[0] := #1;
                             End;
                   End;
  End;

  NextChar;

  If Ch = Char(opStrArray) Then Begin
    Result := Result[Trunc(EvaluateNumber)];
    NextChar;
  End;

  If Ch = Char(opStrAdd) Then
    Result := Result + EvaluateString
  Else
    PrevChar;
End;

Function TInterpEngine.EvaluateBoolean : Boolean;
Type
  tOp = (
    tOpNone,
    tOpEqual,
    tOpNotEqual,
    tOpGreater,
    tOpLess,
    tOpEqGreat,
    tOpEqLess
  );

Var
  VarNum    : Word;
  VarType1  : TIdentTypes;
  VarType2  : TIdentTypes;
  OpType    : tOp;
  GotA      : Boolean;
  GotB      : Boolean;
  BooleanA  : Boolean;
  BooleanB  : Boolean;
  IsNot     : Boolean;
  RealA     : Real;
  RealB     : Real;
  StringA   : String;
  StringB   : String;
  ArrayData : TArrayInfo;
Begin
// set default result?
  VarType1 := iNone;
  VarType2 := iNone;
  GotA     := False;
  GotB     := False;
  OpType   := tOpNone;
  IsNot    := False;

  Repeat
    NextChar;

// put these in numerical order...
    Case TTokenOpsRec(Byte(Ch)) of
      opLeftParan  : Begin
                       BooleanA := EvaluateBoolean;
                       VarType1 := iBool;
                       GotA     := True;
                       NextChar;
                     End;
      opVariable   : Begin
                       NextWord;
                       VarNum := FindVariable(W);
                       CheckArray(VarNum, ArrayData);
                       VarType1 := VarData[VarNum]^.vType;

                       If VarType1 = iBool Then
                         BooleanA := ByteBool(GetDataPtr(VarNum, ArrayData)^)
                       Else
                       If (VarType1 in vStrings) Then Begin
                         NextChar;
                         If Ch = Char(opStrArray) Then
                           StringA := String(GetDataPtr(VarNum, ArrayData)^)[Trunc(EvaluateNumber)]
                         Else Begin
                           PrevChar;
                           If VarData[VarNum]^.vType = iChar Then Begin
                             StringA[0] := #1;
                             StringA[1] := Char(GetDataPtr(VarNum, ArrayData)^);
                           End Else
                             StringA := String(GetDataPtr(VarNum, ArrayData)^);
                         End;
                       End Else
                       If VarType1 in vNums Then
                         RealA := GetNumber(VarNum, ArrayData);  // evalnumber here

                       GotA := True;
                     End;
      opProcExec   : Begin
                       VarType1 := ExecuteProcedure(@StringA);
                       If VarType1 = iBool Then BooleanA := Boolean(Byte(StringA[0])) else
                       If VarType1 in vNums Then RealA := RecastNumber(StringA, VarType1) else
                       if VarType1 = iChar Then Begin
                         StringA[1] := StringA[0];
                         StringA[0] := #1;
                       End;

                       GotA := True;
                     End;
      opTrue       : Begin // we can combine true/false here...
                       BooleanA := True;
                       VarType1 := iBool;
                       GotA     := True;
                     End;
      opFalse      : Begin
                       BooleanA := False;
                       VarType1 := iBool;
                       GotA     := True;
                     End;
      opOpenString : Begin
                       PrevChar;
                       StringA  := EvaluateString;
                       VarType1 := iString;
                       GotA     := True;
                     End;
      opOpenNum    : Begin
                       PrevChar;
                       RealA    := EvaluateNumber;
                       VarType1 := iReal;
                       GotA     := True;
                     End;
      opNot        : IsNot := Not IsNot;
    End;
  Until (ErrNum <> 0) or GotA;

  If ErrNum <> 0 Then Exit;

  NextChar;

  // we shouldnt even need this... just use the actual tokens...???
  Case TTokenOpsRec(Byte(Ch)) of
    opEqual    : OpType := tOpEqual;
    opNotEqual : OpType := tOpNotEqual;
    opGreater  : OpType := tOpGreater;
    opLess     : OpType := tOpLess;
    opEqGreat  : OpType := tOpEqGreat;
    opEqLess   : OpType := tOpEqLess;
  Else
    Result := BooleanA;
    PrevChar;
  End;

  If OpType <> tOpNone Then Begin
    Repeat
      NextChar;

      Case TTokenOpsRec(Byte(Ch)) of
        opLeftParan  : Begin
                         BooleanB := EvaluateBoolean;
                         VarType2 := iBool;
                         GotB     := True;
                         NextChar;
                       End;
        opVariable   : Begin
                         NextWord;
                         VarNum := FindVariable(w);
                         CheckArray (VarNum, ArrayData);
                         VarType2 := VarData[VarNum]^.vType;

                         If VarType2 = iBool Then
                           BooleanB := ByteBool(GetDataPtr(VarNum,ArrayData)^)
                         Else
                         If (VarType2 in vStrings) Then Begin
                           NextChar;
                           If Ch = Char(opStrArray) Then
                             StringB := String(GetDataPtr(VarNum, ArrayData)^)[Trunc(EvaluateNumber)]
                           Else Begin
                             PrevChar;
                             If VarData[VarNum]^.vType = iChar Then Begin
                               StringB[0] := #1;
                               StringB[1] := Char(GetDataPtr(VarNum, ArrayData)^);
                             End Else
                               StringB := String(GetDataPtr(VarNum, ArrayData)^);
                           End;
                         End Else
                         If VarType2 in vNums Then
                           RealB := GetNumber(VarNum, ArrayData);

                         GotB := True;
                       End;
        opProcExec   : Begin
                         VarType2 := ExecuteProcedure(@StringB);
                         If VarType2 = iBool Then BooleanB := Boolean(Byte(StringB[0])) Else
                         If VarType2 in vNums Then RealB := RecastNumber(StringB, VarType2) Else
                         if VarType2 = iChar Then Begin
                           StringB[1] := StringB[0];
                           StringB[0] := #1;
                         End;

                         GotB := True;
                       End;
        opTrue       : Begin
                         BooleanB := True;
                         VarType2 := iBool;
                         GotB     := True;
                       End;
        opFalse      : Begin
                         BooleanB := False;
                         VarType2 := iBool;
                         GotB     := True;
                       End;
        opOpenString : Begin
                         PrevChar;
                         StringB  := EvaluateString;
                         VarType2 := iString;
                         GotB     := True;
                       End;
        opOpenNum    : Begin
                         PrevChar;
                         RealB    := EvaluateNumber;
                         VarType2 := iReal;
                         GotB     := True;
                       End;
      End;
    Until (ErrNum <> 0) or GotB;

    If ErrNum <> 0 Then Exit;

    Result := False;

    Case OpType of
      tOpEqual    : If (VarType1 in vStrings) Then
                      Result := StringA = StringB
                    Else
                    If VarType1 = iBool Then
                      Result := BooleanA = BooleanB
                    Else
                      Result := RealA = RealB;
      tOpNotEqual : If (VarType1 in vStrings) Then Result := StringA <> StringB Else
                    If VarType1 = iBool Then Result := BooleanA <> BooleanB Else
                    Result := RealA <> RealB;
      tOpGreater  : If (VarType1 in vStrings) Then Result := StringA > StringB Else
                    If VarType1 = iBool Then Result := BooleanA > BooleanB Else
                    Result := RealA > RealB;
      tOpLess     : If (VarType1 in vStrings) Then Result := StringA < StringB Else
                    If VarType1 = iBool Then Result := BooleanA < BooleanB Else
                    Result := RealA < RealB;
      tOpEqGreat  : If (VarType1 in vStrings) Then Result := StringA >= StringB Else
                    If VarType1 = iBool Then Result := BooleanA >= BooleanB Else
                    Result := RealA >= RealB;
      tOpEqLess   : If (VarType1 in vStrings) Then Result := StringA  <= StringB Else
                    If VarType1 = iBool Then Result := BooleanA <= BooleanB Else
                    Result := RealA <= RealB;
    End;
  End;

  If IsNot Then Result := Not Result;

  NextChar;

  Case TTokenOpsRec(Byte(Ch)) of
    opAnd : Result := EvaluateBoolean And Result;
    opOr  : Result := EvaluateBoolean Or  Result;
  Else
    PrevChar;
  End;
End;

Procedure TInterpEngine.SetString (VarNum: Word; Var A: TArrayInfo; Str: String);
Begin
  If VarData[VarNum].vType = iString Then Begin
    If Ord(Str[0]) >= VarData[VarNum]^.VarSize Then
      Str[0] := Chr(VarData[VarNum]^.VarSize - 1);

    Move (Str, GetDataPtr(VarNum, A)^, VarData[VarNum]^.VarSize);
  End Else
    Move (Str[1], GetDataPtr(VarNum, A)^, 1);
End;

Procedure TInterpEngine.SetVariable (VarNum: Word);
Var
  ArrayData : TArrayInfo;
  Target    : Byte;
  TempStr   : String;
Begin
  CheckArray (VarNum, ArrayData);

  Case VarData[VarNum]^.vType of
    iChar,
    iString: Begin
               NextChar;

               If Ch = Char(opStrArray) Then Begin
                 TempStr         := String(GetDataPtr(VarNum, ArrayData)^);
                 Target          := Byte(Trunc(EvaluateNumber));
                 TempStr[Target] := EvaluateString[1];

                 SetString (VarNum, ArrayData, TempStr);
               End Else Begin
                 PrevChar;
                 SetString (VarNum, ArrayData, EvaluateString);
               End;
             End;
    iByte    : Byte(GetDataPtr(VarNum, ArrayData)^)     := Trunc(EvaluateNumber);
    iShort   : ShortInt(GetDataPtr(VarNum, ArrayData)^) := Trunc(EvaluateNumber);
    iWord    : Word(GetDataPtr(VarNum, ArrayData)^)     := Trunc(EvaluateNumber);
    iInteger : Integer(GetDataPtr(VarNum, ArrayData)^)  := Trunc(EvaluateNumber);
    iLongInt : LongInt(GetDataPtr(VarNum, ArrayData)^)  := Trunc(EvaluateNumber);
    iReal    : Real(GetDataPtr(VarNum, ArrayData)^)     := EvaluateNumber;
    iBool    : ByteBool(GetDataPtr(VarNum, ArrayData)^) := EvaluateBoolean;
  End;
End;

Procedure TInterpEngine.SetNumber (VN: Word; R: Real; Var A: TArrayInfo);
Begin
  Case VarData[VN]^.vType of
    iByte    : Byte(GetDataPtr(VN, A)^)     := Trunc(R);
    iShort   : ShortInt(GetDataPtr(VN, A)^) := Trunc(R);
    iWord    : Word(GetDataPtr(VN, A)^)     := Trunc(R);
    iInteger : Integer(GetDataPtr(VN, A)^)  := Trunc(R);
    iLongInt : LongInt(GetDataPtr(VN, A)^)  := Trunc(R);
    iReal    : Real(GetDataPtr(VN, A)^)     := R;
  end;
end;

Function TInterpEngine.GetDataSize (VarNum: Word) : Word;
Var
  Count : Word;
Begin
  With VarData[VarNum]^ Do Begin
    Result := VarSize;
    For Count := 1 To ArrPos Do
      Result := Result * ArrDim[Count];
  End;
End;

Function TInterpEngine.DefineVariable : LongInt;
Var
  VarType   : TIdentTypes;
  NumVars   : Word;
  SavedVar  : Word;
  StrSize   : Word;
  Count     : Word;
  ArrayPos  : Word;
  ArrayData : TArrayInfo;
Begin
  Result := 0;

  NextChar;

  VarType  := cVarType(Ch);

  NextChar;

  StrSize   := 256;
  ArrayPos  := 0;

  For Count := 1 To mplMaxArrayDem Do ArrayData[Count] := 1;

  If Ch = Char(opStrSize) Then Begin
    StrSize := Trunc(EvaluateNumber) + 1;
    NextChar;
  End;

  If Ch = Char(opArrDef) Then Begin
    NextWord;
    ArrayPos := W;
    For Count := 1 to ArrayPos Do ArrayData[Count] := Trunc(EvaluateNumber);
  End;

  NextWord;

  NumVars  := W;
  SavedVar := CurVarNum + 1;

  For Count := 1 to NumVars Do
    If ErrNum = 0 Then Begin
        NextWord;

        If FindVariable(W) > 0 Then Begin
          Error (mpxMultiInit, '');
          Exit;
        End;

        Inc (CurVarNum);
        New (VarData[CurVarNum]);

        With VarData[CurVarNum]^ Do Begin
          VarID     := W;
          vType     := VarType;
          NumParams := 0;
          ProcPos   := 0;

          If VarType = iString Then
            VarSize := StrSize
          Else
            VarSize := xVarSize(VarType);

          Kill      := True;
          ArrPos    := ArrayPos;
          ArrDim    := ArrayData;
          DataSize  := GetDataSize(CurVarNum);
          Result    := DataSize;

          GetMem   (Data, DataSize);
          FillChar (Data^, DataSize, 0);
        End;
    End;

  NextChar;

  If Ch = Char(OpEqual) Then Begin
    SetVariable(SavedVar);
    For Count := SavedVar + 1 To CurVarNum Do
      Move (VarData[SavedVar]^.Data^, VarData[Count]^.Data^, VarData[SavedVar]^.DataSize);
  End Else
    PrevChar;
End;

Procedure TInterpEngine.FileReadLine (Var F: File; Var Str: String);
Var
  Buf   : String;
  BR    : SmallInt;
  Count : Byte;
  SP    : LongInt;
Begin
  Str   := '';
  SP    := FilePos(F);
  Count := 1;

  BlockRead (F, Buf[1], 255, BR);

  While Count <= BR Do Begin
    Inc (SP);

    If Buf[Count] = #10 Then Break;
    If Buf[Count] <> #13 Then
      Str := Str + Buf[Count];

    If Count = 255 Then Begin
      BlockRead (F, Buf[1], 255, BR);
      Count := 0;
    End;

    Inc (Count);
  End;

  Seek (F, SP);

  IoError := IoResult;
End;

Procedure TInterpEngine.FileWriteLine (Var F: File; Str: String);
Begin
  {$IFDEF WINDOWS}
    Str := Str + #13#10;
  {$ENDIF}
  {$IFDEF UNIX}
    Str := Str + #10;
  {$ENDIF}

  BlockWrite (F, Str[1], Ord(Str[0]));

  IoError := IoResult;
End;

Function TInterpEngine.ExecuteProcedure (DP: Pointer) : TIdentTypes;
// okay... change this to:
// array[1..mplmaxprocparams] of record
//  vsize : word;
//  vdata : pointer;
// end;
// VAR passing: stores dataptr to passed variable -- DONE
// regular    : creates var and stores its pointer into vdata -- TODO
// doing this will reduce memory usage and make things even harder to
// understand.
// this stuff really needs to be cleaned up before records are fully
// added
Type
  TParamInfo = Array[1..mplMaxProcParams] of Record
//    vType : TIdentTypes;
    vSize : Word;  //do we really nede this?  can get size from vType
    vID   : Word;
    vData : PStack;
    Case TIdentTypes of // this all needs to go... push to vData
      iChar    : (C : Char);
      iString  : (S : String);
      iByte    : (B : Byte);
      iShort   : (H : ShortInt);
      iWord    : (W : Word);
      iInteger : (I : Integer);
      iLongInt : (L : LongInt);
      iReal    : (R : Real);
      iBool    : (O : Boolean);
  End;

Var
  VarNum    : Word;
  Count     : Word;
  ProcID    : Word;
  SavedVar  : Word;
  Param     : TParamInfo;
  TempStr   : String;
  TempBool  : Boolean;
  TempByte  : Byte;
  TempLong  : LongInt;
  TempChar  : Char;
  TempInt   : SmallInt;
  Sub       : LongInt;
  ArrayData : TArrayInfo;

  Procedure Store (Var Dat; Siz: Word);
  Begin
    If DP <> NIL Then Move (Dat, DP^, Siz);
  End;

Begin
// no default result value set here
  NextWord;

  ProcID := W;
  VarNum := FindVariable(ProcID);

  For Count := 1 to VarData[VarNum]^.NumParams Do Begin
    With VarData[VarNum]^ Do Begin
      If Params[Count] = UpCase(Params[Count]) Then Begin

        // its a VAR type parameter, so find the variable
        // and directly map the data pointer to the passed vars
        // data pointer

        NextWord;

        Param[Count].vID := FindVariable(W);
        CheckArray(Param[Count].vID, ArrayData);

        Param[Count].vData := GetDataPtr(Param[Count].vID, ArrayData);

        If VarData[Param[Count].vID]^.vType = iString Then
          Param[Count].vSize := VarData[Param[Count].vID]^.VarSize;
      End Else Begin
        // this should getmem dataptr and store it there instead
        // will save some memory but make calling functions below a bit more
        // of a pain in the ass
        Case Params[Count] of
          'c' : Begin
                  Param[Count].vSize := 1;
                  Param[Count].C     := EvaluateString[1];
                End;
          's' : Begin
                  Param[Count].vSize := 256;
                  Param[Count].S     := EvaluateString;
                End;
          'b' : Param[Count].B := Trunc(EvaluateNumber);
          'h' : Param[Count].H := Trunc(EvaluateNumber);
          'w' : Param[Count].W := Trunc(EvaluateNumber);
          'i' : Param[Count].I := Trunc(EvaluateNumber);
          'l' : Param[Count].L := Trunc(EvaluateNumber);
          'r' : Param[Count].R := EvaluateNumber;
          'o' : Param[Count].O := EvaluateBoolean;
        End;
      End;

      NextChar;
    End;
  End;

  Result := VarData[VarNum]^.vType;

  // this means that its a physical procedure and not a variable
  // or a predefined procedure from mpl_common.

  If VarData[VarNum]^.ProcPos > 0 Then Begin
    {$IFDEF LOGGING}
      Session.SystemLog('    Custom Proc: ' + strI2S(ProcID));
    {$ENDIF}

    Sub      := CurFilePos;
    SavedVar := CurVarNum;

    MoveToPos(VarData[VarNum]^.ProcPos);

    For Count := 1 to VarData[VarNum]^.NumParams Do Begin
      Inc (CurVarNum);
      New (VarData[CurVarNum]);

      With VarData[CurVarNum]^ Do Begin
        VarID     := VarData[VarNum]^.pID[Count];
        vType     := cVarType(VarData[VarNum]^.Params[Count]);
        NumParams := 0;
        ProcPos   := 0;
        ArrPos    := 0;

        If vType = iString Then
          VarSize := Param[Count].vSize
        Else
          VarSize := xVarSize(vType);

        DataSize := GetDataSize(CurVarNum);

        If VarData[VarNum]^.Params[Count] = UpCase(VarData[VarNum]^.Params[Count]) Then Begin
//          Data := VarData[Param[Count].vID]^.Data;
          Data := Param[Count].vData;
          Kill := False;
        End Else Begin
          GetMem (Data, DataSize);

          Case VarData[VarNum]^.Params[Count] of
            'c' : Char(Pointer(Data)^) := Param[Count].C;
            's' : Begin
                    If Ord(Param[Count].S[0]) >= VarSize Then
                      Param[Count].S[0] := Chr(VarSize - 1);

                    Move (Param[Count].S, Data^, VarSize);
                  End;
            'b' : Byte(Pointer(Data)^)     := Param[Count].B;
            'h' : ShortInt(Pointer(Data)^) := Param[Count].H;
            'w' : Word(Pointer(Data)^)     := Param[Count].W;
            'i' : Integer(Pointer(Data)^)  := Param[Count].I;
            'l' : LongInt(Pointer(Data)^)  := Param[Count].L;
            'r' : Real(Pointer(Data)^)     := Param[Count].R;
            'o' : Boolean(Pointer(Data)^)  := Param[Count].O;
          end;

          Kill := True;
        End;
      End;
    End;

    If VarData[VarNum]^.vType <> iNone Then Begin
      VarData[VarNum]^.DataSize := GetDataSize(VarNum);
      VarData[VarNum]^.Kill     := False;

      GetMem   (VarData[VarNum]^.Data,  VarData[VarNum]^.DataSize);
      FillChar (VarData[VarNum]^.Data^, VarData[VarNum]^.DataSize, 0);
    End;

    ExecuteBlock (SavedVar, CurRecNum);

    If ExitProc Then Begin
      ExitProc := False;
      Done     := False;
    End;

    If VarData[VarNum]^.vType <> iNone Then Begin
      If DP <> NIL Then  // force char into a string for DP
        if VarData[VarNum]^.vType = iChar Then Begin
          TempStr[0] := #1;
          TempStr[1] := Char(Pointer(VarData[VarNum]^.Data)^);

          Move (TempStr, DP^, 2);
        End Else
          Move (VarData[VarNum]^.Data^, DP^, VarData[VarNum]^.DataSize);

      FreeMem(VarData[VarNum]^.Data, VarData[VarNum]^.DataSize);

      VarData[VarNum]^.DataSize := 0;
    End;

    MoveToPos(Sub);

    Exit;
  End; // end of custom procedure execution

  // its not a custom procedure, its a build in proc so lets do it
  // this means that all of this param stuff will have to be redone
  // if we change it to a dataptr.  what effect will this have on
  // execution speed?

  {$IFDEF LOGGING}
    Session.SystemLog('    Internal Proc: ' + strI2S(ProcID));
  {$ENDIF}

  Case ProcID of
    0   : Session.io.OutFull(Param[1].S);
    1   : Session.io.OutFullLn(Param[1].S);
    2   : Session.io.AnsiClear;
    3   : Session.io.AnsiClrEOL;
    4   : Session.io.AnsiGotoXY(Param[1].B, Param[2].B);
    5   : Begin
            TempByte := Screen.CursorX;
            Store(TempByte, 1);
          End;
    6   : Begin
            TempByte := Screen.CursorY;
            Store(TempByte, 1);
          End;
    7   : Begin
            TempStr := Session.io.GetKey;
            Store(TempStr, 256);
          End;
    8   : Begin
            Session.io.BufFlush;
            WaitMS(Param[1].L);
          End;
    9   : Begin
            TempLong := Random(Param[1].L);
            Store (TempLong, 4);
          End;
    10  : Begin
            TempChar := Chr(Param[1].B);
            Store (TempChar, 1);
          End;
    11  : Begin
            TempByte := Ord(Param[1].S[1]);
            Store (TempByte, 1);
          End;
    12  : Begin
            TempStr := Copy(Param[1].S, Param[2].L, Param[3].L);
            Store (TempStr, 256);
          End;
    13  : Delete(String(Pointer(Param[1].vData)^), Param[2].L, Param[3].L);
    14  : Insert(Param[1].S, String(Pointer(Param[2].vData)^), Param[3].L);
    15  : Begin
            TempLong := Length(Param[1].S);
            Store (TempLong, 4);
          End;
    16  : Begin
            TempBool := Odd(Param[1].L);
            Store (TempBool, 1);
          End;
    17  : Begin
            TempLong := Pos(Param[1].S, Param[2].S);
            Store (TempLong, 4);
          End;
    18  : Begin
            {$IFDEF UNIX}
              TempBool := Input.KeyPressed;
            {$ELSE}
              TempBool := Input.KeyPressed OR Session.Client.DataWaiting;
            {$ENDIF}
            Store (TempBool, 1);
            Session.io.BufFlush;
          End;
    19  : Begin
            TempStr := strPadR(Param[1].S, Param[2].B, Param[3].S[1]);
            Store (TempStr, 256);
          End;
    20  : Begin
            TempStr := strPadL(Param[1].S, Param[2].B, Param[3].S[1]);
            Store (TempStr, 256);
          End;
    21  : Begin
            TempStr := strPadC(Param[1].S, Param[2].B, Param[3].S[1]);
            Store (TempStr, 256);
          End;
    22  : Begin
            TempStr := strUpper(Param[1].S);
            Store (TempStr, 256);
          End;
    23  : Begin
            TempStr := strLower(Param[1].S);
            Store (TempStr, 256);
          End;
    24  : Begin
            TempStr := strRep(Param[1].S[1], Param[2].B);
            Store (TempStr, 256);
          End;
    25  : Begin
            TempStr := strComma(Param[1].L);
            Store (TempStr, 256);
          End;
    26  : Begin
            TempStr := strI2S(Param[1].L);
            Store (TempStr, 256);
          End;
    27  : Begin
            TempLong := strS2I(Param[1].S);
            Store (TempLong, 4);
          End;
    28  : Begin
            TempStr := strI2H(Param[1].L);
            Store (TempStr, 256);
          End;
    29  : Begin
            TempStr := strWordGet(Param[1].B, Param[2].S, Param[3].S[1]);
            Store (TempStr, 256);
          End;
    30  : Begin
            TempByte := strWordPos(Param[1].B, Param[2].S, Param[3].S[1]);
            Store (TempByte, 1);
          End;
    31  : Begin
            TempByte := strWordCount(Param[1].S, Param[2].S[1]);
            Store (TempByte, 1);
          End;
    32  : Begin
            TempStr := strStripL(Param[1].S, Param[2].S[1]);
            Store (TempStr, 256);
          End;
    33  : Begin
            TempStr := strStripR(Param[1].S, Param[2].S[1]);
            Store (TempStr, 256);
          End;
    34  : Begin
            TempStr := strStripB(Param[1].S, Param[2].S[1]);
            Store (TempStr, 256);
          End;
    35  : Begin
            TempStr := strStripLow(Param[1].S);
            Store (TempStr, 256);
          End;
    36  : Begin
            TempStr := strStripMCI(Param[1].S);
            Store (TempStr, 256);
          End;
    37  : Begin
            TempByte := strMCILen(Param[1].S);
            Store (TempByte, 1);
          End;
    38  : Begin
            TempStr := strInitials(Param[1].S);
            Store (TempStr, 256);
          End;
    39  : Begin
            TempByte := strWrap(String(Pointer(Param[1].vData)^), String(Pointer(Param[2].vData)^), Param[3].B);
            Store (TempByte, 1);
          End;
    40  : Begin
            TempStr := strReplace(Param[1].S, Param[2].S, Param[3].S);
            Store (TempStr, 256);
          End;
    41  : Begin
            TempStr := GetEnv(Param[1].S);
            Store (TempStr, 256);
          End;
    42  : Begin
            TempBool := FileExist(Param[1].S);
            Store (TempBool, 1);
          End;
    43  : FileErase(Param[1].S);
    44  : Begin
            TempBool := DirExists(Param[1].S);
            Store (TempBool, 1);
          End;
    45  : Begin
            TempLong := TimerMinutes;
            Store (TempLong, 4);
          End;
    46  : Begin
            TempLong := TimerSeconds;
            Store (TempLong, 4);
          End;
    47  : Begin
            TempLong := CurDateDos;
            Store (TempLong, 4);
          End;
    48  : Begin
            TempLong := CurDateJulian;
            Store (TempLong, 4);
          End;
    49  : Begin
            TempStr := DateDos2Str(Param[1].L, Param[2].B);
            Store (TempStr, 256);
          End;
    50  : Begin
            TempStr := DateJulian2Str(Param[1].L, Param[2].B);
            Store (TempStr, 256);
          End;
    51  : Begin
            TempLong := DateStr2Dos(Param[1].S);
            Store (TempLong, 4);
          End;
    52  : Begin
            TempLong := DateStr2Julian(Param[1].S);
            Store (TempLong, 4);
          End;
    53  : DateG2J(Param[1].L, Param[2].L, Param[3].L, LongInt(VarData[Param[4].vID]^.Data));
    54  : DateJ2G(Param[1].L, SmallInt(Pointer(Param[2].vData)^), SmallInt(Pointer(Param[3].vData)^), SmallInt(Pointer(Param[4].vData)^));
    55  : Begin
            TempBool := DateValid(Param[1].S);
            Store (TempBool, 1);
          End;
    56  : Begin
            TempStr := TimeDos2Str(Param[1].L, Param[2].O);
            Store (TempStr, 256);
          End;
    57  : Begin
            TempByte := DayOfWeek;
            Store (TempByte, 1);
          End;
    58  : Begin
            TempLong := DaysAgo(Param[1].L);
            Store (TempLong, 4);
          End;
    59  : Begin
            TempStr := JustFile(Param[1].S);
            Store (TempStr, 256);
          End;
    60  : Begin
            TempStr := JustFileName(Param[1].S);
            Store (TempStr, 256);
          End;
    61  : Begin
            TempStr := JustFileExt(Param[1].S);
            Store (TempStr, 256);
          End;
    62  : Begin
            Assign (File(Pointer(Param[1].vData)^), Param[2].S);
            FileMode := Param[3].L;
          End;
    63  : Begin
            Reset (File(Pointer(Param[1].vData)^), 1);
            IoError := IoResult;
          End;
    64  : Begin
            ReWrite (File(Pointer(Param[1].vData)^), 1);
            IoError := IoResult;
          End;
    65  : Begin
            Close (File(Pointer(Param[1].vData)^));
            IoError := IoResult;
          End;
    66  : Begin
            Seek (File(Pointer(Param[1].vData)^), Param[2].L);
            IoError := IoResult;
          End;
    67  : Begin
            TempBool := Eof(File(Pointer(Param[1].vData)^));
            IoError  := IoResult;
            Store (TempBool, 1);
          End;
    68  : Begin
            TempLong := FileSize(File(Pointer(Param[1].vData)^));
            IoError  := IoResult;

            Store (TempLong, 4);
          End;
    69  : Begin
            TempLong := FilePos(File(Pointer(Param[1].vData)^));
            IoError  := IoResult;

            Store (TempLong, 4);
          End;
    70  : Begin
            BlockRead (File(Pointer(Param[1].vData)^), Param[2].vData^, Param[3].W);
            IoError := IoResult;
          End;
    71  : Begin
            BlockWrite (File(Pointer(Param[1].vData)^), Param[2].vData^, Param[3].W);
            IoError := IoResult;
          End;
    72  : FileReadLine  (File(Pointer(Param[1].vData)^), String(Pointer(Param[2].vData)^));
    73  : FileWriteLine (File(Pointer(Param[1].vData)^), Param[2].S);
    74  : Begin
            TempChar := PathChar;
            Store (TempChar, 1);
          End;
    75  : Begin
            TempBool := BitCheck(Param[1].B, Param[2].vSize, VarData[Param[2].vID]^.Data^);

            Store (TempBool, 1);
          End;
    76  : BitToggle(Param[1].B, Param[2].vSize, VarData[Param[2].vID]^.Data^);
    77  : BitSet(Param[1].B, Param[2].vSize, VarData[Param[2].vID]^.Data^, Param[3].O);
    78  : Begin
            FindFirst(Param[1].S, Param[2].W, DirInfo);

            Move (DirInfo.Name, VarData[IdxVarDir    ]^.Data^, SizeOf(DirInfo.Name));
            Move (DirInfo.Size, VarData[IdxVarDir + 1]^.Data^, SizeOf(DirInfo.Size));
            Move (DirInfo.Time, VarData[IdxVarDir + 2]^.Data^, SizeOf(DirInfo.Time));
            Move (DirInfo.Attr, VarData[IdxVarDir + 3]^.Data^, SizeOf(DirInfo.Attr));
          End;
    79  : Begin
            FindNext(DirInfo);

            Move (DirInfo.Name, VarData[IdxVarDir    ]^.Data^, SizeOf(DirInfo.Name));
            Move (DirInfo.Size, VarData[IdxVarDir + 1]^.Data^, SizeOf(DirInfo.Size));
            Move (DirInfo.Time, VarData[IdxVarDir + 2]^.Data^, SizeOf(DirInfo.Time));
            Move (DirInfo.Attr, VarData[IdxVarDir + 3]^.Data^, SizeOf(DirInfo.Attr));
          End;
    80  : FindClose(DirInfo);
    81  : Begin
            TempStr := JustPath(Param[1].S);
            Store (TempStr, 256);
          End;
    82  : Randomize;
    83  : Begin
            TempByte := strWordCount(ParamsStr, ' ');
            Store (TempByte, 1);
          End;
    84  : Begin
            If Param[1].B = 0 Then
              TempStr := MPEName
            Else
              TempStr := strWordGet(Param[1].B, ParamsStr, ' ');
            Store (TempStr, 256);
          End;
    85  : Begin
            TempByte := Screen.TextAttr;
            Store (TempByte, 1);
          End;
    86  : Session.io.AnsiColor(Param[1].B);
    87  : Begin
            TempStr := DirSlash(Param[1].S);
            Store (TempStr, 256);
          End;
    88  : Begin
            TempStr := strStripPipe(Param[1].S);
            Store (TempStr, 256);
          End;
    500 : Begin
            TempStr := Session.io.GetInput(Param[1].B, Param[2].B, Param[3].B, Param[4].S);
            Store (TempStr, 256);
            Session.io.AllowArrow := True;
          End;
    501 : Begin
            TempBool := GetUserRecord(Param[1].L);
            Store (TempBool, 1);
          End;
    502 : Begin
            TempChar := Session.io.OneKey(Param[1].S, Param[1].O);
            Store (TempChar, 1);
          End;
    503 : GetUserVars(Session.User.ThisUser);
    504 : Begin
            TempBool := Session.io.GetYN(Param[1].S, True);
            Store (TempBool, 1);
          End;
    505 : Begin
            TempBool := Session.io.GetYN(Param[1].S, False);
            Store (TempBool, 1);
          End;
    506 : Begin
            Session.io.OutFile(Param[1].S, True, 0);
            TempBool := Not Session.io.NoFile;
            Store (TempBool, 1);
          End;
    507 : Begin
            TempBool := FileCopy(Param[1].S, Param[2].S);
            Store (TempBool, 1);
          End;
    508 : Begin
            ReloadMenu := Session.Menu.ExecuteCommand(Param[1].S, Param[2].S);
            Session.io.AllowArrow := True;
          End;
    509 : Begin
            Session.io.InMacroStr := Param[1].S;
            Session.io.InMacroPos := 1;
            Session.io.InMacro    := Session.io.InMacroStr <> '';
          End;
    510 : Begin
            TempBool := Session.User.Access(Param[1].S);
            Store (TempBool, 1);
          End;
    511 : Upgrade_User_Level(True, Session.User.ThisUser, Param[1].I);
    512 : Session.SetTimeLeft(Param[1].I);
    513 : Halt(0);
    514 : Begin
            TempBool := GetMBaseRecord(Param[1].L);
            Store (TempBool, 1);
          End;
    515 : Begin
            TempStr := Session.GetPrompt(Param[1].L);
            Store (TempStr, 256);
          End;
    516 : Begin
            TempBool := GetMGroupRecord(Param[1].L);
            Store (TempBool, 1);
          End;
    517 : Session.io.PurgeInputBuffer;
    518 : Begin
            TempBool := GetFBaseRecord(Param[1].L);
            Store (TempBool, 1);
          End;
    519 : Begin
            TempBool := GetFGroupRecord(Param[1].L);
            Store (TempBool, 1);
          End;
    520 : Session.SystemLog(Param[1].S);
    521 : Session.io.AnsiMoveX(Param[1].B);
    522 : Session.io.AnsiMoveY(Param[1].B);
    523 : Session.io.OutPipe(Param[1].S);
    524 : Session.io.OutPipeLn(Param[1].S);
    525 : Session.io.OutRaw(Param[1].S);
    526 : Session.io.OutRawLn(Param[1].S);
    527 : Begin
            TempStr := '';
            If Session.io.ParseMCI(False, Param[1].S) Then
              TempStr := Session.io.LastMCIValue;
            Store (TempStr, 256);
          End;
    528 : Begin
            TempInt := Session.TimeLeft;
            Store (TempInt, 2);
          End;
    529 : If Param[1].B < 10 Then Begin
            Move (Session.io.ScreenInfo[Param[1].B].X, Param[2].vData^, 1);
            Move (Session.io.ScreenInfo[Param[1].B].Y, Param[3].vData^, 1);
            Move (Session.io.ScreenInfo[Param[1].B].A, Param[4].vData^, 1);
          End;
    530 : If Param[1].B < FileSize(Session.PromptFile) Then Begin
            Seek  (Session.PromptFile, Param[1].B);
            Write (Session.PromptFile, Param[2].S);
          End;
    531 : Begin
            TempChar := Session.io.MorePrompt;
            Store (TempChar, 1);
          End;
    532 : Session.io.PauseScreen;
    533 : If Param[1].B <= MaxPromptInfo Then Session.io.PromptInfo[Param[1].B] := Param[2].S;
    534 : Session.io.BufFlush;
    535 : Begin
            TempStr := Session.io.StrMci(Param[1].S);
            Store (TempStr, 256);
          End;
    536 : Begin
            TempChar := #0;

            If (Param[1].B < 81) and (Param[2].B < 26) Then
              TempChar := Screen.Buffer[Param[2].B][Param[1].B].UnicodeChar;

            Store (TempChar, 1);
          End;
    537 : Begin
            TempByte := 0;

            If (Param[1].B < 81) and (Param[2].B < 26) Then
              TempByte := Screen.Buffer[Param[2].B][Param[1].B].Attributes;

            Store (TempByte, 1);
          End;
  End;
End;

Procedure TInterpEngine.SkipBlock;
begin
  NextChar;
  NextWord;
  MoveToPos (CurFilePos + W);
end;

Procedure TInterpEngine.DefineProcedure;
Var
  Count   : Word;
  VarChar : Char;
  Params  : Word;
  NumVars : Word;
Begin
  NextWord; { procedure var id }

  If FindVariable(W) > 0 Then Begin  /// ????????????????????
    Error (mpxMultiInit, '');
    Exit;
  End;

  Inc (CurVarNum);
  New (VarData[CurVarNum]);

  With VarData[CurVarNum]^ Do Begin
    VarID     := W;
    vType     := iNone;
    NumParams := 0;
    ProcPos   := 0;
    VarSize   := 0;
    Datasize  := 0;
    ArrPos    := 0;
    Kill      := False;
    Data      := NIL;
  End;

  NextChar;
  Params := 0;

  While (ErrNum = 0) And (Not (Ch in [Char(opProcType), Char(opBlockOpen)])) Do Begin
    VarChar := Ch;
    NextWord;
    NumVars := W;
    For Count := 1 To NumVars Do Begin
      Inc(Params);
      VarData[CurVarNum]^.Params[Params] := VarChar;
      NextWord;
      VarData[CurVarNum]^.pID[Params] := W;
    End;
    NextChar;
  End;

  If Ch = Char(opProcType) Then Begin
    NextChar;

    VarData[CurVarNum]^.vType   := cVarType(Ch);
    VarData[CurVarNum]^.VarSize := xVarSize(VarData[CurVarNum]^.vType);
  End Else
    PrevChar;

  VarData[CurVarNum]^.NumParams := Params;
  VarData[CurVarNum]^.ProcPos   := CurFilePos;

  SkipBlock;
End;

Procedure TInterpEngine.StatementForLoop;
Var
  VarNum    : Word;
  VarArray  : TArrayInfo;
  LoopStart : Real;
  LoopEnd   : Real;
  Count     : Real;
  CountTo   : Boolean;
  SavedPos  : LongInt;
Begin
  NextWord;

  VarNum := FindVariable(W);

  CheckArray (VarNum, VarArray);

  LoopStart := EvaluateNumber;

  NextChar;

  CountTo  := Ch = Char(opTo);
  LoopEnd  := EvaluateNumber;
  Count    := LoopStart;
  SavedPos := CurFilePos;

  If (CountTo And (LoopStart > LoopEnd)) Or ((Not CountTo) And (LoopStart < LoopEnd)) Then
    SkipBlock
  Else
  If CountTo Then
    While (Count <= LoopEnd) And Not Done Do Begin
      SetNumber(VarNum, Count, VarArray);
      MoveToPos(SavedPos);
      If ExecuteBlock (CurVarNum, CurRecNum) = 1 Then Break;
      Count := GetNumber(VarNum, VarArray) + 1;
    End
  Else
  While (Count >= LoopEnd) And Not Done Do Begin
    SetNumber(VarNum, Count, VarArray);
    MoveToPos(SavedPos);
    If ExecuteBlock (CurVarNum, CurRecNum) = 1 Then Break;
    Count := GetNumber(VarNum, VarArray) - 1;
  End;
End;

Procedure TInterpEngine.StatementWhileDo;
Var
  IsTrue   : Boolean;
  StartPos : LongInt;
begin
  StartPos := CurFilePos;
  IsTrue   := True;

  While (ErrNum = 0) And IsTrue And Not Done Do Begin
    IsTrue := EvaluateBoolean;

    If IsTrue Then Begin
      If ExecuteBlock (CurVarNum, CurRecNum) = 1 Then Begin
        MoveToPos (StartPos);
        EvaluateBoolean;
        SkipBlock;
        Break;
      End Else
        MoveToPos (StartPos);
    End Else
      SkipBlock;
  End;
End;

Procedure TInterpEngine.StatementRepeatUntil;
Var
  StartPos: LongInt;
Begin
  StartPos := CurFilePos;

  Repeat
    MoveToPos (StartPos);
    If ExecuteBlock (CurVarNum, CurRecNum) = 1 Then Begin
      EvaluateBoolean;
      Break;
    End;
  Until (ErrNum <> 0) or (EvaluateBoolean) or Done;
End;

Function TInterpEngine.StatementCase : Byte;
Var
  StartPos  : LongInt;
  EndPos    : LongInt;
  TempStr   : String;
  TempBol   : Boolean;
  TempNum   : Real;
  Found     : Boolean;
  VarType   : TIdentTypes;
  Numbers   : Array[1..mplMaxCaseNums] of Record
                Num   : Real;
                Range : Boolean;
              End;
  NumberPos : Word;
  Count     : Word;
  Str       : String;
Begin
  NextWord;   // statement size

  Result    := 0;
  StartPos  := CurFilePos;
  EndPos    := W;
  Found     := False;
  NumberPos := 0;

  NextChar;

  VarType := TIdentTypes(Byte(Ch));

  Case VarType of
    iChar,
    iString : TempStr := EvaluateString;
    iBool   : TempBol := EvaluateBoolean;
  Else
    TempNum := EvaluateNumber;
  End;

  Repeat
    Case VarType of
      iChar,
      iString : Repeat
                   Str   := EvaluateString;
                   Found := Found or (TempStr = Str);

                  NextChar;

                  If Ch <> Char(opParamSep) Then Begin
                    PrevChar;
                    Break;
                  End;
                Until ErrNum <> 0;
      iBool   : Found := EvaluateBoolean = TempBol;
    Else
      Repeat
        Inc (NumberPos);
        Numbers[NumberPos].Num := EvaluateNumber;

        NextChar;

        If Ch = Char(opParamSep) Then
          Numbers[NumberPos].Range := False
        Else
        If Ch = Char(opNumRange) Then
          Numbers[NumberPos].Range := True
        Else Begin
          Numbers[NumberPos].Range := False;
          PrevChar;
          Break;
        End;
      Until ErrNum <> 0;

      Count := 1;

      Repeat
        If Numbers[Count].Range Then
          Found := (TempNum >= Numbers[Count].Num) and (TempNum <= Numbers[Count + 1].Num)
        Else
          Found := TempNum = Numbers[Count].Num;

        Inc (Count);
      Until Found or (Count > NumberPos);
    End;

    If Found Then Begin
      Result := ExecuteBlock (CurVarNum, CurRecNum);
      MoveToPos (StartPos + EndPos);
      Exit;
    End Else
      SkipBlock;

    NextChar;

    If Ch = Char(opElse) Then Begin
      // we probably want to skip the open block here in compiler
      Result := ExecuteBlock(CurVarNum, CurRecNum);
      Break;
    End Else
    If Ch = Char(opBlockClose) Then
      Break
    Else
      PrevChar;

  Until (ErrNum > 0) or Done;
End;

Function TInterpEngine.StatementIfThenElse : Byte;
Var
  Ok : Boolean;
Begin
  Result := 0;

  Ok := EvaluateBoolean;

  //tbbscore(owner).systemlog('if statement');
  //if ok then tbbscore(owner).systemlog('is true') else tbbscore(owner).systemlog('is false');

  If Ok Then
    Result := ExecuteBlock(CurVarNum, CurRecNum)
  Else
    SkipBlock;

  NextChar;

  If Ch = Char(opElse) Then Begin
    If Not Ok Then
      Result := ExecuteBlock(CurVarNum, CurRecNum)
    Else
      SkipBlock;
  End Else
    PrevChar;
End;

Procedure TInterpEngine.DefineRecord;
Var
  Count   : LongInt;
  RecSize : LongInt;
Begin
  NextWord;

  Inc (CurRecNum);
  New (RecData[CurRecNum]);

  RecData[CurRecNum]^.RecStart  := CurVarNum + 1;
  RecData[CurRecNum]^.NumFields := W;

//  DefineVariable; // base record variable

  RecSize := 0;

  For Count := 1 to RecData[CurRecNum]^.NumFields Do Begin
    NextChar;

    Inc (RecSize, DefineVariable);
  End;

  // now we need to build something to create a record block of data
  // and to dispose it based on the variables
  // this method will not work for records in records or arrays of records
  // and really should be re-done.  the problem is, the evaluators will
  // take a lot of changes to suport iRecord correctly.
End;

Function TInterpEngine.ExecuteBlock (StartVar, StartRec: Word) : Byte;
Var
  Count      : Word;
  BlockStart : LongInt;
  BlockSize  : Word;
Begin
  Result := 0;

  {$IFDEF LOGGING}
    Inc(Depth);
    Session.SystemLog('[' + strI2S(Depth) + '] ExecBlock BEGIN Var: ' + strI2S(StartVar) + ' Rec: ' + strI2S(StartRec));
  {$ENDIF}

  NextChar; // block begin character... can we ignore it? at least for case_else
  NextWord; // or just have case else ignore the begin at the compiler level
            // but still output the begin

  BlockStart := CurFilePos;
  BlockSize  := W;

  Repeat
    NextChar;

    Case TTokenOpsRec(Byte(Ch)) of
{0}   opBlockOpen  : Begin
                       PrevChar;
                       Self.ExecuteBlock(CurVarNum, CurRecNum);
                     End;
{1}   opBlockClose : Break;
{2}   opVarDeclare : DefineVariable;
{12}  opSetVar     : Begin
                       NextWord;
                       SetVariable(FindVariable(W));
                     End;
{18}  opProcDef    : DefineProcedure;
{19}  opProcExec   : ExecuteProcedure(NIL);
{21}  opFor        : StatementForLoop;
{34}  opIf         : Begin
                       Result := StatementIfThenElse;
                       If Result > 0 Then Begin
                         MoveToPos(BlockStart + BlockSize);
                         Break;
                       End;
                     End;
{36}  opWhile      : StatementWhileDo;
{39}  opRepeat     : StatementRepeatUntil;
{47}  opGoto       : Begin
                       NextWord;
                       MoveToPos(W);
                     End;
{49}  opHalt       : Done := True;
{50}  opCase       : Begin
                       Result := StatementCase;
                       If Result > 0 Then Begin
                         MoveToPos(BlockStart + BlockSize);
                         Break;
                       End;
                     End;
{52}  opTypeRec    : DefineRecord;
{53}  opBreak      : Begin
                       MoveToPos (BlockStart + BlockSize);
                       Result := 1;
                       Break;
                     End;
{54}  opContinue   : Begin
                       MoveToPos (BlockStart + BlockSize);
                       Result := 2;
                       Break;
                     End;
{55}  opUses       : Begin
                       Repeat
                         NextWord;
                         InitProcedures (Owner, Self, VarData, CurVarNum, CurVarID, W);
                         NextChar;
                         If Ch <> Char(opParamSep) Then Begin
                           PrevChar;
                           Break;
                         End;
                       Until ErrNum <> 0;
                     End;
{56}  opExit       : Begin
                       Done     := True;
                       ExitProc := True;
                     End;
    Else
      Error (mpxUnknownOp, strI2S(Ord(Ch)));
    End;
  Until (ErrNum <> 0) or Done or DataFile^.EOF;

  {$IFDEF LOGGING}
    Session.SystemLog('[' + strI2S(Depth) + '] ExecBlock KILL VAR: ' + strI2S(CurVarNum) + ' to ' + strI2S(StartVar + 1));
  {$ENDIF}

  For Count := CurVarNum DownTo StartVar + 1 Do Begin
    {$IFDEF LOGGING}
      LogVarInformation(Count);
    {$ENDIF}

    If (VarData[Count]^.Kill) And (VarData[Count]^.Data <> NIL) Then Begin
      FreeMem(VarData[Count]^.Data, VarData[Count]^.DataSize);

      {$IFDEF LOGGING}
        Session.SystemLog('    FreeMem ' + strI2S(Count));
      {$ENDIF}
    End;

    {$IFDEF LOGGING}
      Session.SystemLog('    Dispose ' + strI2S(Count));
    {$ENDIF}

    Dispose (VarData[Count]);
  End;

  {$IFDEF LOGGING}
    Session.SystemLog('[' + strI2S(Depth) + '] ExecBlock KILL REC: ' + strI2S(CurRecNum) + ' to ' + strI2S(StartRec + 1));
  {$ENDIF}

  For Count := CurRecNum DownTo StartRec + 1 Do
    Dispose(RecData[Count]);
    // dispose record data block?  or just calc it whenever there is an
    // assignment or filewrite, etc?

  CurVarNum := StartVar;
  CurRecNum := StartRec;

  {$IFDEF LOGGING}
    Session.SystemLog('[' + strI2S(Depth) + '] ExecBlock END');
    Dec (Depth);
  {$ENDIF}
End;

Function TInterpEngine.Execute (FN: String) : Byte;
// 0 = not found  1 = ok  2 = goto new menu
Var
  VerStr : String;
  Res    : LongInt;
Begin
  Result     := 0;
  CurVarNum  := 0;
  CurVarID   := 0;
  CurRecNum  := 0;
  ReloadMenu := False;
  Done       := False;
  ExitProc   := False;
  SavedMCI   := Session.io.AllowMCI;
  SavedGroup := Session.User.IgnoreGroup;
  SavedArrow := Session.io.AllowArrow;
  DataFile   := New(PCharFile, Init(mplExecuteBuffer));

  Session.io.AllowArrow := True;

  If strWordCount(FN, ' ') > 1 Then Begin
    ParamsStr := Copy(FN, strWordPos(2, FN, ' '), Length(FN));
    FN        := strWordGet(1, FN, ' ');
  End Else
    ParamsStr := '';

  If Pos('.', FN) = 0 Then FN := FN + mplExtExecute;

  If Pos(PathChar, FN) = 0 Then
    FN := Config.ScriptPath + FN;

  MPEName := FN;

  If Not DataFile^.Open(FN) Then Begin
    Dispose(DataFile, Done);

    Exit;
  End;

  Result := 1;

  If DataFile^.FileSize < mplVerLength Then Begin
    DataFile^.Close;

    Error   (mpxInvalidFile, FN);
    Dispose (DataFile, Done);

    Exit;
  End;

  DataFile^.BlockRead (VerStr[1], mplVerLength, Res);
  VerStr[0] := Chr(mplVerLength);

  If VerStr <> mplVersion Then Begin
    DataFile^.Close;

    Error   (mpxVerMismatch, VerStr);
    Dispose (DataFile, Done);

    Exit;
  End;

  InitProcedures (Owner, Self, VarData, CurVarNum, CurVarID, 0);
  ExecuteBlock   (CurVarNum, CurRecNum);

  DataFile^.Close;

  Dispose(DataFile, Done);

  Session.io.AllowMCI      := SavedMCI;
  Session.User.IgnoreGroup := SavedGroup;
  Session.io.AllowArrow    := SavedArrow;

  Result := Ord(ReloadMenu) + 1;
End;

Function ExecuteMPL (Owner: Pointer; Str: String) : Byte;
Var
  Script : TInterpEngine;
Begin
  Script := TInterpEngine.Create(Owner);
  Result := Script.Execute(Str);

  If Script.ErrNum > 0 Then
    Session.io.OutFullLn ('|CR|12MPX ERROR: ' + Script.GetErrorMsg);

  Script.Free;
End;

End.

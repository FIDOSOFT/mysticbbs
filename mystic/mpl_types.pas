Type
  TIdentTypes = (
    iNone,
    iString,
    iChar,
    iByte,
    iShort,
    iWord,
    iInteger,
    iLongInt,
    iCardinal,
    iReal,
    iBool,
    iFile,
    iRecord,
    iPointer
  );

  TTokenOpsRec  = (
    opBlockOpen,                 // 1
    opBlockClose,                // 2
    opVarDeclare,                // 3
    opStr,                       // 4
    opChar,                      // 5
    opByte,                      // 6
    opShort,                     // 7
    opWord,                      // 8
    opInt,                       // 9
    opLong,                      // 10
    opReal,                      // 11
    opBool,                      // 12
    opSetVar,                    // 13
    opLeftParan,                 // 14
    opRightParan,                // 15
    opVariable,                  // 16
    opOpenString,                // 17
    opCloseString,               // 18
    opProcDef,                   // 19
    opProcExec,                  // 20
    opParamSep,                  // 21
    opFor,                       // 22
    opTo,                        // 23
    opDownTo,                    // 24
    opTrue,                      // 25
    opFalse,                     // 26
    opEqual,                     // 27
    opNotEqual,                  // 28
    opGreater,                   // 29
    opLess,                      // 30
    opEqGreat,                   // 31
    opEqLess,                    // 32
    opStrAdd,                    // 33
    opProcType,                  // 34
    opIf,                        // 35
    opElse,                      // 36
    opWhile,                     // 37
    opOpenNum,                   // 38
    opCloseNum,                  // 39
    opRepeat,                    // 40
    opNot,                       // 41
    opAnd,                       // 42
    opOr,                        // 43
    opStrArray,                  // 44
    opArrDef,                    // 45
    opStrSize,                   // 46
    opVarNormal,                 // 47
//    opGoto,                      // 48
    opHalt,                      // 49
    opCase,                      // 50
    opNumRange,                  // 51
    opTypeRec,                   // 52
    opBreak,                     // 53
    opContinue,                  // 54
    opUses,                      // 55
    opExit,                      // 56
    opNone                       // 57
  );

Const
  mplVer           = '11S';
  mplVersion       = '[MPX ' + mplVer +']' + #26;
  mplVerLength     = 10;
  mplExtSource     = '.mps';
  mplExtExecute    = '.mpx';
  mplMaxInclude    = 10;
  mplMaxFiles      = 20;
  mplMaxIdentLen   = 30;
  mplMaxVars       = 2500;
//  mplMaxGotos      = 100;
  mplMaxCaseNums   = 20;
  mplMaxVarDeclare = 20;
  mplMaxArrayDem   = 3;   //cannot be changed yet
  mplMaxProcParams = 12;
  mplMaxRecords    = 20;
  mplMaxRecFields  = 40;
  mplMaxDataSize   = 65535;
  mplMaxConsts     = 100;

Const
   chNumber           = ['0'..'9','.'];
   chIdent1           = ['a'..'z','A'..'Z','_'];
   chIdent2           = ['a'..'z','A'..'Z','0'..'9','_'];
   chDigit            = ['0'..'9'];
   chHexDigit         = ['0'..'9','A'..'F','a'..'f'];

{$IFNDEF MPLPARSER}
   mpxEndOfFile       = 1;
   mpxInvalidFile     = 2;
   mpxVerMismatch     = 3;
   mpxUnknownOp       = 4;
   mpxBadInit         = 5;
   mpxDivisionByZero  = 6;
   mpxMathematical    = 7;
   mpxTooManyClasses  = 8;
   mpxInvalidClass    = 9;
   mpxInvalidClassH   = 10;
{$ELSE}
   mpsEndOfFile       = 1;
   mpsFileNotfound    = 2;
   mpsFileRecurse     = 3;
   mpsOutputFile      = 4;
   mpsExpected        = 5;
   mpsUnknownIdent    = 6;
   mpsInStatement     = 7;
   mpsIdentTooLong    = 8;
   mpsExpIdentifier   = 9;
   mpsTooManyVars     = 10;
   mpsDupIdent        = 11;
   mpsOverMaxDec      = 12;
   mpsTypeMismatch    = 13;
   mpsSyntaxError     = 14;
   mpsStringNotClosed = 15;
   mpsStringTooLong   = 16;
   mpsTooManyParams   = 17;
   mpsBadProcRef      = 18;
   mpsNumExpected     = 19;
   mpsToOrDowntoExp   = 20;
   mpsExpOperator     = 21;
   mpsOverArrayDim    = 22;
   mpsNoInitArray     = 23;
//   mpsTooManyGotos    = 24;
   mpsDupLabel        = 25;
   mpsLabelNotFound   = 26;
   mpsFileParamVar    = 27;
   mpsBadFunction     = 28;
   mpsOperation       = 29;
   mpsOverMaxCase     = 30;
   mpsTooManyFields   = 31;
   mpsDataTooBig      = 32;
   mpsMaxConsts       = 33;
{$ENDIF}

// ==========================================================================

{$IFDEF MPLPARSER}
Type
  TTokenWordRec = (wBlockOpen,    wBlockClose,  wVarDeclare,  wVarSep,
                   wSetVar,       wLeftParan,   wRightParan,  wOpenString,
                   wCloseString,  wStrAdd,      wCharPrefix,  wProcDef,
                   wOpenParam,    wCloseParam,  wParamVar,    wParamSpec,
                   wFuncSpec,     wParamSep,    wFor,         wTo,
                   wDownTo,       wDo,          wTrue,        wFalse,
                   wOpEqual,      wOpNotEqual,  wOpGreater,   wOpLess,
                   wOpEqGreat,    wOpEqLess,    wIf,          wThen,
                   wElse,         wWhile,       wRepeat,      wUntil,
                   wNot,          wAnd,         wOr,          wOpenArray,
                   wCloseArray,   wArrSep,      wVarDef,      wOpenStrSize,
                   wCloseStrSize, wLabel,       wHalt,
                   wVarSep2,      wFuncDef,     wArray,       wCaseStart,
                   wCaseOf,       wNumRange,    wType,        wConst,
                   wBreak,        wContinue,    wUses,        wExit,
                   wHexPrefix,    wExpAnd,      wExpOr,       wExpXor,
                   wExpShl,       wExpShr,      wInclude);
{$ENDIF}


Const
  {$IFDEF MPLPARSER}
     tkv : Array[TIdentTypes] of String[mplMaxIdentLen] = (
             'none',            'string',         'char',       'byte',
             'shortint',        'word',           'integer',    'longint',
             'cardinal',        'real',           'boolean',    'file',
             'record',          'pointer');

Type
     TTokenWordType = Array[TTokenWordRec] of String[mplMaxIdentLen];

Const
     wTokensPascal : TTokenWordType = (
             'begin',           'end',            'var',        ',',
             ':=',              '(',              ')',          '''',
             '''',              '+',              '#',          'procedure',
             '(',               ')',              '+',          ';',
             ':',               ',',              'for',        'to',
             'downto',          'do',             'true',       'false',
             '=',               '<>',             '>',          '<',
             '>=',              '<=',             'if',         'then',
             'else',            'while',          'repeat',     'until',
             'not',             'and',            'or',         '[',
             ']',               ',',              '=',          '[',
             ']',               ':',              'halt',
             ':',               'function',       'array',      'case',
             'of',              '..',             'type',       'const',
             'break',           'continue',       'uses',       'exit',
             '$',               'and',            'or',         'xor',
             'shl',             'shr',            'include'
           );

     wTokensIPLC : TTokenWordType = (
             '{',               '}',              '@',          ',',
             '=',               '(',              ')',          '"',
             '"',               '+',              '#',          'proc',
             '(',               ')',              '+',          ';',
             ':',               ',',              'for',        'to',
             'downto',          'do',             'true',       'false',
             '==',              '!=',             '>',          '<',
             '>=',              '<=',             'if',         'then',
             'else',            'while',          'repeat',     'until',
             '!',               '&&',             '||',         '(',
             ')',               ',',              '=',          '[',
             ']',               ':',              'halt',
             ':',               'func',           'array',      'switch',
             'of',              '..',             'type',       'const',
             'break',           'continue',       'uses',       'exit',
             '$',               '&',              '|',          'xor',
             '<<',              '>>',             'include'
           );

  {$ENDIF}

  vNums    : Set of TIdentTypes = [iByte, iShort, iWord, iInteger, iLongInt, iCardinal, iReal];
  vStrings : Set of TIdentTypes = [iChar, iString];

Type
  {$IFNDEF MPLPARSER}
    PStack      = ^TStack;
    TStack      = Array[1..mplMaxDataSize] of Byte;
    TArrayInfo  = Array[1..mplMaxArrayDem] of Word;
    TRecInfo    = Record
                    vType   : TIdentTypes;
                    OneSize : Word;
                    Offset  : Word;
                    ArrDem  : Word;
                  End;

(*
// MEMORY SAVING... could be 28 bytes per var?!?!
// could at least make a procrec that tvarrec links to via a pointer.  would
// save us about 25 bytes per var... which is about half the memory.  we
// could also remove IsProc var in TVar because we could just check to see
// if Proc : Pointer is assigned...
    PProcInfoRec = ^TProcInfoRec;
    TProcInfoRec = Record
      Params    : Array[1..mplMaxProcParams] of Char;
      ParamID   : Array[1..mplMaxProcParams] of Word;
      NumParams : Byte;
      Position  : LongInt;
    End;
*)

    PVarRec = ^TVarRec;
    TVarRec = Record
       VarID     : Word;
       vType     : TIdentTypes;
       Params    : Array[1..mplMaxProcParams] of Char;
       NumParams : Byte;
       pID       : Array[1..mplMaxProcParams] of Word;
       ProcPos   : LongInt;
       DataSize  : Word;
       VarSize   : Word;
       Data      : PStack;
       Kill      : Boolean;
       ArrPos    : Byte;
       ArrDim    : TArrayInfo;
    End;

    VarDataRec = Array[1..mplMaxVars] of PVarRec;
  {$ELSE}
    PVarRec = ^TVarRec;
    TVarRec = Record
       VarID     : Word;
       Ident     : String[mplMaxIdentLen];
       VType     : TIdentTypes;
       Params    : Array[1..mplMaxProcParams] of Char;
       NumParams : Byte;
       InProc    : Boolean;
       Proc      : Boolean;
       ArrPos    : Byte;
       RecID     : Word;
    End;

    VarDataRec = Array[1..mplMaxVars] of PVarRec;
{$ENDIF}


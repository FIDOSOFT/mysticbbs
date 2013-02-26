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

Program MPLC;

{$I M_OPS.PAS}

Uses
  DOS,
  m_Output,
  m_Strings,
  MPL_Compile;

{$I RECORDS.PAS}

Var
  SavedX   : Byte;
  Console  : TOutput;
  WasError : Boolean;

Procedure Status (Info: TParserUpdateInfo);
Begin
  Case Info.Mode of
    StatusStart  : Begin
                     Console.WriteStr('Compiling ' + Info.FileName + ' ... ');
                     SavedX := Console.CursorX;
                   End;
    StatusUpdate : Begin
                     Console.CursorXY (SavedX, Console.CursorY);
                     Console.WriteStr (strPadL(strI2S(Info.Percent), 3, ' ') + '%');
                   End;
    StatusDone   : If Info.ErrorType = 0 Then Begin
                     Console.CursorXY (SavedX, Console.CursorY);
                     Console.WriteLine ('Success!');
                   End Else Begin
                     WasError := True;
                     Console.WriteLine(#13#10#13#10'Error in ' + Info.FileName + ' (Line:' + strI2S(Info.ErrorLine) + ', Col:' + strI2S(Info.ErrorCol) + '): ' + Info.ErrorText);
                   End;
  End;
End;

Var
  Parser : TParserEngine;
  Dir    : SearchRec;
Begin
  WasError := False;
  Console  := TOutput.Create(True);

  Console.WriteLine (#13#10'Mystic BBS Programming Language Compiler Version ' + mysVersion);
  Console.WriteLine ('Copyright (C) ' + mysCopyYear + ' By James Coyle.  All Rights Reserved.'#13#10);

  If ParamCount = 0 Then
    WriteLn ('MPLC [filename] or MPLC -ALL')
  Else Begin
    If Pos('-ALL', strUpper(ParamStr(1))) > 0 Then Begin
      FindFirst ('*.mps', AnyFile - Directory - VolumeID, Dir);
      While DosError = 0 Do Begin
        Parser := TParserEngine.Create(Status);
        If Not Parser.Compile(Dir.Name) Then Begin
          Parser.Free;
          Break;
        End;
        FindNext(Dir);
        Parser.Free;
      End;
      FindClose(Dir);
    End Else Begin
      Parser := TParserEngine.Create(Status);
      Parser.Compile(ParamStr(1));
      Parser.Free;
    End;
  End;

  Console.Free;

  If WasError Then Halt(1);
End.

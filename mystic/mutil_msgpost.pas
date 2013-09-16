Unit MUTIL_MsgPost;

{$I M_OPS.PAS}

Interface

Procedure uPostMessages;

Implementation

Uses
  m_FileIO,
  m_Strings,
  BBS_Records,
  BBS_DataBase,
  mUtil_Common,
  mUtil_Status;

Procedure uPostMessages;
Const
  MaxLines = 10000;
Var
  Posted    : LongInt = 0;
  FileCount : SmallInt;
  Count     : SmallInt;
  FileName  : String;
  AreaIndex : Cardinal;
  Base      : RecMessageBase;
  MsgFrom   : String;
  MsgTo     : String;
  MsgSubj   : String;
  MsgAddr   : RecEchomailAddr;
  MsgText   : RecMessageText;
  MsgLines  : LongInt;
  DelFile   : Boolean;
  InFile    : Text;
  InFileBuf : Array[1..4 * 1024] of Char;
  Lines     : LongInt;
  Buffer    : Array[1..MaxLines] of String[79];
  Pages     : SmallInt;
  PostLoop  : SmallInt;
  Offset    : LongInt;
  TempStr   : String;
Begin
  ProcessName   ('Post Messages', True);
  ProcessResult (rWORKING, False);

  FileCount := INI.ReadInteger(Header_MsgPost, 'totalfiles', 0);

  If FileCount > 0 Then
    For Count := 1 to FileCount Do Begin
      FileName := INI.ReadString(Header_MsgPost, 'file' + strI2S(Count) + '_name', '');

      If (FileName = '') or Not FileExist(FileName) Then Begin
        Log (2, '!', '   File ' + FileName + ' not found');

        Continue;
      End;

      AreaIndex := INI.ReadInteger(Header_MsgPost, 'file' + strI2S(Count) + '_baseidx', -1);

      If (AreaIndex = -1) or Not GetMBaseByIndex(AreaIndex, Base) Then Begin
        Log (2, '!', '   Invalid BaseIdx: ' + strI2S(AreaIndex));

        Continue;
      End;

      MsgFrom := INI.ReadString  (Header_MsgPost, 'file' + strI2S(Count) + '_from', '');
      MsgTo   := INI.ReadString  (Header_MsgPost, 'file' + strI2S(Count) + '_to', '');
      MsgSubj := INI.ReadString  (Header_MsgPost, 'file' + strI2S(Count) + '_subj', '');
      DelFile := INI.ReadBoolean (Header_MsgPost, 'file' + strI2S(Count) + '_delfile', False);

      Str2Addr(INI.ReadString(Header_MsgPost, 'file' + strI2S(Count) + '_addr', '0:0/0'), MsgAddr);

      If (MsgFrom = '') or (MsgTo = '') Then Begin
        Log (2, '!', '   Invalid From to To: ' + MsgFrom + '/' + MsgTo);

        Continue;
      End;

      Assign     (InFile, FileName);
      SetTextBuf (InFile, InFileBuf, SizeOf(InFileBuf));
      Reset      (InFile);

      Lines := 0;

      While Not Eof(InFile) And (Lines < MaxLines) Do Begin
        Inc    (Lines);
        ReadLn (InFile, Buffer[Lines]);
      End;

      Close (InFile);

      If DelFile Then FileErase(FileName);

      Pages := Lines DIV mysMaxMsgLines + 1;

      If (Lines MOD mysMaxMsgLines = 0) Then Dec(Pages);

      For PostLoop := 1 to Pages Do Begin
        Offset   := mysMaxMsgLines * Pred(PostLoop);
        MsgLines := 0;

        While (Offset < Lines) and (MsgLines < mysMaxMsgLines) Do Begin
          Inc (MsgLines);
          Inc (Offset);

          MsgText[MsgLines] := Buffer[Offset];
        End;

        If Pages > 1 Then
          TempStr := MsgSubj + ' (' + strI2S(PostLoop) + '/' + strI2S(Pages) + ')'
        Else
          TempStr := MsgSubj;

        If SaveMessage (Base, MsgFrom, MsgTo, TempStr, MsgAddr, MsgText, MsgLines) Then Begin
          Log (1, '+', '   Post: ' + strI2S(AreaIndex) + ' Subj: ' + TempStr);

          Inc (Posted);
        End Else Begin
          Log (2, '!', '   Error posting');
          Break;
        End;
      End;
    End;

  ProcessStatus ('|07Posted |15' + strI2S(Posted) + ' |07Msgs', True);
  ProcessResult (rDONE, True);
End;

End.

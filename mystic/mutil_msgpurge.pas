Unit MUTIL_MsgPurge;

{$I M_OPS.PAS}

Interface

Procedure uPurgeMessageBases;

Implementation

Uses
  m_Strings,
  m_DateTime,
  mUtil_Common,
  mUtil_Status,
  bbs_Records,
  BBS_DataBase,
  bbs_MsgBase_ABS,
  bbs_MsgBase_JAM,
  bbs_MsgBase_Squish;

Procedure uPurgeMessageBases;
Var
  PurgeTotal : LongInt = 0;
  PurgeBase  : LongInt;
  BaseFile   : File of RecMessageBase;
  Base       : RecMessageBase;
  MsgBase    : PMsgBaseABS;
Begin
  ProcessName   ('Purging Message Bases', True);
  ProcessResult (rWORKING, False);

  Assign (BaseFile, bbsCfg.DataPath + 'mbases.dat');
  {$I-} Reset (BaseFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(BaseFile) Do Begin
      Read (BaseFile, Base);

      ProcessStatus (Base.Name, False);
      BarOne.Update (FilePos(BaseFile), FileSize(BaseFile));

      PurgeBase := 0;

      If Not MessageBaseOpen(MsgBase, Base) Then Continue;

      If Base.MaxAge > 0 Then Begin
        MsgBase^.SeekFirst(1);

        While MsgBase^.SeekFound Do Begin
          MsgBase^.MsgStartUp;

          If MsgBase^.IsDeleted Then Begin
            MsgBase^.SeekNext;

            Continue;
          End;

          If DaysAgo(DateStr2Julian(MsgBase^.GetDate), 1) > Base.MaxAge Then Begin
            MsgBase^.DeleteMsg;

            Inc (PurgeTotal);
            Inc (PurgeBase);
          End;

          MsgBase^.SeekNext;
        End;
      End;

      If Base.MaxMsgs > 0 Then Begin
        MsgBase^.SeekFirst(1);

        While MsgBase^.SeekFound And (MsgBase^.NumberOfMsgs > Base.MaxMsgs) Do Begin
          MsgBase^.MsgStartUp;

          If Not MsgBase^.IsDeleted Then Begin
            MsgBase^.DeleteMsg;

            Inc (PurgeTotal);
            Inc (PurgeBase);
          End;

          MsgBase^.SeekNext;
        End;
      End;

      MsgBase^.CloseMsgBase;

      Dispose (MsgBase, Done);

      Log (2, '+', '      Purged ' + strI2S(PurgeBase));
    End;

    Close (BaseFile);
  End;

  ProcessStatus ('Purged |15' + strI2S(PurgeTotal) + ' |07messages', True);
  ProcessResult (rDONE, True);
End;

End.

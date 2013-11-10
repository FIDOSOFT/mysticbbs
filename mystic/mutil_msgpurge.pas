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

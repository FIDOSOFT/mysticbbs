Unit bbs_cfg_Groups;

{$I M_OPS.PAS}

Interface

Procedure Group_Editor;

Implementation

Uses
  m_Strings,
  bbs_Common,
  bbs_Core;

Procedure File_Group;
var
  a : SmallInt;
fgroup : recgroup;
Begin
  Reset (Session.FileBase.FGroupFile);
  Repeat
    Session.io.OutFullLn ('|CL|14File Group Editor|CR|CR|09###  Name|CR---  ------------------------------');
    Reset (Session.FileBase.FGroupFile);
    while not eof(Session.FileBase.FGroupFile) do begin
      read (Session.FileBase.FGroupFile, FGroup);
      Session.io.OutFullLn ('|15' + strPadR(strI2S(filepos(Session.FileBase.FGroupFile)), 5, ' ') + '|14' + FGroup.Name);
    end;
    Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (Q)uit? ');
    case Session.io.OneKey ('DIEQ', True) of
      'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              KillRecord (Session.FileBase.FGroupFile, A, SizeOf(RecGroup));
            end;
      'I' : begin
              Session.io.OutRaw ('Insert before which? (1-' + strI2S(filesize(Session.FileBase.FGroupFile)+1) + '): ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.FileBase.FGroupFile)+1) then begin
                AddRecord (Session.FileBase.FGroupFile, A, SizeOf(RecGroup));
                FGroup.Name := '';
                FGroup.ACS  := 's255';
                write (Session.FileBase.FGroupFile, FGroup);
              end;
            end;
      'E' : begin
              Session.io.OutRaw ('Edit which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.FileBase.FGroupFile)) then begin
                seek (Session.FileBase.FGroupFile, a-1);
                read (Session.FileBase.FGroupFile, FGroup);
                repeat
                  Session.io.OutFullLn ('|CL|14File Group '+strI2S(FilePos(Session.FileBase.FGroupFile)) + ' of ' + strI2S(FileSize(Session.FileBase.FGroupFile))+'|CR|03');
                  Session.io.OutRawln ('A. Name   : ' + FGroup.Name);
                  Session.io.OutRawln ('B. ACS    : ' + FGroup.acs);
                  Session.io.OutRawLn ('C. Hidden : ' + Session.io.OutYN(FGroup.Hidden));
                  Session.io.OutFull ('|CR|09Command (Q/Quit): ');
                  case Session.io.OneKey('ABCQ', True) of
                    'A' : FGroup.name := Session.io.InXY(13, 3, 30, 30, 11, Fgroup.name);
                    'B' : FGroup.acs  := Session.io.InXY(13, 4, 20, 20, 11, Fgroup.acs);
                    'C' : FGroup.Hidden := Not FGroup.Hidden;
                    'Q' : break;
                  end;
                until false;
                seek (Session.FileBase.FGroupFile, filepos(Session.FileBase.FGroupFile)-1);
                write (Session.FileBase.FGroupFile, FGroup);
              end;
            end;
      'Q' : break;
    end;

  until False;
  close (Session.FileBase.FGroupFile);

End;

Procedure Message_Group;
var
  a : SmallInt;
  group:Recgroup;
Begin
  Reset (Session.Msgs.GroupFile);
  Repeat
    Session.io.OutFullLn ('|CL|14Message Group Editor|CR|CR|09###  Name|CR---  ------------------------------');
    Reset (Session.Msgs.GroupFile);
    while not Eof(Session.Msgs.GroupFile) do begin
      read (Session.Msgs.GroupFile, Group);
      Session.io.OutFullLn ('|15' + strPadR(strI2S(filepos(Session.Msgs.GroupFile)), 5, ' ') + '|14' + Group.Name);
    end;
    Session.io.OutFull ('|CR|09(I)nsert, (D)elete, (E)dit, (Q)uit? ');
    case Session.io.OneKey ('DIEQ', True) of
      'D' : begin
              Session.io.OutRaw ('Delete which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              KillRecord (Session.Msgs.GroupFile, A, SizeOf(RecGroup));
            end;
      'I' : begin
              Session.io.OutRaw ('Insert before? (1-' + strI2S(filesize(Session.Msgs.GroupFile)+1) + '): ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.Msgs.GroupFile)+1) then begin
                AddRecord (Session.Msgs.GroupFile, A, SizeOf(RecGroup));
                Group.Name := '';
                Group.ACS  := 's255';
                write (Session.Msgs.GroupFile, Group);
              end;
            end;
      'E' : begin
              Session.io.OutRaw ('Edit which? ');
              a := strS2I(Session.io.GetInput(3, 3, 11, ''));
              if (a > 0) and (a <= filesize(Session.Msgs.GroupFile)) then begin
                seek (Session.Msgs.GroupFile, a-1);
                read (Session.Msgs.GroupFile, Group);
                repeat
                  Session.io.OutFullLn ('|CL|14Group ' + strI2S(FilePos(Session.Msgs.GroupFile)) + ' of ' + strI2S(FileSize(Session.Msgs.GroupFile)) + '|CR|03');
                  Session.io.OutRawln ('A. Name   : ' + Group.Name);
                  Session.io.OutRawln ('B. ACS    : ' + Group.acs);
                  Session.io.OutRawLn ('C. Hidden : ' + Session.io.OutYN(Group.Hidden));

                  Session.io.OutFull ('|CR|09Command (Q/Quit): ');
                  case Session.io.OneKey('ABCQ', True) of
                    'A' : Group.name := Session.io.InXY(13, 3, 30, 30, 11, group.name);
                    'B' : Group.acs  := Session.io.InXY(13, 4, 20, 20, 11, group.acs);
                    'C' : Group.Hidden := Not Group.Hidden;
                    'Q' : break;
                  end;
                until false;
                seek (Session.Msgs.GroupFile, filepos(Session.Msgs.GroupFile)-1);
                write (Session.Msgs.GroupFile, Group);
              end;
            end;
      'Q' : break;
    end;

  until False;
  close (Session.Msgs.GroupFile);
End;

Procedure Group_Editor;
Begin
  Session.SystemLog ('*GROUP EDITOR*');

  Session.io.OutFull ('|CL|09Edit Groups: (M)essage, (F)ile, (Q)uit? ');
  Case Session.io.OneKey('QMF', True) of
    'M' : Message_Group;
    'F' : File_Group;
  End;
End;

End.

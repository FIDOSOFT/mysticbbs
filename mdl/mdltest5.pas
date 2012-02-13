Program TEST5;

Uses
  m_Types,
  m_Input,
  m_Output,
  m_Socket_Class,
  m_DateTime,
  m_Term_Ansi,
  m_Strings;

Var
  Input  : TInput;
  Output : TOutput;
  Client : TSocketClass;
  Term   : TTermAnsi;

Procedure Init;
Begin
  Input  := TInput.Create;
  Output := TOutput.Create(True);
  Client := TSocketClass.Create;
  Term   := TTermAnsi.Create(Output);
End;

Procedure Cleanup;
Begin
  Client.Free;
  Term.Free;
  Output.Free;
  Input.Free;
End;

Var
  Ch    : Char;
  Res   : LongInt;
  Buf   : Array[1..1024] of Char;
  Done  : Boolean;
  Image : TConsoleImageRec;
Begin
  Init;

  If ParamCount <> 2 Then Begin
    Output.WriteLine('Invalid options: test5 [address] [port]');
    Cleanup;
    Halt;
  End;

  Output.WriteStr ('Connecting to: ' + ParamStr(1) + ':' + ParamStr(2) + '. ');

  If Not Client.Connect(ParamStr(1), strS2I(ParamStr(2))) Then Begin
    Output.WriteLine('Unable to connect');
    Cleanup;
    Halt;
  End;

  Output.WriteLine('Connected!');
  Output.SetWindowTitle('MDL Terminal Demo');

  Client.SetBlocking(False);
  Term.SetReplyClient(Client);

  Output.TextAttr := 7;
  Output.ClearScreen();
  Output.WriteXYPipe (1, 25, 15 + 1 * 16, 79, ' MDL Terminal Demo ');
  Output.SetWindow(1, 1, 80, 24, True);

  Done := False;

  Repeat
    If Input.KeyPressed Then Begin
      Ch := Input.ReadKey;

      Case Ch of
        #00 : Case Input.ReadKey of
                #45 : Break;
                #71 : Client.WriteStr(#27 + '[H');
                #72 : Client.WriteStr(#27 + '[A');
                #73 : Client.WriteStr(#18);
                #75 : Client.WriteStr(#27 + '[D');
                #77 : Client.WriteStr(#27 + '[C');
                #79 : Client.WriteStr(#27 + '[K');
                #80 : Client.WriteStr(#27 + '[B');
                #81 : Client.WriteStr(#3);
                #83 : Client.WriteStr(#127);
                #34 : Begin
                        Output.GetScreenImage(1, 1, 80, 25, Image);
                      End;
                #25 : Begin
                        Output.ClearScreen;
                        Output.PutScreenImage(Image);
                      End;
                ^C  : Break;
              End;
      End;

      Client.WriteBuf(Ch, 1);
    End Else
    If Client.WaitForData(10) > 0 Then Begin
      Repeat
        Res := Client.ReadBuf(Buf, SizeOf(Buf));

        If Res < 0 Then Begin
          Done := True;
          Break;
        End;

        Term.ProcessBuf(Buf[1], Res);

      Until Res <> SizeOf(Buf);
    End Else
      WaitMS(10);
  Until Done;

  Output.WriteLine('');
  Output.WriteLine('Connection terminated.');
  Output.SetWindow(1, 1, 80, 25, False);

  Cleanup;
End.

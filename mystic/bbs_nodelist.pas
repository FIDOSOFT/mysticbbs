Unit BBS_NodeList;

{$I M_OPS.PAS}

Interface

Uses
  BBS_Common,
  BBS_Records,
  BBS_DataBase;

Type
  RecNodeSearch = Record
    Keyword   : String[8];
    SysopName : String[30];
    BBSName   : String[30];
    Location  : String[30];
    Phone     : String[20];
    Address   : RecEchoMailAddr;
    Internet  : String[40];
  End;

  TNodeListSearch = Class
    SearchStr  : String;
    SearchZone : String[5];
    SearchNet  : String[5];
    SearchNode : String[5];
    AddrSearch : Boolean;
    Opened     : Boolean;
    ListFile   : Text;
    ListBuffer : Array[1..1024 * 4] of Char;
    CurAddr    : RecEchoMailAddr;
    NodeData   : RecNodeSearch;

    Constructor Create;
    Destructor  Destroy; Override;
    Function    ResetSearch (NodeList: String; Str: String) : Boolean;
    Function    FindNext    (Var Res: RecNodeSearch) : Boolean;
  End;

Implementation

Uses
  m_Strings;

Constructor TNodeListSearch.Create;
Begin
  Inherited Create;

  Opened := False;
End;

Destructor TNodeListSearch.Destroy;
Begin
  Inherited Destroy;

  If Opened Then Close(ListFile);
End;

Function TNodeListSearch.ResetSearch (NodeList: String; Str: String) : Boolean;
Var
  A : Byte;
  B : Byte;
Begin
  Result    := False;
  SearchStr := strReplace(strUpper(strStripB(Str, ' ')), '*', '?');

  If Opened Then Begin
    Close (ListFile);

    Opened := False;
  End;

  If SearchStr = '' Then Exit;

  A := Pos(':', SearchStr);
  B := Pos('/', SearchStr);

  If (A = 0) or (B <= A) Then
    AddrSearch := False
  Else
    AddrSearch := True;
//  AddrSearch := Not (A = 0) or (B <= A);

  If AddrSearch Then Begin
    SearchZone := Copy(SearchStr, 1, A - 1);
    SearchNet  := Copy(SearchStr, A + 1, B - 1 - A);
    SearchNode := Copy(SearchStr, B + 1, 255);
  End;

  FileMode := 66;

  Assign     (ListFile, NodeList);
  SetTextBuf (ListFile, ListBuffer);
  Reset      (ListFile);

  Opened := IoResult = 0;
  Result := Opened;
End;

Function TNodeListSearch.FindNext (Var Res: RecNodeSearch) : Boolean;
Var
  Str : String;
Begin
  Result := False;

  If Not Opened Then Exit;

  FillChar (NodeData, SizeOf(NodeData), 0);

  While Not Eof(ListFile) Do Begin
    ReadLn (ListFile, Str);

    If (Str = '') or (Str[1] = ';') Then Continue;

    NodeData.Keyword := strUpper(strWordGet(1, Str, ','));

    If NodeData.Keyword = 'ZONE' Then Begin
      FillChar (CurAddr, SizeOf(CurAddr), 0);

      CurAddr.Zone := strS2I(strWordGet(2, Str, ','));
    End Else
    If (NodeData.Keyword = 'REGION') or (NodeData.Keyword = 'HOST') Then Begin
      CurAddr.Net := strS2I(strWordGet(2, Str, ','));
    End Else
      CurAddr.Node := strS2I(strWordGet(2, Str, ','));

    NodeData.BBSName   := strReplace(strWordGet(3, Str, ','), '_', ' ');
    NodeData.Location  := strReplace(strWordGet(4, Str, ','), '_', ' ');
    NodeData.SysopName := strReplace(strWordGet(5, Str, ','), '_', ' ');
    NodeData.Phone     := strReplace(strWordGet(6, Str, ','), '_', ' ');

    If Pos('INA:', Str) > 0 Then Begin
      Str               := Copy(Str, Pos('INA:', Str) + 4, 255);
      NodeData.Internet := Copy(Str, 1, Pos(',', Str) - 1);
    End;

    If AddrSearch Then Begin
      Result := True;

      If (SearchZone <> '?') and (CurAddr.Zone <> strS2I(SearchZone)) Then
        Result := False;

      If (SearchNet <> '?') and (CurAddr.Net <> strS2I(SearchNet)) Then
        Result := False;

      If (SearchNode <> '?') and (CurAddr.Node <> strS2I(SearchNode)) Then
        Result := False;
    End Else Begin
      Result := (Pos(SearchStr, strUpper(NodeData.BBSName)) > 0) or
                (Pos(SearchStr, strUpper(NodeData.Location)) > 0) or
                (Pos(SearchStr, strUpper(NodeData.SysopName)) > 0) or
                (Pos(SearchStr, strUpper(NodeData.Phone)) > 0) or
                (Pos(SearchStr, strUpper(NodeData.Internet)) > 0);
    End;

    If Result Then Begin
      NodeData.Address := CurAddr;
      Res              := NodeData;

      Exit;
    End;
  End;
End;

End.

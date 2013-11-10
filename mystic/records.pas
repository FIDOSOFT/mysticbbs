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
{
 ===========================================================================
 Mystic BBS Software                  Copyright (C) 1997-2013 By James Coyle
 ===========================================================================
 File    | RECORDS.PAS
 Desc    | This file holds the data file records for all data files used
           within Mystic BBS software.  Mystic BBS is compiled with the
           latest version of Free Pascal for all platforms.
 ===========================================================================
}

{$PACKRECORDS 1}

// TODOs:
// Change file listing size to Int64
// Extend msg and file base names to 70 chars?
// local qwk download/upload dirs
// rewrite event system...
//   event types, exec commands, weekly/monthly option?
// change protocol/archives to use a flag longint
//     protocol: active, no 4gig limitation, can batch, etc

Const
  mysSoftwareID  = 'Mystic BBS';
  mysCopyYear    = '1997-2013';
  mysVersion     = '1.10 A38';
  mysDataChanged = '1.10 A11';
  mysCopyNotice  = 'Copyright (C) ' + mysCopyYear + ' By James Coyle';

  {$IFDEF WIN32}
    PathChar = '\';
    LineTerm = #13#10;
    OSID     = 'Windows';
    OSType   = 0;
  {$ENDIF}

  {$IFDEF LINUX}
    PathChar = '/';
    LineTerm = #10;
    {$IFDEF CPUARM} OSID = 'Raspberry Pi'; {$ELSE} OSID = 'Linux'; {$ENDIF}
    OSType   = 1;
  {$ENDIF}

  {$IFDEF DARWIN}
    PathChar = '/';
    LineTerm = #10;
    OSID     = 'OSX';
    OSType   = 2;
  {$ENDIF}

  // OSTYPE 3 = RESERVED FOR "ALL" OS TYPES IN CONFIGURATION

  {$IFDEF OS2}
    PathChar = '\';
    LineTerm = #13#10;
    OSID     = 'OS/2';
    OSType   = 4;
  {$ENDIF}

  mysMaxAcsSize      = 30;                                      // Max ACS string size
  mysMaxPathSize     = 80;
  mysMaxMsgLines     = 1000;                                    // Max message base lines
  mysMaxInputHistory = 5;                                       // Input history stack size
  mysMaxFileDescLen  = 50;                                      // file description length per line
  mysMaxBatchQueue   = 50;                                      // max files per queue
  mysMaxVoteQuestion = 20;                                      // Max number of voting questions
  mysMaxMenuNameLen  = 20;                                      // menu name size
  mysMaxMenuItems    = 75;                                      // Maximum menu items per menu
  mysMaxMenuCmds     = 25;                                      // Max menu commands per item
  mysMaxMenuInput    = 12;
  mysMaxMenuStack    = 8;
  mysMaxThemeText    = 515;

  fn_SemFileEchoOut = 'echomail.out';
  fn_SemFileEchoIn  = 'echomail.in';
  fn_SemFileNews    = 'newsmail.out';
  fn_SemFileNet     = 'netmail.out';
  fn_SemFileQwk     = 'qwkmail.out';
  fn_tplMsgEdit     = 'ansiedit';
  fn_tplTextEdit    = 'ansitext';

  ColumnValue : Array[0..1] of Byte = (80, 40);

Type
  SmallWord = System.Word;
  Integer   = SmallInt;
  Word      = SmallWord;

  RecMessageText = Array[1..mysMaxMsgLines] of String[79];      // large global msg buffer is bad

  AccessFlagType = Set of 1..26;

  RecEchoMailAddr = Record
    Zone,
    Net,
    Node,
    Point : Word;
  End;

  RecEchoMailExport = LongInt;

  RecEchoMailNode = Record
    Index       : LongInt;
    Description : String[35];
    Active      : Boolean;
    Address     : RecEchoMailAddr;
    Domain      : String[8];
    ArcType     : String[4];
    MailType    : Byte;                                         // 0=BINKP,1=FTP,2=Dir
    binkHost    : String[60];
    ftpPassive  : Boolean;
    ProtType    : Byte;
    binkTimeout : Word;
    binkBlock   : Word;
    binkMD5     : Byte;
    ftpOutHost  : String[60];
    UNUSED2     : Word;
    ftpOutLogin : String[20];
    ftpOutPass  : String[20];
    ftpInDir    : String[60];
    ftpOutDir   : String[60];
    ftpTimeOut  : Word;
    LastRecv    : LongInt;
    LastSent    : LongInt;
    LastReset   : LongInt;
    InFiles     : Cardinal;
    InSize      : Cardinal;
    OutFiles    : Cardinal;
    OutSize     : Cardinal;
    binkPass    : String[20];
    RouteInfo   : String[128];
    AreaFixPass : String[20];
    DirInDir    : String[60];
    DirOutDir   : String[60];
    LPKTDay     : Byte;
    LPKTPtr     : Byte;
    Res         : Array[1..217] of Byte;
  End;

  RecQwkNetwork = Record
    Index       : LongInt;
    Description : String[30];
    MemberType  : Byte;                                         // 0=HUB,1=Node
    PacketID    : String[20];
    UseQWKE     : Boolean;
    UsePassive  : Boolean;
    HostName    : String[60];
    Login       : String[20];
    Password    : String[20];
    ArcType     : String[4];
    Res         : Array[1..75] of Byte;
  End;

  RecSauceInfo = Packed Record
    Title  : String[35];
    Author : String[20];
    Group  : String[20];
  End;

  RecUserOptionalField = Record
    Ask    : Boolean;
    Desc   : String[12];
    iType  : Byte;
    iField : Byte;
    iMax   : Byte;
  End;

  RecConfig = Record                                            // MYSTIC.DAT
 // INTERNALS
    DataChanged     : String[8];                                // Version of last data change
    SystemCalls     : LongInt;                                  // system caller number
    UserIdxPos      : LongInt;                                  // permanent user # position
 // SYSTEM PATHS
    SystemPath      : String[mysMaxPathSize];                   // Root mystic path
    DataPath        : String[mysMaxPathSize];
    LogsPath        : String[mysMaxPathSize];
    MsgsPath        : String[mysMaxPathSize];
    AttachPath      : String[mysMaxPathSize];
    ScriptPath      : String[mysMaxPathSize];
    QwkPath         : String[mysMaxPathSize];
    SemaPath        : String[mysMaxPathSize];
    InboundPath     : String[mysMaxPathSize];
    MenuPath        : String[mysMaxPathsize];
    TextPath        : String[mysMaxPathSize];
    OutboundPath    : String[mysMaxPathSize];
 // GENERAL SETTINGS
    BBSName         : String[30];
    SysopName       : String[30];
    SysopPW         : String[15];
    SystemPW        : String[15];
    FeedbackTo      : String[30];
    Inactivity      : Word;                                     // Inactivity seconds (0=disabled)
    DefStartMenu    : String[20];                               // Default start menu
    UNUSED          : String[20];
    DefThemeFile    : String[20];
    DefTermMode     : Byte;                                     // 0=ask 1=detect 2=detect/ask 3=ansi
    DefScreenSize   : Byte;
    DefScreenCols   : Byte;
    ChatStart       : Byte;                                     // Chat hour start
    ChatEnd         : Byte;                                     // Chat hour end
    ChatFeedback    : Boolean;                                  // E-mail sysop if page isn't answered
    ChatLogging     : Boolean;                                  // Record SysOp chat to CHAT.LOG?
    AcsSysop        : String[mysMaxAcsSize];
 // LOGIN/MATRIX
    LoginTime       : Byte;
    LoginAttempts   : Byte;
    PWAttempts      : Byte;
    PWChange        : Word;
    PWInquiry       : Boolean;
    UseMatrix       : Boolean;
    MatrixMenu      : String[20];
    MatrixPW        : String[15];
    MatrixAcs       : String[mysMaxAcsSize];
    AcsInvisLogin   : String[mysMaxAcsSize];
    AcsSeeInvis     : String[mysMaxAcsSize];
    AcsMultiLogin   : String[mysMaxAcsSize];
 // CONSOLE SETTINGS
    SysopMacro      : Array[1..8] of String[60];                // Sysop Macros f1-f8
    UseStatusBar    : Boolean;
    StatusColor1    : Byte;
    StatusColor2    : Byte;
    StatusColor3    : Byte;
 // NEW USER SETTINGS 1
    AllowNewUsers   : Boolean;
    NewUserSec      : SmallInt;
    NewUserPW       : String[15];
    NewUserEMail    : Boolean;
    StartMGroup     : Word;
    StartFGroup     : Word;
    UseUSAPhone     : Boolean;
    UserNameFormat  : Byte;                                     // 0=typed 1=upper 2=lower 3=proper
 // NEW USER SETTINGS 2
    UserDateType    : Byte;                                     // 1=MM/DD/YY 2=DD/MM/YY 3=YY/DD/MM 4=Ask
    UserEditorType  : Byte;                                     // 0=Line 1=Full 2=Ask
    UserHotKeys     : Byte;                                     // 0=no 1=yes 2=ask
    UserFullChat    : Byte;                                     // 0=no 1=yes 2=ask
    UserFileList    : Byte;                                     // 0=Normal 1=Lightbar 2=Ask
    UserReadType    : Byte;                                     // 0=normal 1=ansi 2=ask
    UserMailIndex   : Byte;                                     // 0=normal 1=ansi 2=ask
    UserReadIndex   : Byte;                                     // 0=normal 1=ansi 2=ask
    UserQuoteWin    : Byte;                                     // 0=line 1=window 2=ask
    UserProtocol    : Byte;                                     // 0=no 1=yes 2=ask
    AskTheme        : Boolean;
    AskRealName     : Boolean;
    AskAlias        : Boolean;
    AskStreet       : Boolean;
    AskCityState    : Boolean;
    AskZipCode      : Boolean;
    AskHomePhone    : Boolean;
    AskDataPhone    : Boolean;
    AskBirthdate    : Boolean;
    AskGender       : Boolean;
    AskEmail        : Boolean;
    AskUserNote     : Boolean;
    AskScreenSize   : Boolean;
    AskScreenCols   : Boolean;
 // NEW USER OPTIONAL
    OptionalField   : Array[1..10] of RecUserOptionalField;
 // MESSAGE BASE SETTINGS
    MCompress       : Boolean;
    MColumns        : Byte;
    MShowHeader     : Boolean;                                  // re-show msg header after pause
    MShowBases      : Boolean;
    MaxAutoSig      : Byte;
    Origin          : String[50];                               // Default origin line
    NetCrash        : Boolean;
    NetHold         : Boolean;
    NetKillSent     : Boolean;
    ColorQuote      : Byte;
    ColorText       : Byte;
    ColorTear       : Byte;
    ColorOrigin     : Byte;
    ColorKludge     : Byte;
    AcsExtReply     : String[mysMaxAcsSize];
    AcsFileAttach   : String[mysMaxAcsSize];
    AcsNodeLookup   : String[mysMaxAcsSize];
    FSEditor        : Boolean;
    FSCommand       : String[60];
 // ECHOMAIL NETWORKS
    NetAddress      : Array[1..30] of RecEchoMailAddr;          // echomail addresses
    NetPrimary      : Array[1..30] of Boolean;
    Res1            : Array[1..210] of Byte;
    NetDomain       : Array[1..30] of String[8];                // echomail domains (5D)
    NetDesc         : Array[1..30] of String[25];               // echomail network description
 // OFFLINE MAIL (should include local qwk path)
    qwkMaxBase      : Word;
    qwkMaxPacket    : Word;
    qwkArchive      : String[4];
    qwkBBSID        : String[8];
    qwkWelcome      : String[mysMaxPathSize];
    qwkNews         : String[mysMaxPathSize];
    qwkGoodbye      : String[mysMaxPathSize];
 // FILE BASE SETTINGS
    FCompress       : Boolean;
    FColumns        : Byte;
    FShowHeader     : Boolean;
    FShowBases      : Boolean;
    FDupeScan       : Byte;                                     // 0=no 1=yes 2=global
    UploadBase      : Word;                                     // Default upload file base
    ImportDIZ       : Boolean;
    FreeUL          : LongInt;
    FreeCDROM       : LongInt;
    MaxFileDesc     : Byte;
    FCommentLines   : Byte;
    FCommentLen     : Byte;
    FProtocol       : Char;
    TestUploads     : Boolean;
    TestPassLevel   : Byte;
    TestCmdLine     : String[mysMaxPathSize];
    AcsValidate     : String[mysMaxAcsSize];
    AcsSeeUnvalid   : String[mysMaxAcsSize];
    AcsDLUnvalid    : String[mysMaxAcsSize];
    AcsSeeFailed    : String[mysMaxAcsSize];
    AcsDLFailed     : String[mysMaxAcsSize];
 // INTERNET SERVER SETTINGS
    inetDomain      : String[25];
    inetIPBlocking  : Boolean;
    inetLogging     : Boolean;
    inetSMTPUse     : Boolean;
    inetSMTPPort    : Word;
    inetSMTPMax     : Word;
    inetSMTPDupes   : Byte;
    inetSMTPTimeOut : Word;
    inetPOP3Use     : Boolean;
    inetPOP3Port    : Word;
    inetPOP3Max     : Word;
    inetPOP3Dupes   : Byte;
    inetPOP3Delete  : Boolean;
    inetPOP3Timeout : Word;
    inetTNUse       : Boolean;
    inetTNPort      : Word;
    inetTNNodes     : Byte;
    inetTNDupes     : Byte;
    inetFTPUse      : Boolean;
    inetFTPPort     : Word;
    inetFTPMax      : Word;
    inetFTPDupes    : Byte;
    inetFTPPortMin  : Word;
    inetFTPPortMax  : Word;
    inetFTPPassive  : Boolean;
    inetFTPTimeout  : Word;
    inetNNTPUse     : Boolean;
    inetNNTPPort    : Word;
    inetNNTPMax     : Word;
    inetNNTPDupes   : Byte;
    inetNNTPTimeOut : Word;
 // UNSORTED
    inetTNHidden    : Boolean;
    ThemeOnStart    : Boolean;
    StartCodePage   : Byte;
    AcsSeeOffline   : String[mysMaxAcsSize];
  //  DefDomain       : String[8];
    //inetSMTPRelay   : String[30];
    //inetSMTPLogin   : String[30];
    //inetSMTPPW      : String[30];
    //EmailValidationLevel
    //AllowEmailPWReset
    ForceNodeList   : Boolean;
    inetInterface   : String[23];
    inetBINKPUse    : Boolean;
    inetBINKPPort   : Word;
    inetBINKPMax    : Word;
    inetBINKPDupes  : Byte;
    inetBINKPTimeOut: Word;
    inetBINKPCram5  : Boolean;
    QwkNetMenu      : String[20];
    inetFTPHideQWK  : Boolean;
    Reserved        : Array[1..756] of Char;
  End;

Const
  UserLockedOut  = $00000001;
  UserNoRatio    = $00000002;
  UserDeleted    = $00000004;
  UserNoKill     = $00000008;
  UserNoLastCall = $00000010;
  UserNoPWChange = $00000020;
  UserNoHistory  = $00000040;
  UserNoTimeout  = $00000080;
  UserQWKNetwork = $00000100;

Type
  RecUser = Record                                              // USERS.DAT
    PermIdx      : LongInt;                                     // permanent user number
    Flags        : LongInt;                                     // User Flags bitmap
    Handle       : String[30];            { Handle                       }
    RealName     : String[30];            { Real Name                    }
    Password     : String[15];            { Password                     }
    Address      : String[30];            { Address                      }
    City         : String[25];            { City                         }
    ZipCode      : String[9];             { Zipcode                      }
    HomePhone    : String[15];            { Home Phone                   }
    DataPhone    : String[15];            { Data Phone                   }
    Birthday     : LongInt;
    Gender       : Char;                  { M> Male  F> Female           }
    Email        : String[60];            { email address                }
    OptionData   : Array[1..10] of String[60];
    UserInfo     : String[30];            { user comment field           }
    Theme        : String[20];                                  // user's theme file
    AF1          : AccessFlagType;
    AF2          : AccessFlagType;        { access flags set #2          }
    Security     : SmallInt;              { Security Level               }
    Expires      : String[8];
    ExpiresTo    : Byte;
    LastPWChange : String[8];
    StartMenu    : String[20];            { Start menu for user          }
    Archive      : String[4];             { default archive extension    }
    QwkFiles     : Boolean;               { Include new files in QWK?    }
    DateType     : Byte;                  { Date format (see above)      }
    ScreenSize   : Byte;                  { user's screen length         }
    ScreenCols   : Byte;
    PeerIP       : String[20];
    PeerHost     : String[50];
    FirstOn      : LongInt;               { Date/Time of First Call      }
    LastOn       : LongInt;               { Date/Time of Last Call       }
    Calls        : LongInt;               { Number of calls to BBS       }
    CallsToday   : SmallWord;             { Number of calls today        }
    DLs          : SmallWord;             { # of downloads               }
    DLsToday     : SmallWord;             { # of downloads today         }
    DLk          : LongInt;               { # of downloads in K          }
    DLkToday     : LongInt;               { # of downloaded K today      }
    ULs          : LongInt;               { total number of uploads      }
    ULk          : LongInt;               { total number of uploaded K   }
    Posts        : LongInt;               { total number of msg posts    }
    Emails       : LongInt;               { total number of sent email   }
    TimeLeft     : LongInt;               { time left online for today   }
    TimeBank     : SmallInt;              { number of mins in timebank   }
    FileRatings  : LongInt;
    FileComment  : LongInt;
    LastFBase    : Word;                  { Last file base               }
    LastMBase    : Word;                  { Last message base            }
    LastMGroup   : Word;                  { Last group accessed          }
    LastFGroup   : Word;                  { Last file group accessed     }
    Vote         : Array[1..mysMaxVoteQuestion] of Byte;  { Voting booth data      }
    EditType     : Byte;                  { 0 = Line, 1 = Full, 2 = Ask  }
    FileList     : Byte;                  { 0 = Normal, 1 = Lightbar     }
    SigUse       : Boolean;               { Use auto-signature?          }
    SigOffset    : LongInt;               { offset to sig in AUTOSIG.DAT }
    SigLength    : Byte;                  { number of lines in sig       }
    HotKeys      : Boolean;               { does user have hotkeys on?   }
    MReadType    : Byte;                  { 0 = line 1 = full 2 = ask    }
    UseLBIndex   : Boolean;               { use lightbar index?          }
    UseLBQuote   : Boolean;               { use lightbar quote mode      }
    UseLBMIdx    : Boolean;               { use lightbar index in email? }
    UseFullChat  : Boolean;               { use full screen teleconference }
    Credits      : LongInt;
    Protocol     : Char;
    CodePage     : Byte;                  // 0 = CP437, 1 = UTF8
    QwkExtended  : Boolean;
    QwkNetwork   : LongInt;
    Reserved     : Array[1..383] of Byte;
  End;

  RecEvent = Record
    Active    : Boolean;
    Name      : String[40];
    ExecType  : Byte;  // 0=BBS, 1=Semaphore, 2=Shell, 3=Poll Nodes, 4=SendEcho
    ExecTime  : SmallInt;
    ExecDays  : Array[0..6] of Boolean;
    ExecLevel : Byte;
    Shell     : String[80];
    SemaFile  : String[80];
    Forced    : Boolean;
    Node      : Byte;
    Warning   : Byte;
    LastRan   : LongInt;
    Res       : Array[1..34] of Byte;
  End;

(* SECURITY.DAT in the data directory holds 255 records, one for each *)
(* possible security level. *)

  RecSecurity = Record                   { SECURITY.DAT                     }
    Desc       : String[30];             { Description of security level    }
    Time       : Word;                   { Time online (mins) per day       }
    MaxCalls   : Word;                   { Max calls per day                }
    MaxDLs     : Word;                   { Max downloads per day            }
    MaxDLk     : Word;                   { Max download kilobytes per day   }
    MaxTB      : Word;                   { Max mins allowed in time bank    }
    DLRatio    : Byte;                   { Download ratio (# of DLs per UL) }
    DLKRatio   : SmallInt;               { DL K ratio (# of DLed K per UL K }
    AF1        : AccessFlagType;         { Access flags for this level A-Z  }
    AF2        : AccessFlagType;         { Access flags #2 for this level   }
    Hard       : Boolean;                { Do a hard AF upgrade?            }
    StartMenu  : String[20];             { Start Menu for this level        }
    PCRatio    : SmallInt;               { Post / Call ratio per 100 calls  }
    Expires    : Word;
    ExpiresTo  : Word;
    Posts      : Word;
    PostsTo    : Word;
    Download   : Word;
    DownloadTo : Word;
    Upload     : Word;
    UploadTo   : Word;
    Calls      : Word;
    CallsTo    : Word;
    Reserved   : Array[1..64] of Byte;
  End;

  RecArchive = Record                      { ARCHIVE.DAT }
    OSType : Byte;
    Active : Boolean;
    Desc   : String[30];
    Ext    : String[4];
    Pack   : String[80];
    Unpack : String[80];
    View   : String[80];
  End;

  MScanRec = Record                    { <Message Base Path> *.SCN       }
    NewScan : Byte;                    { Include this base in new scan?  }
    QwkScan : Byte;                    { Include this base in qwk scan?  }
  End;

Const
  MBRealNames   = $00000001; // 1
  MBKillKludge  = $00000002; // 2
  MBAutosigs    = $00000004; // 3
  MBNoAttach    = $00000008; // 4
  MBPrivate     = $00000010; // 5
  MBPrivReply   = $00000020; // 6

Type
  RecMessageBase = Record                                       // MBASES.DAT
    Name      : String[40];
    QWKName   : String[13];                                     // ancient standard.. qwk base name
    NewsName  : String[60];                                     // newsgroup name spaces are replaced with .
    FileName  : String[40];
    Path      : String[mysMaxPathSize];
    BaseType  : Byte;                                           // 0=JAM  1=Squish
    NetType   : Byte;                                           // 0=Local 1=Echo 2=News 3=Net
    ReadType  : Byte;                                           // 0=User 1=Normal 2=FS
    ListType  : Byte;                                           // 0=User 1=Normal 2=FS
    ListACS   : String[mysMaxAcsSize];
    ReadACS   : String[mysMaxAcsSize];
    PostACS   : String[mysMaxAcsSize];
    NewsACS   : String[mysMaxACsSize];
    SysopACS  : String[mysMaxAcsSize];
    Sponsor   : String[30];
    ColQuote  : Byte;
    ColText   : Byte;
    ColTear   : Byte;
    ColOrigin : Byte;
    ColKludge : Byte;
    NetAddr   : Byte;                                           // Net AKA to use for this base
    Origin    : String[50];                                     // Net origin line for this base
    DefNScan  : Byte;                                           // 0 = off, 1 = on, 2 = forced
    DefQScan  : Byte;                                           // 0 = off, 1 = on, 2 = forced
    MaxMsgs   : Word;                                           // max messages allowed (used for squish)
    MaxAge    : Word;                                           // max days to keep msg (used for squish)
    Header    : String[20];                                     // standard reader msgheader
    RTemplate : String[20];                                     // fullscreen reader template
    ITemplate : String[20];                                     // lightbar index template
    Index     : Word;                                           // permanent index
    Flags     : LongInt;                                        // MB flag bits see above
    Created   : LongInt;
    EchoTag   : String[40];                                     // EchoMail Tag
    QwkNetID  : LongInt;
    QwkConfID : Word;
    Res       : Array[1..29] of Byte;                           // RESERVED
  End;

  FScanRec = Record                    { <Data Path> *.SCN               }
    NewScan : Byte;                    { Include this base in new scan?  }
    LastNew : LongInt;                 { Last file scan (packed datetime)}
  End;

Const
  FBShowUpload = $00000001;
  FBSlowMedia  = $00000002;
  FBFreeFiles  = $00000004;

Type
  RecFileBase = Record
    Index      : Word;
    Name       : String[40];
    FtpName    : String[60];
    FileName   : String[40];
    DispFile   : String[20];
    Template   : String[20];
    ListACS    : String[30];
    FtpACS     : String[30];
    DLACS      : String[30];
    ULACS      : String[30];
    CommentACS : String[30];
    SysOpACS   : String[30];
    Path       : String[80];
    DefScan    : Byte;
    Flags      : LongInt;
    Created    : LongInt;
    Res        : Array[1..32] of Byte;
    //echomail network adresss?
  End;

(* The file directory listing are stored as <FBaseRec.FileName>.DIR in    *)
(* the data directory.  Each record stores the info on one file.  File    *)
(* descriptions are stored in <FBaseRec.FileName>.DES in the data         *)
(* directory.  FDirRec.Pointer points to the file position in the .DES    *)
(* file where the file description for the file begins.  FDirRec.Lines is *)
(* the number of lines in the file description.  Each line is stored as a *)
(* Pascal-like string (ie the first byte is the length of the string,     *)
(* followed by text which is the length of the first byte                 *)

Const
  FDirOffline = $01;
  FDirInvalid = $02;
  FDirDeleted = $04;
  FDirFailed  = $08;
  FDirFree    = $10;

Type
  RecFileList = Record
    FileName  : String[70];
    Size      : LongInt;
    DateTime  : LongInt;
    Uploader  : String[30];
    Flags     : Byte;
    Downloads : LongInt;
    Rating    : Byte;
    DescPtr   : LongInt;
    DescLines : Byte;
  End;

  RecFileComment = Record              { .FCI and .FCT in DATA directory }
    UserName : String[30];
    Rating   : Byte;
    Date     : LongInt;
    Pointer  : LongInt;
    Lines    : Word;
  End;

  RecGroup = Record                    { GROUP_*.DAT                  }
    Name   : String[30];               { Group name                   }
    ACS    : String[30];               { ACS required to access group }
    Hidden : Boolean;
  End;

  PtrMenuCmd = ^RecMenuCmd;
  RecMenuCmd = Packed Record
    MenuCmd : String[2];
    Access  : String[mysMaxAcsSize];
    Data    : String[160];
    JumpID  : Byte;
  End;

  PtrMenuItem = ^RecMenuItem;
  RecMenuItem = Packed Record
    Text       : String[160];
    TextLo     : String[160];
    TextHi     : String[160];
    HotKey     : String[mysMaxMenuInput];
    Access     : String[mysMaxAcsSize];
    ShowType   : Byte;
    ReDraw     : Byte;
    JumpUp     : Byte;
    JumpDown   : Byte;
    JumpLeft   : Byte;
    JumpRight  : Byte;
    JumpEscape : Byte;
    JumpTab    : Byte;
    JumpPgUp   : Byte;
    JumpPgDn   : Byte;
    JumpHome   : Byte;
    JumpEnd    : Byte;
    CmdData    : Array[1..mysMaxMenuCmds] of PtrMenuCmd;
    Commands   : Byte;
    X          : Byte;
    Y          : Byte;
    Timer      : Word;
    TimerType  : Byte;
    TimerShow  : Boolean;
  End;

  RecMenuInfo = Packed Record
    Description : String[30];
    Access      : String[mysMaxAcsSize];
    DispFile    : String[20];
    Fallback    : String[20];
    NodeStatus  : String[30];
    Header      : String[160];
    Footer      : String[160];
    DoneX       : Byte;
    DoneY       : Byte;
    MenuType    : Byte;
    InputType   : Byte;
    CharType    : Byte;
    DispCols    : Byte;
    Global      : Boolean;
  End;

  RecPercent = Record
    BarLength : Byte;
    LoChar    : Char;
    LoAttr    : Byte;
    HiChar    : Char;
    HiAttr    : Byte;
    Format    : Byte;
    StartY    : Byte;
    Active    : Boolean;
    StartX    : Byte;
    LastPos   : Byte;
    Reserved  : Array[1..3] of Byte;
  End;

Const
  ThmAllowASCII = $00000001;
  ThmAllowANSI  = $00000002;
  ThmLightbarYN = $00000004;
  ThmFallback   = $00000008;

Type
  RecTheme = Record
    Flags        : LongInt;
    FileName     : String[20];
    Desc         : String[40];
    TextPath     : String[mysMaxPathSize];
    MenuPath     : String[mysMaxPathSize];
    ScriptPath   : String[mysMaxPathSize];
    TemplatePath : String[mysMaxPathSize];
    LineChat1    : Byte;
    LineChat2    : Byte;
    UserInputFmt : Byte;
    FieldColor1  : Byte;
    FieldColor2  : Byte;
    FieldChar    : Char;
    EchoChar     : Char;
    UNUSED       : Byte;
    TagChar      : Char;
    FileDescHi   : Byte;
    FileDescLo   : Byte;
    NewMsgChar   : Char;
    NewVoteChar  : Char;
    VotingBar    : RecPercent;
    FileBar      : RecPercent;
    MsgBar       : RecPercent;
    GalleryBar   : RecPercent;
    HelpBar      : RecPercent;
    ViewerBar    : RecPercent;
    IndexBar     : RecPercent;
    FAreaBar     : RecPercent;
    FGroupBar    : RecPercent;
    MAreaBar     : RecPercent;
    MGroupBar    : RecPercent;
    MAreaList    : RecPercent;
    Colors       : Array[0..9] of Byte;
    ColumnSize   : Byte;
    Reserved     : Array[1..198] of Byte;
  End;

  BBSListRec = Record
    cType     : Byte;
    Phone     : String[15];
    Telnet    : String[40];
    BBSName   : String[30];
    Location  : String[25];
    SysopName : String[30];
    BaudRate  : String[6];
    Software  : String[10];
    Deleted   : Boolean;
    AddedBy   : String[30];
    Verified  : LongInt;
    Res       : Array[1..6] of Byte;
  End;

(* ONELINERS.DAT found in the data directory.  This file contains all the
   one-liner data.  It can be any number of records in size. *)

  OneLineRec = Record
    Text : String[79];
    From : String[30];
  End;

(* Each record of VOTES.DAT is one question.  Mystic only allows for up *)
(* to 20 questions. *)

  VoteRec = Record                      { VOTES.DAT in DATA directory      }
    Votes    : SmallInt;                { Total votes for this question    }
    AnsNum   : Byte;                    { Total # of Answers               }
    User     : String[30];              { User name who added question     }
    ACS      : String[20];              { ACS to see this question         }
    AddACS   : String[20];              { ACS to add an answer             }
    ForceACS : String[20];              { ACS to force voting of question  }
    Question : String[79];              { Question text                    }
    Answer   : Array[1..15] of Record   { Array[1..15] of Answer data      }
                Text  : String[40];     { Answer text                      }
                Votes : SmallInt;       { Votes for this answer            }
              End;
  End;

(* CHATx.DAT is created upon startup, where X is the node number being    *)
(* loaded.  These files are used to store all the user information for a  *)
(* node.                                                                  *)

// need to have terminal emulation and remove baud rate
// add IP/host?  change booleans to bitmap? user perm index

  ChatRec = Record                     { CHATx.DAT }
    Active    : Boolean;               { Is there a user on this node?   }
    Name      : String[30];            { User's name on this node        }
    Action    : String[40];            { User's action on this node      }
    Location  : String[30];            { User's City/State on this node  }
    Gender    : Char;                  { User's gender                   }
    Age       : Byte;                  { User's age                      }
    Baud      : String[6];             { User's baud rate                }
    Invisible : Boolean;               { Is node invisible?              }
    Available : Boolean;               { Is node available?              }
    InChat    : Boolean;               { Is user in multi-node chat?     }
    Room      : Byte;                  { Chat room                       }
  End;

(* Chat room record - partially used by the multi node chat functions *)

  RoomRec = Record
    Name     : String[40];             { Channel Name }
    Reserved : Array[1..128] of Byte;  { RESERVED }
  End;

(* CALLERS.DAT holds information on the last ten callers to the BBS. This *)
(* file is always 10 records long with the most recent caller being the   *)
(* 10th record.                                                           *)

  RecLastOn = Record                                            // CALLERS.DAT
    DateTime   : LongInt;
    NewUser    : Boolean;
    PeerIP     : String[15];
    PeerHost   : String[50];
    Node       : Byte;
    CallNum    : LongInt;
    Handle     : String[30];
    City       : String[25];
    Address    : String[30];
    Gender     : Char;
    EmailAddr  : String[35];
    UserInfo   : String[30];
    OptionData : Array[1..10] of String[60];
    Reserved   : Array[1..53] of Byte;
  End;

  RecHistory = Record
    Date       : LongInt;
    Emails     : Word;
    Posts      : Word;
    Downloads  : Word;
    Uploads    : Word;
    DownloadKB : LongInt;
    UploadKB   : LongInt;
    Calls      : LongInt;
    NewUsers   : Word;
    Telnet     : Word;
    FTP        : Word;
    POP3       : Word;
    SMTP       : Word;
    NNTP       : Word;
    HTTP       : Word;
    Hourly     : Array[0..23] of Byte;
    Reserved   : Array[1..2] of Byte;
  End;

  RecProtocol = Record
    OSType  : Byte;
    Active  : Boolean;
    Batch   : Boolean;
    Key     : Char;
    Desc    : String[40];
    SendCmd : String[60];
    RecvCmd : String[60];
  End;

  RecPrompt = String[255];

  NodeMsgRec = Record
    FromNode : Byte;
    FromWho  : String[30];
    ToWho    : String[30];
    Message  : String[250];
    MsgType  : Byte;
    { 1  = Chat Pub and broadcast }
    { 2  = System message }
    { 3  = User message }
    { 4  = Chat Private }
    { 5  = chat status note }
    { 6  = chat action }
    { 7  = chat topic update }
    { 8  = user 2 user page }
    { 9  = user 2 user forced }
    { 10 = chat accepted }
    { 11 = start pipe session }
    { 12 = end pipe session }
    { 13 = terminte node }
    Room     : Byte;  { Chat room number. 0 = chat broadcast }
  End;

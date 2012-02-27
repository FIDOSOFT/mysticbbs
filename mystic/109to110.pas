Program UP110;

// set lang preferences to defaults

{$I M_OPS.PAS}

Uses
  CRT,
  DOS,
  m_Strings,
  m_FileIO;

{$I RECORDS.PAS}

Type
  OldMBaseRec = Record                    { MBASES.DAT                       }
    Name     : String[40];             { Message base name                }
    QWKName  : String[13];             { QWK (short) message base name    }
    FileName : String[40];             { Message base file name           }
    Path     : String[40];             { Path where files are stored      }
    BaseType : Byte;                   { 0 = JAM, 1 = Squish              }
    NetType  : Byte;                   { 0 = Local  1 = EchoMail          }
                                       { 2 = UseNet 3 = NetMail           }
    PostType : Byte;                   { 0 = Public 1 = Private           }
    ACS,                               { ACS required to see this base    }
    ReadACS,                           { ACS required to read messages    }
    PostACS,                           { ACS required to post messages    }
    SysopACS : String[20];             { ACS required for sysop options   }
    Password : String[15];             { Password for this message base   }
    ColQuote : Byte;                   { Quote text color                 }
    ColText  : Byte;                   { Text color                       }
    ColTear  : Byte;                   { Tear line color                  }
    ColOrigin: Byte;                   { Origin line color                }
    NetAddr  : Byte;                   { Net AKA to use for this base     }
    Origin   : String[50];             { Net origin line for this base    }
    UseReal  : Boolean;                { Use real names?                  }
    DefNScan : Byte;                   { 0 = off, 1 = on, 2 = always      }
    DefQScan : Byte;                   { 0 = off, 1 = on, 2 = always      }
    MaxMsgs  : Word;                   { Max messages to allow            }
    MaxAge   : Word;                   { Max age of messages before purge }
    Header   : String[8];              { Display Header file name         }
    Index    : SmallInt;               { QWK index - NEVER CHANGE THIS    }
  End;

  OldFBaseRec = Record                    { FBASES.DAT                      }
    Name     : String[40];             { File base name                  }
    FtpName  : String[60];             { FTP directory name              }
    Filename : String[40];             { File name                       }
    DispFile : String[20];             { Pre-list display file name      }
    Template : String[20];             { ansi file list template         }
    ListACS,                           { ACS required to see this base   }
    FtpACS,                            { ACS to see in FTP directory     }
    SysopACS,                          { ACS required for SysOp functions}
    ULACS,                             { ACS required to upload files    }
    DLACS    : String[mysMaxAcsSize];  { ACS required to download files  }
    Path     : String[120];            { Path where files are stored     }
    Password : String[20];             { Password to access this base    }
    DefScan  : Byte;                   { Default New Scan Setting        }
    ShowUL   : Boolean;
    IsCDROM  : Boolean;
    IsFREE   : Boolean;
  End;

  OldFDirRec = Record                  { *.DIR                              }
    FileName : String[70];             { File name                          }
    Size     : LongInt;                { File size (in bytes)               }
    DateTime : LongInt;                { Date and time of upload            }
    Uploader : String[30];             { User name who uploaded the file    }
    Flags    : Byte;                   { Set of FDIRFLAGS (see above)       }
    Pointer  : LongInt;                { Pointer to file description        }
    Lines    : Byte;                   { Number of description lines        }
    DLs      : Word;                   { # of times this file was downloaded}
  End;

  ExtAddrType = Record
    Zone,
    Net,
    Node,
    Point : Word;
    Desc  : String[15];
  End;

  OldConfigRec = Record               { MYSTIC.DAT in root BBS directory   }
    Version      : String[8];
    SysPath,                          { System path (root BBS directory)   }
    AttachPath,                       { File attach directory              }
    DataPath,                         { Data file directory                }
    MsgsPath,                         { Default JAM directory              }
    ArcsPath,                         { Archive software directory         }
    QwkPath,                          { Local QWK directory                }
    ScriptPath,                       { Script file directory              }
    LogsPath     : String[40];        { Log file directory                 }
    BBSName,                          { BBS Name                           }
    SysopName    : String[30];        { Sysop Name                         }
    SysopPW      : String[15];        { Sysop Password                     }
    SystemPW     : String[15];        { System Password                    }
    MaxNode      : Byte;              { Max # of nodes the BBS has         }
    DefStartMenu : String[8];         { Default start menu                 }
    DefFallMenu  : String[8];         { Default fallback menu              }
    DefThemeFile : String[8];         { Default language file              }
    DefTermMode  : Byte;              { 0 = Ask                            }
                                      { 1 = Detect                         }
                                      { 2 = Detect, ask if none            }
                                      { 3 = Force ANSI                     }
    ScreenBlank    : Byte;            { Mins before WFC screen saver starts}
    ChatStart      : SmallInt;        { Chat hour start,                   }
    ChatEnd        : SmallInt;        { Chat hour end: mins since midnight }
    ChatFeedback   : Boolean;         { E-mail sysop if page isn't answered}
    AcsSysop       : String[20];      { BBS List Editor ACS              }
    AllowNewUsers  : Boolean;         { Allow new users?                   }
    NewUserPW      : String[15];      { New user password                  }
    NewUserSec     : SmallInt;        { New user security level            }
    AskRealName,                      { Ask new users for real name?       }
    AskAlias,                         { Ask new users for an alias?        }
    AskStreet,                        { Ask new user for street address?   }
    AskCityState,                     { Ask new users for city/state?      }
    AskZipCode,                       { Ask new users for ZIP code         }
    AskHomePhone,                     { Ask new users for home phone #?    }
    AskDataPhone,                     { Ask new users for data phone #?    }
    AskBirthdate,                     { Ask new users for date of birth?   }
    AskGender,                        { Ask new users for their gender?    }
    AskTheme,                         { Ask new users to select a language?}
    AskEmail,
    AskUserNote,
    AskOption1,
    AskOption2,
    AskOption3,
    UseUSAPhone    : Boolean;         { Use XXX-XXX-XXXX format phone #s?  }
    UserEditorType : Byte;            { 0 = Line Editor }
                                      { 1 = Full Editor }
                                      { 2 = Ask         }
    UserDateType   : Byte;            { 1 = MM/DD/YY }
                                      { 2 = DD/MM/YY }
                                      { 3 = YY/DD/MM }
                                      { 4 = Ask      }
    UseMatrix      : Boolean;         { Use MATRIX-style login? }
    MatrixMenu     : String[8];       { Matrix Menu Name }
    MatrixPW       : String[15];      { Matrix Password }
    MatrixAcs      : String[20];      { ACS required to see Matrix PW }
    NewUserEmail   : Boolean;         { Force new user feedback }
    UserMailIndex  : Byte;            { use lightbar email msg index? }
    UserQuoteWin   : Byte;            { 0 = no, 1 = ues, 2 = ask }
    UserReadIndex  : Byte;            { 0 = no, 1 = yes, 2 = ask }
    Option1        : String[10];
    Option2        : String[10];
    Option3        : String[10];
    FCompress      : Boolean;         { Compress file area numbers?      }
    ImportDIZ      : Boolean;         { Search for FILE_ID.DIZ?            }
    AcsValidate    : String[20];      { ACS to auto-validate uploads       }
    AcsSeeUnvalid  : String[20];      { ACS to see unvalidated files       }
    AcsDLUnvalid   : String[20];      { ACS to download unvalidated files  }
    AcsSeeFailed   : String[20];      { ACS to see failed files            }
    AcsDLFailed    : String[20];      { ACS to download failed files       }
    TestUploads    : Boolean;         { Test uploaded files?          }
    TestPassLevel  : Byte;            { Pass errorlevel               }
    TestCmdLine    : String[60];      { Upload processor command line }
    MaxFileDesc    : Byte;            { Max # of File Description Lines  }
    FreeUL         : LongInt;         { Max space required for uploads }
    FreeCDROM      : LongInt;         { Free space required for CD Copy }
    MCompress      : Boolean;         { Compress message area numbers?   }
    qwkBBSID       : String[8];       { QWK packet display name  }
    qwkWelcome     : String[8];       { QWK welcome display file }
    qwkNews        : String[8];       { QWK news display file    }
    qwkGoodbye     : String[8];       { QWK goodbye display file }
    qwkArchive     : String[3];       { Default QWK archive      }
    qwkMaxBase     : SmallInt;        { Max # of messages per base (QWK) }
    qwkMaxPacket   : SmallInt;        { Max # of messages per packet     }
    NetAddress     : Array[1..20] of ExtAddrType;    { Network Addresses   }
    Origin         : String[50];      { Default origin line }
    ColorQuote     : Byte;            { Default quote color       }
    ColorText      : Byte;            { Default text color        }
    ColorTear      : Byte;            { Default tear line color   }
    ColorOrigin    : Byte;            { Default origin line color }
    SystemCalls    : LongInt;         { Total calls to the BBS }
    AcsInvLogin    : String[20];      { Invisible login ACS }
    ChatLogging    : Boolean;         { Record SysOp chat to CHAT.LOG? }
    StatusType     : Byte;            { 0 = 2 line, 1 = 1 line }
    UserFileList   : Byte;            { 0 = Normal, 1 = Lightbar, 2 = Ask }
    FShowHeader    : Boolean;         { Redisplay file header after pause }
    SysopMacro     : Array[1..4] of String[80];  { Sysop Macros }
    UploadBase     : SmallInt;         { Default upload file base }
    MaxAutoSig     : Byte;            { Max Auto-Sig lines }
    FColumns       : Byte;            { File area list columns }
    MColumns       : Byte;            { Message area list columns }
    netCrash       : Boolean;         { NetMail CRASH flag?    }
    netHold        : Boolean;         { NetMail HOLD flag?     }
    netKillSent    : Boolean;         { NetMail KILLSENT flag? }
    UserNameFormat : Byte;            { user input format }
    MShowHeader    : Boolean;         { redisplay message header  }
    DefScreenSize  : Byte;            { default screen length     }
    DupeScan       : Byte;            { dupescan: 0=no,1=yes,2=yes global }
    Inactivity     : Word;            { Seconds before inactivity timeout }
    UserReadType   : Byte;            { 0 = normal, 1 = ansi, 2 = ask }
    UserHotKeys    : Byte;            { 0 = no, 1 = yes, 2 = ask }
    UserIdxPos     : LongInt;         { permanent user # position }
    AcsSeeInvis    : String[20];      { ACS to see invisible users }
    FeedbackTo     : String[30];      { Feedback to user }
    AllowMulti     : Boolean;         { Allow multiple node logins? }
    StartMGroup    : Word;            { new user msg group start }
    StartFGroup    : Word;            { new user file group start }
    MShowBases     : Boolean;
    FShowBases     : Boolean;
    UserFullChat   : Byte;            { 0 = no, 1 = yes, 2 = ask }
    AskScreenSize  : Boolean;
    inetDomain     : String[25];
    inetSMTPUse    : Boolean;
    inetSMTPPort   : Word;
    inetSMTPMax    : Word;
    inetPOP3Use    : Boolean;
    inetPOP3Port   : Word;
    inetPOP3Max    : Word;
    inetTNUse      : Boolean;
    inetTNPort     : Word;
    inetTNDupes    : Byte;
    inetIPBlocking : Boolean;
    inetIPLogging  : Boolean;
    inetFTPUse     : Boolean;
    inetFTPPort    : Word;
    inetFTPMax     : Word;
    inetFTPDupes   : Byte;
    inetFTPPortMin : Word;
    inetFTPPortMax : Word;
    inetFTPAnon    : Boolean;
    inetFTPTimeout : Word;
    Reserved       : Array[1..192] of Byte;
  End;

  OldUserRec = Record                     { USERS.DAT }
    Flags     : Byte;                  { User Flags }
    Handle    : String[30];            { Handle                       }
    RealName  : String[30];            { Real Name                    }
    Password  : String[15];            { Password                     }
    Address   : String[30];            { Address                      }
    City      : String[25];            { City                         }
    ZipCode   : String[9];             { Zipcode                      }
    HomePhone : String[15];            { Home Phone                   }
    DataPhone : String[15];            { Data Phone                   }
    Birthday  : LongInt;
    Gender    : Char;                  { M> Male  F> Female           }
    EmailAddr : String[35];            { email address                }
    Option1   : String[35];            { optional question #1         }
    Option2   : String[35];            { optional question #2         }
    Option3   : String[35];            { optional question #3         }
    UserInfo  : String[30];            { user comment field           }
    AF1       : AccessFlagType;
    AF2       : AccessFlagType;        { access flags set #2          }
    Security  : SmallInt;              { Security Level               }
    StartMenu : String[8];             { Start menu for user          }
    FirstOn   : LongInt;               { Date/Time of First Call      }
    LastOn    : LongInt;               { Date/Time of Last Call       }
    Calls     : LongInt;               { Number of calls to BBS       }
    CallsToday: SmallInt;              { Number of calls today        }
    DLs       : SmallInt;              { # of downloads               }
    DLsToday  : SmallInt;              { # of downloads today         }
    DLk       : LongInt;               { # of downloads in K          }
    DLkToday  : LongInt;               { # of downloaded K today      }
    ULs       : LongInt;               { total number of uploads      }
    ULk       : LongInt;               { total number of uploaded K   }
    Posts     : LongInt;               { total number of msg posts    }
    Emails    : LongInt;               { total number of sent email   }
    TimeLeft  : LongInt;               { time left online for today   }
    TimeBank  : SmallInt;              { number of mins in timebank   }
    Archive   : String[3];             { default archive extension    }
    QwkFiles  : Boolean;               { Include new files in QWK?    }
    DateType  : Byte;                  { Date format (see above)      }
    ScrnPause : Byte;                  { user's screen length         }
    Language  : String[8];             { user's language file         }
    LastFBase : Word;                  { Last file base               }
    LastMBase : Word;                  { Last message base            }
    LastMGroup: Word;                  { Last group accessed          }
    LastFGroup: Word;                  { Last file group accessed     }
    Vote      : Array[1..mysMaxVoteQuestion] of Byte;  { Voting booth data      }
    EditType  : Byte;                  { 0 = Line, 1 = Full, 2 = Ask  }
    FileList  : Byte;                  { 0 = Normal, 1 = Lightbar     }
    SigUse    : Boolean;               { Use auto-signature?          }
    SigOffset : LongInt;               { offset to sig in AUTOSIG.DAT }
    SigLength : Byte;                  { number of lines in sig       }
    HotKeys   : Boolean;               { does user have hotkeys on?   }
    MReadType : Byte;                  { 0 = line 1 = full 2 = ask    }
    PermIdx   : LongInt;               { permanent user number        }
    UseLBIndex: Boolean;               { use lightbar index?          }
    UseLBQuote: Boolean;               { use lightbar quote mode      }
    UseLBMIdx : Boolean;               { use lightbar index in email? }
    UserFullChat : Boolean;               { use full screen teleconference }
    Reserved  : Array[1..98] of Byte;
  End;

  OldGroupRec = Record                 { GROUP_*.DAT                  }
    Name  : String[30];                { Group name                   }
    ACS   : String[20];                { ACS required to access group }
  End;

  OldArcRec = Record                   { ARCHIVE.DAT                      }
    Name   : String[20];               { Archive description              }
    Ext    : String[3];                { Archive extension                }
    Pack   : String[60];               { Pack command line                }
    Unpack : String[60];               { Unpack command line              }
    View   : String[60];               { View command line                }
  End;

  OldSecurityRec = Record              { SECURITY.DAT                     }
    Desc     : String[30];             { Description of security level    }
    Time     : SmallInt;               { Time online (mins) per day       }
    MaxCalls : SmallInt;               { Max calls per day                }
    MaxDLs   : SmallInt;               { Max downloads per day            }
    MaxDLk   : SmallInt;               { Max download kilobytes per day   }
    MaxTB    : SmallInt;               { Max mins allowed in time bank    }
    DLRatio  : Byte;                   { Download ratio (# of DLs per UL) }
    DLKRatio : SmallInt;               { DL K ratio (# of DLed K per UL K }
    AF1      : AccessFlagType;         { Access flags for this level A-Z  }
    AF2      : AccessFlagType;         { Access flags #2 for this level   }
    Hard     : Boolean;                { Do a hard AF upgrade?            }
    StartMNU : String[8];              { Start Menu for this level        }
    PCRatio  : SmallInt;               { Post / Call ratio per 100 calls  }
    Res1     : Byte;                   { reserved for future use }
    Res2     : LongInt;                { reserved for future use }
  End;

Var
  Config : RecConfig;

Function DeleteFile (FN : String) : Boolean;
Var
  F : File;
Begin
  Assign (F, FN);
{  SetFAttr (F, Archive);}
  {$I-} Erase (F); {$I+}
  DeleteFile := (IoResult = 0);
End;

Function RenameFile (Old, New: String) : Boolean;
Var
  OldF : File;
Begin
  DeleteFile(New);
  Assign (OldF, Old);
  {$I-} ReName (OldF, New); {$I+}

  Result := (IoResult = 0);
End;

Procedure WarningDisplay;
Var
  Ch : Char;
Begin
  TextAttr := 15;
  ClrScr;
  WriteLn ('MYSTIC BBS VERSION 1.10 UPGRADE UTILITY');
  TextAttr := 8;
  WriteLn ('---------------------------------------');
  WriteLn;
  TextAttr := 7;
  WriteLn ('You must be using a current installation of Mystic BBS 1.09 in');
  WriteLn ('order for this upgrade to work.  If you are not using 1.09, then');
  WriteLn ('you must upgrade to that version before proceeding with this upgrade');
  WriteLn;
  WriteLn ('You will need to have access rights to all of your BBS directory');
  WriteLn ('structure, otherwise, you may experience crashes during the');
  WriteLn ('upgrade process.');
  WriteLn;
  WriteLn ('Make sure you read the UPGRADE.TXT and follow all steps completely!');
  WriteLn;
  TextAttr := 12;
  WriteLn (^G^G'*WARNING* MAKE A BACKUP OF YOUR BBS BEFORE ATTEMPTING TO UPGRADE!');
  TextAttr := 7;
  WriteLn;
  Repeat
    Write   ('Are you ready to upgrade now (Y/N): ');
    Ch := UpCase(ReadKey);
    WriteLn (Ch);
  Until Ch in ['Y', 'N'];
  If Ch = 'N' Then Halt;
  WriteLn;
End;

Procedure ConvertConfig;
Var
  A : LongInt;
  OldConfigFile : File of OldConfigRec;
  OldConfig     : OldConfigRec;
  ConfigFile    : File of RecConfig;
Begin
  Assign (OldConfigFile, 'mystic.dat');
  {$I-} Reset (OldConfigFile); {$I+}
  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Run this program from the root Mystic BBS directory.');
    Halt(1);
  End;

  WriteLn ('[-] Updating system configuration...');

  Read  (OldConfigFile, OldConfig);
  Close (OldConfigFile);

  With OldConfig Do Begin
    Config.DataChanged    := mysDataChanged;
    Config.SystemCalls    := SystemCalls;
    Config.UserIdxPos     := UserIdxPos;
    Config.SystemPath     := SysPath;
    Config.DataPath       := DataPath;
    Config.LogsPath       := LogsPath;
    Config.MsgsPath       := MsgsPath;
    Config.AttachPath     := AttachPath;
    Config.ScriptPath     := ScriptPath;
    Config.QwkPath        := QwkPath;
    Config.SemaPath       := SysPath;
    Config.BBSName        := BBSName;
    Config.SysopName      := SysopName;
    Config.SysopPW        := SysopPW;
    Config.SystemPW       := SystemPW;
    Config.FeedbackTo     := FeedbackTo;
    Config.Inactivity     := Inactivity;
    Config.DefStartMenu   := DefStartMenu;
    Config.DefFallMenu    := DefFallMenu;
    Config.DefThemeFile   := DefThemeFile;
    Config.DefTermMode    := DefTermMode;
    Config.DefScreenSize  := DefScreenSize;
    Config.UseMatrix      := UseMatrix;
    Config.MatrixMenu     := MatrixMenu;
    Config.MatrixPW       := MatrixPW;
    Config.MatrixAcs      := MatrixAcs;
    Config.AcsSysop       := AcsSysop;
    Config.AcsInvisLogin  := AcsInvLogin;
    Config.AcsSeeInvis    := AcsSeeInvis;

    For A := 1 to 4 Do Config.SysopMacro[A] := SysopMacro[A];

    Config.ChatStart      := ChatStart;
    Config.ChatEnd        := ChatEnd;
    Config.ChatFeedback   := ChatFeedback;
    Config.ChatLogging    := ChatLogging;
    Config.AllowNewUsers  := AllowNewUsers;
    Config.NewUserSec     := NewUserSec;
    Config.NewUserPW      := NewUserPW;
    Config.NewUserEMail   := NewUserEmail;
    Config.StartMGroup    := StartMGroup;
    Config.StartFGroup    := StartFGroup;
    Config.UseUSAPhone    := UseUSAPhone;
    Config.UserNameFormat := UserNameFormat;
    Config.UserDateType   := UserDateType;
    Config.UserEditorType := UserEditorType;
    Config.UserHotKeys    := UserHotkeys;
    Config.UserFullChat   := UserFullChat;
    Config.UserFileList   := UserFileList;
    Config.UserReadType   := UserReadType;
    Config.UserMailIndex  := UserMailIndex;
    Config.UserReadIndex  := UserReadIndex;
    Config.UserQuoteWin   := UserQuoteWin;
    Config.AskTheme       := AskTheme;
    Config.AskRealName    := AskRealName;
    Config.AskAlias       := AskAlias;
    Config.AskStreet      := AskStreet;
    Config.AskCityState   := AskCityState;
    Config.AskZipCode     := AskZipCode;
    Config.AskHomePhone   := AskHomePhone;
    Config.AskDataPhone   := AskDataPhone;
    Config.AskBirthdate   := AskBirthDate;
    Config.AskGender      := AskGender;
    Config.AskEmail       := AskEmail;
    Config.AskUserNote    := AskUserNote;
    Config.AskScreenSize  := AskScreenSize;

    FillChar (Config.OptionalField, SizeOf(Config.OptionalField), #0);

    Config.OptionalField[1].Ask    := AskOption1;
    Config.OptionalField[1].Desc   := Option1;
    Config.OptionalField[1].iType  := 1;
    Config.OptionalField[1].iField := 35;
    Config.OptionalField[1].iMax   := 35;
    Config.OptionalField[2].Ask    := AskOption2;
    Config.OptionalField[2].Desc   := Option2;
    Config.OptionalField[2].iType  := 1;
    Config.OptionalField[2].iField := 35;
    Config.OptionalField[2].iMax   := 35;
    Config.OptionalField[3].Ask    := AskOption3;
    Config.OptionalField[3].Desc   := Option3;
    Config.OptionalField[3].iType  := 1;
    Config.OptionalField[3].iField := 35;
    Config.OptionalField[3].iMax   := 35;

    For A := 4 to 10 Do Begin
      Config.OptionalField[A].Ask    := False;
      Config.OptionalField[A].Desc   := 'Unused';
      Config.OptionalField[A].iType  := 1;
      Config.OptionalField[A].iField := 35;
      Config.OptionalField[A].iMax   := 35;
    End;

    Config.MCompress      := MCompress;
    Config.MColumns       := MColumns;
    Config.MShowHeader    := MShowHeader;
    Config.MShowBases     := MShowBases;
    Config.MaxAutoSig     := MaxAutoSig;
    Config.qwkMaxBase     := qwkMaxBase;
    Config.qwkMaxPacket   := qwkMaxPacket;
    Config.qwkArchive     := qwkArchive;
    Config.qwkBBSID       := qwkBBSID;
    Config.qwkWelcome     := qwkWelcome;
    Config.qwkNews        := qwkNews;
    Config.qwkGoodbye     := qwkGoodbye;
    Config.Origin         := Origin;

    FillChar (Config.NetAddress, SizeOf(Config.NetAddress), #0);

    For A := 1 to 20 Do Begin
      Config.NetAddress[A].Zone  := NetAddress[A].Zone;
      Config.NetAddress[A].Net   := NetAddress[A].Net;
      Config.NetAddress[A].Node  := NetAddress[A].Node;
      Config.NetAddress[A].Point := NetAddress[A].Point;
      Config.NetDesc[A]          := NetAddress[A].Desc;
    End;

    Config.NetCrash       := NetCrash;
    Config.NetHold        := NetHold;
    Config.NetKillSent    := NetKillSent;
    Config.ColorQuote     := ColorQuote;
    Config.ColorText      := ColorText;
    Config.ColorTear      := ColorTear;
    Config.ColorOrigin    := ColorOrigin;
    Config.FCompress      := FCompress;
    Config.FColumns       := FColumns;
    Config.FShowHeader    := FShowHeader;
    Config.FShowBases     := FShowBases;
    Config.FDupeScan      := DupeScan;
    Config.UploadBase     := UploadBase;
    Config.ImportDIZ      := ImportDIZ;
    Config.FreeUL         := FreeUL;
    Config.FreeCDROM      := FreeCDROM;
    Config.MaxFileDesc    := MaxFileDesc;
    Config.TestUploads    := TestUploads;
    Config.TestPassLevel  := TestPassLevel;
    Config.TestCmdLine    := TestCmdLine;
    Config.AcsValidate    := AcsValidate;
    Config.AcsSeeUnvalid  := AcsSeeUnvalid;
    Config.AcsDLUnvalid   := AcsDLUnvalid;
    Config.AcsSeeFailed   := AcsSeeFailed;
    Config.AcsDLFailed    := AcsDLFailed;
    Config.inetDomain     := inetDomain;
    Config.inetIPBlocking := inetIPBlocking;
    Config.inetIPLogging  := inetIPLogging;
    Config.inetSMTPUse    := inetSMTPUse;
    Config.inetSMTPPort   := inetSMTPPort;
    Config.inetSMTPMax    := inetSMTPMax;
    Config.inetPOP3Use    := inetPOP3Use;
    Config.inetPOP3Port   := inetPOP3Port;
    Config.inetPOP3Max    := inetPOP3Max;
    Config.inetTNUse      := inetTNUse;
    Config.inetTNPort     := inetTNPort;
    Config.inetTNDupes    := inetTNDupes;
    Config.inetFTPUse     := inetFTPUse;
    Config.inetFTPPort    := inetFTPPort;
    Config.inetFTPMax     := inetFTPMax;
    Config.inetFTPDupes   := inetFTPDupes;
    Config.inetFTPPortMin := inetFTPPortMin;
    Config.inetFTPPortMax := inetFTPPortMax;
    Config.inetFTPAnon    := inetFTPAnon;
    Config.inetFTPTimeout := inetFTPTimeout;

    { new in 1.10 a11 }

    Config.TemplatePath   := SysPath + 'template' + PathChar;
    Config.MenuPath       := SysPath + 'menus' + PathChar;
    Config.TextPath       := SysPath + 'text' + PathChar;
    Config.WebPath        := SysPath + 'http' + PathChar;

    Config.PWChange       := 0;
    Config.LoginAttempts  := 3;
    Config.LoginTime      := 30;
    Config.PWInquiry      := True;

    Config.DefScreenCols  := 80;

    Config.AcsMultiLogin  := 's255';

    Config.AskScreenCols  := False;

    Config.ColorKludge    := 08;
    Config.AcsCrossPost   := 's255';
    Config.AcsFileAttach  := 's255';
    Config.AcsNodeLookup  := 's255';
    Config.FSEditor       := False;
    Config.FSCommand      := '';

    Config.FCommentLines  := 10;
    Config.FCommentLen    := 79;

    Config.inetTNNodes    := MaxNode;

    Config.inetSMTPDupes  := 1;
    Config.inetSMTPTimeout := 120;

    Config.inetPOP3Dupes   := 1;
    Config.inetPOP3Delete  := False;
    Config.inetPOP3Timeout := 900;

    Config.inetNNTPUse    := False;
    Config.inetNNTPPort   := 119;
    Config.inetNNTPMax    := 8;
    Config.inetNNTPDupes  := 3;

    Config.UseStatusBar   := True;
    Config.StatusColor1   :=  9 + 1 * 16;
    Config.StatusColor2   :=  9 + 1 * 16;
    Config.StatusColor3   := 15 + 1 * 16;

    Config.PWAttempts   := 3;
    Config.FProtocol    := 'Z';
    Config.UserProtocol := 0;
  End;

  Assign  (ConfigFile, 'mystic.dat');
  ReWrite (ConfigFile);
  Write   (ConfigFile, Config);
  Close   (ConfigFile);
End;

Procedure ConvertUsers;
Var
  User        : RecUser;
  UserFile    : File of RecUser;
  OldUser     : OldUserRec;
  OldUserFile : File of OldUserRec;
  A : LongInt;
Begin
  WriteLn ('[-] Updating user database...');

  ReNameFile(Config.DataPath + 'users.dat', Config.DataPath + 'users.old');

  Assign (OldUserFile, Config.DataPath + 'users.old');
  Reset  (OldUserFile);

  Assign  (UserFile, Config.DataPath + 'users.dat');
  ReWrite (UserFile);

  While Not Eof(OldUserFile) Do Begin
    Read (OldUserFile, OldUser);

    FillChar (User, SizeOf(User), #0);

    With OldUser Do Begin
      User.PermIdx := PermIdx;
      User.Flags   := Flags;
      User.Handle  := Handle;
      User.RealName := RealName;
      User.Password := Password;
      User.Address := Address;
      User.City := City;
      User.ZipCode := ZipCode;
      User.HomePhone := HomePhone;
      User.DataPhone := DataPhone;
      User.Birthday := Birthday;
      User.Gender := Gender;
      User.Email := EmailAddr;

      FillChar (User.Optional, SizeOf(User.Optional), #0);

      User.Optional[1] := Option1;
      User.Optional[2] := Option2;
      User.Optional[3] := Option3;

      User.UserInfo := UserInfo;
      User.Theme := Language;
      User.AF1 := AF1;
      User.AF2 := AF2;
      User.Security := Security;
      User.Expires := '00/00/00';
      User.ExpiresTo := 0;
      User.LastPWChange := '00/00/00';
      User.StartMenu := StartMenu;
      User.Archive := Archive;
      User.QwkFiles := QwkFiles;
      User.DateType := DateType;
      User.ScreenSize := ScrnPause;
      User.ScreenCols := 80;
      User.PeerIP := '';
      User.PeerName := '';
      User.FirstOn := FirstOn;
      User.LastOn := LastOn;
      User.Calls := Calls;
      User.CallsToday := CallsToday;
      User.DLs := DLs;
      User.DLsToday := DLsToday;
      User.DLk := DLk;
      User.DLkToday := DLkToday;
      User.ULs := ULs;
      User.ULk := ULk;
      User.Posts := Posts;
      User.Emails := Emails;
      User.TimeLeft := TimeLeft;
      User.TimeBank := TimeBank;
      User.FileRatings := 0;
      User.FileComment := 0;
      User.LastFBase := LastFBase;
      User.LastMBase := LastMBase;
      User.LastFGroup := LastFGroup;
      User.LastMGroup := LastMGroup;

      For A := 1 to 20 Do
        User.Vote[A] := Vote[A];

      User.EditType := EditType;
      User.FileList := FileList;
      User.SigUse := SigUse;
      User.SigOffset := SigOffset;
      User.SigLength := SigLength;
      User.HotKeys := HotKeys;
      User.MReadType := MReadType;
      User.UseLBIndex := UseLBIndex;
      User.UseLBQuote := UseLBQuote;
      User.UseLBMIdx := UseLBMIdx;
      User.UseFullChat := UserFullChat;
      User.Credits := 0;
      User.Protocol := #0;
    End;

    Write (UserFile, User);
  End;

  Close (UserFile);
  Close (OldUserFile);

  DeleteFile (Config.DataPath + 'users.old');
End;

Procedure ConvertSecurity;
Var
  Sec        : RecSecurity;
  SecFile    : File of RecSecurity;
  OldSec     : OldSecurityRec;
  OldSecFile : File of OldSecurityRec;
  A          : LongInt;
Begin
  WriteLn ('[-] Updating security definitions...');

  ReNameFile(Config.DataPath + 'security.dat', Config.DataPath + 'security.old');

  Assign (OldSecFile, Config.DataPath + 'security.old');
  Reset  (OldSecFile);

  Assign  (SecFile, Config.DataPath + 'security.dat');
  ReWrite (SecFile);

  While Not Eof(OldSecFile) Do Begin
    Read (OldSecFile, OldSec);

    FillChar (Sec, SizeOf(Sec), #0);

    With OldSec Do Begin
      Sec.Desc := Desc;
      Sec.Time := Time;
      Sec.MaxCalls := MaxCalls;
      Sec.MaxDLs := MaxDLs;
      Sec.MaxDLk := MaxDLk;
      Sec.MaxTB := MaxTB;
      Sec.DLRatio := DLRatio;
      Sec.DLKRatio := DLKRatio;
      Sec.AF1 := AF1;
      Sec.AF2 := AF2;
      Sec.Hard := Hard;
      Sec.StartMenu := StartMNU;
      Sec.PCRatio := PCRatio;
    End;

    Write (SecFile, Sec);
  End;

  Close (SecFile);
  Close (OldSecFile);

  DeleteFile (Config.DataPath + 'security.old');
End;

(*
Procedure ConvertMessageBases;
Var
  MBase       : MBaseRec;
  MBaseFile   : File of MBaseRec;
  OldBase     : OldMBaseRec;
  OldBaseFile : File of OldMBaseRec;
Begin
  WriteLn ('[-] Updating message base config...');

  ReNameFile(Config.DataPath + 'mbases.dat', Config.DataPath + 'mbases.old');

  Assign (OldBaseFile, Config.DataPath + 'mbases.old');
  Reset  (OldBaseFile);

  Assign  (MBaseFile, Config.DataPath + 'mbases.dat');
  ReWrite (MBaseFile);

  While Not Eof(OldBaseFile) Do Begin
    Read (OldBaseFile, OldBase);

    With OldBase Do Begin
      MBase.Name := Name;
      MBase.QwkName := QwkName;
      MBase.FileName := FileName;
      MBase.Path := Path;
      MBase.BaseType := BaseType;
      MBase.NetType := NetType;
      MBase.PostType := PostType;
      MBase.ACS := ACS;
      MBase.ReadACS := ReadACS;
      MBase.PostACS := PostACS;
      MBase.SysopACS := SysopACS;
      MBase.Password := Password;
      MBase.ColQuote := ColQuote;
      MBase.ColTear := ColTear;
      MBase.ColText := ColText;
      MBase.ColOrigin := ColOrigin;
      MBase.NetAddr := NetAddr;
      MBase.Origin := Origin;
      MBase.UseReal := UseReal;
      MBase.DefNScan := DefNScan;
      MBase.DefQScan := DefQScan;
      MBase.MaxMsgs := MaxMsgs;
      MBase.MaxAge := MaxAge;
      MBase.Header := Header;
      MBase.Index := Index;
    End;

    Write (MBaseFile, MBase);
  End;

  Close (MBaseFile);
  Close (OldBaseFile);

  DeleteFile (Config.DataPath + 'mbases.old');
End;
*)
(*
Procedure ConvertFileBases;
Var
  FBase       : FBaseRec;
  FBaseFile   : File of FBaseRec;
  OldBase     : OldFBaseRec;
  OldBaseFile : File of OldFBaseRec;
Begin
  WriteLn ('[-] Updating file base config...');

  ReNameFile(Config.DataPath + 'fbases.dat', Config.DataPath + 'fbases.old');

  Assign (OldBaseFile, Config.DataPath + 'fbases.old');
  Reset  (OldBaseFile);

  Assign  (FBaseFile, Config.DataPath + 'fbases.dat');
  ReWrite (FBaseFile);

  While Not Eof(OldBaseFile) Do Begin
    Read (OldBaseFile, OldBase);

    With OldBase Do Begin
      FBase.Name := Name;
      FBase.FtpName := strStripMCI(FBase.Name);
      FBase.FileName := FileName;
      FBase.DispFile := DispFile;
      FBase.ListACS := ACS;
      FBase.FtpACS := ACS;
      FBase.SysopACS := SysopACS;
      FBase.ULACS := ULACS;
      FBase.DLACS := DLACS;
      FBase.Path := Path;
      FBase.Password := Password;
      FBase.ShowUL := ShowUL;
      FBase.DefScan := DefScan;
      FBase.IsCDROM := IsCDROM;
      FBase.IsFREE := IsFREE;
    End;

    Write (FBaseFile, FBase);
  End;

  Close (FBaseFile);
  Close (OldBaseFile);

  DeleteFile (Config.DataPath + 'fbases.old');
End;
*)
(*
Procedure ConvertLanguageDefs;
Var
  Lang        : LangRec;
  LangFile    : File of LangRec;
  OldLang     : OldLangRec;
  OldLangFile : File of OldLangRec;
  TempBar     : PercentRec;
Begin
  WriteLn ('[-] Updating language definitions...');

  ReNameFile(Config.DataPath + 'language.dat', Config.DataPath + 'language.old');

  Assign (OldLangFile, Config.DataPath + 'language.old');
  Reset  (OldLangFile);

  Assign  (LangFile, Config.DataPath + 'language.dat');
  ReWrite (LangFile);

  While Not Eof(OldLangFile) Do Begin
    Read (OldLangFile, OldLang);

    TempBar.BarLen := 10;
    TempBar.LoChar := '°';
    TempBar.LoAttr := 8;
    TempBar.HiChar := '²';
    TempBar.HiAttr := 25;

    With OldLang Do Begin
      Lang.FileName := FileName;
      Lang.Desc := Desc;
      Lang.TextPath := TextPath;
      Lang.MenuPath := MenuPath;
      Lang.okASCII := okASCII;
      Lang.okANSI := okANSI;
      Lang.BarYN := BarYN;
      Lang.FieldCol1 := FieldColor;
      Lang.FieldCol2 := FieldColor;
      Lang.FieldChar := InputCh;
      Lang.EchoCh := EchoCh;
      Lang.QuoteColor := QuoteColor;
      Lang.TagCh := TagCh;
      Lang.FileHi := FileHi;
      Lang.FileLo := FileLo;
      Lang.NewMsgChar := NewMsgChar;

      Lang.VotingBar := TempBar;
      Lang.FileBar := TempBar;
      Lang.MsgBar := TempBar;
    End;

    Write (LangFile, Lang);
  End;

  Close (LangFile);
  Close (OldLangFile);

  DeleteFile (Config.DataPath + 'language.old');
End;
*)

Procedure ConvertArchives;
Var
  Arc        : RecArchive;
  ArcFile    : File of RecArchive;
  OldArc     : OldArcRec;
  OldArcFile : File of OldArcRec;
Begin
  WriteLn ('[-] Updating archives...');

  If Not ReNameFile(Config.DataPath + 'archive.dat', Config.DataPath + 'archive.old') Then Begin
    WriteLn('[!] UNABLE TO FIND: ' + Config.DataPath + 'archive.dat');
    Exit;
  End;

  Assign (OldArcFile, Config.DataPath + 'archive.old');
  Reset  (OldArcFile);

  Assign  (ArcFile, Config.DataPath + 'archive.dat');
  ReWrite (ArcFile);

  While Not Eof(OldArcFile) Do Begin
    Read (OldArcFile, OldArc);

    Arc.Desc   := OldArc.Name;
    Arc.Ext    := OldArc.Ext;
    Arc.Pack   := OldArc.Pack;
    Arc.Unpack := OldArc.Unpack;
    Arc.View   := OldArc.View;
    Arc.OSType := OSType;
    Arc.Active := True;

    Write (ArcFile, Arc);
  End;

  Close (ArcFile);
  Close (OldArcFile);

  DeleteFile (Config.DataPath + 'archive.old');
End;

Procedure ConvertGroups;
Var
  Group        : RecGroup;
  GroupFile    : File of RecGroup;
  OldGroup     : OldGroupRec;
  OldGroupFile : File of OldGroupRec;
  Count        : Byte;
  FN           : String;
Begin
  WriteLn ('[-] Updating groups...');

  For Count := 1 to 2 Do Begin
    If Count = 1 Then FN := 'groups_f' Else FN := 'groups_g';

    If Not ReNameFile(Config.DataPath + FN + '.dat', Config.DataPath + FN + '.old') Then Begin
      WriteLn('[!] UNABLE TO FIND: ' + Config.DataPath + FN + '.dat');
      Continue;
    End;

    Assign (OldGroupFile, Config.DataPath + FN + '.old');
    Reset  (OldGroupFile);

    Assign  (GroupFile, Config.DataPath + FN + '.dat');
    ReWrite (GroupFile);

    While Not Eof(OldGroupFile) Do Begin
      Read (OldGroupFile, OldGroup);

      Group.Name   := OldGroup.Name;
      Group.ACS    := OldGroup.ACS;
      Group.Hidden := False;

      Write (GroupFile, Group);
    End;

    Close (GroupFile);
    Close (OldGroupFile);

    DeleteFile (Config.DataPath + FN + '.old');
  End;
End;

Procedure ConvertFileLists;
Var
  DirInfo  : SearchRec;
  OldList  : OlDFDirRec;
  OldFile  : File of OldFDirRec;
  List     : RecFileList;
  ListFile : File of RecFileList;
  FN       : String;
Begin
  WriteLn ('[-] Updating file listings...');

  FindFirst (Config.DataPath + '*.dir', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    FN := Config.DataPath + JustFile(DirInfo.Name) + '.old';

    RenameFile (Config.DataPath + DirInfo.Name, FN);

    Assign (OldFile, FN);
    Reset  (OldFile);

    Assign  (ListFile, Config.DataPath + DirInfo.Name);
    ReWrite (ListFile);

    While Not Eof(OldFile) Do Begin
      Read (OldFile, OldList);

      List.FileName  := OldList.FileName;
      List.Size      := OldList.Size;
      List.DateTime  := OldList.DateTime;
      List.Uploader  := OldList.Uploader;
      List.Flags     := OldList.Flags;
      List.Downloads := OldList.DLs;
      List.Rating    := 0;
      List.DescPtr   := OldList.Pointer;
      List.DescLines := OldList.Lines;

      Write (ListFile, List);
    End;

    Close (OldFile);
    Close (ListFile);

    DeleteFile (FN);
    FindNext   (DirInfo);
  End;

  FindClose(DirInfo);
End;

Procedure ConvertFileBases;
Var
  FBase        : RecFileBase;
  FBaseFile    : File of RecFileBase;
  OldFBase     : OldFBaseRec;
  OldFBaseFile : File of OldFBaseRec;
Begin
  WriteLn ('[-] Updating file bases...');

  If Not ReNameFile(Config.DataPath + 'fbases.dat', Config.DataPath + 'fbases.old') Then Begin
    WriteLn('[!] UNABLE TO FIND: ' + Config.DataPath + 'fbases.dat');
    Exit;
  End;

  Assign (OldFBaseFile, Config.DataPath + 'fbases.old');
  Reset  (OldFBaseFile);

  Assign  (FBaseFile, Config.DataPath + 'fbases.dat');
  ReWrite (FBaseFile);

  While Not Eof(OldFBaseFile) Do Begin
    Read (OldFBaseFile, OldFBase);

    FBase.Name       := OldFBase.Name;
    FBase.FtpName    := OldFBase.FtpName;
    FBase.FileName   := OldFBase.FileName;
    FBase.DispFile   := OldFBase.DispFile;
    FBase.Template   := 'ansiflst';
    FBase.ListACS    := OldFBase.ListACS;
    FBase.FtpACS     := OldFBase.FtpACS;
    FBase.DLACS      := OldFBase.DLACS;
    FBase.ULACS      := OldFBase.ULACS;
    FBase.SysopACS   := OldFBase.SysopACS;
    FBase.Path       := OldFBase.Path;
    FBase.DefScan    := OldFBase.DefScan;
    FBase.CommentACS := 's20';
    FBase.Flags      := 0;

    If OldFBase.ShowUL  Then FBase.Flags := FBase.Flags OR FBShowUpload;
    If OldFBase.IsCDROM Then FBase.Flags := FBase.Flags OR FBSlowMedia;
    If OldFBase.IsFREE  Then FBase.Flags := FBase.Flags OR FBFreeFiles;

    FBase.Index := 0; // calc this now?

    Write (FBaseFile, FBase);
  End;

  Close (FBaseFile);
  Close (OldFBaseFile);

  DeleteFile (Config.DataPath + 'fbases.old');
End;

Procedure ConvertMessageBases;
Var
  MBase        : RecMessageBase;
  MBaseFile    : File of RecMessageBase;
  OldMBase     : OldMBaseRec;
  OldMBaseFile : File of OldMBaseRec;
Begin
  WriteLn ('[-] Updating message bases...');

  If Not ReNameFile(Config.DataPath + 'mbases.dat', Config.DataPath + 'mbases.old') Then Begin
    WriteLn('[!] UNABLE TO FIND: ' + Config.DataPath + 'mbases.dat');
    Exit;
  End;

  Assign (OldMBaseFile, Config.DataPath + 'mbases.old');
  Reset  (OldMBaseFile);

  Assign  (MBaseFile, Config.DataPath + 'mbases.dat');
  ReWrite (MBaseFile);

  While Not Eof(OldMBaseFile) Do Begin
    Read (OldMBaseFile, OldMBase);

    MBase.Name := OldMBase.Name;
    MBase.QWKName := OldMBase.QwkName;
    MBase.NewsName := '';
    MBase.FileName := OldMBase.FileName;
    MBase.Path := OldMBase.Path;
    MBase.BaseType := OldMBase.BaseType;
    MBase.NetType := OldMBase.NetType;
    MBase.ListACS := OldMBase.ACS;
    MBase.ReadACS := OldMBase.ReadACS;
    MBase.PostACS := OldMBase.PostACS;
    MBase.SysopACS := OldMBase.SysopACS;
    MBase.Sponsor := '';
    MBase.ColQuote := OldMBase.ColQuote;
    MBase.ColText := OldMBase.ColText;
    MBase.ColTear := OldMBase.ColTear;
    MBase.ColOrigin := OldMBAse.ColOrigin;
    MBase.ColKludge := 8;
    MBase.NetAddr := OldMBase.NetAddr;
    MBase.Origin := OldMBase.Origin;
    MBase.DefNScan := OldMBase.DefNScan;
    MBase.DefQScan := OldMBase.DefQScan;
    MBase.MaxMsgs := OldMBase.MaxMsgs;
    MBase.MaxAge := OldMBase.MaxAge;
    MBase.Header := OldMBase.Header;
    MBase.RTemplate := 'ansimrd';
    MBase.ITemplate := 'ansimlst';
    MBase.Index := OldMBase.Index;

    MBase.Flags := 0;

    If OldMBase.UseReal      Then MBase.Flags := MBase.Flags or MBRealNames;
    If OldMBase.PostType = 1 Then MBase.Flags := MBase.Flags or MBPrivate;

    Write (MBaseFile, MBase);
  End;

  Close (MBaseFile);
  Close (OldMBaseFile);

  DeleteFile (Config.DataPath + 'mbases.old');
End;

Var
  ConfigFile : File of RecConfig;
Begin
  WarningDisplay;

  //COMMENT this out if mystic.dat is being converted:
//  Assign (ConfigFile, 'mystic.dat');
//  Reset  (ConfigFile);
//  Read   (ConfigFile, Config);
//  Close  (ConfigFile);

  ConvertConfig;  //1.10a11
//  ConvertUsers; //1.10a11
//ConvertSecurity; //1.10a11
//ConvertFileLists;  //1.10a11
//ConvertFileBases; //1.10a11
//ConvertMessageBases; //1.10a11

//  ConvertArchives; //1.10a1
//  ConvertGroups;   //1.10a1

  TextAttr := 12;
  WriteLn;
  WriteLn ('COMPLETE!');
End.

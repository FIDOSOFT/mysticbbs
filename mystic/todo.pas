This file showcases the direction of where this software wants to go as it
continues to expand.  Some things that will probably be mentioned will be
vague, and serve mostly to remind me of my own ideas.

The scope of this file is to document bugs, future enhancements/ideas and
design elements/issues.

BUGS AND POSSIBLE ISSUES
========================

! LBP menus arent scrolling correctly in Linux
! MUTIL FILESBBS import is not skipping FILES.BBS?
! Make sure MIS in Linux works with DOSEMU
! Node chat goes haywire at 1000 lines scrollback
! Node chat needs to actualy word wrap not nickname wrap.
! Node chat does not seem to account for prompt MCI codes when calculating
  the wrap length.
! Make sure ALL msgbase and filebase MPL variables are in place.
! Make sure copy/paste for any msg file base REGENS unique numbers.
! GOTO does not always work properly in MPL (IceDevil)
! Complex boolean evaluations using numerical variables can sometime fail to
  compile (IceDevil)
! After data file review, add missing variables to various MPL Get/Put
  functions.
! Test midnight rollovers for time (flag for user to be immune to timecheck)
! Fixed REAL2STR per Gryphon

FUTURE / IDEAS / WORK IN PROGRESS / NOTES
=========================================

- Option for QuickScan that only prints a base if it has new messages.
- Option for quickscan to show information about the messages (from,subj)
- QWK via email
- Either add Public/Private fusion type message base or allow reply via
  email or netmail option.
- mUTIL scans MSGS directory and auto-creates anything that has data files
  not related to a BBS message base.. uses a template
- Blind upload for single file upload (also message upload)
- Email validation
- Recode FCHECK into MUTIL, but also add the option to phsyically delete the
  file record instead of marking it offline.
- Add ability to ignore files from a files.bbs import
- Need ALL mystic servers to hvae the option to auto-ban an IP address if it
  connects X amount of times in X seconds.
- Outbound telnet feature
- Add "PREVIEW" option to message editors
- Finish Threaded message reader
- Add "high roller/smack talk" into BlackJack
- Add better MIS logging per server (connect, refuse, blocked, etc)
- BBS email autoforwarded to Internet email
- Ability to send internet email to people from within the BBS.
- ANSI post-processor for message uploads via FSE
- ANSI reading support in fullscreen reader
- Ability to override read-type per message base (usersetting/normal/lightbar)
- Ability to override index setting per message base (same as above)
- Ability to override listing type per file base (same as above)
- Ability to list files in a base that is not the current file base
- MCI code to show how many files are in current filebase
- Online text editor / ansi editor?
- Externalize remaining prompt data (msg flags, etc)
- File comments and rating system
- Integrate eventual online ANSI help system into configuration utilities
- Split 1 and 2 column msg/file list prompts and provide a user ability to
  pick which they'd like to use?
- File attachments and crossposts
- User-directories?  How could this be used?  Next two items?
- Ability to save a message post if a user is disconnected while posting.
- Ability to save file queue if a user is disconnected with a queue.
- User 2 User chat system and private split screen/normal chat.  For the
  Linux and OSX peeps that do not have a page sysop function.  Forced ACS
  and remote screen restore afterwards.
- NNTP server completion
- MBBSCGI (or PHP DLL) [Grymmjack might have the only MBBSCGI copy]
- If not the above then finish the HTTP server?
- SDL versions of m_input and m_output and also use SDL if that becomes
  reality for the ability to play WAV/MP3/MIDI files etc as SysOp
  notification of events and pages.  Maybe someone else can take on creating
  a mimic of m_Output_Windows and m_Input_Windows using SDL?  This would
  benefit the entire FPC community, and not just Mystic.  NetRunner could
  also have a full screen mode in Windows, Linux, and OSX.
- Possibility of OS/2 port again?  Need to find a working OS/2 VMware in
  order to do this.  Once MDL is ported over it should almost just work.
- MVIEW rewrite to mimic oldskool AcidView type deals, which would be amazing
  combined with the SDL stuff if that happens.
- Mystic-DOS rewrite or just code a file manager which would probably be a
  lot nicer using the new ANSI UI.  Combined with the text/ansi editor a
  SysOp would never need to use anything else to draw/maintain their setup
  even from a remote telnet connection in Windows, if desired.
- MIDE version using the Lazaurs GUI editor [Spec].   Maybe he would be
  interested in working on that?
- Filebase allow anonymous flag for FTP or just use FreeFiles
- Template system similar to Mystic 2 (ansiedit.ans ansiedit.ans.cfg)
- Rename Template filenames to allow more than 8 characters (for clarity)
- Does anyone use Version 7 compiled nodelists?  Worth supporting?
  How do other softwares leverage nodelists?  Reference TG, RG, RA,
  SearchLight, PCBoard, etc, and come up with the best solution.
- ANSI message upload post processor option: Auto/Disabled/Ask
- Prompt for disconect after UL or DL (and add option to filebase settings)
- Finish optional user prompts
- MCI code for FS ansi viewer?
- MCI code for # of files in current file area
- Redo random ANSI system to use A-Z instead of 1-9 can have upgrade util
  rename them automatically.
- LastOn revamp make sure its not global and new stuff is populated
- MPL fAppend?  Why didnt I add that?
- MCI code to save and restore user screen?
- BBS email forward to e-mail address
- Email pasword resets
- Email verification
- BinkP and FTP echomail polling/hosting options
-    ^^ Auto tosses into/out of Mystic
-    ^^ AREAFIX
-    ^^ TIC processing
-    ^^ Needs to be powerful enough to HUB an entire FTN network
- QWK Networking support internally WHO CAN HELP THIS HAPPEN?
- MPL trunc/round?
- Internal Zmodem and TN/Link protocols or at least MBBSPROT executable
     ^^ driver that ships with Mystic and can be used by others.
- Salted SHA-1 or SHA-256 password encryption
- User editor: Reset password/Force change... cannot view PWs

RANDOM DRUNKEN BRAINDUMP AKA DESIGN DETAILS
===========================================

-------------------------------------------------------------------------
Disconnect while posting design:

1. Before msg post or msg reply Session.Msgs.Posting is set to that bases
   Index.
2. All editors reset this value on any save/abort
3. Any disconnect checks that value.
4. If disconnect while value is set:
     a. Save MSGTMP from node's TEMP dir into DATA as msg_<UID>.tmp
          overwrite if exists
     b. Save MsgText into DATA as msg_<UID>.txt with format:
          Line 1: Base perm index
          Line 2: Msg From
          Line 3: Msg To
          Line 4: Msg Subj
          Line 5: Network address (or blank if none)
          Line 6: MsgText
             overwrite if exists
          NOTE WHAT ABOUT QUOTE TEXT - HAS TO BE SAVED TOO.
5. During LOGIN, check for msg_<UID>.txt or have menu command to do it?
6. If exists, process and prompt user:

     You were recently disconnected while posting a message:

       Base: Clever Message Base Name
         To: MOM JOKEZ R FUNNY LOLZ
       Subj: I eat hot coal.

     (R)esume post, (D)elete, or (A)sk me later?

7. Case result:
     Resume:
        Copy msg_UID.tmp if exists to MSGTMP in temp node directory
        Populate MsgText and execute editor with the other values
        Execute editor
        If save... save... this will be the hard part. :(
        If abort... delete msg_UID* since they aborted?
        What happens if they disconnect while continuing?  lol
           make sure this is handled appropriately.
     Delete:
        Delete msg_UID* in data.
     Ask later:
        Do nothing.  Keep files so Mystic asks on next login.
        Or also Mystic could ask any time a MP menu command happens
        But all of this stuff should be optional?

PROBLEM: When we localize MsgText for the ANSI viewer integration...
how will this work?  I am not sure it really can work without it being
global.  We cannot save what we do not have access to from a class.

SOLUTION: Actual MsgText should be separate from Attributes in the msg
base ANSI class.  Memory requirements almost double though for MsgText
storage if it remains global = 1000 lines x 80. 80,000 bytes memory per
node.  But attributes are only really required while READING.  So maybe
somehow it can be separated so attributes are specific to reading and
the entire class is "unused" until then?

-----------------------------------------------------------------------

CHANGE to support up to 132x50 line mode (requires lots of console
mode library updates and screensave/restore changes)

1. terminal "screen length" is no longer an option of lines but a
   selection:

     80x24
     80x49
     132x49

2. all display files and templates will have this logic added:

      if 132 mode .132.ans is the extention
      if  50 mode .50.ans is the extention
      if  25 mode then .ans is the extention

-----------------------------------------------------------------------

NEW TEMPLATE system

templates will be .cfg files with various things defined within them
based on the template.  no more "injecting" screeninfo codes (|!X) into
files.  Extentions for random ANSI templates:

ansiflst.ans = ansiflist.ans.cfg
ansiflst.an1 = ansiflist.an1.cfg

50 line mode template examples with random selected templates

ansiflst.50.ans = ansiflist.50.ans.cfg
ansiflst.50.an1 = ansiflist.50.an1.cfg

-----------------------------------------------------------------------

FILE rating / comments system

1. what type? 4 or 5 stars, or 1-10, or 0-100 rating system?
2. records already updated to allow for either

-----------------------------------------------------------------------

TANSILINEBUFFER:

LoadToBuffer (Ansi file)
SaveToFile   (Ansi file)
SaveToBuffer (Linelength)

WrapLine    (XPOS)
InsertLine
DeleteLine
JoinLines
InsertChar  (XPOS, Ch, Attr)
ReplaceChar (XPOS, Ch, Attr
ReplaceLine


This file showcases the direction of where this software wants to go as it
continues to expand.  Some things that will probably be mentioned will be
vague, and serve mostly to remind me of my own ideas.

The scope of this file is to document bugs, future enhancements/ideas and
design elements/issues.

BUGS AND POSSIBLE ISSUES
========================

! GOTO does not always work properly in MPL (IceDevil)
! Complex boolean evaluations using numerical variables can sometime fail to
  compile (IceDevil)
! After data file review, add missing variables to various MPL Get/Put
  functions.
! MYSTPACK has access denied errors (caphood)
? Reapern66 has expressed that the minimal CPU requirements may be too
  agressive.  Work with him to sort out his baseline, and potentially reduce
  the CPU requirement for new versions.  Or just tell people the code is
  already available GPL and let them compile it if it is a problem?
! RAR internal viewer does not work with files that have embedded comments

FUTURE / IDEAS / WORK IN PROGRESS / NOTES
=========================================

- ANSI post-processor for message uploads via FSE
- ANSI reading support in fullscreen reader
- Ability to override read-type per message base (usersetting/normal/lightbar)
- Ability to override index setting per message base (same as above)
- Ability to override listing type per file base (same as above)
- Ability to list files in a base that is not the current file base
- MCI code to show how many files are in current filebase
- Online ANSI file viewer (integrate with art gallery)
- Online ANSI help system
- Finish System Configuration rewrite
- Finish Data structure review
- NEWAPP.MPS
- Online text editor / ansi editor?
- Better theme selection (menu command option to select theme)
- Externalize remaining prompt data (msg flags, etc)
- File comments and rating system
- Global node message menu command (0;) = add option to ignore your own node
- Integrate eventual online ANSI help system into configuration utilities
- FUPLOAD command that does an automated Mass Upload from MBBSUTIL
- LEET "TIMER" event menu commands from Mystic 2
- In fact, replace entire menu engine iwth Mystic 2 engine which is SO far
  beyond anything built in ever... But converting old menus will be the
  challenge.  Do people really want to re-do their menu commands for all the
  added features, if that is needed?
- If not above, then possibly add whatever CAN be added in without a complete
  overhaul. (Everything except chain execution and specific key event chains
  I think?)
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
- Rework code base to compile with newly released FPC (2.6.0).
- SDL versions of m_input and m_output and also use SDL if that becomes
  reality for the ability to play WAV/MP3/MIDI files etc as SysOp
  notification of events and pages.  Maybe someone else can take on creating
  a mimic of m_Output_Windows and m_Input_Windows using SDL?  This would
  benefit the entire FPC community, and not just Mystic.  NetRunner could
  also have a full screen mode in Windows, Linux, and OSX.
- Possibility of OS/2 port again?  Need to find a working OS/2 VMware in
  order to do this.  Once MDL is ported over it should almost just work.
- How feasible is an Amiga port?  Can an emulator on the PC side be good
  enough to use as a development environment?  How reliable/complete is FPC
  for Amiga?  Does anyone even care? :)
- MBBSTOP rewrite [Sudden Death might have done similar]
- MVIEW rewrite to mimic oldskool AcidView type deals, which would be amazing
  combined with the SDL stuff if that happens.
- Mystic-DOS rewrite or just code a file manager which would probably be a
  lot nicer using the new ANSI UI.  Combined with the text/ansi editor a
  SysOp would never need to use anything else to draw/maintain their setup
  even from a remote telnet connection in Windows, if desired.
- MIDE version using the Lazaurs GUI editor [Spec].   Maybe he would be
  interested in working on that?
- PCBoard-style "quickscan"?  Yes?  No?
- This line intentionally means nothing.
- Filebase allow anonymous flag for FTP or just use FreeFiles
- Build in "telnetd" STDIO redirection into MIS in Linux/OSX
- Template system similar to Mystic 2 (ansiedit.ans ansiedit.ans.cfg)
- Rename Template filenames to allow more than 8 characters (for clarity)
- Does anyone use Version 7 compiled nodelists?  Worth supporting?
- Ignore user inactivity flag per user
- HOME and END keys added to lightbar file listings
- Default protocol per user
- ANSI message upload post processor option: Auto/Disabled/Ask
- Prompt for disconect after UL or DL (and add option to filebase settings)
- Finish optional user prompts

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
5. During LOGIN, check for msg_<UID>.txt
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

     80x25
     80x50
     132x50

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

1. what type? 4 or 5 start or 0-100 rating system?
2. records already updated to allow for either

-----------------------------------------------------------------------

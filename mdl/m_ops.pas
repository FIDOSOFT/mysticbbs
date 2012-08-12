{
  Mystic Software Development Library
  ===========================================================================
  File    | M_OPS.PAS
  Desc    | Compiler options include file.  This file is included in all
            units within MDL.  This file should create some basic
            definitions relating to the target operating system as well as
            include compiler specific compiler options (if ported to work
            with multiple compilers).  This is also where some program
            specific options will be found (such as the ability to compile
            in DEBUG or RELEASE mode, etc).

  Created | August 22, 2002
  Notes   | Sets up the following compiler directives:

            COMPILERS:
              $FPC : Set if compiler is Free Pascal

            OPERATING SYSTEMS:
              $UNIX    : Set if target OS is unix style
              $LINUX   : Set if target OS is linux
              $WINDOWS : Set if target OS is windows
              $DARWIN  : Set if target OS is Mac OSX

            FILE SYSTEMS:
              $FS_SENSITIVE : Set if target file system is case sensitive
              $FS_IGNORE    : Set if target file system is not case sensitive
  -------------------------------------------------------------------------
}

{$DEFINE DEBUG}
{.$DEFINE RELEASE}
{.$DEFINE LOGGING}

{ ------------------------------------------------------------------------- }

{$WARNINGS ON}

{$IFDEF LINUX}
  {$DEFINE UNIX}
  {$DEFINE FS_SENSITIVE}
{$ENDIF}

{$IFDEF DARWIN}
  {$DEFINE UNIX}
  {$DEFINE FS_SENSITIVE}
{$ENDIF}

{$IFDEF WIN32}
  {$DEFINE WINDOWS}
  {$DEFINE FS_IGNORE}
{$ENDIF}

{ ------------------------------------------------------------------------- }

{$MODE DELPHI}
{$EXTENDEDSYNTAX ON}
{$PACKRECORDS 1}
{$VARSTRINGCHECKS OFF}
{$TYPEINFO OFF}
{$LONGSTRINGS OFF}
{$IOCHECKS OFF}
{$BOOLEVAL OFF}
{$IMPLICITEXCEPTIONS OFF}
{$OBJECTCHECKS OFF}

{$IFDEF CPUX86_64
  {$FPUTYPE SSE64}
{$ELSE}
  {$FPUTYPE SSE}
{$ENDIF}

{$IFDEF DEBUG}
  {$DEBUGINFO ON}
  {$SMARTLINK OFF}
  {$RANGECHECKS OFF}
  {$OVERFLOWCHECKS ON}
  {$CHECKPOINTER ON}
  {$S+}
{$ELSE}
  {$DEBUGINFO OFF}
  {$SMARTLINK ON}
  {$RANGECHECKS OFF}
  {$OVERFLOWCHECKS OFF}
  {$CHECKPOINTER OFF}
  {$OPTIMIZATION LEVEL3}
  {$S-}
{$ENDIF}

{ ------------------------------------------------------------------------ }

{$IFNDEF DEBUG}
  {$IFNDEF RELEASE}
    You must define either DEBUG or RELEASE mode above in order to compile
    this program.
  {$ENDIF}
{$ENDIF}

{$IFNDEF FS_SENSITIVE}
  {$IFNDEF FS_IGNORE}
    You must define the file system type above in order to compile this
    program.
  {$ENDIF}
{$ENDIF}

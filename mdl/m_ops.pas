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
              $OS2     : Set if target OS is OS2

            FILE SYSTEMS:
              $FS_SENSITIVE : Set if target file system is case sensitive
              $FS_IGNORE    : Set if target file system is not case sensitive
  -------------------------------------------------------------------------
}

{.$DEFINE DEBUG}
{$DEFINE RELEASE}
{.$DEFINE LOGGING}

{.$DEFINE TESTEDITOR}

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

{$IFDEF OS2}
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

{$IFDEF CPU386}
  {$IFDEF CPUX86_64
    {$FPUTYPE SSE64}
  {$ELSE}
    {$FPUTYPE SSE}
  {$ENDIF}
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

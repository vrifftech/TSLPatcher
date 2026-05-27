unit UTSLPatcher;
// =============================================================================
// TSLPatcher - main logic classes for Patcher application...
// =============================================================================
// Language:       Delphi7
// Main class:     TTSLPatcher
// Design:         I wish I had done one originally, too late now... :/
// Last modified:  2007-08-13 (MKB)
// Version:        1.2.9b (WIP)
// -----------------------------------------------------------------------------
//
// SYNOPSIS:
//      Quick and dirty patch/install tool I made to be able to apply my Force Powers
//      mod to a game that already modified the relevant 2DA and TLK files. It has
//      since grown way beyond anything it was initially meant for due to interest
//      and requests from other modders, and later mod projects of mine.
//      As such the initial design was pretty much non-existent. Tread lightly... 
//
//
// Things to change some time:
// --------------------------
// * Use procedural types/events to send log values to the GUI for the AddLogLine()
//   instead of working with the text control in this class directly.
//
// * Attempt to shorten the paths used in the DoCompile() method. Try using relative
//   paths instead and see if it works without causing trouble.
//
// ChangeLog for version 1.2.9b (WIP):
// ------------------------------------
// 2007-08-13 - * Changed functioning of the AddGffField() method:
//                Attempting to add a GFF field which already exists (i.e. same label
//                and data type) will now cause TSLPatcher to modify the existing field
//                instead of trying to create a new one and aborting.
//
//
//  [b8, b9 and b10 change notes are missing here! Naughty! Need to write this down!]
//  [Get changes from the ReadMe and update this changelog.]
//
// ChangeLog for version 1.2.8b7 (WIP):
// ------------------------------------
// 2006-11-30 - * Added support for high() token to the ChangeRow 2DA modifier
//                as well.
//
// ChangeLog for version 1.2.8b6 (REL):
// ------------------------------------
// 2006-10-01 - * Added !SourceFile and !SourceFileF keys to the TLKList to allow
//                specifying custom names for append.tlk and appendf.tlk.
//
// 2006-10-01 - * Fixed a MAJOR bug with the rewrite of the ERF handling in version
//                1.2.8b5, which prevented recompiled scripts from being inserted at
//                all in the ERF file, and the ERF file itself from being saved.
//
// 2006-10-01 - * Moved roughly half of the strings from Log and Exception messages
//                in the TTSLPatcher class into the Resource StringTable.
//
// 2006-10-02 - * Fixed bug in TLK class preventing it from properly reading entries
//                with text longer than 4096 characters.
//
// 2006-10-03 - * Fixed bug in TLK class preventing it from properly writing entries
//                with text longer than 4096 characters. It used to truncate them.
//
// 2006-10-03 - * Moved all strings in TTSLPatcher and the GUI to Resource StringTable.
//
//
//
//
// ChangeLog for version 1.2.8b5 (UNRELEASED - Bugged):
// ---------------------------------------------------
// 2006-09-14 - * Added HackList to the Summary function in UMainForm. Added
//                showing SourceFile in the summary if it's different from the
//                destination file.
//
//              * (Re)Added (now) working progress bar to the main TSLPatcher window.
//
// 2006-09-26 - * Adding !OverrideType key to files that may be inserted or
//                edited in ERF/RIM files to allow controlling what should be
//                done with any identically named files existing in the override
//                folder (which would override what's just inserted into the ERF/RIM.
//                Valid key values are [ignore|warn|rename]. Handled in the function
//                HandleERFOverrideType(). 
//
// 2006-09-28 - * Added !DefaultDestination key to the CompileList which allows setting
//                the default destination for ALL files if nothing else is specified.
//                It can be overridden with the !Destination key for each individual
//                file, and if left out the value defaults to 'override' as usual.
//
// 2006-09-29 - * Modified DoCompileFiles() to keep destination ERF open until another
//                non-override destination is encountered to reduce the number of
//                instances where the ERF is reloaded.
//
//
// ChangeLog for version 1.2.8b4 (REL):
// ------------------------------------
// 2006-09-03 - * Fixed oversight where the Backup folder might not have been
//                created if backing up files to be replaced from the InstallList.
//                The folder is now created first if it is missing.
//
//              * Fixed GUI glitch when toggling the install summary in the main
//                Window, where word wrap was not turned back on when displaying
//                the info text again.
//
//
// ChangeLog for version 1.2.8b3 (REL):
// ------------------------------------
// 2006-08-28 - * Fixed nwnnsscomp bug (well, tk102 did).
//
//              * Made workaround for the incorrectly resized GUI panel in the
//                main window that a handful of users experienced. The panel is
//                now manually resized OnShow and OnResize.
//
//
//
// ChangeLog for version 1.2.8b2 (REL):
// ------------------------------------
// 2006-08-23 - * Fixed bug in RIM handling class preventing RIMs from being
//                readable by the game.
//
//
// ChangeLog for version 1.2.8b1 (REL):
// ------------------------------------
// 2006-08-09 - * Changed InstallList to allow installing into ERF/RIM files as
//                well as sub-folders within the game folder. Destination is
//                specified the same as for folders (Relative path with the game
//                folder as root), but with the ERF/RIM filename added at the end.
//
//              * Fixed bugs with !SourceFile key in the InstallList to make it
//                work properly there.
//
//              * Added a !SaveAs key to GFFList/CompileList/InstallList/SSFList
//                which will allow setting the name the file is to be installed as.
//                This will be the name of any existing files to modify as well, if
//                not in replace mode. This is the opposite of !SourceFile. While
//                !SourceFile specifies another file to use as template from
//                tslpatchdata, !SaveAs specifies another name to save data as.
//                Both can be used at the same time (but what's the point?).
//
//              * GUI: Added a "Config Summary" button to the main window which
//                will list all files that are to be modified/installed, along
//                with their replace/modify/skip setting. Allows previewing what
//                the installer will do once installation commences.
//
//
// ChangeLog for version 1.2.8b0 (REL):
// ------------------------------------
// 2006-08-06 - * Changed ERF/RIM handling to no longer work on copies of files in
//                tslpatchdata, but rather directly in sub-folders below the game
//                folder. It will now modify existing GFF files inside those files
//                as well and not overwrite unless instructed to do so.
//
//              * Switched to newer version of the ERF handler class which also
//                supports the RIM format. TSLPatcher will now handle RIM files
//                in exactly the same way as ERF files.
//
//              * Changed order of the InstallList to occur between the TLKList
//                and the 2DAList instead of being performed last during install.
//                This will allow the patcher to move any ERF/RIM files into their
//                proper place before they need to be modified by the GFFList or
//                CompileList.
//
//
// ChangeLog for version 1.2.7b9 (REL):
// ------------------------------------
// 2006-07-23 - * Changes to SetMemoryToken() and AddGffField() to allow storing
//                the complete field path in a 2DAMEMORY token by assigning the
//                keyword "!FieldPath" to a token while ADDING new GFF fields.
//
//              * Changes to UpdateGffFiles() to allow using a field path/label
//                stored in 2DAMEMORY tokens and not just static ones.
//
//
// ChangeLog for version 1.2.7b8 (UNREL):
// -------------------------------------
// 2006-07-20 - * Added a "!SourceFile" key to all sections except 2DA and TLK
//                which allows using a file with another name than the one it
//                will be installed as, as a blueprint if the file does not
//                already exist in the override folder. Could be used for making
//                different namespaces that uses mostly the same files but where
//                they contain a few variants of the same file, one for each
//                namespace.
//
// 2006-07-21 - * Added Callback method, "PathCallback", which is run when the
//                game folder install path has been set. The Main Form ties a
//                method to this procedural variable which updates the status bar
//                when triggered.
//
//              * ChangeEdit: Added OpenDlgBox buttons to the ININame and InfoName
//                input fields to allow easier selection. Added script debug checkbox
//                to the Settings screen.
//
//
// ChangeLog for Version 1.2.7b7 (REL):
// ----------------------------------
// 2006-07-08 - * GUI changes to ChangeEdit: ExclusiveCol has its own textbox, autoload
//                column labels.
//
//              * Changed Add2daLine and Copy2daLine to allow the ExclusiveColumn key
//                to occur anywhere in the section, not just at the top.
//
//
// ChangeLog for Version 1.2.7b6 (REL):
// ----------------------------------
// 2006-06-26 - * Added showing install location in the patcher window status bar.
//
//
// ChangeLog for Version 1.2.7b5 (REL):
// ----------------------------------
// 2006-05-28 - * Added Settings keys to let the patcher look for the game folder
//                in the Registry instead of asking the user for it. Set the boolean
//                key 'LookupGameFolder' to 1 in the Settings section to enable it, and
//                optionally 'LookupGameNumber' to 1 or 2 if its KotOR or TSL. If this
//                key is left out it is assumed that the game is TSL.
//
//
// ChangeLog for Version 1.2.7b4 (REL):
// ----------------------------------
// 2006-05-11 - * Adjusted path to CurrentFolder when compiling scripts to work with
//                the tk102 edition of the script compiler. Using this means you no
//                longer need to provide multiple copies of nwscript.nss for all
//                namespaces that needs to recompile scripts. Putting nwnnsscomp.exe
//                and nwscript.nss in the main tslpatchdata folder should now be enough.
//
//
// ChangeLog for Version 1.2.7b1 (REL):
// ----------------------------------
// 2006-04-29 - * UMainForm/UNamespaceForm - Added support for multiple INI config files
//                where the user can pick which one to use to install. If a 'namespaces.ini'
//                file exists a new box will open during launch prompting the user to pick
//                which setup to use.
//                WARNING: If using different folders for different setups,
//                nwscript.nss must be present in *ALL* subfolders that use it,
//                since the compiler brilliantly uses the working directory both to find the
//                NWSCRIPT.NSS file and all include files required by the scripts.
//
//              * Added new parameter to Constructor to allow specifying the path to where
//                the data files should be located. This used to be hardcoded to 'tslpatchdata'.
//
//
// ChangeLog for Version 1.2.6b3 (REL):
// -----------------------------------
// 2006-03-05 - * Added UpdateSffFiles() function to RunPatchOp() that allows updating
//                SSF (Soundset) files with StrRefs the patcher has added to Dialog.tlk.
//
// 2006-03-18 - * Recompiled with Delphi7 instead of Delphi4 to hopefully get newer versions
//                of some components and classes, making the EXE a bit less archaic.
//
// 2006-04-17 - * Added optional "SaveProcessedScripts" key to the Settings section of the INI
//                file which makes Patcher keep processed NSS files for debug purposes.
//
//
// ChangeLog for Version 1.2.5 (UNREL):
// -----------------------------------
// 2006-02-03 - * Added limited support for saving modified GFF files and recompiled NCS
//                files in an ERF file (located in "tslpatchdata") instead of putting
//                them in the Override folder. Note that the ERF file will then manually
//                have to be moved to its desired location with the InstallList function.
//
// 2006-02-07 - * Made the popup status dialog when the patcher is done report on any
//                errors and warnings that were encountered. RunPatchOp() is now a function
//                that returns status information.
//
//
// ChangeLog for Version 1.2 (UNREL):
// ---------------------------------
// 2006-01-09 - * Updated Patcher to use the new GFF Class for all GFF operations.
//
// 2006-01-10 - * Added functionality for the Patcher to add new fields to GFF files.
//                See comment header for AddGffField() for the specifics.
//
// 2006-01-14 - * Added "ScriptCompilerFlags" key to "Settings" section of INI that allows
//                setting of extra commandline parameters to nwnnsscomp.exe.
//
// 2006-01-18 - * If the TypeID of a STRUCT added to a LIST is set to "ListIndex", that
//                will be substituted for the index in the LIST the STRUCT is about to be added as.
//
// 2006-01-24 - * Changed InstallList behavior to create the specified folder path if it
//                does not already exist, instead of skipping that folder.
//
// 2006-01-26 - * Added an optional "!ReplaceFile" key for GFF Modifier lists which will
//                make the file be overwritten rather than modified in place if it already
//                exists in the override folder.
//
// 2006-01-27 - * Made Patcher display the output from nwnnsscomp.exe in the progress log
//                if the LogLevel is set to 4 (Verbose).
//
//
//
// ChangeLog for Version 1.1.7 (REL):
// -----------------------------------
// 2005-08-23 - * Added support for high() token when assigning a RowLabel to
//                a new line, not just a copied line like before.
//
//              * Added a "Required" Key to the "Settings" section. When set to a
//                filename that file must exist in the override folder in order for
//                the installer to proceed. If it does not exist, it will log an error
//                message found in the "RequiredMsg" key.
//
//
// ChangeLog for Version 1.1.6 (REL):
// ----------------------------------
// 2005-07-31 - * Added fallback plaintext logging since it seems calling RTF a
//                "standard" would be a mistake... Version incompatibilities++ :/
//                Add a "PlaintextLog" key under "Settings" in the INI to use it.
//
//
// ChangeLog for Version 1.1.2: (REL):
// -----------------------------------
// 2005-06-07 - * Added "ExclusiveColumn" key to Add2daLine() and Copy2daLine()
//                which allows skipping adding lines if a line with the same
//                value in that specified column already exist in the 2DA file.
//
//              * Added LABEL as possible index for Change2daLine().
//
//              * Added Log summary of encountered Warnings and Errors.
//
//              * Added date to start of log, and Install/Patch aware message.
//
//              * Progress log now saved to installlog.rtf when completed.
//
//              * ".\" folder now reported as "Game" folder in log for InstallList.
//
// 2005-06-09 - * Added support for overwriting HACK and INSTALL files.
//
//              * Added "ReplaceFile" key to HACK file modifier list.
//
//              * Added "Replace#" key to InstallList file list.
//
//              * Fixed user-selected files in InstallMode, now copied to Override
//                before being modified.
//
// 2005-06-10 - * Changed behavior for ExclusiveColumn flagged Add/Copy row modifiers.
//                If row already exists, it now transforms the modifier into
//                a ChangeRow modifier instead, updating the found matching line.
//
//              * Put in a simple filter to not allow the File Installer to overwrite the
//                game EXE files or the dialog.tlk file directly.
//
//
// Earlier versions: Forgot to write down what I did :/
// -----------------------------------------------------------------------------

interface

uses stdctrls, U2DAEdit, UTLKFile, UGFFFile, UST_inifile, Classes, dialogs, Forms,
     FileCtrl, Windows, SysUtils, comctrls, Graphics, UST_Common, UStrTok, UERFHandler,
     USSFFile;


// -----------------------------------------------------------------------------
// TYPE DEFINITIONS
// -----------------------------------------------------------------------------
type
TPatchFile      = (fileTlk, file2da, fileGff, fileHack, fileCompile, fileGffErf, fileSSF);
TStrRefList     = array of array of integer;
TMemory         = array of string;
TSLPathCallback = procedure(const sPath : string) of object;
TSLProgressCb   = procedure(const iCnt : integer; const iMax : integer) of object;

// Lindrigt använd exception-klass då de flesta fel behandlas internt av
// respektive funktion och felmeddelanden skickas till loggen.
EAbort = class(Exception);


// ADDED(2006-02-05) Added to allow checking if the SCRIPT has a main() or
// StartingConditional() function, and of not, tag it as an include file which
// should not be compiled.
TCompileFileInfo = record
    IsInclude : boolean;
    OrgFile   : string;
    ModFile   : string;
end;

TPatcherResult = record
    Warnings : integer;
    Errors   : integer;
end;

// Supportklass för TTSLPatcher.
TPatchFileHandler = class(TObject)
    private
        l_dobackups   : boolean;       // TRUE on Backup-funktionaliteten är aktiverad för patchern.
        l_backupfile  : boolean;       // TRUE om aktuell fil skall backas up (dvs den skall modifieras)
        l_installmode : boolean;       // TRUE om patchern kör i Installer-läge.
        l_currentfile : string;        // Namn på aktuell fil som för närvarande behandlas.
        l_currentpath : string;        // Path (utan filnamn) till ovan nämnda fil.
        l_installpath : string;        // Path till mappen spelet är installeras i (väljs av Anv.)
        l_basepath    : string;        // Path till mappen Patchern körs ifrån.
        l_datapath    : string;        // Path till mappen datafilerna finns i (normalt 'tslpatchdata')
        l_destination : string;        // ADDED(2006-08-06) Name of destination, either 'override' or path+name of ERF/RIM file.

        l_dlgbox      : TOpenDialog;   // Öppna-dialogbox patchern frågar efter filer med.
        l_parentclass : TObject;       // Referens till TTSLPatcher objektet, anv. för att logga meddelanden.
                                       // hur gör man forward-deklaration till en typ? TTSLPatcher ej def här.

        // Fult hack, men wtf, det funkar :)
        procedure AddLogLine(sText : string; iLevel : integer);
        function GetFilePath() : string;
        function GetInstallPath() : string;
    public
        constructor Create(oBox : TOpenDialog; sPath : string);

        function DoBackup() : boolean;
        function DoDestBackup() : boolean;
        function Execute(sFilename : string; patchType : TPatchFile; bOverwrite : boolean = False; sDest : string = '') : boolean; // CHANGED(2006-08-06)

        property FileName    : string     read l_currentfile;
        property FilePath    : string     read GetFilePath;
        property InstallPath : string     read GetInstallPath;
        property InstallMode : boolean    read l_installmode  write l_installmode;
        property DoBackups   : boolean    read l_dobackups    write l_dobackups;
        property BasePath    : string     read l_basepath     write l_basepath;
        property DataPath    : string     read l_datapath     write l_datapath;
        property Destination : string     read l_destination  write l_destination;   // ADDED(2006-08-06)
        property ParentClass : TObject    read l_parentclass  write l_parentclass;
end;

// Huvudklass.
TTSLPatcher = class(TObject)
    private
           l_ini  : TST_IniFile;             // INI-hanterare för changes.ini.
           l_2da  : T2DAHandler;             // Hanterare för ändring av 2DA filer.
           l_gff  : TGFFFile;                // Hanterare för ändring av GFF filer.
                                             // FIX(2006-01-09) Ändrat till nya GFF-klassen.

           l_path     : string;              // Path till mappen programmet finns i.
           l_inifile  : string;              // Namn på ini-filen som skall laddas...
           l_tlkmap   : TStrRefList;         // StrRef Token <--> Append StrRef tabell.
           l_datapath : string;              // Path till "tslpatchdata" mappen.
           l_memory   : TMemory;             // 2DAMEMORY tabell, innehåller temp-lagrad data.

           l_loglines  : integer;            // Antal rader som skrivits till loggen.
           l_logold    : boolean;            // ADDED(2005-07-31) Använd gammalt fallback-logformat...
           l_loglevel  : integer;            // Läst från ini, hur mkt log-info som ska visas.
           l_logalerts : integer;            // Antal varningar som loggats. (2005-06-07)
           l_logerrors : integer;            // Antal fel som loggats.       (2005-06-07)

           l_dlgopen     : TPatchFileHandler;  // Hämtar fram vilken fil som skall patchas.
           l_currentfile : string;             // Namn på fil som patchern jobbar med f.n.

           l_progcnt     : integer;            // ADDED(2006-09-14) Current patched file count.
           l_progmax     : integer;            // ADDED(2006-09-14) Number of files to patch.

           procedure IncrementProgress(iCnt : Integer);   // ADDED(2006-09-14)
           procedure ReadFileCountFromConfig();           // ADDED(2006-09-14)
           procedure ProcessTLKData();
           procedure AppendTLKData(iType : integer);
           procedure UpdateGffFiles();
           procedure DoInstallFiles();
           procedure UpdateSffFiles();

           function SetMemoryToken(sKey, sValue : string; iType, iVal : integer; sConstVal : string = '') : boolean;
           function GetMemoryToken(sValue : string) : string;
           function ProcessStrRefToken(sToken : string) : integer;
           function CheckForNonExclusiveLabel(sSection, sExclusive : string; var iOldRow : integer) : boolean;
           function CheckLabelIdentifier(var iIndex : integer; sSection, sKey, sValue : string) : boolean;

           procedure Add2daLine(sSection : string);
           procedure Add2daColumn(sSection : string);
           procedure Change2daLine(sSection : string);
           procedure Copy2daLine(sSection : string);
           procedure ModifyRowFallback(sSection : string; iIndex : integer);

           // ADDED(2006-08-09) Get !SourceFile and !SaveAs key values if set...
           function GetSaveFileName(sFile : string) : string;
           function GetSourceFileName(sFile : string) : string;

           // ADDED(2006-09-26) Handle !OverrideType key for (Destination != Override) files.
           procedure HandleERFOverrideType(sFilename : string; sSection : string; bNoDest : boolean=false; sAltDest : string='override');

           // ADDED(2006-01-10) Added GFF Field Add functionality... Called from UpdateGffFiles().
           function AddGffField(sSection : string; sOverridePath : string) : boolean;

           // Odokumenterad funktionalitet eftersom den har hög FUBAR-faktor...
           procedure UpdateHackFiles();
           procedure DoFileHack(sFile : string);

           // ADDED(2006-01-10) Added CompileList functionality...
           procedure DoCompileFiles();
           function ReplaceTokensInFile(sFile : string) : TCompileFileInfo;
    public
           logbuffer    : TRichEdit;
           logbuffertxt : TMemo;      // ADDED(2005-07-31) Fallback text log...

           PathCallback     : TSLPathCallback;
           ProgressCallback : TSLProgressCb; // ADDED(2006-09-14)

           procedure AddLogLine(sText : string; iLevel : integer);
           function RunPatchOperation() : TPatcherResult;

           constructor Create(sFilename : string; oOpenBox : TOpenDialog; sPath : string);
           destructor Destroy(); override;
end;


// -----------------------------------------------------------------------------
// CONSTANTS
// -----------------------------------------------------------------------------
// Feedbacklogg-meddelande klassificeringskonstanter
const LOG_LEVEL_VERBOSE       = $01;
const LOG_LEVEL_ERROR         = $02;
const LOG_LEVEL_ALERT         = $04;
const LOG_LEVEL_INFORMATION   = $08;
const LOG_LEVEL_NOTICE        = $10;

// 2DA Action-typ konstanter
const ACTION_ADD_ROW          = $01;
const ACTION_MODIFY_ROW       = $02;
const ACTION_COPY_ROW         = $04;
const ACTION_ADD_COLUMN       = $08;
const ACTION_ADD_FIELD        = $10; // ADDED(2006-01-10) GFF-action, inte 2DA, men vafan...

// Konstanter för att definiera typ av TLK-fil (dialog.tlk och dialogf.tlk)
const TLK_TYPE_NORMAL         = $01;
const TLK_TYPE_FEMALE         = $02;


// -----------------------------------------------------------------------------
// LOCALIZABLE RESOURCE STRING TABLE CONSTANTS
// -----------------------------------------------------------------------------
resourcestring
	// 2DAMEMORY token handler
    LS_LOG_TOKENERROR1           = 'Invalid 2DAMEMORY token found! Token indexes start at 1 and go up...';
    LS_LOG_TOKENERROR2           = 'Invalid memory token %s encountered, using first memory slot instead.';
    LS_LOG_TOKENFOUND            = 'Found a %s token! Storing value "%s" from 2da to memory...';
    LS_LOG_TOKENLABELERROR       = 'Error looking up row label for row index %s';
    LS_LOG_TOKENCOLUMNERROR      = 'Invalid column label "%s" passed to %s key!';
    LS_LOG_TOKENCOLLABELERROR    = 'Error looking up column label for column index %s';
    LS_LOG_INVALIDCOLLABEL       = 'Invalid column label passed to %s key!';
    LS_LOG_TOKENROWLERROR        = 'Invalid row label "%s" passed to %s key!';
    LS_LOG_LINDEXTOKENFOUND      = 'Found a %s token! Storing ListIndex "%s" from GFF to memory...';
    LS_LOG_FPATHTOKENFOUND       = 'Found a %s token! Storing Field Path "%s" from GFF to memory...';
    LS_LOG_TOKENINDEXERROR1      = 'Invalid memory token %s encountered, assuming first memory slot.';
    LS_LOG_TOKENINDEXERROR2      = 'Invalid memory token %s encountered, unable to insert a proper value into cell or field!';
    LS_LOG_GETTOKENVALUE         = 'Found a %s value, substituting with value "%s" in memory...';
    
    // TLK file handler
    LS_LOG_LOADINGSTRREFTOKENS   = 'Loading StrRef token table...';
    LS_LOG_LOADEDSTRREFTOKENS    = '%s StrRef tokens found and indexed.';
    LS_EXC_TLKFILETYPEMISMATCH   = 'Internal error, invalid TLK file type specified. This should never happen.';
    LS_LOG_APPENDFEEDBACK        = 'Appending strings to TLK file "%s"';
    LS_LOG_TLKENTRYMATCHEXIST    = 'Identical string for append StrRef %s found in %s StrRef %s, reusing it instead.';
    LS_LOG_APPENDTLKENTRY        = 'Appending new entry to %s, new StrRef is %s';
    LS_LOG_MAKETLKBACKUP         = 'Saving unaltered backup copy of %s file in %s';
    LS_LOG_TLKSUMMARY1           = '%s file updated with %s new entries, %s entries already existed.';
    LS_LOG_TLKSUMMARY2           = '%s file updated with %s new entries.'; 
    LS_LOG_TLKSUMMARY3           = '%s file not updated, all %s entries were already present.';
    LS_LOG_TLKSUMMARYWARNING     = 'Warning: No new entries appended to %s. Possible missing entries in append.tlk referenced in the TLKList.';
    LS_LOG_TLKFILEMISSING        = 'Unable to load specified %s file! Aborting...';
    LS_EXC_TLKFILEMISSING        = 'No TLK file loaded. Unable to proceed.';
    LS_LOG_TLKNOTSELECTED        = 'No %s file specified. Unable to proceed!';
    LS_LOG_UNKNOWNSTRREFTOKEN    = 'Encountered StrRef token "%s" in modifier list that was not present in the TLKList! Value set to StrRef #0.';
    
    // Override fileexists check and response
    LS_LOG_OVRCHECKNOFILE        = 'Override check: No file with name "%s" found in override folder.';
    LS_LOG_OVRCHECKEXISTWARN     = 'A file named %s already exists in the override folder! This may cause incompatibility with the one used by this mod!';
    LS_LOG_OVRCHECKRENAMED       = 'A file named %s already existed in the override folder! This existing file has been renamed to %s to allow the one in this Mod to be used!';
    LS_LOG_OVRRENAMEFAILED       = 'A file named %s already exists in the override folder! Renaming existing file to %s failed! The file might be write-protected or a file with the new name already exist.';
    LS_LOG_OVRCHECKSILENTWARN    = 'Warning: A file named %s already exists in the override folder. It will override the one in the ERF/RIM archive in-game.';
    
    // GFF file handler
    LS_LOG_GFFSECTIONMISSING     = 'Unable to locate section "%s" when attempting to add GFF Field, skipping...';
    LS_LOG_GFFPARENTALERROR      = 'Parent field at "%s" does not exist or is not a LIST or STRUCT! Unable to add new Field "%s"...';
    LS_LOG_GFFMISSINGLABEL       = 'No field label has been specified for new field in section "%s"! Unable to create field...';
    LS_LOG_GFFLABELEXISTS        = 'A Field with the label "%s" already exists at "%s", skipping it...';
    LS_LOG_GFFLABELEXISTSMOD     = 'A Field with the label "%s" already exists at "%s", modifying instead...';
    LS_LOG_GFFINVALIDSTRREF      = 'Invalid StrRef value "%s" when attempting to add ExoLocString. Defaulting to -1...';
    LS_LOG_GFFINVALIDTYPEDATA    = 'Invalid field type "%s" or data specified in section "%s" when trying to add fields to %s, skipping...';
    LS_LOG_GFFADDEDSTRUCT        = 'Added %s, index %s, at position "%s"';
    LS_LOG_GFFADDEDFIELD         = 'Added %s field "%s" at position "%s"';
    LS_LOG_GFFPROCSUBFIELDS      = 'Processing new sub-fields at %s.';
    LS_LOG_GFFMODIFYING          = 'Modifying GFF format files...';
    LS_LOG_GFFNOINSTRUCTION      = 'No instruction section found for file %s, skipping...';
    LS_LOG_GFFMODIFYINGFILE      = 'Modifying GFF file %s...';
    LS_LOG_GFFBLANKFIELDLABEL    = 'Blank Gff Field Label encountered in instructions, skipping...';
    LS_LOG_GFFNEWFIELDADDED      = 'Added new field to GFF file %s...';
    LS_LOG_GFFBLANKVALUE         = 'Blank value encountered for GFF field label %s, skipping...';
    LS_LOG_GFFMODIFIEDVALUE      = 'Modified value "%s" to field "%s" in %s.';
    LS_LOG_GFFINCORRECTLABEL     = 'Unable to find a field label matching "%s" in %s, skipping...';
    LS_LOG_GFFBACKUPFILE         = 'Saving unaltered backup copy of %s file in %s';
    LS_LOG_GFFBACKUPDEST         = 'Saving unaltered backup copy of destination file %s file in %s';
    LS_LOG_GFFMODFIELDSUMMARY    = 'Modified %s fields in "%s"...';
    LS_LOG_GFFINSERTDONE         = 'Finished updating GFF file "%s" in "%s"...';
    LS_LOG_GFFSAVEINERFORRIM     = 'Saving modified file "%s" in archive "%s".';
    LS_LOG_GFFUPDATEFINISHED     = 'Finished updating GFF file "%s"...';
    LS_LOG_GFFNOCHANGES          = 'No changes could be applied to GFF file %s.';
    LS_LOG_GFFNOMODIFIERS        = 'No GFF modifier instructions found for file %s, skipping...';
    LS_LOG_GFFCANTLOADFILE       = 'Unable to load file %s! Skipping...';
    LS_LOG_GFFNOFILEOPENED       = 'No valid %s file was opened, skipping...';
    LS_LOG_GFFMISSINGLISTSTRUCT  = 'Could not find struct to modify in parent list at %s, unable to add new field!';
    
    // Recompile file handler
    LS_LOG_NCSBEGINNING          = 'Modifying and compiling scripts...';
    LS_LOG_NCSCOMPILERMISSING    = 'Could not locate nwnsscomp.exe in the TSLPatchData folder! Unable to compile scripts!';
    LS_LOG_NCSPROCESSINGTOKENS   = 'Replacing tokens in script %s...';
    LS_LOG_NCSCOMPILINGSCRIPT    = 'Compiling modified script %s...';
    LS_LOG_NCSCOMPILEROUTPUT     = 'NWNNSSComp says: %s';
    LS_LOG_NCSDESTBACKUP         = 'Saving unaltered backup copy of destination file %s in %s';
    LS_LOG_NCSFILEEXISTSKIP      = 'File "%s" already exists in archive "%s", file skipped...';
    LS_LOG_NCSSAVEINERFORRIM     = 'Adding script "%s" to archive "%s"...';
    LS_LOG_NCSCOMPILEDNOTFOUND   = 'Unable to find compiled version of file "%s"! The compilation probably failed! Skipping...';
    LS_LOG_NCSINCLUDEDETECTED    = 'Script "%s" has no start function, assuming include file. Compile skipped...';
    LS_LOG_NCSPROCNSSMISSING     = 'Unable to find processed version of file, %s, cannot compile it!';
    LS_LOG_NCSSAVEERFRIM         = 'Saving changes to ERF/RIM file %s...';
    
    // SSF file handler
    LS_LOG_SSFNOMODIFIERS        = 'File "%s" has no modifier section specified! Skipping it...';
    LS_LOG_SSFFILENOTFOUND       = 'File %s could not be found! Skipping it...';
    LS_LOG_SSFMODSTRREFS         = 'Modifying StrRefs in Soundset file "%s"...';
    LS_LOG_SSFSETTINGENTRY       = 'Setting Soundset entry "%s" to %s...';
    LS_LOG_SSFINVALIDSTRREF      = 'Unable to set StrRef for entry "%s", %s is not a valid StrRef value!';
    LS_LOG_SSFUPDATESUMMARY      = 'Finished updating %s entries in file "%s".';
    LS_LOG_SSFEXCEPTIONERRORS    = '%s [%s] - file skipped!';
    LS_LOG_SSFNOFILE             = 'No %s file was specified! Skipping it...';
    
    // Run Patch Operation
    LS_LOG_RPOINSTALLSTART       = 'Installation started %s...';
    LS_LOG_RPOPATCHSTART         = 'Patch operation started %s...';
    LS_LOG_RPOSUMMARYWARN        = 'Done. Changes have been applied, but %s warnings were encountered.';
    LS_LOG_RPOSUMMARYERROR       = 'Done. Some changes may have been applied, but %s errors were encountered!';
    LS_LOG_RPOSUMMARYWARNERROR   = 'Done. Some changes may have been applied, but %s errors and %s warnings were encountered!';
    LS_LOG_RPOSUMMARY            = 'Done. All changes have been applied.';
    LS_LOG_RPOGENERALEXCEPTION   = 'Unhandled exception: %s (%s)';
    
    // 2DA Handler
    LS_LOG_2DAFILENOTFOUND       = 'Unable to find 2DA file "%s" to modify! Skipping file...';
    LS_LOG_2DAINVALIDMODIFIER    = 'Invalid modifier type "%s" found for modifier label "%s". Skipping...';
    LS_LOG_2DABACKUPFILE         = 'Saving unaltered backup copy of %s in %s';
    LS_LOG_2DAFILEUPDATED        = 'Updated 2DA file %s.';
    LS_LOG_2DALOADERROR          = 'Unable to load the 2DA file %s! Skipping it...';
    LS_LOG_2DANOFILESELECTED     = 'No %s file was specified! Skipping it...';
    LS_LOG_EXCLUSIVECOLINVALID   = 'Invalid Exclusive column label "%s" specified, ignoring...';
    LS_LOG_EXCLUSIVEMATCHFOUND   = 'Matching value in column %s found for existing row %s...';
    LS_LOG_NOEXCLUSIVEVALUESET   = 'No value has been assigned to column %s for new 2DA line in modifier "%s" with Exclusive checking enabled! Skipping line...';
    LS_LOG_2DAEXROWNOTFOUND      = 'Error locating row when trying to modify existing Exclusive row in modifier "%s".';
    LS_LOG_2DAEXROWINDEXTOOHIGH  = 'Too high row-number encountered when trying to modify existing Exclusive row in modifier "%s".';
    LS_LOG_2DAEXROWMATCH         = 'New Exclusive row matched line %s in 2DA file %s, modifying existing line instead.';
    LS_LOG_2DAINVALIDCOLLABEL    = 'Invalid column label "%s" encountered! Skipping entry...';
    LS_LOG_2DAHIGHTOKENRLFOUND   = 'Setting row label to next HIGHEST value %s.';
    LS_LOG_2DAADDINGROW          = 'Adding new row (index %s) to 2DA file %s...';
    LS_LOG_2DASETROWLABELERROR   = 'Unable to set new row label "%s" in modifier + "%s"!';
    LS_LOG_2DAHIGHTOKENVALUE     = 'Setting added row column %s to next HIGHEST value %s.';
    LS_LOG_2DAADDROWERROR        = 'An error occured while trying to add new line to 2DA in modifier "%s"!';
    LS_LOG_2DANOLABELCOL         = '%s used as index when changing line in modifier "%s" but 2DA file has no label column! Skipping...';
    LS_LOG_2DANONEXCLUSIVECOL    = 'Warning, multiple rows matching Label Index found! Last found row will be used...';
    LS_LOG_2DAMULTIMATCHINDEX    = 'Multiple matches for specified Label Index, previously found row %s, now found row %s.';
    LS_LOG_2DAMODIFYLINE         = 'Modifying line (index %s) in 2DA file %s...';
    LS_LOG_2DANOINDEXFOUND       = 'No RowIndex/RowLabel identifier for row to modify found at top of modifier list! Unable to apply modifier "%s".';
    LS_LOG_2DAADDCOLUMN          = 'Adding new column to 2DA file %s...';
    LS_LOG_2DACOLEXISTS          = 'A column with the label "%s" already exists in %s, unable to add new column!';
    LS_LOG_2DAINVALIDROWLABEL    = 'Invalid row label %s encountered! Skipping entry...';
    LS_LOG_2DANEWROWLABELHIGH    = 'Setting new row label to next HIGHEST value %s.';
    LS_LOG_2DACOPYFAILED         = 'Error! Failed to copy line in 2DA! Skipping...';
    LS_LOG_2DACOPYINGLINE        = 'Copying line %s to new line %s in %s.';
    LS_LOG_2DAINCTOPENCOPY       = 'Incrementing value of copied row for column %s by %s, new value is %s.';
    LS_LOG_2DAINCFAILED          = 'Row value increment failed! Specified modifier "%s" is not a number. Old row value not changed.';
    LS_LOG_2DAINCFAILEDNONUM     = 'Row value increment failed! Specified row column does not contain a number. Old row value not changed.';
    LS_LOG_2DACOPYHIGH           = 'Setting copied row column %s to next HIGHEST value %s.';
    
    // HACK List handler
    LS_LOG_HAKSTART              = 'Modifying binary files...';
    LS_LOG_HAKMODIFYFILE         = 'Modifying binary file "%s"...';
    LS_LOG_HAKNOOFFSETS          = 'No offsets found for file %s, skipping...';
    LS_LOG_HAKNOVALIDFILE        = 'No valid %s file found! Skipping file.';
    LS_LOG_HAKBACKUPFILE         = 'Saving unaltered backup copy of %s in %s.';
    LS_LOG_HAKMODIFYINGDATA      = 'Modifying file %s, setting value at offset "%s" to "%s".';
    LS_LOG_HAKINVALIDOFFSET      = 'Invalid offset(%s) or value(%s) modifier for file %s. Skipping...';
    
	// Install List Handler
	LS_LOG_INSSTART              = 'Installing unmodified files...';
	LS_LOG_INSDESTINVALID        = 'Destination file "%s" does not appear to be a valid ERF or RIM archive! Skipping section...';
	LS_LOG_INSDESTNOTEXIST       = 'Destination file "%s" does not exist at the specified location! Skipping section...';
	LS_LOG_INSCREATEFOLDER       = 'Folder %s did not exist, creating it...';
	LS_LOG_INSFOLDERCREATEFAIL   = 'Unable to create folder %s! Skipping folder...';
	LS_LOG_INSBACKUPFILE         = 'Saving unaltered backup copy of destination file %s in %s.';
	LS_LOG_INSNOEXEPLEASE        = 'Skipping file %s, this Installer will not overwrite EXE files!';
	LS_LOG_INSENOUGHTLK          = 'Skipping file %s, this Installer will not overwrite dialog.tlk directly.';
	LS_LOG_INSSKELETONKEY        = 'Skipping file %s, this Installer will not overwrite the chitin.key file.';
	LS_LOG_INSBIFTHEUNDERSTUDY   = 'Skipping file %s, this Installer will not overwrite BIF data files.';
	LS_LOG_INSREPLACERENAME      = 'Renaming and replacing file "%s" to "%s" in the %s folder...';
	LS_LOG_INSREPLACE            = 'Replacing file %s in the %s folder...';
	LS_LOG_INSLASKIP             = 'A file named %s already exists in the %s folder. Skipping file...';
	LS_LOG_INSRENAMECOPY         = 'Renaming and copying file "%s" to "%s" to the %s folder...';
	LS_LOG_INSCOPYFILE           = 'Copying file %s to the %s folder...';
	LS_LOG_INSREPLACERENAMEFILE  = 'Renaming and replacing file "%s" to "%s" in the %s archive...';
	LS_LOG_INSREPLACEFILE        = 'Replacing file %s in the %s archive...';
	LS_LOG_INSEXCEPTIONSKIP      = '%s Skipping...';
	LS_LOG_INSLASKIPFILE         = 'A file named %s already exists in the %s archive. Skipping file...';
	LS_LOG_INSRENAMEADDFILE      = 'Renaming and adding file "%s" to "%s" in the %s archive...';
	LS_LOG_INSADDFILE            = 'Adding file %s to the %s archive...';
	LS_LOG_INSCOPYFAILED         = 'Unable to copy file "%s", file does not exist!';
	LS_LOG_INSNOMODIFIERS        = 'No install instructions (%s) found for folder %s.';
	LS_LOG_INSINVALIDDESTINATION = 'Invalid install location "%s" encountered! Skipping...';
	
	// File handler
	LS_EXC_FHRENAMEFAILED        = 'Unable to locate source file "%s" to rename to "%s" and install, skipping...';
	LS_EXC_FHNODESTPATHSET       = 'Error! No install path has been set!';
	LS_EXC_FHNOSOURCEFILESET     = 'Error! No file to install is specified!';
	LS_EXC_FHSOURCEDONTEXIST     = 'Error! File "%s" set to be patched does not exist!';
	LS_DLG_SELECTINSTALLFOLDER   = 'Please select the folder where your game is installed. (The folder containing the game executable.)';
	LS_EXC_FHINVALIDGAMEFOLDER   = 'Invalid game directory specified!';
	LS_EXC_FHTALKYMANNOTFOUND    = 'Invalid game folder specified, dialog.tlk file not found! Make sure you have selected the correct folder.';
	LS_LOG_FHINSTALLPATHSET      = 'Install path set to %s.';
	LS_DLG_FILETYPETLK           = 'TLK file %s';
	LS_DLG_FILETYPE2DA           = '2DA file %s';
	LS_DLG_FILETYPENSS           = 'NSS Script Source %s';
	LS_DLG_FILETYPESSF           = 'SSF Soundset file %s';
    LS_DLG_FILETYPEITM           = 'Item template %s';
    LS_DLG_FILETYPEUTC           = 'Creature template %s';
    LS_DLG_FILETYPEUTM           = 'Store template %s';
    LS_DLG_FILETYPEUTP           = 'Placeable template %s';
    LS_DLG_FILETYPEDLG           = 'Dialog file %s';
    LS_DLG_FILETYPEGFF           = 'GFF format file %s';
    LS_DLG_FILETYPEALL           = 'All files %s';	
	LS_DLG_FILESELECTDESC        = 'Please select your %s file.';
	LS_DLG_FILESELECTDESCMOD     = 'Please select the %s file that came with this Mod.';
	LS_DLG_FILEWORD              = '%s File';
	LS_EXC_FHNODESTSELECTED      = 'Error! No valid game folder selected! Installation aborted.';
	LS_EXC_FHREQFILEMISSING      = 'Cannot locate required file %s, unable to continue with install!';
	LS_EXC_FHTLKFILEMISSING      = 'Error! Unable to locate TLK file to patch, "%s" file not found!';
	LS_LOG_FHDESTFILENOTFOUND    = 'Unable to locate archive "%s" to modify or insert file "%s" into, skipping...';
	LS_LOG_FHDESTNOTFOUNDEXC     = 'Unable to load archive "%s" to modify or insert file "%s" into, skipping... (%s)';
	LS_LOG_FHCANNOTLOADDEST      = 'Unable to load archive "%s" to insert file "%s" into, skipping...';
	LS_LOG_FHDESTRESEXISTMOD     = 'File "%s" already exists in archive "%s", modifying existing file...';
	LS_LOG_FHSOURCENOTFOUND      = 'Unable to locate file "%s" to rename to "%s" and install, skipping...';
	LS_LOG_FHADDTODEST           = 'Adding file "%s" to archive "%s"...';
	LS_LOG_FHTEMPFILEFAILED      = 'Unable to make work copy of file "%s". File not saved to ERF/RIM archive!';
	LS_LOG_FHMAKEOVERRIDE        = 'No Override folder found, creating it at %s.';
	LS_LOG_FHMISSINGARCHIVE      = 'Unable to locate archive "%s" to insert script "%s" into, skipping...';
	LS_LOG_FHLOADARCHIVEEXC      = 'Unable to load archive "%s" to insert script "%s" into, skipping... (%s)';
	LS_LOG_FHLOADARCHIVEERR      = 'Unable to load archive "%s" to insert script "%s" into, skipping...';
	LS_LOG_FHBACKUPSCRIPT        = 'Making backup copy of script file "%s" found in override...';
	LS_LOG_FHSCRIPTEXISTS        = 'Script file "%s" already exists in override! Skipping...';
	LS_LOG_FHUPDATEREPLACE       = 'Updating and replacing file %s in Override folder...';
	LS_LOG_FHUPDATECOPY          = 'Updating and copying file %s to Override folder...';
	LS_LOG_FHINSFILENOTFOUND     = 'Unable to locate file "%s" to install, skipping...';
	LS_LOG_FHCOPY2OVERRIDE       = 'Copying file %s to Override folder...';
	LS_LOG_FHSAVEASSRCNOTFOUND   = 'Unable to locate file "%s" to install as "%s", skipping...';
	LS_LOG_FHFILEEXISTSKIP       = 'A file named "%s" already exists in the Override folder. Skipping...';
	LS_LOG_FHNOTSLPATCHDATAFILE  = 'No file blueprint found in tslpatchdata folder, fallback to manual source...';
	LS_DLG_MANUALLOCATEFILE      = 'File not found! Please locate the "%s" ("%s") file.';
	LS_LOG_FHCOPYFILEAS          = 'Copying file "%s" as "%s" to Override folder...';
	LS_EXC_FHCRITFILEMISSING     = 'Critical error: Unable to locate file to patch, "%s" file not found!';
	LS_LOG_FHMODIFYINGFILE       = 'Modifying file "%s" found in Override folder...';
	
           
    
    

// =============================================================================

implementation

// -----------------------------------------------------------------------------
// UTILITY: Function checking if the specified string is a StrRef-token...
// -----------------------------------------------------------------------------
function GetIsStringToken( sToken : string) : boolean;
begin
     if ((length(sToken) > 6)
        and (lowercase(copy(sToken, 1, 6)) = 'strref')
        and GetIsNumber(copy(sToken, 7, length(sToken))))
     then
         result := true
     else
         result := false;
end;


// -----------------------------------------------------------------------------
// Constructor - wants the name of the INI file as a parameter, as well as
// an Open dialog box object the class can use to ask for files.
// -----------------------------------------------------------------------------
constructor TTSLPatcher.Create(sFilename : string; oOpenBox : TOpenDialog; sPath : string);
begin
     inherited Create();

     l_inifile  := sFileName;
     l_path     := ExtractFilePath(Application.ExeName);

     // CHANGED(2006-04-29) Allow changing the path to the directory containing
     //                     the installation data. This used to be hardcoded.
     //                     If no path is specified the default behavior is used.
     if (Length(sPath) <= 0) or not SysUtils.DirectoryExists(sPath) then
        l_datapath := l_path + 'tslpatchdata\'
     else
        l_datapath := sPath;


     l_2da      := T2DAHandler.Create();
     l_gff      := TGFFFile.Create();     // FIX(2006-01-09) Ändrat till nya GFF-klassen.
     l_ini      := TST_IniFile.Create(l_datapath + l_inifile);

     l_dlgopen             := TPatchFileHandler.Create(oOpenBox, l_datapath);
     l_dlgopen.InstallMode := l_ini.ReadBool('Settings', 'InstallerMode', False);
     l_dlgopen.DoBackups   := l_ini.ReadBool('Settings', 'BackupFiles', True);
     l_dlgopen.BasePath    := l_path;
     l_dlgopen.ParentClass := Self;

     l_loglines  := 0;
     l_logalerts := 0;      // ADDED(2005-06-07)
     l_logerrors := 0;      // ADDED(2005-06-07)
     l_loglevel  := l_ini.ReadInteger('Settings', 'LogLevel',     3);
     l_logold    := l_ini.ReadBool(   'Settings', 'PlaintextLog', False);  // ADDED(2005-07-31)
     
     l_currentfile := '';
end;


// -----------------------------------------------------------------------------
// Destructor - free the 2da and INI handler objects.
// -----------------------------------------------------------------------------
destructor TTSLPatcher.Destroy();
begin
    l_2da.free();
    l_ini.free();
    l_gff.free();
    l_dlgopen.free();
    l_memory := nil;

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Support function for Add2daLine(), Modify2daLine(), Add2daColumn() and Copy2daLine().
// This function is context sensitive. It assumes that the proper 2da file has already
// been loaded into l_2da. Function returns true if the KEY value was a memory keyword.
//
// REMEMBER: iVal should be the ROW INDEX of the row to store values in, UNLESS
//            iType is ACTION_ADD_COLUMN, then iVal should be the COLUMN INDEX.
// -----------------------------------------------------------------------------
function TTSLPatcher.SetMemoryToken(sKey, sValue : string; iType, iVal : integer; sConstVal : string = '') : boolean;
var
   iCol : integer;
   iRow : Integer;
   iMem : integer;
   sTmp : string;
begin
    // KEY is MEMORY, we should store a value from the 2da...
    // 2DAMEMORY#=label
    if (copy(sKey, 1, 9) = '2DAMEMORY') then begin
       sTmp := copy(sKey, 10, (Length(sKey)+1) - 10);
       if (GetIsNumber(sTmp)) then begin
          iMem := StrToInt(sTmp);

          if (iMem < 1) then begin
              AddLogLine(LS_LOG_TOKENERROR1, LOG_LEVEL_ERROR);
              result := false;
              exit;
          end;

          if (length(l_memory) < iMem) then
             SetLength(l_memory, iMem);

          // Array indexing starts at 0, so decrease it with 1...
          iMem := iMem - 1;
          if (iMem < 0) then
             iMem := 0;
       end
       else begin
          // TODO: Should perhaps just skip processing the modifier alltogether, this might cause trouble...
          iMem := 1;
          if (length(l_memory) < iMem) then
             SetLength(l_memory, iMem);
          iMem := 0;
          AddLogLine(Format(LS_LOG_TOKENERROR2, [sKey]), LOG_LEVEL_ALERT);
       end;


       // Get the value from the column labeled by VALUE.
       if (  (iType = ACTION_ADD_ROW)
          or (iType = ACTION_MODIFY_ROW)
          or (iType = ACTION_COPY_ROW))
       then begin
            // It's the row index, handle it separately
            if (sValue = 'RowIndex') then begin
               l_memory[iMem] := IntToStr(iVal);
               AddLogLine(Format(LS_LOG_TOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
            end
            // It's the row label, handle it separately....
            else if (sValue = 'RowLabel') then begin
               if (iVal <> -1) and (iVal < l_2da.rowcount) then begin
                   l_memory[iMem] := l_2da.rlabels[iVal];
                   AddLogLine(Format(LS_LOG_TOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
               end
               else
                   AddLogLine(Format(LS_LOG_TOKENLABELERROR, [IntToStr(iVal)]), LOG_LEVEL_ALERT);

            end
            // It's one of the other column labels...
            else begin
                iCol := l_2da.GetColByLabel(sValue);
                try
                    if ((iCol <> -1)
                       and (iCol < l_2da.colcount)
                       and (iVal <> -1)
                       and (iVal < l_2da.rowcount))
                    then begin
                        l_memory[iMem] := l_2da.entry[iVal, iCol];
                        AddLogLine(Format(LS_LOG_TOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
                    end
                    else
                        AddLogLine(Format(LS_LOG_TOKENCOLUMNERROR, [sValue, sKey]), LOG_LEVEL_ALERT);
                except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine(Format(LS_LOG_TOKENCOLUMNERROR, [sValue, sKey]), LOG_LEVEL_ALERT)
                          else if (e.HelpContext <> 8) then
                             raise;
                       end;
                end;

            end;

       end
       // Get the value from the ROW labeled by VALUE;
       else if (iType = ACTION_ADD_COLUMN) then begin
            if (sValue = 'ColumnLabel') then begin
               if (iVal <> -1) and (iVal < l_2da.colcount) then begin
                   l_memory[iMem] := l_2da.clabels[iVal];
                   AddLogLine(Format(LS_LOG_TOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
               end
               else
                   AddLogLine(Format(LS_LOG_TOKENCOLLABELERROR, [IntToStr(iVal)]), LOG_LEVEL_ALERT);

            end
            else begin
                 // TEST THIS, a bugfix ---------------------------------
                sTmp := copy(sValue, 2, length(sValue));
                if ((lowercase(sValue[1]) = 'i') and GetIsNumber(sTmp)) then begin
                    iRow := StrToInt(sTmp);
                end
                else if ((lowercase(sValue[1]) = 'l') and (sTmp <> '')) then begin
                    iRow := l_2da.GetRowByLabel(sTmp);
                end
                else begin
                     iRow := -1;
                end;
                // ------------------------------------------------------
                try
                    if ((iRow >= 0)
                       and (iRow < l_2da.rowcount)
                       and (iVal <> -1)
                       and (iVal < l_2da.colcount))
                    then begin
                       l_memory[iMem] := l_2da.entry[iRow, iVal];
                       AddLogLine(Format(LS_LOG_TOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
                    end
                    else
                        AddLogLine(Format(LS_LOG_INVALIDCOLLABEL, [sKey]), LOG_LEVEL_ALERT);
                except
                     // Missing row values are not fatal, just skip it.
                     on e : EDead do begin
                        if (e.HelpContext = 10) then
                           AddLogLine(Format(LS_LOG_TOKENROWLERROR, [sValue, sKey]), LOG_LEVEL_ALERT)
                        else if (e.HelpContext <> 10) then
                           raise;
                     end;
                end;
            end;
       end
       // ADDED(2006-01-10) Added support for storing values from new GFF fields in 2DAMEMORY
       // tokens as well, despite their name.
       else if (iType = ACTION_ADD_FIELD) then begin
            if (lowercase(sValue) = 'listindex') then begin
               l_memory[iMem] := IntToStr(iVal);
               AddLogLine(Format(LS_LOG_LINDEXTOKENFOUND, [sKey,l_memory[iMem]]), LOG_LEVEL_VERBOSE);
            end
            // ADDED(2006-07-23) Allow storing the full path of the current field to a 2DAMEMORY token!
            else if (lowercase(sValue) = '!fieldpath') then begin
                l_memory[iMem] := sConstVal;
                AddLogLine(Format(LS_LOG_FPATHTOKENFOUND, [sKey, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
            end;
            // TODO: Add support for reading values from fields in the currently loaded GFF file 
            // as well. Should be fairly trivial if the VAL is set to the full field path... GetFieldByLabel...
       end;

       result := true;
       exit;
    end;

    result := false;
end;


// -----------------------------------------------------------------------------
// Check if the specified value matches a MEMORY keyword, and if so substitute
// the keyword for the memorized value instead. If not, just return the
// string that was passed unaltered.
// -----------------------------------------------------------------------------
function TTSLPatcher.GetMemoryToken(sValue : string) : string;
var
   iMem : integer;
   sTmp : string;
begin
    if (copy(sValue, 1, 9) = '2DAMEMORY') then begin
       sTmp := copy(sValue, 10, (Length(sValue)+1) - 10);
       if (GetIsNumber(sTmp)) then begin
          iMem := StrToInt(sTmp);

          if (length(l_memory) < iMem) and (length(l_memory) > 0) then begin
               iMem := 1;
               AddLogLine(Format(LS_LOG_TOKENINDEXERROR1, [sValue]), LOG_LEVEL_ALERT);
          end
          else if ((length(l_memory) < iMem) and (length(l_memory) <= 0)) then begin
               result := sValue;
               AddLogLine(Format(LS_LOG_TOKENINDEXERROR2, [sValue]), LOG_LEVEL_ERROR);
               exit;
          end;

          iMem := iMem - 1;
          if (iMem < 0) then
             iMem := 0;
       end
       else begin
           if (length(l_memory) > 0) then begin
               iMem := 0;
               AddLogLine(Format(LS_LOG_TOKENINDEXERROR1, [sValue]), LOG_LEVEL_ALERT);
           end
           else begin
               result := sValue;
               AddLogLine(Format(LS_LOG_TOKENINDEXERROR2, [sValue]), LOG_LEVEL_ERROR);
               exit;
           end;
       end;

       AddLogLine(Format(LS_LOG_GETTOKENVALUE, [sValue, l_memory[iMem]]), LOG_LEVEL_VERBOSE);
       result := l_memory[iMem];
    end
    else
        result := sValue;
end;

// -----------------------------------------------------------------------------
// Add a line to the feedback log. Set the iLevel parameter to one of the
// LOG_LEVEL_* constants to determine when the logged text should be displayed.
//
// FIX(2005-07-31) Added plaintext only progress log as a fallback for people
//                 with strange RichEd DLLs in their system. (Nicely done MS...)
//
// TODO: Put RichEd control specific code in the Main Form instead, and use a
//       callback procedural type to run it. Don't do any GUI-related things
//       in this method.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.AddLogLine(sText : string; iLevel : integer);
var
   iLog    : integer;
   sPrefix : string;
begin
     iLog := l_loglevel;

     // Leave the info text in the box if LogLevel is set to 0 in the INI.
     if (iLog = 0) then
        exit;

     if (l_loglines = 0) then begin
        if l_logold then begin
            logbuffertxt.lines.clear();
            logbuffertxt.clear();
        end
        else begin
            logbuffer.lines.clear();
            logbuffer.clear();
        end;
     end;

     if not l_logold then begin
         // Reset the text formatting to make sure it displays as intended...
         sPrefix := ' ' + #149 + ' ';  // Square bullet character, might display incorrectly in other charsets.
         logbuffer.wordwrap := False;
         logbuffer.SelAttributes.Size := 8;
         logbuffer.SelAttributes.Style := [];
         logbuffer.SelAttributes.Name := 'Courier New';
         logbuffer.Paragraph.Alignment := taLeftJustify;
         logbuffer.Paragraph.Numbering := nsNone;
         logbuffer.Paragraph.LeftIndent := 0;
     end;

     case iLevel of
          LOG_LEVEL_VERBOSE: begin   // Blue text in log....
              if (iLog > 3) then begin
                 if l_logold then begin
                     sPrefix := ' [Debug] ' + #9;
                     logbuffertxt.lines.add(sPrefix + sText);
                 end
                 else begin
                     logbuffer.SelAttributes.Color := $00982004;
                     logbuffer.lines.add(sPrefix + sText);
                 end;
                 inc(l_loglines);
              end;
          end;

          LOG_LEVEL_ALERT: begin   // Orange text in log...
              inc(l_logalerts);  // ADDED(2005-06-07)
              if (iLog > 2) then begin
                  if l_logold then begin
                     sPrefix := ' [Warning] ' + #9;
                     logbuffertxt.lines.add(sPrefix + sText);
                  end
                  else begin
                     logbuffer.SelAttributes.Color := $000257A0;
                     logbuffer.lines.add(sPrefix + 'Warning: ' + sText);
                  end;
                  inc(l_loglines);
              end;
          end;

          LOG_LEVEL_ERROR: begin  // Red text in log...
              inc(l_logerrors); // ADDED(2005-06-07)
              if (iLog > 1) then begin
                  if l_logold then begin
                      sPrefix := ' [Error] ' + #9;
                      logbuffertxt.lines.add(sPrefix + sText);
                  end
                  else begin
                      logbuffer.SelAttributes.Color := $0002029C;
                      logbuffer.lines.add(sPrefix + 'Error: ' + sText);
                  end;
                  inc(l_loglines);
              end;
          end;

          LOG_LEVEL_INFORMATION: begin  // Black text in log...
              if (iLog > 0) then begin
                 if l_logold then begin
                     sPrefix := ' [Install] ' + #9;
                     logbuffertxt.lines.add(sPrefix + sText);
                 end
                 else begin
                     logbuffer.SelAttributes.Color := $002E2E2E;
                     logbuffer.lines.add(sPrefix + sText);
                 end;
                 inc(l_loglines);
              end;
          end;

          LOG_LEVEL_NOTICE: begin      // Bold green text in log...
              if (iLog > 0) then begin
                 if not l_logold then
                     logbuffer.SelAttributes.Style := [fsBold];

                 // ADDED(2005-06-07)
                 // Set color of notice depending on if errors/alerts have been logged.
                 if (l_logalerts > 0) and (l_logerrors = 0) then begin
                     if l_logold then
                         sPrefix := ' [STATUS - WARNING] ' + #9
                     else
                         logbuffer.SelAttributes.Color := $000257A0;
                 end
                 else if (l_logerrors > 0) then begin
                     if l_logold then
                         sPrefix := ' [STATUS - ERROR] ' + #9
                     else
                         logbuffer.SelAttributes.Color := $0002029C;
                 end
                 else begin
                     if l_logold then
                         sPrefix := ' [STATUS] ' + #9
                     else
                         logbuffer.SelAttributes.Color := $00116102;
                 end;

                 if l_logold then
                     logbuffertxt.lines.add(sPrefix + sText)
                 else
                     logbuffer.lines.add(sPrefix + sText);
                     
                 inc(l_loglines);
              end;
          end;
     end;

     Application.ProcessMessages;
end;


// -----------------------------------------------------------------------------
// Looks in the INI file for a TLKList section and if one is present, make a
// table of its contents.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.ProcessTLKData();
var
   oStrRefLabels : TStringList;
   sKey          : string;
   sValue        : string;
   sIndex        : string;
   i             : integer;
   iCount        : integer;

begin
     oStrRefLabels := TStringList.Create();
     try
        l_ini.ReadSection('TLKList', oStrRefLabels);
        l_tlkmap := nil;
        iCount   := 0;

        AddLogLine(LS_LOG_LOADINGSTRREFTOKENS, LOG_LEVEL_VERBOSE);

        // Read in the String placeholders from the INI file...
        for i := 0 to (oStrRefLabels.count - 1) do begin
            sKey := oStrRefLabels.Strings[i];
            sValue := l_ini.ReadString('TLKList', sKey, '');

            if ((sKey <> '') and (sValue <> '')) then begin
               if (lowercase(copy(sKey, 1, 6)) = 'strref') then begin
                  sIndex := copy(sKey, 7, length(sKey));
                  if (GetIsNumber(sIndex) and GetIsNumber(sValue)) then begin
                     // FIX(2005-05-21) Hjärnsläpp åtgärdat... dimensionerade antalet
                     //     rader efter antalet kolumner +1, istället för
                     //     antalet rader + 1... Kör med iCount istället vid
                     //     rad-åtkomst då den är unikt inkrementell (är det ett ord?)
                     SetLength(l_tlkmap, 2, iCount+1);
                     l_tlkmap[0, iCount] := StrToInt(sIndex);
                     l_tlkmap[1, iCount] := StrToInt(sValue);
                     inc(iCount);
                  end;
               end;
            end;
        end;

        if (iCount > 0) then
           AddLogLine(Format(LS_LOG_LOADEDSTRREFTOKENS, [IntToStr(iCount)]), LOG_LEVEL_VERBOSE);

        // Merge the append.tlk file with the dialog.tlk file....
        AppendTLKData(TLK_TYPE_NORMAL);
        // ...and do the same with appendf.tlk and dialogf.tlk, if present...
        AppendTLKData(TLK_TYPE_FEMALE);

        // ADDED(2006-09-14) Increment progress...
        if (iCount > 0) then
            IncrementProgress(1);

     finally
            oStrRefLabels.free();
     end;
end;


// -----------------------------------------------------------------------------
// Looks through the table created by ProcessTLKData(), loooks up those strings
// in append.tlk and adds them as entries at the end of the user specified
// dialog.tlk file.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.AppendTLKData(iType : integer);
var
   tlkFile    : TTLKFileHandler;
   tlkAppend  : TTLKFileHandler;
   oEntry     : TTLKString;
   oInsert    : TTLKString;
   oTest      : TTLKString;
   sFileName  : string;
   sAppend    : string;
   iCount     : integer;
   iTest      : DWORD;
   iAdded     : integer;
   iReused    : integer;
   i          : integer;
   bFound     : boolean;
begin
    if (iType = TLK_TYPE_NORMAL) then begin
       sFileName := 'dialog.tlk';
       // CHANGED(2006-10-01) Allow setting custom name of append.tlk file.
       sAppend   := l_datapath + l_ini.ReadString('TLKList', '!SourceFile', 'append.tlk');
    end
    else if (iType = TLK_TYPE_FEMALE) then begin
        sFileName := 'dialogf.tlk';
        // CHANGED(2006-10-01) Allow setting custom name of appendf.tlk file.
        sAppend   := l_datapath + l_ini.ReadString('TLKList', '!SourceFileF', 'appendf.tlk');
    end
    else begin
        raise EAbort.Create(LS_EXC_TLKFILETYPEMISMATCH);
    end;

    if ((l_tlkmap <> nil)
        and (length(l_tlkmap) > 0)
        and (length(l_tlkmap[0]) > 0)
        and FileExists(sAppend))
    then begin
        l_currentfile := sFileName;

        if (l_dlgopen.Execute(sFileName, fileTlk)) then begin
            if (FileExists(l_dlgopen.FilePath) and FileExists(sAppend)) then begin
                AddLogLine(Format(LS_LOG_APPENDFEEDBACK, [l_dlgopen.FilePath]), LOG_LEVEL_INFORMATION);
                tlkFile := TTLKFileHandler.Create(l_dlgopen.FilePath);
                try
                    tlkAppend := TTLKFileHandler.Create(sAppend);
                    try
                        if (tlkFile.fileexists and tlkAppend.fileexists) then begin
                           iCount := 0;
                           iAdded := 0;
                           iReused := 0;
                           oEntry := tlkAppend.strings.first();
                           // Go through all entries in append.tlk and add them to dialog.tlk.
                           while ((oEntry <> nil) and (dword(iCount) < tlkAppend.count)) do begin
                               // First check that the string doesn't already exist...
                               // Not very efficient, but wtf, a few seconds more won't kill anyone...
                               iTest := 0;
                               bFound := False;
                               oTest := tlkFile.strings.first();
                               while ((oTest <> nil) and (iTest < tlkFile.count)) do begin
                                     if ((oTest.strtext = oEntry.strtext)
                                        and (oTest.strflags = oEntry.strflags)
                                        and (oTest.strsound = oEntry.strsound)
                                        and (oTest.sndvolume = oEntry.sndvolume)
                                        and (oTest.sndpitch = oEntry.sndpitch)
                                        and (oTest.sndlength = oEntry.sndlength))
                                     then begin
                                        // Update the StrRef in the table to the matching one
                                         for i := 0 to High(l_tlkmap[1]) do begin
                                             if (dword(l_tlkmap[1, i]) = oEntry.strref) then
                                                l_tlkmap[1, i] := oTest.strref;
                                         end;

                                         AddLogLine(Format(LS_LOG_TLKENTRYMATCHEXIST, [IntToStr(oEntry.strref), sFileName, IntToStr(oTest.strref)]), LOG_LEVEL_VERBOSE);
                                         iReused := iReused + 1;
                                         bFound := True;
                                         break;
                                     end;
                                     iTest := iTest + 1;
                                     oTest := tlkFile.strings.next();
                               end;

                               if (bFound = False) then begin
                                   oInsert := TTLKString.Create(oEntry);
                                   tlkFile.AddEntry(oInsert);

                                   AddLogLine(Format(LS_LOG_APPENDTLKENTRY, [sFileName, IntToStr(oInsert.strref)]), LOG_LEVEL_VERBOSE);

                                   // Update the StrRef in the table to the newly inserted one
                                   for i := 0 to High(l_tlkmap[1]) do begin
                                       if (dword(l_tlkmap[1, i]) = oEntry.strref) then
                                          l_tlkmap[1, i] := oInsert.strref;
                                   end;

                                   iAdded := iAdded + 1;
                               end;

                               iCount := iCount + 1;
                               oEntry := tlkAppend.strings.next();
                           end;
                           // At least one string was appended. Save the changes, but first make
                           // a backup copy of the original file if one doesn't already exist.
                           if (iCount > 0) then begin  
                              if l_dlgopen.DoBackup() then
                                 AddLogLine(Format(LS_LOG_MAKETLKBACKUP, [l_dlgopen.FileName, IncludeTrailingPathDelimiter(l_path+'backup')]), LOG_LEVEL_INFORMATION);

                              tlkFile.SaveTlkFile(l_dlgopen.FilePath);

                              if (iAdded > 0) and (iReused > 0) then
                                  AddLogLine(Format(LS_LOG_TLKSUMMARY1, [sFileName, IntToStr(iAdded), IntToStr(iReused)]), LOG_LEVEL_INFORMATION)
                              else if (iAdded > 0) then
                                  AddLogLine(Format(LS_LOG_TLKSUMMARY2, [sFileName, IntToStr(iAdded)]), LOG_LEVEL_INFORMATION)
                              else if (iReused > 0) then
                                  AddLogLine(Format(LS_LOG_TLKSUMMARY3, [sFileName, IntToStr(iReused)]), LOG_LEVEL_INFORMATION)
                              else
                                  AddLogLine(Format(LS_LOG_TLKSUMMARYWARNING, [sFileName]), LOG_LEVEL_ALERT)
                           end;
                        end;
                    finally
                        tlkAppend.free();
                    end;
                finally
                    tlkFile.free();
                end;
            end
            else begin
                 AddLogLine(Format(LS_LOG_TLKFILEMISSING, [sFileName]), LOG_LEVEL_ERROR);
                 raise EAbort.CreateHelp(LS_EXC_TLKFILEMISSING, 2);
            end;
        end // Open tlk execute
        else begin
             l_tlkmap := nil;
             AddLogLine(Format(LS_LOG_TLKNOTSELECTED, [sFileName]), LOG_LEVEL_ERROR);
             raise EAbort.CreateHelp(LS_EXC_TLKFILEMISSING, 1);
        end;

    end;
end;


// -----------------------------------------------------------------------------
// Look if the specified string is a StrRef token. If so, look up what StrRef
// the token refers to and return that StrRef as function value.
// -----------------------------------------------------------------------------
function TTSLPatcher.ProcessStrRefToken(sToken : string) : integer;
var
   i      : integer;
   sIndex : string;
begin
    if (sToken <> '') then begin
       if (lowercase(copy(sToken, 1, 6)) = 'strref') then begin
          sIndex := copy(sToken, 7, length(sToken));
          if (GetIsNumber(sIndex) and (Length(l_tlkmap) > 0) and (Length(l_tlkmap[0]) > 0)) then begin
             for i := 0 to High(l_tlkmap[0]) do begin
                 if (l_tlkmap[0, i] = StrToInt(sIndex)) then begin
                    result := l_tlkmap[1, i];
                    exit;
                 end;
             end; // end for
          end; // end numcheck
       end; // end token check
    end; // end tokenset

    // If we get here, no valid token was found. Log an error and return 0 (Bad StrRef).
    AddLogLine(Format(LS_LOG_UNKNOWNSTRREFTOKEN, [sToken]), LOG_LEVEL_ALERT);
    result := 0;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-09-26) Handle existing file in override folder as one updated or
// inserted into an ERF/RIM archive.
// sFilename - name of file to check for presence in override.
// sSection  - INI section to look for !Destination key in, if any.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.HandleERFOverrideType(sFilename : string; sSection : string; bNoDest : boolean=false; sAltDest : string='override');
var
    sType : string;
    sFile : string;
    sNew  : string;
    sDest : string;
begin
    // Check if the file's section is capable of holding a !Destination key.
    // Only the installist should not do this since it has the destination set
    // already in it's folder specifier.
    if not bNoDest then begin
        sDest := lowercase(l_ini.ReadString(sSection, '!Destination', sAltDest));

        // If destination is the override folder this should not be run at all...
        if (sDest = 'override') then begin
            exit;
        end;
    end;

    sType := lowercase(l_ini.ReadString(sSection, '!OverrideType', 'ignore'));
    sFile := IncludeTrailingPathDelimiter(l_dlgOpen.InstallPath + 'override') + sFilename;

    if not SysUtils.FileExists(sFile) then begin
        AddLogLine(Format(LS_LOG_OVRCHECKNOFILE, [sFilename]), LOG_LEVEL_VERBOSE);
        exit;
    end;

    // If we get here, a file with the same name exists in the override folder....

    if (sType = 'warn') then begin
        AddLogLine(Format(LS_LOG_OVRCHECKEXISTWARN, [sFilename]), LOG_LEVEL_ALERT);
    end
    else if (sType = 'rename') then begin
        // CHANGED(2006-10-01) Changed renaming convention to old_filename.ext instead.
        sNew := IncludeTrailingPathDelimiter(ExtractFilePath(sFile)) + 'old_' + ExtractFileName(sFile);
        if SysUtils.RenameFile(sFile, sNew) then begin
            AddLogLine(Format(LS_LOG_OVRCHECKRENAMED, [sFilename, ExtractFileName(sNew)]), LOG_LEVEL_INFORMATION);
        end
        else begin
            AddLogLine(Format(LS_LOG_OVRRENAMEFAILED, [sFilename, ExtractFileName(sNew)]), LOG_LEVEL_ALERT);
        end;
    end
    else begin
        AddLogLine(Format(LS_LOG_OVRCHECKSILENTWARN, [sFilename]), LOG_LEVEL_VERBOSE);
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-01-10) Added function to let the Patcher add new fields to GFF
// format files. This is done by adding a KEY named as "AddField#" under the
// section for the file in question. The VALUE is this key is the name of
// another section in changes.ini which holds the specifics of the new field to
// add. This section then contains some of the following keys:
//
// General keys:
// * FieldType - REQUIRED field, this determines the type of field, see below.
// * Path      - OPTIONAL field, determines where in the GFF field tree the new
//               field should be added. Leave blank to add the field at the
//               root/top level.
//               IMPORTANT: This *must* be unspecified for sub-fields added
//               within the sections of newly added LIST or STRUCT fields, or
//               the field might be added at the wrong position!
// * Label     - REQUIRED field, this sets what the field label (name) of the
//               new field will be. This must be specified for all new fields,
//               EXCEPT for new STRUCTS added to a LIST.
// * Value     - OPTIONAL field, this sets what value the new field will have.
//               Take care to only enter data in a format that will fit within
//               the type of field set in FieldType (i.e. only numbers in INT
//               fields etc). STRUCT and LIST fields are containers and have
//               no value, and should not specify this key.
//               NOTE: Values specified for Position and Orientation fields must
//               have each value separated by a pipe character, like 0.0|1.0|5.0.
//
// Field specific keys:
// * StrRef    - OPTIONAL field. This is only used in sections that create a new
//               ExoLocString field. It will set the value of the dialog.tlk
//               StrRef for this field.
// * lang#     - OPTIONAL field. This is only used in sections that create a new
//               ExoLocString field. # is the language id to add a new localized
//               substring to the ExoLocString under. Multiple "lang"-lines with
//               different language id's may be specified to add strings for
//               multiple languages and genders.
// * TypeId    - OPTIONAL field. This is only used in sections that create a new
//               STRUCT field. This sets the type ID of the struct to the
//               number assigned to it. (Decimal value, NOT hexadecimal please...)
//
// New LIST and STRUCT fields:
// To add new sub-fields to a LIST or STRUCT field you have just added, you can
// add "AddField#" keys to its modifier section. These will work just like such
// keys added directly under the file's section, with one important difference.
// DO NOT add a "Path" key to ANY of the sub-sections that define those sub-fields.
// Their position paths will be derived automatically from their parent field.
// -----------------------------------------------------------------------------
function TTSLPatcher.AddGffField(sSection : string; sOverridePath : string) : boolean;
var
   oGffList    : TStringList;
   oTokens     : TStringTokenizer;
   oField      : TGFFField;
   oParent     : TGFFField;
   bFound      : boolean;
   bModified   : boolean;
   sModPath    : string;
   sType       : string;
   sPath       : string;
   sKey        : string;
   sValue      : string;
   sLang       : string;
   iIndex      : integer;
   i           : integer;
begin
     result := false;

     if not l_ini.SectionExists(sSection) then begin
        AddLogLine(Format(LS_LOG_GFFSECTIONMISSING, [sSection]), LOG_LEVEL_ALERT);
        result := false;
        exit;
     end;

     // Read in some keys that are used by most field types...
     sType  := l_ini.ReadString(sSection, 'FieldType', '');
     sPath  := l_ini.ReadString(sSection, 'Path', sOverridePath);
     sKey   := l_ini.ReadString(sSection, 'Label', '');
     sValue := l_ini.ReadString(sSection, 'Value', '');

     // Fetch the specified parent field from the GFF data...
     if (sPath = '') then
        oParent := l_gff.root
     else
        oParent := l_gff.GetFieldByLabel(sPath);

     // Check that the parent path specified is valid, and is a type of field
     // that accepts sub-fields, i.e. a STRUCT or LIST.
     if (oParent = nil) or ((oParent.FieldType <> FIELD_TYPE_LIST) and (oParent.FieldType <> FIELD_TYPE_STRUCT)) then begin
         AddLogLine(Format(LS_LOG_GFFPARENTALERROR, [sPath, sKey]), LOG_LEVEL_ALERT);
         exit;
     end;

     // Check that a field with this name doesn't already exist at the
     // specified location. If it does, skip it.
     // Also check that a Label has been specified for the new field.
     sModPath := sPath;
     if (Length(sModPath) > 0) then
         sModPath := sPath + '\';

     // Check the Value data for 2DAMEMORY and StrRef tokens and substitute
     // the correct value.
     // CHANGED(2007-07-13) Moved this up below the LIST TYPE parent check statement
     //                     since it should be done in many cases even if the field
     //                     already exists.
     if (GetIsStringToken(sValue)) then
         sValue := IntToStr(ProcessStrRefToken(sValue));

     sValue := GetMemoryToken(sValue);

     // Default operation: New field added (sets to true if no field was added but an
     // existing field with the same label/type was modified instead, below.
     bModified := false;

     // Skip the check if the parent field is a LIST, since STRUCTs in a list have no label...
     // CHANGED(2007-08-13) Modify existing field value instead if the existing field has the
     //                     same data type as the new one.
     if (oParent.FieldType <> FIELD_TYPE_LIST) then begin
         if (sKey = '') then begin
             AddLogLine(Format(LS_LOG_GFFMISSINGLABEL, [sSection]), LOG_LEVEL_ALERT);
             exit;
         end;

         // Get field with specified label path if one exists.
         oField := l_gff.GetFieldByLabel(sModPath + sKey);

         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         // CHANGED(2007-08-13) If the field exists and is of the same data type, just modify
         //                     the existing field value instead!
         if (oField <> nil) then begin
             if (sType = 'Byte') and (oField.fieldtype = FIELD_TYPE_BYTE) and GetIsNumber(sValue) then begin
                 TGFF_SByte(oField).value := StrToInt(sValue);
             end
             else if (sType = 'Char') and (oField.fieldtype = FIELD_TYPE_CHAR) then begin
                 if (Length(sValue) > 0) then
                     TGFF_SChar(oField).value := sValue[1]
                 else
                     TGFF_SChar(oField).value := #0;
             end
             else if (sType = 'Word') and (oField.fieldtype = FIELD_TYPE_WORD) and GetIsNumber(sValue) then begin
                 TGFF_SWord(oField).value := StrToInt(sValue);
             end
             else if (sType = 'Short') and (oField.fieldtype = FIELD_TYPE_SHORT) and GetIsNumber(sValue) then begin
                 TGFF_SShort(oField).value := StrToInt(sValue);
             end
             else if (sType = 'DWORD') and (oField.fieldtype = FIELD_TYPE_DWORD) and GetIsNumber(sValue) then begin
                 TGFF_SDWORD(oField).value := SafeStrToInt(sValue);
             end
             else if (sType = 'Int') and (oField.fieldtype = FIELD_TYPE_INT) and GetIsNumber(sValue) then begin
                 TGFF_SInt(oField).value := StrToInt(sValue);
             end
             else if (sType = 'Int64') and (oField.fieldtype = FIELD_TYPE_INT64) and GetIsNumber(sValue) then begin
                 TGFF_CInt64(oField).value := StrToInt64(sValue);
             end
             else if (sType = 'Float') and (oField.fieldtype = FIELD_TYPE_FLOAT) and GetIsFloat(sValue) then begin
                 TGFF_SFloat(oField).value := SafeStrToFloat(sValue);
             end
             else if (sType = 'Double') and (oField.fieldtype = FIELD_TYPE_DOUBLE) and GetIsFloat(sValue) then begin
                 TGFF_CDouble(oField).value := SafeStrToDouble(sValue);
             end
             else if (sType = 'ExoString') and (oField.fieldtype = FIELD_TYPE_CEXOSTRING) then begin
                 TGFF_CExoString(oField).textstring := sValue;
             end
             else if (sType = 'ResRef') and (oField.fieldtype = FIELD_TYPE_RESREF) then begin
                 TGFF_CResRef(oField).textstring := sValue;
             end
             else if (sType = 'ExoLocString') and (oField.fieldtype = FIELD_TYPE_CEXOLOCSTRING) then begin
                // Update the StrRef value...
                sValue := l_ini.ReadString(sSection, 'StrRef', '-1');
                // Check the StrRef data for 2DAMEMORY and StrRef tokens and substitute
                // the correct value.
                if (GetIsStringToken(sValue)) then
                    sValue := IntToStr(ProcessStrRefToken(sValue));

                sValue := GetMemoryToken(sValue);

                // FIX(2006-02-03) Moving this down below the token substitution, otherwise
                // the tokens will be nuked as an invalid condition. Silly mistake. :/
                if (not GetIsNumber(sValue)) and (sValue <> '-1') then begin
                    AddLogLine(Format(LS_LOG_GFFINVALIDSTRREF, [sValue]), LOG_LEVEL_ALERT);
                    sValue := '-1';
                end;

                if (sValue = '-1') then
                    TGFF_CExoLocString(oField).strref := $FFFFFFFF
                else
                    TGFF_CExoLocString(oField).strref := SafeStrToInt(sValue);

                // Create or update any localized substrings that have been defined.
                oGffList := TStringList.Create();
                try
                    l_ini.ReadSection(sSection, oGffList);
                    for i := 0 to (oGffList.count - 1) do begin
                        if (Length(oGffList.Strings[i]) > 4) and (copy(oGffList.Strings[i], 1, 4) = 'lang') then begin
                            sLang := copy(oGffList.Strings[i], 5, Length(oGffList.Strings[i]) - 4);
                            if (GetIsNumber(sLang)) then begin
                                sValue := l_ini.ReadString(sSection, oGffList.Strings[i], '');

                                // Check the StrRef data for 2DAMEMORY and StrRef tokens and substitute
                                // the correct value.
                                if (GetIsStringToken(sValue)) then
                                    sValue := IntToStr(ProcessStrRefToken(sValue));

                                sValue := GetMemoryToken(sValue);

                                TGFF_CExoLocString(oField).SetStringByID(StrToInt(sLang), sValue, true);
                            end;
                        end;
                    end;
                finally
                    oGffList.free();
                end;
             end
             else if (sType = 'Orientation') and (oField.fieldtype = FIELD_TYPE_ORIENTATION) then begin
                oTokens := TStringTokenizer.Create(sValue, '|');
                if (oTokens.count = 4) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_COrientation(oField).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
             end
             else if (sType = 'Position') and (oField.fieldtype = FIELD_TYPE_POSITION) then begin
                oTokens := TStringTokenizer.Create(sValue, '|');
                if (oTokens.count = 3) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_CPosition(oField).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
             end
             else if (sType = 'Struct') and (oField.fieldtype = FIELD_TYPE_STRUCT) then begin
                 sValue := l_ini.ReadString(sSection, 'TypeId', '');

                 // ADDED(2006-01-18) if the type id is set to "ListIndex", then set the type id
                 // to the Index in the LIST the STRUCT will be added as instead. This is useful
                 // in global.jrl where, for some reason, the typeid equals the ListIndex.
                 if (oParent.fieldtype = FIELD_TYPE_LIST) and (lowercase(sValue) = 'listindex') then begin
                     iIndex := TGFFList(oParent).count;
                     sValue := IntToStr(iIndex);
                 end;

                 // If no TypeId key was set, or invalid value was set then don't do anything.
                 if (GetIsNumber(sValue)) then
                    TGFFStruct(oField).typeid := SafeStrToInt(sValue);
             end
             else if (sType = 'List') and (oField.fieldtype = FIELD_TYPE_LIST) then begin
                 // List fields have no values in themselves, they are just struct arrays.
             end
             else begin
                 // Invalid data type or Field <-> Modifier data type mismatch. Laskip like before!
                 if (Length(sModPath) = 0) then
                     sModPath := 'root';

                 AddLogLine(Format(LS_LOG_GFFLABELEXISTS, [sKey, sModPath]), LOG_LEVEL_ALERT);
                 exit;
             end;

             if (Length(sModPath) = 0) then
                 sModPath := 'root';

             AddLogLine(Format(LS_LOG_GFFLABELEXISTSMOD, [sKey, sModPath]), LOG_LEVEL_INFORMATION);
             bModified := true;
         end;
         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         (*
         if (oField <> nil) then begin
             if (Length(sModPath) = 0) then
                 sModPath := 'root';

             AddLogLine(Format(LS_LOG_GFFLABELEXISTS, [sKey, sModPath]), LOG_LEVEL_ALERT);
             exit;
         end;
         *)
     end;

     // CHANGED(2007-08-13) Only do this if adding a new field, not if modifying existing one.
     if not bModified then begin
         // Reset field object reference...
         oField := nil;

         // Check type of field to add and create a Field object of the correct type...
         if (sType = 'Byte') then begin
            if (GetIsNumber(sValue)) then
               oField := TGFF_SByte.Create(sKey, StrToInt(sValue));

         end
         else if (sType = 'Char') then begin
            if (Length(sValue) > 0) then
               oField := TGFF_SChar.Create(sKey, sValue[1]);
         end
         else if (sType = 'Word') then begin
            if (GetIsNumber(sValue)) then
               oField := TGFF_SWord.Create(sKey, StrToInt(sValue));
         end
         else if (sType = 'Short') then begin
            if (GetIsNumberSigned(sValue)) then
               oField := TGFF_SShort.Create(sKey, StrToInt(sValue));
         end
         else if (sType = 'DWORD') then begin
            // FIX(2006-07-23) Worked around weird bug in StrToInt() which seems to
            // throw exception if value is 4294967295, but not 0xFFFFFFFF, for some odd reason.
            if (GetIsNumber(sValue)) then
               oField := TGFF_SDWORD.Create(sKey, SafeStrToInt(sValue));
         end
         else if (sType = 'Int') then begin
            if (GetIsNumberSigned(sValue)) then
               oField := TGFF_SInt.Create(sKey, StrToInt(sValue));
         end
         else if (sType = 'Int64') then begin
            if (GetIsNumberSigned(sValue)) then
               oField := TGFF_CInt64.Create(sKey, StrToInt64(sValue));
         end
         else if (sType = 'Float') then begin
            if (GetIsFloat(sValue)) then
               oField := TGFF_SFloat.Create(sKey, SafeStrToFloat(sValue));
         end
         else if (sType = 'Double') then begin
            if (GetIsFloat(sValue)) then
               oField := TGFF_CDouble.Create(sKey, SafeStrToDouble(sValue));
         end
         else if (sType = 'ExoString') then begin
            oField := TGFF_CExoString.Create(sKey, sValue);
         end
         else if (sType = 'ResRef') then begin
            oField := TGFF_CResRef.Create(sKey, sValue);
         end
         else if (sType = 'ExoLocString') then begin
            sValue := l_ini.ReadString(sSection, 'StrRef', '-1');

            // Check the StrRef data for 2DAMEMORY and StrRef tokens and substitute
            // the correct value.
            if (GetIsStringToken(sValue)) then
                sValue := IntToStr(ProcessStrRefToken(sValue));

            sValue := GetMemoryToken(sValue);

            // FIX(2006-02-03) Moving this down below the token substitution, otherwise
            // the tokens will be nuked as an invalid condition. Silly mistake. :/
            if (not GetIsNumber(sValue)) and (sValue <> '-1') then begin
                AddLogLine(Format(LS_LOG_GFFINVALIDSTRREF, [sValue]), LOG_LEVEL_ALERT);
                sValue := '-1';
            end;

            // Create the ExoLocString field object...
            if (sValue = '-1') then
                oField := TGFF_CExoLocString.Create(sKey, $FFFFFFFF)
            else
                oField := TGFF_CExoLocString.Create(sKey, SafeStrToInt(sValue));

            // Create any localized substrings that have been defined.
            oGffList := TStringList.Create();
            try
                l_ini.ReadSection(sSection, oGffList);
                for i := 0 to (oGffList.count - 1) do begin
                    if (Length(oGffList.Strings[i]) > 4) and (copy(oGffList.Strings[i], 1, 4) = 'lang') then begin
                        sLang := copy(oGffList.Strings[i], 5, Length(oGffList.Strings[i]) - 4);
                        if (GetIsNumber(sLang)) then begin
                            sValue := l_ini.ReadString(sSection, oGffList.Strings[i], '');

                            // Check the StrRef data for 2DAMEMORY and StrRef tokens and substitute
                            // the correct value.
                            if (GetIsStringToken(sValue)) then
                                sValue := IntToStr(ProcessStrRefToken(sValue));

                            sValue := GetMemoryToken(sValue);

                            TGFF_CExoLocString(oField).AddString(StrToInt(sLang), sValue);
                        end;
                    end;
                end;
            finally
                oGffList.free();
            end;
         end
         else if (sType = 'Orientation') then begin
              bFound := false;
              oTokens := TStringTokenizer.Create(sValue, '|');
              if (oTokens.count = 4) then begin
                  for i := 0 to (oTokens.count - 1) do begin
                      if not GetIsFloat(oTokens[i]) then begin
                          bFound := True;
                      end;
                  end;
              end;

              if not bFound then begin
                  oField := TGFF_COrientation.Create(sKey, SafeStrToFloat(oTokens[0]),SafeStrToFloat(oTokens[1]), SafeStrToFloat(oTokens[2]), SafeStrToFloat(oTokens[3]));
              end;

              oTokens.free();
         end
         else if (sType = 'Position') then begin
              bFound := false;
              oTokens := TStringTokenizer.Create(sValue, '|');
              if (oTokens.count = 3) then begin
                  for i := 0 to (oTokens.count - 1) do begin
                      if not GetIsFloat(oTokens[i]) then begin
                          bFound := True;
                      end;
                  end;
              end;

              if not bFound then begin
                  oField := TGFF_CPosition.Create(sKey, SafeStrToFloat(oTokens[0]),SafeStrToFloat(oTokens[1]), SafeStrToFloat(oTokens[2]));
              end;

              oTokens.free();
         end
         else if (sType = 'Struct') then begin
             oField := TGFFStruct.Create(sKey);

             sValue := l_ini.ReadString(sSection, 'TypeId', '');

             // ADDED(2006-01-18) if the type id is set to "ListIndex", then set the type id
             // to the Index in the LIST the STRUCT will be added as instead. This is useful
             // in global.jrl where, for some reason, the typeid equals the ListIndex.
             if (oParent.fieldtype = FIELD_TYPE_LIST) and (lowercase(sValue) = 'listindex') then begin
                 iIndex := TGFFList(oParent).count;
                 sValue := IntToStr(iIndex);
             end;

             if (GetIsNumber(sValue)) then
                TGFFStruct(oField).typeid := SafeStrToInt(sValue);
         end
         else if (sType = 'List') then begin
             oField := TGFFList.Create(sKey);
         end;


         // STOP HERE if no valid field object has been created above!
         if (oField = nil) then begin
             AddLogLine(Format(LS_LOG_GFFINVALIDTYPEDATA, [sType, sSection, ExtractFileName(l_gff.filename)]), LOG_LEVEL_ALERT);
             exit;
         end;
     end;  // END: bModified = false

     // Add the new field to the GFF Data tree
     if (oParent <> nil) then begin
        // CHANGED(2007-08-13) Only do this if adding new field, not if modifying existing one
        if not bModified then begin
            l_gff.AddField(oField, sPath);
            result := true;

            sModPath := sPath;
            if (sModPath = '') then
                sModPath := 'root';

            if (oParent.fieldtype = FIELD_TYPE_LIST) then
               AddLogLine(Format(LS_LOG_GFFADDEDSTRUCT, [sType, IntToStr(TGFFList(oParent).count - 1), sModPath]), LOG_LEVEL_VERBOSE)
            else
               AddLogLine(Format(LS_LOG_GFFADDEDFIELD, [sType, oField.fieldlabel, sModPath]), LOG_LEVEL_VERBOSE);
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // ADDED(2006-07-23) store Field Path in token if requested (!FieldPath).
        // CHANGED(2006-07-23) Loop for all field types, not just LIST/STRUCT,
        // to be able to store any requests for field paths.
        oGffList := TStringList.Create();
        try
            // CHANGED(2007-08-13) Need to use different method to get the Lindex of a struct in a list
            //                     if the struct field wasn't added but already exists.
            if not bModified then begin
                // Get ListIndex of new Struct added to a List field.
                if (oField.fieldtype = FIELD_TYPE_STRUCT) and (oParent.fieldtype = FIELD_TYPE_LIST) then
                    iIndex := TGFFList(oParent).count - 1
                else
                    iIndex := -1;
            end
            // CHANGED(2007-08-13) Find the Lindex of the Struct in the parent List if modifying existing field.
            else begin
                if (oField.fieldtype = FIELD_TYPE_STRUCT) and (oParent.fieldtype = FIELD_TYPE_LIST) then begin
                    bFound := false;
                    for i := 0 to (TGFFList(oParent).count - 1) do begin
                        if (TGFFList(oParent).structs[i] = oField) then begin
                            iIndex := i;
                            bFound := true;
                            break;
                        end;
                    end;

                    // Uh oh... could not find this field in the parent struct list! Something is wrong! Abort! ABORT!!!
                    if not bFound then begin
                        AddLogLine(Format(LS_LOG_GFFMISSINGLISTSTRUCT, [sPath]), LOG_LEVEL_ALERT);
                        exit;
                    end;
                end
                else begin
                    iIndex := -1;
                end;
            end;

            // Build path to new field
            sModPath := sPath + '\';
            if (oParent.fieldtype = FIELD_TYPE_LIST) then
                sModPath := sModPath + IntToStr(iIndex)
            else
                sModPath := sModPath + oField.fieldlabel;

            // Loop through modifiers to handle any tokens and sub-fields.
            l_ini.ReadSection(sSection, oGffList);
            for i := 0 to (oGffList.count - 1) do begin
                sKey := oGffList.Strings[i];
                sValue := l_ini.ReadString(sSection, sKey, '');

                // Assign values to 2DAMEMORY tokens if requested.
                if (sValue <> '') then begin
                    SetMemoryToken(sKey, sValue, ACTION_ADD_FIELD, iIndex, sModPath);
                end;

                // If new field was a Struct or List it might contain sub-fields. Check if the
                // section contains any AddField modifier keys of its own and if so process them too.
                if (oField.fieldtype = FIELD_TYPE_STRUCT) or (oField.Fieldtype = FIELD_TYPE_LIST) then begin
                    // Process any fields that should be added to this struct...
                    if (copy(sKey, 1, 8) = 'AddField') and (Length(sKey) > 8) then begin
                       // If the parent is a LIST, use the listindex in new path
                       // recursively, to allow adding fields under a struct in
                       // a list which the index of is unknown at configuration time.
                       AddGffField(sValue, sModPath);
                       AddLogLine(Format(LS_LOG_GFFPROCSUBFIELDS, [sModPath]), LOG_LEVEL_VERBOSE);

                    end;
                end;
            end;
        finally
            oGffList.free();
        end;
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


        // REMOVED(2006-07-23) Replaced with above loop instead...
        // Process any sub-fields to add to new STRUCT or LIST fields, and fetch the ListIndex
        // of this field if it's a STRUCT added to a LIST and the user want to store it in a 2DAMEMORY token.
        (*
        if (oField.fieldtype = FIELD_TYPE_STRUCT) or (oField.fieldtype = FIELD_TYPE_LIST) then begin
            oGffList := TStringList.Create();
            try
                l_ini.ReadSection(sSection, oGffList);
                for i := 0 to (oGffList.count - 1) do begin
                    sKey := oGffList.Strings[i];
                    sValue := l_ini.ReadString(sSection, sKey, '');

                    if (sValue <> '') then begin
                        // Process any fields that should be added to this struct...
                        if (copy(sKey, 1, 8) = 'AddField') and (Length(sKey) > 8) then begin
                           // If the parent is a LIST, use the listindex in new path
                           // recursively, to allow adding fields under a struct in
                           // a list which the index of is unknown at configuration time.
                           sModPath := sPath + '\';
                           if (sModPath = '\') then
                               sModPath := '';

                           if (oParent.fieldtype = FIELD_TYPE_LIST) then begin
                               iIndex := TGFFList(oParent).count - 1;
                               AddGffField(sValue, sModPath + IntToStr(iIndex));
                               AddLogLine('Processing new sub-fields at ' + sModPath + IntToStr(iIndex), LOG_LEVEL_VERBOSE);
                           end
                           // Otherwise use the Field Label of the parent in the new path.
                           else begin
                               AddGffField(sValue, sModPath + oField.fieldlabel);
                               AddLogLine('Processing new sub-fields at ' + sModPath + oField.fieldlabel, LOG_LEVEL_VERBOSE);
                           end;
                        end
                        // Store the ListIndex in a 2DAMEMORY token if requested.
                         else if (oParent.fieldtype = FIELD_TYPE_LIST) then begin
                             SetMemoryToken(oGffList.Strings[i], sValue, ACTION_ADD_FIELD, iIndex);
                         end;
                    end;
                end;
            finally
                oGffList.free();
            end;
        end;
        *)
     end;

end;


// -----------------------------------------------------------------------------
// (2005-05-19) Update any GFF files listed with the specified changes.
// CHANGED(2006-01-10) Add new fields as well, if requested.
// CHANGED(2006-08-06) Modified the ERF/RIM insertion code. Will now work with
// existing files in the game folder (+subs) and will modify existing GFF files
// that exist within the ERF/RIM already, unless Replace is set.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.UpdateGffFiles();
var
   oGffList    : TStringList;
   oChangeList : TStringList;
   oERF        : TERFHandler;
   enType      : TPatchFile;
   sFilename   : string;
   sKey        : string;
   sVal        : string;
   sDest       : string;
   i, n        : integer;
   iChanges    : integer;
   bSkip       : boolean;
   bOverwrite  : boolean;  // ADDED(2006-01-26)
begin
     // No GFF modifiers present in the INI file. No point in continuing...
     if not l_ini.SectionExists('GFFList') then
        exit;

     oGffList := TStringList.Create();
     try
        l_ini.ReadSection('GFFList', oGffList);
        if (oGffList.count > 0) then begin
            AddLogLine(LS_LOG_GFFMODIFYING, LOG_LEVEL_INFORMATION);

            for i := 0 to (oGffList.count - 1) do begin
                sFilename := l_ini.ReadString('GFFList', oGffList.Strings[i], '');
                l_currentfile := sFilename;
                iChanges := 0;

                // If there's no section of modifiers present we might as well skip this file...
                if (l_ini.SectionExists(sFilename) = False) then begin
                    AddLogLine(Format(LS_LOG_GFFNOINSTRUCTION, [sFilename]), LOG_LEVEL_ERROR);
                    continue;
                end;

                // ADDED(2006-02-03) Optional key to make the file get written into an ERF
                // file instead of the override folder.
                // Note: Existing files in the ERF will NOT be modified, the modified GFF
                //       file will be inserted into the ERF, replacing any resource with
                //       the same name and type, if one exists.
                sDest := l_ini.ReadString(sFilename, '!Destination', 'override');

                if (lowercase(sDest) = 'override') then begin
                    enType := fileGff;
                end
                else begin
                    enType := fileGffErf;

                    // REMOVED(2006-08-06) Moved into the dlgopen.Execute method instead,
                    // which will check if the ERF is present where it needs to be.
                    // if not SysUtils.FileExists(l_datapath + sDest) then begin
                    //    AddLogLine('Unable to save file "' + sFilename + '" in ERF archive "' + sDest + '", the ERF file could not be found!', LOG_LEVEL_ERROR);
                    //    continue;
                    //end;
                end;
                // - - - - - - - - - - - - - -


                // ADDED(2006-01-26) Allow optional key to instruct patcher to Overwrite
                // an existing GFF file in override.
                bOverwrite := false;
                if (sFileName <> '') then begin
                    bOverwrite := l_ini.ReadBool(sFilename, '!ReplaceFile', false);
                end;

                // CHANGED(2006-01-26) Added bOverwrite param to Execute method call...
                if ((sFileName <> '') and l_dlgopen.Execute(sFilename, enType, bOverwrite, sDest)) then begin

                    // If the specified file doesn't exist, stop here...
                    if (FileExists(l_dlgopen.FilePath) = False) then
                        break;

                    // Load the GFF File...
                    l_gff.LoadFile(l_dlgopen.FilePath); // FIX(2006-01-09) Nytt metodnamn för nya GFF-klassen.

                    if (l_gff.loaded) then begin  // FIX(2006-01-09) Nytt property-namn för nya GFF-klassen.
                        AddLogLine(Format(LS_LOG_GFFMODIFYINGFILE, [ExtractFileName(l_dlgopen.FilePath)]), LOG_LEVEL_INFORMATION);

                        oChangeList := TStringList.Create();
                        try
                            l_ini.ReadSection(sFilename, oChangeList);
                            if (oChangeList.count > 0) then begin
                                for n := 0 to (oChangeList.count - 1) do begin
                                    sKey := oChangeList.strings[n];

                                    // FIX(2006-07-23) Moved this up above the token substitution,
                                    // since the value needs to get fetched from the INI file before;
                                    // the keys in the file are the tokens, not their values.
                                    sVal := l_ini.ReadString(sFilename, sKey, '');

                                    // ADDED(2006-07-23) Allow using a field label stored in a 2DAMEMORY
                                    // token, and not just static values...
                                    sKey := GetMemoryToken(sKey);

                                    bSkip := False;
                                    if (sKey = '') then begin
                                        bSkip := True;
                                        AddLogLine(LS_LOG_GFFBLANKFIELDLABEL, LOG_LEVEL_ALERT);
                                    end;

                                    // FIX(2006-07-23) Moved this up from the skip-blocked section below.
                                    if (GetIsStringToken(sVal)) then
                                        sVal := IntToStr(ProcessStrRefToken(sVal))
                                    else
                                        sVal := GetMemoryToken(sVal);

                                    // FIX(2005-05-19)
                                    // Pucko... en label är max 16 tkn, men en label PATH kan vara
                                    // betydligt längre än så... bort med det här... :/
                                    (* if (Length(sKey) > 16) then begin
                                        bSkip := True;
                                        AddLogLine('Invalid field label ' + sKey + ' in instructions, label can be no longer than 16 characters. Skipping...', LOG_LEVEL_ALERT);
                                    end; *)

                                    // Skip keys that are not filenames, but special directives...
                                    // ADDED(2006-01-26) !ReplaceFile (replace existing files if found)
                                    // ADDED(2006-02-03) !Destination (set override or ERF file as target)
                                    // ADDED(2006-07-20) !SourceFile  (use source file with different name)
                                    // ADDED(2006-09-26) !OverrideType (how to handle ERF/RIM inserted files existing in override)
                                    if     (lowercase(copy(sKey, 1, 12)) = '!replacefile')
                                        or (lowercase(copy(sKey, 1, 12)) = '!destination')
                                        or (lowercase(copy(sKey, 1, 11)) = '!sourcefile')
                                        or (lowercase(copy(sKey, 1,  7)) = '!saveas')
                                        or (lowercase(copy(sKey, 1, 13)) = '!overridetype')
                                    then begin
                                        bSkip := true;
                                    end;

                                    // ADDED(2006-01-10)
                                    // If the key begins with AddField, look up the section named sVal and
                                    // add a new field to the GFF file according to those instructions.
                                    if (copy(sKey, 1, 8) = 'AddField') then begin
                                        if (AddGffField(sVal, '') = true) then begin
                                            AddLogLine(Format(LS_LOG_GFFNEWFIELDADDED, [ExtractFileName(l_gff.filename)]), LOG_LEVEL_INFORMATION);
                                            inc(iChanges);
                                        end;
                                        bSkip := true;
                                    end;


                                    //if (sVal = '') then begin
                                    //    bSkip := True;
                                    //    AddLogLine(Format(LS_LOG_GFFBLANKVALUE, [sKey]), LOG_LEVEL_ALERT);
                                    //end;

                                    if (bSkip = False) then begin
                                        // FIX(2006-01-09) Ändrat metodanrop för användning av ny GFF-klass.
                                        if (l_gff.ChangeFieldValue(sKey, sVal) = True) then begin
                                            AddLogLine(Format(LS_LOG_GFFMODIFIEDVALUE, [sVal, sKey, l_dlgopen.FileName]), LOG_LEVEL_VERBOSE);
                                            inc(iChanges);
                                        end
                                        else begin
                                            AddLogLine(Format(LS_LOG_GFFINCORRECTLABEL, [sKey, l_dlgopen.FileName]), LOG_LEVEL_ALERT);
                                        end;
                                    end;

                                end;

                                if (iChanges > 0) then begin
                                   // CHANGED(2006-02-03) Don't do backup if the file is to be written to an ERF!
                                   if (enType = fileGff) then begin
                                       if l_dlgopen.DoBackup() then
                                           AddLogLine(Format(LS_LOG_GFFBACKUPFILE, [l_dlgopen.FileName, IncludeTrailingPathDelimiter(l_path + 'backup')]), LOG_LEVEL_INFORMATION);
                                   end
                                   // CHANGED(2006-08-06) ...but do a backup of the ERF/RIM file instead.
                                   else if (enType = fileGffErf) then begin
                                       if l_dlgopen.DoDestBackup() then
                                           AddLogLine(Format(LS_LOG_GFFBACKUPDEST, [ExtractFileName(l_dlgopen.Destination), IncludeTrailingPathDelimiter(l_path + 'backup')]), LOG_LEVEL_INFORMATION);
                                   end;

                                   AddLogLine(Format(LS_LOG_GFFMODFIELDSUMMARY, [IntToStr(iChanges), ExtractFileName(l_dlgopen.FilePath)]), LOG_LEVEL_VERBOSE);

                                   // FIX(2006-01-09) Ändrat metodanrop för användning av ny GFF-klass
                                   l_gff.SaveFile(l_dlgopen.FilePath);
                                   IncrementProgress(1);


                                   // ADDED(2006-02-03) Save ze modified file in the specified ERF/RIM!
                                   // Then delete the modified temporary file from the TEMP folder.
                                   if (enType = fileGffErf) then begin
                                       // ADDED(2006-09-26) Handle checking for conflicting files in the override folder.
                                       HandleERFOverrideType(l_dlgOpen.FileName, sFilename);

                                       AddLogLine(Format(LS_LOG_GFFINSERTDONE, [ExtractFileName(l_dlgopen.FilePath), sDest]), LOG_LEVEL_INFORMATION);
                                       // Make a backup of the original ERF file, Justin Case...
                                       // REMOVED(2006-08-06) Already done above now...
                                       //if not SysUtils.FileExists(l_datapath + 'bak_' + sDest) then
                                       //    BackupFile(l_datapath + sDest, l_datapath + 'bak_' + sDest);

                                       // TODO Keep open while multiple files are supposed to be inserted, like CompileList.
                                       oERF := TERFHandler.Create();
                                       try
                                           // Load ERF file, add this GFF, save changes.
                                           oERF.Load(l_dlgopen.Destination);
                                           oERF.AddResource(l_dlgopen.FilePath, true);
                                           oERF.Save();

                                           // Remove the work file from the TEMP folder.
                                           if l_dlgopen.InstallMode then
                                               DeleteFile(l_dlgopen.FilePath);
                                       finally
                                           oERF.free();
                                       end;

                                       AddLogLine(Format(LS_LOG_GFFSAVEINERFORRIM, [l_dlgopen.FileName, ExtractFileName(l_dlgopen.Destination)]), LOG_LEVEL_INFORMATION);
                                   end
                                   // CHANGED(2006-08-09) Moved feedback down here.
                                   else begin
                                       AddLogLine(Format(LS_LOG_GFFUPDATEFINISHED, [ExtractFileName(l_dlgopen.FilePath)]), LOG_LEVEL_INFORMATION);
                                   end;

                                   // - - - - - - - - - - - - - - - -
                                end
                                else begin
                                    AddLogLine(Format(LS_LOG_GFFNOCHANGES, [l_dlgopen.FileName]), LOG_LEVEL_ALERT);
                                end;
                            end
                            else begin
                                AddLogLine(Format(LS_LOG_GFFNOMODIFIERS, [sFilename]), LOG_LEVEL_ALERT);
                            end;
                        finally
                            oChangeList.free();
                        end;
                    end
                    else begin
                        AddLogLine(Format(LS_LOG_GFFCANTLOADFILE, [l_dlgopen.FileName]), LOG_LEVEL_ERROR);
                    end;

                end
                else begin
                    AddLogLine(Format(LS_LOG_GFFNOFILEOPENED, [sFilename]), LOG_LEVEL_ALERT);
                end;

            end;
        end;
     finally
         oGffList.free();
     end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-01-10) Support function for DoCompileFiles(). Opens the specified
// file, replaces all #2DAMEMORY*# and #StrRef*# tokens with their corresponding
// value and saves the result as a temporary file whose path&name is returned.
//
// CHANGED(2006-02-05) Allow modifications to INCLUDE files as well. Rework this
// to use a Temp folder to temporarily store the unaltered NSS files while the
// altered ones are used for compilation. Then copy the unaltered file back to
// the tslpatchdata folder after compiling.
// -----------------------------------------------------------------------------
function TTSLPatcher.ReplaceTokensInFile(sFile : string) : TCompileFileInfo;
var
   inFile   : Textfile;
   outFile  : Textfile;
   sTemp    : string;
   sTmpFile : string;
   i        : integer;
   rRes     : TCompileFileInfo;
begin
    // CHANGED(2006-02-05) Use a TEMP folder instead of renaming the files.
    // Save the modified file in the TEMP folder..
    // sTmpFile := ExtractFilePath(sFile) + 'tmp_' + ExtractFileName(sFile);
    sTmpFile       := l_datapath + 'nsspatch_temp\' + ExtractFileName(sFile);
    rRes.ModFile   := sFile;
    rRes.OrgFile   := sTmpFile;
    rRes.IsInclude := true;

    // ADDED(2006-02-05) Copy the unaltered file to the TEMP folder briefly...
    BackupFile(sFile, sTmpFile);

    // CHANGED(2006-02-05) Switched file positions for read/write...
    // Made sure to remove the write protected flag from files, if set.
    MakeFileWritable(sTmpFile);
    MakeFileWritable(sFile);
    assignfile(inFile, sTmpFile);
    assignfile(outFile, sFile);
    reset(inFile);
    rewrite(outFile);
    try
       while not eof(inFile) do
       begin
            // Read a line from the template file...
            readln(inFile, sTemp);

            // ADDED(2006-02-05) Attempt to determine if the file is an include file
            // or a compilable script. Not foolproof, but better than nothing...
            // RegExp, where are you? *sigh*
            if (pos('void main()', lowercase(sTemp)) <> 0)
               or (pos('void main ()', lowercase(sTemp)) <> 0)
               or (pos('int startingconditional()', lowercase(sTemp)) <> 0)
               or (pos('int startingconditional ()', lowercase(sTemp)) <> 0)
            then begin
                rRes.IsInclude := false;
            end;

            // Replace 2DAMEMORY# tokens with their represented value...
            if (l_memory <> nil) and (Length(l_memory) > 0) then begin
                for i := 0 to High(l_memory) do begin
                    sTemp := ReplaceInString(sTemp, '#2DAMEMORY' + IntToStr(i+1) + '#', l_memory[i]);
                end;
            end;

            // Replace StrRef# tokens with their represented value...
            if (l_tlkmap <> nil) and (Length(l_tlkmap) > 0) and (Length(l_tlkmap[0]) > 0) then begin
                for i := Low(l_tlkmap[0]) to High(l_tlkmap[0]) do begin
                    sTemp := ReplaceInString(sTemp, '#StrRef' + IntToStr(l_tlkmap[0, i]) + '#', IntToStr(l_tlkmap[1, i]));
                end;
            end;

            // Write modified line to the TEMP file...
            writeln(outFile, sTemp);
       end;
    finally
       closefile(inFile);
       closefile(outFile);
    end;

    result := rRes;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-01-10) CompileList functionality handler. The files listed in the
// CompileList section has to be NSS Source scripts. The Patcher will then go
// through the NSS file and replace any #2DAMEMORY*# and #StrRef*# tokens it
// can locate with the corresponding values held in memory. It will then attempt
// to recompile the script with a copy of NWNNSSComp.exe it expects to find in
// the tslpatchdata folder. If successful, the recompiled script will be moved
// to the override folder.
// If the Key if File# any existing scripts in Override will not be overwritten.
// If the Key is Replace# any existing scripts will be overwritten.
// For example:
// [CompileList]
// File0=modified.nss
// File2=anothermod.nss
// Replace0=customscript.nss
//
// CHANGED(2006-02-05) Modified to allow processing of include files as well,
// which will not be compiled themselves but used by other scripts.
// IMPORTANT: Include files must be processed BEFORE the scripts that use them!
// -----------------------------------------------------------------------------
procedure TTSLPatcher.DoCompileFiles();
var
   oFileList  : TStringList;
   oOrgList   : TStringList;
   oTempList  : TStringList;
   oTokens    : TStringTokenizer;
   oERF       : TERFHandler;
   rFile      : TCompileFileInfo;
   sLastERF   : string;
   sFileMod   : string;
   sFileName  : string;
   sFile      : string;
   sFileBase  : string;
   sApp       : string;
   sParam     : string;
   sFlags     : string;
   sNcsFile   : string;
   sFeedback  : string;
   sDest      : string;
   sTempFldr  : string;
   sWorkFldr  : string;
   sNcsDest   : string;
// sRelPath   : string;
   sCurr      : string;
   bOverwrite : boolean;
   bOpenERF   : boolean;
   bSaveInERF : boolean;
   bDebugFiles: boolean;
   i          : integer;
   n          : Integer;

   // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    function GetRelativePathFrom(sPath : string; sStartPath : string) : string;
    var
       iPos : integer;
       iLen : integer;
       sTmp : string;
    begin
        sPath := ExtractFilePath(sPath);
        sStartPath := ExtractFilePath(sStartPath);
    
        iPos := Pos(lowercase(sStartPath), lowercase(sPath));
        if (iPos <> 0) then begin
            iLen := iPos + Length(sStartPath);
            sTmp := copy(sPath, iLen, Length(sPath) - (iLen-1));
        end
        else begin
            sTmp := '';
        end;

        iPos := Pos('tslpatchdata', lowercase(sTmp));
        if (iPos <> 0) then begin
            iLen := iPos + Length('tslpatchdata');
            sTmp := copy(sTmp, iLen, Length(sTmp) - (iLen-1));
        end;

        if (sTmp[1] = SysUtils.PathDelim) then
            sTmp := copy(sTmp, 2, Length(sTmp)-1);
    
        result := IncludeTrailingPathDelimiter(sTmp);
        if (result = SysUtils.PathDelim) then
            result := '.' + result;
    end;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    procedure DeleteTempFiles();
    var
      iTempIdx : integer;
    begin
        if (oTempList <> nil) then begin
            for iTempIdx := 0 to (oTempList.Count - 1) do begin
                if SysUtils.FileExists(oTempList[iTempIdx]) then begin
                    SysUtils.DeleteFile(oTempList[iTempIdx]);
                end;
            end;

            oTempList.Clear();
        end;
    end;
begin
     // No CompileList modifiers present in the INI file. No point in continuing...
     if not l_ini.SectionExists('CompileList') then
        exit;

     oFileList := TStringList.Create();
     oOrgList  := TStringList.Create();
     oTempList := TStringList.Create();
     try
        l_ini.ReadSection('CompileList', oFileList);
        if (oFileList.count > 0) then begin
            AddLogLine(LS_LOG_NCSBEGINNING, LOG_LEVEL_INFORMATION);

            // Path to NWNNSSCOMP.EXE...
            // CHANGED(2006-05-05) Changed path to NWNNSSCOMP.EXE to always be present in
            // the tslpatchdata folder even if the files for this Setup is located in a
            // sub-folder.
            // sApp := l_datapath + 'nwnnsscomp.exe';
            sApp := l_path + 'tslpatchdata\nwnnsscomp.exe';


            if not FileExists(sApp) then begin
                AddLogLine(LS_LOG_NCSCOMPILERMISSING, LOG_LEVEL_ERROR);
                exit;
            end;

            // ADDED(2006-02-05) Create Script TEMP folder if it doesn't already exist.
            sWorkFldr := l_datapath + 'nsspatch_temp\';
            ForceDirectories(sWorkFldr);

            // ADDED(2006-09-28) Check if a !DefaultDestination key exists within the
            // CompileList, and if so set it to be the default destination. This will be
            // used if nothing is specified, but can be in turn overridden by each individual
            // file using a !Destination key in its section.
            sNcsDest := l_ini.ReadString('CompileList', '!DefaultDestination', 'override');

            bOpenERF := False;
            sLastERF := '';
            oERF     := nil;

            // ADDED(2006-09-29) Added try...finally here to make sure any open ERF file is closed
            // when all scripts have been handled.
            try
                for i := 0 to (oFileList.count - 1) do begin
                    sFileMod  := oFileList.Strings[i];
                    sFilename := l_ini.ReadString('CompileList', sFileMod, '');

                    // ADDED(2006-09-28) Skip the !DefaultDestination key, it's not a file.
                    if (lowercase(sFileMod) = '!defaultdestination') then begin
                        continue;
                    end;

                    if (lowercase(copy(sFileMod, 1, 7)) = 'replace') then
                       bOverwrite := true
                    else
                       bOverwrite := false;

                    // ADDED(2006-08-06) Read custom destination file, if set.
                    // CHANGED(2006-09-28) Use default destination variable instead of
                    // hardcoded value to 'override'.
                    if l_ini.SectionExists(sFilename) then
                        sDest := l_ini.ReadString(sFilename, '!Destination', sNcsDest)
                    else
                        sDest := sNcsDest;

                    // The finesse of l_dlgopen is pretty much lost in this function,
                    // but whatever... fix some time when I have the energy...
                    if (l_dlgopen.Execute(sFilename, fileCompile, bOverwrite, sDest)) then begin
                        sFile := l_dlgopen.FilePath;

    //!!!!!!!!!!!!!!!!!! WORK IN PROGRESS! THIS IS NOT FINISHED
                        // ADDED(2006-08-12) Attempt to use Relative paths instead of absolute
                        // paths to shorten commandline a bit if the user has the game or
                        // installer placed insanely deep in the folder structure.
                        // sRelPath := GetRelativePathFrom(ExtractFilePath(sFile), IncludeTrailingPathDelimiter(l_path));
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


                        // CHANGED(2006-02-05) Replaced string parameter with Record to keep
                        // track of file type and original file as well...
                        rFile := ReplaceTokensInFile(sFile);
                        oOrgList.Add(rFile.OrgFile);
                        AddLogLine(Format(LS_LOG_NCSPROCESSINGTOKENS, [ExtractFileName(rFile.ModFile)]), LOG_LEVEL_VERBOSE);

                        // CHANGED(2006-07-20) Use the file name as set in the INI file here,
                        // since this should always be the "final" name of the file, while the
                        // file returned from the dlgOpen object may now have another name.
                        // sFileBase := copy(sFile, 1, Pos(ExtractFileExt(sFile), sFile) - 1);
                        // CHANGED(2006-08-09) Not any more! Allow custom target names to be set as well...
                        sFileBase := l_datapath + GetSaveFileName(sFileName); //sFileName;
                        sFileBase := copy(sFileBase, 1, Pos(ExtractFileExt(sFileBase), sFileBase) - 1);
                        sFileBase := sFileBase + '.ncs';

                        // CHANGED(2006-02-05) Skip compile part if the NSS file is assumed
                        // to be an include file.
                        if FileExists(rFile.ModFile) and not rFile.IsInclude then begin
                            // Build commandline to run nwnnsscomp.exe....
                            // ADDED(2006-01-14) Allow specifying extra commandline flags to make it
                            // more compatible with all versions of nwnnsscomp.exe that are in use.
                            sFlags := l_ini.ReadString('Settings', 'ScriptCompilerFlags', '');
                            if (Length(sFlags) > 0) then begin
                                if (sFlags[1] <> ' ') then
                                    sFlags := ' ' + sFlags;

                                if (sFlags[Length(sFlags)] <> ' ') then
                                    sFlags := sFlags + ' ';
                            end;

                            sParam := sFlags + '-c "' + rFile.ModFile + '" -o "' + sFileBase + '"';

                            AddLogLine(Format(LS_LOG_NCSCOMPILINGSCRIPT, [ExtractFileName(rFile.ModFile)]), LOG_LEVEL_INFORMATION);

                            // AddLogLine('DEBUG: "' + sApp + '" ' + sParam , LOG_LEVEL_VERBOSE);

                            // - - - - - - - - - - - - - -
                            // CHANGED(2006-01-27) Trying new variant instead to capture nwnnsscomp.exe
                            // feedback and display in the VERBOSE progress log for debugging...
                            // RunAndWaitShell('"' + sApp + '"', sParam, SW_HIDE);

                            // FIX(2006-03-18) Don't add quotation marks around the sApp value here!
                            // this is now done internally in RunShellGetOutput().
                            // FIX(2006-05-11) Changed CurrentDir path to the EXE folder to work properly
                            //                 with the tk102 edition of nwnnsscomp.exe.
                            // CHANGED(2006-08-12) Keep the current folder set after compilation...
                            sCurr := SysUtils.GetCurrentDir();
                            sFeedback := RunShellGetOutput(sApp, sParam, l_path + 'tslpatchdata\'{l_datapath});
                            SysUtils.SetCurrentDir(sCurr);

                            // TODO: This is FUGLY, update the StringTokenizer class instead to support
                            // using a string instead of a char as token delimiter...
                            if (Length(sFeedback) > 0) then begin
                                oTokens := TStringTokenizer.Create(sFeedback, #10); // Use LF as token

                                for n := 0 to (oTokens.count - 1) do begin
                                    sFeedback := ReplaceInString(oTokens[n], #13, ''); // Remove CR
                                    AddLogLine(Format(LS_LOG_NCSCOMPILEROUTPUT, [sFeedback]), LOG_LEVEL_VERBOSE);
                                end;
                            end;
                            // - - - - - - - - - - - - - -

                            sNcsFile := ExtractFileName(sFileBase);

                            if FileExists(l_datapath + sNcsFile) then begin
                                // ADDED(2006-02-03) See if there is a special section for this
                                // file which defines it should be written to an ERF instead of
                                // ze override folder.
                                bSaveInERF := false;
                                // FIX(2006-09-29) Removed condition for whole block, instead just
                                // check for !Destination if section exists, do the rest regardless.
                                if l_ini.SectionExists(sFilename) then
                                    sDest := l_ini.ReadString(sFilename, '!Destination', sNcsDest)
                                else
                                    sDest := sNcsDest;

                                if (lowercase(sDest) <> 'override') then begin
                                    // REMOVED(2006-08-06) Don't use ERFs in tslpatchdata any longer,
                                    // dlgopen.Execute will check if the ERF/RIM file is in place.
                                    //if not SysUtils.FileExists(l_datapath + sDest) then begin
                                    //    AddLogLine('Unable to save file "' + sNcsFile + '" in ERF archive "' + sDest + '", the ERF file could not be found!', LOG_LEVEL_ERROR);
                                    //    continue;
                                    //end;

                                    // Create TEMP folder if it doesn't already exist.
                                    sTempFldr := IncludeTrailingPathDelimiter(l_datapath + 'erfpatch_temp');
                                    ForceDirectories(sTempFldr);

                                    // Move the compiled NCS file to TEMP folder.
                                    if SysUtils.FileExists(sTempFldr + sNcsFile) then begin
                                        DeleteFile(sTempFldr + sNcsFile);
                                    end;
                                    BackupFile(sFileBase, sTempFldr + sNcsFile);
                                    DeleteFile(sFileBase);

                                    // ADDED(2006-08-06) Make backup of destination ERF/RIM before modifying,
                                    // if it has not already been done.
                                    if l_dlgopen.DoDestBackup() then
                                        AddLogLine(Format(LS_LOG_NCSDESTBACKUP, [ExtractFileName(l_dlgopen.Destination), IncludeTrailingPathDelimiter(l_path + 'backup')]), LOG_LEVEL_INFORMATION);

                                    // Write the file to the ERF!
                                    // TODO: This is not good. It's hideously inefficient to reload/save the ERF for
                                    // every file to add to it if there are many, but it'll have to do for now until I
                                    // can summon the willpower to come up with a nifty system of checking if more files
                                    // should go into the save ERF and keep the file open until all are added. :(
                                    //
                                    // REWRITE(2009-09-29): Open ERF and keep it open until either another ERF is specified
                                    // as destination, or all NSS files have been processed.

                                    // ADDED(2006-09-29) If an ERF is currently open and it isn't the one
                                    // this file has has destination, close it.
                                    if bOpenERF and (sLastERF <> l_dlgopen.Destination) then begin
                                        AddLogLine(Format(LS_LOG_NCSSAVEERFRIM, [ExtractFileName(oERF.FileName)]), LOG_LEVEL_VERBOSE);
                                        oERF.Save();
                                        oERF.free();
                                        oERF := nil;

                                        // FIX(2006-10-01) Must reset the Open boolean as well when closing file!
                                        bOpenERF := false;
                                        sLastERF := '';

                                        // FIX(2006-10-01) Remove the compiled files after the ERF/RIM has been saved!
                                        DeleteTempFiles();
                                    end;


                                    // CHANGED(2006-09-29) If no ERF file is currently open, create an
                                    // ERF handler object.
                                    if (oERF = nil) or not bOpenERF then begin
                                        oERF := TERFHandler.Create();
                                    end;

                                    // REMOVED(2006-09-29) Removed try...finally block around ERF code for
                                    // now since the file should not always be closed when a file has been
                                    // added.
                                
                                    // Load ERF file, add this GFF, save changes.
                                    // CHANGED(2006-09-29) If no ERF file is currently open, open
                                    // the destination file.
                                    if (oERF <> nil) and not bOpenERF then begin
                                        oERF.Load(l_dlgopen.Destination);
                                        sLastERF := l_dlgopen.Destination;
                                        bOpenERF := true;
                                    end;

                                    // ADDED(2006-08-06) Check if the file already exists in the
                                    // archive and abort depending on the Overwrite setting.
                                    if (not bOverwrite) and oERF.GetResourceExists(sNcsFile) then begin
                                        AddLogLine(Format(LS_LOG_NCSFILEEXISTSKIP, [sNcsFile, ExtractFileName(l_dlgopen.Destination)]), LOG_LEVEL_ALERT);
                                    end
                                    else begin
                                        AddLogLine(Format(LS_LOG_NCSSAVEINERFORRIM, [ExtractFileName(sNcsFile), ExtractFileName(l_dlgopen.Destination)]), LOG_LEVEL_INFORMATION);
                                        oERF.AddResource(sTempFldr + sNcsFile, true);
                                    end;

                                    // Remove the work file from the TEMP folder.
                                    // FIX(2006-10-01) Do NOT delete the files before oERF.Save() has been called!!
                                    //                 Queue them up for deletion instead and delete them after the
                                    //                 destination has been saved!
                                    // DeleteFile(sTempFldr + sNcsFile);
                                    oTempList.Add(sTempFldr + sNcsFile);

                                    HandleERFOverrideType(sNcsFile, sFilename, false, sNcsDest);

                                    // Proceed to next file...
                                    bSaveInERF := true;
                                end;

                                // CHANGED(2006-02-03) Added condition to skip this if the file
                                // was saved in an ERF archive.
                                if not bSaveInERF then begin
                                    // Do this here to avoid overwriting the original in case the
                                    // replace or compile process messes up for some reason.
                                    // FIX(2006-01-29) Remove ReadOnly flag before trying to delete...
                                    if (bOverwrite) then begin
                                       MakeFileWritable(l_dlgopen.InstallPath + 'override\' + sNcsFile);
                                       DeleteFile(l_dlgopen.InstallPath + 'override\' + sNcsFile);
                                    end;

                                    // Move the compiled file to override.
                                    BackupFile(sFileBase, l_dlgopen.InstallPath + 'override\' + sNcsFile);
                                    DeleteFile(sFileBase);
                                end;
                            end
                            else begin
                                AddLogLine(Format(LS_LOG_NCSCOMPILEDNOTFOUND, [l_dlgopen.FileName]), LOG_LEVEL_ERROR);
                            end;
                        end
                        else begin
                            if rFile.IsInclude then begin
                                AddLogLine(Format(LS_LOG_NCSINCLUDEDETECTED, [l_dlgopen.FileName]), LOG_LEVEL_VERBOSE);
                            end
                            else begin
                                AddLogLine(Format(LS_LOG_NCSPROCNSSMISSING, [l_dlgopen.FileName]), LOG_LEVEL_ERROR);
                            end;
                        end;
                    end;
                    IncrementProgress(1);
                end;
            // ADDED(2006-09-29) Added try...finally here to make sure any open ERF file is closed.
            finally
                if (oERF <> nil) and bOpenERF then begin
                    // FIX(2006-10-01) I Forgot to save any open file before freeing it... DOH!
                    if oERF.Loaded then begin
                        AddLogLine(Format(LS_LOG_NCSSAVEERFRIM, [ExtractFileName(oERF.FileName)]), LOG_LEVEL_VERBOSE);
                        oERF.Save();

                        // FIX(2006-10-01) Remove the compiled files after the ERF/RIM has been saved!
                        DeleteTempFiles();
                    end;
                        
                    oERF.Free();
                end;

                // CHANGED(2006-09-29) Put below code inside the Finally stage as well to make sure
                // the original scripts are put back no matter what happens above, otherwise subsequent
                // installation attempts may fail if the scripts are not moved back manually.
                
                // ADDED(2006-04-17) Special debug setting that makes the patcher keep a copy of any
                // processed script source files for inspection. They are usually deleted once the
                // scripts have been compiled.
                bDebugFiles := l_ini.ReadBool('Settings', 'SaveProcessedScripts', false);

                // ADDED(2006-02-05) Put the original, unaltered files back into the
                // tslpatchdata folder, overwriting the modified copies.
                for i := 0 to (oOrgList.Count - 1) do begin
                    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    // ADDED(2006-04-17) Keep files for debugging if option is set...
                    if bDebugFiles then begin
                        ForceDirectories(IncludeTrailingPathDelimiter(l_datapath + 'debug'));
                        BackupFile(l_datapath + ExtractFileName(oOrgList[i]), IncludeTrailingPathDelimiter(l_datapath + 'debug') + ExtractFileName(oOrgList[i]));
                    end;
                    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

                    if SysUtils.FileExists(oOrgList[i]) then begin
                        BackupFile(oOrgList[i], l_datapath + ExtractFileName(oOrgList[i]));
                        SysUtils.DeleteFile(oOrgList[i]);
                    end;
                end;

                // ADDED(2006-02-05) Remove the TEMP folder when done working...
                SysUtils.RemoveDir(sWorkFldr);
            end;
        end;
     finally
         oFileList.free();
         oOrgList.free();

         if (oTempList <> nil) then
             oTempList.free();
     end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-03-05) Added rudimentary support for inserting appended StrRefs
// into SSF files.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.UpdateSffFiles();
var
   oFiles     : TStringList;
   oEntries   : TStringList;
   oSSF       : TSSFFile;
   bOverwrite : boolean;
   sFileMod   : string;
   sFilename  : string;
   sKey       : string;
   sVal       : string;
   iCnt       : integer;
   i          : integer;
   n          : integer;
begin
     // No SSFList modifiers present in the INI file. No point in continuing...
     if not l_ini.SectionExists('SSFList') then
        exit;

     oFiles := TStringList.Create();
     try
        // Read the list of SSF files...
        l_ini.ReadSection('SSFList', oFiles);
        for i := 0 to (oFiles.count - 1) do begin
            sFileMod  := oFiles.Strings[i];
            sFilename := l_ini.ReadString('SSFList', sFileMod, '');

            // No need to proceed if  this file has no modifier section...
            if not l_ini.SectionExists(sFilename) then begin
                AddLogLine(Format(LS_LOG_SSFNOMODIFIERS, [sFilename]), LOG_LEVEL_ALERT);
                continue;
            end;

            // Check if existing files should be overwritten or left unmolested.
            if (lowercase(copy(sFileMod, 1, 7)) = 'replace') then
               bOverwrite := true
            else
               bOverwrite := false;

            // Get the filename & path of the file to modify...
            if (sFilename <> '') and l_dlgOpen.Execute(sFilename, fileSSF, bOverwrite) then begin
                // Doublecheck that the file actually exists before proceeding.
                if not SysUtils.FileExists(l_dlgOpen.FilePath) then begin
                    AddLogLine(Format(LS_LOG_SSFFILENOTFOUND, [sFilename]), LOG_LEVEL_ALERT);
                    continue;
                end;

                // Load the SSF file into an object...
                oSSF := TSSFFile.Create();
                try
                    try
                        AddLogLine(Format(LS_LOG_SSFMODSTRREFS, [sFilename]), LOG_LEVEL_INFORMATION);
                        oSSF.Load(l_dlgOpen.FilePath);
                        oEntries := TStringList.Create();
                        iCnt := 0;
                        try
                            // - - - - - - - - - - - - - - - - - - - - - - - - -
                            // Read all entries from the Modifier section and
                            // set the value in the object...
                            l_ini.ReadSection(sFilename, oEntries);
                            for n := 0 to (oEntries.count - 1) do begin
                                sKey := oEntries.Strings[n];
                                sVal := l_ini.ReadString(sFilename, sKey, '-1');

                                // ADDED(2006-07-20) Skip the SourceFile key since it is
                                // not a sound entry but a special directive.
                                if (lowercase(copy(sKey, 1, 11)) = '!sourcefile') then
                                   continue;

                                if (lowercase(copy(sKey, 1, 11)) = '!saveas') then
                                   continue;

                                // Substitute for StrRef value if this is a token,
                                // or memorized value if it's a 2DAMEM token...
                                if (GetIsStringToken(sVal)) then
                                    sVal := IntToStr(ProcessStrRefToken(sVal))
                                else
                                    sVal := GetMemoryToken(sVal);

                                // Update the value in the object...
                                // Make sure the final value is a number...
                                try
                                    oSSF.Entries[sKey] := SafeStrToInt(sVal);
                                    AddLogLine(Format(LS_LOG_SSFSETTINGENTRY, [sKey, sVal]), LOG_LEVEL_VERBOSE);
                                    inc(iCnt);
                                except
                                    on err : EConvertError do
                                        AddLogLine(Format(LS_LOG_SSFINVALIDSTRREF, [sKey, sVal]), LOG_LEVEL_ALERT);
                                end;
                            end;
                            // - - - - - - - - - - - - - - - - - - - - - - - - -
                        finally
                            oEntries.free();
                        end;
                        // Save the changes to the file...
                        oSSF.Save();
                        IncrementProgress(1);
                        AddLogLine(Format(LS_LOG_SSFUPDATESUMMARY, [IntToStr(iCnt), sFilename]), LOG_LEVEL_VERBOSE);
                    except
                        // Skip this file if an exception occurs in the SSF class...
                        on err : ESSFError do begin
                            AddLogLine(Format(LS_LOG_SSFEXCEPTIONERRORS, [err.Message, IntToStr(err.HelpContext)]), LOG_LEVEL_ERROR);
                            continue;
                        end;
                    end;
                finally
                    oSSF.free();
                end;

            end
            else begin
                AddLogLine(Format(LS_LOG_SSFNOFILE, [sFilename]), LOG_LEVEL_ALERT);
            end;
        end;
     finally
         oFiles.free();
     end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-09-14) Count the number of file the patcher should work on, from
// the currently loaded Config INI file.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.ReadFileCountFromConfig();
var
   i      : integer;
   oList  : TStringList;
   oLocs  : TStringList;
   arrSec : array[0..4] of string;
begin
    l_progcnt := 0;
    l_progmax := 0;

    oList := TStringList.Create();
    l_ini.ReadSection('TLKList', oList);
    if (oList.count > 0) then
        inc(l_progmax, 1);
    oList.Free();

    arrSec[0] := '2DAList';
    arrSec[1] := 'GFFList';
    arrSec[2] := 'HACKList';
    arrSec[3] := 'CompileList';
    arrSec[4] := 'SSFList';

    for i := 0 to 4 do begin
        oList := TStringList.Create();
        l_ini.ReadSection(arrSec[i], oList);
        if (oList.count > 0) then
            inc(l_progmax, oList.count);
        oList.Free();
    end;

    oLocs := TStringList.Create();
    l_ini.ReadSection('InstallList', oLocs);
    if (oLocs.count > 0) then begin
        for i := 0 to (oLocs.count - 1) do begin
            oList := TStringList.Create();
            l_ini.ReadSection(oLocs[i], oList);
            if (oList.count > 0) then
                inc(l_progmax, oList.count);
            oList.Free();
        end;
    end;
    oLocs.Free();
end;


procedure TTSLPatcher.IncrementProgress(iCnt : Integer);
begin
    inc(l_progcnt, iCnt);
    if Assigned(ProgressCallback) then
        ProgressCallback(l_progcnt, l_progmax);

    if (l_progcnt > l_progmax) then begin
        AddLogLine('DEBUG: ProgressCount is larger than ProgressMax! Uh oh...', LOG_LEVEL_VERBOSE);
    end;
end;


// -----------------------------------------------------------------------------
// Main function of the class, goes through the INI file and performs operations
// on TLK, GFF and 2DA files as instructed.
// CHANGED(2006-02-07) Changed to function returning the number or errors and
// warnings encountered.
// -----------------------------------------------------------------------------
function TTSLPatcher.RunPatchOperation() : TPatcherResult;
var
   oFileList   : TStringList;
   oChangeList : TStringList;
   i, n        : integer;
   sFilename   : string;
   sGroupName  : string;
   sCommand    : string;
   rRes        : TPatcherResult;
begin
    if (l_2da = nil) then
        raise EDead.Create('Unable to load the 2da table handler!');

     // ADDED(2005-06-07) - Added Date & time, and message reflecting the Run mode of the Patcher.
     if (l_dlgopen.InstallMode) then
         AddLogLine(Format(LS_LOG_RPOINSTALLSTART, [DateTimeToStr(Now)]), LOG_LEVEL_NOTICE)
     else
         AddLogLine(Format(LS_LOG_RPOPATCHSTART, [DateTimeToStr(Now)]), LOG_LEVEL_NOTICE);

     rRes.Warnings := 0;
     rRes.Errors := 0;

     try
        // ADDED(2006-09-14) Count how many files will be patched.... Used for progress feedback.
        ReadFileCountFromConfig();

        // FIX(2006-12-12) Ugly quick fix, try to load the dialog.tlk file to ensure
        //                 all file paths and requirement checks are always done.
//       if (l_dlgopen.InstallMode) then
//           l_dlgopen.Execute('dialog.tlk', fileTlk);

         // Check if there are any custom string tokens, and if so update the
         // dialog.tlk file with them.
        ProcessTLKData();

        // CHANGED(2006-08-06) Moved this up here. Was after the other sections
        // before. Now copy unaltered files before doing anything else.
        // Copy the files that should just be installed and nothing else done
        // with them, if any.
        DoInstallFiles();

        // Patch 2DA files...
        // TODO: This should probably go in its own sub-function as well like the other parts...
        //       sometime... when I feel like cleaning up this mess of code. :)
        oFileList := TStringList.Create();
        try
             l_ini.ReadSection('2DAList', oFileList);

             // Go through all the 2da files that should be changed.
             for i := 0 to (oFileList.count - 1) do begin
                 sFilename := l_ini.ReadString('2DAList', oFileList.Strings[i], '');
                 l_currentfile := sFilename;

                 if ((sFileName <> '') and l_dlgopen.Execute(sFilename, file2da)) then begin
                    // TODO: WTF? Shouldn't there be an exception here?
                    // CHANGED(2006-07-20) Added log-error if the file could not be found...
                    if (FileExists(l_dlgopen.FilePath) = False) then begin
                       AddLogLine(Format(LS_LOG_2DAFILENOTFOUND, [ExtractFileName(l_dlgopen.FilePath)]), LOG_LEVEL_ERROR);
                       break;
                    end;

                    // Open 2da file to change.
                    l_2da.Load2daFile(l_dlgopen.FilePath);
                   // AddLogLine('Modifying 2DA file ' + sFileName + '...', LOG_LEVEL_INFORMATION);

                    if (l_2da.isloaded = True) then begin
                        oChangeList := TStringList.Create();
                        try
                            l_ini.ReadSection(sFileName, oChangeList);

                            // Go through all the changed to apply to this 2da file.
                            for n := 0 to (oChangeList.count - 1) do begin
                                sCommand := oChangeList.strings[n];
                                sGroupName := l_ini.ReadString(sFilename, oChangeList.strings[n], '');
                                if ((sGroupName <> '') and (sCommand <> '')) then begin
                                    // Add a new line to the 2da.
                                    if (Pos('AddRow', sCommand) <> 0) then begin
                                        Add2daLine(sGroupName);
                                    end
                                    // Modify existing line in the 2da.
                                    else if (Pos('ChangeRow', sCommand) <> 0) then begin
                                        Change2daLine(sGroupName);
                                    end
                                    // Add a new column to the 2da.
                                    else if (Pos('AddColumn', sCommand) <> 0) then begin
                                        Add2daColumn(sGroupName);
                                    end
                                    // Add a new column to the 2da.
                                    else if (Pos('CopyRow', sCommand) <> 0) then begin
                                        Copy2daLine(sGroupName);
                                    end
                                    else begin
                                        // ADDED(2005-05-23) - Meddela ev. skrivfel i modifier-listan...
                                        AddLogLine(Format(LS_LOG_2DAINVALIDMODIFIER, [sCommand, sGroupName]), LOG_LEVEL_ALERT);
                                    end;
                                end;
                            end;

                            if l_dlgopen.DoBackup() then
                               AddLogLine(Format(LS_LOG_2DABACKUPFILE, [l_dlgopen.FileName, IncludeTrailingPathDelimiter(l_path + 'backup') + sFilename]), LOG_LEVEL_INFORMATION);

                            // Save the changed 2da file.
                            l_2da.Save2daFile(l_dlgopen.FilePath);
                            IncrementProgress(1);
                            AddLogLine(Format(LS_LOG_2DAFILEUPDATED, [l_dlgopen.FilePath]), LOG_LEVEL_INFORMATION);
                        finally
                            oChangeList.free();
                        end;
                    end // isloaded
                    else begin
                         AddLogLine(Format(LS_LOG_2DALOADERROR, [sFilename]), LOG_LEVEL_ALERT);
                    end;
                 end // opendialog
                 else begin
                      AddLogLine(Format(LS_LOG_2DANOFILESELECTED, [sFilename]), LOG_LEVEL_ALERT);
                 end;
             end; // filelist loop

             // Check if any GFF files should be updated, and if so, do it!
             UpdateGffFiles();

             // Check if any unspecified format binary files should be patched/hacked,
             // and if so do it! This is a poweruser++ feature since it relies on
             // in-file offsets to do its thing. Easy to mess things up if a file is
             // changed and you forget to verify that the data offset is the same.
             UpdateHackFiles();

             // ADDED(2006-01-10) Check if there is a CompileList of NSS files that should be
             // processed for tokens and then re-compiled with nwnnsscomp.exe before being
             // moved to override
             DoCompileFiles();

             // ADDED(2006-03-05) Allow updating SSF files with appended dialog.tlk StrRefs.
             UpdateSffFiles();

             // ADDED(2006-02-03) Delete the TEMP folder when done working, if it is empty...
             SysUtils.RemoveDir(IncludeTrailingPathDelimiter(l_datapath + 'erfpatch_temp'));

             // ADDED(2006-02-07) Added function return value...
             rRes.Warnings := l_logalerts;
             rRes.Errors   := l_logerrors;

             // If we get here, everything hopefully worked as intended...
             // FIX(2005-06-07) Summarize any Alerts and Errors that were logged to inform
             // users who won't read the whole the log that something may have gone wrong.
             if (l_logalerts > 0) and (l_logerrors = 0) then
                 AddLogLine(Format(LS_LOG_RPOSUMMARYWARN, [IntToStr(l_logalerts)]), LOG_LEVEL_NOTICE)
             else if (l_logalerts = 0) and (l_logerrors > 0) then
                 AddLogLine(Format(LS_LOG_RPOSUMMARYERROR, [IntToStr(l_logerrors)]), LOG_LEVEL_NOTICE)
             else if (l_logalerts > 0) and (l_Logerrors > 0) then
                 AddLogLine(Format(LS_LOG_RPOSUMMARYWARNERROR, [IntToStr(l_logerrors), IntToStr(l_logalerts)]), LOG_LEVEL_NOTICE)
             else
                 AddLogLine(LS_LOG_RPOSUMMARY, LOG_LEVEL_NOTICE);

        finally
            oFileList.free();
        end;
     except
         // Write the Exception error messages in the log as well...
         on e : EHell do begin
             AddLogLine(e.Message + ' (TLK)', LOG_LEVEL_ERROR);
             raise;
         end;

         on e : EDead do begin
             AddLogLine(e.Message + ' (2DA-' + IntToStr(e.HelpContext) + ')', LOG_LEVEL_ERROR);
             raise;
         end;

         on e : EAbort do begin
             AddLogLine(e.Message + ' (GEN-' + IntToStr(e.HelpContext) + ')', LOG_LEVEL_ERROR);
             raise;
         end;

         on e : EGFFError do begin
             AddLogLine(e.Message + ' (GFF-' + IntToStr(e.HelpContext) + ')', LOG_LEVEL_ERROR);
             raise;
         end;

         on e : EFOpenError do begin
             AddLogLine(e.Message + ' (EXT-' + IntToStr(e.HelpContext) + ')', LOG_LEVEL_ERROR);
             raise;
         end;

         // ADDED(2006-08-06 Add unhandled exceptions to the log as well.
         on e : Exception do begin
             AddLogLine(Format(LS_LOG_RPOGENERALEXCEPTION, [e.Message, IntToStr(e.HelpContext)]), LOG_LEVEL_ERROR);
             raise;
         end;
     end;

     // ADDED(2006-02-07) Added function return value...
     result := rRes;
end;


// -----------------------------------------------------------------------------
// 2005-06-07
// Very ugly, since I hadn't thought of this functionality to begin with...
// This will have to do until I have the inspiration to rewrite the Copy2daline
// and Add2daLine functions to better handle this.
// iOldRow is set to the line number of the existing row that was found, or
// -1 if no existing row was found.
// -----------------------------------------------------------------------------
function TTSLPatcher.CheckForNonExclusiveLabel(sSection, sExclusive : string; var iOldRow : integer) : boolean;
var
   bHasLabel : boolean;
   sValue    : string;
   iCol      : integer;
   i         : integer;
begin
    bHasLabel := False;
    iOldRow   := -1;

    // First check if the specified column label exists in the target table.
    for i := 0 to (l_2da.colcount - 1) do begin
        if (l_2da.clabels[i] = sExclusive) then begin
            bHasLabel := True;
            break;
        end;
    end;

    // Table does not have specified column, just allow it to continue...
    if not bHasLabel then begin
        AddLogLine(Format(LS_LOG_EXCLUSIVECOLINVALID, [sExclusive]), LOG_LEVEL_ALERT);
        iOldRow := -1;
        result := True;
        exit;
    end;

    // Look up value in modifier that must be exclusive for this column.
    sValue := l_ini.ReadString(sSection, sExclusive, '');
    
    // Check if any other row has the same value in this column...
    if (sValue <> '') then begin
        iCol := l_2da.GetColByLabel(sExclusive);

        for i := 0 to (l_2da.rowcount - 1) do begin
            // Match found, return value to indicate the new row should not be added.
            // FIX(2005-06-12) Justerade log-meddelandet lite då det inte alls är säkert
            // att raden hoppas över längre.
            if (l_2da.entry[i, iCol] = sValue) then begin
                AddLogLine(Format(LS_LOG_EXCLUSIVEMATCHFOUND, [sExclusive, IntToStr(i)]), LOG_LEVEL_VERBOSE);
                iOldRow := i;
                result := False;
                exit;
            end;
        end;
    end
    else begin
        AddLogLine(Format(LS_LOG_NOEXCLUSIVEVALUESET, [sExclusive, sSection]), LOG_LEVEL_ERROR);
        iOldRow := -1;
        result := False;
        exit;
    end;

    // No match on existing rows found, indicate that new row should be added.
    iOldRow := -1;
    result := True;
end;

// -----------------------------------------------------------------------------
// 2005-06-10
// Support function used if an AddLine/CopyLine is set to be exclusive and an
// existing row has the same value in the exclusive column. Modify the existing
// row instead with the specified Add/Copy values.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.ModifyRowFallback(sSection : string; iIndex : integer);
var
  oColList : TStringList;
  bDoOnce  : boolean;
  j        : integer;
  iColumn  : integer;
  sValue   : string;
  sKey     : string;
begin
    if (iIndex < 0) then begin
        AddLogLine(Format(LS_LOG_2DAEXROWNOTFOUND, [sSection]), LOG_LEVEL_ALERT);
        exit;
    end;

    if (iIndex > (l_2da.rowcount - 1)) then begin
        AddLogLine(Format(LS_LOG_2DAEXROWINDEXTOOHIGH, [sSection]), LOG_LEVEL_ALERT);
        exit;
    end;

    bDoOnce := False;
    oColList := TStringList.Create();
    try
        l_ini.ReadSection(sSection, oColList);

        // Go through all columns that should be changed and apply changes.
        for j := 0 to (oColList.count - 1) do begin
            sKey   := oColList.strings[j];
            sValue := l_ini.ReadString(sSection, sKey, '');

            // Its the old Add/Copy Index or new row label, just ignore it....
            if ((lowercase(sKey) = 'rowindex')
                or (lowercase(sKey) = 'rowlabel')
                or (lowercase(sKey) = 'newrowlabel')
                or (lowercase(sKey) = 'exclusivecolumn'))
            then begin
               // Do nothing...
            end
            // It's one of the Add/Copy specific token values, skip them and keep existing value.
            else if (lowercase(copy(sValue, 1, 6)) = 'high()') or (lowercase(copy(sValue, 1, 4)) = 'inc(') then begin
                // Do nothing either...
            end
            // It's a memory token, store the specified cell value...
            else if SetMemoryToken(sKey, sValue, ACTION_MODIFY_ROW, iIndex) then begin
                 // do nothing more for this key, SetMemToken does all that needs to be done...
            end
            // It's one of the normal column names
            else if ((iIndex <> -1) and (sKey <> '')) then begin
                 if (sValue = '') then
                    sValue := '****';

                 if (GetIsStringToken(sValue)) then
                    sValue := IntToStr(ProcessStrRefToken(sValue));

                 try
                     iColumn := l_2da.GetColByLabel(sKey);
                     if (iColumn <> -1) and (iColumn < l_2da.colcount) then begin
                         sValue := GetMemoryToken(sValue);

                         if (l_2da.entry[iIndex, iColumn] <> sValue) then begin
                             l_2da.entry[iIndex, iColumn] := sValue;

                             if (bDoOnce = False) then begin
                                 AddLogLine(Format(LS_LOG_2DAEXROWMATCH, [IntToStr(iIndex), l_currentfile]), LOG_LEVEL_VERBOSE);
                                 bDoOnce := True;
                             end;
                         end;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine(Format(LS_LOG_2DAINVALIDCOLLABEL, [sKey]), LOG_LEVEL_ALERT)
                          else if (e.HelpContext <> 8) then
                             raise;
                       end;
                 end;
            end;
        end;
    finally
        oColList.free();
    end;
end;


// -----------------------------------------------------------------------------
// Support function for RunPatchOperation() - adds a new line to the currently
// loaded 2DA file according to the instructions in the INI section specified
// by the parameter.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.Add2daLine(sSection : string);
var
  oColList : TStringList;
  j, i     : integer;
  iLine    : integer;
  iColumn  : integer;
  iVal     : integer;
  iInc     : integer;
  iCurrRow : integer;
  sTemp    : string;
  sValue   : string;
  sKey     : string;
  bAdded   : boolean;
begin
    iCurrRow := -1;
    oColList := TStringList.Create();
    try
        bAdded := False;
        iLine  := -1;

        // ADDED(2006-07-08) Check for the ExclusiveColumn key specifically here,
        // to avoid having to keep keys in sequence.
        sValue := l_ini.ReadString(sSection, 'ExclusiveColumn', '');
        if (sValue <> '') then begin
            if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                ModifyRowFallback(sSection, iCurrRow);
                exit;
            end;
        end;


        l_ini.ReadSection(sSection, oColList);

        // Go through all listed columns (from the .ini) and set their values.
        for j := 0 to (oColList.count - 1) do begin
            sKey := oColList.strings[j];
            sValue := l_ini.ReadString(sSection, sKey, '');
            
            // ADDED(2005-06-07) A column has been set for Exclusive checking.
            // Keyword must come above column labels since the 2da class currently
            // has no rollback functionality. Must be intercepted before anything is added.

            // CHANGED(2006-07-08) Uh...no. Just skip the ExclusiveColumn key here entirely
            // and check for it specifically before reading column labels, silly...
            if (sKey = 'ExclusiveColumn') then begin
               continue;
            end
            (*
            if ((bAdded = False) and (sKey = 'ExclusiveColumn') and (sValue <> '')) then begin
                // A Row with the same value in the specified column as this one already exists,
                // skip copying this row.
                if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                    ModifyRowFallback(sSection, iCurrRow);
                    exit;
                end;
            end
            *)
            // If the rowlabel is set in the .ini, set it. Otherwise default
            // value identical to line index will be used.
            else if (lowercase(sKey) = 'rowlabel') then begin
                 // ----------------------------------------------------------
                // ADDED(2005-08-23) Added high() modifier for RowLabel too...
                // Special modifier! Make the substituted value be the highest in the column.
                if (lowercase(copy(sValue, 1, 6)) = 'high()') then begin
                    iInc := 0;
                    for i := 0 to (l_2da.rowcount - 1) do begin
                        sTemp := l_2da.rlabels[i];
                        if (GetIsNumber(sTemp)) then begin
                            iVal := StrToInt(sTemp);
                            if (iVal > iInc) then
                                iInc := iVal;
                        end;
                    end;
                    sValue := IntToStr(iInc + 1);
                    AddLogLine(Format(LS_LOG_2DAHIGHTOKENRLFOUND, [sValue]), LOG_LEVEL_VERBOSE);
                end;
                // ----------------------------------------------------------

               sValue := GetMemoryToken(sValue);
               if (sValue <> '') then begin
                  if (bAdded = False) then begin
                      iLine := l_2da.addline();
                      AddLogLine(Format(LS_LOG_2DAADDINGROW, [IntToStr(iLine), l_currentfile]), LOG_LEVEL_VERBOSE);
                      bAdded := True;
                  end;

                  if (iLine <> -1) then begin
                      l_2da.rlabels[iLine] := sValue;
                  end
                  else begin
                      AddLogLine(Format(LS_LOG_2DASETROWLABELERROR, [sValue, sSection]), LOG_LEVEL_ALERT);
                  end;
               end;
            end
            // It's a memory assignment token, store the assigned cell data in the memory
            // then abort this iteration.
            else if ((bAdded = True) and SetMemoryToken(sKey, sValue, ACTION_ADD_ROW, iLine)) then begin
                 // do nothing more for this key...
            end
            // Add the value to the specified columns from the .ini file.
            else begin
                 if (bAdded = False) then begin
                     iLine := l_2da.addline();
                     AddLogLine(Format(LS_LOG_2DAADDINGROW, [IntToStr(iLine), l_currentfile]), LOG_LEVEL_VERBOSE);
                     bAdded := True;
                 end;

                 if (sValue = '') then
                     sValue := '****';

                 if (GetIsStringToken(sValue)) then
                    sValue := IntToStr(ProcessStrRefToken(sValue));

                 try
                     iColumn := l_2da.GetColByLabel(sKey);
                     if (iColumn <> -1) and (iColumn < l_2da.colcount) then begin
                         // ADDED(2005-06-07) Added high() modifier for AddLine too...
                         // Special modifier! Make the substituted value be the highest in the column.
                         if (lowercase(copy(sValue, 1, 6)) = 'high()') then begin
                             iInc := 0;
                             for i := 0 to (l_2da.rowcount - 1) do begin
                                 sTemp := l_2da.entry[i, iColumn];
                                 if (GetIsNumber(sTemp)) then begin
                                     iVal := StrToInt(sTemp);
                                     if (iVal > iInc) then
                                         iInc := iVal;
                                 end;
                             end;
                             sValue := IntToStr(iInc + 1);
                             AddLogLine(Format(LS_LOG_2DAHIGHTOKENVALUE, [sKey, sValue]), LOG_LEVEL_VERBOSE);
                         end;

                         sValue := GetMemoryToken(sValue);
                         if (iLine <> -1) then
                             l_2da.entry[iLine, iColumn] := sValue
                         else begin
                             AddLogLine(Format(LS_LOG_2DAADDROWERROR, [sSection]), LOG_LEVEL_ERROR);
                             exit;
                         end;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine(Format(LS_LOG_2DAINVALIDCOLLABEL, [sKey]), LOG_LEVEL_ALERT)
                          else if (e.HelpContext <> 8) then
                             raise;
                       end;
                 end;
                 
            end;
        end;
    finally
        oColList.free();
    end;
end;


// -----------------------------------------------------------------------------
// Support function for Change2daLine(), allows the LABEL column to be used as
// identifier index, if present in the 2DA file.
// -----------------------------------------------------------------------------
function TTSLPatcher.CheckLabelIdentifier(var iIndex : integer; sSection, sKey, sValue : string) : boolean;
var
   bHasLabel : boolean;
   i         : integer;
   iCol      : integer;
begin
    result := False;
    if (sKey = 'LabelIndex') and (sValue <> '') and (iIndex = -1) then begin
        // First check if thelabel column exists in the target table.
        bHasLabel := False;
        for i := 0 to (l_2da.colcount - 1) do begin
            if (l_2da.clabels[i] = 'label') then begin
                bHasLabel := True;
                break;
            end;
        end;

        if (bHasLabel = False) then begin
            AddLogLine(Format(LS_LOG_2DANOLABELCOL, [sKey, sSection]), LOG_LEVEL_ERROR);
            exit;
        end;

        iCol := l_2da.GetColByLabel('label');
        for i := 0 to (l_2da.rowcount - 1) do begin
            if (l_2da.entry[i, iCol] = sValue) then begin
                if (iIndex <> -1) then begin
                    AddLogLine(LS_LOG_2DANONEXCLUSIVECOL, LOG_LEVEL_ALERT);
                    AddLogLine(Format(LS_LOG_2DAMULTIMATCHINDEX, [IntToStr(iIndex), IntToStr(i)]), LOG_LEVEL_VERBOSE);
                end;

                iIndex := i;
                result := True;
            end;
        end;

    end;
end;

// -----------------------------------------------------------------------------
// Support function for RunPatchOperation() - modifies values of a line in the
// loaded 2DA file according to the instructions in the INI section specified
// by the parameter.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.Change2daLine(sSection : string);
var
  oColList : TStringList;
  j        : integer;
  i        : integer;
  iIndex   : integer;
  iColumn  : integer;
  iInc     : integer;
  iVal     : integer;
  sValue   : string;
  sKey     : string;
  sTemp    : string;
begin
    iIndex := -1;
    oColList := TStringList.Create();
    try
        l_ini.ReadSection(sSection, oColList);

        // Go through all columns that should be changed and apply changes.
        for j := 0 to (oColList.count - 1) do begin
            sKey   := oColList.strings[j];
            sValue := l_ini.ReadString(sSection, sKey, '');

            // It's the index key that tells which line to modify.
            if ((lowercase(sKey) = 'rowindex') and (iIndex = -1) and (sValue <> '')) then begin
               sValue := GetMemoryToken(sValue);
               iIndex :=  StrToInt(sValue);

               if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                  iIndex := -1
               else
                  AddLogLine(Format(LS_LOG_2DAMODIFYLINE, [IntToStr(iIndex), l_currentfile]), LOG_LEVEL_VERBOSE);

            end
            // It's the row label that tells which line to modify. MutEx with the above.
            else if ((lowercase(sKey) = 'rowlabel') and (iIndex = -1) and (sValue <> '')) then begin
                try
                   sValue := GetMemoryToken(sValue);
                   iIndex := l_2da.GetRowByLabel(sValue);

                   if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                      iIndex := -1
                   else
                       AddLogLine(Format(LS_LOG_2DAMODIFYLINE, [IntToStr(iIndex), l_currentfile]), LOG_LEVEL_VERBOSE);

                except
                      on e : EDead do begin
                         if (e.HelpContext = 10) then
                            iIndex := -1
                         else
                            raise;
                      end;
                end;
            end
            // ADDED(2005-06-07) - Tillåt användning av LABEL kolumnen som radidentifierare, om denna finns
            // i den aktuella 2DA-filen. Om flera rader matchar angivet Index används sist funna raden.
            else if ((iIndex = -1) and CheckLabelIdentifier(iIndex, sSection, sKey, sValue)) then begin
               if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                  iIndex := -1
               else
                  AddLogLine(Format(LS_LOG_2DAMODIFYLINE, [IntToStr(iIndex), l_currentfile]), LOG_LEVEL_VERBOSE);
            end
            // ADDED(2005-05-23) - Visa felmeddelande om radidentifierare saknas.
            else if (iIndex = -1) and (lowercase(sKey) <> 'rowlabel') and (lowercase(sKey) <> 'rowindex') then begin
                AddLogLine(Format(LS_LOG_2DANOINDEXFOUND, [sSection]), LOG_LEVEL_ERROR);
                exit;
            end
            // It's a memory token, store the specified cell value...
            else if ((iIndex <> -1) and SetMemoryToken(sKey, sValue, ACTION_MODIFY_ROW, iIndex)) then begin
                 // do nothing more for this key...
            end
            // It's one of the normal column names
            else if ((iIndex <> -1) and (sKey <> '')) then begin
                 if (sValue = '') then
                    sValue := '****';

                 if (GetIsStringToken(sValue)) then
                    sValue := IntToStr(ProcessStrRefToken(sValue));

                 try
                     iColumn := l_2da.GetColByLabel(sKey);
                     if (iColumn <> -1) and (iColumn < l_2da.colcount) then begin

                         // ---------------------------------------------------
                         // ADDED(2006-11-30) Added high() modifier for ChangeRow too...
                         // Special modifier! Make the substituted value be the highest in the column.
                         if (lowercase(copy(sValue, 1, 6)) = 'high()') then begin
                             iInc := 0;
                             for i := 0 to (l_2da.rowcount - 1) do begin
                                 sTemp := l_2da.entry[i, iColumn];
                                 if (GetIsNumber(sTemp)) then begin
                                     iVal := StrToInt(sTemp);
                                     if (iVal > iInc) then
                                         iInc := iVal;
                                 end;
                             end;
                             sValue := IntToStr(iInc + 1);
                             AddLogLine(Format(LS_LOG_2DAHIGHTOKENVALUE, [sKey, sValue]), LOG_LEVEL_VERBOSE);
                         end;
                         // ---------------------------------------------------
                     
                         sValue := GetMemoryToken(sValue);
                         l_2da.entry[iIndex, iColumn] := sValue;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine(Format(LS_LOG_2DAINVALIDCOLLABEL, [sKey]), LOG_LEVEL_ALERT)
                          else if (e.HelpContext <> 8) then
                             raise;
                       end;
                 end;
            end;
        end;
    finally
        oColList.free();
    end;
end;


// -----------------------------------------------------------------------------
// Support function for RunPatchOperation() - adds a new column to the currently
// loaded 2DA file according to the instructions in the INI section specified
// by the parameter.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.Add2daColumn(sSection : string);
var
  oColList : TStringList;
  iNewCol : integer;
  k, l    : integer;
  iIndex  : integer;
  sKey    : string;
  sValue  : string;
  sIndex  : string;
  sDefault: string;
  sDefOld : string;
  bAdded  : boolean;
begin
    oColList := TStringList.Create();
    try
        l_ini.ReadSection(sSection, oColList);

        AddLogLine(Format(LS_LOG_2DAADDCOLUMN, [l_currentfile]), LOG_LEVEL_VERBOSE);

        iNewCol := -1;
        bAdded := False;
        sDefault := '****';
        // Go through all the modifiers and apply them to the new line
        for k := 0 to (oColList.count - 1) do begin
            sKey   := oColList.strings[k];
            sValue := l_ini.ReadString(sSection, sKey, '');

            // Set the Label of the new column
            if (lowercase(sKey) = 'columnlabel') and (bAdded = False) then begin
               if (sValue <> '') then begin
                  sValue := GetMemoryToken(sValue);
                  // Check that a column with this label doesn't already exist.
                  // Columns must have unique labels.
                  for l := 0 to (l_2da.colcount - 1) do begin
                      if (l_2da.clabels[l] = sValue) then begin
                          AddLogLine(Format(LS_LOG_2DACOLEXISTS, [sValue, l_currentfile]), LOG_LEVEL_ERROR);
                          exit;
                      end;
                  end;

                  // Add the new column and set its label.
                  iNewCol := l_2da.AddColumn();
                  l_2da.clabels[iNewCol] := sValue;
                  bAdded := True;
               end;
            end
            else if ((bAdded = True) and SetMemoryToken(sKey, sValue, ACTION_ADD_COLUMN, iNewCol)) then begin
                 // Do nothing more for this key...
            end
            // Set the default value for undefined row entries in the column.
            else if ((lowercase(sKey) = 'defaultvalue') and (bAdded = True)) then begin
                 if (sValue <> '') then begin
                    if (GetIsStringToken(sValue)) then
                        sValue := IntToStr(ProcessStrRefToken(sValue));

                    sValue := GetMemoryToken(sValue);
                    sDefOld := sDefault;
                    sDefault := sValue;

                    // Change the default values set at column creation.
                    for l := 0 to (l_2da.rowcount - 1) do begin
                        if (l_2da.entry[l, iNewCol] = sDefOld) then
                           l_2da.entry[l, iNewCol] := sDefault;
                    end;
                 end;
            end
            // Set values defined for individual rows in the new column.
            else if (bAdded = True) then begin
                 if (sValue = '') then
                    sValue := sDefault;

                 if (GetIsStringToken(sValue)) then
                     sValue := IntToStr(ProcessStrRefToken(sValue));

                 sIndex := copy(sKey, 2, length(sKey));
                 if ((lowercase(sKey[1]) = 'i') and GetIsNumber(sIndex)) then begin
                    iIndex := StrToInt(sIndex);

                    if ((iIndex >= 0) and (iIndex < l_2da.rowcount)) then
                       l_2da.entry[iIndex, iNewCol] := sValue;

                 end
                 else if ((lowercase(sKey[1]) = 'l') and (sIndex <> '')) then begin
                      try
                         iIndex := l_2da.GetRowByLabel(sIndex);
                         sValue := GetMemoryToken(sValue);

                         if ((iIndex >= 0) and (iIndex < l_2da.rowcount)) then
                            l_2da.entry[iIndex, iNewCol] := sValue;
                      except
                           // Missing row values are not fatal, just skip it.
                           on e : EDead do begin
                              if (e.HelpContext = 10) then
                                 AddLogLine(Format(LS_LOG_2DAINVALIDROWLABEL, [sIndex]), LOG_LEVEL_ALERT)
                              else if (e.HelpContext <> 10) then
                                 raise;
                           end;
                      end;
                 end;
            end;
        end;
    finally
        oColList.free();
    end;
end;


// -----------------------------------------------------------------------------
// Support function for RunPatchOperation() - copies an existing row, adds the
// new row to the end and modified the values of that row in the currently
// loaded 2DA file according to the instructions in the INI section specified
// by the parameter.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.Copy2daLine(sSection : string);
var
  oColList : TStringList;
  m        : integer;
  iIndex   : integer;
  iOld     : integer;
  iColumn  : integer;
  iInc     : integer;
  iVal     : integer;
  iRow     : integer;
  iCurrRow : integer;
  sValue   : string;
  sKey     : string;
  sNewLabel: string;
  sTemp    : string;
  bCloned  : boolean;
begin
    iIndex    := -1;
    iCurrRow  := -1;
    bCloned   := False;
    sNewLabel := '';

    oColList := TStringList.Create();
    try
        // ADDED(2006-07-08) Check for the ExclusiveCol key here instead to allow it
        // to occur anywhere in the section to reduce some potential for errors.
        sValue := l_ini.ReadString(sSection, 'ExclusiveColumn', '');
        if (sValue <> '') then begin
            if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                ModifyRowFallback(sSection, iCurrRow);
                exit;
            end;
        end;

        l_ini.ReadSection(sSection, oColList);

        // Go through all columns that should be changed and apply changes.
        for m := 0 to (oColList.count - 1) do begin
            sKey   := oColList.strings[m];
            sValue := l_ini.ReadString(sSection, sKey, '');

            // It's the index key that tells which line to copy. MutEx with the next condition.
            if ((lowercase(sKey) = 'rowindex') and (iIndex = -1) and GetIsNumber(sValue)) then begin
               sValue := GetMemoryToken(sValue);
               iIndex :=  StrToInt(sValue);
               if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                  iIndex := -1
            end
            // It's the row label that tells which line to copy. MutEx with the above condition.
            else if ((lowercase(sKey) = 'rowlabel') and (iIndex = -1) and (sValue <> '')) then begin
                try
                   sValue := GetMemoryToken(sValue);
                   iIndex := l_2da.GetRowByLabel(sValue);
                   if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                      iIndex := -1;
                except
                      on e : EDead do begin
                         if (e.HelpContext = 10) then
                            iIndex := -1
                         else
                            raise;
                      end;
                end;
            end
            // ADDED(2005-06-07) A column has been set for Exclusive checking.
            // Keyword must come above column labels since the 2da class currently
            // has no rollback functionality. Must be intercepted before anything is added.

            // CHANGED(2006-07-08) Don't. Just skip the key here, and check for it separately
            // above instead to avoid needlessly complicating things.
            else if (sKey = 'ExclusiveColumn') then begin
               continue;
            end
            (*
            else if ((bCloned = False) and (sKey = 'ExclusiveColumn') and (sValue <> '')) then begin
                // A Row with the same value in the specified column as this one already exists,
                // skip copying this row.
                if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                    ModifyRowFallback(sSection, iCurrRow);
                    exit;
                end;
            end
            *)
            else if ((iIndex <> -1) and SetMemoryToken(sKey, sValue, ACTION_COPY_ROW, iIndex)) then begin
                 // do nothing more for this key...
            end
            // It's the new row label for the cloned line
            else if ((lowercase(sKey) = 'newrowlabel') and (sValue <> '')) then begin
                 // ADDED(2005-06-07) - Make high() usable when setting new row label as well...
                 if (lowercase(copy(sValue, 1, 6)) = 'high()') then begin
                     iInc := 0;
                     for iRow := 0 to (l_2da.rowcount - 1) do begin
                         sTemp := l_2da.rlabels[iRow];
                         if (GetIsNumber(sTemp)) then begin
                             iVal := StrToInt(sTemp);
                             if (iVal > iInc) then
                                 iInc := iVal;
                         end;
                     end;
                     sValue := IntToStr(iInc + 1);
                     AddLogLine(Format(LS_LOG_2DANEWROWLABELHIGH, [sValue]), LOG_LEVEL_VERBOSE);
                 end;
                 sValue := GetMemoryToken(sValue);
                 sNewLabel := sValue;
            end
            // It's one of the normal column names
            else if ((iIndex <> -1) and (sKey <> '')) then begin
                 if (sValue = '') then
                    sValue := '****';

                 if (GetIsStringToken(sValue)) then
                     sValue := IntToStr(ProcessStrRefToken(sValue));

                 // Copy the row if it hasn't already been done
                 if (bCloned = False) then begin
                    iOld := iIndex;
                    iIndex := l_2da.CloneLine(iIndex, sNewLabel);
                    bCloned := True;

                    // If the copy failed for some reason, don't continue
                    if (iIndex = -1) then begin
                       AddLogLine(LS_LOG_2DACOPYFAILED, LOG_LEVEL_ERROR);
                       exit;
                    end;
                    AddLogLine(Format(LS_LOG_2DACOPYINGLINE, [IntToStr(iOld), IntToStr(iIndex), l_currentfile]), LOG_LEVEL_VERBOSE);
                 end;

                 try
                     iColumn := l_2da.GetColByLabel(sKey);
                     if (iColumn <> -1) and (iColumn < l_2da.colcount) then  begin

                         // Special modifier! Increment existing Number instead of replacing it!
                         if ((lowercase(copy(sValue, 1, 4)) = 'inc(') and (copy(sValue, Length(sValue), 1) = ')')) then begin
                             // Get the number between the paranthesises.
                             sTemp := copy(sValue, 5, Pos(')', sValue) - 5);
                             // AddLogLine('Special modifier ' + sValue + ' found when modifying column ' + sKey + '.', LOG_LEVEL_VERBOSE);

                             if (GetIsNumber(l_2da.entry[iIndex, iColumn]) and GetIsNumber(sTemp)) then begin
                                 iVal  := StrToInt(l_2da.entry[iIndex, iColumn]);
                                 iInc  := StrToInt(sTemp);
                                 sValue := IntToStr(iVal + iInc);
                                 AddLogLine(Format(LS_LOG_2DAINCTOPENCOPY, [sKey, IntToStr(iInc), sValue]), LOG_LEVEL_VERBOSE);
                             end
                             else if (GetIsNumber(l_2da.entry[iIndex, iColumn]) and (GetIsNumber(sTemp) = False)) then begin
                                 sValue := l_2da.entry[iIndex, iColumn];
                                 AddLogLine(Format(LS_LOG_2DAINCFAILED, [sTemp]), LOG_LEVEL_ALERT);
                             end
                             else if ((GetIsNumber(l_2da.entry[iIndex, iColumn]) = False) and GetIsNumber(sTemp)) then begin
                                 sValue := l_2da.entry[iIndex, iColumn];
                                 AddLogLine(LS_LOG_2DAINCFAILEDNONUM, LOG_LEVEL_ALERT);
                             end;
                         end
                         // Another special modifier! Make the substituted value be the highest in the column.
                         else if (lowercase(copy(sValue, 1, 6)) = 'high()') then begin

                             //AddLogLine('Special modifier ' + sValue + ' found when modifying column ' + sKey + '.', LOG_LEVEL_VERBOSE);
                             iInc := 0;
                             for iRow := 0 to (l_2da.rowcount - 1) do begin
                                 sTemp := l_2da.entry[iRow, iColumn];
                                 if (GetIsNumber(sTemp)) then begin
                                     iVal := StrToInt(sTemp);
                                     if (iVal > iInc) then
                                         iInc := iVal;
                                 end;
                             end;
                             sValue := IntToStr(iInc + 1);
                             AddLogLine(Format(LS_LOG_2DACOPYHIGH, [sKey, sValue]), LOG_LEVEL_VERBOSE);
                         end;

                         sValue := GetMemoryToken(sValue);

                         // Set the modified value in this table cell.
                         l_2da.entry[iIndex, iColumn] := sValue;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine(Format(LS_LOG_2DAINVALIDCOLLABEL, [sKey]), LOG_LEVEL_ALERT)
                          else if (e.HelpContext <> 8) then
                             raise;
                       end;
                 end;
            end;
        end;
    finally
        oColList.free();
    end;
end;


// -----------------------------------------------------------------------------
// Specialized binary file patching, replace a 32 bit integer value at an offset
// with a custom 32 bit integer value in listed files.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.UpdateHackFiles();
var
   oHackList : TStringList;
   sFilename : string;
   i         : integer;
begin
     if not l_ini.SectionExists('HACKList') then
        exit;

     oHackList := TStringList.Create();
     try
        l_ini.ReadSection('HACKList', oHackList);
        if (oHackList.count > 0) then begin
            AddLogLine(LS_LOG_HAKSTART, LOG_LEVEL_INFORMATION);

            for i := 0 to (oHackList.count - 1) do begin
                sFilename := l_ini.ReadString('HACKList', oHackList.Strings[i], '');
                if (sFilename <> '') and (length(sFilename) > 4) then begin
                    AddLogLine(Format(LS_LOG_HAKMODIFYFILE, [sFilename]), LOG_LEVEL_VERBOSE);
                    DoFileHack(sFilename);
                end;
            end;
        end;
     finally
         oHackList.free();
     end;
end;


// -----------------------------------------------------------------------------
// Process binary patch operations for a particular file.
// Key = offset, Val = new value.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.DoFileHack(sFile : string);
var
   oOffsetList : TStringList;
   theFile     : TFileStream;
   sExt        : string;
   iOffset     : LongInt;
   iValue      : LongInt;
   sOff        : string;
   sVal        : string;
   bReplace    : boolean;
   i           : integer;
begin
    bReplace := False;
    oOffsetList := TStringList.Create();
    l_ini.ReadSection(sFile, oOffsetList);

    if (oOffsetList.count <= 0) then begin
       AddLogLine(Format(LS_LOG_HAKNOOFFSETS, [sFile]), LOG_LEVEL_ALERT);
       exit;
    end;

    // ADDED(2005-06-09) If the first key in the modifier list is "ReplaceFile", then
    // make the Installer overwrite any existing files with the same name.
    if (oOffsetList.count > 1) then begin
        sOff := lowercase(oOffsetList[0]);
        if (sOff = 'replacefile') then
            bReplace := l_ini.readbool(sFile, sOff, False);
    end;

    // Ask for the file...
    if (l_dlgopen.Execute(sFile, fileHack, bReplace)) then begin
        if not FileExists(l_dlgopen.FilePath) then begin
           AddLogLine(Format(LS_LOG_HAKNOVALIDFILE, [sFile]), LOG_LEVEL_ERROR);
           exit;
        end;

        if l_dlgopen.DoBackup() then
           AddLogLine(Format(LS_LOG_HAKBACKUPFILE, [l_dlgopen.FileName, IncludeTrailingPathDelimiter(l_path + 'backup')]), LOG_LEVEL_INFORMATION);

        // Open the file in append-write mode...
        MakeFileWritable(l_dlgopen.FilePath);
        theFile := TFileStream.Create(l_dlgopen.FilePath, fmOpenReadWrite or fmShareDenyWrite);
        try
            for i := 0 to (oOffsetList.count - 1) do begin
                sOff := oOffsetList.strings[i];
                sVal := l_ini.readstring(sFile, sOff, '');

                // FIX(2005-06-09) Skip the ReplaceFile key since it isn't an offset.
                if (lowercase(sOff) = 'replacefile') then
                    continue;

                // ADDED(2006-07-20) Skip the SourceFile key since it isn't an offset.
                if (lowercase(copy(sOff, 1, 11)) = '!sourcefile') then
                   continue;

                // ADDED(2006-07-20) Skip the SourceFile key since it isn't an offset.
                if (lowercase(copy(sOff, 1, 11)) = '!saveas') then
                   continue;

                // Fetch values from StrRef/Memory tokens if applicable...
                if (GetIsStringToken(sVal)) then
                    sVal := IntToStr(ProcessStrRefToken(sVal));

                sVal := GetMemoryToken(sVal);

                // Check that the value and offsets are both numbers and
                // then apply the changes.
                if (sOff <> '')
                    and (sVal <> '')
                    and GetIsNumber(sOff)
                    and GetIsNumber(sVal)
                then begin
                    iOffset := StrToInt(sOff);
                    iValue  := StrToInt(sVal);

                    if (thefile.size > iOffset) then begin
                        // If it's a script, flip the value around since LongInts
                        // are stored backwards in NCS compared to what the
                        // write() function puts in the file.
                        // FIX(2005-05-28) Check that the typecasting of the mask to get
                        //                 rid of the F**** compiler warning doesn't cause trouble...
                        // FIX(2005-05-31) La tillbaka sExt som lite dumt råkade försvinna
                        //                 när filhanteringen las ut på entreprenad...
                        sExt := lowercase(copy(l_dlgopen.FileName, Length(l_dlgopen.FileName) - 2, 3));
                        if (lowercase(sExt) = 'ncs') then begin
                            iValue := (((iValue and longint($FF000000)) shr 24)
                                    or ((iValue and longint($00FF0000)) shr 8)
                                    or ((iValue and longint($0000FF00)) shl 8)
                                    or ((iValue and longint($000000FF)) shl 24));
                        end;

                        theFile.seek(iOffset, soFromBeginning);
                        theFile.write(iValue, sizeof(iValue));
                        AddLogLine(Format(LS_LOG_HAKMODIFYINGDATA, [sFile, sOff , sVal]), LOG_LEVEL_VERBOSE);
                    end;
                end
                else begin
                    AddLogLine(Format(LS_LOG_HAKINVALIDOFFSET, [sOff, sVal, sFile]), LOG_LEVEL_ALERT);
                end;
            end;
        finally
            theFile.free();
            IncrementProgress(1);
        end;
    end
    else begin
       // AddLogLine('No valid ' + sFile + ' file specified! Skipping file.', LOG_LEVEL_ERROR);
    end;

end;

// -----------------------------------------------------------------------------
// 2005-05-30
// Handler for "Installer" type instructions, this will only move the specified
// files into the specified install folder (usually Override) without doing anything
// further to them.
// Structure:
// [InstallList]
// folder_label1=FolderName
//
// [folder_label1]
// File1=filename.tga
// File2=filename.ncs
// File3=filename.gui
// Replace1=updateicon.tga
// -----------------------------------------------------------------------------
procedure TTSLPatcher.DoInstallFiles();
var
   oFolderList : TStringList;
   oFileList   : TStringList;
   oERF        : TERFHandler;
   sFolderName : string;
   sFile       : string;
   sOrig       : string;
// sRename     : string;
   sPath       : string;
   sFolder     : string;
   sSection    : string;
   sKey        : string;
   sExt        : string;
   i, n        : integer;
   iAddCount   : integer;
   bIsArchive  : boolean;
begin
     // No instruction section found in INI file, just exit...
     if not l_ini.SectionExists('InstallList') then
        exit;

     // If the patcher isn't running in Installer mode, there is no point
     // in doing any of this...
     if (l_ini.ReadBool('Settings', 'InstallerMode', False) = False) then
        exit;

     sPath := l_dlgopen.InstallPath;

     oFolderList := TStringList.Create();
     try
         l_ini.ReadSection('InstallList', oFolderList);
         if (oFolderList.count > 0) then begin
             AddLogLine(LS_LOG_INSSTART, LOG_LEVEL_INFORMATION);

             // Go through all specified folders and copy the files there as instructed....
             for i := 0 to (oFolderList.count - 1) do begin
                 sSection := oFolderList.Strings[i];
                 sFolder  := l_ini.ReadString('InstallList', sSection, '');

                 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                 // ADDED(2006-08-09) Attempt to verify if the install destination
                 // is a valid ERF/RIM file or if it's a folder path.
                 bIsArchive := false;
                 if SysUtils.FileExists(sPath + sFolder) then begin
                     if TERFHandler.IsValidArchive(sPath + sFolder) then begin
                         bIsArchive := true;
                     end
                     else begin
                         AddLogLine(Format(LS_LOG_INSDESTINVALID, [sFolder]), LOG_LEVEL_ERROR);
                         continue;
                     end;
                 end
                 else begin
                     // Check if it's a folder that does not exist (OK) or a destination
                     // archive file that does not exist (not OK).
                     if  not DirectoryExists(sPath + sFolder) then begin
                        sExt := ExtractFileExt(sPath + sFolder);
                        if (Length(sExt) > 1) and (sExt[1] = '.') then begin
                            AddLogLine(Format(LS_LOG_INSDESTNOTEXIST, [sFolder]), LOG_LEVEL_ERROR);
                            continue;
                        end;

                     end;
                 end;
                 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


                 // FIX(2005-06-07) Make the output a bit more understandable for files
                 // placed in the main game folder.
                 if (sFolder = '.\') then
                     sFolderName := 'Game'
                 else
                     sFolderName := sFolder;


                 if (sFolder <> '')
                     // and DirectoryExists(sPath + sFolder) // FIX(2006-01-24) Create folder if missing instead...
                     and (Pos('..\', sFolder) = 0) // Don't allow backing out of the Game folder.
                 then begin
                     // ADDED(2006-01-24) Create folder(s) if they do not already exist...
                     // CHANGED(2006-08-09) Skip this part if the destination is a file...
                     if  (not bIsArchive) and (not DirectoryExists(sPath + sFolder)) then begin
                         AddLogLine(Format(LS_LOG_INSCREATEFOLDER, [sPath + sFolder]), LOG_LEVEL_INFORMATION);
                         ForceDirectories(sPath + sFolder);
                     end;

                     // ADDED(2006-01-24) Failsafe in case something went wrong above...
                     // CHANGED(2006-08-09) Skip this part if the destination is a file...
                     if  (not bIsArchive) and (not DirectoryExists(sPath + sFolder)) then begin
                         AddLogLine(Format(LS_LOG_INSFOLDERCREATEFAIL, [sPath + sFolder]), LOG_LEVEL_ERROR);
                         continue;
                     end;

                     if (l_ini.SectionExists(sSection)) then begin
                         // CHANGED(2006-08-09) Moved this up above try...finally block.
                         oFileList := nil;
                         oERF := nil;
                         try
                             oFileList := TStringList.Create();

                             // ADDED(2006-08-09) Make backup and open destination file if an archive,
                             if bIsArchive then begin
                                 l_dlgopen.Destination := sPath + sFolder;
                                 if l_dlgopen.DoDestBackup() then
                                     AddLogLine(Format(LS_LOG_INSBACKUPFILE, [ExtractFileName(l_dlgopen.Destination), IncludeTrailingPathDelimiter(l_path + 'backup')]), LOG_LEVEL_INFORMATION);

                                 oERF := TERFHandler.Create(sPath + sFolder);
                             end;

                             // Copy all files for this folder to the correct location.
                             l_ini.ReadSection(sSection, oFileList);
                             iAddCount := 0;
                             for n := 0 to (oFileList.count - 1) do begin
                                 sKey  := oFileList.Strings[n];
                                 sFile := l_ini.ReadString(sSection, sKey, '');

                                 // ADDED(2006-09-26) Skip the !OverrideType key since it's not a filename.
                                 if (lowercase(sKey) = '!overridetype') then
                                     continue;

                                 // ADDED(2006-08-09) Allow using source file with different name than the
                                 // one that it will be installed as.
                                 // FIX(2006-08-09) Moved this up here before the exist check. :)
                                 sOrig := sFile;
                                 try
                                     sOrig := GetSourceFileName(sOrig);
                                 except
                                     on err : EAbort do begin
                                         AddLogLine(err.Message, LOG_LEVEL_ERROR);
                                         continue;
                                     end;
                                 end;

                                 // ADDED(2006-08-09) Allow using destination file with different name than the
                                 // one that it will be installed from.
                                 // FIX(2006-08-09) Moves this up here before the exist check. :)
                                 sFile := GetSaveFileName(sFile);

                                 // Copy file from the tslpatchdata folder, if it exists....
                                 // FIX(2006-08-09) Check for the source file, not the modifier file name...
                                 if (sFile <> '') and FileExists(l_datapath + sOrig) then begin
                                     // REMOVED(2006-08-09 Replaced with above function call...
                                     (*
                                     if l_ini.SectionExists(sFile) then begin
                                         sRename := l_ini.ReadString(sFile, '!SourceFile', '');
                                         if (sRename <> '') then begin
                                             if SysUtils.FileExists(l_datapath + sRename) then begin
                                                 sOrig := sRename;
                                             end
                                             else begin
                                                 AddLogLine('Unable to locate file "' + sRename + '" to rename to "' + sFile + '" and install, skipping...', LOG_LEVEL_ERROR);
                                                 continue;
                                             end;
                                         end;
                                     end;
                                     *)

                                     if not bIsArchive then begin
                                         // File already exists, won't overwrite anything just to be safe...
                                         if FileExists(sPath + sFolder + '\' + sFile) then begin
                                             // ADDED(2005-06-09) Allow replacing existing files...
                                             if (lowercase(copy(sKey, 1, 7)) = 'replace') then begin
                                                 // ADDED(2005-06-10) Don't allow the Installer to mess with the game binaries or the dialog.tlk file.
                                                 // CHANGED(2006-08-09) Use standard function instead to get extension. Added dot to below if-checks.
                                                 //sExt := lowercase(copy(sFile, Length(sFile) - 2, 3));
                                                 sExt := lowercase(ExtractFileExt(sFile));

                                                 if (sExt = '.exe') then begin
                                                     AddLogLine(Format(LS_LOG_INSNOEXEPLEASE, [sFile]), LOG_LEVEL_ALERT);
                                                     continue;
                                                 end;

                                                 if (sExt = '.tlk') then begin
                                                     AddLogLine(Format(LS_LOG_INSENOUGHTLK, [sFile]), LOG_LEVEL_ALERT);
                                                     continue;
                                                 end;

                                                 // ADDED(2006-09-08)
                                                 if (sExt = '.key') then begin
                                                     AddLogLine(Format(LS_LOG_INSSKELETONKEY, [sFile]), LOG_LEVEL_ALERT);
                                                     continue;
                                                 end;

                                                 // ADDED(2006-09-08)
                                                 if (sExt = '.bif') then begin
                                                     AddLogLine(Format(LS_LOG_INSBIFTHEUNDERSTUDY, [sFile]), LOG_LEVEL_ALERT);
                                                     continue;
                                                 end;

                                                 if (l_dlgopen.DoBackups = True) then begin
                                                     // FIX(2006-09-03) Create Backup folder if it doesn't already exist...
                                                     ForceDirectories(l_path + 'backup\');
                                                     BackupFile(sPath + sFolder + '\' + sFile, l_path + 'backup\' + sFile);
                                                 end;

                                                 DeleteFile(sPath + sFolder + '\' + sFile);
                                                 BackupFile(l_datapath + sOrig, sPath + sFolder + '\' + sFile);
                                                 IncrementProgress(1);

                                                 // CHANGED(2006-07-20) Show feedback on renaming if this is done.
                                                 if (sFile <> sOrig) then begin
                                                     AddLogLine(Format(LS_LOG_INSREPLACERENAME, [sOrig, sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                 end
                                                 else begin
                                                     AddLogLine(Format(LS_LOG_INSREPLACE, [sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                 end;
                                             end
                                             else begin
                                                 AddLogLine(Format(LS_LOG_INSLASKIP, [sFile, sFolderName]), LOG_LEVEL_ALERT);
                                             end;
                                         end
                                         else begin
                                             // FIX(2006-08-09) Changed sFile to sOrig for source file name!
                                             BackupFile(l_datapath + sOrig, sPath + sFolder + '\' + sFile);
                                             IncrementProgress(1);

                                             // FIX(2006-08-09) Show feedback on copy if this is done.
                                             if (sFile <> sOrig) then begin
                                                 AddLogLine(Format(LS_LOG_INSRENAMECOPY, [sOrig, sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                             end
                                             else begin
                                                 AddLogLine(Format(LS_LOG_INSCOPYFILE, [sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                             end;
                                         end;
                                     end
                                     // ADDED(2006-08-09) Insert the file into an ERF/RIM archive.
                                     else begin
                                         if oERF.GetResourceExists(sFile, true) then begin
                                             if (lowercase(copy(sKey, 1, 7)) = 'replace') then begin
                                                 try
                                                     oERF.AddResource(l_datapath + sOrig, true, sFile);
                                                     inc(iAddCount);
                                                     IncrementProgress(1);

                                                     if (sFile <> sOrig) then begin
                                                         AddLogLine(Format(LS_LOG_INSREPLACERENAMEFILE, [sOrig, sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                     end
                                                     else begin
                                                         AddLogLine(Format(LS_LOG_INSREPLACEFILE, [sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                     end;
                                                 except
                                                     on err : EERFError do begin
                                                         AddLogLine(Format(LS_LOG_INSEXCEPTIONSKIP, [err.Message]), LOG_LEVEL_ERROR);
                                                         continue;
                                                     end;
                                                 end;
                                             end
                                             else begin
                                                 AddLogLine(Format(LS_LOG_INSLASKIPFILE, [sFile, sFolderName]), LOG_LEVEL_ALERT);
                                             end;
                                         end
                                         else begin
                                             try
                                                 oERF.AddResource(l_datapath + sOrig, true, sFile);
                                                 inc(iAddCount);
                                                 IncrementProgress(1);

                                                 if (sFile <> sOrig) then begin
                                                     AddLogLine(Format(LS_LOG_INSRENAMEADDFILE, [sOrig, sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                 end
                                                 else begin
                                                     AddLogLine(Format(LS_LOG_INSADDFILE, [sFile, sFolderName]), LOG_LEVEL_INFORMATION);
                                                 end;
                                             except
                                                 on err : EERFError do begin
                                                     AddLogLine(Format(LS_LOG_INSEXCEPTIONSKIP, [err.Message]), LOG_LEVEL_ERROR);
                                                     continue;
                                                 end;
                                             end;
                                         end;
                                         // CHANGED(2006-09-28) Supply section name to check for !OverrideType key in
                                         HandleERFOverrideType(sFile, l_ini.ReadString(sSection, sKey, ''), true);
                                     end;
                                 end
                                 else begin
                                     AddLogLine(Format(LS_LOG_INSCOPYFAILED, [sFile]), LOG_LEVEL_ALERT);
                                 end;
                             end;

                             // ADDED(2006-08-09) Save ERF file when all new content is added.
                             if bIsArchive and (iAddCount > 0) and (oERF <> nil) then begin
                                 oERF.Save();
                             end;
                         finally
                             if (oFileList <> nil) then
                                 oFileList.free();

                             if (oERF <> nil) then
                                 oERF.Free();
                         end;
                     end
                     else begin
                         AddLogLine(Format(LS_LOG_INSNOMODIFIERS, [sSection, sFolderName]), LOG_LEVEL_ALERT);
                     end;
                 end
                 else begin
                     AddLogLine(Format(LS_LOG_INSINVALIDDESTINATION, [sFolderName]), LOG_LEVEL_ERROR);
                 end;
             end;
         end;
     finally
         oFolderList.free();
     end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-08-09)
// Check if an alternative source name has been set for this file, and if so,
// return it. Otherwise return the value passed to it.
// -----------------------------------------------------------------------------
function TTSLPatcher.GetSourceFileName(sFile : string) : string;
var
   sRename : string;
begin
    // ADDED(2006-07-20) Allow using source file with different name than the
    // one that it will be installed as.
    if (l_ini <> nil) and l_ini.SectionExists(sFile) then begin
        sRename := l_ini.ReadString(sFile, '!SourceFile', '');
        if (sRename <> '') then begin
            if SysUtils.FileExists(l_datapath + sRename) then begin
                sFile := sRename;
            end
            else begin
                raise EAbort.Create(Format(LS_EXC_FHRENAMEFAILED, [sRename, sFile]));
            end;
        end;
    end;
    result := sFile;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-08-09)
// Check if an alternative save name has been set for this file, and if so,
// return it. Otherwise return the value passed to it.
// -----------------------------------------------------------------------------
function TTSLPatcher.GetSaveFileName(sFile : string) : string;
var
   sRename : string;
begin
    // ADDED(2006-07-20) Allow using source file with different name than the
    // one that it will be installed as.
    if (l_ini <> nil) and l_ini.SectionExists(sFile) then begin
        sRename := l_ini.ReadString(sFile, '!SaveAs', '');
        if (sRename <> '') then begin
            sFile := sRename;
        end;
    end;
    result := sFile;
end;


// =============================================================================
// 2005-05-28 - TPatchFileHandler - support class for handling files...
// -----------------------------------------------------------------------------
// Fetching files to be patched is now 'outsourced' to this class. Depending on
// if the patcher runs in Installer mode or not, it will determine if it should
// ask the user for the files, or attempt to find and install them on its own.
// =============================================================================

// -----------------------------------------------------------------------------
// 2005-05-28
// Constructor - create object and set attributes to their default values.
// -----------------------------------------------------------------------------
constructor TPatchFileHandler.Create(oBox : TOpenDialog; sPath : string);
begin
    inherited Create();

    l_dlgbox      := oBox;
    l_installpath := '';
    l_currentpath := '';
    l_currentfile := '';
    l_basepath    := '';
    l_datapath    := sPath;
    l_installmode := False;
    l_backupfile  := True;
end;


// -----------------------------------------------------------------------------
// 2005-05-28
// Ugly workaround since I can't declare the l_parentclass as TTSLPatcher
// directly for some peculiar reason, should work but... :/
// TODO: Should probably use callback here instead of this weird way.
// -----------------------------------------------------------------------------
procedure TPatchFileHandler.AddLogLine(sText : string; iLevel : integer);
begin
    if (l_parentclass <> nil) and (l_parentclass is TTSLPatcher) then
        TTSLPatcher(l_parentclass).AddLogLine(sText, iLevel);
end;


// -----------------------------------------------------------------------------
// 2005-05-28
// Returns the full path and filename of the file that the PatchFileHandler has
// fetched for this operation. Execute() *MUST* have been called before this
// function is called, or an exception will be thrown or the output unreliable.
// -----------------------------------------------------------------------------
function TPatchFileHandler.GetFilePath() : string;
begin
    if (l_currentpath = '') then
        raise EAbort.CreateHelp(LS_EXC_FHNODESTPATHSET, 3);

    if (l_currentfile = '') then
        raise EAbort.CreateHelp(LS_EXC_FHNOSOURCEFILESET, 4);

    if not SysUtils.FileExists(l_currentpath + l_currentfile) then
        raise EAbort.CreateHelp(Format(LS_EXC_FHSOURCEDONTEXIST, [l_currentpath + l_currentfile]), 5);

    result := l_currentpath + l_currentfile;
end;


// -----------------------------------------------------------------------------
// 2005-05-28
// Wrapper for making a backup of the last file fetched by the PatchFileHandler.
// Backups will be placed in the 'backup' folder within the same folder as the
// patcher application.
// -----------------------------------------------------------------------------
function TPatchFileHandler.DoBackup() : boolean;
var
   sFile : string;
begin
    result := False;

    if not l_dobackups then
       exit;

    // FIX(2005-05-31) Uuuh, hade glömt lägga till denna, med resultat att alla
    // filer backades upp. Förhoppningsvis ska det funka nu...
    if not l_backupfile then
       exit;

    if not DirectoryExists(l_basepath + 'backup\') then
        ForceDirectories(l_basepath + 'backup\');

    // ADDED(2006-08-09) Allow using destination file with different name than the
    // one that it will be installed from.
    sFile := TTSLPatcher(l_parentclass).GetSaveFileName(l_currentfile);

    // CHANGED(2006-08-09) Using sFile instead of l_currentfile. Added extra Exists check for source.
    if not FileExists(l_basepath + 'backup\' + sFile) and FileExists(l_currentpath + sFile) then begin
        BackupFile(l_currentpath + sFile, l_basepath + 'backup\' + sFile);
        result := True;
    end;
end;

// -----------------------------------------------------------------------------
// 2006-08-06
// Wrapper for making a backup of the destination file, if one is set.
// -----------------------------------------------------------------------------
function TPatchFileHandler.DoDestBackup() : boolean;
begin
    result := False;

    if not l_dobackups then
       exit;

    if (lowercase(l_destination) = 'override') then
        exit;

    if not SysUtils.FileExists(l_destination) then
        exit;

    if not DirectoryExists(l_basepath + 'backup\') then
        ForceDirectories(l_basepath + 'backup\');

    if not DirectoryExists(l_basepath + 'backup\modules\') then
        ForceDirectories(l_basepath + 'backup\modules\');
    // CHANGED(2006-08-09) Check if source file exists as well...
    if not FileExists(l_basepath + 'backup\' + ExtractFileName(l_destination)) and FileExists(l_destination) then begin
        BackupFile(l_destination, l_basepath + 'backup\' + ExtractFileName(l_destination));
        result := True;
    end;
end;



// -----------------------------------------------------------------------------
// 2005-05-30 - Return the install path (ie game folder), if none currently is
//              set, ask the user for its location.
// -----------------------------------------------------------------------------
function TPatchFileHandler.GetInstallPath() : string;
var
   bLookup  : boolean;
   iVersion : integer;
   bPathtrue : integer;
begin
    if (l_installpath = '') or not DirectoryExists(l_installpath) then begin
        // ADDED(2006-05-28) Added Settings key to read the game install folder from
        // the Registry instead of asking the user for the folder. Off by default.
        bLookup := TTSLPatcher(l_parentclass).l_ini.ReadBool('Settings', 'LookupGameFolder', false);
        if bLookup then begin
            iVersion := TTSLPatcher(l_parentclass).l_ini.ReadInteger('Settings', 'LookupGameNumber', 2);
            if (iVersion = 1) then
                l_installpath := GetRegistryString('\SOFTWARE\BioWare\SW\KOTOR', 'Path')
            else
                l_installpath := GetRegistryString('\SOFTWARE\LucasArts\KotOR2', 'Path');

            // Fallback if the Registry lookup failed for whatever reason.
            if (l_installpath = '') or not DirectoryExists(l_installpath) then
                l_installpath := OpenFolderDialog(LS_DLG_SELECTINSTALLFOLDER, 0);
        end
        else begin
            l_installpath := OpenFolderDialog(LS_DLG_SELECTINSTALLFOLDER, 0);
        end;

        if (l_installpath = '') or not DirectoryExists(l_installpath) then
            raise EAbort.CreateHelp(LS_EXC_FHINVALIDGAMEFOLDER, 10);

        // Backslash after last folder is missing for some reason, so add it...
        // FIX(2006-05-28) There's already a function doing this. Use it instead....
        l_installpath := IncludeTrailingPathDelimiter(l_installpath);
        //if (l_installpath[length(l_installpath)] <> '\') then
        //    l_installpath := l_installpath + '\';

        // Check if dialog.tlk exists within the specified folder....
        if not FileExists(l_installpath + 'dialog.tlk') then bPathtrue := bPathtrue + 0;
        if (DirectoryExists(l_installpath + 'override')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'movies')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'modules')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamwaves')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streammusic')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamsounds')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamvoice')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'lips')) then bPathtrue := bPathtrue + 1;

        if(bPathtrue = 0) then raise EAbort.CreateHelp(LS_EXC_FHTALKYMANNOTFOUND, 11);

        AddLogLine(Format(LS_LOG_FHINSTALLPATHSET, [l_installpath]), LOG_LEVEL_VERBOSE);

        // ADDED(2006-07-21) Added callback to update install path in GUI.
        if Assigned(TTSLPatcher(l_parentclass).PathCallback) then
            TTSLPatcher(l_parentclass).PathCallback(l_installpath);
    end;

    result := l_installpath;
end;

// -----------------------------------------------------------------------------
// 2005-05-28 Determines file that should be patched. If the Patcher is in
//            Installer Mode, ask for the Game Folder, then fetch any existing
//            files in the Override folder, and copy any non-existing files
//            there from the TSLPatchData folder.
//            If not in Installer Mode, use the original behavior and ask the
//            user for each file with an Open dialog box.
//
// CHANGED(2006-08-06) Added sDest parameter and modified how pathType
//                     fileGffErf is handled.
// -----------------------------------------------------------------------------
function TPatchFileHandler.Execute(sFilename : string; patchType : TPatchFile; bOverwrite : boolean = False; sDest : string = '') : boolean;
var
   sExt         : string;
   sDesc        : string;
   sRequired    : string;
   sRequiredMsg : string;
   sTemp        : string;
   sRename      : string;
// sFile        : string;
   sFolder      : string;
   sSaveAs      : string;
   sOrig        : string;
   bLookup      : boolean;
   iVersion     : integer;
   bPathtrue    : integer;
   oERF         : TERFHandler;
begin
    result := False;
    l_backupfile := True;

    // ADDED(2006-08-06) If the sDest parameter isn't set, set its value to 'override'.
    if (sDest = '') then begin
        sDest := 'override';
        l_destination := sDest;
    end;

    // ADDED(2006-08-06) If dest is set to override, adjust the ERF setting accordingly
    // if it is set to ERF storage anyway.
    // REMOVED(2006-09-26) Probably not a good idea since the function calling this
    // method might still assume it should be stored in an archive. Let any error
    // handlers below catch this instead.
    //if (lowercase(sDest) = 'override') and (patchType = fileGffErf) then begin
    //    patchType := fileGff;
    //end;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Configure the Open File dialog box, in case it should be used...
    if (patchType = fileTlk) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := 'tlk';
        l_dlgbox.Filter := Format(LS_DLG_FILETYPETLK, ['(*.tlk)|*.tlk']);
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESC, [sFilename]);
    end
    else if (patchType = file2da) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := '2da';
        l_dlgbox.Filter := Format(LS_DLG_FILETYPE2DA, ['(*.2da)|*.2da']);
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESC, [sFilename]);
    end
    // TODO: Check for fileGffErf here as well?
    else if (patchType = fileGff) then begin
        sExt := lowercase(copy(sFilename, Length(sFilename) - 2, 3));

        if (Length(sExt) < 1) then
           sExt := '*';

        if (sExt = 'uti') then      sDesc := Format(LS_DLG_FILETYPEITM, ['(*.uti)'])
        else if (sExt = 'utc') then sDesc := Format(LS_DLG_FILETYPEUTC, ['(*.utc)'])
        else if (sExt = 'utm') then sDesc := Format(LS_DLG_FILETYPEUTM, ['(*.utm)'])
        else if (sExt = 'utp') then sDesc := Format(LS_DLG_FILETYPEUTP, ['(*.utp)'])
        else if (sExt = 'dlg') then sDesc := Format(LS_DLG_FILETYPEDLG, ['(*.dlg)'])
        else if (sExt = 'gff') then sDesc := Format(LS_DLG_FILETYPEGFF, ['(*.gff)'])
        else                        sDesc := Format(LS_DLG_FILETYPEALL, ['(*.*)']);

        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := sExt;
        l_dlgbox.Filter := sDesc + '|*.' + sExt;
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESC, [sFilename]);
    end
    else if (patchType = fileHack) then begin
        sExt := lowercase(copy(sFilename, Length(sFilename) - 2, 3));
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := sExt;
        l_dlgbox.Filter := Format(LS_DLG_FILEWORD, [uppercase(sExt)]) + ' (*.' + sExt + ')|*.' + sExt;
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESCMOD, [sFilename]);
    end
    else if (patchType = fileCompile) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := 'nss';
        l_dlgbox.Filter := Format(LS_DLG_FILETYPENSS, ['(*.nss)|*.nss']);
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESCMOD, [sFilename]);
    end
    else if (patchType = fileSSF) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := 'ssf';
        l_dlgbox.Filter := Format(LS_DLG_FILETYPESSF, ['(*.ssf)|*.ssf']);
        l_dlgbox.Title := Format(LS_DLG_FILESELECTDESCMOD, [sFilename]);
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // The patcher is running in Installer mode... Automatically find and patch the files in
    // the Override folder. If they don't already exist in Override, copy them there from the
    // TSLPatchData folder if they exist there.
    if l_installmode then begin

        // The Install path (aka game directory) has not already been set. Ask the user
        // to select the folder the game is located in. Check for presence of dialog.tlk
        // to verify that it is the right one.
        if (l_installpath = '') or not DirectoryExists(l_installpath) then begin
            // ADDED(2006-05-28) Added Settings key to read the game install folder from
            // the Registry instead of asking the user for the folder. Off by default.
            bLookup := TTSLPatcher(l_parentclass).l_ini.ReadBool('Settings', 'LookupGameFolder', false);
            if bLookup then begin
                iVersion := TTSLPatcher(l_parentclass).l_ini.ReadInteger('Settings', 'LookupGameNumber', 2);
                if (iVersion = 1) then
                    l_installpath := GetRegistryString('\SOFTWARE\BioWare\SW\KOTOR', 'Path')
                else
                    l_installpath := GetRegistryString('\SOFTWARE\LucasArts\KotOR2', 'Path');

                // Fallback if the Registry lookup failed for whatever reason.
                if (l_installpath = '') or not DirectoryExists(l_installpath) then
                    l_installpath := OpenFolderDialog(LS_DLG_SELECTINSTALLFOLDER, 0);
            end
            else begin
                l_installpath := OpenFolderDialog(LS_DLG_SELECTINSTALLFOLDER, 0);
            end;

            if (l_installpath = '') or not DirectoryExists(l_installpath) then
                raise EAbort.CreateHelp(LS_EXC_FHNODESTSELECTED, 6);

            // Backslash after last folder is missing for some reason, so add it...
            l_installpath := IncludeTrailingPathDelimiter(l_installpath);

            // Check if dialog.tlk exists within the specified folder....
        if not FileExists(l_installpath + 'dialog.tlk') then bPathtrue := bPathtrue + 0;
        if (DirectoryExists(l_installpath + 'override')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'movies')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'modules')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamwaves')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streammusic')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamsounds')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'streamvoice')) then bPathtrue := bPathtrue + 1;
        if (DirectoryExists(l_installpath + 'lips')) then bPathtrue := bPathtrue + 1;

        if(bPathtrue = 0) then raise EAbort.CreateHelp(LS_EXC_FHTALKYMANNOTFOUND, 7);

            AddLogLine('Install path set to ' + l_installpath + '.', LOG_LEVEL_VERBOSE);

            // ADDED(2006-07-21) Added callback to update install path in GUI.
            if Assigned(TTSLPatcher(l_parentclass).PathCallback) then
                TTSLPatcher(l_parentclass).PathCallback(l_installpath);
        end;

        // ADDED(2005-08-23) - Added support for a "Required" key. When set to a
        //                     filename a file with that name must exist in the override
        //                     folder already in order for the installer to proceed.
        // TODO: Use procedural type to set up callback instead of doing it this ugly way!!
        // FIX(2006-12-10) Moved this down here to allow the check to be made even if
        //                 the install path is already set!
        if (l_parentclass <> nil) and (l_parentclass is TTSLPatcher) then begin
            sRequired    := TTSLPatcher(l_parentclass).l_ini.ReadString('Settings', 'Required', '');
            if (sRequired <> '') then begin
                if not SysUtils.FileExists(IncludeTrailingPathDelimiter(l_installpath + 'override') + sRequired) then begin
                    sRequiredMsg := TTSLPatcher(l_parentclass).l_ini.ReadString('Settings', 'RequiredMsg', '');
                    if (sRequiredMsg = '') then begin
                        raise EAbort.CreateHelp(Format(LS_EXC_FHREQFILEMISSING, [sRequired]), 99);
                    end
                    else begin
                        raise EAbort.CreateHelp(sRequiredMsg, 99);
                    end;

                    Result := False;
                    Exit;
                end;
            end;
        end;

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // TLK file does not go in Override, nor should any blueprint for it be located
        // in TSLPatchData folder and copied, so it's a special case...
        // Since it is used to locate the Override folder, don't allow the user to specify
        // another, just abort everything if it is missing.
        if (patchType = fileTlk) then begin
            if FileExists(l_installpath + sFilename) then begin
                l_currentfile := sFileName;
                l_currentpath := l_installpath;
                result := True;
                exit;
            end
            else begin
                raise EAbort.CreateHelp(Format(LS_EXC_FHTLKFILEMISSING, [sFilename]), 8);
            end;
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Override folder doesn't already exist, create it.
        if not DirectoryExists(IncludeTrailingPathDelimiter(l_installpath + 'override')) then begin
           ForceDirectories(IncludeTrailingPathDelimiter(l_installpath + 'override'));
           AddLogLine(Format(LS_LOG_FHMAKEOVERRIDE, [IncludeTrailingPathDelimiter(l_installpath + 'override')]), LOG_LEVEL_INFORMATION);
        end;
                

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // ADDED(2006-02-03)
        // Special case for GFF files that should be added to an ERF/RIM file.
        // Make a COPY of the file in tslpatchdata into a TEMP folder, modify this
        // file and then write it into the ERF. Never look in override for existing
        // files in this case.
        // NOTE: ERF file is expected to be in "tslpatchdata", and will have to be
        //       moved to its proper location manually in the InstallList, to complicate
        //       matters even further. :)   (Yes, this is an ugly hack since the patcher
        //       wasn't designed to be able to do things like this from the start...)
        //
        // CHANGED(2006-08-06) Scratch that, look inside the game folder instead for the
        // ERF/RIM file in question and modify it there directly! Ignore the above...
        if (patchType = fileGffErf) then begin
            l_currentfile := sFilename;
            // ADDED(2006-08-06) Keep track of where the file should end up.
            l_destination := IncludeTrailingPathDelimiter(l_installpath) + sDest;

            // ADDED(2006-08-06) Check if the archive ERF/RIM exists first.
            if not SysUtils.FileExists(l_destination) then begin
                AddLogLine(Format(LS_LOG_FHDESTFILENOTFOUND, [l_destination, l_currentfile]), LOG_LEVEL_ERROR);
                result := False;
                exit;
            end;

            // ADDED(2006-08-06) Try to load the archive ERF/RIM and abort if unable.
            oERF := nil;
            try
                try
                    oERF := TERFHandler.Create(l_destination);
                except
                    on err : Exception do begin
                        AddLogLine(Format(LS_LOG_FHDESTNOTFOUNDEXC, [l_destination, l_currentfile, err.Message]), LOG_LEVEL_ERROR);
                        result := False;
                        exit;
                    end;
                end;

                // ADDED(2006-08-06) Verify that the ERF/RIM file has been properly loaded.
                if (oERF = nil) or not oERF.Loaded then begin
                    AddLogLine(Format(LS_LOG_FHCANNOTLOADDEST, [l_destination, l_currentfile]), LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;

                // Create a temp working folder to modify the files in.
                l_currentpath := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(l_datapath) + 'erfpatch_temp');
                ForceDirectories(l_currentpath);

                // ADDED(2006-08-09) Allow using destination file with different name than the
                // one that it will be installed from.
                sSaveAs := TTSLPatcher(l_parentclass).GetSaveFileName(l_currentfile);

                // CHANGED(2006-08-09) Using sSaveAs instead a filename.
                // If a file with this name already exists in the TEMP folder, delete it.
                if FileExists(l_currentpath + sSaveAs{l_currentfile}) then begin
                    DeleteFile(l_currentpath + sSaveAs{l_currentfile});
                end;

                // ADDED(2006-08-06) Resource with this name already exists in destination file. Extract
                // it to the temp folder to modify it! Muhaha!
                if (not bOverwrite) and oERF.GetResourceExists(sSaveAs{sFilename}) then begin
                    AddLogLine(Format(LS_LOG_FHDESTRESEXISTMOD, [sSaveAs, ExtractFileName(l_destination)]), LOG_LEVEL_INFORMATION);
                    sTemp := sSaveAs; // ExtractFileName(l_currentfile);
                    sTemp := copy(sTemp, 1, Pos(ExtractFileExt(sTemp), sTemp) - 1);
                    oERF.GetResource(sTemp, TERF_Resource.StringToResType(ExtractFileExt(sSaveAs{l_currentfile})), l_currentpath + sSaveAs{l_currentfile});
                end
                // Otherwise, use the file from tslpatchdata as a base. Like before.
                else begin
                    // ADDED(2006-08-09) Allow using source file with different name than the
                    // one that it will be installed as.
                    try
                        sFilename := TTSLPatcher(l_parentclass).GetSourceFileName(l_currentfile);
                    except
                        on err : EAbort do begin
                            AddLogLine(Format(LS_LOG_FHSOURCENOTFOUND, [sFilename, sSaveAs]), LOG_LEVEL_ERROR);
                            result := False;
                            exit;
                        end;
                    end;

                    // ADDED(2006-07-20) Allow using source file with different name than the
                    // one that it will be installed as.
                    // REMOVED(2006-08-09) Replaced with above function call.
                    (*
                    sRename := TTSLPatcher(l_parentclass).l_ini.ReadString(l_currentfile, '!SourceFile', '');
                    if (sRename <> '') then begin
                        if SysUtils.FileExists(l_datapath + sRename) then begin
                            sFilename := sRename;
                        end
                        else begin
                            AddLogLine('Unable to locate file "' + sRename + '" to rename to "' + l_currentfile + '" and install, skipping...', LOG_LEVEL_ERROR);
                            result := False;
                            exit;
                        end;
                    end;
                    *)

                    // Copy the file from TSLPATCHDATA to the TEMP folder where it can be modified.
                    AddLogLine(Format(LS_LOG_FHADDTODEST, [sSaveAs, ExtractFileName(l_destination)]), LOG_LEVEL_INFORMATION);
                    BackupFile(l_datapath + sFilename, l_currentpath + sSaveAs{l_currentfile});
                end;

                // Check that the file was copied successfully to work folder...
                if not SysUtils.FileExists(l_currentpath + sSaveAs) then begin
                    result := false;
                    AddLogLine(Format(LS_LOG_FHTEMPFILEFAILED, [sSaveAs]), LOG_LEVEL_ERROR);
                    exit;
                end;

                // FIX(2006-08-09) Forgot to set sSaveAs as the active file...
                l_currentfile := sSaveAs;
                result := true;
                exit;
            finally
                if (oERF <> nil) then
                    oERF.Free();
            end;
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // ADDED(2006-01-10)
        // CompileList files are a special case since they need to be processed
        // indirectly before they are put in override. The final resulting file
        // is also named differently than the original file. A bit messy and
        // VERY hacky, but as long as it works it shall have to do for now...
        if (patchType = fileCompile) then begin
            l_currentfile := sFilename;
            l_currentpath := l_datapath;

            // ADDED(2006-08-06) Keep track of where the file should end up.
            if (lowercase(sDest) <> 'override') then begin
                l_destination := IncludeTrailingPathDelimiter(l_installpath) + sDest;

                // ADDED(2006-08-06) Check if the archive ERF/RIM exists first.
                if not SysUtils.FileExists(l_destination) then begin
                    AddLogLine(Format(LS_LOG_FHMISSINGARCHIVE, [l_destination, l_currentfile]), LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;

                // ADDED(2006-08-06) Try to load the archive ERF/RIM and abort if unable.
                oERF := nil;
                try
                    try
                        oERF := TERFHandler.Create(l_destination);
                    except
                        on err : Exception do begin
                            AddLogLine(Format(LS_LOG_FHLOADARCHIVEEXC, [l_destination, l_currentfile, err.Message]), LOG_LEVEL_ERROR);
                            result := False;
                            exit;
                        end;
                    end;

                    // ADDED(2006-08-06) Verify that the ERF/RIM file has been properly loaded.
                    if (oERF = nil) or not oERF.Loaded then begin
                        AddLogLine(Format(LS_LOG_FHLOADARCHIVEERR, [l_destination, l_currentfile]), LOG_LEVEL_ERROR);
                        result := False;
                        exit;
                    end;
                finally
                    if (oERF <> nil) then
                        oERF.Free();
                end;
            end;

            // ADDED(2006-07-20) Allow using source file with different name than the
            // one that it will be installed as.
            if TTSLPatcher(l_parentclass).l_ini.SectionExists(sFilename) then begin
                sRename := TTSLPatcher(l_parentclass).l_ini.ReadString(sFilename, '!SourceFile', '');
                if (sRename <> '') then begin
                    if SysUtils.FileExists(l_datapath + sRename) then begin
                        l_currentfile := sRename;
                    end
                    else begin
                        AddLogLine(Format(LS_LOG_FHSOURCENOTFOUND, [sRename, sFilename]), LOG_LEVEL_ERROR);
                        result := False;
                        exit;
                    end;
                end;
            end;

           sTemp := copy(sFilename, 1, Pos(ExtractFileExt(sFilename), sFilename) - 1) + '.ncs';

            if (bOverwrite) then begin
                // FIX(2006-08-09) Only check if destination is override folder.
                if (lowercase(sDest) = 'override') and FileExists(l_installpath + 'override\' + sTemp) then begin
                   // Handle backups manually since this doesn't follow the regular pattern of use... :/
                   if l_dobackups then begin
                       if not DirectoryExists(l_basepath + 'backup\') then
                           ForceDirectories(l_basepath + 'backup\');

                       if not FileExists(l_basepath + 'backup\' + sTemp) then begin
                          BackupFile(l_installpath + 'override\' + sTemp, l_basepath + 'backup\' + sTemp);
                          AddLogLine(Format(LS_LOG_FHBACKUPSCRIPT, [sFilename]), LOG_LEVEL_INFORMATION);
                       end;
                   end;
                end;
            end
            else begin
                // FIX(2006-08-09) Only check if destination is overide folder.
                if (lowercase(sDest) = 'override') and FileExists(l_installpath + 'override\' + sFilename) then begin
                    AddLogLine(Format(LS_LOG_FHSCRIPTEXISTS, [sFilename]), LOG_LEVEL_ALERT);
                    result := false;
                    exit;
                end;
            end;

            result := true;
            exit;
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // ADDED(2005-06-09) Lagt till möjligheten att skriva över befintliga filer
        // med en ny-installerad kopia för att låta patchern uppdatera en befintlig Mod.
        // Tillåt bara detta med filer som finns i patchdata-mappen, låt inte anv. välja.
        if (bOverwrite = True) then begin

            // ADDED(2006-08-09) Allow using source file with different name than the
            // one that it will be installed as.
            try
                sOrig := TTSLPatcher(l_parentclass).GetSourceFileName(sFilename);
            except
                on err : EAbort do begin
                    AddLogLine(err.Message, LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;
            end;

            // ADDED(2006-08-09) Allow using destination file with different name than the
            // one that it will be installed from.
            sSaveAs := TTSLPatcher(l_parentclass).GetSaveFileName(sFilename);

            if FileExists(l_datapath + sOrig) then begin
                l_currentfile := sFilename;
                l_currentpath := l_installpath + 'override\';

                // Gör backup om filen redan existerar i Override...
                // FIX(2005-06-12) Lagt till separata log-meddelanden beroende på om filen
                // redan fanns eller om den bara skall kopieras.
                if FileExists(l_currentpath + sSaveAs) then begin
                    l_backupfile := True;
                    DoBackup();
                    DeleteFile(l_currentpath + sSaveAs);
                    AddLogLine(Format(LS_LOG_FHUPDATEREPLACE, [sSaveAs]), LOG_LEVEL_INFORMATION);
                end
                else begin
                    AddLogLine(Format(LS_LOG_FHUPDATECOPY, [sSaveAs]), LOG_LEVEL_INFORMATION);
                end;

                // ADDED(2006-07-20) Allow using source file with different name than the
                // one that it will be installed as.
                // REMOVED(2006-08-09) Done with separate function above instead now.
                (*
                sRename := TTSLPatcher(l_parentclass).l_ini.ReadString(l_currentfile, '!SourceFile', '');
                if (sRename <> '') then begin
                    if SysUtils.FileExists(l_datapath + sRename) then begin
                        sFilename := sRename;
                    end
                    else begin
                        AddLogLine('Unable to locate file "' + sRename + '" to rename to "' + l_currentfile + '" and install, skipping...', LOG_LEVEL_ERROR);
                        result := False;
                        exit;
                    end;
                end;
                *)

                BackupFile(l_datapath + sOrig, l_currentpath + sSaveAs);
                l_currentfile := sSaveAs;  // CHANGED(2006-08-09) use modified file name instead here.

                l_backupfile := False;
                result := True;
            end
            else begin
                AddLogLine(Format(LS_LOG_FHINSFILENOTFOUND, [sFilename]), LOG_LEVEL_ERROR);
                result := False;
            end;

            exit;
        end;

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HACK files should NEVER work on files that already exist in Override with
        // the same name. If files with the same name already exists, abort patching this
        // file rather than mess up existing files. If the file does not exist in
        // the TSLPATCHDATA folder, don't allow the user to pick once since its so
        // sensitive to the file structure.
        //
        // FIX(2005-05-31) Hade glömt "override" biten på l_currentpath tilldelningen.
        // ADDED(2005-06-09) Patch files can now overwrite existing files if specifically
        // set to do so, though that is handled by the above condition and not here.
        if (patchType = fileHack) then begin
            l_currentfile := sFileName;
            l_currentpath := IncludeTrailingPathDelimiter(l_installpath + 'override');

            // ADDED(2006-08-09) Allow using source file with different name than the
            // one that it will be installed as.
            try
                sOrig := TTSLPatcher(l_parentclass).GetSourceFileName(l_currentfile);
            except
                on err : EAbort do begin
                    AddLogLine(err.Message, LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;
            end;

            // ADDED(2006-08-09) Allow using destination file with different name than the
            // one that it will be installed from.
            sSaveAs := TTSLPatcher(l_parentclass).GetSaveFileName(l_currentfile);

            if not FileExists(l_currentpath + sSaveAs) then begin
                // ADDED(2006-07-20) Allow using source file with different name than the
                // one that it will be installed as.
                // REMOVED(2006-08-09) Done above in separate function instead...
                (*
                sRename := TTSLPatcher(l_parentclass).l_ini.ReadString(l_currentfile, '!SourceFile', '');
                if (sRename <> '') then begin
                    if SysUtils.FileExists(l_datapath + sRename) then begin
                        sFilename := sRename;
                    end
                    else begin
                        AddLogLine('Unable to locate file "' + sRename + '" to rename to "' + l_currentfile + '" and install, skipping...', LOG_LEVEL_ERROR);
                        result := False;
                        exit;
                    end;
                end;
                *)

                if FileExists(l_datapath + sOrig) then begin
                    // Blueprint file found, copy it to the Override folder.
                    BackupFile(l_datapath + sOrig, l_currentpath + sSaveAs);
                    l_backupfile := False;
                    l_currentfile := sSaveAs; // CHANGED(2006-08-09) Use target file name instead now.
                    AddLogLine(Format(LS_LOG_FHCOPY2OVERRIDE, [sSaveAs]), LOG_LEVEL_INFORMATION);
                    result := True;
                end
                else begin
                    AddLogLine(Format(LS_LOG_FHSAVEASSRCNOTFOUND, [sFilename, l_currentfile]), LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;
            end
            else begin
                AddLogLine(Format(LS_LOG_FHFILEEXISTSKIP, [sSaveAs]), LOG_LEVEL_ALERT);
                result := False;
                exit;
            end;

            exit;
        end;



        // ADDED(2006-08-09) Allow using source file with different name than the
        // one that it will be installed as.
        try
            sOrig := TTSLPatcher(l_parentclass).GetSourceFileName(sFilename);
        except
            on err : EAbort do begin
                AddLogLine(err.Message, LOG_LEVEL_ERROR);
                result := False;
                exit;
            end;
        end;

        // ADDED(2006-08-09) Allow using destination file with different name than the
        // one that it will be installed from.
        sSaveAs := TTSLPatcher(l_parentclass).GetSaveFileName(sFilename);

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // File does not already exist in the override folder, copy it there from
        // the one in the tslpatchdata folder and then return the new copy...
        if not FileExists(IncludeTrailingPathDelimiter(l_installpath + 'override') + sSaveAs) then begin
            l_currentfile := sSaveAs;
            l_currentpath := IncludeTrailingPathDelimiter(l_installpath + 'override');

            // ADDED(2006-07-20) Allow using source file with different name than the
            // one that it will be installed as.
            // REMOVED(2006-08-09) Handled above in separate function instead now.
            (*
            sRename := TTSLPatcher(l_parentclass).l_ini.ReadString(l_currentfile, '!SourceFile', '');
            if (sRename <> '') then begin
                if SysUtils.FileExists(l_datapath + sRename) then begin
                    sFilename := sRename;
                end;
            end;
            *)

            // File to patch does not exist in the tslpatchdata folder! Fall back to ask
            // the user for one...
            if not FileExists(l_datapath + sOrig) then begin
                AddLogLine(LS_LOG_FHNOTSLPATCHDATAFILE, LOG_LEVEL_VERBOSE);
                sTemp := l_dlgbox.Title;
                l_dlgbox.Title := Format(LS_DLG_MANUALLOCATEFILE, [sSaveAs, sOrig]);
                if (l_dlgbox.Execute()) then begin
                    l_dlgbox.Title := sTemp;
                    sOrig := ExtractFileName(l_dlgbox.FileName);
                    sFolder := IncludeTrailingPathDelimiter(ExtractFilePath(l_dlgbox.FileName));

                    // FIX(2005-06-09) Kopiera den valda filen till Override istället och
                    // sätt den kopian till att patchas istället för originalet.
                    BackupFile(sFolder + sOrig, l_currentpath + sSaveAs);
                    l_currentfile := sSaveAs;  // CHANGED(2006-08-09) Use target file name instead now.
                    result := True;
                    AddLogLine(Format(LS_LOG_FHCOPYFILEAS, [sOrig, sSaveAs]), LOG_LEVEL_INFORMATION);

                    exit;
                end
                else begin
                    l_dlgbox.Title := sTemp;
                    raise EAbort.CreateHelp(Format(LS_EXC_FHCRITFILEMISSING, [sSaveAs]), 9);
                end;
            end
            else begin
                // Blueprint file found, copy it to the Override folder.
                BackupFile(l_datapath + sOrig, l_currentpath + sSaveAs);
                l_backupfile := False;
                l_currentfile := sSaveAs;

                // CHANGED(2006-07-21) Different messages if renaming or just copying.
                if (sOrig <> sSaveAs) then
                    AddLogLine(Format(LS_LOG_FHCOPYFILEAS, [sOrig, sSaveAs]), LOG_LEVEL_INFORMATION)
                else
                    AddLogLine(Format(LS_LOG_FHCOPY2OVERRIDE, [sSaveAs]), LOG_LEVEL_INFORMATION);

                result := True;
                exit;
            end;
        end
        else begin
            AddLogLine(Format(LS_LOG_FHMODIFYINGFILE, [sSaveAs]), LOG_LEVEL_INFORMATION);
            l_currentfile := sSaveAs;
            l_currentpath := IncludeTrailingPathDelimiter(l_installpath + 'override');
            result := True;
            exit;
        end;

        AddLogLine('DEBUG: FALLTHROUGH IN FILE SELECTION ROUTINE! PLEASE REPORT THIS...', LOG_LEVEL_ERROR);
    end
    // Running in Patcher mode, ask for each file individually and patch them directly.
    else begin
        if (l_dlgbox.Execute()) then begin
            l_currentfile := ExtractFileName(l_dlgbox.FileName);
            l_currentpath := ExtractFilePath(l_dlgbox.FileName);
            result := True;
        end;
    end;
end;

end.
 
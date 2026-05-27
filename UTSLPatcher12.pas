unit UTSLPatcher;
// =============================================================================
// TSLPatcher - main logic class for Patcher application...
// =============================================================================
// Language:      Delphi4
// Main class:    TTSLPatcher
// Structure:     Nonexistant :/
// Last modified: 2006-01-27 (MKB)
// Version:       1.1.8 WIP-6
// -----------------------------------------------------------------------------
//
// ChangeLog for Version 1.1.8 (WIP):
// ----------------------------------
// 2006-01-09 - * Updated Patcher to use the new GFF Class for all GFF operations.
// 2006-01-10 - * Added functionality for the Patcher to add new fields to GFF files.
//                See comment header for AddGffField() for the specifics.
// 2006-01-14 - * Added "ScriptCompilerFlags" key to "Settings" section of INI that allows
//                setting of extra commandline parameters to nwnnsscomp.exe.
// 2006-01-18 - * If the TypeID of a STRUCT added to a LIST is set to "ListIndex", that
//                will be substituted for the index in the LIST the STRUCT is about to be added as.
// 2006-01-24 - * Changed InstallList behavior to create the specified folder path if it
//                does not already exist, instead of skipping that folder.
// 2006-01-26 - * Added an optional "!ReplaceFile" key for GFF Modifier lists which will
//                make the file be overwritten rather than modified in place if it already
//                exists in the override folder.
// 2006-01-27 - * Made Patcher display the output from nwnnsscomp.exe in the progress log
//                if the LogLevel is set to 4 (Verbose).
//
//
//
// ChangeLog for Version 1.1.7 (REL):
// -----------------------------------
// 2005-08-23 - * Added support for high() token when assigning a RowLabel to
//                a new line, not just a copied line like before.
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
//              * Added LABEL as possible index for Change2daLine().
//              * Added Log summary of encountered Warnings and Errors.
//              * Added date to start of log, and Install/Patch aware message.
//              * Progress log now saved to installlog.rtf when completed.
//              * ".\" folder now reported as "Game" folder in log for InstallList.
//
// 2005-06-09 - * Added support for overwriting HACK and INSTALL files.
//              * Added "ReplaceFile" key to HACK file modifier list.
//              * Added "Replace#" key to InstallList file list.
//              * Fixed user-selected files in InstallMode, now copied to Override
//                before being modified.
//
// 2005-06-10 - * Changed behavior for ExclusiveColumn flagged Add/Copy row modifiers.
//                If row already exists, it now transforms the modifier into
//                a ChangeRow modifier instead, updating the found matching line.
//              * Put in a simple filter to not allow the File Installer to overwrite the
//                game EXE files or the dialog.tlk file directly.
//

interface

uses stdctrls, U2DAEdit, UTLKFile, UGFFFile, inifiles, Classes, dialogs, Forms,
     FileCtrl, Windows, SysUtils, comctrls, Graphics, UST_Common, UStrTok;

type
TPatchFile  = (fileTlk, file2da, fileGff, fileHack, fileCompile);  // Används av TPatchFileHandler
TStrRefList = array of array of integer;
TMemory     = array of string;

// Lindrigt använd exception-klass då de flesta fel behandlas internt av
// respektive funktion och felmeddelanden skickas till loggen.
EAbort = class(Exception);

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

        l_dlgbox      : TOpenDialog;   // Öppna-dialogbox patchern frågar efter filer med.
        l_parentclass : TObject;       // Referens till TTSLPatcher objektet, anv. för att logga meddelanden.

        // Fult hack, men wtf, det funkar :)
        procedure AddLogLine(sText : string; iLevel : integer);
        function GetFilePath() : string;
        function GetInstallPath() : string;
    public
        constructor Create(oBox : TOpenDialog);

        function DoBackup() : boolean;
        function Execute(sFilename : string; patchType : TPatchFile; bOverwrite : boolean = False) : boolean;

        property FileName    : string     read l_currentfile;
        property FilePath    : string     read GetFilePath;
        property InstallPath : string     read GetInstallPath;
        property InstallMode : boolean    read l_installmode  write l_installmode;
        property DoBackups   : boolean    read l_dobackups    write l_dobackups;
        property BasePath    : string     read l_basepath     write l_basepath;
        property ParentClass : TObject    read l_parentclass  write l_parentclass;
end;

// Huvudklass.
TTSLPatcher = class(TObject)
    private
           l_ini  : TIniFile;                // INI-hanterare för changes.ini.
           l_2da  : T2DAHandler;             // Hanterare för ändring av 2DA filer.
           l_gff  : TGFFFile;                // Hanterare för ändring av GFF filer.
                                             // FIX(2006-01-09) Ändrat till nya GFF-klassen.

           l_path     : string;              // Path till mappen programmet finns i.
           l_inifile  : string;              // Namn på ini-filen som skall laddas...
           l_tlkmap   : TStrRefList;         // StrRef Token <--> Append StrRef tabell.
           l_tlkfile  : string;              // Namn & path till append.tlk filen. Lite onödigt.
           l_tlkfilef : string;              // Namn & path till appendf.tlk filen. Lite onödigt.
           l_datapath : string;              // Path till "tslpatchdata" mappen.
           l_memory   : TMemory;             // 2DAMEMORY tabell, innehåller temp-lagrad data.

           l_loglines  : integer;            // Antal rader som skrivits till loggen.
           l_logold    : boolean;            // ADDED(2005-07-31) Använd gammalt fallback-logformat...
           l_loglevel  : integer;            // Läst från ini, hur mkt log-info som ska visas.
           l_logalerts : integer;            // Antal varningar som loggats. (2005-06-07)
           l_logerrors : integer;            // Antal fel som loggats.       (2005-06-07)

           l_dlgopen     : TPatchFileHandler;  // Hämtar fram vilken fil som skall patchas.
           l_currentfile : string;             // Namn på fil som patchern jobbar med f.n.

           procedure ProcessTLKData();
           procedure AppendTLKData(iType : integer);
           procedure UpdateGffFiles();
           procedure DoInstallFiles();
           
           function SetMemoryToken(sKey, sValue : string; iType, iVal : integer) : boolean;
           function GetMemoryToken(sValue : string) : string;
           function ProcessStrRefToken(sToken : string) : integer;
           function CheckForNonExclusiveLabel(sSection, sExclusive : string; var iOldRow : integer) : boolean;
           function CheckLabelIdentifier(var iIndex : integer; sSection, sKey, sValue : string) : boolean;

           procedure Add2daLine(sSection : string);
           procedure Add2daColumn(sSection : string);
           procedure Change2daLine(sSection : string);
           procedure Copy2daLine(sSection : string);
           procedure ModifyRowFallback(sSection : string; iIndex : integer);

           // ADDED(2006-01-10) Added GFF Field Add functionality... Called from UpdateGffFiles().
           function AddGffField(sSection : string; sOverridePath : string) : boolean;

           // Odokumenterad funktionalitet eftersom den har hög FUBAR-faktor...
           procedure UpdateHackFiles();
           procedure DoFileHack(sFile : string);

           // ADDED(2006-01-10) Added CompileList functionality...
           procedure DoCompileFiles();
           function ReplaceTokensInFile(sFile : string) : string;
    public
           logbuffer    : TRichEdit;
           logbuffertxt : TMemo;      // ADDED(2005-07-31) Fallback text log...

           procedure AddLogLine(sText : string; iLevel : integer);
           procedure RunPatchOperation();

           constructor Create(sFilename : string; oOpenBox : TOpenDialog);
           destructor Destroy(); override;
end;


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
constructor TTSLPatcher.Create(sFilename : string; oOpenBox : TOpenDialog);
begin
     inherited Create();

     l_inifile  := sFileName;
     l_path     := ExtractFilePath(Application.ExeName);
     l_datapath := l_path + 'tslpatchdata\';   // Perhaps this shouldn't be hardcoded...
     l_2da      := T2DAHandler.Create();
     l_gff      := TGFFFile.Create();     // FIX(2006-01-09) Ändrat till nya GFF-klassen.
     l_ini      := TIniFile.Create(l_datapath + l_inifile);
     l_tlkfile  := l_datapath + 'append.tlk';
     l_tlkfilef := l_datapath + 'appendf.tlk';

     l_dlgopen             := TPatchFileHandler.Create(oOpenBox);
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
function TTSLPatcher.SetMemoryToken(sKey, sValue : string; iType, iVal : integer) : boolean;
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
              AddLogLine('Invalid 2DAMEMORY token found! Token indexes start at 1 and go up...', LOG_LEVEL_ERROR);
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
          // Should perhaps just skip processing the modifier alltogether, this might cause trouble...
          iMem := 1;
          if (length(l_memory) < iMem) then
             SetLength(l_memory, iMem);
          iMem := 0;
          AddLogLine('Invalid memory token ' + sKey + ' encountered, using first memory slot instead.', LOG_LEVEL_ALERT);
       end;


       // Get the value from the column labeled by VALUE.
       if (  (iType = ACTION_ADD_ROW)
          or (iType = ACTION_MODIFY_ROW)
          or (iType = ACTION_COPY_ROW))
       then begin
            // It's the row index, handle it separately
            if (sValue = 'RowIndex') then begin
               l_memory[iMem] := IntToStr(iVal);
               AddLogLine('Found a ' + sKey + ' token! Storing value "' + l_memory[iMem] + '" from 2da to memory...', LOG_LEVEL_VERBOSE);
            end
            // It's the row label, handle it separately....
            else if (sValue = 'RowLabel') then begin
               if (iVal <> -1) and (iVal < l_2da.rowcount) then begin
                   l_memory[iMem] := l_2da.rlabels[iVal];
                   AddLogLine('Found a ' + sKey + ' token! Storing value "' + l_memory[iMem] + '" from 2da to memory...', LOG_LEVEL_VERBOSE);
               end
               else
                   AddLogLine('Error looking up row label for row index ' + IntToStr(iVal), LOG_LEVEL_ALERT);

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
                       AddLogLine('Found a ' + sKey + ' token! Storing value "' + l_memory[iMem] + '" from 2da to memory...', LOG_LEVEL_VERBOSE);
                    end
                    else
                        AddLogLine('Invalid column label "' + sValue + '" passed to ' + sKey + ' key!', LOG_LEVEL_ALERT);
                except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine('Invalid column label "' + sValue + '" passed to ' + sKey + ' key!', LOG_LEVEL_ALERT)
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
                   AddLogLine('Found a ' + sKey + ' token! Storing value "' + l_memory[iMem] + '" from 2da to memory...', LOG_LEVEL_VERBOSE);
               end
               else
                   AddLogLine('Error looking up column label for column index ' + IntToStr(iVal), LOG_LEVEL_ALERT);

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
                       AddLogLine('Found a ' + sKey + ' token! Storing value "' + l_memory[iMem] + '" from 2da to memory...', LOG_LEVEL_VERBOSE);
                    end
                    else
                        AddLogLine('Invalid column label passed to ' + sKey + ' key!', LOG_LEVEL_ALERT);
                except
                     // Missing row values are not fatal, just skip it.
                     on e : EDead do begin
                        if (e.HelpContext = 10) then
                           AddLogLine('Invalid row label "' + sValue + '" passed to ' + sKey + ' key!', LOG_LEVEL_ALERT)
                        else if (e.HelpContext <> 10) then
                           raise;
                     end;
                end;
            end;
       end
       else if (iType = ACTION_ADD_FIELD) then begin
            if (sValue = 'ListIndex') then begin
               l_memory[iMem] := IntToStr(iVal);
               AddLogLine('Found a ' + sKey + ' token! Storing ListIndex "' + l_memory[iMem] + '" from GFF to memory...', LOG_LEVEL_VERBOSE);
            end;
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
               AddLogLine('Invalid memory token ' + sValue + ' encountered, assuming first memory slot.', LOG_LEVEL_ALERT);
          end
          else if ((length(l_memory) < iMem) and (length(l_memory) <= 0)) then begin
               result := sValue;
               AddLogLine('Invalid memory token ' + sValue + ' encountered, unable to insert a proper value in the 2da!', LOG_LEVEL_ERROR);
               exit;
          end;

          iMem := iMem - 1;
          if (iMem < 0) then
             iMem := 0;
       end
       else begin
           if (length(l_memory) > 0) then begin
               iMem := 0;
               AddLogLine('Invalid memory token ' + sValue + ' encountered, assuming first memory slot.', LOG_LEVEL_ALERT);
           end
           else begin
               result := sValue;
               AddLogLine('Invalid memory token ' + sValue + ' encountered, unable to insert a proper value in the 2da!', LOG_LEVEL_ERROR);
               exit;
           end;
       end;

       AddLogLine('Found a ' + sValue + ' value, substituting with value "' + l_memory[iMem] + '" in memory...', LOG_LEVEL_VERBOSE);
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

        AddLogLine('Loading StrRef token table...', LOG_LEVEL_VERBOSE);

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
           AddLogLine(IntToStr(iCount) + ' StrRef tokens found and indexed.', LOG_LEVEL_VERBOSE);

        // Merge the append.tlk file with the dialog.tlk file....
        AppendTLKData(TLK_TYPE_NORMAL);
        // ...and do the same with appendf.tlk and dialogf.tlk, if present...
        AppendTLKData(TLK_TYPE_FEMALE);

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
       sAppend   := l_tlkfile;
    end
    else if (iType = TLK_TYPE_FEMALE) then begin
        sFileName := 'dialogf.tlk';
        sAppend   := l_tlkfilef;
    end
    else begin
        raise EAbort.Create('Internal error, invalid TLK file type specified. This should never happen.');
    end;

    if ((l_tlkmap <> nil)
        and (length(l_tlkmap) > 0)
        and (length(l_tlkmap[0]) > 0)
        and FileExists(sAppend))
    then begin
        l_currentfile := sFileName;

        if (l_dlgopen.Execute(sFileName, fileTlk)) then begin
            if (FileExists(l_dlgopen.FilePath) and FileExists(sAppend)) then begin
                AddLogLine('Appending strings to TLK file ' + l_dlgopen.FilePath, LOG_LEVEL_INFORMATION);
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

                                         AddLogLine('Identical string for append StrRef ' + IntToStr(oEntry.strref) + ' found in ' + sFileName + ' StrRef ' + IntToStr(oTest.strref) + ', reusing it instead.', LOG_LEVEL_VERBOSE);
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

                                   AddLogLine('Appending new entry to ' + sFileName + ', new StrRef is ' + IntToStr(oInsert.strref), LOG_LEVEL_VERBOSE);

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
                                 AddLogLine('Saving unaltered backup copy of ' + l_dlgopen.FileName + ' file in ' + l_path + 'backup\', LOG_LEVEL_INFORMATION);

                              tlkFile.SaveTlkFile(l_dlgopen.FilePath);

                              if (iAdded > 0) and (iReused > 0) then
                                  AddLogLine(sFileName + ' file updated with ' + IntToStr(iAdded) + ' new entries, ' + IntToStr(iReused) + ' entries already existed.', LOG_LEVEL_INFORMATION)
                              else if (iAdded > 0) then
                                  AddLogLine(sFileName + ' file updated with ' + IntToStr(iAdded) + ' new entries.', LOG_LEVEL_INFORMATION)
                              else if (iReused > 0) then
                                  AddLogLine(sFileName + ' file not updated, all ' + IntToStr(iReused) + ' entries were already present.', LOG_LEVEL_INFORMATION)
                              else
                                  AddLogLine('Warning: No new entries appended to ' + sFileName + '. Possible missing entries in append.tlk referenced in the TLKList.', LOG_LEVEL_ALERT)
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
                 AddLogLine('Unable to load specified ' + sFileName + ' file! Aborting...', LOG_LEVEL_ERROR);
                 raise EAbort.CreateHelp('No TLK file loaded. Unable to proceed.', 2);
            end;
        end // Open tlk execute
        else begin
             l_tlkmap := nil;
             AddLogLine('No ' + sFileName + ' file specified. Unable to proceed!', LOG_LEVEL_ERROR);
             raise EAbort.CreateHelp('No TLK file loaded. Unable to proceed.', 1);
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
    AddLogLine('Warning! Encountered StrRef token "' + sToken + '" in modifier list that was not present in the TLKList! Value set to StrRef #0.', LOG_LEVEL_ALERT);
    result := 0;
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
// add "AddField#" keys to its specifier section. These will work just like such
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
        AddLogLine('Unable to locate section "' + sSection + '" when attempting to add GFF Field, skipping...', LOG_LEVEL_ALERT);
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
         AddLogLine('Parent field at "' + sPath + '" does not exist or is not a LIST or STRUCT! Unable to add new Field "' + sKey + '"...', LOG_LEVEL_ALERT);
         exit;
     end;

     // Check that a field with this name doesn't already exist at the
     // specified location. If it does, skip it.
     // Also check that a Label has been specified for the new field.
     sModPath := sPath;
     if (Length(sModPath) > 0) then
         sModPath := sPath + '\';

     // Skip the check if the parent field is a LIST, since STRUCTs in a list have no label...
     if (oParent.FieldType <> FIELD_TYPE_LIST) then begin
         if (sKey = '') then begin
             AddLogLine('No field label has been specified for new field in section "' + sSection + '"! Unable to create field...', LOG_LEVEL_ALERT);
             exit;
         end;

         oField := l_gff.GetFieldByLabel(sModPath + sKey);
         if (oField <> nil) then begin
             if (Length(sModPath) = 0) then
                 sModPath := 'root';

             AddLogLine('A Field with the label "' + sKey + '" already exists at "' + sModPath + '", skipping it...', LOG_LEVEL_ALERT);
             exit;
         end;
     end;

     // Reset field object reference...
     oField := nil;

     // Check the Value data for 2DAMEMORY and StrRef tokens and substitute
     // the correct value.
     if (GetIsStringToken(sValue)) then
         sValue := IntToStr(ProcessStrRefToken(sValue));

     sValue := GetMemoryToken(sValue);


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
        if (GetIsNumber(sValue)) then
           oField := TGFF_SDWORD.Create(sKey, StrToInt(sValue));
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

        if (not GetIsNumber(sValue)) and (sValue <> '-1') then begin
            AddLogLine('Invalid StrRef value when attempting to add ExoLocString. Defaulting to -1...', LOG_LEVEL_ALERT);
            sValue := '-1';
        end;

        // Check the StrRef data for 2DAMEMORY and StrRef tokens and substitute
        // the correct value.
        if (GetIsStringToken(sValue)) then
            sValue := IntToStr(ProcessStrRefToken(sValue));

        sValue := GetMemoryToken(sValue);

        // Create the ExoLocString field object...
        oField := TGFF_CExoLocString.Create(sKey, StrToInt(sValue));

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
            TGFFStruct(oField).typeid := StrToInt(sValue);
     end
     else if (sType = 'List') then begin
         oField := TGFFList.Create(sKey);
     end;


     // STOP HERE if no valid field object has been created above!
     if (oField = nil) then begin
         AddLogLine('Invalid field type "' + sType + '" or data specified in section "' + sSection + '" when trying to add fields to ' + ExtractFileName(l_gff.filename) + ', skipping...', LOG_LEVEL_ALERT);
         exit;
     end;

     // Add the new field to the GFF Data tree
     if (oParent <> nil) then begin
        l_gff.AddField(oField, sPath);
        result := true;

        sModPath := sPath;
        if (sModPath = '') then
            sModPath := 'root';

        if (oParent.fieldtype = FIELD_TYPE_LIST) then
           AddLogLine('Added ' + sType + ', index ' + IntToStr(TGFFList(oParent).count - 1) + ', at position "' + sModPath + '"', LOG_LEVEL_VERBOSE)
        else
           AddLogLine('Added ' + sType + ' field "' + oField.fieldlabel + '" at position "' + sModPath + '"', LOG_LEVEL_VERBOSE);


        // Process any sub-fields to add to new STRUCT or LIST fields, and fetch the ListIndex
        // of this field if it's a STRUCT added to a LIST and the user want to store it in a 2DAMEMORY token.
        if (oField.fieldtype = FIELD_TYPE_STRUCT) or (oField.fieldtype = FIELD_TYPE_LIST) then begin
            oGffList := TStringList.Create();
            try
                l_ini.ReadSection(sSection, oGffList);
                iIndex := TGFFList(oParent).count - 1;
                for i := 0 to (oGffList.count - 1) do begin
                    sKey := oGffList.Strings[i];
                    sValue := l_ini.ReadString(sSection, oGffList.Strings[i], '');

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
     end;

end;


// -----------------------------------------------------------------------------
// (2005-05-19) Update any GFF files listed with the specified changes.
// CHANGED(2006-01-10) Add new fields as well, if requested.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.UpdateGffFiles();
var
   oGffList    : TStringList;
   oChangeList : TStringList;
   sFilename   : string;
   sKey        : string;
   sVal        : string;
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
            AddLogLine('Modifying GFF format files...', LOG_LEVEL_INFORMATION);

            for i := 0 to (oGffList.count - 1) do begin
                sFilename := l_ini.ReadString('GFFList', oGffList.Strings[i], '');
                l_currentfile := sFilename;
                iChanges := 0;

                // If there's no section of modifiers present we might as well skip this file...
                if (l_ini.SectionExists(sFilename) = False) then begin
                    AddLogLine('No instruction section found for file ' + sFilename + ', skipping...', LOG_LEVEL_ALERT);
                    break;
                end;

                // ADDED(2006-01-26) Allow optional key to instruct patcher to Overwrite
                // an existing GFF file in override.
                bOverwrite := false;
                if (sFileName <> '') then begin
                    bOverwrite := l_ini.ReadBool(sFilename, '!ReplaceFile', false);
                end;

                // CHANGED(2006-01-26) Added bOverwrite param to Execute method call...
                if ((sFileName <> '') and l_dlgopen.Execute(sFilename, fileGff, bOverwrite)) then begin

                    // If the specified file doesn't exist, stop here...
                    if (FileExists(l_dlgopen.FilePath) = False) then
                        break;

                    // Load the GFF File...
                    l_gff.LoadFile(l_dlgopen.FilePath); // FIX(2006-01-09) Nytt metodnamn för nya GFF-klassen.

                    if (l_gff.loaded) then begin  // FIX(2006-01-09) Nytt property-namn för nya GFF-klassen.
                        AddLogLine('Modifying GFF file ' + sFileName + '...', LOG_LEVEL_INFORMATION);

                        oChangeList := TStringList.Create();
                        try
                            l_ini.ReadSection(sFilename, oChangeList);
                            if (oChangeList.count > 0) then begin
                                for n := 0 to (oChangeList.count - 1) do begin
                                    sKey := oChangeList.strings[n];
                                    sVal := l_ini.ReadString(sFilename, sKey, '');

                                    bSkip := False;
                                    if (sKey = '') then begin
                                        bSkip := True;
                                        AddLogLine('Blank Gff Field Label encountered in instructions, skipping...', LOG_LEVEL_ALERT);
                                    end;
                                    // FIX(2005-05-19)
                                    // Pucko... en label är max 16 tkn, men en label PATH kan vara
                                    // betydligt längre än så... bort med det här... :/
                                    (*
                                    if (Length(sKey) > 16) then begin
                                        bSkip := True;
                                        AddLogLine('Invalid field label ' + sKey + ' in instructions, label can be no longer than 16 characters. Skipping...', LOG_LEVEL_ALERT);
                                    end;
                                    *)

                                    // ADDED(2006-01-26) !ReplaceFile is not a field name, but a special instruction
                                    // to make existing GFF files get overwritten. Skip key when found here.
                                    if (lowercase(copy(sKey, 1, 12)) = '!replacefile') then begin
                                        bSkip := true;
                                    end;


                                    // ADDED(2006-01-10)
                                    // If the key begins with AddField, look up the section named sVal and
                                    // add a new field to the GFF file according to those instructions.
                                    if (copy(sKey, 1, 8) = 'AddField') then begin
                                        if (AddGffField(sVal, '') = true) then begin
                                            AddLogLine('Added new field to GFF file ' + ExtractFileName(l_gff.filename) + '...', LOG_LEVEL_INFORMATION);
                                            inc(iChanges);
                                        end;
                                        bSkip := true;
                                    end;


                                    if (sVal = '') then begin
                                        bSkip := True;
                                        AddLogLine('Blank value encountered for GFF field label ' + sKey + ', skipping...', LOG_LEVEL_ALERT);
                                    end;

                                    if (bSkip = False) then begin
                                        if (GetIsStringToken(sVal)) then
                                            sVal := IntToStr(ProcessStrRefToken(sVal));

                                        sVal := GetMemoryToken(sVal);

                                        // FIX(2006-01-09) Ändrat metodanrop för användning av ny GFF-klass.
                                        if (l_gff.ChangeFieldValue(sKey, sVal) = True) then begin
                                            AddLogLine('Modified value "' + sVal + '" to field "' + sKey + '" in ' + l_dlgopen.FileName + '.', LOG_LEVEL_VERBOSE);
                                            inc(iChanges);
                                        end
                                        else begin
                                            AddLogLine('Unable to find a field label matching "' + sKey + '" in ' + l_dlgopen.FileName + ', skipping...', LOG_LEVEL_ALERT);
                                        end;
                                    end;

                                end;

                                if (iChanges > 0) then begin
                                   if l_dlgopen.DoBackup() then
                                       AddLogLine('Saving unaltered backup copy of ' + l_dlgopen.FileName + ' file in ' + l_path + 'backup\', LOG_LEVEL_INFORMATION);

                                   AddLogLine('Modified ' + IntToStr(iChanges) + ' fields in ' + l_dlgopen.FileName, LOG_LEVEL_VERBOSE);

                                   // FIX(2006-01-09) Ändrat metodanrop för användning av ny GFF-klass
                                   l_gff.SaveFile(l_dlgopen.FilePath);
                                   AddLogLine('Finished updating GFF file ' + l_dlgopen.FileName, LOG_LEVEL_INFORMATION);
                                end
                                else begin
                                    AddLogLine('No changes could be applied to GFF file ' + l_dlgopen.FileName + '.', LOG_LEVEL_ALERT);
                                end;
                            end
                            else begin
                                AddLogLine('No GFF modifier instructions found for file ' + sFilename + ', skipping...', LOG_LEVEL_ALERT);
                            end;
                        finally
                            oChangeList.free();
                        end;
                    end
                    else begin
                        AddLogLine('Unable to load file ' + l_dlgopen.FileName + '! Skipping...', LOG_LEVEL_ERROR);
                    end;

                end
                else begin
                    AddLogLine('No valid ' + sFilename + ' file was opened, skipping...', LOG_LEVEL_ALERT);
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
// -----------------------------------------------------------------------------
function TTSLPatcher.ReplaceTokensInFile(sFile : string) : string;
var
   inFile   : Textfile;
   outFile  : Textfile;
   sTemp    : string;
   sTmpFile : string;
   i        : integer;
begin
    sTmpFile := ExtractFilePath(sFile) + 'tmp_' + ExtractFileName(sFile);
    assignfile(inFile, sFile);
    assignfile(outFile, sTmpFile);
    result := sTmpFile;
    reset(inFile);
    rewrite(outFile);
    try
       while not eof(inFile) do
       begin
            // Read a line from the template file...
            readln(inFile, sTemp);

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
// -----------------------------------------------------------------------------
procedure TTSLPatcher.DoCompileFiles();
var
   oFileList  : TStringList;
   oTokens    : TStringTokenizer;
   sFileMod   : string;
   sFileName  : string;
   sFile      : string;
   sTmpFile   : string;
   sFileBase  : string;
   sApp       : string;
   sParam     : string;
   sFlags     : string;
   sNcsFile   : string;
   sFeedback  : string;
   bOverwrite : boolean;
   i          : integer;
   n          : Integer;
begin
     // No GFF modifiers present in the INI file. No point in continuing...
     if not l_ini.SectionExists('CompileList') then
        exit;

     oFileList := TStringList.Create();
     try
        l_ini.ReadSection('CompileList', oFileList);
        if (oFileList.count > 0) then begin
            AddLogLine('Modifying and compiling scripts...', LOG_LEVEL_INFORMATION);

            // Path to NWNNSSCOMP.EXE...
            sApp := l_datapath + 'nwnnsscomp.exe';

            if not FileExists(sApp) then begin
                AddLogLine('Could not locate nwnsscomp.exe in the TSLPatchData folder! Unable to compile scripts!', LOG_LEVEL_ERROR);
                exit;
            end;

            for i := 0 to (oFileList.count - 1) do begin
                sFileMod  := oFileList.Strings[i];
                sFilename := l_ini.ReadString('CompileList', sFileMod, '');

                if (lowercase(copy(sFileMod, 1, 7)) = 'replace') then
                   bOverwrite := true
                else
                   bOverwrite := false;

                // The finesse of l_dlgopen is pretty much lost in this function,
                // but whatever... fix some time when I have the energy...
                if (l_dlgopen.Execute(sFileName, fileCompile, bOverwrite)) then begin
                    sFile := l_dlgopen.FilePath;
                    AddLogLine('Replacing tokens in script ' + ExtractFileName(sTmpFile) + '...', LOG_LEVEL_VERBOSE);
                    sTmpFile := ReplaceTokensInFile(sFile);
                    sFileBase := copy(sFile, 1, Pos(ExtractFileExt(sFile), sFile) - 1);
                    sFileBase := sFileBase + '.ncs';

                    if FileExists(sTmpFile) then begin
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

                        sParam := sFlags + '-c "' + sTmpFile + '" -o "' + sFileBase + '"';

                        AddLogLine('Compiling modified script ' + ExtractFileName(sTmpFile) + '...', LOG_LEVEL_INFORMATION);

                        // - - - - - - - - - - - - - -
                        // CHANGED(2006-01-27) Trying new variant to capture nwnnsscomp.exe
                        // feedback and display in the VERBOSE progress log for debugging...

                        // RunAndWaitShell('"' + sApp + '"', sParam, SW_HIDE);
                        sFeedback := RunShellGetOutput('"' + sApp + '"', sParam);

                        if (Length(sFeedback) > 0) then begin
                            oTokens := TStringTokenizer.Create(sFeedback, #10); // Use LF as token

                            for n := 0 to (oTokens.count - 1) do begin
                                sFeedback := ReplaceInString(oTokens[n], #13, ''); // Remove CR
                                AddLogLine('NWNNSSComp says: ' + sFeedback, LOG_LEVEL_VERBOSE);
                            end;
                        end;
                        // - - - - - - - - - - - - - -

                        sNcsFile := ExtractFileName(sFileBase);

                        if FileExists(l_dlgopen.BasePath + 'tslpatchdata\' + sNcsFile) then begin
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
                        end
                        else begin
                            AddLogLine('Unable to find compiled version of file, ' + l_dlgopen.FileName + '! The compilation probably failed. Skipping...', LOG_LEVEL_ERROR);
                        end;
                    end
                    else begin
                        AddLogLine('Unable to find processed version of file, ' + l_dlgopen.FileName + ', cannot compile it!', LOG_LEVEL_ERROR);
                    end;
                end;
            end;
        end;
     finally
         oFileList.free();
     end;
end;


// -----------------------------------------------------------------------------
// Main function of the class, goes through the INI file and performs operations
// on TLK, GFF and 2DA files as instructed.
// -----------------------------------------------------------------------------
procedure TTSLPatcher.RunPatchOperation();
var
   oFileList   : TStringList;
   oChangeList : TStringList;
   i, n        : integer;
   sFilename   : string;
   sGroupName  : string;
   sCommand    : string;
begin
    if (l_2da = nil) then
        raise EDead.Create('Unable to load the 2da table handler!');

     // ADDED(2005-06-07) - Added Date & time, and message reflecting the Run mode of the Patcher.
     if (l_dlgopen.InstallMode) then
         AddLogLine('Installation started ' + DateTimeToStr(Now) + '...', LOG_LEVEL_NOTICE)
     else
         AddLogLine('Patch operation started ' + DateTimeToStr(Now) + '...', LOG_LEVEL_NOTICE);

     try
         // Check if there are any custom string tokens, and if so update the
         // dialog.tlk file with them.
        ProcessTLKData();

        // Patch 2DA files... this should probably go in its own sub-function
        // as well... sometime... when I feel like cleaning up this mess of code. :)
        oFileList := TStringList.Create();
        try
             l_ini.ReadSection('2DAList', oFileList);

             // Go through all the 2da files that should be changed.
             for i := 0 to (oFileList.count - 1) do begin
                 sFilename := l_ini.ReadString('2DAList', oFileList.Strings[i], '');
                 l_currentfile := sFilename;

                 if ((sFileName <> '') and l_dlgopen.Execute(sFilename, file2da)) then begin
                    if (FileExists(l_dlgopen.FilePath) = False) then
                       break;

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
                                        AddLogLine('Invalid modifier type "' + sCommand + '" found for modifier label "' + sGroupName + '". Skipping...', LOG_LEVEL_ALERT);
                                    end;
                                end;
                            end;

                            if l_dlgopen.DoBackup() then
                               AddLogLine('Saving unaltered backup copy of ' + l_dlgopen.FileName + ' in ' + l_path + 'backup\' + sFilename, LOG_LEVEL_INFORMATION);

                            // Save the changed 2da file.
                            l_2da.Save2daFile(l_dlgopen.FilePath);
                            AddLogLine('Updated 2DA file ' + l_dlgopen.FilePath + '.', LOG_LEVEL_INFORMATION);
                        finally
                            oChangeList.free();
                        end;
                    end // isloaded
                    else begin
                         AddLogLine('Unable to load the 2DA file ' + sFilename + '! Skipping it...', LOG_LEVEL_ALERT);
                    end;
                 end // opendialog
                 else begin
                      AddLogLine('No ' + sFilename + ' file was specified! Skipping it...', LOG_LEVEL_ALERT);
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

             // Copy the files that should just be installed and nothing else done
             // with them, if any.
             DoInstallFiles();

             // If we get here, everything hopefully worked as intended...
             // FIX(2005-06-07) Summarize any Alerts and Errors that were logged to inform
             // users who won't read the whole the log that something may have gone wrong.
             if (l_logalerts > 0) and (l_logerrors = 0) then
                 AddLogLine('Done. Changes have been applied, but ' + IntToStr(l_logalerts) + ' warnings were encountered.', LOG_LEVEL_NOTICE)
             else if (l_logalerts = 0) and (l_logerrors > 0) then
                 AddLogLine('Done. Some changes may have been applied, but ' + IntToStr(l_logerrors) + ' errors were encountered!', LOG_LEVEL_NOTICE)
             else if (l_logalerts > 0) and (l_Logerrors > 0) then
                 AddLogLine('Done. Some changes may have been applied, but ' + IntToStr(l_logerrors) + ' errors and ' + IntToStr(l_logalerts) + ' warnings were encountered!', LOG_LEVEL_NOTICE)
             else
                 AddLogLine('Done. All changes have been applied.', LOG_LEVEL_NOTICE);

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
     end;
end;


// -----------------------------------------------------------------------------
// 2005-06-07
// MASSIVE hack, since I hadn't thought of this functionality to begin with...
// This will have to do until I have the inspiration to rewrite the Copy2daline
// and Add2daLine functions to better handle this.
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
        AddLogLine('Invalid Exclusive column label "' + sExclusive + '" specified, ignoring...', LOG_LEVEL_ALERT);
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
                AddLogLine('Matching value in column ' + sExclusive + ' found for existing row ' + IntToStr(i) + '...', LOG_LEVEL_VERBOSE);
                iOldRow := i;
                result := False;
                exit;
            end;
        end;
    end
    else begin
        AddLogLine('No value has been assigned to column ' + sExclusive + ' for new 2DA line in modifier "' + sSection + '" with Exclusive checking enabled! Skipping line...', LOG_LEVEL_ERROR);
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
        AddLogLine('Error locating row when trying to modify existing Exclusive row in modifier "' + sSection + '".', LOG_LEVEL_ALERT);
        exit;
    end;

    if (iIndex > (l_2da.rowcount - 1)) then begin
        AddLogLine('Too high row-number encountered when trying to modify existing Exclusive row in modifier "' + sSection + '".', LOG_LEVEL_ALERT);
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
                                 AddLogLine('New Exclusive row matched line ' + IntToStr(iIndex) + ' in 2DA file ' + l_currentfile + ', modifying existing line instead.', LOG_LEVEL_VERBOSE);
                                 bDoOnce := True;
                             end;
                         end;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine('Invalid column label "' + sKey + '" encountered! Skipping entry...', LOG_LEVEL_ALERT)
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
        l_ini.ReadSection(sSection, oColList);

        // Go through all listed columns (from the .ini) and set their values.
        for j := 0 to (oColList.count - 1) do begin
            sKey := oColList.strings[j];
            sValue := l_ini.ReadString(sSection, sKey, '');
            
            // ADDED(2005-06-07) A column has been set for Exclusive checking.
            // Keyword must come above column labels since the 2da class currently
            // has no rollback functionality. Must be intercepted before anything is added.
            if ((bAdded = False) and (sKey = 'ExclusiveColumn') and (sValue <> '')) then begin
                // A Row with the same value in the specified column as this one already exists,
                // skip copying this row.
                if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                    ModifyRowFallback(sSection, iCurrRow);
                    exit;
                end;
            end
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
                    AddLogLine('Setting row label to next HIGHEST value ' + sValue + '.', LOG_LEVEL_VERBOSE);
                end;
                // ----------------------------------------------------------

               sValue := GetMemoryToken(sValue);
               if (sValue <> '') then begin
                  if (bAdded = False) then begin
                      iLine := l_2da.addline();
                      AddLogLine('Adding new row (index ' + IntToStr(iLine) + ') to 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);
                      bAdded := True;
                  end;

                  if (iLine <> -1) then begin
                      l_2da.rlabels[iLine] := sValue;
                  end
                  else begin
                      AddLogLine('Unable to set new row label "' + sValue + '" in modifier + "' + sSection + '"!', LOG_LEVEL_ALERT);
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
                     AddLogLine('Adding new row (index ' + IntToStr(iLine) + ') to 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);
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
                             AddLogLine('Setting added row column ' + sKey + ' to next HIGHEST value ' + sValue + '.', LOG_LEVEL_VERBOSE);
                         end;

                         sValue := GetMemoryToken(sValue);
                         if (iLine <> -1) then
                             l_2da.entry[iLine, iColumn] := sValue
                         else begin
                             AddLogLine('An error occured while trying to add new line to 2DA in modifier "' + sSection + '"!', LOG_LEVEL_ERROR);
                             exit;
                         end;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine('Invalid column label "' + sKey + '" encountered! Skipping entry...', LOG_LEVEL_ALERT)
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
            AddLogLine(sKey + ' used as index when changing line in modifier "' + sSection + '" but 2DA file has no label column! Skipping...', LOG_LEVEL_ERROR);
            exit;
        end;

        iCol := l_2da.GetColByLabel('label');
        for i := 0 to (l_2da.rowcount - 1) do begin
            if (l_2da.entry[i, iCol] = sValue) then begin
                if (iIndex <> -1) then begin
                    AddLogLine('Warning, multiple rows matching Label Index found! Last found row will be used...', LOG_LEVEL_ALERT);
                    AddLogLine('Multiple matches for specified Label Index, previously found row ' + IntToStr(iIndex) + ', now found row ' + IntToStr(i) + '.', LOG_LEVEL_VERBOSE);
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
  iIndex   : integer;
  iColumn  : integer;
  sValue   : string;
  sKey     : string;
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
                  AddLogLine('Modifying line (index ' + IntToStr(iIndex) + ') in 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);

            end
            // It's the row label that tells which line to modify. MutEx with the above.
            else if ((lowercase(sKey) = 'rowlabel') and (iIndex = -1) and (sValue <> '')) then begin
                try
                   sValue := GetMemoryToken(sValue);
                   iIndex := l_2da.GetRowByLabel(sValue);

                   if ((iIndex < 0) or (iIndex >= l_2da.rowcount)) then
                      iIndex := -1
                   else
                       AddLogLine('Modifying line (index ' + IntToStr(iIndex) + ') in 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);

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
                  AddLogLine('Modifying line (index ' + IntToStr(iIndex) + ') in 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);
            end
            // ADDED(2005-05-23) - Visa felmeddelande om radidentifierare saknas.
            else if (iIndex = -1) and (lowercase(sKey) <> 'rowlabel') and (lowercase(sKey) <> 'rowindex') then begin
                AddLogLine('No RowIndex/RowLabel identifier for row to modify found at top of modifier list! Unable to apply modifier "' + sSection + '".', LOG_LEVEL_ERROR);
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
                         sValue := GetMemoryToken(sValue);
                         l_2da.entry[iIndex, iColumn] := sValue;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine('Invalid column label "' + sKey + '" encountered! Skipping entry...', LOG_LEVEL_ALERT)
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

        AddLogLine('Adding new column to 2DA file ' + l_currentfile + '...', LOG_LEVEL_VERBOSE);

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
                          AddLogLine('A column with the label "' + sValue + '" already exists in ' + l_currentfile + ', unable to add new column!', LOG_LEVEL_ERROR);
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
                                 AddLogLine('Invalid row label ' + sIndex + ' encountered! Skipping entry...', LOG_LEVEL_ALERT)
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
            else if ((bCloned = False) and (sKey = 'ExclusiveColumn') and (sValue <> '')) then begin
                // A Row with the same value in the specified column as this one already exists,
                // skip copying this row.
                if not CheckForNonExclusiveLabel(sSection, sValue, iCurrRow) then begin
                    ModifyRowFallback(sSection, iCurrRow);
                    exit;
                end;
            end
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
                     AddLogLine('Setting new row label to next HIGHEST value ' + sValue + '.', LOG_LEVEL_VERBOSE);
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
                       AddLogLine('Error! Failed to copy line in 2DA! Skipping...', LOG_LEVEL_ERROR);
                       exit;
                    end;
                    AddLogLine('Copying line ' + IntToStr(iOld) + ' to new line ' + IntToStr(iIndex) + ' in ' + l_currentfile + '.', LOG_LEVEL_VERBOSE);
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
                                 AddLogLine('Incrementing value of copied row for column ' + sKey + ' by ' + IntToStr(iInc) + ', new value is ' + sValue + '.', LOG_LEVEL_VERBOSE);
                             end
                             else if (GetIsNumber(l_2da.entry[iIndex, iColumn]) and (GetIsNumber(sTemp) = False)) then begin
                                 sValue := l_2da.entry[iIndex, iColumn];
                                 AddLogLine('Row value increment failed! Specified modifier "' + sTemp + '" is not a number. Old row value not changed.', LOG_LEVEL_ALERT);
                             end
                             else if ((GetIsNumber(l_2da.entry[iIndex, iColumn]) = False) and GetIsNumber(sTemp)) then begin
                                 sValue := l_2da.entry[iIndex, iColumn];
                                 AddLogLine('Row value increment failed! Specified row column does not contain a number. Old row value not changed.', LOG_LEVEL_ALERT);
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
                             AddLogLine('Setting copied row column ' + sKey + ' to next HIGHEST value ' + sValue + '.', LOG_LEVEL_VERBOSE);
                         end;

                         sValue := GetMemoryToken(sValue);

                         // Set the modified value in this table cell.
                         l_2da.entry[iIndex, iColumn] := sValue;
                     end;
                 except
                       // Missing column values are not fatal, just skip it.
                       on e : EDead do begin
                          if (e.HelpContext = 8) then
                             AddLogLine('Invalid column label "' + sKey + '" encountered! Skipping entry...', LOG_LEVEL_ALERT)
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
            AddLogLine('Modifying binary files...', LOG_LEVEL_INFORMATION);

            for i := 0 to (oHackList.count - 1) do begin
                sFilename := l_ini.ReadString('HACKList', oHackList.Strings[i], '');
                if (sFilename <> '') and (length(sFilename) > 4) then begin
                    AddLogLine('Modifying binary file "' + sFilename + '"...', LOG_LEVEL_VERBOSE);
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
       AddLogLine('No offsets found for file ' + sFile + ', skipping...', LOG_LEVEL_ALERT);
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
           AddLogLine('No valid ' + sFile + ' file found! Skipping file.', LOG_LEVEL_ERROR);
           exit;
        end;

        if l_dlgopen.DoBackup() then
           AddLogLine('Saving unaltered backup copy of ' + l_dlgopen.FileName + ' in ' + l_path + 'backup\.', LOG_LEVEL_INFORMATION);

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
                        AddLogLine('Modifying file ' + sFile + ', setting value at offset "' + sOff + '" to "' + sVal + '".', LOG_LEVEL_VERBOSE);
                    end;
                end
                else begin
                    AddLogLine('Invalid offset(' + sOff + ') or value(' + sVal + ') modifier for file ' + sFile + '. Skipping...', LOG_LEVEL_ALERT);
                end;
            end;
        finally
            theFile.free();
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
   sFolderName : string;
   sFile       : string;
   sPath       : string;
   sFolder     : string;
   sSection    : string;
   sKey        : string;
   sExt        : string;
   i, n        : integer;
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
             AddLogLine('Installing unmodified files...', LOG_LEVEL_INFORMATION);

             // Go through all specified folders and copy the files there as instructed....
             for i := 0 to (oFolderList.count - 1) do begin
                 sSection := oFolderList.Strings[i];
                 sFolder  := l_ini.ReadString('InstallList', sSection, '');

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
                     if  not DirectoryExists(sPath + sFolder) then begin
                         AddLogLine('Folder ' + sPath + sFolder + ' did not exist, creating it...', LOG_LEVEL_INFORMATION);
                         ForceDirectories(sPath + sFolder);
                     end;

                     // ADDED(2006-01-24) Failsafe in case something went wrong above...
                     if  not DirectoryExists(sPath + sFolder) then begin
                         AddLogLine('Unable to create folder ' + sPath + sFolder + '! Skipping folder...', LOG_LEVEL_ERROR);
                         continue;
                     end;

                     if (l_ini.SectionExists(sSection)) then begin
                         oFileList := TStringList.Create();
                         try
                             // Copy all files for this folder to the correct location.
                             l_ini.ReadSection(sSection, oFileList);
                             for n := 0 to (oFileList.count - 1) do begin
                                 sKey  := oFileList.Strings[n];
                                 sFile := l_ini.ReadString(sSection, sKey, '');
                                 // Copy file from the tslpatchdata folder, if it exists....
                                 if (sFile <> '') and FileExists(l_datapath + sFile) then begin
                                     // File already exists, won't overwrite anything just to be safe...
                                     if FileExists(sPath + sFolder + '\' + sFile) then begin
                                         // ADDED(2005-06-09) Allow replacing existing files...
                                         if (lowercase(copy(sKey, 1, 7)) = 'replace') then begin
                                             // ADDED(2005-06-10) Don't allow the Installer to mess with the game binaries or the dialog.tlk file.
                                             sExt := lowercase(copy(sFile, Length(sFile) - 2, 3));
                                             if (sExt = 'exe') then begin
                                                 AddLogLine('Skipping file ' + sFile + ', this Installer will not overwrite EXE files!', LOG_LEVEL_ALERT);
                                                 continue;
                                             end;

                                             if (sExt = 'tlk') then begin
                                                 AddLogLine('Skipping file ' + sFile + ', this Installer will not overwrite dialog.tlk directly.', LOG_LEVEL_ALERT);
                                                 continue;
                                             end;

                                             if (l_dlgopen.DoBackups = True) then
                                                 BackupFile(sPath + sFolder + '\' + sFile, l_path + 'backup\' + sFile);

                                             DeleteFile(sPath + sFolder + '\' + sFile);
                                             BackupFile(l_datapath + sFile, sPath + sFolder + '\' + sFile);
                                             AddLogLine('Replacing file ' + sFile + ' in the ' + sFolderName + ' folder...', LOG_LEVEL_INFORMATION);
                                         end
                                         else begin
                                             AddLogLine('A file named ' + sFile + ' already exists in the ' + sFolderName + ' folder. Skipping file...', LOG_LEVEL_ALERT);
                                         end;
                                     end
                                     else begin
                                         BackupFile(l_datapath + sFile, sPath + sFolder + '\' + sFile);
                                         AddLogLine('Copying file ' + sFile + ' to the ' + sFolderName + ' folder...', LOG_LEVEL_INFORMATION);
                                     end;
                                 end
                                 else begin
                                     AddLogLine('Unable to copy file "' + sFile + '", file does not exist!', LOG_LEVEL_ALERT);
                                 end;
                             end;
                         finally
                             oFileList.free();
                         end;
                     end
                     else begin
                         AddLogLine('No install instructions (' + sSection + ') found for folder ' + sFolderName + '.', LOG_LEVEL_ALERT);
                     end;
                 end
                 else begin
                     AddLogLine('Invalid install location "' + sFolderName + '" encountered! Skipping...', LOG_LEVEL_ERROR);
                 end;
             end;
         end;
     finally
         oFolderList.free();
     end;
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
constructor TPatchFileHandler.Create(oBox : TOpenDialog);
begin
    inherited Create();

    l_dlgbox      := oBox;
    l_installpath := '';
    l_currentpath := '';
    l_currentfile := '';
    l_basepath    := '';
    l_installmode := False;
    l_backupfile  := True;
end;


// -----------------------------------------------------------------------------
// 2005-05-28
// Ugly workaround since I can't declare the l_parentclass as TTSLPatcher
// directly for some peculiar reason, should work but... :/
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
        raise EAbort.CreateHelp('Error! No install path has been set!', 3);

    if (l_currentfile = '') then
        raise EAbort.CreateHelp('Error! No file to install is specified!', 4);

    if not SysUtils.FileExists(l_currentpath + l_currentfile) then
        raise EAbort.CreateHelp('Error! File "' + l_currentpath + l_currentfile + '" set to be patched does not exist!', 5);

    result := l_currentpath + l_currentfile;
end;


// -----------------------------------------------------------------------------
// 2005-05-28
// Wrapper for making a backup of the last file fetched by the PatchFileHandler.
// Backups will be placed in the 'backup' folder within the same folder as the
// patcher application.
// -----------------------------------------------------------------------------
function TPatchFileHandler.DoBackup() : boolean;
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

    if not FileExists(l_basepath + 'backup\' + l_currentfile) then begin
        BackupFile(l_currentpath + l_currentfile, l_basepath + 'backup\' + l_currentfile);
        result := True;
    end;
end;


// -----------------------------------------------------------------------------
// 2005-05-30 - Return the install path (ie game folder), if none currently is
//              set, ask the user for its location.
// -----------------------------------------------------------------------------
function TPatchFileHandler.GetInstallPath() : string;
begin
    if (l_installpath = '') or not DirectoryExists(l_installpath) then begin
        l_installpath := OpenFolderDialog('Please select the folder where your game is installed.', 0);
        if (l_installpath = '') or not DirectoryExists(l_installpath) then
            raise EAbort.CreateHelp('Error! Invalid game directory specified!', 10);

        // Check if dialog.tlk exists within the specified folder....
        if not FileExists(l_installpath + '\dialog.tlk') then
            raise EAbort.CreateHelp('Error! Invalid game folder specified, dialog.tlk file not found!', 11);

        // Backslash after last folder is missing for some reason, so add it...
        if (l_installpath[length(l_installpath)] <> '\') then
            l_installpath := l_installpath + '\';

        AddLogLine('Install path set to ' + l_installpath + '.', LOG_LEVEL_VERBOSE);
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
// -----------------------------------------------------------------------------
function TPatchFileHandler.Execute(sFilename : string; patchType : TPatchFile; bOverwrite : boolean = False) : boolean;
var
   sExt         : string;
   sDesc        : string;
   sRequired    : string;
   sRequiredMsg : string;
   sTemp        : string;
begin
    result := False;
    l_backupfile := True;

    // Configure the Open File dialog box, in case it should be used...
    if (patchType = fileTlk) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := 'tlk';
        l_dlgbox.Filter := 'TLK file|*.tlk';
        l_dlgbox.Title := 'Please select your ' + sFilename + ' file.';
    end
    else if (patchType = file2da) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := '2da';
        l_dlgbox.Filter := '2DA file|*.2da';
        l_dlgbox.Title := 'Please select your ' + sFilename + ' file.';
    end
    else if (patchType = fileGff) then begin
        sExt := lowercase(copy(sFilename, Length(sFilename) - 2, 3));

        if (Length(sExt) < 1) then
           sExt := '*';

        if (sExt = 'uti') then      sDesc := 'Item (*.uti)'
        else if (sExt = 'utc') then sDesc := 'Creature (*.utc)'
        else if (sExt = 'utm') then sDesc := 'Store (*.utm)'
        else if (sExt = 'utp') then sDesc := 'Placeable (*.utp)'
        else if (sExt = 'dlg') then sDesc := 'Dialog (*.dlg)'
        else if (sExt = 'gff') then sDesc := 'GFF file (*.gff)'
        else                        sDesc := 'All files (*.*)';

        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := sExt;
        l_dlgbox.Filter := sDesc + '|*.' + sExt;
        l_dlgbox.Title := 'Please select your ' + sFilename + ' file.';
    end
    else if (patchType = fileHack) then begin
        sExt := lowercase(copy(sFilename, Length(sFilename) - 2, 3));
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := sExt;
        l_dlgbox.Filter := uppercase(sExt) + ' File (*.' + sExt + ')|*.' + sExt;
        l_dlgbox.Title := 'Please select the ' + sFilename + ' file that came with this Mod.';
    end
    else if (patchType = fileCompile) then begin
        l_dlgbox.FileName := sFilename;
        l_dlgbox.DefaultExt := 'nss';
        l_dlgbox.Filter := 'NSS Script Source (*.nss)|*.nss';
        l_dlgbox.Title := 'Please select the ' + sFilename + ' file that came with this Mod.';
    end;

    // The patcher is running in Installer mode... Automatically find and patch the files in
    // the Override folder. If they don't already exist in Override, copy them there from the
    // TSLPatchData folder if they exist there.
    if l_installmode then begin
        // The Install path (aka game directory) has not already been set. Ask the user
        // to select the folder the game is located in. Check for presence of dialog.tlk
        // to verify that it is the right one.
        if (l_installpath = '') or not DirectoryExists(l_installpath) then begin
            l_installpath := OpenFolderDialog('Please select the folder where your game is installed.', 0);
            if (l_installpath = '') or not DirectoryExists(l_installpath) then
                raise EAbort.CreateHelp('Error! Invalid game folder specified!', 6);

            // Check if dialog.tlk exists within the specified folder....
            if not FileExists(l_installpath + '\dialog.tlk') then
                raise EAbort.CreateHelp('Error! Invalid game folder specified, dialog.tlk file not found!', 7);

            // Backslash after last folder is missing for some reason, so add it...
            if (l_installpath[length(l_installpath)] <> '\') then
                l_installpath := l_installpath + '\';

            AddLogLine('Install path set to ' + l_installpath + '.', LOG_LEVEL_VERBOSE);

            // ADDED(2005-08-23) - Added support for a "Required" key.When set to a
            //                     filename a file with that name must exist in the override
            //                     folder already in order for the installer to proceed.
            if (l_parentclass <> nil) and (l_parentclass is TTSLPatcher) then begin
                sRequired    := TTSLPatcher(l_parentclass).l_ini.ReadString('Settings', 'Required', '');
                if (sRequired <> '') then begin
                    if not FileExists(l_installpath + 'override\' + sRequired) then begin
                        sRequiredMsg := TTSLPatcher(l_parentclass).l_ini.ReadString('Settings', 'RequiredMsg', '');
                        if (sRequiredMsg = '') then begin
                            raise EAbort.CreateHelp('Cannot locate required file ' + sRequired + ', unable to continue with install!', 99);
                        end
                        else begin
                            raise EAbort.CreateHelp(sRequiredMsg, 99);
                        end;

                        Result := False;
                        Exit;
                    end;
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
                raise EAbort.CreateHelp('Error! Unable to locate file to patch, "' + sFilename + '" file not found!', 8);
            end;
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Override folder doesn't already exist, create it.
        if not DirectoryExists(l_installpath + 'override\') then begin
           ForceDirectories(l_installpath + 'override\');
           AddLogLine('No Override folder found, creating it at ' + l_installpath + 'override\.', LOG_LEVEL_INFORMATION);
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // ADDED(2006-01-10)
        // CompileList files are a special case since they need to be processed
        // indirectly before they are put in override. The final resulting file
        // is also named differently than the original file. A bit messy and
        // VERY hacky, but as long as it works it shall have to do for now...
        if (patchType = fileCompile) then begin
           l_currentfile := sFilename;
           l_currentpath := l_basepath + 'tslpatchdata\';

           sTemp := copy(sFilename, 1, Pos(ExtractFileExt(sFilename), sFilename) - 1) + '.ncs';

            if (bOverwrite) then begin
                if FileExists(l_installpath + 'override\' + sTemp) then begin
                   // Handle backups manually since this doesn't follow the regular pattern of use... :/
                   if l_dobackups then begin
                       if not DirectoryExists(l_basepath + 'backup\') then
                           ForceDirectories(l_basepath + 'backup\');

                       if not FileExists(l_basepath + 'backup\' + sTemp) then begin
                          BackupFile(l_installpath + 'override\' + sTemp, l_basepath + 'backup\' + sTemp);
                          AddLogLine('Making backup copy of script file "' + sFilename + '" found in override...', LOG_LEVEL_INFORMATION);
                       end;
                   end;
                end;
            end
            else begin
                if FileExists(l_installpath + 'override\' + sFilename) then begin
                    AddLogLine('Script file "' + sFilename + '" already exists in override! Skipping...', LOG_LEVEL_ALERT);
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
            if FileExists(l_basepath + 'tslpatchdata\' + sFilename) then begin
                l_currentfile := sFilename;
                l_currentpath := l_installpath + 'override\';

                // Gör backup om filen redan existerar i Override...
                // FIX(2005-06-12) Lagt till separata log-meddelanden beroende på om filen
                // redan fanns eller om den bara skall kopieras.
                if FileExists(l_installpath + 'override\' + sFilename) then begin
                    l_backupfile := True;
                    DoBackup();
                    DeleteFile(l_installpath + 'override\' + sFilename);
                    AddLogLine('Updating and replacing file ' + sFilename + ' in Override folder...', LOG_LEVEL_INFORMATION);
                end
                else begin
                    AddLogLine('Updating and copying file ' + sFilename + ' to Override folder...', LOG_LEVEL_INFORMATION);
                end;

                BackupFile(l_basepath + 'tslpatchdata\' + sFilename, l_installpath + 'override\' + sFilename);

                l_backupfile := False;
                result := True;
            end
            else begin
                AddLogLine('Unable to locate file "' + sFilename + '" to install, skipping...', LOG_LEVEL_ERROR);
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
            if not FileExists(l_installpath + 'override\' + sFilename) then begin
                if FileExists(l_basepath + 'tslpatchdata\' + sFilename) then begin
                    // Blueprint file found, copy it to the Override folder.
                    BackupFile(l_basepath + 'tslpatchdata\' + sFilename, l_installpath + 'override\' + sFilename);
                    l_backupfile := False;
                    AddLogLine('Copying file ' + sFilename + ' to Override folder...', LOG_LEVEL_INFORMATION);
                    l_currentfile := sFileName;
                    l_currentpath := l_installpath + 'override\';
                    result := True;
                end
                else begin
                    AddLogLine('Unable to locate file "' + sFilename + '" to install, skipping...', LOG_LEVEL_ERROR);
                    result := False;
                    exit;
                end;
            end
            else begin
                AddLogLine('A file named "' + sFilename + '" already exists in the Override folder. Skipping...', LOG_LEVEL_ALERT);
                result := False;
                exit;
            end;

            exit;
        end;

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // File does not already exist in the override folder, copy it there from
        // the one in the tslpatchdata folder and then return the new copy...
        if not FileExists(l_installpath + 'override\' + sFilename) then begin
            // File to patch does not exist in the tslpatchdata folder! Fall back to ask
            // the user for one...
            if not FileExists(l_basepath + 'tslpatchdata\' + sFilename) then begin
                AddLogLine('No file blueprint found in tslpatchdata folder, asking for file location...', LOG_LEVEL_VERBOSE);
                if (l_dlgbox.Execute()) then begin
                    l_currentfile := ExtractFileName(l_dlgbox.FileName);
                    l_currentpath := ExtractFilePath(l_dlgbox.FileName);

                    // FIX(2005-06-09) Kopiera den valda filen till Override istället och
                    // sätt den kopian till att patchas istället för originalet.
                    BackupFile(l_currentpath + l_currentfile, l_installpath + 'override\' + sFilename);
                    l_currentfile := sFilename;
                    l_currentpath := l_installpath + 'override\';
                    result := True;
                    AddLogLine('Copying file "' + sFilename + '" to Override folder...', LOG_LEVEL_INFORMATION);

                    exit;
                end
                else begin
                    raise EAbort.CreateHelp('Error! Unable to locate file to patch, "' + sFilename + '" file not found!', 9);
                end;
            end
            else begin
                // Blueprint file found, copy it to the Override folder.
                BackupFile(l_basepath + 'tslpatchdata\' + sFilename, l_installpath + 'override\' + sFilename);
                l_backupfile := False;
                AddLogLine('Copying file "' + sFilename + '" to Override folder...', LOG_LEVEL_INFORMATION);
            end;
        end
        else begin
            AddLogLine('Modifying file "' + sFilename + '" found in Override folder...', LOG_LEVEL_INFORMATION);
        end;

        l_currentfile := sFilename;
        l_currentpath := l_installpath + 'override\';
        result := True;
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
 
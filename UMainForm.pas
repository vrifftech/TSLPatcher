unit UMainForm;
// =============================================================================
// TSLPatcher - GUI main form.
// =============================================================================
// See top of the UTSLPatcher unit for version and change information....
// -----------------------------------------------------------------------------


interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, UGFFFile,
  StdCtrls, Buttons, ComCtrls, ExtCtrls, UTSLPatcher, U2DAEdit, UTLKFile, UST_IniFile, UST_Common,
  XPMan;

type
  TMainForm = class(TForm)
    paneMain: TPanel;
    txtInfo: TRichEdit;
    btnContinue: TBitBtn;
    btnQuit: TButton;
    FileOpenBox: TOpenDialog;
    sbar: TStatusBar;
    lblAuthorTag: TLabel;
    txtFallback: TMemo;
    XPManifest1: TXPManifest;
    btnSummary: TSpeedButton;
    Label1: TLabel;
    pbar: TProgressBar;
    procedure FormShow(Sender: TObject);
    procedure btnContinueClick(Sender: TObject);
    procedure btnQuitClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure paneMainDblClick(Sender: TObject);
    procedure btnSummaryClick(Sender: TObject);
  private
    { Private declarations }
    bInstalled : boolean;
    bClicked   : boolean;
    bSummary   : boolean;
    sIniFile   : string;
    sInfoFile  : string;
    sDataPath  : string;
  public
    { Public declarations }
    procedure UpdateInstallPath(const sPath : string);
    procedure UpdateProgress(const iCnt : integer; const iMax : integer);
    procedure ShowSummary();


    property IniFileName  : string    read sIniFile    write sIniFile;
    property InfoFileName : string    read sInfoFile   write sInfoFile;
  end;

var
  MainForm: TMainForm;


resourcestring
	// Miscellaneous
    LS_GUI_CONFIGMISSING      = 'WARNING! Cannot locate the INI file "%s" with work instructions!';
    LS_GUI_DEFAULTCAPTION     = 'Game Data Patcher for KotOR/TSL';
    LS_GUI_SBARINSTALLDEST    = 'Game folder: %s';
    LS_GUI_SBARINSTALLUSERSEL = 'User selected.';
    LS_GUI_INFOLOADERROR      = 'Unable to load the instructions text! Make sure the "tslpatchdata" folder containing the "%s" file is located in the same folder as this application.';
    LS_GUI_BUTTONCAPINSTALL   = 'In&stall Mod';
    LS_GUI_BUTTONCAPPATCH     = '&Start patching';
    LS_GUI_CONFIGLOADERROR    = 'Unable to load the %s file! Make sure the "tslpatchdata" folder is located in the same folder as this application.';
    LS_GUI_DEFAULTCONFIRMTEXT = 'This will start patching the necessary game files. Do you want to do this?';
    LS_GUI_SUMMARY            = 'The Installer is finished. Please check the progress log for details about what has been done.';
    LS_GUI_SUMMARYWARN        = 'The Installer is finished, but %s warnings were encountered! The Mod may or may not be properly installed. Please check the progress log for further details.';
    LS_GUI_SUMMARYERROR       = 'The Installer is finished, but %s errors were encountered! The Mod has likely not been properly installed. Please check the progress log for further details.';
    LS_GUI_SUMMARYERRORWARN   = 'The Installer is finished, but %s errors and %s warnings were encountered! The Mod most likely has not been properly installed. Please check the progress log for further details.';
    LS_GUI_PSUMMARY           = 'The Patcher is finished. Please check the progress log for details about what has been done.';
    LS_GUI_PSUMMARYWARN       = 'The Patcher is finished, but %s warnings were encountered! The Mod may or may not be properly installed. Please check the progress log for further details.';
    LS_GUI_PSUMMARYERROR      = 'The Patcher is finished, but %s errors were encountered! The Mod has likely not been properly installed. Please check the progress log for further details.';
    LS_GUI_PSUMMARYERRORWARN  = 'The Patcher is finished, but %s errors and %s warnings were encountered! The Mod most likely has not been properly installed. Please check the progress log for further details.';
    LS_GUI_EXCEPTIONPREFIX    = 'An error occured! %s (%s)';
    LS_GUI_UEXCEPTIONPREFIX   = 'An unhandled error occured! ';
    LS_GUI_CONFIRMQUIT        = 'Are you sure you wish to quit?';
    
    // Configuration summary
    LS_GUI_REPTITLE           = 'CONFIGURATION SUMMARY';
    LS_GUI_REPSETTINGS        = 'Settings';
    LS_GUI_REPCONFIGFILE      = 'Config file';
    LS_GUI_REPINFOFILE        = 'Information file';
    LS_GUI_REPINSTALLOC       = 'Install location';
    LS_GUI_REPUSERSELECTED    = 'User selected.';
    LS_GUI_REPBACKUPS         = 'Make backups';
    LS_GUI_REPDOBACKUPS       = 'Before modifying/overwriting existing files.';
    LS_GUI_REPNOBACKUPS       = 'Disabled, no backups are made.';
    LS_GUI_REPLOGLEVEL0       = 'Log level: 0 - No progress log';
    LS_GUI_REPLOGLEVEL1       = 'Log level: 1 - Errors only';
    LS_GUI_REPLOGLEVEL2       = 'Log level: 2 - Errors and warnings only';
    LS_GUI_REPLOGLEVEL3       = 'Log level: 3 - Standard: Progress, errors and warnings.';
    LS_GUI_REPLOGLEVEL4       = 'Log level: 4 - Debug: Detailed progress, errors and warnings.';
    LS_GUI_REPTLKAPPEND       = 'dialog tlk appending';
    LS_GUI_REPNEWTLKCOUNT     = 'New entries';
    LS_GUI_REP2DATITLE        = '2DA file changes';
    LS_GUI_REP2DAFILE         = '%s - new rows: %s, modified rows: %s, new columns: %s';
    LS_GUI_REPGFFTITLE        = 'GFF file changes';
    LS_GUI_REPNONE            = 'none';
    LS_GUI_REPOVERWRITE       = 'overwrite existing';
    LS_GUI_REPMODIFY          = 'modify existing';
    LS_GUI_REPSKIP            = 'skip existing';
    LS_GUI_REPLOCATION        = 'location';
    LS_GUI_REPHACKTITLE       = 'NCS file integer hacks';
    LS_GUI_REPCOMPILETITLE    = 'Modified & recompiled scripts';
    LS_GUI_REPSSFTITLE        = 'New/modified Soundset files';
    LS_GUI_REPINSTALLSTART    = 'Unpatched files to install';
    LS_GUI_REPINSTALLLOC      = 'Location';
    LS_GUI_REPGAMEFOLDER      = 'Game folder';
    

    

implementation

uses UNamespaceForm;

{$R *.DFM}

procedure TMainForm.FormShow(Sender: TObject);
var
   sPath : string;
   sFile : string;
   oIni  : TST_IniFile;
   bIns  : boolean;
   bLookup : boolean;
   iVersion: integer;
begin
     bInstalled := False;
     bSummary := false;

     // ADDED(2005-07-06) Added var to assign the name of the INI file to use
     //                   dynamically.
     if (sIniFile = '') then
        sIniFile := 'changes.ini';

     sPath      := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + 'tslpatchdata');

     // ADDED(2006-04-29) Added support for using multiple INI files by defining a
     //                   namespace.ini file. If this file doesn't exist just
     //                   proceed as normal. If it does exist, prompt the user for
     //                   which install should be used.
     if SysUtils.FileExists(sPath + 'namespaces.ini') then begin
         NamespaceForm.Path := sPath;
         if (NamespaceForm.ShowModal() = mrOk) then begin
            sIniFile := NamespaceForm.IniFile;
            sInfoFile := NamespaceForm.InfoFile;
            sPath     := NamespaceForm.DataPath;
         end
         else begin
             Application.Terminate();
         end;
     end;

     // FIX(2006-08-28) Try to fix the problem with improperly sized GUI component on some computers.
     paneMain.Width := (MainForm.Width - 8);
     paneMain.Height := (MainForm.Height - 46);

     sDataPath := sPath;

     if not FileExists(sPath + sIniFile) then begin
         ShowAlertBox(Format(LS_GUI_CONFIGMISSING, [sIniFile]));
         btnContinue.enabled := False;
     end;

     oIni       := TST_IniFile.Create(sPath + sIniFile);
     try
         sFile      := sPath + sInfoFile;
         bIns       := oIni.ReadBool('Settings', 'InstallerMode', False);
         Caption    := oIni.ReadString('Settings', 'WindowCaption', LS_GUI_DEFAULTCAPTION);

         // ADDED(2006-06-26) Added Settings key to read the game install folder from
         // the Registry instead of asking the user for the folder.
         bLookup := oIni.ReadBool('Settings', 'LookupGameFolder', false);
         if bLookup then begin
            iVersion := oIni.ReadInteger('Settings', 'LookupGameNumber', 2);
            if (iVersion = 1) then
                sbar.Panels[0].Text := Format(LS_GUI_SBARINSTALLDEST, [GetRegistryString('\SOFTWARE\BioWare\SW\KOTOR', 'Path')])
            else
                sbar.Panels[0].Text := Format(LS_GUI_SBARINSTALLDEST, [GetRegistryString('\SOFTWARE\LucasArts\KotOR2', 'Path')]);
         end
         else begin
             sbar.Panels[0].Text := Format(LS_GUI_SBARINSTALLDEST, [LS_GUI_SBARINSTALLUSERSEL]);
         end;
     finally
         oIni.free();
     end;

     // If info-text is missing there is a fair chance the other files cannot
     // be found either, so disable the Start button.
     if FileExists(sFile) then begin
        txtInfo.clear();
        txtInfo.lines.LoadFromFile(sFile);

        if (bIns = False) then
            btnContinue.caption := LS_GUI_BUTTONCAPPATCH
        else
            btnContinue.caption := LS_GUI_BUTTONCAPINSTALL;
            
     end
     else begin
         ShowAlertBox(Format(LS_GUI_INFOLOADERROR, [sInfoFile]));
         btnContinue.enabled := False;
     end;
end;

procedure TMainForm.UpdateInstallPath(const sPath : string);
begin
     sbar.Panels[0].Text := Format(LS_GUI_SBARINSTALLDEST, [sPath]);
     Application.ProcessMessages();
end;


procedure TMainForm.UpdateProgress(const iCnt : integer; const iMax : integer);
begin
    if (pbar.Max <> iMax) then
        pBar.Max := iMax;

    pbar.Position := iCnt;
end;


procedure TMainForm.btnContinueClick(Sender: TObject);
var
   oPatcher  : TTSLPatcher;
   oIni      : TST_IniFile;
   rStatus   : TPatcherResult;
   sFilename : string;
   sPath     : string;
   sMessage  : string;
   iLoglevel : integer;
   oCursor   : TCursor;
   bExists   : boolean;
   bInstall  : boolean;
// bAborted  : boolean;
   bLogOld   : boolean;
begin
    // bAborted  := False;
     oCursor   := Screen.Cursor;

     // ADDED(2005-07-06) Added var to assign the name of the INI file to use
     //                   dynamically.
     if (sIniFile = '') then
         sIniFile := 'changes.ini';

     sFilename := sIniFile;
     sPath     := sDataPath;

     // ADDED(2005-07-31) Added bLogOld parameter...
     oIni      := TST_IniFile.Create(sPath + sFilename);
     bExists   := oIni.ReadBool('Settings', 'FileExists', false);
     bInstall  := oIni.ReadBool('Settings', 'InstallerMode', False);
     sMessage  := oIni.ReadString('Settings', 'ConfirmMessage', '');
     iLoglevel := oIni.ReadInteger('Settings', 'LogLevel', 3);
     bLogOld   := oIni.ReadBool(   'Settings', 'PlaintextLog', False);
     oIni.free();

     try
         try
             if (bExists = False) then begin
                ShowAlertBox(Format(LS_GUI_CONFIGLOADERROR, [sIniFile]));
                // bAborted := True;
                exit;
             end;

             if (sMessage = '') then begin
                sMessage := LS_GUI_DEFAULTCONFIRMTEXT;
             end;

             if ((sMessage = 'N/A') or (ShowConfirmBox(sMessage) = mrYes)) then begin
                btnContinue.enabled := False;
                btnSummary.enabled  := False;
                btnQuit.enabled     := False;
                Screen.Cursor       := crHourglass;

                // ADDED(2005-07-31) Hide RichEd box and show plaintext box if
                //                   fallback log style is set.
                if bLogOld and (iLoglevel > 0) then begin
                    txtInfo.visible := False;
                    txtFallback.visible := True;
                end;

                // Allow the cursor change to update...
                Application.ProcessMessages;

                // Create and setup the Patcher class...
                // TODO: Should use callback instead for getting the file box, but I'm too lazy to fix that right now...
                oPatcher := TTSLPatcher.Create(sFilename, FileOpenBox, sPath);
                try
                    // TODO: Logs should probably also be done with callbacks instead, but whatever...
                    //       it works for now and I'm too lazy to change it currently. :)
                    oPatcher.logbuffer        := txtInfo;
                    oPatcher.logbuffertxt     := txtFallback;
                    oPatcher.PathCallback     := self.UpdateInstallPath;
                    oPatcher.ProgressCallback := self.UpdateProgress; // ADDED(2006-09-14)

                    // Do the actual patching/Installing...
                    rStatus := oPatcher.RunPatchOperation();
                finally
                    oPatcher.free();
                end;

                // FIX(2005-07-06) Changed feedback messages to not indicate success,
                //                 since occurance of errors/warnings is unknown here
                //                 due to the internal error logging in the Patcher class
                //                 which isn't exception based.
                // CHANGED(2006-02-07) Display different result message box depending on the
                // number of warnings and errors that were encountered.
                if (bInstall) then begin
                    if (rStatus.Errors = 0) and (rStatus.Warnings = 0) then begin
                        ShowInfoBox(LS_GUI_SUMMARY);
                    end
                    else if (rStatus.Errors = 0) and (rStatus.Warnings > 0) then begin
                        ShowAlertBox(Format(LS_GUI_SUMMARYWARN, [IntToStr(rStatus.Warnings)]));
                    end
                    else if (rStatus.Errors > 0) and (rStatus.Warnings = 0) then begin
                        ShowAlertBox(Format(LS_GUI_SUMMARYERROR, [IntToStr(rStatus.Errors)]));
                    end
                    else begin
                        ShowAlertBox(Format(LS_GUI_SUMMARYERRORWARN, [IntToStr(rStatus.Errors), IntToStr(rStatus.Warnings)]));
                    end;
                end
                else begin
                    if (rStatus.Errors = 0) and (rStatus.Warnings = 0) then begin
                        ShowInfoBox(LS_GUI_PSUMMARY);
                    end
                    else if (rStatus.Errors = 0) and (rStatus.Warnings > 0) then begin
                        ShowAlertBox(Format(LS_GUI_PSUMMARYWARN, [IntToStr(rStatus.Warnings)]));
                    end
                    else if (rStatus.Errors > 0) and (rStatus.Warnings = 0) then begin
                        ShowAlertBox(Format(LS_GUI_PSUMMARYERROR, [IntToStr(rStatus.Errors)]));
                    end
                    else begin
                        ShowAlertBox(Format(LS_GUI_PSUMMARYERRORWARN, [IntToStr(rStatus.Errors), IntToStr(rStatus.Warnings)]));
                    end;
                end;

                bInstalled := True;
             end
             else begin
                 // bAborted := True;
             end;
         except
               // Pick up any error messages logged by the data carrier classes and show them.
               on e : EHell     do ShowAlertBox(Format(LS_GUI_EXCEPTIONPREFIX, [e.Message, 'TLK']));
               on e : EDead     do ShowAlertBox(Format(LS_GUI_EXCEPTIONPREFIX, [e.Message, '2DA-' + IntToStr(e.HelpContext)]));
               on e : EAbort    do ShowAlertBox(Format(LS_GUI_EXCEPTIONPREFIX, [e.Message, 'GEN-' + IntToStr(e.HelpContext)]));
               on e : EGFFError do ShowAlertBox(Format(LS_GUI_EXCEPTIONPREFIX, [e.Message, 'GFF-' + IntToStr(e.HelpContext)]));

               // ADDED(2006-01-27) Generic error handler as well please...
               on e : Exception do ShowAlertBox(Format(LS_GUI_UEXCEPTIONPREFIX, [e.Message]));
         end;
     finally
         Screen.Cursor := oCursor;
         btnQuit.enabled := True;
         btnQuit.setfocus;
         bInstalled := True;

         // ADDED(2005-06-07) Save the installation log to a file...
         // CHANGED(2006-08-09) Save log on aborting errors as well, may aid in finding the problem.
         if (*(bAborted = False) and*) (iLoglevel > 0) then begin
            if bLogOld then
                txtFallback.Lines.SaveToFile(ExtractFilePath(Application.ExeName) + 'installlog.txt')
            else
                txtInfo.Lines.SaveToFile(ExtractFilePath(Application.ExeName) + 'installlog.rtf');
         end;
     end;
end;

procedure TMainForm.btnQuitClick(Sender: TObject);
begin
     if (bInstalled or (ShowConfirmBox(LS_GUI_CONFIRMQUIT) = mrYes)) then
        Application.Terminate;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
     // FIX(2005-07-31) Only resize RichEd window if visible...
     if txtinfo.Visible then
        txtInfo.repaint();

     // ADDED(2005-07-31) Repaint fallback log window on resize as well.
     if txtFallback.Visible then
        txtFallback.repaint();

     // FIX(2006-08-28) Try to fix the problem with improperly sized GUI component on some computers.
     paneMain.Width := (MainForm.Width - 8);
     paneMain.Height := (MainForm.Height - 46);
end;

procedure TMainForm.paneMainDblClick(Sender: TObject);
begin
     if (bClicked) then
        lblAuthorTag.Visible := not lblAuthorTag.Visible;

     bClicked := not bClicked;
end;


procedure TMainForm.ShowSummary();
var
   oIni     : TST_IniFile;
   oList    : TStringList;
   oMods    : TStringList;
   sKey     : string;
   sVal     : string;
   sMod     : string;
   sReplace : string;
   sFile    : string;
   sDest    : string;
   sSrc     : string;
   sDefDest : string;
   iMod     : integer;
   i, n     : integer;
   iTlkCnt  : integer;
   iNewCnt  : integer;
   iModCnt  : integer;
   iColCnt  : integer;
   bLookup  : boolean;
begin
    oIni := nil;
    try
         oIni := TST_IniFile.Create(sDataPath + sIniFile);

         // Reset the text box settings...
         txtInfo.Lines.Clear();
         txtInfo.Clear();
         txtInfo.wordwrap := False;
         txtInfo.Paragraph.Alignment := taLeftJustify;
         txtInfo.Paragraph.Numbering := nsNone;
         txtInfo.Paragraph.LeftIndent := 0;
         txtInfo.DefAttributes.Color := clInfoText;
         txtInfo.DefAttributes.Name := 'Courier New';
         txtInfo.DefAttributes.Size := 9;
         txtInfo.DefAttributes.Style := [];
         txtInfo.Alignment := taLeftJustify;
         txtInfo.Font.Name := 'Courier New';
         txtInfo.Font.Style := [];
         txtInfo.Font.Size := 9;
         txtInfo.Font.Color := clInfoText;

         txtInfo.Lines.Add('==================================');
         txtInfo.Lines.Add('TSLPatcher - ' + LS_GUI_REPTITLE);
         txtInfo.Lines.Add('==================================');

         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPSETTINGS + ':');
         txtInfo.Lines.Add('---------');

         // ADDED(2006-08-26) Show ini and rtf files used as well.
         txtInfo.Lines.Add(LS_GUI_REPCONFIGFILE + ': ' + sIniFile);
         txtInfo.Lines.Add(LS_GUI_REPINFOFILE + ': ' + sInfoFile);

         bLookup := oIni.ReadBool('Settings', 'LookupGameFolder', false);
         if bLookup then begin
            if (oIni.ReadInteger('Settings', 'LookupGameNumber', 2) = 1) then
                txtInfo.Lines.Add(LS_GUI_REPINSTALLOC + ': ' + GetRegistryString('\SOFTWARE\BioWare\SW\KOTOR', 'Path'))
            else
                txtInfo.Lines.Add(LS_GUI_REPINSTALLOC + ': ' + GetRegistryString('\SOFTWARE\LucasArts\KotOR2', 'Path'));
         end
         else begin
             txtInfo.Lines.Add(LS_GUI_REPINSTALLOC + ': ' + LS_GUI_REPUSERSELECTED);
         end;

         if oIni.ReadBool('Settings', 'BackupFiles', true) then
             txtInfo.Lines.Add(LS_GUI_REPBACKUPS + ': ' + LS_GUI_REPDOBACKUPS)
         else
             txtInfo.Lines.Add(LS_GUI_REPBACKUPS + ': ' + LS_GUI_REPNOBACKUPS);

         case oIni.ReadInteger('Settings', 'LogLevel', 3) of
             0: txtInfo.Lines.Add(LS_GUI_REPLOGLEVEL0);
             1: txtInfo.Lines.Add(LS_GUI_REPLOGLEVEL1);
             2: txtInfo.Lines.Add(LS_GUI_REPLOGLEVEL2);
             3: txtInfo.Lines.Add(LS_GUI_REPLOGLEVEL3);
             4: txtInfo.Lines.Add(LS_GUI_REPLOGLEVEL4);
         end;

         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPTLKAPPEND + ':');
         txtInfo.Lines.Add('---------------------');
         iTlkCnt := 0;
         oList := TStringList.Create();
         try
             oIni.ReadSection('TLKList', oList);
             for i := 0 to (oList.Count - 1) do begin
                 if (lowercase(oList[i]) <> '!sourcefile') and (lowercase(oList[i]) <> '!sourcefilef') then begin
                     inc(iTlkCnt);
                 end;
             end;
         finally
             oList.free();
         end;
         txtInfo.Lines.Add(LS_GUI_REPNEWTLKCOUNT + ': ' + IntToStr(iTlkCnt));



         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REP2DATITLE + ':');
         txtInfo.Lines.Add('-----------------');

         oList := TStringList.Create();
         oIni.ReadSection('2DAList', oList);
         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (none)  ');
         end
         else begin
             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('2DAList', sKey, '');
                 oMods := TStringList.Create();
                 oIni.ReadSection(sVal, oMods);
                 iNewCnt := 0;
                 iModCnt := 0;
                 iColCnt := 0;
                 for n := 0 to (oMods.count-1) do begin
                    sMod := lowercase(oMods[n]);
                    // Add a new line to the 2da.
                    if (Pos('addrow', sMod) <> 0) then begin
                        inc(iNewCnt);
                    end
                    // Modify existing line in the 2da.
                    else if (Pos('changerow', sMod) <> 0) then begin
                        inc(iModCnt);
                    end
                    // Add a new column to the 2da.
                    else if (Pos('addcolumn', sMod) <> 0) then begin
                        inc(iColCnt);
                    end
                    // Add a new column to the 2da.
                    else if (Pos('copyrow', sMod) <> 0) then begin
                        inc(iNewCnt);
                    end;
                 end;
                 oMods.free();
                 txtInfo.Lines.Add(' * ' + Format(LS_GUI_REP2DAFILE, [sVal, IntToStr(iNewCnt), IntToStr(iModCnt), IntToStr(iColCnt)]));
             end;
         end;
         oList.free();


         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPGFFTITLE + ':');
         txtInfo.Lines.Add('-----------------');

         oList := TStringList.Create();
         oIni.ReadSection('GFFList', oList);
         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (' + LS_GUI_REPNONE + ')  ');
         end
         else begin
             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('GFFList', sKey, '');
                 sMod := oIni.ReadString(sVal, '!SaveAs', sVal);

                 if (sMod = '') then
                     sMod := sVal;

                 // ADDED(2006-09-14) Show name of source file if applicable
                 sSrc := oIni.ReadString(sVal, '!SourceFile', '');
                 if (sSrc <> '') then
                     sMod := sMod + ' (' + sSrc + ')';

                 if oIni.ReadBool(sVal, '!ReplaceFile', false) then
                     sReplace := LS_GUI_REPOVERWRITE
                 else
                     sReplace := LS_GUI_REPMODIFY;

                 sDest := LS_GUI_REPLOCATION + ': ' + oIni.ReadString(sVal, '!Destination', 'override');
                 txtInfo.Lines.Add(' * ' + sMod + ' - ' + sReplace + ', ' + sDest);
             end;
         end;
         oList.free();


         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         // ADDED(2006-09-14) Display HACK-list operations as well...
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPHACKTITLE + ':');
         txtInfo.Lines.Add('-----------------------');

         oList := TStringList.Create();
         oIni.ReadSection('HACKList', oList);

         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (' + LS_GUI_REPNONE + ')  ');
         end
         else begin
             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('HACKList', sKey, '');
                 sMod := oIni.ReadString(sVal, '!SaveAs', sVal);
                 iMod := oIni.ReadInteger(sVal, 'ReplaceFile', 0);

                 if (iMod = 1) then
                     sReplace := LS_GUI_REPOVERWRITE
                 else
                     sReplace := LS_GUI_REPSKIP;

                 if (sMod = '') then
                     sMod := sVal;

                 sSrc := oIni.ReadString(sVal, '!SourceFile', '');
                 if (sSrc <> '') then
                     sMod := sMod + ' (' + sSrc + ')';

                 sDest := LS_GUI_REPLOCATION + ': override';
                 txtInfo.Lines.Add(' * ' + sMod + ' - ' + sReplace + ', ' + sDest);
             end;
         end;
         oList.free();


         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPCOMPILETITLE + ':');
         txtInfo.Lines.Add('------------------------------');

         oList := TStringList.Create();
         oIni.ReadSection('CompileList', oList);

         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (' + LS_GUI_REPNONE + ')  ');
         end
         else begin
              // FIX(2006-09-30) Use the DefaultDestination value instead of a hardcoded
              // 'override' if no !Destination key exists.
             sDefDest := oIni.ReadString('CompileList', '!DefaultDestination', 'override');

             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('CompileList', sKey, '');
                 sMod := oIni.ReadString(sVal, '!SaveAs', sVal);
                 if (sMod = '') then
                     sMod := sVal;

                 // FIX(2006-09-28) This key is not a file, do not list it.
                 if (lowercase(sKey) = '!defaultdestination') then
                     continue;

                 // ADDED(2006-09-14) Show name of source file if applicable
                 sSrc := oIni.ReadString(sVal, '!SourceFile', '');
                 if (sSrc <> '') then
                     sMod := sMod + ' (' + sSrc + ')';

                 if (lowercase(copy(sKey, 1, 7)) = 'replace') then
                     sReplace := LS_GUI_REPOVERWRITE
                 else
                     sReplace := LS_GUI_REPSKIP;

                 // FIX(2006-09-30) Use the DefaultDestination value instead of a hardcoded
                 // 'override' if no !Destination key exists.
                 sDest := LS_GUI_REPLOCATION + ': ' + oIni.ReadString(sVal, '!Destination', sDefDest);
                 txtInfo.Lines.Add(' * ' + sMod + ' - ' + sReplace + ', ' + sDest);
             end;
         end;
         oList.free();


         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPSSFTITLE + ':');
         txtInfo.Lines.Add('----------------------------');

         oList := TStringList.Create();
         oIni.ReadSection('SSFList', oList);
         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (' + LS_GUI_REPNONE + ')  ');
         end
         else begin
             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('SSFList', sKey, '');
                 sMod := oIni.ReadString(sVal, '!SaveAs', sVal);
                 if (sMod = '') then
                     sMod := sVal;

                 // ADDED(2006-09-14) Show name of source file if applicable
                 sSrc := oIni.ReadString(sVal, '!SourceFile', '');
                 if (sSrc <> '') then
                     sMod := sMod + ' (' + sSrc + ')';

                 if (lowercase(copy(sKey, 1, 7)) = 'replace') then
                     sReplace := LS_GUI_REPOVERWRITE
                 else
                     sReplace := LS_GUI_REPMODIFY;

                 sDest := LS_GUI_REPLOCATION + ': override';
                 txtInfo.Lines.Add(' * ' + sVal + ' - ' + sReplace + ', ' + sDest);
             end;
         end;
         oList.free();


         // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add('');
         txtInfo.Lines.Add(LS_GUI_REPINSTALLSTART + ':');
         txtInfo.Lines.Add('---------------------------');

         oList := TStringList.Create();
         oIni.ReadSection('InstallList', oList);

         if (oList.count < 1) then begin
             txtInfo.Lines.Add('  (none)  ');
         end
         else begin
             for i := 0 to (oList.count-1) do begin
                 sKey := oList[i];
                 sVal := oIni.ReadString('InstallList', sKey, '');

                 // FIX(2006-09-14) Show more user-friendly game folder name...
                 if (sVal = '.\') then
                     txtInfo.Lines.Add(' * ' + LS_GUI_REPINSTALLLOC + ': ' + LS_GUI_REPGAMEFOLDER)
                 else
                     txtInfo.Lines.Add(' * ' + LS_GUI_REPINSTALLLOC + ': ' + sVal);

                 oMods := TStringList.Create();
                 oIni.ReadSection(sKey, oMods);
                 for n := 0 to (oMods.count-1) do begin
                     sReplace := oMods[n];
                     sMod := oIni.ReadString(sKey, sReplace, '');
                     sFile := oIni.ReadString(sMod, '!SaveAs', sMod);
                     if (sFile = '') then
                         sFile := sMod;

                     // ADDED(2006-09-14) Show name of source file if applicable
                     sSrc := oIni.ReadString(sVal, '!SourceFile', '');
                     if (sSrc <> '') then
                         sMod := sMod + ' (' + sSrc + ')';

                     if (lowercase(copy(sReplace, 1, 7)) = 'replace') then
                         sReplace := LS_GUI_REPOVERWRITE
                     else
                         sReplace := LS_GUI_REPSKIP;

                     txtInfo.Lines.Add('   --> ' + sFile + ' - ' + sReplace);
                 end;
                 oMods.free();
                 txtInfo.Lines.Add('');
             end;
         end;
         oList.free();
    finally
        if (oIni <> nil) then
            oIni.free();
    end;
end;

procedure TMainForm.btnSummaryClick(Sender: TObject);
begin
    if not bSummary then begin
        bSummary := true;
        txtInfo.clear();
        txtInfo.Lines.Clear();
        ShowSummary();
    end
    else begin
        bSummary := false;
        txtInfo.clear();
        txtInfo.Lines.Clear();
        txtInfo.wordwrap := True;
        txtInfo.lines.LoadFromFile(sDataPath + sInfoFile);        
    end;
end;

end.

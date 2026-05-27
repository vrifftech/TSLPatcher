// =============================================================================
// Stoffe's Common Generic Utility Functions unit
// =============================================================================
// Last changed: 2006-05-17 (MKB)
// Version:      2.0
// -----------------------------------------------------------------------------
unit UST_Common;

interface

uses Graphics, Classes;  // Must put this here since two functions return TIcon objects.

// Popup boxes showing text to the user and returning button pressed.
function ShowAlertBox(sMessage : string) : word;
function ShowInfoBox(sMessage : string) : word;
function ShowConfirmBox(sMessage : string) : word;

// Check if a string can safely be converted to an Integer or Float.
function GetIsNumber(sStr : string) : boolean;
function GetIsNumberSigned(sStr : string) : boolean;
function GetIsFloat(sStr : string) : boolean;

// Wrapper converter functions with some extra checks...
function SafeStrToDouble(sStr : string) : Double;
function SafeStrToFloat(sStr : string) : Single;
function SafeStrToInt(const S : string) : Integer;

// Browse Folder dialog, since Delphi has no component for this for some reason.
function OpenFolderDialog(const sTitle: string; const iFlags: integer = 0): string;

// Ugly bruteforce method for replacing a substring within another string.
function ReplaceInString(sSource, sFind, sReplace : string ) : string;

// Run an external application and return the StdOut output from it.
function RunShellGetOutput(sExecutable : String; sParameters : string; sWork : string) : string;

// Remove the ReadOnly checkbox for a file.
procedure MakeFileWritable(sFilename : string);
function GetFileIsWriteProtected(sFilename : string) : boolean;

// This should have been named CopyFile(). Both parameters are path+name.
procedure BackupFile(const sFilename, sNewfile: string);

// Get the path to some special Windows folders.
function GetWindowsDir: string;
function GetTempDir: string;
function GetSystemDir: string;

// Delete a folder along with any subfolders it contains.
function DeleteFolder(sFolder : string; bRecursive : boolean = false) : boolean;

// Retrieve a string list with the names of all files in the specified folder.
function GetFilesInFolder(sFolder : string; bNameOnly : boolean = true) : TStringList;

// Get the Windows explorer icons associated with special file types.
function GetFileTypeSmallIcon(sFilename : string) : TIcon;
function GetFileTypeLargeIcon(sFilename : string) : TIcon;

function GetFileSizeString(iBytes : integer) : string;
function StringToResRef(sText : string) : string;

function GetRegistryString(sKeyName: string; sValue : string): string;

implementation

uses Dialogs, Forms, SysUtils, Windows, ShellAPI, ShlObj, Registry;

type PHICON = ^HICON;

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function ShowAlertBox(sMessage : string) : word;
begin
     result := MessageDlg(sMessage, mtWarning, [mbOK], 0);
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function ShowInfoBox(sMessage : string) : word;
begin
     result := MessageDlg(sMessage, mtInformation, [mbOK], 0);
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function ShowConfirmBox(sMessage : string) : word;
begin
     result := MessageDlg(sMessage, mtConfirmation, [mbYes, mbNo], 0);
end;


// -----------------------------------------------------------------------------
// UTILITY: Check if the string can be converted to an Unsigned Integer.
// -----------------------------------------------------------------------------
function GetIsNumber(sStr : string) : boolean;
var
   i       : integer;
begin
     for i := 1 to Length(sStr) do begin
         if not (sStr[i] in ['0'..'9']) then begin
            result := false;
            exit;
         end;
     end;

     if (Length(sStr) > 0) then
        result := true
     else
        result := false;
end;


// -----------------------------------------------------------------------------
// UTILITY: Check if the string can be converted to a Signed Integer.
// -----------------------------------------------------------------------------
function GetIsNumberSigned(sStr : string) : boolean;
var
   i       : integer;
begin
     if (Length(sStr) <= 0) then begin
         result := false;
         exit;
     end;

     if not (sStr[1] in ['0'..'9', '-']) then begin
         result := false;
         exit;
     end;

     for i := 2 to Length(sStr) do begin
         if not (sStr[i] in ['0'..'9']) then begin
            result := false;
            exit;
         end;
     end;

     result := true;
end;


// -----------------------------------------------------------------------------
// UTILITY: Make the file with the specified name Writable if it is flagged
//          as ReadOnly in Windows.
// -----------------------------------------------------------------------------
procedure MakeFileWritable(sFilename : string);
var
   nFlags : Word;
begin
    if (SysUtils.FileExists(sFilename)) then begin
        nFlags := FileGetAttr(sFilename);
        if ((nFlags and faReadOnly) = faReadOnly) then begin
            nFlags := nFlags and not faReadOnly;
            FileSetAttr(sFilename, nFlags);
        end;
    end;
end;


// -----------------------------------------------------------------------------
// UTILITY: Check if the specified file is write protected in Windows.
// -----------------------------------------------------------------------------
function GetFileIsWriteProtected(sFilename : string) : boolean;
var
   nFlags : Word;
begin
    result := false;
    if (SysUtils.FileExists(sFilename)) then begin
        nFlags := FileGetAttr(sFilename);
        result := ((nFlags and faReadOnly) = faReadOnly);
    end;
end;


// -----------------------------------------------------------------------------
// UTILITY: Make a backup copy of the specified file and save it at the path
//          and with the name specified by the second parameter.
//
//          In a stroke of pure genius I didn't name this "CopyFile()" which
//          is what it essentially does, and it's too late to change now. :/
// -----------------------------------------------------------------------------
procedure BackupFile(const sFilename, sNewfile: string);
var
  inFile  : TFileStream;
  outFile : TFileStream;
begin
    inFile := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyNone);
    try
        outFile := TFileStream.Create(sNewfile, fmCreate);
        try
            outFile.CopyFrom(inFile, 0);
        finally
            outFile.Free;
        end;
    finally
        inFile.Free;
    end;
end;


// -----------------------------------------------------------------------------
// CALLBACK FUNCTION for OpenFolderDialog(). Do NOT call directly.
// -----------------------------------------------------------------------------
function OpenFolderSetup(Wnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): integer stdcall;
var
   oArea  : TRect;
   oRect  : TRect;
   oDlgPt : TPoint;
begin
    // Center the Dialog box on the desktop...
    if (uMsg = BFFM_INITIALIZED) then begin
        oArea.top    := Screen.DesktopTop;
        oArea.left   := Screen.DesktopLeft;
        oArea.bottom := Screen.DesktopTop + Screen.DesktopHeight;
        oArea.right  := Screen.DesktopLeft + Screen.DesktopWidth;

        GetWindowRect(Wnd, oRect);

        oDlgPt.X := ((oArea.Right-oArea.Left) div 2) - ((oRect.Right-oRect.Left) div 2);
        oDlgPt.Y := ((oArea.Bottom-oArea.Top) div 2) - ((oRect.Bottom-oRect.Top) div 2);

        MoveWindow(Wnd, oDlgPt.X, oDlgPt.Y, oRect.Right - oRect.Left, oRect.Bottom - oRect.Top, True);
    end;

    Result := 0;
end;



// -----------------------------------------------------------------------------
// Wrapper for Win32API OpenFolder dialog box, since no Delphi component seems
// to exist for it in this version of Delphi.
// -----------------------------------------------------------------------------
function OpenFolderDialog(const sTitle: string; const iFlags: integer = 0): string;
var
   lpItemID   : PItemIDList;
   BrowseInfo : TBrowseInfo;
   sName      : array[0..MAX_PATH] of char;
   sPath      : array[0..MAX_PATH] of char;
begin
    FillChar(BrowseInfo, sizeof(TBrowseInfo), #0);

    with BrowseInfo do begin
        hwndOwner      := Application.Handle;
        pszDisplayName := @sName;
        lpszTitle      := PChar(sTitle);
        ulFlags        := iFlags;
        lpfn           := OpenFolderSetup;
    end;

    lpItemID := SHBrowseForFolder(BrowseInfo);

    if (lpItemId <> nil) then begin
        SHGetPathFromIDList(lpItemID, sPath);
        GlobalFreePtr(lpItemID);
        Result := sPath;
    end
    else begin
        Result:='';
    end;
end;


// -----------------------------------------------------------------------------
// Wrapper for Win32API functionality for running an external console
// application, capture its StdOut output and wait for it to finish before
// proceeding, returning any output as function value.
// Executable = path&name of application to run
// Parameter = Commandline parameters to send to the application when calling it.
// -----------------------------------------------------------------------------
function RunShellGetOutput(sExecutable : String; sParameters : string; sWork : string) : string;
const
    ReadBuffer = 2400;   
var
    oSecurity       : TSecurityAttributes;
    oReadPipe       : THandle;
    oWritePipe      : THandle;
    oStartInfo      : TStartUpInfo;
    oProcessInfo    : TProcessInformation;
    sBuffer         : Pchar;
    iBytesRead      : DWord;
    iApprunning     : DWord;
    sResult         : string;
    sCmdLine        : String;
begin
    result := '';
    sResult := '';

    // If name is shorter than x.exe its not a valid EXE name, no point in continuing.
    if (Length(sExecutable) < 5) then
       exit;

    // The commandline consists of at least the ExeName&path....
    // FIX(2006-03-18) Apply enclosing quotation marks at the commandline instead
    // of getting them in the parameter. The quotation marks were causing trouble
    // with the ChDir function under Windows98 and 2000, since ExtractFilePath
    // stripped the trailing one but not the leading one.
    sCmdLine := '"' + sExecutable + '"';

    // If parameters are specified, append them to the commandline...
    if (Length(sParameters) > 0) then
        sCmdLine := sCmdLine + ' ' + sParameters;

    // Fill arcane Struct needed for Win32API calls with necessary info... :/
    with oSecurity do begin
        nLength                 := sizeof(TSecurityAttributes);
        bInheritHandle          := true;
        lpSecurityDescriptor    := nil;
    end;
   
    if Createpipe(oReadPipe, oWritePipe, @oSecurity, 0) then begin
        sBuffer := AllocMem(ReadBuffer + 1);
        FillChar(oStartInfo, sizeof(oStartInfo), #0);

        try
            // Fill arcane Struct needed for Win32API calls with necessary info... :/
            with oStartInfo do begin
                cb          := SizeOf(oStartInfo);
                hStdOutput  := oWritePipe;
                hStdInput   := oReadPipe;
                dwFlags     := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW;
                wShowWindow := SW_HIDE; // SW_SHOWNORMAL
            end;

            // ADDED(2006-02-05) Set the current folder to the folder the application is run from...
            // CHANGED(2006-04-29) Made it an optional parameter to set the working folder...
            if (Length(sWork) < 1) or not SysUtils.DirectoryExists(sWork) then begin
               sWork := ExtractFilePath(sExecutable);
            end;

            System.ChDir(sWork);

            // Start the application...
            if CreateProcess(nil, PChar(sCmdLine), @oSecurity, @oSecurity, true, NORMAL_PRIORITY_CLASS, nil, nil, oStartInfo, oProcessInfo) then begin
                // Wait for the application to finish....
                repeat
                    iApprunning := WaitForSingleObject(oProcessInfo.hProcess, 100);
                    Application.ProcessMessages;
                until (iApprunning <> WAIT_TIMEOUT) and (iApprunning <> STILL_ACTIVE);

                // Read the output from the pipe and put in the result string...
                repeat
                    iBytesRead := 0;
                    ReadFile(oReadPipe, sBuffer[0], ReadBuffer,iBytesRead, nil);
                    sBuffer[iBytesRead]:= #0;
                    OemToAnsi(sBuffer, sBuffer);
                    sResult := sResult + String(sBuffer);
                until (iBytesRead < ReadBuffer);

                // Clean set functio result and clean up...
                result := sResult;
                CloseHandle(oProcessInfo.hProcess);
                CloseHandle(oProcessInfo.hThread);
            end
            else begin
                raise EFOpenError.CreateHelp('Unable to start program ' + sExecutable + '!' , 1);
            end;
        finally
            // Free used resources...
            FreeMem(sBuffer);
            CloseHandle(oReadPipe);
            CloseHandle(oWritePipe);
        end;
    end;
end;



// -----------------------------------------------------------------------------
// UTILITY: Check if the supplied string can be converted to a decimal number.
// -----------------------------------------------------------------------------
function GetIsFloat(sStr : string) : boolean;
var
   i       : integer;
begin
     if (Length(sStr) <= 0) then begin
         result := false;
         exit;
     end;

     if not (sStr[1] in ['0'..'9', '-']) then begin
         result := false;
         exit;
     end;

     for i := 2 to (Length(sStr) - 1) do begin
         if not (sStr[i] in ['0'..'9', '.', ',']) then begin
            result := false;
            exit;
         end;
     end;

     if not (sStr[Length(sStr)] in ['0'..'9']) then begin
         result := false;
         exit;
     end;

     result := true;
end;


// -----------------------------------------------------------------------------
// UTILITY: Convert string to a Float if possible, accepting both comma and
//          period as valid decimal separators.
// -----------------------------------------------------------------------------
function SafeStrToFloat(sStr : string) : Single;
begin
    if not GetIsFloat(sStr) then begin
        result := 0.0;
        exit;
    end;

    if (DecimalSeparator = ',') then begin
        if (Pos('.', sStr) > 0) then
            sStr[Pos('.', sStr)] := ',';
    end
    else if (DecimalSeparator = '.') then begin
        if (Pos(',', sStr) > 0) then
            sStr[Pos(',', sStr)] := '.';
    end;

    result := StrToFloat(sStr);
end;


// -----------------------------------------------------------------------------
// UTILITY: Convert string to a Float if possible, accepting both comma and
//          period as valid decimal separators.
// -----------------------------------------------------------------------------
function SafeStrToDouble(sStr : string) : Double;
begin
    if not GetIsFloat(sStr) then begin
        result := 0.0;
        exit;
    end;

    if (DecimalSeparator = ',') then begin
        if (Pos('.', sStr) > 0) then
            sStr[Pos('.', sStr)] := ',';
    end
    else if (DecimalSeparator = '.') then begin
        if (Pos(',', sStr) > 0) then
            sStr[Pos(',', sStr)] := '.';
    end;

    result := StrToFloat(sStr);
end;


// -----------------------------------------------------------------------------
// Utility function for replacing substrings within a string with another
// string.
// sSource = The original string to operate on.
// sFind   = The substring that should be replaced.
// sReplace = The new string that will be inserted in place of sFind.
//
// Returns: The modified string.
// -----------------------------------------------------------------------------
function ReplaceInString(sSource, sFind, sReplace : string ) : string;
var
   iPos, lPos : integer;
   
	function EgenPos( substr, str : string; startval : integer ) : integer;
	var temp : string;
	    iPos : integer;
	begin
	     startval := startval + 1;
	     if (Length(str)-startval > 0) then
	     begin
	          temp := Copy(str, startval, (Length(str)-startval)+1 );
	          iPos := pos(substr, temp);
	          if iPos > 0 then
	             result := startval + (iPos-1)
	          else
	              result := 0;
	     end
	     else
	         result := 0;
	end;
begin
     lPos := 1;
     repeat
       iPos := EgenPos(sFind, sSource, lPos);
       lPos := iPos;
       if iPos > 0 then
          sSource := copy(sSource, 1, iPos-1) + sReplace +
                    copy(sSource, iPos+Length(sFind), Length(sSource)-(iPos-1+Length(sFind)))
     until iPos = 0;
     result := sSource;
end;



// -----------------------------------------------------------------------------
// Return the path to the Windows system directory (ROOT\Windows\System32)
// -----------------------------------------------------------------------------
function GetSystemDir: string;
begin;
	SetLength(Result, MAX_PATH);
	SetLength(Result, GetSystemDirectory((PChar(Result)), MAX_PATH));
end;


// -----------------------------------------------------------------------------
// Return the path to the Windows TEMP directory
// -----------------------------------------------------------------------------
function GetTempDir: string;
begin;
	SetLength(Result, MAX_PATH);
	SetLength(Result, GetTempPath(MAX_PATH, (PChar(Result))));
end;


// -----------------------------------------------------------------------------
// Return the path to the Windows directory (ROOT\Windows)
// -----------------------------------------------------------------------------
function GetWindowsDir: string;
begin;
	SetLength(Result, MAX_PATH);
	SetLength(Result, GetWindowsDirectory(PChar(Result), MAX_PATH));
end;


// -----------------------------------------------------------------------------
// Nasty Win32API-using function for getting the icons associated with a
// particular type of file. Use the wrappers below instead.
// -----------------------------------------------------------------------------
procedure GetAssociatedIcon(FileName: TFilename; PLargeIcon, PSmallIcon: PHICON);
// Gets the icons of a given file
var
  IconIndex: UINT;  // Position of the icon in the file
  FileExt, FileType: string;
  Reg: TRegistry;
  p: integer;
  p1, p2: pchar;
label
  noassoc;
begin
  IconIndex := 0;
  // Get the extension of the file
  FileExt := UpperCase(ExtractFileExt(FileName));
  if ((FileExt <> '.EXE') and (FileExt <> '.ICO')) or
      not FileExists(FileName) then begin
    // If the file is an EXE or ICO and it exists, then
    // we will extract the icon from this file. Otherwise
    // here we will try to find the associated icon in the
    // Windows Registry...
    Reg := nil;
    try
      Reg := TRegistry.Create(KEY_QUERY_VALUE);
      Reg.RootKey := HKEY_CLASSES_ROOT;
      if FileExt = '.EXE' then FileExt := '.COM';
      if Reg.OpenKeyReadOnly(FileExt) then
        try
          FileType := Reg.ReadString('');
        finally
          Reg.CloseKey;
        end;
      if (FileType <> '') and Reg.OpenKeyReadOnly(FileType + '\DefaultIcon') then
        try
          FileName := Reg.ReadString('');
        finally
          Reg.CloseKey;
        end;
    finally
      Reg.Free;
    end;

    // If we couldn't find the association, we will
    // try to get the default icons
    if FileName = '' then goto noassoc;

    // Get the filename and icon index from the
    // association (of form '"filaname",index')
    p1 := PChar(FileName);
    p2 := StrRScan(p1, ',');
    if p2 <> nil then begin
      p := p2 - p1 + 1; // Position of the comma
      IconIndex := StrToInt(Copy(FileName, p + 1, Length(FileName) - p));
      SetLength(FileName, p - 1);
    end;
  end;
  // Attempt to get the icon
  if ExtractIconEx(pchar(FileName), IconIndex, PLargeIcon^, PSmallIcon^, 1) <> 1 then
  begin
noassoc:
    // The operation failed or the file had no associated
    // icon. Try to get the default icons from SHELL32.DLL

    try // to get the location of SHELL32.DLL
      FileName := IncludeTrailingPathDelimiter(GetSystemDir) + 'SHELL32.DLL';
    except
      FileName := 'C:\WINDOWS\SYSTEM\SHELL32.DLL';
    end;
    // Determine the default icon for the file extension
    if      (FileExt = '.DOC') then IconIndex := 1
    else if (FileExt = '.EXE')
         or (FileExt = '.COM') then IconIndex := 2
    else if (FileExt = '.HLP') then IconIndex := 23
    else if (FileExt = '.INI')
         or (FileExt = '.INF') then IconIndex := 63
    else if (FileExt = '.TXT') then IconIndex := 64
    else if (FileExt = '.BAT') then IconIndex := 65
    else if (FileExt = '.DLL')
         or (FileExt = '.SYS')
         or (FileExt = '.VBX')
         or (FileExt = '.OCX')
         or (FileExt = '.VXD') then IconIndex := 66
    else if (FileExt = '.FON') then IconIndex := 67
    else if (FileExt = '.TTF') then IconIndex := 68
    else if (FileExt = '.FOT') then IconIndex := 69
    else IconIndex := 0;
    // Attempt to get the icon.
    if ExtractIconEx(pchar(FileName), IconIndex, PLargeIcon^, PSmallIcon^, 1) <> 1 then
    begin
      // Failed to get the icon. Just "return" zeroes.
      if PLargeIcon <> nil then PLargeIcon^ := 0;
      if PSmallIcon <> nil then PSmallIcon^ := 0;
    end;
  end;
end;


// -----------------------------------------------------------------------------
// Wrapper function for returning the small icon associated with a specific
// file type in Windows Explorer.
// -----------------------------------------------------------------------------
function GetFileTypeSmallIcon(sFilename : string) : TIcon;
var
   oHIcon  : HIcon;
begin
    result := TIcon.Create();
    GetAssociatedIcon(sFilename, nil, @oHIcon);
    result.Handle := oHIcon;
end;


// -----------------------------------------------------------------------------
// Wrapper function for returning the large icon associated with a specific
// file type in Windows Explorer.
// -----------------------------------------------------------------------------
function GetFileTypeLargeIcon(sFilename : string) : TIcon;
var
   oHIcon  : HIcon;
begin
    result := TIcon.Create();
    GetAssociatedIcon(sFilename, @oHIcon, nil);
    result.Handle := oHIcon;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function GetFileSizeString(iBytes : integer) : string;
var
   sSuffix : string;
begin
    sSuffix := 'byte';

    if (iBytes > 1024) then begin
        iBytes := iBytes div 1024;
        sSuffix := 'kB';
    end;

    result := IntToStr(iBytes) + ' ' + sSuffix;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function StringToResRef(sText : string) : string;
var
   i    : integer;
   iMax : integer;
   sOut : string;
begin
    sOut := '';

    iMax := Length(sText);
    if (iMax > 16) then
        iMax := 16;

    // Enforce ResRef format (16 characters, alphanumerical, lowercase)
    for i := 1 to iMax do begin
        if (sText[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then begin
            sOut := sOut + sText[i];
        end;
    end;

    result := sOut;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function DeleteFolder(sFolder : string; bRecursive : boolean = false) : boolean;
var
   iRes : integer;
   oSearch : TSearchRec;
begin
    sFolder := IncludeTrailingPathDelimiter(sFolder);

    // Failsafe, prevent deleting from the root folders....
    if (Length(sFolder) < 5) or (not SysUtils.DirectoryExists(sFolder)) then begin
        result := false;
        exit;
    end;

    iRes := SysUtils.FindFirst(sFolder + '*.*', faAnyFile, oSearch);
    while (iRes = 0) do begin
        if ((oSearch.Attr and faDirectory) = 0) then begin
            SysUtils.DeleteFile(sFolder + oSearch.Name);
        end
        else if bRecursive and (oSearch.Name <> '.') and (oSearch.Name <> '..') then begin
            DeleteFolder(sFolder + oSearch.Name, bRecursive);
        end;

        iRes := SysUtils.FindNext(oSearch);
    end;

    SysUtils.FindClose(oSearch);
    result := SysUtils.RemoveDir(sFolder);
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function GetFilesInFolder(sFolder : string; bNameOnly : boolean = true) : TStringList;
var
   oRes : integer;
   oSearch : TSearchRec;
   oList   : TStringList;
begin
    sFolder := IncludeTrailingPathDelimiter(sFolder);

    oList := TStringList.Create();
    oRes := SysUtils.FindFirst(sFolder + '*.*', faAnyFile, oSearch);
    while (oRes = 0) do begin
        if ((oSearch.Attr and faDirectory) = 0) then begin
            if bNameOnly then
                oList.Add(oSearch.Name)
            else
                oList.Add(sFolder + oSearch.Name);
        end;

        oRes := SysUtils.FindNext(oSearch);
    end;

    result := oList;
end;


// -----------------------------------------------------------------------------
// Reads a string value from the HKEY_LOCAL_MACHINE root in the Registry.
// -----------------------------------------------------------------------------
function GetRegistryString(sKeyName: string; sValue : string): string;
var
  oRegistry: TRegistry;
begin
  oRegistry := TRegistry.Create(KEY_READ);
  try
    oRegistry.RootKey := HKEY_LOCAL_MACHINE;
    oRegistry.OpenKey(sKeyName, False);
    Result := oRegistry.ReadString(sValue);
  finally
    oRegistry.Free;
  end;
end;


// -----------------------------------------------------------------------------
// Workaround since Delphi seems to have some weird bug where it won't convert
// the max-value of a DWORD if it's specified in decimal notation, but appear
// to accept it if it's in HexaDecimal, in the StrToInt() function.
// -----------------------------------------------------------------------------
function SafeStrToInt(const S : string) : Integer;
begin
    if (S = '4294967295') then
        result := StrToInt('$FFFFFFFF')
    else
        result := StrToInt(S);
end;


end.
 
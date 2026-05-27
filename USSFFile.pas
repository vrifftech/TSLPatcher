unit USSFFile;
// =============================================================================
// CLASS FOR READING/WRITING SSF V1.1 FILES (KotOR/TSL Soundset files)
// -----------------------------------------------------------------------------
// Last changed: 2006-03-05
// Version:      1.0a
// -----------------------------------------------------------------------------

interface

uses
    Windows, SysUtils, classes, UST_Common;

type
    T4Char  = array[0..3] of Char;
    ESSFError = class(Exception);

    TSSFFile = class(TObject)
    private
        f_labels  : array [1..40] of string;
        f_entries : array [1..40] of DWORD;

        f_ssffile : string;
        f_loaded  : boolean;

        procedure SetupLabels();
        procedure SetValue(const sLabel : string; iStrRef : DWORD);
        function GetValue(const sLabel : string) : DWORD;
        function GetLabel(iIdx : integer) : string;
    public
        procedure Load(sFilename : string);
        procedure Save(sFilename : string = '');
        procedure New(sFilename : string);
        procedure Reset();

        constructor Create(); overload;
        constructor Create(sFilename : string); overload;
        destructor Destroy(); override;

        property Entries[const sLabel : string] : DWORD   read GetValue    write SetValue;
        property Labels[iIdx : integer]         : string  read GetLabel;
    end;

implementation

// -----------------------------------------------------------------------------
// Standard constructor
// -----------------------------------------------------------------------------
constructor TSSFFile.Create();
begin
    inherited Create();
    SetupLabels();
    Reset();
end;


// -----------------------------------------------------------------------------
// Constructor loading the specified file.
// -----------------------------------------------------------------------------
constructor TSSFFile.Create(sFilename : string);
begin
    inherited Create();
    SetupLabels();
    Reset();
    Load(sFilename);
end;


// -----------------------------------------------------------------------------
// Destructor.
// -----------------------------------------------------------------------------
destructor TSSFFile.Destroy();
begin
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Create an array with the entry label values corresponding to the entry in
// the f_entries array with the same index.
// -----------------------------------------------------------------------------
procedure TSSFFile.SetupLabels();
begin
    f_labels[1] := 'Battlecry 1';
    f_labels[2] := 'Battlecry 2';
    f_labels[3] := 'Battlecry 3';
    f_labels[4] := 'Battlecry 4';
    f_labels[5] := 'Battlecry 5';
    f_labels[6] := 'Battlecry 6';
    f_labels[7] := 'Selected 1';
    f_labels[8] := 'Selected 2';
    f_labels[9] := 'Selected 3';
    f_labels[10] := 'Attack 1';
    f_labels[11] := 'Attack 2';
    f_labels[12] := 'Attack 3';
    f_labels[13] := 'Pain 1';
    f_labels[14] := 'Pain 2';
    f_labels[15] := 'Low health';
    f_labels[16] := 'Death';
    f_labels[17] := 'Critical hit';
    f_labels[18] := 'Target immune';
    f_labels[19] := 'Place mine';
    f_labels[20] := 'Disarm mine';
    f_labels[21] := 'Stealth on';
    f_labels[22] := 'Search';
    f_labels[23] := 'Pick lock start';
    f_labels[24] := 'Pick lock fail';
    f_labels[25] := 'Pick lock done';
    f_labels[26] := 'Leave party';
    f_labels[27] := 'Rejoin party';
    f_labels[28] := 'Poisoned';
    f_labels[29] := 'Unknown(29)';
    f_labels[30] := 'Unknown(30)';
    f_labels[31] := 'Unknown(31)';
    f_labels[32] := 'Unknown(32)';
    f_labels[33] := 'Unknown(33)';
    f_labels[34] := 'Unknown(34)';
    f_labels[35] := 'Unknown(35)';
    f_labels[36] := 'Unknown(36)';
    f_labels[37] := 'Unknown(37)';
    f_labels[38] := 'Unknown(38)';
    f_labels[39] := 'Unknown(39)';
    f_labels[40] := 'Unknown(40)';
end;


// -----------------------------------------------------------------------------
// Resets any SSF file data loaded into this object.
// -----------------------------------------------------------------------------
procedure TSSFFile.Reset();
var
   i : integer;
begin
   for i := 1 to 40 do begin
       f_entries[i] := $FFFFFFFF;
   end;

   f_ssffile := '';
   f_loaded := false;
end;


// -----------------------------------------------------------------------------
// Creates a new blank SSF file in this object.
// -----------------------------------------------------------------------------
procedure TSSFFile.New(sFilename : string);
begin
    Reset();
    f_ssffile := sFilename;
    f_loaded  := true;
end;


// -----------------------------------------------------------------------------
// Loads a SFF file into this class.
// -----------------------------------------------------------------------------
procedure TSSFFile.Load(sFilename : string);
var
   inFile     : TFileStream;
   FileType   : T4Char;
   FileVersion: T4Char;
   StartOffset: DWORD;
   intBuff    : DWORD;
   i          : integer;
begin
     Reset();

     if not SysUtils.FileExists(sFilename) then begin
         raise ESSFError.CreateHelp('Selected file "' + sFilename + '" does not exist! Unable to load it.', 5);
     end;

     f_ssffile := sFilename;
     inFile := TFileStream.Create(f_ssffile, fmOpenRead or fmShareDenyWrite);
     try
        inFile.Read(FileType, sizeof(FileType));
        inFile.Read(FileVersion, sizeof(FileVersion));
        inFile.Read(StartOffset, sizeof(StartOffset));

        if (FileType <> 'SSF ') or (FileVersion <> 'V1.1') then begin
           raise ESSFError.CreateHelp('Selected file "' + sFilename + '" is not a valid SSF v1.1 file!', 1);
        end;

        inFile.Seek(StartOffset, soFromBeginning);

        for i := 1 to 40 do begin
            inFile.Read(intBuff, sizeof(intBuff));
            f_entries[i] := intBuff;
        end;

        f_loaded := true;
     finally
        inFile.free();
     end;
end;


// -----------------------------------------------------------------------------
// Saves the SSF file currently loaded in this class.
// -----------------------------------------------------------------------------
procedure TSSFFile.Save(sFilename : string = '');
var
   outFile : TFileStream;
   intBuf  : DWORD;
   i       : integer;
begin
    if not f_loaded then begin
        raise ESSFError.CreateHelp('No file has been loaded! Unable to save.', 6);
    end;

    if (sFilename <> '') then begin
        f_ssffile := sFilename;
    end;

    MakeFileWritable(f_ssffile);

    outFile := TFileStream.Create(f_ssffile, fmCreate or fmShareDenyWrite);
    try
        outFile.write('SSF ', 4);
        outFile.write('V1.1', 4);

        intBuf := 12;
        outFile.write(intBuf, sizeof(intBuf));

        for i := 1 to 40 do begin
            intBuf := f_entries[i];
            outFile.write(intBuf, sizeof(intBuf));
        end;
    finally
        outFile.free();
    end;
end;


// -----------------------------------------------------------------------------
// Changes the value of one of the entries, identified by its label.
// -----------------------------------------------------------------------------
procedure TSSFFile.SetValue(const sLabel : string; iStrRef : DWORD);
var
   i      : integer;
   bFound : boolean;
begin
    bFound := false;
    for i := 1 to 40 do begin
        if (lowercase(sLabel) = lowercase(f_labels[i])) then begin
            bFound := true;
            f_entries[i] := iStrRef;
        end;
    end;

    if not bFound then begin
        raise ESSFError.CreateHelp('Unable to change value in SSF file, label "' + sLabel + '" is not a valid entry label!', 2);
    end;
end;


// -----------------------------------------------------------------------------
// Returns the value of one of the entries, identified by its label.
// -----------------------------------------------------------------------------
function TSSFFile.GetValue(const sLabel : string) : DWORD;
var
   i      : integer;
   bFound : boolean;
begin
    result := $FFFFFFFF;
    bFound := false;

    for i := 1 to 40 do begin
        if (lowercase(sLabel) = lowercase(f_labels[i])) then begin
            bFound := true;
            result := f_entries[i];
        end;
    end;

    if not bFound then begin
        raise ESSFError.CreateHelp('Unable to read value in SSF file, label "' + sLabel + '" is not a valid entry label!', 3);
    end;
end;


// -----------------------------------------------------------------------------
// Get the label of a particular index in the entries array.
// -----------------------------------------------------------------------------
function TSSFFile.GetLabel(iIdx : integer) : string;
begin
    result := '';
    
    if (iIdx >= 1) and (iIdx <= 40) then begin
        result := f_labels[iIdx];
    end
    else begin
        raise ESSFError.CreateHelp('Label index out of bounds, it must be a value between 1 and 40.', 4);
    end;
end;


end.
 
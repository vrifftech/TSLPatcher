// =============================================================================
// CLASS FOR READING, HANDLING AND WRITING BIOWARE ERF V1.0 FORMAT FILES.
// =============================================================================
// Main class:   TERFHandler
// Last changed: 2006-08-23 (MKB)
// Version:      0.5a
// -----------------------------------------------------------------------------
// 2006-05-20 - * Added support for RIM format files, since they are similar
//                to the ERF format.
//
// 2006-08-09 - * Added IsValidArchive() static method to TERFHandler.
//
//              * Added support for renaming resources to different ResRefs than
//                the name of the source file in the AddResource() method.
//
// 2006-08-23 - * Hopefully fixed data read/write bug for RIM files that prevented
//                the game from reading them. Mixed up the offset of the ResID with
//                enveloping reserved WORDS, reading/writing the wrong bytes as ResID.
//                The RIM spec was apparently not entirely accurate. Nasty.
//
// Design idea:
// In order to conserve memory when HUGE ERF files (such as TexPacks) are
// loaded, don't load all the content data into memory directly. Only load file
// info data for all files, and then read the content data when that particular
// file is requested. Thus:
//
// * Load()... will open the file stream and read file descriptor data.
///  It will only load the file data and positional offset for all the
//   resources kept in the ERF file to save memory.
//   DO NOT CLOSE THE FILE STREAM HERE WHEN DONE READING!!
//   IF ANOTHER APP IS ALLOWED TO MESS WITH THE FILE CONTENT BETWEEN KEY LOAD
//   AND DATA RETRIEVAL THE OFFSETS MAY BE INVALID!!
//
// * GetRes()... will fetch the offset and size from the data loaded by the
//   load() call and read the File Data itself from the ERF file.
//
// * Save()... will fetch ALL resources and store them in a temp folder and
//   then write them back to the file (which will be rewritten from scratch)
//   and then delete the temp folder.
//
// * DelRes()... will remove the file info from the f_reslist array, causing
//   it not to be extracted and rewritten when Save() is done.
//
// * AddRes()... will add the path+filename of the selected file to the f_newlist
//   array. Files in this array will be copied to the temp dir when Save() is done
//   and subsequently written into the ERF file.
//
// * Reset() will close the FILE STREAM and free the f_header object and all objects
//   in the TERF_LocString and TERF_Resource arrays, which will then be reinitialized
//   to cell count 0. This method should be called from the DESTRUCTOR, from New()
//   and from Load() before reading the specified file.
//
// NOTE: This will cause serious trouble if some other application messes with the
//       file while it is open. Be careful when this class is used.
//
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TODO: The above is seriously stupid. Just store the "last changed" date of the file
// when loading it, then close it. When something needs to be read, check that the file dates
// match with the current ones. On save, update the File date stored. Then open the filestream
// again if all appears to be OK. Also copy files to temp folder when doing "AddResource" operation
// to prevent having to rely on everything still being where they were when added.
// DateTimeToStr(FileDateToDateTime(FileAge(FileList.FileName)));


unit UERFHandler;

interface

uses Windows, SysUtils, Classes, Forms, FileCtrl;

type
    T4Char         = array [0..3]   of Char;
    T16Char        = array [0..15]  of Char;
    THeaderNull    = array [0..115] of Byte;
    THeaderNullRIM = array [0..99] of Byte;

    TERFType = (erfMOD, erfHAK, erfERF, erfSAV, erfRIM);

    EERFError = class(Exception);
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Class for Resref data type. a Resref can be at most 16 characters long,
    // with unused characters NULL-padded. It is all lowercase and may only
    // contain alphanumerical characters.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_ResRef = class(TObject)
        private
            f_resref : T16Char;      // The ResRef data, 16 nullpadded characters.

            procedure SetResRef(sText : string);
            function GetResRef() : string;
        public
            constructor Create(); overload;
            constructor Create(sText : string); overload;
            destructor Destroy(); override;

            property text : string      read GetResref     write SetResref;
            property raw  : T16Char     read f_resref      write f_resref;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Abstract Superclass for the Header classes...
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_Header = class(TObject)
        filetype        : T4Char;      // Should be 'ERF ', 'HAK ', 'MOD ', 'SAV ', 'RIM '...
        version         : T4Char;      // Should always be 'V1.0'

        constructor Create();
        destructor Destroy(); override;
    end;

    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Class for holding ERF file header information used during loading and saving.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_ERFHeader = class(TERF_Header)
        locstringcount  : DWORD;       // Number of localized description strings.
        locstringsize   : DWORD;       // Byte size of localized string array.
        entrycount      : DWORD;       // Number of files this ERF archive contains...
        offsetlocstring : DWORD;       // Offset where localized string array starts.
        offsetkeylist   : DWORD;       // Offset where content key info array starts.
        offsetreslist   : DWORD;       // Offset where content data array starts.
        buildyear       : DWORD;       // Current year as number of years since 1900.
        buildday        : DWORD;       // Current day as number of days since January 1.
        locstringstrref : DWORD;       // Dialog.tlk StrRef for file description (if any).
        reserved        : THeaderNull; // 116 reserved NULL bytes in file...

        class procedure GetBuildTime(var iYear : WORD; var iDay : WORD);

        constructor Create();
        destructor Destroy(); override;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Class for holding RIM file header information used during loading and saving.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_RIMHeader = class(TERF_Header)
        unknown         : DWORD;          // Unknown data, those who know claims it to be unused.
        entrycount      : DWORD;          // Number of files this ERF archive contains...
        offsetkeylist   : DWORD;          // Offset where content key info array starts.
        reserved        : THeaderNullRIM; // 100 reserved NULL bytes in file...

        constructor Create();
        destructor Destroy(); override;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Localized string used for ERF file description.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_LocString = class(TObject)
        private
            f_languageid : DWORD;        // language id of this localized string
            f_stringsize : DWORD;        // number of characters this string is made up of.
            f_locstring  : string;       // the string text itself.

            procedure SetString(sText : string);
        public
            constructor Create(); overload;
            constructor Create(iLangID : DWORD; sText : string); overload;
            destructor Destroy(); override;

            property languageid : DWORD    read f_languageid    write f_languageid;
            property text       : string   read f_locstring     write SetString;
            property size       : DWORD    read f_stringsize    write f_stringsize;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Class holding info about a single file/resource in the ERF archive.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERF_Resource = class(TObject)
        private
            // Key info
            f_resref     : TERF_ResRef; // Filename without extension.
            f_resid      : DWORD;       // Resource ID number...
            f_restype    : WORD;        // Resource table ID determining file type.
            f_reserved   : WORD;        // Reserved/unused data in ERF files...
            f_reservedRIM: WORD;        // Reserved/unused data in RIM files.

            // Res info
            f_resoffset  : DWORD;       // Offset to start of resource data
            f_ressize    : DWORD;       // Number of bytes the data consists of

            procedure SetResRef(sResref : string);
            procedure SetResRefRaw(sResref : T16Char);
            function GetResRef() : string;
            function GetResRefRaw() : T16Char;
            function GetExtension() : string;
        public
            constructor Create();
            destructor Destroy(); override;

            // Methods to convert to<-->from file Extension to ResType ID.
            // Make them "C-static" so they can be used without an object instance...
            class function ResTypeToString(iType : WORD) : string;
            class function StringToResType(sType : string) : WORD;

            property RawResRef  : T16Char  read GetResrefRaw  write SetResrefRaw;
            property ResRef     : string   read GetResref     write SetResref;
            property ResID      : DWORD    read f_resid       write f_resid;
            property ResType    : WORD     read f_restype     write f_restype;
            property ReservedERF: WORD     read f_reserved    write f_reserved;
            property ReservedRIM: WORD     read f_reservedRIM write f_reservedRIM;
            property Extension  : string   read GetExtension;

            property dataoffset : DWORD    read f_resoffset   write f_resoffset;
            property datasize   : DWORD    read f_ressize     write f_ressize;
    end;

    // Had to put this down here to get things in the right order.... :/
    TERF_ResArray = array of TERF_Resource;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Main class. Allow manipulation of an ERF archive.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    TERFHandler = class(TObject)
        private
            f_header        : TERF_Header;              // File Header information.
            f_locstringlist : array of TERF_LocString;  // Localized strings for file description field.
            f_reslist       : TERF_ResArray;            // The files stored within the archive.
            f_newlist       : TStringList;              // New files that should be added to ERF in Save().
            f_namelist      : TStringList;              // ADDED(2006-08-09 - ResRef name of files to be added.

            f_filename      : string;        // Path+name of the ERF file the object represents.
            f_tmpfolderpath : string;        // Path to place folder to use as tmp work folder.
            f_tmpfolder     : string;        // Path+Name of temp folder for this file...
            f_file          : TFileStream;   // Used to read/write data from ERF file.
            f_loaded        : boolean;       // Set to TRUE when a file is loaded (or new is created).
            f_dirty         : boolean;       // Set to TRUE when any data is changed. Sets to FALSE in Save().
            f_newfile       : boolean;       // Set to TRUE if this is a new file that does not exist on Disk yet.

            function GetInfoByIndex(iIdx : integer) : TERF_Resource;
            function GetResCount() : integer;
            function GetNewCount() : integer;
            function GetERFType() : string;
        public
            // Methods to Load and save ERF data to file.
            procedure New(sFilename : string; enType : TERFType);
            procedure Load(sFilename : string);
            procedure Save(sFilename : string = '');
            procedure Reset(bDestroy : boolean = false);

            // Methods to store and fetch files within the ERF archive.
            procedure AddResource(sFilename : string; bReplace : boolean; sSaveAs : string = '');
            procedure GetResource(sResref : string; iResType : WORD; sFilename : string = '');
            procedure DeleteResource(sResref : string; iResType : WORD);

            // ADDED(2006-05-17) Check if a resource matching the specified file already exists in the ERF.
            function GetResourceExists(sFilename : string; bCheckNew : boolean = false) : boolean;

            // Object constructor and destructor methods...
            constructor Create(); overload;
            constructor Create(sFileToLoad : string); overload;
            destructor Destroy(); override;

            // ADDED(2006-08-09) Checks if the specified file is an ERF/RIM file.
            class function IsValidArchive(sFilename : string) : boolean;

            property TempPath                 : string         read f_tmpfolderpath   write f_tmpfolderpath;
            property TempFolder               : string         read f_tmpfolder;
            property Dirty                    : boolean        read f_dirty;
            property Loaded                   : boolean        read f_loaded;
            property FileName                 : string         read f_filename;
            property FileType                 : string         read GetERFType;
            property Count                    : integer        read GetResCount;
            property CountNew                 : integer        read GetNewCount;
            property Resource[iIdx : integer] : TERF_Resource  read GetInfoByIndex;
    end;

implementation

uses UST_Common;


// =============================================================================
// CLASS: TERF_ResRef
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Standard Constructor - Initialize a new ResRef object
// -----------------------------------------------------------------------------
constructor TERF_ResRef.Create();
begin
    inherited Create();
    FillChar(f_resref, sizeof(f_resref), #0);
end;


// -----------------------------------------------------------------------------
// Constructor - Initialize new ResRef with the specified string set as value.
// -----------------------------------------------------------------------------
constructor TERF_ResRef.Create(sText : string);
begin
    inherited Create();
    SetResRef(sText);
end;


// -----------------------------------------------------------------------------
// Default Destructor - Destroy the ResRef object.
// -----------------------------------------------------------------------------
destructor TERF_ResRef.Destroy();
begin
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Set Method - validate and store the string as the ResRef value.
// -----------------------------------------------------------------------------
procedure TERF_ResRef.SetResRef(sText : string);
var
   i    : integer;
   iCnt : integer;
   iMax : integer;
begin
    FillChar(f_resref, sizeof(f_resref), #0);
    // sText := lowercase(sText);

    iMax := Length(sText);
    if (iMax > 16) then
        iMax := 16;

    // Enforce ResRef format (16 characters, alphanumerical, lowercase) and set
    // the specified text as the ResRef.
    iCnt := 0;
    for i := 1 to iMax do begin
        if (sText[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then begin
            f_resref[iCnt] := sText[i];
            inc(iCnt);
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Get Method - retrieve the stored ResRef value as a string.
// -----------------------------------------------------------------------------
function TERF_ResRef.GetResRef() : string;
var
   sOut : string;
   i    : integer;
begin
    sOut := '';

    for i := Low(f_resref) to High(f_resref) do begin
        if (f_resref[i] <> #0) then
            sOut := sOut + f_resref[i];
    end;

    result := sOut;
end;



// =============================================================================
// CLASS: TERF_Header
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Default Constructor - initialize a new RIM Header object.
// -----------------------------------------------------------------------------
constructor TERF_Header.Create();
begin
    inherited Create();

    // Zero-pad the char arrays to start with blank values...
    FillChar(self.filetype, sizeof(self.filetype), #0);
    FillChar(self.version,  sizeof(self.version),  #0);
end;


// -----------------------------------------------------------------------------
// Default Destructor - Free the RIM header object.
// -----------------------------------------------------------------------------
destructor TERF_Header.Destroy();
begin
    inherited Destroy();
end;



// =============================================================================
// CLASS: TERF_ERFHeader
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Static support function, get Build Date values for the current date.
// -----------------------------------------------------------------------------
class procedure TERF_ERFHeader.GetBuildTime(var iYear : WORD; var iDay : WORD);
var
   oCurrDate : TSystemTime;
   iMonth    : integer;

   function GetFebruaryDays(iYear : WORD) : WORD;
   begin
       result := 28;

       if ((iYear mod 4 = 0) and (iYear mod 100 <> 0)) or (iYear mod 400 = 0) then begin
           result := 29;
       end;
   end;
begin
    DateTimeToSystemTime(Now(), oCurrDate);

    iYear := oCurrDate.wYear - 1900;
    iDay  := oCurrDate.wDay;

    for iMonth := 1 to (oCurrDate.wMonth - 1) do begin
        case iMonth of
            1:  inc(iDay, 31);
            2:  inc(iDay, GetFebruaryDays(oCurrDate.wYear));
            3:  inc(iDay, 31);
            4:  inc(iDay, 30);
            5:  inc(iDay, 31);
            6:  inc(iDay, 30);
            7:  inc(iDay, 31);
            8:  inc(iDay, 31);
            9:  inc(iDay, 30);
            10: inc(iDay, 31);
            11: inc(iDay, 30);
            12: inc(iDay, 31);
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Default Constructor - initialize a new Header object.
// -----------------------------------------------------------------------------
constructor TERF_ERFHeader.Create();
var
   iDay  : WORD;
   iYear : WORD;
begin
    inherited Create();

    // Zero-pad the char arrays to start with blank values...
    FillChar(self.reserved, sizeof(self.reserved), #0);

    self.locstringcount  := 0;
    self.locstringsize   := 0;
    self.entrycount      := 0;
    self.offsetlocstring := 0;
    self.offsetkeylist   := 0;
    self.offsetreslist   := 0;

    // Set the Description StrRef to -1 to start with...
    self.locstringstrref := $FFFFFFFF;

    // Set the Build Date to NOW to start with...
    TERF_ERFHeader.GetBuildTime(iYear, iDay);
    self.buildyear := iYear;
    self.buildday :=  iDay;

end;


// -----------------------------------------------------------------------------
// Default Destructor - Free the header object.
// -----------------------------------------------------------------------------
destructor TERF_ERFHeader.Destroy();
begin
    inherited Destroy();
end;




// =============================================================================
// CLASS: TERF_RIMHeader
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Default Constructor - initialize a new RIM Header object.
// -----------------------------------------------------------------------------
constructor TERF_RIMHeader.Create();
begin
    inherited Create();

    // Zero-pad the char arrays to start with blank values...
    FillChar(self.reserved, sizeof(self.reserved), #0);

    self.entrycount      := 0;
    self.offsetkeylist   := 0;
end;


// -----------------------------------------------------------------------------
// Default Destructor - Free the RIM header object.
// -----------------------------------------------------------------------------
destructor TERF_RIMHeader.Destroy();
begin
    inherited Destroy();
end;



// =============================================================================
// CLASS: TERF_LocString
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Default constructor, initialize this localized string object.
// -----------------------------------------------------------------------------
constructor TERF_LocString.Create();
begin
    inherited Create();
    f_languageid := 0;
    f_stringsize := 0;
    f_locstring  := '';
end;


// -----------------------------------------------------------------------------
// Constructor, initialize this localized string object with the specified
// language id and string text.
// -----------------------------------------------------------------------------
constructor TERF_LocString.Create(iLangID : DWORD; sText : string);
begin
    inherited Create();
    f_languageid := iLangID;
    SetString(sText);
end;


// -----------------------------------------------------------------------------
// Default destructor, free this localized string.
// -----------------------------------------------------------------------------
destructor TERF_LocString.Destroy();
begin
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Set Method, set text data and recalculate the string size field value.
// -----------------------------------------------------------------------------
procedure TERF_LocString.SetString(sText : string);
begin
    f_stringsize := Length(sText);
    f_locstring  := sText;
end;






// =============================================================================
// CLASS: TERF_Resource
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Default constructor, initialize this Resource object.
// -----------------------------------------------------------------------------
constructor TERF_Resource.Create();
begin
    inherited Create();

    f_resref      := TERF_ResRef.Create();
    f_resid       := 0;
    f_restype     := $FFFF;
    f_reserved    := 0;
    f_reservedRIM := 0;   // FIX(2006-08-23) This was not initialized here. Add just in case...

    f_resoffset   := $FFFFFFFF;
    f_ressize     := 0;
end;


// -----------------------------------------------------------------------------
// Default destructor, free this Resource object.
// -----------------------------------------------------------------------------
destructor TERF_Resource.Destroy();
begin
    if (f_resref <> nil) then
        f_resref.free();

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Set Method, set the Resref value of this resource.
// -----------------------------------------------------------------------------
procedure TERF_Resource.SetResRef(sResref : string);
begin
    f_resref.text := sResref;
end;


// -----------------------------------------------------------------------------
// Set Method, set the Resref value of this resource as a char array....
// -----------------------------------------------------------------------------
procedure TERF_Resource.SetResRefRaw(sResref : T16Char);
begin
    f_resref.raw := sResref;
end;


// -----------------------------------------------------------------------------
// Get Method, get the Resref value of this resource.
// -----------------------------------------------------------------------------
function TERF_Resource.GetResRef() : string;
begin
    result := f_resref.text;
end;


// -----------------------------------------------------------------------------
// Get Method, get the Resref value of this resource as a char array...
// -----------------------------------------------------------------------------
function TERF_Resource.GetResRefRaw() : T16Char;
begin
    result := f_resref.raw;
end;


// -----------------------------------------------------------------------------
// Static utility function, get the 3 character file extension for the specified
// resource type id.
// -----------------------------------------------------------------------------
class function TERF_Resource.ResTypeToString(iType : WORD) : string;
var
   sExt : string;
begin
    sExt := '';

    case iType of
        $0000 : sExt := 'res';
        $0001 : sExt := 'bmp';
        $0002 : sExt := 'mve';
        $0003 : sExt := 'tga';
        $0004 : sExt := 'wav';
        $0006 : sExt := 'plt';
        $0007 : sExt := 'ini';
        $0008 : sExt := 'mp3';
        $0009 : sExt := 'mpg';
        $000A : sExt := 'txt';
        $000B : sExt := 'wma';
        $000C : sExt := 'wmv';
        $000D : sExt := 'xmv';
        $07D0 : sExt := 'plh';
        $07D1 : sExt := 'tex';
        $07D2 : sExt := 'mdl';
        $07D3 : sExt := 'thg';
        $07D5 : sExt := 'fnt';
        $07D7 : sExt := 'lua';
        $07D8 : sExt := 'slt';
        $07D9 : sExt := 'nss';
        $07DA : sExt := 'ncs';
        $07DB : sExt := 'mod';
        $07DC : sExt := 'are';
        $07DD : sExt := 'set';
        $07DE : sExt := 'ifo';
        $07DF : sExt := 'bic';
        $07E0 : sExt := 'wok';
        $07E1 : sExt := '2da';
        $07E2 : sExt := 'tlk';
        $07E6 : sExt := 'txi';
        $07E7 : sExt := 'git';
        $07E8 : sExt := 'bti';
        $07E9 : sExt := 'uti';
        $07EA : sExt := 'btc';
        $07EB : sExt := 'utc';
        $07ED : sExt := 'dlg';
        $07EE : sExt := 'itp';
        $07EF : sExt := 'btt';
        $07F0 : sExt := 'utt';
        $07F1 : sExt := 'dds';
        $07F2 : sExt := 'bts';
        $07F3 : sExt := 'uts';
        $07F4 : sExt := 'ltr';
        $07F5 : sExt := 'gff';
        $07F6 : sExt := 'fac';
        $07F7 : sExt := 'bte';
        $07F8 : sExt := 'ute';
        $07F9 : sExt := 'btd';
        $07FA : sExt := 'utd';
        $07FB : sExt := 'btp';
        $07FC : sExt := 'utp';
        $07FD : sExt := 'dft';
        $07FE : sExt := 'gic';
        $07FF : sExt := 'gui';
        $0800 : sExt := 'css';
        $0801 : sExt := 'ccs';
        $0802 : sExt := 'btm';
        $0803 : sExt := 'utm';
        $0804 : sExt := 'dwk';
        $0805 : sExt := 'pwk';
        $0806 : sExt := 'btg';
        $0807 : sExt := 'utg';
        $0808 : sExt := 'jrl';
        $0809 : sExt := 'sav';
        $080A : sExt := 'utw';
        $080B : sExt := '4pc';
        $080C : sExt := 'ssf';
        $080D : sExt := 'hak';
        $080E : sExt := 'nwm';
        $080F : sExt := 'bik';
        $0BB8 : sExt := 'lyt';
        $0BB9 : sExt := 'vis';
        $0BBA : sExt := 'rim';
        $0BBB : sExt := 'pth';
        $0BBC : sExt := 'lip';
        $0BBD : sExt := 'bwm';
        $0BBE : sExt := 'txb';
        $0BBF : sExt := 'tpc';
        $0BC0 : sExt := 'mdx';
        $0BC1 : sExt := 'rsv';
        $0BC2 : sExt := 'sig';
        $0BC3 : sExt := 'xbx';
        $270D : sExt := 'erf';
        $270E : sExt := 'bif';
        $270F : sExt := 'key';
        $FFFF : sExt := '';
    end;

    result := sExt;
end;



// -----------------------------------------------------------------------------
// Static utility function, get the Resource Typd ID number for the specified
// the 3 character file extension.
// -----------------------------------------------------------------------------
class function TERF_Resource.StringToResType(sType : string) : WORD;
var
   iType : WORD;
begin
    iType := $FFFF;
    sType := lowercase(sType);

    // FIX(2006-05-17) If the extension begins with a period, strip it before
    // proceeding to match the extension below...
    if (sType[1] = '.') then
        sType := copy(sType, 2, Length(sType)-1);

         if (sType = 'res') then  iType := $0000
    else if (sType = 'bmp') then  iType := $0001
    else if (sType = 'mve') then  iType := $0002
    else if (sType = 'tga') then  iType := $0003
    else if (sType = 'wav') then  iType := $0004
    else if (sType = 'plt') then  iType := $0006
    else if (sType = 'ini') then  iType := $0007
    else if (sType = 'mp3') then  iType := $0008
    else if (sType = 'mpg') then  iType := $0009
    else if (sType = 'txt') then  iType := $000A
    else if (sType = 'wma') then  iType := $000B
    else if (sType = 'wmv') then  iType := $000C
    else if (sType = 'xmv') then  iType := $000D
    else if (sType = 'plh') then  iType := $07D0
    else if (sType = 'tex') then  iType := $07D1
    else if (sType = 'mdl') then  iType := $07D2
    else if (sType = 'thg') then  iType := $07D3
    else if (sType = 'fnt') then  iType := $07D5
    else if (sType = 'lua') then  iType := $07D7
    else if (sType = 'slt') then  iType := $07D8
    else if (sType = 'nss') then  iType := $07D9
    else if (sType = 'ncs') then  iType := $07DA
    else if (sType = 'mod') then  iType := $07DB
    else if (sType = 'are') then  iType := $07DC
    else if (sType = 'set') then  iType := $07DD
    else if (sType = 'ifo') then  iType := $07DE
    else if (sType = 'bic') then  iType := $07DF
    else if (sType = 'wok') then  iType := $07E0
    else if (sType = '2da') then  iType := $07E1
    else if (sType = 'tlk') then  iType := $07E2
    else if (sType = 'txi') then  iType := $07E6
    else if (sType = 'git') then  iType := $07E7
    else if (sType = 'bti') then  iType := $07E8
    else if (sType = 'uti') then  iType := $07E9
    else if (sType = 'btc') then  iType := $07EA
    else if (sType = 'utc') then  iType := $07EB
    else if (sType = 'dlg') then  iType := $07ED
    else if (sType = 'itp') then  iType := $07EE
    else if (sType = 'btt') then  iType := $07EF
    else if (sType = 'utt') then  iType := $07F0
    else if (sType = 'dds') then  iType := $07F1
    else if (sType = 'bts') then  iType := $07F2
    else if (sType = 'uts') then  iType := $07F3
    else if (sType = 'ltr') then  iType := $07F4
    else if (sType = 'gff') then  iType := $07F5
    else if (sType = 'fac') then  iType := $07F6
    else if (sType = 'bte') then  iType := $07F7
    else if (sType = 'ute') then  iType := $07F8
    else if (sType = 'btd') then  iType := $07F9
    else if (sType = 'utd') then  iType := $07FA
    else if (sType = 'btp') then  iType := $07FB
    else if (sType = 'utp') then  iType := $07FC
    else if (sType = 'dft') then  iType := $07FD
    else if (sType = 'gic') then  iType := $07FE
    else if (sType = 'gui') then  iType := $07FF
    else if (sType = 'css') then  iType := $0800
    else if (sType = 'ccs') then  iType := $0801
    else if (sType = 'btm') then  iType := $0802
    else if (sType = 'utm') then  iType := $0803
    else if (sType = 'dwk') then  iType := $0804
    else if (sType = 'pwk') then  iType := $0805
    else if (sType = 'btg') then  iType := $0806
    else if (sType = 'utg') then  iType := $0807
    else if (sType = 'jrl') then  iType := $0808
    else if (sType = 'sav') then  iType := $0809
    else if (sType = 'utw') then  iType := $080A
    else if (sType = '4pc') then  iType := $080B
    else if (sType = 'ssf') then  iType := $080C
    else if (sType = 'hak') then  iType := $080D
    else if (sType = 'nwm') then  iType := $080E
    else if (sType = 'bik') then  iType := $080F
    else if (sType = 'lyt') then  iType := $0BB8
    else if (sType = 'vis') then  iType := $0BB9
    else if (sType = 'rim') then  iType := $0BBA
    else if (sType = 'pth') then  iType := $0BBB
    else if (sType = 'lip') then  iType := $0BBC
    else if (sType = 'bwm') then  iType := $0BBD
    else if (sType = 'txb') then  iType := $0BBE
    else if (sType = 'tpc') then  iType := $0BBF
    else if (sType = 'mdx') then  iType := $0BC0
    else if (sType = 'rsv') then  iType := $0BC1
    else if (sType = 'sig') then  iType := $0BC2
    else if (sType = 'xbx') then  iType := $0BC3
    else if (sType = 'erf') then  iType := $270D
    else if (sType = 'bif') then  iType := $270E
    else if (sType = 'key') then  iType := $270F;

    result := iType;
end;


// -----------------------------------------------------------------------------
// Get-method for Extension property. Returns the file extension for the
// res-type of this file.
// -----------------------------------------------------------------------------
function TERF_Resource.GetExtension() : string;
begin
    result := ResTypeToString(f_restype);

end;



// =============================================================================
// CLASS: TERFHandler
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Default constructor, create an ERFHandler object.
// -----------------------------------------------------------------------------
constructor TERFHandler.Create();
begin
    inherited Create();
    Reset();
end;


// -----------------------------------------------------------------------------
// Constructor, create ERFHandler object and load ERF data from a file into it.
// -----------------------------------------------------------------------------
constructor TERFHandler.Create(sFileToLoad : string);
begin
    inherited Create();
    Load(sFileToLoad);
end;


// -----------------------------------------------------------------------------
// Default destructor, free all data this objects holds.
// -----------------------------------------------------------------------------
destructor TERFHandler.Destroy();
begin
    Reset(true);
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// ADDED(2006-05-18)
// -----------------------------------------------------------------------------
function TERFHandler.GetERFType() : string;
var
   sType : string;
   i     : integer;
begin
    sType := '';
    for i := Low(f_header.filetype) to High(f_header.filetype) do begin
        if (i < High(f_header.filetype)) or (f_header.filetype[i] <> ' ') then
            sType := f_header.filetype[i];
    end;
    result := sType;
end;



// -----------------------------------------------------------------------------
// ADDED(2006-08-09)
// Checks if the specified file appears to be a valid ERF or RIM format file.
// -----------------------------------------------------------------------------
class function TERFHandler.IsValidArchive(sFilename : string) : boolean;
var
   sTempType : T4Char;
   sTempVer  : T4Char;
   oStream   : TFileStream;
begin
    result := false;

    // If the file does not exist it's obviously not a valid archive.
    if not FileExists(sFilename) then
        exit;

    // Open the file and check the header info...
    oStream := nil;
    try
        try
            oStream := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyWrite);

            FillChar(sTempType, sizeof(sTempType), #0);
            FillChar(sTempVer, sizeof(sTempVer), #0);
            // Read header Type and Version information....
            oStream.read(sTempType, 4);
            oStream.read(sTempVer, 4);

            // Check that it appears to be a valid ERF file type, otherwise abort...
            if (sTempVer = 'V1.0')
                and ((sTempType = 'ERF ')
                    or (sTempType = 'MOD ')
                    or (sTempType = 'HAK ')
                    or (sTempType = 'SAV ')
                    or (sTempType = 'RIM '))
            then begin
                result := true;
                exit;
            end;
        except
            on err : Exception do begin
                result := false;
                exit;
            end;
        end;
    finally
        if (oStream <> nil) then
            oStream.Free();
    end;
end;


// -----------------------------------------------------------------------------
// Readies the object to create a new, blank ERF file that new files can be
// added to and saved.
// -----------------------------------------------------------------------------
procedure TERFHandler.New(sFilename : string; enType : TERFType);
begin
    Reset();

    f_filename := sFilename;

    if (enType = erfRIM) then
        f_header := TERF_RIMHeader.Create()
    else
        f_header := TERF_ERFHeader.Create();

    case enType of
        erfMOD: f_header.filetype := 'MOD ';
        erfHAK: f_header.filetype := 'HAK ';
        erfERF: f_header.filetype := 'ERF ';
        erfSAV: f_header.filetype := 'SAV ';
        erfRIM: f_header.filetype := 'RIM ';
    end;

    f_header.version := 'V1.0';

    f_file     := nil;
    f_loaded   := true;
    f_newfile  := true;
end;


// -----------------------------------------------------------------------------
// Loads the information from an ERF file on Disk into this object.
// sFilename is the Path+Name of the ERF file to open.
// -----------------------------------------------------------------------------
procedure TERFHandler.Load(sFilename : string);
var
   oLocStr   : TERF_LocString;
   oRes      : TERF_Resource;
   sText     : string;
   iNum      : DWORD;
   iShortNum : WORD;
   i         : integer;
   sTempType : T4Char;
   sTempVer  : T4Char;
   bIsRIM    : boolean;
   oHeaderRIM: TERF_RIMHeader;
   oHeaderERF: TERF_ERFHeader;
begin
    if not FileExists(sFilename) then begin
        raise EERFError.CreateHelp('Unable to load file "' + sFilename + '", file not found!', 5);
    end;

    // Reset/initialize the data fields before loading data from field...
    Reset();

    // Open the file to read...
    // FINALLY is left out on purpose! Do NOT close the FileStream here
    // unless an error occurs!
    f_file := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyWrite);
    try
        FillChar(sTempType, sizeof(sTempType), #0);
        FillChar(sTempVer, sizeof(sTempVer), #0);
        // Read header Type and Version information....
        f_file.read(sTempType, 4);
        f_file.read(sTempVer, 4);

        // Check that it appears to be a valid ERF file type, otherwise abort...
        if (sTempVer <> 'V1.0')
            or not ((sTempType = 'ERF ')
                or (sTempType = 'MOD ')
                or (sTempType = 'HAK ')
                or (sTempType = 'SAV ')
                or (sTempType = 'RIM '))   // ADDED(2006-05-20)
        then begin
            raise EERFError.CreateHelp('Unable to load file "' + sFilename + '", it does not appear to be a valid ERF file type!', 6);
        end;

        // ADDED(2006-05-20) - - - - - - - - - - - - - - - - - - - - -
        // Create different headers for ERF and RIM files.
        if (f_header <> nil) then begin
            f_header.free();
            f_header := nil;
        end;

        bIsRIM := (sTempType = 'RIM ');

        if bIsRIM then begin
            f_header := TERF_RIMHeader.Create();
            oHeaderRIM := TERF_RIMHeader(f_header);
        end
        else begin
            f_header := TERF_ERFHeader.Create();
            oHeaderERF := TERF_ERFHeader(f_header);
        end;
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        // These are common in both header types...
        f_header.filetype := sTempType;
        f_header.version := sTempVer;

        // Load the rest of the Header information...
        if bIsRIM then begin
            // Load the rest of the Header information...
            f_file.read(oHeaderRIM.unknown,         sizeof(oHeaderRIM.unknown));
            f_file.read(oHeaderRIM.entrycount,      sizeof(oHeaderRIM.entrycount));
            f_file.read(oHeaderRIM.offsetkeylist,   sizeof(oHeaderRIM.offsetkeylist));
            f_file.read(oHeaderRIM.reserved,        sizeof(oHeaderRIM.reserved));

            // Read the Key data from the RIM file
            // Note that this includes the same data stored in the Resource list in ERFs.
            f_file.seek(oHeaderRIM.offsetkeylist, soFromBeginning);
            for i := 0 to (oHeaderRIM.entrycount - 1) do begin
                oRes := TERF_Resource.Create();

                SetLength(sText, 16);
                f_file.read(Pointer(sText)^, 16);
                oRes.resref := sText;
                sText := '';

                f_file.read(iShortNum, 2);
                oRes.ResType := iShortNum;

                // ADDED(2006-08-23) Missed this seemingly unused WORD before, reusing ERF-property to store it....
                f_file.read(iShortNum, 2);
                oRes.ReservedERF := iShortNum;

                // CHANGED(2006-08-23) Reading this two bytes ahead in the file.
                f_file.read(iShortNum, 2);
                oRes.ResID := iShortNum;

                // FIX(2006-08-23) This is a WORD, not a DWORD....
                f_file.read(iShortNum, 2);
                oRes.ReservedRIM := iShortNum;

                f_file.read(iNum, 4);       // Check if this is read properly now...
                oRes.dataoffset := iNum;

                f_file.read(iNum, 4);
                oRes.datasize := iNum;

                SetLength(f_reslist, Length(f_reslist) + 1);
                f_reslist[i] := oRes;
            end;
        end
        else begin
            // Load the rest of the Header information...
            f_file.read(oHeaderERF.locstringcount,  sizeof(oHeaderERF.locstringcount));
            f_file.read(oHeaderERF.locstringsize,   sizeof(oHeaderERF.locstringsize));
            f_file.read(oHeaderERF.entrycount,      sizeof(oHeaderERF.entrycount));
            f_file.read(oHeaderERF.offsetlocstring, sizeof(oHeaderERF.offsetlocstring));
            f_file.read(oHeaderERF.offsetkeylist,   sizeof(oHeaderERF.offsetkeylist));
            f_file.read(oHeaderERF.offsetreslist,   sizeof(oHeaderERF.offsetreslist));
            f_file.read(oHeaderERF.buildyear,       sizeof(oHeaderERF.buildyear));
            f_file.read(oHeaderERF.buildday,        sizeof(oHeaderERF.buildday));
            f_file.read(oHeaderERF.locstringstrref, sizeof(oHeaderERF.locstringstrref));
            f_file.read(oHeaderERF.reserved,        sizeof(oHeaderERF.reserved));

            // Load the Localized String List...
            f_file.seek(oHeaderERF.offsetlocstring, soFromBeginning);
            for i := 0 to (oHeaderERF.locstringcount - 1) do begin
               oLocStr := TERF_LocString.Create();

               f_file.read(iNum, sizeof(iNum));
               oLocStr.languageid := iNum;

               f_file.read(iNum, sizeof(iNum));
               oLocStr.size := iNum;

               SetLength(sText, oLocStr.size);
               f_file.read(Pointer(sText)^, oLocStr.size);
               oLocStr.text := sText;
               sText := '';

               SetLength(f_locstringlist, Length(f_locstringlist) + 1);
               f_locstringlist[i] := oLocStr;
            end;

            // Load the KeyList
            f_file.seek(oHeaderERF.offsetkeylist, soFromBeginning);
            for i := 0 to (oHeaderERF.entrycount - 1) do begin
                oRes := TERF_Resource.Create();

                SetLength(sText, 16);
                f_file.read(Pointer(sText)^, 16);
                oRes.resref := sText;
                sText := '';

                f_file.read(iNum, sizeof(iNum));
                oRes.ResID := iNum;

                f_file.read(iShortNum, sizeof(iShortNum));
                oRes.ResType := iShortNum;

                f_file.read(iShortNum, sizeof(iShortNum));
                oRes.ReservedERF := iShortNum;

                SetLength(f_reslist, Length(f_reslist) + 1);
                f_reslist[i] := oRes;
            end;


            // Load the ResourceList, entries should match the KeyList in File...
            f_file.seek(oHeaderERF.offsetreslist, soFromBeginning);
            for i := Low(f_reslist) to High(f_reslist) do begin
                oRes := f_reslist[i];

                f_file.read(iNum, sizeof(iNum));
                oRes.dataoffset := iNum;

                f_file.read(iNum, sizeof(iNum));
                oRes.datasize := iNum;
            end;
        end;

        // DON'T load the file resource data for all files, since it could take
        // up huge amounts of memory if the ERF file is large. Instead, load the
        // data from the file "on demand" by reading at the offset stored in the
        // resource table above.

        // DON'T close the FileStream here, leave it open as long as the file this
        // object represents is kept open to allow reading data when needed.
        
        // Set that the file has been loaded.
        f_filename := sFilename;
        f_loaded   := true;
        f_newfile  := false;
    except
        Reset();
        raise;
    end;

end;


// -----------------------------------------------------------------------------
// BFF! Save the currently loaded ERF data to the ERF file on disk.
// Note: This will extract all resources currently in the ERF and re-create it
//       from scratch along with any changes applied.
// -----------------------------------------------------------------------------
procedure TERFHandler.Save(sFilename : string = '');
var
   oRes        : TERF_Resource;
   oOut        : TFileStream;
   oIn         : TFileStream;
   oFiles      : TStringList;
   sFile       : string;
   sExt        : string;
   sName       : string;
   sTemp       : string;
   sBuf        : T16Char;
   i           : integer;
   iYear       : WORD;
   iDay        : WORD;
   iShortNum   : WORD;
   iNum        : DWORD;
   iDataOffset : DWORD;
   iResOffset  : DWORD;
   iKeyOffset  : DWORD;
   bIsRIM      : boolean;
   oHeaderERF  : TERF_ERFHeader;
   oHeaderRIM  : TERF_RIMHeader;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    procedure CopyNewFile(const sFilename, sNewfile: string);
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

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    function GetFileList(sFolder : string) : TStringList;
    var
        iRes    : integer;
        rFile   : TSearchRec;
        oList   : TStringList;
    begin
        oList := TStringList.Create();

        iRes := SysUtils.FindFirst(sFolder + '*.*', faAnyFile, rFile);
         while (iRes = 0) do begin
             if SysUtils.FileExists(sFolder + rFile.Name) then begin
                 oList.Add(sFolder + rFile.Name);
             end;
             iRes := SysUtils.FindNext(rFile);
         end;
         SysUtils.FindClose(rFile);

         result := oList;
    end;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    function GetLocStringSize() : DWORD;
    var
       n     : integer;
       iSize : DWORD;
    begin
        iSize := 0;
        for n := Low(f_locstringlist) to High(f_locstringlist) do begin
            iSize := iSize + DWORD(Length(f_locstringlist[n].text)); // Size of the text string.
            inc(iSize, 8); // Size of LangId and StringSize fields
        end;
        result := iSize;
    end;

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    procedure DeleteFolder(sFolder : string);
    var
        oList : TStringList;
        j     : integer;
    begin
        oList := GetFileList(sFolder);
        for j := 0 to (oList.count - 1) do begin
            if SysUtils.FileExists(oList[j]) then
                SysUtils.DeleteFile(oList[j]);
        end;

        oList.free();
        SysUtils.RemoveDir(sFolder);
    end;

begin
    if not f_loaded then
        raise EERFError.CreateHelp('Unable to save, no ERF file is open!', 1);

    if (f_file = nil) and not f_newfile then
        raise EERFError.CreateHelp('Unable to save, could not access file!', 15);

    // If nothing has been changed there's no point in continuing further...
    // FIX(2006-05-18) ...But only if doing a regular save, not a "Save As..."
    if (sFilename = '') and not f_dirty then
        exit;

    // Get stored name for the ERF file, if no new name has been set.
    if (sFilename = '') then
        sFilename := f_filename;

    if (Length(sFilename) < 1) then
        raise EERFError.CreateHelp('Unable to save, no file name has been specified!', 16);


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 1. Make a TEMP folder to use to briefly store data while working.
    sTemp := ExtractFileName(f_filename);
    sTemp := lowercase(copy(sTemp, 1, Pos(ExtractFileExt(sTemp), sTemp)-1));
    f_tmpfolder := f_tmpfolderpath + lowercase(sTemp) + '_tmp\';
    sTemp := '';
    ForceDirectories(f_tmpfolder);


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 2. Extract current content from the ERF file to the TEMP folder.
    // ADDED(2006-05-18) Handle case if it's a new file that doesn't exist already.
    if not f_newfile then begin
        for i := Low(f_reslist) to High(f_reslist) do begin
            oRes := f_reslist[i];

            sFile := oRes.Resref;
            sExt := TERF_Resource.ResTypeToString(oRes.ResType);
            if (Length(sExt) > 0) then
                sFile := sFile + '.' + sExt;

            sFile := f_tmpfolder + sFile;

            // Read data from ERF and write to new file on disk.
            oOut := TFileStream.Create(sFile, fmCreate or fmShareExclusive);
            try
                if (oRes.datasize > 0) then begin
                    f_file.Seek(oRes.dataoffset, soFromBeginning);
                    oOut.CopyFrom(f_file, oRes.datasize);
                end;
            finally
                if (oOut <> nil) then begin
                    oOut.free();
                end;
            end;
        end;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 3. Copy new files to add to the ERF to the TEMP folder...
    if (f_newlist.Count > 0) then begin
        for i := 0 to (f_newlist.count - 1) do begin
            if FileExists(f_newlist[i]) then begin
               // CHANGED(2006-08-09) Use stored resref name instead at destination name...
               CopyNewFile(f_newlist[i], f_tmpfolder + f_namelist[i]);
               // CopyNewFile(f_newlist[i], f_tmpfolder + ExtractFileName(f_newlist[i]));
            end;
        end;
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 4. Get list of all files that should be added to the ERF.
    oFiles := GetFileList(f_tmpfolder);


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 5. Recalculate Header information.
    bIsRIM := (f_header.filetype = 'RIM ');

    if bIsRIM then begin
        oHeaderRIM := TERF_RIMHeader(f_header);
        oHeaderRIM.entrycount := oFiles.count;
        oHeaderRIM.offsetkeylist := 120;
    end
    else begin
        oHeaderERF := TERF_ERFHeader(f_header);
        TERF_ERFHeader.GetBuildTime(iYear, iDay);
        oHeaderERF.locstringcount := Length(f_locstringlist);
        oHeaderERF.locstringsize := GetLocStringSize();
        oHeaderERF.entrycount := oFiles.count;
        oHeaderERF.buildyear := iYear;
        oHeaderERF.buildday := iDay;
        oHeaderERF.offsetlocstring := 160;
        oHeaderERF.offsetkeylist := oHeaderERF.offsetlocstring + oHeaderERF.locstringsize;
        oHeaderERF.offsetreslist := oHeaderERF.offsetkeylist + (oHeaderERF.entrycount * 24);
    end;


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 6. Close FileStream if open, re-open it in Write mode...
    if (f_file <> nil) then
        f_file.free();

    // CHANGED(2006-08-06) changed to Create/Overwrite depending on if the file exists.
    // FIX(2006-09-30)     Changed to ONLY use fmCreate, the other write mode fucked up
    //                     saving old data when things were deleted.
    f_file := TFileStream.Create(sFilename, fmCreate or fmShareDenyWrite);

    try
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // 7. Write Header information.
        f_file.write(f_header.filetype,         sizeof(f_header.filetype));
        f_file.write(f_header.version,          sizeof(f_header.version));

        if bIsRIM then begin
            f_file.Write(oHeaderRIM.unknown,          sizeof(oHeaderRIM.unknown));
            f_file.Write(oHeaderRIM.entrycount,       sizeof(oHeaderRIM.entrycount));
            f_file.Write(oHeaderRIM.offsetkeylist,    sizeof(oHeaderRIM.offsetkeylist));
            f_file.Write(oHeaderRIM.reserved,         sizeof(oHeaderRIM.reserved));
        end
        else begin
            f_file.write(oHeaderERF.locstringcount,   sizeof(oHeaderERF.locstringcount));
            f_file.write(oHeaderERF.locstringsize,    sizeof(oHeaderERF.locstringsize));
            f_file.write(oHeaderERF.entrycount,       sizeof(oHeaderERF.entrycount));
            f_file.write(oHeaderERF.offsetlocstring,  sizeof(oHeaderERF.offsetlocstring));
            f_file.write(oHeaderERF.offsetkeylist,    sizeof(oHeaderERF.offsetkeylist));
            f_file.write(oHeaderERF.offsetreslist,    sizeof(oHeaderERF.offsetreslist));
            f_file.write(oHeaderERF.buildyear,        sizeof(oHeaderERF.buildyear));
            f_file.write(oHeaderERF.buildday,         sizeof(oHeaderERF.buildday));
            f_file.write(oHeaderERF.locstringstrref,  sizeof(oHeaderERF.locstringstrref));
            f_file.write(oHeaderERF.reserved,         sizeof(oHeaderERF.reserved));
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // 8. Write the LocString descriptions....
        if not bIsRIM then begin
            f_file.seek(oHeaderERF.offsetlocstring, soFromBeginning);
            for i := Low(f_locstringlist) to High(f_locstringlist) do begin
                f_file.write(f_locstringlist[i].languageid, 4);

                sTemp := f_locstringlist[i].text;
                iNum := Length(sTemp);
                f_file.write(iNum, 4);
                f_file.write(Pointer(sTemp)^, iNum);
            end;
        end;


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // 9. Build Resource Info for files in the TEMP folder and write it to
        // the file.
        // Set initial offsets for each section...
        if bIsRIM then begin
            iKeyOffset  := oHeaderRIM.offsetkeylist;
            iDataOffset := oHeaderRIM.offsetkeylist + (32 * oHeaderRIM.entrycount);
            for i := 0 to (oFiles.count - 1) do begin
                // Get the ResRef and ResType from the filename and extension.
                sExt  := ExtractFileExt(oFiles[i]);
                sName := ExtractFileName(oFiles[i]);
                sName := copy(sName, 1, Pos(sExt, sName)-1);       // Filename without extension; FIX(2006-05-18) Removed LowerCase conversion here.
                sExt  := lowercase(copy(sExt, 2, Length(sExt)-1)); // File extension without leading period.

                // Temporarily store data to write about this file in a Resource object...
                oRes         := TERF_Resource.Create();
                oRes.ResRef  := sName;
                oRes.ResID   := DWORD(i);
                oRes.ResType := TERF_Resource.StringToResType(sExt);
                iShortNum    := WORD(i);

                /////////////////////
                // Write data to the key list...
                f_file.seek(iKeyOffset, soFromBeginning);
                sBuf := oRes.RawResRef;
                f_file.write(sBuf, 16);
                f_file.write(oRes.ResType, 2);
                f_file.write(oRes.ReservedERF, 2);  // ADDED(2006-08-23) Added this missing seemingly reserved WORD.
                f_file.write(iShortNum, 2); // FIX(2006-08-23) Make sure ResID is written properly as a WORD!
                f_file.write(oRes.ReservedRIM, 2);
                iKeyOffset := f_file.position;   // Store position temporarily...

                /////////////////////
                // Write the file resource data itself...
                f_file.seek(iDataOffset, soFromBeginning);

                oIn := TFileStream.Create(oFiles[i], fmOpenRead or fmShareDenyWrite);
                try
                    oRes.DataSize   := f_file.CopyFrom(oIn, 0);
                    oRes.DataOffset := iDataOffset;
                    iDataOffset     := f_file.position;
                finally
                    if (oIn <> nil) then begin
                        oIn.free();
                    end;
                end;

                /////////////////////            
                // Write offset and byte length data to the KeyList as well...
                f_file.seek(iKeyOffset, soFromBeginning);  // Return to stored position...
                f_file.write(oRes.dataoffset, 4);
                f_file.write(oRes.datasize, 4);
                iKeyOffset := f_file.position;    // Set position for next KeyEntry to be written at.

                // Free the temporary data holder Resource object when data is written to file.
                oRes.free();
            end;
        end
        else begin
            iKeyOffset  := oHeaderERF.offsetkeylist;
            iResOffset  := oHeaderERF.offsetreslist;
            iDataOffset := oHeaderERF.offsetreslist + (8 * oHeaderERF.entrycount);
            for i := 0 to (oFiles.count - 1) do begin
                // Get the ResRef and ResType from the filename and extension.
                sExt  := ExtractFileExt(oFiles[i]);
                sName := ExtractFileName(oFiles[i]);
                sName := copy(sName, 1, Pos(sExt, sName)-1);   // FIX(2006-05-18) Removed LowerCase conversion here.
                sExt  := lowercase(copy(sExt, 2, Length(sExt)-1));

                // Temporarily store data to write about this file in a Resource object...
                oRes         := TERF_Resource.Create();
                oRes.ResRef  := sName;
                oRes.ResID   := DWORD(i);
                oRes.ResType := TERF_Resource.StringToResType(sExt);

                /////////////////////
                // Write data to the key list...
                f_file.seek(iKeyOffset, soFromBeginning);
                // sTemp := oRes.ResRef;
                // f_file.write(Pointer(sTemp)^, 16);
                sBuf := oRes.RawResRef;
                f_file.write(sBuf, 16);
                f_file.write(oRes.ResId, 4);
                f_file.write(oRes.ResType, 2);
                f_file.write(oRes.ReservedERF, 2);
                iKeyOffset := f_file.position;

                /////////////////////
                // Write the file resource data itself...
                f_file.seek(iDataOffset, soFromBeginning);

                oIn := TFileStream.Create(oFiles[i], fmOpenRead or fmShareDenyWrite);
                try
                    oRes.DataSize   := f_file.CopyFrom(oIn, 0);
                    oRes.DataOffset := iDataOffset;
                    iDataOffset     := f_file.position;
                finally
                    if (oIn <> nil) then begin
                        oIn.free();
                    end;
                end;

                /////////////////////            
                // Write data to the Res list...
                f_file.seek(iResOffset, soFromBeginning);
                f_file.write(oRes.dataoffset, 4);
                f_file.write(oRes.datasize, 4);
                iResOffset := f_file.position;


                // Free the temporary data holder Resource object when data is written to file.
                oRes.free();
            end;
        end;
    finally
        if (f_file <> nil) then begin
            f_file.free();
            f_file := nil;
        end
    end;

    // Free the TEMP folder files list when all files have been processed.
    oFiles.free();

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 10. Delete the TEMP folder and all temporarily extracted/copied files.
    DeleteFolder(f_tmpfolder);


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // 11. Reload the recently written ERF file into this object.
    //     This reopens the FileStream in read mode, and resets the NewList,
    //     f_dirty and all stored data.
    Load(sFilename);

    {
     1 Derive name of TMP folder name from the filename, set it and ForceDirectories().
     2 Extract all resources from ERF file to the TEMP folder.
     3 Copy all files in the NEW list to the TEMP folder.
     4 Get list of all files to add to the ERF.
     5 Prepare new Header information as best as possible.
     6 Close/free the f_file FileStream. Re-open f_file FileStream in Create/Write mode.
     7 Go through TEMP folder and write all files within to the new ERF file.
     8 Delete the TEMP folder and its content.
     9 Call Load() to re-load the saved ERF data. (This will call Reset() automatically,
       clearing the f_newlist and f_dirty fields and re-opening the FileStream in Read mode.)
    }
end;


// -----------------------------------------------------------------------------
// Reset the data fields to default/start values.
// -----------------------------------------------------------------------------
procedure TERFHandler.Reset(bDestroy : boolean = false);
var
   i : integer;
begin
    // Close the FileStream if it's open...
    if (f_file <> nil) then
        f_file.free();
    f_file := nil;


    // Free the current header object, if any...
    if (f_header <> nil) then begin
        f_header.free();
        f_header := nil;
    end;


    // Create new header object...
    // CHANGED(2006-05-20) Don't do this here anymore since the header object type
    // will depend on if it's an ERF or RIM file.
    //if not bDestroy then
    //    f_header := TERF_ERFHeader.Create();


    // Free the Localized Description String List array....
    for i := Low(f_locstringlist) to High(f_locstringlist) do begin
        if (f_locstringlist[i] <> nil) then
            f_locstringlist[i].free();
    end;
    f_locstringlist := nil;
    SetLength(f_locstringlist, 0);


    // Free the Resource List array...
    for i := Low(f_reslist) to High(f_reslist) do begin
        if (f_reslist[i] <> nil) then
            f_reslist[i].free();
    end;
    f_reslist := nil;
    SetLength(f_reslist, 0);

    
    // Free the New Resource (string) array....
    if (f_newlist <> nil) then begin
        f_newlist.free();
        f_newlist := nil;
    end;

    // ADDED(2006-08-09) Free the New Resource (string) array....
    if (f_namelist <> nil) then begin
        f_namelist.free();
        f_namelist := nil;
    end;

    if not bDestroy then begin
        f_newlist := TStringList.Create();
        f_namelist := TStringList.Create(); // ADDED(2006-08-09)
    end;



    // Reset to default/unopened values...
    f_filename      := '';
    f_tmpfolderpath := ExtractFilePath(Application.ExeName);
    f_loaded        := false;
    f_newfile       := false;
    f_dirty         := false;
end;


// -----------------------------------------------------------------------------
// Add a new resource to the list of resources that should be added to the ERF
// file the next time it is saved.
// CHANGED(2006-08-09) Added new sSaveAs parameter to allow adding the file
// as a resref different from the original file name.
// -----------------------------------------------------------------------------
procedure TERFHandler.AddResource(sFilename : string; bReplace : boolean; sSaveAs : string = '');
var
   oRes  : TERF_Resource;
   iType : WORD;
   sName : string;
   sExt  : string;
   i     : integer;
begin
    if not f_loaded then
        raise EERFError.CreateHelp('Unable to add resource to file, no ERF file is open!', 2);

    if (sSaveAs = '') then
        sSaveAs := ExtractFileName(sFilename);

    // Extract potential ResRef and Extension from file to compare against
    // existing files to avoid adding files with the same ResRef twice.
    sExt  := ExtractFileExt(sSaveAs);
    sName := ExtractFileName(sSaveAs);
    sName := lowercase(copy(sName, 1, Pos(sExt, sName)-1));
    sExt  := lowercase(copy(sExt, 2, Length(sExt)-1));
    iType := TERF_Resource.StringToResType(sExt);

    if (iType = $FFFF) then begin
        raise EERFError.CreateHelp('Cannot add resource "' + sName + '"! Unsupported file type "' + sExt + '" encountered!', 9);
    end;

    // Check if a file with this type+resref already exists in the ERF....
    for i := Low(f_reslist) to High(f_reslist) do begin
        oRes := f_reslist[i];
        if (lowercase(oRes.ResRef) = sName) and (oRes.ResType = iType) then begin
            if not bReplace then begin
                raise EERFError.CreateHelp('Cannot add resource "' + sName + '.' + sExt + '"! A file with this name already exists in the ERF!', 10);
            end;

            DeleteResource(sName, iType);
            break;
        end;
    end;

    // Check if a file with this name already exists in the list of new files to add on save.
    for i := 0 to (f_newlist.count-1) do begin
        if (lowercase(ExtractFileName(sFilename)) = lowercase(ExtractFileName(f_newlist[i]))) then begin
            if not bReplace then begin
                raise EERFError.CreateHelp('Cannot add resource "' + sName + '.' + sExt + '"! A file with this name has already been added to the ERF!', 11);
            end
            // CHANGED(2006-05-17) If the bReplace flag is set, replace a newly added
            // file too with this one by removing the old from the newlist array before
            // the new is added.
            else begin
                f_newlist.Delete(i);
                f_namelist.Delete(i);
                break;
            end;
        end;
    end;

    // Add the file to the list of new files to add on Save.
    f_newlist.Add(sFilename);
    f_namelist.Add(sSaveAs); // ADDED(2006-08-09)
    f_dirty := true;
end;


// -----------------------------------------------------------------------------
// Retrieve a resource from the ERF file and save as a separate file on disk.
// sResRef + iResType identified which resource should be extracted.
// sFileName is the Path+Name the extracted file should be saved as.
// -----------------------------------------------------------------------------
procedure TERFHandler.GetResource(sResref : string; iResType : WORD; sFilename : string = '');
var
   oOut   : TFileStream;
   oRes   : TERF_Resource;
   bFound : boolean;
   sExt   : string;
   i      : integer;
begin
    // Stop if no ERF file is loaded into this object.
    if not f_loaded then
        raise EERFError.CreateHelp('Unable to get resource from file, no ERF file is open!', 3);

    // Stop if the FileStream object for some reason hasn't been set?
    if (f_file = nil) then
        raise EERFError.CreateHelp('Unable to get resource from file, the file could not be read!', 12);

    // Find the resource to extract in the ResourceList...
    oRes := nil;
    bFound := false;
    for i := Low(f_reslist) to High(f_reslist) do begin
        oRes := f_reslist[i];
        if (lowercase(oRes.ResRef) = lowercase(sResref)) and (oRes.ResType = iResType) then begin
            bFound := true;
            break;
        end;
    end;

    // The specified resource was not located in the ERF file. Cannot continue with extract.
    if (oRes = nil) or not bFound then begin
        raise EERFError.CreateHelp('Resource "' + sResRef + '.' + TERF_Resource.ResTypeToString(iResType) + '" could not be found in the ERF file. Unable to extract it!', 14);
    end;

    // If no filename has been specified, create one from the ResRef and ResType.
    if (sFilename = '') then begin
        sFilename := oRes.Resref;

        sExt := TERF_Resource.ResTypeToString(oRes.ResType);
        if (Length(sExt) > 0) then
            sFilename := sFilename + '.' + sExt;

        sFilename := ExtractFilePath(Application.ExeName) + sFilename;
    end;

    // Read data from ERF and write to new file on disk.
    oOut := TFileStream.Create(sFilename, fmCreate or fmShareExclusive);
    try
        if (oRes.datasize > 0) then begin
            f_file.Seek(oRes.dataoffset, soFromBeginning);
            oOut.CopyFrom(f_file, oRes.datasize);
        end;
    finally
        if (oOut <> nil) then begin
            oOut.free();
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Delete a resource from the ResourceList array, preventing it from being
// written back to the file on Save.
// -----------------------------------------------------------------------------
procedure TERFHandler.DeleteResource(sResref : string; iResType : WORD);
var
   oRes    : TERF_Resource;
   arrTemp : TERF_ResArray;
   i       : integer;
   n       : integer;
   iCnt    : integer;
   sName   : string;
begin
    if not f_loaded then
        raise EERFError.CreateHelp('Unable to delete resource from file, no ERF file is open!', 4);


    for i := Low(f_reslist) to High(f_reslist) do begin
        oRes := f_reslist[i];
        if (lowercase(oRes.ResRef) = lowercase(sResref)) and (oRes.ResType = iResType) then begin

            // Let's do it the Brute Force way instead for now since the
            // nicer way don't work.... :(
            if (i = High(f_reslist)) then begin
                SetLength(f_reslist, Length(f_reslist) - 1);
            end
            else begin
                arrTemp := f_reslist;
                f_reslist := nil;
                SetLength(f_reslist, Length(arrTemp) - 1);

                iCnt := 0;
                for n := Low(arrTemp) to High(arrTemp) do begin
                    if (arrTemp[n] <> oRes) then begin
                        f_reslist[iCnt] := arrTemp[n];
                        inc(iCnt);
                    end;
                end;
                arrTemp := nil;
            end;

            oRes.free();

            // Decrease the field counter for the struct
            // FIX(2006-05-20) Use the correct header type depending on
            // file type.
            if (f_header.filetype = 'RIM ') then
                dec(TERF_RIMHeader(f_header).entrycount)
            else
                dec(TERF_ERFHeader(f_header).entrycount);
            f_dirty := true;
            exit;
        end;
    end;

    // ADDED(2006-05-17)
    // If we get here the resource wasn't found in the ERF file. Look for it
    // in the list of resources scheduled to be added on the next Save operation.
    // If found there, just remove it from the array.
    if (f_newlist.Count > 0) then begin
        sName := TERF_Resource.ResTypeToString(iResType);
        sName := lowercase(sResRef + '.' + sName);
        for i := 0 to (f_newlist.Count - 1) do begin
            if (lowercase(ExtractFileName(f_newlist[i])) = sName) then begin
                f_newlist.Delete(i);
                f_namelist.Delete(i);
                exit;
            end;
        end;
    end;

    raise EERFError.CreateHelp('Unable to delete resource from file, resource "' + sResref + '" not found!', 8);
end;


// -----------------------------------------------------------------------------
// ADDED(2006-05-17)
// Check if the filename specified already exists as a resource within this ERF
// file. If so it returns TRUE. If the resource was not found it returns FALSE.
// -----------------------------------------------------------------------------
function TERFHandler.GetResourceExists(sFilename : string; bCheckNew : boolean = false) : boolean;
var
   oRes    : TERF_Resource;
   i       : integer;
   iType   : WORD;
   sResref : string;
begin
    // Stop if no ERF file is loaded into this object.
    if not f_loaded then
        raise EERFError.CreateHelp('Unable to get resource from file, no ERF file is open!', 3);

    sResref := lowercase(copy(sFilename, 1, Pos(ExtractFileExt(sFilename), sFilename) - 1));
    sResref := StringToResRef(sResref);
    iType   := TERF_Resource.StringToResType(ExtractFileExt(sFilename));

    // Find the resource to extract in the ResourceList...
    result := false;
    for i := Low(f_reslist) to High(f_reslist) do begin
        oRes := f_reslist[i];
        if (lowercase(oRes.ResRef) = sResref) and (oRes.ResType = iType) then begin
            result := true;
            exit;
        end;
    end;

    // Then look in the NewList for files that are to be added but haven't
    // been saved yet, if instructed to do so.
    if bCheckNew then begin
        for i := 0 to (f_newlist.Count - 1) do begin
            // FIX(2006-05-17) Need to check the is-to-be resref name as well and not
            // just that it's the same file. Otherwise two different files might end
            // up with the same ResRef if they are different but contains characters
            // that gets truncated when they get saved into the ERF.
            if (lowercase(ExtractFileName(f_newlist[i])) = lowercase(ExtractFileName(sFilename)))
                or ((StringToResRef(lowercase(copy(f_newlist[i], 1, Pos(ExtractFileExt(f_newlist[i]), f_newlist[i]) - 1))) = sResref)
                    and (lowercase(ExtractFileExt(f_newlist[i])) = lowercase(ExtractFileExt(sFilename))))
            then begin
                result := true;
                exit;
            end;
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Get Method, fetch the Resource Info at the specified index in the Array.
// -----------------------------------------------------------------------------
function TERFHandler.GetInfoByIndex(iIdx : integer) : TERF_Resource;
begin
    if (iIdx > (Length(f_reslist) - 1)) or (iIdx < 0) then
        raise EERFError.CreateHelp('Cannot get resource info! Array index out of bounds!', 7);

    result := f_reslist[iIdx];
end;


// -----------------------------------------------------------------------------
// Get the number of resources/files this ERF archive contains.
// -----------------------------------------------------------------------------
function TERFHandler.GetResCount() : integer;
begin
    result := Length(f_reslist);
end;


// -----------------------------------------------------------------------------
// Get the number of resources/files that will be added to the ERF on save.
// -----------------------------------------------------------------------------
function TERFHandler.GetNewCount() : integer;
begin
    result := f_newlist.Count;
end;




end.
 
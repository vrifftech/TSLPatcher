unit UGFFFile;
// =============================================================================
// CLASS FOR READING, HANDLING AND WRITING BIOWARE GFF V3.2 FORMAT FILES.
// =============================================================================
// Main class:   TGFFFile
// Last changed: 2006-01-09
// Version:      1.0.1a
// -----------------------------------------------------------------------------
//
// KNOWN PROBLEMS:
// --------------
// * Currently no support for modifying DWORD64 fields. I *really* could use a
//   newer version of Delphi that has this data type... :/
//
// * Currently no support for modifying VOID/Binary values, because I am lazy...
//
// * Root struct Field iterator only supports one concurrent loop. Use the root
//   and fields properties for now if additional loops are needed.
//
// * Internal data structure is poorly protected, but since I'm the only one using
//   this I'll have to manually take care to modify things the correct way. :)
//
//
// Version history: (as far as I remember to update it)
// ----------------
// 1.0.2.a (2007-08-13)
// * Modified SetStringByID() method in ExoLocString class so it will add a new
//   substring if the one it tries to set does not exist if the new third optional
//   parameter is set to true.
//
// 1.0.1a (2006-01-09)
// * Added ChangeFieldValue() shortcut function to allow quickly changing the
//   value of most types of fields as a string regardless of what kind of datatype
//   the field is. This is mostly meant for TSLPatcher and thus uses that syntax
//   for changing EcoLocStrings, Positions and Orientations.
//
// 1.0 (2005-10-08)
// * Handler and support classes rewritten from scratch to get rid of the
//   horribly awkward internal data handling of the previous version.
//
// * Changed internal data keeping model into a logical Tree structure.
//
// * Rewritten all logic for reading and writing files from to accomodate
//   the new internal file format.
//
// * Added functionality to fetch a field by label-path.
//
// * Added functionality for adding new fields to the tree structure.
//
// * Added functionality for deleting fields/sections of the tree structure.
//
// * Added functionality to TGFF_CExoLocString for adding and removing substrings.
//
// * Added Clone() method to the TGFF_Field superclass which will clone the field
//   and any sub-fields in case of a LIST or STRUCT field. (Not very pretty right
//   now since it isn't virtual to be overridden in the subclasses. The superclass
//   currently does all the work.)


interface

uses SysUtils, Classes, Windows, UStrTok, UST_Common;

// Size of buffers used for some read/write operations...
const BYTE_BUFFER_SIZE         = 4096;
const TEXT_BUFFER_SIZE         = 32768;

// GFFField type definition constants...
const FIELD_TYPE_BYTE          = 0;
const FIELD_TYPE_CHAR          = 1;
const FIELD_TYPE_WORD          = 2;
const FIELD_TYPE_SHORT         = 3;
const FIELD_TYPE_DWORD         = 4;
const FIELD_TYPE_INT           = 5;
const FIELD_TYPE_DWORD64       = 6;
const FIELD_TYPE_INT64         = 7;
const FIELD_TYPE_FLOAT         = 8;
const FIELD_TYPE_DOUBLE        = 9;
const FIELD_TYPE_CEXOSTRING    = 10;
const FIELD_TYPE_RESREF        = 11;
const FIELD_TYPE_CEXOLOCSTRING = 12;
const FIELD_TYPE_VOID          = 13;
const FIELD_TYPE_STRUCT        = 14;
const FIELD_TYPE_LIST          = 15;
const FIELD_TYPE_ORIENTATION   = 16;
const FIELD_TYPE_POSITION      = 17;

type
// -----------------------------------------------------------------------------
// SOME TYPE DEFINITIONS
// -----------------------------------------------------------------------------

// Fixed length types...
T4Char  = array [0..3]                of Char;
T16Char = array [0..15]               of Char;
T8Bytes = array [0..7]                of Byte;
TBuffer = array [0..TEXT_BUFFER_SIZE] of Char;

// Variable length types...
TChars      = array of Char;
TBytes      = array of Byte;
TFieldIndex = array of DWORD;


// -----------------------------------------------------------------------------
// SUPPORT CLASSES USED WHEN SAVING/LOADING FILES
// -----------------------------------------------------------------------------

TGFF_Header = class(TObject)
    filetype     : T4Char;     // Filetype, ie GFF, UTI, UTC, DLG etc...
    fileversion  : T4Char;     // Version of GFF format, should be V3.2

    structoffset : DWORD;      // Absolute offset where stuct array begins
    structcount  : DWORD;      // Number of elements in the Struct array

    fieldoffset  : DWORD;      // Absolute offset where field array begind
    fieldcount   : DWORD;      // Number of elements in the field array

    labeloffset  : DWORD;
    labelcount   : DWORD;      // Number of elements in the labels array

    fielddataoffset : DWORD;
    fielddatacount  : DWORD;   // Bytes occupied by the field data block

    fieldindexoffset : DWORD;
    fieldindexcount  : DWORD;  // Bytes occupied by the field index array

    listindexoffset  : DWORD;
    listindexcount   : DWORD;  // Bytes occupied by listindex array
end;


TGFF_SaveData = class(TObject)
    // Data needed to build file header
    StructCount     : DWORD;
    FieldCount      : DWORD;
    FieldIndexCount : DWORD;
    ListIndexCount  : DWORD;
    ListCount       : DWORD;
    DataBlockSize   : DWORD;
    FieldLabels     : array of T16Char;

    // Data to keep track of write progress in the sections
    CurrStructIndex      : DWORD;
    CurrStructOffset     : DWORD;
    CurrFieldIndex       : DWORD;
    CurrFieldOffset      : DWORD;
    CurrFieldDataOffset  : DWORD;
    CurrFieldIndexOffset : DWORD;
    CurrListIndexOffset  : DWORD;

    procedure AddLabel(sLabel : T16Char);
    constructor Create();
    destructor Destroy(); override;
end;


// -----------------------------------------------------------------------------
// EXCEPTION TYPE USED BY THESE CLASSES....
// -----------------------------------------------------------------------------

EGFFError = class(Exception);
          

// -----------------------------------------------------------------------------
// GFF CLASS TYPE DATACARRIERS
// -----------------------------------------------------------------------------

TGFFField = class(TObject) // ABSTRACT super-class for all GFF data types.
    private
        l_label : T16Char;
        l_type  : DWORD;
    public
        procedure SetLabel(sLabel : string);
        procedure SetLabelRaw(sLabel : T16Char);
        function GetLabel() : string;
        function GetLabelRaw() : T16Char;
        function GetString() : string;

        function Clone() : TGFFField;   // This really should be virtual+abstract but I can't be bothered right now :)
        constructor Create(); overload;
        constructor Create(sLabel : string); overload;
        destructor Destroy(); override;

        property fieldtype     : DWORD     read l_type        write l_type;
        property fieldlabel    : string    read GetLabel      write SetLabel;
        property fieldlabelraw : T16Char   read GetLabelRaw   write SetLabelRaw;
        property text          : string    read GetString;
end;


TGFFStruct = class(TGFFField)
    private
        l_fields : array of TGFFField;
        l_type   : DWORD;   // The custom, programmer-set Struct Type-ID.
        l_count  : DWORD;   // The number of fields in this Struct.

        function GetField(i : integer) : TGFFField;
    public
        procedure AddField(oField : TGFFField);
        procedure DeleteField(sLabel : string);

        function GetFieldByLabel(sLabel : string) : TGFFField;

        constructor Create(); overload;
        constructor Create(sLabel : string); overload;
        Destructor Destroy(); override;

        property typeid              : DWORD        read l_type    write l_type;
        property count               : DWORD        read l_count;
        property fields[i : integer] : TGFFField    read GetField;
end;


TGFFList = Class(TGFFField)
    private
        l_count : DWORD;
        l_structs : array of TGFFStruct;

        function GetStruct(iIndex : integer) : TGFFStruct;
    public
        procedure AddStruct(oStruct : TGFFStruct);
        procedure DeleteStruct(iIndex : DWORD);

        constructor Create(); overload;
        constructor Create(sLabel : string); overload;
        destructor Destroy(); override;

        property count                 : DWORD           read l_count;
        property structs[i : integer]  : TGFFStruct      read GetStruct;

end;

// -----------------------------------------------------------------------------
// GFF DATATYPE WRAPPER CLASSES
// -----------------------------------------------------------------------------


TGFF_SByte = class(TGFFField)
    value : Byte;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : Byte); overload;
end;

TGFF_SChar = class(TGFFField)
    value : Char;

    constructor Create(); overload;
    constructor Create(sLabel : string; cData : Char); overload;
end;

TGFF_SWord = class(TGFFField)
    value : Word;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : Word); overload;
end;

TGFF_SShort = class(TGFFField)
    value : SmallInt;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : SmallInt); overload;
end;

TGFF_SDWORD = class(TGFFField)
    value : DWORD;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : DWORD); overload;
end;

TGFF_SInt = class(TGFFField)
    value : LongInt;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : LongInt); overload;
end;

TGFF_CDWORD64 = class(TGFFField)
    value : T8Bytes;

    constructor Create(); overload;
    constructor Create(sLabel : string; aData : T8Bytes); overload;
end;

TGFF_CInt64 = class(TGFFField)
    value : Int64;

    constructor Create(); overload;
    constructor Create(sLabel : string; iData : Int64); overload;
end;

TGFF_SFloat = class(TGFFField)
    value : Single;

    constructor Create(); overload;
    constructor Create(sLabel : string; fData : Single); overload;
end;

TGFF_CDouble = class(TGFFField)
    value : Double;

    constructor Create(); overload;
    constructor Create(sLabel : string; fData : Double); overload;
end;

TGFF_CExoString = class(TGFFField)
    size : DWORD;
    text : TChars;

    constructor Create(); overload;
    constructor Create(sLabel : string; sData : string); overload;
    destructor Destroy(); override;
    procedure SetString(sText : string);
    function GetString() : string;

    // Use this property rather than the Get/Set methods to access the text...
    property textstring : string     read GetString   write SetString;
end;

TGFF_CResRef = class(TGFFField)
    size : Byte;
    text : TChars;

    constructor Create(); overload;
    constructor Create(sLabel : string; sData : string); overload;
    destructor Destroy(); override;
    procedure SetString(sText : string);
    function GetString() : string;

    // Use this property rather than the Get/Set methods to access the text...
    property textstring : string     read GetString   write SetString;
end;

// Support class for CExoLocString
TGFF_CSubString = class (TObject)
    stringid     : LongInt;
    stringlength : LongInt;
    text         : TChars;

    constructor Create(); overload;
    constructor Create(nID : LongInt; sText : string); overload;
    destructor Destroy(); override;

    procedure SetString(sText : string);
    function GetString() : string;

    // Use this property rather than the Get/Set methods to access the text...
    property textstring : string     read GetString   write SetString;
end;

TGFF_CExoLocString = class(TGFFField)
    bytesize     : DWORD; // Size of whole structure, excluding this field.
    strref       : DWORD;
    stringcount  : DWORD;
    substrings   : array of TGFF_CSubString;

    constructor Create(); overload;
    constructor Create(sLabel : string; iStrRef : DWORD); overload;
    destructor Destroy(); override;

    procedure AddString(iLangID : integer; sText : string);
    procedure SetString(iIndex : integer; sText : string);
    procedure DeleteString(iIndex : integer);
    procedure DeleteStringByID(iLangID : integer);
    procedure SetStringByID(iLangID : integer; sText : string; bAddIfMissing : boolean = false);  // CHANGED(2007-08-13) Added bAddIfMissing parameter
    function  GetStringById(iLangID : integer) : string;
    function  GetString(iIndex : integer) : string;

    property strings[i:integer] : string     read GetString    write SetString;
end;

TGFF_CVoid = class(TGFFField)
    bytesize : DWORD;
    data     : TBytes;

    constructor Create(); overload;
    constructor Create(sLabel : string; aData : TBytes); overload;
    destructor Destroy(); override;
end;

// FIX(2005-05-31) Undocumented type added in KotOR...
TGFF_COrientation = class(TGFFField)
    value : array [0..3] of Single;

    constructor Create(); overload;
    constructor Create(sLabel : string; fData1 : Single; fData2 : Single; fData3 : Single; fData4 : Single); overload;
end;

// FIX(2005-05-31) Undocumented type added in KotOR...
TGFF_CPosition = class(TGFFField)
    value : array [0..2] of Single;

    constructor Create(); overload;
    constructor Create(sLabel : string; fX : Single; fY : Single; fZ : Single); overload;
end;

// -----------------------------------------------------------------------------
// MAIN GFF HANDLER CLASS
// -----------------------------------------------------------------------------

TGFFFile = class(TObject)
    private
        l_filetype     : T4Char;        // 4 character file type (UTI, DLG etc...)
        l_fileversion  : T4Char;        // 4 character version info (e.g. V1.0)
        l_filename     : string;        // Path/Name of the currently loaded file.

        l_rootstruct   : TGFFStruct;    // Root struct containing the data in this file
        l_currfield    : DWORD;         // Iterator for fetching the fields in the Root Struct.

        l_isloaded     : boolean;       // Set to TRUE when a file has been loaded into this object
        l_isdirty      : boolean;       // Set to TRUE if the GFF data has been changed since the file has been loaded.
        l_file         : TFileStream;   // File handle, used for reading and writing from the file on disk.
        l_header       : TGFF_Header;   // Reference to File Header object. Used when loading a file.
        l_savedata     : TGFF_SaveData; // Temporary container used to collect data when saving a file...

        procedure ResetAll();

        // Get/Set methods for the Type and Version properties.
        procedure SetType(sType : string);
        procedure SetVersion(sVersion : string);
        function GetType() : string;
        function GetVersion() : string;

        // Functions used to load file data...
        function LoadFileStruct(iOffset : DWORD) : TGFFStruct;
        function LoadFileField(iOffset : DWORD) : TGFFField;
        function LoadComplexField(iType : DWORD; iDataOrOffset : DWORD) : TGFFField;

        // Functions used to save the data to a file...
        function SaveGetLabelIndex(sLabel : T16Char) : DWORD;
        function SaveProcessList(oList : TGFFList) : DWORD;
        function SaveProcessComplexFieldData(oField : TGFFField) : DWORD;
        function SaveProcessField(oField : TGFFField) : DWORD;
        function SaveProcessStruct(oStruct : TGFFStruct) : DWORD;
        function GetIsComplexField(oField : TGFFField) : boolean;
        function GetFieldDataSize(oField : TGFFField) : DWORD;
        procedure SaveParseList(oList : TGFFList);
        procedure SaveParseStruct(oStruct : TGFFStruct);
        procedure SaveProcessLabels();
    public
        // Functions for retrieving the data fields
        function GetFieldByLabel(sFieldPath : string) : TGFFField;
        function GetFirstRootField() : TGFFField;
        function GetNextRootField() : TGFFField;

        // functions for adding new fields or deleting existing ones
        procedure AddField(oField : TGFFField; sPath : string);
        procedure DeleteField(sFieldPath : string);
        function ChangeFieldValue(sPath : string; sValue : string) : boolean;

        // Functions for creating/loading/saving a GFF file.
        procedure NewFile(sType : string; sFilename : string = '');
        procedure LoadFile(sFilename : string);
        procedure SaveFile(sFilename : string = '');

        constructor Create();
        destructor Destroy(); override;

        property filetype : string      read GetType         write SetType;
        property version  : string      read GetVersion      write SetVersion;
        property filename : string      read l_filename;
        property loaded   : boolean     read l_isloaded;
        property dirty    : boolean     read l_isdirty       write l_isdirty;
        property root     : TGFFStruct  read l_rootstruct;

end;

implementation


// =============================================================================
// CLASS FUNCTIONS: TGFFFile
// =============================================================================


// -----------------------------------------------------------------------------
// CONSTRUCTOR - Initializes the GFF File Handler
// -----------------------------------------------------------------------------
constructor TGFFFile.Create();
var
   i : integer;
begin
    inherited Create();
    for i := Low(l_filetype) to High(l_filetype) do
        l_filetype[i] := #0;

    for i := Low(l_fileversion) to High(l_fileversion) do
        l_fileversion[i] := #0;

    l_filename   := '';
    l_currfield  := 0;
    l_rootstruct := nil;
    l_isloaded   := False;
    l_isdirty    := False;
    l_file       := nil;
    l_header     := nil;
    l_savedata   := nil;
end;


// -----------------------------------------------------------------------------
// DESTRUCTOR - Destroys the GFF File Handler and all data it has loaded.
// -----------------------------------------------------------------------------
destructor TGFFFile.Destroy();
begin
    ResetAll();
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Deletes all stored data, if any, and restores the GFF Handler to its
// starting state.
// -----------------------------------------------------------------------------
procedure TGFFFile.ResetAll();
var
   i : integer;
begin
    l_isloaded   := False;
    l_isdirty    := False;
    l_filename   := '';

    // Destroy the Root Struct and all GFF fields below it in the hierarchy
    if (l_rootstruct <> nil) then begin
        l_rootstruct.free();
        l_rootstruct := nil;
    end;

    // Reset the file type
    for i:= Low(l_filetype) to High(l_filetype) do
        l_filetype[i] := #0;

    // Reset the file version
    for i := Low(l_fileversion) to High(l_fileversion) do
        l_fileversion[i] := #0;

    // If the FileStream hasn't been destroyed, do it.
    if (l_file <> nil) then begin
        l_file.free();
        l_file := nil;
    end;

    // If the header exists, destroy it.
    if (l_header <> nil) then begin
        l_header.free();
        l_header := nil;
    end;
end;


//// FILE LOADING METHODS //////////////////////////////////////////////////////


// -----------------------------------------------------------------------------
// Creates a new blank GFF file of the specified type (DLG, GIT, UTC etc...).
// -----------------------------------------------------------------------------
procedure TGFFFile.NewFile(sType : string; sFilename : string = '');
begin
    ResetAll();
    
    l_filename          := sFilename;
    Self.filetype       := sType;
    Self.version        := 'V3.2';

    l_rootstruct        := TGFFStruct.Create();
    l_rootstruct.typeid := $FFFFFFFF;

    l_isloaded          := True;
    l_isdirty           := False;
end;


// -----------------------------------------------------------------------------
// Main function for loading a new GFF file into this object. The sFilename must
// contain the path and name to a GFF V3.2 format file to load.
// -----------------------------------------------------------------------------
procedure TGFFFile.LoadFile(sFilename : string);
begin
    if not FileExists(sFilename) then
       raise EGFFError.CreateHelp('Specified file ' + sFilename + ' could not be found to be opened!', 0);

    ResetAll();
    l_header := TGFF_Header.Create();
    l_file   := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyWrite);

    try
        if (l_file = nil) then
            raise EGFFError.CreateHelp('Unable to load Header information, no file has been opened!', 0);
        
        // READ THE HEADER INFORMATION!
        l_file.read(l_header.filetype, 4);
        l_file.read(l_header.fileversion, 4);
        
        // Format version mismatch, unable to continue.
        if (l_header.fileversion <> 'V3.2') then begin
            ResetAll();
            raise EGFFError.CreateHelp('Invalid file version. Loaded file is not in GFF V3.2 format!', 1);
        end;

        l_filename    := sFilename;
        l_filetype    := l_header.filetype;
        l_fileversion := l_header.fileversion;
        
        // Read in the Struct Array offset & count
        l_file.Read(l_header.structoffset, sizeof(l_header.structoffset));
        l_file.Read(l_header.structcount, sizeof(l_header.structcount));
        
        // Read in the Field Array offset & count
        l_file.Read(l_header.fieldoffset, sizeof(l_header.fieldoffset));
        l_file.Read(l_header.fieldcount, sizeof(l_header.fieldcount));
        
        // Read in the Label Array offset & count
        l_file.Read(l_header.labeloffset, sizeof(l_header.labeloffset));
        l_file.Read(l_header.labelcount, sizeof(l_header.labelcount));
        
        // Read in the File Data Block offset & count
        l_file.Read(l_header.fielddataoffset, sizeof(l_header.fielddataoffset));
        l_file.Read(l_header.fielddatacount, sizeof(l_header.fielddatacount));
        
        // Read in the Field Index Array offset & count
        l_file.Read(l_header.fieldindexoffset, sizeof(l_header.fieldindexoffset));
        l_file.Read(l_header.fieldindexcount, sizeof(l_header.fieldindexcount));
        
        // Read in the List Index Array offset & count
        l_file.Read(l_header.listindexoffset, sizeof(l_header.listindexoffset));
        l_file.Read(l_header.listindexcount, sizeof(l_header.listindexcount));
        
        // READ ALL THE GFF FIELDS INTO A TREE STRUCTURE UNDER THE ROOT STRUCT...
        l_rootstruct := LoadFileStruct(l_header.structoffset);
        
        // Everything should have been loaded if we've gotten this far...
        l_isloaded := True; 
    finally
        if (l_file <> nil) then
            l_file.free();
            
        if (l_header <> nil) then
            l_header.free();
            
        l_file := nil;
        l_header := nil;
        l_isdirty := False;
    end;
end;


// -----------------------------------------------------------------------------
// Loads the data for a Complex data type from the file and stores it in a new
// TGFFField sub-object, which the function then returns. This function does
// not do anything with the STRUCT and LIST types.
// -----------------------------------------------------------------------------
function TGFFFile.LoadComplexField(iType : DWORD; iDataOrOffset : DWORD) : TGFFField;
var
    i, n        : integer;
    iNext       : integer;
    iReadBuffer : integer;
    iReadBlock  : integer;
    sBuffer     : TBuffer;
    iBuffer     : array [0..BYTE_BUFFER_SIZE] of Byte;
    oField      : TGFFField;    
    
    oExoString    : TGFF_CExoString;
    oResref       : TGFF_CResRef;   
    oExoLocString : TGFF_CExoLocString;
    oSubString    : TGFF_CSubString;
    oVoid         : TGFF_CVoid;
    oOrientation  : TGFF_COrientation;
    oPosition     : TGFF_CPosition; 
begin
    l_file.Seek(l_header.fielddataoffset + iDataOrOffset, soFromBeginning);
    
    case (iType) of
        FIELD_TYPE_DWORD64: begin
            oField := TGFF_CDWORD64.Create();
            l_file.read((oField as TGFF_CDWORD64).value, sizeof((oField as TGFF_CDWORD64).value));
        end;
        

        FIELD_TYPE_INT64: begin
            oField := TGFF_CInt64.Create();
            l_file.read((oField as TGFF_CInt64).value, sizeof((oField as TGFF_CInt64).value));            
        end;
        

        FIELD_TYPE_DOUBLE: begin
            oField := TGFF_CDouble.Create();
            l_file.read((oField as TGFF_CDouble).value, sizeof((oField as TGFF_CDouble).value));            
        end;


        FIELD_TYPE_CEXOSTRING: begin
            oExoString := TGFF_CExoString.Create();
            l_file.read(oExoString.size, sizeof(oExoString.size));
            SetLength(oExoString.text, oExoString.size);
            
            // REWRITE: Support ExoStrings of arbitrary length rather than have a fixed
            //          read buffer like before. Check that this works!
            iNext := Low(oExoString.text);
            iReadBuffer := oExoString.size;
            while (iReadBuffer > 0) do begin
                iReadBlock := iReadBuffer;
                if (iReadBlock > TEXT_BUFFER_SIZE) then
                    iReadBlock := TEXT_BUFFER_SIZE;
                   
                    l_file.read(sBuffer, iReadBlock);
                   
                    for i := Low(sBuffer) to (iReadBlock-1) do begin
                        if (iNext > High(oExoString.text)) then
                            raise EGFFError.CreateHelp('Error loading CExoString, overflow when loading text!', 6);
                    
                        oExoString.text[iNext] := sBuffer[i];
                        inc(iNext);
                    end;   
                       
                   iReadBuffer := iReadBuffer - iReadBlock;   
            end;

            oField := oExoString;
        end;


        FIELD_TYPE_RESREF: begin
            oResRef := TGFF_CResRef.Create();
            l_file.read(oResRef.size, sizeof(oResRef.size));

            // Error! Text is longer than the max 16 character length of a ResRef
            if (oResRef.size > 16) then
               raise EGFFError.CreateHelp('Error loading CResRef field, string is too long!', 8);

            l_file.read(sBuffer, oResRef.size);
            SetLength(oResRef.text, oResRef.size);
            for i := Low(oResRef.text) to High(oResRef.text) do
                oResRef.text[i] := sBuffer[i];

            oField := oResRef;
        end;


        FIELD_TYPE_CEXOLOCSTRING: begin
            oExoLocString := TGFF_CExoLocString.Create();
            l_file.Read(oExoLocString.bytesize, sizeof(oExoLocString.bytesize));
            l_file.Read(oExoLocString.strref, sizeof(oExoLocString.strref));
            l_file.Read(oExoLocString.stringcount, sizeof(oExoLocString.stringcount));

            if (oExoLocString.stringcount > 0) then begin
                SetLength(oExoLocString.substrings, oExoLocString.stringcount);
                for i := 0 to (oExoLocString.stringcount - 1) do begin
                    // This is UGLY... The ExoLocStr class should handle its substrings instead...
                    // ...some time when I feel like doing things the proper way... :)
                    oSubString := TGFF_CSubString.Create();
                    l_file.Read(oSubString.stringid, sizeof(oSubString.stringid));
                    l_file.Read(oSubString.stringlength, sizeof(oSubString.stringlength));

                    if (oSubString.stringlength > 0) then begin
                        SetLength(oSubString.text, oSubString.stringlength);
                        
                        // REWRITE: Support Substrings of arbitrary length rather than have a fixed
                        //          read buffer like before. Check that this works!
                        iNext := 0;
                        iReadBuffer := oSubString.stringlength;
                        while (iReadBuffer > 0) do begin
                            iReadBlock := iReadBuffer;
                            if (iReadBlock > TEXT_BUFFER_SIZE) then
                                iReadBlock := TEXT_BUFFER_SIZE;
                               
                                l_file.read(sBuffer, iReadBlock);
                               
                                for n := 0 to (iReadBlock-1) do begin
                                    if (iNext > (oSubString.stringlength-1)) then
                                        raise EGFFError.CreateHelp('Error loading CExoLocSubstring, overflow when loading text!', 10);
                                
                                    oSubString.text[iNext] := sBuffer[n];
                                    inc(iNext);
                                end;   
                                   
                               iReadBuffer := iReadBuffer - iReadBlock;   
                        end;                    
                    end;

                    oExoLocString.substrings[i] := oSubString;
                end;
            end;
            oField := oExoLocString;
        end;


        FIELD_TYPE_VOID: begin
            oVoid := TGFF_CVoid.Create();
            l_file.read(oVoid.bytesize, sizeof(oVoid.bytesize));
            SetLength(oVoid.data, oVoid.bytesize);

            // REWRITE: Support binary data of arbitrary length rather than have a fixed
            //          read buffer like before. Check that this works!              
            iNext := Low(oVoid.data);
            iReadBuffer := oVoid.bytesize;
            while (iReadBuffer > 0) do begin
                iReadBlock := iReadBuffer;
                if (iReadBlock > BYTE_BUFFER_SIZE) then
                    iReadBlock := BYTE_BUFFER_SIZE;
                   
                    l_file.read(iBuffer, iReadBlock);
                   
                    for i := Low(iBuffer) to (iReadBlock-1) do begin
                        if (iNext > High(oVoid.data)) then
                            raise EGFFError.CreateHelp('Error loading Binary/Void data, attempted read past end of data space.', 9);
                    
                        oVoid.data[iNext] := iBuffer[i];
                        inc(iNext);
                    end;   
                       
                   iReadBuffer := iReadBuffer - iReadBlock;   
            end; 
            
            oField := oVoid;             
        end;
        
        
        FIELD_TYPE_ORIENTATION: begin
            // Added this, new undocumented KotOR field type...
            oOrientation := TGFF_COrientation.Create();
            for i := 0 to 3 do
                l_file.read(oOrientation.value[i], 4);

            oField := oOrientation;
        end;


        FIELD_TYPE_POSITION: begin
            // Added this, new undocumented KotOR field type, looks like a Vector...        
            oPosition := TGFF_CPosition.Create();
            for i := 0 to 2 do
                l_file.read(oPosition.value[i], 4);

            oField := oPosition;
        end;
    else
        raise EGFFError.CreateHelp('Invalid field type encountered when reading field ' + IntToStr(iType) + ' data!', 5);
    end;

    Result := oField;   

end;


// -----------------------------------------------------------------------------
// Loads the data for a GFF Field from the file and stores it in a new TGFFField
// object, which the function then returns.
// -----------------------------------------------------------------------------
function TGFFFile.LoadFileField(iOffset : DWORD) : TGFFField;
var
    iType         : DWORD;
    iLabelIndex   : DWORD;
    iDataOrOffset : DWORD;
    
    oField        : TGFFField;
    oList         : TGFFList;
    sLabel        : T16Char;
    iFieldOffset  : DWORD;
    iListCount    : DWORD;
    iStructIndex  : DWORD;
    i             : integer;
begin
    oField := nil;

    l_file.Seek(iOffset, soFromBeginning);
    l_file.read(iType, sizeof(iType));  
    l_file.read(iLabelIndex, sizeof(iLabelIndex));  
    
    // Read the field data depending on datatype.
    case (iType) of
        FIELD_TYPE_BYTE: begin
            oField := TGFF_SByte.Create();
            l_file.read((oField as TGFF_SByte).value, sizeof((oField as TGFF_SByte).value));
        end;
        
        FIELD_TYPE_CHAR: begin
            oField := TGFF_SChar.Create();
            l_file.read((oField as TGFF_SChar).value, sizeof((oField as TGFF_SChar).value));        
        end;
        
        FIELD_TYPE_WORD: begin
            oField := TGFF_SWord.Create();
            l_file.read((oField as TGFF_SWord).value, sizeof((oField as TGFF_SWord).value));        
        end;
        
        FIELD_TYPE_SHORT: begin
            oField := TGFF_SShort.Create();
            l_file.read((oField as TGFF_SShort).value, sizeof((oField as TGFF_SShort).value));      
        end;
        
        FIELD_TYPE_DWORD: begin
            oField := TGFF_SDWORD.Create();
            l_file.read((oField as TGFF_SDWORD).value, sizeof((oField as TGFF_SDWORD).value));              
        end;
        
        FIELD_TYPE_INT: begin
            oField := TGFF_SInt.Create();
            l_file.read((oField as TGFF_SInt).value, sizeof((oField as TGFF_SInt).value));      
        end;

        FIELD_TYPE_FLOAT: begin
            oField := TGFF_SFloat.Create();
            l_file.read((oField as TGFF_SFloat).value, sizeof((oField as TGFF_SFloat).value));          
        end;
        
        FIELD_TYPE_DWORD64, FIELD_TYPE_INT64, FIELD_TYPE_DOUBLE..FIELD_TYPE_VOID, FIELD_TYPE_ORIENTATION, FIELD_TYPE_POSITION: begin
            l_file.read(iDataOrOffset, sizeof(iDataOrOffset));  
            oField := LoadComplexField(iType, iDataOrOffset);
        end;
            
        FIELD_TYPE_STRUCT: begin
            l_file.read(iDataOrOffset, sizeof(iDataOrOffset));
            
            iFieldOffset := l_header.structoffset + (iDataOrOffset * 12);
            oField := LoadFileStruct(iFieldOffset); 
        end;
        
        FIELD_TYPE_LIST: begin
            l_file.read(iDataOrOffset, sizeof(iDataOrOffset));  
            l_file.Seek(l_header.listindexoffset + iDataOrOffset, soFromBeginning);
            l_file.read(iListCount, sizeof(iListCount));    
            
            oList := TGFFList.Create();
            
            for i := 1 to iListCount do begin
                iFieldOffset := l_header.listindexoffset + iDataOrOffset + (DWORD(i) * 4);
                l_file.Seek(iFieldOffset, soFromBeginning);
                l_file.read(iStructIndex, sizeof(iStructIndex));    
                
                oField := LoadFileStruct(l_header.structoffset + (iStructIndex * 12));  
                oList.AddStruct((oField as TGFFStruct));                    
            end;
            
            oField := oList;
        end;
    end;

    // Get and store the field label...
    if (oField <> nil) then begin
        l_file.Seek(l_header.labeloffset + (iLabelIndex * 16), soFromBeginning);
        l_file.read(sLabel, sizeof(sLabel));
        oField.fieldlabelraw := sLabel;
    end;

    oField.fieldtype := iType;

    Result := oField;
end;


// -----------------------------------------------------------------------------
// Loads a STRUCT data type from the file, creates a new TGFFStruct object to
// store it in, retrieves any fields it contains and stores them in it. This
// struct object is then returned by the function.
// -----------------------------------------------------------------------------
function TGFFFile.LoadFileStruct(iOffset : DWORD) : TGFFStruct;
var
    oStruct       : TGFFStruct;
    oField        : TGFFField;
    iType         : DWORD;
    iDataOrOffset : DWORD;
    iFieldCount   : DWORD;
    iFieldOffset  : DWORD;
    iFieldIndex   : DWORD;
    i             : integer;
begin
    l_file.Seek(iOffset, soFromBeginning);
    l_file.read(iType, sizeof(iType));  
    l_file.read(iDataOrOffset, sizeof(iDataOrOffset));
    l_file.read(iFieldCount, sizeof(iFieldCount));
    
    // Create the new STRUCT object...
    oStruct := TGFFStruct.Create();
    oStruct.typeid := iType;
    
    // Struct only has one field. Fetch it directly from the FieldArray
    if (iFieldCount = 1) then begin
        iFieldOffset := l_header.fieldoffset + (iDataOrOffset * 12);
        oField := LoadFileField(iFieldOffset);
        oStruct.AddField(oField);
    end
    // Struct has many fields. Get their indexes from the FieldIndexarray and look them up.
    else if (iFieldCount > 1) then begin
        for i := 0 to (iFieldCount-1) do begin
            // Fetch a FieldArray index from the FieldIndexArray
            iFieldOffset := l_header.fieldindexoffset + iDataOrOffset + (DWORD(i) * 4);
            l_file.Seek(iFieldOffset, soFromBeginning);
            l_file.read(iFieldIndex, sizeof(iFieldIndex));  
            
            // Look up the retrieved index in the FieldArray
            iFieldOffset := l_header.fieldoffset + (iFieldIndex * 12);   
            oField := LoadFileField(iFieldOffset);
            oStruct.AddField(oField);
        end;
    end;
    
    // NOTE: A STRUCT without fields is a valid condition. It will be setup properly
    //       by the TGFFStruct constructor for that case, so just return the "empty" object.

    // Need to put this here too, since the root struct won't be run through LoadFileField().
    oStruct.fieldtype := FIELD_TYPE_STRUCT;
    
    Result := oStruct;
end;


///////// GET & SET METHODS ////////////////////////////////////////////////////


// -----------------------------------------------------------------------------
// Sets the file type of the current file (UTI, DLG, GFF, GIT etc...)
// -----------------------------------------------------------------------------
procedure TGFFFile.SetType(sType : string);
var
    i : integer;
begin
    l_isdirty := True;

    if (Length(sType) > 4) then
        sType := copy(sType, 1, 4);
        
    for i := Low(l_filetype) to High(l_filetype) do begin
        if (i < Length(sType)) then
            l_filetype[i] := sType[i+1]
        else
            l_filetype[i] := #0;
    end;
end;


// -----------------------------------------------------------------------------
// Sets the File version of the current file. This should ALWAYS be V3.2, so
// this might be a bit pointless currently, but whatever. :)
// -----------------------------------------------------------------------------
procedure TGFFFile.SetVersion(sVersion : string);
var
    i : integer;
begin
    l_isdirty := True;

    if (Length(sVersion) > 4) then
        sVersion := copy(sVersion, 1, 4);
        
    for i := Low(l_fileversion) to High(l_fileversion) do begin
        if (i < Length(sVersion)) then
            l_fileversion[i] := sVersion[i+1]
        else
            l_fileversion[i] := #0;
    end;
end;


// -----------------------------------------------------------------------------
// Gets the type of this file as a 4 character string. (UTI, DLG, GIT etc...)
// -----------------------------------------------------------------------------
function TGFFFile.GetType() : string;
var
    i : integer;
    sOut : string;
begin
    sOut := '';
    
    for i := Low(l_filetype) to High(l_filetype) do
        sOut := sOut + l_filetype[i];
        
    result := sOut;
end;


// -----------------------------------------------------------------------------
// Gets the version of the current file as a 4 character string. This should
// always be V3.2 or the file wouldn't have been loaded, so this is a touch
// pointless currently.
// -----------------------------------------------------------------------------
function TGFFFile.GetVersion() : string;
var
    i : integer;
    sOut : string;
begin
    sOut := '';
    
    for i := Low(l_fileversion) to High(l_fileversion) do
        sOut := sOut + l_fileversion[i];
        
    result := sOut;

end;


///////// FIELD HANDLING METHODS ///////////////////////////////////////////////


// -----------------------------------------------------------------------------
// Iterator for retrieving the fields in the Root Struct. Returns the first
// field in the struct. If the root struct contains no fields it returns nil.
// -----------------------------------------------------------------------------
function TGFFFile.GetFirstRootField() : TGFFField;
begin
    l_currfield := 0;
    
    if (l_rootstruct.count > 0) then
        result := l_rootstruct.fields[l_currfield]
    else
        result := nil;
end;


// -----------------------------------------------------------------------------
// Iterator for retrieving the fields in the root struct. GetFirstRootField()
// must be called first to get the first field, then this function will get
// the next field in sequence whenever it is called. When the end of the
// list of fields is reached, it returns nil.
// -----------------------------------------------------------------------------
function TGFFFile.GetNextRootField() : TGFFField;
begin
    inc(l_currfield);
    
    if (l_currfield < l_rootstruct.count) then
        result := l_rootstruct.fields[l_currfield]
    else
        result := nil;
end;


// -----------------------------------------------------------------------------
// Retreive the field located at the label path specified by the sFieldPath
// parameter. Each step in the hierarchy is separated by a backslash, like:
// ClassList\0\KnownList\1\Spell
// -----------------------------------------------------------------------------
function TGFFFile.GetFieldByLabel(sFieldPath : string) : TGFFField;
var
    oField : TGFFField;
    oToken : TStringTokenizer;
    
    sCurrLabel : string;
    iTokCount  : integer;

    function ParseList(oCheck : TGFFList) : TGFFField; forward;
    function ParseStruct(oCheck : TGFFStruct) : TGFFField;
    var
        i : integer;
    begin
        result := nil;

        for i := 0 to (oCheck.count-1) do begin
            // We have found a field with a label matching this part of the label path.
            if (oCheck.fields[i].fieldlabel = sCurrLabel) then begin
                // If this is the last part of the path, return the STRUCT field.
                if (iTokCount = (oToken.count-1)) then begin
                    result := oCheck.fields[i];
                end
                // There are more parts in the path, look for the next sub-field.
                else begin
                    // If its a STRUCT, look inside it for a field matching the next part of the LabelPath
                    if (oCheck.fields[i].fieldtype = FIELD_TYPE_STRUCT) then begin
                        inc(iTokCount);
                        sCurrLabel := oToken.next();
                        result := ParseStruct((oCheck.fields[i] as TGFFStruct));
                    end
                    // If its a LIST, look inside it for a struct index matching the next part of the LabelPath
                    else if (oCheck.fields[i].fieldtype = FIELD_TYPE_LIST) then begin
                        inc(iTokCount);
                        sCurrLabel := oToken.next();
                        result := ParseList((oCheck.fields[i] as TGFFList));
                    end
                    // It's another data type, but the path has more parts! Thus the path is invalid!
                    else begin
                        raise EGFFError.CreateHelp('Unable to retrieve struct field at path ' + sFieldPath + ', the field ' + oCheck.fields[i].fieldlabel + ' is not a LIST or STRUCT!', 1);
                    end;
                end;

                // Since we found a match, stop here no matter what. Field labels in a struct must be unique.
                exit;
            end;
        end;
    end;
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    function ParseList(oCheck : TGFFList) : TGFFField;
    var
        i : integer;
        iIndex : integer;
    begin
        result := nil;

        // ERROR! The field is a LIST, but the part in the LabelPath is not a number,
        // which is required as an index. The path is invalid, unable to proceed.
        if not GetIsNumber(sCurrLabel)  then
            raise EGFFError.CreateHelp('Unable to retrieve struct at path ' + sFieldPath + ', ' + sCurrLabel + ' is not a valid list index!', 0);

        iIndex := StrToInt(sCurrLabel);

        for i := 0 to (oCheck.count-1) do begin
            // We've found the list index matching the specified LabelPath.
            if (i = iIndex) then begin
                // If this is the end of the label path, return the Struct at that index.
                if (iTokCount = (oToken.count-1)) then begin
                    result := oCheck.structs[i];
                end
                // If there is more on the label path, look inside the found STRUCT for the rest.
                else begin
                    inc(iTokCount);
                    sCurrLabel := oToken.next();
                    result := ParseStruct(oCheck.structs[i]);
                end;

                exit;
            end;
        end;
    end;
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
begin
    result := nil;
    oToken := TStringTokenizer.Create(sFieldPath, '\');
    try
        if (oToken.count < 1) then
            raise EGFFError.CreateHelp('Invalid field path ' + sFieldPath + ' encountered! Unable to load specified field.', 0);

        oField := GetFirstRootField();
        sCurrLabel := oToken.first();
        iTokCount  := 0;

        while (oField <> nil) do begin
            // If this field in the root struct matches the first part of the label,
            // examine that field further.
            if (oField.fieldlabel = sCurrLabel) then begin
                // If there only is one part of the label, we have a match. Return this field.
                if (oToken.count = 1) then begin
                    result := oField;
                end
                // There are more parts in the labelpath. If this field is a LIST or STRUCT,
                // examine its sub-fields. If it is not, then the path is invalid!
                else begin
                    if (oField.fieldtype = FIELD_TYPE_STRUCT) then begin
                        inc(iTokCount);
                        sCurrLabel := oToken.next();
                        result := ParseStruct((oField as TGFFStruct));
                    end
                    else if (oField.fieldtype = FIELD_TYPE_LIST) then begin
                        inc(iTokCount);
                        sCurrLabel := oToken.next();
                        result := ParseList((oField as TGFFList));
                    end
                    else begin
                        raise EGFFError.CreateHelp('Unable to retrieve field at path ' + sFieldPath + ', the field ' + oField.fieldlabel + ' is not a LIST or STRUCT!', 0);
                    end;
                end;

                exit;
            end
            // No match, try the next root struct field...
            else begin
                oField := GetNextRootField();
            end;
        end;

    finally
        oToken.free();
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2006-01-09) Quick utility function for changing the value of an
// existing field. The string will be converted to a value of the proper data
// type for the field as the value is stored.  Note that ExoLocStrings will need
// a prefix that determine which sub-value is to be changed, like:
//
// -----------------------------------------------------------------------------
function TGFFFile.ChangeFieldValue(sPath : string; sValue : string) : boolean;
var
   oField  : TGFFField;
   oTokens : TStringTokenizer;
   sIndex  : string;
   sLang   : string;
   iPos    : integer;
   i       : integer;
begin
    sIndex := '';
    result := false;

    // Check if there is a field specifier appended at the end of the path for
    // ExoLocStrings, and if so, extract and remove it.
    if ((Pos('(', sPath) <> 0) and (Pos(')', sPath) <> 0)) then begin
        iPos   := Pos('(', sPath);
        sIndex := copy(sPath, iPos, (Pos(')', sPath) + 1) - iPos);
        sPath  := copy(sPath, 1, iPos - 1);
    end;

    // Fetch the specified field...
    oField := GetFieldByLabel(sPath);

    // ...And change the value if the field was found.
    if (oField <> nil) then begin
        case oField.fieldtype of
            FIELD_TYPE_BYTE: begin
                if (GetIsNumber(sValue)) then
                    TGFF_SByte(oField).value := StrToInt(sValue);
            end;

            FIELD_TYPE_CHAR: begin
                if (Length(sValue) > 0) then
                    TGFF_SChar(oField).value := sValue[1];
            end;

            FIELD_TYPE_WORD: begin
                if (GetIsNumber(sValue)) then
                    TGFF_SWord(oField).value := StrToInt(sValue);
            end;

            FIELD_TYPE_SHORT:  begin
                if (GetIsNumber(sValue)) then
                    TGFF_SShort(oField).value := StrToInt(sValue);
            end;

            FIELD_TYPE_DWORD: begin
                if (GetIsNumber(sValue)) then
                    TGFF_SDWORD(oField).value := SafeStrToInt(sValue);
            end;

            FIELD_TYPE_INT: begin
                if (GetIsNumber(sValue)) then
                    TGFF_SInt(oField).value := StrToInt(sValue);
            end;

            FIELD_TYPE_INT64: begin
                if (GetIsNumber(sValue)) then
                    TGFF_CInt64(oField).value := StrToInt64(sValue);
            end;

            FIELD_TYPE_FLOAT: begin
                if (GetIsFloat(sValue)) then
                    TGFF_SFloat(oField).value := SafeStrToFloat(sValue);
            end;

            FIELD_TYPE_DOUBLE: begin
                if (GetIsFloat(sValue)) then
                    TGFF_CDouble(oField).value := SafeStrToDouble(sValue);
            end;

            FIELD_TYPE_CEXOSTRING: begin
                TGFF_CExoString(oField).textstring := sValue;
            end;

            // ExoLocStrings need an extra identifier that specified what
            // data should be modified. Use:
            // (strref) - Modify the dialog.tlk StrRef value
            // (lang#) - Modify the localized string with language-id #
            FIELD_TYPE_CEXOLOCSTRING: begin
                // It's the StrRef that should be set....
                if (sIndex = '(strref)') then begin
                   if (sValue = '-1') then
                      TGFF_CExoLocString(oField).strref := $FFFFFFFF
                   else if (GetIsNumber(sValue)) then
                      TGFF_CExoLocString(oField).strref := SafeStrToInt(sValue);
                end
                // It's one of the localized substrings that should be changed....
                else if (copy(sIndex, 1, 5) = '(lang') then begin
                    sLang := copy(sIndex, 6, Pos(')', sIndex) - 6 );
                    if(GetIsNumber(sLang)) then begin
                        TGFF_CExoLocString(oField).SetStringByID(SafeStrToInt(sLang), sValue);
                    end;
                end;
            end;

            FIELD_TYPE_RESREF: begin
                TGFF_CResRef(oField).textstring := sValue;
            end;

            // Added support for undocumented KotOR field type. Specify
            // input values in format "1.0|2.0|3.0|4.0"
            FIELD_TYPE_ORIENTATION: begin
                oTokens := TStringTokenizer.Create(sValue, '|');
                if (oTokens.count = 4) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_COrientation(oField).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
            end;

            // Added support for undocumented KotOR field type. Specify
            // input values in format "1.0|2.0|3.0"
            FIELD_TYPE_POSITION: begin
                oTokens := TStringTokenizer.Create(sValue, '|');
                if (oTokens.count = 3) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_CPosition(oField).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
            end;
        end;

        // Flag that the data has been changed...
        result := True;
        l_isdirty := True;
    end;

end;

// -----------------------------------------------------------------------------
// Adds a new field to the GFF file at the specified Label Path. The sPath
// parameter should contain the path and name of the PARENT field which the new
// field should be added under. Parent fields must be of either the STRUCT or
// the LIST type.
// If the parent is a LIST, the oField parameter must contain an object of the
// TGFFStruct type.
// -----------------------------------------------------------------------------
procedure TGFFFile.AddField(oField : TGFFField; sPath : string);
var
    oParent : TGFFField;
begin
     if (sPath = '') then
         oParent := l_rootstruct
     else
         oParent := GetFieldByLabel(sPath);
    
    if (oParent <> nil) then begin
        if (oParent.fieldtype = FIELD_TYPE_STRUCT) then begin
            l_isdirty := True;
            (oParent as TGFFStruct).AddField(oField);
        end
        else if (oParent.fieldtype = FIELD_TYPE_LIST) then begin
            if (oField.fieldtype <> FIELD_TYPE_STRUCT) then
                raise EGFFError.CreateHelp('Unable to add new field to the LIST ' + sPath + ' since the field ' + oField.fieldlabel + ' is not a STRUCT!', 0);

            l_isdirty := True;
            (oParent as TGFFList).AddStruct((oField as TGFFStruct));
        end
        else begin
            raise EGFFError.CreateHelp('Unable to add new field at path ' + sPath + ' since the field ' + oParent.fieldlabel + ' is not a LIST or STRUCT!', 0);
        end;
    end
    else begin
        raise EGFFError.CreateHelp('Unable to add new field at path ' + sPath + ' since the specified parent field could not be found.', 0);
    end;
end;


// -----------------------------------------------------------------------------
// Deletes a field from the GFF file. The sFieldLabel parameter must be set to
// the path and field label of the field to delete. For example:
// ClassList\0\KnownList0
//
// REMEMBER: Deleting a STRUCT of LIST field will delete all fields that are
//           contained within them.
// -----------------------------------------------------------------------------
procedure TGFFFile.DeleteField(sFieldPath : string);
var
    oParent : TGFFField;
    oToken  : TStringTokenizer;
    
    sField  : string;
    sPath   : string;
    i       : integer;
begin
    oToken := TStringTokenizer.Create(sFieldPath, '\');
    try
        if (oToken.count = 1) then begin
            sField := oToken[0];
            sPath  := '';
        end
        else begin
            sField := oToken[oToken.count-1];
            sPath  := '';
            for i := 0 to (oToken.count-2) do
                sPath  := oToken[i];
        end;
    finally
        oToken.free();
    end;

    if (sPath = '') then
        oParent := l_rootstruct
    else
        oParent := GetFieldByLabel(sPath);
    
    if (oParent <> nil) then begin
        if (oParent.fieldtype = FIELD_TYPE_STRUCT) then begin
            l_isdirty := True;
            (oParent as TGFFStruct).DeleteField(sField);
        end
        else if (oParent.fieldtype = FIELD_TYPE_LIST) then begin
            if GetIsNumber(sField) then begin
                l_isdirty := True;
                (oParent as TGFFList).DeleteStruct(StrToInt(sField));
            end
            else
                raise EGFFError.CreateHelp('Unable to delete the field ' + sPath + '\' + sField + ' since no valid parent LIST index was specified!', 0);
        end;
    end
    else begin
        raise EGFFError.CreateHelp('Unable to delete the field ' + sField + ' since the parent path ' + sPath + ' could not be found!', 0);
    end;
end;


//////// FILE SAVING METHODS ///////////////////////////////////////////////////


// -----------------------------------------------------------------------------
// Function used to save the currently loaded GFF data to a file.
// -----------------------------------------------------------------------------
procedure TGFFFile.SaveFile(sFilename : string = '');
begin
    if (l_isloaded = False) then
        raise EGFFError.Create('Unable to save, no file has been loaded that can be saved!');

    // If no filename is specified, use the one stored when the file was opened.
    if (sFilename = '') then
       sFilename := l_filename;

    // If the file already exists, make sure it can be overwritten.
    if SysUtils.FileExists(sFilename) then
        MakeFileWritable(sFilename);


    if (l_header <> nil) then
        l_header.free();

    if (l_savedata <> nil) then
        l_savedata.free();

    l_header   := TGFF_Header.Create();
    l_savedata := TGFF_SaveData.Create();
    l_file     := TFileStream.Create(sFilename, fmCreate or fmShareDenyWrite);

    try
        // Go through the GFF Tree and collect needed data into the l_savedata object
        // Start at the Top Level Struct
        l_savedata.structcount := l_savedata.structcount + 1;

        if (l_rootstruct.count > 1) then
            l_savedata.FieldIndexCount := l_savedata.FieldIndexCount + l_rootstruct.count;

        SaveParseStruct(l_rootstruct);

        // Assemble the Header from the collected data
        l_header.filetype         := l_filetype;                                                     // Type of file to write (UTC, DLG etc)
        l_header.fileversion      := l_fileversion;                                                  // Should always be 'V3.2'
        l_header.structoffset     := 56;                                                             // Header is always 56 bytes...
        l_header.structcount      := l_savedata.StructCount;                                         // Elements in array
        l_header.fieldoffset      := l_header.structoffset + (l_header.structcount * 12);
        l_header.fieldcount       := l_savedata.FieldCount;                                          // Elements in array
        l_header.labeloffset      := l_header.fieldoffset + (l_header.fieldcount * 12);
        l_header.labelcount       := Length(l_savedata.FieldLabels);                                 // Elements in array
        l_header.fielddataoffset  := l_header.labeloffset + (l_header.labelcount * 16);
        l_header.fielddatacount   := l_savedata.DataBlockSize;                                       // Byte count in block
        l_header.fieldindexoffset := l_header.fielddataoffset + l_header.fielddatacount;
        l_header.fieldindexcount  := l_savedata.FieldIndexCount * 4;                                 // Byte count: number of entries * DWORD size
        l_header.listindexoffset  := l_header.fieldindexoffset + l_header.fieldindexcount;
        l_header.listindexcount   := (l_savedata.ListIndexCount * 4) + (l_savedata.ListCount * 4);   // Byte count: Num entries * DWORD size + Size entries * DWORD size

        // Write the header information to the file.
        l_file.write(l_header.filetype,         sizeof(l_header.filetype));
        l_file.write(l_header.fileversion,      sizeof(l_header.fileversion));
        l_file.write(l_header.structoffset,     sizeof(l_header.structoffset));
        l_file.write(l_header.structcount,      sizeof(l_header.structcount));
        l_file.write(l_header.fieldoffset,      sizeof(l_header.fieldoffset));
        l_file.write(l_header.fieldcount,       sizeof(l_header.fieldcount));
        l_file.write(l_header.labeloffset,      sizeof(l_header.labeloffset));
        l_file.write(l_header.labelcount,       sizeof(l_header.labelcount));
        l_file.write(l_header.fielddataoffset,  sizeof(l_header.fielddataoffset));
        l_file.write(l_header.fielddatacount,   sizeof(l_header.fielddatacount));
        l_file.write(l_header.fieldindexoffset, sizeof(l_header.fieldindexoffset));
        l_file.write(l_header.fieldindexcount,  sizeof(l_header.fieldindexcount));
        l_file.write(l_header.listindexoffset,  sizeof(l_header.listindexoffset));
        l_file.write(l_header.listindexcount,   sizeof(l_header.listindexcount));

        // Set the starting offsets for each section to begin writing at...
        l_savedata.CurrStructOffset     := l_header.structoffset;
        l_savedata.CurrFieldOffset      := l_header.fieldoffset;
        l_savedata.CurrFieldDataOffset  := l_header.fielddataoffset;
        l_savedata.CurrFieldIndexOffset := l_header.fieldindexoffset;
        l_savedata.CurrListIndexOffset  := l_header.listindexoffset;

        // Saves the Label array to the file...
        SaveProcessLabels();

        // Go through the GFF tree and write everything to the file...
        SaveProcessStruct(l_rootstruct);

        // Things have been saved, unset the "unsaved changes" flag.
        l_isdirty := False;
    finally
        l_file.free();
        l_header.free();
        l_savedata.free();
        l_file     := nil;
        l_header   := nil;
        l_savedata := nil;
    end;
end;


// -----------------------------------------------------------------------------
// Processes the struct passed to the function, collecting necessary data needed
// for writing the file into the l_savedata field. Any structs or lists
// contained within the struct will be recursively parsed as well.
// -----------------------------------------------------------------------------
procedure TGFFFile.SaveParseStruct(oStruct : TGFFStruct);
var
   oField : TGFFField;
   i      : integer;
begin
    for i := 0 to (oStruct.count-1) do begin
        oField := oStruct.fields[i];

        // 1.1) Count the total number of fields in the GFF file....
        l_savedata.fieldcount := l_savedata.fieldcount + 1;

        // 1.4) Gather all field labels in a temporary array. The AddLabel
        // method will not add a label if an identical one already exists in the array.
        if (oField.fieldlabel <> '') then
            l_savedata.AddLabel(oField.fieldlabelraw);


        if (oField.fieldtype = FIELD_TYPE_STRUCT) then begin
           // 1.2) Count the total number of Structs in the file.
           l_savedata.structcount := l_savedata.structcount + 1;

           // 1.5) Count the entries in the FieldIndexArray...
           if ((oField as TGFFStruct).count > 1) then
               l_savedata.FieldIndexCount := l_savedata.FieldIndexCount + (oField as TGFFStruct).count;

           // Parse any fields contained within this Struct
           SaveParseStruct(oField as TGFFStruct);
        end
        else if (oField.fieldtype = FIELD_TYPE_LIST) then begin
            // 1.7) Count the total number of lists in the file
            l_savedata.listcount := l_savedata.listcount + 1;

            // 1.6) Count the entries in the ListIndexArray  (sum with 1.7...)
            if ((oField as TGFFList).count > 0) then
                l_savedata.ListIndexCount := l_savedata.ListIndexCount + (oField as TGFFList).count;

            // Parse any structs contained within this List.
            SaveParseList(oField as TGFFList);
        end
        else begin
             // Calculate the total sieze of the Field Data Block...
             if GetIsComplexField(oField) then
                 l_savedata.DataBlockSize := l_savedata.DataBlockSize + GetFieldDataSize(oField);
        end;

    end;
end;


// -----------------------------------------------------------------------------
// Parses the list passed to the function, collecting necessary data needed to
// write the file to disk into the l_savedata field. Any Structs contained
// within the list will be parsed as well.
// -----------------------------------------------------------------------------
procedure TGFFFile.SaveParseList(oList : TGFFList);
var
   oStruct : TGFFStruct;
   i       : integer;
begin
    for i := 0 to (oList.count-1) do begin
        oStruct := oList.structs[i];
        // 1.1) Count the total number of Structs in the file...
        l_savedata.structcount := l_savedata.structcount + 1;

       // 1.5) Count the entries in the FieldIndexArray...
       if (oStruct.count > 1) then
           l_savedata.FieldIndexCount := l_savedata.FieldIndexCount + oStruct.count;

        // Parse any fields contained in the struct...
        SaveParseStruct(oStruct);
    end;
end;


// -----------------------------------------------------------------------------
// Function used for writing GFF data to file. This will process the specified
// Struct and write it to the file.
// RETURN VALUE: Struct Array index it was inserted at.
// -----------------------------------------------------------------------------
function TGFFFile.SaveProcessStruct(oStruct : TGFFStruct) : DWORD;
var
   oField  : TGFFField;
   iOffset : DWORD;
   iIndex  : DWORD;
   iNext   : DWORD;
   iMem    : DWORD;
   iRes    : DWORD;
   i       : integer;
begin
     // Seek to next free position in the Struct Array section....
    l_file.seek(l_savedata.CurrStructOffset, soFromBeginning);
    iRes := l_savedata.CurrStructIndex;

    // Update the trackers to the next free position...
    l_savedata.CurrStructIndex  := l_savedata.CurrStructIndex + 1;
    l_savedata.CurrStructOffset := l_savedata.CurrStructOffset + 12;

    // Return Struct Array index this Struct was written at...
    result := iRes;

     // Write Struct Type ID...
    l_file.write(oStruct.typeid, 4);

     // Write dummy placeholder space temporarily, correct value is set below...
    iMem := l_file.position;
    iOffset := $FFFFFFFF;
    l_file.write(iOffset, 4);

     // Write number of fields in this struct.
    l_file.write(oStruct.count, 4);

    // More than one field in the struct, write them and store them in the
    // FieldIndexArray, then write the offset to the FIA at the DataOrOffset offset.
    if (oStruct.count > 1) then begin
        // Get the offset at the first FieldIndexArray element for this Struct,
        // advance the tracker to reserve room for writing all the fields.
        iOffset := l_savedata.CurrFieldIndexOffset - l_header.fieldindexoffset;
        iNext   := l_savedata.CurrFieldIndexOffset;
        l_savedata.CurrFieldIndexOffset := l_savedata.CurrFieldIndexOffset + (oStruct.count * 4);

        // Write the fields, get their FieldArray Indexes and store those in the reserved space.
        for i := 0 to (oStruct.count-1) do begin
           oField := oStruct.fields[i];
           iIndex := SaveProcessField(oField);

           l_file.seek(iNext, soFromBeginning);
           l_file.write(iIndex, 4);
           iNext := iNext + 4;
        end;

        // Store the offset to the start of the listing for this struct in the FieldIndexArray.
        l_file.seek(iMem, soFromBeginning);
        l_file.write(iOffset, 4);
    end
    // Only one field in the struct. Store it in the FieldArray and get its index there and store that.
    else if (oStruct.count = 1) then begin
        oField := oStruct.fields[0];
        iIndex := SaveProcessField(oField);
        l_file.seek(iMem, soFromBeginning);
        l_file.write(iIndex, 4);
    end;
end;


// -----------------------------------------------------------------------------
// Function used for writing GFF data to file. This will process the specified
// Field and write it to the file.
// RETURN VALUE: Field Array index it was inserted at.
// -----------------------------------------------------------------------------
function TGFFFile.SaveProcessField(oField : TGFFField) : DWORD;
var
   iRes    : DWORD;
   iMem    : DWORD;
   iIndex  : DWORD;
   iOffset : DWORD;
begin
     // Seek to next free position in the Field Array section....
    l_file.seek(l_savedata.CurrFieldOffset, soFromBeginning);
    iRes := l_savedata.CurrFieldIndex;

    // Update the trackers to the next free position...
    l_savedata.CurrFieldIndex  := l_savedata.CurrFieldIndex + 1;
    l_savedata.CurrFieldOffset := l_savedata.CurrFieldOffset + 12;

    // Return Field Array index this Field was written at...
    result := iRes;

    // Write the field type...
    l_file.write(oField.fieldtype, 4);

    // Write the field label...
    iIndex := SaveGetLabelIndex(oField.fieldlabelraw);
    l_file.write(iIndex, 4);

    // Store the position for the DataOrOffset value
    iMem := l_file.position;

    case (oField.fieldtype) of
        // Simple data types
        FIELD_TYPE_BYTE: begin
            l_file.write((oField as TGFF_SByte).value, 1);
            l_file.seek(l_file.position + 3, soFromBeginning);
        end;

        FIELD_TYPE_CHAR: begin
            l_file.write((oField as TGFF_SChar).value, 1);
            l_file.seek(l_file.position + 3, soFromBeginning);
        end;

        FIELD_TYPE_WORD: begin
            l_file.write((oField as TGFF_SWord).value, 2);
            l_file.seek(l_file.position + 2, soFromBeginning);
        end;

        FIELD_TYPE_SHORT: begin
            l_file.write((oField as TGFF_SShort).value, 2);
            l_file.seek(l_file.position + 2, soFromBeginning);
        end;

        FIELD_TYPE_DWORD: begin
            l_file.write((oField as TGFF_SDWORD).value, 4);
        end;

        FIELD_TYPE_INT: begin
            l_file.write((oField as TGFF_SInt).value, 4);
        end;

        FIELD_TYPE_FLOAT: begin
            l_file.write((oField as TGFF_SFloat).value, 4);
        end;

        // Complex data types
        FIELD_TYPE_DWORD64..FIELD_TYPE_INT64, FIELD_TYPE_DOUBLE..FIELD_TYPE_VOID , FIELD_TYPE_ORIENTATION..FIELD_TYPE_POSITION: begin
            iOffset := SaveProcessComplexFieldData(oField);
            l_file.seek(iMem, soFromBeginning);
            l_file.write(iOffset, 4);
        end;

        // Container types
        FIELD_TYPE_STRUCT: begin
            iIndex := SaveProcessStruct(oField as TGFFStruct);
            l_file.seek(iMem, soFromBeginning);
            l_file.write(iIndex, 4);
        end;

        FIELD_TYPE_LIST: begin
            iOffset := SaveProcessList(oField as TGFFList);
            l_file.seek(iMem, soFromBeginning);
            l_file.write(iOffset, 4);
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Stores the data of the complex field oField in the Field Data Block of the
// file and returns the offset to the beginning of that data.
// -----------------------------------------------------------------------------
function TGFFFile.SaveProcessComplexFieldData(oField : TGFFField) : DWORD;
var
   oExoLoc : TGFF_CExoLocString;
   iRes    : DWORD;
   iBuf    : DWORD;
   iByte   : Byte;
   i, n    : integer;
begin
     l_file.seek(l_savedata.CurrFieldDataOffset, soFromBeginning);
     iRes := l_savedata.CurrFieldDataOffset - l_header.fielddataoffset;
     result := iRes;

     l_savedata.CurrFieldDataOffset := l_savedata.CurrFieldDataOffset + GetFieldDataSize(oField);

     case (oField.fieldtype) of
        FIELD_TYPE_DWORD64: begin
            l_file.write(TGFF_CDWORD64(oField).value, GetFieldDataSize(oField));
        end;

        FIELD_TYPE_INT64: begin
            l_file.write(TGFF_CInt64(oField).value, GetFieldDataSize(oField));
        end;

        FIELD_TYPE_DOUBLE: begin
            l_file.write(TGFF_CDouble(oField).value, GetFieldDataSize(oField));
        end;

        FIELD_TYPE_CEXOSTRING: begin
            iBuf := TGFF_CExoString(oField).size;
            l_file.write(iBuf, 4);
            for i := 0 to (iBuf-1) do
                l_file.write(TGFF_CExoString(oField).text[i], 1);
        end;

        FIELD_TYPE_RESREF: begin
            iByte := TGFF_CResRef(oField).size;
            l_file.write(iByte, 1);
            for i := 0 to (iByte-1) do
                l_file.write(TGFF_CResRef(oField).text[i], 1);
        end;

        FIELD_TYPE_CEXOLOCSTRING: begin
            oExoLoc := TGFF_CExoLocString(oField);

            l_file.write(oExoLoc.bytesize, 4);
            l_file.write(oExoLoc.strref, 4);
            l_file.write(oExoLoc.stringcount, 4);

            for i := Low(oExoLoc.substrings) to High(oExoLoc.substrings) do begin
                l_file.write(oExoLoc.substrings[i].stringid, 4);
                l_file.write(oExoLoc.substrings[i].stringlength, 4);

                for n := 0 to (oExoLoc.substrings[i].stringlength-1) do
                    l_file.write(oExoLoc.substrings[i].text[n], 1);

            end;
        end;

        FIELD_TYPE_VOID: begin
           iBuf := TGFF_CVoid(oField).bytesize;
           l_file.write(iBuf, 4);
           l_file.write(TGFF_CVoid(oField).data, iBuf);
        end;

        FIELD_TYPE_ORIENTATION: begin
            for i := 0 to 3 do
                l_file.write(TGFF_COrientation(oField).value[i], 4);
        end;

        FIELD_TYPE_POSITION: begin
            for i := 0 to 2 do
                l_file.write(TGFF_CPosition(oField).value[i], 4);
        end;
     end;
end;


// -----------------------------------------------------------------------------
// Stores a specified List in the ListIndexArray and stores the Structs it
// contains in the StructArray. The function returns the offset in the
// ListIndexArray where the list begins (with its size count value).
// -----------------------------------------------------------------------------
function TGFFFile.SaveProcessList(oList : TGFFList) : DWORD;
var
   i      : integer;
   iRes   : DWORD;
   iIndex : DWORD;
   iNext  : DWORD;
begin
     l_file.seek(l_savedata.CurrListIndexOffset, soFromBeginning);
     iRes := l_savedata.CurrListIndexOffset - l_header.listindexoffset;
     result := iRes;

     l_savedata.CurrListIndexOffset := l_savedata.CurrListIndexOffset + 4 + (oList.count * 4);

     // Write number of list elements...
     l_file.write(oList.count, 4);

     // Write all the structs in the list.
     iNext := l_file.position;
     for i := 0 to (oList.count-1) do begin
         iIndex := SaveProcessStruct(oList.structs[i]);
         l_file.seek(iNext, soFromBeginning);
         l_file.write(iIndex, 4);
         iNext := iNext + 4;
     end;
end;


// -----------------------------------------------------------------------------
// Writes the label array to the file.
// -----------------------------------------------------------------------------
procedure TGFFFile.SaveProcessLabels();
var
   i : integer;
begin
   l_file.seek(l_header.labeloffset, soFromBeginning);

   for i := Low(l_savedata.FieldLabels) to High(l_savedata.FieldLabels) do
       l_file.write(l_savedata.FieldLabels[i], 16);

end;


// -----------------------------------------------------------------------------
// Returns the Index in the Label Array for a label matching the specified
// label.
// -----------------------------------------------------------------------------
function TGFFFile.SaveGetLabelIndex(sLabel : T16Char) : DWORD;
var
   i : integer;
begin
    result := 0;
    for i := Low(l_savedata.FieldLabels) to High(l_savedata.FieldLabels) do begin
        if (l_savedata.FieldLabels[i] = sLabel) then begin
            result := i;
            exit;
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Returns the size (when written to disk) of the GFF field passed to the
// function. STRUCTs and LISTs are not supported, but all other field types are.
// -----------------------------------------------------------------------------
function TGFFFile.GetFieldDataSize(oField : TGFFField) : DWORD;
begin
    result := 0;
    case (oField.fieldtype) of
        // Simple data types
        FIELD_TYPE_BYTE:          result := 1;
        FIELD_TYPE_CHAR:          result := 1;
        FIELD_TYPE_WORD:          result := 2;
        FIELD_TYPE_SHORT:         result := 2;
        FIELD_TYPE_DWORD:         result := 4;
        FIELD_TYPE_INT:           result := 4;
        FIELD_TYPE_FLOAT:         result := 4;
        // Complex data types
        FIELD_TYPE_DWORD64:       result := 8;
        FIELD_TYPE_INT64:         result := 8;
        FIELD_TYPE_DOUBLE:        result := 8;
        FIELD_TYPE_CEXOSTRING:    result := 4 + TGFF_CExoString(oField).size;        // Size + Data
        FIELD_TYPE_RESREF:        result := 1 + TGFF_CResRef(oField).size;           // Size + Data
        FIELD_TYPE_CEXOLOCSTRING: result := 4 + TGFF_CExoLocString(oField).bytesize; // Size + Data
        FIELD_TYPE_VOID:          result := 4 + TGFF_CVoid(oField).bytesize;         // Size + Data
        FIELD_TYPE_ORIENTATION:   result := 16;
        FIELD_TYPE_POSITION:      result := 12;
    end;
end;


// -----------------------------------------------------------------------------
// Returns TRUE if the field passed to the function is of a complex data
// carrying data type, i.e. not a simple type, STRUCT or LIST.
// -----------------------------------------------------------------------------
function TGFFFile.GetIsComplexField(oField : TGFFField) : boolean;
begin
    result := False;

    if ((oField.fieldtype = FIELD_TYPE_DWORD64)
       or (oField.fieldtype = FIELD_TYPE_INT64)
       or (oField.fieldtype = FIELD_TYPE_DOUBLE)
       or (oField.fieldtype = FIELD_TYPE_CEXOSTRING)
       or (oField.fieldtype = FIELD_TYPE_RESREF)
       or (oField.fieldtype = FIELD_TYPE_CEXOLOCSTRING)
       or (oField.fieldtype = FIELD_TYPE_VOID)
       or (oField.fieldtype = FIELD_TYPE_ORIENTATION)
       or (oField.fieldtype = FIELD_TYPE_POSITION))
    then begin
        result := True;
    end;
end;



// =============================================================================
// CLASS FUNCTIONS: TGFFStruct
// =============================================================================


// -----------------------------------------------------------------------------
// CONSTRUCTOR for the TGFFStruct class.
// -----------------------------------------------------------------------------
constructor TGFFStruct.Create();
begin
    inherited Create();

    Self.fieldtype := FIELD_TYPE_STRUCT;

    SetLength(l_fields, 0);
    l_type := 0;
    l_count := 0;
end;


// -----------------------------------------------------------------------------
// CONSTRUCTOR for the TGFFStruct class.
// -----------------------------------------------------------------------------
constructor TGFFStruct.Create(sLabel : string);
begin
    inherited Create(sLabel);

    Self.fieldtype := FIELD_TYPE_STRUCT;

    SetLength(l_fields, 0);
    l_type := 0;
    l_count := 0;
end;


// -----------------------------------------------------------------------------
// DESTRUCTOR for the TGFFStruct class.
// -----------------------------------------------------------------------------
destructor TGFFStruct.Destroy();
var
    i : integer;
begin
    for i := Low(l_fields) to High(l_fields) do begin
        l_fields[i].free();
        l_fields[i] := nil;
    end;
    
    l_fields := nil;

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Retrieves the field contained within this struct with a label matching the
// sLabel parameter. If no matching field is found, a nil reference is returned.
// -----------------------------------------------------------------------------
function TGFFStruct.GetFieldByLabel(sLabel : string) : TGFFField;
var
    i : integer;
begin
    result := nil;
    for i := Low(l_fields) to High(l_fields) do begin
        if (l_fields[i].fieldlabel = sLabel) then begin
            result := l_fields[i];
            exit;
        end;
    end;
end;


// -----------------------------------------------------------------------------
// Retrieves the field stored at the specified index in the field array for this
// struct. This is a Get-method for the fields property to use for iterating
// through all fields in a struct.
// -----------------------------------------------------------------------------
function TGFFStruct.GetField(i : integer) : TGFFField;
begin
    if ((i < Low(l_fields)) or (i > High(l_fields)) or (DWORD(i) > l_count)) then
        raise EGFFError.CreateHelp('Out of bounds index encountered when attempting to retrieve field from struct ' + Self.fieldlabel + '!', 0);
        
    result := l_fields[i];
end;


// -----------------------------------------------------------------------------
// Adds the specified field to this struct.
// WARNING: Do NOT add a field object instance to more than one struct or list,
//          or BAD THINGS may happen! A field can only be referenced by one
//          container data type in a GFF file.
// -----------------------------------------------------------------------------
procedure TGFFStruct.AddField(oField : TGFFField);
var
    i : integer;
begin
    //FIX(2005-09-13) - Just skip instead of Raise for now since tk102s DLGEditor
    //                  sometimes adds duplicate fields.
    for i := Low(l_fields) to High(l_fields) do begin
        if (l_fields[i].fieldlabel = oField.fieldlabel) then begin
            exit;
            // raise EGFFError.CreateHelp('Unable to add field. A field with the label ' + oField.fieldlabel + ' already exists in the Struct ' + self.fieldlabel + ' !', 0);
        end;
    end;
     
    SetLength(l_fields, Length(l_fields)+1);
    l_fields[High(l_fields)] := oField;
    inc(l_count);
end;


// -----------------------------------------------------------------------------
// Deletes the field with the label matching sLabel from this struct.
//
// WARNINGS:
// Be careful if using this when looping through the field list with the fields
// property as the array gets reindexed when a field is deleted, with the next
// field in line getting moved down to the index position of the element just
// deleted.
//
// Also remember that the field will get deleted, not just removed from the
// struct, so don't delete a field you've just retrieved if you intend to do
// anything more with that data (or copy that data to a new object first).
//
// TODO: Verify that this actually works properly. I'm not sure the arcane way
// of removing a cell from a dynamic variable is foolproof. If it causes trouble
// use the oldfashioned "brute force" way with a temp array instead.
// -----------------------------------------------------------------------------
procedure TGFFStruct.DeleteField(sLabel : string);
var
    i : integer;
begin
    for i := Low(l_fields) to High(l_fields) do begin
        if (l_fields[i].fieldlabel = sLabel) then begin
            // Free this field and all data it contains or references.
            l_fields[i].free();

            // Remove the element of this field from the field array...
            if (i = High(l_fields)) then begin
                SetLength(l_fields, Length(l_fields) - 1);
            end
            else begin
                Finalize(l_fields[i]);
                System.Move(l_fields[i+1], l_fields[i], (Length(l_fields)-i-1) * sizeof(TGFFField)+1);
                SetLength(l_fields, Length(l_fields) - 1);
            end;

            // Decrease the field counter for the struct
            dec(l_count);
            exit;
        end;
    end;

    raise EGFFError.CreateHelp('Unable to delete field! No field with the label ' + sLabel + ' was found in the Struct ' + Self.fieldlabel + '!', 0);
end;


// =============================================================================
// CLASS FUNCTIONS: TGFFField
// =============================================================================

        
// -----------------------------------------------------------------------------
// CONSTRUCTOR - Creates and initializes the abstract Field part of a GFF field.
// -----------------------------------------------------------------------------
constructor TGFFField.Create();
var
	i : integer;
begin
    inherited Create();
    l_type := $FFFFFFFF;

    for i := Low(l_label) to High(l_label) do
        l_label[i] := #0;
end;


// -----------------------------------------------------------------------------
// CONSTRUCTOR - Creates and initializes the abstract Field part of a GFF field.
// -----------------------------------------------------------------------------
constructor TGFFField.Create(sLabel : string);
var
	i : integer;
begin
    inherited Create();
    l_type := $FFFFFFFF;

    for i := Low(l_label) to High(l_label) do
        l_label[i] := #0;

    Self.fieldlabel := sLabel;
end;


// -----------------------------------------------------------------------------
// DESTRUCTOR - Frees the Field base class part of this GFF field object.
// -----------------------------------------------------------------------------
destructor TGFFField.Destroy();
begin
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Sets the specified string as field label for this field. If the string is
// longer than 16 characters it will be truncated to 16 characters.
// -----------------------------------------------------------------------------
procedure TGFFField.SetLabel(sLabel : string);
var
	i : integer;
begin
    if Length(sLabel) > 16 then
       sLabel := copy(sLabel, 1, 16);

    for i := Low(l_label) to High(l_label) do begin
        if (i < Length(sLabel)) then
                l_label[i] := sLabel[i+1]
        else
                l_label[i] := #0;
    end;
end;


// -----------------------------------------------------------------------------
// Sets the specified CHAR[16]-array as the label for this field. The provided
// char array is expected to already be null-padded if the actual string it
// contains is shorter than 16 characters.
// -----------------------------------------------------------------------------
procedure TGFFField.SetLabelRaw(sLabel : T16Char);
var
	i : integer;
begin
    for i := Low(l_label) to High(l_label) do
        l_label[i] := sLabel[i];
end;


// -----------------------------------------------------------------------------
// Retrieves the label for this field as a string. Trailing null padding chars,
// if any, will have been stripped.
// -----------------------------------------------------------------------------
function TGFFField.GetLabel() : string;
var
    i : integer;
    sOut : string;
begin
    sOut := '';
    for i := Low(l_label) to High(l_label) do begin
        if (l_label[i] <> #0) then
                sOut := sOut + l_label[i];
    end;

    result := sOut;
end;


// -----------------------------------------------------------------------------
// Returns the label of this field as a CHAR[16] array. 
// -----------------------------------------------------------------------------
function TGFFField.GetLabelRaw() : T16Char;
var
    i : integer;
    sOut : T16Char;
begin
    for i := Low(l_label) to High(l_label) do
            sOut[i] := l_label[i];

    result := sOut;
end;




// -----------------------------------------------------------------------------
// CONVENIENCE FUNCTION: Return the field data value as a string...
// -----------------------------------------------------------------------------
function TGFFField.GetString() : string;
    // Some local sub-functions to handle output conversion...
    function DWORD64ToString(iValue : T8Bytes) : string;
    var
        sOut : string;
        i    : integer;
    begin
        sOut := '';
        for i := 0 to 7 do
            sOut := sOut + IntToStr(iValue[i]);

        result := sOut;
    end;

    function ExoLocToString(oString : TGFF_CExoLocString) : string;
    var
       sOut : string;
       sBuf : string;
       i, n : integer;
    begin
        sOut := 'LocString[strref=';

        if (oString.strref = $FFFFFFFF) then
           sOut := sOut + '-1'
        else
           sOut := sOut + IntToStr(oString.strref);

        sOut := sOut + ', substrings=';
        sOut := sOut + IntToStr(oString.stringcount);
        sOut := sOut + ', strings=';

        for i := 0 to (oString.stringcount - 1) do begin
            sBuf := '';
            for n := Low(oString.substrings[i].text) to High(oString.substrings[i].text) do
                sBuf := sBuf + oString.substrings[i].text[n];
                
            sOut := sOut + '(' + sBuf + ')';
        end;
        sOut := sOut + ']';
        result := sOut;
    end;

    function CExoStringToString(oString : TGFF_CExoString) : string;
    var
       sOut : string;
       i    : integer;
    begin
        sOut := '';
        for i := Low(oString.text) to High(oString.text) do
            sOut := sOut + oString.text[i];

        result := sOut;
    end;

    function CResRefToString(oResref : TGFF_CResRef) : string;
    var
       sOut : string;
       i    : integer;
    begin
        sOut := '';
        for i := Low(oResref.text) to High(oResref.text) do
            sOut := sOut + oResref.text[i];

        result := sOut;
    end;

    function OrientationToString(oOrient : TGFF_COrientation) : string;
    var
       sOut : string;
    begin
        sOut := FloatToStr(oOrient.value[0]) + '|';
        sOut := sOut + FloatToStr(oOrient.value[1]) + '|';
        sOut := sOut + FloatToStr(oOrient.value[2]) + '|';
        sOut := sOut + FloatToStr(oOrient.value[3]);
        result := sOut;
    end;

    function PositionToString(oPos : TGFF_CPosition) : string;
    var
       sOut : string;
    begin
        sOut := FloatToStr(oPos.value[0]) + '|';
        sOut := sOut + FloatToStr(oPos.value[1]) + '|';
        sOut := sOut + FloatToStr(oPos.value[2]);
        result := sOut;
    end;
begin
    case Self.fieldtype of
        FIELD_TYPE_BYTE:          result := IntToStr(TGFF_SByte(Self).value);
        FIELD_TYPE_CHAR:          result := TGFF_SChar(Self).value;
        FIELD_TYPE_WORD:          result := IntToStr(TGFF_SWord(Self).value);
        FIELD_TYPE_SHORT:         result := IntToStr(TGFF_SShort(Self).value);
        FIELD_TYPE_DWORD:         result := IntToStr(TGFF_SDWORD(Self).value);
        FIELD_TYPE_INT:           result := IntToStr(TGFF_SInt(Self).value);
        FIELD_TYPE_DWORD64:       result := DWORD64ToString(TGFF_CDWORD64(Self).value);
        FIELD_TYPE_INT64:         result := IntToStr(TGFF_CInt64(Self).value);
        FIELD_TYPE_FLOAT:         result := FloatToStr(TGFF_SFloat(Self).value);
        FIELD_TYPE_DOUBLE:        result := FloatToStr(TGFF_CDouble(Self).value);
        FIELD_TYPE_CEXOSTRING:    result := CExoStringToString(TGFF_CExoString(Self));
        FIELD_TYPE_RESREF:        result := CResRefToString(TGFF_CResRef(Self));
        FIELD_TYPE_CEXOLOCSTRING: result := ExoLocToString(TGFF_CExoLocString(Self));
        FIELD_TYPE_VOID:          result := '(Raw Binary data, size=' + IntToStr(TGFF_CVoid(Self).bytesize) + ')';
        FIELD_TYPE_STRUCT:        result := '[STRUCT type=' + IntToStr(TGFFStruct(self).typeid) + ']';
        FIELD_TYPE_LIST:          result := '[LIST]';
        FIELD_TYPE_ORIENTATION:   result := OrientationToString(TGFF_COrientation(Self));
        FIELD_TYPE_POSITION:      result := PositionToString(TGFF_CPosition(Self));
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Clone this object, returning an exact (non-shallow) copy. If the object is
// a STRUCT or a LIST, objects for all contained fields are cloned as well.
//
// Note that the field label (if applicable) is cloned as well, so if the copy
// is to be inserted into the GFF tree at the same level, remember to change
// the label to be unique first.
// -----------------------------------------------------------------------------
function TGFFField.Clone() : TGFFField;
var
   oNew : TGFFField;
   oTmp : TGFFField;
   i    : integer;
begin
    oNew := nil;

    case Self.fieldtype of
        FIELD_TYPE_BYTE: begin
            oNew := TGFF_SByte.Create();
            TGFF_SByte(oNew).value := TGFF_SByte(Self).value;
        end;

        FIELD_TYPE_CHAR: begin
            oNew := TGFF_SChar.Create();
            TGFF_SChar(oNew).value := TGFF_SChar(Self).value;
        end;

        FIELD_TYPE_WORD: begin
            oNew := TGFF_SWord.Create();
            TGFF_SWord(oNew).value := TGFF_SWord(Self).value;
        end;

        FIELD_TYPE_SHORT: begin
            oNew := TGFF_SShort.Create();
            TGFF_SShort(oNew).value := TGFF_SShort(Self).value;
        end;

        FIELD_TYPE_DWORD: begin
            oNew := TGFF_SDWORD.Create();
            TGFF_SDWORD(oNew).value := TGFF_SDWORD(Self).value;
        end;

        FIELD_TYPE_INT: begin
            oNew := TGFF_SInt.Create();
            TGFF_SInt(oNew).value := TGFF_SInt(Self).value;
        end;

        FIELD_TYPE_DWORD64: begin
            oNew := TGFF_CDWORD64.Create();
            for i := Low(TGFF_CDWORD64(Self).value) to High(TGFF_CDWORD64(Self).value) do
                TGFF_CDWORD64(oNew).value[i] := TGFF_CDWORD64(Self).value[i];
        end;


        FIELD_TYPE_INT64: begin
            oNew := TGFF_CInt64.Create();
            TGFF_CInt64(oNew).value := TGFF_CInt64(Self).value;
        end;

        FIELD_TYPE_FLOAT: begin
            oNew := TGFF_SFloat.Create();
            TGFF_SFloat(oNew).value := TGFF_SFloat(Self).value;
        end;

        FIELD_TYPE_DOUBLE: begin
           oNew := TGFF_CDouble.Create();
           TGFF_CDouble(oNew).value := TGFF_CDouble(Self).value;
        end;

        FIELD_TYPE_CEXOSTRING: begin
            oNew := TGFF_CExoString.Create();
            TGFF_CExoString(oNew).textstring := TGFF_CExoString(Self).textstring;
        end;
        
        FIELD_TYPE_RESREF: begin
            oNew := TGFF_CResRef.Create();
            TGFF_CResRef(oNew).textstring := TGFF_CResRef(Self).textstring;
        end;

        FIELD_TYPE_CEXOLOCSTRING: begin
            oNew := TGFF_CExoLocString.Create();
            TGFF_CExoLocString(oNew).strref := TGFF_CExoLocString(Self).strref;

            for i := Low(TGFF_CExoLocString(Self).substrings) to High(TGFF_CExoLocString(Self).substrings) do
                TGFF_CExoLocString(oNew).AddString(TGFF_CExoLocString(Self).substrings[i].stringid, TGFF_CExoLocString(Self).substrings[i].textstring);
        end;

        FIELD_TYPE_VOID: begin
            oNew := TGFF_CVoid.Create();
            TGFF_CVoid(oNew).bytesize := TGFF_CVoid(Self).bytesize;
            SetLength(TGFF_CVoid(oNew).data, Length(TGFF_CVoid(Self).data));

            for i := Low(TGFF_CVoid(Self).data) to High(TGFF_CVoid(Self).data) do
                TGFF_CVoid(oNew).data[i] := TGFF_CVoid(Self).data[i];
        end;

        FIELD_TYPE_STRUCT: begin
            oNew := TGFFStruct.Create();
            TGFFStruct(oNew).typeid := TGFFStruct(Self).typeid;
            
            for i := 0 to TGFFStruct(Self).count do begin
                oTmp := TGFFStruct(Self).fields[i].Clone();
                if (oTmp <> nil) then
                    TGFFStruct(oNew).AddField(oTmp)
                else
                    raise EGFFError.Create('Unable to clone field "' + TGFFStruct(Self).fields[i].fieldlabel + '" in struct "' + Self.fieldlabel + '"!');
            end;

        end;

        FIELD_TYPE_LIST: begin
            oNew := TGFFList.Create();

            for i := 0 to TGFFList(Self).count do begin
                oTmp := TGFFList(Self).structs[i].Clone();
                if (oTmp <> nil) then
                    TGFFList(oNew).AddStruct(TGFFStruct(oTmp))
                else
                    raise EGFFError.Create('Unable to clone struct ' + IntToStr(i) + ' in List "' + Self.fieldlabel + '"!');
            end;
        end;

        FIELD_TYPE_ORIENTATION: begin
            oNew := TGFF_COrientation.Create();
            for i := Low(TGFF_COrientation(Self).value) to High(TGFF_COrientation(Self).value) do
                TGFF_COrientation(oNew).value[i] := TGFF_COrientation(Self).value[i];
        end;

        FIELD_TYPE_POSITION: begin
            oNew := TGFF_CPosition.Create();
            for i := Low(TGFF_CPosition(Self).value) to High(TGFF_CPosition(Self).value) do
                TGFF_CPosition(oNew).value[i] := TGFF_CPosition(Self).value[i];
        end;
    end;

    // Copy the common GFFField field values...
    if (oNew <> nil) then begin
        oNew.fieldlabel := Self.fieldlabel;
        oNew.fieldtype  := Self.fieldtype;
    end;

    result := oNew;
end;


// =============================================================================
// CLASS FUNCTIONS: TGFFList
// =============================================================================

// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFFList.Create();
begin
    inherited Create();
    Self.fieldtype := FIELD_TYPE_LIST;

    l_count := 0;
    SetLength(l_structs, 0);
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFFList.Create(sLabel : string);
begin
    inherited Create(sLabel);
    Self.fieldtype := FIELD_TYPE_LIST;

    l_count := 0;
    SetLength(l_structs, 0);
end;


// -----------------------------------------------------------------------------
// Destructor - Destroy the list and free any structs it contains...
// -----------------------------------------------------------------------------
destructor TGFFList.Destroy();
var
    i : integer;
begin
    if (Length(l_structs) > 0) then begin
        for i := Low(l_structs) to High(l_structs) do begin
            if (l_structs[i] <> nil) then
                l_structs[i].free();
        end;
    
        SetLength(l_structs, 0);
        l_structs := nil;
    end;
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Get function for the structs property. Retrieves the struct at the specified
// index in the LIST's struct array.
// -----------------------------------------------------------------------------
function TGFFList.GetStruct(iIndex : integer) : TGFFStruct;
begin
    if (iIndex > High(l_structs)) or (iIndex < Low(l_structs)) or (DWORD(iIndex) > l_count) then
       raise EGFFError.CreateHelp('Out of bounds index ' + IntToStr(iIndex) + ' when trying to get STRUCT from LIST ' + Self.fieldlabel + '!', 0);

    result := l_structs[iIndex];
end;


// -----------------------------------------------------------------------------
// Adds a new struct to the end of this LISTs list of structs.
// -----------------------------------------------------------------------------
procedure TGFFList.AddStruct(oStruct : TGFFStruct);
begin
    if (oStruct.fieldlabel <> '') then
       oStruct.fieldlabel := '';

    SetLength(l_structs, Length(l_structs) + 1);
    l_structs[High(l_structs)] := oStruct;
    inc(l_count);
end;


// -----------------------------------------------------------------------------
// Deletes the Struct at the specified index in the LIST's struct array.
//
// WARNINGS:
// Be careful using this when looping through the struct list with the structs
// property as the array gets reindexed when a struct is deleted, with the next
// struct in line getting moved down to the index position of the element just
// deleted.
//
// Also remember that the struct and all fields it contains will get deleted, 
// not just removed from the LIST, so don't delete a field you've just 
// retrieved if you intend to do anything more with that data (or copy that data
//  to a new object first).
//
// TODO: Verify that this actually works properly. I'm not sure the arcane way
// of removing a cell from a dynamic variable is foolproof. If it causes trouble
// use the oldfashioned "brute force" way with a temp array instead.
// -----------------------------------------------------------------------------
procedure TGFFList.DeleteStruct(iIndex : DWORD);
begin
    if ((iIndex > DWORD(High(l_structs))) or (iIndex > l_count)) then
        raise EGFFError.CreateHelp('Out of bounds index ' + IntToStr(iIndex) + ' when trying to delete STRUCT from LIST ' + Self.fieldlabel + '!', 0);

    l_structs[iIndex].free();

    if (iIndex <> DWORD(High(l_structs))) then begin
        Finalize(l_structs[iIndex]);
        System.Move(l_structs[iIndex+1], l_structs[iIndex], (DWORD(Length(l_structs)) - iIndex - 1) * sizeof(TGFFStruct) + 1);
    end;

    SetLength(l_structs, Length(l_structs) - 1);
    dec(l_count);
end;


// =============================================================================
// CRESREF FUNCTIONS
// =============================================================================


// -----------------------------------------------------------------------------
// Constructor - create a new blank CResRef.
// -----------------------------------------------------------------------------
constructor TGFF_CResRef.Create();
begin
    inherited Create();
    Self.fieldtype := FIELD_TYPE_RESREF;
    SetLength(text, 0);
    size := 0;
end;


// -----------------------------------------------------------------------------
// Constructor - create a new blank CResRef.
// -----------------------------------------------------------------------------
constructor TGFF_CResRef.Create(sLabel : string; sData : string);
begin
    inherited Create(sLabel);
    Self.fieldtype := FIELD_TYPE_RESREF;
    SetLength(text, 0);
    size := 0;
    Self.textstring := sData;
end;


// -----------------------------------------------------------------------------
// Destructor - delete this CResRef and all data stored within.
// -----------------------------------------------------------------------------
destructor TGFF_CResRef.Destroy();
begin
    SetLength(text, 0);
    text := nil;
    inherited Destroy();
end;

// -----------------------------------------------------------------------------
// Sets the supplied string as the text of the CResRef. Note 16 char max length.
// -----------------------------------------------------------------------------
procedure TGFF_CResRef.SetString(sText : string);
var
   i : integer;
begin
    if (Length(sText) > 16) then
        size := 16
    else
        size := Length(sText);

    text := nil;
    SetLength(text, size);

    sText := lowercase(sText);

    for i := Low(text) to High(text) do
        text[i] := sText[i+1];
end;


// -----------------------------------------------------------------------------
// Retrieves the text of the CResRef and returns it as a string.
// -----------------------------------------------------------------------------
function TGFF_CResRef.GetString() : string;
var
   sOut : string;
   i    : integer;
begin
    sOut := '';

    if (text <> nil) and (Length(text) > 0) then begin
        for i := Low(text) to High(text) do
            sOut := sOut + text[i];
    end;
    result := sOut;
end;

// =============================================================================
// CEXOSTRING FUNCTIONS
// =============================================================================

// -----------------------------------------------------------------------------
// Constructor - Create a new blank ExoString.
// -----------------------------------------------------------------------------
constructor TGFF_CExoString.Create();
begin
    inherited Create();
    Self.fieldtype := FIELD_TYPE_CEXOSTRING;
    SetLength(text, 0);
    size := 0;
end;


// -----------------------------------------------------------------------------
// Constructor - Create a new blank ExoString.
// -----------------------------------------------------------------------------
constructor TGFF_CExoString.Create(sLabel : string; sData : string);
begin
    inherited Create(sLabel);
    Self.fieldtype := FIELD_TYPE_CEXOSTRING;
    SetLength(text, 0);
    size := 0;
    Self.textstring := sData;
end;


// -----------------------------------------------------------------------------
// Destructor - destroy this ExoString and all data contained within it.
// -----------------------------------------------------------------------------
destructor TGFF_CExoString.Destroy();
begin
    SetLength(text, 0);
    text := nil;
    inherited Destroy();
end;

// -----------------------------------------------------------------------------
// Stores the supplied string in the text portion of the ExoString.
// -----------------------------------------------------------------------------
procedure TGFF_CExoString.SetString(sText : string);
var
   i : integer;
begin
    size := Length(sText);
    text := nil;
    SetLength(text, size);

    for i := Low(text) to High(text) do
        text[i] := sText[i+1];
end;


// -----------------------------------------------------------------------------
// Retrieves the text stored in the ExoString and returns it as a string.
// -----------------------------------------------------------------------------
function TGFF_CExoString.GetString() : string;
var
   sOut : string;
   i    : integer;
begin
    sOut := '';

    if (text <> nil) and (Length(text) > 0) then begin
        for i := Low(text) to High(text) do
            sOut := sOut + text[i];
    end;
    result := sOut;
end;

// =============================================================================
// CEXOLOCSTRING FUNCTIONS
// =============================================================================

// -----------------------------------------------------------------------------
// Create a new blank ExoLoc substring....
// -----------------------------------------------------------------------------
constructor TGFF_CSubString.Create();
begin
    inherited Create();
    SetLength(text, 0);
    stringlength := 0;
    stringid := 0;
end;

// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Create a new blank ExoLoc substring. with the StringId and specified text
// set directly.
// -----------------------------------------------------------------------------
constructor TGFF_CSubString.Create(nID : LongInt; sText : string);
begin
    inherited Create();
    SetLength(text, 0);
    stringlength := 0;
    stringid := nID;
    Self.SetString(sText);
end;


// -----------------------------------------------------------------------------
// Destructor - destroy this substring and associated data.
// -----------------------------------------------------------------------------
destructor TGFF_CSubString.Destroy();
begin
    SetLength(text, 0);
    text := nil;
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Sets the text portion of the CExoLoc substring from to the supplied string.
// -----------------------------------------------------------------------------
procedure TGFF_CSubString.SetString(sText : string);
var
   i : integer;
begin
    stringlength := Length(sText);
    text := nil;
    SetLength(text, stringlength);

    for i := Low(text) to High(text) do
        text[i] := sText[i+1];
end;


// -----------------------------------------------------------------------------
// Returns a string containing the text portion of the CExoLoc substring...
// -----------------------------------------------------------------------------
function TGFF_CSubString.GetString() : string;
var
   sOut : string;
   i    : integer;
begin
    sOut := '';

    if (text <> nil) and (Length(text) > 0) then begin
        for i := Low(text) to High(text) do
            sOut := sOut + text[i];
    end;
    result := sOut;
end;


// -----------------------------------------------------------------------------
// Constructor - create a blank new CExoLocString object....
// -----------------------------------------------------------------------------
constructor TGFF_CExoLocString.Create();
begin
    inherited Create();
    Self.fieldtype := FIELD_TYPE_CEXOLOCSTRING;
    SetLength(substrings, 0);
    strref := $FFFFFFFF;
    stringcount := 0;
    bytesize := 8;
end;


// -----------------------------------------------------------------------------
// Constructor - create a blank new CExoLocString object....
// -----------------------------------------------------------------------------
constructor TGFF_CExoLocString.Create(sLabel : string; iStrRef : DWORD);
begin
    inherited Create(sLabel);
    Self.fieldtype := FIELD_TYPE_CEXOLOCSTRING;
    SetLength(substrings, 0);
    strref := iStrRef;
    stringcount := 0;
    bytesize := 8;
end;


// -----------------------------------------------------------------------------
// Destructor - delete this CExoLocString object and associated data.
// -----------------------------------------------------------------------------
destructor TGFF_CExoLocString.Destroy();
var
   i : integer;
begin
     if (Length(substrings) > 0) then begin
        for i := Low(substrings) to High(substrings) do
            substrings[i].free();

        SetLength(substrings, 0);
        substrings := nil;
     end;

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Set the text of a substring in the CExoLocString, and recalculate the total
// byte size of the CExoLocString to reflect the new data.
// -----------------------------------------------------------------------------
procedure TGFF_CExoLocString.SetString(iIndex : integer; sText : string);
var
   i : integer;
begin
     if ((DWORD(iIndex) >= stringcount) or (iIndex < 0)) then
        raise EGFFError.CreateHelp('Invalid substring index when setting CExoLocString text!', 21);

     // Set the string at the requested index...
     substrings[iIndex].textstring := sText;

     // Then recalculate the CExoLocString's bytesize value....

    // size of StrRef and StrCount fields...
    bytesize := 8;

    // Get length of each substring + size of its stringid and stringlength fields.
    for i := 0 to (stringcount-1) do begin
        bytesize := bytesize + DWORD(substrings[i].stringlength) + 8;
    end;
end;


// -----------------------------------------------------------------------------
// Get the text of an entry in the SubStrings array, with bounds checking for
// the index parameter.
// -----------------------------------------------------------------------------
function TGFF_CExoLocString.GetString(iIndex : integer) : string;
begin
     if ((DWORD(iIndex) >= stringcount) or (iIndex < 0)) then
        raise EGFFError.CreateHelp('Invalid substring index when getting CExoLocString text!', 22);

     result := substrings[iIndex].textstring;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Add a new substring to this CExoLocString object.
// iLangID is the language ID to add the substring for (+1 for female forms)
// sText is the text data that should be added.
// -----------------------------------------------------------------------------
procedure TGFF_CExoLocString.AddString(iLangID : integer; sText : string);
var
   i      : integer;
   bFound : boolean;
   oString : TGFF_CSubString;
begin
    // LanguageIDs start at 0 (English)
    if (iLangID < 0) then
        raise EGFFError.CreateHelp('Invalid Language ID specified when adding CExoLocString substring!', 23);

    // If a substring with this language ID already exists, update it instead.
    bFound := False;
    for i := Low(substrings) to High(substrings) do begin
        if (substrings[i].stringid = iLangID) then begin
            substrings[i].textstring := sText;
            bFound := True;
            break;
        end;
    end;

    // No existing string with specified LanguageID found, add a new Substring.
    if not bFound then begin
        oString := TGFF_CSubString.Create(iLangID, sText);
        SetLength(substrings, Length(substrings) + 1);
        substrings[High(substrings)] := oString;
        stringcount := stringcount + 1;
    end;

    // Recalculate the byte size of the ExoLocString.
    // Add size of StrRef and StrCount fields in the CExoLocString...
    bytesize := 8;

    // Get length of each substring + size of its stringid and stringlength fields.
    // The +8 is the size of the StringID and StringLength fields in the CSubstring.
    for i := Low(substrings) to High(substrings) do begin
        bytesize := bytesize + DWORD(substrings[i].stringlength) + 8;
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Delete a substring from this CExoLocString object. iIndex is the index in
// the substrings array of the CSubstring object to destroy.
//
// TODO: Verify that this actually works properly. I'm not sure the arcane way
// of removing a cell from a dynamic variable is foolproof. If it causes trouble
// use the oldfashioned "brute force" way with a temp array instead.
// -----------------------------------------------------------------------------
procedure TGFF_CExoLocString.DeleteString(iIndex : integer);
var
   n : integer;
begin
    // LanguageIDs start at 0 (English)
    if (iIndex < Low(substrings)) or (iIndex > High(substrings)) then
        raise EGFFError.CreateHelp('Invalid substring index when deleting CExoLocString substring!', 24);

    // Destroy the substring object.
    substrings[iIndex].free();
    stringcount := stringcount - 1;

    // Remove the cell for this substring in the Substrings array.
    if (iIndex = High(substrings)) then begin
        SetLength(substrings, Length(substrings) - 1);
    end
    else begin
        Finalize(substrings[iIndex]);
        System.Move(substrings[iIndex+1], substrings[iIndex], (Length(substrings)-iIndex-1) * sizeof(TGFF_CSubString)+1);
        SetLength(substrings, Length(substrings) - 1);
    end;

    // Recalculate the byte size of the ExoLocString.
    // Add size of StrRef and StrCount fields in the CExoLocString...
    bytesize := 8;

    // Get length of each substring + size of its stringid and stringlength fields.
    // The +8 is the size of the StringID and StringLength fields in the CSubstring.
    for n := Low(substrings) to High(substrings) do begin
        bytesize := bytesize + DWORD(substrings[n].stringlength) + 8;
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Retrieve a substring from this CExoLocString with the specified language id.
// -----------------------------------------------------------------------------
function TGFF_CExoLocString.GetStringById(iLangID : integer) : string;
var
   i : integer;
begin
    result := '';

    for i := Low(substrings) to High(substrings) do begin
        if (substrings[i].stringid = iLangID) then begin
            result := substrings[i].textstring;
            break;
        end;
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Wrapper method for deleting a substring from the ExoLocString that matches
// the specified language id.
// -----------------------------------------------------------------------------
procedure TGFF_CExoLocString.DeleteStringByID(iLangID : integer);
var
   i : integer;
begin
    for i := Low(substrings) to High(substrings) do begin
        if (substrings[i].stringid = iLangID) then begin
            Self.DeleteString(i);
            break;
        end;
    end;
end;


// -----------------------------------------------------------------------------
// ADDED(2005-10-08)
// Wrapper method for modifying a substring in the ExoLocString whose language
// id matches the specified parameter.
// CHANGED(2007-08-13) Modified so it can add the substring if it does not
//                     already exist.
// -----------------------------------------------------------------------------
procedure TGFF_CExoLocString.SetStringByID(iLangID : integer; sText : string; bAddIfMissing : boolean = false);
var
   i : integer;
   bFound : boolean;
begin
    bFound := false;
    for i := Low(substrings) to High(substrings) do begin
        if (substrings[i].stringid = iLangID) then begin
            Self.SetString(i, sText);
            bFound := true;
            break;
        end;
    end;

    if bAddIfMissing and not bFound then begin
        AddString(iLangID, sText);
    end;
end;



// =============================================================================
// CLASS FUNCTIONS: The Rest...
// =============================================================================

// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CVoid.Create();
begin
    inherited Create();
    Self.fieldtype := FIELD_TYPE_VOID;
    bytesize := 0;
    SetLength(data, 0);
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CVoid.Create(sLabel : string; aData : TBytes);
var
   i : integer;
begin
    inherited Create(sLabel);
    Self.fieldtype := FIELD_TYPE_VOID;
    bytesize := Length(aData);
    SetLength(data, bytesize);

    for i := Low(aData) to High(aData) do
        Self.data[i] := aData[i];
end;


// -----------------------------------------------------------------------------
// Destructor
// -----------------------------------------------------------------------------
destructor TGFF_CVoid.Destroy();
begin
     if (Length(data) > 0) then begin
        SetLength(data, 0);
        data := nil;
     end;

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SByte.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_BYTE;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SByte.Create(sLabel : string; iData : Byte);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_BYTE;
     Self.value := iData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SChar.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_CHAR;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SChar.Create(sLabel : string; cData : Char);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_CHAR;
     Self.value := cData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SWord.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_WORD;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SWord.Create(sLabel : string; iData : WORD);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_WORD;
     Self.value := iData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SShort.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_SHORT;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SShort.Create(sLabel : string; iData : Short);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_SHORT;
     Self.value := iData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SDWORD.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_DWORD;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SDWORD.Create(sLabel : string; iData : DWORD);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_DWORD;
     Self.value := iData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SInt.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_INT;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SInt.Create(sLabel : string; iData : LongInt);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_INT;
     Self.value := iData;
end;



// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CDWORD64.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_DWORD64;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CDWORD64.Create(sLabel : string; aData : T8Bytes);
var
   i : integer;
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_DWORD64;

     for i := Low(aData) to High(aData) do
         Self.value[i] := aData[i];
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CInt64.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_INT64;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CInt64.Create(sLabel : string; iData : Int64);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_INT64;
     Self.value := iData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SFloat.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_FLOAT;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SFloat.Create(sLabel : string; fData : Single);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_FLOAT;
     Self.value := fData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CDouble.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_DOUBLE;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CDouble.Create(sLabel : string; fData : Double);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_DOUBLE;
     Self.value := fData;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_COrientation.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_ORIENTATION;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_COrientation.Create(sLabel : string; fData1 : Single; fData2 : Single; fData3 : Single; fData4 : Single);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_ORIENTATION;
     self.value[0] := fData1;
     self.value[1] := fData2;
     self.value[2] := fData3;
     self.value[3] := fData4;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CPosition.Create();
begin
     inherited Create();
     Self.fieldtype := FIELD_TYPE_POSITION;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CPosition.Create(sLabel : string; fX : Single; fY : Single; fZ : Single);
begin
     inherited Create(sLabel);
     Self.fieldtype := FIELD_TYPE_POSITION;
     self.value[0] := fX;
     self.value[1] := fY;
     self.value[2] := fZ;
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_SaveData.Create();
begin
    inherited Create();

    StructCount     := 0;
    FieldCount      := 0;
    FieldIndexCount := 0;
    ListIndexCount  := 0;
    ListCount       := 0;
    DataBlockSize   := 0;

    SetLength(FieldLabels, 0);
end;


// -----------------------------------------------------------------------------
// Destructor
// -----------------------------------------------------------------------------
destructor TGFF_SaveData.Destroy();
begin
    SetLength(FieldLabels, 0);
    FieldLabels := nil;

    inherited Destroy();
end;

// -----------------------------------------------------------------------------
// Adds this Field Label
// -----------------------------------------------------------------------------
procedure TGFF_SaveData.AddLabel(sLabel : T16Char);
var
   sAdd : T16Char;
   i    : integer;
begin
    for i := Low(sLabel) to High(sLabel) do
        sAdd[i] := sLabel[i];

    for i := Low(FieldLabels) to High(FieldLabels) do begin
        if (FieldLabels[i] = sAdd) then
            exit;
    end;

    SetLength(FieldLabels, Length(FieldLabels)+1);
    FieldLabels[High(FieldLabels)] := sAdd;
end;



end.
 
unit UGFFHandler;

// =============================================================================
//  GFF Handler - classes for reading and writing the Bioware GFF format.
// =============================================================================
// MAIN CLASS   : TGFFFileHandler
// Last error ID: 22
// Last changed : 2005-07-21
// -----------------------------------------------------------------------------

(*
  IMPORTANT! The Header counts are always expected to contain up-to-date info on
             everything. When adding or deleting data the header must be updated properly.
             Make sure all the Set methods do this!

  TODO:  [_] Add methods for adding new fields to the GFF.
         [_] Add methods for deleting fields from the GFF.
         [_] Add methods for creating a new GFF from scratch.
         [?] Add support for KotOR ORIENTATION and POSITION fields...
*)

interface

uses SysUtils, Classes, Windows, UStrTok;

// Size of byte buffer used for some writing operations...
const BYTE_BUFFER_SIZE         = 4096;

// GFFField type constants...
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
// TYPE DEFINITIONS
// -----------------------------------------------------------------------------

// Fixed length types...
T4Char  = array [0..3]    of Char;
T16Char = array [0..15]   of Char;
T8Bytes = array [0..7]    of Byte;
TBuffer = array [0..2047] of Char;

// Variable length types...
TChars      = array of Char;
TBytes      = array of Byte;
TFieldIndex = array of DWORD;

// -----------------------------------------------------------------------------
// EXCEPTION TYPE USED BY THESE CLASSES....
// -----------------------------------------------------------------------------

EGFFError = class(Exception);

// -----------------------------------------------------------------------------
// DATA TYPE CLASSES
// -----------------------------------------------------------------------------

// Abstract superclass for encapsulating all field data types...
TGFF_FieldData = class(TObject);

TGFF_SByte = class(TGFF_FieldData)
    value : Byte;
end;

TGFF_SChar = class(TGFF_FieldData)
    value : Char;
end;

TGFF_SWord = class(TGFF_FieldData)
    value : Word;
end;

TGFF_SShort = class(TGFF_FieldData)
    value : SmallInt;
end;

TGFF_SDWORD = class(TGFF_FieldData)
    value : DWORD;
end;

TGFF_SInt = class(TGFF_FieldData)
    value : LongInt;
end;

TGFF_CDWORD64 = class(TGFF_FieldData)
    value : T8Bytes;
end;

TGFF_CInt64 = class(TGFF_FieldData)
    value : Int64;
end;

TGFF_SFloat = class(TGFF_FieldData)
    value : Single;
end;

TGFF_CDouble = class(TGFF_FieldData)
    value : Double;
end;

TGFF_CExoString = class(TGFF_FieldData)
    size : DWORD;
    text : TChars;

    constructor Create();
    destructor Destroy(); override;
    procedure SetString(sText : string);
    function GetString() : string;

    // Use this property rather than the Get/Set methods to access the text...
    property textstring : string     read GetString   write SetString;
end;

TGFF_CResRef = class(TGFF_FieldData)
    size : Byte;
    text : TChars;

    constructor Create();
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

    constructor Create();
    destructor Destroy(); override;
    procedure SetString(sText : string);
    function GetString() : string;

    // Use this property rather than the Get/Set methods to access the text...
    property textstring : string     read GetString   write SetString;
end;

TGFF_CExoLocString = class(TGFF_FieldData)
    bytesize     : DWORD; // Size of whole structure, excluding this field.
    strref       : DWORD;
    stringcount  : DWORD;
    substrings   : array of TGFF_CSubString;

    constructor Create();
    destructor Destroy(); override;

    procedure SetString(iIndex : integer; sText : string);
    function GetString(iIndex : integer) : string;

    property strings[i:integer] : string     read GetString    write SetString;
end;

TGFF_CVoid = class(TGFF_FieldData)
    bytesize : DWORD;
    data     : TBytes;

    constructor Create();
    destructor Destroy(); override;
end;

// FIX(2005-05-31) Undocumented type added in KotOR...
TGFF_COrientation = class(TGFF_FieldData)
    value : array [0..3] of Single;
end;

// FIX(2005-05-31) Undocumented type added in KotOR...
TGFF_CPosition = class(TGFF_FieldData)
    value : array [0..2] of Single;
end;

// -----------------------------------------------------------------------------
// Structural classes...
// -----------------------------------------------------------------------------

TGFF_Struct = class(TGFF_FieldData)
    typeid       : DWORD;
    dataoroffset : DWORD;
    fieldcount   : DWORD;
end;

TGFF_List = class(TGFF_FieldData)
    count   : DWORD;
    structs : array of DWORD; // Indexes in the Struct Array...

    constructor Create();
    destructor Destroy(); override;
end;

TGFF_FieldIndex = class(TObject)
    indexes : TFieldIndex;

    function GetSize() : DWORD;
    constructor Create();
    destructor Destroy(); override;

    property size : DWORD     read GetSize;
end;

TGFF_Field = class(TObject)
    fieldtype : DWORD;
    labelindex : DWORD;
    dataoroffset : DWORD;

    fielddata : TGFF_FieldData;

    function GetString() : string;

    constructor Create();
    destructor Destroy(); override;
end;

// -----------------------------------------------------------------------------
// File handling classes...
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

TGFFFileHandler = class(TObject)
    private
        // Holds the loaded GFF data...
        l_header          : TGFF_Header;
        l_structArray     : array of TGFF_Struct;
        l_fieldArray      : array of TGFF_Field;
        l_labelArray      : array of T16Char;
        l_fieldIndexArray : array of TGFF_FieldIndex;
        l_listIndexArray  : array of TGFF_List;

        // Used for writing to file...
        l_isloaded     : boolean;
        l_currdatapos  : DWORD;
        l_currfieldpos : DWORD;
        l_currlistpos  : DWORD;

        // Used for changing the value of a field in SetGffField()...
        l_modifyfield  : string;
        l_modifyvalue  : string;

        // Support sub-functions used for loading and saving the data structures.
        function ProcessListIndexArrayOffset(inFile : TFileStream; iOffset : DWORD) : DWORD;
        function LookupFieldIndexArrayOffset(inFile : TFileStream; iOffset : DWORD; iCount : DWORD) : DWORD;
        function GetSimpleDataType(inFile : TFileStream; iType : DWORD) : TGFF_FieldData;
        function GetComplexDataType(inFile : TFileStream; iType : DWORD) : TGFF_FieldData;
        function GetFieldLength(oField : TGFF_Field) : DWORD;
        function WriteGffFieldIndexArray(outFile : TFileStream; iIndex : DWORD) : DWORD;
        function WriteGffFieldData(outFile : TFileStream; oField : TGFF_Field) : DWORD;
        function WriteGffListIndexArray(outFile : TFileStream; iIndex : DWORD) : DWORD;

        // Support functions  used by LoadGffFile()
        procedure LoadGffHeader(inFile : TFileStream);
        procedure LoadLabelArray(inFile : TFileStream);
        procedure LoadStructArray(inFile : TFileStream);
        procedure LoadFieldArray(inFile : TFileStream);

        // Support functions used by SaveGffFile()
        procedure SaveGffHeader(outFile : TFileStream);
        procedure SaveGffStructs(outFile : TFileStream);
        procedure SaveGffFields(outFile : TFileStream);
        procedure SaveGffLabels(outFile : TFileStream);

        // Data retreival wrappers with bounds checking for the arrays...
        function GetLabel(iIndex : integer) : string;
        function GetField(iIndex : integer) : TGFF_Field;
        function GetStruct(iIndex : integer) : TGFF_Struct;
        function GetFieldIndex(iIndex : integer) : TGFF_FieldIndex;
        function GetListIndex(iIndex : integer) : TGFF_List;

        // Support functions used by SetGffField()
        function SearchGffStruct(iIndex : integer; sPath : string) : boolean;
        function SearchGffList(iIndex : integer; sPath : string) : boolean;
        function SearchGffField(iIndex : integer; sPath : string) : boolean;
    public
        procedure LoadGffFile(sFilename : string);
        procedure SaveGffFile(sFilename : String);
        function SetGffField(sTarget : string; sValue : string) : boolean;

        procedure Reset();
        constructor Create();
        Destructor Destroy(); override;

        property header                  : TGFF_Header      read l_header;
        property labels[i : integer]     : string           read GetLabel;
        property fields[i : integer]     : TGFF_Field       read GetField;
        property structs[i : integer]    : TGFF_Struct      read GetStruct;
        property fieldindex[i : integer] : TGFF_FieldIndex  read GetFieldIndex;
        property listindex[i : integer]  : TGFF_List        read GetListIndex;
        property isloaded                : boolean          read l_isloaded;
end;

implementation

// -----------------------------------------------------------------------------
// UTILITY: Check if the supplied string can be converted to an Integer.
// -----------------------------------------------------------------------------
function GetIsNumber(sStr : string) : boolean;
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
// UTILITY: Remove the ReadOnly flag on the specified file if present.
// -----------------------------------------------------------------------------
procedure MakeFileWritable(sFilename : string);
var
   nFlags  : Word;
begin    
    if (SysUtils.FileExists(sFilename)) then begin
        nFlags := FileGetAttr(sFilename);
        if ((nFlags and faReadOnly) = faReadOnly) then begin
            nFlags := nFlags and not faReadOnly;
            FileSetAttr(sFilename, nFlags);
        end;  
    end;
end;


// =============================================================================
// CLASS FUNCTIONS: TGFFFileHandler
// =============================================================================


// -----------------------------------------------------------------------------
// Constructor - Creates a new GFF File Handler and initializes all variables
//               to their default values.
// -----------------------------------------------------------------------------
constructor TGFFFileHandler.Create();
begin
    inherited Create();
    Reset();
end;


// -----------------------------------------------------------------------------
// Destructor - clears out all stored data and then destroys the GFF File
//              handler object.
// -----------------------------------------------------------------------------
destructor TGFFFileHandler.Destroy();
begin
    // TODO: Free content of all arrays, set the array sizes to 0 and the array
    // references to nil.
    Reset();
    l_header.free();  // FIX(2005-05-31) Added this since its created in Reset()
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Resets the GFF File Handler, clearing out any loaded data, re-initializes all
// variables and making it clean for loading a new GFF file if desired.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.Reset();
var
   i : integer;
begin
    l_isloaded := False;
    // TODO: Free content of all arrays, set the array sizes to 0 and the array
    // references to nil.
    // Clear the header...
    l_header.free();
    l_header := TGFF_Header.Create();

    // Clear the Struct Array data...
    if (Length(l_structArray) > 0) then begin
       for i := Low(l_structArray) to High(l_structArray) do
           l_structArray[i].free();

       SetLength(l_structArray, 0);
       l_structArray := nil;
    end;

    // Clear the Field Array data...
    if (Length(l_fieldArray) > 0) then begin
       for i := Low(l_fieldArray) to High(l_fieldArray) do
           l_fieldArray[i].free();

       SetLength(l_fieldArray, 0);
       l_fieldArray := nil;
    end;

    // Clear the List Index Array data...
    if (Length(l_listIndexArray) > 0) then begin
       for i := Low(l_listIndexArray) to High(l_listIndexArray) do
           l_listIndexArray[i].free();

       SetLength(l_listIndexArray, 0);
       l_listIndexArray := nil;
    end;

    // Clear the Label Array....
    if (Length(l_labelArray) > 0) then begin
        SetLength(l_labelArray, 0);
        l_labelArray := nil;
    end;

    // Clear the Field Index Array...
    if (Length(l_fieldIndexArray) > 0) then begin
        for i := Low(l_fieldIndexArray) to High(l_fieldIndexArray) do
            l_fieldIndexArray[i].free();

        SetLength(l_fieldIndexArray, 0);
        l_fieldIndexArray := nil;
    end;
end;


// *****************************************************************************
// FILE SAVING FUNCTIONS
// *****************************************************************************

// -----------------------------------------------------------------------------
// TODO: The hard part... save it all back out to a file again.... *shudder*
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.SaveGffFile(sFilename : String);
var
   outFile : TFileStream;
begin
    if (l_isloaded = False) then
        raise EGFFError.Create('Unable to save, no file has been loaded that can be saved!');

     if SysUtils.FileExists(sFileName) then
        MakeFileWritable(sFilename);

     outFile := TFileStream.Create(sFilename, fmCreate or fmShareDenyWrite);
     // Add extra except block that deletes the file if Save failed? (EGFFError)
     try
         l_currdatapos  := 0;
         l_currfieldpos := 0;
         l_currlistpos  := 0;
         
         SaveGffHeader(outFile);
         SaveGffStructs(outFile);
         SaveGffFields(outFile);
         SaveGffLabels(outFile);
         // File Data Block is saved by SaveGffFields()
         // FieldIndexArray is saved by SaveGffStructs()
         // ListIndexArray is saved by SaveGffFields()
     finally
         outFile.free();
     end;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetFieldLength(oField : TGFF_Field) : DWORD;
var
   iDataBlockSize : DWORD;
begin
    iDataBlockSize := 0;

    case oField.fieldtype of
      // FIX(2005-05-19) Doh... Simple types are NOT stored in the data block...
      //  FIELD_TYPE_BYTE:          inc(iDataBlockSize, 1);
      //  FIELD_TYPE_CHAR:          inc(iDataBlockSize, 1);
      //  FIELD_TYPE_WORD:          inc(iDataBlockSize, 2);
      //  FIELD_TYPE_SHORT:         inc(iDataBlockSize, 2);
      //  FIELD_TYPE_DWORD:         inc(iDataBlockSize, 4);
      //  FIELD_TYPE_INT:           inc(iDataBlockSize, 4);
        FIELD_TYPE_DWORD64:       inc(iDataBlockSize, 8);
        FIELD_TYPE_INT64:         inc(iDataBlockSize, 8);
      //  FIELD_TYPE_FLOAT:         inc(iDataBlockSize, 4);
        FIELD_TYPE_DOUBLE:        inc(iDataBlockSize, 8);
        FIELD_TYPE_CEXOSTRING:    inc(iDataBlockSize, 4 + TGFF_CExoString(oField.fielddata).size);
        FIELD_TYPE_RESREF:        inc(iDataBlockSize, 1 + TGFF_CResRef(oField.fielddata).size);
        FIELD_TYPE_CEXOLOCSTRING: inc(iDataBlockSize, 4 + TGFF_CExoLocString(oField.fielddata).bytesize);
        FIELD_TYPE_VOID:          inc(iDataBlockSize, 4 + TGFF_CVoid(oField.fielddata).bytesize);
        FIELD_TYPE_ORIENTATION:   inc(iDataBlockSize, 16);  // FIX(2005-05-31) Undocumented type added in KotOR.
        FIELD_TYPE_POSITION:      inc(iDataBlockSize, 12);  // FIX(2005-05-31) Undocumented type added in KotOR.
    end;

    result := iDataBlockSize;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.SaveGffHeader(outFile : TFileStream);
var
   oField   : TGFF_Field;
   i        : integer;

   iDataBlockSize : DWORD;
   iFieldIndexSize : DWORD;
   iListIndexSize : DWORD;
begin
        // Write the Header...
        outFile.write(l_header.filetype, sizeof(l_header.filetype));
        outFile.write(l_header.fileversion, sizeof(l_header.fileversion));
        // StructArray always follows the fixed size header, thus the structoffset
        // will always be 56.
        l_header.structoffset := 56;
        outFile.write(l_header.structoffset, sizeof(l_header.structoffset));
        l_header.structcount := Length(l_structarray);
        outFile.write(l_header.structcount, sizeof(l_header.structcount));

        // Calculate the offset of the FieldArray by checking how large
        // the StructArray should be.
        l_header.fieldoffset := l_header.structoffset + (12 * l_header.structcount);
        outFile.write(l_header.fieldoffset, sizeof(l_header.fieldoffset));
        l_header.fieldcount := Length(l_fieldarray);
        outFile.write(l_header.fieldcount, sizeof(l_header.fieldcount));

        // Calculate the offset of the LabelArray by checking how large the
        // FieldArray should be.
        l_header.labeloffset := l_header.fieldoffset + (12 * l_header.fieldcount);
        outFile.write(l_header.labeloffset, sizeof(l_header.labeloffset));
        l_header.labelcount := Length(l_labelarray);
        outFile.write(l_header.labelcount, sizeof(l_header.labelcount));

        // Calculate the offset of the Field Data Block by checking how large
        // the LabelArray should be.
        l_header.fielddataoffset := l_header.labeloffset + (16 * l_header.labelcount);
        outFile.write(l_header.fielddataoffset, sizeof(l_header.fielddataoffset));

        // Calculate the size of the Field Data Block by going through all fields
        // and adding up the respective size of their data.
        iDataBlockSize := 0;
        for i := Low(l_fieldarray) to High(l_fieldarray) do begin
            oField := l_fieldarray[i];
            iDataBlockSize := iDataBlockSize + GetFieldLength(oField);
        end;

        // Set the newly calculated bytecount of the datablock....
        l_header.fielddatacount := iDataBlockSize;
        outFile.write(l_header.fielddatacount, sizeof(l_header.fielddatacount));

        // Set offset to start of the FieldIndexArray
        l_header.fieldindexoffset := l_header.fielddataoffset + iDataBlockSize;
        outFile.write(l_header.fieldindexoffset, sizeof(l_header.fieldindexoffset));

        // Get size of the FieldIndexArray... check how many indexes it contains
        // and multiply it with their individual size (DWORD = 4 byte).
        iFieldIndexSize := 0;
        for i := Low(l_fieldindexarray) to High(l_fieldindexarray) do
            inc(iFieldIndexSize, l_fieldindexarray[i].size * 4);

        // Set the newly calculated bytecount of the FieldIndexArray
        l_header.fieldindexcount := iFieldIndexSize;
        outFile.write(l_header.fieldindexcount, sizeof(l_header.fieldindexcount));

        // Set Offset to start of the ListIndexArray
        l_header.listindexoffset := l_header.fieldindexoffset + iFieldIndexSize;
        outFile.write(l_header.listindexoffset, sizeof(l_header.listindexoffset));

        iListIndexSize := 0;
        for i := Low(l_listindexarray) to High(l_listindexarray) do
            inc(iListIndexSize, 4 + (l_listindexarray[i].count * 4));

        // Write the new size of the ListIndexArray...
        l_header.listindexcount := iListIndexSize;
        outFile.write(l_header.listindexcount, sizeof(l_header.listindexcount));
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.WriteGffFieldIndexArray(outFile : TFileStream; iIndex : DWORD) : DWORD;
var
   i       : integer;
   iBuf    : DWORD;
   iOffset : DWORD;
begin
     if (iIndex > DWORD(High(l_fieldindexarray))) then
        raise EGFFError.CreateHelp('Invalid index encountered when writing FieldIndexArray data!', 16);

     outFile.seek(l_header.fieldindexoffset + l_currfieldpos, soFromBeginning);
     iOffset := l_currfieldpos;

     for i := Low(l_fieldindexarray[iIndex].indexes) to High(l_fieldindexarray[iIndex].indexes) do begin
         iBuf := l_fieldindexarray[iIndex].indexes[i];
         outFile.write(iBuf, sizeof(iBuf));
         l_currfieldpos := l_currfieldpos + sizeof(iBuf);
     end;
     
     result := iOffset;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.SaveGffStructs(outFile : TFileStream);
var
   i       : integer;
   iMem    : DWORD;
   iOffset : DWORD;
   oStruct : TGFF_Struct;
begin
    // Move to the beginning of the Struct Array space...
    outFile.Seek(l_header.structoffset, soFromBeginning);

    if (DWORD(Length(l_structarray)) <> l_header.structcount) then
       raise EGFFError.CreateHelp('Data state unreliable. Header structcount does not match struct array size!', 19);

    for i := Low(l_structarray) to High(l_structarray) do begin
        oStruct := l_structarray[i];

        if (oStruct.fieldcount = 1) then begin
            iOffset := oStruct.dataoroffset;
        end
        else if (oStruct.fieldcount > 1) then begin
            iMem := outFile.position;
            iOffset := WriteGffFieldIndexArray(outFile, oStruct.dataoroffset);
            outFile.Seek(iMem, soFromBeginning);
        end;

        // Write the data for this struct into the Struct Array...
        outFile.write(oStruct.typeid, sizeof(oStruct.typeid));
        outFile.write(iOffset, sizeof(iOffset));
        outFile.write(oStruct.fieldcount, sizeof(oStruct.fieldcount));
    end;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.WriteGffFieldData(outFile : TFileStream; oField : TGFF_Field) : DWORD;
var
   oExoLoc  : TGFF_CExoLocString;
   iOffset  : DWORD;
   iBuf     : DWORD;
   iBufS    : LongInt;
   i, n     : integer;
   byteBuf  : Byte;
begin
    outFile.seek(l_header.fielddataoffset + l_currdatapos, soFromBeginning);
    iOffset := l_currdatapos;

    case oField.fieldtype of
        FIELD_TYPE_DWORD64: begin
            outFile.write(TGFF_CDWORD64(oField.FieldData).value, 8);
            l_currdatapos := l_currdatapos + 8;
        end;

        FIELD_TYPE_INT64: begin
            outFile.write(TGFF_CInt64(oField.FieldData).value, 8);
            l_currdatapos := l_currdatapos + 8;
        end;

        FIELD_TYPE_DOUBLE: begin
            outFile.write(TGFF_CDouble(oField.FieldData).value, 8);
            l_currdatapos := l_currdatapos + 8;
        end;

        FIELD_TYPE_CEXOSTRING: begin
            iBuf := TGFF_CExoString(oField.FieldData).size;
            outFile.write(iBuf, sizeof(iBuf));
            for i := 0 to (iBuf-1) do
                outFile.write(TGFF_CExoString(oField.FieldData).text[i], 1);

            l_currdatapos := l_currdatapos + sizeof(iBuf) + iBuf;
        end;

        FIELD_TYPE_RESREF: begin
            byteBuf := TGFF_CResRef(oField.FieldData).size;
            outFile.write(byteBuf, sizeof(byteBuf));
            for i := 0 to (byteBuf-1) do
                outFile.write(TGFF_CResRef(oField.FieldData).text[i], 1);

            l_currdatapos := l_currdatapos + sizeof(byteBuf) + byteBuf;
        end;

        FIELD_TYPE_CEXOLOCSTRING: begin
            oExoLoc := TGFF_CExoLocString(oField.FieldData);

            outFile.write(oExoLoc.bytesize, sizeof(oExoLoc.bytesize));
            l_currdatapos := l_currdatapos + sizeof(oExoLoc.bytesize);

            outFile.write(oExoLoc.strref, sizeof(oExoLoc.strref));
            l_currdatapos := l_currdatapos + sizeof(oExoLoc.strref);

            iBuf := oExoLoc.stringcount;
            outFile.write(oExoLoc.stringcount, sizeof(oExoLoc.stringcount));
            l_currdatapos := l_currdatapos + sizeof(oExoLoc.stringcount);

            for i := Low(oExoLoc.substrings) to High(oExoLoc.substrings) do begin
                iBufS := oExoLoc.substrings[i].stringid;
                outFile.write(iBufS, sizeof(iBufS));
                l_currdatapos := l_currdatapos + sizeof(iBufS);

                iBufS := oExoLoc.substrings[i].stringlength;
                outFile.write(iBufS, sizeof(iBufS));
                l_currdatapos := l_currdatapos + sizeof(iBufS);

                for n := 0 to (iBufS-1) do
                    outFile.write(oExoLoc.substrings[i].text[n], 1);

                l_currdatapos := l_currdatapos + DWORD(iBufS);
            end;
        end;

        FIELD_TYPE_VOID: begin
           iBuf := TGFF_CVoid(oField.FieldData).bytesize;
           outFile.write(iBuf, sizeof(iBuf));
           outFile.write(TGFF_CVoid(oField.FieldData).data, iBuf);
           l_currdatapos := l_currdatapos + sizeof(iBuf) + iBuf;
        end;

        // FIX(2005-05-31) Added New type added in KotOR...
        FIELD_TYPE_ORIENTATION: begin
            for i := 0 to 3 do begin
                outFile.write(TGFF_COrientation(oField.FieldData).value[i], 4);
                l_currdatapos := l_currdatapos + 4;
            end;
        end;

        // FIX(2005-05-31) Added New type added in KotOR...
        FIELD_TYPE_POSITION: begin
            for i := 0 to 2 do begin
                outFile.write(TGFF_CPosition(oField.FieldData).value[i], 4);
                l_currdatapos := l_currdatapos + 4;
            end;
        end;
    end;

    result := iOffset;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.WriteGffListIndexArray(outFile : TFileStream; iIndex : DWORD) : DWORD;
var
   i       : integer;
   iBuf    : DWORD;
   iOffset : DWORD;
begin
     if (iIndex > DWORD(High(l_listindexarray))) then
        raise EGFFError.CreateHelp('Invalid index encountered when writing ListIndexArray data!', 17);

     outFile.seek(l_header.listindexoffset + l_currlistpos, soFromBeginning);
     iOffset := l_currlistpos;

     // Write the array length first...
     outFile.write(l_listindexarray[iIndex].count, sizeof(l_listindexarray[iIndex].count));

     // FIX(2005-07-21) HOPEFULLY fixes the corrupt listindexes written in some GFF files...
     //                 Odd that it didn't break more often that it did, pretty serious mistake. :)
     l_currlistpos := l_currlistpos + sizeof(l_listindexarray[iIndex].count);

     // Then write the entries for each array cell...
     for i := Low(l_listindexarray[iIndex].structs) to High(l_listindexarray[iIndex].structs) do begin
         iBuf := l_listindexarray[iIndex].structs[i];
         outFile.write(iBuf, sizeof(iBuf));
         l_currlistpos := l_currlistpos + sizeof(iBuf);
     end;

     result := iOffset;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.SaveGffFields(outFile : TFileStream);
var
   i       : integer;
   iMem    : DWORD;
   iOffset : DWORD;
   oField  : TGFF_Field;
begin
    // Move to the beginning of the Struct Array space...
    outFile.Seek(l_header.fieldoffset, soFromBeginning);

    if (DWORD(Length(l_fieldarray)) <> l_header.fieldcount) then
       raise EGFFError.CreateHelp('Data state unreliable. Header fieldcount does not match field array size!', 18);

    for i := Low(l_fieldarray) to High(l_fieldarray) do begin
        oField := l_fieldarray[i];

        // Write the Field Type and Label Index for this field...
        outFile.write(oField.fieldtype, sizeof(oField.fieldtype));
        outFile.write(oField.labelindex, sizeof(oField.labelindex));

        // Write the data, or offset to the data, depending on type...
        case oField.fieldtype of
            // Simple Byte  type, store it in the field and pad remaining 3 bytes.
            FIELD_TYPE_BYTE: begin
                outFile.write(TGFF_SByte(oField.fielddata).value, 1);
                outFile.seek(3, soFromCurrent);
            end;

            // Simple Char  type, store it in the field and pad remaining 3 bytes.
            FIELD_TYPE_CHAR: begin
                outFile.write(TGFF_SChar(oField.fielddata).value, 1);
                outFile.seek(3, soFromCurrent);
            end;

            // Simple Word type, store it in the field and pad remaining 2 bytes.
            FIELD_TYPE_WORD: begin
                outFile.write(TGFF_SWord(oField.fielddata).value, 2);
                outFile.seek(2, soFromCurrent);
            end;

            // Simple Short type, store it in the field and pad remaining 2 bytes.
            FIELD_TYPE_SHORT: begin
                outFile.write(TGFF_SShort(oField.fielddata).value, 2);
                outFile.seek(2, soFromCurrent);
            end;

            // Simple DWORD type, store it in the field.
            FIELD_TYPE_DWORD: begin
                outFile.write(TGFF_SDWORD(oField.fielddata).value, 4);
            end;

            // Simple Int type, store it in the field.
            FIELD_TYPE_INT: begin
                outFile.write(TGFF_SInt(oField.fielddata).value, 4);
            end;

            // Complex data types (part 1), write them into the Field Data Block
            // and store the resulting offsets.
            FIELD_TYPE_DWORD64..FIELD_TYPE_INT64: begin
                iMem := outFile.position;
                iOffset := WriteGffFieldData(outFile, oField);
                outFile.Seek(iMem, soFromBeginning);
                outFile.write(iOffset, sizeof(iOffset));
            end;

            // Float simple type, get the valyue and store in the field.
            FIELD_TYPE_FLOAT: begin
                outFile.write(TGFF_SFloat(oField.fielddata).value, 4);
            end;

            // Complex data types (part 2), write them into the Field Data Block
            // and store the resulting offsets.
            FIELD_TYPE_DOUBLE..FIELD_TYPE_VOID: begin
                iMem := outFile.position;
                iOffset := WriteGffFieldData(outFile, oField);
                outFile.Seek(iMem, soFromBeginning);
                outFile.write(iOffset, sizeof(iOffset));
            end;

            // FIX(2005-05-31) Two new complex data types added that were undocumented.
            FIELD_TYPE_ORIENTATION..FIELD_TYPE_POSITION: begin
                iMem := outFile.position;
                iOffset := WriteGffFieldData(outFile, oField);
                outFile.Seek(iMem, soFromBeginning);
                outFile.write(iOffset, sizeof(iOffset));
            end;

            // It's a struct... dataoroffset contains index into StructArray. Write it.
            FIELD_TYPE_STRUCT: begin
                outFile.write(oField.dataoroffset, sizeof(oField.dataoroffset));
            end;

            // It's a list... dataoroffset contains index into ListIndexArray, write the
            // relevant entries into that array and store the resulting byte offsets.
            FIELD_TYPE_LIST: begin
                iMem := outFile.position;
                iOffset := WriteGffListIndexArray(outFile, oField.dataoroffset);
                outFile.Seek(iMem, soFromBeginning);
                outFile.write(iOffset, sizeof(iOffset));
            end;
        end;
    end;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.SaveGffLabels(outFile : TFileStream);
var
   i : integer;
begin
    outFile.Seek(l_header.labeloffset, soFromBeginning);

    if (DWORD(Length(l_labelarray)) <> l_header.labelcount) then
       raise EGFFError.CreateHelp('Data state unreliable. Header labelcount does not match label array size!', 20);

    for i := Low(l_labelarray) to High(l_labelarray) do
        outFile.write(l_labelarray[i], 16);
end;


// *****************************************************************************
// FILE LOADING FUNCTIONS....
// *****************************************************************************

// -----------------------------------------------------------------------------
// Main function used for loading a GFF into memory from the file.
//
// Parameters:
//   sFilename  = Absolute path and name of the GFF file to load.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.LoadGffFile(sFilename : string);
var
   inFile     : TFileStream;
begin
     Reset();

     inFile := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyWrite);
     try
        LoadGffHeader(inFile);
        LoadLabelArray(inFile);
        LoadStructArray(inFile);
        LoadFieldArray(inFile);
        // FieldIndexArray is loaded by LoadStructArray
        // ListIndexArray is loaded by LoadFieldArray
        l_isloaded := True;
     finally
         inFile.free();
     end;
end;


// -----------------------------------------------------------------------------
// Support function: Load the Header of the GFF file into memory.
//
// Parameters:
//   inFile  = Open filestream for accessing the GFF File.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.LoadGffHeader(inFile : TFileStream);
begin
     inFile.read(l_header.filetype, 4);
     inFile.read(l_header.fileversion, 4);

     // Format version mismatch, unable to continue.
     if (l_header.fileversion <> 'V3.2') then begin
        Reset();
        raise EGFFError.CreateHelp('Invalid file version. Loaded file is not in GFF V3.2 format!', 1);
     end;

     // Read in the Struct Array offset & count
     inFile.Read(l_header.structoffset, sizeof(l_header.structoffset));
     inFile.Read(l_header.structcount, sizeof(l_header.structcount));
         
     // Read in the Field Array offset & count
     inFile.Read(l_header.fieldoffset, sizeof(l_header.fieldoffset));
     inFile.Read(l_header.fieldcount, sizeof(l_header.fieldcount));

     // Read in the Label Array offset & count
     inFile.Read(l_header.labeloffset, sizeof(l_header.labeloffset));
     inFile.Read(l_header.labelcount, sizeof(l_header.labelcount));

     // Read in the File Data Block offset & count
     inFile.Read(l_header.fielddataoffset, sizeof(l_header.fielddataoffset));
     inFile.Read(l_header.fielddatacount, sizeof(l_header.fielddatacount));

     // Read in the Field Index Array offset & count
     inFile.Read(l_header.fieldindexoffset, sizeof(l_header.fieldindexoffset));
     inFile.Read(l_header.fieldindexcount, sizeof(l_header.fieldindexcount));

     // Read in the List Index Array offset & count
     inFile.Read(l_header.listindexoffset, sizeof(l_header.listindexoffset));
     inFile.Read(l_header.listindexcount, sizeof(l_header.listindexcount));
end;


// -----------------------------------------------------------------------------
// Support function: Load the Label Array section of the GFF file into memory.
//
// Parameters:
//   inFile  = Open filestream for accessing the GFF File.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.LoadLabelArray(inFile : TFileStream);
var
   sBuffer : T16Char;
   i       : integer;
begin
     if (l_header.labelcount > 0) then begin
        inFile.Seek(l_header.labeloffset, soFromBeginning);
        SetLength(l_labelarray, l_header.labelcount);

        for i := 0 to (l_header.labelcount - 1) do begin
            inFile.Read(sBuffer, sizeof(sBuffer));
            l_labelarray[i] := sBuffer;
        end;
     end;
end;


// -----------------------------------------------------------------------------
// Support function: Populates the FieldIndexArray for a struct and returns the
//                   array index of the newly added list of field indexes.
//
// Parameters:
//   inFile  = Open filestream for accessing the GFF File.
//   iOffset = Offset within the FieldIndexArray data to look for the starting
//             position of the list at.
//   iCount  = The number of entries the list contains.
// -----------------------------------------------------------------------------
function TGFFFileHandler.LookupFieldIndexArrayOffset(inFile : TFileStream; iOffset : DWORD; iCount : DWORD) : DWORD;
var
   i, e    : integer;
   iBuffer : DWORD;
   oIdx    : TGFF_FieldIndex;
begin
    iOffset := l_header.fieldindexoffset + iOffset;
    inFile.Seek(iOffset, soFromBeginning);

    oIdx := TGFF_FieldIndex.Create();
    i := Length(l_fieldIndexArray);
    // FIX(2005-05-18) No good using a 2D array here, switched to using an array of
    //                 objects that encapsulate an array of their own. a 2D array
    //                 would require an identical number of listindexes for all structs
    //                 to work well, which isn't desirable here...
    SetLength(l_fieldIndexArray, i + 1);
    SetLength(oIdx.indexes, iCount);

    for e := Low(oIdx.indexes) to High(oIdx.indexes) do begin
        inFile.read(iBuffer, sizeof(iBuffer));
        oIdx.indexes[e] := iBuffer;
    end;

    l_fieldIndexArray[i] := oIdx;
    result := i;
end;


// -----------------------------------------------------------------------------
// Support function: Load the Struct Array section of the GFF file into memory.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.LoadStructArray(inFile : TFileStream);
var
   oStruct : TGFF_Struct;
   iBuffer : DWORD;
   i       : integer;
   iMem    : DWORD;
begin
    if (l_header.structcount > 0) then begin
       inFile.Seek(l_header.structoffset, soFromBeginning);
       SetLength(l_structarray, l_header.structcount);

       for i := 0 to (l_header.structcount - 1) do begin
           oStruct := TGFF_Struct.Create();

           inFile.read(iBuffer, sizeof(iBuffer));
           oStruct.typeid := iBuffer;

           inFile.read(iBuffer, sizeof(iBuffer));
           oStruct.dataoroffset := iBuffer;

           inFile.read(iBuffer, sizeof(iBuffer));
           oStruct.fieldcount := iBuffer;

           // If the struct contains more than one field, store the index of those fields
           // in the FieldIndexArray in the dataoroffset field. (If the struct only has one
           // field dataoroffset is already the index to the FieldArray)
           if (oStruct.fieldcount > 1) then begin
               iMem := inFile.position;
               oStruct.dataoroffset := LookupFieldIndexArrayOffset(inFile, oStruct.dataoroffset, oStruct.fieldcount);
               inFile.Seek(iMem, soFromBeginning);
           end
           else if (oStruct.fieldcount < 1) then begin
               raise EGFFError.CreateHelp('Error reading struct ' + IntToStr(i) + ', struct contained no fields!', 2);
           end;

           l_structarray[i] := oStruct;
       end;

    end
    else begin
         raise EGFFError.CreateHelp('Critical error, root struct of GFF file not present! Unable to proceed.', 3);
    end;
end;


// -----------------------------------------------------------------------------
// Support function: Packs up a simple data type read from disk into a
//                   TGFF_FieldData sub-object which is then returned.
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetSimpleDataType(inFile : TFileStream; iType : DWORD) : TGFF_FieldData;
var
   oByte : TGFF_SByte;
   oChar : TGFF_SChar;
   oWord : TGFF_SWord;
   oShort: TGFF_SShort;
   oDWORD: TGFF_SDWORD;
   oInt  : TGFF_SInt;
   oFloat: TGFF_SFloat;

begin
     case (iType) of
         FIELD_TYPE_BYTE: begin
             oByte := TGFF_SByte.Create();
             inFile.read(oByte.value, sizeof(oByte.value));
             result := oByte;
         end;

         FIELD_TYPE_CHAR: begin
             oChar := TGFF_SChar.Create();
             inFile.read(oChar.value, sizeof(oChar.value));
             result := oChar;
         end;

         FIELD_TYPE_WORD: begin
             oWord := TGFF_SWord.Create();
             inFile.read(oWord.value, sizeof(oWord.value));
             result := oWord;
         end;

         FIELD_TYPE_SHORT: begin
             oShort := TGFF_SShort.Create();
             inFile.read(oShort.value, sizeof(oShort.value));
             result := oShort;
         end;

         FIELD_TYPE_DWORD: begin
             oDWORD := TGFF_SDWORD.Create();
             inFile.read(oDWORD.value, sizeof(oDWORD.value));
             result := oDWORD;
         end;

         FIELD_TYPE_INT: begin
             oInt := TGFF_SInt.Create();
             inFile.read(oInt.value, sizeof(oInt.value));
             result := oInt;
         end;

         FIELD_TYPE_FLOAT: begin
             oFloat := TGFF_SFloat.Create();
             inFile.read(oFloat.value, sizeof(oFloat.value));
             result := oFloat;
         end;
     else
         raise EGFFError.CreateHelp('Invalid field type encountered when reading simple field data type!', 4);
     end;
end;


// -----------------------------------------------------------------------------
// Support function: Packs up a complex data type read from disk into a
//                   TGFF_FieldData sub-object which is then returned.
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetComplexDataType(inFile : TFileStream; iType : DWORD) : TGFF_FieldData;
var
   oDWORD64      : TGFF_CDWORD64;
   oInt64        : TGFF_CInt64;
   oDouble       : TGFF_CDouble;
   oExoString    : TGFF_CExoString;
   oResref       : TGFF_CResRef;
   oExoLocString : TGFF_CExoLocString;
   oSubString    : TGFF_CSubString;
   oVoid         : TGFF_CVoid;
   oOrientation  : TGFF_COrientation;
   oPosition     : TGFF_CPosition;

   iOffset       : DWORD;
   sBuffer       : TBuffer;
   iBuffer       : array [0..BYTE_BUFFER_SIZE] of Byte;
   i, n          : integer;
begin
     i := 0;
    // Get offset within File Data Block
    inFile.read(iOffset, sizeof(iOffset));

    // Error! Corrupted offset, seek wound lead beyond end of file...
    if ((l_header.fielddataoffset + iOffset) > DWORD(inFile.size)) then
       raise EGFFError.CreateHelp('Error reading CExoString data offset! Specified offset lies beyond EOF.', 7);

    InFile.seek(l_header.fielddataoffset + iOffset, soFromBeginning);

    case (iType) of
        FIELD_TYPE_DWORD64: begin
            oDWORD64 := TGFF_CDWORD64.Create();
            inFile.read(oDWORD64.value, sizeof(oDWORD64.value));
            result := oDWORD64;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_INT64: begin
            oInt64 := TGFF_CInt64.Create();
            inFile.read(oInt64.value, sizeof(oInt64.value));
            result := oInt64;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_DOUBLE: begin
            oDouble := TGFF_CDouble.Create();
            inFile.read(oDouble.value, sizeof(oDouble.value));
            result := oDouble;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_CEXOSTRING: begin
            oExoString := TGFF_CExoString.Create();
            inFile.read(oExoString.size, sizeof(oExoString.size));

            // Error! Text is much longer than the 1024 character max of the ExoString spec.
            if (oExoString.size > 2048) then
               raise EGFFError.CreateHelp('Error loading CExoString field, text is too long!', 6);

            // Get the string itself...
            inFile.read(sBuffer, oExoString.size);
            SetLength(oExoString.text, oExoString.size);
            for i := Low(oExoString.text) to High(oExoString.text) do
                oExoString.text[i] := sBuffer[i];

            result := oExoString;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_RESREF: begin
            oResRef := TGFF_CResRef.Create();
            inFile.read(oResRef.size, sizeof(oResRef.size));

            // Error! Text is much longer than the 1024 character max of the ExoString spec.
            if (oResRef.size > 16) then
               raise EGFFError.CreateHelp('Error loading CResRef field, string is too long!', 8);

            inFile.read(sBuffer, oResRef.size);
            SetLength(oResRef.text, oResRef.size);
            for i := Low(oResRef.text) to High(oResRef.text) do
                oResRef.text[i] := sBuffer[i];

            result := oResRef;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_CEXOLOCSTRING: begin
            oExoLocString := TGFF_CExoLocString.Create();
            inFile.Read(oExoLocString.bytesize, sizeof(oExoLocString.bytesize));
            inFile.Read(oExoLocString.strref, sizeof(oExoLocString.strref));
            inFile.Read(oExoLocString.stringcount, sizeof(oExoLocString.stringcount));

            if (oExoLocString.stringcount > 0) then begin
                SetLength(oExoLocString.substrings, oExoLocString.stringcount);
                for i := 0 to (oExoLocString.stringcount - 1) do begin
                    // This is UGLY... The ExoLocStr class should handle its substrings instead...
                    // ...some time when I feel like doing things the proper way... :)
                    oSubString := TGFF_CSubString.Create();
                    inFile.Read(oSubString.stringid, sizeof(oSubString.stringid));
                    inFile.Read(oSubString.stringlength, sizeof(oSubString.stringlength));

                    if (oSubString.stringlength > 0) then begin
                        // Error! Text is much longer than the 1024 character max of the ExoString spec.
                        if (oSubString.stringlength > 2048) then
                            raise EGFFError.CreateHelp('Error loading CExoLocString substring, text is too long!', 10);

                        inFile.Read(sBuffer, oSubString.stringlength);
                        // FIX(2005-05-18): Forgot to set size of substring char array... Doh...
                        SetLength(oSubString.text, oSubString.stringlength);

                        for n := 0 to (oSubString.stringlength - 1) do
                            oSubString.text[n] := sBuffer[n];
                    end;

                    oExoLocString.substrings[i] := oSubString;
                end;
            end;
            result := oExoLocString;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_VOID: begin
            oVoid := TGFF_CVoid.Create();
            inFile.read(oVoid.bytesize, sizeof(oVoid.bytesize));
            SetLength(oVoid.data, oVoid.bytesize);

            // Binary data fits within read buffer
            if (oVoid.bytesize <= BYTE_BUFFER_SIZE) then begin
               inFile.read(iBuffer, oVoid.bytesize);
               for i := Low(oVoid.data) to High(oVoid.data) do
                   oVoid.data[i] := iBuffer[i];

               result := oVoid;
            end
            // This is an ugly hack... don't know how long the binary data can be...
            // Should probably make it block read the whole bunch instead no matter how
            // long it is.... sometime. :) This will have to do for now...
            else
                raise EGFFError.CreateHelp('Oops. Read buffer capacity exceeded when loading Void data! Please report this ASAP!', 9);
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_ORIENTATION: begin
            // FIX(2005-05-31) Added this, new undocumented KotOR field type...
            oOrientation := TGFF_COrientation.Create();
            for i := 0 to 3 do
                inFile.read(oOrientation.value[i], 4);

            result := oOrientation;
        end;
        // -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        FIELD_TYPE_POSITION: begin
            // FIX(2005-05-31) Added this, new undocumented KotOR field type...        
            oPosition := TGFF_CPosition.Create();
            for i := 0 to 2 do
                inFile.read(oPosition.value[i], 4);

            result := oPosition;
        end;
    else
        raise EGFFError.CreateHelp('Invalid field type encountered when reading field ' + IntToStr(i) + ' data!', 5);
    end;
end;


// -----------------------------------------------------------------------------
// Support function: Builds a ListIndexArray entry for the current field
//                   and returns the array index the entry was inserted at.
// -----------------------------------------------------------------------------
function TGFFFileHandler.ProcessListIndexArrayOffset(inFile : TFileStream; iOffset : DWORD) : DWORD;
var
   i       : integer;
   iBuffer : DWORD;
   iIndex  : DWORD;
   oList   : TGFF_List;
begin
    iOffset := l_header.listindexoffset + iOffset;
    inFile.Seek(iOffset, soFromBeginning);

    iIndex := Length(l_listIndexArray);
    SetLength(l_listIndexArray, iIndex + 1);

    oList := TGFF_List.Create();
    inFile.Read(oList.count, sizeof(oList.count));
    if (oList.count > 0) then begin
        SetLength(oList.structs, oList.count);

        for i := 0 to (oList.count - 1) do begin
            inFile.read(iBuffer, sizeof(iBuffer));
            oList.structs[i] := iBuffer;
        end;
    end;

    l_listIndexArray[iIndex] := oList;
    result := iIndex;
end;

// -----------------------------------------------------------------------------
// Support function: Loads the file array from file into memory, building all
//                   sub-objects the fields contain.
// -----------------------------------------------------------------------------
procedure TGFFFileHandler.LoadFieldArray(inFile : TFileStream);
var
   oField  : TGFF_Field;
   i       : integer;
   iBuffer : DWORD;
   iMem1   : DWORD;
   iMem2   : DWORD;
begin
    if (l_header.fieldcount > 0) then begin
       inFile.Seek(l_header.fieldoffset, soFromBeginning);
       SetLength(l_fieldarray, l_header.fieldcount);

       for i := 0 to (l_header.fieldcount - 1) do begin
           oField := TGFF_Field.Create();

           inFile.read(iBuffer, sizeof(iBuffer));
           oField.fieldtype := iBuffer;

           inFile.read(iBuffer, sizeof(iBuffer));
           oField.labelindex := iBuffer;

           iMem1 := inFile.position;
           inFile.read(iBuffer, sizeof(iBuffer));
           oField.dataoroffset := iBuffer;
           iMem2 := inFile.position;

           // Set the file pointer back to the offsetordata offset for the below
           // functions to read...
           inFile.seek(iMem1, soFromBeginning);

           case (oField.fieldtype) of
               // It's a simple data type, get an object containing its value....
               FIELD_TYPE_BYTE..FIELD_TYPE_INT, FIELD_TYPE_FLOAT: begin
                   oField.fielddata := GetSimpleDataType(inFile, oField.fieldtype);
               end;

               // It's a complex data type, get an object containing its value...
               FIELD_TYPE_DWORD64, FIELD_TYPE_INT64, FIELD_TYPE_DOUBLE..FIELD_TYPE_VOID: begin
                   oField.fielddata := GetComplexDataType(inFile, oField.fieldtype);
               end;

               // It's a struct, get the index into the StructArray...
               FIELD_TYPE_STRUCT: begin
                   oField.fielddata := nil;
                   inFile.read(iBuffer, sizeof(iBuffer));
                   oField.dataoroffset := iBuffer;
               end;

               // It's a list, dataoroffset is an offset into the listindex array.
               // Build that listindex and then return the index in the array for this field.
               FIELD_TYPE_LIST: begin
                   oField.fielddata := nil;
                   oField.dataoroffset := ProcessListIndexArrayOffset(inFile, oField.dataoroffset);
               end;

               FIELD_TYPE_ORIENTATION, FIELD_TYPE_POSITION: begin
                   oField.fielddata := GetComplexDataType(inFile, oField.fieldtype);
               end;
           else
               raise EGFFError.CreateHelp('Invalid field type encountered when reading field ' + IntToStr(i) + ' data!', 4);
           end;

           l_fieldarray[i] := oField;

           // Set the file pointer back to the end of this entry in the field array.
           inFile.seek(iMem2, soFromBeginning);

       end;
    end;
end;

// *****************************************************************************
// DATA MANIPULATION FUNCTIONS
// *****************************************************************************


function TGFFFileHandler.SetGffField(sTarget : string; sValue : string) : boolean;
begin
     l_modifyfield := sTarget;
     l_modifyvalue := sValue;

     // Start searching for the specified field from the Root Struct...
     result := SearchGffStruct(0, '');
end;


function TGFFFileHandler.SearchGffStruct(iIndex : integer; sPath : string) : boolean;
var
   oStruct     : TGFF_Struct;
   fieldIdx    : TGFF_FieldIndex;
   i           : integer;
begin
    oStruct := structs[iIndex];
    result := false;

    // Struct only contains one field, access it directly...
    if (oStruct.fieldcount = 1) then begin
        result := SearchGffField(oStruct.dataoroffset, sPath);
    end
    // Struct contains multiple fields, look them all up in the FieldIndexArray...
    else if (oStruct.fieldcount > 1) then begin
        fieldIdx := fieldindex[oStruct.dataoroffset];

        for i := Low(fieldIdx.indexes) to High(fieldIdx.indexes) do begin
            result := SearchGffField(fieldIdx.indexes[i], sPath);
            if (result = True) then
                exit;
        end;
    end;
end;


function TGFFFileHandler.SearchGffList(iIndex : integer; sPath : string) : boolean;
var
   oList   : TGFF_List;
   i       : integer;
begin
    oList := listindex[iIndex];
    result := false;

    if (oList.count > 0) then begin
        for i := Low(oList.structs) to High(oList.structs) do begin
            result := SearchGffStruct(oList.structs[i], sPath + IntToStr(i) + '\');
            if (result = True) then
               exit;
        end;

    end;
end;


function TGFFFileHandler.SearchGffField(iIndex : integer; sPath : string) : boolean;
var
   oField   : TGFF_Field;
   oExoLoc  : TGFF_CExoLocString;
   oTokens  : TStringTokenizer;
   sLabel   : string;
   sSub     : string;
   sLang    : string;
   sTag     : string;
   i        : integer;
   iPos     : integer;
   iLang    : integer;
begin
    oField := fields[iIndex];
    sLabel := labels[oField.labelindex];

    if (oField.fieldtype = FIELD_TYPE_STRUCT) then begin
        result := SearchGffStruct(oField.dataoroffset, sPath + sLabel + '\');
        exit;
    end
    else if (oField.fieldtype = FIELD_TYPE_LIST) then begin
        result := SearchGffList(oField.dataoroffset, sPath + sLabel + '\');
        exit;
    end
    // NEW! CHECK THIS THOROUGHLY FOR BUGS!!!!
    // ------------------------------------------------------------------->
    else if (oField.fieldtype = FIELD_TYPE_CEXOLOCSTRING) then begin
        oExoLoc := TGFF_CExoLocString(oField.FieldData);

        // Since you can't assign a value to a CExoLocString without telling
        // what value to assign to, skip if an identifier is missing from the
        // search path...
        if (Pos('(', l_modifyfield) <> 0) then begin

            // Cut away the identifier to get the real field search path...
            iPos := Pos('(', l_modifyfield);
            sSub := copy(l_modifyfield, 1, iPos - 1);

            // See if the current path matches the path of the desired field.
            if ((sPath + sLabel) = sSub) then begin

                // Get the ()-enclosed CExoLocString field modifier tag...
                sTag := copy(l_modifyfield, iPos, (Pos(')', l_modifyfield) + 1) - iPos);

                // It's a StrRef
                if (sTag = '(strref)') then begin
                    if (l_modifyvalue = '-1') then
                        oExoLoc.strref := $FFFFFFFF
                    else if (GetIsNumber(l_modifyvalue)) then
                        oExoLoc.strref := StrToInt(l_modifyvalue);
                end
                // It's a language id identifier!
                else if (copy(sTag, 1, 5) = '(lang') then begin

                    // Extract the language id number from the identifier
                    sLang := copy(l_modifyfield, (iPos + 1) + Length('lang'), Pos(')', l_modifyfield) - ((iPos+1) + Length('lang')) );

                    // Modify the string value of that language id...
                    if(GetIsNumber(sLang)) then begin
                        iLang := StrToInt(sLang);
                        for i := Low(oExoLoc.substrings) to High(oExoLoc.substrings) do begin
                            if (oExoLoc.substrings[i].stringid = iLang) then
                                oExoLoc.strings[i] := l_modifyvalue;
                        end;
                    end;
                end;
                // It was a label-path match, so return true.
                result := true;
                exit;
            end;
        end;
    end
    // <-------------------------------------------------------------------
    else if ((sPath + sLabel) = l_modifyfield) then begin
        // FIELD_TYPE_DWORD64 left out on purpose for now, since it's too much work
        // for my feeble math skills to convert the value into the proper format
        // as my Delphi apparently has no native Unsigned 64 bit Int data type... :/
        //
        // FIELD_TYPE_CEXOLOCSTRING is handled separately, see above...
        //
        // FIELD_TYPE_VOID left out on purpose for now since it doesn't exactly mesh
        // well with text input for modified value...
        case oField.fieldtype of
            FIELD_TYPE_BYTE: begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_SByte(oField.FieldData).value := StrToInt(l_modifyvalue);
            end;

            FIELD_TYPE_CHAR: begin
                if (Length(l_modifyvalue) > 0) then
                    TGFF_SChar(oField.FieldData).value := l_modifyvalue[1];
            end;

            FIELD_TYPE_WORD: begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_SWord(oField.FieldData).value := StrToInt(l_modifyvalue);
            end;

            FIELD_TYPE_SHORT:  begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_SShort(oField.FieldData).value := StrToInt(l_modifyvalue);
            end;

            FIELD_TYPE_DWORD: begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_SDWORD(oField.FieldData).value := StrToInt(l_modifyvalue);
            end;

            FIELD_TYPE_INT: begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_SInt(oField.FieldData).value := StrToInt(l_modifyvalue);
            end;

            FIELD_TYPE_INT64: begin
                if (GetIsNumber(l_modifyvalue)) then
                    TGFF_CInt64(oField.FieldData).value := StrToInt64(l_modifyvalue);
            end;

            FIELD_TYPE_FLOAT: begin
                if (GetIsFloat(l_modifyvalue)) then
                    TGFF_SFloat(oField.FieldData).value := SafeStrToFloat(l_modifyvalue);
            end;

            FIELD_TYPE_DOUBLE: begin
                if (GetIsFloat(l_modifyvalue)) then
                    TGFF_CDouble(oField.FieldData).value := SafeStrToDouble(l_modifyvalue);
            end;

            FIELD_TYPE_CEXOSTRING: begin
                TGFF_CExoString(oField.FieldData).textstring := l_modifyvalue;
            end;

            FIELD_TYPE_RESREF: begin
                TGFF_CResRef(oField.FieldData).textstring := l_modifyvalue;
            end;

            // FIX(2005-05-31) Added support for undocumented KotOR field type. Specify
            //                 input values in format "1.0|2.0|3.0|4.0"
            FIELD_TYPE_ORIENTATION: begin
                oTokens := TStringTokenizer.Create(l_modifyvalue, '|');
                if (oTokens.count = 4) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_COrientation(oField.FieldData).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
            end;

            // FIX(2005-05-31) Added support for undocumented KotOR field type. Specify
            //                 input values in format "1.0|2.0|3.0"
            FIELD_TYPE_POSITION: begin
                oTokens := TStringTokenizer.Create(l_modifyvalue, '|');
                if (oTokens.count = 3) then begin
                    for i := 0 to (oTokens.count - 1) do begin
                        if GetIsFloat(oTokens[i]) then begin
                            TGFF_CPosition(oField.FieldData).value[i] := SafeStrToFloat(oTokens[i]);
                        end;
                    end;
                end;
                oTokens.free();
            end;
        end;

        result := true;
        exit;
    end;

    result := false;
end;


// *****************************************************************************

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetLabel(iIndex : integer) : string;
begin
     if (iIndex >= Low(l_labelArray)) and (iIndex <= High(l_labelArray)) then begin
        result := l_labelArray[iIndex];
     end
     else
         result := 'ERROR!';
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetField(iIndex : integer) : TGFF_Field;
begin
    if (iIndex >= Low(l_fieldarray)) and (iIndex <= High(l_fieldarray)) then begin
         result := l_fieldarray[iIndex];
    end
    else
        raise EGFFError.CreateHelp('Invalid field index ' + IntToStr(iIndex) + ' specified in GetField!', 11);
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetStruct(iIndex : integer) : TGFF_Struct;
begin
    if (iIndex >= Low(l_structarray)) and (iIndex <= High(l_structarray)) then begin
        result := l_structarray[iIndex];
    end
    else
        raise EGFFError.CreateHelp('Invalid struct index ' + IntToStr(iIndex) + ' specified in GetStruct!', 13);
end;

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetFieldIndex(iIndex : integer) : TGFF_FieldIndex;
begin
    if (iIndex >= Low(l_fieldindexarray)) and (iIndex <= High(l_fieldindexarray)) then begin
        result := l_fieldindexarray[iIndex];
    end
    else
        raise EGFFError.CreateHelp('Invalid fieldindex index ' + IntToStr(iIndex) + ' specified in GetFieldIndex!', 14);
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function TGFFFileHandler.GetListIndex(iIndex : integer) : TGFF_List;
begin
    if (iIndex >= Low(l_listIndexArray)) and (iIndex <= High(l_listIndexArray)) then begin
        result := l_listIndexArray[iIndex];
    end
    else
        raise EGFFError.CreateHelp('Invalid List index ' + IntToStr(iIndex) + ' specified in GetListIndex!', 15);
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
    SetLength(text, 0);
    size := 0;
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
    SetLength(text, 0);
    size := 0;
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
    SetLength(substrings, 0);
    strref := $FFFFFFFF;
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


// =============================================================================
// CLASS FUNCTIONS: The Rest...
// =============================================================================

// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_CVoid.Create();
begin
    inherited Create();
    bytesize := 0;
    SetLength(data, 0);
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
constructor TGFF_List.Create();
begin
    inherited Create();
    count := 0;
    SetLength(structs, 0);
end;


// -----------------------------------------------------------------------------
// Destructor
// -----------------------------------------------------------------------------
destructor TGFF_List.Destroy();
begin
    if (Length(structs) > 0) then begin
        SetLength(structs, 0);
        structs := nil;
    end;
    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_Field.Create();
begin
    inherited Create();
    fielddata := nil;
end;


// -----------------------------------------------------------------------------
// Destructor
// -----------------------------------------------------------------------------
destructor TGFF_Field.Destroy();
begin
    if (fielddata <> nil) then
       fielddata.free();

    inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
constructor TGFF_FieldIndex.Create();
begin
     inherited Create();
     SetLength(indexes, 0);
end;


// -----------------------------------------------------------------------------
// Destructor
// -----------------------------------------------------------------------------
destructor TGFF_FieldIndex.Destroy();
begin
     SetLength(indexes, 0);
     indexes := nil;
     inherited Destroy();
end;


// -----------------------------------------------------------------------------
// Return the number of indexes in the currently loaded data....
// -----------------------------------------------------------------------------
function TGFF_FieldIndex.GetSize() : DWORD;
begin
     if (indexes <> nil) then
        result := Length(indexes)
     else
         result := 0;
end;


// -----------------------------------------------------------------------------
// DEBUG FUNCTION: Return the field data value as a string...
// -----------------------------------------------------------------------------
function TGFF_Field.GetString() : string;
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
    // Meep! Don't continue if fielddata is unset for whatever reason...
    if (    (fieldtype <> FIELD_TYPE_STRUCT)
        and (fieldtype <> FIELD_TYPE_LIST)
        and (fielddata = nil))
    then
        raise EGFFError.CreateHelp('Missing field data when looking up field!', 12);

    case fieldtype of
        FIELD_TYPE_BYTE:          result := IntToStr(TGFF_SByte(fielddata).value);
        FIELD_TYPE_CHAR:          result := TGFF_SChar(fielddata).value;
        FIELD_TYPE_WORD:          result := IntToStr(TGFF_SWord(fielddata).value);
        FIELD_TYPE_SHORT:         result := IntToStr(TGFF_SShort(fielddata).value);
        FIELD_TYPE_DWORD:         result := IntToStr(TGFF_SDWORD(fielddata).value);
        FIELD_TYPE_INT:           result := IntToStr(TGFF_SInt(fielddata).value);
        FIELD_TYPE_DWORD64:       result := DWORD64ToString(TGFF_CDWORD64(fielddata).value);
        FIELD_TYPE_INT64:         result := IntToStr(TGFF_CInt64(fielddata).value);
        FIELD_TYPE_FLOAT:         result := FloatToStr(TGFF_SFloat(fielddata).value);
        FIELD_TYPE_DOUBLE:        result := FloatToStr(TGFF_CDouble(fielddata).value);
        FIELD_TYPE_CEXOSTRING:    result := CExoStringToString(TGFF_CExoString(fielddata));
        FIELD_TYPE_RESREF:        result := CResRefToString(TGFF_CResRef(fielddata));
        FIELD_TYPE_CEXOLOCSTRING: result := ExoLocToString(TGFF_CExoLocString(fielddata));
        FIELD_TYPE_VOID:          result := '(Raw Binary data, size=' + IntToStr(TGFF_CVoid(fielddata).bytesize) + ')';
        FIELD_TYPE_STRUCT:        result := '[STRUCT]';
        FIELD_TYPE_LIST:          result := '[LIST]';
        FIELD_TYPE_ORIENTATION:   result := OrientationToString(TGFF_COrientation(fielddata));
        FIELD_TYPE_POSITION:      result := PositionToString(TGFF_CPosition(fielddata));
    end;
end;


end.
 
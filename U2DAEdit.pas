unit U2DAEdit;
(*
2DA is the 2-dimensional array format, used to store a large number of tables
pertaining to everything from game rules to graphics and sound definitions.

1) There is not much to say about the 2DA V2.b header, it's just the
string "2DA V2.b" followed by a linefeed character.

2) Directly following the header is a list of column names. Each name is an
ASCII string terminated with a tab character. The end of the list is signified
by a null character.

3) Following the column list is a 32-bit unsigned integer containing the number
of rows in the table.

4) This is then followed with another tab-terminated list, containing the row
names. Unlike the column list, it has no null terminator.

5) Following the row list is a two dimensional array, in row major order,
containing 16-bit offsets into a data area for each cell in the table.
Offsets are relative to the start of the data area.

6) This is followed by 2 unused bytes.

7) And then a data section of null terminated strings.


TStringList <--- check if this class will be useful for this, probably overkill.

A : array of array of string;
SetLength(A, 10); <-- results in a[0..9]

a := nil <-- unallocates the array

Null character                          #0
Linefeed character. ASCII 0x0A.         #10      (radmatning)
Tab character. ASCII 0x09.              #9
Backspace character. ASCII 0x08.        #8
Carriage-return character. ASCII 0x0D.  #13      (Vagnretur! Vilket namn...)

*)
interface

uses sysutils, classes, windows;

type
TResRef = array[0..15] of Char;
THeader = array[0..7] of Char;
TBuffer = array[0..4095] of Char;
TOffsets = array of array of Word;


EDead = Class(Exception);

T2DAHandler = Class(TObject)
    private
        l_columns      : integer;
        l_rows         : integer;

        l_columnlabels : array of string;
        l_rowlabels    : array of string;
        l_entries      : array of array of string;

        l_fileloaded   : boolean;
        l_filename     : string;

        l_unknown1     : ansichar;
        l_unknown2     : ansichar;

        function GetRows() : integer;
        function GetCols() : integer;
        function GetColLabel(i : integer) : string;
        function GetRowLabel(i : integer) : string;
        function GetEntry(r, c : integer) : string;

        procedure SetColLabel(c : integer; sLabel : string);
        procedure SetRowLabel(r : integer; sLabel : string);
        procedure SetEntry(r, c : integer; sValue : string);
    public
        constructor Create();
        destructor Destroy(); override;

        procedure Load2daFile(sFilename : string);
        procedure Save2daFile(sFilename : string);

        function AddLine() : integer;   // Returns index of new line.
        function AddColumn() : integer; // Returns index of new col.
        function CloneLine(iIndex : integer; sNewLabel : string = '') : integer;
        function GetColByLabel(sLabel : string) : integer;
        function GetRowByLabel(sLabel : string) : integer;

        property isloaded : boolean               read l_fileloaded;
        property filename : string                read l_filename;
        property rowcount : integer               read GetRows;
        property colcount : integer               read GetCols;
        property clabels[c : integer] : string    read GetColLabel   write SetColLabel;
        property rlabels[r : integer] : string    read GetRowLabel   write SetRowLabel;
        property entry[r, c : integer] : string   read GetEntry      write SetEntry;
end;


implementation

procedure ClearBuffer(var sBuf : TBuffer);
var
   iIdx : integer;
begin
     for iIdx := Low(sBuf) to High(sBuf) do
         sBuf[iIdx] := #0;
end;

procedure AddStringToBuffer(var sBuf : TBuffer; sText : string);
var
   iSize : integer;
   iIdx  : integer;
begin
     ClearBuffer(sBuf);
     iSize := Length(sText);
     if (iSize > High(sBuf)) then
        iSize := High(sBuf);

     for iIdx := 1 to iSize do
         sBuf[iIdx - 1] := sText[iIdx];
end;


procedure MakeFileWritable(sFilename : string);
var
  nFlags  : Word;
begin
     if (FileExists(sFilename)) then begin
     	nFlags := FileGetAttr(sFilename);
        if ((nFlags and faReadOnly) = faReadOnly) then begin
           nFlags := nFlags and not faReadOnly;
           FileSetAttr(sFilename, nFlags);
        end;
     end;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
constructor T2DAHandler.Create();
begin
     inherited Create();

     l_fileloaded := False;
     l_columns    := 0;
     l_rows       := 0;
     l_unknown1   := #0;
     l_unknown2   := #0;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
destructor T2DAHandler.Destroy();
begin
     l_columnlabels := nil;
     l_rowlabels    := nil;
     l_entries      := nil;

     inherited Destroy();
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure T2DAHandler.Load2daFile(sFilename : string);
var
   inFile     : TFileStream;
   sHeader    : THeader;
   sBuffer    : TBuffer;
   sValue     : string;
   cChar      : ansichar;
   i          : integer;
   iCount     : integer;
   iRows      : DWORD;
   iOffsets   : TOffsets;
   iOffset    : Word;
   iDataOffset: integer;
   r, c       : integer;
begin
     inFile := TFileStream.Create(sFilename, fmOpenRead or fmShareDenyWrite);
     try
        inFile.read(sHeader, sizeof(sHeader));

        if (sHeader = '2DA V2.0') then
           raise EDead.CreateHelp('Specified file was a 2DA file but not in binary format. That format is unhandled at this time. Unable to load.', 1);

        if (sHeader <> '2DA V2.b') then
           raise EDead.CreateHelp('Specified file is not a valid binary 2DA file. Unable to load.', 2);

        // Reset currently loaded data, if any...
        l_filename     := sFilename;
        l_columnlabels := nil;
        l_rowlabels    := nil;
        l_entries      := nil;
        l_columns      := 0;
        l_rows         := 0;
        l_fileloaded   := False;
        l_unknown1   := #0;
        l_unknown2   := #0;

        // Read in the LF following the header to skip past it.
        inFile.read(cChar, sizeof(cChar));

        // Read in the column labels...
        i := 0;
        iCount := 0;
        ClearBuffer(sBuffer);
        repeat
              inFile.read(cChar, sizeof(cChar));

              if (cChar = #9) then begin
                 l_columns := l_columns + 1;
                 SetLength(l_columnlabels, l_columns);
                 l_columnlabels[l_columns-1] := sBuffer;
                 ClearBuffer(sBuffer);
                 i := 0;
              end
              else if (cChar <> #0) then begin
                   sBuffer[i] := cChar;
                   i := i + 1;
              end;

              iCount := iCount + 1; // Failsafe to prevent runaway loops and buffer overflow.
        until ((cChar = #0) or (iCount >= 4095));

        // Above loop didn't terminate due to encountered null terminator. Something went wrong.
        if (iCount >= 4095) then begin
           l_columnlabels := nil;
           l_columns := 0;
           raise EDead.CreateHelp('Malformatted data encountered while reading 2DA! Unable to continue!', 3);
        end;

        // Read the number of rows the file contains.
        inFile.read(iRows, sizeof(iRows));
        l_rows := iRows;

        // Do a crude check for corrupted row count data... no standard 2DA is
        // anywhere near that number of rows, so abort if rowcount is too large.
        if (l_rows > 9999) then begin
           l_columnlabels := nil;
           l_columns := 0;
           l_rows := 0;
           raise EDead.CreateHelp('Sanity check failed, number of 2DA rows reported as unrealistically large! Load aborted.', 4);
        end;

        // Read in the row labels...
        if (l_rows > 0) then begin
           SetLength(l_rowlabels, l_rows);
           iCount := 0;
           i := 0;
           ClearBuffer(sBuffer);
           while (iCount < l_rows) do begin
              inFile.read(cChar, sizeof(cChar));

              if (cChar = #9) then begin
                 l_rowlabels[iCount] := sBuffer;
                 ClearBuffer(sBuffer);
                 i := 0;
                 iCount := iCount + 1;
              end
              else begin
                   sBuffer[i] := cChar;
                   i := i + 1;
              end;
           end;
        end;

        // Read in the table cell offsets
        if ((l_rows > 0) and (l_columns > 0)) then begin
           SetLength(iOffsets, l_rows, l_columns);
           for r:= Low(iOffsets) to High(iOffsets) do begin
               for c := Low(iOffsets[r]) to High(iOffsets[r]) do begin
                   inFile.read(iOffset, sizeof(iOffset));
                   iOffsets[r, c] := iOffset;
               end;
           end;

           // Get the two presumably unused padding bytes...
           inFile.read(l_unknown1, sizeof(l_unknown1));
           inFile.read(l_unknown2, sizeof(l_unknown2));

           // Store the offset of the start of the data area.
           iDataOffset := inFile.Position;

           // Read in and store the string values for each cell.
           SetLength(l_entries, l_rows, l_columns);
           for r:= Low(l_entries) to High(l_entries) do begin
               for c := Low(l_entries[r]) to High(l_entries[r]) do begin

                   // Attempting to read past the end of the file. Abort.
                   if (iDataOffset + iOffsets[r, c] > inFile.size) then begin
                       l_columnlabels := nil;
                       l_rowlabels := nil;
                       l_entries := nil;
                       l_columns := 0;
                       l_rows := 0;
                       raise EDead.CreateHelp('Attempted to read past end of file while reading 2DA cell entry. Aborting...', 5);
                   end;

                   // Move to offset for this cell's string data
                   inFile.Seek(iDataOffset + iOffsets[r, c], soFromBeginning);
                   ClearBuffer(sBuffer);
                   i := 0;

                   // Read in string data until null terminator is encountered.
                   repeat
                         inFile.read(cChar, sizeof(cChar));

                         // Cell entry is too long to fit in buffer. Ouch. Abort.
                         if (i > High(sBuffer)) then begin
                            l_columnlabels := nil;
                            l_rowlabels := nil;
                            l_entries := nil;
                            l_columns := 0;
                            l_rows := 0;
                            raise EDead.CreateHelp('Buffer overflow while reading 2DA cell entry. This is very bad.', 6);
                         end;

                         // Null terminator signifying end of string. Store the buffered data.
                         if (cChar = #0) then begin
                            sValue := sBuffer;

                            if (Length(sValue) > 0) then
                               l_entries[r, c] := sValue
                            else
                               l_entries[r, c] := '****';

                            ClearBuffer(sBuffer);
                            i := 0;
                         end
                         // Store this character at the end of the buffer.
                         else begin
                              sBuffer[i] := cChar;
                              i := i + 1;
                         end;
                   until (cChar = #0) or (inFile.position = inFile.Size);
               end;
           end;
        end;

        // If we get here, the 2DA has hopefully been successfully loaded.
        l_fileloaded   := True;

     finally
        inFile.free();
     end;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure T2DAHandler.Save2daFile(sFilename : string);
var
   outFile    : TFileStream;
   sHeader    : THeader;
   sBuffer    : TBuffer;
   iRowCount  : DWORD;
   iOffset    : WORD;
   iOffsets   : TOffsets;
   iOffsetPos : integer;
   iOffsetData: integer;
   iOffsetTest: integer;
   i          : integer;
   iRow, iCol : integer;
   cChar      : ansichar;

    function GetStringOffset(iRowMax, iColMax: integer) : integer;
    var
       sText  : string;
       r, c   : integer;
    begin
         sText := l_entries[iRowMax, iColMax];
         for r := 0 to iRowMax do begin
             for c := 0 to iColMax do begin
                 // Don't check the current cell since it of course always match,
                 // but doesn't have any offset set yet.
                 if (r = iRowMax) and (c = iColMax) then
                    break;

                    // If matching entry is found, return that offset.
                 if (l_entries[r, c] = sText) then begin
                    result := iOffsets[r, c];
                    exit;
                 end;
             end;
             if (r = iRowMax) and (c = iColMax) then
                break;
         end;

         result := -1;
    end;

begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded that can be saved.', 27);

     if (l_columns < 1) or (l_rows < 1) then
        raise EDead.CreateHelp('The open 2da file is empty. There is no point in saving it.', 28);

     // Remove the ReadOnly flag if the file already exists, before writing.
     if (FileExists(sFilename)) then
        MakeFileWritable(sFilename);

     outFile := TFileStream.Create(sFilename, fmCreate or fmShareDenyWrite);
     try
        // Write the header + LF character
        sHeader := '2DA V2.b';
        outFile.write(sHeader, sizeof(sHeader));
        cChar := #10;
        outFile.write(cChar, sizeof(cChar));

        // Write tab-separated Column labels list
        for i := 0 to (l_columns - 1) do begin
            AddStringToBuffer(sBuffer, l_columnlabels[i]);
            outFile.write(sBuffer, length(l_columnlabels[i]));
            cChar := #9;
            outFile.write(cChar, sizeof(cChar));
        end;

        // Write null-terminator signifying end of column label list.
        cChar := #0;
        outFile.write(cChar, sizeof(cChar));

        // Write the number of rows the 2da file contains.
        iRowCount := l_rows;
        outFile.Write(iRowCount, sizeof(iRowCount));

        // Write the tab-separated row labels list
        for i := 0 to (l_rows - 1) do begin
            AddStringToBuffer(sBuffer, l_rowlabels[i]);
            outFile.write(sBuffer, length(l_rowlabels[i]));
            cChar := #9;
            outFile.write(cChar, sizeof(cChar));
        end;

        // Pad the string offsets section for now so it can be written later.
        iOffsetPos := outFile.position;
        iOffset := 0;
        for iRow := 0 to (l_rows - 1) do begin
            for iCol := 0 to (l_columns - 1) do begin
                outFile.write(iOffset, sizeof(iOffset));
            end;
        end;

        // Write the two presumably unused padding bytes before the text area
        outFile.write(l_unknown1, sizeof(l_unknown1));
        outFile.write(l_unknown2, sizeof(l_unknown2));

        // Write the null-terminated string entries
        iOffsetData := outFile.position;
        SetLength(iOffsets, l_rows, l_columns);
        for iRow := 0 to (l_rows - 1) do begin
            for iCol := 0 to (l_columns - 1) do begin
                 // Check if this string has already been written once.
                 iOffsetTest := GetStringOffset(iRow, iCol);

                 // String not already stored, store it and set offset.
                 if (iOffsetTest = -1) then begin

                     // Store the offset this string will be found at
                     iOffsets[iRow, iCol] := outFile.position;

                     // If it's not the Default value, write it.
                     if (l_entries[iRow, iCol] <> '****') then begin
                        // Add the string to the file
                        AddStringToBuffer(sBuffer, l_entries[iRow, iCol]);
                        outFile.write(sBuffer, length(l_entries[iRow, iCol]));
                     end;

                     // Add null-terminator to set end of string
                     cChar := #0;
                     outFile.write(cChar, sizeof(cChar));
                 end
                 // String already stored before, don't double-store it, just
                 // re-use the old offset.
                 else begin
                      iOffsets[iRow, iCol] := iOffsetTest;
                 end;
            end;
        end;

        // Fill in the string offsets collected above in the padded area
        outFile.seek(iOffsetPos, soFromBeginning);
        for iRow := 0 to (l_rows - 1) do begin
            for iCol := 0 to (l_columns - 1) do begin
                iOffset := iOffsets[iRow, iCol] - iOffsetData;
                outFile.write(iOffset, sizeof(iOffset));
            end;
        end;

     finally
         outFile.free();
     end;

end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.AddLine() : integer;
var
   i : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column labels.', 31);

     // Re-dimension the dynamic arrays to add a new blank line.
     // The data on the row will have to be set manually.
     l_rows := l_rows + 1;
     SetLength(l_rowlabels, l_rows);
     SetLength(l_entries, l_rows, l_columns);

     // Set default row label
     l_rowlabels[l_rows - 1] := IntToStr(l_rows - 1);

     // Initialize all columns in new row to default value.
     for i := 0 to High(l_entries[l_rows - 1]) do
         l_entries[l_rows - 1, i] := '****';

     result := l_rows - 1;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.AddColumn() : integer;
var
   i : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column labels.', 29);

     // Re-dimension the dynamic arrays to add a new blank column.
     // The data on the row will have to be set manually.
     l_columns := l_columns + 1;
     SetLength(l_columnlabels, l_columns);
     SetLength(l_entries, l_rows, l_columns);

     // Set Default column label
     l_columnlabels[l_columns - 1] := 'Column' +  IntToStr(l_columns);

     // Initialize all columns in new row to default value.
     for i := 0 to High(l_entries) do
         l_entries[i, l_columns - 1] := '****';

     result := l_columns - 1;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.CloneLine(iIndex : integer; sNewLabel : string = '') : integer;
var
   iNew, i : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column labels.', 30);

     if ((iIndex >= 0) and (iIndex < l_rows)) then begin
        iNew := AddLine();
        if (sNewLabel <> '') then
           l_rowlabels[iNew] := sNewLabel
        else
           l_rowlabels[iNew] := IntToStr(iNew);

        for i := 0 to High(l_entries[iNew]) do
            l_entries[iNew, i] := l_entries[iIndex, i];

        result := iNew;
     end
     else
         result := -1;
end;

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetColByLabel(sLabel : string) : integer;
var
   i : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column labels.', 7);

     for i := Low(l_columnlabels) to High(l_columnlabels) do begin
         if (lowercase(l_columnlabels[i]) = lowercase(sLabel)) then begin
            result := i;
            exit;
         end;
     end;
     raise EDead.CreateHelp('Unable to find a column matching the label ' + sLabel + ' in ' + l_filename + '!', 8);
     result := -1;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetRowByLabel(sLabel : string) : integer;
var
   i : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column labels.', 9);

     for i := Low(l_rowlabels) to High(l_rowlabels) do begin
         if (lowercase(l_rowlabels[i]) = lowercase(sLabel)) then begin
            result := i;
            exit;
         end;
     end;
     raise EDead.CreateHelp('Unable to find a row matching the label ' + sLabel + '!', 10);
     result := -1;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetRows() : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up row count.', 11);

     result := l_rows;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetCols() : integer;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column count.', 12);

     result := l_columns;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetColLabel(i : integer) : string;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up column label.', 13);

     if ((i >= l_columns) or (i < 0)) then
        raise EDead.CreateHelp('Invalid column index specified, unable to look up column label.', 14);

     result := l_columnlabels[i];
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetRowLabel(i : integer) : string;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up row label.', 15);

     if ((i >= l_rows) or (i < 0)) then
        raise EDead.CreateHelp('Invalid row index specified, unable to look up row label.', 16);

     result := l_rowlabels[i];
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
function T2DAHandler.GetEntry(r, c : integer) : string;
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to look up cell value.', 17);

     if ((r >= l_rows) or (r < 0)) then
        raise EDead.CreateHelp('Invalid row index specified, unable to look up cell value.', 18);

     if ((c >= l_columns) or (c < 0)) then
        raise EDead.CreateHelp('Invalid column index specified, unable to look up cell value.', 19);

     result := l_entries[r, c];
end;

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure T2DAHandler.SetColLabel(c : integer; sLabel : string);
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to set column label.', 20);

     if ((c >= l_columns) or (c < 0)) then
        raise EDead.CreateHelp('Invalid column index specified, unable to set column label.', 21);

     l_columnlabels[c] := sLabel;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure T2DAHandler.SetRowLabel(r : integer; sLabel : string);
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to set row label.', 22);

     if ((r >= l_rows) or (r < 0)) then
        raise EDead.CreateHelp('Invalid row index specified, unable to set row label.', 23);

     l_rowlabels[r] := sLabel;
end;


// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
procedure T2DAHandler.SetEntry(r, c : integer; sValue : string);
begin
     if (l_fileloaded <> True) then
        raise EDead.CreateHelp('No 2da file has been loaded. Unable to set cell value.', 24);

     if ((r >= l_rows) or (r < 0)) then
        raise EDead.CreateHelp('Invalid row index specified, unable to set cell value.', 25);

     if ((c >= l_columns) or (c < 0)) then
        raise EDead.CreateHelp('Invalid column index specified, unable to set cell value.', 26);

     l_entries[r, c] := sValue;
end;


end.

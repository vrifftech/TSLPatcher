unit UStrTok;
// =============================================================================
// TStringTokenizer - A very bare bones String Tokenizer....
// =============================================================================
// Language:      Delphi4
// Last modified: 2005-06-03 (MKB)
// Version:       1.0a
// -----------------------------------------------------------------------------

interface

uses Classes;

type
TStringTokenizer = class(TObject)
    private
        l_strings    : TStringList;
        l_fullstring : string;
        l_delimiter  : Char;
        l_index      : integer;

        function GetString(i : integer) : string;
        function GetCount() : integer;
    public
        function first() : string;
        function next() : string;
        constructor Create(sString : string; sToken : Char);
        destructor Destroy(); override;

        property strings[i : integer] : string    read GetString; default;
        property count                : integer   read GetCount;
        property current              : integer   read l_index;
        property delimiter            : char      read l_delimiter;
        property text                 : string    read l_fullstring;
end;

implementation

constructor TStringTokenizer.Create(sString : string; sToken : Char);
var
    iLast    : integer;
    i        : integer;
    sTemp    : string;

    function GetSubString( sString : string; iStart, iEnd : integer) : string;
    begin
         if (iEnd > iStart) then
             result := copy(sString, iStart, iEnd - iStart)
         else if (iEnd = iStart) then
             result := sString[iStart]
         else
             result := '';
    end;
begin
    inherited Create();

    l_strings    := TStringList.Create();
    l_delimiter  := sToken;
    l_fullstring := sString;
    l_index      := 0;

    // If string contains less than 3 characters it cant possibly be token
    // separated, so just store it as it came.
    if (Length(sString) < 3) then begin
        l_strings.add(sString);
        exit;
    end;

    // Separate string by the token and store in stringlist.
    iLast := 0;
     for i := 1 to Length(sString) do begin
         if (sString[i] = sToken) then begin
             sTemp := GetSubString(sString, iLast + 1, i);
             if (sTemp <> sToken) then
                 l_strings.add(sTemp);
             iLast := i;
         end
         else if ( i = Length(sString) ) then begin
             sTemp := GetSubString(sString, iLast + 1, i + 1 );
             l_strings.add(sTemp);
             iLast := i;
         end;
     end;
end;

destructor TStringTokenizer.Destroy();
begin
    l_strings.free();

    inherited Destroy();
end;

function TStringTokenizer.GetString(i : integer) : string;
begin
    if (i < l_strings.count) then
        result := l_strings[i]
    else
        result := '';
end;


function TStringTokenizer.GetCount() : integer;
begin
    result := l_strings.count;
end;

function TStringTokenizer.first() : string;
begin
    l_index := 0;
    if (l_index < l_strings.count) then
        result := l_strings[l_index]
    else
        result := '';
end;

function TStringTokenizer.next() : string;
begin
    if ((l_index + 1) < l_strings.count) then begin
        inc(l_index);
        result := l_strings[l_index];
    end
    else begin
        result := '';
    end;
end;

end.
 
unit UST_IniFile;

interface

uses Classes, IniFiles, UST_Common;

type
TST_Inifile = class(TIniFile)
    public
        function ReadString(const Section, Ident, Default: string): string; override;
        procedure WriteString(const Section, Ident, Value: String); override;
        procedure ReadSectionValues(const Section: string; Strings: TStrings); override;

        constructor Create(const FileName: string);
        destructor Destroy; override; 
end;

implementation


constructor TST_Inifile.Create(const FileName: string);
begin
    inherited Create(FileName);
end;


destructor TST_Inifile.Destroy();
begin
    inherited Destroy;
end;


function TST_Inifile.ReadString(const Section, Ident, Default: string): string;
var
   sTmp : string;
begin
    sTmp := inherited ReadString(Section, Ident, Default);
    sTmp := ReplaceInString(sTmp, '<#LF#>', Chr(10));
    sTmp := ReplaceInString(sTmp, '<#CR#>', Chr(13));

    result := sTmp;
end;


procedure TST_Inifile.WriteString(const Section, Ident, Value: String);
var
   sTmp : string;
begin
    sTmp := Value;
    sTmp := ReplaceInString(sTmp, Chr(10), '<#LF#>');
    sTmp := ReplaceInString(sTmp, Chr(13), '<#CR#>');

    inherited WriteString(Section, Ident, sTmp);
end;


procedure TST_Inifile.ReadSectionValues(const Section: string; Strings: TStrings);
var
   i : integer;
begin
   inherited ReadSectionValues(Section, Strings);
   Strings.BeginUpdate;
   for i := 0 to (Strings.Count - 1) do begin
       Strings[i] := ReplaceInString(Strings[i], '<#LF#>', Chr(10));
       Strings[i] := ReplaceInString(Strings[i], '<#CR#>', Chr(13));
   end;
   Strings.EndUpdate;
end;


end.
 
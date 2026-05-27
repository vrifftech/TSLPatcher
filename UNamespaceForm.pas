unit UNamespaceForm;
// =============================================================================
// TSLPatcher - GUI Setup Selector Form.
// =============================================================================
// Form allowing the user to pick which setup to use for installing when a
// namespaces.ini file exists in TSLPATCHDATA.
// See top of the UTSLPatcher unit for version and change information....
// -----------------------------------------------------------------------------
// Format example of 'namespaces.ini':
// [Namespaces]
// Namespace1=full
// Namespace2=update
//
// [full]
// IniName=changes.ini
// InfoName=info.rtf
// Name=Full installation
// Description=Installs the full mod. Use this if you have no previous versions.
//
// [update]
// IniName=update.ini
// InfoName=update.rtf
// DataPath=updatefiles  ;relative path below tslpatchdata....
// Name=Update from v1.0
// Description=Use this if you already have version 1 of the Mod installed.
// -----------------------------------------------------------------------------


interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, UST_IniFile;

type
  TNamespaceForm = class(TForm)
    paneBackground: TPanel;
    cbNamespace: TComboBox;
    txtDesc: TMemo;
    lblTitle: TLabel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormShow(Sender: TObject);
    procedure cbNamespaceChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    f_path    : string;
    f_index   : array of string;
    oIni      : TST_IniFile;

    function GetIniName() : string;
    function GetInfoName() : string;
    function GetDataPath() : string;
  public
    { Public declarations }

    property Path     : string      read f_path          write f_path;
    property IniFile  : string      read GetIniName;
    property InfoFile : string      read GetInfoName;
    property DataPath : string      read GetDataPath;
  end;

var
  NamespaceForm: TNamespaceForm;

implementation

{$R *.dfm}


function TNamespaceForm.GetIniName() : string;
var
   sKey : string;
   sSec : string;
   sVal : string;
   sDat : string;
begin
    // If no namespaces.ini exists, just return the default name...
    if (f_index = nil) or not SysUtils.FileExists(f_path + 'namespaces.ini') then begin
        result := 'changes.ini';
        exit;
    end;

    sVal := 'changes.ini';

    // Fetch the ini name from namespaces.ini for the selected namespace.
    sKey := f_index[cbNamespace.ItemIndex];
    sSec := oIni.ReadString('Namespaces', sKey, 'default');
    sVal := oIni.ReadString(sSec, 'IniName', 'changes.ini');
    sDat := oIni.ReadString(sSec, 'DataPath', '');

    // FIX(2006-05-07) Need to add the DataPath part to the check as well,
    // or it won't find INI files located in subfolders!!
    if (sDat <> '') then
        sDat := sDat + '\';

    if SysUtils.FileExists(f_path + sDat + sVal) then
       result := sVal
    else
       result := 'changes.ini';
end;


function TNamespaceForm.GetInfoName() : string;
var
   sKey : string;
   sSec : string;
   sVal : string;
   sDat : string;
begin
    // If no namespaces.ini exists, just return the default name...
    if (f_index = nil) or not SysUtils.FileExists(f_path + 'namespaces.ini') then begin
        result := 'info.rtf';
        exit;
    end;

    sVal := 'info.rtf';

    // Fetch the ini name from namespaces.ini for the selected namespace.
    sKey := f_index[cbNamespace.ItemIndex];
    sSec := oIni.ReadString('Namespaces', sKey, 'default');
    sVal := oIni.ReadString(sSec, 'InfoName', 'info.rtf');
    sDat := oIni.ReadString(sSec, 'DataPath', '');

    // FIX(2006-05-07) Need to add the DataPath part to the check as well,
    // or it won't find INI files located in subfolders!!
    if (sDat <> '') then
        sDat := sDat + '\';


    if SysUtils.FileExists(f_path + sDat + sVal) then
       result := sVal
    else
       result := 'info.rtf';
end;


function TNamespaceForm.GetDataPath() : string;
var
   sKey : string;
   sSec : string;
   sVal : string;
begin
    // If no namespaces.ini exists, just return the default name...
    if (f_index = nil) or not SysUtils.FileExists(f_path + 'namespaces.ini') then begin
        result := f_path;
        exit;
    end;

    sVal := f_path;

    // Fetch the ini name from namespaces.ini for the selected namespace.
    sKey := f_index[cbNamespace.ItemIndex];
    sSec := oIni.ReadString('Namespaces', sKey, 'default');
    sVal := oIni.ReadString(sSec, 'DataPath', '');

    // Don't allow backing out of the TSLPATCHDATA folder, only allow subfolders.
    if (Pos('..\', sVal) > 0) then begin
        result := f_path;
        exit;
    end;

    // Append the relative path from the INI to the tslpatchdata path...
    sVal := f_path + sVal;

    // Make sure the path ends with a backslash....
    if (sVal[Length(sVal)] <> '\') then
       sVal := sVal + '\';

    // Check that the folder actually exists, otherwise use default instead.
    if SysUtils.DirectoryExists(sVal) then
       result := sVal
    else
       result := f_path;
end;


procedure TNamespaceForm.FormShow(Sender: TObject);
var
   oList : TStringList;
   sKey  : string;
   sSec  : string;
   i     : integer;
begin
    // If no namespaces.ini exists, just return the default name...
    if not SysUtils.FileExists(f_path + 'namespaces.ini') then begin
        f_index := nil;
        cbNamespace.ItemIndex := -1;
        cbNamespace.Clear();
        btnOK.Enabled := false;
        exit;
    end;

     btnOK.Enabled := true;

    // Fetch the ini name from namespaces.ini for the selected namespace.
    if (oIni = nil) then
       oIni := TST_IniFile.Create(f_path + 'namespaces.ini');

    oList := TStringList.Create();
    oini.ReadSection('Namespaces', oList);

    // Dimension the Index array after the number of choices available...
    f_index := nil;
    SetLength(f_index, oList.Count);

    // Clear the current content of the ComboBox...
    cbNamespace.Clear();
    txtDesc.Clear();

    // Fill the combobox with new values....
    for i := 0 to (oList.Count - 1) do begin
        sKey := oList.Strings[i];

        // Add key to lookup array. This is matched against the ItemIndex in the combobox.
        f_index[i] := sKey;

        sSec := oIni.ReadString('Namespaces', sKey, 'default');
        if (sSec = 'default') then
            cbNamespace.Items.Add(oIni.ReadString(sSec, 'Name', 'Standard install'))
        else
            cbNamespace.Items.Add(oIni.ReadString(sSec, 'Name', '*no name set*'));
    end;

    if (cbNamespace.Items.Count > 0) then begin
       cbNamespace.ItemIndex := 0;
       cbNamespaceChange(cbNamespace);
    end;

    oList.free();
end;

procedure TNamespaceForm.cbNamespaceChange(Sender: TObject);
var
   sKey : string;
begin
    if (f_index <> nil) and (Length(f_index) > 0) then begin
       sKey := oIni.ReadString('Namespaces', f_index[cbNamespace.ItemIndex], 'default');
       txtDesc.Clear();
       txtDesc.Text := oIni.ReadString(sKey, 'Description', '*no description set*');
    end
    else begin
       txtDesc.Clear();
       txtDesc.Text := 'Standard installation of this Mod.';
    end;
end;

procedure TNamespaceForm.FormDestroy(Sender: TObject);
begin
    if (oIni <> nil) then begin
       oIni.free();
       oIni := nil;
    end;
end;

procedure TNamespaceForm.FormCreate(Sender: TObject);
begin
     oIni := nil;
end;

end.

program TSLPatcher;

uses
  Forms,
  SysUtils,
  UMainForm in 'UMainForm.pas' {MainForm},
  UST_Common in 'UST_Common.pas',
  UGFFFile in 'UGFFFile.pas',
  UERFHandler in 'UERFHandler.pas',
  UTSLPatcher in 'UTSLPatcher.pas',
  UNamespaceForm in 'UNamespaceForm.pas' {NamespaceForm};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'TSLPatcher';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TNamespaceForm, NamespaceForm);
  // -------------------------------------------------------
  MainForm.IniFileName := 'changes.ini';
  MainForm.InfoFileName := 'info.rtf';
  
  if (ParamCount() > 0) then begin
      if (lowercase(copy(ParamStr(1), Length(ParamStr(1)) - 3, 4)) = '.ini') then begin
          MainForm.IniFileName := ParamStr(1);
      end;

      if (ParamCount() > 1)
          and (lowercase(copy(ParamStr(2), Length(ParamStr(2)) - 3, 4)) = '.rtf')
      then begin
          MainForm.InfoFileName := ParamStr(2);
      end;
  end;
  // -------------------------------------------------------

  Application.Run;
end.

unit XPMan;

interface

uses
  Classes;

type
  // OmniPascal resolves this workspace through Free Pascal sources, where the
  // Delphi VCL XPMan unit is unavailable. Keep the editor-only shim outside
  // the project root so real Delphi builds still use the genuine XPMan unit.
  TXPManifest = class(TComponent)
  end;

implementation

initialization
  RegisterClass(TXPManifest);

end.
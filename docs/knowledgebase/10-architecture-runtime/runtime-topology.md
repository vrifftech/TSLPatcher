# Runtime Topology

This layer captures the active startup path, unit boundaries, and runtime data contract that the current executable expects.

## Startup Path

- [REPO] `TSLPatcher.dpr` initializes the VCL application, creates `TMainForm` and `TNamespaceForm`, sets default filenames to `changes.ini` and `info.rtf`, then accepts optional CLI overrides for an alternate `.ini` and `.rtf`.
- [REPO] `TMainForm.FormShow` in `UMainForm.pas` resolves `ExtractFilePath(Application.ExeName) + 'tslpatchdata'`, then checks for `namespaces.ini` before loading the selected INI and info file.
- [REPO] `TMainForm.btnContinueClick` reads install settings, confirmation text, log mode, and log level from the chosen INI, then creates `TTSLPatcher` and calls `RunPatchOperation()`.
- [REPO] `UMainForm.pas` wires `PathCallback` and `ProgressCallback` into `TTSLPatcher`, so install-path updates and progress flow back into the GUI during execution.

## Owning Boundaries

- [REPO] `UMainForm.pas` owns GUI orchestration: startup checks, info-text display, operator confirmation, summary display, and install-log persistence.
- [REPO] `UNamespaceForm.pas` owns namespace selection when `namespaces.ini` exists.
- [REPO] `UTSLPatcher.pas` owns the mutating engine, sequencing, logging, and patch/install lifecycle.
- [REPO] `U2DAEdit.pas`, `UTLKFile.pas`, `UGFFFile.pas`, `UERFHandler.pas`, and `USSFFile.pas` own format-specific parsing and write behavior.
- [REPO] `UST_Common.pas` and `UST_IniFile.pas` own shared Windows helpers, registry access, backup/copy utilities, shell execution helpers, and INI newline-token conversion.

## Runtime Data Contract

- [REPO] The executable expects runtime patch data in a `tslpatchdata` directory beside the built executable.
- [REPO] `UNamespaceForm.pas` reads `IniName`, `InfoName`, `DataPath`, `Name`, and `Description` from `namespaces.ini` sections.
- [REPO] `UNamespaceForm.pas` rejects `..\` in namespace `DataPath`, which constrains namespace data to subdirectories under `tslpatchdata`.
- [REPO] `UST_IniFile.pas` expands `<#LF#>` and `<#CR#>` tokens on read and writes them back on save, so text-backed settings depend on that compatibility layer.

## Operator-Visible Runtime Outputs

- [REPO] `UMainForm.pas` loads info text from the selected RTF file before the user starts patching.
- [REPO] `UMainForm.pas` saves `installlog.rtf` by default and `installlog.txt` when `PlaintextLog=True` and log level is enabled.
- [REPO] `UMainForm.pas` uses the INI `LookupGameFolder` and `LookupGameNumber` settings to populate the status bar from registry-derived install paths before execution starts.

## Conditional Dependency Surface

- [REPO] `UTSLPatcher.pas` contains `CompileList` handling that invokes a compiler helper under `tslpatchdata`.
- [REPO] The source disagrees on the helper filename: one runtime path uses `nwnnsscomp.exe`, while the missing-file message refers to `nwnsscomp.exe`.
- [OPEN] Because the workspace contains no checked-in `tslpatchdata` sample, the exact expected compiler filename and packaging convention remain only partially verified.

## Repo Implications

- [SYNTH] The controlling code path is short and clear up to `RunPatchOperation()`, but once execution enters `UTSLPatcher.pas`, behavior becomes stateful and side-effect-heavy.
- [SYNTH] Namespace selection is a safe seam for configuration branching because it is isolated in `UNamespaceForm.pas` and explicitly constrained to local subpaths.
- [SYNTH] Any change to config semantics should preserve `UST_IniFile.pas` newline-token behavior unless the repo intentionally migrates away from existing INI compatibility.

## Next Actions

- [SYNTH] Before changing startup or install-path behavior, inspect `UMainForm.pas` and `UTSLPatcher.pas` together rather than treating them as independent surfaces.
- [OPEN] Runtime packaging details for `CompileList` should be checked against a real mod package before they are promoted from caveat to hard guidance.

# TSLPatcher

TSLPatcher is a legacy Delphi 7 Windows desktop application for applying mod-driven changes to Star Wars: Knights of the Old Republic and The Sith Lords game data. It reads patch instructions from INI files and updates game assets such as 2DA tables, TLK dialog strings, GFF resources, ERF/RIM archives, and SSF soundsets.

This repository is source-first. The workspace currently includes compiled artifacts such as `TSLPatcher.exe` and `.dcu` files, but the active build entrypoint is `TSLPatcher.dpr`.

## What The App Does

- Starts a VCL GUI application from `TSLPatcher.dpr`.
- Loads `changes.ini` and `info.rtf` by default, with optional CLI overrides for a different `.ini` and `.rtf`.
- Looks for runtime patch data in a `tslpatchdata` folder next to the executable.
- Supports namespace-based multi-configuration installs through `namespaces.ini` when present.
- Runs either patcher mode or installer mode depending on INI settings.
- Writes progress output to an RTF or plaintext install log, depending on configuration.

## Repository Layout

### Core Flow

- `TSLPatcher.dpr`: application entrypoint, form creation, and CLI override handling.
- `UMainForm.pas`: main window, config loading, info text display, user confirmation, progress bar, and summary/report flow.
- `UNamespaceForm.pas`: namespace chooser used when `namespaces.ini` exists.
- `UTSLPatcher.pas`: patch engine, sequencing, logging, and most of the operational behavior.

### Format And Archive Handlers

- `U2DAEdit.pas`: 2DA reader/editor/writer.
- `UTLKFile.pas`: TLK V3.0 reader/writer and append behavior.
- `UGFFFile.pas`: BioWare GFF V3.2 tree-based reader/writer.
- `UERFHandler.pas`: ERF/RIM archive handling.
- `USSFFile.pas`: SSF reader/writer.

### Supporting Units

- `UST_Common.pas`: Windows dialogs, registry helpers, backup/copy helpers, shell output capture, and file utilities.
- `UST_IniFile.pas`: INI wrapper that expands `<#LF#>` and `<#CR#>` newline tokens.
- `UStrTok.pas`: simple string tokenizer used by format helpers.

### Project Artifacts And Legacy Files

- `TSLPatcher.dof`: Delphi project options and embedded version metadata.
- `TSLPatcher.cfg`: compiler options plus old machine-specific output paths. Do not treat those paths as current.
- `UMainForm.dfm` / `UNamespaceForm.dfm`: form resources for the VCL UI.
- `UMainForm.ddp` / `UNamespaceForm.ddp`: Delphi diagram/designer metadata.
- `UGFFHandler.pas` and `UTSLPatcher12.pas`: older legacy source variants not referenced by `TSLPatcher.dpr`.

## Build And Run

### Prerequisites

- Delphi 7 on Windows.
- A runtime `tslpatchdata` folder beside the built executable.

The current repository snapshot does not include a `tslpatchdata/` directory, so a meaningful launch requires supplying that runtime data separately.

### Build

1. Open `TSLPatcher.dpr` in Delphi 7.
2. Review project options from `TSLPatcher.dof` only as IDE metadata, not as authoritative output-path guidance.
3. Compile the project in Delphi 7.

### Launch Behavior

- Default config files: `changes.ini` and `info.rtf`.
- Optional CLI arguments:
  - Argument 1: alternate `.ini`
  - Argument 2: alternate `.rtf`
- Default runtime data location: `tslpatchdata\` under the executable directory.
- Namespace selection appears automatically when `tslpatchdata\namespaces.ini` exists.

## Validation

There is no automated test suite in this repository.

Use the narrowest practical manual check:

1. Compile `TSLPatcher.dpr` in Delphi 7.
2. Launch the app and confirm it can load its INI and info text from the runtime data folder.
3. If `namespaces.ini` exists, confirm the namespace selection flow works.
4. Run one representative patch or install operation and confirm a progress log is written.

## Important Constraints

- This is stateful legacy code. Call order inside `UTSLPatcher.pas` matters.
- Binary and archive handlers are sensitive to offsets and internal layout.
- Install path handling mixes Windows registry lookup with manual folder selection.
- Source comments and project metadata contain historical version information that is not fully synchronized. Treat `TSLPatcher.dpr` and the active units it wires in as the current authority.

## Contributor Docs

- See `CONTRIBUTING.md` for prerequisites, change workflow, and validation expectations.
- See `CONVENTIONS.md` for code organization, Delphi 7 compatibility rules, and high-risk areas.

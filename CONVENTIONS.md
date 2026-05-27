# Conventions

This file captures the coding and repository conventions that are visible in the current source tree.

## Toolchain And Platform

- Target toolchain: Delphi 7.
- Target platform: Windows desktop.
- UI stack: VCL forms.
- Runtime behavior assumes Windows-specific facilities such as registry access and common dialogs.

Do not introduce modern Delphi-only features or platform assumptions that break Delphi 7 or Windows-specific behavior.

## Repository Structure Conventions

- `TSLPatcher.dpr` is the active project entrypoint.
- `UMainForm.pas` and `UNamespaceForm.pas` own UI orchestration.
- `UTSLPatcher.pas` owns patch/install sequencing and logging.
- Format-specific logic is separated into dedicated units:
  - `U2DAEdit.pas`
  - `UTLKFile.pas`
  - `UGFFFile.pas`
  - `UERFHandler.pas`
  - `USSFFile.pas`
- Shared helpers live in `UST_Common.pas`, `UST_IniFile.pas`, and `UStrTok.pas`.

Two root-level units appear to be historical variants rather than active build inputs:

- `UGFFHandler.pas`
- `UTSLPatcher12.pas`

Because they are not referenced by `TSLPatcher.dpr`, do not treat them as the active implementation surface unless you are intentionally comparing old behavior.

## Naming Conventions

- Units use `U` prefixes, for example `UTSLPatcher`, `UMainForm`, `UST_Common`.
- Class names commonly use `T` prefixes and descriptive PascalCase names, for example `TTSLPatcher`, `TMainForm`, `TTLKFileHandler`, and `TERFHandler`.
- Resource strings use `LS_` prefixes.
- Exception types commonly follow the existing local naming style (`EHell`, `EDead`, `EAbort`, `EGFFError`, `EERFError`, `ESSFError`).

Preserve existing naming unless the task specifically calls for a rename.

## Behavioral Conventions

- Installer and patcher modes are configuration-driven rather than separate executables.
- Runtime data defaults to a `tslpatchdata` folder beside the executable.
- Default config filenames are `changes.ini` and `info.rtf`, but the entrypoint accepts alternate `.ini` and `.rtf` arguments.
- Namespace support is optional and driven by `namespaces.ini`.
- Namespace directory selections are expected to stay under `tslpatchdata`; parent-directory traversal is explicitly rejected.
- In installer mode, game path resolution may come from the Windows registry or from a user-selected folder.
- Progress, summaries, and install location updates flow back to the GUI through callbacks and shared logging surfaces.

## Change-Safety Conventions

- Preserve call order in `UTSLPatcher.pas` unless you are intentionally changing sequencing.
- Treat binary/archive readers and writers as high-risk code.
- Keep UI changes inside the form units whenever possible.
- Keep data-format changes inside the corresponding handler units.
- Preserve backup and logging behavior unless the task explicitly changes them.
- Be cautious with file write-protection logic, backup helpers, and archive temp-file behavior.

## INI And Text Handling Conventions

- `UST_IniFile.pas` expands `<#LF#>` and `<#CR#>` tokens when reading/writing INI-backed text.
- If you change configuration semantics, preserve compatibility with that newline-token behavior unless the change explicitly replaces it.

## Project Artifact Conventions

- `.dcu` files are compiled outputs.
- `.dfm` files are form resources that should stay aligned with the matching `.pas` unit.
- `.ddp` files are Delphi designer/diagram metadata.
- `.cfg` and `.dof` store compiler and IDE/project settings; some values are historical and machine-specific.
- `.exe` in the workspace is an artifact, not the source of truth.

## Commenting Conventions

- Existing source uses long historical comment blocks and changelogs in several units.
- New comments should explain intent or non-obvious risk, not restate the syntax.
- When working in risky areas, prefer a small explanatory comment to a silent behavior change.

## Documentation Conventions

- Keep maintainer docs source-backed.
- Prefer repo-relative file references in docs.
- If a behavior is uncertain or historically drifted, document the uncertainty instead of guessing.

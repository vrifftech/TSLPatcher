# AGENTS.md

## Project Scope

- Legacy Delphi 7 Windows desktop app for TSLPatcher.
- Main executable entry point is `TSLPatcher.dpr`.
- Core behavior: read patch instructions from INI files, then patch KotOR/TSL game assets (2DA, TLK, GFF, ERF/RIM, SSF).

## First Files To Read

- `TSLPatcher.dpr`: startup flow, CLI args (`.ini` and `.rtf` override defaults).
- `UMainForm.pas`: GUI orchestration, install flow, summary/progress handling.
- `UTSLPatcher.pas`: main patch engine and operation sequencing.
- `UNamespaceForm.pas`: multi-configuration namespace selector (`namespaces.ini`).

## Module Map

- `UTSLPatcher.pas`: patch/install pipeline and high-level patcher logic.
- `UGFFFile.pas`: BioWare GFF V3.2 reader/writer and field model.
- `UERFHandler.pas`: ERF/RIM archive handling.
- `UTLKFile.pas`: TLK read/write and append operations.
- `U2DAEdit.pas`: 2DA table editing logic.
- `USSFFile.pas`: SSF handling.
- `UST_IniFile.pas`: INI wrapper with newline token conversion (`<#LF#>`, `<#CR#>`).
- `UST_Common.pas`: shared utility functions, dialogs, filesystem helpers, shell output wrapper.

## Build And Run

- Preferred environment: Delphi 7 on Windows.
- Primary project file: `TSLPatcher.dpr`.
- Existing config file: `TSLPatcher.cfg` (contains old machine-specific output paths; do not rely on them as-is).
- Current workspace includes `TSLPatcher.exe`, but treat it as an artifact, not source of truth.

## Validation Expectations

- There is no automated test suite in this repository.
- Validate changes with the narrowest practical check:
  1. Project compiles in Delphi 7.
  2. App launches and reads `tslpatchdata/changes.ini` + `info.rtf` (or CLI overrides).
  3. Namespace flow works when `namespaces.ini` is present.
  4. One representative patch operation completes and writes logs.

## Editing Conventions

- Keep Delphi 7 compatibility (no modern Delphi-only language features).
- Preserve existing unit/class naming and Pascal-style formatting.
- Avoid broad refactors in `UTSLPatcher.pas` unless explicitly requested; behavior is legacy and tightly coupled.
- Keep UI logic in forms (`UMainForm.pas`, `UNamespaceForm.pas`) and data-format logic in dedicated units.
- Do not edit `.dcu`, `.dfm` binaries, or compiled artifacts unless explicitly asked.

## Known Pitfalls

- Many routines are stateful and rely on side effects; changing call order can break patch flow.
- `UTSLPatcher.pas` comments explicitly note minimal original design and accumulated historical changes; prefer surgical edits.
- Archive and binary format handlers (`UGFFFile.pas`, `UERFHandler.pas`) are sensitive to offsets and struct layout.
- Installation path logic mixes Windows registry lookups and user selection; preserve both paths.

## Change Hygiene

- For behavior changes, include a short note in comments near touched logic if intent is non-obvious.
- Keep changes narrowly scoped and avoid unrelated formatting churn.
- If you add new operational docs, link them from this file rather than duplicating details.

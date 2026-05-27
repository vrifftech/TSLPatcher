# Contributing

This repository is a legacy Delphi 7 codebase. Safe changes depend more on understanding the existing sequencing and file-format boundaries than on broad cleanup.

## Prerequisites

- Delphi 7 on Windows.
- Familiarity with VCL form projects and Object Pascal.
- A runtime `tslpatchdata` folder if you need to launch or smoke-test the app.

## Start Here

Before changing behavior, read these files in order:

1. `TSLPatcher.dpr`
2. `UMainForm.pas`
3. `UTSLPatcher.pas`
4. `UNamespaceForm.pas`

Then move to the format/unit surface you actually need:

- `U2DAEdit.pas`
- `UTLKFile.pas`
- `UGFFFile.pas`
- `UERFHandler.pas`
- `USSFFile.pas`
- `UST_Common.pas`
- `UST_IniFile.pas`

## Change Boundaries

Keep edits surgical.

- UI orchestration belongs in `UMainForm.pas` and `UNamespaceForm.pas`.
- Patch/install sequencing belongs in `UTSLPatcher.pas`.
- File-format logic belongs in the dedicated handler units.
- Shared Windows/file/INI helpers belong in `UST_Common.pas` and `UST_IniFile.pas`.

Avoid broad refactors in `UTSLPatcher.pas` unless the task explicitly requires them. The engine is heavily stateful and historical comments in the file itself warn that the design accumulated incrementally.

## High-Risk Areas

- `UTSLPatcher.pas`: sequencing, logging, and install-path behavior are tightly coupled.
- `UGFFFile.pas` and `UERFHandler.pas`: offset and layout sensitivity make unintended breakage easy.
- `UTLKFile.pas`, `U2DAEdit.pas`, and `USSFFile.pas`: serialization changes can corrupt outputs if not validated carefully.
- Install path resolution uses both registry lookup and manual folder selection. Preserve both unless the task explicitly changes them.

## What Not To Rely On

- `TSLPatcher.cfg` contains old machine-specific output paths.
- `TSLPatcher.exe` and `.dcu` files are build artifacts, not source of truth.
- `ReadMe, really.pdf` may contain historical context, but source files and current repo guidance should win when they disagree.
- `UGFFHandler.pas` and `UTSLPatcher12.pas` are not referenced by `TSLPatcher.dpr`; treat them as historical reference files unless you are intentionally working on legacy comparisons.

## Validation Expectations

There is no automated test suite in this repository.

Validate the smallest affected behavior you can:

1. Compile `TSLPatcher.dpr` in Delphi 7.
2. Launch the app.
3. Confirm the expected runtime data loads from `tslpatchdata`.
4. If applicable, exercise namespace selection through `namespaces.ini`.
5. Run one representative patch operation and confirm the install log is written.

For documentation-only changes, use `docs/manual-validation/repository-docs.md` after it exists.

## Editing Guidance

- Preserve Delphi 7 compatibility. Do not introduce modern Delphi-only language features.
- Preserve existing unit and class naming unless the task explicitly requires a rename.
- Avoid unrelated formatting churn.
- Add short intent comments only when behavior is non-obvious.
- Keep changes recoverable. When in doubt, prefer a narrow fix over a sweeping rewrite.

## Designer And Generated Files

- `.dcu` files should not be hand-edited.
- `.dfm` and `.ddp` files should only change when the corresponding UI change actually requires it.
- `.res`, `.ico`, `.cfg`, and `.dof` are project/resource metadata surfaces; handle them deliberately rather than incidentally.

## Documentation Expectations

When adding or updating docs:

- Ground claims in source files or clearly observable repo surfaces.
- Prefer links and short summaries over duplicating large blocks of guidance.
- Call out unknowns instead of guessing hosted workflow or release process details.

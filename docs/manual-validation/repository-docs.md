# Repository Docs Manual Validation

Use this checklist to validate `README.md`, `CONTRIBUTING.md`, and `CONVENTIONS.md` against the current repository.

## Source Of Truth Order

1. `AGENTS.md`
2. `TSLPatcher.dpr`
3. `UMainForm.pas`
4. `UTSLPatcher.pas`
5. `UNamespaceForm.pas`
6. `UST_Common.pas`
7. `UST_IniFile.pas`
8. Format handlers and project metadata files as needed

Do not promote `ReadMe, really.pdf` above the files above unless its claims are independently verified.

## README.md Checks

- Project purpose matches `TSLPatcher.dpr`, `UMainForm.pas`, and the top comment block in `UTSLPatcher.pas`.
- Core module map matches `AGENTS.md` and the actual root file list.
- Runtime defaults mention `changes.ini`, `info.rtf`, and `tslpatchdata` exactly as implemented in `TSLPatcher.dpr` and `UMainForm.pas`.
- CLI override behavior for alternate `.ini` and `.rtf` files matches `TSLPatcher.dpr`.
- Namespace support matches `UNamespaceForm.pas` and `UMainForm.pas`.
- Validation section matches the repository’s manual validation reality.
- README does not claim the repository contains a checked-in `tslpatchdata` directory if it is absent from the root snapshot.
- README links to `CONTRIBUTING.md` and `CONVENTIONS.md`.

## CONTRIBUTING.md Checks

- Required reading list matches the actual active entrypoint, forms, engine, and helper units.
- High-risk area warnings match `AGENTS.md` and the visible source structure.
- Validation steps stay manual and do not invent CI or automated tests.
- “What not to rely on” statements are backed by root files or explicit repo guidance.
- Historical files (`UGFFHandler.pas`, `UTSLPatcher12.pas`) are described as non-active only because they are not referenced by `TSLPatcher.dpr`.
- Install-path cautions still reflect the real dual behavior of registry lookup plus manual folder selection.

## CONVENTIONS.md Checks

- Toolchain and platform claims match the Delphi/VCL/Windows surfaces in the source.
- Naming conventions match actual unit/class/resource-string patterns.
- Structural boundaries match the active project file and unit responsibilities.
- Namespace path constraints match `UNamespaceForm.pas`.
- INI newline-token handling matches `UST_IniFile.pas`.
- Artifact descriptions match the root file inventory and `.gitignore` context.

## Cross-Doc Consistency Checks

- `README.md`, `CONTRIBUTING.md`, and `CONVENTIONS.md` use the same names for the main units.
- The three docs do not contradict each other on build environment, validation flow, or source-of-truth files.
- Cross-links resolve correctly.
- Unknown workflow details are omitted or clearly framed as unknown rather than guessed.

## Final Sign-Off

- Each significant documentation claim can be traced to at least one repo file.
- No section depends on a source file that was not actually checked.
- No doc turns historical comments or IDE metadata into stronger guarantees than the code supports.

# TSLPatcher Architecture

This document describes how the active codebase is structured, which units participate in the live runtime path, how control moves from startup to patch execution, and where each major data format is handled.

## Source Of Truth For The Active Architecture

Use these files to understand the live architecture in order:

1. [TSLPatcher.dpr](TSLPatcher.dpr#L1-L34)
2. [UMainForm.pas](UMainForm.pas#L120-L420)
3. [UTSLPatcher.pas](UTSLPatcher.pas#L444-L487)
4. [UTSLPatcher.pas](UTSLPatcher.pas#L2996-L3161)
5. [UNamespaceForm.pas](UNamespaceForm.pas#L1-L220)
6. [AGENTS.md](AGENTS.md)
7. [CONVENTIONS.md](CONVENTIONS.md)

Historical files and compiled artifacts are useful context, but they do not override the units above.

## High-Level Runtime Shape

The live application has four architectural layers:

1. **Bootstrap layer**: [TSLPatcher.dpr](TSLPatcher.dpr#L1-L34)
2. **GUI orchestration layer**: [UMainForm.pas](UMainForm.pas) and [UNamespaceForm.pas](UNamespaceForm.pas)
3. **Patch engine layer**: [UTSLPatcher.pas](UTSLPatcher.pas)
4. **Format and utility layer**: handler units such as [U2DAEdit.pas](U2DAEdit.pas), [UTLKFile.pas](UTLKFile.pas), [UGFFFile.pas](UGFFFile.pas), [UERFHandler.pas](UERFHandler.pas), [USSFFile.pas](USSFFile.pas), [UST_Common.pas](UST_Common.pas), [UST_IniFile.pas](UST_IniFile.pas), and [UStrTok.pas](UStrTok.pas)

The codebase is not organized as isolated services. It is a stateful desktop application where forms, callbacks, file handlers, and config-driven workflow all cooperate inside one long-running process.

## Entry Point And Application Bootstrap

[TSLPatcher.dpr](TSLPatcher.dpr#L1-L34) performs only a small amount of work, but that work defines the entire runtime shape:

- It initializes the VCL application.
- It creates `TMainForm` and `TNamespaceForm` as application-wide form instances.
- It seeds default filenames for the runtime config and info text.
- It accepts optional CLI replacements for those two filenames.
- It enters `Application.Run`, which hands control to the GUI event loop.

That means the main executable does not perform patching directly. It always routes through the GUI layer first.

## GUI Orchestration Layer

### Main Form Responsibilities

[UMainForm.pas](UMainForm.pas#L120-L209) performs the startup-time orchestration in `FormShow`.

That routine:

1. Resolves the runtime data path as `Application.ExeName` + `tslpatchdata`.
2. Detects whether `namespaces.ini` exists and, if so, hands control to `NamespaceForm`.
3. Validates that the chosen INI file exists.
4. Reads startup settings such as `InstallerMode`, `LookupGameFolder`, and `WindowCaption`.
5. Optionally resolves the target game path from the Windows registry.
6. Loads the RTF info file into the UI.
7. Enables or disables the main action button based on what runtime data is present.

The actual patch/install start happens in [btnContinueClick](UMainForm.pas#L217-L368). That handler:

1. Re-reads the active INI.
2. Loads operational settings such as log level, plaintext-log mode, and confirmation message.
3. Confirms with the operator.
4. Creates the patch engine object `TTSLPatcher`.
5. Connects GUI callbacks for install-path updates and progress updates.
6. Calls `RunPatchOperation` on the engine.
7. Shows completion/error summaries.
8. Saves the install log to disk.

The GUI therefore owns operator interaction, state presentation, and error dialogs, while the engine owns actual patch behavior.

### Namespace Form Responsibilities

[UNamespaceForm.pas](UNamespaceForm.pas#L1-L220) is a small but important specialization layer for multi-configuration installs.

Its responsibilities are:

- load `namespaces.ini`,
- present available install variants,
- translate the chosen variant into:
  - an INI filename,
  - an RTF filename,
  - an optional relative data subfolder.

One of its most important architectural constraints is in [GetDataPath](UNamespaceForm.pas#L127-L160): it rejects `..\` traversal and only allows paths that remain under `tslpatchdata`. That is a runtime boundary, not just a UI convenience.

## Patch Engine Layer

[UTSLPatcher.pas](UTSLPatcher.pas) is the operational core of the application. It owns sequencing, logging, file selection, token processing, backups, archive handling, and format-specific modifications.

### Main Engine Objects

The key architectural roles declared near [UTSLPatcher.pas](UTSLPatcher.pas#L444-L487) are:

- `TTSLPatcher`: main orchestrator
- `TPatchFileHandler`: file discovery, backup, and path-handling support
- format handlers owned or used by the patcher for 2DA, TLK, GFF, SSF, and archive surfaces

### Main Operation Sequence

The core runtime path is [RunPatchOperation](UTSLPatcher.pas#L2996-L3161). This is the function that turns INI instructions into actual game-file changes.

The engine runs in this order:

1. Count target files for progress feedback.
2. Process TLK token data.
3. Copy install-only files.
4. Patch 2DA files.
5. Update GFF files.
6. Apply binary HACK changes.
7. Compile tokenized script files.
8. Update SSF files.
9. Remove temporary ERF patch folder.
10. Summarize warnings/errors.

That order matters. The comments and sequencing inside [RunPatchOperation](UTSLPatcher.pas#L3028-L3131) make clear that the application is intentionally stateful and that some operations were moved specifically to avoid archive or dependency problems.

### What The Engine Actually Controls

The patch engine is responsible for:

- reading INI sections and deciding which operations run,
- loading source or destination files through the file handler,
- applying token replacements and memory lookups,
- coordinating backups,
- routing work into the format-specific handlers,
- logging all significant warnings, errors, and notices.

Because the engine aggregates many behaviors, it is the highest-risk file in the repository for accidental architectural breakage.

## Format Handler Layer

The format handlers are not interchangeable utilities. Each one models a specific game data format.

### 2DA Tables

[U2DAEdit.pas](U2DAEdit.pas) owns the 2DA table format: reading, writing, row/column operations, label lookups, and value access. Inside the patch engine, 2DA changes are routed through helper routines such as row add/change/copy and column add operations during the 2DA loop in [RunPatchOperation](UTSLPatcher.pas#L3039-L3110).

### TLK String Tables

[UTLKFile.pas](UTLKFile.pas) handles dialog string resources. The patch engine uses TLK processing to create or resolve string-reference mappings before later operations depend on them. That is why `ProcessTLKData` runs before the other major patch phases.

### GFF Trees

[UGFFFile.pas](UGFFFile.pas) models BioWare GFF V3.2 files as typed fields, structs, and lists. The patch engine’s GFF phase, entered through [UpdateGffFiles](UTSLPatcher.pas#L2052), relies on that tree model to add fields, locate nested paths, and update values.

### ERF And RIM Archives

[UERFHandler.pas](UERFHandler.pas) handles container archives. This matters because some install or compile operations do not write only to loose override files; they may also route data into archives.

### SSF Soundsets

[USSFFile.pas](USSFFile.pas) handles the fixed-layout SSF soundset format. The patch engine’s SSF phase updates these files after TLK string references have already been assigned.

## Shared Helper Layer

### Windows And File Utilities

[UST_Common.pas](UST_Common.pas) is the repository’s shared Windows/file helper surface. It contains message-box wrappers, safe conversions, file backup and write-protection helpers, directory utilities, registry access, and shell-output capture. This unit is a major architectural bridge between GUI behavior and file-system behavior.

### INI Wrapper

[UST_IniFile.pas](UST_IniFile.pas) wraps Delphi INI handling and expands `<#LF#>` / `<#CR#>` newline tokens. That means configuration text can carry multi-line content in INI files without pretending that plain INI keys are naturally multiline.

### String Tokenizer

[UStrTok.pas](UStrTok.pas) is a small helper used where string splitting is needed, such as path/token parsing in more complex handlers.

## Operator Workflow In Plain Language

From the operator’s point of view, the architecture behaves like this:

1. The executable starts.
2. The main form locates runtime data.
3. If multiple install variants exist, the namespace form asks the operator which one to use.
4. The main form loads explanatory text and destination settings.
5. The operator confirms the run.
6. The patch engine performs a fixed sequence of content updates.
7. The main form reports results and writes an install log.

That workflow is driven by the interaction between [TSLPatcher.dpr](TSLPatcher.dpr#L13-L34), [UMainForm.pas](UMainForm.pas#L138-L209), [UMainForm.pas](UMainForm.pas#L217-L368), and [UTSLPatcher.pas](UTSLPatcher.pas#L2996-L3161).

## Historical And Non-Active Surfaces

Two root-level units are present for historical reference but are not part of the live runtime path:

- [UGFFHandler.pas](UGFFHandler.pas)
- [UTSLPatcher12.pas](UTSLPatcher12.pas)

The safest architectural interpretation is:

- they are useful for understanding code evolution,
- they are not wired into [TSLPatcher.dpr](TSLPatcher.dpr#L3-L9),
- they should not be treated as current behavior unless a task explicitly investigates historical behavior.

Other root-level files such as [TSLPatcher.dof](TSLPatcher.dof), [TSLPatcher.cfg](TSLPatcher.cfg), `.dfm`, `.ddp`, `.res`, `.dcu`, and [TSLPatcher.exe](TSLPatcher.exe) are project metadata, UI resources, build outputs, or artifacts rather than the active architecture itself.

## Architectural Risk Areas

The repository’s own guidance in [AGENTS.md](AGENTS.md#L43-L51) and [CONTRIBUTING.md](CONTRIBUTING.md) is consistent with the code:

- [UTSLPatcher.pas](UTSLPatcher.pas) is tightly stateful and sequencing-sensitive.
- [UGFFFile.pas](UGFFFile.pas) and [UERFHandler.pas](UERFHandler.pas) are structurally sensitive because they read and write binary formats.
- install-path behavior spans registry lookup, UI display, and patch-engine execution.
- UI logic belongs in form units; file-format logic belongs in format handlers.

Those boundaries are not style preferences only. They reflect how the current codebase actually keeps responsibilities separated.

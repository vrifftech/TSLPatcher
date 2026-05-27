# Building And Launching TSLPatcher

This document describes how the repository is built and launched today, what the runtime expects beside the executable, and what the committed VS Code workflow does on Windows versus Linux or macOS.

## Source Of Truth

Use these files in this order when build or launch guidance conflicts:

1. [AGENTS.md](AGENTS.md)
2. [TSLPatcher.dpr](TSLPatcher.dpr#L1-L34)
3. [UMainForm.pas](UMainForm.pas#L120-L264)
4. [UNamespaceForm.pas](UNamespaceForm.pas#L1-L220)
5. [.vscode/tasks.json](.vscode/tasks.json)
6. [.vscode/launch.json](.vscode/launch.json)
7. [README.md](README.md)

`TSLPatcher.exe`, `.dcu` files, and old paths inside [TSLPatcher.cfg](TSLPatcher.cfg) are not the source of truth for how this project should be built.

## What Actually Gets Built

The active Delphi project entrypoint is [TSLPatcher.dpr](TSLPatcher.dpr#L1-L34). It creates the VCL application, instantiates `MainForm` and `NamespaceForm`, sets default config file names to `changes.ini` and `info.rtf`, accepts optional command-line overrides for those two files, and then enters the GUI event loop.

The `uses` list in [TSLPatcher.dpr](TSLPatcher.dpr#L3-L9) tells you which units participate directly in the active build:

- [UMainForm.pas](UMainForm.pas)
- [UST_Common.pas](UST_Common.pas)
- [UGFFFile.pas](UGFFFile.pas)
- [UERFHandler.pas](UERFHandler.pas)
- [UTSLPatcher.pas](UTSLPatcher.pas)
- [UNamespaceForm.pas](UNamespaceForm.pas)

Two similarly named files in the repository root are historical and are not referenced by the active project file:

- [UGFFHandler.pas](UGFFHandler.pas)
- [UTSLPatcher12.pas](UTSLPatcher12.pas)

## Preferred Build Environment

The supported build environment is Windows with Delphi 7, as stated in [AGENTS.md](AGENTS.md#L28-L31) and [README.md](README.md#L52-L58).

The smallest build loop is:

1. Open [TSLPatcher.dpr](TSLPatcher.dpr) in Delphi 7.
2. Treat [TSLPatcher.dof](TSLPatcher.dof) as IDE/project metadata, not as an authority on output paths.
3. Compile the project in Delphi 7.

This repository does not contain an automated test suite, so build validation is manual. The expected validation sequence from [AGENTS.md](AGENTS.md#L33-L39) is:

1. Compile `TSLPatcher.dpr` in Delphi 7.
2. Launch the app with runtime data beside the executable.
3. If `namespaces.ini` exists, verify the namespace selector flow.
4. Run one representative patch/install operation and confirm logs are written.

## Runtime Layout Beside The Executable

The executable expects a `tslpatchdata` folder next to itself. That expectation is encoded in [UMainForm.pas](UMainForm.pas#L138-L140), where the main form derives the runtime data path from `ExtractFilePath(Application.ExeName) + 'tslpatchdata'`.

Inside that runtime data folder, the default startup expects:

- `changes.ini`
- `info.rtf`

Those defaults are set in [TSLPatcher.dpr](TSLPatcher.dpr#L17-L18), then used by [UMainForm.pas](UMainForm.pas#L138-L167) when the GUI starts.

If `tslpatchdata\namespaces.ini` exists, [UMainForm.pas](UMainForm.pas#L142-L152) opens [UNamespaceForm.pas](UNamespaceForm.pas#L165-L219) so the operator can choose a specific install variant. That form can redirect the app to a different INI file, a different RTF file, and a different subfolder under `tslpatchdata`.

The current repository snapshot does not include a checked-in `tslpatchdata/` folder. That means a meaningful launch always requires supplying runtime data separately, even if `TSLPatcher.exe` is present in the workspace.

## Command-Line Overrides

The executable accepts up to two optional command-line arguments, parsed in [TSLPatcher.dpr](TSLPatcher.dpr#L20-L31):

- Argument 1: alternate `.ini` file
- Argument 2: alternate `.rtf` file

The startup code checks the file extensions before replacing the defaults, so these arguments are not arbitrary positional parameters. The form then reads those values through its `IniFileName` and `InfoFileName` properties in [UMainForm.pas](UMainForm.pas#L133-L137) and [UMainForm.pas](UMainForm.pas#L217-L236).

## What The Committed VS Code Tasks Do

The workspace tasks in [.vscode/tasks.json](.vscode/tasks.json) are helpers around the real Delphi 7 workflow. They do not replace Delphi 7.

### Validation Helpers

- `TSLPatcher: Validate repo surface`
  Checks that the active entrypoint and core orchestration units exist.
- `TSLPatcher: Validate Wine availability`
  Checks that the configured Wine launcher exists on non-Windows hosts.
- `TSLPatcher: Validate default runtime data`
  Checks whether `tslpatchdata`, `changes.ini`, and `info.rtf` exist beside the chosen executable.
- `TSLPatcher: Validate default executable launch surface`
  Runs repo-surface and Wine validation before the default launch path.
- `TSLPatcher: Validate override executable launch surface`
  Runs repo-surface and Wine validation before the override launch path.

The default launch preflight intentionally does **not** depend on `Validate default runtime data`. That allows the app itself to start and surface its own missing-data errors instead of failing too early in VS Code.

### Build Helper

`TSLPatcher: Build project (Delphi 7)` only performs a real build on Windows. On Linux and macOS it exits with an explicit message that Delphi 7 compilation is Windows-only. That behavior is intentional and matches the repo’s actual toolchain support.

### Run Helpers

- `TSLPatcher: Run built executable`
- `TSLPatcher: Run built executable with overrides`

On Windows, these run the built executable directly.

On Linux and macOS, they call Wine with the configured executable path and optional CLI override arguments. They do not provide true Delphi-native source debugging; they only provide a practical way to start the Windows executable from the current host.

## What The Committed VS Code Launch Configurations Do

The debug configurations in [.vscode/launch.json](.vscode/launch.json) target the built Windows executable.

- `TSLPatcher: Launch built executable`
- `TSLPatcher: Launch with CLI overrides`

The important details are:

1. The debugger type is `cppdbg`, because this environment does not have a dedicated Delphi debug adapter.
2. On Windows, the `program` is the built `TSLPatcher.exe` path.
3. On Linux and macOS, the configuration swaps the program to `/usr/bin/env` and passes the executable through Wine.
4. The default launch uses `TSLPatcher: Validate default executable launch surface` as its prelaunch check.
5. The override launch uses `TSLPatcher: Validate override executable launch surface` as its prelaunch check.

The compounds `Build then launch default flow` and `Build then launch with overrides` are meaningful primarily on Windows because the build task itself is Windows-only.

## Runtime Errors You Should Expect

If runtime data is missing, the app itself reports that through the GUI. Two important messages are wired in [UMainForm.pas](UMainForm.pas#L65-L68):

- Missing info text file under `tslpatchdata`
- Missing configuration file under `tslpatchdata`

That is why the repo-local workflow lets the executable launch even when `Validate default runtime data` would fail: the application already contains the operator-facing error handling.

## Linux And macOS Reality Check

You can use the committed helpers on Linux or macOS to:

- inspect the repo surface,
- verify Wine,
- launch the built Windows executable through Wine,
- pass alternate `.ini` and `.rtf` arguments.

You cannot use this repository alone to perform a true supported build on Linux or macOS, because the active compiler/toolchain expectation remains Delphi 7 on Windows.

## Practical Build/Launch Checklist

If you are trying to get from source to a meaningful manual validation run, use this order:

1. Confirm the active files in [TSLPatcher.dpr](TSLPatcher.dpr#L3-L9).
2. Build on Windows in Delphi 7.
3. Put a valid `tslpatchdata` folder beside the built executable.
4. Launch normally for `changes.ini` + `info.rtf`, or pass alternate files via CLI.
5. If `namespaces.ini` exists, verify the namespace picker uses the intended subfolder and filenames.
6. Run one representative patch/install and confirm that `installlog.rtf` or `installlog.txt` is written, as handled in [UMainForm.pas](UMainForm.pas#L358-L368).

# Operator Flow

This layer captures the source-derived operator experience exposed by the current VCL forms.

## Observation Boundary

- [OPEN] No live UI session was observed in this workspace. The claims below are derived from `UMainForm.pas`, `UNamespaceForm.pas`, and form resources, not from a running Windows build.

## Current Flow

- [REPO] On startup, `TMainForm.FormShow` resolves the data folder, optionally opens `TNamespaceForm`, and disables the Continue button if either the selected INI or the selected info RTF is missing.
- [REPO] When `LookupGameFolder=True`, `UMainForm.pas` shows the detected install location in the status bar using Windows registry keys for KotOR 1 or KotOR 2; otherwise it marks the destination as user-selected.
- [REPO] `UNamespaceForm.pas` populates the namespace combo box from the `Namespaces` section, shows the selected namespace description, and uses namespace-specific `Name`, `Description`, `IniName`, `InfoName`, and `DataPath` values.
- [REPO] On Continue, `UMainForm.pas` reads `ConfirmMessage`, `InstallerMode`, `LogLevel`, and `PlaintextLog`, shows a confirmation prompt unless the message is `N/A`, then swaps from rich-text info view to plaintext log view when fallback logging is configured.
- [REPO] After execution, `UMainForm.pas` shows different summary dialogs for installer mode and patcher mode and varies the message depending on warning and error counts.
- [REPO] The quit flow is guarded before installation starts and becomes unconditional after the run completes.

## User-Facing Safety Rails

- [REPO] Missing config files and missing info text are surfaced before execution by disabling Continue and showing an alert box.
- [REPO] Namespace `DataPath` cannot back out of `tslpatchdata`, which prevents namespace selection from redirecting operators outside the packaged runtime data folder.
- [REPO] Install logs are written even after aborting errors when log level is enabled, which supports post-failure triage.

## Repo Implications

- [SYNTH] The operator experience is centered on one narrow pre-run setup phase followed by a long stateful engine call. That makes early validation especially valuable because the UI itself does not stage or preview mutations.
- [SYNTH] Source-backed UX claims here should stay conservative until a Windows run validates control sizing, message copy, and summary behavior against the form resources.

## Next Actions

- [SYNTH] Use this flow when evaluating proposed UX changes such as preflight checks, richer summaries, or namespace improvements.
- [OPEN] A future live UI pass should verify the source-derived flow against actual window behavior, especially the namespace dialog and fallback log swap.

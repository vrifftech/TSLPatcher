# Preflight Safety Gate Manual Validation

Use this checklist to validate the installer preflight slice that now runs before any mutating patch stage.

## Preconditions

- Use a build that includes the `RunInstallerPreflight` call in `TTSLPatcher.RunPatchOperation`.
- Run with logging enabled so the install log artifact is written on both success and early abort.
- Use a disposable game install or a scratch copy when validating the happy path.
- Keep one known-good installer configuration and one disposable copy that you can edit for the `Required` scenario.

## Shared Expectations

- Installer-mode runs should log `Running installer preflight checks before applying any changes...` before any patch work starts.
- Successful installer-mode preflight should log `Installer preflight completed. Beginning patch operations.` before TLK, InstallList, 2DA, GFF, NSS, or SSF mutation work begins.
- Failed installer-mode preflight should log `Installer preflight failed before any patch changes were started.` and surface an alert whose message starts with `Preflight failed:`.
- When log level is greater than `0`, the same run should still write `installlog.rtf` or `installlog.txt` on preflight abort.
- Preflight failure must not create the target `override` folder, copy files into the game folder, or write patched outputs.

## Scenario 1: Valid Installer Run

1. Prepare a valid game folder that contains `dialog.tlk` and the expected game subfolders.
2. If the configuration uses `Required`, make sure the required file already exists inside the game folder's `override` directory.
3. Launch the patcher in installer mode with that configuration.
4. Complete any folder-selection prompt if registry lookup is disabled or unavailable.

Expected results:

- The install-path display updates before mutation begins.
- The log shows the preflight start line, then the preflight completion line, then the existing patch-operation logs.
- The run proceeds into the existing mutation flow without changed summary behavior.

## Scenario 2: Invalid Game Folder

1. Launch the same installer-mode configuration.
2. When prompted for the game folder, choose a folder that does not contain `dialog.tlk` and does not look like a game install.

Expected results:

- The run aborts before TLK append, InstallList copy, override creation, or any other mutating stage begins.
- The alert text starts with `Preflight failed:` and still includes the original install-path validation message.
- The log contains the preflight start line, the preflight failed line, and the existing exception log entry.
- No new patch outputs appear in the selected folder.

## Scenario 3: Missing Required Override File

1. Use an installer-mode configuration with `Required=<filename>` set under `[Settings]`.
2. Point the patcher at an otherwise valid game folder.
3. Ensure the required file is absent from that game folder's `override` directory.

Expected results:

- The run aborts during preflight, before any mutating patch stage begins.
- The alert text starts with `Preflight failed:` and shows either `RequiredMsg` or the default missing-required-file message.
- The log shows the preflight start line and the preflight failed line.
- The selected game folder is unchanged apart from any read-only validation access.

## Scenario 4: Non-Installer Mode

1. Use a configuration with installer mode disabled.
2. Launch the patcher and run the same patch flow you used before this change.

Expected results:

- No installer preflight log lines appear.
- File selection and patch sequencing behave the same way they did before this slice.
- The run does not require a game install folder unless the pre-existing non-installer flow already did.

## Sign-Off

- Installer mode now fails fast on invalid install folders and missing `Required` prerequisites.
- Failure output is clearly identifiable as preflight failure in both the alert text and the log.
- Non-installer behavior remains unchanged.

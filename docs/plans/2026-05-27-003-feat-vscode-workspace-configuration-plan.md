---
title: VS Code Workspace Configuration
type: feat
status: completed
date: 2026-05-27
---

# VS Code Workspace Configuration

## Summary

Create a source-matched `.vscode` workspace configuration for this Delphi 7 repository by adding `tasks.json`, `launch.json`, and `settings.json`. The configuration should streamline the real project workflow: prioritize the active entrypoint and core units in the editor, support Windows-oriented Delphi build and run tasks without hardcoding one machine's tool paths, and remain safe and informative when the workspace is opened on Linux where Delphi 7 compilation and native debugging are not available.

---

## Problem Frame

The repository currently has no `.vscode` folder, so there is no shared editor workflow for the active project entrypoint, no repo-specific build or run tasks, and no workspace settings that de-prioritize Delphi build artifacts. Because the codebase is a legacy Delphi 7 Windows application but the current workspace is being edited from Linux, the new configuration needs to be explicit about what is supported on Windows versus what is validation or helper-only on non-Windows hosts.

---

## Assumptions

*This plan was authored without synchronous user confirmation. The items below are agent inferences that fill gaps in the input and should be reviewed during implementation.*

- The workspace configuration should optimize for editing and operating the existing codebase, not for introducing a new Lazarus or Free Pascal toolchain.
- Build and launch tasks should avoid embedding machine-local Delphi install paths and instead use prompts or environment variables where a tool path is required.
- Launch configurations should prefer honest Windows-only process launch flows over pretending that full Delphi 7 source-level debugging is available on Linux.
- The three requested `.vscode` files are the deliverable; extension recommendations and extra docs are optional and should only be added if they materially improve validation.

---

## Requirements

- R1. Create `.vscode/tasks.json` with intuitive repo-specific tasks for preflight checks, Delphi build, and app launch helpers that match the actual `TSLPatcher.dpr` and `TSLPatcher.exe` workflow.
- R2. Create `.vscode/launch.json` with valid VS Code launch configuration structure that reflects the real executable entrypoint and uses platform-specific visibility or behavior for Windows versus Linux/macOS.
- R3. Create `.vscode/settings.json` with workspace settings that improve navigation and signal-to-noise for this codebase, especially around Pascal project files and generated artifacts.
- R4. Use current VS Code schema conventions for `tasks.json` (`version: 2.0.0`), `launch.json` (`version: 0.2.0`), OS-specific sections, `dependsOn`, `dependsOrder`, `preLaunchTask`, variable substitution, and input variables where appropriate.
- R5. Do not hardcode stale paths from `TSLPatcher.cfg` or assume Linux-native Delphi build/debug support.
- R6. Keep the configuration source-backed: task labels, paths, and prompts should be traceable to the real repo structure and documented validation flow.

---

## Scope Boundaries

- No migration to Lazarus, Free Pascal, or another build system.
- No attempt to create a fake automated test workflow where the repo has none.
- No assumption that a Delphi-compatible VS Code debug extension is installed.
- No changes to source code, project files, or compiled artifacts outside `.vscode` unless a small supporting validation file becomes necessary.

### Deferred to Follow-Up Work

- Extension recommendations for Pascal syntax or Delphi tooling if the user later wants a curated `.vscode/extensions.json`.
- More advanced compiler problem matchers if actual `dcc32` output samples are captured and warrant refinement.
- Worktree or multi-root workspace opinions beyond this single-repo setup.

---

## Context & Research

### Relevant Code and Patterns

- `TSLPatcher.dpr` is the active project entrypoint and defines the default `.ini` and `.rtf` override behavior.
- `UMainForm.pas`, `UTSLPatcher.pas`, and `UNamespaceForm.pas` are the primary orchestration surfaces and should be easy to reach from the workspace.
- `AGENTS.md` defines the real build and validation expectations: Delphi 7 on Windows, no automated test suite, and manual runtime validation through `tslpatchdata`.
- `.gitignore` explicitly allows `.vscode/settings.json`, `.vscode/tasks.json`, and `.vscode/launch.json` to be committed while ignoring the rest of `.vscode/`.
- `TSLPatcher.cfg` contains historical machine-specific output paths and must not be copied into workspace automation.

### Institutional Learnings

- No existing `docs/solutions/` or prior indexed learnings were found for VS Code workspace setup in this repository.

### External References

- Current VS Code task documentation confirms `tasks.json` uses `version: "2.0.0"`, supports OS-specific `windows`/`linux`/`osx` sections, `dependsOn`, `dependsOrder`, `presentation`, `problemMatcher`, and `inputs`.
- Current VS Code debug documentation confirms `launch.json` uses `version: "0.2.0"`, supports `preLaunchTask`, platform-specific sections, `presentation.hidden`, variable substitution, and compound configurations.
- Current VS Code variables documentation confirms `${workspaceFolder}`, `${defaultBuildTask}`, `${input:...}`, `${env:...}`, and `${pathSeparator}` / `${/}` behavior, and notes that variable substitution support in `settings.json` is limited.
- Context7 was attempted for VS Code docs but the session hit a monthly quota limit, so implementation should stay conservative where exact extension-specific debugger attributes would otherwise need authoritative lookup.

---

## Key Technical Decisions

- Use dual-host posture: Windows tasks and launch flows for actual build/run work, plus Linux/macOS-safe helper behavior that explains unsupported actions instead of failing mysteriously.
- Use prompt-based or environment-based path inputs for Delphi compiler and executable paths rather than copying stale values from project metadata.
- Model tasks around the repo's real lifecycle: preflight validation, build `TSLPatcher.dpr`, launch default executable, and launch executable with CLI override arguments.
- Keep `launch.json` honest by centering executable launch configurations and hiding Windows-specific configurations on non-Windows platforms when appropriate.
- Use `settings.json` to improve repo navigation by associating Delphi-adjacent files sensibly and filtering compiled artifacts from search/watching, without hiding important source or project metadata.

---

## Open Questions

### Resolved During Planning

- Should this configuration optimize for a Linux-native build loop? No. The codebase and repo guidance are Windows/Delphi 7 oriented.
- Should current VS Code schema features such as input variables and platform-specific sections be used? Yes, because they let the workspace stay portable without baking in one machine's paths.

### Deferred to Implementation

- Whether to include a conservative custom Delphi compiler problem matcher now or leave build tasks with `problemMatcher: []` until real compiler output is captured.
- Whether the launch configurations should assume the C/C++ debugger extension's `cppvsdbg` type is present, or instead provide shell-task-driven launch only.

---

## Implementation Units

### U1. Design The Workspace Task Matrix

**Goal:** Define the exact tasks that match this repo's build, run, and validation reality.

**Requirements:** R1, R4, R5, R6

**Dependencies:** None

**Files:**

- Create: `.vscode/tasks.json`

**Approach:**

- Create a small, high-signal task set instead of generic editor boilerplate.
- Include a preflight task that checks for expected repo/runtime files.
- Add Windows-oriented build and run tasks for `TSLPatcher.dpr` and `TSLPatcher.exe`.
- Use inputs for compiler path, executable path, and optional override arguments where that reduces machine-specific assumptions.
- Use platform-specific task sections so unsupported hosts fail clearly and locally.

**Patterns to follow:**

- Validation flow and project entrypoint from `AGENTS.md` and `TSLPatcher.dpr`.
- VS Code task schema patterns for `dependsOn`, `dependsOrder`, `inputs`, `presentation`, and OS-specific scopes.

**Test scenarios:**

- Happy path: a Windows user can trigger a default build task and a default run helper without editing JSON.
- Edge case: Linux or macOS task execution reports that Delphi build/debug is Windows-specific instead of silently failing from a missing command.
- Integration: preflight tasks are reusable by both build and launch flows.

**Verification:**

- `tasks.json` is valid JSONC for VS Code and every task label maps to a real repo action.

---

### U2. Add Source-Matched Launch Configurations

**Goal:** Create launch configurations that match the actual executable workflow without overstating debug support.

**Requirements:** R2, R4, R5, R6

**Dependencies:** U1

**Files:**

- Create: `.vscode/launch.json`

**Approach:**

- Add launch entries for the default executable and the override-argument executable flow.
- Use `preLaunchTask` to connect launch flows to task-level preflight validation.
- Use platform-specific `presentation.hidden` or platform-specific configuration sections to keep Windows-only entries from cluttering unsupported hosts.
- If a debugger type must be assumed, keep the assumption narrow and explicit.

**Patterns to follow:**

- CLI override behavior from `TSLPatcher.dpr`.
- VS Code launch configuration patterns for `version`, `configurations`, `preLaunchTask`, `inputs`, and platform-specific visibility.

**Test scenarios:**

- Happy path: the workspace exposes a launch target aligned to `TSLPatcher.exe` with default startup behavior.
- Edge case: non-Windows hosts do not advertise a broken primary debug workflow.
- Integration: launch entries reuse task labels and argument inputs consistently with `tasks.json`.

**Verification:**

- `launch.json` opens in VS Code without schema errors and reflects the repo's actual executable flow.

---

### U3. Add Workspace Settings For Delphi Repo Navigation

**Goal:** Improve day-to-day editing signal for this repository through workspace settings.

**Requirements:** R3, R5, R6

**Dependencies:** None

**Files:**

- Create: `.vscode/settings.json`

**Approach:**

- Add file associations for Delphi-adjacent project files where VS Code benefits from explicit mapping.
- Reduce noise from generated artifacts like `.dcu` and built executables in search and file watching.
- Add repo-specific explorer or search behaviors only when they clearly improve navigation of the current tree.
- Keep settings portable; avoid machine-local absolute paths unless VS Code only accepts a path in a setting and a safe variable form is supported.

**Patterns to follow:**

- Source/artifact distinctions from `.gitignore` and `AGENTS.md`.
- VS Code default-settings guidance for workspace overrides.

**Test scenarios:**

- Happy path: Pascal source and project files are easier to navigate and generated artifacts do not dominate search results.
- Edge case: important project metadata such as `.dpr`, `.dof`, and `.cfg` remains visible and editable.
- Integration: settings do not conflict with the files intentionally committed under `.vscode/`.

**Verification:**

- `settings.json` remains portable and focused on repo ergonomics rather than personal editor taste.

---

### U4. Validate The Workspace Configuration Slice

**Goal:** Confirm the new `.vscode` files are internally consistent and honest about the repo's constraints.

**Requirements:** R1, R2, R3, R4, R5, R6

**Dependencies:** U1, U2, U3

**Files:**

- Modify: `.vscode/tasks.json`
- Modify: `.vscode/launch.json`
- Modify: `.vscode/settings.json`

**Approach:**

- Validate JSONC structure and cross-file references such as `preLaunchTask` labels.
- Check that committed `.vscode` files remain compatible with the current `.gitignore` policy.
- Run the narrowest practical validation available in this environment and document any Windows-only checks that cannot run from Linux.

**Patterns to follow:**

- Existing manual-validation posture in `AGENTS.md`.

**Test scenarios:**

- Happy path: task labels referenced by launch configurations exist and use the same names.
- Error path: unsupported host behavior is explicit in task or launch configuration rather than being implied away.
- Integration: the `.vscode` folder contains only the three requested committed files and no ignored spillover.

**Verification:**

- Workspace files are syntactically valid, source-backed, and consistent with each other.

---

## Verification

- Validate `.vscode/tasks.json`, `.vscode/launch.json`, and `.vscode/settings.json` for JSONC correctness and cross-reference consistency.
- Run a narrow workspace diff check after edits.
- If possible in this environment, inspect the created files through the workspace and confirm `.gitignore` still permits the three committed `.vscode` files.
- Document that actual Delphi build and executable launch validation remain Windows-host checks outside this Linux session.

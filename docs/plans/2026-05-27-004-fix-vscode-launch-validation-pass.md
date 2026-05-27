---
title: VS Code Launch Validation Pass
type: fix
status: completed
date: 2026-05-27
---

# VS Code Launch Validation Pass

## Summary

Adjust the shared VS Code workspace flow so the default debug launch no longer fails before the application starts just because the repository snapshot does not include runtime `tslpatchdata`, then run the Linux-available task and launch surface to verify which paths succeed directly and which intentionally report host or runtime prerequisites.

---

## Problem Frame

The current workspace configuration added a helper task that validates default runtime data before the default debug launch. In this repository snapshot, `tslpatchdata/` is intentionally absent, and the application already contains its own runtime error handling for that condition. That means the helper task blocks the debugger too early and produces a less useful failure than the executable itself. The user also asked for an execution pass over the available launch/task surface, so this follow-up slice needs to distinguish between paths that should succeed on Linux, paths that should fail with an explicit prerequisite message, and paths that remain Windows-only by design.

## Requirements

- R1. Default debug launch must not be blocked solely by missing runtime `tslpatchdata` in this repo snapshot.
- R2. Explicit runtime-data validation should remain available as a separate task for users who want to check packaging prerequisites.
- R3. Linux-available prelaunch and helper tasks must emit explicit, useful messages instead of silent shell failures.
- R4. Validate each available task/launch path in the current Linux environment and record which outcomes are expected versus unavailable by design.
- R5. Keep the existing Windows-oriented build posture intact; do not pretend Delphi 7 compilation is Linux-native.

## Scope Boundaries

- No changes to Delphi source units.
- No attempt to fabricate a `tslpatchdata/` sample just to satisfy the workspace helpers.
- No claim that `cppdbg` plus Wine provides full Delphi source debugging parity.
- No change to the override-runtime validation posture unless validation shows a concrete mismatch.

## Context & Research

- `UMainForm.pas` already shows a user-facing alert when `tslpatchdata` or the expected `changes.ini` / `info.rtf` files are missing.
- `README.md` states that the repository snapshot does not include a checked-in `tslpatchdata/` directory, so default runtime-data absence is expected in this workspace.
- `AGENTS.md` treats actual launch and representative patch execution as runtime validation expectations, but they remain environment-dependent rather than automated test suite checks.
- `.vscode/tasks.json` currently contains explicit Linux/macOS helper commands for repo-surface, Wine availability, runtime-data validation, and process launch via Wine.

## Key Technical Decisions

- Remove runtime-data validation from the default launch preflight while keeping it as an explicit standalone task.
- Treat Linux validation as a matrix of expected outcomes rather than forcing every task to succeed: helper checks should pass when prerequisites exist, build should remain Windows-only, and runtime launches may surface application-level missing-data dialogs when `tslpatchdata` is absent.
- Validate launch behavior with the narrowest available checks first: task syntax, helper-task execution, then launch-command execution where feasible.

## Implementation Units

### U1. Fix Default Launch Gating

**Goal:** Stop the default debug launch from failing prematurely on missing runtime data.

**Requirements:** R1, R2, R5

**Files:**

- Modify: `.vscode/tasks.json`

**Approach:**

- Keep `TSLPatcher: Validate default runtime data` intact as an explicit task.
- Remove it from the dependency chain for `TSLPatcher: Validate default executable launch surface`.
- Leave repo-surface and Wine validation in place so missing executable prerequisites still fail before launch.

**Test scenarios:**

- Happy path: default prelaunch validation passes on Linux when repo files and Wine exist.
- Edge case: runtime-data validation still fails explicitly when `tslpatchdata` is absent.
- Integration: default launch no longer stops at prelaunch solely because runtime data is missing.

**Verification:**

- `get_errors` is clean for `.vscode/tasks.json`.
- Running the remaining default prelaunch checks succeeds locally.

### U2. Validate Task And Launch Matrix

**Goal:** Verify the available task and launch surface in the current Linux environment.

**Requirements:** R3, R4, R5

**Files:**

- Modify: `.vscode/tasks.json` (only if validation exposes another local mismatch)
- Modify: `.vscode/launch.json` (only if validation exposes another local mismatch)

**Approach:**

- Run the helper task commands directly to verify messaging and exit behavior.
- Run or emulate the Linux launch/run commands where feasible without claiming unavailable Delphi-native debugging support.
- Treat Windows-only build flow as valid if it fails with the intended host-specific message.

**Test scenarios:**

- Happy path: repo-surface and Wine validation pass.
- Edge case: default runtime-data validation reports the missing `tslpatchdata` path explicitly.
- Error path: Delphi build task reports Windows-host limitation explicitly.
- Integration: default and override run/launch commands resolve to the expected executable and argument paths.

**Verification:**

- `git diff --check -- .vscode/tasks.json .vscode/launch.json`
- Focused command runs for the Linux helper tasks and Linux launch/run commands where possible.
- Clear record of any intentionally unverified paths due GUI/runtime limitations.

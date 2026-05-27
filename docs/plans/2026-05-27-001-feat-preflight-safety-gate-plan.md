---
title: Preflight Safety Gate For Installer Runs
type: feat
status: active
date: 2026-05-27
---

# Preflight Safety Gate For Installer Runs

## Summary

Add a non-mutating preflight pass that resolves the install path and validates required installer prerequisites before any patch mutations begin. The first slice stays narrow: it reuses the existing `dialog.tlk` and `Required` checks already embedded in `TPatchFileHandler.Execute`, surfaces failures as early-abort results, and leaves format writers untouched.

---

## Problem Frame

Current installer validation is distributed across runtime mutation paths, and `RunPatchOperation` even carries a commented reminder that path and requirement checks should be forced up front. That means invalid install folders or missing required override files can be discovered late, after the patcher has already entered operational flow and started logging as if mutation were underway.

---

## Assumptions

*This plan was authored without synchronous user confirmation. The items below are agent inferences that fill gaps in the input — un-validated bets that should be reviewed before implementation proceeds.*

- The requested LFG run should execute the highest-confidence first slice of the top-ranked ideation item in `docs/ideation/2026-05-27-open-ideation.md`, not attempt the entire multi-phase safety-spine program in one pass.
- A preflight-only slice is preferable to serializer-level write hardening for this turn because it uses an existing code seam and is manually verifiable without a Delphi test framework.
- Manual validation documentation is an acceptable first test surface for this repository because no automated test harness exists today.

---

## Requirements

- R1. Installer-mode runs must validate the resolved game install path before any mutating patch operation executes.
- R2. Installer-mode runs must validate the configured `Required` override prerequisite before any mutating patch operation executes.
- R3. Preflight failures must abort cleanly with log and UI messaging that distinguishes preflight failure from mid-run patch failure.
- R4. Non-installer patch mode must preserve existing behavior.
- R5. The first slice must not change binary format save logic in `UTLKFile.pas`, `U2DAEdit.pas`, `UGFFFile.pas`, `UERFHandler.pas`, or `USSFFile.pas`.

---

## Scope Boundaries

- No serializer or archive write hardening in this slice.
- No change to namespace selection behavior.
- No new CLI contract, replay format, or structured log schema in this slice.
- No new automated test framework introduction.

### Deferred to Follow-Up Work

- Format-specific invariant envelopes and staged atomic replacement for TLK/2DA/GFF writers: later safety-spine iteration.
- Replayable execution plans and lockfiles: separate follow-up from the deterministic-execution ideation track.

---

## Context & Research

### Relevant Code and Patterns

- `UMainForm.pas`: `TMainForm.btnContinueClick` is the narrow GUI-to-engine handoff before `TTSLPatcher.RunPatchOperation`.
- `UTSLPatcher.pas`: `TTSLPatcher.RunPatchOperation` contains a commented preflight reminder around forcing `dialog.tlk` path checks early.
- `UTSLPatcher.pas`: `TPatchFileHandler.Execute` already resolves install path, validates `dialog.tlk`, runs the `Required` override-file check, and exits early for the `fileTlk` path before override-folder creation.
- `UTSLPatcher.pas`: `TPatchFileHandler` already reports through `AddLogLine` and the existing `PathCallback`, so the first slice can reuse established reporting surfaces.

### Institutional Learnings

- No stored `docs/solutions/` learnings were found for this workspace.
- Repo guidance in `AGENTS.md` recommends surgical edits, preserving call order in `UTSLPatcher.pas`, and using the narrowest practical validation path.

### External References

- `docs/ideation/2026-05-27-open-ideation.md`: selected source direction is the first narrow slice of the “Safety Spine” idea.

---

## Key Technical Decisions

- Reuse the existing `TPatchFileHandler.Execute('dialog.tlk', fileTlk)` validation path rather than inventing a new install-path resolution mechanism.
- Implement preflight as a dedicated helper called from `RunPatchOperation` before `ProcessTLKData` and `DoInstallFiles`, so the safety contract is owned by the engine rather than the form.
- Treat preflight as non-mutating and installer-only. The helper may resolve install path and emit logs, but it must not create override folders, save files, or start patch operations.
- Surface preflight failures through the existing exception and result/reporting path rather than adding a new UI workflow.

---

## Open Questions

### Resolved During Planning

- Where should the first safety-spine slice live? In `UTSLPatcher.pas`, because the relevant path/requirement checks already exist there and can be forced before mutation.
- Should v1 touch format writers? No. The first slice stops at validation and early abort.

### Deferred to Implementation

- Whether the preflight helper returns a dedicated result record or simply relies on the existing exception-based contract within `RunPatchOperation`.
- Whether a dedicated log string is needed for “preflight started” versus relying on existing path/requirement log lines.

---

## Implementation Units

### U1. Add An Explicit Installer Preflight Helper

**Goal:** Force install-path and `Required` prerequisite validation before any mutating patch steps begin.

**Requirements:** R1, R2, R4, R5

**Dependencies:** None

**Files:**

- Modify: `UTSLPatcher.pas`
- Test: `docs/manual-validation/preflight-safety-gate.md`

**Approach:**

- Extract a dedicated helper in `TTSLPatcher` that runs only when `l_dlgopen.InstallMode` is true.
- Use the existing `TPatchFileHandler.Execute('dialog.tlk', fileTlk)` branch to resolve install path and run the built-in `Required` check.
- Keep the helper read-only with respect to patch outputs: it validates environment and returns, leaving mutation sequencing unchanged for the rest of the run.

**Execution note:** Characterization-first within the touched slice: preserve existing install-path resolution behavior and only move its timing earlier.

**Patterns to follow:**

- `TPatchFileHandler.Execute` for path resolution and prerequisite checks.
- Existing `AddLogLine` and `PathCallback` behavior in `UTSLPatcher.pas`.

**Test scenarios:**

- Happy path: installer mode with a valid game folder and no missing prerequisites completes preflight and continues into the existing patch flow.
- Error path: installer mode with an invalid game folder aborts before `ProcessTLKData` or `DoInstallFiles` execute.
- Error path: installer mode with a missing `Required` override file aborts before any mutation work starts.
- Edge case: non-installer mode bypasses preflight and preserves current execution order.

**Verification:**

- Preflight failures occur before any mutating patch stage begins.
- Successful preflight reuses the resolved install path for the rest of the run.

---

### U2. Wire Early-Abort Reporting Through Existing UI And Log Surfaces

**Goal:** Make preflight failure visible and understandable without creating a new user interaction path.

**Requirements:** R3, R4

**Dependencies:** U1

**Files:**

- Modify: `UTSLPatcher.pas`
- Modify: `UMainForm.pas`
- Test: `docs/manual-validation/preflight-safety-gate.md`

**Approach:**

- Keep failure propagation inside the current `RunPatchOperation` and `btnContinueClick` flow.
- Ensure preflight failures still produce install log output and reach the existing exception/result handling in the form.
- Only add resource strings or log entries if the current output does not clearly distinguish preflight aborts from mid-run failures.

**Patterns to follow:**

- Existing exception handling in `TMainForm.btnContinueClick`.
- Existing `AddLogLine` severity handling in `UTSLPatcher.pas`.

**Test scenarios:**

- Happy path: successful preflight produces either existing or new clear log context and does not change summary messaging.
- Error path: invalid folder preflight shows a clear alert and writes the same style of install log artifact as other early aborts.
- Integration: if preflight resolves the install path via registry or folder picker, the status bar updates through the existing callback before mutation starts.

**Verification:**

- Users can distinguish environment-validation failures from data-mutation failures using the log/UI output.

---

### U3. Add A Manual Validation Checklist For The First Safety Slice

**Goal:** Capture a repeatable validation path for a repo that currently lacks automated tests.

**Requirements:** R1, R2, R3, R4

**Dependencies:** U1, U2

**Files:**

- Create: `docs/manual-validation/preflight-safety-gate.md`

**Approach:**

- Document the smallest repeatable scenarios needed to validate the slice: valid install, invalid folder, missing required override file, non-installer mode.
- Reference the expected log/UI observations and note that no target files should be mutated on preflight failure.

**Patterns to follow:**

- Existing repo validation expectations from `AGENTS.md`.

**Test scenarios:**

- Happy path: valid installer run proceeds past preflight.
- Error path: invalid folder aborts before mutation.
- Error path: missing required override file aborts before mutation.
- Integration: log artifact still saves on preflight abort when log level is enabled.

**Verification:**

- Another maintainer can reproduce the four target scenarios without inferring missing steps.

---

## System-Wide Impact

- **Interaction graph:** touches the form-to-engine boundary and the patch-file helper path resolution flow, but does not alter downstream format handler APIs.
- **Error propagation:** environment-validation exceptions happen earlier in the same exception/logging path already used by install failures.
- **State lifecycle risks:** preflight must not partially initialize mutable patch state in a way that changes subsequent successful runs.
- **API surface parity:** non-installer mode and existing namespace selection remain unchanged.
- **Integration coverage:** install-path resolution through registry lookup and manual folder selection both need manual verification.
- **Unchanged invariants:** once preflight passes, the rest of `RunPatchOperation` should execute in the same order and through the same handlers as today.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Forcing `Execute('dialog.tlk', fileTlk)` earlier changes user-visible timing of folder prompts or status updates | Keep the call installer-only, reuse current callback/log surfaces, and validate both registry and manual folder-selection flows |
| Preflight introduces hidden side effects before mutation | Limit the helper to the existing `fileTlk` validation branch, which exits before override-folder creation and file copying |
| Early-abort logging becomes inconsistent with current install logs | Verify log persistence in `UMainForm.pas` on preflight failure and add only minimal clarifying log strings if needed |

---

## Documentation / Operational Notes

- Capture this slice as the repository’s first explicit manual validation recipe under `docs/manual-validation/`.
- If implementation succeeds, add a short repo learning later describing why the `dialog.tlk` preflight seam was chosen instead of touching serializer code first.

---

## Sources & References

- Ideation source: `docs/ideation/2026-05-27-open-ideation.md`
- Related code: `UMainForm.pas`
- Related code: `UTSLPatcher.pas`
- Project guidance: `AGENTS.md`

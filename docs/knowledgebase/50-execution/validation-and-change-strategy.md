# Validation And Change Strategy

This layer captures the practical execution model for making safe changes in the current repository.

## Validation Ladder

- [REPO] The current repo guidance converges on a narrow manual ladder: compile `TSLPatcher.dpr` in Delphi 7 on Windows, launch with `tslpatchdata`, verify namespace flow when `namespaces.ini` exists, and run one representative patch operation that writes an install log.
- [REPO] `docs/manual-validation/repository-docs.md` adds a focused source-backed checklist for maintainer documentation and keeps doc verification separate from runtime claims.
- [SYNTH] When code changes touch the engine, the smallest decisive check is usually a behavior-scoped Windows manual run, not a broad source read or diff-only inspection.

## Change Strategy

- [REPO] `CONTRIBUTING.md` and `CONVENTIONS.md` place UI orchestration in `UMainForm.pas` and `UNamespaceForm.pas`, engine sequencing in `UTSLPatcher.pas`, and file-format logic in the dedicated handler units.
- [REPO] `AGENTS.md` explicitly warns against broad refactors in `UTSLPatcher.pas` and against incidental edits to `.dcu`, `.dfm`, or compiled artifacts.
- [SYNTH] The safest default is to change the owning abstraction only: forms for UI flow, engine for sequencing, handler units for serialization, and shared helpers for Windows/INI utilities.

## Prefer / Defer / Avoid

- [SYNTH] Prefer preflight, validation, and observability slices that expose problems before mutation starts.
- [SYNTH] Prefer source-backed documentation updates when new behavior is added, especially in high-risk areas such as install-path handling, namespace flow, and binary writers.
- [SYNTH] Defer serializer rewrites, framework migration work, and broad engine cleanup until a narrower safety or validation seam has been landed first.
- [SYNTH] Avoid treating ignored local artifacts (`TSLPatcher.exe`, `.dcu`, `TSLPatcher.cfg`) as authoritative.
- [SYNTH] Avoid widening a change from one owner surface into multiple units unless a focused validation result shows that the controlling behavior lives elsewhere.

## Repo Implications

- [SYNTH] Manual validation is part of the engineering design here, not an afterthought. A change without a plausible Windows/manual check should be treated as only partially validated.
- [SYNTH] Documentation and implementation should stay aligned in the same pass whenever behavior, validation, or runtime prerequisites change.

## Next Actions

- [SYNTH] Use this layer as the default working contract for follow-up feature slices such as the installer preflight gate.
- [OPEN] End-to-end confidence still depends on a Windows environment with Delphi 7 and representative runtime data.

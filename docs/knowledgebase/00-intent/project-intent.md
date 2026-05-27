# Project Intent

This intent layer anchors the current repository truth and points to the deeper runtime, risk, execution, and caveat layers.

## Current System Truth

- [REPO] `TSLPatcher.dpr`, `README.md`, and the header in `UTSLPatcher.pas` all describe the active project as a legacy Delphi 7 Windows desktop patcher for Star Wars: Knights of the Old Republic and The Sith Lords game data.
- [REPO] The shipped runtime contract is local and file-based: `TSLPatcher.dpr` defaults to `changes.ini` and `info.rtf`, and `UMainForm.pas` resolves those under a sibling `tslpatchdata` directory beside the executable.
- [REPO] The active entry surfaces are `TSLPatcher.dpr`, `UMainForm.pas`, `UTSLPatcher.pas`, and `UNamespaceForm.pas`. `UGFFHandler.pas` and `UTSLPatcher12.pas` are present in the workspace but are not wired into `TSLPatcher.dpr`.
- [SYNTH] The repo is a source-first maintenance surface for a stateful installer and patcher, not a generic mod manager, hosted service, or cross-platform application.

## Non-Goals Visible In The Repo

- [REPO] `README.md`, `CONTRIBUTING.md`, `CONVENTIONS.md`, and `AGENTS.md` all keep validation manual and Delphi-7-on-Windows specific; there is no checked-in automated test suite or CI surface.
- [REPO] `.gitignore` excludes `*.exe`, `*.dcu`, and `*.cfg`, which means compiled outputs and compiler-local config are present in this workspace but are not reliable versioned inputs.
- [SYNTH] Broad framework migration, serializer rewrites, and hosted workflow assumptions should be treated as future work unless a plan or implementation slice explicitly takes them on.

## Definition Of Done Signals

- [REPO] The current maintainer docs converge on the same validation ladder: compile `TSLPatcher.dpr` in Delphi 7 on Windows, launch with a real `tslpatchdata` package, verify namespace selection when `namespaces.ini` exists, and complete one representative patch run that writes an install log.
- [REPO] `UMainForm.pas` persists `installlog.rtf` or `installlog.txt` when logging is enabled, which makes log creation part of the observable completion contract.
- [SYNTH] For this codebase, done means preserving runtime startup, config resolution, installer-versus-patcher behavior, and log/report output more than it means structural cleanliness.

## Active Direction

- [REPO] `docs/ideation/2026-05-27-open-ideation.md` ranks a safety-first path highest, and `docs/plans/2026-05-27-001-feat-preflight-safety-gate-plan.md` narrows that direction into an installer preflight slice.
- [SYNTH] The highest-confidence improvement path is to add read-only safety and validation seams before attempting deep engine or format-handler rewrites.

## Knowledgebase Map

- [SYNTH] Read `../10-architecture-runtime/runtime-topology.md` for the controlling code path and runtime data contract.
- [SYNTH] Read `../30-product-ux/operator-flow.md` for the source-derived operator flow through the VCL forms.
- [SYNTH] Read `../40-operational-risk/risk-and-drift.md` for current failure modes, source-runtime drift, and modernization boundaries.
- [SYNTH] Read `../50-execution/validation-and-change-strategy.md` for the working validation ladder and change approach.
- [SYNTH] Read `../90-meta/foundation-boundaries.md` for evidence boundaries and unresolved caveats.

## Repo Implications

- [SYNTH] Prefer source-backed claims over historical artifacts, IDE metadata, or the checked-in executable.
- [SYNTH] Prefer narrow, reversible slices that preserve current call order in `UTSLPatcher.pas`.
- [SYNTH] Defer migration narratives until they are separated from current runtime truth and backed by explicit evidence.

## Next Actions

- [SYNTH] Use the runtime and risk layers before changing `UTSLPatcher.pas`, install-path logic, or any binary handler.
- [OPEN] Live runtime verification still requires Delphi 7 on Windows and a representative `tslpatchdata` package, neither of which is available in this workspace snapshot.

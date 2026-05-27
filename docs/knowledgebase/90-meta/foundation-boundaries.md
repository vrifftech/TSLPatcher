# Foundation Boundaries

This meta layer records what this knowledgebase foundation is grounded on, what it intentionally excludes, and where evidence is still partial.

## Evidence Sources Used

- [REPO] Existing maintainer docs: `README.md`, `CONTRIBUTING.md`, `CONVENTIONS.md`, `AGENTS.md`, `docs/manual-validation/repository-docs.md`, and the active plan and ideation docs under `docs/plans/` and `docs/ideation/`.
- [REPO] Active source anchors: `TSLPatcher.dpr`, `UMainForm.pas`, `UNamespaceForm.pas`, `UTSLPatcher.pas`, and `UST_IniFile.pas`.
- [OFFICIAL] Accessed 2026-05-27: accessible current Free Pascal and Lazarus project documentation relevant to Delphi compatibility and LCL compatibility boundaries.
- [SYNTH] Lower-priority external research was used only to frame migration risk themes and was kept out of current runtime truth unless it aligned with higher-priority evidence.

## Observation Boundaries

- [OPEN] No live Windows compile, launch, or patch run was possible from this Linux workspace.
- [OPEN] No checked-in `tslpatchdata` directory, `changes.ini`, `info.rtf`, or `namespaces.ini` sample was available for runtime-package inspection.
- [OPEN] The Lazarus wiki was not accessible in this environment because of bot protection.
- [OPEN] Git history is not available in a useful form because the repository was newly initialized locally and does not expose a meaningful commit timeline.

## What This Foundation Covers

- [SYNTH] Current repository intent and non-goals.
- [SYNTH] Active startup path, runtime contract, and operator flow.
- [SYNTH] Operational risk, artifact drift, and official-source-backed modernization boundaries.
- [SYNTH] Safe change and validation strategy for future work.

## What This Foundation Defers

- [SYNTH] Exhaustive patch-key or file-format reference material for 2DA, TLK, GFF, ERF/RIM, and SSF internals.
- [SYNTH] End-user packaging, release, or distribution workflow guidance not visible in the repo.
- [SYNTH] A codebase-specific migration plan to Lazarus or Free Pascal.

## Repo Implications

- [SYNTH] New knowledge should extend the layered folders that already exist here instead of accreting into the root docs or into one mega-summary.
- [SYNTH] Any future note that makes runtime claims should say whether it is source-derived, live-observed, or externally documented.

## Next Actions

- [SYNTH] Add deeper architecture or domain notes only when a task needs them, not preemptively.
- [OPEN] Promote caveats to verified guidance only after a Windows/manual validation pass closes the current observation boundary.

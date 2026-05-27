# Risk And Drift

This layer separates current repo risks from future-facing migration guidance so the knowledgebase does not blur runtime truth with modernization speculation.

## Current Runtime Risks

- [REPO] `UTSLPatcher.pas` describes itself as a tool that grew without an original design and warns through its own header comments that the design accumulated incrementally.
- [REPO] `README.md`, `CONTRIBUTING.md`, `CONVENTIONS.md`, and `AGENTS.md` all flag `UTSLPatcher.pas` as sequencing-sensitive and the format handlers as offset- and layout-sensitive.
- [REPO] Install-path resolution mixes registry lookup, user folder selection, required-file checks, backup behavior, and archive handling through the same engine surface.
- [REPO] `UMainForm.pas` passes GUI controls directly into `TTSLPatcher` for logging, which tightens the coupling between the form and the engine.

## Source-Runtime Drift In This Workspace

- [REPO] `.gitignore` excludes `*.exe`, `*.dcu`, and `*.cfg`, but this workspace currently contains `TSLPatcher.exe`, multiple `.dcu` files, and `TSLPatcher.cfg`.
- [SYNTH] Those files are useful local clues, but they are workspace artifacts rather than stable repository guarantees. Treat them as hints, not authority.
- [REPO] `README.md` already notes that `tslpatchdata/` is absent from the snapshot.
- [OPEN] Because the runtime data package is missing, the workspace cannot verify a real install run, namespace package contents, or the exact `CompileList` helper packaging.

## Conditional Dependency Ambiguity

- [REPO] `UTSLPatcher.pas` references a compiler helper for `CompileList` operations.
- [REPO] The source names this helper inconsistently as `nwnnsscomp.exe` in one place and `nwnsscomp.exe` in another.
- [OPEN] This remains unresolved until a representative `tslpatchdata` package or a Windows runtime check confirms which helper name real packages rely on.

## Modernization Boundary

- [OFFICIAL] Accessed 2026-05-27: Free Pascal documents `-Mdelphi` as a Delphi-compatibility mode and describes the compiler as aiming for broad Delphi source-level compatibility, not interchangeable compiled units or binary parity.
- [OFFICIAL] Accessed 2026-05-27: Free Pascal documents record-layout compatibility caveats and explicitly warns that safe Delphi data exchange depends on matching packing/layout assumptions.
- [OFFICIAL] Accessed 2026-05-27: Lazarus documents `LCLIntf` and `LCLType` as Delphi-compatibility layers, but also states they are not exact WinAPI or Delphi-compatible emulations, even on Windows.
- [SYNTH] A future Lazarus/FPC migration would be constrained more by VCL/LCL and WinAPI behavior differences than by Pascal syntax alone.
- [SYNTH] This repo's highest migration-risk surfaces are VCL forms, Windows-specific helpers, message and dialog behavior, and any binary structure assumptions that depend on Delphi defaults.

## Caveat Register

- [OPEN] No live Delphi 7 compile or Windows launch was possible from this Linux workspace.
- [OPEN] The Lazarus wiki was bot-protected during this pass, so only accessible official pages were used for current migration guidance.
- [OPEN] Git history is not informative here because the workspace was newly initialized locally and has no meaningful commit history to mine.

## Repo Implications

- [SYNTH] Prefer reliability work that strengthens current runtime behavior before evaluating framework migration or large refactors.
- [SYNTH] Prefer source-level comparisons over build-artifact comparison because the local executable and DCUs are ignored artifacts.
- [SYNTH] If migration planning starts, begin with UI and Windows-API dependence mapping rather than assuming Delphi mode alone will make the project portable.

## Next Actions

- [SYNTH] Resolve the `CompileList` helper-name ambiguity during the next real runtime packaging check.
- [SYNTH] Keep future migration notes separate from current operational guidance unless they are backed by an approved plan and codebase-specific validation.

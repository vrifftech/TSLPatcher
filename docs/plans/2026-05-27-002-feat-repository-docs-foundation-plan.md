---
title: Repository Documentation Foundation
type: feat
status: completed
date: 2026-05-27
---

## Repository Documentation Foundation

## Summary

Create `README.md`, `CONTRIBUTING.md`, and `CONVENTIONS.md` as the primary maintainer-facing documentation set for this Delphi 7 TSLPatcher repository. The implementation will derive content directly from source-backed repo surfaces, separate verified facts from unresolved gaps, and add a small manual validation checklist so documentation changes can be audited against the codebase.

---

## Problem Frame

The repository currently exposes core project knowledge only through source files and `AGENTS.md`, which makes onboarding, safe contribution, and maintenance reasoning unnecessarily expensive. The requested documentation set needs to be comprehensive enough to orient a new maintainer while staying accurate to the actual codebase and avoiding invented workflow details that are not visible in repo evidence.

---

## Assumptions

*This plan was authored without synchronous user confirmation. The items below are agent inferences that fill gaps in the input — un-validated bets that should be reviewed before implementation proceeds.*

- The new documentation should prioritize maintainers and contributors over end-user mod-install instructions, because the requested files are repository docs and the visible source surfaces are engineering-focused.
- Unknown hosting workflow details such as issue templates, PR labels, or branch policy should be omitted unless directly verified in the repo.
- The existing `ReadMe, really.pdf` file should not be treated as authoritative until its contents are intentionally extracted and reviewed; source files and `AGENTS.md` take priority for this pass.

---

## Requirements

- R1. Create `README.md` that accurately describes project purpose, architecture, build/run expectations, and validation flow from current source-backed evidence.
- R2. Create `CONTRIBUTING.md` that documents prerequisites, safe change boundaries, validation expectations, and contribution workflow details that are actually supported by repo evidence.
- R3. Create `CONVENTIONS.md` that documents code organization, Delphi 7 compatibility rules, naming/style expectations, and high-risk behavior conventions visible in the source tree.
- R4. Each new doc must avoid unsupported claims and explicitly omit or caveat details that are not verifiable from the repository.
- R5. The documentation set must cross-link cleanly so a maintainer can move from repo overview to contribution flow to code conventions without duplicated long-form sections.

---

## Scope Boundaries

- No extraction or transcription of the PDF readme unless it is explicitly validated against current source.
- No GitHub-hosting workflow claims unless `.github` metadata or other repo-backed evidence is found.
- No attempt to document every patch instruction key or binary format in exhaustive reference form in this pass.
- No code changes beyond the requested documentation set and supporting validation docs.

### Deferred to Follow-Up Work

- A deeper format-reference or maintainer handbook built from `UTLKFile.pas`, `UGFFFile.pas`, `UERFHandler.pas`, and `U2DAEdit.pas`: separate documentation iteration if needed.
- End-user packaging or release instructions, if future evidence surfaces for actual distribution workflow.

---

## Context & Research

### Relevant Code and Patterns

- `AGENTS.md` is the current highest-signal maintainer guidance surface and should be preserved through the new docs rather than contradicted.
- `TSLPatcher.dpr` defines startup behavior and CLI override support for `.ini` and `.rtf` inputs.
- `UMainForm.pas` and `UNamespaceForm.pas` define the visible operator flow: config loading, namespace selection, progress reporting, summary reporting, and install-log output.
- `UTSLPatcher.pas` defines the patch engine and the sequencing risks that contributor docs need to call out.
- `UST_IniFile.pas` and `UST_Common.pas` expose config and utility conventions that belong in code conventions documentation.
- `TSLPatcher.cfg` is historical environment context only and should be documented as non-authoritative.

### Institutional Learnings

- No `docs/solutions/` or equivalent institutional learnings were found in the repository.
- Existing guidance in `AGENTS.md` already establishes surgical edits, Delphi 7 compatibility, and manual validation as the operating model.

### External References

- None required for this documentation pass; the requested output is source-grounded repo documentation, not library or framework guidance.

---

## Key Technical Decisions

- Treat source files and `AGENTS.md` as the source of truth; do not elevate the existing PDF into authoritative documentation in this pass.
- Use a layered doc set: `README.md` for orientation, `CONTRIBUTING.md` for workflow and validation, `CONVENTIONS.md` for coding and architectural boundaries.
- Keep unknowns explicit rather than filling gaps with generic open-source boilerplate.
- Add one repo-local manual validation document so the new docs can be checked against the source surfaces that informed them.

---

## Open Questions

### Resolved During Planning

- Should this pass create one mega-doc or layered docs? Layered docs, because the requested filenames already imply different audiences and responsibilities.
- Should external research be used? No; repo-local evidence is sufficient and higher priority for this task.

### Deferred to Implementation

- Whether the README should reference the PDF as historical background or omit it entirely if current evidence does not support it.
- Whether a short “Known Gaps” section belongs in README or CONTRIBUTING after the full source audit is complete.

---

## Implementation Units

### U1. Audit The Source-Backed Documentation Inputs

**Goal:** Build a verified fact set from the repo surfaces that should feed the three requested docs.

**Requirements:** R1, R2, R3, R4

**Dependencies:** None

**Files:**

- Modify: `docs/plans/2026-05-27-002-feat-repository-docs-foundation-plan.md`
- Test: `docs/manual-validation/repository-docs.md`

**Approach:**

- Read the project entrypoint, form units, patch engine, utility/config units, and root project files needed to support documentation claims.
- Capture only claims that are traceable to visible source or repo files.
- Record unresolved gaps that should be omitted or caveated in the docs.

**Patterns to follow:**

- Evidence-first guidance already embodied in `AGENTS.md`.

**Test scenarios:**

- Happy path: every major README/CONTRIBUTING/CONVENTIONS section can be mapped to at least one source-backed repo surface.
- Error path: any claim without supporting evidence is either removed or explicitly marked as unknown/caveated.

**Verification:**

- The implementation has a concrete evidence set before drafting the final docs.

---

### U2. Write README.md As The Repo Overview And Operator Entry Point

**Goal:** Create a source-grounded overview document for maintainers and contributors.

**Requirements:** R1, R4, R5

**Dependencies:** U1

**Files:**

- Create: `README.md`
- Test: `docs/manual-validation/repository-docs.md`

**Approach:**

- Cover project purpose, high-level file map, build/run constraints, runtime inputs, validation expectations, and major risks.
- Keep detailed contribution policy and coding rules out of README, linking to the dedicated docs instead.
- Use concise module descriptions derived from the source tree and existing `AGENTS.md` map.

**Patterns to follow:**

- Existing repo terminology in `AGENTS.md`, `TSLPatcher.dpr`, and the form/engine units.

**Test scenarios:**

- Happy path: a new maintainer can identify what the project does, how it is built, and where to start reading code from README alone.
- Edge case: README does not claim unsupported automation, CI, or hosted workflow details.
- Integration: README links correctly to `CONTRIBUTING.md` and `CONVENTIONS.md` without duplicating full sections.

**Verification:**

- README is accurate, scannable, and traceable to repo evidence.

---

### U3. Write CONTRIBUTING.md For Safe Change Workflow

**Goal:** Document how contributors should approach changes in this repository.

**Requirements:** R2, R4, R5

**Dependencies:** U1

**Files:**

- Create: `CONTRIBUTING.md`
- Test: `docs/manual-validation/repository-docs.md`

**Approach:**

- Document environment prerequisites, surgical-edit expectations, do-not-edit surfaces, and the manual validation ladder already established by repo guidance.
- Include only contribution workflow steps supported by visible repo evidence.
- Link outward to README for project orientation and CONVENTIONS for coding rules.

**Patterns to follow:**

- Validation expectations and editing constraints from `AGENTS.md`.

**Test scenarios:**

- Happy path: a contributor can determine prerequisites, safe edit scope, and expected validation without reading source first.
- Error path: the file does not invent PR or issue workflow details when none are visible in the repo.
- Integration: CONTRIBUTING references the same validation order as README and does not contradict CONVENTIONS.

**Verification:**

- CONTRIBUTING matches repo-backed workflow realities and avoids generic boilerplate.

---

### U4. Write CONVENTIONS.md For Codebase Boundaries And Legacy-Safe Rules

**Goal:** Document the coding and architectural conventions that matter for safe changes.

**Requirements:** R3, R4, R5

**Dependencies:** U1

**Files:**

- Create: `CONVENTIONS.md`
- Test: `docs/manual-validation/repository-docs.md`

**Approach:**

- Describe unit responsibilities, Delphi 7 compatibility rules, naming/style expectations, side-effect and sequencing risks, and format-handler caution areas.
- Keep conventions tied to actual source organization and known pitfalls rather than generic Pascal advice.
- Cross-link to CONTRIBUTING for process and README for overview.

**Patterns to follow:**

- Unit boundaries and known pitfalls in `AGENTS.md`.
- Conventions visible in `UTSLPatcher.pas`, `UMainForm.pas`, `UNamespaceForm.pas`, `UST_Common.pas`, and `UST_IniFile.pas`.

**Test scenarios:**

- Happy path: a maintainer can identify where UI logic belongs, where format logic belongs, and what changes are high risk.
- Edge case: Delphi 7 compatibility and binary-handler sensitivity are called out explicitly.
- Integration: CONVENTIONS uses the same module names and terminology as README.

**Verification:**

- CONVENTIONS reflects actual codebase structure and hazard boundaries.

---

### U5. Add A Manual Validation Checklist For Repository Docs

**Goal:** Provide a repeatable verification path for documentation accuracy in a repo without automated tests.

**Requirements:** R1, R2, R3, R4

**Dependencies:** U2, U3, U4

**Files:**

- Create: `docs/manual-validation/repository-docs.md`

**Approach:**

- Record the source files and checks needed to verify each section of the three docs.
- Include consistency checks for terminology, cross-links, and unsupported-claim removal.

**Patterns to follow:**

- Manual validation posture in `AGENTS.md`.

**Test scenarios:**

- Happy path: each doc section can be checked against one or more repo files listed in the checklist.
- Edge case: missing evidence for a candidate claim is caught during validation rather than silently shipped.
- Integration: cross-links among the three docs resolve correctly.

**Verification:**

- Another maintainer can audit the docs against the repo without reconstructing the reasoning from scratch.

---

## System-Wide Impact

- **Interaction graph:** no runtime behavior changes; impact is on maintainer onboarding, contribution safety, and documentation discoverability.
- **Error propagation:** primary failure mode is documentation drift or unsupported claims, not runtime regressions.
- **State lifecycle risks:** low for code execution, but high for trust if docs overstate build or workflow guarantees.
- **API surface parity:** terminology and behavior descriptions need to stay aligned across entrypoint, UI, and engine docs.
- **Integration coverage:** cross-link integrity and consistency across the three new docs require explicit verification.
- **Unchanged invariants:** the docs pass must not imply new tooling, testing, or release workflows that the repo does not actually have.

---

## Risks & Dependencies

| Risk | Mitigation |
| ------ | ------------ |
| Documentation invents workflow details not supported by the repo | Keep source-backed evidence as the only authority and omit or caveat unknowns |
| README becomes a duplicate of `AGENTS.md` instead of a public-facing maintainer overview | Use README for orientation and link to deeper docs instead of copying full guidance blocks |
| Cross-doc terminology drifts across README, CONTRIBUTING, and CONVENTIONS | Use one evidence pass first, then validate shared terms and links in a dedicated checklist |
| The PDF readme conflicts with current code behavior | Do not rely on the PDF for this pass unless a claim is independently confirmed from source |

---

## Documentation / Operational Notes

- After implementation, consider linking the new docs from `AGENTS.md` so future agent guidance points to the maintainer-facing docs instead of duplicating them.
- If the repo later gains `.github` contribution metadata, revisit CONTRIBUTING to document the hosted workflow explicitly.

---

## Sources & References

- Project guidance: `AGENTS.md`
- Related code: `TSLPatcher.dpr`
- Related code: `UMainForm.pas`
- Related code: `UTSLPatcher.pas`
- Related code: `UNamespaceForm.pas`
- Related code: `UST_Common.pas`
- Related code: `UST_IniFile.pas`

---

## Implementation Delta

- Landed: added a layered `docs/knowledgebase/` foundation covering intent, runtime topology, operator flow, operational risk and drift, execution strategy, and evidence boundaries.
- Partial or uncertain: no Windows/Delphi 7 runtime validation was possible; `tslpatchdata` is absent from the workspace; the `CompileList` helper filename remains ambiguous in source; accessible official migration docs were limited to non-wiki Free Pascal and Lazarus pages.
- Next-step change: prefer Windows/manual validation with a representative runtime package before promoting any runtime caveat to stronger guidance, then extend the knowledgebase only where an implementation slice needs deeper domain detail.

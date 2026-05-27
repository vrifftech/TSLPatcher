---
title: Wiki Codebase Reference
type: feat
status: completed
date: 2026-05-27
---

## Summary

Attach the now-reachable GitHub wiki for `OpenKotOR/TSLPatcher` to this repository as a `wiki/` git submodule and author a structured set of documentation that explains the entire codebase in plain language for non-technical readers while still tracing every substantial behavior back to specific source-file citations. In parallel, maintain the repo-local `BUILDING.md` and `ARCHITECTURE.md` files, and add a markdown rendering of `ReadMe, really.pdf` to the wiki that preserves the original document's structure and wording as closely as possible.

---

## Problem Frame

The repository currently has a concise `README.md`, contributor guidance, and layered local docs, but it does not have a public wiki and it does not yet provide a complete, exhaustive, reader-friendly explanation of what each source file does internally. The user wants a codebase-wide documentation surface that is intuitive for non-technical readers, organized like a proper reference manual, lightly grounded in the README’s structure, and explicit about internal behavior instead of stopping at high-level summaries.

Wiki support is enabled on GitHub and the corresponding `TSLPatcher.wiki.git` remote is now reachable from this environment. That removes the earlier GitHub-side blocker and shifts the work to submodule attachment, wiki page authoring, and PDF-to-markdown transcription.

## Requirements

- R1. Use `gh` CLI to enable the GitHub wiki for `OpenKotOR/TSLPatcher`.
- R2. Create or initialize the wiki git repository and add it to this repository as a submodule rooted at `wiki/`.
- R3. Populate the wiki with comprehensive, organized documentation for the full codebase, including active entrypoints, forms, engine logic, helpers, format handlers, project metadata surfaces, and clearly-labeled historical files.
- R4. Write for non-technical readers without omitting internal behavior; explain what the code does in plain language while preserving exactness.
- R5. Ground claims in source citations rather than paraphrase from memory or from historical PDFs.
- R6. Lightly use `README.md` as the narrative seed, but treat the source tree and current repo guidance as the real authority.
- R7. Organize the wiki so readers can navigate from a top-level overview into per-surface reference pages without facing a single mega-file.
- R8. Create `BUILDING.md` with source-backed build, launch, runtime-data, and VS Code workflow guidance.
- R9. Create `ARCHITECTURE.md` with a source-backed breakdown of the active units, runtime flow, handler layers, helpers, and historical files.
- R10. Add a wiki page that reproduces `ReadMe, really.pdf` in markdown, preserving the original wording and document structure as closely as the source extraction allows.

## Scope Boundaries

- Do not rewrite or simplify the application logic itself.
- Do not treat `ReadMe, really.pdf` as authoritative over source-backed evidence for implementation claims, even though it must be mirrored on the wiki as a historical/manual reference.
- Do not copy the entire codebase verbatim into the wiki when a precise source citation plus exact plain-language explanation conveys the same behavior more clearly.
- Do not claim runtime behavior that has not been verified from source or from the current repo guidance.
- Do not mix wiki content generation with unrelated VS Code workspace changes.

## Context & Research

- [REPO] `README.md` already defines a workable top-level structure: app purpose, core flow, handler surfaces, supporting units, and validation posture.
- [REPO] `CONTRIBUTING.md` and `AGENTS.md` identify the current source-of-truth order and the high-risk modules, which should shape the wiki’s navigation and emphasis.
- [REPO] `gh repo view OpenKotOR/TSLPatcher --json hasWikiEnabled` reports `true`, so wiki support is enabled.
- [REPO] `git ls-remote https://github.com/OpenKotOR/TSLPatcher.wiki.git HEAD` returns a reachable HEAD ref, confirming the wiki remote is now usable.
- [REPO] `ReadMe, really.pdf` exists in the repository root and should be treated as a historical/manual source to mirror on the wiki, not as the authority for source-level behavior.
- [REPO] The root source surface is compact and enumerated: one entrypoint, two active forms, one main engine unit, dedicated file-format handlers, shared helpers, project metadata files, and a small number of historical reference units.

## Key Technical Decisions

- Use a layered wiki structure instead of one massive page: overview, runtime flow, UI flow, engine sequencing, handler references, helper references, project artifacts, historical files, validation/limitations, and a source index.
- Represent “source code as citations” through explicit file-and-line references (and short targeted excerpts only when the prose needs a concrete anchor) rather than dumping full files into the wiki. This keeps the documentation exact, navigable, and maintainable.
- Separate active runtime surfaces from historical files so non-technical readers are not misled about what the current executable actually uses.
- Keep claims evidence-first: cite source for behavior, use local repo docs for validation posture, and mark unresolved areas explicitly.

## Open Questions

### Resolved During Planning

- Does the repository currently have wiki support enabled? Yes.
- Can `gh` authenticate with repo-scoped permissions here? Yes.
- Does the wiki git remote already exist? Yes.

### Deferred To Implementation

- Whether `ReadMe, really.pdf` can be extracted cleanly with local tooling, or whether the markdown mirror will require minor normalization after OCR/text extraction.
- Whether the final wiki index should use a single Home page plus sectional pages only, or also include per-file pages for the most complex units.

## Implementation Units

### U1. Enable And Attach The Wiki Repo

**Goal:** Attach the reachable GitHub wiki repo to the repository as a tracked submodule.

**Requirements:** R1, R2

**Dependencies:** None

**Files:**

- Modify: `.gitmodules`
- Create: `wiki/` (git submodule)

**Approach:**

- Add the wiki repo as a submodule at `wiki/`.
- Verify that the submodule points at the reachable wiki remote.
- Keep the main repo pointer and the wiki repo history in sync as wiki pages are authored.

**Patterns to follow:**

- Existing repository git conventions and non-destructive submodule setup.

**Test scenarios:**

- Happy path: the wiki remote clones and the submodule attaches cleanly.
- Edge case: the wiki remote clones but is empty, so seed content must be committed before the final pointer update is useful.
- Integration: `git submodule status` reports the `wiki/` submodule cleanly.

**Verification:**

- `gh repo view OpenKotOR/TSLPatcher --json hasWikiEnabled`
- `git ls-remote https://github.com/OpenKotOR/TSLPatcher.wiki.git`
- `git submodule status`

### U2. Build The Wiki Information Architecture

**Goal:** Create a navigable wiki structure that covers the full codebase without collapsing into a mega-file.

**Requirements:** R3, R6, R7

**Dependencies:** U1

**Files:**

- Create: `wiki/Home.md`
- Create: `wiki/Codebase-Overview.md`
- Create: `wiki/Runtime-Flow.md`
- Create: `wiki/UI-and-Operator-Flow.md`
- Create: `wiki/Patch-Engine-Reference.md`
- Create: `wiki/File-Format-and-Archive-Handlers.md`
- Create: `wiki/Shared-Helpers-and-INI-Utilities.md`
- Create: `wiki/Project-Artifacts-and-Historical-Files.md`
- Create: `wiki/Validation-Limitations-and-Unknowns.md`
- Create: `wiki/Source-Index.md`
- Create: `wiki/ReadMe-Really.md`

**Approach:**

- Use `README.md` as the top-level narrative seed, then deepen each surface into its own page.
- Give non-technical readers a clear progression from “what this app is” to “what each source surface is responsible for.”
- Reserve the Source Index for file-by-file citation routing so the narrative pages stay readable.
- Add `ReadMe-Really.md` as a clearly-labeled historical/manual page so the original end-user manual is preserved without being confused for current source authority.

**Patterns to follow:**

- Current repo docs in `README.md`, `CONTRIBUTING.md`, and `docs/knowledgebase/`.

**Test scenarios:**

- Happy path: a reader can start at Home and navigate to any major subsystem.
- Edge case: historical files are documented without being confused for active runtime code.
- Edge case: the mirrored PDF/manual page is clearly labeled as a historical/manual reference, not a source-of-truth implementation page.
- Integration: every page links back to Home and to adjacent relevant pages.

**Verification:**

- Internal markdown links resolve within `wiki/`.
- The page set covers every major source surface named in the root file inventory.

### U3. Document The Active Runtime Surfaces Exhaustively

**Goal:** Explain the active codebase internals in exact but plain language, grounded in source citations.

**Requirements:** R3, R4, R5, R6, R10

**Dependencies:** U2

**Files:**

- Modify: `wiki/Codebase-Overview.md`
- Modify: `wiki/Runtime-Flow.md`
- Modify: `wiki/UI-and-Operator-Flow.md`
- Modify: `wiki/Patch-Engine-Reference.md`
- Modify: `wiki/File-Format-and-Archive-Handlers.md`
- Modify: `wiki/Shared-Helpers-and-INI-Utilities.md`
- Modify: `wiki/Source-Index.md`
- Modify: `wiki/ReadMe-Really.md`

**Approach:**

- Read each active source file and document what it does, how it is called, what state it owns, what data it transforms, and what side effects it produces.
- Use file-and-line citations for each substantial claim.
- Translate code behavior into plain-language equivalents suitable for non-technical readers without removing sequencing details, conditions, or limitations.
- Cover at minimum: `TSLPatcher.dpr`, `UMainForm.pas`, `UNamespaceForm.pas`, `UTSLPatcher.pas`, `U2DAEdit.pas`, `UTLKFile.pas`, `UGFFFile.pas`, `UERFHandler.pas`, `USSFFile.pas`, `UST_Common.pas`, `UST_IniFile.pas`, and `UStrTok.pas`.
- Transcribe `ReadMe, really.pdf` into markdown with the original structure and wording preserved as closely as possible, then label it as a manual/reference artifact rather than current implementation authority.

**Patterns to follow:**

- Source-of-truth order from `AGENTS.md` and `docs/manual-validation/repository-docs.md`.

**Test scenarios:**

- Happy path: each active source unit appears in at least one narrative page and in the source index.
- Edge case: modules with stateful or format-sensitive behavior are described with enough precision that their role is not reduced to vague summaries.
- Edge case: the PDF/manual transcription is faithful to the source while still being clearly separated from source-backed implementation pages.
- Integration: cross-references between UI flow, patch engine, and format handlers stay consistent.

**Verification:**

- Manual source-to-doc trace for every active unit.
- `git diff --check` on the new wiki markdown files.

### U4. Document Project Metadata, Historical Files, And Boundaries

**Goal:** Explain the non-active but important repository surfaces and explicitly call out limitations.

**Requirements:** R3, R5, R7

**Dependencies:** U2

**Files:**

- Modify: `wiki/Project-Artifacts-and-Historical-Files.md`
- Modify: `wiki/Validation-Limitations-and-Unknowns.md`
- Modify: `wiki/Source-Index.md`
- Modify: `wiki/ReadMe-Really.md`

**Approach:**

- Document project/resource files such as `.dof`, `.cfg`, `.dfm`, `.ddp`, `.res`, and the compiled artifacts as metadata or generated surfaces rather than source-of-truth logic.
- Clearly distinguish `UGFFHandler.pas` and `UTSLPatcher12.pas` as historical reference files not wired by the active project.
- Record open limitations like absent checked-in runtime `tslpatchdata`, Windows-only Delphi compilation, and any behavior that remains only partially verified from source.
- Place the mirrored `ReadMe, really.pdf` page in this historical/manual layer, with explicit notes that it is preserved for reference and formatting continuity rather than as runtime truth.

**Patterns to follow:**

- Existing cautions in `README.md`, `CONTRIBUTING.md`, and `AGENTS.md`.

**Test scenarios:**

- Happy path: non-technical readers can understand which files matter at runtime versus as project baggage or historical context.
- Edge case: historical files are not misrepresented as dead code if they still provide context.
- Integration: limitations page reflects the same caveats used elsewhere in the wiki.

**Verification:**

- No contradiction with root repo docs on source-of-truth order or historical status.

### U5. Validate, Commit, And Publish The Wiki Slice

**Goal:** Create repo-local documentation that mirrors the most important build and architecture guidance alongside the published wiki reference set.

**Requirements:** R8, R9

**Dependencies:** None

**Files:**

- Create: `BUILDING.md`
- Create: `ARCHITECTURE.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Approach:**

- Use `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CONVENTIONS.md`, `.vscode/tasks.json`, `.vscode/launch.json`, and the active source files as the authoritative inputs.
- Write `BUILDING.md` for operators and maintainers who need exact build/launch behavior, including Windows Delphi expectations and Linux/Wine helper behavior.
- Write `ARCHITECTURE.md` as the local, source-backed system map for the active entrypoint, forms, patch engine, handlers, helpers, and historical files.
- Link these docs from the existing repo guidance so they are discoverable.

**Patterns to follow:**

- Existing root docs tone and the source-of-truth order from `docs/manual-validation/repository-docs.md`.

**Test scenarios:**

- Happy path: both files explain the current repo state without contradicting `README.md` or `AGENTS.md`.
- Edge case: Linux helper-task behavior is described without claiming Linux-native Delphi compilation.
- Integration: new docs are linked from current top-level guidance.

**Verification:**

- `git diff --check -- BUILDING.md ARCHITECTURE.md README.md AGENTS.md`
- Manual doc-to-source trace for the major claims.

### U6. Validate, Commit, And Publish The Wiki Slice

**Goal:** Verify the wiki content and publish both the submodule attachment and wiki content updates.

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R10

**Dependencies:** U1, U2, U3, U4

**Files:**

- Modify: `.gitmodules`
- Modify: `wiki/`

**Approach:**

- Validate markdown structure and local git state for both the main repo and the submodule.
- Commit and push the wiki submodule contents to the wiki remote.
- Commit and push the main repo pointer update so the codebase tracks the wiki snapshot.

**Patterns to follow:**

- Existing repo git hygiene and documentation validation expectations.

**Test scenarios:**

- Happy path: the wiki remote contains the new pages and the main repo submodule points at the correct wiki commit.
- Edge case: submodule pointer exists but wiki content is not yet pushed; fix that before completion.
- Integration: PR diff in the main repo shows `.gitmodules`, the `wiki/` submodule addition, and any supporting docs only.

**Verification:**

- `git diff --check`
- `git submodule status`
- `git -C wiki status`
- `git -C wiki log --oneline -1`

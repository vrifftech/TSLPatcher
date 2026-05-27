---
date: 2026-05-27
topic: open-ideation
focus: surprise-me
mode: repo-grounded
---

# Ideation: TSLPatcher Improvement Directions

Treating this as a topic in this codebase, with open-ended surprise-me exploration.

## Grounding Context

- Legacy Delphi 7 Windows patcher with orchestration concentrated in UTSLPatcher/UMainForm.
- Primary risks: side-effect-heavy execution order and fragile binary offset/serialization logic.
- Current quality gates are manual; no automated test suite exists.
- External prior art indicates strongest long-term patterns are deterministic execution, replayability, governance, and incremental strangler modernization.

## Topic Axes

Decomposition skipped - surprise-me mode

## Ranked Ideas

### 1. Safety Spine: Preflight + Invariant Envelope + Journaled Writes + Dual-Write

**Description:** Build a unified safety layer around all format mutations: dependency preflight, invariant checks before commit, staged temp writes with atomic swap, and optional dual-write semantic comparison during migration windows.
**Basis:** `direct:` binary format handlers are offset-sensitive and side effects are fragile in current flow. `external:` mature migration toolchains de-risk serializer replacement with dual-write compare.
**Rationale:** This directly lowers corruption risk while creating a controlled path for future handler changes.
**Downsides:** Medium-high implementation complexity and careful compatibility tuning needed.
**Confidence:** 92%
**Complexity:** High
**Status:** Unexplored

### 2. Deterministic Execution Substrate: IR + Lockfile + Replay Capsule + Headless CLI

**Description:** Separate plan from apply by compiling INI inputs into a deterministic intermediate representation and lockfile, then executing through a replayable run capsule accessible from both GUI and CLI.
**Basis:** `direct:` current behavior is stateful and difficult to reproduce. `reasoned:` deterministic planning and replay provides strongest compounding foundation for debugging and automation.
**Rationale:** Converts opaque installs into inspectable, repeatable operations and enables future CI-style validation.
**Downsides:** Requires orchestration refactor and schema design discipline.
**Confidence:** 89%
**Complexity:** High
**Status:** Unexplored

### 3. Community Reliability Loop: Scenario Corpus + Crash Repro Bundles + Volunteer Grid

**Description:** Establish a community-contributed regression corpus with expected outputs, auto-generate reproducibility bundles on failure, and optionally run corpus checks on volunteer environments.
**Basis:** `direct:` no automated tests and high support burden. `external:` long-lived mod ecosystems stabilize through reproducibility and distributed validation.
**Rationale:** Delivers practical confidence quickly without waiting for a full modern test harness rewrite.
**Downsides:** Requires triage governance and artifact hygiene to prevent noisy reports.
**Confidence:** 86%
**Complexity:** Medium
**Status:** Unexplored

### 4. Migration Rail: Strangler Sidecar + Offset Firewall + Legacy Frontend/Modern Spec Backend

**Description:** Introduce a sidecar planner and adapter seam so high-level orchestration can modernize while low-level Delphi handlers stay stable initially, then migrate operation families incrementally.
**Basis:** `external:` strangler pattern is proven for high-risk legacy systems. `direct:` current core is tightly coupled but unit boundaries are still usable seams.
**Rationale:** Reduces rewrite risk and enables measurable parity milestones instead of a big-bang replacement.
**Downsides:** Temporary dual-architecture complexity and adapter maintenance overhead.
**Confidence:** 84%
**Complexity:** High
**Status:** Unexplored

### 5. Trust Evidence Stack: Event Recorder + Provenance Ledger + Telemetry Delta View

**Description:** Make every install emit structured operation events, provenance metadata, and expected-vs-actual delta views for operators and bug triage.
**Basis:** `direct:` failures are expensive to diagnose under current manual flow. `reasoned:` evidence-first diagnostics are highest leverage in stateful systems.
**Rationale:** Shrinks time-to-root-cause and raises user trust by making behavior auditable.
**Downsides:** Logging schema/versioning burden and potential verbosity management.
**Confidence:** 82%
**Complexity:** Medium
**Status:** Unexplored

### 6. Contributor Surface: Namespace Contracts + Governance Rules + Explainability Reports

**Description:** Promote namespace definitions and compatibility policies to first-class contributor-facing artifacts, with pre-execution explainability output for users.
**Basis:** `direct:` namespace behavior and config-driven variability are critical paths. `external:` ecosystem tools scale through policy rails and contributor on-ramps.
**Rationale:** Improves maintainability and reduces tacit knowledge bottlenecks.
**Downsides:** Requires social/process adoption, not just code.
**Confidence:** 78%
**Complexity:** Medium
**Status:** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Content fingerprint no-op cache | Valuable later, but depends on deterministic substrate and stronger safety primitives first. |
| 2 | Signed patch packs and capability limits | Security/governance upside, but premature before reliability and reproducibility baseline is established. |
| 3 | Pure analogy framings (watchmaker/conservator only) | Good conceptual lenses, but superseded by concrete implementation-ready survivors above. |
| 4 | Standalone plan mode | Folded into Deterministic Execution Substrate for better compounding value. |
| 5 | Standalone namespace profile idea | Incorporated into Contributor Surface to avoid fragmented rollout. |

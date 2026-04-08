# Plan: Round Contract & Slice Terminology Refactor

## Metadata

| Key | Value |
|-----|-------|
| Name | Round Contract & Slice Terminology Refactor |
| Description | Add `Round Contract` to Baton's control plane, rename Builder-internal `batch` terminology to `slice`, and align live artifacts, docs, tools, and validators to the new task hierarchy (`task -> round -> round contract -> slice`) |
| Started | 2026-04-08 |
| Round | 11 |
| Verifier Mode | C |
| Execution Mode | standard |

## Context

- Round 9 finished the active section-label cleanup and left the active contract on `Metadata`, `Scope Breakdown`, `Round History`, `Human Judgment`, and `Needs your judgment`.
- The remaining naming asymmetry is now role-level: `Planner / Builder / Verifier` are noun-role names, while the router role still used the older label in active prose.
- The desired contract is narrower than a full rename. User-facing command and path stability matter, so `/dispatch`, `dispatch/`, and `name: dispatch` stay unchanged.
- The cleanup target is only the role label in active docs, protocol text, skill docs, templates, validator messaging, and live control-plane summaries.
- Historical snapshots in `.harness/review-round-*.md` stay frozen; they should not be retroactively normalized.

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `README.md` | | role overview must use `Dispatcher` consistently |
| `README.zh-CN.md` | | bilingual role overview must match |
| `v2/CLAUDE.md` | | quick-reference artifact ownership text mentions the router role |
| `v2/protocol.md` | | protocol is the canonical role-definition layer |
| `v2/templates/plan.template.md` | | template notes still mention who asks human questions |
| `v2/skills/dispatch/*` | | the role-local docs must describe the role as `Dispatcher` even though the command is `/dispatch` |
| `v2/skills/planner/*` | | planner docs mention who owns question flow |
| `v2/skills/verifier/*` | | verifier docs mention who consumes routing signals and activates add-ons |
| `v2/skills/builder/SKILL.md` | | builder escalation language references the router role |
| `v2/tools/validate-round-sync.sh` | | user-facing validator output should use the current role name |
| `.harness/plan.md` | | live plan must record the naming decision cleanly |
| `.harness/review.md` | | live review must verify the naming decision cleanly |
| | `/dispatch` command rename | intentionally out of scope; command stability is a constraint, not a target |
| | `dispatch/` directory rename | intentionally out of scope; file-system churn is unnecessary for a prose-level naming cleanup |

### Metrics Baseline

| Metric | Value | Verification command |
|--------|-------|---------------------|
| Remaining active old-router-label hits before Round 10 live-state refresh | 0 | `rg -n '\\bDispatch\\b' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/skills v2/templates v2/tools` |
| Archived review snapshots intentionally left frozen | 9 | `ls .harness/review-round-*.md | wc -l` |

## Scope Breakdown

| # | Feature | Clarity | Round |
|---|---------|---------|-------|
| F1 | Protocol boundary hardening | Complete | 1 |
| F2 | Verifier read-only cleanup | Complete | 1 |
| F3 | Live state validation scripts | Complete | 1 |
| F4 | Public skill modularization | Complete | 2 |
| F5 | Governance / projection sync for moduleized skills | Complete | 2 |
| F6 | Structured control-plane fields (`Open Decisions`, `Routing Signals`) | Complete | 3 |
| F7 | Dispatcher / Planner human-interaction cleanup | Complete | 3 |
| F8 | Historical docs cleanup | Complete | 4 |
| F9 | Lifecycle terminology normalization | Complete | 5 |
| F10 | Active file-name cleanup for modules / tools | Complete | 6 |
| F11 | Remove redundant `module-` prefix from skill-local files | Complete | 7 |
| F12 | Artifact contract rename: `brief/eval` → `plan/review` | Complete | 8 |
| F13 | Active section-label cleanup after the artifact rename | Complete | 9 |
| F14 | Router role-name cleanup to `Dispatcher` in prose | Clear | 10 |

## Round History

### Round 1: Boundary hardening + live validators ✅
- Decisions: fix role-boundary violations before deeper refactors; validate live state as first-class control-plane state
- Open: the router and planner entrypoints remained monolithic and projection layers still lagged the repo structure

### Round 2: Moduleized public skill entrypoints ✅
- Decisions: keep public entrypoints thin and push procedure into role-local files; synchronize governance and projection layers in the same round
- Open: control-plane routing still depended on prose rather than explicit artifact fields

### Round 3: Structured control-plane fields ✅
- Decisions: add `Open Decisions` and `Routing Signals` as the minimum structured control-plane fields; keep Dispatcher as the only human-facing role
- Open: stale historical docs still described removed v1/spec/hook architecture and risked misleading future analysis

### Round 4: Historical docs removed ✅
- Decisions: delete stale analysis docs instead of preserving a knowingly wrong in-repo history layer
- Open: lifecycle branches still mixed old labels with the newer control-plane model

### Round 5: Lifecycle terminology normalized ✅
- Decisions: adopt `Task Recovery`, `Scope Change`, and `Task Closeout` as the canonical lifecycle terms; treat archive as the last step of closeout
- Open: some active file names still described old responsibilities or implementation detail rather than current semantics

### Round 6: Active file names clarified ✅
- Decisions: rename the most misleading active files first without reopening artifact naming wholesale
- Open: the shared `module-` prefix still felt redundant once each file already lived inside a role directory

### Round 7: Role-local files dropped the `module-` prefix ✅
- Decisions: let the directory provide the namespace and let each file name describe only its responsibility
- Open: the live control-plane artifacts still used the older `brief/eval` names

### Round 8: Artifact contract renamed to `plan/review` ✅
- Decisions: adopt `plan.md` and `review.md` as the active control-plane artifacts; rename round history to `review-round-{N}.md`
- Open: some active section labels and companion wording still reflected the older naming layer

### Round 9: Active section labels cleaned up ✅
- Decisions: normalize the active contract around `Metadata`, `Scope Breakdown`, `Round History`, `Human Judgment`, and `Needs your judgment`
- Open: the router role still used the older label in active prose even though the command stayed `/dispatch`

### Round 10: Dispatcher naming cleanup ✅
- Decisions: align the router role name on `Dispatcher` in active prose while preserving `/dispatch`, `dispatch/`, and `name: dispatch`
- Open: Builder-internal `batch` terminology still blurred control-plane and implementation-layer concepts

## Round 11

### Acceptance Criteria

**AC-11.1: Baton defines an explicit round contract**
- Given: `round` is Baton's top-level delivery cycle
- When: this round is complete
- Then: `plan.md`, protocol text, Planner guidance, and Verifier pre-flight all include `§ Round Contract`

**AC-11.2: Builder-internal work is described as slices, not the older internal term**
- Given: Builder delegation is an implementation detail, not the control-plane unit
- When: this round is complete
- Then: Builder skills, templates, helper tooling, and scratch paths use `slice` terminology end-to-end

**AC-11.3: Live artifacts and validators understand the new hierarchy**
- Given: `.harness/plan.md` and `.harness/review.md` are the active control plane
- When: this round is complete
- Then: live artifacts carry `Round Contract` and `Implementation Slices`, and validators enforce the new schema

**AC-11.4: Baton keeps `Round` instead of renaming it to `Sprint`**
- Given: Anthropic's `sprint` is semantically closer to Baton's full round than to a Builder slice
- When: this round is complete
- Then: protocol/docs describe the hierarchy as `task -> round -> round contract -> slice`

### Open Decisions

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-11.1 | None. The naming decision is to keep `Round` and rename Builder-internal `batch` to `slice`. | — | resolved | no |

### Round Contract

| Key | Value |
|-----|-------|
| Scope In | Add `§ Round Contract` to the control plane, rename Builder-internal terminology from `batch` to `slice`, and align docs/tools/live artifacts |
| Scope Out | Renaming `Round` to `Sprint`, changing public role entrypoints, or introducing a new top-level lifecycle unit |
| Done Criteria | Templates, protocol, Builder/Planner/Verifier guides, scratch helper, validators, and live artifacts all use the new hierarchy consistently |
| Verification Plan | Run contract tests, consistency checks, live-state validation, and round-sync validation after the rename |
| Exit Threshold | `check-consistency.sh`, `validate-live-state.sh`, and `validate-round-sync.sh` all pass without compatibility shims |
| Deferred Items | Revisit deeper task-recovery / scope-change semantics only if the new hierarchy exposes gaps |

### Approach

Treat `Round` as the Baton equivalent of Anthropic's higher-level `sprint`, and treat `slice` as the Builder-only implementation unit beneath it. Make `Round Contract` explicit in the task artifact and force Verifier pre-flight to agree or reject that contract before Builder starts. Rename the Builder delegation chain physically, not just in prose, so tooling and scratch state use the same vocabulary as the protocol.

**This round:** formalize `round -> round contract -> slice`
**Not this round:** add compatibility aliases or a new public role

### Implementation Slices

```text
Slice 1: refactor the control plane
  Files: v2/templates/plan.template.md, v2/templates/review.template.md, v2/protocol.md, v2/skills/planner/*, v2/skills/verifier/*
  Check: rg -n 'Round Contract|Implementation Slices|Contract Status' v2/templates v2/protocol.md v2/skills/planner v2/skills/verifier
  Commit: "round-11 slice 1: add round contract"

Slice 2: rename Builder delegation to slice terminology
  Files: v2/skills/builder/*, v2/templates/slice-packet.template.md, v2/templates/worker-report.template.*, v2/tools/builder-slice.sh, .context/baton/README.md
  Check: rg -n 'Slice Packet|slice-|builder-slice|Implementation Slices' v2/skills/builder v2/templates v2/tools .context/baton/README.md
  Commit: "round-11 slice 2: rename builder delegation to slice"

Slice 3: align validators, live artifacts, and projections
  Files: v2/tools/check-consistency.sh, v2/tools/validate-live-state.sh, v2/tests/contracts/*.sh, README.md, README.zh-CN.md, CLAUDE.md, v2/CLAUDE.md, project-profile.md, .harness/*
  Check: bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-11 slice 3: align live state to round contract"
```

### AC → Test Mapping

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-11.1 | `rg -n 'Round Contract|Contract Status' v2/templates v2/protocol.md v2/skills/planner v2/skills/verifier` | ✅ |
| AC-11.2 | `rg -n 'Slice Packet|slice-|builder-slice|Implementation Slices' v2/skills/builder v2/templates v2/tools .context/baton/README.md` | ✅ |
| AC-11.3 | `bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh` | ✅ |
| AC-11.4 | `rg -n 'sprint|Sprint' v2 README.md README.zh-CN.md CLAUDE.md v2/CLAUDE.md project-profile.md .harness` | ✅ |

### Commit Checkpoints

| Slice | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| 1 | `v2/templates/plan.template.md`, `v2/templates/review.template.md`, `v2/protocol.md`, `v2/skills/planner/*`, `v2/skills/verifier/*` | round-11 slice 1: add round contract | ✅ | ✅ |
| 2 | `v2/skills/builder/*`, `v2/templates/slice-packet.template.md`, `v2/templates/worker-report.template.*`, `v2/tools/builder-slice.sh`, `.context/baton/README.md` | round-11 slice 2: rename builder delegation to slice | ✅ | ✅ |
| 3 | `v2/tools/check-consistency.sh`, `v2/tools/validate-live-state.sh`, `v2/tests/contracts/*.sh`, `README.md`, `README.zh-CN.md`, `CLAUDE.md`, `v2/CLAUDE.md`, `project-profile.md`, `.harness/*` | round-11 slice 3: align live state to round contract | ✅ | ✅ |

### Discoveries

- Anthropic's `sprint` maps more closely to Baton's full `round` than to Builder's internal implementation cuts.
- `Round Contract` is the missing Baton concept; without it, pre-flight can challenge a plan but not explicitly agree on what "done" means.
- `slice` is a better Builder term than `batch` because it naturally covers both planned implementation cuts and verifier-driven fix slices.

### Risks

- Renaming the Builder helper and scratch layout can leave drift in validators or docs if any active reference is missed.
- Archived snapshots remain intentionally frozen, so terminology scans must focus on active control-plane files.

## Future Rounds (tentative)

- Round 12: deepen task-recovery / scope-change / closeout semantics if the round-contract model exposes gaps
- Round 13: consider whether review findings need a stronger contract beyond `Routing Signals`

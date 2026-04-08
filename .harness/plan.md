# Plan: Skill Boundary Hardening & Live Validators

## Metadata

| Key | Value |
|-----|-------|
| Name | Skill Boundary Hardening & Live Validators |
| Description | Repair role-boundary violations, modularize public skill entrypoints, structure the live control plane, remove stale historical docs, normalize lifecycle terms, clarify naming, migrate the task/round artifact contract from `brief/eval` to `plan/review`, tighten active section labels, and align the router role name on `Dispatcher` while keeping `/dispatch` stable |
| Started | 2026-04-08 |
| Round | 10 |
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

## Round 10

### Acceptance Criteria

**AC-10.1: Active prose uses `Dispatcher` as the router role name**
- Given: Baton’s active role set should read as noun-role names
- When: this round is complete
- Then: active protocol/docs/skills/templates/tools use `Dispatcher` where they refer to the router role

**AC-10.2: Command and file-system stability are preserved**
- Given: the user wants a better role name, not a disruptive command rename
- When: this round is complete
- Then: `/dispatch`, `dispatch/`, and `name: dispatch` remain unchanged

**AC-10.3: Live control-plane artifacts record the naming distinction cleanly**
- Given: `.harness/plan.md` and `.harness/review.md` are the active control plane
- When: this round is complete
- Then: the live artifacts explicitly distinguish role-name cleanup from command/path stability

**AC-10.4: Validation still passes after the role-name cleanup**
- Given: protocol wording, skill docs, and live artifacts all reference the router role
- When: this round is complete
- Then: `check-consistency.sh`, `validate-live-state.sh`, and `validate-round-sync.sh` still pass

### Approach

Treat this as a terminology alignment round. Replace only the role-name layer in active prose with `Dispatcher`, leave the command surface and file paths alone, and then update the live control plane to document that distinction explicitly. Do not retroactively rewrite archived snapshots.

**This round:** align the router role name on `Dispatcher` in active prose while preserving `/dispatch`
**Not this round:** rename commands, directories, or frontmatter identifiers

### Batch Plan

```text
Batch 1: update active docs, protocol, templates, and skill prose
  Files: README.md, README.zh-CN.md, v2/CLAUDE.md, v2/protocol.md, v2/templates/plan.template.md, v2/skills/*
  Check: rg -n '\bDispatch\b' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/skills v2/templates v2/tools
  Commit: "round-10 batch 1: rename router role to Dispatcher"

Batch 2: align user-facing tool messaging and live state
  Files: v2/tools/validate-round-sync.sh, .harness/plan.md, .harness/review.md, .harness/review-round-9.md
  Check: bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-10 batch 2: record Dispatcher naming"

Batch 3: run full contract validation
  Files: v2/tools/check-consistency.sh, .harness/plan.md, .harness/review.md
  Check: bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-10 batch 3: verify Dispatcher contract"
```

### AC → Test Mapping

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-10.1 | `rg -n '\\bDispatch\\b' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/skills v2/templates v2/tools` | ✅ |
| AC-10.2 | `rg -n '^name: dispatch$|/dispatch|v2/skills/dispatch/' v2/skills/dispatch/SKILL.md README.md README.zh-CN.md v2/CLAUDE.md v2/tools/check-consistency.sh` | ✅ |
| AC-10.3 | `bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh` | ✅ |
| AC-10.4 | `bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh` | ✅ |

### Commit Checkpoints

| Batch | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| 1 | `README.md`, `README.zh-CN.md`, `v2/CLAUDE.md`, `v2/protocol.md`, `v2/templates/plan.template.md`, `v2/skills/*` | round-10 batch 1: rename router role to Dispatcher | ✅ | ✅ |
| 2 | `v2/tools/validate-round-sync.sh`, `.harness/plan.md`, `.harness/review.md`, `.harness/review-round-9.md` | round-10 batch 2: record Dispatcher naming | ✅ | ✅ |
| 3 | `v2/tools/check-consistency.sh`, `.harness/plan.md`, `.harness/review.md` | round-10 batch 3: verify Dispatcher contract | ✅ | ✅ |

### Open Decisions

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-10.1 | None. The naming decision is constrained to active prose while command/path stability stays fixed. | — | resolved | no |

### Discoveries

- `Dispatcher` is the cleanest noun-role name because it matches `Planner / Builder / Verifier` without overstating authority.
- Keeping `/dispatch` stable preserves operator muscle memory while still cleaning up the conceptual model.
- This distinction only works if the live artifacts state it explicitly; otherwise readers infer an incomplete rename.

### Risks

- Future docs may regress to the older router label if authors copy older material instead of reading the current protocol.
- Because file paths still contain `dispatch`, reviewers need to distinguish role naming from filesystem naming deliberately.

## Future Rounds (tentative)

- Round 11: deepen task recovery / scope change / closeout semantics if more structure is needed
- Round 12: revisit any remaining operator-facing labels only if new ambiguity appears in real use

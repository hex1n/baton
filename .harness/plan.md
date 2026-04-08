# Plan: Skill Boundary Hardening & Live Validators

## Metadata

| Key | Value |
|-----|-------|
| Name | Skill Boundary Hardening & Live Validators |
| Description | Repair role-boundary violations, modularize public skill entrypoints, structure the live control plane, remove stale historical docs, normalize lifecycle terms, clarify naming, migrate the task/round artifact contract from `brief/eval` to `plan/review`, and tighten the remaining active section labels |
| Started | 2026-04-08 |
| Round | 9 |
| Verifier Mode | C |
| Execution Mode | standard |

## Context

- Round 8 settled the core artifact contract on `project-profile.md` / `plan.md` / `review.md` and renamed round history to `review-round-{N}.md`.
- After that rename, the remaining naming drift was no longer at the file level; it was inside active section labels and companion wording such as `## Task`, `Human Review Guidance`, `Recommend you review`, `brief template`, and `completed rounds`.
- These residual labels were spread across templates, protocol wording, planner/verifier companion files, README text, validators, and the live control-plane artifacts themselves.
- Historical review snapshots in `.harness/review-round-*.md` are intentionally left unchanged; they are historical records, not active contract files.
- The active contract should now consistently use `Metadata`, `Scope Breakdown`, `Round History`, `Human Judgment`, and `Needs your judgment`.

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `README.md` | | active operator-facing artifact descriptions must match the refined labels |
| `v2/protocol.md` | | protocol wording must use the same active section names as templates and skills |
| `v2/templates/plan.template.md` | | task-level section names define the canonical plan contract |
| `v2/templates/review.template.md` | | review-level human-judgment labels define the verifier contract |
| `v2/templates/exploration.template.md` | | the transient exploration checkpoint still had an overly generic `## Task` label |
| `v2/skills/planner/SKILL.md` | | public planner guidance still referenced the old template name |
| `v2/skills/planner/planning.md` | | round-planning guidance still referenced `brief` / `completed rounds` wording |
| `v2/skills/planner/revision.md` | | revision guidance still referenced the old `brief` wording |
| `v2/skills/verifier/cross-model.md` | | add-on review guidance still used the old human-judgment label |
| `v2/skills/dispatch/checkpoints.md` | | human checkpoint text must point to the current review section names |
| `v2/tools/validate-live-state.sh` | | validator must enforce the renamed section headings directly |
| `.harness/plan.md` | | live plan must record the label-cleanup round with the updated wording |
| `.harness/review.md` | | live review must record the label-cleanup round with the updated wording |
| | `.harness/review-round-*.md` | historical snapshots should remain frozen once archived |

### Metrics Baseline

| Metric | Value | Verification command |
|--------|-------|---------------------|
| Remaining active legacy-label hits after the active-layer sweep | 0 | `rg -n 'human review guidance|Recommend you review|## Task$|completed rounds|\\bbrief template\\b|current brief' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/templates v2/skills v2/tools` |
| Round-history snapshots intentionally left untouched | 8 | `ls .harness/review-round-*.md | wc -l` |

## Scope Breakdown

| # | Feature | Clarity | Round |
|---|---------|---------|-------|
| F1 | Protocol boundary hardening | Complete | 1 |
| F2 | Verifier read-only cleanup | Complete | 1 |
| F3 | Live state validation scripts | Complete | 1 |
| F4 | Public skill modularization | Complete | 2 |
| F5 | Governance / projection sync for moduleized skills | Complete | 2 |
| F6 | Structured control-plane fields (`Open Decisions`, `Routing Signals`) | Complete | 3 |
| F7 | Dispatch / Planner human-interaction cleanup | Complete | 3 |
| F8 | Historical docs cleanup | Complete | 4 |
| F9 | Lifecycle terminology normalization | Complete | 5 |
| F10 | Active file-name cleanup for modules / tools | Complete | 6 |
| F11 | Remove redundant `module-` prefix from skill-local files | Complete | 7 |
| F12 | Artifact contract rename: `brief/eval` → `plan/review` | Complete | 8 |
| F13 | Active section-label cleanup after the artifact rename | Clear | 9 |

## Round History

### Round 1: Boundary hardening + live validators ✅
- Decisions: fix role-boundary violations before deeper refactors; validate live state as first-class control-plane state
- Open: dispatch/planner remained monolithic and projection layers still lagged the repo structure

### Round 2: Moduleized public skill entrypoints ✅
- Decisions: keep public entrypoints thin and push procedure into role-local files; synchronize governance and projection layers in the same round
- Open: control-plane routing still depended on prose rather than explicit artifact fields

### Round 3: Structured control-plane fields ✅
- Decisions: add `Open Decisions` and `Routing Signals` as the minimum structured control-plane fields; keep Dispatch as the only human-facing role
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

## Round 9

### Acceptance Criteria

**AC-9.1: Active section labels align with the `plan/review` contract**
- Given: file-level names were already corrected in Round 8
- When: this round is complete
- Then: active templates, protocol text, skills, and live artifacts use `Metadata`, `Scope Breakdown`, `Round History`, `Human Judgment`, and `Needs your judgment`

**AC-9.2: Planner and Verifier guidance stop using the old planning/review labels**
- Given: the public and companion skill docs still guide how the contract is written
- When: this round is complete
- Then: active skill docs no longer reference `brief template`, `current brief`, or the old human-judgment wording

**AC-9.3: The transient exploration checkpoint uses a clearer label**
- Given: `v2/templates/exploration.template.md` is still part of Baton’s active control plane
- When: this round is complete
- Then: the checkpoint uses `## Objective` instead of the generic `## Task`

**AC-9.4: Live state and validators match the refined labels**
- Given: Baton routes from current live artifacts, not just docs
- When: this round is complete
- Then: `.harness/plan.md`, `.harness/review.md`, and `validate-live-state.sh` all use the refined labels directly

**AC-9.5: Validation still passes after the label cleanup**
- Given: this round tightens the active contract again
- When: this round is complete
- Then: `check-consistency.sh`, `validate-live-state.sh`, and `validate-round-sync.sh` still pass

### Approach

Treat this as a contract-polish round, not another structural refactor. Keep filenames and role boundaries fixed, then sweep only the active layer for residual section-label drift. Update the live artifacts last so Round 9 records the cleanup cleanly while archived snapshots stay untouched.

**This round:** tighten active section labels and companion wording after the `plan/review` rename
**Not this round:** rewrite historical snapshots or reopen the artifact/file naming decision

### Batch Plan

```text
Batch 1: sweep active docs, templates, and skill wording
  Files: README.md, v2/protocol.md, v2/templates/exploration.template.md, v2/skills/planner/*, v2/skills/verifier/cross-model.md
  Check: rg -n 'human review guidance|Recommend you review|## Task$|completed rounds|\\bbrief template\\b|current brief' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/templates v2/skills v2/tools
  Commit: "round-9 batch 1: tighten active section labels"

Batch 2: align live state and validators
  Files: .harness/plan.md, .harness/review.md, v2/tools/validate-live-state.sh
  Check: bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-9 batch 2: align live state labels"

Batch 3: run full contract validation
  Files: v2/tools/check-consistency.sh, .harness/review-round-8.md, .harness/plan.md, .harness/review.md
  Check: bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-9 batch 3: verify label cleanup"
```

### AC → Test Mapping

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-9.1 | `bash v2/tools/check-consistency.sh` | ✅ |
| AC-9.2 | `rg -n 'human review guidance|Recommend you review|## Task$|completed rounds|\\bbrief template\\b|current brief' README.md README.zh-CN.md project-profile.md v2/CLAUDE.md v2/protocol.md v2/templates v2/skills v2/tools` | ✅ |
| AC-9.3 | `rg -n '^## Objective$' v2/templates/exploration.template.md` | ✅ |
| AC-9.4 | `bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh` | ✅ |
| AC-9.5 | `bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh` | ✅ |

### Commit Checkpoints

| Batch | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| 1 | `README.md`, `v2/protocol.md`, `v2/templates/exploration.template.md`, `v2/skills/planner/*`, `v2/skills/verifier/cross-model.md` | round-9 batch 1: tighten active section labels | ✅ | ✅ |
| 2 | `.harness/plan.md`, `.harness/review.md`, `v2/tools/validate-live-state.sh` | round-9 batch 2: align live state labels | ✅ | ✅ |
| 3 | `v2/tools/check-consistency.sh`, `.harness/review-round-8.md`, `.harness/plan.md`, `.harness/review.md` | round-9 batch 3: verify label cleanup | ✅ | ✅ |

### Open Decisions

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-9.1 | None. This round only tightens active wording and label coherence. | — | resolved | no |

### Discoveries

- Once file names are correct, the next source of operator friction is almost always section and heading language, not structure.
- Historical snapshots are more useful as frozen evidence than as retroactively normalized documents.
- `Objective` is a clearer label than `Task` for the transient exploration checkpoint because that file only captures the current exploration target.

### Risks

- Validator coverage is only as good as the labels it enforces; if new headings drift later, the live-state validator must keep pace.
- Historical snapshots still contain older headings by design; future audits must distinguish archived history from the active contract.

## Future Rounds (tentative)

- Round 10: deepen task recovery / scope change / closeout semantics if more structure is needed
- Round 11: revisit any remaining operator-facing labels only if new ambiguity appears in real use

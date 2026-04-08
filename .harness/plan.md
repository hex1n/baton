# Plan: Baton Protocol Refinement

## Metadata

| Key | Value |
|-----|-------|
| Name | Baton Protocol Refinement |
| Description | Continue refining Baton's protocol, control-plane artifacts, naming, task hierarchy, and round classification model |
| Started | 2026-04-08 |
| Round | 12 |
| Verifier Mode | C |
| Execution Mode | standard |
| Scope Class | S3 |
| Risk Class | R2 |
| Expected Rounds | 1 |
| Expected Slices This Round | 3+ |

## Context

- Round 11 completed the hierarchy cleanup around `task -> round -> round contract -> slice`, and live artifacts already use `Round Contract` plus `Implementation Slices`.
- Baton now distinguishes task structure cleanly, but it still lacks explicit task classification in the control plane. `Execution Mode` and `Verifier Mode` exist, yet they do not directly express scope, risk, or forecast.
- The desired change is not a single total level. Baton should keep multi-axis classification so a round can be small-but-risky or large-but-low-risk without collapsing that nuance.
- The new fields belong in `plan.md § Metadata`, because Planner owns the round shape, Dispatcher consumes it, and Verifier must challenge the resulting round contract instead of guessing complexity from prose.
- Archived review snapshots remain frozen. Only the active control plane and forward projections should adopt the new classification model.

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `v2/templates/plan.template.md` | | add the new classification and forecast metadata fields |
| `v2/protocol.md` | | define the classification model and the default execution-mode mapping |
| `v2/skills/planner/SKILL.md` | | Planner must be required to fill the new metadata |
| `v2/skills/planner/planning.md` | | planning flow must classify the round before locking the contract |
| `v2/skills/planner/revision.md` | | revisions may need to update classification if the round shape changes |
| `v2/skills/dispatch/SKILL.md` | | Dispatcher must consume, not invent, classification |
| `v2/skills/dispatch/routing.md` | | routing rules must derive execution mode from classification |
| `v2/tools/validate-live-state.sh` | | live-state validation must require the new metadata fields |
| `v2/tests/contracts/02-artifact-contracts.sh` | | artifact contract tests must pin the new metadata fields and protocol section |
| `v2/tools/check-consistency.sh` | | consistency checks must project the classification model into templates and README |
| `README.md` | | English projection layer must explain classification, forecast, verifier mode, and execution mode |
| `README.zh-CN.md` | | Chinese projection layer must explain the same model |
| `CLAUDE.md` | | root quick reference must project the new classification layer |
| `v2/CLAUDE.md` | | v2 quick reference must project the new classification layer |
| `.harness/plan.md` | | live plan must carry the new metadata and Round 12 contract |
| `.harness/review.md` | | live review must evaluate the classification change and stay round-aligned |
| | `v2/skills/builder/*` | builder delegation is already on `slice`; this round is about classification, not implementation-unit naming |
| | `v2/tools/external-review.sh` | provider-neutral review adapter is unaffected by classification fields |

### Metrics Baseline

| Metric | Value | Verification command |
|--------|-------|---------------------|
| Archived review snapshots before Round 12 | 11 | `ls .harness/review-round-*.md | wc -l` |
| Classification metadata rows required by the new plan template | 4 | `rg -n 'Scope Class|Risk Class|Expected Rounds|Expected Slices This Round' v2/templates/plan.template.md | wc -l` |

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
| F14 | Router role-name cleanup to `Dispatcher` in prose | Complete | 10 |
| F15 | Task hierarchy normalization to `round -> round contract -> slice` | Complete | 11 |
| F16 | Explicit task classification and forecasting in `plan.md § Metadata` | Clear | 12 |

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

### Round 11: Round contract and slice terminology finalized ✅
- Decisions: keep `Round` as the top-level delivery cycle, make `Round Contract` explicit, rename Builder-internal `batch` to `slice`, and avoid compatibility shims
- Open: Baton still lacked explicit scope/risk classification and round forecasts in the active control plane

## Round 12

### Acceptance Criteria

**AC-12.1: Baton records classification and forecast fields in the active control plane**
- Given: `plan.md § Metadata` is the canonical summary for the current round
- When: this round is complete
- Then: the active plan and the plan template both include `Scope Class`, `Risk Class`, `Expected Rounds`, and `Expected Slices This Round`

**AC-12.2: Baton distinguishes classification, forecast, evidence mode, and execution mode**
- Given: the harness already has `Verifier Mode` and `Execution Mode`
- When: this round is complete
- Then: protocol, Planner guidance, and Dispatcher guidance clearly explain that `Scope/Risk` classify the round, forecasts predict shape, `Verifier Mode` describes evidence capability, and `Execution Mode` is the orchestration decision

**AC-12.3: Validators and projection docs enforce the new classification model**
- Given: Baton depends on projection sync and live validators
- When: this round is complete
- Then: consistency checks, artifact contract tests, live-state validation, README projections, and quick references all include the new classification layer

**AC-12.4: Live artifacts advance cleanly to Round 12**
- Given: Round 11 is already complete
- When: this round is complete
- Then: `.harness/review-round-11.md` preserves the previous review, `.harness/plan.md` and `.harness/review.md` align on Round 12, and all validators pass

### Open Decisions

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-12.1 | None. The decision is to keep multi-axis classification instead of collapsing Baton to a single task level. | — | resolved | no |

### Round Contract

| Key | Value |
|-----|-------|
| Scope In | Add scope/risk classification plus round forecasts to Baton's control plane, protocol, planner/dispatcher guidance, validators, projection docs, and live artifacts |
| Scope Out | Renaming `Round`, creating a single total task level, or revisiting Builder slice terminology |
| Done Criteria | Templates, protocol, Planner, Dispatcher, validators, README, CLAUDE, and live artifacts all use the same classification model and validate cleanly |
| Verification Plan | Run contract tests, consistency checks, live-state validation, and round-sync validation after updating the live plan/review pair |
| Exit Threshold | `v2/tests/run.sh`, `check-consistency.sh`, `validate-live-state.sh`, and `validate-round-sync.sh` all pass with the live task on Round 12 |
| Deferred Items | Consider richer review-sidecar classification only if the new plan metadata still leaves routing ambiguity |

### Approach

Keep Baton's task structure unchanged: `task -> round -> round contract -> slice`. Add classification only at the `plan.md § Metadata` layer so Planner defines the round, Dispatcher consumes it, and Verifier can challenge whether the contract matches the declared scope/risk. Avoid a single total level, because Baton needs to express small-but-risky and large-but-low-risk work without flattening that nuance.

**This round:** add explicit `Scope Class`, `Risk Class`, and forecast fields, then wire them through protocol, planners, routing, validators, and live artifacts.
**Not this round:** invent a new top-level lifecycle term or replace `Verifier Mode` with a new evidence taxonomy.

### Implementation Slices

```text
Slice 1: classify the protocol
  Files: v2/templates/plan.template.md, v2/protocol.md, v2/skills/planner/SKILL.md, v2/skills/planner/planning.md, v2/skills/planner/revision.md, v2/skills/dispatch/SKILL.md, v2/skills/dispatch/routing.md
  Check: rg -n 'Scope Class|Risk Class|Expected Rounds|Expected Slices This Round|Task Classification' v2/templates/plan.template.md v2/protocol.md v2/skills/planner v2/skills/dispatch
  Commit: "round-12 slice 1: add task classification model"

Slice 2: enforce classification through validators and projections
  Files: v2/tools/validate-live-state.sh, v2/tests/contracts/02-artifact-contracts.sh, v2/tools/check-consistency.sh, README.md, README.zh-CN.md, CLAUDE.md, v2/CLAUDE.md
  Check: rg -n 'Scope Class|Risk Class|Expected Rounds|Expected Slices This Round|Task Classification' v2/tools/validate-live-state.sh v2/tests/contracts/02-artifact-contracts.sh v2/tools/check-consistency.sh README.md README.zh-CN.md CLAUDE.md v2/CLAUDE.md
  Commit: "round-12 slice 2: project classification model"

Slice 3: advance the live control plane
  Files: .harness/plan.md, .harness/review.md, .harness/review-round-11.md
  Check: bash v2/tests/run.sh && bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh && bash v2/tools/validate-round-sync.sh
  Commit: "round-12 slice 3: refresh live control plane"
```

### AC → Test Mapping

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-12.1 | `rg -n 'Scope Class|Risk Class|Expected Rounds|Expected Slices This Round' v2/templates/plan.template.md .harness/plan.md` | ✅ |
| AC-12.2 | `rg -n 'Task Classification|Execution Mode.*orchestration|Scope Class|Risk Class' v2/protocol.md v2/skills/planner v2/skills/dispatch` | ✅ |
| AC-12.3 | `bash v2/tests/run.sh && bash v2/tools/check-consistency.sh && bash v2/tools/validate-live-state.sh` | ✅ |
| AC-12.4 | `bash v2/tools/validate-round-sync.sh && test -f .harness/review-round-11.md` | ✅ |

### Commit Checkpoints

| Slice | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| 1 | `v2/templates/plan.template.md`, `v2/protocol.md`, `v2/skills/planner/*`, `v2/skills/dispatch/*` | round-12 slice 1: add task classification model | ✅ | ✅ |
| 2 | `v2/tools/validate-live-state.sh`, `v2/tests/contracts/02-artifact-contracts.sh`, `v2/tools/check-consistency.sh`, `README.md`, `README.zh-CN.md`, `CLAUDE.md`, `v2/CLAUDE.md` | round-12 slice 2: project classification model | ✅ | ✅ |
| 3 | `.harness/plan.md`, `.harness/review.md`, `.harness/review-round-11.md` | round-12 slice 3: refresh live control plane | ✅ | ✅ |

### Discoveries

- Baton's missing piece was not a new lifecycle unit. It was explicit classification of the current round's size, risk, and likely shape.
- `Expected Rounds` and `Expected Slices This Round` must stay forecasts; if treated as gates, Baton would duplicate `Execution Mode` and confuse planning with orchestration.
- Dispatcher should consume Planner's classification rather than recompute it, otherwise Baton would split ownership of the round shape across roles.
- The coarse forecast enum is working as intended: `3+` prevents false precision in live planning even when the current round happens to use three concrete slices.

### Risks

- Live-state validation is now stricter; any stale plan metadata will fail immediately once Round 12 is written.
- Projection docs can drift on this topic because classification touches README, CLAUDE, protocol, and role-local guidance at once.

## Future Rounds (tentative)

- Round 13: deepen task-recovery / scope-change / closeout semantics if the classification model exposes new routing ambiguity
- Round 14: consider whether review findings need structured severity or ownership fields beyond `Routing Signals`

# Plan: Baton Protocol Refinement

> Baton control-plane projection of `.harness/design.md`. Keep this file concise and structured for routing, approval, and recovery.

## Metadata

| Key | Value |
|-----|-------|
| Name | Baton Protocol Refinement |
| Description | Continue refining Baton with design-stage review add-ons and pre-flight triage before Builder admission |
| Started | 2026-04-08 |
| Round | 14 |
| Verifier Mode | C |
| Execution Mode | full |
| Scope Class | S3 |
| Risk Class | R2 |
| Expected Rounds | 1 |
| Expected Slices This Round | 3+ |

## Context

- `v2/protocol.md`: Round 13 already established `design.md` as the planning artifact and made Superpowers semantics the default Planner engine policy, but it deferred design-stage adversarial / cross-model review orchestration to the next round.
- `v2/templates/review.template.md`: pre-flight still recorded only verify-pass add-ons, so Baton had no canonical slot for design-stage add-ons or triage.
- `v2/skills/dispatch/checkpoints.md` + `v2/skills/dispatch/routing.md`: Dispatcher could not distinguish "structural design fix before approval" from "human checkpoint before approval".
- `v2/skills/verifier/adversarial.md` + `v2/skills/verifier/cross-model.md`: both guides still leaned toward verification-phase review and lacked design-stage triage semantics.
- `v2/tools/validate-live-state.sh`, `v2/tools/validate-round-contract.sh`, `v2/tools/check-consistency.sh`, and contract tests must all enforce the new control-plane fields or Baton will drift back to prose-only routing.
- `.harness/review-round-13.md`: Round 13 review is archived before making Round 14 active.

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `v2/protocol.md` | | confirm design-stage review add-ons and triage are already recognized at protocol level |
| `v2/templates/review.template.md` | | add canonical pre-flight fields and routing rows |
| `v2/skills/dispatch/checkpoints.md` | | add auto-revise vs human-checkpoint admission routing |
| `v2/skills/dispatch/routing.md` | | keep routing mechanical from `review.md § Routing Signals` |
| `v2/skills/dispatch/SKILL.md` | | project the new Dispatcher responsibility boundary |
| `v2/skills/verifier/SKILL.md` | | confirm pre-flight execution order already expects design-review triage |
| `v2/skills/verifier/preflight.md` | | confirm design-review stage already sits between core challenge and verify-pass add-on selection |
| `v2/skills/verifier/design-review.md` | | use it as the canonical triage contract |
| `v2/skills/verifier/adversarial.md` | | extend to pre-flight design challenge |
| `v2/skills/verifier/cross-model.md` | | extend to pre-flight design challenge and triage classification |
| `v2/tools/validate-live-state.sh` | | require new review sections and routing rows |
| `v2/tools/validate-round-contract.sh` | | lint triage routing invariants |
| `v2/tools/check-consistency.sh` | | project the new template rows and verifier guide |
| `v2/tests/contracts/02-artifact-contracts.sh` | | pin the review-template artifact contract |
| `README.md`; `README.zh-CN.md`; `CLAUDE.md`; `v2/CLAUDE.md` | | sync the new design-stage review layer into projection docs |
| `.harness/design.md`; `.harness/plan.md`; `.harness/review.md` | | keep live artifacts aligned with Round 14 |
| | `v2/tools/external-review.sh` | adapter implementation is not changing this round |
| | `v2/skills/builder/*` | Builder behavior does not change in this round |

### Metrics Baseline

| Metric | Value | Verification command |
|--------|-------|---------------------|
| Archived active reviews before Round 14 | 13 | `Get-ChildItem .harness\\review-round-*.md | Measure-Object | Select-Object -ExpandProperty Count` |
| New pre-flight routing fields expected in review template | 2 | `Select-String -Path v2\\templates\\review.template.md -Pattern 'Design Review Add-ons|Pre-flight Triage' | Measure-Object | Select-Object -ExpandProperty Count` |

## Scope Breakdown

| # | Feature | Clarity | Round |
|---|---------|---------|-------|
| F1 | Protocol boundary hardening | Complete | 1 |
| F3 | Artifact rename to `plan/review` | Complete | 8 |
| F5 | Plan quality / deepen / confidence / round-load guard | Complete | 12 |
| F6 | Dual-artifact planning (`design.md` + projected `plan.md`) | Complete | 13 |
| F7 | Default Planner engine selection + Superpowers companion adapters | Complete | 13 |
| F8 | Design-stage review add-ons + pre-flight triage | Clear | 14 |

## Round History

### Round 1: Boundary hardening + live validators ✅
- Decisions: fix role-boundary violations before deeper refactors; treat validators as first-class control-plane code
- Open: artifact state still lived in monolithic files and prose-heavy routing

### Round 3: Structured control-plane fields ✅
- Decisions: add `Open Decisions` and `Routing Signals` as the minimum structured control-plane fields; keep Dispatcher as the only human-facing role
- Open: planning quality and artifact clarity still depended too much on prose

### Round 8: Artifact contract renamed to `plan/review` ✅
- Decisions: adopt `plan.md` and `review.md` as the active control-plane artifacts
- Open: `plan.md` still had to act as both the design doc and the control plane

### Round 11: Round contract and slice terminology finalized ✅
- Decisions: keep `Round` as the top-level delivery cycle, make `Round Contract` explicit, and rename Builder-internal `batch` to `slice`
- Open: Baton still needed stronger planning-quality control

### Round 12: Plan-quality and round-load gates ✅
- Decisions: add `Planning Depth`, `Recommendation Confidence`, `Confidence Calibration`, and the round-load guard so Baton can reject coherent-but-under-searched or overloaded rounds before Builder starts
- Open: `plan.md` still mixed human-readable design narrative with machine-readable control-plane state, and default planner-engine policy was still implicit

### Round 13: Dual artifacts + default planner engines ✅
- Decisions: add `.harness/design.md`, keep `plan.md` as the execution/routing control plane, and make Superpowers semantics the default Planner engine policy
- Open: design-stage adversarial / cross-model review still lacked a formal pre-flight gate and triage path

## Round 14

### Acceptance Criteria

**AC-14.1: `review.md` explicitly distinguishes design-stage review from verify-pass review**
- Given: design-stage add-ons and verify-pass add-ons are different control-plane decisions
- When: this round is complete
- Then: `v2/templates/review.template.md`, validators, and live `review.md` contain `Design Review Add-ons` and `Pre-flight Triage` separately from `Verification Add-ons`

**AC-14.2: Dispatcher routes design-stage triage mechanically before Builder admission**
- Given: some pre-flight findings are structural and should auto-revise, while others need human judgment
- When: this round is complete
- Then: Dispatcher guidance auto-routes Planner for `auto-revise`, blocks Builder while triage is non-`none`, and surfaces `human-checkpoint` as a distinct checkpoint

**AC-14.3: Verifier add-on guides support pre-flight design challenge semantics**
- Given: design-stage adversarial and cross-model review must classify findings differently from post-build review
- When: this round is complete
- Then: `adversarial.md` and `cross-model.md` both describe pre-flight design review, classify findings into auto-revise vs needs-human, and keep add-ons read-only

**AC-14.4: Mechanical checks enforce the new control-plane fields**
- Given: Baton cannot rely on prose discipline
- When: this round is complete
- Then: live-state validation, round-contract lint, consistency checks, and artifact contract tests all require the new review fields and triage invariants

**AC-14.5: Live artifacts advance cleanly to Round 14**
- Given: Round 13 is already complete
- When: this round is complete
- Then: `.harness/review-round-13.md` preserves the prior review, and active `design.md`, `plan.md`, and `review.md` all reflect Round 14

### Plan Quality

| Key | Value |
|-----|-------|
| Planning Depth | deepen |
| Recommendation Confidence | medium |
| Confidence Basis | The change is conceptually narrow and follows the protocol direction already chosen in Round 13, but it touches Builder admission, Dispatcher routing, Verifier guidance, validators, docs, and live artifacts together, so integration risk is still medium. |
| Problem Statement | Baton already had richer design artifacts and full-mode add-ons, but it still lacked a formal design-stage gate between "plan challenge succeeded" and "Builder may start", so structural design findings could not be auto-fixed mechanically and semantic findings could not stop at a distinct pre-build checkpoint. |
| Load-Bearing Assumptions | `review.md` is still the right place to carry all Verifier-to-Dispatcher routing state; Dispatcher can safely auto-route bounded Planner revisions if the triage contract is narrow; design-stage add-ons can share the same add-on files as verification-phase review as long as the guide distinguishes the phase semantics clearly. |
| Constraints vs Conventions | True constraints: Dispatcher must stay artifact-driven, Builder admission must remain mechanical, add-ons stay read-only, and `plan.md` remains the single execution/routing truth. Conventions: pre-flight used to record only verify-pass add-ons, and design-stage review lived as future intent rather than canonical control-plane behavior. |
| Alternatives Considered | A) leave design-stage review informal in prose; B) overload `Verification Add-ons` to mean both pre-flight and post-build review; C) add distinct `Design Review Add-ons` and `Pre-flight Triage`, then route them mechanically. Recommendation: C because it preserves clear control-plane semantics. |
| Failure Mode | `auto-revise` could silently widen scope or semantic direction, or Dispatcher could still behave like the old approval flow even after the new rows exist. |

### Decisions

| Decision | Chose | Rejected | Why |
|----------|-------|----------|-----|
| Pre-flight review fields | separate `Design Review Add-ons` + `Pre-flight Triage` | reuse `Verification Add-ons` | pre-flight and verify-pass decisions have different meanings |
| Dispatcher response to structural design issues | auto-route bounded Planner revision | force all design issues through human approval | structural fixes should be mechanical to reduce friction |
| Triage boundary | structural only for `auto-revise`; semantic/scope/policy goes to human | broad auto-fix authority | Baton must not silently change product direction |
| Add-on guide strategy | extend existing `adversarial.md` / `cross-model.md` | add separate duplicate files | keeps add-on semantics centralized while preserving phase distinctions |

### Open Decisions

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-14.1 | None. This round already decided the design-stage triage contract and its routing boundary. | — | resolved | no |

### Round Contract

| Key | Value |
|-----|-------|
| Scope In | Add canonical pre-flight design-review fields and triage routing, extend verifier add-on guides for design-stage review semantics, update validators/docs, archive Round 13 review, and refresh live Round 14 artifacts |
| Key Entry Points | `v2/templates/review.template.md`; `v2/skills/dispatch/checkpoints.md`; `v2/skills/dispatch/routing.md`; `v2/skills/dispatch/SKILL.md`; `v2/skills/verifier/adversarial.md`; `v2/skills/verifier/cross-model.md`; `v2/tools/validate-live-state.sh`; `v2/tools/validate-round-contract.sh`; `v2/tools/check-consistency.sh`; `v2/tests/contracts/02-artifact-contracts.sh` |
| Scope Out | Changing Builder execution, changing the external-review adapter runtime, or making Dispatcher read `design.md` directly |
| Done Criteria | `review.md` template and live review explicitly record design-stage add-ons and triage, Dispatcher guidance blocks Builder while triage is unresolved, verifier add-on guides support pre-flight design challenge semantics, validators enforce the new fields, and Round 13 review is archived before Round 14 becomes active |
| Verification Plan | Run targeted PowerShell spot checks for the changed guidance plus bash validators where the host still permits them: contract tests, live-state validation, round-contract lint, and round-sync; if Git Bash wrappers still fail on this host, document the degraded evidence explicitly in `review.md` |
| Budget Note | This round changes admission control, review templates, add-on guidance, validators, projection docs, and live artifacts together. Splitting it would leave Baton in a half-upgraded state where pre-flight triage exists in some layers but not others. |
| Overload Override | none |
| Exit Threshold | The changed docs and templates are internally consistent, active artifacts align on Round 14, and the available validators / spot checks pass or any host failure is explicitly recorded as residual risk |
| Deferred Items | Runtime hardening of `external-review.sh`; future Builder-side worker strategy changes |

### Approach

Use `review.md` as the canonical bridge between richer pre-flight design review and Builder admission:

- pre-flight records which design-stage add-ons ran
- pre-flight classifies the result into `none / auto-revise / human-checkpoint`
- Dispatcher reads those rows literally
- `auto-revise` re-enters Planner revision without a human checkpoint
- `human-checkpoint` stops the flow before Builder starts
- verify-pass add-ons remain a separate decision for post-build verification

### Implementation Slices

```text
Slice 1: add control-plane rows and Dispatcher triage routing
  Files: v2/templates/review.template.md, v2/skills/dispatch/checkpoints.md, v2/skills/dispatch/routing.md, v2/skills/dispatch/SKILL.md
  Check: Select-String -Path v2\templates\review.template.md,v2\skills\dispatch\checkpoints.md,v2\skills\dispatch\routing.md,v2\skills\dispatch\SKILL.md -Pattern 'Design Review Add-ons|Pre-flight Triage|auto-revise|human-checkpoint'
  Commit: "round-14 slice 1: add preflight triage control plane"

Slice 2: extend verifier add-on guides and validators
  Files: v2/skills/verifier/adversarial.md, v2/skills/verifier/cross-model.md, v2/tools/validate-live-state.sh, v2/tools/validate-round-contract.sh, v2/tools/check-consistency.sh, v2/tests/contracts/02-artifact-contracts.sh
  Check: Select-String -Path v2\skills\verifier\adversarial.md,v2\skills\verifier\cross-model.md,v2\tools\validate-live-state.sh,v2\tools\validate-round-contract.sh,v2\tools\check-consistency.sh,v2\tests\contracts\02-artifact-contracts.sh -Pattern 'auto-revise|human-checkpoint|Design Review Add-ons|Pre-flight Triage'
  Commit: "round-14 slice 2: wire design-stage add-on triage"

Slice 3: sync docs and live artifacts
  Files: README.md, README.zh-CN.md, CLAUDE.md, v2/CLAUDE.md, .harness/design.md, .harness/plan.md, .harness/review.md, .harness/review-round-13.md
  Check: bash v2/tools/validate-live-state.sh --repo-root . && bash v2/tools/validate-round-contract.sh --repo-root . && bash v2/tools/validate-round-sync.sh --repo-root .
  Commit: "round-14 slice 3: project design-stage review gate"
```

### AC → Test Mapping

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-14.1 | `Select-String -Path v2\templates\review.template.md,v2\tools\validate-live-state.sh,v2\tests\contracts\02-artifact-contracts.sh -Pattern 'Design Review Add-ons|Pre-flight Triage'` | ✅ |
| AC-14.2 | `Select-String -Path v2\skills\dispatch\checkpoints.md,v2\skills\dispatch\routing.md,v2\skills\dispatch\SKILL.md -Pattern 'auto-revise|human-checkpoint|Design Review Add-ons|Pre-flight Triage'` | ✅ |
| AC-14.3 | `Select-String -Path v2\skills\verifier\adversarial.md,v2\skills\verifier\cross-model.md -Pattern 'Pre-flight|auto-revise|needs-human|read-only'` | ✅ |
| AC-14.4 | `bash v2/tools/validate-live-state.sh --repo-root .` plus `bash v2/tools/validate-round-contract.sh --repo-root .` or targeted PowerShell spot checks if wrappers are blocked | ✅ |
| AC-14.5 | `Test-Path .harness\review-round-13.md` plus active artifact inspection | ✅ |

### Commit Checkpoints

| Slice | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| 1 | `v2/templates/review.template.md`, `v2/skills/dispatch/*` | round-14 slice 1: add preflight triage control plane | ✅ | ✅ |
| 2 | `v2/skills/verifier/*`, `v2/tools/*`, `v2/tests/contracts/02-artifact-contracts.sh` | round-14 slice 2: wire design-stage add-on triage | ✅ | ✅ |
| 3 | `README.md`, `README.zh-CN.md`, `CLAUDE.md`, `v2/CLAUDE.md`, `.harness/*` | round-14 slice 3: project design-stage review gate | ✅ | ✅ |

### Discoveries

- Baton needed one more admission-control layer after dual artifacts: a formal design-stage review gate before Builder starts.
- `Design Review Add-ons` and `Verification Add-ons` must remain separate or the control plane becomes ambiguous.
- `auto-revise` only works if Dispatcher reads it literally and the revision boundary is narrow.
- Validator coverage matters even more here because the new fields gate Builder admission rather than just documenting review nuance.

### Risks

- The live host still has intermittent Git Bash startup failures, so end-to-end wrapper validation may remain partially degraded.
- Future users may overuse `auto-revise`; the protocol text must keep the semantic boundary narrow.
- Cross-model pre-flight will still depend on external reviewer availability in real environments.

## Future Rounds (tentative)

- Round 15: harden real external-review availability checks and cross-model fallback behavior
- Round 16: integrate Builder-side worker strategy improvements after the planning / review control plane is stable

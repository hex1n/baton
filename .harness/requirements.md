# Requirements: remove-spec-extensions

**Topic**: delete `spec/extensions/` and all live references
**Status**: `final`
**Sizing**: `Small`

## 1. Problem

**Original request**: "我想删除 spec/extensions 目录及其下面所有文件" (delete
`spec/extensions/` and all its files).

**Reframed problem**: After `promote-java-artifacts` (2026-04-04) moved
the "java-backend-strict" overlay's templates into `spec/templates/`
core, the `spec/extensions/` directory and its migration guardrails
have become dead weight. Four surfaces still mention them:

1. `spec/extensions/java-backend-strict/` — 7 stale files kept alive
   only by inertia.
2. `spec/README.md` — 3 places advertise the directory to readers.
3. `spec/bootstrap/commands/check-consistency.sh` — invariants
   14/17/18 assert the legacy paths are absent (a guard that has been
   dead — permanently-false `[[ -e ... ]]` — since the promotion
   commit).
4. `skills/baton-evaluator/SKILL.md:210` — parenthetical "(extensions
   may replace this layer)" is a stale hook-point reference.

The undesirable state: readers (human and LLM) are told the overlay
exists as a governance concept, and the consistency checker carries
permanently-dead code. Solved state: every live reference to
`spec/extensions/` and `java-backend-strict` is removed (except the
intentionally preserved historical snapshots in `docs/*.md` and
`.harness/history/**`), and `check-consistency.sh` still passes
end-to-end with no weakened coverage of the core templates.

## 2. Assumptions

| # | Assumption | Type | Confidence | If wrong... |
|---|-----------|------|------------|-------------|
| A1 | The three core templates (`spec/templates/{codebase-map,decisions,escalation}.template.md`) are sufficient — no runtime/validator path still expects the legacy overlay copies | Testable | High — verified via exploration §6; positive halves of invariants 14/17/18 cover them | Removing the negative-half guards would silently drop coverage |
| A2 | No test or script outside the ones found in exploration.md references `spec/extensions/` or `java-backend-strict` | Testable | High — repo-wide grep returned zero test hits | A latent reference exists; Phase 5 Verify re-grep will catch it |
| A3 | The 5 `docs/*.md` snapshots are historical artifacts the user genuinely wants left untouched | User intent | High — user confirmed scope at Gate 0 via structured question | Docs drift becomes a long-term readability problem; flagged for retrospective |
| A4 | `check-consistency.sh` end-to-end (exit 0) is a sufficient functional test — no unit test needed | Convention | Medium — no `test-check-consistency*.sh` exists; the tool has always been tested only via end-to-end invocation | A regression in an unrelated invariant slips through; accepted because this task touches only dead guards |
| A5 | The semantic shift in `baton-evaluator` SKILL.md (removing the "extensions may replace Layer 2" hint) matches `baton-positioning`'s protocol-first stance | Convention | High — baton-positioning explicitly folded stack-specific overlays into core | The change would need a broader role-contracts revision; defer to retrospective if challenged |

## 3. Scope

### 3.1 In Scope

- Delete `spec/extensions/` directory (`rm -rf`) — 7 files under
  `java-backend-strict/`.
- Remove 3 references in `spec/README.md` (lines 17, 136–137, 201).
- Remove dead code in `spec/bootstrap/commands/check-consistency.sh`:
  - 3 `legacy_*_template` variable definitions (lines 20, 23, 24)
  - 3 invariant guard `if [[ -e ... ]]` blocks for invariants 14/17/18
    (lines 473–474, 647–648, 700–701)
- Remove parenthetical "(extensions may replace this layer)" in
  `skills/baton-evaluator/SKILL.md:210`.
- Pending architect decision (Q1): optional `[[ ! -d spec/extensions ]]`
  regression guard added to `check-consistency.sh` as a new invariant
  line (see R7).

### 3.2 Out of Scope

- `docs/*.md` historical analysis snapshots (5 files) — user accepted
  drift; flagged for retrospective.
- `.harness/history/**` — archived task artifacts, immutable.
- `.tmp/deep-research-workspace/**` — scratch workspace.
- `skills/deep-research/SKILL.md:343` — false positive ("columnar
  extensions" in SQLite example).
- Role-contracts revision to fully remove the "extensions" concept
  from protocol docs — deferred; this task only removes the
  skill-level hint.
- Writing a dedicated `tests/test-check-consistency*.sh` unit test
  — separate standardization candidate.

## 4. Functional Requirements

### FR-1 Directory deletion

- **R1. [P0]** `spec/extensions/` must not exist after the task.
  All 7 files under `java-backend-strict/` removed.

### FR-2 Governance reference cleanup

- **R2. [P0]** `spec/README.md` must contain zero mentions of
  `extensions` or `java-backend-strict`. The 3 current references
  (lines 17, 136–137, 201) deleted; surrounding structure (the
  directory tree diagram) remains coherent.

### FR-3 Dead-code cleanup in consistency checker

- **R3. [P0]** `spec/bootstrap/commands/check-consistency.sh` must
  contain zero definitions or references to `legacy_escalation_template`,
  `legacy_decisions_template`, `legacy_codebase_map_template`, or
  `spec/extensions/java-backend-strict`. The 3 variable lines (20,
  23, 24) and 3 if-block guards for invariants 14/17/18 (lines
  473–474, 647–648, 700–701) removed. (depends-on: R1)
- **R4. [P0]** The surviving positive halves of invariants 14/17/18
  (the `[[ -e spec/templates/*.template.md ]]` checks and downstream
  schema/skill checks) remain functional. (depends-on: R3)

### FR-4 Stale skill documentation cleanup

- **R5. [P0]** `skills/baton-evaluator/SKILL.md:210` must not contain
  the parenthetical "(extensions may replace this layer)". Surrounding
  sentence remains grammatical.

### FR-5 End-to-end consistency still holds

- **R6. [P0]** `bash spec/bootstrap/commands/check-consistency.sh`
  must exit 0 after all edits. All remaining invariants (1–18 minus
  the removed legacy halves) must still pass. (depends-on: R1, R2,
  R3, R4, R5)

### FR-6 Regression guard (pending architect decision Q1)

- **R7. [P1]** (conditional — adopted iff architect resolves Q1 to
  "bundle") A new invariant in `check-consistency.sh` asserts
  `[[ ! -d spec/extensions ]]`, catching any future re-creation.
  If architect resolves Q1 to "split", this becomes a follow-up task
  and R7 is dropped from this requirements doc before Phase 5.

## 5. Non-Goals

- **NG-1** Modifying `docs/*.md` historical snapshots — user scope
  excludes them.
- **NG-2** Adding a unit test file `tests/test-check-consistency.sh`
  — the end-to-end invocation is sufficient for this scope.
- **NG-3** Revising `spec/protocol/role-contracts.md` or other
  protocol docs to fully excise the "extensions" concept — the
  skill-level hint cleanup (R5) is the only prose change.
- **NG-4** Touching `.harness/history/**` references — archived,
  immutable.
- **NG-5** Re-opening or amending `promote-java-artifacts`
  retrospective — already closed.

## 6. Acceptance Criteria

### AC-1 Directory deleted

- [ ] [manual] `ls spec/extensions` returns "No such file or
      directory" (or equivalent non-existence signal). Covers R1.

### AC-2 README clean

- [ ] [unit] `grep -E "extensions|java-backend-strict" spec/README.md`
      returns zero lines. Covers R2.

### AC-3 Consistency checker dead code removed

- [ ] [unit] `grep -E "legacy_(escalation|decisions|codebase_map)_template"
      spec/bootstrap/commands/check-consistency.sh` returns zero lines.
      Covers R3.
- [ ] [unit] `grep -F "spec/extensions/java-backend-strict"
      spec/bootstrap/commands/check-consistency.sh` returns zero lines.
      Covers R3.

### AC-4 Skill stale doc cleaned

- [ ] [unit] `grep -F "extensions may replace this layer"
      skills/baton-evaluator/SKILL.md` returns zero lines. Covers R5.

### AC-5 End-to-end consistency passes

- [ ] [integration] `bash spec/bootstrap/commands/check-consistency.sh`
      exits 0, and stdout contains `OK: invariant-14`, `OK: invariant-17`,
      `OK: invariant-18` among the reported OK lines. Covers R4, R6.

### AC-6 Full-repo live-reference sweep clean

- [ ] [integration] `grep -rE "spec/extensions|java-backend-strict" .
      --exclude-dir=.harness --exclude-dir=docs --exclude-dir=.tmp
      --exclude-dir=.git --exclude-dir=node_modules` returns zero
      lines. Any match is a latent reference the task missed.
      Covers completeness of R1/R2/R3/R5.

### AC-7 Regression guard (conditional on R7)

- [ ] [unit] (only applies if architect adopts R7) `grep -F
      "spec/extensions" spec/bootstrap/commands/check-consistency.sh`
      returns exactly the one line asserting `[[ ! -d spec/extensions ]]`
      — no other mentions. Covers R7.

## 7. Constraints

- **C1 (true)**: `check-consistency.sh` must keep exit 0 at all times
  on master — any invariant break blocks downstream tasks.
- **C2 (true)**: Edits to `check-consistency.sh` must use unique
  per-hunk context (no sed-based sweeps, no `replace_all` on
  `legacy_` or bare invariant numbers). Inherited from
  `knowledge/lessons.md` — "Python str.replace substring-matches
  across markdown heading levels"; the same substring-matching risk
  applies to `legacy_` bash prefixes, which appear many times in
  this file.
- **C3 (true)**: Phase 5 Verify and Phase 7 Review MUST run in strict
  isolation (baton-verifier / baton-evaluator via Agent dispatch) —
  non-negotiable per `knowledge/lessons.md` — "'Low-risk' is not a
  license to skip strict isolation in a repo that dogfoods strict".
  The inline-explorer exception taken in Phase 2 does not extend to
  verification or evaluation phases.

## 8. Validation Intent

- **Primary**: `bash spec/bootstrap/commands/check-consistency.sh`
  end-to-end exit 0. This is the one command that proves the
  migration guardrails still cover what matters (positive halves of
  invariants 14/17/18) and no unrelated invariant broke.
- **Secondary**: targeted grep sweeps for each AC (AC-1 through
  AC-6) to prove each live reference is gone.
- **Tertiary**: `bash spec/bootstrap/commands/validate-artifact.sh`
  for all `.harness/*.md` artifacts to confirm the task's own
  artifacts stay schema-clean.
- Phase 5 Verify will codify exact commands in `verification.md`;
  Phase 7 Evaluator will execute them in strict isolation per C3.

## 9. Traceability

No `clarification-brief.md` exists (Phase 0 triage established the
request was Clear-to-Partial and went directly to Phase 2 Explore).
Traceability between `exploration.md` and this document:

| Exploration §9 Unit | Requirement | Acceptance Criterion |
|---------------------|-------------|---------------------|
| U1: `rm -rf spec/extensions/` | R1 | AC-1 |
| U2: `spec/README.md` refs | R2 | AC-2 |
| U3: `check-consistency.sh` dead code | R3, R4 | AC-3, AC-5 |
| U4: `baton-evaluator` SKILL.md:210 | R5 | AC-4 |
| (end-to-end sweep) | R6 | AC-5, AC-6 |
| (architect-gated Q1) | R7 | AC-7 (conditional) |

Exploration §8 risk 1 (regression guard gap) → R7/AC-7 as
architect-gated option. Exploration §8 risk 2 (docs drift) →
NG-1 with retrospective flag. Exploration §8 risk 3 (skill
semantic shift) → R5 + assumption A5.

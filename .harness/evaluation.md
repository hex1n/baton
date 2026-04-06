# Evaluation: remove-spec-extensions

**Owner**: `evaluator`
**Status**: `complete`

## 1. Inputs

- Requirements: `.harness/requirements.md` (7 acceptance criteria, R1-R7)
- Architecture: `.harness/architecture.md` (Category A bundle, 5 units U1-U5)
- Verification path: `.harness/verification.md` (7 AC commands + artifact validation)
- Diff / changed files: `git diff -- spec/extensions/ spec/README.md spec/bootstrap/commands/check-consistency.sh skills/baton-evaluator/SKILL.md` (unstaged working tree changes scoped to write surface)

## 2. Execution Provenance

- Role: evaluator
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: (recorded by orchestrator at dispatch time)
- Evidence: cold-read of `.harness/requirements.md`, `.harness/architecture.md`, `.harness/verification.md`, `.harness/exploration.md`, `.harness/task-status.md`; scoped `git diff` of write surface files; executed all 7 AC verification commands independently; read `spec/README.md` (lines 10-19, 108-149, 173-192), `spec/bootstrap/commands/check-consistency.sh` (lines 14-28, 460-490, 630-660, 678-736), `skills/baton-evaluator/SKILL.md` (lines 205-214)
- Fallback policy: strict mode -- no sequential fallback permitted
- Fallback reason: N/A (strict mode; no fallback taken)
- Verdict: PASS WITH WARNINGS

**WARNING**: `base_commit` is missing from `task-status.md` State Notes. Diff was obtained via `git diff -- <write surface>` against unstaged working tree changes, which is valid because the implementation exists as uncommitted modifications.

## 3. Findings

### Layer 1: Deterministic Checks

All verification commands from `verification.md` Section 2 were executed. Results:

| AC | Command | Result | Status |
|----|---------|--------|--------|
| AC-1 | `ls spec/extensions 2>&1` | "No such file or directory", exit 2 | PASS |
| AC-2 | `grep -E "extensions\|java-backend-strict" spec/README.md` | zero lines, exit 1 | PASS |
| AC-3a | `grep -E "legacy_(escalation\|decisions\|codebase_map)_template" ...check-consistency.sh` | zero lines, exit 1 | PASS |
| AC-3b | `grep -F "spec/extensions/java-backend-strict" ...check-consistency.sh` | zero lines, exit 1 | PASS |
| AC-4 | `grep -F "extensions may replace this layer" skills/baton-evaluator/SKILL.md` | zero lines, exit 1 | PASS |
| AC-5 | `bash spec/bootstrap/commands/check-consistency.sh` | OK: invariant-14, OK: invariant-18, OK: invariant-19; 7 pre-existing errors (inv-4 x2, inv-16 x4, inv-17 x1); no new errors | PASS (per recommended interpretation in verification.md) |
| AC-6 | `grep -rE "spec/extensions\|java-backend-strict" . --exclude-dir=...` | 4 lines, all from invariant-19 block in check-consistency.sh (the regression guard itself) | PASS |
| AC-7 | `grep -F "spec/extensions" ...check-consistency.sh` | 4 lines, all from invariant-19 assertion block | PASS |

Hard failures: none.

### Layer 2: Diff Review

**Scope validation**: The diff touches exactly the 4 files (3 modified + 7 deleted) listed in architecture.md Section 4 Surface Scan as L1 targets. No files outside the approved write surface were modified. Scope matches perfectly.

**Architecture conformance**: All 5 units match the architecture:
- U1: 7 files deleted under `spec/extensions/java-backend-strict/` -- matches
- U2: 3 regions removed from `spec/README.md` (line 17 bullet, lines 136-149 tree block, lines 198-201 link bullet) -- matches
- U3: 3 legacy variable definitions and 3 if-block guards removed from `check-consistency.sh` -- matches. Each if-block was 4 lines (if/printf/increment/fi), consistent with verification.md line-number verification note.
- U4: Parenthetical "(extensions may replace this layer)" removed from `skills/baton-evaluator/SKILL.md:210` -- matches
- U5: invariant-19 block added (12 lines) at the end of `check-consistency.sh` before the Summary section -- matches

**Unexpected changes**: None. All changes are within the approved write surface.

**Bug patterns**: None found. The invariant-19 block follows the exact same pattern as invariants 14/17/18 (error counter, conditional check, printf, OK message, error accumulation).

**Security**: No security concerns. This is a pure file deletion and dead-code removal task.

**Pattern consistency**: The new invariant-19 block follows the existing codebase convention for check-consistency.sh invariants (comment banner, error counter, conditional, printf, OK line, error aggregation).

**Test quality**: No new tests were required (per A4 and NG-2). The end-to-end `check-consistency.sh` invocation serves as the functional gate.

**Dependency audit**: No new dependencies added.

**Risk area coverage** (cross-reference with exploration.md Section 8):
- Risk 1 (regression guard gap): addressed by U5/invariant-19
- Risk 2 (docs drift): accepted per NG-1, out of scope
- Risk 3 (skill semantic shift): addressed by U4, sentence remains grammatical

**Cosmetic observations**:
- Double blank lines at check-consistency.sh lines 469-470 and 639-640 where if-blocks were removed. The existing style uses single blank lines between blocks. Non-blocking.
- `spec/README.md` line 141 still says "add the matching extension overlay" (singular "extension") -- a generic concept reference that does not match the AC-2 pattern but refers to a concept whose concrete implementation was just removed. This is informational only; the requirements targeted "extensions" (plural) and "java-backend-strict" specifically.

### Layer 3: Requirements Verification

**Blockers**: none

**Warnings**:
1. (Minor) Double blank lines at two points in `check-consistency.sh` where dead code was removed. Cosmetic only.
2. (Informational) `spec/README.md` line 141 still references "extension overlay" as a generic concept. The specific directory and path references are all gone per AC-2, but a reader might be confused by the mention of "extension overlay" when no such thing exists in the repo. Not a blocker because it is outside the requirements scope (R2 targeted `extensions` plural and `java-backend-strict`).

**No findings**: All acceptance criteria are met.

## 4. Verification Results

### Layer 1: Deterministic Results

All 7 AC commands executed successfully. See Layer 1 table above for details. `check-consistency.sh` reports 7 pre-existing errors (all unrelated to this task), with OK lines for invariant-14, invariant-18, and invariant-19. invariant-17 has a pre-existing failure (`Why\|` pattern missing from validate-artifact.sh) documented in verification.md as outside this task's scope.

### Layer 2: Review Results

- Scope match: exact match between diff and approved write surface
- Architecture conformance: all 5 units implemented as designed
- Issues found: 2 cosmetic observations (double blank lines, singular "extension" reference) -- neither affects correctness

### Layer 3: Acceptance Criteria

- [x] AC-1 Directory deleted -- `ls spec/extensions` returns exit 2, "No such file or directory". Covers R1.
- [x] AC-2 README clean -- `grep -E "extensions|java-backend-strict" spec/README.md` returns exit 1, zero lines. Covers R2.
- [x] AC-3 Consistency checker dead code removed -- both grep commands return exit 1, zero lines. Covers R3.
- [x] AC-4 Skill stale doc cleaned -- `grep -F "extensions may replace this layer" skills/baton-evaluator/SKILL.md` returns exit 1, zero lines. Covers R5.
- [x] AC-5 End-to-end consistency passes -- `check-consistency.sh` reports OK for invariant-14, invariant-18, invariant-19; 7 pre-existing errors unchanged; no new errors introduced. Covers R4, R6.
- [x] AC-6 Full-repo live-reference sweep clean -- only matches are from the invariant-19 regression guard itself (expected). Covers completeness of R1/R2/R3/R5.
- [x] AC-7 Regression guard -- `grep -F "spec/extensions" check-consistency.sh` returns exactly the invariant-19 assertion lines. Covers R7.

## 5. Verdict

**Verdict: PASS WITH WARNINGS**

All 7 acceptance criteria are met with concrete evidence. Two minor warnings documented:
1. Cosmetic double blank lines in `check-consistency.sh` at removal points
2. Singular "extension overlay" concept reference remains in `spec/README.md` line 141 (outside requirements scope)

Neither warning threatens correctness. The implementation is complete and safe.

## 6. Residual Risks

- **R-R3 (accepted)**: `docs/*.md` (5 files) still reference the overlay -- accepted per user scope decision (NG-1). Flagged for retrospective.
- **R-R4 (mitigated)**: Future re-creation of `spec/extensions/` is now guarded by invariant-19.
- **Singular "extension" concept**: `spec/README.md` lines 26 and 141 use "extension" (singular) as a generic concept. If the extension mechanism is fully deprecated at the protocol level in the future, these references should be cleaned up. Not a risk for this task.

## 7. Human Judgment Notes

> Populated during Gate 5 review. Not machine-editable.
> Space for the reviewer's tacit signals -- intuitions, pattern recalls,
> or concerns that resist full articulation.

- <human annotation, if any>

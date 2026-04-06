# Verification Path: remove-spec-extensions

**Owner**: `verification-explorer`
**Status**: `final`

## 1. Intended Checks

- **Build**: not applicable (no compiled code; shell scripts only)
- **Tests**: `bash spec/bootstrap/commands/check-consistency.sh` -- end-to-end
  consistency checker; this is the primary functional gate (covers R4, R6)
- **Static checks**:
  - AC-1: `ls spec/extensions` must fail (R1)
  - AC-2: `grep` for extensions/java-backend-strict in spec/README.md must
    return zero lines (R2)
  - AC-3: `grep` for legacy variable names and extension paths in
    check-consistency.sh must return zero lines (R3)
  - AC-4: `grep` for stale parenthetical in baton-evaluator/SKILL.md must
    return zero lines (R5)
  - AC-6: repo-wide sweep for any remaining live references (completeness
    of R1/R2/R3/R5)
  - AC-7: `grep` for new invariant-19 assertion (R7, conditional -- adopted
    per architecture decision)
- **Runtime/manual checks**: none required
- **Artifact validation**: `validate-artifact.sh` for requirements.md and
  architecture.md

## 2. Exact Commands

### AC-1: Directory deleted (R1)

```bash
ls spec/extensions 2>&1
# Expected: "ls: spec/extensions: No such file or directory" (or equivalent)
# Expected exit code: non-zero (2)
```

### AC-2: README clean (R2)

```bash
grep -E "extensions|java-backend-strict" spec/README.md
# Expected: zero lines (exit code 1)
```

### AC-3: Consistency checker dead code removed (R3)

```bash
grep -E "legacy_(escalation|decisions|codebase_map)_template" spec/bootstrap/commands/check-consistency.sh
# Expected: zero lines (exit code 1)

grep -F "spec/extensions/java-backend-strict" spec/bootstrap/commands/check-consistency.sh
# Expected: zero lines (exit code 1)
```

### AC-4: Skill stale doc cleaned (R5)

```bash
grep -F "extensions may replace this layer" skills/baton-evaluator/SKILL.md
# Expected: zero lines (exit code 1)
```

### AC-5: End-to-end consistency passes (R4, R6)

```bash
bash spec/bootstrap/commands/check-consistency.sh 2>&1
# Expected: stdout contains "OK: invariant-14" and "OK: invariant-18"
# Expected: stdout contains "OK: invariant-19" (new regression guard)
#
# CAVEAT: invariant-17 has a pre-existing failure (Why\| pattern missing
# from validate-artifact.sh) that prevents "OK: invariant-17" from appearing.
# This failure is NOT caused by this task. See Blockers section for details.
#
# Primary success criterion: the output contains OK lines for invariant-14
# and invariant-18, and the total error count does not increase from the
# pre-existing baseline of 7 errors.
#
# Full exit-0 criterion: check-consistency.sh currently exits 1 due to
# 7 pre-existing errors (invariant-4 x2, invariant-16 x4, invariant-17 x1).
# These are all unrelated to this task. The task MUST NOT introduce new
# errors. If pre-existing errors are coincidentally fixed by the time the
# evaluator runs, exit 0 is expected.
```

### AC-6: Full-repo live-reference sweep (completeness)

```bash
grep -rE "spec/extensions|java-backend-strict" . \
  --exclude-dir=.harness --exclude-dir=docs --exclude-dir=.tmp \
  --exclude-dir=.git --exclude-dir=node_modules
# Expected: zero lines (exit code 1)
```

### AC-7: Regression guard (R7)

```bash
grep -F "spec/extensions" spec/bootstrap/commands/check-consistency.sh
# Expected: exactly one line containing [[ ! -d ... spec/extensions ]]
# No other mentions of spec/extensions should remain
```

### Artifact validation (tertiary)

```bash
bash spec/bootstrap/commands/validate-artifact.sh requirements .harness/requirements.md
# Expected: exit 0, no output

bash spec/bootstrap/commands/validate-artifact.sh architecture .harness/architecture.md
# Expected: exit 0, no output
```

## 3. Prerequisites

- **Toolchain**: bash (present), grep (present), ls (present). No build
  tools required -- this is a pure file-deletion and text-editing task.
- **Services**: none
- **Fixtures**: none
- **Environment variables**: none
- **Test data**: none
- **Test runner**: `check-consistency.sh` is the test runner; it is present
  and executable at `spec/bootstrap/commands/check-consistency.sh`.
- **Test config**: the script is self-contained; no external config needed.
- **CI config**: `.github/workflows/` does not exist in this repo. No CI
  pipeline to cross-reference.
- **Dependencies installed**: not applicable (no package manager dependencies).

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: (recorded by orchestrator at dispatch time)
- Evidence: cold-read of `.harness/requirements.md`, `.harness/architecture.md`,
  `.harness/task-status.md`, `spec/README.md`,
  `spec/bootstrap/commands/check-consistency.sh` (lines 0-50, 460-490,
  635-665, 688-737), `skills/baton-evaluator/SKILL.md` (line 210).
  Dry-ran `check-consistency.sh`, `validate-artifact.sh`, and all 7 AC
  grep/ls commands against the current repo state.
- Fallback policy: strict mode -- no sequential fallback permitted. If
  isolated subagent dispatch fails, the task is blocked.
- Fallback reason: N/A (strict mode; no fallback taken)

## 5. Dry-Run Result

### check-consistency.sh baseline

- Command: `bash spec/bootstrap/commands/check-consistency.sh`
- Result: exit 1, 7 pre-existing errors
- Passing invariants relevant to this task:
  - `OK: invariant-14: escalation contract stays synchronized across schema, validator, templates, and skills`
  - `OK: invariant-18: codebase-map.md contract stays synchronized across schema, validator, templates, and skills`
- Pre-existing failures (all unrelated to this task):
  - `ERROR: invariant-4: baton-clarifier/SKILL.md missing from .agents/`
  - `ERROR: invariant-4: baton-orchestrator/SKILL.md missing from .agents/`
  - `ERROR: invariant-16: Codex PostToolUse drifted from install-hooks manifest`
  - `ERROR: invariant-16: Codex PreToolUse drifted from install-hooks manifest`
  - `ERROR: invariant-16: Codex Stop drifted from install-hooks manifest`
  - `ERROR: invariant-16: Codex SessionStart drifted from install-hooks manifest`
  - `ERROR: invariant-17: validate-artifact.sh decisions case missing field check for Why\|`
- Notes: invariant-17 fails because `validate-artifact.sh` lacks a `Why|`
  pattern check. This pre-dates the current task. The legacy-decisions-template
  guard (the one we are removing) would have been checked only if inv17 reached
  that code path -- it does, and the guard currently evaluates to false (the
  legacy file exists so the `[[ -e ... ]]` check passes without error). After
  removal of the guard AND the directory, the invariant-17 result will remain
  ERROR for the same pre-existing `Why\|` reason, not for any reason introduced
  by this task.

### validate-artifact.sh baseline

- Command: `bash spec/bootstrap/commands/validate-artifact.sh requirements .harness/requirements.md`
- Result: exit 0, no output (pass)
- Command: `bash spec/bootstrap/commands/validate-artifact.sh architecture .harness/architecture.md`
- Result: exit 0, no output (pass)

### AC baseline checks

| AC | Command | Baseline Result | Post-Task Expected |
|----|---------|----------------|-------------------|
| AC-1 | `ls spec/extensions` | exits 0, lists `java-backend-strict` | exits non-zero, "No such file or directory" |
| AC-2 | `grep -E "extensions\|java-backend-strict" spec/README.md` | 4 lines matched | exit 1, zero lines |
| AC-3a | `grep -E "legacy_(escalation\|decisions\|codebase_map)_template" ...check-consistency.sh` | 9 lines matched | exit 1, zero lines |
| AC-3b | `grep -F "spec/extensions/java-backend-strict" ...check-consistency.sh` | 3 lines matched | exit 1, zero lines |
| AC-4 | `grep -F "extensions may replace this layer" ...SKILL.md` | 1 line matched | exit 1, zero lines |
| AC-6 | `grep -rE "spec/extensions\|java-backend-strict" . --exclude-dir=...` | 5 lines matched (3 in check-consistency.sh, 2 in README) | exit 1, zero lines |
| AC-7 | `grep -F "spec/extensions" ...check-consistency.sh` | 3 lines matched (variable defs) | exactly 1 line (new invariant-19 assertion) |

### Line number verification

Architecture claims were verified against the actual file content:
- `check-consistency.sh` line 19 (0-indexed): `legacy_escalation_template=...` -- confirmed
- `check-consistency.sh` line 22 (0-indexed): `legacy_decisions_template=...` -- confirmed
- `check-consistency.sh` line 23 (0-indexed): `legacy_codebase_map_template=...` -- confirmed
- `check-consistency.sh` lines 473-476: if-block for legacy escalation template -- confirmed (4 lines: if/printf/increment/fi, not 2 as architecture states)
- `check-consistency.sh` lines 647-650: if-block for legacy decisions template -- confirmed (4 lines)
- `check-consistency.sh` lines 700-703: if-block for legacy codebase-map template -- confirmed (4 lines)
- `spec/README.md` line 17: `- extensions/: stack-specific stricter overlays` -- confirmed
- `spec/README.md` lines 136-137: `extensions/` and `java-backend-strict/` in tree diagram -- confirmed (actual content at lines 136-149 in 1-indexed; the tree sub-block is larger than 2 lines)
- `spec/README.md` line 201: `- [java-backend-strict/README.md]...` -- confirmed
- `skills/baton-evaluator/SKILL.md` line 210: `(extensions may replace this layer)` -- confirmed

Architecture inaccuracy (non-blocking): the if-blocks in check-consistency.sh
are 4 lines each (if, printf, increment, fi), not 2 lines. This does not
affect generation because the Generator will use the actual file content for
Edit `old_string` matching. The architecture's description of "3 if-block
guards" and their line locations is correct.

## 6. Blockers

### Pre-existing: AC-5 literal reading cannot pass

- **Category**: `scope_clarification` (not a blocker for generation)
- **Detail**: AC-5 as written requires `check-consistency.sh` to exit 0 and
  stdout to contain `OK: invariant-17`. Due to 7 pre-existing errors
  (invariant-4 x2, invariant-16 x4, invariant-17 x1), the script exits 1
  and never prints `OK: invariant-17`. None of these errors are caused by
  `spec/extensions/` or the code this task removes.
- **Recommended interpretation**: AC-5 passes if:
  1. The output contains `OK: invariant-14` (confirmed achievable)
  2. The output contains `OK: invariant-18` (confirmed achievable)
  3. The output contains `OK: invariant-19` (achievable after U5)
  4. The total error count does not increase from the 7-error baseline
  5. No new invariant error mentions `spec/extensions`, `java-backend-strict`,
     or any `legacy_*_template` variable
- **Action needed**: none -- the evaluator should use the recommended
  interpretation above. The literal "exit 0" + "OK: invariant-17" parts of
  AC-5 are blocked by pre-existing issues outside this task's scope.

### No generation blockers

No issues were found that would prevent the Generator from implementing the
5 units described in the architecture. All target files are present, readable,
and contain the exact content described.

## 7. Fallbacks

### If check-consistency.sh becomes unreliable

- Run each AC command (AC-1 through AC-4, AC-6, AC-7) independently as the
  full verification suite. These grep/ls commands collectively cover every
  requirement without depending on the consistency checker.

### If the Edit tool fails to match a hunk in check-consistency.sh

- Read the surrounding 20-line window of the target hunk
- Adjust the `old_string` to include more unique context
- This is the most likely operational failure (architecture risk R-R2) and
  is recoverable by the Generator without escalation

### If spec/extensions/ has already been deleted by another change

- AC-1 passes trivially
- U1 (`rm -rf`) is a no-op
- All other units proceed unchanged
- U5 (invariant-19) assertion will pass immediately

### If the repo build is already broken

- Not applicable -- no build step. The only "build" equivalent is
  `check-consistency.sh`, which has pre-existing failures documented above.

### If the test runner is unavailable

- `check-consistency.sh` is a bash script with no external dependencies
  beyond grep, bash, and standard Unix tools. If bash is unavailable,
  the entire harness is non-functional and the task is blocked at the
  environment level.

## CI Compatibility

No CI configuration exists in this repository (no `.github/workflows/`,
`.gitlab-ci.yml`, or `Jenkinsfile`). All validation is local-only. No
CI compatibility gaps to document.

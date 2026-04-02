# Runtime Enforcement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add runtime enforcement to the baton harness — artifact validation, state transition checks, structured eval_round tracking, and auto-installed Claude Code hooks — closing the gap between what the protocol specifies and what the runtime enforces.

**Architecture:** Three scripts (`validate-artifact.sh`, `validate-transition.sh`, `install-hooks.sh`) handle logic; platform hooks in `.claude/settings.json` trigger them automatically on artifact writes. Skill edits (P0) close documentation-level gaps in isolation contracts and architect rejection paths. The eval_round column moves repair-round tracking from free-text notes into the task-status table, making it machine-readable.

**Tech Stack:** Bash, `jq` (hook stdin parsing), Claude Code settings.json hooks (PostToolUse / PreToolUse), markdown section matching.

**Key constraint:** `.harness/` artifacts are NOT git-managed. All enforcement is via tool-use hooks, not git hooks.

**Pre-flight check:** Before starting, verify `check-consistency.sh` passes (all 7 invariants) and `jq` is available (`jq --version`).

---

## Task 1: P0-1 — Isolation self-check in baton-evaluator

**Files:**
- Modify: `skills/baton-evaluator.md:20-27` (Startup section)

**Step 1: Add self-check assertion after the "Load these artifacts" list**

In `skills/baton-evaluator.md`, after the four `Read .harness/...` lines (line ~27), add:

```markdown
## Isolation Self-Check

Before proceeding, verify you are running in a fresh context:

- If you can recall Generator output, code diffs, or implementation
  decisions from earlier in this conversation, **STOP**.
- You are NOT in a fresh context. Context inheritance defeats the
  purpose of independent evaluation.
- Instruct the orchestrator to re-dispatch via `Agent` tool
  (not `Skill` tool) and restart from a blank session.

If you loaded the artifacts above and have no prior conversation
history, proceed.
```

**Step 2: Verify the section appears in the right place**

Read `skills/baton-evaluator.md` and confirm the self-check section is between "Startup" and "Claude Code Execution Note". No logic changes; only the documentation contract is tightened.

**Step 3: Commit**

```bash
git add skills/baton-evaluator.md
git commit -m "feat(evaluator): add isolation self-check assertion at startup"
```

---

## Task 2: P0-1 — Isolation self-check in baton-verifier

**Files:**
- Modify: `skills/baton-verifier.md:17-29` (Startup section)

**Step 1: Add identical self-check block**

In `skills/baton-verifier.md`, after the three `Read .harness/...` lines and "Do not inherit..." note (line ~29), add the same self-check block:

```markdown
## Isolation Self-Check

Before proceeding, verify you are running in a fresh context:

- If you can recall Architect or Specifier reasoning, decisions,
  or design discussions from earlier in this conversation, **STOP**.
- You are NOT in a fresh context. Inherited reasoning defeats the
  purpose of independent verification path discovery.
- Instruct the orchestrator to re-dispatch via `Agent` tool
  (not `Skill` tool) and restart from a blank session.

If you loaded the artifacts above and have no prior conversation
history, proceed.
```

**Step 2: Verify placement**

Confirm self-check is between "Startup" and "Claude Code Execution Note". Confirm `context: fork` is still in frontmatter.

**Step 3: Commit**

```bash
git add skills/baton-verifier.md
git commit -m "feat(verifier): add isolation self-check assertion at startup"
```

---

## Task 3: P0-1 — Claude Code isolation invariant note

**Files:**
- Modify: `spec/adapters/claude-code.md:59-70` (Context Isolation section)

**Step 1: Add Invariant paragraph**

After the existing "In Claude Code, use the `Agent` tool to dispatch these roles..." paragraph (line ~69), add:

```markdown
### Isolation Invariant

Context isolation responsibility belongs to the **orchestrator** (caller),
not the invoked skill.

- The skill declares isolation intent via `context: fork` frontmatter.
- The orchestrator is responsible for dispatching via `Agent` tool.
- Using the `Skill` tool to invoke an isolated role is a protocol
  violation — it executes inline and shares conversation context.
- If an isolated role's Isolation Self-Check fires, the orchestrator
  MUST re-dispatch via `Agent` tool before the role can proceed.
```

**Step 2: Verify**

Read the updated file. Confirm the invariant appears in the Context Isolation section, after the dispatch examples.

**Step 3: Commit**

```bash
git add spec/adapters/claude-code.md
git commit -m "feat(claude-code-adapter): add isolation invariant — responsibility is orchestrator's"
```

---

## Task 4: P0-2 — Architect rejection path (requirements misunderstood)

**Files:**
- Modify: `skills/baton-architect.md:146-154` (Human Feedback Handling section)

**Step 1: Expand the "Rejected — requirements misunderstood" branch**

Find the existing branch (currently 2 lines). Replace with:

```markdown
**Rejected — requirements misunderstood**

1. Write `task-status.md` → state `blocked`, category `design_blocker`.
   Notes: name the specific requirement that is ambiguous or contradictory.

2. Write `.harness/generator-feedback.md` with these fields:
   - **Original assumption**: what `architecture.md` assumed about the requirement
   - **Actual finding**: why that assumption cannot be satisfied as-is
   - **Impact on implementation**: what breaks if proceeding without clarity
   - **Recommended next owner**: `specifier`

3. Stop. Do not re-attempt architecture.

Specifier entry condition: when `generator-feedback.md` exists and
`recommended_next_owner` is `specifier`, resolve the ambiguity in
`requirements.md` before architecture resumes. Architect will then
re-read both files and restart from Step 2 (First-Principles Decomposition).
```

**Step 2: Verify**

Read the updated Human Feedback Handling section. Confirm all four feedback branches (Approved / Partial revision / Rejected direction / Rejected misunderstood) are present and complete.

**Step 3: Commit**

```bash
git add skills/baton-architect.md
git commit -m "feat(architect): complete rejection path — write generator-feedback.md on requirements misunderstood"
```

---

## Task 5: P1-3 — Add eval_round column to task-status template

**Files:**
- Modify: `spec/templates/task-status.template.md`
- Modify: `spec/bootstrap/start-task.sh`
- Modify: `spec/bootstrap/start-task.ps1`

**Step 1: Update the template**

In `spec/templates/task-status.template.md`, change lines 3-4 to:

```markdown
| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| <task-id> | <role> | <state> | 0 | <timestamp> | <notes> |
```

**Step 2: Update start-task.sh header**

In `spec/bootstrap/start-task.sh`:

Line 256 — update the header check:
```bash
if [[ "$line" == '| Scope | Owner | State | Eval Round | Updated At | Notes |' ]]; then
```

Lines 371-372 — update the printf:
```bash
printf '| Scope | Owner | State | Eval Round | Updated At | Notes |\n'
printf '|------|------|------|-----------|-----------|------|\n'
```

Find the line that writes the new task row (near line 383, the row with `$task_id`) and add `| 0 |` after the state column:
```bash
printf '| %s | %s | %s | 0 | %s | %s |\n' "$task_id" "$owner" "$state" "$timestamp" "$notes"
```

(Read lines 370-395 of start-task.sh first to locate the exact printf.)

**Step 3: Update start-task.ps1**

In `spec/bootstrap/start-task.ps1`:

Line 334: update header string:
```powershell
"| Scope | Owner | State | Eval Round | Updated At | Notes |"
```

Line 339: update row construction to include `0` for Eval Round:
```powershell
$moduleStatusContent += "| $($row.Scope) | $($row.Owner) | $($row.State) | 0 | $($row.UpdatedAt) | $($row.Notes) |"
```

Also find where the PowerShell parses existing rows (near line 36, where it splits by `|`) — add `EvalRound` as a parsed field:
```powershell
EvalRound = if ($parts.Count -ge 7) { $parts[4].Trim() } else { "0" }
```
(Read lines 30-60 of start-task.ps1 to see the exact parsing structure.)

**Step 4: Verify invariant 3 still passes**

```bash
bash spec/bootstrap/check-consistency.sh
```

Expected: `OK: invariant-3: template header matches start-task.sh header`

**Step 5: Commit**

```bash
git add spec/templates/task-status.template.md spec/bootstrap/start-task.sh spec/bootstrap/start-task.ps1
git commit -m "feat(task-status): add Eval Round column to task table — structured repair-round tracking"
```

---

## Task 6: P1-3 — Update evaluator + status skills to use the Eval Round column

**Files:**
- Modify: `skills/baton-evaluator.md:177-179` (State Transition section)
- Modify: `skills/baton-status.md:35-36` (Eval round display)

**Step 1: Update evaluator's eval_round increment instruction**

In `skills/baton-evaluator.md`, find the State Transition section at the bottom. Replace the eval_round increment line:

Before:
```
Increment the eval round counter in the State Notes section of `task-status.md` (format: `Current eval round: N`).
```

After:
```
Increment the `Eval Round` column in the task table row (not in State Notes).
Read the current value, add 1, write it back as a plain integer.
```

**Step 2: Update status skill's eval_round read instruction**

In `skills/baton-status.md`, find the "Eval round" line in Execution Steps step 3. Update:

Before:
```
- **Eval round** — if in the repair loop, show `round N / 3`
```

After:
```
- **Eval round** — read the `Eval Round` column from the task table row.
  If state is `reviewing`, `generating` (repair), or `blocked` from evaluator,
  show `round N / 3`. If N ≥ 3, flag for human escalation.
```

**Step 3: Verify**

Read both files and confirm:
- Evaluator no longer mentions "State Notes" for eval_round
- Status reads from the table column

**Step 4: Commit**

```bash
git add skills/baton-evaluator.md skills/baton-status.md
git commit -m "feat(evaluator,status): eval_round reads/writes table column — removes free-text parsing"
```

---

## Task 7: P1-1 — Create validate-artifact.sh

**Files:**
- Create: `spec/bootstrap/validate-artifact.sh`
- Create: `tests/test-validate-artifact.sh`

**Step 1: Write the failing test first**

Create `tests/test-validate-artifact.sh`:

```bash
#!/usr/bin/env bash
# Tests for validate-artifact.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../spec/bootstrap/validate-artifact.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# -- scoped-map: complete artifact passes --
cat > "$tmp/scoped-map.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
## 3. Call Chain
content
## 4. Existing Behavior
content
## 5. Existing Tests
content
## 6. Dependency / Risk Scan
content
## 7. Change Shape
content
## 9. Recommendation
content
EOF
assert_exit "scoped-map complete → exit 0" 0 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map.md"

# -- scoped-map: missing section fails --
cat > "$tmp/scoped-map-bad.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
EOF
assert_exit "scoped-map missing sections → exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map-bad.md"

# -- requirements: complete passes --
cat > "$tmp/requirements.md" <<'EOF'
# Requirements: test-task
## 1. Problem
content
## 2. Scope
content
## 3. Functional Requirements
content
## 4. Non-Goals
content
## 5. Acceptance Criteria
content
## 6. Constraints
content
## 7. Validation Intent
content
EOF
assert_exit "requirements complete → exit 0" 0 bash "$VALIDATE" "requirements" "$tmp/requirements.md"

# -- unknown artifact type → exit 0 (skip, not error) --
assert_exit "unknown artifact type → exit 0 (skip)" 0 bash "$VALIDATE" "unknown-type" "$tmp/requirements.md"

# -- file not found → exit 1 --
assert_exit "missing file → exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/nonexistent.md"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**Step 2: Run test — confirm it fails**

```bash
bash tests/test-validate-artifact.sh
```

Expected: `FAIL: scoped-map complete → exit 0` (script doesn't exist yet)

**Step 3: Create validate-artifact.sh**

Create `spec/bootstrap/validate-artifact.sh`:

```bash
#!/usr/bin/env bash
# validate-artifact.sh — verify a .harness/*.md artifact has all required sections
#
# Usage: validate-artifact.sh <artifact-type> <file-path>
#   artifact-type: scoped-map | requirements | architecture | verification-path | task-status
#   file-path:     path to the artifact file to validate
#
# Exit 0: artifact passes or type is unknown (skip)
# Exit 1: artifact fails — missing required sections, or file not found
set -euo pipefail

artifact_type="${1:-}"
file_path="${2:-}"

if [[ -z "$artifact_type" || -z "$file_path" ]]; then
  printf 'Usage: validate-artifact.sh <artifact-type> <file-path>\n' >&2
  exit 1
fi

if [[ ! -f "$file_path" ]]; then
  printf 'ERROR: validate-artifact: file not found: %s\n' "$file_path" >&2
  exit 1
fi

# Section patterns: grep-compatible strings that must appear in the file.
# Using case-insensitive matching; numbers and punctuation are stripped.
has_section() {
  local file="$1" pattern="$2"
  grep -qiE "^##[[:space:]].*${pattern}" "$file"
}

check_sections() {
  local file="$1"
  shift
  local missing=0
  for pattern in "$@"; do
    if ! has_section "$file" "$pattern"; then
      printf 'ERROR: validate-artifact: missing section matching "%s" in %s\n' "$pattern" "$file" >&2
      missing=$((missing + 1))
    fi
  done
  return $missing
}

case "$artifact_type" in
  scoped-map)
    check_sections "$file_path" \
      "Scope" "Entry" "Call.Chain" "Existing.Behavior" \
      "Existing.Tests" "Risk" "Change.Shape" "Recommendation"
    ;;
  requirements)
    check_sections "$file_path" \
      "Problem" "Scope" "Functional.Requirements" "Non.Goals" \
      "Acceptance.Criteria" "Constraints" "Validation.Intent"
    ;;
  architecture)
    check_sections "$file_path" \
      "Problem.Framing" "First.Principles" "Recommended.Approach" \
      "Surface.Scan" "Verification.Strategy" "Risk" "Self.Challenge"
    ;;
  verification-path)
    check_sections "$file_path" \
      "Intended.Checks" "Commands" "Dependencies" \
      "Dry.Run" "Blockers" "Fallback"
    ;;
  task-status)
    # Module status must have the table header and state notes section
    check_sections "$file_path" "State.Notes"
    if ! grep -q "| Scope |" "$file_path"; then
      printf 'ERROR: validate-artifact: task-status missing task table in %s\n' "$file_path" >&2
      exit 1
    fi
    ;;
  *)
    # Unknown type: skip (exit 0) — do not error on future artifact types
    exit 0
    ;;
esac
```

**Step 4: Make executable**

```bash
chmod +x spec/bootstrap/validate-artifact.sh
```

**Step 5: Run test — confirm it passes**

```bash
bash tests/test-validate-artifact.sh
```

Expected: `Results: 5 passed, 0 failed of 5 total`

**Step 6: Commit**

```bash
git add spec/bootstrap/validate-artifact.sh tests/test-validate-artifact.sh
git commit -m "feat(bootstrap): validate-artifact.sh — check required sections in harness artifacts"
```

---

## Task 8: P1-2 — Create validate-transition.sh

**Files:**
- Create: `spec/bootstrap/validate-transition.sh`
- Create: `tests/test-validate-transition.sh`

**Step 1: Write the failing test first**

Create `tests/test-validate-transition.sh`:

```bash
#!/usr/bin/env bash
# Tests for validate-transition.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../spec/bootstrap/validate-transition.sh"
PASS=0; FAIL=0; TOTAL=0

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Legal transitions
assert_exit "exploring → specifying is legal"       0 bash "$VALIDATE" "exploring"           "specifying"
assert_exit "specifying → architecting is legal"    0 bash "$VALIDATE" "specifying"          "architecting"
assert_exit "generating → reviewing is legal"       0 bash "$VALIDATE" "generating"          "reviewing"
assert_exit "any → blocked is legal (wildcard)"     0 bash "$VALIDATE" "generating"          "blocked"
assert_exit "reviewing → blocked is legal"          0 bash "$VALIDATE" "reviewing"           "blocked"
assert_exit "blocked → architecting is legal"       0 bash "$VALIDATE" "blocked"             "architecting"

# Illegal transitions
assert_exit "exploring → generating is illegal"     1 bash "$VALIDATE" "exploring"           "generating"
assert_exit "complete → generating is illegal"      1 bash "$VALIDATE" "complete"            "generating"
assert_exit "specifying → reviewing is illegal"     1 bash "$VALIDATE" "specifying"          "reviewing"

# Same-state (no-op) is always legal
assert_exit "same state is legal"                   0 bash "$VALIDATE" "generating"          "generating"

# Unknown states → illegal
assert_exit "unknown from_state → illegal"          1 bash "$VALIDATE" "nonexistent_state"   "specifying"
assert_exit "unknown to_state → illegal"            1 bash "$VALIDATE" "exploring"           "nonexistent_state"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**Step 2: Run test — confirm it fails**

```bash
bash tests/test-validate-transition.sh
```

Expected: script not found / all FAILs.

**Step 3: Create validate-transition.sh**

Create `spec/bootstrap/validate-transition.sh`:

```bash
#!/usr/bin/env bash
# validate-transition.sh — check that a state transition is legal per state-machine.md
#
# Usage: validate-transition.sh <from_state> <to_state>
#
# Reads allowed transitions from spec/protocol/state-machine.md.
# Exit 0: transition is legal (or same-state no-op)
# Exit 1: transition is illegal or state is unknown
set -euo pipefail

from_state="${1:-}"
to_state="${2:-}"

if [[ -z "$from_state" || -z "$to_state" ]]; then
  printf 'Usage: validate-transition.sh <from_state> <to_state>\n' >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state_machine="$script_dir/../protocol/state-machine.md"
states_file="$script_dir/../protocol/states.txt"

if [[ ! -f "$state_machine" ]]; then
  printf 'ERROR: validate-transition: state-machine.md not found at %s\n' "$state_machine" >&2
  exit 1
fi

if [[ ! -f "$states_file" ]]; then
  printf 'ERROR: validate-transition: states.txt not found at %s\n' "$states_file" >&2
  exit 1
fi

# Same-state is always a no-op — legal.
if [[ "$from_state" == "$to_state" ]]; then
  exit 0
fi

# Validate that both states are known canonical states.
if ! grep -Fxq "$from_state" "$states_file"; then
  printf 'ERROR: validate-transition: unknown from_state "%s"\n' "$from_state" >&2
  exit 1
fi
if ! grep -Fxq "$to_state" "$states_file"; then
  printf 'ERROR: validate-transition: unknown to_state "%s"\n' "$to_state" >&2
  exit 1
fi

# "any -> blocked" is a wildcard: always legal.
if [[ "$to_state" == "blocked" ]]; then
  exit 0
fi

# Extract allowed transitions from state-machine.md.
# Lines in the "## Allowed Transitions" section that match "state -> state".
allowed="$(sed -n '/## Allowed Transitions/,/^## /p' "$state_machine" \
  | grep -E '^[a-z_]+ -> [a-z_]+$')"

if echo "$allowed" | grep -qE "^${from_state} -> ${to_state}$"; then
  exit 0
fi

printf 'ERROR: validate-transition: illegal transition "%s" -> "%s"\n' "$from_state" "$to_state" >&2
printf 'Allowed from "%s":\n' "$from_state" >&2
echo "$allowed" | grep -E "^${from_state} -> " >&2 || printf '  (none)\n' >&2
exit 1
```

**Step 4: Make executable**

```bash
chmod +x spec/bootstrap/validate-transition.sh
```

**Step 5: Run test — confirm it passes**

```bash
bash tests/test-validate-transition.sh
```

Expected: `Results: 11 passed, 0 failed of 11 total`

**Step 6: Commit**

```bash
git add spec/bootstrap/validate-transition.sh tests/test-validate-transition.sh
git commit -m "feat(bootstrap): validate-transition.sh — enforce legal state transitions from state-machine.md"
```

---

## Task 9: P1-4 — Create install-hooks.sh

**Files:**
- Create: `spec/bootstrap/install-hooks.sh`
- Create: `tests/test-install-hooks.sh`

**Step 1: Write the failing test first**

Create `tests/test-install-hooks.sh`:

```bash
#!/usr/bin/env bash
# Tests for install-hooks.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_HOOKS="$SCRIPT_DIR/../spec/bootstrap/install-hooks.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

assert_file_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — pattern '$pattern' not found in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

repo="$tmp/repo"
mkdir -p "$repo/.claude" "$repo/.harness"
bootstrap="$SCRIPT_DIR/../spec/bootstrap"

# Basic install: writes hooks into settings.json
assert_exit "install-hooks exits 0" 0 \
  bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap"

assert_file_contains "PostToolUse hook written" "$repo/.claude/settings.json" "PostToolUse"
assert_file_contains "PreToolUse hook written"  "$repo/.claude/settings.json" "PreToolUse"
assert_file_contains "validate-artifact in config" "$repo/.claude/settings.json" "validate-artifact"
assert_file_contains "validate-transition in config" "$repo/.claude/settings.json" "validate-transition"

# Idempotent: running twice does not duplicate hooks
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
post_count="$(grep -c "PostToolUse" "$repo/.claude/settings.json")"
TOTAL=$((TOTAL + 1))
if [[ "$post_count" -eq 1 ]]; then
  echo "  pass: idempotent — PostToolUse not duplicated"
  PASS=$((PASS + 1))
else
  echo "  FAIL: idempotent — PostToolUse appears $post_count times"
  FAIL=$((FAIL + 1))
fi

# Dry run: does not modify settings.json
repo2="$tmp/repo2"
mkdir -p "$repo2/.claude"
bash "$INSTALL_HOOKS" --repo-root "$repo2" --bootstrap-dir "$bootstrap" --dry-run >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ ! -f "$repo2/.claude/settings.json" ]]; then
  echo "  pass: dry-run does not create settings.json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: dry-run should not create settings.json"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**Step 2: Run test — confirm it fails**

```bash
bash tests/test-install-hooks.sh
```

Expected: all FAILs.

**Step 3: Create install-hooks.sh**

Create `spec/bootstrap/install-hooks.sh`:

```bash
#!/usr/bin/env bash
# install-hooks.sh — register baton validation hooks in the target repo's Claude Code settings
#
# Usage: install-hooks.sh --repo-root PATH --bootstrap-dir PATH [--dry-run]
#
# Writes PostToolUse (validate-artifact) and PreToolUse (validate-transition) hooks
# into .claude/settings.json. Idempotent: existing baton hooks are replaced, not duplicated.
# Other entries in settings.json are preserved.
#
# Requires: jq
set -euo pipefail

repo_root=""
bootstrap_dir=""
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)    repo_root="$2";    shift 2 ;;
    --bootstrap-dir) bootstrap_dir="$2"; shift 2 ;;
    --dry-run)      dry_run="true";    shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [[ -z "$repo_root" || -z "$bootstrap_dir" ]]; then
  printf 'Usage: install-hooks.sh --repo-root PATH --bootstrap-dir PATH [--dry-run]\n' >&2
  exit 1
fi

repo_root="$(cd "$repo_root" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: install-hooks.sh requires jq. Install with: brew install jq\n' >&2
  exit 1
fi

settings_file="$repo_root/.claude/settings.json"

# Relative paths from repo root (hooks run with repo root as CWD)
artifact_script="${bootstrap_dir}/validate-artifact.sh"
transition_script="${bootstrap_dir}/validate-transition.sh"

# Make paths relative to repo_root for portability
rel_artifact="$(realpath --relative-to="$repo_root" "$artifact_script" 2>/dev/null \
  || python3 -c "import os; print(os.path.relpath('$artifact_script', '$repo_root'))")"
rel_transition="$(realpath --relative-to="$repo_root" "$transition_script" 2>/dev/null \
  || python3 -c "import os; print(os.path.relpath('$transition_script', '$repo_root'))")"

# PostToolUse hook: validate artifact sections after write (informational — does not block)
post_hook_cmd="bash $rel_artifact \"\$(echo \$CLAUDE_TOOL_INPUT | jq -r '.file_path | split(\"/\") | last | split(\".\") | first')\" \"\$(echo \$CLAUDE_TOOL_INPUT | jq -r '.file_path')\" 2>&1 || true"

# PreToolUse hook: validate transition before writing task-status.md (blocks on illegal)
pre_hook_cmd="bash $rel_transition \"\$(jq -r 'if .file_path | test(\"task-status\") then \"__check__\" else \"__skip__\" end' <<< \"\$CLAUDE_TOOL_INPUT\")\" 2>&1 || true"

# Build the hook entries as JSON
post_entry="$(jq -n \
  --arg cmd "$(cat <<EOF
# baton: validate artifact sections
input=\$(cat); fp=\$(echo "\$input" | jq -r '.tool_input.file_path // empty')
[[ "\$fp" == *".harness/"*".md" ]] || exit 0
at=\$(basename "\$fp" .md)
bash "$rel_artifact" "\$at" "\$fp"
EOF
)" \
  '{ "type": "command", "command": $cmd }')"

pre_entry="$(jq -n \
  --arg cmd "$(cat <<EOF
# baton: validate state transition
input=\$(cat); fp=\$(echo "\$input" | jq -r '.tool_input.file_path // empty')
[[ "\$fp" == *"task-status.md" ]] || exit 0
new_content=\$(echo "\$input" | jq -r '.tool_input.content // empty')
[[ -n "\$new_content" ]] || exit 0
new_state=\$(echo "\$new_content" | awk -F'|' '/^[|]/{if(\$4!~/State|---/){gsub(/ /,\"\",\$4); print \$4; exit}}')
[[ -n "\$new_state" ]] || exit 0
[[ -f "\$fp" ]] || exit 0
cur_state=\$(awk -F'|' '/^[|]/{if(\$4!~/State|---/){gsub(/ /,\"\",\$4); print \$4; exit}}' "\$fp")
[[ -n "\$cur_state" ]] || exit 0
bash "$rel_transition" "\$cur_state" "\$new_state"
EOF
)" \
  '{ "type": "command", "command": $cmd }')"

if [[ "$dry_run" == "true" ]]; then
  printf 'dry-run: would write baton hooks to %s\n' "$settings_file"
  printf '  PostToolUse: validate-artifact on .harness/*.md writes\n'
  printf '  PreToolUse:  validate-transition on task-status.md writes\n'
  exit 0
fi

mkdir -p "$(dirname "$settings_file")"

# Read existing settings or start with empty object
if [[ -f "$settings_file" ]]; then
  existing="$(cat "$settings_file")"
else
  existing="{}"
fi

# Remove any existing baton hooks, then add fresh ones
# PostToolUse: remove baton entries from matcher "Write|Edit|MultiEdit", then add
updated="$(echo "$existing" | jq \
  --argjson post "$post_entry" \
  --argjson pre "$pre_entry" \
  '
  # Remove old baton hooks (identified by "# baton:" in command)
  .hooks.PostToolUse //= []
  | .hooks.PreToolUse //= []
  | .hooks.PostToolUse = [
      .hooks.PostToolUse[] | select(.command | startswith("# baton: validate artifact") | not)
    ]
  | .hooks.PreToolUse = [
      .hooks.PreToolUse[] | select(.command | startswith("# baton: validate state") | not)
    ]
  # Add fresh baton hooks
  | .hooks.PostToolUse += [$post]
  | .hooks.PreToolUse += [$pre]
  ')"

printf '%s\n' "$updated" > "$settings_file"
printf 'write %s\n' "$settings_file"
printf 'Hooks installed:\n'
printf '  PostToolUse: validate-artifact.sh on .harness/*.md writes\n'
printf '  PreToolUse:  validate-transition.sh on task-status.md writes\n'
```

**Step 4: Make executable**

```bash
chmod +x spec/bootstrap/install-hooks.sh
```

**Step 5: Run test — confirm it passes**

```bash
bash tests/test-install-hooks.sh
```

Expected: `Results: 6 passed, 0 failed of 6 total`

**Step 6: Commit**

```bash
git add spec/bootstrap/install-hooks.sh tests/test-install-hooks.sh
git commit -m "feat(bootstrap): install-hooks.sh — auto-register validate-artifact + validate-transition as Claude Code hooks"
```

---

## Task 10: P1-5 — Wire install-harness.sh to call install-hooks.sh

**Files:**
- Modify: `spec/bootstrap/install-harness.sh` (last ~10 lines before the printf summary)

**Step 1: Read the current end of install-harness.sh**

Read `spec/bootstrap/install-harness.sh` from line 295 to end to see the exact lockfile write and summary printf.

**Step 2: Add install-hooks.sh call after the lockfile write**

Find the line: `printf 'write %s\n' "$lockfile_path"` (after the lockfile heredoc).

After that block, add:

```bash
# Install platform hooks for artifact validation and state transition enforcement
if [[ "$dry_run" != "true" ]]; then
  hook_installer="$resolved_source_root/spec/bootstrap/install-hooks.sh"
  if [[ -f "$hook_installer" ]]; then
    bootstrap_dir="$vendor_spec_root/bootstrap"
    bash "$hook_installer" \
      --repo-root "$resolved_repo_root" \
      --bootstrap-dir "$bootstrap_dir" \
      || printf 'Warning: install-hooks.sh failed — hooks not installed\n'
  fi
fi
```

**Step 3: Verify install still works end-to-end**

```bash
bash spec/bootstrap/install-harness.sh --repo-root /tmp/baton-hook-test --source-root . --dry-run
```

Expected: dry-run output shows all install steps; no errors.

**Step 4: Commit**

```bash
git add spec/bootstrap/install-harness.sh
git commit -m "feat(install-harness): call install-hooks.sh after install/update — zero-step hook registration"
```

---

## Task 11: Full verification

**Step 1: Run check-consistency.sh**

```bash
bash spec/bootstrap/check-consistency.sh
```

Expected: `all invariants OK` (7/7)

**Step 2: Run all tests**

```bash
bash tests/test-validate-artifact.sh
bash tests/test-validate-transition.sh
bash tests/test-install-hooks.sh
```

Expected: all pass.

**Step 3: Verify hooks are installed in the baton repo itself**

```bash
bash spec/bootstrap/install-hooks.sh \
  --repo-root . \
  --bootstrap-dir spec/bootstrap
cat .claude/settings.json | jq '.hooks'
```

Expected: PostToolUse and PreToolUse entries with baton validation commands visible.

**Step 4: Smoke-test validate-artifact on a known artifact**

Create a test artifact and run the validator:

```bash
bash spec/bootstrap/validate-artifact.sh "scoped-map" spec/templates/scoped-map.template.md
echo "exit: $?"
```

Expected: exit 0 (template has all required sections).

**Step 5: Smoke-test validate-transition**

```bash
bash spec/bootstrap/validate-transition.sh "exploring" "generating" && echo "should not reach"
# Expected: ERROR + exit 1

bash spec/bootstrap/validate-transition.sh "exploring" "specifying" && echo "OK"
# Expected: exit 0
```

**Step 6: Final commit if settings.json was modified**

```bash
git add .claude/settings.json
git commit -m "chore: install baton validation hooks in dev repo"
```

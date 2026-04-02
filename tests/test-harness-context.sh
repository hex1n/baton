#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/harness-context.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_json_field() {
  local label="$1" harness="$2" jq_expr="$3"
  TOTAL=$((TOTAL+1))
  local out; out=$(bash "$SCRIPT" "$harness" 2>/dev/null)
  if echo "$out" | jq -e "$jq_expr" >/dev/null 2>&1; then
    echo "  pass: $label"; PASS=$((PASS+1))
  else
    echo "  FAIL: $label — jq '$jq_expr' failed on: $out"; FAIL=$((FAIL+1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/task-status.md" <<EOF
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task-abc | generator | $state | 1 | 2026-03-28 | - |
EOF
}

make_legacy_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/task-status.md" <<EOF
# Task Status

| Scope | Owner | State | Updated At | Notes |
|------|------|------|-----------|------|
| legacy-task | reviewer | $state | 2026-03-28 | legacy |

## State Notes
EOF
}

# no task-status → valid JSON, hookEventName=SessionStart, "No active"
assert_json_field "no task: valid JSON"           "$tmp/empty" '.hookSpecificOutput.hookEventName == "SessionStart"'
assert_json_field "no task: no-task message"      "$tmp/empty" '.hookSpecificOutput.additionalContext | test("No active")'

# active task: contains state and task id
make_status "$tmp/t1" "generating"
assert_json_field "active task: hookEventName"    "$tmp/t1" '.hookSpecificOutput.hookEventName == "SessionStart"'
assert_json_field "active task: contains state"   "$tmp/t1" '.hookSpecificOutput.additionalContext | test("generating")'
assert_json_field "active task: contains task-id" "$tmp/t1" '.hookSpecificOutput.additionalContext | test("task-abc")'
assert_json_field "active task: contains owner"   "$tmp/t1" '.hookSpecificOutput.additionalContext | test("generator")'
assert_json_field "active task: contains eval_round" "$tmp/t1" '.hookSpecificOutput.additionalContext | test("1")'

# missing artifacts appear in output
make_status "$tmp/t2" "generating"
touch "$tmp/t2/scoped-map.md" "$tmp/t2/requirements.md"
assert_json_field "missing artifacts listed"      "$tmp/t2" '.hookSpecificOutput.additionalContext | test("missing")'

# present artifacts appear in output
touch "$tmp/t2/architecture.md" "$tmp/t2/verification-path.md"
assert_json_field "present artifacts listed"      "$tmp/t2" '.hookSpecificOutput.additionalContext | test("present")'

# latest row wins when multiple task rows exist
mkdir -p "$tmp/t3"
cat > "$tmp/t3/task-status.md" <<'EOF'
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| old-task | human | complete | 0 | 2026-03-28 | closed |
| latest-task | generator | generating | 2 | 2026-03-28 | active |

## State Notes
EOF
assert_json_field "latest row task id used"       "$tmp/t3" '.hookSpecificOutput.additionalContext | test("latest-task")'
assert_json_field "latest row state used"         "$tmp/t3" '.hookSpecificOutput.additionalContext | test("generating")'
assert_json_field "latest row eval_round used"    "$tmp/t3" '.hookSpecificOutput.additionalContext | test("2")'

# legacy schema still readable with eval_round defaulting to 0
make_legacy_status "$tmp/t4" "reviewing"
assert_json_field "legacy schema state readable"  "$tmp/t4" '.hookSpecificOutput.additionalContext | test("reviewing")'
assert_json_field "legacy eval_round defaults 0"  "$tmp/t4" '.hookSpecificOutput.additionalContext | test("eval_round: 0")'

# ready_for_human_close includes evaluation.md in visible artifact set
make_status "$tmp/t5" "ready_for_human_close"
touch "$tmp/t5/scoped-map.md" "$tmp/t5/requirements.md" "$tmp/t5/architecture.md" "$tmp/t5/verification-path.md"
assert_json_field "ready_for_human_close missing evaluation listed" "$tmp/t5" '.hookSpecificOutput.additionalContext | test("evaluation.md")'

# human-close context includes verifier/evaluator provenance and verdict
cat > "$tmp/t5/verification-path.md" <<'EOF'
# Verification Path: test
## 1. Intended Checks
ok
## 2. Exact Commands
ok
## 3. Prerequisites
ok
## 4. Execution Provenance
- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: dry-run
- Fallback policy: block
- Fallback reason: none
## 5. Dry-Run Result
ok
## 6. Blockers
none
## 7. Fallbacks
ok
EOF
cat > "$tmp/t5/evaluation.md" <<'EOF'
# Evaluation: test
## 1. Inputs
ok
## 2. Execution Provenance
- Role: evaluator
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: cold-read
- Fallback policy: block
- Fallback reason: none
## 3. Findings
ok
## 4. Verification Results
ok
## 5. Verdict
- Verdict: pass
- Acceptance criteria status: all met
## 6. Residual Risks
none
EOF
assert_json_field "human-close context shows verifier provenance" "$tmp/t5" '.hookSpecificOutput.additionalContext | test("verifier: role=verification_explorer mode=strict context=isolated_subagent")'
assert_json_field "human-close context shows evaluator verdict" "$tmp/t5" '.hookSpecificOutput.additionalContext | test("evaluator: role=evaluator mode=strict context=isolated_subagent verdict=pass")'

# overlay recommendation from scoped-map is surfaced in context
make_status "$tmp/t6" "generating"
cat > "$tmp/t6/scoped-map.md" <<'EOF'
# Scoped Map: test
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

## Overlay Recommendation
overlay: strict
EOF
touch "$tmp/t6/requirements.md" "$tmp/t6/architecture.md" "$tmp/t6/verification-path.md"
assert_json_field "overlay recommendation surfaced" "$tmp/t6" '.hookSpecificOutput.additionalContext | test("overlay: strict")'

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

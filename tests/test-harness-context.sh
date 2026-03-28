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
  cat > "$dir/module-status.md" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task-abc | generator | $state | 1 | 2026-03-28 | - |
EOF
}

# no module-status → valid JSON, hookEventName=SessionStart, "No active"
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

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

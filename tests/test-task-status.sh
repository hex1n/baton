#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/task-status.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_output() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=""
  actual="$("$@" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$expected' got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

current_file="$tmp/current.md"
cat > "$current_file" <<'EOF'
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| old-task | human | complete | 0 | 2026-03-28T10:00:00+0800 | closed |
| new-task | generator | generating | 2 | 2026-03-28T10:10:00+0800 | active |

## State Notes
EOF

legacy_file="$tmp/legacy.md"
cat > "$legacy_file" <<'EOF'
# Task Status

| Scope | Owner | State | Updated At | Notes |
|------|------|------|-----------|------|
| legacy-task | reviewer | reviewing | 2026-03-28T09:00:00+0800 | legacy row |

## State Notes
EOF

assert_output "current schema detected" "current" bash "$SCRIPT" schema "$current_file"
assert_output "legacy schema detected" "legacy" bash "$SCRIPT" schema "$legacy_file"
assert_output "current row count" "2" bash "$SCRIPT" row-count "$current_file"
assert_output "non-complete count" "1" bash "$SCRIPT" non-complete-count "$current_file"
assert_output "current-field scope uses last row" "new-task" bash "$SCRIPT" current-field "$current_file" scope
assert_output "current-field state uses last row" "generating" bash "$SCRIPT" current-field "$current_file" state
assert_output "current-field eval_round uses last row" "2" bash "$SCRIPT" current-field "$current_file" eval_round
assert_output "legacy eval_round defaults to 0" "0" bash "$SCRIPT" current-field "$legacy_file" eval_round
assert_output "legacy state readable" "reviewing" bash "$SCRIPT" current-field "$legacy_file" state

updated_file="$tmp/updated.md"
cat > "$updated_file" <<'EOF'
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| task-a | generator | reviewing | 1 | 2026-03-28T10:00:00+0800 | active |
| task-b | generator | reviewing | 2 | 2026-03-28T10:10:00+0800 | active |

## State Notes
EOF

TOTAL=$((TOTAL + 1))
actual="$(
  bash -c "source '$SCRIPT'; task_status_set_eval_round '$updated_file' 3; task_status_current_field '$updated_file' eval_round" 2>/dev/null || true
)"
if [[ "$actual" == "3" ]]; then
  echo "  pass: set_eval_round updates current row"
  PASS=$((PASS + 1))
else
  echo "  FAIL: set_eval_round updates current row — expected '3' got '$actual'"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
state_after="$(
  bash -c "source '$SCRIPT'; task_status_current_field '$updated_file' state" 2>/dev/null || true
)"
if [[ "$state_after" == "reviewing" ]]; then
  echo "  pass: set_eval_round preserves other columns"
  PASS=$((PASS + 1))
else
  echo "  FAIL: set_eval_round preserves other columns — expected 'reviewing' got '$state_after'"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

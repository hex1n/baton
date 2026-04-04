#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/validate-state-artifacts.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_exit() {
  local label="$1" expected="$2"; shift 2
  TOTAL=$((TOTAL+1))
  local actual=0; "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then echo "  pass: $label"; PASS=$((PASS+1))
  else echo "  FAIL: $label — expected exit $expected got $actual"; FAIL=$((FAIL+1)); fi
}

assert_json_block() {
  local label="$1" harness="$2"
  TOTAL=$((TOTAL+1))
  local out; out=$(bash "$SCRIPT" "$harness" 2>/dev/null || true)
  if echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    echo "  pass: $label"; PASS=$((PASS+1))
  else
    echo "  FAIL: $label — output is not valid JSON block: $out"; FAIL=$((FAIL+1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/task-status.md" <<EOF
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task1 | generator | $state | 0 | 2026-03-28 | - |
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

# no task-status.md → exit 0
assert_exit "no task-status → pass" 0 bash "$SCRIPT" "$tmp/empty"

# state=exploring → no artifacts required → exit 0
make_status "$tmp/t1" "exploring"
assert_exit "exploring → no artifacts required" 0 bash "$SCRIPT" "$tmp/t1"

# state=blocked → no artifact check → exit 0
make_status "$tmp/t2" "blocked"
assert_exit "blocked → no artifact check" 0 bash "$SCRIPT" "$tmp/t2"

# state=specifying, exploration.md present → exit 0
make_status "$tmp/t3" "specifying"
touch "$tmp/t3/exploration.md"
assert_exit "specifying + exploration present → pass" 0 bash "$SCRIPT" "$tmp/t3"

# state=specifying, exploration.md missing → exit 2
make_status "$tmp/t4" "specifying"
assert_exit "specifying + exploration missing → block" 2 bash "$SCRIPT" "$tmp/t4"

# state=generating, all artifacts present → exit 0
make_status "$tmp/t5" "generating"
touch "$tmp/t5/exploration.md" "$tmp/t5/requirements.md" "$tmp/t5/architecture.md" "$tmp/t5/verification.md"
assert_exit "generating + all artifacts → pass" 0 bash "$SCRIPT" "$tmp/t5"

# state=generating, verification.md missing → exit 2
make_status "$tmp/t6" "generating"
touch "$tmp/t6/exploration.md" "$tmp/t6/requirements.md" "$tmp/t6/architecture.md"
assert_exit "generating + verification missing → block" 2 bash "$SCRIPT" "$tmp/t6"

# exit 2 output is valid JSON with decision:block
assert_json_block "block output is JSON with decision:block" "$tmp/t6"

# latest row determines current state
mkdir -p "$tmp/t7"
cat > "$tmp/t7/task-status.md" <<'EOF'
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| old-task | human | complete | 0 | 2026-03-28 | closed |
| latest-task | generator | generating | 1 | 2026-03-28 | active |

## State Notes
EOF
touch "$tmp/t7/exploration.md" "$tmp/t7/requirements.md" "$tmp/t7/architecture.md"
assert_exit "latest row generating without verification -> block" 2 bash "$SCRIPT" "$tmp/t7"

# legacy schema remains readable
make_legacy_status "$tmp/t8" "specifying"
touch "$tmp/t8/exploration.md"
assert_exit "legacy schema specifying + exploration present -> pass" 0 bash "$SCRIPT" "$tmp/t8"

# ready_for_human_close requires evaluation.md
make_status "$tmp/t9" "ready_for_human_close"
touch "$tmp/t9/exploration.md" "$tmp/t9/requirements.md" "$tmp/t9/architecture.md" "$tmp/t9/verification.md"
assert_exit "ready_for_human_close without evaluation -> block" 2 bash "$SCRIPT" "$tmp/t9"

make_status "$tmp/t10" "ready_for_human_close"
touch "$tmp/t10/exploration.md" "$tmp/t10/requirements.md" "$tmp/t10/architecture.md" "$tmp/t10/verification.md" "$tmp/t10/evaluation.md"
assert_exit "ready_for_human_close with evaluation -> pass" 0 bash "$SCRIPT" "$tmp/t10"

# state=complete requires retrospective.md
make_status "$tmp/t11" "complete"
touch "$tmp/t11/exploration.md" "$tmp/t11/requirements.md" "$tmp/t11/architecture.md" "$tmp/t11/verification.md" "$tmp/t11/evaluation.md"
assert_exit "complete without retrospective -> block" 2 bash "$SCRIPT" "$tmp/t11"

make_status "$tmp/t12" "complete"
touch "$tmp/t12/exploration.md" "$tmp/t12/requirements.md" "$tmp/t12/architecture.md" "$tmp/t12/verification.md" "$tmp/t12/evaluation.md" "$tmp/t12/retrospective.md"
assert_exit "complete with retrospective -> pass" 0 bash "$SCRIPT" "$tmp/t12"

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

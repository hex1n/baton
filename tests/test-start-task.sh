#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_TASK="$SCRIPT_DIR/../spec/bootstrap/start-task.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_file_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -Fq "$pattern" "$file" 2>/dev/null; then
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
mkdir -p "$repo/.harness/history"

cat > "$repo/.harness/task-status.md" <<'EOF'
# Task Status

| Scope | Owner | State | Updated At | Notes |
|------|------|------|-----------|------|
| old-task | human | complete | 2026-03-28T10:00:00+0800 | done |

## State Notes

- Current artifacts: complete
- Current blockers: none
- Current residual risks: none
EOF

cat > "$repo/.harness/scoped-map.md" <<'EOF'
custom scoped map
EOF

cat > "$repo/.harness/requirements.md" <<'EOF'
custom requirements
EOF

cat > "$repo/.harness/architecture.md" <<'EOF'
custom architecture
EOF

cat > "$repo/.harness/verification-path.md" <<'EOF'
custom verification path
EOF

cat > "$repo/.harness/evaluation.md" <<'EOF'
custom evaluation
EOF

cat > "$repo/.harness/retrospective.md" <<'EOF'
custom retrospective
EOF

assert_exit "start-task handles legacy task-status" 0 \
  bash "$START_TASK" --repo-root "$repo" --task-id "new-task" --notes "legacy migration test"

assert_file_contains "task-status migrated to current header" \
  "$repo/.harness/task-status.md" "| Scope | Owner | State | Eval Round | Updated At | Notes |"
assert_file_contains "legacy row preserved with eval round 0" \
  "$repo/.harness/task-status.md" "| old-task | human | complete | 0 | 2026-03-28T10:00:00+0800 | done |"
assert_file_contains "new row appended" \
  "$repo/.harness/task-status.md" "| new-task | scoped-explorer | exploring | 0 |"

history_count="$(find "$repo/.harness/history" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
TOTAL=$((TOTAL + 1))
if [[ "$history_count" -ge 1 ]]; then
  echo "  pass: previous artifacts archived"
  PASS=$((PASS + 1))
else
  echo "  FAIL: previous artifacts were not archived"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if [[ -f "$repo/.harness/evaluation.md" ]] && ! grep -Fq "custom evaluation" "$repo/.harness/evaluation.md"; then
  echo "  pass: evaluation artifact reset from template"
  PASS=$((PASS + 1))
else
  echo "  FAIL: evaluation artifact was not reset from template"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

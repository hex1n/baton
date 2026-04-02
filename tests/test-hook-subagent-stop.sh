#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/subagent-stop"
TASK_STATUS="$SCRIPT_DIR/../spec/bootstrap/task-status.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

make_repo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  git -C "$dir" init -q
}

write_status() {
  local file="$1" state="$2" eval_round="$3"
  cat > "$file" <<EOF
# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | $state | $eval_round | 2026-03-29T22:00:00+0800 | active |

## State Notes
EOF
}

make_verification_path() {
  local file="$1"
  cat > "$file" <<'EOF'
# Verification Path: runtime-enforcement-hardening
## 1. Intended Checks
content
## 2. Exact Commands
content
## 3. Prerequisites
content
## 4. Execution Provenance
- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: dry-run
- Fallback policy: block
- Fallback reason: none
## 5. Dry-Run Result
content
## 6. Blockers
none
## 7. Fallbacks
content
EOF
}

run_hook() {
  local repo="$1" payload="$2"
  PAYLOAD="$payload" HOOK_PATH="$HOOK" bash -c '
    cd "$1"
    printf "%s" "$PAYLOAD" | bash "$HOOK_PATH"
  ' bash "$repo"
}

make_repo "$tmp/pass"
write_status "$tmp/pass/.harness/task-status.md" "reviewing" 1
cat > "$tmp/pass/.harness/profile.local.yaml" <<'EOF'
execution:
  max_eval_rounds: 3
EOF
make_verification_path "$tmp/pass/.harness/verification-path.md"
pass_payload='{"agent_type":"baton-evaluator"}'
assert_exit "evaluator increments eval_round" 0 run_hook "$tmp/pass" "$pass_payload"
TOTAL=$((TOTAL + 1))
actual_round="$(bash "$TASK_STATUS" current-field "$tmp/pass/.harness/task-status.md" eval_round 2>/dev/null || true)"
if [[ "$actual_round" == "2" ]]; then
  echo "  pass: evaluator write updates eval_round to 2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: evaluator write updates eval_round to 2 — got '$actual_round'"
  FAIL=$((FAIL + 1))
fi

make_repo "$tmp/block"
write_status "$tmp/block/.harness/task-status.md" "reviewing" 2
cat > "$tmp/block/.harness/profile.local.yaml" <<'EOF'
execution:
  max_eval_rounds: 3
EOF
make_verification_path "$tmp/block/.harness/verification-path.md"
block_payload='{"agent_type":"baton-evaluator"}'
assert_exit "evaluator blocks when max_eval_rounds reached" 2 run_hook "$tmp/block" "$block_payload"
TOTAL=$((TOTAL + 1))
blocked_round="$(bash "$TASK_STATUS" current-field "$tmp/block/.harness/task-status.md" eval_round 2>/dev/null || true)"
if [[ "$blocked_round" == "3" ]]; then
  echo "  pass: blocked evaluator still records the reaching eval_round"
  PASS=$((PASS + 1))
else
  echo "  FAIL: blocked evaluator still records the reaching eval_round — got '$blocked_round'"
  FAIL=$((FAIL + 1))
fi

make_repo "$tmp/verifier"
write_status "$tmp/verifier/.harness/task-status.md" "reviewing" 0
make_verification_path "$tmp/verifier/.harness/verification-path.md"
verifier_payload='{"agent_type":"baton-verifier"}'
assert_exit "verifier path passes when verification artifact is valid" 0 run_hook "$tmp/verifier" "$verifier_payload"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

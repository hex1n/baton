#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/validate-isolation.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_exit() {
  local label="$1" expected="$2"; shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0; "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"; FAIL=$((FAIL + 1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/module-status.md" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| task1 | generator | $state | 0 | 2026-03-28 | - |

## State Notes
EOF
}

make_verification() {
  local dir="$1" mode="$2" context="$3" reason="$4"
  cat > "$dir/verification-path.md" <<EOF
# Verification Path: test
## 1. Intended Checks
ok
## 2. Exact Commands
ok
## 3. Prerequisites
ok
## 4. Execution Provenance
- Role: verification_explorer
- Isolation mode: $mode
- Execution context: $context
- Evidence: dry-run plan from isolated artifact read
- Fallback policy: explicit
- Fallback reason: $reason
## 5. Dry-Run Result
ok
## 6. Blockers
none
## 7. Fallbacks
ok
EOF
}

make_evaluation() {
  local dir="$1" mode="$2" context="$3" reason="$4" verdict="$5"
  cat > "$dir/evaluation.md" <<EOF
# Evaluation: test
## 1. Inputs
ok
## 2. Execution Provenance
- Role: evaluator
- Isolation mode: $mode
- Execution context: $context
- Evidence: artifact-only cold read
- Fallback policy: explicit
- Fallback reason: $reason
## 3. Findings
ok
## 4. Verification Results
ok
## 5. Verdict
- Verdict: $verdict
- Acceptance criteria status: all met
## 6. Residual Risks
none
EOF
}

# strict is default when profile is absent
make_status "$tmp/t1" "generating"
make_verification "$tmp/t1" "strict" "isolated_subagent" "none"
assert_exit "strict verification with isolated_subagent -> pass" 0 bash "$SCRIPT" "$tmp/t1"

make_status "$tmp/t2" "generating"
make_verification "$tmp/t2" "strict" "sequential_fallback" "tool lacks agent"
assert_exit "strict verification with sequential fallback -> block" 2 bash "$SCRIPT" "$tmp/t2"

mkdir -p "$tmp/t3"
cat > "$tmp/t3/profile.local.yaml" <<'EOF'
execution:
  verification_isolation_mode: compat
  review_isolation_mode: compat
EOF
make_status "$tmp/t3" "generating"
make_verification "$tmp/t3" "compat" "sequential_fallback" "host policy disallows spawn_agent in this turn"
assert_exit "compat verification with reason -> pass" 0 bash "$SCRIPT" "$tmp/t3"

mkdir -p "$tmp/t4"
cat > "$tmp/t4/profile.local.yaml" <<'EOF'
execution:
  verification_isolation_mode: compat
  review_isolation_mode: compat
EOF
make_status "$tmp/t4" "generating"
make_verification "$tmp/t4" "compat" "sequential_fallback" "none"
assert_exit "compat verification without concrete reason -> block" 2 bash "$SCRIPT" "$tmp/t4"

make_status "$tmp/t5" "ready_for_human_close"
make_verification "$tmp/t5" "strict" "isolated_subagent" "none"
assert_exit "ready_for_human_close without evaluation -> block" 2 bash "$SCRIPT" "$tmp/t5"

make_status "$tmp/t6" "ready_for_human_close"
make_verification "$tmp/t6" "strict" "isolated_subagent" "none"
make_evaluation "$tmp/t6" "strict" "isolated_subagent" "none" "PASS"
assert_exit "ready_for_human_close with strict evaluation -> pass" 0 bash "$SCRIPT" "$tmp/t6"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

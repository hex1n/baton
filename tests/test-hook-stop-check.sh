#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/stop-check"
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
  local file="$1" state="$2"
  cat > "$file" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | $state | 0 | 2026-03-29T22:00:00+0800 | active |

## State Notes
EOF
}

write_verification_path() {
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
- Agent ID: verifier-stop-check
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

make_repo "$tmp/pass"
write_status "$tmp/pass/.harness/module-status.md" "generating"
touch "$tmp/pass/.harness/scoped-map.md" \
  "$tmp/pass/.harness/requirements.md" \
  "$tmp/pass/.harness/architecture.md" \
  "$tmp/pass/.harness/verification-path.md"
write_verification_path "$tmp/pass/.harness/verification-path.md"
assert_exit "stop-check passes on complete generating harness" 0 \
  bash -c 'cd "$1" && bash "$2"' bash "$tmp/pass" "$HOOK"

make_repo "$tmp/fail"
write_status "$tmp/fail/.harness/module-status.md" "ready_for_human_close"
touch "$tmp/fail/.harness/scoped-map.md" \
  "$tmp/fail/.harness/requirements.md" \
  "$tmp/fail/.harness/architecture.md" \
  "$tmp/fail/.harness/verification-path.md"
write_verification_path "$tmp/fail/.harness/verification-path.md"
assert_exit "stop-check blocks missing evaluation on ready_for_human_close" 2 \
  bash -c 'cd "$1" && bash "$2"' bash "$tmp/fail" "$HOOK"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

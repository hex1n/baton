#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/run-hook.sh"
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

assert_json_field() {
  local label="$1" repo="$2" jq_expr="$3"
  TOTAL=$((TOTAL + 1))
  local out=""
  out="$(PAYLOAD='{}' HOOK_PATH="$HOOK" bash -c '
    cd "$1"
    printf "%s" "$PAYLOAD" | bash "$HOOK_PATH" session-start baton-harness-context
  ' bash "$repo" 2>/dev/null || true)"
  if echo "$out" | jq -e "$jq_expr" >/dev/null 2>&1; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — jq '$jq_expr' failed on: $out"
    FAIL=$((FAIL + 1))
  fi
}

make_repo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  git -C "$dir" init -q
}

assert_exit "run-hook requires a handler name" 1 bash "$HOOK"
assert_exit "run-hook rejects unknown handlers" 1 bash "$HOOK" not-a-real-hook

make_repo "$tmp/repo"
assert_json_field "run-hook dispatches session-start and returns valid JSON" \
  "$tmp/repo" '.hookSpecificOutput.hookEventName == "SessionStart"'

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
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

# Basic install
assert_exit "install-hooks exits 0" 0 \
  bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap"

assert_file_contains "PostToolUse written"       "$repo/.claude/settings.json" "PostToolUse"
assert_file_contains "PreToolUse written"        "$repo/.claude/settings.json" "PreToolUse"
assert_file_contains "validate-artifact in config" "$repo/.claude/settings.json" "validate-artifact"
assert_file_contains "validate-transition in config" "$repo/.claude/settings.json" "validate-transition"

# Idempotent: running twice does not duplicate PostToolUse
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
post_count="$(grep -c '"PostToolUse"' "$repo/.claude/settings.json")"
TOTAL=$((TOTAL + 1))
if [[ "$post_count" -eq 1 ]]; then
  echo "  pass: idempotent — PostToolUse not duplicated"
  PASS=$((PASS + 1))
else
  echo "  FAIL: idempotent — PostToolUse key appears $post_count times"
  FAIL=$((FAIL + 1))
fi

# Dry run: does not create settings.json
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

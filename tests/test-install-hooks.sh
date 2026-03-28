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

# ---------------------------------------------------------------------------
# Claude Code hooks
# ---------------------------------------------------------------------------
assert_exit "install-hooks exits 0" 0 \
  bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap"

assert_file_contains "CC PostToolUse written"           "$repo/.claude/settings.json" "PostToolUse"
assert_file_contains "CC PreToolUse written"            "$repo/.claude/settings.json" "PreToolUse"
assert_file_contains "CC validate-artifact in config"   "$repo/.claude/settings.json" "validate-artifact"
assert_file_contains "CC validate-transition in config" "$repo/.claude/settings.json" "validate-transition"
assert_file_contains "CC matcher is Write|Edit"         "$repo/.claude/settings.json" "Write|Edit|MultiEdit"
assert_file_contains "CC commands use git rev-parse" \
  "$repo/.claude/settings.json" "git rev-parse"
assert_file_contains "Codex commands use git rev-parse" \
  "$repo/.codex/hooks.json" "git rev-parse"

# Idempotent: running twice does not duplicate PostToolUse
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
post_count="$(grep -c '"PostToolUse"' "$repo/.claude/settings.json")"
TOTAL=$((TOTAL + 1))
if [[ "$post_count" -eq 1 ]]; then
  echo "  pass: CC idempotent — PostToolUse not duplicated"
  PASS=$((PASS + 1))
else
  echo "  FAIL: CC idempotent — PostToolUse key appears $post_count times"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Codex hooks
# ---------------------------------------------------------------------------
assert_file_contains "Codex hooks.json created"             "$repo/.codex/hooks.json"   "PostToolUse"
assert_file_contains "Codex PreToolUse written"             "$repo/.codex/hooks.json"   "PreToolUse"
assert_file_contains "Codex validate-artifact in hooks"     "$repo/.codex/hooks.json"   "validate-artifact"
assert_file_contains "Codex validate-transition in hooks"   "$repo/.codex/hooks.json"   "validate-transition"
assert_file_contains "Codex matcher is Bash"                "$repo/.codex/hooks.json"   '"Bash"'
assert_file_contains "Codex PreToolUse exits 2 to block"    "$repo/.codex/hooks.json"   "exit 2"
assert_file_contains "Codex config feature flag written"    "$repo/.codex/config.toml"  "codex_hooks = true"

# Idempotent: running twice does not duplicate Codex PostToolUse
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
cx_post_count="$(grep -c '"PostToolUse"' "$repo/.codex/hooks.json")"
TOTAL=$((TOTAL + 1))
if [[ "$cx_post_count" -eq 1 ]]; then
  echo "  pass: Codex idempotent — PostToolUse not duplicated"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Codex idempotent — PostToolUse key appears $cx_post_count times"
  FAIL=$((FAIL + 1))
fi

# Idempotent: config.toml feature flag not duplicated
cx_flag_count="$(grep -c 'codex_hooks' "$repo/.codex/config.toml")"
TOTAL=$((TOTAL + 1))
if [[ "$cx_flag_count" -eq 1 ]]; then
  echo "  pass: Codex idempotent — config.toml flag not duplicated"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Codex idempotent — codex_hooks appears $cx_flag_count times in config.toml"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Stop hooks
# ---------------------------------------------------------------------------
assert_file_contains "CC Stop hook written"             "$repo/.claude/settings.json" '"Stop"'
assert_file_contains "CC Stop uses validate-state"      "$repo/.claude/settings.json" "validate-state-artifacts"
assert_file_contains "Codex Stop hook written"          "$repo/.codex/hooks.json"     '"Stop"'
assert_file_contains "Codex Stop has statusMessage"     "$repo/.codex/hooks.json"     "Checking harness state"

# Stop idempotent (CC)
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
cc_stop_count="$(grep -c '"Stop"' "$repo/.claude/settings.json")"
TOTAL=$((TOTAL+1))
if [[ "$cc_stop_count" -eq 1 ]]; then
  echo "  pass: CC Stop idempotent — not duplicated"
  PASS=$((PASS+1))
else
  echo "  FAIL: CC Stop appears $cc_stop_count times"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Dry run
# ---------------------------------------------------------------------------
repo2="$tmp/repo2"
mkdir -p "$repo2/.claude"
bash "$INSTALL_HOOKS" --repo-root "$repo2" --bootstrap-dir "$bootstrap" --dry-run >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ ! -f "$repo2/.claude/settings.json" && ! -f "$repo2/.codex/hooks.json" ]]; then
  echo "  pass: dry-run does not create settings.json or hooks.json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: dry-run should not create settings.json or hooks.json"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

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

assert_file_not_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -Fq "$pattern" "$file" 2>/dev/null; then
    echo "  FAIL: $label — unexpected pattern '$pattern' found in $file"
    FAIL=$((FAIL + 1))
  else
    echo "  pass: $label"
    PASS=$((PASS + 1))
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
assert_file_contains "CC PostToolUse points at hook script" \
  "$repo/.claude/settings.json" "hooks/post-artifact"
assert_file_contains "CC PreToolUse points at hook script" \
  "$repo/.claude/settings.json" "hooks/pre-transition"
assert_file_contains "CC Stop points at hook script" \
  "$repo/.claude/settings.json" "hooks/stop-check"
assert_file_contains "CC SubagentStop points at hook script" \
  "$repo/.claude/settings.json" "hooks/subagent-stop"
assert_file_contains "CC SessionStart points at hook script" \
  "$repo/.claude/settings.json" "hooks/session-start"
assert_file_contains "CC matcher is Write|Edit"         "$repo/.claude/settings.json" "Write|Edit|MultiEdit"
assert_file_not_contains "CC settings no longer inline validate-artifact logic" \
  "$repo/.claude/settings.json" "tool_input.file_path"
assert_file_not_contains "CC settings no longer inline validate-transition logic" \
  "$repo/.claude/settings.json" "tool_input.content"

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
assert_file_contains "Codex PostToolUse uses unix dispatcher" \
  "$repo/.codex/hooks.json"   "run-hook.sh"
assert_file_contains "Codex PostToolUse names target handler" \
  "$repo/.codex/hooks.json"   "post-artifact baton-validate-artifact"
assert_file_contains "Codex PreToolUse names target handler" \
  "$repo/.codex/hooks.json"   "pre-transition baton-validate-transition"
assert_file_contains "Codex Stop names target handler" \
  "$repo/.codex/hooks.json"   "stop-check baton-validate-state baton-validate-isolation"
assert_file_contains "Codex SessionStart names target handler" \
  "$repo/.codex/hooks.json"   "session-start baton-harness-context"
assert_file_contains "Codex matcher is Bash"                "$repo/.codex/hooks.json"   '"Bash"'
assert_file_not_contains "Codex hooks no longer inline validate-artifact logic" \
  "$repo/.codex/hooks.json" "tool_input.command"
assert_file_not_contains "Codex hooks do not rely on shell assignment snippets" \
  "$repo/.codex/hooks.json" 'root=$(git rev-parse'
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
assert_file_contains "CC Stop hook still registered"    "$repo/.claude/settings.json" '"Stop"'
assert_file_contains "Codex Stop hook still registered" "$repo/.codex/hooks.json"     '"Stop"'
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

# Codex Stop idempotent
cx_stop_count="$(grep -c '"Stop"' "$repo/.codex/hooks.json")"
TOTAL=$((TOTAL+1))
if [[ "$cx_stop_count" -eq 1 ]]; then
  echo "  pass: Codex Stop idempotent — not duplicated"
  PASS=$((PASS+1))
else
  echo "  FAIL: Codex Stop appears $cx_stop_count times"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# SubagentStop (CC only)
# ---------------------------------------------------------------------------
assert_file_contains "CC SubagentStop written"            "$repo/.claude/settings.json" '"SubagentStop"'
assert_file_contains "CC SubagentStop matcher is agents"  "$repo/.claude/settings.json" "baton-evaluator"
assert_file_contains "CC SubagentStop points at hook script"  "$repo/.claude/settings.json" "hooks/subagent-stop"
TOTAL=$((TOTAL+1))
if ! grep -q '"SubagentStop"' "$repo/.codex/hooks.json" 2>/dev/null; then
  echo "  pass: Codex has no SubagentStop"
  PASS=$((PASS+1))
else
  echo "  FAIL: Codex should not have SubagentStop"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# SessionStart
# ---------------------------------------------------------------------------
assert_file_contains "CC SessionStart written"               "$repo/.claude/settings.json" '"SessionStart"'
assert_file_contains "CC SessionStart matcher"               "$repo/.claude/settings.json" "startup|resume"
assert_file_contains "CC SessionStart points at hook script"  "$repo/.claude/settings.json" "hooks/session-start"
assert_file_contains "Codex SessionStart written"            "$repo/.codex/hooks.json"     '"SessionStart"'
assert_file_contains "Codex SessionStart has statusMessage"  "$repo/.codex/hooks.json"     "Loading harness context"

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

# ---------------------------------------------------------------------------
# Relative bootstrap path test
# ---------------------------------------------------------------------------
repo3="$tmp/repo3"
mkdir -p "$repo3/custom-bootstrap"
cp -R "$bootstrap"/. "$repo3/custom-bootstrap/"
bash "$INSTALL_HOOKS" --repo-root "$repo3" --bootstrap-dir "$repo3/custom-bootstrap" >/dev/null 2>&1
assert_file_contains "CC uses relative bootstrap path" \
  "$repo3/.claude/settings.json" "custom-bootstrap"
assert_file_contains "Codex uses relative bootstrap path" \
  "$repo3/.codex/hooks.json" "custom-bootstrap"

TOTAL=$((TOTAL+1))
if ! grep -q '\.vendor/baton-harness/spec/bootstrap' "$repo3/.claude/settings.json" 2>/dev/null; then
  echo "  pass: CC does not hardcode vendor path when bootstrap-dir differs"
  PASS=$((PASS+1))
else
  echo "  FAIL: CC hardcodes .vendor/baton-harness/spec/bootstrap instead of relative path"
  FAIL=$((FAIL+1))
fi

# Stronger check: absolute path to repo3 must not appear in the hook commands
TOTAL=$((TOTAL+1))
if ! grep -qF "$repo3" "$repo3/.claude/settings.json" 2>/dev/null; then
  echo "  pass: CC hook commands contain no absolute path to bootstrap dir"
  PASS=$((PASS+1))
else
  echo "  FAIL: CC hook commands contain absolute path — relative path not computed"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Windows command generation
# ---------------------------------------------------------------------------
repo4="$tmp/repo4"
mkdir -p "$repo4/.claude"
BATON_HOOK_PLATFORM=windows bash "$INSTALL_HOOKS" --repo-root "$repo4" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
assert_file_contains "Windows CC uses run-hook.cmd" "$repo4/.claude/settings.json" "run-hook.cmd"
assert_file_contains "Windows CC uses cmd launcher" "$repo4/.claude/settings.json" "cmd /d /c"
assert_file_not_contains "Windows CC does not emit bash hook path" "$repo4/.claude/settings.json" 'bash \"$root'

# ---------------------------------------------------------------------------
# Machine-readable manifest
# ---------------------------------------------------------------------------
manifest="$tmp/install-hooks-manifest.json"
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" --print-manifest > "$manifest"
assert_file_contains "manifest contains Claude session command" "$manifest" '"session_start"'
assert_file_contains "manifest contains Codex post command" "$manifest" '"post"'
assert_file_contains "manifest contains current handler path" "$manifest" 'hooks/session-start'
assert_file_contains "manifest contains unix codex dispatcher" "$manifest" 'run-hook.sh'

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

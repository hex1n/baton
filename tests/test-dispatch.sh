#!/bin/bash
# test-dispatch.sh — Tests for event-based hook dispatcher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_DIR="$SCRIPT_DIR/.."
DISPATCH="$BATON_DIR/.baton/hooks/dispatch.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "$2" ]; then
        echo "  pass: $3"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $3 (expected '$2', got '$1')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    TOTAL=$((TOTAL + 1))
    if echo "$1" | grep -q "$2"; then
        echo "  pass: $3"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $3 (output does not contain '$2')"
        FAIL=$((FAIL + 1))
    fi
}

# Setup: copy dispatch.sh to temp hooks dir
setup_hooks() {
    rm -rf "$tmp/hooks"
    mkdir -p "$tmp/hooks"
    cp "$DISPATCH" "$tmp/hooks/dispatch.sh"
    chmod +x "$tmp/hooks/dispatch.sh"
}

# --- Test: dispatch routes to correct hook by event ---
echo "=== dispatch routes by event ==="
setup_hooks
cat > "$tmp/hooks/test-hook.sh" << 'HOOK'
echo "hook-fired"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
SessionStart::test-hook
MANIFEST

_out="$(bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
assert_contains "$_out" "hook-fired" "SessionStart routes to test-hook"

_out="$(bash "$tmp/hooks/dispatch.sh" Stop 2>&1)" || true
assert_eq "$_out" "" "Stop does not route to SessionStart hook"

# --- Test: matcher filtering via stdin JSON tool_name ---
echo "=== matcher filtering ==="
setup_hooks
cat > "$tmp/hooks/write-hook.sh" << 'HOOK'
echo "write-matched"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse:Write,Edit:write-hook
MANIFEST

_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" "write-matched" "Write matches Write,Edit matcher (from stdin JSON)"

_out="$(echo '{"tool_name":"Bash"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_eq "$_out" "" "Bash does not match Write,Edit matcher"

# No stdin = no tool name = matcher hooks with tool filter skipped
_out="$(bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1 < /dev/null)" || true
assert_eq "$_out" "" "no stdin means no tool_name, matcher hooks skipped"

# Empty matcher matches regardless of tool_name
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::write-hook
MANIFEST
_out="$(bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1 < /dev/null)" || true
assert_contains "$_out" "write-matched" "empty matcher matches without tool_name"

# --- Test: BATON_STDIN is available ---
echo "=== BATON_STDIN buffering ==="
setup_hooks
cat > "$tmp/hooks/stdin-hook.sh" << 'HOOK'
echo "stdin=$BATON_STDIN"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::stdin-hook
MANIFEST

_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" 'stdin={"tool_name":"Write"}' "BATON_STDIN contains piped input"

# --- Test: BATON_PROJECT_DIR is exported ---
echo "=== BATON_PROJECT_DIR export ==="
setup_hooks
cat > "$tmp/hooks/dir-hook.sh" << 'HOOK'
echo "projdir=$BATON_PROJECT_DIR"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
SessionStart::dir-hook
MANIFEST

_out="$(cd "$tmp" && bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
assert_contains "$_out" "projdir=" "BATON_PROJECT_DIR is set"

# --- Test: subshell isolation — exit 0 does not kill dispatcher ---
echo "=== subshell isolation ==="
setup_hooks
cat > "$tmp/hooks/hook-a.sh" << 'HOOK'
echo "a-fired"
exit 0
HOOK
cat > "$tmp/hooks/hook-b.sh" << 'HOOK'
echo "b-fired"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
Stop::hook-a
Stop::hook-b
MANIFEST

_out="$(bash "$tmp/hooks/dispatch.sh" Stop 2>&1)" || true
assert_contains "$_out" "a-fired" "hook-a fires"
assert_contains "$_out" "b-fired" "hook-b fires after hook-a exit 0"

# --- Test: exit 2 propagation for PreToolUse ---
echo "=== exit 2 propagation ==="
setup_hooks
cat > "$tmp/hooks/blocker.sh" << 'HOOK'
echo "blocked"
exit 2
HOOK
cat > "$tmp/hooks/after-block.sh" << 'HOOK'
echo "after-block"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::blocker
PreToolUse::after-block
MANIFEST

_rc=0
_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || _rc=$?
assert_eq "$_rc" "2" "dispatch exits 2 when hook blocks"
assert_contains "$_out" "after-block" "hooks after blocker still run"

# --- Test: comments and blank lines in manifest ---
echo "=== manifest comments ==="
setup_hooks
cat > "$tmp/hooks/hook-a.sh" << 'HOOK'
echo "a-fired"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
# This is a comment

SessionStart::hook-a
# Another comment
MANIFEST

_out="$(bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
assert_contains "$_out" "a-fired" "comments and blanks are skipped"

# --- Test: missing manifest exits cleanly ---
echo "=== missing manifest ==="
setup_hooks
rm -f "$tmp/hooks/manifest.conf"
_rc=0
bash "$tmp/hooks/dispatch.sh" SessionStart >/dev/null 2>&1 || _rc=$?
assert_eq "$_rc" "0" "missing manifest exits 0"

# --- Test: multiple hooks for same event, different matchers ---
echo "=== multiple matchers ==="
setup_hooks
cat > "$tmp/hooks/write-hook.sh" << 'HOOK'
echo "write-hook"
exit 0
HOOK
cat > "$tmp/hooks/bash-hook.sh" << 'HOOK'
echo "bash-hook"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse:Write,Edit:write-hook
PreToolUse:Bash:bash-hook
MANIFEST

_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" "write-hook" "Write triggers write-hook"
_out2="$(echo "$_out" | grep -c "bash-hook" || true)"
assert_eq "$_out2" "0" "Write does not trigger bash-hook"

_out="$(echo '{"tool_name":"Bash"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" "bash-hook" "Bash triggers bash-hook"

echo ""
echo "dispatch tests: $PASS passed, $FAIL failed out of $TOTAL"
[ "$FAIL" -eq 0 ]

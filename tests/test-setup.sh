#!/bin/bash
# test-setup.sh — Tests for setup.sh v5 (user-level flat install)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_DIR="$SCRIPT_DIR/.."
SETUP="$BATON_DIR/setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert() {
    TOTAL=$((TOTAL + 1))
    if eval "$2"; then
        echo "  pass: $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $1"
        FAIL=$((FAIL + 1))
    fi
}

# Create a fake HOME so we don't modify the real ~/.claude/
FAKE_HOME="$tmp/home"
mkdir -p "$FAKE_HOME/.claude"

# --- Test 1: Fresh install ---
echo "=== Fresh install ==="
(
    export HOME="$FAKE_HOME"
    export BATON_HOME="$BATON_DIR"
    bash "$SETUP" 2>&1
)

assert "skill symlinks created" '[ -L "$FAKE_HOME/.claude/skills/baton-plan" ]'
assert "using-baton symlink created" '[ -L "$FAKE_HOME/.claude/skills/using-baton" ]'
_BATON_CANONICAL="$(cd "$BATON_DIR" && pwd -P)"
assert "symlink points to source" '[ "$(readlink "$FAKE_HOME/.claude/skills/baton-plan")" = "$_BATON_CANONICAL/skills/baton-plan" ]'
assert "SKILL.md accessible via symlink" '[ -f "$FAKE_HOME/.claude/skills/baton-plan/SKILL.md" ]'

if command -v jq >/dev/null 2>&1; then
    assert "settings.json created" '[ -f "$FAKE_HOME/.claude/settings.json" ]'
    assert "hooks contain run-hook.cmd" 'grep -q "run-hook.cmd" "$FAKE_HOME/.claude/settings.json"'
    assert "SessionStart has empty matcher" 'jq -e ".hooks.SessionStart[0].matcher == \"\"" "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1'
    assert "PreToolUse has Edit matcher" 'jq -e ".hooks.PreToolUse[0].matcher" "$FAKE_HOME/.claude/settings.json" >/dev/null 2>&1'
else
    echo "  skip: jq not available, skipping settings.json tests"
fi

assert "CLAUDE.md created" '[ -f "$FAKE_HOME/.claude/CLAUDE.md" ]'
assert "CLAUDE.md has constitution" 'grep -q "constitution.md" "$FAKE_HOME/.claude/CLAUDE.md"'

# --- Test 2: Idempotent re-install ---
echo ""
echo "=== Idempotent re-install ==="
(
    export HOME="$FAKE_HOME"
    export BATON_HOME="$BATON_DIR"
    bash "$SETUP" 2>&1
)

assert "symlinks still valid" '[ -L "$FAKE_HOME/.claude/skills/baton-plan" ]'
assert "no duplicate constitution lines" '[ "$(grep -c "constitution" "$FAKE_HOME/.claude/CLAUDE.md")" -eq 1 ]'

# --- Test 3: Uninstall ---
echo ""
echo "=== Uninstall ==="
(
    export HOME="$FAKE_HOME"
    export BATON_HOME="$BATON_DIR"
    bash "$SETUP" --uninstall 2>&1
)

assert "skill symlinks removed" '[ ! -L "$FAKE_HOME/.claude/skills/baton-plan" ]'
assert "using-baton symlink removed" '[ ! -L "$FAKE_HOME/.claude/skills/using-baton" ]'

if command -v jq >/dev/null 2>&1; then
    assert "hooks removed from settings.json" '! grep -q "run-hook.cmd" "$FAKE_HOME/.claude/settings.json"'
fi

assert "constitution removed from CLAUDE.md" '! grep -q "constitution" "$FAKE_HOME/.claude/CLAUDE.md"'

# --- Test 4: Install with existing settings.json ---
echo ""
echo "=== Install with existing settings.json ==="
FAKE_HOME2="$tmp/home2"
mkdir -p "$FAKE_HOME2/.claude"
cat > "$FAKE_HOME2/.claude/settings.json" << 'EOF'
{
  "env": {"MY_VAR": "my_value"},
  "hooks": {
    "PreToolUse": [
      {"matcher": "CustomTool", "hooks": [{"type": "command", "command": "my-custom-hook"}]}
    ]
  }
}
EOF

(
    export HOME="$FAKE_HOME2"
    export BATON_HOME="$BATON_DIR"
    bash "$SETUP" 2>&1
)

if command -v jq >/dev/null 2>&1; then
    assert "backup created" '[ -f "$FAKE_HOME2/.claude/settings.json.baton-backup" ]'
    assert "env preserved" 'jq -e ".env.MY_VAR == \"my_value\"" "$FAKE_HOME2/.claude/settings.json" >/dev/null 2>&1'
    assert "custom hook preserved" 'grep -q "my-custom-hook" "$FAKE_HOME2/.claude/settings.json"'
    assert "baton hooks added" 'grep -q "run-hook.cmd" "$FAKE_HOME2/.claude/settings.json"'
fi

# --- Test 5: Migrate v4 project ---
echo ""
echo "=== Migrate v4 project ==="
V4_PROJECT="$tmp/v4project"
mkdir -p "$V4_PROJECT/.claude/skills/baton-plan"
mkdir -p "$V4_PROJECT/.claude/skills/baton-implement"
echo '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":".baton/hooks/run-hook.cmd PreToolUse"}]}]}}' > "$V4_PROJECT/.claude/settings.json"
echo '@.baton/constitution.md' > "$V4_PROJECT/CLAUDE.md"
echo '@.baton/constitution.md' > "$V4_PROJECT/AGENTS.md"

(
    export HOME="$FAKE_HOME"
    export BATON_HOME="$BATON_DIR"
    bash "$SETUP" --migrate "$V4_PROJECT" 2>&1
)

assert "v4 skill dirs removed" '[ ! -d "$V4_PROJECT/.claude/skills/baton-plan" ]'
if command -v jq >/dev/null 2>&1; then
    assert "v4 hooks removed from settings" '! grep -q "run-hook" "$V4_PROJECT/.claude/settings.json"'
fi
assert "v4 constitution removed from CLAUDE.md" '! grep -q "constitution" "$V4_PROJECT/CLAUDE.md" 2>/dev/null || [ ! -f "$V4_PROJECT/CLAUDE.md" ]'

# --- Summary ---
echo ""
echo "=== Results ==="
echo "$PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0

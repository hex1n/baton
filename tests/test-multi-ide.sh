#!/bin/bash
# test-multi-ide.sh — Tests for multi-IDE detection and configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Helper: detect_ides function for unit testing
run_detect_ides() {
    PROJECT_DIR="$1"
    _ides=""
    [ -d "$PROJECT_DIR/.claude" ]     && _ides="$_ides claude"
    [ -d "$PROJECT_DIR/.cursor" ]     && _ides="$_ides cursor"
    [ -d "$PROJECT_DIR/.windsurf" ]   && _ides="$_ides windsurf"
    [ -d "$PROJECT_DIR/.factory" ]    && _ides="$_ides factory"
    [ -d "$PROJECT_DIR/.clinerules" ] && _ides="$_ides cline"
    _ides="$(echo "$_ides" | sed 's/^ //')"
    [ -z "$_ides" ] && _ides="claude"
    echo "$_ides"
}

# ============================================================
echo "=== Test 1: Single IDE detection — only .claude ==="
d="$tmp/t1" && mkdir -p "$d/.claude"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if [ "$OUTPUT" = "claude" ]; then
    echo "  pass: single IDE detected: claude"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'claude', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: Multi IDE detection — .claude + .cursor ==="
d="$tmp/t2" && mkdir -p "$d/.claude" "$d/.cursor"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if [ "$OUTPUT" = "claude cursor" ]; then
    echo "  pass: multi IDE detected: claude cursor"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'claude cursor', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: No IDE → defaults to claude ==="
d="$tmp/t3" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if [ "$OUTPUT" = "claude" ]; then
    echo "  pass: no IDE → defaults to claude"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'claude', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: Multi IDE install — claude + cursor configured ==="
d="$tmp/t4" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# Check Claude settings
if [ -f "$d/.claude/settings.json" ] && grep -q 'write-lock' "$d/.claude/settings.json"; then
    echo "  pass: .claude/settings.json configured"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .claude/settings.json not properly configured"
    FAIL=$((FAIL + 1))
fi
# Check Cursor hooks
TOTAL=$((TOTAL + 1))
if [ -f "$d/.cursor/hooks.json" ] && grep -q 'adapter-cursor' "$d/.cursor/hooks.json"; then
    echo "  pass: .cursor/hooks.json configured"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .cursor/hooks.json not properly configured"
    FAIL=$((FAIL + 1))
fi
# Check Cursor rules
TOTAL=$((TOTAL + 1))
if [ -f "$d/.cursor/rules/baton.mdc" ]; then
    echo "  pass: .cursor/rules/baton.mdc created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .cursor/rules/baton.mdc not found"
    FAIL=$((FAIL + 1))
fi
# Check adapter installed
TOTAL=$((TOTAL + 1))
if [ -f "$d/.baton/adapters/adapter-cursor.sh" ]; then
    echo "  pass: adapter-cursor.sh installed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: adapter-cursor.sh not installed"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: Multi IDE install — claude + windsurf configured ==="
d="$tmp/t5" && mkdir -p "$d/.claude" "$d/.windsurf"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# Check Windsurf hooks
if [ -f "$d/.windsurf/hooks.json" ] && grep -q 'write-lock' "$d/.windsurf/hooks.json"; then
    echo "  pass: .windsurf/hooks.json configured with native hook"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .windsurf/hooks.json not properly configured"
    FAIL=$((FAIL + 1))
fi
# Check NO adapter-windsurf.sh (deprecated)
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/adapters/adapter-windsurf.sh" ]; then
    echo "  pass: adapter-windsurf.sh not installed (deprecated)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: adapter-windsurf.sh should not be installed"
    FAIL=$((FAIL + 1))
fi
# Check Windsurf rules
TOTAL=$((TOTAL + 1))
if [ -f "$d/.windsurf/rules/baton-workflow.md" ]; then
    echo "  pass: .windsurf/rules/baton-workflow.md created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .windsurf/rules/baton-workflow.md not found"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: Cursor hooks.json — correct structure ==="
d="$tmp/t6" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# Verify JSON structure
if grep -q '"version": 1' "$d/.cursor/hooks.json" && \
   grep -q '"sessionStart"' "$d/.cursor/hooks.json" && \
   grep -q '"preToolUse"' "$d/.cursor/hooks.json" && \
   grep -q 'phase-guide' "$d/.cursor/hooks.json"; then
    echo "  pass: hooks.json has correct structure"
    PASS=$((PASS + 1))
else
    echo "  FAIL: hooks.json structure incorrect"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: Windsurf hooks.json — correct structure ==="
d="$tmp/t7" && mkdir -p "$d/.windsurf"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
if grep -q '"pre_write_code"' "$d/.windsurf/hooks.json" && \
   grep -q 'write-lock.sh' "$d/.windsurf/hooks.json" && \
   grep -q '"show_output": true' "$d/.windsurf/hooks.json"; then
    echo "  pass: .windsurf/hooks.json has correct structure"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .windsurf/hooks.json structure incorrect"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: Workflow selection — slim for SessionStart IDEs ==="
d="$tmp/t8" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# .baton/workflow.md should be slim (not contain [RESEARCH] header from full)
if ! grep -q '^\[RESEARCH\]' "$d/.baton/workflow.md" 2>/dev/null; then
    echo "  pass: .baton/workflow.md is slim version"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/workflow.md should be slim when SessionStart IDEs present"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 9: Workflow selection — full for non-SessionStart only ==="
d="$tmp/t9" && mkdir -p "$d/.windsurf"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# Windsurf rules should get full workflow
if grep -q 'RESEARCH\|research' "$d/.windsurf/rules/baton-workflow.md" 2>/dev/null; then
    echo "  pass: .windsurf/rules/baton-workflow.md is full version"
    PASS=$((PASS + 1))
else
    echo "  FAIL: windsurf rules should get full workflow"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10: Existing hooks.json not overwritten ==="
d="$tmp/t10" && mkdir -p "$d/.cursor"
echo '{"version":1,"hooks":{"custom":[{"command":"echo hi"}]}}' > "$d/.cursor/hooks.json"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
# Should NOT overwrite existing hooks.json
if grep -q '"custom"' "$d/.cursor/hooks.json"; then
    echo "  pass: existing .cursor/hooks.json preserved"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .cursor/hooks.json was overwritten"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: Deprecated adapter-windsurf.sh cleaned up on re-install ==="
d="$tmp/t11" && mkdir -p "$d/.windsurf" "$d/.baton/adapters"
echo "#!/bin/sh" > "$d/.baton/adapters/adapter-windsurf.sh"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
if [ ! -f "$d/.baton/adapters/adapter-windsurf.sh" ]; then
    echo "  pass: deprecated adapter-windsurf.sh cleaned up"
    PASS=$((PASS + 1))
else
    echo "  FAIL: adapter-windsurf.sh should be removed on re-install"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 12: Pre-commit hook installed by default ==="
d="$tmp/t12" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
bash "$SETUP" "$d" > /dev/null 2>&1
if [ -f "$d/.git/hooks/pre-commit" ] && grep -q 'baton' "$d/.git/hooks/pre-commit"; then
    echo "  pass: pre-commit hook installed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-commit hook not installed"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 13: Pre-commit hook skipped with BATON_SKIP ==="
d="$tmp/t13" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit bash "$SETUP" "$d" > /dev/null 2>&1
if [ ! -f "$d/.git/hooks/pre-commit" ]; then
    echo "  pass: pre-commit hook skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-commit hook should be skipped"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi

#!/bin/bash
# test-setup.sh — Tests for setup.sh v2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

assert_file_exists() {
    TOTAL=$((TOTAL + 1))
    if [ -f "$1" ]; then
        echo "  pass: file exists '$(basename "$1")'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected file '$1' to exist"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_executable() {
    TOTAL=$((TOTAL + 1))
    if [ -x "$1" ]; then
        echo "  pass: file executable '$(basename "$1")'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected file '$1' to be executable"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_contains() {
    TOTAL=$((TOTAL + 1))
    if grep -q "$2" "$1" 2>/dev/null; then
        echo "  pass: '$(basename "$1")' contains '$2'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: '$(basename "$1")' should contain '$2'"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_contains() {
    TOTAL=$((TOTAL + 1))
    if grep -q "$2" "$1" 2>/dev/null; then
        echo "  FAIL: '$(basename "$1")' should NOT contain '$2'"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: '$(basename "$1")' does not contain '$2'"
        PASS=$((PASS + 1))
    fi
}

assert_output_contains() {
    TOTAL=$((TOTAL + 1))
    if echo "$1" | grep -q "$2"; then
        echo "  pass: output contains '$2'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: output should contain '$2'"
        FAIL=$((FAIL + 1))
    fi
}

assert_count() {
    local file="$1" pattern="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    local actual
    actual=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
    if [ "$actual" = "$expected" ]; then
        echo "  pass: '$pattern' appears $expected time(s)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: '$pattern' appears $actual time(s), expected $expected"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: Fresh install into empty directory ==="
d="$tmp/t1" && mkdir -p "$d"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
# .baton/ directory structure
assert_file_exists "$d/.baton/write-lock.sh"
assert_file_executable "$d/.baton/write-lock.sh"
assert_file_exists "$d/.baton/phase-guide.sh"
assert_file_executable "$d/.baton/phase-guide.sh"
assert_file_exists "$d/.baton/workflow.md"
assert_file_exists "$d/.baton/workflow-full.md"
# .claude/ settings
assert_file_exists "$d/.claude/settings.json"
assert_file_contains "$d/.claude/settings.json" ".baton/write-lock"
assert_file_contains "$d/.claude/settings.json" "PreToolUse"
assert_file_contains "$d/.claude/settings.json" "SessionStart"
assert_file_contains "$d/.claude/settings.json" "phase-guide"
assert_file_contains "$d/.claude/settings.json" "NotebookEdit"
# CLAUDE.md with @import
assert_file_exists "$d/CLAUDE.md"
assert_file_contains "$d/CLAUDE.md" "@.baton/workflow.md"
assert_output_contains "$OUTPUT" "Installing baton"

# ============================================================
echo ""
echo "=== Test 2: Default IDE detection (claude) ==="
d="$tmp/t2" && mkdir -p "$d"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDE: claude"
# Claude Code gets slim workflow (SessionStart support)
assert_file_contains "$d/.baton/workflow.md" "Phase-specific guidance is provided automatically"

# ============================================================
echo ""
echo "=== Test 3: Cursor IDE detection → full workflow ==="
d="$tmp/t3" && mkdir -p "$d/.cursor"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDE: cursor"
# Cursor gets full workflow (no SessionStart support)
assert_file_contains "$d/.baton/workflow.md" "RESEARCH"
assert_file_exists "$d/.cursor/rules/baton.mdc"
assert_file_contains "$d/.cursor/rules/baton.mdc" "alwaysApply"

# ============================================================
echo ""
echo "=== Test 4: Windsurf IDE detection ==="
d="$tmp/t4" && mkdir -p "$d/.windsurf"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDE: windsurf"
assert_file_exists "$d/.windsurf/rules/baton-workflow.md"

# ============================================================
echo ""
echo "=== Test 5: Cline IDE detection → adapter installed ==="
d="$tmp/t5" && mkdir -p "$d/.clinerules"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDE: cline"
assert_file_exists "$d/.baton/adapters/adapter-cline.sh"
assert_file_executable "$d/.baton/adapters/adapter-cline.sh"
assert_file_exists "$d/.clinerules/baton-workflow.md"

# ============================================================
echo ""
echo "=== Test 6: Existing settings.json without write-lock hook ==="
d="$tmp/t6" && mkdir -p "$d/.claude"
echo '{"permissions":{"allow":["Bash"]}}' > "$d/.claude/settings.json"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
# Should not overwrite settings.json
assert_file_contains "$d/.claude/settings.json" "permissions"
# Should warn about missing hooks
assert_output_contains "$OUTPUT" "write-lock hook"

# ============================================================
echo ""
echo "=== Test 7: Existing settings.json with v2 hook ==="
d="$tmp/t7" && mkdir -p "$d/.claude" "$d/.baton"
echo '{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"sh .baton/write-lock.sh"}]}]}}' > "$d/.claude/settings.json"
# Pre-install matching write-lock.sh so version check says "up to date"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
# Should detect the v2 path and report up to date
assert_output_contains "$OUTPUT" "up to date"

# ============================================================
echo ""
echo "=== Test 8: v1 → v2 migration (move write-lock.sh) ==="
d="$tmp/t8" && mkdir -p "$d/.claude"
# Install v1 layout
cat > "$d/.claude/write-lock.sh" << 'EOF'
#!/bin/sh
# Version: 1.0
echo "v1 lock"
EOF
chmod +x "$d/.claude/write-lock.sh"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Migrating from v1"
# v1 file should be gone, v2 should be in .baton/
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/write-lock.sh" ]; then
    echo "  pass: v1 write-lock.sh removed from .claude/"
    PASS=$((PASS + 1))
else
    echo "  FAIL: v1 write-lock.sh should be removed from .claude/"
    FAIL=$((FAIL + 1))
fi
assert_file_exists "$d/.baton/write-lock.sh"
assert_file_contains "$d/.baton/write-lock.sh" "Version: 2.0"

# ============================================================
echo ""
echo "=== Test 9: v1 settings.json path updated ==="
d="$tmp/t9" && mkdir -p "$d/.claude"
# v1 settings with old path
cat > "$d/.claude/settings.json" << 'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"sh .claude/write-lock.sh"}]}]}}
JSON
cat > "$d/.claude/write-lock.sh" << 'EOF'
#!/bin/sh
# Version: 1.0
EOF
chmod +x "$d/.claude/write-lock.sh"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_file_contains "$d/.claude/settings.json" ".baton/write-lock"
assert_file_not_contains "$d/.claude/settings.json" ".claude/write-lock"
assert_output_contains "$OUTPUT" ".claude/ → .baton/"

# ============================================================
echo ""
echo "=== Test 10: Legacy workflow detection in CLAUDE.md ==="
d="$tmp/t10" && mkdir -p "$d"
cat > "$d/CLAUDE.md" << 'EOF'
# My Project
## AI Workflow
Old inline workflow content
EOF
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Legacy workflow detected"
# Should NOT append @import when legacy workflow exists (user must clean up)
assert_file_not_contains "$d/CLAUDE.md" "@.baton/workflow.md"

# ============================================================
echo ""
echo "=== Test 11: Idempotent re-install ==="
d="$tmp/t11" && mkdir -p "$d"
bash "$SETUP" "$d" >/dev/null 2>&1
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
# @import should appear exactly once
assert_count "$d/CLAUDE.md" "@.baton/workflow.md" 1
assert_output_contains "$OUTPUT" "@import already"

# ============================================================
echo ""
echo "=== Test 12: Non-existent target directory ==="
TOTAL=$((TOTAL + 1))
if bash "$SETUP" "$tmp/nonexistent" 2>/dev/null; then
    echo "  FAIL: should error on non-existent directory"
    FAIL=$((FAIL + 1))
else
    echo "  pass: errored on non-existent directory"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 13: Upgrade from outdated version ==="
d="$tmp/t13" && mkdir -p "$d/.baton"
cat > "$d/.baton/write-lock.sh" << 'EOF'
#!/bin/sh
# Version: 0.1
echo "old version"
EOF
chmod +x "$d/.baton/write-lock.sh"
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "v0.1"
assert_output_contains "$OUTPUT" "Updated write-lock.sh"
assert_file_contains "$d/.baton/write-lock.sh" "Version: 2.0"

# ============================================================
echo ""
echo "=== Test 14: Same version already installed ==="
d="$tmp/t14" && mkdir -p "$d"
bash "$SETUP" "$d" >/dev/null 2>&1
OUTPUT="$(bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "up to date"

# ============================================================
echo ""
echo "=== Test 15: BATON_SKIP skips single component ==="
d="$tmp/t15" && mkdir -p "$d"
OUTPUT="$(BATON_SKIP="bash-guard" bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Skipped bash-guard.sh"
assert_file_exists "$d/.baton/write-lock.sh"
assert_file_exists "$d/.baton/phase-guide.sh"
assert_file_exists "$d/.baton/stop-guard.sh"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/bash-guard.sh" ]; then
    echo "  pass: bash-guard.sh not installed when skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: bash-guard.sh should not be installed when skipped"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 16: BATON_SKIP skips multiple components ==="
d="$tmp/t16" && mkdir -p "$d"
OUTPUT="$(BATON_SKIP="stop-guard,bash-guard" bash "$SETUP" "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Skipped stop-guard.sh"
assert_output_contains "$OUTPUT" "Skipped bash-guard.sh"
assert_file_exists "$d/.baton/write-lock.sh"
assert_file_exists "$d/.baton/phase-guide.sh"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/stop-guard.sh" ]; then
    echo "  pass: stop-guard.sh not installed when skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: stop-guard.sh should not be installed when skipped"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/bash-guard.sh" ]; then
    echo "  pass: bash-guard.sh not installed when skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: bash-guard.sh should not be installed when skipped"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17: --uninstall removes baton ==="
d="$tmp/t17" && mkdir -p "$d/.claude"
# First install
bash "$SETUP" "$d" > /dev/null 2>&1
assert_file_exists "$d/.baton/write-lock.sh"
assert_file_exists "$d/CLAUDE.md"
# Now uninstall
OUTPUT="$(bash "$SETUP" --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removing baton"
assert_output_contains "$OUTPUT" "Removed .baton/"
TOTAL=$((TOTAL + 1))
if [ ! -d "$d/.baton" ]; then
    echo "  pass: .baton/ directory removed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/ directory should be removed"
    FAIL=$((FAIL + 1))
fi
# CLAUDE.md should no longer have @import
TOTAL=$((TOTAL + 1))
if [ -f "$d/CLAUDE.md" ] && ! grep -q '@.baton/workflow.md' "$d/CLAUDE.md"; then
    echo "  pass: @import removed from CLAUDE.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: @import should be removed from CLAUDE.md"
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

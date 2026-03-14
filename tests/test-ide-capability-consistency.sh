#!/bin/bash
# test-ide-capability-consistency.sh — Verify IDE capability wording stays aligned
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

README="$ROOT_DIR/README.md"
MATRIX="$ROOT_DIR/docs/ide-capability-matrix.md"
LEGACY_RESEARCH="$ROOT_DIR/docs/research-ide-hooks.md"
SETUP="$ROOT_DIR/setup.sh"

assert_contains() {
    local file="$1"
    local text="$2"
    local label="$3"
    TOTAL=$((TOTAL + 1))
    if grep -Fq "$text" "$file"; then
        echo "  pass: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: missing $label"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local file="$1"
    local text="$2"
    local label="$3"
    TOTAL=$((TOTAL + 1))
    if grep -Fq "$text" "$file"; then
        echo "  FAIL: should not contain $label"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: $label"
        PASS=$((PASS + 1))
    fi
}

echo "=== IDE Capability Consistency (4-IDE scope) ==="

# Matrix: maintenance rule present
assert_contains "$MATRIX" 'Update this matrix before changing supported-IDE wording' "matrix maintenance rule"

# Matrix: 4 supported IDEs present
assert_contains "$MATRIX" '| Claude Code |' "matrix Claude Code row"
assert_contains "$MATRIX" '| Factory AI |' "matrix Factory AI row"
assert_contains "$MATRIX" '| Cursor IDE |' "matrix Cursor IDE row"
assert_contains "$MATRIX" '| Codex |' "matrix Codex row"

# README: 4 supported IDEs present
assert_contains "$README" '| Claude Code |' "README Claude Code row"
assert_contains "$README" '| Factory AI |' "README Factory AI row"
assert_contains "$README" '| Cursor IDE |' "README Cursor IDE row"
assert_contains "$README" '| Codex |' "README Codex row"
assert_contains "$README" '| Cursor IDE | **Core protection** |' "README Cursor IDE core protection wording"
assert_contains "$README" 'Experimental `SessionStart` + `Stop` hooks (best-effort)' "README Codex hook wording"

# README: removed IDEs absent
assert_not_contains "$README" '| Windsurf' "README no Windsurf row"
assert_not_contains "$README" '| Kiro' "README no Kiro row"
assert_not_contains "$README" '| Cline' "README no Cline row"
assert_not_contains "$README" '| Augment' "README no Augment row"
assert_not_contains "$README" '| Copilot' "README no Copilot row"
assert_not_contains "$README" '(no hooks)' "README no stale Codex no-hooks wording"

# Legacy research: maintenance rule and updated scope note
assert_contains "$LEGACY_RESEARCH" '维护规则：支持 IDE 的公开表述应先更新 [IDE Capability Matrix](./ide-capability-matrix.md)' "legacy research maintenance rule"
assert_contains "$LEGACY_RESEARCH" 'Baton supports 4 IDEs' "legacy research 4-IDE scope note"
assert_contains "$MATRIX" '2/9 experimental' "matrix Codex experimental hooks"
assert_contains "$MATRIX" 'SessionStart' "matrix SessionStart note"

# Setup: ide_summary entries for 4 IDEs
assert_contains "$SETUP" 'Cursor IDE hooks + adapter' "setup Cursor IDE summary"
assert_contains "$SETUP" 'session hooks + AGENTS.md rules + skills' "setup Codex summary"
assert_contains "$SETUP" 'full protection, native hooks + skills' "setup Claude summary"
assert_contains "$SETUP" 'full protection, Claude-style hooks + skills' "setup Factory summary"
assert_contains "$SETUP" 'core protection, Cursor IDE hooks + adapter' "setup Cursor core summary"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "Results: $PASS/$TOTAL passed, 0 failed"
    echo "ALL PASSED"
else
    echo "Results: $PASS/$TOTAL passed, $FAIL failed"
    exit 1
fi

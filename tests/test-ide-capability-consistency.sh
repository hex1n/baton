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

SCOPE_NOTE=$'Current implementation scope: Baton\'s current installer work covers Cursor IDE and the current Kiro `.amazonq` compatibility surface. This iteration does not add a first-class Amazon Q Developer CLI target, does not model Cursor CLI separately, and keeps Roo Code in rules-guidance mode.'

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

echo "=== IDE Capability Consistency ==="

assert_contains "$MATRIX" 'Update this matrix before changing supported-IDE wording in `README.md`, `setup.sh`, or installer-facing tests.' "matrix maintenance rule"
assert_contains "$MATRIX" "$SCOPE_NOTE" "matrix current-scope note"

assert_contains "$README" '| Cursor IDE |' "README Cursor IDE row"
assert_contains "$README" '| Kiro (`.amazonq` surface) |' "README Kiro compatibility-surface row"
assert_contains "$README" 'Cursor CLI hook parity is still partial and is not modeled separately here.' "README Cursor CLI scope note"
assert_contains "$README" 'Roo Code remains rules-guidance by default because Baton does not yet rely on a current official Roo hook integration.' "README Roo conservative note"
assert_contains "$README" "$SCOPE_NOTE" "README current-scope note"

assert_contains "$LEGACY_RESEARCH" '维护规则：支持 IDE 的公开表述应先更新 [IDE Capability Matrix](./ide-capability-matrix.md)，再同步到 `README.md`、`setup.sh` 和测试。' "legacy research maintenance rule"
assert_contains "$LEGACY_RESEARCH" "$SCOPE_NOTE" "legacy research current-scope note"

assert_contains "$SETUP" 'Cursor IDE hooks + adapter' "setup Cursor IDE summary"
assert_contains "$SETUP" 'Kiro compatibility surface (.amazonq) + skills' "setup Kiro compatibility summary"
assert_contains "$SETUP" 'rules guidance via .roo/rules + skills (no Baton hook integration)' "setup Roo conservative summary"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "Results: $PASS/$TOTAL passed, 0 failed"
    echo "ALL PASSED"
else
    echo "Results: $PASS/$TOTAL passed, $FAIL failed"
    exit 1
fi

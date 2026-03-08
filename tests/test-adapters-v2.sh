#!/bin/bash
# test-adapters-v2.sh — Tests for Cursor adapter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS="$SCRIPT_DIR/../.baton/adapters"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Helper: set up a test directory with write-lock.sh
setup_dir() {
    d="$tmp/$1" && mkdir -p "$d/.baton/adapters" "$d/.baton/hooks"
    cp "$SCRIPT_DIR/../.baton/hooks/_common.sh" "$d/.baton/hooks/_common.sh"
    cp "$SCRIPT_DIR/../.baton/hooks/write-lock.sh" "$d/.baton/hooks/write-lock.sh"
    chmod +x "$d/.baton/hooks/write-lock.sh"
    cp "$SCRIPT_DIR/../.baton/hooks/completion-check.sh" "$d/.baton/hooks/completion-check.sh"
    chmod +x "$d/.baton/hooks/completion-check.sh"
    # Copy the adapter under test
    if [ -n "${2:-}" ] && [ -f "$ADAPTERS/$2" ]; then
        cp "$ADAPTERS/$2" "$d/.baton/adapters/$2"
        chmod +x "$d/.baton/adapters/$2"
    fi
    echo "$d"
}

# ============================================================
echo "=== Cursor Adapter ==="
echo ""

echo "--- Test 1: Cursor adapter — allowed with BATON:GO ---"
d="$(setup_dir t1 adapter-cursor.sh)"
echo "<!-- BATON:GO -->" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"decision":"allow"'; then
    echo "  pass: returns {\"decision\":\"allow\"}"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected decision:allow, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Test 2: Cursor adapter — blocked without BATON:GO ---"
d="$(setup_dir t2 adapter-cursor.sh)"
echo "# Plan" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"decision":"deny"'; then
    echo "  pass: returns {\"decision\":\"deny\"}"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected decision:deny, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q '"reason"'; then
    echo "  pass: includes reason field"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should include reason field"
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

#!/bin/bash
# test-adapters-v2.sh — Tests for new/simplified adapters (Cursor, Copilot, Cline v2)
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
    cp "$SCRIPT_DIR/../.baton/hooks/write-lock.sh" "$d/.baton/hooks/write-lock.sh"
    chmod +x "$d/.baton/hooks/write-lock.sh"
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
echo "=== Copilot Adapter ==="
echo ""

echo "--- Test 3: Copilot adapter — allowed with BATON:GO ---"
d="$(setup_dir t3 adapter-copilot.sh)"
echo "<!-- BATON:GO -->" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-copilot.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"permissionDecision":"allow"'; then
    echo "  pass: returns {\"permissionDecision\":\"allow\"}"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected permissionDecision:allow, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Test 4: Copilot adapter — blocked without BATON:GO ---"
d="$(setup_dir t4 adapter-copilot.sh)"
echo "# Plan" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-copilot.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
    echo "  pass: returns {\"permissionDecision\":\"deny\"}"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected permissionDecision:deny, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q '"permissionDecisionReason"'; then
    echo "  pass: includes permissionDecisionReason field"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should include permissionDecisionReason field"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Cline Adapter (v2 — with tool filtering) ==="
echo ""

echo "--- Test 5: Cline adapter — write tool blocked ---"
d="$(setup_dir t5 adapter-cline.sh)"
echo "# Plan" > "$d/plan.md"
JSON='{"tool":"write_to_file","tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cline.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"cancel":true'; then
    echo "  pass: write_to_file blocked → cancel:true"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:true for write_to_file, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Test 6: Cline adapter — write tool allowed with GO ---"
d="$(setup_dir t6 adapter-cline.sh)"
echo "<!-- BATON:GO -->" > "$d/plan.md"
JSON='{"tool":"replace_in_file","tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cline.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"cancel":false'; then
    echo "  pass: replace_in_file allowed with GO → cancel:false"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:false for replace_in_file with GO, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Test 7: Cline adapter — non-write tool always allowed ---"
d="$(setup_dir t7 adapter-cline.sh)"
# No plan at all — but read_file should pass through
JSON='{"tool":"read_file","tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cline.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"cancel":false'; then
    echo "  pass: read_file always allowed → cancel:false"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:false for non-write tool, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Test 8: Cline adapter — insert_content blocked ---"
d="$(setup_dir t8 adapter-cline.sh)"
echo "# Plan" > "$d/plan.md"
JSON='{"tool":"insert_content","tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cline.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"cancel":true'; then
    echo "  pass: insert_content blocked → cancel:true"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:true for insert_content, got: $OUTPUT"
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

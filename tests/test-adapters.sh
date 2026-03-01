#!/bin/bash
# test-adapters.sh — Tests for cross-IDE adapters
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS="$SCRIPT_DIR/../.baton/adapters"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# ============================================================
echo "=== Test 1: Cline adapter — allowed → JSON cancel:false ==="
d="$tmp/t1" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
echo "<!-- BATON:GO -->" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-cline.sh" 2>/dev/null)"
if echo "$OUTPUT" | grep -q '"cancel":false'; then
    echo "  pass: cline adapter returns cancel:false when allowed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:false, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: Cline adapter — blocked → JSON cancel:true ==="
d="$tmp/t2" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
echo "# Plan" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-cline.sh" 2>/dev/null)"
if echo "$OUTPUT" | grep -q '"cancel":true'; then
    echo "  pass: cline adapter returns cancel:true when blocked"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:true, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
# Verify error message is included
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'errorMessage'; then
    echo "  pass: cline adapter includes errorMessage"
    PASS=$((PASS + 1))
else
    echo "  FAIL: cline adapter should include errorMessage"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: Cline adapter — no plan → JSON cancel:true ==="
d="$tmp/t3" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-cline.sh" 2>/dev/null)"
if echo "$OUTPUT" | grep -q '"cancel":true'; then
    echo "  pass: cline adapter blocks when no plan"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected cancel:true when no plan, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: Cline adapter — markdown → JSON cancel:false ==="
d="$tmp/t4" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
# No plan.md — but markdown should always be allowed
JSON='{"tool_input":{"file_path":"research.md"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-cline.sh" 2>/dev/null)"
if echo "$OUTPUT" | grep -q '"cancel":false'; then
    echo "  pass: cline adapter allows markdown files"
    PASS=$((PASS + 1))
else
    echo "  FAIL: cline adapter should allow markdown, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: Windsurf adapter — passes target via BATON_TARGET ==="
d="$tmp/t5" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
echo "<!-- BATON:GO -->" > "$d/plan.md"
# Windsurf format with file_path in tool_info
JSON='{"tool_info":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
if (cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-windsurf.sh" 2>/dev/null); then
    echo "  pass: windsurf adapter allowed write with GO"
    PASS=$((PASS + 1))
else
    echo "  FAIL: windsurf adapter should allow with GO"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: Windsurf adapter — blocked without GO ==="
d="$tmp/t6" && mkdir -p "$d/.baton"
cp "$SCRIPT_DIR/../.baton/write-lock.sh" "$d/.baton/write-lock.sh"
chmod +x "$d/.baton/write-lock.sh"
echo "# Plan" > "$d/plan.md"
JSON='{"tool_info":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
if (cd "$d" && printf '%s' "$JSON" | sh "$ADAPTERS/adapter-windsurf.sh" 2>/dev/null); then
    echo "  FAIL: windsurf adapter should block without GO"
    FAIL=$((FAIL + 1))
else
    echo "  pass: windsurf adapter blocked without GO"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: OpenCode plugin — file exists and has correct structure ==="
TOTAL=$((TOTAL + 1))
if [ -f "$SCRIPT_DIR/../.baton/adapters/opencode-plugin.mjs" ]; then
    echo "  pass: opencode-plugin.mjs exists"
    PASS=$((PASS + 1))
else
    echo "  FAIL: opencode-plugin.mjs not found"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -q 'BatonPlugin' "$SCRIPT_DIR/../.baton/adapters/opencode-plugin.mjs"; then
    echo "  pass: opencode-plugin.mjs exports BatonPlugin"
    PASS=$((PASS + 1))
else
    echo "  FAIL: opencode-plugin.mjs should export BatonPlugin"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -q 'BATON:GO' "$SCRIPT_DIR/../.baton/adapters/opencode-plugin.mjs"; then
    echo "  pass: opencode-plugin.mjs checks BATON:GO marker"
    PASS=$((PASS + 1))
else
    echo "  FAIL: opencode-plugin.mjs should check BATON:GO marker"
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

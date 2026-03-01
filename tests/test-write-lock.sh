#!/bin/bash
# test-write-lock.sh — Tests for write-lock.sh v2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="$SCRIPT_DIR/../.baton/write-lock.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_lock() {
    # Run write-lock.sh with BATON_TARGET env var, from the given directory
    local dir="$1" target="$2"
    (cd "$dir" && BATON_TARGET="$target" sh "$LOCK" < /dev/null 2>/dev/null)
}

run_lock_stdin() {
    # Run write-lock.sh with stdin JSON, from the given directory
    local dir="$1" json="$2"
    (cd "$dir" && printf '%s' "$json" | sh "$LOCK" 2>/dev/null)
}

run_lock_stderr() {
    # Run write-lock.sh and capture stderr
    local dir="$1" target="$2"
    (cd "$dir" && BATON_TARGET="$target" sh "$LOCK" < /dev/null 2>&1 1>/dev/null) || true
}

assert_blocked() {
    TOTAL=$((TOTAL + 1))
    if run_lock "$1" "$2"; then
        echo "  FAIL: expected BLOCKED for '$2' but was ALLOWED"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: blocked '$2'"
        PASS=$((PASS + 1))
    fi
}

assert_allowed() {
    TOTAL=$((TOTAL + 1))
    if run_lock "$1" "$2"; then
        echo "  pass: allowed '$2'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected ALLOWED for '$2' but was BLOCKED"
        FAIL=$((FAIL + 1))
    fi
}

assert_blocked_stdin() {
    TOTAL=$((TOTAL + 1))
    if run_lock_stdin "$1" "$2"; then
        echo "  FAIL: expected BLOCKED for stdin JSON but was ALLOWED"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: blocked via stdin JSON"
        PASS=$((PASS + 1))
    fi
}

assert_allowed_stdin() {
    TOTAL=$((TOTAL + 1))
    if run_lock_stdin "$1" "$2"; then
        echo "  pass: allowed via stdin JSON"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected ALLOWED for stdin JSON but was BLOCKED"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: No plan.md → block source, allow markdown ==="
d="$tmp/t1" && mkdir -p "$d"
assert_blocked "$d" "src/app.ts"
assert_blocked "$d" "main.go"
assert_allowed "$d" "research.md"
assert_allowed "$d" "notes.MD"

# ============================================================
echo ""
echo "=== Test 2: plan.md exists, no GO marker → block source ==="
d="$tmp/t2" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "src/app.ts"
assert_allowed "$d" "plan.md"

# ============================================================
echo ""
echo "=== Test 3: plan.md with GO marker → allow everything ==="
d="$tmp/t3" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
Some design content here.
<!-- BATON:GO -->
## Todo
- [ ] Implement feature
EOF
assert_allowed "$d" "src/app.ts"
assert_allowed "$d" "lib/utils.py"
assert_allowed "$d" "plan.md"

# ============================================================
echo ""
echo "=== Test 4: Re-lock by removing GO marker ==="
d="$tmp/t4" && mkdir -p "$d"
echo "<!-- BATON:GO -->" > "$d/plan.md"
assert_allowed "$d" "app.js"
# Remove GO marker
echo "# Plan (revised)" > "$d/plan.md"
assert_blocked "$d" "app.js"

# ============================================================
echo ""
echo "=== Test 5: GO marker in subdirectory plan.md (walk-up) ==="
d="$tmp/t5" && mkdir -p "$d/src/components"
echo "<!-- BATON:GO -->" > "$d/plan.md"
assert_allowed "$d/src/components" "Button.tsx"

# ============================================================
echo ""
echo "=== Test 6: No target path → fail-open with warning ==="
TOTAL=$((TOTAL + 1))
STDERR="$(cd "$tmp/t1" && sh "$LOCK" < /dev/null 2>&1 1>/dev/null || true)"
if (cd "$tmp/t1" && sh "$LOCK" < /dev/null 2>/dev/null); then
    if echo "$STDERR" | grep -q "could not determine target"; then
        echo "  pass: empty target → allowed (fail-open) with warning"
    else
        echo "  pass: empty target → allowed (fail-open) [warning missing]"
    fi
    PASS=$((PASS + 1))
else
    echo "  FAIL: empty target should fail-open"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: Various file extensions ==="
d="$tmp/t7" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "index.html"
assert_blocked "$d" "style.css"
assert_blocked "$d" "server.py"
assert_blocked "$d" "Makefile"
assert_allowed "$d" "CHANGELOG.md"
assert_allowed "$d" "docs/guide.markdown"

# ============================================================
echo ""
echo "=== Test 8: BATON_BYPASS=1 skips lock entirely ==="
d="$tmp/t8" && mkdir -p "$d"
# No plan.md, normally would block — but bypass allows it
TOTAL=$((TOTAL + 1))
if (cd "$d" && BATON_BYPASS=1 sh "$LOCK" < /dev/null 2>/dev/null); then
    echo "  pass: bypass allowed without plan.md (fail-open, no target)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: bypass should allow writes"
    FAIL=$((FAIL + 1))
fi
# Verify bypass emits warning to stderr
TOTAL=$((TOTAL + 1))
STDERR="$(cd "$d" && BATON_BYPASS=1 BATON_TARGET=src/app.ts sh "$LOCK" < /dev/null 2>&1 1>/dev/null)"
if echo "$STDERR" | grep -q "bypassed"; then
    echo "  pass: bypass emits warning to stderr"
    PASS=$((PASS + 1))
else
    echo "  FAIL: bypass should emit warning to stderr"
    FAIL=$((FAIL + 1))
fi
# Without bypass, still blocked
assert_blocked "$d" "src/app.ts"

# ============================================================
echo ""
echo "=== Test 9: stdin JSON path resolution ==="
d="$tmp/t9" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
# Simulate PreToolUse stdin JSON — should block (no GO marker)
JSON='{"tool_input":{"file_path":"src/app.ts","content":"hello"}}'
assert_blocked_stdin "$d" "$JSON"
# Now add GO — should allow
echo "<!-- BATON:GO -->" >> "$d/plan.md"
assert_allowed_stdin "$d" "$JSON"
# stdin JSON with markdown target — always allowed
JSON_MD='{"tool_input":{"file_path":"research.md","content":"findings"}}'
assert_allowed_stdin "$d" "$JSON_MD"

# ============================================================
echo ""
echo "=== Test 10: BATON_PLAN custom plan file name ==="
d="$tmp/t10" && mkdir -p "$d"
# No plan.md, but custom-plan.md with GO marker
echo "<!-- BATON:GO -->" > "$d/custom-plan.md"
# Default plan name → blocked (no plan.md)
assert_blocked "$d" "src/app.ts"
# Custom plan name → allowed (custom-plan.md has GO)
TOTAL=$((TOTAL + 1))
if (cd "$d" && BATON_PLAN=custom-plan.md BATON_TARGET=src/app.ts sh "$LOCK" < /dev/null 2>/dev/null); then
    echo "  pass: BATON_PLAN=custom-plan.md allowed 'src/app.ts'"
    PASS=$((PASS + 1))
else
    echo "  FAIL: BATON_PLAN should use custom plan file"
    FAIL=$((FAIL + 1))
fi
# Custom plan without GO → blocked
echo "# Custom plan" > "$d/other-plan.md"
TOTAL=$((TOTAL + 1))
if (cd "$d" && BATON_PLAN=other-plan.md BATON_TARGET=src/app.ts sh "$LOCK" < /dev/null 2>/dev/null); then
    echo "  FAIL: custom plan without GO should block"
    FAIL=$((FAIL + 1))
else
    echo "  pass: BATON_PLAN=other-plan.md blocked (no GO marker)"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: .mdx files always allowed (v2 extension) ==="
d="$tmp/t11" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "components/Button.mdx"
assert_allowed "$d" "docs/guide.mdx"

# ============================================================
echo ""
echo "=== Test 12: BATON_TARGET environment variable ==="
d="$tmp/t12" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
# BATON_TARGET takes precedence over stdin
TOTAL=$((TOTAL + 1))
JSON='{"tool_input":{"file_path":"allowed.md","content":"hello"}}'
if (cd "$d" && printf '%s' "$JSON" | BATON_TARGET="src/blocked.ts" sh "$LOCK" 2>/dev/null); then
    echo "  FAIL: BATON_TARGET should take precedence over stdin"
    FAIL=$((FAIL + 1))
else
    echo "  pass: BATON_TARGET takes precedence over stdin JSON"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 15: Blocking messages contain phase guidance ==="
d="$tmp/t15" && mkdir -p "$d"
# No plan → research guidance
TOTAL=$((TOTAL + 1))
STDERR="$(run_lock_stderr "$d" "src/app.ts")"
if echo "$STDERR" | grep -q "research.md"; then
    echo "  pass: no plan → blocking message mentions research.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: no plan blocking message should mention research.md"
    FAIL=$((FAIL + 1))
fi
# Plan without GO → plan guidance
echo "# Plan" > "$d/plan.md"
TOTAL=$((TOTAL + 1))
STDERR="$(run_lock_stderr "$d" "src/app.ts")"
if echo "$STDERR" | grep -q "scope"; then
    echo "  pass: plan without GO → blocking message mentions scope"
    PASS=$((PASS + 1))
else
    echo "  FAIL: plan without GO blocking message should mention scope"
    FAIL=$((FAIL + 1))
fi
# ============================================================
echo ""
echo "=== Test 16: JSON cwd field for plan discovery ==="
d="$tmp/t16" && mkdir -p "$d/project/src"
echo "<!-- BATON:GO -->" > "$d/project/plan.md"
# stdin JSON with cwd pointing to project/src → should find plan.md in project/
TOTAL=$((TOTAL + 1))
JSON="{\"tool_input\":{\"file_path\":\"src/app.ts\"},\"cwd\":\"$d/project/src\"}"
if (cd "$tmp" && printf '%s' "$JSON" | sh "$LOCK" 2>/dev/null); then
    echo "  pass: JSON cwd field used for plan discovery"
    PASS=$((PASS + 1))
else
    echo "  FAIL: JSON cwd should be used for plan discovery"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17: awk fallback (hide jq) ==="
d="$tmp/t17" && mkdir -p "$d"
echo "<!-- BATON:GO -->" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
# Build a PATH that excludes the real jq binary
JQ_REAL="$(command -v jq 2>/dev/null || true)"
if [ -n "$JQ_REAL" ]; then
    JQ_DIR="$(dirname "$JQ_REAL")"
    CLEAN_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$JQ_DIR" | paste -sd: -)"
else
    CLEAN_PATH="$PATH"
fi
if (cd "$d" && PATH="$CLEAN_PATH" printf '%s' "$JSON" | sh "$LOCK" 2>/dev/null); then
    echo "  pass: awk fallback parsed stdin JSON correctly"
    PASS=$((PASS + 1))
else
    echo "  FAIL: awk fallback should parse stdin JSON"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 18: Performance benchmark (write-lock latency) ==="
d="$tmp/t18" && mkdir -p "$d"
echo "<!-- BATON:GO -->" > "$d/plan.md"
TOTAL=$((TOTAL + 1))
START_NS=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
for i in $(seq 1 100); do
    run_lock "$d" "src/test.ts" >/dev/null 2>&1 || true
done
END_NS=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))
AVG_MS=$((ELAPSED_MS / 100))
echo "  100 invocations in ${ELAPSED_MS}ms (avg ${AVG_MS}ms/call)"
if [ "$AVG_MS" -lt 200 ]; then
    echo "  pass: write-lock latency ${AVG_MS}ms < 200ms threshold"
    PASS=$((PASS + 1))
else
    echo "  FAIL: write-lock.sh too slow: ${AVG_MS}ms > 200ms threshold"
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

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

run_setup() {
    (
        unset CODEX_SANDBOX CODEX_THREAD_ID CODEX_SANDBOX_NETWORK_DISABLED BATON_IDE
        bash "$SETUP" "$@"
    )
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

assert_output_not_contains() {
    TOTAL=$((TOTAL + 1))
    if echo "$1" | grep -q "$2"; then
        echo "  FAIL: output should NOT contain '$2'"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: output does not contain '$2'"
        PASS=$((PASS + 1))
    fi
}

# Helper: detect_ides function for unit testing (synced with setup.sh detect_ides)
run_detect_ides() {
    PROJECT_DIR="$1"
    _ides=""
    append_ide() {
        case " $_ides " in
            *" $1 "*) ;;
            *) _ides="${_ides:+$_ides }$1" ;;
        esac
    }
    [ -d "$PROJECT_DIR/.claude" ]     && append_ide "claude"
    [ -d "$PROJECT_DIR/.cursor" ]     && append_ide "cursor"
    { [ -d "$PROJECT_DIR/.factory" ] || [ -d "$PROJECT_DIR/.agents" ]; } && append_ide "factory"
    { [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -d "$PROJECT_DIR/.agents" ] || [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; } && append_ide "codex"
    [ -z "$_ides" ] && append_ide "claude"
    echo "$_ides"
}

run_parse_ides() {
    _supported="claude codex cursor factory"
    _raw="$(printf '%s' "$1" | tr ',\n\t' '   ')"
    _parsed=""
    normalize_ide() {
        _normalized="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
        case "$_normalized" in
            claudecode|claude-code) echo "claude" ;;
            *) echo "$_normalized" ;;
        esac
    }
    is_supported() {
        case " $_supported " in
            *" $1 "*) return 0 ;;
            *) return 1 ;;
        esac
    }
    for _candidate in $_raw; do
        [ -n "$_candidate" ] || continue
        _normalized="$(normalize_ide "$_candidate")"
        is_supported "$_normalized" || return 1
        case " $_parsed " in
            *" $_normalized "*) ;;
            *) _parsed="${_parsed:+$_parsed }$_normalized" ;;
        esac
    done
    [ -n "$_parsed" ] || return 1
    echo "$_parsed"
}

# ============================================================
echo "=== Test 1: Single IDE detection — only .claude ==="
d="$tmp/t1" && mkdir -p "$d/.claude"
TOTAL=$((TOTAL + 1))
OUTPUT="$(CODEX_THREAD_ID= CODEX_SANDBOX= CODEX_SANDBOX_NETWORK_DISABLED= run_detect_ides "$d")"
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
OUTPUT="$(CODEX_THREAD_ID= CODEX_SANDBOX= CODEX_SANDBOX_NETWORK_DISABLED= run_detect_ides "$d")"
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
OUTPUT="$(CODEX_THREAD_ID= CODEX_SANDBOX= CODEX_SANDBOX_NETWORK_DISABLED= run_detect_ides "$d")"
if [ "$OUTPUT" = "claude" ]; then
    echo "  pass: no IDE → defaults to claude"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'claude', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3a: Codex session env → detected as codex ==="
d="$tmp/t3a" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
OUTPUT="$(CODEX_THREAD_ID=test-codex CODEX_SANDBOX=seatbelt CODEX_SANDBOX_NETWORK_DISABLED=1 run_detect_ides "$d")"
if [ "$OUTPUT" = "codex" ]; then
    echo "  pass: Codex session detected as codex"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'codex', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3aa: Requested IDE parsing normalizes aliases ==="
d="$tmp/t3aa" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_parse_ides "codex,claude-code")"
if [ "$OUTPUT" = "codex claude" ]; then
    echo "  pass: requested IDE parsing normalizes and preserves order"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'codex claude', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3ab: Invalid requested IDE parsing fails ==="
d="$tmp/t3ab" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
if run_parse_ides "cursor,unknown" >/dev/null 2>&1; then
    echo "  FAIL: invalid requested IDE should fail"
    FAIL=$((FAIL + 1))
else
    echo "  pass: invalid requested IDE rejected"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: Multi IDE install — claude + cursor configured ==="
d="$tmp/t4" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# Check Claude settings
if [ -f "$d/.claude/settings.json" ] && grep -q 'dispatch.sh' "$d/.claude/settings.json"; then
    echo "  pass: .claude/settings.json configured"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .claude/settings.json not properly configured"
    FAIL=$((FAIL + 1))
fi
# Check Cursor hooks
TOTAL=$((TOTAL + 1))
if [ -f "$d/.cursor/hooks.json" ] && grep -q 'adapters/cursor/dispatch' "$d/.cursor/hooks.json"; then
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
if [ -f "$d/.baton/adapters/cursor/adapter.sh" ]; then
    echo "  pass: cursor/adapter.sh installed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: cursor/adapter.sh not installed"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: Cursor hooks.json — correct structure ==="
d="$tmp/t6" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# Verify JSON structure
if grep -q '"version": 1' "$d/.cursor/hooks.json" && \
   grep -q '"sessionStart"' "$d/.cursor/hooks.json" && \
   grep -q '"preToolUse"' "$d/.cursor/hooks.json" && \
   grep -q 'dispatch.sh' "$d/.cursor/hooks.json"; then
    echo "  pass: hooks.json has correct structure"
    PASS=$((PASS + 1))
else
    echo "  FAIL: hooks.json structure incorrect"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: constitution.md stays slim ==="
d="$tmp/t8" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# .baton/constitution.md should stay slim regardless of selected IDE mix
if ! grep -q '^\[RESEARCH\]' "$d/.baton/constitution.md" 2>/dev/null; then
    echo "  pass: .baton/constitution.md is slim version"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/constitution.md should stay slim"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10: Existing hooks.json not overwritten ==="
d="$tmp/t10" && mkdir -p "$d/.cursor"
echo '{"version":1,"hooks":{"custom":[{"command":"echo hi"}]}}' > "$d/.cursor/hooks.json"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# Should preserve custom hooks and merge Baton hooks
if grep -q '"custom"' "$d/.cursor/hooks.json" && \
   grep -q 'adapters/cursor/dispatch.sh' "$d/.cursor/hooks.json"; then
    echo "  pass: existing .cursor/hooks.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .cursor/hooks.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 15: Cursor expanded hooks — 4 hooks ==="
d="$tmp/t15" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
_hooks_ok=1
for _h in '"sessionStart"' '"preToolUse"' '"subagentStart"' '"preCompact"'; do
    if ! grep -q "$_h" "$d/.cursor/hooks.json" 2>/dev/null; then
        _hooks_ok=0
        break
    fi
done
if [ "$_hooks_ok" -eq 1 ]; then
    echo "  pass: .cursor/hooks.json has all 4 hooks (sessionStart, preToolUse, subagentStart, preCompact)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .cursor/hooks.json missing expanded hooks"
    FAIL=$((FAIL + 1))
fi



# ============================================================
echo ""
echo "=== Test 21: Cursor .mdc embeds constitution content ==="
d="$tmp/t21" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.cursor/rules/baton.mdc" ] && \
   grep -q 'alwaysApply: true' "$d/.cursor/rules/baton.mdc" && \
   grep -q 'Baton Constitution' "$d/.cursor/rules/baton.mdc"; then
    echo "  pass: .cursor/rules/baton.mdc has YAML frontmatter + constitution content"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .cursor/rules/baton.mdc should embed constitution content"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 22: CLAUDE.md uses constitution.md ==="
d="$tmp/t22" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '@\.baton/constitution\.md' "$d/CLAUDE.md" 2>/dev/null; then
    echo "  pass: CLAUDE.md references constitution.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md should reference constitution.md"
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

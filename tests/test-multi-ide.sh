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
    [ -d "$PROJECT_DIR/.windsurf" ]   && append_ide "windsurf"
    [ -d "$PROJECT_DIR/.factory" ]    && append_ide "factory"
    { [ -d "$PROJECT_DIR/.clinerules" ] || [ -d "$PROJECT_DIR/.cline" ]; } && append_ide "cline"
    [ -d "$PROJECT_DIR/.augment" ]    && append_ide "augment"
    [ -d "$PROJECT_DIR/.amazonq" ]    && append_ide "kiro"
    # Copilot: require copilot-specific files, not just .github/
    { [ -f "$PROJECT_DIR/.github/copilot-instructions.md" ] || \
      [ -f "$PROJECT_DIR/.github/hooks/baton.json" ]; } && append_ide "copilot"
    { [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; } && append_ide "codex"
    [ -f "$PROJECT_DIR/.rules" ]      && append_ide "zed"
    [ -d "$PROJECT_DIR/.roo" ]        && append_ide "roo"
    [ -z "$_ides" ] && append_ide "claude"
    echo "$_ides"
}

run_parse_ides() {
    _supported="claude factory cursor windsurf cline augment kiro copilot codex zed roo"
    _raw="$(printf '%s' "$1" | tr ',\n\t' '   ')"
    _parsed=""
    normalize_ide() {
        _normalized="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
        case "$_normalized" in
            amazonq|amazon-q) echo "kiro" ;;
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
OUTPUT="$(run_parse_ides "codex,amazonq,claude-code")"
if [ "$OUTPUT" = "codex kiro claude" ]; then
    echo "  pass: requested IDE parsing normalizes and preserves order"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'codex kiro claude', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3aaa: amazonq alias installs the shared kiro surface ==="
d="$tmp/t3aaa" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
OUTPUT="$(BATON_SKIP=pre-commit run_setup --ide amazonq "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'Selected IDEs: kiro (--ide)' && \
   echo "$OUTPUT" | grep -q 'Kiro compatibility surface (.amazonq)' && \
   [ -f "$d/.amazonq/hooks.json" ] && \
   [ ! -d "$d/.kiro" ]; then
    echo "  pass: amazonq alias keeps the current shared .amazonq/ target"
    PASS=$((PASS + 1))
else
    echo "  FAIL: amazonq alias should resolve to the current shared .amazonq/ target"
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
echo "=== Test 3b: .cline directory (no .clinerules) → detected as cline ==="
d="$tmp/t3b" && mkdir -p "$d/.cline"
TOTAL=$((TOTAL + 1))
OUTPUT="$(CODEX_THREAD_ID= CODEX_SANDBOX= CODEX_SANDBOX_NETWORK_DISABLED= run_detect_ides "$d")"
if [ "$OUTPUT" = "cline" ]; then
    echo "  pass: .cline-only detected as cline"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'cline', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3c: .clinerules directory → detected as cline ==="
d="$tmp/t3c" && mkdir -p "$d/.clinerules"
TOTAL=$((TOTAL + 1))
OUTPUT="$(CODEX_THREAD_ID= CODEX_SANDBOX= CODEX_SANDBOX_NETWORK_DISABLED= run_detect_ides "$d")"
if [ "$OUTPUT" = "cline" ]; then
    echo "  pass: .clinerules-only detected as cline"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'cline', got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: Multi IDE install — claude + cursor configured ==="
d="$tmp/t4" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
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
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
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
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
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
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
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
echo "=== Test 8: workflow.md stays slim ==="
d="$tmp/t8" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# .baton/workflow.md should stay slim regardless of selected IDE mix
if ! grep -q '^\[RESEARCH\]' "$d/.baton/workflow.md" 2>/dev/null; then
    echo "  pass: .baton/workflow.md is slim version"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/workflow.md should stay slim"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 9: Skill-capable non-SessionStart IDEs use slim workflow rules ==="
d="$tmp/t9" && mkdir -p "$d"
(cd "$d" && git init -q)
BATON_SKIP=pre-commit run_setup --ide windsurf,cline,kiro,roo,codex "$d" > /dev/null 2>&1
for f in \
    "$d/.windsurf/rules/baton-workflow.md" \
    "$d/.clinerules/baton-workflow.md" \
    "$d/.amazonq/rules/baton-workflow.md" \
    "$d/.roo/rules/baton-workflow.md"
do
    TOTAL=$((TOTAL + 1))
    if [ -f "$f" ] && ! grep -q '^\[RESEARCH\]' "$f" 2>/dev/null; then
        echo "  pass: $f uses slim workflow rules"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected slim workflow rules in $f"
        FAIL=$((FAIL + 1))
    fi
done
TOTAL=$((TOTAL + 1))
if grep -q '@\.baton/workflow\.md' "$d/AGENTS.md" 2>/dev/null; then
    echo "  pass: Codex AGENTS.md uses workflow.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Codex AGENTS.md should use workflow.md"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 9b: Rules-only IDEs keep workflow-full fallback ==="
d="$tmp/t9b" && mkdir -p "$d"
printf '# Existing rules\n' > "$d/.rules"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup --ide zed "$d" > /dev/null 2>&1
if grep -q '\.baton/workflow-full\.md' "$d/.rules" 2>/dev/null; then
    echo "  pass: Zed .rules keeps workflow-full fallback"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Zed .rules should reference workflow-full fallback"
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
   grep -q 'adapter-cursor.sh' "$d/.cursor/hooks.json" && \
   grep -q 'phase-guide.sh' "$d/.cursor/hooks.json"; then
    echo "  pass: existing .cursor/hooks.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .cursor/hooks.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10b: Existing Windsurf hooks.json gets Baton hooks merged ==="
d="$tmp/t10b" && mkdir -p "$d/.windsurf"
echo '{"hooks":{"custom":[{"command":"echo hi","show_output":false}]}}' > "$d/.windsurf/hooks.json"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '"custom"' "$d/.windsurf/hooks.json" && \
   grep -q 'write-lock.sh' "$d/.windsurf/hooks.json" && \
   grep -q 'bash-guard.sh' "$d/.windsurf/hooks.json" && \
   grep -q 'post-write-tracker.sh' "$d/.windsurf/hooks.json"; then
    echo "  pass: existing .windsurf/hooks.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .windsurf/hooks.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: Deprecated adapter-windsurf.sh cleaned up on re-install ==="
d="$tmp/t11" && mkdir -p "$d/.windsurf" "$d/.baton/adapters"
echo "#!/bin/sh" > "$d/.baton/adapters/adapter-windsurf.sh"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
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
run_setup "$d" > /dev/null 2>&1
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
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ ! -f "$d/.git/hooks/pre-commit" ]; then
    echo "  pass: pre-commit hook skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-commit hook should be skipped"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 14: Cline hook wiring — PreToolUse + TaskComplete ==="
d="$tmp/t14" && mkdir -p "$d/.clinerules"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.clinerules/hooks/PreToolUse" ] && grep -q 'adapter-cline' "$d/.clinerules/hooks/PreToolUse"; then
    echo "  pass: .clinerules/hooks/PreToolUse wired to adapter-cline.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .clinerules/hooks/PreToolUse not wired correctly"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ -f "$d/.clinerules/hooks/TaskComplete" ] && grep -q 'adapter-cline-taskcomplete' "$d/.clinerules/hooks/TaskComplete"; then
    echo "  pass: .clinerules/hooks/TaskComplete wired to adapter-cline-taskcomplete.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .clinerules/hooks/TaskComplete not wired correctly"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 14b: Existing Cline hook files are wrapped and preserved ==="
d="$tmp/t14b" && mkdir -p "$d/.clinerules/hooks"
cat > "$d/.clinerules/hooks/PreToolUse" << 'HOOK'
#!/bin/sh
echo '{"cancel":false,"contextModification":"user-pre"}'
HOOK
cat > "$d/.clinerules/hooks/TaskComplete" << 'HOOK'
#!/bin/sh
echo '{"cancel":false,"contextModification":"user-task"}'
HOOK
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.clinerules/hooks/PreToolUse.baton-user" ] && \
   [ -f "$d/.clinerules/hooks/TaskComplete.baton-user" ] && \
   grep -q 'baton-cline-wrapper' "$d/.clinerules/hooks/PreToolUse" && \
   grep -q 'PreToolUse.baton-user' "$d/.clinerules/hooks/PreToolUse" && \
   grep -q 'adapter-cline-taskcomplete' "$d/.clinerules/hooks/TaskComplete"; then
    echo "  pass: existing Cline hooks preserved and Baton wrappers installed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing Cline hooks should be preserved behind Baton wrappers"
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
echo "=== Test 16: Windsurf expanded hooks — 3 hooks ==="
d="$tmp/t16" && mkdir -p "$d/.windsurf"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
_hooks_ok=1
for _h in '"pre_write_code"' '"pre_run_command"' '"post_write_code"'; do
    if ! grep -q "$_h" "$d/.windsurf/hooks.json" 2>/dev/null; then
        _hooks_ok=0
        break
    fi
done
if [ "$_hooks_ok" -eq 1 ]; then
    echo "  pass: .windsurf/hooks.json has all 3 hooks (pre_write_code, pre_run_command, post_write_code)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .windsurf/hooks.json missing expanded hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17: New IDE — Augment configured ==="
d="$tmp/t17" && mkdir -p "$d/.augment"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.augment/settings.json" ] && grep -q 'baton' "$d/.augment/settings.json"; then
    echo "  pass: .augment/settings.json configured"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .augment/settings.json not configured"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ -f "$d/.augment/rules/baton-workflow.md" ]; then
    echo "  pass: .augment/rules/baton-workflow.md created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .augment/rules/baton-workflow.md not found"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17b: Existing Augment settings.json gets Baton hooks merged ==="
d="$tmp/t17b" && mkdir -p "$d/.augment"
cat > "$d/.augment/settings.json" << 'JSON'
{"hooks":{"custom":[{"matcher":"","hooks":[{"type":"command","command":"echo hi"}]}]}}
JSON
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '"custom"' "$d/.augment/settings.json" && \
   grep -q 'phase-guide.sh' "$d/.augment/settings.json" && \
   grep -q 'write-lock.sh' "$d/.augment/settings.json"; then
    echo "  pass: existing .augment/settings.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .augment/settings.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 18: New IDE — Kiro (Amazon Q) configured ==="
d="$tmp/t18" && mkdir -p "$d/.amazonq"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.amazonq/hooks.json" ] && grep -q 'baton' "$d/.amazonq/hooks.json"; then
    echo "  pass: .amazonq/hooks.json configured"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .amazonq/hooks.json not configured"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ -f "$d/.amazonq/rules/baton-workflow.md" ]; then
    echo "  pass: .amazonq/rules/baton-workflow.md created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .amazonq/rules/baton-workflow.md not found"
    FAIL=$((FAIL + 1))
fi
# Skills should go to .amazonq/skills/, not .kiro/skills/
TOTAL=$((TOTAL + 1))
if [ -f "$d/.amazonq/skills/baton-research/SKILL.md" ]; then
    echo "  pass: Kiro skills installed in .amazonq/skills/"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Kiro skills not in .amazonq/skills/"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ ! -d "$d/.kiro/skills" ]; then
    echo "  pass: no stale .kiro/skills/ created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: stale .kiro/skills/ created alongside .amazonq"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 18b: Existing .amazonq/hooks.json gets Baton hooks merged ==="
d="$tmp/t18b" && mkdir -p "$d/.amazonq"
echo '{"hooks":{"custom":[{"matcher":"cmd","command":"echo hi","timeout_ms":1}]}}' > "$d/.amazonq/hooks.json"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '"custom"' "$d/.amazonq/hooks.json" && \
   grep -q 'write-lock.sh' "$d/.amazonq/hooks.json"; then
    echo "  pass: existing .amazonq/hooks.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .amazonq/hooks.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19: New IDE — Copilot configured ==="
d="$tmp/t19" && mkdir -p "$d/.github"
touch "$d/.github/copilot-instructions.md"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.github/hooks/baton.json" ]; then
    echo "  pass: .github/hooks/baton.json created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .github/hooks/baton.json not found"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -q 'baton' "$d/.github/copilot-instructions.md" 2>/dev/null; then
    echo "  pass: copilot-instructions.md updated with baton reference"
    PASS=$((PASS + 1))
else
    echo "  FAIL: copilot-instructions.md not updated"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19b: Existing Copilot baton.json gets Baton hooks merged ==="
d="$tmp/t19b" && mkdir -p "$d/.github/hooks"
cat > "$d/.github/hooks/baton.json" << 'JSON'
{"version":1,"hooks":{"custom":[{"type":"command","bash":"echo hi"}]}}
JSON
touch "$d/.github/copilot-instructions.md"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '"custom"' "$d/.github/hooks/baton.json" && \
   grep -q 'phase-guide.sh' "$d/.github/hooks/baton.json" && \
   grep -q 'adapter-copilot.sh' "$d/.github/hooks/baton.json"; then
    echo "  pass: existing .github/hooks/baton.json preserved and Baton hooks merged"
    PASS=$((PASS + 1))
else
    echo "  FAIL: existing .github/hooks/baton.json should preserve custom hooks and merge Baton hooks"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19c: Copilot uninstall removes Baton hooks but preserves custom hooks ==="
d="$tmp/t19c" && mkdir -p "$d/.github/hooks"
cat > "$d/.github/hooks/baton.json" << 'JSON'
{"version":1,"hooks":{"custom":[{"type":"command","bash":"echo hi"}]}}
JSON
touch "$d/.github/copilot-instructions.md"
(cd "$d" && git init -q)
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed Baton hooks from .github/hooks/baton.json"
TOTAL=$((TOTAL + 1))
if [ -f "$d/.github/hooks/baton.json" ] && \
   grep -q 'echo hi' "$d/.github/hooks/baton.json" && \
   ! grep -q '.baton/' "$d/.github/hooks/baton.json"; then
    echo "  pass: Copilot uninstall preserves custom hooks and removes Baton entries"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Copilot uninstall should preserve custom hooks and remove Baton entries"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19d: Copilot uninstall preserves custom .baton hook ref ==="
d="$tmp/t19d" && mkdir -p "$d/.github/hooks"
touch "$d/.github/copilot-instructions.md"
(cd "$d" && git init -q)
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
jq '.hooks.custom += [{"type":"command","bash":"bash .baton/hooks/company-check.sh"}]' \
   "$d/.github/hooks/baton.json" > "$d/.github/hooks/baton.json.tmp"
mv "$d/.github/hooks/baton.json.tmp" "$d/.github/hooks/baton.json"
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed Baton hooks from .github/hooks/baton.json"
assert_output_contains "$OUTPUT" "still references .baton/ — preserved .baton/ for safety"
TOTAL=$((TOTAL + 1))
if [ -f "$d/.github/hooks/baton.json" ] && \
   grep -q 'company-check.sh' "$d/.github/hooks/baton.json"; then
    echo "  pass: Copilot uninstall keeps non-Baton .baton hook refs"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Copilot uninstall should keep non-Baton .baton hook refs"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ -d "$d/.baton" ]; then
    echo "  pass: .baton/ preserved for Copilot custom .baton hook refs"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/ should be preserved for Copilot custom .baton hook refs"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 20: New IDE — Roo Code configured ==="
d="$tmp/t20" && mkdir -p "$d/.roo"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.roo/rules/baton-workflow.md" ]; then
    echo "  pass: .roo/rules/baton-workflow.md created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .roo/rules/baton-workflow.md not found"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 21: Cursor .mdc embeds slim workflow content ==="
d="$tmp/t21" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if [ -f "$d/.cursor/rules/baton.mdc" ] && \
   grep -q 'alwaysApply: true' "$d/.cursor/rules/baton.mdc" && \
   grep -q 'Shared Understanding Construction Protocol' "$d/.cursor/rules/baton.mdc"; then
    echo "  pass: .cursor/rules/baton.mdc has YAML frontmatter + workflow content"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .cursor/rules/baton.mdc should embed workflow content"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 22: CLAUDE.md uses slim workflow.md ==="
d="$tmp/t22" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
if grep -q '@\.baton/workflow\.md' "$d/CLAUDE.md" 2>/dev/null; then
    echo "  pass: CLAUDE.md references workflow.md (slim)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md should reference workflow.md (slim)"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 23: Copilot detection — .github/ alone does NOT trigger ==="
d="$tmp/t23" && mkdir -p "$d/.github"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if echo "$OUTPUT" | grep -q 'copilot'; then
    echo "  FAIL: .github/ alone should NOT detect copilot, got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
else
    echo "  pass: .github/ alone does not trigger copilot detection"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 24: Copilot detection — copilot-instructions.md triggers ==="
d="$tmp/t24" && mkdir -p "$d/.github"
touch "$d/.github/copilot-instructions.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if echo "$OUTPUT" | grep -q 'copilot'; then
    echo "  pass: copilot-instructions.md triggers copilot detection"
    PASS=$((PASS + 1))
else
    echo "  FAIL: copilot-instructions.md should trigger copilot, got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 25: Copilot detection — baton.json triggers ==="
d="$tmp/t25" && mkdir -p "$d/.github/hooks"
echo '{"hooks":{}}' > "$d/.github/hooks/baton.json"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
if echo "$OUTPUT" | grep -q 'copilot'; then
    echo "  pass: .github/hooks/baton.json triggers copilot detection"
    PASS=$((PASS + 1))
else
    echo "  FAIL: baton.json should trigger copilot, got: '$OUTPUT'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 26: Uninstall cleans new IDE artifacts ==="
d="$tmp/t26" && mkdir -p "$d/.augment" "$d/.amazonq" "$d/.github" "$d/.roo"
touch "$d/.github/copilot-instructions.md"
(cd "$d" && git init -q)
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# Now uninstall
run_setup --uninstall "$d" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.augment/rules/baton-workflow.md" ] && \
   [ ! -f "$d/.amazonq/rules/baton-workflow.md" ] && \
   [ ! -f "$d/.github/hooks/baton.json" ] && \
   [ ! -f "$d/.roo/rules/baton-workflow.md" ]; then
    echo "  pass: new IDE artifacts cleaned up on uninstall"
    PASS=$((PASS + 1))
else
    echo "  FAIL: some new IDE artifacts remain after uninstall"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 27: New IDEs detected in detect_ides ==="
d="$tmp/t27" && mkdir -p "$d/.augment" "$d/.amazonq" "$d/.roo"
touch "$d/.rules"
touch "$d/AGENTS.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_detect_ides "$d")"
_ok=1
for _ide in augment kiro codex zed roo; do
    if ! echo "$OUTPUT" | grep -q "$_ide"; then
        echo "  FAIL: $_ide not detected in: '$OUTPUT'"
        _ok=0
    fi
done
if [ "$_ok" -eq 1 ]; then
    echo "  pass: all new IDEs detected: $OUTPUT"
    PASS=$((PASS + 1))
else
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

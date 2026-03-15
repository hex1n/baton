#!/bin/bash
# test-setup.sh — Tests for setup.sh v3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"
WRITE_LOCK_VERSION="$(sed -n 's/^# Version: *//p' "$SCRIPT_DIR/../.baton/hooks/write-lock.sh" 2>/dev/null | head -1)"
PHASE_GUIDE_VERSION="$(sed -n 's/^# Version: *//p' "$SCRIPT_DIR/../.baton/hooks/phase-guide.sh" 2>/dev/null | head -1)"
PASS=0
FAIL=0
TOTAL=0
ORIGINAL_HOME="${HOME:-}"

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_setup() {
    (
        unset CODEX_SANDBOX CODEX_THREAD_ID CODEX_SANDBOX_NETWORK_DISABLED BATON_IDE
        _test_home="${BATON_TEST_HOME:-$HOME}"
        if [ "$_test_home" = "$ORIGINAL_HOME" ]; then
            _test_home="$tmp/home-default"
        fi
        mkdir -p "$_test_home"
        HOME="$_test_home" bash "$SETUP" "$@"
    )
}

run_setup_as_codex() {
    (
        unset BATON_IDE
        _codex_home="${BATON_TEST_CODEX_HOME:-$tmp/codex-home-default}"
        mkdir -p "$_codex_home"
        HOME="$_codex_home" \
        CODEX_THREAD_ID="test-codex-thread" \
        CODEX_SANDBOX="seatbelt" \
        CODEX_SANDBOX_NETWORK_DISABLED="1" \
        bash "$SETUP" "$@"
    )
}

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

assert_file_not_exists() {
    TOTAL=$((TOTAL + 1))
    if [ ! -f "$1" ]; then
        echo "  pass: $1 does not exist"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $1 should not exist"
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
OUTPUT="$(run_setup "$d" 2>&1)"
# .baton/ directory structure
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_executable "$d/.baton/hooks/write-lock.sh"
assert_file_exists "$d/.baton/hooks/plan-parser.sh"
assert_file_executable "$d/.baton/hooks/plan-parser.sh"
assert_file_exists "$d/.baton/hooks/phase-guide.sh"
assert_file_executable "$d/.baton/hooks/phase-guide.sh"
assert_file_exists "$d/.baton/workflow.md"
assert_file_not_exists "$d/.baton/workflow-full.md"
# .claude/ settings
assert_file_exists "$d/.claude/settings.json"
assert_file_contains "$d/.claude/settings.json" ".baton/hooks/write-lock"
assert_file_contains "$d/.claude/settings.json" "PreToolUse"
assert_file_contains "$d/.claude/settings.json" "SessionStart"
assert_file_contains "$d/.claude/settings.json" "phase-guide"
assert_file_contains "$d/.claude/settings.json" "NotebookEdit"
# failure-tracker hook
assert_file_exists "$d/.baton/hooks/failure-tracker.sh"
assert_file_contains "$d/.claude/settings.json" "failure-tracker"
assert_file_contains "$d/.claude/settings.json" "PostToolUseFailure"
# CLAUDE.md with @import
assert_file_exists "$d/CLAUDE.md"
assert_file_contains "$d/CLAUDE.md" "@.baton/workflow.md"
assert_output_contains "$OUTPUT" "Installing baton"
assert_output_contains "$OUTPUT" "research file, plan file, or chat"
assert_output_contains "$OUTPUT" "simple changes may skip straight to planning"
assert_output_contains "$OUTPUT" "Free-text is the default"
assert_output_contains "$OUTPUT" "\[PAUSE\]"
assert_output_not_contains "$OUTPUT" "Give feedback in plan.md or chat"
assert_output_not_contains "$OUTPUT" "Annotate plan.md with \[NOTE\]"
assert_output_not_contains "$OUTPUT" "\[Q\]"
assert_output_not_contains "$OUTPUT" "\[CHANGE\]"
assert_output_not_contains "$OUTPUT" "\[DEEPER\]"
assert_output_not_contains "$OUTPUT" "\[MISSING\]"
assert_output_not_contains "$OUTPUT" "\[RESEARCH-GAP\]"

# ============================================================
echo ""
echo "=== Test 2: Default IDE detection (claude) ==="
d="$tmp/t2" && mkdir -p "$d"
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude"
assert_output_contains "$OUTPUT" "Selected IDEs: claude (auto)"
# Claude Code gets slim workflow (SessionStart support)
assert_file_contains "$d/.baton/workflow.md" "Shared Understanding Construction Protocol"
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-review/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-subagent/SKILL.md"

# ============================================================
echo ""
echo "=== Test 2a: Baton-generated .agents fallback does not trigger Codex/Factory on re-run ==="
d="$tmp/t2a" && mkdir -p "$d/.claude"
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
OUTPUT="$(BATON_SKIP=pre-commit run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude"
assert_output_contains "$OUTPUT" "Selected IDEs: claude (auto)"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/AGENTS.md" ]; then
    echo "  pass: fallback .agents directory does not bootstrap Codex on re-run"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Baton-generated .agents fallback should not auto-bootstrap Codex on re-run"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2a2: Legacy Baton-only .agents fallback is ignored during detection ==="
d="$tmp/t2a2" && mkdir -p "$d/.claude" "$d/.agents/skills/baton-research" "$d/.agents/skills/baton-plan"
echo "legacy fallback" > "$d/.agents/skills/baton-research/SKILL.md"
echo "legacy fallback" > "$d/.agents/skills/baton-plan/SKILL.md"
OUTPUT="$(BATON_SKIP=pre-commit run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude"
assert_output_contains "$OUTPUT" "Selected IDEs: claude (auto)"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/AGENTS.md" ]; then
    echo "  pass: legacy Baton-only .agents fallback does not count as Codex/Factory signal"
    PASS=$((PASS + 1))
else
    echo "  FAIL: legacy Baton-only .agents fallback should be ignored"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2b: Codex session detection → AGENTS.md + .agents skills ==="
d="$tmp/t2b" && mkdir -p "$d"
OUTPUT="$(run_setup_as_codex "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: codex"
assert_output_contains "$OUTPUT" "Selected IDEs: codex (auto)"
assert_file_exists "$d/AGENTS.md"
assert_file_contains "$d/AGENTS.md" "@.baton/workflow.md"
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-review/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-subagent/SKILL.md"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ]; then
    echo "  pass: Codex install does not create Claude hooks"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Codex install should not create .claude/settings.json"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2b2: Codex install creates hooks.json + feature flag + trust (HOME isolated) ==="
d="$tmp/t2b2" && mkdir -p "$d"
FAKE_HOME="$tmp/fakehome-2b2"
mkdir -p "$FAKE_HOME"
OUTPUT="$(HOME="$FAKE_HOME" run_setup --ide codex "$d" 2>&1)"
assert_file_exists "$d/.codex/hooks.json"
assert_file_contains "$d/.codex/hooks.json" "adapter-codex.sh phase-guide"
assert_file_contains "$d/.codex/hooks.json" "adapter-codex.sh stop-guard"
assert_file_contains "$d/.codex/hooks.json" "SessionStart"
assert_file_contains "$d/.codex/hooks.json" "Stop"
assert_file_exists "$d/.codex/config.toml"
assert_file_contains "$d/.codex/config.toml" "codex_hooks = true"
assert_file_exists "$FAKE_HOME/.codex/config.toml"
assert_file_contains "$FAKE_HOME/.codex/config.toml" "baton:codex-trust:"
assert_file_contains "$FAKE_HOME/.codex/config.toml" "trust_level"
assert_output_contains "$OUTPUT" "Created .codex/hooks.json"
assert_output_contains "$OUTPUT" "codex_hooks feature flag"
assert_output_contains "$OUTPUT" "trust"
assert_file_exists "$d/.baton/adapters/adapter-codex.sh"

# ============================================================
echo ""
echo "=== Test 2b3: Codex re-install is idempotent (hooks.json merge) ==="
d="$tmp/t2b2"  # reuse t2b2 directory
FAKE_HOME="$tmp/fakehome-2b2"
OUTPUT="$(HOME="$FAKE_HOME" run_setup --ide codex "$d" 2>&1)"
assert_output_contains "$OUTPUT" "already"
assert_file_contains "$d/.codex/hooks.json" "adapter-codex.sh phase-guide"

# ============================================================
echo ""
echo "=== Test 2b4: Codex install tolerates unwritable HOME trust config ==="
d="$tmp/t2b4" && mkdir -p "$d"
FAKE_HOME="$tmp/fakehome-2b4"
mkdir -p "$FAKE_HOME"
chmod 500 "$FAKE_HOME"
TOTAL=$((TOTAL + 1))
if OUTPUT="$(HOME="$FAKE_HOME" run_setup --ide codex "$d" 2>&1)"; then
    echo "  pass: codex install still succeeds with unwritable HOME"
    PASS=$((PASS + 1))
else
    echo "  FAIL: codex install should fail-open when HOME trust config is unwritable"
    FAIL=$((FAIL + 1))
fi
chmod 700 "$FAKE_HOME"
assert_file_exists "$d/.codex/hooks.json"
assert_file_contains "$d/.codex/config.toml" "codex_hooks = true"
assert_output_contains "$OUTPUT" "manually"

# ============================================================
echo ""
echo "=== Test 2c: Explicit --ide codex bootstraps Codex outside session ==="
d="$tmp/t2c" && mkdir -p "$d"
FAKE_HOME="$tmp/fakehome-2c"
mkdir -p "$FAKE_HOME"
OUTPUT="$(HOME="$FAKE_HOME" run_setup --ide codex "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude"
assert_output_contains "$OUTPUT" "Selected IDEs: codex (--ide)"
assert_file_exists "$d/AGENTS.md"
assert_file_contains "$d/AGENTS.md" "@.baton/workflow.md"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ]; then
    echo "  pass: explicit Codex selection does not create Claude hooks"
    PASS=$((PASS + 1))
else
    echo "  FAIL: explicit Codex selection should not create .claude/settings.json"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2c2: .agents/ dir without AGENTS.md → auto-detect factory + codex ==="
d="$tmp/t2c2" && mkdir -p "$d/.agents"
FAKE_HOME="$tmp/fakehome-2c2"
mkdir -p "$FAKE_HOME"
OUTPUT="$(HOME="$FAKE_HOME" run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "factory"
assert_output_contains "$OUTPUT" "codex"
assert_file_exists "$d/AGENTS.md"
assert_file_contains "$d/AGENTS.md" "@.baton/workflow.md"

# ============================================================
echo ""
echo "=== Test 2d: Explicit --ide overrides detected IDEs ==="
d="$tmp/t2d" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
OUTPUT="$(BATON_SKIP=pre-commit run_setup --ide cursor "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude cursor"
assert_output_contains "$OUTPUT" "Selected IDEs: cursor (--ide)"
assert_file_exists "$d/.cursor/hooks.json"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ] && [ ! -f "$d/CLAUDE.md" ]; then
    echo "  pass: unselected Claude config is not installed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: explicit cursor selection should not install Claude config"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2e: --choose installs only the chosen IDEs ==="
d="$tmp/t2e" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
FAKE_HOME="$tmp/fakehome-2e"
mkdir -p "$FAKE_HOME"
OUTPUT="$(printf '2\n' | HOME="$FAKE_HOME" BATON_SKIP=pre-commit run_setup --choose "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude cursor"
assert_output_contains "$OUTPUT" "1. claude - full protection"
assert_output_contains "$OUTPUT" "2. codex - session hooks"
assert_output_contains "$OUTPUT" "3. cursor - core protection, Cursor IDE hooks + adapter"
assert_output_contains "$OUTPUT" "Select IDEs"
assert_output_contains "$OUTPUT" "Selected IDEs: codex (--choose)"
assert_file_exists "$d/AGENTS.md"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ] && [ ! -f "$d/.cursor/hooks.json" ]; then
    echo "  pass: choose mode installs only Codex config"
    PASS=$((PASS + 1))
else
    echo "  FAIL: choose mode should not install unselected IDE configs"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2f: Invalid --ide value fails fast ==="
d="$tmp/t2f" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
if run_setup --ide not-an-ide "$d" >/dev/null 2>&1; then
    echo "  FAIL: invalid --ide should error"
    FAIL=$((FAIL + 1))
else
    echo "  pass: invalid --ide rejected"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 2g: Interactive default prompts for IDE selection ==="
d="$tmp/t2g" && mkdir -p "$d/.claude" "$d/.cursor"
OUTPUT="$(printf '3\n' | BATON_ASSUME_INTERACTIVE=1 run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: claude cursor"
assert_output_contains "$OUTPUT" "Select IDEs"
assert_output_contains "$OUTPUT" "Selected IDEs: cursor (interactive default)"
assert_file_exists "$d/.cursor/hooks.json"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ] && [ ! -f "$d/CLAUDE.md" ]; then
    echo "  pass: interactive default installs only chosen IDE config"
    PASS=$((PASS + 1))
else
    echo "  FAIL: interactive default should not install unchosen Claude config"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2h: --choose accepts compact numeric selections ==="
d="$tmp/t2h" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
FAKE_HOME="$tmp/fakehome-2h"
mkdir -p "$FAKE_HOME"
OUTPUT="$(printf '32\n' | HOME="$FAKE_HOME" BATON_SKIP=pre-commit run_setup --choose "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Selected IDEs: cursor codex (--choose)"
assert_file_exists "$d/.cursor/hooks.json"
assert_file_exists "$d/AGENTS.md"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/settings.json" ]; then
    echo "  pass: compact numeric choice skips unselected Claude config"
    PASS=$((PASS + 1))
else
    echo "  FAIL: compact numeric choice should not install Claude config"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2j: --help documents current capability scope ==="
OUTPUT="$(run_setup --help 2>&1)"
assert_output_contains "$OUTPUT" "cursor = Cursor IDE"

# ============================================================
echo ""
echo "=== Test 3: Cursor IDE detection → slim workflow + hooks ==="
d="$tmp/t3" && mkdir -p "$d/.cursor"
(cd "$d" && git init -q)
OUTPUT="$(BATON_SKIP=pre-commit run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Detected IDEs: cursor"
# Cursor now has SessionStart hook support → slim workflow
assert_file_exists "$d/.baton/workflow.md"
assert_file_exists "$d/.cursor/rules/baton.mdc"
assert_file_contains "$d/.cursor/rules/baton.mdc" "alwaysApply"
assert_file_exists "$d/.cursor/hooks.json"
assert_file_contains "$d/.cursor/hooks.json" "adapter-cursor"

# ============================================================
echo ""
echo "=== Test 6: Existing settings.json without write-lock hook ==="
d="$tmp/t6" && mkdir -p "$d/.claude"
echo '{"permissions":{"allow":["Bash"]}}' > "$d/.claude/settings.json"
OUTPUT="$(run_setup "$d" 2>&1)"
# Should preserve existing settings and merge missing Baton hooks
assert_file_contains "$d/.claude/settings.json" "permissions"
assert_file_contains "$d/.claude/settings.json" "phase-guide"
assert_file_contains "$d/.claude/settings.json" "pre-compact"
assert_output_contains "$OUTPUT" "Merged missing Baton hooks into .claude/settings.json"

# ============================================================
echo ""
echo "=== Test 7: Existing settings.json with partial Baton hooks gets merged ==="
d="$tmp/t7" && mkdir -p "$d/.claude" "$d/.baton/hooks"
echo '{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"sh .baton/hooks/write-lock.sh"}]}]}}' > "$d/.claude/settings.json"
# Pre-install matching write-lock.sh so version check says "up to date"
cp "$SCRIPT_DIR/../.baton/hooks/write-lock.sh" "$d/.baton/hooks/write-lock.sh"
chmod +x "$d/.baton/hooks/write-lock.sh"
OUTPUT="$(run_setup "$d" 2>&1)"
assert_file_contains "$d/.claude/settings.json" "phase-guide"
assert_file_contains "$d/.claude/settings.json" "completion-check"
assert_output_contains "$OUTPUT" "Merged missing Baton hooks into .claude/settings.json"

# ============================================================
echo ""
echo "=== Test 7b: Existing Claude settings are normalized to current baton contract ==="
d="$tmp/t7b" && mkdir -p "$d/.claude"
cat > "$d/.claude/settings.json" << 'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/phase-guide.sh"
          }
        ]
      },
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/phase-guide.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/write-lock.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/post-write-tracker.sh"
          }
        ]
      }
    ]
  }
}
JSON
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Merged missing Baton hooks into .claude/settings.json"
if command -v jq >/dev/null 2>&1; then
    TOTAL=$((TOTAL + 1))
    if jq -e '[.hooks.SessionStart[] | select(any(.hooks[]?; .command=="bash .baton/hooks/phase-guide.sh")) | .matcher] == [""]' \
        "$d/.claude/settings.json" >/dev/null 2>&1; then
        echo "  pass: phase-guide compact duplicate removed"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: phase-guide SessionStart entries should normalize to a single empty matcher"
        FAIL=$((FAIL + 1))
    fi
    TOTAL=$((TOTAL + 1))
    if jq -e 'any(.hooks.PreToolUse[]?; .matcher=="Edit|Write|MultiEdit|CreateFile|NotebookEdit" and any(.hooks[]?; .command=="bash .baton/hooks/write-lock.sh"))' \
        "$d/.claude/settings.json" >/dev/null 2>&1; then
        echo "  pass: write-lock matcher upgraded to include NotebookEdit"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: write-lock matcher should include NotebookEdit after merge"
        FAIL=$((FAIL + 1))
    fi
    TOTAL=$((TOTAL + 1))
    if jq -e 'any(.hooks.PreToolUse[]?; .matcher=="Bash" and any(.hooks[]?; .command=="bash .baton/hooks/bash-guard.sh"))' \
        "$d/.claude/settings.json" >/dev/null 2>&1; then
        echo "  pass: bash-guard entry exists with Bash matcher"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: bash-guard entry should exist with Bash matcher"
        FAIL=$((FAIL + 1))
    fi
    TOTAL=$((TOTAL + 1))
    if jq -e 'any(.hooks.PostToolUse[]?; .matcher=="Edit|Write|MultiEdit|CreateFile|NotebookEdit" and any(.hooks[]?; .command=="bash .baton/hooks/post-write-tracker.sh"))' \
        "$d/.claude/settings.json" >/dev/null 2>&1; then
        echo "  pass: post-write-tracker matcher upgraded to include NotebookEdit"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: post-write-tracker matcher should include NotebookEdit after merge"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  skip: jq unavailable, normalization assertions skipped"
fi

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
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Migrating from v1"
# v1 file should be gone, v2 should be in .baton/hooks/
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.claude/write-lock.sh" ]; then
    echo "  pass: v1 write-lock.sh removed from .claude/"
    PASS=$((PASS + 1))
else
    echo "  FAIL: v1 write-lock.sh should be removed from .claude/"
    FAIL=$((FAIL + 1))
fi
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_contains "$d/.baton/hooks/write-lock.sh" "Version: $WRITE_LOCK_VERSION"

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
OUTPUT="$(run_setup "$d" 2>&1)"
assert_file_contains "$d/.claude/settings.json" ".baton/hooks/write-lock"
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
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Legacy workflow detected"
# Should NOT append @import when legacy workflow exists (user must clean up)
assert_file_not_contains "$d/CLAUDE.md" "@.baton/workflow.md"

# ============================================================
echo ""
echo "=== Test 11: Idempotent re-install ==="
d="$tmp/t11" && mkdir -p "$d"
run_setup "$d" >/dev/null 2>&1
OUTPUT="$(run_setup "$d" 2>&1)"
# @import should appear exactly once
assert_count "$d/CLAUDE.md" "@.baton/workflow.md" 1
assert_output_contains "$OUTPUT" "@import already"

# ============================================================
echo ""
echo "=== Test 12: Non-existent target directory ==="
TOTAL=$((TOTAL + 1))
if run_setup "$tmp/nonexistent" 2>/dev/null; then
    echo "  FAIL: should error on non-existent directory"
    FAIL=$((FAIL + 1))
else
    echo "  pass: errored on non-existent directory"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 13: Upgrade from outdated version ==="
d="$tmp/t13" && mkdir -p "$d/.baton/hooks"
cat > "$d/.baton/hooks/write-lock.sh" << 'EOF'
#!/bin/sh
# Version: 0.1
echo "old version"
EOF
chmod +x "$d/.baton/hooks/write-lock.sh"
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "v0.1"
assert_output_contains "$OUTPUT" "Updated write-lock.sh"
assert_file_contains "$d/.baton/hooks/write-lock.sh" "Version: $WRITE_LOCK_VERSION"

# ============================================================
echo ""
echo "=== Test 14: Same version already installed ==="
d="$tmp/t14" && mkdir -p "$d"
run_setup "$d" >/dev/null 2>&1
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "up to date"

# ============================================================
echo ""
echo "=== Test 15: BATON_SKIP skips single component ==="
d="$tmp/t15" && mkdir -p "$d"
OUTPUT="$(BATON_SKIP="bash-guard" run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Skipped bash-guard.sh"
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_exists "$d/.baton/hooks/phase-guide.sh"
assert_file_exists "$d/.baton/hooks/stop-guard.sh"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/hooks/bash-guard.sh" ]; then
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
OUTPUT="$(BATON_SKIP="stop-guard,bash-guard" run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Skipped stop-guard.sh"
assert_output_contains "$OUTPUT" "Skipped bash-guard.sh"
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_exists "$d/.baton/hooks/phase-guide.sh"
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/hooks/stop-guard.sh" ]; then
    echo "  pass: stop-guard.sh not installed when skipped"
    PASS=$((PASS + 1))
else
    echo "  FAIL: stop-guard.sh should not be installed when skipped"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.baton/hooks/bash-guard.sh" ]; then
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
run_setup "$d" > /dev/null 2>&1
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_exists "$d/CLAUDE.md"
# Now uninstall
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
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
echo "=== Test 17b: Codex uninstall removes AGENTS import ==="
d="$tmp/t17b" && mkdir -p "$d"
FAKE_HOME="$tmp/fakehome-17b"
mkdir -p "$FAKE_HOME"
BATON_TEST_CODEX_HOME="$FAKE_HOME" run_setup_as_codex "$d" > /dev/null 2>&1
assert_file_exists "$d/AGENTS.md"
OUTPUT="$(HOME="$FAKE_HOME" run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed @.baton/workflow"
TOTAL=$((TOTAL + 1))
if [ -f "$d/AGENTS.md" ] && ! grep -qE '@\.baton/workflow(-full)?\.md' "$d/AGENTS.md"; then
    echo "  pass: Codex workflow import removed from AGENTS.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Codex workflow import should be removed from AGENTS.md"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17c: Codex uninstall cleans hooks.json + feature flag + trust (HOME isolated) ==="
d="$tmp/t17c" && mkdir -p "$d"
FAKE_HOME="$tmp/fakehome-17c"
mkdir -p "$FAKE_HOME"
HOME="$FAKE_HOME" run_setup --ide codex "$d" > /dev/null 2>&1
# Verify installed state before uninstall
assert_file_exists "$d/.codex/hooks.json"
assert_file_exists "$d/.codex/config.toml"
assert_file_exists "$FAKE_HOME/.codex/config.toml"
# Uninstall
OUTPUT="$(HOME="$FAKE_HOME" run_setup --uninstall "$d" 2>&1)"
# hooks.json should be cleaned (empty or removed)
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.codex/hooks.json" ] || ! grep -q 'adapter-codex' "$d/.codex/hooks.json" 2>/dev/null; then
    echo "  pass: Codex hooks.json cleaned on uninstall"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Codex hooks.json should not contain adapter-codex after uninstall"
    FAIL=$((FAIL + 1))
fi
# Feature flag should be removed
TOTAL=$((TOTAL + 1))
if [ ! -f "$d/.codex/config.toml" ] || ! grep -q 'codex_hooks' "$d/.codex/config.toml" 2>/dev/null; then
    echo "  pass: codex_hooks feature flag removed on uninstall"
    PASS=$((PASS + 1))
else
    echo "  FAIL: codex_hooks should be removed from .codex/config.toml after uninstall"
    FAIL=$((FAIL + 1))
fi
# Trust entry should be removed from user config
TOTAL=$((TOTAL + 1))
if [ ! -f "$FAKE_HOME/.codex/config.toml" ] || ! grep -q 'baton:codex-trust:' "$FAKE_HOME/.codex/config.toml" 2>/dev/null; then
    echo "  pass: trust entry removed from user config on uninstall"
    PASS=$((PASS + 1))
else
    echo "  FAIL: baton:codex-trust should be removed from ~/.codex/config.toml after uninstall"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17c2: Codex uninstall removes only the current project's trust entry ==="
FAKE_HOME="$tmp/fakehome-17c2"
mkdir -p "$FAKE_HOME"
d="$tmp/t17c2-prefix" && mkdir -p "$d"
d2="$tmp/t17c2-prefix-long" && mkdir -p "$d2"
HOME="$FAKE_HOME" run_setup --ide codex "$d2" > /dev/null 2>&1
HOME="$FAKE_HOME" run_setup --ide codex "$d" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -qxF "# baton:codex-trust:$d2" "$FAKE_HOME/.codex/config.toml" 2>/dev/null; then
    echo "  pass: user config contains exact trust marker for second project"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected exact trust marker for second project"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -qxF "# baton:codex-trust:$d" "$FAKE_HOME/.codex/config.toml" 2>/dev/null; then
    echo "  pass: user config contains exact trust marker for first project"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected exact trust marker for first project"
    FAIL=$((FAIL + 1))
fi
OUTPUT="$(HOME="$FAKE_HOME" run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed baton trust entry"
TOTAL=$((TOTAL + 1))
if grep -qxF "# baton:codex-trust:$d2" "$FAKE_HOME/.codex/config.toml" 2>/dev/null && \
   ! grep -qxF "# baton:codex-trust:$d" "$FAKE_HOME/.codex/config.toml" 2>/dev/null; then
    echo "  pass: uninstall removes only the matching project trust entry"
    PASS=$((PASS + 1))
else
    echo "  FAIL: uninstall should preserve other project trust entries"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17d: Claude uninstall removes Baton hooks but preserves user settings ==="
d="$tmp/t17d" && mkdir -p "$d/.claude"
cat > "$d/.claude/settings.json" << 'JSON'
{"permissions":{"allow":["Bash"]},"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"echo keep"}]}]}}
JSON
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed Baton hooks from .claude/settings.json"
assert_file_contains "$d/.claude/settings.json" "\"permissions\""
assert_file_contains "$d/.claude/settings.json" "echo keep"
assert_file_not_contains "$d/.claude/settings.json" ".baton/"

# ============================================================
echo ""
echo "=== Test 17e: Claude uninstall does not remove custom .baton hook refs ==="
d="$tmp/t17e" && mkdir -p "$d/.claude"
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
jq '.hooks.PreToolUse += [{"matcher":"Edit","hooks":[{"type":"command","command":"bash .baton/hooks/company-check.sh"}]}]' \
   "$d/.claude/settings.json" > "$d/.claude/settings.json.tmp"
mv "$d/.claude/settings.json.tmp" "$d/.claude/settings.json"
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed Baton hooks from .claude/settings.json"
assert_output_contains "$OUTPUT" "still references .baton/ — preserved .baton/ for safety"
assert_file_contains "$d/.claude/settings.json" "company-check.sh"
assert_file_not_contains "$d/.claude/settings.json" "write-lock.sh"
TOTAL=$((TOTAL + 1))
if [ -d "$d/.baton" ]; then
    echo "  pass: .baton/ preserved for custom .baton hook refs"
    PASS=$((PASS + 1))
else
    echo "  FAIL: .baton/ should be preserved for custom .baton hook refs"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 17f: Claude uninstall removes legacy .claude/write-lock hook ==="
d="$tmp/t17f" && mkdir -p "$d/.claude"
cat > "$d/.claude/settings.json" << 'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"sh .claude/write-lock.sh"},{"type":"command","command":"echo keep"}]}]}}
JSON
OUTPUT="$(run_setup --uninstall "$d" 2>&1)"
assert_output_contains "$OUTPUT" "Removed Baton hooks from .claude/settings.json"
assert_file_not_contains "$d/.claude/settings.json" ".claude/write-lock.sh"
assert_file_contains "$d/.claude/settings.json" "echo keep"

# ============================================================
echo ""
echo "=== Test: install_skills() installs SKILL.md to IDE directories ==="
d="$tmp/tskills" && mkdir -p "$d/.claude" "$d/.cursor"
(cd "$d" && git init -q)
BATON_SKIP=pre-commit run_setup "$d" > /dev/null 2>&1
# Skills should be installed in all detected IDE directories
assert_file_exists "$d/.claude/skills/baton-research/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-plan/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-implement/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-review/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-subagent/SKILL.md"
assert_file_exists "$d/.cursor/skills/baton-research/SKILL.md"
# Cross-IDE fallback
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-plan/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-implement/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-review/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-subagent/SKILL.md"
# Skill content should match canonical source (.baton/skills/) byte-for-byte
_skill_source="$SCRIPT_DIR/../.baton/skills"
if [ ! -d "$_skill_source" ]; then
    _skill_source="$SCRIPT_DIR/../.claude/skills"  # fallback for pre-migration
fi
for _sk in baton-research baton-plan baton-implement baton-review baton-debug baton-subagent; do
    TOTAL=$((TOTAL + 1))
    if diff -q "$_skill_source/$_sk/SKILL.md" \
               "$d/.claude/skills/$_sk/SKILL.md" > /dev/null 2>&1; then
        echo "  pass: .claude/skills/$_sk/SKILL.md matches canonical source"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: .claude/skills/$_sk/SKILL.md differs from canonical source"
        FAIL=$((FAIL + 1))
    fi
    TOTAL=$((TOTAL + 1))
    if diff -q "$_skill_source/$_sk/SKILL.md" \
               "$d/.agents/skills/$_sk/SKILL.md" > /dev/null 2>&1; then
        echo "  pass: .agents/skills/$_sk/SKILL.md matches canonical source"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: .agents/skills/$_sk/SKILL.md differs from canonical source"
        FAIL=$((FAIL + 1))
    fi
done

# ============================================================
echo ""
echo "=== Test: self-install bootstraps .agents/skills fallback ==="
d="$tmp/tself" && mkdir -p "$d/.claude"
FAKE_HOME="$tmp/fakehome-tself"
mkdir -p "$FAKE_HOME"
cp "$SETUP" "$d/setup.sh"
cp -R "$SCRIPT_DIR/../.baton" "$d/.baton"
cp -R "$SCRIPT_DIR/../.claude/skills" "$d/.claude/skills"
OUTPUT="$(
    cd "$d" && \
    HOME="$FAKE_HOME" BATON_SKIP=pre-commit bash ./setup.sh --ide codex 2>&1
)"
assert_output_contains "$OUTPUT" "Repaired baton skills via absolute symlinks (self-install fallback)"
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-plan/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-implement/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-review/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-subagent/SKILL.md"
assert_file_exists "$d/AGENTS.md"
TOTAL=$((TOTAL + 1))
if [ ! -d "$d/.cursor/skills" ]; then
    echo "  pass: self-install skips unrelated IDE skill directories"
    PASS=$((PASS + 1))
else
    echo "  FAIL: self-install should only bootstrap .agents fallback skills"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: self-install bootstraps selected non-Codex IDE skill directories ==="
d="$tmp/tself-ides" && mkdir -p "$d/.claude"
FAKE_HOME="$tmp/fakehome-tself-ides"
mkdir -p "$FAKE_HOME"
cp "$SETUP" "$d/setup.sh"
cp -R "$SCRIPT_DIR/../.baton" "$d/.baton"
cp -R "$SCRIPT_DIR/../.claude/skills" "$d/.claude/skills"
OUTPUT="$(
    cd "$d" && \
    HOME="$FAKE_HOME" BATON_SKIP=pre-commit bash ./setup.sh --ide cursor,codex 2>&1
)"
assert_output_contains "$OUTPUT" "Repaired baton skills via absolute symlinks (self-install fallback)"
assert_file_exists "$d/.cursor/skills/baton-research/SKILL.md"
assert_file_exists "$d/.cursor/skills/baton-plan/SKILL.md"
assert_file_exists "$d/.cursor/skills/baton-review/SKILL.md"
assert_file_exists "$d/.cursor/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.cursor/skills/baton-subagent/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-review/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-subagent/SKILL.md"
assert_file_exists "$d/AGENTS.md"

# ============================================================
echo ""
echo "=== Test: self-install uninstall preserves source files but removes fallback skills ==="
d="$tmp/tself-uninstall" && mkdir -p "$d/.claude"
FAKE_HOME="$tmp/fakehome-tself-uninstall"
mkdir -p "$FAKE_HOME"
cp "$SETUP" "$d/setup.sh"
cp -R "$SCRIPT_DIR/../.baton" "$d/.baton"
cp -R "$SCRIPT_DIR/../.claude/skills" "$d/.claude/skills"
(
    cd "$d" && \
    HOME="$FAKE_HOME" BATON_SKIP=pre-commit bash ./setup.sh --ide codex > /dev/null 2>&1
)
OUTPUT="$(
    cd "$d" && \
    HOME="$FAKE_HOME" BATON_SKIP=pre-commit bash ./setup.sh --uninstall 2>&1
)"
assert_output_contains "$OUTPUT" "Preserved source .baton/ directory (self-install)"
assert_file_exists "$d/.baton/hooks/write-lock.sh"
assert_file_exists "$d/.claude/skills/baton-research/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-review/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-subagent/SKILL.md"
TOTAL=$((TOTAL + 1))
if [ -f "$d/.agents/skills/baton-research/SKILL.md" ]; then
    echo "  pass: self-install uninstall preserves .agents committed skills"
    PASS=$((PASS + 1))
else
    echo "  FAIL: self-install uninstall should preserve .agents skills (committed symlinks)"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: phase-guide.sh version upgrade ==="
d="$tmp/t-pg-upgrade" && mkdir -p "$d/.baton/hooks"
# Create old version phase-guide.sh
cat > "$d/.baton/hooks/phase-guide.sh" << 'EOF'
#!/usr/bin/env bash
# Version: 5.0
echo "old phase-guide"
EOF
run_setup "$d"
TOTAL=$((TOTAL + 1))
if grep -q "Version: $PHASE_GUIDE_VERSION" "$d/.baton/hooks/phase-guide.sh"; then
    echo "  pass: phase-guide.sh upgraded from v5.0 to v$PHASE_GUIDE_VERSION"
    PASS=$((PASS + 1))
else
    echo "  FAIL: phase-guide.sh was not upgraded"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: workflow-full.md import migration ==="
d="$tmp/t-wf-migrate" && mkdir -p "$d/.baton/hooks" "$d/.claude"
# Simulate existing project with old import
echo '@.baton/workflow-full.md' > "$d/CLAUDE.md"
run_setup "$d"
TOTAL=$((TOTAL + 1))
if grep -q '@\.baton/workflow\.md' "$d/CLAUDE.md" && ! grep -q 'workflow-full' "$d/CLAUDE.md"; then
    echo "  pass: CLAUDE.md migrated from workflow-full.md to workflow.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md import not migrated"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: mixed import cleanup — CLAUDE.md with both old and new ==="
d="$tmp/t-mixed-claude" && mkdir -p "$d"
printf '@.baton/workflow.md\nSome content\n@.baton/workflow-full.md\n' > "$d/CLAUDE.md"
run_setup "$d"
TOTAL=$((TOTAL + 1))
if grep -q '@\.baton/workflow\.md' "$d/CLAUDE.md" 2>/dev/null; then
    echo "  pass: CLAUDE.md retains @.baton/workflow.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md should retain @.baton/workflow.md"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if ! grep -q '@\.baton/workflow-full\.md' "$d/CLAUDE.md" 2>/dev/null; then
    echo "  pass: CLAUDE.md residual workflow-full.md removed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md should not contain residual workflow-full.md"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: mixed import cleanup — AGENTS.md with both old and new ==="
d="$tmp/t-mixed-agents" && mkdir -p "$d"
printf '@.baton/workflow.md\nSome content\n@.baton/workflow-full.md\n' > "$d/AGENTS.md"
run_setup --ide codex "$d"
TOTAL=$((TOTAL + 1))
if grep -q '@\.baton/workflow\.md' "$d/AGENTS.md" 2>/dev/null; then
    echo "  pass: AGENTS.md retains @.baton/workflow.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: AGENTS.md should retain @.baton/workflow.md"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if ! grep -q '@\.baton/workflow-full\.md' "$d/AGENTS.md" 2>/dev/null; then
    echo "  pass: AGENTS.md residual workflow-full.md removed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: AGENTS.md should not contain residual workflow-full.md"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test: transition path — legacy baton with only .claude/skills/ (no .baton/skills/) ==="
# Simulate a baton installation that has not yet moved skills to .baton/skills/
d="$tmp/t-transition" && mkdir -p "$d/.claude"
FAKE_HOME="$tmp/fakehome-transition"
mkdir -p "$FAKE_HOME"
# Create a fake baton dir that has .claude/skills but no .baton/skills
FAKE_BATON="$tmp/fake-baton-legacy"
mkdir -p "$FAKE_BATON/.baton/hooks" "$FAKE_BATON/.claude/skills" "$FAKE_BATON/bin"
# Copy hooks and setup from real baton
cp "$SCRIPT_DIR/../setup.sh" "$FAKE_BATON/setup.sh"
cp -R "$SCRIPT_DIR/../.baton/hooks" "$FAKE_BATON/.baton/"
cp -R "$SCRIPT_DIR/../.baton/adapters" "$FAKE_BATON/.baton/" 2>/dev/null || true
cp "$SCRIPT_DIR/../.baton/workflow.md" "$FAKE_BATON/.baton/workflow.md"
# Copy skills to .claude/skills ONLY (legacy layout, no .baton/skills/)
_canon_src="$SCRIPT_DIR/../.baton/skills"
[ ! -d "$_canon_src" ] && _canon_src="$SCRIPT_DIR/../.claude/skills"
for _sk in baton-research baton-plan baton-implement baton-review baton-debug baton-subagent; do
    mkdir -p "$FAKE_BATON/.claude/skills/$_sk"
    cp "$_canon_src/$_sk/SKILL.md" "$FAKE_BATON/.claude/skills/$_sk/SKILL.md"
done
OUTPUT="$(
    cd "$FAKE_BATON" && \
    HOME="$FAKE_HOME" BATON_SKIP=pre-commit bash ./setup.sh "$d" 2>&1
)"
# Skills should still be installed via backward-compatibility fallback
assert_file_exists "$d/.claude/skills/baton-research/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-plan/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-implement/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-review/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-debug/SKILL.md"
assert_file_exists "$d/.claude/skills/baton-subagent/SKILL.md"
assert_file_exists "$d/.agents/skills/baton-research/SKILL.md"
assert_output_contains "$OUTPUT" "legacy .claude/skills/"
assert_file_exists "$d/.baton/workflow.md"
assert_file_exists "$d/.baton/hooks/write-lock.sh"

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

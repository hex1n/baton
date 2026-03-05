#!/bin/sh
# setup.sh — Install or upgrade baton plan-first workflow into a project
# Version: 3.0
#
# Usage: bash /path/to/baton/setup.sh [project_dir]
#
# What it does:
#   1. Detects all IDEs in the project (multi-IDE support)
#   2. Creates .baton/ directory with write-lock, phase-guide, workflow
#   3. Configures IDE-specific hooks and workflow injection for each detected IDE
#   4. Installs git pre-commit hook as universal safety net
#   5. Handles v1 → v2 → v3 migration automatically
set -eu

BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

# --- Uninstall mode ---
if [ "${1:-}" = "--uninstall" ]; then
    PROJECT_DIR="${2:-$(pwd)}"
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Error: $PROJECT_DIR is not a directory" >&2
        exit 1
    fi
    echo "Removing baton from: $PROJECT_DIR"
    rm -rf "$PROJECT_DIR/.baton"
    echo "  ✓ Removed .baton/ directory"
    # Clean CLAUDE.md @import
    if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d' "$PROJECT_DIR/CLAUDE.md"
        rm -f "$PROJECT_DIR/CLAUDE.md.bak"
        echo "  ✓ Removed @.baton/workflow*.md from CLAUDE.md"
    fi
    # Warn about settings.json
    if [ -f "$PROJECT_DIR/.claude/settings.json" ] && grep -q 'baton' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
        echo "  ⚠ .claude/settings.json may still contain baton hooks — review manually"
    fi
    # Clean Cursor
    if [ -f "$PROJECT_DIR/.cursor/rules/baton.mdc" ]; then
        rm -f "$PROJECT_DIR/.cursor/rules/baton.mdc"
        echo "  ✓ Removed .cursor/rules/baton.mdc"
    fi
    if [ -f "$PROJECT_DIR/.cursor/hooks.json" ] && grep -q 'baton' "$PROJECT_DIR/.cursor/hooks.json" 2>/dev/null; then
        echo "  ⚠ .cursor/hooks.json may still contain baton hooks — review manually"
    fi
    # Clean Windsurf
    if [ -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
        echo "  ✓ Removed .windsurf/rules/baton-workflow.md"
    fi
    if [ -f "$PROJECT_DIR/.windsurf/hooks.json" ] && grep -q 'baton' "$PROJECT_DIR/.windsurf/hooks.json" 2>/dev/null; then
        echo "  ⚠ .windsurf/hooks.json may still contain baton hooks — review manually"
    fi
    # Clean Cline
    if [ -f "$PROJECT_DIR/.clinerules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.clinerules/baton-workflow.md"
        echo "  ✓ Removed .clinerules/baton-workflow.md"
    fi
    for _hook in PreToolUse TaskComplete; do
        if [ -f "$PROJECT_DIR/.clinerules/hooks/$_hook" ] && \
           grep -q 'baton' "$PROJECT_DIR/.clinerules/hooks/$_hook" 2>/dev/null; then
            rm -f "$PROJECT_DIR/.clinerules/hooks/$_hook"
            echo "  ✓ Removed .clinerules/hooks/$_hook"
        fi
    done
    # Clean Augment
    if [ -f "$PROJECT_DIR/.augment/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.augment/rules/baton-workflow.md"
        echo "  ✓ Removed .augment/rules/baton-workflow.md"
    fi
    if [ -f "$PROJECT_DIR/.augment/settings.json" ] && grep -q 'baton' "$PROJECT_DIR/.augment/settings.json" 2>/dev/null; then
        echo "  ⚠ .augment/settings.json may still contain baton hooks — review manually"
    fi
    # Clean Kiro / Amazon Q
    if [ -f "$PROJECT_DIR/.amazonq/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.amazonq/rules/baton-workflow.md"
        echo "  ✓ Removed .amazonq/rules/baton-workflow.md"
    fi
    if [ -f "$PROJECT_DIR/.amazonq/hooks.json" ] && grep -q 'baton' "$PROJECT_DIR/.amazonq/hooks.json" 2>/dev/null; then
        echo "  ⚠ .amazonq/hooks.json may still contain baton hooks — review manually"
    fi
    # Clean Copilot
    if [ -f "$PROJECT_DIR/.github/hooks/baton.json" ]; then
        rm -f "$PROJECT_DIR/.github/hooks/baton.json"
        echo "  ✓ Removed .github/hooks/baton.json"
    fi
    if [ -f "$PROJECT_DIR/.github/copilot-instructions.md" ] && grep -q 'baton' "$PROJECT_DIR/.github/copilot-instructions.md" 2>/dev/null; then
        echo "  ⚠ .github/copilot-instructions.md may still contain baton references — review manually"
    fi
    # Clean Roo Code
    if [ -f "$PROJECT_DIR/.roo/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.roo/rules/baton-workflow.md"
        echo "  ✓ Removed .roo/rules/baton-workflow.md"
    fi
    # Clean Codex (AGENTS.md)
    if [ -f "$PROJECT_DIR/AGENTS.md" ] && grep -q 'baton' "$PROJECT_DIR/AGENTS.md" 2>/dev/null; then
        echo "  ⚠ AGENTS.md may still contain baton references — review manually"
    fi
    # Clean Zed (.rules)
    if [ -f "$PROJECT_DIR/.rules" ] && grep -q 'baton' "$PROJECT_DIR/.rules" 2>/dev/null; then
        echo "  ⚠ .rules may still contain baton references — review manually"
    fi
    # Clean git pre-commit hook
    if [ -f "$PROJECT_DIR/.git/hooks/pre-commit" ] && grep -q 'baton:pre-commit' "$PROJECT_DIR/.git/hooks/pre-commit" 2>/dev/null; then
        if grep -c '.' "$PROJECT_DIR/.git/hooks/pre-commit" | grep -q '^[0-9]' && \
           ! grep -v '^#\|^$\|baton' "$PROJECT_DIR/.git/hooks/pre-commit" | grep -q '.'; then
            rm -f "$PROJECT_DIR/.git/hooks/pre-commit"
            echo "  ✓ Removed git pre-commit hook"
        else
            # Has other content — remove only baton section
            sed -i.bak '/# baton:pre-commit:start/,/# baton:pre-commit:end/d' "$PROJECT_DIR/.git/hooks/pre-commit"
            rm -f "$PROJECT_DIR/.git/hooks/pre-commit.bak"
            echo "  ✓ Removed baton section from git pre-commit hook"
        fi
    fi
    echo "Done. Baton removed."
    exit 0
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory" >&2
    exit 1
fi

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Self-install detection: source and target are the same directory
SELF_INSTALL=0
[ "$BATON_DIR" = "$PROJECT_DIR" ] && SELF_INSTALL=1

# --- Helpers ---
get_version() {
    sed -n 's/^# Version: *//p' "$1" 2>/dev/null || echo ""
}

detect_ides() {
    _ides=""
    [ -d "$PROJECT_DIR/.claude" ]     && _ides="$_ides claude"
    [ -d "$PROJECT_DIR/.cursor" ]     && _ides="$_ides cursor"
    [ -d "$PROJECT_DIR/.windsurf" ]   && _ides="$_ides windsurf"
    [ -d "$PROJECT_DIR/.factory" ]    && _ides="$_ides factory"
    [ -d "$PROJECT_DIR/.clinerules" ] && _ides="$_ides cline"
    [ -d "$PROJECT_DIR/.augment" ]    && _ides="$_ides augment"
    [ -d "$PROJECT_DIR/.amazonq" ]    && _ides="$_ides kiro"
    # Copilot: require copilot-specific files, not just .github/
    { [ -f "$PROJECT_DIR/.github/copilot-instructions.md" ] || \
      [ -f "$PROJECT_DIR/.github/hooks/baton.json" ]; } && _ides="$_ides copilot"
    [ -f "$PROJECT_DIR/AGENTS.md" ]   && _ides="$_ides codex"
    [ -f "$PROJECT_DIR/.rules" ]      && _ides="$_ides zed"
    [ -d "$PROJECT_DIR/.roo" ]        && _ides="$_ides roo"
    # Trim leading space
    _ides="$(echo "$_ides" | sed 's/^ //')"
    [ -z "$_ides" ] && _ides="claude"
    echo "$_ides"
}

# --- Skip list ---
SKIP="${BATON_SKIP:-}"
should_skip() {
    case ",$SKIP," in
        *",$1,"*) return 0 ;;
        *) return 1 ;;
    esac
}

install_versioned_script() {
    _ivs_name="$1"
    _ivs_src="$BATON_DIR/.baton/hooks/$_ivs_name"
    _ivs_dst="$PROJECT_DIR/.baton/hooks/$_ivs_name"
    _ivs_skip="${_ivs_name%.sh}"

    [ ! -f "$_ivs_src" ] && return
    # Self-install: source == destination, skip copy
    if [ "$SELF_INSTALL" = "1" ]; then
        _ivs_sv="$(get_version "$_ivs_src")"
        echo "  ✓ $_ivs_name (self-install, v${_ivs_sv:-?})"
        return
    fi

    if should_skip "$_ivs_skip"; then
        echo "  ⊘ Skipped $_ivs_name"
        return
    fi

    if [ -f "$_ivs_dst" ]; then
        _ivs_sv="$(get_version "$_ivs_src")"
        _ivs_dv="$(get_version "$_ivs_dst")"
        if [ "$_ivs_sv" = "$_ivs_dv" ] && [ -n "$_ivs_sv" ]; then
            echo "  ✓ $_ivs_name is up to date (v$_ivs_sv)"
            return
        fi
        if [ -n "$_ivs_dv" ]; then
            # Detect potential downgrade by comparing major version
            _ivs_s_major="${_ivs_sv%%.*}"
            _ivs_d_major="${_ivs_dv%%.*}"
            if [ "$_ivs_s_major" -lt "$_ivs_d_major" ] 2>/dev/null; then
                echo "  ⚠️ $_ivs_name: v$_ivs_dv → v$_ivs_sv (downgrade)"
            else
                echo "  ↑ $_ivs_name: v$_ivs_dv → v$_ivs_sv"
            fi
        else
            echo "  ↑ $_ivs_name: (unversioned) → v$_ivs_sv"
        fi
        cp "$_ivs_src" "$_ivs_dst"
        chmod +x "$_ivs_dst"
        echo "  ✓ Updated $_ivs_name"
        return
    fi
    cp "$_ivs_src" "$_ivs_dst"
    chmod +x "$_ivs_dst"
    echo "  ✓ Installed $_ivs_name"
}

# IDEs that support SessionStart hook get slim workflow; others get full
ide_has_session_start() {
    case "$1" in
        claude|factory|cursor|cline|augment|kiro|copilot) return 0 ;;
        *) return 1 ;;
    esac
}

# Check if any IDE in the list supports SessionStart
any_has_session_start() {
    for _ide in $1; do
        if ide_has_session_start "$_ide"; then
            return 0
        fi
    done
    return 1
}

install_adapter() {
    _ia_name="$1"
    _ia_src="$BATON_DIR/.baton/adapters/$_ia_name"
    _ia_dst="$PROJECT_DIR/.baton/adapters/$_ia_name"
    if [ "$SELF_INSTALL" != "1" ] && [ -f "$_ia_src" ]; then
        cp "$_ia_src" "$_ia_dst"
        chmod +x "$_ia_dst"
        echo "  ✓ Installed $_ia_name"
    fi
}

# --- Per-IDE configuration functions ---

configure_claude() {
    echo "  --- Claude Code ---"
    mkdir -p "$PROJECT_DIR/.claude"
    SETTINGS="$PROJECT_DIR/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
        NEEDS_UPDATE=0
        if ! grep -q '.baton/hooks/write-lock' "$SETTINGS" 2>/dev/null; then
            NEEDS_UPDATE=1
        fi
        if grep -q '.claude/write-lock' "$SETTINGS" 2>/dev/null; then
            sed -i.bak 's|\.claude/write-lock\.sh|.baton/hooks/write-lock.sh|g' "$SETTINGS"
            rm -f "$SETTINGS.bak"
            echo "  ✓ Updated write-lock path in settings.json (.claude/ → .baton/)"
            NEEDS_UPDATE=0
        fi
        if [ "$NEEDS_UPDATE" = "1" ]; then
            echo "  ⚠ .claude/settings.json exists but may need write-lock hook."
            echo "    See .baton/hooks/write-lock.sh for hook config."
        fi
        if ! grep -q 'phase-guide' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ SessionStart hook for phase-guide.sh not found in settings.json."
            echo "    Add SessionStart hook: bash .baton/hooks/phase-guide.sh"
        fi
        if ! grep -q 'stop-guard' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ Stop hook for stop-guard.sh not found in settings.json."
            echo "    Add Stop hook: bash .baton/hooks/stop-guard.sh"
        fi
        if ! grep -q 'post-write-tracker' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ PostToolUse hook for post-write-tracker.sh not found in settings.json."
            echo "    Add PostToolUse hook: bash .baton/hooks/post-write-tracker.sh"
        fi
        if ! grep -q 'subagent-context' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ SubagentStart hook for subagent-context.sh not found in settings.json."
            echo "    Add SubagentStart hook: bash .baton/hooks/subagent-context.sh"
        fi
        if ! grep -q 'completion-check' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ TaskCompleted hook for completion-check.sh not found in settings.json."
            echo "    Add TaskCompleted hook: bash .baton/hooks/completion-check.sh"
        fi
        if ! grep -q 'pre-compact' "$SETTINGS" 2>/dev/null; then
            echo "  ⚠ PreCompact hook for pre-compact.sh not found in settings.json."
            echo "    Add PreCompact hook: bash .baton/hooks/pre-compact.sh"
        fi
    else
        cat > "$SETTINGS" << 'JSON'
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
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
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
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/stop-guard.sh"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/subagent-context.sh"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/completion-check.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/pre-compact.sh"
          }
        ]
      }
    ]
  }
}
JSON
        echo "  ✓ Created .claude/settings.json with 7 hooks (SessionStart, PreToolUse, PostToolUse, Stop, SubagentStart, TaskCompleted, PreCompact)"
    fi
    # Inject workflow reference into CLAUDE.md
    CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ] && grep -qE '@\.baton/workflow(-full)?\.md' "$CLAUDE_MD" 2>/dev/null; then
        # Upgrade old @workflow.md → @workflow-full.md if needed
        if grep -q '@\.baton/workflow\.md' "$CLAUDE_MD" 2>/dev/null && \
           ! grep -q '@\.baton/workflow-full\.md' "$CLAUDE_MD" 2>/dev/null; then
            sed -i.bak 's|@\.baton/workflow\.md|@.baton/workflow-full.md|g' "$CLAUDE_MD"
            rm -f "$CLAUDE_MD.bak"
            echo "  ✓ Upgraded CLAUDE.md @import: workflow.md → workflow-full.md"
        else
            echo "  ✓ Workflow @import already in CLAUDE.md"
        fi
    elif [ -f "$CLAUDE_MD" ]; then
        if ! grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null; then
            printf '\n@.baton/workflow-full.md\n' >> "$CLAUDE_MD"
            echo "  ✓ Added @.baton/workflow-full.md to CLAUDE.md"
        fi
    else
        printf '@.baton/workflow-full.md\n' > "$CLAUDE_MD"
        echo "  ✓ Created CLAUDE.md with @.baton/workflow-full.md"
    fi
}

configure_factory() {
    # Factory uses the same config as Claude Code
    echo "  --- Factory ---"
    configure_claude
}

configure_cursor() {
    echo "  --- Cursor ---"
    mkdir -p "$PROJECT_DIR/.cursor/rules"
    # Rules file — embed full workflow content (not just a reference)
    # so it persists as alwaysApply rule and survives context compression
    {
        printf '%s\n' '---'
        printf '%s\n' 'description: Baton plan-first workflow enforcer'
        printf '%s\n' 'alwaysApply: true'
        printf '%s\n' '---'
        printf '\n'
        cat "$BATON_DIR/.baton/workflow-full.md"
    } > "$PROJECT_DIR/.cursor/rules/baton.mdc"
    echo "  ✓ Created .cursor/rules/baton.mdc (full workflow embedded)"
    # Hooks
    if [ ! -f "$PROJECT_DIR/.cursor/hooks.json" ]; then
        cat > "$PROJECT_DIR/.cursor/hooks.json" << 'HOOKJSON'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "command": "bash .baton/hooks/phase-guide.sh",
        "timeout": 10
      }
    ],
    "preToolUse": [
      {
        "command": "bash .baton/adapters/adapter-cursor.sh",
        "matcher": "Write",
        "timeout": 10
      }
    ],
    "subagentStart": [
      {
        "command": "bash .baton/hooks/subagent-context.sh",
        "timeout": 10
      }
    ],
    "preCompact": [
      {
        "command": "bash .baton/hooks/pre-compact.sh",
        "timeout": 10
      }
    ]
  }
}
HOOKJSON
        echo "  ✓ Created .cursor/hooks.json (4 hooks)"
    else
        if grep -q 'baton' "$PROJECT_DIR/.cursor/hooks.json" 2>/dev/null; then
            echo "  ✓ Hooks already configured in .cursor/hooks.json"
        else
            echo "  ⚠ .cursor/hooks.json exists but has no baton hooks — merge manually"
        fi
    fi
    install_adapter "adapter-cursor.sh"
}

configure_windsurf() {
    echo "  --- Windsurf ---"
    mkdir -p "$PROJECT_DIR/.windsurf/rules"
    # Rules file
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
    echo "  ✓ Copied workflow to .windsurf/rules/"
    # Native hooks (pre_write_code supports exit code 2)
    if [ ! -f "$PROJECT_DIR/.windsurf/hooks.json" ]; then
        cat > "$PROJECT_DIR/.windsurf/hooks.json" << 'HOOKJSON'
{
  "hooks": {
    "pre_write_code": [
      {
        "command": "bash .baton/hooks/write-lock.sh",
        "show_output": true
      }
    ],
    "pre_run_command": [
      {
        "command": "bash .baton/hooks/bash-guard.sh",
        "show_output": true
      }
    ],
    "post_write_code": [
      {
        "command": "bash .baton/hooks/post-write-tracker.sh",
        "show_output": true
      }
    ]
  }
}
HOOKJSON
        echo "  ✓ Created .windsurf/hooks.json (3 hooks)"
    else
        if grep -q 'baton' "$PROJECT_DIR/.windsurf/hooks.json" 2>/dev/null; then
            echo "  ✓ Hooks already configured in .windsurf/hooks.json"
        else
            echo "  ⚠ .windsurf/hooks.json exists but has no baton hooks — merge manually"
        fi
    fi
    # Clean up deprecated adapter
    if [ -f "$PROJECT_DIR/.baton/adapters/adapter-windsurf.sh" ]; then
        rm -f "$PROJECT_DIR/.baton/adapters/adapter-windsurf.sh"
        echo "  ✓ Removed deprecated adapter-windsurf.sh (native hooks now used)"
    fi
}

configure_cline() {
    echo "  --- Cline ---"
    mkdir -p "$PROJECT_DIR/.clinerules"
    # Cline has TaskStart but not full SessionStart — use full workflow
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.clinerules/baton-workflow.md"
    echo "  ✓ Copied workflow (full) to .clinerules/"
    install_adapter "adapter-cline.sh"
    # Create hook wiring files — Cline discovers hooks via .clinerules/hooks/<EventName>
    mkdir -p "$PROJECT_DIR/.clinerules/hooks"
    if [ ! -f "$PROJECT_DIR/.clinerules/hooks/PreToolUse" ]; then
        cat > "$PROJECT_DIR/.clinerules/hooks/PreToolUse" << 'HOOK'
#!/bin/sh
exec bash "$(dirname "$0")/../../.baton/adapters/adapter-cline.sh"
HOOK
        chmod +x "$PROJECT_DIR/.clinerules/hooks/PreToolUse"
        echo "  ✓ Created .clinerules/hooks/PreToolUse → adapter-cline.sh"
    else
        echo "  ✓ .clinerules/hooks/PreToolUse already exists"
    fi
    if [ ! -f "$PROJECT_DIR/.clinerules/hooks/TaskComplete" ]; then
        cat > "$PROJECT_DIR/.clinerules/hooks/TaskComplete" << 'HOOK'
#!/bin/sh
exec bash "$(dirname "$0")/../../.baton/hooks/completion-check.sh"
HOOK
        chmod +x "$PROJECT_DIR/.clinerules/hooks/TaskComplete"
        echo "  ✓ Created .clinerules/hooks/TaskComplete → completion-check.sh"
    else
        echo "  ✓ .clinerules/hooks/TaskComplete already exists"
    fi
}

configure_augment() {
    echo "  --- Augment Code ---"
    mkdir -p "$PROJECT_DIR/.augment/rules"
    # Rules: embed full workflow
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.augment/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (full) to .augment/rules/"
    # Hooks: A-class (exit code 2, no adapter needed)
    if [ ! -f "$PROJECT_DIR/.augment/settings.json" ]; then
        cat > "$PROJECT_DIR/.augment/settings.json" << 'JSON'
{
  "hooks": {
    "SessionStart": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .baton/hooks/phase-guide.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "str-replace-editor|save-file", "hooks": [{"type": "command", "command": "bash .baton/hooks/write-lock.sh", "timeout": 5000}]}
    ]
  }
}
JSON
        echo "  ✓ Created .augment/settings.json (2 hooks)"
    else
        if grep -q 'baton' "$PROJECT_DIR/.augment/settings.json" 2>/dev/null; then
            echo "  ✓ Hooks already configured in .augment/settings.json"
        else
            echo "  ⚠ .augment/settings.json exists but has no baton hooks — merge manually"
        fi
    fi
}

configure_kiro() {
    echo "  --- Amazon Q / Kiro ---"
    mkdir -p "$PROJECT_DIR/.amazonq/rules"
    # Rules: embed full workflow
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.amazonq/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (full) to .amazonq/rules/"
    # Hooks: A-class (exit code 2)
    if [ ! -f "$PROJECT_DIR/.amazonq/hooks.json" ]; then
        cat > "$PROJECT_DIR/.amazonq/hooks.json" << 'JSON'
{
  "hooks": {
    "preToolUse": [
      {"matcher": "fs_write", "command": "bash .baton/hooks/write-lock.sh", "timeout_ms": 10000}
    ]
  }
}
JSON
        echo "  ✓ Created .amazonq/hooks.json"
    else
        if grep -q 'baton' "$PROJECT_DIR/.amazonq/hooks.json" 2>/dev/null; then
            echo "  ✓ Hooks already configured"
        else
            echo "  ⚠ .amazonq/hooks.json exists but has no baton hooks — merge manually"
        fi
    fi
}

configure_copilot() {
    echo "  --- GitHub Copilot ---"
    mkdir -p "$PROJECT_DIR/.github/hooks"
    # Hooks: B-class (needs adapter for JSON response)
    if [ ! -f "$PROJECT_DIR/.github/hooks/baton.json" ]; then
        cat > "$PROJECT_DIR/.github/hooks/baton.json" << 'JSON'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {"type": "command", "bash": "bash .baton/hooks/phase-guide.sh", "timeoutSec": 10}
    ],
    "preToolUse": [
      {"type": "command", "bash": "bash .baton/adapters/adapter-copilot.sh", "timeoutSec": 10}
    ]
  }
}
JSON
        echo "  ✓ Created .github/hooks/baton.json"
    else
        if grep -q 'baton' "$PROJECT_DIR/.github/hooks/baton.json" 2>/dev/null; then
            echo "  ✓ Hooks already configured in .github/hooks/baton.json"
        else
            echo "  ⚠ .github/hooks/baton.json exists but has no baton hooks — merge manually"
        fi
    fi
    install_adapter "adapter-copilot.sh"
    # Rules: append to copilot-instructions.md
    COPILOT_MD="$PROJECT_DIR/.github/copilot-instructions.md"
    if [ -f "$COPILOT_MD" ] && grep -q 'baton' "$COPILOT_MD" 2>/dev/null; then
        echo "  ✓ Workflow reference already in copilot-instructions.md"
    elif [ -f "$COPILOT_MD" ]; then
        printf '\n## Workflow\n\nFollow the plan-first workflow in .baton/workflow-full.md\n' >> "$COPILOT_MD"
        echo "  ✓ Added workflow reference to copilot-instructions.md"
    else
        printf '## Workflow\n\nFollow the plan-first workflow in .baton/workflow-full.md\n' > "$COPILOT_MD"
        echo "  ✓ Created copilot-instructions.md with workflow reference"
    fi
}

configure_codex() {
    echo "  --- Codex CLI ---"
    # No hooks — rules injection only
    AGENTS_MD="$PROJECT_DIR/AGENTS.md"
    if [ -f "$AGENTS_MD" ] && grep -q 'baton' "$AGENTS_MD" 2>/dev/null; then
        echo "  ✓ Workflow reference already in AGENTS.md"
    elif [ -f "$AGENTS_MD" ]; then
        printf '\n@.baton/workflow-full.md\n' >> "$AGENTS_MD"
        echo "  ✓ Added @.baton/workflow-full.md to AGENTS.md"
    fi
}

configure_zed() {
    echo "  --- Zed AI ---"
    # No hooks — rules injection only
    RULES_FILE="$PROJECT_DIR/.rules"
    if [ -f "$RULES_FILE" ] && grep -q 'baton' "$RULES_FILE" 2>/dev/null; then
        echo "  ✓ Workflow reference already in .rules"
    elif [ -f "$RULES_FILE" ]; then
        printf '\n# Baton workflow\nFollow the plan-first workflow in .baton/workflow-full.md\n' >> "$RULES_FILE"
        echo "  ✓ Added workflow reference to .rules"
    fi
}

configure_roo() {
    echo "  --- Roo Code ---"
    mkdir -p "$PROJECT_DIR/.roo/rules"
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.roo/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (full) to .roo/rules/"
    echo "  💡 Roo Code hooks are in development — rules-only for now"
}

# ==========================================
# Main installation flow
# ==========================================

IDES="$(detect_ides)"
SOURCE_VERSION="$(get_version "$BATON_DIR/.baton/hooks/write-lock.sh")"

echo "Installing baton v${SOURCE_VERSION:-3.0} into: $PROJECT_DIR"
echo "  Detected IDEs: $IDES"

# --- 0. v1 → v2 migration ---
if [ -f "$PROJECT_DIR/.claude/write-lock.sh" ] && [ ! -d "$PROJECT_DIR/.baton" ]; then
    echo "  ⬆ Migrating from v1 layout..."
    mkdir -p "$PROJECT_DIR/.baton"
    mkdir -p "$PROJECT_DIR/.baton/hooks"
    mv "$PROJECT_DIR/.claude/write-lock.sh" "$PROJECT_DIR/.baton/hooks/write-lock.sh"
    echo "  ✓ Moved write-lock.sh to .baton/hooks/"
fi

# Detect legacy workflow in CLAUDE.md
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null && \
   ! grep -qE '@\.baton/workflow(-full)?\.md' "$CLAUDE_MD" 2>/dev/null; then
    echo "  ⚠ Legacy workflow detected in CLAUDE.md."
    echo "    Remove the '## AI Workflow' section and add: @.baton/workflow-full.md"
fi

# --- 1. Install .baton/ directory ---
mkdir -p "$PROJECT_DIR/.baton/hooks" "$PROJECT_DIR/.baton/adapters"

# Install scripts (versioned + skippable)
install_versioned_script "write-lock.sh"
install_versioned_script "phase-guide.sh"
install_versioned_script "stop-guard.sh"
install_versioned_script "bash-guard.sh"

# --- 2. Install workflow files ---
if [ "$SELF_INSTALL" = "1" ]; then
    echo "  ✓ workflow.md (self-install, skipping copy)"
    echo "  ✓ workflow-full.md (self-install, skipping copy)"
elif any_has_session_start "$IDES"; then
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.baton/workflow.md"
    echo "  ✓ Installed workflow.md (slim — SessionStart provides phase guidance)"
else
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.baton/workflow.md"
    echo "  ✓ Installed workflow.md (full — no SessionStart support)"
fi

# Always copy workflow-full.md as reference
if [ "$SELF_INSTALL" != "1" ]; then
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.baton/workflow-full.md"
fi

# --- 3. Configure each detected IDE ---
for ide in $IDES; do
    case "$ide" in
        claude)   configure_claude ;;
        factory)  configure_factory ;;
        cursor)   configure_cursor ;;
        windsurf) configure_windsurf ;;
        cline)    configure_cline ;;
        augment)  configure_augment ;;
        kiro)     configure_kiro ;;
        copilot)  configure_copilot ;;
        codex)    configure_codex ;;
        zed)      configure_zed ;;
        roo)      configure_roo ;;
        *)        echo "  ⚠ Unknown IDE: $ide (skipped)" ;;
    esac
done

# --- 4. Install git pre-commit hook (universal safety net) ---
if ! should_skip "pre-commit"; then
    GIT_DIR=""
    if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        GIT_DIR="$(cd "$PROJECT_DIR" && git rev-parse --git-dir)"
        # Make absolute if relative
        case "$GIT_DIR" in
            /*) ;;
            *) GIT_DIR="$PROJECT_DIR/$GIT_DIR" ;;
        esac
    fi
    if [ -n "$GIT_DIR" ]; then
        HOOK_DIR="$GIT_DIR/hooks"
        mkdir -p "$HOOK_DIR"
        PRE_COMMIT="$HOOK_DIR/pre-commit"
        if [ ! -f "$PRE_COMMIT" ]; then
            cp "$BATON_DIR/.baton/git-hooks/pre-commit" "$PRE_COMMIT"
            chmod +x "$PRE_COMMIT"
            echo "  ✓ Installed git pre-commit hook"
        elif grep -q 'baton:pre-commit' "$PRE_COMMIT" 2>/dev/null; then
            echo "  ✓ Git pre-commit hook already installed"
        else
            # Append baton section to existing hook
            printf '\n# baton:pre-commit:start\n' >> "$PRE_COMMIT"
            # Source the baton pre-commit logic
            cat "$BATON_DIR/.baton/git-hooks/pre-commit" | grep -v '^#!' | grep -v '^# pre-commit' >> "$PRE_COMMIT"
            printf '# baton:pre-commit:end\n' >> "$PRE_COMMIT"
            echo "  ✓ Appended baton section to existing git pre-commit hook"
        fi
    fi
else
    echo "  ⊘ Skipped pre-commit hook"
fi

# --- 5. Suggest .gitignore entries ---
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q 'plan.md' "$GITIGNORE" 2>/dev/null; then
        echo "  💡 Consider adding to .gitignore: plan.md, research.md, plans/"
    fi
fi

# --- 6. Optional: jq availability hint ---
if ! command -v jq >/dev/null 2>&1; then
    echo ""
    echo "  💡 Optional: install jq for faster JSON parsing"
    case "$(uname -s)" in
        Darwin) echo "     brew install jq" ;;
        Linux)  echo "     sudo apt-get install jq  # or: sudo yum install jq" ;;
        MINGW*|MSYS*|CYGWIN*) echo "     Download from https://jqlang.github.io/jq/download/" ;;
    esac
    echo "     (Baton works without jq using built-in awk fallback)"
fi

echo ""
echo "Done. Your project now uses the Baton workflow."
echo ""
echo "  How it works:"
echo "  1. Start your AI coding session"
echo "     → Baton guides the AI to research deeply first (code writes are blocked)"
echo ""
echo "  2. Tell the AI what you want to build or fix"
echo "     → The AI writes research.md, then plan.md with proposed changes"
echo ""
echo "  3. Annotate plan.md with [NOTE] [Q] [CHANGE] [DEEPER] [MISSING]"
echo "     → AI responds to each annotation, cycle until satisfied"
echo ""
echo "  4. When satisfied, add this line to plan.md:"
echo "     <!-- BATON:GO -->"
echo "     → Now the AI can write code"
echo ""
echo "  To remove: bash $BATON_DIR/setup.sh --uninstall $PROJECT_DIR"

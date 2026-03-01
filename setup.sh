#!/bin/sh
# setup.sh — Install or upgrade baton plan-first workflow into a project
# Version: 2.0
#
# Usage: bash /path/to/baton/setup.sh [project_dir]
#
# What it does:
#   1. Detects IDE and platform
#   2. Creates .baton/ directory with write-lock, phase-guide, workflow
#   3. Configures IDE-specific hooks and workflow injection
#   4. Handles v1 → v2 migration automatically
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
        sed -i.bak '/@\.baton\/workflow\.md/d' "$PROJECT_DIR/CLAUDE.md"
        rm -f "$PROJECT_DIR/CLAUDE.md.bak"
        echo "  ✓ Removed @.baton/workflow.md from CLAUDE.md"
    fi
    # Warn about settings.json
    if [ -f "$PROJECT_DIR/.claude/settings.json" ] && grep -q 'baton' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
        echo "  ⚠ .claude/settings.json may still contain baton hooks — review manually"
    fi
    # Clean Cursor rules
    if [ -f "$PROJECT_DIR/.cursor/rules/baton.mdc" ]; then
        rm -f "$PROJECT_DIR/.cursor/rules/baton.mdc"
        echo "  ✓ Removed .cursor/rules/baton.mdc"
    fi
    # Clean Windsurf rules
    if [ -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
        echo "  ✓ Removed .windsurf/rules/baton-workflow.md"
    fi
    # Clean Cline rules
    if [ -f "$PROJECT_DIR/.clinerules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.clinerules/baton-workflow.md"
        echo "  ✓ Removed .clinerules/baton-workflow.md"
    fi
    echo "Done. Baton removed."
    exit 0
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory" >&2
    exit 1
fi

# --- Helpers ---
get_version() {
    sed -n 's/^# Version: *//p' "$1" 2>/dev/null || echo ""
}

detect_ide() {
    [ -d "$PROJECT_DIR/.claude" ] && echo "claude" && return
    [ -d "$PROJECT_DIR/.cursor" ] && echo "cursor" && return
    [ -d "$PROJECT_DIR/.windsurf" ] && echo "windsurf" && return
    [ -d "$PROJECT_DIR/.factory" ] && echo "factory" && return
    [ -d "$PROJECT_DIR/.clinerules" ] && echo "cline" && return
    echo "claude"  # Default
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
    _ivs_src="$BATON_DIR/.baton/$_ivs_name"
    _ivs_dst="$PROJECT_DIR/.baton/$_ivs_name"
    _ivs_skip="${_ivs_name%.sh}"

    [ ! -f "$_ivs_src" ] && return

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
        claude|factory) return 0 ;;
        *) return 1 ;;
    esac
}

IDE="$(detect_ide)"
SOURCE_VERSION="$(get_version "$BATON_DIR/.baton/write-lock.sh")"

echo "Installing baton v${SOURCE_VERSION:-2.0} into: $PROJECT_DIR"
echo "  Detected IDE: $IDE"

# --- 0. v1 → v2 migration ---
if [ -f "$PROJECT_DIR/.claude/write-lock.sh" ] && [ ! -d "$PROJECT_DIR/.baton" ]; then
    echo "  ⬆ Migrating from v1 layout..."
    mkdir -p "$PROJECT_DIR/.baton"
    mv "$PROJECT_DIR/.claude/write-lock.sh" "$PROJECT_DIR/.baton/write-lock.sh"
    echo "  ✓ Moved write-lock.sh to .baton/"
fi

# Detect legacy workflow in CLAUDE.md
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null && \
   ! grep -q '@\.baton/workflow\.md' "$CLAUDE_MD" 2>/dev/null; then
    echo "  ⚠ Legacy workflow detected in CLAUDE.md."
    echo "    Remove the '## AI Workflow' section and add: @.baton/workflow.md"
fi

# --- 1. Install .baton/ directory ---
mkdir -p "$PROJECT_DIR/.baton/adapters"

# Install scripts (versioned + skippable)
install_versioned_script "write-lock.sh"
install_versioned_script "phase-guide.sh"
install_versioned_script "stop-guard.sh"
install_versioned_script "bash-guard.sh"

# workflow.md — slim or full based on IDE
if ide_has_session_start "$IDE"; then
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.baton/workflow.md"
    echo "  ✓ Installed workflow.md (slim — SessionStart provides phase guidance)"
else
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.baton/workflow.md"
    echo "  ✓ Installed workflow.md (full — no SessionStart support)"
fi

# Always copy workflow-full.md as reference
cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.baton/workflow-full.md"

# --- 2. Install adapters (if needed) ---
case "$IDE" in
    cline)
        cp "$BATON_DIR/.baton/adapters/adapter-cline.sh" "$PROJECT_DIR/.baton/adapters/adapter-cline.sh"
        chmod +x "$PROJECT_DIR/.baton/adapters/adapter-cline.sh"
        echo "  ✓ Installed Cline adapter"
        ;;
    windsurf)
        cp "$BATON_DIR/.baton/adapters/adapter-windsurf.sh" "$PROJECT_DIR/.baton/adapters/adapter-windsurf.sh"
        chmod +x "$PROJECT_DIR/.baton/adapters/adapter-windsurf.sh"
        echo "  ✓ Installed Windsurf adapter"
        ;;
esac

# --- 3. Configure IDE-specific hooks ---
case "$IDE" in
    claude|factory)
        mkdir -p "$PROJECT_DIR/.claude"
        SETTINGS="$PROJECT_DIR/.claude/settings.json"
        if [ -f "$SETTINGS" ]; then
            # Update existing settings: check for write-lock and phase-guide hooks
            NEEDS_UPDATE=0
            if ! grep -q '.baton/write-lock' "$SETTINGS" 2>/dev/null; then
                NEEDS_UPDATE=1
            fi
            if grep -q '.claude/write-lock' "$SETTINGS" 2>/dev/null; then
                # v1 path detected — update to v2
                sed -i.bak 's|\.claude/write-lock\.sh|.baton/write-lock.sh|g' "$SETTINGS"
                rm -f "$SETTINGS.bak"
                echo "  ✓ Updated write-lock path in settings.json (.claude/ → .baton/)"
                NEEDS_UPDATE=0
            fi
            if [ "$NEEDS_UPDATE" = "1" ]; then
                echo "  ⚠ .claude/settings.json exists but may need write-lock hook."
                echo "    See .baton/write-lock.sh for hook config."
            fi
            if ! grep -q 'phase-guide' "$SETTINGS" 2>/dev/null; then
                echo "  ⚠ SessionStart hook for phase-guide.sh not found in settings.json."
                echo "    Add SessionStart hook: sh .baton/phase-guide.sh"
            fi
            if ! grep -q 'stop-guard' "$SETTINGS" 2>/dev/null; then
                echo "  ⚠ Stop hook for stop-guard.sh not found in settings.json."
                echo "    Add Stop hook: sh .baton/stop-guard.sh"
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
            "command": "sh .baton/phase-guide.sh"
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
            "command": "sh .baton/write-lock.sh"
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
            "command": "sh .baton/stop-guard.sh"
          }
        ]
      }
    ]
  }
}
JSON
            echo "  ✓ Created .claude/settings.json with SessionStart + PreToolUse + Stop hooks"
        fi
        ;;
    cursor)
        mkdir -p "$PROJECT_DIR/.cursor/rules"
        # Cursor uses .mdc rules files
        cat > "$PROJECT_DIR/.cursor/rules/baton.mdc" << 'MDC'
---
description: Baton plan-first workflow enforcer
alwaysApply: true
---

Read .baton/workflow.md for the complete plan-first workflow rules.
Source writes are blocked by hooks until plan.md contains <!-- BATON:GO -->.
MDC
        echo "  ✓ Created .cursor/rules/baton.mdc"
        # Cursor hooks (if supported)
        if [ ! -f "$PROJECT_DIR/.cursor/hooks.json" ]; then
            echo "  💡 Cursor hook support: configure PreToolUse in .cursor/hooks.json"
        fi
        ;;
    windsurf)
        mkdir -p "$PROJECT_DIR/.windsurf/rules"
        cp "$PROJECT_DIR/.baton/workflow.md" "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
        echo "  ✓ Copied workflow to .windsurf/rules/"
        ;;
    cline)
        mkdir -p "$PROJECT_DIR/.clinerules"
        cp "$PROJECT_DIR/.baton/workflow.md" "$PROJECT_DIR/.clinerules/baton-workflow.md"
        echo "  ✓ Copied workflow to .clinerules/"
        ;;
esac

# --- 4. Inject workflow reference into CLAUDE.md (for Claude Code / Factory / Amp) ---
case "$IDE" in
    claude|factory)
        if [ -f "$CLAUDE_MD" ] && grep -q '@\.baton/workflow\.md' "$CLAUDE_MD" 2>/dev/null; then
            echo "  ✓ Workflow @import already in CLAUDE.md"
        elif [ -f "$CLAUDE_MD" ]; then
            # Append @import if not present and no legacy workflow
            if ! grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null; then
                printf '\n@.baton/workflow.md\n' >> "$CLAUDE_MD"
                echo "  ✓ Added @.baton/workflow.md to CLAUDE.md"
            fi
        else
            printf '@.baton/workflow.md\n' > "$CLAUDE_MD"
            echo "  ✓ Created CLAUDE.md with @.baton/workflow.md"
        fi
        ;;
esac

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

# --- 7. Protection level notice for non-hook IDEs ---
case "$IDE" in
    cursor|windsurf|cline)
        echo ""
        echo "  ⚠️  Note: $IDE does not support hook-based enforcement."
        echo "     Baton installed workflow rules only (AI follows them voluntarily)."
        echo "     For enforced write-locking, use Claude Code or Factory AI."
        ;;
esac

echo ""
echo "Done. Your project now uses the plan-first workflow."
echo ""
echo "  How it works:"
echo "  1. Start your AI coding session"
echo "     → Baton guides the AI to research first (code writes are blocked)"
echo ""
echo "  2. Tell the AI what you want to build or fix"
echo "     → The AI writes plan.md with research findings and proposed changes"
echo ""
echo "  3. Review plan.md. When satisfied, add this line at the top:"
echo "     <!-- BATON:GO -->"
echo "     → Now the AI can write code"
echo ""
echo "  To remove: bash $BATON_DIR/setup.sh --uninstall $PROJECT_DIR"

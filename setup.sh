#!/bin/sh
# setup.sh — Install baton plan-first workflow into a project
#
# Usage: bash /path/to/baton/setup.sh [project_dir]
#
# What it does:
#   1. Copies write-lock.sh into the project
#   2. Creates/merges .claude/settings.json with hook config
#   3. Appends workflow instructions to CLAUDE.md
set -eu

BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory" >&2
    exit 1
fi

echo "Installing baton into: $PROJECT_DIR"

# --- 1. Copy write-lock.sh ---
mkdir -p "$PROJECT_DIR/.claude"
cp "$BATON_DIR/write-lock.sh" "$PROJECT_DIR/.claude/write-lock.sh"
chmod +x "$PROJECT_DIR/.claude/write-lock.sh"
echo "  ✓ Copied write-lock.sh → .claude/write-lock.sh"

# --- 2. Configure hooks ---
SETTINGS="$PROJECT_DIR/.claude/settings.json"

if [ -f "$SETTINGS" ]; then
    # Check if hook already configured
    if grep -q 'write-lock' "$SETTINGS" 2>/dev/null; then
        echo "  ✓ Hook already configured in .claude/settings.json"
    else
        echo "  ⚠ .claude/settings.json exists but has no write-lock hook."
        echo "    Add this to your hooks.PreToolUse config:"
        echo ""
        echo '    {"matcher":"Edit|Write|MultiEdit|CreateFile","hooks":[{"type":"command","command":"sh .claude/write-lock.sh"}]}'
        echo ""
    fi
else
    cat > "$SETTINGS" << 'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile",
        "hooks": [
          {
            "type": "command",
            "command": "sh .claude/write-lock.sh"
          }
        ]
      }
    ]
  }
}
JSON
    echo "  ✓ Created .claude/settings.json with write-lock hook"
fi

# --- 3. Append workflow instructions to CLAUDE.md ---
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
WORKFLOW="$BATON_DIR/workflow-instructions.md"

if [ -f "$CLAUDE_MD" ] && grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null; then
    echo "  ✓ Workflow instructions already in CLAUDE.md"
else
    echo "" >> "$CLAUDE_MD"
    cat "$WORKFLOW" >> "$CLAUDE_MD"
    echo "  ✓ Appended workflow instructions to CLAUDE.md"
fi

echo ""
echo "Done. Your project now uses the plan-first workflow:"
echo "  🔒 Source writes blocked until plan.md has <!-- GO -->"
echo "  📝 Workflow: research.md → plan.md → annotate → <!-- GO --> → implement"
echo ""
echo "To remove: delete .claude/write-lock.sh and the '## AI Workflow' section from CLAUDE.md"

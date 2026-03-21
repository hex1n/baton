#!/bin/sh
# setup.sh — Install baton at user level (v5 — flat install)
# Version: 5.0
#
# Usage: bash /path/to/baton/setup.sh [--uninstall] [--migrate [project_dir]]
set -eu

BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
DISPATCH="$BATON_DIR/hooks/run-hook.cmd"

# --- Argument parsing ---
ACTION="install"
MIGRATE_DIR=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --uninstall)  ACTION="uninstall"; shift ;;
        --migrate)    ACTION="migrate"; shift
                      [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ] && { MIGRATE_DIR="$(cd "$1" && pwd)"; shift; } || MIGRATE_DIR="$(pwd)" ;;
        -h|--help)    echo "Usage: bash setup.sh [--uninstall] [--migrate [project_dir]]"; exit 0 ;;
        *)            echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Discover skill names ---
discover_skills() {
    _src="$BATON_DIR/skills"
    [ -d "$_src" ] || return 0
    for _d in "$_src"/*/; do
        [ -d "$_d" ] || continue
        basename "$_d"
    done
}

# --- Create skill symlinks in ~/.claude/skills/ ---
install_skills() {
    mkdir -p "$CLAUDE_DIR/skills"
    for _skill in $(discover_skills); do
        _src="$BATON_DIR/skills/$_skill"
        _dst="$CLAUDE_DIR/skills/$_skill"
        if [ -L "$_dst" ]; then
            _target="$(readlink "$_dst" 2>/dev/null || true)"
            [ "$_target" = "$_src" ] && continue
            rm -f "$_dst"
        elif [ -d "$_dst" ]; then
            echo "  ⚠ $_dst exists as directory, replacing with symlink"
            rm -rf "$_dst"
        fi
        ln -sf "$_src" "$_dst"
    done
    echo "  ✓ Skill symlinks created in $CLAUDE_DIR/skills/"
}

# --- Remove skill symlinks ---
remove_skills() {
    for _skill in $(discover_skills); do
        _dst="$CLAUDE_DIR/skills/$_skill"
        [ -L "$_dst" ] && rm -f "$_dst"
    done
    echo "  ✓ Skill symlinks removed"
}

# --- Merge baton hooks into user-level settings.json ---
install_hooks() {
    _prefix="$DISPATCH"

    _baton_hooks='[
        {"event":"PreToolUse","matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","cmd":"PreToolUse"},
        {"event":"PreToolUse","matcher":"Bash","cmd":"PreToolUse"},
        {"event":"PostToolUse","matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","cmd":"PostToolUse"},
        {"event":"SessionStart","matcher":"","cmd":"SessionStart"},
        {"event":"Stop","matcher":"","cmd":"Stop"},
        {"event":"PreCompact","matcher":"","cmd":"PreCompact"},
        {"event":"SubagentStart","matcher":"","cmd":"SubagentStart"},
        {"event":"TaskCompleted","matcher":"","cmd":"TaskCompleted"},
        {"event":"PostToolUseFailure","matcher":"","cmd":"PostToolUseFailure"}
    ]'

    if [ ! -f "$CLAUDE_SETTINGS" ]; then
        mkdir -p "$CLAUDE_DIR"
        # Fresh install — generate settings with baton hooks only
        if command -v jq >/dev/null 2>&1; then
            echo '{}' | jq --arg prefix "$_prefix" --argjson entries "$_baton_hooks" '
                .hooks = (reduce $entries[] as $e ({};
                    .[$e.event] = (.[$e.event] // []) + [{
                        "matcher": $e.matcher,
                        "hooks": [{"type":"command","command":($prefix + " " + $e.cmd)}]
                    }]
                ))
            ' > "$CLAUDE_SETTINGS"
        else
            echo "  ⚠ jq not available — cannot create settings.json automatically."
            echo "  Please add baton hooks manually to $CLAUDE_SETTINGS"
            return 1
        fi
        echo "  ✓ Created $CLAUDE_SETTINGS with baton hooks"
        return
    fi

    # Existing file — backup, then remove old baton entries and add new ones
    if command -v jq >/dev/null 2>&1 && jq empty "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.baton-backup"
        _tmp="$CLAUDE_SETTINGS.baton.tmp"
        jq --arg prefix "$_prefix" --argjson entries "$_baton_hooks" '
            # Remove existing baton entries (matching run-hook.cmd or dispatch.sh)
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("run-hook\\.cmd|dispatch\\.sh|\\.baton/hooks/"))) | not
                )])
            ) | from_entries) |

            # Add baton dispatch entries
            reduce $entries[] as $e (.;
                .hooks[$e.event] = ((.hooks[$e.event] // []) + [{
                    "matcher": $e.matcher,
                    "hooks": [{"type":"command","command":($prefix + " " + $e.cmd)}]
                }])
            )
        ' "$CLAUDE_SETTINGS" > "$_tmp" && mv "$_tmp" "$CLAUDE_SETTINGS"
        echo "  ✓ Merged baton hooks into $CLAUDE_SETTINGS (backup at .baton-backup)"
    else
        echo "  ⚠ jq not available or settings.json invalid — cannot merge hooks."
        echo "  Backup: $CLAUDE_SETTINGS.baton-backup"
        return 1
    fi
}

# --- Remove baton hooks from user-level settings.json ---
remove_hooks() {
    if [ -f "$CLAUDE_SETTINGS" ] && command -v jq >/dev/null 2>&1; then
        _tmp="$CLAUDE_SETTINGS.baton.tmp"
        jq '
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("run-hook\\.cmd|dispatch\\.sh|\\.baton/hooks/"))) | not
                )]
                | if length == 0 then null else . end)
            ) | map(select(.value != null)) | from_entries)
        ' "$CLAUDE_SETTINGS" > "$_tmp" && mv "$_tmp" "$CLAUDE_SETTINGS"
        echo "  ✓ Removed baton hooks from $CLAUDE_SETTINGS"
    fi
}

# --- Inject constitution into user-level CLAUDE.md ---
install_constitution() {
    _ref="@../.baton/constitution.md"
    if [ ! -f "$CLAUDE_MD" ]; then
        printf '%s\n' "$_ref" > "$CLAUDE_MD"
        echo "  ✓ Created $CLAUDE_MD"
        return
    fi
    if grep -qF 'constitution.md' "$CLAUDE_MD" 2>/dev/null; then
        echo "  ✓ $CLAUDE_MD already references constitution"
        return
    fi
    printf '\n%s\n' "$_ref" >> "$CLAUDE_MD"
    echo "  ✓ Injected constitution into $CLAUDE_MD"
}

# --- Remove constitution from user-level CLAUDE.md ---
remove_constitution() {
    if [ -f "$CLAUDE_MD" ]; then
        sed -i.bak '/constitution\.md/d' "$CLAUDE_MD"
        rm -f "$CLAUDE_MD.bak"
        echo "  ✓ Removed constitution reference from $CLAUDE_MD"
    fi
}

# --- Migrate a v4 project (remove project-local baton artifacts) ---
do_migrate() {
    _dir="${MIGRATE_DIR:-$(pwd)}"
    echo "Migrating $_dir from v4 to v5..."

    # Check for v4+v5 coexistence
    if [ -f "$_dir/.claude/settings.json" ] && grep -q 'run-hook\|dispatch\.sh\|\.baton/hooks/' "$_dir/.claude/settings.json" 2>/dev/null; then
        echo "  ⚠ Found v4 hook entries in project settings.json — will remove"
    fi

    # Remove .baton junction/symlink (not the source directory)
    if [ -L "$_dir/.baton" ]; then
        rm -f "$_dir/.baton"
        echo "  ✓ Removed .baton/ symlink"
    elif [ -d "$_dir/.baton" ] && [ ! -f "$_dir/.baton/dispatch.sh" ]; then
        # Only remove if it's a junction/copy, not the source repo
        rm -rf "$_dir/.baton"
        echo "  ✓ Removed .baton/ directory"
    fi

    # Remove skill junctions from IDE directories
    for _ide_skills in .claude/skills .cursor/skills .agents/skills; do
        for _skill in $(discover_skills); do
            _path="$_dir/$_ide_skills/$_skill"
            if [ -L "$_path" ] || [ -d "$_path" ]; then
                rm -rf "$_path"
            fi
        done
    done
    echo "  ✓ Removed skill junctions"

    # Remove baton entries from project-level settings.json
    _settings="$_dir/.claude/settings.json"
    if [ -f "$_settings" ] && command -v jq >/dev/null 2>&1; then
        _tmp="$_settings.baton.tmp"
        jq '
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("run-hook\\.cmd|dispatch\\.sh|\\.baton/hooks/"))) | not
                )]
                | if length == 0 then null else . end)
            ) | map(select(.value != null)) | from_entries)
        ' "$_settings" > "$_tmp" && mv "$_tmp" "$_settings"
        echo "  ✓ Removed baton hooks from project settings.json"
    fi

    # Remove constitution reference from project CLAUDE.md/AGENTS.md
    for _md in CLAUDE.md AGENTS.md; do
        _path="$_dir/$_md"
        if [ -f "$_path" ] && grep -q '@\.baton/constitution\.md\|@\.baton/workflow' "$_path" 2>/dev/null; then
            sed -i.bak '/@\.baton\/constitution\.md/d;/@\.baton\/workflow/d' "$_path"
            rm -f "$_path.bak"
            # Remove file if empty
            if [ ! -s "$_path" ] || ! grep -q '[^[:space:]]' "$_path" 2>/dev/null; then
                rm -f "$_path"
            fi
        fi
    done
    echo "  ✓ Removed constitution references from project"

    echo "Done. Project migrated to v5."
}

# --- Main ---
case "$ACTION" in
    install)
        echo "Installing baton v5 (user-level)..."
        install_skills
        install_hooks
        install_constitution
        echo ""
        echo "Done! Baton v5 installed."
        echo "  Skills: $CLAUDE_DIR/skills/baton-*"
        echo "  Hooks:  $CLAUDE_SETTINGS"
        echo "  Constitution: $CLAUDE_MD"
        echo ""
        echo "To migrate existing v4 projects: bash setup.sh --migrate [project_dir]"
        ;;
    uninstall)
        echo "Uninstalling baton..."
        remove_skills
        remove_hooks
        remove_constitution
        echo "Done. ~/.baton/ directory preserved — delete manually if desired."
        ;;
    migrate)
        do_migrate
        ;;
esac

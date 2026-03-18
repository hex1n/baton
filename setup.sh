#!/bin/sh
# setup.sh — Install or upgrade baton into a project (v4 — junction-based)
# Version: 4.0
#
# Usage: bash /path/to/baton/setup.sh [--ide ide[,ide...]] [--choose] [project_dir]
set -eu

BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
UNINSTALL=0
REQUESTED_IDES="${BATON_IDE:-}"
CHOOSE_IDES=0
SELF_INSTALL=0
COPY_MODE=0
BATON_HOME="${BATON_HOME:-$HOME/.baton}"
BATON_REPO="${BATON_REPO:-https://github.com/hex1n/baton.git}"
BATON_SKILL_NAMES="baton-research baton-plan baton-implement baton-review baton-debug baton-subagent"
SUPPORTED_IDES="claude codex cursor factory"

usage() {
    cat <<'EOF'
Usage: bash /path/to/baton/setup.sh [--ide ide[,ide...]] [project_dir]
       bash /path/to/baton/setup.sh --choose [project_dir]
       bash /path/to/baton/setup.sh --uninstall [project_dir]
EOF
}

# --- Argument parsing ---
while [ "$#" -gt 0 ]; do
    case "$1" in
        --uninstall) UNINSTALL=1; shift ;;
        --ide)       REQUESTED_IDES="$2"; shift 2 ;;
        --choose)    CHOOSE_IDES=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           PROJECT_DIR="$(cd "$1" && pwd)"; shift ;;
    esac
done

# --- Source junction utility ---
. "$BATON_DIR/.baton/hooks/lib/junction.sh"

# --- Ensure ~/.baton exists ---
ensure_baton_home() {
    if [ "$BATON_DIR" = "$BATON_HOME" ]; then
        return 0
    fi
    if [ -d "$BATON_HOME/.git" ]; then
        if git -C "$BATON_HOME" pull --ff-only 2>/dev/null; then
            echo "  ✓ Updated ~/.baton to latest"
        else
            echo "  ⚠ Could not update ~/.baton (local changes?)"
        fi
    elif [ ! -d "$BATON_HOME" ]; then
        echo "  Cloning baton to $BATON_HOME..."
        git clone --depth 1 "$BATON_REPO" "$BATON_HOME"
        echo "  ✓ Cloned baton"
    fi
}

# --- Self-install detection ---
detect_self_install() {
    if [ -d "$PROJECT_DIR/.baton/skills" ] && [ ! -L "$PROJECT_DIR/.baton" ]; then
        # Real .baton directory with skills = source repo
        SELF_INSTALL=1
        echo "  ✓ Self-install mode (baton source repo)"
    fi
}

# --- IDE detection ---
detect_ides() {
    _ides=""
    _add() { case " $_ides " in *" $1 "*) ;; *) _ides="$_ides $1" ;; esac; }

    [ -d "$PROJECT_DIR/.claude" ]   && _add "claude"
    [ -d "$PROJECT_DIR/.cursor" ]   && _add "cursor"
    [ -d "$PROJECT_DIR/.factory" ]  && _add "factory"
    if [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -d "$PROJECT_DIR/.codex" ]; then
        _add "codex"
    fi
    # Check codex env
    [ -n "${CODEX_SANDBOX:-}" ] && _add "codex"
    # Default to claude if nothing detected
    [ -z "$_ides" ] && _add "claude"

    echo "$_ides" | sed 's/^ *//'
}

choose_ides() {
    if [ -n "$REQUESTED_IDES" ]; then
        echo "$REQUESTED_IDES" | tr ',' ' '
        return
    fi
    if [ "$CHOOSE_IDES" = "1" ]; then
        _detected="$(detect_ides)"
        echo "  Detected IDEs: $_detected"
        echo "  Available: $SUPPORTED_IDES"
        printf "  Select IDEs (comma-separated, or Enter for detected): "
        read -r _choice </dev/tty 2>/dev/null || _choice=""
        if [ -n "$_choice" ]; then
            echo "$_choice" | tr ',' ' '
        else
            echo "$_detected"
        fi
        return
    fi
    detect_ides
}

# --- Create .baton junction ---
create_baton_junction() {
    if [ "$SELF_INSTALL" = "1" ]; then
        echo "  ✓ .baton/ is source directory (self-install)"
        return
    fi
    _baton_src="$BATON_HOME/.baton"
    if [ ! -d "$_baton_src" ]; then
        _baton_src="$BATON_DIR/.baton"
    fi
    if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
        echo "  ✓ .baton/ → junction to source"
    else
        COPY_MODE=1
        touch "$PROJECT_DIR/.baton/.copy-mode"
        echo "  ⚠ .baton/ copied (no junction support). Updates need 'baton update'."
    fi
}

# --- Create skill junctions ---
create_skill_junctions() {
    _skill_src="$PROJECT_DIR/.baton/skills"
    [ ! -d "$_skill_src" ] && return

    _count=0
    for _ide in $IDES; do
        case "$_ide" in
            claude|factory) _skills_dir="$PROJECT_DIR/.claude/skills" ;;
            cursor)         _skills_dir="$PROJECT_DIR/.cursor/skills" ;;
            codex)          _skills_dir="$PROJECT_DIR/.agents/skills" ;;
            *)              continue ;;
        esac
        mkdir -p "$_skills_dir"
        for _skill in $BATON_SKILL_NAMES; do
            _src="$_skill_src/$_skill"
            [ ! -d "$_src" ] && continue
            _dst="$_skills_dir/$_skill"
            [ -d "$_dst" ] && continue
            atomic_junction "$_src" "$_dst" || true
            _count=$((_count + 1))
        done
    done
    # Always create .agents/skills fallback
    if ! echo " $IDES " | grep -q ' codex '; then
        mkdir -p "$PROJECT_DIR/.agents/skills"
        for _skill in $BATON_SKILL_NAMES; do
            _src="$_skill_src/$_skill"
            [ ! -d "$_src" ] && continue
            _dst="$PROJECT_DIR/.agents/skills/$_skill"
            [ -d "$_dst" ] && continue
            atomic_junction "$_src" "$_dst" || true
            _count=$((_count + 1))
        done
    fi
    echo "  ✓ Skill junctions created ($_count)"
}

# --- Generate or merge settings.json for Claude Code / Factory ---
generate_claude_settings() {
    _settings="$1"
    # OS-aware dispatch: use polyglot wrapper on Windows, direct bash on Unix
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            _dispatch_cmd_prefix=".baton/hooks/run-hook.cmd"
            ;;
        *)
            _dispatch_cmd_prefix="bash .baton/hooks/dispatch.sh"
            ;;
    esac

    # All 8 event types with dispatch.sh
    _events="PreToolUse PostToolUse SessionStart Stop PreCompact SubagentStart TaskCompleted PostToolUseFailure"

    # Define baton hook entries with IDE-level matchers to avoid unnecessary dispatch.
    # PreToolUse/PostToolUse use specific matchers so dispatch.sh only fires for relevant tools.
    _baton_hooks='[
        {"event":"PreToolUse","matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","cmd":"PreToolUse"},
        {"event":"PreToolUse","matcher":"Bash","cmd":"PreToolUse"},
        {"event":"PostToolUse","matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","cmd":"PostToolUse"},
        {"event":"SessionStart","matcher":"startup|clear|compact","cmd":"SessionStart"},
        {"event":"Stop","matcher":"","cmd":"Stop"},
        {"event":"PreCompact","matcher":"","cmd":"PreCompact"},
        {"event":"SubagentStart","matcher":"","cmd":"SubagentStart"},
        {"event":"TaskCompleted","matcher":"","cmd":"TaskCompleted"},
        {"event":"PostToolUseFailure","matcher":"","cmd":"PostToolUseFailure"}
    ]'

    if [ ! -f "$_settings" ]; then
        # Fresh install: generate via jq if available, otherwise hardcode
        mkdir -p "$(dirname "$_settings")"
        if command -v jq >/dev/null 2>&1; then
            echo '{}' | jq --arg prefix "$_dispatch_cmd_prefix" --argjson entries "$_baton_hooks" '
                .hooks = (reduce $entries[] as $e ({};
                    .[$e.event] = (.[$e.event] // []) + [{
                        "matcher": $e.matcher,
                        "hooks": [{"type":"command","command":($prefix + " " + $e.cmd)}]
                    }]
                ))
            ' > "$_settings"
        else
            # Hardcoded fallback without jq
            cat > "$_settings" << SETTINGS_EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix PreToolUse"}]},
      {"matcher":"Bash","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix PreToolUse"}]}
    ],
    "PostToolUse": [
      {"matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix PostToolUse"}]}
    ],
    "SessionStart": [
      {"matcher":"startup|clear|compact","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix SessionStart"}]}
    ],
    "Stop": [
      {"matcher":"","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix Stop"}]}
    ],
    "PreCompact": [
      {"matcher":"","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix PreCompact"}]}
    ],
    "SubagentStart": [
      {"matcher":"","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix SubagentStart"}]}
    ],
    "TaskCompleted": [
      {"matcher":"","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix TaskCompleted"}]}
    ],
    "PostToolUseFailure": [
      {"matcher":"","hooks":[{"type":"command","command":"$_dispatch_cmd_prefix PostToolUseFailure"}]}
    ]
  }
}
SETTINGS_EOF
        fi
        echo "  ✓ Created $_settings"
        return
    fi

    # Existing file: remove only baton entries, preserve user hooks, then add baton entries
    if command -v jq >/dev/null 2>&1 && jq empty "$_settings" >/dev/null 2>&1; then
        _tmp="$_settings.baton.tmp"
        jq --arg prefix "$_dispatch_cmd_prefix" --argjson entries "$_baton_hooks" '
            # Step 1: Remove only baton-related entries (matching .baton/hooks/ or dispatch.sh)
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("\\.baton/hooks/"))) | not
                )])
            ) | from_entries) |

            # Step 2: Append baton dispatch entries to each event
            reduce $entries[] as $e (.;
                .hooks[$e.event] = ((.hooks[$e.event] // []) + [{
                    "matcher": $e.matcher,
                    "hooks": [{"type":"command","command":($prefix + " " + $e.cmd)}]
                }])
            )
        ' "$_settings" > "$_tmp" && mv "$_tmp" "$_settings"
        echo "  ✓ Merged baton hooks into $_settings (preserved existing config)"
    else
        echo "  ⚠ jq not available — cannot merge settings.json safely."
        echo "    Install jq or manually add dispatch.sh hooks to $_settings"
    fi
}

# --- Generate or merge Cursor hooks.json ---
generate_cursor_hooks() {
    _hooks="$PROJECT_DIR/.cursor/hooks.json"
    _dispatch_cmd="bash .baton/adapters/cursor/dispatch.sh"

    if [ ! -f "$_hooks" ]; then
        mkdir -p "$PROJECT_DIR/.cursor"
        cat > "$_hooks" << EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "$_dispatch_cmd sessionStart", "timeout": 10 }
    ],
    "preToolUse": [
      { "command": "$_dispatch_cmd preToolUse", "matcher": "Write", "timeout": 10 },
      { "command": "$_dispatch_cmd preToolUse", "matcher": "Edit", "timeout": 10 },
      { "command": "$_dispatch_cmd preToolUse", "matcher": "Bash", "timeout": 10 }
    ],
    "postToolUse": [
      { "command": "$_dispatch_cmd postToolUse", "matcher": "Write", "timeout": 10 },
      { "command": "$_dispatch_cmd postToolUse", "matcher": "Edit", "timeout": 10 }
    ],
    "stop": [
      { "command": "$_dispatch_cmd stop", "timeout": 10 }
    ],
    "subagentStart": [
      { "command": "$_dispatch_cmd subagentStart", "timeout": 10 }
    ],
    "preCompact": [
      { "command": "$_dispatch_cmd preCompact", "timeout": 10 }
    ]
  }
}
EOF
        echo "  ✓ Created .cursor/hooks.json"
    else
        if command -v jq >/dev/null 2>&1 && jq empty "$_hooks" >/dev/null 2>&1; then
            _tmp="$_hooks.baton.tmp"
            # Remove only baton entries (match dispatch-cursor.sh or .baton/ paths)
            jq --arg cmd "$_dispatch_cmd" '
                .hooks = ((.hooks // {}) | to_entries | map(
                    .value = ([.value[] | select(.command | test("dispatch-cursor\\.sh|\\.baton/hooks/|\\.baton/adapters/") | not)])
                ) | from_entries) |
                .hooks.sessionStart = ((.hooks.sessionStart // []) + [{"command":($cmd + " sessionStart"),"timeout":10}]) |
                .hooks.preToolUse = ((.hooks.preToolUse // []) + [
                    {"command":($cmd + " preToolUse"),"matcher":"Write","timeout":10},
                    {"command":($cmd + " preToolUse"),"matcher":"Edit","timeout":10},
                    {"command":($cmd + " preToolUse"),"matcher":"Bash","timeout":10}
                ]) |
                .hooks.postToolUse = ((.hooks.postToolUse // []) + [
                    {"command":($cmd + " postToolUse"),"matcher":"Write","timeout":10},
                    {"command":($cmd + " postToolUse"),"matcher":"Edit","timeout":10}
                ]) |
                .hooks.stop = ((.hooks.stop // []) + [{"command":($cmd + " stop"),"timeout":10}]) |
                .hooks.subagentStart = ((.hooks.subagentStart // []) + [{"command":($cmd + " subagentStart"),"timeout":10}]) |
                .hooks.preCompact = ((.hooks.preCompact // []) + [{"command":($cmd + " preCompact"),"timeout":10}])
            ' "$_hooks" > "$_tmp" && mv "$_tmp" "$_hooks"
            echo "  ✓ Merged baton hooks into .cursor/hooks.json"
        else
            echo "  ⚠ jq not available — cannot merge .cursor/hooks.json"
        fi
    fi

    # Cursor rules file
    mkdir -p "$PROJECT_DIR/.cursor/rules"
    if [ -f "$PROJECT_DIR/.baton/constitution.md" ]; then
        {
            printf '%s\n' '---'
            printf '%s\n' 'description: Baton plan-first protocol enforcer'
            printf '%s\n' 'alwaysApply: true'
            printf '%s\n' '---'
            printf '\n'
            cat "$PROJECT_DIR/.baton/constitution.md"
        } > "$PROJECT_DIR/.cursor/rules/baton.mdc"
        echo "  ✓ Created .cursor/rules/baton.mdc"
    fi
}

# --- Configure Codex ---
configure_codex() {
    # (a) AGENTS.md rules injection
    _agents_md="$PROJECT_DIR/AGENTS.md"
    if [ ! -f "$_agents_md" ]; then
        printf '@.baton/constitution.md\n' > "$_agents_md"
        echo "  ✓ Created AGENTS.md"
    elif ! grep -q '@\.baton/constitution\.md' "$_agents_md" 2>/dev/null; then
        # Migrate old workflow imports
        if grep -qE '@\.baton/workflow(-full)?\.md' "$_agents_md" 2>/dev/null; then
            sed -i.bak 's|@\.baton/workflow\(-full\)\{0,1\}\.md|@.baton/constitution.md|g' "$_agents_md"
            rm -f "$_agents_md.bak"
            echo "  ✓ Migrated AGENTS.md: workflow → constitution.md"
        else
            printf '\n@.baton/constitution.md\n' >> "$_agents_md"
            echo "  ✓ Injected constitution into AGENTS.md"
        fi
    else
        echo "  ✓ AGENTS.md already has constitution reference"
    fi

    # (b) .codex/hooks.json — SessionStart + Stop via dispatch-codex.sh
    _codex_hooks="$PROJECT_DIR/.codex/hooks.json"
    _dispatch_cmd="bash .baton/adapters/codex/dispatch.sh"
    mkdir -p "$PROJECT_DIR/.codex"

    if [ ! -f "$_codex_hooks" ]; then
        cat > "$_codex_hooks" << EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$_dispatch_cmd SessionStart",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$_dispatch_cmd Stop",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
        echo "  ✓ Created .codex/hooks.json (SessionStart + Stop)"
    else
        if command -v jq >/dev/null 2>&1 && jq empty "$_codex_hooks" >/dev/null 2>&1; then
            _tmp="$_codex_hooks.baton.tmp"
            jq --arg cmd "$_dispatch_cmd" '
                # Remove old baton entries
                .hooks = ((.hooks // {}) | to_entries | map(
                    .value = ([.value[] | select(
                        ([(.hooks // [])[] | .command // ""] | any(test("baton/hooks/|baton/adapters/"))) | not
                    )])
                ) | from_entries) |
                # Add dispatch entries
                .hooks.SessionStart = ((.hooks.SessionStart // []) + [{
                    "hooks": [{"type":"command","command":($cmd + " SessionStart"),"timeout":30}]
                }]) |
                .hooks.Stop = ((.hooks.Stop // []) + [{
                    "hooks": [{"type":"command","command":($cmd + " Stop"),"timeout":30}]
                }])
            ' "$_codex_hooks" > "$_tmp" && mv "$_tmp" "$_codex_hooks"
            echo "  ✓ Merged baton hooks into .codex/hooks.json"
        else
            echo "  ⚠ jq not available — cannot merge .codex/hooks.json"
        fi
    fi

    # (c) Feature flag — codex_hooks in .codex/config.toml
    _codex_config="$PROJECT_DIR/.codex/config.toml"
    if [ -f "$_codex_config" ] && grep -q 'codex_hooks' "$_codex_config" 2>/dev/null; then
        echo "  ✓ Feature flag codex_hooks already set"
    elif [ -f "$_codex_config" ]; then
        if grep -q '^\[features\]' "$_codex_config" 2>/dev/null; then
            sed -i.bak '/^\[features\]/a codex_hooks = true' "$_codex_config"
            rm -f "$_codex_config.bak"
        else
            printf '\n[features]\ncodex_hooks = true\n' >> "$_codex_config"
        fi
        echo "  ✓ Enabled codex_hooks feature flag"
    else
        printf '[features]\ncodex_hooks = true\n' > "$_codex_config"
        echo "  ✓ Created .codex/config.toml with codex_hooks feature flag"
    fi

    # (d) Trust — user-level ~/.codex/config.toml
    _codex_user_config="$HOME/.codex/config.toml"
    if command -v cygpath >/dev/null 2>&1; then
        _codex_project_path="$(cygpath -w "$PROJECT_DIR")"
    else
        _codex_project_path="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)"
    fi
    if [ -f "$_codex_user_config" ] && grep -qF "$_codex_project_path" "$_codex_user_config" 2>/dev/null; then
        echo "  ✓ Project trust already configured"
    else
        mkdir -p "$(dirname "$_codex_user_config")" 2>/dev/null || true
        if printf '\n# baton-managed: %s\n[projects.'\''%s'\'']\ntrust_level = "trusted"\n' \
            "$_codex_project_path" "$_codex_project_path" >> "$_codex_user_config" 2>/dev/null; then
            echo "  ✓ Added project trust to ~/.codex/config.toml"
        else
            echo "  ⚠ Could not update ~/.codex/config.toml — add trust manually"
        fi
    fi
}

# --- Inject CLAUDE.md ---
inject_claude_md() {
    _claude_md="$PROJECT_DIR/CLAUDE.md"
    if [ ! -f "$_claude_md" ]; then
        printf '@.baton/constitution.md\n' > "$_claude_md"
        echo "  ✓ Created CLAUDE.md"
    elif ! grep -q '@\.baton/constitution\.md' "$_claude_md" 2>/dev/null; then
        # Remove old workflow imports if present
        if grep -qE '@\.baton/workflow(-full)?\.md' "$_claude_md" 2>/dev/null; then
            sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d' "$_claude_md"
            rm -f "$_claude_md.bak"
        fi
        printf '\n@.baton/constitution.md\n' >> "$_claude_md"
        echo "  ✓ Injected constitution into CLAUDE.md"
    else
        # Clean residual old imports
        if grep -qE '@\.baton/workflow(-full)?\.md' "$_claude_md" 2>/dev/null; then
            sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d' "$_claude_md"
            rm -f "$_claude_md.bak"
            echo "  ✓ Removed residual workflow import from CLAUDE.md"
        else
            echo "  ✓ CLAUDE.md already has constitution reference"
        fi
    fi
}

# --- Add .gitignore entries ---
add_gitignore() {
    _gi="$PROJECT_DIR/.gitignore"
    # Self-install: don't gitignore .baton/ (it's the source directory)
    if [ "$SELF_INSTALL" = "1" ]; then
        _entries=".claude/skills/baton-*
.cursor/skills/baton-*
.agents/skills/baton-*"
    else
        _entries=".baton/
.codex/
.claude/skills/baton-*
.cursor/skills/baton-*
.agents/skills/baton-*"
    fi

    [ ! -f "$_gi" ] && touch "$_gi"
    _changed=0
    echo "$_entries" | while IFS= read -r _entry; do
        [ -z "$_entry" ] && continue
        if ! grep -qxF "$_entry" "$_gi" 2>/dev/null; then
            echo "$_entry" >> "$_gi"
            _changed=1
        fi
    done
    # Check if we added anything (re-read since subshell)
    _missing=0
    echo "$_entries" | while IFS= read -r _entry; do
        [ -z "$_entry" ] && continue
        grep -qxF "$_entry" "$_gi" 2>/dev/null || _missing=1
    done
    echo "  ✓ .gitignore updated"
}

# --- Uninstall ---
do_uninstall() {
    echo "Removing baton from $PROJECT_DIR..."

    # Remove .baton junction/directory
    if [ -L "$PROJECT_DIR/.baton" ] || [ -d "$PROJECT_DIR/.baton" ]; then
        rm -rf "$PROJECT_DIR/.baton"
        echo "  ✓ Removed .baton/"
    fi

    # Remove skill junctions
    for _ide_skills in .claude/skills .cursor/skills .agents/skills; do
        for _skill in $BATON_SKILL_NAMES; do
            _path="$PROJECT_DIR/$_ide_skills/$_skill"
            if [ -e "$_path" ] || [ -L "$_path" ]; then
                rm -rf "$_path"
            fi
        done
    done
    echo "  ✓ Removed skill junctions"

    # Remove baton entries from settings.json
    _settings="$PROJECT_DIR/.claude/settings.json"
    if [ -f "$_settings" ] && command -v jq >/dev/null 2>&1; then
        _tmp="$_settings.baton.tmp"
        jq '
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("dispatch\\.sh"))) | not
                )]
                | if length == 0 then null else . end)
            ) | map(select(.value != null)) | from_entries)
        ' "$_settings" > "$_tmp" && mv "$_tmp" "$_settings"
        echo "  ✓ Removed baton hooks from settings.json"
    fi

    # Remove baton entries from cursor hooks.json
    _hooks="$PROJECT_DIR/.cursor/hooks.json"
    if [ -f "$_hooks" ] && command -v jq >/dev/null 2>&1; then
        _tmp="$_hooks.baton.tmp"
        jq '
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(.command | test("dispatch") | not)])
                | if length == 0 then null else . end
            ) | map(select(.value != null)) | from_entries)
        ' "$_hooks" > "$_tmp" && mv "$_tmp" "$_hooks"
        echo "  ✓ Removed baton hooks from .cursor/hooks.json"
    fi

    # Remove cursor rules
    rm -f "$PROJECT_DIR/.cursor/rules/baton.mdc"

    # Remove baton entries from codex hooks.json
    _codex_hooks="$PROJECT_DIR/.codex/hooks.json"
    if [ -f "$_codex_hooks" ] && command -v jq >/dev/null 2>&1; then
        _tmp="$_codex_hooks.baton.tmp"
        jq '
            .hooks = ((.hooks // {}) | to_entries | map(
                .value = ([.value[] | select(
                    ([(.hooks // [])[] | .command // ""] | any(test("baton"))) | not
                )]
                | if length == 0 then null else . end)
            ) | map(select(.value != null)) | from_entries)
        ' "$_codex_hooks" > "$_tmp" && mv "$_tmp" "$_codex_hooks"
        echo "  ✓ Removed baton hooks from .codex/hooks.json"
    fi

    # Remove codex feature flag and trust
    _codex_config="$PROJECT_DIR/.codex/config.toml"
    if [ -f "$_codex_config" ] && grep -q 'codex_hooks' "$_codex_config" 2>/dev/null; then
        sed -i.bak '/codex_hooks/d' "$_codex_config"
        rm -f "$_codex_config.bak"
        echo "  ✓ Removed codex_hooks feature flag"
    fi

    # Remove constitution from CLAUDE.md (also clean old workflow imports)
    for _md in CLAUDE.md AGENTS.md; do
        _path="$PROJECT_DIR/$_md"
        if [ -f "$_path" ]; then
            sed -i.bak '/@\.baton\/constitution\.md/d;/@\.baton\/workflow/d' "$_path"
            rm -f "$_path.bak"
            # Remove file if empty
            if [ ! -s "$_path" ] || ! grep -q '[^[:space:]]' "$_path" 2>/dev/null; then
                rm -f "$_path"
            fi
        fi
    done
    echo "  ✓ Removed constitution references"

    echo "Done."
}

# --- Main ---
if [ "$UNINSTALL" = "1" ]; then
    do_uninstall
    exit 0
fi

echo "Setting up baton in $PROJECT_DIR..."
echo ""

# 1. Ensure global baton exists
ensure_baton_home

# 2. Detect self-install
detect_self_install

# 3. Choose IDEs
IDES="$(choose_ides)"
echo "  IDEs: $IDES"

# 4. Create .baton junction
create_baton_junction

# 5. Create skill junctions
create_skill_junctions

# 6. Configure each IDE
for _ide in $IDES; do
    case "$_ide" in
        claude|factory)
            mkdir -p "$PROJECT_DIR/.claude"
            generate_claude_settings "$PROJECT_DIR/.claude/settings.json"
            inject_claude_md
            ;;
        cursor)
            generate_cursor_hooks
            ;;
        codex)
            configure_codex
            ;;
    esac
done

# 7. Add gitignore entries
add_gitignore

echo ""
echo "Done! Baton v4 installed."
if [ "$COPY_MODE" = "1" ]; then
    echo "  ⚠ Running in copy mode. Run 'baton update' after updating baton source."
fi

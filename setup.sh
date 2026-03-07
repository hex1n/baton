#!/bin/sh
# setup.sh — Install or upgrade baton plan-first workflow into a project
# Version: 3.0
#
# Usage: bash /path/to/baton/setup.sh [--ide ide[,ide...]] [--choose] [project_dir]
#
# What it does:
#   1. Detects available IDEs in the project
#   2. Lets the user select which IDEs to configure (via --ide / --choose)
#   3. Creates .baton/ directory with write-lock, phase-guide, workflow
#   4. Configures IDE-specific hooks and workflow injection for each selected IDE
#   5. Installs git pre-commit hook as universal safety net
#   6. Handles v1 → v2 → v3 migration automatically
set -eu

usage() {
    cat <<'EOF'
Usage: bash /path/to/baton/setup.sh [--ide ide[,ide...]] [project_dir]
       bash /path/to/baton/setup.sh --choose [project_dir]
       bash /path/to/baton/setup.sh --uninstall [project_dir]

Examples:
  bash /path/to/baton/setup.sh
  bash /path/to/baton/setup.sh /path/to/project
  bash /path/to/baton/setup.sh --ide cursor,codex /path/to/project
  bash /path/to/baton/setup.sh --ide kiro /path/to/project
  bash /path/to/baton/setup.sh --ide codex /path/to/project
  bash /path/to/baton/setup.sh --choose /path/to/project

Scope notes:
  cursor = Cursor IDE
  kiro = current .amazonq compatibility surface
  roo = rules guidance only in Baton
EOF
}

BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
UNINSTALL=0
REQUESTED_IDES="${BATON_IDE:-}"
REQUESTED_IDES_SOURCE=""
CHOOSE_IDES=0
CHOOSE_IDES_SOURCE=""
POSITIONAL_COUNT=0

[ -n "$REQUESTED_IDES" ] && REQUESTED_IDES_SOURCE="BATON_IDE"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        --ide)
            if [ "$#" -lt 2 ]; then
                echo "Error: --ide requires a value" >&2
                usage >&2
                exit 1
            fi
            REQUESTED_IDES="$2"
            REQUESTED_IDES_SOURCE="--ide"
            shift 2
            ;;
        --ide=*)
            REQUESTED_IDES="${1#--ide=}"
            REQUESTED_IDES_SOURCE="--ide"
            shift
            ;;
        --choose)
            CHOOSE_IDES=1
            CHOOSE_IDES_SOURCE="--choose"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
                if [ "$POSITIONAL_COUNT" -gt 1 ]; then
                    echo "Error: unexpected argument '$1'" >&2
                    usage >&2
                    exit 1
                fi
                PROJECT_DIR="$1"
                shift
            done
            ;;
        -*)
            echo "Error: unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
        *)
            POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
            if [ "$POSITIONAL_COUNT" -gt 1 ]; then
                echo "Error: unexpected argument '$1'" >&2
                usage >&2
                exit 1
            fi
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

if [ "$CHOOSE_IDES" = "1" ] && [ -n "$REQUESTED_IDES_SOURCE" ]; then
    echo "Error: cannot combine --choose with $REQUESTED_IDES_SOURCE" >&2
    usage >&2
    exit 1
fi

if [ "$UNINSTALL" = "0" ] && [ "$CHOOSE_IDES" = "0" ] && [ -z "$REQUESTED_IDES" ]; then
    if [ "${BATON_ASSUME_INTERACTIVE:-0}" = "1" ] || { [ -t 0 ] && [ -t 1 ]; }; then
        CHOOSE_IDES=1
        CHOOSE_IDES_SOURCE="interactive default"
    fi
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory" >&2
    exit 1
fi

# Resolve to absolute path early so uninstall can distinguish self-install safely.
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Self-install detection: source and target are the same directory.
SELF_INSTALL=0
[ "$BATON_DIR" = "$PROJECT_DIR" ] && SELF_INSTALL=1

json_edit_with_jq() {
    _jej_file="$1"
    _jej_filter="$2"
    shift 2
    if ! command -v jq >/dev/null 2>&1; then
        return 2
    fi
    if ! jq empty "$_jej_file" >/dev/null 2>&1; then
        return 3
    fi
    _jej_tmp="$_jej_file.baton.tmp"
    if ! jq "$@" "$_jej_filter" "$_jej_file" > "$_jej_tmp"; then
        rm -f "$_jej_tmp"
        return 4
    fi
    if cmp -s "$_jej_file" "$_jej_tmp"; then
        rm -f "$_jej_tmp"
        return 1
    fi
    mv "$_jej_tmp" "$_jej_file"
    return 0
}

baton_json_command_allowlist() {
    cat <<'JSON'
[
  "bash .baton/hooks/phase-guide.sh",
  "sh .baton/hooks/phase-guide.sh",
  "bash .baton/hooks/write-lock.sh",
  "sh .baton/hooks/write-lock.sh",
  "bash .baton/hooks/post-write-tracker.sh",
  "sh .baton/hooks/post-write-tracker.sh",
  "bash .baton/hooks/stop-guard.sh",
  "sh .baton/hooks/stop-guard.sh",
  "bash .baton/hooks/subagent-context.sh",
  "sh .baton/hooks/subagent-context.sh",
  "bash .baton/hooks/completion-check.sh",
  "sh .baton/hooks/completion-check.sh",
  "bash .baton/hooks/pre-compact.sh",
  "sh .baton/hooks/pre-compact.sh",
  "bash .baton/hooks/bash-guard.sh",
  "sh .baton/hooks/bash-guard.sh",
  "bash .baton/adapters/adapter-cursor.sh",
  "sh .baton/adapters/adapter-cursor.sh",
  "bash .baton/adapters/adapter-copilot.sh",
  "sh .baton/adapters/adapter-copilot.sh",
  "bash .claude/write-lock.sh",
  "sh .claude/write-lock.sh"
]
JSON
}

baton_hook_count_in_json_file() {
    _bhcj_file="$1"
    _bhcj_allowlist="$(baton_json_command_allowlist)"
    if ! command -v jq >/dev/null 2>&1; then
        return 2
    fi
    if ! jq empty "$_bhcj_file" >/dev/null 2>&1; then
        return 3
    fi
    jq -r --argjson baton_commands "$_bhcj_allowlist" '
        def hook_command:
            ((.command? // .bash? // "") | tostring);
        def baton_ref:
            hook_command as $cmd
            | ($baton_commands | index($cmd)) != null;
        def event_entries:
            (.hooks // {})
            | if type == "object" then .[] else empty end
            | if type == "array" then .[] else empty end;
        [
            event_entries
            | if type != "object" then
                empty
              elif ((.hooks? // null) | type) == "array" then
                (.hooks[]? | select(type == "object" and baton_ref))
              elif baton_ref then
                .
              else
                empty
              end
        ]
        | length
    ' "$_bhcj_file"
}

json_dot_baton_path_ref_count() {
    _jdbpr_file="$1"
    if ! command -v jq >/dev/null 2>&1; then
        return 2
    fi
    if ! jq empty "$_jdbpr_file" >/dev/null 2>&1; then
        return 3
    fi
    jq -r '
        def hook_command:
            ((.command? // .bash? // "") | tostring);
        def dot_baton_ref:
            hook_command | contains(".baton/");
        def event_entries:
            (.hooks // {})
            | if type == "object" then .[] else empty end
            | if type == "array" then .[] else empty end;
        [
            event_entries
            | if type != "object" then
                empty
              elif ((.hooks? // null) | type) == "array" then
                (.hooks[]? | select(type == "object" and dot_baton_ref))
              elif dot_baton_ref then
                .
              else
                empty
              end
        ]
        | length
    ' "$_jdbpr_file"
}

remove_baton_hooks_from_json_file() {
    _rbhj_file="$1"
    _rbhj_allowlist="$(baton_json_command_allowlist)"
    json_edit_with_jq "$_rbhj_file" '
        def hook_command:
            ((.command? // .bash? // "") | tostring);
        def baton_ref:
            hook_command as $cmd
            | ($baton_commands | index($cmd)) != null;
        def clean_nested:
            if type == "object" and ((.hooks? // null) | type) == "array" then
                .hooks |= map(select((type != "object") or (baton_ref | not)))
            else
                .
            end;
        .hooks = (
            (.hooks // {})
            | if type == "object" then . else {} end
            | with_entries(
                .value = (
                    (.value // [])
                    | if type == "array" then . else [] end
                    | map(if type == "object" then clean_nested else . end)
                    | map(select(
                        if type != "object" then
                            true
                        elif ((.hooks? // null) | type) == "array" then
                            ((.hooks | length) > 0)
                        else
                            (baton_ref | not)
                        end
                    ))
                )
                | select((.value | length) > 0)
            )
        )
    ' --argjson baton_commands "$_rbhj_allowlist"
}

copilot_baton_file_is_empty() {
    _cbfe_file="$1"
    command -v jq >/dev/null 2>&1 || return 1
    jq -e '
        ((.hooks // {}) | type == "object" and length == 0) and
        (((keys_unsorted - ["hooks", "version"]) | length) == 0)
    ' "$_cbfe_file" >/dev/null 2>&1
}

cleanup_baton_json_hook_file() {
    _cbj_file="$1"
    _cbj_label="$2"
    _cbj_mode="${3:-keep}"
    [ -f "$_cbj_file" ] || return 0

    _cbj_before="$(baton_hook_count_in_json_file "$_cbj_file" 2>/dev/null)"
    _cbj_status=$?
    case "$_cbj_status" in
        0)
            ;;
        2|3)
            echo "  ⚠ $_cbj_label exists but Baton could not inspect hooks automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
        *)
            echo "  ⚠ $_cbj_label exists but Baton could not inspect hooks automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
    esac

    if [ "${_cbj_before:-0}" -gt 0 ]; then
        if ! remove_baton_hooks_from_json_file "$_cbj_file"; then
            echo "  ⚠ $_cbj_label exists but Baton could not remove hooks automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
        fi
    fi

    _cbj_after="$(baton_hook_count_in_json_file "$_cbj_file" 2>/dev/null)"
    _cbj_status=$?
    case "$_cbj_status" in
        0)
            ;;
        2|3)
            echo "  ⚠ $_cbj_label exists but Baton could not verify hook cleanup automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
        *)
            echo "  ⚠ $_cbj_label exists but Baton could not verify hook cleanup automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
    esac

    _cbj_dot_baton_after="$(json_dot_baton_path_ref_count "$_cbj_file" 2>/dev/null)"
    _cbj_status=$?
    case "$_cbj_status" in
        0)
            ;;
        2|3)
            echo "  ⚠ $_cbj_label exists but Baton could not verify remaining .baton/ references automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
        *)
            echo "  ⚠ $_cbj_label exists but Baton could not verify remaining .baton/ references automatically — review manually"
            UNINSTALL_KEEP_BATON_DIR=1
            return 0
            ;;
    esac

    if [ "${_cbj_before:-0}" -gt "${_cbj_after:-0}" ]; then
        echo "  ✓ Removed Baton hooks from $_cbj_label"
    fi

    if [ "${_cbj_after:-0}" -gt 0 ]; then
        echo "  ⚠ $_cbj_label still references Baton — preserved .baton/ for safety"
        UNINSTALL_KEEP_BATON_DIR=1
        return 0
    fi

    if [ "${_cbj_dot_baton_after:-0}" -gt 0 ]; then
        echo "  ⚠ $_cbj_label still references .baton/ — preserved .baton/ for safety"
        UNINSTALL_KEEP_BATON_DIR=1
        return 0
    fi

    if [ "$_cbj_mode" = "delete-if-empty" ] && [ "${_cbj_before:-0}" -gt 0 ] && copilot_baton_file_is_empty "$_cbj_file"; then
        rm -f "$_cbj_file"
        echo "  ✓ Removed $_cbj_label"
    fi
}

# --- Uninstall mode ---
if [ "$UNINSTALL" = "1" ]; then
    echo "Removing baton from: $PROJECT_DIR"
    UNINSTALL_KEEP_BATON_DIR=0
    if [ "$SELF_INSTALL" = "1" ]; then
        UNINSTALL_KEEP_BATON_DIR=1
    fi
    # Clean CLAUDE.md @import
    if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d' "$PROJECT_DIR/CLAUDE.md"
        rm -f "$PROJECT_DIR/CLAUDE.md.bak"
        echo "  ✓ Removed @.baton/workflow*.md from CLAUDE.md"
    fi
    cleanup_baton_json_hook_file "$PROJECT_DIR/.claude/settings.json" ".claude/settings.json"
    # Clean Cursor
    if [ -f "$PROJECT_DIR/.cursor/rules/baton.mdc" ]; then
        rm -f "$PROJECT_DIR/.cursor/rules/baton.mdc"
        echo "  ✓ Removed .cursor/rules/baton.mdc"
    fi
    cleanup_baton_json_hook_file "$PROJECT_DIR/.cursor/hooks.json" ".cursor/hooks.json"
    # Clean Windsurf
    if [ -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
        echo "  ✓ Removed .windsurf/rules/baton-workflow.md"
    fi
    cleanup_baton_json_hook_file "$PROJECT_DIR/.windsurf/hooks.json" ".windsurf/hooks.json"
    # Clean Cline
    if [ -f "$PROJECT_DIR/.clinerules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.clinerules/baton-workflow.md"
        echo "  ✓ Removed .clinerules/baton-workflow.md"
    fi
    for _hook in PreToolUse TaskComplete; do
        _hook_path="$PROJECT_DIR/.clinerules/hooks/$_hook"
        _hook_backup="$_hook_path.baton-user"
        if [ -f "$_hook_path" ] && grep -q 'baton-cline-wrapper' "$_hook_path" 2>/dev/null; then
            if [ -f "$_hook_backup" ]; then
                mv "$_hook_backup" "$_hook_path"
                echo "  ✓ Restored original .clinerules/hooks/$_hook"
            else
                rm -f "$_hook_path"
                echo "  ✓ Removed .clinerules/hooks/$_hook"
            fi
        elif [ -f "$_hook_path" ] && grep -q 'baton' "$_hook_path" 2>/dev/null; then
            rm -f "$_hook_path"
            echo "  ✓ Removed .clinerules/hooks/$_hook"
        fi
    done
    # Clean Augment
    if [ -f "$PROJECT_DIR/.augment/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.augment/rules/baton-workflow.md"
        echo "  ✓ Removed .augment/rules/baton-workflow.md"
    fi
    cleanup_baton_json_hook_file "$PROJECT_DIR/.augment/settings.json" ".augment/settings.json"
    # Clean Kiro / Amazon Q
    if [ -f "$PROJECT_DIR/.amazonq/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.amazonq/rules/baton-workflow.md"
        echo "  ✓ Removed .amazonq/rules/baton-workflow.md"
    fi
    cleanup_baton_json_hook_file "$PROJECT_DIR/.amazonq/hooks.json" ".amazonq/hooks.json"
    # Clean Copilot
    cleanup_baton_json_hook_file "$PROJECT_DIR/.github/hooks/baton.json" ".github/hooks/baton.json" "delete-if-empty"
    if [ -f "$PROJECT_DIR/.github/copilot-instructions.md" ] && grep -q 'baton' "$PROJECT_DIR/.github/copilot-instructions.md" 2>/dev/null; then
        echo "  ⚠ .github/copilot-instructions.md may still contain baton references — review manually"
    fi
    # Clean Roo Code
    if [ -f "$PROJECT_DIR/.roo/rules/baton-workflow.md" ]; then
        rm -f "$PROJECT_DIR/.roo/rules/baton-workflow.md"
        echo "  ✓ Removed .roo/rules/baton-workflow.md"
    fi
    # Clean Codex (AGENTS.md)
    if [ -f "$PROJECT_DIR/AGENTS.md" ]; then
        if grep -qE '@\.baton/workflow(-full)?\.md' "$PROJECT_DIR/AGENTS.md" 2>/dev/null; then
            sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d' "$PROJECT_DIR/AGENTS.md"
            rm -f "$PROJECT_DIR/AGENTS.md.bak"
            echo "  ✓ Removed @.baton/workflow*.md from AGENTS.md"
        fi
        if grep -q 'baton' "$PROJECT_DIR/AGENTS.md" 2>/dev/null; then
            echo "  ⚠ AGENTS.md may still contain baton references — review manually"
        fi
    fi
    # Clean baton skills from all IDEs
    for _ide_dir in .claude .cursor .windsurf .cline .github .augment .roo .kiro .amazonq .agents; do
        for _skill in baton-research baton-plan baton-implement; do
            _skill_dir="$PROJECT_DIR/$_ide_dir/skills/$_skill"
            if [ "$SELF_INSTALL" = "1" ] && [ "$_skill_dir" = "$BATON_DIR/.claude/skills/$_skill" ]; then
                continue
            fi
            if [ -d "$_skill_dir" ]; then
                rm -rf "$_skill_dir"
            fi
        done
    done
    echo "  ✓ Removed baton skills from all IDE directories"
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
    if [ "$SELF_INSTALL" = "1" ]; then
        echo "  ✓ Preserved source .baton/ directory (self-install)"
    elif [ "$UNINSTALL_KEEP_BATON_DIR" = "1" ]; then
        echo "  ⚠ Preserved .baton/ directory because some configs still reference Baton"
    elif [ -d "$PROJECT_DIR/.baton" ]; then
        rm -rf "$PROJECT_DIR/.baton"
        echo "  ✓ Removed .baton/ directory"
    fi
    echo "Done. Baton removed."
    exit 0
fi

# --- Helpers ---
get_version() {
    sed -n 's/^# Version: *//p' "$1" 2>/dev/null || echo ""
}

SUPPORTED_IDES="claude codex cursor windsurf copilot augment kiro cline factory zed roo"

append_ide() {
    _append_name="$1"
    case " ${_ides:-} " in
        *" $_append_name "*) ;;
        *) _ides="${_ides:+$_ides }$_append_name" ;;
    esac
}

has_codex_env() {
    [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]
}

normalize_ide_name() {
    _normalized="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$_normalized" in
        amazonq|amazon-q) echo "kiro" ;;
        claudecode|claude-code) echo "claude" ;;
        *) echo "$_normalized" ;;
    esac
}

is_supported_ide() {
    case " $SUPPORTED_IDES " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

ide_summary() {
    case "$1" in
        claude)   echo "full protection, native hooks + skills" ;;
        factory)  echo "full protection, Claude-style hooks + skills" ;;
        cursor)   echo "full protection, Cursor IDE hooks + adapter" ;;
        windsurf) echo "full protection, native hooks + skills" ;;
        cline)    echo "hook protection + completion checks + skills" ;;
        augment)  echo "full protection, hooks + skills" ;;
        kiro)     echo "hook protection, Kiro compatibility surface (.amazonq) + skills" ;;
        copilot)  echo "full protection, adapter + workflow.md + skills" ;;
        codex)    echo "rules guidance via AGENTS.md + .agents/skills" ;;
        zed)      echo "rules guidance via .rules only" ;;
        roo)      echo "rules guidance via .roo/rules + skills (no Baton hook integration)" ;;
        *)        echo "supported IDE" ;;
    esac
}

parse_ide_list() {
    _raw="$(printf '%s' "$1" | tr ',\n\t' '   ')"
    _parsed=""
    for _candidate in $_raw; do
        [ -n "$_candidate" ] || continue
        _normalized="$(normalize_ide_name "$_candidate")"
        if ! is_supported_ide "$_normalized"; then
            echo "Error: unsupported IDE '$_candidate'. Supported IDEs: $SUPPORTED_IDES" >&2
            return 1
        fi
        case " $_parsed " in
            *" $_normalized "*) ;;
            *) _parsed="${_parsed:+$_parsed }$_normalized" ;;
        esac
    done
    if [ -z "$_parsed" ]; then
        echo "Error: no IDEs selected. Supported IDEs: $SUPPORTED_IDES" >&2
        return 1
    fi
    echo "$_parsed"
}

ide_at_index() {
    _target="$1"
    _i=1
    for _ide_name in $SUPPORTED_IDES; do
        if [ "$_i" = "$_target" ]; then
            echo "$_ide_name"
            return 0
        fi
        _i=$((_i + 1))
    done
    return 1
}

parse_ide_choice() {
    _raw_choice="$(printf '%s' "$1" | tr ',\n\t' '   ')"
    _parsed=""
    _max_count=0
    for _ in $SUPPORTED_IDES; do
        _max_count=$((_max_count + 1))
    done
    for _token in $_raw_choice; do
        [ -n "$_token" ] || continue
        case "$_token" in
            *[!0-9]*)
                _resolved="$(parse_ide_list "$_token")" || return 1
                ;;
            *)
                _resolved=""
                if [ "$_token" -gt "$_max_count" ] 2>/dev/null && \
                   [ "${#_token}" -gt 1 ] && \
                   printf '%s' "$_token" | grep -q '^[1-9][1-9]*$'; then
                    _chars="$(printf '%s' "$_token" | sed 's/./& /g')"
                    for _digit in $_chars; do
                        _digit_ide="$(ide_at_index "$_digit")" || {
                            echo "Error: unsupported IDE selection '$_digit'. Choose 1-$_max_count or use IDE names." >&2
                            return 1
                        }
                        _resolved="${_resolved:+$_resolved }$_digit_ide"
                    done
                else
                    _digit_ide="$(ide_at_index "$_token")" || {
                        echo "Error: unsupported IDE selection '$_token'. Choose 1-$_max_count or use IDE names." >&2
                        return 1
                    }
                    _resolved="$_digit_ide"
                fi
                ;;
        esac
        for _resolved_ide in $_resolved; do
            case " $_parsed " in
                *" $_resolved_ide "*) ;;
                *) _parsed="${_parsed:+$_parsed }$_resolved_ide" ;;
            esac
        done
    done
    if [ -z "$_parsed" ]; then
        echo "Error: no IDEs selected. Choose 1-$_max_count or use IDE names." >&2
        return 1
    fi
    echo "$_parsed"
}

choose_ides() {
    _default_ides="$1"
    _index=1
    for _ide_name in $SUPPORTED_IDES; do
        _summary="$(ide_summary "$_ide_name")"
        if printf ' %s ' "$_default_ides" | grep -q " $_ide_name "; then
            echo "  $_index. $_ide_name - $_summary [detected]" >&2
        else
            echo "  $_index. $_ide_name - $_summary" >&2
        fi
        _index=$((_index + 1))
    done
    echo "  Enter IDE names, numbers like '1,3,4' or '134', 'all', or press Enter to use detected IDEs." >&2
    echo "  Note: cursor = Cursor IDE, kiro = current .amazonq compatibility surface." >&2
    printf "  Select IDEs [%s]: " "$_default_ides" >&2
    if ! IFS= read -r _choice; then
        echo "Error: --choose requires input on stdin" >&2
        return 1
    fi
    _choice="$(printf '%s' "$_choice" | tr '[:upper:]' '[:lower:]')"
    case "$_choice" in
        ""|detected) echo "$_default_ides" ;;
        all) echo "$SUPPORTED_IDES" ;;
        *) parse_ide_choice "$_choice" ;;
    esac
}

detect_ides() {
    _ides=""
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
    [ -f "$PROJECT_DIR/AGENTS.md" ]   && append_ide "codex"
    has_codex_env                    && append_ide "codex"
    [ -f "$PROJECT_DIR/.rules" ]      && append_ide "zed"
    [ -d "$PROJECT_DIR/.roo" ]        && append_ide "roo"
    [ -z "$_ides" ] && append_ide "claude"
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

# Install baton skills to each detected IDE's skill directory
# Skills are the canonical source in .claude/skills/ within baton
install_skills() {
    _skill_count=0
    _fallback_count=0
    for _skill in baton-research baton-plan baton-implement; do
        _src="$BATON_DIR/.claude/skills/$_skill/SKILL.md"
        [ -f "$_src" ] || continue
        for _ide in $IDES; do
            case "$_ide" in
                claude)   _ide_dir="$PROJECT_DIR/.claude/skills/$_skill" ;;
                factory)  _ide_dir="$PROJECT_DIR/.claude/skills/$_skill" ;;
                cursor)   _ide_dir="$PROJECT_DIR/.cursor/skills/$_skill" ;;
                windsurf) _ide_dir="$PROJECT_DIR/.windsurf/skills/$_skill" ;;
                cline)    _ide_dir="$PROJECT_DIR/.cline/skills/$_skill" ;;
                augment)  _ide_dir="$PROJECT_DIR/.augment/skills/$_skill" ;;
                kiro)     _ide_dir="$PROJECT_DIR/.amazonq/skills/$_skill" ;;
                copilot)  _ide_dir="$PROJECT_DIR/.github/skills/$_skill" ;;
                roo)      _ide_dir="$PROJECT_DIR/.roo/skills/$_skill" ;;
                *)        continue ;;
            esac
            _dst="$_ide_dir/SKILL.md"
            if [ "$_dst" = "$_src" ]; then
                continue
            fi
            mkdir -p "$_ide_dir"
            cp "$_src" "$_dst"
            _skill_count=$((_skill_count + 1))
        done
        mkdir -p "$PROJECT_DIR/.agents/skills/$_skill"
        cp "$_src" "$PROJECT_DIR/.agents/skills/$_skill/SKILL.md"
        _fallback_count=$((_fallback_count + 1))
    done
    if [ "$SELF_INSTALL" = "1" ] && [ "$_skill_count" -gt 0 ]; then
        echo "  ✓ Installed baton skills to selected IDE directories + .agents/ fallback (self-install)"
    elif [ "$SELF_INSTALL" = "1" ] && [ "$_fallback_count" -gt 0 ]; then
        echo "  ✓ Installed baton skills to .agents/ fallback (self-install)"
    elif [ "$_skill_count" -gt 0 ]; then
        echo "  ✓ Installed baton skills to $(echo "$IDES" | wc -w | tr -d ' ') IDE(s) + .agents/ fallback"
    elif [ "$_fallback_count" -gt 0 ]; then
        echo "  ✓ Installed baton skills to .agents/ fallback"
    fi
}

merge_json_with_jq() {
    _mj_file="$1"
    _mj_filter="$2"
    shift 2
    if ! command -v jq >/dev/null 2>&1; then
        return 2
    fi
    if ! jq empty "$_mj_file" >/dev/null 2>&1; then
        return 3
    fi
    _mj_tmp="$_mj_file.baton.tmp"
    if ! jq "$@" "$_mj_filter" "$_mj_file" > "$_mj_tmp"; then
        rm -f "$_mj_tmp"
        return 4
    fi
    if cmp -s "$_mj_file" "$_mj_tmp"; then
        rm -f "$_mj_tmp"
        return 1
    fi
    mv "$_mj_tmp" "$_mj_file"
    return 0
}

merge_nested_hook_entry() {
    _mn_file="$1"
    _mn_event="$2"
    _mn_command="$3"
    _mn_entry="$4"
    merge_json_with_jq "$_mn_file" '
        .hooks = ((.hooks // {}) | if type == "object" then . else {} end) |
        .hooks[$event] = ((.hooks[$event] // []) | if type == "array" then . else [] end) |
        if any(.hooks[$event][]?; any((.hooks // [])[]?; .command == $command)) then
            .
        else
            .hooks[$event] += [$entry]
        end
    ' --arg event "$_mn_event" --arg command "$_mn_command" --argjson entry "$_mn_entry"
}

merge_flat_hook_entry() {
    _mf_file="$1"
    _mf_event="$2"
    _mf_field="$3"
    _mf_value="$4"
    _mf_entry="$5"
    merge_json_with_jq "$_mf_file" '
        .hooks = ((.hooks // {}) | if type == "object" then . else {} end) |
        .hooks[$event] = ((.hooks[$event] // []) | if type == "array" then . else [] end) |
        if any(.hooks[$event][]?; .[$field] == $value) then
            .
        else
            .hooks[$event] += [$entry]
        end
    ' --arg event "$_mf_event" --arg field "$_mf_field" --arg value "$_mf_value" --argjson entry "$_mf_entry"
}

ensure_json_default() {
    _ej_file="$1"
    _ej_key="$2"
    _ej_value="$3"
    merge_json_with_jq "$_ej_file" '
        .[$key] = (.[$key] // $value)
    ' --arg key "$_ej_key" --argjson value "$_ej_value"
}

record_merge_status() {
    case "$1" in
        0) MERGE_CHANGED=1 ;;
        1) ;;
        *) MERGE_FAILED=1 ;;
    esac
}

run_merge_and_record() {
    if "$@"; then
        _rm_status=0
    else
        _rm_status=$?
    fi
    record_merge_status "$_rm_status"
    return 0
}

report_merge_result() {
    _rm_path="$1"
    if [ "${MERGE_FAILED:-0}" = "1" ]; then
        echo "  ⚠ $_rm_path exists but Baton could not merge hooks automatically — review manually"
    elif [ "${MERGE_CHANGED:-0}" = "1" ]; then
        echo "  ✓ Merged missing Baton hooks into $_rm_path"
    else
        echo "  ✓ Hooks already configured in $_rm_path"
    fi
}

is_legacy_cline_hook_stub() {
    _clh_file="$1"
    _clh_marker="$2"
    grep -q "$_clh_marker" "$_clh_file" 2>/dev/null
}

write_cline_hook_wrapper() {
    _wch_file="$1"
    _wch_event="$2"
    _wch_adapter_rel="$3"
    cat > "$_wch_file" <<EOF
#!/bin/sh
# baton-cline-wrapper: $_wch_event
INPUT=\$(cat 2>/dev/null || true)
SELF_DIR=\$(CDPATH= cd -- "\$(dirname "\$0")" 2>/dev/null && pwd)
USER_HOOK="\$SELF_DIR/$_wch_event.baton-user"
BATON_OUTPUT=\$(printf '%s' "\$INPUT" | bash "\$(dirname "\$0")/../../$_wch_adapter_rel" 2>/dev/null || true)
if printf '%s' "\$BATON_OUTPUT" | grep -q '"cancel":true'; then
    printf '%s\n' "\$BATON_OUTPUT"
    exit 0
fi
if [ -f "\$USER_HOOK" ]; then
    printf '%s' "\$INPUT" | sh "\$USER_HOOK"
else
    if [ -n "\$BATON_OUTPUT" ]; then
        printf '%s\n' "\$BATON_OUTPUT"
    else
        printf '{"cancel":false}\n'
    fi
fi
EOF
    chmod +x "$_wch_file"
}

install_cline_hook_wrapper() {
    _ich_event="$1"
    _ich_adapter_rel="$2"
    _ich_legacy_marker="$3"
    _ich_hook="$PROJECT_DIR/.clinerules/hooks/$_ich_event"
    _ich_backup="$_ich_hook.baton-user"
    if [ -f "$_ich_hook" ] && grep -q 'baton-cline-wrapper' "$_ich_hook" 2>/dev/null; then
        echo "  ✓ .clinerules/hooks/$_ich_event already wrapped for Baton"
        return
    fi
    if [ -f "$_ich_hook" ] && is_legacy_cline_hook_stub "$_ich_hook" "$_ich_legacy_marker"; then
        rm -f "$_ich_backup"
        write_cline_hook_wrapper "$_ich_hook" "$_ich_event" "$_ich_adapter_rel"
        echo "  ✓ Upgraded .clinerules/hooks/$_ich_event to Baton wrapper"
        return
    fi
    if [ -f "$_ich_hook" ]; then
        mv "$_ich_hook" "$_ich_backup"
        write_cline_hook_wrapper "$_ich_hook" "$_ich_event" "$_ich_adapter_rel"
        echo "  ✓ Wrapped existing .clinerules/hooks/$_ich_event and preserved user hook"
        return
    fi
    write_cline_hook_wrapper "$_ich_hook" "$_ich_event" "$_ich_adapter_rel"
    echo "  ✓ Created .clinerules/hooks/$_ich_event → $_ich_adapter_rel"
}

# --- Per-IDE configuration functions ---

configure_claude() {
    echo "  --- Claude Code ---"
    mkdir -p "$PROJECT_DIR/.claude"
    SETTINGS="$PROJECT_DIR/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
        if grep -q '.claude/write-lock' "$SETTINGS" 2>/dev/null; then
            sed -i.bak 's|\.claude/write-lock\.sh|.baton/hooks/write-lock.sh|g' "$SETTINGS"
            rm -f "$SETTINGS.bak"
            echo "  ✓ Updated write-lock path in settings.json (.claude/ → .baton/)"
        fi
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "SessionStart" "bash .baton/hooks/phase-guide.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/phase-guide.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "PreToolUse" "bash .baton/hooks/write-lock.sh" '{"matcher":"Edit|Write|MultiEdit|CreateFile|NotebookEdit","hooks":[{"type":"command","command":"bash .baton/hooks/write-lock.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "PostToolUse" "bash .baton/hooks/post-write-tracker.sh" '{"matcher":"Edit|Write|MultiEdit|CreateFile","hooks":[{"type":"command","command":"bash .baton/hooks/post-write-tracker.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "Stop" "bash .baton/hooks/stop-guard.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/stop-guard.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "SubagentStart" "bash .baton/hooks/subagent-context.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/subagent-context.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "TaskCompleted" "bash .baton/hooks/completion-check.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/completion-check.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$SETTINGS" "PreCompact" "bash .baton/hooks/pre-compact.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/pre-compact.sh"}]}'
        report_merge_result ".claude/settings.json"
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
    # Inject workflow reference into CLAUDE.md (slim — phase-guide provides details)
    CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ] && grep -qE '@\.baton/workflow(-full)?\.md' "$CLAUDE_MD" 2>/dev/null; then
        # Migrate old @workflow-full.md → @workflow.md (slim)
        if grep -q '@\.baton/workflow-full\.md' "$CLAUDE_MD" 2>/dev/null; then
            sed -i.bak 's|@\.baton/workflow-full\.md|@.baton/workflow.md|g' "$CLAUDE_MD"
            rm -f "$CLAUDE_MD.bak"
            echo "  ✓ Migrated CLAUDE.md @import: workflow-full.md → workflow.md (slim)"
        else
            echo "  ✓ Workflow @import already in CLAUDE.md"
        fi
    elif [ -f "$CLAUDE_MD" ]; then
        if ! grep -q '## AI Workflow' "$CLAUDE_MD" 2>/dev/null; then
            printf '\n@.baton/workflow.md\n' >> "$CLAUDE_MD"
            echo "  ✓ Added @.baton/workflow.md to CLAUDE.md"
        fi
    else
        printf '@.baton/workflow.md\n' > "$CLAUDE_MD"
        echo "  ✓ Created CLAUDE.md with @.baton/workflow.md"
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
    # Rules file — embed slim workflow (phase-guide.sh provides phase-specific details)
    {
        printf '%s\n' '---'
        printf '%s\n' 'description: Baton plan-first workflow enforcer'
        printf '%s\n' 'alwaysApply: true'
        printf '%s\n' '---'
        printf '\n'
        cat "$BATON_DIR/.baton/workflow.md"
    } > "$PROJECT_DIR/.cursor/rules/baton.mdc"
    echo "  ✓ Created .cursor/rules/baton.mdc (slim workflow + phase-guide provides details)"
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
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record ensure_json_default "$PROJECT_DIR/.cursor/hooks.json" "version" '1'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.cursor/hooks.json" "sessionStart" "command" "bash .baton/hooks/phase-guide.sh" '{"command":"bash .baton/hooks/phase-guide.sh","timeout":10}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.cursor/hooks.json" "preToolUse" "command" "bash .baton/adapters/adapter-cursor.sh" '{"command":"bash .baton/adapters/adapter-cursor.sh","matcher":"Write","timeout":10}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.cursor/hooks.json" "subagentStart" "command" "bash .baton/hooks/subagent-context.sh" '{"command":"bash .baton/hooks/subagent-context.sh","timeout":10}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.cursor/hooks.json" "preCompact" "command" "bash .baton/hooks/pre-compact.sh" '{"command":"bash .baton/hooks/pre-compact.sh","timeout":10}'
        report_merge_result ".cursor/hooks.json"
    fi
    install_adapter "adapter-cursor.sh"
}

configure_windsurf() {
    echo "  --- Windsurf ---"
    mkdir -p "$PROJECT_DIR/.windsurf/rules"
    # Rules file — slim workflow; detailed phase methodology lives in skills
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.windsurf/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (slim) to .windsurf/rules/ (skills are primary)"
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
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.windsurf/hooks.json" "pre_write_code" "command" "bash .baton/hooks/write-lock.sh" '{"command":"bash .baton/hooks/write-lock.sh","show_output":true}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.windsurf/hooks.json" "pre_run_command" "command" "bash .baton/hooks/bash-guard.sh" '{"command":"bash .baton/hooks/bash-guard.sh","show_output":true}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.windsurf/hooks.json" "post_write_code" "command" "bash .baton/hooks/post-write-tracker.sh" '{"command":"bash .baton/hooks/post-write-tracker.sh","show_output":true}'
        report_merge_result ".windsurf/hooks.json"
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
    # Cline supports skills (v3.48+) — keep always-loaded rules slim
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.clinerules/baton-workflow.md"
    echo "  ✓ Copied workflow (slim) to .clinerules/ (skills are primary)"
    install_adapter "adapter-cline.sh"
    install_adapter "adapter-cline-taskcomplete.sh"
    # Create hook wiring files — Cline discovers hooks via .clinerules/hooks/<EventName>
    mkdir -p "$PROJECT_DIR/.clinerules/hooks"
    install_cline_hook_wrapper "PreToolUse" ".baton/adapters/adapter-cline.sh" 'adapter-cline\.sh'
    install_cline_hook_wrapper "TaskComplete" ".baton/adapters/adapter-cline-taskcomplete.sh" 'completion-check\.sh\|adapter-cline-taskcomplete\.sh'
}

configure_augment() {
    echo "  --- Augment Code ---"
    mkdir -p "$PROJECT_DIR/.augment/rules"
    # Rules: embed slim workflow (phase-guide.sh provides phase-specific details)
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.augment/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (slim) to .augment/rules/"
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
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record merge_nested_hook_entry "$PROJECT_DIR/.augment/settings.json" "SessionStart" "bash .baton/hooks/phase-guide.sh" '{"matcher":"","hooks":[{"type":"command","command":"bash .baton/hooks/phase-guide.sh"}]}'
        run_merge_and_record merge_nested_hook_entry "$PROJECT_DIR/.augment/settings.json" "PreToolUse" "bash .baton/hooks/write-lock.sh" '{"matcher":"str-replace-editor|save-file","hooks":[{"type":"command","command":"bash .baton/hooks/write-lock.sh","timeout":5000}]}'
        report_merge_result ".augment/settings.json"
    fi
}

configure_kiro() {
    echo "  --- Kiro compatibility surface (.amazonq) ---"
    mkdir -p "$PROJECT_DIR/.amazonq/rules"
    # Baton currently targets the shared .amazonq project surface.
    # Official Kiro and Amazon Q hook models differ, but this installer does not
    # split them into separate targets yet.
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.amazonq/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (slim) to .amazonq/rules/ (skills are primary)"
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
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.amazonq/hooks.json" "preToolUse" "command" "bash .baton/hooks/write-lock.sh" '{"matcher":"fs_write","command":"bash .baton/hooks/write-lock.sh","timeout_ms":10000}'
        report_merge_result ".amazonq/hooks.json"
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
        MERGE_CHANGED=0
        MERGE_FAILED=0
        run_merge_and_record ensure_json_default "$PROJECT_DIR/.github/hooks/baton.json" "version" '1'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.github/hooks/baton.json" "sessionStart" "bash" "bash .baton/hooks/phase-guide.sh" '{"type":"command","bash":"bash .baton/hooks/phase-guide.sh","timeoutSec":10}'
        run_merge_and_record merge_flat_hook_entry "$PROJECT_DIR/.github/hooks/baton.json" "preToolUse" "bash" "bash .baton/adapters/adapter-copilot.sh" '{"type":"command","bash":"bash .baton/adapters/adapter-copilot.sh","timeoutSec":10}'
        report_merge_result ".github/hooks/baton.json"
    fi
    install_adapter "adapter-copilot.sh"
    # Rules: append to copilot-instructions.md
    COPILOT_MD="$PROJECT_DIR/.github/copilot-instructions.md"
    if [ -f "$COPILOT_MD" ] && grep -q 'baton' "$COPILOT_MD" 2>/dev/null; then
        echo "  ✓ Workflow reference already in copilot-instructions.md"
    elif [ -f "$COPILOT_MD" ]; then
        printf '\n## Workflow\n\nFollow the plan-first workflow in .baton/workflow.md\n' >> "$COPILOT_MD"
        echo "  ✓ Added workflow reference to copilot-instructions.md"
    else
        printf '## Workflow\n\nFollow the plan-first workflow in .baton/workflow.md\n' > "$COPILOT_MD"
        echo "  ✓ Created copilot-instructions.md with workflow reference"
    fi
}

configure_codex() {
    echo "  --- Codex CLI ---"
    # No hooks — rules injection only
    AGENTS_MD="$PROJECT_DIR/AGENTS.md"
    if [ -f "$AGENTS_MD" ] && grep -q '@\.baton/workflow\.md' "$AGENTS_MD" 2>/dev/null; then
        echo "  ✓ Workflow reference already in AGENTS.md"
    elif [ -f "$AGENTS_MD" ] && grep -q '@\.baton/workflow-full\.md' "$AGENTS_MD" 2>/dev/null; then
        sed -i.bak 's|@\.baton/workflow-full\.md|@.baton/workflow.md|g' "$AGENTS_MD"
        rm -f "$AGENTS_MD.bak"
        echo "  ✓ Migrated AGENTS.md @import: workflow-full.md → workflow.md"
    elif [ -f "$AGENTS_MD" ]; then
        printf '\n@.baton/workflow.md\n' >> "$AGENTS_MD"
        echo "  ✓ Added @.baton/workflow.md to AGENTS.md"
    else
        printf '@.baton/workflow.md\n' > "$AGENTS_MD"
        echo "  ✓ Created AGENTS.md with @.baton/workflow.md"
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
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.roo/rules/baton-workflow.md"
    echo "  ✓ Copied workflow (slim) to .roo/rules/ (skills are primary)"
    echo "  💡 Roo Code remains rules-guidance only in Baton for now"
}

# ==========================================
# Main installation flow
# ==========================================

DETECTED_IDES="$(detect_ides)"
if [ "$CHOOSE_IDES" = "1" ]; then
    IDES="$(choose_ides "$DETECTED_IDES")"
elif [ -n "$REQUESTED_IDES" ]; then
    IDES="$(parse_ide_list "$REQUESTED_IDES")"
else
    IDES="$DETECTED_IDES"
fi
SOURCE_VERSION="$(get_version "$BATON_DIR/.baton/hooks/write-lock.sh")"

echo "Installing baton v${SOURCE_VERSION:-3.0} into: $PROJECT_DIR"
echo "  Detected IDEs: $DETECTED_IDES"
if [ "$IDES" = "$DETECTED_IDES" ] && [ "$CHOOSE_IDES" = "0" ] && [ -z "$REQUESTED_IDES" ]; then
    echo "  Selected IDEs: $IDES (auto)"
elif [ "$CHOOSE_IDES" = "1" ]; then
    echo "  Selected IDEs: $IDES ($CHOOSE_IDES_SOURCE)"
elif [ -n "$REQUESTED_IDES" ]; then
    echo "  Selected IDEs: $IDES ($REQUESTED_IDES_SOURCE)"
else
    echo "  Selected IDEs: $IDES"
fi

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
    echo "    Remove the '## AI Workflow' section and add: @.baton/workflow.md"
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
else
    cp "$BATON_DIR/.baton/workflow.md" "$PROJECT_DIR/.baton/workflow.md"
    echo "  ✓ Installed workflow.md (slim — detailed phase guidance lives in skills)"
fi

# Always copy workflow-full.md as reference
if [ "$SELF_INSTALL" != "1" ]; then
    cp "$BATON_DIR/.baton/workflow-full.md" "$PROJECT_DIR/.baton/workflow-full.md"
fi

# Install baton skills to all detected IDEs
install_skills

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
if echo "$IDES" | grep -Eq '(^| )(claude|factory|cursor|windsurf|cline|augment|kiro|copilot)( |$)'; then
    echo "     → Baton guides the AI to research deeply first (code writes stay blocked until approval)"
else
    echo "     → Baton guides the AI to research deeply first via rules (and skills where supported); no hook-based write lock in this IDE"
fi
echo ""
echo "  2. Tell the AI what you want to build or fix"
echo "     → The AI writes research.md, then plan.md with proposed changes"
echo ""
echo "  3. Annotate plan.md with [NOTE] [Q] [CHANGE] [DEEPER] [MISSING]"
echo "     → AI responds to each annotation, cycle until satisfied"
echo ""
echo "  4. When satisfied, add this line to plan.md:"
echo "     <!-- BATON:GO -->"
echo "     → Then tell the AI \"generate todolist\" before implementation"
echo ""
echo "  5. Once ## Todo exists, implementation can begin"
if echo "$IDES" | grep -q 'codex'; then
    echo "     → Codex follows this via AGENTS.md + .agents/skills/ guidance (no hooks)"
fi
echo ""
echo "  To remove: bash $BATON_DIR/setup.sh --uninstall $PROJECT_DIR"

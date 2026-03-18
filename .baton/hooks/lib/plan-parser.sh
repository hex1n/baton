#!/usr/bin/env bash
# plan-parser.sh — shared parser/discovery layer for baton hooks and bin/baton
# Version: 1.3 (1A discovery + 1B section + 1C write-set primitives)
#
# Sourced through _common.sh. Do not source directly from hooks.
#
# 1A primitives:
#   parser_find_plan      — walk-up plan discovery + multi-plan count
#   parser_find_research  — paired research discovery + glob fallback
#   parser_has_go         — BATON:GO presence check
#   parser_has_skill      — skill directory walk-up (includes .baton/skills)
#   parser_project_root   — infer Baton project root / plan root
#
# 1B primitives:
#   parser_todo_range          — ## Todo section line range
#   parser_todo_counts         — done/remaining/total Todo counts scoped to ## Todo
#   parser_todo_items          — Todo checklist items scoped to ## Todo
#   parser_todo_remaining_items — unchecked Todo checklist items scoped to ## Todo
#   parser_retro_range         — ## Retrospective section line range
#   parser_retro_valid         — ≥3 non-empty content lines check
#
# 1C primitives:
#   parser_writeset_normalize — path normalization (strip ./, absolute→relative)
#   parser_writeset_extract   — Files: field extraction from ## Todo items
#   parser_writeset_contains  — path membership check against Todo write set

# Guard against double-sourcing
[ -n "${_BATON_PARSER_LOADED:-}" ] && return 0
_BATON_PARSER_LOADED=1

# parser_find_plan — walk up from JSON_CWD/cwd to find plan file
# Inputs:  BATON_PLAN env (optional, explicit plan name)
# Sets:    PLAN (full path or empty), PLAN_NAME (filename), MULTI_PLAN_COUNT
# shellcheck disable=SC2034
parser_find_plan() {
    PLAN=""
    PLAN_NAME=""
    export MULTI_PLAN_COUNT=0
    local _d="${JSON_CWD:-$(pwd)}"

    if [ -n "${BATON_PLAN:-}" ]; then
        PLAN_NAME="$BATON_PLAN"
        while true; do
            if [ -f "$_d/$PLAN_NAME" ]; then
                PLAN="$_d/$PLAN_NAME"
                export MULTI_PLAN_COUNT=0
                return
            fi
            local _p
            _p="$(dirname "$_d")"
            [ "$_p" = "$_d" ] && { export MULTI_PLAN_COUNT=0; return; }
            _d="$_p"
        done
    else
        while true; do
            # Collect candidates: root plans + baton-tasks plans
            local _candidates
            _candidates="$(cd "$_d" 2>/dev/null && ls -t plan.md plan-*.md baton-tasks/*/plan.md baton-tasks/*/plan-*.md 2>/dev/null)" || true

            # Filter out COMPLETE-marked plans
            local _active=""
            if [ -n "$_candidates" ]; then
                while IFS= read -r _f; do
                    [ -z "$_f" ] && continue
                    if ! grep -q '^[[:space:]]*<!-- BATON:COMPLETE -->[[:space:]]*$' "$_d/$_f" 2>/dev/null; then
                        _active="${_active:+${_active}
}$_f"
                    fi
                done <<< "$_candidates"
            fi

            if [ -n "$_active" ]; then
                local _c
                _c="$(printf '%s\n' "$_active" | head -1)"
                PLAN_NAME="$_c"
                PLAN="$_d/$_c"
                local _count
                _count="$(printf '%s\n' "$_active" | wc -l | tr -d ' ')"

                # --- Disambiguation when multiple active plans found ---
                if [ "$_count" -gt 1 ] 2>/dev/null; then
                    # Layer 1: BATON:GO uniqueness — exactly one plan has GO → select it
                    local _go_plan="" _go_count=0
                    while IFS= read -r _gf; do
                        [ -z "$_gf" ] && continue
                        if grep -q '<!-- BATON:GO -->' "$_d/$_gf" 2>/dev/null; then
                            _go_plan="$_gf"
                            _go_count=$((_go_count + 1))
                        fi
                    done <<< "$_active"
                    if [ "$_go_count" -eq 1 ]; then
                        PLAN_NAME="$_go_plan"
                        PLAN="$_d/$_go_plan"
                        export MULTI_PLAN_COUNT=1
                        return
                    fi

                    # Layer 2: BATON_TARGET context — target in baton-tasks/<topic>/ → prefer that plan
                    if [ -n "${BATON_TARGET:-}" ]; then
                        local _target_rel
                        case "$BATON_TARGET" in
                            "$_d"/*) _target_rel="${BATON_TARGET#"$_d"/}" ;;
                            *) _target_rel="$BATON_TARGET" ;;
                        esac
                        case "$_target_rel" in
                            baton-tasks/*/*)
                                local _topic_dir
                                _topic_dir="${_target_rel#baton-tasks/}"
                                _topic_dir="baton-tasks/${_topic_dir%%/*}"
                                local _match=""
                                while IFS= read -r _tf; do
                                    [ -z "$_tf" ] && continue
                                    case "$_tf" in
                                        "$_topic_dir/"*) _match="$_tf"; break ;;
                                    esac
                                done <<< "$_active"
                                if [ -n "$_match" ]; then
                                    PLAN_NAME="$_match"
                                    PLAN="$_d/$_match"
                                    export MULTI_PLAN_COUNT=1
                                    return
                                fi
                                ;;
                        esac
                    fi
                fi

                export MULTI_PLAN_COUNT="$_count"
                if [ "$_count" -gt 1 ] 2>/dev/null; then
                    echo "⚠️ Multiple plan files found ($PLAN_NAME selected by mtime). Set BATON_PLAN=<filename> to select one, or remove unused plans." >&2
                fi
                return
            fi
            local _p
            _p="$(dirname "$_d")"
            [ "$_p" = "$_d" ] && { PLAN_NAME="plan.md"; export MULTI_PLAN_COUNT=0; return; }
            _d="$_p"
        done
    fi
}

# parser_find_research — find paired research file for current plan
# Prerequisite: parser_find_plan must have been called (PLAN/PLAN_NAME set)
# Sets:    RESEARCH (full path or empty), RESEARCH_NAME (filename)
#          RESEARCH_FALLBACK_COUNT (number of research-*.md when glob fallback used)
# shellcheck disable=SC2034
parser_find_research() {
    RESEARCH=""
    RESEARCH_FALLBACK_COUNT=0

    # Determine plan directory (or cwd if no plan found)
    local _plan_dir
    if [ -n "$PLAN" ]; then
        _plan_dir="${PLAN%/*}"
    else
        _plan_dir="${JSON_CWD:-$(pwd)}"
    fi
    [ -z "$_plan_dir" ] && _plan_dir="$(pwd)"

    if [ -n "$PLAN" ]; then
        # Derive research name from plan filename (not full PLAN_NAME path)
        # This correctly handles baton-tasks/<topic>/plan.md paths
        local _plan_basename
        _plan_basename="$(basename "$PLAN")"
        RESEARCH_NAME="${_plan_basename/plan/research}"

        if [ -f "$_plan_dir/$RESEARCH_NAME" ]; then
            RESEARCH="$_plan_dir/$RESEARCH_NAME"
            return
        fi
    else
        RESEARCH_NAME="${PLAN_NAME/plan/research}"

        # Glob fallback: only when no plan found
        # Searches root + baton-tasks subdirectories
        local _rf_list
        _rf_list="$(cd "$_plan_dir" 2>/dev/null && ls -t research-*.md research.md baton-tasks/*/research.md 2>/dev/null)" || true
        if [ -n "$_rf_list" ]; then
            RESEARCH_FALLBACK_COUNT="$(printf '%s\n' "$_rf_list" | wc -l | tr -d ' ')"
            if [ "$RESEARCH_FALLBACK_COUNT" -eq 1 ]; then
                RESEARCH_NAME="$(printf '%s\n' "$_rf_list" | head -1)"
                RESEARCH="$_plan_dir/$RESEARCH_NAME"
                # Derive plan name from discovered research
                PLAN_NAME="${RESEARCH_NAME/research/plan}"
            fi
        fi
    fi

}

# parser_has_go — check if plan has <!-- BATON:GO --> marker
# Args:    $1 = plan file path (defaults to $PLAN)
# Returns: 0 if present, 1 if not (or file doesn't exist)
parser_has_go() {
    local _plan="${1:-$PLAN}"
    [ -n "$_plan" ] && [ -f "$_plan" ] && grep -q '<!-- BATON:GO -->' "$_plan" 2>/dev/null
}

# parser_has_skill — check if baton skill exists by name
# Walks up from JSON_CWD/cwd checking .baton/skills, .claude/skills,
# .cursor/skills, .agents/skills at each directory level.
# Args:    $1 = skill name
# Returns: 0 if found, 1 if not
parser_has_skill() {
    local _name="$1"
    local _d="${JSON_CWD:-$(pwd)}"
    while true; do
        for _ide in .baton .claude .cursor .agents; do
            [ -f "$_d/$_ide/skills/$_name/SKILL.md" ] && return 0
        done
        local _p
        _p="$(dirname "$_d")"
        [ "$_p" = "$_d" ] && return 1
        _d="$_p"
    done
    return 1
}

# parser_project_root — infer Baton project root / plan root
# Priority:
#   1. explicit plan directory if PLAN is already known
#   2. nearest ancestor containing Baton/project markers
#   3. original start directory
# Args:    $1 = starting directory (optional)
# Outputs: project root path to stdout
parser_project_root() {
    # Always use marker walk-up (no plan directory shortcut).
    # Prevents baton-tasks/<topic>/ from being treated as project root.
    local _d="${1:-${JSON_CWD:-$(pwd)}}"
    [ -z "$_d" ] && _d="$(pwd)"
    [ -f "$_d" ] && _d="$(dirname "$_d")"
    local _fallback="$_d"

    while true; do
        if [ -d "$_d/.baton" ] || [ -d "$_d/.git" ] || [ -d "$_d/.claude" ] || \
           [ -d "$_d/.cursor" ] || [ -d "$_d/.codex" ] || \
           [ -f "$_d/AGENTS.md" ] || [ -f "$_d/CLAUDE.md" ]; then
            printf '%s\n' "$_d"
            return
        fi
        local _p
        _p="$(dirname "$_d")"
        [ "$_p" = "$_d" ] && {
            printf '%s\n' "$_fallback"
            return
        }
        _d="$_p"
    done
}

# ============================================================
# 1B Section Primitives
# ============================================================

# parser_todo_range — find ## Todo section line range
# Args:    $1 = plan file path (defaults to $PLAN)
# Sets:    TODO_START (header line number), TODO_END (last line of section)
#          Both 0 if section not found.
# shellcheck disable=SC2034
parser_todo_range() {
    local _plan="${1:-$PLAN}"
    TODO_START=0
    TODO_END=0
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    local _result
    _result="$(awk '
        /^## Todo[[:space:]]*$/ { start=NR; next }
        start && /^## / { print start, NR-1; found=1; exit }
        END { if (start && !found) print start, NR }
    ' "$_plan")" || true
    if [ -n "$_result" ]; then
        TODO_START="${_result%% *}"
        TODO_END="${_result##* }"
    fi
}

# parser_todo_counts — count done/remaining/total Todo items scoped to ## Todo only
# Args:    $1 = plan file path (defaults to $PLAN)
# Sets:    TODO_TOTAL, TODO_DONE, TODO_REMAINING
# shellcheck disable=SC2034
parser_todo_counts() {
    local _plan="${1:-$PLAN}"
    TODO_TOTAL=0
    TODO_DONE=0
    TODO_REMAINING=0
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    local _result
    _result="$(awk '
        /^## Todo[[:space:]]*$/ { in_todo=1; next }
        in_todo && /^## / { exit }
        in_todo && /^- \[/ { total++ }
        in_todo && /^- \[[xX]\]/ { done++ }
        END { print (total+0), (done+0) }
    ' "$_plan")" || true
    TODO_TOTAL="${_result%% *}"
    TODO_DONE="${_result##* }"
    TODO_REMAINING=$((TODO_TOTAL - TODO_DONE))
}

# parser_todo_items — output Todo checklist items scoped to ## Todo only
# Args:    $1 = plan file path (defaults to $PLAN)
# Outputs: newline-separated checklist item lines to stdout
parser_todo_items() {
    local _plan="${1:-$PLAN}"
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    awk '
        /^## Todo[[:space:]]*$/ { in_todo=1; next }
        in_todo && /^## / { exit }
        in_todo && /^- \[/ { print }
    ' "$_plan"
}

# parser_todo_remaining_items — output unchecked Todo checklist items scoped to ## Todo
# Args:    $1 = plan file path (defaults to $PLAN)
# Outputs: newline-separated unchecked checklist item lines to stdout
parser_todo_remaining_items() {
    local _plan="${1:-$PLAN}"
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    awk '
        /^## Todo[[:space:]]*$/ { in_todo=1; next }
        in_todo && /^## / { exit }
        in_todo && /^- \[ \]/ { print }
    ' "$_plan"
}

# parser_retro_range — find ## Retrospective section line range
# Args:    $1 = plan file path (defaults to $PLAN)
# Sets:    RETRO_START (header line number), RETRO_END (last line of section)
#          Both 0 if section not found.
# shellcheck disable=SC2034
parser_retro_range() {
    local _plan="${1:-$PLAN}"
    RETRO_START=0
    RETRO_END=0
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    local _result
    _result="$(awk '
        /^## Retrospective[[:space:]]*$/ { start=NR; next }
        start && /^## / { print start, NR-1; found=1; exit }
        END { if (start && !found) print start, NR }
    ' "$_plan")" || true
    if [ -n "$_result" ]; then
        RETRO_START="${_result%% *}"
        RETRO_END="${_result##* }"
    fi
}

# parser_retro_valid — check if ## Retrospective has ≥3 non-empty content lines
# Args:    $1 = plan file path (defaults to $PLAN)
# Sets:    RETRO_LINE_COUNT
# Returns: 0 if valid (≥3 non-empty lines), 1 if not
parser_retro_valid() {
    local _plan="${1:-$PLAN}"
    RETRO_LINE_COUNT=0
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return 1
    RETRO_LINE_COUNT="$(awk '
        /^## Retrospective[[:space:]]*$/ { in_retro=1; next }
        in_retro && /^## / { exit }
        in_retro && /[^[:space:]]/ { count++ }
        END { print (count+0) }
    ' "$_plan")" || RETRO_LINE_COUNT=0
    [ "$RETRO_LINE_COUNT" -ge 3 ] 2>/dev/null
}

# ============================================================
# 1C Write-Set Primitives
# ============================================================

# parser_writeset_normalize — normalize a file path for write-set comparison
# Strips leading ./, converts absolute paths to project-relative via Baton root.
# Args:    $1 = file path, $2 = explicit project root override (optional)
# Outputs: normalized path to stdout
parser_writeset_normalize() {
    local _path="$1"
    [ -z "$_path" ] && return
    # Strip leading ./
    _path="${_path#./}"
    # If absolute, make relative to Baton project root / plan root
    if [ "${_path#/}" != "$_path" ]; then
        local _root
        _root="${2:-}"
        [ -z "$_root" ] && _root="$(parser_project_root)"
        if [ -n "$_root" ] && [ "${_path#"$_root"/}" != "$_path" ]; then
            _path="${_path#"$_root"/}"
        fi
    fi
    printf '%s\n' "$_path"
}

# parser_writeset_extract — extract all file paths from Files: fields in ## Todo section
# Parses backtick-wrapped, comma-separated paths. Strips annotations like (new)
# and completion metadata after |. Deduplicates output.
# Args:    $1 = plan file path (defaults to $PLAN)
# Outputs: newline-separated list of normalized, deduplicated paths to stdout
parser_writeset_extract() {
    local _plan="${1:-$PLAN}"
    [ -z "$_plan" ] || [ ! -f "$_plan" ] && return
    awk '
        /^## Todo[[:space:]]*$/ { in_todo=1; next }
        in_todo && /^## / { exit }
        in_todo && /^[[:space:]]+Files:/ {
            sub(/^[[:space:]]+Files:[[:space:]]*/, "")
            sub(/[[:space:]]*\|.*$/, "")
            n = split($0, items, ",")
            for (i = 1; i <= n; i++) {
                path = items[i]
                gsub(/`/, "", path)
                gsub(/\([^)]*\)/, "", path)
                gsub(/^[[:space:]]+/, "", path)
                gsub(/[[:space:]]+$/, "", path)
                sub(/^\.\//, "", path)
                if (path != "") print path
            }
        }
    ' "$_plan" | sort -u
}

# parser_writeset_contains — check if a file path is in the Todo write set
# Normalizes the input path, then checks against extracted write set paths.
# Args:    $1 = file path to check, $2 = plan file path (defaults to $PLAN)
# Returns: 0 if in write set, 1 if not
parser_writeset_contains() {
    local _path
    _path="$(parser_writeset_normalize "$1")"
    local _plan="${2:-$PLAN}"
    [ -z "$_path" ] && return 1
    parser_writeset_extract "$_plan" | grep -qxF "$_path"
}

#!/bin/sh
# _common.sh — shared functions for baton hooks
# Sourced by all hooks: . "$SCRIPT_DIR/_common.sh"

# resolve_plan_name — sets PLAN_NAME from BATON_PLAN env, glob, or default
resolve_plan_name() {
    if [ -n "${BATON_PLAN:-}" ]; then
        PLAN_NAME="$BATON_PLAN"
    else
        _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
        PLAN_NAME="${_candidate:-plan.md}"
    fi
}

# find_plan — walk up from JSON_CWD/cwd to find $PLAN_NAME, sets PLAN
# Call resolve_plan_name first. Supports JSON_CWD for hook-provided cwd.
# shellcheck disable=SC2034
find_plan() {
    PLAN=""
    _fp_d="${JSON_CWD:-$(pwd)}"
    while true; do
        [ -f "$_fp_d/$PLAN_NAME" ] && { PLAN="$_fp_d/$PLAN_NAME"; return; }
        _fp_p="$(dirname "$_fp_d")"
        [ "$_fp_p" = "$_fp_d" ] && return
        _fp_d="$_fp_p"
    done
}

# has_skill NAME — check if baton skill exists in .claude/.cursor/.agents
has_skill() {
    _hs_name="$1"
    _hs_d="$(pwd)"
    while true; do
        for _hs_ide in .claude .cursor .agents; do
            [ -f "$_hs_d/$_hs_ide/skills/$_hs_name/SKILL.md" ] && return 0
        done
        _hs_p="$(dirname "$_hs_d")"
        [ "$_hs_p" = "$_hs_d" ] && return 1
        _hs_d="$_hs_p"
    done
    return 1
}

# extract_section SEC [NEXT_SEC] — extract markdown section from $WORKFLOW_FULL
# Caller must set WORKFLOW_FULL. Returns 1 if extraction fails or is empty.
extract_section() {
    [ -z "${WORKFLOW_FULL:-}" ] || [ ! -f "$WORKFLOW_FULL" ] && return 1
    _es_sec="$1"
    _es_next="${2:-}"
    if [ -n "$_es_next" ]; then
        _es_out="$(awk -v sec="$_es_sec" -v nxt="$_es_next" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found && $0 ~ "^### \\[" nxt "\\]" {exit}
            found {print}
        ' "$WORKFLOW_FULL" 2>/dev/null)"
    else
        _es_out="$(awk -v sec="$_es_sec" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found {print}
        ' "$WORKFLOW_FULL" 2>/dev/null)"
    fi
    [ -z "$_es_out" ] && return 1
    printf '%s\n' "$_es_out"
    return 0
}

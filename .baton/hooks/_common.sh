#!/usr/bin/env bash
# _common.sh — shared functions for baton hooks
# Sourced by all hooks: . "$SCRIPT_DIR/_common.sh"

# resolve_plan_name — backward-compatible shim
# Sets PLAN_NAME from BATON_PLAN env when explicitly set.
# When not set, leaves PLAN_NAME empty — find_plan() discovers it during walk-up.
resolve_plan_name() {
    if [ -n "${BATON_PLAN:-}" ]; then
        PLAN_NAME="$BATON_PLAN"
    else
        PLAN_NAME=""
    fi
}

# find_plan — walk up from JSON_CWD/cwd to find plan file, sets PLAN + PLAN_NAME
# Merges name discovery into directory walk-up: at each level, either checks for
# BATON_PLAN (explicit) or globs plan.md/plan-*.md (implicit).
# shellcheck disable=SC2034
find_plan() {
    PLAN=""
    _fp_d="${JSON_CWD:-$(pwd)}"
    if [ -n "${BATON_PLAN:-}" ]; then
        PLAN_NAME="$BATON_PLAN"
        while true; do
            [ -f "$_fp_d/$PLAN_NAME" ] && { PLAN="$_fp_d/$PLAN_NAME"; return; }
            _fp_p="$(dirname "$_fp_d")"
            [ "$_fp_p" = "$_fp_d" ] && return
            _fp_d="$_fp_p"
        done
    else
        while true; do
            _fp_c="$(cd "$_fp_d" 2>/dev/null && ls -t plan.md plan-*.md 2>/dev/null | head -1)"
            if [ -n "$_fp_c" ]; then
                PLAN_NAME="$_fp_c"
                PLAN="$_fp_d/$_fp_c"
                return
            fi
            _fp_p="$(dirname "$_fp_d")"
            [ "$_fp_p" = "$_fp_d" ] && { PLAN_NAME="plan.md"; return; }
            _fp_d="$_fp_p"
        done
    fi
}

# has_skill NAME — check if baton skill exists in .claude/.cursor/.agents
has_skill() {
    _hs_name="$1"
    _hs_d="${JSON_CWD:-$(pwd)}"
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

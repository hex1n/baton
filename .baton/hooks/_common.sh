#!/usr/bin/env bash
# _common.sh — shared functions for baton hooks
# Sourced by all hooks: . "$SCRIPT_DIR/_common.sh"
#
# Sources plan-parser.sh for discovery/parsing primitives.
# Legacy function names (resolve_plan_name, find_plan, has_skill) delegate
# to parser functions for backward compatibility during incremental migration.

# Source parser module
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$_COMMON_DIR/plan-parser.sh" ]; then
    . "$_COMMON_DIR/plan-parser.sh"
else
    echo "⚠️ BATON _common.sh: plan-parser.sh not found, discovery functions unavailable" >&2
fi

# --- Legacy wrappers (delegate to parser) ---

# resolve_plan_name — backward-compatible shim
# No longer needed as a separate call; parser_find_plan handles name resolution.
# Kept for hooks that call resolve_plan_name before find_plan.
resolve_plan_name() {
    if [ -n "${BATON_PLAN:-}" ]; then
        PLAN_NAME="$BATON_PLAN"
    else
        PLAN_NAME=""
    fi
}

# find_plan — delegates to parser_find_plan
# shellcheck disable=SC2034
find_plan() {
    parser_find_plan
}

# has_skill — delegates to parser_has_skill
# Note: parser_has_skill adds .baton/skills to the search path
has_skill() {
    parser_has_skill "$1"
}

#!/usr/bin/env bash
# common.sh — shared functions for baton hooks
# Sourced by all hooks: . "$SCRIPT_DIR/lib/common.sh"
#
# Sources plan-parser.sh for discovery/parsing primitives.
# Legacy function names (resolve_plan_name, find_plan, has_skill) delegate
# to parser functions for backward compatibility during incremental migration.

# Source parser module
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$_COMMON_DIR/plan-parser.sh" ]; then
    . "$_COMMON_DIR/plan-parser.sh"
else
    echo "⚠️ BATON common.sh: plan-parser.sh not found, discovery functions unavailable" >&2
fi

# --- Legacy wrappers (delegate to parser) ---

# resolve_plan_name — backward-compatible shim
# Still called explicitly by write-lock.sh (and any hook that needs PLAN_NAME set
# before calling find_plan). parser_find_plan also performs name resolution internally,
# so new hooks can skip this call — but do not remove it while write-lock.sh depends on it.
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

# --- Test suite configuration ---
# BATON_TEST_CMD: command to run the project's full test suite.
# Set via env, .claude/settings.json env field, or auto-detected here.
baton_resolve_test_cmd() {
    if [ -n "${BATON_TEST_CMD:-}" ]; then
        echo "$BATON_TEST_CMD"
        return
    fi
    local _root="${BATON_PROJECT_DIR:-$(pwd)}"
    if [ -f "$_root/package.json" ] && grep -q '"test"' "$_root/package.json" 2>/dev/null; then
        echo "npm test"
    elif [ -f "$_root/Makefile" ] && grep -q '^test:' "$_root/Makefile" 2>/dev/null; then
        echo "make test"
    elif [ -f "$_root/pytest.ini" ] || [ -f "$_root/setup.cfg" ] || [ -f "$_root/pyproject.toml" ]; then
        echo "pytest"
    elif [ -d "$_root/tests" ] && ls "$_root/tests"/test-*.sh >/dev/null 2>&1; then
        echo "bash tests/run.sh"
    else
        echo ""
    fi
}

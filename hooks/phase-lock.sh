#!/bin/sh
# phase-lock.sh — Block source code writes during locked phases. (v2.1)
# POSIX sh for maximum portability.
#
# v2.1 changes:
# - Slice scope check is now BLOCKING by default (was advisory)
# - Override with BATON_ALLOW_SCOPE_OVERRIDE=true for emergencies
# - Added slice/approved phase blocking (pre-implement phases)
#
# Always allows writes to .baton/ artifacts.
# Uses active-task file for phase detection.
#
# Usage:  sh phase-lock.sh [target_path]
#
# Environment:
#     AI_PHASE                Explicit phase override
#     BATON_TARGET_PATH       File being written (alt to CLI arg)
#     BATON_ROOT              Repo root (optional)
#     BATON_CURRENT_ITEM      Current todo item number (for slice scope check)
#     BATON_ALLOW_SCOPE_OVERRIDE  Set to "true" to bypass scope blocking

resolve_repo_root() {
    if [ -n "${BATON_ROOT:-}" ] && [ -d "${BATON_ROOT}/.baton" ]; then
        echo "$BATON_ROOT"
        return
    fi
    dir="$(pwd)"
    while true; do
        if [ -d "$dir/.baton" ]; then
            if [ -f "$dir/.baton/project-config.json" ] || \
               [ -d "$dir/.baton/tasks" ] || \
               [ -d "$dir/.baton/governance" ]; then
                echo "$dir"
                return
            fi
        fi
        parent="$(dirname "$dir")"
        if [ "$parent" = "$dir" ]; then break; fi
        dir="$parent"
    done
    pwd
}

resolve_phase() {
    if [ -n "${AI_PHASE:-}" ]; then echo "$AI_PHASE"; return; fi
    repo="$1"
    active_file="$repo/.baton/active-task"
    if [ -f "$active_file" ]; then
        phase="$(awk '{print $2}' "$active_file" 2>/dev/null)"
        if [ -n "$phase" ]; then echo "$phase"; return; fi
    fi
    echo ""
}

resolve_task_id() {
    repo="$1"
    active_file="$repo/.baton/active-task"
    if [ -f "$active_file" ]; then
        task_id="$(awk '{print $1}' "$active_file" 2>/dev/null)"
        if [ -n "$task_id" ]; then echo "$task_id"; return; fi
    fi
    echo ""
}

plan_is_approved() { grep -q "STATUS: APPROVED" "$1" 2>/dev/null; }
plan_has_todo() { grep -q "^## Todo" "$1" 2>/dev/null; }

is_artifact_path() {
    target="$1"
    case "$target" in .baton/*|*/.baton/*) return 0 ;; esac
    return 1
}

# v2.1: Slice scope check is now BLOCKING by default
check_slice_scope() {
    plan_file="$1"
    target="$2"
    item_num="${BATON_CURRENT_ITEM:-}"

    if [ -z "$item_num" ]; then return 0; fi
    if ! grep -q "^## Context Slices" "$plan_file" 2>/dev/null; then return 0; fi

    slice_header="#slice-${item_num}"
    if grep -A 50 "$slice_header" "$plan_file" 2>/dev/null | \
       grep -q "Files NOT to modify" 2>/dev/null; then
        if grep -A 50 "$slice_header" "$plan_file" 2>/dev/null | \
           sed -n '/Files NOT to modify/,/^\*\*/p' | \
           grep -q "$target" 2>/dev/null; then
            echo "[phase-lock] ⚠️  SCOPE VIOLATION: '$target' is in 'Files NOT to modify' for slice #${item_num}." >&2
            if [ "${BATON_ALLOW_SCOPE_OVERRIDE:-}" != "true" ]; then
                echo "[phase-lock] Set BATON_ALLOW_SCOPE_OVERRIDE=true to proceed (not recommended)." >&2
                exit 1
            fi
            echo "[phase-lock] Scope override active. Proceeding with warning." >&2
        fi
    fi
    return 0
}

# ── Main ──────────────────────────────────────────────────────────────

REPO_ROOT="$(resolve_repo_root)"

# Layer 0: No .baton/ → no enforcement
if [ ! -d "$REPO_ROOT/.baton" ]; then exit 0; fi

PHASE="$(resolve_phase "$REPO_ROOT")"
TASK_ID="$(resolve_task_id "$REPO_ROOT")"

# Layer 0: No active task → no enforcement
if [ -z "$TASK_ID" ] || [ -z "$PHASE" ]; then exit 0; fi

TARGET="${1:-${BATON_TARGET_PATH:-}}"

# Artifact paths always allowed
if [ -n "$TARGET" ] && is_artifact_path "$TARGET"; then exit 0; fi

# v2.1: expanded locked phases to include slice and approved
case "$PHASE" in
    research|plan|annotation|slice|approved)
        msg="[phase-lock] Blocked during phase='$PHASE'."
        if [ -n "$TARGET" ]; then msg="$msg Target: '$TARGET'."; fi
        msg="$msg Source writes require an approved plan + Todo checklist."
        echo "$msg" >&2
        exit 1
        ;;
esac

# Non-artifact write requires approved plan + generated todo
PLAN_FILE="$REPO_ROOT/.baton/tasks/$TASK_ID/plan.md"
if [ ! -f "$PLAN_FILE" ]; then
    msg="[phase-lock] Blocked: missing plan.md for task '$TASK_ID'."
    if [ -n "$TARGET" ]; then msg="$msg Target: '$TARGET'."; fi
    msg="$msg Write and approve plan.md before source writes."
    echo "$msg" >&2
    exit 1
fi

if ! plan_is_approved "$PLAN_FILE"; then
    msg="[phase-lock] Blocked: plan.md is not APPROVED for task '$TASK_ID'."
    if [ -n "$TARGET" ]; then msg="$msg Target: '$TARGET'."; fi
    msg="$msg Source writes require: <!-- STATUS: APPROVED -->"
    echo "$msg" >&2
    exit 1
fi

if ! plan_has_todo "$PLAN_FILE"; then
    msg="[phase-lock] Blocked: plan.md has no Todo checklist for task '$TASK_ID'."
    if [ -n "$TARGET" ]; then msg="$msg Target: '$TARGET'."; fi
    msg="$msg Generate '## Todo' after approval before source writes."
    echo "$msg" >&2
    exit 1
fi

# v2.1: Blocking slice scope check
if [ -n "$TARGET" ]; then
    check_slice_scope "$PLAN_FILE" "$TARGET"
fi

exit 0

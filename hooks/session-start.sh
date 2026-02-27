#!/usr/bin/env bash
# session-start.sh — Baton SessionStart hook (v2.1)
#
# v2.1 changes:
# - Action-oriented output: when active task exists, emit a single
#   concrete "cat" command instead of a skill mapping table
# - Visual phase-lock indicators
# - Quick-path detection in output
# - Protocol reference
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GLOBAL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

layer="0"
task=""
phase=""

if [ -d ".baton" ]; then
    if [ -f ".baton/project-config.json" ]; then layer="2"; fi
    if [ -f ".baton/active-task" ]; then
        content=$(cat .baton/active-task 2>/dev/null || echo "")
        task=$(echo "$content" | awk '{print $1}')
        phase=$(echo "$content" | awk '{$1=""; print}' | xargs)
        if [ -n "$task" ] && [ -z "$phase" ]; then
            bash "${GLOBAL_ROOT}/bin/baton" active > /dev/null 2>&1 || true
            content=$(cat .baton/active-task 2>/dev/null || echo "")
            task=$(echo "$content" | awk '{print $1}')
            phase=$(echo "$content" | awk '{$1=""; print}' | xargs)
        fi
        if [ -n "$task" ] && [ "$layer" = "0" ]; then layer="1"; fi
    fi
fi

has_checklists=""
has_constraints=""
if [ -f ".baton/review-checklists.md" ]; then has_checklists="yes"; fi
if [ -f ".baton/governance/hard-constraints.md" ]; then has_constraints="yes"; fi

phase_to_skill() {
    case "$1" in
        research*)  echo "plan-first-research" ;;
        plan*)      echo "plan-first-plan" ;;
        annotation*)echo "annotation-cycle" ;;
        approved*)  echo "plan-first-plan" ;;
        slice*)     echo "context-slice" ;;
        implement*) echo "plan-first-implement" ;;
        verify*)    echo "verification-gate" ;;
        review*)    echo "code-reviewer" ;;
        *)          echo "" ;;
    esac
}

if [ -n "$task" ] && [ -n "$phase" ]; then
    skill_for_phase=$(phase_to_skill "$phase")
    task_dir=".baton/tasks/${task}"
    quick_label=""
    if [ -f "${task_dir}/.quick-path" ]; then
        quick_label=" | Mode: quick-path (skip research)"
    fi
    slices_label=""
    if [ -f "${task_dir}/plan.md" ] && grep -q "## Context Slices" "${task_dir}/plan.md" 2>/dev/null; then
        slices_label=" | Slices: available"
    fi
    phase_constraint=""
    case "$phase" in
        research*|plan*|annotation*)
            phase_constraint="  🔒 SOURCE WRITES BLOCKED — only .baton/ artifacts allowed" ;;
        implement*|verify*|review*)
            phase_constraint="  🔓 Source writes allowed (plan must be APPROVED + has Todo)" ;;
        approved*|slice*)
            phase_constraint="  🔒 SOURCE WRITES BLOCKED — generating todo/slices" ;;
        done*|abandoned*)
            phase_constraint="  Task is ${phase}. Start new task or clear: baton active --clear" ;;
    esac
    cat << CONTEXT
<baton-context>
Baton v2.1 | Layer: ${layer} | Task: ${task} | Phase: ${phase}${quick_label}${slices_label}

═══════════════════════════════════════════════════
 REQUIRED ACTION — DO THIS BEFORE ANYTHING ELSE:
 cat ${GLOBAL_ROOT}/skills/${skill_for_phase}/SKILL.md
═══════════════════════════════════════════════════

Phase constraints:
${phase_constraint}

${has_constraints:+Hard constraints active: .baton/governance/hard-constraints.md}
${has_checklists:+Review checklists active: .baton/review-checklists.md}

Protocol reference: ${GLOBAL_ROOT}/workflow-protocol.md
</baton-context>
CONTEXT
else
    cat << CONTEXT
<baton-context>
Baton v2.1 | Layer ${layer} (no active task)

Available standalone skills:
  baton research <scope>    → plan-first-research
  baton plan                → plan-first-plan
  baton annotate <file>     → annotation-cycle
  baton slice <file>        → context-slice
  baton review [--diff]     → code-reviewer

To start a full workflow: baton new-task <id>

IMPORTANT: Load FULL skill file before acting:
  cat ${GLOBAL_ROOT}/skills/<skill-name>/SKILL.md
</baton-context>
CONTEXT
fi

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
source "$bootstrap_dir/lib/task-status.sh"
source "$bootstrap_dir/lib/provenance.sh"
source "$bootstrap_dir/lib/state-requirements.sh"

harness_dir="${1:-.harness}"
task_status="$harness_dir/task-status.md"

state_migrate_legacy_artifacts "$harness_dir"

if [[ ! -f "$task_status" ]]; then
  jq -n '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No active harness task."}}'
  exit 0
fi

state="$(task_status_current_field "$task_status" state)"
owner="$(task_status_current_field "$task_status" owner)"
task_id="$(task_status_current_field "$task_status" scope)"
eval_round="$(task_status_current_field "$task_status" eval_round)"

present="" missing=""
for artifact in $(state_required_artifacts_for_summary "$state"); do
  if [[ -f "$harness_dir/$artifact" ]]; then
    present="${present:+$present, }$artifact"
  else
    missing="${missing:+$missing, }$artifact"
  fi
done

overlay_summary() {
  local exploration_file="$1"
  awk '
    /^## Overlay Recommendation$/ { in_section = 1; next }
    /^## / && in_section { exit }
    in_section && /^overlay:[[:space:]]*(core|strict)[[:space:]]*$/ {
      sub(/^overlay:[[:space:]]*/, "", $0)
      print $0
      exit
    }
  ' "$exploration_file"
}

summary_field() {
  local file="$1"
  shift
  provenance_clean_value "$(provenance_read_field "$file" "$@" || true)"
}

ctx="Harness task active:"
ctx+=$'\n'"  task: ${task_id:-?}  state: ${state:-?}  owner: ${owner:-?}  eval_round: ${eval_round:-0}"
[[ -n "$present" ]] && ctx+=$'\n'"  present: $present"
[[ -n "$missing" ]] && ctx+=$'\n'"  missing: $missing"

exploration="$harness_dir/exploration.md"
if [[ -f "$exploration" ]]; then
  overlay="$(overlay_summary "$exploration" || true)"
  if [[ -n "$overlay" ]]; then
    ctx+=$'\n'"  overlay: $overlay"
  fi
fi

if [[ "$state" == "ready_for_human_close" || "$state" == "complete" ]]; then
  verification_file="$harness_dir/verification.md"
  evaluation_path="$harness_dir/evaluation.md"

  if [[ -f "$verification_file" ]]; then
    verifier_role="$(summary_field "$verification_file" "Role")"
    verifier_mode="$(summary_field "$verification_file" "Isolation mode" "Verification mode")"
    verifier_context="$(summary_field "$verification_file" "Execution context")"
    ctx+=$'\n'"  verifier: role=${verifier_role:-?} mode=${verifier_mode:-?} context=${verifier_context:-?}"
  fi

  if [[ -f "$evaluation_path" ]]; then
    evaluator_role="$(summary_field "$evaluation_path" "Role")"
    evaluator_mode="$(summary_field "$evaluation_path" "Isolation mode" "Review mode")"
    evaluator_context="$(summary_field "$evaluation_path" "Execution context")"
    evaluator_verdict="$(summary_field "$evaluation_path" "Verdict")"
    ctx+=$'\n'"  evaluator: role=${evaluator_role:-?} mode=${evaluator_mode:-?} context=${evaluator_context:-?} verdict=${evaluator_verdict:-?}"
  fi
fi

jq -n --arg ctx "$ctx" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'

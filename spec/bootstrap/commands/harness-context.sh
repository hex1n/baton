#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
source "$bootstrap_dir/lib/module-status.sh"
source "$bootstrap_dir/lib/provenance.sh"
source "$bootstrap_dir/lib/state-requirements.sh"

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"

if [[ ! -f "$module_status" ]]; then
  jq -n '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No active harness task."}}'
  exit 0
fi

state="$(module_status_current_field "$module_status" state)"
owner="$(module_status_current_field "$module_status" owner)"
task_id="$(module_status_current_field "$module_status" scope)"
eval_round="$(module_status_current_field "$module_status" eval_round)"

present="" missing=""
for artifact in $(state_required_artifacts_for_summary "$state"); do
  if [[ -f "$harness_dir/$artifact" ]]; then
    present="${present:+$present, }$artifact"
  else
    missing="${missing:+$missing, }$artifact"
  fi
done

overlay_summary() {
  local scoped_map="$1"
  awk '
    /^## Overlay Recommendation$/ { in_section = 1; next }
    /^## / && in_section { exit }
    in_section && /^overlay:[[:space:]]*(core|strict)[[:space:]]*$/ {
      sub(/^overlay:[[:space:]]*/, "", $0)
      print $0
      exit
    }
  ' "$scoped_map"
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

scoped_map="$harness_dir/scoped-map.md"
if [[ -f "$scoped_map" ]]; then
  overlay="$(overlay_summary "$scoped_map" || true)"
  if [[ -n "$overlay" ]]; then
    ctx+=$'\n'"  overlay: $overlay"
  fi
fi

if [[ "$state" == "ready_for_human_close" || "$state" == "complete" ]]; then
  verification_path="$harness_dir/verification-path.md"
  evaluation_path="$harness_dir/evaluation.md"

  if [[ -f "$verification_path" ]]; then
    verifier_role="$(summary_field "$verification_path" "Role")"
    verifier_mode="$(summary_field "$verification_path" "Isolation mode" "Verification mode")"
    verifier_context="$(summary_field "$verification_path" "Execution context")"
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

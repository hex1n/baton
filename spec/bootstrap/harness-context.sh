#!/usr/bin/env bash
set -euo pipefail

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"

if [[ ! -f "$module_status" ]]; then
  jq -n '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No active harness task."}}'
  exit 0
fi

state=$(awk    -F'|' 'NF>3 && $4!~/---/ && $4!~/^[[:space:]]*State[[:space:]]*$/{gsub(/ /,"",$4); print $4; exit}' "$module_status")
owner=$(awk    -F'|' 'NF>3 && $3!~/---/ && $3!~/^[[:space:]]*Owner[[:space:]]*$/{gsub(/ /,"",$3); print $3; exit}' "$module_status")
task_id=$(awk  -F'|' 'NF>2 && $2!~/---/ && $2!~/^[[:space:]]*Scope[[:space:]]*$/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' "$module_status")
eval_round=$(awk -F'|' 'NF>4 && $5!~/---/ && $5!~/[Ee]val/{gsub(/ /,"",$5); print $5; exit}' "$module_status")

required_for_state() {
  case "$1" in
    specifying)           echo "scoped-map.md" ;;
    architecting)         echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check) echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing|ready_for_human_close|complete) echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    *)                    echo "" ;;
  esac
}

present="" missing=""
for artifact in $(required_for_state "$state"); do
  if [[ -f "$harness_dir/$artifact" ]]; then
    present="${present:+$present, }$artifact"
  else
    missing="${missing:+$missing, }$artifact"
  fi
done

ctx="Harness task active:"
ctx+=$'\n'"  task: ${task_id:-?}  state: ${state:-?}  owner: ${owner:-?}  eval_round: ${eval_round:-0}"
[[ -n "$present" ]] && ctx+=$'\n'"  present: $present"
[[ -n "$missing" ]] && ctx+=$'\n'"  missing: $missing"

jq -n --arg ctx "$ctx" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'

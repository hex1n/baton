#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
source "$bootstrap_dir/lib/task-status.sh"
source "$bootstrap_dir/lib/state-requirements.sh"

harness_dir="${1:-.harness}"
task_status="$harness_dir/task-status.md"

[[ -f "$task_status" ]] || exit 0

state_migrate_legacy_artifacts "$harness_dir"

state="$(task_status_current_field "$task_status" state)"
[[ -n "$state" ]] || exit 0

missing=()
for artifact in $(state_required_artifacts_for_validation "$state"); do
  [[ -f "$harness_dir/$artifact" ]] || missing+=("$harness_dir/$artifact")
done

[[ ${#missing[@]} -eq 0 ]] && exit 0

list=""
for f in "${missing[@]}"; do
  list+="  - $f"$'\n'
done

reason="State is \"$state\" but missing required artifacts:"$'\n'"${list}"$'Write the missing artifacts before finishing this turn.'
jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
exit 2

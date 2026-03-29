#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/module-status.sh"

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"

[[ -f "$module_status" ]] || exit 0

state="$(module_status_current_field "$module_status" state)"
[[ -n "$state" ]] || exit 0

required_for_state() {
  case "$1" in
    specifying)
      echo "scoped-map.md" ;;
    architecting)
      echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing)
      echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    ready_for_human_close)
      echo "scoped-map.md requirements.md architecture.md verification-path.md evaluation.md" ;;
    complete)
      echo "scoped-map.md requirements.md architecture.md verification-path.md evaluation.md retrospective.md" ;;
    *)
      echo "" ;;
  esac
}

missing=()
for artifact in $(required_for_state "$state"); do
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

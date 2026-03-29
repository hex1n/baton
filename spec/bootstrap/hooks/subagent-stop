#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/parse-input.sh"

module_status_path="$HOOK_ROOT/.harness/module-status.md"
verification_path="$HOOK_ROOT/.harness/verification-path.md"
module_status_script="$BOOTSTRAP_DIR/module-status.sh"
validate_artifact_script="$BOOTSTRAP_DIR/validate-artifact.sh"

case "$HOOK_AGENT" in
  baton-verifier|baton-evaluator) ;;
  *) hook_pass ;;
esac

debug_log "subagent-stop agent=$HOOK_AGENT"
source "$module_status_script"

if [[ "$HOOK_AGENT" == "baton-verifier" ]]; then
  [[ -f "$verification_path" ]] || hook_block "baton-verifier completed without writing verification-path.md"
  if ! verifier_output="$(bash "$validate_artifact_script" verification-path "$verification_path" 2>&1)"; then
    hook_block "$verifier_output"
  fi
  hook_pass
fi

current_state="$(module_status_current_field "$module_status_path" state 2>/dev/null || true)"
case "$current_state" in
  blocked|reviewing|ready_for_human_close) ;;
  *)
    hook_block "baton-evaluator completed but module-status state is \"$current_state\""
    ;;
esac

current_round="$(module_status_current_field "$module_status_path" eval_round 2>/dev/null || true)"
if [[ ! "$current_round" =~ ^[0-9]+$ ]]; then
  current_round="0"
fi

max_rounds="$(read_profile_value max_eval_rounds 3 '^[0-9]+$')"
if [[ ! "$max_rounds" =~ ^[0-9]+$ ]] || (( max_rounds <= 0 )); then
  max_rounds="3"
fi

new_round=$((current_round + 1))
debug_log "subagent-stop current_round=$current_round new_round=$new_round max_rounds=$max_rounds"

export BATON_HOOK_ACTIVE=1
module_status_set_eval_round "$module_status_path" "$new_round"

if (( new_round >= max_rounds )); then
  hook_block "Eval round $new_round reached max_eval_rounds ($max_rounds)"
fi

hook_pass

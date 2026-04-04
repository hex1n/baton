#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
source "$bootstrap_dir/lib/task-status.sh"
source "$bootstrap_dir/lib/provenance.sh"
source "$bootstrap_dir/lib/profile.sh"

harness_dir="${1:-.harness}"
task_status="$harness_dir/task-status.md"
profile_local="$harness_dir/profile.local.yaml"
verification_path="$harness_dir/verification.md"
evaluation_path="$harness_dir/evaluation.md"
validate_artifact="$bootstrap_dir/validate-artifact.sh"

[[ -f "$task_status" ]] || exit 0

state="$(task_status_current_field "$task_status" state)"
[[ -n "$state" ]] || exit 0

block() {
  local reason="$1"
  jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
  exit 2
}

is_blank_or_none() {
  local value
  value="$(provenance_normalize_value "${1:-}")"
  [[ -z "$value" || "$value" == "none" || "$value" == "\"none\"" ]]
}

require_context_value() {
  local label="$1" context="$2"
  case "$context" in
    isolated_subagent|fresh_session|session_reset|sequential_fallback) ;;
    *)
      block "$label declares unsupported execution context \"$context\". Expected one of isolated_subagent, fresh_session, session_reset, sequential_fallback."
      ;;
  esac
}

check_verification_isolation() {
  local expected_mode declared_role declared_mode execution_context agent_id evidence fallback_policy fallback_reason
  expected_mode="$(profile_read_mode "$profile_local" verification_isolation_mode strict)"

  [[ -f "$verification_path" ]] || block "State is \"$state\" but verification.md is missing."
  bash "$validate_artifact" verification "$verification_path" >/dev/null 2>&1 \
    || block "verification.md is present but does not satisfy the required schema."

  declared_role="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Role" || true)")"
  declared_mode="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Isolation mode" "Verification mode" || true)")"
  execution_context="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Execution context" || true)")"
  agent_id="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Agent ID" || true)")"
  evidence="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Evidence" || true)")"
  fallback_policy="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Fallback policy" || true)")"
  fallback_reason="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Fallback reason" || true)")"

  [[ "$declared_role" == "verification_explorer" ]] \
    || block "verification.md must declare Role \"verification_explorer\"."
  [[ -n "$declared_mode" ]] || block "verification.md must declare \"Isolation mode\"."
  [[ "$declared_mode" == "$expected_mode" ]] \
    || block "verification.md declares Isolation mode \"$declared_mode\" but profile expects \"$expected_mode\"."

  [[ -n "$execution_context" ]] || block "verification.md must declare \"Execution context\"."
  require_context_value "verification.md" "$execution_context"
  is_blank_or_none "$evidence" && block "verification.md must declare provenance evidence."
  is_blank_or_none "$fallback_policy" && block "verification.md must declare a fallback policy."

  if [[ "$expected_mode" == "strict" && "$execution_context" != "isolated_subagent" ]]; then
    block "verification.md must use Execution context \"isolated_subagent\" while verification isolation mode is strict."
  fi

  if [[ "$execution_context" == "isolated_subagent" ]] && is_blank_or_none "$agent_id"; then
    block "verification.md uses isolated_subagent but does not record Agent ID."
  fi

  if [[ "$expected_mode" == "compat" && "$execution_context" == "sequential_fallback" ]] && is_blank_or_none "$fallback_reason"; then
    block "verification.md uses sequential_fallback in compat mode but does not record a concrete fallback reason."
  fi
}

check_review_isolation() {
  local expected_mode declared_role declared_mode execution_context agent_id evidence fallback_policy fallback_reason verdict
  expected_mode="$(profile_read_mode "$profile_local" review_isolation_mode strict)"

  [[ -f "$evaluation_path" ]] || block "State is \"$state\" but evaluation.md is missing."
  bash "$validate_artifact" evaluation "$evaluation_path" >/dev/null 2>&1 \
    || block "evaluation.md is present but does not satisfy the required schema."

  declared_role="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Role" || true)")"
  declared_mode="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Isolation mode" "Review mode" || true)")"
  execution_context="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Execution context" || true)")"
  agent_id="$(provenance_clean_value "$(provenance_read_field "$evaluation_path" "Agent ID" || true)")"
  evidence="$(provenance_clean_value "$(provenance_read_field "$evaluation_path" "Evidence" || true)")"
  fallback_policy="$(provenance_clean_value "$(provenance_read_field "$evaluation_path" "Fallback policy" || true)")"
  fallback_reason="$(provenance_clean_value "$(provenance_read_field "$evaluation_path" "Fallback reason" || true)")"
  verdict="$(provenance_clean_value "$(provenance_read_field "$evaluation_path" "Verdict" || true)")"

  [[ "$declared_role" == "evaluator" ]] \
    || block "evaluation.md must declare Role \"evaluator\"."
  [[ -n "$declared_mode" ]] || block "evaluation.md must declare \"Isolation mode\"."
  [[ "$declared_mode" == "$expected_mode" ]] \
    || block "evaluation.md declares Isolation mode \"$declared_mode\" but profile expects \"$expected_mode\"."

  [[ -n "$execution_context" ]] || block "evaluation.md must declare \"Execution context\"."
  require_context_value "evaluation.md" "$execution_context"
  is_blank_or_none "$evidence" && block "evaluation.md must declare provenance evidence."
  is_blank_or_none "$fallback_policy" && block "evaluation.md must declare a fallback policy."

  if [[ "$expected_mode" == "strict" && "$execution_context" != "isolated_subagent" ]]; then
    block "evaluation.md must use Execution context \"isolated_subagent\" while review isolation mode is strict."
  fi

  if [[ "$execution_context" == "isolated_subagent" ]] && is_blank_or_none "$agent_id"; then
    block "evaluation.md uses isolated_subagent but does not record Agent ID."
  fi

  if [[ "$expected_mode" == "compat" && "$execution_context" == "sequential_fallback" ]] && is_blank_or_none "$fallback_reason"; then
    block "evaluation.md uses sequential_fallback in compat mode but does not record a concrete fallback reason."
  fi

  if is_blank_or_none "$verdict"; then
    block "evaluation.md must record a final verdict before human close."
  fi
}

case "$state" in
  verification_check|generating|reviewing|ready_for_human_close|complete)
    check_verification_isolation
    ;;
esac

case "$state" in
  ready_for_human_close|complete)
    check_review_isolation
    ;;
esac

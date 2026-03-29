#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/module-status.sh"
source "$script_dir/provenance.sh"

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"
profile_local="$harness_dir/profile.local.yaml"
verification_path="$harness_dir/verification-path.md"
evaluation_path="$harness_dir/evaluation.md"
validate_artifact="$script_dir/validate-artifact.sh"

[[ -f "$module_status" ]] || exit 0

state="$(module_status_current_field "$module_status" state)"
[[ -n "$state" ]] || exit 0

block() {
  local reason="$1"
  jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
  exit 2
}

read_profile_mode() {
  local key="$1" default_value="$2"
  local line value
  [[ -f "$profile_local" ]] || {
    printf '%s\n' "$default_value"
    return 0
  }
  line="$(grep -E "^[[:space:]]*${key}:[[:space:]]*(strict|compat)[[:space:]]*$" "$profile_local" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi
  value="${line##*:}"
  value="$(printf '%s' "$value" | tr -d '[:space:]')"
  case "$value" in
    strict|compat) printf '%s\n' "$value" ;;
    *) printf '%s\n' "$default_value" ;;
  esac
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
  local expected_mode declared_role declared_mode execution_context evidence fallback_policy fallback_reason
  expected_mode="$(read_profile_mode verification_isolation_mode strict)"

  [[ -f "$verification_path" ]] || block "State is \"$state\" but verification-path.md is missing."
  bash "$validate_artifact" verification-path "$verification_path" >/dev/null 2>&1 \
    || block "verification-path.md is present but does not satisfy the required schema."

  declared_role="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Role" || true)")"
  declared_mode="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Isolation mode" "Verification mode" || true)")"
  execution_context="$(provenance_normalize_value "$(provenance_read_field "$verification_path" "Execution context" || true)")"
  evidence="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Evidence" || true)")"
  fallback_policy="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Fallback policy" || true)")"
  fallback_reason="$(provenance_clean_value "$(provenance_read_field "$verification_path" "Fallback reason" || true)")"

  [[ "$declared_role" == "verification_explorer" ]] \
    || block "verification-path.md must declare Role \"verification_explorer\"."
  [[ -n "$declared_mode" ]] || block "verification-path.md must declare \"Isolation mode\"."
  [[ "$declared_mode" == "$expected_mode" ]] \
    || block "verification-path.md declares Isolation mode \"$declared_mode\" but profile expects \"$expected_mode\"."

  [[ -n "$execution_context" ]] || block "verification-path.md must declare \"Execution context\"."
  require_context_value "verification-path.md" "$execution_context"
  is_blank_or_none "$evidence" && block "verification-path.md must declare provenance evidence."
  is_blank_or_none "$fallback_policy" && block "verification-path.md must declare a fallback policy."

  if [[ "$expected_mode" == "strict" && "$execution_context" == "sequential_fallback" ]]; then
    block "verification-path.md records sequential_fallback while verification isolation mode is strict."
  fi

  if [[ "$expected_mode" == "compat" && "$execution_context" == "sequential_fallback" ]] && is_blank_or_none "$fallback_reason"; then
    block "verification-path.md uses sequential_fallback in compat mode but does not record a concrete fallback reason."
  fi
}

check_review_isolation() {
  local expected_mode declared_role declared_mode execution_context evidence fallback_policy fallback_reason verdict
  expected_mode="$(read_profile_mode review_isolation_mode strict)"

  [[ -f "$evaluation_path" ]] || block "State is \"$state\" but evaluation.md is missing."
  bash "$validate_artifact" evaluation "$evaluation_path" >/dev/null 2>&1 \
    || block "evaluation.md is present but does not satisfy the required schema."

  declared_role="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Role" || true)")"
  declared_mode="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Isolation mode" "Review mode" || true)")"
  execution_context="$(provenance_normalize_value "$(provenance_read_field "$evaluation_path" "Execution context" || true)")"
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

  if [[ "$expected_mode" == "strict" && "$execution_context" == "sequential_fallback" ]]; then
    block "evaluation.md records sequential_fallback while review isolation mode is strict."
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

#!/usr/bin/env bash
set -euo pipefail

profile_read_scalar() {
  local profile_path="$1"
  local key="$2"
  local regex="${3:-}"
  local line=""
  local value=""

  if [[ ! -f "$profile_path" ]]; then
    return 1
  fi

  line="$(grep -E "^[[:space:]]*${key}:[[:space:]]*" "$profile_path" | head -n 1 || true)"
  [[ -n "$line" ]] || return 1

  value="${line#*:}"
  value="$(printf '%s' "$value" | sed "s/[[:space:]]*#.*$//")"
  value="$(printf '%s' "$value" | sed "s/^[[:space:]\"']*//;s/[[:space:]\"']*$//")"

  if [[ -n "$regex" ]] && ! printf '%s\n' "$value" | grep -Eq "$regex"; then
    return 1
  fi

  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}

profile_read_artifact_language() {
  local profile_path="$1"
  profile_read_scalar "$profile_path" "artifact_language" || true
}

profile_read_mode() {
  local profile_path="$1"
  local key="$2"
  local default_value="$3"
  local value=""

  value="$(profile_read_scalar "$profile_path" "$key" '^(strict|compat)$' || true)"
  if [[ -z "$value" ]]; then
    printf '%s\n' "$default_value"
    return
  fi

  printf '%s\n' "$value"
}

#!/usr/bin/env bash
set -euo pipefail

if [[ "${BATON_HOOK_ACTIVE:-}" == "1" ]]; then
  exit 0
fi

hook_trim() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

debug_log() {
  if [[ "${BATON_DEBUG:-0}" == "1" ]]; then
    printf 'baton-hook: %s\n' "$*" >&2
  fi
}

hook_pass() {
  debug_log "pass"
  exit 0
}

hook_block() {
  local reason="${1:-blocked by baton hook}"
  debug_log "block: $reason"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
  else
    printf '%s\n' "$reason" >&2
  fi
  exit 2
}

HOOK_INPUT="$(cat)"
HOOK_FILE_PATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
HOOK_CONTENT="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null || true)"
HOOK_COMMAND="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
HOOK_AGENT="$(printf '%s' "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"

if [[ -n "$HOOK_FILE_PATH" ]]; then
  HOOK_HOST="cc"
elif [[ -n "$HOOK_COMMAND" ]]; then
  HOOK_HOST="codex"
elif [[ -n "$HOOK_AGENT" ]]; then
  HOOK_HOST="cc"
else
  HOOK_HOST="unknown"
fi

HOOK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$HOOK_ROOT" ]]; then
  HOOK_ROOT="$(pwd)"
fi

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_bootstrap_dir="$(cd "$lib_dir/../.." && pwd)"
BOOTSTRAP_DIR="${BATON_BOOTSTRAP:-$default_bootstrap_dir}"
PROFILE_LOCAL_PATH="$HOOK_ROOT/.harness/profile.local.yaml"

export HOOK_INPUT
export HOOK_HOST
export HOOK_ROOT
export BOOTSTRAP_DIR
export HOOK_FILE_PATH
export HOOK_CONTENT
export HOOK_COMMAND
export HOOK_AGENT
export PROFILE_LOCAL_PATH

read_profile_value() {
  local key="$1"
  local default_value="$2"
  local regex="${3:-}"
  local line=""
  local value=""

  if [[ ! -f "$PROFILE_LOCAL_PATH" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  line="$(grep -E "^[[:space:]]*${key}:[[:space:]]*" "$PROFILE_LOCAL_PATH" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  value="${line#*:}"
  value="$(printf '%s' "$value" | sed "s/[[:space:]]*#.*$//")"
  value="$(hook_trim "$value")"
  value="$(printf '%s' "$value" | sed "s/^[\"']*//;s/[\"']*$//")"

  if [[ -n "$regex" ]] && ! printf '%s\n' "$value" | grep -Eq "$regex"; then
    printf '%s\n' "$default_value"
    return 0
  fi

  if [[ -z "$value" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  printf '%s\n' "$value"
}

hook_repo_cache_key() {
  printf '%s' "$HOOK_ROOT" | cksum | awk '{print $1}'
}

hook_transition_cache_path() {
  printf '/tmp/baton-transition-%s\n' "$(hook_repo_cache_key)"
}

debug_log "host=$HOOK_HOST root=$HOOK_ROOT file=${HOOK_FILE_PATH:-none} agent=${HOOK_AGENT:-none}"

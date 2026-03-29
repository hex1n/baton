#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/parse-input.sh"

module_status_path="$HOOK_ROOT/.harness/module-status.md"
module_status_script="$BOOTSTRAP_DIR/module-status.sh"
validate_transition_script="$BOOTSTRAP_DIR/validate-transition.sh"
states_file="$BOOTSTRAP_DIR/../protocol/states.txt"
blocked_notes_regex='^\[(verification|scope|environment|design)_blocker\]'

has_human_ack() {
  local file_path="$1"
  awk '
    /^## State Notes$/ { in_notes = 1; next }
    /^## / && in_notes { in_notes = 0 }
    in_notes && /^[[:space:]]*-[[:space:]]*human_ack:[[:space:]]*true[[:space:]]*$/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$file_path"
}

state_regex() {
  grep -v '^[[:space:]]*$' "$states_file" | paste -sd'|' -
}

extract_codex_state() {
  local regex=""
  regex="$(state_regex)"
  printf '%s\n' "$HOOK_COMMAND" \
    | grep -oE "\\| *(${regex}) *\\|" \
    | tail -n 1 \
    | tr -d '| ' \
    || true
}

if [[ "$HOOK_HOST" == "cc" ]]; then
  if [[ "$HOOK_FILE_PATH" != *"module-status.md" || -z "$HOOK_CONTENT" ]]; then
    hook_pass
  fi
elif [[ "$HOOK_HOST" == "codex" ]]; then
  if [[ "$HOOK_COMMAND" != *".harness/module-status.md"* ]]; then
    hook_pass
  fi
else
  hook_pass
fi

if [[ ! -f "$module_status_path" ]]; then
  hook_pass
fi

current_state="$(bash "$module_status_script" current-field "$module_status_path" state 2>/dev/null || true)"
[[ -n "$current_state" ]] || hook_pass

new_state=""
new_notes=""
temp_file=""

if [[ "$HOOK_HOST" == "cc" ]]; then
  temp_file="$(mktemp)"
  trap 'rm -f "$temp_file"' EXIT
  printf '%s' "$HOOK_CONTENT" > "$temp_file"
  new_state="$(bash "$module_status_script" current-field "$temp_file" state 2>/dev/null || true)"
  new_notes="$(bash "$module_status_script" current-field "$temp_file" notes 2>/dev/null || true)"
else
  new_state="$(extract_codex_state)"
fi

[[ -n "$new_state" ]] || hook_pass

debug_log "pre-transition current_state=$current_state new_state=$new_state"

if ! transition_output="$(bash "$validate_transition_script" "$current_state" "$new_state" 2>&1)"; then
  hook_block "$transition_output"
fi

if [[ "$current_state" == "awaiting_human_arch" || "$current_state" == "ready_for_human_close" ]]; then
  if [[ "$new_state" != "blocked" ]] && ! has_human_ack "$module_status_path"; then
    hook_block "Human approval required before leaving $current_state. Add '- human_ack: true' under ## State Notes."
  fi
fi

if [[ "$HOOK_HOST" == "cc" && "$new_state" == "blocked" ]]; then
  new_notes="$(hook_trim "$new_notes")"
  if [[ -z "$new_notes" ]]; then
    hook_block "Blocked state requires a categorized Notes value with prefix [verification_blocker], [scope_blocker], [environment_blocker], or [design_blocker]."
  fi

  if ! printf '%s\n' "$new_notes" | grep -Eq "$blocked_notes_regex"; then
    hook_block "Blocked state Notes must start with [verification_blocker], [scope_blocker], [environment_blocker], or [design_blocker]."
  fi
fi

cache_path="$(hook_transition_cache_path)"
printf 'from_state=%s\nto_state=%s\n' "$current_state" "$new_state" > "$cache_path"
debug_log "cached transition $current_state -> $new_state at $cache_path"

hook_pass

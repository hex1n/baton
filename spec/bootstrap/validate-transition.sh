#!/usr/bin/env bash
# validate-transition.sh — check that a state transition is legal per state-machine.md
#
# Usage: validate-transition.sh <from_state> <to_state>
#
# Reads allowed transitions from spec/protocol/state-machine.md.
# Exit 0: transition is legal (or same-state no-op)
# Exit 1: transition is illegal or state is unknown
set -euo pipefail

from_state="${1:-}"
to_state="${2:-}"

if [[ -z "$from_state" || -z "$to_state" ]]; then
  printf 'Usage: validate-transition.sh <from_state> <to_state>\n' >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state_machine="$script_dir/../protocol/state-machine.md"
states_file="$script_dir/../protocol/states.txt"

if [[ ! -f "$state_machine" ]]; then
  printf 'ERROR: validate-transition: state-machine.md not found at %s\n' "$state_machine" >&2
  exit 1
fi

if [[ ! -f "$states_file" ]]; then
  printf 'ERROR: validate-transition: states.txt not found at %s\n' "$states_file" >&2
  exit 1
fi

# Same-state is always a no-op — legal.
if [[ "$from_state" == "$to_state" ]]; then
  exit 0
fi

# Validate that both states are known canonical states.
if ! grep -Fxq "$from_state" "$states_file"; then
  printf 'ERROR: validate-transition: unknown from_state "%s"\n' "$from_state" >&2
  exit 1
fi
if ! grep -Fxq "$to_state" "$states_file"; then
  printf 'ERROR: validate-transition: unknown to_state "%s"\n' "$to_state" >&2
  exit 1
fi

# "any -> blocked" is a wildcard: always legal.
if [[ "$to_state" == "blocked" ]]; then
  exit 0
fi

# Extract allowed transitions from state-machine.md.
# Lines in the "## Allowed Transitions" section that match "state -> state".
allowed="$(sed -n '/## Allowed Transitions/,/^## /p' "$state_machine" \
  | grep -E '^[a-z_]+ -> [a-z_]+$')"

if echo "$allowed" | grep -qE "^${from_state} -> ${to_state}$"; then
  exit 0
fi

printf 'ERROR: validate-transition: illegal transition "%s" -> "%s"\n' "$from_state" "$to_state" >&2
printf 'Allowed from "%s":\n' "$from_state" >&2
echo "$allowed" | grep -E "^${from_state} -> " >&2 || printf '  (none)\n' >&2
exit 1

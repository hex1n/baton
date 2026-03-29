#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/parse-input.sh"

harness_dir="$HOOK_ROOT/.harness"
module_status_path="$harness_dir/module-status.md"

if [[ ! -f "$module_status_path" ]]; then
  hook_pass
fi

debug_log "running stop checks for $harness_dir"
bash "$BOOTSTRAP_DIR/validate-state-artifacts.sh" "$harness_dir" || exit $?
bash "$BOOTSTRAP_DIR/validate-isolation.sh" "$harness_dir" || exit $?

hook_pass

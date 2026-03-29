#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/parse-input.sh"

debug_log "session-start for $HOOK_ROOT/.harness"
bash "$BOOTSTRAP_DIR/harness-context.sh" "$HOOK_ROOT/.harness"

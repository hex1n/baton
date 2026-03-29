#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
handler="${1:-}"

case "$handler" in
  post-artifact|pre-transition|session-start|stop-check|subagent-stop)
    ;;
  "")
    printf 'ERROR: run-hook.sh: missing handler name\n' >&2
    exit 1
    ;;
  *)
    printf 'ERROR: run-hook.sh: unsupported handler: %s\n' "$handler" >&2
    exit 1
    ;;
esac

shift || true
export BATON_BOOTSTRAP="${BATON_BOOTSTRAP:-$bootstrap_dir}"
exec bash "$script_dir/$handler" "$@"

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"

repo_root="."
target_bootstrap_dir="$bootstrap_dir"
dry_run=false

usage() {
  cat <<'EOF'
Usage:
  prepare-review.sh [--repo-root PATH] [--bootstrap-dir PATH] [--dry-run]
EOF
}

extract_session_command() {
  local repo="$1"
  local codex_hooks="$repo/.codex/hooks.json"
  local claude_settings="$repo/.claude/settings.json"
  local command=""

  if [[ -f "$codex_hooks" ]]; then
    command="$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command | select(test("baton-harness-context"))][0] // empty' "$codex_hooks")"
  fi

  if [[ -z "$command" && -f "$claude_settings" ]]; then
    command="$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command | select(test("baton-harness-context"))][0] // empty' "$claude_settings")"
  fi

  printf '%s' "$command"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --bootstrap-dir)
      target_bootstrap_dir="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: prepare-review: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

resolved_repo_root="$(cd "$repo_root" && pwd)"
resolved_bootstrap_dir="$(cd "$target_bootstrap_dir" && pwd)"

if [[ "$dry_run" == true ]]; then
  bash "$resolved_bootstrap_dir/install-hooks.sh" \
    --repo-root "$resolved_repo_root" \
    --bootstrap-dir "$resolved_bootstrap_dir" \
    --dry-run
  printf 'prepare-review: would run %s/check-consistency.sh\n' "$resolved_bootstrap_dir"
  printf 'prepare-review: would execute generated SessionStart hook command from local config\n'
else
  bash "$resolved_bootstrap_dir/install-hooks.sh" \
    --repo-root "$resolved_repo_root" \
    --bootstrap-dir "$resolved_bootstrap_dir"

  bash "$resolved_bootstrap_dir/check-consistency.sh"

  session_cmd="$(extract_session_command "$resolved_repo_root")"
  if [[ -z "$session_cmd" ]]; then
    printf 'ERROR: prepare-review: could not find a Baton SessionStart hook command in local config\n' >&2
    exit 1
  fi

  printf 'prepare-review: executing SessionStart smoke check from generated config\n'
  (
    cd "$resolved_repo_root"
    eval "$session_cmd"
  )
fi

cat <<'EOF'
prepare-review: next isolated review steps
1. Spawn verifier with fork_context: false and include "Agent ID: <spawned-agent-id>" in the prompt.
2. Spawn evaluator with fork_context: false and include "Agent ID: <spawned-agent-id>" in the prompt.
3. Write both agent ids into verification-path.md and evaluation.md before moving to ready_for_human_close.
EOF

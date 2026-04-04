#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
spec_root="$(cd "$bootstrap_dir/.." && pwd)"
default_repo_root="$(cd "$spec_root/.." && pwd)"

repo_root="$default_repo_root"
mode="sync"
force="false"
dry_run="false"
template_path="$spec_root/templates/root-governance.template.md"

usage() {
  cat <<'EOF'
Usage:
  sync-entrypoints.sh [--repo-root PATH] [--mode sync|check] [--force] [--dry-run]

Synchronize the shared governance template into root-level host entrypoints:
  - CLAUDE.md
  - AGENTS.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --force)
      force="true"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$mode" in
  sync|check) ;;
  *)
    printf 'Unsupported mode: %s\n' "$mode" >&2
    exit 1
    ;;
esac

if [[ ! -f "$template_path" ]]; then
  printf 'Template not found: %s\n' "$template_path" >&2
  exit 1
fi

resolved_repo_root="$(cd "$repo_root" && pwd)"
targets=(
  "$resolved_repo_root/CLAUDE.md"
  "$resolved_repo_root/AGENTS.md"
)

errors=0

check_target() {
  local target="$1"
  local label
  label="$(basename "$target")"

  if [[ ! -f "$target" ]]; then
    printf 'ERROR: governance entrypoint missing: %s\n' "$target"
    errors=$((errors + 1))
    return
  fi

  if cmp -s "$template_path" "$target"; then
    printf 'OK: governance entrypoint synced: %s\n' "$label"
  else
    printf 'ERROR: governance entrypoint drifted from template: %s\n' "$label"
    errors=$((errors + 1))
  fi
}

sync_target() {
  local target="$1"

  if [[ -f "$target" ]] && cmp -s "$template_path" "$target"; then
    printf 'skip  %s\n' "$target"
    return
  fi

  if [[ -f "$target" && "$force" != "true" ]]; then
    printf 'skip  %s (differs; pass --force to overwrite)\n' "$target"
    return
  fi

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target"
    return
  fi

  cp "$template_path" "$target"
  printf 'write %s\n' "$target"
}

if [[ "$mode" == "check" ]]; then
  for target in "${targets[@]}"; do
    check_target "$target"
  done

  if [[ $errors -eq 0 ]]; then
    printf 'governance entrypoints OK\n'
    exit 0
  fi

  printf '%d error(s) found\n' "$errors"
  exit 1
fi

for target in "${targets[@]}"; do
  sync_target "$target"
done

printf 'governance entrypoint sync complete\n'

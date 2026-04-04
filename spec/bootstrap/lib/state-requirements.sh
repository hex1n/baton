#!/usr/bin/env bash
set -euo pipefail

# Migrate legacy artifact filenames from previous harness versions.
# Called once per validation entry point so in-flight tasks survive upgrades.
state_migrate_legacy_artifacts() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  [[ -f "$dir/scoped-map.md" && ! -f "$dir/exploration.md" ]] \
    && mv "$dir/scoped-map.md" "$dir/exploration.md"
  [[ -f "$dir/verification-path.md" && ! -f "$dir/verification.md" ]] \
    && mv "$dir/verification-path.md" "$dir/verification.md"
  return 0
}

state_required_artifacts_for_validation() {
  case "$1" in
    specifying)
      echo "exploration.md" ;;
    architecting)
      echo "exploration.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "exploration.md requirements.md architecture.md" ;;
    generating|reviewing)
      echo "exploration.md requirements.md architecture.md verification.md" ;;
    ready_for_human_close)
      echo "exploration.md requirements.md architecture.md verification.md evaluation.md" ;;
    complete)
      echo "exploration.md requirements.md architecture.md verification.md evaluation.md" ;;
    *)
      echo "" ;;
  esac
}

state_required_artifacts_for_summary() {
  case "$1" in
    specifying)
      echo "exploration.md" ;;
    architecting)
      echo "exploration.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "exploration.md requirements.md architecture.md" ;;
    generating|reviewing)
      echo "exploration.md requirements.md architecture.md verification.md" ;;
    ready_for_human_close|complete)
      echo "exploration.md requirements.md architecture.md verification.md evaluation.md" ;;
    *)
      echo "" ;;
  esac
}

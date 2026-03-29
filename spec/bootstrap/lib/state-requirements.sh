#!/usr/bin/env bash
set -euo pipefail

state_required_artifacts_for_validation() {
  case "$1" in
    specifying)
      echo "scoped-map.md" ;;
    architecting)
      echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing)
      echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    ready_for_human_close)
      echo "scoped-map.md requirements.md architecture.md verification-path.md evaluation.md" ;;
    complete)
      echo "scoped-map.md requirements.md architecture.md verification-path.md evaluation.md retrospective.md" ;;
    *)
      echo "" ;;
  esac
}

state_required_artifacts_for_summary() {
  case "$1" in
    specifying)
      echo "scoped-map.md" ;;
    architecting)
      echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing)
      echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    ready_for_human_close|complete)
      echo "scoped-map.md requirements.md architecture.md verification-path.md evaluation.md" ;;
    *)
      echo "" ;;
  esac
}

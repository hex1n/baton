#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo "  Round contract lint"

if bash "$REPO_ROOT/v2/tools/validate-round-contract.sh" --repo-root "$REPO_ROOT"; then
  echo "  ✅ validate-round-contract.sh"
  exit 0
else
  echo "  ❌ validate-round-contract.sh"
  exit 1
fi

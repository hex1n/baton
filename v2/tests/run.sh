#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

TEST_DIR="$REPO_ROOT/v2/tests/contracts"

if [[ ! -d "$TEST_DIR" ]]; then
  echo "Contract tests not found: $TEST_DIR" >&2
  exit 1
fi

PASS=0
FAIL=0

echo "Baton v2 Contract Tests"
echo "======================="

for test_file in "$TEST_DIR"/*.sh; do
  [[ -f "$test_file" ]] || continue
  echo ""
  echo "→ $(basename "$test_file")"
  if bash "$test_file" --repo-root "$REPO_ROOT"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "======================="
echo "Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

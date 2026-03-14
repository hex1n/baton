#!/bin/bash
# test-smoke.sh - Fast local regression subset
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

run_test() {
    local test_name="$1"
    echo ""
    echo "=== Smoke: $test_name ==="
    if bash "$SCRIPT_DIR/$test_name"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
}

TESTS=(
    "test-plan-parser.sh"
    "test-write-lock.sh"
    "test-bash-guard.sh"
    "test-stop-guard.sh"
    "test-phase-guide.sh"
    "test-new-hooks.sh"
    "test-adapters.sh"
    "test-annotation-protocol.sh"
    "test-workflow-consistency.sh"
    "test-ide-capability-consistency.sh"
)

for test_name in "${TESTS[@]}"; do
    run_test "$test_name"
done

echo ""
echo "Smoke summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

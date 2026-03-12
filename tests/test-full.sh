#!/bin/bash
# test-full.sh - Broad regression suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

run_test() {
    local test_name="$1"
    echo ""
    echo "=== Full: $test_name ==="
    if [ "$test_name" = "test-write-lock.sh" ]; then
        if BATON_RUN_BENCH=1 bash "$SCRIPT_DIR/$test_name"; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1))
        fi
        return
    fi

    if bash "$SCRIPT_DIR/$test_name"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
}

TESTS=(
    "test-write-lock.sh"
    "test-stop-guard.sh"
    "test-phase-guide.sh"
    "test-new-hooks.sh"
    "test-adapters.sh"
    "test-annotation-protocol.sh"
    "test-workflow-consistency.sh"
    "test-ide-capability-consistency.sh"
    "test-setup.sh"
    "test-multi-ide.sh"
    "test-cli.sh"
)

for test_name in "${TESTS[@]}"; do
    run_test "$test_name"
done

echo ""
echo "Full summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

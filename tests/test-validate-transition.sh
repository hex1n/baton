#!/usr/bin/env bash
# Tests for validate-transition.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../spec/bootstrap/validate-transition.sh"
PASS=0; FAIL=0; TOTAL=0

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Legal transitions
assert_exit "exploring -> specifying is legal"       0 bash "$VALIDATE" "exploring"           "specifying"
assert_exit "specifying -> architecting is legal"    0 bash "$VALIDATE" "specifying"          "architecting"
assert_exit "generating -> reviewing is legal"       0 bash "$VALIDATE" "generating"          "reviewing"
assert_exit "any -> blocked is legal (wildcard)"     0 bash "$VALIDATE" "generating"          "blocked"
assert_exit "reviewing -> blocked is legal"          0 bash "$VALIDATE" "reviewing"           "blocked"
assert_exit "blocked -> architecting is legal"       0 bash "$VALIDATE" "blocked"             "architecting"

# Illegal transitions
assert_exit "exploring -> generating is illegal"     1 bash "$VALIDATE" "exploring"           "generating"
assert_exit "complete -> generating is illegal"      1 bash "$VALIDATE" "complete"            "generating"
assert_exit "specifying -> reviewing is illegal"     1 bash "$VALIDATE" "specifying"          "reviewing"

# Same-state is always legal
assert_exit "same state is legal"                    0 bash "$VALIDATE" "generating"          "generating"

# Unknown states -> illegal
assert_exit "unknown from_state -> illegal"          1 bash "$VALIDATE" "nonexistent_state"   "specifying"
assert_exit "unknown to_state -> illegal"            1 bash "$VALIDATE" "exploring"           "nonexistent_state"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

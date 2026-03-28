#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/validate-state-artifacts.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_exit() {
  local label="$1" expected="$2"; shift 2
  TOTAL=$((TOTAL+1))
  local actual=0; "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then echo "  pass: $label"; PASS=$((PASS+1))
  else echo "  FAIL: $label — expected exit $expected got $actual"; FAIL=$((FAIL+1)); fi
}

assert_json_block() {
  local label="$1" harness="$2"
  TOTAL=$((TOTAL+1))
  local out; out=$(bash "$SCRIPT" "$harness" 2>/dev/null || true)
  if echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    echo "  pass: $label"; PASS=$((PASS+1))
  else
    echo "  FAIL: $label — output is not valid JSON block: $out"; FAIL=$((FAIL+1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/module-status.md" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task1 | generator | $state | 0 | 2026-03-28 | - |
EOF
}

# no module-status.md → exit 0
assert_exit "no module-status → pass" 0 bash "$SCRIPT" "$tmp/empty"

# state=exploring → no artifacts required → exit 0
make_status "$tmp/t1" "exploring"
assert_exit "exploring → no artifacts required" 0 bash "$SCRIPT" "$tmp/t1"

# state=blocked → no artifact check → exit 0
make_status "$tmp/t2" "blocked"
assert_exit "blocked → no artifact check" 0 bash "$SCRIPT" "$tmp/t2"

# state=specifying, scoped-map.md present → exit 0
make_status "$tmp/t3" "specifying"
touch "$tmp/t3/scoped-map.md"
assert_exit "specifying + scoped-map present → pass" 0 bash "$SCRIPT" "$tmp/t3"

# state=specifying, scoped-map.md missing → exit 2
make_status "$tmp/t4" "specifying"
assert_exit "specifying + scoped-map missing → block" 2 bash "$SCRIPT" "$tmp/t4"

# state=generating, all artifacts present → exit 0
make_status "$tmp/t5" "generating"
touch "$tmp/t5/scoped-map.md" "$tmp/t5/requirements.md" "$tmp/t5/architecture.md" "$tmp/t5/verification-path.md"
assert_exit "generating + all artifacts → pass" 0 bash "$SCRIPT" "$tmp/t5"

# state=generating, verification-path.md missing → exit 2
make_status "$tmp/t6" "generating"
touch "$tmp/t6/scoped-map.md" "$tmp/t6/requirements.md" "$tmp/t6/architecture.md"
assert_exit "generating + verification-path missing → block" 2 bash "$SCRIPT" "$tmp/t6"

# exit 2 output is valid JSON with decision:block
assert_json_block "block output is JSON with decision:block" "$tmp/t6"

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

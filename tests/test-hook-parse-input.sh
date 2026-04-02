#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../spec/bootstrap/hooks/lib/parse-input.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_output() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=""
  actual="$("$@" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$expected' got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

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

run_sourced() {
  local repo="$1" payload="$2" snippet="$3"
  PAYLOAD="$payload" HOOK_SCRIPT="$HOOK_SCRIPT" bash -c '
    cd "$1"
    source "$HOOK_SCRIPT" <<<"$PAYLOAD"
    eval "$2"
  ' bash "$repo" "$snippet"
}

make_repo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  git -C "$dir" init -q
}

repo="$tmp/repo"
make_repo "$repo"

cc_payload='{"tool_input":{"file_path":".harness/task-status.md","content":"# Task Status\n"}}'
assert_output "cc host detection" $'cc\n.harness/task-status.md' \
  run_sourced "$repo" "$cc_payload" 'printf "%s\n%s\n" "$HOOK_HOST" "$HOOK_FILE_PATH"'

codex_payload='{"tool_input":{"command":"echo update .harness/task-status.md"}}'
assert_output "codex host detection" $'codex\necho update .harness/task-status.md' \
  run_sourced "$repo" "$codex_payload" 'printf "%s\n%s\n" "$HOOK_HOST" "$HOOK_COMMAND"'

unknown_payload='{}'
assert_output "unknown host detection" "unknown" \
  run_sourced "$repo" "$unknown_payload" 'printf "%s\n" "$HOOK_HOST"'

assert_exit "hook_pass exits 0" 0 \
  run_sourced "$repo" "$unknown_payload" 'hook_pass'

assert_exit "hook_block exits 2" 2 \
  run_sourced "$repo" "$unknown_payload" 'hook_block "blocked for test"'

repo2="$tmp/repo2"
make_repo "$repo2"
cat > "$repo2/.harness/profile.local.yaml" <<'EOF'
execution:
  max_eval_rounds: 5
  verification_isolation_mode: strict
EOF

profile_payload='{}'
assert_output "read_profile_value returns configured value" "5" \
  run_sourced "$repo2" "$profile_payload" 'read_profile_value max_eval_rounds 3 "^[0-9]+$"'

cat > "$repo2/.harness/profile.local.yaml" <<'EOF'
execution:
  max_eval_rounds: nope
EOF
assert_output "read_profile_value falls back on invalid value" "3" \
  run_sourced "$repo2" "$profile_payload" 'read_profile_value max_eval_rounds 3 "^[0-9]+$"'

assert_output "BATON_HOOK_ACTIVE short-circuits" "" \
  PAYLOAD="$unknown_payload" HOOK_SCRIPT="$HOOK_SCRIPT" bash -c '
    cd "$1"
    export BATON_HOOK_ACTIVE=1
    source "$HOOK_SCRIPT" <<<"$PAYLOAD"
    echo after
  ' bash "$repo"

debug_out="$tmp/debug.err"
PAYLOAD="$unknown_payload" HOOK_SCRIPT="$HOOK_SCRIPT" bash -c '
  cd "$1"
  export BATON_DEBUG=1
  source "$HOOK_SCRIPT" <<<"$PAYLOAD"
  debug_log "debug-line"
' bash "$repo" >"$tmp/debug.out" 2>"$debug_out"
TOTAL=$((TOTAL + 1))
if grep -q "debug-line" "$debug_out" 2>/dev/null; then
  echo "  pass: debug_log emits when BATON_DEBUG=1"
  PASS=$((PASS + 1))
else
  echo "  FAIL: debug_log emits when BATON_DEBUG=1 — missing stderr output"
  FAIL=$((FAIL + 1))
fi

PAYLOAD="$unknown_payload" HOOK_SCRIPT="$HOOK_SCRIPT" bash -c '
  cd "$1"
  unset BATON_DEBUG
  source "$HOOK_SCRIPT" <<<"$PAYLOAD"
  debug_log "quiet-line"
' bash "$repo" >"$tmp/debug2.out" 2>"$tmp/debug2.err"
TOTAL=$((TOTAL + 1))
if [[ ! -s "$tmp/debug2.err" ]]; then
  echo "  pass: debug_log stays quiet without BATON_DEBUG"
  PASS=$((PASS + 1))
else
  echo "  FAIL: debug_log stays quiet without BATON_DEBUG — unexpected stderr output"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

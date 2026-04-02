#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREPARE_REVIEW="$SCRIPT_DIR/../spec/bootstrap/prepare-review.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — missing '$needle'"
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

repo="$tmp/repo"
mkdir -p "$repo"

cp -R "$SCRIPT_DIR/../spec" "$repo/spec"
cp -R "$SCRIPT_DIR/../skills" "$repo/skills"
cp -R "$SCRIPT_DIR" "$repo/tests"
cp -R "$SCRIPT_DIR/../.claude" "$repo/.claude"
cp -R "$SCRIPT_DIR/../.agents" "$repo/.agents"
mkdir -p "$repo/.harness"
cp "$SCRIPT_DIR/../.harness/task-status.md" "$repo/.harness/task-status.md"
cp "$SCRIPT_DIR/../README.md" "$repo/README.md"
cp "$SCRIPT_DIR/../README.zh-CN.md" "$repo/README.zh-CN.md"
cp "$SCRIPT_DIR/../CLAUDE.md" "$repo/CLAUDE.md"
cp "$SCRIPT_DIR/../AGENTS.md" "$repo/AGENTS.md"

(cd "$repo" && git init >/dev/null 2>&1)

assert_exit "prepare-review dry-run succeeds" 0 \
  bash "$PREPARE_REVIEW" --repo-root "$repo" --bootstrap-dir "$repo/spec/bootstrap" --dry-run

output="$(
  bash "$PREPARE_REVIEW" --repo-root "$repo" --bootstrap-dir "$repo/spec/bootstrap"
)"

assert_contains "prepare-review prints smoke-check banner" "$output" "prepare-review: executing SessionStart smoke check"
assert_contains "prepare-review executes live session-start command" "$output" "\"hookEventName\": \"SessionStart\""
assert_contains "prepare-review prints isolated next steps" "$output" "next isolated review steps"
assert_contains "prepare-review writes Codex hooks config" "$(ls "$repo/.codex")" "hooks.json"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/pre-transition"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

make_repo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  git -C "$dir" init -q
}

write_status() {
  local file="$1" state="$2" notes="$3"
  cat > "$file" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | $state | 0 | 2026-03-29T22:00:00+0800 | $notes |

## State Notes
$notes
EOF
}

run_hook() {
  local repo="$1" payload="$2"
  PAYLOAD="$payload" HOOK_PATH="$HOOK" bash -c '
    cd "$1"
    printf "%s" "$PAYLOAD" | bash "$HOOK_PATH"
  ' bash "$repo"
}

make_repo "$tmp/cc-ok"
write_status "$tmp/cc-ok/.harness/module-status.md" "architecting" "-"
cc_payload="$(jq -n --arg content $'# Module Status\n\n| Scope | Owner | State | Eval Round | Updated At | Notes |\n|------|------|------|-----------|-----------|------|\n| runtime-enforcement-hardening | generator | awaiting_human_arch | 0 | 2026-03-29T22:00:00+0800 | - |\n\n## State Notes\n- human_ack: true\n' '{tool_input:{file_path:".harness/module-status.md",content:$content}}')"
assert_exit "cc legal transition passes" 0 run_hook "$tmp/cc-ok" "$cc_payload"

make_repo "$tmp/cc-blocked"
write_status "$tmp/cc-blocked/.harness/module-status.md" "generating" "-"
cc_blocked_payload="$(jq -n --arg content $'# Module Status\n\n| Scope | Owner | State | Eval Round | Updated At | Notes |\n|------|------|------|-----------|-----------|------|\n| runtime-enforcement-hardening | generator | blocked | 0 | 2026-03-29T22:00:00+0800 | missing blocker |\n\n## State Notes\n- human_ack: true\n' '{tool_input:{file_path:".harness/module-status.md",content:$content}}')"
assert_exit "cc blocked transition needs classification" 2 run_hook "$tmp/cc-blocked" "$cc_blocked_payload"

make_repo "$tmp/cc-blocked-ok"
write_status "$tmp/cc-blocked-ok/.harness/module-status.md" "generating" "-"
cc_blocked_ok_payload="$(jq -n --arg content $'# Module Status\n\n| Scope | Owner | State | Eval Round | Updated At | Notes |\n|------|------|------|-----------|-----------|------|\n| runtime-enforcement-hardening | generator | blocked | 0 | 2026-03-29T22:00:00+0800 | [design_blocker] design mismatch |\n\n## State Notes\n- human_ack: true\n' '{tool_input:{file_path:".harness/module-status.md",content:$content}}')"
assert_exit "cc blocked transition with classification passes" 0 run_hook "$tmp/cc-blocked-ok" "$cc_blocked_ok_payload"

make_repo "$tmp/cc-human-block"
write_status "$tmp/cc-human-block/.harness/module-status.md" "awaiting_human_arch" "- human_ack: false"
human_payload="$(jq -n --arg content $'# Module Status\n\n| Scope | Owner | State | Eval Round | Updated At | Notes |\n|------|------|------|-----------|-----------|------|\n| runtime-enforcement-hardening | generator | verification_check | 0 | 2026-03-29T22:00:00+0800 | - |\n\n## State Notes\n- human_ack: false\n' '{tool_input:{file_path:".harness/module-status.md",content:$content}}')"
assert_exit "human gate blocks without ack" 2 run_hook "$tmp/cc-human-block" "$human_payload"

make_repo "$tmp/cc-human-ok"
write_status "$tmp/cc-human-ok/.harness/module-status.md" "awaiting_human_arch" "- human_ack: true"
human_ok_payload="$(jq -n --arg content $'# Module Status\n\n| Scope | Owner | State | Eval Round | Updated At | Notes |\n|------|------|------|-----------|-----------|------|\n| runtime-enforcement-hardening | generator | verification_check | 0 | 2026-03-29T22:00:00+0800 | - |\n\n## State Notes\n- human_ack: true\n' '{tool_input:{file_path:".harness/module-status.md",content:$content}}')"
assert_exit "human gate passes with ack" 0 run_hook "$tmp/cc-human-ok" "$human_ok_payload"

make_repo "$tmp/codex-blocked"
write_status "$tmp/codex-blocked/.harness/module-status.md" "generating" "-"
codex_payload="$(jq -n --arg command 'echo "| runtime-enforcement-hardening | generator | blocked | 0 | 2026-03-29T22:00:00+0800 | missing blocker |" > .harness/module-status.md' '{tool_input:{command:$command}}')"
assert_exit "codex blocked transition defers classification to post-artifact" 0 run_hook "$tmp/codex-blocked" "$codex_payload"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

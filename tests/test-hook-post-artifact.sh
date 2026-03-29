#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/post-artifact"
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

write_module_status() {
  local file="$1" state="$2" row_notes="$3" state_notes="$4"
  cat > "$file" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | $state | 0 | 2026-03-29T22:00:00+0800 | $row_notes |

## State Notes
$state_notes
EOF
}

transition_cache_path() {
  local repo="$1"
  local root=""
  root="$(git -C "$repo" rev-parse --show-toplevel)"
  printf '/tmp/baton-transition-%s\n' "$(printf '%s' "$root" | cksum | awk '{print $1}')"
}

run_hook() {
  local repo="$1" payload="$2"
  PAYLOAD="$payload" HOOK_PATH="$HOOK" bash -c '
    cd "$1"
    printf "%s" "$PAYLOAD" | bash "$HOOK_PATH"
  ' bash "$repo"
}

make_repo "$tmp/cc-ok"
write_module_status "$tmp/cc-ok/.harness/module-status.md" "verification_check" "active" "- human_ack: true"
cc_payload='{"tool_input":{"file_path":".harness/module-status.md"}}'
printf 'from_state=awaiting_human_arch\nto_state=verification_check\n' > "$(transition_cache_path "$tmp/cc-ok")"
run_hook "$tmp/cc-ok" "$cc_payload"
TOTAL=$((TOTAL + 1))
if ! grep -q '^[-] human_ack: true$' "$tmp/cc-ok/.harness/module-status.md" 2>/dev/null; then
  echo "  pass: human_ack cleared after successful validation"
  PASS=$((PASS + 1))
else
  echo "  FAIL: human_ack cleared after successful validation — ack still present"
  FAIL=$((FAIL + 1))
fi

make_repo "$tmp/cc-bad"
cat > "$tmp/cc-bad/.harness/module-status.md" <<'EOF'
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | verification_check | 0 | 2026-03-29T22:00:00+0800 | active |

## Wrong Notes
- human_ack: true
EOF
bad_cc_payload='{"tool_input":{"file_path":".harness/module-status.md"}}'
assert_exit "invalid module-status does not clear ack" 2 run_hook "$tmp/cc-bad" "$bad_cc_payload"
TOTAL=$((TOTAL + 1))
if grep -q '^[-] human_ack: true$' "$tmp/cc-bad/.harness/module-status.md" 2>/dev/null; then
  echo "  pass: ack preserved when validation fails"
  PASS=$((PASS + 1))
else
  echo "  FAIL: ack preserved when validation fails — ack was removed"
  FAIL=$((FAIL + 1))
fi

make_repo "$tmp/cc-no-transition"
write_module_status "$tmp/cc-no-transition/.harness/module-status.md" "reviewing" "active" "- human_ack: true"
no_transition_payload='{"tool_input":{"file_path":".harness/module-status.md"}}'
run_hook "$tmp/cc-no-transition" "$no_transition_payload"
TOTAL=$((TOTAL + 1))
if grep -q '^[-] human_ack: true$' "$tmp/cc-no-transition/.harness/module-status.md" 2>/dev/null; then
  echo "  pass: ack is preserved without cached transition from a gated state"
  PASS=$((PASS + 1))
else
  echo "  FAIL: ack is preserved without cached transition from a gated state — ack was removed"
  FAIL=$((FAIL + 1))
fi

make_repo "$tmp/codex-bad"
write_module_status "$tmp/codex-bad/.harness/module-status.md" "blocked" "missing blocker" "[design_blocker]"
codex_payload="$(jq -n --arg command 'echo "| runtime-enforcement-hardening | generator | blocked | 0 | 2026-03-29T22:00:00+0800 | missing blocker |" > .harness/module-status.md' '{tool_input:{command:$command}}')"
assert_exit "codex blocked classification enforced on-disk" 2 run_hook "$tmp/codex-bad" "$codex_payload"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

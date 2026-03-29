#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../spec/bootstrap/hooks/session-start.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_json_field() {
  local label="$1" repo="$2" jq_expr="$3"
  TOTAL=$((TOTAL + 1))
  local out=""
  out="$(PAYLOAD='{}' HOOK_PATH="$HOOK" bash -c '
    cd "$1"
    printf "%s" "$PAYLOAD" | bash "$HOOK_PATH"
  ' bash "$repo" 2>/dev/null || true)"
  if echo "$out" | jq -e "$jq_expr" >/dev/null 2>&1; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — jq '$jq_expr' failed on: $out"
    FAIL=$((FAIL + 1))
  fi
}

make_repo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  git -C "$dir" init -q
}

write_status() {
  local file="$1" state="$2"
  cat > "$file" <<EOF
# Module Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| runtime-enforcement-hardening | generator | $state | 0 | 2026-03-29T22:00:00+0800 | active |

## State Notes
EOF
}

make_repo "$tmp/empty"
assert_json_field "no task session-start output is valid JSON" "$tmp/empty" '.hookSpecificOutput.hookEventName == "SessionStart"'

make_repo "$tmp/overlay"
write_status "$tmp/overlay/.harness/module-status.md" "generating"
cat > "$tmp/overlay/.harness/scoped-map.md" <<'EOF'
# Scoped Map: runtime-enforcement-hardening
## 1. Scope
content
## 2. Entry Point
content
## 3. Call Chain
content
## 4. Existing Behavior
content
## 5. Existing Tests
content
## 6. Dependency / Risk Scan
content
## 7. Change Shape
content
## 9. Recommendation
content

## Overlay Recommendation
overlay: core
EOF
touch "$tmp/overlay/.harness/requirements.md" \
  "$tmp/overlay/.harness/architecture.md" \
  "$tmp/overlay/.harness/verification-path.md"
assert_json_field "overlay recommendation surfaces in session-start" "$tmp/overlay" '.hookSpecificOutput.additionalContext | test("overlay: core")'

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

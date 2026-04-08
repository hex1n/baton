#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0

check() {
  local label="$1" result="$2" detail="${3:-}"
  if [[ "$result" == "pass" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — $detail"
    FAIL=$((FAIL + 1))
  fi
}

require_pattern() {
  local file="$1" pattern="$2" label="$3" detail="$4"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    check "$label" "pass"
  else
    check "$label" "fail" "$detail"
  fi
}

echo "  Mode degradation"

require_pattern "$REPO_ROOT/v2/protocol.md" "Mode B/C must include: \"⚠️ Verification independence: degraded — human review weight is higher\\.\"" \
  "protocol requires degraded-independence note" "protocol lost the degraded-independence requirement"
require_pattern "$REPO_ROOT/v2/protocol.md" "\"Cross-model review \\(L2\\.5\\)\"" \
  "protocol requires cross-model labeling" "protocol lost the L2.5 cross-model label"
require_pattern "$REPO_ROOT/v2/skills/verifier/SKILL.md" 'In Mode C/C\+, declare degraded independence in `review\.md`' \
  "verifier entrypoint requires degraded-independence note" "Verifier entrypoint no longer enforces degradation disclosure"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "⚠️ Verification independence: degraded — human review weight is higher\\." \
  "review template includes degraded-independence text" "review template missing degraded-independence placeholder"
require_pattern "$REPO_ROOT/v2/skills/verifier/verification.md" "⚠️ Verification independence: degraded — human review weight is higher\\." \
  "verification guide emits degraded-independence text" "verification guide sample missing degraded-independence note"

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

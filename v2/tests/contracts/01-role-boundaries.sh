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

forbid_pattern() {
  local file="$1" pattern="$2" label="$3" detail="$4"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    check "$label" "fail" "$detail"
  else
    check "$label" "pass"
  fi
}

echo "  Role boundaries"

require_pattern "$REPO_ROOT/v2/protocol.md" "Builder is the only role that modifies source code or tests" \
  "protocol assigns mutation to Builder only" "missing Builder-only mutation rule"
require_pattern "$REPO_ROOT/v2/protocol.md" "\\*\\*Writes:\\*\\* review\\.md only" \
  "protocol keeps Verifier output read-only" "Verifier output contract drifted"
require_pattern "$REPO_ROOT/v2/skills/verifier/SKILL.md" "Verification is read-only\\. Do not modify source code, tests, or the working tree" \
  "verifier entrypoint states read-only boundary" "Verifier entrypoint lost the read-only rule"
require_pattern "$REPO_ROOT/v2/skills/verifier/SKILL.md" "Optional add-on files stay read-only and additive" \
  "verifier add-ons stay read-only" "Verifier add-on boundary missing"
require_pattern "$REPO_ROOT/v2/skills/verifier/cross-model.md" "read-only review" \
  "cross-model review stays read-only" "cross-model guide no longer declares read-only review"
require_pattern "$REPO_ROOT/v2/skills/verifier/cross-model.md" "never trigger or apply fixes" \
  "cross-model guide forbids fixes" "cross-model guide may be mutating again"
forbid_pattern "$REPO_ROOT/v2/skills/verifier/cross-model.md" "/codex:rescue|rescue \\(optional\\)" \
  "cross-model guide forbids rescue path" "found rescue workflow inside Verifier guide"

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

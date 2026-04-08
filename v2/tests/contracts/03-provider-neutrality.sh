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

vendor_pattern='codex-plugin-cc|/codex:|openai codex|claude code|/plugin install|/plugin marketplace add'

files=(
  "$REPO_ROOT/v2/protocol.md"
  "$REPO_ROOT/v2/skills/dispatch/SKILL.md"
  "$REPO_ROOT/v2/skills/planner/SKILL.md"
  "$REPO_ROOT/v2/skills/builder/SKILL.md"
  "$REPO_ROOT/v2/skills/verifier/SKILL.md"
  "$REPO_ROOT/v2/skills/verifier/cross-model.md"
  "$REPO_ROOT/v2/templates/plan.template.md"
  "$REPO_ROOT/v2/templates/project-profile.template.md"
  "$REPO_ROOT/v2/templates/review.template.md"
  "$REPO_ROOT/v2/tools/external-review.sh"
  "$REPO_ROOT/CLAUDE.md"
  "$REPO_ROOT/v2/CLAUDE.md"
  "$REPO_ROOT/CONTRIBUTING.md"
)

echo "  Provider neutrality"

for file in "${files[@]}"; do
  label="${file#$REPO_ROOT/}"
  if grep -qiE "$vendor_pattern" "$file" 2>/dev/null; then
    check "$label stays provider-neutral" "fail" "found host/provider-specific command or product name"
  else
    check "$label stays provider-neutral" "pass"
  fi
done

if [[ -f "$REPO_ROOT/v2/tools/external-review.sh" ]]; then
  check "v2/tools/external-review.sh exists" "pass"
else
  check "v2/tools/external-review.sh exists" "fail" "missing external review adapter"
fi

if grep -q "external-review.sh" "$REPO_ROOT/v2/skills/verifier/cross-model.md" 2>/dev/null; then
  check "cross-model guide routes through external-review.sh" "pass"
else
  check "cross-model guide routes through external-review.sh" "fail" "cross-model guide still bypasses the adapter"
fi

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

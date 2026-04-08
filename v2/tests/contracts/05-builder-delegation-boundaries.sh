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

echo "  Builder delegation boundaries"

require_pattern "$REPO_ROOT/v2/protocol.md" "^## Builder Delegation$" \
  "protocol declares Builder Delegation section" "Builder delegation section missing from protocol"
require_pattern "$REPO_ROOT/v2/protocol.md" "This is an implementation detail inside Builder, not a fifth Baton role\\." \
  "protocol keeps worker as internal Builder detail" "protocol drifted toward a public worker role"
require_pattern "$REPO_ROOT/v2/protocol.md" 'only Builder writes source code/tests in the shared workspace and only Builder updates `\.harness/plan\.md`\.' \
  "protocol keeps canonical writes in Builder" "protocol lost canonical write ownership rule"
require_pattern "$REPO_ROOT/v2/protocol.md" 'internal workers may not ask the human directly, update `\.harness/review\.md`, invoke external review, or change execution mode\.' \
  "protocol blocks worker control-plane actions" "protocol no longer blocks worker control-plane actions"
require_pattern "$REPO_ROOT/v2/skills/builder/SKILL.md" "Worker must NOT update \\.harness/plan\\.md or \\.harness/review\\.md" \
  "builder entrypoint blocks worker artifact writes" "builder entrypoint lost worker artifact boundary"
require_pattern "$REPO_ROOT/v2/skills/builder/SKILL.md" "Worker must NOT ask the human directly or invoke external review" \
  "builder entrypoint blocks worker human/external review access" "builder entrypoint lost human/external review boundary"
require_pattern "$REPO_ROOT/v2/skills/builder/workers.md" "Internal workers are part of Builder\\. They are not Baton roles" \
  "worker guide keeps internal-role boundary" "worker guide drifted toward a public role"
require_pattern "$REPO_ROOT/v2/skills/builder/workers.md" 'Update `\.harness/plan\.md` or `\.harness/review\.md`' \
  "worker guide forbids harness writes" "worker guide no longer forbids harness writes"
require_pattern "$REPO_ROOT/v2/skills/builder/workers.md" "Ask the human directly" \
  "worker guide forbids direct human access" "worker guide no longer forbids direct human access"
require_pattern "$REPO_ROOT/v2/skills/builder/workers.md" 'Invoke Verifier or `external-review\.sh`' \
  "worker guide forbids external verification escalation" "worker guide no longer forbids direct verification escalation"
require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "show-status" \
  "builder-slice helper exposes status inspection" "builder-slice helper missing show-status action"
require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "STATE_BASE=.*\\.context/baton/active/slices" \
  "builder-slice helper stays in scratch state" "builder-slice helper no longer writes under scratch slices"

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

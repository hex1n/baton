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

echo "  Design projection contracts"

require_pattern "$REPO_ROOT/v2/protocol.md" "^### Design-First Planning$" \
  "protocol defines design-first planning" "protocol missing Design-First Planning section"
require_pattern "$REPO_ROOT/v2/protocol.md" "^### Default Planner Engines$" \
  "protocol defines default planner engines" "protocol missing Default Planner Engines section"
require_pattern "$REPO_ROOT/v2/protocol.md" "\.harness/design\.md" \
  "protocol references design.md artifact" "protocol missing design.md artifact references"
require_pattern "$REPO_ROOT/v2/protocol.md" 'Dispatcher never routes directly from `design\.md`' \
  "protocol forbids routing from design.md" "protocol missing dispatcher/design boundary"
require_pattern "$REPO_ROOT/v2/skills/planner/SKILL.md" "project-from-design\.md" \
  "planner skill references projection guide" "planner skill missing project-from-design companion file"
require_pattern "$REPO_ROOT/v2/skills/planner/SKILL.md" "engine-selection\.md" \
  "planner skill references engine selection guide" "planner skill missing engine-selection companion file"
require_pattern "$REPO_ROOT/v2/skills/planner/planning.md" 'Draft or revise `design\.md`' \
  "planner guide writes design.md first" "planner guide missing design-first step"
require_pattern "$REPO_ROOT/v2/skills/planner/planning.md" "Select the planning engine" \
  "planner guide selects planning engine" "planner guide missing planning-engine selection step"
require_pattern "$REPO_ROOT/v2/skills/verifier/preflight.md" "Read: \.harness/design\.md" \
  "verifier preflight reads design.md" "preflight missing design.md input"
if [[ -f "$REPO_ROOT/v2/tools/validate-design-projection.sh" ]]; then
  check "validate-design-projection.sh exists" "pass"
else
  check "validate-design-projection.sh exists" "fail" "missing design projection validator"
fi
if [[ -f "$REPO_ROOT/skills/superpowers-planning-engine/SKILL.md" ]]; then
  check "superpowers planning companion exists" "pass"
else
  check "superpowers planning companion exists" "fail" "missing superpowers planning companion"
fi
if [[ -f "$REPO_ROOT/skills/superpowers-debugging-engine/SKILL.md" ]]; then
  check "superpowers debugging companion exists" "pass"
else
  check "superpowers debugging companion exists" "fail" "missing superpowers debugging companion"
fi

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

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

echo "  Artifact contracts"

require_pattern "$REPO_ROOT/v2/protocol.md" "plan\\.md is the single source of truth" \
  "protocol declares plan.md as control plane" "plan.md single-source rule missing"
require_pattern "$REPO_ROOT/v2/protocol.md" '`\§ Open Decisions` is the only place Planner records unresolved human choices' \
  "protocol pins Open Decisions field" "Open Decisions uniqueness rule missing"
require_pattern "$REPO_ROOT/v2/protocol.md" '`\§ Routing Signals` is the only place Verifier tells Dispatcher what should happen next' \
  "protocol pins Routing Signals field" "Routing Signals uniqueness rule missing"
require_pattern "$REPO_ROOT/v2/templates/plan.template.md" "^### Open Decisions$" \
  "plan template includes Open Decisions section" "Open Decisions section missing from plan template"
require_pattern "$REPO_ROOT/v2/templates/plan.template.md" "^\\| ID \\| Question \\| Options \\| Status \\| Blocking \\|" \
  "plan template includes Open Decisions table" "Open Decisions table header missing"
require_pattern "$REPO_ROOT/v2/templates/plan.template.md" "^### Round Contract$" \
  "plan template includes Round Contract section" "Round Contract section missing from plan template"
require_pattern "$REPO_ROOT/v2/templates/plan.template.md" "^### Implementation Slices$" \
  "plan template includes Implementation Slices section" "Implementation Slices section missing from plan template"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^## Routing Signals$" \
  "review template includes Routing Signals section" "Routing Signals section missing from review template"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^### Contract Status$" \
  "review template includes Contract Status section" "Contract Status section missing from review template"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^### Findings Sidecar$" \
  "review template includes findings sidecar section" "Findings Sidecar section missing from review template"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^\\| Next Route \\|" \
  "review template includes next-route row" "Next Route row missing"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^\\| Human Review Needed \\|" \
  "review template includes human-review row" "Human Review Needed row missing"
require_pattern "$REPO_ROOT/v2/templates/review.template.md" "^\\| Blocking \\|" \
  "review template includes blocking row" "Blocking row missing"
require_pattern "$REPO_ROOT/CLAUDE.md" "plan\\.md" \
  "root CLAUDE projects plan.md" "root CLAUDE still points at legacy artifact names"
require_pattern "$REPO_ROOT/CLAUDE.md" "review\\.md" \
  "root CLAUDE projects review.md" "root CLAUDE still points at legacy review artifact"
forbid_pattern "$REPO_ROOT/CLAUDE.md" "brief\\.md|eval\\.md|brief\\.template\\.md" \
  "root CLAUDE avoids legacy artifact names" "root CLAUDE still contains brief/eval legacy names"
if [[ -f "$REPO_ROOT/v2/templates/review-findings.template.json" ]]; then
  check "review findings template exists" "pass"
else
  check "review findings template exists" "fail" "missing review-findings.template.json"
fi

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

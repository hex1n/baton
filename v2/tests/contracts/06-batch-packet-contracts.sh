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

echo "  Batch packet contracts"

require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^# Batch Packet: Round \\{N\\} Batch \\{M\\}$" \
  "batch packet template title" "batch packet template title missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Metadata$" \
  "batch packet template metadata section" "batch packet metadata missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^\\| Trigger \\|" \
  "batch packet template trigger row" "batch packet trigger row missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^\\| Delegation Mode \\|" \
  "batch packet template delegation-mode row" "batch packet mode row missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^\\| Start SHA \\|" \
  "batch packet template start-sha row" "batch packet start sha row missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Objective$" \
  "batch packet template objective section" "batch packet objective missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Scope Slice$" \
  "batch packet template scope section" "batch packet scope section missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Allowed Files$" \
  "batch packet template allowed-files section" "batch packet allowed-files section missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Forbidden Actions$" \
  "batch packet template forbidden-actions section" "batch packet forbidden-actions section missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Acceptance Checks$" \
  "batch packet template acceptance-checks section" "batch packet acceptance checks missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Test Commands$" \
  "batch packet template test-commands section" "batch packet test commands missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Context Snippets$" \
  "batch packet template context-snippets section" "batch packet context snippets missing"
require_pattern "$REPO_ROOT/v2/templates/batch-packet.template.md" "^## Expected Outputs$" \
  "batch packet template expected-outputs section" "batch packet expected outputs missing"

require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^# Worker Report: Round \\{N\\} Batch \\{M\\}$" \
  "worker report md title" "worker report markdown title missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^\\| Status \\| \\{complete / complete_with_concerns / needs_context / blocked\\} \\|" \
  "worker report md status row" "worker report markdown status row missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Summary$" \
  "worker report md summary section" "worker report markdown summary missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Files Touched$" \
  "worker report md files section" "worker report markdown files section missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Commands Run$" \
  "worker report md commands section" "worker report markdown commands section missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Concerns$" \
  "worker report md concerns section" "worker report markdown concerns section missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Open Questions$" \
  "worker report md open-questions section" "worker report markdown open questions missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^## Patch$" \
  "worker report md patch section" "worker report markdown patch section missing"

require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"status": "complete\|complete_with_concerns\|needs_context\|blocked"' \
  "worker report json status enum" "worker report json status enum missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"delegation_mode": "advisory\|isolated"' \
  "worker report json delegation mode enum" "worker report json mode enum missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"files_touched": \[' \
  "worker report json files array" "worker report json files array missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"tests_run": \[' \
  "worker report json tests array" "worker report json tests array missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"concerns": \[' \
  "worker report json concerns array" "worker report json concerns array missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"open_questions": \[' \
  "worker report json open-questions array" "worker report json open questions array missing"
require_pattern "$REPO_ROOT/v2/templates/worker-report.template.json" '"patch_path": ' \
  "worker report json patch path" "worker report json patch path missing"

require_pattern "$REPO_ROOT/v2/tools/builder-worker.sh" "init-batch" \
  "builder-worker helper exposes init-batch" "builder-worker helper missing init-batch action"
require_pattern "$REPO_ROOT/v2/tools/builder-worker.sh" "run-worker" \
  "builder-worker helper exposes run-worker" "builder-worker helper missing run-worker action"
require_pattern "$REPO_ROOT/v2/tools/builder-worker.sh" "collect-report" \
  "builder-worker helper exposes collect-report" "builder-worker helper missing collect-report action"
require_pattern "$REPO_ROOT/v2/tools/builder-worker.sh" "show-status" \
  "builder-worker helper exposes show-status" "builder-worker helper missing show-status action"

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

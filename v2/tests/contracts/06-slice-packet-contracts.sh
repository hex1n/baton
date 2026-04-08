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

echo "  Slice packet contracts"

require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^# Slice Packet: Round \\{N\\} Slice \\{M\\}$" \
  "slice packet template title" "slice packet template title missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Metadata$" \
  "slice packet template metadata section" "slice packet metadata missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^\\| Trigger \\|" \
  "slice packet template trigger row" "slice packet trigger row missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^\\| Delegation Mode \\|" \
  "slice packet template delegation-mode row" "slice packet mode row missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^\\| Start SHA \\|" \
  "slice packet template start-sha row" "slice packet start sha row missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Objective$" \
  "slice packet template objective section" "slice packet objective missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Scope Slice$" \
  "slice packet template scope section" "slice packet scope section missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Allowed Files$" \
  "slice packet template allowed-files section" "slice packet allowed-files section missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Forbidden Actions$" \
  "slice packet template forbidden-actions section" "slice packet forbidden-actions section missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Acceptance Checks$" \
  "slice packet template acceptance-checks section" "slice packet acceptance checks missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Test Commands$" \
  "slice packet template test-commands section" "slice packet test commands missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Context Snippets$" \
  "slice packet template context-snippets section" "slice packet context snippets missing"
require_pattern "$REPO_ROOT/v2/templates/slice-packet.template.md" "^## Expected Outputs$" \
  "slice packet template expected-outputs section" "slice packet expected outputs missing"

require_pattern "$REPO_ROOT/v2/templates/worker-report.template.md" "^# Worker Report: Round \\{N\\} Slice \\{M\\}$" \
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

require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "init-slice" \
  "builder-slice helper exposes init-slice" "builder-slice helper missing init-slice action"
require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "run-worker" \
  "builder-slice helper exposes run-worker" "builder-slice helper missing run-worker action"
require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "collect-report" \
  "builder-slice helper exposes collect-report" "builder-slice helper missing collect-report action"
require_pattern "$REPO_ROOT/v2/tools/builder-slice.sh" "show-status" \
  "builder-slice helper exposes show-status" "builder-slice helper missing show-status action"

echo "  Results: $PASS pass, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

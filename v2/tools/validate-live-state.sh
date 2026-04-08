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
WARN=0

check() {
  local label="$1" result="$2" detail="${3:-}"
  if [[ "$result" == "pass" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  elif [[ "$result" == "warn" ]]; then
    echo "  ⚠️  $label — $detail"
    WARN=$((WARN + 1))
  else
    echo "  ❌ $label — $detail"
    FAIL=$((FAIL + 1))
  fi
}

require_heading() {
  local file="$1" pattern="$2" label="$3" detail="$4"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    check "$label" "pass"
  else
    check "$label" "fail" "$detail"
  fi
}

echo "Baton v2 Live State Validation"
echo "================================"
echo ""

PROJECT_PROFILE="$REPO_ROOT/project-profile.md"
PLAN="$REPO_ROOT/.harness/plan.md"
REVIEW="$REPO_ROOT/.harness/review.md"

echo "1. project-profile.md"
if [[ -f "$PROJECT_PROFILE" ]]; then
  require_heading "$PROJECT_PROFILE" '^# Project Profile:' "project-profile title" "missing '# Project Profile:'"
  require_heading "$PROJECT_PROFILE" '^## Project Type$' "project-profile project type" "missing '## Project Type'"
  require_heading "$PROJECT_PROFILE" '^## Build$' "project-profile build" "missing '## Build'"
  require_heading "$PROJECT_PROFILE" '^## Test Infrastructure$' "project-profile test infrastructure" "missing '## Test Infrastructure'"
  require_heading "$PROJECT_PROFILE" '^## Conventions$' "project-profile conventions" "missing '## Conventions'"
  require_heading "$PROJECT_PROFILE" '^## Traps$' "project-profile traps" "missing '## Traps'"
  require_heading "$PROJECT_PROFILE" '^## Verifier Capability$' "project-profile verifier capability" "missing '## Verifier Capability'"
  require_heading "$PROJECT_PROFILE" '^## Builder Delegation$' "project-profile builder delegation" "missing '## Builder Delegation'"
  require_heading "$PROJECT_PROFILE" '^## Notes$' "project-profile notes" "missing '## Notes'"

  if grep -qE '^\| Modules \|.*`spec/`|^\| Modules \|.*`tests/`|^  ├── spec/|^  ├── tests/|baton-tasks/' "$PROJECT_PROFILE" 2>/dev/null; then
    check "project-profile references current layout" "fail" "module layout still lists removed legacy directories"
  else
    check "project-profile references current layout" "pass"
  fi
else
  check "project-profile.md exists" "fail" "project-profile.md is required"
fi

echo ""
echo "2. .harness/plan.md"
if [[ -f "$PLAN" ]]; then
  plan_open_decisions_count=$(grep -c '^### Open Decisions$' "$PLAN" 2>/dev/null || true)
  require_heading "$PLAN" '^# Plan:' "plan title" "missing '# Plan:'"
  require_heading "$PLAN" '^## Metadata$' "plan metadata section" "missing '## Metadata'"
  require_heading "$PLAN" '^\| Execution Mode \|' "plan execution mode" "missing Execution Mode row in task table"
  require_heading "$PLAN" '^## Context$' "plan context section" "missing '## Context'"
  require_heading "$PLAN" '^### Exploration Boundary$' "plan exploration boundary" "missing '### Exploration Boundary'"
  require_heading "$PLAN" '^## Scope Breakdown$' "plan scope breakdown" "missing '## Scope Breakdown'"
  require_heading "$PLAN" '^## Round History$' "plan round history" "missing '## Round History'"
  require_heading "$PLAN" '^## Round [0-9]+$' "plan current round" "missing current round section"
  require_heading "$PLAN" '^### Acceptance Criteria$' "plan AC section" "missing '### Acceptance Criteria'"
  require_heading "$PLAN" '^### Open Decisions$' "plan open decisions" "missing '### Open Decisions'"
  require_heading "$PLAN" '^\| ID \| Question \| Options \| Status \| Blocking \|' "plan open decisions table" "missing Open Decisions table header"
  require_heading "$PLAN" '^### Approach$' "plan approach section" "missing '### Approach'"
  require_heading "$PLAN" '^### Batch Plan$' "plan batch plan" "missing '### Batch Plan'"
  require_heading "$PLAN" '^### AC → Test Mapping$' "plan AC mapping" "missing '### AC → Test Mapping'"
  require_heading "$PLAN" '^### Commit Checkpoints$' "plan commit checkpoints" "missing '### Commit Checkpoints'"
  require_heading "$PLAN" '^### Discoveries$' "plan discoveries" "missing '### Discoveries'"
  require_heading "$PLAN" '^### Risks$' "plan risks" "missing '### Risks'"
  require_heading "$PLAN" '^## Future Rounds' "plan future rounds" "missing '## Future Rounds'"

  if [[ "$plan_open_decisions_count" -eq 1 ]]; then
    check "plan single open decisions section" "pass"
  else
    check "plan single open decisions section" "fail" "expected exactly 1 '### Open Decisions' section, found $plan_open_decisions_count"
  fi

  if grep -q '^## Status$' "$PLAN" 2>/dev/null; then
    check "plan avoids legacy status section" "fail" "found legacy '## Status' section"
  else
    check "plan avoids legacy status section" "pass"
  fi

  if grep -qiE 'strict mode|strict vs compact|strict/compact' "$PLAN" 2>/dev/null; then
    check "plan uses current mode terminology" "fail" "found legacy strict/compact terminology"
  else
    check "plan uses current mode terminology" "pass"
  fi
else
  check "plan.md present" "warn" "no active task plan found"
fi

echo ""
echo "3. .harness/review.md"
if [[ -f "$REVIEW" ]]; then
  review_routing_signals_count=$(grep -c '^## Routing Signals$' "$REVIEW" 2>/dev/null || true)
  require_heading "$REVIEW" '^# Review: Round [0-9]+$' "review title" "missing '# Review: Round {N}'"
  require_heading "$REVIEW" '^## Pre-flight' "review pre-flight section" "missing '## Pre-flight'"
  require_heading "$REVIEW" '^## Verification$' "review verification section" "missing '## Verification'"
  require_heading "$REVIEW" '^## Findings$' "review findings section" "missing '## Findings'"
  require_heading "$REVIEW" '^### Findings Sidecar$' "review findings sidecar" "missing '### Findings Sidecar'"
  require_heading "$REVIEW" '^- Path: ' "review findings sidecar path" "missing findings sidecar path line"
  require_heading "$REVIEW" '^- Status: ' "review findings sidecar status" "missing findings sidecar status line"
  require_heading "$REVIEW" '^## Human Judgment$' "review human judgment" "missing '## Human Judgment'"
  require_heading "$REVIEW" '^## Routing Signals$' "review routing signals" "missing '## Routing Signals'"
  require_heading "$REVIEW" '^\| Next Route \|' "review next route row" "missing Next Route row"
  require_heading "$REVIEW" '^\| Human Review Needed \|' "review human review row" "missing Human Review Needed row"
  require_heading "$REVIEW" '^\| Blocking \|' "review blocking row" "missing Blocking row"
  require_heading "$REVIEW" '^## Verdict' "review verdict" "missing '## Verdict'"

  if [[ "$review_routing_signals_count" -eq 1 ]]; then
    check "review single routing signals section" "pass"
  else
    check "review single routing signals section" "fail" "expected exactly 1 '## Routing Signals' section, found $review_routing_signals_count"
  fi

  sidecar_line=$(grep -m1 '^- Path: ' "$REVIEW" 2>/dev/null || true)
  sidecar_path="${sidecar_line#- Path: }"
  sidecar_path="${sidecar_path#\`}"
  sidecar_path="${sidecar_path%\`}"
  if [[ -z "$sidecar_path" || "$sidecar_path" == "N/A" ]]; then
    check "review findings sidecar optional path" "pass"
  else
    sidecar_abs="$REPO_ROOT/$sidecar_path"
    if [[ -f "$sidecar_abs" ]]; then
      check "review findings sidecar file exists" "pass"
      if grep -q '"round"' "$sidecar_abs" 2>/dev/null && grep -q '"findings"' "$sidecar_abs" 2>/dev/null; then
        check "review findings sidecar shape" "pass"
      else
        check "review findings sidecar shape" "fail" "sidecar exists but does not look like review findings JSON"
      fi
    else
      check "review findings sidecar file exists" "fail" "declared sidecar path not found: $sidecar_path"
    fi
  fi
else
  check "review.md present" "warn" "no current review found"
fi

echo ""
echo "================================"
echo "Results: $PASS pass, $FAIL fail, $WARN warn"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

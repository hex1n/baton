#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

DESIGN="$REPO_ROOT/.harness/design.md"
PLAN="$REPO_ROOT/.harness/plan.md"

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

require_alias_heading() {
  local file="$1" pattern="$2" label="$3" detail="$4"
  if grep -qiE "^#{1,6}[[:space:]]+(${pattern})[[:space:]]*$" "$file" 2>/dev/null; then
    check "$label" "pass"
  else
    check "$label" "fail" "$detail"
  fi
}

extract_plan_value() {
  local file="$1" key="$2"
  awk -F'|' -v key="$key" '
    /^\|/ {
      left=$2
      right=$3
      gsub(/^[ \t]+|[ \t]+$/, "", left)
      gsub(/^[ \t]+|[ \t]+$/, "", right)
      if (left == key) {
        print right
        exit
      }
    }
  ' "$file"
}

echo "Baton v2 Design Projection Validation"
echo "===================================="
echo ""

if [[ ! -f "$PLAN" && ! -f "$DESIGN" ]]; then
  check "no active design projection required" "warn" "no active task artifacts found"
  echo ""
  echo "Results: $PASS pass, $FAIL fail, $WARN warn"
  exit 0
fi

if [[ -f "$PLAN" && ! -f "$DESIGN" ]]; then
  check "design.md exists for active task" "fail" "plan.md exists but design.md is missing"
  echo ""
  echo "Results: $PASS pass, $FAIL fail, $WARN warn"
  exit 1
fi

if [[ -f "$DESIGN" ]]; then
  require_alias_heading "$DESIGN" 'Problem|Problem Definition' "design problem section" "missing Problem / Problem Definition section"
  require_alias_heading "$DESIGN" 'Goals|Objectives' "design goals section" "missing Goals / Objectives section"
  require_alias_heading "$DESIGN" 'Non-goals|Out of Scope|Non Goals' "design non-goals section" "missing Non-goals / Out of Scope section"
  require_alias_heading "$DESIGN" 'Recommended Approach|Recommendation|Proposed Approach' "design recommended approach section" "missing Recommended Approach / Recommendation section"
  require_alias_heading "$DESIGN" 'Implementation Plan|Implementation Slices|Execution Plan' "design implementation plan section" "missing Implementation Plan / Implementation Slices section"
  require_alias_heading "$DESIGN" 'Risks|Risk Analysis' "design risks section" "missing Risks section"
  require_alias_heading "$DESIGN" 'Self-Check|Failure Modes|Self Check' "design self-check section" "missing Self-Check / Failure Modes section"
fi

if [[ -f "$PLAN" ]]; then
  planning_depth="$(extract_plan_value "$PLAN" "Planning Depth")"

  if grep -qE '^\| OD-[0-9]+\.[0-9]+ \|' "$PLAN" 2>/dev/null; then
    require_alias_heading "$DESIGN" 'Need Confirmation|Open Questions|Questions' \
      "design need-confirmation section" "plan has Open Decisions rows but design lacks Need Confirmation / Open Questions"
  else
    check "design need-confirmation section" "pass"
  fi

  if [[ "$planning_depth" == "deepen" ]]; then
    require_alias_heading "$DESIGN" 'Alternatives|Trade-offs|Tradeoffs|Options Considered' \
      "design alternatives section for deepen round" "deepen round requires Alternatives / Trade-offs section"
  else
    check "design alternatives requirement" "pass"
  fi
fi

echo ""
echo "Results: $PASS pass, $FAIL fail, $WARN warn"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

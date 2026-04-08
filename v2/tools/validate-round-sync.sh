#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PLAN="$REPO_ROOT/.harness/plan.md"
REVIEW="$REPO_ROOT/.harness/review.md"

extract_plan_round() {
  awk -F'|' '
    /^\| Round \|/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $3)
      print $3
      exit
    }
  ' "$1"
}

extract_review_round() {
  sed -n 's/^# Review: Round \([0-9][0-9]*\)$/\1/p' "$1" | head -n 1
}

echo "Baton v2 Round Sync Validation"
echo "=============================="

if [[ ! -f "$PLAN" ]]; then
  echo "  ⚠️  plan.md not found — no active task"
  exit 0
fi

plan_round="$(extract_plan_round "$PLAN")"
if [[ -z "$plan_round" ]]; then
  echo "  ❌ Could not determine current round from plan.md"
  exit 1
fi

echo "  • plan.md current round: $plan_round"

if [[ ! -f "$REVIEW" ]]; then
  echo "  ⚠️  review.md not found — round may be mid-flight"
  exit 0
fi

review_round="$(extract_review_round "$REVIEW")"
if [[ -z "$review_round" ]]; then
  echo "  ❌ Could not determine round from review.md"
  exit 1
fi

echo "  • review.md round: $review_round"

if (( review_round > plan_round )); then
  echo "  ❌ review.md is ahead of plan.md"
  exit 1
fi

if (( review_round < plan_round )); then
  echo "  ✅ review.md is stale but valid — Dispatcher should treat this as 'new round pending'"
  exit 0
fi

echo "  ✅ plan.md and review.md are aligned on the same round"
exit 0

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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

extract_metadata_value() {
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

extract_round_contract_value() {
  local file="$1" round="$2" key="$3"
  awk -F'|' -v round="$round" -v key="$key" '
    $0 ~ "^## Round " round "$" { in_round=1; next }
    in_round && $0 ~ "^## Round [0-9]+$" { exit }
    in_round && $0 == "### Round Contract" { in_contract=1; next }
    in_contract && $0 ~ "^### " { in_contract=0 }
    in_contract && /^\|/ {
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

extract_plan_quality_value() {
  local file="$1" round="$2" key="$3"
  awk -F'|' -v round="$round" -v key="$key" '
    $0 ~ "^## Round " round "$" { in_round=1; next }
    in_round && $0 ~ "^## Round [0-9]+$" { exit }
    in_round && $0 == "### Plan Quality" { in_quality=1; next }
    in_quality && $0 ~ "^### " { in_quality=0 }
    in_quality && /^\|/ {
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

extract_review_signal() {
  local file="$1" key="$2"
  awk -F'|' -v key="$key" '
    $0 == "## Routing Signals" { in_signals=1; next }
    in_signals && /^## / { exit }
    in_signals && /^\|/ {
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

extract_review_round() {
  sed -n 's/^# Review: Round \([0-9][0-9]*\)$/\1/p' "$1" | head -n 1
}

extract_ac_count() {
  local file="$1" round="$2"
  awk -v round="$round" '
    $0 ~ "^## Round " round "$" { in_round=1; next }
    in_round && $0 ~ "^## Round [0-9]+$" { exit }
    in_round && $0 ~ "^\\*\\*AC-" round "\\.[0-9]+:" { count++ }
    END { print count + 0 }
  ' "$file"
}

contains_any() {
  local text="$1"
  shift
  local needle
  for needle in "$@"; do
    [[ -z "$needle" ]] && continue
    if [[ "$text" == *"$needle"* ]]; then
      return 0
    fi
  done
  return 1
}

echo "Baton v2 Round Contract Lint"
echo "============================"
echo ""

if [[ ! -f "$PLAN" ]]; then
  check "plan.md present" "warn" "no active task plan found"
  echo ""
  echo "Results: $PASS pass, $FAIL fail, $WARN warn"
  exit 0
fi

round="$(extract_metadata_value "$PLAN" "Round")"
execution_mode="$(extract_metadata_value "$PLAN" "Execution Mode")"
verifier_mode="$(extract_metadata_value "$PLAN" "Verifier Mode")"
scope_class="$(extract_metadata_value "$PLAN" "Scope Class")"
risk_class="$(extract_metadata_value "$PLAN" "Risk Class")"
expected_slices="$(extract_metadata_value "$PLAN" "Expected Slices This Round")"

scope_out="$(extract_round_contract_value "$PLAN" "$round" "Scope Out")"
done_criteria="$(extract_round_contract_value "$PLAN" "$round" "Done Criteria")"
verification_plan="$(extract_round_contract_value "$PLAN" "$round" "Verification Plan")"
budget_note="$(extract_round_contract_value "$PLAN" "$round" "Budget Note")"
overload_override="$(extract_round_contract_value "$PLAN" "$round" "Overload Override")"
key_entry_points="$(extract_round_contract_value "$PLAN" "$round" "Key Entry Points")"
planning_depth="$(extract_plan_quality_value "$PLAN" "$round" "Planning Depth")"
recommendation_confidence="$(extract_plan_quality_value "$PLAN" "$round" "Recommendation Confidence")"
confidence_basis="$(extract_plan_quality_value "$PLAN" "$round" "Confidence Basis")"
problem_statement="$(extract_plan_quality_value "$PLAN" "$round" "Problem Statement")"
assumptions="$(extract_plan_quality_value "$PLAN" "$round" "Load-Bearing Assumptions")"
constraints_vs_conventions="$(extract_plan_quality_value "$PLAN" "$round" "Constraints vs Conventions")"
alternatives_considered="$(extract_plan_quality_value "$PLAN" "$round" "Alternatives Considered")"
failure_mode="$(extract_plan_quality_value "$PLAN" "$round" "Failure Mode")"
ac_count="$(extract_ac_count "$PLAN" "$round")"

check "round has ACs" "$([[ "$ac_count" -gt 0 ]] && echo pass || echo fail)" "current round has no acceptance criteria"

if [[ -n "$key_entry_points" ]]; then
  check "round contract key entry points row" "pass"
else
  check "round contract key entry points row" "fail" "missing Key Entry Points value"
fi

if [[ "$planning_depth" == "normal" || "$planning_depth" == "deepen" ]]; then
  check "planning depth value" "pass"
else
  check "planning depth value" "fail" "Planning Depth must be normal or deepen"
fi

if [[ "$recommendation_confidence" == "high" || "$recommendation_confidence" == "medium" || "$recommendation_confidence" == "low" ]]; then
  check "recommendation confidence value" "pass"
else
  check "recommendation confidence value" "fail" "Recommendation Confidence must be high, medium, or low"
fi

if [[ -n "$confidence_basis" && "$confidence_basis" != "None." ]]; then
  check "confidence basis present" "pass"
else
  check "confidence basis present" "fail" "Plan Quality must explain Confidence Basis"
fi

deepen_trigger="no"
if [[ "$scope_class" == "S3" || "$scope_class" == "S4" || "$risk_class" == "R2" || "$risk_class" == "R3" || "$execution_mode" == "full" ]]; then
  deepen_trigger="yes"
fi

if [[ "$deepen_trigger" == "yes" ]]; then
  if [[ "$planning_depth" == "deepen" ]]; then
    check "deepen trigger respected" "pass"
  else
    check "deepen trigger respected" "fail" "complex or risky round should set Planning Depth = deepen"
  fi
else
  check "deepen trigger" "pass"
fi

if [[ "$planning_depth" == "deepen" ]]; then
  if [[ -n "$problem_statement" && "$problem_statement" != "Normal-depth round." && "$problem_statement" != "None." ]]; then
    check "deepen problem statement" "pass"
  else
    check "deepen problem statement" "fail" "deepen rounds require a real Problem Statement"
  fi

  if [[ -n "$assumptions" && "$assumptions" != "None." ]]; then
    check "deepen assumptions" "pass"
  else
    check "deepen assumptions" "fail" "deepen rounds require load-bearing assumptions"
  fi

  if [[ -n "$constraints_vs_conventions" && "$constraints_vs_conventions" != "None." ]]; then
    check "deepen constraints vs conventions" "pass"
  else
    check "deepen constraints vs conventions" "fail" "deepen rounds require constraints-vs-conventions reasoning"
  fi

  if [[ -n "$alternatives_considered" && "$alternatives_considered" != "None." ]]; then
    check "deepen alternatives" "pass"
  else
    check "deepen alternatives" "fail" "deepen rounds require alternatives or a single-path justification"
  fi

  if [[ -n "$failure_mode" && "$failure_mode" != "None." ]]; then
    check "deepen failure mode" "pass"
  else
    check "deepen failure mode" "fail" "deepen rounds require an explicit failure mode"
  fi
fi

budget_trigger="no"
if [[ "$expected_slices" == "3+" && ( "$execution_mode" == "full" || "$scope_class" == "S4" || "$risk_class" == "R3" ) ]]; then
  budget_trigger="yes"
fi

if [[ "$budget_trigger" == "yes" ]]; then
  if [[ -n "$budget_note" && "$budget_note" != "None." ]]; then
    check "budget note required by heavy forecast" "pass"
  else
    check "budget note required by heavy forecast" "fail" "heavy/complex round is missing a real Budget Note"
  fi
else
  check "budget note trigger" "pass"
fi

if [[ "$overload_override" == "human-approved" ]]; then
  if [[ -n "$budget_note" && "$budget_note" != "None." ]]; then
    check "overload override has rationale" "pass"
  else
    check "overload override has rationale" "fail" "human-approved override requires a non-empty Budget Note"
  fi
else
  check "overload override default" "$([[ "$overload_override" == "none" ]] && echo pass || echo fail)" "Overload Override must be none or human-approved"
fi

scope_out_lc="$(lower "$scope_out")"
if [[ "$key_entry_points" == "None." || -z "$key_entry_points" ]]; then
  if [[ "$scope_class" == "S3" || "$scope_class" == "S4" || "$risk_class" == "R3" ]]; then
    check "key entry points recommended on complex rounds" "warn" "consider listing load-bearing entry points explicitly in Round Contract"
  else
    check "key entry points optional" "pass"
  fi
else
  conflict_list=()
  while IFS= read -r raw_entry; do
    entry="$(trim "${raw_entry//\`/}")"
    [[ -z "$entry" ]] && continue
    entry_norm="$(lower "$entry")"
    base="${entry##*/}"
    stem="${base%.*}"
    base_lc="$(lower "$base")"
    stem_lc="$(lower "$stem")"
    if contains_any "$scope_out_lc" "$entry_norm" "$base_lc" "$stem_lc"; then
      conflict_list+=("$entry")
    fi
  done < <(printf '%s\n' "$key_entry_points" | tr ';' '\n')

  if [[ ${#conflict_list[@]} -gt 0 ]]; then
    check "scope out avoids key entry points" "fail" "Scope Out conflicts with: ${conflict_list[*]}"
  else
    check "scope out avoids key entry points" "pass"
  fi
fi

done_lc="$(lower "$done_criteria")"
verify_lc="$(lower "$verification_plan")"

if [[ "$done_lc" =~ (test|tests|assertion|assertions) ]] && ! [[ "$verify_lc" =~ (test|tests|assertion|assertions) ]]; then
  check "done criteria vs verification plan (tests)" "warn" "Done Criteria mentions tests but Verification Plan does not"
fi

if [[ "$done_lc" =~ (runtime|startup|health|scenario|request|response) ]] && ! [[ "$verify_lc" =~ (runtime|startup|health|scenario|request|response) ]]; then
  check "done criteria vs verification plan (runtime)" "warn" "Done Criteria mentions runtime-style proof but Verification Plan does not"
fi

if [[ "$done_lc" =~ (validator|validators|validate|validation|check-consistency|live-state|round-sync|contract) ]] && ! [[ "$verify_lc" =~ (validator|validators|validate|validation|check|check-consistency|live-state|round-sync|contract) ]]; then
  check "done criteria vs verification plan (validators)" "warn" "Done Criteria mentions validators but Verification Plan does not"
fi

if [[ -f "$REVIEW" ]]; then
  review_round="$(extract_review_round "$REVIEW")"
  if [[ "$review_round" == "$round" ]]; then
    review_addons="$(extract_review_signal "$REVIEW" "Verification Add-ons")"
    review_design_addons="$(extract_review_signal "$REVIEW" "Design Review Add-ons")"
    review_preflight_triage="$(extract_review_signal "$REVIEW" "Pre-flight Triage")"
    review_plan_quality="$(extract_review_signal "$REVIEW" "Plan Quality")"
    review_confidence_calibration="$(extract_review_signal "$REVIEW" "Confidence Calibration")"
    review_load="$(extract_review_signal "$REVIEW" "Round Load")"
    review_blocking="$(extract_review_signal "$REVIEW" "Blocking")"
    review_next_route="$(extract_review_signal "$REVIEW" "Next Route")"
    review_human_needed="$(extract_review_signal "$REVIEW" "Human Review Needed")"

    if [[ "$review_design_addons" == "none" || "$review_design_addons" == "adversarial" || "$review_design_addons" == "cross-model" || "$review_design_addons" == "adversarial,cross-model" ]]; then
      check "review design review add-ons signal" "pass"
    else
      check "review design review add-ons signal" "fail" "review Design Review Add-ons must be none, adversarial, cross-model, or adversarial,cross-model"
    fi

    if [[ "$review_preflight_triage" == "none" || "$review_preflight_triage" == "auto-revise" || "$review_preflight_triage" == "human-checkpoint" ]]; then
      check "review pre-flight triage signal" "pass"
    else
      check "review pre-flight triage signal" "fail" "review Pre-flight Triage must be none, auto-revise, or human-checkpoint"
    fi

    if [[ -n "$review_design_addons" && "$review_design_addons" != "none" ]]; then
      if [[ "$execution_mode" == "full" ]]; then
        check "design review add-ons only in full mode" "pass"
      else
        check "design review add-ons only in full mode" "fail" "Design Review Add-ons require Execution Mode = full"
      fi
    else
      check "design review add-ons only in full mode" "pass"
    fi

    if [[ -n "$review_addons" && "$review_addons" != "none" ]]; then
      if [[ "$execution_mode" == "full" ]]; then
        check "review add-ons only in full mode" "pass"
      else
        check "review add-ons only in full mode" "fail" "Verification Add-ons require Execution Mode = full"
      fi
    else
      check "review add-ons only in full mode" "pass"
    fi

    if [[ "$review_preflight_triage" == "auto-revise" ]]; then
      if [[ "$review_next_route" == "planner" && "$review_human_needed" == "no" && "$review_blocking" == "design-issue" ]]; then
        check "auto-revise triage routing" "pass"
      else
        check "auto-revise triage routing" "fail" "auto-revise triage must route planner / no human / blocking=design-issue"
      fi
    elif [[ "$review_preflight_triage" == "human-checkpoint" ]]; then
      if [[ "$review_next_route" == "human" && "$review_human_needed" == "yes" && ( "$review_blocking" == "design-issue" || "$review_blocking" == "requirement-gap" ) ]]; then
        check "human-checkpoint triage routing" "pass"
      else
        check "human-checkpoint triage routing" "fail" "human-checkpoint triage must route human / yes / blocking=design-issue or requirement-gap"
      fi
    else
      check "pre-flight triage routing" "pass"
    fi

    if [[ "$review_plan_quality" == "adequate" || "$review_plan_quality" == "under-searched" ]]; then
      check "review plan quality signal" "pass"
    else
      check "review plan quality signal" "fail" "review Plan Quality must be adequate or under-searched"
    fi

    if [[ "$review_confidence_calibration" == "calibrated" || "$review_confidence_calibration" == "overstated" || "$review_confidence_calibration" == "understated" ]]; then
      check "review confidence calibration signal" "pass"
    else
      check "review confidence calibration signal" "fail" "review Confidence Calibration must be calibrated, overstated, or understated"
    fi

    if [[ "$review_plan_quality" == "under-searched" && "$recommendation_confidence" == "high" ]]; then
      check "under-searched rounds avoid high confidence" "fail" "under-searched plan cannot still claim Recommendation Confidence = high"
    else
      check "under-searched rounds avoid high confidence" "pass"
    fi

    if [[ "$review_load" == "overloaded" ]]; then
      if [[ "$overload_override" == "human-approved" ]]; then
        if [[ "$review_blocking" == "overload" ]]; then
          check "overload override clears blocker" "fail" "review still blocks on overload despite recorded human override"
        else
          check "overload override clears blocker" "pass"
        fi
      else
        if [[ "$review_blocking" == "overload" ]]; then
          check "overloaded round blocks builder" "pass"
        else
          check "overloaded round blocks builder" "fail" "review load is overloaded but Blocking is not overload"
        fi
      fi
    elif [[ "$overload_override" == "human-approved" ]]; then
      check "stale overload override" "fail" "Overload Override is human-approved but review load is not overloaded"
    else
      check "round load / override alignment" "pass"
    fi
  else
    check "review round alignment for lint" "warn" "review.md is stale for round-contract lint; skipping review-based checks"
  fi
else
  check "review.md present for round-contract lint" "warn" "review.md not found; skipping review-based checks"
fi

echo ""
echo "Results: $PASS pass, $FAIL fail, $WARN warn"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0

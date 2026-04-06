#!/usr/bin/env bash
# validate-artifact.sh — verify a .harness/*.md artifact has all required sections
#
# Usage: validate-artifact.sh <artifact-type> <file-path>
#   artifact-type: exploration | requirements | architecture | verification | evaluation | task-status | escalation
#   file-path:     path to the artifact file to validate
#
# Exit 0: artifact passes or type is unknown (skip)
# Exit 1: artifact fails — missing required sections, or file not found
set -euo pipefail

artifact_type="${1:-}"
file_path="${2:-}"

if [[ -z "$artifact_type" || -z "$file_path" ]]; then
  printf 'Usage: validate-artifact.sh <artifact-type> <file-path>\n' >&2
  exit 1
fi

if [[ ! -f "$file_path" ]]; then
  printf 'ERROR: validate-artifact: file not found: %s\n' "$file_path" >&2
  exit 1
fi

# Skip full validation for draft artifacts. Authors can set
# **Status**: `draft` in the artifact header to allow iterative writing
# without triggering section-completeness checks during post-artifact.
#
# Safety: pre-transition hook (L94-115) independently blocks state
# transitions when the required artifact for the current state still
# carries draft/template status. So draft artifacts pass mid-phase
# writes but cannot advance the state machine.
if grep -qE '^\*\*Status\*\*.*`draft`' "$file_path" 2>/dev/null; then
  exit 0
fi

has_section() {
  local file="$1" pattern="$2"
  grep -qiE "^##[[:space:]].*(${pattern})" "$file"
}

check_sections() {
  local file="$1"
  shift
  local missing=0
  for pattern in "$@"; do
    if ! has_section "$file" "$pattern"; then
      printf 'ERROR: validate-artifact: missing section matching "%s" in %s\n' "$pattern" "$file" >&2
      missing=$((missing + 1))
    fi
  done
  return $missing
}

check_optional_overlay_recommendation() {
  local file="$1"

  if ! grep -qiE '^##[[:space:]]+Overlay Recommendation' "$file"; then
    return 0
  fi

  if ! grep -Eq '^overlay:[[:space:]]*(core|strict)[[:space:]]*$' "$file"; then
    printf 'ERROR: validate-artifact: exploration overlay recommendation must contain "overlay: core" or "overlay: strict" in %s\n' "$file" >&2
    return 1
  fi
}

# Ensure exploration §12 Historical Lessons has at least one substantive
# line (bullet, prose, or explicit-empty marker). Silent omission is the
# failure mode this check exists to prevent — see
# spec/protocol/role-contracts.md Context Isolation Note and
# skills/baton-explorer/SKILL.md Step 1b.
check_exploration_historical_lessons_populated() {
  local file="$1"
  awk '
    /^##[[:space:]]+(12\.[[:space:]]+)?Historical Lessons/ { in_section = 1; next }
    in_section && /^##[[:space:]]/ { in_section = 0 }
    in_section {
      # strip leading whitespace and blockquote markers
      line = $0
      sub(/^[[:space:]]*>?[[:space:]]*/, "", line)
      if (length(line) > 0 && line !~ /^<!--/) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$file" && return 0

  printf 'ERROR: validate-artifact: exploration §12 Historical Lessons is empty in %s — populate with at least one lesson reference or the explicit-empty marker "no relevant lessons in index" / "no lessons file found at knowledge/lessons.md"\n' "$file" >&2
  return 1
}

run_checks() {
  local rc=0
  case "$artifact_type" in
    exploration)
      check_sections "$file_path" \
        "Scope" "Entry" "Call.Chain" "Existing.Behavior" \
        "Existing.Tests" "Risk|Dependency" "Change.Shape" \
        "Recommendation|Suggested.Next" "Historical.Lessons" || rc=$?
      check_optional_overlay_recommendation "$file_path" || rc=$((rc + 1))
      check_exploration_historical_lessons_populated "$file_path" || rc=$((rc + 1))
      ;;
    requirements)
      check_sections "$file_path" \
        "Problem" "Assumptions" "Scope" "Functional.Requirements" "Non.Goals" \
        "Acceptance.Criteria" "Constraints" "Validation.Intent" || rc=$?
      ;;
    architecture)
      check_sections "$file_path" \
        "Problem.Framing" "First.Principles" "Recommended.Approach" \
        "Surface.Scan" "Verification.Strategy" "Risk" "Self.Challenge" || rc=$?
      ;;
    verification)
      check_sections "$file_path" \
        "Intended.Checks" "Commands" "Dependencies|Prerequisites" "Execution.Provenance|Isolation" \
        "Dry.Run" "Blockers" "Fallback" || rc=$?
      ;;
    evaluation)
      check_sections "$file_path" \
        "Inputs" "Execution.Provenance|Isolation.Provenance" "Findings" \
        "Verification.Results" "Verdict" "Residual.Risks" || rc=$?
      ;;
    task-status)
      check_sections "$file_path" "State.Notes" || rc=$?
      if ! grep -q "| Scope |" "$file_path"; then
        printf 'ERROR: validate-artifact: task-status missing task table in %s\n' "$file_path" >&2
        rc=$((rc + 1))
      fi
      ;;
    escalation)
      check_sections "$file_path" \
        "Original.Assumption" "Actual.Finding" \
        "Impact" "Recommended.Next.Owner" || rc=$?
      ;;
    retrospective)
      # retrospective.md is load-bearing for knowledge/lessons.md — the
      # extractor in start-task.sh parses §4 and §5 by exact heading. Any
      # rename silently breaks the cross-task lesson compounding chain.
      # Required sections must match spec/templates/retrospective.template.md.
      check_sections "$file_path" \
        "Outcome" "What.Worked" "What.Failed" \
        "Repo.Specific Lessons" "Harness Lessons" "Standardization Candidates" || rc=$?
      ;;
    decisions)
      check_sections "$file_path" \
        "D[0-9]+:" || rc=$?
      local decisions_fields=("Choice" "Rejected.Alternatives" "Why" "Why.Not" "Impact")
      for field_pattern in "${decisions_fields[@]}"; do
        if ! grep -qiE "^-[[:space:]]*(${field_pattern}):" "$file_path"; then
          printf 'ERROR: validate-artifact: decisions.md missing required field matching "%s" in %s\n' "$field_pattern" "$file_path" >&2
          rc=$((rc + 1))
        fi
      done
      ;;
    codebase-map)
      check_sections "$file_path" \
        "Project.Structure" "Module.Dependencies" \
        "Data.Model" "Code.Style" \
        "High.Risk" || rc=$?
      ;;
    *)
      return 0
      ;;
  esac
  return $rc
}

if ! run_checks; then
  exit 1
fi

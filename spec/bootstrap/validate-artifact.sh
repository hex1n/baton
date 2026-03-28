#!/usr/bin/env bash
# validate-artifact.sh — verify a .harness/*.md artifact has all required sections
#
# Usage: validate-artifact.sh <artifact-type> <file-path>
#   artifact-type: scoped-map | requirements | architecture | verification-path | module-status
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

has_section() {
  local file="$1" pattern="$2"
  grep -qiE "^##[[:space:]].*${pattern}" "$file"
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

run_checks() {
  local rc=0
  case "$artifact_type" in
    scoped-map)
      check_sections "$file_path" \
        "Scope" "Entry" "Call.Chain" "Existing.Behavior" \
        "Existing.Tests" "Risk" "Change.Shape" "Recommendation" || rc=$?
      ;;
    requirements)
      check_sections "$file_path" \
        "Problem" "Scope" "Functional.Requirements" "Non.Goals" \
        "Acceptance.Criteria" "Constraints" "Validation.Intent" || rc=$?
      ;;
    architecture)
      check_sections "$file_path" \
        "Problem.Framing" "First.Principles" "Recommended.Approach" \
        "Surface.Scan" "Verification.Strategy" "Risk" "Self.Challenge" || rc=$?
      ;;
    verification-path)
      check_sections "$file_path" \
        "Intended.Checks" "Commands" "Dependencies" \
        "Dry.Run" "Blockers" "Fallback" || rc=$?
      ;;
    module-status)
      check_sections "$file_path" "State.Notes" || rc=$?
      if ! grep -q "| Scope |" "$file_path"; then
        printf 'ERROR: validate-artifact: module-status missing task table in %s\n' "$file_path" >&2
        rc=$((rc + 1))
      fi
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

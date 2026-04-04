#!/usr/bin/env bash
# validate-artifact.sh — verify a .harness/*.md artifact has all required sections
#
# Usage: validate-artifact.sh <artifact-type> <file-path>
#   artifact-type: scoped-map | requirements | architecture | verification-path | evaluation | task-status | generator-feedback
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

check_optional_overlay_recommendation() {
  local file="$1"

  if ! grep -qiE '^##[[:space:]]+Overlay Recommendation' "$file"; then
    return 0
  fi

  if ! grep -Eq '^overlay:[[:space:]]*(core|strict)[[:space:]]*$' "$file"; then
    printf 'ERROR: validate-artifact: scoped-map overlay recommendation must contain "overlay: core" or "overlay: strict" in %s\n' "$file" >&2
    return 1
  fi
}

run_checks() {
  local rc=0
  case "$artifact_type" in
    scoped-map)
      check_sections "$file_path" \
        "Scope|范围" "Entry|入口" "Call.Chain|调用链" "Existing.Behavior|现有行为" \
        "Existing.Tests|现有测试" "Risk|Dependency|风险" "Change.Shape|变更形态" \
        "Recommendation|Suggested.Next|建议" || rc=$?
      check_optional_overlay_recommendation "$file_path" || rc=$((rc + 1))
      ;;
    requirements)
      check_sections "$file_path" \
        "Problem|问题" "Scope|范围" "Functional.Requirements|功能需求" "Non.Goals|非目标" \
        "Acceptance.Criteria|验收标准" "Constraints|约束" "Validation.Intent|验证意图" || rc=$?
      ;;
    architecture)
      check_sections "$file_path" \
        "Problem.Framing|问题" "First.Principles|第一性原理" "Recommended.Approach|推荐架构" \
        "Surface.Scan|影响面扫描" "Verification.Strategy|验证策略" "Risk|风险" "Self.Challenge|自我质疑" || rc=$?
      ;;
    verification-path)
      check_sections "$file_path" \
        "Intended.Checks|计划检查项" "Commands|精确命令" "Dependencies|Prerequisites|前置条件" "Execution.Provenance|Isolation" \
        "Dry.Run" "Blockers|阻塞项" "Fallback|回退方案" || rc=$?
      ;;
    evaluation)
      check_sections "$file_path" \
        "Inputs|输入" "Execution.Provenance|Isolation.Provenance" "Findings|发现" \
        "Verification.Results" "Verdict" "Residual.Risks" || rc=$?
      ;;
    task-status)
      check_sections "$file_path" "State.Notes" || rc=$?
      if ! grep -q "| Scope |" "$file_path"; then
        printf 'ERROR: validate-artifact: task-status missing task table in %s\n' "$file_path" >&2
        rc=$((rc + 1))
      fi
      ;;
    generator-feedback)
      check_sections "$file_path" \
        "Original.Assumption|原始假设" "Actual.Finding|实际发现" \
        "Impact|影响" "Recommended.Next.Owner|建议下一步负责方" || rc=$?
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

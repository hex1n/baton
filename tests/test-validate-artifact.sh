#!/usr/bin/env bash
# Tests for validate-artifact.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../spec/bootstrap/validate-artifact.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# -- scoped-map: complete artifact passes --
cat > "$tmp/scoped-map.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
## 3. Call Chain
content
## 4. Existing Behavior
content
## 5. Existing Tests
content
## 6. Dependency / Risk Scan
content
## 7. Change Shape
content
## 9. Recommendation
content
EOF
assert_exit "scoped-map complete -> exit 0" 0 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map.md"

# -- scoped-map: missing section fails --
cat > "$tmp/scoped-map-bad.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
EOF
assert_exit "scoped-map missing sections -> exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map-bad.md"

# -- requirements: complete passes --
cat > "$tmp/requirements.md" <<'EOF'
# Requirements: test-task
## 1. Problem
content
## 2. Assumptions
content
## 3. Scope
content
## 4. Functional Requirements
content
## 5. Non-Goals
content
## 6. Acceptance Criteria
content
## 7. Constraints
content
## 8. Validation Intent
content
EOF
assert_exit "requirements complete -> exit 0" 0 bash "$VALIDATE" "requirements" "$tmp/requirements.md"

# -- requirements: missing Assumptions -> exit 1 --
cat > "$tmp/requirements-no-assumptions.md" <<'EOF'
# Requirements: test-task
## 1. Problem
content
## 2. Scope
content
## 3. Functional Requirements
content
## 4. Non-Goals
content
## 5. Acceptance Criteria
content
## 6. Constraints
content
## 7. Validation Intent
content
EOF
assert_exit "requirements missing Assumptions -> exit 1" 1 bash "$VALIDATE" "requirements" "$tmp/requirements-no-assumptions.md"

# -- verification-path: complete passes with isolation plan --
cat > "$tmp/verification-path.md" <<'EOF'
# Verification Path: test-task
## 1. Intended Checks
content
## 2. Exact Commands
content
## 3. Prerequisites
content
## 4. Execution Provenance
content
## 5. Dry-Run Result
content
## 6. Blockers
content
## 7. Fallbacks
content
EOF
assert_exit "verification-path complete -> exit 0" 0 bash "$VALIDATE" "verification-path" "$tmp/verification-path.md"

# -- evaluation: complete passes --
cat > "$tmp/evaluation.md" <<'EOF'
# Evaluation: test-task
## 1. Inputs
content
## 2. Execution Provenance
content
## 3. Findings
content
## 4. Verification Results
content
## 5. Verdict
content
## 6. Residual Risks
content
EOF
assert_exit "evaluation complete -> exit 0" 0 bash "$VALIDATE" "evaluation" "$tmp/evaluation.md"

# -- chinese evaluation headings also pass --
cat > "$tmp/evaluation-zh.md" <<'EOF'
# Evaluation: test-task
## 1. 输入
content
## 2. Execution Provenance
content
## 3. 发现
content
## 4. Verification Results
content
## 5. Verdict
content
## 6. Residual Risks
content
EOF
assert_exit "evaluation zh headings -> exit 0" 0 bash "$VALIDATE" "evaluation" "$tmp/evaluation-zh.md"

# -- generator-feedback: complete passes in English --
cat > "$tmp/generator-feedback.md" <<'EOF'
# Generator Feedback: test-task
## 1. Original Assumption
content
## 2. Actual Finding
content
## 3. Impact
content
## 4. Recommended Next Owner
content
EOF
assert_exit "generator-feedback complete -> exit 0" 0 bash "$VALIDATE" "generator-feedback" "$tmp/generator-feedback.md"

# -- generator-feedback: complete passes in Chinese --
cat > "$tmp/generator-feedback-zh.md" <<'EOF'
# Generator Feedback: test-task
## 1. 原始假设
content
## 2. 实际发现
content
## 3. 影响
content
## 4. 建议下一步负责方
content
EOF
assert_exit "generator-feedback zh headings -> exit 0" 0 bash "$VALIDATE" "generator-feedback" "$tmp/generator-feedback-zh.md"

# -- generator-feedback: missing section fails --
cat > "$tmp/generator-feedback-bad.md" <<'EOF'
# Generator Feedback: test-task
## 1. Original Assumption
content
## 2. Actual Finding
content
EOF
assert_exit "generator-feedback missing sections -> exit 1" 1 bash "$VALIDATE" "generator-feedback" "$tmp/generator-feedback-bad.md"

# -- chinese verification-path headings also pass --
cat > "$tmp/verification-path-zh.md" <<'EOF'
# Verification Path: test-task
## 1. 计划检查项
content
## 2. 精确命令
content
## 3. 前置条件
content
## 4. Execution Provenance
content
## 5. Dry-Run 结果
content
## 6. 阻塞项
content
## 7. 回退方案
content
EOF
assert_exit "verification-path zh headings -> exit 0" 0 bash "$VALIDATE" "verification-path" "$tmp/verification-path-zh.md"

# -- decisions: complete passes in English --
cat > "$tmp/decisions.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `approved`

## D1: Test Decision

- Choice: Option A
- Rejected Alternatives: Option B
- Why: Better performance
- Why Not: More complex
- Impact: Moderate
EOF
assert_exit "decisions complete -> exit 0" 0 bash "$VALIDATE" "decisions" "$tmp/decisions.md"

# -- decisions: complete passes in Chinese --
cat > "$tmp/decisions-zh.md" <<'EOF'
# 技术决策

**Owner**: `architect`
**状态**: `approved`

## D1: 测试决策

- 选择: 方案 A
- 被拒方案: 方案 B
- 为什么: 性能更好
- 为什么不: 更复杂
- 影响: 中等
EOF
assert_exit "decisions zh headings -> exit 0" 0 bash "$VALIDATE" "decisions" "$tmp/decisions-zh.md"

# -- decisions: missing D<N> heading fails --
cat > "$tmp/decisions-bad.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `approved`

## Some heading without D pattern
content only
EOF
assert_exit "decisions missing D heading -> exit 1" 1 bash "$VALIDATE" "decisions" "$tmp/decisions-bad.md"

# -- decisions: missing required fields fails --
cat > "$tmp/decisions-missing-fields.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `approved`

## D1: Partial Decision

- Choice: Option A
- Why: Performance
EOF
assert_exit "decisions missing fields -> exit 1" 1 bash "$VALIDATE" "decisions" "$tmp/decisions-missing-fields.md"

# -- decisions: draft skips validation --
cat > "$tmp/decisions-draft.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `draft`
EOF
assert_exit "decisions draft -> exit 0 (skip)" 0 bash "$VALIDATE" "decisions" "$tmp/decisions-draft.md"

# -- codebase-map: complete passes in English --
cat > "$tmp/codebase-map.md" <<'EOF'
# Codebase Map

**Owner**: `explorer`
**Status**: `approved`

## Project Structure
content

## Module Dependencies
content

## Data Model
content

## Code Style And Conventions
content

## High-Risk Areas
content
EOF
assert_exit "codebase-map complete -> exit 0" 0 bash "$VALIDATE" "codebase-map" "$tmp/codebase-map.md"

# -- codebase-map: complete passes in Chinese --
cat > "$tmp/codebase-map-zh.md" <<'EOF'
# 代码地图

**Owner**: `explorer`
**状态**: `approved`

## 项目结构
content

## 模块依赖
content

## 数据模型
content

## 代码风格与约定
content

## 高风险区域
content
EOF
assert_exit "codebase-map zh headings -> exit 0" 0 bash "$VALIDATE" "codebase-map" "$tmp/codebase-map-zh.md"

# -- codebase-map: missing section fails --
cat > "$tmp/codebase-map-bad.md" <<'EOF'
# Codebase Map

**Owner**: `explorer`
**Status**: `approved`

## Project Structure
content
EOF
assert_exit "codebase-map missing sections -> exit 1" 1 bash "$VALIDATE" "codebase-map" "$tmp/codebase-map-bad.md"

# -- unknown artifact type -> exit 0 (skip, not error) --
assert_exit "unknown artifact type -> exit 0 (skip)" 0 bash "$VALIDATE" "unknown-type" "$tmp/requirements.md"

# -- file not found -> exit 1 --
assert_exit "missing file -> exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/nonexistent.md"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

# 验证路径：promote-java-artifacts

**Owner**: `verification-explorer`  
**Status**: `approved`

## 1. 计划检查项

| 需求 | 验证内容 | 验证类型 |
|------|---------|---------|
| R1 | `artifact-schema.md` 包含 `decisions.md` 和 `codebase-map.md` 条目 | manual |
| R2 | 4 个新模板文件存在且结构正确 | manual + unit |
| R3 | `validate-artifact.sh decisions/codebase-map` 对完整文件 pass，缺失 section 文件 fail | unit |
| R4 | 新旧格式 `evaluation.md` 均通过验证（向后兼容） | unit |
| R5 | evaluator skill 文档三层对齐 | manual |
| R6 | architect skill 文档 Decision Records 更新 | manual |
| R7 | explorer skill 文档 Mode 1 产出更新 | manual |
| R8 | orchestrator skill Risk-Adaptive Matrix 更新 | manual |
| R9 | `check-consistency.sh` invariant 17 + 18 通过 | e2e |
| R10 | `start-task.sh` 分发 `decisions.md` 和 `codebase-map.md` 模板 | integration |
| R11 | Java 扩展标注已提升制品 | manual |
| R12 | 新测试用例通过 | unit |
| R13 | `link-skills.sh` 同步后 invariant 4 通过 | e2e |

## 2. 精确命令

按执行顺序排列。命令间无冲突，但 Unit 2 依赖 Unit 1 的文件存在。

### 命令 1: validate-artifact.sh decisions 类型 -- 完整文件通过

```bash
tmp="$(mktemp -d)"
cat > "$tmp/decisions-good.md" <<'EOF'
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
bash spec/bootstrap/commands/validate-artifact.sh decisions "$tmp/decisions-good.md"
# 期望: exit 0
```

### 命令 2: validate-artifact.sh decisions 类型 -- 缺失字段失败

```bash
tmp="$(mktemp -d)"
cat > "$tmp/decisions-bad.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `approved`

## Some heading without D pattern
content only
EOF
bash spec/bootstrap/commands/validate-artifact.sh decisions "$tmp/decisions-bad.md"
# 期望: exit 1 (missing D<N>: heading and required fields)
```

### 命令 3: validate-artifact.sh codebase-map 类型 -- 完整文件通过

```bash
tmp="$(mktemp -d)"
cat > "$tmp/codebase-map-good.md" <<'EOF'
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
bash spec/bootstrap/commands/validate-artifact.sh codebase-map "$tmp/codebase-map-good.md"
# 期望: exit 0
```

### 命令 4: validate-artifact.sh codebase-map 类型 -- 缺失 section 失败

```bash
tmp="$(mktemp -d)"
cat > "$tmp/codebase-map-bad.md" <<'EOF'
# Codebase Map

**Owner**: `explorer`
**Status**: `approved`

## Project Structure
content
EOF
bash spec/bootstrap/commands/validate-artifact.sh codebase-map "$tmp/codebase-map-bad.md"
# 期望: exit 1 (missing Module Dependencies, Data Model, Code Style, High-Risk)
```

### 命令 5: validate-artifact.sh evaluation -- 旧格式向后兼容

```bash
tmp="$(mktemp -d)"
cat > "$tmp/eval-old.md" <<'EOF'
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
bash spec/bootstrap/commands/validate-artifact.sh evaluation "$tmp/eval-old.md"
# 期望: exit 0
```

### 命令 6: validate-artifact.sh evaluation -- 新格式（三层子结构）通过

```bash
tmp="$(mktemp -d)"
cat > "$tmp/eval-new.md" <<'EOF'
# Evaluation: test-task

## 1. Inputs
content
## 2. Execution Provenance
content
## 3. Findings
### Layer 1: Deterministic Checks
- pass
### Layer 2: Diff Review
- ok
### Layer 3: Requirements Verification
- met
## 4. Verification Results
### Layer 1 Commands
- Command: bash test
### Layer 2/3 Evidence
- ok
## 5. Verdict
pass
## 6. Residual Risks
none
EOF
bash spec/bootstrap/commands/validate-artifact.sh evaluation "$tmp/eval-new.md"
# 期望: exit 0
```

### 命令 7: draft 状态跳过验证

```bash
tmp="$(mktemp -d)"
cat > "$tmp/decisions-draft.md" <<'EOF'
# Technical Decisions

**Owner**: `architect`
**Status**: `draft`
EOF
bash spec/bootstrap/commands/validate-artifact.sh decisions "$tmp/decisions-draft.md"
# 期望: exit 0 (draft skip)
```

### 命令 8: test-validate-artifact.sh 全量运行

```bash
bash tests/test-validate-artifact.sh
# 期望: 所有测试通过（包括新增的 decisions 和 codebase-map 用例）
```

### 命令 9: test-start-task.sh 全量运行

```bash
bash tests/test-start-task.sh
# 期望: 所有测试通过（包括新增的模板分发验证用例）
```

### 命令 10: check-consistency.sh 全量运行

```bash
bash spec/bootstrap/commands/check-consistency.sh .
# 期望: invariant 1-16 + 17 + 18 全部 OK
# 注意: invariant 7 有预存在的 link_fork_dir 缺陷（relative_link_target 函数未定义），
#       这是 link-skills.sh 中 .claude/agents/ 路径计算的已知 bug，不由本任务引入。
#       如果 invariant 7 报错，属于预存在问题，不阻塞本任务验证。
```

### 命令 11: link-skills.sh 同步

```bash
bash spec/bootstrap/link-skills.sh --repo-root .
# 期望: .claude/skills/ 和 .agents/ 同步完成
# 注意: .claude/agents/ 同步可能因 relative_link_target bug 产生错误输出，属于预存在问题
```

## 3. 前置条件

### 工具和版本

- bash 3.2+ (macOS 自带)
- grep (BSD 版本，macOS 自带)
- mktemp, sed, tr (macOS 自带)
- jq (check-consistency.sh invariant 16 需要)

### 验证 jq 是否可用

```bash
jq --version
# 已确认: jq-1.7.1 (macOS 已安装)
```

### 依赖解析

- 项目无编译步骤，所有验证通过 bash 脚本完成
- 测试使用 `mktemp -d` 创建临时目录，无需外部 fixture

### 需要 Generator 创建的文件

以下 4 个新文件必须在验证命令运行前创建：

1. `spec/templates/decisions.template.md` -- 英文 decisions 模板
2. `spec/templates/zh/decisions.template.md` -- 中文 decisions 模板
3. `spec/templates/codebase-map.template.md` -- 英文 codebase-map 模板
4. `spec/templates/zh/codebase-map.template.md` -- 中文 codebase-map 模板

模板必须包含 `**Status**: \`draft\`` 以便分发后未使用时跳过验证。

### 需要 Generator 修改的文件

- `spec/bootstrap/commands/validate-artifact.sh` -- 新增 `decisions)` 和 `codebase-map)` case
- `spec/bootstrap/commands/check-consistency.sh` -- 新增 invariant 17 + 18
- `spec/bootstrap/commands/start-task.sh` -- `artifact_templates` 数组扩展
- `tests/test-validate-artifact.sh` -- 新增测试用例
- `tests/test-start-task.sh` -- 新增分发验证用例
- 其余 10 个 skill/protocol/extension 文件的文档修改

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: baton-verifier (Agent tool dispatch with subagent_type isolation)
- Evidence: Cold-read `.harness/requirements.md`, `.harness/architecture.md`, `.harness/task-status.md`; dry-ran all primary validation commands against current codebase; verified existing test baselines (test-validate-artifact: 12/12, test-start-task: 6/6, check-consistency: 13/16 invariants OK with 3 pre-existing invariant-7 errors); no inherited reasoning from prior roles
- Fallback policy: N/A
- Fallback reason: N/A

## 5. Dry-Run 结果

### test-validate-artifact.sh (基线)

```
  pass: scoped-map complete -> exit 0
  pass: scoped-map missing sections -> exit 1
  pass: requirements complete -> exit 0
  pass: verification-path complete -> exit 0
  pass: evaluation complete -> exit 0
  pass: evaluation zh headings -> exit 0
  pass: generator-feedback complete -> exit 0
  pass: generator-feedback zh headings -> exit 0
  pass: generator-feedback missing sections -> exit 1
  pass: verification-path zh headings -> exit 0
  pass: unknown artifact type -> exit 0 (skip)
  pass: missing file -> exit 1

Results: 12 passed, 0 failed of 12 total
```

状态: 测试基础设施正常，Generator 添加新用例后应继续通过。

### test-start-task.sh (基线)

```
  pass: start-task handles legacy task-status
  pass: task-status migrated to current header
  pass: legacy row preserved with eval round 0
  pass: new row appended
  pass: previous artifacts archived
  pass: evaluation artifact reset from template

Results: 6 passed, 0 failed of 6 total
```

状态: 测试基础设施正常，Generator 添加新用例后应继续通过。

### check-consistency.sh (基线)

```
OK: invariant-1 through invariant-6
ERROR: invariant-7: baton-evaluator/SKILL.md missing from .claude/agents/
ERROR: invariant-7: baton-explorer/SKILL.md missing from .claude/agents/
ERROR: invariant-7: baton-verifier/SKILL.md missing from .claude/agents/
OK: invariant-8 through invariant-16
3 error(s) found
```

状态: 3 个 invariant-7 错误是预存在问题（`link-skills.sh` 中 `link_fork_dir` 函数第 187 行使用了未定义的 `relative_link_target` 而非 `paths_relpath_from`），不由本任务引入，不阻塞验证。Generator 添加 invariant 17+18 后，这些新 invariant 应该独立通过。

### validate-artifact.sh 对新类型的当前行为

- `validate-artifact.sh decisions <file>` -- 当前返回 exit 0（unknown type skip）
- `validate-artifact.sh codebase-map <file>` -- 当前返回 exit 0（unknown type skip）
- Generator 添加 case 分支后，将对 section 进行实际验证

### evaluation.md 向后兼容验证

- 旧格式（无三层子结构）: exit 0 -- 通过
- 新格式（含 `###` 三层子结构）: exit 0 -- 通过
- 原因: `has_section()` 使用 `^##[[:space:]]` 只匹配 `##` 级别，`###` 不会干扰

### draft 状态跳过验证

- draft 状态 `decisions.md`: exit 0 -- 通过（第 33-35 行 draft 跳过逻辑）

## 6. 阻塞项

### 预存在问题（不阻塞）

- **invariant-7 错误**: `link-skills.sh` 的 `link_fork_dir` 函数在第 187 行调用 `relative_link_target`（未定义函数），应为 `paths_relpath_from`。导致 `.claude/agents/` 下的 symlink 指向 `.` 而非正确路径。此为预存在 bug，不由本任务引入，不影响本任务验证（invariant 17/18 不检查 `.claude/agents/`）。

### 本任务无新增阻塞

- 验证管线（validate-artifact.sh + check-consistency.sh + start-task.sh）测试基础设施正常
- 所有 21 个目标文件均可访问
- 4 个新模板的目标目录存在
- 2 个待删除的 Java 扩展模板文件存在

## 7. 回退方案

### 主路径失败时的回退

| 主路径 | 回退方案 |
|--------|---------|
| `test-validate-artifact.sh` 新用例失败 | 单独运行 `validate-artifact.sh decisions/codebase-map` 手动验证 |
| `test-start-task.sh` 新用例失败 | 手动运行 `start-task.sh --dry-run` 检查 plan 输出 |
| `check-consistency.sh` invariant 17/18 失败 | 逐项手动检查 schema/validator/template/skill 一致性 |
| `link-skills.sh` 失败 | 手动比对 `skills/` 与 `.claude/skills/` 和 `.agents/` 内容 |

### 无回退的情况

- 如果 `validate-artifact.sh` 的 `has_section()` 函数本身被破坏，则无法验证任何制品类型。但 dry-run 已确认该函数正常工作。

# 架构：promote-java-artifacts

**Owner**: `architect`  
**状态**: `proposed`

## 1. 问题

需要将 Java 扩展中的 3 类制品提升到核心协议：
1. `decisions.md` 和 `codebase-map.md` 作为条件必需制品
2. 三层评估结构合并进核心 `evaluation.md` 模板

核心挑战：在保持核心协议的通用性和向后兼容的前提下，将扩展中验证过的高价值结构提升为核心能力。已有 `generator-feedback.md` 提升的直接先例（commit `2c6f6ee`）可作为实现模板。

## 2. 第一性原理拆解

### 2.1 子问题分解

本任务可拆分为 4 个独立子问题：

**SP1: 制品定义与模板** — 在 `artifact-schema.md` 新增条件必需制品定义，创建通用模板（en+zh）  
**SP2: 验证管线** — `validate-artifact.sh` 新增类型，`check-consistency.sh` 新增 invariant  
**SP3: 评估模板三层化** — `evaluation.template.md` 嵌入三层子结构，evaluator skill 对齐  
**SP4: Skill 与扩展同步** — architect/explorer/orchestrator skill 更新，Java 扩展标注

依赖关系：SP1 → SP2, SP1 → SP4, SP3 独立, SP4 依赖 SP3 完成后标注评估部分

### 2.2 约束

- 遵循 `generator-feedback.md` 提升先例的实现模式
- 双语模板（en + zh）
- `validate-artifact.sh` 的 `has_section()` 用 `grep -qiE "^##[[:space:]].*${pattern}"` 匹配 — 只匹配 `##` 级别标题
- `evaluation.md` 验证只检查顶层 6 section（`Inputs|输入`, `Execution.Provenance`, `Findings|发现`, `Verification.Results`, `Verdict`, `Residual.Risks`），三层子结构用 `###` 级别嵌入，不会干扰现有验证
- 新 invariant 编号从 17 开始
- draft 状态制品跳过验证（`validate-artifact.sh` L33-35）

### 2.3 方案比较

**方案 A: 独立 invariant** — 为 `decisions.md` 和 `codebase-map.md` 各创建独立 invariant（invariant 17 + invariant 18），类似 invariant 14 对 `generator-feedback.md` 的处理

**方案 B: 合并 invariant** — 创建一个通用 invariant 17，覆盖所有已提升制品（decisions + codebase-map），减少代码重复

### 2.4 评估

选择**方案 A**（独立 invariant）：
- **为什么 A 胜出**: 每个制品的验证逻辑独立，invariant 14 已建立的模式是每种制品一个 invariant，保持一致性；独立 invariant 在失败时提供更精确的错误定位
- **为什么拒绝 B**: 合并 invariant 内部分支较多，调试时不如独立 invariant 直观；与 invariant 14 的先例不一致

## 3. 推荐架构

### 3.1 `decisions.md` 制品定义

**artifact-schema.md 条目**:
```markdown
### `decisions.md`

- **Required when**: `architecture.md` contains at least one rejected alternative
- Writer: Architect
- Readers: Generator, Evaluator, Human
- Purpose: record architectural decisions with rationale (chosen, rejected, why, why not)
- Required sections:
  - at least one decision block (D1, D2, ...)
  - each block: choice, rejected alternatives, why, why not, impact
```

**核心模板结构** (`decisions.template.md`):
```markdown
# Technical Decisions

**Owner**: `architect`
**Status**: `draft`

## D1: <decision title>

- Choice:
- Rejected Alternatives:
- Why:
- Why Not:
- Impact:
```

**validate-artifact.sh section 匹配**:
```bash
decisions)
  check_sections "$file_path" \
    "D[0-9]+:" || rc=$?
  # Additional field check: at least one decision block must have content fields
  if ! grep -qiE '^-[[:space:]]*(Choice|选择|Why|为什么|Impact|影响):' "$file_path"; then
    printf 'ERROR: validate-artifact: decisions.md missing required fields (Choice/Why/Impact) in %s\n' "$file_path" >&2
    rc=$((rc + 1))
  fi
  ;;
```

设计决策：`decisions.md` 的验证分两层——(1) `check_sections` 检查至少一个 `## D<N>:` heading 存在，(2) 自定义 `grep` 检查至少一个 `Choice/Why/Impact` 字段存在（bullet 级别）。这比纯 heading 检查更严格，类似 `task-status` case 中 `| Scope |` 的自定义检查。

### 3.2 `codebase-map.md` 制品定义

**artifact-schema.md 条目**:
```markdown
### `codebase-map.md`

- **Required when**: Explorer runs in repo-wide mode (first adoption on existing codebase)
- Writer: Explorer
- Readers: all roles
- Purpose: structured understanding of the existing codebase for informed task scoping
- Required sections:
  - project structure
  - module dependencies
  - data model
  - code style and conventions
  - high-risk areas
```

**核心模板结构** (`codebase-map.template.md`):
```markdown
# Codebase Map

**Owner**: `explorer`
**Status**: `draft`

## Project Structure

- Build tool:
- Language version:
- Framework:
- Data access stack:

## Module Dependencies

| Module | Depends On | Notes |
|--------|------------|-------|

## Existing API Surfaces

| Path Or Interface | Layer | Notes |
|-------------------|-------|-------|

## Data Model

| Table Or Aggregate | Key Fields | Notes |
|--------------------|------------|-------|

## Framework/Runtime Notes

- Profiles:
- Interceptors / filters:
- Async / scheduling:
- Caching:

## Code Style And Conventions

- Package layout:
- Exception handling:
- Logging style:

## High-Risk Areas

- Risk 1:
- Risk 2:
```

泛化设计：从 Java 扩展模板移除 "Spring Runtime Notes" → "Framework/Runtime Notes"，移除 "Java version" → "Language version"。`Existing API Surfaces` 和 `Framework/Runtime Notes` 作为可选 section，不在 validate-artifact.sh 中检查。

**validate-artifact.sh section 匹配**:
```bash
codebase-map)
  check_sections "$file_path" \
    "Project.Structure|项目结构" "Module.Dependencies|模块依赖" \
    "Data.Model|数据模型" "Code.Style|代码风格" \
    "High.Risk|高风险" || rc=$?
  ;;
```

### 3.3 三层评估结构嵌入

**现有 evaluation.template.md 结构** (6 section):
```
## 1. Inputs
## 2. Execution Provenance
## 3. Findings
## 4. Verification Results
## 5. Verdict
## 6. Residual Risks
```

**新结构** — 三层跨 Findings 和 Verification Results 两个 section：
```
## 1. Inputs
## 2. Execution Provenance
## 3. Findings

### Layer 1: Deterministic Checks
- (compile result, test result, pass/fail summary)

### Layer 2: Diff Review
- (scope validation, architecture conformance, security, pattern consistency)

### Layer 3: Requirements Verification
- (per-AC checklist: met/not met/cannot determine)

## 4. Verification Results

### Layer 1 Commands
- Command:
- Result:
- Notes:

### Layer 2/3 Evidence
- Diff command:
- Key observations:

## 5. Verdict
## 6. Residual Risks
```

三层映射到两个 section 的逻辑：
- `## 3. Findings` 包含三层的**判断结果**（pass/fail、发现、AC 状态）
- `## 4. Verification Results` 包含三层的**执行证据**（命令、输出、diff）
- Layer 1 的命令和输出记录在 Verification Results，Layer 1 的 pass/fail 判断记录在 Findings
- Layer 2/3 的 diff 命令和关键证据记录在 Verification Results，审查判断记录在 Findings

关键设计决策：
- 三层子结构用 `###` 嵌入，不改变 `##` 级别的 6 section 编号
- `validate-artifact.sh` 的 `evaluation` case 不变（它只检查 `##` 级别），旧格式自动向后兼容
- Layer 2 在核心为 "Diff Review"，Java 扩展可替换为 "Runtime Signals"
- evaluator skill 已有 Layer 1/2/3 结构，只需对齐措辞并添加扩展替换 Layer 2 的说明

### 3.4 start-task.sh 分发

在 `artifact_templates` 数组中新增两行：
```bash
artifact_templates=(
  "scoped-map.template.md:scoped-map.md"
  "requirements.template.md:requirements.md"
  "architecture.template.md:architecture.md"
  "verification-path.template.md:verification-path.md"
  "evaluation.template.md:evaluation.md"
  "retrospective.template.md:retrospective.md"
  "decisions.template.md:decisions.md"
  "codebase-map.template.md:codebase-map.md"
)
```

模板包含 `**Status**: \`draft\``，未使用时跳过验证。

### 3.4b 条件必需制品的执行模型

**关键设计决策**：`decisions.md` 和 `codebase-map.md` 的 "条件必需" 与 `generator-feedback.md` 采用相同的执行模型——**skill 层引导 + post-artifact 验证，不进入 state-requirements.sh**。

原因：
- `state-requirements.sh` 管理的是**状态转换必需**的制品（如 `evaluation.md` 在 `ready_for_human_close` 状态必需）
- 条件必需制品的触发条件是**语义判断**（"架构包含被拒方案"、"Explorer 执行 repo-wide 模式"），无法在 shell 脚本中自动检测
- 执行层保障：skill 文档明确指引 Architect/Explorer 在条件满足时产出制品；post-artifact hook 在制品写入时验证 section 完整性；check-consistency.sh invariant 确保 schema-模板-验证-skill 四方一致
- 这与 `generator-feedback.md` 的先例完全一致——它也是条件必需但不在 `state-requirements.sh` 中

### 3.5 check-consistency.sh invariant 设计

**Invariant 17**: `decisions.md` 制品提升一致性
- `artifact-schema.md` 包含 `### \`decisions.md\`` 条目
- `validate-artifact.sh` 包含 `decisions)` case
- `spec/templates/decisions.template.md` 和 `spec/templates/zh/decisions.template.md` 存在
- en 模板包含 `## D1:` heading
- zh 模板包含 `## D1:` heading
- Java 扩展旧模板 `spec/extensions/java-backend-strict/templates/decisions.template.md` 不再存在
- `baton-architect/SKILL.md` 包含 `decisions.md` 引用

**Invariant 18**: `codebase-map.md` 制品提升一致性
- `artifact-schema.md` 包含 `### \`codebase-map.md\`` 条目
- `validate-artifact.sh` 包含 `codebase-map)` case
- `spec/templates/codebase-map.template.md` 和 `spec/templates/zh/codebase-map.template.md` 存在
- en 模板包含 `## Project Structure` heading
- zh 模板包含 `## 项目结构` heading
- Java 扩展旧模板 `spec/extensions/java-backend-strict/templates/codebase-map.template.md` 不再存在
- `baton-explorer/SKILL.md` 包含 `codebase-map.md` 引用

### 3.6 role-contracts.md 同步

`spec/protocol/role-contracts.md` 是角色产出的权威定义。需要同步更新：

- **Repo Explorer**: `Typical artifact` 从 `optional \`repo-map.md\`` 改为 `conditionally required \`codebase-map.md\` (when repo-wide mode triggers); optional \`repo-map.md\` (legacy)`
- **Architect**: 在 `Outputs` 中添加 `decisions.md (when architecture contains rejected alternatives)`

### 3.7 Skill 更新汇总

| Skill | 变更 | 复杂度 |
|-------|------|--------|
| baton-evaluator | Layer 1/2/3 措辞对齐新模板；添加扩展替换 Layer 2 说明 | moderate |
| baton-architect | Decision Records 改为：有被拒方案时产出 `decisions.md`，否则 inline | trivial |
| baton-explorer | Mode 1 产出从 `repo-map.md` (optional) 改为 `codebase-map.md` (conditionally required)；添加共存规则 | trivial |
| baton-orchestrator | Risk-Adaptive Matrix Phase 2/4 行添加条件产出说明 | trivial |

### 3.8 Java 扩展标注

**artifact-overlay.md**: 标注 `decisions.md` 和 `codebase-map.md` 已提升到核心，删除扩展中的模板文件（但保留 `api-contract.yaml`、`evaluation-report.md`、`runtime-signals/` 相关模板）

**runtime-evaluator.md**: 添加说明三层结构已提升到核心，Java 扩展通过替换 Layer 2（用 Runtime Signals 替换 Diff Review）来适配

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|------|------|---------|------|
| `spec/protocol/artifact-schema.md` | L1 | modify | 新增 decisions.md + codebase-map.md 条目 |
| `spec/protocol/role-contracts.md` | L1 | modify | Explorer + Architect 产出更新 |
| `spec/templates/decisions.template.md` | L1 | add | 新建英文模板 |
| `spec/templates/zh/decisions.template.md` | L1 | add | 新建中文模板 |
| `spec/templates/codebase-map.template.md` | L1 | add | 新建英文模板 |
| `spec/templates/zh/codebase-map.template.md` | L1 | add | 新建中文模板 |
| `spec/templates/evaluation.template.md` | L1 | modify | 嵌入三层子结构 |
| `spec/templates/zh/evaluation.template.md` | L1 | modify | 嵌入三层子结构（中文） |
| `spec/bootstrap/commands/validate-artifact.sh` | L1 | modify | 新增 decisions + codebase-map case |
| `spec/bootstrap/commands/check-consistency.sh` | L1 | modify | 新增 invariant 17 + 18 |
| `spec/bootstrap/commands/start-task.sh` | L1 | modify | artifact_templates 数组扩展 |
| `skills/baton-evaluator/SKILL.md` | L1 | modify | 三层对齐 + 扩展注入说明 |
| `skills/baton-architect/SKILL.md` | L1 | modify | Decision Records 更新 |
| `skills/baton-explorer/SKILL.md` | L1 | modify | Mode 1 产出 + 共存规则 |
| `skills/baton-orchestrator/SKILL.md` | L1 | modify | Risk-Adaptive Matrix 更新 |
| `spec/extensions/java-backend-strict/artifact-overlay.md` | L1 | modify | 标注已提升 |
| `spec/extensions/java-backend-strict/runtime-evaluator.md` | L1 | modify | 标注三层已提升 |
| `spec/extensions/java-backend-strict/templates/decisions.template.md` | L1 | delete | 已提升到核心 |
| `spec/extensions/java-backend-strict/templates/codebase-map.template.md` | L1 | delete | 已提升到核心 |
| `tests/test-validate-artifact.sh` | L1 | modify | 新增测试用例 |
| `tests/test-start-task.sh` | L1 | modify | 新增分发验证用例 |

**总计**: 4 个新文件 + 15 个修改 + 2 个删除 = 21 个文件变更

### L2 间接影响

- `.claude/skills/` 和 `.agents/` 目录下的 symlink — 通过 `link-skills.sh` 同步
- 任何现有 `.harness/evaluation.md` — 向后兼容（旧格式继续通过验证）

## 5. 可逆性分析

| 决策 | 可逆? | 代价 | 回退方式 |
|------|-------|------|---------|
| 新增 artifact-schema 条目 | 是 | 低 | 删除条目 + revert |
| 新建核心模板 | 是 | 低 | 删除文件 |
| evaluation.md 三层嵌入 | 是 | 低 | 恢复旧模板（旧格式仍兼容） |
| 删除 Java 扩展旧模板 | 是 | 低 | 从 git 恢复 |
| validate-artifact.sh 新 case | 是 | 低 | 删除 case 分支 |
| invariant 17/18 | 是 | 低 | 删除 invariant 块 |
| Skill 文档更新 | 是 | 低 | Revert commit |

所有变更均可逆，且回退成本低。

## 6. 验证策略

| 需求 | 验证方式 | 类型 |
|------|---------|------|
| R1 | 检查 artifact-schema.md 包含新条目 | manual |
| R2 | 检查 4 个新模板文件存在且内容正确 | manual |
| R3 | `validate-artifact.sh decisions/codebase-map` pass/fail 测试 | unit |
| R4 | 新旧格式 evaluation.md 均通过验证 | unit |
| R5 | 检查 evaluator skill 文档对齐 | manual |
| R6-R8 | 检查 skill 文档更新 | manual |
| R9 | `check-consistency.sh` 全量通过 | e2e |
| R10 | `start-task.sh` 分发验证 | integration |
| R11 | Java 扩展文档标注检查 | manual |
| R12 | `test-validate-artifact.sh` + `test-start-task.sh` | unit |
| R13 | `check-consistency.sh` invariant 4 | e2e |

## 7. 交付顺序

```
Unit 1: 制品定义 + 模板 (R1, R2)
  ├── artifact-schema.md 新增条目
  ├── 4 个新模板文件（en+zh × decisions+codebase-map）
  ├── 删除 Java 扩展旧模板
  └── 可独立验证：模板文件存在且内容正确

Unit 2: 验证管线 (R3, R9, R10, R12) — depends on Unit 1
  ├── validate-artifact.sh 新增 case
  ├── check-consistency.sh 新增 invariant 17+18
  ├── start-task.sh 扩展 artifact_templates
  ├── test-validate-artifact.sh 新增测试
  ├── test-start-task.sh 新增测试
  └── 可独立验证：bash tests/test-validate-artifact.sh

Unit 3: 评估三层化 (R4, R5) — independent of Unit 1/2
  ├── evaluation.template.md (en+zh) 嵌入三层
  ├── evaluator skill 对齐
  └── 可独立验证：旧格式/新格式 evaluation.md 均通过验证

Unit 4: Skill、协议与扩展同步 (R6, R7, R8, R11, R13) — depends on Unit 1+3
  ├── role-contracts.md Explorer + Architect 产出更新
  ├── architect/explorer/orchestrator skill 更新
  ├── Java 扩展 artifact-overlay.md + runtime-evaluator.md 标注
  ├── link-skills.sh 同步
  └── 可独立验证：check-consistency.sh 全量通过
```

## 8. 风险

1. **Section 匹配模式遗漏** — `validate-artifact.sh` 的正则可能无法匹配所有合法的中英文标题变体。缓解：测试用例覆盖中英文双语。
2. **Java 扩展删除旧模板后一致性断裂** — `artifact-overlay.md` 引用了旧模板的相对路径。缓解：更新引用并验证 invariant 17/18 的旧模板不存在检查。
3. **评估模板三层化后的 evaluator 行为** — evaluator 可能在旧对话中使用旧模板结构填写。缓解：旧格式仍通过验证，不阻塞工作流。

## 9. 自我质疑

1. **这是最优方案类别，还是只是第一个可行方案？**
   invariant 14 (generator-feedback) 的先例已验证了这个模式。独立 invariant 的方案清晰、可调试，是成熟选择。

2. **三层嵌入是否过度设计？**
   核心 evaluator skill 已经按 Layer 1/2/3 执行。让模板与执行结构对齐是减少认知负担，不是增加。用 `###` 嵌入不改变验证逻辑，是最小变更。

3. **删除 Java 扩展旧模板是否激进？**
   保留会导致两份模板不同步。invariant 17/18 检查旧模板不存在，确保不会遗留。如果需要恢复，git history 保底。

4. **一个怀疑者会先质疑什么？**
   "条件必需但没有门禁执行层阻塞" — 是的，条件必需制品（decisions.md, codebase-map.md, generator-feedback.md）的触发条件是语义判断，不适合在 shell 脚本中自动检测。执行保障依赖 skill 文档引导 + post-artifact 验证 + invariant 一致性检查，与 generator-feedback.md 先例一致。如果未来需要更强的执行保障，可在 pre-transition hook 中添加启发式检测（如检查 architecture.md 是否包含 "Rejected" 关键词），但这超出本任务范围。

5. **Codex 对抗审查后的修订**:
   - decisions.md 验证增加了 bullet 级别的 Choice/Why/Impact 字段检查（不再只检查 heading）
   - 三层评估结构现在覆盖 Findings 和 Verification Results 两个 section（不再只覆盖 Findings）
   - 明确了条件必需制品的执行模型（与 generator-feedback.md 一致）
   - 新增 `role-contracts.md` 到写入面（确保核心协议文档一致）

# 需求：promote-java-artifacts

**Owner**: `specifier`  
**状态**: `approved`

## 1. 问题

Java 后端严格扩展定义了若干高价值制品（`decisions.md`、`codebase-map.md`、三层评估结构），但这些制品的价值并不限于 Java 后端场景——任何涉及显著架构决策或大型存量仓库的任务都能受益。当前核心协议不识别这些制品，导致：

1. 非 Java 项目无法获得结构化的决策记录和代码地图
2. 核心评估模板（6 section 平铺）缺少分层评估结构，评估产出不够结构化
3. 跨技术栈的制品复用需要依赖扩展机制，增加了采纳摩擦

本任务采用分层提升策略（方案 C）：将通用价值的制品和结构提升到核心，同时保留技术栈特定内容在扩展中。核心三层评估的 Layer 2 定义为 "Diff Review"（通用代码审查），扩展可替换或扩展 Layer 2 以适配特定场景（如 Java 扩展的 "Runtime Signals"）。这是有意的设计选择，不是合并所有扩展内容。

## 2. 范围

- **范围内**:
  - `decisions.md` 提升为核心条件必需制品
  - `codebase-map.md` 提升为核心条件必需制品
  - 三层评估结构合并进核心 `evaluation.md` 模板和 evaluator skill
  - 新建核心模板（中英文各两个：decisions + codebase-map）
  - 更新验证脚本、一致性检查、分发脚本、相关 skill
  - 在 Java 扩展中标注已提升制品
- **范围外**:
  - `api-contract.yaml` 不提升（技术栈特定）
  - `runtime-signals/` 不提升（技术栈特定）
  - `evaluation-report.md` 不提升（Java 扩展独有格式）
  - 不改变状态机或门禁逻辑
  - 不改变 `task-status.md` 结构

## 3. 功能需求

- R1. [P0] **artifact-schema.md 新增条件必需制品定义** — 在 `## Conditionally Required Artifacts` 下新增 `decisions.md` 和 `codebase-map.md` 的定义，包括触发条件、writer、readers、purpose、required sections。
  - `decisions.md` 触发条件: `architecture.md` 包含至少一个被拒方案（即存在显著架构决策需要记录 Why / Why Not）
  - `codebase-map.md` 触发条件: Explorer 执行 repo-wide 模式（首次在大型存量仓库中采用 harness）

- R2. [P0] **新建核心模板** — 创建通用化的 `decisions.template.md` 和 `codebase-map.template.md`，分别提供中英文版本（共 4 个文件）。
  - `decisions.template.md`: 保持 Java 扩展的 D1/D2 结构（Choice / Rejected Alternatives / Why / Why Not / Impact）
  - `codebase-map.template.md`: 从 Java 扩展模板泛化。必需顶层 section: Project Structure、Module Dependencies、Data Model、Code Style And Conventions、High-Risk Areas。移除 Spring 特定 section（如 "Spring Runtime Notes"），替换为通用可选 section（如 "Framework/Runtime Notes"、"Existing API Surfaces"）。精确措辞留给架构阶段。

- R3. [P0] **validate-artifact.sh 新增验证类型** — 在 `run_checks()` 的 case 分支中新增 `decisions` 和 `codebase-map` 类型，定义中英文 section 标题匹配模式。(depends-on: R1, R2)

- R4. [P0] **三层评估结构合并进核心 evaluation.md** — 修改 `evaluation.template.md`（中英文），在现有 6 section 结构中将 `## 3. Findings` 和 `## 4. Verification Results` 细化为三层子结构：
  - Layer 1: 确定性检查（编译、测试、已有验证命令）
  - Layer 2: Diff Review（范围验证、架构一致性、安全审查、模式一致性）
  - Layer 3: 需求验证（逐项 AC 检查）
  - 设计要点: 核心 Layer 2 固定为 "Diff Review"。扩展可**替换或扩展** Layer 2 以适配特定场景（如 Java 扩展用 "Runtime Signals" 替换 "Diff Review"）。核心保持 3 层，扩展不改变层数，只改变 Layer 2 的内容。三层结构作为 Findings/Results 的内部组织方式嵌入模板，不改变顶层 6 section 编号。

- R5. [P0] **evaluator skill 更新** — 更新 `skills/baton-evaluator/SKILL.md` 中的执行指南，使其与新模板的三层子结构对齐。增加说明：扩展可替换或扩展 Layer 2 以适配特定场景（如 Java 扩展用 "Runtime Signals" 替换 "Diff Review"），但核心保持 3 层不变。(depends-on: R4)

- R6. [P1] **architect skill 更新** — 更新 `skills/baton-architect/SKILL.md` 的 "Decision Records" 小节，从 "inline in architecture.md; strict overlay uses separate decisions.md" 改为 "when architecture includes rejected alternatives, produce standalone decisions.md; otherwise record inline"。(depends-on: R1)

- R7. [P1] **explorer skill 更新** — 更新 `skills/baton-explorer/SKILL.md` 的 Mode 1 (Repo-wide) 产出说明，将 `repo-map.md`（optional）改为 `codebase-map.md`（conditionally required when repo-wide mode triggers）。共存规则: `codebase-map.md` 是 `repo-map.md` 的结构化替代；当 repo-wide 模式触发时，Explorer 产出 `codebase-map.md` 而非 `repo-map.md`；`repo-map.md` 保留在 Optional Artifacts 中仅用于向后兼容，不再由 Explorer 主动产出。(depends-on: R1)

- R8. [P1] **orchestrator 风险自适应矩阵更新** — 更新 `skills/baton-orchestrator/SKILL.md` 中的 Risk-Adaptive Matrix，在 Phase 2 (Explore) 和 Phase 4 (Architect) 行中反映 `codebase-map.md` 和 `decisions.md` 的条件产出。(depends-on: R6, R7)

- R9. [P1] **check-consistency.sh 新增不变量** — 新增一致性不变量覆盖已提升制品：
  - 核心模板存在性检查（`decisions.template.md` 和 `codebase-map.template.md` 的 en+zh 四个文件）
  - `artifact-schema.md` 与 `validate-artifact.sh` 的类型覆盖一致性
  - Java 扩展旧模板不存在检查（如果从扩展删除已提升模板）
  (depends-on: R1, R2, R3)

- R10. [P1] **start-task.sh 分发新模板** — 将 `decisions.template.md` 和 `codebase-map.template.md` 加入 `artifact_templates` 数组，使新任务启动时自动分发空模板到 `.harness/`。遵循 `evaluation.md` 和 `generator-feedback.md` 的先例——条件必需制品也分发模板，验证时机由 hook 控制。未触发路径: 分发的空模板保持 `draft` 状态（模板默认包含 `**Status**: \`draft\``），`validate-artifact.sh` 对 draft 状态制品跳过验证，因此未使用的模板不会导致验证失败。(depends-on: R2)

- R11. [P1] **Java 扩展标注已提升** — 更新 `spec/extensions/java-backend-strict/artifact-overlay.md`，标注 `decisions.md` 和 `codebase-map.md` 已提升到核心。更新 `runtime-evaluator.md`，标注三层评估结构已提升到核心，Java 扩展通过**替换** Layer 2 内容（用 "Runtime Signals" 替换 "Diff Review"）来适配，层数和结构不变。(depends-on: R1, R4)

- R12. [P1] **测试覆盖** — 在 `tests/test-validate-artifact.sh` 中新增 `decisions` 和 `codebase-map` 类型的 section 验证测试用例。在 `tests/test-start-task.sh` 中新增验证新模板被正确分发的测试用例。(depends-on: R3, R10)

- R13. [P2] **skill 同步验证** — 完成所有 skill 修改后，运行 `link-skills.sh` 确保 `.claude/skills/` 和 `.agents/` 同步，通过 `check-consistency.sh` invariant 4。(depends-on: R5, R6, R7, R8)

## 4. 非目标

1. 不提升 `api-contract.yaml` 到核心 — API 契约验证是技术栈特定的（OpenAPI/Swagger），不属于通用协议
2. 不提升 `runtime-signals/` 到核心 — 运行时信号采集依赖特定运行环境（JVM、容器等），核心不应强制
3. 不提升 `evaluation-report.md` — 核心已有 `evaluation.md`，Java 扩展的 `evaluation-report.md` 是冗余的独有格式
4. 不修改状态机或门禁 — 本任务是制品层变更，不涉及流程控制层
5. 不删除 `repo-map.md` — `repo-map.md` 保留在 Optional Artifacts 中用于向后兼容，但 Explorer repo-wide 模式不再主动产出它，改为产出 `codebase-map.md`
6. 不为 `decisions.md` 和 `codebase-map.md` 新增 hook — 验证时机由现有 post-artifact hook 和 validate-artifact.sh 覆盖

## 5. 验收标准

- [ ] [unit] 运行 `bash spec/bootstrap/commands/validate-artifact.sh decisions .harness/decisions.md`，对包含完整 section 的 decisions.md 返回成功
- [ ] [unit] 运行 `bash spec/bootstrap/commands/validate-artifact.sh codebase-map .harness/codebase-map.md`，对包含完整 section 的 codebase-map.md 返回成功
- [ ] [unit] `validate-artifact.sh` 对缺少必需 section 的 decisions.md / codebase-map.md 返回失败
- [ ] [integration] `artifact-schema.md` 中 `decisions.md` 和 `codebase-map.md` 的 required sections 列表与 `validate-artifact.sh` 中的 section 匹配模式完全一致
- [ ] [integration] `start-task.sh` 执行后，`.harness/` 中包含 `decisions.md` 和 `codebase-map.md` 空模板（draft 状态）
- [ ] [unit] 未触发条件时，draft 状态的 `decisions.md` 和 `codebase-map.md` 不会导致 `validate-artifact.sh` 或 `check-consistency.sh` 失败
- [ ] [integration] `check-consistency.sh` 所有 invariant 通过（包括新增的制品提升 invariant）
- [ ] [unit] 使用旧格式（无三层子结构）的 evaluation.md 仍然通过 `validate-artifact.sh evaluation` 验证（向后兼容）
- [ ] [unit] 使用新格式（含三层子结构）的 evaluation.md 通过 `validate-artifact.sh evaluation` 验证
- [ ] [manual] `evaluation.template.md`（中英文）包含 Layer 1/2/3 子结构，顶层仍保持 6 section 编号不变
- [ ] [manual] `baton-evaluator/SKILL.md` 执行指南与新模板的三层子结构对齐，明确说明扩展注入点
- [ ] [manual] `baton-architect/SKILL.md` 明确在架构包含被拒方案时产出独立 `decisions.md`
- [ ] [manual] `baton-explorer/SKILL.md` Mode 1 产出从 `repo-map.md` (optional) 改为 `codebase-map.md` (conditionally required)
- [ ] [manual] Java 扩展 `artifact-overlay.md` 和 `runtime-evaluator.md` 标注已提升制品，保持扩展文档自洽
- [ ] [e2e] 运行 `bash spec/bootstrap/commands/check-consistency.sh .` 全量通过

## 6. 约束

1. **先例遵循**: 实现模式必须遵循 `generator-feedback.md` 提升的先例（commit `2c6f6ee`），包括：核心新增定义 → 核心新增模板 → 验证脚本新增类型 → 一致性检查新增 invariant → 扩展标注
2. **双语模板**: 所有新模板必须提供 `spec/templates/` (en) 和 `spec/templates/zh/` 两个版本
3. **向后兼容**: 现有 `.harness/evaluation.md` 的验证逻辑不能被新的三层子结构破坏（旧格式仍然通过验证）
4. **Section 匹配模式**: `validate-artifact.sh` 中的正则必须同时匹配中英文 section 标题
5. **Invariant 编号**: 新增 invariant 不能与现有 16 个 invariant 编号冲突

## 7. 验证意图

- **R1-R3**: 通过 `validate-artifact.sh` 对测试制品文件的 pass/fail 结果验证
- **R4-R5**: 通过人工检查模板结构和 skill 文档一致性验证
- **R9**: 通过 `check-consistency.sh` 全量运行验证
- **R10**: 通过 `start-task.sh` 实际运行后检查 `.harness/` 目录内容验证
- **R11**: 通过人工检查 Java 扩展文档的标注和自洽性验证
- **R12**: 通过运行 `test-validate-artifact.sh` 验证
- **R13**: 通过 `check-consistency.sh` invariant 4 验证

## 未决设计问题（架构阶段确认）

以下问题已在需求层明确意图，具体实现方案留给架构阶段:

1. **evaluation.md 三层子结构的精确嵌入方式**: R4 规定了三层嵌入 Findings/Results 的意图，但不规定具体的 markdown heading 层级（## vs ###）和子 section 命名
2. **codebase-map.md 可选 section 和精确措辞**: R2 已定义必需顶层 section（Project Structure、Module Dependencies、Data Model、Code Style And Conventions、High-Risk Areas），但可选 section 的最终列表和精确措辞留给架构阶段
3. **check-consistency.sh 新 invariant 的编号和分组**: R9 规定需要新增 invariant，但不指定编号分配

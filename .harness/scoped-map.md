# Scoped Map: promote-java-artifacts

**需求**: 将 Java 扩展中的 `decisions.md` 和 `codebase-map.md` 提升为核心条件必需制品，将三层评估结构合并进核心 `evaluation.md`，保留 `api-contract.yaml` 和 `runtime-signals/` 在 Java 扩展  
**领域**: harness protocol / artifact schema  
**Owner**: `scoped-explorer`  
**状态**: `complete`

## 1. 范围

- 范围内:
  - 提升 `decisions.md` 为核心条件必需制品（Architect 产出，当架构包含显著决策时必需）
  - 提升 `codebase-map.md` 为核心条件必需制品（Explorer 产出，当 repo-wide 探索触发时必需）
  - 将 Java 扩展的三层评估结构（确定性检查 / 运行时信号 / 需求判断）合并进核心 `evaluation.md` 模板和 evaluator skill
  - 在 Java 扩展中标注已提升的制品和评估结构
  - 新增 `decisions.template.md` 和 `codebase-map.template.md` 的中英文核心模板
  - 更新验证脚本识别新制品类型
  - 更新一致性检查脚本覆盖新制品
  - 更新 `install-harness.sh` / `start-task.sh` 分发新模板
  - 更新相关 skill 的产出说明
- 范围外:
  - `api-contract.yaml` 留在 Java 扩展（不提升）
  - `runtime-signals/` 留在 Java 扩展（不提升）
  - `evaluation-report.md` 不提升（Java 扩展独有的格式，核心已有 `evaluation.md`）
  - 不改变状态机或门禁逻辑
  - 不改变 `task-status.md` 结构
- 预期写入边界: 约 15-18 个文件

## 2. 入口点

- 主要入口类或文件:
  - `spec/protocol/artifact-schema.md` (L73-117) -- 制品定义的权威源，需新增 `decisions.md` 和 `codebase-map.md` 条目
  - `spec/bootstrap/commands/validate-artifact.sh` (L68-113) -- `run_checks()` 函数的 case 分支，需新增 `decisions` 和 `codebase-map` 类型
  - `spec/bootstrap/commands/check-consistency.sh` -- 一致性不变量检查，需新增 invariant 覆盖新制品
  - `skills/baton-evaluator/SKILL.md` (L138-198) -- Layer 1/2/3 执行指南
  - `skills/baton-architect/SKILL.md` (L318-328) -- Decision Records 小节
  - `skills/baton-explorer/SKILL.md` (L47-53) -- Mode 1 Repo-wide 产出
  - `skills/baton-orchestrator/SKILL.md` (L258-273) -- Risk-Adaptive Matrix
  - `spec/templates/evaluation.template.md` -- 评估模板
  - `spec/templates/zh/evaluation.template.md` -- 评估模板（中文）
- 涉及的方法、API、命令或脚本:
  - `validate-artifact.sh` 的 `check_sections()` / `run_checks()` case 分支
  - `check-consistency.sh` 的 invariant 14 及潜在新 invariant
  - `start-task.sh` 的 `artifact_templates` 数组 (L240-247)
  - `install-harness.sh` 不直接管理单个模板拷贝（它拷贝整个 `spec/`），但 `start-task.sh` 负责将模板拷贝到 `.harness/`
- 这些入口为什么相关: 它们构成制品从定义 -> 模板 -> 验证 -> 分发 -> skill 引用的完整生命周期链

## 3. 调用链

```text
artifact-schema.md                          # 1. 制品定义权威源
  |
  v (定义必需 section)
spec/templates/{decisions,codebase-map}.template.md  # 2. 核心模板 (新建 en+zh)
  |
  v (start-task.sh 拷贝模板到 .harness/)
spec/bootstrap/commands/start-task.sh       # 3. 模板分发 (artifact_templates 数组)
  |
  v (post-artifact hook 调用 validate-artifact.sh)
spec/bootstrap/commands/validate-artifact.sh # 4. 制品验证 (新增 case 分支)
  |
  v (一致性检查引用 validate-artifact.sh)
spec/bootstrap/commands/check-consistency.sh # 5. 一致性不变量
  |
  v (install-harness.sh 安装整个 spec/ 到 vendor)
spec/bootstrap/commands/install-harness.sh  # 6. 分发 (间接 -- 拷贝整个 spec/ 目录)

skills/baton-architect/SKILL.md             # 7. Architect 产出 decisions.md
skills/baton-explorer/SKILL.md              # 8. Explorer 产出 codebase-map.md
skills/baton-evaluator/SKILL.md             # 9. Evaluator 采用三层评估结构
skills/baton-orchestrator/SKILL.md          # 10. Orchestrator 矩阵更新

spec/extensions/java-backend-strict/
  artifact-overlay.md                       # 11. 标注已提升到核心
  runtime-evaluator.md                      # 12. 标注三层结构已提升
```

## 4. 数据流

- Source: Java 扩展中的制品定义和模板 (`spec/extensions/java-backend-strict/`)
- Transforms:
  1. `artifact-schema.md` 新增条件必需制品定义 -> 影响验证规则
  2. 新建核心模板 -> `start-task.sh` 读取并拷贝 -> `.harness/` 工作区
  3. post-artifact hook -> `validate-artifact.sh` 读取并验证 section 完整性
  4. `check-consistency.sh` 读取 `artifact-schema.md` + `validate-artifact.sh` + 模板 + skill 确认一致性
- Sink: `.harness/decisions.md` 和 `.harness/codebase-map.md` 制品文件（由 Architect 和 Explorer 写入）
- 状态变异:
  - `decisions.md` 的 "条件必需" 触发条件: 架构包含显著决策（Medium/High risk）
  - `codebase-map.md` 的 "条件必需" 触发条件: Explorer 执行 repo-wide 模式
  - `evaluation.md` 模板增加三层结构 section（不改变条件必需逻辑，它已经是条件必需）

## 5. 现有行为

- 当前可观察行为:
  - `decisions.md` 仅在 Java 扩展的 `artifact-overlay.md` 中定义，核心协议不识别
  - `codebase-map.md` 同上，核心协议中 `repo-map.md` 是可选的
  - `evaluation.md` 核心模板有 6 个 section（Inputs / Provenance / Findings / Results / Verdict / Risks），不含三层结构
  - `validate-artifact.sh` 识别 7 种类型: scoped-map, requirements, architecture, verification-path, evaluation, task-status, generator-feedback
  - `start-task.sh` 分发 6 个模板到 `.harness/`（scoped-map, requirements, architecture, verification-path, evaluation, retrospective）
  - `check-consistency.sh` 有 16 个 invariant，其中 invariant 14 覆盖 generator-feedback 提升后的一致性
  - Architect skill 在 "Decision Records" 小节 (L318-328) 说 "Record decisions inline in `architecture.md`"，只在 strict overlay 时才用独立 `decisions.md`
  - Explorer skill 的 Repo-wide 模式产出 `repo-map.md`（可选），不提及 `codebase-map.md`
  - Evaluator skill 已有 Layer 1/2/3 结构（确定性检查 / Diff Review / 需求验证），但与 Java 扩展的三层（确定性检查 / 运行时信号 / 需求判断）不同
- 当前校验规则:
  - `evaluation` 类型验证: `Inputs|输入`, `Execution.Provenance|Isolation.Provenance`, `Findings|发现`, `Verification.Results`, `Verdict`, `Residual.Risks`
  - Draft 状态制品跳过验证
- 现有隐式约束:
  - `generator-feedback.md` 提升的先例: 从 Java 扩展删除旧模板，核心新增模板 + 验证 + 一致性检查（invariant 14 检查旧模板不存在）
  - `start-task.sh` 中 `artifact_templates` 数组决定哪些模板在新任务时被拷贝
  - 条件必需制品（如 `evaluation.md`, `generator-feedback.md`）不在 `start-task.sh` 的常规分发中，它们的模板仍被拷贝但由 hook 在需要时验证

## 6. 现有测试

- 直接相关的测试:
  - `/Users/hex1n/IdeaProjects/baton/tests/test-validate-artifact.sh` -- 验证 validate-artifact.sh 对各制品类型的 section 检查，需新增 `decisions` 和 `codebase-map` 测试用例
  - `/Users/hex1n/IdeaProjects/baton/tests/test-start-task.sh` -- 验证 start-task.sh 的模板分发行为
- 附近可复用的测试:
  - `/Users/hex1n/IdeaProjects/baton/tests/test-validate-isolation.sh` -- 验证隔离 provenance，evaluation 模板变更可能影响
  - `/Users/hex1n/IdeaProjects/baton/tests/test-harness-context.sh` -- harness 上下文摘要
- 测试落点（新增需要）:
  - `test-validate-artifact.sh` 新增 `decisions` 和 `codebase-map` 类型测试用例
  - `test-start-task.sh` 确认新模板被正确分发（如果加入 `artifact_templates` 数组）
  - 一致性检查 (`check-consistency.sh` 自身就是测试)

## 7. 变更历史

- 近期受影响区域的变更 (git log):
  - `cc00a5a` fix: scope evaluator diff to write surface files from architecture.md
  - `a0a78aa` feat: implement P2/P3 improvements (profile feedback, crash recovery)
  - `cf46251` feat: implement P1 improvements (risk-adaptive alignment)
  - `c8919ac` feat: implement P0 improvements (base_commit, DRY cleanup)
  - `2c6f6ee` feat: harden baton runtime and workflow -- 这次提交完成了 `generator-feedback.md` 从 Java 扩展到核心的提升，是本次任务的直接先例
- 高频变更文件:
  - `skills/baton-evaluator/SKILL.md` -- 最近 5 次提交中有 4 次修改
  - `skills/baton-orchestrator/SKILL.md` -- 最近 5 次提交中有 3 次修改
  - `spec/bootstrap/commands/check-consistency.sh` -- 最近 5 次提交中有 3 次修改
- 活跃贡献者: 单一贡献者

## 8. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施? 否 -- 纯协议层变更
- 这次改动是否可能触及迁移或 schema? 否 -- 但 `artifact-schema.md` 本身就是 schema
- 这次改动是否可能跨业务域? 是 -- 横切 protocol / templates / bootstrap / skills 四个目录
- 具体风险:

1. **evaluation.md 模板三层合并的向后兼容** -- 核心 evaluator 已有 Layer 1/2/3（确定性 / Diff / 需求），Java 扩展的三层是（确定性 / 运行时信号 / 需求判断）。两者 Layer 1 相同，Layer 2 不同（Diff Review vs Runtime Signals），Layer 3 类似。合并时需决定是扩展为 4 层还是将运行时信号作为 Layer 2 的子项。这是架构决策的核心。
2. **`validate-artifact.sh` section 匹配模式** -- 新增 `decisions` 和 `codebase-map` 类型需要精确的 section 标题匹配模式（中英文双语），需要仔细对齐模板和验证脚本。
3. **`start-task.sh` 分发决策** -- `decisions.md` 和 `codebase-map.md` 是条件必需的，是否应该在 `start-task.sh` 的 `artifact_templates` 数组中加入取决于 "条件必需" 的触发时机。如果在每个任务开始时就分发空模板，可能产生噪音；如果不分发，则需要 skill 自行从模板目录拷贝。需参考 `evaluation.md` 和 `generator-feedback.md` 的先例（两者都在 `artifact_templates` 中）。
4. **`check-consistency.sh` invariant 扩展** -- `generator-feedback` 提升时新增了 invariant 14。本次提升可能需要新增 invariant 或扩展 invariant 14 来覆盖 `decisions.md` 和 `codebase-map.md` 的模板 / 验证 / skill 一致性。需避免 invariant 编号冲突。
5. **Java 扩展标注后的一致性** -- `artifact-overlay.md` 需要标注哪些制品已提升到核心，同时保持扩展文档自身的可读性和正确性。
6. **Skill 同步** -- skills/ 目录下修改后，必须通过 `link-skills.sh` 同步到 `.claude/skills/` 和 `.agents/`，否则 invariant 4 会失败。

## 9. 变更形态

- 这看起来像: 分层协议提升（类似 `generator-feedback.md` 的提升先例，但涉及 3 个制品维度的变更）
- 预计文件数: 约 15-18 个文件（新建 4 + 修改 11-14）
  - 新建: `spec/templates/decisions.template.md`, `spec/templates/zh/decisions.template.md`, `spec/templates/codebase-map.template.md`, `spec/templates/zh/codebase-map.template.md`
  - 修改: `artifact-schema.md`, `validate-artifact.sh`, `check-consistency.sh`, `start-task.sh` (可选), `baton-orchestrator/SKILL.md`, `baton-architect/SKILL.md`, `baton-explorer/SKILL.md`, `baton-evaluator/SKILL.md`, `evaluation.template.md` (en+zh), `artifact-overlay.md`, `runtime-evaluator.md`, `test-validate-artifact.sh`
- 推荐实现深度: 中等 -- 每个变更点的逻辑清晰，但需仔细对齐跨文件一致性

## 10. 未决问题

- 三层评估结构合并方案: 核心 evaluator 的 Layer 2 (Diff Review) 与 Java 扩展的 Layer 2 (Runtime Signals) 如何统一？选项: (A) 扩展为 4 层; (B) 将运行时信号作为 Layer 1 的可选子项; (C) 保持核心 3 层不变，将运行时信号作为 Extension 提示加入 evaluator skill 但不改模板
- `decisions.md` 的条件触发: 什么条件下 "条件必需"？是所有 Medium/High risk，还是只在 architecture 包含多于 1 个被拒方案时？
- `codebase-map.md` 的条件触发: 是 repo-wide 探索时必需，还是所有 High risk 任务必需？
- 是否需要在 `start-task.sh` 的 `artifact_templates` 中加入新模板: `evaluation.md` 和 `generator-feedback.md` 目前都在数组中会被拷贝，但 `decisions.md` 和 `codebase-map.md` 不是每次任务都需要

## 11. 建议

- 是否继续? 是 -- 变更边界清晰，有 `generator-feedback.md` 提升作为直接先例可参照
- 建议下一步:
  - Specifier 应优先确认三层评估合并方案（风险 1）和条件触发逻辑（未决问题 2/3）
  - 实现顺序建议: artifact-schema -> 模板 -> validate-artifact -> check-consistency -> skills -> Java 扩展标注 -> 测试
  - 参照 `generator-feedback.md` 提升的 commit `2c6f6ee` 作为实现模式

## Overlay Recommendation

overlay: strict

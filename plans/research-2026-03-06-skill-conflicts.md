# Research: Baton × Superpowers Skills 冲突分析

## 工具使用记录

| 工具 | 用途 | 结果 |
|------|------|------|
| Glob | 定位所有 skill 文件 | 14 个 superpowers skills + 支撑文件 |
| Agent (general-purpose) | 并行读取 15 个 SKILL.md，提取结构化摘要 | 每个 skill 的触发条件、核心机制、跟踪方式、验证方式、与计划文件的交互 |
| Read | baton workflow.md + workflow-full.md | 作为对比基准 |

---

## § 1. 冲突分类框架

四种冲突类型：

| 类型 | 定义 | 严重程度 |
|------|------|---------|
| **CONTRADICTION** | 两个系统给出矛盾指令 | 高：AI 被迫违反其中一个 |
| **REDUNDANCY** | 两个系统做同一件事，造成双倍开销 | 中：浪费时间，不造成错误 |
| **COMPETITION** | 两个系统争夺同一控制点 | 高：状态不一致 |
| **GAP** | 一个系统有某能力，另一个缺失，导致不协调 | 低-中：取决于是否需要该能力 |

---

## § 2. 逐 Skill 冲突分析

### 2.1 using-superpowers（元 skill）

**冲突类型：COMPETITION**

这是根源冲突。using-superpowers 说：

> "If you think there is even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke the skill."
> "This is not negotiable. This is not optional."

Baton 说：

> "You are an investigator, not an executor."
> 判断应基于 Complexity Calibration 和 task 类型。

**问题**：using-superpowers 的无条件触发机制不允许 AI 根据任务复杂度做判断。一个 Trivial 级 baton 任务仍会触发 brainstorming → writing-plans → subagent-driven-development 全链。这直接违反 Baton 的 Complexity Calibration 设计意图。

**证据**：Plan 2 实施过程中，subagent-driven-development 被触发用于 markdown 重写（应为 Trivial-Small 级），导致 ~25 分钟额外开销。

---

### 2.2 writing-plans

**冲突类型：COMPETITION + CONTRADICTION**

| 维度 | Baton | writing-plans | 冲突 |
|------|-------|--------------|------|
| 计划位置 | `plan.md` 或 `plan-<topic>.md`（项目根） | `docs/plans/YYYY-MM-DD-<feature-name>.md` | COMPETITION：两个不同路径，hooks 只认 baton 路径 |
| 计划结构 | What/Why/Impact/Risks + Self-Review + 批注区 | 固定头部（goal/architecture/tech stack/sub-skill reference）+ 精确步骤 | CONTRADICTION：结构完全不同 |
| 人类审批 | 批注循环 → `<!-- BATON:GO -->` → 才能写代码 | 无审批门：写完直接执行 | CONTRADICTION：baton 的核心安全机制被绕过 |
| Todolist | `## Todo` + `- [ ]`（hooks grep 依赖） | 精确步骤内嵌在计划文档中 | COMPETITION：hooks 找不到 skill 格式 |
| 详细程度 | 描述意图 + 验证方法 | 精确代码 + 精确命令 + 期望输出 | 风格矛盾但不一定冲突 |

**严重程度：高**。这是最大的结构性冲突——两个系统各自定义了完整的计划格式和审批流程。

---

### 2.3 subagent-driven-development

**冲突类型：REDUNDANCY + CONTRADICTION**

| 维度 | Baton | subagent-driven-development | 冲突 |
|------|-------|---------------------------|------|
| 执行跟踪 | `## Todo` checkboxes in plan.md | TodoWrite API | COMPETITION：双重跟踪 |
| 质量保证 | Self-Check Triggers（内省式） | 3 阶段外审（implementer → spec → code quality） | REDUNDANCY：同一目标的双重机制 |
| Implementer 指令 | IMPLEMENT 阶段指南（phase-guide.sh 注入） | implementer-prompt.md 模板 | COMPETITION：两套执行指令 |
| 完成后动作 | `## Retrospective` → 提醒归档 | → `finishing-a-development-branch`（merge/PR/discard） | CONTRADICTION：baton 归档 vs skill push/merge |
| Commit 策略 | 不主动 commit（plan 2 实施期间无 commit 要求） | implementer 要求 "commit your work" | CONTRADICTION |

**严重程度：高**。Plan 2 实施的主要低效来源。

---

### 2.4 executing-plans

**冲突类型：COMPETITION + CONTRADICTION**

与 subagent-driven-development 类似，但额外问题：

- 使用 TodoWrite 而非 `## Todo` checkboxes
- 以 3 个 task 为一批 review，baton 以每个 todo item 为单位 review
- 完成后链接到 `finishing-a-development-branch`，不走 baton 归档流程
- 读取 plan 文件但不写入——baton 要求发现遗漏时更新 plan.md

**严重程度：高**。

---

### 2.5 brainstorming

**冲突类型：COMPETITION + GAP**

| 维度 | Baton | brainstorming | 冲突 |
|------|-------|--------------|------|
| 探索阶段 | research.md → 批注循环 → plan.md | 对话式设计 → `docs/plans/` 文档 | COMPETITION：两个不同的探索流程 |
| 产出物 | research.md + plan.md（带批注区） | design doc（200-300 字分段验证） | COMPETITION：不同格式 |
| 人类参与 | 批注类型（[Q]/[DEEPER]/[CHANGE]...）→ 结构化反馈 | 一次一个问题 → 多选 → 递增验证 | 风格冲突：结构化 vs 对话式 |
| 后续链 | plan.md → BATON:GO → todolist | → using-git-worktrees → writing-plans | COMPETITION：两条不同的下游链路 |

**GAP**：brainstorming 的「一次一个问题」「多选项」交互模式比 baton 的批注循环更友好。Baton 缺乏这种交互设计。

**严重程度：中**。

---

### 2.6 systematic-debugging

**冲突类型：REDUNDANCY（轻微）**

| 维度 | Baton | systematic-debugging | 冲突 |
|------|-------|---------------------|------|
| 证据要求 | file:line + ✅/❌/❓ | 根因调查 → 证据收集 | 兼容：方向一致 |
| 3 次失败规则 | Action Boundaries #5："3x → MUST stop" | "3+ fixes fail → question architecture" | REDUNDANCY：同一规则两个来源 |
| 产出物 | 无（直接修 bug） | 无持久化文档 | 兼容 |
| 研究义务 | "All analysis → research.md" | 无 research.md 输出 | GAP：baton 可能要求 debugging 产出 research.md |

**严重程度：低**。两者方向一致，冲突仅在「是否产出 research.md」上。

---

### 2.7 test-driven-development

**冲突类型：GAP**

TDD skill 与 baton 几乎无冲突——它是纯粹的代码级纪律，baton 是流程级协议，不同层面。

唯一 GAP：baton 没有明确要求 TDD。如果 baton plan 说「写测试」但没说「先写失败测试再写代码」，而 TDD skill 被触发，它会要求删除已有代码从头来——这可能与 baton plan 的意图冲突。

**严重程度：低**。

---

### 2.8 verification-before-completion

**冲突类型：REDUNDANCY**

| 维度 | Baton | verification-before-completion | 冲突 |
|------|-------|-------------------------------|------|
| 完成前验证 | "re-read the code, compare against plan" | "run the command, read output, THEN claim" | REDUNDANCY：都是完成前的门控 |
| "should be fine" | Evidence Standards 明确禁止 | 同样禁止 "should work now" | 完全对齐 |
| 验证标准 | file:line 证据 | 命令输出 + exit code | 互补但重叠 |

**严重程度：低**。方向完全一致。可以视为 baton 的 Evidence Standards 的子集。

---

### 2.9 requesting-code-review / code-reviewer

**冲突类型：REDUNDANCY**

Baton 的 IMPLEMENT 阶段已有 self-check triggers。code-reviewer 提供独立外审。两者不矛盾但叠加时（特别是 subagent-driven-development 的 3 阶段 review）造成冗余。

单独使用 requesting-code-review（比如实施结束后做一次总审）与 baton 完全兼容。

**严重程度：低**（单独使用时）。

---

### 2.10 dispatching-parallel-agents

**冲突类型：无直接冲突**

这是一个纯执行工具，不涉及计划、跟踪或审批流程。Baton 的 IMPLEMENT 段已经说"Independent items can run in parallel (subagent)"。两者兼容。

**严重程度：无**。

---

### 2.11 using-git-worktrees

**冲突类型：GAP（轻微）**

Baton 说 "Use git worktrees for parallel sessions"（Session Handoff）但不定义具体操作。Skill 定义了完整的 worktree 操作流程。两者互补。

唯一 GAP：skill 把 worktree 放在 `.worktrees/` 或 `worktrees/`；baton 无偏好。

**严重程度：无**。

---

### 2.12 finishing-a-development-branch

**冲突类型：CONTRADICTION**

Baton 的完成流程：`## Retrospective` → 提醒归档到 `plans/`。
Skill 的完成流程：验证测试 → 呈现 4 个选项（merge/PR/keep/discard）。

两者定义了不同的「完成」含义。Baton 关注知识归档，skill 关注代码集成。

**严重程度：中**。但如果明确界定 baton 归档先于 skill 集成，则可协调。

---

### 2.13 receiving-code-review

**冲突类型：无直接冲突**

这是被动技能（收到 review 后如何响应），不涉及 baton 的任何流程。与 baton 的 "disagree with evidence" 原则方向一致。

**严重程度：无**。

---

### 2.14 writing-skills

**冲突类型：无直接冲突**

创建新 skill 的元技能。不影响 baton 日常流程。

**严重程度：无**。

---

## § 3. 冲突严重程度总览

| Skill | 冲突类型 | 严重程度 | 核心问题 |
|-------|---------|---------|---------|
| **using-superpowers** | COMPETITION | 🔴 高 | 无条件触发绕过 Complexity Calibration |
| **writing-plans** | COMPETITION + CONTRADICTION | 🔴 高 | 计划格式、位置、审批流程全面冲突 |
| **subagent-driven-development** | REDUNDANCY + CONTRADICTION | 🔴 高 | 双重跟踪、双重验证、指令竞争 |
| **executing-plans** | COMPETITION + CONTRADICTION | 🔴 高 | 同 subagent-driven-development |
| **brainstorming** | COMPETITION + GAP | 🟡 中 | 探索流程竞争；交互模式差异 |
| **finishing-a-development-branch** | CONTRADICTION | 🟡 中 | 完成定义不同（归档 vs 集成） |
| **systematic-debugging** | REDUNDANCY | 🟢 低 | 3x 规则重复；research.md 义务模糊 |
| **test-driven-development** | GAP | 🟢 低 | baton 不要求 TDD；TDD 可能删除已有代码 |
| **verification-before-completion** | REDUNDANCY | 🟢 低 | 方向一致，互补 |
| **requesting-code-review** | REDUNDANCY | 🟢 低 | 单独使用兼容 |
| **dispatching-parallel-agents** | — | ⚪ 无 | 完全兼容 |
| **using-git-worktrees** | GAP | ⚪ 无 | 互补 |
| **receiving-code-review** | — | ⚪ 无 | 兼容 |
| **writing-skills** | — | ⚪ 无 | 不影响 |

---

## § 4. 根因分析

### 4.1 两个系统的设计哲学差异

| 维度 | Baton | Superpowers |
|------|-------|-------------|
| **控制模型** | 人类门控（批注→GO→todolist→实施） | AI 自主（skill 链自动流转） |
| **验证方式** | 自检 + 人类审查批注 | 外审（subagent 交叉审查） |
| **状态追踪** | Markdown checkboxes（人类可读） | TodoWrite API（程序化） |
| **计划格式** | 灵活（成功标准 + 意图描述） | 严格（精确代码 + 精确命令） |
| **完成定义** | 知识归档（Retrospective → plans/） | 代码集成（merge/PR） |
| **适用范围** | 所有任务（含分析、研究） | 代码实现任务 |

### 4.2 核心张力

Baton 的核心假设是**人类是质量的最终保障**——通过批注循环确保共识。
Superpowers 的核心假设是**AI 自审可以替代部分人类审查**——通过 subagent 交叉检查。

两者不是非此即彼。它们在不同维度上有效：
- Baton 在**方向正确性**上更强（人类判断需求、优先级、trade-off）
- Superpowers 在**执行正确性**上更强（代码质量、测试覆盖、回归检测）

冲突发生在两者都试图控制**同一阶段**时——特别是 IMPLEMENT 阶段。

### 4.3 为什么问题现在才暴露

Plan 1（结构性改进）只改了管道，不改内容，没有触发 skill。
Plan 2（内容重写）触发了 subagent-driven-development，第一次在同一个 task 中同时运行 baton 和 superpowers。

---

## § 5. 三个需要人类判断的问题

### Q1: Baton 应该兼容 Superpowers 还是替代它？

两个方向：
- **兼容**：定义 baton 阶段与 skill 的映射关系（哪个阶段用哪个 skill），修改冲突的 skill 或添加 baton 适配层
- **替代**：Baton 内建 superpowers 的有效能力（subagent 并行、外部 code review），不再依赖 skill 系统

兼容的优点：保留 skill 生态的灵活性，别人也能用
替代的优点：消除所有冲突，一个系统管所有事

### Q2: using-superpowers 的「无条件触发」规则怎么处理？

三个选项：
- **A. 修改 using-superpowers**：加入 "if baton workflow is active, defer to baton's Complexity Calibration for skill selection"
- **B. 修改 baton**：在 Complexity Calibration 中明确每个级别可用的 skill
- **C. 不改**：依赖 memory 中的经验记录让 AI 自行校准（当前方案，不可靠）

### Q3: 验证层怎么统一？

- Baton 的 self-check triggers（内省式）
- Superpowers 的 subagent review（外审式）
- verification-before-completion（运行命令式）

全部叠加 = 3 次验证同一件事。全部只留一个 = 可能遗漏。
需要决定：哪些场景用哪种验证方式？

---

## Self-Review

1. **最可能被质疑的点**：我把 using-superpowers 标为 🔴 高冲突。有人可能说它只是一个触发机制，真正冲突的是被触发的 skill 本身。但我认为根源在触发逻辑——如果触发逻辑尊重 baton 的复杂度校准，下游冲突大多可以避免。

2. **最弱的结论**：brainstorming 标为 🟡 中。实际上它的「一次一个问题」设计可能和 baton 的批注循环是互补的（不同交互场景），不一定是竞争。需要实际测试才能确认。

3. **如果进一步调查会改变什么**：如果测试发现 using-superpowers 的无条件触发在 baton 上下文中实际上被 CLAUDE.md 的 workflow 引用覆盖（即 baton 指令优先级高于 skill 指令），那冲突严重程度可能降低。但目前没有证据支持这个假设——Plan 2 的经验表明 skill 确实被无条件触发了。

## Questions for Human Judgment

1. **Baton 的定位**：你打算让 baton 成为一个通用的 AI 协作协议（兼容其他工具生态），还是一个自包含的完整系统（不依赖外部 skill）？这决定了 Q1 的方向。

2. **Skill 生态的可控性**：Superpowers 是第三方 plugin，你能修改它吗？如果不能，兼容只能从 baton 侧做。

3. **实际使用中哪些 skill 有价值**：在你的日常工作中，哪些 superpowers skill 你觉得确实提供了 baton 不具备的价值？（比如 TDD 纪律、code review 外审、worktree 管理）

## Annotation Log

### Round 1 (2026-03-06)

**[Q] § Questions for Human Judgment — Baton 的定位**
"经过你多次任务的实践 你认为Baton的定位是什么?"
→ 基于 Plan 1 + Plan 2 实践：Baton 是**决策对齐层**（decision-alignment layer），不是执行层。
  - 核心价值在 RESEARCH + ANNOTATION 阶段（结构化研究、批注循环、证据标准）——没有任何 skill 有等价物
  - IMPLEMENT 阶段价值低：self-check triggers 弱于 subagent 外审
  - Baton 应管「做什么 + 为什么」，在执行阶段做调度者，委托给合适的 skill
→ 这个定位决定了 Q1 的答案：**兼容**路线（baton 做上层协议，skill 做下层执行工具）

**[NOTE] § Questions for Human Judgment — 约束与价值判断**
"1. 不能修改第三方plugin 2. TDD和code review外审价值较大"
→ 约束接纳：Q2 选项 A（修改 using-superpowers）排除，只能从 baton 侧适配
→ TDD + code review 恰好是 🟢 低冲突 skill（纯执行纪律，不争流程控制权），整合最容易
→ 影响 § 5 Q1 结论：走兼容路线，从 baton 侧添加 skill 调度指导

**[DEEPER] § Questions for Human Judgment — Baton 往哪个方向发展更好**
"你认为Baton往哪个方向发展更好呢?"
→ 分析了三条路径：
  - A. 协议层（只管决策，执行全委托）：风险是失去执行阶段的控制力
  - B. 全栈框架（吸收 skill 能力）：重造轮子，维护负担
  - **C. 编排协议（推荐）**：保持决策对齐能力，升级为 skill 编排者
→ 路径 C 的核心设计：**扩展 Complexity Calibration，从控制 baton 深度 → 同时控制 skill 选择**
  - Trivial → 不触发 skill
  - Small → 完成后可选 code review
  - Medium → TDD + code review
  - Large → subagent 并行 + TDD + 必须 code review
→ 四个优势：(1) 复用现有概念 (2) 解决 using-superpowers 根源冲突 (3) 保留各自优势 (4) 渐进可行
→ CLAUDE.md 指令优先级高于 plugin skill，可以在 baton 侧声明 "skill 选择服从 Complexity Calibration"
→ Result: 推荐路径 C，等待人类确认

**[RESEARCH-GAP] § Questions for Human Judgment — 社区/学术研究**
"还有最佳的路线吗? 是否可以检索一下社区对于类似问题的讨论或者其他团队的实践经验 或者相关的学术研究"
→ 暂停当前文档，执行外部研究。检索了 9 个来源（WebSearch × 6, WebFetch × 2, Context7 × 1）。
→ 新增 § 6 Supplement，6 个子节涵盖：
  - 6.1 多 Agent 编排模式（Kore.ai）：Supervisor 模式 ≈ Path C 的人类+baton 联合 supervisor
  - 6.2 指令优先级层级（arxiv 2404.13208）：CLAUDE.md > plugin skill，但需显式声明才能生效
  - 6.3 claude-code-workflows 社区项目（shinpr）：已实现 requirement-analyzer → 动态 skill 选择，验证 Path C 可行
  - 6.4 复杂度路由模式（Shipyard/ruflo）：入口一次性判断 → 后续自动路由，与 Complexity Calibration 扩展对齐
  - 6.5 Agent 编排控制面（arxiv 2601.13671）：单一事实源 + supervisor 模式，plan.md 应为唯一状态源
  - 6.6 综合结论：四个维度（指令优先级、复杂度路由、控制面统一、分层架构）均验证 Path C 方向
→ Result: 外部研究从工业实践、学术论文、社区项目三个维度验证 Path C（编排协议）是合理方向。无发现替代性"最佳路线"——Path C 本身与业界最佳实践对齐。

**[Q] § 整体 — 新 Skill 兼容性**
"但是你上面的分析是不是只基于现有的superpowers skills 如果后续又安装了新的skill 可能就会有新的冲突点 你觉得这个问题应该怎么解决呢? 是不是需要一个更系统的兼容框架 来评估和管理这些潜在的冲突?"
→ 是的，§ 2 是静态分析。但发现规律：冲突严重程度 ∝ skill 触碰的 baton 控制点数量。
→ 5 个控制点（计划位置、审批门、状态跟踪、执行边界、完成流程）是有限可枚举的。
→ 解法不是逐 skill 路由表（不可扩展），而是**控制点防御规则**：声明 5 个控制点不可被 skill 覆盖，新 skill 自动兼容。
→ Path C 升级为双层防御：Layer 1 Complexity Calibration（入口过滤）+ Layer 2 控制点防御（运行时护栏）
→ 新增 § 7 详述此模型。

**[Q] § 7 — 适配层方案**
"还有更好的方案吗？比如说在Baton中引入一个适配层，专门负责协调Baton和Superpowers之间的交互，确保它们能够无缝协作而不是相互冲突？"
→ 评估了适配层 vs 控制点防御（§ 7.5）。适配层理论上整合更深，但在 Claude Code 纯指令环境下退化为更复杂的 CLAUDE.md 指令集，且丧失自动兼容新 skill 的优势。
→ 混合方案：通用 skill 靠控制点防御（Layer 2），高价值 skill（TDD、code review）靠定点整合规则（Layer 3）
→ Path C 升级为三层模型（§ 7.6）：入口过滤 + 运行时护栏 + 可选的定点整合

## § 6. Supplement: Community & Academic Research

### 6.1 多 Agent 编排模式（工业实践）

**Kore.ai 多 Agent 架构模式**（2024-2025 业界总结）：

三种主流模式：
| 模式 | 特点 | Baton 关联 |
|------|------|-----------|
| **Supervisor**（集中式） | 中央 agent 分派任务、收集结果、做最终决策 | ✅ Baton 的 Complexity Calibration + 人类门控 = 类似 supervisor 角色 |
| **Adaptive Network**（去中心化） | Agent 之间直接通信，实时协调 | ❌ Superpowers 的 skill 链更接近此模式，缺乏中央控制 |
| **Custom/Programmatic**（代码编排） | 硬编码 agent 调用顺序 | 🟡 中间路线：用配置而非代码定义调用规则 |

关键发现：Supervisor 模式在需要可追溯性和质量保证的场景下表现最好，但 token 消耗比 Adaptive 高 ~200%。**Path C（编排协议）属于 Supervisor 模式的变体**——人类 + baton 共同担任 supervisor 角色。

---

### 6.2 学术研究：指令优先级层级

**"The Instruction Hierarchy" (arxiv 2404.13208, OpenAI/Microsoft, 2024)**

这篇论文建立了 LLM 指令的优先级模型：

```
System prompt > Developer instructions > User instructions > Third-party tool output
```

核心发现：
- 当不同层级的指令冲突时，应优先遵循更高层级
- 模型可以被训练来识别并拒绝低优先级指令对高优先级指令的覆盖

**对 Baton 的启示**：
- ✅ Claude Code 文档确认 `CLAUDE.md project instructions > plugin skill instructions`
- ✅ 这意味着 baton（通过 CLAUDE.md 加载）理论上优先于 superpowers skill
- ❓ 但 Plan 2 实践中 skill 仍被无条件触发——说明**优先级机制存在但不完善**：skill 的触发逻辑（"1% chance → MUST invoke"）在行为层面覆盖了 baton 的 Complexity Calibration
- 💡 解法：在 CLAUDE.md 中**显式声明** skill 选择规则，让优先级机制生效。不能依赖隐式优先级。

---

### 6.3 社区实践：claude-code-workflows 项目

**shinpr/claude-code-workflows**（GitHub 社区项目，2025）

这是目前最接近「baton + superpowers 冲突解决」的实践案例。核心设计：

**架构分层**：
```
orchestration/          ← 编排层（agents + recipes + workflow state）
  agents/               ← requirement-analyzer, code-implementer, reviewer...
  recipes/              ← 预定义任务流
knowledge/              ← 知识层（skills + best practices）
  skills/               ← 具体执行技能
  coding-rules/         ← 代码规则库
```

**关键机制**：
1. **requirement-analyzer agent**：接收任务后先分析复杂度，决定激活哪些 skill/agent
2. **rule-advisor agent**：根据代码上下文动态选择适用的 coding rules
3. **互斥约束**：通过 agent 定义中的 `requires` / `conflicts` 字段防止冲突 skill 同时激活

**对 Baton 的启示**：
- ✅ **验证了 Path C 方向**：复杂度分析 → 动态 skill 选择 正是这个项目的核心做法
- ✅ **分层思路一致**：orchestration（baton）与 knowledge（skills）分离
- 💡 **可借鉴**：`requirement-analyzer` 的角色可以映射到 baton 的 Complexity Calibration 扩展
- 💡 **可借鉴**：互斥约束声明——在 baton 中可以声明 "当 baton 活跃时，writing-plans / executing-plans 不触发"

---

### 6.4 复杂度路由模式（工业实践）

**Shipyard/ruflo 等 AI 工作流平台**（2024-2025）：

复杂度路由（complexity-based routing）已成为生产级 AI 系统的标准模式：

| 复杂度 | 路由策略 | 对应 Baton Path C |
|--------|---------|------------------|
| Simple | 跳过 LLM 或用最轻量模型 | Trivial：不触发 skill |
| Medium | 标准模型 + 基础验证 | Small/Medium：选择性触发 TDD / code review |
| Complex | 最强模型 + 多阶段验证 + 人类审查 | Large：subagent 并行 + 完整 review 链 |

关键发现：
- 无差别使用最重方案（equivalent to always triggering all skills）导致成本/时间增长 3-5x，且不一定提高质量
- 最有效的系统在**入口处做一次性复杂度判断**，后续所有路由基于此判断

**对 Baton 的启示**：
- ✅ Baton 已有 Complexity Calibration（Trivial/Small/Medium/Large），这是天然的路由入口
- 💡 将 Complexity Calibration 从「控制 baton 自身深度」扩展为「同时控制 skill 选择」，与工业实践完全对齐

---

### 6.5 学术研究：LLM Agent 编排的控制面

**"A Survey of LLM Agent Orchestration" (arxiv 2601.13671, 2025)**

该综述提出多 agent 系统的「控制面」概念：

```
控制面 = Planning Unit + Control Unit + Validation Layer
```

- **Planning Unit**：任务分解 + 资源分配（≈ baton 的 research → plan → todolist）
- **Control Unit**：执行调度 + 状态监控（≈ baton 的 phase guidance + Complexity Calibration）
- **Validation Layer**：结果验证 + 质量保证（≈ baton 的 Evidence Standards + skill 的 code review）

核心发现：
- 缺乏统一控制面的多 agent 系统表现出**协调失败**（coordination failure）——agent 之间目标不对齐、状态不同步
- 成功的系统都有**单一事实源**（single source of truth）供所有 agent 参考

**对 Baton 的启示**：
- ✅ plan.md 已经是 single source of truth（所有 agent 应读取 plan.md 的 todolist）
- ❌ 当前问题：superpowers 的 TodoWrite API 创建了第二个事实源 → 协调失败
- 💡 Path C 的关键实现要点：确保所有 skill 的执行状态回写到 plan.md 的 `## Todo`，而非创建独立跟踪

---

### 6.6 综合结论

外部研究从三个维度验证了 Path C（编排协议）方向：

| 维度 | 外部证据 | Path C 对应设计 |
|------|---------|----------------|
| **指令优先级** | CLAUDE.md > plugin skill（学术 + 平台文档） | 在 CLAUDE.md 显式声明 skill 选择规则 |
| **复杂度路由** | 入口处一次性判断，后续自动路由（工业实践） | 扩展 Complexity Calibration 为 skill 路由表 |
| **控制面统一** | 单一事实源 + supervisor 模式（学术综述） | plan.md 为唯一状态源，baton 为 supervisor |
| **分层架构** | orchestration 与 knowledge 分离（社区实践） | baton = orchestration, skills = knowledge |

❓ **未验证**：尚无社区项目同时使用 baton 和 superpowers 的实际案例。上述结论是从相似问题空间的解决方案推导而来，非直接实证。

---

## § 7. 新 Skill 兼容性：控制点防御模型

### 7.1 问题

§ 2 的冲突分析基于当前 14 个 superpowers skills。新 skill 安装后可能引入新冲突，逐 skill 维护路由表不可扩展。

### 7.2 观察：冲突只发生在控制点

回看 § 2，所有冲突都可归因于 skill 触碰了 baton 的某个**控制点**：

| # | Baton 控制点 | 含义 | 触碰时的后果 |
|---|-------------|------|-------------|
| 1 | **计划位置/格式** | plan.md / plan-\<topic\>.md，结构含 批注区 | skill 写到别处 → hooks 失效、人类找不到 |
| 2 | **审批门** | `<!-- BATON:GO -->` 人类放置后才能写代码 | skill 绕过 → 未经审批的代码变更 |
| 3 | **状态跟踪** | `## Todo` + `- [ ]` checkboxes | skill 用 TodoWrite 等替代 → 双重跟踪、状态不一致 |
| 4 | **执行边界** | 只修改计划列出的文件；发现遗漏须停下 | skill 自主扩展范围 → 失控 |
| 5 | **完成流程** | Retrospective → 归档到 plans/ | skill 走 merge/PR → 跳过知识沉淀 |

验证（§ 2 数据）：
- 🔴 writing-plans：触碰 #1 #2 #3（3/5）
- 🔴 executing-plans：触碰 #3 #4 #5（3/5）
- 🔴 subagent-driven-development：触碰 #3 #4 #5（3/5）
- 🟢 TDD：触碰 0/5
- 🟢 code review：触碰 0/5
- ⚪ worktrees：触碰 0/5

**规律成立**：冲突严重程度 ∝ 触碰控制点数量。

### 7.3 解法：控制点防御规则

不需要逐 skill 路由表。在 CLAUDE.md 中声明一条通用规则：

> 当 baton workflow 活跃时，任何 skill 的指令若与以下控制点冲突，以 baton 为准：
> 1. 计划文件位置和格式以 baton 约定为准
> 2. 代码写入须有 BATON:GO
> 3. 任务跟踪使用 `## Todo` checkboxes
> 4. 只修改计划列出的文件
> 5. 完成后走 baton 归档流程

这条规则的优势：
- **不需要认识每个 skill**——只检查行为是否侵入控制点
- **新 skill 自动兼容**——不触碰控制点的 skill（TDD、debugging、worktree）直接放行
- **利用指令优先级**——CLAUDE.md > plugin skill（§ 6.2 已验证）
- **与 Complexity Calibration 互补**——Calibration 决定"触发哪些 skill"，控制点防御决定"skill 运行时不能做什么"

### 7.4 Path C 修订：双层防御

原 Path C 只有 Complexity Calibration 路由（什么时候用什么 skill）。加入控制点防御后变成双层：

```
Layer 1: Complexity Calibration → 决定激活哪些 skill（入口过滤）
Layer 2: 控制点防御规则 → 约束已激活 skill 的行为边界（运行时护栏）
```

Layer 1 解决「不该触发的 skill 被触发」（Plan 2 的问题）。
Layer 2 解决「即使触发了冲突 skill，它也不能覆盖 baton 的核心控制」（未来新 skill 的问题）。

### 7.5 替代方案评估：适配层 vs 控制点防御

**适配层方案**：在 baton 中引入翻译规则，把 skill 的输出转换为 baton 格式：
- TodoWrite → 写入 plan.md `## Todo`
- `docs/plans/` → 重定向到 plan.md
- code review 结果 → 追加到 Annotation Log

**评估**：

| 维度 | 适配层 | 控制点防御 |
|------|--------|-----------|
| 整合深度 | 深——skill 产出融入 baton 文档体系 | 浅——skill 被约束但不融入 |
| 实现方式 | CLAUDE.md 中每个 skill 写翻译规则 | CLAUDE.md 中 5 条通用禁令 |
| 新 skill 兼容 | 需手写新翻译规则 | 自动兼容 |
| 指令复杂度 | 高（N 条规则 × M 个 skill） | 低（5 条固定规则） |
| 前提条件 | 需要程序化 hook 或详细了解每个 skill 的行为 | 不需要了解 skill 内部 |

**结论**：在 Claude Code 的纯指令环境下（无程序化中间件），适配层退化为更复杂的 CLAUDE.md 指令集，且丧失自动兼容新 skill 的优势。

**但有一个有价值的混合方案**：对少数高价值 skill（TDD、code review）写**定点整合规则**，其余 skill 靠控制点防御自动管理。

### 7.6 Path C 最终架构：三层模型

```
Layer 1: Complexity Calibration    → 入口过滤：什么时候激活什么 skill
Layer 2: 控制点防御规则            → 运行时护栏：5 条通用禁令，新 skill 自动兼容
Layer 3: 定点整合规则（可选）       → 深度整合：高价值 skill 的产出回流到 baton 文档
```

Layer 3 示例（仅对确认有价值的 skill）：
- code review → 发现的问题记入 plan.md Annotation Log 或 `## Code Review` 节
- TDD → 测试通过/失败状态映射到 `## Todo` 对应条目的 ✅/❌

Layer 3 是**可选的、渐进式的**——先部署 Layer 1 + 2，根据实际使用反馈再决定哪些 skill 值得写 Layer 3 规则。

---

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->
[Q] 
    1.经过你多次任务的实践 你认为Baton的定位是什么?
[NOTE]
    1.不能修改第三方plugin
    2.目前感觉TDD和code review的外审价值较大 但也需要评估它们的使用频率和实际效果

[DEEPER]
    2.你认为Baton往哪个方向发展更好呢?
[RESEARCH-GAP]
    1.还有最佳的路线吗? 是否可以检索一下社区对于类似问题的讨论或者其他团队的实践经验 或者相关的学术研究
[Q]
    3.但是你上面的分析是不是只基于现有的superpowers skills  如果后续又安装了新的skill 可能就会有新的冲突点 你觉得这个问题应该怎么解决呢? 是不是需要一个更系统的兼容框架 来评估和管理这些潜在的冲突?
[Q]
    1.还有更好的方案吗？比如说在Baton中引入一个适配层，专门负责协调Baton和Superpowers之间的交互，确保它们能够无缝协作而不是相互冲突？
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

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->

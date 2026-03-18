# 改进计划：absorb-superpowers-hooks session 复盘

**来源**：2026-03-18 session 复盘
**范围**：AI 执行流程改进，非代码变更

---

## P0: 测试执行策略

**问题**：直接跑完整测试套件（58+ 断言 × ~15s），在 Windows Git Bash 上 15-20 分钟，反复 TaskOutput 轮询堆积十几个后台任务，严重阻塞实施流程。

**根因**：没有区分"验证逻辑正确性"和"回归测试"两个目标。前者秒级可完成，后者才需要完整套件。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | 关键逻辑用纯命令行单元验证（jq 管道、printf 输出、grep 断言） | 每个 Todo item 的 Verify 步骤 | 秒级反馈 |
| 2 | 完整套件只在最终回归时跑，且用 `run_in_background` 不阻塞 | Item 5（回归验证） | 不阻塞主流程 |
| 3 | 完整套件超过 2 分钟没结果 → 立即切换到隔离验证，不轮询等待 | 等待超时 | 避免时间黑洞 |
| 4 | Todo item 的 Verify 字段应优先写单元级命令，集成测试作为补充 | 生成 Todo list 时 | 从源头避免慢验证 |

---

## P0: Research 质量 — 为什么用了 skill 反而更差

### 第一性原理分析

**观察到的现象**：

1. Chat 自由研究阶段：产出详细对比表（6 维度）、5 个具体改进点（含代码示例）、优先级建议表
2. 使用 baton-research skill 写文档后：内容变为抽象总结，丢失了代码片段、对比细节、具体数据
3. 用户批注："chat 里面相关的分析都没进这个文档呀"

**问题拆解 — 质量下降发生在哪个环节？**

不是 skill 本身有问题。skill 提供的是结构（Frame → Orient → Investigate → Self-Challenge）。问题出在 **AI 如何使用 skill** — 具体是两个失误叠加：

**失误 A：时序错误 — 分析已完成后才启动 research skill**

本 session 的实际流程：
```
chat 自由分析（丰富）→ 用户说"制定实施计划" → 才 invoke research skill → 重写一份文档
```

此时分析已经完成，invoke skill 变成了一个"补文档"的动作。AI 的行为模式切换为"把已有结论填入模板"，而不是"用 skill 的方法论指导新的调查"。模板变成了约束而非工具。

**失误 B：模板填充思维 — 把 skill 当表格填，而非当方法论用**

当 research skill 被 invoke 时，AI 看到模板的章节标题（Move 1, Move 2, ...），就开始"往格子里填内容"。这导致：
- 原本丰富的分析被压缩进固定框架
- 为了"符合模板格式"而重写措辞，丢失了原始的具体性
- 模板中没有的内容（如"5 个值得吸收的设计点"这种 chat 中自然产出的结构）被丢弃

### 根因结论

**skill 是方法论，不是模板。** 当 AI 把 skill 当模板填时，skill 反而降低质量 — 因为 AI 把注意力从"深度分析"切换到了"格式合规"。

### 改进方案：两阶段分离 — 自由探索 + 框架增强

**核心思路**（来自用户批注 4）：研究分两阶段，职责分离。

#### 阶段 1：自由探索（发散）

AI 自由发挥，不受 research skill 模板约束。目标是产出尽可能丰富的原始分析。

可选方式：
- 直接 chat 探索（本 session 初始研究的方式 — 效果好）
- 使用 superpowers brainstorming skill（结构化发散）
- 使用 Agent 并行调查多个方向
- 任何能产出高质量分析的方式

**这个阶段不 invoke baton-research skill。** 因为 skill 在这个阶段的作用是约束而非增强 — 它会让 AI 从"深度思考"切换到"填模板"。

#### 阶段 2：框架增强（收敛）

用 baton-research 的思维框架**审视和增强**阶段 1 的产出，而非重写。

框架的作用是**质量检查清单**，不是模板：
- ✅ 有没有明确的问题定义（Frame）？→ 没有就补
- ✅ 证据标签全了吗？`[CODE]`/`[DOC]`/`[RUNTIME]` + 状态 → 缺的标上
- ✅ 做了 counterexample sweep 吗？→ 没有就补一轮
- ✅ Self-Challenge 做了吗？够深吗？→ 没有就补
- ✅ 多个来源的发现是否做了 reconciliation？→ 冲突的地方标出来
- ✅ 结论能追溯到具体证据吗？→ 不能的标 `❓`

**增强过程保留原始分析的结构和内容**。如果阶段 1 用了"5 个改进点"这种结构，阶段 2 保留它，不强制改成 "Move 1/Move 2"。

#### 最终方案：A+C（两阶段分离 + review dispatch）

`[HUMAN]✅` 用户确认采用此方案。

**阶段 1：自由探索** → **阶段 2：框架增强** → **阶段 3：review dispatch 兜底**

| 阶段 | 做什么 | 防什么 |
|------|--------|--------|
| 1. 自由探索 | AI 自由发挥 / brainstorming skill / 并行 Agent | 防"模板填充"降低质量 |
| 2. 框架增强 | 用 baton-research 检查清单补盲点（证据标签、Self-Challenge、counterexample） | 补结构性盲点 |
| 3. review dispatch | baton-review 独立审查（context 隔离） | 防阶段 2 自我宽容或滑入重写 |

**阶段 2 的风险缓解**：
- AI 可能滑入"重写"模式 → 被阶段 3 的 review 兜住。即使阶段 2 做得不好，review 会指出信息丢失
- 两阶段边界模糊 → 阶段 1 在 chat 中完成，阶段 2 是"写入文档"的动作，边界自然清晰

**中期演进**：验证 A+C 效果后，可加入 Hook 门控（方向 D）自动化检查 research.md 结构完整性（进入 plan 前）。

---

## P1: Commit 后验证

**问题**：`git commit` 后没立即检查文件清单，5 个文件只提交了 2 个，用户在另一个 session 修复。

**根因**：Windows 上 git 路径处理可能静默失败，且 commit 后没有验证步骤。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | `git commit` 后立即 `git show --stat HEAD`，确认文件数与预期一致 | 每次 commit | 立即发现漏文件 |
| 2 | 文件数不对 → 立即排查（`git status`、`git diff HEAD -- <file>`），不继续 push | 文件数异常时 | 避免推送不完整 commit |
| 3 | commit 前 `git diff --cached --stat` 确认暂存区内容 | 每次 commit | 提前发现 staging 问题 |

---

## P2: 竞品分析覆盖配置差异

**问题**：分析 superpowers 时只关注代码逻辑（session-start 脚本、run-hook.cmd），漏掉了 hooks.json 的 `matcher: "startup|clear|compact"` 配置差异。用户在批注区发现并指出。

**根因**：代码文件和配置文件用同一种分析方式（看逻辑流程），但配置文件的价值在字段值差异，不在逻辑。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | 竞品对比时，代码文件和配置文件分开分析 | 分析涉及配置文件时 | 不遗漏配置差异 |
| 2 | 配置文件逐字段对比，输出差异表（字段名、我方值、对方值、是否值得吸收） | 配置文件分析阶段 | 系统化覆盖 |

---

## P1: 不在改进计划中无证据下结论

**问题**：跨 IDE 支持表中直接写了 Cursor/Codex/Factory 为 ❌，但没有实际验证证据。改进计划本身犯了 research 中同样的错误 — 无证据链就下结论。

**根因**：改进计划被当作"快速记录想法"而非"需要证据支持的文档"。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | 改进计划中的事实性断言必须标注证据标签（`[CODE]✅`/`❓`） | 写改进计划时 | 区分已验证和未验证 |
| 2 | 未验证的断言用 `❓` 而非 `❌`，明确标注"需要验证" | 写改进计划时 | 不把假设当结论 |
| 3 | 如果某个改进依赖于事实性前提，该前提必须有证据或标注为待验证 | 写改进计划时 | 改进计划本身经得起审查 |

---

## P2: 批注区格式纪律

**问题**：improvement-plan.md、research.md、plan.md 的早期批注区都没有使用 using-baton 定义的标准模板格式。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | 新建文档时，批注区直接包含模板注释提示格式 | 创建任何 baton 工作文档时 | 格式从一开始就正确 |
| 2 | 处理批注时，每条批注使用标准 Annotation 模板（Trigger/Intent/Response/Status/Impact） | 收到用户批注时 | 统一格式 |

---

## P2: 持续执行纪律

**问题**：BATON:GO + Todo list 已是授权，但仍频繁暂停问用户（"要 commit 吗？""要继续等还是先做其他事？"）。

**根因**：习惯性寻求确认，没有区分"需要人类判断的决策点"和"流程中的自然步骤"。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | Todo list 生成后连续执行到完成或阻塞，不在 item 之间暂停 | BATON:GO + Todo 存在 | 减少不必要交互 |
| 2 | 只在以下情况暂停：阻塞错误、C/D 级发现、3 次失败上限 | 执行期间 | 暂停有明确理由 |
| 3 | 里程碑更新用简短状态行（"Item 1-3 done, running item 4"），不用问句 | 完成 item 后 | 通知而非询问 |

---

## P1: Review 时应使用 baton-review 而非 superpowers code-reviewer

**问题**：实施阶段的 review（Todo list review、plan review）都 dispatch 了 `superpowers:code-reviewer`，而非 baton-review。在 baton-governed 项目中，baton-review 有 phase-specific 的 review-prompt.md，更精准。

**根因**：superpowers:code-reviewer 是"默认"选项（在 agent description 中提到"use after major step completed"），而 baton-review 需要主动识别当前是 baton 项目。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | baton 项目中，所有 review dispatch 使用 `/baton-review`（Skill 工具）或 Agent + baton-review review-prompt.md | 任何需要 review 的时刻 | 使用正确的 review 标准 |
| 2 | 只在非 baton 项目中使用 superpowers:code-reviewer | 非 baton 项目 | 不误用 |

---

## P1: Todo 即时标记完成 + Task 进度可视化

**问题**：
1. 完成 Todo item 后没有立即标记 `[x] ✅`，而是最后批量标记。用户无法实时了解进度。
2. Chat 中没有像截图那样的可视化进度（✓ 已完成 / ■ 当前 / □ 待办）。

**参考**：用户提供的截图显示了另一个 session 的执行效果 — 使用 Claude Code 的 Task 系统（TaskCreate/TaskUpdate）在 chat 中实时显示带勾选状态的任务列表。

**改进措施**：

| # | 措施 | 触发条件 | 预期效果 |
|---|------|----------|----------|
| 1 | 每完成一个 Todo item，立即用 Edit 将 `- [ ]` 改为 `- [x] ✅` | 每个 item 的 Verify 通过后 | plan.md 实时反映进度 |
| 2 | 实施开始时用 TaskCreate 为每个 Todo item 创建 Task | 开始执行 Todo list 时 | Chat 中显示可视化进度列表 |
| 3 | 每完成一个 item，用 TaskUpdate 标记 completed | 每个 item 完成后 | 进度条实时更新 |
| 4 | 开始执行某个 item 时，用 TaskUpdate 标记 in_progress | 开始每个 item 时 | 用户能看到当前在做什么 |

**跨 IDE 支持情况**：

TaskCreate/TaskUpdate 是 Claude Code 的 **工具**（Tool），不是 Hook 事件。它在 chat 中创建可视化的勾选进度列表。

| 能力 | Claude Code | Cursor | Codex | Factory |
|------|-------------|--------|-------|---------|
| TaskCreate/TaskUpdate（chat 内进度列表） | ✅ 原生工具 | ❓ 未验证 | ❓ 未验证 | ❓ 未验证 |
| plan.md 即时标记（Edit 工具） | ✅ | ✅ | ✅ | ✅ |

**证据链**：
- Claude Code: `[CODE]✅` — 本 session 可直接调用 TaskCreate/TaskUpdate 工具，确认存在
- Cursor: `[CODE]❓` — 未在 Cursor 环境中验证过此工具是否可用。Cursor adapter (`adapters/cursor/adapter.sh:5-10`) 列出了 Cursor 缺少的 **hook 事件**（completion-check, failure-tracker），但这是 hook 层面的限制，不等同于 Cursor 没有 Task 工具。**需要在 Cursor 环境中实际测试**
- Codex: `[CODE]❓` — 同上，Codex adapter 只说明了 hook 限制，未验证 Tool 层面。Codex 的工具集与 Claude Code 不同 `[DOC]❓`
- Factory: `[CODE]❓` — Factory 与 Claude Code 共用 settings.json 格式 `[CODE]✅` (setup.sh:641)，可能共享工具集，但未验证

**结论**：仅 Claude Code 确认支持。其他 IDE 需要实际环境验证 — 当前标为 `❓` 而非 `❌`。所有 IDE 都可用 plan.md 即时标记作为 fallback。

**Claude Code 其他可运用于 baton 的能力**：

| 能力 | 当前 baton 使用情况 | 潜在改进 | 证据 |
|------|---------------------|----------|------|
| **TaskCreate/TaskUpdate** | 未使用 | 实施阶段进度可视化（本章节） | `[CODE]✅` 本 session 可用 |
| **Agent (worktree isolation)** | baton-subagent 使用 | 已运用 | `[CODE]✅` |
| **EnterPlanMode** | 未使用（baton 有自己的 plan 流程） | 可考虑协同 | `[CODE]❓` 未验证兼容性 |
| **Hooks** | 核心使用 | 已运用 | `[CODE]✅` |
| **Memory (auto-memory)** | 部分使用 | 可系统化 | `[CODE]✅` |

→ 值得单独调研的方向：Cursor/Codex/Factory 的 Task 工具支持、EnterPlanMode 协同、Memory 整合。建议作为独立研究任务。

---

## 批注区

### [Annotation 1]
- **Trigger / 触发点**: research 的问题如何改进？给出具体且有效的最优方案
- **Response / 回应**: 已重写 Research 章节为 Chat-First → Document-Capture 模式
- **Status**: ✅ → 被 Annotation 5+6 进一步深化

### [Annotation 2]
- **Trigger / 触发点**: 执行过程中 review 时使用的还是 superpowers 的 code-reviewer
- **Response / 回应**: 新增 P1 章节 — baton 项目中所有 review 应使用 baton-review
- **Status**: ✅
- **Impact**: affects conclusions

### [Annotation 3]
- **Trigger / 触发点**: 执行完一个 todo 任务时没有马上标记完成，而是等到最后才一起标记
- **Response / 回应**: 新增 P1 章节 — 每完成一个 item 立即标记 `[x] ✅`，回退时可改回 `[ ]`
- **Status**: ✅
- **Impact**: affects conclusions

### [Annotation 4]
- **Trigger / 触发点**: 实现 todo 任务时能按截图中的方式显示进度吗（TaskCreate/TaskUpdate）
- **Response / 回应**: 已加入 P1 章节 — 使用 Claude Code Task 系统显示实时进度
- **Status**: ✅
- **Impact**: affects conclusions

### [Annotation 5+6]
- **Trigger / 触发点**: Research 章节写得有点死，缺乏分析过程；用了 skill 后研究结果反而比不用 skill 时差
- **Intent as understood / 理解后的意图**: 两条指向同一个根因 — 为什么使用 research skill 后质量反而下降
- **Response / 回应**: 用第一性原理重写了 Research 章节（升级为 P0）。拆解为两个失误叠加：时序错误（分析完后才 invoke）+ 模板填充思维（把 skill 当表格填）。改进方案分 3 场景（未开始/已完成/部分完成），强调 skill 是方法论不是模板
- **Status**: ✅
- **Impact**: affects conclusions — 升级为 P0

### [Annotation 7]
- **Trigger / 触发点**: research 章节的改进最好能根据 skill 的最佳实践来改进 不要太死
- **Intent as understood / 理解后的意图**: 改进方案不应是死规则，应该灵活运用 skill 方法论
- **Response / 回应**: 已重写改进方案为 3 场景模式（未开始/已完成/部分完成），强调 skill 是方法论指南而非模板
- **Status**: ✅
- **Impact**: affects conclusions — P0 Research 章节重写

### [Annotation 8]
- **Trigger / 触发点**: TaskCreate/TaskUpdate 系统是 Claude Code 的，其他支持的 IDE 有这个功能吗？
- **Intent as understood / 理解后的意图**: 确认跨 IDE 兼容性，避免写出只适用于 Claude Code 的方案
- **Response / 回应**: 已增加跨 IDE 支持表。TaskCreate/TaskUpdate 是 Claude Code 专有，其他 IDE 只能依赖 plan.md 即时标记
- **Status**: ✅
- **Impact**: affects conclusions — P1 Task 章节增加兼容性分析

### [Annotation 9]
- **Trigger / 触发点**: 还有其他类似的系统可以运用在 baton 中吗？
- **Intent as understood / 理解后的意图**: 全面梳理 Claude Code 能力，找到 baton 尚未利用的功能
- **Response / 回应**: 已增加 Claude Code 能力盘点表（EnterPlanMode、Memory 等）。建议 EnterPlanMode 协同和 Memory 整合作为独立研究任务
- **Status**: ✅
- **Impact**: clarification only — 产出后续研究方向

### [Annotation 10]
- **Trigger / 触发点**: 文档里面的批注区格式不对，这个文档包括同目录的其他文档
- **Intent as understood / 理解后的意图**: 批注区应使用 using-baton 定义的标准模板格式
- **Response / 回应**: 已将本文档批注区改为标准格式。research.md 和 plan.md 的批注区为早期写就，格式修复属于独立清理任务，不在本改进计划范围
- **Status**: ✅
- **Impact**: clarification only


### [Annotation 11]
- **Trigger / 触发点**: 批注区格式不对的问题我没看到改进方案
- **Response / 回应**: 新增 P2"批注区格式纪律"章节 — 新建文档时包含格式模板提示，处理批注时使用标准 Annotation 格式
- **Status**: ✅
- **Impact**: affects conclusions — 新增改进章节

### [Annotation 12]
- **Trigger / 触发点**: 跨 IDE Cursor/Codex/Factory 支持情况没有调查证据链
- **Response / 回应**: 重写跨 IDE 支持表，所有未验证项从 `❌` 改为 `❓`，每个 IDE 标注具体证据来源。Cursor/Codex/Factory 的 Task 工具支持需要在实际环境中验证
- **Status**: ✅
- **Impact**: affects conclusions — 修正了无证据的断言

### [Annotation 13]
- **Trigger / 触发点**: 无证据链就下结论的问题也需要给出改进方案
- **Response / 回应**: 新增 P1"不在改进计划中无证据下结论"章节 — 改进计划中的事实性断言也需要证据标签，未验证用 `❓` 不用 `❌`
- **Status**: ✅
- **Impact**: affects conclusions — 新增改进章节，且这正是改进计划自身犯的错误

### [Annotation 14]
- **Trigger / 触发点**: research 改进太死（固定 3 场景）。想法：让 AI 自由发挥探索，落文档时再用 baton-research 框架增强质量
- **Intent as understood / 理解后的意图**: 两阶段分离 — 阶段 1 自由探索（发散），阶段 2 用框架增强（收敛）。skill 的角色从"过程指南"变为"质量检查清单"
- **Response / 回应**: 已重写 P0 Research 改进方案为"两阶段分离"模式。分析了可行性：优势 4 点（保留 AI 自由探索最佳表现、框架只增强不替换、与现有 skill 兼容），风险 2 点（AI 滑入重写模式、阶段边界模糊）及缓解措施。结论：可行
- **Status**: ✅
- **Impact**: affects conclusions — P0 章节第三次重写

### [Annotation 15]
- **Trigger / 触发点**: research 两阶段分离的方案怎么样？基于这个两阶段分离有更好的改进吗？或者还有其他的更好改进？
- **Intent as understood / 理解后的意图**: 不要急着锁定方案，要从第一性原理枚举所有可能的解再比较
- **Response / 回应**: 见下方分析
- **Status**: ❓ — 待讨论
- **Impact**: 可能影响 P0 方案选择

#### 第一性原理分析

**核心矛盾**：AI 自由探索产出质量高（丰富、具体、有代码示例），使用 skill 后产出质量低（抽象、模板化）。但自由探索可能遗漏关键质量检查（counterexample sweep、证据标签、Self-Challenge）。

**约束条件**：
- 最终产出必须满足 baton 质量标准（证据标签、Self-Challenge、可追溯）
- 不能依赖 AI 自觉 — 需要机制保障
- 方案必须跨 session 一致（不依赖"这次记得"）

**解的空间**（4 个根本不同的方向）：

**方向 A：两阶段分离（当前方案）**
自由探索 → 框架增强。skill 作为阶段 2 的质量检查清单。
- 优：探索质量不受限
- 劣：阶段 2 仍然依赖 AI 自觉执行检查清单，可能滑入重写模式

**方向 B：Skill 提供问题而非结构**
不给模板，只在关键时刻抛出质量探测问题："你最弱的结论是什么？""什么证据能推翻这个？" AI 在自然行文中回答这些问题。
- 优：零格式开销，问题自然融入分析
- 劣：问题可能被敷衍回答（本 session 的 Self-Challenge Q3 就是例子）

**方向 C：Review 兜底，不改研究过程**
完全不约束研究过程。研究结束后 dispatch baton-review（context 隔离），review 用 research review-prompt.md 检查盲点并要求补充。
- 优：探索完全自由；review 的 context 隔离避免了"对自己宽容"
- 劣：review 可能发现大量缺失需要回填，效率较低

**方向 D：Hook 自动化质量门控**
用 hooks 自动检查 research.md 的结构完整性（有没有证据标签、有没有 Self-Challenge 节、有没有 counterexample）。质量不达标时阻止进入 plan 阶段。
- 优：机制保障，不依赖 AI 自觉
- 劣：只能检查结构（"有没有 Self-Challenge"），不能检查质量（"Self-Challenge 够不够深"）

#### 组合分析

单一方向都有短板。最优解可能是组合：

| 环节 | 机制 | 作用 |
|------|------|------|
| 研究过程 | **自由探索**（方向 A 阶段 1） | 保留 AI 最佳表现 |
| 落文档时 | **质量探测问题**（方向 B） | 轻量增强，不改结构 |
| 文档完成后 | **baton-review dispatch**（方向 C） | context 隔离的独立审查 |
| 进入 plan 前 | **Hook 门控**（方向 D） | 结构完整性自动检查 |

这个组合的核心优势：**每一层解决不同的失败模式**。
- 自由探索 → 防止"模板填充"降低质量
- 质量探测问题 → 轻量补盲点，不改写
- Review dispatch → context 隔离防止自我宽容
- Hook 门控 → 机制保障不依赖自觉

#### 对比两阶段分离

两阶段分离（方向 A）是这个组合的子集。它缺少了方向 C（review 兜底）和方向 D（hook 门控）。两阶段分离的最大风险（AI 在阶段 2 滑入重写模式）在组合方案中被方向 C 兜住 — 即使阶段 2 做得不好，review 会抓出来。

**建议**：
- 近期：采用两阶段分离 + review dispatch（A+C），验证效果
- 中期：如果效果好，加入 hook 门控（D）自动化结构检查
- 方向 B（质量探测问题）可以融入阶段 2 的检查清单，不需要独立实施

### [Annotation 16]
- **Trigger / 触发点**: 按两阶段分离 + review dispatch（A+C）来
- **Response / 回应**: 确认。已将 P0 Research 方案锁定为 A+C。更新正文方案。
- **Status**: ✅
- **Impact**: affects conclusions — P0 方案最终确定

<!--BATON:GO-->

## Todo

**Status: BLOCKED → 转为独立 task `baton-tasks/improve-baton-skills/`**
C-level discovery: 目标文件从 memory 改为 skill 文件，影响面需要独立 plan。

~~- [ ] 1. 更新 execution-patterns.md memory — 合并测试策略 + commit 验证~~
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/execution-patterns.md`
  Verify: `cat` 文件确认内容包含分层验证策略和 commit 验证规则
  Deps: none
  Artifacts: none

~~- [ ] 2. 新建 feedback memory~~ — Research 两阶段 A+C 模式
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/feedback_research_two_phase.md`
  Verify: `cat` 文件确认内容包含自由探索→框架增强→review dispatch
  Deps: none
  Artifacts: none

~~- [ ] 3. 更新 feedback_use_baton_review.md~~ — 扩展 review 工具选择规则
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/feedback_use_baton_review.md`
  Verify: `cat` 文件确认覆盖 plan review、Todo review、implementation review 场景
  Deps: none
  Artifacts: none

~~- [ ] 4. 新建 feedback memory~~ — 实施阶段进度可视化 + 持续执行纪律
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/feedback_implementation_discipline.md`
  Verify: `cat` 文件确认包含 TaskCreate/TaskUpdate 使用规则、即时标记、持续执行不暂停
  Deps: none
  Artifacts: none

~~- [ ] 5. 新建 feedback memory~~ — 竞品分析 + 无证据不下结论
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/feedback_evidence_discipline.md`
  Verify: `cat` 文件确认包含配置文件逐字段对比、证据标签要求
  Deps: none
  Artifacts: none

~~- [ ] 6. 更新 MEMORY.md 索引~~
  Files: `~/.claude/projects/C--Users-hexin-IdeaProjects-baton/memory/MEMORY.md`
  Verify: `cat` 文件确认新增 memory 文件都在索引中
  Deps: 1, 2, 3, 4, 5
  Artifacts: none
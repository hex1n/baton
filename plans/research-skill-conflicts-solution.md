# Research: Baton × Superpowers 兼容方案（我的设计）

## 工具使用记录

| 工具 | 用途 | 结果 |
|------|------|------|
| Read | 读取 `.baton/workflow.md` / `.baton/workflow-full.md` | 确认 Baton 已拥有 phase、审批门、Todo、Retrospective、研究义务 |
| Read | 读取 `.baton/hooks/*.sh` | 确认 Baton 的硬约束主要落在文件系统与 plan 状态，而不是 skill 调度 |
| Read | 读取 superpowers 相关 `SKILL.md` | 确认哪些 skill 在“编排任务”，哪些只是“执行纪律/工具” |
| Read | 读取 `research-skill-conflicts.md` / `research-skill-conflicts-review.md` | 继承前一轮冲突分析，并修正其证据薄弱点 |

## 核心判断

**我不会把 Baton 设计成“与 superpowers 平级协商的系统”。**

我会把 Baton 固定为**唯一编排层**，然后把 superpowers 拆成三类：

1. **编排型 skill**：禁止在 Baton 活跃时接管流程
2. **执行纪律 skill**：只能在 Baton 的 IMPLEMENT 阶段按需调用
3. **工具型 skill**：满足前提时可直接使用

原因很直接：
- Baton 已经明确定义了完整的阶段流转和单一事实源：`research.md → plan.md → BATON:GO → ## Todo → Retrospective`（`.baton/workflow.md:17-38`, `.baton/workflow.md:85-99`）。
- Baton 的 hook 也已经把这套状态机部分硬化了：`write-lock.sh` 依赖 `BATON:GO`（`.baton/hooks/write-lock.sh:83-98`），`phase-guide.sh` 依赖 `plan.md + GO + ## Todo` 判阶段（`.baton/hooks/phase-guide.sh:86-100`），`completion-check.sh` 依赖 `## Retrospective`（`.baton/hooks/completion-check.sh:35-48`）。
- 与 Baton 真正冲突的不是“skill 本身”，而是**另一套编排权**：`using-superpowers` 的 1% 强制触发（`.../using-superpowers/SKILL.md:7-24`）、`brainstorming → writing-plans` 的链式入口（`.../brainstorming/SKILL.md:24-31`, `.../brainstorming/SKILL.md:55-56`）、`writing-plans` 的自有计划格式与执行分流（`.../writing-plans/SKILL.md:18`, `.../writing-plans/SKILL.md:31-45`, `.../writing-plans/SKILL.md:97-116`）、`executing-plans` / `subagent-driven-development` 的 TodoWrite 与完成链（`.../executing-plans/SKILL.md:18-25`, `.../executing-plans/SKILL.md:45-50`, `.../subagent-driven-development/SKILL.md:56-62`）。

## 我的方案

### 1. Baton 是唯一编排层，不允许“双 orchestrator”

**规则**
- 当 Baton workflow 活跃时，以下 skill 一律不得自动触发：
  - `using-superpowers`
  - `brainstorming`
  - `writing-plans`
  - `executing-plans`
  - `subagent-driven-development`
  - `finishing-a-development-branch`

**依据**
- 这些 skill 都在定义自己的流程入口、计划格式、任务跟踪或完成语义（见上面的原始 skill 引用）。
- Baton 已经定义了自己的对应物：阶段流转、审批门、Todo、归档（`.baton/workflow.md:17-38`）。

**设计意图**
- 不是“限制 skill”，而是防止系统里出现第二个 workflow owner。
- 只要 Baton 活跃，就只能有一个 orchestrator。

### 2. 用“phase × skill class”矩阵，而不是只靠复杂度

我不会只做 `Complexity Calibration → 触发哪些 skill`，因为复杂度只能解决“要不要更多帮助”，不能解决“谁拥有流程”。

#### RESEARCH / PLAN / ANNOTATION
- 允许：
  - `using-git-worktrees`
  - `dispatching-parallel-agents`
  - `systematic-debugging`（仅当任务本质是 debug research）
- 禁止：
  - 所有编排型 skill
  - `test-driven-development`
  - `requesting-code-review`
  - `verification-before-completion`

**原因**
- 这三个阶段 Baton 已有完整协议，且要求研究/计划文件成为唯一事实源（`.baton/workflow-full.md:105-180`, `.baton/workflow-full.md:186-240`, `.baton/workflow-full.md:247-319`）。
- `brainstorming` 的“一次一个问题 + 多选 + docs/plans 设计文档 + 调用 writing-plans”是一整套替代研究/计划系统（`.../brainstorming/SKILL.md:27-31`, `.../brainstorming/SKILL.md:61-63`, `.../brainstorming/SKILL.md:81-87`）。

#### IMPLEMENT
- 允许：
  - `verification-before-completion`
  - `requesting-code-review`
  - `receiving-code-review`
  - `dispatching-parallel-agents`
  - `using-git-worktrees`
  - `systematic-debugging`
- 条件允许：
  - `test-driven-development` 只能在 plan/todo 明确要求“先写失败测试再实现”时启用
- 禁止：
  - 所有编排型 skill

**原因**
- `test-driven-development` 不是低风险通用 skill。它要求“写代码前先删掉已有实现，重新开始”（`.../test-driven-development/SKILL.md:37-45`）。这和 Baton plan 的语义可能冲突，所以不能按复杂度自动开。
- `verification-before-completion`、`requesting-code-review`、`receiving-code-review` 更像执行质量层，而不是流程接管层（`.../verification-before-completion/SKILL.md:3`, `.../requesting-code-review/SKILL.md:8-17`, `.../receiving-code-review/SKILL.md:3-18`）。

### 3. Prompt 只做软路由，真正的边界要落到 hook 的“硬产物约束”

这是我和现有 Path C 最大的差异。

现状里 Baton 有一个明显缺口：**Markdown 永远可写**（`.baton/workflow.md:30`, `.baton/hooks/write-lock.sh:55-57`），`post-write-tracker.sh` 也直接跳过所有 Markdown（`.baton/hooks/post-write-tracker.sh:36-39`）。

这意味着：
- `brainstorming` 可以写 `docs/plans/*-design.md`
- `writing-plans` 可以写 `docs/plans/YYYY-MM-DD-<feature>.md`
- Baton 的 source-code write lock 不会阻止它们，因为这些都是 Markdown

所以我会改成：

#### 3.1 收紧 Markdown 白名单

在 Baton 活跃时：
- **预实施阶段**（无 `BATON:GO`）只允许写：
  - `research*.md`
  - `plan*.md`
  - `plans/*` 归档
- **实施阶段**（有 `BATON:GO`）额外允许：
  - plan 中明确列出的文档文件

**结果**
- `docs/plans/*` 这类第三方规划产物会被物理拦下。
- Baton 不再只靠 prompt 说“不要写”，而是 hook 真正拒绝写。

#### 3.2 Markdown 也进入计划跟踪

当前 `post-write-tracker.sh` 对 Markdown 完全不跟踪（`.baton/hooks/post-write-tracker.sh:36-39`）。

我会改成：
- Baton 自有文档（当前 research/plan/归档）免跟踪
- 其他 Markdown 在 IMPLEMENT 阶段也要检查是否列在 plan 里

**结果**
- 文档修改不再是计划外逃逸口
- Baton 的“只改计划列出的文件”才真正覆盖 docs/markdown 工作

### 4. 只给少数高价值 skill 做“定点适配”，不做通用适配层

我不会做通用 adapter，把每个 skill 输出都翻译回 Baton。那会把规则复杂度做成 `skill 数 × 翻译规则数`。

我只会做 3 个定点适配：

1. **code review**
   - review 发现写回 `plan.md` 的 `## Annotation Log` 或 `## Code Review`

2. **verification**
   - 验证命令和结果写到对应 todo 项旁边，成为 Baton 文档的一部分

3. **TDD**
   - 只在 todo 明确要求时启用
   - 其 RED/GREEN 状态映射到 todo 的验证记录

**原因**
- `requesting-code-review` / `verification-before-completion` 的价值高且产出结构相对稳定（`.../requesting-code-review/SKILL.md:32-47`, `.../verification-before-completion/SKILL.md:33-34`）。
- `TDD` 的风险也高，所以必须显式接入，而不是默认放行。

## 为什么这比现有 Path C 更稳

### 1. 不再把“控制点”当成唯一冲突模型

`brainstorming` 的冲突不只是控制点，还包括交互模式和探索流（`research-skill-conflicts.md:101-106`）。
`TDD` 的冲突也不只是状态跟踪，而是方法论语义（`research-skill-conflicts.md:133-135`, `.../test-driven-development/SKILL.md:37-45`）。

所以我会用：
- **skill role** 解决“谁拥有流程”
- **phase matrix** 解决“什么时候能用”
- **hook invariants** 解决“即便 prompt 失效，也不能产出越界文件”

### 2. 不再把 prompt 优先级当成唯一依赖

现有研究已经承认：理论上 `CLAUDE.md > plugin skill`，但 Plan 2 现象上并未完全压住 `using-superpowers` 的 1% 触发（`research-skill-conflicts.md:407-411`）。

所以我的设计是：
- **prompt 层负责说清规则**
- **hook 层负责卡住错误产物**

如果 prompt 失效，`docs/plans/*` 仍然写不进去；这比单纯把规则写进 `workflow.md` 更可靠。

## 需要改哪些地方

### 必改
- `.baton/workflow.md`
  - 增加 skill 分类与 phase matrix
  - 明确 Baton 活跃时禁止编排型 skill
- `.baton/workflow-full.md`
  - 在各 phase 补充 allow/deny 规则
  - 在 IMPLEMENT 中补充 code review / verification / TDD 的写回规则
- `.baton/hooks/write-lock.sh`
  - 把“Markdown 永远可写”改为“Baton-owned Markdown 白名单”
- `.baton/hooks/post-write-tracker.sh`
  - 让 Markdown 也接受 plan 边界检查

### 可选
- `.baton/git-hooks/pre-commit`
  - 增加对 `docs/plans/*.md` 这类 Baton 外规划文档的告警或阻断

## 风险

1. **白名单过严**
   - 某些合法文档更新会先被挡住
   - 缓解：IMPLEMENT 阶段允许 plan 列出的 Markdown

2. **TDD 使用率下降**
   - 因为它不再被复杂度自动触发
   - 缓解：把 TDD 作为可显式选择的 plan 模板，而不是隐藏自动规则

3. **仍无法阻止 UI 内部的 TodoWrite**
   - 纯 hook 无法直接拦截非文件型状态
   - 缓解：把 Baton 文档明确为唯一事实源，TodoWrite 即使出现也只是辅助，不参与归档/完成判断（`.baton/workflow.md:85-99`, `.baton/hooks/phase-guide.sh:86-100`）

## 结论

如果让我自己设计，我会做的是：

**Baton 单编排层 + skill 分类矩阵 + hook 级硬产物约束 + 少量高价值适配。**

不是“让 Baton 和 superpowers 协商”，而是：
- Baton 永远拥有流程
- superpowers 只提供纪律和工具
- 一旦某个 skill 想写出 Baton 体系外的计划/设计/完成产物，hook 直接挡下

这套方案比“控制点防御 + prompt 规则”更稳，因为它承认一个现实：**prompt 会失手，文件系统不会说谎。**

## Self-Review

- 这套方案最激进的地方是收紧 Markdown 白名单，可能会让一些原本方便的 doc-only 流程变麻烦。
- 我最不确定的是 pre-commit 是否也需要硬阻断 `docs/plans/*`；这取决于你想要“强一致性”还是“低摩擦”。
- 如果后续发现 Baton 之外的 Markdown 产物其实经常有价值，可以把白名单做成“Baton-owned + plan-listed”二段式，而不是纯 Baton-owned。

## Questions for Human Judgment

- 你更偏向“强一致性”还是“低摩擦”？这决定 `docs/plans/*` 是告警还是直接阻断。
- 你想让 TDD 成为默认建议，还是明确 opt-in？我倾向后者，因为它的删除语义太强。

## 批注区
> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI 是继续补实现细节，还是直接出 plan

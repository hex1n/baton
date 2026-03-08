# 评审：HITL/HOTL 文档

**日期**: 2026-03-07
**范围**: 评审 `plans/research-2026-03-07-hitl-tools.md` 以及与之配套的方案 `plans/plan-2026-03-07-hotl.md`。

## 范围说明

用户输入里把同一个路径重复写了两次。我实际评审的是研究文档本身，以及与之配套的 HOTL 计划，因为计划文档是这组研究结论的具体延伸。

## 发现

### 1. 研究文档对产品定位的判断大体是对的

✅ 有证据支撑的强结论：

- 文档的核心差异化判断，与 Baton 当前工作流是一致的：Baton 不只是一个工具调用审批层，它更像是一套从研究到计划、审批、实现的工作流契约（`plans/research-2026-03-07-hitl-tools.md:227-232`, `plans/research-2026-03-07-hitl-tools.md:308-316`）。
- 这也和当前工作流定义吻合：研究/计划/批注/实现四个阶段、明确的行动边界、批注协议，以及 skill-first 的阶段入口（`.baton/workflow.md:14-19`, `.baton/workflow.md:29-39`, `.baton/workflow.md:48-57`）。

我的观点：这是这份研究里最强的一部分。“工作流，不只是单点闸门”这个定位框架是可信的，值得保留。

### 2. 研究文档高估了当前约束机制的硬度

❌ 有证据支撑的过度表述：

- 研究文档说 write-lock 是“技术强制，不可绕过（除 BATON_BYPASS=1）”，后面又把 Baton 描述成“确定性强制”（`plans/research-2026-03-07-hitl-tools.md:248-249`, `plans/research-2026-03-07-hitl-tools.md:285`）。
- 但实际钩子没有那么硬：
  - 遇到异常时是 fail-open，直接放行（`.baton/hooks/write-lock.sh:13-19`）
  - 目标路径解析失败时也是 fail-open（`.baton/hooks/write-lock.sh:46-52`）
  - markdown 写入始终允许（`.baton/hooks/write-lock.sh:55-58`）

我的观点：Baton 在正常路径上确实有实质性的约束力，但如果要按强合规语境去宣传成“硬门控”，这个表述并不准确。

### 3. HOTL 计划用了错误的控制原语：AI 自我认证

❌ 有证据支撑的核心设计风险：

- 计划提议让 AI 自己在 plan 里写 HOTL 元数据，例如 `<!-- HOTL: complexity=TRIVIAL confidence=0.96 -->`，然后钩子再根据这些元数据自动审批（`plans/plan-2026-03-07-hotl.md:71-93`）。
- 计划自己的风险章节也承认，最大风险就是 AI 会高估自己的 confidence（`plans/plan-2026-03-07-hotl.md:380-383`, `plans/plan-2026-03-07-hotl.md:389-392`）。

我的观点：这是最关键的弱点。一个监督机制不应该主要依赖模型自己给自己打分。这个更像自我背书，而不是 HOTL。

### 4. 这份计划把复杂度加到了最脆弱的约束点上

❌ 有证据支撑的架构风险：

- HOTL 提案要把更多解析和分支逻辑塞进 `write-lock.sh`（`plans/plan-2026-03-07-hotl.md:55-84`）。
- 但这个脚本本身就是核心闸门，而且已经存在 fail-open 路径（`.baton/hooks/write-lock.sh:13-19`, `.baton/hooks/write-lock.sh:46-52`）。
- OpenCode 适配器也没有复用 shell 钩子，而是自己在 JS 里重写了一套逻辑（`.baton/adapters/opencode-plugin.mjs:6-25`）。
- 即使还没上 HOTL，shell 钩子和 OpenCode 插件在 plan 文件名解析上也已经不一致：
  - shell 钩子会优先选最新的 `plan.md` 或 `plan-*.md`（`.baton/hooks/write-lock.sh:62-81`）
  - OpenCode 插件除非显式设置 `BATON_PLAN`，否则只认 `plan.md`（`.baton/adapters/opencode-plugin.mjs:12-23`）

我的观点：HOTL 会放大一个已经存在的漂移问题。在继续加更多策略分支之前，应该先统一约束入口。

### 5. 审计方向是对的，但有一个集成点定义得不够完整

❓ 有证据支撑但仍不完整：

- 计划希望在自动审批后，由 post-write tracking 写入审计记录（`plans/plan-2026-03-07-hotl.md:36-41`, `plans/plan-2026-03-07-hotl.md:104-132`）。
- 但当前的 `post-write-tracker.sh` 只有在 plan 已经包含 `<!-- BATON:GO -->` 时才会继续执行（`.baton/hooks/post-write-tracker.sh:58-59`）。
- 而 HOTL 设计的目标恰恰是允许 Trivial/Small 任务在没有 `BATON:GO` 的情况下写入（`plans/plan-2026-03-07-hotl.md:10-16`, `plans/plan-2026-03-07-hotl.md:80-84`）。

我的观点：如果要实现 HOTL，审计记录更合理的位置应该是在 `write-lock.sh` 的允许路径里直接记录，而不是把它当成当前 post-write tracker 的一个小扩展。

### 6. 研究文档的产品结论，比它的扩张冲动更好

✅ 有证据支撑的边界判断：

- 研究文档准确记录了用户给出的产品约束：可以引入 Node.js，但保持 CLI + markdown，目标用户是个人开发者，并继续保持独立（`plans/research-2026-03-07-hitl-tools.md:343-352`）。
- 它也明确否定了“做成完整平台”的方向，而是推荐更轻量的概念层/配置层方案（`plans/research-2026-03-07-hitl-tools.md:317-323`）。

我的观点：这个边界判断是对的。Baton 应该保持文件原生和轻量。如果要加 HOTL，也应该表现为“更紧的本地工作流”，而不是一次平台化转向。

## 补充：当前 Baton 算不算 Human-in-the-Loop？

### 工具盘点

本轮补充研究实际使用了这些检索手段：

- `rg` / `sed` / `nl`：用于检索和逐行核对 `.baton/workflow.md`、hooks、adapters、tests、`setup.sh`、skills。
- MCP resources：调用过 `list_mcp_resources`，返回空列表。
- MCP resource templates：调用过 `list_mcp_resource_templates`，返回空列表。
- Context7 / Web：本轮未使用，因为问题是“当前仓库实现是否属于 HITL”，主要证据都在本地代码中。

### 结论

我的判断是：

- ✅ 如果把 HITL 理解为“人类必须在关键执行边界进入闭环，AI 不能自行开始源码实现”，当前 Baton **算** HITL。
- ❌ 如果把 HITL 理解为“人类在实现过程中的每个关键决策周期都持续参与，且所有控制点都强制、一致、不可绕过”，当前 Baton **不算严格 HITL**。
- 🟡 更准确的说法是：**Baton 目前是一个以 `BATON:GO` 为核心的阶段式 HITL 系统，外围混有 advisory-only 控制、显式 bypass、fail-open 路径，以及跨 IDE 不一致的实现。**

下面分角度说明。

### 角度 1：在“批准后才能写源码”这个核心边界上，Baton 具备 HITL 核心

✅ 证据：

- 工作流规则明确要求源码写入必须有 `<!-- BATON:GO -->`，而且只有人类能放这个标记（`.baton/workflow.md:29-31`）。
- `write-lock.sh` 在没有 plan 时直接阻止写入，在 plan 存在但没有 `BATON:GO` 时也阻止写入（`.baton/hooks/write-lock.sh:83-98`）。
- Claude Code 安装面把 `write-lock.sh` 接到了 `PreToolUse` 写入相关 matcher 上（`setup.sh:974-980`, `.claude/settings.json:26-46`）。
- `baton-plan` 明确规定 “NO BATON:GO PLACED BY AI”，并把 `BATON:GO` 解释为人类批准实现的硬门（`.agents/skills/baton-plan/SKILL.md:12-22`）。
- `baton-implement` 也把 “NO CODE CHANGES WITHOUT BATON:GO” 作为铁律，并把计划视为实现契约（`.agents/skills/baton-implement/SKILL.md:11-20`）。
- Git pre-commit 还加了一层提交门控：没有 plan 或没有 `BATON:GO` 的源码提交会被拒绝（`.baton/git-hooks/pre-commit:36-47`）。

这意味着什么：

推论：在“AI 什么时候能开始真正改源码”这个最关键的控制点上，Baton 不是纯提示词系统，而是有人类审批闸门的。

### 角度 2：但它不是“严格、全流程、不可绕过”的 HITL

❌ 证据：

- `write-lock.sh` 明确存在 fail-open 路径：
  - 异常时直接放行（`.baton/hooks/write-lock.sh:13-15`）
  - 无法解析目标路径时直接放行（`.baton/hooks/write-lock.sh:46-52`）
- `BATON_BYPASS=1` 会显式跳过写入门控（`.baton/hooks/write-lock.sh:16-19`），pre-commit 也同样允许 bypass（`.baton/git-hooks/pre-commit:6-7`）。
- Markdown 始终可写，不需要审批（`.baton/hooks/write-lock.sh:55-58`, `.baton/workflow.md:30`）。
- 测试套件把这些行为当作预期，而不是 bug：
  - “No target path → fail-open” 被作为通过条件测试（`tests/test-write-lock.sh:126-139`）
  - `BATON_BYPASS=1` 跳过锁也是显式测试场景（`tests/test-write-lock.sh:155-177`）

这意味着什么：

推论：Baton 的核心门控是“默认阻止 + 允许人工批准”，但它不是强合规意义上的不可绕过闸门。更准确地说，它是**有明确逃生口和容错放行的 HITL**。

### 角度 3：很多外围控制点只是 advisory，不构成严格的人类在环

❌ 证据：

- `post-write-tracker.sh` 在文件不在计划中时只警告，不阻止继续，而且脚本头部明确写着 “advisory only” 与 “Always exit 0”（`.baton/hooks/post-write-tracker.sh:2-9`, `.baton/hooks/post-write-tracker.sh:61-68`）。
- `bash-guard.sh` 对可能写文件的 Bash 命令也只是提醒，“never blocks, only warns”（`.baton/hooks/bash-guard.sh:2-5`, `.baton/hooks/bash-guard.sh:37-40`）。
- `stop-guard.sh` 只在停止时提醒未完成项，脚本头部明确写 “never block the stop action”（`.baton/hooks/stop-guard.sh:2-6`, `.baton/hooks/stop-guard.sh:41-54`）。
- `subagent-context.sh` 和 `pre-compact.sh` 都是上下文注入，不能阻止动作（`.baton/hooks/subagent-context.sh:5-9`, `.baton/hooks/pre-compact.sh:5-9`）。
- `completion-check.sh` 确实会阻止 `TaskCompleted`，但它只检查“全部 todo 完成后是否写了 `## Retrospective`”，不是在运行中做人类审批（`.baton/hooks/completion-check.sh:41-52`）。
- `workflow.md` 中“同一路径失败 3 次必须停下”和“发现遗漏必须停下更新 plan”是规则文本，但当前没有对应 runtime hook 去普遍强制这些行为（`.baton/workflow.md:34-35`）。

这意味着什么：

推论：当前 Baton 的“人在环”主要集中在**进入实现前的审批**，而不是实现过程中的每一步监督。实现过程里的很多 guardrail 仍是“提醒型”，不是“阻断型”。

### 角度 4：一旦 `BATON:GO` 被放置，监督粒度会明显下降

❌ 证据：

- `write-lock.sh` 只检查 plan 是否存在 `BATON:GO`；一旦有这个标记，就直接 `exit 0`，没有按 todo、按文件、按 diff、按风险重新审查（`.baton/hooks/write-lock.sh:90-92`）。
- `post-write-tracker.sh` 虽然会检查文件名是否出现在 plan 里，但命中异常也只是 stderr 警告（`.baton/hooks/post-write-tracker.sh:61-66`）。
- `stop-guard.sh` 的实现关注的是“还有多少 todo 没做完”或“是否该写 Retrospective”，而不是人类是否实际复核了输出（`.baton/hooks/stop-guard.sh:36-54`）。

这意味着什么：

推论：当前 Baton 更像“**人类审批一次实现意图，AI 在这个批准窗口内自主执行**”。这仍然属于 HITL 的一个变体，但不是“每个实现决策都要人类点头”的那种强 HITL。

### 角度 5：跨 IDE / 工具面的实现不一致，会削弱“Baton 整体都是严格 HITL”这个说法

❌ 一致性矩阵（直接证据）：

| 表面 | 写入前阻断 | 其他控制 | 评估 |
|------|-----------|---------|------|
| Claude Code | `write-lock.sh`（`setup.sh:974-980`, `.claude/settings.json:26-46`） | 还有 `post-write-tracker`、`stop-guard`、`subagent-context`、`completion-check`、`pre-compact`（`.claude/settings.json:37-91`） | 最完整 |
| Cursor | `adapter-cursor.sh` → `write-lock.sh`（`setup.sh:1148-1151`） | 只有 `sessionStart`、`subagentStart`、`preCompact`，没有 post-write / stop / completion（`setup.sh:1148-1151`） | 部分 HITL |
| Windsurf | `write-lock.sh`（`setup.sh:1193-1195`） | 有 `bash-guard`、`post-write-tracker`，但没有 stop / completion / subagent / pre-compact（`setup.sh:1193-1195`） | 部分 HITL |
| Cline | `adapter-cline.sh`（`setup.sh:1213-1216`） | 还有 `TaskComplete` wrapper，但无独立 `phase-guide` / `stop-guard` / `post-write-tracker` 接入（`setup.sh:1213-1216`） | 部分 HITL |
| Augment | `write-lock.sh`（`setup.sh:1230-1244`） | 只有 `SessionStart` + `PreToolUse`（`setup.sh:1230-1244`） | 较弱 |
| Kiro / Amazon Q surface | `write-lock.sh`（`setup.sh:1257-1273`） | 只有 `preToolUse`（`setup.sh:1257-1273`） | 最小门控 |
| Copilot | `adapter-copilot.sh`（`setup.sh:1286-1301`） | 只有 `sessionStart` + `preToolUse`（`setup.sh:1286-1301`） | 较弱 |
| Codex CLI | 无 hooks（`setup.sh:1318-1334`） | 只有 `AGENTS.md` 规则注入（`setup.sh:1320-1334`） | 规则型，不是强制型 |
| Zed | 无 hooks（`setup.sh:1337-1345`） | 只有 `.rules` 文本（`setup.sh:1339-1345`） | 规则型，不是强制型 |
| Roo Code | 明确写着 “rules-guidance only” （`setup.sh:1349-1355`） | 无 runtime hook（`setup.sh:1349-1355`） | 规则型，不是强制型 |
| OpenCode | JS 插件里有独立写入门控（`.baton/adapters/opencode-plugin.mjs:6-25`） | 但它不复用 shell hook，且 plan 解析逻辑与 shell 版不完全一致（`.baton/hooks/write-lock.sh:62-81`, `.baton/adapters/opencode-plugin.mjs:12-23`） | 单独实现，存在漂移风险 |

这意味着什么：

推论：如果讨论的是“Claude Code 里的 Baton”，它很接近一个有硬门控的 HITL 工作流。如果讨论的是“Baton 这个项目跨所有 IDE surface 的统一性质”，那它更像**部分技术强制 + 部分规则注入 + 部分提醒型控制的混合系统**。

### 角度 6：反例检查

为了避免结论偏到一边，我专门做了反例检查：

- 反例 A：“Baton 根本不是 HITL。”
  - 反驳证据：`write-lock.sh` 会拦截无 plan / 无 GO 的源码写入（`.baton/hooks/write-lock.sh:83-98`）；pre-commit 会阻止无 GO 的源码提交（`.baton/git-hooks/pre-commit:36-47`）；`baton-plan` 明确规定只有人类可加 `BATON:GO`（`.agents/skills/baton-plan/SKILL.md:15-22`）。
  - 结论：这个反例不成立。Baton 不是“纯建议式流程”。

- 反例 B：“Baton 是严格的、纯粹的 HITL。”
  - 反驳证据：fail-open、`BATON_BYPASS=1`、Markdown 永久豁免、多个 advisory-only hooks、跨 IDE 只有部分 surface 有 runtime gate（见上文各节）。
  - 结论：这个反例也不成立。Baton 不是“全程强制、不可绕过、全 surface 一致”的 HITL。

### 补充结论

综合当前仓库实现，我会把 Baton 定义为：

> **一个以 `BATON:GO` 人类审批为核心的阶段式 HITL 工作流。**
>
> 它在“是否允许开始写源码”这个边界上有真实的 HITL 门控；
> 但在实现过程监督、异常处理强制性、跨 IDE 一致性、以及不可绕过性上，
> 仍然保留了明显的 advisory / bypass / fail-open 成分。

如果你要更严格地命名，我不建议把当前 Baton 叫做“严格 HITL 系统”；更准确的叫法是：

- **phase-gated HITL**
- **plan-first HITL workflow**
- **HITL core with advisory perimeter**

## 观点

我认同这份研究文档的核心命题，但不认同当前这版 HOTL 机制。

好的部分在于定位：Baton 最强的地方，是它定义了一套协作协议，而不是去逐项模仿 LangGraph 或 HumanLayer 的功能。薄弱的部分在于，它从这个命题直接跳到了“AI 在 plan 里写置信度标记，然后钩子选择相信它”。这个改动会削弱 Baton 最有区分度的地方，也就是对写入边界的人类显式控制。

如果目标是向 HOTL 演进，我不会从“由置信度驱动的自动审批”开始。我会按这个顺序做：

1. 先补强今天的 HITL 闸门：减少 fail-open，或者至少把 fail-open 变成可观测、可审计的行为。
2. 先统一各适配器的语义，尤其是 OpenCode 和 shell 钩子的行为。
3. 先加机器可读的审计日志。
4. 然后才去试验 HOTL，而且要做得窄、做得由人类显式开启：
   - 按文件类别或任务类别显式启用
   - 只覆盖文档、测试、机械性重构这类低风险改动
   - 不以 AI 自报 confidence 作为主要依据

## 需要人类判断的问题

- 当前的首要目标，是提升个人开发效率，还是强化“受治理的 AI 编码”这个产品定位？这会导向两种不同的 HOTL 设计。
  - 强化“受治理的 AI 编码”
- 你是否接受让模型自己声明 confidence，还是希望 auto-approval 必须由人类显式选择某个模式后才生效？
  - auto-approval 必须由人类显式选择某个模式后才生效
- Baton 更应该优化为“先审批意图，事后审代码”，还是“按范围逐步审批输出”？这才是 HOTL 讨论背后的真实策略选择。
  -先审批意图，事后审代码

## 自我审查

- 最强结论：当前 HOTL 提案依赖 AI 自我认证，这一点有计划文本直接支撑。
- 最弱结论：“审计应该放在 write-lock 里”属于架构判断，不是严格事实。
- 什么会改变我的看法：如果有证据表明，预期的 HOTL 模式是“每次会话由人类显式开启”，而不是日常流程中由 AI 静默声明。

## Annotation Log

### Round 1

**[DEEPER] § 全局**
"目前的baton是一个 human in the loop吗? 多角度系统分析"

→ 已补充 `## 补充：当前 Baton 算不算 Human-in-the-Loop？`

→ 结论：
- 在“源码写入前必须有人类批准”这个核心边界上，当前 Baton 算 HITL（`.baton/workflow.md:29-31`, `.baton/hooks/write-lock.sh:83-98`）。
- 但它不是严格、全流程、不可绕过、跨所有 IDE 一致成立的 HITL，因为存在 fail-open、`BATON_BYPASS=1`、大量 advisory-only hooks、以及 rules-only 的 IDE surface（见补充章节各小节）。

→ Result: supplemented

### Round 2

**[NOTE] § 需要人类判断的问题**
"我已补充 需要人类判断的问题 给出你的自己的判断"

用户在三个判断题下方补充了自己的回答。以下是我对每个回答的判断：

**问题 1：目标是提升个人效率，还是强化"受治理的 AI 编码"？**
用户回答：强化"受治理的 AI 编码"。

→ 我同意这个选择。证据：Baton 当前最强的差异化就是工作流契约（`.baton/workflow.md:14-19`），而不是速度。市面上加速个人效率的工具很多（Cursor Tab、Copilot autocomplete），但把"AI 写代码前必须有人类审批意图"做成可执行机制的几乎没有。选效率就是进入红海；选治理是守住蓝海。

**问题 2：AI 自报 confidence 还是人类显式开启 auto-approval？**
用户回答：auto-approval 必须由人类显式选择某个模式后才生效。

→ 我强烈同意。这正是评审发现 3 的核心论点（本文 §3, `plans/plan-2026-03-07-hotl.md:71-93`）。AI 自我认证 confidence 是一个自我背书结构，会从根本上削弱 HITL 的可信度。人类显式开启意味着治理权始终在人类手中——即使未来引入自动化，入口也是人类控制的，而不是模型控制的。

**问题 3：先审批意图事后审代码，还是按范围逐步审批输出？**
用户回答：先审批意图，事后审代码。

→ 我同意，但要补充一个风险。"先审批意图"与当前 `BATON:GO` 阶段门控模型完全一致（`.baton/workflow.md:29-31`）——人类审批 plan（意图），然后 AI 在批准窗口内自主执行。这比逐步审批效率更高，也更符合 Baton 的设计哲学。但评审角度 4（本文 §角度4）已经指出：一旦 `BATON:GO` 放置后，监督粒度会明显下降（`.baton/hooks/write-lock.sh:90-92`）。缓解措施是：加强事后审计能力（机器可读审计日志），让"事后审代码"这一步有工具支撑，而不是纯靠人类记忆去 `git diff`。

→ Result: accepted — 三个回答均与评审结论方向一致，已补充具体判断和证据。

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注 -->
[NOTE]
    1.我已补充 需要人类判断的问题 给出你的自己的判断

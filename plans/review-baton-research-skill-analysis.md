# ChatGPT 评审的二次分析

> 被评审对象：`.agents/skills/baton-research/SKILL.md`
> 评审来源：`review-baton-research-skill.md`（ChatGPT 产出）
> 本文档：对该评审的准确性和可操作性进行分析

## 总体评价

评审的**分析框架很专业**——从触发条件、约束可执行性、证据模型、工程化四个维度审视 skill，思路清晰。但它犯了一个 skill 评审里常见的错误：**用 Claude Code 官方文档的理想能力来批评一个在实际环境中运行的 skill**，某些建议在当前 Claude Code 的真实行为中并不可行或效果不佳。

## 逐条分析

### 1. "触发条件过宽" — ~~部分正确，但建议过度~~ 勘误：评审正确，初次分析低估

**事实核查**：description 确实写了 "even if the task seems simple"（SKILL.md:6），但正文 "When NOT to use" 部分（SKILL.md:31-32）明确排除了 Trivial/Small。这确实存在 description 和正文之间的张力。

**~~但评审夸大了问题~~**（勘误：评审没有夸大。它正确指出了根因：description 用宽泛的用户措辞 "analyze / explore / understand" 做触发条件，这些词几乎覆盖所有非平凡开发对话。真正的修复不是删半句 "even if simple"，而是把触发依据从用户措辞改为任务特征。初次分析只看到表面矛盾，没有正视评审指出的根因。）

**判断**：评审将此标为"当前最大缺陷"是正确的。description 需要从关键词匹配改为任务特征匹配——触发条件应描述什么样的任务需要 research（跨模块/歧义/多路径），而不是匹配用户可能随口说的词。

### 2. "只读约束没有编码到 frontmatter" — 方向对，建议不可行

**事实核查**：评审建议用 `context: fork` + `agent: Explore` 或 `allowed-tools` 来硬限制。

**问题**：`context: fork` 和 `allowed-tools` 是 Claude Code 的 **CLAUDE.md 级别的 agent 配置能力**，不是 skill frontmatter 支持的字段。截至当前版本，skill 的 frontmatter 只支持 `name`、`description`、`user-invocable`、`disable-model-invocation` 等有限字段。评审把 agents 的能力混淆成了 skills 的能力。

**实际约束机制**：baton 用的是 write-lock hook（SKILL.md:21 提到），这在实际运行中**确实能硬阻止写操作**。这比 frontmatter 配置更强——hook 是操作系统级别的拦截，而 frontmatter 是提示词级别的自律。

**判断**：评审在这一点上**方向对但方案错**。当前的 hook 方案实际上比评审建议的方案更硬。可移植性确实差一些，但对于 baton 这个特定项目来说，hook 是正确选择。

### 3. "证据标准应该分层" — 最有价值的建议

**事实核查**：SKILL.md:131 写 "Every claim requires file:line evidence. No exceptions."，但 Step 7（SKILL.md:216-217）要求记录 "Human requirement (chat): ..."，外部文档检索也是鼓励的（SKILL.md:63）。确实存在矛盾。

**评审的分层建议**：`[CODE]` file:line、`[DOC]` 外部文档、`[RUNTIME]` 命令输出、`[HUMAN]` 用户明确要求——**这是整份评审里最值得采纳的一条**。

**判断**：完全同意。当前写法会导致两个后果：严格执行时自相矛盾，宽松执行时破坏规则权威性。分层后规则更精确且可执行。

### 4. "Step 0 Tool Inventory 仪式化过头" — 部分同意

**事实核查**：SKILL.md:37-41 要求先盘点所有工具。但注意 Pre-Exit Checklist（SKILL.md:227-228）已经做了务实化处理："At least 2 distinct search methods used beyond Read"。

**评审漏看了这个修正**。实际的约束不是"每个工具都用一遍"，而是"至少 2 种互补检索方式"。Step 0 的写法确实偏仪式化，但 Pre-Exit Checklist 已经把执行标准拉回了务实水平。

**判断**：Step 0 的措辞可以简化，与 Pre-Exit Checklist 对齐，但这不是严重问题。

### 5. "subagent 使用是倡议不是机制" — 正确但不重要

**事实核查**：SKILL.md:95-96 确实只是建议性的 "when you encounter 3+ call paths across 10+ files, use subagents"。

**但这恰好是正确的做法**。subagent 调度应该是启发式的，不应该被硬编码到配置里——因为什么时候需要并行取决于运行时的代码结构，不是提前能确定的。

**判断**：评审把"不是机制"当问题，但"倡议"在这个场景下就是正确的设计。

### 6. 小瑕疵 — 基本正确

- `user-invocable: true` 是否是默认值：在当前 Claude Code 版本中**不是默认值**，需要显式声明。评审这里错了。
- `3+ annotations signal depth issues` 的阈值是否武断：有一定道理，但作为启发式规则，3 是合理的经验值。

## 评审本身的问题

1. ~~**混淆了 skill 和 agent 的配置能力**~~（勘误：此条判断错误。`context: fork`、`agent: Explore`、`allowed-tools` 确实是 Claude Code skill frontmatter 支持的字段，官方文档有 `deep-research` 示例。评审在这一点上是对的。）

2. **忽视了 hook 作为约束机制的优势**：只看到 "可移植性差"，没看到 hook 提供的是操作系统级硬阻断，比提示词约束强得多。

3. **Pre-Exit Checklist 的存在被忽略了**：评审批评 Step 0 和证据要求时，没有注意到 SKILL.md:224-237 已经做了务实化收敛。

4. ~~**对 Claude Code skill 系统的理解有明显偏差**~~（勘误：评审对 skill frontmatter 的理解是准确的，之前是本分析的认知有误。保留的有效批评：评审忽视了 hook 机制和 Pre-Exit Checklist。）

## 总结

| 评审观点 | 判断 | 优先级 |
|----------|------|--------|
| description 过宽 | **评审正确，需从关键词匹配改为任务特征匹配**（初次分析低估） | **高** |
| 只读约束应编码到配置 | 方向对且方案合法，但 hook 提供更强保障；是否叠加 `context: fork` 待决 | 待决 |
| 证据标准应分层 | **完全正确，最值得采纳** | **高** |
| Step 0 仪式化 | 部分正确，但已有 Pre-Exit 修正 | 低 |
| subagent 应机制化 | 不同意，倡议式更合适 | 不需改 |

**一句话结论**：这份评审的分析框架和具体建议都有价值。证据分层应采纳；`context: fork` + `agent: Explore` 的建议方案技术上合法（之前误判为错误，已勘误），是否采用是设计权衡问题；其余部分已有配套机制覆盖。

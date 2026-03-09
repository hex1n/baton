# baton-research skill 改进方案

> 来源：`review-baton-research-skill-analysis.md` + ChatGPT 替代版本的 cherry-pick
> 涉及文件：3 个（SKILL.md、workflow.md、workflow-full.md）

---

## 替代版本评估

批注区提供了一个完整的替代 SKILL.md。评估结论：**不能整体替换，cherry-pick 好想法合入当前 skill。**

### ~~技术性错误~~ 勘误：frontmatter 判断修正

> 之前的分析错误地将 `context: fork` 和 `agent: Explore` 判为"不是 skill frontmatter 支持的字段"。
> 经人类纠正：按当前 Claude Code 官方文档，这两个字段是 **合法的 skill frontmatter**。
> 官方文档给出了明确的 `deep-research` 示例使用 `context: fork` + `agent: Explore`。
> 这些是 Claude Code 对 Agent Skills open standard 的扩展，在 Claude Code 内部完全合法，但跨工具不一定可移植。

### 设计决策：是否采用 `context: fork` + `agent: Explore`

这不是对错问题，而是设计权衡。需要人类判断。

**采用的好处：**
- `context: fork` 让 research 在隔离上下文中运行，天然防止 context 污染
- `agent: Explore` 是只读分析代理，从系统层面强制 "no code changes"
- 与 write-lock hook 形成双重保障（hook 管文件写入，agent 管工具权限）

**~~采用的风险~~ annotation cycle 兼容性（已有解法）：**

annotation cycle 里有两种不同的工作：

| 类型 | 例子 | 适合 fork？ |
|------|------|-------------|
| **初始研究** | 用户说 "research X" → AI 产出 research.md | 是 — 独立、重量级 |
| **[PAUSE] 深度补充** | 人类写 `[PAUSE]` → AI 做整块新研究 → 追加 `## Supplement` | 是 — 独立、重量级 |
| **轻量批注回应** | 人类问"这个函数安全吗？" → AI 查代码、引 file:line 回答 | 否 — 需要对话上下文，快速单点 |

**解法：fork 只覆盖初始研究 + [PAUSE] 深度补充，轻量批注回应留在主对话。**

- research.md 是跨 fork 的上下文桥梁：每个 fork 读到的都是包含所有历史批注和回应的完整文档
- 文档就是持久化状态，不依赖对话内存
- 这与 baton 现有设计一致：research.md 是 single source of truth，对话只是交互媒介

**其他风险：**
- Explore agent 的工具集可能不包含 Write（写 research.md 需要），需确认
- `disable-model-invocation: true` 会阻止自动触发，与 baton workflow 对 Medium/Large 任务的自动 research 流程冲突

**待决选项：**
- **A**: 不加 `context: fork`（当前方案），依赖 write-lock hook + 提示词纪律
- **B**: 加 `context: fork` + `agent: Explore`，但不加 `disable-model-invocation`，保留自动触发。description 收窄为只覆盖"初始研究 + [PAUSE] 深度补充"，避免轻量批注误触发 fork
- **C**: 加 `context: fork` + `agent: Explore` + `disable-model-invocation: true`，完全手动 `/baton-research` 控制

→ 此决策需要人类确认。当前方案按 **A** 执行，如选 B 或 C 则追加改动 8。

### 其他不可采纳的部分

| 项目 | 问题 |
|------|------|
| `docs/research/<topic>.md` | 与 baton 文件约定 `research-<topic>.md` 不一致，plan phase 找不到研究文件 |
| 缺失 baton 核心机制 | 批注区、Annotation Protocol（[PAUSE] / Annotation Log / consequence detection）、Self-Review、Pre-Exit Checklist、write-lock hook 提及、Complexity Calibration 联动——全部缺失 |

### 值得 cherry-pick 的好想法（合入下方改动）

| 好想法 | 合入位置 |
|--------|----------|
| Frame the investigation（Question / Why / Scope / Out of scope / Constraints） | 新增改动 4 |
| Separate facts, inferences, and judgments | 新增改动 5 |
| Confidence levels（high / medium / low）in Final Conclusions | 新增改动 6 |
| Escalation guidance（研究越界时怎么办） | 新增改动 7 |

---

## 改动 1（高优先级）：证据标准分层

**问题**：Iron Law 说 “NO CONCLUSIONS WITHOUT FILE:LINE EVIDENCE”，但实际研究中会用到外部文档、运行时输出、用户口头需求，造成规则自相矛盾。

**涉及 3 个文件：**

### A. `.claude/skills/baton-research/SKILL.md`

**Iron Law（行 14-16）**

Before:
```
NO CONCLUSIONS WITHOUT FILE:LINE EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
```

After:
```
NO CONCLUSIONS WITHOUT EXPLICIT EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
```

**Evidence Standards（行 129-140）**

Before:
```markdown
## Evidence Standards

Every claim requires file:line evidence. No exceptions.

- `✅` confirmed safe — with verification evidence
- `❌` problem found — with evidence of the problem
- `❓` unverified — with reason it remains unverified

​```
✅ Good: “Token expires after 24h (auth.ts:45 — `expiresIn: ‘24h’`)”
❌ Bad: “Token expiration should be fine”
​```
```

After:
```markdown
## Evidence Standards

Every claim requires explicit evidence. Label by type:

- `[CODE]` repo file:line — for code behavior claims
- `[DOC]` authoritative external docs — for dependency/framework behavior
- `[RUNTIME]` command output — for observed runtime behavior
- `[HUMAN]` chat-stated requirements — for user direction and constraints

Code-behavior conclusions without `[CODE]` evidence are not valid.
No-evidence claims must be marked ❓ unverified.

- `✅` confirmed safe — with verification evidence
- `❌` problem found — with evidence of the problem
- `❓` unverified — with reason it remains unverified

​```
✅ Good: “Token expires after 24h [CODE] auth.ts:45 — `expiresIn: ‘24h’`”
✅ Good: “Redis SCAN is O(1) per call [DOC] redis.io/commands/scan”
✅ Good: “Sparse-checkout requires git 2.25+ [RUNTIME] `git sparse-checkout` fails on 2.24”
❌ Bad: “Token expiration should be fine”
​```
```

### B. `.baton/workflow.md`（行 42）

Before:
```
Every claim requires file:line evidence. No evidence = mark with ❓ unverified.
```

After:
```
Every claim requires explicit evidence — label as [CODE] file:line, [DOC] external docs, [RUNTIME] command output, or [HUMAN] chat requirement. No evidence = mark with ❓ unverified.
```

### C. `.baton/workflow-full.md`（行 41-42）

同 B，保持一致。

---

## 改动 2（高优先级）：description 从关键词匹配改为任务特征匹配

**问题**：description 用宽泛的用户措辞（analyze / explore / understand）做触发条件，几乎覆盖所有非平凡开发对话，导致过触发。ChatGPT 评审正确地将此标为”当前最大缺陷”——之前的分析低估了这一点，仅提出删半句的表面修复。

**根因**：description 匹配的是**用户的措辞**，而不是**任务的特征**。用户说”帮我分析一下这个函数”可能只想要一个快速解释，不是启动完整的 research phase。

### `.claude/skills/baton-research/SKILL.md`（行 3-8）

Before:
```yaml
description: >
  This skill MUST be used when the user asks to “research”, “analyze”,
  “investigate”, “trace”, “explore”, “understand how this works”, or whenever
  starting any task that touches unfamiliar code — even if the task seems simple.
  Also use when receiving feedback requesting deeper analysis or [PAUSE] annotations.
  Produces research.md with file:line evidence for human review.
```

After:
```yaml
description: >
  Use for Medium/Large code investigations that require a research artifact
  before planning: cross-module behavior tracing, ambiguous or contradictory
  requirements, multi-surface consistency checks, or root-cause analysis
  across multiple execution paths. Also use when the user explicitly says
  “research” or “deep research”, or for [PAUSE] supplementary investigations.
  Do NOT use for quick lookups, single-file explanations, or tasks where
  scope is already clear — those belong in the main conversation.
```

**变化**：
- 触发依据从用户措辞（analyze/explore/understand）改为任务特征（跨模块/歧义/多路径）
- 只保留 “research” 作为显式触发词，去掉宽泛的 analyze/explore/understand
- 增加显式的 “Do NOT use” 反向约束
- 漏触发风险可接受：Complexity Calibration 仍是前置过滤，用户说 “research” 仍可显式触发

**同步修改 “When to Use” 正文**（SKILL.md:23-32），保持 description 和正文一致：

Before:
```markdown
## When to Use

- Starting analysis of unfamiliar code or a new feature area
- When the user asks to research, analyze, explore, understand, or investigate
- When a task's complexity is Medium or Large (see workflow.md Complexity Calibration)
- When you need to understand existing behavior before proposing changes
- After receiving a `[PAUSE]` annotation during plan review

**When NOT to use**: Trivial/Small tasks where the scope is already clear and you can
go directly to planning.
```

After:
```markdown
## When to Use

- Medium/Large tasks requiring cross-module behavior tracing
- Ambiguous or contradictory requirements that need evidence-backed clarification
- Multi-surface consistency checks (e.g., N IDEs, N API endpoints, N config formats)
- Root-cause analysis across multiple execution paths
- When the user explicitly says “research” or “deep research”
- After receiving a `[PAUSE]` annotation during plan review

**When NOT to use**: Quick lookups, single-file explanations, tasks where scope is
already clear, or Trivial/Small tasks that can go directly to planning.
```

---

## 改动 3（低优先级）：Step 0 与 Pre-Exit Checklist 对齐

**问题**：Step 0 要求”盘点所有工具”，Pre-Exit Checklist 只要求”至少 2 种互补方式”，前者偏仪式化。

### `.claude/skills/baton-research/SKILL.md`（行 36-41）

Before:
```markdown
### Step 0: Tool Inventory

Before any code investigation, inventory all available documentation retrieval and
search tools (Context7, WebSearch, WebFetch, Grep, Glob, MCP servers). Attempt each
relevant one during research. Record what you used and what each returned — the human
judges search thoroughness.
```

After:
```markdown
### Step 0: Tool Inventory

Use at least 2 distinct search methods beyond Read (e.g., Grep + Glob,
Grep + Context7, Glob + subagent). Record what you used, what each
returned, and why these methods are sufficient for the current investigation
— the human judges search thoroughness.
```

---

## 改动 4（中优先级）：新增 Step 0.5 — Frame the Investigation

**来源**：替代版本 Step 1。当前 skill 直接跳到 “Start from Entry Points”，缺少显式的问题定义步骤。

### `.claude/skills/baton-research/SKILL.md`

在 Step 0 和 Step 1 之间插入：

```markdown
### Step 0.5: Frame the Investigation

Before diving into code, define at the top of research.md:

- **Question**: what exactly is being investigated
- **Why it matters**: what later decision (plan/implementation) this research supports
- **Scope**: what is included
- **Out of scope**: what is intentionally excluded
- **Known constraints**: repo, platform, compatibility, or tooling constraints

If the user’s request is vague, resolve it into a concrete research question first.
This framing anchors the entire investigation — without it, research drifts.
```

---

## 改动 5（中优先级）：新增 “Separate facts, inferences, and judgments” 原则

**来源**：替代版本 Research Standard #2。当前 skill 要求证据但没有区分事实/推断/判断，容易混在一起。

### `.claude/skills/baton-research/SKILL.md`

在 Evidence Standards 末尾（现行 `❌ Bad` 示例之后）追加：

```markdown
### Layering: Facts, Inferences, Judgments

In research.md, keep these distinct:

- **Facts**: directly evidenced statements (cite [CODE]/[DOC]/[RUNTIME]/[HUMAN])
- **Inferences**: reasoned conclusions drawn from facts (mark as inference)
- **Judgments**: recommendations or tradeoff assessments (mark as judgment)

Do not blur them. The human needs to know which conclusions they can trust
directly vs. which require their own judgment.
```

---

## 改动 6（低优先级）：Final Conclusions 增加 confidence level

**来源**：替代版本 Step 6。当前 skill 的 Final Conclusions 只要求 “reference evidence location”，缺少置信度。

### `.claude/skills/baton-research/SKILL.md`（Step 7: Convergence Check，行 205-220）

Before:
```markdown
2. **Write `## Final Conclusions`** — a short section at the end listing ONLY
   the currently-valid conclusions. Each must reference its evidence location
   in the document body.
```

After:
```markdown
2. **Write `## Final Conclusions`** — a short section at the end listing ONLY
   the currently-valid conclusions. Each must include:
   - conclusion statement
   - confidence: high / medium / low
   - supporting evidence reference (location in document body)
   - main uncertainty, if any
   - implication for planning or implementation
```

---

## 改动 7（低优先级）：新增 Escalation Guidance

**来源**：替代版本 Escalation Guidance。当前 skill 没有显式的 “研究越界时怎么办” 指导。

### `.claude/skills/baton-research/SKILL.md`

在 Exit Criteria 之后、Metacognitive Triggers 之前插入：

```markdown
## Escalation Guidance

If the investigation expands beyond the original question:
- Finish the current research question cleanly first
- Note adjacent unresolved areas in a separate section
- State whether each is a blocker, a risk, or follow-on research
- Do not silently broaden scope — the human needs to approve scope changes

If runtime validation is impossible, say exactly why.
If evidence is mixed, say so directly — do not force a neat conclusion.
```

---

## 不改的部分

| 项目 | 理由 |
|------|------|
| ~~`context: fork` / `agent: Explore`~~ | ~~待决~~ → 已决：方案 B，追加为改动 8 |
| subagent 使用策略 | 启发式建议比硬编码更适合运行时决策 |
| 3+ annotations 阈值 | 合理的经验值，无需调整 |
| Annotation Protocol | 当前版本完整，替代版本完全缺失此机制 |
| Self-Review / Pre-Exit Checklist | 当前版本有效，替代版本用 Quality Bar 替代但缺少自检机制 |
| Red Flags / Common Rationalizations | 当前版本的反模式表有实战价值，替代版本删除了这些 |
| 批注区 | baton 核心机制，替代版本完全缺失 |

## 改动总览

| # | 内容 | 优先级 | 来源 |
|---|------|--------|------|
| 1 | 证据标准分层 [CODE]/[DOC]/[RUNTIME]/[HUMAN] | **高** | ChatGPT 评审 |
| 2 | description 从关键词匹配改为任务特征匹配 | **高** | ChatGPT 评审（初次分析低估，经批注纠正） |
| 3 | Step 0 简化为 “至少 2 种方法” | 低 | ChatGPT 评审 |
| 4 | 新增 Step 0.5: Frame the Investigation | **中** | 替代版本 cherry-pick |
| 5 | 新增 Facts/Inferences/Judgments 分层 | **中** | 替代版本 cherry-pick |
| 6 | Final Conclusions 增加 confidence level | 低 | 替代版本 cherry-pick |
| 7 | 新增 Escalation Guidance | 低 | 替代版本 cherry-pick |
| 8 | frontmatter 加 `context: fork` + `agent: Explore`，description 进一步收窄 | **高** | 方案 B（Round 10 确认） |

## 改动 8（高优先级）：frontmatter 加 `context: fork` + `agent: Explore`（方案 B）

**决策**：人类选定方案 B。

### `.claude/skills/baton-research/SKILL.md` frontmatter

Before:
```yaml
---
name: baton-research
description: >
  This skill MUST be used when the user asks to "research", "analyze",
  "investigate", "trace", "explore", "understand how this works", or whenever
  starting any task that touches unfamiliar code — even if the task seems simple.
  Also use when receiving feedback requesting deeper analysis or [PAUSE] annotations.
  Produces research.md with file:line evidence for human review.
user-invocable: true
---
```

After（合并改动 2 的 description + 改动 8 的 frontmatter）:
```yaml
---
name: baton-research
description: >
  Use for initial code research on Medium/Large tasks: cross-module behavior
  tracing, ambiguous or contradictory requirements, multi-surface consistency
  checks, or root-cause analysis across multiple execution paths. Also use
  for [PAUSE] supplementary investigations and when user explicitly says
  "research". Do NOT trigger for lightweight annotation responses or quick
  single-file lookups — those belong in the main conversation.
user-invocable: true
context: fork
agent: Explore
---
```

**注意**：改动 2 的 description 已合并到此处。执行时改动 2 只需执行 "When to Use" 正文修改。

---

## Todo

- [x] ✅ 1. 改动 8+2 frontmatter：重写 SKILL.md frontmatter（description + context: fork + agent: Explore）和 "When to Use" 正文 | Files: `.claude/skills/baton-research/SKILL.md` | Verify: YAML frontmatter 格式正确，description 与 When to Use 无矛盾 | Deps: none
- [x] ✅ 2. 改动 1 Iron Law：`FILE:LINE EVIDENCE` → `EXPLICIT EVIDENCE` | Files: `.claude/skills/baton-research/SKILL.md` | Verify: Iron Law 与 Evidence Standards 措辞一致 | Deps: none
- [x] ✅ 3. 改动 1 Evidence Standards：重写证据标准为四类标签 [CODE]/[DOC]/[RUNTIME]/[HUMAN] | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 示例覆盖四种标签 | Deps: #2
- [x] ✅ 4. 改动 5 Facts/Inferences/Judgments：在 Evidence Standards 末尾追加分层原则 | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 紧跟 Evidence Standards 示例之后 | Deps: #3
- [x] ✅ 5. 改动 3 Step 0：简化为"至少 2 种方法 + 记录 why sufficient" | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 与 Pre-Exit Checklist 一致 | Deps: none
- [x] ✅ 6. 改动 4 Step 0.5：在 Step 0 和 Step 1 之间插入 Frame the Investigation | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 位于 Step 0 之后、Step 1 之前 | Deps: #5
- [x] ✅ 7. 改动 6 Final Conclusions：扩展为含 confidence level 的结构化格式 | Files: `.claude/skills/baton-research/SKILL.md` | Verify: Step 7 Convergence Check 格式正确 | Deps: none
- [x] ✅ 8. 改动 7 Escalation Guidance：在 Exit Criteria 之后插入 | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 位于 Exit Criteria 和 Metacognitive Triggers 之间 | Deps: none
- [x] ✅ 9. 改动 1 workflow.md：证据标准行改为分层版本 | Files: `.baton/workflow.md` | Verify: 与 SKILL.md Evidence Standards 一致 | Deps: none
- [x] ✅ 10. 改动 1 workflow-full.md：证据标准行改为分层版本 | Files: `.baton/workflow-full.md` | Verify: 与 workflow.md 一致 | Deps: none

---

## Annotation Log

### Round 1

**纠正 § frontmatter 判断**
“context: fork 和 agent: Explore 是 Claude Code skill frontmatter 的合法字段，官方文档有 deep-research 示例”
→ Inferred intent: 事实纠正
→ 确认人类正确。官方文档支持 `context: fork` + `agent: Explore` 作为 skill frontmatter。
  之前的分析基于过时/错误的认知，已修正。
→ Consequence: “技术性错误”表中 2 项被移除，转为设计决策（A/B/C 三选一）待人类确认。
→ Result: 已更新替代版本评估部分，加入勘误 + 设计决策分析。

### Round 2

**追问 § annotation cycle 兼容性**
“如果 skill 在 fork 里运行，annotation cycle 的上下文连续性可能受影响，这个有好的解决方法吗”
→ Inferred intent: 技术可行性追问
→ 有解：annotation cycle 里的工作分两类——初始研究/[PAUSE] 深度补充适合 fork，轻量批注回应留在主对话。
  research.md 是跨 fork 的上下文桥梁，文档即持久化状态。
→ Consequence: 设计决策 B 方案可行性提升，description 需收窄以区分 fork 场景和主对话场景。
→ Result: 已更新设计决策部分，补充兼容性解法 + B 方案 description 要求。

### Round 3

**追问 § 触发条件过宽**
“ChatGPT 评审一开始就指出了触发条件问题，你做改进计划的时候为什么没有自动考虑到？”
→ Inferred intent: 指出分析失误
→ 确认人类正确。ChatGPT 评审将此标为”当前最大缺陷”，但初次分析将其降级为”低优先级、删半句即可”，
  未正视根因：description 用用户措辞做触发条件，而不是用任务特征。这是对评审合理批评的过度抵抗。
→ Consequence: 改动 2 从”低优先级表面修复”升级为”高优先级根因修复”——description 从关键词匹配改为任务特征匹配。
→ Result: 已重写改动 2，升级优先级，更新总览表。

### Round 4

**质疑 § 全局复审**
“合理怀疑其他改进项也不好”
→ Inferred intent: 要求对所有改进项做防御性偏差检查
→ 逐项重新审视结果：
  - 改动 2：发现遗漏——“When to Use” 正文未同步修改，与新 description 仍矛盾。已补充。
  - 改动 3：漏吸收替代版本的 “record why sufficient”。已补充。
  - 改动 4-7、不改的部分：重新审视后判断不变，无需调整。
→ Consequence: 改动 2 补充了 “When to Use” 正文的同步修改；改动 3 补充了 “why sufficient”。
→ 自省：初次分析的防御性模式在改动 1（证据分层）上没有出现，因为那条评审建议没有”挑战”感；
  在改动 2（触发条件）上严重出现，因为评审直接说”最大缺陷”，触发了抵抗心理。
  结论：被评审标为”最大问题”的点恰恰最容易被防御性降级。后续分析应对评审认为最严重的条目投入最多而非最少的审视。

### Round 5

**追问 § 分析习惯改进方案**
“你识别了防御性偏差模式，但没有给出避免再犯的方案”
→ Inferred intent: 要求可执行的改进机制，不只是自省
→ 提出 3 条规则：
  1. **严重度反转检查**：从评审标为最严重的条目开始，降级需要比评审更多的证据
  2. **钢人论证**：反驳前先写出评审论点的最强版本
  3. **置信度最高处加倍检查**：最确信评审错的那一条就是偏差最可能藏身的地方
→ Result: 已写入 memory（跨 session 持久化），作为分析外部评审的常驻规则。

### Round 6

**追问 § 机制落地 + 范围扩展**
“只是记到 memory 里面吗？而且不只是评审，限定在评审就太死了”
→ Inferred intent: 两点纠正——(1) memory 不是约束机制，(2) 范围应覆盖所有外部挑战
→ 行动：
  1. 在 workflow.md Mindset 新增第 4 条原则 “Accept challenges proportionally”，覆盖所有挑战来源（人类反馈、代码证据、测试结果、外部分析）
  2. 同步到 workflow-full.md
  3. memory 改为引用 workflow.md 原则 + 操作细节，不再独立维护规则
→ 这是原则层面的变更，不只是 baton-research skill 的改动。

### Round 7

**纠正 § 文件路径**
“skills 唯一真源是 .claude/skills/ 不是 .agents/skills/”
→ Inferred intent: 事实纠正
→ 确认：`.claude/skills/` 和 `.agents/skills/` 内容完全一致（diff 无输出），`.claude/skills/` 是唯一真源。
→ Result: plan 中所有 `.agents/skills/` 引用已全部替换为 `.claude/skills/`。

### Round 8

**要求 § plan phase 同等验证纪律**
“你需要在 plan 时同等要求自己”
→ Inferred intent: 将 “verify before you claim” 延伸到 plan phase，不只是 research
→ 行动：
  1. workflow-full.md [PLAN] Constraints 新增 “Verify before you plan” 条目
  2. workflow-full.md [PLAN] Self-Review Internal Consistency Check 新增文件路径/约定验证项
→ 这是 plan phase 指导的永久变更，不只是本次 plan 的修复。

### Round 9

**纠正 § 落地位置 + 措辞宽度**
“写得太死了，而且 workflow-full 目前没有其他地方消费”
→ Inferred intent: 两点纠正——(1) 措辞应覆盖所有前提而非只提文件路径 (2) 应写到实际被消费的文件
→ 验证：grep 全项目确认 workflow-full.md 零消费者，baton-plan skill 才是实际的 plan phase guidance
→ 行动：
  1. 从 workflow-full.md 回滚两处改动（Constraints + Self-Review）——无消费者，写了等于没写
  2. 在 baton-plan SKILL.md Self-Review checklist 新增 “Are all premises verified?”，措辞覆盖
     所有前提（file locations, naming conventions, tool capabilities, project structure, API behavior），
     而非只提文件路径
→ Result: 原则落在了会被实际读取的文件里，措辞更宽泛。

### Round 10

**决策 § context: fork 方案 + 生成 todo**
“走方案 B 生成 todo” + `<!-- BATON:GO -->`
→ Inferred intent: 选定方案 B，批准实施
→ 行动：新增改动 8（frontmatter + description 合并），生成 10 项 todo。
→ Result: plan 已完整，todo 已生成，BATON:GO 已确认。

## Retrospective

### What the plan got wrong
- Nothing structurally wrong — the 10 items mapped cleanly to edits. The plan was well-scoped after 10 annotation rounds.

### What surprised during implementation
- All 10 edits were straightforward string replacements. The hard work was in the 10-round annotation cycle, not the implementation.
- Grep couldn't find matches in `.baton/` and `.claude/` directories (likely gitignore exclusion), so verification required direct Read.

### What to research differently next time
- The initial analysis defensively dismissed the ChatGPT review's strongest criticisms (trigger condition, evidence standards). 9 annotation rounds were needed to correct this. The new workflow.md principle #4 ("Accept challenges proportionally") should reduce this in future sessions.
- Should have verified workflow-full.md's consumer status during research rather than discovering it has zero consumers during Round 9.

## 批注区

<!-- BATON:GO -->
<!-- 写下你的反馈，AI 会判断如何处理。 -->
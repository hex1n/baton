# Research: workflow.md + workflow-full.md Agentic 重写

## 研究范围

**目标**：系统性分析当前 workflow.md / workflow-full.md 的每条规则，对比官方和社区最佳实践，为 plan-agentic-rewrite.md 提供证据基础。

**工具使用记录**：

| 工具 | 使用次数 | 结果 |
|------|----------|------|
| WebSearch | 8 | 找到 Anthropic 官方文档、社区实践、学术研究 |
| WebFetch | 12 | 深度抓取 Anthropic 工程博客、Claude 4.6 最佳实践、Claude Code 文档、社区博客 |
| Context7 | 5 | /anthropics/courses, /anthropics/anthropic-cookbook, /nikiforovall/claude-code-rules, /johnlindquist/claude 等 |
| Read | 2 | workflow.md, workflow-full.md 逐行分析 |

## 1. 当前状态分析

### 1.1 规则清单统计

| 指标 | workflow.md | workflow-full.md 阶段段落 | 合计 |
|------|-----------|--------------------------|------|
| 总规则数 | 45 | 97 | 142 |
| HARD_CONSTRAINT | 16 | 24 | 40 |
| COGNITIVE_GUIDE | 7 | 16 | 23 |
| PROCESS_STEP | 13 | 24 | 37 |
| FORMAT_REQUIREMENT | 4 | 21 | 25 |
| STRATEGY_HINT | 5 | 6 | 11 |

### 1.2 风格分布

| 风格 | 数量 | 占比 |
|------|------|------|
| **PRESCRIPTIVE**（do X then Y） | 89 | **65%** |
| CONSTRAINT（never do X） | 18 | 13% |
| CONTEXT_RICH（do X because Y） | 16 | 12% |
| GOAL_DRIVEN（achieve state X） | 13 | **10%** |

**核心发现**：65% 的规则是 prescriptive 风格，只有 10% 是 goal-driven。这与官方建议（"prefer general instructions over prescriptive steps"）存在明显差距。

### 1.3 冗余分析

| 冗余类型 | 数量 | 示例 |
|----------|------|------|
| workflow.md 内部重复 | 3 | R1=M6, R5=A8, P2=R15 |
| workflow-full.md 重述 workflow.md | 25 | RE17=M2, PL5=R3, IM1=M6 等 |
| workflow-full.md 展开 workflow.md | 15 | RE16→M2, AN7→A8, IM6→R8 等 |
| **冗余规则总计** | **43** | 占总规则 30% |

最严重的冗余：
- "no source code before BATON:GO" — 出现 3 次（M6, R1, IM1）
- "human not always right" — 出现 4 次（M3, A10, AN16, PL21）
- "annotation must be recorded in log" — 出现 4 次（A8, R5, AN3, AN7）

### 1.4 各段问题总览

| 段落 | 主要问题 |
|------|----------|
| Mindset (M1-M8) | M6-M8 write-lock 规则不应在 Mindset 段（机械约束 vs 认知定位） |
| Flow (F1-F3) | F2 箭头符号混乱；F3 "simple" 未定义；缺 WHY |
| Rules (R1-R16) | 14 条操作指令，功能是 catch-all；与其他段高度冗余 |
| [RESEARCH] (RE1-RE36) | Execution Strategy 过于 prescriptive；12 条 FORMAT_REQUIREMENT 使其模板化 |
| [PLAN] (PL1-PL21) | PL14-15 方法分析模板过于 rigid；PL19 patch/root 二分法不够通用 |
| [ANNOTATION] (AN1-AN21) | 大部分已是约束式（✅）；与 workflow.md 冗余最多（25 条 SHARED） |
| [IMPLEMENT] (IM1-IM19) | 6 步逐条检查清单是全文档最 prescriptive 的段落 |

### 1.5 已经 agentic 的优秀内容（保留）

| 规则 | 位置 | 为什么好 |
|------|------|----------|
| "You are an investigator, not an executor" | M1 | 身份框架，目标驱动 |
| "Observe-then-decide: after reading each node's implementation, decide the next node based on what you found — not from a pre-made list" | RE7 | 认知自主，非 prescriptive |
| "For every claim, ask: have you actually read the code that confirms this?" | RE18 | 元认知触发器 |
| "Plans should not jump to 'how to do it' — they should derive approaches from research findings" | PL13 | 优秀的认知原则 |
| Correct/incorrect AI behavior examples | AN17-18 | 具体示例比规则更有效（官方确认） |
| Self-Review prompts（3 questions, weakest conclusion, what would change） | RE29-31 | 强制自我批判 |

## 2. 官方最佳实践

### 2.1 Anthropic「Right Altitude」框架

**来源**：[Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

两个失败模式：
- **过度 prescriptive**：「Engineers hardcoding complex, brittle logic in their prompts... creates fragility and increases maintenance complexity over time.」
- **过度 abstract**：「Vague, high-level guidance that fails to give the LLM concrete signals for desired outputs or falsely assumes shared context.」

**最优解**：「Specific enough to guide behavior effectively, yet flexible enough to provide the model with strong heuristics to guide behavior.」

**关键发现**：「Smarter models require less prescriptive engineering, allowing agents to operate with more autonomy.」

### 2.2 Claude 4.6 官方最佳实践

**来源**：[Prompting Best Practices](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)

**核心原则**：

1. **General > Prescriptive**：「Prefer general instructions over prescriptive steps. A prompt like "think thoroughly" often produces better reasoning than a hand-written step-by-step plan — Claude's reasoning frequently exceeds what a human would prescribe.」

2. **告知 WHY**：「Providing context or motivation behind your instructions... can help Claude better understand your goals.」示例：与其说「NEVER use ellipses」不如解释「Your response will be read aloud by a text-to-speech engine...」

3. **正面表述**：「Tell Claude what to do instead of what not to do.」与其说「Do not use markdown」不如说「Your response should be composed of smoothly flowing prose paragraphs.」

4. **Overtriggering 警告**：「Claude Opus 4.6 are more responsive to the system prompt than previous models. If your prompts were designed to reduce undertriggering, these models may now overtrigger. The fix is to dial back any aggressive language. Where you might have said 'CRITICAL: You MUST...', you can use more normal prompting like 'Use this tool when...'」

5. **示例 > 规则**：「For an LLM, examples are the 'pictures' worth a thousand words.」官方建议 3-5 个 diverse examples 而非 exhaustive edge case lists。

6. **验证是最高杠杆**：「Give Claude a way to verify its work... This is the single highest-leverage thing you can do.」

### 2.3 CLAUDE.md 设计指南

**来源**：[Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) + [Memory](https://code.claude.com/docs/en/memory)

**长度**：Target under 200 lines。「Bloated CLAUDE.md files cause Claude to ignore your actual instructions!」

**Include vs Exclude**：

| Include | Exclude |
|---------|---------|
| Claude 猜不到的 Bash 命令 | Claude 能从代码推断的信息 |
| 偏离默认值的代码风格 | 标准语言惯例 |
| 测试指令和首选工具 | 详细 API 文档（改为链接） |
| 仓库礼仪（分支命名、PR 规范） | 频繁变化的信息 |
| 项目特定架构决策 | 长教程 |
| 常见陷阱 | 文件级描述 |
|  | "write clean code" 之类的自明要求 |

**黄金测试**：「For each line, ask: "Would removing this cause Claude to make mistakes?" If not, cut it.」

**advisory vs deterministic**：「CLAUDE.md is advisory, hooks are deterministic. Use hooks for actions that must happen every time with zero exceptions.」

**CLAUDE.md 作为入职文档**：「Think of CLAUDE.md as an 'onboarding document' that orients the agent, while detailed files are 'source systems' the agent can query when precision matters.」

### 2.4 Context Rot（上下文腐烂）

**来源**：[Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

「LLMs have an 'attention budget'... As the number of tokens in the context window increases, the model's ability to accurately recall information from that context decreases.」

**指导**：「Be thoughtful and keep your context informative, yet tight.」— context 中的每个 token 都在消耗注意力预算。

## 3. 社区最佳实践

### 3.1 指令遵从性量化研究

**来源**：[Arize — Optimizing Coding Agent Rules](https://arize.com/blog/optimizing-coding-agent-rules-claude-md-agents-md-clinerules-cursor-rules-for-improved-accuracy/)

- **绝对语言** MUST/MUST NOT 的遵从率是 **2.8x**（相比 "prefer"/"try"/"avoid"）
- **Primacy effect**（首因效应）：AI 强烈锚定在初始指令上。关键约束应前置
- 最优规则集包含 **20-50 条广泛适用的规则**
- **广泛适用的规则 > 针对特定案例的规则**：「Rules tailored to specific examples underperformed; broadly applicable guidance proved superior.」

### 3.2 真实世界工作流验证

**来源**：[Boris Tane — How I Use Claude Code](https://boristane.com/blog/how-i-use-claude-code/)

Boris Tane 的工作流与 baton 高度相似：
- Research → Plan → **Annotation Cycle (1-6 rounds)** → Implement
- 使用 "don't implement yet" guard（≈ baton 的 BATON:GO write-lock）
- 内联批注（notes range from two-word corrections to paragraph-length domain knowledge）
- 实施命令：「implement it all. mark tasks completed in the plan document. do not stop until finished. run typecheck continuously.」
- 关键原则：**「The workflow treats Claude as an excellent executor, not a decision-maker, shifting creative work to the planning phase where human judgment is most valuable.」**

### 3.3 元认知 / 自检有效性研究

**来源**：[Galileo — Self-Evaluation in AI Agents](https://galileo.ai/blog/self-evaluation-ai-agents-performance-reasoning-reflection)

- Self-reflection 将 GPT-4 准确率从 78.6% 提升到 **97.1%**
- 跨模型验证：Claude 3 Opus (97.1%), Gemini 1.5 Pro (97.2%), Mistral Large (92.2%)
- **关键限制**：「Self-correction without external verification signals is fundamentally unreliable. Without evaluation, reflection optimizes appearance rather than correctness.」
- 有效的 self-checking 必须结合：工具验证、human-in-the-loop、评估模式

**对 baton 的启示**：baton 的「verify before you claim, cite file:line」本质上是 self-reflection + external grounding 的结合。研究确认这个方向是对的。

### 3.4 CLAUDE.md 学术分析

**来源**：[On the Use of Agentic Coding Manifests (arXiv)](https://arxiv.org/html/2509.14744v1)（253 份 CLAUDE.md 文件分析）

- **结构**：开发者偏好浅层级。中位数：1 个 H1, 5 个 H2, 9 个 H3。极少使用 H4+
- **最常见内容类型**：
  1. Build and Run (77.1%)
  2. Implementation Details (71.9%)
  3. Architecture (64.8%)
  4. Testing (60.5%)
  5. Development Process (37.2%)
- 48.2% 包含系统概述；仅 15.4% 明确定义 AI agent 角色
- 「There is little research on how to design them effectively」— 这是一个不成熟的领域

### 3.5 GSD 工作流系统

**来源**：[GSD Workflow System — Codecentric](https://www.codecentric.de/en/knowledge-hub/blog/the-anatomy-of-claude-code-workflows-turning-slash-commands-into-an-ai-development-system)（23k GitHub stars）

关键原则：**「Deterministic logic belongs in code, not in prompts.」** — 用 Bash 脚本捕获项目状态，不依赖 LLM 推断。

这印证了 baton 的 hooks 设计（write-lock.sh, completion-check.sh 是 deterministic，workflow.md 是 advisory）。

### 3.6 指令预算

**来源**：[HumanLayer — Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)

- 前沿模型大约能可靠遵循 **150-200 条指令**
- Claude Code 系统提示已经消耗了 ~50 条
- workflow.md（45 条规则）+ 系统提示（~50 条）= ~95 条，距离上限还有余量
- 但如果 workflow-full.md 通过 phase-guide 注入当前阶段（~36 条 for RESEARCH），总计 ~131 条，接近上限

## 4. Gap 分析：当前状态 vs 最佳实践

### 4.1 风格对齐度

| 最佳实践 | 当前状态 | Gap | 严重性 |
|----------|---------|-----|--------|
| General > Prescriptive（官方） | 65% prescriptive | 大 | High — 直接影响 agent 效能 |
| 告知 WHY（官方） | 16 条有 CONTEXT_RICH，126 条没有 | 中 | Medium — 缺少 WHY 的规则可能被误解或忽略 |
| 正面表述（官方） | 多数是约束/禁止式 | 中 | Medium — 告诉「做什么」比「不做什么」更有效 |
| 示例 > 规则列表（官方） | 仅 AN17-18 有具体示例 | 大 | High — 官方说「examples are pictures worth 1000 words」 |
| MUST/MUST NOT 绝对语言（社区） | 部分使用 | 小 | Low — 硬约束已用绝对语言 |
| 广泛适用 > 特定案例（社区） | 大部分规则是广泛适用的 | 小 | Low — 这方面做得好 |

### 4.2 结构对齐度

| 最佳实践 | 当前状态 | Gap | 严重性 |
|----------|---------|-----|--------|
| <200 行（官方） | workflow.md 66 行 ✅ | 无 | — |
| 浅层级 H1/H2/H3（社区研究） | 使用 H2/H3 ✅ | 无 | — |
| 无冗余（官方 "cut what doesn't cause mistakes"） | 30% 冗余 | 中 | Medium — 浪费注意力预算 |
| 关键约束前置（社区 primacy effect） | Write-lock 在 Mindset 中间 | 小 | Low — 但值得优化 |
| Include/Exclude 准则（官方） | 未区分"Claude 能推断的" vs "必须告知的" | 中 | Medium |

### 4.3 内容对齐度

| 最佳实践 | 当前状态 | Gap | 严重性 |
|----------|---------|-----|--------|
| 验证是最高杠杆（官方 #1） | 有 M2（cite file:line）但不够突出 | 中 | Medium — 应更显著 |
| 元认知触发器有效（研究 78.6% → 97.1%） | 仅 RE18 有一条 | 大 | High — 应在每个关键决策点 |
| Self-reflection 需要 external grounding（研究） | 有 Self-Review 但无外部验证要求 | 中 | Medium — Self-Review 缺少工具验证 |
| 工具清点为研究第 0 步（Plan 1 教训） | 工具规则埋在 RE21-23 子节 | 大 | High — 已两次遗漏 |
| Overtriggering 风险（Claude 4.6）| 部分规则使用 NEVER/ALWAYS | 小 | Low — 但应审查是否有过激语言 |

## 5. 具体改写建议

### 5.1 workflow.md 改写建议

**目标**：~80-90 行，always-loaded 核心规则，agentic 风格

**段落级建议**：

**Mindset（保留，微调）**：
- M1-M5 已是优秀的 agentic 内容，保留
- M6-M8（write-lock）移到专门的「行动边界」段
- 增加一条元认知触发器

**Flow（补充 WHY）**：
- 保留 Scenario A/B，但补充为什么先研究后计划的理由
- F3 "simple" 改为明确引用 Complexity Calibration

**Complexity Calibration（保留）**：
- 已经是好的授权式设计
- 小改：补充 WHO 决定复杂度（AI 提议，human 确认）

**Annotation Protocol（重写为目标+约束）**：
- 当前 A1 过长，拆分
- 6 种标注类型保留（这是 baton 的核心机制）
- 但将每种类型的响应要求从 prescriptive 改为 constraint + WHY
- 补充示例（AN17-18 的精简版）

**Rules → 重组为「行动边界」+「质量标准」+「文件规范」**：
- **行动边界**（HARD_CONSTRAINT，保持命令式）：write-lock, BATON:GO, 文件范围限制
- **质量标准**（COGNITIVE_GUIDE，目标驱动 + WHY）：证据标准、验证要求、元认知检查点
- **文件规范**（FORMAT_REQUIREMENT，保持 prescriptive）：## Todo 格式、批注区、命名规则
- 删除冗余（R1=M6, R5=A8 等）

**新增段落**：
- **证据标准**：✅/❌/❓ 体系 + "should be fine" is NOT valid + Every claim requires file:line
- **工具使用原则**：研究前清点工具（从子节提升为核心规则）
- **阶段衔接**：说明 RESEARCH/PLAN/ANNOTATION/IMPLEMENT 详细指南由 SessionStart hook 按需注入

### 5.2 workflow-full.md 改写建议

**目标**：~370 行，各阶段详细指南，phase-guide.sh 动态提取

**共享头部（L1-67）**：与 workflow.md 保持一致（两份文件头部相同的设计是好的，保留）

**[RESEARCH] 改写方向**：
- 重组为：目标 → 成功标准 → 约束 → 策略提示
- **工具清点提升为第 0 步**（解决两次遗漏的根因）
- Execution Strategy 从 4 步操作清单改为策略提示（保留 RE7 observe-then-decide）
- 保留 Self-Review 和 Questions for Human Judgment（优秀独创内容）
- 保留 Evidence Standards（已是好的约束式）
- 减少 FORMAT_REQUIREMENT 的 rigidity — 给出输出目标而非严格模板
- 增加元认知触发器（研究支持 78.6% → 97.1% 的提升）
- 增加 1-2 个具体示例（官方：examples > rules）

**[PLAN] 改写方向**：
- 保留 Approach Analysis (First Principles)（PL13-16 是优秀内容）
- 保留 When Research Discovers Fundamental Problems（PL17-21）
- PL14-15 模板改为成功标准（goal-driven）
- PL19 patch/root 二分法改为更灵活的描述
- Self-Review prompts 保留

**[ANNOTATION] 改写方向**：
- 大部分已是约束式，小幅优化
- 保留 AN17-18 的行为示例（这是全文档最有效的内容之一）
- 增加元认知触发器：「Before responding to [Q], ask: am I about to answer from memory?」
- 减少与 workflow.md 的冗余（不需要重述 A1-A10 的全部内容）

**[IMPLEMENT] 改写方向**：
- 6 步检查清单（IM2-IM7）改为：质量目标 + 自检触发器 + 约束
- 保留 IM17-18（依赖顺序/并行执行）— 有独立价值
- 减少与 Rules 段的冗余

### 5.3 分层混合策略矩阵

基于 § 2 和 § 3 的研究，为每条规则确定目标风格：

| 规则类型 | 目标风格 | 理由 | 示例 |
|----------|---------|------|------|
| HARD_CONSTRAINT（行动边界） | **命令式** MUST/MUST NOT | 2.8x 遵从率；格式不遵从是 18% 失败原因 | "No source code before BATON:GO" |
| COGNITIVE_GUIDE（认知指导） | **目标驱动 + WHY** | 官方确认 "general instructions > prescriptive steps" for reasoning | "Build understanding deep enough that the human can judge correctness" |
| PROCESS_STEP（关键流程） | **约束式 + WHY** | 告知 WHY 比裸命令更有效（官方） | "Update document body when annotation accepted, because log alone means todolist reads outdated state" |
| FORMAT_REQUIREMENT（格式要求） | **Prescriptive** | 格式必须精确（hooks grep 依赖） | "## Todo / - [ ] / - [x]" |
| STRATEGY_HINT（策略建议） | **启发式** | 给 heuristics 而非 if-then（Right Altitude） | "When tracing 3+ parallel paths, consider using subagents" |

## 6. 指令预算评估

| 组件 | 规则数 | 注入方式 |
|------|--------|----------|
| Claude Code 系统提示 | ~50 | 自动 |
| workflow.md（slim） | 45 → 目标 ~40（去冗余） | CLAUDE.md 引用，always-loaded |
| phase-guide 注入（最大 = RESEARCH） | 36 → 目标 ~30（去冗余） | SessionStart hook |
| **总计（最大场景）** | ~120 | 在 150-200 限制内 ✅ |

## Self-Review

- **3 个批判性问题**：
  1. 「广泛适用 > 特定案例」的 Arize 研究是否适用于 baton？baton 的 annotation 类型（6 种）是「特定案例」还是「广泛适用的框架」？— 我认为是后者，因为它们是可复用的分类体系而非 one-off 规则
  2. 元认知触发器的 97.1% 提升是否在 coding agent 场景下也成立？Galileo 研究的是通用 QA，coding agent 的任务更复杂 — 需要实际测试验证
  3. 将 65% prescriptive 改为混合策略后，是否会导致 AI 在「应该严格执行但被写成 agentic 风格的规则」上打折扣？— 分层策略通过保留硬约束的命令式来缓解

- **最弱的结论**：「指令预算 ~120 条在限制内」— 这个计算假设每条规则等权重，但实际上复杂规则消耗更多注意力。可能需要实际测试验证

- **如果进一步调查会改变什么**：如果能做 A/B 测试（原版 vs agentic 版），用具体的 baton 任务衡量遵从率，就能得到定量结论而非依赖外部研究的类推

## Questions for Human Judgment

1. **annotation 类型的粒度**：当前 6 种类型（NOTE/Q/CHANGE/DEEPER/MISSING/RESEARCH-GAP）是否都有必要？还是可以简化？
    → **建议：保留全部 6 种。** 从 Plan 1（5 轮）和 Plan 2（2 轮）的实际使用看：[Q] 和 [DEEPER] 高频，[NOTE] 和 [MISSING] 中频，[RESEARCH-GAP] 低频但触发了最有价值的补充研究，[CHANGE] 未使用但在实施阶段后会变常用。每种类型代表不同认知意图（查代码回答 vs 深入调查 vs 验证安全性），帮助 AI 选择正确的响应策略。成本极低（仅标签），去掉任何一种会让 AI 缺少明确的处理模式。

2. **Rules 段的功能定位**：当前 Rules 段是 14 条操作指令的 catch-all。改写时应该保留一个集中的 Rules 段，还是把规则分散到各自的语境段落中？
    → **建议：混合式 — 短集中段 + 语境分散。** 硬约束（write-lock, BATON:GO, 文件范围, 3x 失败停止）集中为「行动边界」段（~8 条），前置以利用 primacy effect（Arize 研究确认首因效应）。认知指导分散到 Mindset、证据标准等语境段落中。格式规范集中为短「文件规范」段。这兼顾了可扫描性和语境理解。

3. **示例 vs 精简**：官方建议增加示例（3-5 个），但 workflow.md 有 200 行限制。
    → **建议：在 workflow.md 增加 2-3 个关键示例（~15 行），通过去冗余腾出空间。** 官方说 "examples are pictures worth 1000 words"，当前全文档仅 AN17-18 有示例，而那恰好是最有效内容。去除 3 条冗余（R1=M6, R5=A8, P2=R15）+ 紧缩描述可腾出 ~15 行。建议示例：(1) 证据标准 good vs bad (2) disagree with evidence 场景。workflow-full.md 无限制，各阶段放更多示例。
## Annotation Log

### Round 1 (2026-03-05)

**[NOTE] § Questions for Human Judgment — 已回答问题**
"已回答上面问题"
→ 人类在 3 个问题下方添加了追问，要求 AI 给出建议。
  Q1（annotation 类型）：建议保留全部 6 种，基于实际使用频率和认知意图区分。
  Q2（Rules 段定位）：建议混合式 — 硬约束集中前置 + 认知指导按语境分散。
  Q3（示例 vs 精简）：建议增加 2-3 个关键示例，通过去冗余腾出空间。
  已将建议直接整合到 Questions 段落中。
→ Result: accepted

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 4.1 风格对齐度：prescriptive 的具体条目有哪些？ -->
[NOTE]
  已回答上面问题

# Plan: 基于 GPT-5.4 Prompt Guidance 研究的 Baton 改进

> 基于 research-prompt-guidance.md § 9.2 的可借鉴模式
> 复杂度：Small（2 文件，scope 来自研究，无新依赖）

## 设计理由

research-prompt-guidance.md 的分析识别出 5 个可借鉴的模式。本计划筛选其中**与 baton 现有设计自然融合、不引入新概念**的改进，以轻量增补的方式合入 workflow-full.md。

workflow.md 不改动——它是 ~100 行的 always-loaded 核心规则，当前已在合理范围内。改进内容属于阶段级细节，应进入 workflow-full.md 的各阶段段落。

## 改动清单

### 变更 1：RESEARCH 阶段增加「空结果恢复」策略

**文件**：`.baton/workflow-full.md` — `[RESEARCH]` 段落的 Strategy Hints

**理由**：research-agentic-rewrite.md 记录了"工具清点已两次遗漏"的问题（§ 4.3）。当前 workflow-full.md:122 要求"inventory all available tools"，但没有规定工具返回空结果时的行为。GPT-5.4 的 `<empty_result_recovery>` 模式直接解决这个 gap。

**具体改动**：在 Strategy Hints（workflow-full.md:124-129 之后）增加一条策略提示：

```markdown
- **Empty results ≠ no results**: if a tool search returns empty or suspiciously narrow results,
  try at least one fallback (alternate keywords, broader filters, different tool) before concluding
  nothing exists. Record what you tried
```

**风格**：启发式（Strategy Hint），非命令式。与现有 Strategy Hints 的语调一致。

**影响范围**：仅 RESEARCH 阶段行为。不影响其他阶段。

---

### 变更 2：IMPLEMENT 阶段增加「依赖前置检查」触发器

**文件**：`.baton/workflow-full.md` — `[IMPLEMENT]` 段落的 Self-Check Triggers

**理由**：当前 workflow-full.md:347-349 定义了依赖排序规则（有依赖 → 顺序，无依赖 → 可并行），但缺少**执行前验证前置条件是否满足**的检查。GPT-5.4 的 `<dependency_checks>` 指出"不因最终操作看起来明显就跳过前置步骤"。

**具体改动**：在 Self-Check Triggers（workflow-full.md:341-344 之后）增加一条触发器：

```markdown
- **Before starting a dependent item**: verify the prerequisite item's actual output matches
  what this item expects — don't assume a checked `[x]` means the implementation matches the plan
```

**风格**：元认知触发器（与现有 Self-Check Triggers 的"After writing code"、"Before marking complete"格式一致）。

**影响范围**：仅 IMPLEMENT 阶段有依赖关系的 todo items。

---

### 变更 3：IMPLEMENT 阶段增加「完成度定义」

**文件**：`.baton/workflow-full.md` — `[IMPLEMENT]` 段落的 Completion 小节

**理由**：当前 Completion 小节（workflow-full.md:357-362）描述了完成后的动作（run tests, append retrospective），但没有显式定义**什么条件下任务算完成**。GPT-5.4 的 `<completeness_contract>` 模式提供了声明式的完成度定义。

**具体改动**：在 Completion 小节的开头增加完成度定义：

```markdown
#### Completion
A task is complete when ALL of:
- Every todo item is `[x]` or explicitly marked `[blocked]` with reason
- Each `[x]` item passed self-check (code re-read vs plan intent)
- Full verification passes (typecheck/test)
```

然后保留现有的"After ALL items: run full test suite..."内容。

**风格**：声明式合约（定义状态，而非描述步骤）。

**影响范围**：仅 IMPLEMENT 阶段的完成判定。completion-check.sh hook 已经做了部分检查（grep `- [ ]`），此处是 advisory 层面的补充。

---

### 变更 4：RESEARCH 阶段增加「多轮扫描」策略提示

**文件**：`.baton/workflow-full.md` — `[RESEARCH]` 段落的 Strategy Hints

**理由**：当前 RESEARCH 阶段有"observe-then-decide"（workflow-full.md:126）这一优秀的认知原则，但缺少**对复杂研究任务的结构化策略**。GPT-5.4 的研究三阶段模式（Plan → Retrieve → Synthesize）提供了一个轻量的框架。

**具体改动**：在 Strategy Hints 末尾增加：

```markdown
- **For complex research**: consider three passes — (1) list 3-6 sub-questions to answer,
  (2) investigate each + follow 1-2 second-order leads that emerge from initial findings,
  (3) synthesize by resolving contradictions before writing conclusions
```

**风格**：启发式（"consider"而非"MUST"）。与现有"Use subagents when you encounter 3+ call paths"的建议语调一致。

**影响范围**：仅 RESEARCH 阶段。作为策略提示，AI 可根据任务复杂度自主决定是否采用。

---

### 变更 5：IMPLEMENT 阶段增加「实现自主性」定义

**文件**：`.baton/workflow-full.md` — `[IMPLEMENT]` 段落，Quality Goal 之后新增小节

**理由**：当前 IMPLEMENT 阶段定义了硬约束（发现遗漏 → 停、3x 失败 → 停、不超出文件范围），但没有显式定义**在这些约束之内 AI 应该多自主**。导致 AI 可能在每个 todo item 之间等待人类确认，或遇到小阻碍就停下来。GPT-5.4 的 `<autonomy_and_persistence>` 模式 + 用户 Q3 的"端到端解决问题"需求指向同一个 gap。

BATON:GO 本身就是人类的端到端授权信号——这个变更只是让这个隐含授权变成显式指引。

**具体改动**：在 Quality Goal 之后、Constraints 之前新增：

```markdown
#### Autonomy After BATON:GO
- BATON:GO is your authorization to proceed end-to-end: implement → verify → mark complete.
  Do not stop at analysis or partial fixes; do not ask permission for each todo item.
- If you encounter a blocker, attempt to resolve it yourself (alternative approach, different tool,
  broader search) before consulting the human.
- Stop and consult only at hard boundaries:
  (a) plan omission discovered — update plan.md, wait for confirmation
  (b) same approach fails 3x — report with evidence
  (c) change needed outside plan's file list — propose in plan first
```

**风格**：授权式（定义"你可以做什么"而非"你必须做什么"），与硬约束互补。

**影响范围**：仅 IMPLEMENT 阶段。不改变 RESEARCH/PLAN/ANNOTATION 阶段的人机交互模式。

---

### 变更 6：IMPLEMENT 阶段增加「进度沟通」指引

**文件**：`.baton/workflow-full.md` — `[IMPLEMENT]` 段落，Autonomy 之后新增小节

**理由**：变更 5 鼓励 AI 自主推进，但自主不等于沉默。人类需要知道进度，特别是长 todolist 场景。GPT-5.4 的 `<user_updates_spec>` 提供了一个简洁的模式。

**具体改动**：

```markdown
#### Progress Communication
- Update the human at major phase transitions or when something changes the plan.
- Each update: what was done + what's next. Keep it to 1-2 sentences.
- Do not narrate routine tool calls or file reads.
```

**风格**：简洁的行为指引（3 条），非详细规范。

**影响范围**：仅 IMPLEMENT 阶段的人机沟通。

---

### 不做的变更（及理由）

| 研究建议 | 为什么不做 |
|---------|----------|
| XML 合约块结构（§ 9.4） | Baton 的 Markdown 结构同时服务人和 AI，不需要 XML 形式。但借鉴声明式思维——变更 3 的完成度定义已体现 |
| 指令优先级层级（§ 9.3） | 与 baton "人有最终决定权"的核心哲学冲突。标注协议已处理指令冲突 |
| RESEARCH/PLAN 阶段的自动执行 | 这些阶段的核心是构建共同理解，AI 不应跳过人类审阅。自主性仅授权给 IMPLEMENT 阶段（变更 5） |

## 风险评估

| 风险 | 可能性 | 影响 | 缓解 |
|------|--------|------|------|
| 新增内容使 workflow-full.md 更长，接近注意力预算上限 | 低 | 中 | 6 个变更共增加 ~25 行，在 research-agentic-rewrite.md 评估的 ~120 条指令预算内 |
| 新策略提示与现有 agentic 改写计划（plan-agentic-rewrite.md）冲突 | 低 | 低 | 本计划的改动是增量式的、与现有内容风格一致的增补，不涉及结构重组。若后续 agentic 改写落地，这些内容会自然融入 |
| "完成度定义"与 completion-check.sh 的检查逻辑不一致 | 低 | 低 | 完成度定义是 advisory（workflow 文本），completion-check.sh 是 deterministic（hook）。两者是互补关系，不是竞争关系 |

## Self-Review

- **最大风险**：变更 5（实现自主性）可能导致 AI 在应该停下来的时候继续推进。缓解：显式列出了 3 个硬边界（plan omission, 3x failure, file scope），这些与现有 Action Boundaries 一致，不是新增约束。
- **什么会让计划完全错误**：如果 baton 的 agentic 改写（plan-agentic-rewrite.md）即将落地，那么在旧结构上做增量改进可能是浪费。但当前 agentic 改写仍在研究/批注阶段，这些改进可以立即生效，且方向一致。
- **被拒绝的替代方案**：(1) 在 workflow.md 中增加这些内容——但 workflow.md 是 ~100 行的核心规则层，阶段特定内容属于 workflow-full.md。(2) 用 XML 合约块重构 baton 的 prompt 结构——过度工程化，Markdown 对人和 AI 都够用。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 变更 3：为什么用声明式而非清单式？ -->

## Annotation Log

### Round 1 (2026-03-06)

**[Q] § 不做的变更 — 三个追问**

Q1: "如果要做进度更新规范和自动执行低风险操作呢?"
→ 进度更新：可以做。新增变更 6（Progress Communication），定义为 IMPLEMENT 阶段的 3 条简洁指引。
→ 自动执行：重新定义为"IMPLEMENT 阶段的实现自主性"。新增变更 5（Autonomy After BATON:GO）。关键洞察：BATON:GO 本身就是端到端授权信号，不需要额外的"低风险自动执行"通用策略——只需在 IMPLEMENT 阶段显式声明这个隐含授权。RESEARCH/PLAN/ANNOTATION 阶段不适用自动执行（核心是构建共同理解）。
→ Result: 采纳，新增变更 5 和变更 6。更新了"不做的变更"表格。

Q2: "提示词结构需要像 OpenAI 那样做结构性合约吗?"
→ 不需要照搬 XML 形式。Baton 的 Markdown 结构同时服务人和 AI，已有 Layer 0/1/2 的模块化设计。但借鉴**声明式思维**是有价值的——变更 3（完成度定义）已经体现了这个思路（"A task is complete when ALL of..."而非"After ALL items: do X"）。
→ Result: 不增加新变更，已有变更 3 体现了声明式思维。

Q3: "端到端解决问题，遇阻自行尝试？"
→ 这正是变更 5 解决的问题。在 IMPLEMENT 阶段的硬约束（plan omission → 停, 3x failure → 停, 超出文件范围 → 停）之内，AI 应被鼓励自主推进。变更 5 的措辞"attempt to resolve it yourself before consulting the human"直接回应了这个需求。
→ Result: 已被变更 5 覆盖。更新了 Self-Review 的最大风险评估。

### Round 2 (2026-03-06)

**[Q] § 整体计划 — 积极和消极影响**
"这次改进对目前的 baton 有什么积极和消极的影响吗?"
→ 积极：(1) 填补 IMPLEMENT 阶段的自主性真空，与现有 3 个 hooks 无冲突 (2) 空结果恢复解决已知痛点（两次遗漏） (3) 完成度定义与 completion-check.sh 形成 advisory/deterministic 互补 (4) 依赖前置检查填补顺序执行的盲区
→ 消极：(1) 指令预算缓冲从 ~55 条缩减到 ~45 条 (2) 变更 5 的自主性如果 AI 误判"阻碍" vs "plan omission"可能绕过应停的点（已通过 3 个显式硬边界缓解） (3) 与 agentic 改写可能有措辞重复（内容有价值，格式可能需微调） (4) 纯 advisory 无新 hook 兜底（设计上正确但遵循依赖 AI 注意力）
→ 总体判断：积极影响是具体的、可验证的；消极影响是可控的、有缓解措施的。建议推进。
→ Result: 分析完成，等待人类决定
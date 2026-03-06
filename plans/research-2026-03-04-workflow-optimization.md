# Research: Prompt 设计风格对比 — Active Recall vs Baton

## 研究范围

对比 "Active Recall Generator" 风格的提示词设计与 Baton 当前方案，提取可借鉴的设计模式。

研究对象：
- Active Recall Generator prompt（用户提供的示例）
- Baton workflow.md（`.baton/workflow.md`）
- Baton workflow-full.md（`.baton/workflow-full.md`）

## Active Recall Generator 风格分析

原文：
```
"Act as my generative learning coach for [TOPIC].
Don't let me read passively. Make me produce.
For each subtopic:
-Make me write a summary
-Make me create an analogy
-Make me generate examples
-Make me create 3 flashcards
Keep it interactive and adapt based on my answers."
```

### 设计模式提取

| 模式 | 实现方式 | 强度 |
|------|---------|------|
| 角色分配 | "Act as my coach" | 弱——角色标签在长对话中容易丢失 |
| 行为约束 | "Don't let me read passively" | 中——明确了禁止行为 |
| 结构化输出模板 | "For each subtopic: summary, analogy, examples, flashcards" | 强——"每个X必须产出Y"格式不容易遗漏 |
| 动态适应 | "adapt based on my answers" | 弱——缺乏具体的适应规则 |

### 适用场景

- 短对话、单目标、低风险
- 学习/训练场景
- 人类是主要产出者，AI是引导者

### 局限

1. **单向推动**——AI推动人类产出，没有机制让人类挑战AI
2. **无质量验证闭环**——产出的正确性依赖人类自觉
3. **无阶段划分**——所有内容在一个扁平流程中完成
4. **角色约束弱**——"Act as"在长对话中容易退化

## 与 Baton 的结构化对比

| 维度 | Active Recall | Baton |
|------|--------------|-------|
| 角色定义 | 角色标签（"Act as my coach"） | 行为规则（三条覆盖默认行为的原则） |
| 互动方向 | 单向（AI→人类产出） | 双向（AI产出→人类批注→AI回应→循环） |
| 质量保证 | 无 | file:line 证据、write lock、self-review |
| 复杂度适应 | "adapt based on answers"（模糊） | Complexity Calibration 四档（Trivial/Small/Medium/Large） |
| 结构 | 扁平列表 | 分阶段流程（research→plan→annotation cycle→implement） |
| 强制性 | 低——人类可以敷衍回答 | 高——BATON:GO 写锁、批注必须响应 |
| 产出形式 | 人类产出（summary, analogy 等） | AI产出文档，人类产出批注 |

### Baton 已具备的 Active Recall 特征

- **批注区** = 强制人类产出反馈（类似 "Make me produce"）
- **Annotation Protocol** = 结构化的互动模板（类似 "For each subtopic"）
- **Complexity Calibration** = 适应性（类似 "adapt based on answers"，但更精确）

### Baton 当前缺失的

1. **批注区是被动的**——人类可以不写任何批注就说 "出 plan" 或加 BATON:GO
2. **research.md 的输出格式偏叙述体**——不如 "每个X必须有Y" 的模板格式清晰
3. **复杂度适应是静态的**——初始判断后不会根据批注反馈动态调整

## 可借鉴的设计模式

### 模式 1: 强制产出检查点

**问题**: 人类可能被动审阅 research.md/plan.md，不写批注就继续推进，导致共识是虚假的。

**Active Recall 的启发**: "Don't let me read passively. Make me produce."

**应用到 Baton 的方式**:

AI 在 research.md 末尾（Self-Review 之后、批注区之前）增加一个 `## 需要人类判断的问题` 区域，提出 2-3 个**真正需要领域知识才能回答**的问题。这些不是 self-review 的自问自答，而是 AI 确实不知道答案、需要人类输入的问题。

示例：
```markdown
## 需要人类判断的问题

1. EventBus 的 listener 注册顺序是否有业务含义？代码中没有显式排序（event-bus.ts:45），但不确定是否有隐含约定。
2. 缓存 TTL 设为 300s 是基于什么业务需求？没有找到相关文档或注释。
3. 这个模块的测试覆盖率很低（仅 2 个测试），是有意为之还是遗漏？
```

**效果**: 把批注区从"可选的反馈渠道"变成"必须回应的检查点"。人类至少需要回答这些问题才能有信心继续。

### 模式 2: 模板化输出 > 叙述化输出

**问题**: Baton 的 research.md 指南用叙述方式描述应包含的内容（"What Research Should Cover" 列了 4 个要点），但这容易导致 AI 在某些方面写很多、在另一些方面遗漏。

**Active Recall 的启发**: "For each subtopic: summary, analogy, examples, flashcards"——每个单元必须产出固定的几样东西。

**应用到 Baton 的方式**:

将 research.md 中的代码路径分析改为严格模板：

```markdown
### [路径名称]

**调用链**: A (file:line) → B (file:line) → C (file:line) → [停止: 原因]
**风险点**: ✅/❌/❓ + 具体描述
**未验证假设**: 列出未读的代码和原因
**如果这里出错**: 影响范围描述
```

**效果**: "每个代码路径必须有4项"比"研究应涵盖关键执行路径"更不容易遗漏。

### 模式 3: 动态复杂度调整

**问题**: Baton 的 Complexity Calibration 在流程开始时确定（Trivial/Small/Medium/Large），之后不变。如果初始判断偏低，后续批注轮次中大量出现 [DEEPER] 和 [MISSING]，但流程仍按低复杂度进行。

**Active Recall 的启发**: "adapt based on my answers"——根据互动反馈调整。

**应用到 Baton 的方式**:

增加一条规则：如果单轮批注中出现 **3 个以上 [DEEPER] 或 [MISSING]**，AI 应主动建议：

> "本轮批注表明初始复杂度判断可能偏低。建议将复杂度从 [当前] 升级到 [建议]，这意味着 [具体变化：如增加研究深度、拆分更细的 todo 等]。是否同意？"

**效果**: 复杂度不再是一次性判断，而是一个可以随证据调整的信号。

### 不值得借鉴的模式

1. **"Act as" 角色标签**——Baton 的"三条行为原则"方式更有效。行为规则比角色扮演更持久、更具约束力。
2. **完全由 AI 驱动的交互节奏**——Active Recall 中 AI 控制何时推进。Baton 中人类控制节奏（通过批注和 BATON:GO），这对工程场景更安全。

## 补充：角色扮演式 vs Agentic 式提示词 — 范式对比

（回应批注 [NOTE] §1）

### 两种范式的本质区别

这不是"哪种写法更好"的问题，而是两种**完全不同的设计范式**，解决不同层面的问题。

| 维度 | 角色扮演式 (Role-playing) | Agentic 式 |
|------|--------------------------|------------|
| 核心假设 | AI 是对话者，输出是文本 | AI 是执行者，拥有工具和环境 |
| 状态管理 | 无——一切在对话上下文中 | 有——文件作为持久状态（research.md, plan.md） |
| 质量保证 | 依赖模型的"表演能力" | 依赖行为规则 + 工具约束 + 外部验证 |
| 可组合性 | 低——每个 prompt 是独立的 | 高——可以分阶段、分模块、多 agent 协作 |
| 复杂度天花板 | 低——上下文窗口是硬限制 | 高——文件状态不受上下文窗口限制 |
| 可复现性 | 低——同一 prompt 不同模型/不同次表现差异大 | 较高——行为规则 + 工具调用更确定 |
| 上手难度 | 低——自然语言描述即可 | 高——需要理解工具链、状态流、约束机制 |

### 为什么角色扮演式提示词"看起来更好"

角色扮演式提示词有几个直觉优势：

1. **认知负担低**——"Act as my coach" 一句话就建立了交互预期
2. **即插即用**——不需要特定工具链，任何 LLM 都能用
3. **直觉化**——人类天然理解角色互动，不需要学习协议

这让它在**社交媒体传播**上有巨大优势：一段 5 行的 prompt 比 300 行的 workflow.md 更容易分享和理解。但传播性 ≠ 有效性。

### 为什么角色扮演式在工程场景中不够用

**问题 1: 角色标签是弱约束**

"Act as my code reviewer" 在第 3 轮对话后，AI 很可能退化成"帮你写代码"而不是"审查你的代码"。原因：LLM 的注意力机制会随着对话增长，逐渐稀释开头的角色设定。

Baton 的应对：不依赖角色标签，而是用**行为规则**（"Verify before you claim"、"Disagree with evidence"）。规则比角色更具体、更可验证，AI 更难偷偷违反。

**问题 2: 没有外部状态就无法处理复杂任务**

角色扮演式 prompt 的所有状态都在对话上下文中。这意味着：
- 上下文窗口用完 → 前面的信息丢失
- 无法在多个会话间传递工作进度
- 无法让多个 agent 并行处理不同子任务

Baton 用文件（research.md, plan.md）作为外部状态，不受上下文窗口限制。Session handoff 和 Lessons Learned 机制让跨会话协作成为可能。

**问题 3: 没有工具 = 没有验证**

角色扮演式 prompt 只能让 AI "说"它验证了。Agentic prompt 可以让 AI **真正**去读代码、跑测试、检查依赖。

"我检查了代码，没有问题" vs AI 实际执行 `grep` + `read file:line` 并展示证据——后者不可伪造。

### 两种范式的适用边界

```
复杂度低 ←————————————————————→ 复杂度高
风险低   ←————————————————————→ 风险高

[角色扮演式最优区间]
|████████████|                            |
 学习辅导      创意写作
 简单问答      头脑风暴

              [两种都可以]
              |████████|
               代码解释
               简单重构

                        [Agentic式最优区间]
                        |████████████████████|
                         多文件修改    架构变更
                         生产代码      多人协作
```

### 关键洞察：它们不在同一层

角色扮演式是**通信范式**（AI 怎么说话）。
Agentic 式是**执行范式**（AI 怎么做事）。

它们可以叠加使用。例如 Baton 的 Mindset 部分（"You are an investigator, not an executor"）本质上就有一点角色设定，但它服务于行为规则，而不是相反。

真正的问题不是"角色扮演 vs agentic"，而是：

> **你的 prompt 是在设定 AI 的"人设"，还是在约束 AI 的"行为"？**

前者（"Act as X"）依赖模型理解并维持一个模糊的期望。
后者（"在 X 条件下必须做 Y"）给出了可验证的约束。

对于**有风险的、有状态的、需要验证的任务**（即工程任务），行为约束远比角色设定有效。

### 对 Baton 的启示

1. **Baton 走 agentic 路线是正确的**——工程场景的复杂度和风险要求外部状态、工具验证、行为约束
2. **但 Baton 可以借鉴角色扮演式的"低认知负担"优势**——workflow.md 的入门门槛偏高，可以考虑增加一个 quickstart 或 TL;DR 版本
3. **Mindset 部分是两种范式的好的融合点**——用角色语言建立直觉（"investigator"），用行为规则保证执行（三条原则）

## Self-Review

1. **一个批判性审阅者会问的问题**: "强制产出检查点"会不会增加人类负担，导致人类为了快速推进而随便回答，反而降低质量？
   - 这是真实风险。关键在于问题的质量——必须是 AI 确实无法自行判断的问题，而不是走形式。如果问题本身就能从代码中找到答案，人类会（合理地）觉得烦。

2. **最弱的结论**: 模式 3（动态复杂度调整）的 "3 个以上" 阈值是拍脑袋定的，没有经验数据支撑。实际中可能需要根据使用情况调整。

3. **进一步调查可能改变什么**: ~~如果研究更多的 prompt engineering 框架（如 Chain-of-Thought、ReAct、Tree-of-Thought），可能会发现更多值得借鉴的结构化模式，目前只对比了一种风格。~~ → 已调查，见下方补充章节。

## 补充：主流 Prompt 框架对 Baton 的影响分析

（回应批注 [DEEPER] §Self-Review 第 3 点）

调查了以下框架/范式，逐一分析与 Baton 的关系：

### 框架 1: Chain-of-Thought (CoT)

**核心机制**: 强制 AI 逐步推理，而非直接给出结论。

**与 Baton 的关系**: Baton 的 research.md 本质上就是一个**外化的 CoT**——不是在 AI 的内部推理链中完成，而是写成文档让人类可审阅。这比标准 CoT 更好，因为：
- 标准 CoT：推理过程在 AI 内部，人类只看到结果
- Baton research.md：推理过程外化为文档，人类可以在任何环节批注

**新发现**: 2025-2026 的研究表明，对于 reasoning model（Claude Extended Thinking、o-series），显式 CoT prompting 反而有害——模型已经内置了推理链，外部再加一层会干扰。这意味着 Baton 的 research.md 不应该理解为"让 AI 做 CoT"，而应该理解为"让 AI 把理解外化给人类审阅"。**动机是透明性，不是推理质量。** 这个区分很重要。

**对 Baton 的影响**: 无需改动。Baton 的 research.md 已经超越了 CoT 的设计意图。

### 框架 2: ReAct (Reasoning + Acting)

**核心机制**: Thought → Action → Observation 循环。AI 推理下一步该做什么，执行工具操作，观察结果，再推理。

**与 Baton 的关系**: 这是最值得注意的框架。Baton 的实现阶段（per-item execution sequence）已经隐含了 ReAct：
1. Re-read plan → **Thought**
2. Read target files → **Action + Observation**
3. Implement → **Action**
4. Run typecheck/build → **Action + Observation**
5. Mark [x] → **Thought**（判断是否通过）

但 Baton 的研究阶段缺乏显式的 ReAct 循环。当前写法是叙述性的（"Identify entry points... For each function, read the IMPLEMENTATION..."），没有明确要求 AI 在每一步观察结果后再决定下一步。

**新启发**: 可以在 research.md 的研究阶段引入更显式的 Observe-then-Decide 模式：

```
在跟踪调用链时：
1. 读取当前节点的实现 → 记录发现
2. 基于发现决定下一个要跟踪的节点（不要预先列出所有节点）
3. 如果发现与预期不符 → 记录为 ❓ 并调查
```

这比当前的"for each call, read the IMPLEMENTATION"更能防止 AI 走马观花。

### 框架 3: Tree-of-Thought (ToT)

**核心机制**: 同时探索多条推理路径，像决策树一样展开并比较。

**与 Baton 的关系**: plan.md 的 "Approach Analysis" 已经是轻量版 ToT——要求 AI 推导 2-3 种方案并比较。

**新发现**: 行业共识是 ToT 对大多数任务来说 compute cost 不值得（来源：promptingguide.ai），只在高风险决策中有意义。Baton 的 2-3 approach 方案分析是恰当的简化——不需要完整的 ToT。

**对 Baton 的影响**: 无需改动。当前设计已在正确的点上。

### 框架 4: Flow Engineering（最重要的发现）

**核心概念**: "设计 LLM 调用周围的控制流、状态转换和决策边界，而不是优化调用本身。" 把 agent 构建当作**软件架构问题**而不是 prompt 优化问题。

**关键洞察**: 这完全重新框定了 Baton 的定位。

Baton 不是一个 "prompt"。Baton 是一个 **flow engineering 解决方案**：
- research.md → plan.md → implement = **状态转换**
- BATON:GO write lock = **决策边界**
- 批注区 + Annotation Protocol = **控制流**（人类在循环中）
- Complexity Calibration = **flow 选择器**（不同复杂度走不同流程）

这意味着之前把 Baton 和 Active Recall Generator 做对比，其实是**跨层对比**：
- Active Recall Generator = prompt engineering（优化单个 LLM 调用的措辞）
- Baton = flow engineering（设计多个 LLM 调用之间的状态和控制流）

行业趋势明确支持 flow engineering 方向：企业团队发现 prompt 长度翻倍但准确率停滞（来源：PromptLayer blog），真正的杠杆在 flow 设计而不是 prompt 措辞。

**对 Baton 的影响**: 这不是一个需要改动的发现，而是一个**定位澄清**。Baton 的 README/文档可以明确自称为 "flow engineering protocol" 而不是 "prompt"。这会帮助用户理解为什么它比 "Act as my..." 复杂得多——因为它解决的是不同层面的问题。

### 框架 5: Reflection Pattern

**核心机制**: AI 先生成，再自我批评，再修正——然后才呈现给用户。

**与 Baton 的关系**: Baton 的 Self-Review 是一种反射，但它只在文档完成时发生一次。行业中的 Reflection Pattern 是**持续的**——在每一步操作后都有小的反射循环。

**新启发**: Baton 的实现阶段可以加入微反射——在每个 todo item 完成后，不只是"run typecheck"，而是：

```
完成 todo item 后：
1. 重新读取修改后的代码（不是从记忆中回忆）
2. 与 plan.md 中的设计意图对比
3. 如果偏离 → 记录原因，判断是计划有误还是实现有误
```

这比当前的 "run typecheck/build" 验证更深——typecheck 只检查语法正确性，微反射检查设计一致性。

### 框架 6: Plan Mode vs Act Mode（来自 Cline）

**核心机制**: 显式分离"规划"和"执行"两种模式，不同模式下 AI 有不同的权限和工具。

**与 Baton 的关系**: Baton 的 BATON:GO write lock 正是这个模式的实现——而且比 Cline 更严格。Cline 的 Plan/Act 切换由 AI 判断，Baton 的切换由**人类控制**（添加/移除 BATON:GO）。

**对 Baton 的影响**: 验证了 Baton 的设计选择。人类控制模式切换比 AI 自主切换更安全。

### 框架 7: Red/Green TDD（来自 Simon Willison）

**核心机制**: 先写失败的测试，再写代码让测试通过。在 agentic 上下文中，这给了 AI 一个明确的"完成"信号。

**与 Baton 的关系**: Baton 当前没有显式集成 TDD。todo item 的验证方式是"run typecheck/build"，但没有要求先写测试。

**新启发**: 对于非 trivial 的 todo item，可以在 per-item execution sequence 中加入：

```
0. （可选）为此项变更写一个预期行为的测试
1. Re-read plan section
2. Read target files
3. Implement
4. Run tests → 红变绿 = 完成
```

但这需要 Complexity Calibration 配合——Trivial/Small 项目加 TDD 是过度工程。

### 总结：什么真正改变了分析

| 框架 | 对之前分析的影响 |
|------|----------------|
| CoT | 澄清：Baton research.md 的动机是透明性，不是推理质量。无需改动 |
| ReAct | **新增**：研究阶段可以更显式地要求 observe-then-decide |
| ToT | 确认：2-3 approach 方案分析已经足够。无需改动 |
| Flow Engineering | **重新框定**：Baton 是 flow engineering，不是 prompt。这改变了定位，不改变设计 |
| Reflection | **新增**：实现阶段可以加入微反射（设计一致性检查） |
| Plan/Act Mode | 确认：人类控制模式切换更安全。无需改动 |
| Red/Green TDD | **可选**：非 trivial 项目可集成 TDD。需要 Complexity Calibration 配合 |

**最重要的发现**: Baton 已经是 flow engineering，这在行业趋势中处于正确位置。之前的 Self-Review 低估了 Baton 已有设计的合理性——不是"可能会发现更多值得借鉴的模式"，而是 Baton 已经在做这些框架想做的事情，只是没有用这些术语。

真正值得新增的只有两点：
1. 研究阶段的 observe-then-decide 模式（来自 ReAct）
2. 实现阶段的微反射（来自 Reflection Pattern）

### Confirmation Bias 自检

（回应批注 [Q] §1）

上述分析存在 confirmation bias 风险：先有"Baton 是 flow engineering"的框架，再把其他框架映射上去。为了对冲这个偏差，用 context7 查询了 Anthropic 官方课程和 Claude 平台文档，发现了一些**挑战原有结论**的证据：

**挑战 1: 角色扮演在 agentic 场景中并非无用**

Anthropic 官方的 Claude Agent SDK 示例中直接使用角色扮演：
```python
system_prompt = "You are a senior Python developer. Always follow PEP 8 style guidelines."
```
（来源：platform.claude.com/docs/en/agent-sdk/quickstart）

这意味着 Anthropic 自己认为**角色设定 + agentic 工具**是可以叠加使用的。之前我说"角色标签在长对话中容易丢失"仍然成立，但结论应该修正为：角色设定作为 agentic 系统的**一层**（而非替代品）是有价值的。Baton 的 Mindset 部分已经在做这件事。

**挑战 2: 模块化 prompt 构建是一个被忽视的中间地带**

Anthropic 官方课程（prompt_engineering_interactive_tutorial）教授了一种 **10 元素模块化 prompt 构建法**：
1. User role
2. Task context（任务背景）
3. Tone context（语调）
4. Detailed task description and rules（详细规则）
5. Examples（示例）
6. Input data（输入数据）
7. Immediate task（当前任务）
8. Precognition（"think step by step"）
9. Output formatting（输出格式）
10. Prefill（预填充）

这不是角色扮演，也不是 flow engineering——而是**结构化的单次调用优化**。Baton 对单次 LLM 调用的内部结构没有明确指导（workflow.md 关注的是调用之间的流程）。如果要让每一次 AI 产出更可靠，可以考虑在 research.md/plan.md 的输出规范中借鉴这种元素拆分思路。

**挑战 3: ReAct 的核心价值不只是工具使用**

context7 中的 ReAct 文档提到一个关键点：CoT 不接入外部世界会导致**事实幻觉和错误传播**（"Fehlerfortpflanzung"）。这直接对应 Baton 的第一原则（"Verify before you claim"），但揭示了一个更深的联系——Baton 的 file:line 证据要求本质上就是 ReAct 的 Observation 步骤。之前我把这分析为"Baton 隐含了 ReAct"，但更准确的说法是：**Baton 的证据原则和 ReAct 的 Observation 机制解决的是同一个问题——防止 AI 在没有外部验证的情况下自信地编造**。

### 修正后的结论

原结论："真正值得新增的只有两点"
修正后："在当前调查深度下，识别出两个高置信度的新增点（observe-then-decide、微反射），但还有一个中等置信度的发现（模块化 prompt 元素对单次调用质量的提升）值得进一步实验验证。"

同时，之前对角色扮演的否定过于绝对。修正为：角色设定作为行为规则的补充层（而非替代品）在 agentic 系统中仍有价值，Baton 当前的 Mindset 设计已体现了这一点。

参考来源：
- [ReAct Prompting - Prompt Engineering Guide](https://www.promptingguide.ai/techniques/react)
- [Tree of Thoughts - Prompt Engineering Guide](https://www.promptingguide.ai/techniques/tot)
- [Simon Willison - Agentic Engineering Patterns](https://simonwillison.net/2026/Feb/23/agentic-engineering-patterns/)
- [PromptHub - Prompt Engineering for AI Agents](https://www.prompthub.us/blog/prompt-engineering-for-ai-agents)
- [PromptLayer - Flow Engineering](https://blog.promptlayer.com/prompt-routers-and-flow-engineering-building-modular-self-correcting-agent-systems/)
- [SitePoint - Agentic Design Patterns 2026](https://www.sitepoint.com/the-definitive-guide-to-agentic-design-patterns-in-2026/)
- Anthropic Claude Platform Docs - Agent SDK System Prompts（via context7: /websites/platform_claude_en）
- Anthropic Courses - Prompt Engineering Interactive Tutorial（via context7: /anthropics/courses）
- DAIR-AI Prompt Engineering Guide（via context7: /dair-ai/prompt-engineering-guide）

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->

## Annotation Log

### Round 1 (2026-03-04)

**[NOTE] § 整体研究方向**
"我指的是类似这样的角色扮演提示词 是更好的prompt吗 和之前提到的提示词要 agentic呢 对比分析"
→ 增加了 `## 补充：角色扮演式 vs Agentic 式提示词 — 范式对比` 章节。
  核心结论：两者不在同一层——角色扮演是通信范式（AI怎么说话），agentic 是执行范式（AI怎么做事）。
  对于工程场景，agentic 的行为约束远比角色设定有效，但角色扮演式的低认知负担值得借鉴。
→ Result: 已补充分析

### Round 2 (2026-03-04)

**[DEEPER] § Self-Review 第 3 点**
"根据Self-Review 进一步调查可能改变什么"
→ 增加了 `## 补充：主流 Prompt 框架对 Baton 的影响分析` 章节。
  调查了 7 个框架/范式（CoT、ReAct、ToT、Flow Engineering、Reflection、Plan/Act Mode、Red/Green TDD）。
  最重要的发现：Baton 已经是 flow engineering 解决方案，行业趋势验证了这个方向。
  真正值得新增的只有两点：(1) 研究阶段的 observe-then-decide 模式，(2) 实现阶段的微反射。
→ Result: 已深入调查，Self-Review 第 3 点已替换为实际调查结论

### Round 3 (2026-03-04)

**[Q] §1 — Confirmation bias 风险**
"刚才的调查是基于之前的分析结论进行的，还是独立进行的？如果是前者，是否存在 confirmation bias 的风险？"
→ 确实存在。调查流程是先有"Baton 是 flow engineering"框架再映射，而非独立评估。
  用 context7 补充查询后发现了 3 个挑战原有结论的证据，已在"Confirmation Bias 自检"章节修正。
  最重要的修正：角色设定的否定过于绝对，Anthropic 官方 SDK 示例证明角色设定 + agentic 工具可叠加。
→ Result: 已修正，增加了自检章节

**[Q] §2 — 未使用 context7 的影响**
"调查我看没有使用context7 工具，是否意味着这些结论完全基于模型的内在知识？"
→ 第一轮调查使用了 WebSearch + WebFetch（6 个外部来源），不是纯内在知识。但确实遗漏了 context7。
  补充使用 context7 后查询了 3 个库（dair-ai/prompt-engineering-guide、platform_claude_en、anthropics/courses），
  发现了 Anthropic 官方课程的 10 元素模块化 prompt 构建法和 SDK 中角色设定的实际使用，修正了部分结论。
→ Result: 已补充 context7 查询，增加了 3 个新来源

**[Q] §3 — 为什么没用 context7**
"如果没有使用context7 是什么原因呢?"
→ 初始判断是 context7 适用于编程库 API 文档，不适用于学术方法论。
  实际验证后发现 context7 收录了 dair-ai/prompt-engineering-guide 和 Anthropic 官方课程，确实包含相关内容。
  这是工具使用上的盲点——应该先尝试再判断，而不是基于假设排除。
→ Result: 已修正，后续调查中已使用 context7
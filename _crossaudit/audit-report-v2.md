# Baton v2.1 技能包深度审计报告 (完整版)

---

## 第零部分：设计机制全景清单

在逐项分析之前，先建立完整的机制清单。Baton v2.1 包含以下独立设计机制：

### 核心创新 (行业内无直接对标)

| # | 机制 | 所在文件 | 解决的问题 |
|---|------|----------|-----------|
| 1 | **循环批注 (Annotation Cycle)** | annotation-cycle SKILL.md | 人机协作模式——既不是全自主也不是 PR 审批 |
| 2 | **上下文切片 (Context Slices)** | context-slice SKILL.md | LLM 长上下文质量衰减 |
| 3 | **设计-Todo 分离** | plan-first-plan SKILL.md | 人类审批的是设计(What/Why)，AI 生成实施步骤(How) |
| 4 | **反合理化系统** | 全部 8 个 SKILL.md | AI 会为跳过流程编造合理理由 |
| 5 | **证据优先方法论** | research + verification + review | AI 会把"我认为"伪装成"事实是" |

### 架构机制

| # | 机制 | 所在文件 | 解决的问题 |
|---|------|----------|-----------|
| 6 | **三层架构 + 优雅降级** | workflow-protocol.md + 各 SKILL.md | 不同项目成熟度需要不同约束级别 |
| 7 | **唯一责任人原则** | workflow-protocol.md | 多技能抢同一动作造成冲突 |
| 8 | **Phase-lock 纵深防御** | phase-lock.sh + Cursor rules + SKILL checkpoints | 在不允许写代码的阶段阻止写代码 |
| 9 | **Workflow Protocol 单一真相源** | workflow-protocol.md | 工作流逻辑散布在多文件造成不一致 |

### 行为塑造机制

| # | 机制 | 所在文件 | 解决的问题 |
|---|------|----------|-----------|
| 10 | **内联检查点 (⚠️ Checkpoints)** | 全部 8 个 SKILL.md | AI 在关键决策点偏离流程 |
| 11 | **Assume-bug-first 审查法** | code-reviewer SKILL.md | 自我 review 的确认偏差 |
| 12 | **升级阶梯 (Escalation Ladder)** | plan-first-implement SKILL.md | AI 在失败路径上无限重试 |
| 13 | **Announce 模式** | 全部 8 个 SKILL.md | LLM 陈述意图后遵从率更高 |
| 14 | **"有能力但无上下文的开发者"心智模型** | plan-first-plan SKILL.md | Todo 项含糊不清 |

### 治理机制

| # | 机制 | 所在文件 | 解决的问题 |
|---|------|----------|-----------|
| 15 | **Hard Constraints 生命周期** | hard-constraints.md + 多个 SKILL.md | 非谈判规则的过期和遗忘 |
| 16 | **Review Routing 预加载** | plan-first-plan SKILL.md | 审查时遗漏重要维度 |
| 17 | **子代理注入协议** | implementer.md + spec-reviewer.md + quality-reviewer.md | 子代理接收过多/过少上下文 |
| 18 | **Quick-path 快速通道** | workflow-protocol.md + CLI | 小变更的仪式感过重 |

**合计 18 个独立设计机制。** 下面逐一深入分析。

---

## 第一部分：核心创新深度解析

### 1.1 循环批注 — 系统存在的核心理由

#### 它解决了什么

当前 AI 辅助开发只有两种范式：

| 范式 | 代表 | 致命缺陷 |
|------|------|----------|
| AI 全自主 | Devin, Codex agent | 偏离预期时大量工作浪费 |
| 人类审批 PR | Copilot + 人工 review | 反馈粒度粗，修改成本高 |

循环批注发明了**第三范式**：人类不写代码、不写计划，只在 AI 产出上打轻量标记，AI 被强制处理每一个标记并迭代。

#### 深层设计解剖

**四种标记类型的语义梯度：**

```
[NOTE]           → 补充信息（AI 整合）
[Q]              → 需要 AI 回答的问题（AI 回答 + 可能改设计）
[CHANGE]         → 直接修改请求（AI 执行 + 记录前后对比）
[RESEARCH-GAP]   → 知识盲区（暂停 → 定向研究 → 回填 → 继续）
```

这四种类型按**人类干预强度递增**排列：NOTE 是最轻的（"顺便说一下"），RESEARCH-GAP 是最重的（"我们对这一块其实不了解"）。这种梯度设计让人类可以用最小的认知成本施加最大的影响。

**[RESEARCH-GAP] 是 mid-design 知识补给——循环批注最精妙的设计：**

传统流程中，如果设计审查时发现知识盲区，要么：
- 人类自己去调研（打断审查流，认知成本高）
- 忽略盲区继续审批（埋下风险）
- 全部推倒重来研究（效率极低）

[RESEARCH-GAP] 创造了第四条路：**原地暂停 → 触发定向补充研究 → 写入 research.md → 回填到 annotation log → 继续处理剩余批注**。这把"发现知识不够"从一个中断事件变成了一个可以在流程内处理的正常步骤。

并且设置了**溢出保护**：每轮最多 2 个 RESEARCH-GAP，超过说明初始研究不充分，建议重新做完整研究。这防止了批注阶段变成变相的研究阶段。

**每轮 Conflict Check 是收敛保障：**

三维冲突检测：
- a. 共享资源冲突：修改后/未修改的 Decision 是否引用了同一个数据结构、API、共享状态？
- b. 文件范围冲突：File change manifest 中同一文件是否在多个 Decision 下有不同意图？
- c. 约束冲突：新增/修改的 Decision 是否违反 hard-constraints.md？

不可解决的冲突 → **STOP**，把冲突双方呈现给人类决策。这保证了每一轮批注都不会引入逻辑矛盾。

**Annotation Priority 的权威模型：**

```
人类批注 > AI 技术偏好（绝对优先）

唯一例外：安全与正确性
  → 数据丢失风险？
  → 安全漏洞？
  → Hard constraint 违反？
  如果都不是 → 这是偏好，不是安全问题 → 执行人类意图
```

关键的反滥用条款：*"This is NOT a license to second-guess every annotation. 'I think there's a better way' is not a safety concern."* 这精准封堵了 AI 最常见的不服从方式——把偏好伪装成安全顾虑。

**Annotation Log 是决策审计链：**

```markdown
### Round 1 (2026-02-27)
- [NOTE] "Database connection pool max 50" → Updated Decision #2
- [CHANGE] "Add error retry mechanism" → New Decision #4
- [Q] "Can the existing logger handle audit logs?" → Yes, ...
⚠️ Conflict check: [results]
```

每个设计决策的来源（AI 提出/人类批注）、时间（Round N）、变更内容都可追溯。这不仅是文档，更是问责机制——如果实现出了问题，可以追溯到是哪一轮批注引入的变更。

#### 循环批注的局限性

**局限 1: 无法检测自由格式插入**

annotation-cycle Step 2 说：*"Human notes marked with [NOTE]/[Q]/[CHANGE]/[RESEARCH-GAP], or any free-form text inserted between existing content."*

但 AI 没有 plan.md 的上一版本。Step 1 说"Re-read the file from disk"（不依赖记忆），但检测"人类插入的新文本"需要知道"什么是旧文本"。**这需要 diff 能力，而系统没有提供。** 在实践中，AI 只能可靠检测带标记的批注，自由格式文本很可能被忽略。

**局限 2: 审批确认过于非正式**

"The human confirms by ANY of: 'confirmed' / 'looks good' / 'proceed to plan'" — 这些是日常对话用语。如果人类说"The research looks good, but I have more questions"，AI 可能错误地将前半句当作确认。

**局限 3: 无计划版本历史**

Annotation log 记录了 WHAT changed，但 plan.md 只保留最新状态。如果人类在 Round 3 说"回到 Round 1 对 Decision 3 的方案"，没有机制可以恢复之前的版本。

**局限 4: Todo 质量无审查门**

人类审批的是 DESIGN，不是 TODO。Todo 在 Phase 2 由 AI 自动生成，没有明确的"审查 Todo 质量"步骤。如果 AI 生成了模糊的 Todo 项（"Update config for SMS"），会直接影响实现质量。

---

### 1.2 上下文切片 — 循环批注的下游解药

#### 与循环批注的协同关系

多轮批注让 plan.md 持续膨胀：设计决策增加、annotation log 积累、修改痕迹堆叠。一个经过 3 轮批注的 plan.md 可能有 300-500 行。

**这正是 context-slice 存在的原因。** 它不是独立的创新——它是循环批注的必然后果和解药：

```
循环批注 → plan.md 质量更高但体积膨胀
                 ↓
context-slice → 将膨胀的计划切割为精准的上下文包
                 ↓
implement → 每个 todo 只接收自己需要的信息
```

#### "Files NOT to modify" — 负面边界的创新

传统的任务分配只说"做什么"。context-slice 还明确说"**不要碰什么**"：

```markdown
**Files NOT to modify:**
- [Explicit list of files OUT OF SCOPE for this item]
```

Rule 3 规定：*"List at minimum the files modified by adjacent todo items."* 这确保子代理不会意外越界。这是**显式负面边界**——在 AI 工作分配中几乎没有先例。

#### 粒度阈值作为 Todo 质量回压

Rule 4 说：如果一个 slice 引用超过 3 个 decisions、修改超过 3 个文件、目标超过 1 句话、或预计超过 15 分钟——**拆分 todo item**。

这实际上是对上游 Todo 生成质量的**回压机制**：如果 Todo 粒度太粗，slice 生成会失败（或发出警告），迫使系统回去拆分 Todo。这部分弥补了 1.1 中提到的"Todo 质量无审查门"的问题。

#### 并行性识别 vs 顺序执行的矛盾

context-slice Step 4 说：*"Identify items with no dependencies and no overlapping files."*

但 plan-first-implement 说：*"In order. Do not skip ahead."*

**矛盾：** slice 花时间识别了哪些 item 可以并行，但 implement 忽略了这个信息。并行性分析在当前设计中是"写了但没用"。它的价值在于**未来的多代理并发实现**，但当前版本没有这个能力。

---

### 1.3 设计-Todo 分离 — 审批的正确抽象层次

#### 为什么不让人类直接审批 Todo

传统做法：AI 写一个包含步骤的计划 → 人类审批整个计划（包括步骤）。

Baton 的做法：AI 写设计（What/Why）→ 人类审批设计 → AI 把设计转化为 Todo（How）。

这个分离的洞察是：**人类擅长判断"这个方案对不对"，不擅长判断"这个任务拆分合不合理"。** 让人类审批实施步骤是在错误的抽象层次上浪费人类注意力。

#### 隐藏的超能力：计划稳定性

设计审批后，"合同"是设计文档，不是 Todo。这意味着：
- 如果实施中发现 Todo 拆分不合理，可以重新生成 Todo，**不需要重新审批设计**
- 如果 review 发现问题，修复是"plan amendment"，不是重新设计

但这个能力**没有被显式文档化**。plan-first-plan 没有说"你可以重新生成 Todo 而不重新审批设计"。

---

### 1.4 反合理化系统 — AI 的认知行为疗法

#### 系统规模

统计全部 8 个 SKILL.md 中的反合理化条目：

| 技能 | 条目数 | 内联检查点数 |
|------|--------|-------------|
| plan-first-research | 9 | 3 |
| plan-first-plan | 9 | 4 |
| annotation-cycle | 7 | 4 |
| context-slice | 8 | 2 |
| plan-first-implement | 8 | 2 |
| verification-gate | 5 | 1 |
| code-reviewer | 6 | 1 |
| using-baton | 5 | 2 |
| **合计** | **57 条** | **19 个** |

这是一个有 57 条规则、19 个检查点的**行为修正框架**。

#### 三列覆盖模式

每条规则的结构：`思维触发 → 反驳逻辑 → 正确行动`

```
| "I already know this codebase" | Your knowledge is stale. | Read the actual files now. |
```

这不是简单的"不要做 X"——它预测了 AI 的**具体内心独白**，提供了**为什么这个想法是错的**的逻辑反驳，然后给出**具体替代行动**。这是认知行为疗法（CBT）的"识别→挑战→替代"模式应用于 AI。

#### 内联检查点的放置策略

检查点不是随机分布的——它们被精确放置在 AI **最可能偏离**的决策点上：

- Research Step 1（scope）: *"Are you skipping scope identification because 'the task is simple'?"* — AI 倾向于跳过范围定义
- Research Step 2（reading）: *"Are you relying on memory instead of reading files?"* — AI 倾向于用训练知识替代实际代码阅读
- Plan Step 4（design）: *"Are you planning to 'figure out details during implementation'?"* — AI 倾向于推迟细节
- Annotation Step 3（processing）: *"Are you thinking 'this annotation doesn't change anything'?"* — AI 倾向于忽略不同意的反馈
- Implement Step 2: *"Are you about to 'improve' something not in the plan?"* — AI 倾向于在实施时发挥创意

每个检查点的定位都基于对 LLM 行为模式的深度理解。

---

### 1.5 证据优先方法论 — 区分"我认为"与"事实是"

#### Research 中的三级验证系统

```
✅ Verified safe — [evidence: file:line showing why]
❌ Verified unsafe — [evidence: file:line showing the problem]
❓ Unverified — [what you still need to read to confirm]
```

关键规则：*"If a risk is ❓ Unverified, you are NOT done with research."*

这创造了一个**完备性追踪机制**：research 不是"我觉得差不多了"就完成，而是所有风险都必须达到 ✅ 或 ❌ 才能完成。唯一的例外是"需要运行时测试才能验证的风险"。

#### Findings vs Assumptions 分离

*"Any claim without direct code evidence belongs here (Assumptions), not in Findings."*

这迫使 AI 对每一个断言进行自我审计："这个结论有代码证据支持吗？"如果没有，就必须放到 Assumptions 里，降低其可信度。这直接对抗了 LLM 最危险的行为：**把推测当事实陈述**。

#### 反通用知识规则

*"DO NOT mark something as a risk based on general knowledge (e.g., 'event publishing inside transactions is usually unsafe'). General patterns do not apply until you verify them against THIS codebase's actual configuration."*

这防止了 AI 用训练数据中的通用模式替代对当前代码的实际分析——这是一种非常精准的行为校正。

#### Verification 中的证据标准

```
✅ Command output showing pass/fail counts
✅ Log excerpt or error message
❌ "It should work because I wrote it correctly"
❌ "The tests pass" (without showing which tests)
❌ "I checked and it's fine" (checked how?)
```

三个 ❌ 示例精确对应了 AI 最常见的三种虚假验证：自信宣称、笼统陈述、模糊确认。

---

## 第二部分：行为工程——系统如何塑造 AI 行为

### 2.1 Baton 的 AI 行为理论

系统基于以下关于 LLM 行为的假设（全部是经验上已验证的）：

| 假设 | 对策机制 | 验证来源 |
|------|----------|---------|
| AI 无约束会漂移 | Phase-lock, checkpoints | 所有 AI 编码实践 |
| AI 会合理化跳过规则 | 57 条反合理化规则 | 长 prompt 遵从率研究 |
| AI 质量随上下文长度衰减 | Context slices | LLM attention 衰减研究 |
| AI 自我审查有确认偏差 | Assume-bug-first | 认知心理学 |
| AI 不会主动与人类迭代 | Annotation cycle | AI 产品 UX 研究 |
| AI 会同时做太多事 | 唯一责任人, 阶段分离 | 多代理系统经验 |
| AI 把推测当事实 | Findings/Assumptions 分离 | LLM 幻觉研究 |
| AI 会伪造验证结果 | 证据标准 + 命令输出 | AI 代码生成实践 |
| AI 偏好速度而非正确性 | "创意在计划，纪律在实施" | 编码实践观察 |
| AI 回避困难对话 | Escalation ladder 强制升级 | AI 助手行为观察 |

**元创新：** Baton 把 AI 行为当作软件工程问题来处理——用状态机、访问控制、接口契约、单一职责、纵深防御来约束一个"有能力但不守纪律的开发者"。

### 2.2 Announce 模式的隐藏心理学

每个技能开始时都要求 AI 宣告："I'm using the plan-first-research skill."

这不仅是给人类看的——**对 LLM 而言，陈述意图后遵从该意图的概率更高**。这是一种轻度的"自我提示"（self-prompting），利用了 LLM 会保持与前文一致性的特性。

### 2.3 "有能力但无上下文的开发者" — Todo 的心智模型

plan-first-plan 说：*"Assume the implementer is a capable but context-free developer. Give them enough detail to implement without guessing."*

这个心智模型是为 context-slice 的子代理设计的。它迫使 Todo 生成者写出完全自包含的任务描述：文件名、具体变更、验证步骤。如果你不能给一个"有能力但不知道背景"的人解释清楚这个 Todo 项，那这个 Todo 项就不够好。

### 2.4 Phase-lock 的三层纵深

```
Layer 1: phase-lock.sh hook (硬阻断, Claude Code only)
  ↓ 如果平台不支持 hook
Layer 2: Self-enforcement protocol (Cursor rules, 自我约束)
  ↓ 如果自我约束失败
Layer 3: Inline ⚠️ checkpoints in SKILL.md (心理提醒)
```

**只有 Layer 1 是可靠的。** Layer 2 和 3 的有效性取决于 AI 是否认真读了规则。但三层叠加比单层好——即使每层只有 60% 遵从率，三层叠加的综合遵从率约为 94%（假设独立）。

---

## 第三部分：技能间矛盾 (扩展版)

### 矛盾 1: research.md 三个互相矛盾的模板 [严重度: 中]

系统中存在三个版本的 research.md 结构：

| 来源 | Sections |
|------|----------|
| `cmd_init` 生成的 `_task-template/research.md` | Objective, Scope, Files reviewed, Findings, Assumptions, Risks, Architecture, Open questions (8个) |
| `cmd_new_task` 的 fallback | 仅 `# Research: <task-id>` (0个 section) |
| plan-first-research SKILL.md 定义 | Objective, Scope, Files reviewed, Current behavior, Execution paths, Risks and edge cases, Architecture context, Technical references, Evidence snippets, Assumptions, Open questions (11个) |

**三者互不一致。** 模板有 `## Findings` 但技能定义没有；技能定义有 `## Current behavior`、`## Execution paths`、`## Evidence snippets` 等但模板没有。

### 矛盾 2: detect_phase 对 verification 的判断跳过了失败状态 [严重度: 高]

```bash
if [ -f "$verification" ]; then
    # verification.md 存在就直接进入 review 或 done
    # 不管 verification 是否通过
fi
```

verification.md 一旦存在（哪怕是空的、测试失败的），detect_phase 就跳到 review。**缺少 "verify (failing)" 状态。**

### 矛盾 3: slice 阶段在 WORKFLOW MODE 是强制的，但 implement 有 fallback [严重度: 高]

detect_phase 在 WORKFLOW MODE 下：没有 `## Context Slices` → 返回 `slice` 阶段，无法进入 implement。

但 plan-first-implement 专门设计了 "Fallback to full-plan mode"：*"If no context slices exist, use full plan.md as context with a warning"*。

**这个 fallback 在 WORKFLOW MODE 下永远不会被触发**——因为 detect_phase 不让你到达 implement 阶段如果没有 slices。Fallback 只在 STANDALONE 模式下有意义。

### 矛盾 4: review 后修复循环在状态机中不存在 [严重度: 高]

plan-first-implement 定义了完整的 review fix 流程（plan amendment → regenerate slices → fix → re-verify → re-review，最多 2 轮）。

但 workflow-protocol.md 只有 `review → done`，没有回退路径。detect_phase 返回 `review (blocking issues)` 后，没有机制回到 implement。

### 矛盾 5: context-slice 识别并行性，implement 禁止乱序 [严重度: 中]

context-slice Step 4: *"Identify items with no dependencies and no overlapping files."*

plan-first-implement: *"In order. Do not skip ahead."* 和 *"I'll do items out of order for efficiency → Order may encode dependencies → Follow the order unless impossible"*

并行性分析的结果在当前设计中被浪费。

### 矛盾 6: annotation-cycle 要求检测自由格式文本但无 diff 能力 [严重度: 中]

Step 2: *"Human notes marked with [NOTE]/[Q]/[CHANGE]/[RESEARCH-GAP], or any free-form text inserted between existing content."*

但 Step 1 说 *"Do not rely on memory. Re-read it now."*

检测"插入的新文本"需要与旧版本比较，但系统没有提供 diff 能力，且明确要求不依赖记忆。**标记型批注可靠检测，自由格式文本不可靠。**

### 矛盾 7: hard-constraints 在 PROJECT STANDALONE 模式的约束力矛盾 [严重度: 低]

workflow-protocol.md: PROJECT STANDALONE → *"Read as advisory"*

plan-first-plan Step 3: *"flag it explicitly and propose an alternative or request human confirmation"* — 这是强制性行为，不是 advisory。

### 矛盾 8: annotation-cycle 的 WORKFLOW MODE handoff 指引是 STANDALONE 逻辑 [严重度: 低]

annotation-cycle 审批后说：*"Tell the human: 'Next step: load the plan-first-plan skill'"*。但在 WORKFLOW MODE 下，阶段转换由 detect_phase 自动完成，人类只需 `baton next`。

### 矛盾 9: "15 分钟"超时不可测量 [严重度: 低]

plan-first-implement: *"Never spend more than 15 minutes on a failing approach without escalating."*

AI 没有 wall-clock time 概念。应该用"尝试次数"（如"2 次失败后升级"）而不是时间来衡量。

---

## 第四部分：流程断点 (扩展版)

### 断点 1: BATON_CURRENT_ITEM 未设置 — slice scope check 是死代码

phase-lock.sh 的 slice scope check 依赖 `BATON_CURRENT_ITEM` 环境变量，但**没有任何组件设置它**。

```bash
item_num="${BATON_CURRENT_ITEM:-}"
if [ -z "$item_num" ]; then return 0; fi  # ← 永远走这里
```

v2.1 CHANGELOG 宣传 *"Slice scope check is now BLOCKING by default"*，但这是**死代码**。

### 断点 2: approved → slice → implement 需要三次人工干预

```
approved → baton next → load plan-first-plan (生成 Todo)
        → baton next → load context-slice (生成 Slices)
        → baton next → load plan-first-implement (开始写代码)
```

从"批准设计"到"开始写代码"需要人类运行 3 次 `baton next`。没有 `baton auto` 命令来链接自动化阶段。

### 断点 3: session-start.sh 的 cat 命令不是可执行指令

session-start hook 输出 `cat ~/.baton/skills/.../SKILL.md` 给 AI 看。但 AI 收到的是字符串，不是系统指令——AI 可能用 Read tool 读文件（好），可能忽略（坏），可能运行 bash cat（次优）。**没有强制执行保证。**

### 断点 4: 无 skip-slice 正式机制

detect_phase 在有 Todo 但无 Slices 时强制进入 slice 阶段。小任务不需要 slices 但无法跳过。唯一方法是 hack plan.md 加空的 `## Context Slices` section。

### 断点 5: plan.md 承载过多状态

plan.md 同时包含：设计文档 + Annotation log + Todo checklist + Context Slices。

一个经过 3 轮批注的 8-item Todo 的 plan.md 可能超过 600 行。这个文件既是人类的审查界面（需要可读），又是机器的状态容器（需要可解析）。这两个需求本身是矛盾的。

### 断点 6: review.md 位置遗留问题

`cmd_init` 创建 `tasks/_task-template/reviews/`（目录，带 s），但 code-reviewer 输出到 `review.md`（文件，不在目录中），detect_phase 检查 `$task_dir/review.md`。`reviews/` 目录是 v1 遗留物，永远不会被使用。

### 断点 7: 确认语义过于宽泛

research 确认：*"'confirmed' / 'looks good' / 'proceed to plan'"*
plan 审批：*"'approved' / 'looks good' / 'go ahead'"*

*"looks good"* 在两个阶段都是触发词。如果人类说 *"The research looks good, but I have a question about the plan"*，AI 可能误判为 research confirmed。

### 断点 8: Todo 生成无独立审查门

人类审批 DESIGN，但不审批 TODO。如果 AI 生成了质量差的 Todo（模糊、遗漏验证步骤、粒度不当），没有 gate 来拦截。context-slice 的粒度阈值可以回压，但它发生在 Todo 之后，不是之前。

### 断点 9: 无多任务并行机制

`active-task` 文件只支持一个活跃任务。如果需要暂停 task-A 处理紧急 task-B：
1. `baton active task-B` 切换
2. task-A 的文件状态保留在磁盘
3. 但 AI 的 session 上下文中仍有 task-A 的信息，可能造成混淆

没有 "stash"、"pause" 或 "parallel tasks" 机制。

---

## 第五部分：运行时行为分析 (扩展版)

### 5.1 AI 遵从率预测

| 行为点 | 遵从率 | 主要风险 |
|--------|--------|---------|
| 读取完整 SKILL.md | 70% | session-start 输出不是强制指令 |
| 按技能定义（而非模板）写 research.md | 50% | 三个互相矛盾的模板混淆 AI |
| 不跳过 scope identification | 60% | "简单任务"是 AI 最常犯的假设 |
| Plan 阶段不写代码 (Claude Code) | **95%** | phase-lock hook 硬阻断 |
| Plan 阶段不写代码 (Cursor) | 40% | 纯自我约束 |
| 正确处理每一个批注 | **80%** | [NOTE]/[Q]/[CHANGE] 标记明确；自由格式文本约 40% |
| 批注时不延迟到实施 | 75% | *"I'll address this during implementation"* 是高频合理化 |
| 每轮后执行 conflict check | 65% | *"changes are small"* 是常见跳过理由 |
| 生成 Todo 后等待 slice 而非直接实施 | 30% | AI 强烈倾向于直接开始 |
| 使用 slice 而非全量 plan | 60% | 依赖正确的 prompt 注入 |
| 不修改 slice 边界外的文件 | 55% | BATON_CURRENT_ITEM 未设置 → scope check 死代码 |
| 验证时贴真实命令输出 | **85%** | 证据标准写得很好 |
| 自我 code review 保持客观 | 35% | 确认偏差是根本性的 |
| Assume-bug-first 真正执行 | 45% | AI 倾向于正向验证 |
| 遵守 escalation ladder | 50% | AI 倾向于反复尝试 |
| 不改计划外的代码 | 70% | *"I'll improve this while I'm here"* 是最高频违规 |

### 5.2 关键运行时故障模式

#### A. "Phase drift" (阶段漂移)

**场景：** implement 阶段需要一个没在 slice 里的 import。
**预期：** 报告 scope 问题。
**实际：** AI 直接加 import（"这只是一个 import"）。phase-lock 不阻止（BATON_CURRENT_ITEM 未设置）。
**频率：** 几乎每次 implement 都会发生。

#### B. "Approval fatigue" (审批疲劳)

**场景：** research CONFIRMED → plan reviewed → annotation round 1 → annotation round 2 → APPROVED。
**结果：** 到 Round 2 人类已经开始 rubber-stamp。
**根因：** 系统没有区分"需要深度 review"和"可以快速确认"。

#### C. "Orphaned state" (孤立状态)

**场景：** session 中断（超时、关闭终端）。
**结果：** plan.md 可能写了一半（有 APPROVED 标记但 Todo 只生成了一部分），detect_phase 会认为在 `slice` 阶段（因为有 Todo 但没有 Context Slices）。

#### D. "Self-review theater" (自我审查表演)

**场景：** 自我 code review（非子代理模式）。
**预期：** Assume-bug-first，找到 bug。
**实际：** AI 快速扫描自己写的代码，每个维度都写 "✅ Good"。Assume-bug-first 退化为 confirm-correct-first。
**根因：** LLM 对自己产出的确认偏差是结构性的，不可通过 prompt 完全消除。

#### E. "Todo generation drift" (Todo 生成漂移)

**场景：** Phase 2 todo 生成。
**预期：** 5-15 分钟的精确 todo 项。
**实际：** AI 要么过于粒细（每行代码一个 item），要么过于粗粒度（"implement the auth module"），极少恰好在 5-15 分钟范围内。
**根因：** AI 对"5 分钟的工作量"没有校准能力。

#### F. "Research-gap overflow" (研究缺口溢出)

**场景：** 人类在一轮批注中写了 4 个 [RESEARCH-GAP]。
**规则：** 最多处理 2 个，推迟其余，建议重新研究。
**风险：** 第 3、4 个 gap 可能比前两个更重要，但 FIFO 顺序处理可能处理了次要的、推迟了关键的。
**缺失：** 没有优先级排序机制。

### 5.3 各平台可靠性矩阵

| 机制 | Claude Code | Cursor | Codex/OpenCode |
|------|-------------|--------|----------------|
| Phase-lock 硬阻断 | ✅ hook | ❌ 自我约束 | ⚠️ bootstrap |
| Session start 注入 | ✅ 自动 | ⚠️ rules 文件 | ❌ 手动 |
| Skill 完整加载 | ⚠️ 依赖 AI 行为 | ⚠️ 依赖 AI 行为 | ⚠️ 依赖 AI 行为 |
| Slice scope check | ❌ 死代码 | ❌ 不存在 | ❌ 不存在 |
| Annotation cycle | ✅ 可靠 | ✅ 可靠 | ✅ 可靠 |
| Subagent 上下文隔离 | ⚠️ 部分 | ❌ 无子代理 | ⚠️ 部分 |

---

## 第六部分：遗漏机制

| 缺失的机制 | 影响 | 建议优先级 |
|-----------|------|-----------|
| **BATON_CURRENT_ITEM 设置逻辑** | Slice scope check 完全失效 | P0 |
| **research.md 模板统一** | 三个矛盾模板造成 AI 混淆 | P0 |
| **review→fix 回退路径** | review 发现 BLOCKING 后状态机卡死 | P0 |
| **verify-failing 状态** | 验证失败被误判为 review 阶段 | P1 |
| **baton skip-slice 命令** | 小任务无法跳过强制 slice 阶段 | P1 |
| **baton auto 命令** | approved→todo→slice→implement 三步人工干预 | P1 |
| **plan.md 版本历史** | 无法回退到之前轮次的设计 | P2 |
| **Todo 独立审查门** | Todo 质量直接影响实施但无审查 | P2 |
| **结构化确认机制** | "looks good" 语义歧义 | P2 |
| **多任务并行支持** | 一次只能有一个活跃任务 | P2 |
| **Crash recovery** | Session 中断后状态可能不一致 | P2 |
| **Subagent review 触发条件** | 何时用子代理 review vs 自我 review 未定义 | P3 |
| **RESEARCH-GAP 优先级排序** | FIFO 可能处理次要的、推迟关键的 | P3 |
| **并行实施支持** | Slice 识别了并行性但 implement 忽略 | P3 |

---

## 第七部分：综合评分 (修订版)

### 评分维度

| 维度 | 分数 | 权重 | 加权分 | 说明 |
|------|------|------|--------|------|
| **核心创新 (循环批注)** | 9.5/10 | 20% | 1.90 | 真正的范式创新；局限性（无 diff、非正式确认）不影响核心价值 |
| **架构设计** | 9.0/10 | 15% | 1.35 | 三层架构 + 单一真相源 + 优雅降级都是正确决策 |
| **行为工程** | 8.5/10 | 15% | 1.28 | 57 条反合理化 + 19 个检查点 + assume-bug-first 是专业级的 AI 行为塑造 |
| **技能间一致性** | 6.0/10 | 15% | 0.90 | 9 处矛盾，3 处高严重度 |
| **状态机完备性** | 6.5/10 | 10% | 0.65 | 缺 verify-failing、review→fix 回退、skip-slice |
| **AI 实际遵从率** | 6.0/10 | 10% | 0.60 | Phase-lock 可靠；slice scope 死代码；自我 review 不可靠 |
| **容错与恢复** | 4.5/10 | 5% | 0.23 | 无 crash recovery、单文件过载、无版本历史 |
| **跨平台可靠性** | 5.5/10 | 5% | 0.28 | Claude Code 好；Cursor 中；Codex 低 |
| **工具链完备性** | 6.0/10 | 5% | 0.30 | BATON_CURRENT_ITEM 未设置、无 skip-slice/auto 命令 |

### **总分: 7.5 / 10**

### 评分说明

上一版评分 6.8 低估了核心创新的价值。修订版将"核心创新"和"行为工程"单独列为评分维度，反映了它们作为 Baton 真正竞争力的权重。

**7.5 分的含义：** 这是一个**设计哲学一流、工程实现八成完成**的系统。核心创新（循环批注 + 上下文切片 + 反合理化系统）在 AI 辅助开发领域有真正的原创性。但工程层面有 3 个高严重度矛盾和 1 处死代码（BATON_CURRENT_ITEM）需要修复后才能发挥设计意图的全部价值。

### Top 5 改进建议 (按 ROI 排序)

1. **修复 BATON_CURRENT_ITEM 设置机制** — P0，让 slice scope check 生效，v2.1 核心卖点
2. **统一 research.md 模板为 SKILL.md 定义的 11-section 结构** — P0，消除最常见的日常摩擦
3. **在 detect_phase 和 workflow-protocol 中加入 review→fix 回退路径** — P0，补全状态机
4. **增加 verify-failing 状态 + baton skip-slice 命令** — P1，状态机完备性
5. **增加 baton auto 命令，链接 approved→todo→slice→implement** — P1，减少审批疲劳

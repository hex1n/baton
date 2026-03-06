# Agentic 提示词改进计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 让 Baton 的 AI 提示词更加 agentic — 给 AI 清晰的执行策略和思维姿态，而不仅仅是规则和目标。

**架构：** 三层改进：workflow.md（始终加载的思维姿态 + 规则）、phase-guide.sh（按阶段注入的执行策略）、workflow-full.md（与上述同步的完整参考）。控制机制（write-lock、bash-guard）保持不变。

**根本问题：** 当前提示词是声明式的（"规则是什么"），而非过程式的（"怎么做好"）。AI 默认行为是表面化的研究、盲目顺从标注、草率的实现 — 因为提示词没有建立正确的思维姿态。

---

## Task 1：改进 workflow.md — 添加思维姿态 + 细化规则

**文件：**
- 修改：`.baton/workflow.md`

**问题：** 所有规则都是否定式的（"不准 X"、"NEVER Y"），没有解释 WHY。AI 机械地遵守规则，但不理解背后的原则。缺少思维姿态的引导。

### 1.1 新增 Mindset 段

在标题之后、Flow 之前插入：

> **改进前：** 无此段落，直接从 Write lock 开始。
>
> **Before:** No mindset section — jumps straight to "Write lock: source code writes require..."

**改进后 / After：**

```markdown
### Mindset
You are an investigator, not an executor. Your job is to surface what you know,
challenge what seems wrong, and ensure nothing is hidden from the human.
（你是调查者，不是执行者。你的职责是呈现你所知道的，质疑看起来有问题的，确保不对人隐瞒任何信息。）

Three principles that override all defaults:
（三条覆盖所有默认行为的原则：）

1. **Verify before you claim** — "should be fine" is not evidence. Read the code, cite file:line.
   （先验证再下结论 — "应该没问题"不是证据。读代码，引用 file:line。）

2. **Disagree with evidence** — the human is not always right. When you see a problem,
   explain it with code evidence. Don't comply silently, don't hide concerns.
   （用证据反驳 — 人不一定对。发现问题时，用代码证据说明。不要沉默顺从，不要隐瞒顾虑。）

3. **Stop when uncertain** — if you don't understand something, say so. Don't guess, don't gloss over.
   （不确定就停下 — 不理解就说不理解。不要猜测，不要含糊带过。）
```

### 1.2 细化标注协议描述

**`[Q]` 标注：**

| | 英文 | 中文解读 |
|---|------|---------|
| 改进前 | `answer with file:line evidence` | 用 file:line 证据回答 |
| 改进后 | `answer with file:line evidence. Read code first — don't answer from memory` | 用 file:line 证据回答。**先读代码 — 不要凭记忆回答** |

**`[CHANGE]` 标注：**

| | 英文 | 中文解读 |
|---|------|---------|
| 改进前 | `if problematic, explain with evidence + offer alternatives, let human decide` | 如果有问题，用证据说明 + 给替代方案，让人决定 |
| 改进后 | `verify safety first — check callers, tests, edge cases. If problematic, explain with evidence + offer alternatives, let human decide` | **先验证安全性 — 检查调用方、测试、边界情况。** 如果有问题，用证据说明 + 给替代方案，让人决定 |

**`[DEEPER]` 标注：**

| | 英文 | 中文解读 |
|---|------|---------|
| 改进前 | `continue investigation in specified direction` | 继续调查指定方向 |
| 改进后 | `your previous work was insufficient. Investigate seriously in the specified direction` | **你之前的工作不够充分。** 认真调查指定方向 |

**验证：** Token 数应控制在 ~600 以内（当前 ~400，Mindset 增加 ~150，标注细化增加 ~50）。

---

## Task 2：改进 phase-guide.sh — 每个阶段的执行策略

**文件：**
- 修改：`.baton/phase-guide.sh`

**问题：** 每个阶段只输出 2-3 行"产出什么"，完全没有指导"怎么做好"。这是影响最大的改动。

---

### 阶段：RESEARCH（当前 ~50 tokens → 目标 ~250 tokens）

**改进前 / Before：**
```
📍 RESEARCH phase — produce research.md
Read code deeply, trace call chains to implementations (don't stop at interfaces).
Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified. Attach file:line to every conclusion.
Simple changes may skip research and go straight to plan.md.
```
> 中文直译：研究阶段 — 产出 research.md。深入阅读代码，追踪调用链到实现层。标记风险。简单改动可跳过。
>
> 问题：只说了"读深一点"，但没有给出**怎么读深**的策略。AI 经常只读接口不追实现。

**改进后 / After：**
```
📍 RESEARCH phase — produce research.md

You are investigating code you have never seen. Your goal: build understanding
deep enough that the human can judge whether you truly comprehend the system.
（你在调查从未见过的代码。目标：建立足够深的理解，让人能判断你是否真正理解了系统。）

Execution strategy:（执行策略：）
1. Identify entry points relevant to the task (human's request or affected files)
   （识别与任务相关的入口点）
2. For each function/method call, read the IMPLEMENTATION — not just the interface
   （对每个函数调用，读实现 — 不只是接口）
3. When a call delegates to another layer, follow it. Stop only at:
   framework internals, stdlib, or external deps (annotate WHY you stopped)
   （当调用委托到另一层时，跟进去。只在以下情况停止：框架内部、标准库、外部依赖 — 标注停止原因）
4. Use subagents to trace parallel branches when you find 3+ call paths (10+ files)
   （发现 3+ 条调用路径时，用 subagent 并行追踪）

For every conclusion in research.md:（research.md 中的每个结论：）
- Attach file:line evidence. No evidence = mark as ❓ unverified
  （附上 file:line 证据。无证据 = 标记为 ❓ 待确认）
- "Should be fine" is NOT a valid conclusion — verify or mark ❓
  （"应该没问题"不是有效结论 — 验证或标记 ❓）
- Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified
  （标记风险：✅ 已确认安全 / ❌ 发现问题 / ❓ 待确认）

Simple changes may skip research and go straight to plan.md.
（简单改动可跳过研究，直接写 plan.md。）
```

**改进要点：**
- 新增角色定位："你在调查从未见过的代码"（建立调查者心态）
- 新增 4 步执行策略（入口 → 实现 → 追踪 → 并行）
- 明确什么不算证据（"应该没问题"不是结论）

---

### 阶段：PLAN（当前 ~50 tokens → 目标 ~200 tokens）

**改进前 / Before：**
```
📍 PLAN phase — produce plan.md (based on research.md + requirements)
Include: what (referencing research), why, impact scope, risk mitigation.
Approach analysis: extract constraints → derive 2-3 approaches (feasibility + pros/cons) → recommend + reasoning.
Do NOT write todolist — generate only after human approves.
```
> 中文直译：计划阶段 — 产出 plan.md。包含：做什么、为什么、影响范围、风险应对。方案分析：提取约束 → 推导方案 → 推荐。
>
> 问题：把方案分析压缩成了一行公式，AI 经常直接跳到"怎么做"而不推导。

**改进后 / After：**
```
📍 PLAN phase — produce plan.md (based on research.md + requirements)

Don't jump to "how to do it". Derive your approach from research findings:
（不要直接跳到"怎么做"。从研究发现中推导方案：）

1. Extract hard constraints from research.md (architecture limits, dependencies,
   backward compatibility, performance, team conventions)
   （从 research.md 提取硬性约束：架构限制、依赖关系、向后兼容、性能、团队规范）
2. Derive 2-3 approaches. For each:
   （推导 2-3 个方案，每个方案需说明：）
   - Feasibility: ✅ feasible / ⚠️ risky / ❌ not feasible (with file:line evidence)
     （可行性，附 file:line 证据）
   - Pros and cons (analyzed against each constraint)
     （优缺点，对照每条约束逐条分析）
   - Impact scope (files touched, callers affected)
     （影响范围：涉及文件数、受影响的调用方）
3. Recommend one + reasoning that traces back to specific research findings
   （推荐一个 + 可追溯到具体研究发现的理由）

If research revealed fundamental design problems:
（如果研究发现了根本性的设计问题：）
- Present honestly: "file:line shows X, which means Y"
  （诚实呈现："file:line 显示 X，意味着 Y"）
- Offer both: patch within existing structure vs. fix root problem
  （给出两类方案：在现有结构内打补丁 vs. 解决根本问题）
- State clearly: this is an architectural decision the human must make
  （明确声明：这是架构级决策，需要人来决定）

Do NOT write todolist — generate only after human says "generate todolist".
（不要写 todolist — 等人说"生成 todolist"后再追加。）
```

**改进要点：**
- 开头就明确"不要直接跳到怎么做"（纠正最常见偏差）
- 方案推导从一行公式展开为 3 步流程
- 新增发现根本问题时的处理策略（诚实呈现 + 两类方案 + 让人决定）

---

### 阶段：ANNOTATION（当前 ~50 tokens → 目标 ~250 tokens）

**改进前 / Before：**
```
📍 ANNOTATION cycle — plan.md awaiting approval
Human may add annotations: [NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]
Respond to each annotation, record in Annotation Log.
Human annotations may not always be correct — explain issues with file:line evidence, offer alternatives.
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
```
> 中文直译：标注循环 — plan.md 等待审批。人可能添加标注。逐条回应，记录到 Annotation Log。人的标注不一定正确。
>
> 问题：只说了"逐条回应"，但没有建立**先验证再回应**的思维模式。AI 看到 [CHANGE] 就改，很少 pushback。

**改进后 / After：**
```
📍 ANNOTATION cycle — plan.md awaiting approval

Read the document carefully. Look for new annotations:
（仔细阅读文档，查找新标注：）
[NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]

For EACH annotation, BEFORE responding:
（对每条标注，回应之前先：）

- [Q]: Don't answer from memory. Go read the actual code, then answer with file:line.
  （不要凭记忆回答。去读实际代码，然后用 file:line 回答。）
- [CHANGE]: Verify the change is safe first. Check callers, check tests, check edge cases.
  If you find a problem, say so with evidence — don't comply just because the human asked.
  （先验证改动是否安全。检查调用方、测试、边界情况。发现问题就用证据说明 — 不要因为人要求就盲从。）
- [DEEPER]: Your previous work was insufficient. This is a signal to investigate seriously,
  not just add a paragraph.
  （你之前的工作不够充分。这是认真调查的信号，不是加一段话就行。）
- [RESEARCH-GAP]: Pause other annotations. Do the research. Append findings to research.md
  as ## Supplement. Then return.
  （暂停其他标注。做补充研究。将结果追加到 research.md 作为 ## Supplement。然后回来继续。）

Record every response in ## Annotation Log with:
（在 ## Annotation Log 中记录每条回应：）
- The annotation type and section（标注类型和所在段落）
- Your response with file:line evidence（你的回应，附 file:line 证据）
- The outcome (accepted / rejected / awaiting human decision)
  （结果：接受 / 拒绝 / 等待人决定）

The human is not always right. Your job is to surface what you know.
Blind compliance is a failure mode. So is hiding concerns.
（人不一定对。你的职责是呈现你所知道的。盲从是一种失败模式，隐瞒顾虑也是。）

Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
（人满意后会说"生成 todolist"或添加 <!-- BATON:GO -->。）
```

**改进要点：**
- 核心改动：对每种标注类型建立"先验证再回应"的思维模式
- 明确两种失败模式：盲从（blind compliance）和 隐瞒（hiding concerns）
- Annotation Log 增加结果字段（accepted / rejected / awaiting）
- [DEEPER] 明确告诉 AI "你之前做得不够"而非客气地说"继续调查"

---

### 阶段：IMPLEMENT（当前 ~30 tokens → 目标 ~200 tokens）

**改进前 / Before：**
```
📍 IMPLEMENT phase — <!-- BATON:GO --> is set
Implement in Todo order. After each item: typecheck → mark [x].
After all items: run full test suite. Discover omission → stop, update plan, wait for confirmation.
```
> 中文直译：实现阶段。按 Todo 顺序实现。每个 item 完成后 typecheck → 标记 [x]。全部完成后跑测试。发现遗漏 → 停下。
>
> 问题：没有给出每个 item 的执行序列。AI 经常不重读计划就直接改代码，也不先读目标文件。

**改进后 / After：**
```
📍 IMPLEMENT phase — <!-- BATON:GO --> is set

For each todo item, follow this sequence:
（对每个 todo item，按以下序列执行：）

1. Re-read the plan section for this item — understand WHAT and WHY
   （重读计划中这个 item 对应的段落 — 理解做什么和为什么）
2. Read the target files before modifying — understand current state
   （修改前先读目标文件 — 理解当前状态）
3. Implement the change
   （实施改动）
4. Run typecheck/build. If it fails, fix before moving on
   （运行 typecheck/build。失败则先修复再继续）
5. Mark [x] only AFTER verification passes
   （只在验证通过后才标记 [x]）

Quality checks:（质量检查：）
- Only modify files listed in the plan. Need a new file? Stop, update plan, wait for confirmation
  （只改计划中列出的文件。需要新文件？停下，更新计划，等人确认）
- Discover something the plan didn't anticipate? STOP. Update plan.md, wait for human confirmation
  （发现计划未预见的情况？停下。更新 plan.md，等人确认）
- Same approach fails 3 times? Stop and report — don't keep trying
  （同一方法失败 3 次？停下报告 — 不要继续尝试）

After ALL items complete: run full test suite, record results at bottom of plan.md.
（全部完成后：跑完整测试套件，在 plan.md 底部记录结果。）
Todo items with dependencies: execute sequentially. Independent items: may run in parallel.
（有依赖的 items 顺序执行。无依赖的 items 可并行。）
```

**改进要点：**
- 核心改动：给出 5 步执行序列（重读计划 → 读目标文件 → 实现 → 验证 → 标记）
- 强调"先读再改"（步骤 1、2），纠正 AI 直接动手的习惯
- 增加质量检查清单
- 标记 [x] 从"完成后标记"变为"验证通过后才标记"

---

### 阶段：ARCHIVE（不变）

保持当前归档提醒 — 已经足够清晰。

---

## Task 3：改进 workflow-full.md — 同步 + 补强

**文件：**
- 修改：`.baton/workflow-full.md`

**改动：**

1. **添加 Mindset 段**（与 workflow.md Task 1 相同）— 确保完整参考中也包含思维姿态，即使未作为上下文加载

2. **更新 [RESEARCH] 段** — 添加与 phase-guide 改进匹配的执行策略：
   - 添加"执行策略"编号列表
   - 添加明确的"什么算证据"指导
   - 强化"深度技巧"，给出更具体的指令

3. **更新 [ANNOTATION] 段** — 添加每种标注类型的思维姿态：
   - 添加"对每条标注，回应前先..."模块（与 phase-guide 匹配）
   - 强化"AI 回应核心原则"，加入"先验证"模式
   - 添加明确的反模式："不要凭记忆回答 [Q] — 先读代码"

4. **更新 [IMPLEMENT] 段** — 添加每个 item 的执行序列：
   - 添加 5 步序列（重读计划 → 读目标文件 → 实现 → 验证 → 标记）
   - 添加"质量检查"段

5. **更新标注协议描述** — 与 workflow.md 相同的细化：
   - `[Q]`：添加"先读代码"
   - `[CHANGE]`：添加"先验证安全性"
   - `[DEEPER]`：添加"你之前的工作不够充分"

**验证：** workflow-full.md 必须是 workflow.md 的超集。workflow.md 中的所有内容都必须在 workflow-full.md 中出现（原文或扩展形式）。

---

## Task 4：更新测试

**文件：**
- 修改：`tests/test-phase-guide.sh`
- 修改：`tests/test-workflow-consistency.sh`（如需要）

**改动：**

更新测试断言以匹配新的 phase-guide 输出。需要验证的关键新关键词：

| 阶段 | 需要断言的新关键词 |
|------|-------------------|
| RESEARCH | "entry points", "IMPLEMENTATION", "evidence", "unverified" |
| PLAN | "constraints", "2-3 approaches", "Feasibility", "todolist" |
| ANNOTATION | "BEFORE responding", "verify", "Annotation Log", "not always right" |
| IMPLEMENT | "Re-read the plan", "target files", "typecheck", "STOP" |

运行 `tests/test-workflow-consistency.sh` 验证 workflow.md 和 workflow-full.md 的共享内容保持同步。

---

## Task 5：验证所有测试通过

**步骤：**
1. 运行 `bash tests/test-phase-guide.sh`
2. 运行 `bash tests/test-workflow-consistency.sh`
3. 运行 `bash tests/test-write-lock.sh`（应不受影响）
4. 运行 `bash tests/test-stop-guard.sh`（应不受影响）
5. 修复所有失败

---

## 变更总结

| 文件 | 变更类型 | 影响 |
|------|---------|------|
| `.baton/workflow.md` | 添加思维姿态，细化标注 | 始终加载的上下文获得思维姿态 |
| `.baton/phase-guide.sh` | 扩展全部 4 个阶段 | 每次会话的引导变为可执行的策略 |
| `.baton/workflow-full.md` | 同步 + 补强 | 完整参考保持一致 |
| `tests/test-phase-guide.sh` | 更新断言 | 测试匹配新输出 |
| `.baton/write-lock.sh` | 不变 | — |
| `.baton/stop-guard.sh` | 不变 | — |
| `.baton/bash-guard.sh` | 不变 | — |

## 设计决策

**为什么不让 workflow.md 更长？** workflow.md 始终加载（每次 API 调用都会消耗）。Mindset 段增加 ~150 tokens — 对其价值而言可以接受。执行策略放在 phase-guide（每次会话只加载一次）。

**为什么不改 write-lock 的消息？** write-lock 是技术强制机制，其消息已经够有效了。在那里加 agentic 内容是噪音 — AI 已经从 workflow.md 知道规则了。

**为什么 phase-guide 扩展这么多？** phase-guide 在会话开始时注入一次。成本是一次性的。收益很大：AI 获得整个会话的清晰执行策略。这是 ROI 最高的改动。

**为什么用英文写提示词？** 英文提示词对 LLM 效果更稳定，且项目是开源的，保持与现有 workflow.md 和 phase-guide 输出的一致性。
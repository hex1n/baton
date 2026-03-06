# Plan: Baton Workflow 优化 — 基于 Prompt 框架研究

## 背景

基于 research.md 的调查，从 7 个主流 prompt/agentic 框架中提取了可应用于 Baton 的改进点。本计划聚焦于高置信度的改动，排除需要进一步实验验证的项目。

## 变更概览

| # | 变更 | 来源 | 置信度 | 涉及文件 |
|---|------|------|--------|---------|
| 1 | 研究阶段增加"需要人类判断的问题" | Active Recall + 模式 1 | 高 | workflow-full.md |
| 2 | 代码路径分析改为严格模板 | Active Recall + 模式 2 | 高 | workflow-full.md |
| 3 | 研究阶段增加 observe-then-decide 规则 | ReAct | 高 | workflow-full.md |
| 4 | 实现阶段增加微反射步骤 | Reflection Pattern | 高 | workflow.md, workflow-full.md |
| 5 | 动态复杂度调整规则 | Active Recall + 模式 3 | 中 | workflow.md, workflow-full.md |
| 6 | 研究阶段增加工具使用指南 | context7 遗漏教训 | 高 | workflow-full.md |
| 7 | Annotation Protocol 增加回写纪律 | 批注轮次质量保证 | 高 | workflow.md, workflow-full.md |

### 不纳入本次计划的项目

- **模块化 prompt 元素（Anthropic 10 元素法）**: 中等置信度，需要实验验证单次调用质量是否提升。记录为未来调查方向。
- **Red/Green TDD 集成**: 补充性质，与 Baton 核心流程正交，可独立决定是否引入。
- **定位澄清（"flow engineering protocol"）**: 这是文档/README 层面的变更，不涉及 workflow 逻辑，单独处理。

## 变更详情

### 变更 1: 研究阶段增加"需要人类判断的问题"

**What**: 在 workflow-full.md 的 `[RESEARCH]` 部分，Self-Review 之后、批注区之前，增加一个必填区域 `## 需要人类判断的问题`。

**Why**: 当前批注区是被动的——人类可以不写任何批注就推进。增加 AI 主动提出的问题，把批注区从"可选反馈"变成"必答检查点"。来源：research.md § 模式 1。

**具体改动**:

在 workflow-full.md 的 `#### Self-Review` 段落之后，增加：

```markdown
#### Questions for Human Judgment (required)
After Self-Review, append a section:
## Questions for Human Judgment
- 2-3 questions that genuinely require human domain knowledge to answer
- These must NOT be questions the AI could answer by reading more code
- Examples: business intent behind a design choice, historical context, team conventions not in code
```

**Impact**: 仅影响 workflow-full.md 的 RESEARCH 部分。不影响现有流程逻辑。

**Risk**: 人类可能觉得被迫回答问题增加负担。缓解：明确限制为 2-3 个，且必须是 AI 确实无法自行判断的问题。

### 变更 2: 代码路径分析改为严格模板

**What**: 在 workflow-full.md 的 `#### What Research Should Cover` 中，将"How the code works"的叙述性描述替换为结构化模板。

**Why**: "每个X必须产出Y"的模板格式比叙述性指令更不容易遗漏。来源：research.md § 模式 2。

**具体改动**:

将当前的：
```
- **How the code works** — key execution paths, call chains, each node with file:line
  Trace call chains to leaf nodes or explicit stopping points (annotate why you stopped)
```

替换为：
```markdown
- **How the code works** — for each execution path, use this template:
  ### [Path Name]
  **Call chain**: A (file:line) → B (file:line) → C (file:line) → [Stop: reason]
  **Risk**: ✅/❌/❓ + description
  **Unverified assumptions**: what code was not read and why
  **If this breaks**: impact scope
```

**Impact**: 仅影响 workflow-full.md 的 RESEARCH 部分。研究产出格式变化，不影响流程。

**Risk**: 某些研究场景不涉及代码路径（如配置分析、架构评估），模板可能不适用。缓解：在模板前加"for code path analysis"限定语。

### 变更 3: 研究阶段增加 observe-then-decide 规则

**What**: 在 workflow-full.md 的 `#### Execution Strategy` 中增加一条显式规则，要求 AI 在跟踪调用链时先观察再决定下一步。

**Why**: 当前写法（"For each function/method call, read the IMPLEMENTATION"）是预设好的列表式遍历，AI 容易走马观花。ReAct 的 Thought→Action→Observation 循环要求每一步基于上一步的观察结果决定方向。来源：research.md § 框架 2。

**具体改动**:

在 Execution Strategy 的第 2-3 条之间增加：
```markdown
   Observe-then-decide: after reading each node's implementation, decide the next
   node to trace based on what you found — not from a pre-made list.
   If a finding contradicts expectations, mark ❓ and investigate before moving on.
```

**Impact**: 仅影响 workflow-full.md。改变研究行为，不改变流程结构。

**Risk**: 低。这是对现有行为的细化，不是新增阶段。

### 变更 4: 实现阶段增加微反射步骤

**What**: 在 workflow.md 和 workflow-full.md 的 per-item execution sequence 中，在第 4 步（typecheck/build）之后、第 5 步（mark [x]）之前，增加一个微反射步骤。

**Why**: 当前验证只有 typecheck/build，检查的是语法正确性。微反射检查的是设计一致性——实现是否偏离了 plan 的设计意图。来源：research.md § 框架 5。

**具体改动**:

workflow.md 的 per-item execution sequence（当前在 workflow-full.md:295-300）从：
```
1. Re-read the plan section for this item
2. Read the target files before modifying
3. Implement the change
4. Run typecheck/build. If it fails, fix before moving on
5. Mark [x] only AFTER verification passes
```

改为：
```
1. Re-read the plan section for this item — understand WHAT and WHY
2. Read the target files before modifying — understand current state
3. Implement the change
4. Run typecheck/build. If it fails, fix before moving on
5. Re-read the modified code (not from memory). Compare against plan's design intent.
   If implementation diverges from plan, record whether plan was wrong or implementation was wrong
6. Mark [x] only AFTER verification passes
```

**Impact**: workflow.md（简版）和 workflow-full.md（完整版）都需要更新。

**Risk**: 增加每个 todo item 的执行时间。缓解：对于 Trivial 复杂度的任务，这一步可以跳过（已被 Complexity Calibration 覆盖）。

### 变更 5: 动态复杂度调整规则

**What**: 在 workflow.md 和 workflow-full.md 的 Annotation Protocol 或 Annotation Cycle 部分，增加一条规则：批注密度作为复杂度信号。

**Why**: 当前 Complexity Calibration 是静态的，初始判断后不变。如果批注轮次中出现大量 [DEEPER]/[MISSING]，说明初始判断偏低。来源：research.md § 模式 3。

**具体改动**:

在 Annotation Protocol 末尾增加：
```markdown
#### Dynamic Complexity Adjustment
If a single annotation round contains 3+ [DEEPER] or [MISSING] annotations,
AI should suggest upgrading the complexity level:
> "Annotation density suggests initial complexity was underestimated.
>  Recommend upgrading from [current] to [suggested]. This means [specific changes]."
```

**Impact**: workflow.md 和 workflow-full.md。

**Risk**: "3 个以上"的阈值缺乏经验数据（research.md Self-Review 第 2 点已承认）。缓解：先以此为起点，在实践中调整。可在 Retrospective 中记录阈值是否合适。

### 变更 6: 研究阶段增加工具使用指南

**What**: 在 workflow-full.md 的 `[RESEARCH]` 部分的 Execution Strategy 或 Evidence Standards 中，增加一条关于文档检索工具使用的规则。

**Why**: 本次研究过程中，AI 基于假设（"context7 只适用于代码库 API 文档"）排除了可用工具，导致遗漏了 Anthropic 官方课程等有价值的来源。教训是：**应该先尝试再判断，不应基于假设排除工具**。来源：research.md § Annotation Log Round 3, Q3。

**具体改动**:

在 Evidence Standards 段落中增加：
```markdown
#### Tool Usage in Research
- When investigating external concepts or frameworks, try all available documentation
  retrieval tools before concluding information isn't available
- Do not exclude tools based on assumptions about their coverage — verify by attempting
- Record which tools were used and which returned no results, so the human can judge
  whether the search was thorough
```

**Impact**: 仅影响 workflow-full.md。

**Risk**: 低。这是一条行为指南，不改变流程结构。可能增加研究阶段的工具调用量，但工具调用比遗漏信息的代价低。

### 变更 7: Annotation Protocol 增加回写纪律

**What**: 在 workflow.md 和 workflow-full.md 的 Annotation Protocol / Annotation Cycle 部分，增加一条规则：被接受的批注必须回写到文档正文。

**Why**: 如果批注结果只记录在 Annotation Log 而不回写正文，后续生成 todolist 时 AI 会基于过时的正文内容生成，导致 todolist 与实际决策不一致。来源：本次 plan 批注 Round 3。

**具体改动**:

在 Annotation Cycle 的 "AI responds to each" 步骤后增加：
```markdown
#### Write-back Discipline
When an annotation is accepted:
1. Update the relevant section in the document body to reflect the change
2. Record the change in Annotation Log
Both steps are required — Log alone is not enough.
The document body must always reflect the current agreed state,
so that todolist generation reads the final version, not an outdated one.
```

**Impact**: workflow.md（简版增加一条规则）和 workflow-full.md（详细版增加段落）。

**Risk**: 低。这是明确化一个本应存在的纪律，不改变流程结构。

## 方案分析

### 约束条件

1. Baton 的核心价值是**透明性和人类控制**，任何改动不能削弱这两点
2. workflow.md（简版）必须保持简洁，详细指南放在 workflow-full.md
3. 改动必须向后兼容——不能让已有的 plan.md/research.md 失效

### 方案

只有一种合理方案：**增量修改现有文件**。这些变更都是在现有框架内添加规则或模板，不涉及架构变更。

不考虑"重写 workflow.md"的方案——当前结构经过验证，改动应该是外科手术式的。

## Self-Review

1. **最大风险**: 变更 4（微反射）和变更 5（动态复杂度）同时增加了流程的重量。如果实践中发现每个 todo item 都要做反射导致效率下降，可能需要回滚变更 4 或限制其适用范围。

2. **什么可能让这个计划完全错误**: 如果 Baton 的实际痛点不是"AI 分析不够深"而是"流程太重导致人类不想用"，那么增加更多步骤（检查点、模板、微反射）会恶化核心问题。这个计划隐含假设是"Baton 流程重量可以接受，需要提升的是产出质量"。

3. **被拒绝的替代方案**: 考虑过"大幅简化 workflow.md 并借鉴 Active Recall 的低认知负担"，但这会牺牲 Baton 的核心优势（严格验证、人类控制）。对于 Baton 的目标用户（工程师处理复杂代码变更），流程严谨性比简洁性更重要。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 变更 3：为什么用 grep -i？ -->
## Annotation Log

### Round 1 (2026-03-04)

**[MISSING] § 变更概览**
"当前方案没有看到之前研究阶段没有使用context7去查资料的解决方案"
→ 正确。已增加**变更 6: 研究阶段增加工具使用指南**。
  核心规则：不应基于假设排除工具，应先尝试再判断，并记录工具使用情况供人类判断。
→ Result: 已补充

**[CHANGE] § 变更 3**
"增加 'If a finding contradicts expectations, mark ❓ and investigate before moving on.'"
→ 确认：该内容已在变更 3 的具体改动中（plan.md:88）。原文：
  `If a finding contradicts expectations, mark ❓ and investigate before moving on.`
  无需额外修改。
→ Result: 已包含，无需改动

**[Q] § 批注区交互设计**
"批注区实际交互起来感觉不太顺畅，是否有更好的交互设计方案？"

这是一个好的 UX 问题。分析三种方案：

**方案 A: 单一批注区在文档末尾（当前设计）**
- 优点：简洁，一个地方写、一个地方查
- 缺点：批注与内容分离，需要 § 引用跳转；文档长时来回滚动不方便
- 实际体验：在本次交互中，人类确实在文档末尾批注，用的是描述性引用而非 § 格式

**方案 B: 每个章节末尾有小批注区**
- 优点：批注紧邻内容，无需跳转，阅读时自然看到
- 缺点：文档结构变复杂，AI 需要扫描多个位置；跨章节的批注（如"整体方向有问题"）没有归属

**方案 C: 允许行内批注 + 末尾保留汇总区（推荐）**
- workflow-full.md 其实已经支持行内批注（Annotation Format 章节示例中直接在内容下方写 `[Q] Why not...`）
- 但当前实践中人类都集中写在末尾，说明行内方式没有被充分引导
- 改进：明确鼓励行内批注，批注区降级为"参考卡 + 通用批注兜底"

具体交互流：
```
1. 人类阅读到某个章节有问题 → 直接在该位置写 [Q]/[CHANGE] 等
2. 人类有整体性反馈 → 写在末尾的批注区
3. AI 扫描全文寻找批注标记，不限于批注区
```

批注区模板可以简化为：
```markdown
## 批注区

> 可以在文档任意位置添加批注（`[Q]` `[CHANGE]` `[NOTE]` `[DEEPER]` `[MISSING]`）
> 整体性反馈写在此处。审阅完成后添加 `<!-- BATON:GO -->`
```

⚠️ **这个改动涉及 Baton 的核心交互机制**，影响范围比本次 plan 的其他变更大。建议：
1. 如果认同方案 C，可以作为**变更 7** 纳入本次 plan
2. 如果需要更多思考，可以作为独立的 research topic 推迟

→ Awaiting human decision
### Round 2 (2026-03-04)

**[NOTE] § 批注区交互设计**
"先推迟批注区交互设计改动"
→ 接受。方案 C 不纳入本次 plan，记为未来独立 research topic。
→ Result: 已确认，不纳入

**[Q] § 流程设计 — 多轮批注后是否需要重新生成 plan**
"目前的plan如果经过多轮批注修改后，有必要审阅完成后再基于原plan重新生成一个新的plan吗？还是说直接在原来的plan上修改就行了？"

→ **直接在原 plan 上修改即可，不需要重新生成。** 理由：

1. **Annotation Log 就是变更历史**。每轮批注的修改都记录在 Annotation Log 中，读者可以追溯 plan 是如何演进的。重新生成会丢失这个历史。

2. **重新生成的风险 > 收益**。如果 AI 重新生成 plan，可能会：
   - 意外丢弃已批准的决策
   - 引入新的措辞偏差（同一件事换个说法，人类需要重新审阅整份文档确认没有语义变化）
   - 浪费人类已经投入的审阅精力

3. **"脏"的 plan 比"干净"的 plan 更有价值**。带着 Annotation Log 和修改痕迹的 plan 表明它经过了人类审查，而不是 AI 一次性产出的。归档到 plans/ 时，这些历史是长期参考的一部分。

唯一需要重新生成 plan 的场景是：**批注导致方案发生根本性变化**（比如从"增量修改"变为"重写"），使原 plan 的骨架不再适用。这种情况下应该先归档旧 plan，再创建新 plan。

当前 Baton workflow 的规则已经覆盖了这一点：
- workflow.md:48 — "Before writing a new plan.md, archive the existing one"
- 这意味着只有在需要**新** plan 时才归档+重写，普通批注修改就地更新

→ Result: 直接在原 plan 上修改，无需重新生成。根本性方案变更除外。

### Round 3 (2026-03-04)

**[Q] § 流程设计 — 在原 plan 上修改对 todolist 质量的影响**
"在原plan上修改 对生成todolist的质量有影响吗?"

→ **取决于一个关键纪律：被接受的批注是否回写到了 plan 正文。**

两种情况：

**情况 A（无影响）: 批注结果已回写到正文**
```
变更 3 正文已更新 → Annotation Log 记录了变更历史
AI 生成 todolist 时读正文 → todolist 反映最终决策 ✅
```
本次 plan 就是这样操作的：变更 6 是因 [MISSING] 批注直接新增到正文的，不只是记在 Log 里。

**情况 B（有影响）: 批注结果只记在 Annotation Log 里**
```
变更 3 正文未更新 → Annotation Log 说"已接受修改"但正文是旧的
AI 生成 todolist 时读正文 → todolist 基于过时内容 ❌
```

**结论**: 在原 plan 上修改本身不影响 todolist 质量。影响质量的是**是否有"回写纪律"**——每当一个批注被接受时，必须同步更新 plan 正文对应章节，而不是只在 Annotation Log 中记一笔。

当前 Baton workflow 没有显式要求这个纪律。这本身可以作为一条规则加入 Annotation Protocol：

```
When an annotation is accepted:
1. Update the relevant section in the plan body to reflect the change
2. Record the change in Annotation Log
Both steps are required — Log alone is not enough.
```

⚠️ 这条规则是否纳入本次 plan 的变更范围？它和变更 5（动态复杂度）一样属于 Annotation Protocol 的改进。如果纳入，可以合并到变更 5 的同一区域。

→ Result: 已纳入，新增变更 7（Annotation Protocol 增加回写纪律）

<!-- BATON:GO -->

## Todo

### workflow-full.md — RESEARCH 部分

- [x] **变更 3**: Execution Strategy 增加 observe-then-decide 规则（第 2-3 条之间插入）。验证：新规则与现有 4 条策略不冲突
- [x] **变更 2**: What Research Should Cover 中 "How the code works" 替换为严格模板（加 "for code path analysis" 限定语）。验证：模板格式正确
- [x] **变更 6**: Evidence Standards 增加 Tool Usage in Research 段落。验证：与现有 Evidence Standards 内容不重复
- [x] **变更 1**: Self-Review 之后、批注区之前增加 Questions for Human Judgment 段落。验证：段落位置正确

### workflow-full.md — ANNOTATION 部分

- [x] **变更 7**: Full Flow 步骤 4 之后增加 Write-back Discipline 段落。验证：与步骤 4 的 "adopt, update document" 语义一致不矛盾
- [x] **变更 5**: Annotation Cycle 末尾（[RESEARCH-GAP] Handling 之后）增加 Dynamic Complexity Adjustment 段落。验证：阈值描述清晰

### workflow-full.md — IMPLEMENT 部分

- [x] **变更 4**: Per-Item Execution Sequence 在步骤 4 和 5 之间插入微反射步骤，原步骤 5 变为步骤 6。验证：步骤编号连续正确

### workflow.md — 简版同步

- [x] **变更 7-简版**: Annotation Protocol 段落末尾增加回写纪律的简要规则
- [x] **变更 5-简版**: Annotation Protocol 段落末尾增加动态复杂度调整的简要规则
- [x] **变更 4-简版**: Rules 部分增加微反射的简要提及（workflow.md 无 per-item sequence，添加一条规则即可）

### 验证

- [x] 通读修改后的 workflow-full.md，确认新增内容与现有内容无矛盾
- [x] 通读修改后的 workflow.md，确认简版与完整版一致且保持简洁

## Retrospective

### Plan 预测 vs 实际

1. **预测：变更 1-3, 6 只影响 workflow-full.md** → 实际一致，没有意外扩散
2. **预测：变更 4 需要修改两个文件** → 实际发现 workflow.md 没有 per-item sequence，改为在 Rules 中加一条简要规则。偏差不大但说明 plan 对简版的内容了解不够精确
3. **预测：变更 5 的 "3+" 阈值是拍脑袋的** → 实现时直接使用了该阈值，这个风险仍然存在，需要在实践中验证

### 实现中的意外

- 无重大意外。所有插入点都清晰，没有遇到冲突或需要调整的情况
- workflow.md 的简版同步比预期简单——两条规则各一行即可表达核心意思

### 下次研究要做的不同

1. **更早使用 context7** — 本次研究中因假设排除了 context7，直到人类批注指出后才补充。教训已固化为变更 6（Tool Usage in Research 规则）
2. **对 confirmation bias 更主动** — 本次是人类批注才触发自检。下次在 Self-Review 中应主动问自己："我是在独立评估还是在验证已有结论？"
3. **plan 中应更精确地描述目标文件的当前状态** — 变更 4 说"两个文件都需要更新"但 workflow.md 没有 per-item sequence，如果事先确认了就能避免 plan 与实际的偏差
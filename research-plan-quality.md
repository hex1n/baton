# Research：为什么 Plan 阶段遗漏了 72% 的实际工作量

## 参考文档

- `plan.md`：批注系统重构计划（21 个 todo，其中 15 个是 review 后新增）
- `research-baton-gaps.md`：原始缺口分析
- `.claude/skills/baton-plan/SKILL.md`：plan 阶段认知引导
- `.claude/skills/baton-research/SKILL.md`：research 阶段认知引导
- `.claude/skills/baton-implement/SKILL.md`：implement 阶段认知引导

## 工具清单

本研究使用：Read、Grep、Glob、Bash（git log）。无需外部文档。

---

## 1. 量化失败

### 原始 plan vs 实际工作

| 度量 | 值 |
|------|-----|
| 原始 todo | 6 项（变更 1-11 合并为 6 个实施项） |
| Review 后新增 todo | 15 项（#7-#21） |
| **遗漏率** | **71.4%（15/21 的工作 plan 未预见）** |
| Review 轮次 | 6 轮 |
| 每轮平均发现 | 2.5 个新问题 |

### 15 个遗漏的分类

| 类别 | Todo # | 数量 | 是否可在 plan 阶段预防 |
|------|--------|------|----------------------|
| **A. grep 可捕获的遗漏面** | #8, #9, #10, #15, #16, #18 | 6 | ✅ 一条 grep 命令即可发现 |
| **B. 实现引入的新 bug** | #7, #17, #20, #21 | 4 | ❌ plan 阶段无法预见 |
| **C. 架构方向变更** | #12, #13, #14 | 3 | ❌ 来自 review 中的用户决策 |
| **D. 一致性/测试补强** | #11, #19 | 2 | ⚠️ 部分可预见 |

**关键发现：6 个 todo（40% 的遗漏）本可通过一条 grep 在 plan 阶段发现。**

---

## 2. 失败链分析

### 2.1 Research 阶段遗漏：未做 Surface Scan

**baton-research/SKILL.md:Step 2b** 明确要求：

> "When a feature touches N parallel implementations... build a matrix before concluding research. **Every cell must have direct evidence (file:line), explicit N/A, runtime verification, or a documented ❓ unverified reason. Blank cells are not allowed.**"

批注协议是典型的 cross-cutting feature — 它出现在：

| Surface | 文件 | 原始 plan 覆盖？ |
|---------|------|-----------------|
| Skill 定义 | `.claude/skills/baton-plan/SKILL.md` | ✅ |
| Skill 定义 | `.claude/skills/baton-research/SKILL.md` | ✅ |
| 主工作流 | `.baton/workflow.md` | ✅ |
| 详细工作流 | `.baton/workflow-full.md` | ✅ |
| 运行时 hook | `.baton/hooks/phase-guide.sh` | ❌ **遗漏** |
| 测试 | `tests/test-annotation-protocol.sh` | ❌ **遗漏** |
| 测试 | `tests/test-phase-guide.sh` | ❌ **遗漏** |
| 安装器 | `setup.sh` | ❌ **遗漏** |
| 项目入口 | `README.md` | ❌ **遗漏** |
| 参考文档 | `docs/first-principles.md` | ❌ **遗漏** |
| 参考文档 | `docs/implementation-design.md` | ❌ **遗漏** |
| Skill 同步 | `.agents/skills/` | ✅ |
| 测试 | `tests/test-workflow-consistency.sh` | ✅ |

**research-baton-gaps.md 没有建 Consistency Matrix。** 它聚焦于分析失败模式（G1-G7），但没有回答"批注协议出现在哪些文件中"这个基础问题。

**反事实验证**：如果在 research 阶段执行 `rg '\[NOTE\]|\[Q\]|\[CHANGE\]|\[DEEPER\]|\[MISSING\]' --glob '!plans/**'`，会找到 10 个活跃文件。排除 research/plan 讨论文件后，`setup.sh`、`README.md`、`docs/*.md`、`phase-guide.sh`、`tests/*.sh` 会立刻浮出。

### 2.2 Plan 阶段遗漏：无 Impact Scan 步骤

**baton-plan/SKILL.md:Step 3** 对影响分析的要求是：

```
- **Impact scope**: files affected, callers impacted
```

这是一个**描述性要求**（"列出影响范围"），不是**程序性要求**（"搜索所有引用，列出影响范围"）。区别至关重要：

| 要求类型 | 示例 | AI 行为 |
|----------|------|--------|
| 描述性 | "列出影响范围" | AI 从记忆中枚举已知文件 → 遗漏不在上下文中的文件 |
| 程序性 | "grep 搜索所有引用，列出影响范围" | AI 执行搜索 → 发现所有引用 → 再从中筛选 |

**plan.md 的变更清单是通过枚举构建的**，不是通过搜索。证据：plan.md 的影响范围表只列出了 research 中已经讨论过的文件（skills, workflow.md, workflow-full.md, .agents, tests）。没有任何迹象表明执行了全仓库搜索。

### 2.3 Self-Review 缺口：检查一致性但不检查完整性

**baton-plan/SKILL.md:82-97** 的 Internal Consistency Check：

```
- Does the recommendation section point to the same approach as the change list?
- Does each change item trace back to the recommended approach?
- Does the Self-Review below reference findings consistent with the plan body?
```

这三项都是**内部一致性**检查。没有任何一项检查**外部完整性** — 即"变更清单是否覆盖了所有需要修改的文件"。

plan.md 的 Self-Review 全部 ✅ — 因为推荐、变更清单、Self-Review 确实指向同一方案（方案 C）。一致性没问题，**完整性才是问题**。

### 2.4 实现引入的级联 bug

4 个 todo（#7, #17, #20, #21）是实现其他 todo 时引入的新 bug：

| 新 bug | 来源 | 性质 |
|--------|------|------|
| #7 嵌套 HTML comment | 变更 6 批注区模板 | 模板语法错误：`<!-- ... <!-- BATON:GO --> ... -->` 导致 comment 提前闭合 |
| #17 setup.sh 入口缩窄 | #15 修改 setup.sh | 修改时遗漏了 research.md 入口，只写了 `plan.md or chat` |
| #20 setup.sh 流程描述 | #15/#17 修改 setup.sh | 修改时把 research→plan 写成固定顺序，没有反映 skip-research 路径 |
| #21 测试边界过宽 | #19 加强测试 | 测试把 comparison 文档也当成协议源检查，误判历史描述为旧协议 |

**模式**：每个修复只关注当前 bug，没有检查修复本身是否引入新问题。这不是 plan 的问题，是 implement 阶段的质量问题。

**baton-implement/SKILL.md:93-96** 其实有相关指导：

> "Grep for the old (buggy) pattern — if it exists in other files, those are the same bug"
> "Check parallel implementations: if you fixed IDE A's path, verify IDEs B-N have the same fix"

但这些 Self-Check Triggers 都是关于"同样的 bug 是否在别处重复"，不是关于"我的修复是否引入了新 bug"。缺少一个 **regression self-check**："我改的这几行，周围的上下文是否仍然正确？"

---

## 3. 根因总结

### 三层失败

```
Layer 1: Research — 未对变更对象做 Surface Scan（Consistency Matrix 缺失）
  → 导致 plan 的输入不完整

Layer 2: Plan — Impact 分析是"描述性"而非"程序性"
  → 变更清单从记忆枚举，不从搜索发现
  → Self-Review 检查一致性但不检查完整性

Layer 3: Implement — 每次修复缺少 regression self-check
  → 修 A 引入 B，修 B 引入 C
```

### 对比：baton-implement 已有的好实践

有趣的是，**baton-implement 的 Self-Check Triggers（SKILL.md:80-105）比 baton-plan 的 Self-Review 更具程序性**：

- "Re-read the modified code"（程序性：具体的行动）
- "Grep for the old (buggy) pattern"（程序性：具体的搜索）
- "Check parallel implementations"（程序性：具体的对比）

而 baton-plan 的 Self-Review 是：
- "Does recommendation point to same approach?"（判断性：需要推理，容易通过）
- "Does each change trace back?"（判断性：容易自我确认）

**Plan 阶段需要 implement 阶段同等级别的程序性自检。**

---

## 4. 改进方案

### 4.1 Plan 阶段：Surface Scan + Completeness Check（对抗 Layer 1 + Layer 2）

> **方向变更**：原方案将 Surface Scan 放在 research 层。用户决策（批注 #1）：Plan 负责 Surface Scan，因为 research 不知道具体需求，plan 是需求 + 研究的汇合点。

在 baton-plan/SKILL.md 的 **Step 3 (Approach Analysis) 和 Step 4 (Recommend) 之间**插入新步骤：

```markdown
### Step 3b: Surface Scan (required for Medium/Large changes)

Before writing the change list, perform Change Impact Analysis (see Supplement B):

**Level 1 — Direct references**: Search for exact terms being changed.
  - Text patterns → Grep/Glob
  - Code references → IDE "Find References" / AST tools
  - Convention-based → Glob patterns
  - Exclude archives (plans/, node_modules/, etc.)

**Level 2 — Dependency tracing**: From each L1 result, trace consumers.
  - Who imports/sources/references this file?
  - Who reads this file at runtime or build time?
  - Which tests validate this file's behavior?

**Level 3 — Behavioral equivalence** (human-assisted):
  - Files that implement the same concept without naming it?
  - Flag as ❓ in disposition table for human review.

Build the disposition table from ALL levels:

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Include in plan.md as `## Surface Scan`.
Default is "modify" — "skip" requires justification.
Self-check: if this "skip" file isn't updated, will users encounter old behavior?
If Level 1 finds 0 results, search terms are wrong. Try again.
For Trivial/Small changes, Level 1 alone is sufficient.
```

**反形式主义设计**（详见 Supplement A1）：

- **搜索结果成为 plan 正式段落** — 人类审阅 plan 时可直接对比 Surface Scan 表和变更清单
- **排除需要举证**（反转默认假设）— 所有搜索结果默认 "modify"，skip 必须给理由
- **Self-Review 交叉验证** — "Surface Scan 中标 'skip' 的文件，如果不更新用户会遇到旧行为吗？"

**并且**，在 Self-Review Internal Consistency Check 中新增一项：

```markdown
- **Does the change list cover ALL files in the Surface Scan disposition table?**
  Files marked "modify" must appear in change list. Files marked "skip" must have justification.
  If no Surface Scan was done → execute one now before presenting.
```

### 4.2 Implement 阶段：三层级联防御（对抗 Layer 3）

> **方向变更**：原方案只有简单的 regression self-check。用户决策（批注 #2）：需要结构化防御，不只改表面。

在 baton-implement/SKILL.md 的 **Self-Check Triggers** 中，替换简单的 regression check 为三层机制：

**层 1：Per-todo 增量测试**

```markdown
**After completing each todo**:
- Run tests directly related to the modified files
- If tests fail → fix before moving to next todo
- If no relevant tests exist → note this in the todo completion record
```

当前 SKILL.md:72 只要求"全部完成后 run full test suite"。改为每完成一个 todo 就跑相关测试。

**层 2：Same-file 级联重验**

```markdown
**When a todo modifies a file already changed by a prior todo**:
- Before implementing: re-read the file's CURRENT state (not from memory)
- After implementing: re-run ALL verification steps for ALL prior todos
  that touched this file
- Record: "File X touched by todos #A, #B, #C — re-verified #A and #B"
```

针对最常见的级联模式（3/4 的级联 bug 来自同文件重复修改）。

**层 3：变更影响向下追踪**

```markdown
**After modifying any file, ask**:
- Who consumes/imports/calls/reads this file?
- Did my change affect any of those consumers?
- For scripts/configs: who runs this? What do they expect?
- For code: grep for function/class/variable usage across repo
```

对应大型项目场景：改了一个 util 函数，需要检查所有 caller。

---

## Self-Review

### Internal Consistency Check (fix before presenting)
- ✅ 所有数据来源一致：plan.md 的 21 个 todo → 6 原始 + 15 新增 → 71.4% 遗漏率
- ✅ 分类逻辑自洽：6 个 grep 可捕获 + 4 个实现新 bug + 3 个架构变更 + 2 个一致性补强 = 15
- ✅ baton-plan Self-Review 确实只有一致性检查无完整性检查（研究了 SKILL.md:82-97 验证）
- ✅ 改进方案已更新：Surface Scan 移至 plan 层（符合用户决策），级联防御升级为三层结构（符合用户方向）
- ✅ 反形式主义方案（grep 结果可见 + 排除举证制）直接对抗"形式主义 grep"风险

### External Uncertainties (present to human)
1. **最弱结论**：声称"Consistency Matrix 本应在 research 阶段使用" — 但实际上 research-baton-gaps.md 的研究目标是"分析失败模式"，不是"列举批注协议的所有引用位置"。Surface scan 对于当时的 research 目标是否必要，取决于 research 的 scope 定义。反面论点是：research 聚焦 G1-G7 是正确的，surface scan 应该由 plan 阶段负责。
2. **改进方案的风险**：强制 surface scan 可能变成"形式主义 grep" — AI 执行了 grep，看到了结果，但仍然只把"认为重要的"放进变更清单。grep 是必要条件但不充分 — 还需要 plan 的变更清单显式标注"搜索到但判断不需改的文件"及原因。
     如果是形式主义grep 那有其他更好的方案吗
3. **级联 bug 的改进方案是否足够**："regression check: read 5 lines above and below" 是启发式的，不保证捕获所有回归。例如 #21（测试边界过宽）不是"周围上下文"的问题，而是测试逻辑设计的问题。
    
## Questions for Human Judgment

1. ~~**Research 和 Plan 谁负责 Surface Scan？**~~ → **已回答：Plan 负责。** Research 负责理解系统，不知道具体需求；Plan 是用户需求 + research 结果的汇合点，自然应由 plan 执行 surface scan。→ Section 4.1 需要更新：从 research 层移到 plan 层。
2. ~~**级联 bug 是否需要更结构化的防御？**~~ → **已回答：需要。** 大型复杂项目中，改一处影响其他地方是常态，不能只做表面回归检查。→ 详见 Supplement A。

---

## Supplement A：回应批注 — 反形式主义 + Plan Surface Scan + 级联防御

### A1：Surface Scan 如何避免形式主义

**问题的精确描述**：AI 执行搜索 → 看到 10 个文件 → 只把"觉得重要的" 5 个放进变更清单 → 搜索变成了 checked box。

**为什么会形式主义？** 因为搜索结果和变更清单之间有一个"AI 判断"的黑盒。AI 可以在这个黑盒里默默跳过文件，人类看不到。

**核心对策：让搜索结果对人类可见，让排除需要理由。**

三层防形式主义设计：

**层 1：搜索结果成为 plan 的正式段落**

```markdown
## Surface Scan

**Search terms**: `[NOTE]|[Q]|[CHANGE]|[DEEPER]|[MISSING]`
**Search scope**: entire repo, excluding plans/
**Method**: Grep (text pattern search)
**Results**:

| File | Disposition | Reason |
|------|-------------|--------|
| `.claude/skills/baton-plan/SKILL.md` | modify | Changes 1-6 |
| `setup.sh` | modify | Installer onboarding still teaches old protocol |
| `README.md` | modify | Annotation Cycle section uses old markers |
| `docs/design-comparison.md` | **skip** | Comparison/history doc — describing old protocol ≠ teaching it |
| `research-baton-gaps.md` | **skip** | Research doc — discussing old system is its analysis subject |
```

**关键**：每一行都必须有 disposition（modify/skip）和 reason。**空行 = 遗漏 = bug。** 人类审阅 plan 时，这张表是第一个检查点 — 人类可以直接发现 "setup.sh 被标记为 skip 但理由不成立"。

**层 2：默认假设是 "modify"，skip 需要举证**

当前思维：AI 搜索后决定"哪些需要改"（包含性思维 → 遗漏容易）
改后思维：所有搜索结果默认 "modify"，AI 必须论证"为什么可以 skip"（排除性思维 → skip 需要理由）

这利用了一个认知偏差：AI 更擅长"解释为什么不需要做 X"（有具体的排除理由）而不是"确认我没遗漏什么"（需要完备性证明）。

**层 3：Self-Review 交叉验证**

```
Self-Review 新增一条：
- Surface Scan 表中标记 "skip" 的文件 — 重新审视：如果这个文件没有被更新，
  用户使用时会看到旧行为吗？如果会 → 这是面向用户的 surface，不应 skip。
```

**对比形式主义 grep**：
| Aspect | Formalistic mode | Anti-formalism mode |
|--------|------------------|---------------------|
| Search results | AI sees, not shown to human | **Becomes formal plan section** |
| Disposition | AI black-box judgment | **Every file must have explicit disposition + reason** |
| Default assumption | modify = needs justification | **skip = needs justification** (reversed burden) |
| Human review | Can't see full list | **Full list + disposition table exposed to human** |

### A2：Plan 层 Surface Scan（更新 Section 4.1）

基于用户决策：Surface Scan 从 research 移到 plan。

**更新 Section 4.1 的改进方案**：

~~在 baton-research/SKILL.md 加 Surface Scan~~ → 改为在 **baton-plan/SKILL.md** 加：

在 Step 3 (Approach Analysis) 和 Step 4 (Recommend) 之间插入新步骤。
具体设计见 Section 4.1（分层 Change Impact Analysis）和 Supplement B（外部方法论参考）。

**Research 阶段的角色**：research 不做 Surface Scan，但如果 research 过程中自然发现了相关 surface（如 Consistency Matrix），plan 应引用那些发现。Research 是"发现理解"，Plan 是"决定范围"。

### A3：级联 bug 的结构化防御

**本次级联 bug 的真实模式**：

| Bug | 来源 todo | 涉及文件 | 模式 |
|-----|----------|---------|------|
| #17 | #15 | setup.sh | 同文件重复修改 |
| #20 | #15/#17 | setup.sh | 同文件重复修改 |
| #21 | #19 | test-workflow-consistency.sh | 同文件重复修改 |
| #7 | 变更 6 | baton-plan/SKILL.md | 新代码语法错误 |

**关键发现**：3/4 的级联 bug 发生在**同一个文件被多个 todo 修改**的场景（setup.sh 被 #15/#17/#20 三次修改，test 文件被 #19/#21 两次修改）。

**结构化防御方案：三层机制**

**层 1：Per-todo 增量测试（即时反馈）**

当前 baton-implement 只要求"全部完成后 run full test suite"（SKILL.md:72）。改为：

```markdown
**After each todo**:
- Run tests directly related to the modified files
- If tests fail → fix before moving to next todo
- If no relevant tests exist → note this in the todo completion record
```

这是最直接的防御：如果 #15 完成后立刻跑 `test-setup.sh`，马上就能发现 setup.sh 的入口缩窄问题，不需要等 #17。

**层 2：Same-file 级联重验（同文件守卫）**

```markdown
**When a todo modifies a file already changed by a prior todo**:
- Before implementing: re-read the file's CURRENT state (not from memory)
- After implementing: re-run ALL verification steps for ALL prior todos
  that touched this file
- Record: "File X touched by todos #A, #B, #C — re-verified #A and #B"
```

这针对的是最常见的级联模式。如果 #17 修改 setup.sh 时先重验 #15 的验证条件，能立刻发现 #15 引入的问题。

**层 3：变更影响向下追踪（在大型项目中尤其重要）**

```markdown
**After modifying any file, ask**:
- Who consumes/imports/calls/reads this file?
- Did my change affect any of those consumers?
- For scripts/configs: who runs this? What do they expect?

For code changes: grep for function/class/variable usage across repo
For config/doc changes: identify who reads this file at runtime or build time
```

这对应大型项目的场景：改了一个 util 函数，需要检查所有 caller 是否仍然兼容。

**层 3 的局限性**：对于本项目（纯 markdown + shell），影响追踪主要靠 grep。对于真正的代码项目（TypeScript/Python），还可以用 IDE 的 "Find References" 或 AST 分析。但在 baton-implement 的认知引导层面，指导是一样的："改完后追踪消费者"。

---

## Annotation Log

### Round 1

**[inferred: depth-issue] § External Uncertainties #2**
"如果是形式主义grep 那有其他更好的方案吗"
→ 核心对策：grep 结果成为 plan 正式段落 + 排除需要举证（反转默认假设）+ Self-Review 交叉验证。详见 Supplement A1。
→ Consequence: 改进方案从"要求 grep"升级为"grep 结果可见 + 排除举证制"
→ Result: accepted, 更新了 Section 4 的改进方案

**[inferred: decision] § Questions for Human Judgment #1**
"plan负责Surface Scan 因为research 只是负责研究 有可能是不知道具体需求"
→ Accepted. Research 是理解层，Plan 是决策层。Surface scan 属于"决定范围"，自然是 plan 的职责。
→ Consequence: Section 4.1 改为 plan 层而非 research 层
→ Result: accepted, Section 4.1 已更新

**[inferred: direction-confirmation + depth] § Questions for Human Judgment #2**
"需要更结构化的防御 不能只改表面的 因为在大型的复杂项目中 改完一处 是很有可能影响其他地方的"
→ 分析了级联 bug 模式，发现 3/4 源于同文件重复修改。提出三层防御：per-todo 增量测试 + same-file 级联重验 + 变更影响向下追踪。
→ Consequence: Section 4.3 从简单的 "regression check" 升级为三层结构化防御
→ Result: accepted, 详见 Supplement A3

### Round 2

**[inferred: change-request] § Surface Scan disposition labels**
"上面的 改 和跳过 最好使用英文描述 保持一致"
→ 所有 "改" → "modify"，"跳过" → "skip"。Disposition table 示例和说明文本统一为英文。
→ Consequence: no direction change
→ Result: accepted, 全文已更新

**[inferred: depth-issue] § Search method generality**
"grep 感觉不太通用"
→ 将 "Execute grep" 改为 "Search — use the most effective method"，列出多种搜索方式：text patterns (Grep/Glob), code references (IDE Find References / AST tools), convention-based (Glob patterns)。Surface Scan 的核心是"搜索所有引用"，搜索方法因项目而异。
→ Consequence: Surface Scan 步骤从 grep-specific 升级为 method-agnostic
→ Result: accepted, Section 4.1 和 Supplement A2 已更新

### Round 3

**[inferred: depth-issue + gap] § Search methodology + Tool Inventory**
"有更好的吗 如果没有其他好的方案 可以检索官方或者社区相同种类的 相关的最佳的设计作为参考"
"你这次检索没有使用context7"
→ 使用 WebSearch + Context7 搜索了外部最佳实践。发现：
  1. Change Impact Analysis 是成熟的 SE 领域（Wikipedia: traceability IA + dependency IA）
  2. 业界标准是分层搜索（L1 direct → L2 dependency → L3 behavioral equivalence）
  3. Cline 验证：filesystem traversal + AST > keyword search alone
  4. Claude Code Handbook 已有 impact section 模板（affected components / required updates / migration），但仅在 code review 阶段
  5. Baton 的创新：将 impact analysis 前移到 plan 阶段
→ Consequence: Surface Scan 设计从"搜索方法列表"升级为"分层 Change Impact Analysis 框架"
→ Tool gap: 本轮研究初始未使用 Context7，被用户指出后补上。违反了 Step 0 Tool Inventory 要求。
→ Result: accepted, Supplement B 已添加

---

## Supplement B：外部最佳实践 — Change Impact Analysis 方法论

### 检索来源

**WebSearch**:
- [Change Impact Analysis - Wikipedia](https://en.wikipedia.org/wiki/Change_impact_analysis)
- [Blast Radius in Software Development](https://devcookies.medium.com/understanding-blast-radius-in-software-development-system-design-0d994aff5060)
- [Graph AI: Blast Radius Definition & Applications](https://www.graphapp.ai/engineering-glossary/devops/blast-radius)
- [Cline AI codebase awareness approach](https://github.com/cline/cline)
- [Why Cline doesn't index your codebase (HN discussion)](https://news.ycombinator.com/item?id=44106944)
- [Software Dependency Graphs](https://www.puppygraph.com/blog/software-dependency-graph)
- [Finding affected declarations via AST in JavaScript](https://dev.to/jennieji/find-what-is-affected-by-a-declaration-in-javascript-2d5c)

**Context7** (library docs):
- Claude Code Handbook (`/nikiforovall/claude-code-rules`): git-diff-analyzer agent + code review agent patterns
- Claude Code official (`/anthropics/claude-code`): compare-files skill with Impact section, Code Review Agent with context evaluation
- Cline (`/cline/cline`): search_files + list_code_definition_names + AST approach confirmed

### 核心发现

**1. Change Impact Analysis 是成熟的 SE 学科**

Wikipedia 定义：*"identifying the potential consequences of a change, or estimating what needs to be modified to accomplish a change."*

Bohner & Arnold 将 Impact Analysis 分为两类：

| Type | What it traces | Baton equivalent |
|------|---------------|------------------|
| **Traceability IA** | Requirements → design → code | Research → Plan traceability (already exists in baton-plan Step 1) |
| **Dependency IA** | Code → code, module → module | **Surface Scan (this is what we're designing)** |

Baton 的 Surface Scan 本质上是 Dependency Impact Analysis 在 plan 阶段的应用。

**2. Blast Radius 分层模型**

业界标准将变更影响分为两层：

- **Direct impact**: 直接引用/使用被修改实体的文件
- **Indirect impact**: 通过中间依赖受影响的文件（cascade）

本次 plan 的失败案例完美映射：
- Direct: skills, workflow.md（直接定义批注协议）→ 原始 plan 覆盖了 ✅
- Indirect: setup.sh, README.md, phase-guide.sh（引用/教授批注协议但不定义它）→ 原始 plan 遗漏了 ❌

**3. Cline 的方法：Filesystem Traversal + AST > Keyword Search**

Cline (主流 AI coding agent) 的关键设计决策：

> 团队最初尝试 RAG + embeddings，但发现 **给 agent 文件系统工具让它自然地跟踪依赖** 效果显著更好。

Cline 使用 tree-sitter 做 AST parsing，但核心思路不是"先建索引再搜索"，而是"从变更点出发，沿依赖链向外追踪"。这与 keyword search 的区别：

| Approach | How it works | Catches | Misses |
|----------|-------------|---------|--------|
| Keyword search | 搜索字符串匹配 | 直接文本引用 | 不使用关键字但实现同一概念的文件 |
| Dependency tracing | 从变更点沿 import/call/reference 链追踪 | 代码级依赖 | 非代码引用（docs, configs） |
| Combined | 两者结合 | 最全面 | 仅运行时动态依赖 |

**4. Claude Code 生态中的 Impact Analysis 实践** (via Context7)

Claude Code Handbook 的 `compare-files` skill 定义了结构化的 Impact 分析模板：

```
3. Impact:
   - Affected components
   - Required updates elsewhere
   - Migration requirements
```

Code Review Agent 的 review 流程包含 "Context evaluation: Check impact on related code" 作为第三步。这证实了 **impact analysis 在 Claude Code 生态中已是 code review 阶段的标准实践** — 但目前只在 review 阶段，不在 planning 阶段。

Baton 的创新是把这个实践 **前移到 plan 阶段**：在写变更清单之前做 impact analysis，而不是在 review 时才发现遗漏。

**5. Dependency Graph 作为分析工具**

学术界和工业界的标准工具：
- **Call Graph**: 函数 A 调用函数 B → 改 B 需要检查 A
- **Import Graph**: 模块 A 导入模块 B → 改 B 的导出需要检查 A
- **Control Flow Graph**: 分支/循环中的依赖关系

对于非代码项目（baton 的 markdown + shell），依赖关系主要是：
- `source`/`.` 命令（shell 脚本间的依赖）
- `@` / `Contents of` 引用（CLAUDE.md 引用其他文件）
- Template include（批注区模板被多个文件使用）
- Grep-based 关键字引用（协议名称、标记名称）

### 对 Surface Scan 设计的影响

基于外部研究，Surface Scan 应该采用 **分层搜索** 而非单一方法：

```
Level 1: Direct references (keyword/text search)
  → Search for the exact strings being changed
  → Catches: all files that literally mention the concept

Level 2: Dependency tracing (follow imports/sources/references)
  → From each Level 1 result, trace who depends on this file
  → Catches: indirect consumers not found by keyword search

Level 3: Behavioral equivalence (manual review)
  → Files that implement the same concept without using the keyword
  → Example: a function that validates annotation types without naming them
  → This level requires human judgment — flag as ❓ in the disposition table
```

**对 baton 的具体建议**：

当前 Surface Scan 步骤（Section 4.1）应改为：

```markdown
### Step 3b: Surface Scan (required for Medium/Large changes)

Before writing the change list, perform Change Impact Analysis on the concept being modified:

**Level 1 — Direct references**: Search for the exact terms being changed.
  - Text patterns → Grep/Glob
  - Code references → IDE "Find References" / AST tools
  - Config/markup → Glob for file patterns

**Level 2 — Dependency tracing**: From each L1 result, trace consumers.
  - Who imports/sources/references this file?
  - Who reads this file at runtime or build time?
  - Which tests validate this file's behavior?

**Level 3 — Behavioral equivalence** (human-assisted):
  - Are there files that implement the same concept without naming it?
  - Flag as ❓ in the disposition table — human reviews these.

Build the disposition table from ALL three levels:

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `skill.md` | L1 | modify | Defines the protocol |
| `setup.sh` | L1 | modify | Teaches the protocol in onboarding |
| `phase-guide.sh` | L2 | modify | Runtime consumer of workflow.md protocol |
| `test-*.sh` | L2 | modify | Validates protocol behavior |
| `docs/comparison.md` | L1 | skip | Describes history, doesn't teach current protocol |

Default disposition is "modify". "skip" requires justification.
For Trivial/Small changes, Level 1 is sufficient.
```

### 为什么这比纯 keyword search 更好

回到本次失败案例：

| 遗漏的文件 | L1 (keyword) 能发现？ | L2 (dependency) 能发现？ |
|-----------|---------------------|------------------------|
| setup.sh | ✅ 包含旧 marker 文本 | ✅ |
| README.md | ✅ 包含旧 marker 文本 | ✅ |
| phase-guide.sh | ⚠️ 可能（如果搜索 annotation 相关词） | ✅ workflow.md 的运行时消费者 |
| tests/*.sh | ⚠️ 可能 | ✅ 验证协议行为的测试 |
| docs/*.md | ✅ 包含旧 marker 文本 | ✅ |

L1 alone 能抓到大部分（如果搜索词选得好）。L2 额外抓到 L1 可能遗漏的间接依赖（如 phase-guide.sh 不一定包含旧 marker 字符串，但它是 workflow 协议的运行时入口）。

**组合 L1+L2 的覆盖率 > 任一单独方法。** L3 作为人类辅助层处理"无法自动发现"的等价实现。

---

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->
 1. 你这次检索没有使用context7
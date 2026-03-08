# Plan：Baton 批注系统重构与认知引导强化

## 参考文档

- `research-baton-gaps.md`：缺口分析（G1-G7 + Supplements A-F）
- `retrospective-2026-03-08.md`：复盘记录

## 约束条件

从研究中提取的基本约束：

1. **AI 指令遵守率有上限**（research-baton-gaps.md Supplement A）— Claude Code 能可靠遵循约 150-200 条指令，超过后遵守率下降。baton skills 已经较长（baton-plan: 206 行, baton-research: 227 行），新增规则必须精炼
2. **位置偏差**（Supplement A）— Iron Law（开头）和 Red Flags（中间）是遵守率最高的位置。新增关键规则应利用这些位置
3. **语义检查不可自动化**（G1 分析）— Shell 脚本只能检查结构缺失，不能检测语义矛盾。核心防御必须是认知引导
4. **人类不应承担 AI 更擅长的分类任务**（Supplement F）— 批注类型的选择成本不应由人类承担
5. **方向 γ 已确认**（用户决策）— 只保留 `[PAUSE]` 作为流程控制类型，其余自然语言由 AI 推断
6. **`.agents/skills/` 必须与 `.claude/skills/` 保持同步**

## 方案分析

### 方案 A：最小改动 — 只改 skills，不改批注系统

- ✅ 改动最小，风险最低
- ❌ 不解决 G7（批注类型 4 源不一致 + 人类分类负担）
- ❌ 用户已确认方向 γ，不改批注系统违背用户决策

**排除理由**：G7 是用户在批注循环中明确选择的方向，跳过它等于忽略用户决策。

### 方案 B：全面改动 — skills + 批注系统 + doc-quality.sh hook

- ✅ 覆盖所有 9 个缺口
- ⚠️ 范围较大，doc-quality.sh 需要新增 shell 脚本 + 测试
- ⚠️ 与 skills 认知引导改进混在同一次实施中，增加验证复杂度

**排除理由**：doc-quality.sh（G1 结构兜底层）是独立的结构检查，与认知引导改进没有依赖关系。应单独实施以降低风险。

### 方案 C：认知引导重构 — skills + 批注系统（推荐）

覆盖 G1（认知引导部分）+ G2-G9。不包含 doc-quality.sh（留给后续独立任务）。

- ✅ 覆盖所有认知引导改进（G1-G7 + 批注循环中发现的 G8/G9）
- ✅ 方向 γ 的批注系统简化
- ✅ Research 收敛机制 + chat 需求持久化
- ✅ 纯 markdown 改动，零代码风险
- ✅ doc-quality.sh 可独立后续实施
- ⚠️ G1 的结构兜底层暂缺（但认知引导已覆盖核心防御）

## 推荐：方案 C

理由追溯：
- research-baton-gaps.md § 4（防御模型）："真正能防御语义矛盾的是认知引导"
- research-baton-gaps.md Supplement B："推荐比例：认知引导 80% + 结构兜底 20%"
- 方案 C 覆盖了 80% 的核心防御，20% 的结构兜底（doc-quality.sh）可独立后续实施

---

## 新增缺口（批注循环中发现）

| # | 缺口 | 来源 |
|---|------|------|
| G8 | Research 多轮演进后结论矛盾未标记 | 人类批注：research 中不同 Supplement 的推荐互相替代但没有标记，影响 plan 质量 |
| G9 | 人类 chat 需求无持久化 | 人类批注：research 无批注时人类在 chat 中提出需求，只存在于 chat 上下文中，context compact 或换会话后丢失 |

G8 示例：research-baton-gaps.md Supplement E 推荐方向 X，Supplement F 推荐方向 γ，但 E 的推荐未被标记为"已替代"。AI 出 plan 时可能错误引用 E 的结论。

G9 示例：人类审阅完 research，在 chat 中说"基于这个研究，我要新增一个 XX 功能"。这个需求是 plan 的输入源，但不在任何持久化文档中。

---

## 变更清单

### 变更 1：baton-plan/SKILL.md — Iron Law 新增第四条（G3）

**What**：在 Iron Law code block 中新增第四条规则

**当前**（SKILL.md:14-17）：
```
NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
NO BATON:GO PLACED BY AI — ONLY THE HUMAN PLACES IT
NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
```

**改为**：
```
NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
NO BATON:GO PLACED BY AI — ONLY THE HUMAN PLACES IT
NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
NO INTERNAL CONTRADICTIONS LEFT UNRESOLVED — FIX BEFORE PRESENTING
```

**Why**：G3 — Self-Review 发现矛盾时把它当"风险"记录而不修复。Iron Law 位置利用开头位置偏差获得最高遵守率（Supplement A）。

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 2：baton-plan/SKILL.md — Self-Review 模板区分矛盾与风险（G3）

**当前**（SKILL.md:73-78）：
```markdown
## Self-Review
- The biggest risk in this plan that you're least confident about
- What could make this plan completely wrong
- One alternative approach you considered but rejected, and why
```

**改为**：
```markdown
## Self-Review

### Internal Consistency Check (fix before presenting)
- Does the recommendation section point to the same approach as the change list?
- Does each change item trace back to the recommended approach?
- Does the Self-Review below reference findings consistent with the plan body?
- If ANY contradiction found → this is a bug, not a risk. Fix it now.

### External Risks (present to human)
- The biggest risk in this plan that you're least confident about
- What could make this plan completely wrong
- One alternative approach you considered but rejected, and why
```

**Why**：G3 — 区分"内部矛盾（必须修复）"和"外部风险（呈现给人类）"。显式清单比"检查一致性"的抽象指令更难跳过。

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 3：baton-plan/SKILL.md — 批注协议重构（G4 + G6 + G7）

**What**：用方向 γ 的自然语言批注 + 后果检测替换当前的 6 类型表格式批注协议。

**当前**（SKILL.md:141-168）：Annotation Protocol 包含 5 类型表格 + 接受/拒绝规则

**改为**：

```markdown
## Annotation Protocol (Plan Phase)

The human reviews plan.md and provides feedback — either as free-text annotations
in the document, or as conversation in chat. AI infers intent from content.

The only explicit annotation type is `[PAUSE]` — a flow control signal meaning
"stop current work, go investigate something else first" (equivalent to the old
[RESEARCH-GAP]). All other feedback is free-text; AI determines the appropriate
response from content.

### Processing Each Annotation

For each piece of feedback:
1. **Read code first** — don't answer from memory. Cite file:line.
2. **Infer intent** — is this a question, change request, context addition,
   depth complaint, or gap signal? Record your inference in the Annotation Log.
3. **Respond with evidence** — if the human is right, adopt and update. If
   problematic, explain with evidence + offer alternatives. Don't comply blindly.
4. **Consequence detection** — after responding, ask yourself:
   - Did my answer change the recommended approach? → Direction change. See below.
   - Did my answer contradict a research.md conclusion? → Must add counter-evidence
     to research.md before updating plan.
   - Did my answer reveal an internal contradiction in this document? → Fix immediately
     (Iron Law #4).

### Direction Change Rule

When any annotation response changes the recommended approach:
1. **Declare** — "Responding to this feedback changes my recommendation from X to Y."
2. **Full-document alignment** — re-read every section (recommendation, change list,
   Self-Review, scope) and update ALL references to the old approach.
3. **Research check** — if the new direction contradicts research.md conclusions,
   pause and add counter-evidence to research.md first.
4. **Inform human** — "If you believe this needs deeper investigation before
   changing direction, say [PAUSE]."

When an annotation is accepted: (1) update the document body, (2) record in
Annotation Log. Both steps required — the document body is the source of truth.

If 3+ annotations in one round signal depth issues → suggest upgrading complexity.

### Annotation Log Format

Record each annotation with AI-inferred classification:

    ## Annotation Log

    ### Round 1

    **[inferred: direction-question] § Section Name**
    "Human's original feedback text"
    → AI response with file:line evidence
    → Consequence: direction changed / no direction change
    → Result: accepted / awaiting decision / alternative proposed

Inference categories: question, change-request, context, depth-issue, gap, pause.
The category is AI's best judgment — human can correct if wrong.
```

**Why**：
- G7 — 消除 4 源不一致，消除人类分类负担。方向 γ 已被用户确认。
- G4 — 方向变更后的收敛步骤（"Full-document alignment"显式枚举每个需要检查的段落）
- G6 — 后果检测（"Consequence detection"在每次回答后自检方向是否改变）
- G2 — 合并到 G4 的 "Research check"（方向变更通读时显式对比 research）

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 4：baton-plan/SKILL.md — Red Flags 新增行（G4 + G6）

**当前**（SKILL.md:124-131）：5 行 Red Flags 表格

**新增两行**：

```
| "Let me just update the recommendation section" | Direction changes affect the ENTIRE document. Re-read every section. |
| "I'll note this direction change in the Annotation Log" | Annotation Log is not enough. Update the document body — it's the source of truth. |
```

**Why**：G4/G6 — 双重放置（Annotation Protocol + Red Flags）利用不同位置提高遵守率（Supplement A）。

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 5：baton-plan/SKILL.md — Pre-todo 一致性检查（G5）

**What**：在 Todolist Format 段之前插入一致性检查步骤。

**当前**（SKILL.md:99-101）：
```
After the human says "generate todolist" and BATON:GO is present:
```

**改为**：
```markdown
### Pre-Todo Consistency Check

Before generating the todolist, verify internal consistency:
1. Re-read the recommendation section — which approach is recommended?
2. Re-read the change list — do ALL changes belong to the recommended approach?
3. Re-read the Self-Review — are there unresolved internal contradictions?
4. All three aligned → proceed to generate todolist.
5. Any mismatch → fix the document first, then generate.

### Todolist Format

After the human says "generate todolist" and BATON:GO is present:
```

**Why**：G5 — 在 BATON:GO 检查之后、todo 生成之前的自然位置。纯认知引导，零代码成本。

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 6：baton-plan/SKILL.md — 批注区模板更新（G7）

**当前**（SKILL.md:192-198）：
```markdown
## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注 -->
```

**改为**：
```markdown
## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 <!-- BATON:GO -->，然后告诉 AI "generate todolist" -->
```

**Why**：G7 方向 γ — 人类不再需要选类型，直接写反馈。`[PAUSE]` 是唯一的显式流程控制信号。

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

### 变更 7：baton-research/SKILL.md — Self-Review + 批注协议 + 批注区（G3 + G7）

**7a. Self-Review 模板更新**（SKILL.md:107-112）

**改为**：
```markdown
## Self-Review

### Internal Consistency Check (fix before presenting)
- Do all call chain conclusions align with the evidence cited?
- Are there sections that contradict each other?
- If ANY contradiction found → fix it now. This is a bug, not a finding.

### External Uncertainties (present to human)
- 3 questions a critical reviewer would ask about this research
- The weakest conclusion in this document and why
- What would change your analysis if investigated further
```

**7b. Annotation Protocol 更新**（SKILL.md:157-168）

**改为**：
```markdown
## Annotation Protocol (Research Phase)

The human reviews research.md and provides feedback — free-text annotations or
conversation. AI infers intent from content.

The only explicit type is `[PAUSE]` — "stop current research direction, investigate
something else first." All other feedback is free-text.

### Processing Each Annotation

1. **Read code first** — don't answer from memory. Cite file:line.
2. **Infer intent** — question, context, depth complaint, gap?
   Record inference in Annotation Log.
3. **Respond with evidence** — adopt if right, explain with evidence if problematic.
4. **Consequence detection** — did my answer invalidate a prior conclusion?
   If yes, update the affected sections immediately.

When an annotation is accepted: (1) update the document body, (2) record in
Annotation Log.

If 3+ annotations signal depth issues → suggest upgrading complexity.
```

**7c. 批注区模板更新**（SKILL.md:203-209）

**改为**：
```markdown
## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->
```

**Why**：G3（Self-Review 一致性）+ G7（方向 γ 批注系统简化）。与 baton-plan 保持对称。

**Impact**：`.claude/skills/baton-research/SKILL.md`，`.agents/skills/baton-research/SKILL.md`

---

### 变更 8：workflow.md — 批注协议简化（G7）

**当前**（workflow.md:48-51）：
```
### Annotation Protocol
Human adds annotations in research.md or plan.md. AI responds to each and records in `## Annotation Log`.
Types: `[NOTE]` · `[Q]` · `[CHANGE]` · `[DEEPER]` · `[MISSING]` · `[RESEARCH-GAP]`
Every claim requires file:line. Blind compliance is a failure mode — disagree with evidence when needed.
```

**改为**：
```
### Annotation Protocol
Human adds feedback in research.md, plan.md, or chat. AI infers intent from content,
responds with file:line evidence, and records in `## Annotation Log`.
Only explicit type: `[PAUSE]` — stop current work, investigate something else first.
After responding to any feedback, AI must self-check: did my answer change direction,
contradict research, or reveal internal contradictions? If yes, handle immediately.
Blind compliance is a failure mode — disagree with evidence when needed.
```

**Why**：G7 — workflow.md 是始终加载的主入口（via CLAUDE.md），必须与 skills 的方向 γ 对齐。

**Impact**：`.baton/workflow.md`

---

### 变更 9：workflow-full.md — 批注区模板统一 + 协议更新（G4 + G7）

**9a. Research 批注区模板**（workflow-full.md:174-180）：改为方向 γ 模板（同变更 7c）

**9b. Plan 批注区模板**（workflow-full.md:240-246）：改为方向 γ 模板（同变更 6）

**9c. Annotation Protocol 段**（workflow-full.md:59-84）：更新为方向 γ 协议，保留核心规则（证据标准、不盲从、Annotation Log 双步骤）但删除 6 类型表格，改为自然语言推断 + 后果检测 + [PAUSE]

**9d. Annotation Cycle 段**（workflow-full.md:248-329）：
- 删除 6 类型的单独处理指令（workflow-full.md:282-286）
- 保留 Full Flow 和 Annotation Log Format（更新为方向 γ 的推断格式）
- 将 `[RESEARCH-GAP] Handling`（workflow-full.md:319-324）改为 `[PAUSE] Handling`
- 更新 Thinking Posture 段：删除按类型的指令，改为"推断意图 + 后果检测"

**9e. Self-Review 模板**（workflow-full.md:~156-161 research 版、~229-235 plan 版）：
- 两处 Self-Review 模板都更新为"Internal Consistency Check / External Risks (或 Uncertainties)"格式
- 与 baton-plan/SKILL.md 变更 2 和 baton-research/SKILL.md 变更 7a 对齐

**Why**：G7 — workflow-full.md 包含 2 个不同的 5 类型子集批注区模板，是 4 源不一致的根源。统一为方向 γ 从根本上消除不一致。G3 — Self-Review 模板必须在所有来源一致，否则重演 4 源不一致问题。

**Impact**：`.baton/workflow-full.md`

---

### 变更 10：.agents/skills/ 同步

将变更 1-7, 12, 13 的结果同步到 `.agents/skills/baton-plan/SKILL.md` 和 `.agents/skills/baton-research/SKILL.md`。

**方法**：实施完 `.claude/skills/` 后，直接 `cp` 到 `.agents/skills/`。

**Impact**：`.agents/skills/baton-plan/SKILL.md`，`.agents/skills/baton-research/SKILL.md`

---

### 变更 11：tests/test-workflow-consistency.sh 更新

更新一致性测试以验证新结构：
- 检查 `[PAUSE]` 在所有批注区模板中出现
- 检查旧的 6 类型标签不再出现在批注区模板中
- 验证 Iron Law 第四条存在
- 验证 `.claude/skills/` 与 `.agents/skills/` 内容一致

**Impact**：`tests/test-workflow-consistency.sh`

---

### 变更 12：baton-research/SKILL.md — Research 收敛步骤（G8）

**What**：在 Exit Criteria 之前新增 "Convergence Check" 步骤。

**当前**（SKILL.md:213-218）：Exit Criteria 只检查三个条件（Main path verified, Key unknowns surfaced, Human judgment questions extracted）。

**新增段落**（插入在 Exit Criteria 之前）：

```markdown
### Step 7: Convergence Check

Before transitioning to plan phase, consolidate the research conclusions:

1. **Scan for superseded conclusions** — if any section's recommendation or
   conclusion was revised by a later section (Supplement or otherwise), mark
   the original with a note: "→ Revised in § [later section]".
2. **Write `## Final Conclusions`** — a short section at the end listing ONLY
   the currently-valid conclusions. Each must reference its evidence location
   in the document body.
3. **Chat requirements capture** — if the human stated requirements or
   direction in chat (not in the document), record them in Final Conclusions
   with attribution: "Human requirement (chat): ..."

This step ensures plan derivation works from a single coherent source, even
across session boundaries.
```

**Why**：
- G8 — research 多轮演进后结论矛盾影响 plan 质量。收敛步骤在出口处创建"单一真相源"，而不是让 plan 作者在多个互相矛盾的 Supplement 中自行判断。不限于有多个 Supplement 的情况 — 即使主体内前后段落结论演进，也需要标记。
- G9 — 人类 chat 需求的捕获点。在 research 收敛时把 chat 需求记录到 Final Conclusions 中，确保跨会话持久化。

**Impact**：`.claude/skills/baton-research/SKILL.md`，`.agents/skills/baton-research/SKILL.md`

---

### 变更 13：baton-plan/SKILL.md — Step 1 增加需求来源验证（G8 + G9）

**What**：在 Step 1（Derive from Research）中增加对 research 收敛状态和 chat 需求的检查。

**当前**（SKILL.md:36-40）：
```
Plans MUST derive approaches from research findings — don't jump to "how" without
tracing back to "why". If research.md exists, reference it. If not, do the research
first (invoke baton-research).
```

**改为**：
```markdown
### Step 1: Derive from Research

Plans MUST derive approaches from research findings — don't jump to "how" without
tracing back to "why". If research.md exists, reference it. If not, do the research
first (invoke baton-research).

**Before deriving approaches, verify the research source:**
1. If research.md contains a `## Final Conclusions` section, derive from there
   (it's the converged single source of truth).
2. If no Final Conclusions exists and research has multiple sections with
   evolving recommendations, identify which conclusions are current vs superseded.
   Only derive from current conclusions.
3. If the human stated requirements in chat, record them in plan.md under
   `## Requirements` before proceeding. The plan must trace back to BOTH
   research findings AND human-stated requirements.
```

**Why**：
- G8 — 第二道防线：即使 research 忘了做收敛步骤，plan 在入口处仍能识别被替代的结论
- G9 — chat 需求如果未被 research 的 Step 7 捕获，在 plan 入口再捕获一次，确保不丢失

**Impact**：`.claude/skills/baton-plan/SKILL.md`，`.agents/skills/baton-plan/SKILL.md`

---

## 影响范围

| 文件 | 变更项 | 变更性质 |
|------|--------|---------|
| `.claude/skills/baton-plan/SKILL.md` | 1,2,3,4,5,6,13 | 认知引导重构 + 需求来源验证 |
| `.claude/skills/baton-research/SKILL.md` | 7,12 | 认知引导 + 模板对齐 + 收敛步骤 |
| `.baton/workflow.md` | 8 | 批注协议简化 |
| `.baton/workflow-full.md` | 9 | 模板统一 + 协议更新 |
| `.agents/skills/baton-plan/SKILL.md` | 10 | 同步镜像 |
| `.agents/skills/baton-research/SKILL.md` | 10 | 同步镜像 |
| `tests/test-workflow-consistency.sh` | 11 | 测试更新 |

所有变更为纯 markdown 修改（除测试为 shell 脚本）。不涉及源代码，不需要 BATON:GO 生效即可编辑。

## 风险与缓解

| 风险 | 可能性 | 缓解 |
|------|--------|------|
| AI 推断批注意图不如显式类型准确 | 中 | 后果检测作为安全网；Annotation Log 记录推断结果，人类可纠正 |
| 新增规则增加 skill 长度超过遵守率阈值 | 低 | 方向 γ 同时删除了大量类型表格，净行数变化预计为负（删多增少） |
| 历史文档中的旧类型标签在新协议下无法解析 | 低 | 旧文档已归档在 plans/ 中，不影响新流程。AI 仍能理解旧类型标签的含义 |
| workflow-full.md 修改范围较大 | 中 | 核心逻辑（Full Flow、Annotation Log Format）保留不变，只修改类型相关段落 |

---

## Self-Review

### Internal Consistency Check (fix before presenting)
- ✅ 推荐方案 C = 认知引导重构（G1-G9）。变更清单 1-13 全部是认知引导 + 批注系统改动，无 doc-quality.sh。一致。
- ✅ 方案分析已更新：方案 C 描述为"G1-G9"，方案 B 描述为"9 个缺口"。与变更清单对齐。
- ✅ 每个变更项都追溯到至少一个 G 缺口（G1-G9）。无游离变更。
- ✅ 所有变更项的目标文件一致：变更 1-6,13 → baton-plan/SKILL.md，变更 7,12 → baton-research/SKILL.md，变更 8-9 → workflow*.md，变更 10 → agents 同步，变更 11 → 测试。
- ✅ 变更 10 范围 = "变更 1-7, 12, 13"，覆盖所有 skill 修改。
- ✅ G8 和 G9 的防御是双层的：research 出口（变更 12）+ plan 入口（变更 13），任一层遗漏另一层兜底。
- ✅ Annotation Log 格式在变更 3 中定义（方向 γ 推断格式）。
- ✅ workflow-full.md Self-Review 模板在变更 9e 中覆盖。

**Meta-observation**: 本 plan 在批注循环中经历了 G8 问题（方案分析写在 G8/G9 发现之前，前面没有同步更新）。经人类指出后修复。这验证了 G8 的存在和变更 12/13 的必要性。

### External Risks (present to human)
- **最大风险**：方向 γ 的"AI 推断替代显式类型"是否在实际批注循环中表现良好，目前无法验证 — 只能在后续使用中观察。
- **什么会让这个计划完全错误**：如果 AI 的后果检测（"我的回答是否改变了方向"）本身不可靠 — 即 AI 在回答时无法意识到自己正在改变方向 — 那么 G4/G6 的改进将失效。但研究证据表明，上次失败中 AI 在 Self-Review 里确实"发现"了矛盾但没有"行动"，说明检测能力存在，问题在于缺少"发现 → 行动"的显式规则。
- **被拒绝的替代方案**：方案 B（包含 doc-quality.sh）被拒绝因为它与认知引导改进是独立的，混合实施增加复杂度。doc-quality.sh 应在本计划完成并验证后单独实施。

---

## Todo

- [x] ✅ 1. Change: baton-plan/SKILL.md — Iron Law #4 + Self-Review 模板 + 批注协议重构 + Red Flags + Pre-todo check + 批注区模板 + Step 1 需求来源验证（变更 1,2,3,4,5,6,13） | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: diff 确认所有 7 项变更到位；skill 行数不增反减 | Deps: none | Artifacts: none
- [x] ✅ 2. Change: baton-research/SKILL.md — Self-Review 模板 + 批注协议重构 + 批注区模板 + Convergence Check 步骤（变更 7a,7b,7c,12） | Files: `.claude/skills/baton-research/SKILL.md` | Verify: diff 确认 4 项变更到位 | Deps: none | Artifacts: none
- [x] ✅ 3. Change: workflow.md — 批注协议简化为方向 γ（变更 8） | Files: `.baton/workflow.md` | Verify: grep 确认 [PAUSE] 存在、旧 6 类型标签不在 Annotation Protocol 段 | Deps: none | Artifacts: none
- [x] ✅ 4. Change: workflow-full.md — 批注区模板统一 + 协议更新 + Self-Review 模板 + Annotation Cycle 更新（变更 9a-9e） | Files: `.baton/workflow-full.md` | Verify: grep 确认所有批注区模板使用 [PAUSE]；旧类型子集不再出现 | Deps: none | Artifacts: none
- [x] ✅ 5. Change: .agents/skills/ 同步（变更 10） | Files: `.agents/skills/baton-plan/SKILL.md`, `.agents/skills/baton-research/SKILL.md` | Verify: diff 确认与 .claude/skills/ 内容一致 | Deps: #1, #2 | Artifacts: none
- [x] ✅ 6. Change: tests/test-workflow-consistency.sh 更新（变更 11） | Files: `tests/test-workflow-consistency.sh` | Verify: 运行测试通过 | Deps: #1, #2, #3, #4, #5 | Artifacts: none
- [x] ✅ 7. Change: 修复 plan/批注模板中的无效嵌套 HTML comment，避免 `<!-- BATON:GO -->` 提示提前闭合注释并污染输出 | Files: `.claude/skills/baton-plan/SKILL.md`, `.agents/skills/baton-plan/SKILL.md`, `.baton/workflow-full.md` | Verify: diff 确认批注区模板不再包含嵌套 comment，文本仍保留 BATON:GO 指引 | Deps: #1, #4, #5 | Artifacts: none
- [x] ✅ 8. Change: 迁移 ANNOTATION 运行时入口到方向 γ，删除 `phase-guide.sh` fallback 中旧的 6 类型标签提示 | Files: `.baton/hooks/phase-guide.sh` | Verify: phase-guide 输出只描述 free-text + `[PAUSE]`，不再提 `[NOTE]/[Q]/[CHANGE]/[DEEPER]/[MISSING]/[RESEARCH-GAP]` | Deps: #3, #4 | Artifacts: none
- [x] ✅ 9. Change: 更新遗留测试以匹配方向 γ，覆盖 annotation protocol 与 phase guide 的新提示文案 | Files: `tests/test-annotation-protocol.sh`, `tests/test-phase-guide.sh` | Verify: `bash tests/test-annotation-protocol.sh` 和 `bash tests/test-phase-guide.sh` 通过 | Deps: #7, #8 | Artifacts: none
- [x] ✅ 10. Change: 清理 skills 中残留的旧术语 `[RESEARCH-GAP]`，统一为 Direction γ 的 `[PAUSE]` / free-text 表述 | Files: `.claude/skills/baton-plan/SKILL.md`, `.claude/skills/baton-research/SKILL.md`, `.agents/skills/baton-plan/SKILL.md`, `.agents/skills/baton-research/SKILL.md` | Verify: grep 确认 active skills 中不再出现 `[RESEARCH-GAP]` | Deps: #1, #2, #5 | Artifacts: none
- [x] ✅ 11. Change: 统一 todo 完成格式文案，避免 baton-plan 与 workflow/implement skill 对 `- [x]` vs `- [x] ✅` 的描述漂移 | Files: `.claude/skills/baton-plan/SKILL.md`, `.agents/skills/baton-plan/SKILL.md`, `tests/test-workflow-consistency.sh` | Verify: grep 确认 baton-plan 与 workflow/implement 对 completed todo 的描述一致；一致性测试通过 | Deps: #1, #5, #6 | Artifacts: none
- [x] ✅ 12. Change: 将 Codex 入口文件加入版本控制，避免 `.agents/skills` 一致性检查在 clean checkout 中因缺少镜像文件而失败 | Files: `AGENTS.md`, `.agents/skills/baton-implement/SKILL.md`, `.agents/skills/baton-plan/CLAUDE.md`, `.agents/skills/baton-plan/SKILL.md`, `.agents/skills/baton-research/SKILL.md` | Verify: `git status --short AGENTS.md .agents` 不再出现 `??`；`git ls-files --error-unmatch` 能解析这些路径 | Deps: #5, #6 | Artifacts: git index
- [x] ✅ 13. Change: 切换到“`.claude/skills` 唯一真源，Codex surface 安装时生成”的模型，移除仓库级 `.agents` 镜像硬要求 | Files: `tests/test-workflow-consistency.sh`, `README.md`, `docs/ide-capability-matrix.md` | Verify: 一致性测试不再要求 repo 内 `.agents/skills` 必须存在；README 明确 Codex 的 `AGENTS.md + .agents/skills` 为 generated-on-install | Deps: #5, #6 | Artifacts: none
- [x] ✅ 14. Change: 从仓库工作树移除生成型 Codex surface 文件，避免继续把 `AGENTS.md` / `.agents` 当作源码维护 | Files: `AGENTS.md`, `.agents/skills/baton-implement/SKILL.md`, `.agents/skills/baton-plan/CLAUDE.md`, `.agents/skills/baton-plan/SKILL.md`, `.agents/skills/baton-research/SKILL.md` | Verify: `git status --short AGENTS.md .agents` 不再显示 `A` 或 `??`；`setup.sh --ide codex` 相关测试仍通过 | Deps: #13 | Artifacts: working tree + git index
- [x] ✅ 15. Change: 更新 `setup.sh` 安装后 onboarding 文案到 Direction γ，不再指导用户使用旧 6 类型批注，并补测试覆盖安装输出与默认 Claude 安装生成的 `.agents` fallback | Files: `setup.sh`, `tests/test-setup.sh`, `tests/test-workflow-consistency.sh` | Verify: `bash tests/test-setup.sh` 通过，安装输出包含 free-text + `[PAUSE]`，且默认 Claude 安装仍生成 `.agents/skills` fallback | Deps: #13, #14 | Artifacts: none
- [x] ✅ 16. Change: 更新 `README.md` 的 Annotation Cycle 说明到 free-text + `[PAUSE]` 模型，并纳入一致性检查 | Files: `README.md`, `tests/test-workflow-consistency.sh` | Verify: `bash tests/test-workflow-consistency.sh` 通过，README 不再出现旧 marker 列表，且包含 intent inference / free-text 说明 | Deps: #13 | Artifacts: none
- [x] ✅ 17. Change: 修正 `setup.sh` onboarding 对批注入口的缩窄，明确反馈可发生在 `research.md`、`plan.md` 或 chat，而不是只在 `plan.md` | Files: `setup.sh`, `tests/test-setup.sh`, `tests/test-workflow-consistency.sh` | Verify: `bash tests/test-setup.sh` 通过；安装输出包含 `research.md, plan.md, or chat`，不再将批注入口限定为 `plan.md` | Deps: #15 | Artifacts: none
- [x] ✅ 18. Change: 将 active reference docs 中的标注协议描述迁移到 Direction γ，避免继续教授旧 6 类型 marker 模型 | Files: `docs/first-principles.md`, `docs/implementation-design.md`, `docs/design-comparison.md` | Verify: grep/ diff 确认这 3 份文档的规范性段落与示例改为 free-text + `[PAUSE]` + intent inference / consequence detection | Deps: #16 | Artifacts: none
- [x] ✅ 19. Change: 强化协议回归测试，覆盖 installer/README 的完整旧 marker 回归，以及 active docs 的规范性协议段落 | Files: `tests/test-setup.sh`, `tests/test-workflow-consistency.sh` | Verify: `bash tests/test-workflow-consistency.sh` 通过；若 README/setup 或 3 份 active docs 的协议段落回退到旧 marker 模型则测试失败 | Deps: #17, #18 | Artifacts: none
- [x] ✅ 20. Change: 修正 `setup.sh` onboarding 的流程文案，保留“简单改动可跳过 research.md”的入口，避免把 `research.md → plan.md` 说成固定顺序 | Files: `setup.sh`, `tests/test-setup.sh` | Verify: `bash tests/test-setup.sh` 通过；安装输出明确 simple changes may skip straight to plan.md | Deps: #17 | Artifacts: none
- [x] ✅ 21. Change: 收紧 Direction γ 一致性测试的边界，只把当前 runtime / protocol source 当成强制收敛对象，不再用全文件 grep 改写 comparison/history 文档 | Files: `tests/test-workflow-consistency.sh`, `docs/design-comparison.md` | Verify: `bash tests/test-workflow-consistency.sh` 通过；`design-comparison.md` 恢复比较/历史语义，不再被测试要求整份文档禁用旧 marker 术语 | Deps: #19 | Artifacts: none

**并行策略**: Todo 1-4 互相独立（不同文件），可并行执行。Todo 5 依赖 1+2。Todo 6 依赖所有前置项。

**Post-review scope update**: review 暴露出 3 个计划遗漏。
1. Direction γ 不只影响文档模板，也影响 `phase-guide.sh` 的 ANNOTATION fallback 文案；否则运行时入口仍会指导用户使用旧 6 类型。
2. `tests/test-annotation-protocol.sh` 与 `tests/test-phase-guide.sh` 仍断言旧协议，导致仓库测试为红。
3. 新批注区模板把 `<!-- BATON:GO -->` 嵌进 HTML 注释内部，属于模板语法问题，需要在已计划的 plan/workflow 文件内补修。

**Second review scope update**: 复查还暴露出 2 个低风险但真实的协议漂移。
1. `baton-research` 的 When to Use 和 `baton-plan` 的 Annotation Protocol 仍残留 `[RESEARCH-GAP]` 历史术语，与 Direction γ 的 `[PAUSE]` 唯一显式类型不一致。
2. `baton-plan` 的 todo 完成格式仍写作 `- [x]`，而 workflow / baton-implement 已写作 `- [x] ✅`。运行时 hook 能识别前缀 `- [x]`，但文档层应保持单一表述。

**Third review scope update**: 当前测试和内容已一致，但交付层还缺一个 git 跟踪问题。
1. `tests/test-workflow-consistency.sh` 已把 `.agents/skills` 视为必需镜像输入；如果提交漏掉 `.agents/` 或 `AGENTS.md`，clean checkout 会因为缺少 Codex surface 而漂移。

**Direction change (user confirmed in chat)**:
1. `.claude/skills` 应为唯一手工真源；`.agents/skills` 只是 Codex 安装/自举时生成的 fallback surface，不应再作为仓库内长期维护镜像。
2. `AGENTS.md` 与 `CLAUDE.md` 同类，属于运行时入口文件；对 Codex 而言也应按“缺失则创建”处理，而不是要求源码仓库始终提交一份。
3. 这意味着上面的 Todo 12 属于临时性补丁，现已被新的 source-first 方向取代。后续实现应撤销 repo-level 跟踪要求，而不是继续加强它。

**Fourth review scope update**: 最后一轮复查又暴露出 2 个 active-surface 漂移。
1. `setup.sh` 安装完成后的 onboarding 仍然指导用户使用 `[NOTE] [Q] [CHANGE] [DEEPER] [MISSING]`，与 Direction γ 的 free-text + `[PAUSE]` 不一致。
2. `README.md` 的 Annotation Cycle 仍保留旧 marker 表，和 workflow / skills 的当前协议冲突。

**Fifth review scope update**: 最新复查又发现 3 个残留问题。
1. `setup.sh` 虽已改成 Direction γ，但把批注入口缩窄成了 `plan.md or chat`，遗漏了 `research.md` 的 annotation cycle。
2. `docs/first-principles.md`、`docs/implementation-design.md`、`docs/design-comparison.md` 仍在规范性段落中教授旧 6 类型 marker 协议。
3. 新增测试对 README/setup 的防回归仍偏弱，且没有覆盖上述 3 份 active reference docs 的协议段落。

**Sixth review scope update**: 最新复查指出 2 个收尾问题。
1. `setup.sh` 的 installer onboarding 仍把 `research.md → plan.md` 说成固定顺序，没有反映 simple changes 可直接进入 `plan.md`。
2. `tests/test-workflow-consistency.sh` 现在把 `design-comparison.md` 这类比较/历史文档当成当前协议源做全文件 marker 禁止检查，已经开始扭曲比较文档本身的历史描述。

**Post-review verification (2026-03-08)**:
- `bash tests/test-annotation-protocol.sh` ✅
- `bash tests/test-phase-guide.sh` ✅
- `bash tests/test-workflow-consistency.sh` ✅
- `bash tests/test-setup.sh` ✅（安装输出改为 free-text + `[PAUSE]`，并确认默认 Claude 安装仍生成 `.agents/skills` fallback）
- `bash tests/test-workflow-consistency.sh` ✅（README/setup onboarding 现纳入 Direction γ 覆盖）
- `bash tests/test-setup.sh` ✅（installer onboarding 现明确 `research.md, plan.md, or chat`，并完整排除旧 marker）
- `bash tests/test-workflow-consistency.sh` ✅（3 份 active reference docs 现纳入 Direction γ 一致性覆盖）
- `bash tests/test-setup.sh` ✅（installer onboarding 现明确 simple changes may skip straight to `plan.md`）
- `bash tests/test-workflow-consistency.sh` ✅（`design-comparison.md` 已从当前协议强约束集合移除；comparison/history 语义恢复）
- `for t in tests/test-*.sh; do bash "$t"; done` ✅ 全部通过
- `rg -n '\[NOTE\]|\[Q\]|\[CHANGE\]|\[DEEPER\]|\[MISSING\]|\[RESEARCH-GAP\]|\[WRONG\]' setup.sh docs/first-principles.md docs/implementation-design.md docs/design-comparison.md README.md` ✅ 无命中
- `rg --fixed-strings '[RESEARCH-GAP]' .claude/skills .agents/skills .baton/workflow.md .baton/workflow-full.md` ✅ 无命中
- `git status --short AGENTS.md .agents` ✅ 从 `??` 变为 `A`
- `git ls-files --error-unmatch AGENTS.md .agents/skills/...` ✅ 可解析
- `git status --short AGENTS.md .agents` ✅ 现为空，repo 不再跟踪/保留生成型 Codex surface
- `bash tests/test-setup.sh` ✅ Codex/Claude install 仍会按需创建 `AGENTS.md` / `CLAUDE.md` 与技能 surface

---

## Retrospective

### What the plan got wrong
- **baton-plan/SKILL.md 行数增加了**（206 → 242）而非预期的"删多增少"。原因：新的 Direction Change Rule、Consequence Detection、Pre-Todo Check 和 Step 1 验证加起来的内容多于删除的 6 类型表格。不过新内容都是高优先级认知引导，比旧的表格更有针对性。
- **Frontmatter description 未被 plan 覆盖**。实施中发现两个 skill 的 description 字段仍引用旧类型标签，需要额外修复。这属于变更 3/7 的自然范围但 plan 没有显式提到。

### What surprised me
- **所有现有测试一次通过**。担心 workflow.md 和 workflow-full.md 的改动会破坏 section consistency 检查，但测试只验证共享段落（Mindset、Action Boundaries 等），不验证 Annotation Protocol — 所以不受影响。
- **这个 plan 本身就触发了 G8**：方案分析写在 G8/G9 发现之前，前面没有同步更新。被人类指出后修复。这恰好验证了 G8 的存在性和变更 12/13 的必要性。

### What to research differently next time
- **实施前预估行数变化**：plan 中声称"净行数不增反减"但没有实际计算，导致 Self-Review 中的 ✅ 是未验证的。下次应在 plan 中给出具体的行数预估。
- **Frontmatter 也需要在变更清单中提到**：skill 的 description 字段是 AI 路由的入口（决定什么时候触发 skill），修改 skill 内容时必须同步检查 description 是否仍然准确。

---

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->

<!-- BATON:GO -->

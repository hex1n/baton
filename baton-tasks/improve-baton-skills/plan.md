# Plan: 将 Session 复盘改进落实到 Baton Skill 文件

**Complexity**: Small
**Derived from**: `baton-tasks/improve-baton-skills/research.md` + `baton-tasks/absorb-superpowers-hooks/improvement-plan.md`

---

## Requirements

- `[HUMAN]✅` 改进必须持久化到跟随代码库的 skill 文件中（不是 memory）
- `[HUMAN]✅` Research 采用 A+C 两阶段模式（自由探索 → 框架增强 → review dispatch）
- `[HUMAN]✅` baton 项目中 review 必须用 baton-review 不用 superpowers:code-reviewer

---

## Recommendation: 直接增补

Research 已确认：3 个 skill 文件需要增补 ~70 行，不删除现有内容，无向后兼容风险。

**持久化位置**只有一个合理选择：skill 文件（跟随代码库）。**改变行为的机制**有多种：正文章节（AI 进入 skill 时阅读）、review-prompt.md 检查条目（review 时主动验证）、Red Flag 表（高显著性入口）、hook（机械化强制）。本方案各改动的机制选择：

| Change | 失败模式 | 机制 | 理由 |
|--------|----------|------|------|
| 1a A+C 两阶段 | 规则缺失 — 现有 skill 无"已有分析时怎么做"的路径 | 正文章节 | 定义新流程路径，不是检查点 |
| 1b 配置文件对比 | 规则缺失 — failure modes 列表缺此项 | failure mode 列表 | 与现有 4 条 failure mode 并列 |
| 2a 验证策略 | 规则缺失 — 无验证优先级指导 | 正文（执行步骤处） | 运行时决策指导 |
| 2b 即时标记 | 执行纪律 — 规则存在但措辞不够明确 | 强化措辞 + review-prompt 检查项 | 措辞改行为入口，检查项验证行为结果 |
| 2c Task 进度 | 规则缺失 — 无 TaskCreate/TaskUpdate 指导 | 正文（执行步骤处） | 平台特定能力指导 |
| 3a Review 工具 | 执行纪律 — "prefer" 措辞太弱 | 强化措辞 + Red Flag | Red Flag 表高显著性 |

**有效性风险**：Change 2b 和 3a 针对的是执行纪律而非规则缺失。追加文本不保证改变行为。缓解：3a 同时加入 Red Flag 表（高显著性）；2b 除措辞强化外，增加 review-prompt.md 检查项（Change 2d）作为可验证机制 — review 时主动检查即时标记行为，而非依赖 AI 自觉遵守。

---

## Specification

### Change 1: baton-research — 两阶段模式 + Review Gate + 配置文件对比

**文件**: `.baton/skills/baton-research/SKILL.md`

**1a. 在 `## When to Use` 之后、`## The Process` 之前插入新章节**：

```markdown
## Two-Phase Mode + Review Gate

When analysis has already been done in chat (comparison tables, code examples,
conclusions), the skill's role shifts from **process guide** to **quality
checklist**. Do not rewrite existing analysis into the template — enhance it.

**Phase 1 — Free exploration** (before invoking this skill):
Use any method: chat exploration, brainstorming skill, parallel agents.
Goal: produce the richest possible analysis.

**Phase 2 — Framework enhancement** (this skill):
Take Phase 1 output and enhance with this checklist:
- [ ] Problem framed? (Step 0) — if not, add framing
- [ ] Evidence labeled? (`[CODE]`/`[DOC]`/`[RUNTIME]` + status) — if not, label
- [ ] ≥2 independent evidence methods used? (Step 2) — if not, note gap
- [ ] Counterexample sweep done? (Step 3) — if not, do it now
- [ ] Self-Challenge written? (Step 5) — if not, write it
- [ ] Config files compared field-by-field? — if research involves config files, verify

**Review gate**:
Dispatch baton-review for context-isolated independent review. This catches
gaps that self-enhancement misses.

**Anti-pattern**: Do NOT rewrite Phase 1 analysis to fit Move 1/Move 2 format.
Preserve the original structure. The checklist adds missing elements — it does
not restructure existing content.
```

**1b. 在 Step 3 的 `AI failure modes to guard against` 列表末尾增加**：

```markdown
5. **Config files treated as code** — when research involves config files
   (hooks.json, settings.json, plugin.json), they need field-by-field
   comparison, not logic-flow analysis. A single field value difference
   (e.g., `matcher`) can be the most impactful finding.
```

### Change 2: baton-implement — 分层验证 + 即时标记 + Task 进度

**文件**: `.baton/skills/baton-implement/SKILL.md`

**2a. 在 Step 2 Execute Each Todo Item 的第 4 点（Verify）后增加验证策略指导**：

即在 baton-implement SKILL.md Step 2 的 `4. **Verify** — run the verification method specified` 之后追加：

```markdown
**Verification strategy**: Prefer unit-level checks (jq pipes, grep assertions,
single-command output) over full test suite runs. Full suites are for final
regression, not per-item checks. On slow platforms (Windows Git Bash
~15s/assertion), if a full suite exceeds 2 minutes without results, switch to
isolated verification — do not poll.
```

**2b. 修改 Step 2 第 5 点（Mark complete）**：

当前：`5. **Mark complete** — only after self-check and verify both pass`

改为：
```markdown
5. **Mark complete immediately** — after self-check and verify both pass,
   immediately Edit the plan to change `- [ ]` to `- [x] ✅` for this item.
   Do not batch-update at the end. In Claude Code, also use TaskUpdate to
   mark the task completed for visual progress tracking.
```

**2c. 在 Step 2 开头（CONTINUOUS EXECUTION 段落后）增加**：

```markdown
**Progress tracking**: In Claude Code, use TaskCreate at the start of
execution to create a task for each Todo item. Use TaskUpdate to mark
in_progress when starting an item and completed when done. This provides
visual progress in the chat. Outside Claude Code, rely on immediate plan
marking (Step 2.5) for progress visibility.
```

### Change 2d: baton-implement review-prompt — 即时标记检查项

**文件**: `.baton/skills/baton-implement/review-prompt.md`

在 `### Cross-Phase Compliance Checks` 的检查项列表末尾增加：

```markdown
- [ ] Todo items marked complete immediately after verify pass? (not batch-updated at end)
```

**失败模式**：执行纪律。措辞强化（Change 2b）是弱干预；此检查项确保 review 时主动验证即时标记行为。

### Change 3: using-baton — Review 工具选择强化

**文件**: `.baton/skills/using-baton/SKILL.md`

**3a. 修改 `## Review Dispatch` 第一句**：

当前：`baton-review provides phase-specific review-prompt.md criteria that general reviewers lack. For baton-governed artifacts, prefer it unless the user explicitly requests a different reviewer.`

改为：`baton-review provides phase-specific review-prompt.md criteria that general reviewers lack. For baton-governed artifacts, **prefer baton-review over general-purpose reviewers** (e.g., superpowers:code-reviewer) because it checks governance compliance, not just code quality.`

**3b. 在 `## Red Flags` 表末尾增加一行**：

```markdown
| "I'll use a general-purpose reviewer, it's faster" | baton-review has phase-specific criteria. General reviewers miss governance checks. |
```

### Change 4: 批注区格式提示 — 共享模板 + 使用点可见

**根因**：批注区格式模板定义在 using-baton，但 AI 写批注时在 phase skill 上下文中，看不到模板。Phase skill 只有指针（"Follow using-baton Annotation Protocol"），不是模板本身。

**失败模式**：模板不在使用点 — 不是规则缺失也不是纯执行纪律，而是信息不可达。

**4a. 新建 `.baton/annotation-template.md`** — 单一来源：

```markdown
## 批注区

<!-- Per annotation: ### [Annotation N] / Trigger / Response / Status / Impact -->
```

**4b. 修改 research 两个模板**：

`.baton/skills/baton-research/template-codebase.md` 和 `template-external.md` 中：

当前：
```markdown
## 批注区

> Follow baton-research Annotation Protocol
```

改为：
```markdown
> Append content of `.baton/annotation-template.md`
```

（AI 创建文档时读共享文件，复制其内容到文档末尾）

**4c. 修改 baton-plan SKILL.md Annotation Protocol 处**：

当前：
```markdown
Every plan document ends with `## 批注区`.
Follow using-baton Annotation Protocol for format and processing rules.
```

改为：
```markdown
Every plan document ends with the content of `.baton/annotation-template.md`.
Follow using-baton Annotation Protocol for processing rules.
```

## Implementation Notes

- **A-level: baton-research SKILL.md Annotation Protocol 同步更新**：Change 4 的设计意图要求所有 phase skill 的 Annotation Protocol 引用共享模板，但 plan 遗漏了 baton-research SKILL.md。Review 发现后补充修复。不改变公开合约，仅完善 Change 4 的一致性。
- **A-level: "Step 2.5" 修正为 "Step 2 point 5"**：plan 措辞歧义，Review 发现后在实施中修正。
- **A-level: Progress tracking 增补增量场景**：用户反馈中途新增 Todo 项时只显示新项、丢失全局进度。在 Progress tracking 段落补充"recreate all tasks including completed ones"指导。

---

## Files

| File | Action | Lines |
|------|--------|-------|
| `.baton/skills/baton-research/SKILL.md` | 新增 A+C 章节 + 配置文件对比 failure mode | ~33 |
| `.baton/skills/baton-implement/SKILL.md` | 增补验证策略 + 即时标记 + Task 进度 | ~25 |
| `.baton/skills/baton-implement/review-prompt.md` | 增加即时标记检查项 | ~1 |
| `.baton/skills/using-baton/SKILL.md` | 强化 review 工具选择 + Red Flag | ~5 |
| `.baton/annotation-template.md` | 新建共享批注区模板 | ~3 |
| `.baton/skills/baton-research/template-codebase.md` | 引用共享模板替换指针 | ~1 |
| `.baton/skills/baton-research/template-external.md` | 引用共享模板替换指针 | ~1 |
| `.baton/skills/baton-plan/SKILL.md` | 引用共享模板替换指针 | ~2 |

## Risks & Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skill 文件变长影响可读性 | Low | 所有增补都在逻辑相关位置，不改结构 |
| A+C 模式与现有 Step 0-7 冲突 | Low | A+C 是可选路径（"when analysis already done"），不替换默认流程 |
| TaskCreate/TaskUpdate 只在 Claude Code 可用 | Low | 措辞用 "In Claude Code" 限定 + 回退方案指向 plan marking |
| 追加文本未必改变执行纪律型失败 | Medium | 2b 已升级为措辞 + review-prompt 检查项（可验证）；3a 加 Red Flag（高显著性）。两者都不再仅依赖正文 |

## Verification

1. 读改后的 3 个 skill 文件，确认增补内容在正确位置
2. 确认现有内容未被删除或修改（除 Change 3a 的措辞强化）
3. `bash tests/test-constitution-consistency.sh`

> ⚠️ 需要人类在此处添加 `BATON:GO` 标记以授权执行

---

## Self-Challenge

1. **A+C 模式作为可选正文章节，AI 会真的使用吗？** 逻辑上不矛盾 — skill invoke 后 AI 读到条件分支，评估当前状态选择路径。但有效性问题更关键：AI 倾向于按默认路径（Step 0-7）机械执行。缓解：(1) 章节位于 `## The Process` 之前，AI 进入流程前先读到；(2) 标题和首句明确触发条件（"when analysis already done"）；(3) review gate 提供独立检查层。如果后续观察到 AI 仍然无视此章节回到模板填充，应升级为 Step 0 的强制分支判断。

2. **"不要用 superpowers:code-reviewer" 的规则会不会太绝对？** 措辞是 "unless the user explicitly requests it"，保留了用户覆盖的能力。在 baton 项目中，baton-review 的 phase-specific review-prompt.md 确实比通用 reviewer 更精准 — 这不是偏好，是能力差异。

3. **验证策略指导放在 Step 2 Verify 后是否合适？** Step 1 生成 Todo 时定义 Verify 字段内容，Step 2 执行时运行 Verify。策略指导放在 Step 2 执行处更合适 — 生成时 AI 可能还不知道平台性能特征，执行时才需要决定策略。

---

## 批注区
### [Annotation 1]
- **Trigger / 触发点**: "在 Step 1 的 Todo item schema 说明后增加验证策略指导"这是什么意思
- **Response / 回应**: 措辞不清晰。已改为"在 Step 2 Execute Each Todo Item 的第 4 点 Verify 后增加"，并补充了具体的插入锚点
- **Status**: ✅
- **Impact**: affects conclusions — Change 2a 插入位置修改

### [Annotation 2]
- **Trigger / 触发点**: Review 工具选择 "do not substitute" 写得太死了
- **Response / 回应**: 将 "always use / do not substitute" 改为 "prefer baton-review over general-purpose reviewers because it checks governance compliance"。保留了能力差异的解释，去掉了禁令语气
- **Status**: ✅
- **Impact**: affects conclusions — Change 3a 措辞修改

### [Annotation 3]
- **Trigger / 触发点**: commit 验证去掉
- **Response / 回应**: 已删除 Change 2b（commit 验证 Self-Check）。Files 表行数从 ~30 改为 ~25。Self-Challenge Q3 改为验证策略位置问题
- **Status**: ✅
- **Impact**: affects conclusions — 减少一个改动项

research 除了2阶段式还有更好的方案吗?
- **Response / 回应**: 考虑了 4 个替代方案：(B) Step 0 自适应入口 — 改造 Orient 评估每步是否已满足，只执行缺口步骤，但要求 AI 判断"是否已充分"容易出错（倾向跳过关键检查）；(C) 独立 research-audit skill — 职责分离但增加调度复杂度，且审计内容与 research 检查点高度重复；(D) Quick/Standard/Deep 深度分级 — 更通用但过度设计，当前只有两个真实场景。当前方案 A（两阶段）用最简单的条件入口解决实际问题，不需要更复杂的机制。
- **Status**: ✅
- **Impact**: no impact — 确认当前方案，无需修改

### [Annotation 5 — Review 修复]
- **Trigger / 触发点**: baton-review 发现 7 个问题（2 中 5 低）
- **Response / 回应**: 逐项修复：(1) Recommendation 增加失败模式分类表 + 有效性风险分析，区分"规则缺失"和"执行纪律"；(2) "Phase 3" 改为 "Review gate"，标题改为 "Two-Phase Mode + Review Gate"；(3) Change 2c 增加非 Claude Code 回退方案；(4) Change 1b 配置文件范围从 "when comparing systems" 扩展为 "when research involves config files"；(5) 验证步骤 3 去掉条件式；(6) 添加 BATON:GO 占位提示（AI 不能写标记，需人类添加）；(7) Self-Challenge Q1 从逻辑问题改为有效性问题；(8) Risks 表增加执行纪律有效性风险；(9) Change 2 标题去掉遗留的 "commit 验证"
- **Status**: ✅
- **Impact**: affects conclusions — Recommendation 扩展、Change 1a/1b/2c 措辞修改、Self-Challenge Q1 重写、Risks 表新增一行

### [Annotation 6]
- **Trigger / 触发点**: 从根本性追问——review 修复本身是否是最佳实践？框架层修复用"文档化"解决"文档化可能无效"的问题，是元层面的自相矛盾
- **Response / 回应**: 识别出 Change 2b（即时标记）的干预机制不足：仅措辞强化是最弱干预。新增 Change 2d — 在 `baton-implement/review-prompt.md` 加检查项，使 review 时主动验证即时标记行为。写集从 3 文件扩大为 4 文件。Recommendation 表、Files 表、Risks 表、有效性风险段落同步更新
- **Status**: ✅
- **Impact**: affects conclusions — 新增 Change 2d，写集扩大，执行纪律型改动的干预机制升级

### [Annotation 7]
- **Trigger / 触发点**: 批注区格式不对的改进没有被实施 — research 把它归类为"现有规则已足够"但实际是模板不在使用点的问题
- **Response / 回应**: 根因分析：模板定义在 using-baton，phase skill 只有指针，AI 写批注时看不到格式。新增 Change 4 — 创建共享模板 `.baton/annotation-template.md`，research 模板和 baton-plan 引用共享文件。生成的文档中 HTML 注释提供使用点可见性。写集从 4 文件扩大为 8 文件
- **Status**: ✅
- **Impact**: affects conclusions — 新增 Change 4（4a/4b/4c），Recommendation 表应补充该条目

## Todo

All 4 items are independent (different files, no write-set overlap). Can be parallelized.

- [x] ✅ **1. baton-research SKILL.md — Two-Phase Mode + config failure mode**
  - Change: (1a) Insert `## Two-Phase Mode + Review Gate` section between `## When to Use` and `## The Process`. (1b) Append failure mode #5 (config files) to Step 3's `AI failure modes to guard against` list.
  - Files: `.baton/skills/baton-research/SKILL.md`
  - Verify: `grep -n "Two-Phase Mode" .baton/skills/baton-research/SKILL.md && grep -n "Config files treated as code" .baton/skills/baton-research/SKILL.md`
  - Deps: none
  - Artifacts: none

- [x] ✅ **2. baton-implement SKILL.md — verification strategy + immediate marking + progress tracking**
  - Change: (2a) Insert verification strategy paragraph after Step 2 point 4 (Verify). (2b) Replace Step 2 point 5 (Mark complete) with immediate marking version. (2c) Insert progress tracking paragraph after CONTINUOUS EXECUTION paragraph.
  - Files: `.baton/skills/baton-implement/SKILL.md`
  - Verify: `grep -n "Verification strategy" .baton/skills/baton-implement/SKILL.md && grep -n "Mark complete immediately" .baton/skills/baton-implement/SKILL.md && grep -n "Progress tracking" .baton/skills/baton-implement/SKILL.md`
  - Deps: none
  - Artifacts: none

- [x] ✅ **3. baton-implement review-prompt.md — immediate marking check item**
  - Change: (2d) Append `- [ ] Todo items marked complete immediately after verify pass?` to Cross-Phase Compliance Checks list.
  - Files: `.baton/skills/baton-implement/review-prompt.md`
  - Verify: `grep -n "Todo items marked complete immediately" .baton/skills/baton-implement/review-prompt.md`
  - Deps: none
  - Artifacts: none

- [x] ✅ **4. using-baton SKILL.md — review dispatch wording + Red Flag**

- [x] ✅ **5. 批注区格式提示 — 共享模板 + 模板引用更新**
  - Change: (4a) 新建 `.baton/annotation-template.md`。(4b) 修改 research 两个模板引用共享文件。(4c) 修改 baton-plan SKILL.md 引用共享文件。
  - Files: `.baton/annotation-template.md`, `.baton/skills/baton-research/template-codebase.md`, `.baton/skills/baton-research/template-external.md`, `.baton/skills/baton-plan/SKILL.md`
  - Verify: `test -f .baton/annotation-template.md && grep -n "annotation-template" .baton/skills/baton-research/template-codebase.md && grep -n "annotation-template" .baton/skills/baton-research/template-external.md && grep -n "annotation-template" .baton/skills/baton-plan/SKILL.md`
  - Deps: none
  - Artifacts: none

## Retrospective

1. **Plan 迭代比实施更耗时**：实施本身是 8 个精确的文本插入/替换，每个都有明确锚点，全程无阻塞。但 plan 经历了 6 轮批注 + 1 轮 review + 2 次根本性追问，这反映了"改动简单但设计决策多"的任务特征 — plan 阶段的争论（措辞松紧度、干预机制选择）是价值所在，不应跳过。
2. **"Step 2.5" 引用歧义已修复**：Change 2c 中 "immediate plan marking (Step 2.5)" 读起来像独立步骤。Review 发现后修正为 "(Step 2 point 5)"。教训：plan 中的措辞歧义应在实施时修正，而非留给后续迭代。
3. **执行纪律型改进的有效性待观察**：Change 2b（即时标记）和 3a（review 工具选择）针对执行纪律而非规则缺失。plan 中增加了 review-prompt 检查项和 Red Flag 作为可验证机制，但实际效果需要在后续 session 中观察 — 如果 AI 仍不遵守，应升级为 hook。

<!-- BATON:GO -->

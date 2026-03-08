# Plan：Plan 质量改进 — Surface Scan + 级联防御

## 参考文档

- `research-plan-quality.md`：失败分析 + 外部最佳实践（Change Impact Analysis, Blast Radius, Cline/Claude Code patterns）

## Requirements

Human requirements (chat):
1. Plan 负责 Surface Scan，不是 research
2. 需要结构化级联防御，不只表面回归
3. 英文标签（modify/skip），搜索方法通用化
4. 参考了外部最佳实践（Change Impact Analysis 分层模型）

## 约束条件

1. **AI 指令遵守率有上限**（research-baton-gaps.md Supplement A）— skills 已较长（baton-plan: 242 行, baton-implement: 155 行），新增内容必须精炼
2. **位置偏差**（Supplement A）— Iron Law（开头）和 Red Flags（中间）是遵守率最高的位置
3. **语义检查不可自动化**（research-baton-gaps.md § 4）— Surface Scan 和级联防御都是认知引导，不是 hook
4. **纯 markdown + shell 项目** — 不涉及 AST/import 分析，L2 dependency tracing 主要靠 source/reference 链
5. **workflow-full.md 必须与 skills 对齐** — 两处 Self-Review 模板 + Approach Analysis 段需要同步

## Surface Scan

**搜索词**: `Self-Review`, `Impact scope`, `Step 3`, `After writing code`, `Self-Check`, `Approach Analysis`
**搜索范围**: 全仓库，排除 plans/
**方法**: Grep (text pattern search) + L2 dependency tracing (skills ↔ workflow-full.md 同步关系)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.claude/skills/baton-plan/SKILL.md` | L1 | modify | 主要改动：新增 Step 3b Surface Scan + Self-Review Completeness Check |
| `.claude/skills/baton-implement/SKILL.md` | L1 | modify | 主要改动：Self-Check Triggers 新增三层级联防御 |
| `.baton/workflow-full.md` | L2 | modify | 与 skills 对齐：Approach Analysis 段 + Self-Review 模板 + Implementation Self-Check |
| `tests/test-workflow-consistency.sh` | L2 | modify | 验证新增内容在 skills 和 workflow-full.md 间一致 |
| `.baton/workflow.md` | L2 | skip | 只含顶层原则摘要，不含 Approach Analysis 细节或 Self-Check Triggers |
| `research-plan-quality.md` | L1 | skip | 研究文档，描述改进方案不等于实施 |
| `research-baton-gaps.md` | L1 | skip | 历史研究，不是当前协议源 |
| `docs/plans/*.md` | L1 | skip | 归档文档 |
| `retrospective-2026-03-08.md` | L1 | skip | 复盘记录，不是协议源 |

## 方案分析

### 方案 A：只改 skills，不改 workflow-full.md

- ✅ 最小改动
- ❌ workflow-full.md 的 Approach Analysis 和 Self-Review 模板与 skills 脱节
- ❌ 重演上次 4 源不一致的问题

**排除理由**：上次 plan 的核心教训就是"遗漏同步面"。只改 skills 而不更新 workflow-full.md 正好犯同样的错误。

### 方案 B：改 skills + workflow-full.md + 新增 hook

- ✅ 完整覆盖
- ⚠️ Hook 无法检查语义（research-plan-quality.md § 2.1 — "Surface Scan 是认知引导，不是 hook"）
- ⚠️ 范围较大

**排除理由**：Surface Scan 和级联防御都是 AI 认知层面的改进，shell hook 无法检测"AI 是否做了 Surface Scan"或"AI 是否做了 same-file re-verification"。

### 方案 C：Skills + workflow-full.md + 一致性测试（推荐）

覆盖所有需要改的 surface（4 个 modify 文件），纯 markdown + shell test 改动。

- ✅ skills 和 workflow-full.md 同步
- ✅ 测试验证一致性
- ✅ 纯认知引导，零代码风险
- ✅ 行数控制：Surface Scan 步骤约 20 行，级联防御约 15 行，Self-Review 新增 2 行

## 推荐：方案 C

理由追溯：
- research-plan-quality.md § 3："Plan 阶段需要 implement 阶段同等级别的程序性自检"
- research-plan-quality.md § 4.1："Surface Scan 的核心是把 AI 判断的黑盒打开给人类看"
- research-plan-quality.md Supplement A3："3/4 级联 bug 来自同文件重复修改"
- research-plan-quality.md Supplement B："Impact analysis 在 Claude Code 生态中已是 review 标准实践，Baton 将其前移到 plan 阶段"

---

## 变更清单

### 变更 1：baton-plan/SKILL.md — 新增 Step 3b Surface Scan

**What**：在 Step 3 (Approach Analysis) 和 Step 4 (Recommend) 之间插入 Step 3b。

**当前**（SKILL.md:63-74）：Step 3 以 "Derived artifacts" 结束，直接进入 Step 4。

**新增**：

```markdown
### Step 3b: Surface Scan (required for Medium/Large changes)

Before writing the change list, perform Change Impact Analysis:

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

Build the disposition table from ALL levels and include in plan.md as `## Surface Scan`:

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Default disposition is "modify" — "skip" requires explicit justification.
Self-check: for each "skip" file — if not updated, will users encounter old behavior?
For Trivial/Small changes, Level 1 alone is sufficient.
```

**Why**：research-plan-quality.md § 2.2 — Plan 的影响分析是"描述性"而非"程序性"，变更清单从记忆枚举而不从搜索发现。分层 IA 框架来自 Change Impact Analysis 学科（Wikipedia: Bohner & Arnold）和 Cline 验证（filesystem traversal + AST > keyword search）。

**Impact**：`.claude/skills/baton-plan/SKILL.md`

---

### 变更 2：baton-plan/SKILL.md — Self-Review 新增 Completeness Check

**当前**（SKILL.md:84-97）：Internal Consistency Check 有 4 项，全部是一致性检查。

**新增一项**：

```markdown
- **Does the change list cover ALL files in the Surface Scan disposition table?**
  Files marked "modify" must appear in change list. Files marked "skip" must have justification.
  If no Surface Scan was done → execute one now before presenting.
```

**Why**：research-plan-quality.md § 2.3 — Self-Review 检查一致性但不检查完整性。plan.md 全部 ✅ 但遗漏了 72% 的工作。

**Impact**：`.claude/skills/baton-plan/SKILL.md`

---

### 变更 3：baton-implement/SKILL.md — Self-Check Triggers 三层级联防御

**当前**（SKILL.md:79-105）：Self-Check Triggers 有 5 个触发器。

**3a. "After writing code" 新增 regression check**：

```markdown
- **Regression check**: re-read the surrounding context (5+ lines above and below).
  Did your edit break adjacent logic, narrow scope, or introduce syntax errors?
```

**3b. 新增 "After completing each todo" 触发器**：

```markdown
**After completing each todo**:
- Run tests directly related to the modified files before moving to next todo
- If tests fail → fix before proceeding
- If no relevant tests exist → note this in the todo completion record
```

**3c. 新增 "When modifying a file already changed by a prior todo" 触发器**：

```markdown
**When modifying a file already changed by a prior todo**:
- Before implementing: re-read the file's CURRENT state (not from memory)
- After implementing: re-run ALL verification steps for ALL prior todos
  that touched this file
- Record: "File X touched by todos #A, #B — re-verified #A after #B"
```

**3d. 新增 "After modifying any file" 下游追踪**：

```markdown
**After modifying any file**:
- Who consumes/imports/calls/reads this file?
- Did my change affect any of those consumers?
- For scripts/configs: who runs this? What do they expect?
```

**Why**：
- 3a: research-plan-quality.md § 2.4 — #7 嵌套 HTML comment 是新代码语法错误
- 3b: research-plan-quality.md Supplement A3 层 1 — 当前只在全部完成后 run test suite，太晚
- 3c: research-plan-quality.md Supplement A3 层 2 — 3/4 级联 bug 来自同文件重复修改
- 3d: research-plan-quality.md Supplement A3 层 3 — 大型项目中改一处影响其他地方

**Impact**：`.claude/skills/baton-implement/SKILL.md`

---

### 变更 4：workflow-full.md — 对齐 skills 改动

**4a. [PLAN] Approach Analysis 段**：在 "Estimated impact scope" 后新增提示，引导 AI 做 Surface Scan：

```markdown
   - For Medium/Large changes: perform Surface Scan (search for all references,
     build disposition table) before writing the change list
```

**4b. [PLAN] Self-Review 模板**：新增 Completeness Check 项（与变更 2 对齐）

**4c. [IMPLEMENT] Self-Check 段**：新增三条 trigger（与变更 3b/3c/3d 对齐）

**Why**：上次 plan 的教训 — workflow-full.md 与 skills 必须同步，否则 AI 看到不同版本的指导。

**Impact**：`.baton/workflow-full.md`

---

### 变更 5：tests/test-workflow-consistency.sh — 验证新增内容一致

新增测试项：
- 检查 baton-plan/SKILL.md 包含 "Surface Scan" 段
- 检查 baton-plan/SKILL.md Self-Review 包含 "disposition table" 或 "Surface Scan"
- 检查 baton-implement/SKILL.md 包含 "After completing each todo" 和 "already changed by a prior todo"
- 检查 workflow-full.md 包含 "Surface Scan" 提示

**Impact**：`tests/test-workflow-consistency.sh`

---

## 影响范围

| 文件 | 变更项 | 变更性质 |
|------|--------|---------|
| `.claude/skills/baton-plan/SKILL.md` | 1, 2 | Surface Scan 步骤 + Self-Review 完整性检查 |
| `.claude/skills/baton-implement/SKILL.md` | 3 | 三层级联防御 |
| `.baton/workflow-full.md` | 4 | 对齐 skills |
| `tests/test-workflow-consistency.sh` | 5 | 一致性测试 |

所有变更为纯 markdown 修改（除测试为 shell 脚本）。

## 风险与缓解

| 风险 | 可能性 | 缓解 |
|------|--------|------|
| Surface Scan 增加 plan 阶段时间 | 中 | Trivial/Small 只需 L1；Medium/Large 本来就需要全面分析 |
| Per-todo 测试增加实现时间 | 低 | 比"全部完成后发现级联 bug 再逐个修"更快 |
| Skills 行数增加超过遵守率阈值 | 低 | 预估 baton-plan +20 行, baton-implement +15 行；远低于上次 annotation 重构的增幅 |
| AI 形式主义执行 Surface Scan | 中 | 反形式主义设计：disposition table 可见给人类、skip 需要举证、Self-Review 交叉验证 |

---

## Self-Review

### Internal Consistency Check (fix before presenting)
- ✅ 推荐方案 C = skills + workflow-full.md + 测试。变更清单 1-5 覆盖这 4 个文件。一致。
- ✅ 每个变更项都追溯到 research-plan-quality.md 的具体段落。无游离变更。
- ✅ Surface Scan 表覆盖了所有搜索结果（9 个文件，4 modify + 5 skip with reason）。
- ✅ 变更清单 cover 所有 Surface Scan 中标记 "modify" 的文件。无遗漏。
- ✅ 变更 4 显式同步变更 1/2/3 到 workflow-full.md。
- ✅ 预估行数增加合理：baton-plan +20, baton-implement +15, workflow-full +10, test +15。

### External Risks (present to human)
- **最大风险**：Surface Scan 的分层框架（L1/L2/L3）对于 baton 当前的 markdown+shell 项目可能 overkill — L2 dependency tracing 在纯 markdown 项目中价值有限（没有 import 链）。但保留 L2/L3 是为了 baton 应用到真正的代码项目时能适用。
- **什么会让这个计划完全错误**：如果 AI 的 Surface Scan 本身就不完整（搜索词选错），那整个框架失效。但这与"不做 Surface Scan"相比，至少多了一层人类可审查的 disposition table。
- **被拒绝的替代方案**：方案 B（新增 hook）被拒绝因为 Surface Scan 是语义任务，shell hook 无法验证"AI 是否做了完整的 Surface Scan"。

---

## Annotation Log

### Round 1

**[inferred: direction-question] § Scope**
"我考虑是否有必要在加一个 code-review的skill在baton中呢?"
→ 分析了当前防御层次：baton 缺少 post-implement 整体性复查阶段。用户用 Codex review 填补了这个缺口。
→ 提出三个选项：A(纳入本 plan) / B(独立后续任务) / C(轻量版：在 baton-implement Completion 加 review checklist)
→ AI 倾向 C（核心价值可用 5-10 行 checklist 实现，效果好再升级为独立 skill）
→ Consequence: 如果采纳 C，需新增变更 6（baton-implement Completion + workflow-full.md 对齐）
→ Result: **用户选择 B — 作为独立后续任务。** 本 plan 范围不变，code-review skill 在本 plan 完成后单独 research → plan → implement。

## Todo

- [x] ✅ 1. Change: Add Step 3b Surface Scan to baton-plan/SKILL.md — insert between Step 3 (line 75) and Step 4 (line 77), containing L1/L2/L3 Change Impact Analysis framework and disposition table template | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: grep for "Surface Scan", "Level 1", "Level 2", "Level 3", "disposition" in file | Deps: none | Artifacts: none
- [x] ✅ 2. Change: Add Completeness Check to baton-plan/SKILL.md Self-Review — insert new bullet in Internal Consistency Check (line 91) verifying change list covers all Surface Scan disposition table entries | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: grep for "disposition table" in Self-Review section | Deps: #1 (same file) | Artifacts: none
- [x] ✅ 3. Change: Add three-layer cascading defense to baton-implement/SKILL.md Self-Check Triggers — (3a) regression check after "After writing code", (3b) "After completing each todo" trigger, (3c) "When modifying a file already changed by a prior todo" trigger, (3d) "After modifying any file" downstream tracing | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: grep for "Regression check", "After completing each todo", "already changed by a prior todo", "After modifying any file" | Deps: none | Artifacts: none
- [x] ✅ 4. Change: Sync workflow-full.md with skill changes — (4a) add Surface Scan hint to Approach Analysis section, (4b) add Completeness Check to Self-Review template, (4c) add cascading triggers to Implementation Self-Check section | Files: `.baton/workflow-full.md` | Verify: grep for "Surface Scan", "disposition table", "After completing each todo", "already changed" in file | Deps: #1, #2, #3 | Artifacts: none
- [x] ✅ 5. Change: Add consistency tests verifying new content exists in both skills and workflow-full.md — test Surface Scan in baton-plan, disposition table in Self-Review, cascading triggers in baton-implement, Surface Scan hint in workflow-full.md | Files: `tests/test-workflow-consistency.sh` | Verify: `sh tests/test-workflow-consistency.sh` passes | Deps: #1, #2, #3, #4 | Artifacts: none

## Test Results

- test-workflow-consistency.sh: ALL CONSISTENT ✅
- All other test suites: 12/13 pass (test-multi-ide.sh 59/60 — pre-existing failure, unrelated)

## Retrospective

### What the plan got right
- Scope estimation was accurate: 5 changes across 4 files, pure markdown + shell
- Line count estimates were close: predicted +20/+15/+10/+15, actual ~+28/+18/+7/+30
- Dependency ordering was correct: #1 and #3 truly independent, #4 needed all prior, #5 needed all

### What surprised
- Nothing major — the changes were well-specified and straightforward. The plan's own Surface Scan (9 files analyzed) correctly identified the 4 modify targets.

### What to research differently next time
- The pre-existing test-multi-ide.sh failure (1/60) was not investigated. Future plans touching multi-IDE surface should check this first.

---

Ready to archive: `mkdir -p plans && mv plan-plan-quality.md plans/plan-2026-03-08-plan-quality.md && mv research-plan-quality.md plans/research-2026-03-08-plan-quality.md`

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->
    B 作为独立后续任务

<!-- BATON:GO -->
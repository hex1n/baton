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

Research 已确认：3 个 skill 文件需要增补 ~70 行，不删除现有内容，无向后兼容风险。不需要枚举其他方案 — 这是唯一合理的持久化方式（skill 文件跟随代码库）。

---

## Specification

### Change 1: baton-research — A+C 两阶段模式 + 配置文件对比

**文件**: `.baton/skills/baton-research/SKILL.md`

**1a. 在 `## When to Use` 之后、`## The Process` 之前插入新章节**：

```markdown
## Two-Phase Mode (A+C)

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
- [ ] Config files compared field-by-field? — if comparing systems, verify

**Phase 3 — Review dispatch**:
Dispatch baton-review for context-isolated independent review. This catches
gaps that self-enhancement misses.

**Anti-pattern**: Do NOT rewrite Phase 1 analysis to fit Move 1/Move 2 format.
Preserve the original structure. The checklist adds missing elements — it does
not restructure existing content.
```

**1b. 在 Step 3 的 `AI failure modes to guard against` 列表末尾增加**：

```markdown
5. **Config files treated as code** — when comparing systems, config files
   (hooks.json, settings.json, plugin.json) need field-by-field comparison,
   not logic-flow analysis. A single field value difference (e.g., `matcher`)
   can be the most impactful finding.
```

### Change 2: baton-implement — 分层验证 + commit 验证 + 即时标记 + Task 进度

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
visual progress in the chat.
```

### Change 3: using-baton — Review 工具选择强化

**文件**: `.baton/skills/using-baton/SKILL.md`

**3a. 修改 `## Review Dispatch` 第一句**：

当前：`baton-review provides phase-specific review-prompt.md criteria that general reviewers lack. For baton-governed artifacts, prefer it unless the user explicitly requests a different reviewer.`

改为：`baton-review provides phase-specific review-prompt.md criteria that general reviewers lack. For baton-governed artifacts, **prefer baton-review over general-purpose reviewers** (e.g., superpowers:code-reviewer) because it checks governance compliance, not just code quality.`

**3b. 在 `## Red Flags` 表末尾增加一行**：

```markdown
| "I'll use superpowers:code-reviewer, it's faster" | baton-review has phase-specific criteria. General reviewers miss governance checks. |
```

---

## Files

| File | Action | Lines |
|------|--------|-------|
| `.baton/skills/baton-research/SKILL.md` | 新增 A+C 章节 + 配置文件对比 failure mode | ~33 |
| `.baton/skills/baton-implement/SKILL.md` | 增补验证策略 + 即时标记 + Task 进度 | ~25 |
| `.baton/skills/using-baton/SKILL.md` | 强化 review 工具选择 + Red Flag | ~5 |

## Risks & Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skill 文件变长影响可读性 | Low | 所有增补都在逻辑相关位置，不改结构 |
| A+C 模式与现有 Step 0-7 冲突 | Low | A+C 是可选路径（"when analysis already done"），不替换默认流程 |
| TaskCreate/TaskUpdate 只在 Claude Code 可用 | Low | 措辞用 "In Claude Code" 限定，不影响其他 IDE |

## Verification

1. 读改后的 3 个 skill 文件，确认增补内容在正确位置
2. 确认现有内容未被删除或修改（除 Change 3a 的措辞强化）
3. `bash tests/test-constitution-consistency.sh` — 如果存在

---

## Self-Challenge

1. **A+C 模式放在 baton-research skill 里，但说"Phase 1 在 invoke skill 之前"— 这不矛盾吗？** 不矛盾。skill 被 invoke 后 AI 读到 A+C 章节，它说"如果分析已在 chat 中完成，用 Phase 2 模式"。这是条件分支，不是时序矛盾。AI 进入 skill 时评估当前状态，选择路径。

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
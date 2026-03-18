# Research: 将 Session 复盘改进落实到 Baton Skill 文件

## Question
改进计划中的 7 项改进（P0-P2）应该改动哪些 skill 文件的哪些章节？

## Why
改进如果只存在 memory 中，换电脑就失效。必须持久化到跟随代码库的 skill 文件中。

## Scope
- 输入：`baton-tasks/absorb-superpowers-hooks/improvement-plan.md` 的 7 项改进
- 输出：每项改进 → 目标 skill 文件 + 具体插入位置 + 改动内容摘要
- Out of scope：不改 constitution.md（已有足够的证据纪律规则）

## Task Sizing: Small
明确的改动集，少量文件，无架构变更。

---

## 改进 → Skill 映射

### 1. P0 Research A+C 两阶段模式 → `baton-research/SKILL.md`

**当前状态** `[CODE]✅`：
- Step 0-7 定义了线性流程：Frame → Orient → Investigate → Self-Challenge → Review → Convergence
- 没有区分"自由探索"和"框架增强"两个阶段
- AI 容易把整个流程当模板填

**需要改什么**：
- 在 `## The Process` 开头增加一个 `### 两阶段模式` 章节
- 明确说明：当分析已在 chat 中完成时，skill 的角色是**质量检查清单**而非过程指南
- 保留现有 Step 0-7 作为"从零开始"的完整流程
- 增加质量检查清单（从现有步骤提取关键检查点）

**插入位置**：`## The Process` 之前，`## When to Use` 之后

**改动量**：新增 ~30 行，不删除现有内容

### 2. P0 测试分层验证 → `baton-implement/SKILL.md`

**当前状态** `[CODE]✅`：
- Step 1 生成 Todo list 时要求 `Verify` 字段
- Step 2 执行时要求 "Run the required validation commands"
- 没有指导验证策略的优先级（单元验证 vs 集成测试）

**需要改什么**：
- 在 Step 1 的 Verify 字段说明中增加验证策略指导
- 在 Self-Checks 章节增加验证超时处理规则

**插入位置**：
- Step 1 的 Todo item schema 说明处
- Self-Checks 章节末尾

**改动量**：新增 ~15 行

### 3. P1 Commit 验证 → `baton-implement/SKILL.md`

**当前状态** `[CODE]✅`：
- Step 5 Completion 没有提到 commit 验证
- 整个 skill 没有提到 git commit 流程

**需要改什么**：
- 在 Step 5 或 Self-Checks 中增加 commit 后验证规则

**插入位置**：Self-Checks 章节，作为第 5 个 check

**改动量**：新增 ~5 行

### 4. P1 Review 工具选择 → `using-baton/SKILL.md`

**当前状态** `[CODE]✅`：
- `## Review Dispatch` 章节已经说 "baton-review provides phase-specific review-prompt.md criteria that general reviewers lack. For baton-governed artifacts, prefer it"
- 但措辞是 "prefer"，不是 "must"

**需要改什么**：
- 将 "prefer" 改为更强的措辞
- 增加 Red Flag："想用 superpowers:code-reviewer 代替 baton-review"

**插入位置**：
- `## Review Dispatch` 章节
- `## Red Flags` 表

**改动量**：修改 ~3 行，新增 ~2 行

### 5. P1 Todo 即时标记 + Task 进度可视化 → `baton-implement/SKILL.md`

**当前状态** `[CODE]✅`：
- Step 2 第 5 点："Mark complete — only after self-check and verify both pass"
- 没有说"立即标记"，也没提 TaskCreate/TaskUpdate

**需要改什么**：
- 在 Step 2 第 5 点强调"立即标记，不要批量"
- 在 Step 1 或 Step 2 开头增加 TaskCreate 指导（Claude Code 环境）

**插入位置**：Step 2 章节

**改动量**：新增 ~10 行

### 6. P2 批注区格式 → 不需要改 skill

**当前状态** `[CODE]✅`：
- `using-baton/SKILL.md` 的 `## Annotation Protocol` 已有完整格式定义
- 问题不是规则缺失，是执行时没遵守

**结论**：不需要 skill 改动。现有规则已足够。

### 7. P2 竞品分析覆盖配置差异 → `baton-research/SKILL.md`

**当前状态** `[CODE]✅`：
- Step 3 Investigate 有 "AI failure modes to guard against" 列表
- 没有提到配置文件 vs 代码文件的区分

**需要改什么**：
- 在 failure modes 列表中增加一条：配置文件逐字段对比

**插入位置**：Step 3 的 failure modes 列表

**改动量**：新增 ~3 行

### 8. P2 持续执行纪律 → 不需要改 skill

**当前状态** `[CODE]✅`：
- `baton-implement/SKILL.md` Step 2 已有 "CONTINUOUS EXECUTION" 大写强调段落
- 问题不是规则缺失，是执行时没遵守

**结论**：不需要 skill 改动。现有规则已足够。

---

## 汇总

| 改进 | 目标文件 | 改动类型 | 行数估计 |
|------|----------|----------|----------|
| P0 Research A+C | `baton-research/SKILL.md` | 新增章节 | ~30 行 |
| P0 测试分层验证 | `baton-implement/SKILL.md` | 增补 | ~15 行 |
| P1 Commit 验证 | `baton-implement/SKILL.md` | 增补 | ~5 行 |
| P1 Review 工具选择 | `using-baton/SKILL.md` | 修改+增补 | ~5 行 |
| P1 Todo 即时标记 + Task | `baton-implement/SKILL.md` | 增补 | ~10 行 |
| P2 批注区格式 | 无 | 现有规则已足够 | 0 |
| P2 配置文件对比 | `baton-research/SKILL.md` | 增补 | ~3 行 |
| P2 持续执行纪律 | 无 | 现有规则已足够 | 0 |

**写集**：3 个文件
- `.baton/skills/baton-research/SKILL.md`
- `.baton/skills/baton-implement/SKILL.md`
- `.baton/skills/using-baton/SKILL.md`

**总改动**：~70 行新增/修改，0 行删除

---

## Self-Challenge

1. **P2 项"不需要改 skill"是否正确？** 批注区格式和持续执行的问题确实是执行纪律问题而非规则缺失。现有 skill 文本已有明确要求。增加更多规则文本不会改善执行 — 这类问题更适合通过 review 抓住。✅ 判断成立。

2. **A+C 模式放在 skill 里会不会让 skill 变得太长太复杂？** baton-research 当前 ~200 行。新增 ~30 行不会显著增加复杂度。关键是新增内容要放在正确位置（流程入口处，不是深埋在步骤中）。

3. **修改 skill 文件是否有向后兼容风险？** 所有改动都是增补，不删除现有内容。现有流程仍然可用。A+C 模式是可选路径（"当分析已在 chat 中完成时"），不替换默认流程。

---

## Final Conclusions

3 个 skill 文件需要改动，总计 ~70 行增补。最大改动是 baton-research 的 A+C 两阶段模式（~30 行）。2 项改进不需要 skill 改动（现有规则已足够）。所有改动都是增补，无删除，无向后兼容风险。

---

## 批注区

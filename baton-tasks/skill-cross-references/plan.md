# Plan: Baton skill cross-references

**Complexity**: Trivial
**State**: COMPLETE

## Requirements

- [HUMAN] baton skills 之间缺少显式连接，导致 AI 在有 baton-review 的项目里误用 superpowers:code-reviewer
- 在隐式引用处加上 skill 名，形成闭环

## First Principles

**Problem**: 4 个 skill 在需要 dispatch baton-review 时只说"dispatch review subagent"不说调谁，AI 默认选了 superpowers 生态的 reviewer。

**Constraints**: 不改流程、不加规则、不加新 section。只在已有文字中加 skill 名。

**Evaluation**: 6 个断点中，4 个是 review dispatch（需要加 baton-review 名），2 个是 phase transition（research→plan、implement→plan，这是状态边界不是 dispatch，不需要加）。

## Recommendation

**A. implement Step 1 + Step 5: "dispatch review subagent" → "dispatch baton-review"**

| File | Line | 现状 | 改为 |
|------|------|------|------|
| baton-implement Step 1 | 55 | "dispatch review subagent via Agent tool" | "dispatch baton-review via Agent tool" |
| baton-implement Step 5 | 99 | "dispatch review subagent via Agent tool" | "dispatch baton-review via Agent tool" |

**B. implement Step 5: 写明 review-fix-re-review 循环**

现状：Step 5.1 只说 "Fix findings before proceeding"，没说修完后要 re-review。

改为：明确 review → fix → re-review 循环，引用 baton-review 的 circuit breaker（3 轮 high severity 后升级给 human）。

**C. baton-review: circuit breaker 阈值 2 → 3**

**Write set**: 2 files（baton-implement, baton-review 的 SKILL.md）

## Todo

- [x] 1. baton-implement Step 1: "dispatch review subagent" → "dispatch baton-review" ✅
  Files: `.baton/skills/baton-implement/SKILL.md`
  Verify: grep shows "baton-review" on line 55
  Deps: none
  Artifacts: none

- [x] 2. baton-implement Step 5: "dispatch review subagent" → "dispatch baton-review" + review-fix-re-review 循环 ✅
  Files: `.baton/skills/baton-implement/SKILL.md`
  Verify: grep shows "baton-review" on Step 5; re-review loop text present
  Deps: none
  Artifacts: none

- [x] 3. baton-review: circuit breaker 2 → 3 ✅
  Files: `.baton/skills/baton-review/SKILL.md`
  Verify: grep shows "3 revision" instead of "2 revision"
  Deps: none
  Artifacts: none

## Retrospective

1. **Wrong prediction**: 初始 plan 包含 4 个 skill 文件（research/plan/implement/review），批注分析后精简为 2 个——research 和 plan 的 review 有其他阶段兜底，不需要强化。
2. **Surprise**: 删除 inline review criteria 时丢掉了 B-level rationale 检查——baton-review 没有 implement 特有的 A/B/C/D 概念，不能完全替代。
3. **Process**: review-fix-re-review 循环第一次在 baton 里使用——首轮 review 发现 medium finding，修复后第二轮 pass。正好验证了这个机制。
4. **流程疏忽**: 第一轮 review 之前就把 State 改为 COMPLETE，被人发现纠正。

<!-- BATON:COMPLETE -->

## 批注区
我有一个想法 如果baton-implement 实现完成后 使用 baton-review 去审查 如果有问题就继续修改实现 直到 review 通过为止 这样就形成了一个闭环 让 review 不再是可选项 而是一个必经的步骤 你觉得这个流程怎么样？ 但是也需要考虑不能无限循环

> **回应**: 好想法。implement Step 5 已有 "Fix findings before proceeding" 但缺两个关键件：(1) 修完后要 re-review (2) circuit breaker 防无限循环。baton-review 已有 circuit breaker（3 轮 high severity 后升级给 human），只需在 implement 侧引用。Plan 已更新为 A+B 两层改动。

我看现在 baton-research Step 5 和 baton-plan Step 6 都提到了要baton-review 这两个地方有必要性吗 分析

> **回应**: implement 是唯一没有后续阶段兜底的 review 点（review 后直接 commit）。research 有 self-challenge + counterexample sweep + plan 阶段兜底；plan 有 self-challenge + human annotation cycle。结论：只在 implement 强化 baton-review 连接，research/plan 保持可选措辞。Plan 相应精简为只改 implement + review 两个文件。

我额外发现 baton-tasks/rename-workflow-to-constitution/plan.md 中的 State 不是终态 即使这个任务已经完成了

> **回应**: 确认 ✅ 已修正为 `COMPLETE`。这是 baton-implement Step 5 漏掉的——完成时只加了 `BATON:COMPLETE` 标记但忘记更新 State 字段。属于 implement 流程的执行疏忽，不需要改 skill。

 <!-- BATON:GO -->
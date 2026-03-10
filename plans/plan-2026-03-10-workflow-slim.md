# Plan: workflow.md 瘦身 — 移除协议索引，保留纯协议

> 基于外部评审：workflow.md 混入了"文档治理"内容，应只承载"协议规则"

## Requirements

- [HUMAN] Document Authority 整段不该放在 workflow.md，挪到 workflow-full.md
- [HUMAN] Phase Guidance（L86-90）与 L52 重复，压缩或删除
- [HUMAN] Session Handoff L78（worktrees / hooks auto-discover / BATON_PLAN）是实现细节，挪走
- [HUMAN] 保留：Action Boundaries L43、Enforcement Boundaries L80-84、skill 入口 L52

## Complexity

**Small** — 2 文件修改，scope 明确，无歧义

---

## Constraints

1. **Token 预算**：workflow.md 目标 ~400 tokens，这次是净删减，预算只会改善
2. **workflow-full.md 是 fallback**：挪过去的内容必须在那边完整保留
3. **测试无断言**：tests/ 中无 "Document Authority" / "Phase Guidance" / "Enforcement Boundaries" 相关断言 [CODE] Grep → 0 matches

---

## Recommendation

**单一方案：删 + 挪**

从 workflow.md 删除三段内容，将其中有保留价值的部分并入 workflow-full.md。
不需要方案比较——评审指出的问题只有一个解法：把不属于协议层的内容移出协议层。

### 具体操作

#### Change 1: workflow.md — 删除 Document Authority 整节

**删除** L92-96（`### Document Authority` 及其 4 行内容）。

理由：三个 SKILL.md 已各自带 `normative-status` frontmatter [CODE] `.claude/skills/baton-implement/SKILL.md:2`，workflow.md 重复定义是冗余。这是文档治理，不是行为约束。

#### Change 2: workflow.md — 删除 Phase Guidance 整节

**删除** L86-90（`### Phase Guidance` 及其 4 行内容）。

理由：L52 已经说 "Before entering any phase, check for the corresponding baton skill" [CODE] `.baton/workflow.md:52`。Phase Guidance 是重复的 meta 信息。

"4 个主阶段 + 2 个系统态"这个模型声明不再需要单独出现在 workflow.md —— Enforcement Boundaries L83 已经提到 AWAITING_TODO [CODE] `.baton/workflow.md:83`，phase-guide.sh 负责实现 [CODE] `.baton/hooks/phase-guide.sh`。

#### Change 3: workflow.md — Session Handoff 删除 L78

**删除** L78 一行（`Use git worktrees for parallel sessions. Hooks auto-discover plan files; set BATON_PLAN to override if multiple plans exist.`）

**保留** L75-77（Lessons Learned + archive preservation）— 这是行为约束。

理由：worktrees 是工作建议，hooks auto-discover 是实现细节，BATON_PLAN 是配置机制。都不是"AI 必须遵守什么"。

#### Change 4: workflow-full.md — 接收挪出的内容

workflow-full.md 已有 `### Phase Guidance`（L109-115）和 `### Session Handoff`（L104-107），需要：

1. Phase Guidance 保留现有内容不变（已经比 workflow.md 版本更完整，含 fallback 说明）
2. Session Handoff L107：保留现有 worktrees/BATON_PLAN 行（已存在）
3. **新增** `### Document Authority` 节在 Phase Guidance 之后，内容从 workflow.md 搬入

---

## Surface Scan (L1)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L1 | **modify** | 删除 3 段内容 |
| `.baton/workflow-full.md` | L1 | **modify** | 接收 Document Authority |
| `tests/test-workflow-consistency.sh` | L2 | **skip** | 无相关断言 [CODE] Grep → 0 matches |
| `tests/test-ide-capability-consistency.sh` | L2 | **skip** | 无相关断言 |

### Skip 验证

| Skip 文件 | 如果不更新？ |
|-----------|------------|
| test-workflow-consistency.sh | 无影响 — 不检查被删除的节名 |
| test-ide-capability-consistency.sh | 无影响 — 不检查 workflow.md 内部结构 |

---

## Self-Review

### Internal Consistency Check
- ✅ 推荐方案（删 + 挪）贯穿所有 Change
- ✅ 每个 Change 回溯到评审具体批评点
- ✅ Surface Scan 覆盖所有 "modify" 文件
- ✅ 保留项（L43, L52, L80-84）不在任何 Change 的删除范围内
- ✅ 无内部矛盾

### External Risks
1. **最大风险**：删除 Document Authority 后，如果 AI 在 workflow-full.md 不可用的降级场景中无法得到文档层级信息。**缓解**：SKILL.md 自带 normative-status，L52 指向 skill，两层覆盖足够
2. **可能推翻计划的因素**：如果人类认为"4+2 态模型声明"必须在 slim workflow 中出现。当前判断：Enforcement Boundaries L83 已隐含 AWAITING_TODO 态，不需要显式模型声明
3. **被否决的替代方案**：将 Document Authority 压缩为一行保留在 workflow.md（如 "SKILL.md is authoritative per phase; workflow-full.md is fallback"）— 但这仍然是文档索引而非行为约束，不应在 slim 层

---

## Todo

- [x] ✅ 1. Change: workflow.md — delete `### Document Authority` section (L92-96) + delete `### Phase Guidance` section (L86-90) + delete Session Handoff L78 | Files: .baton/workflow.md | Verify: file ends at Enforcement Boundaries, test-workflow-consistency.sh passes | Deps: none | Artifacts: none
- [x] ✅ 2. Change: workflow-full.md — add `### Document Authority` section after Phase Guidance + remove worktrees/BATON_PLAN line from Session Handoff (B-level: consistency test requires section match) | Files: .baton/workflow-full.md | Verify: section present, test-workflow-consistency.sh passes | Deps: none | Artifacts: none
- [x] ✅ 3. Change: run tests to verify no regressions | Files: none | Verify: test-workflow-consistency.sh ALL CONSISTENT + test-ide-capability-consistency.sh 20/20 ALL PASSED | Deps: #1, #2 | Artifacts: none

---

## Retrospective

- **Plan vs reality**: Plan specified adding Document Authority to workflow-full.md and removing worktrees line only from workflow.md. Reality: `test-workflow-consistency.sh` checks Session Handoff for exact match between both files, so the worktrees/BATON_PLAN line also had to be removed from workflow-full.md (B-level adjacent change). The info remains in README.md, docs/, and hook implementations.
- **Surprise**: None — straightforward deletions.
- **Next time**: When planning changes to workflow.md shared sections, always check `test-workflow-consistency.sh:18` for which sections require exact match.

---

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

 <!-- BATON:GO -->
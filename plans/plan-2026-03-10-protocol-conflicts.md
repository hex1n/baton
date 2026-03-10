# Plan: 修复两处协议层硬冲突

> research.md 产出规则自相矛盾 + write set 规则与 implement skill 不一致

## Requirements

- [HUMAN] L51 "All analysis tasks produce research.md" 与 L25 "Trivial/Small may skip" 矛盾 — 改 L51
- [HUMAN] L42 "Only modify plan-listed files" 与 baton-implement A/B 级预授权例外矛盾 — 改 L42
- [HUMAN] L48 (#6) "Discover omission → MUST stop" 也与 A/B 级矛盾 — 同步改

## Complexity

**Small** — 2 文件 (workflow.md, workflow-full.md) 纯文案修正，无测试断言涉及

---

## Recommendation

三处文案修正，消除协议层规则说法不唯一：

### Fix 1: L51 — research.md 产出规则

**当前** [CODE] `.baton/workflow.md:51`:
> `9. All analysis tasks produce research.md. Baton workflow applies to ALL analysis.`

**冲突来源**:
- [CODE] `.baton/workflow.md:25`: "Trivial or Small, research.md may be skipped"
- [CODE] `.baton/workflow.md:29`: Small "may skip research.md"
- [CODE] `.claude/skills/baton-research/SKILL.md:35-36`: "Trivial/Small tasks that can go directly to planning"

**改为**:
> `9. Medium/Large analysis tasks produce research.md. Trivial/Small may inline reasoning in plan.md.`

保留 "Baton workflow applies to ALL analysis" 的精神（所有分析都走 baton 流程），但不再强制 Trivial/Small 产出独立 research.md。

### Fix 2: L42 (#4) — write set 规则

**当前** [CODE] `.baton/workflow.md:42`:
> `4. Only modify files listed in the plan. Need additions? Propose in plan first (file + reason).`

**冲突来源** [CODE] `.claude/skills/baton-implement/SKILL.md:165-177`: A/B 级可以在 implement 阶段直接追加到 write set。

**改为**:
> `4. Only modify files in the approved write set. By default, the approved write set is the plan-listed files. During implementation, the implement skill permits narrowly scoped A/B-level additions to be appended to the current todo/write set without replanning; broader additions require updating the plan first.`

L43（advisory 说明）保持不变，跟在新 L42 后面。

### Fix 3: L48 (#6) — omission stop 规则

**当前** [CODE] `.baton/workflow.md:48`:
> `6. Discover omission during implementation → MUST stop, update plan.md, wait for human confirmation.`

**冲突来源**: 与 A/B 级预授权矛盾——A/B 级 omission 不需要 stop。

**改为**:
> `6. Discover a C/D-level omission during implementation → MUST stop, update plan.md, wait for human confirmation.`

### 额外同步点

[CODE] `.baton/hooks/phase-guide.sh:75`:
> `Only modify files listed in the plan. Discover omission → STOP, update plan.`

这是 phase-guide IMPLEMENT 阶段的 fallback 提示。它是简化版指引，不是完整协议，且仅在 skill 不可用时显示。当前措辞虽然简化了 A/B 例外，但作为 fallback 提示是可接受的——偏严比偏松安全。**不改**。

---

## Surface Scan (L1)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L1 | **modify** | L42, L48, L51 三处修正 |
| `.baton/workflow-full.md` | L1 | **modify** | 同步 L42, L48, L51 |
| `.baton/hooks/phase-guide.sh` | L1 | **skip** | Fallback 提示，偏严可接受 |
| `docs/plans/2026-03-03-agentic-prompts.md` | L1 | **skip** | 历史归档文档 |
| `docs/plans/2026-03-03-agentic-prompts-zh.md` | L1 | **skip** | 历史归档文档 |
| tests/ | L2 | **skip** | 未发现直接依赖这些具体文案的测试断言；本轮不改 tests |

### Skip 验证

| Skip 文件 | 如果不更新？ |
|-----------|------------|
| phase-guide.sh | Fallback 提示偏严（"任何 omission 都 stop"），用户在无 skill 场景下会多一次不必要的 stop。可接受——比偏松导致 write set 漂移好 |
| agentic-prompts*.md | 历史文档，不影响 AI 行为 |

---

## Self-Review

### Internal Consistency Check
- ✅ 三处修正消除所有已知 workflow.md 内部矛盾
- ✅ 修正后 workflow.md L25/L29/L51 对 research.md 产出说法一致
- ✅ 修正后 workflow.md L42/L48 与 baton-implement SKILL.md A/B/C/D 层级一致
- ✅ 无内部矛盾

### External Risks
1. **最大风险**: L42 新措辞引用了 "implement skill" 但没有展开 A/B 定义——依赖 AI 在 implement 阶段加载 skill 才能看到完整定义。**缓解**: L52 已要求进入任何 phase 先加载 skill，这是基本保证
2. **可能推翻计划**: 如果人类认为 phase-guide.sh fallback 也需要承认 A/B 例外。当前判断：fallback 场景本身就是降级，偏严合理
3. **被否决的替代**: 在 workflow.md 中完整复制 A/B/C/D 四级定义。否决原因：workflow.md 是 slim 协议层，完整定义属于 SKILL.md 职责

---

## Todo

- [x] ✅ 1. Change: workflow.md — fix L51 (research.md rule), L42 (write set rule), L48 (omission stop rule) | Files: .baton/workflow.md | Verify: test-workflow-consistency.sh ALL CONSISTENT | Deps: none | Artifacts: none
- [x] ✅ 2. Change: workflow-full.md — sync same three fixes | Files: .baton/workflow-full.md | Verify: test-workflow-consistency.sh ALL CONSISTENT | Deps: #1 | Artifacts: none
- [x] ✅ 3. Change: run tests | Files: none | Verify: test-workflow-consistency.sh ALL CONSISTENT + test-ide-capability-consistency.sh 20/20 ALL PASSED | Deps: #1, #2 | Artifacts: none

---

## Annotation Log

### Round 1

**[inferred: change-request] § Fix 3 L48 措辞**
"scope-extending omission (C/D level) 叠了两套分类语言，建议收成 'Discover a C/D-level omission'"
→ 同意。真正起约束作用的是 C/D level（implement skill 定义），不需要 "scope-extending" 这个悬空概念
→ Consequence: 无方向变化，措辞精确化
→ Result: accepted — Fix 3 已更新

**[inferred: depth-issue] § Fix 2 L42 approved write set 批准来源**
"approved write set 和 todo write set 的关系没钉死；批准来源应显式绑定到 implement skill"
→ 同意。新措辞明确 "the implement skill permits narrowly scoped A/B-level additions to be appended to the current todo/write set without replanning"
→ Consequence: 无方向变化，定义完整化
→ Result: accepted — Fix 2 已更新

**[inferred: depth-issue] § Surface Scan tests skip 表述**
"Grep 0 matches 只证明无字符串断言，不能证明无行为覆盖，表述应更谨慎"
→ 同意。改为 "未发现直接依赖这些具体文案的测试断言；本轮不改 tests"
→ Consequence: 无方向变化
→ Result: accepted — Surface Scan 已更新

---

## Retrospective

- **Plan vs reality**: 完全匹配。三处文案替换，无意外发现。
- **Surprise**: 无。
- **Next time**: 协议层规则之间的交叉引用（如 write set 规则 vs implement skill Unexpected Discoveries）应该在首次编写时就建立一致性检查，而不是等审计发现。

---

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->
你把 L48 从“发现 omission 必须 stop”改成“发现 C/D 级 omission 才必须 stop”，这个大方向是对的，但措辞还不够精确。现在写成：

Discover scope-extending omission (C/D level) during implementation → MUST stop...

问题在于，“scope-extending omission” 和 “C/D level” 其实是两套分类语言。
如果以后有人读到这句，会有一个自然问题：
•	是不是所有 scope-extending omission 都属于 C/D？
•	A/B 级 omission 算不算 scope-extending？
•	这里真正起约束作用的是 “scope-extending” 还是 “C/D level”？

也就是说，这句现在的风险不是错，而是多加了一个可能造成解释分叉的限定词。

我建议收成更硬一点的版本，例如：

6. Discover a C/D-level omission during implementation → MUST stop, update plan.md, wait for human confirmation.

或者如果你一定想保留“scope”这个概念，也应该把主谓关系说死：

6. Discover an omission classified as C/D-level under the implement skill → MUST stop...

这样就不会出现“双重分类口径”。

我认为还需要再收一下的核心点

1. L42 新措辞对 “approved write set” 的定义还差半步

你现在写的是：

Only modify files in the approved write set. By default this is the plan-listed files. During implementation, narrowly scoped A/B-level additions ... may be appended to the todo write set...

这比原版强很多，但还有一个小口子：

“approved write set” 和 “todo write set” 的关系没有完全钉死。

现在用户读下来可能会问：
•	approved write set 是不是等于当前 todo write set？
•	A/B 追加后，是自动变成 approved，还是只是临时允许？
•	谁批准这个追加——skill 规则自动批准，还是 AI 自己判断？

按你计划里的意图，答案其实是：
A/B 级追加属于 implement skill 预授权范围，因此可直接并入当前 todo/write set；更大范围才需要回 plan。

那我建议把这层关系再钉清楚一点，不然“approved write set”会显得比真实机制更强、但又没解释批准来源。

更稳的版本像这样：

4. Only modify files in the approved write set. By default, the approved write set is the plan-listed files. During implementation, the implement skill permits narrowly scoped A/B-level additions to be appended to the current todo/write set without replanning; broader additions require updating the plan first.

这比现在这句更完整，因为“批准来源”被明确绑定到了 implement skill，不再像是一个悬空概念。

2. “无相关断言，tests skip” 这个判断基本合理，但表述可以更谨慎

你在 Surface Scan 里写：
•	tests/ | skip | 无相关断言 [CODE] Grep → 0 matches

这个结论大概率是对的，但这里最好别写得太满。因为“grep 0 matches”只能证明没有显式字符串断言，不能证明没有行为级覆盖。
更稳一点的说法应该是：
•	未发现直接依赖这些具体文案的测试断言；本轮不改 tests


<!-- BATON:GO -->

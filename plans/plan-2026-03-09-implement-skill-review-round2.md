# baton-implement Review Round 2 分析

**来源**: 用户提供的第二轮评审反馈
**分析方法**: 逐条验证评审发现的准确性，评估优先级，判断修复方案

---

## Reviewer 肯定的改进（无需行动，记录共识）

Reviewer 确认 4 项改进有效：触发词收紧、section hierarchy、tiered verification、A/B/C/D 分类。这与实施意图一致，不再展开。

---

## 逐条分析残余问题

### Issue R2-1: Iron Law 与 B 类规则冲突

**Review 原文**: Iron Law 说 "ONLY MODIFY FILES LISTED IN THE PLAN OR THEIR EXPLICITLY EXPECTED DERIVED ARTIFACTS"，但 B 类说 "Continue. Append the file to the todo's write set"。B 类文件既不在 plan 中，也不是 derived artifact，所以按 Iron Law 不能改，按 B 类可以改。

**验证**:
- [CODE] `SKILL.md:15` — Iron Law 限定 plan 文件 + 显式预期派生产物
- [CODE] `SKILL.md:161-163` — B 类允许继续修改后追加记录
- [CODE] `SKILL.md:19` — Section hierarchy 声明 Iron Law = hard gates (violation = stop)

**判断**: ✅ **准确发现。这是真实的规范冲突。**

Iron Law 是 hard gate，B 类是 exception handling。当前文本中 B 类实际上构成了对 Iron Law 的隐式覆盖，但没有显式声明这种关系。严谨的 agent 会遇到决策冲突。

**Reviewer 方案 A vs B 评估**:

| 方案 | 内容 | 优点 | 缺点 |
|------|------|------|------|
| A: Iron Law 加例外 | 在 Iron Law 中显式纳入 B 类 | 一处定义，无歧义 | Iron Law 行变长，可读性下降 |
| B: B 类要求先改 plan | "Update plan.md, then continue without waiting" | 保持 Iron Law 纯净 | 增加执行步骤，"不等人确认就继续"是新的模糊地带 |

**我的判断**: 方案 A 更优，但不建议把完整 B 类描述塞进 Iron Law 行。更好的做法：

1. Iron Law 第二行改为: `ONLY MODIFY FILES IN THE APPROVED WRITE SET (SEE UNEXPECTED DISCOVERIES FOR SCOPE)`
2. 在 Unexpected Discoveries 开头加一句总则: `Levels A and B are pre-authorized exceptions to Iron Law #2. Levels C and D require stopping.`

这样 Iron Law 保持简洁，同时显式声明了 A/B 级的授权关系，消除冲突。

**优先级**: P1 — 不修会导致不同 agent 执行分叉

---

### Issue R2-2: "3 failures" 仍未定义

**Review 原文**: 仍然没有定义 same approach / fail / 一次。

**验证**:
- [CODE] `workflow.md:41-43` — **已添加** failure chain 定义
- [CODE] `workflow-full.md:41-43` — **已同步**
- [CODE] `SKILL.md:183` — skill 中只写 "Same approach fails 3x → MUST stop and report"，**未包含** workflow.md 中的定义

**判断**: ⚠️ **部分准确。定义已存在于 workflow.md，但 reviewer 看的是 SKILL.md。**

Failure chain 定义在本轮 Todo #6 中已添加到 `workflow.md:41-43`:
> *Failure chain definition: same root cause = same chain. Parameter tweaks or minor path adjustments do not count as a new approach. Only a fundamentally different strategy (different algorithm, different API, different architecture) counts as new.*

问题是 SKILL.md 的 Action Boundaries Reminder 没有引用或复述这个定义。Reviewer 只看了 SKILL.md，所以认为问题未解决。

**建议**: 在 SKILL.md Action Boundaries #3 后加引用即可，不需要重复定义：

```
3. Same approach fails 3x → MUST stop and report (see workflow.md for failure chain definition)
```

或者直接内联一句精简版:

```
3. Same approach fails 3x → MUST stop and report. Same root cause = same chain; only a fundamentally different strategy counts as new.
```

**优先级**: P2 — 定义已存在，只是 skill 层缺引用

---

### Issue R2-3: generate todolist 的职责边界

**Review 原文**: implement skill 同时负责进入实施态、生成 todo、执行 todo、retrospective、session handoff，本质是 orchestrator。

**验证**:
- [CODE] `workflow.md:22-23` — Flow 定义: `BATON:GO → generate todolist → implement`
- [CODE] `SKILL.md:37-50` — Step 1: Generate Todolist
- [CODE] `baton-plan SKILL.md:174-187` — baton-plan 的 Todolist Format 已改为引用 baton-implement

**判断**: ⚠️ **观察准确，但 reviewer 自己也说 "不是 blocker"**

在 baton 架构中，generate todolist 明确属于 BATON:GO 之后的动作（workflow.md:38）。baton-plan 负责 plan 契约，baton-implement 负责从 approved plan 到 code 的全流程。这是有意设计。

Reviewer 说 "如果 baton-plan 已经很强，implement 再带 generate todolist 会有点职责重叠"——但 baton-plan 的 Todolist Format 部分已在本轮 Todo #5 中改为引用 baton-implement，单一定义权已经明确在 implement 侧。

**建议**: 不做修改。当前职责分工与 workflow.md 的 Flow 定义一致。

**优先级**: 不采纳（已论证过，架构选择而非缺陷）

---

### Issue R2-4: resume mid-session 条件不够形式化

**Review 原文**: "resuming implementation mid-session" 对 agent 不够可判定。需要明确 resume 的触发条件。

**验证**:
- [CODE] `SKILL.md:6-7` — description 只说 "Also use when resuming implementation mid-session"
- [CODE] `SKILL.md:172-175` — Session Handoff 描述了停止时的行为（写 Lessons Learned），但没有描述恢复时的判断条件

**判断**: ✅ **准确发现。缺少形式化的 resume 判定条件。**

Reviewer 提出的三条判定规则合理：
1. plan.md 含 BATON:GO + 有未完成的 todo items
2. 上次 session 以 `## Lessons Learned` / blocked 状态结束
3. 用户显式要求继续实施

这三条覆盖了 resume 的全部合理场景，且是可机器判定的（grep BATON:GO + grep unchecked todo + grep Lessons Learned）。

**建议**: 在 When to Use 部分补充 resume 条件。

**优先级**: P2 — 改善恢复稳定性，不影响正常首次执行

---

### Issue R2-5: completion record 缺少最小结构

**Review 原文**: "怎么记"不够结构化。不同 agent/session 记录风格不一致，降低审计价值。

**验证**:
- [CODE] `SKILL.md:48` — 要求 `- [x] ✅` 格式
- [CODE] `SKILL.md:57` — "Mark complete — only after steps 3 and 4 pass"
- 没有定义 completion note 的字段模板

**判断**: ✅ **准确发现。当前只要求"标记完成"，不要求记录什么。**

Reviewer 建议的最小字段集（Status / Files changed / Verification run / Result / Notes）有道理，但需要权衡：
- 7 个 todo 项 × 5 个字段 = 35 行记录开销
- 对 Trivial/Small 任务过重
- 对 Medium/Large 有审计价值

**建议**: 添加为可选的 completion record 模板，建议用于 Medium/Large 任务，不强制用于 Trivial/Small。与 complexity-based scope 精神一致。

**优先级**: P3 — 打磨型改进，不影响执行正确性

---

## 优先级总结

### P1 — 必须修（规范冲突）
1. **消除 Iron Law 与 B 类冲突** — 在 Unexpected Discoveries 开头声明 A/B 是 Iron Law #2 的预授权例外

### P2 — 应该修（提升一致性）
2. **SKILL.md 中引用 failure chain 定义** — 已存在于 workflow.md，skill 层缺引用
3. **形式化 resume 条件** — 在 When to Use 中补充三条判定规则

### P3 — 可选修（打磨）
4. **completion record 最小模板** — 建议用于 Medium/Large，不强制

### 不采纳
5. **拆分 generate todolist 到 baton-plan** — 与 workflow.md Flow 定义矛盾，且已在 Todo #5 中明确了单一定义权

---

## Reviewer 评分校准

Reviewer 给出 9.0/10。分项：
- 治理能力 9.3 ✅ 同意
- 工程可执行性 8.8 ⚠️ 合理，但 Iron Law 与 B 类冲突修复后应升至 9.1
- 规范清晰度 9.0 ⚠️ 合理，resume 条件形式化后应升至 9.2

**修复 P1+P2 后预期评分**: 9.2/10

---

## Todo

- [x] ✅ 1. Change: 在 Unexpected Discoveries 开头加授权总则，声明 A/B 级是 Iron Law #2 的预授权例外、C/D 级需要停止。同时将 Iron Law 第二行中 "OR THEIR EXPLICITLY EXPECTED DERIVED ARTIFACTS" 精简——derived artifacts 现在由 A 类覆盖，Iron Law 只需指向 Unexpected Discoveries 的 scope 定义 | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: 重读 Iron Law + Unexpected Discoveries 两处，确认无冲突——Iron Law 不再声明完整 scope，而是引用 Unexpected Discoveries 的分级授权 | Deps: none | Artifacts: none

- [x] ✅ 2. Change: 在 Action Boundaries #3 后内联一句 failure chain 精简定义: "Same root cause = same chain; only a fundamentally different strategy counts as new." | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: grep "failure chain\|root cause\|different strategy" 确认 SKILL.md 中有定义；确认与 workflow.md:41-43 的完整定义不矛盾 | Deps: none | Artifacts: none

- [x] ✅ 3. Change: 在 When to Use 部分新增 resume 判定条件: (1) plan.md 含 BATON:GO + 有 unchecked todo items (2) plan.md 含 `## Lessons Learned` 表明上次 session 中断 (3) 用户显式要求继续实施 | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: 重读 When to Use，确认 resume 条件完整且与 Session Handoff 对应 | Deps: none | Artifacts: none

- [x] ✅ 4. Change: 在 Step 2 "Mark complete" 后添加可选的 completion record 模板，标注为 "Recommended for Medium/Large tasks": Status / Files changed / Verification command+result / Deviations from plan | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: 重读 Step 2，确认模板存在且标注为可选；确认不与 Self-Check Triggers 重复 | Deps: none | Artifacts: none

- [x] ✅ 5. Change: 更新 test-workflow-consistency.sh 中的 derived artifact guardrail 断言以匹配新的 Iron Law 措辞 (如果 #1 改变了 Iron Law 文本) | Files: `tests/test-workflow-consistency.sh` | Verify: 运行 `bash tests/test-workflow-consistency.sh` — 全部 CONSISTENT | Deps: #1 | Artifacts: none

## Retrospective

**Plan vs reality**:
- Plan predicted 5 items, implemented 5. No scope surprises this round.
- The Iron Law refactoring (Todo #1) required cascading updates to Red Flags and Action Boundaries, same pattern as round 1. This time it was anticipated.

**Key design decision**: Iron Law #2 now delegates scope definition to Unexpected Discoveries rather than trying to enumerate all cases inline. This is a structural improvement — it means future scope changes (e.g. adding a new discovery level) only need one edit, not 4 synchronized references.

**Two-round cumulative result**:
- Round 1: 7 items — rewrote discovery classification, tiered verification, trigger tightening, derived artifacts, dedup, failure chain, hierarchy
- Round 2: 5 items — resolved Iron Law conflict, failure chain visibility, resume formalization, completion records, test sync
- Test suite: ALL CONSISTENT across both rounds

**What would be different next time**: When adding a new concept (like "approved write set") that replaces an old one, grep all test files for the old concept *before* implementing, not after.

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- BATON:GO -->
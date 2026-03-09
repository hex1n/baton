# baton-implement Skill Review 逐条分析

**来源**: `baton-plan-implement-skill-review.md` (baton-implement 部分)
**分析方法**: 将 review 中每条建议与实际代码交叉验证，区分"准确发现"、"误读架构"和"已通过其他途径解决"

---

## 总体评估

Review 整体质量高，评分 8.3/10 是合理的。reviewer 准确抓住了 baton-implement 的核心价值（变更治理而非代码生成能力），也正确识别了若干工程可执行性问题。

但 review 存在 **三处系统性误读**：
1. 将 skill 层面的指导性规则等同于 hook 层面的硬性强制
2. 低估了 workflow.md 作为权威层的角色（部分规则源自 workflow.md 而非 skill 自定义）
3. 未考虑 baton-plan skill 已完成的复杂度分层改进对上下游协同的影响

---

## 逐条分析

### Issue #1: 触发条件过宽（"开始"歧义）

**Review 原文**: "开始" 在中文语境中过于宽泛，可能指研究、规划等，不是 implementation intent 的充分信号。

**验证**:
- [CODE] `SKILL.md:5` — description 确实包含 `"开始"`
- [CODE] `SKILL.md:24-26` — When to Use 部分有更严格的前置条件：需要 `BATON:GO` 存在

**判断**: ✅ **准确发现，值得修复**

但 reviewer 高估了风险。实际执行中触发条件是 **AND 逻辑**：skill description 中明确写了 `plan.md contains BATON:GO AND the user says...`，不是 OR。没有 BATON:GO 的情况下单独说"开始"不会进入实施态。

**但仍建议修复**：description 中的触发词列表影响 skill 选择器的模式匹配，"开始"确实会导致不必要的 skill 加载。收紧为 "开始实施" / "开始开发" / "按 plan 执行" 即可。

**优先级**: P2（改善，非阻塞）

---

### Issue #2: "Only modify files listed in the plan" 过于刚性

**Review 原文**: 真实代码改动有主改动、派生文件、邻接文件三类，skill 只适配第一类，导致频繁停机。

**验证**:
- [CODE] `SKILL.md:15` — Iron Law: `ONLY MODIFY FILES LISTED IN THE PLAN`
- [CODE] `SKILL.md:134` — Red Flags: "These generated files don't count" → "No global exemption"
- [CODE] `SKILL.md:149-155` — Unexpected Discoveries: Derived artifacts 已有条件处理逻辑
- [CODE] `SKILL.md:171` — Action Boundaries #5: "Derived artifacts are allowed only when explicitly listed"
- [CODE] `write-lock.sh:56-58` — **hook 只检查 markdown 豁免和 BATON:GO 存在，不检查文件清单**

**关键发现**: reviewer 混淆了两个层面：
1. **write-lock.sh (hook 层)** — 只验证 BATON:GO 存在与否，**不做文件清单校验**
2. **SKILL.md (指导层)** — 要求只改 plan 中列出的文件

这意味着文件边界约束是 **软约束**（依赖 agent 自律），不是硬约束（hook 不会拦截）。Review 所描述的"卡死"场景在当前架构中不会发生——agent 技术上可以写任何文件，只是 skill 指导它不要。

**判断**: ⚠️ **部分准确，但高估了影响**

Reviewer 提出的三层授权模型（Explicit write set / Pre-authorized derived artifacts / Adjacent integration files）理念是好的，但 baton-implement 已经在 Unexpected Discoveries 部分做了分类处理。当前架构的真实问题是：

- todolist 格式已要求 `Derived artifacts` 字段 (SKILL.md:43)
- plan 阶段已要求列出 derived artifacts (baton-plan SKILL.md:82-84)
- 但 Unexpected Discoveries 的分类维度确实可以改进（见 Issue #3）

**建议**: 不需要三层授权模型那么重的改造。更务实的做法是：
1. 在 Iron Law 中将 "ONLY MODIFY FILES LISTED IN THE PLAN" 软化为 "ONLY MODIFY FILES LISTED IN THE PLAN OR THEIR EXPLICITLY EXPECTED DERIVED ARTIFACTS"
2. 保持 Unexpected Discoveries 的停机逻辑不变

**优先级**: P2

---

### Issue #3: Unexpected Discoveries 分类不够工程化

**Review 原文**: 当前按表面类型分（Small addition / Derived artifact / Design change / Stopping），应改为按影响范围和边界变化分四级（Local completion aid / Adjacent integration / Scope extension / Design change）。

**验证**:
- [CODE] `SKILL.md:145-161` — 当前四类分类

**判断**: ✅ **准确发现，reviewer 的替代方案更优**

当前分类混了两个维度：变化规模（Small addition）和变化性质（Design direction change），且 "Stopping mid-implementation" 不属于 discovery 分类，而是执行状态。

Reviewer 提出的 A/B/C/D 分级有明确的处理规则：
- A (Local completion aid): 继续+记录
- B (Adjacent integration): 继续+追加 write set
- C (Scope extension): 停+更新 plan
- D (Design change): 停+退回 annotation

这比当前分类更清晰，agent 判断成本更低。

**但需注意**: "Stopping mid-implementation" 应保留，只是从 discovery 分类中移出，作为独立的 Session Handoff 规则（当前已在 workflow.md:69 有对应）。

**优先级**: P1（结构改进，直接提升可执行性）

---

### Issue #4: "3 failures must stop" 定义不清

**Review 原文**: 缺少 "同一种 approach fail 3 次" 的精确定义——是同一命令、同一思路、同一测试、还是同一 patch？

**验证**:
- [CODE] `SKILL.md:132` — "3 failures → MUST stop and report to human"
- [CODE] `SKILL.md:169` — Action Boundaries #3: 同上
- [CODE] `workflow.md:40` — "Same approach fails 3x → MUST stop and report to human"

**关键发现**: 这条规则源自 **workflow.md**（权威层），不是 baton-implement 自己发明的。SKILL.md 只是复述了 workflow 层的规则。

**判断**: ⚠️ **发现准确，但修复位置应在 workflow.md 而非 skill**

Reviewer 建议的 failure chain 定义（同根因 = 同 chain / 参数调整不算新 approach / 明显更换策略才算新 approach）是合理的。但这属于 workflow 层面的规则细化，不应在 implement skill 中单独定义，否则会造成规则层级混乱。

**建议**: 在 workflow.md 的 Action Boundaries #5 中补充 failure chain 定义，skill 层面保持引用即可。

**优先级**: P3（workflow 层面改进，不影响 implement skill 本身）

---

### Issue #5: "生成 todolist" 与 "实施" 职责绑定

**Review 原文**: baton-implement 同时负责进入实施态、生成 todo、执行 todo、收尾 retrospective，已是 orchestration skill。与 baton-plan 存在职责重叠。

**验证**:
- [CODE] `SKILL.md:33-46` — Step 1: Generate Todolist（在 implement 中）
- [CODE] `baton-plan SKILL.md:174-196` — baton-plan 也定义了 Todolist Format
- [CODE] `workflow.md:38` — "Todolist required before implementation. Append `## Todo` only after human says 'generate todolist'."
- [CODE] `workflow.md:22-23` — Flow 明确: `BATON:GO → generate todolist → implement`

**关键发现**: workflow.md 的 Flow 定义把 "generate todolist" 放在 BATON:GO 之后、implement 之前。这意味着 todolist 生成 **就是** implement 阶段的第一步，不是 plan 阶段的产物。

但 baton-plan 的 Todolist Format 部分（SKILL.md:174-196）与 baton-implement 的 Step 1（SKILL.md:33-46）确实存在 **重复定义**：两处都规定了 todolist 的格式和字段要求。

**判断**: ⚠️ **部分准确——存在重复定义，但不存在职责错位**

Reviewer 说 "generate todolist 本质上是 planning 的细化" 是对 baton workflow 架构的误读。在 baton 中，todolist 是从 approved plan 到 code 的执行桥接，明确属于 implement 阶段。baton-plan 中出现 todolist format 是为了让规划者预知实现者需要什么，是前向参考而非职责重叠。

**建议**: 消除重复——baton-plan 中的 Todolist Format 改为引用 baton-implement 的格式定义，避免两处维护。

**优先级**: P2

---

### Issue #6: "Run full test suite" 不现实

**Review 原文**: 很多项目 full suite 很慢/很脆/依赖外部环境/本地不可运行。硬要求会导致机械执行失败或假装完成。

**验证**:
- [CODE] `SKILL.md:72` — "Run full test suite, record results in plan.md"

**判断**: ✅ **准确发现，建议采纳分层验证**

当前写法确实过于绝对。Reviewer 提出的分层验证方案合理：
1. 必跑：todo 指定验证 + 受影响范围测试
2. 条件允许时：package/module 级测试
3. 可运行时：full suite
4. 不可运行时：记录原因和未覆盖风险

这与 baton-plan 中 Complexity-Based Scope 的分层精神一致。

**优先级**: P1

---

### Issue #7: 文档重复且无层级

**Review 原文**: "计划是合同"、"不在 plan 里的不能做"、"漂移就停"、"先验证再勾选" 分别出现在 Iron Law / Process / Self-Check / Red Flags / Common Rationalizations / Action Boundaries 中，重复无层级。

**验证**: 逐条检查重复情况：

| 原则 | Iron Law | Process | Self-Check | Red Flags | Common Rationalizations | Action Boundaries |
|------|----------|---------|------------|-----------|------------------------|-------------------|
| 只改 plan 中文件 | ✅ L15 | — | — | ✅ L128 | ✅ L140,143 | ✅ L168 |
| 偏离就停 | ✅ L16 | — | ✅ L86-87 | ✅ L131 | ✅ L142 | ✅ L170 |
| 先验证再标完成 | — | ✅ L56-57 | ✅ L108-109 | ✅ L130 | — | — |
| 计划是合同 | ✅ L14-15 | ✅ L19 | — | ✅ L128 | — | ✅ L167 |

**判断**: ✅ **准确发现，但 reviewer 低估了重复的功能价值**

在 AI prompt engineering 中，关键规则的多角度重复（声明式 → 触发式 → 反面教材）是有意设计，不是冗余。但 reviewer 说得对：**重复没有层级化**。Agent 无法快速区分 "硬约束" vs "指导建议" vs "反面示例"。

**建议**: 不采纳 reviewer 的四层重构（Hard gates / Execution protocol / Drift detection / Exception handling），因为当前结构的阅读流（Iron Law → Process → Self-Check → Red Flags）已经形成自然的 "原则 → 流程 → 检查 → 警告" 递进。

但可以在 Iron Law 后加一句明确层级:
```
Iron Law = hard gates (violation = stop).
Process = execution protocol (follow sequentially).
Self-Check = drift detection (run after each action).
Red Flags = pattern recognition (if you think this, stop).
```

**优先级**: P3

---

### Issue #8（隐含）: 上游 plan 质量决定 implement 效果

**Review 原文**: 如果 baton-plan 没有强制包含 write set、verification、derived artifacts、dependency graph，implement skill 会频繁停机。

**验证**:
- [CODE] `baton-plan SKILL.md:82-84` — 已要求列出 derived artifacts
- [CODE] `baton-plan SKILL.md:185-190` — Todolist Format 已包含 Files/Verify/Deps/Artifacts 字段
- [CODE] `baton-plan SKILL.md:88-114` — Surface Scan 已要求做影响面分析

**判断**: ❌ **已被解决**

baton-plan 当前版本（经过之前的 review 迭代改进后）已强制包含 reviewer 要求的所有上游产物。这个问题在 baton-plan skill 的改进轮次中已被覆盖。

---

## 已被其他工作覆盖的建议

| Review 建议 | 已有覆盖 |
|-------------|---------|
| 显式复杂度分层 | baton-plan SKILL.md:35-44 已添加 Complexity-Based Scope |
| Plan 应包含 write set | baton-plan Todolist Format 已要求 Files 字段 |
| Plan 应包含 derived artifacts | baton-plan SKILL.md:82-84 已强制要求 |
| 上游 plan 质量保障 | baton-plan 已经过完整 review 迭代 |

---

## 优先级排序

### P1 — 结构性改进（直接提升可执行性）

1. **重写 Unexpected Discoveries 分类** — 采纳 reviewer 的四级方案（Local completion aid / Adjacent integration / Scope extension / Design change），将 "Stopping mid-implementation" 移出作为独立规则
2. **将 "Run full test suite" 改为分层验证** — 必跑项 + 条件项 + 可选项 + 不可运行时的记录要求

### P2 — 改善型修复

3. **收紧触发词** — 从 description 中删除 "开始"，替换为 "开始实施" / "开始开发"
4. **软化 Iron Law 文件边界** — 补充 "or their explicitly expected derived artifacts"
5. **消除 todolist 格式重复定义** — baton-plan 中的 Todolist Format 改为引用 baton-implement

### P3 — 打磨型改进

6. **在 workflow.md 中补充 failure chain 定义** — 不在 skill 层修改
7. **在 Iron Law 后添加层级声明** — 明确各 section 的约束强度

### 不采纳

| Review 建议 | 不采纳原因 |
|-------------|-----------|
| 三层文件授权模型 | 过重。当前 Unexpected Discoveries + derived artifacts 字段已覆盖 80% 场景，只需微调 |
| 四层文档重构 | 当前结构的递进逻辑（原则→流程→检查→警告）已合理，重构 ROI 不足 |
| 拆分 todolist 生成到 baton-plan | 违反 workflow.md 定义的阶段边界 |

---

## 对 Review 评分的评价

Reviewer 给出 8.3/10，各维度：
- 理念与治理能力：9.1/10 ✅ 同意
- 工程可执行性：7.6/10 ⚠️ 偏低——hook 层面实际不做文件清单校验，"卡死"风险被高估
- 与上游 planning skill 协同性：8.0/10 ⚠️ 偏低——baton-plan 已完成的改进未被 reviewer 考虑

**修正评分建议**: 综合 8.5/10，工程可执行性 8.0/10，协同性 8.5/10

---

## Todo

- [x] ✅ 1. Change: Rewrite Unexpected Discoveries section — replace 4 type-based categories (Small addition / Derived artifact / Design change / Stopping) with 4 impact-based levels (A: Local completion aid — continue+record / B: Adjacent integration — continue+append write set / C: Scope extension — stop+update plan / D: Design change — stop+roll back to annotation). Move "Stopping mid-implementation" out as a standalone Session Handoff rule after the discovery section. | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: re-read section, confirm each level has clear condition + action + example; confirm "Stopping" is separate | Deps: none | Artifacts: none

- [x] ✅ 2. Change: Replace "Run full test suite" in Step 4 Completion with tiered verification — Required: todo-specified verification + affected-scope tests; Conditional: package/module-level tests if available; Optional: full suite if runnable; If not runnable: record reason and uncovered risk | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: re-read Step 4, confirm no unconditional "full test suite" remains; confirm tiered structure is clear | Deps: none | Artifacts: none

- [x] ✅ 3. Change: In frontmatter description, replace `"开始"` with `"开始实施"` and add `"开始开发"`. Keep all other trigger words unchanged | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: grep for standalone "开始" in description — should only appear as part of compound phrases | Deps: none | Artifacts: none

- [x] ✅ 4. Change: Soften Iron Law line 2 from `ONLY MODIFY FILES LISTED IN THE PLAN` to `ONLY MODIFY FILES LISTED IN THE PLAN OR THEIR EXPLICITLY EXPECTED DERIVED ARTIFACTS`. Update matching Red Flags entry and Action Boundaries #2 for consistency | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: grep for "ONLY MODIFY" and "Only modify files" — all instances should include the derived artifacts clause | Deps: none | Artifacts: none

- [x] ✅ 5. Change: In baton-plan SKILL.md, replace the Todolist Format section's inline field definitions with a reference to baton-implement skill, keeping only the format example. Add a one-line note: "Field definitions (Change, Files, Verification, Dependencies, Derived artifacts) are specified in baton-implement." | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: re-read baton-plan Todolist Format section — should have format example + reference, no duplicated field definitions | Deps: none | Artifacts: none

- [x] ✅ 6. Change: Add failure chain definition to workflow.md Action Boundaries #5 (after "Same approach fails 3x"): define same root cause = same failure chain; parameter tweaks ≠ new approach; only a fundamentally different strategy counts as a new approach | Files: `.baton/workflow.md` | Verify: re-read Action Boundaries #5, confirm definition is present and unambiguous | Deps: none | Artifacts: none

- [x] ✅ 7. Change: Add a 4-line section hierarchy declaration immediately after the Iron Law code block, before "The plan is the contract" paragraph: Iron Law = hard gates / Process = execution protocol / Self-Check = drift detection / Red Flags = pattern recognition | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: re-read the section after Iron Law, confirm hierarchy is concise (≤4 lines) and doesn't duplicate existing text | Deps: #4 (Iron Law text changed) | Artifacts: none

## Retrospective

**What the plan got wrong**:
- Plan didn't anticipate that removing the old "Derived artifact changed" category would break a test assertion in `test-workflow-consistency.sh` (line 261) that greps for that exact string.
- Plan didn't list `workflow-full.md` as a file needing the failure chain definition (it mirrors workflow.md's Action Boundaries).
- Plan didn't list `test-workflow-consistency.sh` as needing an update for the changed guardrail wording.

**What surprised during implementation**:
- Removing Action Boundary #5 (derived artifacts rule) caused a numbering gap (4→6) that needed manual fix.
- The consistency test suite caught drift immediately — good validation infrastructure.

**What to research differently next time**:
- Before modifying any section in baton-implement, grep for exact strings from that section across the test suite to pre-identify assertion dependencies.
- Check workflow-full.md whenever workflow.md is changed — they must stay synchronized.

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
 <!-- BATON:GO -->
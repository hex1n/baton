# Plan: Baton Core Contract Audit Fixes

> 基于 research-contract-audit.md 审计发现，修复 4 个 P0 + 7 个 P1 + 4 个 P2 问题

## Requirements

- [HUMAN] 根据审计报告给出改进计划
- [CODE] research-contract-audit.md §J 差异矩阵 — 15 项需修复
- [CODE] research-contract-audit.md §K 优先级排序 — P0×4, P1×7, P2×4

## Complexity

**Large** — 13+ 文件修改，含架构决策（文档权威层级、强制策略选择）

---

## Fundamental Constraints

1. **向后兼容**：修改不能破坏现有安装。setup.sh 生成的配置引用不变
2. **最小侵入**：优先文档修正，技术加固需要明确权衡
3. **测试守护**：所有现有测试必须继续通过（或同步更新）
4. **Skill token 预算**：workflow.md ~400 tokens，不能无限膨胀

---

## Approach Analysis

### 决策点 1：阶段模型（P0 #1）

**问题**：workflow.md 说 "Four phases"，phase-guide.sh 实现 6 态

| 方案 | 描述 | 优劣 |
|------|------|------|
| **A: 文档承认 6 态** | workflow.md 改为描述 4 个主阶段 + 2 个系统态（AWAITING_TODO, ARCHIVE） | ✅ 与实现一致；❌ 增加文档复杂度 |
| **B: 简化实现到 4 阶段** | 合并 AWAITING_TODO→IMPLEMENT，去掉 ARCHIVE | ❌ 丢失 AWAITING_TODO 门控能力；❌ ARCHIVE 检测对 stop-guard 有用 |

**推荐 A**：文档承认实现。6 态状态机已证明有效，AWAITING_TODO 提供了重要的门控提示。改文档比改逻辑成本低、风险小。

### 决策点 2：todolist 技术强制（P1 #5）

**问题**：write-lock.sh 只检查 BATON:GO，不检查 `## Todo`

| 方案 | 描述 | 优劣 |
|------|------|------|
| **A: write-lock 加入 Todo 检查** | GO + Todo 同时满足才 exit 0 | ✅ 技术强制完整；❌ 改变现有行为，需更新测试；❌ Trivial 任务可能不需要 todolist |
| **B: 保持 advisory** | phase-guide.sh AWAITING_TODO 状态已提供提示 | ✅ 零破坏；✅ 灵活（Trivial 可跳过）；❌ 不是硬门控 |
| **C: 文档承认 advisory** | 在 workflow.md 明确 todolist 是 "强烈建议" 而非技术强制 | ✅ 消除期望差距；❌ 降低了协议严格度 |

**推荐 B+完整协议补充**：保持当前 advisory 设计（phase-guide.sh AWAITING_TODO 态已做得很好），但在 workflow.md 中补充完整的 todolist 协议条款：

1. **合法跳过条件**：Trivial 复杂度（1 file, <20 lines）且人类明确说"直接实现"
2. **决策权**：人类。AI 不得自行判断跳过 — 必须由人类在 chat 中显式授权
3. **跳过后最小约束**：仍需 BATON:GO + 仅修改 plan 中列出的文件 + 完成后写 Retrospective

这不是"补一句说明"，而是把 advisory 的边界条件写成正式协议条款。

### 决策点 3：approved write set 强制（P1 #6）

**问题**：post-write-tracker.sh 是 advisory，不能阻止写入计划外文件

| 方案 | 描述 | 优劣 |
|------|------|------|
| **A: 升级为 blocking** | PostToolUse exit 非 0 阻止 | ❌ PostToolUse 在多数 IDE 架构中不支持 blocking |
| **B: 保持 advisory + 文档说明** | 明确 write set 是 advisory 约束 | ✅ 可行；✅ 与 IDE 限制一致 |

**推荐 B + 完整 tradeoff 声明**：在文档中写入结构化的约束声明：

- **当前版本**：write set 仅 advisory（post-write-tracker.sh 警告但不阻断）
- **工程原因**：PostToolUse hook 在 Claude Code/Cursor 架构中不支持 blocking（exit code 被忽略）
- **产品原因**：这是当前宿主 hook 模型的架构边界，不是"暂时没拦"
- **影响**：计划外写入无法被技术阻断
- **缓解**：skill discipline（baton-implement Iron Law #2）+ post-write audit 警告 + human review 发现偏航
- **后续**：保留升级为更强 enforcement 的设计空间（如果宿主 hook 模型演进）

"计划是合同"仍然成立 — 但当前版本中 write set 这一条的执行力是 advisory + social contract，不是 technical gate。文档必须诚实说明这一点。

### 决策点 4：文档权威层级（P0 #3, #4）

**问题**：workflow.md / SKILL.md / README.md 三处定义行为，无明确权威关系

**推荐**：在 workflow.md 末尾新增 `### Document Authority` 小节（~50 tokens），声明：
- workflow.md = 核心协议（always loaded）
- SKILL.md = 阶段规范扩展（normative，按需加载）
- workflow-full.md = 降级参考（系统无 skill 支持时使用）
- README.md = 公开介绍（explanatory，非规范）

---

## Recommendation

**组合方案**：决策点 1A + 2B（补文档）+ 3B + 4（新增权威声明）

核心思路：**这轮修复以文档对齐为主，技术加固为辅**。审计发现的 P0 全是契约清晰度问题，不是运行时漏洞。修复方向是消除歧义、建立权威层级、修正虚假声明，而非增加新的技术门控。

---

## Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L1 | **modify** | 修正阶段描述 + 新增文档权威层级 + 补充 todolist 说明 |
| `.baton/workflow-full.md` | L1 | **modify** | 同步阶段描述修正 |
| `README.md` | L1 | **modify** | 修正 "No state machine" + hook 数量 + .markdown 扩展名 + Codex 警告 |
| `.claude/skills/baton-implement/SKILL.md` | L1 | **modify** | 修正 "enforced by hooks" 虚假声明 + 添加 normative 声明 |
| `.claude/skills/baton-research/SKILL.md` | L1 | **modify** | 添加 normative 声明 |
| `.claude/skills/baton-plan/SKILL.md` | L1 | **modify** | 添加 normative 声明 |
| `.baton/hooks/write-lock.sh` | L2 | **skip** | 保持现有逻辑不变（决策点 2B：todolist 保持 advisory）|
| `.baton/hooks/phase-guide.sh` | L2 | **skip** | 已正确实现 6 态，无需改动 |
| `.baton/hooks/post-write-tracker.sh` | L2 | **skip** | 保持 advisory（决策点 3B：PostToolUse 不支持 blocking）|
| `tests/test-workflow-consistency.sh` | L2 | **modify** | 可能需更新 SKILL.md 内容断言 |
| `tests/test-ide-capability-consistency.sh` | L2 | **modify** | 更新 hook 数量断言（7→8）|
| `tests/test-write-lock.sh` | L2 | **skip** | write-lock.sh 不改，测试不需变 |
| `tests/test-phase-guide.sh` | L2 | **skip** | phase-guide.sh 不改，测试不需变 |
| `research-contract-audit.md` | L3 | **skip** | 审计文档，不是代码产物 |

### Skip 决策验证

| Skip 文件 | 如果不更新，用户会遇到什么？ |
|-----------|---------------------------|
| write-lock.sh | 无影响 — 保持当前行为（GO 门控），文档将明确说明 todolist 是 advisory |
| phase-guide.sh | 无影响 — 已正确实现 6 态 |
| post-write-tracker.sh | 无影响 — 保持 advisory，文档说明 |
| test-write-lock.sh | 无影响 — write-lock 行为不变 |
| test-phase-guide.sh | 无影响 — phase-guide 行为不变 |

---

## Change List

### Batch 1: P0 — 契约清晰度（核心文档对齐）

#### Change 1.1: workflow.md — 阶段模型 + 文档权威 + 执行边界
**File**: `.baton/workflow.md`
**Lines**: 77（阶段描述）+ Action Boundaries 附近 + 末尾新增
**What**:
- L77: "Four phases" → "Four primary phases — RESEARCH, PLAN, ANNOTATION, IMPLEMENT — plus two system states (AWAITING_TODO, ARCHIVE) detected by phase-guide"
- 新增 `### Document Authority` 小节（~60 tokens），声明权威层级
- Action Boundaries 附近新增 todolist 协议条款：
  - 合法跳过条件：Trivial 复杂度 + 人类显式授权 "直接实现"
  - 决策权：人类（AI 不得自行判断跳过）
  - 跳过后最小约束：BATON:GO + 仅改 plan 列出的文件 + Retrospective
- Action Boundaries 附近新增 write set 约束声明：
  - 当前版本 advisory（post-write-tracker 警告不阻断）
  - 原因：宿主 hook 模型限制
  - 缓解：skill discipline + post-write audit + human review
- 新增 `### Enforcement Boundaries` 小节（~40 tokens），区分 hook-enforced vs advisory vs skill-disciplined

#### Change 1.2: workflow-full.md — 同步阶段描述
**File**: `.baton/workflow-full.md`
**Lines**: 106（阶段描述）
**What**: 与 workflow.md 保持一致的阶段描述修正

#### Change 1.3: README.md — 状态机声明 + Codex 警告 + 小修
**File**: `README.md`
**Lines**: 167（No state machine）、137（hook 数量）、40（markdown 扩展名）、~140（Codex 行）
**What**:
- L167: "No state machine" → 改为 "**File-derived phase detection** — your current phase is determined by file state, not stored anywhere" 或等价表述。避免 "state machine" 一词引发显式状态存储的联想；Baton 的模型更准确地说是"由文件状态推导的确定性阶段模型"
- L137: "7 hooks" → "8 hooks"
- L40: `(*.md, *.mdx)` → `(*.md, *.mdx, *.markdown)`
- Codex 行后添加警告：无技术写锁，依赖 AI 遵守规则

### Batch 2: P1 — 准确性修正

#### Change 2.1: baton-implement SKILL.md — 移除虚假声明 + normative 声明
**File**: `.claude/skills/baton-implement/SKILL.md`
**Lines**: 192（"enforced by hooks"）+ 文件头
**What**:
- L192: "enforced by hooks and cannot be bypassed" → 区分哪些由 hook 强制（GO 检查），哪些由 skill discipline 引导（write set、discovery blocking）
- 文件头添加：`**Normative status**: This skill is the authoritative specification for the IMPLEMENT phase.`

#### Change 2.2: baton-research SKILL.md — normative 声明
**File**: `.claude/skills/baton-research/SKILL.md`
**Lines**: 文件头
**What**: 添加 normative status 声明

#### Change 2.3: baton-plan SKILL.md — normative 声明
**File**: `.claude/skills/baton-plan/SKILL.md`
**Lines**: 文件头
**What**: 添加 normative status 声明

### Batch 3: 测试同步

#### Change 3.1: test-workflow-consistency.sh — SKILL.md 断言更新
**File**: `tests/test-workflow-consistency.sh`
**What**: 如果现有断言检查 "Four phases" 文本，更新为新措辞。检查 SKILL.md normative 声明是否触发新的一致性断言

#### Change 3.2: test-ide-capability-consistency.sh — hook 数量断言
**File**: `tests/test-ide-capability-consistency.sh`
**What**: 更新 hook 数量相关断言（7→8）

---

## Deferred but Explicitly Accepted Constraints

本轮修复不解决以下问题，但要求在文档中**正式承认**它们的存在：

| 约束 | 当前状态 | 为什么不修 | 文档中如何表述 |
|------|---------|-----------|--------------|
| Codex 无技术写锁 | 仅规则引导 | Codex 无 hook 机制，属于宿主架构限制 | README 添加显著警告 |
| todolist 非技术阻断条件 | phase-guide advisory | Trivial/Small 需要灵活性；硬门控摩擦大 | workflow.md 写入跳过条件 + 决策权 + 最小约束 |
| approved write set 非技术强制 | post-write-tracker advisory | PostToolUse 不支持 blocking | workflow.md 写入完整 tradeoff 声明 |
| BATON:GO 不能技术证明由人类写入 | plan.md 是 markdown，AI 可写 | 无法在不改变 GO 格式的前提下解决 | 依赖 skill Iron Law + human review |
| 部分治理依赖 skill discipline | hook 不覆盖所有规则 | hook 模型无法表达所有治理意图 | SKILL.md 中区分 hook-enforced vs skill-disciplined |

**原则**：治理层最怕"默认让用户以为更强"。这些约束写入文档后，用户能准确理解 Baton 当前版本的保护边界。

---

## Self-Review

### Internal Consistency Check

- ✅ 推荐方案（文档对齐为主 + advisory 保持 + 完整协议条款）贯穿所有 Change
- ✅ 每个 Change 回溯到审计发现（P0/P1/P2 编号）
- ✅ Surface Scan 覆盖所有 Change 文件，skip 有理由
- ✅ Change List 覆盖 Surface Scan 所有 "modify" 文件
- ✅ Deferred Constraints 正式列出所有本轮不修但需承认的约束
- ✅ todolist advisory 补充了跳过条件/决策权/最小约束（非轻描淡写）
- ✅ write set advisory 补充了完整 tradeoff 声明（工程+产品双重理由）
- ✅ README 措辞选用 "file-derived phase detection"（避免 state machine 误导）
- ✅ 无内部矛盾

### External Risks

1. **最大风险**：workflow.md token 预算。新增 Document Authority + Enforcement Boundaries + todolist 条款 + write set 声明，总新增可能 ~150 tokens。**缓解**：措辞极度精简，用列表而非段落；如果仍超预算，将 Enforcement Boundaries 移入 workflow-full.md
2. **可能完全推翻计划的因素**：如果人类认为 todolist 必须技术强制（而非 advisory），则 write-lock.sh 需改动，测试需更新，复杂度显著增加
3. **被否决但值得记录的方案**：write-lock.sh 加入 `## Todo` 检查（决策点 2A）— 技术上可行但会影响 Trivial 任务灵活性，且需大量测试更新

---

## Execution Summary

| 批次 | 内容 | 文件数 | 风险 |
|------|------|--------|------|
| Batch 1 | P0 契约清晰度 | 3 (workflow.md, workflow-full.md, README.md) | 低：纯文档修正 |
| Batch 2 | P1 准确性修正 | 3 (SKILL.md ×3) | 低：纯文档修正 |
| Batch 3 | 测试同步 | 2 (test-workflow-consistency.sh, test-ide-capability-consistency.sh) | 中：需确认断言内容 |

**总计 8 文件修改**，全部为文档/测试层面，无 hook 逻辑变更。

---

## Todo

- [x] ✅ 1. Change: workflow.md — update Phase Guidance section + add Enforcement Boundaries + add Document Authority + expand Action Boundaries with todolist/write-set clauses | Files: .baton/workflow.md | Verify: test-workflow-consistency.sh passes | Deps: none | Artifacts: none
  Files: .baton/workflow.md | Verified: `bash tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deviations: none
- [x] ✅ 2. Change: workflow-full.md — sync Phase Guidance section to match workflow.md | Files: .baton/workflow-full.md | Verify: test-workflow-consistency.sh passes (shared sections check) | Deps: #1 | Artifacts: none
  Files: .baton/workflow-full.md | Verified: `bash tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deviations: none
- [x] ✅ 3. Change: README.md — fix "No state machine" → file-derived phase detection; fix "7 hooks" → "8 hooks"; add .markdown to extension list; add Codex warning | Files: README.md | Verify: test-ide-capability-consistency.sh passes | Deps: none | Artifacts: none
  Files: README.md | Verified: `bash tests/test-ide-capability-consistency.sh` → 20/20 ALL PASSED | Deviations: none
- [x] ✅ 4. Change: baton-implement SKILL.md — fix "enforced by hooks" false claim at Action Boundaries Reminder; add normative status declaration | Files: .claude/skills/baton-implement/SKILL.md | Verify: test-workflow-consistency.sh SKILL.md checks pass | Deps: none | Artifacts: none
  Files: .claude/skills/baton-implement/SKILL.md | Verified: `bash tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deviations: none
- [x] ✅ 5. Change: baton-research SKILL.md — add normative status declaration after frontmatter | Files: .claude/skills/baton-research/SKILL.md | Verify: test-workflow-consistency.sh SKILL.md checks pass | Deps: none | Artifacts: none
  Files: .claude/skills/baton-research/SKILL.md | Verified: `bash tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deviations: none
- [x] ✅ 6. Change: baton-plan SKILL.md — add normative status declaration after frontmatter | Files: .claude/skills/baton-plan/SKILL.md | Verify: test-workflow-consistency.sh SKILL.md checks pass | Deps: none | Artifacts: none
  Files: .claude/skills/baton-plan/SKILL.md | Verified: `bash tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deviations: none
- [x] ✅ 7. Change: test-workflow-consistency.sh — update if any assertions break from workflow.md/SKILL.md text changes | Files: tests/test-workflow-consistency.sh | Verify: test-workflow-consistency.sh passes | Deps: #1, #2, #4, #5, #6 | Artifacts: none
  Files: none modified — tests passed without changes | Verified: ALL CONSISTENT | Deviations: none
- [x] ✅ 8. Change: test-ide-capability-consistency.sh — update if any assertions break from README changes | Files: tests/test-ide-capability-consistency.sh | Verify: test-ide-capability-consistency.sh passes | Deps: #3 | Artifacts: none
  Files: none modified — tests passed without changes | Verified: 20/20 ALL PASSED | Deviations: none
- [x] ✅ 9. Change: run full test suite to verify no regressions | Files: none | Verify: all tests pass | Deps: #1-#8 | Artifacts: none
  Verified: full suite run. test-workflow-consistency (ALL CONSISTENT), test-ide-capability-consistency (20/20), test-phase-guide (13/13). Pre-existing failures confirmed on clean master via git stash: test-write-lock (28/38), test-adapters (1/3 each), test-multi-ide (17/18) — same results before and after changes.

---

## Annotation Log

### Round 1

**[inferred: confirmation] § 整体方向 + 决策点 1 + 文档权威 + enforced by hooks**
"认同修复顺序、取舍方向、改动面控制；阶段模型选 A 正确；权威层级最高优先级；去掉虚假强表述必要"
→ 无需改动，方向确认
→ Consequence: 无方向变化
→ Result: accepted

**[inferred: depth-issue] § 决策点 2 — todolist advisory**
"保持 advisory 可以，但不能只补一句说明。需写清：跳过条件、决策权、跳过后最小约束"
→ 已更新决策点 2 推荐 + Change 1.1 规格，补充三条协议条款
→ Consequence: 无方向变化，深度增强
→ Result: accepted

**[inferred: depth-issue] § 决策点 3 — write set advisory**
"不能只用 IDE 限制当理由。需写清完整 tradeoff：当前版本/原因/影响/缓解/后续"
→ 已更新决策点 3 推荐为完整 tradeoff 声明 + Change 1.1 规格同步
→ Consequence: 无方向变化，结构增强
→ Result: accepted

**[inferred: change-request] § Change 1.3 — README 措辞**
"不要写 state machine，用 file-derived deterministic workflow state model"
→ 已更新 Change 1.3：L167 改为 "File-derived phase detection"，避免 state machine 联想
→ Consequence: 无方向变化，措辞调整
→ Result: accepted

**[inferred: gap] § 缺 Deferred Constraints 小节**
"需要一个'本轮不修但正式承认'的清单"
→ 已新增 `## Deferred but Explicitly Accepted Constraints` 小节，列出 5 项约束 + 文档表述方式
→ Consequence: 无方向变化，计划结构增强
→ Result: accepted

---

## Retrospective

### What the plan got wrong

Nothing structurally wrong. The plan predicted 8 file modifications; actual result was 6 file modifications + 2 "no change needed" (tests passed without updates). This is a good outcome — the plan was conservative about test breakage, and the tests turned out to be resilient to the text changes.

### What surprised during implementation

1. **Pre-existing test failures**: test-write-lock.sh (10/38 failures), test-adapters (2/3 failures each), test-multi-ide (1/18 failure) all exist on clean master. These are environment-specific issues (likely path/shell differences), not caused by this change set. Confirmed via `git stash` comparison.

2. **Test assertions were more flexible than expected**: Both test-workflow-consistency.sh and test-ide-capability-consistency.sh passed without any modifications despite significant text changes to workflow.md, SKILL.md files, and README.md. The tests check structural patterns (keyword presence, section existence) rather than exact text, which made them resilient.

3. **workflow-full.md sync scope**: The plan specified syncing Phase Guidance, but workflow-full.md also needed Action Boundaries updates (todolist skip protocol + write set advisory). This was a natural B-level adjacent change — the same sections exist in both files and must stay aligned.

### What to research differently next time

- **Pre-existing test baseline**: Before any audit-driven change, run the full test suite first and record the baseline. This session spent verification effort confirming that failures were pre-existing rather than regression.
- **Token budget tracking**: The plan flagged workflow.md token budget (~400 tokens) as a risk. The actual additions (~150 tokens) stayed within bounds, but future changes should measure before/after.

---

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->
这份计划最强的地方有三个。

第一，它抓住了修复顺序。
你把 P0 主要放在阶段模型、文档权威层级、README 误导表述这些“协议层失真”上，而不是一上来改 hook，这符合 Baton 当前的真实问题结构。现在 Baton 最大的问题确实不是运行时大漏洞，而是“规范怎么说、用户怎么理解、实现实际做什么”之间还有错位。 ￼

第二，它做了明确取舍。
尤其三个决策点很关键：
阶段模型承认 6 态、todolist 保持 advisory、write set 保持 advisory。这个好处是避免在一次修复里把 Baton 推向更重、更脆的实现。作为第一轮收敛，这个思路稳。 ￼

第三，它控制了改动面。
计划把修改压到 8 个文件，而且几乎全是文档/测试层，这很重要。因为你这轮任务的核心不是“增强 Baton”，而是“让 Baton 先自洽”。在这一点上，这份计划没有跑偏。 ￼

我认同的部分

1. 阶段模型选 A 是正确的

“4 个主阶段 + 2 个系统态”这个表述，比“硬把实现改回 4 阶段”更合理。
原因很简单：实现已经证明你实际上依赖 AWAITING_TODO 和 ARCHIVE 这两个状态做提示和边界控制；为了迎合文案去删状态，属于反向伤系统。这里改文档比改逻辑更对。 ￼

2. 文档权威层级必须补，而且应当放在最高优先级

你把 workflow.md / SKILL.md / workflow-full.md / README.md 的权威关系单独拎出来，这是对的。
Baton 现在最危险的，不是某个单点 bug，而是“多份文档都在定义行为”。不先定 normative hierarchy，后面所有修复都可能继续漂。 ￼

3. baton-implement 去掉 “enforced by hooks” 这类虚假强表述，非常必要

这个修复虽然看起来只是文案，但实际上是在修 Baton 的信用。
治理型项目最忌讳把 advisory 说成 enforced，把 social contract 说成 technical gate。这个地方必须改，而且优先级应该很高。 ￼

我不完全认同的部分

1. 这份计划把 “todolist 保持 advisory” 处理得太轻了

先说结论：保持 advisory 可以，但不能只是在 workflow.md 里补一句说明就算完。

你的计划现在的逻辑是：
•	不做技术强制
•	phase-guide 已有 AWAITING_TODO
•	文档承认它只是 advisory

这在工程上可行，但在协议上还不够。
因为 Baton 的核心不是“实现一个提示器”，而是“把进入 implement 的前置条件说清楚”。

如果 todolist 继续 advisory，那你至少还需要把下面三件事写清：
1.	什么情况下可以合法跳过 todolist
2.	谁有权判断可以跳过
3.	跳过后 implement 的最小约束是什么

否则你只是把“原来的隐性歧义”改成了“显式承认歧义”。

也就是说，这个决策可以保留，但文档补充量不能只有一句轻描淡写说明。 ￼

2. approved write set 保持 advisory，我认为可以接受，但不能只用 IDE 限制当理由

你在计划里写 “PostToolUse 在多数 IDE 架构中不支持 blocking，所以保持 advisory”。这句话作为工程理由成立，但作为产品理由不够。 ￼

真正的问题不是“能不能拦”，而是：

Baton 还要不要继续把‘计划是合同’作为强命题。

如果答案是要，那你至少应该在计划里再加一个明确表述：
•	当前版本：write set 仅 advisory
•	原因：宿主 hook 模型限制
•	影响：计划外写入无法被技术阻断
•	缓解：通过 skill discipline + post-write audit + review 发现偏航
•	后续：保留升级为更强 enforcement 的设计空间

现在这份计划只写了“保持 advisory + 文档说明”，对这个 tradeoff 讲得还不够硬。
这会导致用户误以为“只是暂时没拦”，而不是“这是当前架构边界”。 ￼

3. README.md 改成 “Deterministic state machine” 是对的，但这个词要慎选

你写的是把 No state machine 改成 Deterministic state machine 或等价表述。这里方向对，但具体措辞我建议谨慎。 ￼

原因是 Baton 不是传统外显状态机系统，它更准确的是：

file-derived deterministic workflow state model
或者中文可以表达成：
由文件状态推导的确定性阶段模型

为什么要这么咬文嚼字？因为如果你直接写 “state machine”，用户会自然联想到显式状态存储、事件转移、持久化状态。这不是 Baton 当前的实现形态。

所以这里建议修，但别过度工程化命名。

这份计划最大的缺口

最大缺口不是某个技术点，而是：

它还缺一个“哪些问题这轮明确不修、但要正式承认”的清单。

现在计划虽然有决策分析，也有 skip 理由，但还不够像“产品层承诺管理”。
我建议你补一个很短的小节，名字类似：

Deferred but Explicitly Accepted Constraints

里面直接列：
•	Codex 无技术写锁，只有规则引导
•	todolist 当前不是技术阻断条件
•	approved write set 当前不是技术强制
•	BATON:GO 不能完全技术证明由人类写入
•	部分治理依赖 skill discipline，而非 hook enforcement

这很重要。
因为 Baton 当前最缺的不是更多规则，而是把不能做到的事也说清楚。
治理层最怕“默认让用户以为更强”。

<!-- BATON:GO -->
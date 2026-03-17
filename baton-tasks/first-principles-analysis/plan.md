# Baton 治理系统改进计划

基于 skill-audit.md 的 27+ 项发现和 5 个系统性模式，制定改进方案。

**Complexity**: Large（涉及 .baton/ 下 34 个文件中的 ~20 个，跨越治理层、技能层和 hook 层）

---

## Requirements

来源：skill-audit.md [CODE] ✅ + 批注区 3 条 accepted annotations

1. 修复 2 个高严重度安全缺口（C2、B15）
2. 解决 11 个中严重度行为不可预测问题
3. 缓解 5 个系统性模式（A-E），尤其是模式 E（多副本漂移）的根因
4. 不破坏现有 baton-tasks 中的进行中工作
5. 改进方案自身必须可增量交付——不能要求一次性全部完成

---

## First Principles Decomposition

### Problem Statement

Baton 的治理系统在规则层（constitution + skills）做出了强承诺（"hard boundary"、"mandatory review"、"STOP"），但 hook 层的实际执行力与这些承诺之间存在系统性落差。同时，同一治理事实在 6+ 位置重复陈述且无单一真相源，导致副本间漂移产生矛盾。AI 在运行时面对矛盾指令时行为不可预测。

### Constraints

1. **向后兼容** — 现有 plan 文件格式、BATON:GO/COMPLETE 标记语义不能变
2. **Fail-open 是有意设计** — hook 生态不稳定，不能将所有 hook 改为 fail-closed
3. **Constitution 变更级联** — constitution 是最高非人类权威，改它会影响所有下游
4. **AI 上下文有限** — 不能通过"加更多文字"解决问题，需要减少而非增加治理文本总量
5. **增量交付** — 每个 wave 必须独立有价值，不能依赖后续 wave 才有意义

### Solution Categories

**Category 1: 增量对齐** — 逐一修复文档措辞和 hook 行为，不改架构
**Category 2: 架构整合** — 为每个治理事实建立 SSoT，所有层引用而非复述
**Category 3: 分阶段** — Wave 1 关键修复 → Wave 2 定向整合 → Wave 3 选择性硬化

### Evaluation

| 维度 | Category 1 增量对齐 | Category 2 架构整合 | Category 3 分阶段 |
|------|-------------------|-------------------|-----------------|
| 修复根因 | ❌ 治标不治本，修完还会漂移 | ✅ 直接消除多副本漂移 | ✅ Wave 2 处理根因 |
| 交付风险 | 低（每个修复独立） | 高（大范围重构，中间态不稳定） | 中（每 wave 独立收敛） |
| 向后兼容 | ✅ 最安全 | ❌ 可能改变引用方式 | ✅ Wave 1 完全兼容 |
| 上下文负担 | ❌ 文本总量不减反增 | ✅ 文本总量减少 | ✅ Wave 2 减少 |
| 可增量交付 | ✅ 天然增量 | ❌ 需整体完成才有价值 | ✅ 每 wave 独立有价值 |

---

## Approach A: 增量对齐（"逐个修补"）

- **What**: 按严重度排序，逐一修复每个发现涉及的文档和 hook
- **How**: 对每个 finding 做最小改动——修措辞、加 hook 条件、补定义
- **Trade-offs**:
  - ✅ 风险最低，每个修复可独立验证
  - ❌ 不解决模式 E（多副本漂移）——修完 C2 后，下次有人改 baton-implement 又会遗漏同步 phase-guide
  - ❌ 治理文本总量只增不减，加重 AI 上下文负担
- **Fit**: 解决表面症状，不解决结构性问题

## Approach B: 架构整合（"单一真相源"）

- **What**: 为每个治理事实指定唯一 authoritative source，其他所有位置通过引用获取
- **How**:
  - Constitution 定义语义（"什么是失败阈值"）
  - 一个新的 `governance-facts.md` 或 constitution 扩展定义具体值
  - Phase skills 引用而非复述（`per constitution §Failure Boundary`）
  - phase-guide.sh 从 plan-parser 动态读取 skill 定义而非硬编码
- **Trade-offs**:
  - ✅ 从根本上消除多副本漂移
  - ✅ 减少治理文本总量，降低 AI 上下文负担
  - ❌ 大范围重构：需同时改 constitution、所有 skills、所有引用这些事实的 hooks
  - ❌ 中间态不稳定——改了一半时系统可能比现在更不一致
  - ❌ "引用而非复述"对 AI 是反直觉的——AI 需要看到完整文本才能遵守，间接引用可能被忽略
- **Fit**: 解决根因但实施风险高，且"引用"模式与 AI 上下文加载机制有冲突

## Approach C: 分阶段（"关键修复 → 定向整合 → 选择性硬化"）

- **What**: 三个独立 wave，每个 wave 解决不同层次的问题
- **How**:
  - **Wave 1**（关键修复）: 修 C2、B15 两个高严重度 + 定义 Annotation Log 和 post-escalation 协议
  - **Wave 2**（定向整合）: 对 5 个已确认漂移的治理事实建立 SSoT，不做全面重构
  - **Wave 3**（选择性硬化）: 在最关键的 3-4 个点升级 hook 执行力
- **Trade-offs**:
  - ✅ Wave 1 立即修复安全缺口，独立交付
  - ✅ Wave 2 只针对已确认漂移的事实，不做投机性重构
  - ✅ Wave 3 选择性加 hook，不追求全覆盖
  - ⚠️ 比 Category 2 保守——不追求消除所有漂移，只修已发现的
  - ⚠️ 需要 3 个 plan-review 周期
- **Fit**: 在风险控制和根因修复之间取得平衡

---

## Recommendation: C→D 混合路径

> 初版推荐 Approach C（分阶段修补）。批注区 Annotation 4 的第一性原理分析揭示了更根本的问题：33 条规则中 52% 完全无执行，治理复杂度超过执行能力。人类选择 C→D 混合路径 [HUMAN] ✅。

**最终方案**：
1. **Wave 1**（关键修复）→ 不变，立即修复 2 个安全缺口
2. **Wave 1.5**（规则重分类）→ 新增，将 33 条规则分为 Hard Rule / Auditable Standard / Guidance
3. **Wave 2**（定向整合）→ 基于重分类结果调整：只对 Hard Rule 和 Auditable Standard 做 SSoT
4. **Wave 3**（选择性硬化）→ 基于重分类结果调整：只升级高风险 Auditable Standards

**拒绝纯 A 的原因**：不解决模式 E，修复被后续漂移侵蚀 [CODE] ✅（skill-audit.md Annotation 3）
**拒绝纯 B 的原因**：全面 SSoT 与 AI 必须看到完整规则的现实矛盾 [DESIGN] ❓
**拒绝纯 C 的原因**：在 33 条规则内修补矛盾，但不质疑规则数量是否合理 [CODE] ✅（Annotation 4 量化分析）
**拒绝纯 D 的原因**：Step 1 重分类是不可增量的前置条件，风险高；Wave 1 的安全修复不应等待重分类

---

## Detailed Design: Wave 1 — 关键修复

**执行顺序约束**: W1.4（constitution 扩展）必须先于 W1.2（baton-debug 引用 BLOCKED），因为 W1.2 的措辞依赖 W1.4 定义的 post-escalation 语义。W1.1 和 W1.3 可独立于其他项。

### W1.1: 修复 C2（FINISH 指导遗漏 Implementation Review）

**Files**: `phase-guide.sh`
**Change**: 在 FINISH 阶段指导中，在 "Run the full test suite" **之前**插入 implementation review 步骤
**Before**:
```
1. Append ## Retrospective to $PLAN_NAME
2. Run the full test suite
3. Mark complete
4. Decide branch disposition
```
**After**:
```
1. Implementation review (invoke /baton-review or dispatch via Agent)
2. Fix review findings, re-review if needed
3. Run the full test suite
4. Append ## Retrospective to $PLAN_NAME
5. Mark complete: add <!-- BATON:COMPLETE -->
6. Decide branch disposition
```
**Verify**: 读取 phase-guide.sh FINISH 输出，确认与 baton-implement Step 5 一致

**注意**: W2.2 将取代本项的硬编码步骤列表，改为引用 baton-implement Step 5。W1.1 的验证标准是临时性的——W2.2 完成后需重新验证 FINISH 指导的完整性。

### W1.2: 修复 B15（baton-debug Escalation 不引用 BLOCKED 状态）

**Files**: `baton-debug/SKILL.md`
**Change**: 在 Escalation Criteria 中明确：当 "plan assumptions wrong / write set exceeded" 时，必须：
1. 进入 BLOCKED 状态
2. 声明旧 BATON:GO 失效（因为 constitution Q1/Q2 被触发）
3. 等待人类确认后获得新的 BATON:GO 才能继续

**Verify**: 读取 baton-debug SKILL.md escalation section，确认引用了 constitution BLOCKED 状态和 BATON:GO 失效语义

### W1.3: 定义 Annotation Log（C9）

**Files**: `shared-protocols.md`（新增 Section 5）
**Change**: 添加 Annotation Log 的定义、格式、与批注区的区别：
- **Annotation Log**: 实现阶段的轻量级设计决策记录（单行条目，含日期+决策+理由）
- **批注区**: 人机交互的结构化批注/挑战/回应
- 格式模板 + 何时用哪个的判断标准

**Verify**: grep 所有引用 "Annotation Log" 的文件，确认与新定义不矛盾

### W1.4: 定义 Post-Escalation 协议（B6）

**Files**: `constitution.md`（State Model 扩展）

**现有文本**（constitution.md:90-95）已定义：
- `Any → BLOCKED`: triggered by discovery protocol (Q1/Q2), unresolved challenge, or failure boundary
- `BLOCKED → EXECUTING`: 区分了 Q1/Q2 invalidation（需 renewed GO）和 challenge/failure boundary（人类确认现有 GO 仍适用）

**问题**: 现有规则只说"怎么进入 BLOCKED"和"怎么离开 BLOCKED"，但没定义 BLOCKED **期间** AI 的行为，也没有将 skill-level escalation（review circuit breaker、debug escalation、research circuit breaker）显式映射到 BLOCKED 状态。

**Change**: 在现有 `BLOCKED → EXECUTING` 规则之后新增：

1. **BLOCKED 期间行为**（新增条款）:
   - AI 必须报告 blocking reason 和 impact statement
   - 不执行 plan scope 内的工作
   - 可继续信息收集但不可修改 artifacts

2. **Escalation → BLOCKED 映射**（新增条款，引用而非替代现有触发条件）:
   - Review circuit breaker（3 revision cycles with high severity）→ BLOCKED（属于 "unresolved challenge" 触发条件）
   - Debug escalation（plan assumptions wrong / write set exceeded）→ BLOCKED（属于 Q1/Q2 触发条件，GO 失效）
   - Research/Plan circuit breaker → BLOCKED（属于 "failure boundary" 触发条件）

这些映射不引入新的触发类型，而是将现有触发条件具体化到各 skill 的 escalation 场景。BLOCKED 的退出仍遵循现有的 `BLOCKED → EXECUTING` 规则（Q1/Q2 需 renewed GO，其他需人类确认现有 GO）。

**Verify**: 读取修改后的 constitution.md state transition rules，确认新条款与现有 :90-95 行无矛盾；确认 baton-review、baton-plan、baton-debug 的 escalation 路径都能映射到已有的触发类型

---

## Detailed Design: Wave 1.5 — 规则重分类 + 治理面缩减

> 这是 C→D 混合路径的核心步骤。在 Wave 1（安全修复）和 Wave 2（SSoT 整合）之间执行。
> Wave 1.5 改变的是 constitution 的**呈现结构**，不改变规则的实质内容。

### W1.5.1: 规则重分类（constitution.md 结构重组）

**Files**: `constitution.md`
**Change**: 将 constitution 中的 33 条命令式规则（见 Annotation 4 量化分析）显式分为三类。在每个规则或规则组旁标注类别：

| 类别 | 定义 | 执行方式 | 标注格式 |
|------|------|---------|---------|
| **`[HARD]`** | 操作约束，违反时 hook 阻止操作 | Hook exit 2 | `[HARD: write-lock]` |
| **`[AUDIT]`** | 推理质量标准，review 时评估 | Review checklist 检查项 | `[AUDIT: review-prompt]` |
| **`[GUIDE]`** | 最佳实践，AI 自律遵守 | 无强制执行 | `[GUIDE]` |

**预期分类**（基于 Annotation 4 量化分析）：

**Hard Rules（~7 条）**:
- 源码修改需 BATON:GO [HARD: write-lock]
- Shell 写入操作受限 [HARD: bash-guard]
- 完成需 retrospective [HARD: completion-check]
- 完成需 todo 全部完成 [HARD: completion-check]
- 不超出项目边界 [HARD: write-lock + bash-guard]
- Plan approval 不等于执行授权 [HARD: write-lock]
- AI 不得添加 BATON:GO/COMPLETE/OVERRIDE（当前无 hook，Wave 3 候选）

**Auditable Standards（~12 条）**:
- 每个 material claim 有证据支持
- 证据状态显式标记（✅/❌/❓）
- 发现协议 Q1/Q2/Q3 判断显式记录
- Impact statement 每次 discovery 必写
- 挑战反驳需等级或更高力度证据
- 不得默默同意（矛盾要说出来）
- 不确定时停下来
- 完成需结果匹配目标
- 完成需人类确认
- 文档必须有批注区
- 文档必须用证据标签
- Implementation-local 变更需事先记录

**Guidance（~14 条）**:
- 无支撑置信度语言无效（"should be fine"）
- 不可同源性语言避免
- Phase skill 优先于 extension skill
- Task documents 不得重定义语义
- 假设有效性重检（Core Invariant 5）
- Stale authorization 检测
- 等

**注意**: 上述分类是草案。实施时需逐条确认，某些边界情况（如 "假设有效性重检" — 是 Auditable Standard 还是 Guidance？）需要逐个判断。

**Verify**: 读取重分类后的 constitution.md，确认：(1) 每条命令式规则都有类别标注，(2) 标注为 [HARD] 的规则都有对应 hook，(3) 标注为 [AUDIT] 的规则都能映射到 review-prompt 中的检查项

### W1.5.2: Review Prompt 与 Auditable Standards 对齐

**Files**: `baton-plan/review-prompt.md`, `baton-implement/review-prompt.md`, `baton-research/review-prompt-codebase.md`
**Change**: 确保每个标注为 `[AUDIT]` 的 constitution 规则在对应 phase 的 review-prompt 中有检查项。目前 review-prompt 的检查项是独立编写的，与 constitution 规则没有显式对应关系。重分类后，review-prompt 应引用 constitution 的 `[AUDIT]` 标注：

```markdown
## Constitution Auditable Standards Check
- [ ] Evidence labels present for all material claims? (constitution §Evidence Model [AUDIT])
- [ ] Discovery protocol Q1/Q2 answers explicit? (constitution §Discovery Protocol [AUDIT])
- ...
```

**Verify**: 对比 constitution `[AUDIT]` 标注列表和 review-prompt 检查项列表，确认无遗漏

### W1.5.3: 治理面缩减 — shared-protocols 合并

**Files**: `constitution.md`, `shared-protocols.md`, 所有引用 shared-protocols 的 skills
**Change**:
- shared-protocols Section 1（Extended Evidence Standards）→ 合并到 constitution Evidence Model
- shared-protocols Section 2（Self-Challenge）→ 合并到 constitution（新增 §Self-Challenge）或保留为 skill-level guidance
- shared-protocols Section 3（Review Protocol）→ 合并到 constitution（扩展现有 review 相关语义）
- shared-protocols Section 4（批注区 Protocol）→ 合并到 constitution Artifact Model
- 合并后删除 shared-protocols.md，更新所有 `Follow .baton/shared-protocols.md Section N` 引用为 constitution 引用

**风险**: 这会增加 constitution 的长度。但目的不是减少总文本量，而是消除一个漂移源。Constitution 变长但成为真正的 single source。

**Verify**: grep 全部 `.baton/` 文件，确认无残留 `shared-protocols` 引用；读取合并后 constitution，确认无内部矛盾

### W1.5.4: 治理面缩减 — phase-guide 去重

**Files**: `phase-guide.sh`
**Change**: phase-guide.sh 不再硬编码各阶段的具体步骤列表。改为：
- 只输出**当前阶段名称**和**对应 skill 的调用指令**
- 保留文件系统检测逻辑（检测 plan、research、todo 的存在性）
- 保留警告逻辑（批注区未处理、write set 异常等）
- **删除**所有硬编码的步骤列表（RESEARCH 步骤、PLAN 步骤、FINISH 步骤等）

**Before**:
```
📍 FINISH phase — all tasks complete. Complete the completion workflow:
   1. Implementation review...
   2. Run the full test suite...
   ...
```

**After**:
```
📍 FINISH phase — all tasks complete.
   Load /baton-implement for the completion workflow (Step 5).
```

**注意**: 这取代了 W1.1 和 W2.2 的修改。W1.1（修 FINISH 遗漏 review）在 W1.5.4 执行后不再需要，因为 phase-guide 不再硬编码步骤。但 W1.1 应在 W1.5.4 之前执行作为临时修复——如果 W1.5 延迟，W1.1 仍然提供安全价值。

**Verify**: 启动新 session，确认 phase-guide 对每个阶段只输出阶段名 + skill 调用指令，不输出硬编码步骤

### W1.5.5: 引用式规则可行性调查

**Files**: 无修改（调查性质）
**实验设计**:
1. 在一个测试 session 中，constitution 的 Auditable Standards 只保留 `[AUDIT]` 标注和一句话摘要，删除完整规则文本
2. AI 按正常流程执行一个小任务（写 plan 或做 review）
3. 用 baton-review（完整 context）评估 AI 的输出是否遵循了被引用但未内联的 Auditable Standards
4. 对比：同一任务在完整 constitution 下的输出质量

**判定标准**: 如果引用式规则下的 review 通过率 < 70%，则 Wave 2 的 SSoT 策略需要在引用处保留足够上下文（不能纯引用）。

**Verify**: 实验完成后记录结果到本 plan 的 Annotation Log

---

## Detailed Design: Wave 2 — 定向整合（基于 W1.5 重分类结果调整）

> **注**: Wave 2 设计为方向性规格。W1.5 完成后，Wave 2 的具体范围将基于重分类结果调整：只对 Hard Rule 和 Auditable Standard 类规则做 SSoT，Guidance 类规则允许松散一致。以下保留原设计作为起点，实施时按重分类结果修订。

### W2.1: 失败阈值 SSoT（C1）

**Authoritative source**: `constitution.md` §Failure Boundary
**Change**:
- Constitution 明确：默认阈值 >1（≥2），phase skill 可通过 `Failure threshold: N` 声明覆盖
- baton-implement 和 baton-debug 各自声明 `Failure threshold: 3`
- phase-guide.sh 从 constitution 继承默认值或从当前 phase skill 读取覆盖值
- failure-tracker.sh 的 3/5 阈值改为引用 phase skill 的声明值

**Files**: constitution.md, baton-implement/SKILL.md, baton-debug/SKILL.md, phase-guide.sh, failure-tracker.sh
**Verify**: grep "fail" / "threshold" / "repeatedly" 跨所有 .baton/ 文件，确认引用一致

### ~~W2.2: FINISH 步骤 SSoT~~ — 已被 W1.5.4 取代

W1.5.4（phase-guide 去重）已覆盖此项。phase-guide 不再硬编码任何阶段步骤，统一改为 skill 调用指令。

### W2.3: Review Dispatch 优先级澄清（C3 + C7）

**Authoritative source**: 各 phase skill 的 review 步骤
**Change**:
- ~~shared-protocols.md Section 3~~ → W1.5.3 合并后变为 constitution §Review Protocol 中的措辞。将 "engineering judgment" 改为 "When the phase skill specifies dispatch, prefer dispatch; use self-review only when dispatch is technically blocked"
- baton-review 的 "may skip" 条件加 qualifier: "These skip conditions apply to human-initiated standalone reviews. When dispatched by a phase skill's mandatory review step, the phase skill's requirement takes precedence."

**Files**: constitution.md（合并后的 review protocol section）, baton-review/SKILL.md
**Verify**: 读取 constitution review protocol 和 baton-review skip 条件，确认优先级无歧义

### W2.4: Discovery 框架统一（C5）

**Authoritative source**: `constitution.md` §Discovery Protocol Q1/Q2/Q3
**Change**: baton-implement 的 A/B/C/D 分级明确映射到 constitution 的 Q1/Q2/Q3，在 SKILL.md 中用表格对齐：

| Implement 级别 | Constitution 问题 | 行为 |
|---------------|-----------------|------|
| A（无影响） | Q3（都不适用） | 继续 |
| B（implementation-local） | Q3 + implementation-local touch | 记录后继续 |
| C（新能力/文件面） | Q2（execution plan needs change） | BLOCKED |
| D（假设失效） | Q1（assumptions invalid） | BLOCKED + GO 失效 |

**Files**: baton-implement/SKILL.md
**Verify**: 读取 baton-implement discovery 分级，确认每个级别都有 constitution Q 对应且行为一致

### W2.5: Research 阶段 Spike 语义澄清（C8）

**Authoritative source**: `baton-research/SKILL.md` Iron Law
**Change**: phase-guide.sh 的 "Spike with Bash" 改为 "Investigate with Bash (read-only: run commands, inspect output — no file creation or modification)"

**Files**: phase-guide.sh
**Verify**: 读取 phase-guide RESEARCH 阶段输出，确认不再出现 "spike" 措辞

---

## Detailed Design: Wave 3 — 选择性硬化

> **注**: Wave 3 设计为方向性规格。基于 W1.5 重分类结果，Wave 3 的目标是：将 W1.5.1 中标注为 `[AUDIT]` 但风险最高的规则升级为 `[HARD]`（添加 hook 执行）。以下保留原设计，实施时按重分类结果确认哪些规则值得升级。W3.1 有可行性前提条件。

### W3.1: BATON:GO/COMPLETE/OVERRIDE 标记保护（B7）

**Files**: write-lock.sh
**Change**: 对 markdown 文件的写入，增加一项检查：如果 Edit/Write 的 new content 包含 `<!-- BATON:GO`、`<!-- BATON:COMPLETE` 或 `<!-- BATON:OVERRIDE`，则 block 并提示 "Only the human may add governance markers"。

**可行性前提**: 这需要解析 tool input 中的 new_string 内容。write-lock 目前只检查文件路径，不检查内容。**实施前必须先完成 feasibility spike**：检查 hook 接收的 JSON 参数是否包含 tool input content。如果不包含，W3.1 降级为 advisory warning（在 PostToolUse 中检查文件 diff 是否新增了标记字符串）。如果 PostToolUse 也无法获取 diff，则 W3.1 descope。
**Verify**: 运行 write-lock hook 传入包含 BATON:GO 的 markdown 写入，确认 block（或 warning）

### W3.2: Write Set 越界从 Advisory 升级为 Soft Block（B17 / Annotation 2）

**Files**: post-write-tracker.sh
**Change**: 超出 write set 的写入从纯 warning 升级为：
- 第 1 次：warning + 记录
- 第 2 次同一文件：warning + 在下一次 Stop hook 时强制提示人类确认
- **不改为 hard block**（PostToolUse 无法 block，且 fail-open 原则）

**Verify**: 模拟写入 write set 外的文件两次，确认第 2 次触发 Stop hook 升级提示

### W3.3: Full Test Suite 配置化（B10）

**Files**: 新增 `.baton/config.sh` 或扩展 `_common.sh`
**Change**: 定义 `BATON_TEST_CMD` 变量（默认 auto-detect: npm test / pytest / make test / bash tests/run.sh），completion-check.sh 检查该命令是否被执行过（通过 post-write-tracker 记录的 Bash 调用历史）。
**Verify**: 在有 BATON_TEST_CMD 配置的项目中，运行 completion-check，确认未执行测试时产生 warning

### W3.4: 复杂度早期验证（B9）

**Files**: phase-guide.sh
**Change**: 在 PLAN 阶段开始时（而非 ANNOTATION 阶段结束后），如果检测到 write set > 3 files 或 research.md 中有多维度分析，输出 "Detected indicators of Medium+ complexity — verify complexity classification before proceeding"。
**Verify**: 在有 >3 files write set 的 plan 下启动 session，确认 PLAN 阶段输出复杂度提示

---

## Surface Scan

| File | Level | Wave | Disposition | Reason |
|------|-------|------|-------------|--------|
| **constitution.md** | L1 | W1.4, W1.5.1, W1.5.3, W2.1, W2.3 | modify | 核心：post-escalation、规则重分类、shared-protocols 合并、SSoT |
| **phase-guide.sh** | L1 | W1.1, W1.5.4, W2.5, W3.4 | modify | FINISH 临时修复、去重、spike 澄清、复杂度提示 |
| **shared-protocols.md** | L1 | W1.3, W1.5.3 | **delete** | W1.3 先加 Annotation Log 定义，W1.5.3 合并到 constitution 后删除 |
| **baton-debug/SKILL.md** | L1 | W1.2 | modify | B15 escalation 引用 BLOCKED |
| **baton-implement/SKILL.md** | L1 | W2.1, W2.4 | modify | C1 失败阈值声明、C5 discovery 映射 |
| **baton-review/SKILL.md** | L1 | W2.3 | modify | C7 skip 条件 qualifier |
| review-prompt.md (plan) | L1 | W1.5.2 | modify | Auditable Standards 检查项对齐 |
| review-prompt.md (implement) | L1 | W1.5.2 | modify | Auditable Standards 检查项对齐 |
| review-prompt-codebase.md | L1 | W1.5.2 | modify | Auditable Standards 检查项对齐 |
| write-lock.sh | L1 | W3.1 | modify | B7 标记保护 |
| post-write-tracker.sh | L1 | W3.2 | modify | B17 write set 越界升级 |
| completion-check.sh | L1 | W3.3 | modify | B10 test suite 检查 |
| _common.sh | L1 | W3.3 | modify | B10 BATON_TEST_CMD 定义 |
| failure-tracker.sh | L1 | W2.1 | modify | C1 阈值引用 |
| baton-research/SKILL.md | L2 | W1.5.3 | modify | 更新 shared-protocols 引用为 constitution 引用 |
| baton-plan/SKILL.md | L2 | W1.5.3 | modify | 更新 shared-protocols 引用为 constitution 引用 |
| baton-subagent/SKILL.md | L2 | W1.5.3 | modify | 更新 shared-protocols 引用为 constitution 引用 |
| using-baton/SKILL.md | L2 | W1.5.3 | modify | 更新 shared-protocols 引用为 constitution 引用 |
| stop-guard.sh | L2 | W1.3 | skip | 引用 Annotation Log 但不定义它 |
| pre-compact.sh | L2 | — | skip | 只检测存在性 |
| plan-parser.sh | L2 | — | skip | 当前不影响核心修复 |
| quality-gate.sh | L2 | — | skip | 当前不影响核心修复 |
| bash-guard.sh | L2 | — | skip | 无相关发现 |
| subagent-context.sh | L2 | — | skip | 无相关发现 |
| templates | L2 | — | skip | B4 是低严重度 |
| adapters | L3 | — | skip | 不涉及治理逻辑 |

**Core write set（18 个文件）**: constitution.md, phase-guide.sh, shared-protocols.md（W1.5.3 后删除）, baton-debug/SKILL.md, baton-implement/SKILL.md, baton-review/SKILL.md, 3× review-prompt.md, write-lock.sh, post-write-tracker.sh, completion-check.sh, _common.sh, failure-tracker.sh, baton-research/SKILL.md, baton-plan/SKILL.md, baton-subagent/SKILL.md, using-baton/SKILL.md

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Constitution 修改引入新矛盾 | 中 | 高 | W1.4、W1.5.1、W1.5.3 改 constitution 后立即 dispatch baton-review |
| Phase-guide 去重后 AI 不加载 skill | 中 | 高 | W1.5.4 保留阶段名和 skill 调用指令，AI 有明确的加载入口 |
| shared-protocols 合并增大 constitution 体积 | 高 | 中 | 合并后审查 constitution 总行数，如 >500 行考虑分节加载策略 |
| 规则重分类标注主观性 | 中 | 中 | W1.5.1 的分类草案提交人类 review，边界情况由人类定夺 |
| Phase-guide 修改破坏 SessionStart | 中 | 中 | 每次改 phase-guide 后手动测试 session 启动 |
| Write-lock 标记检测误报 | 中 | 中 | W3.1 采用 fail-open：检测失败时放行而非阻断 |
| 引用式规则 AI 不遵守 | 中 | 高 | W1.5.5 实验验证，结果决定 Wave 2 策略 |

**Rollback strategy**: 每个 wave 在独立 commit（或 commit 组）中实现。可通过 `git revert` 回退单个 wave 而不影响其他 wave。依赖方向：W1.5 依赖 W1，W2 依赖 W1 + W1.5，W3 依赖 W1。回退 W3 不影响其他 wave；回退 W2 不影响 W1/W1.5；回退 W1.5 需同时回退 W2（因为 W2 基于重分类结果）。

---

## Scope Not Covered（低严重度，延后处理）

以下低严重度发现不在本计划 scope 内：
C4, C6, C8（hook 层已一致）, C10, C11, B2, B3, B4, B5, B11, B12, B13, B14, B16

**理由**: 功能性影响小，且部分会被 Wave 2 的 SSoT 整合间接缓解。

---

## Todo

### Wave 1 — 关键修复

- [x] ✅ 1. Change: phase-guide.sh FINISH 阶段插入 implementation review 步骤（W1.1/C2）
  Files: `.baton/hooks/phase-guide.sh`
  Verify: 读取 phase-guide.sh FINISH 输出，确认 6 步与 baton-implement Step 5 一致
  Deps: none
  Artifacts: none

- [x] ✅ 2. Change: constitution.md 新增 BLOCKED 期间行为 + Escalation→BLOCKED 映射（W1.4/B6）
  Files: `.baton/constitution.md`
  Verify: 读取 constitution state transition rules :90+ 确认无矛盾；检查 baton-review/plan/debug escalation 映射
  Deps: none
  Artifacts: none

- [x] ✅ 3. Change: baton-debug SKILL.md escalation 引用 BLOCKED 状态和 GO 失效语义（W1.2/B15）
  Files: `.baton/skills/baton-debug/SKILL.md`
  Verify: 读取 baton-debug escalation section，确认引用 constitution BLOCKED + GO invalidation
  Deps: 2（W1.4 定义 post-escalation 语义后才能引用）
  Artifacts: none

- [x] ✅ 4. Change: shared-protocols.md 新增 Section 5 定义 Annotation Log 格式和与批注区的区别（W1.3/C9）
  Files: `.baton/shared-protocols.md`
  Verify: grep "Annotation Log" 跨 .baton/，确认与新定义不矛盾
  Deps: none
  Artifacts: none

### Wave 1.5 — 规则重分类 + 治理面缩减

- [x] ✅ 5. Change: constitution.md 33 条规则添加 [HARD]/[AUDIT]/[GUIDE] 分类标注（W1.5.1）
  Files: `.baton/constitution.md`
  Verify: 确认每条规则有标注；[HARD] 有对应 hook；[AUDIT] 可映射到 review-prompt 检查项
  Deps: 2（W1.4 先完成 constitution 扩展）
  Artifacts: none

- [x] ✅ 6. Change: review-prompt 添加 Constitution Auditable Standards Check section（W1.5.2）
  Files: `.baton/skills/baton-plan/review-prompt.md`, `.baton/skills/baton-implement/review-prompt.md`, `.baton/skills/baton-research/review-prompt-codebase.md`
  Verify: 对比 constitution [AUDIT] 列表和 review-prompt 检查项，确认无遗漏
  Deps: 5（需要 W1.5.1 完成分类）
  Artifacts: none

- [x] ✅ 7. Change: shared-protocols 4 个 section 合并到 constitution，删除 shared-protocols.md，更新所有引用（W1.5.3）
  Files: `.baton/constitution.md`, `.baton/shared-protocols.md`(delete), `.baton/skills/baton-research/SKILL.md`, `.baton/skills/baton-plan/SKILL.md`, `.baton/skills/baton-implement/SKILL.md`, `.baton/skills/baton-review/SKILL.md`, `.baton/skills/baton-subagent/SKILL.md`, `.baton/skills/using-baton/SKILL.md`
  Verify: grep "shared-protocols" 跨 .baton/，确认零残留引用；读取合并后 constitution 确认无内部矛盾
  Deps: 5（W1.5.1 完成后再合并，避免合并期间分类标注丢失）
  Artifacts: none

- [x] ✅ 8. Change: phase-guide.sh 去重——删除硬编码步骤列表，改为 skill 调用指令（W1.5.4）
  Files: `.baton/hooks/phase-guide.sh`
  Verify: 启动新 session，确认每个阶段只输出阶段名 + "Load /baton-xxx" 指令
  Deps: 1（W1.1 先执行作为临时修复；W1.5.4 执行后 W1.1 的改动被取代）
  Artifacts: none

- [ ] 9. Change: 引用式规则可行性调查——实验验证 AI 对 [AUDIT] 引用的遵循率（W1.5.5）⏳ deferred to separate session
  Files: none（调查）
  Verify: 记录实验结果到 plan Annotation Log；遵循率 < 70% 则标记 Wave 2 需内联标准
  Deps: 5（需要 W1.5.1 完成分类才能设计实验）
  Artifacts: 实验报告（记录在 plan Annotation Log）

### Wave 2 — 定向整合（基于 W1.5 重分类结果）

- [x] ✅ 10. Change: constitution 失败阈值 SSoT + skills/hooks 引用对齐（W2.1/C1）
  Files: `.baton/constitution.md`, `.baton/skills/baton-implement/SKILL.md`, `.baton/skills/baton-debug/SKILL.md`, `.baton/hooks/phase-guide.sh`, `.baton/hooks/failure-tracker.sh`
  Verify: grep "fail"/"threshold"/"repeatedly" 跨 .baton/，确认引用一致
  Deps: 7（W1.5.3 合并后 constitution 结构稳定）
  Artifacts: none

- [x] ✅ 11. Change: baton-implement discovery A/B/C/D 映射到 constitution Q1/Q2/Q3（W2.4/C5）
  Files: `.baton/skills/baton-implement/SKILL.md`
  Verify: 读取 discovery 分级，确认每级有 constitution Q 对应且行为一致
  Deps: 7（constitution 结构稳定后）
  Artifacts: none

- [x] ✅ 12. Change: review dispatch 优先级澄清——constitution review protocol + baton-review skip qualifier（W2.3/C3+C7）
  Files: `.baton/constitution.md`, `.baton/skills/baton-review/SKILL.md`
  Verify: 读取 constitution review protocol 和 baton-review skip 条件，确认无歧义
  Deps: 7（constitution 合并后）
  Artifacts: none

- [x] ✅ 13. Change: phase-guide "Spike with Bash" → removed by W1.5.4 de-duplication（W2.5/C8）
  Files: `.baton/hooks/phase-guide.sh`
  Verify: 读取 phase-guide RESEARCH 阶段输出，确认无 "spike" 措辞
  Deps: 8（phase-guide 去重后）
  Artifacts: none

### Wave 3 — 选择性硬化（基于 W1.5 重分类结果）

- [x] ✅ 14. Change: write-lock.sh 标记保护——检测 markdown 写入中的 BATON:GO/COMPLETE/OVERRIDE（W3.1/B7）
  Files: `.baton/hooks/write-lock.sh`
  Verify: 运行 write-lock 传入含 BATON:GO 的 markdown 写入，确认 block 或 warning
  Deps: 9（W1.5.5 feasibility spike 结果可能影响实现策略）
  Artifacts: none

- [x] ✅ 15. Change: post-write-tracker 越界升级——第 2 次同文件越界时升级警告（W3.2/B17）
  Files: `.baton/hooks/post-write-tracker.sh`
  Verify: 模拟 write set 外文件写入 2 次，确认第 2 次触发升级提示
  Deps: none
  Artifacts: none

- [x] ✅ 16. Change: BATON_TEST_CMD 配置 + completion-check 测试执行验证（W3.3/B10）
  Files: `.baton/hooks/_common.sh`, `.baton/hooks/completion-check.sh`
  Verify: 在配置了 BATON_TEST_CMD 的项目中，未运行测试时 completion-check 产生 warning
  Deps: none
  Artifacts: none

- [x] ✅ 17. Change: phase-guide PLAN 阶段复杂度早期验证提示（W3.4/B9）
  Files: `.baton/hooks/phase-guide.sh`
  Verify: 在 >3 files write set 的 plan 下启动 session，确认 PLAN 阶段输出复杂度提示
  Deps: 8（phase-guide 去重后）
  Artifacts: none

---

<!-- BATON:COMPLETE -->

## Retrospective

1. **Plan 没有预见到的**：BATON_PLAN 多计划歧义阻塞了所有写入，浪费了一轮调试。Plan 的 Risk Mitigation 没有覆盖"hook 自身阻止实施"的场景。未来涉及 hook 修改的 plan 应检查 hook 的前置条件（如多计划检测）是否会阻止实施本身。

2. **实施中的意外**：shared-protocols 合并到 constitution 后行数恰好到 500 行（plan 的阈值边界）。W1.5.5（引用式规则实验）被推迟但 Wave 2/3 仍然实施了——缺少实验数据的情况下做了 SSoT 决策，这是一个假设风险。Review 发现 write-lock 错误地阻止了 BATON:COMPLETE（constitution 明确允许 AI 添加），这是 constitution 规则细粒度差异被忽略的典型案例。

3. **下次会不同做的 research**：审计应该区分三种标记的语义差异（GO=授权，COMPLETE=确认，OVERRIDE=豁免）而不是把它们当作同一类"治理标记"。如果审计做了这个区分，plan 和 implementation 就不会把三者混为一谈。

## Authorization

<!-- BATON:GO -->

---

## Self-Challenge（已更新为 C→D 混合路径）

### 1. 最弱的结论是什么？什么证据能推翻它？

最弱的结论是 **W1.5.1（规则重分类）的三分类边界足够清晰**。某些规则处于 Hard Rule 和 Auditable Standard 的边界（如"AI 不得添加 BATON:GO"——当前无 hook 但理论上可 hook 化）。如果分类边界判断困难的规则数量 > 5，说明三分类框架可能不够。

**验证方式**: W1.5.1 实施时统计"边界情况"数量。如果 > 5 条，考虑引入第四类或调整分类标准。

次弱结论：**W3.1（markdown 标记保护）可行**。Hook 能否获取 tool input content 尚未验证。W3.1 有明确的 feasibility spike 和 descope 路径。

### 2. 没有调查什么应该调查的？

~~没有调查 AI 实际如何处理引用式规则。~~ → 已通过 W1.5.5 正式纳入计划，作为 Wave 1.5 的调查任务。W1.5.5 的实验结果将决定 Wave 2 的 SSoT 引用策略。

另一个未调查的：**shared-protocols 合并后 constitution 的体积**。当前 constitution 354 行 + shared-protocols 130 行 = ~484 行。接近但未超过 500 行阈值。需要关注合并后实际行数。

### 3. 做了什么假设没有验证？

1. **Wave 1 执行顺序**：W1.4 先于 W1.2 → 已提升到 Wave 1 正文（:110）✅
2. **重分类不改变规则实质内容**：W1.5 声称只改"呈现结构"。但添加 `[HARD]`/`[AUDIT]`/`[GUIDE]` 标注实际上**创建了新的语义层**——AI 会基于标注调整行为优先级。这是有意的设计效果，但应明确承认：W1.5 不只是"重新标注"，而是"重新定义 AI 对规则的理解方式"。
3. **phase-guide 去重后 AI 会主动加载 skill**：W1.5.4 假设 AI 看到 "Load /baton-implement" 就会实际调用 Skill tool。如果 AI 跳过了这一步（例如 context compact 后丢失了 phase-guide 的指导），则 AI 在 FINISH 阶段可能无任何指导。缓解：using-baton 的 Phase Routing 也会指向 skill，提供二次入口。
---

## 批注区

> 当前的是最佳方案实现了吗 如果从第一性原理来分析 还有更好的改进方案吗

### [Annotation 4] 第一性原理审视：是否存在更优方案

- **Trigger / 触发点**: 批注质疑当前 Approach C（分阶段修补）是否是第一性原理下的最优方案。
- **Intent as understood / 理解后的意图**: 当前计划是"在现有架构内修复已发现的问题"。批注要求退一步问：现有架构本身是否是问题？是否存在从根本上不同的改进路径？

- **Response / 回应**:

  为回答这个问题，量化了 Baton 的治理执行现状 [CODE] ✅：

  | 分类 | 规则数 | 占比 |
  |------|--------|------|
  | 硬执行（hook exit 2） | 7 | 21% |
  | 软执行（advisory，exit 0） | 9 | 27% |
  | 无 hook 执行 | 17 | 52% |
  | **合计** | **33** | 100% |

  **硬执行的 7 条规则**：write-lock（GO gate）、bash-guard（shell 写入）、completion-check（retrospective + todo + scope）。这些覆盖了"入口"（不能写）和"出口"（不能完成），但不覆盖"过程"（怎么写）。

  **完全无执行的 17 条规则**：包括证据模型（标签、状态标记）、挑战模型（反驳力度）、发现协议（Q1/Q2 判断）、假设有效性重检、artifact 结构等。这些规则的共同特征是：**它们约束的是 AI 推理质量，而非 AI 操作行为**——你无法写一个 hook 来验证"AI 是否真正考虑了替代假设"。

  这产生了一个第一性原理级的洞察：

  **当前架构的根本张力**：Baton 用"规则"（imperative language: must, must not, requires）来表述两种本质不同的东西：
  1. **操作约束**（"没有 GO 不能写代码"）— 可以机械执行
  2. **推理标准**（"每个发现必须有证据标签"）— 只能通过 review 事后评估

  但 constitution 和 skills 用相同的权威语气呈现两者，AI 无法区分"违反这条规则 hook 会阻止我"和"违反这条规则没有任何后果"。这不仅造成认知混乱，还使 AI 在上下文压力下优先遵守它碰巧记住的规则，而非最重要的规则。

  ---

  **从第一性原理推导的替代方案：Approach D — 治理简化（"Match rules to enforcement"）**

  核心理念：不是在现有 33 条规则内修补矛盾，而是重新分类规则以匹配执行能力。

  **Step 1: 重新分类**
  将 constitution 中的 33 条规则显式分为三类：

  | 类别 | 特征 | 执行方式 | 示例 |
  |------|------|---------|------|
  | **Hard Rule** | 操作约束，可机械验证 | Hook（exit 2） | GO gate、write set、completion |
  | **Auditable Standard** | 推理质量，可事后评估 | Review 检查清单 | 证据标签、挑战反驳力度、发现协议 |
  | **Guidance** | 最佳实践，边界模糊 | 无执行，AI 自律 | "re-read code after edit"、模板格式 |

  Constitution 中**显式标注**每条规则属于哪个类别。AI 看到 Hard Rule 知道 hook 会阻止它；看到 Auditable Standard 知道 review 会检查它；看到 Guidance 知道这是建议而非约束。

  **Step 2: 减少治理面**
  - 合并 shared-protocols 回 constitution（消除一个漂移源）
  - phase-guide.sh 不再硬编码 skill 内容，只输出"Load /baton-implement for FINISH workflow"（消除 phase-guide vs skill 漂移的整个类别）
  - review-prompt.md 基于 Auditable Standards 自动生成检查项（而非手动维护独立文件）

  **Step 3: 升级关键 Auditable Standards 为 Hard Rules**
  对最高风险的 Auditable Standards（如"AI 不能添加 BATON:GO"），寻找 hook 化路径（Wave 3 的内容）。

  ---

  **Approach C vs Approach D 对比**：

  | 维度 | C（分阶段修补） | D（治理简化） |
  |------|----------------|--------------|
  | 修复现有矛盾 | ✅ 直接修复 | ⚠️ 部分矛盾因规则消除而消失，剩余的仍需修复 |
  | 防止未来漂移 | ⚠️ SSoT 缓解但不根治 | ✅ 减少治理面 = 更少漂移表面 |
  | 降低 AI 认知负担 | ⚠️ 文本量不变 | ✅ 分类标注让 AI 知道什么重要 |
  | 实施风险 | 中 | 高（重分类影响所有文档） |
  | 向后兼容 | ✅ | ⚠️ constitution 结构变化 |
  | 独立增量交付 | ✅ 每 wave 独立 | ⚠️ Step 1 重分类是前置条件 |

  **诚实评估**：Approach D 从第一性原理上更优——它解决了"治理复杂度超过执行能力"的根本问题，而不只是修补执行能力内的矛盾。但它的实施成本显著更高，且 Step 1（重分类）是一个不可增量的前置条件。

  **可能的混合方案：C→D 路径**

  1. 先执行 Approach C 的 Wave 1（修复 2 个安全缺口，低风险，立即有价值）
  2. 在 Wave 2 之前，执行 Approach D 的 Step 1（重分类 33 条规则为 Hard Rule / Auditable Standard / Guidance）
  3. 用重分类后的框架指导 Wave 2 的 SSoT 整合——只对 Hard Rules 和 Auditable Standards 做 SSoT，Guidance 允许松散一致
  4. Wave 3 的硬化方向由重分类决定——只升级高风险 Auditable Standards

  这条路径保留了 Approach C 的增量交付优势，同时在 Wave 1 和 Wave 2 之间插入了 Approach D 的核心洞察（重分类），使后续 wave 更有针对性。

- **Status**: ✅ accepted — 批注暴露了当前计划的框架局限性
- **Impact**: affects conclusions — 建议修改计划为 C→D 混合路径：Wave 1 不变，Wave 1 和 Wave 2 之间插入"规则重分类"步骤，Wave 2/3 基于重分类结果调整。如果人类同意此方向，需要修订 Wave 2 和 Wave 3 的设计。

---

### [Annotation 5] Self-Challenge #2 "需要调查"

- **Trigger / 触发点**: Self-Challenge 第 2 点（AI 如何处理引用式规则）被标注为"需要调查"。
- **Intent as understood / 理解后的意图**: 不只是标记为未知，而是要求实际开展调查。
- **Response / 回应**:

  这个问题与 Approach D 直接相关。如果重分类后规则带有显式标签（Hard Rule / Auditable Standard / Guidance），AI 处理"引用"的问题可能被重新框定：

  - **Hard Rules**: 不需要 AI "记住"规则——hook 强制执行，AI 违反时会被阻止
  - **Auditable Standards**: AI 需要在 review 时看到完整标准——但 review 是独立 dispatch，可以在 review prompt 中内联完整标准
  - **Guidance**: 引用即可，不遵守没有后果

  这意味着"AI 能否处理引用式规则"的问题被分解为：
  - Hard Rules → 不需要引用（hook 执行）
  - Auditable Standards → 引用问题转移到 review prompt（review prompt 是 review 的输入，可以包含完整文本）
  - Guidance → 引用足够（无执行后果）

  **调查建议**：在 Wave 1 完成后、Wave 2 设计前，做一个轻量级实验：让 AI 在一个 session 中只看到 constitution 的 Auditable Standards 引用（不看完整文本），然后用 baton-review 检查 AI 是否遵循了这些标准。如果遵循率低，确认需要在 review prompt 中内联完整标准而非引用。

- **Status**: ✅ accepted — 调查需求合理，已整合到 C→D 混合路径的时序中
- **Impact**: affects conclusions — 调查时间点应在 Wave 1 完成后、Wave 2 设计前。调查结果决定 Wave 2 的"SSoT 引用"策略是否可行。
- 
<!-- BATON:GO -->
# Baton 技能系统审计：技能间矛盾与流程断点

审计方法：从 AI 实际运行时行为出发，逐一交叉比对所有技能文件（SKILL.md）、
constitution.md、shared-protocols.md、hooks、review-prompt、template，
识别规则冲突和流程断裂。

审计范围：`.baton/` 下全部技能、hook、协议文件。

---

## 第一部分：技能间矛盾

### C1. 失败阈值：constitution vs baton-implement vs baton-debug vs failure-tracker

**矛盾描述**

四个地方定义了"什么时候停下来"，数字不同：

| 来源 | 阈值 | 原文 |
|------|------|------|
| constitution.md :172 | >1（即 ≥2） | "Repeatedly means more than one failed attempt under the same underlying hypothesis" |
| baton-implement :65 | 3 | "3-failure limit (3 failed remediation attempts for the same blocking issue)" |
| baton-debug :84-86 | 3 | "3 hypothesis tests that produced no significant new evidence → stop" |
| failure-tracker.sh :55-58 | 3 和 5 | 工具失败累计到 3 和 5 时告警 |
| phase-guide.sh :159 | 3 | "Same approach fails 3x → STOP and report" |

**技术上一致性**：constitution 允许 phase skill 覆盖默认阈值（"unless the active phase skill defines a different threshold"）。所以 implement 和 debug 定义 3 是合法的。

**AI 运行时问题**：
- AI 在 constitution always-loaded 的情况下看到 ">1 failed attempt"，可能在第 2 次失败就停下来
- 但如果加载了 baton-implement，会看到 "3-failure limit"
- 如果两个都在上下文中（constitution 总是在），AI 面对第 2 次失败时：是按 constitution 停？还是按 implement 继续到第 3 次？
- constitution 说 "when in doubt, interpret conservatively" — 这会让 AI 倾向于在第 2 次就停下来，与 implement 的 3 次设计意图矛盾
- **failure-tracker.sh 在 3 次时告警但不阻断**，而 baton-implement 说 3 次时 STOP——hook 层面无法强制执行 STOP

**严重度**：中。AI 可能在第 2 次或第 3 次停止，行为不可预测。

---

### C2. FINISH 阶段指导遗漏了 Implementation Review

**矛盾描述**

phase-guide.sh 检测到 FINISH 阶段时输出的指导：
```
📍 FINISH phase — all tasks complete. Complete the completion workflow (baton-implement Step 5):
   1. Append ## Retrospective to $PLAN_NAME
   2. Run the full test suite to verify nothing is broken
   3. Mark complete: add <!-- BATON:COMPLETE -->
   4. Decide branch disposition
```

但 baton-implement Step 5 实际是：
```
1. Implementation review (dispatch baton-review)  ← 遗漏
2. Full test suite
3. Retrospective
4. Mark complete
5. Branch disposition
```

phase-guide 跳过了 **Implementation Review（baton-review dispatch）**——这是 baton-implement Step 5 的第一步，也是唯一的对抗性审查点。

**AI 运行时问题**：
- 新 session 中 AI 进入 FINISH 阶段，看到 phase-guide 的 4 步指导
- AI 没有加载 baton-implement skill（除非主动调用），跟着 phase-guide 走
- 结果：跳过 implementation review，直接写 retrospective → 标记 COMPLETE
- 对抗性审查被完全绕过

**严重度**：高。这是一个实际的安全护栏缺口——phase-guide 的指导直接跳过了完成前的唯一审查步骤。

---

### C3. Review 选择权：phase skills "优先 dispatch" vs shared-protocols "工程判断"

**矛盾描述**

phase skills（research/plan/implement）都说：
> Dispatch baton-review via Agent tool... Fallback: explicit self-review

shared-protocols.md Section 3 说：
> Choose the review strategy based on engineering judgment, not form preference.

**AI 运行时问题**：
- AI 知道两个指令，选择路径取决于哪个更显著
- "engineering judgment" 给了 AI 一条合法的绕过路径——"我判断 self-review 更合适"
- 实际上 self-review 几乎总是更快更省力，AI 有动机选择它
- Phase skill 说 "preferred: independent review"，但不是 "mandatory"
- 结果：AI 大概率选择 self-review，context-isolated review 很少真正发生

constitution 说 "phase skill wins on procedure"。但 phase skill 本身说 "preferred" 而非 "required"，然后引用 shared-protocols 说 "choose based on judgment"。这种委托关系让 AI 有理由选择任意一条路径。

**严重度**：中。Review isolation 是 baton-review 的核心设计原则，但实际执行率可能很低。

---

### C4. Plan 呈现方式：枚举多个方案 vs 只呈现推荐方案

**矛盾描述**

baton-plan SKILL.md Step 1 说：
> Solution categories — enumerate fundamentally different approaches

baton-plan Step 4 说：
> Recommend with Reasoning — State why the chosen approach wins and why the main alternative categories were rejected

review-prompt.md 说：
> Are 2-3 approaches presented with trade-offs visible to the human?
> Or did the author internally enumerate and silently reject, presenting only the winner?

**AI 运行时问题**：
- Step 1 说 "enumerate"（内部行为？输出？不明确）
- Step 4 说 "recommend"（呈现一个推荐 + 拒绝理由）
- review-prompt 明确要求 "2-3 approaches presented"
- SKILL 本身没有明确说 "在 plan 文档中呈现所有被评估的方案"
- AI 可能只在内部推理中枚举，plan 文档中只写推荐方案
- Review 会抓住这个问题——但 review 可能被跳过（见 C3）

**严重度**：低。Review 能捕获，但 SKILL 和 review-prompt 之间存在预期偏差。

---

### C5. "持续执行" vs Discovery Protocol 的张力

**矛盾描述**

baton-implement Step 2（粗体强调）：
> CONTINUOUS EXECUTION: Once the user says "implement", execute ALL Todo items to completion
> without pausing between items. Only stop for: blocking errors, C/D unexpected discoveries,
> or 3-failure limit.

constitution Discovery Protocol Q1/Q2：
> If any answer is no → move to BLOCKED... Report the discovery and its impact to the human.

**AI 运行时问题**：
- "CONTINUOUS EXECUTION" 创建了强烈的执行惯性
- 当 AI 遇到一个 borderline B/C 级发现时，"CONTINUOUS EXECUTION" 的惯性会推动 AI 将其分类为 B 级（可以继续）而非 C 级（必须停止）
- baton-implement 的 A/B/C/D 分级与 constitution 的 Q1/Q2/Q3 是不同的框架：
  - A/B → 大致对应 Q3（继续）
  - C/D → 大致对应 Q1/Q2（停止）
  - 但映射不精确——constitution 的 Q1 问 "assumptions still valid?"，implement 的 C 问 "new capability or file surface?"
- AI 在两个框架之间切换时可能不一致

baton-implement Red Flags 试图缓解（"This small change isn't in the plan but makes sense" → Stop），但 "CONTINUOUS EXECUTION" 的心理惯性是真实的。

**严重度**：中。Discovery 分级的边界判断受执行惯性影响。

---

### C6. baton-review Iron Law vs 人类触发模式

**矛盾描述**

baton-review Iron Law：
> REVIEW THE ARTIFACT, NOT THE INTENT — you have no generation context

baton-review Invocation（人类触发）：
> Human-initiated: Runs within the current session context (no isolation).
> Treat as weaker than subagent review due to session history influence.

**AI 运行时问题**：
- Iron Law 说 "you have no generation context"——这在人类触发模式下是假的
- AI 执行人类触发的 /baton-review 时，有完整的 session 历史
- Iron Law 要求它忽略这些上下文，但认知上不可能——已经看到的信息无法 "unsee"
- 技能承认了这一点（"treat as weaker"），但 Iron Law 的措辞是绝对的（"you have no generation context"），不是条件的
- AI 可能试图假装没有上下文（不真实），或承认有上下文但尝试独立判断（与 Iron Law 矛盾）

**严重度**：低。已有缓解（"treat as weaker"），但 Iron Law 的措辞应调整。

---

### C7. Implement 完成审查 "mandatory" vs baton-review "may skip"

**矛盾描述**

baton-implement Step 5：
> Implementation review — dispatch baton-review via Agent tool with review-prompt.md

没有任何 skip 条件。语气是强制的（Step 5 的第一步，后面说 "Fix findings, then re-review"）。

baton-review（When Review is Mandatory）：
> May skip only when all of the following are true: single-surface, no control flow / contract /
> validation change, no alternative trade-offs, and no semantic behavior change

**AI 运行时问题**：
- AI 完成一个 trivial 的单文件修改（改个 typo）
- baton-implement Step 5 说 "dispatch review"——无例外
- baton-review 说 "may skip if single-surface and no contract change"
- AI 引用 baton-review 的 skip 条件来跳过 baton-implement 的强制步骤
- 哪个 skill 权威？Constitution 说 "phase skill wins on procedure"，但两个都是 phase skills（implement 和 review 都在 Authority Model L3）
- 结果：AI 遇到冲突时可以自由选择，很可能选择 skip

**严重度**：中。Trivial 实现的审查可能被系统性跳过。

---

### C8. Research "NO SOURCE CODE CHANGES" vs phase-guide "Spike with Bash"

**矛盾描述**

baton-research Iron Law：
> NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY

phase-guide.sh RESEARCH 阶段的 fallback 指导：
> Spike with Bash.

**AI 运行时问题**：
- "Spike with Bash" 意味着运行实验性命令——可能包括创建测试脚本、修改临时文件
- 但 research Iron Law 禁止源代码变更
- write-lock 在 RESEARCH 阶段（无 plan）会阻止所有非 markdown 写入——所以 hook 层面是一致的
- 但 bash-guard 在无 plan 时会放行读取类 bash 命令，只阻止文件写入模式
- "Spike with Bash" 的用户心智模型可能包括 `node -e "..."` 或 `python -c "..."` 等——这些不被 bash-guard 拦截
- 矛盾在于 phase-guide（hook）建议 spike，但 research skill（规则）禁止 source changes

**严重度**：低。Hook 层面一致（write-lock 阻止写入），但指导层面矛盾。

---

### C9. Annotation Log：被引用 6 次，从未定义

**矛盾描述**

以下位置提到 `## Annotation Log`：
- baton-debug :118 — "Resolved within IMPLEMENT → Plan `## Annotation Log` only"
- phase-guide.sh :182 — "Record in ## Annotation Log"
- stop-guard.sh :44 — "The Annotation Log records design decision rationale"
- pre-compact.sh :48-49 — 检测 `## Annotation Log` 存在性

但 **没有任何文件定义** Annotation Log 的格式、内容要求或与 `## 批注区` 的关系。

对比：`## 批注区` 在 shared-protocols.md Section 4 有完整的格式模板、处理规则和升级启发式。

**AI 运行时问题**：
- AI 被要求 "Record in ## Annotation Log" 但没有格式指导
- AI 可能：
  - 用 批注区 格式写（错——它们是不同的 section）
  - 自由格式写（不一致）
  - 根本不写（丢失可追溯性）
- pre-compact.sh 检查它是否存在，但不检查内容
- 这是一个 **幽灵概念**——被引用但未被定义

**严重度**：中。影响实现阶段的决策可追溯性。

---

### C10. Plan 中的五类注释 section，只有一个有定义

**矛盾描述**

plan 文件中可能出现的注释/记录 section：

| Section | 来源 | 有格式定义？ |
|---------|------|-------------|
| `## 批注区` | constitution Artifact Model, shared-protocols S4 | ✅ 完整模板 |
| `## Annotation Log` | phase-guide, stop-guard, baton-debug | ❌ |
| `## Implementation Notes` | baton-implement Step 4 | ❌ |
| `## Lessons Learned` | baton-implement Session Handoff | ❌（只有内容要求，无格式） |
| `## Retrospective` | baton-implement Step 5 | ❌（只有三个问题，无格式） |

**AI 运行时问题**：
- AI 在同一个 plan 文件中维护 5 种不同的注释 section
- 只有 批注区 有明确的格式要求
- 其他 4 个 section 的内容边界模糊——什么该记在 Annotation Log vs Implementation Notes？
- baton-implement 区分了 Lessons Learned（中途停止）和 Retrospective（完成后），但没有区分 Annotation Log 和 Implementation Notes

**严重度**：低。功能性影响小，但增加认知负担和不一致风险。

---

### C11. baton-implement Todo 项 schema：SKILL 说 5 个字段，plan schema 说的不完全相同

**矛盾描述**

baton-implement Step 1：
> Each item must have five fields: Change (what), Files (write set), Verify (validation command),
> Deps (blocked by), Artifacts (produced)

baton-plan Todo List Format：
```markdown
- [ ] 1. Change: description
  Files: `a.ts`, `b.ts`
  Verify: how to verify
  Deps: none
  Artifacts: none
```

baton-subagent Prerequisites：
> Each Todo item dispatched to a subagent MUST have: Files:, Verify:, Deps:

plan-parser.sh 只解析：
- `^- \[` 模式的 Todo 项（todo counts）
- `Files:` 字段（write set extraction）
- 不解析 Change/Verify/Deps/Artifacts

**AI 运行时问题**：
- 如果 AI 漏了 `Artifacts:` 字段，没有任何检查会捕获
- 如果 AI 写了 `Verification:` 而非 `Verify:`，parser 不在乎（它不解析 Verify），但 baton-subagent 可能找不到
- review-prompt 检查 "Are Files: fields present and accurate?" 但不检查其他四个字段
- Todo schema 的执行完全依赖 AI 的自律和 review

**严重度**：低。schema 验证缺失但不影响核心功能。

---

## 第二部分：流程断点

### B1. ANNOTATION → IMPLEMENT：BATON:GO 的放置无工具支持

**断点描述**

constitution 要求人类在 plan 中放置 `<!-- BATON:GO -->`。但：
- `baton` CLI 没有 `baton approve` 或 `baton go` 命令
- 人类必须手动打开 .md 文件，输入精确的字符串 `<!-- BATON:GO -->`
- 如果格式错误（如 `<!-- BATON: GO -->` 多了空格），hook 检测不到

**AI 运行时表现**：
- AI 完成 plan，提示 "Human adds `<!-- BATON:GO -->` when satisfied"
- 人类不知道怎么加——尤其是不熟悉 markdown comment 语法的用户
- 人类可能要求 AI "帮我加"——AI 受 Iron Law 约束不能加
- 结果：流程卡在 ANNOTATION 阶段，需要人类有 markdown 编辑经验

**严重度**：中。这是一个 UX 瓶颈，影响非技术用户的可用性。

---

### B2. Research → Plan：无显式交接指令

**断点描述**

baton-research 有 Exit Criteria（Step 6, Convergence Check），定义了 research 完成的条件。但完成后的下一步操作不明确：
- 技能不说 "现在调用 /baton-plan"
- 技能不说 "告诉人类 research 完成了"
- 技能只说 "Before transitioning to plan"——暗示转换会发生，但不说谁触发

**AI 运行时表现**：
- 情况 1（同一 session）：AI 完成 research，然后... 停下来？自动开始 plan？等人类说话？
  - using-baton 的 Phase Routing 表说 PLAN → /baton-plan，但不说何时触发
  - AI 可能自行调用 /baton-plan（可能过于主动）或等待人类指令（可能过于被动）
- 情况 2（新 session）：phase-guide 检测到 PLAN 阶段，输出指导——这条路径是清晰的
- 关键问题在情况 1：same-session 的阶段转换没有定义

**严重度**：低。新 session 的路径清晰，同 session 的路径靠 AI 判断（通常足够）。

---

### B3. 人类批注周期：Session 内无检测机制

**断点描述**

Annotation 流程：
1. AI 创建 plan，包含 `## 批注区`
2. 人类在 批注区 写批注
3. AI 处理批注（per shared-protocols Section 4）
4. 循环直到人类满意

但步骤 2→3 没有自动触发机制。phase-guide.sh 能检测到 "📝 Unprocessed content detected in 批注区"——但这只在 SessionStart 触发。

**AI 运行时表现**：
- AI 呈现 plan，等待人类反应
- 人类在文件中写批注（AI 看不到——没有 file-watch hook）
- 人类必须显式告诉 AI "我写了批注" 或 "读一下 plan"
- 如果人类只是编辑文件然后等待——什么都不会发生
- 下一个 session 才能自动检测到

**严重度**：低。这是 AI coding 工具的通用限制（不能 watch 文件变更），不是 baton 特有问题。

---

### B4. baton-research 步骤 vs 模板 section 映射不对齐

**断点描述**

| SKILL 步骤 | 模板 Section | 状态 |
|-----------|-------------|------|
| Step 0: Frame | `## Frame` | ✅ 对齐 |
| Step 0.25: Orient | `## Orient` | ✅ 对齐 |
| Step 0.5: Investigation Methods | `## Investigation Methods` | ✅ 对齐 |
| Step 0.75: Dimension Decomposition | ??? | ❌ 无对应 section |
| Step 1: Investigation Targets | ??? | ❌ 无对应 section |
| Step 2: Reduce Uncertainty | `## Investigation` (by moves) | ⚠️ 隐含映射 |
| Step 2b: Synthesize | `## Cross-Move Synthesis` | ✅ 对齐 |
| Step 2c: Counterexample Sweep | `## Counterexample Sweep` | ✅ 对齐 |
| Step 3: Evidence Standards | （无 section，贯穿所有 section）| ⚠️ 隐含 |
| Step 4: Self-Challenge | `## Self-Challenge` | ✅ 对齐 |
| Step 5: Review | `## Review` | ✅ 对齐 |
| Step 6: Convergence | `## Final Conclusions` + `## Questions` | ⚠️ 部分对齐 |

**AI 运行时表现**：
- AI 遵循 SKILL 步骤执行 Step 0.75（Dimension Decomposition），产生了维度分解结果
- 打开模板看输出结构——没有 Dimension Decomposition section
- AI 必须自行决定把维度分解放在哪里（Orient 里？Investigation 前？新建 section？）
- 类似地，Investigation Targets（Step 1）没有模板位置——它们是 Investigation moves 的输入，但不是输出 section
- 结果：不同 session 的 AI 会把同类内容放在不同位置，research 文档结构不一致

**严重度**：低。功能性影响小，但降低了 research 文档的可预测性。

---

### B5. baton-review 的 Context Isolation 无法验证

**断点描述**

baton-review：
> When dispatching, verify that the subagent received only artifact text and review criteria —
> no conversation history or generation context should leak. If isolation cannot be verified,
> treat as untrusted.

但 AI 无法检查 subagent 收到了什么。Agent tool 接受一个 prompt，AI 不能 inspect subagent 的完整上下文。

**AI 运行时表现**：
- Phase skill（如 baton-plan）dispatch review via Agent tool
- Agent 子进程启动，加载 SessionStart hook → 注入 using-baton
- 子进程可能还加载了其他上下文（conversation history 不会泄漏，但 skill context 会）
- baton-review 说 "verify isolation"——AI 无法做到，只能 trust the mechanism
- "If isolation cannot be verified, treat as untrusted" → 逻辑上，AI 永远无法验证 → 所有 dispatch review 都应被视为 untrusted → 但这会使 dispatch review 无意义

**严重度**：低。实际中 Agent tool 的隔离性是足够的（无 conversation history），但 "verify" 的要求不可执行。

---

### B6. Circuit Breaker 和 baton-debug 的 Post-Escalation 状态未定义

**断点描述**

三个 escalation 路径都通向 "escalate to human"，但没有定义 post-escalation 行为：

| 来源 | Escalation | Post-escalation 行为 |
|------|-----------|---------------------|
| baton-review | 3 revision cycles with high severity | "escalate to the approving human" — 然后？ |
| baton-plan Step 6 | circuit breaker | "escalate to human" — 然后？ |
| baton-debug Phase 3 | 3 hypothesis tests | "stop and escalate" — 然后？ |
| baton-research Step 5 | circuit breaker | "escalate to human" — 然后？ |

constitution State Model 有 BLOCKED 状态，但这些 escalation 路径没有显式引用它。

**AI 运行时表现**：
- baton-plan dispatch review 失败 3 次
- AI 执行 "escalate to human"——给人类发消息说 "review 持续失败"
- 然后呢？AI 处于什么状态？BLOCKED？ANNOTATION？
- AI 不确定能否继续其他工作，还是必须等人类响应
- 人类看到消息后，应该做什么？修改 plan？override review？
- 没有任何指导

**严重度**：中。Escalation 后 AI 进入未定义状态，可能导致 session 卡死或 AI 自行选择不当行为。

---

### B7. Markdown 写入 Gap：AI 可修改关键标记

**断点描述**

write-lock.sh :58-60：
```bash
case "$TARGET" in
    *.md|*.MD|*.markdown|*.mdx) exit 0 ;;
esac
```

所有 markdown 写入无条件放行。这意味着 AI 可以：
- 在 plan.md 中添加 `<!-- BATON:GO -->` — constitution 禁止但 hook 不拦截
- 在 plan.md 中添加 `<!-- BATON:COMPLETE -->` — 同上
- 在 plan.md 中添加 `<!-- BATON:OVERRIDE -->` — 同上
- 删除 research.md 中的不利发现
- 修改 plan.md 扩大 write set（然后利用扩大后的 write set 修改源码）

**AI 运行时表现**：
- 正常情况下，AI 遵守 constitution 的指令不会做这些事
- 但如果 AI 的指令被覆盖（prompt injection、context 溢出后丢失规则、bug in skill loading），这些操作没有硬阻断
- constitution.md 在 compact 后可能被压缩——这时 AI 可能丢失 "AI must never add this marker" 的指令
- pre-compact.sh 保存的是 phase 和 progress 信息，不保存 "不要修改标记" 的规则

**严重度**：中。这是有意设计（markdown 必须可写），但标记保护纯靠规则注入，无防御深度。

---

### B8. Stale Research 无检测机制

**断点描述**

baton-plan Step 2：
> Plans MUST derive approaches from validated inputs — don't jump to "how" without
> tracing back to "why". If a ## Final Conclusions section exists, derive from there.

但如果 research 是 3 个 session 前做的，期间代码已经变了呢？

**AI 运行时表现**：
- AI 进入 PLAN 阶段，读取 research.md
- research.md 的 Final Conclusions 基于 3 个 session 前的代码状态
- 代码可能已经被其他人或其他分支修改
- AI 按照过期的 research conclusions 制定 plan
- 没有 hook、没有 skill 指令提醒 "检查 research 的时效性"
- constitution Core Invariant 5（No stale authorization）适用于 authorization，不明确适用于 research findings

**严重度**：中。尤其在多人协作或长周期任务中，可能导致 plan 基于错误前提。

---

### B9. 复杂度自评估：AI 自行决定，无验证

**断点描述**

baton-plan Complexity-Based Scope：
> Complexity is proposed by AI and may be corrected by the human if the scope,
> risk, or review depth appears misclassified.

baton-research When to Use：
> When NOT to use: Quick lookups, single-file explanations, Trivial/Small tasks.

**AI 运行时表现**：
- AI 收到任务 "修改 X 的行为"
- AI 自评：Trivial → 跳过 research，写 3-5 行 plan contract
- 实际上 X 有 5 个消费者、涉及跨模块数据流——应该是 Medium
- phase-guide.sh 有一个事后提示：如果 plan touches >3 files 但没有 Surface Scan，提醒 "consider upgrading"
- 但这个提示只在 ANNOTATION 阶段（plan 已写完后）才触发
- 结果：AI 已经用 Trivial 模式写了 plan，收到提示后需要重写——浪费了一个 plan-review 周期
- 更糟：如果 human 看到 Trivial plan 直接加 BATON:GO，复杂度不足的 plan 就被执行了

**严重度**：中。复杂度降级是 AI 最常见的偏差之一，当前只有事后检测。

---

### B10. "Full Test Suite" 无定义、无执行

**断点描述**

baton-implement Step 5：
> Full test suite — run the project's complete suite (as defined by repo conventions or plan)

baton-implement（粗体强调）：
> NO BATON:COMPLETE WITHOUT FULL TEST SUITE PASS.

但：
- 没有配置定义 "full test suite" 是什么命令
- completion-check.sh 只检查 Retrospective，不检查测试是否跑过
- stop-guard.sh FINISH 指导说 "Run the full test suite" 但不知道跑什么

**AI 运行时表现**：
- AI 到了 FINISH 阶段，被告知 "run the full test suite"
- AI 必须猜测测试命令：`npm test`？`pytest`？`make test`？`bash tests/test-full.sh`？
- 如果猜错了，可能跑了部分测试就认为 "full suite passed"
- 没有 hook 验证测试是否真的通过
- AI 可以说 "I ran the tests and they passed" 而不实际运行（违反 Iron Law "VERIFY = VISIBLE OUTPUT"，但无 hook 拦截）

**严重度**：中。"Full test suite" 是 completion 的硬要求，但完全靠 AI 自律执行。

---

### B11. 外部 Skill 合规检查：无自动化，靠记忆

**断点描述**

using-baton：
> when any skill produces a document, check compliance with both the Artifact Model
> invariants and shared-protocols.md. If non-compliant, fix before presenting to the human.

但：
- 没有 PostToolUse hook 检查 skill output 的合规性
- quality-gate.sh 只检查 plan/research 文件的 Self-Challenge section
- 外部 skill（如 superpowers:brainstorming）产生的文档不会被自动检查
- using-baton 在 SessionStart 注入，但 context compact 后可能丢失

**AI 运行时表现**：
- AI 调用 superpowers:brainstorming，产生一个 brainstorming.md
- brainstorming.md 没有 `## 批注区`、没有证据标签、不在 `baton-tasks/` 目录
- AI 应该修正这些问题——但 using-baton 的指令可能已被 compact
- 结果：非合规文档直接呈现给人类

**严重度**：低。外部 skill 产生的文档通常不是治理关键路径。

---

### B12. Phase Boundary 的 Markdown 穿透

**断点描述**

phase-guide.sh 通过文件系统检测阶段。write-lock.sh 放行所有 markdown 写入。

**AI 运行时表现**：
- AI 在 RESEARCH 阶段
- AI 创建 `baton-tasks/x/plan.md`（markdown，write-lock 放行）
- 下一次 phase-guide 检测：发现 plan 存在 → 阶段变为 ANNOTATION
- AI 跳过了 research 的 Exit Criteria、Convergence Check、Final Conclusions
- 没有任何检查阻止过早创建 plan 文件

- 类似地，AI 可以在 ANNOTATION 阶段创建 Todo list（plan 中添加 `## Todo`）——即使人类没有说 "generate Todo list"（baton-plan Iron Law 禁止，但无 hook 拦截）

**严重度**：低-中。阶段检测是基于文件存在性的，markdown 写入的无条件放行允许 AI 通过创建文件来人为推进阶段。

---

### B13. Self-Check "Re-read Code, Not from Memory" 不可执行

**断点描述**

baton-implement Self-Checks #1：
> Re-read code, not from memory — after every edit

**AI 运行时表现**：
- AI 使用 Edit tool 修改文件，Edit 返回 diff（不是完整文件）
- AI 认为 "我看到了 diff，我知道文件现在的状态" — 这是 "from memory" 还是 "re-read"？
- 严格来说，要满足 "re-read"，AI 应该在每次 Edit 后调用 Read tool 读取完整文件
- 但没有 hook 强制 Read-after-Edit
- AI 大概率依赖 Edit 的返回值而非重新 Read，因为 Read 消耗一次工具调用和 context 空间

**严重度**：低。这是一个良好实践指导，但强制执行不现实（每次 Edit 后 Read 会显著增加 latency）。

---

### B14. Template 文件路径解析

**断点描述**

baton-research Step 0.25：
> Codebase-primary → Read `./template-codebase.md` and use its output structure.

`./` 相对于什么？相对于 SKILL.md 所在目录？相对于 cwd？

**AI 运行时表现**：
- AI 通过 /baton-research 加载 skill（Skill tool 注入内容，不暴露文件路径）
- Skill 说 "Read `./template-codebase.md`"
- AI 不知道 skill 文件在哪——需要搜索
- AI 可能搜索 `**/template-codebase.md`，找到 `.baton/skills/baton-research/template-codebase.md`
- 或者 AI 猜测路径（基于 skill 名称推断目录结构）
- 通常能找到，但增加了一步不确定性

**严重度**：低。AI 通常能通过搜索找到，但增加了额外工具调用。

---

### B15. baton-debug Escalation 不引用 Constitution BLOCKED 状态

**断点描述**

baton-debug Escalation Criteria：
> Root cause confirmed, but plan assumptions wrong / write set exceeded → Escalate to RESEARCH/PLAN update

constitution State Model：
> Any → BLOCKED: triggered by discovery protocol (Q1/Q2), unresolved challenge, or failure boundary.

baton-debug 说 "escalate to RESEARCH/PLAN update" 但不说 "move to BLOCKED state"。

**AI 运行时表现**：
- AI 在 IMPLEMENT 中进入 baton-debug
- Debug 发现 plan assumptions 有问题
- baton-debug 说 "escalate to RESEARCH/PLAN update"
- AI 理解为 "修改 plan"——可能直接开始修改 plan（这是合法的，markdown 写入被放行）
- 但没有经历 BLOCKED → re-approval 的状态转换
- constitution 说 "If BATON:GO was invalidated (Q1 or Q2), renewed BATON:GO is required"
- baton-debug 没有说 "invalidate BATON:GO"
- 结果：AI 可能修改 plan 但保留旧的 BATON:GO，继续在修改后的 plan 下执行——没有人类 re-approval

**严重度**：高。这是一个真实的安全缺口——baton-debug 的 escalation 路径绕过了 constitution 的 re-approval 要求。

---

### B16. Retrospective 质量门控只数行数

**断点描述**

completion-check.sh :55-56：
```bash
if ! parser_retro_valid; then
    echo "## Retrospective exists but has only ${RETRO_LINE_COUNT:-0} content line(s) — need ≥3."
```

parser_retro_valid（plan-parser.sh :299-314）：
```bash
parser_retro_valid() {
    ...
    RETRO_LINE_COUNT="$(awk '...' "$_plan")"
    [ "$RETRO_LINE_COUNT" -ge 3 ] 2>/dev/null
}
```

只检查 ≥3 非空行。不检查是否回答了三个必需问题：
1. What did the plan get wrong?
2. What surprised you during implementation?
3. What would you research differently next time?

**AI 运行时表现**：
- AI 写 3 行通用内容："Everything went as planned. No surprises. Research was adequate."
- completion-check 通过（≥3 行）
- 但 Retrospective 的过程改进价值为零
- baton-implement Step 5 说 "≥3 lines: wrong predictions, surprises, research improvements"——质量要求存在但无执行

**严重度**：低。Retrospective 的质量靠 AI 自律，hook 只保证最低存在性。

---

## 第三部分：严重度汇总

### 高严重度（安全缺口）

| ID | 问题 | 影响 |
|----|------|------|
| C2 | FINISH 指导遗漏 implementation review | 完成前的对抗性审查被绕过 |
| B15 | baton-debug escalation 不引用 BLOCKED 状态 | plan 修改后 AI 可能继续执行而无 re-approval |

### 中严重度（行为不可预测或安全弱化）

| ID | 问题 | 影响 |
|----|------|------|
| C1 | 失败阈值矛盾（2 vs 3） | AI 停止时机不可预测 |
| C3 | Review dispatch vs engineering judgment | dispatch review 实际执行率低 |
| C5 | CONTINUOUS EXECUTION vs Discovery Protocol | 边界发现可能被降级 |
| C7 | Implement review mandatory vs review skip conditions | Trivial 实现审查被跳过 |
| C9 | Annotation Log 从未定义 | 实现阶段决策不可追溯 |
| B1 | BATON:GO 无工具支持 | 非技术用户 UX 瓶颈 |
| B6 | Circuit breaker post-escalation 未定义 | AI 进入未定义状态 |
| B7 | Markdown 写入可修改关键标记 | 标记保护无防御深度 |
| B8 | Stale research 无检测 | plan 可能基于过期信息 |
| B9 | 复杂度自评估无验证 | AI 系统性降级复杂度 |
| B10 | "Full test suite" 无定义无执行 | 完成条件靠自律 |

### 低严重度（次优但可工作）

| ID | 问题 | 影响 |
|----|------|------|
| C4 | Plan 多方案呈现预期偏差 | review 能捕获 |
| C6 | baton-review Iron Law vs human-invoked | 已有 "treat as weaker" 缓解 |
| C8 | "Spike with Bash" vs "NO SOURCE CODE CHANGES" | hook 层面一致 |
| C10 | Plan 中 5 类注释 section | 认知负担增加 |
| C11 | Todo schema 字段验证缺失 | 不影响核心功能 |
| B2 | Research → Plan 无显式交接 | 新 session 路径清晰 |
| B3 | Session 内批注检测 | AI 工具通用限制 |
| B4 | Skill 步骤 vs 模板 section 不对齐 | 文档结构不可预测 |
| B5 | Review isolation 不可验证 | Agent tool 的隔离性实际足够 |
| B11 | 外部 skill 合规无自动化 | 非关键路径 |
| B12 | Markdown 穿透 phase boundary | 需 AI 配合 |
| B13 | Self-check re-read 不可执行 | 实践指导 |
| B14 | Template 路径解析 | 搜索可解决 |
| B16 | Retrospective 只检查行数 | 质量靠自律 |

---

## 第四部分：系统性模式

从上述 27 个发现中可以识别出三个系统性模式：

### 模式 A：规则层定义了但 hook 层不执行

constitution/skills 定义了大量治理规则，但只有少数通过 hook 硬执行：
- ✅ 硬执行：write-lock（plan + GO）、bash-guard（shell 写入）、completion-check（retrospective）
- ❌ 纯规则：BATON:GO 标记权限、write set 边界（仅 warn）、review dispatch、full test suite、failure boundary STOP、evidence labels、self-challenge depth

这创造了一个 **合规梯度**：最核心的约束（"没有 plan 不能写代码"）有硬执行，其他约束靠 AI 自律。问题在于规则文档没有区分这两类——读者（包括 AI）看到所有规则以相同的权威性呈现，但实际执行力不同。

### 模式 B：Escalation 路径通向未定义状态

baton-review circuit breaker、baton-debug escalation、baton-subagent BLOCKED——多条路径都以 "escalate to human" 结束，但没有定义 post-escalation 协议。AI 到达 escalation 点后的行为依赖于它自己的判断，这恰恰是在 AI 判断已经被证明不足（才需要 escalation）的情况下。

### 模式 C：Phase-guide hook 与 phase skill 的覆盖不一致

phase-guide.sh 是 SessionStart 时的唯一阶段指导来源。如果它的指导与 phase skill 不一致（如 C2 中 FINISH 阶段遗漏 review），AI 在不加载 skill 的情况下会按 hook 指导行动——而 hook 指导可能不完整。这在 "resume after context compact" 场景中尤其危险：AI 丢失了 skill 内容，只剩 hook 指导。

## 批注区

# Baton v2.1 技能包深度审计报告

---

## 第一部分：技能间矛盾与流程断点

### A. 技能间矛盾 (Contradictions)

#### 矛盾 1: research.md 模板 vs 技能定义的结构不一致 [严重度: 中]

**`_task-template/research.md`** (由 `cmd_init` 和 `cmd_new_task` 生成):
```
Objective / Scope / Files reviewed / Open questions
```
只有 4 个 section（`cmd_new_task` 的版本更简陋）。

**`plan-first-research` SKILL.md** 定义的结构:
```
Objective / Scope / Files reviewed / Current behavior / Execution paths /
Risks and edge cases / Architecture context / Technical references /
Evidence snippets / Assumptions / Open questions
```
有 11 个 section。

**模板中有但技能定义中没有:** `## Findings`（出现在 `cmd_init` 版本的模板中）
**技能定义中有但模板中没有:** Current behavior, Execution paths, Technical references, Evidence snippets 等 7 个 section

**影响:** AI 如果从模板开始填写，写出的 research.md 结构不符合技能定义的质量标准。如果严格遵循技能定义，模板完全无用。

---

#### 矛盾 2: detect_phase 对 verification 的判断逻辑有歧义 [严重度: 高]

`bin/baton` 中 `detect_phase` 的逻辑:

```bash
# verification 文件存在但没有 TASK-STATUS: DONE
if [ -f "$verification" ]; then
    if [ -f "$review" ]; then
        # 有 review → 看是否有 BLOCKING → done 或 review(blocking)
    else
        echo "review"  # ← 这里！verification 存在就直接跳到 review
    fi
fi
```

**问题:** verification.md 文件一旦存在（即使是空的、写到一半的、或者测试失败的），`detect_phase` 就认为进入了 `review` 阶段。但 `verification-gate` 技能说只有"all checks pass"才应该加 `TASK-STATUS: DONE`。如果验证失败，verification.md 存在但没有 DONE 标记，detect_phase 会返回 `review`，**实际上应该还在 verify 阶段修复问题**。

**状态机缺少一个"verify (failing)"状态。**

---

#### 矛盾 3: annotation-cycle 的审批后 handoff 与 workflow-protocol 的状态转换脱节 [严重度: 中]

`annotation-cycle` SKILL.md 第 164-165 行:
> "Tell the human: 'Design is approved. Next step: load the plan-first-plan skill to generate the implementation checklist.'"

但在 WORKFLOW MODE 中，状态转换是由 `detect_phase` 自动完成的（通过检测 `STATUS: APPROVED`），不需要人工 load skill。annotation-cycle 的指引适用于 STANDALONE 模式，但在 WORKFLOW MODE 下会造成困惑——AI 不需要告诉人类去 load skill，人类只需要 `baton next`。

---

#### 矛盾 4: slice 阶段是必需的还是可选的？ [严重度: 高]

**workflow-protocol.md** 把 `slice` 列为正式阶段，entry condition 是 "Todo exists, Context Slices do not"。

**detect_phase** 的实现:
```bash
if ! grep -q "## Context Slices" "$plan" 2>/dev/null; then
    echo "slice"  # ← 强制进入 slice 阶段
fi
```

**但 plan-first-implement** SKILL.md 说:
> "If no context slices exist, use full plan.md as context with a warning"

**矛盾:** detect_phase 强制进入 slice 阶段（在 WORKFLOW MODE 下无法跳过），但 implement 技能设计了 fallback 模式来处理"没有 slice"的情况。**detect_phase 不允许你到达 implement 阶段如果没有 slices，但 implement 技能为此准备了 fallback。** 这意味着 fallback 代码在 WORKFLOW MODE 下永远不会被触发——它只在 STANDALONE 模式下有意义。

---

#### 矛盾 5: hard-constraints 的读取级别不一致 [严重度: 低]

**workflow-protocol.md Mode Behavior Matrix:**
> PROJECT STANDALONE → "Read as advisory"

**plan-first-plan** Step 3:
> "In WORKFLOW MODE or PROJECT STANDALONE: read .baton/governance/hard-constraints.md"
> 风险评估中要 "flag it explicitly and propose an alternative or request human confirmation"

plan-first-plan 在 PROJECT STANDALONE 模式下把 hard-constraints 当作强制约束使用（flag + 提出替代方案），而 workflow-protocol 说这个模式下只是"advisory"。两者对"advisory"的理解不同。

---

#### 矛盾 6: review 阶段后的修复循环在状态机中缺失 [严重度: 高]

**plan-first-implement** 定义了完整的 review fix 流程:
> "When review finds BLOCKING issues → plan amendment → regenerate slices → fix → re-verify → re-review"
> "Review fix limit: 2 rounds"

**但 workflow-protocol.md 的状态转换表:**
```
review → done (terminal)
```
**没有 review → implement 的回退路径。** detect_phase 的实现也没有处理这种情况：当 review.md 有 BLOCKING 时返回 `review (blocking issues)`，但没有回到 implement 的机制。

**实际行为:** AI 会停在 `review (blocking issues)` 状态，但 plan-first-implement 说应该修复。谁来触发修复？implement 技能已经退出了（所有 todo 都 checked 了）。

---

### B. 流程断点 (Process Breakpoints)

#### 断点 1: "approved" → "slice" → "implement" 的触发链断裂

当 plan 被批准后：
1. detect_phase 返回 `approved (generating todo)` → 需要人类 run `baton next` → load plan-first-plan
2. plan-first-plan 生成 Todo → detect_phase 返回 `slice` → 需要人类 run `baton next` → load context-slice
3. context-slice 生成 slices → detect_phase 返回 `implement` → 需要人类 run `baton next` → load plan-first-implement

**三次人工干预才能从"批准"到"开始写代码"。** 这是设计意图（每一步都可审查），但如果人类期望"批准后 AI 自己开始干活"，会感到困惑。没有任何技能主动告知人类 "接下来你需要手动运行 baton next 三次"。

---

#### 断点 2: session-start.sh 的 `cat` 命令在 Claude Code 中不生效

session-start.sh 输出:
```
═══════════════════════════════════════════════════
 REQUIRED ACTION — DO THIS BEFORE ANYTHING ELSE:
 cat ~/.baton/skills/plan-first-plan/SKILL.md
═══════════════════════════════════════════════════
```

这是一个给 AI 看的指令。但在 Claude Code 中，SessionStart hook 的输出是 **informational context**，AI 不一定会执行这个 `cat` 命令。AI 收到的是字符串，不是可执行命令。它可能会:
- 直接用 Read tool 读取文件（好的结果）
- 忽略这个指令开始对话（坏的结果）
- 运行 bash cat 命令（次优结果）

**没有强制执行机制保证 AI 一定会读 SKILL.md。**

---

#### 断点 3: BATON_CURRENT_ITEM 环境变量无人设置

`phase-lock.sh` 的 slice scope check 依赖 `BATON_CURRENT_ITEM` 环境变量:
```bash
item_num="${BATON_CURRENT_ITEM:-}"
if [ -z "$item_num" ]; then return 0; fi  # ← 没设置就直接跳过检查
```

**但没有任何技能文件、hook 或 CLI 命令会设置这个变量。** plan-first-implement 没有提到它。这意味着 slice scope check 在实践中**永远不会执行**——它永远走到 `return 0` 就返回了。

这是 v2.1 CHANGELOG 宣传的一个重要特性（"Slice scope check is now BLOCKING by default"），但实际上是**死代码**。

---

#### 断点 4: 无 "skip slice" 的正式机制

detect_phase 强制进入 slice 阶段。如果用户想跳过 slice（小任务不需要），没有 `baton skip-slice` 命令，也没有 `.skip-slice` 标记文件。唯一的方法是手动编辑 plan.md 加一个空的 `## Context Slices` section 来欺骗 detect_phase。

---

#### 断点 5: review.md 位置不一致

`code-reviewer` SKILL.md Mode Behavior 表:
> WORKFLOW MODE → `.baton/tasks/<id>/review.md`

但 `detect_phase` 检查的是:
```bash
local review="$task_dir/review.md"
```

而 `cmd_init` 创建的模板目录结构:
```bash
mkdir -p "$baton_dir/tasks/_task-template/reviews"  # ← 注意是 reviews/ 目录
```

`detect_phase` 查的是 `review.md`（文件），模板准备的是 `reviews/`（目录）。如果 code-reviewer 按照模板输出到 `reviews/review.md`，detect_phase 找不到它。

实际上 code-reviewer 会输出到 `review.md`（根据 Mode Behavior 表），所以 `reviews/` 目录是个遗留物，不会造成运行时问题，但是代码 smell。

---

## 第二部分：系统行为——AI 实际运行时会怎样

### 1. 上下文窗口压力分析

一次完整的 WORKFLOW MODE session 启动时，AI 需要读取:

| 文件 | 大小(行) | 必须性 |
|------|----------|--------|
| session-start.sh 输出 | ~20 | 自动注入 |
| workflow-protocol.md | 65 | using-baton 要求 |
| SKILL.md (当前阶段) | 120-240 | 必须 |
| plan.md (可能很长) | 50-500+ | 大多数阶段需要 |
| research.md | 50-200 | plan 阶段需要 |
| hard-constraints.md | 20-100 | plan/review 需要 |
| project-config.json | 20 | verify 需要 |
| review-checklists.md | 10-50 | review 需要 |

**最坏情况:** 约 1200 行指令性文本，还没开始做任何实际工作。对于 200k context window 不是致命问题，但会稀释注意力。

**循环批注与上下文的关系:** 多轮 annotation 会使 plan.md 不断膨胀（annotation log + 修改后的设计 + 新增决策），这正是 context-slice 存在的原因——它是循环批注的下游解药。循环批注让计划质量更高但文件更长，context-slice 在实现阶段将膨胀的计划切割为精准的上下文包。两者是协同设计。

---

### 2. AI 遵从率预测 (关键行为点)

| 行为点 | 预期遵从率 | 原因 |
|--------|-----------|------|
| 读取 SKILL.md | 70% | 依赖 AI "自觉"，无强制机制 |
| 按模板写 research.md | 50% | 模板和技能定义不一致，AI 会混用 |
| 不跳过 scope identification | 60% | "简单任务"假设是 AI 最常犯的错 |
| 不在 plan 阶段写代码 | 95% | phase-lock hook 硬性阻断（Claude Code 平台） |
| 不在 plan 阶段写代码 (Cursor) | 40% | 纯自我约束，无 hook |
| 生成 Todo 后等待 slice | 30% | AI 倾向于直接开始实现 |
| 使用 slice 而非全量 plan | 60% | 需要正确的 prompt 注入逻辑 |
| 验证时贴真实命令输出 | 85% | verification-gate 的证据标准写得很好 |
| 自我 code review 保持客观 | 35% | 确认偏差是根本性的，结构化协议有限缓解 |
| 遵守 escalation ladder | 50% | AI 倾向于反复尝试而不是升级 |
| 不偷偷改计划外的代码 | 70% | "I'll improve this while I'm here" 是最常见的违规 |

---

### 3. 关键运行时故障模式

#### 故障模式 A: "Phase drift" (阶段漂移)

**场景:** AI 在 implement 阶段遇到计划没覆盖的情况（缺少一个 import、需要修改一个类型定义）。

**预期行为:** 按 escalation ladder 报告。
**实际行为:** AI 大概率会直接修复（"这只是一个 import"），违反 slice 边界。phase-lock 不会阻止（因为 BATON_CURRENT_ITEM 未设置，scope check 被跳过）。

**频率:** 几乎每个 implement 阶段都会发生。

---

#### 故障模式 B: "Approval fatigue" (审批疲劳)

**场景:** 人类需要审批 research.md (CONFIRMED)、plan.md (APPROVED)、每次 annotation 后再审批。

**结果:** 到第三次交互时，人类开始 rubber-stamp（说"looks good"不认真看），失去了审批的质量保障意义。

**根本原因:** 系统没有区分"需要深度 review"和"可以快速确认"的审批粒度。quick-path 缓解了一部分但不够。

---

#### 故障模式 C: "Orphaned state" (孤立状态)

**场景:** AI session 中断（超时、用户关闭终端）。

**结果:**
- `active-task` 文件指向某个中间状态
- plan.md 可能写了一半（STATUS: DRAFT，有 annotation log 但没处理完）
- 下一个 session 的 detect_phase 可能会误判阶段

**缺失:** 没有"session crash recovery"机制。detect_phase 基于文件内容判断，如果文件内容不一致（比如 plan 有 APPROVED 标记但 Todo 只写了一半），状态可能无法正确恢复。

---

#### 故障模式 D: "Subagent context leakage" (子代理上下文泄漏)

**场景:** 使用 implementer.md prompt template 派发子代理。

**预期:** 子代理只看到 slice，不看全量 plan。
**实际:** Claude Code 的 Task tool 派发的子代理会继承父会话的部分上下文。如果父会话中已经读取了 plan.md，子代理可能"记住"它。prompt template 说 "Do NOT read the full plan.md"，但如果上下文已经包含了 plan 内容，这个指令无法真正隔离信息。

**没有真正的上下文隔离机制。** Slice 的价值取决于子代理是否真的是 fresh context。

---

### 4. 各平台实际执行差异

| 特性 | Claude Code | Cursor | Codex/OpenCode |
|------|-------------|--------|----------------|
| Phase-lock 强制 | Hook 硬阻断 | 自我约束 | Bootstrap 脚本 |
| Session start 注入 | 自动 | .cursor/rules | 手动 |
| Skill 加载 | AI 读取文件 | AI 读取规则 | AI 读取文件 |
| Slice scope check | 死代码 | 不存在 | 不存在 |
| 实际可靠性 | 高 | 中 | 低 |

---

## 第三部分：综合评分

### 评分维度

| 维度 | 分数 | 权重 | 加权分 |
|------|------|------|--------|
| **架构设计** | 9.0/10 | 25% | 2.25 |
| **技能间一致性** | 6.5/10 | 20% | 1.30 |
| **状态机完备性** | 7.0/10 | 15% | 1.05 |
| **AI 实际遵从率** | 6.0/10 | 20% | 1.20 |
| **容错与恢复** | 4.5/10 | 10% | 0.45 |
| **跨平台可靠性** | 5.5/10 | 10% | 0.55 |

### **总分: 6.8 / 10**

---

### 各维度详解

**架构设计 (9.0):** 三层架构 (Layer 0/1/2) 是结构亮点，每层可独立运作、向上兼容。但本系统最核心的原创贡献是**循环批注 (Annotation Cycle)** — 它发明了一种人机协作的第三范式。

当前 AI 辅助开发主流只有两种模式：AI 全自主（Devin 模式）和人类审批 PR。前者在偏离预期时浪费大量工作；后者反馈粒度太粗，修改成本高。循环批注创造了一种**低认知负担、高影响力的迭代收敛协议**：

- 人类不写代码、不写计划，只在 AI 产出上打轻量标记（`[NOTE]` / `[Q]` / `[CHANGE]` / `[RESEARCH-GAP]`）
- AI 被强制处理每一个标记、更新设计、记录变更日志
- 人类再审、再标记，循环直到收敛
- `[RESEARCH-GAP]` 实现了 mid-design 的及时知识补给——审查中发现知识盲区时原地触发定向补充研究
- 每轮 conflict check 是收敛保障，Annotation log 是完整的决策审计链

本质上，annotation cycle 把 plan.md 从单向审批文档变成了双人收敛协议。它是整个 Baton 系统存在的核心理由。

其次，Context Slice 是另一个真正的工程创新——直接解决了 LLM 长上下文质量衰减问题。workflow-protocol.md 作为 single source of truth、Responsibility Assignment 表明确所有权边界，也都是正确的架构决策。

**技能间一致性 (6.5):** 存在 6 处矛盾，其中 3 处为高严重度。research 模板与技能定义脱节是最常见的日常摩擦点。review fix loop 在状态机中的缺失是最严重的设计遗漏。annotation 后的 handoff 指引在不同模式下表现不一致。但值得注意的是，v2.1 已经修复了 annotation-cycle 生成 Todo 的矛盾——说明作者有持续改进意识。

**状态机完备性 (7.0):** 9 阶段覆盖了主流程。Quick-path 是好的快速通道设计。但缺少: verify-failing 状态、review→fix→re-verify 回退路径、slice-skip 机制。detect_phase 的 verification 判断逻辑有空指针般的边界条件。

**AI 实际遵从率 (6.0):** phase-lock hook 在 Claude Code 上是整个系统最可靠的约束。但 slice scope check 因 BATON_CURRENT_ITEM 未设置而形同虚设。自我 code review 的确认偏差无法通过结构化协议完全解决。Rationalizations 表和 inline checkpoints 是非常好的设计模式——它们在心理层面与 AI 的行为倾向对抗——但效果有限，预计能提升 10-15% 的遵从率。

**容错与恢复 (4.5):** 没有 crash recovery。没有 partial state detection。`active-task` 文件是单点故障——如果损坏，整个状态丢失。plan.md 既是设计文档又是 Todo 又是 Slices 的容器，单文件承载过多状态，增加了损坏风险。

**跨平台可靠性 (5.5):** Claude Code 上体验最好（hook 支持）。Cursor 的 self-enforcement 在实践中不可靠。Codex/OpenCode 的 bootstrap 方案未在技能文件中详细说明。

---

### Top 5 改进建议 (按 ROI 排序)

1. **修复 BATON_CURRENT_ITEM 的设置机制** — 让 slice scope check 真正生效，否则 v2.1 的核心卖点是死代码
2. **统一 research.md 模板与技能定义的结构** — 消除最常见的日常摩擦
3. **在状态机中加入 review→fix 回退路径** — 补全 review fix loop 的设计空白
4. **为 detect_phase 增加 verify-failing 状态** — 区分"验证中"和"验证完成等待review"
5. **添加 `baton skip-slice` 命令** — 为小任务提供正式的跳过机制，而不是让用户 hack plan.md

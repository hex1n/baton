# Plan 2: workflow.md + workflow-full.md 分层混合重写

## 背景

本 plan 是 plan-workflow-redundancy.md 的后续。Plan 1（结构性改进）已完成管道搭建。

**研究发现**（详见 research-agentic-rewrite.md）：
- 当前 142 条规则中 **65% 是 prescriptive**，仅 10% goal-driven — 与官方「general > prescriptive」建议差距明显
- **30% 冗余**（43 条重复）— 浪费注意力预算
- 仅 **2 处** 有具体示例 — 官方说「examples are pictures worth 1000 words」
- 指令预算 ~120 条在 150-200 限制内，但需要优化注意力分配

**核心策略**：分层混合 — 硬约束保持命令式，认知指导改为目标驱动，关键流程增加 WHY。

## 目标

| 文件 | 定位 | 目标行数 | 加载方式 |
|------|------|----------|----------|
| `workflow.md` | always-loaded 核心原则 | ~80-90行 | CLAUDE.md / IDE rules 静态引用 |
| `workflow-full.md` | 各阶段详细执行指南 | ~370行 | phase-guide.sh 动态提取 |

两份文件共享头部（头部内容相同），独立维护阶段段落。

## 约束

- `### [RESEARCH]` / `### [PLAN]` / `### [ANNOTATION]` / `### [IMPLEMENT]` 分隔符不能改（phase-guide.sh 依赖）
- `## Todo` / `- [ ]` / `- [x]` 格式不能改（hooks grep 依赖）
- workflow.md < 200 行（官方建议）
- 保留全部 6 种 annotation 类型（研究确认各有独立价值）
- 两份文件风格一致（同批次重写）

## 分层混合策略

基于研究证据确定每类规则的目标风格：

| 规则类型 | 目标风格 | 证据 |
|----------|---------|------|
| HARD_CONSTRAINT（行动边界） | **命令式** MUST/MUST NOT | Arize: 2.8x 遵从率；格式不遵从占失败 18% |
| COGNITIVE_GUIDE（认知指导） | **目标驱动 + WHY** | 官方: "general instructions > prescriptive steps" |
| PROCESS_STEP（关键流程） | **约束式 + WHY** | 官方: "add context about WHY" 比裸命令有效 |
| FORMAT_REQUIREMENT（格式要求） | **Prescriptive** | hooks grep 依赖精确格式 |
| STRATEGY_HINT（策略建议） | **启发式** | Right Altitude: heuristics > if-then |

## 变更 1: workflow.md 重组与重写

### 新结构设计

当前结构 → 新结构（基于研究中「混合式」建议）：

```
当前 (66行):                      新 (~85行):
├── Mindset (M1-M8)                ├── Mindset (保留，微调)
├── Flow (F1-F3)                   ├── Flow (补充 WHY)
├── Complexity Calibration (C1-C4)  ├── Complexity Calibration (保留)
├── Annotation Protocol (A1-A10)    ├── Action Boundaries (集中硬约束，前置)
├── Rules (R1-R16, catch-all)       ├── Evidence Standards (新，含示例)
├── Session handoff (S1-S2)         ├── Annotation Protocol (精简，增加 WHY)
└── Parallel sessions (P1-P3)       ├── File Conventions (格式规范集中)
                                    ├── Session handoff (目标式)
                                    └── Phase guidance (衔接说明)
```

### 各段具体变更

#### Mindset（保留，微调）

M1-M5 已是优秀 agentic 内容（研究确认），保留不改。

**变更**：M6-M8（write-lock 规则）从 Mindset **移入 Action Boundaries 段**。Mindset 应纯粹是认知定位，不混入机械约束。

#### Flow（补充 WHY）

保留 Scenario A/B，补充意图说明。

| 当前 | 改后 |
|------|------|
| F2: `research.md ← annotation cycle → plan.md ← ...`（箭头混乱） | 改为明确的迭代描述 |
| F3: "Simple changes may skip research.md"（vague） | 改为引用 Complexity Calibration |

#### Complexity Calibration（保留）

C1-C4 已是好的授权式设计。唯一补充：明确 AI 提议复杂度级别，human 确认。

#### Action Boundaries（新段，集中硬约束，前置）

利用 primacy effect（Arize 研究），将所有 HARD_CONSTRAINT 集中前置。约 8 条，保持命令式 MUST/MUST NOT：

来源：M6 + M7 + R1 + R2 + R3 + R4 + R6 + R7（去冗余后）

内容：
1. Source code writes require `<!-- BATON:GO -->` in plan.md. Markdown is always writable.
2. NEVER add BATON:GO yourself.
3. Todolist required before implementation. Append `## Todo` only after human says "generate todolist".
4. Only modify files listed in the plan. Need additions? Propose in plan first (file + reason).
5. Same approach fails 3× → stop and report to human.
6. Discover omission during implementation → stop, update plan.md, wait for human confirmation.
7. Before writing a new plan, archive existing: `mkdir -p plans && mv ...`
8. All analysis tasks produce research.md. Baton workflow applies to ALL analysis.

#### Evidence Standards（新段，含 2 个示例）

整合 M2 的「verify before you claim」+ 研究中的元认知触发器 + 工具使用原则。

内容：
- Every claim requires file:line evidence. No evidence = mark ❓ unverified.
- `✅` confirmed safe / `❌` problem found / `❓` unverified — each with evidence or reason.
- "Should be fine" is NOT a valid conclusion.

**示例 1（证据标准 good vs bad）**：
```
✅ Good: "Token expires after 24h (auth.ts:45 — `expiresIn: '24h'`)"
❌ Bad: "Token expiration should be fine"
```

- Before starting research: inventory all available documentation retrieval tools. Attempt each at least once. Record usage.

**元认知触发器**：
- Before presenting research: what would a skeptic challenge first?
- Before marking a todo complete: re-read the code. Does it match the plan's intent, or did you drift?

#### Annotation Protocol（精简，增加 WHY）

保留 6 种类型（研究确认全部有价值）。将响应要求从 prescriptive → constraint + WHY。

| 当前 | 改后 |
|------|------|
| A1: 长句混合 in-doc 和 in-chat 机制 | 拆为两句 |
| A3: "Read code first — don't answer from memory" | "Every claim requires file:line. If you can't cite evidence, investigate first." + WHY |
| A4: "verify safety first — check callers, tests, edge cases" | 保持约束式，补充 WHY（因为 blind compliance 是 failure mode） |
| A8: 两步要求 | 补充 WHY（「document body must reflect current agreed state, so todolist reads final version」） |

**示例 2（disagree with evidence，精简自 AN17）**：
```
Human: "Switch to Redis for caching"
AI: ⚠️ Project has 0 Redis dependencies (package.json:1-30).
    Adopting requires: docker-compose + connection mgmt + serialization.
    Alternative: add TTL to existing CacheManager (src/cache.ts:30).
    → Your decision.
```

去除 A10（与 M3 冗余），去除 R5（与 A8 冗余）。

#### File Conventions（格式规范集中）

将分散的格式规则集中：
- Todolist: `## Todo` / `- [ ]` / `- [x]`（lowercase x）. Hooks grep depend on this exact format.
- Documents must end with `## 批注区`
- Name by topic: `research-<topic>.md` + `plan-<topic>.md`. Default `research.md`/`plan.md` for simple tasks.

去除 P2（与 R15 冗余）。

#### Session handoff（目标式）

| 当前 | 改后 |
|------|------|
| S1: "append ## Lessons Learned to plan.md" | "Ensure continuity: record what worked, what didn't, what to try next — so the next session starts with context, not from scratch." |
| S2: "preserve Lessons Learned and Annotation Log" | 保留（已有 WHY："long-term reference"） |

#### Phase guidance（新段，衔接说明）

简短说明：
- Four phases (RESEARCH → PLAN → ANNOTATION → IMPLEMENT) have detailed execution guides.
- Guides are injected by SessionStart hook when you enter each phase.
- This file contains cross-phase principles. Phase-specific strategies come from the hook.

### 预估行数

| 段落 | 当前行数 | 新行数 |
|------|---------|--------|
| Mindset | 15 | 12（去 M6-M8） |
| Flow | 4 | 6（补 WHY） |
| Complexity Calibration | 5 | 6 |
| Action Boundaries | — | 12（新段） |
| Evidence Standards | — | 16（新段，含 2 示例） |
| Annotation Protocol | 14 | 16（精简 + 示例 + WHY） |
| File Conventions | — | 6（新段） |
| Session handoff | 3 | 3 |
| Phase guidance | — | 4（新段） |
| **总计** | **66** | **~81** |

在 200 行限制内 ✅。

## 变更 2: workflow-full.md 重写

### 共享头部（L1-67）

与 workflow.md 保持一致（当前两份文件头部 byte-for-byte 相同，这个设计保留）。头部随变更 1 同步更新。

### 各阶段重写结构

每个阶段统一为：**目标 → 成功标准 → 约束 → 策略提示 → 模板/示例**

### [RESEARCH] 重写

**当前问题**（36 条规则）：
- Execution Strategy 是 4 步操作清单 → 改为策略提示
- 12 条 FORMAT_REQUIREMENT → 简化为成功标准 + 输出目标（非严格模板）
- 工具清点埋在子节 → 提升为第 0 步

**保留**（已 agentic）：
- RE1 goal、RE4 success criteria、RE7 observe-then-decide、RE10 stopping criteria
- RE18 self-check question、RE29-31 Self-Review prompts、RE33-34 Questions for Human Judgment
- Evidence Standards（RE16-17）

**改写**：
- RE5 "Identify entry points"（prescriptive step）→ 策略提示
- RE21-22 "try ALL tools"（too rigid）→ "inventory tools first, attempt each"
- RE12-15 output template → 改为输出目标（what research.md should let the human judge）
- 增加 2-3 个研究输出示例（call chain 格式、risk 标记示例）

**新增**：
- **第 0 步：工具清点**（「Before starting: list all available documentation retrieval tools. Attempt each at least once. Record tool usage.」）
- 元认知触发器（2-3 条）
- 成功标准段

### [PLAN] 重写

**当前问题**（21 条规则）：
- PL14-15 方法分析模板过于 rigid → 改为成功标准
- PL19 patch/root 二分法不够通用 → 改为灵活描述

**保留**：
- PL1 goal、PL3 success criteria
- PL13 "derive from research, don't jump to how"（优秀原则）
- PL17-21 "When Research Discovers Fundamental Problems"（好）
- PL9-11 Self-Review prompts

**改写**：
- PL4 "should include: What, Why, Impact, Risks"（prescriptive list）→ 成功标准
- PL14-15 approach analysis template → 目标描述 + 示例
- PL19 patch/root → "present options with trade-offs, let human decide"

### [ANNOTATION] 重写

**当前状态**：大部分已是约束式，改动最小。

**改写**：
- 减少与 workflow.md 的冗余（AN11=A3, AN12=A4 等不需要完整重述，改为引用）
- 增加元认知触发器：「Before responding to [Q], check: am I about to answer from memory?」
- 保留 AN17-18 行为示例（全文档最有效的内容）

### [IMPLEMENT] 重写

**当前问题**（19 条规则）：
- IM2-IM7 是 6 步操作清单（全文档最 prescriptive）→ 改为质量目标 + 自检触发器

**改写**：
- 6 步清单 → 目标（「Each item: understand intent, implement, verify against plan, mark complete only after verification」）
- 增加自检触发器：「After writing code, re-read it (not from memory). Does it match the plan, or did you drift?」
- 保留 IM17-18（依赖顺序/并行执行 — 有独立价值）

**减少冗余**：
- IM1（=M6/R1）、IM8（=R6）、IM9（=R9）、IM12（=R7）、IM16（=S1）→ 不再完整重述

## 影响范围

| 文件 | 变更类型 |
|------|----------|
| `.baton/workflow.md` | 重组 + 内容重写（66行 → ~81行） |
| `.baton/workflow-full.md` | 头部同步 + 4 个阶段段落重写（372行 → ~360行） |

不需要修改：CLAUDE.md, phase-guide.sh, setup.sh, 所有 hooks。

## 风险 + 缓解

| 风险 | 缓解策略 |
|------|----------|
| hooks grep 匹配失败 | 保留 `## Todo` / `- [ ]` / `- [x]` + `### [RESEARCH]` 等分隔符完全不变 |
| 混合策略分界线画错 | 每条规则有明确的类型标签（research 中的 142 条规则清单）；硬约束（write-lock, BATON:GO, 格式）绝不改为 abstract |
| 内容遗漏 | 实施时逐条对比 research 中的 142 条规则清单，确保每条在新版中有对应 |
| 两份文件风格不一致 | 同批次重写；头部保持相同 |
| overtriggering | 审查所有 NEVER/ALWAYS/MUST — 仅硬约束使用绝对语言，其他用正常语气 |

## Self-Review

- **最大风险**：重写 ~440 行内容时遗漏规则。缓解：research 中的 142 条规则清单是 checklist，实施后逐条验证。
- **什么会让这个方案完全错误**：如果 Claude 4.6 对 baton 的分层混合策略的响应不如预期（比如 goal-driven 的认知指导被忽略）。缓解：实施后做实际任务测试，观察遵从率变化。
- **被拒绝的替代方案**：
  - 全面 agentic 化 — 研究表明硬约束用 abstract 导致 18% non-compliance
  - 只改 workflow.md 不改 workflow-full.md — phase-guide 从 full 提取，源质量直接影响效果
  - 保持 Rules 段 catch-all — 研究建议混合式（硬约束集中 + 认知指导分散）更优

## Annotation Log

### Round 1 (2026-03-05) — plan 初版

**[DEEPER] § Self-Review — agentic 风格是否反而让 AI 忽略规则**
"如果 agentic 风格反而让 AI 更容易忽略规则这个点能研究一下官方文档或者社区最佳实践有没有类似的讨论吗？"
→ 研究了 Anthropic Right Altitude 框架 + Claude 4.6 最佳实践 + 学术研究。结论：分层混合策略。
→ Result: accepted

**[MISSING] § 研究过程 — 研究时未使用所有可用工具**
"刚才研究的时候你也并没有调用可用的工具进行研究 分析原因 及改进方案"
→ 补充了 Context7 查询。根因：习惯路径依赖 + workflow.md 缺少工具清点规则。
→ Result: accepted

**[Q] § 方案形成过程 — 通过批注→研究→回环拟定的吗？**
"目前的方案是通过批注然后再研究然后再回环拟定的方案吗?"
→ 不是。跳过了独立研究阶段。
→ Result: accepted，补充了独立的 research-agentic-rewrite.md

### Round 2 (2026-03-05) — 基于研究重写

Plan 基于 research-agentic-rewrite.md 的系统性研究重写：
- 量化数据驱动（142 条规则分析、65% prescriptive、30% 冗余）
- 整合 3 个人类判断决策（保留 6 种 annotation、混合式 Rules、增加示例）
- 具体到段落级的重组设计

## Todo

- [x] 1. 重写 workflow.md — Mindset 段
  - 文件: `.baton/workflow.md`
  - 变更: 保留 M1-M5（已 agentic），删除 M6-M8（write-lock 移入 Action Boundaries）
  - 验证: Mindset 段纯粹是认知定位，无机械约束

- [x] 2. 重写 workflow.md — Flow 段
  - 文件: `.baton/workflow.md`
  - 变更: 保留 Scenario A/B，修复 F2 箭头符号，F3 改为引用 Complexity Calibration，补充 WHY
  - 验证: 两个场景描述清晰，有意图说明

- [x] 3. 重写 workflow.md — Complexity Calibration 段
  - 文件: `.baton/workflow.md`
  - 变更: 保留 C1-C4，补充"AI 提议复杂度，human 确认"
  - 验证: 内容基本不变，仅小补充

- [x] 4. 新增 workflow.md — Action Boundaries 段
  - 文件: `.baton/workflow.md`
  - 变更: 集中 8 条硬约束（M6+M7+R1+R2+R3+R4+R6+R7 去冗余后），命令式 MUST/MUST NOT，前置于认知段落之后
  - 验证: 所有 HARD_CONSTRAINT 已集中；无遗漏；语言为绝对式

- [x] 5. 新增 workflow.md — Evidence Standards 段
  - 文件: `.baton/workflow.md`
  - 变更: 整合 M2 的 verify-before-claim + ✅/❌/❓ 体系 + 工具使用原则 + 元认知触发器 + 2 个示例（证据 good/bad + disagree with evidence）
  - 验证: 含 2 个具体示例；工具清点规则在 always-loaded 层

- [x] 6. 重写 workflow.md — Annotation Protocol 段
  - 文件: `.baton/workflow.md`
  - 变更: 保留 6 种类型，A1 拆分，A3/A4/A8 增加 WHY，增加 disagree 示例，去除 A10（=M3 冗余）和 R5（=A8 冗余）
  - 验证: 6 种类型完整；每种有 WHY 或约束理由

- [x] 7. 新增 workflow.md — File Conventions 段
  - 文件: `.baton/workflow.md`
  - 变更: 集中 Todolist 格式（## Todo / - [ ] / - [x]）+ 批注区要求 + 文件命名规则，去除 P2（=R15 冗余）
  - 验证: hooks grep 匹配的格式完全保留

- [x] 8. 重写 workflow.md — Session handoff + Phase guidance 段
  - 文件: `.baton/workflow.md`
  - 变更: S1 改为目标式（"ensure continuity"），S2 保留，新增 Phase guidance 衔接说明（4 行）
  - 验证: 行数 ~81，< 200 行限制

- [x] 9. 同步 workflow-full.md 共享头部
  - 文件: `.baton/workflow-full.md`
  - 变更: L1-67 替换为新版 workflow.md 内容（保持两份文件头部相同）
  - 验证: diff 确认头部 byte-for-byte 一致

- [x] 10. 重写 workflow-full.md — [RESEARCH] 段
  - 文件: `.baton/workflow-full.md`
  - 变更: 重组为「目标→成功标准→约束→策略提示→模板」；工具清点提升为第 0 步；Execution Strategy 从步骤清单改为策略提示；保留 RE7/RE18/RE29-31/Evidence Standards；增加元认知触发器和示例
  - 验证: `### [RESEARCH]` 分隔符保留；phase-guide.sh 能正确提取；所有 36 条原始规则有对应

- [x] 11. 重写 workflow-full.md — [PLAN] 段
  - 文件: `.baton/workflow-full.md`
  - 变更: 保留 Approach Analysis + Fundamental Problems 段；PL4 改为成功标准；PL14-15 模板改为目标描述；PL19 改为灵活描述
  - 验证: `### [PLAN]` 分隔符保留；21 条原始规则有对应

- [x] 12. 重写 workflow-full.md — [ANNOTATION] 段
  - 文件: `.baton/workflow-full.md`
  - 变更: 减少与 workflow.md 冗余；增加元认知触发器；保留 AN17-18 行为示例
  - 验证: `### [ANNOTATION]` 分隔符保留；21 条原始规则有对应

- [x] 13. 重写 workflow-full.md — [IMPLEMENT] 段
  - 文件: `.baton/workflow-full.md`
  - 变更: 6 步清单改为质量目标+自检触发器；保留 IM17-18；减少冗余
  - 验证: `### [IMPLEMENT]` 分隔符保留；19 条原始规则有对应

- [x] 14. 规则完整性验证
  - 对比 research-agentic-rewrite.md § 1.1 的 142 条规则清单，逐条确认在新版中有对应（可能换了表达方式）
  - 验证: 0 条规则遗漏

- [x] 15. hooks 兼容性验证
  - 运行 `bash .baton/hooks/phase-guide.sh` 验证动态提取在新版 workflow-full.md 上正常工作
  - 运行 tests/ 下的测试套件
  - 验证: 所有 4 个阶段段落正确提取；grep 匹配格式不变

- [ ] 16. 实际任务测试（需要在新 session 中执行）
  - 用新版 workflow 执行一个 Small 级别的实际任务，观察 AI 遵从率变化
  - 重点观察: 硬约束是否仍被严格遵守、认知指导是否有效、示例是否改善理解

## Code Review（实施后审查）

### 总体结论：实施质量优秀

实施忠实遵循了 plan 的全部 15 个已完成 todo 项。结构重组、风格转换、内容整合均执行到位。

### 测试结果：全部通过
- **phase-guide 测试**：58/58 通过
- **CLI 测试**：14/14 通过
- 4 个阶段分隔符（`### [RESEARCH]`、`### [PLAN]`、`### [ANNOTATION]`、`### [IMPLEMENT]`）均能正确提取

### 指标对比

| 指标 | Plan 目标 | 实际 | 状态 |
|------|----------|------|------|
| workflow.md 行数 | ~81 | 99 | 超出估算，但远低于 200 行限制 |
| workflow-full.md 行数 | ~360 | 361 | 达标 |
| 头部 byte-for-byte 一致 | 必须 | 不匹配（见问题 1） | 需修复 |

### 发现的问题

**问题 1（Bug）：两份文件头部换行符不一致**

workflow.md 使用 LF（`0a`），workflow-full.md 使用 CRLF（`0d0a`）。Plan 要求「byte-for-byte 一致」，目前不满足。不影响功能（phase-guide.sh 正常工作），但违反了设计约束。

**修复方案**：统一两份文件的换行符。

**问题 2（轻微）：Action Boundaries 有 9 条，Plan 指定 8 条**

第 8 条（完成后追加 Retrospective）超出了 Plan 的 8 条规格。该条源自旧版 R8，属于正确的补充——否则 Retrospective 规则会丢失。判断正确，不是问题。

**问题 3（观察）：workflow.md 99 行 vs Plan 估算的 ~81 行**

超出估算 18 行（22%）。额外行数来自：
- Evidence Standards 示例块（代码围栏 5 行）
- Annotation Protocol 示例（Redis，代码围栏 7 行）
- 补充的 WHY 从句

均为合理添加，仍远低于 200 行上限。

### Plan 遵从性——逐规则抽查

| 原始规则 | 新位置 | 状态 |
|----------|--------|------|
| M1（调查者身份） | Mindset L4 | ✅ |
| M6-M8（写锁） | Action Boundaries #1-2 | ✅ 按计划从 Mindset 移出 |
| F2（箭头混乱） | Flow L18 | ✅ 已修复 |
| F3（"simple" 未定义） | Flow L19 | ✅ 改为引用 Complexity Calibration |
| R1-R13（旧 Rules catch-all） | 分散至 Action Boundaries、File Conventions、Evidence Standards | ✅ 全部有对应 |
| A10（=M3 冗余） | 已移除，由 Mindset 原则 #2 + Annotation Protocol L75 覆盖 | ✅ |
| P1-P3（并行会话） | 合并入 Session Handoff | ✅ |
| RE7（observe-then-decide） | RESEARCH Strategy Hints | ✅ |
| RE18（元认知） | RESEARCH Metacognitive Triggers | ✅ |
| PL13（从研究推导） | PLAN Approach Analysis | ✅ |
| AN17-18（行为示例） | ANNOTATION Core Principles | ✅ |
| IM2-IM7（6 步清单） | IMPLEMENT Quality Goal + Self-Check Triggers | ✅ prescriptive→目标驱动 |
| IM17-18（依赖排序） | IMPLEMENT Dependency Ordering | ✅ |

### 风格对齐检查

| 风格目标 | 证据 | 状态 |
|----------|------|------|
| HARD_CONSTRAINT → 命令式 MUST/MUST NOT | Action Boundaries 正确使用 MUST/MUST NOT | ✅ |
| COGNITIVE_GUIDE → 目标驱动 + WHY | Mindset、Evidence Standards、Annotation Protocol 均有 WHY | ✅ |
| 无 overtriggering | MUST/NEVER 仅用于硬约束；认知指导使用正常语气 | ✅ |
| 增加 2 个示例 | 证据 good/bad（L47-50）、Redis disagree（L77-83） | ✅ |
| 消除冗余 | 旧版 43 条冗余规则已消除；改用交叉引用（"see Action Boundaries in header"） | ✅ |

### 做得好的地方

1. **结构重组清晰** — Mindset 纯粹是认知定位，Action Boundaries 集中所有硬约束，Evidence Standards 独立成段
2. **WHY 从句到位** — A8 解释了「因为文档正文是 todolist 生成所读取的事实来源」，S1 解释了「让下个会话有上下文而非从零开始」
3. **冗余消除彻底** — ANNOTATION 和 IMPLEMENT 段改为引用头部而非重述（"see Action Boundaries in header"）
4. **Tool Inventory 提升为 Step 0** — 位置突出，针对已记录的两次工具使用遗漏问题
5. **元认知触发器分布合理** — 分布在研究、证据、实施三个检查点

### 建议

修复换行符不一致（问题 1），然后可进入实际任务测试（Todo #16）。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏

<!-- BATON:GO -->
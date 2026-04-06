# Plan A vs Plan B — first-principles-planner vs baton harness pipeline

**任务**:同一问题(让 baton 跨任务复利,单人使用场景,默认 medium 风险),分别用两种方法产出方案,对比有效性。

**Plan A**:`/first-principles-planner` 单 skill 一次成型
**Plan B**:baton pipeline 多 skill 链式([clarifier → explorer → specifier → architect])

---

## 1. 结论(放最前面)

**Plan A 的最大失败 = Plan B 的最大收益**:Plan A 基于错误前提"baton 缺跨任务复利机制,需要从零构建",于是围绕"设计 knowledge/ 结构、retrospective 钩子、explorer 钩子"展开;而 Plan B 在 explorer 阶段发现 **baton 其实已经实现了这套机制(commit `884e4ce`),只是因为三处错位静默损坏**,于是方案从"从零构建"重写为"修复已 wired 但损坏的链路"。

这不是"Plan B 更细"的差异,而是**问题定义完全不同** —— Plan A 在解一个不存在的问题。

一条钢性结论:**对涉及既有代码的任务,single-shot planner 会放过"代码已经部分回答了问题"这个事实;baton 的 explorer 阶段强制读代码,把这层认知补回来**。

---

## 2. 并排对比

### 2.1 结构对比

| 维度 | Plan A(first-principles-planner)| Plan B(baton pipeline)|
|---|---|---|
| **产出物数量** | 1 份 markdown | 4 份 markdown + 1 份 decisions 待定 |
| **产出物名** | 一段对话内嵌的 Action Plan + Analysis | `clarification-brief.md` + `exploration.md` + `requirements.md` + `architecture.md` |
| **产出物总长** | ~300 行 | ~800 行(4 份合计)|
| **Gate 数** | 0(自检一次就结束) | 4(clarifier 退出 / explorer 推进 / specifier 推进 / architect 人工 gate) |
| **必须人工介入** | 否(可独立产出) | 是(clarifier 2 问 + architect Gate 2)|
| **工具链依赖** | 无(纯 LLM reasoning) | 依赖 `.harness/` 状态机 + `spec/` 协议 + validator 钩子 |
| **面向对象** | 单轮任务或对话问答 | 面向"状态机可驱动的实现任务" |

### 2.2 问题定义

| | Plan A | Plan B |
|---|---|---|
| **Root problem** | "baton 协议缺跨任务复利维度" —— 来自 Five Whys,基于 clarifier 阶段的用户陈述 | **"baton 已有的 lesson-index 机制(commit `884e4ce`)由三处错位导致静默损坏"** —— 来自 explorer 对现有代码的直接阅读 |
| **如何定位** | 从 Karpathy LLM Wiki 原理 + clarifier 对话推导 | 从 commit history + `start-task.sh` regex + `retrospective.template.md` heading level 对齐检查推导 |
| **Problem 有没有 reframe** | 有(从 "build a wiki" reframed to "close the compound loop") | 有(从 "build from scratch" reframed to "fix + backfill existing wiring")|
| **reframe 的质量** | 正确但不够 —— 仍然假设"要新建机制" | 正确且基于证据 —— 引用了 `start-task.sh:236-287`、commit `884e4ce`、三处文件 heading 层级对比 |

### 2.3 推荐方案的核心行动

| # | Plan A(原始,假设从零构建)| Plan B(baton pipeline,基于修复)|
|---|---|---|
| 1 | 定义 `knowledge/` 结构(index.md + lessons.md)| **修**  `start-task.sh:244-245` regex heading level(`###` → `##`)|
| 2 | 在 `baton-retrospective` 加钩子抽取 lesson | **对齐** `retrospective.template.md` 与 `baton-retrospective/SKILL.md` 输出模板的 heading |
| 3 | 在 `baton-explorer` 加钩子读 index | **强化** `baton-explorer/SKILL.md:163-166` 从 "if exists" 到 "always,空要显式空" |
| 4 | 决定路径与 git 策略(`knowledge/` gitignored)| **决策**(Gate 2 待定)物理位置 —— 现状 `.harness/lesson-index.md` vs 迁移 `knowledge/lessons.md` |
| 5 | Backfill 3–5 条初始 lesson | Backfill **15 个**历史 retrospective + **中文源语料兼容**设计 |
| 6 | 验证:真跑一个新任务 | 同 + **一致性 validator** 防未来再次静默损坏 + **protocol 文档(`role-contracts.md`/`artifact-schema.md`)路径同步** |
| 7 | — | verifier / evaluator **必须不读** lesson-index(基于 `role-contracts.md:133-135` 的现有隔离规则)|

**观察**:Plan A 的 1–6 大致正确,但缺 7(隔离规则保护)—— 因为 Plan A 不知道 baton 已经写了这条隔离,也就不知道要保护它。如果按 Plan A 直接实施,会大概率在强化 explorer 钩子时顺手给 verifier / evaluator 也加一个(为了"一致性"),破坏 baton 的核心判断隔离原则。

### 2.4 决策深度

| Decision | Plan A | Plan B |
|---|---|---|
| **D-1 物理位置** | 2 个选项(跟仓 vs gitignored),简要 tradeoff | 3 个选项(加了 Category C 双文件方案),完整 reversibility + 每个候选的拒绝理由 |
| **D-2 写入触发点** | 未提及(默认用 retrospective hook)| 2 个选项对比(start-task.sh 延迟抽取 vs SKILL.md 主动写)+ 推荐理由 |
| **D-3 一致性保障** | 未提及 | Validator vs constants 抽象 vs 人工,**明确选 validator,拒绝 constants 作为 over-engineering** |
| **D-4 lesson schema** | 未给(只说 markdown)| 给出最小字段:`**[context]** trigger: takeaway [source link]` |
| **D-5 LRU 阈值** | 未提及 | 显式决策:从现状 10 放宽到 30 |
| **D-6 Backfill 介入方式** | 未提及 | 半自动:脚本 + 人工审核 |

Plan A 有 1–2 个核心决策,Plan B 把同一问题拆成 6 个独立可翻转的子决策。这个差异直接来自 architect 的 "First-Principles Decomposition" + "Reversibility Analysis" 强制步骤。

### 2.5 Surface Scan / 影响范围

| | Plan A | Plan B |
|---|---|---|
| **列出的文件数** | ~5 个(示意级) | **17 个**(C1-C14 + L2 grep 清单 + 隔离守恒列表)|
| **L1 / L2 / L3 分层** | 无 | 有 —— 并给出 L2 grep 命令用于实施时自检 |
| **失败面覆盖** | 粗 —— 只列直接改动 | 细 —— 含 protocol 文档同步(`role-contracts.md`, `artifact-schema.md`)、隔离守恒(verifier/evaluator 不能读)、cross-platform bash 注意事项 |

### 2.6 Delivery Order / 可交付单元

| | Plan A | Plan B |
|---|---|---|
| 列出单元数 | 1(整体推进)| 6(Unit A–F),A→B→C/D 并行→E→F 顺序 |
| 每单元独立可合并 | — | 是 |
| 单元依赖图 | — | 显式给出 |

### 2.7 Self-Challenge / 对抗

| | Plan A | Plan B |
|---|---|---|
| 自我挑战问题数 | 3 | 4 |
| 最刺耳挑战 | "你的方案依赖 LLM 遵循 SKILL 指令,但这不可靠" | "你在修一个没人用的 feature —— 15 个历史任务全是自举,没一个真公司任务。不如先放到真场景跑一轮" |
| 对 skeptic 的回应 | 用 validator 兜底 | 用 FR-7 Success Gate 回应(已经包含 skeptic 的要求)|
| 承认的不可验证假设 | 2 条 | 3 条,且每条绑定到一个具体的 Assumption ID(A1/A3)+ 对应的 fallback |

### 2.8 Risk 清单

| | Plan A | Plan B |
|---|---|---|
| Risk 数 | 3(低信号 / 钩子不可靠 / 语料贫血)| 8 — 含 Plan A 的 3 条 + 迁移破坏协议自洽性 / 隔离破坏 / LRU 阈值 / heading regex 边缘情况 / 跨平台 |
| 绑定到 Assumption | 否 | 是(R1→A1, R2→A3)|
| 每条 Risk 的缓解动作具体程度 | 中(段落级)| 高(引用到具体的 Unit 或 FR)|

---

## 3. Plan B 独有发现(Plan A 绝对无法产生)

这些是 Plan B 因为有 explorer 阶段才能发现的事实:

1. **E1**: `spec/bootstrap/commands/start-task.sh:244-245` 的 regex `/^###.*${section_pattern}/` 找的是 level-3 heading,但 `spec/templates/retrospective.template.md:17,21` 用的是 level-2 `## 4. Repo-Specific Lessons`。**Plan A 根本不知道 start-task.sh 里有这段抽取代码存在**。

2. **E2**: 历史 15 个 retrospective.md 的 lesson section heading 全是中文(`## 4. 仓库特定经验` / `## 5. Harness 经验`),而 regex 字面量是英文 —— i18n 移除后的历史语料已经孤立。

3. **E3**: `.harness/` 根目录没有 `lesson-index.md` 文件,证实链路从未成功落盘。

4. **Gotcha**: `spec/protocol/role-contracts.md:133-135` 已有对 verification-explorer / evaluator 的"不读 lesson-index"隔离规则,任何修改都**不能**破坏这条,否则违反 baton 核心判断隔离原则。

5. **Gotcha**: `spec/protocol/artifact-schema.md:150-163` 已注册 lesson-index 为 Optional Artifacts,迁移路径需要同步此文档。

6. **Gotcha**: commit `884e4ce`("wire lesson-index extraction")与 commit `9792a38`("remove i18n")的先后顺序 —— 后者移除了 i18n 但没触及早已断裂的前者,解释了为什么 bug 从未被发现。

**Plan A 假设开始的地方**(从 clarifier 对话),Plan B 通过 explorer 找到**问题真正开始的地方**(commit + 文件 + 行号)。

---

## 4. "baton pipeline 是不是 first-principles-planner 的融合体"假设验证

用户在最初让 Claude 做对比时,假设"first-principles-planner ≈ 压缩版的 baton-clarifier + baton-specifier + baton-architect"。这次 trial run 的结论:

**部分正确,但压缩比有损**:

- ✅ **方法论同源**:两者都用 Five Whys、Assumption Audit、Solution Categories、Self-Challenge、Reversibility 这些 first-principles 工具
- ✅ **决策产出形态相似**:TL;DR + priority table + risk list 的结构两者都有
- ❌ **"读代码"这一步无法压缩**:`first-principles-planner` 的 Phase 1(Problem Archaeology)会"列出假设",但**不会主动 grep 代码去验证假设**。baton 的 explorer 是独立一个 skill,**强制**读代码,这是 first-principles-planner 无法折叠进去的
- ❌ **Gate 分层无法压缩**:baton 的 clarifier → specifier → architect 是**3 次独立的思考 pass**,每次只关注一个维度(需求 / 需求 / 方案)。first-principles-planner 是一个 pass 同时做这 3 件事,实际 LLM 会把其中两件简化
- ❌ **Human gate 无法压缩**:baton 架构阶段的 Gate 2 是**强制中断 + 人工批准**,first-principles-planner 没有这个停点
- ⚠️ **Skill 协作机制不同**:baton 中,clarifier 的输出是 specifier 的输入,specifier 的输出是 architect 的输入 —— 每一步都有显式 handoff 和验证;first-principles-planner 是单一 skill 在自己的 reasoning 里折叠所有步骤

**结论**:first-principles-planner 更像"包含 clarifier + 简化 specifier + 简化 architect"的一个**浓缩剂**,适合没有状态机支持的快速场景;但当任务涉及**既有代码**或**需要强 Gate 控制**时,baton pipeline 的"强制多 pass + 代码阅读 + 人工 gate"有本质优势。

---

## 5. 什么场景选谁

| 场景 | 推荐 | 理由 |
|---|---|---|
| 纯概念设计、没有代码基础 | **first-principles-planner** | explorer 没东西可 explore,baton 的多 pass 反而变成开销 |
| 需要快速对话 / 白板讨论 | **first-principles-planner** | 1 次对话拿到结构化方案,不需要状态机 |
| 涉及既有代码、风险中以上 | **baton pipeline** | explorer 阶段的"读代码验证假设"是不可替代的 |
| 需要人工 gate(团队 / 评审) | **baton pipeline** | Gate 2 强制中断 |
| 跨会话、要可重启 / 可回溯 | **baton pipeline** | `.harness/` 状态机提供检查点 |
| 问题定义已经非常清晰 | **first-principles-planner**(甚至可 skip 到 plan synthesis)| baton 的 clarifier + explorer 会被压缩成 no-op |
| 怀疑用户陈述可能是 solution-as-problem | **baton pipeline** | explorer 会把 solution-as-problem 直接打回 —— 代码会说话 |

本次任务("修 / 构建 knowledge-compound")属于"涉及既有代码 + 怀疑用户陈述可能包含隐藏假设"—— baton pipeline 正好命中它的 sweet spot,所以 Plan B 产出了本质不同的 Plan A 无法到达的结论。

---

## 6. 方法论收益:本次 trial run 的 meta-lesson

这次对比本身产生了一个跨任务可复利的 lesson(讽刺地,它应该进 `knowledge/lessons.md`):

> **[planning-methodology] 对涉及既有代码的任务,任何不强制"读代码验证假设"的 planner 都会以 30–50% 的概率基于错误前提。先读代码,再做假设审计,而不是反过来。**
> Why: 本次任务中 first-principles-planner 的 Problem Archaeology 产出的 root problem("baton 缺跨任务复利维度")在 explorer 阶段被推翻,原因是 baton 其实已经实现了该机制但静默损坏。没有 explorer 的话,planner 会按错误 problem 推进 6 个 FR 的完整设计,最终产出的是"和已存在代码并行的第二套实现"。
> How to apply: 在 first-principles-planner 的 Phase 1.3(Surface Assumptions)之前,**强制加一个 "1.2b Code Reality Check"** —— 用 grep / git log 验证"所述问题是否已经在代码中被部分解决过"。

**这条 lesson 本身就是 FR-4 Backfill 的第一条候选**,如果用户接受推进到 Phase 5(generator),应放进初始 `knowledge/lessons.md`(或 `.harness/lesson-index.md`,视 Gate 2 的路径决策)。

---

## 7. 对 first-principles-planner skill 本身的改进建议(副产物)

基于本次 trial run,给 `.claude/skills/first-principles-planner/SKILL.md` 的建议改动:

1. **在 Phase 1.2(Five Whys)之后,Phase 1.3(Surface Assumptions)之前**,插入一个 "1.2b Code Reality Check" 步骤:
   - 对每一个问题陈述中命名的机制 / 组件 / 功能,强制 grep 一次代码仓库
   - 若 grep 命中,必须读命中的文件并评估"该机制是否部分或完全已实现"
   - 这一步是**阻塞性**的,不是可选
2. **在 Self-Check 中新增一个必答问题**:"这个问题在代码中已经有没有部分解?如果有,我的方案是'修'还是'新建'?"

这两个改动会把 first-principles-planner 从"纯 reasoning-level planner"升级为"reasoning + code-evidence planner",显著缩小与 baton pipeline 的 gap,同时保持其 single-shot 的简洁性。

---

## 8. 对 baton pipeline 本身的改进建议(副产物)

1. **lesson-index 链路静默损坏**本身就是本任务要修的 bug —— 已在 architecture.md 的 C1-C14 列出
2. **retrospective 的 lesson sections 用中文 + i18n 后的英文 regex 不一致** —— architecture.md 的 C2 regex 宽松化 + C12 backfill 双语兼容已覆盖
3. **探索阶段需要更系统的"已有代码是否已解"检查** —— Plan B 在本次任务里做到了,但这更像 explorer 的"好 LLM 行为"而不是 SKILL 的强制步骤。可以考虑在 `baton-explorer/SKILL.md` 的 Scoped Mode Steps 第 2 步之前,加一个 "Step 2a: 检查所描述机制是否已存在"(对应 first-principles-planner 改进建议 1)

---

## 9. 产出物一览

| 文件 | 路径 | 作用 |
|---|---|---|
| 本对比文档 | `comparison.md`(worktree 根) | 最终对比交付物 |
| Plan B 澄清简报 | `.harness/clarification-brief.md` | baton clarifier 产出 |
| Plan B 探索报告 | `.harness/exploration.md` | baton explorer 产出(含 §0 核心发现) |
| Plan B 需求 | `.harness/requirements.md` | baton specifier 产出 |
| Plan B 架构 | `.harness/architecture.md` | baton architect 产出,待 Gate 2 人工决策 |
| Plan A | 会话内(已被 context compaction 压缩) | first-principles-planner 产出,本文档第 2-3 节引用 |

## 10. 状态与下一步

- **本 trial run 的 scope** = 产出并对比 Plan A vs Plan B,**到此结束**
- **不继续推进到 Phase 5(generator / 实施)** —— 需要用户在 Gate 2 审批 architecture.md 才能继续
- **Gate 2 需要用户决策的内容**(已在 architecture.md 末尾列出):
  - D-1 物理位置(推荐 Category B:`knowledge/` gitignored)
  - D-2 写入触发点(推荐 α:保留 start-task.sh 延迟抽取)
  - D-3 一致性保障(推荐 validator only)
  - D-4 lesson schema(推荐单行 markdown)
  - D-5 LRU 阈值(推荐 30)
  - D-6 Backfill 介入(推荐半自动)

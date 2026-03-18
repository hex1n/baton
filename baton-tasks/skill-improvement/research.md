# Research: Baton Skill Improvement Based on Thariq Article Insights

## Step 0: Frame

- **Question**: Thariq 文章 "Lessons from Building Claude Code: How We Use Skills" 中的最佳实践，哪些能直接改进 baton？优先级如何？
- **Why**: 指导 baton 下一阶段改进方向，最大化 ROI
- **Scope**: baton 的 skills、hooks、configuration 三层架构
- **Out of scope**: baton CLI/安装机制改动、新增 IDE 支持
- **System goal**: 让 baton 的治理更精准、更可观测、更可定制

## Step 1: Orient

- **Familiarity**: deep（baton 维护者视角）
- **Evidence type**: mixed（文章分析 + 代码验证）
- **Strategy**: 将 Thariq 文章的 9 大实践逐条对照 baton 现状，用代码证据确认 gap 真实性，然后按 ROI 排序

## Step 2: Evidence Methods

1. **[DOC] 文章分析** — Thariq 原文全文（via Jina Reader）
2. **[CODE] 代码验证** — Agent 探索 baton 全部 skills、hooks、lib/（29 次工具调用 + 32 次工具调用）

两种方法独立交叉验证：文章提出的 gap 是否在代码中确认。

## Step 3: Gap Analysis

### Gap 1: Gotchas ≠ Red Flags — 缺少操作性 Gotchas

**文章观点**: "The highest-signal content in any skill is the Gotchas section — built up from common failure points that Claude runs into" `[DOC]✅`

**baton 现状**: 7 个 skill 都有 `## Red Flags` 表格 `[CODE]✅`

**但 Red Flags ≠ Gotchas**:
- Red Flags 是 **AI 合理化模式**（"This is obvious, no evidence needed"）— 防止 AI 偷工减料
- Gotchas 是 **操作性踩坑记录**（"write-set 常遗漏间接依赖文件"、"research 中两个 ❓ 源的一致不等于验证"）— 从实际使用中积累

Red Flags 是静态的理论防线，Gotchas 是动态的经验积累。**baton 缺后者。** `[CODE]✅` `[DOC]✅`

### Gap 2: 验证脚本覆盖不足

**文章观点**: Verification Skills 可以让工程师花一周时间专门打磨，用程序化断言替代 AI 自查 `[DOC]✅`

**baton 现状**: 已有验证脚本 `[CODE]✅`
- `quality-gate.sh` — 检查 Self-Challenge 存在性 + 最少 3 行内容
- `completion-check.sh` — Todo 完成度、retrospective 存在性、测试检测
- `plan-parser.sh` — write-set 提取、Todo 解析、BATON:GO 检测

**Gap**: 验证是浅层的（presence check + line count），缺少深层验证：
- research: 是否有 ≥2 独立证据方法？证据标签覆盖率？
- plan: write-set 是否覆盖了所有 Todo 涉及的文件？approach 数量是否 ≥2（Medium+ 任务）？
- implement: retrospective 是否包含 "unexpected" 或 "discovery" 类内容？

### Gap 3: 无用户配置机制

**文章观点**: "A good pattern is to store setup information in a config.json file in the skill directory" `[DOC]✅`

**baton 现状**: 仅通过环境变量（`BATON_PLAN`, `BATON_BYPASS`, `BATON_TEST_CMD`）和 hook 自动检测 `[CODE]✅`

**Gap**: 无法定制治理强度。所有项目、所有团队用同一套流程。实际需求：
- 某些团队 Trivial 任务也要 plan（风控需求）
- 某些团队 Small 任务可以跳过 review dispatch
- 自定义证据标签（如 `[METRIC]`, `[A/B TEST]`）
- 默认 task sizing 偏好

### Gap 4: 无跨 session 持久化

**文章观点**: "Skills can include a form of memory by storing data... use `${CLAUDE_PLUGIN_DATA}` as a stable folder" `[DOC]✅`

**baton 现状**: `/tmp/baton-failures-${SESSION_ID}` 和 `/tmp/baton-writeset-violations-${SESSION_ID}` 都是 session-scoped `[CODE]✅`

**Gap**: 每次新 session 都从零开始。无法积累：
- 跨 session 的 failure patterns
- 历次 review 发现的常见问题分类
- skill 使用频率和触发率

### Gap 5: 无 Usage Tracking

**文章观点**: "We use a PreToolUse hook that lets us log skill usage... find skills that are popular or are undertriggering" `[DOC]✅`

**baton 现状**: `failure-tracker.sh` 追踪失败次数，`post-write-tracker.sh` 追踪 write-set 违规，但都是 session-local advisory `[CODE]✅`

**Gap**: 无法回答：
- baton-review 发现了多少实质性问题 vs 多少 nitpick？
- 哪个 phase 最常 BLOCKED？
- 从 APPROVED 到 COMPLETE 平均几次迭代？

### Non-Gap: Skill Descriptions（原判断有误）

**文章观点**: "description field is not a summary — it's a description of when to trigger" `[DOC]✅`

**baton 现状**: 所有 7 个 skill descriptions 都以 "Use when..." 开头，聚焦触发条件 `[CODE]✅`

**结论**: 不是 gap。baton 已经做对了。 ✅

### Non-Gap: Folder Structure as Context Engineering

**baton 现状**: skills 包含 hooks/、lib/、templates、review-prompt-*.md，渐进式信息披露完整 `[CODE]✅`

**结论**: 不是 gap。 ✅

## Step 4: ROI 排序

| Gap | 影响面 | 实现难度 | ROI |
|-----|--------|----------|-----|
| Gap 2: 深层验证脚本 | 高 — 直接强化 defense-in-depth | 中 — 扩展现有 parser | **最高** |
| Gap 1: 操作性 Gotchas | 高 — 提升 skill 有效性 | 低 — 文档级改动 | **高** |
| Gap 3: config.json 配置 | 中 — 可定制性 | 中 — 需改 hooks 读取逻辑 | **中** |
| Gap 4: 持久化存储 | 中 — 跨 session 学习 | 中 — 需定义存储格式 | **中** |
| Gap 5: Usage Tracking | 低-中 — 可观测性 | 低 — 加一个 hook | **中低** |

## Step 5: Self-Challenge

1. **最弱结论**: Gap 4（持久化）的价值可能被高估。baton-tasks/ 本身已经是持久化载体（research.md、plan.md、retrospective 都留在磁盘上）。额外的 session metrics 真的有人会看吗？
   - 反驳：baton-tasks/ 保存的是任务级产物，不是元级数据（skill 效能、failure patterns）。两者用途不同。

2. **未调查**: 没有验证其他团队/项目使用 baton 时的实际痛点。当前分析仅基于文章理论对照，缺少 `[RUNTIME]` 或 `[HUMAN]` 证据。

3. **假设**: 假设 "更多验证 = 更好"。但 constitution.md 明确说 "Adding more structural checks does not solve quality problems — it incentivizes mechanical compliance." 新增验证脚本需要检查的是具体有价值的信号，而不是堆叠检查项。

## Conclusions

1. **最高 ROI**: 深层验证脚本（Gap 2）— 直接对齐 constitution "defense is layered" 原则，且有现成基础设施（plan-parser.sh）可扩展
2. **次高 ROI**: 操作性 Gotchas（Gap 1）— 低成本高回报，每个 skill 加一个 section
3. **中等 ROI**: config.json（Gap 3）+ 持久化（Gap 4）— 有价值但需谨慎设计，避免过度工程
4. **观望**: Usage Tracking（Gap 5）— 等前几项落地后再评估

**Plan implication**: actionable for Gap 1-2, judgment-needed for Gap 3-4, watchlist for Gap 5

## 批注区

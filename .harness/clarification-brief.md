# Clarification Brief — knowledge-compound-mvp

## 置信度总览

| 维度 | 置信度 | 关键结论 |
|------|--------|----------|
| Problem | 80% | baton 协议当前只在**单任务内**闭环(clarifier → … → retrospective),retrospective 写完就没人再读了,**跨任务维度缺失**。用户手动翻 `.harness/history/` 成本太高、不可持续 → 需要一层"知识沉淀 + 被下一任务读到"的机制。 |
| Users | 95% | 单人使用(一人开发者,未来可能进入公司实际工作),无团队协作 / 多人合并语义需求。 |
| Boundaries | 95% | 明确纳入:lessons 文件结构、写入钩子、读取钩子、backfill。明确排除:spec/ 状态机改动、自动 lint、团队合并。物理位置已定:`knowledge/` 放仓库根,gitignored,本地保留。 |
| Success criteria | 90% | **行为式验收**:MVP 完成后必须真跑一个新 baton 任务,explorer 阶段可观察到引用到某条历史 lesson(读了 + 用了,而不仅仅是"文件存在")。 |
| Constraints | 70% | 技术约束低(纯 md + shell/skill hook);时间约束未明;主要是**内容约束**——backfill 能不能产出可迁移的 lesson 是个未知数(目前 `.harness/history/` 全是 baton 自举任务)。 |
| Risks | 70% | 已识别 3 类风险(低信号噪音、钩子触发不可靠、backfill 语料贫血),缓解方向基本清晰。 |
| **加权总体** | **~85%** | 可退出 clarifier,进入 explorer |

## 核心问题

baton 协议把每个任务闭环得很好(clarifier → explorer → specifier → architect → generator → reviewer → evaluator → retrospective),但**所有闭环都发生在任务内部**。retrospective.md 写完后,下一个任务启动时没有任何路径会让它被再次读到 —— 历史教训停留在 `.harness/history/` 目录里"积灰"。

对一个打算把 baton 用在日常工作中的单人使用者,这意味着每次做相似任务都要**重新踩同一个坑**。缺的不是"更多 skill",而是一层把过往任务的非显然教训沉淀为可被未来任务消费的结构。

## 用户与场景

- **主要用户**:单人开发者(本人),当前在自举 baton 协议,未来计划把它用在公司实际工作任务。
- **使用场景**:
  1. 任务完成后:retrospective 结束时,把这次任务中**非显然**的教训抽取成 lesson 条目,追加进 `knowledge/lessons.md` 并更新 `knowledge/index.md`。
  2. 任务启动时:explorer 阶段读取 `knowledge/index.md`,识别与当前任务相关的历史 lesson,显式引用进探索产出,供后续角色参考。
- **不在场景内**:多人并发、跨仓库合并、自动化 lint、LLM 主动重写已有 lesson。

## 需求 (R)

- **R1**. 任务完成时(`baton-retrospective` 执行流程末尾),必须有一个钩子把本次任务的 1–N 条"非显然 lesson"追加到 `knowledge/lessons.md`,并同步更新 `knowledge/index.md`(主题 + 一行钩子 + 文件锚)。
- **R2**. 任务启动时(`baton-explorer` 执行流程开头),必须有一个钩子加载 `knowledge/index.md`,并在 exploration.md 中显式列出"本次任务可能相关的历史 lesson"(哪怕是空列表,也必须显式写出,证明读了)。
- **R3**. `knowledge/` 目录位于**仓库根**,`.gitignore` 忽略,本地持久(允许包含公司敏感信息、事故笔记、决策细节,不泄漏到主仓库)。
- **R4**. 文件结构保持**单人可读可手编**:lessons.md 用 markdown,每条 lesson 有稳定 id/锚点,index.md 按主题分组,避免强 schema/YAML 校验。
- **R5**. 必须完成一次从 `.harness/history/` 的 **backfill**:把至少过去 3–5 个已完成任务的 retrospective 转成初始 lesson 条目,保证 MVP 上线时 `knowledge/lessons.md` 不是空的(否则 R2 无内容可引用,成功标准无法验证)。

## 明确的非目标 (Non-Goals)

- ❌ 改 `spec/` 状态机或新增 phase。
- ❌ 自动 lint / 自动校验 lesson 条目质量。
- ❌ 多人并发写入 / 团队合并 / PR review 流程。
- ❌ 替代 retrospective(lessons 是 retrospective 的**下游抽取**,不是它的替代)。
- ❌ 把 lessons 做成可查询的数据库或向量库(MVP 只是纯 markdown)。
- ❌ 跨仓库 / 跨项目的 knowledge 同步。

## 成功标准 (Success Criteria)

**行为式 Gate**(用户显式选择的最严标准):

1. MVP 构建完成后,在 baton 仓库(或其他目标仓库)**真跑一个新的 baton 任务**。
2. 该任务的 `exploration.md` 中可观察到**显式引用**至少一条 `knowledge/lessons.md` 的 lesson 条目(通过锚点 / id / 引号文本)。
3. 引用发生**自动**(由 explorer 钩子触发读取 index),而不是人工在对话里粘贴。

附加标准(非必需,但用于质量判断):

4. Backfill 完成后,`knowledge/lessons.md` 至少有 3 条来自 `.harness/history/` 的非显然 lesson(不是"按流程做就行"这种套话)。
5. `knowledge/index.md` 行数 < 50(保持紧凑,可直接被 explorer 完整加载)。

## 约束 (Constraints)

- **技术**:不引入新运行时(Node/Python),限制在 bash + markdown + 既有 skill 结构内。
- **协议**:不改 `spec/` 下的状态机定义,只在 skill 层(`skills/baton-retrospective/SKILL.md`、`skills/baton-explorer/SKILL.md`)加钩子。
- **内容**:backfill 的原材料是 baton 自举任务(元任务),而非真实公司任务 —— 存在可迁移性风险(见风险 R3)。
- **可移植性**:knowledge/ 本地保留 = 换机器 / 换 clone 时丢数据,需要用户自己备份(用户已接受)。

## 已知风险

| # | 风险 | 影响 | 缓解方向 |
|---|------|------|----------|
| **Risk-1** | **低信号噪音**:lesson 写得太套话("记得写测试"、"沟通很重要"),explorer 即使读到也不产生决策价值 | 高 —— 直接让 R2/R3/成功标准验收失败 | retrospective 钩子里加**非显然判据**(见 architecture 阶段设计):一条 lesson 必须同时满足"过去任务踩过的坑 + 下一个相似任务可能再踩 + 不是流程常识" |
| **Risk-2** | **钩子触发不可靠**:explorer 运行时 LLM 忘了读 index,或 retrospective 忘了抽 lesson | 中 —— 破坏"自动引用"这个成功标准 | 把钩子写成 SKILL.md 执行流程里的**强制第一步**,而非可选建议;在产出 artifact 的模板中给 lessons 引用留显式位置(空也要填"无相关") |
| **Risk-3** | **backfill 语料贫血**:`.harness/history/` 全是 baton 协议自举任务,lesson 不一定适用于未来的公司业务任务 | 中 —— 验收可能只能在 baton 元任务上验证,不能立即证明对公司场景有效 | 接受该局限:MVP 验收在 baton 元任务上完成即可;公司任务的有效性留给后续真实使用时的迭代修正,不在本 scope |

## 未解决项

- **UR-1**(留给 architect):lesson 条目的最小 schema 是什么?(id / title / context / trigger / takeaway / 锚到哪次 retrospective)—— 单人使用要尽量简,但要允许 index 按主题聚合。
- **UR-2**(留给 explorer):backfill 的粒度 —— 从几条 retrospective 抽?每条抽几条 lesson?阈值由谁定?
- **UR-3**(留给真实使用):backfill 产出的 lesson 是否对**非 baton 元任务**有可迁移价值 —— 本 MVP 不解决,留作上线后观察。

## 访谈日志(摘要)

- **Q1(风险级别)**:初判为 Low,用户纠正为 **Medium**。→ 触发了更完整的 clarifier 通道而不是 Low 直跳 explorer。
- **Q2(成功标准严格度)**:三选一("文件存在"/"结构完整 + backfill 可读"/"真跑新任务能被引用"),用户选**最严**(真跑新任务验证)。→ 反向约束 MVP 必须包含 backfill,且 backfill 质量必须够。
- **Q3(lessons 物理位置 + git 策略)**:四选一(`.harness/knowledge` 跟仓 / `knowledge/` 仓库根跟仓 / `knowledge/` 仓库根 gitignored / 其他路径),用户选 **`knowledge/` 仓库根 + gitignored 本地**。→ 明确了可放敏感信息、不泄漏到主仓,代价是无版本历史 / 无团队共享(单人场景可接受)。

## 退出说明

Problem 和 Boundaries 已基本清晰,Success criteria 已升级为可验证的行为式 Gate。剩余 15% 左右的不确定性集中在 "UR-1/UR-2/UR-3",这些属于 **how** 层面而非 **what**,由 specifier / architect 在各自阶段消化更合适。

→ 进入 Phase 2:**baton-explorer**(Medium depth = Dependency Scan)。

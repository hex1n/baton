# Requirements: knowledge-compound-mvp

**Topic**: 修复并上线 baton 的 lesson-index 跨任务复利机制
**Status**: `ready_for_architecture`
**Sizing**: `Small`

## 1. Problem

### 用户原始表述(reframed)

**原始**:"给 baton 加一层 knowledge-compound,让 retrospective 的教训能被下个任务读到"
**reframed(基于 explorer 发现)**:**baton 已有 lesson-index 机制,但由三处错位导致静默损坏,从未成功抽取过一条 lesson;需要修复链路 + 一次性 backfill + 调和物理位置分歧**

### Root Problem

已有的 lesson-index 抽取机制(commit `884e4ce` wire)**诞生即坏**,具体失败点:

- E1(heading level mismatch):`start-task.sh:244-245` regex 找 level-3 (`###`),但 `retrospective.template.md` 与 `baton-retrospective/SKILL.md` 输出都是 level-2 (`##`) → sed 永远匹配空 block
- E2(语料语言错配):regex 是英文字面量,历史 15 个 retrospective 全是中文 heading
- E3(无测试 / 无落盘):`.harness/lesson-index.md` 从未被写出,无人感知失败

**谁被影响**:单人使用者(本人),做相似任务时重复踩同一个坑;未来在公司场景使用时问题会放大

**"solved" 的形态**:
1. 修复后的链路在一次真任务上走通(retrospective → start-task.sh 抽取 → 下个任务 explorer 显式引用)
2. 历史 retrospective 里有价值的非显然 lesson 被 backfill 成初始数据,让"下一次真任务"有东西可引用
3. 静默失败被一致性 validator 或测试兜住,未来改名/改结构时能被立即发现

## 2. Assumptions

| # | Assumption | Type | Confidence | If wrong... |
|---|-----------|------|------------|-------------|
| A1 | `.harness/history/` 中的中文历史 retrospective 包含可迁移 lesson(即存在值得记住的非显然教训) | Testable | Medium | Backfill 产出全是套话,R2 成功标准"explorer 自动引用"会因"读了但没价值所以不引用"而失败 |
| A2 | 单人使用场景不需要多人合并 / PR review / 版本历史上的 lesson 追溯 | User intent | High | 如果错,`knowledge/` gitignored 方案不成立,必须跟仓 + 冲突解决流程 |
| A3 | explorer / architect 的 LLM 执行者会真的遵循 SKILL.md 第 1b 步"必读 lesson-index" —— 即 skill 指令足够成为强制流程 | Testable | Medium | 如果不可靠,需要额外的提示机制(如 exploration.md 模板里强制留位) |
| A4 | Heading 名字在 4 处 (`start-task.sh` regex、`retrospective.template.md`、`baton-retrospective/SKILL.md`、可能的 validator) 的一致性可通过一致性 validator 保障 —— 不需要引入"单一 constants 源"这种重量级抽象 | Convention | Medium | 如果错,每次重命名都要手动更新 4 处,单人场景也容易漏 |
| A5 | 现有的 LRU-10 策略(`artifact-schema.md:159`)对单人使用够用;不需要全量保留或更细的标签过滤 | Convention | High | 如果错,最坏丢弃旧 lesson —— 但可手动从 `.harness/history/*/retrospective.md` 找回 |
| A6 | 物理位置决策(`.harness/lesson-index.md` 跟仓 vs `knowledge/` gitignored)影响**可上线性**但不影响**可修复性** —— 两种方案都能让机制跑通,只是在"私密 vs 可追溯"上 tradeoff | User intent | High | 如果错(比如用户其实想要两者同时 —— 私密的 + 可追溯的),就需要更复杂的双文件方案 |

**Load-bearing 最关键**:**A1**(backfill 可行性)与 **A6**(位置二选一),这两个如果错,MVP scope 要重算。

## 3. Scope

### 3.1 In Scope

- 修复 `spec/bootstrap/commands/start-task.sh:236-287` 抽取段的 regex 与源 heading 层级
- 对齐 `spec/templates/retrospective.template.md` 与 `skills/baton-retrospective/SKILL.md` 输出模板的 heading 规范
- 强化 `skills/baton-explorer/SKILL.md` 第 1b 步 / §11 与 `skills/baton-architect/SKILL.md` L88-90 的"必读 + 显式引用"语义 —— 允许空列表,但必须显式写出"无相关"
- 从 `.harness/history/` 15 个历史 retrospective 做一次性 backfill(见 FR-4)
- 决策并落实物理位置(由 architect 决定:`.harness/lesson-index.md` 维持现状 vs 迁移到 `knowledge/lessons.md` gitignored)
- 加一致性 validator 或等价机制,防止未来 heading 重命名再次造成静默失败
- 真跑一次"修复验证任务"(小规模 baton 任务)证明 end-to-end 链路通(Success Gate)

### 3.2 Out of Scope

- `spec/protocol/state-machine.md` 状态机增减 phase
- 自动 lint / lesson 条目质量打分
- 多人合并、跨仓库同步、PR review 流程
- 用向量库 / 数据库替代 markdown
- 替代或取消 retrospective(lessons 是 retrospective 的下游抽取,不是它的替代)
- 修改 verification-explorer / evaluator 的隔离规则(`role-contracts.md:133-135` 明确禁止它们读 lesson-index,修复必须保留该隔离)

## 4. Functional Requirements

### FR-1 Heading 对齐与抽取链路修复 [P0]

- 保证 `start-task.sh` 的抽取正则与 `retrospective.template.md` 的源 heading 层级**对得上**(要么 regex 改 `##`,要么 template 改 `###`,两者择一,同时同步 `baton-retrospective/SKILL.md` 输出模板)
- 抽取成功后必须把结果落盘到 lesson-index 文件(路径由 FR-5 决定)
- LRU-10 保留策略保持不变(`artifact-schema.md:159`)
- **Input**:上一任务的 retrospective.md(含非空 lesson 段)
- **Output**:新任务的 lesson-index 文件中追加一个 `## <scope> (date)` block
- **Validation**:在测试夹具里构造一个符合新 heading 规范的 retrospective.md,运行 `start-task.sh --scope next --dry-run` 应显示 `plan ... (append lesson)`;去掉 --dry-run 应真落盘
- **Exceptions**:retrospective.md 不存在 / lesson 段空白 → 静默跳过(保留现有行为)
- **Priority**:**P0**(不修这个,后面全是空谈)

### FR-2 Retrospective 模板引导"非显然 lesson"[P0]

- 在 `retrospective.template.md` 的 "Repo-Specific Lessons" 与 "Harness Lessons" 段前加一行引导句,明确"什么算一条可被 lesson-index 复用的条目"(判据:过去踩过的坑 + 下次可能再踩 + 不是流程常识)
- 在 `baton-retrospective/SKILL.md` 的 Execution Steps 或 Quality Check 里呼应该规则
- **Input**:retrospective 阶段的 LLM
- **Output**:只记录"非显然"条目,避免套话污染 lesson-index
- **Validation**:人工审核 backfill 与下一个真任务的 retrospective,确认条目符合判据
- **Exceptions**:判据主观,允许 LLM 在边缘情况下"宁多勿少",后续由 explorer 读时过滤
- **Priority**:**P0**(低质量 lesson = explorer 不会引用 = Success Gate 失败)

### FR-3 Explorer / Architect 的"必读 + 显式引用"语义强化 [P0]

- `skills/baton-explorer/SKILL.md` 第 1b 步改为**强制第一步**(不是 "if exists" 可选分支):即使 lesson-index 文件不存在,也要在 exploration.md §11 显式写 "no lesson-index found" 或 "no relevant lessons"
- `exploration.md` 模板的 §11 从"可省略"改为"必填"(空列表要显式空)
- `skills/baton-architect/SKILL.md` L88-90 同样强化
- `architecture.md` 模板(若有对应段)同步
- 保留 `role-contracts.md:133-135` 对 verification-explorer / evaluator 的禁读规则,不改
- **Input**:explorer / architect 的 LLM 执行者
- **Output**:所有 exploration.md / architecture.md 文件都有一段可被人工 grep 到的 "historical lessons" 记录(即使为空)
- **Validation**:新增或复用 `spec/bootstrap/hooks/post-artifact` 的 validator,校验 exploration.md 含 §11 且非完全空
- **Exceptions**:无 —— 空要显式空
- **Priority**:**P0**(读路径不可靠 = 写路径再好也没用)
- **Depends-on**:FR-1(没 lesson-index 文件前先验证空列表语义)

### FR-4 历史 retrospective 一次性 Backfill [P0]

- 读 `.harness/history/` 下全部(目前 15 个)retrospective.md,人工或半自动抽取每个任务的"仓库特定经验 / Harness 经验"段落
- 至少 3 条被认定为"非显然"的 lesson 进入初始 lesson-index(见 FR-2 判据)
- Backfill 过程可以是脚本 + 人工审核(半自动),允许放弃套话条目
- 产出物:一份可重现的 lesson-index 初始文件(或补丁)
- **Input**:`.harness/history/*/retrospective.md`(全部现有 15 个)
- **Output**:`.harness/lesson-index.md` 或 `knowledge/lessons.md`(取决于 FR-5)含 ≥3 条非显然 lesson
- **Validation**:人工审核 —— 每条条目明确对应某个历史任务、非"按流程做就行"类套话
- **Exceptions**:若某 retrospective 无可抽取非显然条目,在 backfill 备注中显式说明(而非默默跳过)
- **Priority**:**P0**(Success Gate 要求"下个任务能引用到 lesson",空 index 无法验证)

### FR-5 物理位置决策与落实 [P0]

- 由 architect 在 Phase 4 提出 2 种方案并给出推荐:
  - **方案 A(现状)**:`.harness/lesson-index.md`,跟仓,LRU-10 —— 保持 baton protocol 一致性,但无法放公司敏感信息
  - **方案 B(用户偏好)**:`knowledge/lessons.md`,仓库根,`.gitignored`,本地持久 —— 可放敏感信息,代价是无版本历史 + 无跨机器同步
- `decisions.md` 记录决策与理由
- 修复 start-task.sh 的抽取 / 落盘路径以匹配所选方案
- 若选方案 B,同步更新 `role-contracts.md:25,58`、`artifact-schema.md:150-162`、`skills/baton-explorer/SKILL.md:163`、`skills/baton-architect/SKILL.md:88` 对文件路径的引用
- 若选方案 B,`.gitignore` 加一行
- **Input**:用户在 clarifier 阶段已声明的偏好(`knowledge/` gitignored)+ architect 的 tradeoff 分析
- **Output**:一个唯一被选中的路径,所有相关代码/协议/skill 引用都指向它
- **Validation**:运行 `bash spec/bootstrap/hooks/consistency-check`(或等价),无路径引用不一致
- **Exceptions**:若用户在 Gate 2 改变偏好,需要回到 FR-5 重新决策(触发 requirements sync)
- **Priority**:**P0**(路径分歧不解,后面的修复代码无处落)

### FR-6 一致性 Validator / 测试兜底 [P1]

- 新增或扩展 `spec/bootstrap/hooks/post-artifact` 或 `spec/bootstrap/validators/` 下的 validator,检查:
  - `start-task.sh` 抽取 regex 的 heading level 与 `retrospective.template.md` 源 heading level 一致
  - `baton-retrospective/SKILL.md` 输出模板的 heading 与 `retrospective.template.md` 一致
  - `exploration.md` 含 §11 "Historical Lessons" 段(FR-3 的语义校验)
- 可选:新增最小 e2e smoke test —— 造一个 fixture retrospective,跑 `start-task.sh`,断言 lesson-index 正确产出
- **Input**:baton 仓库改动(作为 PostToolUse / pre-commit / 手动 invoked 校验)
- **Output**:检测到 heading 不一致或缺失时失败并给出明确错误信息
- **Validation**:故意把 `start-task.sh` 的 regex 改回 `###` 或把 template 改成 `### 4.` —— validator 应立即报错
- **Exceptions**:允许人工在 decisions.md 显式接受不一致(但默认必须一致)
- **Priority**:**P1**(未来防回归,不修也不影响当下 MVP 验收,但强烈推荐)
- **Depends-on**:FR-1, FR-2, FR-3(validator 校验的规则来自这些 FR)

### FR-7 Success Gate:真跑一次小任务验证 [P0]

- 在 baton 仓库或其他目标仓库,跑一个全新的、规模小的 baton 任务(任意 scope)
- 该任务的 `exploration.md` § "Historical Lessons"(或等价段)必须**显式引用**至少一条来自 FR-4 backfill 的 lesson(通过任务名锚点、引号文本或 id)
- 引用必须是 explorer 自动读 index 产生的,而不是人工粘贴
- **Input**:修复完成后的 baton 仓库 + 已 backfill 的 lesson-index
- **Output**:一份新任务的 `exploration.md`,其 §11 可被人工 grep 到一条历史 lesson 引用
- **Validation**:人工 diff 新 exploration.md 的 §11,比对 lesson-index 中的源条目
- **Exceptions**:如果新任务 scope 与任何 backfill 的 lesson 完全无关,允许"无相关"显式空 —— 但此时必须单独补跑一个与历史 lesson 相关的任务
- **Priority**:**P0**(这是唯一的验收 Gate,clarification-brief 已明确)
- **Depends-on**:FR-1, FR-2, FR-3, FR-4, FR-5

## 5. Non-Goals

- 状态机增加 / 删除 phase
- Lesson 自动质量评分、自动去重、自动重写
- 多人并发写入 / git 合并冲突处理
- 跨仓库 / 跨项目的 lesson 同步
- 向量化、语义搜索、LLM-maintained schema
- 替代 retrospective 本身

## 6. Acceptance Criteria

### AC-1 抽取链路修复

- [ ] [unit] 给定符合 FR-2 规范的 retrospective.md,运行 `bash spec/bootstrap/commands/start-task.sh --scope test-next --dry-run`,输出含 `plan ... (append lesson)` 行
- [ ] [unit] 去掉 `--dry-run` 后,`<target-path>/lesson-index.md` 被创建或追加了一个新 `## <scope> (date)` block
- [ ] [unit] 运行 11 次(> LRU-10 阈值),lesson-index.md 中 `## ` block 数量 = 10(LRU 生效)
- [ ] [manual] 当 retrospective.md 中 lesson 段为空时,抽取段静默跳过,不创建空 block

### AC-2 模板对齐

- [ ] [unit] `grep -E '^##' spec/templates/retrospective.template.md` 与 `grep -E '^##' skills/baton-retrospective/SKILL.md` 对 lesson section 的 heading 层级一致
- [ ] [unit] `start-task.sh` 抽取 regex 的 heading level 与上述模板一致(通过 validator 或手工 grep 比对)

### AC-3 Explorer / Architect 读路径强化

- [ ] [integration] 在一个无 lesson-index 文件的新任务 `.harness/` 下,让 explorer 跑一次,`exploration.md` §11 含显式 "no lesson-index found" 或类似显式空表达
- [ ] [integration] 在一个有 lesson-index 的新任务中,explorer 的 exploration.md §11 至少引用 lesson-index 中的一个锚点或任务名
- [ ] [unit] validator 对缺失 §11 或完全空白 §11 的 exploration.md 报错

### AC-4 Backfill 完成

- [ ] [manual] `.harness/history/` 15 个任务的 retrospective 至少有 3 个贡献了非显然 lesson
- [ ] [manual] 初始 lesson-index 中每条 lesson 符合 FR-2 判据(非套话 + 可追溯到源 task id)
- [ ] [unit] 初始 lesson-index 结构符合 `spec/templates/lesson-index.template.md`(header + `##` entry block)

### AC-5 物理位置决策落地

- [ ] [manual] `decisions.md` 记录了 FR-5 的方案 A/B tradeoff + 最终选择 + 理由
- [ ] [unit] 所选路径在 `start-task.sh`、`role-contracts.md`、`artifact-schema.md`、`baton-explorer/SKILL.md`、`baton-architect/SKILL.md` 中引用**一致**(由 consistency-check 或手工 grep 验证)
- [ ] [unit] 若选方案 B,`.gitignore` 含对应的 `knowledge/` 条目;且 `ls knowledge/` 能看到文件但 `git status` 不显示它

### AC-6 一致性 Validator(P1)

- [ ] [unit] 故意把 `start-task.sh` 的抽取 regex 层级改回 `###`,validator 报错
- [ ] [unit] 故意把 `retrospective.template.md` 的 lesson 段 heading 改为不一致的层级,validator 报错

### AC-7 Success Gate 真任务验证

- [ ] [e2e] 修复完成后,跑一个新的 baton 任务(scope 不限,规模小),其 exploration.md §11 显式引用至少一条来自 backfill 的 lesson,引用源自 explorer 自动读 index(非人工粘贴)
- [ ] [manual] 人工 diff 新 exploration.md 与 lesson-index,确认引用文本 / 锚点对应一致

## 7. Constraints

- **技术**:
  - 不引入新运行时(Node/Python);限制在 bash + markdown + 既有 skill 结构
  - 不改 `spec/protocol/state-machine.md` 状态机
  - 保留 `role-contracts.md:133-135` 对 verification-explorer / evaluator 的隔离读规则 —— 修复不能让它们读 lesson-index
- **内容**:
  - Backfill 原料是 baton 自举任务(元任务),而非真实公司业务 —— 产出的 lesson 可能对未来真实场景可迁移性弱。接受该局限(clarification-brief 已承认)
- **单人使用**:
  - 可接受本地持久(无版本历史)的 tradeoff(clarification-brief 已承认)
  - 无团队合并、无 PR review 流程要求
- **Convention 已剥离**:
  - ~~"必须跟仓便于回溯"~~(在单人场景下不成立,clarification-brief 已确认方案 B)
  - ~~"必须英文以便未来国际化"~~(单人 + 私密场景不需要,artifact language 依 state notes `artifact_language: zh`)

## 8. Validation Intent

- **FR-1 链路修复**:用 fixture 驱动 start-task.sh,dry-run + 真 run 两层验证
- **FR-2 模板引导**:人工审核 backfill 与后续真任务的 lesson 条目质量
- **FR-3 读路径强化**:integration 级 —— 让 explorer 在两种状态(有/无 lesson-index)下各跑一次,查 exploration.md §11 输出
- **FR-4 Backfill**:manual 审核为主,辅以结构校验
- **FR-5 物理位置**:decisions.md 记录 + consistency-check 兜底
- **FR-6 Validator**:故意引入不一致,验证 validator 报错
- **FR-7 Success Gate**:**这是最终收口** —— 一切其他 AC 都服务于让这个 e2e 能跑通;如果 FR-7 失败,不管其他 AC 绿不绿,MVP 都不算完成

## 9. Traceability

| Clarification Brief Finding | Requirement |
|---|---|
| Core problem: baton 协议缺跨任务维度 → **reframe 后**:已 wire 但损坏 | → FR-1, FR-2, FR-3, FR-4(修复现有机制而非从零构建) |
| R1: 任务完成时 lesson 入 index | → FR-1(写路径),FR-2(质量引导) |
| R2: 任务启动时 explorer 读 index | → FR-3(读路径强化)|
| R3: knowledge/ 仓库根 gitignored | → FR-5(方案 B 决策) + AC-5 |
| R4: 单人可读可手编 markdown | → Non-Goals(禁止 schema/DB/向量库) + FR-1 的纯 markdown 约束 |
| R5: 一次性 backfill | → FR-4 + AC-4 |
| Risk-1 低信号噪音 | → FR-2 判据 + AC-4 非套话审核 |
| Risk-2 钩子触发不可靠 | → FR-3 强化必读语义 + FR-6 validator 兜底 |
| Risk-3 语料贫血 | → Assumptions A1 显式承认 + FR-7 允许补跑任务 |
| Non-goal: state-machine 不改 | → Non-Goals 首条 |
| Non-goal: 自动 lint | → Non-Goals 第二条 |
| Non-goal: 多人合并 | → Non-Goals 第三条 |
| Success criterion: 真跑任务引用 lesson | → FR-7 + AC-7 |
| UR-1 lesson schema 最小化 | → 留给 architect(标记 Decision Needed)|
| UR-2 backfill 粒度 | → FR-4 的"至少 3 条"规则 + 人工审核 |
| UR-3 跨场景可迁移性 | → Assumptions A1 + Constraints "Backfill 原料是元任务" |

## 10. Decision Needed(留给 Architect)

- **D-1(来自 FR-5)**:物理位置 A vs B
- **D-2(来自 OQ-4)**:写入触发点 —— start-task.sh 延迟抽取(现状)vs baton-retrospective SKILL.md 主动写入(更早)
- **D-3(来自 OQ-2)**:一致性保障形式 —— 单一 constants 源 vs 一致性 validator vs 人工兜底
- **D-4(来自 UR-1)**:lesson 条目的最小 schema 字段(id / title / context / trigger / takeaway / 源 task id / 源 section)

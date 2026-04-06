# Scoped Map: knowledge-compound-mvp

**Requirement**: 让 baton 跨任务复利 —— retrospective 的教训能被下一个任务的 explorer 读到。
**Domain**: harness protocol / skills / bootstrap scripts
**Owner**: `scoped-explorer`
**Status**: `done`

## 0. 核心发现(放最前面)

**baton 的 lesson-index 机制已经实现,但静默损坏 —— 从未成功抽取过任何一条 lesson。**

证据:

1. **Scaffold 完整**:
   - `spec/templates/lesson-index.template.md` 存在(commit `884e4ce`: "refactor: rename generator-feedback.md to escalation.md and **wire lesson-index extraction**")
   - `spec/protocol/artifact-schema.md:150-162` 已注册 `lesson-index.md` 为 Optional Artifacts
   - `spec/protocol/role-contracts.md:25,58,133` 规定 explorer/specifier/architect 读取,verification-explorer/evaluator **不读**(独立判断隔离)
   - `skills/baton-explorer/SKILL.md:163-166` 与 §11 "Historical Lessons" 已声明读取
   - `skills/baton-architect/SKILL.md:88-90` 同上
   - `spec/bootstrap/commands/start-task.sh:236-287` 已写入抽取逻辑(从上一任务的 retrospective.md 抽取 → 写入下一任务的 `.harness/lesson-index.md`,LRU-10)

2. **三处错位,导致抽取永远不触发**:

   | 错位 | 位置 | 现象 |
   |---|---|---|
   | **E1: heading level mismatch** | `start-task.sh:244-245` 正则 `/^###.*${section_pattern}/` 找 **level-3** | 但 `spec/templates/retrospective.template.md:17,21` 写的是 **level-2** `## 4. Repo-Specific Lessons`,`skills/baton-retrospective/SKILL.md:147` 输出模板也是 **level-2** `## Repo-Specific Lessons`。`sed` 永远匹配空 block。 |
   | **E2: 历史语料全中文** | 历史 retrospective 全是 `## 4. 仓库特定经验` / `## 5. Harness 经验` | 抽取 regex 是英文字面量(`'Repo.Specific Lessons' 'Harness Lessons'`),对 15 个历史任务全部无效。 |
   | **E3: 无 .harness/lesson-index.md** | `ls .harness/` 根无此文件 | 与 E1/E2 一致:从未有过一次成功的抽取落盘。 |

3. **时间线**:`884e4ce`(wire lesson-index)→ `9792a38`(remove i18n)→ 之后没人跑通一次真任务,所以静默失败从未被发现。

**这个发现重写了问题定义**:任务不是"从零构建 knowledge-compound",而是:
- **(a) 修**:把已 wired 但坏掉的 lesson-index 链路打通
- **(b) 调和**:用户偏好 `knowledge/` 仓库根 + gitignored(私密)vs 现状 `.harness/lesson-index.md`(跟仓,LRU-10,公共 protocol artifact)存在冲突,需 architect 阶段裁决
- **(c) 验证**:上线一次真任务跑通(与成功标准闭环)

## 1. Scope

- **In scope**:
  - `spec/bootstrap/commands/start-task.sh` L236-287 —— 修 heading level 匹配 + 多语言 / 单一语言源决策
  - `spec/templates/retrospective.template.md` —— 与 regex / SKILL 模板对齐
  - `skills/baton-retrospective/SKILL.md` 输出模板 —— 同步 heading 规范
  - `spec/templates/lesson-index.template.md` —— 可能需要结构微调
  - `skills/baton-explorer/SKILL.md:163-166` + §11 —— 强化"必读 + 显式空列表"语义
  - `skills/baton-architect/SKILL.md:88-90` —— 同上
  - 路径决策:`.harness/lesson-index.md`(保留现状)vs `knowledge/lessons.md`(用户偏好)
  - Backfill:把 15 个历史 retrospective 的"仓库特定经验 / Harness 经验"段落转成初始 lesson-index 条目
  - 视决策结果调整 `.gitignore`

- **Out of scope**:
  - `spec/protocol/state-machine.md` 状态机增减(clarification-brief 已列为 non-goal)
  - 自动 lint / lesson 条目质量校验
  - 多人合并、跨仓库同步
  - 替代或取消 retrospective

- **Expected write boundary**(详见 §9):修改 3–5 个文件,新增 1 个 backfill 脚本,可选新增 1 个一致性 validator,可选 1 行 `.gitignore`。

## 2. Entry Point

- **写路径 R1(retrospective → lesson-index)**:
  - 主入口:`spec/bootstrap/commands/start-task.sh:236`(已 wire,**当前坏**)—— 触发时机:下一任务启动时,归档前对上一任务 retrospective.md 抽取
  - 备选入口:`skills/baton-retrospective/SKILL.md` 执行流程尾部 —— 在 retrospective 完成时主动写 lesson-index(触发时机更早)

- **读路径 R2(lesson-index → explorer / architect)**:
  - `skills/baton-explorer/SKILL.md:163-166` 第 1b 步 —— 已 wire,但当前文件不存在所以分支 no-op
  - `skills/baton-architect/SKILL.md:88-90` —— 同上

- **Backfill 入口**:无现成入口,需新增(`spec/bootstrap/commands/` 下新脚本或临时一次性脚本)

- **为什么是这些入口**:
  - `start-task.sh` 是 baton 唯一跨任务边界执行的脚本,天然是写路径归宿
  - explorer + architect 是 `role-contracts.md:133` 明确授权的读者;verification-explorer / evaluator 明确禁止读 lesson-index(隔离判断防偏见),修复时必须保留这层隔离

## 3. Call Chain

**写路径当前状态**:

```text
上一任务完成 (retrospective.md 写好,heading = ## 4. xxx / ## 5. xxx)
   ↓
用户运行 start-task.sh --scope <new-task>
   ↓
start-task.sh L184-234: 归档 .harness/*.md → .harness/history/<ts>-<slug>/
   ↓
start-task.sh L236-287: lesson-index 抽取段
   ├── L244-249: sed 找 ^### Repo-Specific Lessons / ^### Harness Lessons
   │              ❌ 模板产出是 ## (level-2) → 永远空 block
   ├── L251: extracted 全空白 → 跳过写入
   └── (从未到达 L259-284 的落盘分支)
   ↓
继续初始化新任务 .harness/ 模板
```

**读路径当前状态**:

```text
新任务启动,explorer 执行
   ↓
baton-explorer SKILL L163 "If .harness/lesson-index.md exists..."
   ↓
❌ 文件不存在(写路径断裂)→ 跳过
   ↓
exploration.md §11 "Historical Lessons" 可省略
   ↓
explorer 产出零历史教训影响的探索
```

**修复后的预期链路**:

```text
retrospective.md 写好(heading 与 regex 对齐)
   ↓
start-task.sh 抽取命中 → 写入 .harness/lesson-index.md (或 knowledge/lessons.md)
   ↓
新任务 explorer 第 1b 步必读 → exploration.md §11 显式引用 or 显式"无相关"
   ↓
architect / specifier / generator 可选读(role-contracts 已授权)
```

## 4. Data Flow

- **源**:`retrospective.md` 某 heading 下的 markdown bullet list
- **中间态**:`sed -n "/^PATTERN/,/^DELIM/{...}"` 切出 raw markdown block
- **目标**:`lesson-index.md`,结构:
  ```
  # Lesson Index
  > ...header...
  ## <scope> (YYYY-MM-DD)
  - <bullet from retrospective>
  ## <older-scope> (YYYY-MM-DD)
  ...
  ```
- **状态突变**:
  - 归档边界:`.harness/*.md` → `.harness/history/<ts>-<slug>/*.md`
  - 抽取边界:`retrospective.md § N` → `lesson-index.md § <scope>`
  - LRU 截断:`awk -v max=10` 只留最近 10 个 `## ` 块

**数据缺陷**(与 §0 的 E1/E2 一致):
- 抽取 regex 层级错位 → 源数据落不到中间态
- 语言字面量 → 中文历史语料不被识别
- bullet 内容无结构化 → 下一任务 explorer 只能按关键词扫而非按主题索引

## 5. Existing Behavior

- **现况**:
  - `start-task.sh` 抽取段每次新任务启动时运行,但 L246 `if [[ -n "$block" ]]` 永远进不去,L251 判空后直接跳到 artifact 初始化段(L289)
  - `.harness/history/` 15 个历史任务的 retrospective 全部 orphan
  - `skills/baton-retrospective/SKILL.md:147` 输出模板 `## Repo-Specific Lessons`(level-2 无编号),与 `spec/templates/retrospective.template.md:17` 的 `## 4. Repo-Specific Lessons`(level-2 带编号)**语义一致但格式不同**,两者都与 start-task.sh level-3 regex 对不上

- **现有验证规则**:
  - `artifact-schema.md:159-160` 规定 LRU-10,**无**质量校验
  - start-task.sh L251 的 `tr -d '[:space:]'` 是唯一 content gate —— 非空白就写入,不管内容是否"非显然 lesson"

- **隐式约束**:
  - verification-explorer + evaluator 不读 lesson-index(`role-contracts.md:133-135`),这是刻意隔离,修复必须保留
  - lesson-index 语义是 "subsidiary context, not constraints"(`role-contracts.md:25`),explorer 不能把 lesson 当需求引用

## 6. Existing Tests

- **直接相关**:无 —— grep `lesson` 在测试/validator 目录未命中
- **附近可复用**:`spec/bootstrap/commands/validators/` 下的 consistency-check 模式可被用来新增 "lesson-index 链路一致性"校验(验证 template heading level 与 start-task.sh regex 一致)
- **无可用测试**:端到端(任务结束 + 下一任务启动 → lesson 出现在新 `.harness/`)的集成测试完全缺失 —— 这是 E1 静默损坏的直接原因

## 7. Change History

- `884e4ce refactor: rename generator-feedback.md to escalation.md and wire lesson-index extraction` —— **关键 commit**,引入抽取段,**诞生即坏**
- `9792a38 refactor: remove remaining i18n — English-only validator patterns and artifact headings` —— 移除 i18n,但历史 retrospective 仍是中文,加剧 E2
- `50b9807 refactor: standardize naming — skills, commands, and artifacts` —— 命名标准化,可能改动 heading

**高 churn 文件**:`start-task.sh` 近期改动多(单人自举期),但 L236-287 抽取段从 `884e4ce` 后未改

**活跃贡献者**:单人仓库

## 8. Dependency / Risk Scan

- **Integration / infra**:无
- **Migration / schema**:无
- **跨业务域**:无(纯 baton 内部)
- **脆弱点**:
  - **R-A(高)**:heading 名字("Repo-Specific Lessons" / "Harness Lessons")分散在 4 处(template / skill 输出模板 / start-task.sh regex / 可能的 validator),任何一处改名都会再次静默损坏 → 需单一事实源或一致性 validator
  - **R-B(中)**:历史 15 个 retrospective 的中文 headings 使 backfill 只能做中英双模式或人工介入
  - **R-C(低)**:LRU-10 可能丢重要 lesson —— 单人可接受
- **无测试覆盖**:整个 extract → append → prune 链路 0 单元测试,0 集成测试

## 9. Change Shape

- **This looks like**:小型修复 + 流程完善 + 一次性 backfill,不是重构
- **估算文件数**:
  - 修改 3–5 个:`start-task.sh`、`retrospective.template.md`、`baton-retrospective/SKILL.md`、可能 `lesson-index.template.md`、可能 `.gitignore`
  - 新增 1 个:backfill 脚本
  - 可能新增 1 个:一致性 validator
- **代码量**:80–150 行净增/修改

## 10. Open Questions(交给 specifier / architect)

1. **OQ-1(architect)**:物理位置 —— `.harness/lesson-index.md`(跟仓,LRU-10,protocol artifact)vs `knowledge/lessons.md`(仓库根,gitignored,私密)。两种不能同时,Gate 2 需裁决。
2. **OQ-2(architect)**:heading 名字的单一事实源 —— constants 文件?一致性 validator?还是"单人场景接受重复,靠 validator 兜底"?
3. **OQ-3(specifier)**:backfill AC —— "至少 3 条 lesson 被抽出" vs "每个 history 任务至少贡献一条"?考虑 E2,可能人工编辑不可避免。
4. **OQ-4(architect)**:写入触发点 —— 保持 start-task.sh 延迟抽取(现状)vs 改为 baton-retrospective SKILL.md 主动写入(更早,在任务者视野内)。前者依赖 shell,后者依赖 LLM 遵循 SKILL。
5. **OQ-5(architect)**:lesson 的最小质量门槛 —— 若只搬运历史 retrospective 原文,explorer 可能跳过。需要在 retrospective 模板里引入 "What counts as a non-obvious lesson" 引导句。

## 11. Recommendation

- **Proceed?**:**是**,但 problem framing 需要升级
- **Suggested next step**:进入 specifier,把 requirements.md 从 "build from scratch" 改写为 **"fix + harden + backfill the already-wired but silently-broken lesson-index feature"**:
  - R1/R2 措辞调整:不再是"新增钩子",而是"修复现有钩子 + 强化语义 + 一次性 backfill"
  - 新增 R6(由 architect 决策):物理位置(knowledge/ vs .harness/)
  - 新增 R7:heading 源与 regex 的一致性保障(可通过 validator 或单一事实源)
- **Uncertainty flags**:
  - ❓ 修复后的 end-to-end 链路未实际跑过 —— 需要 verification-explorer 阶段真做一次 dry-run
  - ❓ 中文历史语料的 backfill 可行性未验证 —— 可能只能人工单次 copy-paste

## 12. Historical Lessons

> 本仓库**尚无** `.harness/lesson-index.md`(原因见 §0 链路静默损坏)。
> 这本身就是第一条 lesson 候选:**"静默失败路径 = 零 signal = 等同于没实现"**。

- 相关历史教训:**无** —— 本任务正是要把这个机制建起来
- 明确不适用:N/A

---

## Overlay Recommendation

overlay: core

**触发信号**:跨文件 heading-name 约定(4 处)+ 缺失端到端测试 —— 属于"多模块写面 + 接口级约定"的边缘信号,但没有 schema/migration、没有交叉业务域,不足以触发 strict。core overlay 足以覆盖本任务的一致性需求。

# Architecture: knowledge-compound-mvp

**Topic**: 修复并上线 baton lesson-index 跨任务复利机制
**Status**: `proposed`
**Sizing**: `Small`

## 1. Problem Framing

baton 已有 lesson-index 抽取机制(commit `884e4ce` wire),但由于三处错位(heading level / 语料语言 / 无测试)导致**诞生即坏**:从未成功抽取过一条 lesson,`.harness/lesson-index.md` 从未被写出。

本任务**不是从零构建**一套新的知识沉淀机制,而是:

1. 把已 wire 但断裂的链路打通(start-task.sh ↔ retrospective template ↔ skill 输出模板,heading 层级对齐)
2. 在读路径强化"必读 + 显式空列表"语义,让 explorer / architect 不能静默跳过
3. 决策物理位置分歧(`.harness/lesson-index.md` 现状 vs `knowledge/lessons.md` 用户偏好)
4. 一次性 backfill 历史 15 个 retrospective
5. 加一致性 validator 防止未来再次静默损坏
6. 跑一次真任务验证 end-to-end

## 2. First-Principles

### 2.1 Problem Statement

对一个想跨任务复利的单人使用者,baton 缺少一条**可验证的、自动触发的**"上一任务产出 → 下一任务摄入"的信息管道。目前的尝试(lesson-index feature)在三个独立的地方有硬编码耦合,只要任意一处与其他两处不一致,整条链路静默失败,且没有任何信号通知使用者。

### 2.2 Constraints

**真约束(需要设计去适应)**:

- **C1 不引入新运行时** —— 只能用 bash + markdown + 既有 SKILL 结构(来自 requirements §7 + clarification-brief 约束)
- **C2 不改 state-machine.md** —— 状态机不增删 phase(clarification-brief non-goal)
- **C3 Verification-Explorer / Evaluator 必须不读 lesson-index** —— `role-contracts.md:133-135` 的隔离规则不能破坏(这是 baton protocol 的核心隔离假设)
- **C4 单人私密需求** —— 用户明确偏好 gitignored 本地方案,但要与 baton protocol 的 `.harness/` 公共 artifact 契约调和
- **C5 retrospective 是 lesson 的唯一源头** —— 不替代、不绕过 retrospective

**被识别并剥离的 Convention(不是真约束)**:

- ~~"所有 baton artifact 必须跟仓可回溯"~~ —— 这是协议默认,但 lesson-index 在 `artifact-schema.md:150-163` 被明确标为 **Optional Artifact**;加之单人 + 敏感内容场景,此 convention 可挑战
- ~~"heading 名字必须有单一事实源(constants 文件)"~~ —— 单人仓库 + 改名频率低,一致性 validator 足以兜底;过早引入 constants 抽象会违反 baton 的 "markdown + bash" 简洁原则

### 2.3 Solution Categories

针对 **Decision D-1(物理位置)** 枚举两种方案:

#### Category A:保留现状路径,修复现有 wire

- **机制**:`.harness/lesson-index.md` 跟仓,LRU-10,`start-task.sh` 延迟抽取
- **改动面**:只修 `start-task.sh` regex + 对齐模板 + 强化 skill 读路径 + 一致性 validator
- **验证难度**:低(纯 fixture-driven + e2e smoke)
- **风险**:
  - R-A1:违反用户"可放敏感信息"的偏好 —— 公司任务迁移到此仓时,lesson 可能泄漏到 git 历史
  - R-A2:LRU-10 截断可能过于激进(每任务一条 = 只记 10 个任务)

#### Category B:迁移到 knowledge/ 仓库根 + gitignored

- **机制**:`knowledge/lessons.md` 在仓库根,`.gitignored`,无 LRU 或 LRU-50,`start-task.sh` 路径参数化
- **改动面**:修 `start-task.sh` 路径 + 对齐模板 + 强化 skill 读路径 + 更新 `artifact-schema.md` 的路径引用 + 更新 `role-contracts.md:25,58` + 更新 `baton-explorer/SKILL.md:163` / `baton-architect/SKILL.md:88` + 加 `.gitignore` 条目 + 一致性 validator
- **验证难度**:中(除了 fixture + smoke,还需校验多处路径引用一致)
- **风险**:
  - R-B1:换机器 / 重新 clone 时丢失所有历史 lesson —— 用户已在 clarifier 阶段接受
  - R-B2:修改 `artifact-schema.md` 和 `role-contracts.md` 的路径引用 = 动了 baton protocol 的 canonical 文档,需要更大的 diff 范围审查
  - R-B3:`role-contracts.md:133` 显式写的是 `.harness/lesson-index.md` —— 如果迁走,该隔离规则的文本引用也要同步,否则 protocol 自我矛盾

#### Category C(新):双文件 —— 跟仓的 protocol lesson + gitignored 的 private lesson

- **机制**:`.harness/lesson-index.md` 保留(baton 自举元任务用),`knowledge/lessons.md` 新增(公司/私密任务用);`start-task.sh` 根据 config 或 scope 标签决定写入哪个;explorer/architect 两者都读
- **改动面**:Category A 全部 + Category B 全部 + 新增路由逻辑
- **验证难度**:高(两条路径 × 读写两端 = 4 种组合)
- **风险**:
  - R-C1:复杂度翻倍,违反 MVP 原则
  - R-C2:路由规则本身成为新的耦合点
  - R-C3:单人场景下分裂成两个文件没有清晰的切分标准(什么算"元任务"?)

### 2.4 Evaluation

**推荐 Category B(迁移到 `knowledge/` + gitignored),理由**:

1. **用户意图对齐**:clarifier 阶段用户已在四选一中明确选了"knowledge/ 仓库根,gitignored(本地)"。Category A 直接违反该选择,需要推翻用户决定才能成立 —— 这不符合 baton "用户说了算" 的原则
2. **面向未来场景**:clarification-brief 的 Users 维度说用户"未来计划把 baton 用在公司实际工作任务"。Category A 的跟仓策略在公司场景会**灾难性地**把事故 / 决策 / 团队细节曝光到 git 历史(一旦 push 无法撤回)
3. **MVP 纯度**:Category C 的双文件方案有显著的复杂度溢价但没有匹配的价值 —— 单人使用者不需要同时支持"协议自举" + "私密 lesson"两种模式,可以统一成一种
4. **R-B2/R-B3(protocol 文档同步)是可控的**:动的是 `.md` 文档里的路径引用,不是代码契约,review 范围虽扩大但变更类型是"文本对齐",可用 grep + consistency-check 兜底

**为什么 Category A 被拒**:
- 与用户意图正面冲突
- 在公司场景下存在数据泄漏风险
- 虽然 diff 最小,但 MVP 的正确性比 diff 体积更重要

**为什么 Category C 被拒**:
- 复杂度不匹配 MVP 原则
- 单人场景下的切分标准模糊
- 如果用户将来真需要"元任务 lesson 跟仓",可以在 Category B 基础上增量加(反过来则需要重新设计路由)

**未选的替代仍保留的用途**:
- Category A 在**团队协作项目**场景下会重新成为最优解(那时候跟仓回溯价值 > 私密需求)
- Category C 在**已经有稳定私密流 + 想把部分 lesson 开源**的成熟阶段可以增量迁移

---

针对 **Decision D-2(写入触发点)**,两个候选:

#### Option D-2-α:保留 start-task.sh 延迟抽取(现状)

- 下一任务启动时,bash 脚本对上一任务 retrospective.md 做 sed 抽取
- 优点:纯 bash,无 LLM 依赖,可用 dry-run 测试
- 缺点:抽取结果离任务者视野较远(在"开始下一个任务"时才发生,而不是"结束当前任务"时)

#### Option D-2-β:移到 baton-retrospective SKILL.md 主动写入

- retrospective 阶段结束时,LLM 主动把 lessons 写进 lesson-index 文件
- 优点:时机更早,在任务者视野内,可人工审核
- 缺点:依赖 LLM 遵循 SKILL 第 N 步,不如 shell 脚本可靠;且需要文件级写锁(避免并发改动)

**推荐 D-2-α(保留现状)**,理由:
- MVP 原则:bash 抽取是已 wire 的机制,修三行 regex 就能修好,比改 SKILL 流程 + 新增可靠性保证的代价低得多
- 可测试性:bash + fixture 测试便于 verification-explorer 设计 e2e smoke
- 单一机制:避免"两处可能写 lesson"的并发复杂度

---

针对 **Decision D-3(一致性保障)**,推荐:**一致性 validator + 不引入 constants 抽象**。

- constants 抽象会让 bash + markdown 流程被迫引入"模板引擎 / 环境变量替换"复杂度
- validator 是 baton 已有模式(`spec/bootstrap/hooks/post-artifact` + `validators/`),符合现有结构
- 故意制造不一致 → validator 报错,这本身就是 FR-6 的 AC-6

---

针对 **Decision D-4(lesson 最小 schema)**,推荐:

```markdown
## <scope> (YYYY-MM-DD)
- **[context]** <一句话触发条件>: <takeaway> —— [source: .harness/history/<ts>-<slug>/retrospective.md § N]
```

- **[context]**:一个简短的域 tag(如 "bash script"、"skill wiring"、"protocol doc sync")
- 触发条件 + takeaway 合成一个 bullet
- 源锚点用 inline markdown link 而非 YAML 字段 —— 符合 FR-4 "单人可手编 markdown" 约束

不引入 id / 结构化 trigger / status 等字段 —— MVP 纯度。

## 3. Recommended Approach

### 3.1 Approach

**"修已 wire 的链路,迁到私密路径,保留一切隔离不变"**

一句话:不新建机制,把存在但没人用的 lesson-index 机制从 `.harness/` 迁到 `knowledge/`(仓库根,gitignored),顺手修好三处不对齐的 heading,强化 skill 的"必读"语义,加 validator 防回归,一次性 backfill。

### 3.2 Key Change Points

| 改动 | 文件 | 类型 | 含义 |
|---|---|---|---|
| **C1** 路径迁移 | `spec/bootstrap/commands/start-task.sh` | modify | L237 `lesson_index_path="$harness_dir/lesson-index.md"` → `lesson_index_path="$repo_root/knowledge/lessons.md"`,L259 template copy 目标路径同步 |
| **C2** Heading 对齐(方向:统一到 level-2 + English) | `spec/bootstrap/commands/start-task.sh` | modify | L244 `'Repo.Specific Lessons' 'Harness Lessons'` 保留,但 regex 从 `^###` 改为 `^## ([0-9]\. )?`,允许可选编号前缀 |
| **C3** Retrospective 模板引导句 | `spec/templates/retrospective.template.md` | modify | L16-22 在 "## 4. Repo-Specific Lessons" 和 "## 5. Harness Lessons" 段前加 "> 只记录非显然教训:过去踩过 + 下次可能再踩 + 非流程常识" |
| **C4** SKILL 输出模板同步 | `skills/baton-retrospective/SKILL.md` | modify | L147 "## Repo-Specific Lessons" 改为 "## 4. Repo-Specific Lessons"(与 template 带编号对齐)+ 同上引导句 |
| **C5** 新增 Harness Lessons section | `skills/baton-retrospective/SKILL.md` | modify | L147 附近补充 "## 5. Harness Lessons" —— 现有模板只有 Repo-Specific,没有 Harness |
| **C6** Explorer 读路径强化为必须 | `skills/baton-explorer/SKILL.md` | modify | L163-166 第 1b 步从 "if exists" 改为 "always"(文件不存在时显式写 "no lesson-index" 到 §11);§11 从"可省略"改为"必填,空要显式空" |
| **C7** Architect 读路径强化 | `skills/baton-architect/SKILL.md` | modify | L88-90 同上,但 architect 只在 risk assessment 段引用 lesson,保持 "subsidiary cue" 语义 |
| **C8** Protocol 路径引用同步 | `spec/protocol/role-contracts.md` | modify | L25, L58 的 `lesson-index.md` 提及更新为 `knowledge/lessons.md`;L133 隔离规则保持(explicitly mention new path) |
| **C9** Protocol schema 同步 | `spec/protocol/artifact-schema.md` | modify | L150 从 "Optional Artifacts" 移到新的 "External Artifacts" 段(或注释明确该 artifact 不在 `.harness/` 根下);L152-163 更新路径与 LRU 描述 |
| **C10** 读写路径 validator | `spec/bootstrap/hooks/post-artifact` 或 `validators/lesson-index-consistency.sh`(新) | add | 校验 (a) start-task.sh regex heading level 与 retrospective.template.md 一致,(b) exploration.md §11 存在且非空,(c) baton-retrospective SKILL 模板 heading 与 retrospective.template.md 一致 |
| **C11** .gitignore 条目 | `.gitignore` | modify | 追加 `knowledge/` |
| **C12** 一次性 backfill 脚本 | `spec/bootstrap/commands/backfill-lessons.sh`(新,一次性)或临时脚本 | add | 读 `.harness/history/*/retrospective.md`,抽取 `## 4. 仓库特定经验` / `## 5. Harness 经验` 段(兼容中文源),人工审核后输出到 `knowledge/lessons.md` |
| **C13** decisions.md 记录 | `.harness/decisions.md` | modify | 记录 D-1(位置 B)、D-2(保留 α)、D-3(validator)、D-4(minimal schema) |
| **C14** lesson-index 模板路径 | `spec/templates/lesson-index.template.md` | modify | 调整 template 注释(不再是 "auto-populated by start-task.sh during task archival",改为 "auto-populated into `knowledge/lessons.md` by start-task.sh") |

### 3.3 Data / Control Boundaries

**写路径**(修复后):

```text
任务 N 完成 → retrospective.md 写好(## 4. Repo-Specific Lessons / ## 5. Harness Lessons,符合 FR-2 判据)
    ↓
用户运行 start-task.sh --scope task-N+1
    ↓
start-task.sh 归档 .harness/*.md → .harness/history/<ts>-<slug>/
    ↓
start-task.sh lesson-index 抽取段(L236-287)
    ├── sed 正则 /^## ([0-9]\. )?Repo.Specific Lessons/ 命中
    ├── 切出 bullet block
    ├── 若非空 → cat 到 $repo_root/knowledge/lessons.md(首次会从 template 拷贝 header)
    ├── LRU prune(awk -v max=10 或放松到 50)
    └── 打印 `write knowledge/lessons.md`
    ↓
.harness/ 新任务模板初始化
```

**读路径**(修复后):

```text
任务 N+1 explorer 启动
    ↓
baton-explorer SKILL 第 1b 步(必须,非可选)
    ├── 读 knowledge/lessons.md(若不存在则写 "no lesson-index found" 到 §11)
    └── 扫描与当前 task scope 相关的 entry
    ↓
exploration.md §11 "Historical Lessons"
    ├── 若有相关:显式列引用(带锚点)
    └── 若无:显式写 "no relevant lessons in index"(空要显式空)
    ↓
validator 校验 §11 存在且非全空
```

**隔离保证**(C3 不可破坏):

```text
verification-explorer / evaluator 启动
    ↓
这两个 skill 的 SKILL.md 中**不能**出现对 knowledge/lessons.md 的任何 read 指令
    ↓
role-contracts.md:133 文本保留 "Verification Explorer and Evaluator do NOT read lesson-index"(路径名称可同步更新,语义不变)
```

### 3.4 Backward-Compatibility

- `.harness/lesson-index.md` 若已存在(本仓目前没有),需要一次性迁移(脚本 or 手动 `mv` 到 `knowledge/lessons.md`)
- `role-contracts.md` / `artifact-schema.md` 的路径引用是 protocol-level 文本,其他 skill / script 若有 hardcode `"\.harness/lesson-index\.md"` 需要 grep 一遍确保同步(见 Surface Scan L2)
- retrospective.md 既有用户若已按 level-3 heading 写过(grep 显示没有),旧文件无效 → 无需迁移

## 4. Surface Scan

| 文件 | Level | Disposition | 理由 |
|---|---|---|---|
| `spec/bootstrap/commands/start-task.sh` | L1 | modify | C1 路径 + C2 regex 修复 —— 核心写路径 |
| `spec/templates/retrospective.template.md` | L1 | modify | C3 引导句 + heading 编号规范化 |
| `skills/baton-retrospective/SKILL.md` | L1 | modify | C4 输出模板对齐 + C5 补 Harness Lessons section |
| `skills/baton-explorer/SKILL.md` | L1 | modify | C6 读路径强化为必须 |
| `skills/baton-architect/SKILL.md` | L1 | modify | C7 读路径强化(subsidiary 语义保持) |
| `spec/templates/exploration.template.md` | L1 | modify | §11 改为必填 |
| `spec/protocol/role-contracts.md` | L1 | modify | C8 L25, L58, L133 路径引用同步 |
| `spec/protocol/artifact-schema.md` | L1 | modify | C9 L150-163 路径 + 定位同步 |
| `spec/templates/lesson-index.template.md` | L1 | modify | C14 注释同步 |
| `.gitignore` | L1 | modify | C11 追加 knowledge/ |
| `spec/bootstrap/commands/backfill-lessons.sh` | L1 | add | C12 一次性 backfill(可选:临时脚本) |
| `spec/bootstrap/hooks/post-artifact` 或 `validators/lesson-index-consistency.sh` | L1 | add | C10 一致性 validator |
| `spec/bootstrap/commands/sync-entrypoints.sh` | L2 | skip-but-grep | 生成 CLAUDE.md / AGENTS.md 的脚本,确认它没有 hardcode lesson-index 路径(预期:无) |
| `CLAUDE.md` / `AGENTS.md` | L2 | skip-but-grep | 若生成模板 `spec/templates/root-governance.template.md` 提及 lesson-index,同步;否则 skip |
| `spec/templates/root-governance.template.md` | L2 | skip-but-grep | 同上 |
| `docs/baton-positioning.md` / `docs/baton-workflow-best-practice.md` | L3 | skip | 定位文档不写路径细节 |
| `.claude/agents/baton-*.md` | L3 | skip-but-grep | 若有 hardcode 路径同步,预期无 |
| `knowledge/lessons.md`(新文件) | L1 | add | C12 backfill 产出目标 |
| `.harness/decisions.md` | L1 | modify | C13 决策记录 |
| verification-explorer / evaluator 的 skill / agent 文件 | - | **MUST NOT READ** | 违反 C3 隔离 —— 显式 guard |

**L2 grep 检查清单**(实施时运行):

```bash
rg -n "lesson-index|lesson_index|lessons\.md" --type sh --type md | grep -v ".harness/history"
```

预期结果:仅 L1 列出的文件出现 —— 若命中其他文件,加进 L1 或决策是否 skip。

## 5. Reversibility Analysis

| 决策 | 可逆? | 回滚代价 | 回滚方法 |
|---|---|---|---|
| D-1 路径迁到 `knowledge/`(C1, C8, C9, C11) | Yes | Low–Medium | 改回 start-task.sh 路径 + 批量 `sed -i 's|knowledge/lessons.md|.harness/lesson-index.md|g'` + 移除 .gitignore 条目;但若 knowledge/lessons.md 已累积了 lesson 还没被 git 跟踪,需要手动 `git add` 或 `mv`(数据保全要小心) |
| D-2 保留 start-task.sh 延迟抽取(不改) | Yes | Trivial | 无需回滚 —— 未改动 |
| D-3 一致性 validator(C10)| Yes | Trivial | 删 validator 文件 |
| D-4 lesson 最小 schema(C12 backfill 格式)| Yes | Low | 重新 backfill 或手工改格式 |
| C2 heading level 对齐(正则 `^## ([0-9]\. )?`)| Yes | Trivial | 单行 regex 回退 |
| C3 retrospective 模板引导句 | Yes | Trivial | 删行 |
| C6 explorer SKILL 必读语义 | Yes | Low | SKILL.md 文本回退;已产出的 exploration.md §11 "no lesson" 记录无副作用 |
| C8/C9 protocol 文档路径引用同步 | Yes | Medium | 改 protocol 文档是最慢的回退,因为涉及 `role-contracts.md` / `artifact-schema.md` 两个 canonical 文件的 diff review |
| C12 backfill 产出的 `knowledge/lessons.md` | Yes(数据)/ No(人工判断)| Low(数据)/ High(判断)| 数据可重跑 backfill 脚本;但"哪些是非显然 lesson"的人工判断是一次性投入,回滚意味着丢弃这些判断 |

**不可逆决策**:**无**。所有 key decision 都可以在 1 天内全量回退。

**要求额外审查**的决策:
- D-1(路径迁移)—— 人类审批 Gate 2 时应确认:"你接受把 lesson-index 迁出 `.harness/` protocol 根目录,换取私密性吗?"

## 6. Verification Strategy(映射到 requirements.md)

| Req | 测试类型 | 如何验证 | 现有覆盖 | 新增 |
|---|---|---|---|---|
| FR-1(链路修复)| unit + manual | 构造 fixture retrospective.md → `start-task.sh --dry-run` 显示 `plan ... (append lesson)`;去掉 --dry-run 实际写出 | 无 | e2e smoke script(fixtures 目录 + 1 个 bash 驱动脚本) |
| FR-2(模板引导)| manual | 人工审核 backfill + 下一个真任务的 lesson 条目,比对 FR-2 判据 | 无 | checklist in backfill 流程 |
| FR-3(读路径强化)| unit + integration | (a) 无 lesson-index 时 explorer 输出含 "no lesson-index found";(b) 有 lesson-index 时 §11 引用至少一个 anchor;(c) validator 对空 §11 报错 | 无 | validator 规则 + 1 个 fixture exploration.md |
| FR-4(Backfill)| manual + unit | 审核条目内容 + 结构校验(每条符合 C12 schema)| 无 | backfill 脚本 + 人工 checklist |
| FR-5(位置决策)| manual + unit | (a) decisions.md 记录完整;(b) consistency-check 脚本 grep 所有 `lesson-index` 引用无孤儿 | `spec/bootstrap/hooks/consistency-check` 存在,但未覆盖此规则 | 扩展 consistency-check 或新增 `lesson-index-path-consistency.sh` |
| FR-6(validator)| unit | 故意破坏一致性 → validator 报错(两个变体:regex 层级改 + template 层级改)| 无 | 两个故障 fixture + 断言 |
| FR-7(Success Gate)| e2e manual | 真跑一个小 scope 的 baton 任务,人工 diff 其 exploration.md §11 对比 backfill lesson | 无 | 验证记录进 `.harness/verification.md` |

**主验证方法**:fixture-driven bash 测试 + 1 次真任务 e2e。

**Review focus**:
- heading regex 与 template heading level 是否绝对对齐(bash regex 里 `^## ([0-9]\. )?` 支持可选编号前缀,避免未来 template 加/去编号再次损坏)
- verification-explorer / evaluator 的 skill 文件里确认没有任何 `knowledge/lessons.md` 或 `lesson-index` 的 read 指令(C3 守恒)
- backfill 产出的人工判断质量 —— 最弱环节

**验证无法消除的风险**:
- 未来新任务的 retrospective 作者写出套话 lesson —— 这是人类判断,fixture 覆盖不到
- LLM 在执行 explorer SKILL 时不按第 1b 步读 lesson-index —— validator 可以捕捉 exploration.md §11 缺失,但不能保证"真的读了才写的"

## 7. Delivery Order(Medium risk,推荐)

**单元划分**,按依赖顺序:

1. **Unit-A: Heading 对齐(C2, C3, C4, C5)**
   - 文件:`start-task.sh`(regex)、`retrospective.template.md`、`baton-retrospective/SKILL.md`
   - 可独立合并:**是** —— 修完 heading 对齐,即使不做迁移路径,`.harness/lesson-index.md` 写路径就已经能工作了
   - 自验证:fixture unit test

2. **Unit-B: 一致性 validator(C10)**
   - 文件:`spec/bootstrap/hooks/post-artifact` 或新 `validators/lesson-index-consistency.sh`
   - 依赖:Unit-A(validator 规则基于 A 的 heading 规范)
   - 可独立合并:**是** —— validator 本身不影响运行时

3. **Unit-C: 路径迁移(C1, C8, C9, C11, C14)**
   - 文件:`start-task.sh`(路径)、`role-contracts.md`、`artifact-schema.md`、`.gitignore`、`lesson-index.template.md`
   - 依赖:Unit-A(Unit-A 已验证 heading 规范,Unit-C 只是换目标路径)
   - 可独立合并:**是**,但需要同步更新 protocol 文档

4. **Unit-D: 读路径强化(C6, C7, `exploration.template.md` §11 必填)**
   - 文件:`baton-explorer/SKILL.md`、`baton-architect/SKILL.md`、`exploration.template.md`
   - 依赖:Unit-A(不严格,但语义上顺序清晰)
   - 可独立合并:**是**

5. **Unit-E: Backfill(C12)**
   - 文件:`spec/bootstrap/commands/backfill-lessons.sh`(新)+ 产出的 `knowledge/lessons.md`
   - 依赖:Unit-A + Unit-C(Unit-C 决定目标路径)
   - 可独立合并:**是** —— 人工审核后单独 commit

6. **Unit-F: Success Gate 验证(FR-7)**
   - 文件:无新代码 —— 跑一个真任务,产物进 `.harness/verification.md`
   - 依赖:Unit-A + B + C + D + E 全部
   - 可独立合并:验证记录可作为独立 commit

**推荐顺序**:A → B → C / D(并行)→ E → F。

总单元数 6,其中 A B D 可并行起点,C 和 D 可并行,E 依赖 A+C,F 依赖全部。

## 8. Risks

| Risk | 来源 | 影响 | 缓解 / 接受 |
|---|---|---|---|
| **R1** backfill 语料贫血(中文 + 元任务场景)| Assumption A1 | 高 —— FR-7 Success Gate 可能失败 | Backfill 时**人工介入**,允许放弃不可抽取的任务;若 15 个 retrospective 全为套话,升级到 FR-7 补跑任务(clarification-brief 已接受) |
| **R2** LLM 不遵循"必读 lesson-index"新 SKILL 语义 | Assumption A3 | 中 —— 读路径依然静默失效 | validator 校验 exploration.md §11 存在性(可机械检查) + exploration.template.md 模板留位强化提示 |
| **R3** heading regex 仍有边缘情况未覆盖(如 `##  4. ` 带双空格) | C2 regex 设计 | 低 —— 但符合 R-A 脆弱点 | regex 写宽松 + Unit-B validator 故障 fixture 覆盖多种变体 |
| **R4** 迁移到 knowledge/ 破坏协议文档自洽性 | D-1 路径决策 | 中 —— protocol 文档多处引用 | Unit-C 合并前做 `rg -n 'lesson-index|lesson_index|\.harness/lesson.*\.md' --type md --type sh` 全量对照,补齐所有孤儿 |
| **R5** verification-explorer / evaluator 隔离被意外破坏 | C3 护栏 | 高 —— 违反 baton 核心隔离原则 | 合并前手动 grep 这两个 skill 文件确认无 read 指令;写入 checklist |
| **R6** knowledge/ gitignored 导致用户换机器时丢失 lesson | D-1 tradeoff | 低 —— 用户已接受 | 在 decisions.md 显式记录该 tradeoff;可选:在 `backfill-lessons.sh` 附带 "export to portable format" 命令,便于用户手动备份 |
| **R7** LRU-10 对单人长期使用过于激进 | A5 | 低 | 在 D-1 落地时把 LRU 阈值从 10 放宽到 30 或 50(clarification-brief 未约束阈值,可自由选) |
| **R8** start-task.sh 跨平台 bash/awk/sed 差异(尤其 macOS)| 既有 baton 风险 | 低 —— 现有抽取段已经在用这些工具,修改面小 | 沿用 start-task.sh 既有的 BSD/GNU 兼容写法 |

**关键 residual risk**:**R1** 是 Gate 7(FR-7)的唯一 blocker,必须在 backfill 阶段严肃执行人工审核,不能放过套话条目。

## 9. Self-Challenge

### 9.1 这是最优类别,还是"第一个可行的"?

**可能的未选类别:**

- **类别 X**:完全放弃跨任务 lesson,改为"下一个任务启动时 LLM 主动 grep `.harness/history/*/retrospective.md`" —— 无 index,无抽取,直接全文搜索
  - 为什么没选:grep 15 个 retrospective 的全文每次启动都要读 100+ KB 到 LLM context,不可持续;而 index 是 500 字以内的摘要
- **类别 Y**:lesson 写在每个任务的 exploration.md / architecture.md 里,按 tag 交叉引用,不做独立 index 文件
  - 为什么没选:破坏 single source of truth,且 explorer 要 grep 15 个目录 —— 本质上是类别 X 的变形

选定的 Category B 不是唯一可行,但它是**最小改动 × 最大可逆性 × 对齐用户偏好**的组合。

### 9.2 哪些假设未验证?

- **A1(backfill 产出可迁移 lesson)** —— 最弱假设,Phase 5(generator)做 backfill 时才能验证;若失败,FR-7 触发补跑任务的 fallback
- **A3(LLM 遵循 SKILL 必读指令)** —— 无法在 verification-explorer 阶段验证,只能靠 FR-7 真任务观察;validator 是补偿机制
- **知识路径迁移的全量 grep 完整性** —— 依赖 Unit-C 前的 `rg` 扫描质量,有可能漏掉深层引用

### 9.3 skeptic 会先挑战什么?

**最刺耳的挑战**:"你在修一个没人用的 feature。baton 目前 15 个任务全是自举,没一个真公司任务。与其先修 lesson-index,不如先把 baton 放到真场景跑一轮,让需求自己浮出来。"

**我的回应**:
- clarifier 明确 success criterion 是"修好后跑一次真任务验证",所以 FR-7 天然包含了 skeptic 的"先跑一次再说"
- 修已 wire 但损坏的 feature 是"低垂的果子"—— 80% 的代码已存在,改动面小,相比"先做别的"更容易先吃掉
- 修完后不做 backfill + FR-7 才是问题,**做了** backfill + FR-7 就已经是 skeptic 的要求了

**第二个挑战**:"单人使用 lesson-index 收益质疑 —— 你会真的回去读下次任务的 §11 吗?"
- 这是合理质疑。MVP 的 FR-7 正是验证这点。如果 FR-7 完成后连续 3 个任务都没从 §11 获益,应升级风险级别重新评估 lesson-index 是否值得维护。

### 9.4 哪些判断是 pattern-match 而非 derivation?

- **"Category B(私密路径)更好"** —— 主要基于用户 clarifier 阶段的声明,derivation 来自用户意图;但"公司场景下 `.harness/` 会导致泄漏"是 pattern-match(没有具体事故数据支持)
- **"一致性 validator 足够,不需要 constants 抽象"** —— pattern-match:单人 + 改动频率低;若未来变多人或改名频繁,此判断失效
- **"保留 delayed extraction 优于 SKILL 主动写"** —— pattern-match:bash 可靠性高;若 LLM 可靠性显著提升(或有额外约束机制),可重新评估

这些判断都在 Reversibility Analysis 中被标为低回滚代价,所以即使错也不致命。

## 10. Cross-Model Architecture Review

**状态**:本次为 baton-vs-first-principles-planner 对比实验,暂**跳过** codex:rescue adversarial review,保留 baton 方案的独立产出特征,以便后续对比中反映 baton pipeline 的"纯人工 Agent"版本 vs 带 cross-model review 的版本的差异。

若对比后决定上线,再补跑一次 codex:rescue。

## 11. Human Judgment Notes

> Populated during Gate 2 review. Not machine-editable.

- **Gate 2 APPROVED** (2026-04-05). User accepted all 6 recommended defaults in a single pass:
  - D-1 = Category B (`knowledge/lessons.md` 仓库根 gitignored)
  - D-2 = Option α (保留 start-task.sh 延迟抽取)
  - D-3 = Validator-only
  - D-4 = 单行 markdown schema
  - D-5 = LRU 放宽到 30
  - D-6 = 半自动 backfill(脚本 + 人工审核)
- 进入 Phase 5(generator),按 Delivery Order A → B → C/D → E → F 执行。

---

## Decision Needed — 需要人类在 Gate 2 裁决

| Decision | 推荐 | 关键 tradeoff |
|---|---|---|
| **D-1 物理位置** | Category B(`knowledge/lessons.md` 仓库根 gitignored) | 私密性 vs 跟仓可回溯 |
| **D-2 写入触发点** | Option α(保留 start-task.sh 延迟抽取)| bash 可靠性 vs LLM 时机更早 |
| **D-3 一致性保障** | Validator-only(不引入 constants 抽象)| 简洁 vs 防御纵深 |
| **D-4 lesson 最小 schema** | `**[context]** trigger: takeaway [source link]` 单行 | MVP 纯度 vs 结构化可搜索 |
| **D-5 LRU 阈值** | 放宽到 30(原 10) | 单人长期记忆 vs context 量 |
| **D-6 Backfill 介入方式** | 半自动:脚本抽取 + 人工审核 | 可重现性 vs 质量 |

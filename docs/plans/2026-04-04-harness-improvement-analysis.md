# Baton Harness 改进分析

**日期**: 2026-04-04
**来源**: E2E eval 测试 + 全量 skill/hook/template/protocol 审查 + 实际使用场景讨论
**范围**: 10 个 baton skill、3 个 hook、10 个 template、4 个 protocol spec
**目标场景**: 公司中大型 Java 后端项目开发（模块多、关联复杂、历史包袱重、多人协作）
**审查状态**: 工程审查 + Codex 独立审查完成（2026-04-04）
**产品边界**: 核心协议保持通用，Java 特定行为放入 `spec/profiles/java-maven.yaml` 和 `spec/extensions/java-backend-strict/`

---

## 核心问题：各阶段深度未按风险适配

### 现状

当前流程 10 个阶段，6+ artifact：

```
Triage → Clarify → Explore → Specify → Architect → Verify → Generate → Review → Human Close → Retrospective
```

问题不在于步骤数量，而在于每个步骤不区分风险等级一律全深度执行。
Low risk 的配置项变更走和 High risk 的支付重构一样的流程深度。

### 实际任务分布

公司中大型 Java 项目的特点：模块多、关联复杂，改一个地方经常牵连
好几个模块；历史包袱重，很多隐含的业务规则在代码里不在文档里；
多人协作，你改的代码别人也在改；业务逻辑本身就复杂（支付、订单、
权限、工作流）。

| 风险等级 | 占比 | 典型任务 |
|----------|------|---------|
| **Low** | **30-40%** | 加配置项、改文案、加简单查询接口、修明显 bug |
| **Medium** | **40-50%** | 加新接口涉及多个 Service、改业务逻辑、加字段要改多层、跨模块调用 |
| **High** | **15-20%** | 支付/权限相关变更、数据库 schema 变更、核心流程重构、性能优化 |

**Medium 才是主力**，不是 Low。这意味着带 Architect 的流程才是
日常体感，因为改动经常跨模块，需要想清楚方案再动手。

### 根因分析

不是阶段太多，而是 orchestrator 对不同风险等级的调用深度没有差异化。
三个前期阶段（Clarify → Explore → Specify）各自有价值，但 Low risk
任务不需要每个都跑满深度。改进方向是让 orchestrator 按风险等级调整
每个阶段的调用深度，而非合并或删除阶段。

**状态机不变，协议不变，改的是 orchestrator 的路由行为。**

---

## S1. 前期阶段调用深度优化 [P0]

### 设计

Orchestrator 按 risk level 调整 Clarify / Explore / Specify 三个阶段的
调用深度，而非合并为新 skill。状态机和协议层不动。

#### 为什么不合并

工程审查发现合并方案存在三个问题：

1. **体积矛盾**: Clarifier(293行) + Explorer(196行) + Specifier(223行) = 712行，
   比 orchestrator(651行) 还大。而 S5 的目标是缩减 orchestrator。合并会制造一个
   更大的 mega-skill。
2. **状态机改动风险**: 修改 `spec/protocol/states.txt` 和 `state-machine.md` 会
   影响 `validate-transition.sh`(68行, 11个测试)、`pre-transition` hook(133行,
   6个测试)、`state-requirements.sh` 等基础设施，连锁改动成本高。
3. **单一职责**: 每个 skill 聚焦一件事（问需求 / 看代码 / 写规格）比一个 skill
   同时做三件事更容易维护和调试。

#### 按风险等级调整深度

| 阶段 | Low | Medium | High |
|------|-----|--------|------|
| **Clarify** | 跳过（需求通常明确） | 快速确认（1-2个关键问题） | 完整访谈 |
| **Explore** | Convention Scan（项目结构+命名规范） | Dependency Scan（+接口签名+数据模型） | Impact Scan（+调用链+反向引用+测试覆盖） |
| **Specify** | scoped-map 直接含实现范围 | 轻量 requirements（关键验收标准） | 完整 requirements.md |

#### 需求质疑能力保留

不管什么 risk level，AI 都应该在看到代码后质疑不合理的需求：

| 问题类型 | 示例 | AI 应做的 |
|----------|------|----------|
| 写的和想要的不一样 | PM 写"加缓存"，实际问题是查询慢 | 追问根本目的，可能有更优解 |
| 技术上不可行 | "实时同步百万条数据" | 带着性能数据说明不可行，建议替代方案 |
| 和现有系统矛盾 | "物理删除订单"但有外键关联 | 列出受影响的关联关系，建议逻辑删除 |
| 遗漏关键约束 | 没提并发、没提数据量 | 基于代码发现的约束主动提出 |

**关键原则：不是所有模糊都要问，只问"选错了会返工"的。**

#### 按任务类型选择探索策略

不是所有任务都需要同样深度的代码探索：

| 类型 | 信号 | 探索策略 |
|------|------|----------|
| **纯新增** | 新建独立模块/服务 | Convention Scan — 看项目结构、命名规范、通用基类、类似功能的参考代码 |
| **新增依赖现有** | 加接口，调用现有 Service/DAO | Dependency Scan — Convention Scan + 依赖接口的签名和行为 + 数据模型 + 可复用能力 |
| **变更现有** | 改逻辑、修 bug、加字段 | Impact Scan — 完整行为理解 + 调用链 + 反向引用（谁依赖了要改的代码） + 测试覆盖 |

#### Scope 产出：增强版 scoped-map.md

保持 `scoped-map.md` 作为前期阶段的核心产出，增加需求决策记录段落：

```markdown
## 需求决策记录

### 已确认（来自需求文档，验证可行）
- 支持 Excel 批量导入用户数据

### 已澄清（需求模糊，人类确认）
- Q: 批量上限？ A: 5000 条/次

### 已纠正（需求有问题，人类同意修改）
- 原始需求: 物理删除订单
- 问题: 外键约束 + 审计合规（Order 关联 PaymentRecord, ShippingRecord, AuditLog）
- 修改为: 逻辑删除 + 列表不展示
- 确认人: [用户]

### 已补充（需求遗漏，人类确认）
- 补充: 导入需要幂等校验（按手机号去重）
- 原因: 发现 user 表 phone 列有 unique 约束

### 待定（不影响架构，实现时再确认）
- 导出文件名格式

## Implementation Scope

### 要做什么
- [从需求 + 澄清中提取的明确实现目标]

### 受影响的文件和接口
- [写面清单]

### 验收标准
- [ ] [可验证的标准]

### 不做什么
- [显式排除项]
```

### 实施方案

| 动作 | 说明 |
|------|------|
| 修改 orchestrator 路由逻辑 | 按 risk level 调整 Clarify/Explore/Specify 的调用深度 |
| 各 skill 的 Risk-Adaptive Depth 段落对齐 | Explorer 已有，Clarifier 和 Specifier 需要补充 |
| 模板更新 | `scoped-map.template.md` 添加需求决策记录段落 |

**不动的东西**: 状态机、states.txt、validate-transition.sh、pre-transition hook

**涉及文件**:
- `skills/baton-orchestrator/SKILL.md`（路由深度逻辑）
- `skills/baton-clarifier/SKILL.md`（添加 Risk-Adaptive Depth）
- `skills/baton-specifier/SKILL.md`（添加 Risk-Adaptive Depth）
- `spec/templates/scoped-map.template.md`（添加需求决策记录段落）

---

## S2. Verify 轻量化 [P1]

### 现状

独立的 Verifier 阶段在 Java 项目的 Low/Medium 任务中大多过重。
Java 项目通常有成熟的构建和测试基础设施（Maven/Gradle + JUnit/Spring Boot Test），
"测试能不能跑"在 99% 的情况下答案是能。

### 设计

保留 baton-verifier 为独立 skill，但按 risk level 调整深度。
不合并进 Generator，因为"验证先于生成"是 baton 的第一原则
（`CLAUDE.md`: "Verification before generation — prove you can validate
before writing code"）。合并会违反这个原则。

| 风险等级 | Verify 处理 |
|----------|------------|
| Low | Verifier 快速检查（构建能跑、基本测试通过），不产出独立 artifact |
| Medium | Verifier 标准检查，在 State Notes 记录验证命令和结果 |
| High | 完整 Verifier，产出独立 verification-path.md |

### 实施方案

**涉及文件**:
- `skills/baton-verifier/SKILL.md`（添加 Risk-Adaptive Depth，Low risk 快速模式）
- `skills/baton-orchestrator/SKILL.md`（调整 Verify 阶段的路由深度）

**不动的东西**: 状态机（verification_check 状态保留）、Generator 不吸收 Verify 职责

---

## S3. Retrospective 改为条件触发 [P1]

### 现状

每个任务完成后都提议跑 retrospective，但大多数常规任务不需要。

### 设计

只在以下条件触发：
- 用户主动要求
- Repair loop 发生过（eval round > 1）
- 任务曾进入 blocked 状态
- High risk 任务

常规 Low risk 任务顺利完成时不提议 retrospective。

**注意**: `spec/bootstrap/lib/state-requirements.sh` L17 要求 `complete` 状态
必须有 `retrospective.md`。条件化 retrospective 后，当不触发 retrospective
时需要更新此检查逻辑（跳过 retrospective.md 要求，或生成一个最小占位文件）。

**涉及文件**:
- `skills/baton-orchestrator/SKILL.md`（Phase 9 条件化）
- `spec/bootstrap/lib/state-requirements.sh`（更新 complete 状态的 artifact 要求）

---

## S4. Generator commit 策略 — Evaluator diff 不准 [P0]

### 现状

Generator 说"每个 checkpoint 提交"，但没指定基准点。
Evaluator 写着 `git diff HEAD~1`（`skills/baton-evaluator/SKILL.md:35`），
但 Generator 可能做了多次提交。Evaluator 会漏掉早期变更。

**这是当前系统中最可能导致误判的 bug。**

### 设计

1. Generator 开始前记录 `base_commit=$(git rev-parse HEAD)` 到 State Notes
2. Evaluator 读取 `base_commit`，用 `git diff $base_commit..HEAD`
3. **安全网**: Evaluator 启动时检测 base_commit 是否存在。如果缺失，
   在 evaluation.md 中写入警告（"base_commit missing from State Notes,
   falling back to HEAD~1 — diff range may be incomplete"），
   而不是静默使用错误的 diff 范围

**涉及文件**:
- `skills/baton-generator/SKILL.md`（记录 base_commit）
- `skills/baton-evaluator/SKILL.md`（读取 base_commit，缺失时警告，修改 diff 范围）
- `skills/baton-orchestrator/SKILL.md`（Phase 6 入口添加 base_commit 指令）

**边缘情况（记录在 TODOS.md）**: Generator 在 dirty worktree 时会先 stash，
stash 发生在 base_commit 记录之后。此时 `base_commit..HEAD` 不包含 stash 内容。
频率低，S4 主修复先落地，边缘情况后续处理。

---

## S5. Orchestrator 瘦身 — DRY 违反消除 [P0]

### 现状

Orchestrator 已达 650+ 行。关键指令被埋在底部，AI 遵循率低。
主要膨胀来源：Artifact Language Policy 在 9 个 skill 中各复制一份（~100行重复），
Structured Question Tool 在 3 个 skill 中各复制一份。

### 设计

不是提取到 `references/` 目录（没有加载机制），而是：

1. **Artifact Language Policy**: Orchestrator 在 Phase 0 读取
   `.harness/profile.local.yaml` 的 `documentation.artifact_language` 设定，
   写入 State Notes 一次。各 skill 删除内联的 Artifact Language Policy 段落，
   改为从 State Notes 读取语言设定。
2. **Structured Question Tool**: 保留在各 skill 中（已在另一个改进计划中
   强化为 MUST + DO NOT 格式，见 AskUserQuestion 修复计划）。
3. **Codex 调用指令**: 已在另一个改进计划中统一为 `codex:rescue` 路径。

### 实施方案

**涉及文件**:
- `skills/baton-orchestrator/SKILL.md`（Phase 0 添加语言检测，删除内联策略）
- 9 个 baton skill（删除 Artifact Language Policy 段落，改为读 State Notes）

---

## S6. State Notes 结构化 [P1]

### 现状

State Notes 同时承载 risk_level、codex_available、blocked reason、
human_ack、batch progress、base_commit。全是自由文本，解析脆弱。

### 设计

改为固定键值格式：

```markdown
## State Notes
- risk_level: Medium
- task_type: change_existing
- codex_available: true
- codex_skill: codex:rescue
- human_ack: false
- base_commit: abc1234
- artifact_language: zh
```

hooks 和 skills 用 `grep -E '^- key: '` 可靠提取。

**替代方案（记录在 TODOS.md）**: 考虑将机器可读状态移到独立的
`.harness/task-meta.yaml`，保持 `task-status.md` 纯人类可读。
这样 hooks 不需要解析 markdown，但需要两个文件。决策需在 S6 实施前确定。

**涉及文件**:
- `spec/templates/task-status.template.md`
- `spec/bootstrap/hooks/pre-transition`
- `skills/baton-orchestrator/SKILL.md`
- 所有读取 State Notes 的 skill

---

## S7. 状态转换历史记录 [P1]

### 现状

`task-status.md` 只记录当前状态，无转换历史。调试和 retrospective 缺乏数据。

### 设计

在 `task-status.md` 中添加 `## Transition Log`：

```markdown
## Transition Log
| From | To | Timestamp |
|------|----|-----------|
| exploring | specifying | 2026-04-04T10:15 |
| specifying | architecting | 2026-04-04T10:42 |
```

由 hook 自动追加。

**涉及文件**:
- `spec/templates/task-status.template.md`
- `spec/bootstrap/hooks/`（扩展或新增 post-transition）
- `skills/baton-retrospective/SKILL.md`（读取 Transition Log）

---

## S8. Risk-Adaptive 全局对齐 [P1]

### 现状

Orchestrator 的 Low-Risk Fast Track 表格与各 skill 的 Risk-Adaptive
Depth 表格维度不匹配，容易让 AI 混淆。7 个 skill 各有独立的
Risk-Adaptive 表格，维度各异，没有单一可信来源。

### 设计

建立一份全局 Risk-Adaptive 矩阵，各 skill 引用统一来源：

| Phase | Low | Medium | High |
|-------|-----|--------|------|
| Clarify | 跳过或 1-2 个问题 | 快速确认 | 完整访谈 |
| Explore | Convention Scan | Dependency Scan | Impact Scan |
| Specify | 内含在 scoped-map | 轻量 requirements | 完整 requirements.md |
| Architect | 跳过或单方案 | 标准多方案 | 完整方案比较 + delivery order |
| Verify | 快速检查 | 标准检查 | 独立 Verifier + verification-path.md |
| Generate | 1-2 批次 | 逻辑单元批次 | 严格按 delivery order |
| Review | Evaluator only, Layer 1+3 | Codex + Evaluator 全层 | Codex adversarial + Evaluator 全层 |

**实施建议（记录在 TODOS.md）**: 考虑将 risk-adaptive 行为编码进
profile 数据（`java-maven.yaml` 等）和 hook 运行时检查，而非添加
另一个 markdown 矩阵。执行时检查比文档更可靠。

**涉及文件**:
- `skills/baton-orchestrator/SKILL.md`
- 各 skill 的 Risk-Adaptive Depth 段落

---

## 其他改进项

### S9. profile.local.yaml 闭环 [P2]

Retrospective 写 Profile Patches 但没有 skill 读取。定义标准 profile key
并让对应 skill 读取，使反馈闭环。

### S10. Skill 中途崩溃恢复 [P2]

利用 draft artifact 机制：Orchestrator 恢复时检测到 draft artifact → 重跑该 phase。

### S11. Evaluator partial re-evaluation [P3]

Repair loop 中 Layer 2 只 review 修复 diff，Layer 3 只重验上轮 BLOCKED criteria。

### S12. Artifact 变更追踪 [P3]

artifact 头部添加 `**Last Modified**: <timestamp>`，或依赖 git log 追踪。

---

## 优先级总表

| 优先级 | ID | 改进项 | 类型 | 影响 |
|--------|----|--------|------|------|
| **P0** | S1 | 前期阶段调用深度优化 | 深度调优 | Orchestrator 按风险等级差异化调用 Clarify/Explore/Specify 深度 |
| **P0** | S4 | Generator base_commit / Evaluator diff 安全网 | Bug 修复 | 消除 Evaluator 误判风险，缺失 base_commit 时显式警告 |
| **P0** | S5 | Orchestrator 瘦身 — DRY 消除 | 效率 | 语言策略集中到 State Notes，9 个 skill 删除副本 |
| **P1** | S2 | Verify 轻量化（保持独立） | 深度调优 | Low risk 快速检查，High risk 完整 verification-path.md |
| **P1** | S3 | Retrospective 条件触发 | 流程优化 | 常规任务不再提议回顾；需同步更新 state-requirements.sh |
| **P1** | S6 | State Notes 结构化 | 可靠性 | Hook 解析稳定性 |
| **P1** | S7 | 状态转换历史 | 可观测性 | 调试和 retrospective 数据 |
| **P1** | S8 | Risk-Adaptive 全局对齐 | 一致性 | 防止 AI 混淆 |
| **P2** | S9 | profile.local.yaml 闭环 | 功能 | 长期反馈闭环 |
| **P2** | S10 | 崩溃恢复 | 健壮性 | 中断后自动恢复 |
| **P3** | S11 | Partial re-evaluation | 效率 | Repair loop 加速 |
| **P3** | S12 | Artifact 变更追踪 | 可追溯 | Git 部分覆盖 |

---

## 改进后流程一览

**流程路径不变，每个阶段的深度按风险等级调整。**

### Low risk（30-40% — 加配置、改文案、简单查询、明显 bug）

```
Triage → Clarify(跳过) → Explore(Convention Scan) → Specify(内含在scoped-map)
  → Architect(跳过或单方案) → Verify(快速检查) → Generate → Review → Human Close
```

体感轻快：前期阶段快速通过，Architect 和 Verify 最小化深度。

### Medium risk（40-50% — 日常主力，跨模块接口、业务逻辑变更）

```
Triage → Clarify(快速确认) → Explore(Dependency Scan) → Specify(轻量requirements)
  → Architect(标准多方案) → Verify(标准检查) → Generate → Review → Human Close
```

**这是走得最多的路径。** 中大型项目的改动经常跨模块，需要想清楚方案再动手。
Architect 是值得的投入。

### High risk（15-20% — 支付/权限、schema 变更、核心重构）

```
Triage → Clarify(完整访谈) → Explore(Impact Scan) → Specify(完整requirements.md)
  → Architect(完整方案比较) → Verify(独立Verifier) → Generate → Review → Human Close → Retro
```

完整流程，所有 artifact，所有深度。涉及资金、数据安全、核心流程时才需要跑全套。
Retrospective 在 High risk 时自动触发。

---

## 审查结论

工程审查 + Codex 独立审查（2026-04-04）达成以下共识：

### 框架决策

1. **深度调优，不改状态机**: 所有改进在 orchestrator 路由层实现，
   `spec/protocol/` 下的状态机、状态列表、转换验证脚本不动。
   这大幅降低了实施风险和测试回归范围。

2. **产品边界**: 核心协议保持通用（不写 Java 特定逻辑），
   Java/Maven 特定行为放入现有的 `spec/profiles/java-maven.yaml`
   和 `spec/extensions/java-backend-strict/`。

3. **Verify 保持独立**: "验证先于生成"是 baton 第一原则，
   不因 Java 测试基础设施成熟就合并进 Generator。
   通过 Risk-Adaptive 深度调整解决"过重"问题。

### 关键修正

| 原始提案 | 审查后 | 原因 |
|----------|--------|------|
| S1: 合并三阶段为 Scope skill | 调整调用深度，不合并 | 合并产生 712 行 mega-skill，状态机改动风险大 |
| S2: Verify 合并进 Generator | Verify 轻量化，保持独立 | 违反"验证先于生成"原则 |
| S5: 提取到 references/ 目录 | 语言策略写入 State Notes | references/ 没有加载机制 |

### 新增发现

- **S3 隐藏依赖**: `state-requirements.sh` L17 要求 complete 状态有 `retrospective.md`，
  条件化 retrospective 需同步更新
- **S4 静默回退风险**: base_commit 缺失时 Evaluator 不能静默用 HEAD~1，必须显式警告
- **S6 替代方案**: 考虑 `.harness/task-meta.yaml` sidecar 文件分离机器状态和人类可读状态

### 待决事项（记录在 TODOS.md）

1. S4 dirty-worktree stash 后 base_commit 不包含 stash 内容
2. S6 sidecar 文件 vs 结构化 State Notes 的选择
3. S8 risk-adaptive 行为编码进 profile 数据 vs markdown 矩阵

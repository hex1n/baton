# `spec/` 目录深度分析

**问题**：`spec/` 目录是什么、如何组织、设计权衡在哪里？
**深度**：Deep — 完整协议设计，多层结构（核心 / 扩展 / 适配器 / Profile），含明确的路线图和架构张力
**核心结论**：一个以文件为基础、工具无关的治理协议，优先保证可移植性，通过扩展层叠加更重的 Java 专用严格模式。

---

## 一、整体架构

```
spec/
├── protocol/          ← 规范核心，工具无关
│   ├── state-machine.md
│   ├── role-contracts.md
│   ├── artifact-schema.md
│   └── gates.md
├── templates/         ← 制品模板（在目标仓库本地使用）
├── adapters/          ← CLI 工具能力映射
│   ├── cli-adapter-interface.md  ← 抽象接口契约
│   ├── claude-code.md
│   ├── codex.md
│   └── cursor.md
├── profiles/          ← 仓库类型检测与命令示例
│   ├── java-maven.yaml
│   ├── node-monorepo.yaml
│   └── python-service.yaml
├── extensions/
│   └── java-backend-strict/  ← Spring/Java 重型叠加层
│       ├── README.md
│       ├── artifact-overlay.md
│       ├── state-overlay.md
│       ├── runtime-evaluator.md
│       ├── v1-to-11-roadmap.md
│       └── templates/
├── bootstrap/         ← 采用脚本与检查清单
│   ├── init-harness.{md,sh,ps1}
│   └── start-task.{md,sh,ps1}
├── README.md
├── VERSION            ← 1.0.0
└── 11.md             ← 原始中文设计文档（Java/Spring 专项）
```

**分层是刻意的**：`protocol/` 是不变的核心；`adapters/`、`profiles/`、`extensions/` 是变化点，永远不触碰核心规则。

---

## 二、核心协议（`protocol/`）

### 状态机（`protocol/state-machine.md`）

10 个规范状态，构成严格的线性流水线，加一个安全阀：

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete

任意状态 → blocked
blocked → {verification_check | architecting | generating}
```

**关键设计选择**：

- `awaiting_human_arch` 是具名状态，不是口头约定。架构必须经过人工明确审批，验证工作才能开始。
- `verification_check` 在 `generating` 之前——"验证先于生成"的原则被结构化。不能在未证明验证路径可执行的情况下进入实现。
- `blocked` 有三个出口，对应三种实际失败模式：无法验证、设计有误、实现卡住。
- **每个工作区同时只能有一个活跃任务**（`state-machine.md` 第 101 行）。并行工作需要使用 worktree。

### 角色契约（`protocol/role-contracts.md`）

8 个角色，每个角色有明确的输入/输出契约：

| 角色 | 输入 | 输出 | 制品责任 |
|------|------|------|----------|
| Repo Explorer | 仓库根目录、Profile | 仓库地图、高风险目录 | 可选 `repo-map.md` |
| Scoped Explorer | 用户请求、仓库地图 | 调用链、写入面、测试锚点、风险 | `exploration.md` |
| Specifier | 请求 + exploration | 需求、验收标准 | `requirements.md` |
| Architect | exploration + requirements | 方案、文件影响、验证策略、权衡 | `architecture.md` |
| Verification Explorer | architecture、Profile | 精确命令、可执行性证明、阻塞条件 | `verification.md` |
| Generator | 已审批的需求 + 架构 + 验证路径 | 代码变更 | 更新 `task-status.md` |
| Reviewer | 变更文件 + 需求 + 架构 | 发现项、残余风险 | 更新 `task-status.md` |
| Evaluator | diff + 审查结论 + 验证结果 | 通过/拒绝、未满足标准 | 更新 `task-status.md` |

**关键设计**：Reviewer 和 Evaluator 是不同角色。Reviewer 收集证据，Evaluator 做结论判断。在严格模式下，Evaluator 在主评估阶段被明确禁止阅读 Generator 的源代码（`runtime-evaluator.md` 第 19 行）——保护独立性，防止合理化偏差。

### 关卡（`protocol/gates.md`）

5 个关卡，每个都有明确的通过/失败标准：

| 关卡 | 位置 | 核心判据 |
|------|------|----------|
| 1 | Specifier 之前 | 入口点、写入面、测试锚点、高风险目录均已识别 |
| 2 | Verification Check 之前 | 需求与架构一致；**人工已审批** |
| 3 | Generator 之前 | 精确命令可执行；已定义备用路径 |
| 4 | Human Close 之前 | 发现项明确；所有阻塞已解决或已接受 |
| 5 | Complete 之前 | 人工接受残余风险；确认目标已达成 |

**关卡 3 最具操作性**：大多数 Agent 工作流直接跳进生成阶段。此关卡强制在任何代码编写之前，先证明验证路径可以运行。

### 制品模式（`protocol/artifact-schema.md`）

6 个必需制品，每个有强制章节。一个核心原则贯穿始终：

> "制品应在没有模型特定提示上下文的情况下可读。"

即**制品自包含规则**——每个制品必须能被全新的 Agent 实例或人工审查者冷读懂，不依赖对话历史。

---

## 三、适配器层（`adapters/`）

`cli-adapter-interface.md` 定义了任何 CLI 工具必须支持的最小能力集：

**必需**：文件读写、列目录、搜索、运行命令（含退出码/stdout/stderr）、获取仓库根目录和当前分支、创建 worktree、更新制品状态。

**可选**：生成子 Agent、等待子 Agent、发送输入、生成独立审查 Agent。

**硬约束**：适配器不得更改规范状态、必需关卡、必需制品，或取消明确阻塞的要求。适配器只能控制提示措辞、角色到 Agent 调用的映射方式、临时执行日志的存储方式。

Claude Code 和 Codex 适配器共享相同建议：

- 主会话 = 编排器
- Explorer、Reviewer、Evaluator = 条件允许时使用隔离上下文
- Generator = 非平凡代码变更使用独立 worktree
- 如无子 Agent，降级为顺序执行（角色顺序不变，制品写入不得省略）

---

## 四、Profile 层（`profiles/`）

Profile 是声明式的仓库类型检测器，包含具体命令。以 `java-maven.yaml` 为例：

```yaml
repo_signals: [pom.xml, src/main/java, src/test/java]
verification_style:
  primary: 针对性 junit 或 testng 命令
high_risk_surfaces: [integration, bootstrap, migrations, generated-sources]
example_commands:
  verify:
    - mvn -pl <module> -am test
    - mvn -pl <module> -am -DskipTests compile
```

Profile 是**证据目录**——告诉 Explorer 要找什么、告诉 Verification Explorer 要尝试哪些命令。它们不改变协议流程，只为每个仓库填充 `profile.local.yaml` 的具体内容。

---

## 五、扩展层：`java-backend-strict/`

这是协议变得实质更重的地方。三个文件定义了升级内容：

### 制品叠加（`artifact-overlay.md`）

核心 v1：6 个必需制品。
严格模式额外增加 6 个：

| 制品 | 写入者 | 用途 |
|------|--------|------|
| `codebase-map.md` | repo-explorer | 全局仓库地图（必需，非可选） |
| `decisions.md` | architect | 记录"为什么"和"为什么不" |
| `api-contract.yaml` | architect | 稳定的 API 验证契约 |
| `evaluation-report.md` | evaluator | 发现项 + 通过/拒绝 |
| `generator-feedback.md` | generator | 设计不匹配升级通道 |
| `runtime-signals/` | evaluator | 原始运行时证据（SQL 日志、性能、事务、actuator） |

**通信规则（严格模式）**：Agent 只通过文件通信。Generator 不得重写 `requirements.md` 或 `decisions.md`。Evaluator 在主评估期间不得修改源代码。Generator 通过 `generator-feedback.md` 升级设计不匹配问题，而非临时修改源码。

### 状态叠加（`state-overlay.md`）

核心 v1 是面向任务的。严格模式在任务内部引入**模块循环**：

```
repo-explorer → specifier → architect → 人工架构审批
  → verification_check
  → generator(模块1) → evaluator(模块1)
  → generator(模块1 修复) → evaluator(模块1 重跑)
  → 下一模块
  → cross-cutter
  → 人工关闭
```

`task-status.md` 通过 scope 列编码模块 + 轮次粒度：
- `task-id/module-1`
- `task-id/module-1#eval-1`
- `task-id/module-1#eval-2`
- `task-id/cross-cutter`

在不改变核心文件结构的前提下，暴露模块和轮次信息。

### 运行时 Evaluator（`runtime-evaluator.md`）

严格模式的 Evaluator 是三层模型：

**第一层 — 确定性检查**：编译、现有测试、API 契约验证、DB 断言、健康端点。任何硬失败立即阻塞，不允许高层解释。

**第二层 — 运行时信号**：SQL 日志、事务行为、延迟、异步执行、缓存行为、连接池。输出 = 证据，非最终判断。

**第三层 — 需求驱动判断**：验收检查清单 → 哪些需求已满足、哪些边界条件缺失、哪些信号应升级为阻塞项 vs. 警告。

**来源独立规则**：Evaluator 从需求 + API 契约 + 运行时推导主要判断，而非阅读 Generator 的源代码。代码审查是之后单独的活动。

**修复循环**：evaluator → generator → evaluator（最多 3 轮）→ 升级给人工。

Cross-Cutter 不是新角色，是所有模块完成后 Evaluator 的最终全局模式。

---

## 六、`11.md` 文档

`spec/11.md` 是原始设计文档：中文，标题为"Java 后端多 Agent Harness — 最终设计 v1.0"，是 `java-backend-strict` 扩展的上游来源，早于可移植 v1 规范。

相对于 v1 规范化内容，`11.md` 额外包含：

- **成本/时间模型**：一个 3 模块 Java 任务约 $30-50；相比 6 小时人工约 $200，或单 Agent 无验证约 $5-10
- **上下文重置策略**：Generator 每模块只读取当前模块的需求 + 架构；Evaluator 读取需求 + API 契约，**不读源代码**
- **恢复模式**：编译失败 3 次重试，然后回滚到最后检查点，然后升级
- **明确适用范围**："需求清晰的业务系统，3-10 模块复杂度，标准 Java/Spring 技术栈"

核心设计哲学（直接引用）：

> 用正确的工具解决正确层级的问题——确定性问题用确定性工具，需要创造力的问题用 AI，不可逆决策交给人工。

---

## 七、Bootstrap

`init-harness.md` 描述了 10 步采用流程，"首日最小路径"归纳为 8 步：
选 Profile → 选适配器 → 创建 `.harness/` → 填写 `profile.local.yaml` → 运行 Repo Explorer → 运行 `start-task` → 运行 Verification Path Check → 完成一个试点任务。

`start-task` 通过拒绝在现有未完成任务行存在时创建新行，强制执行单任务不变量。同时提供轻量历史机制：`.harness/history/<timestamp>-<scope>/`。

---

## 八、设计张力与权衡

**张力 1：可移植性 vs. 严格性**
核心协议刻意最小化。Java 扩展要重得多（12 vs. 6 个制品，模块循环，三层 Evaluator）。通过扩展层管理这个张力——严格行为是 opt-in 的，核心永不膨胀。

**张力 2：人工关卡 vs. 自主流程**
5 个显式关卡，2 个需要人工操作（关卡 2：架构审批；关卡 5：人工关闭）。严格模式再加 3 个（需求确认、迁移审批、3 轮 Evaluator 失败后的升级）。这是刻意的：协议不是全自动的，在架构和收尾决策上，人工判断是承重结构。

**张力 3：文件控制平面 vs. 执行开销**
所有状态在 `task-status.md` 中，不在会话记忆里。这使得上下文隔离成为可能（新 Agent 实例可以冷启动接手），但要求每个角色在交接时规范地更新文件。协议没有执行层——依赖适配器实现来保证合规。

**张力 4：Evaluator 独立性 vs. 修复效率**
来源独立规则（Evaluator 不在主评估阶段读 Generator 代码）防止合理化偏差——先读代码往往会导致为代码辩护而非测试它。但这意味着 Evaluator 必须在第二遍才能定位阻塞项，增加了往返成本。3 轮修复上限是熔断器。

---

## 九、结构性空白 / 开放问题

1. **无执行层**：协议是规范，不是实现。没有机制强制 Agent 不跳过关卡。协议规定"当前所有者 Agent 更新 `task-status.md`"，但未定义如果不更新会怎样。`.claude/skills/harness-*.md` 中的角色技能可能实现了硬性关卡检查——若如此，执行空白在实践中可能不存在，但规范本身仍缺少这一层。

2. **Reviewer 角色欠规范**：相比 Evaluator 的三层模型和专用模板，Reviewer 只有"发现项优先 + 残余风险 + 明确无发现"。不对称是刻意的（Reviewer = 轻量，Evaluator = 重量），但 Reviewer 可以更具体。

3. **Cross-Cutter 状态歧义**：`state-overlay.md` 将 Cross-Cutter 放在所有模块之后，但核心状态机中没有对应的显式状态。它被描述为"Evaluator 的最终全局模式"，复用 `reviewing` 状态。若状态机被工具化，这种隐式复用可能产生追踪歧义。

4. **`11.md` 是信息性文档，非规范性文档**：它是 Java 扩展设计的事实来源，但扩展文件（`artifact-overlay.md`、`state-overlay.md`、`runtime-evaluator.md`）并不引用它。只读扩展文档的人不会知道 `11.md` 中记录的成本模型、上下文管理策略和适用范围限制。

5. **Profile 自动检测未指定**：`init-harness.sh/ps1` 支持 `--profile auto`，但协议文档没有规定检测算法。推测是解析各 Profile YAML 的 `repo_signals`，但这是实现定义的行为。

---

## 来源审计

| 声明 | 来源 | 获取方式 |
|------|------|----------|
| 状态机：10 个状态，`any → blocked`，blocked 三出口 | `spec/protocol/state-machine.md` | 本次会话读取 |
| 角色契约：8 个角色，含输入/输出规范 | `spec/protocol/role-contracts.md` | 本次会话读取 |
| 5 个关卡，含通过/失败标准 | `spec/protocol/gates.md` | 本次会话读取 |
| 制品模式：6 必需 + 4 可选 | `spec/protocol/artifact-schema.md` | 本次会话读取 |
| Evaluator 来源独立规则 | `spec/extensions/java-backend-strict/runtime-evaluator.md:19` | 本次会话读取 |
| 严格模式：6 个额外制品 | `spec/extensions/java-backend-strict/artifact-overlay.md` | 本次会话读取 |
| 模块循环与 scope 编码约定 | `spec/extensions/java-backend-strict/state-overlay.md` | 本次会话读取 |
| v1-to-11 路线图：P0-P5 阶段 | `spec/extensions/java-backend-strict/v1-to-11-roadmap.md` | 本次会话读取 |
| Java Profile：repo_signals、高风险面、示例命令 | `spec/profiles/java-maven.yaml` | 本次会话读取 |
| Bootstrap：10 步流程 + 8 步最小路径 | `spec/bootstrap/init-harness.md` | 本次会话读取 |
| start-task：单任务强制、归档约定 | `spec/bootstrap/start-task.md` | 本次会话读取 |
| Claude Code 适配器：worktree + 顺序降级规则 | `spec/adapters/claude-code.md` | 本次会话读取 |
| VERSION = 1.0.0 | `spec/VERSION` | 本次会话读取 |

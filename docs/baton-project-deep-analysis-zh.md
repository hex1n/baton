**问题**: Baton 项目的架构、组件、设计哲学及各部分如何协同工作？
**深度**: 深度分析
**核心发现**: Baton 是一个可移植的、协议优先的 AI 编码 Agent 协作框架，通过文件制品的闭环状态机、Hook 驱动的运行时强制执行和多宿主适配器支持来实现结构化协作。
**待解决问题**: 3 个 — 见文末

---

# Baton 项目深度分析

## 1. 概览

Baton 是一个用于 AI 辅助编码任务的**可移植 Harness 协议**。它定义了 AI Agent 与人类之间的结构化协作闭环——每个阶段产出基于文件的制品，人类门控强制关键决策，运行时 Hook 防止协议违规。

```
┌──────────────────────────────────────────────────────────────┐
│                    BATON 架构                                 │
│                                                              │
│  spec/protocol/     ← 可移植协议（工具无关）                    │
│  spec/adapters/     ← 宿主特定映射（CC/Codex/...）             │
│  spec/bootstrap/    ← Shell 脚本（安装、Hook、库）              │
│  spec/templates/    ← 制品模板（中/英文）                       │
│  spec/profiles/     ← 仓库类型配置（java/node/python）          │
│  spec/extensions/   ← 技术栈特定叠加层（java-strict）           │
│  skills/            ← 角色技能定义（规范源）                     │
│  .claude/skills/    ← 运行时技能入口（符号链接）                  │
│  .agents/           ← Agent 定义（符号链接）                    │
│  .harness/          ← 每任务制品 + 控制平面                     │
│  tests/             ← 基于 Shell 的测试套件                     │
└──────────────────────────────────────────────────────────────┘
```

- **版本**: 1.0.0
- **创建**: 2026-02-27（首次提交）
- **提交数**: 截至 2026-04-04 共 225 次
- **语言**: 纯 Shell (bash) 运行时；Markdown + YAML 制品
- **规模**: 引导脚本约 4,352 行 Shell 代码；约 12 个技能定义

✅ 已验证：全部来自本次会话中的直接文件读取和 git log。

---

## 2. 核心设计哲学

来自 `spec/README.md` 的六大原则：

1. **协议为先** — 规范与工具无关；特定 Agent CLI 只是执行适配器
2. **仓库特定知识放在配置文件中** — 不放入协议核心
3. **多 Agent 优先，顺序执行也有效** — 优雅降级
4. **验证是一等公民** — Gate 3 在验证路径被证明可执行之前阻止代码生成
5. **`task-status.md` 是最小控制平面** — 其他都是便利层
6. **扩展增加严格性** — 更重的行为（如 Java 运行时验证）放在扩展中，不放入核心

---

## 3. 状态机

Baton 的核心是一个 **10 状态有限状态机**，具有线性正常路径和显式修复循环：

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

任何状态都可以转换到 `blocked`。阻塞状态必须分类：
`verification_blocker`（验证阻塞）、`scope_blocker`（范围阻塞）、`environment_blocker`（环境阻塞）或 `design_blocker`（设计阻塞）。

### 门控（质量检查点）

| 门控 | 前置于 | 强制执行内容 |
|------|--------|------------|
| G1: 范围探索完成 | Specifier | 入口点、写入面、测试落点、风险 |
| G2: 架构已批准 | Verification | 需求 ↔ 架构一致；**人类批准** |
| G3: 验证路径检查 | Generator | 验证命令可执行，隔离模式已声明 |
| G4: 独立评审 | Human Close | evaluation.md 存在且含裁决 |
| G5: 人类关闭 | Complete | **人类确认**目标已达成 |

五个门控中有两个强制需要人类参与（G2、G5）。协议在物理层面无法绕过它们 —— `pre-transition` Hook 在允许从 `awaiting_human_arch` 或 `ready_for_human_close` 转换之前会检查 State Notes 中的 `human_ack: true`。

✅ 已验证：`spec/bootstrap/hooks/pre-transition:88-92`

---

## 4. 角色体系

### 4.1 角色技能（状态机阶段）

| 技能 | 角色令牌 | 隔离方式 | 主要制品 |
|------|---------|---------|---------|
| `baton-explorer` | `scoped-explorer` | `context: fork` | `exploration.md` |
| `baton-specifier` | `specifier` | 内联 | `requirements.md` |
| `baton-architect` | `architect` | 内联 | `architecture.md` |
| `baton-verifier` | `verification-explorer` | `context: fork` | `verification.md` |
| `baton-generator` | `generator` | 内联 | 代码变更 |
| `baton-evaluator` | `evaluator` | `context: fork` | `evaluation.md` |

三个角色（`explorer`、`verifier`、`evaluator`）声明了 `context: fork`，意味着它们**必须**在隔离上下文中运行（独立的 Agent 调用），以防止被先前推理污染。在 `strict` 模式下，无法隔离即为阻塞。

### 4.2 能力技能（非状态机）

| 技能 | 用途 |
|------|------|
| `baton-clarifier` | 状态机前的需求访谈 |
| `baton-orchestrator` | 驱动完整流程的一站式入口 |
| `baton-status` | 报告当前任务状态和下一步行动 |
| `baton-retrospective` | 完成后的过程经验总结 |
| `deep-research` | 系统性调研（本技能） |
| `first-principles-planner` | 第一性原理战略规划 |

### 4.3 编排器

`baton-orchestrator` 是最复杂的技能（约 700 行）。它：

1. **Phase 0**: 评估清晰度（模糊/部分/清晰）和风险（低/中/高）
2. **Phase 1-9**: 顺序驱动每个角色技能
3. **风险自适应矩阵**: 根据风险级别调整各阶段深度（例如，低风险跳过 Codex 评审；高风险要求架构中包含交付顺序）
4. **Codex 集成**: 在中/高风险时可选使用 `codex:rescue` 进行跨模型评审
5. **草稿恢复**: 恢复时检测草稿制品并重新运行被中断的阶段
6. **修复循环**: 将评估器 BLOCKED 裁决路由回生成器 + 重新评估

✅ 已验证：`skills/baton-orchestrator/SKILL.md`

---

## 5. 制品体系

所有任务状态以 Markdown/YAML 文件形式存放在 `.harness/` 中：

| 制品 | 写入者 | 用途 |
|------|--------|------|
| `exploration.md` | Explorer | 任务级代码理解 |
| `requirements.md` | Specifier | 实现合同 |
| `architecture.md` | Architect | 带权衡的变更设计 |
| `verification.md` | Verifier | 验证路径可执行的证明 |
| `evaluation.md` | Evaluator | 独立评审裁决 |
| `task-status.md` | 所有角色 | 控制平面（状态、所有者、备注） |
| `retrospective.md` | Retrospective | 过程经验 |
| `clarification-brief.md` | Clarifier | 状态机前需求访谈输出 |
| `escalation.md` | Generator | 设计级问题上报通道 |

### `task-status.md` 模式

```
| Scope | Owner | State | Eval Round | Updated At | Notes |
```

加上结构化的 `## State Notes` 区段，包含机器可读的键：
`risk_level`、`artifact_language`、`codex_available`、`human_ack`、`base_commit` 等。

加上 `## Transition Log` 表，由 `post-artifact` Hook 自动填充。

### 双语支持

模板同时存在英文版（`spec/templates/`）和中文版（`spec/templates/zh/`）。语言通过 `profile.local.yaml` → `documentation.artifact_language` 配置。`task-status.md` 始终保持英文，作为可移植控制平面。

✅ 已验证：模板目录和 `spec/README.md:196-206`

---

## 6. 运行时强制执行（Hook 系统）

Baton 最具特色的技术特性是其**基于 Hook 的运行时强制执行**。Hook 是拦截 Agent 工具调用并实时阻止协议违规的 Shell 脚本。

### Hook 架构

```
.claude/settings.json
  ├── PreToolUse (Write|Edit|MultiEdit) → hooks/pre-transition
  ├── PostToolUse (Write|Edit|MultiEdit) → hooks/post-artifact
  ├── Stop → hooks/stop-check
  ├── SubagentStop (baton-evaluator|baton-verifier) → hooks/subagent-stop
  └── SessionStart (startup|resume) → hooks/session-start
```

所有 Hook 共享 `hooks/lib/parse-input.sh`，它：
- 从 stdin 读取 JSON（Claude Code Hook 协议）
- 从输入形态检测宿主类型（`cc` 或 `codex`）
- 提供 `hook_pass()` / `hook_block()` 控制流
- 从 `profile.local.yaml` 读取配置值
- 在 `/tmp/baton-transition-*` 管理状态转换缓存

### Hook 行为

| Hook | 触发时机 | 强制执行内容 |
|------|---------|------------|
| `pre-transition` | 写入 `task-status.md` 之前 | 仅允许合法状态转换；人类门控需要 `human_ack`；草稿制品阻止阶段推进；阻塞状态需要分类说明 |
| `post-artifact` | 写入任何 `.harness/*.md` 之后 | 制品模式验证；状态转换日志记录；门控通过后自动清除 `human_ack` |
| `stop-check` | 会话结束时 | 当前状态需要的制品是否存在；隔离来源是否有效 |
| `subagent-stop` | Verifier/Evaluator Agent 完成时 | Verifier 必须已写入 `verification.md`；Evaluator 状态必须是 reviewing/blocked/ready；评估轮次计数器递增；最大轮次限制 |
| `session-start` | 会话启动/恢复时 | 注入 Harness 上下文 |

### 重入保护

`BATON_HOOK_ACTIVE=1` 防止 Hook 在 Hook 发起的写入过程中重复触发（例如，`post-artifact` 清除 `human_ack` 或记录转换日志时）。这是一个简单但关键的机制。

✅ 已验证：`parse-input.sh:4` 检查 `BATON_HOOK_ACTIVE`

### 跨宿主支持

Hook 同时工作于 Claude Code（通过 `.claude/settings.json`）和 Codex（通过 `.codex/hooks.json`）。`parse-input.sh` 从输入形态检测宿主类型 —— 有 `file_path` 表示 CC，有 `command` 表示 Codex。Windows 支持使用 `run-hook.cmd`，它定位 Git Bash 并委托执行。

✅ 已验证：`parse-input.sh:40-48`、`run-hook.cmd`

---

## 7. 引导 / 分发体系

### 安装流程

```
install-harness.sh ─── 将 baton 负载打包到目标仓库
  └── .vendor/baton-harness/     （完整 spec/ 拷贝）
  └── .harness/harness.lock.yaml （版本真相）
  └── .harness/overrides/        （本地自定义插槽）
  └── .claude/skills/            （已实体化的运行时技能）
  └── .agents/                   （已实体化的 Agent 定义）
  └── install-hooks.sh           （在 settings.json 中注册 Hook）

init-harness.sh ────── 引导 .harness/ 目录
  └── 拷贝模板
  └── 初始化 profile.local.yaml
  └── 从治理模板实体化 CLAUDE.md + AGENTS.md
  └── 可选注册首个任务

start-task.sh ──────── 在 task-status.md 中注册任务行

update-harness.sh ──── 从较新的 baton 检出更新打包负载
```

### 技能分发

在 baton 仓库本身中，技能位于 `skills/`，通过 `link-skills.sh` **符号链接**到 `.claude/skills/` 和 `.agents/`。对于外部仓库，技能在 `install-harness.sh` 执行期间被**拷贝**。`.link-mode` 文件跟踪当前使用的模式。

### 治理入口点

`CLAUDE.md` 和 `AGENTS.md` 是从 `spec/templates/root-governance.template.md` 通过 `sync-governance-entrypoints.sh` **生成**的。这确保 Claude Code、Codex 和 Cursor 看到相同的仓库级治理规则。

✅ 已验证：`install-harness.sh`、`link-skills.sh`、`.agents/` 目录（全部为符号链接）

---

## 8. 验证基础设施

### 引导验证器

| 脚本 | 用途 |
|------|------|
| `validate-transition.sh` | 检查状态 A → B 是否被允许 |
| `validate-artifact.sh` | 验证制品模式（必需区段） |
| `validate-isolation.sh` | 检查 Verifier/Evaluator 制品中的隔离来源 |
| `validate-state-artifacts.sh` | 确保当前状态所需的制品存在 |
| `check-consistency.sh` | 全面一致性检查（约 656 行）—— 交叉验证 owners.txt、states.txt、技能定义、模板、Hook 和运行配置 |

`check-consistency.sh` 是最庞大的脚本，运行 20+ 项不变量检查，包括：
- 技能中的所有者令牌匹配 `owners.txt`
- `states.txt` 中的状态匹配 `state-machine.md`
- 技能前置元数据声明正确的 `context: fork`
- 模板必需区段匹配 `artifact-schema.md`
- settings.json 中的 Hook 命令正确
- 来源信息块字段一致

✅ 已验证：`check-consistency.sh:1-80`

### 测试套件

`tests/` 中有 15 个测试脚本：

```
test-harness-context.sh      test-hook-session-start.sh
test-hook-parse-input.sh     test-hook-stop-check.sh
test-hook-post-artifact.sh   test-hook-subagent-stop.sh
test-hook-pre-transition.sh  test-install-hooks.sh
test-hook-run-hook.sh        test-prepare-review.sh
test-skill-links.sh          test-start-task.sh
test-task-status.sh          test-validate-artifact.sh
test-validate-isolation.sh   test-validate-state-artifacts.sh
test-validate-transition.sh
```

测试通过创建临时目录、模拟 Harness 状态并验证 Hook/验证器行为来工作。纯 Shell 实现 —— 无测试框架依赖。

---

## 9. 多宿主适配器体系

Baton 设计为可在三种 AI 编码环境中工作：

| 宿主 | 入口点 | 子 Agent 隔离 | Hook |
|------|--------|-------------|------|
| Claude Code | `CLAUDE.md` | `Agent` 工具 | `.claude/settings.json` |
| Codex | `AGENTS.md` | `spawn_agent(fork_context: false)` | `.codex/hooks.json` |
| Cursor | `AGENTS.md` | 手动会话分离 | 有限（依赖用户自律） |

### 隔离策略

两种模式：

- **`strict`（严格）**: Verifier 和 Evaluator 必须有真正的上下文隔离。顺序回退 = 阻塞。
- **`compat`（兼容）**: 允许顺序回退，但必须在制品来源信息中显式记录（隔离模式、执行上下文、回退原因）。

适配器合同（`cli-adapter-interface.md`）定义了适配器**可以**和**不可以**改变什么。适配器可以自定义提示和调用方式，但不能改变规范状态、必需门控或隔离语义。

✅ 已验证：`cli-adapter-interface.md`、`claude-code.md`、`codex.md`、`cursor.md`

---

## 10. 扩展体系

### Java 后端严格扩展

位于 `spec/extensions/java-backend-strict/`，这是目前唯一的扩展。它增加了：

- 按模块的生成循环
- 具有三层验证的运行时评估器
- 额外制品：`codebase-map.md`、`decisions.md`、`api-contract.yaml`
- 显式的迁移和上报检查点

原始设计（`spec/11.md`）是用中文编写的完整 Java 多 Agent Harness —— 该扩展将其更严格的工作流提取为可移植核心之上的叠加层。

### 配置文件

定义了三种仓库类型配置：

| 配置 | 目标 | 关键信号 |
|------|------|---------|
| `java-maven.yaml` | Java/Maven 项目 | `pom.xml`、`src/main/java` |
| `node-monorepo.yaml` | Node 单仓库 | `package.json`、`pnpm-workspace.yaml` |
| `python-service.yaml` | Python 服务 | `pyproject.toml`、`pytest.ini` |

配置文件定义了验证风格、工作空间策略、高风险表面、首选测试层和示例命令。它们为技能提供关于仓库特定约定的信息。

---

## 11. 已完成任务历史

`.harness/task-status.md` 显示 19 个已完成任务 —— 全部为 baton 内部开发工作：

1. `add-version-flag` — 版本标志功能
2. `protocol-consistency-fix` — 协议对齐修复
3. `harness-workflow-improvements` — 工作流加固
4. `harness-language-support` — 双语制品支持
5. `harness-distribution-installer` — 安装/更新/锁文件体系
6. `root-readme-bilingual` — 双语 README
7. `root-readme-standardization` — 双语检查
8. `governance-multi-host-entrypoints` — AGENTS.md + 共享模板
9. `runtime-thickness-improvements` — 跨平台隔离
10. `isolation-enforcement-hardening` — strict/compat 隔离语义
11. `provenance-standardization-hardening` — 共享来源信息合同
12. `positioning-protocol-vs-runtime` — 定位文档
13. `workflow-best-practice-doc` — 工作流文档
14. `runtime-enforcement-hardening` — Hook 系统加固（经历了 1 轮评估！）
15. `bootstrap-structure-rationalization` — 结构清理

该项目自我使用（吃自己的狗粮）—— baton 自身的开发通过 baton harness 来跟踪。

---

## 12. 架构图

```
                         ┌─────────────────┐
                         │    用户请求       │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │    编排器        │ ← baton-orchestrator
                         │  (Phase 0-9)    │
                         └────────┬────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
    ┌─────▼─────┐          ┌─────▼─────┐          ┌─────▼─────┐
    │  Phase 1   │          │  Phase 2   │          │ Phase 3-4  │
    │  澄清器    │          │  探索器     │          │ 规格器/    │
    │ (内联)     │          │ (隔离)      │          │ 架构师     │
    └────────────┘          └────────────┘          │ (内联)     │
                                                    └─────┬─────┘
                                                          │
                                                    ┌─────▼─────┐
                                                    │   人类      │
                                                    │  门控 G2    │
                                                    └─────┬─────┘
                                                          │
    ┌─────────────┐          ┌─────────────┐        ┌─────▼─────┐
    │  Phase 7    │          │  Phase 6    │        │  Phase 5   │
    │  评估器     │◄─────── │   生成器     │◄───────│  验证器    │
    │ (隔离)      │          │  (内联)     │        │ (隔离)     │
    └──────┬──────┘          └─────────────┘        └────────────┘
           │                        ▲
           │ BLOCKED ───────────────┘  （修复循环）
           │
    ┌──────▼──────┐
    │    人类      │
    │   门控 G5    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │    完成      │
    └─────────────┘

    ─── 运行时强制执行层 ───

    ┌─────────────────────────────────────────────┐
    │  Hook (pre-transition, post-artifact,       │
    │        stop-check, subagent-stop,            │
    │        session-start)                        │
    │  验证器 (transition, artifact, isolation,    │
    │         state-artifacts, consistency)        │
    └─────────────────────────────────────────────┘
```

---

## 13. 关键设计张力与权衡

### 13.1 协议可移植性 vs 运行时深度

Baton 明确选择了**协议优先**定位。Shell 脚本是"参考运行时" —— 真正的价值在于协议规范（状态机、门控、制品）。这意味着：

- **优势**: 任何 AI Agent CLI 都可以通过实现适配器接口来采用 baton
- **劣势**: 运行时强制执行仅限于 Shell Hook 能拦截的范围；更深层的强制执行（例如，防止 Agent 推理先前上下文）需要宿主支持

### 13.2 基于文件的控制平面

一切都存在于 Markdown 文件中，而非数据库或 API：

- **优势**: 零基础设施依赖；可在任何 git 仓库中工作；人类可读；版本控制
- **劣势**: 在 Shell 中解析 Markdown 表格较为脆弱（参见 TODOS.md 中提到的如果解析变复杂可迁移到 sidecar YAML）

### 13.3 通过宿主机制实现隔离

上下文隔离（对 Verifier/Evaluator 的独立性至关重要）完全依赖于宿主的子 Agent 能力：

- **Claude Code**: `Agent` 工具提供真正的隔离
- **Codex**: `spawn_agent(fork_context: false)` 提供隔离
- **Cursor**: 仅靠手动自律 —— 已知弱点

### 13.4 吃自己狗粮的张力

该项目使用自身进行开发，这产生了先有鸡还是先有蛋的问题 —— Hook 变更可能会阻止这些变更本身的实现（在用户的反馈记忆中有记录）。

---

## 14. 来源审计

| 声明 | 来源 | 获取方式 |
|------|------|---------|
| 版本 1.0.0 | `spec/VERSION` | 本次会话中读取 |
| 225 次提交 | `git log --oneline --all \| wc -l` | 本次会话中运行 |
| 首次提交 2026-02-27 | `git log --reverse --format='%ai' \| head -1` | 本次会话中运行 |
| 10 个规范状态 | `spec/protocol/state-machine.md:3-13` | 本次会话中读取 |
| 定义了 5 个门控 | `spec/protocol/gates.md` | 本次会话中读取 |
| 3 个隔离角色（explorer、verifier、evaluator） | 技能 YAML 前置元数据 `context: fork` | 本次会话中读取 |
| 19 个已完成任务 | `.harness/task-status.md` | 本次会话中读取 |
| 引导脚本约 4,352 行 Shell | `wc -l` 输出 | 本次会话中运行 |
| 15 个测试脚本 | `tests/` 目录列表 | 本次会话中读取 |
| Hook 重入保护通过 BATON_HOOK_ACTIVE | `parse-input.sh:4` | 本次会话中读取 |
| pre-transition 中的 human_ack 强制执行 | `pre-transition:88-92` | 本次会话中读取 |
| 基于 Anthropic harness 设计 | `README.md:12` | 本次会话中读取 |

---

## 15. 待解决问题

1. **生产采用量**: 有多少外部仓库通过 `install-harness.sh` 采用了 baton？任务历史全部是自开发。没有外部采用指标的证据。❓ 未知 —— 未见遥测或采用跟踪机制。

2. **Windows 运行时覆盖**: TODOS 和残余风险中提到 `run-hook.cmd` 没有进行过实际 Windows 烟雾测试。`.cmd` 桥接文件存在，但仅在命令生成层面经过测试。❓ 未验证的 Windows 运行时行为。

3. **配置文件强制执行**: TODOS.md 将"基于配置文件的风险行为强制执行"标记为 DEFERRED（推迟）。配置文件目前通过文档提示告知技能，但没有 Hook 在运行时验证技能的行为是否匹配配置文件的期望。

---

## 16. 最薄弱的结论

Baton 的 Hook 系统提供"运行时强制执行"这一说法是准确的，但应在狭义上理解：Hook 可以阻止违反协议的文件写入（无效转换、格式错误的制品、缺失的人类确认），但无法强制执行行为约束，例如"评估器不得看到生成器的推理过程"。这种更深层的隔离保证完全依赖于宿主能力，在 `compat` 模式下则依赖于制品来源信息块中的自我报告诚实性。

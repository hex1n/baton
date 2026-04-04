# Baton Runtime Thickness: Evidence-Based Analysis

**Question**: Is Baton's runtime genuinely thin relative to its protocol? What are the specific enforcement gaps, and what does the codebase actually provide?
**Depth**: Deep
**Key finding**: The argument's core thesis is correct — protocol documentation substantially outpaces runtime enforcement — but several specific sub-claims are overstated or inaccurate. The distribution layer is stronger than portrayed, a strict enforcement extension already exists in-spec, and an improvement plan already names several of the gaps.

---

## Overview

```
spec/protocol/         ← normative core (state machine, role contracts, artifact schema, gates)
spec/adapters/         ← CLI capability mapping (claude-code, codex, cursor)
spec/extensions/       ← opt-in strict mode (java-backend-strict)
spec/bootstrap/        ← setup + consistency scripts
skills/                ← agent role skills (canonical single source)
.claude/skills/        ← symlinks → skills/ in dev; copies via vendor in target repos
.agents/               ← same
.harness/              ← runtime control plane (artifacts + task-status.md)
```

**Key asymmetry**: `spec/protocol/` tells agents what to do. `spec/bootstrap/` gets the scaffold in place. Nothing between them continuously enforces that agents actually did it.

---

## Findings

### 1. Quick Start is purely bootstrap ✅ verified

`README.md:68-90` — Quick Start is: `install-harness.sh` → `init-harness.sh` → `start-task.sh` → "Run Scoped Explorer." There is no `run-harness.sh`, `advance-state.sh`, or continuous orchestrator.

`init-harness.sh` writes artifact templates to `.harness/` and materializes governance entrypoints (`CLAUDE.md`, `AGENTS.md`). `start-task.sh` adds a row to `task-status.md` and resets artifact templates for a new task. These are one-shot setup operations, not an ongoing runtime.

### 2. 状态转移是 agent 自报告机制 — 且是明确的设计选择 ✅ verified

`spec/protocol/role-contracts.md:154-156`:

> "start-task initializes a task row. After that point, **the current owner agent updates task-status.md as part of normal task execution**. A helper script may exist in a local repo, but the protocol does not require one for ordinary state transitions."

脚本层唯一的硬约束：`start-task.sh:296-304` 在非 complete 行存在时拒绝启动新任务。Gates 1–5（`spec/protocol/gates.md`）定义了通过/失败标准，由 agent 自行评估——没有任何脚本校验。

### 3. Artifact 内容校验缺失 ✅ verified

`check-consistency.sh` 包含 6 个不变式，没有一个校验 `.harness/*.md` 制品的节结构完整性：

| # | 校验内容 |
|---|---------|
| 1 | skills/ 中的 owner token 与 owners.txt 一致 |
| 2 | states.txt 与 state-machine.md 一致；bootstrap 脚本读取它 |
| 3 | start-task.sh 输出表头与模板表头一致 |
| 4 | skills/ 与 .claude/skills/ 和 .agents/ 副本一致 |
| 5 | README 中英文双语对一致 |
| 6 | 治理入口文件跨宿主同步 |

**零制品内容校验**。`spec/protocol/artifact-schema.md` 定义了每个制品的必需节，但不存在 `validate-harness.sh` 来检查用户填写的 `exploration.md` 是否包含所有必需节。

最精确的表述：**`check-consistency.sh` 校验 spec 内部一致性；它不校验用户制品质量。** 这是两个不同的问题。

### 4. 文件系统级强制执行缺失 ✅ verified

`.baton/git-hooks/` 存在但**为空**——无任何文件（`find .baton/git-hooks -type f` 无输出）。git-hooks 的思路显然曾经存在，但未被填充。

没有 `validate-transitions.sh`，没有写入面保护脚本。

### 5. 分发层比论述中描绘的更强 ❌ 被高估

论述认为 skill 文件"仍是手工复制维护"。对于 baton 本仓这一说法不准确：

- **baton 仓内**，`.agents/` 条目是指向 `skills/` 的**符号链接**（`ls -la .agents/` 确认：`lrwxr-xr-x harness-architect.md -> .../skills/harness-architect.md`）。开发模式下 `.agents/` 与 `skills/` 之间的漂移在结构上不可能发生。
- `check-consistency.sh` 不变式 4 明确强制 `.claude/skills/` 和 `.agents/` 与 `skills/` 一致——这是一个真实的漂移门控。
- `install-harness.sh` 生成带 lockfile（`harness.lock.yaml`，含版本号和 commit）的 vendor 布局。`update-harness.sh` 读取 lockfile。这是一个完整的 vendor 更新机制，不是手工复制。

真正残留的分发风险：skill 文本更新但其引用的 `spec/protocol/` 内容未同步更新（术语漂移）。该 gap 存在，但比论述中描述的更窄。

### 6. 强制执行扩展已在 spec 中存在 ❌ 论述未提及

`spec/extensions/java-backend-strict/` 提供了：
- `runtime-evaluator.md`：三层评估（确定性检查 → 运行时信号 → 需求驱动判断），源独立性规则（主评估阶段不读 generator 源码），有界 3 轮修复循环，`evaluation-report.md` + `runtime-signals/` 输出契约
- `state-overlay.md`：更严格的逐模块生成 + 评估循环
- `artifact-overlay.md`：额外必需制品（codebase-map、decisions.md、api-contract.yaml）

这是纯文档（无实现脚本），但设计决策已明确：**核心保持可移植轻量；强执行通过扩展可选叠加**。扩展路径已存在，尚缺实现脚本。

### 7. 改进计划已命名了其中多个 gap ❌ 论述未提及

`docs/harness-improvement-plan.md` 列出了 10 项具体改进：
- **P0-1**：Evaluator 上下文隔离（`context: fork`）
- **P0-2**：Architect 拒绝路径（当前是悬空状态分支）
- **P1-1**：新建 `harness-status` skill，无需手动读文件即可查看任务状态
- **P1-2**：`task-status.md` 增加 `eval_round` 字段，持久化修复轮次计数
- **P1-4**：`generator-feedback.md` 作为正式的向上游升级通道

"优先补 runtime 厚度"的方向已在本计划中推进，但尚未实现。

---

## 架构张力

| 张力 | 证据 |
|------|------|
| 协议假设多 Agent 上下文隔离；技能在单 session 运行 | `docs/harness-improvement-plan.md:15-17`：这已被诊断为根因——"设计假设（多 Agent 隔离）与执行环境（单 session 共享上下文）之间的结构性错位" |
| cli-adapter-interface.md 要求 Verifier + Evaluator 上下文隔离 | `spec/adapters/cli-adapter-interface.md:67-82`：`context: fork` / `spawn_agent` 是机制；Claude Code 有 `context: fork`；Cursor 无程序化机制 |
| 强模式扩展已被规格化，无脚本实现 | `spec/extensions/java-backend-strict/` 完整定义但纯文档 |

---

## 论述最准确的部分

**"现在 Baton 的 protocol 已经快超过 runtime 了"** — 比例关系是真实存在的：

- **协议层**：5 个文件 × 大量内容（state-machine、role-contracts、artifact-schema、gates、adapter-interface）= 完整规范
- **Bootstrap 层**：5+ 脚本（init、start、install、update、check-consistency）= 安装 + 预检
- **运行时层**：0 个脚本用于持续状态机操作；0 个脚本用于制品内容校验；0 个脚本用于"阻止并发任务"之外的转移强制执行

Baton 在任务执行期间"强制执行"协议的机制是：agent 读取协议和技能，然后自愿遵守。这不是什么都没有——清晰的指令 + 明确的门控确实会改变 agent 行为——但其威胁模型不同于文件系统级硬约束。

---

## 论述低估的部分

1. **产品设计选择是有意为之且有记录的**。`spec/extensions/java-backend-strict/README.md:14`："Use this extension on top of the core protocol, **not instead of it.**" 保持核心可移植、通过扩展添加强制执行的决策是显式的，不是偶然的。

2. **分发一致性机制是真实的**。符号链接 + `check-consistency.sh` 不变式 4 + lockfile 在正常使用中提供了结构性保证。

3. **`start-task.sh` 阻止并发任务这一硬约束是非平凡的**。它强制执行单活跃任务原则，无需 agent 读取任何文件。

---

## 最精确的 Gap 表述

**存在且明确的 gap：**
- 无 `validate-artifact.sh` 校验用户填写的 `.harness/*.md` 是否包含必需节
- 无 `validate-transition.sh` 校验尝试的状态转移是否合法
- `.baton/git-hooks/` 为空——无 git 层强制执行
- java-backend-strict 扩展仅存在于 spec；无脚本实现其更严格的评估循环

**已在改进计划中但尚未实现的 gap：**
- `harness-status` skill（P1-1）
- `eval_round` 持久化追踪（P1-2）
- Evaluator `context: fork` 隔离（P0-1）
- Architect 拒绝路径（P0-2）

**不是 gap：**
- 分发漂移防护（符号链接 + 不变式 4 + lockfile 已解决）
- 单一真源缺失（`skills/` 是规范源，由 check-consistency 强制执行）

---

## 产品定位评估

论述提出的定义——"一个 protocol-first 的 AI coding harness，提供可移植核心协议、宿主适配、文件化控制平面，以及可选的严格执行扩展"——与代码库实际情况吻合：

| 特性 | 证据 |
|------|------|
| protocol-first | `spec/protocol/` 是规范；适配器和扩展引用它，从不改变它 |
| adapter-aware | `spec/adapters/` 含 claude-code、codex、cursor + cli-adapter-interface.md |
| file-based control plane | `.harness/` 制品 + `task-status.md` 作为唯一状态真源 |
| optional strict enforcement | `spec/extensions/java-backend-strict/` 明确标注为可选叠加 |

README 已称其为"portable AI coding agent collaboration protocol"并把 `.claude/skills/` 称为"reference implementation"。定位基本准确；缺失的是把第四个特性（强制执行扩展路径）作为 README 一级条目显式呈现。

---

## 最薄弱的结论

未验证 `harness-verifier.md` frontmatter 中的 `context: fork`（已确认在 `:2`）在当前 Claude Code 版本中是否实际触发新上下文，还是被静默忽略。如果被忽略，verifier skill 中的上下文隔离声明是纯协议层的，在技术上没有强制执行。`docs/harness-improvement-plan.md:352-357` 已将此明确标注为最高风险假设。

---

## Source Audit

| 声明 | 来源 | 获取方式 |
|------|------|---------|
| Quick Start 是纯 bootstrap | `README.md:68-90` | 本次 session 读取 |
| 状态转移由 agent 自报告（设计选择） | `spec/protocol/role-contracts.md:154-156` | 本次 session 读取 |
| check-consistency.sh 6 个不变式，无制品内容校验 | `spec/bootstrap/check-consistency.sh` | 本次 session 读取 |
| .baton/git-hooks/ 为空 | `find .baton/git-hooks -type f` 无输出 | 本次 session 运行 |
| .agents/ 条目为符号链接 | `ls -la .agents/` 输出 | 本次 session 运行 |
| check-consistency 不变式 4 强制技能一致性 | `spec/bootstrap/check-consistency.sh:104-131` | 本次 session 读取 |
| java-backend-strict 扩展存在 | `spec/extensions/java-backend-strict/` | 本次 session 读取 |
| 改进计划已命名 gap | `docs/harness-improvement-plan.md` | 本次 session 读取 |
| start-task.sh 阻止并发任务 | `spec/bootstrap/start-task.sh:296-304` | 本次 session 读取 |
| harness.lock.yaml 是版本真源 | `spec/bootstrap/install-harness.sh:279-300` | 本次 session 读取 |

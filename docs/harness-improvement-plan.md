# Baton Harness 改进计划

**根因**：harness 按多 Agent 上下文隔离设计，但实现为单 session 顺序执行。
大多数 gap 都从这个错位派生。

---

## 根因溯源

```
表象：  多个 gap（无编排入口、Evaluator 独立性弱、无反馈通道…）
Why 1 → skill 层与 spec 层存在多处偏差
Why 2 → spec 定义了多 Agent、上下文隔离的协议；
         skill 写成了单 session 顺序调用工具
Why 3 → 没有层次明确说明"单 session 下，隔离应如何实现"
根因：  设计假设（多 Agent 隔离）与执行环境（单 session 共享上下文）
         之间的结构性错位从未被显式解决
```

---

## 上下文隔离机制（跨平台）

三个平台的隔离语义一致，机制不同：

| 平台 | 隔离机制 | 关键约束 |
|------|---------|---------|
| Claude Code | skill frontmatter: `context: fork` | 新上下文，不继承当前 session |
| Codex | `spawn_agent({ fork_context: false })` | **不传** `fork_context: true`，只传显式制品 |
| Cursor | 手动开新 chat/agent context | 无程序化手段，文档标注为已知限制 |

Codex 的 `fork_context: true` 是反模式——会把 Generator 的整个推理链复制给 Evaluator，破坏独立性。

---

## 改进计划

### P0 — 核心循环的结构性缺口

---

#### P0-1：Evaluator 上下文隔离（根因直接修复）

**问题**：Evaluator 在同一 session 里运行，继承 Generator 的推理链，独立性是口头承诺而非结构保证。

**变更 1**：`.claude/skills/harness-evaluator.md` frontmatter 加 `context: fork`

```yaml
---
name: harness-evaluator
context: fork
allowed-tools: Read, Bash, Glob, Grep
description: >
  独立评估实现是否满足需求...
---
```

skill 开头加强制冷读步骤：

```markdown
## 启动（context: fork 下必须显式加载制品）

1. 读取 .harness/requirements.md
2. 读取 .harness/architecture.md
3. 读取 .harness/verification-path.md
4. 读取 git diff（实现变更）

不得读取 Generator 的执行笔记或继承对话历史。
```

**变更 2**：`spec/adapters/codex.md` Evaluator 一节改为必须 spawn：

```markdown
### Evaluator

- Spawn as an isolated sub-agent: `spawn_agent({ fork_context: false })`
- Explicitly pass only:
  - .harness/requirements.md
  - .harness/architecture.md
  - .harness/verification-path.md
  - implementation diff
- Do NOT use fork_context: true — this passes Generator's reasoning chain
  and defeats context independence
```

**变更 3**：`spec/adapters/cli-adapter-interface.md` 在 Required Capabilities 新增隔离要求：

```markdown
## Context Isolation Requirement

The following roles MUST derive judgment from artifacts only,
without inheriting prior role reasoning:

- Scoped Explorer (task mode)
- Evaluator

Adapters MUST document how they implement this isolation.
Acceptable mechanisms:
- New context initialized from artifacts only (preferred)
- Isolated sub-agent with explicit artifact inputs, no context fork
- Explicit session reset followed by artifact reload

Sequential execution WITHOUT isolation is not sufficient for Evaluator.
```

---

#### P0-2：Architect 拒绝路径补全

**问题**：`harness-architect.md` 在"Present and Wait"后没有描述人工拒绝时的处理路径，是一个悬空的状态分支。

**变更**：`harness-architect.md` 增加反馈处理节：

```markdown
## 人工反馈处理

**审批通过**
更新 module-status.md → state: verification_check，owner: verifier。

**部分修改**
根据反馈修订 architecture.md，重新展示修改点，再次等待审批。
不得在未获审批的情况下进入下一阶段。

**根本拒绝（架构方向错误）**
返回 Step 2 重新分解问题，修订后再次提交审批。

**根本拒绝（需求理解有误）**
更新 module-status.md → state: blocked，category: design_blocker。
说明：需求层存在歧义，需 Specifier 重新接手并澄清后返回。
```

---

#### P0-3：Explorer 上下文隔离

**问题**：Scoped Explorer 在 repo-wide 模式下可能携带大量无关上下文影响探索判断。

**变更**：`.claude/skills/harness-explorer.md` frontmatter 加 `context: fork`，仅在 Repo-wide 模式触发时适用。在 skill 说明中标注原因。

---

### P1 — 协议闭环缺失

---

#### P1-1：新增 `harness-status` skill

**问题**：用户无法在不手动读文件的情况下知道当前任务处于哪个状态、下一步应该做什么。

**新建** `.claude/skills/harness-status.md`：

```markdown
---
name: harness-status
description: >
  读取 .harness/module-status.md，报告当前任务状态、所有者、
  下一步行动建议，以及修复轮次。任何时刻都可调用。
user-invocable: true
---

## 执行步骤

1. 读取 .harness/module-status.md
2. 输出：
   - 当前任务 ID、state、owner
   - 当前状态对应的下一步（按 state-machine.md 转换规则）
   - 如果是 blocked：阻塞类别 + 可选出口
   - 如果有 eval_round：显示当前修复轮次 / 剩余轮次
3. 如果 .harness/ 不存在，提示先运行 init-harness
```

---

#### P1-2：修复轮次追踪

**问题**："3 次 BLOCKED 后升级给人工"的上限无处持久化，依赖模型上下文记忆，会退化。

**变更**：`spec/templates/module-status.template.md` 增加 `eval_round` 字段：

```markdown
| Task ID | Owner | State | Eval Round | Notes | Blockers |
|---------|-------|-------|------------|-------|----------|
| —       | —     | —     | —          | —     | —        |
```

`eval_round` 规则：
- `generating` / `reviewing` 之外的状态填 `—`
- 进入修复循环后填 `1`、`2`、`3`
- 第 3 轮结果仍为 BLOCKED → 强制更新 state: blocked，owner: human，附说明

---

#### P1-3：新增 `harness-retrospective` skill

**问题**：`retrospective.md` 是 spec 定义的必需制品，但没有对应 skill，实际任务中几乎不会被填写。

**新建** `.claude/skills/harness-retrospective.md`：

```markdown
---
name: harness-retrospective
description: >
  任务结束后填写回顾文档。触发：用户说"写回顾"、"任务完成"、
  "close task"。读取本次任务的全部制品，产出 retrospective.md。
user-invocable: true
---

## 回顾维度

1. **什么有效** — 哪些 gate / artifact / 流程节点确实防住了问题
2. **什么失效** — 哪些步骤被跳过、造成了返工、或产出了低质制品
3. **应该标准化的东西** — 值得写入 profile.local.yaml 或 adapter 文档的经验
4. **仓库特有教训** — 只对这个仓库有效的发现
5. **下一版本建议** — 对 spec 或 skill 的改进建议

## 输出

写入 .harness/retrospective.md，更新 module-status.md → state: complete。
```

---

#### P1-4：核心 v1 增加 Generator → 上游反馈通道

**问题**：Generator 发现需求或架构级别的问题时，没有合法的升级通道，只能 blocked 并靠文字说明，结构不清晰。

**变更 1**：`spec/protocol/artifact-schema.md` Optional Artifacts 里提升 `generator-feedback.md` 为 conditionally required：

```markdown
### `generator-feedback.md` (conditionally required)

- Required when: Generator discovers a requirement gap or architectural
  mismatch that cannot be resolved within the approved write surface
- Writer: Generator
- Readers: Architect, Specifier, Human
- Purpose: escalation channel for design-level issues found during implementation
- Required sections:
  - original assumption (from architecture.md)
  - actual finding (what the code shows)
  - impact on implementation
  - recommended next owner: architect | specifier | human
```

**变更 2**：`harness-generator.md` Architecture Mismatch 节增加：

```markdown
**向上游反馈**：结构性不匹配时，除进入 blocked 状态外，
同时写入 .harness/generator-feedback.md，内容包括：
- 原始架构假设（引用 architecture.md 的具体内容）
- 实际代码情况
- 影响范围
- 建议下一步：需要 Architect 重新处理 / 需要 Specifier 澄清需求 / 需要 Human 决策
```

---

#### P1-5：Spec 记录 Reviewer/Evaluator 合并决策

**问题**：`spec/protocol/role-contracts.md` 定义了独立的 Reviewer 和 Evaluator；`harness-evaluator.md` 静默合并了两者，spec 没有记录这个决策。

**变更**：`spec/protocol/role-contracts.md` Evaluator 节末尾增加：

```markdown
## Implementation Note: Reviewer + Evaluator Merge

In single-agent CLI environments (Claude Code, Codex sequential fallback),
Reviewer and Evaluator MAY be merged into a single role.

Conditions for valid merge:
- The merged role must maintain context independence (see cli-adapter-interface.md)
- Findings must still be explicit before go/no-go conclusion
- The merge must be documented in the adapter's role execution section

When sub-agents are available, keeping them separate is preferred —
Reviewer can run in parallel with final Generator cleanup.
```

---

### P2 — 操作摩擦

---

#### P2-1：Blocked 出口决策指引

**问题**：任务 blocked 后，谁决定走哪个出口（verification_check / architecting / generating）没有说明。

**变更**：在各 skill 的 blocked 转换处增加决策规则：

| blocked 原因 | 出口 | 接手角色 |
|-------------|------|---------|
| 验证命令无法执行 | verification_check | verifier |
| 架构假设被实际代码推翻 | architecting | architect |
| 需求存在歧义或遗漏 | architecting（含 specifier 协作） | architect + human |
| 环境/依赖问题 | generating（环境修复后） | generator |
| 3 轮修复未收敛 | human 决策 | human |

---

#### P2-2：Cursor adapter 标注已知限制

**问题**：Cursor 没有程序化的 spawn 机制，Evaluator 隔离依赖用户手动操作，应如实标注。

**变更**：`spec/adapters/cursor.md` Evaluator 节增加：

```markdown
### Evaluator

- Open a new chat or agent context before starting evaluation
- Load only: .harness/requirements.md, architecture.md,
  verification-path.md, and the diff
- Known limitation: Cursor has no programmatic spawn — isolation
  depends on user discipline. If context isolation cannot be
  guaranteed, note this in module-status.md and have human
  perform a separate manual review pass before close.
```

---

## 不做什么

- **不把 harness 改成全自动 pipeline**：human-in-loop 是设计选择，符合"不可逆操作需要人工"原则。
- **不引入 superpowers 依赖**：会破坏 harness 对 Codex/Cursor 的可移植性。
- **不拆分 Reviewer/Evaluator**：`context: fork` / `spawn_agent` 解决隔离问题后，合并仍是合理简化；条件见 P1-5。
- **不现在做 profile skill**：bootstrap 脚本已处理 `--profile auto`，优先级低于核心循环完整性。

---

## 变更文件汇总

| 文件 | 变更类型 | 对应改进项 |
|------|---------|-----------|
| `.claude/skills/harness-evaluator.md` | 修改 | P0-1 |
| `.claude/skills/harness-explorer.md` | 修改 | P0-3 |
| `.claude/skills/harness-architect.md` | 修改 | P0-2 |
| `.claude/skills/harness-generator.md` | 修改 | P1-4 |
| `.claude/skills/harness-status.md` | **新建** | P1-1 |
| `.claude/skills/harness-retrospective.md` | **新建** | P1-3 |
| `spec/adapters/cli-adapter-interface.md` | 修改 | P0-1 |
| `spec/adapters/codex.md` | 修改 | P0-1 |
| `spec/adapters/cursor.md` | 修改 | P2-2 |
| `spec/protocol/artifact-schema.md` | 修改 | P1-4 |
| `spec/protocol/role-contracts.md` | 修改 | P1-5 |
| `spec/templates/module-status.template.md` | 修改 | P1-2 |

**共 12 个文件，10 项改进，2 个新建 skill。**

---

## Self-Check

**最可能的失败模式**：`context: fork` 下的 Evaluator 无法可靠读取 `.harness/` 制品（路径解析或工作目录问题）。

**验证方式**：先在一个真实任务上试跑 P0-1，确认 Evaluator 能冷启动读到制品，再推进其余改动。

**如果 `context: fork` 不可靠**：在 Evaluator skill 开头加极强的"禁止携带先验假设"约束，在 spec 里明确标注这是已知的结构性弱点，等 Claude Code 子 Agent 能力成熟后补强。

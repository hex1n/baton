# Baton vs 已安装 CE 当前能力差距分析

## Snapshot

- **分析日期**：2026-03-30
- **比较对象**：
  - `baton` 当前仓库
  - 本机已安装的 CE workflow 栈
- **只比较当前本地已实现能力**：
  - 不比较未安装的上游 CE 源码能力
  - 不比较 Baton 或 CE 的未来潜力
  - 不引入外部最佳实践作为裁判标准

## 结论先行

当前态下，两者不是同一层次的产品，但都已经很成形：

- **用户可感知能力层**：已安装 CE 明显更厚。它已经把 `brainstorm → plan → work → review` 做成了直接可调用的 workflow 产品面，并围绕它补了 research、review personas、todo、worktree、Proof 等支撑层。
- **底层机制层**：Baton 明显更硬。它已经把状态机、artifacts、gates、verification-before-generation、独立 verifier/evaluator、hooks enforcement、human close 这些东西写成了明确协议和 reference runtime。
- **真正的差距**不是 Baton “没有能力”，而是 Baton 目前的能力更多停在 `protocol + role + runtime enforcement`，而不是 CE 那样的 `top-level workflow product + companion ecosystem`。

一句话说：

**Baton 现在是“下层更强、上层更薄”；已安装 CE 现在是“上层更厚、下层更松”。**

这意味着 Baton 当前最该补的不是协议正确性，而是**建立在现有 protocol/reference runtime 之上的 workflow product shell**。

## 比较范围

### Baton 观察面

- `README.md`
- `docs/baton-positioning.md`
- `docs/baton-workflow-best-practice.md`
- `skills/baton-explorer/SKILL.md`
- `skills/baton-specifier/SKILL.md`
- `skills/baton-architect/SKILL.md`
- `skills/baton-verifier/SKILL.md`
- `skills/baton-generator/SKILL.md`
- `skills/baton-evaluator/SKILL.md`
- `spec/protocol/state-machine.md`
- `spec/protocol/gates.md`
- `spec/protocol/role-contracts.md`
- `spec/bootstrap/`

### 已安装 CE 观察面

- `/Users/hex1n/.agents/skills/ce-brainstorm/SKILL.md`
- `/Users/hex1n/.agents/skills/ce-plan/SKILL.md`
- `/Users/hex1n/.agents/skills/ce-work/SKILL.md`
- `/Users/hex1n/.agents/skills/ce-review/SKILL.md`
- `/Users/hex1n/.agents/commands/ce-brainstorm.md`
- `/Users/hex1n/.agents/commands/ce-plan.md`
- `/Users/hex1n/.agents/commands/ce-work.md`
- `/Users/hex1n/.agents/commands/ce-review.md`
- `/Users/hex1n/.agents/skills/proof/SKILL.md`
- `/Users/hex1n/.agents/skills/git-worktree/SKILL.md`
- `/Users/hex1n/.agents/skills/todo-create/SKILL.md`
- `/Users/hex1n/.agents/skills/todo-resolve/SKILL.md`
- `/Users/hex1n/.agents/skills/feature-video/SKILL.md`
- `/Users/hex1n/.agents/skills/` 当前快照下共 **93** 个 skills

## 用户可感知能力层

### 矩阵

| ID | 能力项 | Baton 当前面向用户的形态 | 已安装 CE 当前面向用户的形态 | 当前判断 |
|---|---|---|---|---|
| U1 | 问题澄清与需求收敛 | `baton-explorer` + `baton-specifier`，偏 role/harness 组合 | `ce:brainstorm` 直接做互动式需求澄清与 requirements 文档 | Baton `部分覆盖`，CE 更强 |
| U2 | 技术 planning | `baton-architect` 产出 `architecture.md` | `ce:plan` 产出带 research、implementation units、references 的 plan | Baton `部分覆盖`，CE 更强 |
| U3 | 直接执行 work | `baton-generator` 依赖前置 gate 和 artifacts | `ce:work` 直接消费 plan，管任务切分、执行策略、review tier | Baton `能力存在但定位不同`，CE 更强 |
| U4 | diff review 与 autofix 流程 | `baton-evaluator` 负责独立评估 | `ce:review` 提供 persona review、多模式、autofix、残留路由 | Baton `部分覆盖`，CE 更强 |
| U5 | 长任务闭环纪律 | role + gate + human close 是第一等结构 | workflow 中要求 review，但未显式暴露同级状态机 | Baton 更强 |
| U6 | 研究 / 规划支撑 | `deep-research`、`first-principles-planner` 两个通用能力 skill | research / reviewer / flow / learning 生态更完整 | Baton `部分覆盖`，CE 更强 |
| U7 | 残留工作管理 | 只有 task state，没有 findings/todo 工作流 | `todo-create` / `todo-resolve` / `todo-triage` 持久化残留工作 | Baton `缺失`，CE 更强 |
| U8 | 并行工作与 worktree 体验 | 协议层要求并行任务用另一 worktree/clone，但没有用户面管理器 | `git-worktree` + `ce:work`/`ce:review` 工作流直接纳入 worktree | Baton `缺失`，CE 更强 |
| U9 | 文档共享 / 演示面 | 当前没有对应用户面 | `proof`、`feature-video` 已可直接使用 | Baton `缺失`，CE 更强 |

### 为什么用户会感知到这些差异

- **U1**：Baton 有 requirements capture 能力，但入口是 `Explorer/Specifier` 角色，不是一个面向用户的“brainstorm workflow”。CE 把这一步直接做成 `ce:brainstorm`，并把 requirements 文档与 document-review、planning handoff 接在一起。
- **U2**：Baton 的 `Architect` 很强于“把需求变成可验证架构”，但 `ce:plan` 更像完整 planning 产品，包含 `Requirements Trace`、`Implementation Units`、`Sources & References`、confidence check 与 document-review。
- **U3**：Baton 的 `Generator` 是闭环中的一个角色；CE 的 `ce:work` 是用户直接调用的执行编排器，连 branch/worktree、task list、review tier 都一起管。
- **U4**：Baton 的 `Evaluator` 更像严格独立评估 gate；CE 的 `ce:review` 更像一个代码评审平台，带 15 个 reviewer persona、`mode:autofix/report-only/headless`、`safe_auto/gated_auto/manual/advisory` 路由和 residual queue。
- **U5**：这是 Baton 目前最容易被低估的强项。Baton 在 README 和 protocol docs 里把 `Explorer → Specifier → Architect → human approval → Verifier → Generator → Evaluator → human close` 明确成了闭环，而不是只在 workflow 文本里建议这样做。
- **U6-U9**：已安装 CE 不只是四个主 workflow。它外围还有 reviewer、researcher、todo、Proof、worktree、feature-video 等 companion skills，用户自然会感知到“事情做完以后还有后续层”；Baton 当前这一层明显更薄。

### 用户层小结

如果站在“今天就要拿它干活”的角度：

- 已安装 CE 更像一个**已经打包好的 workflow product**
- Baton 更像一个**需要你懂 protocol/harness 才能把能力串起来的 reference system**

所以用户层的主结论不是 “Baton 没能力”，而是：

**Baton 缺的是面向日常交付的产品壳，而不是底下的协议骨架。**

## 底层机制层

### 矩阵

| ID | 机制项 | Baton 当前实现面 | 已安装 CE 当前实现面 | 当前判断 |
|---|---|---|---|---|
| M1 | 显式状态机与重入路径 | `spec/protocol/state-machine.md` 明确 `exploring → ... → complete` 与 `any -> blocked` / re-entry | 未看到同级显式状态机控制面 | Baton 更强 |
| M2 | Gate 模型与前置条件 | `spec/protocol/gates.md` 定义 Gate 2-5，要求 artifacts、human approval、execution context | workflow 有顺序，但未暴露同级 gate 协议 | Baton 更强 |
| M3 | Artifact 契约与控制平面 | `.harness/` + `task-status.md` + named artifacts 是一等真源 | 有 requirements/plan/review/todo artifacts，但没有统一 control plane | Baton 更强 |
| M4 | Verification before generation | Gate 3 明确“先证明验证路径可执行，再进入 Generator” | `ce:work` 强调测试与 review，但不是同级 protocol gate | Baton 更强 |
| M5 | Verifier/Evaluator 独立隔离契约 | `context: fork`、`spawn_agent({ fork_context: false })`、`strict/compat`、`sequential_fallback` blocker | 有并行 reviewer/subagents，但未看到同级 strict isolation contract | Baton 更强 |
| M6 | Hook / validator / runtime enforcement | `install-hooks.sh`、`validate-artifact.sh`、`validate-transition.sh`、`validate-state-artifacts.sh`、`harness-context.sh`、`subagent-stop` | 主要通过 workflow / skill 约定运转，未看到同级 repo control plane | Baton 更强 |
| M7 | Review synthesis 与 autofix 路由 | 单一 evaluator gate 为主 | `ce:review` 有 persona fan-out、merge/dedup、`safe_auto/gated_auto/manual/advisory` | CE 更强 |
| M8 | 残留行动项持久化 | 没有 findings → todo 的持久化机制 | `.context/compound-engineering/todos/` + `todo-*` skills | CE 更强 |
| M9 | Workspace / worktree 编排 | 协议说“并行任务用另一 worktree 或 clone”，但无管理器 | `git-worktree` 提供可执行管理脚本和 workflow 接入 | CE 更强 |
| M10 | 跨宿主可迁移边界 | `spec/adapters/claude-code.md`、`spec/adapters/codex.md`、`spec/adapters/cursor.md` + profiles/extensions | 已安装面以 workflow skills 为主，未暴露同级 adapter/protocol core | Baton 更强 |
| M11 | Human gate 与 close 语义 | `awaiting_human_arch`、`ready_for_human_close`、Gate 5 明确要求 human accept risk | workflow 有 review 和 next-step，但未见同级 stateful human-close contract | Baton 更强 |

### 机制层解释

- **M1-M4**：Baton 最成熟的不是“怎么写代码”，而是“什么时候可以安全地进入下一步”。`state-machine.md`、`gates.md`、`role-contracts.md` 把很多 AI workflow 常见的隐式约定写成了显式协议。
- **M5-M6**：Baton 已经把 `Verifier` / `Evaluator` 的独立性上升到机制层，不只是“最好这样做”，而是 `strict` 下没有真实隔离就应该 block。再叠加 `install-hooks.sh`、`validate-*`、`session-start`、`subagent-stop`，说明 Baton 已经把一部分 correctness 逻辑从 prompt 文本下沉到了 runtime enforcement。
- **M7-M9**：已安装 CE 的机制优势不在 protocol，而在**工作流外围自动化**。`ce:review` 的多 persona 审查与 findings routing、`todo-*` 的持久工作项、`git-worktree` 的隔离 workspace 管理，都是 Baton 当前没补上的执行壳。
- **M10-M11**：Baton 的可迁移性和 human gate 语义明显更完整。这也是为什么它虽然“上层更薄”，但并不等于“机制更弱”。

### 机制层小结

机制层不是 CE 全赢，也不是 Baton 全赢。

更准确的说法是：

- **Baton 赢在 protocol correctness、runtime enforcement、cross-host portability**
- **已安装 CE 赢在 review automation、residual-work persistence、workspace orchestration**

## 双层映射

用户层看到的主要差距，基本都能映射回机制层：

- **Baton 为什么在 U1-U3 显得更薄**  
  因为 Baton 当前把主要资产放在了 `role + artifact + gate + runtime`，而不是像 CE 那样再包一层 `brainstorm/plan/work` 顶层 workflow。  
  这不是“底层没有”，而是“上层没包出来”。

- **Baton 为什么在 U4/U7 显得 review 能力薄**  
  Baton 有独立 evaluator，但缺 CE 那种 `multi-persona review → autofix routing → durable todos` 的外围机制。  
  所以 Baton 的评估更像 gate，CE 的评审更像系统。

- **Baton 为什么在 U8 看起来不够日用**  
  协议层已经知道并行任务要用 worktree/clone，但没有像 `git-worktree` 那样把它产品化。  
  这是典型的“协议知道，用户面没补”。

- **Baton 为什么在 U5 反而更强**  
  因为 M1-M6 和 M11 已经把闭环纪律写进了协议和 runtime：验证先于生成、独立 review、human close、blocked re-entry。  
  这是用户能感知到的“更难漂移”。

## Baton 当前缺口清单

按 `闭环阻断 > 用户痛感 > 杠杆/成本比` 排序：

| 优先级 | 缺口 | 层次 | 为什么优先 |
|---|---|---|---|
| P1 | 缺少建立在 Baton role/gate 之上的顶层 workflow 壳（brainstorm/plan/work/review） | 双层耦合 | 这是 Baton 与已安装 CE 在用户层最大体感差距，也是把现有 protocol 变成日用品的最短路径 |
| P2 | 缺少围绕 evaluator 的 review synthesis 层：多视角、路由、autofix 策略 | 双层耦合 | Baton 已有独立评估 gate，但缺少 CE 式 review system，导致用户觉得“能关门，但不够会挑问题” |
| P3 | 缺少 findings → todo 的持久化工作项层 | 双层耦合 | 现在 Baton 的 repair loop 有状态，但没有 CE 那种残留问题外化与跨 session 管理能力 |
| P4 | 缺少 worktree / 并行任务管理壳 | 用户层 + 执行机制 | Baton 协议已经要求并行任务隔离，但没有把这件事做成方便的工作流 |
| P5 | 缺少 planning-side research orchestration | 用户层 | Baton 有通用 research/planner skill，但没有像 CE plan 那样把 repo research / learnings / docs lookup 纳入 planning 主流程 |
| P6 | 缺少协作与演示面（Proof / feature-video） | 用户层 | 有价值，但不应先于 workflow shell、review layer、todo layer |

## 近期路线建议

### 1. 先补 workflow shell，不要先重写 protocol

最应该做的是：

- 在 Baton 现有 role/gate/runtime 之上补一层顶层工作流入口
- 这些入口应当**编译到**现有 `.harness` artifacts、`task-status.md`、Gate 2/3/4/5，而不是绕开它们

换句话说，正确方向不是“把 Baton 做成另一个 CE clone”，而是：

**让 Baton 现有 protocol core 有一个更像产品的入口层。**

这类工作最值得优先考虑：

- `baton-brainstorm`
- `baton-plan`
- `baton-work`
- `baton-review`

但这四个入口必须站在 Baton 现有 protocol truth 之上，而不是另起一套 state/artifact 体系。

### 2. 保留 evaluator 作为 gate-of-record，再外接 review system

如果 Baton 直接照抄 CE 的 `ce:review`，容易把“独立 evaluator”稀释成“很多 reviewer 的总和”。

更合理的做法是：

- **保留 `baton-evaluator` 作为最终 gate-of-record**
- 在它前面或旁边增加一个 `review synthesis layer`
  - 多视角 reviewer
  - findings routing
  - autofix policy
  - residual queue

这样 Baton 可以同时保住：

- 自己的独立评估纪律
- CE 式更丰富的 review 体验

### 3. 把 residual queue 做成 Baton repair loop 的外层，而不是替代品

Baton 当前已经有 `blocked`、re-entry 和 `Eval Round` 这种 repair-loop 语义。

它缺的是：

- 把“这次不修但以后要修”的东西沉淀下来
- 在跨 session、跨 PR、跨回合里继续追踪

所以 todo 层的正确位置不是替代 `blocked` / `evaluation.md`，而是：

**作为 Baton repair loop 的持久外层。**

### 4. 把 worktree / parallel ergonomics 当成执行壳补丁

`spec/protocol/state-machine.md` 已经明确说：

- 一个 workspace 只假定一个非 complete active task
- 并行任务请用另一 worktree 或 clone

这说明 Baton 在协议层已经承认并行隔离的重要性。  
缺的是把它做成像 `git-worktree` 那样用户愿意每天用的工具。

这块应当在 review/todo 之后补，而不是更早，因为它提升的是执行舒适度，不是闭环正确性。

### 5. 现在不要优先追这些

当前阶段不建议优先追：

- 把 Baton 整体转成 full runtime product
- 在 protocol 还没被顶层 workflow 壳稳定消费前，先去堆更重的 telemetry/control plane
- 在 workflow shell、review layer、todo layer 还没补起来之前，先做 Proof/feature-video 这类外围展示层

这些都可能是将来的产品层，但不是 Baton 当前最短的价值路径。

## 最终判断

如果问题是：

**“当前 Baton 项目，深度对比已安装 CE，差距到底在哪里？”**

我的结论是：

1. **当前 Baton 还不是已安装 CE 那样的用户层 workflow product。**  
   在日常交付闭环上，它明显更薄。

2. **当前 Baton 已经是比已安装 CE 更明确的 protocol/reference runtime。**  
   在状态机、gates、artifacts、independent verifier/evaluator、hook enforcement、cross-host boundary 上，它反而更成体系。

3. **所以 Baton 的主缺口不是“协议不够严”，而是“产品壳不够厚”。**

4. **最该做的不是抹平 Baton 的 protocol-first 身份，而是给这套 protocol/reference runtime 补上 workflow shell、review synthesis、todo layer、worktree ergonomics。**

如果只允许一句最短结论：

**Baton 现在离已安装 CE 的主要差距，在上层 workflow product；不是在下层 protocol core。**

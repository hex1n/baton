# Baton Positioning

## 1. 问题

Baton 的灵感来自 Anthropic 在 2026 年 3 月 24 日发布的文章
[*Harness design for long-running application development*](https://www.anthropic.com/engineering/harness-design-long-running-apps)。
那篇文章展示了一件很重要的事：当任务变长、变复杂、需要反复验证时，单 agent 直推很快会失稳，而多角色分工、结构化 artifacts、独立 evaluator 和明确 sprint contract 会显著提高结果质量。

但那篇文章回答的是“在 Anthropic 自己可控的运行环境里，怎样把 Claude 推到更强的长任务表现”；它没有直接回答 Baton 该做成什么产品形态。

对 Baton 来说，真正的问题不是“Anthropic 做了 runtime，所以 Baton 也应该直接做 runtime product”，而是：

- Baton 的长期核心资产到底是什么
- Baton 在真实工作项目里怎样才真正有用
- Baton 应该把多少工程投入放到 protocol，多少放到 runtime

## 2. 结论

当前阶段，Baton 最合理的定位是：

**一个 protocol-first 的 AI coding collaboration system，配一个 opinionated local reference runtime。**

更直白一点：

- Baton 的核心产品身份应该仍然是 **protocol**
- Baton 不能只停在协议文档，必须有一个 **真的能跑真实项目闭环的 reference runtime**
- Baton **现在不应该直接升级成 full runtime product**

这三个判断必须同时成立，缺一不可。

## 3. 为什么不是纯 protocol

如果 Baton 只做 protocol，会保留抽象上的漂亮分层，但会在实际工作里失去抓地力。

用户真正要的不是“有 Explorer、Specifier、Architect、Verifier、Generator、Evaluator 这些词”，而是：

1. 给一个真实需求
2. 能把方案设计出来
3. 能 review 方案
4. 能实现
5. 能验证
6. 能在发现问题后修复并重新验证
7. 最后稳定收敛到 human accepted complete

这套闭环如果没有 runtime 支撑，很多关键动作会退化成：

- 靠执行者自觉 dispatch 正确角色
- 靠人工维护 state
- 靠人工判断 gate 是否真的过了
- 靠约定而不是系统来保持 verifier / evaluator 独立性

这会让 Baton 变成“高质量流程理念”，而不是“真正能在工作里每天使用的系统”。

所以 Baton 不能只做 protocol。

## 4. 为什么不是现在就做 runtime product

另一边，如果 Baton 现在就把自己定义成 runtime product，也会过早走偏。

原因有四个：

### 4.1 Baton 当前最稳的资产仍是 protocol

仓库里最清晰、最可迁移、最不依赖宿主的东西，仍然是：

- state machine
- role contracts
- gates
- artifacts
- adapters / profiles / extensions 分层

这些东西构成了 Baton 的可迁移核心。它们能跨 Claude、Codex、Cursor 甚至未来别的宿主继续成立。

### 4.2 runtime 能力仍在收敛期

当前 Baton 已经有了一层最小 enforcement runtime，但还远没到“完整 runtime product”：

- 有 bootstrap、hooks、artifact validator、transition validator、isolation validator
- 但还没有完整的 job orchestration、receipt/telemetry 平台、跨宿主统一执行控制面

如果现在就转成 runtime product，工程重心会快速从协议收敛转向：

- agent dispatch
- scheduler
- recovery
- telemetry
- execution receipts
- host-specific integration

这会在协议还没完全收敛时，提前把 Baton 绑到某个运行时表面上。

### 4.3 Anthropic 的 runtime 前提和 Baton 不一样

Anthropic 文中的 harness 建在它自己的可控环境上：模型、Agent SDK、MCP、评估路径和运行权限都更统一。

Baton 现在面对的是异构宿主环境：

- Claude Code
- Codex
- Cursor
- 以及未来可能的更多 agent host

这意味着 Baton 不能简单照搬 Anthropic 的产品形态，只能借鉴其中的方法论：

- 多角色分工
- evaluator 独立性
- artifacts 作为交接面
- 长任务靠 handoff / reset / loop 收敛

### 4.4 现在最大的风险不是“runtime 不够厚”，而是“边界不够稳”

如果 protocol、template、validator、skill、host adapter 还没有完全锁成单一真源，runtime product 只会把这些漂移放大。

所以当前阶段更重要的是：

- 锁 protocol
- 强化 reference runtime
- 用真实项目压测闭环

而不是直接跳到更重的产品形态。

## 5. 推荐的三层模型

### 5.1 Layer 1: Protocol Core

这层是 Baton 的核心产品身份。

它定义：

- 角色
- 状态机
- gates
- artifact schema
- adapter capability boundary
- profiles / extensions

判断标准只有一个：**如果 reference runtime 全部重写，这层是否依然成立。**

如果答案是“会”，它属于 protocol core。

### 5.2 Layer 2: Opinionated Reference Runtime

这层是 Baton 在真实项目里变得“可日用”的关键。

它不是 Baton 的唯一产品身份，但它必须足够强，才能支撑用户真正完成任务闭环。

这层至少应该负责：

- task start / resume / close
- state transition enforcement
- artifact validation
- verifier / evaluator isolation dispatch
- provenance / receipt 记录
- human gate surface
- repair loop 支持
- 本地 hooks / stop checks

对你的真实使用场景来说，这一层才是把“需求 → 设计 → review → 实现 → 验证 → 完成”真正跑起来的执行面。

### 5.3 Layer 3: Future Runtime Product

只有当 Baton 的执行面本身开始成为独立价值，才应该进入这一层。

这层才会包含更重的内容，例如：

- 跨宿主统一 orchestration
- runtime telemetry ingestion
- machine receipts 作为一等真源
- 多任务 / worktree 调度
- 长任务恢复与追踪
- 可视化 control plane

一旦进入这一层，Baton 的产品重心就会开始从“协议”转向“执行平台”。

这不是不能做，而是现在还不该做。

## 6. 对真实工作项目意味着什么

你对 Baton 的期待是对的：它应该服务真实工作，而不是只服务 prompt engineering。

但这里有一个重要边界：

**Baton 的目标不是抽象意义上的“完美完成”，而是更稳定地收敛到 human-accepted complete。**

也就是说，Baton 要做的是：

- 让需求和方案更早收敛
- 让 review 和 verification 更早暴露问题
- 让 repair loop 有证据、有轮次、有退出条件
- 让 human close 发生在真正有独立验证之后

如果没有 reference runtime，这些只能停留在原则层。
如果太早做 full runtime product，又会把协议价值压扁成某个宿主的实现细节。

所以最合理的现实路径不是二选一，而是：

**protocol first, runtime backed.**

## 7. 下一阶段应该怎么投

短中期最值得投入的不是“把 Baton 全面产品化为 runtime”，而是把 reference runtime 做到足够硬：

1. gate enforcement 更稳
2. isolation evidence 更真
3. provenance 从 artifact 自述逐步升级到 runtime receipt
4. recovery / resume 更可靠
5. human close surface 更清楚
6. 在真实工作项目上反复压测

这会让 Baton 在不丢失 protocol 核心价值的前提下，真正变成你能每天使用的工作系统。

## 8. 什么时候才该升级成 runtime product

只有当下面几类信号同时变强时，Baton 才应该正式升级为 runtime product：

- 多个真实项目都证明 reference runtime 是刚需，而不是可选辅助
- 大部分关键价值已经来自 Baton 自己的执行面，而不是 protocol 文档本身
- receipt / telemetry / orchestration 已经成为 correctness 的必要条件
- 宿主能力边界已经足够稳定，值得为其建设更重的平台层
- 你愿意接受 Baton 的一部分可迁移性，换更强的执行控制力

如果这些信号还不够强，最佳策略仍然是：

- protocol 继续做核心
- reference runtime 持续加厚
- runtime product 暂不提前承诺

## 9. 推荐的一句话定位

可以把 Baton 的内部定位先收敛成一句话：

**Baton is a protocol-first AI coding harness, with an opinionated local reference runtime.**

这句话的好处是：

- 保住了 Baton 最核心的长期资产
- 明确了 Baton 不是“只有文档”
- 也避免过早把 Baton 锁死成某个宿主绑定的 runtime product

## 10. 最终判断

如果只允许在“runtime product”与“protocol”之间二选一，我会选 **protocol**。

但如果问题是“Baton 现在应该怎样做，才能既保持长期价值，又在真实工作项目里真正有用”，答案不是纯 protocol，而是：

**做 protocol core，配一个强的 reference runtime；暂时不要把 Baton 全面转成 runtime product。**

# Baton Workflow Best Practice

## 1. 目的

这份文档回答一个实际问题：

如果你想在真实工作项目里用 Baton，把一个需求从“有人提出”推进到“human accepted complete”，最稳的流程应该怎么跑？

结论不是“所有任务都走最重流程”，而是：

**默认走 Core Flow；只有在高风险或高复杂度任务下，才升级到 Strict Overlay。**

这和 [Baton Positioning](./baton-positioning.md) 一致：

- Baton 的核心仍然是 protocol
- Baton 需要一个可日用的 reference runtime
- Baton 现在不应该把所有工作都推成 full runtime product 风格

## 2. 先记住三条规则

### 2.1 先证明能验证，再开始生成

`Verifier` 不是可选角色。  
如果还不能证明测试、构建、检查或最小验证路径可运行，就不应该进入实现。

### 2.2 默认走轻闭环，不默认走重流程

不是每个任务都需要：

- `codebase-map.md`
- `decisions.md`
- `api-contract.yaml`
- `schema-draft.sql`
- 按模块迭代
- migration 专属审批

这些都属于严格叠加层，而不是默认 core。

### 2.3 目标是稳定收敛，不是形式上的“完美”

Baton 的目标不是把每个任务都抬成大型流程工程，而是：

- 尽早暴露误解
- 尽早暴露验证缺口
- 让修复循环有边界
- 让 human close 建立在独立验证之上

## 3. Core Flow

这是所有任务都适用的默认闭环。

```text
用户需求（1-4 句话）
        │
        ├─ 存量项目? YES → Explorer
        │                 输出: exploration.md
        │
        └─ 存量项目? NO  → 直接进入 Specifier
        ▼
Specifier
输出: requirements.md
        │
⛔ 人类检查点 #1
需求、边界、验收标准是否正确
        │
        ▼
Architect
输出: architecture.md
        │
⛔ 人类检查点 #2
方案方向、写入面、风险、回退策略是否接受
        │
        ▼
Verifier
输出: verification.md
        │
        ├─ BLOCKED → 回 Architect / Specifier / Human
        └─ PASS
        ▼
Generator
实现一个可验证 slice
        │
        ▼
Evaluator（独立 Agent）
输出: evaluation.md
        │
        ├─ BLOCKED → 回 Generator 修复
        └─ PASS
        ▼
Final Evaluator Pass
整体验收轮
        │
⛔ 人类检查点 #3
残余风险是否接受，目标是否达成
        │
        ▼
complete
```

## 4. 为什么 Core Flow 应该这样定义

### 4.1 Explorer 不是永远都要跑

如果是存量项目，Explorer 默认应该存在，因为你需要先知道：

- 入口点在哪
- 写入面在哪
- 现有测试和验证落点在哪
- 哪些风险已经在仓库里存在

如果是新项目、功能很小、上下文极其明确，可以直接进入 Specifier。

### 4.2 Specifier 是第一份真正的合同

`requirements.md` 不只是“写点需求说明”，而是后面所有角色共享的任务合同。

它至少要锁住：

- 问题是什么
- 范围是什么
- 非目标是什么
- 验收标准是什么

如果这里没锁住，后面的架构、实现和评估都会漂。

### 4.3 Architect 后必须有人类检查点

架构阶段不是为了写大文档，而是为了把这些问题提前讲明白：

- 改哪些面
- 不改哪些面
- 为什么这样改
- 风险在哪
- 如果失败怎么退

这一步之后的 human approval 不能省。  
不然 Generator 很容易在一个未经确认的方向上高速前进。

### 4.4 Verifier 是 Core Flow 里最不能丢的一步

很多流程图最大的问题，是把“验证”理解成实现之后的动作。

在 Baton 里，`Verifier` 是生成前 gate：

- 测试能跑吗
- 构建能过吗
- 需要哪些依赖和环境
- 如果主验证路径不可用，回退策略是什么

如果这里不通过，就应该 `blocked`，而不是让 Generator 盲写。

### 4.5 Evaluator 必须独立

`Generator` 和 `Evaluator` 不能共享同一条推理链来互相证明。

最佳实践是：

- `Generator` 负责实现和局部自修
- `Evaluator` 负责独立检查、列 findings、给 verdict
- 最终再做一轮全局 `Final Evaluator Pass`

你原图里的 `Cross-Cutter` 很有价值，但更稳的收法不是新增一个全新角色，而是把它定义成 **Evaluator 的最终整体验收轮**。

## 5. Strict Overlay

当任务进入高风险、高复杂度或高运行时成本场景时，在 Core Flow 之上叠加严格流程。

### 5.1 触发条件

满足以下一项或多项时，建议升级：

- Java / Spring / backend-heavy 任务
- 有数据库 schema 或 migration
- 有 API contract 约束
- 改动跨多个模块
- 运行时验证比静态验证更重要
- 单次生成很容易跨过可控写入面

### 5.2 叠加内容

升级到 Strict Overlay 后，通常增加这些要求：

- Explorer 额外产出 `codebase-map.md`
- Architect 额外产出 `decisions.md`
- 有接口时增加 `api-contract.yaml`
- 有数据库时增加 `schema-draft.sql`
- Generator 按模块或按 slice 迭代，而不是一次铺太大
- 每个模块都要过一轮独立 Evaluator
- 有 migration 时必须加入额外 human approval
- 最后再做一轮全局 Final Evaluator Pass

### 5.3 一个更接近 strict 的流程

```text
用户需求
   │
Explorer
输出: exploration.md + codebase-map.md
   │
Specifier
输出: requirements.md
   │
⛔ Human #1 需求检查
   │
Architect
输出: architecture.md + decisions.md
      + api-contract.yaml? + schema-draft.sql?
   │
⛔ Human #2 架构 / 数据模型 / 风险检查
   │
Verifier
输出: verification.md
   │
Generator（模块 A）
   │
Evaluator（独立）
   │
Generator（模块 B）
   │
Evaluator（独立）
   │
...
   │
有 migration?
   ├─ YES → ⛔ 额外 human approval
   └─ NO
   │
Final Evaluator Pass
   │
⛔ Human #3 最终 close
   │
complete
```

## 6. 你原流程里哪些点应该保留

- `Explorer` 在存量项目默认启用，这点对。
- `Specifier` 可以向用户提问，这点必须保留。
- `Generator -> Evaluator` 的修复循环，这点必须保留。
- migration 需要额外人类审批，这点也对。
- 最终做一次跨模块、跨切面的整体验收，这点也应该保留。

## 7. 你原流程里哪些点应该调整

### 7.1 补上显式 Verifier

这是最关键的调整。  
没有 `Verifier` 的流程，很容易退化成“先写再说”。

### 7.2 Cross-Cutter 改成 Final Evaluator Pass

你要的能力保留，但角色模型更简单：

- 不新增新角色
- 只规定 Evaluator 在末尾还要做一次全局轮

### 7.3 git commit checkpoint 不是 protocol hard requirement

把 `git commit checkpoint` 写成最佳实践可以，但不要把它写成协议强制要求。

更合理的定位是：

- 在 reference runtime 里，建议把每个稳定 slice 作为一个本地检查点
- 但 protocol core 不要求每个任务都必须 commit

### 7.4 附加工件不能默认全员强制

`codebase-map.md`、`decisions.md`、`api-contract.yaml`、`schema-draft.sql` 都有价值，但应属于 strict overlay 或领域特定扩展，而不是 core 默认要求。

## 8. 运行规则

### 8.1 任意阶段都允许 blocked

`blocked` 不是失败，而是显式保护。

一旦 blocked，必须写清楚：

- 为什么阻塞
- 当前证据是什么
- 下一步需要谁来决策

### 8.2 repair loop 要有上限

不要无限自修。  
最佳实践是：

- 同一问题修复循环建议最多 `2-3` 轮
- 超过上限就升级给 human 或 Architect

### 8.3 Generator 只实现可验证 slice

不要一次铺太大。  
即使在 core flow 里，也尽量让每一轮实现都对应一个明确的验证单元。

### 8.4 Evaluator 只接受证据，不接受希望

`PASS` 不能基于“应该没问题”。  
必须基于：

- 命令结果
- 明确文件改动
- requirements 对照
- architecture 对照

### 8.5 human close 不能删

自动化验证再强，最终是否接受残余风险，仍然应该由 human 决定。

## 9. 常见反模式

- 把 strict overlay 当成所有任务默认流程，导致日常使用过重
- 跳过 Verifier，直接让 Generator 开始写
- 让 Generator 和 Evaluator 在同一上下文里互相证明
- 把 `blocked` 当成坏事，结果把风险藏进“继续推进”
- 没有 repair loop 上限，导致同一问题无限回圈
- 把 git commit、migration 审批、runtime telemetry 之类的执行层实践误写成 protocol core

## 10. 一句话版最佳实践

如果要把 Baton 的工作流最佳实践压成一句话，就是：

**默认走轻 Core Flow；遇到 backend、migration、cross-module 等高风险任务，再升级到 Strict Overlay。**

这能同时满足三件事：

- 保持 Baton 的 protocol core 简洁可迁移
- 让 reference runtime 足够强，能支撑真实项目闭环
- 避免过早把 Baton 推成一个过重的 runtime product

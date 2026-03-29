# Architecture: workflow-best-practice-doc

**主题**: 用一份最佳实践文档收敛 Baton 的默认流程与严格叠加流程  
**状态**: `approved`  
**规模**: `Small`

## 1. 问题

用户期望的 Baton 完整流程已经接近一个高质量的 strict workflow，但 Baton 不能把重型后端任务的流程直接上升为所有任务的默认流程。需要一份文档把“通用默认闭环”和“高风险严格叠加层”拆开，并把这份拆分与当前 positioning、core artifact schema、strict extension 边界保持一致。

## 2. 第一性原理拆解

### 2.1 问题陈述

一个好的工作流必须既能服务真实项目闭环，又不能把所有任务都推入过重的流程负担；因此问题不是“选轻还是选重”，而是如何定义一个默认最小闭环，并在高风险任务下稳定升级。

### 2.2 约束

- current core artifact schema 只要求 `scoped-map`、`requirements`、`architecture`、`verification-path`、`evaluation`
- java-backend-strict 已经存在额外工件和模块循环定义
- 文档要回应用户流程图，但不能让 core protocol 和 strict overlay 混在一起
- 不在本任务里引入新的 spec 要求

### 2.3 方案类别

- 方案 A: 把用户给出的完整重流程直接写成 Baton 通用最佳实践
- 方案 B: 定义 `Core Flow + Strict Overlay`，默认轻量闭环，风险任务再升级
- 方案 C: 只给原则，不给明确流程图与实践规则

### 2.4 评估

- 为什么方案 B 胜出:
  - 能保留用户流程图里最重要的控制点
  - 不会把 strict artifacts 和审批污染到所有任务
  - 与 positioning 文档和现有 extension 边界一致
- 为什么拒绝方案 A:
  - 会把后端重流程错误提升为 core 默认要求
  - 会增加不必要的日常使用负担
- 为什么拒绝方案 C:
  - 用户要的是可执行最佳实践，不是又一份抽象原则

## 3. 推荐架构

- 方法:
  - 新增一份 `docs/baton-workflow-best-practice.md`
- 关键变更点:
  - 定义默认 `Core Flow`
  - 定义条件触发的 `Strict Overlay`
  - 给出“保留 / 调整 / 非默认要求”的明确判断
  - 增加 operational rules 和 anti-patterns
- 数据 / 控制边界:
  - 文档层解释工作流使用法
  - 不修改 `spec/protocol/` 规范本体
  - strict extension 仍是重型任务的来源，不被文档替代
- 向后兼容说明:
  - 完全向后兼容；只是把已存在的做法写得更清楚

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `/Users/hex1n/IdeaProjects/baton/docs/baton-workflow-best-practice.md` | L2 | add | 新增正式最佳实践文档 |
| `/Users/hex1n/IdeaProjects/baton/.harness/scoped-map.md` | L3 | modify | 记录探索结论 |
| `/Users/hex1n/IdeaProjects/baton/.harness/requirements.md` | L3 | modify | 固化需求边界 |
| `/Users/hex1n/IdeaProjects/baton/.harness/architecture.md` | L3 | modify | 固化推荐方案 |
| `/Users/hex1n/IdeaProjects/baton/.harness/verification-path.md` | L3 | modify | 记录文档验证路径 |
| `/Users/hex1n/IdeaProjects/baton/.harness/evaluation.md` | L3 | modify | 记录独立评估结论 |

## 5. 验证策略

- 主要检查:
  - 文档存在
  - 关键结构和术语可检索
  - `.harness/` artifacts 满足 schema
- 评审重点:
  - 是否清楚区分 core 与 overlay
  - 是否明确保留 `Verifier`
  - 是否把 `Cross-Cutter` 正确收敛为 final evaluator pass
- 验证无法完全消除的风险:
  - 文档正确不等于未来所有人都会按文档执行

## 6. 风险

- 文档可能过长，变成第二份 spec
- 读者可能仍误以为 strict overlay 是默认要求
- 未来如果 strict extension 改动，这份文档可能需要同步

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 是当前最优类别，因为它兼顾可执行性与轻重边界。
2. 还有哪些假设尚未验证?
   - 这份文档是否足够指导陌生用户执行，还需后续真实项目验证。
3. 一个怀疑者会先质疑什么?
   - “既然 strict overlay 看起来更完整，为什么不默认所有任务都走它？” 文档需要直接回答这一点。

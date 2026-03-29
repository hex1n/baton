# Requirements: workflow-best-practice-doc

**主题**: 产出 Baton workflow best practice 文档，明确 core flow 与 strict overlay  
**状态**: `approved`  
**规模**: `Small`

## 1. 问题

用户已经给出一个预期的完整流程图，包含 Explorer、Specifier、Architect、模块级 Generator/Evaluator 循环、Cross-Cutter 全局审查和多个人类检查点。这个方向是对的，但如果直接把整套重流程当作 Baton 的统一默认流程，会让 core protocol 过重，并和当前 `protocol-first + reference runtime` 的定位产生张力。当前缺少一份正式文档，把 Baton 的最佳实践解释成“默认走轻 core flow，遇到后端 / migration / cross-module 等高风险任务时再升级到 strict overlay”。

## 2. 范围

### 2.1 范围内

- 新增 `docs/baton-workflow-best-practice.md`
- 明确 core flow 的默认步骤与必要检查点
- 明确 strict overlay 的触发条件、附加 artifacts 和额外人类审批
- 解释为什么 `Verifier` 不能丢、为什么 `Cross-Cutter` 更适合作为 final evaluator pass
- 给出真实项目中的使用规则和反模式

### 2.2 范围外

- 修改 protocol core artifact schema
- 强制把 `codebase-map.md`、`decisions.md`、`api-contract.yaml`、`schema-draft.sql` 加入所有任务
- 修改 strict extension 本身
- 改写 README 主流程图

## 3. 功能需求

### FR-1 默认流程

- 文档必须给出一个适用于大多数任务的 core flow
- core flow 必须保留 `Verifier`
- core flow 必须保留至少三个 human checkpoints：需求、架构、最终关闭

### FR-2 严格叠加层

- 文档必须明确 strict overlay 不是所有任务的默认要求
- 文档必须列出 strict overlay 的适用条件
- 文档必须列出 strict overlay 里新增的 artifacts、审批点和模块循环

### FR-3 与现有定位一致

- 文档必须与 `docs/baton-positioning.md` 的 `protocol-first + reference runtime` 结论一致
- 文档不得把 Baton 定义成 full runtime product

### FR-4 可执行性

- 文档必须能指导真实工作项目执行，而不是只讲抽象理念
- 文档必须包含实践规则，例如 repair loop 上限、blocked 使用方式、git commit 作为 runtime practice 而不是 protocol hard requirement

## 4. 非目标

- 不在本任务里重画 spec 级状态机
- 不在本任务里承诺未来 runtime product 的平台能力
- 不在本任务里设计新的 telemetry receipt schema

## 5. 验收标准

### AC-1 文档存在

- `docs/baton-workflow-best-practice.md` 存在

### AC-2 核心结构清楚

- 文档明确分出 `Core Flow` 与 `Strict Overlay`

### AC-3 回应用户流程图

- 文档明确说明哪些点保留，哪些点调整，以及为什么

### AC-4 实践导向

- 文档包含可执行的规则，而不是只讲原则

### AC-5 与定位一致

- 文档不与 `docs/baton-positioning.md` 冲突

## 6. 约束

- 文档语言使用中文
- 只新增文档，不改协议实现
- 需要与 current strict extension 的边界定义一致

## 7. 验证意图

- 检查文档存在
- 检查文档包含 `Core Flow`、`Strict Overlay`、`Verifier`、`Final Evaluator`、`blocked`、`repair loop` 等关键概念
- 检查文档没有把 strict overlay 误写成 core 必需项

# Scoped Map: workflow-best-practice-doc

**需求**: 把 Baton 的完整最佳实践流程写成正式文档，明确 core flow 与 strict overlay 的边界  
**领域**: workflow design / protocol usage / best practice  
**Owner**: `scoped-explorer`  
**状态**: `complete`

## 1. 范围

- 范围内:
  - 把用户提出的完整流程收敛成 Baton 推荐实践
  - 明确哪些步骤属于所有任务的 core flow
  - 明确哪些额外 artifact / 审批 / 模块循环只属于 strict overlay
  - 产出一份可直接阅读的最佳实践文档
- 范围外:
  - 修改 protocol schema
  - 修改 Java strict extension 规范
  - 实现新的 runtime 行为
- 预期写入边界:
  - `.harness/` 当前任务 artifacts
  - `docs/baton-workflow-best-practice.md`

## 2. 入口点

- 主要入口类或文件:
  - `docs/baton-positioning.md`
  - `spec/extensions/java-backend-strict/README.md`
  - `spec/protocol/artifact-schema.md`
- 涉及的方法、API、命令或脚本:
  - `spec/bootstrap/validate-artifact.sh`
  - `spec/bootstrap/validate-isolation.sh`
  - `spec/bootstrap/harness-context.sh`
- 这些入口为什么相关:
  - 定位文档给出 `protocol-first + reference runtime` 的上位边界
  - strict extension 说明重流程应作为 overlay 存在，而不是污染 core
  - artifact schema 定义了 core 当前已经规范化的 artifact 集

## 3. 调用链

```text
user desired end-to-end workflow -> best-practice synthesis -> docs/baton-workflow-best-practice.md -> future repo adoption / training / task execution
```

## 4. 现有行为

- 当前可观察行为:
  - 仓库已有定位文档，但还没有一份正式 workflow best practice 文档
  - strict extension 已经提出 `codebase-map.md`、`decisions.md`、`api-contract.yaml`、模块循环和 migration checkpoint
- 当前校验规则:
  - 文档任务仍需满足 `.harness/` artifact schema
  - `strict` 模式下 verifier / evaluator 仍需隔离
- 现有隐式约束:
  - 不能把 strict overlay 的工件误写成 core protocol 的默认要求
  - 文档必须回应用户给出的完整流程图，而不是只重述 positioning

## 5. 现有测试

- 直接相关的测试:
  - 无专门的 doc 测试；主要靠 artifact validator 和关键结论匹配
- 附近可复用的测试:
  - `spec/bootstrap/validate-artifact.sh`
  - `spec/bootstrap/validate-isolation.sh`
- 未找到可用测试:
  - 无自动化检查文档中流程结构是否完整

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 否；只新增文档与当前 artifacts
- 这次改动是否可能触及迁移或 schema?
  - 否；只解释现有 core 与 overlay 的用法
- 这次改动是否可能跨业务域?
  - 会影响 Baton 的使用习惯和后续培训方式，但不影响 runtime 实现

## 7. 变更形态

- 这看起来像:
  - workflow best practice 文档化
- 预计文件数:
  - 5 到 7 个文件
- 推荐实现深度:
  - 中等；要把“什么时候轻、什么时候重”讲具体

## 8. 未决问题

- 是否未来需要把这份最佳实践同步进 README 或 spec/README
- 是否要单独再写一份 strict overlay 触发条件速查表

## 9. 建议

- 是否继续?
  - 是
- 建议下一步:
  - 锁 requirements / architecture，然后新增最佳实践文档

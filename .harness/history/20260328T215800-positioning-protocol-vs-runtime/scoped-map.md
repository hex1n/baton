# Scoped Map: positioning-protocol-vs-runtime

**需求**: 把 Baton 应该做成 protocol 还是 runtime product 的判断，沉淀成正式定位文档  
**领域**: 产品定位 / 协议工程 / runtime strategy  
**Owner**: `scoped-explorer`  
**状态**: `complete`

## 1. 范围

- 范围内:
  - 归纳 Baton 当前公开定位与仓库真实结构
  - 结合 Anthropic 的 harness 文章，说明 Baton 应吸收什么、不应直接复制什么
  - 明确 `protocol core / reference runtime / future runtime product` 三层边界
  - 给出适配“真实工作项目从需求到验证闭环”的推荐路线
- 范围外:
  - 修改 README 主定位
  - 新增 runtime 功能或协议字段
  - 调整 adapter / hook / validator 实现
- 预期写入边界:
  - `.harness/` 当前任务工件
  - `docs/baton-positioning.md`

## 2. 入口点

- 主要入口类或文件:
  - `README.md`
  - `spec/README.md`
  - `docs/runtime-thickness-analysis.md`
  - `docs/review-analysis.md`
  - `docs/spec-deep-analysis.md`
- 涉及的方法、API、命令或脚本:
  - `spec/bootstrap/start-task.sh`
  - `spec/bootstrap/validate-artifact.sh`
  - `spec/bootstrap/harness-context.sh`
- 这些入口为什么相关:
  - README 给出当前对外定位
  - 现有分析文档描述 protocol/runtime 张力
  - harness artifacts 定义本任务必须落成的中间决策

## 3. 调用链

```text
user expectation -> product positioning decision -> docs/baton-positioning.md -> downstream roadmap and runtime investment choices
```

## 4. 现有行为

- 当前可观察行为:
  - README 已将 Baton 定义为 portable AI coding agent collaboration protocol
  - 仓库里已有多篇分析文档，但还没有一份单独的定位文档把 protocol 与 runtime 边界锁定
- 当前校验规则:
  - 文档任务仍需走 `.harness/` 流程
  - `strict` 模式下 verifier / evaluator 需要隔离执行证据
- 现有隐式约束:
  - 文档结论不能与 README 的 protocol-first 定位直接冲突
  - 不能把 Anthropic 内部 harness 的运行时形态直接等同于 Baton 的产品形态

## 5. 现有测试

- 直接相关的测试:
  - 无代码级测试；以文档存在性与关键结论检查为主
- 附近可复用的测试:
  - `spec/bootstrap/validate-artifact.sh`
  - `spec/bootstrap/harness-context.sh`
- 未找到可用测试:
  - 无专门针对 docs 定位文档的自动化测试

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 否；仅新增分析文档与当前任务 artifacts
- 这次改动是否可能触及迁移或 schema?
  - 否；不改 protocol schema
- 这次改动是否可能跨业务域?
  - 会影响后续 roadmap、runtime investment 和 public messaging

## 7. 变更形态

- 这看起来像:
  - 文档澄清 + 产品定位收敛
- 预计文件数:
  - 5 到 7 个文件
- 推荐实现深度:
  - 中等；需要把战略判断写到可执行的路线层，而不只是观点表态

## 8. 未决问题

- 是否需要同步 README 主定位
- 是否需要把这份定位提升为 spec 外的长期产品文档而不是单次分析

## 9. 建议

- 是否继续?
  - 是
- 建议下一步:
  - 先锁 requirements / architecture，再落 `docs/baton-positioning.md`

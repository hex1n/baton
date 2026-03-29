# Scoped Map: isolation-enforcement-hardening

**需求**: 基于 `docs/review-analysis.md` 和本轮执行偏差，补上 Baton 对 verifier / evaluator 隔离执行的协议与 runtime enforcement 缺口  
**领域**: harness protocol / adapter contract / runtime enforcement  
**Owner**: `scoped-explorer`  
**状态**: `complete`

## 1. 范围

- 范围内:
  - 统一 strict / compat 两种隔离执行模式
  - 修正 protocol / adapter / root governance 对 sequential fallback 的歧义
  - 为 verifier / evaluator 增加可验证的 isolation provenance
  - 为 `ready_for_human_close` 增加独立评估 artifact 要求
  - 增加 isolation validator 并挂到 runtime stop checks
  - 生成一份面向仓库的执行计划文档
- 范围外:
  - 新增更重的 orchestrator / scheduler
  - 真实检查宿主是否实际调用了平台级 subagent API
  - 扩新的角色树或 Java strict 专属 runtime
- 预期写入边界:
  - `docs/plans/`
  - `spec/protocol/`
  - `spec/adapters/`
  - `spec/templates/`
  - `spec/bootstrap/`
  - `skills/`
  - `tests/`
  - `.harness/`

## 2. 入口点

- 主要入口类或文件:
  - `spec/adapters/cli-adapter-interface.md`
  - `spec/adapters/codex.md`
  - `spec/adapters/claude-code.md`
  - `spec/protocol/role-contracts.md`
  - `spec/protocol/gates.md`
  - `spec/protocol/artifact-schema.md`
  - `spec/templates/root-governance.template.md`
  - `spec/templates/verification-path.template.md`
  - `spec/bootstrap/validate-state-artifacts.sh`
  - `spec/bootstrap/validate-artifact.sh`
  - `spec/bootstrap/install-hooks.sh`
- 涉及的方法、API、命令或脚本:
  - `spawn_agent({ fork_context: false })`
  - Claude `Agent` dispatch
  - stop-hook validation
  - artifact schema checks
- 这些入口为什么相关:
  - 它们共同决定“哪些角色必须隔离、如何声明降级、何时允许进入 human close”

## 3. 调用链

```text
protocol + adapter rules
  -> verifier / evaluator artifact contract
  -> runtime validators + stop hooks
  -> ready_for_human_close gate semantics
```

## 4. 现有行为

- 当前可观察行为:
  - `cli-adapter-interface.md` 说 verifier / evaluator 隔离是硬要求
  - `codex.md` 和 `claude-code.md` 仍把 sequential fallback 写成通用退路
  - `verification-path.md` 目前不要求记录 isolation mode / execution context
  - `evaluation.md` 仍是 optional artifact
  - stop hooks 不会阻止“没有独立评估证据”却进入 `ready_for_human_close`
- 当前校验规则:
  - `validate-state-artifacts.sh` 只看 artifacts 是否存在
  - `validate-artifact.sh` 只看 section 是否存在
  - 没有 isolation-specific validator
- 现有隐式约束:
  - verifier / evaluator 的独立性主要依赖 orchestrator 自觉
  - “compat 降级是否被允许”没有单一真源

## 5. 现有测试

- 直接相关的测试:
  - `tests/test-validate-artifact.sh`
  - `tests/test-validate-state-artifacts.sh`
  - `tests/test-install-hooks.sh`
- 附近可复用的测试:
  - `tests/test-harness-context.sh`
  - `tests/test-validate-transition.sh`
- 未找到可用测试:
  - isolation mode strict/compat validator coverage
  - `ready_for_human_close` 对 `evaluation.md` 的硬要求

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 是，hooks 和 profile 语义会受影响
- 这次改动是否可能触及迁移或 schema?
  - 是，`verification-path.md` 与 `evaluation.md` 的 schema 会收紧
- 这次改动是否可能跨业务域?
  - 否，集中在 harness protocol/runtime

## 7. 变更形态

- 这看起来像:
  - 一次小而硬的 protocol-to-runtime hardening
- 预计文件数:
  - 12-18 个
- 推荐实现深度:
  - 中等；先做 strict/compat、artifact provenance、runtime validator，不做重 orchestrator

## 8. 未决问题

- Baton 是否需要真正检测“平台 API 确实创建了 subagent”，还是先只要求 artifact-level provenance？
- `compat` 默认值应该是向后兼容还是 reference implementation 严格优先？

## 9. 建议

- 是否继续?
  - 是
- 建议下一步:
  - 先消掉 strict/compat 语义冲突
  - 再让 verifier / evaluator 产物显式记录 isolation provenance
  - 最后把 gate enforcement 补到 validator 和 stop hooks

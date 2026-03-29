# Scoped Map: provenance-standardization-hardening

**需求**: 根据上一轮 retrospective，把 verifier / evaluator 的 provenance 标准化，并让 human close 直接看到 provenance 与 verdict  
**领域**: harness protocol / bootstrap validators / human-close status surface  
**Owner**: `scoped-explorer`  
**状态**: `complete`

## 1. 范围

- 范围内:
  - 统一 `verification-path.md` 与 `evaluation.md` 的 provenance section 名称与字段名
  - 抽出 provenance 读取辅助逻辑，避免 validator / status surface 各自发明字段解析
  - 在 human-close / complete 的状态可见面直接暴露 verifier/evaluator provenance 与 evaluator verdict
  - 把“模板更新 -> validator 更新 -> start-task reset -> tests 覆盖”的联动收进 consistency check
- 范围外:
  - 引入平台级 telemetry 或 agent runtime attestation
  - 改造整体状态机或新增角色
  - 改动 Java strict extension 的专用 runtime
- 预期写入边界:
  - `docs/plans/`
  - `spec/protocol/`
  - `spec/templates/`
  - `spec/bootstrap/`
  - `skills/`
  - `tests/`
  - `.harness/`

## 2. 入口点

- 主要入口类或文件:
  - `spec/protocol/artifact-schema.md`
  - `spec/templates/verification-path.template.md`
  - `spec/templates/evaluation.template.md`
  - `spec/bootstrap/validate-isolation.sh`
  - `spec/bootstrap/harness-context.sh`
  - `spec/bootstrap/check-consistency.sh`
  - `skills/baton-status.md`
- 涉及的方法、API、命令或脚本:
  - artifact provenance 读取
  - SessionStart context injection
  - stop-time isolation validation
  - consistency invariants
- 这些入口为什么相关:
  - 它们共同决定 Baton 是否真正把 “provenance 是协议字段” 和 “human close 能直接看见 verdict” 落成统一系统

## 3. 调用链

```text
artifact schema + templates
  -> provenance reader / validator
  -> SessionStart / status surface
  -> human close decision
```

## 4. 现有行为

- 当前可观察行为:
  - `verification-path.md` 与 `evaluation.md` 都有 provenance，但 section 名和字段名并不完全统一
  - `validate-isolation.sh` 仍按 verification / review 两套 key 分别读取
  - `harness-context.sh` 在 `ready_for_human_close` 只显示 artifact presence，不直接显示 provenance / verdict
- 当前校验规则:
  - `check-consistency.sh` 已能检查 isolation templates 和 `evaluation.md` reset
  - 还没有把“字段标准化 + validator + tests 覆盖”的联动收成更一般规则
- 现有隐式约束:
  - human 想看 verdict 需要主动打开 `evaluation.md`
  - provenance 字段变更时容易只改模板，不改 parser / tests

## 5. 现有测试

- 直接相关的测试:
  - `tests/test-validate-artifact.sh`
  - `tests/test-validate-isolation.sh`
  - `tests/test-harness-context.sh`
- 附近可复用的测试:
  - `tests/test-start-task.sh`
  - `tests/test-install-hooks.sh`
- 未找到可用测试:
  - 专门覆盖 “provenance 字段名必须固定” 的 consistency invariant

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 是，SessionStart context 和 validators 会受影响
- 这次改动是否可能触及迁移或 schema?
  - 是，`verification-path.md` / `evaluation.md` 的 provenance section 会收敛
- 这次改动是否可能跨业务域?
  - 否，集中在 harness core

## 7. 变更形态

- 这看起来像:
  - 一次中等规模的 schema hardening + status surface polish
- 预计文件数:
  - 12-16 个
- 推荐实现深度:
  - 中等；优先做共享 provenance 契约和 consistency invariant，不做更重 telemetry

## 8. 未决问题

- provenance section 是否统一成同一个英文 section 名，还是允许 verification / evaluation 保持不同 section 但字段相同？
- human-close surface 是否只展示 evaluator verdict，还是同时展示 verifier/evaluator 的 mode + context？

## 9. 建议

- 是否继续?
  - 是
- 建议下一步:
  - 先把 provenance section 与字段收成一个标准
  - 再让 `validate-isolation.sh` 和 `harness-context.sh` 共用同一套 reader
  - 最后把 coupling 规则补进 `check-consistency.sh`

# Verification Path: provenance-standardization-hardening

**Owner**: `verification-explorer`  
**状态**: `draft`

## 1. 计划检查项

- Build: 无额外构建步骤，直接验证脚本与 harness 状态。
- 测试: 覆盖 artifact schema、isolation、harness context、start-task、consistency。
- 静态检查: 通过 `check-consistency.sh` 做耦合与模板一致性检查。
- 运行时 / 手工检查: 读取 live `.harness/`，确认 provenance 与状态 surface 可见。

## 2. 精确命令

```text
bash tests/test-validate-artifact.sh
bash tests/test-validate-isolation.sh
bash tests/test-harness-context.sh
bash tests/test-start-task.sh
bash spec/bootstrap/check-consistency.sh
```

## 3. 前置条件

- 工具链: `bash`、`sed`、`grep`、`awk`、`jq`、标准 GNU/BSD coreutils。
- 服务: 无外部服务依赖。
- 夹具 / 测试数据: 依赖仓库内 `tests/` 的临时目录与 live `.harness/`。
- 环境变量: 无必需环境变量；在仓库根目录执行。

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: 已实际执行五个焦点命令，结果均通过；`test-validate-artifact.sh` 8/8 passed，`test-validate-isolation.sh` 6/6 passed，`test-harness-context.sh` 17/17 passed，`test-start-task.sh` 6/6 passed，`check-consistency.sh` 全部 invariant OK。
- Fallback policy: 仅在 strict 路径不可运行时，才转为显式记录的兼容回退路径；本次不启用回退。
- Fallback reason: strict 路径可用且验证已通过。

## 5. Dry-Run 结果

- 命令: `bash tests/test-validate-artifact.sh`
- 结果: 通过，8/8 passed。
- 备注: artifact schema 的 verification-path / evaluation / zh headings 校验通过。

- 命令: `bash tests/test-validate-isolation.sh`
- 结果: 通过，6/6 passed。
- 备注: strict、compat 与 ready_for_human_close 的 isolation 规则均符合预期。

- 命令: `bash tests/test-harness-context.sh`
- 结果: 通过，17/17 passed。
- 备注: human-close context 已能显示 verifier provenance 与 evaluator verdict。

- 命令: `bash tests/test-start-task.sh`
- 结果: 通过，6/6 passed。
- 备注: start-task 会重置 `evaluation.md`，且旧版 task-status 兼容正常。

- 命令: `bash spec/bootstrap/check-consistency.sh`
- 结果: 通过，全部 invariant OK。
- 备注: provenance contract、模板、reader 和 tests 的联动一致性成立。

## 6. 阻塞项

- none

## 7. 回退方案

- 如果主路径失败: 先检查 live `.harness/verification-path.md` 是否仍使用旧 provenance 字段，再按 `spec/bootstrap/provenance.sh` 的共享读取约定修正。
- 如果测试模块不可用: 退回到 `spec/bootstrap/check-consistency.sh` 与单个验证脚本的最小集，优先确认 schema 与 isolation reader。
- 如果仓库当前 build 已损坏: 只记录阻塞原因，不扩写其他 artifact，等待生成或 reviewer 修复 build / state 问题。

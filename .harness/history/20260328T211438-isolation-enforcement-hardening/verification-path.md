# Verification Path: isolation-enforcement-hardening

**Owner**: `verification-explorer`  
**Status**: `draft`

## 1. 计划检查项

- 构建:
  - 仓库当前不依赖额外编译产物，验证重点是脚本与工件契约一致性
- 测试:
  - `bash tests/test-validate-artifact.sh`
  - `bash tests/test-validate-state-artifacts.sh`
  - `bash tests/test-validate-isolation.sh`
  - `bash tests/test-install-hooks.sh`
- 静态检查:
  - `bash spec/bootstrap/check-consistency.sh`
- 运行时 / 手工检查:
  - 检查 `.harness/verification-path.md` 是否包含 isolation provenance
  - 检查 `.harness/evaluation.md` 是否在 human-close 前被要求并记录 verdict
  - 检查 hook 配置是否包含 isolation validation

## 2. 精确命令

```text
bash tests/test-validate-artifact.sh
bash tests/test-validate-state-artifacts.sh
bash tests/test-validate-isolation.sh
bash tests/test-install-hooks.sh
bash spec/bootstrap/check-consistency.sh
```

## 3. 前置条件

- 工具链:
  - `bash`
  - `jq`
  - `git`
- 服务:
  - 无外部服务依赖
- 夹具:
  - 测试脚本使用临时目录与仓库内工件
- 环境变量:
  - 无必需环境变量

## 4. Isolation Plan

- Verification mode: `strict`
- Execution context: `isolated_subagent`
- Fallback policy: `主路径失败时阻断，不接受静默 sequential_fallback`
- Fallback reason: `none`

## 5. Dry-Run Result

- Command:
  - `bash tests/test-validate-artifact.sh`
  - `bash tests/test-validate-state-artifacts.sh`
  - `bash tests/test-validate-isolation.sh`
  - `bash tests/test-install-hooks.sh`
  - `bash spec/bootstrap/check-consistency.sh`
- Result:
  - 上述命令已实际执行并通过；此外 live `.harness/` 也通过了 `validate-artifact.sh verification-path`, `validate-state-artifacts.sh`, 与 `validate-isolation.sh`
- Notes:
  - `install-hooks.sh` 为更新当前仓库 `.codex/hooks.json` 需要一次提权重跑
  - 该路径覆盖了 strict / compat 语义、`ready_for_human_close` 前的 `evaluation.md` gate，以及 stop hook 中的 isolation enforcement

## 6. 阻塞项

- none

## 7. 回退方案

- 如果主路径失败:
  - 先拆分到单个 test script，定位是 artifact schema、state gating 还是 hook 绑定问题
- 如果测试模块不可用:
  - 保留 `spec/bootstrap/check-consistency.sh` 与人工核对 `.harness/verification-path.md` / `.harness/evaluation.md`
- 如果仓库当前 build 已损坏:
  - 该任务不依赖完整构建链，优先验证 shell 测试与 bootstrap 脚本

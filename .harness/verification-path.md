# Verification Path: bootstrap-structure-rationalization

**Owner**: `verification-explorer`  
**状态**: `approved`

## 1. 计划检查项

- Build:
  - 无单独 build；本任务是 shell tooling / docs / tests 重整
- 测试:
  - `bash tests/test-prepare-review.sh`
  - `bash tests/test-install-hooks.sh`
  - `bash tests/test-start-task.sh`
  - `bash tests/test-task-status.sh`
  - `bash tests/test-hook-post-artifact.sh`
  - `bash tests/test-hook-pre-transition.sh`
  - `bash tests/test-hook-session-start.sh`
  - `bash tests/test-hook-stop-check.sh`
  - `bash tests/test-hook-subagent-stop.sh`
  - `bash tests/test-skill-links.sh`
  - `bash tests/test-validate-isolation.sh`
- 静态检查:
  - `bash spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir spec/bootstrap`
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
- 运行时 / 手工检查:
  - 从 live `.codex/hooks.json` 提取并执行真实 `SessionStart` hook command
  - 检查 `install-hooks.sh --print-manifest` 与 live `.codex/hooks.json` / `.claude/settings.json` 无 drift

## 2. 精确命令

```text
bash spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir spec/bootstrap
bash tests/test-prepare-review.sh
bash tests/test-install-hooks.sh
bash tests/test-validate-isolation.sh
bash tests/test-start-task.sh
bash tests/test-task-status.sh
bash tests/test-hook-post-artifact.sh
bash tests/test-hook-pre-transition.sh
bash tests/test-hook-session-start.sh
bash tests/test-hook-stop-check.sh
bash tests/test-hook-subagent-stop.sh
bash tests/test-skill-links.sh
bash spec/bootstrap/check-consistency.sh
bash spec/bootstrap/check-root-readme-bilingual.sh
cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command | select(test("baton-harness-context"))][0] // empty' .codex/hooks.json) && eval "$cmd"
```

## 3. 前置条件

- 工具链:
  - `bash`
  - `git`
  - `jq`
- 服务:
  - none
- 夹具 / 测试数据:
  - tests 自带 `mktemp` 临时仓库夹具
- 环境变量:
  - 无强制要求

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: 019d3a10-495a-7ca3-943e-e6355ea5e3fb
- Evidence: 通过 Codex `spawn_agent({ fork_context: false })` 启动独立 verifier 子代理，并由其冷读 `.harness/requirements.md`、`.harness/architecture.md`、`.harness/task-status.md`、实现面与 tests，独立复跑 focused verification commands、`prepare-review.sh`，以及一条从 `.codex/hooks.json` 提取的真实 SessionStart hook 命令。
- Fallback policy: strict 路径已可用并已执行；未来如果无法提供隔离 verifier，应阻塞 gate，而不是默认退回 compat。
- Fallback reason: none

## 5. Dry-Run 结果

- 命令:
  - `bash spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir spec/bootstrap`
  - `bash tests/test-prepare-review.sh`
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash tests/test-install-hooks.sh`
  - `bash tests/test-skill-links.sh`
  - `bash tests/test-validate-isolation.sh`
  - `bash tests/test-start-task.sh`
  - `bash tests/test-task-status.sh`
  - `bash tests/test-harness-context.sh`
  - `bash tests/test-validate-artifact.sh`
  - `bash tests/test-validate-state-artifacts.sh`
  - `bash tests/test-validate-transition.sh`
  - `bash tests/test-hook-session-start.sh`
  - `bash tests/test-hook-stop-check.sh`
  - `bash tests/test-hook-post-artifact.sh`
  - `bash tests/test-hook-pre-transition.sh`
  - `bash tests/test-hook-subagent-stop.sh`
  - `rg --files spec/bootstrap -g '*.ps1'`
  - `cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command' .codex/hooks.json) && printf 'HOOK_CMD=%s\n' "$cmd" && eval "$cmd"`
- 结果:
  - `prepare-review.sh`: pass，已刷新 live hooks、跑过 bilingual README / consistency checks，并执行真实 SessionStart hook smoke check
  - `tests/test-prepare-review.sh`: pass，5/5
  - `check-root-readme-bilingual.sh`: pass
  - `check-consistency.sh`: pass，invariants 1-16 全部通过
  - `tests/test-install-hooks.sh`: pass，49/49
  - `tests/test-skill-links.sh`: pass，10/10
  - `tests/test-validate-isolation.sh`: pass，8/8
  - `tests/test-start-task.sh`: pass，6/6
  - `tests/test-task-status.sh`: pass，11/11
  - `tests/test-harness-context.sh`: pass，18/18
  - `tests/test-validate-artifact.sh`: pass，12/12
  - `tests/test-validate-state-artifacts.sh`: pass，14/14
  - `tests/test-validate-transition.sh`: pass，12/12
  - `tests/test-hook-session-start.sh`: pass，2/2
  - `tests/test-hook-stop-check.sh`: pass，2/2
  - `tests/test-hook-post-artifact.sh`: pass，5/5
  - `tests/test-hook-pre-transition.sh`: pass，6/6
  - `tests/test-hook-subagent-stop.sh`: pass，5/5
  - `rg --files spec/bootstrap -g '*.ps1'`: expected no matches，exit 1，确认 `.ps1` 业务入口已全部移除
  - `.codex/hooks.json` 中提取并执行的 SessionStart hook command: pass，exit 0，返回有效 JSON
- 备注:
  - `prepare-review.sh` 现在把 hooks refresh、consistency check 和 live SessionStart smoke check 做成了统一入口
  - live `.codex/hooks.json` / `.claude/settings.json` 现在被当作本次改动的一部分，并通过 invariant-16 与 `install-hooks.sh --print-manifest` 保持对齐
  - Windows 路径本轮通过 `tests/test-install-hooks.sh` 中的 `run-hook.cmd` / `cmd /d /c` 断言做了结构级验证，但仍未替代真实 Windows 主机 smoke test

## 6. 阻塞项

- none

## 7. 回退方案

- 如果主路径失败:
  - 先运行 `tests/test-install-hooks.sh`、`tests/test-start-task.sh`、`tests/test-hook-*.sh` 这类最直接相关测试定位 breakage
- 如果测试模块不可用:
  - 至少运行 `check-consistency.sh` 和关键命令的 dry-run / generated-output 断言
- 如果仓库当前 build 已损坏:
  - 记录为 `[environment_blocker]`，并区分“现有基线已坏”与“本次重整引入回归”

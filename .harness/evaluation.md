# Evaluation: bootstrap-structure-rationalization

**Owner**: `evaluator`  
**状态**: `final`

## 1. Inputs

- Requirements: 冷读 `.harness/requirements.md`，重点复核新增 guardrails 后的 FR-1 到 FR-9 与 AC-1 到 AC-8。
- Architecture: 冷读 `.harness/architecture.md`，确认落地结构、strict provenance、hook drift detection 与 `prepare-review.sh` 都与批准方案一致。
- Verification path: 冷读 `.harness/verification-path.md`，确认 strict verifier 已记录 `isolated_subagent` 与 `Agent ID`。
- Diff / changed files:
  - `spec/bootstrap/commands/`
  - `spec/bootstrap/lib/`
  - `spec/bootstrap/hooks/`
  - 顶层 `spec/bootstrap/*.sh` wrappers 与新增 `prepare-review.sh`
  - `spec/bootstrap/*.md`、`spec/README.md`
  - `spec/templates/` 与 `spec/templates/zh/`
  - `skills/baton-verifier/SKILL.md`、`skills/baton-evaluator/SKILL.md`
  - `.claude/settings.json`、`.codex/hooks.json`
  - `tests/test-install-hooks.sh`、`tests/test-prepare-review.sh`、`tests/test-validate-isolation.sh` 及相关 hook / validator tests
  - 删除的 `spec/bootstrap/*.ps1`

## 2. Execution Provenance

- Role: evaluator
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: 019d3a10-4967-76d3-b2a4-fb9c01464e75
- Evidence: 通过 Codex `spawn_agent({ fork_context: false })` 启动独立 evaluator 子代理，并由其冷读 `.harness/requirements.md`、`.harness/architecture.md`、`.harness/verification-path.md`、`.harness/module-status.md`、当前 working-tree 实现面与 focused tests；同时将已刷新后的 `.claude/settings.json` / `.codex/hooks.json` 视为本次改动的一部分进行评审。
- Fallback policy: strict 路径已可用并执行；若未来无法提供隔离子代理或无法记录 Agent ID，应阻塞 review gate，而不是再用 compat 结果充当最终评审。
- Fallback reason: none

## 3. Findings

- Blockers: none
- Warnings:
  - none
- No findings:
  - 目录已清晰分层为顶层 wrappers、`commands/`、`lib/`、`hooks/`，符合批准架构。
  - bootstrap 核心已收敛到单一 bash 实现；`spec/bootstrap/*.ps1` 业务入口已删除，并由 invariant-15 防回退。
  - strict review provenance 已收紧：templates 含 `Agent ID`，`validate-isolation.sh` 会阻断缺失 `isolated_subagent` 或缺失 `Agent ID` 的 strict artifacts。
  - verifier / evaluator skills 已把 `spawn_agent({ fork_context: false })` 与 `Agent ID` 记账写成默认且不可静默降级的执行要求。
  - `install-hooks.sh --print-manifest` 已提供机器可读真源，`check-consistency.sh` 的 invariant-16 会把 live `.claude/settings.json` / `.codex/hooks.json` 与当前 manifest 做真实 drift 比对。
  - `prepare-review.sh` 已把 hooks refresh、consistency checks、live SessionStart smoke check 和 isolated review handoff 指引收敛成可执行入口。

## 4. Verification Results

- `bash spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir spec/bootstrap` -> pass
- `bash spec/bootstrap/check-consistency.sh` -> pass（invariants 1-16）
- `bash tests/test-prepare-review.sh` -> pass（5/5）
- `bash tests/test-validate-isolation.sh` -> pass（8/8）
- `bash tests/test-install-hooks.sh` -> pass（49/49）
- `bash tests/test-skill-links.sh` -> pass（10/10）
- `bash tests/test-start-task.sh` -> pass（6/6）
- `bash tests/test-module-status.sh` -> pass（11/11）
- `bash tests/test-harness-context.sh` -> pass（18/18）
- `bash tests/test-validate-artifact.sh` -> pass（12/12）
- `bash tests/test-validate-transition.sh` -> pass（12/12）
- `bash tests/test-validate-state-artifacts.sh` -> pass（14/14）
- `bash tests/test-hook-session-start.sh` -> pass（2/2）
- `bash tests/test-hook-stop-check.sh` -> pass（2/2）
- `bash tests/test-hook-post-artifact.sh` -> pass（5/5）
- `bash tests/test-hook-pre-transition.sh` -> pass（6/6）
- `bash tests/test-hook-subagent-stop.sh` -> pass（5/5）
- `root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; BATON_BOOTSTRAP="$root/spec/bootstrap" bash "$root/spec/bootstrap/hooks/session-start" # baton-harness-context` -> pass，exit 0，返回有效 SessionStart hook JSON

## 5. Verdict

- Verdict: PASS
- Acceptance criteria status:
  - AC-1 单一实现落地: met
  - AC-2 目录职责清晰: met
  - AC-3 Windows 路径可执行: met at structure/test level
  - AC-4 外部入口不被静默破坏: met
  - AC-5 测试面覆盖新结构: met
  - AC-6 strict review gate 无法被 compat 结果伪装通过: met
  - AC-7 hook 本地配置漂移可自动暴露: met
  - AC-8 review preparation 入口可跑通: met

## 6. Residual Risks

- 尚未在真实 Windows 主机上做 live smoke test；当前仅能确认 Git Bash / `run-hook.cmd` 路径在仓库级测试、manifest drift check 和生成命令层面成立。

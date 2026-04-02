# Verification Path: runtime-enforcement-hardening

**Owner**: `verification-explorer`
**状态**: `approved`

## 1. 计划检查项

- Hook 提取与 clean switch:
  - 验证 `install-hooks.sh` 可执行，并且在变更后生成的 `.claude/settings.json` / `.codex/hooks.json` 只引用 `spec/bootstrap/hooks/*.sh` 薄调用。
  - 覆盖 FR-1、FR-2、FR-9、AC-1 到 AC-5。
- 运行时 enforcement 逻辑:
  - 通过 `tests/test-hook-parse-input.sh`、`tests/test-hook-pre-transition.sh`、`tests/test-hook-post-artifact.sh`、`tests/test-hook-stop-check.sh`、`tests/test-hook-subagent-stop.sh`、`tests/test-hook-session-start.sh` 覆盖宿主识别、blocked 分类、人类门控、ack 清除、eval round、自循环防护、BATON_DEBUG。
  - 覆盖 FR-1、FR-3、FR-4、FR-7、FR-8、FR-11、AC-6 到 AC-8、AC-12 到 AC-21。
- 现有 bootstrap 回归:
  - 运行 `tests/test-install-hooks.sh`、`tests/test-task-status.sh`、`tests/test-validate-artifact.sh`、`tests/test-validate-state-artifacts.sh`、`tests/test-validate-isolation.sh`、`tests/test-harness-context.sh`。
  - 覆盖 FR-5、FR-6、FR-8、FR-13、AC-9 到 AC-11、AC-15、AC-20、AC-22。
- 静态与一致性检查:
  - 运行 `spec/bootstrap/check-consistency.sh`。
  - 运行 `shellcheck` 覆盖新增 hooks 脚本与相关 bootstrap 脚本。
  - 用 `rg` / `test` 检查 generator-feedback 模板提升、旧模板删除、skill 指导文字、overlay 推荐输出。
  - 覆盖 FR-5、FR-8、FR-10、FR-12、FR-13、AC-9、AC-10、AC-16 到 AC-20。

## 2. 精确命令

```text
bash spec/bootstrap/install-hooks.sh --repo-root . --bootstrap-dir spec/bootstrap --dry-run
bash tests/test-install-hooks.sh
bash tests/test-task-status.sh
bash tests/test-validate-artifact.sh
bash tests/test-validate-state-artifacts.sh
bash tests/test-validate-isolation.sh
bash tests/test-harness-context.sh
bash spec/bootstrap/check-consistency.sh
command -v shellcheck
shellcheck -S error spec/bootstrap/install-hooks.sh spec/bootstrap/task-status.sh spec/bootstrap/validate-artifact.sh spec/bootstrap/validate-state-artifacts.sh spec/bootstrap/harness-context.sh spec/bootstrap/check-consistency.sh spec/bootstrap/hooks/*.sh spec/bootstrap/hooks/lib/parse-input.sh
bash tests/test-hook-parse-input.sh
bash tests/test-hook-pre-transition.sh
bash tests/test-hook-post-artifact.sh
bash tests/test-hook-stop-check.sh
bash tests/test-hook-subagent-stop.sh
bash tests/test-hook-session-start.sh
rg -n "generator-feedback|Original Assumption|原始假设|Recommended Next Owner|建议下一步负责方" spec/bootstrap/validate-artifact.sh spec/templates/generator-feedback.template.md spec/templates/zh/generator-feedback.template.md skills/baton-generator/SKILL.md
test ! -e spec/extensions/java-backend-strict/templates/generator-feedback.template.md
rg -n "Overlay Recommendation|overlay:[[:space:]]*(core|strict)" skills/baton-explorer/SKILL.md spec/bootstrap/harness-context.sh
```

## 3. 前置条件

- 工具链:
  - 已实测存在: `bash`、`jq`、`shellcheck`
  - 计划路径依赖: `rg`、`awk`、`sed`、`mktemp`、`grep`
- 服务: 无外部服务依赖
- 夹具 / 测试数据:
  - 仓库内 `tests/`
  - live `.harness/`
  - 生成器需补齐 `tests/test-hook-*.sh` 与 `spec/bootstrap/hooks/` 文件后再跑完整路径
- 环境变量:
  - 无必需环境变量
  - 当前仓库未提供 `.harness/profile.local.yaml`，因此 `verification_isolation_mode` 按默认值 `strict` 解释

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: 通过 Codex `spawn_agent({ fork_context: false })` 启动了独立 verifier，会话内冷读 `.harness/requirements.md`、`.harness/architecture.md`、`.harness/scoped-map.md`、`skills/baton-verifier/SKILL.md` 与相关 bootstrap/tests 文件；并实际执行了 `install-hooks.sh --dry-run`、`tests/test-install-hooks.sh`、`tests/test-task-status.sh`、`tests/test-validate-artifact.sh`、`tests/test-validate-state-artifacts.sh`、`tests/test-validate-isolation.sh`、`tests/test-harness-context.sh`、`check-consistency.sh`，同时确认 `shellcheck` 可用。
- Fallback policy: strict 路径已可用并已执行；若未来 strict 隔离不可用，则应阻塞而不是退化为未记录的顺序验证。
- Fallback reason: none

## 5. Dry-Run 结果

- 命令: `bash spec/bootstrap/install-hooks.sh --repo-root . --bootstrap-dir spec/bootstrap --dry-run`
- 结果: 通过，打印出将写入 `.claude/settings.json` 与 `.codex/hooks.json` 的 hook 命令。
- 备注: 当前基线仍是内联命令；这证明安装器链路可执行，但也说明 FR-9 的 clean switch 仍待实现。

- 命令: `bash tests/test-install-hooks.sh`
- 结果: 通过，42/42 passed。
- 备注: 现有 hook 安装回归链可运行，后续可以在同一入口上收紧断言为“薄调用脚本”。

- 命令: `bash tests/test-validate-artifact.sh`
- 结果: 通过，9/9 passed。
- 备注: 当前 artifact schema 校验器正常，但尚未覆盖 `generator-feedback`。

- 命令: `bash tests/test-validate-state-artifacts.sh`
- 结果: 通过，12/12 passed。
- 备注: 状态工件检查链路可执行，但 `complete` 仍未要求 `retrospective.md`，FR-6 尚未落地。

- 命令: `bash tests/test-validate-isolation.sh`
- 结果: 通过，6/6 passed。
- 备注: 当前 strict/compat 判定器正常，也正因为如此，本次 `strict + sequential_fallback` 不能被判成通过。

- 命令: `bash tests/test-task-status.sh`
- 结果: 通过，9/9 passed。
- 备注: `task-status.sh` 当前只有读路径基线；`task_status_set_eval_round()` 仍需新增并补测。

- 命令: `bash tests/test-harness-context.sh`
- 结果: 通过，17/17 passed。
- 备注: SessionStart 上下文链路正常，但尚未输出 overlay recommendation。

- 命令: `bash spec/bootstrap/check-consistency.sh`
- 结果: 通过，全部 invariants OK。
- 备注: 当前 11 个不变量健康；FR-13 新增的 3 个不变量还未加入。

- 命令: `shellcheck -S error spec/bootstrap/install-hooks.sh spec/bootstrap/task-status.sh spec/bootstrap/validate-artifact.sh spec/bootstrap/validate-state-artifacts.sh spec/bootstrap/harness-context.sh spec/bootstrap/check-consistency.sh spec/bootstrap/hooks/*.sh spec/bootstrap/hooks/lib/parse-input.sh`
- 结果: 通过。
- 备注: 当前 runtime 脚本在 error 级别无 ShellCheck 发现；`SC1090/SC1091` 仅保留在非 error 级别。

## 6. 阻塞项

- none

## 7. 回退方案

- 如果 strict 隔离未来不可用: 保持 `blocked`，不要进入 `generating`；先恢复真实 `isolated_subagent` 或新会话验证能力。
- 如果测试模块不可用: 先区分是测试基础设施损坏还是实现缺陷；前者记为 `[environment_blocker]`，后者由 Generator 修复后回到同一验证路径。
- 如果仓库当前 build 已损坏: 不扩写实现产物，先记录可复现命令和损坏面，再决定回 Architect 还是直接修基础设施。

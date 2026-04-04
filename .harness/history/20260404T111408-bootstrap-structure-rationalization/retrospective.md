# Retrospective: bootstrap-structure-rationalization

## 1. 结果

- 关闭状态: complete
- 主要阻塞: 无实现级阻塞；中途发现 review gate 被 compat 评审和 stale local hooks 配置绕过，需要回退状态重做 verifier / evaluator
- 人工决策: 接受 Baton 继续以 `bash` 单核心 + Git Bash / launcher 作为 Windows 路径，并接受当前仍缺少真实 Windows 主机 smoke test 的残余风险

## 2. 有效做法

- 把 `spec/bootstrap` 分成顶层 wrappers、`commands/`、`lib/`、`hooks/` 后，职责边界明显更清楚
- 用 `install-hooks.sh --print-manifest` 生成机器可读真源，再由 `check-consistency.sh` 对 live `.claude/settings.json` / `.codex/hooks.json` 做 drift 对比，比写静态版本号更稳
- 新增 `prepare-review.sh` 把 hooks refresh、consistency、live SessionStart smoke check 和 isolated review handoff 变成可执行流程，降低了靠记忆走 gate 的风险

## 3. 失败点

- 一开始把 isolated verifier / evaluator 当成可后补的“增强项”，没有主动按 strict gate 执行，这是流程判断错误
- hooks handler 改名后，只靠测试没有立刻暴露 live `.codex/hooks.json` 仍指向旧 `*.sh` 的问题；需要把 live config freshness 纳入一致性检查
- `install-harness.sh` 复用共享 `paths_relpath_from()` 时参数顺序写反，导致 vendored skill 链接回归；共享 helper 收敛后仍要靠测试兜住调用约定

## 4. 仓库特定经验

- 这个仓库里 `.claude/settings.json` 和 `.codex/hooks.json` 不是纯本地噪声；当 hook runtime 变更时，它们需要被视为真实实现面的一部分
- `spec/bootstrap/check-consistency.sh` 已经是 protocol/runtime 边界的核心守门人，适合继续承载“防回退”类 invariant
- `prepare-review.sh` 这种 review 入口脚本更符合 Baton 的 protocol-first 定位：宿主负责 agent，runtime 负责把进入 gate 前的环境准备标准化

## 5. Harness 经验

- strict 模式不能只写 `Isolation mode: strict`；必须把 `Execution context: isolated_subagent` 和 `Agent ID` 一并做成 validator 可审计字段
- 当流程强调独立判断时，compat 结果不应允许临时充当最终 gate 产物；否则人很容易顺着“先跑通再说”的惯性滑过去
- “live generated config 是否仍是当前真相”是 hook 系统的一类独立风险，需要专门的 freshness guard，而不是靠实现测试间接覆盖

## 6. 可标准化候选

- 保留 `prepare-review.sh` 作为所有 Baton 任务进入 verifier / evaluator 前的标准入口
- 保留 `Agent ID` 作为 strict verifier / evaluator artifact 的强制 provenance 字段
- 保留 invariant-16 这类 “manifest vs live config” drift 检查，未来如扩到其他 generated runtime files 也沿用同一模式

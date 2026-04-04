# Scoped Map: bootstrap-structure-rationalization

**需求**: 重新梳理 `spec/bootstrap` 的目录与跨平台运行策略，去掉 `sh` / `ps1` 双核心维护，收敛为单一 `bash` 核心加 Windows 薄适配层。  
**领域**: harness bootstrap runtime / tooling layout / cross-platform entry design  
**Owner**: `scoped-explorer`  
**状态**: `draft`

## 1. 范围

- 范围内:
  - `spec/bootstrap` 目录分层
  - `install-harness` / `init-harness` / `start-task` / `install-hooks` 等公共入口的职责拆分
  - Windows 支持策略是否从 `.ps1` 双实现收敛到 `bash` 单核心 + launcher
  - hooks 入口命名与安装方式
  - 与上述变更直接耦合的测试和文档
- 范围外:
  - `spec/protocol` 状态机和 gate 规则本身
  - `.harness` artifact schema 内容定义
  - skills 内容与业务工作流语义
  - 新增 Python 运行时或其它新语言核心
- 预期写入边界:
  - `spec/bootstrap/**`
  - `tests/**`
  - `spec/README.md`
  - `README.md`
  - `README.zh-CN.md`

## 2. 入口点

- 主要入口类或文件:
  - `spec/bootstrap/install-harness.sh`
  - `spec/bootstrap/init-harness.sh`
  - `spec/bootstrap/start-task.sh`
  - `spec/bootstrap/install-hooks.sh`
  - `spec/bootstrap/link-skills.sh`
  - `spec/bootstrap/sync-skills.sh`
  - `spec/bootstrap/sync-governance-entrypoints.sh`
  - `spec/bootstrap/check-consistency.sh`
  - `spec/bootstrap/hooks/*`
- 涉及的方法、API、命令或脚本:
  - vendored repo 安装路径引用
  - `.claude/settings.json` / `.codex/hooks.json` / `.codex/config.toml` 写入逻辑
  - `.harness/task-status.md` 初始化与状态读取
  - docs 中公开暴露的 shell / PowerShell 调用示例
- 这些入口为什么相关:
  - 它们共同构成当前 bootstrap 的公共表面
  - 目录重整若破坏这些入口，会直接影响 README、vendored 安装流和 hooks 运行
  - `install-hooks.sh` 当前把跨平台策略和 hook 注册逻辑绑死在 `bash + .sh` 命名上，是 Windows 路径设计的关键锚点

## 3. 调用链

```text
public bootstrap command
  -> shell implementation in spec/bootstrap top level
  -> shared helpers or inline duplicated logic
  -> file writes under .harness / .vendor / runtime config
  -> install-hooks.sh writes host hook config
  -> host hook command runs spec/bootstrap/hooks/*.sh
  -> hook script sources hook lib + bootstrap validators/helpers
  -> validator/helper inspects artifacts and may block session flow
```

## 4. 现有行为

- 当前可观察行为:
  - `spec/bootstrap` 顶层同时混放公共入口、内部 helper、validator、sync 工具、hooks 文档和 PowerShell 对应实现
  - 同一逻辑在 `sh` 和 `ps1` 中重复维护，典型包括 language 解析、task-status 读取、template 解析
  - hooks 运行时统一调用 `bash .../hooks/*.sh`
  - `install-hooks.sh` 额外要求 `python3` 仅用于计算相对路径，不是业务核心
  - 文档和 `spec/README.md` 仍把 `.ps1` 作为正式入口公开暴露
- 当前校验规则:
  - `check-consistency.sh` 会检查 `start-task.ps1` / `start-task.sh` 对 `states.txt` 和 `evaluation.md` reset 的耦合
  - `tests/test-install-hooks.sh` 校验 hooks 写入 `.sh` 路径
  - 多个 shell tests 校验当前 shell 实现
- 现有隐式约束:
  - `spec/bootstrap/*.sh` 已经是对外稳定路径，文档和 vendored 引用大量依赖
  - README 是中英双语成对维护，任何根入口调整需要同时改两份
  - Windows 支持历史上通过 `.ps1` 与 link fallback 维持，但 hooks 路径本身已经偏向 bash

## 5. 现有测试

- 直接相关的测试:
  - `tests/test-install-hooks.sh`
  - `tests/test-start-task.sh`
  - `tests/test-task-status.sh`
  - `tests/test-hook-parse-input.sh`
  - `tests/test-hook-post-artifact.sh`
  - `tests/test-hook-pre-transition.sh`
  - `tests/test-hook-session-start.sh`
  - `tests/test-hook-stop-check.sh`
  - `tests/test-hook-subagent-stop.sh`
  - `tests/test-skill-links.sh`
- 附近可复用的测试:
  - `tests/test-validate-artifact.sh`
  - `tests/test-validate-transition.sh`
  - `tests/test-validate-isolation.sh`
  - `tests/test-validate-state-artifacts.sh`
- 未找到可用测试:
  - 几乎没有覆盖 `.ps1` 实际行为的对等测试
  - 当前没有显式的 Windows launcher 行为测试

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 是。会触及 Claude Code / Codex hooks 配置写入，以及 vendored bootstrap 入口路径。
- 这次改动是否可能触及迁移或 schema?
  - 否。不会改数据库、迁移或 artifact schema。
- 这次改动是否可能跨业务域?
  - 低。主要集中在 harness runtime/tooling 层，但会波及根文档与安装说明。

## 7. 变更形态

- 这看起来像:
  - 工具层架构重整
  - 公共入口兼容层保留
  - 跨平台策略收敛
  - 文档与测试同步调整
- 预计文件数:
  - Medium 到 Large，约 15-30 个文件会改动或迁移
- 推荐实现深度:
  - 不是最小重排；应一次性解决目录分层、重复逻辑抽取、Windows 启动策略和 `.ps1` 退场路径

## 8. 未决问题

- Windows 支持是否正式改为“需要 Git Bash / Git for Windows”，不再承诺纯 PowerShell 一等运行?
- `.ps1` 是立即删除，还是保留一个版本周期的 deprecation wrapper?
- hooks 是否改成 `superpowers` 风格的无扩展名 handler + `run-hook.cmd` launcher?

## 9. 建议

- 是否继续?
  - 继续。这已经不是视觉整洁问题，而是维护模型错误：当前存在双核心漂移风险和目录职责混杂。
- 建议下一步:
  - 固化 requirements，明确“不引入 Python、单一 bash 核心、Windows 薄适配、保留稳定公共入口”四条边界，然后进入 architecture 评估。

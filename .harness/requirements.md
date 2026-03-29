# Requirements: bootstrap-structure-rationalization

**主题**: `spec/bootstrap` 结构重整与跨平台入口收敛  
**状态**: `draft`  
**规模**: `Large`

## 1. 问题

当前 `spec/bootstrap` 把公共入口、内部共享逻辑、validator、hooks 运行时、同步工具、PowerShell 对应实现混放在同一层，导致：

- 入口发现成本高，用户和维护者都难以判断哪些是公共接口、哪些是内部实现
- 相同逻辑在 `sh` 与 `ps1` 中重复维护，产生漂移风险
- Windows 支持策略不清晰，既维护 `.ps1`，又在 hooks 路径上依赖 `bash`
- 文档、测试和实现同时依赖这些混杂路径，使后续演进成本越来越高

## 2. 范围

### 2.1 范围内

- 重整 `spec/bootstrap` 目录分层
- 收敛 bootstrap 核心实现到单一语言实现
- 定义并实现 Windows 的运行/启动适配策略
- 保留或兼容现有公开 shell 入口路径
- 调整 hooks 安装与 handler 组织方式
- 更新与上述变更直接相关的测试与文档

### 2.2 范围外

- 修改 protocol state machine、gate 规则或 artifact schema
- 新增 Python 作为 bootstrap 核心运行时
- 重写 skills 内容
- 改动与 bootstrap 无直接关系的业务代码

## 3. 功能需求

### FR-1 单一核心实现

- bootstrap 运行时逻辑必须收敛为单一核心实现，不再长期维护 `sh` 和 `ps1` 两套完整业务逻辑。
- 该核心实现必须保持与现有 hooks 和 shell-first 工具链兼容。
- 本任务不得通过引入 Python 核心来完成收敛。

### FR-2 公共入口与内部实现分层

- `spec/bootstrap` 必须形成清晰分层，至少区分：
  - 稳定公共入口
  - 内部共享库
  - hooks runtime
  - 文档或命令说明
- 维护者应能快速识别哪些路径可被文档、vendored repo、外部调用依赖，哪些仅是内部实现细节。

### FR-3 公开路径兼容

- 现有对外公开的 shell 路径应继续可用，或提供明确且低破坏的兼容 wrapper。
- README、`spec/README.md`、bootstrap 文档中引用的入口应与最终结构一致。
- 任何删除或弃用 `.ps1` 的决定必须伴随文档说明，不允许保留失真文档。

### FR-4 Windows 支持策略明确

- 架构必须对 Windows 支持给出单一明确策略。
- 若不再以 `.ps1` 作为一等业务入口，必须提供可执行的 Windows 启动方式。
- hooks 相关入口必须考虑 Windows 路径、quoting 与 shell 启动问题。
- 本任务批准的 Windows 策略为: 以 Git for Windows / Git Bash 为前提，通过薄 launcher 调用唯一的 shell 核心实现；不再承诺纯 PowerShell 原生业务入口。

### FR-5 hooks 模型一致

- hooks 的 handler 组织方式应与统一核心实现一致，不应继续额外维护一套平台分叉逻辑。
- hook 安装脚本输出的命令串必须与新目录结构匹配，并保持可测试性。

### FR-6 测试与校验同步

- 现有 shell tests 必须随结构重整同步更新。
- 新的 Windows 启动/launcher 路径需要有至少基础的行为断言。
- `check-consistency.sh` 如仍存在，应反映新的真实结构和兼容边界。

### FR-7 review gate 必须强制隔离并可审计

- `verification-path.md` 和 `evaluation.md` 在 strict 模式下必须明确记录 `isolated_subagent`，不能仅靠 compat / sequential fallback 进入最终 review gate。
- strict 模式下必须保留可审计的 agent 身份字段，用于证明该 artifact 来自哪次隔离 verifier / evaluator 执行。
- verifier / evaluator 的技能指令必须把 `spawn_agent(..., fork_context: false)` 作为默认且优先的执行方式；若做不到，应显式 block，而不是静默降级。

### FR-8 本地 hook 运行配置必须可检测漂移

- `.codex/hooks.json` 与 `.claude/settings.json` 如果存在，必须能够检查它们是否与当前 `install-hooks.sh` 生成结果一致。
- 漂移检查不能只验证“文件存在”；应能够发现 handler 路径、command string 或 launcher 语义已经落后于当前实现。
- 对 hooks / `install-hooks.sh` 的重构，必须能通过自动检查暴露“本地安装结果已过期”的问题。

### FR-9 review 准备步骤必须可执行而非只靠记忆

- 仓库内必须提供一个 review preparation 入口，用于在进入 isolated verifier / evaluator 之前执行必要的 runtime 刷新和本地 smoke checks。
- 该入口至少要完成：刷新本地 hooks 配置、校验一致性、执行一条从生成配置提取出的真实 hook 命令、输出后续 isolated review 指引。
- 该入口不要求直接启动 agent，但必须让“进入 review gate 前该做什么”成为可执行命令，而不是口头约定。

## 4. 非目标

- 不追求“零改动”最小方案
- 不保留长期双核心实现作为过渡常态
- 不引入 Python 以简化跨平台问题
- 不在本任务中设计新的 protocol 能力

## 5. 验收标准

### AC-1 单一实现落地

- bootstrap 不再存在 `.sh` 与 `.ps1` 两套完整业务实现并行维护的状态。
- 核心逻辑只有一份权威实现。

### AC-2 目录职责清晰

- `spec/bootstrap` 的目录结构能明显区分公共入口、共享库、hooks runtime 和文档。
- 顶层不再同时混放大量内部 helper 与公开命令实现。

### AC-3 Windows 路径可执行

- 在不依赖 `.ps1` 业务实现的前提下，Windows 仍有明确可执行路径。
- hooks 安装后的命令串不依赖 Unix-only quoting 假设。
- 文档明确说明 Windows 运行前提为 Git Bash 或等效 launcher。

### AC-4 外部入口不被静默破坏

- 现有 shell 公共入口仍能调用到最终实现，或有明确兼容层。
- 文档中的安装与启动示例与仓库真实结构一致。

### AC-5 测试面覆盖新结构

- 直接相关的 bootstrap / hooks tests 在新结构下可运行。
- 至少包含对 launcher / hook command string 的断言。

### AC-6 strict review gate 无法被 compat 结果伪装通过

- strict 模式下，缺少 `isolated_subagent` 或缺少 agent 身份字段的 `verification-path.md` / `evaluation.md` 必须被 `validate-isolation.sh` 阻断。
- `ready_for_human_close` 不得建立在 compat review artifact 之上。

### AC-7 hook 本地配置漂移可自动暴露

- 当 `.codex/hooks.json` / `.claude/settings.json` 落后于当前 `install-hooks.sh` 生成结果时，`check-consistency.sh` 必须失败。
- 漂移检查至少覆盖 Baton 管理的 hook entries，而不是只检查文件存在。

### AC-8 review preparation 入口可跑通

- 新增的 review preparation 命令可在当前仓库执行成功。
- 它能够刷新 hooks、本地执行至少一条真实生成 hook 命令，并给出 isolated verifier / evaluator 的下一步指引。

## 6. 约束

- 必须遵守 harness flow，在 architecture 获得人工确认前不进入代码生成
- 不新增 Python 核心依赖
- Windows 运行前提允许要求 Git Bash / Git for Windows
- 根入口文档是中英双语对，若涉及根 README 变更必须同时更新两份
- `spec/bootstrap/*.sh` 已是外部可见接口，需要兼容意识
- 当前 hooks 和测试体系以 shell 为主，重整方向不能与之冲突

## 7. 验证意图

- 通过 artifact 评审确认目录、兼容、Windows 路径和 hooks 模型都被显式设计
- 通过 shell tests 和 consistency checks 证明新结构可运行且无文档漂移
- 通过 reviewer/evaluator 检查确认没有保留新的双实现或隐藏平台分叉

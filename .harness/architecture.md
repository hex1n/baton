# Architecture: bootstrap-structure-rationalization

**主题**: `spec/bootstrap` 目录重整与单核心跨平台 bootstrap runtime  
**状态**: `approved`  
**规模**: `Large`

## 1. 问题

`spec/bootstrap` 当前同时承担公共命令入口、共享 helper、validator、hooks runtime、同步工具和 PowerShell 对应实现，已经形成职责混杂。更关键的是，`sh` 和 `ps1` 两套业务实现并存，而 hooks 与测试体系实际上已经明显偏向 shell-first 运行模型，导致 Windows 支持方式和维护模型彼此冲突。

## 2. 第一性原理拆解

### 2.1 问题陈述

需要把 bootstrap 系统整理成：

- 只有一套权威实现
- 目录职责清晰
- 外部公开入口保持稳定
- Windows 仍可运行
- hooks 与 tests 不再围绕两套实现分叉

### 2.2 约束

- 不引入 Python 作为新的核心运行时
- 在 architecture 获得人工批准前不进入代码生成
- 现有 `spec/bootstrap/*.sh` 已经被文档和外部路径依赖，不能粗暴删除
- Windows 支持必须有明确策略，不能只留下“理论可做”
- hooks 继续要兼容 Claude Code / Codex 的现有安装模型
- 需要尽量减少文档漂移和测试失真

### 2.3 方案类别

- 方案 A: `bash` 单核心 + 顶层兼容 wrapper + Windows launcher（借鉴 superpowers）
- 方案 B: Python 单核心 + `sh` / `ps1` wrapper
- 方案 C: 保留 `sh` / `ps1` 双实现，只做目录重排和局部抽 helper

### 2.4 评估

- 为什么方案 A 胜出:
  - 与现有 hooks、tests、shell-first 生态一致，变更方向最自然
  - 可以像 `superpowers` 一样，把 Windows 兼容压缩到薄启动层，而不是维护第二套业务实现
  - 可以同时解决目录分层、双实现漂移、Windows 路径不清、hooks quoting 这四个问题
  - 不需要引入 Python，也不再依赖 `python3` 仅为 `relpath` 这类小事服务
- 为什么拒绝方案 B:
  - 虽然能形成单核心，但与用户明确偏好冲突
  - 会把当前 shell-first hooks/runtime 体系再绕一层解释和依赖
  - Baton 的目标不是做一个多语言 runtime platform；这里引入 Python 的收益不足以覆盖额外依赖和认知成本
- 为什么拒绝方案 C:
  - 只是视觉整理，不解决长期维护风险
  - `sh` / `ps1` 漂移问题会继续积累
  - 目录整齐后仍会保留双核心事实，属于“更好看的错误模型”

## 3. 推荐架构

- 方法:
  - 采用 `bash` 单核心，删除 `.ps1` 业务实现
  - 保留现有顶层 `spec/bootstrap/*.sh` 作为稳定公共入口，但它们只做 thin wrapper
  - 新增分层目录承载真实实现、共享库和 hooks runtime
  - 为 Windows 增加极薄 launcher，要求 Git for Windows / Git Bash 作为运行前提
- 关键变更点:
  - 顶层命令迁移到 `spec/bootstrap/commands/`
  - 共享逻辑迁移到 `spec/bootstrap/lib/`
  - hooks runtime 继续在 `spec/bootstrap/hooks/`，但改成无扩展名 handler
  - 新增 `spec/bootstrap/hooks/run-hook.cmd` 作为 Windows hook/launcher 入口
  - `install-hooks.sh` 改为生成跨平台安全的 hook command string
  - `install-hooks.sh` 去掉 `python3` 依赖，改用 shell helper 计算相对路径
  - 所有 `.ps1` 文档引用改为 shell 主路径 + Windows launcher / Git Bash 说明
  - review gate 再加三层护栏：
    - strict verifier / evaluator provenance 必须含 `isolated_subagent` + `Agent ID`
    - 本地 `.codex/hooks.json` / `.claude/settings.json` 要能与当前 `install-hooks.sh --dry-run` 输出做 drift 对比
    - 新增 review preparation 命令，把 hooks 刷新、本地 hook smoke check 和 isolated review 指引做成可执行入口
- 数据 / 控制边界:
  - 公共入口层:
    - `spec/bootstrap/*.sh`
    - 职责仅为参数转发到 `commands/`
  - 核心实现层:
    - `spec/bootstrap/commands/*.sh`
    - `spec/bootstrap/lib/*.sh`
  - hooks runtime:
    - `spec/bootstrap/hooks/<handler>`
    - `spec/bootstrap/hooks/lib/*.sh`
    - `spec/bootstrap/hooks/run-hook.cmd`
  - 文档层:
    - `spec/bootstrap/docs/` 或保留现有 markdown 并与命令分目录
    - `README.md` / `README.zh-CN.md` / `spec/README.md`
- 向后兼容说明:
  - 现有 shell 命令路径继续可执行
  - `.ps1` 不保留为兼容层，文档将明确升级后的 Windows 运行方式为 Git Bash / launcher
  - hooks 写出的路径以新结构为准，但宿主侧仍只看到稳定命令串

### 3.1 目标目录形态

```text
spec/bootstrap/
  README.md

  install-harness.sh
  init-harness.sh
  start-task.sh
  update-harness.sh
  link-skills.sh
  sync-skills.sh
  sync-governance-entrypoints.sh
  install-hooks.sh
  check-consistency.sh
  check-root-readme-bilingual.sh

  commands/
    install-harness.sh
    init-harness.sh
    start-task.sh
    update-harness.sh
    link-skills.sh
    sync-skills.sh
    sync-governance-entrypoints.sh
    install-hooks.sh
    check-consistency.sh
    check-root-readme-bilingual.sh

  lib/
    language.sh
    module-status.sh
    paths.sh
    profile.sh
    provenance.sh
    state-requirements.sh
    templates.sh

  hooks/
    run-hook.cmd
    post-artifact
    pre-transition
    session-start
    stop-check
    subagent-stop
    lib/
      parse-input.sh
      human-ack.sh
```

### 3.2 关键设计决定

- 决定 1: `.ps1` 全量退场
  - 不再维护 `init-harness.ps1` / `start-task.ps1` / `install-harness.ps1` 等双实现
  - Windows 用户统一走：
    - `bash spec/bootstrap/<command>.sh ...`
    - 或由 `run-hook.cmd` / 未来 `run-bootstrap.cmd` 调 Git Bash
- 决定 2: hooks handler 去扩展名
  - 借鉴 `superpowers`，让真正 handler 呈现为平台无关名称
  - Windows launcher 决定如何启动它，而不是让仓库结构暴露 `.sh` 假设
- 决定 3: 顶层 wrapper 保持稳定
  - 这样 README、vendored repo、历史路径和外部脚本不需要同步大迁移
- 决定 4: 纯 shell 实现相对路径与共享逻辑
  - 新增 `lib/paths.sh` 统一计算 repo-relative path
  - 新增 `lib/language.sh`、`lib/state-requirements.sh` 等消除重复逻辑
- 决定 5: strict review provenance 需要 agent 级审计字段
  - 在 verification/evaluation templates 中新增 `Agent ID`
  - `validate-isolation.sh` 在 strict 模式下要求 `Execution context: isolated_subagent` 且 `Agent ID` 非空
  - verifier / evaluator skills 明确要求 orchestrator 通过 `spawn_agent(..., fork_context: false)` 启动，并把 agent id 传入 prompt 以便写入 artifact
- 决定 6: hook freshness 以“当前应有配置”比对 live 配置，而不是靠版本常量
  - 不向 host JSON 写额外 schema 字段，避免宿主兼容风险
  - `check-consistency.sh` 通过 `install-hooks.sh --dry-run` 生成当前期望 command strings，再与 live `.codex/hooks.json` / `.claude/settings.json` 中 Baton 管理的 entries 比较
  - 这样既能抓到“handler 文件被删”，也能抓到“command string 语义已变但文件还在”的漂移
- 决定 7: review preparation 只做 runtime 准备，不负责直接起 agent
  - agent 启动能力属于宿主而非 shell runtime
  - 因此新增 `prepare-review.sh`，负责：
    - 重跑 `install-hooks.sh`
    - 执行 `check-root-readme-bilingual.sh` 与 `check-consistency.sh`
    - 从 `.codex/hooks.json` 提取一条生成的 hook command 做真实 smoke check
    - 输出 isolated verifier / evaluator 的下一步执行提示

### 3.3 迁移顺序

1. 抽出共享库：`language.sh`、`state-requirements.sh`、`paths.sh`
2. 将顶层现有 `.sh` 逻辑迁移到 `commands/`，顶层保留 wrapper
3. 将 `module-status.sh`、`provenance.sh` 等迁入 `lib/`，更新调用方
4. 将 hooks handlers 改为无扩展名，并加入 `run-hook.cmd`
5. 重写 `install-hooks.sh` 的 command string 生成逻辑
6. 删除 `.ps1`
7. 更新 tests 与文档

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `spec/bootstrap/install-harness.sh` | L1 | modify | 降为 wrapper |
| `spec/bootstrap/init-harness.sh` | L1 | modify | 降为 wrapper |
| `spec/bootstrap/start-task.sh` | L1 | modify | 降为 wrapper |
| `spec/bootstrap/install-hooks.sh` | L1 | modify | 降为 wrapper，且安装模型变更 |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | 新结构与新兼容边界需要重新校验 |
| `spec/bootstrap/check-root-readme-bilingual.sh` | L1 | modify | 可能降为 wrapper 或更新路径断言 |
| `spec/bootstrap/module-status.sh` | L2 | move/modify | 迁入共享库 |
| `spec/bootstrap/provenance.sh` | L2 | move/modify | 迁入共享库 |
| `spec/bootstrap/harness-context.sh` | L2 | move/modify | 迁入 runtime/context 或 commands |
| `spec/bootstrap/validate-artifact.sh` | L2 | move/modify | 迁入 validators 或 commands/lib |
| `spec/bootstrap/validate-transition.sh` | L2 | move/modify | 同上 |
| `spec/bootstrap/validate-isolation.sh` | L2 | move/modify | 同上 |
| `spec/bootstrap/validate-state-artifacts.sh` | L2 | move/modify | 同上 |
| `spec/bootstrap/hooks/*` | L2 | modify | handler 命名和启动方式调整 |
| `spec/bootstrap/prepare-review.sh` | L1 | add | review preparation 入口 |
| `spec/templates/verification-path.template.md` | L2 | modify | 新增 Agent ID provenance |
| `spec/templates/evaluation.template.md` | L2 | modify | 新增 Agent ID provenance |
| `spec/templates/zh/verification-path.template.md` | L2 | modify | 同步中文模板 |
| `spec/templates/zh/evaluation.template.md` | L2 | modify | 同步中文模板 |
| `skills/baton-verifier/SKILL.md` | L2 | modify | 强制 isolated spawn + Agent ID 记账 |
| `skills/baton-evaluator/SKILL.md` | L2 | modify | 强制 isolated spawn + Agent ID 记账 |
| `spec/bootstrap/*.ps1` | L1 | delete | 移除双核心 |
| `tests/test-install-hooks.sh` | L1 | modify | 断言新 hook 路径与 launcher |
| `tests/test-validate-isolation.sh` | L1 | modify | 断言 strict + Agent ID gate |
| `tests/test-prepare-review.sh` | L1 | add | 断言 review preparation 行为 |
| `tests/test-start-task.sh` | L1 | modify | 对齐新入口与共享库路径 |
| `tests/test-hook-*.sh` | L1 | modify | 对齐新 hooks 命名 |
| `README.md` | L1 | modify | 更新公开安装/Windows 路径 |
| `README.zh-CN.md` | L1 | modify | 与 README.md 保持同步 |
| `spec/README.md` | L1 | modify | 更新 bootstrap 目录结构与命令说明 |
| `spec/bootstrap/*.md` | L2 | modify | 删除 `.ps1` 示范，更新新结构说明 |

## 5. 验证策略

- 主要检查:
  - `bash spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir spec/bootstrap`
  - `bash tests/test-install-hooks.sh`
  - `bash tests/test-start-task.sh`
  - `bash tests/test-module-status.sh`
  - `bash tests/test-hook-parse-input.sh`
  - `bash tests/test-hook-post-artifact.sh`
  - `bash tests/test-hook-pre-transition.sh`
  - `bash tests/test-hook-session-start.sh`
  - `bash tests/test-hook-stop-check.sh`
  - `bash tests/test-hook-subagent-stop.sh`
  - `bash tests/test-skill-links.sh`
  - `bash tests/test-prepare-review.sh`
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
  - 从 live `.codex/hooks.json` 提取并执行 `SessionStart` hook command
- 评审重点:
  - 是否真的只剩一套权威实现
  - 顶层 wrapper 是否保持兼容而不再次塞回业务逻辑
  - Windows 入口是否清晰、简单、可文档化
  - hook command string 是否避免平台相关 quoting 问题
  - strict verifier / evaluator 是否留下可审计 provenance，而不是只写“strict”字样
  - live hook config 是否能被自动发现 drift
- 验证无法完全消除的风险:
  - 本地 shell tests 不能完全替代真实 Windows 机器 smoke test
  - 文档迁移后仍可能存在外部用户依赖旧 `.ps1` 的升级摩擦

## 6. 风险

- 立即删除 `.ps1` 会让少数纯 PowerShell 用户失去原路径，需要明确宣布新的前提
- `check-consistency.sh` 当前与若干旧路径强耦合，重构时容易先红一片
- hooks 去扩展名后，测试和安装脚本必须同步调整，否则会出现半迁移状态
- 若 wrapper 设计不克制，顶层又会重新长回“第二份逻辑”

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 在“不引入 Python”和“拒绝长期双实现”两个约束同时成立时，这是最优方案类别，不只是第一个可行方案。
2. 还有哪些假设尚未验证?
   - 还未在真实 Windows 环境验证 `run-hook.cmd` 和 Git Bash 路径发现细节。
   - 还未决定 docs 是否单独迁入 `spec/bootstrap/docs/`，还是保留现位只更新引用。
3. 一个怀疑者会先质疑什么?
   - “为什么不保留 `.ps1` 兼容一段时间？”
   - “Git Bash 作为前提会不会过于强硬？”
   - “hooks 去扩展名是否真的比 `.sh` 更值？”

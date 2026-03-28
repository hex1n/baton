# Architecture: harness-distribution-installer

**主题**: harness 外部分发机制
**状态**: `approved`
**规模**: `Large`

## 1. 问题

需要把 baton 从“当前仓库内部可运行的一套 spec + skills”提升为“能稳定安装到其他项目，并且能升级、保留本地 override、记录版本真源”的分发模型。

## 2. 第一性原理拆解

### 2.1 问题陈述

问题不是“如何再复制一次文件”，而是“如何让目标仓库拥有一份自包含、可升级、可覆盖、可追踪版本的 harness 运行载荷”。

### 2.2 约束

- 目标仓库不能依赖开发者本机 baton checkout 的绝对路径
- 当前 harness 的运行时入口仍然是 `.claude/skills/` 和 `.agents/`
- bootstrap 模板最终仍由 `init-harness` / `start-task` 写入 `.harness/`
- 不新增远程拉取协议或第三方依赖
- 需要保留 bash / PowerShell 双路径

### 2.3 方案类别

- 方案 A: 继续手工复制 skill / spec
- 方案 B: 让目标仓库直接引用 upstream baton checkout（外部 symlink）
- 方案 C: 在目标仓库 vendoring upstream payload，配 lockfile、本地 override 和 runtime materialization

### 2.4 评估

- 为什么方案 C 胜出:
  - 目标仓库自包含，可提交、可复现、可升级
  - 本地 override 与 upstream payload 分层清晰
  - 不依赖目标仓库外部路径，避免跨机器失效
  - 仍可在 repo 内部用 symlink/hardlink 减少重复
- 为什么拒绝方案 A:
  - 没有版本真源，没有升级路径，容易覆盖本地定制
- 为什么拒绝方案 B:
  - 仍然绑定开发机路径，不适合团队协作、CI 和仓库自包含

## 3. 推荐架构

- 方法:
  - 新增 `install-harness` / `update-harness`，把当前 baton checkout 的 `spec/` 和 `harness-*.md` 安装到目标仓库 `.vendor/baton-harness/`
  - 在目标仓库写 `.harness/harness.lock.yaml` 作为安装真源
  - 在目标仓库保留 `.harness/overrides/skills` 与 `.harness/overrides/templates`
  - 安装/升级时把“effective skill source”物化到 `.claude/skills/` 和 `.agents/`，优先 override，次选 vendor，并采用 repo 内 `symlink -> hardlink -> copy` 降级
  - 修改 `init-harness` / `start-task`，优先读取 `repo/.harness/overrides/templates`
- 关键变更点:
  - 新增安装与升级脚本、文档和 lockfile 生成逻辑
  - bootstrap 脚本增加 template override 搜索逻辑
  - README / spec 更新推荐接入路径
- 数据 / 控制边界:
  - upstream canonical payload: `.vendor/baton-harness/`
  - target local policy and overrides: `.harness/`
  - runtime skill entrypoints: `.claude/skills/` 与 `.agents/`
  - machine-readable task control plane 继续留在 `.harness/module-status.md`
- 向后兼容说明:
  - 现有 `init-harness` / `start-task` 仍可直接在 baton 源仓库对目标 repo 运行
  - 手工复制仍可作为 fallback，但不再是主推荐路径

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `spec/bootstrap/install-harness.sh` | L1 | add | 新增正式安装入口 |
| `spec/bootstrap/update-harness.sh` | L1 | add | 新增正式升级入口 |
| `spec/bootstrap/install-harness.ps1` | L1 | add | PowerShell 对齐 |
| `spec/bootstrap/update-harness.ps1` | L1 | add | PowerShell 对齐 |
| `spec/bootstrap/install-harness.md` | L1 | add | 新接入文档 |
| `spec/bootstrap/update-harness.md` | L1 | add | 新升级文档 |
| `spec/bootstrap/init-harness.sh` | L1 | modify | 增加 template override 搜索 |
| `spec/bootstrap/start-task.sh` | L1 | modify | 增加 template override 搜索 |
| `spec/bootstrap/init-harness.ps1` | L1 | modify | PowerShell 对齐 |
| `spec/bootstrap/start-task.ps1` | L1 | modify | PowerShell 对齐 |
| `README.md` | L1 | modify | 更新推荐接入方式 |
| `spec/README.md` | L1 | modify | 更新 portable spec 目录与接入流程 |

## 5. 验证策略

- 主要检查:
  - `bash -n` 检查新增/修改的 shell 脚本
  - 临时目标仓库执行 install/update
  - 在临时目标仓库中使用 vendored `init-harness` / `start-task`
  - 创建 override skill/template，验证优先级
  - `check-consistency.sh` 与 `git diff --check`
- 评审重点:
  - vendor 布局是否自包含
  - lockfile 是否足够表达版本真源
  - override 机制是否只影响人类可读工件，不漂移控制面
- 验证无法完全消除的风险:
  - PowerShell 路径在当前环境仍无法做运行时验证

## 6. 风险

- `update-harness` v1 依赖“当前 baton checkout 作为更新源”，尚未解决远程发现最新版本的问题
- repo 内 runtime materialization 若落到 copy 模式，需要重复执行 update 才能刷新入口文件
- 如果目标仓库手工改了 `.vendor/baton-harness/`，下次 update 会覆盖；本地定制必须放进 `.harness/overrides/`

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 对当前“本地源仓库分发到其他目标仓库”的边界，这已经是最稳的方案类别；远程安装是下一阶段问题，不是当前必须项。
2. 还有哪些假设尚未验证?
   - 未验证 Windows / PowerShell 实际物化行为。
3. 一个怀疑者会先质疑什么?
   - 为什么不直接上包管理器或远程 install；答案是当前先解决“仓库内自包含 + 可升级 + 可 override”，避免过早扩展分发面。

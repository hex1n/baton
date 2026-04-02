# Requirements: harness-distribution-installer

**主题**: harness 外部分发与升级机制
**状态**: `approved`
**规模**: `Large`

## 1. 问题

当前 baton 对“其他项目如何接入 harness”的正式路径只有手工复制 skill 和直接从当前 checkout 运行 bootstrap 脚本。这样无法稳定表达版本、升级、覆盖顺序，也无法让目标仓库在保留本地定制的同时安全更新上游 harness。

## 2. 范围

### 2.1 范围内

- 新增正式的 `install-harness` 命令，把 harness payload 安装到目标仓库
- 新增正式的 `update-harness` 命令，按 lockfile 刷新目标仓库里的 harness payload
- 为目标仓库定义 lockfile 和 override 目录结构
- 让 `init-harness` / `start-task` 支持目标仓库本地模板 override
- 更新 README / spec 文档，给出推荐接入方式

### 2.2 范围外

- 不实现从远程 GitHub / package registry 自动拉取最新版本
- 不实现 submodule / subtree 管理
- 不为目标仓库新增复杂的守护进程、调度器或 watcher

## 3. 功能需求

### FR-1 正式安装命令

- 系统必须提供 `install-harness`，把当前 baton checkout 的可分发 payload 安装到目标仓库
- 安装结果必须包含可复用的 vendored spec、vendored harness skills、runtime skill 入口和 lockfile

### FR-2 正式升级命令

- 系统必须提供 `update-harness`，在保留目标仓库 local overrides 的前提下刷新 vendored payload
- 升级后 runtime skill 入口必须重新物化，避免目标仓库继续引用旧内容

### FR-3 Lockfile 真源

- 安装或升级后，目标仓库必须拥有单一真源 lockfile，记录至少以下信息:
  - schema/version
  - 上游 harness 版本
  - 上游 commit
  - vendor 根目录
  - override 根目录
  - runtime skill 目标目录
  - 最近一次安装/升级时间

### FR-4 Local Override 机制

- 目标仓库必须可以在不改 vendored upstream payload 的前提下做本地覆写
- 覆写至少支持两类:
  - `skills`
  - `templates`
- 覆写优先级必须明确且稳定

### FR-5 模板 override 生效

- `init-harness` 和 `start-task` 必须先查找目标仓库 `.harness/overrides/templates`，找不到时再回退到 vendored `spec/templates`
- 机器可读的控制面模板不得因为本地化或 override 失去稳定性

### FR-6 Runtime Skill 物化

- 安装或升级后，目标仓库 `.claude/skills/` 与 `.agents/` 必须拥有可直接被运行时消费的 harness skill 文件
- 这些 runtime files 应优先使用本地 override，未 override 时使用 vendored upstream
- 物化过程应优先尝试 repo 内 symlink，再回退到 hardlink/copy，而不是依赖目标仓库外部的 baton 路径

### FR-7 自包含接入

- 目标仓库安装完成后，必须在仓库内部持有运行 `init-harness` / `start-task` 所需的 spec 和 skills，不要求开发者继续依赖原始 baton checkout 的绝对路径

### FR-8 文档化推荐路径

- 文档必须把“vendor + lockfile + override + runtime materialization”标记为推荐接入方式
- 手工复制只能作为简化 fallback，不再作为主推荐路径

## 4. 非目标

- 不解决跨机器自动更新来源发现
- 不解决任意远程版本比较或 semver 协商
- 不引入 target repo 对 upstream baton 的运行时硬依赖

## 5. 验收标准

### AC-1 安装可用

- [ ] 在一个临时目标仓库运行安装命令后，出现 `.vendor/baton-harness/`、`.harness/harness.lock.yaml`、`.harness/overrides/`、`.claude/skills/` 和 `.agents/` 的预期内容

### AC-2 升级可用

- [ ] 在同一个临时目标仓库再次运行升级命令后，lockfile 的版本/commit/时间戳更新，runtime skill 入口重新物化

### AC-3 Override 不丢失

- [ ] 当目标仓库存在 `.harness/overrides/skills/<file>` 时，runtime skill 入口使用 override 内容而不是 vendored upstream
- [ ] 当目标仓库存在 `.harness/overrides/templates/...` 时，vendored `init-harness` / `start-task` 使用 override 模板生成活动制品

### AC-4 自包含

- [ ] 安装后可以从目标仓库内部的 vendored bootstrap 脚本继续运行 `init-harness`，不需要依赖原始 baton checkout 路径

### AC-5 文档一致

- [ ] README 与 spec 文档明确区分 baton 自身开发态 link-mode 和外部目标仓库推荐的 install/update 路径

### AC-6 控制面稳定

- [ ] `task-status.md` 相关控制面行为不因 overrides 或本地化而漂移

## 6. 约束

- 继续保持 bash / PowerShell 双脚本路径
- 当前环境没有 `pwsh`，因此 PowerShell 只能做静态对齐，无法运行时验证
- 不引入额外依赖如 `jq` / `yq`

## 7. 验证意图

- 用临时目标仓库真实执行 install/update/bootstrap 回归
- 检查 lockfile、vendor 布局、runtime skills 和 override 生效顺序
- 用一致性检查与 `git diff --check` 保证源仓库未引入格式和协议回归

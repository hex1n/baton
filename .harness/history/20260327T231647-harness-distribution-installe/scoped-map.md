# Scoped Map: harness-distribution-installer

**需求**: 为其他项目接入 baton harness 设计并实现正式的 install/update/lockfile/override 机制，替代单纯手工复制 skill 的方式。
**领域**: harness 分发与仓库接入
**Owner**: `scoped-explorer`
**状态**: `complete`

## 1. 范围

- 范围内:
  - 设计外部仓库接入时的 vendor 布局、lockfile 和 local override 规则
  - 实现 `install-harness` / `update-harness` 脚本与文档
  - 让 `init-harness` / `start-task` 支持从目标仓库的 override 模板目录取模板
  - 定义如何把 vendored skill 物化到 `.claude/skills/` 和 `.agents/`
- 范围外:
  - 不做网络拉取、包管理器发布或远程 registry
  - 不引入 git submodule / subtree 工作流
  - 不改现有 protocol gate 顺序
- 预期写入边界:
  - `spec/bootstrap/`
  - `README.md`
  - `spec/README.md`
  - 可能新增 lockfile 模板 / 文档说明

## 2. 入口点

- 主要入口类或文件:
  - `README.md`
  - `spec/bootstrap/init-harness.sh`
  - `spec/bootstrap/start-task.sh`
  - `spec/bootstrap/link-skills.sh`
  - `spec/bootstrap/sync-skills.sh`
- 涉及的方法、API、命令或脚本:
  - `init-harness`
  - `start-task`
  - 新增 `install-harness`
  - 新增 `update-harness`
- 这些入口为什么相关:
  - 现在“接入其他项目”只有 README 里的手工复制说明，没有正式安装/升级路径；bootstrap 脚本也没有 vendor/override 概念

## 3. 调用链

```text
source baton repo
  -> install-harness/update-harness
  -> target repo .vendor/baton-harness + .harness/harness.lock.yaml
  -> runtime skills materialized into .claude/skills and .agents
  -> vendored init-harness/start-task
  -> target repo .harness active task artifacts
```

## 4. 现有行为

- 当前可观察行为:
  - baton 自己内部可以用 `link-skills.sh` / `sync-skills.sh` 管理 `skills/`、`.claude/skills/`、`.agents/`
  - 其他项目目前靠 README 里的 `cp .claude/skills/harness-*.md ...` 手工复制
  - `init-harness` 会直接从当前 baton checkout 的 `spec/templates` 写目标仓库 `.harness/`
- 当前校验规则:
  - `check-consistency.sh` 只校验 baton 仓库内部 owner/state/header/skill mirror 一致性
  - 没有“外部分发是否与 lockfile 一致”的校验
- 现有隐式约束:
  - 目标仓库如果想升级 harness，必须人工再次复制
  - 目标仓库做本地定制后，下一次复制很容易把本地改动覆盖掉
  - 目前不存在单一真源来记录“某个目标仓库装的是哪一版 harness”

## 5. 现有测试

- 直接相关的测试:
  - 无自动测试；主要依赖 bootstrap 脚本 dry-run / 临时仓库验证
- 附近可复用的测试:
  - `check-consistency.sh`
  - 现有 `init-harness` / `start-task` 临时仓库回归方法
- 未找到可用测试:
  - 没有现成的 install/update 集成测试

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 会触及 bootstrap 脚本和目标仓库目录布局，但不触及业务代码
- 这次改动是否可能触及迁移或 schema?
  - 会新增 lockfile schema，但仅限 harness 元数据
- 这次改动是否可能跨业务域?
  - 会影响 spec、bootstrap、README、target repo adoption flow

## 7. 变更形态

- 这看起来像:
  - 分发机制增强 + bootstrap overlay 支持 + 文档改造
- 预计文件数:
  - 中等，约 10-16 个文件
- 推荐实现深度:
  - 做到可真实安装到临时目标仓库并完成一次 overlay 回归

## 8. 未决问题

- install 是否要顺手执行 `init-harness`，还是只负责 vendor 和 runtime materialization?

## 9. 建议

- 是否继续?
  - 继续
- 建议下一步:
  - 把 install/update 与 init-harness 分开：前者负责“分发与升级”，后者继续负责“初始化任务工件”

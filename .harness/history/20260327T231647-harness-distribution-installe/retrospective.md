# Retrospective: harness-distribution-installer

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无功能性阻塞；唯一残余风险是当前环境缺少 `pwsh`，因此 PowerShell 安装与 bootstrap 路径未做运行时验证
- 人工决策: 接受 PowerShell 运行时未验证的残余风险，并确认采用 `vendor + lockfile + overrides + runtime materialization` 作为外部仓库推荐接入模型

## 2. 有效做法

- 把“分发”与“初始化任务工件”拆开是对的，`install-harness` / `update-harness` 负责 payload 生命周期，`init-harness` / `start-task` 继续负责任务制品
- 用临时目标仓库跑真实 install/update/bootstrap 回归很关键，能直接验证 vendored 脚本是否真的自包含
- 将 override 规则同时落在 skill runtime materialization 和 template lookup 上，避免只有一半路径支持本地定制

## 3. 失败点

- 现有 `check-consistency.sh` 仍只覆盖 baton 仓库内部一致性，没有外部目标仓库安装态的自动化校验
- PowerShell 路径依旧只能静态对齐，无法证明 Windows 侧 runtime materialization 的实际行为

## 4. 仓库特定经验

- baton 自己内部继续适合 link-mode 维护 canonical `skills/`
- 对外部分发则必须是目标仓库自包含，不能再依赖开发机上的 baton 绝对路径
- `.harness/overrides/` 必须作为唯一允许的本地定制入口，避免目标仓库直接修改 `.vendor/baton-harness/`

## 5. Harness 经验

- 分发模型也要遵守“单一真源”原则：版本与布局真源在 `harness.lock.yaml`，本地差异真源在 `.harness/overrides/`
- `auto` 这种运行时策略和“默认值”要分开；同样，vendor payload 和 local override 也必须分层，不然升级一定会覆盖定制
- 推荐路径必须写进 README 与 spec，而不能只留在口头约定里，否则团队会继续走手工复制的旧路径

## 6. 可标准化候选

- 给目标仓库安装态补一套专门的验证脚本，例如 `verify-harness-install.sh`
- 把 `harness.lock.yaml` schema 正式写进 spec 文档，而不是只让脚本隐式生成
- 后续可以在远程分发层面再加 release source / registry，但前提仍然是保持当前的 vendor + override 分层不变

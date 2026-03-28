# Verification Path: harness-distribution-installer

**Owner**: `verification-explorer`
**状态**: `complete`

## 1. 计划检查项

- Build:
  - 不涉及业务 build；主要验证 bootstrap / distribution 脚本
- 测试:
  - install/update 能在临时目标仓库真实运行
  - vendored `init-harness` / `start-task` 能在 override 场景下写出正确工件
- 静态检查:
  - `bash -n`
  - `check-consistency.sh`
  - `git diff --check`
- 运行时 / 手工检查:
  - lockfile 内容正确
  - vendor 布局正确
  - `.claude/skills` / `.agents` 指向或落地到 effective skill source

## 2. 精确命令

```text
bash -n spec/bootstrap/install-harness.sh
bash -n spec/bootstrap/update-harness.sh
bash -n spec/bootstrap/init-harness.sh
bash -n spec/bootstrap/start-task.sh
tmp=$(mktemp -d); git init -q "$tmp"; touch "$tmp/package.json"; bash spec/bootstrap/install-harness.sh --repo-root "$tmp"; bash "$tmp/.vendor/baton-harness/spec/bootstrap/init-harness.sh" --repo-root "$tmp" --profile auto --adapter codex
tmp=$(mktemp -d); git init -q "$tmp"; touch "$tmp/package.json"; bash spec/bootstrap/install-harness.sh --repo-root "$tmp"; printf '---\\nname: override\\n' > "$tmp/.harness/overrides/skills/harness-explorer.md"; bash spec/bootstrap/update-harness.sh --repo-root "$tmp"
tmp=$(mktemp -d); git init -q "$tmp"; touch "$tmp/package.json"; bash spec/bootstrap/install-harness.sh --repo-root "$tmp"; printf '# Requirements: custom\\n' > "$tmp/.harness/overrides/templates/zh/requirements.template.md"; bash "$tmp/.vendor/baton-harness/spec/bootstrap/init-harness.sh" --repo-root "$tmp" --profile auto --adapter codex
bash spec/bootstrap/check-consistency.sh
git diff --check
command -v pwsh
rg -n "install-harness|update-harness|harness.lock|overrides|vendor" README.md spec/README.md spec/bootstrap
```

## 3. 前置条件

- 工具链:
  - `bash`
  - 标准 Unix 工具
  - `git`
- 服务:
  - 无
- 夹具 / 测试数据:
  - 临时目标仓库目录
- 环境变量:
  - 无特殊要求

## 4. Dry-Run 结果

- 命令: shell 脚本语法检查
  - 结果: pass
  - 备注: `install-harness.sh`、`update-harness.sh`、`init-harness.sh`、`start-task.sh` 的 bash 语法检查通过
- 命令: 临时目标仓库 install + vendored init-harness
  - 结果: pass
  - 备注: 成功写出 `.vendor/baton-harness/`、`.harness/harness.lock.yaml`，并从目标仓库内的 vendored `init-harness` / `start-task` 完成初始化与任务启动；runtime skill mode 落在 repo 内 `symlink`
- 命令: 临时目标仓库 override skill + update
  - 结果: pass
  - 备注: `.harness/overrides/skills/harness-explorer.md` 在执行 `update-harness` 后仍然覆盖 `.claude/skills/` 与 `.agents/` 的 runtime entrypoint；lockfile 的 `install.mode` 更新为 `update`
- 命令: 临时目标仓库 override template + vendored init-harness
  - 结果: pass
  - 备注: `.harness/overrides/templates/zh/requirements.template.md` 被 vendored `init-harness` 正确优先读取，生成的 `requirements.md` 命中了自定义内容
- 命令: `bash spec/bootstrap/check-consistency.sh`
  - 结果: pass
  - 备注: owner/state/header/skill mirror invariants 均通过
- 命令: `git diff --check`
  - 结果: pass
  - 备注: 无尾空格或 patch 格式问题
- 命令: `command -v pwsh`
  - 结果: fail
  - 备注: 当前环境没有 `pwsh`，所以 `install-harness.ps1` / `update-harness.ps1` 以及 PowerShell 版 bootstrap 脚本只能做静态对齐，未做运行时验证
- 命令: docs / bootstrap 关键词检查
  - 结果: pass
  - 备注: README、spec README 和 bootstrap 文档都已包含 `install-harness`、`update-harness`、`harness.lock`、`overrides`、`vendor` 说明

## 5. 阻塞项

- none

## 6. 回退方案

- 如果主路径失败:
  - 优先检查 lockfile 写入和 vendor 目录布局，再检查 runtime skill 物化是否走到了 copy fallback
- 如果测试模块不可用:
  - 不适用
- 如果仓库当前 build 已损坏:
  - 不适用

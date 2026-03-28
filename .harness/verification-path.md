# Verification Path: governance-multi-host-entrypoints

**Owner**: `verification-explorer`
**状态**: `ready`

## 1. 计划检查项

- Build:
  - 不涉及
- 测试:
  - 不涉及单元测试
- 静态检查:
  - `bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --mode check`
  - `bash spec/bootstrap/check-consistency.sh`
  - `git diff --check`
- 运行时 / 手工检查:
  - 在临时仓库执行 `init-harness.sh`，确认会生成 `CLAUDE.md` 和 `AGENTS.md`
  - grep 文档，确认 README / adapter / bootstrap 文档说明已补齐

## 2. 精确命令

```text
bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --mode check
bash spec/bootstrap/check-consistency.sh
tmp_repo="$(mktemp -d)"
bash spec/bootstrap/init-harness.sh --repo-root "$tmp_repo" --profile python-service --adapter codex --task-id smoke --force
test -f "$tmp_repo/CLAUDE.md" && test -f "$tmp_repo/AGENTS.md"
git diff --check
```

## 3. 前置条件

- 工具链:
  - `bash`
  - `grep`
  - `mktemp`
  - `git`
- 服务:
  - 无
- 夹具 / 测试数据:
  - 一个临时空目录
- 环境变量:
  - 无特殊要求

## 4. Dry-Run 结果

- 命令:
  - `bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --mode check`
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash spec/bootstrap/init-harness.sh --repo-root "$tmp_repo" --profile python-service --adapter codex --task-id smoke --force`
  - `git diff --check`
- 结果:
  - root governance sync check: passed
  - root README bilingual check: passed
  - repository consistency check: passed
  - temp repo bootstrap generated both `CLAUDE.md` and `AGENTS.md`: passed
  - `git diff --check`: passed
- 备注:
  - 当前环境没有 `pwsh`，因此 `sync-governance-entrypoints.ps1` 和 `init-harness.ps1` 仅做了静态对齐，未做运行时验证

## 5. 阻塞项

- none

## 6. 回退方案

- 如果主路径失败:
  - 先单独运行同步脚本定位是模板、根文件还是 init-harness 接线问题
- 如果测试模块不可用:
  - 至少运行同步脚本 check、主一致性检查与手工文件存在性检查
- 如果仓库当前 build 已损坏:
  - 本任务不依赖 build

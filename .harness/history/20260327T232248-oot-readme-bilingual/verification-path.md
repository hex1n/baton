# Verification Path: root-readme-bilingual

**Owner**: `verification-explorer`
**状态**: `complete`

## 1. 计划检查项

- Build:
  - 不涉及
- 测试:
  - 不涉及
- 静态检查:
  - 根目录 README 文件存在性
  - 双向语言链接
  - 关键术语命中
  - `git diff --check`
- 运行时 / 手工检查:
  - 中文版内容是否覆盖 install/update、vendor、lockfile、overrides、link-mode

## 2. 精确命令

```text
find . -maxdepth 1 -type f -iname 'README*' | sort
rg -n 'README.zh-CN.md|README.md' README.md README.zh-CN.md
rg -n 'install-harness|update-harness|vendor|harness.lock|overrides|link-skills' README.md README.zh-CN.md
git diff --check
```

## 3. 前置条件

- 工具链:
  - `rg`
  - `git`
- 服务:
  - 无
- 夹具 / 测试数据:
  - 无
- 环境变量:
  - 无

## 4. Dry-Run 结果

- 命令: 根目录 README 文件列表
  - 结果: pass
  - 备注: 根目录现在同时存在 `README.md` 和 `README.zh-CN.md`
- 命令: 双向语言链接检查
  - 结果: pass
  - 备注: 两份 README 顶部都包含对方文件的链接
- 命令: 关键术语命中
  - 结果: pass
  - 备注: 中英文两版都覆盖了 `install-harness`、`update-harness`、`vendor`、`harness.lock`、`overrides` 和 `link-skills`
- 命令: `git diff --check`
  - 结果: pass
  - 备注: 无格式问题

## 5. 阻塞项

- none

## 6. 回退方案

- 如果主路径失败:
  - 至少保留英文 README 不破坏，并单独新增中文 README 作为第一步
- 如果测试模块不可用:
  - 不适用
- 如果仓库当前 build 已损坏:
  - 不适用

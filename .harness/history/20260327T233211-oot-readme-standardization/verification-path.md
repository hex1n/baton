# Verification Path: root-readme-standardization

**Owner**: `verification-explorer`
**状态**: `ready`

## 1. 计划检查项

- Build:
  - 不涉及
- 测试:
  - 不涉及单元测试
- 静态检查:
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
  - `bash spec/bootstrap/check-consistency.sh`
  - `git diff --check`
- 运行时 / 手工检查:
  - 检查 `CLAUDE.md` 和两份根目录 README 是否写入了双语维护规则

## 2. 精确命令

```text
bash spec/bootstrap/check-root-readme-bilingual.sh
bash spec/bootstrap/check-consistency.sh
git diff --check
```

## 3. 前置条件

- 工具链:
  - `bash`
  - `grep`
  - `git`
- 服务:
  - 无
- 夹具 / 测试数据:
  - 当前仓库已有 `README.md` 与 `README.zh-CN.md`
- 环境变量:
  - 无特殊要求

## 4. Dry-Run 结果

- 命令:
  - `bash spec/bootstrap/check-root-readme-bilingual.sh`
  - `bash spec/bootstrap/check-consistency.sh`
  - `git diff --check`
- 结果:
  - `check-root-readme-bilingual.sh`: passed
  - `check-consistency.sh`: passed
  - `git diff --check`: passed
- 备注:
  - README 双语自检已验证链接、章节与关键术语

## 5. 阻塞项

- none

## 6. 回退方案

- 如果主路径失败:
  - 先单独运行 README 自检脚本定位是链接、章节还是关键术语缺失
- 如果测试模块不可用:
  - 至少保留 `git diff --check` 和手工 grep
- 如果仓库当前 build 已损坏:
  - 本任务不依赖 build 系统

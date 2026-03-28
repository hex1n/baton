# Requirements: root-readme-bilingual

**主题**: 根目录 README 中英双版
**状态**: `approved`
**规模**: `Small`

## 1. 问题

项目根目录当前只有英文 `README.md`，而仓库的默认文档语言和用户预期已经偏向中文，导致入口文档语言不一致，也无法直接给中文用户提供根目录级别的项目说明。

## 2. 范围

### 2.1 范围内

- 保留并更新英文 `README.md`
- 新增中文 `README.zh-CN.md`
- 在两份 README 顶部提供语言切换入口
- 保持两份 README 的结构和核心信息一致

### 2.2 范围外

- 不把所有 `spec/` 文档改成双语
- 不翻译根目录其他专题 Markdown

## 3. 功能需求

### FR-1 双版 README

- 根目录必须同时存在英文 README 和中文 README

### FR-2 双向链接

- 英文 README 必须显式链接到中文 README
- 中文 README 必须显式链接到英文 README

### FR-3 内容对齐

- 两份 README 必须覆盖相同的核心主题:
  - 项目定位
  - protocol 概览
  - 语言策略
  - 新仓库接入方式
  - install/update 分发模型
  - baton 自己内部的 link-mode 说明

### FR-4 根目录入口清晰

- 中文用户阅读根目录时应能直接看到中文入口，而不是再去猜测其他中文文件是否为正式 README

## 4. 非目标

- 不做逐段自动同步机制
- 不承诺所有后续根目录 Markdown 都双语

## 5. 验收标准

### AC-1 README 文件存在

- [ ] 根目录存在 `README.md` 和 `README.zh-CN.md`

### AC-2 语言切换可见

- [ ] 两份 README 顶部都有对方文件的明确链接

### AC-3 主题一致

- [ ] install/update、vendor、lockfile、overrides、link-mode 等关键信息在两份 README 中都能找到

### AC-4 格式正常

- [ ] `git diff --check` 通过

## 6. 约束

- 保持英文版可继续作为默认 GitHub README 展示
- 中文版文件名使用常见的 `README.zh-CN.md`

## 7. 验证意图

- 检查根目录 README 文件列表
- 检查双向链接和关键术语命中
- 运行 `git diff --check`

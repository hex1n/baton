# Scoped Map: root-readme-bilingual

**需求**: 将项目根目录 README 整理为中英双版，并确认根目录 README 覆盖情况。
**领域**: 根目录项目文档
**Owner**: `scoped-explorer`
**状态**: `complete`

## 1. 范围

- 范围内:
  - 检查项目根目录现有 README 布局
  - 维护英文 `README.md`
  - 新增中文 `README.zh-CN.md`
  - 在两份 README 顶部互相链接
- 范围外:
  - 不翻译 `spec/` 下的所有文档
  - 不改根目录下其他分析类中文 Markdown
- 预期写入边界:
  - `README.md`
  - `README.zh-CN.md`

## 2. 入口点

- 主要入口类或文件:
  - `README.md`
  - 项目根目录 Markdown 文件列表
- 涉及的方法、API、命令或脚本:
  - 无运行时代码入口；这是文档入口变更
- 这些入口为什么相关:
  - 根目录当前只有一份英文 README，用户明确要求中英双版

## 3. 调用链

```text
root README layout -> README.md -> README.zh-CN.md -> user-facing onboarding
```

## 4. 现有行为

- 当前可观察行为:
  - 根目录只有 `README.md`
  - `README.md` 内容已更新到 install/update 分发模型，但仍只有英文
- 当前校验规则:
  - 无 README 专项校验
- 现有隐式约束:
  - 项目默认语言现在偏中文，但根 README 仍只有英文，入口体验不一致

## 5. 现有测试

- 直接相关的测试:
  - 无
- 附近可复用的测试:
  - `git diff --check`
- 未找到可用测试:
  - 无自动校验 README 双语一致性的脚本

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 否
- 这次改动是否可能触及迁移或 schema?
  - 否
- 这次改动是否可能跨业务域?
  - 仅影响项目入口文档

## 7. 变更形态

- 这看起来像:
  - 文档补全与入口一致性修复
- 预计文件数:
  - 2 个文件
- 推荐实现深度:
  - 维持英文 README 为主版，新增一份结构对齐的中文版本

## 8. 未决问题

- 中文版是否需要严格逐段逐句对齐英文，还是保持结构一致但允许更自然的中文表述?

## 9. 建议

- 是否继续?
  - 继续
- 建议下一步:
  - 新增 `README.zh-CN.md`，并在两份 README 顶部加语言切换链接

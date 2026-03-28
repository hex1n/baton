# Scoped Map: root-readme-standardization

**需求**: 把 retrospective 中关于根目录 README 双语维护的第 5、6 点落成机制
**领域**: 根目录入口文档治理 / 仓库自检
**Owner**: `scoped-explorer`
**状态**: `ready`

## 1. 范围

- 范围内:
  - 为根目录 `README.md` / `README.zh-CN.md` 增加轻量自检脚本
  - 把根目录 README 双语维护规则写进治理文档
  - 让仓库已有自检入口能覆盖这条规则
- 范围外:
  - 扩展到所有文档文件的多语言同步
  - 为 `CONTRIBUTING` 再建立新的双语体系
  - 修改 harness 状态机或新增 role
- 预期写入边界:
  - `.harness/*.md`
  - `spec/bootstrap/*.sh`
  - `CLAUDE.md`
  - 根目录 README 双语入口

## 2. 入口点

- 主要入口类或文件:
  - `.harness/history/20260327T232248-oot-readme-bilingual/retrospective.md`
  - `README.md`
  - `README.zh-CN.md`
  - `CLAUDE.md`
  - `spec/bootstrap/check-consistency.sh`
- 涉及的方法、API、命令或脚本:
  - `bash spec/bootstrap/check-consistency.sh`
  - 新增 `bash spec/bootstrap/check-root-readme-bilingual.sh`
- 这些入口为什么相关:
  - retrospective 定义了要落地的经验
  - 根目录双语 README 是被维护的对象
  - `CLAUDE.md` 是现有治理摘要
  - `check-consistency.sh` 是 baton 仓库已有的自检主入口

## 3. 调用链

```text
retrospective lesson -> governance rule + repo check script -> check-consistency.sh -> root README drift surfaced early
```

## 4. 现有行为

- 当前可观察行为:
  - 根目录已经有英文 `README.md` 和中文 `README.zh-CN.md`
  - 双语 README 目前靠人工维护，没有自动校验
- 当前校验规则:
  - `check-consistency.sh` 校验 protocol/skills/bootstrap 一致性
  - 不覆盖根目录 README 双语一致性
- 现有隐式约束:
  - `README.md` 是英文主入口
  - `README.zh-CN.md` 是中文正式副本
  - 其他中文根目录文档不是 README 替代品

## 5. 现有测试

- 直接相关的测试:
  - 无现成自动测试；当前只能手工 grep / diff
- 附近可复用的测试:
  - `spec/bootstrap/check-consistency.sh` 的 invariant 输出风格可复用
- 未找到可用测试:
  - 没有专门针对 README 双语结构的断言脚本

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 只触及仓库治理脚本，不触及运行时产品逻辑
- 这次改动是否可能触及迁移或 schema?
  - 不会
- 这次改动是否可能跨业务域?
  - 不跨业务域，但会影响后续所有维护根目录 README 的流程

## 7. 变更形态

- 这看起来像:
  - 小型文档治理 + 仓库自检增强
- 预计文件数:
  - 6 到 9 个文件
- 推荐实现深度:
  - 直接落机制，不只写建议

## 8. 未决问题

- 贡献约定写到哪里最合适: 新建 `CONTRIBUTING.md`，还是补进现有治理摘要
- README 双语自检是否只作为独立脚本，还是顺手纳入 `check-consistency.sh`

## 9. 建议

- 是否继续?
  - 继续
- 建议下一步:
  - 用“独立脚本 + 纳入 `check-consistency.sh` + 治理摘要显式规则”的组合方案落地

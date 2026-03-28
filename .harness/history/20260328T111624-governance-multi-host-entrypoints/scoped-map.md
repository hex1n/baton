# Scoped Map: governance-multi-host-entrypoints

**需求**: 把根目录治理摘要从仅有 `CLAUDE.md` 扩展成 Claude Code / Codex / Cursor 都能识别的多宿主入口
**领域**: bootstrap / adapter governance / root agent instruction entrypoints
**Owner**: `scoped-explorer`
**状态**: `ready`

## 1. 范围

- 范围内:
  - 为根目录治理摘要建立单一真源模板
  - 物化 `CLAUDE.md` 与 `AGENTS.md`
  - 让 `init-harness` 在目标仓库里生成这两个入口
  - 增加一致性检查，防止双入口漂移
- 范围外:
  - 引入复杂的 `.cursor/rules/*.mdc` 规则体系
  - 为不同宿主维护完全不同版本的治理内容
  - 改写 portable protocol 本身
- 预期写入边界:
  - `.harness/*.md`
  - `spec/templates/*`
  - `spec/bootstrap/*`
  - `spec/adapters/*`
  - `README.md`
  - `README.zh-CN.md`
  - 根目录 `CLAUDE.md`
  - 根目录 `AGENTS.md`

## 2. 入口点

- 主要入口类或文件:
  - `CLAUDE.md`
  - `AGENTS.md`（当前缺失）
  - `spec/bootstrap/init-harness.sh`
  - `spec/bootstrap/check-consistency.sh`
  - `spec/adapters/codex.md`
  - `spec/adapters/cursor.md`
- 涉及的方法、API、命令或脚本:
  - `init-harness.sh --adapter ...`
  - 新增 `sync-governance-entrypoints.sh`
  - `check-consistency.sh`
- 这些入口为什么相关:
  - 当前问题就是根目录治理摘要只存在于 `CLAUDE.md`
  - bootstrap 决定目标仓库是否会获得可识别的根级规则入口
  - adapter 文档需要告诉用户不同宿主具体读哪个文件

## 3. 调用链

```text
canonical governance template -> sync-governance-entrypoints.sh -> CLAUDE.md + AGENTS.md -> host agent loads root rules
                                           -> init-harness bootstrap in target repo
                                           -> check-consistency.sh drift detection
```

## 4. 现有行为

- 当前可观察行为:
  - 仓库根目录只有 `CLAUDE.md`
  - 没有 `AGENTS.md`
  - `init-harness` 不会为目标仓库生成根级 agent instruction 文件
- 当前校验规则:
  - `check-consistency.sh` 目前不检查根目录治理入口是否同步
- 现有隐式约束:
  - `CLAUDE.md` 被当作治理摘要真源
  - Codex / Cursor 的根级规则入口没有被正式物化

## 5. 现有测试

- 直接相关的测试:
  - 无现成测试
- 附近可复用的测试:
  - `check-consistency.sh` 的 invariant 结构可扩展
  - README 双语检查脚本提供了“新增轻量脚本并接入主自检”的先例
- 未找到可用测试:
  - 没有 root governance dual-entry consistency check

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - 会影响 bootstrap 和外部仓库接入路径
- 这次改动是否可能触及迁移或 schema?
  - 不会
- 这次改动是否可能跨业务域?
  - 不跨业务域，但会影响所有用这个 harness 的宿主工具

## 7. 变更形态

- 这看起来像:
  - 小到中型的协议入口标准化
- 预计文件数:
  - 10 到 15 个文件
- 推荐实现深度:
  - 直接落脚本和 bootstrap，不只补文档

## 8. 未决问题

- 是否需要同时生成 `.cursor/rules/*.mdc`，还是 `AGENTS.md` 已足够覆盖 Cursor 简单场景
- 目标仓库若已有自定义 `CLAUDE.md` / `AGENTS.md`，bootstrap 覆盖策略如何处理

## 9. 建议

- 是否继续?
  - 继续
- 建议下一步:
  - 用“共享模板 + 双入口物化 + 主自检”方案实现，并把 Cursor 先落在 `AGENTS.md` 这个轻量官方入口上

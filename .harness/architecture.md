# Architecture: governance-multi-host-entrypoints

**主题**: 根目录治理摘要多宿主入口标准化
**状态**: `approved`
**规模**: `Medium`

## 1. 问题

当前 harness 参考实现只有 `CLAUDE.md` 这一份根级治理摘要。对 Claude Code 这是自然入口，但对 Codex 不是；对 Cursor 来说，这也不是最明确、最通用的根目录项目规则入口。问题本质不是“再复制一份文件”，而是“如何让多宿主入口共享同一份治理真源，并被 bootstrap 与一致性检查共同维护”。

## 2. 第一性原理拆解

### 2.1 问题陈述

根级 agent instruction 文件的职责是让宿主工具在进入仓库时就加载一组稳定、跨任务的项目规则。如果这些规则只存在于某一个宿主专用文件名下，那么协议虽然定义了治理摘要，实际却只对那个宿主生效。只要不同宿主看到的根级规则不一致，portable harness 的“adapter 只是执行层”这个原则就会被破坏。

### 2.2 约束

- 需要继续兼容 Claude Code 对 `CLAUDE.md` 的入口习惯
- Codex 需要 `AGENTS.md`
- Cursor 先走官方支持的简单入口 `AGENTS.md`，不引入更重的 `.cursor/rules` 系统
- 不能让 `CLAUDE.md` 和 `AGENTS.md` 长期手工同步

### 2.3 方案类别

- 方案 A: 只新增一个手工维护的 `AGENTS.md`
- 方案 B: 把治理摘要完全迁移到 `AGENTS.md`，删掉 `CLAUDE.md`
- 方案 C: 引入共享模板，通过脚本物化 `CLAUDE.md` 与 `AGENTS.md`，并纳入 bootstrap 与自检

### 2.4 评估

- 为什么方案 C 胜出:
  - 兼顾 Claude Code 与 Codex / Cursor
  - 保持单一真源，避免双文件长期漂移
  - 能自然接入 `init-harness` 和 `check-consistency.sh`
- 为什么拒绝方案 A:
  - 只是把单入口问题变成双份手工维护问题
- 为什么拒绝方案 B:
  - 会损失 Claude Code 的现有根入口，并且没有必要

## 3. 推荐架构

- 方法:
  - 新增共享模板 `spec/templates/root-governance.template.md`
  - 新增 `spec/bootstrap/sync-governance-entrypoints.sh`
  - baton 根目录用该脚本物化 `CLAUDE.md` 与 `AGENTS.md`
  - `init-harness.sh` 在目标仓库 bootstrap 时调用该脚本，为根目录写出缺失入口
  - `check-consistency.sh` 增加一个 invariant，检查这两个入口与模板保持一致
- 关键变更点:
  - 从单宿主 `CLAUDE.md` 升级为多宿主共享根入口
  - bootstrap 除了 `.harness` 制品，还会管理根目录治理入口
- 数据 / 控制边界:
  - 真源在 `spec/templates/`
  - 运行时根入口在 repo root
  - 一致性检查只在 baton 仓库强制 exact-match
- 向后兼容说明:
  - 继续保留 `CLAUDE.md`
  - Cursor 先通过 `AGENTS.md` 获得相同治理摘要，不额外要求 `.cursor/rules`

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `.harness/scoped-map.md` | L1 | modify | 记录当前探索 |
| `.harness/requirements.md` | L1 | modify | 固化需求 |
| `.harness/architecture.md` | L1 | modify | 固化方案 |
| `.harness/verification-path.md` | L1 | modify | 定义验证路径 |
| `.harness/module-status.md` | L1 | modify | 状态跟踪 |
| `spec/templates/root-governance.template.md` | L1 | add | 共享治理真源 |
| `spec/bootstrap/sync-governance-entrypoints.sh` | L1 | add | 物化和检查双入口 |
| `spec/bootstrap/init-harness.sh` | L1 | modify | bootstrap 目标仓库根入口 |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | 增加双入口 invariant |
| `CLAUDE.md` | L1 | modify | 由模板同步 |
| `AGENTS.md` | L1 | add | Codex / Cursor 根入口 |
| `README.md` | L1 | modify | 说明多宿主入口 |
| `README.zh-CN.md` | L1 | modify | 同步说明 |
| `spec/README.md` | L1 | modify | 说明 bootstrap 生成 root entrypoints |
| `spec/bootstrap/init-harness.md` | L1 | modify | 文档化行为 |
| `spec/adapters/codex.md` | L1 | modify | 明确读取 `AGENTS.md` |
| `spec/adapters/cursor.md` | L1 | modify | 明确轻量入口采用 `AGENTS.md` |

## 5. 验证策略

- 主要检查:
  - 同步脚本 check 模式通过
  - 主一致性检查通过
  - 临时仓库 bootstrap 后根目录出现双入口
- 评审重点:
  - `init-harness` 的覆盖策略是否足够稳妥
  - 是否在不过度设计的前提下覆盖了 Codex / Cursor
- 验证无法完全消除的风险:
  - Cursor 的高级规则体系没有在本次任务中覆盖；这里只保证根级简单入口

## 6. 风险

- 如果维护者绕过模板直接改 `CLAUDE.md` / `AGENTS.md`，会被一致性检查拦下
- 如果目标仓库已有自定义 root instructions，默认不强制覆盖，仍需人工决定是否合并

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 对当前需求是最优轻量方案；没有必要一步走到 Cursor 的复杂 rule metadata
2. 还有哪些假设尚未验证?
   - 尚未验证 PowerShell 版 init 是否也要同时落地；当前优先覆盖 bash 主路径
3. 一个怀疑者会先质疑什么?
   - “为什么不用单独的 `.cursor/rules`？” 回答是当前问题首先是 Codex 不识别 `CLAUDE.md`，而 `AGENTS.md` 已能覆盖 Codex，并作为 Cursor 的简单官方入口

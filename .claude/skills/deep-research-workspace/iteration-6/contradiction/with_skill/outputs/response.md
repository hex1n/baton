**Question**: docs/research-ide-hooks.md 里的适配器架构图显示了 adapter-cline.sh 和 adapter-copilot.sh，但代码里找不到这些文件。baton 当前支持哪些 adapter？文档和代码哪个是对的？
**Depth**: Standard
**Key finding**: 代码是对的。`adapter-cline.sh` 和 `adapter-copilot.sh` 从未实现——它们只存在于研究文档的"建议架构"图中，属于未来规划而非当前实现。baton 当前有且仅有 2 个 adapter：cursor 和 codex。
**Open questions**: 1 — see end of document

---

## Overview

研究文档 `docs/research-ide-hooks.md` 包含两种性质不同的内容：

1. **调研事实**（Tier 1/2/3 表格、各 IDE 详细信息）——记录外部 IDE 的 hook 能力
2. **建议架构图**（第 328-338 行）——基于调研提出的 baton 设计方案

`adapter-cline.sh` 和 `adapter-copilot.sh` 出现在第 2 类内容中，是**设计建议**，不是当前实现的描述。

## Findings

### 1. 代码中实际存在的 adapter

baton 当前有 2 个 adapter，均位于 `.baton/adapters/` 下，按 IDE 分目录组织：

| Adapter | 路径 | 用途 |
|---------|------|------|
| **cursor** | `.baton/adapters/cursor/adapter.sh` | 将 write-lock 的 exit code 翻译为 Cursor JSON 协议 `{"decision":"allow/deny"}` |
| **codex** | `.baton/adapters/codex/adapter.sh` | 将 hook stderr 输出翻译为 Codex stdout 协议（advisory only） |

每个 adapter 目录还有自己的 `dispatch.sh`，由 `setup.sh` 在安装时注册到对应 IDE 的配置文件中。

(verified: read `.baton/adapters/cursor/adapter.sh`, `.baton/adapters/codex/adapter.sh`, `ls .baton/adapters/`)

### 2. baton 当前支持的 4 个 IDE

`docs/ide-capability-matrix.md` 第 1-3 行明确声明（截至 2026-03-11）：

| Tier | IDE | Adapter 需求 |
|------|-----|-------------|
| Full protection | Claude Code, Factory AI | 无需 adapter，直接使用 `dispatch.sh` + exit code |
| Core protection | Cursor IDE | 需要 `cursor/adapter.sh` 翻译 JSON 协议 |
| Rules guidance | Codex | 需要 `codex/adapter.sh` 翻译 stderr→stdout |

(verified: read `docs/ide-capability-matrix.md`, `setup.sh` adapter 引用)

研究文档自身在第 7 行也标注了：
> Current implementation scope (2026-03-09): Baton supports 4 IDEs — Claude Code, Factory AI, Cursor IDE (core protection via adapter), and Codex (rules guidance). All other IDEs documented below are historical research only and are not supported by the current installer.

### 3. 文档中 adapter-cline.sh 和 adapter-copilot.sh 的性质

这两个文件名出现在研究文档的两个位置：

**位置 A — 建议架构图**（第 328-338 行）：
```
├── 薄适配层（~10行，翻译输出格式）：
│   ├── adapter-cline.sh    → {"cancel":true/false}
│   └── adapter-copilot.sh  → {"permissionDecision":"deny"/"allow"}
```

这是标注为"建议的 baton 架构"的设计方案图，描述的是**如果 baton 扩展到 Cline 和 Copilot 时需要的适配层**。

**位置 B — Copilot 配置示例**（第 227 行）：
```json
"bash": ".baton/adapters/adapter-copilot.sh",
```

这是 Copilot hook 的配置格式示例，展示的是**如果 baton 支持 Copilot 时配置文件长什么样**。

(verified: grep `adapter-cline|adapter-copilot` across entire codebase — only hits are in `docs/research-ide-hooks.md` and eval/workspace files)

### 4. 矛盾解析

| 维度 | 文档（research-ide-hooks.md） | 代码（.baton/adapters/） |
|------|-------------------------------|--------------------------|
| adapter-cline.sh | 出现在"建议架构"图中 | 不存在 |
| adapter-copilot.sh | 出现在"建议架构"图和配置示例中 | 不存在 |
| adapter-cursor.sh | 出现在 Cursor 配置示例中（第 106 行） | 存在，实际路径为 `.baton/adapters/cursor/adapter.sh` |
| adapter-codex.sh | 未直接出现 | 存在，实际路径为 `.baton/adapters/codex/adapter.sh` |

**根因**：研究文档写于 2026-03-03/03-05（baton 早期），当时只有研究和设计建议。实际实现在后续 commit 中走了不同的路径：

- 架构图建议的扁平命名（`adapter-cline.sh`, `adapter-copilot.sh`）→ 实际实现用了分目录结构（`cursor/adapter.sh`, `codex/adapter.sh`）
- 架构图建议支持 Cline 和 Copilot → 实际只实现了 Cursor 和 Codex（scope 收窄到 4 IDE）
- 研究文档后来加了 scope 声明（第 7 行），但没有回过头更新架构图

**结论：代码是权威来源。** 架构图是历史规划遗留，不反映当前实现。文档第 7 行的 scope 声明是正确的，但架构图与之矛盾。

### 5. 命名差异补充说明

研究文档和部分其他文档（如 `ide-capability-matrix.md:33`）仍然使用旧的扁平命名 `adapter-cursor.sh`、`adapter-codex.sh`。实际文件在 `96334d1 refactor: restructure .baton directory` 这个 commit 中被重组为目录结构。这是另一个文档滞后于代码的例子。

(verified: `git log --follow -- .baton/adapters/cursor/adapter.sh` 显示 `96334d1 refactor: restructure .baton directory`)

## Challenge

**Weakest conclusion**: 我判断架构图是"设计建议"而非实现描述，主要依据是 (a) 它出现在标题为"建议的 baton 架构"的 section 下，和 (b) 文件从未存在于 git history 中。我没有检查是否有单独的 branch 或 PR 曾经实际创建过这些文件后又删除——如果存在这样的 branch，它们可能是曾经实现过又被 revert 的功能，而非纯规划。不过这不影响核心结论：当前代码中它们不存在。

## Open Questions

1. **文档是否应该更新？** 架构图中的 `adapter-cline.sh` 和 `adapter-copilot.sh` 容易误导读者（正如这个问题本身所证明的）。建议要么在架构图中标注"未实现"，要么将架构图更新为反映当前实际的 2-adapter 结构。`ide-capability-matrix.md` 中的 `adapter-cursor.sh` 引用也应更新为实际路径 `adapters/cursor/adapter.sh`。

## 批注区

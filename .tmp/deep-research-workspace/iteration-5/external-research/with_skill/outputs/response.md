**Question**: Claude Code Agent Skills 与 Cursor Rules 在技能/规则分发机制上的区别是什么？baton 应如何选择跨 IDE 适配策略？
**Depth**: Deep
**Key finding**: Agent Skills 开放标准已统一 16+ IDE 的技能分发格式，但 "规则"（always-on context）与 "技能"（on-demand capability）是两个正交维度，baton 需要同时适配两者——技能层已经标准化（SKILL.md），规则层仍然碎片化（每个 IDE 有自己的格式）。
**Open questions**: 3 — see end of document

---

## Overview

本调研回答一个设计决策：baton 在跨 IDE 适配时，应该把治理内容（constitution、phase skills）作为 **rules** 分发、作为 **skills** 分发、还是两者兼有？

现代 AI coding IDE 有两个正交的内容注入机制：

```
┌─────────────────────────────────────────────────────────────────┐
│                     IDE 内容注入机制                              │
├──────────────────────┬──────────────────────────────────────────┤
│   Rules（规则）       │   Skills（技能）                          │
│   ─────────────────  │   ──────────────────────────────────     │
│   Always-on context  │   On-demand capability                   │
│   行为约束、编码规范   │   过程性知识、工作流、脚本                  │
│   每次会话都加载      │   Agent 按需激活或用户 /invoke             │
│   格式碎片化          │   Agent Skills 开放标准（SKILL.md）       │
│   IDE 专属配置路径    │   跨 IDE 统一路径                         │
└──────────────────────┴──────────────────────────────────────────┘
```

baton 当前的治理内容涵盖两个维度：
- **Constitution**（`constitution.md`）→ 属于 rules（每次会话必须加载的行为约束）
- **Phase skills**（`baton-research`, `baton-plan`, `baton-implement`, `baton-review` 等）→ 属于 skills（按需激活的过程性工作流）

---

## Findings

### 1. Agent Skills 开放标准——技能层已统一

2025 年 12 月 Anthropic 发布 Agent Skills 开放标准（[agentskills.io](https://agentskills.io/specification)），截至 2026 年 3 月已被 16+ 工具采纳：

| IDE/Tool | Skills 路径 | 标准兼容 | 备注 |
|----------|-------------|---------|------|
| Claude Code | `.claude/skills/` | ✅ 原生 | 标准发起者，扩展了 `context: fork`、`agent`、`hooks` 等字段 |
| Cursor | `.cursor/skills/` + `.agents/skills/` | ✅ 原生 | v2.4 (2026-02) 正式支持，同时兼容 `.claude/skills/` ([Cursor 2.4 changelog](https://cursor.com/changelog/2-4)) |
| Codex CLI | `.agents/skills/` | ✅ 原生 | 扩展了 `agents/openai.yaml`（UI metadata）([Codex Skills docs](https://developers.openai.com/codex/skills)) |
| Windsurf | `.windsurf/skills/` + `.agents/skills/` | ✅ 原生 | 2026-03-09 加入支持 ([Windsurf Cascade Skills](https://docs.windsurf.com/windsurf/cascade/skills)) |
| GitHub Copilot | `.github/skills/` + `.claude/skills/` + `.agents/skills/` | ✅ 原生 | VS Code + CLI + Coding Agent ([VS Code Skills docs](https://code.visualstudio.com/docs/copilot/customization/agent-skills)) |
| Cline | `.cline/skills/` | ✅ 实验性 | v3.48+ 需手动启用 ([Cline Skills docs](https://docs.cline.bot/customization/skills)) |
| Kiro | `.agents/skills/` | ✅ 原生 | ([Kiro Skills docs](https://kiro.dev/docs/skills/)) |

**核心发现**：`SKILL.md` 格式已成为事实标准，**一个 SKILL.md 文件可在所有支持工具中工作**。每个 IDE 查找的路径不同，但大多数同时扫描 `.agents/skills/`（通用路径）和自家专属路径。

**Progressive disclosure 是统一的加载模型**：
1. **启动时**：仅加载 `name` + `description`（~100 tokens/skill）
2. **激活时**：加载完整 `SKILL.md`（建议 <5000 tokens）
3. **按需**：引用的 `scripts/`、`references/`、`assets/` 文件
(✅ verified: [agentskills.io specification](https://agentskills.io/specification), [Claude Code docs](https://code.claude.com/docs/en/skills))

### 2. Rules 层——仍然碎片化

与技能层的标准化形成对比，规则层的格式和路径在每个 IDE 中都不同：

| IDE | Rules 路径 | 格式 | Always-on 机制 | 特殊限制 |
|-----|-----------|------|---------------|---------|
| Claude Code | `CLAUDE.md`（`@import` 语法） | Markdown | `@` 引入自动加载 | 无显式限制 |
| Cursor | `.cursor/rules/*.mdc` | MDC (Markdown + frontmatter) | `alwaysApply: true` | 无明确字符限制 |
| Codex | `AGENTS.md` (layered) | Markdown | 整个文件始终加载 | 建议简短 |
| Windsurf | `.windsurfrules` + `.windsurf/rules/` | Markdown + frontmatter | "Always On" 模式 | 全局+本地合计 12,000 字符 |
| Cline | `.clinerules/` | Markdown | 全部加载 | 无明确限制 |
| GitHub Copilot | `.github/copilot-instructions.md` | Markdown | 整个文件始终加载 | 无明确限制 |
| Kiro | `.amazonq/rules/` | Markdown | 全部加载 | 无明确限制 |

**核心发现**：没有统一的 "rules" 标准。`AGENTS.md` 曾有成为通用标准的趋势（Codex、Zed、Goose、Roo Code 都支持），但 Claude Code 用 `CLAUDE.md`，Cursor 用 `.cursor/rules/`，Windsurf 用 `.windsurfrules`。

**Cursor 的特殊情况**：Cursor 同时支持 rules（`.cursor/rules/`，带 `globs`、`alwaysApply` 等元数据）和 skills（`.cursor/skills/`，遵循 Agent Skills 标准），两者设计为互补关系：
- Rules = "tells the agent how to **behave**"（行为约束）
- Skills = "tells the agent how to **do something**"（过程知识）
(✅ verified: [Cursor Rules docs](https://cursor.com/docs/context/rules), [Cursor Skills docs](https://cursor.com/docs/context/skills))

### 3. Baton 当前适配架构

Baton 目前的分发机制（✅ verified: `setup.sh:142-182`）：

```
.baton/skills/              ← 源技能目录（8 个技能）
├── using-baton/
├── baton-research/
├── baton-plan/
├── baton-implement/
├── baton-review/
├── baton-debug/
├── baton-subagent/
└── baton-evolve/

setup.sh create_skill_junctions():
  claude|factory → .claude/skills/<skill>/  (NTFS junction)
  cursor         → .cursor/skills/<skill>/  (NTFS junction)
  codex          → .agents/skills/<skill>/  (NTFS junction)
  fallback       → .agents/skills/<skill>/  (always created)
```

对于 constitution（always-on rules）的分发：
- Claude Code: `CLAUDE.md` 中 `@.baton/constitution.md`
- Codex: `AGENTS.md` 中引入 constitution
- Cursor: **缺少对应的 rules 注入**（当前只注入了 skills，未注入 constitution 作为 always-on rule）

(✅ verified: `setup.sh:480-503` inject_claude_md, `setup.sh:360-382` inject_agents_md)

### 4. 关键差异矩阵：Skills vs Rules 分发对比

| 维度 | Agent Skills (SKILL.md) | Rules (各 IDE 自有) |
|------|------------------------|-------------------|
| **标准化程度** | 高——开放标准，16+ IDE | 低——每个 IDE 独立格式 |
| **加载时机** | On-demand（按需） | Always-on（始终加载） |
| **Context 开销** | 低——仅加载 description 直到激活 | 高——每次会话都占 context |
| **适合内容** | 过程性工作流、脚本、参考文档 | 行为约束、编码规范、项目元数据 |
| **分发路径** | 多 IDE 共享 `.agents/skills/` | 每个 IDE 不同路径和格式 |
| **Baton 治理映射** | Phase skills（research/plan/implement/review） | Constitution（cross-phase invariants） |

### 5. 三方生态工具

新兴的第三方分发工具正在桥接 IDE 差异：

| 工具 | 功能 | URL |
|------|------|-----|
| **localskills.sh** | 发布/安装 skills+rules，自动转换格式，支持 8 个 IDE | [localskills.sh](https://localskills.sh) |
| **skills.sh** (Vercel) | Agent Skills 包管理器和目录 | [skills.sh](https://skills.sh/docs) |
| **skillsmp.com** | Agent Skills 市场 | [skillsmp.com](https://skillsmp.com/) |
| **skillshare** (npm) | 跨工具同步 skills | [runkids/skillshare](https://github.com/runkids/skillshare) |

这些工具的存在证实了一个事实：技能层的跨 IDE 分发已经是已解决问题，但规则层仍然需要格式转换。

---

## Synthesis: Baton 跨 IDE 适配策略建议

### 核心洞察

Baton 的治理内容天然分为两层，恰好对应 IDE 的两个注入维度：

```
Constitution (always-on invariants)  →  Rules 层（每个 IDE 用不同格式注入）
Phase skills (on-demand workflows)   →  Skills 层（Agent Skills 标准，一次写入，多处运行）
```

### 建议方案

#### A. Skills 层：维持当前 junction 策略，扩展 fallback 路径

当前 `setup.sh` 的 junction 分发已经是正确策略。建议：

1. **保持** `.baton/skills/` → IDE-specific paths 的 junction 映射
2. **增加** `.agents/skills/` 作为通用 fallback（当前已做 ✅）
3. **新增 IDE 适配时**，只需在 `create_skill_junctions()` 中增加一行路径映射

理由：Agent Skills 标准已统一 SKILL.md 格式，baton 的 skills 不需要任何格式转换，只需要放到正确路径。Junction 比复制更优因为保证单一源。

#### B. Rules 层：需要新增格式适配层

**这是当前 baton 的缺口。** Constitution 作为 always-on 规则，需要为每个 IDE 生成对应格式：

| IDE | 目标格式 | 生成方式 |
|-----|---------|---------|
| Claude Code | `CLAUDE.md` + `@.baton/constitution.md` | ✅ 已有 `inject_claude_md()` |
| Codex | `AGENTS.md` + 引入 constitution | ✅ 已有 `inject_agents_md()` |
| Cursor | `.cursor/rules/baton-constitution.md` + `alwaysApply: true` | **缺失** — 需要新增 |
| Windsurf | `.windsurf/rules/baton-constitution.md` + always-on | 未来扩展 |
| Cline | `.clinerules/baton-constitution.md` | 未来扩展 |
| Copilot | `.github/copilot-instructions.md` 追加 or `.github/rules/` | 未来扩展 |

Cursor 的具体实现建议：
```yaml
# .cursor/rules/baton-constitution.md
---
description: "Baton governance constitution — cross-phase invariants for task sizing, permissions, evidence standards, and completion criteria."
alwaysApply: true
---

<!-- Content from .baton/constitution.md, or @import if supported -->
```

#### C. 不建议的方案：把 constitution 伪装成 skill

将 constitution 作为 `user-invocable: false` 的 skill 发布是技术上可行的（Claude Code 会将 description 始终加载到 context），但这是滥用 skill 机制：
- Constitution 需要 **完整内容** 始终可用，不只是 description
- Progressive disclosure 会导致 constitution 的关键条款在激活前不可见
- 语义错误：skill 是 "能力"，constitution 是 "约束"

#### D. 长期策略建议

```
短期（当前）:
  Skills → junction 到 IDE 专属路径 (已完成)
  Rules  → 为 Cursor 新增 inject_cursor_rules()

中期（6个月）:
  Rules  → 抽象 inject_rules() 函数，按 IDE 生成不同格式
  关注 AGENTS.md 是否成为第二个通用标准

长期（>1年）:
  如果 rules 标准化（类似 Agent Skills 的 "Agent Rules" 标准出现）→ 迁移
  如果不标准化 → 维持 adapter 模式，每个 IDE 一个格式转换
```

---

## Contradictions & Tensions

1. **Cursor 的 dual system 设计 vs 其他 IDE 的单一系统**。Cursor 显式区分 rules 和 skills，但 Claude Code 用 `CLAUDE.md` + skills 隐式区分，Codex 用 `AGENTS.md` + skills 隐式区分。这意味着 "rules vs skills" 的语义边界在不同 IDE 中不完全一致。Baton 不应过度依赖 Cursor 的术语体系。

2. **`.agents/skills/` 的通用性 vs IDE 专属路径的偏好**。虽然多数 IDE 扫描 `.agents/skills/`，但社区文档和 IDE 官方都更推荐使用专属路径（`.claude/skills/`、`.cursor/skills/`）。Baton 当前同时创建两者的策略是正确的。

3. **Progressive disclosure 与 constitution 的矛盾**。Agent Skills 的设计理念是 "只在需要时加载"，但 baton 的 constitution 需要 "始终加载"。这不是一个可以通过技巧解决的矛盾——它们属于不同的内容类型，应该使用不同的分发机制。

---

## Challenge

**最弱结论**：对 Cursor rules 注入的缺失判断。我基于 `setup.sh` 代码确认 Cursor 安装流程中没有 `inject_cursor_rules()` 函数，但可能 Cursor 的 `using-baton` skill 在实践中部分弥补了这个缺口——如果 Cursor 的 skill auto-detection 足够积极，`using-baton` skill 的 description 可能触发自动加载 constitution。不过，这仍然不等价于 always-on rule，因为它依赖 Agent 的判断而非确定性注入。

**我没有验证的**：
- Cursor 的 `.cursor/rules/` 中的 `alwaysApply: true` 文件实际上是否被 100% 注入（vs 有时被截断或忽略）
- Windsurf 的 12,000 字符限制是否会截断 constitution（baton constitution.md 当前约 5,000 字符，应该安全）
- Cline skills 的 "实验性" 状态是否影响 baton skill 的可靠性

---

## Open Questions

1. **Cursor rules 注入的实际可靠性**：`alwaysApply: true` 在 Cursor 中的行为是否完全等价于 Claude Code 的 `CLAUDE.md @import`？社区有 sessionStart hook 被忽略的报告（❓ 来源：`research-ide-hooks.md:98`），rules 是否有类似问题？需要实际测试。

2. **`AGENTS.md` 是否会成为 rules 的通用标准**：Codex、Zed、Goose、Roo Code 都支持 `AGENTS.md`，如果 Claude Code 和 Cursor 也开始支持（Cursor 已部分支持），baton 可能可以简化为只维护 `AGENTS.md` + 技能 junction。目前缺乏足够证据判断这个趋势。

3. **第三方分发工具（localskills.sh 等）对 baton 的价值**：如果 baton 的目标扩展到支持更多 IDE，是否值得使用第三方工具来自动生成 IDE 专属格式，还是应该保持自有的 `setup.sh` adapter 逻辑？这取决于 baton 的用户规模和支持 IDE 数量的增长计划。

---

Sources:
- [Agent Skills Specification](https://agentskills.io/specification)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Cursor Rules Documentation](https://cursor.com/docs/context/rules)
- [Cursor Skills Documentation](https://cursor.com/docs/context/skills)
- [Cursor 2.4 Changelog](https://cursor.com/changelog/2-4)
- [Codex Skills Documentation](https://developers.openai.com/codex/skills)
- [Windsurf Cascade Skills](https://docs.windsurf.com/windsurf/cascade/skills)
- [VS Code Copilot Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Cline Skills Documentation](https://docs.cline.bot/customization/skills)
- [Kiro Skills Documentation](https://kiro.dev/docs/skills/)
- [localskills.sh](https://localskills.sh)
- [skills.sh (Vercel)](https://skills.sh/docs)
- [Cursor Forum: Skills vs Rules Discussion](https://forum.cursor.com/t/questions-regarding-agent-skills-and-its-relationship-with-cursorrules/148080)
- [Agent Skills vs Rules vs Commands (builder.io)](https://www.builder.io/blog/agent-skills-rules-commands)
- [Anthropic Skills Open Standard Announcement](https://aibusiness.com/foundation-models/anthropic-launches-skills-open-standard-claude)
- [GitHub - anthropics/skills](https://github.com/anthropics/skills)

## 批注区

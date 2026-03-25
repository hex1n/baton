**Question**: Claude Code Agent Skills 与 Cursor Rules 在技能/规则分发机制上有何区别？baton 应采取怎样的跨 IDE 适配策略？
**Depth**: Deep
**Key finding**: 两套系统正在快速趋同——Agent Skills 开放标准已被 30+ 工具采纳（含 Cursor），但 Cursor 仍维护独立的 Rules 系统作为 always-on 上下文注入通道。baton 的适配策略应以 Agent Skills 标准路径为主干，辅以 IDE 原生 rules 通道注入 constitution。
**Open questions**: 3 — 见文末

---

## 1. 全景概览

```
                    ┌─────────────────────────────────────┐
                    │     Agent Skills Open Standard       │
                    │  (agentskills.io, Linux Foundation)  │
                    │  SKILL.md + frontmatter + 目录结构    │
                    └───────────┬─────────────────────────┘
                                │ 30+ 工具采纳
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
   Claude Code              Cursor               Codex CLI
   ┌────────────┐      ┌────────────┐      ┌────────────┐
   │ .claude/    │      │ .cursor/    │      │ .agents/    │
   │  skills/    │      │  skills/    │      │  skills/    │
   │  rules/     │      │  rules/     │      │             │
   │ CLAUDE.md   │      │ .cursorrules│      │ AGENTS.md   │
   │ Plugins     │      │ Team Rules  │      │             │
   └────────────┘      └────────────┘      └────────────┘
```

存在两个并行但正在融合的分发维度：
- **技能分发（Skills）**：程序性知识，按需加载，Agent Skills 标准统一
- **规则分发（Rules/Instructions）**：声明性约束，always-on 上下文注入，每个 IDE 自有格式

---

## 2. Agent Skills 开放标准：统一的技能分发

### 标准规范（✅ verified: [agentskills.io/specification](https://agentskills.io/specification)）

| 维度 | 规范要求 |
|------|---------|
| 文件 | `SKILL.md`（必须），YAML frontmatter + Markdown body |
| 必选字段 | `name`（≤64字符，小写+连字符）, `description`（≤1024字符） |
| 可选字段 | `license`, `compatibility`, `metadata`, `allowed-tools`（实验性） |
| 目录结构 | `skill-name/SKILL.md` + 可选 `scripts/`, `references/`, `assets/` |
| 渐进披露 | metadata ~100 tokens → instructions <5000 tokens → 按需加载 references |
| 命名规则 | `name` 必须与父目录名一致 |

### 采纳状况（✅ verified: agentskills.io 首页 logo carousel）

30+ 工具已采纳，包括：Claude Code, Cursor, OpenAI Codex, Gemini CLI, GitHub Copilot, VS Code, Junie (JetBrains), Kiro, Goose, Roo Code, OpenHands, Factory, Databricks, TRAE, Amp, Spring AI 等。

### 各 IDE 的 Skills 存放路径

| IDE | 主路径 | 兼容路径 |
|-----|--------|---------|
| Claude Code | `.claude/skills/` | — |
| Cursor | `.cursor/skills/` | `.claude/skills/`, `.codex/skills/`, `.agents/skills/`（✅ verified: Cursor docs） |
| Codex CLI | `.agents/skills/` | `.codex/skills/` |
| Gemini CLI | `.gemini/skills/` | — |

**关键发现**：Cursor 主动兼容 `.claude/skills/` 和 `.agents/skills/` 路径。这意味着 baton 的 skill junction 即使只写入 `.claude/skills/`，Cursor 也能发现它们。（✅ verified: [cursor.com/help/customization/skills](https://cursor.com/help/customization/skills)）

---

## 3. Claude Code 特有的分发机制

### 3.1 Skills 扩展字段

Claude Code 在 Agent Skills 标准之上扩展了多个 frontmatter 字段（✅ verified: [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)）：

| 扩展字段 | 作用 | Cursor 是否支持 |
|----------|------|----------------|
| `disable-model-invocation` | 禁止 AI 自动调用，仅手动 `/name` | ❓ Cursor docs 提及但未确认行为一致 |
| `user-invocable` | 设为 false 则用户不可见，仅 AI 可调用 | ❌ 未见 Cursor 文档提及 |
| `context: fork` | 在隔离子 agent 中运行 | ❌ Cursor 无此能力 |
| `agent` | 指定子 agent 类型（Explore, Plan 等） | ❌ Cursor 无此能力 |
| `model` | 指定运行时模型 | ❌ Cursor 无此能力 |
| `effort` | 指定推理努力等级 | ❌ Cursor 无此能力 |
| `hooks` | Skill 生命周期内的 hook | ❌ Cursor 无此能力 |
| `allowed-tools` | 限制可用工具 | ❌ Cursor 未确认支持 |

**结论**：Claude Code 的 skill 扩展字段（`context: fork`, `agent`, `model`, `hooks`）是 Claude Code 独有能力，baton 的复杂 skill（如 baton-review 使用 `context: fork`）在 Cursor 上会降级为普通 inline 执行。

### 3.2 CLAUDE.md 规则系统

（✅ verified: [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)）

| 维度 | 机制 |
|------|------|
| 层级 | Managed Policy > Project (`./CLAUDE.md`) > User (`~/.claude/CLAUDE.md`) |
| 导入 | `@path/to/file` 语法，递归深度 ≤5 |
| 条件加载 | `.claude/rules/*.md` 支持 `paths:` frontmatter glob 过滤 |
| 子目录发现 | 编辑子目录文件时自动加载该目录的 CLAUDE.md |
| 企业管控 | Managed CLAUDE.md（不可排除）+ `claudeMdExcludes` 设置 |
| 大小建议 | ≤200 行/文件 |

### 3.3 Plugins 分发

（✅ verified: [code.claude.com/docs/en/plugins](https://code.claude.com/docs/en/plugins)）

Claude Code 独有的打包分发机制：
- 结构：`.claude-plugin/plugin.json` + `skills/` + `agents/` + `hooks/` + `.mcp.json` + `.lsp.json`
- 命名空间：`/plugin-name:skill-name`，避免冲突
- 安装：`npx skills add` 或官方 marketplace 提交
- 企业：managed settings 可强制启用/禁用 plugins

Cursor 和 Codex 均无对等的 plugin 系统。

---

## 4. Cursor 特有的分发机制

### 4.1 Rules 系统

（✅ verified: [cursor.com/docs/rules](https://cursor.com/docs/rules)）

| 维度 | 机制 |
|------|------|
| 文件格式 | `.cursor/rules/*.md` 或 `.mdc`（Markdown + frontmatter） |
| Frontmatter 字段 | `description`, `alwaysApply`, `globs` |
| 四种模式 | Always Apply / Apply Intelligently / Apply to Specific Files / Apply Manually (`@rule-name`) |
| 层级 | Team Rules > Project Rules > User Rules |
| 旧格式 | `.cursorrules`（已废弃，仍可用） |
| AGENTS.md | 支持，子目录继承 |

### 4.2 Rules vs Skills 的分工

（✅ verified: [dev.to/nedcodes/cursor-rules-vs-skills](https://dev.to/nedcodes/cursor-rules-vs-skills-whats-the-actual-difference-383b)，[forum.cursor.com](https://forum.cursor.com/t/skills-vs-commands-vs-rules/148875)）

| 维度 | Rules | Skills |
|------|-------|--------|
| 性质 | 声明性约束 | 程序性工作流 |
| 加载 | Always-on 或 glob 触发 | 按需（AI 判断或 `/name`） |
| 上下文占用 | alwaysApply=true 每次都注入 | 仅激活时加载 |
| 典型用途 | 编码规范、错误处理模式 | 部署流程、代码审查步骤 |
| 迁移 | `/migrate-to-skills` 可转换动态 rules | — |

**关键发现**：Cursor 同时维护 Rules 和 Skills 两套系统。`alwaysApply: true` 的 rules 不会被 skills 取代——它们服务于不同目的。baton 的 constitution 属于 always-on 约束，应走 Rules 通道而非 Skills。

### 4.3 Team Rules 分发

（✅ verified: [cursor.com/enterprise](https://cursor.com/enterprise)，[forum.cursor.com/t/new-team-rules-feature](https://forum.cursor.com/t/new-team-rules-feature/135970)）

- 管理员在 Cursor Dashboard 创建/强制规则
- 支持 enforce（必须应用）和 optional（可选）
- 支持 glob 过滤
- 独立于项目文件，不需要 git 提交

---

## 5. AGENTS.md：第三条通道

（✅ verified: [agents.md](https://agents.md/)）

| 维度 | 机制 |
|------|------|
| 格式 | 纯 Markdown，无必选字段 |
| 治理 | Linux Foundation 下 Agentic AI Foundation |
| 发起方 | OpenAI + Google + Cursor + Factory + Sourcegraph |
| 支持工具 | 25+ 工具原生读取 |
| 发现规则 | 从编辑文件向上遍历目录，最近的优先 |
| 与 Skills 关系 | 互补——AGENTS.md 是 always-on 上下文，Skills 是按需加载 |

**baton 当前状态**：已在 Codex 配置中使用 AGENTS.md（`@.baton/constitution.md`）。（✅ verified: `setup.sh:366-381`）

---

## 6. 分发维度对比总表

| 分发维度 | Claude Code | Cursor | Codex CLI | 标准化程度 |
|----------|------------|--------|-----------|-----------|
| **技能（按需加载）** | `.claude/skills/` | `.cursor/skills/` | `.agents/skills/` | ⭐⭐⭐ Agent Skills 标准 |
| **规则（always-on）** | `CLAUDE.md` + `.claude/rules/` | `.cursor/rules/*.mdc` | `AGENTS.md` | ⭐ 各自独立格式 |
| **导入语法** | `@path` | 无（frontmatter 控制） | `@path`（AGENTS.md 内） | ⭐ 无统一标准 |
| **条件加载** | `paths:` glob in rules | `globs:` in frontmatter | 子目录 AGENTS.md | ⭐ 各有实现 |
| **企业分发** | Managed CLAUDE.md + Plugins | Team Rules Dashboard | — | ⭐ 各自独立 |
| **Plugin 打包** | `.claude-plugin/` + marketplace | ❌ 无 | ❌ 无 | Claude Code 独有 |
| **跨 IDE 兼容路径** | — | 读取 `.claude/skills/`, `.agents/skills/` | — | Cursor 单向兼容 |

---

## 7. 对 baton 跨 IDE 适配策略的分析

### 7.1 baton 当前分发架构

（✅ verified: `setup.sh:142-182`, `setup.sh:348-361`, `setup.sh:364-382`）

```
.baton/skills/（源）
├── junction → .claude/skills/（Claude Code / Factory）
├── junction → .cursor/skills/（Cursor）
├── junction → .agents/skills/（Codex + 通用 fallback）
└── [每个 IDE 都获得相同的 SKILL.md]

.baton/constitution.md（源）
├── CLAUDE.md @import（Claude Code）
├── .cursor/rules/baton.mdc（Cursor，alwaysApply: true）
└── AGENTS.md @import（Codex）
```

### 7.2 策略建议

**A. Skills 分发：junction 三写策略继续有效，但可简化**

当前 baton 向三个路径写 junction：`.claude/skills/`, `.cursor/skills/`, `.agents/skills/`。

鉴于 Cursor 已原生兼容 `.claude/skills/` 和 `.agents/skills/`，理论上可以只写两个路径：
- `.claude/skills/`（Claude Code + Cursor 均可发现）
- `.agents/skills/`（Codex + 其他 Agent Skills 兼容工具）

但 **不建议立即简化**，原因：
1. Cursor 的 `.claude/skills/` 兼容是 fallback，`.cursor/skills/` 仍是其主路径
2. 不同 IDE 的主路径上将来可能有 IDE-specific 行为差异
3. 当前 junction 方案成本极低（junction 不占磁盘空间），收益不值得冒风险

**结论**：维持三路 junction 策略。Agent Skills 标准的趋同让这个方案的未来可移植性很好。

**B. Rules/Constitution 分发：必须走 IDE 原生通道，无法统一**

Constitution（always-on 治理约束）的分发是各 IDE 差异最大的地方：

| IDE | 通道 | 格式要求 |
|-----|------|---------|
| Claude Code | `CLAUDE.md` 中 `@.baton/constitution.md` | Markdown + `@import` |
| Cursor | `.cursor/rules/baton.mdc` | MDC（Markdown + `alwaysApply: true` frontmatter） |
| Codex | `AGENTS.md` 中 `@.baton/constitution.md` | Markdown + `@import` |
| 其他工具 | `AGENTS.md`（通用 fallback） | 纯 Markdown |

baton 当前已为每个 IDE 做了正确的适配。这里 **没有捷径**——always-on 规则注入是各 IDE 的差异化地带，不会短期标准化。

**C. 复杂 Skills 的降级问题**

baton 的 phase skills（baton-review, baton-implement 等）使用了 Claude Code 扩展字段：
- `context: fork`（隔离子 agent 执行）
- `agent: Explore`（指定只读探索 agent）
- `allowed-tools`（工具白名单）
- `user-invocable: false`（仅 AI 可调用）

这些在 Cursor 上会 **静默降级**：
- `context: fork` → 在主线程内联执行（无隔离）
- `agent` → 忽略
- `allowed-tools` → 忽略（所有工具可用）
- `user-invocable: false` → ❓ 行为未确认

**建议**：
1. 在 SKILL.md 的 `compatibility` 字段注明所需能力（Agent Skills 标准支持）
2. 在 skill 内容中加入条件性指引："如果你无法 fork 子 agent，则在当前上下文中执行以下步骤..."
3. 接受降级——baton 的核心价值（write-lock + constitution 强制）不依赖 skill 高级特性

**D. Plugin 分发：Claude Code 独有优势，不影响跨 IDE 策略**

Claude Code 的 Plugin 系统是唯一的标准化打包+marketplace 分发机制。如果 baton 未来要作为通用工具分发，可以考虑：
- 为 Claude Code 用户提供 plugin 格式安装（`/plugin install baton`）
- 但核心仍是 junction-based 本地安装，确保跨 IDE 工作

---

## 8. 矛盾与张力

### 8.1 Agent Skills "统一" vs Rules "各自为政"

Agent Skills 标准在 skills 层面取得了 remarkable 的跨工具共识（30+ 采纳），但 rules/instructions 层面完全碎片化。每个 IDE 都有自己的 always-on 上下文注入格式：

- Claude Code: `CLAUDE.md` + `@import` + `.claude/rules/`
- Cursor: `.cursor/rules/*.mdc` + Team Rules
- Codex: `AGENTS.md`
- Windsurf: `.windsurfrules`

AGENTS.md 试图统一这一层，但它的表达力远弱于 IDE 原生格式（无 frontmatter、无 glob 条件加载、无导入语法）。

**对 baton 的影响**：rules 适配层的维护成本不会消失。每新增一个 IDE 支持，都需要一个新的 constitution 注入路径。但好消息是这个成本很低——每个 IDE 只需几行 setup.sh 代码。

### 8.2 Cursor 的双轨制

Cursor 同时支持 Agent Skills 和自己的 Rules 系统，且明确表示 `alwaysApply: true` rules 不会被 skills 取代。这意味着：

- baton 的 **skills** 可以走标准路径（`.cursor/skills/` 或 `.claude/skills/`）
- baton 的 **constitution** 必须走 `.cursor/rules/baton.mdc`

当前 baton 已正确处理了这种双轨制。

---

## 9. Challenge

**最薄弱的结论**：我声称 Cursor 的 `.claude/skills/` 兼容意味着 baton 的 skill junction 在 Cursor 中"开箱即用"。但我没有实际测试过 Cursor 是否能正确读取通过 NTFS junction 指向的 `.claude/skills/` 目录。NTFS junction 在 Cursor 的文件系统遍历中的行为是 unverified 的。

**我没有检查的**：
1. Cursor Team Rules Dashboard 的 API 或自动化能力——如果 baton 要支持企业 Cursor 部署，可能需要与 Team Rules API 集成
2. Agent Skills 标准的版本演进速度——标准是否会在未来加入 `context: fork` 等能力？如果标准追赶 Claude Code 的扩展，baton 的降级策略可能不再需要

---

## 10. Open Questions

1. **NTFS junction 在 Cursor 中的行为**：Cursor 遍历 `.cursor/skills/` 时是否正确穿透 NTFS junction？需要实测。如果不穿透，需要回退到 copy-mode。
2. **`user-invocable: false` 在 Cursor 中的行为**：baton 的 `using-baton` skill 使用此字段。Cursor 是否会将其暴露在 `/` 菜单中？需要实测。
3. **Agent Skills 标准路线图**：标准是否计划纳入 `context: fork`、`agent`、`hooks` 等 Claude Code 扩展？如果纳入，baton 的多 IDE 兼容性会自动改善。

---

Sources:
- [Agent Skills Open Standard — Specification](https://agentskills.io/specification)
- [Agent Skills Open Standard — Overview](https://agentskills.io)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins)
- [Claude Code Memory (CLAUDE.md) Documentation](https://code.claude.com/docs/en/memory)
- [Cursor Rules Documentation](https://cursor.com/docs/rules)
- [Cursor Skills Documentation](https://cursor.com/help/customization/skills)
- [Cursor Agent Skills Documentation](https://cursor.com/docs/context/skills)
- [AGENTS.md Specification](https://agents.md/)
- [Cursor Rules vs Skills Comparison](https://dev.to/nedcodes/cursor-rules-vs-skills-whats-the-actual-difference-383b)
- [Cursor Team Rules Forum Discussion](https://forum.cursor.com/t/new-team-rules-feature/135970)
- [Cursor Enterprise](https://cursor.com/enterprise)
- [npx skills Tool (Vercel)](https://github.com/vercel-labs/skills)
- [baton setup.sh](../../../../../../../setup.sh) — skill junction 创建逻辑
- [baton docs/research-ide-hooks.md](../../../../../../../docs/research-ide-hooks.md) — 前期 hook 协议调研

## 批注区


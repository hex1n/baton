**Question**: Claude Code Agent Skills 与 Cursor Rules 在技能/规则分发机制上有何区别？baton 应采取什么跨 IDE 适配策略？
**Depth**: Deep
**Key finding**: Agent Skills 开放标准已成为事实上的跨 IDE 技能分发标准（30+ 工具采用），Cursor 已加入该标准。baton 的技能层（SKILL.md）已天然跨 IDE 可用；真正的适配挑战在 hooks 层（IDE 特异性最强）和 rules 层（声明式配置，各 IDE 格式不同）。
**Open questions**: 3 -- see end of document

---

# Claude Code Agent Skills vs Cursor Rules: 技能/规则分发机制对比

## 1. 概览：三层分发模型

在 AI 编码工具生态中，"分发给 AI 的指令" 实际分为三个独立层，每层的跨 IDE 可移植性不同：

| 层 | 作用 | 跨 IDE 标准化程度 | baton 对应组件 |
|---|------|-----------------|---------------|
| **Skills 层** (SKILL.md) | 按需加载的程序性知识 — 告诉 AI "怎么做某件事" | **高** — Agent Skills 开放标准，30+ 工具采用 | `skills/deep-research/`, `skills/using-baton/` 等 |
| **Rules 层** (规则/指令) | 始终生效的声明性约束 — 告诉 AI "必须遵守什么" | **中** — AGENTS.md 趋于标准化，但各 IDE 仍有私有格式 | `constitution.md`, `CLAUDE.md` |
| **Hooks 层** (事件钩子) | 物理强制 — 拦截/允许 AI 的工具调用 | **低** — 协议趋同（exit code 2）但配置格式各异 | `.baton/hooks/write-lock.sh` 等 9 个 hook |

这三层的独立性是关键洞见：**baton 无需在三层采取相同策略**。

---

## 2. Skills 层：Agent Skills 开放标准 — 已收敛

### 2.1 标准概况

Agent Skills 是 Anthropic 于 2025-12 发布的开放标准，现由 agentskills.io 维护。 ✅ [agentskills.io](https://agentskills.io) 首页列出 30+ 采用方。

**核心规范** ✅ [specification](https://agentskills.io/specification)：

```
skill-name/
├── SKILL.md          # 必需：YAML frontmatter + Markdown 指令
├── scripts/          # 可选：可执行脚本
├── references/       # 可选：文档
└── assets/           # 可选：模板、资源
```

Frontmatter 字段：

| 字段 | 必需 | 说明 |
|------|------|------|
| `name` | Yes | 小写字母+连字符，最长 64 字符，须匹配目录名 |
| `description` | Yes | 最长 1024 字符，描述技能做什么、何时使用 |
| `license` | No | 许可证 |
| `compatibility` | No | 环境要求 |
| `metadata` | No | 任意 key-value |
| `allowed-tools` | No | 预授权工具列表（实验性） |

**渐进披露模型**：
1. **元数据** (~100 tokens) — name + description 在启动时加载
2. **指令** (< 5000 tokens 推荐) — SKILL.md body 在技能激活时加载
3. **资源** (按需) — scripts/references/assets 仅在需要时加载

### 2.2 Claude Code 的 Skills 实现

✅ [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)

Claude Code 基于 Agent Skills 标准，并扩展了以下私有功能：

| 扩展功能 | 说明 | 标准兼容性 |
|---------|------|-----------|
| `disable-model-invocation` | 阻止 AI 自动调用，仅用户 `/` 触发 | Claude Code 私有 |
| `user-invocable` | 设为 false 时对用户隐藏，仅 AI 使用 | Claude Code 私有 |
| `context: fork` | 在隔离的 subagent 中执行 | Claude Code 私有 |
| `agent` | 指定 subagent 类型 (Explore, Plan 等) | Claude Code 私有 |
| `model` | 覆盖模型 | Claude Code 私有 |
| `effort` | 覆盖推理 effort 级别 | Claude Code 私有 |
| `hooks` | 技能生命周期 hook | Claude Code 私有 |
| `` !`command` `` | 动态 context 注入 (shell 命令输出替换) | Claude Code 私有 |
| `$ARGUMENTS`, `$ARGUMENTS[N]` | 参数替换 | Claude Code 私有 |

**发现机制**：
- 层级：Enterprise > Personal (`~/.claude/skills/`) > Project (`.claude/skills/`) > Plugin
- 同名时高优先级覆盖低优先级
- 自动发现嵌套目录（monorepo 支持）
- `--add-dir` 附加目录中的 skills 也被发现

**加载时机**：
- 默认情况下，skill descriptions 始终在 context 中（AI 知道有哪些 skills 可用）
- 完整 skill content 仅在被调用时加载
- context budget: 动态 2% 上下文窗口，fallback 16000 字符

### 2.3 Cursor 的 Skills 实现

✅ [cursor.com/docs/context/skills](https://cursor.com/docs/context/skills) — Cursor 2.4 (2026-01) 正式支持 Agent Skills

**发现路径**（三处均自动扫描）：
- `.cursor/skills/`
- `.claude/skills/` (兼容)
- `.agents/skills/` (兼容 Codex)
- `~/.cursor/skills/` (用户级)

**关键事实**：Cursor **已采用 Agent Skills 标准**，同一 SKILL.md 文件无需转换即可在 Cursor 和 Claude Code 中使用。✅ cursor.com/docs/context/skills 确认自动发现 `.claude/skills/`。

**`/migrate-to-skills` 命令**：Cursor 2.4 内置迁移工具，将动态规则 (Apply Intelligently) 转为标准 skills，将 slash commands 转为 `disable-model-invocation: true` 的 skills。

### 2.4 其他 IDE 的 Skills 支持

✅ agentskills.io 列出的采用方包括：

| 工具 | Skills 路径 | 兼容 `.claude/skills/`? |
|------|-----------|----------------------|
| OpenAI Codex | `.agents/skills/` | 需 symlink ❓ |
| Gemini CLI | `.gemini/skills/` ❓ | 未验证 |
| GitHub Copilot / VS Code | `.github/skills/` ❓ | 未验证 |
| JetBrains Junie | 支持 Agent Skills | 未验证 |
| Goose | 支持 Agent Skills | 未验证 |
| Roo Code | 支持 Agent Skills | 未验证 |
| Kiro | 支持 Agent Skills | 未验证 |

### 2.5 Skills 层结论

**Agent Skills 标准是已收敛的跨 IDE 技能分发方案。** baton 的 SKILL.md 文件天然跨 IDE 可用。不需要格式转换。唯一的变量是各 IDE 的 skills 目录路径（`.claude/skills/` vs `.agents/skills/` vs `.cursor/skills/`），可通过 symlink 或多路径安装解决。

---

## 3. Rules 层：声明性指令 — 部分收敛

### 3.1 Cursor Rules 系统

✅ [cursor.com/docs/context/rules](https://cursor.com/docs/context/rules) + ✅ [forum deep dive](https://forum.cursor.com/t/a-deep-dive-into-cursor-rules-0-45/60721)

Cursor 有两套规则系统：

**Legacy: `.cursorrules`** — 单文件，仍可用但不再推荐。

**Current: `.cursor/rules/`** — MDC 格式 (Markdown with Configuration)：

```yaml
---
description: "规则用途描述"
globs: ["src/**/*.ts"]
alwaysApply: false
---

规则内容（Markdown）
```

**四种激活模式**（由 frontmatter 组合决定）：

| 模式 | alwaysApply | description | globs | 激活方式 |
|------|-------------|-------------|-------|---------|
| **Always** | true | 任意 | 忽略 | 每次对话无条件注入 |
| **Auto-Attached** | false | 空 | 指定 | 当引用的文件匹配 glob 时注入 |
| **Agent-Decided** | false | 有 | 空 | AI 根据 description 判断是否相关 |
| **Manual** | false | 空 | 空 | 仅通过 `@rule-name` 显式引用 |

**注入过程**（两阶段）：
1. Stage 1 (Injection): 基于 alwaysApply 或 globs 匹配添加到 system prompt
2. Stage 2 (Activation): 模型对注入的规则做相关性评估

**优先级**：Team Rules > Project Rules > User Rules（冲突时高层级优先）

**分发方式**：
- Git 版本控制（`.cursor/rules/` 提交到仓库）
- GitHub 远程导入（自动同步）
- Team Rules（Team/Enterprise 计划，dashboard 管理）

### 3.2 Claude Code 的 Rules 等价物

Claude Code 没有独立的 "rules" 子系统。等价机制是：

| Cursor Rules 功能 | Claude Code 等价物 |
|-------------------|-------------------|
| Always-Apply rules | `CLAUDE.md` 文件 (`@import` 引用其他文件) |
| File-specific rules (globs) | 无直接等价。最接近的是 `user-invocable: false` 的 skill（AI 自动加载）|
| Agent-Decided rules | `user-invocable: false` 的 skill（AI 根据 description 判断） |
| Manual rules | 无直接等价 |
| Team Rules | Enterprise managed settings |

**CLAUDE.md 层级**：
- Enterprise (managed settings)
- Personal (`~/.claude/CLAUDE.md`)
- Project (`./CLAUDE.md`)
- Nested (子目录 `CLAUDE.md`，操作子目录文件时自动加载)

### 3.3 AGENTS.md — 跨 IDE 指令标准

✅ [agents.md](https://agents.md/) — Google, OpenAI, Cursor, Factory, Sourcegraph 联合推出

**特点**：
- 纯 Markdown，无 frontmatter，无特殊格式要求
- 放在项目根目录或子目录
- 子目录继承父目录，子目录优先
- 已被 60000+ GitHub 仓库采用 ✅ 搜索结果

**支持的 IDE**：GitHub Copilot, Cursor, OpenAI Codex, Google Jules, Aider, Zed 等。

**局限**：
- 无激活条件（没有 globs、alwaysApply 等）
- 无法区分"总是生效"和"按需加载"
- 纯文本 — AI 全量读取，无渐进披露

### 3.4 三种 Rules 格式对比

| 维度 | Cursor Rules (.mdc) | CLAUDE.md | AGENTS.md |
|------|-------------------|-----------|-----------|
| 格式 | YAML frontmatter + Markdown | Markdown + `@import` | 纯 Markdown |
| 条件激活 | globs, alwaysApply, description | 子目录自动发现 | 无 |
| 层级 | Team > Project > User | Enterprise > Personal > Project > Nested | 父目录 > 子目录 |
| 私有字段 | description, globs, alwaysApply | `@import` 指令 | 无 |
| 跨 IDE | 仅 Cursor | 仅 Claude Code/Factory | 广泛（Codex, Copilot, Cursor, Jules 等） |
| 渐进披露 | 有（Agent-Decided 模式） | 无（全量注入） | 无（全量注入） |

### 3.5 Rules 层结论

**Rules 层存在三个并行标准，尚未完全收敛。** AGENTS.md 是最广泛的 LCD（最低公分母）但功能最弱。Cursor Rules 有最强的条件激活能力但仅限 Cursor。CLAUDE.md 是 Claude Code 的原生方案。

baton 当前用 `CLAUDE.md` + `@constitution.md` 作为 rules 入口 — 这仅在 Claude Code 生态可用。跨 IDE 需要额外的 AGENTS.md 或 Cursor Rules 映射。

---

## 4. Hooks 层：物理强制 — 协议趋同，格式各异

### 4.1 现状回顾

✅ baton 已有详细的 IDE hook 调研 (`docs/research-ide-hooks.md`)：

- 8/12 主流工具支持 PreToolUse 级硬阻断
- A 类（exit code 2）：Claude Code, Factory, Cursor, Windsurf, Augment, Kiro — 核心脚本直接可用
- B 类（JSON 响应）：Cline, GitHub Copilot — 需薄适配层
- baton 已实现 Cursor adapter (`adapter-cursor.sh`) 和 Codex adapter (`adapter-codex.sh`)

### 4.2 Hooks 层结论

Hooks 层没有统一标准。baton 的现有策略（核心脚本 + IDE adapter 薄层）是正确的架构。**这是跨 IDE 适配中不可避免需要 per-IDE 代码的唯一层。**

---

## 5. baton 当前适配架构分析

### 5.1 baton 当前的三层映射

✅ 基于 codebase 分析（`docs/ide-capability-matrix.md`, `docs/implementation-design.md`, `skills/`, `.baton/`）：

| 层 | Claude Code | Cursor | Codex |
|---|------------|--------|-------|
| **Skills** | `.claude/skills/*/SKILL.md` — 全功能 | 未配置（但 Cursor 2.4 可直接读取 `.claude/skills/`） | `.agents/skills/` — 需 symlink 或复制 |
| **Rules** | `CLAUDE.md` → `@constitution.md` | 无 `.cursor/rules/` 配置 | `AGENTS.md` |
| **Hooks** | 9/9 hooks (`.claude/settings.json`) | 5/9 via `adapter-cursor.sh` | 2/9 experimental via `adapter-codex.sh` |

### 5.2 问题诊断

1. **Skills 层已天然可移植但未被利用**：baton 的 skills（如 `deep-research`, `using-baton`）使用标准 SKILL.md 格式，Cursor 2.4+ 可直接发现并使用，但 baton 的 setup 流程未配置此路径。

2. **Rules 层存在缺口**：constitution.md 通过 `@import` 在 CLAUDE.md 中引用 — 这是 Claude Code 私有机制。在 Cursor 中 constitution 的内容不会自动注入。在 Codex 中靠 AGENTS.md 覆盖但内容可能不同步。

3. **Hooks 层已有 adapter 架构**：write-lock.sh 等核心脚本通过 adapter 层适配不同 IDE，这部分架构合理。

---

## 6. 推荐适配策略

### 6.1 策略总结

| 层 | 策略 | 投入 | 收益 |
|---|------|-----|------|
| **Skills** | **不做转换 — 利用 Agent Skills 标准的天然可移植性** | 低 — setup.sh 增加 symlink/多路径安装 | 高 — baton skills 在 30+ 工具中可用 |
| **Rules** | **双轨：CLAUDE.md (Claude Code 原生) + AGENTS.md (跨 IDE LCD)** | 中 — 维护两份入口文件，但引用同一份 constitution.md | 高 — 覆盖所有 IDE |
| **Hooks** | **保持现有 adapter 架构 — per-IDE 不可避免** | 持续 — 每新增 IDE 需写 adapter | 必需 — 这是 baton 的核心价值（物理写锁） |

### 6.2 Skills 层具体方案

**现状**：baton skills 已在 `.claude/skills/` 和 `skills/`（项目根目录）两处存放。

**方案**：

```
# setup.sh 增加以下逻辑：

# 对 Cursor: 无需额外操作 — Cursor 2.4+ 自动发现 .claude/skills/
# 对 Codex: symlink .agents/skills → .claude/skills (或各 skill 逐个 symlink)
# 对其他 Agent Skills 兼容工具: 各 IDE skills 路径 → .claude/skills
```

**注意**：Claude Code 的私有 frontmatter 扩展（`context: fork`, `agent`, `disable-model-invocation` 等）在其他 IDE 中会被忽略但不会报错 — 这是标准设计的 forward compatibility。baton skills 中使用这些扩展不影响跨 IDE 可用性，只是在非 Claude Code 环境中这些高级功能不生效。

### 6.3 Rules 层具体方案

**方案：Constitution 作为 single source of truth**

```
constitution.md                  # 唯一的规则源 — 已有
CLAUDE.md → @constitution.md     # Claude Code 入口 — 已有
AGENTS.md → 引用 constitution.md  # 跨 IDE 入口 — 需新增
.cursor/rules/baton.mdc          # Cursor 特化入口 — 可选
```

AGENTS.md 内容设计：
```markdown
# Agent Instructions

Read and follow the governance rules in `constitution.md`.

## Quick Summary
[constitution.md 的精简摘要，供不支持文件引用的 IDE 使用]
```

Cursor Rules 方案（可选增强）：
```yaml
# .cursor/rules/baton-governance.mdc
---
description: "Baton governance rules — read constitution.md for full rules"
alwaysApply: true
---
Read and follow governance rules in `constitution.md`.
```

**关键决策**：是否为 Cursor 维护专门的 `.cursor/rules/` 文件？

- **Pro**：可利用 Cursor 的 alwaysApply/globs 条件激活，更精细的 context 控制
- **Con**：额外维护成本，内容可能与 constitution.md 不同步
- **推荐**：初期不做。AGENTS.md + `.claude/skills/` 已覆盖 Cursor。仅当 Cursor 用户反馈 constitution 未被遵守时再加

### 6.4 Hooks 层具体方案

**保持现有架构** — 这是 baton 已经做对的部分：

```
.baton/hooks/write-lock.sh        # 核心逻辑 — exit 0/2
.baton/adapters/cursor/adapter.sh  # Cursor JSON 翻译
.baton/adapters/codex/adapter.sh   # Codex 适配
```

**扩展路径**（按用户需求逐步添加）：
- Windsurf: 直接使用核心脚本（A 类，exit code 2）
- Cline: 新增 adapter（B 类，JSON `{"cancel":true}`）
- GitHub Copilot: 新增 adapter（B 类，JSON `{"permissionDecision":"deny"}`）

### 6.5 setup.sh 改造建议

```bash
# 安装时根据检测到的 IDE 环境：

# 1. Skills: symlink 到各 IDE 的 skills 路径
#    .agents/skills/<skill> → .claude/skills/<skill>  # for Codex
#    .cursor/skills/<skill> → .claude/skills/<skill>  # for Cursor (optional)

# 2. Rules: 生成 AGENTS.md（引用 constitution.md）
#    如果不存在 AGENTS.md → 生成

# 3. Hooks: 根据 IDE 安装对应配置
#    Claude Code → .claude/settings.json (已有)
#    Cursor → .cursor/hooks.json (已有)
#    Codex → .codex/hooks.json (已有)
#    其他 → 按需添加
```

---

## 7. 行业趋势判断

### 7.1 三个标准的演化方向

| 标准 | 当前状态 | 趋势 | baton 影响 |
|------|---------|------|-----------|
| **Agent Skills (SKILL.md)** | 30+ 工具采用，包括所有主要 IDE | 成为事实标准 ✅ | baton skills 已兼容，无需改动 |
| **AGENTS.md** | 60000+ 仓库采用，Linux Foundation 管理 | 成为 "README for agents" 的 LCD | baton 应生成 AGENTS.md 作为跨 IDE 入口 |
| **Cursor Rules (.mdc)** | Cursor 私有，已暗示 skills 替代动态规则 | 可能逐步收窄到 "always-apply 声明性配置" 的利基 | baton 无需投入 .mdc 格式，等 Cursor 进一步收敛 |

### 7.2 "Position Matters" 洞察

一篇分析文章 ✅ [lellansin.github.io](https://lellansin.github.io/2026/01/27/Why-Cursor-Rules-Failed-and-Claude-Skill-Succeeded/) 指出：Anthropic 作为模型提供商（上游位置）推动的 Agent Skills 标准比 Cursor 作为 IDE 应用（下游位置）推动的 Rules 格式更容易获得行业采用。这与实际市场表现一致 — Agent Skills 被 30+ 工具采用，而 .mdc 仍是 Cursor 私有。

**对 baton 的含义**：押注 Agent Skills 标准是低风险策略。即使个别 IDE 有私有扩展，标准的核心（SKILL.md + frontmatter）已足够稳定。

---

## 8. Source Audit

| Claim | Source | How obtained |
|-------|--------|-------------|
| Agent Skills 30+ 工具采用 | [agentskills.io](https://agentskills.io) | ✅ Fetched |
| Agent Skills 规范（frontmatter 字段） | [agentskills.io/specification](https://agentskills.io/specification) | ✅ Fetched |
| Claude Code skills 文档（全部功能） | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | ✅ Fetched |
| Cursor 2.4 支持 Agent Skills | [cursor.com/changelog/2-4](https://cursor.com/changelog/2-4) | ✅ Fetched |
| Cursor 自动发现 .claude/skills/ | [cursor.com/docs/context/skills](https://cursor.com/docs/context/skills) | ✅ Fetched |
| Cursor Rules MDC 格式四种激活模式 | [forum.cursor.com deep dive](https://forum.cursor.com/t/a-deep-dive-into-cursor-rules-0-45/60721) | ✅ Fetched |
| Cursor Rules 两阶段注入 | 同上 | ✅ Fetched |
| AGENTS.md 60000+ 仓库采用 | Web search results | ❓ 未直接验证仓库数量 |
| AGENTS.md 由 Google/OpenAI/Cursor 等联合推出 | [agents.md](https://agents.md/) | ❓ 搜索结果，未 fetch 原站 |
| Codex .agents/skills/ 路径 | Web search: developers.openai.com/codex/skills | ❓ 搜索结果摘要 |
| Cursor /migrate-to-skills 命令 | cursor.com/docs/context/skills fetch result | ✅ Fetched |
| baton 当前 IDE 支持矩阵 | `docs/ide-capability-matrix.md` | ✅ Read |
| baton hooks 调研 | `docs/research-ide-hooks.md` | ✅ Read |
| baton skills 结构 | `skills/*/SKILL.md` | ✅ Read |
| baton 实现设计 | `docs/implementation-design.md` | ✅ Read |
| Cursor Rules 优先级 Team > Project > User | cursor.com/docs/context/rules fetch | ✅ Fetched |
| Claude Code skills context budget 2% | code.claude.com/docs/en/skills fetch | ✅ Fetched |
| "Position Matters" 分析 | [lellansin.github.io](https://lellansin.github.io/2026/01/27/Why-Cursor-Rules-Failed-and-Claude-Skill-Succeeded/) | ✅ Fetched |

---

## 9. Challenge: Weakest Conclusions

1. **"Cursor 自动发现 .claude/skills/ 所以 baton 无需额外配置"** — 这基于 Cursor docs 的描述，但未在实际 Cursor 环境中验证 baton 的 skills（尤其是含 Claude Code 私有 frontmatter 的）是否正确加载。如果 Cursor 对未知 frontmatter 字段报错而非忽略，则需要适配。

2. **"AGENTS.md 引用 constitution.md 可以作为跨 IDE rules 入口"** — 依赖各 IDE 的 AI 是否会主动读取被引用的文件。如果 AI 只读 AGENTS.md 内容而不追踪文件引用，则需要将 constitution 精简版直接内联到 AGENTS.md 中，增加维护成本。

3. **"不需要维护 .cursor/rules/"** — 这是一个节省维护成本的判断，但如果 Cursor 用户占 baton 用户的大多数，不利用 Cursor 的条件激活能力（globs, Agent-Decided）可能导致 constitution 在 Cursor 中被忽略或 context 浪费。

---

## 10. Open Questions

1. **Cursor 对未知 SKILL.md frontmatter 字段的处理行为**：是忽略还是报错？需要在实际 Cursor 环境中测试含 `context: fork`, `agent: Explore` 等 Claude Code 私有字段的 SKILL.md。

2. **AGENTS.md 中的文件引用追踪能力**：各 IDE（尤其 Codex, Copilot）的 AI 是否会根据 AGENTS.md 中的指令去读取 constitution.md？还是只使用 AGENTS.md 自身的文本？这决定了 AGENTS.md 应该是引用还是内联。

3. **Skills 标准的 hooks 扩展可能性**：Agent Skills 标准目前不涉及 hooks。是否有讨论将 hook 配置纳入标准？如果有，baton 的 adapter 架构可能需要调整。

---

## 批注区

# Claude Code Agent Skills vs Cursor Rules: 技能/规则分发机制对比研究

## 研究目的

为 baton 的跨 IDE 适配策略提供决策依据。核心问题：baton 目前通过 junction + adapter 模式跨 IDE 分发 hooks 和 skills，这个架构在 Agent Skills 开放标准日益成熟的背景下是否需要调整？

---

## 1. 两个系统的架构对比

### 1.1 Claude Code: Hooks + Skills 双层架构

Claude Code 有两个独立的扩展机制，职责明确分离：

**Hooks（行为控制层）**
- 配置位置：`.claude/settings.json`（项目级）、`~/.claude/settings.json`（用户级）、managed policy（企业级）
- 事件类型：PreToolUse, PostToolUse, SessionStart, Stop, SubagentStart, SubagentStop, PreCompact, PostCompact, TaskCompleted, PostToolUseFailure, UserPromptSubmit, PermissionRequest, Notification, ConfigChange, InstructionsLoaded, SessionEnd, StopFailure, WorktreeCreate/Remove, Elicitation/ElicitationResult, TeammateIdle
- 通信协议：stdin JSON -> 脚本执行 -> exit code + stdout JSON
- 关键能力：exit code 2 = 硬阻断（deny tool use）; `hookSpecificOutput.permissionDecision` 精确控制; `additionalContext` 注入上下文; `updatedInput` 修改工具输入
- 分发机制：JSON 配置文件，支持 matcher 正则过滤

**Skills（能力扩展层）**
- 配置位置：`.claude/skills/<name>/SKILL.md`（项目级）、`~/.claude/skills/<name>/SKILL.md`（用户级）、plugin skills、enterprise managed
- 发现机制：启动时加载所有 skill 的 name + description（~100 tokens/skill），匹配时才加载完整内容
- 触发方式：Claude 自动匹配 description 加载，或用户 `/skill-name` 手动调用
- 关键 frontmatter 字段（Claude Code 扩展）：
  - `context: fork` — 在隔离子代理中运行
  - `agent: Explore|Plan|general-purpose|<custom>` — 指定子代理类型
  - `disable-model-invocation: true` — 仅手动调用
  - `user-invocable: false` — 仅 AI 自动调用
  - `allowed-tools` — 限制可用工具集
  - `model` — 指定模型
  - `effort` — 指定推理深度
  - `hooks` — 技能生命周期内的 scoped hooks
- 分发机制：文件系统目录，支持 monorepo 嵌套发现、`--add-dir` 动态加载、plugin 命名空间隔离

### 1.2 Cursor: Rules + Hooks + Skills 三层架构

Cursor 的架构更分散，三个机制之间有部分重叠：

**Rules（声明式规则层）**
- 配置位置：`.cursor/rules/*.mdc`（项目级）、User Rules（全局）、Team Rules（企业级 dashboard 管理）
- 四种应用模式：
  - **Always** (`alwaysApply: true`) — 始终注入上下文
  - **Auto-Attach** (`globs: ["**/*.py"]`) — 文件匹配时注入
  - **Agent Requested** (`alwaysApply: false`, 有 description) — AI 根据 description 判断是否加载
  - **Manual** — 用户 `@rule-name` 手动引用
- Frontmatter 字段：`description`, `alwaysApply`, `globs`（仅三个）
- 优先级：Team Rules > Project Rules > User Rules
- 分发机制：git 版本控制 + dashboard 管理 + 远程 GitHub 仓库导入

**Hooks（行为控制层，较新）**
- 配置位置：`.cursor/hooks.json`（项目级）、`~/.cursor/hooks.json`（用户级）、Enterprise MDM、Team（云端分发）
- 事件类型：preToolUse, postToolUse, postToolUseFailure, sessionStart, sessionEnd, stop, subagentStart, subagentStop, beforeShellExecution, afterShellExecution, beforeMCPExecution, afterMCPExecution, beforeReadFile, afterFileEdit, beforeSubmitPrompt, preCompact, afterAgentResponse, afterAgentThought, beforeTabFileRead, afterTabFileEdit
- 通信协议：stdin JSON -> 脚本执行 -> exit code + stdout JSON（exit 2 = block，与 Claude Code 一致）
- 响应格式差异：Cursor 使用 `"permission": "allow|deny|ask"` 而非 Claude Code 的 `"permissionDecision"`

**Skills（能力扩展层，2.4+ 新增）**
- 配置位置：`.agents/skills/`, `.cursor/skills/`, `~/.cursor/skills/`（也兼容 `.claude/skills/`）
- 遵循 Agent Skills 开放标准
- Frontmatter：`name`, `description`, `disable-model-invocation`（Cursor 认可的字段子集）
- 与 Rules 的关系：Skills 用于动态上下文发现和过程性指令；Rules 用于声明式、始终生效的约束。Cursor 2.4 提供了 `/migrate-to-skills` 迁移工具

### 1.3 Agent Skills 开放标准（agentskills.io）

Anthropic 于 2025 年 12 月发布的跨工具标准，现已被 16+ 工具采纳：

- **核心原则**：一个 Skill = 一个目录 + SKILL.md，无需注册表、网络调用或二进制格式
- **标准 frontmatter**：`name`(必需), `description`(必需), `license`, `compatibility`, `metadata`, `allowed-tools`(实验性)
- **标准目录结构**：`SKILL.md` + 可选 `scripts/`, `references/`, `assets/`
- **渐进式披露**：Level 1 元数据（启动加载 ~100 tokens） -> Level 2 指令（触发时加载） -> Level 3 资源（按需加载）
- **标准发现路径**：`.agents/skills/`（项目级）、`~/.agents/skills/`（用户级）
- **各工具的发现路径兼容**：Claude Code 用 `.claude/skills/`，Cursor 用 `.cursor/skills/` 和 `.agents/skills/`，Codex 用 `.agents/skills/`

---

## 2. 关键差异维度分析

### 2.1 分发机制差异

| 维度 | Claude Code | Cursor | Codex | 开放标准 |
|------|------------|--------|-------|---------|
| **Rules/上下文注入** | CLAUDE.md（`@` 引用） | .mdc 文件（frontmatter 控制） | AGENTS.md（`@` 引用） | 无（不覆盖此层） |
| **Hooks 配置** | `.claude/settings.json` | `.cursor/hooks.json` | `.codex/hooks.json` | 无（不覆盖此层） |
| **Skills 目录** | `.claude/skills/` | `.cursor/skills/` + `.agents/skills/` | `.agents/skills/` | `.agents/skills/` |
| **硬阻断能力** | PreToolUse exit 2 | preToolUse exit 2 | 无（仅 advisory） | 无 |
| **企业分发** | Managed policy | Team Rules dashboard + MDM | 无 | 无 |
| **用户级分发** | `~/.claude/` | `~/.cursor/` | `~/.codex/` | `~/.agents/` |

### 2.2 hooks 协议差异（baton 必须适配的核心差异）

| 协议要素 | Claude Code | Cursor |
|---------|------------|--------|
| 事件名称格式 | PascalCase（`PreToolUse`） | camelCase（`preToolUse`） |
| 阻断响应格式 | `{"hookSpecificOutput":{"permissionDecision":"deny"}}` | `{"permission":"deny"}` |
| 允许响应格式 | exit 0 或 `{"hookSpecificOutput":{"permissionDecision":"allow"}}` | `{"permission":"allow"}` |
| 上下文注入 | stderr 输出 + `additionalContext` | `additional_context` |
| SessionStart 输出 | stderr 显示给 AI | stdout 作为 `additional_context` |
| Stop 输出 | `{"decision":"block","reason":"..."}` 继续对话 | `{"followup_message":"..."}` 触发下一轮 |
| matcher 语法 | `Edit\|Write\|MultiEdit` (settings.json 中) | `Edit` 或 `Write` (hooks.json 中单独条目) |
| 额外能力 | `updatedInput` 修改工具输入 | `updated_input` 修改工具输入 |
| Tab 补全 hooks | 无 | beforeTabFileRead, afterTabFileEdit |
| MCP 专用 hooks | 通过 tool matcher `mcp__*` | beforeMCPExecution, afterMCPExecution 独立事件 |

### 2.3 Skills 标准 vs 各 IDE 扩展

| 特性 | 开放标准 | Claude Code 扩展 | Cursor 扩展 |
|------|---------|-----------------|------------|
| `context: fork` | 无 | 有（子代理隔离） | 无 |
| `agent` 字段 | 无 | 有（指定子代理类型） | 无 |
| `disable-model-invocation` | 无 | 有 | 有 |
| `user-invocable` | 无 | 有 | 无 |
| `model` / `effort` | 无 | 有 | 无 |
| `hooks` (scoped) | 无 | 有（技能生命周期 hooks） | 无 |
| `$ARGUMENTS` 替换 | 无 | 有 | 部分 |
| `!`command`` 动态注入 | 无 | 有 | 无 |
| `${CLAUDE_SKILL_DIR}` | 无 | 有 | 无 |

---

## 3. Baton 当前架构的映射分析

### 3.1 Baton 分发的三类产物

**产物 A：治理规则（constitution.md）**
- Claude Code: `CLAUDE.md` 中 `@.baton/constitution.md`
- Cursor: `.cursor/rules/baton.mdc`（`alwaysApply: true`）
- Codex: `AGENTS.md` 中 `@.baton/constitution.md`
- 现状：**每个 IDE 的注入方式完全不同**，baton 已正确处理

**产物 B：Hooks（行为控制）**
- Claude Code: `.claude/settings.json` -> `run-hook.cmd` -> `dispatch.sh`
- Cursor: `.cursor/hooks.json` -> `adapters/cursor/dispatch.sh`（JSON 协议转换）
- Codex: `.codex/hooks.json` -> `adapters/codex/dispatch.sh`（stderr->stdout 转换 + 能力降级）
- 现状：**adapter 层已经正确处理协议差异**，但 Cursor adapter 还在转换旧的 adapter.sh 格式

**产物 C：Skills（能力扩展）**
- 源：`.baton/skills/` 下 8 个 skill
- 分发：setup.sh 通过 junction 分发到 `.claude/skills/`、`.cursor/skills/`、`.agents/skills/`
- 现状：**所有 IDE 收到相同的 SKILL.md**，其中使用了 Claude Code 专有扩展（如 `normative-status`、`user-invocable`）

### 3.2 当前架构的优势

1. **Junction 分发 = 单源真相**：`.baton/skills/` 是唯一源，所有 IDE 通过 junction 引用，更新自动同步
2. **Adapter 模式 = 协议隔离**：hooks 协议差异被 adapter 层吸收，核心 hooks 不需要知道 IDE 差异
3. **Manifest 路由 = 声明式配置**：新增 hook 只需加 manifest.conf 行 + 脚本 + IDE 注册
4. **能力分级标注**：`[Baton capability: reduced enforcement (Cursor)]` 让用户/AI 知道当前 IDE 的治理能力边界

### 3.3 当前架构的隐患

1. **Skills 的 IDE 专有字段问题**：baton skills 使用了 `normative-status`（非标准字段）和 `user-invocable`（Claude Code 专有），其他 IDE 会忽略这些字段但不会报错——这实际上是安全的降级
2. **Cursor rules 与 skills 的职责重叠**：baton 同时生成了 `.cursor/rules/baton.mdc`（注入 constitution）和 `.cursor/skills/`（注入 phase skills），constitution 属于"始终生效的约束"用 rules 是正确的，phase skills 属于"动态过程性指令"用 skills 也是正确的
3. **缺少 `.agents/skills/` 标准路径支持**：setup.sh 已经分发到 `.agents/skills/`（给 Codex），但对于其他采纳开放标准的 IDE（Windsurf、Gemini CLI 等），这个路径就是入口——baton 已经覆盖了

---

## 4. 策略建议

### 4.1 核心判断：开放标准收敛趋势明确

事实证据：
- ✅ Agent Skills 开放标准已被 16+ 工具采纳（Cursor 2.4、Codex、Windsurf、VS Code Copilot、Gemini CLI 等）
- ✅ `.agents/skills/` 正在成为跨 IDE 的规范发现路径
- ✅ Cursor 2.4 向后兼容 `.claude/skills/` 路径
- ✅ 开放标准的 frontmatter 字段是 Claude Code 扩展字段的严格子集——未知字段被忽略而非报错
- ✅ Hooks 协议方面，Cursor 明确表示 exit code 2 的语义"matches Claude Code behavior for compatibility"

推论：**技能层（Skills）的跨 IDE 兼容性问题已基本由开放标准解决**。差异集中在 hooks 协议和 rules 注入这两个非标准化的层。

### 4.2 Baton 无需改变的部分

| 部分 | 理由 |
|------|------|
| Junction 分发模式 | 单源 → 多 IDE 投射，与开放标准的 "skill = 目录" 理念完全一致 |
| Adapter 层架构 | Hooks 协议差异是 IDE-specific 的，不会被标准化，adapter 是正确抽象 |
| Manifest + dispatch 路由 | 核心 hooks 逻辑与 IDE 无关，这层不需要变 |
| Constitution 注入策略 | 每个 IDE 的 "always-on rules" 机制不同（CLAUDE.md、.mdc、AGENTS.md），需要分别处理 |
| 能力分级标注 | 不同 IDE 的 hook 能力确实不同（Codex 无硬阻断），分级是必要的 |

### 4.3 Baton 可以优化的部分

**优化 1：确保 `.agents/skills/` 作为一等公民路径**

现状：setup.sh 已经分发到 `.agents/skills/`，但逻辑上是 Codex 的 fallback。建议提升为"标准路径——所有 IDE 都分发"的语义，因为越来越多的工具将 `.agents/skills/` 作为首选发现路径。

```
# 当前逻辑（setup.sh line 166-180）
# 只在非 codex IDE 时才创建 .agents/skills fallback
if ! echo " $IDES " | grep -q ' codex '; then
    mkdir -p "$PROJECT_DIR/.agents/skills"
    ...
fi
```

建议改为：无条件分发到 `.agents/skills/`，不再称为 "fallback"。这样任何支持开放标准的新 IDE（无需 baton 显式适配）自动获得 baton skills。

**优化 2：SKILL.md 中区分标准字段和扩展字段**

当前 baton skills 使用的非标准 frontmatter 字段：
- `normative-status` — 纯粹是 baton 内部语义，其他 IDE 忽略无害
- `user-invocable: true` — Claude Code 扩展，其他 IDE 忽略无害

这些在当前实际运行中不会出错（YAML 前端字段的未知 key 被忽略），但如果要让 baton skills 在纯开放标准环境（如 Gemini CLI）中表现最优，可以考虑将 baton 内部字段移到 `metadata` map 下：

```yaml
metadata:
  baton-normative-status: "Authoritative specification for the RESEARCH phase."
```

评估：**优先级低**。当前不会出错，只是语义不够干净。

**优化 3：为新 IDE 提供零配置适配路径**

当前添加新 IDE 支持需要：
1. 写 adapter 脚本（协议转换）
2. 在 setup.sh 中添加 IDE 检测 + 配置生成逻辑
3. 注册到 `SUPPORTED_IDES` 列表

对于支持 Agent Skills 标准但没有 hooks 系统的 IDE（比如某些只读 `.agents/skills/` 的轻量级工具），baton 已经通过 `.agents/skills/` junction 提供了基本支持——这些工具不需要任何 adapter，只需要 skill 内容。

建议：在文档/setup 中明确区分两种适配级别：
- **Level 1（Skills only）**：任何支持 Agent Skills 标准的工具，通过 `.agents/skills/` 自动获得 baton phase skills + constitution（如果 skill 引用了 constitution）
- **Level 2（Full governance）**：需要 hooks adapter + rules 注入的 IDE，提供完整的治理链（write-lock、phase-guide、quality-gate 等）

这个分级已经隐含在 Codex adapter 的 `[Baton capability: rules + guidance only]` 标注中，但可以更显式地建模。

### 4.4 不建议做的事

| 不建议 | 理由 |
|--------|------|
| 试图统一所有 IDE 的 hooks 协议 | Hooks 协议是各 IDE 的 implementation detail，不会被标准化。Adapter 层就是为此存在的 |
| 为每个 IDE 生成不同的 SKILL.md | 会破坏 junction 的单源特性。当前"写标准+扩展字段，不认识的 IDE 忽略"的策略是正确的 |
| 放弃 Cursor rules 注入 constitution | Skills 用于过程性指令，Rules 用于声明式约束——constitution 属于后者。两个通道并行是正确的 |
| 将 hooks 逻辑移入 skills | Hooks 是强制执行层（硬阻断），Skills 是 advisory 层（AI 可以选择忽略）。混合会削弱治理 |

---

## 5. 架构总结：Baton 的三层分发模型

```
┌─────────────────────────────────────────────────────────────┐
│                    .baton/ (Single Source)                   │
│  constitution.md  │  hooks/dispatch.sh  │  skills/*/SKILL.md│
└────────┬──────────┴─────────┬───────────┴────────┬──────────┘
         │                    │                    │
    ╔════╧════╗         ╔════╧════╗         ╔════╧═════════╗
    ║ Rules   ║         ║ Hooks   ║         ║ Skills       ║
    ║ Layer   ║         ║ Layer   ║         ║ Layer        ║
    ╚════╤════╝         ╚════╤════╝         ╚════╤═════════╝
         │                    │                    │
    ┌────┴────┐         ┌────┴────┐         ┌────┴──────────┐
    │per-IDE  │         │per-IDE  │         │STANDARD PATH  │
    │format   │         │adapter  │         │(junction)     │
    └────┬────┘         └────┬────┘         └────┬──────────┘
         │                    │                    │
  ┌──────┼──────┐      ┌─────┼─────┐     ┌──────┼──────────┐
  │      │      │      │     │     │     │      │          │
CLAUDE  .mdc  AGENTS  CC   Cursor Codex .claude .cursor .agents
.md            .md   hooks  hooks hooks /skills /skills /skills
```

- **Rules 层**：IDE-specific，不可标准化，每个 IDE 需要独立的注入策略
- **Hooks 层**：IDE-specific 协议，通过 adapter 层隔离，核心逻辑共享
- **Skills 层**：已标准化（Agent Skills），通过 junction 统一分发到多个标准路径，IDE 扩展字段安全降级

**结论：Baton 的当前架构与行业演进方向一致。** 不需要架构重构，需要的是：(1) 将 `.agents/skills/` 从 Codex fallback 提升为一等公民；(2) 明确建模两级适配（skills-only vs full-governance）；(3) 保持 hooks adapter 层应对持续演化的 IDE hooks 协议。

---

## 批注区

Sources:
- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Agent Skills Overview - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Agent Skills Specification - agentskills.io](https://agentskills.io/specification)
- [Hooks - Cursor Docs](https://cursor.com/docs/hooks)
- [Rules - Cursor Docs](https://cursor.com/docs/context/rules)
- [Agent Skills - Cursor Docs](https://cursor.com/docs/skills)
- [Cursor 2.4 Changelog](https://cursor.com/changelog/2-4)
- [Agent Skills - Codex | OpenAI Developers](https://developers.openai.com/codex/skills)
- [Custom instructions with AGENTS.md - Codex | OpenAI Developers](https://developers.openai.com/codex/guides/agents-md)
- [Cascade Skills - Windsurf Docs](https://docs.windsurf.com/windsurf/cascade/skills)
- [Equipping agents for the real world with Agent Skills - Anthropic Engineering](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [GitHub - anthropics/skills](https://github.com/anthropics/skills)

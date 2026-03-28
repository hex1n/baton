# Architecture: runtime-thickness-improvements

**主题**: 实现跨平台真实上下文隔离（三平台对称）
**状态**: `proposed (revision 3)`
**规模**: `Medium`

## 1. 问题重述

**协议层**（`cli-adapter-interface.md`）已明确要求：Evaluator、Verification Explorer 这两个角色
"MUST derive judgment from artifacts only, without inheriting prior role reasoning"。

**现状不对称**：

| 平台 | adapter 文档 | skill 内 dispatch note | 运行时隔离保证 |
|------|-------------|----------------------|--------------|
| Codex | `codex.md` 有完整 spawn_agent 示例 ✅ | baton-evaluator/verifier 有 Codex Note ✅ | 真实（spawn_agent 是 Codex 运行时强制） |
| Cursor | `cursor.md` 有 known limitation ✅ | 无 | 软性（用户手动开新 chat） |
| Claude Code | `claude-code.md` 只说 "Prefer separate contexts" ❌ | 无 CC Note ❌ | 无保证（Skill 工具在当前会话内联执行） |

**不对称的根因**：Claude Code adapter 和 skill 文件缺少对等于 Codex 的具体机制文档。

## 2. 第一性原理拆解

### 2.1 各平台隔离机制对照

| 平台 | 真实隔离机制 | 机制来源 |
|------|------------|---------|
| Claude Code | `Agent` 工具 — 生成零父会话历史的子进程 | Claude Code 运行时 |
| Codex | `spawn_agent({ fork_context: false })` | Codex runtime API |
| Cursor | 手动新建 chat/agent context | 用户纪律（无程序化手段） |

`context: fork` in skill frontmatter：对 Codex/Cursor 是触发语义的信号；对 Claude Code 的 Skill 工具本身**无运行时效果**（Skill 工具始终内联执行）。

### 2.2 约束

- 遵循已有的 Codex 模式：adapter 文档 + skill 内 Execution Note，保持三平台结构对称
- 不改变协议核心
- `.claude/agents/` 是 Claude Code 注册自定义 Agent 子类型的目录（与 `.claude/skills/` 并列，功能不同）
- 为 `.claude/agents/` 设置保底 fallback（`general-purpose` 子类型），避免 CC 版本差异引起的中断

### 2.3 方案选择

**选"Codex 模式对称"**：
- adapter 文档（`claude-code.md`）加 Agent 工具 dispatch 部分，结构与 `codex.md` 对称
- 三个 context:fork skill 各加 "Claude Code Execution Note"，结构与已有 "Codex Execution Note" 对称
- 建立 `.claude/agents/` 目录，链接 evaluator/verifier/explorer，支持 `subagent_type: "baton-evaluator"` 调用

拒绝"只改文档"方案：无运行时效果，不满足 "必须" 要求。
拒绝"只用 general-purpose fallback"方案：可行但丧失语义清晰度，且不能利用 `.claude/agents/` 机制。

## 3. 推荐架构

**核心原则**：三平台结构对称 — 每个平台都有：adapter 文档机制 + skill 内具体 dispatch note。

### 写入面（12 个文件）

| 文件 | 变更类型 | 内容 |
|------|---------|------|
| `spec/adapters/claude-code.md` | 修改 | 加 "Context Isolation" 节：Agent 工具为 CC 的强制隔离机制，含 preferred/fallback dispatch 示例 |
| `skills/baton-evaluator.md` | 修改 | 加 "Claude Code Execution Note"（结构与现有 Codex Note 对称） |
| `skills/baton-verifier.md` | 修改 | 同上 |
| `skills/baton-explorer.md` | 修改 | 加 CC/Codex/Cursor 三平台 dispatch note（Repo-wide 模式适用） |
| `.claude/agents/baton-evaluator.md` | 新建（symlink） | 链接到 `skills/baton-evaluator.md` |
| `.claude/agents/baton-verifier.md` | 新建（symlink） | 链接到 `skills/baton-verifier.md` |
| `.claude/agents/baton-explorer.md` | 新建（symlink） | 链接到 `skills/baton-explorer.md` |
| `spec/bootstrap/link-skills.sh` | 修改 | 新增 `.claude/agents/` 为同步目标 |
| `spec/bootstrap/check-consistency.sh` | 修改 | 新增不变式 7：`.claude/agents/` context:fork 文件与 skills/ 一致 |

（加上原始已在进行的 4 个变更：baton-explorer.md frontmatter、check-consistency.sh harness→baton、link-skills.sh SKILL.md 支持、改进计划 P1-2 补注）

### Claude Code Execution Note 内容（baton-evaluator 示例）

```markdown
## Claude Code Execution Note

In Claude Code, launch this role as an isolated subagent via the `Agent` tool.
Do NOT invoke inline via the `Skill` tool — that executes within the current
conversation and provides no context isolation.

Preferred (if `.claude/agents/baton-evaluator` is registered):
  Agent(subagent_type: "baton-evaluator",
        prompt: "Evaluate the implementation for task [task-id].")

Fallback (general-purpose, always works):
  Agent(subagent_type: "general-purpose",
        prompt: "You are the Evaluator for the current harness task.
                 Cold-read only:
                 - .harness/requirements.md
                 - .harness/architecture.md
                 - .harness/verification-path.md
                 - the implementation diff from git
                 Do not inherit Generator reasoning or prior conversation history.
                 [follow baton-evaluator skill instructions]")

See spec/adapters/claude-code.md for the full dispatch pattern.
```

### 三平台隔离对称表（实现后）

| 平台 | 机制 | Adapter 文档 | Skill Note |
|------|------|-------------|----------|
| Claude Code | Agent 工具子进程 | `claude-code.md` § Context Isolation | CC Execution Note ✅ |
| Codex | spawn_agent | `codex.md` § Evaluator | Codex Execution Note ✅ |
| Cursor | 手动新 chat | `cursor.md` § Evaluator | Cursor 已知限制（adapter 文档，skill 内不重复） |

Cursor 在 skill 内不加 note，原因：cursor.md 已完整记录，且无程序化机制可文档化。

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 |
|------|------|---------|
| `spec/adapters/claude-code.md` | L1 | 修改 |
| `skills/baton-evaluator.md` | L1 | 修改 |
| `skills/baton-verifier.md` | L1 | 修改 |
| `skills/baton-explorer.md` | L1 | 修改 |
| `.claude/agents/baton-evaluator.md` | L1 | 新建 symlink |
| `.claude/agents/baton-verifier.md` | L1 | 新建 symlink |
| `.claude/agents/baton-explorer.md` | L1 | 新建 symlink |
| `spec/bootstrap/link-skills.sh` | L1 | 修改 |
| `spec/bootstrap/check-consistency.sh` | L1 | 修改 |
| `.claude/skills/baton-*.md` | L2 | 自动同步（已是 symlinks） |
| `.agents/baton-*.md` | L2 | 自动同步（已是 symlinks） |

## 5. 验证策略

- `head -5 skills/baton-evaluator.md` 含 `context: fork`
- `grep "Claude Code Execution Note" skills/baton-evaluator.md skills/baton-verifier.md skills/baton-explorer.md`
- `ls -la .claude/agents/` 含三个 symlinks
- `grep "Agent tool\|Agent(" spec/adapters/claude-code.md`
- `bash spec/bootstrap/check-consistency.sh` 全部不变式（含新增不变式 7）通过

## 6. 风险

| 风险 | 缓解 |
|------|------|
| `.claude/agents/` 在目标 CC 版本中不支持自定义 subagent_type | fallback 模式（general-purpose + skill 内容）文档化，确保降级路径清晰 |
| Cursor 无程序化隔离（已知）| 已有文档；adapter + skill 层都不做虚假保证 |
| link-skills.sh 新增 .claude/agents/ 同步时覆盖用户自定义 agent | .claude/agents/ 文件由 link-skills.sh 管理，与 .claude/skills/ 一致；用户自定义 agent 应放在 ~/.claude/agents/ (user-level) |

## 7. 自我质疑

1. **Cursor 为什么不在 skill 内加 Cursor Note？** Cursor 无程序化 dispatch；在 skill 内加等于又重复一遍 "请手动开新 chat"。cursor.md 已是权威来源，skill 内额外说明带来的是混淆而非价值。
2. **为什么建 .claude/agents/ 而不只用 general-purpose fallback？** general-purpose 需要把完整 skill 内容嵌入 prompt，既冗长又难维护。.claude/agents/ 方案语义清晰、单一来源。
3. **link-skills.sh 已有改动，再加 .claude/agents/ 是否超出写入面？** 否——link-skills.sh 的责任是管理所有分发目标；.claude/agents/ 是一个新的合理目标，属于同一职责域。

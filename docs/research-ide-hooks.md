# AI Coding IDE Hook/Plugin 能力调研

> 调研日期：2026-03-03（初版）/ 2026-03-05（全面刷新）
> 目的：为 baton 的安装分发设计提供依据，确定哪些 IDE 支持 hook 硬阻断写入

## 核心发现

**12 个主流工具中，8 个支持 PreToolUse 级别的 hook 硬阻断**，且协议高度趋同（JSON stdin + exit code 2）。

## Tier 1: 完整 Hook 支持 — 可通过自定义脚本硬阻断写入（8 个）

| 工具 | Hook 事件 | Matcher | 阻断机制 | 配置位置 | SessionStart |
|------|----------|---------|----------|---------|-------------|
| Claude Code | `PreToolUse` | `Write\|Edit` | exit 2 | `.claude/settings.json` | ✅ |
| Factory AI | `PreToolUse` | `Write\|Edit` | exit 2 | `.claude/settings.json` | ✅ |
| Cursor | `preToolUse` | `Write` | exit 2 / `decision:"deny"` | `.cursor/hooks.json` | ✅ `sessionStart` |
| Windsurf | `pre_write_code` | （内置） | exit 2 | `.windsurf/hooks.json` | ❌ |
| Cline | `PreToolUse` | tool=`write_to_file` | `{"cancel":true}` | `.clinerules/hooks/` | ✅ `TaskStart` |
| Augment Code | `PreToolUse` | `str-replace-editor\|save-file` | exit 2 / JSON deny | `~/.augment/settings.json` | ✅ `SessionStart` |
| Amazon Q/Kiro | `PreToolUse` | `fs_write` / `write` | exit 2 | Agent config YAML | ✅ `AgentSpawn` |
| GitHub Copilot | `preToolUse` | `edit` / `create` | `permissionDecision:"deny"` | `.github/hooks/*.json` | ✅ `SessionStart` |

## Tier 2: 部分/静态控制 — 无法执行自定义逻辑（3 个）

| 工具 | 机制 | 限制 |
|------|------|------|
| Zed AI | `always_deny` regex 匹配 | 只能按文件路径静态拒绝，无法动态检查 plan 状态 |
| Roo Code | `fileRegex` 限制 edit 工具组 | 只能按文件类型静态限制，无法执行脚本 |
| OpenAI Codex CLI | 沙盒 `writable_roots` + 审批 | 无自定义 hook，只能限制写入目录和要求交互确认 |

## Tier 3: 无写入阻断能力（2 个）

| 工具 | 原因 |
|------|------|
| Aider | 仅 post-hoc lint/test，写入已发生后才检查 |
| Goose (Block) | 仅 MCP 扩展，无 pre-tool 拦截点 |

---

## 协议趋同分析

8 个 Tier 1 工具采用了高度相似的 hook 协议：

| 方面 | 主流模式 | 变体 |
|------|---------|------|
| 事件名 | `PreToolUse` / `preToolUse` | Windsurf: `pre_write_code` |
| 输入 | JSON via stdin（含 tool name + parameters） | 字段名略有不同 |
| 阻断信号 | exit code 2 | Cline: JSON `cancel:true`; Copilot/Augment: JSON `permissionDecision:"deny"` |
| 配置格式 | JSON 文件 | Kiro: YAML; Cline: 可执行文件命名约定 |
| 配置位置 | 项目根目录下的 dotfile 目录 | `.claude/`, `.cursor/`, `.windsurf/`, `.clinerules/`, `.github/` 等 |

### 阻断协议分类

**A 类：exit code 2（5 个）**
- Claude Code, Factory, Cursor, Windsurf, Augment, Amazon Q/Kiro
- 核心脚本 exit 2 即可直接工作

**B 类：JSON 响应（2 个）**
- Cline: stdout 输出 `{"cancel":true,"errorMessage":"..."}`
- GitHub Copilot: stdout 输出 `{"permissionDecision":"deny","permissionDecisionReason":"..."}`

**结论：** 一个核心 write-lock 脚本（exit 0/2）可直接覆盖 A 类。B 类需要 ~10 行的薄适配层翻译输出格式。

---

## 各工具详细信息

### Claude Code / Factory AI

- **文档**: https://code.claude.com/docs/en/hooks
- **Hook 类型（17 个）**: PreToolUse, PostToolUse, PostToolUseFailure, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, PreCompact, Notification, UserPromptSubmit, PermissionRequest, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove
- **新增（2026-03 确认）**: UserPromptSubmit（✅ 可阻断）, PermissionRequest（✅）, TeammateIdle（✅）, TaskCompleted（✅，baton 已使用 completion-check.sh）, ConfigChange（✅）, WorktreeCreate（✅）, WorktreeRemove（❌ 仅日志）
- **配置格式**:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": ".baton/write-lock.sh"
      }]
    }]
  }
}
```
- **I/O**: JSON stdin, exit code 控制流（0=允许, 2=阻断, 其他=警告）
- **规则系统**: `CLAUDE.md` 文件 `@import`

### Cursor

- **文档**: https://cursor.com/docs/agent/hooks
- **Hook 类型（18 个）**: sessionStart, sessionEnd, preToolUse, postToolUse, postToolUseFailure, subagentStart, subagentStop, beforeShellExecution, afterShellExecution, beforeMCPExecution, afterMCPExecution, beforeReadFile, afterFileEdit, beforeSubmitPrompt, preCompact, stop, afterAgentResponse, afterAgentThought
- **新增/重要**: beforeSubmitPrompt（✅ 等价于 Claude Code 的 UserPromptSubmit，每轮触发）, subagentStart/subagentStop, preCompact, beforeMCPExecution（✅ fail-closed）
- **已知问题**: sessionStart 社区报告 `continue: false` 被忽略，部分版本报 "unknown hook type"。stop 不能阻断（只能返回 followup_message），与 Claude Code Stop 行为不同
- **配置层级**: Enterprise > Team > Project (`.cursor/hooks.json`) > User (`~/.cursor/hooks.json`)
- **配置格式**:
```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [{
      "command": ".baton/adapters/adapter-cursor.sh",
      "type": "command",
      "matcher": "Write",
      "timeout": 30
    }]
  }
}
```
- **I/O**: JSON stdin/stdout, exit 0=允许, exit 2=阻断
- **输出格式**: `{"decision":"allow"|"deny","reason":"..."}`
- **注意**: `afterFileEdit` 仅观察，不能阻断。必须用 `preToolUse`
- **安全模型**: 大部分 hook fail-open；`beforeReadFile`, `beforeMCPExecution` fail-closed
- **额外能力**: prompt-based hooks（LLM 评估自然语言条件）
- **规则系统**: `.cursorrules` 文件

### Windsurf (Codeium)

- **文档**: https://docs.windsurf.com/windsurf/cascade/hooks
- **Hook 类型（12 个）**:
  - Pre-hooks（可阻断）: `pre_read_code`, `pre_write_code`, `pre_run_command`, `pre_mcp_tool_use`, `pre_user_prompt`
  - Post-hooks（仅观察）: `post_read_code`, `post_write_code`, `post_run_command`, `post_mcp_tool_use`, `post_cascade_response`, `post_cascade_response_with_transcript`（2026-02-24 新增，合规审计用）, `post_setup_worktree`（2025-12 新增）
- **配置层级**: System > User (`~/.codeium/windsurf/hooks.json`) > Workspace (`.windsurf/hooks.json`)
- **配置格式**:
```json
{
  "hooks": {
    "pre_write_code": [{
      "command": ".baton/write-lock.sh",
      "show_output": true
    }]
  }
}
```
- **I/O**: JSON stdin（含 `file_path`, `edits` 数组）, exit 2=阻断, stderr 显示给用户
- **特点**: hook 名直接叫 `pre_write_code`，最直观
- **规则系统**: `.windsurfrules` 文件（单文件 6000 字符限制，合计 12000）

### Cline

- **文档**: https://docs.cline.bot/features/hooks/hook-reference
- **Hook 类型（8 个）**: TaskStart, TaskResume, TaskCancel, TaskComplete, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact
- **新增（v3.38.3）**: TaskComplete（可用于 completion-check.sh）, PreCompact
- **配置方式**: 基于文件命名约定
  - 全局: `~/Documents/Cline/Hooks/`
  - 项目: `.clinerules/hooks/`
  - macOS/Linux: 无扩展名可执行文件（如 `PreToolUse`，需 `chmod +x`）
  - Windows: `.ps1` PowerShell 脚本
  - 执行顺序：全局先于项目
- **I/O**: JSON stdin/stdout
```json
// 输入
{"taskId":"...","tool":"write_to_file","parameters":{"path":"src/file.ts","content":"..."}}
// 阻断输出
{"cancel":true,"errorMessage":"Plan not approved."}
// 允许输出
{"cancel":false}
```
- **规则系统**: `.clinerules` 目录

### Augment Code

- **文档**: https://docs.augmentcode.com/cli/hooks
- **Hook 类型**: PreToolUse, PostToolUse, SessionStart, SessionEnd, Stop
- **配置层级**: System (`/etc/augment/settings.json`) > User (`~/.augment/settings.json`)
- **配置格式**:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "str-replace-editor|save-file",
      "hooks": [{
        "type": "command",
        "command": ".baton/write-lock.sh",
        "timeout": 5000
      }]
    }]
  }
}
```
- **I/O**: JSON stdin, exit 2=阻断, JSON 输出 `permissionDecision:"deny"`
- **环境变量**: `AUGMENT_PROJECT_DIR`, `AUGMENT_CONVERSATION_ID`, `AUGMENT_HOOK_EVENT`, `AUGMENT_TOOL_NAME`
- **规则系统**: `.augment/rules/` 目录（markdown 文件）

### Amazon Q Developer / Kiro CLI

- **文档**: https://kiro.dev/docs/cli/hooks/
- **Hook 类型**: AgentSpawn, UserPromptSubmit, PreToolUse, PostToolUse, Stop
- **配置格式**:
```json
{
  "hooks": {
    "preToolUse": [{
      "matcher": "fs_write",
      "command": ".baton/write-lock.sh",
      "timeout_ms": 30000,
      "cache_ttl_seconds": 0
    }]
  }
}
```
- **Matcher 语法**: `fs_write`/`write`（别名）, `@git`（MCP server 工具）, `*`（所有工具）
- **I/O**: JSON stdin, exit 2=阻断（仅 PreToolUse），stderr 返回给 LLM
- **缓存**: `cache_ttl_seconds` 支持 hook 结果缓存
- **规则系统**: `.amazonq/rules/` 目录

### GitHub Copilot

- **文档**:
  - VS Code: https://code.visualstudio.com/docs/copilot/customization/hooks
  - CLI: https://github.blog/changelog/2026-02-25-github-copilot-cli-is-now-generally-available/
- **Hook 类型**:
  - VS Code (Preview): SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, SubagentStart, SubagentStop, Stop
  - CLI: sessionStart, sessionEnd, userPromptSubmitted, preToolUse, postToolUse, errorOccurred
- **配置位置**: `.github/hooks/*.json`（必须在默认分支上才对 Coding Agent 生效）
- **配置格式**:
```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [{
      "type": "command",
      "bash": ".baton/adapters/adapter-copilot.sh",
      "powershell": ".baton/adapters/adapter-copilot.ps1",
      "timeoutSec": 30
    }]
  }
}
```
- **I/O**: JSON stdin/stdout
```json
// 输出
{"permissionDecision":"allow"|"deny"|"ask","permissionDecisionReason":"..."}
```
- **决策值**: `allow`=允许, `deny`=硬阻断, `ask`=弹窗确认
- **可用性**: 需要 Copilot Pro/Pro+, Business, 或 Enterprise 计划
- **规则系统**: `.github/copilot-instructions.md`, `.agent.md` 自定义 agent

### OpenCode

- **文档**: https://opencode.ai/docs/config/
- **Hook 系统**: Plugin API（JS/MJS）
- **Plugin 位置**: `.opencode/plugins/` 或 `~/.config/opencode/plugins/`
- **Hook 事件**: `tool.execute.before`（可阻断）
- **配置格式**: ES Module 导出
```javascript
export const BatonPlugin = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => {
    if (!['edit', 'write', 'create'].includes(input.tool)) return;
    // ... check plan.md + BATON:GO ...
    if (!approved) throw new Error('🔒 Blocked');
  }
});
```
- **规则系统**: instructions 配置（文件路径/glob 模式）

### OpenAI Codex CLI

- **文档**: https://developers.openai.com/codex/cli/
- **Hook 系统**: ❌ 无自定义 hook
- **替代控制**:
  - 沙盒 `sandbox_mode: "workspace-write"` + `writable_roots` 限制写入目录
  - `approval_policy` 控制审批（`untrusted`, `on-request`, `never`）
  - `requirements.toml` 管理员级约束
- **配置位置**: `~/.codex/config.toml`
- **规则系统**: `AGENTS.md`（分层：从仓库根到子目录），`AGENTS.override.md`，Skills（`.agents/skills/`）

### Zed AI

- **文档**: https://zed.dev/docs/ai/tool-permissions
- **Hook 系统**: ❌ 无自定义脚本执行
- **替代控制**: 静态工具权限规则
  - `always_deny`: regex 拒绝特定文件路径
  - `always_confirm`: regex 要求确认
  - 内置安全规则（硬编码，不可覆盖）
- **配置位置**: Zed `settings.json`
- **规则系统**: `.rules`, `.cursorrules`, `CLAUDE.md`, `AGENTS.md`（多格式兼容）

### Goose (Block)

- **文档**: https://github.com/block/goose
- **Hook 系统**: ❌ 无 pre-tool 拦截
- **扩展机制**: 仅 MCP server 扩展
- **配置位置**: `~/.config/goose/config.yaml`
- **规则系统**: `AGENTS.md`, `.gooseignore`, Recipes (YAML)

### Aider

- **文档**: https://aider.chat/docs/usage/lint-test.html
- **Hook 系统**: ❌ 无 pre-tool hook
- **替代控制**: post-hoc lint/test（写入已发生后才检查）
  - `--lint-cmd` / `--auto-lint`
  - `--test-cmd` / `--auto-test`
  - `--git-commit-verify`（默认关闭，aider 默认 `--no-verify`）
- **配置位置**: `.aider.conf.yml`

### Roo Code (Cline fork)

- **文档**: https://docs.roocode.com/
- **Hook 系统**: ❌ 虽然 fork 自 Cline，但未实现 hook（开发中：PR #11579 "Feat/zoe hooks" 已合并 2026-02-18，PR #11663 "Hooks phase 1" 进行中）
- **替代控制**: Custom Modes + `fileRegex` 限制 edit 工具组
- **配置位置**: `.roomodes`（YAML/JSON）
- **规则系统**: `.roo/rules/`, `.roo/rules-{modeSlug}/`, `AGENTS.md`（opt-in）

---

## 对 baton 设计的影响

### 之前的假设（错误）
- 只有 Claude Code / Factory 支持 hook 硬阻断
- 其他 IDE 只能靠规则引导
- 需要为每个 IDE 写独立适配器

### 实际情况
- **8 个工具支持硬阻断**，协议高度趋同
- 核心 write-lock 脚本（exit 0/2）可直接覆盖 5 个工具（A 类：Claude Code, Factory, Windsurf, Augment, Kiro）
- Cursor、Cline、GitHub Copilot 需要薄适配层翻译输出格式（B 类协议）
- OpenCode 独立（JS Plugin API）
- 仅 3 个工具（Codex, Zed, Roo Code）需要降级到规则引导 + git pre-commit（Roo Code hook 开发中）
- 仅 2 个工具（Aider, Goose）完全无法集成写入控制

### 建议的 baton 架构

```
write-lock.sh（核心，exit 0/2）
├── 直接使用：Claude Code, Factory, Cursor*, Windsurf, Augment, Amazon Q/Kiro
├── 薄适配层（~10行，翻译输出格式）：
│   ├── adapter-cline.sh    → {"cancel":true/false}
│   └── adapter-copilot.sh  → {"permissionDecision":"deny"/"allow"}
├── JS Plugin：OpenCode（独立实现，已有）
└── 降级方案：
    ├── 规则注入：Codex (AGENTS.md), Zed (.rules), Roo Code (.roo/rules/)
    └── git pre-commit hook：通用安全网
```

*Cursor 需要验证 exit code 2 是否足够，或是否必须输出 `{"decision":"deny"}` JSON。

---

## 参考链接

- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- [Cursor Agent Hooks](https://cursor.com/docs/agent/hooks)
- [Windsurf Cascade Hooks](https://docs.windsurf.com/windsurf/cascade/hooks)
- [Cline Hook Reference](https://docs.cline.bot/features/hooks/hook-reference)
- [Augment Code CLI Hooks](https://docs.augmentcode.com/cli/hooks)
- [Kiro CLI Hooks](https://kiro.dev/docs/cli/hooks/)
- [GitHub Copilot Hooks (VS Code)](https://code.visualstudio.com/docs/copilot/customization/hooks)
- [OpenAI Codex CLI](https://developers.openai.com/codex/cli/)
- [Zed AI Tool Permissions](https://zed.dev/docs/ai/tool-permissions)
- [Goose Extensions](https://block.github.io/goose/docs/getting-started/using-extensions/)
- [Aider Linting and Testing](https://aider.chat/docs/usage/lint-test.html)
- [Roo Code Documentation](https://docs.roocode.com/)

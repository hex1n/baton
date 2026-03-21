# Baton Plugin Architecture — 从 Junction 到 Claude Code Plugin

**Sizing: Large** — 验证需要多环境（plugin 安装/更新/hooks 触发/跨平台），涉及仓库结构重组 + 现有项目迁移。

**状态: PROPOSING**

---

## 背景

当前 baton v4 使用 junction-based 架构将 skills、hooks、constitution 从 `~/.baton` 映射到每个项目目录。这带来了：

1. **`git clean -fdX` 删除项目文件**（致命 bug）
2. **Junction/symlink/copy-mode 三级降级**（~100 行 junction.sh + setup.sh 中大量条件分支）
3. **settings.json 合并**（依赖 jq，两套模板维护）
4. **跨平台 hook 调用**（bash/cmd/powershell 兼容问题）
5. **self-install 悖论**（在 baton 源码仓库内开发时 BATON_HOME = 源码目录）
6. **setup.sh 683 行**，职责过重

### 核心洞察

Baton 往每个项目投递 4 类东西：

| 投递物 | 跨项目相同？ | 必须在项目目录内？ |
|--------|:----------:|:----------------:|
| Skills | ✅ | ❌ 插件系统可发现 |
| Hooks 脚本 | ✅ | ❌ 可在任何位置 |
| Constitution | ❌ 可定制 | ✅ CLAUDE.md @import |
| Hook 配置 (settings.json) | ✅ | ❌ 插件 hooks.json 自动加载 |

只有 constitution 真正需要在项目目录内。其余 3 类都可以由 Claude Code 插件系统投递。

---

## 插件系统验证（研究证据）

以下证据来自对本机已安装插件的实际文件读取（2026-03-20）：

### Marketplace 注册机制 ✅

- `~/.claude/settings.json` 包含 `extraKnownMarketplaces` 字段，支持自定义 marketplace 注册 ✅ 已读取确认
- autoresearch 插件通过 `{"source": {"source": "github", "repo": "uditgoenka/autoresearch"}}` 注册为自定义 marketplace ✅ 已读取 settings.json
- marketplace 仓库克隆到 `~/.claude/plugins/marketplaces/<name>/` ✅ 已确认目录存在
- 插件缓存在 `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` ✅ 已确认目录存在

### marketplace.json 格式 ✅

```json
// 来源：~/.claude/plugins/marketplaces/autoresearch/.claude-plugin/marketplace.json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "autoresearch",
  "version": "1.7.5",
  "plugins": [{
    "name": "autoresearch",
    "source": "./claude-plugin",     // 相对路径指向插件根
    "category": "productivity"
  }]
}
```

✅ 已读取文件原文确认。单插件 marketplace 模式：`"source": "."` 或 `"source": "./subdir"`。

### plugin.json 格式 ✅

```json
// 来源：~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.5/.claude-plugin/plugin.json
{
  "name": "superpowers",
  "description": "Core skills library...",
  "version": "5.0.5",
  "author": { "name": "Jesse Vincent", "email": "jesse@fsck.com" },
  "repository": "https://github.com/obra/superpowers",
  "license": "MIT",
  "keywords": [...]
}
```

✅ 已读取文件原文确认。

### 插件 hooks.json — 与 settings.json hooks 格式一致 ✅

```json
// 来源：~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.5/hooks/hooks.json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "hooks": [{
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start"
      }]
    }]
  }
}
```

✅ 已读取文件原文确认。`${CLAUDE_PLUGIN_ROOT}` 由 Claude Code 在执行时展开为插件缓存路径。

### Skills 自动发现 ✅

superpowers 插件的 `skills/` 目录包含 14 个 skill 子目录（brainstorming、systematic-debugging、test-driven-development 等），在本会话中均被 Claude Code 自动发现并列入可用 skills。

✅ 已确认：本会话的 system-reminder 中列出了 `superpowers:brainstorming`、`superpowers:test-driven-development` 等 skill。

### 插件目录标准结构 ✅

superpowers 5.0.5 的完整结构（已 `find` 列出）：

```
.claude-plugin/plugin.json          # 插件元数据
hooks/hooks.json                    # hook 声明
hooks/run-hook.cmd                  # polyglot wrapper
hooks/session-start                 # hook 脚本（无 .sh 扩展名）
skills/*/SKILL.md                   # 14 个 skills
commands/*.md                       # 3 个 slash commands
agents/*.md                         # 1 个 agent type
```

✅ 已列出完整目录确认。

### 未验证项 ❓

- `/install-plugin` 命令是否存在 ❓ — 可能需要通过 Claude Code UI 或 `claude plugin add` 安装
- 插件 hooks 是否能与项目 settings.json hooks 共存且不冲突 ❓ — superpowers 只有 SessionStart，未验证多事件场景
- `${CLAUDE_PLUGIN_ROOT}` 是否在所有 shell（cmd/powershell/bash）中都能正确展开 ❓ — superpowers 用引号包裹路径，暗示需要处理空格

---

## 方案

将 baton 重构为 Claude Code Plugin。插件系统自动处理 skills 发现、hooks 加载、版本更新。项目只保留 constitution（治理规则）和 baton-tasks（工作产物）。

### 目标仓库结构

```
github.com/hex1n/baton/
├── .claude-plugin/
│   ├── marketplace.json          # marketplace 注册（baton 仓库 = 单插件 marketplace）
│   └── plugin.json               # 插件元数据
│
├── skills/                       # Claude Code 自动发现
│   ├── baton-research/
│   │   ├── SKILL.md
│   │   └── references/           # skill 引用的辅助文档
│   ├── baton-plan/
│   │   └── SKILL.md
│   ├── baton-implement/
│   │   └── SKILL.md
│   ├── baton-review/
│   │   └── SKILL.md
│   ├── baton-debug/
│   │   └── SKILL.md
│   ├── baton-subagent/
│   │   └── SKILL.md
│   ├── baton-evolve/
│   │   ├── SKILL.md
│   │   └── review-prompt.md
│   └── using-baton/                    # governance 上下文，phase-guide 注入
│       └── SKILL.md
│   # 注：每个 skill 目录可能包含 SKILL.md 之外的辅助文件
│   # （review-prompt.md, template-*.md, references/ 等），均随目录整体迁移
│
├── hooks/                        # Claude Code 通过 hooks.json 自动加载
│   ├── hooks.json                # 声明 8 个事件的 hook 配置
│   ├── run-hook.cmd              # polyglot bash/cmd wrapper
│   ├── dispatch.sh               # 事件分发器（现有架构保留）
│   ├── manifest.conf             # hook 路由表
│   ├── lib/
│   │   └── common.sh             # 共享函数（find_plan, parser_todo_counts 等）
│   ├── write-lock.sh
│   ├── bash-guard.sh
│   ├── phase-guide.sh
│   ├── post-write-tracker.sh
│   ├── quality-gate.sh
│   ├── stop-guard.sh
│   ├── completion-check.sh
│   ├── failure-tracker.sh
│   ├── subagent-context.sh
│   └── pre-compact.sh
│
├── commands/                     # Claude Code slash commands
│   └── baton-init.md             # /baton-init — 项目初始化命令
│
├── templates/
│   └── constitution.md           # constitution 模板
│
├── adapters/                     # 非 Claude Code IDE 适配层
│   ├── cursor/
│   │   ├── setup.sh              # cursor 专用初始化（~100 行）
│   │   └── dispatch.sh
│   └── codex/
│       ├── setup.sh              # codex 专用初始化（~80 行）
│       └── dispatch.sh
│
├── bin/
│   └── baton                     # CLI 入口（精简版）
│
├── install.sh                    # 全局安装脚本（安装 CLI + 注册 marketplace）
├── CLAUDE.md                     # baton 开发者用
└── .baton/
    └── constitution.md           # baton 自身的 constitution
```

### 用户项目结构（安装后）

```
project/
├── .baton/
│   └── constitution.md           # 从 templates/ 复制，可定制
├── baton-tasks/                  # 工作产物（按需创建）
│   └── <topic>/
│       ├── research.md
│       └── plan.md
├── CLAUDE.md                     # 包含 @.baton/constitution.md
└── .gitignore                    # baton-tasks/
```

对比现在每个项目需要：`.baton/` junction + `.claude/skills/baton-*` junctions + `.claude/settings.json` hook 条目 — 插件方案只需要 `.baton/constitution.md` + CLAUDE.md 引用。

### Cursor/Codex 项目结构（安装后）

Cursor 和 Codex 不支持 Claude Code 插件系统，仍需 adapter。Adapter 引用 `$BATON_HOME/hooks/dispatch.sh`（不依赖项目内 hook 文件）：

```
project/
├── .baton/
│   └── constitution.md           # 从 templates/ 复制，可定制
├── .cursor/rules/                # Cursor 规则（adapter.sh 生成）
│   └── baton.mdc
├── .codex/
│   └── hooks.json                # Codex hooks（adapter setup.sh 生成，引用 BATON_HOME）
├── baton-tasks/
├── CLAUDE.md
└── .gitignore
```

Adapter 的 `dispatch.sh` 路径引用从相对路径 `../../hooks/dispatch.sh` 改为 `$BATON_HOME/hooks/dispatch.sh`：
- **优点**：adapter 不依赖项目内的 hook 文件，项目只需 `.baton/constitution.md`
- **约束**：需要 `BATON_HOME` 环境变量已设置（`install.sh` 在 `~/.bashrc` / `~/.zshrc` 中导出）
- **降级**：如果 `BATON_HOME` 未设置，adapter 自动降级到 `$HOME/.baton`（与 `bin/baton` 相同逻辑）

---

## hooks.json 设计

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" PreToolUse"
        }]
      },
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" PreToolUse"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" PostToolUse"
        }]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" SessionStart"
        }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" Stop"
        }]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" PreCompact"
        }]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" SubagentStart"
        }]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" TaskCompleted"
        }]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" PostToolUseFailure"
        }]
      }
    ]
  }
}
```

### SessionStart matcher 设计决策

hooks.json 的 SessionStart 使用 `"matcher": ""`（匹配所有触发类型），而非 superpowers 的 `"matcher": "startup|clear|compact"`。原因：baton 的 phase-guide hook 需要在每次会话恢复时注入 governance 上下文（包括 compact 后的重新注入），空 matcher 确保不遗漏任何需要 governance 的场景。trade-off：可能在不需要 governance 的 session 事件中产生少量额外开销，但 phase-guide 在非 baton 项目中已通过 dispatch.sh 的 constitution 检测跳过（Phase 2 step 11）。

### Hook 脚本适配

当前 hook 脚本通过 `$PWD` 获取项目目录（`BATON_PROJECT_DIR`），通过环境变量 `$BATON_PLAN` 定位 plan 文件。这些在插件模式下完全不变——插件 hooks 的工作目录就是当前项目。

唯一需要改的是 `dispatch.sh` 中的自身路径解析：

```bash
# 现在：
_dir="$(cd "$(dirname "$0")" && pwd)"

# 插件模式下不变——$0 指向插件缓存中的 dispatch.sh
# run-hook.cmd 会用 ${CLAUDE_PLUGIN_ROOT}/hooks/ 路径调用 dispatch.sh
```

`lib/common.sh` 的路径解析也需要适配：

```bash
# 现在：
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
fi

# dispatch.sh 通过 subshell source 各 hook，$0 是 dispatch.sh 的路径
# 所以 $_dir 已经指向 hooks/ 目录，lib/common.sh 相对路径正常工作
```

### run-hook.cmd 适配

```cmd
: << 'CMDBLOCK'
@echo off
REM ${CLAUDE_PLUGIN_ROOT} 由 Claude Code 展开后传入
REM 此处 %~dp0 指向插件缓存中的 hooks/ 目录

set "HOOK_DIR=%~dp0"

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)
where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)
exit /b 0
CMDBLOCK

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"
```

无硬编码路径。`%~dp0` / `$(dirname "$0")` 自动解析到插件缓存目录。

---

## Plugin 元数据

### .claude-plugin/marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "baton",
  "version": "5.0.0",
  "description": "Baton plan-first workflow — research, plan, implement, review with governance hooks",
  "owner": {
    "name": "hex1n",
    "url": "https://github.com/hex1n"
  },
  "plugins": [
    {
      "name": "baton",
      "description": "Plan-first development workflow with research → plan → implement → review phases. Includes governance hooks (write-lock, bash-guard, failure-tracker) and phase skills.",
      "version": "5.0.0",
      "author": {
        "name": "hex1n",
        "url": "https://github.com/hex1n"
      },
      "source": "./",
      "category": "development"
    }
  ]
}
```

### .claude-plugin/plugin.json

```json
{
  "name": "baton",
  "description": "Plan-first development workflow with governance hooks and phase skills",
  "version": "5.0.0",
  "author": {
    "name": "hex1n",
    "url": "https://github.com/hex1n"
  },
  "repository": "https://github.com/hex1n/baton",
  "license": "MIT",
  "keywords": [
    "workflow", "governance", "plan-first", "research",
    "implementation", "review", "hooks", "write-lock"
  ]
}
```

### Marketplace 注册方式

用户安装 baton 插件有两种路径：

**路径 1：使用 Claude Code 内置命令**（推荐）

Phase 0 骨架验证中确认实际命令语法。预期为：
```bash
claude plugin install hex1n/baton
# 或在 Claude Code 内：/install-plugin baton
```

不自行修改 `~/.claude/settings.json` — 使用 Claude Code 提供的插件管理命令，避免造轮子。

**路径 2：手动注册**（降级）

如果内置命令不可用，`install.sh` 向 `~/.claude/settings.json` 写入 `extraKnownMarketplaces` + `enabledPlugins`（jq merge）。此路径仅作为降级方案，Phase 0 验证后决定是否需要。

---

## /baton-init 命令设计

`commands/baton-init.md`：一个 Claude Code slash command，替代 setup.sh 的 Claude Code 部分。

用户在项目中执行 `/baton-init` 后，Claude 执行以下步骤：

1. **检查 constitution**：如果 `.baton/constitution.md` 不存在，从插件 templates/ 复制
2. **注入 CLAUDE.md**：如果 CLAUDE.md 中没有 `@.baton/constitution.md`，添加引用
3. **更新 .gitignore**：添加 `baton-tasks/` 条目
4. **清理旧安装**（迁移）：如果检测到旧 junction/settings.json hook 条目，提示清理

不需要 jq，不需要 settings.json merge，不需要 junction——因为 skills 和 hooks 由插件系统管理。

---

## CLI 精简

`bin/baton` 从当前 393 行精简为 ~150 行：

| 命令 | 变化 |
|------|------|
| `baton init` | Claude Code: 提示用 `/baton-init`。Cursor/Codex: 调用 adapters/ 中的 setup |
| `baton update` | Claude Code: 提示用 `/install-plugin baton`。Cursor/Codex: 更新 adapter 文件 |
| `baton uninstall` | Claude Code: 只删 `.baton/` + CLAUDE.md 引用。Cursor/Codex: 完整清理 |
| `baton doctor` | 检查 constitution 存在 + 插件是否启用 + CLI 与插件版本一致性 |
| `baton status` | 改为从 `$BATON_HOME/hooks/lib/plan-parser.sh` 加载 parser（当前从项目内 `.baton/hooks/lib/` 加载，该路径迁移后不存在） |
| `baton list` | 不变 |

删除的逻辑：
- junction 创建 / 修复 / 检测
- settings.json hook 合并
- copy-mode 处理
- `git clean` 清理
- self-install 检测

---

## 代码变更清单

**删除**（净减少）：

| 文件 | 实际行数 | 操作 |
|------|----------|------|
| `setup.sh` | 683 | **删除**（Claude Code 部分由 /baton-init 替代，Cursor/Codex 部分移入 adapters/） |
| `.baton/hooks/lib/junction.sh` | 36 | **删除** |
| `bin/baton` 精简（393→~150 行） | ~243 | **重写**（含 junction/copy-mode/settings-merge 删除） |
| `bin/baton` 中 `git clean` | 1 | **已删除** |
| `tests/test-junction.sh` | 71 | **删除** |

**移动**（不计入净增减）：

| 文件 | 实际行数 | 操作 |
|------|----------|------|
| `.baton/hooks/` (整个目录，不含 junction.sh) | 1695 | **移动**到仓库根 `hooks/` |
| `.baton/skills/` (整个目录) | 2370 | **移动**到仓库根 `skills/` |
| `.baton/adapters/` | 165 | **移动**到仓库根 `adapters/`（迁移现有 adapter.sh + dispatch.sh） |

**新增**：

| 文件 | 预估行数 | 说明 |
|------|----------|------|
| `.claude-plugin/marketplace.json` | ~20 | marketplace 注册 |
| `.claude-plugin/plugin.json` | ~15 | 插件元数据 |
| `hooks/hooks.json` | ~83 | 8 事件 hook 声明 |
| `commands/baton-init.md` | ~80 | /baton-init slash command |
| `adapters/codex/run-hook.cmd` | ~50 | Codex polyglot wrapper |
| `templates/constitution.md` | ~40 | constitution 模板（从 `.baton/constitution.md` 复制）|
| `adapters/cursor/run-hook.cmd` | ~50 | Cursor polyglot wrapper |

**修改**（随移动一起进行，或就地重写）：

| 文件 | 修改内容 | 对应步骤 |
|------|----------|----------|
| `hooks/dispatch.sh` | 增加 baton-project 检测（`parser_project_root` walk-up + constitution 检查）| Phase 2 step 17 |
| `hooks/phase-guide.sh` | 适配 `_scan_all_skills()` 扫描插件 skills 路径 + 移除 junction 自动创建块 + 命名空间适配 | Phase 2 step 18, 20, 21, 22 |
| `hooks/lib/plan-parser.sh` | 适配 `parser_has_skill()` 增加 `$BATON_PLUGIN_SKILLS_DIR` 搜索路径 | Phase 2 step 19 |
| `install.sh` | 重写：移除 `setup.sh` 调用（92 行→~60 行），优先使用 `claude plugin install`，降级方案才写 settings.json | Phase 3 |
| `bin/baton` | 精简：移除 junction/copy-mode/settings-merge 逻辑（393 行→~150 行）；`status()` 改为从 `$BATON_HOME/hooks/lib/` 加载 parser；`doctor` 增加版本一致性检查 | Phase 3 step 23-25 |
| `adapters/*/dispatch.sh` | 路径引用从 `../../hooks/dispatch.sh` 改为 `$BATON_HOME/hooks/dispatch.sh` | Phase 3 step 28 |

**净效果**：
- 删除：683（setup.sh）+ 36（junction.sh）+ 1（git clean）+ 71（test-junction.sh）= **791 行**
- 新增：~20（marketplace.json）+ ~15（plugin.json）+ ~83（hooks.json）+ ~80（baton-init.md）+ ~40（constitution 模板）+ ~50×2（adapter run-hook.cmd）= **~338 行**
- 重写净减：~243（bin/baton 393→150）+ ~32（install.sh 92→60）= **~275 行**
- **净减 ~728 行**。移动 ~4230 行（不变）。

---

## 环境变量处理

当前 `.claude/settings.json` 中的 `env` 段（如 `BATON_PLAN`）在插件模式下有两种处理方式：

1. **保留在 settings.json 的 env 段**：BATON_PLAN 是项目级配置，继续放在项目的 settings.json 中。插件 hooks 可以读取这些环境变量。
2. **项目级 `.baton/config`**：如果需要更多项目级配置，可以创建一个简单的 key=value 配置文件，hook 脚本启动时读取。

推荐方案 1——迁移时只删除 settings.json 的 `hooks` 段，保留 `env` 段不动：

```json
{
  "env": {
    "ENABLE_CLAUDEAI_MCP_SERVERS": "false",
    "ENABLE_LSP_TOOL": "1",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "35",
    "BATON_PLAN": "baton-tasks/some-topic/plan.md"
  }
}
```

非 baton 环境变量（如 `ENABLE_LSP_TOOL`）保持不变。迁移脚本只匹配并移除包含 `run-hook.cmd` 或 `dispatch.sh` 的 hook 条目。

---

## 迁移策略

### 现有项目迁移

对已用 baton v4 (junction) 的项目：

```bash
# 1. 清理旧 junction 和 hook 配置
baton uninstall

# 2. 安装插件（一次性）
# Claude Code 中: /install-plugin baton

# 3. 重新初始化（只创 constitution + CLAUDE.md）
# Claude Code 中: /baton-init
# 或: baton init
```

### 自动迁移检测

`/baton-init` 和 `baton init` 检测旧安装标志：
- `.baton` 是 junction/symlink → 提示先 `baton uninstall`
- `.claude/settings.json` 包含 `dispatch.sh` 或 `run-hook.cmd` → 提示删除旧 hook 条目
- `.claude/skills/baton-*` 存在 → 提示删除（插件系统已接管）

### baton 源码仓库自身

baton 仓库本身是 marketplace 仓库。开发者在仓库内工作时：
- skills 和 hooks 就在仓库根目录，Claude Code 通过插件加载
- `.baton/constitution.md` 在仓库内（自身的 constitution）
- 不存在 self-install 悖论，因为不需要 junction

---

## 实施步骤

### Phase 0: 插件骨架验证（先验证再重构）

1. 创建最小插件骨架（临时目录）：1 个 skill（hello-world）+ 1 个 hook（SessionStart echo）
2. 注册为 marketplace，安装插件，确认 `claude plugin install` 或等效命令的实际语法
3. 验证 `${CLAUDE_PLUGIN_ROOT}` 在 hook 命令中正确展开（macOS 必测，Windows 有条件测）
4. 确认 skill 命名空间格式（`baton:baton-review` 还是 `/baton-review`），记录实际格式
5. 验证插件 hooks 与项目 settings.json hooks 共存行为
6. 删除骨架，记录验证结果

**Gate**: 步骤 2-4 任一失败 → 停止，重新评估方案

### Phase 1: 仓库结构重组（复制优先，保留旧目录）

7. 创建 `.claude-plugin/marketplace.json` 和 `plugin.json`
8. **复制**（非移动）`.baton/skills/baton-*` → `skills/baton-*`（仓库根）
9. **复制**（非移动）`.baton/hooks/*` → `hooks/*`（仓库根）
10. 创建 `hooks/hooks.json`
11. 更新 `hooks/run-hook.cmd`（已完成 polyglot 修复）
12. 创建 `templates/constitution.md`（从 `.baton/constitution.md` 复制）
13. 创建 `commands/baton-init.md`

> 注：此阶段旧目录 `.baton/hooks/`、`.baton/skills/` 完整保留，确保现有 setup.sh、bin/baton、adapters 不中断。

### Phase 2: Hook 脚本适配

14. 确认 `dispatch.sh` 路径解析在插件缓存目录下正常工作
15. 确认 `lib/common.sh` 相对路径正常
16. 调整 `BATON_PROJECT_DIR` 设置方式（$PWD 应该就是项目目录）
17. **增加 baton-project 检测**：在 `dispatch.sh` 的 `_manifest` 检查后、hook 循环前，先用 `parser_project_root` 向上遍历推导项目根目录，再检查 constitution 是否存在：
    ```bash
    . "$_dir/lib/common.sh"
    _proj_root="$(parser_project_root "$BATON_PROJECT_DIR")"
    [ -f "$_proj_root/.baton/constitution.md" ] || exit 0
    export BATON_PROJECT_DIR="$_proj_root"
    ```
    确保：(a) 非 baton 项目不触发任何 hook；(b) 在子目录中启动 Claude 时仍能正确定位项目根。验证方式：在无 `.baton/` 的项目中触发 PreToolUse，确认 dispatch.sh 直接 exit 0；在 baton 项目的子目录中触发，确认 hooks 正常工作
18. **适配 `_scan_all_skills()`**（phase-guide.sh:72-83）：当前只扫 `$BATON_PROJECT_DIR/{.baton,.claude,.cursor,.agents}/skills/*/`，在插件模式下找不到 skills。需增加对 `${CLAUDE_PLUGIN_ROOT}/skills/` 的扫描（dispatch.sh 可通过 `$_dir/../skills/` 推导插件 skills 路径，并 export 为 `BATON_PLUGIN_SKILLS_DIR`）
19. **适配 `parser_has_skill()`**（lib/plan-parser.sh:204-217）：当前沿项目目录向上遍历 `.baton/skills`、`.claude/skills` 等。需增加 `$BATON_PLUGIN_SKILLS_DIR` 作为额外搜索路径
20. **移除 phase-guide.sh 的 junction 自动创建块**（phase-guide.sh:50-66）：该块 source 了 `junction.sh` 来自动创建 skill junctions。插件模式下不再需要 junction，需删除或条件跳过（检查 `junction.sh` 是否存在）
21. **适配 `using-baton` governance 上下文路径**（phase-guide.sh:28）：当前通过 `$SCRIPT_DIR/../skills/using-baton/SKILL.md` 读取。在插件模式下 `$SCRIPT_DIR` = `<plugin-root>/hooks/`，`../skills/` = `<plugin-root>/skills/` — 路径应正常解析，但需显式验证
22. **适配命名空间**：根据 Phase 0 step 4 的验证结果，更新 phase-guide.sh 中所有 skill 引用格式（如 `/baton-review` → `baton:baton-review`），更新 constitution 和文档中的 skill 引用

### Phase 3: CLI 与 Adapter

23. 重写 `bin/baton`：移除 junction/copy-mode/settings-merge 逻辑
24. **修复 `baton status` 的 parser 路径**：当前从 `$_dir/.baton/hooks/lib/plan-parser.sh` 加载，迁移后改为从 `$BATON_HOME/hooks/lib/plan-parser.sh` 加载（BATON_HOME 指向 baton 仓库根，hooks/ 在仓库根）
25. **修复版本一致性**：`baton doctor` 增加检查——比对 CLI 版本（`$BATON_HOME` 的 git tag）与插件缓存版本（`~/.claude/plugins/cache/baton/*/`），不一致时提示 `baton update`
26. 迁移 `.baton/adapters/cursor/` → `adapters/cursor/`：保留现有 adapter.sh + dispatch.sh，增加 `run-hook.cmd` polyglot wrapper
27. 迁移 `.baton/adapters/codex/` → `adapters/codex/`：保留现有 adapter.sh + dispatch.sh，增加 `run-hook.cmd` polyglot wrapper（.codex/hooks.json 不再写死 `bash`）
28. **适配 adapter 路径引用**：adapter 的 dispatch.sh 当前用 `../../hooks/dispatch.sh`（相对路径引用项目内 hooks），改为引用 `$BATON_HOME/hooks/dispatch.sh`。这使 adapter 自包含于 BATON_HOME，不依赖项目内的 hook 文件
29. 创建 `adapters/cursor/setup.sh` 和 `adapters/codex/setup.sh`（从 setup.sh 提取对应 IDE 部分）

### Phase 4: 测试（Go/No-Go 决策点）

30. 本地注册为 marketplace，安装插件
31. 验证 skills 被正确发现（含命名空间格式验证）
32. 验证 hooks 在 8 个事件上正常触发（重点测试 Windows cmd.exe/PowerShell）
33. 验证 `/baton-init` 工作正常（含命名空间格式）
34. 验证 `baton init --ide cursor` 工作正常
35. 验证 `baton init --ide codex` 工作正常
36. 测试现有项目迁移流程
37. 验证子目录启动时 baton-project 检测正常（walk-up 正确定位项目根）
38. 验证 `baton doctor` 版本一致性检查

**Go/No-Go 检查点**：步骤 30-32 通过后才继续 Phase 5。如果插件方案验证失败（`${CLAUDE_PLUGIN_ROOT}` 不展开、hooks 不触发等），执行回滚：从 `evolve-baseline` 分支恢复。

### Phase 5: 清理（仅在 Phase 4 通过后执行）

39. 删除 `setup.sh`
40. 删除 `junction.sh`
41. 删除旧 `.baton/hooks/`、`.baton/skills/`、`.baton/adapters/` 目录（Phase 1 的复制源）
42. 更新 `.gitignore`
43. 更新 README.md
44. 删除 `tests/test-junction.sh`
45. 更新现有 hook 测试的路径引用

---

## 回滚策略

Phase 1-3 在独立分支 `plugin-architecture` 上进行，不合入 master。

- **Phase 4 验证通过** → 合入 master，执行 Phase 5 清理
- **Phase 4 验证失败** → 不合入，记录失败原因，回退到 junction 方案并修复已知 bug（`git clean` 已删、run-hook.cmd polyglot 已修）

关键：`setup.sh` 和 `junction.sh` 在 Phase 5 才删除，Phase 4 失败时它们仍完整可用。

---

## 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `${CLAUDE_PLUGIN_ROOT}` 不展开 .cmd 文件路径 | hooks 无法定位脚本 | **Phase 0 step 3 提前验证**；降级方案：settings.json 中 hardcode 绝对路径 |
| 插件 hooks 与项目 settings.json hooks 冲突 | 事件重复触发 | **Phase 0 step 5 验证共存行为**；迁移时清理项目 settings.json 中的旧 hook 条目 |
| 非 baton 项目也触发 baton hooks | write-lock 阻断所有非 baton 项目的源码写入（exit 2） | Phase 2 step 17：dispatch.sh 用 `parser_project_root` 向上遍历推导项目根，检查 constitution 存在。✅ 已验证 write-lock.sh:134-138 无 plan 时 exit 2（非 exit 0） |
| Skill 命名空间变化 | phase-guide 输出错误的 skill 引用，用户无法调用 | **Phase 0 step 4 验证实际格式**；Phase 2 step 22 更新所有引用 |
| CLI 与插件版本不一致 | `baton doctor/status` 检查的版本与 Claude 执行的版本不同 | Phase 3 step 25：`baton doctor` 增加版本一致性检查 |
| 迁移过程中仓库中断 | 旧路径的调用方在 Phase 1 后失效 | Phase 1 使用复制（非移动），旧目录在 Phase 5 才删除 |
| Claude Code 更新改变插件 API | 插件失效 | 跟踪 Claude Code changelog；hooks.json 格式已稳定 |
| Cursor/Codex adapter 依赖 BATON_HOME | BATON_HOME 未设置时 adapter 失效 | adapter 降级到 `$HOME/.baton`；install.sh 在 shell profile 中导出 BATON_HOME |
| PortableGit `CreateFileMapping error 5` | hook 启动失败 | hook 脚本 fail-open (trap exit 0)；文档注明 PortableGit 白名单要求 |
| Codex hooks.json 写死 `bash` | Windows 下 Codex hook 不触发 | adapter 统一用 run-hook.cmd polyglot（Phase 3 覆盖） |

---

## 自我质疑

### 最弱假设

**`${CLAUDE_PLUGIN_ROOT}` 在所有 hook 执行上下文中正确展开**。这是整个方案的基石——如果此变量不展开，hooks.json 中的所有命令路径都无效，插件的 hook 系统完全失效。

- 证据来源：superpowers 插件使用相同的 `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd"` 模式 ✅ 已读取 hooks.json
- 未验证场景：cmd.exe 和 PowerShell 中的展开行为 ❓，Claude Code 源码中展开逻辑的实现方式 ❓
- 降级方案：如果不展开，可退回 settings.json hardcode 绝对路径模式（功能等价，仅失去自动路径管理）
- **Phase 0 提前验证**：step 3 在最小骨架上验证此假设，失败则在任何仓库变动之前就终止

### 次弱假设

**Skill 命名空间在迁移后不会破坏现有工作流**。插件模式下 skills 可能变为 `baton:baton-review` 格式，而当前 phase-guide、constitution、用户习惯都使用无前缀的 `/baton-review`。

- 未验证：Claude Code 实际使用的命名空间格式 ❓
- 影响范围：phase-guide.sh（~10 处 skill 引用）、constitution.md、用户文档
- **Phase 0 提前验证**：step 4 确认实际格式

### 第三弱假设

**插件 hooks 与项目 settings.json hooks 不冲突**。迁移期间两套 hooks 可能并存——插件 hooks（来自 hooks.json）和旧的 settings.json hooks。如果 Claude Code 对同一事件同时触发两者，write-lock 可能执行两次、产生重复输出或竞争条件。

- 证据：superpowers 只有 SessionStart hook，未验证多事件共存场景 ❓
- 缓解：迁移流程（baton uninstall）先清理旧 hooks，再安装插件。但用户可能跳过步骤
- **Phase 0 提前验证**：step 5 测试共存行为

### 已知盲区

1. 插件安装命令的具体语法 ❓ — Phase 0 step 2 验证
2. 插件缓存更新机制（Claude Code 何时拉取新版本）❓ — 影响版本更新策略
3. 多插件 hooks 执行顺序 ❓ — 如果用户同时启用 superpowers 和 baton，SessionStart 的执行顺序是否确定

### 框架级反思（来自 Codex 跨模型评审）

**"是否选错了控制点？"** — Codex 指出消灭 junction 可以通过更简单的复制式配置实现，不需要插件架构。评估后决定继续插件方案，原因：自动分发 + 自动更新的价值在多项目场景下大于引入的复杂度。但通过 Phase 0 提前验证 + 使用 Claude 内置插件命令（不造轮子）来控制复杂度。

## 批注区

### 批注 #1（人类）

codex再使用 hook时出现了下面问题 Codex 的 hook 配置把 SessionStart/Stop 都写死成了 bash .baton/adapters/codex/dispatch.sh ...，见 .codex/
hooks.json:8 和 setup.sh:384。
Windows 环境里 bash 实际解析到的是 PortableGit 的 D:\App\PortableGit\bin\bash.exe。
我直接执行同一条命令时，Git Bash 在进入 Baton 逻辑前就先报了 CreateFileMapping ... Win32 error 5。

### 回应 #1

**问题确认**：两个独立问题。

**问题 A：Codex hooks.json 写死 `bash` 命令**

与 Claude Code 的问题完全一致。`.codex/hooks.json:8` 用 `bash .baton/adapters/codex/dispatch.sh`，当 Codex 通过 cmd.exe 执行时找不到 bash。

**插件方案中的解决**：Codex 不支持 Claude Code 插件系统，仍需 adapter。修正如下：

1. `adapters/codex/` 增加 `run-hook.cmd`（polyglot wrapper，与 hooks/ 下的同模式）
2. `.codex/hooks.json` 改为 `.baton/adapters/codex/run-hook.cmd SessionStart`（去掉 `bash` 前缀）
3. `adapters/codex/dispatch.sh` 内部调用 `../../hooks/dispatch.sh` 时也走 polyglot 或直接用绝对路径的 bash

在 plan 的 Phase 3 step 18 中覆盖。

**问题 B：PortableGit bash 的 `CreateFileMapping Win32 error 5`**

这是 MSYS2 / Git Bash 的已知问题——`error 5` = `ERROR_ACCESS_DENIED`，通常由以下原因触发：

- 杀毒软件实时扫描锁住了 MSYS2 的共享内存文件
- 多个 bash 进程并发启动时竞争 `/dev/shm` 映射
- PortableGit 安装目录权限不足（D:\ 盘非管理员写入）

这不是 baton 的 bug，是 PortableGit 环境问题。缓解措施：

1. 排查：杀毒软件白名单 `D:\App\PortableGit\`
2. 排查：以管理员权限运行一次看是否复现
3. 如果是并发问题：Codex 的 hook 有 `"timeout": 30`，序列化执行应该避免竞争
4. **plan 中增加 risk**：PortableGit 环境不稳定时 hooks 应 fail-open（hook 已有 trap + exit 0 保护）

### Plan 修订

根据批注 #1，追加以下改动：

**Phase 3 step 18 扩展**：`adapters/codex/setup.sh` 生成的 `.codex/hooks.json` 必须用 `run-hook.cmd` polyglot 模式，不写死 `bash`。

**风险表已更新**：PortableGit error 5 和 Codex bash 写死问题已纳入主风险表（不再重复）。

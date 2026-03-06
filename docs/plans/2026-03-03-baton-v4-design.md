# Baton v4 改进设计方案

> 日期：2026-03-03
> 基于：[IDE Hook 能力调研](../research-ide-hooks.md)
> 状态：设计中

## 背景

当前 baton 的主要问题：

1. **分发门槛高** — 用户需 clone 仓库 + 手动跑 `setup.sh`，无一行安装体验
2. **多项目管理累** — 每个项目独立复制，升级需逐个项目 re-run setup.sh
3. **IDE 支持不完整** — 只检测第一个 IDE；Cursor/Windsurf/Cline 已有 hook 但未利用
4. **适配器重复实现** — 每个 IDE 各自重新实现 write-lock 逻辑，维护成本高
5. **无健康检查** — 配置漂移（文件被删、新增 IDE）无法自动发现

### 核心发现

IDE hook 调研显示 **8/12 主流工具支持 PreToolUse 级别的硬阻断**，且协议高度趋同（JSON stdin + exit code 2）。这意味着 baton 可以用一个核心脚本 + 极薄适配层覆盖绝大多数工具。

---

## 设计总览

四个改进层，可独立实施：

```
┌─────────────────────────────────────────────┐
│  Layer 1: CLI 分发层                         │
│  install.sh / bin/baton / projects.list      │
├─────────────────────────────────────────────┤
│  Layer 2: IDE 集成层                         │
│  多 IDE 检测 + 统一 hook 协议 + 适配器简化    │
├─────────────────────────────────────────────┤
│  Layer 3: 健康检查层                         │
│  baton doctor / baton status                 │
├─────────────────────────────────────────────┤
│  Layer 4: 通用安全网                         │
│  git pre-commit hook                         │
└─────────────────────────────────────────────┘
```

---

## Layer 1: CLI 分发层

### 1.1 安装入口

```bash
# 一行安装
curl -fsSL https://raw.githubusercontent.com/<org>/baton/master/install.sh | bash

# 或手动
git clone https://github.com/<org>/baton.git ~/.baton
~/.baton/install.sh
```

`install.sh` 做三件事：
1. 确认 `~/.baton/` 是完整仓库（如果不存在则 clone）
2. 创建 `~/.baton/bin/baton` 可执行脚本
3. 将 `~/.baton/bin` 加入 PATH（追加到 `~/.bashrc` / `~/.zshrc`，检测已有则跳过）

### 1.2 CLI 命令

```
baton init [dir]         # 在项目中安装 baton（= setup.sh）
baton update [dir]       # 更新指定项目（= 重新执行 setup.sh）
baton update --all       # 批量更新注册表中所有项目
baton self-update        # git -C ~/.baton pull --ff-only 更新 baton 自身
baton uninstall [dir]    # 从项目中移除 baton（= setup.sh --uninstall）
                         # 清理 .baton/、各 IDE 规则文件、git pre-commit baton 段
                         # settings.json / hooks.json 需用户手动编辑
baton list               # 列出所有已安装项目及版本
baton doctor [dir]       # 检查项目配置健康度（见 Layer 3）
baton status [dir]       # 显示当前 phase 和 plan 状态
```

### 1.3 注册表

```
# ~/.baton/projects.list — 纯文本，一行一个绝对路径
/home/user/project-a
/home/user/work/api-server
/home/user/side-project
```

- `baton init` 时自动追加（去重）
- `baton uninstall` 时自动移除
- `baton update --all` 遍历列表，跳过不存在的路径并提示清理
- `baton list` 读取列表，显示每个项目的 baton 版本和检测到的 IDE

### 1.4 `bin/baton` 脚本结构

~80 行 shell 脚本，零依赖：

```sh
#!/bin/sh
set -eu
BATON_HOME="${BATON_HOME:-$HOME/.baton}"
SETUP="$BATON_HOME/setup.sh"
REGISTRY="$BATON_HOME/projects.list"

case "${1:-help}" in
    init)      bash "$SETUP" "${2:-.}" && registry_add "${2:-.}" ;;
    update)    # --all → 遍历 registry; 否则 bash "$SETUP" "${2:-.}"
    uninstall) bash "$SETUP" --uninstall "${2:-.}" && registry_remove "${2:-.}" ;;
    self-update) git -C "$BATON_HOME" pull --ff-only ;;
    list)      registry_list ;;
    doctor)    doctor "${2:-.}" ;;  # 见 Layer 3
    status)    status "${2:-.}" ;;
    help|*)    usage ;;
esac
```

### 1.5 目录结构

```
~/.baton/                          # = git clone 的仓库本身
├── bin/
│   └── baton                      # CLI 入口，加入 PATH
├── install.sh                     # 全局安装脚本
├── setup.sh                       # 项目安装逻辑（现有，不变）
├── projects.list                  # 注册表
├── .baton/                        # 源文件（复制到项目的来源）
│   ├── write-lock.sh
│   ├── phase-guide.sh
│   ├── stop-guard.sh
│   ├── bash-guard.sh
│   ├── workflow.md
│   ├── workflow-full.md
│   └── adapters/
│       ├── adapter-cursor.sh      # 新增
│       ├── adapter-cline.sh       # 简化
│       ├── adapter-copilot.sh     # 新增
│       └── ...
├── hooks/
│   └── pre-commit                 # git pre-commit hook（见 Layer 4）
├── README.md
└── tests/
```

---

## Layer 2: IDE 集成层

### 2.1 多 IDE 检测

**现状：** `detect_ide()` 返回第一个匹配的 IDE，其余被忽略。

**改造：**

```sh
detect_ides() {
    ides=""
    [ -d "$PROJECT_DIR/.claude" ]      && ides="$ides claude"
    [ -d "$PROJECT_DIR/.cursor" ]      && ides="$ides cursor"
    [ -d "$PROJECT_DIR/.windsurf" ]    && ides="$ides windsurf"
    [ -d "$PROJECT_DIR/.factory" ]     && ides="$ides factory"
    [ -d "$PROJECT_DIR/.clinerules" ]  && ides="$ides cline"
    [ -d "$PROJECT_DIR/.opencode" ]    && ides="$ides opencode"
    [ -d "$PROJECT_DIR/.augment" ]     && ides="$ides augment"
    [ -d "$PROJECT_DIR/.amazonq" ]     && ides="$ides kiro"
    [ -d "$PROJECT_DIR/.github" ]      && ides="$ides copilot"
    [ -f "$PROJECT_DIR/AGENTS.md" ]    && ides="$ides codex"
    [ -z "$ides" ] && ides="claude"  # 默认
    echo "$ides"
}
```

安装时遍历所有检测到的 IDE，逐个配置。输出示例：

```
Installing baton v4.0 into: /home/user/my-project
  Detected IDEs: claude, cursor, copilot
  --- Claude Code ---
  ✓ Hooks configured in .claude/settings.json
  ✓ Added @.baton/workflow.md to CLAUDE.md
  --- Cursor ---
  ✓ Hooks configured in .cursor/hooks.json
  ✓ Created .cursor/rules/baton.mdc
  --- GitHub Copilot ---
  ✓ Hooks configured in .github/hooks/baton.json
  ✓ Updated .github/copilot-instructions.md
  --- Universal ---
  ✓ Installed git pre-commit hook
```

**原则：** 不主动创建 IDE 目录。只有项目里已存在对应目录时才配置。

### 2.2 统一 Hook 协议

调研发现 8 个工具的 hook 协议高度趋同，分两类：

**A 类：exit code 2 协议（5 个工具）**
- Claude Code, Factory, Windsurf, Augment, Amazon Q/Kiro
- 核心 `write-lock.sh`（exit 0 允许, exit 2 阻断）可直接工作

**B 类：需要适配器（3 个工具）**
- Cursor: exit code 2 + 需要输出 `{"decision":"deny"/"allow"}`
- Cline: 需要输出 `{"cancel":true,"errorMessage":"..."}`
- GitHub Copilot: 需要输出 `{"permissionDecision":"deny","permissionDecisionReason":"..."}`

**C 类：独立 API（1 个工具）**
- OpenCode: JS Plugin API，已有 `opencode-plugin.mjs`

### 2.3 适配器架构

```
write-lock.sh（核心，exit 0/2 + stderr 消息）
│
├── 直接使用（A 类，无适配器）
│   ├── Claude Code     .claude/settings.json    → PreToolUse → write-lock.sh
│   ├── Factory         .claude/settings.json    → PreToolUse → write-lock.sh
│   ├── Windsurf        .windsurf/hooks.json     → pre_write_code → write-lock.sh
│   ├── Augment         ~/.augment/settings.json → PreToolUse → write-lock.sh
│   └── Amazon Q/Kiro   agent config             → PreToolUse → write-lock.sh
│
├── 薄适配器（B 类，~10 行，仅翻译输出格式）
│   ├── adapter-cursor.sh   → exit code + {"decision":"deny"/"allow"}
│   ├── adapter-cline.sh    → {"cancel":true/false,"errorMessage":"..."}
│   └── adapter-copilot.sh  → {"permissionDecision":"deny"/"allow"}
│
├── JS Plugin（C 类）
│   └── opencode-plugin.mjs → throw Error / return
│
└── 降级方案（无 hook 能力）
    ├── 规则注入：Codex (AGENTS.md), Zed (.rules), Roo Code (.roo/rules/)
    └── git pre-commit hook（见 Layer 4）
```

### 2.4 各 IDE 配置详情

#### Claude Code / Factory（现有，不变）

配置位置：`.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "sh .baton/phase-guide.sh"}]}],
    "PreToolUse": [{"matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit", "hooks": [{"type": "command", "command": "sh .baton/write-lock.sh"}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "sh .baton/stop-guard.sh"}]}]
  }
}
```

#### Cursor（新增 hook 支持）

配置位置：`.cursor/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{"command": "sh .baton/phase-guide.sh", "timeout": 10}],
    "preToolUse": [{"command": "sh .baton/adapters/adapter-cursor.sh", "matcher": "Write", "timeout": 10}]
  }
}
```

adapter-cursor.sh（~10 行）：

```sh
#!/bin/sh
RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
    printf '{"decision":"allow"}\n'
    exit 0
else
    # 转义 JSON 特殊字符
    REASON=$(printf '%s' "$RESULT" | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"decision":"deny","reason":"%s"}\n' "$REASON"
    exit 2
fi
```

#### Windsurf（从适配器升级为原生 hook）

配置位置：`.windsurf/hooks.json`

```json
{
  "hooks": {
    "pre_write_code": [{"command": "sh .baton/write-lock.sh", "show_output": true}]
  }
}
```

Windsurf 的 `pre_write_code` hook 直接支持 exit code 2 阻断，无需适配器。现有的 `adapter-windsurf.sh` 可以废弃。

#### Cline（简化适配器）

安装方式：adapter-cline.sh 安装到 `.baton/adapters/`，workflow-full.md 复制到 `.clinerules/baton-workflow.md`。
需要创建 `.clinerules/hooks/PreToolUse` 连线文件指向 adapter（当前 setup.sh 未创建，见 A11 修复）。

adapter-cline.sh 简化为 ~15 行：

```sh
#!/bin/sh
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | grep -o '"tool":"[^"]*"' | head -1 | cut -d'"' -f4)

case "$TOOL" in
    write_to_file|replace_in_file|insert_content)
        RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
        EXIT=$?
        if [ "$EXIT" -eq 0 ]; then
            printf '{"cancel":false}\n'
        else
            REASON=$(printf '%s' "$RESULT" | sed 's/"/\\"/g' | tr '\n' ' ')
            printf '{"cancel":true,"errorMessage":"%s"}\n' "$REASON"
        fi
        ;;
    *)
        printf '{"cancel":false}\n'
        ;;
esac
```

#### Augment Code（新增）

配置位置：项目级 `.augment/settings.json` 或用户级 `~/.augment/settings.json`

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "sh .baton/phase-guide.sh"}]}],
    "PreToolUse": [{"matcher": "str-replace-editor|save-file", "hooks": [{"type": "command", "command": "sh .baton/write-lock.sh", "timeout": 5000}]}]
  }
}
```

直接使用 write-lock.sh，无需适配器（exit code 2 协议）。

#### Amazon Q / Kiro（新增）

配置位置：项目 hook 配置

```json
{
  "hooks": {
    "preToolUse": [{"matcher": "fs_write", "command": "sh .baton/write-lock.sh", "timeout_ms": 10000}]
  }
}
```

直接使用 write-lock.sh，无需适配器（exit code 2 协议）。

#### GitHub Copilot（新增）

配置位置：`.github/hooks/baton.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{"type": "command", "bash": "sh .baton/phase-guide.sh", "timeoutSec": 10}],
    "preToolUse": [{"type": "command", "bash": "sh .baton/adapters/adapter-copilot.sh", "timeoutSec": 10}]
  }
}
```

adapter-copilot.sh（~10 行）：

```sh
#!/bin/sh
RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
    printf '{"permissionDecision":"allow"}\n'
else
    REASON=$(printf '%s' "$RESULT" | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$REASON"
fi
```

#### OpenCode（现有，不变）

Plugin 位置：`.opencode/plugins/baton-write-lock.mjs`

已有 `opencode-plugin.mjs`，通过 `tool.execute.before` hook 实现。保持不变。

#### Codex CLI（规则引导）

无 hook 能力。注入规则到 `AGENTS.md`：

```markdown
@.baton/workflow.md
```

#### Zed AI / Roo Code（规则引导）

- Zed：注入到 `.rules` 文件
- Roo Code：注入到 `.roo/rules/baton-workflow.md`

### 2.5 辅助 Hook 脚本

**bash-guard.sh** — Bash 命令写入检测
- Hook 事件：`PreToolUse`（matcher: `Bash`）
- 功能：当 AI 通过 Bash 工具执行写入命令（`sed`, `cat >`, `echo >` 等）时发出警告
- 当前仅配置在 Claude Code/Factory（`PreToolUse` matcher `Bash`）
- 其他支持 shell execution hook 的 IDE（Cursor `beforeShellExecution`, Windsurf `pre_run_command`）可对接，但 stdin JSON 格式不同，需验证兼容性

**stop-guard.sh** — 会话结束检查
- Hook 事件：`Stop`
- 功能：会话结束前检查是否有未完成的 todo 项，提醒 AI 继续或写 Lessons Learned
- 当前仅配置在 Claude Code/Factory
- Cursor 的 `stop` hook 行为不同：不能阻断（只能返回 followup_message），与 Claude Code 的 `Stop`（可阻断）不同
- 其他 IDE（Augment, Kiro）的 `Stop` hook 行为类似 Claude Code，可配置

### 2.7 废弃项

| 文件 | 原因 |
|------|------|
| `adapter-windsurf.sh` | Windsurf 已支持原生 hook（`pre_write_code` + exit code 2），不再需要适配器 |

### 2.8 Workflow 文件选择策略

```
支持 SessionStart hook 的 IDE → 安装 slim 版 workflow.md
不支持的 IDE                  → 安装 full 版 workflow.md（含 phase guidance）
```

支持 SessionStart 的 IDE：Claude Code, Factory, Cursor, Cline（TaskStart）, Augment, Kiro, Copilot
不支持的 IDE：Windsurf, OpenCode, Codex, Zed, Roo Code, Goose, Aider

当项目同时存在多个 IDE 时：
- `.baton/workflow.md` 用 slim 版（只要有一个 IDE 支持 SessionStart）
- 不支持 SessionStart 的 IDE 规则目录下复制 full 版

---

## Layer 3: 健康检查层

### 3.1 `baton doctor`

检测项目配置健康度，发现问题并提供修复建议。

```
$ baton doctor

🔍 Checking baton installation in /home/user/my-project...

  Scripts:
  ✓ write-lock.sh    v3.0 (latest: v3.0)
  ✓ phase-guide.sh   v3.1 (latest: v3.1)
  ✓ stop-guard.sh    v3.0 (latest: v3.0)
  ✓ workflow.md       present

  Detected IDEs:
  ✓ Claude Code      hooks configured in .claude/settings.json
  ⚠ Cursor           .cursor/ exists but no hooks.json — run `baton init` to fix
  ✓ GitHub Copilot   hooks configured in .github/hooks/baton.json

  Rules injection:
  ✓ CLAUDE.md        contains @.baton/workflow.md

  Universal safety net:
  ✓ git pre-commit   hook installed

  Result: 1 warning found. Run `baton init` to auto-fix.
```

检查项：

| 类别 | 检查内容 |
|------|---------|
| 脚本完整性 | write-lock.sh, phase-guide.sh, stop-guard.sh, bash-guard.sh 是否存在、版本是否最新 |
| IDE 配置 | 每个检测到的 IDE 是否已配置 hook（对比已配置 vs 应配置） |
| 新增 IDE | 是否有新的 IDE 目录出现但未配置 baton |
| 规则注入 | CLAUDE.md / AGENTS.md / .cursorrules 等是否包含 workflow 引用 |
| git hook | pre-commit hook 是否安装 |
| 版本一致 | 项目中的脚本版本是否与 ~/.baton/ 中的一致 |

### 3.2 `baton status`

显示当前项目的 baton 工作流状态：

```
$ baton status

📍 Phase: ANNOTATION
   Plan:     plan.md (exists, no BATON:GO)
   Research: research.md (exists)
   Todos:    0/0 (no todolist yet)
```

逻辑复用 phase-guide.sh 的状态检测，但输出面向人类（非 AI agent）。

---

## Layer 4: 通用安全网 — git pre-commit hook

### 4.1 目的

为所有没有 PreToolUse hook 的场景提供兜底保障：
- Tier 2/3 IDE（Codex, Zed, Roo Code, Aider, Goose）
- 直接用编辑器手动编辑时
- Hook-capable IDE 的双重保护

### 4.2 逻辑

```sh
#!/bin/sh
# .git/hooks/pre-commit — baton plan-first enforcement
# ~30 行

# 跳过检查
[ "${BATON_BYPASS:-}" = "1" ] && exit 0

# 检查 staged 文件中是否有非 markdown 文件
HAS_SOURCE=0
for f in $(git diff --cached --name-only --diff-filter=ACM); do
    case "$f" in
        *.md|*.mdx|*.markdown) ;;  # markdown 始终允许
        *) HAS_SOURCE=1; break ;;
    esac
done

[ "$HAS_SOURCE" -eq 0 ] && exit 0  # 纯 markdown 提交，放行

# 查找 plan.md（复用 walk-up 逻辑）
PLAN_NAME="${BATON_PLAN:-plan.md}"
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

# 检查 BATON:GO
if [ -z "$PLAN" ]; then
    echo "🔒 baton: No plan.md found. Create a plan before committing source code." >&2
    echo "   Bypass: BATON_BYPASS=1 git commit" >&2
    exit 1
fi

if ! grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    echo "🔒 baton: plan.md exists but not approved. Add <!-- BATON:GO --> first." >&2
    echo "   Bypass: BATON_BYPASS=1 git commit" >&2
    exit 1
fi

exit 0
```

### 4.3 安装方式

`setup.sh` 在安装时：
1. 检查 `.git/hooks/pre-commit` 是否存在
2. 如果不存在 → 直接安装
3. 如果已存在 → 检查是否包含 baton 标记，没有则追加（不覆盖用户的 hook）
4. 支持 `BATON_SKIP=pre-commit` 跳过

---

## 实施优先级

| 优先级 | 内容 | 工作量 | 影响 |
|--------|------|--------|------|
| P0 | IDE 集成层：多 IDE 检测 + Cursor/Windsurf hook 支持 | 中 | 高（直接扩大用户群） |
| P1 | 适配器简化：废弃 adapter-windsurf.sh，新增 adapter-cursor.sh/copilot.sh | 小 | 中（减少维护成本） |
| P2 | git pre-commit hook | 小 | 中（通用安全网） |
| P3 | CLI 分发层：install.sh + bin/baton + registry | 中 | 高（降低采用门槛） |
| P4 | baton doctor / status | 小 | 中（改善运维体验） |
| P5 | 新 IDE 支持：Augment, Kiro, Copilot | 小 | 低（用户量较小） |

### 分批实施建议

**Phase 1（核心价值）：** P0 + P1 + P2
- 多 IDE 检测 + 主流 IDE hook 配置 + git pre-commit
- 预计变更：setup.sh 重构 + 3 个新适配器 + 1 个 hook 脚本

**Phase 2（分发层）：** P3
- install.sh + bin/baton + projects.list
- 预计新增文件：install.sh, bin/baton

**Phase 3（体验优化）：** P4 + P5
- baton doctor + baton status + 新 IDE 支持
- 在 bin/baton 中添加子命令

---

## 不做的事情

- **不引入运行时依赖** — 保持零依赖（jq 可选，awk fallback）
- **不做版本管理器** — 不支持不同项目使用不同 baton 版本
- **不主动创建 IDE 目录** — 只在已存在的 IDE 目录中配置
- **不做 GUI/TUI** — CLI 足够
- **不做 config 文件** — 无 `~/.baton/config`，用环境变量控制行为
- **不做自动更新** — `baton self-update` 是手动触发的

---

## 测试计划

### 新增测试

| 测试文件 | 覆盖内容 |
|---------|---------|
| `tests/test-multi-ide.sh` | 多 IDE 检测、同时配置多个 IDE、各 IDE hook 配置正确性 |
| `tests/test-pre-commit.sh` | git pre-commit hook 的阻断/放行逻辑 |
| `tests/test-adapters-v2.sh` | 新适配器输出格式验证（Cursor JSON、Copilot JSON） |
| `tests/test-self-install.sh` | 自安装检测（source == target 跳过 cp） |
| `tests/test-cli.sh` | CLI 子命令（init, update, list, doctor, self-update） |

### 现有测试更新

| 测试文件 | 变更 |
|---------|------|
| `tests/test-setup.sh` | 增加多 IDE 场景测试 |
| `tests/test-adapters.sh` | 更新适配器测试以匹配新的精简逻辑 |

---

## Todo

### Phase 1: 核心价值（P0 + P1 + P2）

#### P0: 多 IDE 检测 + 主流 IDE hook 配置

- [x] 1.1 重构 `setup.sh` 中的 `detect_ide()` → `detect_ides()`，返回空格分隔的 IDE 列表
- [x] 1.2 重构 `setup.sh` 安装逻辑：从"单 IDE 配置"改为"遍历所有检测到的 IDE 逐个配置"
- [x] 1.3 新增 Cursor hook 配置：生成 `.cursor/hooks.json`（仅当 `.cursor/` 已存在时）
- [x] 1.4 新增 Windsurf 原生 hook 配置：生成 `.windsurf/hooks.json`（`pre_write_code` + exit code 2）
- [x] 1.5 实现 workflow 文件选择策略：支持 SessionStart 的 IDE 用 slim 版，否则用 full 版
- [x] 1.6 更新安装输出：按 IDE 分组显示配置结果（参考 §2.1 输出示例）
- [x] 1.7 编写 `tests/test-multi-ide.sh`：多 IDE 检测、同时配置多个 IDE、各 IDE hook 配置正确性
- [ ] 1.8 更新 `tests/test-setup.sh`：增加多 IDE 场景测试

#### P1: 适配器简化

- [x] 1.9 新增 `.baton/adapters/adapter-cursor.sh`：write-lock.sh exit code → `{"decision":"allow/deny"}` JSON（~10 行）
- [x] 1.10 简化 `.baton/adapters/adapter-cline.sh`：从 stdin 读取 JSON、提取 tool 名、调用 write-lock.sh、输出 `{"cancel":true/false}` JSON（~15 行）
- [x] 1.11 新增 `.baton/adapters/adapter-copilot.sh`：write-lock.sh exit code → `{"permissionDecision":"allow/deny"}` JSON（~10 行）
- [x] 1.12 废弃 `adapter-windsurf.sh`：Windsurf 已支持原生 hook，标记废弃或删除
- [x] 1.13 编写 `tests/test-adapters-v2.sh`：验证新适配器输出格式（Cursor JSON、Cline JSON、Copilot JSON）
- [ ] 1.14 更新 `tests/test-adapters.sh`：适配新的精简逻辑

#### P2: git pre-commit hook

- [x] 1.15 新增 `hooks/pre-commit` 脚本：检查 staged 文件中是否有非 markdown 文件 → 查找 plan.md → 检查 BATON:GO（~30 行）
- [x] 1.16 在 `setup.sh` 中集成 pre-commit 安装逻辑：检测已有 hook → 追加 baton 标记段（不覆盖用户 hook）
- [x] 1.17 支持 `BATON_SKIP=pre-commit` 跳过 pre-commit 安装
- [x] 1.18 支持 `BATON_BYPASS=1` 运行时跳过 pre-commit 检查
- [x] 1.19 编写 `tests/test-pre-commit.sh`：阻断/放行逻辑、BATON_BYPASS 跳过、已有 hook 不被覆盖

### Phase 2: 分发层（P3）

- [ ] 2.1 新增 `install.sh`：全局安装脚本（clone/确认 ~/.baton → 创建 bin/baton → 加入 PATH）
- [ ] 2.2 新增 `bin/baton`：CLI 入口脚本（~80 行），实现子命令路由
- [ ] 2.3 实现 `baton init [dir]`：调用 setup.sh + 注册表追加
- [ ] 2.4 实现 `baton update [dir]` 和 `baton update --all`：单项目更新 / 遍历注册表批量更新
- [ ] 2.5 实现 `baton uninstall [dir]`：调用 setup.sh --uninstall + 注册表移除
- [ ] 2.6 实现 `baton self-update`：git -C ~/.baton pull
- [ ] 2.7 实现 `baton list`：读取 projects.list，显示每个项目的 baton 版本和检测到的 IDE
- [ ] 2.8 实现注册表管理（`projects.list`）：追加去重、移除、遍历跳过不存在路径
- [ ] 2.9 处理自安装场景：当 source == target（项目目录就是 ~/.baton）时跳过 cp
- [ ] 2.10 编写 `tests/test-cli.sh`：CLI 子命令测试（init, update, list, self-update, uninstall）
- [ ] 2.11 编写 `tests/test-self-install.sh`：自安装检测

### Phase 3: 体验优化（P4 + P5）

#### P4: 健康检查

- [ ] 3.1 实现 `baton doctor [dir]`：脚本完整性、IDE 配置、新增 IDE 检测、规则注入、git hook、版本一致性
- [ ] 3.2 实现 `baton status [dir]`：显示当前 phase、plan.md 状态、todo 进度（复用 phase-guide.sh 逻辑）

#### P5: 新 IDE 支持

- [ ] 3.3 新增 Augment Code 配置：生成 `.augment/settings.json` hook 配置（A 类，直接用 write-lock.sh）
- [ ] 3.4 新增 Amazon Q / Kiro 配置：生成 hook 配置（A 类，直接用 write-lock.sh）
- [ ] 3.5 新增 GitHub Copilot 配置：生成 `.github/hooks/baton.json` + 更新 `.github/copilot-instructions.md`
- [ ] 3.6 新增 Codex 规则注入：在 `AGENTS.md` 中添加 `@.baton/workflow.md`
- [ ] 3.7 新增 Zed AI 规则注入：注入到 `.rules` 文件
- [ ] 3.8 新增 Roo Code 规则注入：注入到 `.roo/rules/baton-workflow.md`

---

## 参考

- [IDE Hook 能力调研](../research-ide-hooks.md)
- [Cursor Hooks 文档](https://cursor.com/docs/agent/hooks)
- [Windsurf Cascade Hooks](https://docs.windsurf.com/windsurf/cascade/hooks)
- [Cline Hook Reference](https://docs.cline.bot/features/hooks/hook-reference)
- [GitHub Copilot Hooks](https://code.visualstudio.com/docs/copilot/customization/hooks)
- [Augment Code Hooks](https://docs.augmentcode.com/cli/hooks)
- [Kiro CLI Hooks](https://kiro.dev/docs/cli/hooks/)
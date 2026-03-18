# Research: Absorb Superpowers Hook Design Into Baton

## Question
What specific improvements can baton absorb from superpowers' hook architecture?

## Why
Improve baton's cross-platform robustness, simplify maintenance, and adopt proven patterns.

## Scope
- Superpowers hooks/ directory (4 files)
- Baton .baton/hooks/, .baton/adapters/, setup.sh, bin/baton
- Out of scope: superpowers skills system, baton governance model

## Task Sizing: Medium
Cross-module changes (dispatch, adapters, setup, hooks), design decisions on architecture.

---

## Investigation

### Move 1: Superpowers Hook Architecture — Complete Analysis

**What was checked**: Fetched all 4 files from `github.com/obra/superpowers/tree/main/hooks` `[CODE]✅`

Superpowers 的 hook 系统极简：4 个文件，只有 1 个实际 hook 事件（SessionStart）。

#### 文件清单

| 文件 | 角色 | 事件 |
|------|------|------|
| `hooks/hooks.json` | Claude Code hook 配置 | SessionStart (matcher: `startup\|clear\|compact`) |
| `hooks/hooks-cursor.json` | Cursor hook 配置 | sessionStart（更简格式，相对路径） |
| `hooks/run-hook.cmd` | cmd/bash polyglot wrapper | 基础设施，非 hook 本身 |
| `hooks/session-start` | 唯一实际 hook 逻辑 | SessionStart |

#### 值得吸收的 5 个设计点

**1. `run-hook.cmd` polyglot — 最有价值**

单文件同时兼容 Windows cmd 和 Unix bash。核心结构 `[CODE]✅`：

```cmd
:: 2>nul & @echo off & goto CMDBLOCK
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"; shift
exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
exit $?
:CMDBLOCK
:: Windows: 按顺序搜索 Git Bash
for %%G in (
    "C:\Program Files\Git\bin\bash.exe"
    "C:\Program Files (x86)\Git\bin\bash.exe"
) do (
    if exist %%G ( %%G "%~dp0session-start" %* & exit /b !ERRORLEVEL! )
)
:: 最后尝试 PATH 中的 bash
where bash >nul 2>&1 && ( bash "%~dp0session-start" %* & exit /b !ERRORLEVEL! )
:: 找不到 bash 也不阻塞（静默退出）
exit /b 0
```

Baton 当前 `setup.sh:170` 用 `"bash .baton/hooks/dispatch.sh"` — 假设 `bash` 在 PATH 中。这个 polyglot 主动搜索常见安装路径，找不到也不阻塞。

**2. `printf` 替代 heredoc — 规避 bash 5.3+ bug**

Superpowers 发现 bash 5.3+ 的 heredoc 变量展开在内容超过 ~512 字节时会挂起（issue #571）。他们全面改用 `printf` `[CODE]✅`：

```bash
# superpowers 的做法
printf '{\n  "hookSpecificOutput": {\n    ...\n    "additionalContext": "%s"\n  }\n}\n' "$session_context"
```

**3. 环境变量驱动的平台检测**

一个 `if/elif` 分支处理所有 IDE 输出格式 `[CODE]✅`：

```bash
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    # Cursor: emit additional_context
    printf '{\n  "additional_context": "%s"\n}\n' "$session_context"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    # Claude Code: emit hookSpecificOutput.additionalContext only
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$session_context"
fi
```

注意：Claude Code **同时读取**两个字段但不去重，所以必须只 emit 当前平台消费的字段，否则会双重注入。

**4. Plugin 自动发现机制**

`.claude-plugin/plugin.json` 让 Claude Code 自动发现插件，无需手动安装。`CLAUDE_PLUGIN_ROOT` 自动设置。Baton 的 `baton init` 模式需要每个项目手动运行。

**5. 无扩展名 hook 脚本**

Hook 脚本故意不加 `.sh` 后缀 — "Claude Code 在 Windows 上会自动给 `.sh` 文件前加 `bash`"，与 polyglot wrapper 冲突。Baton 的 hook 用 `.sh` 但由 `dispatch.sh` 内部调用，不受此影响。

### Move 2: Baton vs Superpowers 架构对比

**What was checked**: Read all baton hooks, dispatch.sh, manifest.conf, adapters, setup.sh `[CODE]✅`

#### 全维度对比

| 维度 | Baton | Superpowers | 评价 |
|------|-------|-------------|------|
| **Hook 数量** | 10+ hooks，覆盖 6 种事件 | 1 个 hook（SessionStart） | Baton 能力更强 |
| **设计目标** | 全流程治理：写锁、失败追踪、完成检查等 | 单一目标：注入 skill 上下文 | 不同定位，不可直接比较 |
| **分发机制** | `manifest.conf` + `dispatch.sh` 自建分发器 | Claude Code 原生 `hooks.json` 直接注册 | Baton manifest 更灵活 |
| **跨平台** | junction 回退链 + 假设 bash 在 PATH | `run-hook.cmd` polyglot 主动搜索 Git Bash | **Superpowers 更健壮** |
| **heredoc 安全** | 4 处 heredoc，其中 1 处有变量展开 | 全面使用 `printf` | **Superpowers 更安全** |
| **多 IDE 适配** | adapter 目录模式（每 IDE 一个翻译层） | 环境变量 `if/elif` 内联分支 | **平手**（baton 在 10+ hook 下更合理） |
| **安装方式** | `setup.sh` 手动安装 + junction | `.claude-plugin/` 自动发现 | **Superpowers 更零配** |
| **上下文注入** | phase-guide.sh（已借鉴 superpowers 模式） | session-start | **平手**（baton 已吸收） |

#### Baton 独有优势（不需放弃）

- **写锁 (write-lock)** — 计划批准前阻止代码修改
- **失败追踪 (failure-tracker)** — 重复失败自动告警
- **完成检查 (completion-check)** — 阻止无回顾的草率完成
- **子 agent 上下文 (subagent-context)** — 并行 agent 对齐
- **manifest 分发** — 声明式 hook 管理（superpowers 只有 1 个 hook 不需要）

### Move 3: Specific Vulnerability Assessment

**heredoc usage in baton hooks** `[CODE]✅`:
1. `write-lock.sh:147` — `cat <<'HOOKJSON'` — single-quoted, no variable expansion. **Safe** from bash 5.3+ bug.
2. `phase-guide.sh:36,45` — `cat <<EOFJ` with `${_ctx}` variable. **VULNERABLE** — `_ctx` contains full SKILL.md content (>512 bytes).
3. `phase-guide.sh:124` — `cat >&2 <<EOF` — hardcoded text only. **Safe**.
4. `phase-guide.sh:138` — `cat >&2 << 'EOF'` — single-quoted. **Safe**.

**Conclusion**: phase-guide.sh lines 36-50 are the critical vulnerability — this is the governance context injection path, and the `_ctx` variable contains escaped SKILL.md content that routinely exceeds 512 bytes.

**Windows dispatch entry point** `[CODE]✅`:
- settings.json uses `"bash .baton/hooks/dispatch.sh"` — assumes `bash` is in PATH
- No fallback if Git Bash isn't configured in PATH
- Superpowers' polyglot searches `C:\Program Files\Git\bin\bash.exe` and `C:\Program Files (x86)\Git\bin\bash.exe` before PATH

**Plugin auto-discovery** `[CODE]❓`:
- `.claude-plugin/plugin.json` format is used by superpowers but not documented as a stable Claude Code API
- Baton does not currently have `.claude-plugin/` — would need to create it
- Risk: this format may change without notice
- Status: ❓ — need to verify stability before adopting

### Move 4: Counterexample Sweep

**Leading interpretation**: Adopt run-hook.cmd polyglot, fix heredoc vulnerability, defer plugin auto-discovery.

**What would disprove this?**
1. "run-hook.cmd is unnecessary if Claude Code already handles Windows" — **Checked**: Claude Code settings.json `command` field runs via system shell. On Windows, `bash` command fails if Git Bash isn't in PATH. Superpowers' approach is strictly more robust. ✅
2. "heredoc bug is theoretical" — **Checked**: bash 5.3+ is current (shipped with recent macOS). The specific variable `_ctx` in phase-guide.sh contains full SKILL.md escaped content, easily >1KB. This is a real risk. ✅
3. "Plugin format might break baton's junction model" — **Valid concern** ❓. Plugin format defines `CLAUDE_PLUGIN_ROOT` relative to plugin.json location, but baton uses junctions pointing elsewhere. Need to test compatibility.

---

## Self-Challenge

1. **Weakest conclusion**: Plugin auto-discovery (P1 recommendation). The `.claude-plugin` format is not well-documented as a stable API. Evidence is only from superpowers' usage, not official docs. Would disprove: finding Claude Code docs stating this format is experimental or deprecated.

2. **What I didn't investigate**: Whether `CLAUDE_PLUGIN_ROOT` is already available in baton's current hook execution context (phase-guide.sh already checks for it — suggests it might be set by Claude Code's plugin system even without `.claude-plugin`). Also didn't verify the exact bash version where the heredoc bug was introduced.

3. **Assumptions without verification**: That adapter consolidation (P2) would actually simplify things — baton has 4 IDEs with different hook protocols, and the adapter pattern may be the correct architecture at that scale.

---

## Final Conclusions

### Actionable (P0)
1. **Fix heredoc vulnerability in phase-guide.sh** — Replace `cat <<EOFJ` with `printf` for governance context injection (lines 36-50). Direct, low-risk fix. Already proven by superpowers.
2. **Add run-hook.cmd polyglot** as dispatch entry point on Windows — Creates `.baton/hooks/run-hook.cmd` that searches for Git Bash, then calls `dispatch.sh`. Update `setup.sh` to use `run-hook.cmd` in settings.json `command` field on Windows.

### Watchlist (P1)
3. **Plugin auto-discovery** — Investigate `.claude-plugin/plugin.json` format stability before adopting. Would eliminate `baton init` for Claude Code users. Blocked on format stability verification.

### Judgment-needed (P2)
4. **Adapter consolidation** — Could merge platform-specific output logic into dispatch.sh using env var detection. But current adapter pattern is clean and scales well with more IDEs. Recommend keeping unless maintenance cost becomes evident.

---

## Questions for Human Judgment

1. **P0 scope**: Both heredoc fix and run-hook.cmd are low-risk. Proceed with both, or prioritize one?
2. **Plugin format (P1)**: Worth investigating `.claude-plugin` format stability, or keep current `baton init` approach?
3. **Adapter consolidation (P2)**: Keep adapter directories as-is, or merge into dispatch?

---

## 批注区

1.我看chat里面相关的分析 都没进这个文档呀

→ 已补充：Move 1 增加完整文件清单、5 个值得吸收的设计点（含代码示例）、polyglot 核心结构。Move 2 增加全维度对比表和 baton 独有优势列表。
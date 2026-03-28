# Baton Hook 系统研究报告

## 架构概览

Baton 的 hook 系统是一个纯 bash 实现的事件驱动拦截层，零编译依赖（jq 可选，有 awk/sed 回退）。它在 AI 编码工具（Claude Code、Cursor、Codex 等）的操作生命周期中插入检查点，实现"先计划后执行"的治理模型。

核心设计原则：**hooks enforce structure, review enforces quality** — hooks 负责结构约束（比如"没有计划不能写代码"），review 负责质量约束（比如"写的代码是否正确"）。两者缺一不可。

## 分发架构（Dispatch Architecture）

### 事件流

```
IDE 触发事件
    ↓
IDE 配置层 (settings.json / hooks.json / .codex/hooks.json)
    ↓
入口层: run-hook.cmd (跨平台 polyglot 包装器)
    ↓
dispatch.sh (中央路由器)
    ↓ (根据 manifest.conf 路由)
具体 hook 脚本 (在子 shell 中执行)
```

### `dispatch.sh` — 中央路由器

文件：`.baton/hooks/dispatch.sh`

这是整个系统的核心枢纽。职责：

1. **事件接收**：接收第一个参数作为事件名（如 `PreToolUse`、`SessionStart`）
2. **stdin 缓冲**：将 IDE 传入的 JSON stdin 一次性读入 `BATON_STDIN` 环境变量，供所有 hook 重复消费（因为 stdin 只能读一次）
3. **工具名提取**：从 stdin JSON 中解析 `tool_name` 字段（先试 jq，回退到 sed）
4. **Manifest 路由**：逐行读取 `manifest.conf`，匹配事件名和工具名，决定执行哪些 hook
5. **子 shell 隔离**：每个 hook 在独立子 shell 中执行（`( . "$_dir/$_script.sh" )`），隔离 exit code 和变量状态
6. **退出码语义**：
   - `0` = 允许
   - `2` = 阻断（PreToolUse 专用，第一个 exit 2 胜出）
   - 其他 = 意外错误，输出警告到 stderr

### `manifest.conf` — 事件路由表

文件：`.baton/hooks/manifest.conf`

格式为 `event:matcher:script`，matcher 为空则匹配所有工具，逗号分隔匹配多个：

```
SessionStart::phase-guide
PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock
PreToolUse:Bash:bash-guard
PostToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:post-write-tracker
PostToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:quality-gate
SubagentStart::subagent-context
Stop::stop-guard
TaskCompleted::completion-check
PostToolUseFailure::failure-tracker
PreCompact::pre-compact
```

支持 8 种事件类型，映射到 10 个 hook 脚本。新增 hook 需要：manifest 行 + 脚本文件 + IDE 注册。

### `run-hook.cmd` — 跨平台入口

文件：`.baton/hooks/run-hook.cmd`

这是一个 cmd/bash polyglot 文件 — 同一个文件在 Windows 上被 cmd.exe 解释为批处理，在 Unix 上被 bash 解释为 shell 脚本。Windows 路径下会按优先级搜索 Git for Windows 的 bash.exe（`Program Files`、`Program Files (x86)`、`LOCALAPPDATA`、PATH），找不到则静默退出（hooks 是 advisory，不 blocking）。

这个设计解决了一个实际问题：Windows IDE 的 pre-tool hooks 无法直接调用 Git Bash，需要 cmd.exe 作为桥梁。

## 10 个 Hook 脚本详解

### 1. `phase-guide.sh` — SessionStart 阶段引导

**事件**：SessionStart（会话启动、clear、compact 时触发）
**能力**：advisory（只输出引导信息，不阻断）

这是最复杂的 hook（~265行），负责两件事：

**A. 治理上下文注入**：读取 `.baton/skills/using-baton/SKILL.md` 的完整内容，通过 `hookSpecificOutput.additionalContext` JSON 注入到 AI 的上下文中。这是 baton 治理模型加载到 AI 记忆的关键机制。

**B. 阶段检测与引导**：基于 plan 文件状态，检测当前处于哪个阶段并输出对应指引：

| 状态 | 条件 | 引导行为 |
|------|------|---------|
| FINISH | plan + GO + 所有 Todo 完成 | 提示加载 /baton-implement 走完成流程 |
| AWAITING_TODO | plan + GO + 无 Todo 项 | 提示让用户说 "generate Todo list" |
| IMPLEMENT | plan + GO + 有未完成 Todo | 提示加载实现技能，输出自检清单 |
| ANNOTATION | plan 存在, 无 GO | 提示处于批注周期，检查批注区 |
| PLAN | research 存在, 无 plan | 提示进入规划阶段，检查 Final Conclusions |
| RESEARCH | 什么都没有 | 提示开始研究 |

**C. 技能自动发现**：扫描项目下所有 IDE skill 目录（`.baton/skills`、`.claude/skills`、`.cursor/skills`、`.agents/skills`），动态发现可用技能并按关键词（research、plan、implement、debug、review）分类推荐。

**D. 技能 junction 自动创建**：如果 `.baton/skills/` 下有 `baton-*` 技能目录但对应 IDE skill 目录下没有，自动创建 junction/symlink。

### 2. `write-lock.sh` — 写操作门控

**事件**：PreToolUse（Write、Edit、MultiEdit、CreateFile、NotebookEdit）
**能力**：hard block（exit 2 阻断写操作）

这是治理模型的核心执行点。逻辑层次：

1. **紧急旁路**：`BATON_BYPASS=1` 立即放行
2. **Markdown 特殊处理**：`.md/.mdx` 文件总是放行，但检查是否试图写入治理标记（`BATON:GO`、`BATON:OVERRIDE`）— AI 不允许自己添加这些标记
3. **baton-tasks/ 文档**：总是放行（可能引用治理标记作为示例）
4. **项目外文件**：总是放行（通过 `parser_project_root` 判断）
5. **无 plan 文件**：阻断，提示先完成研究再写计划
6. **多 plan 歧义**：阻断，要求 `BATON_PLAN` 指定
7. **有 GO 标记**：
   - 如果 plan 定义了 write set（Todo 项的 `Files:` 字段），检查目标文件是否在 write set 中
   - 在 write set 中 → 放行 + 输出自检提示
   - 不在 write set 中 → 阻断 + 显示允许的文件列表
8. **有 plan 无 GO**：阻断，提示批注周期进行中

**目标路径获取**：先查 `BATON_TARGET` 环境变量，再从 stdin JSON 的 `tool_input.file_path` 解析（jq 优先，awk 回退）。

**Fail-open 设计**：所有意外错误（trap 捕获）和无法确定目标路径的情况都选择放行（exit 0），而非阻断。这是有意为之 — 宁可漏过也不误杀。

### 3. `bash-guard.sh` — Shell 写操作拦截

**事件**：PreToolUse（Bash）
**能力**：hard block

与 write-lock 互补，拦截通过 Bash 工具进行的文件写操作。当 gate 关闭时（无 GO 标记）：

**阻断的模式**（Phase-1 block list）：
- 重定向：`>` / `>>` / heredoc 重定向
- `tee`（写入文件 sink）
- `sed -i`（就地编辑）
- `perl -pi`（就地编辑）
- `python -c` with `open(..., 'w')` / `open(..., 'a')`
- `cp`、`mv`、`install`、`truncate`、`patch`

**警告的模式**：
- `rm`（破坏性但不是写入）
- `touch`（可能是创建新文件）

**关键技巧**：`strip_quoted_segments()` 函数在检查前先剥离引号内的内容，避免字符串常量中的关键字触发误报。比如 `echo "cp file"` 中的 `cp` 不会被匹配。但 `python -c` 的检查特意查原始命令，因为写模式字符串在引号内。

### 4. `post-write-tracker.sh` — 写集合漂移追踪

**事件**：PostToolUse（Write、Edit 等）
**能力**：advisory（不阻断）

写操作完成后检查被修改的文件是否在 plan 的 write set 中。如果不在：
- **首次违规**：输出警告 + 显示允许的文件列表
- **重复违规**：升级为 "REPEAT write-set violation" 警告，提示 scope drift

违规计数通过 `/tmp/baton-writeset-violations-{session_id}` 文件跟踪，session 粒度。

### 5. `quality-gate.sh` — 自我挑战质量门控

**事件**：PostToolUse（Write、Edit 等）
**能力**：advisory

检查 plan/research 文件是否包含 `## Self-Challenge` 章节，且内容行数 >= 3。如果缺失或太浅，输出反思提示：
- 这是最优方案还是你想到的第一个？
- 有哪些假设没有验证？
- 质疑者会先挑战什么？

### 6. `subagent-context.sh` — 子 agent 上下文注入

**事件**：SubagentStart
**能力**：advisory

当子 agent 启动时，注入当前 plan 的上下文：
- 批注阶段（无 GO）：只报告阶段状态
- 执行阶段（有 GO）：输出 Todo 进度 + Todo 项列表（上限 20 行）+ 授权 write set

### 7. `stop-guard.sh` — 会话结束提醒

**事件**：Stop
**能力**：advisory（永不阻断停止操作）

根据进度状态输出提醒：
- **所有 Todo 完成**：提醒完成 finish 流程（回顾、测试、标记完成）
- **仍有未完成项**：显示进度，提示下次会话可从 checklist 恢复

### 8. `completion-check.sh` — 完成条件检查

**事件**：TaskCompleted
**能力**：hard block（exit 2）

阻断未满足条件的任务完成：
- 所有 Todo 完成但无 `## Retrospective` → 阻断
- Retrospective 存在但内容行数 < 3 → 阻断
- 有未解决的 `❓` 标记 → 警告（advisory）
- 检测到测试套件 → 提醒确认已运行

### 9. `failure-tracker.sh` — 工具失败追踪

**事件**：PostToolUseFailure
**能力**：advisory

累计追踪 session 内工具失败次数（通过 `/tmp/baton-failures-{session_id}` 文件）：
- 达到 3 次：提醒检查是否有两次失败共享同一根因假设
- 达到 5 次：强烈建议停下来，识别驱动重复尝试的假设

这是 constitution 中 "failure boundary"（同一假设下 >= 2 次失败 → 停止并上报）的代理实现。Hook 层无法追踪假设身份，精确的每假设计数依赖 AI 自律。

### 10. `pre-compact.sh` — 上下文压缩前快照

**事件**：PreCompact
**能力**：advisory

在上下文窗口压缩前输出关键信息，确保压缩后不丢失：
- 当前阶段 + Todo 进度
- 剩余 Todo 项（上限 5 条）
- 授权 write set
- 最近的 Annotation Log 内容（上限 10 行）

## 共享库层

### `lib/common.sh`

胶水层，加载 `plan-parser.sh` 并提供向后兼容的函数名（`resolve_plan_name`、`find_plan`、`has_skill`），以及测试套件配置自动检测（`baton_resolve_test_cmd`）。

### `lib/plan-parser.sh`

三层解析器原语，版本 1.3：

**1A — 发现原语**：
- `parser_find_plan` — 从 cwd 向上遍历查找 plan 文件。支持多 plan 消歧（先看 BATON:GO 唯一性，再看 BATON_TARGET 上下文匹配）。过滤 `<!-- BATON:COMPLETE -->` 标记的已完成 plan
- `parser_find_research` — 查找配对的 research 文件（plan→research 名称映射）
- `parser_has_go` — 检查 `<!-- BATON:GO -->` 标记
- `parser_has_skill` — 跨 IDE 目录向上查找技能
- `parser_project_root` — 通过标记（`.baton`、`.git`、`.claude`、`CLAUDE.md` 等）推断项目根

**1B — 章节原语**：
- `parser_todo_range` / `parser_todo_counts` / `parser_todo_items` — 解析 `## Todo` 章节
- `parser_retro_range` / `parser_retro_valid` — 解析 `## Retrospective` 章节

**1C — Write-set 原语**：
- `parser_writeset_normalize` — 路径标准化（去 `./`、绝对→相对、Windows cygpath）
- `parser_writeset_extract` — 从 Todo 的 `Files:` 字段提取去重的文件路径集合
- `parser_writeset_contains` — 路径成员测试

### `lib/junction.sh`

`atomic_junction()` 函数：按优先级尝试 NTFS junction（Windows，无需开发者模式）→ symlink → copy。这是 baton 分发架构的基础 — `~/.baton/` 是单一数据源，项目通过 junction 引用。

## 适配器层（Adapter Layer）

适配器翻译 IDE 特定的 hook 协议，使核心 hook 脚本保持 IDE 无关。

### Claude Code / Factory

直接使用 `dispatch.sh`，通过 `run-hook.cmd` 入口。hook 输出协议：
- stdout JSON `hookSpecificOutput` → additionalContext 注入
- stderr → 直接显示给 AI
- exit 2 → 阻断工具执行

所有 8 种事件类型都支持，enforcement 最完整。

### Cursor

文件：`.baton/adapters/cursor/dispatch.sh` + `adapter.sh`

**dispatch.sh**（新架构）：
- 将 Cursor 的 camelCase 事件名映射为 PascalCase（`preToolUse` → `PreToolUse`）
- 翻译退出码为 Cursor JSON 协议：exit 2 → `{"decision":"block","reason":"..."}`，其他 → `{"decision":"allow"}`

**adapter.sh**（旧架构，仍保留）：
- 只包装 write-lock.sh 的直接调用
- 标注 `[Baton capability: reduced enforcement (Cursor)]` — Cursor 不支持 PostToolUseFailure、TaskCompleted 等事件

### Codex

文件：`.baton/adapters/codex/dispatch.sh` + `adapter.sh`

**dispatch.sh**（主入口）：
- SessionStart：关闭 stdin（Codex 可能不发 EOF，导致 `cat` 挂起）+ 输出 tier header
- Stop：保存 stop-guard 消息到 `.codex/stop-hook.message.txt`（Codex Stop stdout 是 JSON 协议通道，不能混入文本）
- 其他事件：stderr→stdout 重定向

**能力分级**：`[Baton capability: rules + guidance only (Codex)]` — 无 hard gate（Codex 没有 PreToolUse），依赖 rules + guidance + Codex 自身的沙箱/人工审批层。

## 安装机制（`setup.sh`）

版本 4.0，junction-based 分发架构：

1. **确保 `~/.baton` 存在**：自动 clone 或 git pull
2. **检测自安装**：baton 源仓库自身安装时不创建 junction
3. **IDE 检测**：扫描项目目录中的 IDE 标记（`.claude`、`.cursor`、`.codex`、`AGENTS.md`），支持 `--ide` 手动指定和 `--choose` 交互选择
4. **创建 `.baton` junction**：`~/.baton/.baton` → 项目 `.baton/`
5. **创建技能 junction**：`.baton/skills/*` → 各 IDE skills 目录
6. **配置各 IDE**：
   - Claude/Factory：生成/合并 `.claude/settings.json`（注册所有 8 个事件），注入 `CLAUDE.md`
   - Cursor：生成/合并 `.cursor/hooks.json` + `.cursor/rules/baton.mdc`
   - Codex：生成 `AGENTS.md`、`.codex/hooks.json`（SessionStart + Stop）、feature flag、trust 配置
7. **更新 `.gitignore`**：junction 目标不应被 git 跟踪

支持 `--uninstall` 完全清理。

## 跨 IDE 能力对比

| 事件 / 能力 | Claude Code | Cursor | Codex |
|---|---|---|---|
| SessionStart (phase-guide) | full | full | full (via adapter) |
| PreToolUse write-lock | hard block | hard block (via JSON) | not available |
| PreToolUse bash-guard | hard block | hard block (via JSON) | not available |
| PostToolUse write-tracker | advisory | partial | not available |
| PostToolUse quality-gate | advisory | partial | not available |
| SubagentStart context | advisory | advisory | not available |
| Stop guard | advisory | advisory | file-based (off-channel) |
| TaskCompleted check | hard block | not available | not available |
| PostToolUseFailure tracker | advisory | not available | not available |
| PreCompact snapshot | advisory | advisory | not available |

## 设计模式总结

1. **Fail-open**：所有 hook 的意外错误都选择放行，不阻断用户操作。宁可漏过也不误杀。
2. **jq + awk 双轨**：所有 JSON 解析都有 jq-first、awk/sed-fallback 两条路径，零硬依赖。
3. **Stdin 缓冲**：dispatch.sh 一次性读取 stdin 到环境变量，解决"stdin 只能读一次但需多个 hook 消费"的问题。
4. **子 shell 隔离**：每个 hook 在子 shell 中执行，互不影响变量和退出码。
5. **分层执行**：IDE 配置层（matcher 过滤） → dispatch 层（manifest 匹配） → hook 层（业务逻辑）。IDE 层的 matcher 避免了不必要的 dispatch.sh 调用。
6. **Walk-up 发现**：plan、research、skill、project root 的查找都采用从 cwd 向上遍历的模式，自然支持 monorepo 和嵌套项目。
7. **渐进式治理**：从 advisory（警告）到 hard block（阻断），不同 hook 使用不同强度，平衡安全性和灵活性。
8. **Junction 分发**：`~/.baton` 作为单一数据源，通过 NTFS junction（Windows 不需要管理员权限）/ symlink / copy 分发到各项目，更新一处即更新所有项目。

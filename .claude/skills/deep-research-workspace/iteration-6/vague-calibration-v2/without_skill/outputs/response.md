# Baton Hook 系统研究

## 系统概述

Baton 的 hook 系统是一个纯 bash 实现的事件驱动 hook 分发架构，用于在 AI coding 工具（Claude Code、Cursor、Codex 等）的工作流程中注入治理和质量控制逻辑。零编译依赖，jq 可选（有 awk 回退）。

核心设计理念：**hooks enforce structure, review enforces quality** — 两者缺一不可的分层防御。

---

## 架构总览

```
IDE (Claude Code / Cursor / Codex)
  │
  ├─ Claude Code: settings.json hooks → run-hook.cmd → dispatch.sh
  ├─ Cursor:      hooks.json          → adapters/cursor/dispatch.sh → dispatch.sh
  └─ Codex:       .codex/hooks.json   → adapters/codex/dispatch.sh  → dispatch.sh
                                              │
                                        dispatch.sh (核心调度器)
                                              │
                                        manifest.conf (事件路由表)
                                              │
                              ┌───────────────┼───────────────┐
                              │               │               │
                        hook scripts    lib/common.sh    lib/plan-parser.sh
```

### 分发模型

所有 IDE 最终都汇聚到同一个 `dispatch.sh`，但中间经过不同的适配层：

- **Claude Code**: `settings.json` 直接通过 `run-hook.cmd` 调用 `dispatch.sh`，传递事件名作为参数。`run-hook.cmd` 是一个 bash/cmd 多语言文件（polyglot），Windows 上由 cmd.exe 执行批处理部分找到 Git Bash，Unix 上直接作为 shell 脚本执行。
- **Cursor**: 通过 `adapters/cursor/dispatch.sh` 翻译事件名（camelCase → PascalCase）和退出码（exit 2 → JSON `{"decision":"block"}`）。
- **Codex**: 通过 `adapters/codex/dispatch.sh` 适配，但能力受限 — 只有 SessionStart 和 Stop 两个事件可用，没有 PreToolUse 硬拦截能力。

---

## dispatch.sh — 核心调度器

**文件**: `.baton/hooks/dispatch.sh`

这是整个 hook 系统的中枢。其工作流程：

1. **接收事件名**：第一个参数 `$1` 是事件名（如 `PreToolUse`）。
2. **缓冲 stdin**：将 IDE 传入的 JSON（包含 tool_name、tool_input 等）读入 `BATON_STDIN` 环境变量，这样多个 hook 可以重复读取同一份输入。
3. **提取 tool_name**：从 stdin JSON 中用 jq（或 sed 回退）提取 `tool_name` 字段，用于后续 matcher 过滤。
4. **遍历 manifest.conf**：逐行读取，匹配事件名 + matcher。
5. **子 shell 执行**：每个匹配的 hook 在 `( . "$_dir/$_script.sh" )` 子 shell 中执行，隔离退出码和变量状态。
6. **退出码语义**：
   - `0` = 允许
   - `2` = 阻止（PreToolUse 的硬拦截）
   - 其他 = 异常，输出警告但不阻止

关键设计决策：**第一个 exit 2 胜出** — 如果多个 hook 都想阻止，只记录第一个 exit 2，最终统一返回 2。

---

## manifest.conf — 事件路由表

**文件**: `.baton/hooks/manifest.conf`

格式：`event:matcher:script`（冒号分隔，matcher 为空表示匹配所有）

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

共 8 种事件类型，10 条路由规则，映射到 10 个 hook 脚本。

Matcher 机制：当 manifest 行中有 matcher 时，dispatch.sh 用 `case ",$_matcher," in *",$_tool,"*)` 做逗号分隔的列表匹配。这意味着 `Write,Edit,MultiEdit` 会匹配其中任何一个 tool_name。

---

## 10 个 Hook 脚本详解

### 1. phase-guide.sh — 阶段引导（SessionStart）

**版本**: 7.1 | **事件**: SessionStart | **性质**: 信息性，不阻止

功能：检测当前项目所处的工作阶段，输出相应的引导信息。

**状态机**（优先级从高到低）：
1. **FINISH** — plan 有 GO + 所有 Todo 完成 → 提示完成工作流
2. **AWAITING_TODO** — plan 有 GO 但没有 Todo 项 → 提示生成 Todo
3. **IMPLEMENT** — plan 有 GO + 有 Todo → 提示执行实现
4. **ANNOTATION** — plan 存在但没有 GO → 提示批注审查
5. **PLAN** — research 存在但没有 plan → 提示创建计划
6. **RESEARCH** — 什么都没有 → 提示研究阶段

额外功能：
- **自动创建 skill junctions**：扫描 `.baton/skills/baton-*`，自动为各 IDE 的 skills 目录创建 junction
- **治理上下文注入**：通过 EXIT trap 输出 `using-baton` skill 的内容作为 `additionalContext`，确保 AI 在每次会话开始时加载治理规则
- **动态 skill 发现**：扫描所有 IDE skill 目录，按关键词（research、plan、implement、debug、review）分类，在引导信息中推荐相关 skill
- **复杂度升级提示**：在 ANNOTATION 状态下，如果 plan 涉及 >3 个文件但没有 Surface Scan，提示升级复杂度
- **Sizing Checkpoint**：在 PLAN 状态下，输出宪法要求的 sizing 重新评估提醒

### 2. write-lock.sh — 写入锁（PreToolUse: Write/Edit/MultiEdit/CreateFile/NotebookEdit）

**版本**: 3.1 | **事件**: PreToolUse | **性质**: 硬拦截（exit 2 阻止工具执行）

这是 baton 最核心的治理 hook — 在 plan 被批准（`<!-- BATON:GO -->`）之前阻止所有源代码写入。

**决策流程**：
1. `BATON_BYPASS=1` → 允许（紧急旁路）
2. 无法确定目标路径 → 允许（fail-open，但输出警告）
3. 目标是 `.md/.mdx` → 允许（但检查是否写入治理标记 `BATON:GO`/`BATON:OVERRIDE`，如果是则阻止）
4. 目标在项目根目录外 → 允许
5. 没找到 plan → 阻止 + 提示"先完成研究，再写计划"
6. 多个 plan 文件且未指定 `BATON_PLAN` → 阻止（歧义）
7. Plan 有 `BATON:GO` → 检查 write-set 约束：
   - 如果 plan 定义了 write set（`Files:` 字段），目标必须在 write set 中
   - 不在 write set → 阻止 + 显示已授权文件列表
   - 在 write set → 允许 + 输出 hookSpecificOutput JSON
8. Plan 存在但没有 GO → 阻止 + 提示"批注周期进行中"

**关键安全机制**：
- **治理标记保护**：即使是 markdown 文件，如果 AI 试图写入 `<!-- BATON:GO -->` 或 `<!-- BATON:OVERRIDE -->`，也会被阻止。只有人类可以添加这些标记。
- **Fail-open 设计**：意外错误时允许操作（trap handler），避免 hook 崩溃阻塞所有工作。但错误会输出可见警告。
- **Write-set 执行**：当 plan 的 Todo 项中有 `Files:` 字段时，只允许修改这些文件。

### 3. bash-guard.sh — Bash 命令守卫（PreToolUse: Bash）

**版本**: 3.3 | **事件**: PreToolUse | **性质**: 硬拦截

在 plan gate 关闭时，阻止通过 Bash 工具进行的文件写入操作。

**当 gate 打开时（有 BATON:GO）**: 允许所有命令。

**当 gate 关闭时的检测**：
- **阻止列表**（exit 2）：
  - heredoc with redirect（`<< EOF > file`）
  - output redirection（`> file`、`>> file`）
  - `tee`（作为命令 token，非引号内字符串）
  - `sed -i`（原地编辑）
  - `perl -pi`（原地编辑）
  - `python -c` with file write patterns（`open(... 'w')`）
  - 文件操作命令：`cp`、`mv`、`install`、`truncate`、`patch`
- **警告列表**（允许但警告）：
  - `rm`（破坏性，提醒确认意图）
  - `touch`（允许，但提醒确认意图）

**引号剥离技术**：`strip_quoted_segments()` 函数在检查前移除单引号和双引号内的内容，避免误报（如 `echo "sed -i is cool"` 不会被阻止）。用 `_is_cmd_token()` 确认命令出现在命令位置（行首或 `;|&(` 之后），而非参数位置。

### 4. post-write-tracker.sh — 写入跟踪（PostToolUse: Write/Edit/...）

**版本**: 1.1 | **事件**: PostToolUse | **性质**: 纯信息性

在文件写入完成后，检查被修改的文件是否在 plan 的 write set 中。

功能：
- 如果 plan 有 `Files:` 字段定义的 write set，精确匹配路径
- 如果没有 write set，回退到 basename 文本匹配
- 追踪重复违规：使用 `/tmp/baton-writeset-violations-$SESSION_ID` 文件计数每个文件的违规次数
- 首次违规：温和警告 + 显示预期文件列表
- 重复违规：升级警告"Repeated out-of-set writes suggest scope drift"

### 5. quality-gate.sh — 质量门（PostToolUse: Write/Edit/...）

**版本**: 1.0 | **事件**: PostToolUse | **性质**: 纯信息性

当 plan 或 research 文件被写入后，检查是否包含 `## Self-Challenge` 部分，且内容深度至少 3 行。

这是 baton 防御模型中"自我挑战"层的 hook 级执行点。

### 6. subagent-context.sh — 子代理上下文注入（SubagentStart）

**版本**: 1.2 | **事件**: SubagentStart | **性质**: 纯信息性

当子代理启动时，注入当前 plan 的 Todo 进度和授权 write set，确保子代理了解整体计划边界。

输出内容：
- Todo 进度（done/total）
- Todo 项列表（最多 20 行）
- 授权 write set（最多 20 个文件）

### 7. stop-guard.sh — 停止守卫（Stop）

**版本**: 3.0 | **事件**: Stop | **性质**: 纯信息性（从不阻止停止）

在会话结束时提供上下文提醒：
- **实现阶段**（有未完成 Todo）→ 显示进度（done/total/remaining），建议写 Lessons Learned
- **完成阶段**（所有 Todo 完成）→ 提示完成工作流：review → test suite → retrospective → BATON:COMPLETE → branch disposition

### 8. completion-check.sh — 完成检查（TaskCompleted）

**版本**: 1.2 | **事件**: TaskCompleted | **性质**: 硬拦截

当 AI 尝试标记任务完成时：
- 检查是否所有 Todo 项都完成
- 检查 `## Retrospective` 是否存在且内容至少 3 行
- 检查未解决的 `❓` 标记（advisory）
- 检测并提示运行测试套件

阻止条件：所有 Todo 完成但没有合格的 Retrospective → exit 2。

### 9. failure-tracker.sh — 失败追踪（PostToolUseFailure）

**版本**: 1.1 | **事件**: PostToolUseFailure | **性质**: 纯信息性

追踪会话内工具失败次数：
- 使用 `/tmp/baton-failures-$SESSION_ID` 文件累积计数
- 3 次失败：提醒检查是否有相同根因假设（宪法要求：同一假设下 >=2 次失败 → 停止并上报）
- 5 次失败：更强烈的警告"failure boundary very likely applies"

注意：这是一个会话级总量代理。宪法的失败边界是 per-hypothesis 的，但 hook 无法追踪假设身份 — 这部分依赖 AI 层自我执行。

### 10. pre-compact.sh — 压缩前上下文保存（PreCompact）

**版本**: 1.2 | **事件**: PreCompact | **性质**: 纯信息性

在上下文窗口压缩前输出关键信息快照：
- 当前阶段和 Todo 进度
- 授权 write set
- 最近的 Annotation Log 内容（最多 10 行）

确保关键上下文在压缩后仍然可用。

---

## 共享库层

### lib/common.sh

入口点，被所有 hook 通过 `. "$SCRIPT_DIR/lib/common.sh"` 加载。功能：
- 加载 `plan-parser.sh`
- 提供向后兼容的函数封装：`resolve_plan_name()`、`find_plan()`、`has_skill()`
- `baton_resolve_test_cmd()` — 自动检测项目测试命令（package.json → npm test, Makefile → make test, etc.）

### lib/plan-parser.sh

核心解析库，分为三层原语：

**1A 发现原语**：
- `parser_find_plan()` — 从当前目录向上查找 plan 文件，支持 multi-plan 消歧（GO 唯一性 → BATON_TARGET 上下文 → mtime 排序）
- `parser_find_research()` — 查找配对的 research 文件
- `parser_has_go()` — 检查 `<!-- BATON:GO -->` 标记
- `parser_has_skill()` — 遍历目录查找 skill
- `parser_project_root()` — 推断 Baton 项目根目录

**1B 节解析原语**：
- `parser_todo_range()` / `parser_todo_counts()` / `parser_todo_items()` — 解析 `## Todo` 节
- `parser_retro_range()` / `parser_retro_valid()` — 解析 `## Retrospective` 节

**1C Write-Set 原语**：
- `parser_writeset_normalize()` — 路径规范化（strip `./`、绝对路径转相对、Windows 路径兼容）
- `parser_writeset_extract()` — 从 Todo 的 `Files:` 字段提取 write set
- `parser_writeset_contains()` — 路径成员检查

### lib/junction.sh

`atomic_junction()` 函数 — 创建目录链接的跨平台实现：
1. 尝试 NTFS junction（Windows，不需要 Developer Mode）
2. 尝试 symlink（Linux/macOS，或 Windows Developer Mode）
3. 回退到 cp -r（copy mode）

返回码：0 = junction/symlink 成功，1 = copy 回退。

---

## 适配器层

### Cursor 适配器

**能力级别**: 降级执行（reduced enforcement）

- `adapters/cursor/dispatch.sh` — 事件名翻译（camelCase → PascalCase）+ 退出码翻译（exit 2 → `{"decision":"block","reason":"..."}`）
- `adapters/cursor/adapter.sh` — 早期的单 hook 适配器（仅 write-lock），现已被 dispatch.sh 适配器取代

可用信号：write-lock（硬拦截）、phase-guide、bash-guard、subagent-context、pre-compact
缺失：post-write-tracker、stop-guard、completion-check、failure-tracker、retrospective 执行

### Codex 适配器

**能力级别**: 仅规则 + 引导（rules + guidance only）

- `adapters/codex/dispatch.sh` — 仅支持 SessionStart 和 Stop 事件
- SessionStart：stderr 输出转为 stdout（Codex 从 stdout 读取 additionalContext）
- Stop：将消息写入 `.codex/stop-hook.message.txt` 文件（避免污染 JSON 协议通道）
- 所有输出都带上 capability tier 声明

没有硬拦截能力 — Codex 的安全依赖其自身的 sandbox 和人类审批。

---

## 安装机制（setup.sh）

**版本**: 4.0（junction-based）

安装流程：
1. 确保 `~/.baton` 存在（clone 或 pull）
2. 检测是否是 self-install（baton 自身的源码仓库）
3. 选择 IDE（auto-detect 或 `--ide` / `--choose`）
4. 创建 `.baton/` junction → `~/.baton/.baton/`
5. 为每个 IDE 的 skills 目录创建 skill junctions
6. 生成/合并各 IDE 的 hook 配置文件
7. 更新 `.gitignore`

支持的 IDE：claude、codex、cursor、factory

Hook 注册细节：
- **Claude Code / Factory**: `.claude/settings.json` — 用 jq 合并（已有文件）或硬编码生成（新文件），包含所有 8 种事件的 dispatch 调用
- **Cursor**: `.cursor/hooks.json` — 生成 Cursor 格式的 hooks 配置 + `.cursor/rules/baton.mdc`（宪法作为 Cursor rules）
- **Codex**: `.codex/hooks.json` + `AGENTS.md`（宪法引用）+ `.codex/config.toml`（feature flag）+ `~/.codex/config.toml`（project trust）

---

## 跨平台兼容性

- **run-hook.cmd**: bash/cmd polyglot — Windows 上 cmd.exe 执行批处理部分寻找 Git Bash，Unix 上直接作为 shell 脚本
- **CRLF 处理**: dispatch.sh 在读取 manifest.conf 时对每个字段做 `${var%$'\r'}` 剥离 CR
- **路径处理**: plan-parser.sh 的 `parser_writeset_normalize()` 处理 Windows 驱动器字母路径（`C:/...`），使用 `cygpath` 做 POSIX 转换
- **Junction 优先**: Windows 使用 NTFS junction（不需要管理员权限或 Developer Mode），比 symlink 兼容性更好

---

## 事件类型汇总

| 事件 | 可阻止 | Hook | 核心功能 |
|------|--------|------|----------|
| SessionStart | 否 | phase-guide | 阶段检测 + 引导 + skill junction + 治理注入 |
| PreToolUse (Write/Edit/...) | 是 | write-lock | 写入锁 + write-set 执行 + 治理标记保护 |
| PreToolUse (Bash) | 是 | bash-guard | Shell 写入命令检测与拦截 |
| PostToolUse (Write/Edit/...) | 否 | post-write-tracker | Write-set 漂移警告 |
| PostToolUse (Write/Edit/...) | 否 | quality-gate | Self-Challenge 深度检查 |
| SubagentStart | 否 | subagent-context | 计划上下文注入 |
| Stop | 否 | stop-guard | 进度提醒 + 完成工作流引导 |
| TaskCompleted | 是 | completion-check | Retrospective 强制执行 |
| PostToolUseFailure | 否 | failure-tracker | 失败次数追踪 + 阈值警告 |
| PreCompact | 否 | pre-compact | 压缩前上下文快照 |

---

## 设计原则总结

1. **Fail-open**: 所有 hook 都有 `trap 'exit 0'` 作为错误处理 — hook 崩溃不应阻塞工作，但必须可见（stderr 警告）。
2. **子 shell 隔离**: dispatch.sh 在子 shell 中运行每个 hook，防止变量污染和退出码泄漏。
3. **Stdin 缓冲**: `BATON_STDIN` 环境变量解决了多个 hook 需要读取同一份 stdin 的问题。
4. **jq + awk 双路径**: 所有 JSON 解析都有 jq 首选 + awk/sed 回退，保证零依赖可用。
5. **分层能力降级**: Claude Code（全能力）→ Cursor（降级执行）→ Codex（仅规则），每个适配器明确声明自己的能力级别。
6. **Junction 分发**: 单一源（`~/.baton/`），项目通过 junction 引用 — 更新源即更新所有项目。
7. **Markdown 作为数据**: plan 文件中的 `<!-- BATON:GO -->`、`## Todo`、`Files:` 等结构既是人类可读文档，又是 hook 系统的机器可解析数据。

---

## 测试覆盖

共 18 个测试文件覆盖 hook 系统各个方面：

| 测试文件 | 覆盖范围 |
|----------|----------|
| test-dispatch.sh | dispatch.sh 路由逻辑 |
| test-write-lock.sh | write-lock 的各种场景 |
| test-bash-guard.sh | Bash 命令检测 |
| test-phase-guide.sh | 阶段检测状态机 |
| test-stop-guard.sh | 停止提醒逻辑 |
| test-plan-parser.sh | 解析器原语 |
| test-junction.sh | junction 创建 |
| test-adapters.sh / test-adapters-v2.sh | 适配器翻译 |
| test-new-hooks.sh | 新增 hook（failure-tracker 等） |
| test-setup.sh | 安装流程 |
| test-multi-ide.sh | 多 IDE 配置 |
| test-smoke.sh / test-full.sh | 冒烟/全量回归 |

---

## 关键文件路径

- 调度器: `.baton/hooks/dispatch.sh`
- 路由表: `.baton/hooks/manifest.conf`
- 跨平台入口: `.baton/hooks/run-hook.cmd`
- 共享库: `.baton/hooks/lib/common.sh`, `.baton/hooks/lib/plan-parser.sh`, `.baton/hooks/lib/junction.sh`
- Hook 脚本: `.baton/hooks/*.sh`（10 个）
- Cursor 适配器: `.baton/adapters/cursor/dispatch.sh`, `.baton/adapters/cursor/adapter.sh`
- Codex 适配器: `.baton/adapters/codex/dispatch.sh`, `.baton/adapters/codex/adapter.sh`
- 安装脚本: `setup.sh`

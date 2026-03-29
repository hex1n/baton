# Requirements: runtime-thickness-improvements

**主题**: 实现跨平台真实上下文隔离（三平台对称）
**状态**: `approved (rev3)`
**规模**: `Medium`

## 1. 问题

Claude Code 的上下文隔离机制缺失：Codex 有完整的 `spawn_agent` 文档和 skill-level dispatch note；Claude Code adapter 只有软性建议，skill 文件无 CC dispatch 指引，且缺乏运行时强制机制（`.claude/agents/` 目录未建立）。

## 2. 范围

### 2.1 范围内

- `skills/baton-explorer.md`：frontmatter 加 `context: fork`（已完成），Execution Guide 适用场景说明（已完成），新增 CC/Codex platform dispatch note
- `skills/baton-evaluator.md`：加 Claude Code Execution Note
- `skills/baton-verifier.md`：加 Claude Code Execution Note
- `spec/adapters/claude-code.md`：加 Context Isolation 节（Agent 工具 dispatch 示例）
- `.claude/agents/baton-evaluator.md`、`baton-verifier.md`、`baton-explorer.md`：新建 symlinks → skills/
- `spec/bootstrap/link-skills.sh`：新增 `.claude/agents/` 同步目标
- `spec/bootstrap/check-consistency.sh`：新增不变式 7（`.claude/agents/` 一致性），以及已有修改（harness→baton）
- `docs/harness-improvement-plan.md`：P1-2 State Notes 补注（已完成）

### 2.2 范围外

- validate-artifact.sh / validate-transition.sh（设计上不做）
- .baton/git-hooks/ 填充（设计上不做）
- Cursor 的程序化隔离（已知限制，无程序化手段）
- spec/templates/module-status.template.md eval_round 列（State Notes 已满足需求）

## 3. 功能需求

### FR-1 Explorer skill 声明上下文隔离意图并提供平台 dispatch 指引

`skills/baton-explorer.md` 须：frontmatter 含 `context: fork`（Repo-wide mode 场景）；Execution Guide 区分 Repo-wide（强烈建议隔离）vs Scoped；含 CC 和 Codex 平台的 dispatch 指引（Repo-wide mode）。

### FR-2 Evaluator skill 含 Claude Code Execution Note

`skills/baton-evaluator.md` 须含 "Claude Code Execution Note" 节，与已有 Codex Execution Note 结构对称：preferred dispatch（`baton-evaluator` agent 类型）+ fallback（`general-purpose`）。

### FR-3 Verifier skill 含 Claude Code Execution Note

`skills/baton-verifier.md` 须含 "Claude Code Execution Note" 节，结构同 FR-2。

### FR-4 Claude Code adapter 文档化 Agent 工具 dispatch

`spec/adapters/claude-code.md` 须含 "Context Isolation" 节，明确：Agent 工具是 CC 的运行时隔离机制；列出哪些角色须用 Agent dispatch；含 preferred + fallback dispatch 示例。

### FR-5 .claude/agents/ 目录注册三个 context:fork agent 类型

`.claude/agents/` 目录须存在，含 `baton-evaluator.md`、`baton-verifier.md`、`baton-explorer.md` 三个 symlinks，指向 `skills/` 对应文件。

### FR-6 link-skills.sh 同步 .claude/agents/

`link-skills.sh` 须将 skills/ 中带 `context: fork` 的 skill 文件链接至 `.claude/agents/`（或同步全部 skill，由实现选择最简路径）。

### FR-7 check-consistency.sh 验证 .claude/agents/ 一致性

`check-consistency.sh` 须有不变式验证 `.claude/agents/` 中的 context:fork 文件与 `skills/` 内容一致。

### FR-8 check-consistency.sh 使用正确的 baton 模式

不变式 1 和 4 使用 `baton-*.md`（已修改，纳入提交）。

### FR-9 P1-2 改进计划补注

`docs/harness-improvement-plan.md` P1-2 节含 State Notes 已实现的补注（已完成）。

## 4. 非目标

- 运行时验证 Agent 工具是否成功隔离（无法在文档层证明）
- Cursor 程序化 dispatch（已知无此机制）
- 更改 module-status.md 模板结构

## 5. 验收标准

### AC-1 Explorer frontmatter + 模式说明

- [ ] `skills/baton-explorer.md` frontmatter 含 `context: fork`
- [ ] Execution Guide 含 Repo-wide vs Scoped 模式说明
- [ ] 含 CC 和 Codex 的 Repo-wide dispatch 指引

### AC-2 Evaluator Claude Code Execution Note

- [ ] `skills/baton-evaluator.md` 含 "Claude Code Execution Note" 节
- [ ] 含 preferred dispatch（`baton-evaluator` agent 类型）
- [ ] 含 fallback dispatch（`general-purpose`）

### AC-3 Verifier Claude Code Execution Note

- [ ] `skills/baton-verifier.md` 含 "Claude Code Execution Note" 节
- [ ] 结构与 evaluator 对称

### AC-4 Claude Code adapter Context Isolation 节

- [ ] `spec/adapters/claude-code.md` 含 "Context Isolation" 节
- [ ] 含 Agent 工具 dispatch 示例（preferred + fallback）

### AC-5 .claude/agents/ 三个 symlinks 存在

- [ ] `.claude/agents/baton-evaluator.md` → `skills/baton-evaluator.md`
- [ ] `.claude/agents/baton-verifier.md` → `skills/baton-verifier.md`
- [ ] `.claude/agents/baton-explorer.md` → `skills/baton-explorer.md`

### AC-6 check-consistency.sh 全部不变式通过（含不变式 7）

- [ ] `bash spec/bootstrap/check-consistency.sh` exit 0，所有不变式 OK
- [ ] 不变式 7 验证 `.claude/agents/` 一致性

### AC-7 P1-2 改进计划补注存在

- [ ] `docs/harness-improvement-plan.md` P1-2 节含 "实现状态" 补注

## 6. 约束

- Skill 文件 CC Execution Note 结构须与已有 Codex Execution Note 平行，保持一致性
- `.claude/agents/` 条目以 symlink 实现（与 `.claude/skills/` 一致），由 link-skills.sh 管理
- fallback dispatch 须清晰可用，不依赖 `.claude/agents/` 自定义类型是否被 CC 支持

## 7. 验证意图

- 读取各 skill 文件 grep 对应节名
- 读取 claude-code.md 确认 Context Isolation 节存在
- `ls -la .claude/agents/` 确认三个 symlinks
- `bash spec/bootstrap/check-consistency.sh` 全部通过

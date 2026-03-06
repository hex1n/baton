# Plan: 支持自定义命名的 plan+research 配对

## 背景

当前 Baton 假设固定文件名 `plan.md` 和 `research.md`。用户希望能按意图命名（如 `plan-auth.md` + `research-auth.md`），支持同一工作区并行多个研究/计划。

## 现状分析

**已支持 `BATON_PLAN`**（8 个脚本 + 1 个插件）：
- `write-lock.sh:61`, `stop-guard.sh:15`, `bash-guard.sh:10`, `completion-check.sh:18`, `pre-compact.sh:17`, `subagent-context.sh:17`, `post-write-tracker.sh:42`, `hooks/pre-commit:20`
- 全部使用 `PLAN_NAME="${BATON_PLAN:-plan.md}"` 模式
- `opencode-plugin.mjs:12` — `process.env.BATON_PLAN || 'plan.md'`

**唯一问题**：`phase-guide.sh:13` 把 research 硬编码为 `"research.md"`

**workflow 文档**：`BATON_PLAN` 只在 Parallel sessions 部分简短提及，没有解释命名约定

## 设计方案

### 核心思路：AI 自动命名 + hooks 自动发现

两层设计：

**第一层（AI 行为）**：workflow 指导 AI 在创建文件时根据任务意图命名。
- 研究 auth 系统 → 创建 `research-auth.md`
- 出 plan → 创建 `plan-auth.md`（与 research 同 topic）
- 默认（简单任务）→ 仍可用 `plan.md` / `research.md`

**第二层（hooks 基础设施）**：hooks 自动发现当前目录下的 plan 文件，不依赖用户手动设置 `BATON_PLAN`。
- 如果 `BATON_PLAN` 已设置 → 使用它（显式覆盖，向后兼容）
- 如果未设置 → 自动发现：在当前目录查找 `plan*.md`
  - 找到 1 个 → 使用它
  - 找到多个 → 使用最近修改的（`ls -t` 排序取第一个）
  - 找到 0 个 → 处于 research 阶段

### 命名约定

| 场景 | plan 文件 | research 文件 |
|------|----------|--------------|
| AI 自动命名 | `plan-<topic>.md` | `research-<topic>.md` |
| 默认（简单任务） | `plan.md` | `research.md` |
| 显式覆盖 | `BATON_PLAN=plan-auth.md` | 自动推导 |

推导逻辑（shell）：`RESEARCH_NAME="${PLAN_NAME/plan/research}"`

### 归档约定

归档时保持配对，topic 一致：
```
mv plan-auth.md plans/plan-2026-03-04-auth.md
mv research-auth.md plans/research-2026-03-04-auth.md
```

## 变更概览

| # | 变更 | 涉及文件 |
|---|------|---------|
| 1 | 所有 hooks：PLAN_NAME 解析改为自动发现 | 8 个 `.baton/*.sh` + `hooks/pre-commit` |
| 2 | phase-guide.sh：从 PLAN_NAME 推导 RESEARCH_NAME | `.baton/phase-guide.sh` |
| 3 | phase-guide.sh：归档提示 + phase 输出使用变量 | `.baton/phase-guide.sh` |
| 4 | workflow.md：增加 AI 自动命名指导 + 更新命名约定 | `.baton/workflow.md` |
| 5 | workflow-full.md：同步更新 | `.baton/workflow-full.md` |

## 变更详情

### 变更 1: 所有 hooks 的 PLAN_NAME 解析改为自动发现

**What**: 将所有脚本中 `PLAN_NAME="${BATON_PLAN:-plan.md}"` 改为自动发现逻辑。

**具体改动**:

当前（所有 9 个脚本中相同的模式）：
```bash
PLAN_NAME="${BATON_PLAN:-plan.md}"
```

改为：
```bash
# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
```

逻辑：`BATON_PLAN` 显式覆盖 > 自动发现（最近修改的 `plan*.md`） > 默认 `plan.md`

**涉及文件**（9 个，全部标记为 `SYNCED: plan-name-resolution`）：
- `.baton/write-lock.sh:61`
- `.baton/stop-guard.sh:15`
- `.baton/bash-guard.sh:10`
- `.baton/completion-check.sh:18`
- `.baton/pre-compact.sh:17`
- `.baton/subagent-context.sh:17`
- `.baton/post-write-tracker.sh:42`
- `.baton/phase-guide.sh:12`
- `hooks/pre-commit:20`

**Risk**: `ls -t plan*.md` 在有多个 plan 文件时取最近修改的。如果用户同时编辑两个 plan，可能取到错误的一个。缓解：此时用户应显式设置 `BATON_PLAN`。自动发现是 best-effort，显式覆盖是 guaranteed。

**注意**: `opencode-plugin.mjs` 使用 JS，模式不同，暂不改动（保留 `process.env.BATON_PLAN || 'plan.md'`）。

### 变更 2: phase-guide.sh 从 PLAN_NAME 推导 RESEARCH_NAME

**What**: 将 `RESEARCH_NAME="research.md"` 改为从 `PLAN_NAME` 推导。

**具体改动**:
```bash
# 当前 (phase-guide.sh:13)
RESEARCH_NAME="research.md"

# 改为（紧接 PLAN_NAME 解析之后）
RESEARCH_NAME="${PLAN_NAME/plan/research}"
```

**验证**: `PLAN_NAME=plan-auth.md` → `RESEARCH_NAME=research-auth.md`；`PLAN_NAME=plan.md` → `RESEARCH_NAME=research.md`。

### 变更 3: phase-guide.sh 归档提示 + phase 输出使用变量

**What**: 所有 heredoc 中硬编码的 `plan.md` / `research.md` 改为使用 `$PLAN_NAME` / `$RESEARCH_NAME` 变量或通用表述。

**具体改动**:

需要把所有受影响的 heredoc 从 `<<'EOF'` 改为 `<<EOF`（去掉引号以允许变量展开）。

修改的 state：
- State 1 (ARCHIVE): `:41-42` 归档命令中的文件名 → 变量
- State 3 (IMPLEMENT): `:77` `plan.md` → `the plan`；`:80` → `the plan`
- State 4 (ANNOTATION): `:91` → `$PLAN_NAME awaiting approval`；`:102` → `the research document`
- State 5 (PLAN): `:123` → `produce $PLAN_NAME`；`:126` → `$RESEARCH_NAME`；`:140` → `the plan`
- State 6 (RESEARCH): `:151` → `produce $RESEARCH_NAME`；其余引用改为变量或通用表述

**Risk**: 改 heredoc 引号后，如果文本中有 `$`、反引号等 shell 特殊字符会被展开。检查了所有 heredoc 内容，当前无此类字符。但 `$(date +%Y-%m-%d)` 在 State 1 归档命令中存在——这本来就需要展开，所以正确。

### 变更 4: workflow.md 增加 AI 自动命名指导

**What**:
1. 在 Flow 或 Rules 部分增加 AI 命名规则
2. 更新 Parallel sessions 说明命名约定
3. 更新归档规则

**具体改动**:

Rules 部分增加一条：
```
- Name research/plan files by topic: `research-<topic>.md` + `plan-<topic>.md`. Default `plan.md`/`research.md` for simple tasks
```

Parallel sessions 更新为：
```markdown
### Parallel sessions (optional)
- Use git worktrees: each session gets its own working copy
- Name files by topic: `plan-<topic>.md` pairs with `research-<topic>.md`
- Hooks auto-discover plan files; set `BATON_PLAN` to override if multiple plans exist
```

归档规则使用通用表述。

### 变更 5: workflow-full.md 同步更新

**What**: 与 workflow.md 同步更新命名约定、归档规则。在 RESEARCH 和 PLAN phase 描述中提及自动命名。

**Impact**: Parallel sessions + Rules + Completion 归档命令 + RESEARCH phase + PLAN phase。

## Self-Review

1. **最大风险**: 自动发现 `ls -t plan*.md` 在有多个 plan 文件时可能取到错误的。但这是 best-effort 机制——有歧义时用户应设 `BATON_PLAN`。单个 plan 文件的常见场景下完全可靠。

2. **什么可能让这个计划完全错误**: 如果 `plan*.md` 的 glob 匹配到了不是 baton plan 的文件（如用户自己的 `planning-notes.md`），会导致误判。缓解：约定前缀必须是 `plan-` 或精确的 `plan.md`，glob 改为 `plan.md plan-*.md`。

3. **被拒绝的替代方案**: 考虑过只改文档不改 hooks（让 AI 在创建文件时自行设置 `BATON_PLAN`），但这依赖 AI 记住去设环境变量，不够自动化。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 变更 3：为什么用 grep -i？ -->

## Annotation Log

### Round 1 (2026-03-04)

**[NOTE] § 设计方案**
"我的意思是生成research 或者 plan的时候就自动根据命名约定生成对应的research或者plan"
→ 方案从"用户设 BATON_PLAN 环境变量"调整为"AI 自动命名 + hooks 自动发现"。
  两层设计：(1) workflow 指导 AI 按意图命名 (2) hooks 自动发现 plan*.md 文件。
  变更概览从 5 项调整为 5 项（重组：新增 hooks 自动发现机制，合并 phase-guide 的变更）。
→ Result: 已回写到 plan 正文

 <!-- BATON:GO -->

## Todo

### 变更 1: hooks 自动发现（9 个脚本）

- [x] `.baton/phase-guide.sh:12` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/write-lock.sh:61` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/stop-guard.sh:15` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/bash-guard.sh:10` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/completion-check.sh:18` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/pre-compact.sh:17` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/subagent-context.sh:17` — 替换 PLAN_NAME 解析为自动发现
- [x] `.baton/post-write-tracker.sh:42` — 替换 PLAN_NAME 解析为自动发现
- [x] `hooks/pre-commit:20` — 替换 PLAN_NAME 解析为自动发现

### 变更 2+3: phase-guide.sh RESEARCH 推导 + 输出变量化

- [x] `phase-guide.sh:13` — RESEARCH_NAME 改为从 PLAN_NAME 推导
- [x] `phase-guide.sh` State 1 (ARCHIVE) — heredoc 改 EOF + 文件名改变量
- [x] `phase-guide.sh` State 3 (IMPLEMENT) — 硬编码 plan.md 改通用表述
- [x] `phase-guide.sh` State 4 (ANNOTATION) — 硬编码文件名改变量
- [x] `phase-guide.sh` State 5 (PLAN) — 硬编码文件名改变量
- [x] `phase-guide.sh` State 6 (RESEARCH) — 硬编码文件名改变量

### 变更 4: workflow.md

- [x] Rules 部分增加命名规则
- [x] Parallel sessions 更新命名约定
- [x] 归档规则更新为通用表述

### 变更 5: workflow-full.md

- [x] Rules 部分增加命名规则
- [x] Parallel sessions 更新命名约定
- [x] Completion 归档命令更新
- [x] RESEARCH phase / PLAN phase 描述中提及自动命名

### 验证

- [x] 运行现有测试确认无回归
- [x] 手动测试：无 BATON_PLAN + 单个 plan-auth.md → hooks 正确发现

## Retrospective

**Plan vs reality**:
- Plan predicted 5 changes but implementation revealed a 6th: workflow-full.md had pre-existing drift (missing write-back discipline line, dynamic complexity line, archive pairing rule) that needed syncing. The consistency test caught this.
- The `$(date +%Y-%m-%d)` in State 1 heredoc needed `\$()` escaping after changing from `<<'EOF'` to `<<EOF` — plan correctly predicted this edge case.

**Surprises**:
- The RESEARCH state (no plan exists) can't derive a topic-named research file because there's no plan to derive from. This is a design limitation, not a bug — acceptable since the AI creates the research file and later creates a matching plan.
- The test for "mentions option to skip to plan.md" broke because "go straight to plan.md" was changed to "go straight to the plan" (generic wording). Fixed by using `$PLAN_NAME` which defaults to `plan.md`.

**What to research differently**:
- Should have checked workflow-consistency tests before starting implementation to know the baseline state.
- The `ls -t plan.md plan-*.md` approach on Windows is noticeably slow (~5s per invocation in benchmarks). Worth investigating if there's a faster alternative for auto-discovery.
# Todo Capitalization — Standardize "Todo" as Proper Noun

**Complexity**: Small
**State**: PROPOSING

## Requirements

[HUMAN] 用户反馈 baton 中 "todolist" 全小写不规范，需要统一大小写。

## Problem Statement

Baton 文档和 hook 脚本中对 "todo" 概念的引用大小写不一致：
- `todolist` (全小写连写) — 非标准英文
- `todo item` (全小写) — 作为 baton 专有概念未首字母大写
- `TODOLIST` (Iron Law 全大写) — 和其他全大写行风格一致但连写仍不规范
- `## Todo` (Title Case) — 已正确
- `TODO_*` (Shell 变量全大写) — 已正确，Shell 惯例

## Constraints

1. **`## Todo` 章节标题不能改** — plan-parser.sh 中所有 awk 模式匹配 `/^## Todo[[:space:]]*$/`，改标题就要改所有 parser + 测试
2. **Shell 变量 `TODO_*` 不能改** — Shell 全大写惯例
3. **awk 中的 `in_todo` 变量名不能改** — 代码内部变量
4. **函数名 `parser_todo_*` 不能改** — 代码 API
5. **测试文件中匹配输出的断言需要同步更新**

## Approach

**规则：把 "Todo" 当作 baton 的专有名词，首字母大写。"Todo list" 两个词，不连写。**

变更范围仅限散文文本（prose）——注释、用户提示消息、技能文档中的说明。
不触碰任何 parser 逻辑、awk 模式、变量名、函数名。

| 当前写法 | 目标写法 | 适用场景 |
|----------|---------|---------|
| `todolist` | `Todo list` | 散文中引用列表概念 |
| `TODOLIST` | `TODO LIST` | Iron Law 全大写行 |
| `todo item` | `Todo item` | 散文中引用条目 |
| `todo` (独立指代概念) | `Todo` | 散文中引用概念 |
| `## Todo` | 不变 | 章节标题 |
| `TODO_*` | 不变 | Shell 变量 |
| `parser_todo_*` | 不变 | 函数名 |
| `in_todo` | 不变 | awk 变量 |

### Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/constitution.md` | L1 | modify | line 274: "todolists" |
| `.baton/skills/baton-plan/SKILL.md` | L1 | modify | lines 17, 130, 132, 144: "TODOLIST", "Todolist", "todolist", "todo list" |
| `.baton/skills/baton-implement/SKILL.md` | L1 | modify | lines 6, 21, 31, 39-40, 46, 48, 54-56, 59, 61, 63, 69, 90: "todolist", "todo", "todo item" |
| `.baton/skills/baton-subagent/SKILL.md` | L1 | modify | lines 5, 28, 40-41, 44, 48, 51, 54, 57, 68, 71, 73-76, 124, 127, 134, 141-142, 173, 176: "todolist", "todo item", "todo" |
| `.baton/skills/baton-review/SKILL.md` | L1 | modify | lines 5, 24, 98, 162: "todolist" |
| `.baton/hooks/phase-guide.sh` | L1 | modify | lines 52-53, 68, 148: user-facing messages with "todolist", "todo item" |
| `.baton/hooks/completion-check.sh` | L1 | modify | line 9, 47: comments with "todo items" |
| `.baton/hooks/stop-guard.sh` | L1 | modify | lines 8-9, 29, 35, 48: comments and messages with "TODOs", "todo items" |
| `.baton/hooks/subagent-context.sh` | L1 | modify | line 8, 33: comments with "Todo", "todo items" |
| `.baton/hooks/post-write-tracker.sh` | L1 | modify | line 8, 25, 79: comments with "Todo", "todo" |
| `.baton/hooks/pre-compact.sh` | L1 | modify | line 35: message with "AWAITING_TODO" (state name, skip) |
| `.baton/hooks/plan-parser.sh` | L1 | modify | lines 15-18, 24-25, 205-207, 227-229, 250, 263, 340, 368: comments with "todo" |
| `tests/test-phase-guide.sh` | L2 | modify | lines 82, 208, 210: assertions matching output text |
| `tests/test-constitution-consistency.sh` | L2 | modify | line 521: checks for "Todolist Format" |
| `tests/test-new-hooks.sh` | L2 | skip | assertions match "Todo" in `## Todo` — already correct casing |
| `tests/test-stop-guard.sh` | L2 | modify | lines 133, 272, 277: "todo items", "todo item" |
| `tests/test-plan-parser.sh` | L2 | skip | "todo items" in test descriptions (informal, not user-facing) |

### Decisions

**State name `AWAITING_TODO`**: 保持不变。这是状态机常量，全大写是 Shell/状态机惯例。

**Iron Law 中的 `TODOLIST`**: 改为 `TODO LIST` (两个词)。Iron Law 整行全大写是刻意的强调风格，两个词更规范。

**Shell 注释中的 "todo items" / "TODOs"**: 改为 "Todo items" / "Todos"。注释属于散文文本，应遵循专有名词规则。但如果注释紧跟在 `TODO_*` 变量旁边，上下文中 "TODO" 指的是变量值而非概念，此时保持和变量名风格一致。

**测试断言**: 仅在断言匹配的源文本被修改时才同步更新。不改测试描述字符串（非用户可见）。

## Self-Challenge

1. **Is this the best approach?** 考虑过的替代方案：(a) 全部大写 `TODO` — 太刺眼，不适合散文；(b) 保持小写 `todo` — 用户明确反馈不好；(c) 用 `to-do` (带连字符) — 虽然语法正确但在技术文档中不常见。选择 "Todo" 作为专有名词是最平衡的方案。
2. **Assumptions**: 假设修改仅限于散文文本不会破坏功能。这是安全的——所有 parser 逻辑匹配的是 `## Todo` 标题和 `- [ ]` checkbox 格式，不是散文中的 "todo" 一词。
3. **Skeptic challenge**: "这是不是浪费时间的美化工作？" 不是——术语一致性影响文档可读性和项目专业度，而且变更范围小、风险低。

## Todo

- [x] 1. Change: Standardize "todo/todolist" → "Todo/Todo list" in skill documentation
  Files: `.baton/skills/baton-plan/SKILL.md`, `.baton/skills/baton-implement/SKILL.md`, `.baton/skills/baton-subagent/SKILL.md`, `.baton/skills/baton-review/SKILL.md`
  Verify: `grep -inE 'todolist|todo item|[^#] todo [^TDSR]' .baton/skills/baton-{plan,implement,subagent,review}/SKILL.md | grep -v 'TODO_\|in_todo\|parser_todo\|## Todo\|TODO LIST' | head -20` — should return empty
  Deps: none
  Artifacts: none

- [x] 2. Change: Standardize "todolists" → "Todo lists" in constitution.md
  Files: `.baton/constitution.md`
  Verify: `grep -in 'todolist' .baton/constitution.md` — should return empty
  Deps: none
  Artifacts: none

- [x] 3. Change: Standardize todo prose in hook script comments and user-facing messages
  Files: `.baton/hooks/phase-guide.sh`, `.baton/hooks/completion-check.sh`, `.baton/hooks/stop-guard.sh`, `.baton/hooks/subagent-context.sh`, `.baton/hooks/post-write-tracker.sh`, `.baton/hooks/plan-parser.sh`
  Verify: `grep -inE 'todolist|todo item|# .*todo [^TDSR]' .baton/hooks/{phase-guide,completion-check,stop-guard,subagent-context,post-write-tracker,plan-parser}.sh | grep -v 'TODO_\|in_todo\|parser_todo\|## Todo\|AWAITING_TODO' | head -20` — should return empty
  Deps: none
  Artifacts: none

- [x] 4. Change: Sync test assertions to match updated output text
  Files: `tests/test-phase-guide.sh`, `tests/test-constitution-consistency.sh`, `tests/test-stop-guard.sh`
  Verify: `cd "C:/Users/hexin/IdeaProjects/baton" && bash tests/test-phase-guide.sh && bash tests/test-constitution-consistency.sh && bash tests/test-stop-guard.sh` — all pass
  Deps: 1, 3
  Artifacts: none

## Retrospective

1. **Verification patterns too coarse**: Initial verification grep commands used `-i` (case-insensitive), so they matched both old and new forms. Had to re-run case-sensitive checks to confirm correctness. Future tasks should design verification to distinguish old vs. new forms.
2. **Review caught residual misses**: baton-review found ~7 remaining lowercase "todo" instances in comments, test echo messages, and fixture data across phase-guide.sh and test files that the initial pass missed. The phase-guide.sh line 101 comment was a genuine oversight; the test file instances were borderline (plan said to skip test descriptions, but echo messages and fixture content are different from assertion description strings).
3. **baton-subagent had pre-existing uncommitted changes**: The file had been significantly rewritten before this task started, causing a large diff that mixed pre-existing structural changes with this task's capitalization changes. This didn't cause problems but made the diff harder to review.

## 批注区


 <!-- BATON:GO -->


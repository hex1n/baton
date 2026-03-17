# Hook 多计划消歧

**Complexity**: Small
**Problem**: `parser_find_plan()` 发现多个活跃 plan 时直接设 `MULTI_PLAN_COUNT > 1`，下游 hook（write-lock、bash-guard、completion-check）无条件阻塞所有写入。并行任务场景（多 baton-tasks 目录、worktree）中，这导致合法实施被阻塞。

**Root cause**: 消歧逻辑缺失——有明显信号（BATON:GO 唯一性、target 路径归属）但没有使用。

## Requirements

[HUMAN] 用户要求：
1. 并行任务场景不应被多计划歧义阻塞
2. 不仅限于修改 `.baton/` 文件时——任何并行场景都要覆盖
3. Worktree 场景也要考虑

## Approach

### Recommendation: 只改 parser_find_plan()，下游 hook 零改动

两层消歧（在 `parser_find_plan()` 内部，多 plan 发现后、设 MULTI_PLAN_COUNT 前）：

1. **BATON:GO 唯一性**：多个活跃 plan 中恰好一个有 BATON:GO → 选它，`MULTI_PLAN_COUNT=1`。正在实施的任务只有一个。
2. **Target 上下文**：如果 `BATON_TARGET` env var 指向某个 `baton-tasks/<topic>/` 内的文件，且该 topic 目录下有 plan 在候选列表中 → 选它，`MULTI_PLAN_COUNT=1`。

Worktree 不需要特殊处理——worktree 有独立文件树，`ls baton-tasks/*/plan.md` 只看到该 worktree 内的 plan，天然隔离。

**核心优势**：`parser_find_plan` 消歧成功后 `MULTI_PLAN_COUNT=1`，所有下游 hook 自动放行，零改动。

### Why not alternatives

- **改下游 hook**：多处重复消歧逻辑，新 hook 容易遗漏
- **改 SKILL.md 加 pre-flight**：依赖 AI 遵守软约束，不如 parser 层硬编码可靠
- **自动删除旧 plan**：过于激进，破坏并行任务

## Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/hooks/plan-parser.sh` | L1 | modify | `parser_find_plan()` 加消歧逻辑（~20 行） |

所有下游 hook（write-lock、bash-guard、completion-check、phase-guide）：skip — 读取 `MULTI_PLAN_COUNT`，parser 修复后自动受益。

## Risk Mitigation

1. **消歧误选**：BATON:GO 唯一性是强信号（同一 session 只实施一个任务）；target 路径匹配是精确的目录级别。误选风险低。
2. **两个 plan 都有 GO**：BATON:GO 消歧失败，fall through 到 target 消歧。如果 target 也无法消歧，保持当前行为（MULTI_PLAN_COUNT > 1，阻塞）。不会比现在更差。
3. **Hook 自阻塞**：本次只改 plan-parser.sh（.sh 文件），write-lock 的 markdown 早退逻辑不影响它。但 multi-plan 检查会阻塞 .sh 写入。**缓解**：`export BATON_PLAN=baton-tasks/hook-disambiguation/plan.md`。

## Self-Challenge

1. **BATON:GO 唯一性假设** — 两个 plan 都有 GO 时消歧失败，但 target 消歧作为 fallback。两层都失败则保持阻塞（安全）。
2. **BATON_TARGET 可用性** — write-lock 在调用 find_plan 前已解析 TARGET 并可 export。phase-guide（SessionStart）没有 target 上下文，但 SessionStart 不阻塞写入，不需要消歧。
3. **复杂度** — 只改一个函数、加两个 if 块。比原 plan 的 5 文件改动简单得多。

## Todo

- [x] 1. ✅ BATON:GO 唯一性消歧
  Files: `.baton/hooks/plan-parser.sh`
  Verify: 创建两个 baton-tasks 目录各含 plan.md，只给一个加 BATON:GO，验证 `parser_find_plan` 选中有 GO 的那个且 `MULTI_PLAN_COUNT=1`
  Deps: none

- [x] 2. ✅ BATON_TARGET 路径消歧
  Files: `.baton/hooks/plan-parser.sh`
  Verify: 两个 plan 都有 GO（或都没有），设 `BATON_TARGET=baton-tasks/topic-a/some-file.sh`，验证选中 topic-a 的 plan
  Deps: 1

## 批注区
> 这个不需要改skill吧。还有更好的实现吗

✅ 同意不改 SKILL.md。已修订：只改 `plan-parser.sh` 一个文件，所有消歧在 parser 层完成，下游 hook 零改动。


<!-- BATON:GO -->

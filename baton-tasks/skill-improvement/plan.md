# Plan: Baton Skill Improvement (Thariq Article Insights)

**Complexity**: Medium
**Research**: `baton-tasks/skill-improvement/research.md`

## Requirements

- [HUMAN] 根据 Thariq 文章 "Lessons from Building Claude Code: How We Use Skills" 的最佳实践，改进 baton
- Research 确认 5 个 gap，按 ROI 排序：深层验证脚本 > 操作性 Gotchas > config.json > 持久化 > usage tracking

## Step 1: Problem Statement

Baton 的防御模型是三层：self-check → context-isolated review → human annotation。当前薄弱点：

1. **Self-check 层的程序化验证过于浅层** — 仅检查 section 存在性 + 行数，无法捕获如"research 缺少多源证据"或"plan 只有一个 approach"等语义级问题
2. **Skills 缺少操作性 Gotchas** — Red Flags 是静态理论防线（AI 合理化模式），缺少从真实使用中积累的踩坑记录
3. **Review 层未充分利用 Gotchas 知识** — review-prompt.md 没有从 Gotchas 中提取的具体对抗性问题

**不是的问题**：不是 hook 数量不够，不是 skill description 写得差（已 trigger-focused `[CODE]✅`），不是 folder structure 不对（已有渐进披露 `[CODE]✅`）。

## Step 2: Validated Inputs

From research `## Conclusions`:
1. Gap 2（深层验证）— actionable，现有 plan-parser.sh 可扩展 `[CODE]✅`
2. Gap 1（操作性 Gotchas）— actionable，文档级改动 `[DOC]✅`
3. Gap 3-5 — judgment-needed / watchlist，本轮不纳入

## Step 3: Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/hooks/lib/plan-parser.sh` | L1 | modify | 新增验证 primitives（1D 组）|
| `.baton/hooks/quality-gate.sh` | L1 | modify | 调用新 primitives，按文件类型分支 |
| `.baton/hooks/phase-guide.sh` | L2 | modify | ANNOTATION 状态添加验证摘要 |
| `.baton/skills/baton-research/SKILL.md` | L1 | modify | 添加 `## Gotchas` section |
| `.baton/skills/baton-plan/SKILL.md` | L1 | modify | 添加 `## Gotchas` section |
| `.baton/skills/baton-implement/SKILL.md` | L1 | modify | 添加 `## Gotchas` section |
| `.baton/skills/baton-review/SKILL.md` | L1 | modify | 添加 `## Gotchas` section |
| `.baton/skills/baton-review/review-prompt.md` | L1 | modify | 注入 Gotchas 衍生的对抗性问题 |
| `.baton/skills/baton-review/review-prompt-codebase.md` | L1 | modify | 同上（codebase 变体）|
| `tests/test-smoke.sh` | L1 | modify | 新增验证 primitives 测试 |
| `.baton/hooks/lib/common.sh` | L2 | skip | 已读 `[CODE]✅` — common.sh 仅 source plan-parser.sh 和提供 resolve/find 包装，新函数在 plan-parser.sh 中自包含，无命名冲突 |
| `.baton/hooks/manifest.conf` | L2 | skip | quality-gate 已注册为 `PostToolUse:Write,Edit,MultiEdit,CreateFile:quality-gate` `[CODE]✅`，无需改动 |
| `.baton/hooks/completion-check.sh` | L2 | skip | 已读 `[CODE]✅` — 功能为 Todo 完成度 + retrospective 验证，与本轮新增检查不重叠 |

## Step 4: Approaches

### Approach A: Verification + Gotchas（双层强化）— 推荐

**What**: 在 hook 层添加有限的语义验证 primitives，同时将 Gotchas 知识注入 review-prompt.md 以强化 review 层。

**How**:
- plan-parser.sh 新增 3 个函数（approach count、evidence labels、research methods）
- quality-gate.sh 调用它们做 advisory 检查
- 4 个 phase skills 各添加 Gotchas section（标记 `[DESIGN]❓`，待实际观察后升级）
- review-prompt.md 注入 Gotchas 衍生的具体对抗性问题

**Trade-offs**:
- ✅ 同时强化两层防御（hook + review），符合 constitution "defense is layered"
- ✅ Gotchas 注入 review 是 constitution 明确推荐的改进方式："Quality improvement comes from sharper review questions" `[DOC]✅`
- ✅ advisory only，不产生 mechanical compliance 压力
- ⚠️ hook 层的新检查仍是结构性检查（数标签/approach 数量），不检测语义质量
- 缓解：明确定位为"early warning"，真正的质量检查由 review 层完成

### Approach B: Review-Only

**What**: 不改 hooks，只将 Gotchas 注入 review-prompt.md 和 skills。

**How**: 纯文档改动，无代码变更。

**Trade-offs**:
- ✅ 最小改动量，零引入风险
- ✅ 完全符合 constitution 的改进偏好
- ❌ 放弃了 hook 层的 early warning — 要等到 review dispatch 才发现问题
- ❌ review 不总是被 dispatch（Trivial/Small 可能跳过）

### Approach C: Deep Semantic Verification

**What**: 用更复杂的 pattern-matching 做语义级验证（如检测 Self-Challenge 答案是否包含浅层回答模式）。

**How**: plan-parser.sh 添加正则匹配浅层回答模式。

**Trade-offs**:
- ✅ 真正检测内容质量而非结构
- ❌ 正则匹配脆弱，误报率高
- ❌ 实际上是在 hook 层做 review 的工作 — 越界
- ❌ Constitution 的层级模型明确区分 "hooks enforce structure, review enforces quality"

### 推荐理由

1. 同时加强两个层级，而不是只加强一个 `[DOC]✅`
2. Hook 层的新检查保持克制（3 个 primitives，advisory only），不越界做 review 的事 `[CODE]✅`
3. 将 Gotchas 知识同时放入 skills（指导 AI 生产）和 review-prompt（指导 AI 审查），形成闭环
4. Approach B 放弃了 early warning；Approach C 越界做了 review 的事

## Detailed Design

### Part 1: Verification Primitives（plan-parser.sh，1D 组）

**注意**：这些是结构性 early-warning 检查，不是语义质量检查。真正的质量由 review 层保证。

```bash
# parser_evidence_labels — count evidence label occurrences in a file
# Counts patterns like [CODE], [DOC], [RUNTIME], [HUMAN] (with optional ✅/❌/❓)
# Args:    $1 = file path
# Sets:    EVIDENCE_TOTAL (total label count)
# Note:    Structural presence check, not quality check.

# parser_research_methods — count investigation method headers in research
# Looks for "Step 2" or "Evidence Methods" section, counts numbered/bulleted items
# Args:    $1 = file path (defaults to $RESEARCH)
# Sets:    RESEARCH_METHOD_COUNT

# parser_approach_count — count "### Approach" headers in plan
# Only counts within ## Step 4 or ## Approaches section
# Args:    $1 = file path (defaults to $PLAN)
# Sets:    APPROACH_COUNT
```

原设计的 `parser_writeset_todo_coverage` 已移除 — review 指出 write-set 从 Todo 提取，自查是循环检查。

### Part 2: quality-gate.sh 扩展

```
For research files:
  - Evidence label count < 3 → advisory: "Research has few evidence labels — consider adding [CODE]/[DOC]/[RUNTIME] markers"
  - Research method count < 2 → advisory: "Research may lack independent evidence methods (need ≥2)"
  - Existing: Self-Challenge presence + depth ≥ 3 lines

For plan files:
  - Complexity detection: grep -qi 'Complexity:.*\(Trivial\|Small\)' → skip approach check
  - Approach count < 2 AND NOT Trivial/Small → advisory: "Plan has < 2 approaches for Medium+ task"
  - Existing: Self-Challenge presence + depth ≥ 3 lines
```

All checks remain **advisory** (exit 0). Output to stderr.

### Part 3: phase-guide.sh Enhancement

在 ANNOTATION 状态（State 4, lines 159-206）的现有检查之后，每次 SessionStart 都输出验证摘要：

```bash
# After existing annotation/Surface Scan checks (~line 205), add:
parser_approach_count "$PLAN"
_approach_ok="✓"; [ "${APPROACH_COUNT:-0}" -lt 2 ] && _approach_ok="⚠"
_sc_ok="✓"; grep -q '^## Self-Challenge' "$PLAN" 2>/dev/null || _sc_ok="⚠"
echo "📊 Plan: ${APPROACH_COUNT:-0} approaches ${_approach_ok} | Self-Challenge ${_sc_ok}" >&2
```

每次 State 4 都执行，无需额外状态管理。

### Part 4: Gotchas Sections（4 Skills）

每个 Gotchas section 顶部标注来源和清理机制：

```markdown
## Gotchas

> 初始条目标记 `[DESIGN]❓`（理论推导）。观察到实际发生后升级为 `[RUNTIME]✅`。
> 长期未观察到的条目应定期清理。
```

**baton-research Gotchas**:
- `[DESIGN]❓` 两个 ❓ 源一致 ≠ 验证。需要 [RUNTIME]✅ 或直接 code trace
- `[DESIGN]❓` "Nothing contradicted it" 不是 counterexample sweep。需主动搜索反证
- `[DESIGN]❓` 外部文档（blog/tutorial）是线索不是证据，需追溯到一手来源
- `[DESIGN]❓` 证据标签忘记标状态（✅/❌/❓），导致 reviewer 无法判断可信度

**baton-plan Gotchas**:
- `[DESIGN]❓` write-set 遗漏间接依赖文件（如改了 lib/ 但没列依赖它的 hooks）
- `[DESIGN]❓` Medium 任务只列一个 approach 就收敛
- `[DESIGN]❓` Surface Scan 的 "skip" 没给理由
- `[DESIGN]❓` Todo 项的 Verify 字段写 "run tests" — 太模糊，应指定具体命令

**baton-implement Gotchas**:
- `[DESIGN]❓` B 级 discovery 判断偷懒 — "这个小改动和计划相关" → 实际是范围蔓延
- `[DESIGN]❓` 标记 Todo 完成前没重新读修改后的代码
- `[DESIGN]❓` 测试通过后直接标完成，没检查改动文件的 consumers

**baton-review Gotchas**:
- `[DESIGN]❓` 文档说什么就信什么，不检查代码是否真的这样做
- `[DESIGN]❓` "No findings" 更可能是审查深度不够而非质量真的高
- `[DESIGN]❓` 只看 artifact 结构不看内容 — "有 Self-Challenge" ≠ "有深度"

### Part 5: Review Prompt Enhancement

在 `review-prompt.md` 和 `review-prompt-codebase.md` 中添加（控制在 4-5 条，避免机械化）：

```markdown
## Gotchas-Derived Checks
- Does the research use ≥2 genuinely independent evidence methods, or are "two methods" variations of the same approach?
- Are evidence labels present AND do they have status markers (✅/❌/❓)?
- For plans: does every Surface Scan "skip" decision have explicit justification?
- For plans: is the Verify field in each Todo item specific enough to actually execute?
```

### Part 6: Tests

扩展 `tests/test-smoke.sh`：
- Fixture research file with 0 labels → `parser_evidence_labels` returns 0
- Fixture research file with 5 labels → returns 5
- Fixture plan with 1 approach → `parser_approach_count` returns 1
- Fixture plan with 3 approaches → returns 3
- Verify quality-gate.sh outputs advisory for single-approach Medium plan
- Verify quality-gate.sh skips approach check for `Complexity: Trivial` plan

## Write Set

| File | Change Type |
|------|------------|
| `.baton/hooks/lib/plan-parser.sh` | 新增 3 个 1D primitives |
| `.baton/hooks/quality-gate.sh` | 扩展检查逻辑（research + plan 分支 + complexity 检测）|
| `.baton/hooks/phase-guide.sh` | ANNOTATION 状态添加验证摘要 |
| `.baton/skills/baton-research/SKILL.md` | 添加 `## Gotchas` section |
| `.baton/skills/baton-plan/SKILL.md` | 添加 `## Gotchas` section |
| `.baton/skills/baton-implement/SKILL.md` | 添加 `## Gotchas` section |
| `.baton/skills/baton-review/SKILL.md` | 添加 `## Gotchas` section |
| `.baton/skills/baton-review/review-prompt.md` | 添加 Gotchas-Derived Checks section |
| `.baton/skills/baton-review/review-prompt-codebase.md` | 添加 Gotchas-Derived Checks section |
| `tests/test-smoke.sh` | 新增 6 个验证测试 |

## Risks

1. **Alert fatigue** — advisory 输出过多导致用户忽视所有 hook 信息
   - 缓解：新增最多 2 条 advisory（evidence labels/methods 或 approach count），不显著增加噪音
   - 回退：revert plan-parser.sh 1D 组 + quality-gate.sh 变更，不影响现有功能

2. **Gotchas 内容过时** — `[DESIGN]❓` 条目长期未被验证，变成死文档
   - 缓解：section 顶部标注清理机制；定期审查时评估哪些从未触发

3. **假阳性** — Trivial/Small 任务被提示 ≥2 approaches
   - 缓解：quality-gate.sh 通过 complexity 标记检测跳过

4. **向后兼容** — 新 parser 函数名冲突
   - 缓解：延续 `parser_` 前缀约定 `[CODE]✅`，冲突概率极低

## Self-Challenge

1. **Hook 层的新检查是否真的有价值？**
   - 诚实回答：`parser_evidence_labels` 数标签数量是结构性检查，不检测质量。定位为 early warning——如果实际使用中没有帮助，应移除而非加强。真正的质量改进来自 Part 5（enriched review prompts）。

2. **Gotchas 是理论推导而非真实踩坑**
   - 诚实回答：标记 `[DESIGN]❓`。初始价值在于建立积累结构和清理机制，内容质量随使用时间提升。

3. **review-prompt.md 的改动会让 review 更机械吗？**
   - 控制在 4 条具体问题，每条都有明确的检查对象（不是空泛原则）。如条目膨胀会退化为检查单，需克制添加。

## Review Findings (Round 1)

**Accepted and addressed:**
- [Medium] Core tension with constitution → 重新定位 hook 层为 "early warning"，质量改进集中在 review-prompt 层
- [Medium] Gotchas 来源标注 → 所有条目标记 `[DESIGN]❓`，建立升级/清理机制
- [Major] Missing BATON:GO → 添加占位符（待人类放置）
- [Major] Circular write-set check → 移除 `parser_writeset_todo_coverage`
- [Major] Missing risk section → 添加 4 项风险 + 缓解
- [Minor] Self-Challenge #3 未入 design → complexity 检测逻辑已写入 Part 2
- [Minor] phase-guide.sh 描述不精确 → 明确为"每次 State 4 都执行"
- [Minor] Surface Scan skip 缺证据 → 添加 `[CODE]✅` 标注
- [Nitpick] 批注区 present ✅

## 批注区

### [Annotation 1]
- **Trigger**: `[DESIGN]❓` 这个标签是哪儿来的 有什么作用
- **Intent**: 理解 Gotchas 条目的标签设计
- **Response**: `[DESIGN]` 是 constitution.md §Evidence 定义的扩展证据标签，表示"设计意图/理论推导"（区别于 `[CODE]` 代码读取、`[RUNTIME]` 运行观察）。`❓` 表示未验证。组合含义：这条 Gotcha 是理论推导出来的，还没在实际使用中观察到。作用：(1) 标注可信度——读者知道这不是实战经验；(2) 建立升级路径——踩坑后升级为 `[RUNTIME]✅`；(3) 建立清理机制——长期 `[DESIGN]❓` 说明可能不准确。此设计源自 review 反馈：避免把分析推导伪装成实战积累。
- **Status**: ❓ 待确认
- **Impact**: clarification — 不影响 plan 方向，如果你觉得这套标签太复杂，也可以简化为只标"初始/已验证"两档
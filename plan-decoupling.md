# Plan: Baton 解耦 — 废除 workflow-full.md

**复杂度**: Large
**前置研究**: `research-decoupling-approaches.md`

## Requirements

1. [RESEARCH] 废除 `workflow-full.md`（方案 C），因为所有目标 IDE（Claude Code、Factory AI、Codex、Cursor）都支持 skills，`workflow-full.md` 的运行时消费路径永远不会触发。[RESEARCH] `research-decoupling-approaches.md` § Direction Reassessment After Round 2。[CODE] `README.md:137-140` 列出四个宿主。
2. [RESEARCH] 把 `Document Authority` 元信息从 `workflow-full.md` 上移到 `workflow.md`。[RESEARCH] § Annotation Log Round 1 Q2
3. [HUMAN] `.agents/` 保持通用 fallback 定位。[HUMAN] research 批注区 Round 1 Q3
4. [RESEARCH] 修复 plan 发现的 pwd vs JSON_CWD 不一致 + walk-up 缺陷：`find_plan()` 重构（合并名称发现到 walk-up 中）、`has_skill()` JSON_CWD 修复、`bin/baton:status()` 同步修复。[RESEARCH] § Direction Reassessment — 已知风险 + plan 批注 Round 2/7
5. [RESEARCH] Fork context 修复：在 fork-context SKILL.md 中内联 annotation rules，使其在 subagent 下自足。[RESEARCH] § Annotation Log Round 1 Q4

## Fundamental Constraints

1. **Hook 运行时兼容**：`phase-guide.sh` 改动后必须对所有 6 个状态（ARCHIVE → AWAITING_TODO → IMPLEMENT → ANNOTATION → PLAN → RESEARCH）输出正确指导。硬编码 fallback 是 safety net，不能丢。
2. **测试基线保持**：当前测试套件通过率 166/166。改动后所有保留的测试必须继续通过；删除的测试必须有明确理由（被测对象已不存在）。
3. **安装行为向后兼容**：已安装项目里可能有旧版 `workflow-full.md`，`setup.sh` 不应因此失败。
4. **Token budget**：~~`workflow.md` 当前 ~400 tokens。Document Authority 上移后应保持 <450 tokens。~~ 已移除。实际测量 `wc -w` = 1,079 words / 7,320 bytes，"~400 tokens" 基线不正确。Document Authority 新增约 2 行（~20 words），对 1,079 words 的文件无实质影响，不构成有效约束。（Round 3 批注 #3 修正）

## Approach Analysis

### Approach A: 废除 workflow-full.md（推荐）

从 research § Part 6 方案 C 推导。所有目标 IDE 支持 skills → `extract_section` from `workflow-full.md` 永远不会执行 → 文件无运行时消费者 → 直接废除。

- **Feasibility**: ✅ 可行。[CODE] `phase-guide.sh:68-133` 的 skill-present 分支完全跳过 `extract_section`；hardcoded fallback 已存在于每个 else 分支的 `|| cat <<'EOF'` 中。
- **Pros**: 消除所有 slim/full/skills 同步关系（研究确认的 15+ 个测试检查点中 ~8 个 DELETE、~8 个 MODIFY）；消除 `extract_section()` 函数；消除 setup.sh 的冗余复制
- **Cons**: 如果 skills 不可用（新项目未装、路径 bug），fallback 从完整方法论降级到 3-4 行硬编码摘要（完整内容的 ~10-15%）
- **Impact**: 14 个文件修改 + 1 个文件删除（Round 7 批注 #2 新增 bin/baton + test-cli.sh）
- **Mitigation**: 修复 `has_skill()` + `resolve_plan_name()` 的 pwd vs JSON_CWD 不一致 bug，提高 skill 发现和 plan 发现可靠性；hardcoded fallback 保留作为最后 safety net

### Approach B: 生成 workflow-full.md（generate-full.sh）

从 research § 4.2 阶段一推导。把 `workflow-full.md` 从手工维护改为自动生成。

- **Feasibility**: ✅ 可行，但投资回报低。
- **Pros**: 保留完整的 fallback 内容；消除手工同步（改为生成）
- **Cons**: 需要新增 ~80 行生成脚本 + SKILL.md 里加 export 标记 + CI 检查——**为一个永远不被运行时消费的文件投入工程量**
- **Ruled out because**: 研究 Round 2 确认所有目标 IDE 支持 skills，`workflow-full.md` 无运行时消费者。生成一个没人读的文件是过度工程。

### Approach C: 维持现状 + 只修 bug

- **Feasibility**: ✅ 但不解决核心问题。
- **Ruled out because**: 研究确认当前耦合是四层锁定的架构现实，维持现状意味着继续承担 O(N²) 的同步维护成本。

## Recommendation

**Approach A：废除 workflow-full.md**。

理由链：
- 所有目标 IDE 支持 skills [HUMAN] → `phase-guide.sh` skill-present 分支跳过 `workflow-full.md` [CODE] `phase-guide.sh:68-133` → 文件无运行时消费者 → 废除是最简方案 [RESEARCH] → hardcoded fallback 保留作为 safety net [CODE] `phase-guide.sh:73-77,90-94,109-113,127-132` → 同时修复 `has_skill()` + `resolve_plan_name()` 的 pwd vs JSON_CWD 不一致 bug，提高 skill 发现和 plan/phase 发现可靠性 [CODE] `_common.sh:10,32`

## Surface Scan

### L1 — 直接引用 `workflow-full` / `extract_section` / `WORKFLOW_FULL`

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow-full.md` | L1 | **delete** | 被废除的文件本身 |
| `.baton/hooks/phase-guide.sh` | L1 | modify | 删除 `WORKFLOW_FULL=`、4 个 `extract_section` 调用；保留 hardcoded fallback |
| `.baton/hooks/_common.sh` | L1 | modify | 删除 `extract_section()` 函数（22 行）；修复 `has_skill()` pwd bug（1 行） |
| `setup.sh` | L1 | modify | 删除 `cp workflow-full.md` 安装步骤（:1216-1219）；可选保留旧引用迁移代码（:949-953, :1047-1050） |
| `tests/test-workflow-consistency.sh` | L1 | modify | 删除 ~8 个 FULL-dependent 检查块；修改 ~8 个检查块移除 FULL 引用；更新 Document Authority 守卫注释 |
| `tests/test-annotation-protocol.sh` | L1 | modify | 删除所有 `$FULL` 引用的断言（~12 行）；保留 `$SLIM` 独立断言 |
| `tests/test-setup.sh` | L1 | modify | 删除 `assert_file_exists workflow-full.md`（:130） |

### L2 — 间接依赖

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L2 | modify | 新增 Document Authority 段落（~5 行）；更新 Enforcement Boundaries fallback 描述 |
| `tests/test-phase-guide.sh` | L2 | **modify** | 不直接引用 workflow-full.md，但 no-skill 场景的测试断言期待 `extract_section` 输出（来自 workflow-full.md），而非 hardcoded fallback。删除 extract_section 后，8 个断言会失败（见 Change List 5.4）。 |
| `README.md` | L2 | modify | 删除目录树中 workflow-full.md 条目（:119）；更新架构描述 |
| `docs/implementation-design.md` | L2 | modify | 重写三层架构叙述，删除 workflow-full.md 相关段落 |
| `tests/test-write-lock.sh` | L2 | **modify** | 现有 Test 16 只覆盖 JSON cwd + `plan.md`；需新增 JSON cwd + `plan-*.md` 回归测试以覆盖 `resolve_plan_name()` 修复在写锁硬门上的效果。（Round 4 批注 #1 新增） |
| `bin/baton` | L2 | **modify** | `status()` 函数（L128-145）有独立的 plan 发现逻辑，不使用 `_common.sh`，存在同样的 plan-*.md walk-up 缺陷。（Round 7 批注 #2 新增） |
| `tests/test-cli.sh` | L2 | **modify** | 现有 status 测试（L135-145）只覆盖 `plan.md`，需新增 `plan-*.md` 场景。（Round 7 批注 #2 新增） |

### L2 — Fork context（SKILL.md 修复）

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.claude/skills/baton-research/SKILL.md` | L2 | modify | 内联必要的 cross-cutting annotation rules（~10 行），使 fork context 自足 |
| `.claude/skills/baton-plan/SKILL.md` | L2 | **skip** | 不声明 `context: fork`（无 frontmatter `context:` 行），不在 subagent 中运行。（Round 2 批注 #3 修正） |

### Skip Justification

| File | Disposition | 如果不更新，用户会遇到什么？ |
|------|-------------|----------------------------|
| `setup.sh:949-953, :1047-1050` | skip（迁移代码） | 无影响。这些迁移旧 `@.baton/workflow-full.md` 引用为 `@.baton/workflow.md`——对已安装项目仍有价值，保留作为向后兼容。 |
| `.claude/skills/baton-plan/SKILL.md` | skip | 无影响。不声明 `context: fork`，不在 subagent 中运行，不需要内联 annotation rules。（Round 2 批注 #3 修正：从 modify 降级为 skip） |
| `.claude/skills/baton-implement/SKILL.md` | skip | 无影响。该 skill 不标记 `context: fork`，不在 subagent 中运行，不需要内联 annotation rules。 |

## Change List

### Group 1: Core — 废除 workflow-full.md 运行时路径

**1.1 删除 `.baton/workflow-full.md`**
- 删除文件。
- 存档到 `plans/` 供历史参考（可选）。

**1.2 简化 `.baton/hooks/phase-guide.sh`**
- 删除 L6 注释中 "workflow-full.md" 引用
- 删除 L20 `WORKFLOW_FULL=` 赋值
- 4 个状态分支（IMPLEMENT/ANNOTATION/PLAN/RESEARCH）：删除 `extract_section ... >&2 ||` 调用，直接输出 hardcoded fallback。else 分支从 `extract_section ... || cat <<'EOF'` 简化为 `cat <<'EOF'`
- 修正 PLAN fallback 文案大小写：`Todolist` → `todolist`（L112），使与 `test-phase-guide.sh:84` 的 `grep -q "todolist"` 断言一致。[CODE] `phase-guide.sh:112` 当前为 `Todolist generated only after human says so.`，grep 大小写敏感。（Round 2 批注 #2 修正）
- 保留 hardcoded fallback 其余文本不变（它们是 safety net）

**1.3 清理 `.baton/hooks/_common.sh`**
- 删除 `extract_section()` 函数（L44-65，含注释共 22 行）。无其他调用者。[CODE] Surface scan 确认 `phase-guide.sh` 是唯一生产调用者；`test-workflow-consistency.sh:14-16` 有同名但独立的本地定义。
- 修复 `has_skill()` L32：`_hs_d="$(pwd)"` → `_hs_d="${JSON_CWD:-$(pwd)}"`
- 重构 `resolve_plan_name()` + `find_plan()`：将 plan 名称发现合并到 `find_plan()` 的逐级向上搜索中。（Round 2 批注 #1 + Round 7 批注 #1 修正）
  - **问题根因**：当前设计分两步：`resolve_plan_name()` 在起始目录 glob → `find_plan()` 拿着固定名称向上搜索。但 plan 名称取决于文件所在目录，而非起始目录。从子目录运行时，起始目录无 plan 文件 → 名称默认为 `plan.md` → walk-up 找不到 `plan-feature.md`。
  - **修复方式**：`find_plan()` 在每一级目录同时做名称发现和文件查找：
    ```bash
    find_plan() {
        PLAN=""
        _fp_d="${JSON_CWD:-$(pwd)}"
        if [ -n "${BATON_PLAN:-}" ]; then
            PLAN_NAME="$BATON_PLAN"
            while true; do
                [ -f "$_fp_d/$PLAN_NAME" ] && { PLAN="$_fp_d/$PLAN_NAME"; return; }
                _fp_p="$(dirname "$_fp_d")"
                [ "$_fp_p" = "$_fp_d" ] && return
                _fp_d="$_fp_p"
            done
        else
            while true; do
                _fp_c="$(cd "$_fp_d" 2>/dev/null && ls -t plan.md plan-*.md 2>/dev/null | head -1)"
                if [ -n "$_fp_c" ]; then
                    PLAN_NAME="$_fp_c"
                    PLAN="$_fp_d/$_fp_c"
                    return
                fi
                _fp_p="$(dirname "$_fp_d")"
                [ "$_fp_p" = "$_fp_d" ] && { PLAN_NAME="plan.md"; return; }
                _fp_d="$_fp_p"
            done
        fi
    }
    ```
  - `resolve_plan_name()` 保留为向后兼容 shim：仅处理 `BATON_PLAN` 显式设定场景；未设定时设为空，由 `find_plan()` 在 walk-up 中自动发现。
  - **调用者影响**：8 个 hook 当前调用 `resolve_plan_name` → `find_plan`。改造后 `find_plan()` 同时设置 `PLAN_NAME` 和 `PLAN`，调用者使用 `PLAN_NAME` 派生 `RESEARCH_NAME` 的代码需移到 `find_plan()` 之后（仅影响 `phase-guide.sh:25`）。
  - 影响范围：所有 8 个 hook 通过 `source _common.sh` 自动受益。[CODE] phase-guide.sh, stop-guard.sh, write-lock.sh, completion-check.sh, subagent-context.sh, post-write-tracker.sh, bash-guard.sh, pre-compact.sh。

### Group 2: Authority 上移

**2.1 更新 `.baton/workflow.md`**
- 在 `### Enforcement Boundaries` 之前新增 `### Document Authority` 段落：
  ```
  ### Document Authority
  - **workflow.md** — foundational protocol, always loaded. The core contract.
  - **SKILL.md files** — normative phase specifications. Authoritative for their respective phases.
  ```
  （2 行，~20 tokens。去掉了 workflow-full.md 条目。不包含 README.md——[CODE] `test-workflow-consistency.sh:494-500` 禁止 workflow.md 引用 README.md，且 README 的非规范性不需要在 slim 协议中声明。）
- 更新 `### Enforcement Boundaries` 末行"Fallback guidance"描述：移除 "Without phase-specific skill discipline" 的暗示，改为明确说明 fallback 是 hardcoded summary。

### Group 3: Fork Context 自足

**3.1 更新 `.claude/skills/baton-research/SKILL.md`**
- 在现有 annotation 规则引用处（当前 L218："Cross-cutting annotation rules... live in `workflow.md`"），补充内联摘要（~10 行）：
  - `[PAUSE]` 信号说明
  - intent inference + file:line 验证
  - 结论写回文档本体
  - Annotation Log 格式要求
- 保留 workflow.md 引用作为 "full details" 指向，但 fork context 不再依赖它

**3.2 ~~更新 `.claude/skills/baton-plan/SKILL.md`~~** — 已移除
- baton-plan/SKILL.md 不声明 `context: fork`，不在 subagent 中运行，无需内联。（Round 2 批注 #3 修正）

### Group 4: 安装与分发

**4.1 更新 `setup.sh`**
- 删除 L1210：`echo "  ✓ workflow-full.md (self-install, skipping copy)"` — 文件已不存在，self-install 状态输出会误导
- 删除 L1216-1219（`cp workflow-full.md` 安装步骤 + 注释）
- 保留 L949-953 和 L1047-1050 的旧引用迁移代码（向后兼容已安装项目）

### Group 4b: CLI plan 发现同步（Round 7 批注 #2 新增）

**4b.1 更新 `bin/baton`**
- `status()` 函数（L128-145）有独立的 plan 发现逻辑，不使用 `_common.sh`。需要同步修复使其在子目录中也能发现父目录的 `plan-*.md`。
- 修改 L132-139 的 plan file 发现逻辑：从只在 `$_dir` 下 glob 改为向上遍历目录（与 `_common.sh:find_plan()` 等价行为）。
- 保留 `BATON_PLAN` 显式设置路径不变。

**4b.2 新增 `tests/test-cli.sh` plan-*.md 回归测试**
- 在现有 Test 8（L135-145，`plan.md` + GO → IMPLEMENT）附近新增一个测试：
- 在临时目录创建 `plan-feature.md`（非默认名，含 GO + Todo）
- 运行 `baton status "$d"` 断言输出包含 `IMPLEMENT`（而非 fallback 到 `RESEARCH`）

### Group 5: 测试重构

**5.1 更新 `tests/test-workflow-consistency.sh`**

DELETE（测试对象已不存在）：
- L7：`FULL=` 变量声明
- L14-16：本地 `extract_section()` helper
- L18-30：slim/full 共享章节一致性循环（Mindset, Action Boundaries, File Conventions, Session Handoff）
- L85-101：Flow line slim/full diff
- L103-125：phase-guide 关键词 vs FULL 交叉验证
- L166-179：Self-Review vs FULL
- L473-479：Surface Scan hint in FULL
- L481-488：Cascading triggers in FULL

MODIFY（移除 FULL 引用，保留独立有效的部分）：
- L32-43：core concept 循环 — 删除 `grep "$concept" "$FULL"` 半边，保留 SLIM 检查
- L127-135：批注区 — 删除 FULL 检查
- L137-153：Complexity levels — 删除 FULL 检查
- L155-164：Anti-sycophancy — 删除 FULL 检查
- L181-190：Retrospective — 删除 FULL 检查，保留 stop-guard.sh 检查
- L284-299：`[PAUSE]` 文件循环 — 从 `for f in` 列表中移除 `"$FULL"`
- L363-371：Nested BATON:GO — 移除 FULL 循环臂
- L373-382：Todo format — 移除 FULL 条件
- L502-508：Document Authority 守卫 — 保留"workflow.md 不应包含 Document Authority"的**负面检查**逻辑（因为 Document Authority 现在确实要进 workflow.md），所以这条需要**反转**：改为"workflow.md 必须包含 Document Authority"的正面检查。更新注释。

**5.2 更新 `tests/test-annotation-protocol.sh`**

DELETE：
- L7：`FULL=` 变量声明
- L40：`[PAUSE]` in FULL
- L42-44：annotation 关键概念 in FULL
- L52：legacy markers absent from FULL
- L57-65：detailed annotation sections in FULL
- L72, L74：core principles in FULL
- L86-90：plan analysis section in FULL

KEEP：所有 `$SLIM` 断言不变。

**5.3 更新 `tests/test-setup.sh`**
- 删除 L130：`assert_file_exists "$d/.baton/workflow-full.md"`
- 新增负向断言：`assert_file_not_exists "$d/.baton/workflow-full.md"`（fresh install 后该文件不应存在）。如果 `assert_file_not_exists` helper 不存在，先添加（与现有 `assert_file_exists` 对称）。（Round 6 批注 #1 新增）

**5.4 更新 `tests/test-phase-guide.sh`**（Round 1 批注 #1 修正）

删除 `extract_section` 后，no-skill 场景的输出从 workflow-full.md 完整段落降级为 hardcoded fallback（3-4 行/阶段）。以下断言期待只存在于 workflow-full.md 中的内容，会失败：

| Test | 断言行 | 期待内容 | 在 hardcoded fallback 中？ | 处理 |
|------|--------|---------|--------------------------|------|
| Test 1 RESEARCH | L72 | "documentation retrieval" | ❌ 不存在 | DELETE |
| Test 1 RESEARCH | L73 | "Self-Review" | ❌ 不存在 | DELETE |
| Test 2 PLAN | L89 | "Self-Review" | ❌ 不存在 | DELETE |
| Test 2 PLAN | L90 | "Approach Analysis" | ❌ 不存在 | DELETE |
| Test 3 ANNOTATION | L101 | "Consequence detection" | ❌ 不存在 | DELETE |
| Test 3 ANNOTATION | L108 | "blind compliance" | ❌ 不存在 | DELETE |
| Test 4 IMPLEMENT | L121 | "typecheck" | ❌ 不存在 | DELETE |
| Test 4 IMPLEMENT | L124 | "re-read the modified code" | ❌ 不存在 | DELETE |

保留的断言（在 hardcoded fallback 中存在，不受影响）：
- Test 1: "implementations", "file:line", "entry points", "subagent", "批注区", "Spike" ✅
- Test 2: "approach", "constraints", "批注区", "todolist" ✅
- Test 3: `\[PAUSE\]`, "Free-text is the default", "file:line", "BATON:GO" ✅
- Test 4: "3x", "BATON:GO" ✅

**5.5 新增 `tests/test-phase-guide.sh` JSON_CWD 回归测试**（Round 1 补充建议 + Round 2 批注 #1 扩展）

在现有 Test 16（walk-up 测试，L273-279）之后新增两个测试：

**Test A: has_skill via JSON_CWD**
- 设置 `JSON_CWD` 环境变量指向项目根目录
- 从一个不包含 skills 的临时目录执行 phase-guide.sh
- 断言 `has_skill` 通过 `JSON_CWD` 找到 skill（输出包含 `/baton-research`）
- 验证 `has_skill()` 的 `${JSON_CWD:-$(pwd)}` 修复生效

**Test B: resolve_plan_name via JSON_CWD**（Round 2 批注 #1 新增）
- 在临时目录下创建 `plan-feature.md`（非默认名）
- 设置 `JSON_CWD` 指向该临时目录
- 从一个**不含** plan 文件的其他目录执行 phase-guide.sh
- 断言输出包含 `ANNOTATION`（或 `PLAN`），而非 fallback 到 `RESEARCH`
- 验证 `resolve_plan_name()` 在 `JSON_CWD` 目录下执行 glob，而非在 pwd 下

**5.6 新增 `tests/test-write-lock.sh` JSON_CWD + plan-*.md 回归测试**（Round 4 批注 #1 新增）

在现有 Test 16（L287-299，JSON cwd + plan.md）之后新增一个测试：
- 在临时目录下创建 `plan-feature.md`（非默认名，含 `<!-- BATON:GO -->` + `## Todo`）
- 构造 stdin JSON：`{"tool_input":{"file_path":"src/app.ts"},"cwd":"<tmp>/project/src"}`
- 从项目外目录（`$tmp`）执行 write-lock.sh
- 断言：允许写入（exit 0）——因为 `resolve_plan_name()` 通过 `JSON_CWD` 找到 `plan-feature.md`，`find_plan()` 找到含 GO 标记的 plan
- 这覆盖了 write-lock.sh 作为硬门的真实输入路径（stdin JSON → JSON_CWD → resolve_plan_name → find_plan），验证修复在最关键的 hook 上生效。[CODE] `write-lock.sh:30-43` 解析 JSON_CWD，`test-write-lock.sh:287-299` 现有测试只覆盖 `plan.md`。

### Group 6: 文档更新

**6.1 更新 `README.md`**
- 删除 L119 目录树中 `workflow-full.md` 条目
- 更新相关架构描述段落

**6.2 更新 `docs/implementation-design.md`**
- 重写三层架构叙述：删除 workflow-full.md 相关描述
- 更新为两层模型：`workflow.md`（cross-cutting core）+ `SKILL.md`（per-phase authority）
- 更新 phase-guide 描述：skills-first + hardcoded fallback（不再有 extract_section）

## Risks + Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skills 不可用时（新项目、路径 bug）fallback 质量从完整方法论降到 3-4 行 | Medium | (1) 修复 `has_skill()` + `resolve_plan_name()` 的 pwd vs JSON_CWD bug，提高 skill 发现和 plan 发现可靠性；(2) hardcoded fallback 保留核心纪律；(3) 所有目标 IDE 确认支持 skills |
| 测试数量下降——删除的测试是否有独立价值？ | Low | 删除的测试全部依赖 workflow-full.md 作为被测对象。被测对象不存在→测试无意义。保留的 SLIM/skills 测试覆盖 authority 核心 |
| 已安装项目里残留旧 `workflow-full.md` | Low | setup.sh 不再复制新文件，但不主动删除旧文件。旧文件成为惰性文件，不影响运行时（skill 路径跳过 extract_section） |
| docs/implementation-design.md 重写遗漏 | Low | 该文件是纯文档，不影响运行时。实施时通读全文确认所有 workflow-full 引用 |

## Self-Review

### Internal Consistency Check

- ✅ Recommendation（Approach A）与 Change List 一致——所有改动都是围绕废除 workflow-full.md 展开
- ✅ 每个 Change Item 都追溯到 Approach A 的具体理由
- ✅ Surface Scan 中所有 "modify" 文件都出现在 Change List 中（Round 1 修正：test-phase-guide.sh 从 skip 改为 modify）
- ✅ Surface Scan 中 "skip" 文件都有明确理由（迁移代码保留向后兼容；baton-implement 不在 fork context；baton-plan 不在 fork context — Round 2 批注 #3 修正）
- ✅ Document Authority 上移方向与 Change List Group 2 一致，且不包含 README.md（避免触发 L494-500 drift guard）
- ✅ setup.sh 清理完整：L1210 self-install 消息 + L1216-1219 copy 步骤
- ✅ Plan 发现修复覆盖完整：`find_plan()` 重构为逐级 walk-up 时同时发现名称和文件；`has_skill()` L32 修复 JSON_CWD；`bin/baton:status()` 同步修复。（Round 7 批注 #1+#2 修正）
- ✅ 回归测试覆盖三条路径：phase-guide.sh（advisory, Test A + B）、write-lock.sh（hard gate, Change 5.6）、baton CLI（Change 4b.2）。（Round 5+7 修正）
- ✅ 高层理由链（Approach A Mitigation、Recommendation、Risk table）与 Change List 同步：均已更新为同时提及 `has_skill()` + `resolve_plan_name()`。（Round 5 批注 #2 修正）
- ✅ PLAN fallback 大小写修正：`Todolist` → `todolist`，避免 grep 大小写敏感导致测试失败。（Round 2 批注 #2 修正）
- ✅ 关键前提已验证：
  - `has_skill` 返回 true 时 `extract_section` 被跳过 [CODE] `phase-guide.sh:68-133`（本 session 读取确认）
  - `extract_section()` 无其他调用者 [CODE] surface scan 确认
  - `test-phase-guide.sh` 不引用 `$FULL` 变量，但 8 个断言依赖 extract_section 输出内容 [CODE] `test-phase-guide.sh:72-73,89-90,101,108,121,124`（Round 1 修正确认）
  - `test-workflow-consistency.sh:494-500` 禁止 workflow.md 引用 README.md [CODE]（Round 1 修正确认）
  - `baton-plan/SKILL.md` 不声明 `context: fork` [CODE] grep 确认无 `context:` 行（Round 2 批注 #3 确认）
  - `resolve_plan_name()` 的 `ls -t` 在 pwd 执行 [CODE] `_common.sh:10`（Round 2 批注 #1 确认）

### External Risks

- **最大风险**：`has_skill()` 和 `resolve_plan_name()` 的 pwd bug 修复后仍有路径解析边界情况（如 symlinked 项目目录），导致 skill 或 plan 找不到。Mitigation：修复后在 test-phase-guide.sh 中验证 JSON_CWD 场景（Test A + Test B）以及在 test-write-lock.sh 中验证写锁硬门路径（Change 5.6）。
- **什么会让这个 plan 完全错误**：如果未来有新的 IDE 目标不支持 skills（如 aider、Continue），hardcoded fallback 不够用。但这与人类决策"所有目标 IDE 支持 skills"矛盾——如果前提变化，需要重新评估。
- **被否决的替代方案**：Approach B（generate-full.sh）是更保守的选择——如果废除后发现 fallback 不够用，可以回退到生成方案。但当前证据不支持这个担忧。

## Annotation Log

### Round 1

**[inferred: gap-critical] § test-phase-guide.sh 不能 skip**
“高风险：tests/test-phase-guide.sh 不能按计划 skip...当前无-skill 场景下，测试实际验证的是运行时输出，而这些输出今天主要来自 extract_section”
→ 验证：✅ 正确。[CODE] `test-phase-guide.sh:72` 期待 “documentation retrieval”、`:73` 期待 “Self-Review”——这些在 hardcoded fallback（`phase-guide.sh:127-132`）中不存在，来自 `extract_section` 从 workflow-full.md 提取的完整段落。PLAN/ANNOTATION/IMPLEMENT 同理，共 8 个断言会失败。
→ Consequence: test-phase-guide.sh 从 Surface Scan “skip” 改为 “modify”。新增 Change 5.4（列出 8 个 DELETE 断言）和 Change 5.5（JSON_CWD 回归测试）。Self-Review 更新。
→ Result: accepted

**[inferred: gap-medium] § Document Authority README.md 冲突**
“中风险：Document Authority 上移后...tests/test-workflow-consistency.sh:494-500 明确禁止 workflow.md 引用 README.md”
→ 验证：✅ 正确。[CODE] `test-workflow-consistency.sh:494-500` 检查 `grep -q 'README\.md' “$SLIM”`，如果匹配则 DRIFT 失败。原计划的 Document Authority 包含 “README.md” 条目。
→ Consequence: Document Authority 段落从 3 行改为 2 行，移除 README.md 条目。README 的非规范性不需要在 slim 协议中声明。这同时避免了触发 L494-500 drift guard，该守卫无需修改。
→ Result: accepted

**[inferred: gap-medium] § setup.sh self-install 消息遗漏**
“中风险：setup.sh 清理少了一处...setup.sh:1210 这句 workflow-full.md (self-install, skipping copy)”
→ 验证：✅ 正确。[CODE] `setup.sh:1210` 打印 `”  ✓ workflow-full.md (self-install, skipping copy)”`。文件删除后这条消息误导。
→ Consequence: Change 4.1 新增删除 L1210。Self-Review setup.sh 清理条目更新。
→ Result: accepted

**[inferred: depth-issue] § has_skill() JSON_CWD 回归测试**
“补充建议：把 has_skill() 的 JSON_CWD 回归测试显式写进计划”
→ 验证：✅ 合理。[CODE] `test-phase-guide.sh:273-279` 现有 walk-up 测试只用 pwd 场景（`assert_output_contains “$d/src/deep”`），不覆盖 `JSON_CWD` 环境变量传入的场景。
→ Consequence: 新增 Change 5.5，在 test-phase-guide.sh 中加入 JSON_CWD 场景测试。
→ Result: accepted

### Round 2

**[inferred: gap-critical] § resolve_plan_name() pwd bug**
“高: JSON_CWD 相关修复仍然只修了一半...resolve_plan_name() 仍然只看当前 pwd...我本地复现了一个只含 plan-feature.md 的项目：从项目外执行、只设置 JSON_CWD 时，phase 仍然掉回 RESEARCH”
→ 验证：✅ 正确。[CODE] `_common.sh:10` `ls -t plan.md plan-*.md` 在 shell pwd 下执行，不尊重 `JSON_CWD`。`find_plan()` 虽然从 `JSON_CWD` 开始查找，但 `PLAN_NAME` 已被 `resolve_plan_name()` 错误地设为默认 `plan.md`（因为 pwd 下没有 plan 文件），导致 `find_plan()` 找不到实际的 `plan-feature.md`。8 个 hook 全部受影响。
→ Consequence: Change 1.3 新增 `resolve_plan_name()` 修复（`cd “${JSON_CWD:-$(pwd)}”` 后执行 glob）。Change 5.5 新增 Test B 验证 plan name resolution via JSON_CWD。Self-Review 更新。Risks 表的”最大风险”描述更新为同时覆盖两个函数。
→ Result: accepted

**[inferred: gap-medium] § PLAN fallback Todolist 大小写**
“中: tests/test-phase-guide.sh 的删改清单还是少算了一条...现有测试是小写 todolist...hardcoded PLAN fallback 写的是 Todolist 大写开头...grep 这里是大小写敏感的”
→ 验证：✅ 正确。[CODE] `phase-guide.sh:112` `Todolist generated only after human says so.`（大写 T）。[CODE] `test-phase-guide.sh:84` `assert_output_contains “$d” “todolist”`（小写 t）。[CODE] `test-phase-guide.sh:25` 使用 `grep -q`（大小写敏感）。当前通过是因为 `extract_section` 从 workflow-full.md 提取的内容包含小写 todolist。
→ Consequence: Change 1.2 新增 fallback 文案修正（`Todolist` → `todolist`）。这比删除断言更好——保持测试覆盖 + 修正文案一致性。8 个 DELETE 断言计数不变。
→ Result: accepted

**[inferred: evidence-gap] § baton-plan fork context 证据不足**
“baton-plan 为什么仍被列为 fork-context 自足修复的必改项...当前只有 baton-research/SKILL.md 声明了 context: fork，而 baton-plan/SKILL.md 没有”
→ 验证：✅ 正确。[CODE] `baton-research/SKILL.md:12` 有 `context: fork`。`baton-plan/SKILL.md` 无 `context:` 声明（grep 确认）。baton-plan 在主对话中通过 `/baton-plan` 调用，不在 subagent 中运行。
→ Consequence: Surface Scan 中 baton-plan 从 “modify” 降级为 “skip”（补充 skip 理由）。Change 3.2 标记为已移除。Skip Justification 表新增 baton-plan 条目。
→ Result: accepted

### Round 3

**[inferred: duplicate — already addressed in Round 2] § #1 resolve_plan_name, #2 todolist case, #3 baton-plan**
批注 #1-#3 与 Round 2 处理的内容相同（可能是编辑时序交叉导致）。文档本体已在 Round 2 中更新：
- #1: Change 1.3（L110-112）已包含 `resolve_plan_name()` 修复
- #2: Change 1.2（L104）已包含 `Todolist` → `todolist` 文案修正
- #3: Change 3.2（L136-137）已标记移除，Skip Justification 已新增条目
→ Result: already addressed in Round 2

**[inferred: scope-question] § #4 plan-*.md 回归测试**
“如果这轮要真正修 JSON_CWD，是否会补一组 plan-*.md 场景的回归测试，而不只是 skill walk-up？”
→ 确认：已覆盖。Change 5.5 Test B（L218-223）专门验证此场景：在临时目录创建 `plan-feature.md`（非默认名），设置 `JSON_CWD` 指向该目录，从另一个不含 plan 的目录执行 phase-guide.sh，断言输出包含 `ANNOTATION` 而非 fallback 到 `RESEARCH`。这直接复现了人类描述的”从项目外执行、只设置 JSON_CWD 时 phase 掉回 RESEARCH”场景。
→ Result: already addressed in Round 2

### Round 4

**[inferred: duplicate — already addressed in Round 2] § #1 resolve_plan_name, #2 todolist case**
批注 #1 和 #2 引用的行号对应 Round 2 编辑前的旧版本。当前文档本体已包含这些修复：
- #1 resolve_plan_name: **Change 1.3（当前 L110-112）** 已包含修复 + **Change 5.5 Test B（当前 L218-223）** 已包含 plan-*.md 场景的回归测试
- #2 todolist 大小写: **Change 1.2（当前 L104）** 已包含 `Todolist` → `todolist` fallback 文案修正
→ Result: already addressed in Round 2. 建议在 IDE 中刷新 plan-decoupling.md 确认当前内容。

**[inferred: gap-medium] § #3 Token budget 约束不可执行**
“token 预算约束已经不是一个可验证的约束了...wc -w .baton/workflow.md 当前文件是 1,079 个英文单词...~400 tokens 基线过时”
→ 验证：✅ 正确。[RUNTIME] `wc -w .baton/workflow.md` = 1,079 words / 7,320 bytes。”~400 tokens” 基线与实际差距约 3 倍（按 ~1.3 tokens/word 估算，实际约 ~1,400 tokens）。该数字可能来源于 research-decoupling-approaches.md 引用的 workflow-full.md:117，但 workflow.md 在多轮迭代后已大幅扩展。加 ~20 words 的 Document Authority 对 1,079 words 的文件无实质影响——约束本身无意义。
→ Consequence: Fundamental Constraint #4 已标记删除线并附注实际测量值。约束从”token budget <450”改为”Document Authority 新增 ~20 words，对当前文件无实质影响”。
→ Result: accepted

### Round 5

**[inferred: gap-critical] § #1 write-lock.sh 回归测试缺失**
“共享函数修复现在只在 phase-guide.sh 上补回归，遗漏了真正高风险的 write-lock 路径...write-lock.sh 是从 stdin JSON 解析 cwd 的...现有 test-write-lock.sh:287 只测了 JSON cwd + plan.md，并没有测 JSON cwd + plan-*.md”
→ 验证：✅ 正确。[CODE] `test-write-lock.sh:289` 创建 `plan.md`（默认名），不覆盖 `plan-*.md` 场景。`resolve_plan_name()` 修复后在 JSON_CWD 目录下 glob，但 write-lock.sh 这条硬门（唯一的阻断型 hook）的测试不验证此路径。
→ Consequence: 新增 Change 5.6（test-write-lock.sh 新增 JSON cwd + plan-*.md 回归测试）。Surface Scan L2 新增 test-write-lock.sh 条目。
→ Result: accepted

**[inferred: internal-inconsistency] § #2 高层理由链/风险表与 Change List 脱节**
“Approach A 的 mitigation 还只写了 has_skill()...推荐理由链也只提 has_skill()...风险表同样只提 has_skill()...但 Change 1.3 和 Self-Review 已经把 resolve_plan_name() 一并纳入”
→ 验证：✅ 正确。三处已过时：Approach A Mitigation（L31）、Recommendation 理由链（L52）、Risk table（L240）均只提 `has_skill()`，但 Change 1.3 和 Self-Review 已包含 `resolve_plan_name()` 修复。这是 Iron Law #4（无内部矛盾）的违反。
→ Consequence: 三处已同步更新为 `has_skill()` + `resolve_plan_name()`。
→ Result: accepted

### Round 6

**[inferred: gap-medium] § #1 test-setup.sh 缺负向断言**
“只删除 assert_file_exists...没有补一个 fresh install 不应再生成该文件的负向断言”
→ 验证：✅ 正确。[CODE] `test-setup.sh:40-49` 只有 `assert_file_exists` 正向 helper，无对称的 `assert_file_not_exists`。删除正向断言后，若 setup.sh 残留或重新引入 workflow-full.md 创建逻辑，测试不会报警。
→ Consequence: Change 5.3 新增负向断言 + helper 函数。
→ Result: accepted

**[inferred: internal-inconsistency] § #2 Requirements 与正文脱节**
“plan-decoupling.md:8 还只写了 3 个目标 IDE...plan-decoupling.md:11 仍把路径 bug 写成仅 has_skill()”
→ 验证：✅ 正确。[CODE] `README.md:137-140` 列出 4 个宿主（含 Factory AI）。Requirement #4 只提 `has_skill()` 但 Change 1.3 已包含 `resolve_plan_name()` 修复。Iron Law #4 违反。
→ Consequence: Requirement #1 新增 Factory AI；Requirement #4 更新为 `has_skill()` + `resolve_plan_name()`。
→ Result: accepted

**[inferred: stale-metadata] § #3 Impact 计数 + External Risks 缓解过时**
“13 个文件修改 + 1 个文件删除 但当前 Surface Scan 实际是 12 改 1 删...外部风险缓解仍只提 test-phase-guide.sh”
→ 验证：✅ 正确。Surface Scan 实际：L1 modify 6 + L2 modify 5 + L2 fork 1 = 12 modify + 1 delete。External Risks 只提 test-phase-guide.sh 但 Change 5.6 已加入 test-write-lock.sh。
→ Consequence: Impact 更新为 12+1；External Risks mitigation 新增 test-write-lock.sh。
→ Result: accepted

### Round 7

**[inferred: gap-critical] § #1 resolve_plan_name walk-up 缺陷**
“resolve_plan_name() 修法本身不够...只看起始目录，不会向上找父目录里的 plan-feature.md...问题不只是 JSON_CWD，而是'候选名发现没有随 walk-up 一起工作'”
→ 验证：✅ 正确。[RUNTIME] 实测确认：`cd project/src/deep && ls -t plan.md plan-*.md` 在子目录无结果 → 默认 `plan.md` → `find_plan()` walk-up 找不到 `plan-feature.md`。即使修复 JSON_CWD，子目录场景仍然失败。问题根因是名称解析和路径搜索的分离设计。
→ Consequence: Change 1.3 重写为 `find_plan()` 重构方案——在逐级 walk-up 时同时做名称发现（每级目录 glob `plan.md`/`plan-*.md`），消除两步分离的设计缺陷。`resolve_plan_name()` 保留为 BATON_PLAN shim。
→ Result: accepted

**[inferred: gap-medium] § #2 bin/baton status() 独立 plan 发现**
“bin/baton:128-145 的 status() 复制了同样的 plan.md / plan-*.md 发现逻辑...hook 说一个 phase，baton status 说另一个 phase”
→ 验证：✅ 正确。[CODE] `bin/baton:136` 使用 `ls -t “$_dir”/plan.md “$_dir”/plan-*.md`——与 `_common.sh` 相同的单目录 glob 缺陷。CLI 不 source `_common.sh`，需独立修复。[CODE] `test-cli.sh:135-145` 只测 `plan.md`。
→ Consequence: Surface Scan 新增 bin/baton + test-cli.sh。Change List 新增 Group 4b（CLI plan 发现同步 + 回归测试）。Impact 更新为 14+1。
→ Result: accepted

**[inferred: duplicate — already addressed in Round 6] § #3 Requirements 同步**
批注 #3 引用的行号对应 Round 6 编辑前的旧版本。当前 L8 已包含 Factory AI（4 个 IDE），L11 已扩展为 `find_plan()` 重构 + `has_skill()` + `bin/baton`。
→ Result: already addressed

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI “generate todolist” -->
1. 高: 这份计划现在仍然没有覆盖 research-*.md 的 walk-up / 名称发现，所以“phase 发现可靠性已修复”的表述过宽。计划只修 plan 路径，plan-decoupling.md:11 和 plan-decoupling.md:113 到 plan-decoupling.md:145 都围绕 find_plan() / status() 展开；但当前 phase-guide.sh 仍然是在 find_plan() 之后只检查当前 pwd 或 plan 所在
   目录里的 RESEARCH_NAME，phase-guide.sh:24 到 phase-guide.sh:32，bin/baton 也只看 $_dir/$_rname，bin/baton:140 到 bin/baton:146。我复现了“父目录只有 research-feature.md、从子目录进入”的场景，phase-guide.sh 和 baton status 都仍然落回 RESEARCH。所以 plan-decoupling.md:52 和 plan-decoupling.md:295 里“提高 plan/
   phase 发现可靠性”的结论还不成立，除非把 research 侧一起修，或者把 scope 明确缩成“仅 plan 文件发现”。
2. 中: CLI 回归测试设计现在抓不到它自己要防的 bug。plan-decoupling.md:186 到 plan-decoupling.md:189 写的是创建 plan-feature.md 后运行 baton status "$d"。但当前实现里，项目根目录本来就能通过；真正出错的是从子目录调用时，bin/baton:136 到 bin/baton:146 只在传入目录下找 plan/research。我复现了同一个仓库：status
   <project-root> 返回 IMPLEMENT，status <project-root/src/deep> 返回 RESEARCH。所以 4b.2 如果不改成子目录路径，就是一个会绿但没有覆盖缺陷的测试。
3. 中: phase-guide 的 Test B 也还停在旧问题定义上，没有验证这次新增的“walk-up + 名称发现合并”合同。plan-decoupling.md:264 到 plan-decoupling.md:269 只是把 JSON_CWD 设到含 plan-feature.md 的目录本身，再从外部执行；这只能证明“root JSON_CWD 生效”，证明不了 plan-decoupling.md:113 到 plan-decoupling.md:145 新引入的“从
   子目录 walk-up 过程中发现 plan-*.md”。当前真正覆盖子目录场景的只有 write-lock 用例，plan-decoupling.md:271 到 plan-decoupling.md:278。因此 plan-decoupling.md:310 到 plan-decoupling.md:311 的“覆盖完整”判断还过早。

4. 这轮 Requirement 4 到底要修“所有 phase 文件发现”，还是只修“plan 文件发现”？如果是前者，计划里应该补一个 research 侧的 walk-up 方案和回归测试；如果不是，顶层措辞需要收窄。
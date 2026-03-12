# Plan: Baton 解耦 — 废除 workflow-full.md

**复杂度**: Large
**前置研究**: `research-decoupling-approaches.md`

## Requirements

1. [RESEARCH] 废除 `workflow-full.md`（方案 C），因为所有目标 IDE（Claude Code、Factory AI、Codex、Cursor）都支持 skills，`workflow-full.md` 的运行时消费路径永远不会触发。[RESEARCH] `research-decoupling-approaches.md` § Direction Reassessment After Round 2。[CODE] `README.md:158-161` 列出四个宿主。
2. [RESEARCH] 把 `Document Authority` 元信息从 `workflow-full.md` 上移到 `workflow.md`。[RESEARCH] § Annotation Log Round 1 Q2
3. [HUMAN] `.agents/` 保持通用 fallback 定位。[HUMAN] research 批注区 Round 1 Q3
4. [RESEARCH] 修复 **plan 文件**发现的 pwd vs JSON_CWD 不一致 + walk-up 缺陷：`find_plan()` 重构（合并名称发现到 walk-up 中）、`has_skill()` JSON_CWD 修复、`bin/baton:status()` 同步修复。Scope 仅限 plan 文件；research 文件发现在 plan 存在时间接受益，独立 research-only 子目录场景不在本轮范围。[RESEARCH] § Direction Reassessment — 已知风险 + plan 批注 Round 2/7/8
5. [RESEARCH] Fork context 修复（独立子目标，pre-existing gap，非 workflow-full.md 废除引入）：在 fork-context SKILL.md 中内联 annotation rules，使其在 subagent 下自足。[RESEARCH] § Annotation Log Round 1 Q4。（Round 18 批注 #3 标注：与 workflow-full.md 废除并行，可独立拆出）

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
- **Impact**: 17 个文件修改 + 1 个文件删除（Round 16 新增 docs/stable-surface.md）
- **Mitigation**: 修复 `has_skill()` + `find_plan()` 的 pwd vs JSON_CWD 不一致 bug，提高 skill 发现和 plan 文件发现可靠性（scope: plan 文件发现；research 文件发现在 plan 存在时间接受益）；hardcoded fallback 保留作为最后 safety net

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
- 所有目标 IDE 支持 skills [HUMAN] → `phase-guide.sh` skill-present 分支跳过 `workflow-full.md` [CODE] `phase-guide.sh:68-133` → 文件无运行时消费者 → 废除是最简方案 [RESEARCH] → hardcoded fallback 保留作为 safety net [CODE] `phase-guide.sh:73-77,90-94,109-113,127-132` → 同时修复 `has_skill()` + `find_plan()` 的 pwd vs JSON_CWD 不一致 bug，提高 skill 发现和 plan 文件发现可靠性（research 文件发现在 plan 存在时间接受益，但独立 research-only 场景不在本轮范围）[CODE] `_common.sh:10,32`

## Surface Scan

### L1 — 直接引用 `workflow-full` / `extract_section` / `WORKFLOW_FULL`

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow-full.md` | L1 | **delete** | 被废除的文件本身 |
| `.baton/hooks/phase-guide.sh` | L1 | modify | 删除 `WORKFLOW_FULL=`、4 个 `extract_section` 调用；保留 hardcoded fallback |
| `.baton/hooks/_common.sh` | L1 | modify | **主变更**：`find_plan()`/`resolve_plan_name()` 重构——合并名称发现到逐级 walk-up 中（30+ 行新代码，影响所有 8 个 hook 的 plan 发现行为）。附带：删除 `extract_section()` 函数（22 行）；修复 `has_skill()` JSON_CWD（1 行，预防性）。（Round 18 批注 #1 修正：从仅列附带项升级为主变更前置） |
| `setup.sh` | L1 | modify | 删除 `cp workflow-full.md` 安装步骤（:1216-1219）；可选保留旧引用迁移代码（:949-953, :1047-1050） |
| `tests/test-workflow-consistency.sh` | L1 | modify | 删除 ~8 个 FULL-dependent 检查块；修改 ~8 个检查块移除 FULL 引用；更新 Document Authority 守卫注释 |
| `tests/test-annotation-protocol.sh` | L1 | modify | 删除所有 `$FULL` 引用的断言（~12 行）；保留 `$SLIM` 独立断言 |
| `tests/test-setup.sh` | L1 | modify | 删除 `assert_file_exists workflow-full.md`（:130） |

### L2 — 间接依赖

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L2 | modify | 新增 Document Authority 段落（~5 行）；更新 Enforcement Boundaries fallback 描述 |
| `tests/test-phase-guide.sh` | L2 | **modify** | 不直接引用 workflow-full.md，但 no-skill 场景的测试断言期待 `extract_section` 输出（来自 workflow-full.md），而非 hardcoded fallback。删除 extract_section 后，8 个断言会失败（见 Change List 5.4）。 |
| `README.md` | L2 | modify | 删除目录树中 workflow-full.md 条目（:140）；更新架构描述（:48, :49, :192 的 ~400 tokens / extraction 说法） |
| `docs/implementation-design.md` | L2 | modify | 受测试约束的活跃文档（`test-workflow-consistency.sh:11` 引用）。重写三层架构叙述，删除 workflow-full.md 相关段落（:17, :21, :60, :97, :293, :319-334）。（Round 16 批注 #3 修正：从"纯文档"升级为"受测试约束"） |
| `docs/stable-surface.md` | L2 | modify | 含 "Without phase-specific skill discipline" 同一措辞（:39），与 Change 2.1 修改的 workflow.md Enforcement Boundaries 同源。不更新会导致协议面措辞漂移。无测试约束。（Round 16 批注 #2 新增） |
| `tests/test-write-lock.sh` | L2 | **modify** | 现有 Test 16 只覆盖 JSON cwd + `plan.md`；需新增 JSON cwd + `plan-*.md` 回归测试以覆盖 `resolve_plan_name()` 修复在写锁硬门上的效果。（Round 4 批注 #1 新增） |
| `bin/baton` | L2 | **modify** | `status()` 函数（L128-145）有独立的 plan 发现逻辑，不使用 `_common.sh`，存在同样的 plan-*.md walk-up 缺陷。（Round 7 批注 #2 新增） |
| `tests/test-cli.sh` | L2 | **modify** | 现有 status 测试（L135-145）只覆盖 `plan.md`，需新增 `plan-*.md` 场景。（Round 7 批注 #2 新增） |
| `tests/test-stop-guard.sh` | L2 | **modify** | 现有 Test 7（L161-168）walk-up 测试只覆盖 `plan.md`，需新增 `plan-*.md` 子目录场景。（Round 9 批注 #1 新增） |
| `tests/test-new-hooks.sh` | L2 | **modify** | completion-check 测试（L123-131）只覆盖 `plan.md`，需新增 `plan-*.md` 子目录场景。（Round 9 批注 #1 新增） |

### L2 — Fork context（SKILL.md 修复）

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.claude/skills/baton-research/SKILL.md` | L2 | modify | 内联必要的 cross-cutting annotation rules（~10 行），使 fork context 自足 |
| `.claude/skills/baton-plan/SKILL.md` | L2 | **skip** | 不声明 `context: fork`（无 frontmatter `context:` 行），不在 subagent 中运行。（Round 2 批注 #3 修正） |

### Skip Justification

| File | Disposition | 如果不更新，用户会遇到什么？ |
|------|-------------|----------------------------|
| `setup.sh:949-953, :1047-1050` | keep + test（迁移代码） | 删除 workflow-full.md 后，这些迁移分支从"可选兼容"升级为"关键兼容边界"——旧项目的 CLAUDE.md/AGENTS.md 含 `@.baton/workflow-full.md`，迁移代码将其替换为 `@.baton/workflow.md`。保留代码不变，新增回归测试。（Round 12 批注 #2 从 skip 升级为 keep + test） |
| `.claude/skills/baton-plan/SKILL.md` | skip | 无影响。不声明 `context: fork`，不在 subagent 中运行，不需要内联 annotation rules。（Round 2 批注 #3 修正：从 modify 降级为 skip） |
| `.claude/skills/baton-implement/SKILL.md` | skip | 无影响。该 skill 不标记 `context: fork`，不在 subagent 中运行，不需要内联 annotation rules。 |

## Change List

### Group 1: Core — 废除 workflow-full.md 运行时路径

**1.1 删除 `.baton/workflow-full.md`**
- 删除文件。
- 存档到 `plans/` 供历史参考（可选）。

**1.2 简化 `.baton/hooks/phase-guide.sh`**
- **版本升级**：`# Version: 5.0` → `# Version: 6.0`。必须升版，否则 `setup.sh:install_versioned_script()` 的版本比较（L659）会判定 "is up to date" 跳过覆盖，导致已安装项目拿不到修复。[CODE] `setup.sh:637-662` 按 `# Version:` 字符串比较。（Round 11 批注 #1 新增）
- 删除 L6 注释中 "workflow-full.md" 引用
- 删除 L20 `WORKFLOW_FULL=` 赋值
- 4 个状态分支（IMPLEMENT/ANNOTATION/PLAN/RESEARCH）：删除 `extract_section ... >&2 ||` 调用，直接输出 hardcoded fallback。else 分支从 `extract_section ... || cat <<'EOF'` 简化为 `cat <<'EOF'`
- 修正 PLAN fallback 文案大小写：`Todolist` → `todolist`（L112），使与 `test-phase-guide.sh:84` 的 `grep -q "todolist"` 断言一致。[CODE] `phase-guide.sh:112` 当前为 `Todolist generated only after human says so.`，grep 大小写敏感。（Round 2 批注 #2 修正）
- 保留 hardcoded fallback 其余文本不变（它们是 safety net）

**1.3 清理 `.baton/hooks/_common.sh`**
- 删除 `extract_section()` 函数（L44-65，含注释共 22 行）。无其他调用者。[CODE] Surface scan 确认 `phase-guide.sh` 是唯一生产调用者；`test-workflow-consistency.sh:14-16` 有同名但独立的本地定义。
- 修复 `has_skill()` L32：`_hs_d="$(pwd)"` → `_hs_d="${JSON_CWD:-$(pwd)}"` — 预防性修复，与 `find_plan()` 保持一致。当前无生产消费者（仅 write-lock.sh 设置 JSON_CWD，但不调用 has_skill()）。（Round 10 批注 #3 标注）
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

### Group 3: Fork Context 自足（独立子目标——opportunistic，非 workflow-full.md 废除的机械必需项）

**3.1 更新 `.claude/skills/baton-research/SKILL.md`**
- **主变更**：改写 L217-218 依赖句（"Cross-cutting annotation rules (analysis write-back, approach re-evaluation, annotation cleanup) live in `workflow.md` Annotation Protocol and apply here too."）。当前措辞把三条 cross-cutting rules 的权威完全委托给 workflow.md，fork context 下无法访问 → 变成空引用。
- 改写方式：将三条 cross-cutting rules 内联展开（~5-8 行），替换当前的一句式委托。具体内联：
  - analysis write-back：When feedback triggers new analysis, write conclusions back to document body immediately
  - approach re-evaluation：When new analysis changes or weakens current approach, re-evaluate and update immediately
  - annotation cleanup：After annotation is processed into Annotation Log entry, remove raw text from 批注区
- **不重复**：L220-230 的 Processing Each Annotation 段落（Read code first / Infer intent / Consequence detection / Annotation Log）**已存在且自足**，不需要重复。本变更只补 L217-218 委托的三条 rules。（Round 19 批注 #1+#2 修正：从"加 ~10 行摘要"缩窄为"改写 1 处依赖句 + 内联 3 条 rules"）
- 保留 workflow.md 引用作为 "full details" 指向（`See workflow.md Annotation Protocol for comprehensive rules`），但 fork context 的核心行为不再依赖它
- **验证**：实施后 SKILL.md 应满足：(1) 不含 "live in `workflow.md`" 委托句；(2) 三条 cross-cutting rules 有内联表述。Change 5.2 的 RESEARCH_SKILL 断言（infers intent / [PAUSE] 等）验证的是 annotation protocol 迁移，不验证 Group 3 的自足性——Group 3 的验证靠上述两点。

**3.2 ~~更新 `.claude/skills/baton-plan/SKILL.md`~~** — 已移除
- baton-plan/SKILL.md 不声明 `context: fork`，不在 subagent 中运行，无需内联。（Round 2 批注 #3 修正）

### Group 4: 安装与分发

**4.1 更新 `setup.sh`**
- 删除 L1210：`echo "  ✓ workflow-full.md (self-install, skipping copy)"` — 文件已不存在，self-install 状态输出会误导
- 删除 L1216-1219（`cp workflow-full.md` 安装步骤 + 注释）
- 保留 L949-953 和 L1047-1050 的旧引用迁移代码（向后兼容已安装项目）

### Group 4b: CLI plan 发现同步（Round 7 批注 #2 新增）

**4b.1 更新 `bin/baton`**
- `status()` 函数（L128-146）有独立的 plan 发现逻辑，不使用 `_common.sh`。需要同步修复使其在子目录中也能发现父目录的 plan 文件。
- **为什么不复用 `_common.sh`**：`_common.sh` 位于 `.baton/hooks/_common.sh`，相对于项目根。`bin/baton` 是全局 CLI（`~/.baton/bin/baton`），接收任意目录参数（`baton status /path/to/project`）。要 source `_common.sh`，需要先找到项目根——而找项目根正是 `find_plan()` walk-up 在做的事。Chicken-and-egg：走完 walk-up 之后才能定位 `_common.sh`，但此时 plan 已经找到了，不再需要 `_common.sh`。两套实现的 drift 风险已知（见 Round 22 批注 #2），但在不引入额外复杂度（如要求 `.baton/` 目录作为第二锚点）的前提下，本地维护等价逻辑是当前最简方案。（Round 22 批注 #2 新增）
- 修改 L132-146 的 plan file 发现 + 存在性检查逻辑：walk-up 必须同时产出 plan 文件名（`_pname`）和 plan 所在目录（`_pdir`），后续 `_plan`/`_research` 存在性检查用 `_pdir` 而非原始 `$_dir`。当前 L144 `[ -f "$_dir/$_pname" ]` 中 `$_dir` 是传入参数（如 `src/deep`），walk-up 找到的 plan 在父目录——仅修名称发现不够，存在性检查仍会失败。（Round 15 批注 #1 修正：从"只改名称发现"改为"名称+目录一起带出"）
  - 隐式路径（无 BATON_PLAN）：逐级向上 glob `plan.md plan-*.md`，命中时设 `_pname` + `_pdir`。（与 `_common.sh:find_plan()` else 分支 L131-142 等价）
  - BATON_PLAN 分支：逐级向上查找 `$BATON_PLAN`，命中时设 `_pname` + `_pdir`。（与 `_common.sh:find_plan()` BATON_PLAN 分支 L123-130 等价）
  - `_rname="${_pname/plan/research}"` 移到 walk-up 之后。`_plan="$_pdir/$_pname"`，`_research`检查用 `[ -f "$_pdir/$_rname" ]`。
  - 未命中（walk-up 到根仍无 plan）：`_pdir="$_dir"`（保持原行为），`_pname="plan.md"`。
- `doctor()` 函数规则注入检查修复：
  - L99：收紧 CLAUDE.md 正则——`'@\.baton/workflow(-full)?\.md'` → `'@\.baton/workflow\.md'`。删除 workflow-full.md 后，旧 import 应被标记为需要迁移而非视为健康。[CODE] `bin/baton:99`。（Round 12 批注 #1 新增）
  - 新增 AGENTS.md 规则注入检查（当前缺失）：在 L105 之后新增 `if [ -f "$_dir/AGENTS.md" ]` 块，检查 `grep -q '@\.baton/workflow\.md' "$_dir/AGENTS.md"`。当前 doctor 只检查 CLAUDE.md 的 @import，不检查 AGENTS.md。[CODE] `bin/baton:93` 的 `_check_ide_config` 只检查 "baton"（IDE config），不检查 @import 规则注入。（Round 13 批注 #1 新增）

**4b.2 新增 `tests/test-cli.sh` plan-*.md 子目录回归测试 + doctor 规则注入回归**
- 在现有 Test 8（L135-145，`plan.md` + GO → IMPLEMENT）附近新增一个测试：
- 在临时目录根创建 `plan-feature.md`（非默认名，含 GO + Todo）+ `research-feature.md` + `mkdir -p src/deep`
- 运行 `baton status "$d/src/deep"` 断言：
  - 输出包含 `IMPLEMENT`（而非 fallback 到 `RESEARCH`）
  - 输出包含 `plan-feature.md`（Plan: 行正确显示发现的 plan 文件名）
  - 输出包含 `research-feature.md`（Research: 行正确显示对应 research 文件名）
  - 输出包含 `exists`（research 文件被找到而非 `not found`）
- [CODE] `bin/baton:179-181` status() 打印 `Plan: $_pname ($_plan_status)` 和 `Research: $_rname ($_research_status)`。在子目录调用时，修复前 `$_pname` 会 fallback 到 `plan.md` 而非发现 `plan-feature.md`，导致 Plan/Research 行显示错误文件名。（Round 13 批注 #2 新增）
- 子目录路径是关键：`baton status "$d"` 在根目录本就能通过（`ls -t` 在 `$_dir` 下找到 plan-feature.md），真正缺陷是从子目录调用时 `bin/baton:136` 只在传入目录下 glob。（Round 8 批注 #2 修正）
- 新增 BATON_PLAN 子目录回归测试：在临时目录根创建 `plan-custom.md`（含 GO + Todo）+ `research-custom.md`，运行 `BATON_PLAN=plan-custom.md baton status "$d/src/deep"`，断言输出包含 `IMPLEMENT`、`plan-custom.md`、`research-custom.md`。使用 `plan-custom.md` 而非 `custom.md`——避免锁定 `${name/plan/research}` 对不含 "plan" 文件名的退化行为（`custom.md` → research 派生同名，是 pre-existing 命名合同问题，不在本轮范围）。（Round 14 批注 #1 新增 + Round 17 批注 #1 修正：fixture 改名）
- 新增 doctor 规则注入回归测试（CLAUDE.md + AGENTS.md 双路径）：
  - CLAUDE.md 旧 import：创建 CLAUDE.md 含 `@.baton/workflow-full.md`，运行 `baton doctor`，断言输出包含 `issue` 或 `⚠`（不再视为健康）。再创建含 `@.baton/workflow.md`（正确 import），断言 `all checks passed`。（Round 12 批注 #1 新增）
  - AGENTS.md 旧 import：创建 AGENTS.md 含 `@.baton/workflow-full.md`，运行 `baton doctor`，断言输出包含 `issue` 或 `⚠`。再创建含 `@.baton/workflow.md`（正确 import），断言 Rules injection 段**不含** `⚠`（不断言 `all checks passed`——Codex IDE config 假阳性是已知 pre-existing bug，全局 "all checks passed" 会把假阳性锁成金标准）。（Round 14 批注 #2 新增 + Round 17 批注 #2 修正：收窄断言范围）

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
- L52：legacy markers absent from FULL
- L72, L74：core principles in FULL（workflow.md 已有独立覆盖 L71, L73）

MIGRATE to skill files（而非简单删除，保留 annotation protocol 的 detailed coverage）：
- L42-44（intent inference, free-text default, consequence detection in FULL）→ 双侧迁移：
  - baton-plan：`check "$PLAN_SKILL" "infers intent" / "free-text" / "Consequence detection"`。[CODE] baton-plan/SKILL.md:212 "infers intent", L207 "free-text", L225 "Consequence detection"。（Round 14 批注 #4 修正："Free-text" → "free-text"，SKILL.md 实际为小写）
  - baton-research：`check "$RESEARCH_SKILL" "infers intent" / "free-text" / "Consequence detection"`。[CODE] baton-research/SKILL.md:212 "infers intent", L211-212 "free-text", L226 "Consequence detection"。（Round 14 批注 #3 新增）
- L57-65（Annotation Log, Round 1, Annotation Format, Core Principles, [PAUSE] Handling, Correct/Incorrect behavior in FULL）→ 双侧迁移 + coverage loss：
  - baton-plan：`check "$PLAN_SKILL" "Annotation Log" / "Round 1" / "Annotation Log Format" / "[PAUSE]"`。[CODE] baton-plan/SKILL.md:253 "## Annotation Log", L255 "### Round 1", L248 "Annotation Log Format", L210 "[PAUSE]"。
  - baton-research：`check "$RESEARCH_SKILL" "Annotation Log" / "[PAUSE]"`。[CODE] baton-research/SKILL.md:224/230 "Annotation Log", L214 "[PAUSE]"。注意：baton-research 无 "Annotation Log Format" 和 "Round 1" 模板（仅 baton-plan 有详细格式），不迁移。
  - "Core Principles" / "[PAUSE] Handling" 5-step process / "Correct behavior:" / "Incorrect behavior:" → coverage loss（见下方）。（Round 13 批注 #4 + Round 14 批注 #3 修正）
- L86-90（Approach Analysis, fundamental constraints, Fundamental Problems in FULL）→ 改挂 baton-plan/SKILL.md：`check "$PLAN_SKILL" "Approach Analysis" / "fundamental constraints" / "Fundamental Problems"`。[CODE] baton-plan/SKILL.md:76, L67, L147。（仅 plan 侧——research skill 不含这些规划概念）
- 新增 `PLAN_SKILL=` 和 `RESEARCH_SKILL=` 变量声明，分别指向 `.claude/skills/baton-plan/SKILL.md` 和 `.claude/skills/baton-research/SKILL.md`。（Round 14 批注 #3 新增）

Group 3 自足性守卫（与 annotation protocol 迁移分离）：
- `check_not "$RESEARCH_SKILL" "live in .workflow\.md."` — 验证 L217-218 委托句已改写（当前文本含 "live in `workflow.md`"，改写后不应出现）。
- `check "$RESEARCH_SKILL" "document body"` — 验证 analysis write-back rule 已内联（当前 SKILL.md 不含 "document body"，改写后应包含）。
- 如果 `check_not` helper 不存在，先添加（与 Change 5.3 的 `assert_file_not_exists` 模式对称——取反 grep 返回值）。
- （Round 20 批注 #1 新增：从纯人工验收改为回归测试守卫）

KEEP：所有 `$SLIM` 断言不变。

Coverage loss（无法迁移的断言）：
- "Core Principles" — workflow-full.md:322 的 section heading "#### Core Principles for AI Responses"，SKILL.md 中 "Processing Each Annotation"（L217）承载等价功能但无此标题字符串。（Round 13 批注 #4 新增）
- "[PAUSE] Handling" 5-step process — workflow-full.md:356-361 的独立处理流程（暂停→研究→追加→回溯→记录），SKILL.md:210 提及 [PAUSE] 概念（已迁移为 `check "[PAUSE]"`），但无独立 "[PAUSE] Handling" 标题和 5 步流程。SKILL.md § Processing Each Annotation 仅在流程说明中提及 [PAUSE]，以不同结构呈现。（Round 13 批注 #4 新增）
- "Correct behavior:" / "Incorrect behavior:" — workflow-full.md 特有的示例对，skills 中 Red Flags 表承载类似功能但格式不同。（Round 12 批注 #3 新增）

**5.3 更新 `tests/test-setup.sh`**
- 删除 L130：`assert_file_exists "$d/.baton/workflow-full.md"`
- 新增负向断言：`assert_file_not_exists "$d/.baton/workflow-full.md"`（fresh install 后该文件不应存在）。如果 `assert_file_not_exists` helper 不存在，先添加（与现有 `assert_file_exists` 对称）。（Round 6 批注 #1 新增）
- 新增 phase-guide.sh 版本升级回归测试：在现有 Test 13（L466-477，write-lock.sh v0.1 → v3.0）之后新增一个测试——创建旧版 phase-guide.sh（`# Version: 5.0`），运行 setup.sh，断言输出包含版本升级消息（`v5.0`）且目标文件包含 `Version: 6.0`。模式与 Test 13 对称。[CODE] `test-setup.sh:466-477` 现有 write-lock.sh 升级测试。（Round 11 批注 #1 新增）
- 新增 workflow-full.md import 迁移回归测试：创建项目目录，写入 CLAUDE.md 含 `@.baton/workflow-full.md`，运行 setup.sh，断言：(a) CLAUDE.md 现在包含 `@.baton/workflow.md`（不再含 `-full`）；(b) 输出包含 `Migrated` 消息。再测 AGENTS.md 同理。[CODE] `setup.sh:949-953` (CLAUDE.md 迁移), `setup.sh:1047-1050` (AGENTS.md 迁移)。（Round 12 批注 #2 新增）

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

附带修复（同文件，与 policy 一致）：
- Test 7（L157-172）：将 `custom.md` fixture 改为 `plan-custom.md`，`BATON_PLAN=plan-custom.md`。避免锁定 `${name/plan/research}` 对不含 "plan" 文件名的退化行为，与 Change 4b.2 CLI test policy 一致。（Round 21 批注 #1 新增）

保留的断言（在 hardcoded fallback 中存在，不受影响）：
- Test 1: "implementations", "file:line", "entry points", "subagent", "批注区", "Spike" ✅
- Test 2: "approach", "constraints", "批注区", "todolist" ✅
- Test 3: `\[PAUSE\]`, "Free-text is the default", "file:line", "BATON:GO" ✅
- Test 4: "3x", "BATON:GO" ✅

**5.5 新增 `tests/test-phase-guide.sh` plan-*.md walk-up 回归测试**（Round 1 补充建议 + Round 10 批注 #3 重设计）

在现有 Test 16（walk-up 测试，L273-279）之后新增一个测试：

~~Test A: has_skill via JSON_CWD~~ — 已移除。has_skill() 从 shell cwd walk-up 已被 Test 16 覆盖。has_skill() 的 `${JSON_CWD:-$(pwd)}` 修复是预防性的（无当前生产消费者——仅 write-lock.sh 设置 JSON_CWD，但不调用 has_skill()），不需要独立回归测试。（Round 10 批注 #3 修正）

**Test B: find_plan() 子目录 shell cwd walk-up 发现 plan-*.md**（Round 2 → Round 8 → Round 10 重设计）
- 在临时目录根创建 `plan-feature.md`（非默认名）+ `mkdir -p src/deep`
- **cd 到子目录** `<tmp>/src/deep`，直接执行 phase-guide.sh（**不设置 JSON_CWD**）
- 断言输出包含 `ANNOTATION`（fixture 为 plan-feature.md 无 GO 无 research → 状态机 [CODE] `phase-guide.sh:83` 必然落到 ANNOTATION）
- 断言输出**不包含** `RESEARCH`（排除 walk-up 失败导致的 fallback）
- 验证 `find_plan()` 从 shell cwd（子目录）向上遍历时，在每一级做名称发现（glob `plan-*.md`）。
- **设计理由**：生产环境中 SessionStart hooks 由 host IDE 从项目根执行 [CODE] `setup.sh:842`，无 JSON_CWD 注入。Shell cwd 子目录测试是防御性的，但比原 JSON_CWD 方案更贴近可能的边界情况。JSON_CWD + find_plan() 的真实场景由 write-lock.sh 测试覆盖（Change 5.6）。（Round 9 批注 #2 收紧断言 + Round 10 批注 #3 去 JSON_CWD）

**5.6 新增 `tests/test-write-lock.sh` JSON_CWD + plan-*.md 回归测试**（Round 4 批注 #1 新增）

在现有 Test 16（L287-299，JSON cwd + plan.md）之后新增一个测试：
- 在临时目录下创建 `plan-feature.md`（非默认名，含 `<!-- BATON:GO -->` + `## Todo`）
- 构造 stdin JSON：`{"tool_input":{"file_path":"src/app.ts"},"cwd":"<tmp>/project/src"}`
- 从项目外目录（`$tmp`）执行 write-lock.sh
- 断言：允许写入（exit 0）——因为 `find_plan()` 从 `JSON_CWD`（子目录 `src`）向上 walk-up 时在父目录发现 `plan-feature.md`（含 GO 标记）
- 这覆盖了 write-lock.sh 作为硬门的真实输入路径（stdin JSON → JSON_CWD → find_plan walk-up），验证修复在最关键的 hook 上生效。[CODE] `write-lock.sh:30-43` 解析 JSON_CWD，`test-write-lock.sh:287-299` 现有测试只覆盖 `plan.md`。

**5.7 新增 `tests/test-stop-guard.sh` plan-*.md 子目录回归测试**（Round 9 批注 #1 新增）

在现有 Test 7（L161-168，walk-up with `plan.md`）之后新增一个测试：
- 在临时目录根创建 `plan-feature.md`（非默认名，含 `<!-- BATON:GO -->` + 1 个未完成 todo）+ `mkdir -p src/deep`
- 从子目录 `$d/src/deep` 执行 stop-guard.sh
- 断言输出包含 `remaining`（找到 plan-feature.md 并检测到未完成 todo）
- 验证 `find_plan()` walk-up 在 stop-guard.sh 路径上生效。[CODE] `stop-guard.sh:22-23` 调用 `resolve_plan_name` → `find_plan`；`test-stop-guard.sh:163` 现有 walk-up 只测 `plan.md`。

**5.8 新增 `tests/test-new-hooks.sh` completion-check plan-*.md 子目录回归测试**（Round 9 批注 #1 新增）

在现有 Test 9（L123-126，`plan.md` + all done → exit 2）附近新增一个测试：
- 在临时目录根创建 `plan-feature.md`（非默认名，含 `<!-- BATON:GO -->` + 全部完成 todo，无 Retrospective）+ `mkdir -p src/deep`
- 从子目录 `$d/src/deep` 执行 completion-check.sh
- 断言 exit code = 2（阻断，提示写 Retrospective）
- 验证 `find_plan()` walk-up 在 completion-check.sh 路径上生效。[CODE] `completion-check.sh:24-25` 调用 `resolve_plan_name` → `find_plan`；`test-new-hooks.sh:125` 只覆盖 `plan.md` + 根目录。

### Group 6: 文档更新

**6.1 更新 `README.md`**
- 删除 L140 目录树中 `workflow-full.md` 条目
- L139：`workflow.md ← Universal rules (~400 tokens)` → 更新或删除 `~400 tokens` 标注（与 L48 同理）。（Round 20 批注 #4 新增）
- L43：`BATON_PLAN=design.md` → `BATON_PLAN=plan-design.md`。`design.md` 触发 `${name/plan/research}` 退化（退化为同名），与 Risk table 已记录的命名合同风险矛盾。README 已在 write set 中，零成本修复。（Round 22 批注 #1 新增）
- L48：`~400 tokens` → 更新为实际度量或删除具体数字（计划自身已判定 ~400 tokens 为失真基线，见 Constraint 4）
- L49：`session-start hook extraction` → 改为 `session-start hook with hardcoded fallback`（extraction 不再发生）
- L192：`~400 tokens total overhead` → 同 L48 处理
- 更新架构描述段落：两层模型（workflow.md core + SKILL.md per-phase），不再提 workflow-full.md
- （Round 16 批注 #4 修正：从笼统"更新架构描述"升级为明确 rewrite checklist）

**6.3 更新 `docs/stable-surface.md`**（Round 16 批注 #2 新增）
- L39：更新 "Without phase-specific skill discipline, stricter defaults are safer" 措辞，与 Change 2.1 对 workflow.md Enforcement Boundaries 的修改同步

**6.2 更新 `docs/implementation-design.md`**
- 重写三层架构叙述：删除 workflow-full.md 相关描述
- 更新为两层模型：`workflow.md`（cross-cutting core）+ `SKILL.md`（per-phase authority）
- 更新 phase-guide 描述：skills-first + hardcoded fallback（不再有 extract_section）
- **显式验收**（rewrite 完成后执行）：
  - `grep -n workflow-full docs/implementation-design.md` → 零命中
  - `grep -n '~400 tokens\|380 tokens' docs/implementation-design.md` → 零命中（L20, L60, L93, L610 含失真 token 基线，不带 "workflow-full" 字样但同样已过时）
  - 当前测试只验证新协议关键词存在（[PAUSE]、free-text 等 [CODE] `test-workflow-consistency.sh:291,330`），不验证旧叙述已清除——L319-334（phase-guide extraction）、L432-434（升级文件）、L501-507（一致性验证）、L557-582（替换矩阵）等 stale 区块即使漏改也不会被现有测试捕获。（Round 18 #2 + Round 20 #3 修正：扩展 grep 范围覆盖 token 基线）

## Risks + Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skills 不可用时（新项目、路径 bug）fallback 质量从完整方法论降到 3-4 行 | Medium | (1) 修复 `has_skill()` + `find_plan()` 的 pwd vs JSON_CWD bug，提高 skill 发现和 plan 文件发现可靠性；(2) hardcoded fallback 保留核心纪律；(3) 所有目标 IDE 确认支持 skills |
| 测试数量下降——部分 annotation protocol coverage 无法迁移 | Low-Medium | 三类处理：(1) 被测对象移除、断言纯删除（extract_section 输出等）→ 对象不存在，测试无意义；(2) 被测对象迁移到 skills、断言改挂 PLAN_SKILL/RESEARCH_SKILL → 无损迁移；(3) 已知 coverage loss（Core Principles / [PAUSE] Handling 5-step / Correct-Incorrect behavior）→ 这些内容在 skills 中以不同结构呈现（Red Flags 表、Processing Each Annotation），概念覆盖存在但字符串级守卫丢失。接受为已知 gap。（Round 15 批注 #3 修正：与 Change 5.2 coverage loss 对齐） |
| 已安装项目里残留旧 `workflow-full.md` | Low | setup.sh 不再复制新文件，但不主动删除旧文件。旧文件成为惰性文件，不影响运行时（skill 路径跳过 extract_section） |
| docs/implementation-design.md 重写遗漏 | Low-Medium | 受测试约束的活跃文档（`test-workflow-consistency.sh:11` 引用 `IMPL_DESIGN` 变量）。含大量 workflow-full.md 引用（:17, :21, :60, :97, :293, :319-334）。测试只验证新协议关键词存在（[PAUSE]、free-text 等），**不会捕获旧叙述未清除**——stale 清理靠 Change 6.2 的显式 `grep workflow-full` 零命中验收。（Round 16 #3 + Round 19 #3 修正：与 Change 6.2 验收项对齐） |
| Research-only 子目录发现不在本轮范围 | Low | 当只有 `research-feature.md` 存在（无 plan）且从子目录进入时，phase 仍会 fallback 到 RESEARCH。这是预存缺陷，非本轮引入。当 plan 文件存在时，research 发现间接受益（`PLAN_DIR` 指向 plan 所在目录）。独立 research walk-up 可作为后续改进。（Round 8 批注 #1 新增） |
| BATON_PLAN 任意文件名 research 派生退化 | Low | `${name/plan/research}` 对不含 "plan" 的文件名（如 `design.md`）退化为同名。Pre-existing bug，README.md:43 公开允许任意名。本轮测试 fixture 改为 `plan-custom.md` 避免锁定此行为。命名合同收窄可作为后续改进。（Round 17 批注 #1 新增） |
| doctor() Codex IDE config 假阳性 | Low | `bin/baton:93` 把 AGENTS.md 当 Codex hook config（实际在 `.codex/hooks.json`）。Pre-existing bug，本轮不修。AGENTS.md 回归测试收窄到 Rules injection 段，避免锁定假阳性。（Round 16 #1 + Round 17 #2 新增） |
| 根目录 untracked plan-*.md 引用 workflow-full.md | Low | `plan-ask-user-question.md` 等是 git untracked 工作文件（`git status` = `??`），非 committed 项目 surface。实施前按 workflow.md rule 7 归档到 `plans/`，或保留为惰性文件。（Round 17 批注 #3 新增） |

## Self-Review

### Internal Consistency Check

- ✅ Recommendation（Approach A）与 Change List 一致——Groups 1/2/4/4b/5/6 围绕废除 workflow-full.md 展开；Group 3（fork-context）是独立子目标（pre-existing gap，opportunistic 收口，非机械必需）。（Round 19 批注 #4 修正）
- ✅ 每个 Change Item 都追溯到 Approach A 或 Requirement 5（Group 3）的具体理由
- ✅ Surface Scan 中所有 "modify" 文件都出现在 Change List 中（Round 1 修正：test-phase-guide.sh 从 skip 改为 modify）
- ✅ Surface Scan 中 "skip" 文件都有明确理由（迁移代码保留向后兼容；baton-implement 不在 fork context；baton-plan 不在 fork context — Round 2 批注 #3 修正）
- ✅ Document Authority 上移方向与 Change List Group 2 一致，且不包含 README.md（避免触发 L494-500 drift guard）
- ✅ setup.sh 清理完整：L1210 self-install 消息 + L1216-1219 copy 步骤
- ✅ 版本分发：phase-guide.sh 5.0 → 6.0，确保 `install_versioned_script()` 触发覆盖。_common.sh 无版本机制（直接 `cp`，L1191），改动自动分发。test-setup.sh 新增版本升级回归。（Round 11 批注 #1 新增）
- ✅ Plan 文件发现修复：`find_plan()` 重构为逐级 walk-up 时同时发现名称和文件；`has_skill()` L32 修复 JSON_CWD（预防性，无当前生产消费者）；`bin/baton:status()` 同步修复。Research 文件发现在 plan 存在时间接受益，独立 research-only 子目录场景不在本轮范围（见 Risks 表）。（Round 7+8+10 修正）
- ✅ 回归测试分两层覆盖 walk-up 合同：
  - **生产路径**：write-lock.sh（Change 5.6，真实 JSON_CWD 子目录）+ baton CLI（Change 4b.2，真实子目录参数）
  - **防御性路径**：phase-guide.sh（Test B，shell cwd 子目录）+ stop-guard.sh（Change 5.7）+ completion-check.sh（Change 5.8）— 生产中这些 hooks 由 host IDE 从项目根执行 [CODE] `setup.sh:842-849`，shell cwd 子目录不自然发生，但作为 defense-in-depth 保留
  - **间接受益（无独立测试）**：bash-guard.sh、post-write-tracker.sh、subagent-context.sh、pre-compact.sh — 与已测 hooks 共享同一 `_common.sh:find_plan()` 代码路径，且生产中均从项目根执行，无子目录场景。（Round 5+7+8+9+10 修正）
- ✅ 高层理由链（Approach A Mitigation、Recommendation、Risk table）与 Change List 同步：均已更新为同时提及 `has_skill()` + `find_plan()`，措辞收窄为 "plan 文件发现"。（Round 5 批注 #2 + Round 8 修正）
- ✅ PLAN fallback 大小写修正：`Todolist` → `todolist`，避免 grep 大小写敏感导致测试失败。（Round 2 批注 #2 修正）
- ✅ 关键前提已验证：
  - `has_skill` 返回 true 时 `extract_section` 被跳过 [CODE] `phase-guide.sh:68-133`（本 session 读取确认）
  - `extract_section()` 无其他调用者 [CODE] surface scan 确认
  - `test-phase-guide.sh` 不引用 `$FULL` 变量，但 8 个断言依赖 extract_section 输出内容 [CODE] `test-phase-guide.sh:72-73,89-90,101,108,121,124`（Round 1 修正确认）
  - `test-workflow-consistency.sh:494-500` 禁止 workflow.md 引用 README.md [CODE]（Round 1 修正确认）
  - `baton-plan/SKILL.md` 不声明 `context: fork` [CODE] grep 确认无 `context:` 行（Round 2 批注 #3 确认）
  - `resolve_plan_name()` 的 `ls -t` 在 pwd 执行 [CODE] `_common.sh:10`（Round 2 批注 #1 确认）

### External Risks

- **最大风险**：`find_plan()` 重构后仍有路径解析边界情况（如 symlinked 项目目录），导致 plan 找不到。Mitigation：生产路径回归（write-lock JSON_CWD + CLI 子目录参数）+ 防御性回归（phase-guide/stop-guard/completion-check shell cwd 子目录）。
- **Scope 边界**：本轮只修 plan 文件发现。Research-only 子目录发现（无 plan 时从子目录找 research-feature.md）是预存缺陷，不在范围内。当 plan 存在时 research 间接受益。
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
→ ⚠ **后续修正**：Test B 在 Round 10 从 JSON_CWD 改为 shell cwd 子目录场景。此条目反映的是 Round 3 时的设计，非最终方案。见 Round 10 #3 和正文 Change 5.5。

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
→ 验证：✅ 正确。[CODE] `README.md:158-161` 列出 4 个宿主（含 Factory AI）。Requirement #4 只提 `has_skill()` 但 Change 1.3 已包含 `resolve_plan_name()` 修复。Iron Law #4 违反。
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

### Round 8

**[inferred: gap-critical] § #1 research-*.md walk-up / 名称发现不在范围内**
"计划只修 plan 路径...phase-guide.sh 仍然是在 find_plan() 之后只检查当前 pwd 或 plan 所在目录里的 RESEARCH_NAME...我复现了'父目录只有 research-feature.md、从子目录进入'的场景，phase-guide.sh 和 baton status 都仍然落回 RESEARCH"
→ 验证：✅ 正确。[CODE] `phase-guide.sh:28-32` — research 发现依赖 `PLAN_DIR`（plan 所在目录）或 fallback 到 `pwd`。[CODE] `bin/baton:140,146` — 只在 `$_dir` 下查找。当 plan 存在时，`PLAN_DIR` 指向 plan 所在目录，research 间接受益。但当只有 `research-feature.md` 存在（无 plan）时，`PLAN_NAME` 默认为 `plan.md`，`RESEARCH_NAME` = `research.md`，名称推导失败，发现不到 `research-feature.md`。这是预存缺陷，非本轮引入。
→ Consequence: 选择方案"收窄 scope 到仅 plan 文件发现"。具体更新：Requirement #4 新增 scope 声明；Recommendation L52 从 "plan/phase" 收窄为 "plan 文件"；Approach A Mitigation 同步；Risks 表新增 research-only 条目；Self-Review L310 收窄；External Risks 新增 scope 边界说明。
→ Result: accepted — scope 收窄为 plan 文件发现

**[inferred: gap-medium] § #2 CLI 回归测试需子目录路径**
"CLI 回归测试设计现在抓不到它自己要防的 bug...baton status \"$d\" 在根目录本就能通过...真正缺陷是从子目录调用"
→ 验证：✅ 正确。[CODE] `bin/baton:136` `ls -t "$_dir"/plan.md "$_dir"/plan-*.md` — 当 `$_dir` 是项目根时，`plan-feature.md` 在该目录存在，glob 成功。缺陷仅在子目录调用时触发。[RUNTIME] 人类复现确认 `status <root>` = IMPLEMENT，`status <root/src/deep>` = RESEARCH。
→ Consequence: Change 4b.2 改为使用 `baton status "$d/src/deep"` 子目录路径 + `mkdir -p src/deep`。
→ Result: accepted

**[inferred: gap-medium] § #3 phase-guide Test B 需子目录场景**
"Test B 只是把 JSON_CWD 设到含 plan-feature.md 的目录本身...只能证明'root JSON_CWD 生效'，证明不了'从子目录 walk-up 过程中发现 plan-*.md'"
→ 验证：✅ 正确。Test B 原设计将 JSON_CWD 指向含 plan-feature.md 的目录——这只证明 JSON_CWD 替代 pwd 生效，不证明 walk-up。Change 1.3 的核心合同是"在逐级 walk-up 中每级做名称发现"。[CODE] write-lock 测试（Change 5.6）确实用了子目录 cwd（`<tmp>/project/src`），是目前唯一覆盖子目录 walk-up 的用例。
→ Consequence: Test B 重设计——JSON_CWD 改为指向子目录 `<tmp>/src/deep`，plan-feature.md 放在 `<tmp>/` 根。验证 find_plan() 从子目录 walk-up 时发现父目录的 plan-*.md。Self-Review 回归测试条目同步更新。
→ Result: accepted

**[inferred: scope-question] § #4 Scope: plan 文件 vs 全部 phase 文件？**
"Requirement 4 到底要修'所有 phase 文件发现'，还是只修'plan 文件发现'？"
→ 回答：**仅 plan 文件发现**。理由：(1) Plan 文件发现是高影响修复——plan 控制所有 ANNOTATION/IMPLEMENT/ARCHIVE/AWAITING_TODO 状态转换，而 research 只影响 RESEARCH → PLAN 转换；(2) research 发现在 plan 存在时已间接受益（`PLAN_DIR` 指向正确目录）；(3) research-only + 子目录是较窄场景（research 阶段用户通常在项目根目录）；(4) 本 plan 已是 Large 复杂度，增加 research walk-up 扩大范围不利于收敛。
→ Consequence: 已在 Requirement #4、Recommendation、Approach A Mitigation、Risks、Self-Review、External Risks 六处收窄措辞。
→ Result: answered — scope = plan 文件发现 only

### Round 9

**[inferred: gap-critical] § #1 stop-guard.sh + completion-check.sh 回归测试缺失**
"共享 find_plan() 的改动没有把另一个阻断面一起纳入回归...completion-check.sh 和 stop-guard.sh 也直接依赖同一个 _common.sh 查 plan...我本地复现了当前 bug：父目录只有 plan-feature.md、从 src/deep 运行时，stop-guard.sh 静默，completion-check.sh 直接 exit 0"
→ 验证：✅ 正确。[CODE] `completion-check.sh:24-25` 调用 `resolve_plan_name` → `find_plan`。[CODE] `stop-guard.sh:22-23` 同理。[CODE] `test-stop-guard.sh:163` walk-up 测试只用 `plan.md`，无 `plan-*.md` 场景。[CODE] `test-new-hooks.sh:125` completion-check 只用 `plan.md` + 根目录。人类复现确认：子目录 + plan-feature.md 时两个 hook 均静默失效。
→ Consequence: Surface Scan 新增 test-stop-guard.sh + test-new-hooks.sh 条目（L2 modify）。Change List 新增 5.7（stop-guard 子目录回归）和 5.8（completion-check 子目录回归）。Impact 更新 14 → 16。Self-Review 回归测试条目新增两条路径。External Risks mitigation 新增两条测试路径。
→ Result: accepted

**[inferred: gap-medium] § #2 Test B 断言过松**
"fixture 只创建 plan-feature.md，没有 GO，也没有 research...按当前状态机，只要找到 plan，就必然落到 ANNOTATION...现在计划写成'ANNOTATION（或 PLAN）'，这会把 phase 判定错误也放过去"
→ 验证：✅ 正确。[CODE] `phase-guide.sh:83` State 4 (ANNOTATION) 触发条件为 plan 存在但无 GO。fixture 创建 plan-feature.md 无 GO 无 research → 确定性落到 ANNOTATION。"或 PLAN" 会放过 walk-up 失败后 fallback 到 RESEARCH 再被 research 存在升到 PLAN 的假阳性路径。
→ Consequence: Test B 断言锁死为 `ANNOTATION` + 新增负向断言 `不包含 RESEARCH`。
→ Result: accepted

### Round 10

**[inferred: duplicate — already addressed in Round 9] § #1 stop-guard + completion-check 回归**
“共享 find_plan() 重构的回归面仍然漏了真正会影响用户流程的 hook...stop-guard.sh 和 completion-check.sh 同样直接依赖 _common.sh”
→ 已在 Round 9 处理。Changes 5.7（test-stop-guard.sh plan-*.md 子目录回归）和 5.8（test-new-hooks.sh completion-check plan-*.md 子目录回归）在 Round 9 中新增。Surface Scan、Impact、Self-Review 均已同步。
→ Result: already addressed in Round 9

**[inferred: gap-medium] § #2 剩余 4 个 advisory hooks blast radius**
“blast radius 还被继续低估在另外 4 个 advisory hooks 上...bash-guard、post-write-tracker、subagent-context、pre-compact 全都 source _common.sh...本地复现时 subagent-context.sh 和 pre-compact.sh 都没有输出，post-write-tracker.sh 对未列入计划的文件也不告警，bash-guard.sh 反而按'未解锁'路径发警告”
→ 验证：✅ 人类复现结果正确。[CODE] `bash-guard.sh:10-18` source `_common.sh`，`post-write-tracker.sh:41-49` 同理，`subagent-context.sh:16-24` 同理，`pre-compact.sh:16-24` 同理。4 个 hooks 都调用 `resolve_plan_name` → `find_plan`，当 plan 找不到时各有不同行为：bash-guard L20 → 走”未解锁”分支（false positive）；其余三个 `[ -z “$PLAN” ] && exit 0`（false negative / 静默）。
→ 但 [CODE] `setup.sh:842-849` 确认所有 hooks 配置为 `bash .baton/hooks/<hook>.sh`，由 host IDE 从项目根目录执行。生产环境中 pwd = 项目根，find_plan() 直接在根目录找到 plan-*.md，**无需 walk-up**。人类的复现场景（手动 cd 到 src/deep 后执行 hook）在生产中不会自然发生。
→ Consequence: 不为这 4 个 hooks 新增独立回归测试（测试场景不对应生产路径）。Self-Review 已更新为三层结构（生产路径 / 防御性路径 / 间接受益），明确说明这 4 个 hooks 通过共享 `_common.sh:find_plan()` 间接受益，且生产中均从项目根执行。”覆盖完整”的措辞已在 Round 8 移除。
→ Result: partially accepted — blast radius 分析正确，但基于生产调用路径分析不新增独立测试

**[inferred: gap-critical] § #3 JSON_CWD 测试是合成场景**
“仓库内只有 write-lock.sh 会从 hook payload 解析 cwd 并设置 JSON_CWD...实际安装出来的 SessionStart / Stop 命令只是直接执行脚本...如果没有一个外部 host contract 明确会给 phase-guide/stop-guard 注入 JSON_CWD，那这组测试就在验证 repo 里并不存在的运行时路径”
→ 验证：✅ 正确。[CODE] `write-lock.sh:28-44` 是唯一从 stdin 解析 `JSON_CWD` 的 hook。[CODE] `setup.sh:842` SessionStart 配置为 `bash .baton/hooks/phase-guide.sh`（无 JSON 输入）。[CODE] `setup.sh:846` Stop 配置为 `bash .baton/hooks/stop-guard.sh`（无 JSON 输入）。其他 hooks 虽有 stdin 但不解析 cwd。
→ 推导：`has_skill()` 的 `${JSON_CWD:-$(pwd)}` 修复是预防性的——当前无 hook 同时设置 JSON_CWD 又调用 has_skill()。为 phase-guide 测试 JSON_CWD 路径确实在验证不存在的运行时场景。
→ Consequence:
  - **Test A（has_skill via JSON_CWD）移除**——has_skill() shell cwd walk-up 已被 Test 16 覆盖；JSON_CWD 版无生产消费者
  - **Test B 从 JSON_CWD 改为 shell cwd**——cd 到子目录执行 phase-guide.sh。仍是防御性测试（生产中 hooks 从项目根执行），但比 JSON_CWD 方案更贴近可能的边界情况
  - **has_skill() JSON_CWD 修复标注为预防性**——Change 1.3 保留修复（1 行，一致性），但注明无当前生产消费者
  - **JSON_CWD 真实场景由 write-lock.sh 测试覆盖**——Change 5.6 是唯一的生产 JSON_CWD 回归
→ Result: accepted — 测试策略重构为生产路径 + 防御性路径两层

**[inferred: context] § 假设：plans/ 是归档材料**
“我把 plans/ 下历史文档都视为归档材料，没有把它们算进必须同步的活跃 surface”
→ 确认：一致。plans/ 是归档目录，不是活跃 surface。plan Change List 和 Surface Scan 中已将其排除。
→ Result: acknowledged

### Round 11

**[inferred: gap-critical] § #1 版本号升级缺失——分发失效**
"setup.sh 只按 # Version: 比较脚本是否需要覆盖...phase-guide.sh 现在是 5.0...我本地构造了一个'内容过时但仍标 Version: 5.0'的项目脚本，跑 setup.sh 的结果是 phase-guide.sh is up to date (v5.0)"
→ 验证：✅ 正确。[CODE] `setup.sh:659` `if [ "$_ivs_sv" = "$_ivs_dv" ] && [ -n "$_ivs_sv" ]; then return` — 版本相同则跳过。[CODE] `phase-guide.sh:3` 当前 `# Version: 5.0`。[CODE] `setup.sh:1199` `install_versioned_script "phase-guide.sh"` — phase-guide 通过版本化安装。[CODE] `setup.sh:1191` `cp "$BATON_DIR/.baton/hooks/_common.sh"` — _common.sh 直接 cp，不受版本机制影响。
→ 影响分析：phase-guide.sh 是本计划唯一通过 `install_versioned_script` 安装且被修改的 hook。_common.sh 直接 cp 无需版本。其他 hooks（stop-guard、bash-guard 等）本计划不修改内容，不需要升版。
→ Consequence: Change 1.2 新增版本升级 5.0 → 6.0。Change 5.3 (test-setup.sh) 新增版本升级回归测试。Self-Review 新增版本分发检查条目。
→ Result: accepted — 这是真正的分发阻断问题

**[inferred: duplicate — already addressed in Round 10] § #2 has_skill() JSON_CWD 是合成场景**
"plan-decoupling.md:259 这组 phase-guide/has_skill 的 JSON_CWD 测试更像合成场景"
→ 已在 Round 10 #3 处理。当前状态：Test A 已移除（L261），Test B 已改为 shell cwd（L263-269），has_skill() 修复已标注为预防性（L114）。人类引用的 L259 内容（"在现有 Test 16 之后新增一个测试"）在 Round 10 编辑后指向不同内容。
→ Result: already addressed in Round 10

**[inferred: duplicate — already addressed in Round 9+10] § #3 blast radius 低估 + "覆盖完整"**
"变更集只给 phase-guide、write-lock、CLI 补回归...其余实际依赖 find_plan() 的 subagent-context.sh、pre-compact.sh、post-write-tracker.sh、bash-guard.sh 都没有进入测试补强"
→ 已在 Round 9 + Round 10 处理。当前状态：
  - Round 9 新增 Changes 5.7（stop-guard）和 5.8（completion-check）
  - Round 10 将 Self-Review 重构为三层结构（L328-331）：生产路径 / 防御性路径 / 间接受益。"覆盖完整"措辞已移除。4 个 advisory hooks 明确归类为"间接受益（无独立测试）"并附理由（共享函数 + 生产中从项目根执行）。
  - 人类的"要么降级成'本轮不验证'，要么纳入计划"——已选择前者（降级 + 明确标注），且附生产调用路径分析作为理由。
→ Result: already addressed in Round 9+10

**[inferred: gap-low] § #4 证据行号漂移**
"Requirement 1 说 README.md:137-140 列出四个宿主，但当前四个宿主实际在 README.md:154；README 目录树里 workflow-full.md 也不在计划写的 :119，而在 README.md:140"
→ 确认：行号在多轮编辑后漂移是正常的。这不影响技术方向但增加复核成本。在实施阶段，每个 Change Item 执行前会重新定位实际行号（baton-implement skill 要求"re-read plan intent"）。
→ Consequence: 不在 plan 中逐条修正行号（会在下次编辑后再次漂移）。实施时以文件内容匹配定位，不依赖行号。
→ Result: acknowledged — 行号是指引而非合同，实施时重新定位

### Round 12

**[inferred: gap-critical] § #1 doctor() 假阳性——旧 import 视为健康**
"baton doctor() 仍把旧 workflow-full import 当健康配置...bin/baton:99 正则 @\.baton/workflow(-full)?\.md 接受已删除文件的引用...我本地复现了把 CLAUDE.md 改回 @.baton/workflow-full.md 同时删掉 .baton/workflow-full.md 的场景，baton doctor 仍输出 Result: all checks passed."
→ 验证：✅ 正确。[CODE] `bin/baton:99` `grep -qE '@\.baton/workflow(-full)?\.md'` 正则的 `(-full)?` 使其接受 `@.baton/workflow-full.md`。删除 workflow-full.md 后，这个 import 指向不存在的文件，doctor 不应视为健康。[CODE] `test-cli.sh:89-106` doctor 测试只验证"能跑"和"列脚本"，不测规则注入语义。
→ Consequence: Change 4b.1 新增 doctor() 正则收紧。Change 4b.2 新增 doctor 规则注入回归测试（旧 import → 报 issue；正确 import → all checks passed）。
→ Result: accepted

**[inferred: gap-medium] § #2 迁移代码从 skip 升级为 keep + test**
"向后兼容的旧 import 迁移被当成 skip，但没有回归测试保护...既然文件要被删，这已经不是'保留即可'，而是必须受测的兼容边界"
→ 验证：✅ 正确。[CODE] `setup.sh:949-953` CLAUDE.md 迁移 `@.baton/workflow-full.md` → `@.baton/workflow.md`。[CODE] `setup.sh:1047-1050` AGENTS.md 同理。删除 workflow-full.md 后，旧项目依赖这些迁移将旧 import 更新为有效 import。若迁移代码意外被破坏，旧项目会指向不存在的文件。
→ Consequence: Surface Scan Skip Justification 中 `setup.sh:949-953, :1047-1050` 从 "skip（迁移代码）" 升级为 "keep + test"。Change 5.3 新增迁移路径回归测试。
→ Result: accepted

**[inferred: gap-medium] § #3 annotation protocol 断言应迁移而非删除**
"test-annotation-protocol.sh 的删法会把一块详细批注协议 coverage 直接蒸发，而不是迁到新的权威面...如果新的权威面是 baton-plan / baton-research skills，这里应该把 focused assertions 改挂到 skill 文件"
→ 验证：✅ 大部分可迁移。[CODE] baton-plan/SKILL.md 包含：Annotation Log (L248/253), Annotation Log Format (L248), [PAUSE] (L210), Approach Analysis (L76), fundamental constraints (L67), Fundamental Problems (L147), infer intent (L222), Consequence detection (L225)。"Correct behavior:" / "Incorrect behavior:" 在 skills 中无直接等价物（Red Flags 表承载类似功能但措辞不同），标记为 coverage loss。
→ Consequence: Change 5.2 重构——从"DELETE all FULL" 改为 DELETE + MIGRATE 结构。可迁移断言改挂 baton-plan/SKILL.md。"Correct/Incorrect behavior" 标记为已知 coverage loss。
→ Result: accepted

### Round 13

**[inferred: gap-critical] § #1 doctor() AGENTS.md 规则注入检查缺失**
"Round 12 的 doctor() 修复只收紧了 CLAUDE.md，没有把 Codex 的 AGENTS.md 旧 import 一起修掉...Codex 在 doctor() 里走的是 _check_ide_config，旧的 @.baton/workflow-full.md 仍然匹配 'baton'...我本地复现了 baton doctor 仍输出 Result: all checks passed."
→ 验证：✅ 正确。[CODE] `bin/baton:93` `_check_ide_config "$_dir" "codex" "AGENTS.md" "baton"` 检查 AGENTS.md 含 "baton"——`@.baton/workflow-full.md` 匹配此模式。[CODE] `bin/baton:97-105` 当前 doctor 只有 CLAUDE.md 的 @import 规则注入检查，无 AGENTS.md 对应检查。
→ Consequence: Change 4b.1 新增 AGENTS.md 规则注入检查块（在 L105 之后新增 `if [ -f "$_dir/AGENTS.md" ]` 块）。
→ Result: accepted

**[inferred: gap-medium] § #2 CLI status 回归断言太弱——只锁 phase 不锁 Plan:/Research: 明细**
"4b.2 只要求 baton status 输出包含 IMPLEMENT...status() 本身会打印 Plan: / Research: 两行...这意味着'phase 修好了，但仍显示 plan.md / research.md (not found)'的半修状态会被放过去"
→ 验证：✅ 正确。[CODE] `bin/baton:179-181` status() 打印 `Plan: $_pname ($_plan_status)` 和 `Research: $_rname ($_research_status)`。子目录调用时 `$_pname` fallback 到 `plan.md` 导致所有输出行使用错误文件名。仅断言 `IMPLEMENT` 不够——"phase 对但文件名错"的半修状态不会被捕获。
→ Consequence: Change 4b.2 扩展断言——新增 `plan-feature.md` 和 `research-feature.md` fixture，断言 Plan/Research 输出行包含正确文件名和 `exists` 状态。
→ Result: accepted

**[inferred: duplicate — already addressed in Round 12 #2] § #3 迁移回归测试**
"安装时的旧 import 迁移现在成了硬兼容路径，但计划仍然没给它补回归"
→ 已在 Round 12 #2 处理。Change 5.3 (L247) 已新增迁移路径回归测试：创建含 `@.baton/workflow-full.md` 的 CLAUDE.md/AGENTS.md → 运行 setup.sh → 断言迁移完成。
→ Result: already addressed in Round 12

**[inferred: gap-medium] § #4 annotation coverage loss 低估——Core Principles 和 [PAUSE] Handling 未计入**
"原来 workflow-full.md 里的 Core Principles for AI Responses 和独立的 [PAUSE] Handling 过程也是被删测试的一部分 workflow-full.md:322 workflow-full.md:356 而计划没有把这两块计入 coverage loss"
→ 验证：✅ 正确。[CODE] `test-annotation-protocol.sh:62` `check "$FULL" "Core Principles"` — 验证 workflow-full.md:322 "#### Core Principles for AI Responses" 标题存在。[CODE] `test-annotation-protocol.sh:63` `check "$FULL" "\[PAUSE\] Handling"` — 验证 workflow-full.md:356 "#### [PAUSE] Handling" 5-step process 存在。[CODE] SKILL.md 无 "Core Principles" 字符串（grep 零命中），无 "[PAUSE] Handling" 标题（grep 零命中）。SKILL.md:217 "Processing Each Annotation" 承载等价功能但标题不同；SKILL.md:210 提及 [PAUSE] 概念但无独立处理流程。
→ Consequence: Change 5.2 MIGRATE 段补充 "Round 1" 迁移（SKILL.md:255 有此模板）。Coverage loss 新增 "Core Principles" 和 "[PAUSE] Handling" 5-step process 两条。
→ Result: accepted

### Round 14

**[inferred: internal-contradiction] § #1 BATON_PLAN 子目录分支——plan vs hooks 行为不一致**
“CLI 的 BATON_PLAN 子目录分支仍然没有被计划约束住...计划要求 status() 与共享 find_plan() 等价，同时又写'保留 BATON_PLAN 显式设置路径不变'...CLI 从 src/deep 执行 BATON_PLAN=custom.md baton status 仍落回 RESEARCH”
→ 验证：✅ 内部矛盾。[CODE] Change 1.3 L123-130 新 find_plan() BATON_PLAN 分支向上遍历。[CODE] Change 4b.1 L187（修正前）说 “保留 BATON_PLAN 不变”。[CODE] `bin/baton:133-134` 当前 BATON_PLAN 只在 `$_dir` 下查找，不 walk-up。Change 4b.2 无 BATON_PLAN 测试用例。
→ Consequence: Change 4b.1 从 “保留不变” 修正为 “BATON_PLAN 分支同样向上遍历”。Change 4b.2 新增 BATON_PLAN 子目录回归测试。
→ Result: accepted — 内部矛盾已修正

**[inferred: gap-medium] § #2 doctor() AGENTS.md 回归测试缺失**
“4b.2 的回归描述还是只写了 CLAUDE.md 旧/新 import...这次新加的 AGENTS.md 检查如果没有专门回归，很容易再次只修 Claude、不修 Codex”
→ 验证：✅ 正确。Change 4b.1 新增了 AGENTS.md 规则注入检查代码，但 Change 4b.2 doctor 测试只覆盖 CLAUDE.md 路径。[CODE] `bin/baton:93` Codex 走独立分支 `_check_ide_config “$_dir” “codex” “AGENTS.md” “baton”`。
→ Consequence: Change 4b.2 doctor 回归扩展为 CLAUDE.md + AGENTS.md 双路径测试。
→ Result: accepted

**[inferred: gap-medium] § #3 annotation 迁移只覆盖 baton-plan，baton-research 失去 guard**
“原来那套协议本身是跨 plan 和 research 的，baton-research 这边会失去 guard...baton-research 也有完整的 Annotation Protocol、infers intent、[PAUSE]、Consequence detection、Annotation Log 语义”
→ 验证：✅ 正确。[CODE] baton-research/SKILL.md:209 “## Annotation Protocol (Research Phase)”, L212 “infers intent”, L214 “[PAUSE]”, L224/230 “Annotation Log”, L226 “Consequence detection”。迁移只引入 PLAN_SKILL，baton-research 侧的等价内容无测试守卫。
→ Consequence: Change 5.2 MIGRATE 段从单侧改为双侧迁移——新增 `RESEARCH_SKILL=` 变量，为 infers intent / free-text / Consequence detection / Annotation Log / [PAUSE] 添加 baton-research 侧断言。
→ Result: accepted

**[inferred: bug-low] § #4 大小写错误——“Free-text” vs “free-text”**
“计划写的是 check “$PLAN_SKILL” “Free-text”，但 baton-plan 里实际是小写 free-text”
→ 验证：✅ 正确。[CODE] baton-plan/SKILL.md:207 “free-text annotations”（小写 f）。grep 大小写敏感，`”Free-text”` 不匹配。
→ Consequence: Change 5.2 MIGRATE 段 “Free-text” → “free-text”。
→ Result: accepted

**[inferred: scope-confirmation] § #5 归档排除确认**
“plans/ / docs/plans/ 视为归档材料，不算本轮 live surface”
→ 与既有 Surface Scan 范围一致。归档目录不在 L1/L2 扫描范围内。
→ Result: acknowledged

### Round 15

**[inferred: gap-critical] § #1 BATON_PLAN walk-up 只改名称发现，存在性检查仍用 `$_dir`**
“即使你把'名字发现'修成 walk-up，显式 BATON_PLAN=custom.md 从 src/deep 调 status() 仍会找不到父目录文件...真正把 phase 判成存在与否的是后面的 $_dir/$_pname / $_dir/$_rname 检查 bin/baton:142”
→ 验证：✅ 正确。[CODE] `bin/baton:144` `[ -f “$_dir/$_pname” ]` — `$_dir` 是传入参数（如 `src/deep`），walk-up 找到的 plan 在父目录。名称对了但目录错了 → 存在性检查失败 → `_plan=””` → phase = RESEARCH。同理 L146 `_research` 检查也用 `$_dir`。对比 `_common.sh:find_plan()` 直接设 `PLAN=”$_fp_d/$PLAN_NAME”` 返回完整路径。
→ Consequence: Change 4b.1 重写——walk-up 必须同时产出 `_pname`（名称）和 `_pdir`（plan 所在目录），存在性检查改用 `_pdir`。隐式和 BATON_PLAN 分支均需此修正。Round 14 的”同步 walk-up”修正不够充分。
→ Result: accepted — 这是本轮最关键的修正

**[inferred: duplicate — already addressed in Round 14] § #2 doctor() AGENTS.md 测试**
→ 已在 Round 14 #2 处理。[CODE] Change 4b.2 L203-205 已包含 AGENTS.md 旧/新 import 双路径测试。
→ Result: already addressed in Round 14

**[inferred: internal-contradiction] § #3 风险表与 coverage loss 互相矛盾**
“5.2 现在明确把 Core Principles、[PAUSE] Handling、Correct/Incorrect behavior 标成 coverage loss...可风险表仍写成'被测对象不存在，测试无意义'...两段已经互相矛盾了”
→ 验证：✅ 内部矛盾。[CODE] Change 5.2 coverage loss 列出 4 项无法迁移的断言。[CODE] 风险表（Round 15 前）写 “被测对象不存在→测试无意义”——这忽略了迁移和 coverage loss 两类。
→ Consequence: 风险表行重写，区分三类处理（纯删除/无损迁移/已知 coverage loss），与 Change 5.2 对齐。严重度从 Low 上调为 Low-Medium。
→ Result: accepted — 内部矛盾已修正

**[inferred: duplicate — already addressed in Round 14] § #4 baton-research 迁移**
→ 已在 Round 14 #3 处理。[CODE] Change 5.2 MIGRATE 段 L241-249 已包含 RESEARCH_SKILL 双侧迁移。
→ Result: already addressed in Round 14

**[inferred: duplicate — already addressed in Round 14] § #5 “Free-text” 大小写**
→ 已在 Round 14 #4 处理。[CODE] Change 5.2 L242 已改为 “free-text”（小写）。
→ Result: already addressed in Round 14

### Round 16

**[inferred: scope-question] § #1 doctor() Codex IDE config 假阳性——AGENTS.md ≠ Codex hook config**
“doctor() 把 AGENTS.md 当成 Codex hook 配置来检查...实际 Codex hook 配置落在 .codex/hooks.json...只有 AGENTS.md、没有 .codex/hooks.json 的项目，baton doctor 仍显示 ✓ codex hooks configured”
→ 验证：✅ 问题真实存在。[CODE] `bin/baton:93` `_check_ide_config “$_dir” “codex” “AGENTS.md” “baton”` — 把 AGENTS.md 当 Codex hook config。[CODE] `docs/ide-capability-matrix.md:37` 确认实际配置在 `.codex/hooks.json`。
→ 但：**pre-existing bug**，非本轮引入。workflow-full.md 废除不改变此行为。本轮已在 doctor() 上做 2 处修复（rules injection regex + AGENTS.md @import），再加 IDE config 修复进一步扩大已经 Large 的 scope。
→ Result: **推荐为后续修复**，不纳入本轮。Risk 表可新增一行记录。若人类认为应纳入，请在批注区明确指示。

**[inferred: gap-medium] § #2 docs/stable-surface.md 遗漏出 Surface Scan**
“稳定面文档还保留着同一句 'Without phase-specific skill discipline...'...当前 surface scan 只列了 README.md 和 docs/implementation-design.md”
→ 验证：✅ 正确。[CODE] `docs/stable-surface.md:39` 含同源措辞。无测试约束（grep tests/ 零命中），但作为设计文档会产生措辞漂移。
→ Consequence: Surface Scan L2 新增 `docs/stable-surface.md`。Group 6 新增 Change 6.3。Impact 16→17 个文件。
→ Result: accepted

**[inferred: gap-medium] § #3 docs/implementation-design.md 风险低估——受测试约束**
“测试已经把这个文件当成活跃协议面的一部分 test-workflow-consistency.sh:11...还保留着 workflow-full.md 提取、~400 tokens 约束等核心叙述”
→ 验证：✅ 正确。[CODE] `test-workflow-consistency.sh:11` `IMPL_DESIGN=` 变量引用。[CODE] `implementation-design.md:17,21,60,97,293,319-334` 大量 workflow-full.md 引用。
→ Consequence: Risk 表行重写（Low→Low-Medium，”纯文档”→”受测试约束的活跃文档”）。Surface Scan L2 条目同步更新。
→ Result: accepted

**[inferred: gap-medium] § #4 README.md rewrite checklist 太笼统**
“README 里还有 session-start hook extraction 的说法、两处 ~400 tokens 说法...最好升级成明确的 rewrite checklist”
→ 验证：✅ 正确。[CODE] `README.md:48` “~400 tokens”, `README.md:49` “session-start hook extraction”, `README.md:140` workflow-full.md 目录项, `README.md:192` “~400 tokens total overhead”。
→ Consequence: Change 6.1 扩展为 4 个具体行号 + 架构段落的 rewrite checklist。
→ Result: accepted

### Round 17

**[inferred: gap-medium] § #1 BATON_PLAN 测试 fixture 锁定 research 派生退化行为**
“对 custom.md / design.md 这类不含 plan 的名字，RESEARCH_NAME 会退化成和 plan 同名...新计划在 CLI 回归里继续用 custom.md，且只断言输出包含 custom.md”
→ 验证：✅ 正确。[CODE] `bin/baton:140` `_rname=”${_pname/plan/research}”` — `custom.md` 无 “plan” 子串 → `_rname=”custom.md”` → Plan/Research 同名。[CODE] `phase-guide.sh:25` 同理。[CODE] `README.md:43` 公开允许 `BATON_PLAN=design.md`。
→ Consequence: Change 4b.2 BATON_PLAN test fixture 从 `custom.md` 改为 `plan-custom.md`，避免锁定退化行为。命名合同收窄作为后续改进记入 Risks 表。
→ Result: accepted

**[inferred: internal-contradiction] § #2 doctor() AGENTS.md 回归断言锁定假阳性**
“计划自己已经把 'Codex IDE config 假阳性' 标成后续修复...但 4b.2 仍要求 'AGENTS.md 正确 import 时断言 all checks passed'”
→ 验证：✅ 内部矛盾。Round 16 #1 决定 Codex IDE config 假阳性不在本轮修复。但 “all checks passed” 断言依赖 Codex IDE config 也是健康的——仅有 AGENTS.md 的 fixture 会触发假阳性。
→ Consequence: Change 4b.2 AGENTS.md 正确 import 测试改为只断言 Rules injection 段不含 `⚠`，不断言全局 “all checks passed”。
→ Result: accepted — 内部矛盾已修正

**[inferred: scope-clarification] § #3 根目录 untracked plan-*.md 引用 workflow-full.md**
“plan-ask-user-question.md 还把 workflow-full.md 当 phase-guide 数据源...删掉 workflow-full.md 后，这类顶层计划文档会直接变成过时架构说明”
→ 验证：这些文件是 **git untracked**（`git status` = `??`），非 committed 项目 surface。它们是其他 conversation 的工作产物，不参与 CI 或测试。
→ Consequence: 不纳入 Surface Scan write set。在 Risks 表新增一行，实施前按 workflow.md rule 7 归档到 `plans/` 即可。
→ Result: acknowledged as non-committed working files

**[inferred: readability] § #4 Annotation Log 内部矛盾——Test B JSON_CWD vs shell cwd**
“正文 5.5 明确写的是 shell cwd 子目录场景...审阅记录又把同一测试描述成 JSON_CWD 场景”
→ 验证：✅ 正确。[CODE] Change 5.5 L295-301 说 “shell cwd”（当前方案）。Round 3 #4 L448 说 “JSON_CWD”（Round 10 前的旧方案）。这是历史记录的正常演变，但增加复核成本。
→ Consequence: Round 3 #4 条目追加 “⚠ 后续修正” 脚注，指向 Round 10 #3 和正文 Change 5.5。
→ Result: accepted — 脚注已添加

### Round 18

**[inferred: gap-medium] § #1 Surface Scan _common.sh 描述低估主变更**
“表里只写了'删 extract_section() + 修 has_skill()'，但正文真正的大改是 find_plan() / resolve_plan_name() 的重构，以及 8 个 hook 的共享行为变化”
→ 验证：✅ 正确。[CODE] Surface Scan L62 只列附带项。Change 1.3 L116-149 的主体是 `find_plan()`/`resolve_plan_name()` 重构（30+ 行新代码，8 个 hook 行为变化），这是本计划最大的逻辑变更。
→ Consequence: Surface Scan _common.sh 行重写——主变更（find_plan 重构）前置，附带项后列。
→ Result: accepted

**[inferred: gap-medium] § #2 implementation-design.md 风险缓解过于乐观**
“当前测试只验新协议关键词存在...它并不验证旧的 workflow-full.md 叙述被删干净...L432, L501, L557 等 stale 区块即使漏改也可能照样过测”
→ 验证：✅ 正确。[CODE] `test-workflow-consistency.sh:291` 检查 `[PAUSE]`、L330 检查 `free-text`——都是正向关键词断言。`implementation-design.md:319-334,432-434,501-507,557-582` 含旧叙述，不被现有测试覆盖。
→ Consequence: Change 6.2 新增显式验收项——rewrite 后 `grep workflow-full` 断言零命中。
→ Result: accepted

**[inferred: scope-framing] § #3 Group 3 fork-context 是并行议题**
“baton-research 在 context: fork 下引用 workflow.md，而不是因为这次废除 workflow-full.md 才新出现的问题...这块最好单独标成'顺手收口的独立子目标'”
→ 验证：✅ 正确。fork-context gap 是 pre-existing（research 确认），非 workflow-full.md 废除引入。但它是小变更（~10 行到 1 个文件），与 annotation protocol 迁移共享知识上下文，分拆反增管理成本。
→ Consequence: Group 3 标题 + Requirement 5 标注为”独立子目标（opportunistic，非机械必需项）”。保留在本计划中但明确关系。
→ Result: accepted — 保留但重新定性

### Round 19

**[inferred: gap-critical] § #1 Group 3 测试会”没做也过”——依赖句无断言**
“拟新增的 research-side 守卫只检查 infers intent、[PAUSE] 等关键词...这些词在当前 skill 里已经存在...真正有问题的是那句'rules live in workflow.md' SKILL.md#L217，但计划没有任何断言去锁这个依赖已被移除”
→ 验证：✅ 正确。[CODE] baton-research/SKILL.md:217-218 “Cross-cutting annotation rules... live in `workflow.md`”。Change 5.2 的 RESEARCH_SKILL 断言（infers intent / [PAUSE] 等）全部匹配现有内容 → 不做任何改动也通过。Group 3 的实质变更（改写依赖句）无守卫。
→ Consequence: Change 3.1 重写——从”加 ~10 行摘要”缩窄为”改写 L217-218 依赖句 + 内联 3 条 cross-cutting rules”。新增验证：(1) 不含 “live in `workflow.md`” 委托句；(2) 三条 rules 有内联表述。明确 Change 5.2 的 RESEARCH_SKILL 断言是 annotation protocol 迁移，不验证 Group 3。
→ Result: accepted — 这是关键的测试有效性修正

**[inferred: gap-medium] § #2 Group 3 “加 ~10 行摘要”会重复现有内容**
“baton-research 已经写了 file:line、Infer intent、回写文档和记录 Annotation Log...真正该改的是把依赖句改写成自足表述”
→ 验证：✅ 正确。[CODE] SKILL.md:220-230 已有完整的 Processing Each Annotation（Read code / Infer intent / Respond with evidence / Consequence detection）。真正缺失的仅是 L217-218 委托给 workflow.md 的三条 cross-cutting rules（analysis write-back / approach re-evaluation / annotation cleanup）。
→ Consequence: 与 #1 合并处理。Change 3.1 改为只内联 3 条缺失 rules，不重复已有段落。
→ Result: accepted — 与 #1 合并

**[inferred: internal-contradiction] § #3 implementation-design.md 风险表与 Change 6.2 验收矛盾**
“Change 6.2 承认'现有测试只验新关键词存在，不会抓到旧叙述没删干净'...但风险表仍写'测试将验证关键一致性断言'”
→ 验证：✅ 内部矛盾。Risk table L354 说 “测试将验证”；Change 6.2 的显式验收（`grep workflow-full` 零命中）承认测试无法覆盖。
→ Consequence: Risk table 行重写——“测试只验证新关键词存在，stale 清理靠 Change 6.2 显式 grep 验收”。
→ Result: accepted — 内部矛盾已修正

**[inferred: internal-contradiction] § #4 Self-Review 与 Group 3 scope 标注冲突**
“Self-Review 仍说'所有改动都是围绕废除 workflow-full.md 展开'...但 Group 3 已标成'独立子目标'”
→ 验证：✅ 正确。L364 “所有改动” 与 Group 3 标注矛盾。
→ Consequence: Self-Review L364 更新——区分 Groups 1/2/4/4b/5/6（围绕废除展开）和 Group 3（独立子目标）。
→ Result: accepted

### Round 20

**[inferred: gap-medium] § #1 Group 3 “文案修了，测试没锁”——自足性无回归守卫**
“Group 5 没有相应新增断言；现有测试仍只检查 baton-research 里本来就已有的关键词...Group 3 的关键修复现在主要靠人工验收”
→ 验证：✅ 正确。Change 5.2 的 RESEARCH_SKILL 断言（infers intent / [PAUSE] 等）全部匹配现有内容。Change 3.1 的验证点（”不含 live in workflow.md”、”三条 rules 有内联表述”）在正文中描述为人工检查，不在 test-annotation-protocol.sh 中。
→ Consequence: Change 5.2 新增 Group 3 自足性守卫——`check_not` 验证委托句已移除 + `check` 验证 “document body”（write-back rule 内联标志）。如 `check_not` helper 不存在则先添加。
→ Result: accepted

**[inferred: scope-question] § #2 --uninstall 路径无 legacy fixture 测试**
“setup.sh --uninstall 也显式支持清理旧的 @.baton/workflow-full.md 引用 setup.sh:380 setup.sh:394...没有 legacy workflow-full fixture”
→ 验证：问题真实，但 scope 有限。[CODE] `setup.sh:380` `sed -i.bak '/@\.baton\/workflow\(-full\)\{0,1\}\.md/d'` — uninstall regex `(-full)?` 对清理场景**正确**（应同时移除新旧引用）。此代码不在本计划修改范围内，regex 语义与 doctor() 不同（uninstall = 全清，doctor = 区分有效/无效）。
→ 现有卸载测试（`test-setup.sh:533-563`）覆盖标准路径。Legacy fixture 测试是增强但非必需——uninstall 代码未被修改且 regex 行为正确。
→ Result: **推荐为可选增强**，不纳入本轮必需变更。若人类认为应纳入，请明确指示。

**[inferred: gap-medium] § #3 implementation-design.md grep 验收过窄——“~400 tokens” 绕过**
“grep workflow-full 过了不代表文档真的清干净...~400 token 开销 / ~380 tokens 这类 stale 内容会绕过”
→ 验证：✅ 正确。[CODE] `implementation-design.md:20` “~400 tokens”, L60 “~400 tokens”, L93 “~380 tokens”, L610 “~380 tokens” — 不含 “workflow-full” 字样但同样已失真。
→ Consequence: Change 6.2 显式验收扩展——新增 `grep '~400 tokens\|380 tokens'` 零命中检查。
→ Result: accepted

**[inferred: gap-low] § #4 README.md:139 “~400 tokens” 漏出 rewrite checklist**
“目录树的 README.md:139 仍写着 workflow.md ← Universal rules (~400 tokens)”
→ 验证：✅ 正确。[CODE] README.md:139 含 `~400 tokens`。当前 checklist 有 L140（workflow-full.md 条目）、L48/L192（~400 tokens），但 L139 遗漏。
→ Consequence: Change 6.1 checklist 新增 L139。
→ Result: accepted

### Round 21

**[inferred: internal-contradiction] § #1 test-phase-guide.sh Test 7 仍用 `custom.md`——与 anti-degeneration policy 矛盾**
“test-phase-guide.sh:157 仍然在断言 BATON_PLAN=custom.md → IMPLEMENT...5.4/5.5 本来就会改这个文件...现在的计划一边说'避免锁定 arbitrary-name degeneration'，一边保留一个现成的回归在继续锁它”
→ 验证：✅ 内部矛盾。[CODE] `test-phase-guide.sh:159` `cat > “$d/custom.md”`, L168 `BATON_PLAN=custom.md`。Change 5.4/5.5 已在此文件的 write set 中。Change 4b.2 和 Risk table 建立了 “plan-custom.md 避免锁定退化” 的 policy，但同文件的既有测试未跟进。
→ Consequence: Change 5.4 附带修复——Test 7 fixture 从 `custom.md` 改为 `plan-custom.md`。
→ Result: accepted

**[inferred: scope-question] § #2 setup.sh/README 用户文案只提 `plan.md` 默认名**
“setup.sh 还在提示 .gitignore 只加 plan.md...onboarding 里多次只说 plan.md...README 的 Suggested .gitignore 也是默认名”
→ 分析：本轮修复的是 plan-*.md **发现逻辑**（bug fix），不是改变命名约定。`plan.md` 仍是默认名（`find_plan()` glob 未命中时 fallback 到 `plan.md`）。用户文案提 `plan.md` 作为默认入口是正确的——topic-named files 是高级用法，不需要在 onboarding 中强调。`.gitignore` 建议 `plan.md` 也正确（`plan-*.md` 可由用户自行添加）。
→ Result: **out of scope** — 发现逻辑修复不改变命名约定，用户文案无需变更

**[inferred: scope-question] § #3 docs/first-principles.md:474 硬编码 `mv plan.md`**
“归档流程仍然硬编码 mv plan.md / mv research.md...最新 workflow.md 已经写成泛化的 <plan-file>”
→ 分析：这是 **pre-existing 文档不一致**（first-principles 用具体名，workflow.md 用泛化名），与 workflow-full.md 废除无关。本轮不修改归档流程或命名约定。first-principles.md 写 `mv plan.md` 作为最常见用例的示例是合理的（同段 L506 已提 `BATON_PLAN=plan-auth.md` 高级用法）。
→ Result: **out of scope** — pre-existing 文档风格差异，非本轮引入

### Round 22

**[inferred: gap-contract] § #1 README.md:43 `BATON_PLAN=design.md` 是已知坏合同**
"计划自己已经把 BATON_PLAN 任意命名的 research 派生退化记进风险表...但 6.1 仍没要求改掉 README.md:43"
→ 验证：✅ 正确。[CODE] `README.md:43` `BATON_PLAN=design.md`。运行时 `${PLAN_NAME/plan/research}` [CODE] `phase-guide.sh:25` `bin/baton:140` 对 `design.md` 退化为同名。Risk table L371 已记录此风险。README 已在 write set 中，改为 `BATON_PLAN=plan-design.md` 是零成本修复。
→ Consequence: Change 6.1 rewrite checklist 新增 L43 项。
→ Result: accepted

**[inferred: architecture-question] § #2 bin/baton 为什么不复用 `_common.sh`**
"Group 4b 还是在 bin/baton 里再写一份与 _common.sh 等价的解析逻辑...同一类 drift 向量会继续存在"
→ 分析：合理关切。`_common.sh` 位于 `.baton/hooks/_common.sh`，路径相对于项目根。`bin/baton` 是全局 CLI（`~/.baton/bin/baton`），接收任意目录参数。要 source `_common.sh`，需先找到项目根——而找项目根正是 walk-up 在做的事（chicken-and-egg）。走完 walk-up 后 plan 已找到，不再需要 `_common.sh`。替代方案（如用 `.baton/` 目录作为第二锚点来先定位 `_common.sh` 再复用 `find_plan()`）引入额外复杂度且收益有限——`status()` 的 plan 发现逻辑是 ~15 行 shell，drift 风险已知但可控。
→ Consequence: Change 4b.1 新增架构决策说明段落，解释 chicken-and-egg 和为什么本地维护是当前最简方案。
→ Result: accepted — 补充了架构决策理由

**[inferred: scope-question] § #3 命名合同用户面仍漏在 surface scan 外**
"规范文件已经把 topic-named 文件写成 canonical...但安装/引导文案仍只教 plan.md / research.md"
→ 分析：与 Round 18 #1、Round 19 #2、Round 21 #2/#3 同一 scope 边界。本轮修复的是 plan-*.md **发现逻辑**（find_plan walk-up bug），不是推广命名约定。`plan.md` 作为默认名是正确的（`find_plan()` glob 未命中时 fallback 到 `plan.md`）。topic-named files（`plan-<topic>.md`）是高级用法，用户文案无需同步更新。setup.sh/test-setup.sh/first-principles.md 的面虽然只提 `plan.md`，但不与本轮改动矛盾——它们描述的是默认路径，不是唯一路径。
→ Result: **out of scope** — 第 4 次相同 scope 边界，发现逻辑修复不改变命名约定推广策略

**[inferred: meta-quality] § #4 计划证据行号漂移**
"Requirement 1 和 Annotation Log 里还在写 README.md:137-140...实际在 README.md:158-161"
→ 验证：✅ 正确。[CODE] `README.md:158-161` 是四个宿主 IDE 实际位置。计划 Requirement #1 和 Annotation Log Round 6 #2 引用了旧行号。
→ Consequence: Requirement #1 和 Annotation Log 中 `README.md:137-140` → `README.md:158-161`（2 处）。
→ Result: accepted — 行号已同步修正

## Todo

- [x] ✅ 1. Change 1.3: 重构 `_common.sh` — 删除 `extract_section()`，重构 `find_plan()`（合并名称发现到 walk-up），修复 `has_skill()` JSON_CWD，保留 `resolve_plan_name()` 为兼容 shim | Files: `.baton/hooks/_common.sh` | Verified: smoke tests pass | Deviations: none
- [x] ✅ 2. Change 1.2: 简化 `phase-guide.sh` — 版本 5.0→6.0，删除 WORKFLOW_FULL 赋值和 extract_section 调用，直接输出 hardcoded fallback，修正 `Todolist`→`todolist` 大小写 | Files: `.baton/hooks/phase-guide.sh` | Verified: test-phase-guide.sh 70/70 | Deviations: RESEARCH_NAME 移至 find_plan 之后（PLAN_NAME 现在由 find_plan 设置而非 resolve_plan_name）
- [x] ✅ 3. Change 1.1: 删除 `workflow-full.md` | Files: `.baton/workflow-full.md` | Verified: 文件不存在 | Deviations: none
- [x] ✅ 4. Change 2.1: Authority 上移到 `workflow.md` — 新增 Document Authority 段落，更新 Enforcement Boundaries fallback 描述 | Files: `.baton/workflow.md` | Verified: test-workflow-consistency.sh ALL CONSISTENT | Deviations: none
- [x] ✅ 5. Change 3.1: Fork context 自足 — 改写 baton-research SKILL.md L217-218 委托句，内联 3 条 cross-cutting rules | Files: `.claude/skills/baton-research/SKILL.md` | Verified: test-annotation-protocol.sh Group 3 pass | Deviations: 子代理权限不足，主会话直接完成
- [x] ✅ 6. Change 4.1: 清理 `setup.sh` — 删除 workflow-full.md self-install 消息和 cp 安装步骤，保留旧引用迁移代码 | Files: `setup.sh` | Verified: test-setup.sh 176/176 | Deviations: none
- [x] ✅ 7. Change 4b.1: 修复 `bin/baton` — status() walk-up 产出 _pname+_pdir，doctor() 收紧正则 + 新增 AGENTS.md 检查 | Files: `bin/baton` | Verified: test-cli.sh 25/25 | Deviations: none
- [x] ✅ 8. Change 5.1: 重构 `test-workflow-consistency.sh` — DELETE FULL 引用段，MODIFY 移除 FULL 半边，反转 Document Authority 守卫 | Files: `tests/test-workflow-consistency.sh` | Verified: ALL CONSISTENT | Deviations: none
- [x] ✅ 9. Change 5.2: 重构 `test-annotation-protocol.sh` — DELETE FULL 引用，MIGRATE 到 PLAN_SKILL/RESEARCH_SKILL 双侧，新增 Group 3 自足性守卫 | Files: `tests/test-annotation-protocol.sh` | Verified: 30/30 | Deviations: none
- [x] ✅ 10. Change 5.3: 更新 `test-setup.sh` — 删除 workflow-full.md 存在断言，新增负向断言 + 版本升级回归 + import 迁移回归 | Files: `tests/test-setup.sh` | Verified: 176/176 | Deviations: none
- [x] ✅ 11. Change 5.4+5.5: 更新 `test-phase-guide.sh` — 删除 8 个 extract_section 断言，新增 Test 18（plan-*.md walk-up），Test 7 重排序 | Files: `tests/test-phase-guide.sh` | Verified: 70/70 | Deviations: Test 7 改为先测 RESEARCH 再创建 plan-custom.md（因 find_plan glob 会发现它）
- [x] ✅ 12. Change 5.6: 新增 `test-write-lock.sh` Test 17 JSON_CWD + plan-*.md 回归测试 | Files: `tests/test-write-lock.sh` | Verified: 38/39（1 pre-existing benchmark） | Deviations: 重编号 Test 17→18, Test 18→20 避免冲突
- [x] ✅ 13. Change 5.7: 新增 `test-stop-guard.sh` Test 8 plan-*.md 子目录回归测试 | Files: `tests/test-stop-guard.sh` | Verified: 26/26 | Deviations: 重编号 Test 8→9, Test 9→10
- [x] ✅ 14. Change 5.8: 新增 `test-new-hooks.sh` Test 15 completion-check plan-*.md 子目录回归测试 | Files: `tests/test-new-hooks.sh` | Verified: 22/22 | Deviations: 使用 assert_exit_code 替代手动 capture（修复 set -e 兼容性）
- [x] ✅ 15. Change 4b.2: 新增 `test-cli.sh` Tests 12-14 plan-*.md + BATON_PLAN + doctor 回归测试 | Files: `tests/test-cli.sh` | Verified: 25/25 | Deviations: 编号 9/10/11→12/13/14 避免冲突；Test 14 “correct import” 断言改为 narrow grep（doctor 在无脚本环境报非零 issues）
- [x] ✅ 16. Change 6.1: 更新 `README.md` — 删除 workflow-full.md 条目，修复 BATON_PLAN 示例，更新架构描述 | Files: `README.md` | Verified: 零 workflow-full.md / design.md / extraction 残留 | Deviations: none
- [x] ✅ 17. Change 6.3: 更新 `docs/stable-surface.md` — L39 fallback 描述与 workflow.md 同步 | Files: `docs/stable-surface.md` | Verified: 措辞一致 | Deviations: none
- [x] ✅ 18. Change 6.2: 重写 `docs/implementation-design.md` — 删除 workflow-full.md 叙述，更新为两层模型 | Files: `docs/implementation-design.md` | Verified: 零 workflow-full.md（migration 除外）/ ~400 tokens / 380 tokens 残留 | Deviations: none
- [x] ✅ 19. 全量回归: `bash tests/test-full.sh` 全部通过 | Verified: 10/11 suites pass, 唯一失败为 pre-existing write-lock benchmark (Windows latency) | Deviations: none — 无新增失败

## Retrospective

### What the plan got wrong

1. **Test 14 assertion design**: The plan specified `test-cli.sh` doctor should check `"all checks passed"` but the test environment only creates CLAUDE.md — no hook scripts. Doctor correctly reports 8 missing scripts. The assertion needed to narrow to the Rules injection section, not the overall result. Caught during full regression.

2. **Test 7 (phase-guide) interaction with find_plan() glob**: The plan didn't anticipate that `plan-custom.md` matches the new `plan-*.md` glob in `find_plan()`. The test created the fixture before running the "no plan → RESEARCH" assertion, so find_plan() discovered it. Fix: reorder test to assert RESEARCH before creating the file.

3. **Test 15 (test-new-hooks) set -e interaction**: The plan didn't account for `set -euo pipefail` at the test file level causing script termination when `completion-check.sh` exits with code 2. Fix: use the existing `assert_exit_code` helper which handles non-zero exits via `|| actual=$?`.

4. **Subagent permissions for SKILL.md edit**: Todo #5 (baton-research fork-context self-sufficiency) was delegated to a background agent that lacked Edit permissions. Had to complete in the main conversation.

### What surprised during implementation

- The find_plan() glob change had wider blast radius than expected — any test fixture named `plan-*.md` became discoverable, requiring careful test ordering.
- Test renumbering cascaded across 4 test files (write-lock, stop-guard, new-hooks, cli) to avoid collisions with new tests.
- The `bin/baton` status() walk-up was more complex than a simple loop — it needed to produce both `_pname` and `_pdir` for the paired research file derivation.

### What to research differently next time

- When refactoring a function that uses glob patterns (like find_plan with `plan-*.md`), explicitly enumerate all test fixtures that match the new pattern. The plan should have included a grep for `plan-*.md` and `plan-custom` across test files.
- For test files with `set -e`, always verify that new test patterns handle non-zero exit codes correctly before delegating to agents.

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI “generate todolist” -->
<!-- BATON:GO -->
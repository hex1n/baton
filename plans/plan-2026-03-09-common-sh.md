# Plan: Baton 技术债清理 — _common.sh 抽取 + CI 全覆盖 + Skills 增强

## Requirements

来源: research.md Final Conclusions (Round 1 批注循环确认)

1. **SYNCED 代码抽取到 _common.sh** — 9 个文件的重复 plan-name-resolution + find_plan 统一到一处。范围扩大至 has_skill()、extract_section() 等公共逻辑。(Research § 一 + Human requirement: "公共逻辑一起抽取")
2. **CI 全覆盖** — 所有 13 个测试加入 CI + 所有 8 个 hook 加入 shellcheck。(Research § 二 + Human requirement: "全覆盖")
3. **Skills 自检增强** — 强化 baton-research 和 baton-plan 的退出前自检清单。(Human requirement: "强化 baton-research 自检 增强 / 强化 baton-plan 自检 增强")

## Constraints

1. **POSIX sh 兼容** — 所有 hook 使用 `#!/bin/sh`，`_common.sh` 也必须 POSIX。使用 `.` 而非 `source`
2. **独立可调试** — hook 加 `_common.sh` 后仍可单独运行测试。`_common.sh` 体量小（~40 行）
3. **Fail-open 不变** — `_common.sh` 加载失败时 hook 应 fail-open（exit 0），不应阻止工作
4. **向后兼容** — 已安装项目升级时 setup.sh 需安装 `_common.sh`
5. **JSON_CWD 统一** — write-lock.sh 的 `JSON_CWD` 支持应成为统一行为，其他 hook fallback 到 `$(pwd)`

## Complexity

**Large** — 影响 8 个 hook + pre-commit + setup.sh + ci.yml + 2 个 skill + 测试

## Approach Analysis

### 方案 A：_common.sh 作为 sourced library（推荐）

创建 `.baton/hooks/_common.sh`，所有 hook 通过 `. "$SCRIPT_DIR/_common.sh"` 引入。

- **Feasibility**: ✅ 可行 — phase-guide.sh:13 已有 `SCRIPT_DIR` 模式，且 setup.sh:652 用 `cp` 复制 hook（非 symlink），worktree 安全
- **Pros**: 单点维护 plan 解析逻辑、消除 3 类不一致（函数/内联/压缩）、~40 行公共代码
- **Cons**: hook 不再完全独立（但 _common.sh 很小）
- **Impact**: 8 hook + pre-commit 修改，setup.sh 安装，test-workflow-consistency.sh 验证策略改变

### 方案 B：每个 hook 内联但用 sync 脚本自动同步

写一个 `sync-hooks.sh` 脚本，从模板生成每个 hook 的 SYNCED 块。

- **Feasibility**: ⚠️ 风险 — 增加构建步骤，CI 需要先运行 sync 再测试
- **Ruled out**: 增加复杂度但不消除根本问题（仍有 9 个副本）

**推荐方案 A**。

## Surface Scan

### L1 — 直接引用（_common.sh 抽取）

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| .baton/hooks/_common.sh | L1 | **new** | 新文件：resolve_plan_name + find_plan + has_skill + extract_section |
| .baton/hooks/write-lock.sh | L1 | modify | 删除 SYNCED 块 (:61-79)，source _common.sh |
| .baton/hooks/phase-guide.sh | L1 | modify | 删除 SYNCED 块 (:58-75) + has_skill() (:17-29) + extract_section() (:31-54)，source _common.sh |
| .baton/hooks/stop-guard.sh | L1 | modify | 删除 SYNCED 块 (:15-30)，source _common.sh |
| .baton/hooks/bash-guard.sh | L1 | modify | 删除 SYNCED 块 (:10-23)，source _common.sh |
| .baton/hooks/post-write-tracker.sh | L1 | modify | 删除 SYNCED 块 (:42-56)，source _common.sh |
| .baton/hooks/completion-check.sh | L1 | modify | 删除 SYNCED 块 (:18-32)，source _common.sh |
| .baton/hooks/pre-compact.sh | L1 | modify | 删除 SYNCED 块 (:17-31)，source _common.sh |
| .baton/hooks/subagent-context.sh | L1 | modify | 删除 SYNCED 块 (:17-31)，source _common.sh |
| .baton/git-hooks/pre-commit | L1 | modify | 删除 SYNCED 块 (:20-34)，source _common.sh |

### L2 — 依赖追踪

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| setup.sh | L2 | modify | install_versioned_script 需包含 _common.sh |
| tests/test-workflow-consistency.sh | L2 | modify | 验证策略从"提取 while 循环对比"改为"检查 source _common.sh" |
| .github/workflows/ci.yml | L2 | modify | 加入 7 个测试 + 4 个 shellcheck + _common.sh shellcheck |
| .claude/skills/baton-research/SKILL.md | L2 | modify | 增强退出前自检清单 |
| .claude/skills/baton-plan/SKILL.md | L2 | modify | 增强退出前自检清单 |

### L2 — 测试验证（不修改源码，运行验证）

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| tests/test-write-lock.sh | L2 | verify | write-lock.sh 变更的下游测试 |
| tests/test-phase-guide.sh | L2 | verify | phase-guide.sh 变更的下游测试 |
| tests/test-stop-guard.sh | L2 | verify | stop-guard.sh 变更的下游测试 |
| tests/test-setup.sh | L2 | verify | setup.sh 变更的下游测试 |
| tests/test-pre-commit.sh | L2 | verify | pre-commit 变更的下游测试 |
| tests/test-new-hooks.sh | L2 | verify | 新 hook 的下游测试 |

### Skip

| File | Disposition | Reason |
|------|-------------|--------|
| .baton/workflow.md | skip | 不含 SYNCED 代码，不需要修改 |
| .baton/workflow-full.md | skip | 已在前序工作中更新 Surface Scan/cascading defense |
| .claude/skills/baton-implement/SKILL.md | skip | 已在前序工作中充分强化 |
| README.md | skip | 不受本次变更影响 |
| plans/*.md | skip | 历史归档 |

## Change List

### Change 1：创建 _common.sh

**What**: 新建 `.baton/hooks/_common.sh`，包含 4 个函数：
- `resolve_plan_name` — BATON_PLAN 环境变量 → glob fallback → 默认 plan.md
- `find_plan` — 从指定目录向上查找 $PLAN_NAME，支持 JSON_CWD
- `has_skill` — 在 .claude/.cursor/.agents 中查找 SKILL.md
- `extract_section` — 从 markdown 文件提取指定 section

**Why**: 消除 9 文件 SYNCED 代码复制（research § 一），统一 JSON_CWD 支持

**Design**:
```sh
#!/bin/sh
# _common.sh — shared functions for baton hooks
# Sourced by all hooks: . "$SCRIPT_DIR/_common.sh"

resolve_plan_name() { ... }   # sets PLAN_NAME
find_plan() { ... }            # sets PLAN, accepts optional start dir
has_skill() { ... }            # returns 0/1
extract_section() { ... }      # extracts markdown section
```

每个 hook 需要在 source 前定义 `SCRIPT_DIR`，然后 `. "$SCRIPT_DIR/_common.sh"`。

### Change 2：迁移 8 个 hook + pre-commit

**What**: 删除每个文件的 SYNCED 块，替换为 `. "$SCRIPT_DIR/_common.sh"`

**Impact**: 每个文件减少 ~15 行，增加 ~3 行（SCRIPT_DIR 定义 + source + 调用）

**Risk**: source 失败时需 fail-open。缓解：

```sh
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    exit 0  # fail-open
fi
```

### Change 3：更新 setup.sh

**What**: `install_versioned_script` 增加 `_common.sh` 安装

**Impact**: setup.sh 仅增加 ~2 行

### Change 4：更新 test-workflow-consistency.sh

**What**: 验证策略从"提取 while 循环对比核心元素"改为：
1. 检查 `_common.sh` 定义了 `resolve_plan_name` + `find_plan` + `has_skill`
2. 检查所有 8 hook + pre-commit 都 source `_common.sh`
3. 检查没有 hook 还残留 `SYNCED:` 注释

**Why**: 比当前策略更简单、更可靠（research § 一.2）

### Change 5：CI 全覆盖

**What**: 修改 `.github/workflows/ci.yml`：
- 添加 shellcheck：post-write-tracker.sh, completion-check.sh, pre-compact.sh, subagent-context.sh, _common.sh
- 添加测试：test-multi-ide, test-pre-commit, test-annotation-protocol, test-cli, test-new-hooks, test-ide-capability-consistency, test-adapters-v2

**Why**: 7/13 测试不在 CI（research § 二），4/8 hook 无 shellcheck

### Change 6：Skills Pre-Exit Checklist

**Design principle**: Each item must (a) not duplicate existing skill steps, (b) target a documented failure mode, (c) be self-explanatory about why it exists.

**What**:

baton-research SKILL.md — add Pre-Exit Checklist before Exit Criteria:
```
### Pre-Exit Checklist

Before presenting research.md to the human, verify:

1. **Tool breadth** — At least 2 distinct search methods used beyond Read
   (e.g., Grep + Glob, or Grep + subagent). Recorded in Tool Inventory.
   _Prevents: tunnel vision from single-tool investigation_

2. **Conclusion resilience** — Each major conclusion states what evidence
   would disprove it, and whether that evidence was found or searched for.
   _Prevents: confirmation bias — finding what you expect instead of what exists_

3. **Single source of truth** — Final Conclusions section exists. Each
   conclusion references its evidence location in the body. No body-section
   conclusion contradicts Final Conclusions.
   _Prevents: stale conclusions surviving across annotation rounds_
```

baton-plan SKILL.md — add Pre-Exit Checklist before Output Template:
```
### Pre-Exit Checklist

Before presenting plan.md to the human, verify:

1. **Requirement traceability** — Every requirement in `## Requirements`
   has a source: research section reference or "Human requirement (chat/annotation)".
   _Prevents: plans that drift from what was actually researched or requested_

2. **Test-layer coverage in Surface Scan** — For each L1 file being modified,
   asked: "which test file exercises this?" If one exists, it appears in the
   disposition table as L2.
   _Prevents: downstream test breakage going unplanned (e.g., test-phase-guide.sh omission)_

3. **Skip decisions challenged** — Each "skip" entry answers: "if this file
   is NOT updated, what will the user experience?"
   _Prevents: silent stale behavior in untouched files_

4. **Change specs grounded in reads** — Every file in the change list was
   read in this session before writing its change specification.
   _Prevents: scope underestimation from assuming file content (e.g., test-adapters.sh)_

5. **Optimal solution, not just a solution** — For each proposed change,
   asked: "is this the best answer to the underlying problem?" before
   asking "is this implementation correct?"
   _Prevents: jumping to implementation before validating the approach itself_
```

**Why**: Retrospective-driven. Each item traces to a documented failure from IDE simplification:
- #1 → requirements without attribution caused confusion about scope source
- #2 → phase-guide.sh modified but test-phase-guide.sh not in Surface Scan L2
- #3 → Surface Scan "skip" items not challenged, stale behavior possible
- #4 → test-adapters.sh assumed to contain "only opencode tests", was entirely Cline tests
- #5 → v1 checklist jumped to "what items should it have" before asking "is a redundant checklist the optimal way to strengthen skills"

**First version problems → how this version fixes them**:

| Problem | Example | Fix |
|---------|---------|-----|
| 9/12 items duplicated existing skill steps | "Self-Review written", "批注区 present" already in Step 5 and Output Template | Removed all duplicates. Every item now covers something the skill steps don't enforce |
| Incident-patching: copied specific failure details as checklist items | "grep patterns, word boundaries" taken verbatim from one retrospective | Generalized to principle: "Change specs grounded in reads" covers grep false positives, content assumptions, and any future "didn't look before writing" failure |
| Phase misplacement: plan checklist contained implement-phase concerns | "Verification commands tested for false positives" is an implement-time activity | Removed. Plan checklist now only checks plan artifact quality, not implementation execution |
| Checklist items lacked self-explanation | Items said WHAT to check but not WHY it matters | Each item now has `_Prevents:_` rationale linking to a documented failure mode |

## Self-Review

### Internal Consistency Check

- ✅ 推荐方案 A（_common.sh sourced library），变更清单全部是抽取/source 操作，一致
- ✅ 每个变更追溯到研究发现：变更 1-2→§ 一，变更 3→§ 四，变更 4→§ 一.2，变更 5→§ 二，变更 6→Human requirement
- ✅ Surface Scan 中所有 "modify" 文件都出现在变更清单中
- ✅ Surface Scan 中所有 "new" 文件（_common.sh）出现在变更 1 中
- ✅ Surface Scan "skip" 文件都有显式理由

### External Risks

1. **最大风险**: `_common.sh` source 路径在测试环境中可能与生产环境不同 — 测试通过临时目录运行 hook，`$0` 可能指向不同位置。**缓解**: test-write-lock.sh 等已有类似模式（cp hook 到临时目录），_common.sh 需要一起复制。
2. **可能完全错误**: 如果某个 hook 的 SYNCED 代码有微妙的本地定制（不只是格式差异），抽取会引入行为变更。**缓解**: research § 一.2 已逐文件对比，确认只有 3 类差异（函数/内联/压缩），语义等价。
3. **被拒绝的方案**: 方案 B（sync 脚本自动同步）— 增加构建步骤复杂度但不消除根本问题。

## Todo

### Batch 1 — _common.sh 创建（无依赖）

- [x] ✅ 1. Change: 创建 `.baton/hooks/_common.sh`，包含 resolve_plan_name + find_plan + has_skill + extract_section 四个函数 | Files: .baton/hooks/_common.sh (new) | Verify: `sh -n .baton/hooks/_common.sh` 语法检查通过 + shellcheck 通过 | Deps: none | Artifacts: none

### Batch 2 — Hook 迁移 + setup.sh（依赖 #1）

- [x] ✅ 2. Change: write-lock.sh 删除 SYNCED 块，source _common.sh，保留 find_plan 函数调用（JSON_CWD 支持） | Files: .baton/hooks/write-lock.sh | Verify: `bash tests/test-write-lock.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 3. Change: phase-guide.sh 删除 SYNCED 块 + has_skill() + extract_section()，source _common.sh | Files: .baton/hooks/phase-guide.sh | Verify: `bash tests/test-phase-guide.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 4. Change: stop-guard.sh 删除 SYNCED 块，source _common.sh | Files: .baton/hooks/stop-guard.sh | Verify: `bash tests/test-stop-guard.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 5. Change: bash-guard.sh 删除 SYNCED 块（含单行压缩格式），source _common.sh | Files: .baton/hooks/bash-guard.sh | Verify: `sh -n .baton/hooks/bash-guard.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 6. Change: post-write-tracker.sh 删除 SYNCED 块，source _common.sh | Files: .baton/hooks/post-write-tracker.sh | Verify: `sh -n .baton/hooks/post-write-tracker.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 7. Change: completion-check.sh 删除 SYNCED 块，source _common.sh | Files: .baton/hooks/completion-check.sh | Verify: `sh -n .baton/hooks/completion-check.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 8. Change: pre-compact.sh 删除 SYNCED 块，source _common.sh | Files: .baton/hooks/pre-compact.sh | Verify: `sh -n .baton/hooks/pre-compact.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 9. Change: subagent-context.sh 删除 SYNCED 块，source _common.sh | Files: .baton/hooks/subagent-context.sh | Verify: `sh -n .baton/hooks/subagent-context.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 10. Change: pre-commit 删除 SYNCED 块，source _common.sh | Files: .baton/git-hooks/pre-commit, tests/test-pre-commit.sh (setup_repo needs _common.sh copy) | Verify: `bash tests/test-pre-commit.sh` 通过 | Deps: #1 | Artifacts: none
- [x] ✅ 11. Change: setup.sh 的 install_versioned_script 增加 _common.sh 安装 | Files: setup.sh | Verify: `bash tests/test-setup.sh` 通过 | Deps: #1 | Artifacts: none

### Batch 3 — 测试更新（依赖 #2-11）

- [x] ✅ 12. Change: test-workflow-consistency.sh 重写验证策略 — 检查 _common.sh 定义函数 + 所有 hook source 它 + 无残留 SYNCED 注释 | Files: tests/test-workflow-consistency.sh | Verify: `bash tests/test-workflow-consistency.sh` 通过 | Deps: #2-10 | Artifacts: none

### Batch 4 — CI 全覆盖（依赖 #1-12）

- [x] ✅ 13. Change: ci.yml 添加 5 个 shellcheck（_common.sh + post-write-tracker + completion-check + pre-compact + subagent-context）+ 7 个测试 job（test-multi-ide + test-pre-commit + test-annotation-protocol + test-cli + test-new-hooks + test-ide-capability-consistency + test-adapters-v2） | Files: .github/workflows/ci.yml | Verify: YAML 语法正确 + 所有测试本地运行通过 | Deps: #12 | Artifacts: none

### Batch 5 — Skills 增强（独立，可与 Batch 1-4 并行）

- [x] ✅ 14. Change: baton-research SKILL.md 添加 Pre-Exit Checklist（3 项：tool breadth / conclusion resilience / single source of truth） | Files: .claude/skills/baton-research/SKILL.md | Verify: 目视确认 checklist 在 Exit Criteria 之前，每项有 _Prevents:_ | Deps: none | Artifacts: none
- [x] ✅ 15. Change: baton-plan SKILL.md 添加 Pre-Exit Checklist（5 项：requirement traceability / test-layer L2 / skip challenge / reads not assumptions / optimal solution） | Files: .claude/skills/baton-plan/SKILL.md | Verify: 目视确认 checklist 在 Output Template 之前，每项有 _Prevents:_ | Deps: none | Artifacts: none

### Batch 6 — 全量验证

- [x] ✅ 16. Change: 运行完整测试套件 | Files: none (只读) | Verify: 所有 13 个 test-*.sh 通过 | Deps: #1-15 | Artifacts: none

### 全量测试结果

13/13 通过：test-adapters-v2, test-adapters, test-annotation-protocol, test-cli, test-ide-capability-consistency, test-multi-ide, test-new-hooks, test-phase-guide, test-pre-commit, test-setup, test-stop-guard, test-workflow-consistency, test-write-lock

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

## Annotation Log

### Round 1

**[inferred: scope-addition] § Change 6 baton-plan Pre-Exit Checklist**
"baton-plan SKILL.md 还需要自检 需求 和 来源"
→ 已添加两项：`## Requirements` 存在且标注来源 + 方案推导追溯到研究发现
→ Consequence: no direction change, checklist 增加 2 项
→ Result: accepted


### Round 2

**[inferred: style-requirement] § Change 6 Pre-Exit Checklist**
"增强的skill保持统一使用英文"
→ Pre-Exit Checklist content translated to English to match existing SKILL.md language
→ Consequence: no direction change, presentation only
→ Result: accepted

### Round 3

**[inferred: quality-critique] § Change 6 Pre-Exit Checklist**
"自检的内容是最佳状态了吗?" + "类似这样的字眼太死了" + "还需要改进你一版方案粗糙的情况"
→ 根本性重写 Change 6：
  - 删除全部 12 项重复/事故补丁/阶段错位的检查
  - Research checklist: 3 项原则（tool breadth / conclusion resilience / single source of truth）
  - Plan checklist: 4 项原则（requirement traceability / test-layer L2 / skip challenge / reads not assumptions）
  - 每项附 _Prevents:_ 说明，链接到真实失败模式
  - 记录第一版失败分析（为什么重复不等于强化）
→ Consequence: Change 6 scope reduced from 12 items to 7, quality significantly improved
→ Result: accepted

### Round 4

**[inferred: principle-elevation] § Change 6 baton-plan item #5**
"对每一项改进/方案做最根本性的追问 不是这样实现对不对 而是这个问题的最优解是什么"
→ 替换原提议的 "new content derived from evidence"（枚举了 checklist/模板/文档等具体场景，太死）
→ 提升为通用原则：#5 "Optimal solution, not just a solution" — 先问"是不是最优解"再问"实现对不对"
→ 根因：v1 checklist 失败本质是跳过了"这是不是最优方式"直接进入"该有哪些条目"
→ Consequence: baton-plan checklist 从 4 项增至 5 项
→ Result: accepted

<!-- BATON:GO -->

## Retrospective

### 计划判断正确的部分
- _common.sh 设计：4 函数 ~60 行，POSIX sh 兼容，每个 hook 迁移只需 ~6 行替换 ~15 行 — 完全符合预期
- Batch 分层正确：Batch 1→2→3→4 的依赖链清晰，Batch 5 独立并行无冲突
- fail-open 模式：所有 hook 在 _common.sh 缺失时正确 exit 0
- JSON_CWD 统一：write-lock.sh 的 JSON_CWD 支持自动扩展到所有 hook

### 计划判断错误的部分
1. **Surface Scan 遗漏 3 个测试文件**：test-pre-commit.sh、test-adapters.sh、test-adapters-v2.sh 被标为 L2 "verify" 但实际需要 "modify"。这 3 个测试的 setup 函数复制 hook 到临时目录，缺少 _common.sh 则 fail-open 导致 deny→allow 反转。教训：当代码引入新的外部依赖（_common.sh），所有复制该代码的测试 setup 都需要同步复制新依赖
2. **pre-commit hook 路径假设错误**：最初使用 `SCRIPT_DIR` 相对路径查找 _common.sh，但 pre-commit 从 `.git/hooks/` 运行而 _common.sh 在 `.baton/hooks/`。改为 `$(pwd)/.baton/hooks/_common.sh`（git 保证从 repo root 运行 pre-commit）
3. **Batch 5 子代理权限失败**：Skills enhancement 子代理被拒绝 Edit/Bash 权限，最终由主进程完成

### 实施中的意外
- shellcheck SC2034 false positive：_common.sh 中 `PLAN` 被 shellcheck 标记为未使用（实际由 caller 使用），需要 disable 注释且必须放在函数定义行前（不是赋值行前）
- setup.sh 中 _common.sh 不需要版本管理：它无 `# Version:` 头，直接 cp 覆盖即可（不走 install_versioned_script）

### 下次研究改进点
- Surface Scan 时应对每个 L2 "verify" 文件追问：该测试是否**复制**了被修改的文件？如果是，它的 setup 函数需要同步更新
- pre-commit hook 的特殊性（运行位置 ≠ 源码位置）应在研究阶段显式标注

1. plan的skill 对每一项改进/方案做最根本性的追问 不是这样实现对不对 而是这个问题的最优解是什么 这段放在做计划前还是做完计划后呢?

## Annotation Log (Retrospective)

### Round 5

**[inferred: placement-question] § Pre-Exit Checklist #5 位置**
"plan的skill 对每一项改进/方案做最根本性的追问...这段放在做计划前还是做完计划后呢?"
→ 分析：当前 SKILL.md 已有两层覆盖 —
  - Step 4 (SKILL.md:108) "optimal choice given the constraints" 覆盖**方案级**最优（做计划时）
  - Pre-Exit #5 (SKILL.md:272) "Optimal solution, not just a solution" 覆盖**变更级**最优（做完计划后验证）
→ Pre-Exit 是正确位置，因为：(1) 变更只在写完 Change List 后才存在，Step 3-4 阶段无法验证具体变更形态；(2) 防止的失败模式是"写着写着忘了追问"而非"不知道要追问"；(3) 本次 v1 checklist 失败恰好发生在变更级 — 方案没错但具体形态（12 条冗余）未经最优性追问
→ Consequence: no change — Pre-Exit Checklist 位置确认正确
→ Result: accepted, placement validated
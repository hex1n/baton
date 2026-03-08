# 重新研究：Baton 技术债清理（IDE 精简后）

> 来源：plans/plan-2026-03-08-baton-annotation-harness-draft.md 的重新评估
> 前置条件：IDE 精简已完成（11→4），skills 已纳入版本控制

## 研究工具清单

| 工具 | 用途 | 结果 |
|------|------|------|
| Grep | SYNCED 标记搜索、CI 配置分析 | 定位 9 个文件 |
| Read | ci.yml、test-workflow-consistency.sh 完整阅读 | CI 覆盖缺口 |
| Explore subagent | 9 个文件的 SYNCED 代码块逐行对比 | 发现 3 类不一致 |
| Glob | 测试文件列表 | 13 个测试文件 vs CI 6 个 |

## 一、SYNCED 代码复制现状

9 个文件包含相同的 plan-name-resolution + find_plan 逻辑：

### 1.1 plan-name-resolution 块（完全一致）

所有 9 个文件的 plan-name-resolution 块完全相同：

```sh
# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
```

| 文件 | 起始行 |
|------|--------|
| write-lock.sh | :61 |
| phase-guide.sh | :58 |
| bash-guard.sh | :10 |
| stop-guard.sh | :15 |
| post-write-tracker.sh | :42 |
| completion-check.sh | :18 |
| pre-compact.sh | :17 |
| subagent-context.sh | :17 |
| pre-commit | :20 |

### 1.2 find_plan 块（存在 3 类不一致）

**类型 A：函数式 + JSON_CWD**（仅 write-lock.sh）
```sh
find_plan() {
    d="${JSON_CWD:-$(pwd)}"      # ← 唯一支持 JSON_CWD
    while true; do
        [ -f "$d/$PLAN_NAME" ] && { echo "$d/$PLAN_NAME"; return; }
        p="$(dirname "$d")"
        [ "$p" = "$d" ] && return
        d="$p"
    done
}
```
证据：write-lock.sh:69-79

**类型 B：内联式，多行格式**（7 个文件）
```sh
PLAN=""
d="$(pwd)"                       # ← 不支持 JSON_CWD
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done
```
证据：phase-guide.sh:67-75, stop-guard.sh:22-30, post-write-tracker.sh:49-56, completion-check.sh:25-32, pre-compact.sh:24-31, subagent-context.sh:24-31, pre-commit:27-34

**类型 C：内联式，单行压缩**（仅 bash-guard.sh）
```sh
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"; [ "$p" = "$d" ] && break; d="$p"    # ← 压缩为单行
done
```
证据：bash-guard.sh:17-23

### 1.3 风险评估

- ❌ **JSON_CWD 不一致** — write-lock.sh 通过 `JSON_CWD` 支持 hook 传入的工作目录，其他 8 个文件硬编码 `$(pwd)`。如果 IDE hook 在非项目目录执行，只有 write-lock.sh 能正确找到 plan.md。
- ❌ **test-workflow-consistency.sh 只验证 4/9** — 只检查 write-lock.sh、phase-guide.sh、stop-guard.sh、bash-guard.sh（:56-83）。post-write-tracker.sh、completion-check.sh、pre-compact.sh、subagent-context.sh、pre-commit 完全不在验证范围。
- ⚠️ **bash-guard.sh 格式差异** — 语义等价但不利于 diff 维护。

### 1.4 反例搜索

> "如果 SYNCED 代码有 bug，哪些测试会暴露？"

| 文件 | 有专门测试？ | 测试验证 find_plan？ |
|------|-------------|-------------------|
| write-lock.sh | ✅ test-write-lock.sh (37 tests) | ✅ 测试 plan 查找行为 |
| phase-guide.sh | ✅ test-phase-guide.sh (76 tests) | ✅ 测试 plan 查找 |
| stop-guard.sh | ✅ test-stop-guard.sh (25 tests) | ❓ 未验证 |
| bash-guard.sh | ❌ 无专门测试 | ❌ |
| post-write-tracker.sh | ❌ 无专门测试 | ❌ |
| completion-check.sh | ❌ 无专门测试 | ❌ |
| pre-compact.sh | ❌ 无专门测试 | ❌ |
| subagent-context.sh | ❌ 无专门测试 | ❌ |
| pre-commit | ✅ test-pre-commit.sh (但不在 CI) | ❓ 未验证 |

结论：9 个文件中只有 2 个的 find_plan 行为有测试覆盖。

## 二、CI 覆盖缺口

### 2.1 Shellcheck 覆盖

| 文件 | CI shellcheck | 行数 |
|------|--------------|------|
| write-lock.sh | ✅ ci.yml:17 | ~100 |
| phase-guide.sh | ✅ ci.yml:19 | ~180 |
| bash-guard.sh | ✅ ci.yml:21 | ~30 |
| stop-guard.sh | ✅ ci.yml:23 | ~70 |
| post-write-tracker.sh | ❌ | ~60 |
| completion-check.sh | ❌ | ~40 |
| pre-compact.sh | ❌ | ~30 |
| subagent-context.sh | ❌ | ~40 |
| adapter-cursor.sh | ✅ ci.yml:25 | ~20 |
| setup.sh | ✅ ci.yml:27 | ~1000 |

4/8 hooks 不在 shellcheck 覆盖范围。

### 2.2 测试覆盖

| 测试文件 | 在 CI 中？ | 测试数 |
|----------|-----------|--------|
| test-write-lock.sh | ✅ ci.yml:29 | 37 |
| test-phase-guide.sh | ✅ ci.yml:39 | 76 |
| test-setup.sh | ✅ ci.yml:46 | 148 |
| test-stop-guard.sh | ✅ ci.yml:56 | 25 |
| test-adapters.sh | ✅ ci.yml:63 | 3 |
| test-workflow-consistency.sh | ✅ ci.yml:70 | ~60 checks |
| test-multi-ide.sh | ❌ | 18 |
| test-pre-commit.sh | ❌ | ~15 |
| test-annotation-protocol.sh | ❌ | ~10 |
| test-cli.sh | ❌ | 14 |
| test-new-hooks.sh | ❌ | 20 |
| test-ide-capability-consistency.sh | ❌ | 20 |
| test-adapters-v2.sh | ❌ | 3 |

6/13 测试文件在 CI 中，7 个不在。

### 2.3 反例搜索

> "不在 CI 中的测试是否会因为回归而悄悄失败？"

刚完成的 IDE 精简就证明了这个风险：test-phase-guide.sh Test 18（.amazonq）在 CI 中运行，所以如果它没被修复就会被 CI 拦截。但如果同样的问题出现在 test-multi-ide.sh 中，它不在 CI 中，回归就不会被发现。

## 三、旧计划项状态评估

| 旧计划项 | 当前状态 | 仍需实施？ |
|----------|---------|-----------|
| 变更 1：抽取 `_common.sh` | ❌ 未实施，9 个文件仍有 SYNCED 代码 | ✅ 是 — 最高优先级 |
| 变更 2：修复 OpenCode glob | ✅ 已过时 — opencode-plugin.mjs 已删除 | ❌ 不需要 |
| 变更 3a：CI shellcheck 修复 | ✅ 已完成 — adapter-windsurf.sh 引用已修正 | ❌ 不需要 |
| 变更 3b：test-multi-ide.sh 加入 CI | ❌ 未实施 | ✅ 是 |
| 变更 3c：test-pre-commit.sh 加入 CI | ❌ 未实施 | ✅ 是 |
| 方案 D #8：强化 baton-research 自检 | ✅ 已有 Exit Criteria + Self-Review + Convergence Check | ⚠️ 可选增强 |
| 方案 D #9：强化 baton-plan 自检 | ✅ 已有 Pre-Todo Consistency Check + Self-Review + Surface Scan | ⚠️ 可选增强 |
| 方案 D #10：强化 baton-implement 自检 | ✅ 已有 8 项 Self-Check Triggers + cascading defense | ❌ 已足够 |
| Todo #11：同步 .agents/skills/ | ❌ .agents/skills/ 目录不存在 | ✅ 是（setup.sh 生成，但源码库中无预置） |

## 四、_common.sh 抽取的技术分析

### 4.1 需要抽取的逻辑

两个函数：
1. **resolve_plan_name** — `BATON_PLAN` 环境变量 → glob fallback → 默认 plan.md（6 行）
2. **find_plan** — 从当前目录向上查找 `$PLAN_NAME`（8 行）

### 4.2 设计约束

- **POSIX sh 兼容** — 所有 hook 使用 `#!/bin/sh`，不能用 bash-only 语法
- **source 路径** — hook 通过 `. "$SCRIPT_DIR/_common.sh"` 引用，`SCRIPT_DIR` 需要在每个 hook 中定义
- **JSON_CWD** — write-lock.sh 需要 JSON_CWD 支持。统一后所有 hook 都应支持，但其他 hook 不传入 JSON_CWD 所以 fallback 到 `$(pwd)` 即可
- **独立可调试** — hook 不再完全独立，但 _common.sh 只有 ~15 行，影响很小
- **setup.sh 需要安装 _common.sh** — `install_versioned_script` 需要包含这个文件

### 4.3 现有 SCRIPT_DIR 模式

只有 phase-guide.sh 定义了 SCRIPT_DIR（phase-guide.sh:13）。其他 hook 不需要定位相对路径。抽取后所有 hook 都需要 SCRIPT_DIR。

### 4.4 test-workflow-consistency.sh 影响

当前验证策略（:45-84）：提取 while 循环体、比较核心元素。抽取后：
- 验证策略应改为：检查每个 hook 是否 source _common.sh + _common.sh 定义 resolve_plan_name 和 find_plan
- 比当前策略更简单、更可靠

## 五、CI 缺口修复分析

### 5.1 应加入 CI 的测试

优先级排序：

| 测试文件 | 优先级 | 理由 |
|----------|-------|------|
| test-multi-ide.sh | P0 | 测试安装器核心功能，18 个测试覆盖 4 个 IDE |
| test-pre-commit.sh | P1 | 测试 git hook，目前完全不在 CI 中 |
| test-ide-capability-consistency.sh | P1 | 测试 IDE 文档一致性，刚重写过 |
| test-new-hooks.sh | P1 | 测试 4 个新 hook（post-write-tracker 等），这些 hook 也没有 shellcheck |
| test-cli.sh | P2 | 测试 bin/baton CLI |
| test-adapters-v2.sh | P2 | 与 test-adapters.sh 重叠 |
| test-annotation-protocol.sh | P2 | 测试批注协议 |

### 5.2 应加入 shellcheck 的 hook

| 文件 | 理由 |
|------|------|
| post-write-tracker.sh | 当前无静态检查 |
| completion-check.sh | 当前无静态检查 |
| pre-compact.sh | 当前无静态检查 |
| subagent-context.sh | 当前无静态检查 |

## Self-Review

### Internal Consistency Check

- ✅ SYNCED 代码分析基于逐文件 subagent 对比，证据链完整
- ✅ CI 缺口分析基于完整阅读 ci.yml，与测试文件 glob 交叉验证
- ✅ 旧计划项评估与 § 一至 § 五 的发现一致

### External Uncertainties

1. ~~**最大不确定性**：_common.sh 的 source 路径在 git worktree 场景下是否可靠？~~ → ✅ **已验证安全**。setup.sh:652 使用 `cp` 复制 hook 文件（非 symlink），因此每个 worktree 有自己的 `.baton/hooks/` 副本，`dirname "$0"` 正确解析到 worktree 本地路径。
2. ~~**最弱结论**：test-multi-ide.sh 优先级~~ → Human decision: 全覆盖，不需要按优先级排序，所有测试都加入 CI。
3. ~~**进一步调查会改变什么**：`$0` 在 Claude Code hook 执行环境~~ → ✅ **已验证安全**。`.claude/settings.json:33` 配置为 `"command": "bash .baton/hooks/write-lock.sh"`，Claude Code 直接执行脚本（非 stdin pipe），`$0` 正确指向脚本路径。

## Questions for Human Judgment

1. **CI 运行时间预算** → Human answer: **全覆盖**，所有 7 个缺失的测试都加入 CI。
2. **_common.sh 范围** → Human answer: **公共逻辑一起抽取**，包括 has_skill()（phase-guide.sh:17-29）和 extract_section()（phase-guide.sh:31+）等。
## Final Conclusions

1. **SYNCED 代码复制仍是最高优先级技术债** — 9 个文件，3 类不一致（函数/内联/压缩），只有 4/9 被一致性测试覆盖。（§ 一）
2. **OpenCode 相关变更已过时** — 文件已在 IDE 精简中删除。（§ 三）
3. **CI shellcheck 引用已修复** — 但仍有 4 个 hook 不在 shellcheck 范围。（§ 二.1）
4. **CI 测试覆盖缺口严重** — 7/13 测试文件不在 CI 中，包括安装器核心测试 test-multi-ide.sh。（§ 二.2）
5. ~~Skills 自检已充分~~ → **Revised**: Human requirement: 强化 baton-research 和 baton-plan 自检。尽管已有 Self-Review/Exit Criteria，用户认为仍需增强。纳入计划范围。
6. **_common.sh 范围扩大** — 除 plan-name-resolution + find_plan 外，还应抽取 has_skill()（phase-guide.sh:17-29）等公共逻辑。source 路径已验证安全（setup.sh 用 cp 复制，非 symlink）。（§ 四 + 验证结果）
7. **CI 全覆盖** — Human decision: 所有 7 个缺失测试加入 CI + 4 个 hook 加入 shellcheck。（§ 二）
8. **.agents/skills/ 同步** — setup.sh 的 install_skills() 在安装时生成，源码库不需要预置。当前状态可接受。

## Annotation Log

### Round 1

**[inferred: verification-request] § External Uncertainties #1**
"需要先验证"
→ 已验证：setup.sh:652 使用 `cp` 复制 hook（非 symlink），worktree 场景安全。
→ Consequence: 不确定性消除，_common.sh 方案风险降低。

**[inferred: priority-adjustment] § External Uncertainties #2**
"test-multi-ide.sh调整优先级"
→ 结合 Q1 回答"全覆盖"，所有测试统一加入 CI，不再需要优先级排序。
→ Consequence: no direction change.

**[inferred: verification-request] § External Uncertainties #3**
"进一步调查验证"
→ 已验证：`.claude/settings.json:33` 配置为 `"command": "bash .baton/hooks/write-lock.sh"`，`$0` 正确指向脚本路径。
→ Consequence: 不确定性消除。

**[inferred: scope-decision] § Questions for Human Judgment**
Q1: "全覆盖" — CI 加入所有缺失测试。
Q2: "公共逻辑一起抽取" — _common.sh 范围扩大至 has_skill() 等。
→ Consequence: _common.sh 范围从 ~15 行扩大到 ~30 行，影响 phase-guide.sh 最大。

**[inferred: scope-addition] § 批注区**
"强化 baton-research 自检 增强 / 强化 baton-plan 自检 增强"
→ 与 Final Conclusions #5 矛盾 — 原结论认为"不需要额外强化"。用户覆盖：需要增强。
→ Consequence: direction change. Final Conclusions #5 已修正。Skills 强化重新纳入计划范围。

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->
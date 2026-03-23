# 改进方案：Hook Dispatch 架构

**深度**：Standard — 多种可行方案，需要对比取舍
**模式**：Improvement Proposal（改进现有系统）
**输入来源**：`input-doc.md` + 代码库实际验证

---

## TL;DR

输入文档严重过时（标称 8 条映射 / 5 个 hook，实际 10 条 / 10 个 hook；列出的 `prompt-guard.sh` 不存在），但它识别的五个核心问题中有四个真实存在。根本原因不是 dispatch.sh 本身设计有缺陷——它作为一个 64 行的纯 bash 路由器已经够用——而是 **hook 脚本之间存在大量重复的样板代码**（stdin 解析、target 解析、plan 查找等），这才是可维护性和可测试性的真正瓶颈。改进方向应该是向下提取公共逻辑到 dispatch 层，而非向上增加 manifest 复杂度。

---

## 提议的改进

| 优先级 | 改进 | 为什么（追溯到根本原因） | 工时 | 风险 |
|--------|------|------------------------|------|------|
| P1 | 提升 dispatch.sh 预处理层：stdin 解析 + target 提取下沉 | 10 个 hook 中有 6 个重复相同的 stdin/target 解析逻辑（~30 行），是最大的重复来源 | 3h | 低 |
| P2 | 统一 hook 上下文注入：plan 查找 + GO 检查下沉到 dispatch | 8 个 hook 中有 7 个重复 `source common.sh` + `resolve_plan_name` + `find_plan` 模式 | 2h | 低 |
| P3 | 结构化退出协议：JSON 输出替代纯 stderr 文本 | 当前错误信息仅靠 emoji 前缀区分，IDE 适配层无法可靠解析 | 4h | 中 |
| P4 | Hook 测试 harness：dispatch 层 mock 注入 | 当前测试需模拟完整 IDE 环境变量；dispatch 预处理后 hook 只需测试业务逻辑 | 3h | 低 |
| **合计** | | | **~12h** | |

### P1：Dispatch 预处理层

当前 6 个 hook（write-lock, bash-guard, post-write-tracker, failure-tracker, quality-gate, subagent-context）各自独立解析 `BATON_STDIN` 中的 JSON 字段。这是 dispatch.sh 应该做的事——它已经做了 `tool_name` 提取，只需扩展：

```bash
# dispatch.sh — 在 hook 循环之前，追加以下导出
export BATON_TOOL_NAME="$_tool"

if [ -n "$BATON_STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        export BATON_TARGET="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.file_path // empty')"
        export BATON_COMMAND="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.command // empty')"
        export BATON_CWD="$(printf '%s' "$BATON_STDIN" | jq -r '.cwd // empty')"
        export BATON_SESSION_ID="$(printf '%s' "$BATON_STDIN" | jq -r '.session_id // empty')"
    else
        # awk fallback（现有模式，集中一次）
        export BATON_TARGET="$(printf '%s' "$BATON_STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="file_path") { print $(i+2); exit }
        }')"
        # ... 其余字段类似
    fi
fi
```

**影响**：每个 hook 可删除 15-30 行样板代码，直接使用 `$BATON_TARGET`、`$BATON_CWD` 等环境变量。

**验证方式**：现有 17 个 dispatch 测试 + 各 hook 独立测试全部通过。

### P2：Plan 上下文预加载

7 个 hook 重复同一段模式：

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
resolve_plan_name
find_plan
```

将 plan 发现下沉到 dispatch.sh 中，在 hook 循环之前执行一次：

```bash
# dispatch.sh — manifest 解析前
. "$_dir/lib/common.sh" 2>/dev/null || true
resolve_plan_name
find_plan
export BATON_PLAN_PATH="$PLAN"
export BATON_PLAN_FILE="$PLAN_NAME"
export BATON_HAS_GO=""
[ -n "$PLAN" ] && parser_has_go && BATON_HAS_GO=1
export BATON_HAS_GO
```

**影响**：plan 查找从每 hook 执行一次变为每次 dispatch 执行一次（Windows 上节省 ~100ms * hook 数量）。Hook 直接读环境变量即可。

**验证方式**：`test-dispatch.sh` 扩展 + `test-write-lock.sh` 回归。

### P3：结构化退出协议

目前 Cursor 适配器 (`adapter.sh`) 用正则从 stderr 文本中提取信息。建议用 JSON stdout 替代：

```bash
# hook 输出约定（stdout JSON，stderr 仍可用于人可读消息）
# 允许：
echo '{"decision":"allow","context":"write-set approved"}'
# 阻止：
echo '{"decision":"deny","reason":"no BATON:GO marker"}'
# 建议（PostToolUse 等）：
echo '{"decision":"allow","advisory":"file not in write set"}'
```

**影响**：Cursor 适配器从 37 行简化到 ~5 行（直接透传 JSON）。新 IDE 适配只需映射 JSON 字段。

**验证方式**：`test-adapters.sh` + `test-adapters-v2.sh` 全部覆盖。

### P4：测试 Harness 改进

P1/P2 完成后，hook 测试可以简化为：设置环境变量 → source hook → 检查输出。不再需要构造 JSON stdin 和模拟 dispatch 路径。这不是独立工作项，而是 P1/P2 的自然副产品——但需要同步更新现有测试。

---

## 不应改变的部分

| 要素 | 保留理由 |
|------|---------|
| **manifest.conf 平面结构** | ✅ 验证：10 条映射，全部是无条件的事件→脚本路由。文档声称需要"条件路由（如只在 plan 阶段启用某 hook）"，但实际各 hook 内部已自行处理阶段判断（如 `parser_has_go`），manifest 不需要承载这个责任。阶段条件下沉到 hook 内部是正确的——manifest 负责路由，hook 负责决策。 |
| **run-hook.cmd 跨平台层** | ✅ 验证：polyglot 脚本（cmd + bash 双模式），46 行，逻辑清晰。Windows 上绕过 Git Bash 执行慢的问题是 OS 层面的，不是架构层面能解决的。 |
| **Hook 子 shell 隔离** | ✅ 验证：`( . "$_dir/$_script.sh" )` 模式确保 hook 之间状态隔离。文档将此列为"hook 之间无通信机制"问题，但状态隔离是 feature 不是 bug——hook 之间共享可变状态会引入隐式耦合。 |
| **fail-open 策略** | ✅ 验证：所有 hook 的 trap 默认 exit 0。对于治理工具来说 fail-open 是正确的默认——hook 崩溃不应阻止开发者工作。 |

---

## 对比

| 维度 | 当前 | 改进后 | 为什么 |
|------|------|--------|--------|
| Hook 平均行数 | ~80 行（含 ~30 行样板） | ~50 行（纯业务逻辑） | P1/P2 消除重复样板 |
| Plan 查找次数/dispatch | N 次（每 hook 一次，N=被触发的 hook 数） | 1 次 | P2 集中预加载 |
| IDE 适配复杂度 | 适配器需解析 stderr 文本 | 适配器透传 JSON | P3 结构化输出 |
| 测试构造成本 | 需模拟 JSON stdin + 环境 | 设置 env 变量即可 | P1/P2 的副产品 |
| Windows 性能 | ~200ms * hook 数 | ~200ms + hook 数 * delta | P2 减少重复 shell 操作 |

---

## Self-Check

1. **我是否质疑了问题本身，而不仅是解法？**
   是。输入文档的五个"已知问题"中，我验证后发现"hook 间无通信"实际上是有意的隔离设计而非缺陷。"manifest 不支持条件路由"也不是真正的问题——阶段判断在 hook 内部完成是更好的职责分离。真正的问题是文档没提到的：hook 间大量重复的样板代码。

2. **我是否发现了值得打破的惯例？**
   是。当前惯例是"每个 hook 自己负责完整的输入解析"。这在 hook 数量少（文档声称 5 个）时可以接受，但现实已经有 10 个 hook，重复已不可忽视。打破这个惯例，让 dispatch 承担预处理职责。

3. **我是否在推荐第一个想到的方案？**
   不是。我先考虑了增加 manifest 复杂度（条件路由、优先级系统）的方案，也考虑了引入 hook 框架/模板生成器的方案。前者增加认知负担且不解决根本问题；后者引入代码生成复杂度。最终选择向 dispatch 下沉预处理，因为它不增加新概念，只是把已经做的事（dispatch 已提取 tool_name）做得更完整。

4. **读者能否从这份方案预测会发生什么？**
   可以。每个 P 级改动都标注了：具体改什么文件、代码示例、删多少行、如何验证。

5. **我愿意押钱在这个方案上吗？**
   P1/P2 完全愿意——它们是低风险、高确定性的重构，有充分测试覆盖。P3 的最弱环节是：现有 hook 的 stderr 输出已被 IDE 集成（如 Claude Code 的 hookSpecificOutput JSON），迁移到纯 JSON 需要确认所有 IDE 的 hook 协议是否都支持 stdout JSON 解析。建议 P3 先做一个 hook 的 pilot（write-lock），验证 Claude Code 和 Cursor 都能正确处理后再推广。

---

## 分析（支撑推理）

### 现状（已验证）

输入文档的声明与代码库实际的偏差：

| 文档声明 | 实际情况 | 偏差程度 |
|---------|---------|---------|
| "8 个映射" | ✅ 验证：manifest.conf 有 **10 条映射** | 过时 |
| "5 个独立的 hook 脚本" | ✅ 验证：**10 个** hook .sh 文件（不含 dispatch.sh） | 严重过时 |
| "hook: prompt-guard.sh" | ✅ 验证：**不存在** `prompt-guard.sh`；实际有 bash-guard.sh | 错误 |
| "hook 之间无通信机制" | ✅ 验证：子 shell 隔离是有意设计（`dispatch.sh:52`） | 误判 |
| "dispatch.sh 单次 ~50ms/~200ms" | ❓ 未验证（无 benchmark 工具），但符合 Git Bash 的已知性能特征 | 可信但未验证 |

完整的 hook 清单（✅ 验证于 manifest.conf + 文件系统）：

1. `phase-guide.sh` — SessionStart，阶段检测 + 技能引导（265 行，最复杂）
2. `write-lock.sh` — PreToolUse(Write/Edit/...)，写锁 + 写集执行（172 行）
3. `bash-guard.sh` — PreToolUse(Bash)，shell 写模式检测（165 行）
4. `post-write-tracker.sh` — PostToolUse(Write/Edit/...)，写集漂移告警（117 行）
5. `quality-gate.sh` — PostToolUse(Write/Edit/...)，Self-Challenge 检查（46 行）
6. `subagent-context.sh` — SubagentStart，plan 上下文注入（51 行）
7. `stop-guard.sh` — Stop，会话结束提醒（53 行）
8. `completion-check.sh` — TaskCompleted，完成前检查（77 行）
9. `failure-tracker.sh` — PostToolUseFailure，失败计数器（64 行）
10. `pre-compact.sh` — PreCompact，压缩前上下文保存（70 行）

### 根本原因

文档提出的"平面 manifest""无通信""粗糙错误处理"都是表象。深层问题是：

**Five Whys 链条：**

- 表象：添加新 hook 需要写大量样板代码
- 为什么？每个 hook 独立处理输入解析和上下文获取
- 为什么？dispatch.sh 只做了最小的路由（事件名匹配 + 子 shell 执行）
- 为什么？最初只有 2-3 个 hook，样板不是问题
- 根因：**hook 数量从 3 个增长到 10 个，但 dispatch 的职责没有同步扩展**

这是一个典型的"成功导致的技术债"——系统因为好用而快速增长，但基础设施没跟上。

### Assumption Audit

| # | 假设 | 类型 | 如果错误… |
|---|------|------|----------|
| 1 | manifest.conf 不需要条件路由 | 验证后的事实 | 如果未来需要"某些 hook 只在特定 IDE 上运行"，需要重新评估。但当前 adapter 机制已解决此问题。 |
| 2 | Hook 间不需要共享可变状态 | 设计选择 | 如果需要，说明 hook 职责划分有误，应合并而非添加通信。方案不受影响。 |
| 3 | dispatch.sh 预处理不会显著增加延迟 | 推断 | jq 调用从分散在各 hook 变为集中一次调用，总延迟应减少。最差情况持平。 |
| 4 | 所有 IDE hook 协议都支持 stdout JSON | 未知 | P3 的关键风险点。Claude Code 支持（hookSpecificOutput 已在用），Cursor 支持（adapter 已返回 JSON）。其他 IDE 待验证。 |

### 方案重构

考虑过的替代方案：

**A. 增强 manifest 语法**（条件路由、优先级、参数传递）
- 机制：manifest.conf 变为 DSL（如 `PreToolUse:Write=write-lock.sh [when:has_go]`）
- 否决原因：增加解析复杂度，且问题不在路由逻辑——hook 内部已经正确处理条件判断。这是拿 manifest 解决 hook 的问题。

**B. Hook 框架/模板生成器**
- 机制：提供 `baton hook new <name>` 生成 hook 骨架
- 否决原因：生成的代码仍然是重复的——只是生成时省力，维护时不省力。且对现有 10 个 hook 无帮助。

**C. 向 dispatch 下沉预处理**（推荐方案）
- 机制：dispatch.sh 承担 stdin 解析、target 提取、plan 发现，通过环境变量传递给 hook
- 优势：不引入新概念；减少代码量；改善性能（单次 jq 调用）；降低测试构造成本
- 风险：dispatch.sh 从 64 行增长到 ~100 行，但复杂度是线性的（顺序提取字段），不是指数的

**反转测试（针对方案 C）：**
- **什么情况下这是最差方案？** 如果 hook 需要的输入差异极大（每个 hook 需要完全不同的 JSON 字段），集中提取就变成了"提取了没人用的字段"。✅ 验证：实际 6/10 hook 需要相同的 file_path/cwd 字段，2/10 需要 command 字段，集中提取是合理的。
- **反面方案有道理吗？** 反面是"让每个 hook 更独立"——走向微服务化/独立进程。对于 <100ms 目标的 hook 系统来说，进程开销不可接受。

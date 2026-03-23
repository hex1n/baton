# Hook Dispatch 架构改进方案

**深度**: Standard — 多个可行方案，需要在 "足够好" 与 "过度工程" 之间做出判断。
**输入**: `input-doc.md`（hook dispatch 架构现状分析） + 代码库实际验证。

---

## TL;DR

输入文档的事实基础有多处重大偏差（hook 数量差一倍、漏报已有的状态共享机制、虚构了不存在的脚本），导致它提出的问题部分是伪问题。实际代码库中，dispatch 架构的核心设计是健康的 — 64 行调度器 + 声明式 manifest + 隔离子壳执行。**真正值得改进的是两个点**：(1) hook 脚本之间的 stdin 解析/plan 发现样板代码重复严重（8 个脚本各自重复同一段），(2) dispatch.sh 缺少 BATON_TARGET 的预提取，导致下游 hook 各自再解析一遍。其余所谓问题要么已解决（状态共享），要么是刻意的设计选择（平面 manifest 的简单性优于条件路由的复杂性）。

---

## 改进方案

| 优先级 | 改动 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P1 | dispatch.sh 预提取 BATON_TARGET — 从 stdin JSON 解析 `tool_input.file_path` 并 export | 1h | 低 — 已有 jq+awk 双路径模式可复用 | 高 — 消除 4 个 hook 中重复的 target 解析代码(~60 行) |
| P2 | 将 stdin 读取样板提取到 `lib/stdin.sh` — 标准化 `BATON_STDIN+x` 检查 + fallback 读取 | 1h | 低 — 纯重构，行为不变 | 中 — 消除 4 个 hook 中重复的 stdin 处理模式(~30 行) |
| P3 | 合并 resolve_plan_name + find_plan 调用链 — 当前 8 个 hook 都手动调 `resolve_plan_name; find_plan`，可在 common.sh 加 `init_plan_context()` 一次调用 | 30min | 低 — 向后兼容的 wrapper | 中 — 减少样板，降低新 hook 的入门门槛 |
| P4 | 为 dispatch.sh 增加 `--dry-run` 模式 — 输出匹配的 hook 列表但不执行 | 30min | 低 | 低 — 但对调试和测试有价值 |
| **合计** | | **~3h** | | |

---

## P1 详细设计: dispatch.sh 预提取 BATON_TARGET

当前状态：dispatch.sh 已经从 stdin 提取 `tool_name`（第 24-31 行），但没有提取 `file_path`。下游的 write-lock.sh、post-write-tracker.sh、quality-gate.sh 各自再解析一遍。

改动：在 dispatch.sh 的 tool_name 提取之后，增加 file_path 提取：

```bash
# 在 dispatch.sh 第 31 行之后追加
export BATON_TARGET=""
if [ -n "$BATON_STDIN" ]; then
    BATON_TARGET="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || true
    if [ -z "$BATON_TARGET" ]; then
        BATON_TARGET="$(printf '%s' "$BATON_STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="file_path") { print $(i+2); exit }
        }')" || true
    fi
fi
```

下游 hook 中的 target 解析可简化为 `TARGET="${BATON_TARGET:-}"`，保留 fallback 以兼容直接调用场景。

## P2 详细设计: lib/stdin.sh 标准化

当前 4 个 hook (write-lock, bash-guard, post-write-tracker, failure-tracker) 各自包含相同的模式：

```bash
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
else
    STDIN=""
    [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
fi
```

提取到 `lib/stdin.sh`，export `STDIN` 变量。hook 只需 `. "$SCRIPT_DIR/lib/stdin.sh"`。

## P3 详细设计: init_plan_context()

在 common.sh 中增加：

```bash
init_plan_context() {
    resolve_plan_name
    find_plan
}
```

新 hook 的初始化从 3 行（source common + resolve + find）变成 2 行（source common + init）。现有 hook 保持兼容。

---

## 不应该做的事

1. **不要引入条件路由 / 阶段感知 manifest** — 输入文档建议 manifest "不支持条件路由（如只在 plan 阶段启用某 hook）"是个问题。这不是问题，这是设计选择。✅ 验证：当前 10 个 hook 没有一个需要按阶段条件禁用 — write-lock 在有 BATON:GO 时自行放行，phase-guide 自行检测阶段。把路由逻辑从 hook 内部移到 manifest 层会增加 manifest 的复杂度且带来零收益（hook 已经各自处理了这个逻辑）。

2. **不要把 dispatch.sh 重写为更复杂的调度框架** — 当前 64 行的调度器清晰、可测试、fail-open。增加 hook 优先级、依赖排序、hook 链中断等机制会引入工程复杂性而没有当前需求驱动。

3. **不要试图解决 "Windows 兼容性层增加了复杂度" 这个 "问题"** — run-hook.cmd 是 46 行的 polyglot wrapper，它的存在是因为 Windows IDE 进程无法直接调用 bash。这是一个不可消除的平台约束，不是架构问题。✅ 验证：run-hook.cmd 最后更新于很久之前，稳定且无 bug 报告。

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| P1 预提取可能与 hook 内部的 fallback 逻辑冲突 | hook 内部保留 `TARGET="${BATON_TARGET:-}"` 模式 — 如果 dispatch 没有提取到（直接调用场景），hook 自行回退 |
| P2/P3 重构可能破坏直接调用 hook 的测试 | 测试已有 17 个 dispatch 测试 + 各 hook 独立测试；改动后跑全套回归 |

---

## 自检

**这个方案最可能的失败模式**：改动太小，不值得做。3 小时的重构消除约 90 行重复代码 — 对于一个已经稳定运行的 1674 行系统来说，ROI 确实不高。如果我知道这个方案会失败，我会问："这些重复真的造成了维护负担吗？" 答案是：当前 hook 增长速度已经放缓（最近的 hook 是 failure-tracker 和 pre-compact），如果不再频繁添加新 hook，重构的投资回报会更低。

但反过来看：P1（预提取 BATON_TARGET）的价值不仅是减少代码量 — 它确立了一个正确的职责边界："dispatch 负责解析 stdin，hook 负责业务逻辑"。这个原则在下次添加 hook 时会立刻降低认知负担。所以即使只做 P1 一项，也是有意义的。

---

## 分析

### 输入文档事实核查

输入文档存在多处事实偏差，必须先纠正才能在其基础上规划：

| 文档声称 | 实际情况 | 偏差程度 |
|----------|----------|----------|
| "当前 manifest.conf 中有 8 个映射" | ✅ 实际 10 个映射（manifest.conf 10 行非注释内容） | 数量错误 |
| "5 个独立的 hook 脚本" | ✅ 实际 10 个 hook 脚本（write-lock, phase-guide, bash-guard, post-write-tracker, quality-gate, stop-guard, completion-check, failure-tracker, pre-compact, subagent-context） | 数量差一倍 |
| 列举 "prompt-guard.sh" | ✅ 不存在此脚本；实际存在的是 bash-guard.sh | 虚构 |
| "Hook 之间无通信机制 — 每个 hook 独立执行，无法共享状态" | ✅ 实际有多种共享机制：`BATON_STDIN`（dispatch 缓冲后 export）、`BATON_PROJECT_DIR`（dispatch export）、`common.sh`/`plan-parser.sh`（共享库）、`/tmp/baton-*` 文件（session 级状态） | 与事实相反 |
| "错误处理粗糙 — 只有退出码，没有结构化错误信息" | ✅ dispatch.sh 第 59-61 行有 unexpected exit code 警告；所有 hook 都有 fail-open trap；stderr 输出包含结构化的 emoji 前缀消息 | 低估了现有机制 |
| "manifest.conf 是平面结构" | ✅ 准确 — manifest 确实是 event:matcher:script 三列平面格式 | 准确，但见下方分析 |
| "不支持条件路由（如只在 plan 阶段启用某 hook）" | ✅ 准确描述 manifest 能力；但忽略了 hook 内部已经各自实现了阶段感知逻辑 | 准确但误导 |

### 为什么 "平面 manifest" 不是问题

输入文档暗示 manifest 应该支持条件路由。对此进行第一性原理分析：

**条件路由解决什么问题？** 它的前提是 "某些 hook 在某些阶段不应该运行"。但 ✅ 验证实际代码后发现：所有 10 个 hook 都在自身内部处理了阶段判断（write-lock 检查 BATON:GO、phase-guide 检测 6 种状态、bash-guard 检查 gate 状态等）。它们在 "不适用" 的阶段会快速退出（exit 0），不会产生错误输出或性能开销。

如果把阶段判断从 hook 移到 manifest：
- manifest 需要新语法（如 `PreToolUse:Write:write-lock:phase=implement`）
- dispatch.sh 需要新增阶段检测逻辑（目前不是它的职责）
- 同一个阶段判断逻辑会出现在两个地方（manifest + hook 内部的 fallback）
- 测试复杂度增加（需要测试 manifest 条件 + hook 内部条件的交互）

结论：当前设计中 **hook 自治** 是正确的架构选择。dispatch 只负责路由（event + tool matcher），hook 自己决定是否生效。这遵循了 "让每个组件自己管理自己的条件" 的原则。

### 真正的改进空间

通过代码审查发现的实际痛点（不是文档说的，是代码本身表现出的）：

1. **stdin 解析重复**: write-lock.sh(23-28), bash-guard.sh(34-40), post-write-tracker.sh(17-22), failure-tracker.sh(14-19) 有几乎相同的 6 行 BATON_STDIN 检查模式。这不是功能问题，但每次添加新 hook 都要复制粘贴。

2. **target 路径解析重复**: write-lock.sh(30-46) 和 post-write-tracker.sh(25-39) 包含几乎相同的 15 行 target+cwd 解析代码。dispatch.sh 已经做了 tool_name 提取但跳过了 file_path — 这是一个遗留的不一致。

3. **plan context 初始化重复**: 8 个 hook 都有 `resolve_plan_name; find_plan` 两行调用。虽然每行很短，但对新 hook 作者来说是一个需要知道的仪式。

这三个重复模式的共同根因是：dispatch.sh 的 "预处理" 范围太窄（只提取了 tool_name），导致下游 hook 各自补充缺失的预处理步骤。

## 批注区

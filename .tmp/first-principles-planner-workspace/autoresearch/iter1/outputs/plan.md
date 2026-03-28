# 规划：Bash Hooks 的维护性问题

**深度**: Deep — 请求本身以解决方案("重写为 Python")替代了问题("难维护")，
需要深挖假设，这正是 assumption audit 的核心用途。

**输入来源**: baton 代码库（14 个 hooks/lib 脚本，4 个 adapter 脚本，18 个测试文件）

---

## TL;DR

"重写为 Python"是一个伪装成问题的解决方案。真正的问题是"hooks 在哪些方面
难维护"——分解后发现根因集中在**重复模式**（每个 hook 的 stdin 解析/plan 查找
样板）和 **awk 内嵌解析器的可读性**，而非 bash 语言本身。在 baton 的零依赖
约束下，Python 重写不仅不解决根因，还引入一个新的硬依赖，破坏项目的核心设计
原则。推荐方案：**在 bash 内部消除重复**——将样板模式提取到 common.sh，
简化 plan-parser.sh 中的 awk 块，加强 ShellCheck + 测试覆盖。

---

## 行动方案

| 优先级 | 变更 | 工时 | 风险 | 价值 |
|--------|------|------|------|------|
| P1 | 将 stdin JSON 解析提取为 `lib/stdin-reader.sh` 共享函数 | 2h | 低 | 高 — 消除 6 个 hook 中的重复样板 |
| P2 | 将 plan 查找/GO 检查样板提取为 common.sh 的 `baton_hook_init` 一行初始化 | 1h | 低 | 高 — 消除 8 个 hook 中的 5 行重复序列 |
| P3 | 将 plan-parser.sh 的 awk 内嵌块拆分为独立 awk 脚本文件（如 `lib/todo-parser.awk`） | 3h | 中 | 中 — awk 逻辑可独立测试、可读性大幅提升 |
| P4 | 为 common.sh 和 plan-parser.sh 增加函数级文档头（参数/返回值/副作用） | 1h | 低 | 低 — 降低新 hook 的上手门槛 |
| **合计** | | **~7h** | | |

### P1 详细说明：stdin JSON 解析提取

当前 6 个 hook（write-lock, bash-guard, post-write-tracker, failure-tracker,
subagent-context, quality-gate）各自包含近乎相同的 stdin 读取 + jq/awk 解析段。
提取为共享函数后：

```bash
# lib/stdin-reader.sh
# 使用方式：. "$SCRIPT_DIR/lib/stdin-reader.sh"
# 设置：STDIN, TARGET, JSON_CWD, TOOL_NAME, CMD (按需)

_read_baton_stdin() {
    if [ -n "${BATON_STDIN+x}" ]; then
        STDIN="$BATON_STDIN"
    else
        STDIN=""
        [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
    fi
}

_parse_target() {
    TARGET="${BATON_TARGET:-}"
    JSON_CWD=""
    [ -z "$TARGET" ] && [ -n "$STDIN" ] || return 0
    if command -v jq >/dev/null 2>&1; then
        TARGET="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // empty')"
        JSON_CWD="$(printf '%s' "$STDIN" | jq -r '.cwd // empty')"
    else
        TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)
        }' | head -1)"
        JSON_CWD="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="cwd") print $(i+2)
        }' | head -1)"
    fi
}
```

### P2 详细说明：hook 初始化一行化

目前 8 个 hook 的开头都重复这个序列：

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan
```

提取为 `baton_hook_init` 后，每个 hook 只需一行：

```bash
. "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/lib/common.sh" && baton_hook_init
```

---

## 不应该做的事

1. **不要重写为 Python**。原因见下方分析。引入 Python 运行时依赖与 baton 的
   "零编译依赖"核心约束直接冲突。
2. **不要引入 bash 框架**（如 bats-core 替代自有测试）。当前测试套件有 7000+
   行、覆盖所有 hook，迁移成本大于收益。
3. **不要用 `source` 替代子 shell 隔离**。dispatch.sh 的 `( . "$_dir/$_script.sh" )`
   模式是故意的——隔离 exit code 和变量状态，防止 hook 间干扰。

---

## 对比表：当前状态 vs 推荐方案 vs Python 重写

| 维度 | 当前状态 | 推荐（bash 内部优化） | Python 重写 |
|------|---------|---------------------|-------------|
| **依赖** | 零（bash + coreutils） | 零（不变） | Python 3.x（新硬依赖） |
| **Windows 兼容** | run-hook.cmd polyglot + Git Bash | 不变 | 需额外处理 Python 路径发现 |
| **stdin 解析重复** | 6 处 ~15 行重复 | 1 处共享函数 | 消除（Python 内置 json） |
| **awk 可读性** | 内嵌 awk 块难读 | awk 拆为独立文件 | 消除（Python 原生解析） |
| **测试套件** | 7034 行 bash 测试 | 增量修改 | 需完全重写 |
| **hook 添加成本** | ~50 行样板 | ~10 行（用共享函数） | ~20 行（Python 模块化） |
| **总工时** | — | ~7h | ~40-60h（含测试重写） |
| **风险** | — | 低（增量、向后兼容） | 高（全量替换 + 新依赖 + 回归风险） |

---

## 异议路径：什么条件下 Python 重写是正确的

如果你仍然希望推进 Python 重写，以下条件需要同时满足：

1. **零依赖约束被显式放弃** — 作为项目决策记录在案（BATON:OVERRIDE + 理由）
2. **hooks 逻辑复杂度持续增长** — 当单个 hook 超过 300 行且包含递归数据结构
   处理时，bash 的限制开始真正影响正确性而非仅影响可读性
3. **Windows 兼容层已解决** — 确认所有目标用户环境都有 Python 3.x，或提供
   可靠的 Python 发现/安装机制（类似当前 run-hook.cmd 对 bash 的发现逻辑）
4. **测试迁移计划已就绪** — 7034 行测试的迁移不是附带工作，是主体工作

**如果以上条件满足**，推荐的迁移路径是：

1. 先迁移 `lib/plan-parser.sh`（最复杂的模块，441 行）为 Python 模块
2. 保留 dispatch.sh（64 行，逻辑简单）为 bash
3. 逐个 hook 迁移，每迁移一个完成对应测试迁移
4. 最后迁移 run-hook.cmd 为 Python 入口

预计工时：40-60h（含测试），风险评级：高。

---

## 分析

### Phase 1：问题考古

**Five Whys**:

```
表述: "我们需要把所有 bash hooks 重写成 Python"
为什么? → "bash 太难维护了"
为什么难维护? → [需要分解]
```

"bash 太难维护了"不是一个单一问题，分解为具体症状：

| # | 症状 | 严重程度 | 证据 |
|---|------|---------|------|
| 1 | stdin JSON 解析在 6 个 hook 中近乎逐字重复 | 中 | ✅ write-lock.sh:23-46, bash-guard.sh:34-49, post-write-tracker.sh:17-39, failure-tracker.sh:14-37 各含 ~15 行相同逻辑 |
| 2 | plan-parser.sh 的 awk 内嵌块难以一眼读懂 | 中 | ✅ plan-parser.sh:266-275, 288-298, 411-428 含多行 awk 程序 |
| 3 | jq/awk 双路径（jq 优先 + awk fallback）增加代码量 | 低 | ✅ 这是设计选择（jq optional），不是疏忽 |
| 4 | hook 初始化样板重复 | 低 | ✅ 8 个 hook 中有相同的 5 行 source + init 序列 |
| 5 | bash 本身缺乏结构化数据处理能力 | — | ❓ 实际上 hooks 处理的数据极其简单（单层 JSON、行级文本匹配），bash 对此足够 |

症状 #5 是常见误判：人们把"这段代码写得不好"归因为"语言不好"。但 baton hooks
实际处理的数据结构非常简单——扁平 JSON 提取 1-3 个字段、行级 grep/awk 匹配。
这些任务在 bash 中是惯用操作，不是语言能力的瓶颈。真正的痛点是**重复**（#1, #4）
和**内嵌 awk 的可读性**（#2），两者都可以在 bash 内部解决。

**问题陈述（不含解决方案）**:

baton 的 14 个 hook 脚本中存在约 90 行的重复样板代码（stdin 解析 + 初始化序列），
以及约 60 行的内嵌 awk 块可读性不佳。这增加了添加新 hook 和理解现有 hook 的
成本。解决 = 新 hook 只需 <15 行样板，awk 逻辑可独立阅读和测试。

### 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|------------|
| 1 | "bash 太难维护"是语言问题 | 惯例 | 方案崩溃 — 实际是代码组织问题，换语言不解决 |
| 2 | Python 在所有目标环境可用 | 未知 | 方案崩溃 — Windows CI/CD + 最小容器可能无 Python |
| 3 | 零依赖是核心约束不可更改 | 事实 | ✅ CLAUDE.md 明确声明 "Pure bash + markdown. Zero compiled dependencies" |
| 4 | 测试套件可以增量迁移 | 惯例 | 方案受损 — bash 测试调用 bash hooks，改为 Python 需全量重写测试 |
| 5 | hooks 复杂度会继续增长 | 未知 | 如果不增长，当前方案足够；如果大幅增长，bash 限制才真正成立 |

**关键约束分离**:

- **真约束**：零编译依赖（CLAUDE.md 明确声明，是架构原则不是惯例）✅ 验证于 CLAUDE.md:34
- **真约束**：Windows 兼容（run-hook.cmd 的存在证明这是硬需求）✅ 验证于 run-hook.cmd
- **真约束**：hook 间隔离（dispatch.sh 的子 shell 模式是故意设计）✅ 验证于 dispatch.sh:52
- **惯例**：每个 hook 自己解析 stdin（可以提取为共享函数）
- **惯例**：awk 内嵌在 bash 脚本中（可以拆分为独立文件）

### Phase 2：解决方案类别

**方案 A：bash 内部重构**（推荐）
- 机制：提取重复模式为共享函数 + 拆分 awk 为独立文件
- 优势条件：零依赖约束存在、hooks 复杂度不会大幅增长
- 失败条件：hooks 开始需要复杂数据结构（树、图遍历）
- 挑战的惯例：每个 hook 自包含

**方案 B：Python 全量重写**（不推荐）
- 机制：所有 hooks + dispatch + adapters 用 Python 重写
- 优势条件：零依赖约束被放弃、Python 普遍可用
- 失败条件：目标环境无 Python、测试重写工时爆炸
- 挑战的惯例：零依赖原则

**方案 C：混合方案（bash dispatch + Python 复杂 hooks）**
- 机制：保留 dispatch.sh 和简单 hooks 为 bash，仅复杂 hooks（plan-parser、
  phase-guide）用 Python
- 优势条件：只有少数 hooks 超出 bash 的舒适区
- 失败条件：两种语言混合增加认知负担而非减少
- 挑战的惯例：单一语言栈

**反转测试（方案 A）**：在什么条件下，bash 内部重构是最差方案？
答：如果 hooks 的复杂度在未来 6 个月内增长到需要解析嵌套 JSON、维护跨 hook
状态、或做复杂字符串处理（如模板引擎），那么 bash 重构只是推迟了不可避免的
语言迁移。但从当前代码看，hooks 的复杂度增长趋势是**水平的**（更多 hooks，
每个 hook 逻辑相似）而非**垂直的**（每个 hook 越来越复杂），这正是
"消除重复"能长期有效的场景。

---

## 自检

**核心问题**：这个方案最可能的失败模式是什么？

最可能的失败模式不是技术性的——P1-P4 都是低风险的增量重构。最可能的失败模式是
**方案正确但动机误判**：如果"bash 太难维护"的真正含义不是"代码有重复"，而是
"我不想再用 bash 了，这是审美/偏好问题"，那么任何在 bash 内部的优化都不会
让你满意。重构会让代码客观上更好，但你主观上仍然觉得"难维护"，因为根因
从一开始就不是客观的维护性指标。

如果是这种情况——如果你的判断是"即使代码组织得很好，bash 本身就是我不想继续
投入的语言"——那这是一个合法的决策，但需要显式承认代价：放弃零依赖约束、承受
40-60h 迁移成本、承担回归风险。上面的"异议路径"就是为这种情况准备的。

**因为推荐的方案与用户原始方向相反**：什么证据会改变我的判断？如果你能指出
一个具体的 hook，其 bug 是因为 bash 语言限制（而非代码组织问题）导致的——
比如浮点计算错误、Unicode 处理失败、或并发竞态条件——那说明 bash 的能力边界
确实被触碰了，Python 重写就有了具体的技术理由而不仅是主观偏好。

## 批注区


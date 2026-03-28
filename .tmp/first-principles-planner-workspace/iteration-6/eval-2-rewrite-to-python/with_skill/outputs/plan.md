# 规划：Bash Hooks 重写为 Python

**深度**: Deep — 这是一个"我们一直这么做"类型的提案，假设审计是核心价值所在。
**输入来源**: baton 代码库直接审查（所有 `.baton/hooks/`、`.baton/adapters/`、`setup.sh`、`bin/baton`、`tests/`）

---

## TL;DR

用户提出的问题是"把 bash hooks 重写成 Python"，但实际的根问题是 **bash 难以维护**。重写到 Python 是一个解决方案，不是问题本身。经过对代码库的深入审查，我的结论是：**不应该重写到 Python**。bash 的"难维护"程度被高估了，而重写的代价——引入 Python 运行时依赖、破坏零编译依赖架构、重写 ~9600 行代码（含测试）——远超收益。更好的方案是对现有 bash 代码做针对性的结构优化。

但如果你仍然决定要做这个重写，本文末尾提供了完整的执行方案。

---

## 不应该做的事

- **不要做全量一次性重写。** 无论选择什么目标语言，一次性重写 2567 行 hooks + 393 行 CLI + 7034 行测试是高风险行为。
- **不要引入 Python 作为运行时依赖。** baton 的核心设计原则是"pure bash + markdown, zero compiled dependencies"（✅ 见 CLAUDE.md）。Python 不是零依赖——它需要安装、需要版本管理、Windows 上的 Python 路径问题比 bash 更多。
- **不要把"我觉得 bash 难读"等同于"bash 是错误的技术选择"。** 这是一个 convention 在冒充 constraint。

---

## 推荐方案：结构化优化现有 Bash 代码

### 为什么不重写

| 维度 | Bash 现状 | Python 重写代价 |
|------|-----------|----------------|
| **运行时依赖** | 零。Git Bash 在 Windows 上随 Git 安装 ✅ | 需要 Python 3.x 安装 + 版本锁定。Windows 用户可能有多版本冲突 |
| **代码量** | hooks 1884 行 + lib 540 行 + adapters 165 行 + setup 683 行 + CLI 393 行 = ~2567 行产品代码 ✅ | 1:1 重写至少同等行数，加上 ~7034 行测试重写 |
| **启动性能** | bash 脚本无需解释器启动。hooks 在 10ms 级别响应 ✅ | Python 冷启动 100-300ms，每次 hook 调用都有额外开销 |
| **跨平台** | `run-hook.cmd` polyglot 解决了 Windows 兼容 ✅ | Python 在 Windows 上需要额外处理 (`py` vs `python3` vs `python`) |
| **已有测试** | 18 个测试文件，7034 行断言 ✅ | 全部需要重写或大幅改造 |
| **ShellCheck** | CI 已集成 linting ✅ | 需要建立新的 lint 体系 (mypy, ruff, etc.) |

### 根问题诊断（五个"为什么"）

```
声明: "bash 太难维护了"
为什么? → bash 语法不直观、错误处理脆弱
为什么? → 缺少类型系统、字符串操作笨拙、条件判断语法奇怪
为什么? → bash 是 shell 语言而非通用编程语言
为什么? → baton 选择 bash 是因为它是唯一一个所有目标平台（Linux/macOS/Windows Git Bash）都保证存在的语言
根因: bash 的"难维护"是真实的开发体验问题，但它是零依赖跨平台约束下的合理权衡。
      问题不是"该用什么语言"，而是"如何让 bash 代码更可维护"。
```

### 问题陈述

Bash 作为 baton hooks 的实现语言，在以下方面造成开发体验摩擦：

1. **代码重复** — 多个 hooks 有近乎相同的初始化序列（fail-open trap、stdin 读取、JSON 解析、common.sh 加载、plan 查找）✅ 读过所有 10 个 hook 脚本验证
2. **JSON 解析脆弱** — jq/awk 双路径模式在每个需要 stdin 的 hook 中重复 ✅ 见 dispatch.sh:25-31, write-lock.sh:35-45, bash-guard.sh:42-49
3. **plan-parser.sh 过长** — 441 行单文件，混合了 discovery (1A)、section parsing (1B)、write-set (1C) 三个不同关注点 ✅
4. **测试执行慢** — Windows Git Bash 每个 shell 断言 ~15s ✅ 见 CLAUDE.md

但以上这些都是 **可以在 bash 内解决的结构问题**，不需要更换语言。

---

## 行动方案

| 优先级 | 变更 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P1 | 提取 `lib/stdin-reader.sh`：统一 JSON stdin 读取 + jq/awk 双路径 | 2h | 低 | 高 — 消除 dispatch/write-lock/bash-guard/post-write-tracker/failure-tracker 中的 5 处重复 |
| P2 | 提取 `lib/hook-init.sh`：统一 fail-open trap + common.sh 加载 + plan 查找 | 1.5h | 低 | 高 — 每个 hook 减少 8-12 行样板代码 |
| P3 | 拆分 `plan-parser.sh` 为三个模块：`plan-discovery.sh`、`plan-sections.sh`、`plan-writeset.sh` | 3h | 中 — 需要更新所有消费者 | 中 — 提高可读性和可测试性 |
| P4 | 为 `bash-guard.sh` 的 `strip_quoted_segments` 添加单元级测试函数 | 1h | 低 | 中 — 这是最复杂的 bash 函数（84 行字符级状态机），目前只有集成测试 |
| P5 | 创建 `lib/json-output.sh`：统一 hookSpecificOutput JSON 构造和 `_escape_for_json` | 1h | 低 | 低 — 减少 phase-guide.sh 和 write-lock.sh 中的 JSON 字符串拼接 |
| **总计** | | **~8.5h** | | |

### P1 代码示例：`lib/stdin-reader.sh`

```bash
#!/usr/bin/env bash
# stdin-reader.sh — Unified JSON stdin reader with jq/awk fallback
# Sets: STDIN, TOOL_NAME, TARGET, JSON_CWD (exported for hook use)

[ -n "${_BATON_STDIN_LOADED:-}" ] && return 0
_BATON_STDIN_LOADED=1

baton_read_stdin() {
    if [ -n "${BATON_STDIN+x}" ]; then
        STDIN="$BATON_STDIN"
    elif [ ! -t 0 ]; then
        STDIN="$(cat 2>/dev/null || true)"
    else
        STDIN=""
    fi
    [ -z "$STDIN" ] && return

    if command -v jq >/dev/null 2>&1; then
        TOOL_NAME="$(printf '%s' "$STDIN" | jq -r '.tool_name // empty' 2>/dev/null)" || true
        TARGET="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || true
        JSON_CWD="$(printf '%s' "$STDIN" | jq -r '.cwd // empty' 2>/dev/null)" || true
    else
        TOOL_NAME="$(printf '%s' "$STDIN" | sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1)" || true
        TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)}' | head -1)" || true
        JSON_CWD="$(printf '%s' "$STDIN" | awk -F'"' '{for(i=1;i<=NF;i++) if($i=="cwd") print $(i+2)}' | head -1)" || true
    fi
}
```

重写前 write-lock.sh 的 stdin 处理（第 23-46 行）变为：

```bash
. "$SCRIPT_DIR/lib/stdin-reader.sh"
baton_read_stdin
TARGET="${BATON_TARGET:-$TARGET}"
```

### P2 代码示例：`lib/hook-init.sh`

```bash
#!/usr/bin/env bash
# hook-init.sh — Standard hook initialization
# Provides: fail-open trap, common.sh loading, plan discovery

baton_hook_init() {
    local _hook_name="${1:-unknown}"
    trap "echo '⚠️ BATON $_hook_name: unexpected error, allowing (fail-open)' >&2; exit 0" HUP INT TERM

    SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
    if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
        . "$SCRIPT_DIR/lib/common.sh"
    else
        echo "⚠️ BATON $_hook_name: common.sh not found, allowing (fail-open)" >&2
        exit 0
    fi
    resolve_plan_name
    find_plan
}
```

---

## 反对方案（Dissenting Path）：如果你仍然要用 Python 重写

### 什么条件下 Python 重写是合理的

1. **baton 的用户群扩大到非开发者**，他们不会安装 Git（因此没有 Git Bash）但会安装 Python — ❓ 目前不成立
2. **hooks 的逻辑复杂度大幅增加**，需要真正的数据结构（AST、tree、graph）— ❓ 目前最复杂的是 plan-parser 的 awk 脚本，足够但勉强
3. **你决定放弃"零依赖"架构原则** — 这是一个合法的战略决策，但需要明确做出

### 如果要做，执行方案

| 阶段 | 内容 | 工作量 | 依赖 |
|------|------|--------|------|
| A | 建立 Python 基础设施：`requirements.txt`（空或 minimal）、项目结构 `.baton/hooks_py/`、Python 版本检测 wrapper | 4h | 无 |
| B | 重写 `lib/` 层：plan-parser、common、junction、stdin-reader → Python 模块 | 8h | A |
| C | 重写核心 hooks：write-lock、bash-guard、dispatch → Python | 12h | B |
| D | 重写辅助 hooks：phase-guide、stop-guard、completion-check、failure-tracker、pre-compact、post-write-tracker、quality-gate、subagent-context | 10h | B |
| E | 重写 adapters：cursor dispatch、cursor adapter、codex dispatch、codex adapter | 4h | C |
| F | 重写 setup.sh 和 bin/baton | 12h | B |
| G | 重写测试：7034 行 bash 测试 → pytest | 16h | C, D |
| H | 更新 `run-hook.cmd`：将 bash 调用替换为 Python | 2h | C |
| I | 集成测试 + Windows 验证 + CI 更新 | 8h | G |
| **总计** | | **~76h** | |

**关键风险**：
- Windows 上 Python 路径检测比 bash 更复杂（`python` vs `python3` vs `py -3` vs 虚拟环境）
- hook 启动延迟从 ~10ms 增加到 ~150ms，用户在每次文件保存时会感知到
- `run-hook.cmd` polyglot 技巧在 Python 上不适用，需要另一种跨平台入口策略
- 迁移期间需要维护 bash 和 Python 两套代码，持续时间不短

---

## 分析

### 假设审计

| # | 假设 | 类型 | 如果错误... |
|---|------|------|-------------|
| 1 | "Bash 太难维护" = 需要更换语言 | **convention** — 把"不喜欢 bash"等同于"bash 不适合这个用途" | 方案崩溃：如果 bash 代码结构优化后可维护性足够，重写就是浪费 |
| 2 | Python 在所有目标平台上可用 | **unknown** — Windows 不保证预装 Python | 方案崩溃：引入新的安装前提条件，违反零依赖原则 |
| 3 | Python 重写后代码量会减少 | **unknown** — Python 的显式导入和类定义可能抵消语法简洁性 | 方案受损：如果代码量持平，维护性提升有限 |
| 4 | Hook 启动性能不重要 | **convention** — 没有人抱怨过性能 ≠ 性能不重要 | 方案受损：PreToolUse hook 在每次编辑操作前执行，150ms 延迟会被感知 |
| 5 | 现有 bash 代码质量差 | **fact — 被证伪** | 方案的前提被削弱。✅ 读过全部代码：有一致的风格、fail-open 设计、双路径兼容、充分的测试覆盖 |

### 真约束 vs 惯例

| 约束 | 类型 | 决定者 | 理由是否仍成立 |
|------|------|--------|---------------|
| 零编译/运行时依赖 | **真约束** — 架构决策 | 项目创始人（你），记录在 CLAUDE.md | ✅ 仍然成立：baton 通过 junction 分发到任意项目，不能假设目标项目有 Python |
| 跨平台（Linux/macOS/Windows） | **真约束** — 目标市场 | 项目定义 | ✅ 仍然成立 |
| hook 响应时间 < 1s | **真约束** — 用户体验 | IDE hook 协议限制 | ✅ 仍然成立：Cursor hooks.json 有 timeout:10 |
| "bash 难维护" | **惯例** — 开发体验偏好 | 当前开发者 | 可通过结构优化改善而非更换语言 |
| 使用 bash 而非其他脚本语言 | **convention 但 load-bearing** | 初始架构选择 | ✅ 理由仍成立：bash 是唯一保证存在于所有目标平台的语言 |

### 逆向测试

对推荐方案（结构优化而非重写）做 pre-mortem：

**"在什么条件下，结构优化是最差的方案？"**

当 hooks 的业务逻辑复杂度增长到需要真正的数据结构和类型系统时——例如如果 plan-parser 需要解析 Markdown AST 而非简单的 `grep`/`awk` 模式匹配。目前 plan-parser.sh 的 441 行代码刚好在 bash 能力的边界上：awk 脚本处理 section range、Todo counting 和 write-set extraction 仍然够用，但如果需要嵌套结构解析，bash 就会开始挣扎。

**缓解**：监控 plan-parser.sh 的复杂度。如果它超过 ~600 行或需要处理嵌套结构，那时候考虑将 **仅 parser** 提取为 Python 模块（而非全量重写），其余 hooks 继续用 bash。

---

## 自检

**核心问题：这个方案最可能的失败模式是什么？**

最可能的失败模式是：我低估了用户（你）对 bash 的维护性厌倦，而你要的不是"最优技术方案"而是"不用再写 bash"的开发体验改善。如果你的根本需求是"我不想再看 bash 了"，那么结构优化不会解决这个问题——它只是让你需要维护的 bash 更整洁一点。

**如果我知道这个方案会失败，我会怎么做？** 我会推荐一个中间路线：核心 dispatch 保持 bash（保证零依赖），但将业务逻辑密集的模块（plan-parser、phase-guide、bash-guard）提取为 Python optional 增强——当 Python 可用时用 Python 版本，否则 fallback 到 bash。这增加了维护表面积但保留了零依赖保证。

**用户提出了一个解决方案而非问题——我是否追溯到了根问题？** 是的。"重写到 Python"是一个解决方案。根问题是"bash 难维护"。我提出的方案直接解决维护性问题而不引入语言迁移的成本和风险。但我也尊重你可能有我不知道的上下文——因此提供了完整的 Python 重写执行方案。

---

## 批注区

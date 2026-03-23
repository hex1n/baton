# 改进提案: Baton Hook 系统可维护性

**深度**: 深度 (Deep) — 问题带有"我们一直都这么做"的能量（"bash 太难维护"），假设审计是核心价值所在。

**输入来源**: 用户请求 + 代码库直接验证（11个 hook 脚本、3个 lib 模块、18个测试文件、manifest.conf、run-hook.cmd）

---

## TL;DR

用户提出将 bash hooks 重写为 Python 以改善可维护性。经过第一性原理分析，**根本问题不是语言选择，而是代码库缺少结构化的 bash 工程实践**（函数库提取不完整、JSON 解析重复、缺乏类型化错误处理）。Python 重写会破坏 baton 的核心设计原则（"pure bash + markdown, zero compiled dependencies"），引入 Python 运行时依赖，并要求重写 7000+ 行测试代码 — 而 **bash 本身完全可以通过结构化重构达到同等可维护性**。推荐方案：在保持 bash 的前提下，通过提取共享库、统一 JSON 处理、改善错误模式来解决维护痛点。但如果你仍然想用 Python，本文也提供了具体的执行路径。

---

## 建议的变更

| 优先级 | 变更 | 根因关联 | 工作量 | 风险 |
|--------|------|----------|--------|------|
| P1 | 提取 `lib/json.sh` — 统一 JSON 解析（jq + awk fallback） | 消除7个 hook 中重复的 JSON 解析代码 | 2-3h | 低 |
| P2 | 提取 `lib/hook-bootstrap.sh` — 统一 hook 初始化模式 | 消除每个 hook 开头重复的 trap/source/stdin 读取 | 2h | 低 |
| P3 | 为 `bash-guard.sh` 添加声明式配置 | 最复杂的单个 hook (164行)，write patterns 应为数据而非代码 | 3-4h | 中 |
| P4 | ShellCheck strict mode + 函数文档注释标准化 | 预防新 hook 引入的维护债务 | 1-2h | 低 |
| **总计** | | | **~10h** | |

### P1: 提取 `lib/json.sh` — 统一 JSON 解析

当前状态：`dispatch.sh`、`write-lock.sh`、`bash-guard.sh`、`post-write-tracker.sh`、`failure-tracker.sh`、`subagent-context.sh` 中各自实现了近乎相同的 JSON 解析逻辑（jq 优先 + awk/sed fallback）。这是可维护性问题的最大单一来源。

```bash
# lib/json.sh — 统一 JSON 字段提取
# 用法: json_field '.tool_input.file_path' "$STDIN"
json_field() {
    local _path="$1" _input="$2"
    [ -z "$_input" ] && return
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_input" | jq -r "$_path // empty" 2>/dev/null
    else
        # awk fallback — 提取最后一个字段名对应的值
        local _key="${_path##*.}"
        printf '%s' "$_input" | awk -F'"' -v k="$_key" '{
            for(i=1;i<=NF;i++) if($i==k) { print $(i+2); exit }
        }'
    fi
}
```

**预期影响**: 每个 hook 减少 5-15 行重复代码；JSON 解析 bug 修复只需改一处。
**验证方法**: 现有测试套件通过 + `test-dispatch.sh` 覆盖 json_field 函数。

### P2: 提取 `lib/hook-bootstrap.sh` — 统一初始化

当前模式（每个 hook 都重复）:
```bash
trap '...' HUP INT TERM
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
if [ -n "${BATON_STDIN+x}" ]; then STDIN="$BATON_STDIN"; else ...
```

提取后每个 hook 开头变为:
```bash
#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib/hook-bootstrap.sh"
# hook 逻辑从这里开始，STDIN/SCRIPT_DIR/TARGET 已可用
```

**预期影响**: 每个 hook 减少 10-20 行样板代码；新 hook 开发更快。
**验证方法**: 全量测试通过。

---

## 不应改变的部分

| 要素 | 保留理由 |
|------|----------|
| **Bash 作为 hook 语言** | ✅ 核心设计原则 "pure bash + markdown, zero compiled dependencies" — 这是 baton 的差异化优势，不是历史包袱 |
| **`dispatch.sh` 架构** | ✅ 64行，清晰的 event→matcher→script 路由，已经是该模式的简洁实现 |
| **`manifest.conf` 格式** | ✅ 声明式 `event:matcher:script` 格式直观且足够 |
| **`plan-parser.sh` 集中化** | ✅ 已经正确抽取了 plan 解析逻辑为共享库 (441行)，是好的工程实践 |
| **`run-hook.cmd` 多语言包装器** | ✅ 巧妙的 cmd/bash polyglot，解决了 Windows 兼容问题 |
| **Shell 测试套件 (7034行)** | ✅ 覆盖率高，直接测试 bash 函数，无需翻译层 |

---

## 对比

| 维度 | 当前 (Bash) | 提议 A: 结构化重构 (Bash) | 提议 B: Python 重写 |
|------|-------------|---------------------------|---------------------|
| 运行时依赖 | bash (系统自带) | bash (不变) | Python 3.x (需安装) |
| Windows 兼容 | Git Bash (已验证) | 不变 | Python (需要安装配置) |
| 代码总量 | ~1719 行 hooks + libs | ~1400 行（减少样板） | ~1200 行 Python + 适配层 |
| 测试迁移 | 不需要 | 不需要 | 7034 行 shell 测试需全部重写 |
| JSON 处理 | jq + awk fallback (重复) | 统一 lib/json.sh | 内置 json 模块 |
| 学习曲线 | 需要 bash 能力 | 需要 bash 能力（但更结构化） | 需要 Python 能力 |
| 部署方式 | junction/symlink | 不变 | 需要处理 Python 路径 + venv 问题 |
| 总工程量 | — | ~10h | ~40-60h（含测试重写） |
| 破坏核心原则 | — | 否 | **是** — 引入编译语言依赖 |

---

## 自查

1. **我是在质疑问题本身，还是只在质疑解决方案？**
   是的，质疑了问题本身。"bash 太难维护"不是原子事实 — 经过分解，真正的痛点是重复代码和缺乏共享抽象，这些在任何语言中都会造成维护困难。Python 本身不会解决 7 个文件复制粘贴同一段逻辑的结构问题。

2. **我发现了值得打破的惯例吗？**
   是的：当前"每个 hook 自己处理 JSON 解析和初始化"的做法是惯例而非约束。应该打破它，提取为共享库。

3. **我推荐的是我第一个想到的方案吗？**
   不是。第一反应是同意 Python 重写（毕竟用户明确要求了）。但第一性原理分析揭示根因不在语言层面，所以推荐了不同方案。

4. **用户能从这个计划预测会发生什么吗？**
   可以：4 个具体步骤，每个有代码示例、工作量估计和验证方法。

5. **我会为此押钱吗？**
   P1-P2 高度自信 — 提取共享库是被充分验证的工程实践，风险低。最薄弱环节是 P3（bash-guard 声明式配置），因为当前的 pattern matching 逻辑较复杂，声明式转换的设计需要仔细考虑边界情况。

---

## 分析（支撑推理）

### 当前状态（已验证）

✅ 经逐文件阅读验证，baton hook 系统由以下部分组成：

- **调度器**: `dispatch.sh` (64行) — 读取 `manifest.conf`，按 event:matcher:script 路由，子 shell 隔离
- **11 个 hook 脚本**: write-lock (171行), phase-guide (264行), bash-guard (164行), post-write-tracker (116行), completion-check (76行), pre-compact (69行), failure-tracker (63行), stop-guard (52行), subagent-context (50行), quality-gate (45行)
- **3 个共享库**: plan-parser.sh (441行), common.sh (63行), junction.sh (36行)
- **Windows 兼容**: run-hook.cmd (45行) — cmd/bash polyglot
- **测试**: 18 个测试文件，7034 行，覆盖所有核心 hook
- **总量**: hooks + libs = 1719 行 bash

### 根因分析

用户说"bash 太难维护"。通过五个为什么分解：

```
表述: "我们需要把 bash hooks 重写成 Python"
为什么? → "因为 bash 太难维护"
为什么难维护? → 检查代码库后发现：
  1. JSON 解析在 7 个文件中重复（jq + awk/sed fallback）
  2. 每个 hook 有 10-20 行相同的初始化样板
  3. bash-guard.sh 的 pattern matching (164行) 较复杂
  4. awk 内嵌脚本可读性低
为什么这些问题存在? → plan-parser.sh 的提取是好的开始，但 JSON/初始化层没有同样抽取
为什么没抽取? → 这是增量演化的自然结果 — 不是 bash 语言的固有限制
根因: 代码库需要第二轮抽象提取（JSON + bootstrap），而非语言替换
```

**问题陈述**（不引用任何解决方案）：
baton hook 系统中存在大量重复的 JSON 解析和初始化代码，分散在 7+ 个文件中。修改 JSON 处理逻辑需要同步更新多个文件，增加了出错概率和维护成本。新 hook 开发需要复制粘贴样板代码。当这些问题被解决后 = 每个 hook 只包含业务逻辑，共享关注点集中在共享库中。

### 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|-------------|
| 1 | "Bash 本质上难以维护" | **惯例** — bash 写得好时可维护性不逊色于脚本语言 | 计划存活 — 重构仍有价值 |
| 2 | "Python 会更好维护" | **未经验证** — Python 也可以写出难维护的代码；语言不决定结构 | 计划崩塌 — 重写的投入回报率为负 |
| 3 | "零编译依赖"是核心设计原则 | **事实** — ✅ CLAUDE.md 明确声明 "Pure bash + markdown. Zero compiled dependencies." | 如果这不是约束，Python 方案更可行 |
| 4 | 测试套件必须一起迁移 | **事实** — 测试直接调用 bash 函数和脚本，无法跨语言复用 | 如果能保留 shell 测试，Python 迁移成本降低 |
| 5 | Windows 兼容是硬约束 | **事实** — ✅ run-hook.cmd 存在且被维护；Git Bash 是已验证的方案 | 如果放弃 Windows 支持，约束空间改变 |

### 真约束 vs 惯例

**真约束**（不可在范围内改变）：
- "Pure bash + markdown, zero compiled dependencies" — 项目的核心设计原则 ✅
- Windows 兼容 — 已有用户依赖 run-hook.cmd + Git Bash ✅
- 测试覆盖 — 7034 行测试不能丢失 ✅
- Claude Code hook 协议 — stdin JSON 格式、exit code 约定 ✅

**惯例**（可以改变的选择）：
- "每个 hook 自己处理 JSON" — 历史惯例，应打破
- "每个 hook 自己初始化" — 历史惯例，应打破
- "bash-guard 的 pattern list 硬编码在代码中" — 可以改为数据驱动

### 方案重建

**方案 A: Bash 结构化重构**（推荐）
- 机制：提取 json.sh + hook-bootstrap.sh，减少重复
- 为什么最优：零迁移成本，直接解决根因，保持所有约束
- 为什么可能失败：如果维护者真的不想写 bash（但这是偏好，不是工程问题）
- 打破的惯例：hook 自包含的做法

**方案 B: Python 重写**
- 机制：用 Python 重写所有 hook + dispatch + parser
- 为什么最优：Python 有更好的数据结构、标准库、测试框架
- 为什么可能失败：(1) 破坏核心设计原则 (2) 需要重写 7034 行测试 (3) Windows Python 路径管理 (4) 引入运行时依赖
- 打破的惯例：整个技术栈选择

**方案 C: 混合 — 核心用 Python，胶水用 Bash**
- 机制：plan-parser 和 JSON 处理用 Python，hook 入口保持 bash
- 为什么最优：渐进迁移，可逐步验证
- 为什么可能失败：两种语言的维护负担 > 一种语言；接口层增加复杂度

**反转测试 (方案 A)**:
- 什么情况下这是最差方案？→ 如果团队扩大、新成员完全不会 bash、且需要频繁修改 hook 逻辑。目前 baton 是单人维护且维护者精通 bash，这个条件不成立。
- 相反方案（完全不重构）有没有价值？→ 有 — 如果 hook 系统已稳定不再变化。但从 git log 看，hooks 仍在活跃演化。
- 如果方案 A 失败我们学到什么？→ bash 的问题确实在语言层面而非结构层面，此时方案 B 成为正确选择。

### 反对方案（如果你仍然想用 Python）

以下条件**会**使 Python 重写合理：
- baton 将成为多人维护的项目，且新维护者不熟悉 bash
- hook 逻辑变得远比当前复杂（例如需要异步处理、复杂数据结构）
- "zero compiled dependencies" 原则被修订

如果你决定继续 Python 重写，具体执行路径：

| 步骤 | 内容 | 工作量 |
|------|------|--------|
| 1 | 创建 `hooks/baton_hooks/` Python 包 + json_util.py + bootstrap.py | 4h |
| 2 | 实现 `plan_parser.py` (移植 plan-parser.sh 的 441 行) | 6-8h |
| 3 | 逐个重写 hook: quality-gate → stop-guard → ... → write-lock (按复杂度升序) | 8-12h |
| 4 | 修改 dispatch — 改为 `python -m baton_hooks.dispatch` 或保持 bash dispatch + python hooks | 2-3h |
| 5 | 修改 run-hook.cmd 以定位 Python 解释器 | 2h |
| 6 | 重写测试套件（7034 行 → pytest） | 15-20h |
| 7 | 更新 CLAUDE.md、setup.sh、安装流程 | 2h |
| **总计** | | **~40-50h** |

风险：Python 解释器在 Windows 上的路径发现比 bash 更不可靠（Python 可能安装在 Microsoft Store、Anaconda、系统 Python、pyenv 等多个位置）。run-hook.cmd 当前只需查找 bash.exe，Python 版本需要处理更多边界情况。

## 批注区


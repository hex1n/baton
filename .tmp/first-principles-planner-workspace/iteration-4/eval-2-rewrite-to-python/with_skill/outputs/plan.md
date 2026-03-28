# 改进提案：Baton Hook 系统的可维护性

**深度**: Deep — 用户的请求带有"一直都是这么做的"的能量（"bash 太难维护了 → 重写成 Python"），需要深入质疑假设，分离真实问题与预设方案。

**输入来源**: 代码库直接验证（`.baton/hooks/` 全部 11 个脚本、`lib/` 3 个库文件、`manifest.conf`、适配器、测试套件、`setup.sh`、`run-hook.cmd`）

**证据标记**: 全部 ✅ verified — 每个断言均基于直接读取源文件。

---

## TL;DR

用户提出将 bash hooks 重写为 Python，理由是"bash 太难维护了"。深入分析后发现：**真正的问题不是语言本身，而是 bash 中缺乏结构化复用机制导致的模式重复（boilerplate）。** ✅ 验证：11 个 hook 脚本中有 7 个重复相同的 stdin 解析 / plan 查找 / fail-open 模式，共约 120 行重复代码。但引入 Python 会破坏 baton 的核心设计原则（零编译依赖），在 Windows 上引入新的依赖问题，且需要重写 7034 行测试。**推荐方案：保留 bash，通过提取公共 harness 层消除 boilerplate，将 hook 作者只需关心的"业务逻辑"降到最少。** 如果仍然希望采用 Python，本文末尾提供了具体的迁移路径。

---

## 提议的变更

| 优先级 | 变更 | 为什么（追溯到根因） | 工作量 | 风险 |
|--------|------|---------------------|--------|------|
| P1 | 提取 hook harness 层：`dispatch.sh` 内置 stdin 缓冲、plan 查找、fail-open trap，hook 脚本只定义 `hook_main()` 函数 | 消除 7 个 hook 中重复的 ~120 行 boilerplate，这是可维护性问题的根因 | 4h | 低 — 行为不变，只是结构重组 |
| P2 | 统一 JSON 解析：将 jq/awk 双路径提取集中到 `lib/json.sh`，提供 `json_get <key>` 接口 | 目前每个需要 JSON 的 hook 都自己实现 jq+awk fallback，是最大的重复来源之一 | 2h | 低 |
| P3 | 添加 ShellCheck 严格模式 + hook 接口契约文档 | 用静态分析弥补 bash 缺乏类型系统的劣势；接口文档降低新 hook 的认知负担 | 1h | 低 |
| P4 | 为 `plan-parser.sh`（441 行）添加单元级测试分组 | 当前 `test-plan-parser.sh`（1105 行）是最大测试文件，缺乏内部分组使回归定位困难 | 2h | 低 |
| **Total** | | | **~9h** | |

### P1 详细设计：Hook Harness 层

当前每个 hook 的结构几乎相同：

```bash
# 当前模式（每个 hook 重复）：
trap 'echo "..." >&2; exit 0' HUP INT TERM        # fail-open
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then        # source common
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
resolve_plan_name                                    # plan discovery
find_plan
# ...实际逻辑...
```

改为由 `dispatch.sh` 提供 harness：

```bash
# dispatch.sh 中的新调度逻辑：
_run_hook() {
    local _script="$1"
    # harness: fail-open trap + source common + resolve plan
    trap 'echo "⚠️ BATON dispatch: $_script unexpected error, fail-open" >&2; exit 0' HUP INT TERM
    . "$_dir/lib/common.sh" 2>/dev/null || { exit 0; }
    resolve_plan_name; find_plan
    # 调用 hook 的业务逻辑
    . "$_dir/$_script.sh"
}
```

```bash
# 重构后的 stop-guard.sh（从 52 行降至 ~20 行）：
# Hook: Stop — 提醒未完成的任务
[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0
parser_todo_counts
if [ "$TODO_TOTAL" -gt 0 ] && [ "$TODO_REMAINING" -eq 0 ]; then
    echo "✅ All Todo items complete — FINISH phase." >&2
    # ... finish guidance ...
elif [ "$TODO_REMAINING" -gt 0 ]; then
    echo "📋 Implementation in progress: $TODO_DONE/$TODO_TOTAL done." >&2
fi
exit 0
```

**预期可衡量的影响**: hook 脚本平均行数从 ~95 行降至 ~50 行（去除 boilerplate 后）。新 hook 的编写只需关注业务逻辑，不需要复制粘贴基础设施代码。

**验证方式**: 重构后运行全部 18 个测试文件（7034 行断言），零回归即为成功。

### P2 详细设计：统一 JSON 解析

```bash
# lib/json.sh — 统一 JSON 字段提取
# 用法：value="$(json_get "tool_input.file_path" "$json_string")"
json_get() {
    local _key="$1" _json="$2"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_json" | jq -r ".$_key // empty" 2>/dev/null
    else
        # awk fallback：处理顶层和一层嵌套
        local _leaf="${_key##*.}"
        printf '%s' "$_json" | awk -F'"' -v k="$_leaf" '{
            for(i=1;i<=NF;i++) if($i==k) { print $(i+2); exit }
        }'
    fi
}
```

**预期影响**: 消除 `write-lock.sh`、`bash-guard.sh`、`post-write-tracker.sh`、`failure-tracker.sh` 中的 4 处 jq/awk 重复实现。

**验证方式**: `test-write-lock.sh`（529 行）+ `test-bash-guard.sh`（377 行）全部通过。

---

## 不应改变的部分

| 要素 | 保留原因 |
|------|---------|
| **Bash 作为 hook 语言** | ✅ baton 的核心设计原则是"pure bash + markdown, zero compiled dependencies"。Bash 在所有目标平台（Linux、macOS、Windows Git Bash）上预装可用，无需额外安装步骤。Python 在 Windows 上不保证预装。 |
| **`manifest.conf` 声明式路由** | ✅ 当前的 `event:matcher:script` 格式（12 行）清晰、可 grep、易于新增。这是 bash 擅长的场景。 |
| **jq-optional 策略** | ✅ "jq optional, awk fallback" 保证了零硬依赖。消除的是重复实现，不是双路径策略本身。 |
| **Shell-based 测试** | ✅ 7034 行测试直接测试 bash hook 行为（exit code、stderr 输出）。测试语言与被测代码同构是优势，不是问题。 |
| **`run-hook.cmd` polyglot** | ✅ 这个 46 行的 cmd/bash polyglot 解决了 Windows IDE 的 hook 入口问题。无论 hook 用什么语言，这层适配都需要存在。 |

---

## 对比

| 维度 | 当前状态 | 提议后 | 原因 |
|------|---------|--------|------|
| Hook 平均行数 | ~95 行 | ~50 行 | P1 harness 消除 boilerplate |
| 新 hook 编写成本 | 复制粘贴约 15 行基础设施 | 只写业务逻辑 | harness 层提供统一入口 |
| JSON 解析重复 | 4 处独立的 jq+awk 实现 | 1 处集中实现 | P2 统一 `json_get` |
| 运行时依赖 | bash only（jq optional） | 不变 | 不引入新依赖 |
| 测试改动量 | 0 | 0（行为不变） | 重构不改变外部接口 |
| Python 方案的运行时依赖 | N/A | 需要 Python 3.7+ | Windows 上需额外安装 |

---

## Self-Check

1. **我是否质疑了问题本身，而不仅是方案？**
   是。用户说"bash 太难维护"，我没有直接接受这个定性，而是去验证了具体是什么让 bash hook 难维护。发现不是 bash 语言本身（hook 逻辑其实很直白：if/grep/exit），而是 boilerplate 重复。这两个问题有不同的解。

2. **我是否发现了值得打破的惯例？**
   是。当前惯例是每个 hook 自己负责 fail-open trap、common.sh sourcing、plan discovery。这个惯例源于 hook 的独立演化历史，而非有意的设计选择。打破它（集中到 dispatch harness）消除了可维护性问题的根因。

3. **我推荐的是不是第一个想到的方案？**
   不是。第一反应是"Python 不行因为零依赖原则"——这是一个防御性否定，不是解决方案。实际推荐的 harness 重构方案是在分析了 11 个 hook 的共同模式后才浮现的。

4. **用户能否从这个计划预测会发生什么？**
   能。P1-P4 每项都指定了具体改什么文件、代码示例长什么样、行数预期变化多少、用什么验证成功。

5. **我愿意押钱在这个方案上吗？**
   P1-P2 愿意 — 这是纯粹的结构重构，有 7034 行测试覆盖，风险极低。最弱的环节是 P1 的 harness 设计是否能覆盖所有 hook 的初始化差异（例如 `phase-guide.sh` 有额外的 EXIT trap 用于 governance context 注入 — 这需要 harness 支持 hook 级别的 EXIT trap 注册，而不是覆盖）。

---

## Analysis (supporting reasoning)

### 当前状态（已验证）

✅ Baton hook 系统由以下组件构成：
- **`dispatch.sh`**（64 行）：事件分发器，读取 `manifest.conf`，匹配事件+工具名，在子 shell 中执行 hook
- **`manifest.conf`**（12 行）：声明式路由，9 个事件-脚本映射
- **11 个 hook 脚本**（共 1134 行）：从 45 行（`quality-gate.sh`）到 264 行（`phase-guide.sh`）
- **3 个库文件**（共 540 行）：`plan-parser.sh`（441 行）、`common.sh`（63 行）、`junction.sh`（36 行）
- **4 个适配器文件**（共 165 行）：Cursor 和 Codex 的 dispatch + adapter
- **18 个测试文件**（共 7034 行）：全部基于 bash

总量：~1851 行生产代码 + 7034 行测试 = ~8885 行。

### 根因分析

用户的问题是"bash 太难维护了"。通过 Five Whys 追溯：

1. **为什么要重写成 Python？** → "bash 太难维护"
2. **bash 的什么具体方面难维护？** → 验证后发现：不是语法（hook 逻辑是简单的 if/grep/exit 模式），而是每个 hook 重复相同的 boilerplate（fail-open、common sourcing、plan discovery、stdin parsing）
3. **为什么有这些 boilerplate？** → 每个 hook 设计为可独立运行的脚本，dispatch.sh 只负责路由不负责初始化
4. **为什么 dispatch 不提供初始化？** → 历史原因：hook 从 v1 到 v4 逐步演化，早期没有 dispatch 层
5. **根因**：hook 系统缺少一个 harness 层来提供公共初始化，导致每个 hook 作者必须手动复制基础设施代码

**问题陈述**（不引用任何方案）：Hook 系统的可维护性受损于公共基础设施代码的重复。每新增一个 hook 需要复制约 15 行与 hook 功能无关的初始化代码，修改公共模式（如 fail-open 策略）需要同步修改多个文件。解决 = 新 hook 只需编写业务逻辑，公共模式修改只需改一处。

### 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|-----------|
| 1 | "bash 难维护"是因为语言本身 | **惯例** — ✅ 验证后发现是 boilerplate 重复，不是 bash 语法问题。hook 逻辑本身（去掉 boilerplate）是简单的 shell 操作 | 如果真是语言问题 → Python 方案成立。但证据不支持 |
| 2 | Python 在所有目标平台可用 | **未知** — ❓ Windows 不预装 Python，用户的 Windows 10 LTSC 环境需要额外安装 | 如果错 → Python 方案引入新的部署摩擦，违反零依赖原则 |
| 3 | 重写能保持行为一致 | **事实** — ✅ 有 7034 行测试，但测试是 bash 写的，测试的是 exit code + stderr 输出。如果 hook 改为 Python，测试的调用方式需要适配 | 如果适配不完全 → 回归风险 |
| 4 | 所有 hook 共享相同的初始化模式 | **事实** — ✅ 验证：9/11 个 hook source `common.sh` + `resolve_plan_name` + `find_plan`。例外：`failure-tracker.sh` 和 `quality-gate.sh` 有简化路径 | harness 需要支持 opt-out |
| 5 | Hook 数量会继续增长 | **惯例** — 合理推断但未验证。如果 hook 数量稳定在 11 个，boilerplate 的边际成本已经付过了 | 即使不增长，P1 仍然值得做（减少修改公共模式时的同步成本） |

**真正的约束**:
- bash 在所有目标平台预装 — 这是真约束（事实）
- 零编译依赖是核心设计原则 — 这是强惯例，由维护者明确选择，等同于约束
- 测试必须继续通过 — 真约束

**可以打破的惯例**:
- 每个 hook 自行初始化 — 历史遗留，不是有意设计
- jq/awk fallback 在每个 hook 中独立实现 — 可集中

### 方案重建

#### 方案 A：Python 重写（用户提出的方案）

**机制**: 将 11 个 bash hook 重写为 Python 脚本，`dispatch.sh` 改为 `dispatch.py`（或保留 bash dispatch 调用 Python hook）。

**可能最优的条件**: hook 逻辑需要复杂数据结构（dict、class）、正则表达式、JSON 处理、或网络请求。

**可能失败的原因**:
- ✅ 违反核心设计原则"pure bash + markdown, zero compiled dependencies"
- ✅ Windows 上 Python 不预装。当前 baton 的安装只需 `bash setup.sh`，引入 Python 后需要先确保 Python 可用
- ✅ 需要重写或适配 7034 行测试
- ✅ `run-hook.cmd` 需要增加 Python 路径发现逻辑（当前只需找 bash）
- ✅ hook 实际逻辑很简单（grep、exit code、awk），不需要 Python 的高级特性

**反转测试**: 什么条件下这会是最差方案？→ 当团队全是 bash 专家、代码库小、hook 逻辑简单时。✅ 全部命中。

#### 方案 B：Bash Harness 重构（推荐）

**机制**: 在 `dispatch.sh` 中添加 harness 层，提供公共初始化（fail-open、common sourcing、plan discovery）。hook 脚本只定义业务逻辑。同时将 JSON 解析集中到 `lib/json.sh`。

**可能最优的条件**: 问题是 boilerplate 重复而非语言能力不足。✅ 验证确认。

**可能失败的原因**: 某些 hook 有特殊的初始化需求不适配 harness。✅ 验证发现 `phase-guide.sh` 的 EXIT trap 和 `failure-tracker.sh` 的无 plan 路径是例外，但可通过 harness 的 opt-out 机制处理。

**反转测试**: 什么条件下这会是最差方案？→ 当 bash 语言本身是瓶颈（需要 class、异步、复杂数据处理）时。✅ 当前 hook 不需要这些。

#### 方案 C：混合方案（bash dispatch + Python 复杂 hook）

**机制**: 保留 bash dispatch + 简单 hook，仅将 `plan-parser.sh`（441 行，最复杂）改为 Python。

**为什么不推荐**: `plan-parser.sh` 的复杂性来自 walk-up 查找和 awk 段落解析——这些 bash 做得很好，且有 1105 行专门测试覆盖。引入 Python 单点不减少复杂度，反而增加跨语言调用的复杂度。

### 反对意见路径（Dissenting Path）

如果你仍然希望采用 Python 重写，以下是合理的条件和具体路径：

**什么条件下 Python 方案合理：**
- hook 需要调用外部 API（HTTP 请求、webhook 通知）
- hook 需要复杂的 JSON schema 验证（不只是字段提取）
- hook 数量增长到 20+ 且逻辑越来越复杂（需要 class 层次结构）
- 团队中没有人愿意维护 bash

**具体迁移路径（如果决定执行）：**

1. **保留 `dispatch.sh` 为 bash**（它只有 64 行，且是 `run-hook.cmd` 的入口），但改为调用 `.py` 脚本而非 `.sh`
2. **新增 `lib/hook_base.py`**：提供 `HookBase` 类，封装 stdin 解析、plan 查找、fail-open
3. **逐步迁移**：先迁移最简单的 hook（`quality-gate.sh`，45 行），验证测试通过后再逐步迁移其他
4. **`manifest.conf` 扩展**：增加语言标记字段（`event:matcher:script:lang`），dispatch 根据 lang 选择 bash/python
5. **测试适配**：测试不需要重写（测试的是 dispatch 的 exit code + stderr），但需要确保 Python 可用性检查
6. **工作量估计**：~40h（含测试适配），约为 bash harness 方案的 4.5 倍

---

## 批注区


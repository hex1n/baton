# Hook Dispatch 架构改进方案

## 现状评估

基于对全部源码的阅读（dispatch.sh, manifest.conf, 10 个 hook 脚本, lib/common.sh, lib/plan-parser.sh, run-hook.cmd, 两套 adapter），以下是对输入文档中 5 个已知问题的深度分析和改进建议。

### 核心判断

当前架构的设计决策大多数是正确的。dispatch.sh 64 行，manifest.conf 纯文本格式，hook 脚本独立执行 — 这些都是适合 baton "pure bash + markdown, zero compiled dependencies" 哲学的选择。改进应该在保留这个架构精神的前提下，解决真正产生摩擦的问题，而不是引入不必要的复杂度。

---

## 问题 1: manifest.conf 平面结构 — 不支持条件路由

### 现状分析

输入文档说 manifest.conf 不支持"只在 plan 阶段启用某 hook"。但检查实际代码后发现：**现在的 hook 脚本已经在内部实现了阶段感知**。例如：
- `write-lock.sh` 自己检查 BATON:GO 来决定是否阻止写入
- `stop-guard.sh` 内部检查 `[ -z "$PLAN" ] && exit 0` 来跳过非实现阶段
- `bash-guard.sh` 内部检查 `parser_has_go` 来决定是否执行检查
- `completion-check.sh` 内部检查 GO marker 和 Todo 状态

也就是说，**条件路由事实上已经存在，只是在 hook 脚本层而非 manifest 层**。

### 评估

将条件路由移到 manifest 层（例如 `PreToolUse:Write:write-lock:phase=implement`）看起来更"干净"，但实际上会引入几个问题：
1. manifest 需要理解 baton 的阶段模型，使 dispatch.sh 从一个通用调度器变成 baton 专属组件
2. 阶段判断逻辑（找 plan、检查 GO marker、计数 Todo）本身就很复杂，不适合在 dispatch 层做
3. Hook 内部的早期 return 已经很快（~5ms），不值得为这点性能去增加复杂度

### 建议：不改 manifest 格式，引入可选的 guard 机制

如果将来确实需要 manifest 层的条件过滤（例如为了减少 Windows 上的进程启动开销），可以加一个轻量级 guard 列：

```
# 格式: event:matcher:script[:guard]
# guard 是一个简短的 shell 表达式，在 dispatch.sh 中 eval
# 空 = 无条件执行（当前行为）
PreToolUse:Write,Edit:write-lock
PostToolUse:Write,Edit:quality-gate:test -n "$PLAN"
```

但**当前不建议实施**。现有的 hook 内部自检模式工作得很好，增加 guard 列的唯一理由是 Windows 性能 — 而这在问题 4 中有更好的解决方案。

**优先级：低（不建议当前实施）**

---

## 问题 2: Hook 之间无通信机制

### 现状分析

当前每个 hook 在子 shell 中执行（`( . "$_dir/$_script.sh" )`），变量隔离。hook 之间唯一的共享渠道是：
- `BATON_STDIN`（环境变量，只读）
- 文件系统（`/tmp/baton-failures-*`, `/tmp/baton-writeset-violations-*`）

检查实际使用场景后，真正需要 hook 间通信的情况只有一个：**多个 hook 重复执行相同的初始化逻辑**。

具体来说，以下代码模式在 5+ 个 hook 中重复出现：
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
fi
resolve_plan_name
find_plan
```

这不是"通信"问题 — 这是**初始化重复**问题。每次 PreToolUse 触发时，write-lock.sh 和 bash-guard.sh 各自独立地执行 plan 发现逻辑。在 Unix 上这只是 ~10ms 的浪费，但在 Windows/Git Bash 上每个子 shell 启动就是 ~100ms。

### 建议：dispatch 层预计算共享上下文

在 dispatch.sh 中，**在进入 manifest 循环之前**，预计算 hook 共同需要的上下文并导出为环境变量：

```bash
# dispatch.sh — 在 while 循环之前加入
if [ -f "$_dir/lib/common.sh" ]; then
    . "$_dir/lib/common.sh"
    resolve_plan_name
    find_plan
    export BATON_PLAN_RESOLVED="${PLAN:-}"
    export BATON_PLAN_NAME_RESOLVED="${PLAN_NAME:-}"
    export BATON_MULTI_PLAN_COUNT="${MULTI_PLAN_COUNT:-0}"
    if [ -n "${PLAN:-}" ]; then
        parser_has_go && export BATON_HAS_GO=1 || export BATON_HAS_GO=0
    fi
fi
```

Hook 脚本可以检查这些预计算变量来跳过重复初始化：
```bash
# write-lock.sh 中
if [ -n "${BATON_PLAN_RESOLVED+x}" ]; then
    PLAN="$BATON_PLAN_RESOLVED"
    PLAN_NAME="$BATON_PLAN_NAME_RESOLVED"
    MULTI_PLAN_COUNT="$BATON_MULTI_PLAN_COUNT"
else
    # 直接调用模式 — 自行初始化
    . "$SCRIPT_DIR/lib/common.sh"
    resolve_plan_name
    find_plan
fi
```

**好处**：
- 消除 N 个 hook 的重复 plan 发现（最大收益在 PostToolUse，同时触发 post-write-tracker + quality-gate）
- 向后兼容 — hook 仍可独立调用
- 不需要改 manifest 格式

**优先级：中高（Windows 上的实际性能改善）**

### 不建议做的事

不要引入 hook 间的通用消息传递或共享内存机制。当前的 hook 设计原则是**独立和幂等**，这是正确的。如果两个 hook 需要共享状态，正确的做法通常是把它们合并成一个 hook，或者把共享逻辑提取到 lib/ 中。

---

## 问题 3: 错误处理粗糙

### 现状分析

当前的错误处理模型：
- Exit 0 = 允许
- Exit 2 = 阻止（仅 PreToolUse 有效）
- 其他退出码 → dispatch.sh 输出 `⚠️ BATON dispatch: xxx.sh exited with unexpected code` 到 stderr
- 每个 hook 有 `trap '...; exit 0' HUP INT TERM`（fail-open）
- 结构化输出通过 stdout JSON（`hookSpecificOutput`）

这比输入文档描述的要健壮。dispatch.sh 已经区分了 0/2/其他，hook 脚本有 fail-open trap，write-lock.sh 输出结构化 JSON 给 IDE。

### 实际的薄弱点

1. **stderr 消息格式不一致**：有的 hook 用 `🔒 Blocked:`，有的用 `⚠️ BATON xxx:`，有的直接 `echo`。这不影响功能但影响可读性。
2. **dispatch.sh 不区分 "hook 脚本缺失" 和 "hook 脚本执行失败"**：如果 manifest 引用了不存在的脚本，`. "$_dir/$_script.sh"` 会失败，报 "unexpected code 1"，不够明确。
3. **没有聚合输出**：如果多个 hook 都产生 stderr 输出，它们交错在一起，没有清晰的分隔。

### 建议

#### 3a. 脚本存在性预检查（低成本、高价值）

在 dispatch.sh 的循环内、执行 hook 之前加入检查：

```bash
if [ ! -f "$_dir/$_script.sh" ]; then
    echo "⚠️ BATON dispatch: $_script.sh not found (referenced in manifest.conf), skipping" >&2
    continue
fi
```

#### 3b. 结构化错误输出（可选，面向未来）

如果将来需要让 IDE 展示更好的错误信息，可以在 dispatch.sh 层收集 hook 的 stderr 输出并格式化：

```bash
_hook_stderr="$( ( . "$_dir/$_script.sh" ) 2>&1 1>/dev/null )" || _rc=$?
# 保留 stdout（JSON 给 IDE），格式化 stderr
if [ -n "$_hook_stderr" ]; then
    echo "[$_script] $_hook_stderr" >&2
fi
```

但这会增加 I/O 复杂度（需要分离 stdout/stderr），**当前不建议**。3a 的预检查已经足够。

**优先级：3a = 高（一行代码，防止配置错误静默失败）; 3b = 低**

---

## 问题 4: Windows 兼容性层

### 现状分析

`run-hook.cmd` 是一个精巧的多语言脚本（polyglot）— cmd.exe 和 bash 都能执行它。Windows 路径下它找 Git Bash 然后委托给 dispatch.sh。这增加了 ~150ms 的延迟（进程启动 + bash 初始化）。

每次 IDE 工具调用触发 1-2 个 hook，意味着每次 Edit/Write 操作在 Windows 上额外增加 ~400ms（run-hook.cmd → bash → dispatch.sh → hook subshell）。

### 建议：分层优化

#### 4a. 减少子 shell 启动次数（推荐）

当前 dispatch.sh 对每个匹配的 hook 都启动一个子 shell（`( . "$_dir/$_script.sh" )`）。对于同一个事件触发多个 hook 的情况（如 PostToolUse:Write 触发 post-write-tracker + quality-gate），可以考虑：

**方案 A - 合并同事件 hook**：把同一事件下的多个 advisory hook（quality-gate + post-write-tracker 都是 exit 0）合并成一个脚本。这在语义上合理 — 它们都是"写后检查"。

**方案 B - 条件子 shell**：对于 advisory hook（始终 exit 0），用 `. "$_dir/$_script.sh"` 而不是 `( . "$_dir/$_script.sh" )`，省掉子 shell 开销。在 manifest 中标记哪些 hook 是 advisory：

```
# event:matcher:script[:flags]
# flags: a=advisory (no subshell, exit code ignored)
PostToolUse:Write,Edit:post-write-tracker:a
PostToolUse:Write,Edit:quality-gate:a
```

方案 B 更通用，但需要改 manifest 格式。方案 A 更简单，直接减少文件数。

**建议采用方案 A**，将 `post-write-tracker.sh` 和 `quality-gate.sh` 合并为 `post-write-check.sh`。它们的触发条件完全相同（PostToolUse:Write,Edit,MultiEdit,CreateFile），都是 advisory，且逻辑上互补（一个检查 write-set 偏移，一个检查 self-challenge）。

#### 4b. dispatch 层缓存 manifest 解析（低优先级）

manifest.conf 解析只需 ~5ms，不值得优化。但如果 manifest 增长到 20+ 行，可以考虑缓存。当前无需行动。

**优先级：4a 方案 A = 中（减少一次 subshell，~100ms on Windows）; 4b = 低**

---

## 问题 5: 测试困难

### 现状分析

test-dispatch.sh 已经有 17 个 assertion，test-phase-guide.sh 有 58 个 assertion。它们通过以下方式解决环境依赖问题：
- 复制 dispatch.sh 到临时目录
- 创建临时的 manifest.conf 和 hook 脚本
- 注入 mock 环境变量
- 检查 stdout/stderr 和退出码

这个模式工作得不错，但有两个实际痛点：
1. **每个新 hook 的测试需要大量 boilerplate**（setup_hooks, 创建临时 manifest, 准备 JSON stdin）
2. **端到端路径测试困难**（比如测试"Cursor adapter → dispatch → write-lock → plan-parser"整条链路）

### 建议

#### 5a. 提取测试 fixture 工具库

创建 `tests/lib/hook-test-helpers.sh`，封装常见的测试 setup/teardown 模式：

```bash
# hook-test-helpers.sh

# 创建隔离的 hook 测试环境
setup_hook_env() {
    local _tmp="$1"
    mkdir -p "$_tmp/hooks/lib"
    cp "$BATON_DIR/.baton/hooks/dispatch.sh" "$_tmp/hooks/"
    cp "$BATON_DIR/.baton/hooks/lib/"*.sh "$_tmp/hooks/lib/"
    chmod +x "$_tmp/hooks/dispatch.sh"
}

# 注册一个 hook 到临时 manifest
register_hook() {
    local _tmp="$1" _event="$2" _matcher="$3" _script="$4"
    echo "${_event}:${_matcher}:${_script}" >> "$_tmp/hooks/manifest.conf"
}

# 模拟 PreToolUse stdin JSON
make_pretooluse_stdin() {
    local _tool="$1" _file="$2"
    printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$_tool" "$_file"
}

# 运行 dispatch 并捕获 stdout, stderr, exit code
run_dispatch() {
    local _tmp="$1" _event="$2"
    shift 2
    local _stdout _stderr _rc=0
    _stderr="$(mktemp)"
    _stdout="$(cd "$_tmp" && bash "$_tmp/hooks/dispatch.sh" "$_event" "$@" 2>"$_stderr")" || _rc=$?
    echo "$_stdout"
    LAST_STDERR="$(cat "$_stderr")"
    LAST_RC="$_rc"
    rm -f "$_stderr"
}
```

这不改变任何运行时代码，只降低编写新 hook 测试的门槛。

#### 5b. 单 hook 隔离测试模式

让每个 hook 脚本支持 `BATON_TEST=1` 环境变量，在测试模式下跳过 IDE 特定的 JSON 输出，只输出人可读的结果。大多数 hook 已经接近这种模式（输出到 stderr），只需要在文档中标准化这个约定。

**优先级：5a = 中（减少测试编写摩擦）; 5b = 低（约定优先于代码）**

---

## 新增建议：输入文档未涵盖的问题

### 6. JSON 解析的 jq/awk 双轨制

至少 4 个 hook（write-lock, bash-guard, post-write-tracker, failure-tracker）各自实现了 jq → awk fallback 的 JSON 解析。这些实现细节不同（有的用 awk -F'"'，有的用 sed），容错行为也不一致。

**建议**：将 JSON 字段提取提升到 `lib/common.sh` 或 `lib/json-parse.sh`：

```bash
# json_field <field_name> [json_string]
# 从 JSON 中提取顶层字段值，jq 优先，awk fallback
json_field() {
    local _field="$1"
    local _json="${2:-$BATON_STDIN}"
    [ -z "$_json" ] && return
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_json" | jq -r ".$_field // empty" 2>/dev/null
    else
        printf '%s' "$_json" | awk -F'"' -v f="$_field" '{
            for(i=1;i<=NF;i++) if($i==f) { print $(i+2); exit }
        }'
    fi
}

# json_nested <path> [json_string]
# 支持嵌套路径如 "tool_input.file_path"
json_nested() {
    local _path="$1"
    local _json="${2:-$BATON_STDIN}"
    [ -z "$_json" ] && return
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_json" | jq -r ".${_path} // empty" 2>/dev/null
    else
        # awk fallback: 只支持两级嵌套
        local _outer="${_path%%.*}"
        local _inner="${_path#*.}"
        printf '%s' "$_json" | awk -F'"' -v f="$_inner" '{
            for(i=1;i<=NF;i++) if($i==f) { print $(i+2); exit }
        }'
    fi
}
```

然后 dispatch.sh 中已有的 tool_name 提取改为：
```bash
_tool="$(json_field "tool_name")"
```

各 hook 中的 file_path 提取改为：
```bash
TARGET="$(json_nested "tool_input.file_path")"
```

**优先级：中（减少代码重复，统一 fallback 行为，降低 bug 面）**

### 7. dispatch.sh 预计算 + 导出 TARGET 变量

dispatch.sh 已经提取了 `_tool`（tool_name），但没有提取 `tool_input.file_path`。5 个 hook 各自从 `BATON_STDIN` 中重新提取这个字段。可以在 dispatch.sh 中预提取并导出为 `BATON_TARGET`（如果未设置）：

```bash
if [ -z "${BATON_TARGET:-}" ] && [ -n "$BATON_STDIN" ]; then
    export BATON_TARGET
    BATON_TARGET="$(json_nested "tool_input.file_path" "$BATON_STDIN")"
fi
```

这与问题 2 的预计算方向一致 — dispatch 做一次，hook 用多次。

**优先级：中（与问题 2 的改进一起实施）**

---

## 实施优先级排序

| 优先级 | 改进 | 预计工作量 | 风险 |
|--------|------|-----------|------|
| **P1** | 3a: 脚本存在性预检查 | 1 行代码 | 极低 |
| **P2** | 6: JSON 解析提取到 lib | ~40 行 lib + 各 hook 迁移 | 低（向后兼容） |
| **P2** | 2+7: dispatch 预计算共享上下文 | ~20 行 dispatch + 各 hook 适配 | 低（env 变量向后兼容） |
| **P3** | 4a: 合并 post-write-tracker + quality-gate | 合并两个 ~100 行脚本 | 中（需更新 manifest + tests） |
| **P3** | 5a: 测试 fixture 库 | ~60 行新文件 | 无（只影响 tests/） |
| **P4** | 1: manifest guard 列 | 不建议当前实施 | — |
| **P4** | 3b: 结构化错误输出 | 不建议当前实施 | — |

P1 可以立即实施。P2 适合作为一个小任务批量完成。P3 是独立的改进项，可以在有相关工作时顺便做。P4 是"有需要再做"的选项。

---

## Self-Challenge

**为什么不做更大的架构重构？** 比如把 dispatch 改成 pipeline 模式、引入插件注册机制、或者用 Node.js 重写？

答案是 baton 的架构约束：pure bash, zero compiled dependencies, junction-based distribution。dispatch.sh 运行在用户机器的 Git Bash 里，通过 NTFS junction 从 `~/.baton/` 分发到各项目。任何引入额外依赖或改变分发模型的改进都与这些约束冲突。

当前架构中最有价值的改进不是增加新能力，而是**减少重复**（JSON 解析、plan 发现初始化）和**减少进程启动**（合并同事件 advisory hook）。这些改进在保持架构简洁性的同时，解决实际的性能和维护性问题。

**预计算方案的风险**：dispatch.sh 承担更多职责后，它的失败影响面扩大。但由于已有 fail-open 模式和 hook 的独立调用兼容性，风险可控 — 最坏情况是预计算失败，hook 回退到自行初始化。

**合并 hook 的风险**：post-write-tracker 和 quality-gate 的关注点不同（write-set 漂移 vs self-challenge 检查），合并可能降低代码清晰度。缓解方式是在合并后的脚本中保留清晰的函数分隔。

## 批注区

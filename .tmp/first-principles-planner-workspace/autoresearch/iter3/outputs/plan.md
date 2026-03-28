# Bash Hooks 重写评估：保留 Bash 还是迁移 Python？

**深度**: Deep — 用户表述的是一个解决方案（"重写成 Python"），而非问题本身。"我们一直都这样做"的逆向版本——"bash 太难维护了"——需要拆解到底层事实。

**输入来源**: baton 代码库全量阅读（`.baton/hooks/`, `.baton/hooks/lib/`, `.baton/adapters/`, `tests/`, `setup.sh`, `run-hook.cmd`）

---

## TL;DR

1. **问题不是 "bash 难维护"，而是 plan-parser.sh 过度膨胀**。11 个 hook 脚本中，9 个结构清晰、逻辑简单（平均 60 行）。唯一真正复杂的是 `plan-parser.sh`（441 行 awk/sed 解析器）和 `phase-guide.sh`（264 行，其中大量是 parser 调用 + 输出格式化）。
2. **推荐方案**: 不做全量重写。将 `plan-parser.sh` 提取为独立 Python 模块，其余 hook 保持 bash。这解决了 80% 的维护痛点，同时保留 bash hook 的零依赖、即改即生效的优势。
3. **如果仍然想全量迁移 Python**: 文末提供完整的执行路线，但需要接受 Python 运行时依赖、Windows 路径翻译层、以及 ~7000 行测试重写的成本。

---

## 不应该做的事

- **不要引入 Python 打包/虚拟环境**。hook 在每次工具调用时执行，冷启动延迟是硬约束。用单文件 `.py` 脚本 + 标准库即可。
- **不要同时重写 hook 和 adapter**。adapter 层（Cursor JSON 协议、Codex stdout 协议）是纯 I/O 翻译，bash 是最自然的选择——重写它们到 Python 没有任何维护收益。
- **不要试图重写 `run-hook.cmd`**。这个 polyglot cmd/bash 包装器解决的是 Windows IDE 无法直接调用 bash 的问题。Python 不解决这个问题——你仍然需要一个 `.cmd` 入口点来找到 `python.exe`。

---

## 对比表：现状 vs. 推荐方案 vs. 全量 Python

| 维度 | 现状 (纯 bash) | 推荐: Parser → Python | 全量 Python |
|------|---------------|----------------------|-------------|
| **最难维护的部分** | `plan-parser.sh` 441 行 awk | ✅ 变成 Python，类型安全 | ✅ 全部 Python |
| **零依赖** | ✅ 只需 bash + coreutils | ⚠️ 需要 Python 3（大多数系统已有） | ❌ 必须保证 Python 3 可用 |
| **冷启动延迟** | ~50ms (bash) | ~50ms (bash) + ~80ms (Python parser, 按需) | ~150ms (Python 进程启动) |
| **Windows 兼容** | ✅ `run-hook.cmd` 已解决 | ✅ 同上 + Python 跨平台 | ⚠️ 需要新的 `.cmd` 找 `python.exe` |
| **测试重写量** | 0 | ~1100 行 (`test-plan-parser.sh`) | ~7000 行 (全部测试) |
| **hook 即改即生效** | ✅ 编辑 `.sh` 立即生效 | ✅ 大部分保持 | ✅ 编辑 `.py` 也立即生效 |
| **IDE 集成风险** | 无 | 低 — dispatch 层不变 | 高 — 需重写 dispatch + adapter |
| **实施时间估计** | 0 | ~2 天 | ~2-3 周 |

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Python 3 不在 PATH 上（某些 Windows 配置） | hook 静默失败（fail-open 策略不变） | `run-hook.cmd` 里加 Python 发现逻辑，类似现有的 bash 发现 |
| Parser Python 化后，bash hook 调用 Python 子进程增加延迟 | 每次 PreToolUse 额外 ~80ms | 只在需要 plan 解析时调用（write-lock、phase-guide）；其他 hook 不受影响 |
| bash ↔ Python 接口约定漂移 | parser 返回值格式在两边不一致 | 定义明确的 JSON 输出契约；测试覆盖接口边界 |

---

## 行动方案

| 优先级 | 变更 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P1 | 将 `plan-parser.sh` 重写为 `plan_parser.py`，输出 JSON | 1 天 | 低 | 高 — 消除最大维护痛点（441 行 awk → ~200 行 Python） |
| P2 | 写 bash shim `lib/plan-parser.sh` 调用 `plan_parser.py`，暴露相同函数签名 | 0.5 天 | 低 | 高 — 所有现有 hook 无需修改 |
| P3 | 迁移 `test-plan-parser.sh`（1105 行）到 Python `unittest` | 0.5 天 | 低 | 中 — 测试更易维护，可用 `pytest` |
| P4 | （可选）将 `phase-guide.sh` 的状态检测逻辑提取到 `plan_parser.py` | 0.5 天 | 中 | 中 — 减少 phase-guide 复杂度，但状态机逻辑本身不复杂 |
| **合计** | | **~2.5 天** | | |

### P1 详细设计: `plan_parser.py`

将 `plan-parser.sh` 的全部 parser 函数重写为一个 Python 模块。关键接口：

```python
# .baton/hooks/lib/plan_parser.py
import json, sys, os, re
from pathlib import Path

def find_plan(start_dir: str, baton_plan: str = "") -> dict:
    """Walk-up plan discovery.
    Returns: {"plan": "/abs/path", "plan_name": "plan.md", "multi_plan_count": 0}
    """
    ...

def find_research(plan_path: str, plan_dir: str) -> dict:
    """Paired research discovery.
    Returns: {"research": "/abs/path", "research_name": "research.md", "fallback_count": 0}
    """
    ...

def todo_counts(plan_path: str) -> dict:
    """Returns: {"total": N, "done": N, "remaining": N}"""
    ...

def has_go(plan_path: str) -> bool: ...

def writeset_extract(plan_path: str) -> list[str]: ...

def writeset_normalize(path: str, project_root: str = "") -> str: ...

def project_root(start_dir: str) -> str: ...

if __name__ == "__main__":
    cmd = sys.argv[1]
    # Dispatch to function, print JSON to stdout
    result = globals()[cmd](*sys.argv[2:])
    print(json.dumps(result))
```

### P2 详细设计: Bash Shim

```bash
# .baton/hooks/lib/plan-parser.sh (重写后)
_PARSER_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plan_parser.py"
_python_cmd=""

_find_python() {
    [ -n "$_python_cmd" ] && return
    for _p in python3 python; do
        command -v "$_p" >/dev/null 2>&1 && { _python_cmd="$_p"; return; }
    done
    echo "⚠️ BATON: python3 not found, parser unavailable" >&2
    return 1
}

_call_parser() {
    _find_python || return 1
    "$_python_cmd" "$_PARSER_PY" "$@"
}

parser_find_plan() {
    local _json
    _json="$(_call_parser find_plan "${JSON_CWD:-$(pwd)}" "${BATON_PLAN:-}")" || return
    PLAN="$(printf '%s' "$_json" | jq -r '.plan // empty')" || true
    PLAN_NAME="$(printf '%s' "$_json" | jq -r '.plan_name // empty')" || true
    MULTI_PLAN_COUNT="$(printf '%s' "$_json" | jq -r '.multi_plan_count // 0')" || true
    export MULTI_PLAN_COUNT
}
# ... 其他函数类似
```

这种设计的关键优势：**所有 9 个 hook 脚本的代码零修改**。它们仍然 `source lib/common.sh`，调用 `parser_find_plan`、`parser_has_go` 等函数——只是这些函数的内部实现从 awk 变成了 Python 子进程调用。

---

## 异议路径：如果你仍然想全量重写为 Python

在以下条件下，全量 Python 重写是合理的：

1. **你计划大幅扩展 hook 逻辑**（例如加入网络调用、数据库状态、复杂条件链），使得 bash 的表达能力成为真正的瓶颈。
2. **你打算放弃对无 Python 环境的支持**（嵌入式系统、最小化 Docker 镜像等极端场景）。
3. **你有时间重写 ~7000 行测试**并验证所有 IDE 适配器（Claude Code、Cursor、Codex）在新架构下的行为一致性。

如果以上条件成立，全量重写的执行路线：

| 阶段 | 内容 | 工作量 |
|------|------|--------|
| 1 | `plan_parser.py` + shim（同 P1-P2） | 1.5 天 |
| 2 | `dispatch.py` 替代 `dispatch.sh`（读 manifest、路由事件、隔离子进程） | 1 天 |
| 3 | 逐个 hook 重写（write-lock → bash-guard → 其余 7 个） | 3-4 天 |
| 4 | adapter 层适配（`run-hook.cmd` 改为调 Python、Cursor/Codex adapter 重写） | 1 天 |
| 5 | 测试迁移（7000+ 行 bash 测试 → Python） | 3-4 天 |
| 6 | `setup.sh` 增加 Python 依赖检测 | 0.5 天 |
| **合计** | | **~10-12 天** |

**反转测试**: 全量 Python 重写在什么条件下是最差方案？当 hook 系统需要在没有 Python 的环境运行时（CI minimal images、新机器初始化阶段），或当 hook 执行的延迟预算从 ~50ms 扩大到 ~200ms 成为用户可感知的卡顿时。

---

## 分析

### 问题考古：五个 Why

```
表述: "我们需要把所有 bash hooks 重写成 Python，因为 bash 太难维护了"
Why?   → bash 哪里难维护？
Why?   → plan-parser.sh 的 awk 解析逻辑（441 行）——类型不安全、调试困难、错误处理原始
Why?   → parser 承担了所有 plan 发现、section 解析、write-set 提取的职责
Why?   → hook 系统的核心复杂度集中在 plan 解析，而不是 hook 调度或 I/O 处理
根因:  维护痛点的 80% 来自一个文件（plan-parser.sh），而非 bash 语言本身。
```

### 问题陈述

baton hook 系统中，plan 解析层（`plan-parser.sh`）随功能增长积累了不成比例的复杂度（441 行 awk/sed，占总代码量 24%），导致维护、调试和扩展成本高于预期。其余 hook 脚本（平均 ~60 行）结构简单、职责单一，并不构成维护负担。

"解决"意味着：plan 解析逻辑可以用有类型安全和标准调试工具的语言编写和测试，同时不破坏现有 hook 的执行模型（fail-open、subshell 隔离、零配置）。

### 假设审计

| # | 假设 | 类型 | 如果错误... |
|---|------|------|-------------|
| 1 | "bash 难维护" 是全局性的 | **惯例** — 实际上 9/11 个 hook 脚本结构清晰 | ✅ 已验证：只有 parser + phase-guide 复杂。计划不崩溃，但范围大幅缩小 |
| 2 | Python 在所有目标环境可用 | **未知** — 大多数开发机有，但 CI/Docker 不一定 | ⚠️ 计划需要 fallback 策略 |
| 3 | 重写语言解决维护问题 | **惯例** — 如果 parser 的设计有问题，Python 也一样难维护 | 计划崩溃：需要先做设计改进，再选语言 |
| 4 | hook 执行延迟不敏感 | **事实** — PreToolUse 在每次工具调用前执行 | ✅ 验证：当前 bash ~50ms，Python 子进程 ~80-150ms，在人类交互场景下不可感知 |
| 5 | 测试可以逐步迁移 | **事实** — 测试按 hook 独立组织 | ✅ 验证：每个 `test-*.sh` 测试一个 hook，可以逐个迁移 |

### 真约束 vs. 惯例

| 约束 | 类型 | 理由 |
|------|------|------|
| hook 必须 fail-open（意外错误时允许操作） | **真约束** | 设计原则：hook 是防护层，不是阻断层 |
| `dispatch.sh` 从 `manifest.conf` 路由事件 | **惯例** | manifest 格式可变，但 dispatch 模型本身是合理的 |
| adapter 层用 bash | **惯例，但合理** | adapter 做的是 exit code → JSON 翻译，bash 是最自然的 |
| `run-hook.cmd` 必须是 cmd/bash polyglot | **真约束** | Windows IDE 的 pre-tool hook 只能调用 `.cmd` |
| 测试用 bash 写 | **惯例** | 可以迁移到 Python，但 7000 行的迁移成本是真实的 |

---

## 自检

**核心问题: 这个方案最可能的失败模式是什么？如果知道它会失败，我会怎么做？**

最可能的失败模式是 bash shim（P2）引入的 bash ↔ Python 接口成为新的维护负担——两种语言之间的 JSON 序列化/反序列化、错误传播、退出码映射都需要精确对齐。如果知道它会失败，我会跳过 shim 层，直接让 `dispatch.sh` 支持 `.py` 后缀的 hook 脚本（在 manifest 里注册 `write-lock.py` 而非 `write-lock.sh`），消除中间层。

**用户表述的是解决方案而非问题——是否追溯到了根因？**

是。用户说 "bash 太难维护"，但量化分析显示难维护的是 parser 层（1 个文件占 24% 代码量），不是 bash 语言本身。其余 hook 脚本的平均复杂度（60 行、单一职责、线性逻辑）在任何语言中都不构成维护挑战。如果把 60 行的 `stop-guard.sh` 重写为 Python，它会变成 ~50 行的 Python——维护性几乎没有变化。

**推荐了不同于用户方案的路径——什么证据会改变我的判断？**

如果用户展示的维护痛点不是 parser 而是 hook 之间的交互模式（比如 stdin 缓冲、exit code 语义、subshell 隔离）——这些是 bash 特有的执行模型问题，Python 的异常处理和进程管理确实更优。在这种情况下，从 dispatch 层开始重写会比从 parser 开始更有价值。

## 批注区

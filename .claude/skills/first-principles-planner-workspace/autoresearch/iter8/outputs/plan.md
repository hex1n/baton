# 规划: Bash Hooks 是否应重写为 Python

**深度**: Deep — "bash 太难维护" 带有 "we've always done it this way" 的逆向能量：不是在质疑惯例本身，而是在用一个解决方案（重写为 Python）替代对问题的定义。需要完整的假设审计。

**输入来源**: baton 代码库直接审查（11个 hook 脚本 + 3个 lib + 2个 adapter + 18个测试文件 + setup.sh + run-hook.cmd）

---

## TL;DR

"重写为 Python" 是一个**解决方案伪装成问题**。真正的问题是 hook 系统存在若干具体的维护痛点，而这些痛点中大部分可以在 bash 内部解决，少部分与语言无关。Python 重写会引入新的硬依赖，直接违反 baton 的零编译依赖架构约束，且重写成本（~8,700行代码 + 测试，跨平台验证）远超收益。**建议不重写**；如果特定痛点足够严重，下方提供了可在 bash 内部执行的改进方案，以及"如果仍然要重写"的具体路径。

---

## 行动方案

### 不应做的事

| 不做 | 原因 |
|------|------|
| 全量重写为 Python | 成本/风险远超收益；引入硬依赖违反架构约束 |
| 部分混用 Python + Bash hooks | 引入双运行时依赖，调试复杂度翻倍 |
| 引入 Python 作为必选依赖 | 破坏零编译依赖保证；Windows 上 Python 路径解析比 bash 更碎片化 |

### 应做的事（如果维护痛点真实存在）

| 优先级 | 变更 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P1 | **提取 JSON 解析为独立函数** — 当前 jq/awk 双路径散布在 dispatch.sh、write-lock.sh、bash-guard.sh、failure-tracker.sh 等 6 个文件中（每个都有 `if command -v jq ... else awk` 分支）。提取到 `lib/json.sh` 统一提供 `json_get` 函数 | 2h | Low | High — 消除最大的重复来源，也是"难维护"感受的主要来源 |
| P2 | **统一 stdin 读取模式** — 每个 hook 都有相同的 `BATON_STDIN` / `cat` / `[ ! -t 0 ]` 样板代码（~10行/hook × 8个hook）。移入 common.sh 作为 `baton_read_stdin` | 1h | Low | Med — 减少 ~80 行重复样板 |
| P3 | **统一 fail-open trap 模式** — 每个 hook 的第一行都是同一个 `trap '...' HUP INT TERM`，文案略有差异。统一为 `common.sh` 中的 `baton_trap_failopen` | 30min | Low | Low-Med — 小改善但消除不一致 |
| P4 | **为 plan-parser.sh 补充单元级注释** — 该文件 441 行，是最复杂的单一模块，但函数签名注释已经良好。痛点主要是 awk 内嵌脚本的可读性。可考虑将长 awk 脚本提取为 `.awk` 文件或加行内注释 | 1h | Low | Med — 提高最复杂模块的可读性 |
| **合计** | | **~4.5h** | | |

### 对比表: 现状 vs. P1-P4 改进后 vs. Python 重写

| 维度 | 现状 (Bash) | P1-P4 改进后 (Bash) | Python 重写 |
|------|-------------|---------------------|-------------|
| 依赖 | bash + (可选)jq | bash + (可选)jq | bash + Python 3 (必选) |
| 代码总量 | 1,674 行 hooks + 540 行 lib | ~1,400 行（减少 ~16%） | ~1,200 行（估算，含 argparse 等样板） |
| JSON 解析 | jq + awk 双路径，散布 6 文件 | 统一 `json_get`，单点维护 | `json.loads()`，内置 |
| 跨平台支持 | run-hook.cmd polyglot + cygpath 处理 | 同上 | 需要 Python 路径发现 + venv 风险 + Windows Store Python 陷阱 |
| 测试 | 7,034 行 bash 测试，全部需重写 | 不变 | 全量重写（~3,000-5,000 行 pytest 估算） |
| 部署 | junction + source，零安装 | 同上 | 需确保 Python 可用 + 可能的 shebang 差异 |
| ShellCheck CI | 现成 | 不变 | 替换为 flake8/mypy（额外配置） |
| AI Hook 协议兼容 | 原生（Claude Code hooks 是 bash 接口） | 同上 | 需要 wrapper 层翻译退出码 |

---

## 异议路径 (Dissenting Path)

### 在什么条件下 Python 重写是正确的

以下条件**全部满足**时，重写才值得：

1. **Baton 决定放弃零依赖约束** — 架构层面接受 Python 3 作为必选运行时依赖，并承担在 Windows（无 Python 预装）、CI 容器（可能无 Python）等环境的兼容性成本
2. **Hook 逻辑复杂度持续增长** — 当 hook 需要做 HTTP 请求、数据库查询、复杂状态管理等 bash 天然不擅长的事情时（目前都是文件系统操作 + 文本解析）
3. **测试重写成本可接受** — 当前 7,034 行测试全部是 bash 断言，重写为 pytest 需要 ~2-3 周投入
4. **跨 IDE adapter 层也同步重写** — cursor adapter 和 codex adapter 需要同步迁移，否则出现双运行时

### 如果仍然要重写的具体方案

1. **先写 Python dispatcher** — 替换 `dispatch.sh`（64行），证明 Python 可以作为 hook 入口点，处理 manifest 解析、stdin 缓冲、exit code 语义
2. **逐个 hook 迁移** — 按复杂度排序：quality-gate.sh (45行) → failure-tracker.sh (63行) → stop-guard.sh (52行) → ... → write-lock.sh (171行) → phase-guide.sh (264行)
3. **保留 bash 测试作为集成测试** — 不立即重写测试，让现有 bash 测试验证 Python hook 的行为等价性
4. **run-hook.cmd 改为寻找 Python** — 将 polyglot wrapper 从找 bash 改为找 python3
5. **lib/plan-parser.sh → plan_parser.py** — 最后迁移，因为这是所有 hook 的共享核心
6. **预计总工作量**: 3-4 周（含测试迁移和跨平台验证）

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| P1-P4 改进不解决"真正的"痛点 | 改完之后仍觉得难维护 | 改进之前先列出具体的维护事件（哪些 bug、哪些修改耗时过长），用事实而非感觉驱动 |
| JSON 统一函数引入新 bug | 所有 hook 的 JSON 解析都受影响 | 先保留 jq/awk 双路径在新函数内部，一个 PR 只重构调用方，不改实现 |

---

## 自检 (Self-Check)

**核心**: 这个方案最可能的失败模式是什么？

如果"bash 太难维护"的感受来源不是代码重复或可读性，而是**对 bash 语言本身的认知负担**（比如引号地狱、变量作用域规则、子 shell 陷阱），那 P1-P4 的重构不会显著改善体验。这类认知负担是语言层面的，代码重构无法消除。

但这里有一个关键的反事实：baton 的 hook 代码风格实际上相当干净。`set -eu`、fail-open traps、subshell 隔离、清晰的函数签名 — 这些都是 bash 最佳实践。如果这样的代码仍然"难维护"，问题可能不在代码质量，而在维护者对 bash 的熟悉程度。Python 重写会解决这个问题，但代价是引入一个全新的依赖类别。这是一个人 vs. 架构的权衡，两边都有合理性 — 取决于团队规模是否会扩大（目前是 solo creator）以及未来维护者的技能分布。

**因为我在反对用户的既定方案**: 如果用户提供了 2-3 个具体的"bash 让我多花了 X 时间"的维护事件，且这些事件在 Python 中确实不会发生，我会改变建议。

---

## 分析 (Phase 1-2 推理)

### Phase 1: 问题考古

#### 五个为什么

```
表述: "我们需要把 bash hooks 重写成 Python"
为什么? → "bash 太难维护了"
为什么难维护? → (需要分解 — 见下方)
```

"难维护"是一个复合感受，可能的根因分解：

| # | 可能的根因 | 代码库中的证据 | 状态 |
|---|-----------|---------------|------|
| 1 | JSON 解析的 jq/awk 双路径重复 | ✅ 6 个文件各有独立的 `if command -v jq ... else awk` 分支（dispatch.sh:25-31, write-lock.sh:35-46, bash-guard.sh:42-49, failure-tracker.sh:26-37, post-write-tracker.sh:29-39, subagent-context.sh 间接通过 dispatch） | 确认的痛点 |
| 2 | stdin 读取样板重复 | ✅ 8 个 hook 中有相同的 BATON_STDIN / cat 模式 | 确认的痛点 |
| 3 | awk 内嵌脚本可读性差 | ✅ plan-parser.sh 有 5 个 10+ 行的 awk 脚本，phase-guide.sh 有 1 个 | 确认但程度有限 |
| 4 | 跨平台兼容性处理分散 | ✅ CR stripping (dispatch.sh:37)、cygpath 调用 (junction.sh, plan-parser.sh)、run-hook.cmd polyglot | 确认但 Python 同样面临 |
| 5 | 测试写起来痛苦 | ✅ 7,034 行测试全是 bash 断言，Windows 上 15s/assertion | 确认，但这是测试框架问题而非 hook 语言问题 |
| 6 | 缺乏类型系统 / IDE 补全 | ❓ 未观察到因此导致的 bug — 但对开发体验有影响 | 可能的感受来源 |

#### 问题陈述

baton 的 hook 系统包含 ~1,674 行 bash 代码，分布在 14 个文件中，存在可量化的维护成本来源：JSON 解析逻辑在 6 个文件中重复、stdin 样板在 8 个 hook 中重复、awk 内嵌脚本降低了最复杂模块的可读性。"解决"意味着：修改任意一个 hook 时不需要理解 5 种 JSON 解析变体，新增 hook 不需要复制粘贴 30 行样板。

#### 假设审计

| # | 假设 | 类型 | 如果错误... |
|---|------|------|------------|
| 1 | "Bash 太难维护" 是因为代码重复和可读性问题 | ❓ 未验证 — 可能是语言层面的认知负担 | P1-P4 改进后仍觉得难维护 → 方案失败 |
| 2 | 零编译依赖是硬约束 | ✅ CLAUDE.md 明确写 "Pure bash + markdown. Zero compiled dependencies. jq optional (awk fallback)" | 如果这是可放弃的惯例 → Python 重写变得可行 |
| 3 | Python 在所有目标平台都可用 | ❌ Windows 10 不预装 Python；CI 容器可能不含 Python | 重写后部分环境无法运行 hook → 需要 fallback 或安装指南 |
| 4 | Hook 复杂度不会继续增长 | ❓ 取决于未来路线图 | 如果 hook 需要做 HTTP/DB/复杂状态 → bash 确实不够 |
| 5 | 测试可以保持不变 | ❌ 如果重写 hook 语言，7,034 行测试的进程调用方式全部需要更新 | 重写成本至少翻倍 |
| 6 | Claude Code hook 协议是稳定的 bash 接口 | ✅ 当前协议是 bash 脚本 + JSON stdin + exit code 语义 | 如果协议改为支持任意可执行文件 → Python 变更可行 |
| 7 | Solo creator 是长期维护模型 | ❓ 如果团队扩大且新成员不熟悉 bash → Python 降低入门门槛 | 当前 solo 模式下 bash 专精反而是优势 |

**负载承重假设**: #1 和 #2 是最关键的。假设 #1（"难维护"的根因是代码重复而非语言本身）决定了 P1-P4 是否有效。假设 #2（零依赖是硬约束）决定了 Python 重写是否可行。两个假设如果同时为假（语言本身是问题 + 零依赖可放弃），则应该重写。

### Phase 2: 约束分离

| 约束 | 类型 | 判定理由 |
|------|------|----------|
| 零编译依赖 | **真约束** — 架构决策写入 CLAUDE.md，影响部署模型（junction-based distribution 依赖零安装） | ✅ CLAUDE.md: "Pure bash + markdown. Zero compiled dependencies. jq optional (awk fallback)" |
| bash 作为 hook 语言 | **惯例** — 初始选择基于零依赖约束，但如果放弃该约束则可更换 | 由真约束派生的合理选择，而非不可更改的事实 |
| jq 可选 | **真约束** — 每个 hook 都有 awk fallback，确保无 jq 环境仍可工作 | ✅ 多处 `if command -v jq` 双路径证实 |
| 测试框架是 bash | **惯例** — 可以用任何语言写测试，只要能调用被测脚本 | 但迁移成本是真实的 |
| Hook 通过 exit code 通信 | **真约束** — Claude Code hook 协议定义 0=allow, 2=block | ✅ dispatch.sh:54-57 明确处理 |

---

## 批注区



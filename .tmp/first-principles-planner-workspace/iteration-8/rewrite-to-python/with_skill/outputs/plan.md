# 规划：Bash Hooks 维护性问题

## 深度校准

**深度：Standard+**

用户提出的是一个解决方案（"重写成 Python"），而不是一个问题。需要用 Five Whys 追溯到根因，避免把"换语言"当作问题本身。代码库总量 ~1,600 行 hooks + ~5,300 行测试，属于中等规模，有具体代码可分析。

---

## Phase 1 — 问题考古

### 输入上下文

| 维度 | 事实 |
|------|------|
| Hooks 数量 | 12 个 hooks + 1 dispatcher + 3 个 lib 文件 |
| Hook 总行数 | 1,632 行（hooks/ 目录） |
| 测试总行数 | 5,329 行（tests/ 目录，3.3x hooks 代码量） |
| 辅助脚本 | setup.sh (260行), install.sh (49行), bin/baton (239行), context-bar.sh (500+行) |
| 全项目 bash 总量 | ~2,643 行产品代码 + 5,329 行测试 = ~7,972 行 |
| Python 代码 | 0 行。项目无任何 Python 依赖 |
| 外部依赖 | jq (可选, 有 awk/sed fallback), bash 3.2+, POSIX 工具链 |
| 跨平台要求 | macOS + Linux + Windows (Git Bash) — 有 `run-hook.cmd` polyglot 包装器, cygpath 处理 |
| 调用方式 | Claude Code 通过 `settings.json` 配置的 command hooks 调用 `run-hook.cmd <event>` |

### Five Whys

**Why 1: 为什么说"bash 太难维护了"？**

没有用户给出的具体痛点陈述，需要从代码里推断。检查代码后发现以下维护摩擦点：

1. **JSON 解析的脆弱性** — 4 个 hook 都有相同的 stdin 读取 + JSON 解析 boilerplate（jq 路径 + awk fallback），~15 行重复代码 x4 ✅ 读 write-lock.sh:23-46, bash-guard.sh:34-49, post-write-tracker.sh:17-39, failure-tracker.sh:14-37
2. **字符串处理的晦涩性** — bash-guard.sh 的 `strip_quoted_segments` 用字符级循环模拟状态机（60-86行），可读性差 ✅ 读 bash-guard.sh:54-86
3. **plan-parser.sh 的复杂度** — 单文件 444 行，包含 15 个函数，plan 发现逻辑有 3 层消歧（mtime → BATON:GO → BATON_TARGET），nested while/case 结构可读性差 ✅ 读 plan-parser.sh:35-140
4. **缺乏结构化错误处理** — 所有 hook 用 `trap 'exit 0' HUP INT TERM` 实现 fail-open，没有结构化的错误报告 ✅ 读各 hook 开头
5. **测试用 bash 写，3.3x 代码量** — 测试框架是手写的 assert_eq/assert_rc，没有 fixture 管理，每个测试文件都重复 setup/teardown 模式 ✅ 读 test-plan-parser.sh:1-47

**Why 2: 为什么会有这些重复和复杂度？**

Bash 缺乏模块化原语：没有 import 系统（只有 source），没有结构化数据类型（只有字符串和数组），没有 JSON 原生支持。每个 hook 被 dispatch.sh 在 subshell 中执行，需要自己处理 stdin 输入。

**Why 3: 为什么选择了 bash 而不是一开始就用更高级语言？**

从 commit 历史看（`47a89fc Initial commit` → `bfd899e dispatch.sh` → `a6e422c v5 flat install`），项目从简单的单文件 hook 演化而来。bash 的优势是零依赖安装：用户只需 `curl | bash`，不需要预装 Python runtime。项目最初的分发约束就是"bash everywhere"。

**Why 4: 为什么零依赖安装很重要？**

baton 是一个 AI 编码助手的治理框架，目标用户是开发者。开发者机器上 bash 是确定存在的（macOS、Linux 自带，Windows 通过 Git Bash 覆盖）。安装脚本 `install.sh` 只有 49 行，用 `curl | bash` 一键安装。如果引入 Python 依赖，安装流程立刻复杂化。

**Why 5: 那根本问题到底是什么？**

根本问题不是"用了 bash"，而是**随着业务逻辑增长，bash 的语言能力不足以支撑当前的抽象需求**。具体来说：

- JSON 输入解析需要结构化数据类型 → bash 没有
- plan-parser 的多层发现逻辑需要函数组合和数据传递 → bash 只有全局变量和 stdout
- 测试需要 fixture 管理和断言库 → bash 没有标准测试框架
- 跨平台路径处理需要统一抽象 → bash 依赖 case/if 硬编码

### 问题陈述

**当前不良状态：** 随着 baton hooks 的业务逻辑增长到 ~1,600 行，bash 的语言限制导致 (a) 跨 hook 的 JSON 解析/target 解析 boilerplate 重复，(b) 复杂字符串处理（如 quote stripping）可读性差，(c) plan-parser 核心模块用全局变量+嵌套 while 管理状态，难以推理和测试。

**受影响者：** baton 的维护者和贡献者（包括 AI agent 自身——它需要理解 hook 代码来调试问题）。

**解决的样子：** hook 代码中的业务逻辑清晰可读，JSON 解析有原生支持，公共逻辑不重复，测试可以用标准框架，同时保持零/低门槛安装。

### 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|-------------|
| A1 | Python 在所有目标平台上可用 | 环境 | Windows 没有预装 Python；macOS 的系统 Python 正在被弃用（3.x 需要 Xcode CLT 或 brew）。**这是"重写为 Python"方案的最大风险** |
| A2 | 维护痛点主要在 hooks，不在 tests | 范围 | 如果测试也需要迁移，工作量翻倍。5,329 行测试 bash 也要重写 |
| A3 | Claude Code 的 hook 接口只支持 command 调用 | 接口 | 如果 hook 接口还支持其他调用方式（如 node module），可能有更好的选择 |
| A4 | 当前 hook 代码是稳定的，不需要频繁修改 | 频率 | 如果 hooks 很少改动，维护性问题的实际影响可能被高估。commit 历史显示最近一批修改集中在 v5 迁移 |
| A5 | "难维护"指的是修改和理解成本，不是 bug 频率 | 定义 | 如果实际上是 runtime bug 多，那应该加类型检查/linting，不一定要换语言 |

### 约束分离

| 条目 | 真约束 vs 惯例 |
|------|----------------|
| Hook 通过 shell command 调用 | **真约束** — Claude Code settings.json 的 hooks 配置是 `"type": "command"` ✅ 读 setup.sh:89 |
| 必须跨平台（macOS/Linux/Windows） | **真约束** — run-hook.cmd 有 Windows batch 入口 ✅ 读 run-hook.cmd |
| hooks 必须用 bash 写 | **惯例** — command 可以调用任何可执行文件 |
| 安装必须零依赖 | **惯例** — 当前设计选择，不是用户硬约束。但改变它有实际成本 |
| jq 是可选的 | **真约束** — 代码中所有 jq 调用都有 awk/sed fallback ✅ 读 write-lock.sh:35-46 |
| dispatch.sh 在 subshell 中运行每个 hook | **设计选择** — 隔离 exit code 和变量状态 ✅ 读 dispatch.sh:52 |

### Phase Gate

根本问题已经明确：**不是 "bash 不好"，而是 "当前的抽象需求超出了 bash 的语言能力上限"**。维护成本的主要驱动因素是 (1) 重复 boilerplate, (2) 嵌套控制流可读性, (3) 测试基础设施。进入解决方案设计。

---

## Phase 2 — 解决方案重建

### 方案 A：Bash 内部重构（不换语言）

**核心思路：** 保持 bash，但通过重构消除已知痛点。

**具体措施：**

1. **统一 stdin/target 解析** — 在 `dispatch.sh` 中一次性解析 JSON，export `BATON_TOOL_NAME`, `BATON_FILE_PATH`, `BATON_COMMAND`, `BATON_CWD` 等结构化环境变量。每个 hook 直接读环境变量，消除 4 处 ~15 行的重复 boilerplate。
   - 当前 dispatch.sh 已经做了 `BATON_STDIN` 和 `_tool` 的提取（行 20-31），只需扩展到 file_path/command/cwd
   - **影响：** 每个 hook 减少 ~15 行，总共减少 ~60 行重复代码

2. **plan-parser.sh 拆分** — 将 444 行拆为 3 个模块：`discovery.sh`（plan/research 查找）, `sections.sh`（Todo/Retro 解析）, `writeset.sh`（write-set 操作）。每个 <150 行。

3. **采用轻量测试框架** — 用 [bats-core](https://github.com/bats-core/bats-core) 替换手写测试框架，获得 fixture 管理、tap 输出、setup/teardown。

4. **引入 shellcheck CI** — 已有 `# shellcheck disable` 注释，说明知道 shellcheck，但没有系统化运行。

**优势：**
- 零迁移风险，增量改进
- 保持零依赖安装
- 不影响 Windows/Git Bash 兼容性
- 工作量小（~2-3 天）

**劣势：**
- 不解决 bash 的根本限制（没有结构化数据类型，没有原生 JSON）
- 复杂逻辑（如 quote stripping、多层 plan 消歧）仍然难以用 bash 优雅表达
- 测试仍需要 bash 编写

### 方案 B：Python 完全重写

**核心思路：** 将所有 hooks + lib + tests 重写为 Python。

**具体措施：**

1. 创建 `hooks/` 下的 Python 版本，保留 dispatch 架构
2. `dispatch.py` 替代 `dispatch.sh`，原生 JSON 解析
3. `plan_parser.py` 替代 `plan-parser.sh`，用 dataclass/NamedTuple 替代全局变量
4. 每个 hook 变成 Python 模块
5. 测试用 pytest
6. `run-hook.cmd` 修改为调用 `python3 dispatch.py` 替代 `bash dispatch.sh`

**优势：**
- JSON 原生支持（`json` stdlib）
- 结构化数据类型（dataclass, dict, list）
- 标准测试框架（pytest）
- 更好的错误处理（exceptions, traceback）
- AI agent 更容易理解 Python 代码

**劣势：**
- **Python 不是零依赖的** — Windows 用户可能没有 Python 3；macOS 未来可能不再预装 Python ❓ Apple 已宣告弃用系统 Python 但尚未完全移除
- **迁移量大** — ~1,600 行 hooks + ~5,300 行测试 + setup.sh 中的 hook 安装逻辑 + bin/baton CLI + run-hook.cmd polyglot wrapper
- **运行时开销** — Python 冷启动 ~50-100ms vs bash ~5ms；每次 tool use 都触发 hook，可能有感知延迟
- **双语过渡期** — 迁移过程中需要维护两套代码
- **安装复杂化** — 需要在 install.sh/setup.sh 中检测 Python 版本

### 方案 C：混合架构 — 核心逻辑 Python，薄 Bash 入口

**核心思路：** 保持 bash dispatch + hook 入口，但将复杂逻辑下沉到 Python 模块。

**具体措施：**

1. **保留 dispatch.sh** — 不变，继续做事件路由
2. **创建 `hooks/lib/baton_core.py`** — 包含 plan 发现、section 解析、write-set 逻辑、JSON 输入解析
3. **每个 hook 仍是 .sh 文件**，但复杂逻辑通过调用 `python3 baton_core.py <subcommand> [args]` 实现
4. **bash hook 层** 退化为 ~10-15 行的胶水代码：读环境变量，调 Python，检查退出码
5. **如果 Python 不可用**：fallback 到当前的纯 bash 逻辑（保留为降级路径）

**优势：**
- 增量迁移，每次迁移一个函数
- 保持 bash 入口的零依赖兼容性
- 复杂逻辑在 Python 中可读可测
- 有 fallback 机制应对无 Python 环境

**劣势：**
- 两套代码增加了维护面（虽然 fallback 路径可以逐步弃用）
- 每次 hook 调用有额外的 Python 进程启动开销
- 架构复杂度增加（bash → python 的进程间通信）
- fallback 路径如果长期不用，容易 bitrot

### 反向测试（Inversion Test）：方案 A

如果我们**不**换语言，只做 bash 内部重构，最坏情况是什么？

1. boilerplate 重复可以通过 dispatch 预解析消除 — **可解决**
2. plan-parser 拆分可以改善可读性 — **可解决**
3. quote stripping 状态机（bash-guard.sh:54-86）仍然难读 — **可忍受**，这段代码稳定后几乎不需要修改
4. 测试用 bats-core 可以改善 — **可解决**
5. 未来如果需要更复杂的 JSON 处理（比如输出结构化 JSON response 给 Claude Code）— **bash 确实力不从心**

反向测试结论：方案 A 可以解决当前 80% 的痛点。剩余 20% 的未来风险可以在需要时再决策。

### 推荐

**推荐方案 A：Bash 内部重构。**

理由：

1. **问题与解决方案不匹配** — 当前的维护痛点（重复 boilerplate、模块过大、缺少测试框架）都可以在 bash 内解决。换语言是用 sledgehammer 打 fly。
2. **Python 依赖假设不成立** — 假设 A1（Python 在所有目标平台可用）是 unverified 的，而这是 Python 方案的承重假设。Windows 用户不一定有 Python 3；baton 的 run-hook.cmd 显示 Windows 支持是明确需求。
3. **投入产出比** — 方案 A 的工作量是方案 B 的 1/10（~200 行修改 vs ~7,000 行重写），却能解决大部分痛点。
4. **风险分布** — 方案 A 是增量的，任何一步出错都可以回滚。方案 B 是 big bang，中间状态下项目不可用。
5. **实际修改频率** — 从 commit 历史看，hooks 代码在 v5 之后趋于稳定。高频修改的是 skills/（prompt 文件），不是 hooks。对稳定代码做大规模重写的 ROI 低。

### 异议路径

**如果仍然要走 Python 重写路径**，以下条件应当成立：

- Python 3.8+ 确认在 macOS/Linux/Windows 所有目标环境上可用（或者决定放弃无 Python 环境的支持）
- 有明确的未来需求需要结构化 JSON 输出（不只是 exit code + stderr 消息）
- 维护团队不是单人，有人可以 review Python 代码

如果上述条件满足，推荐走**方案 C（混合架构）**而非方案 B：先迁移 plan-parser 到 Python（最复杂、收益最大的单模块），保持其他 hook 的 bash 入口不变。观察 3 个月后再决定是否继续迁移。

具体 "if you still want to proceed" 方案：

1. 创建 `hooks/lib/baton_core.py`，实现 `plan-parser.sh` 的全部 15 个函数
2. 修改 `common.sh`，检测 Python 可用性，若可用则 `parser_find_plan()` 调用 `python3 baton_core.py find-plan --cwd "$JSON_CWD"` 替代原始 bash 逻辑
3. 保留 bash fallback
4. 测试用 pytest 写，保留 bash test 作为 integration test
5. 评估稳定后再决定下一步

---

## Phase 3 — 规划综合

### 优先级表（方案 A：Bash 内部重构）

| # | 任务 | 影响 | 工作量 | 优先级 |
|---|------|------|--------|--------|
| 1 | dispatch.sh 预解析：在 dispatch 层提取 file_path, command, cwd 到环境变量 | 消除 4 个 hook 中 ~60 行重复 boilerplate | 小 (~30 行修改) | P0 |
| 2 | 每个 hook 删除自有 JSON 解析代码，改读 dispatch 预解析的环境变量 | 配合任务 1，简化每个 hook | 小 (~60 行删除) | P0 |
| 3 | plan-parser.sh 拆分为 discovery.sh + sections.sh + writeset.sh | 可读性，每个模块 <150 行 | 中 (~100 行重新组织) | P1 |
| 4 | 引入 bats-core 测试框架，迁移 1 个关键测试文件（test-plan-parser.sh） | 验证可行性，获得 fixture/tap 支持 | 中 (~200 行) | P1 |
| 5 | 补充 shellcheck CI（GitHub Action） | 防止回归 | 小 (~20 行 workflow) | P2 |
| 6 | 迁移剩余测试文件到 bats-core | 统一测试体验 | 大 (~2000 行) | P2 |
| **Total** | | | **~2,400 行变更** | |

### 对比表

| 维度 | 当前状态 | 重构后（方案 A） |
|------|----------|------------------|
| JSON 解析重复 | 4 处 x ~15 行 = ~60 行重复 | dispatch 层统一，0 重复 |
| plan-parser 模块大小 | 444 行单文件 | 3 个 ~150 行模块 |
| hook 平均行数 | 50-170 行 | 30-100 行（去除 boilerplate） |
| 测试框架 | 手写 assert_eq/assert_rc | bats-core（标准 tap 输出） |
| 静态分析 | 无 CI | shellcheck in GitHub Actions |
| 外部依赖 | bash + jq(可选) | bash + jq(可选) + bats-core(dev) |
| 安装流程 | 不变 | 不变 |
| Windows 兼容性 | 不变 | 不变 |

### 不要做什么

1. **不要重写成 Python** — 问题可以在 bash 内解决，不需要引入新的运行时依赖和 7,000 行重写。
2. **不要同时重构 hooks 和 tests** — 先重构 hooks，确认行为不变（用现有测试验证），然后再迁移测试框架。
3. **不要重构 context-bar.sh** — 它是 500+ 行的独立脚本，有独立的性能优化逻辑（Windows 进程创建开销），和 hooks 维护性问题不相关。
4. **不要重构 setup.sh / install.sh / bin/baton** — 这些是安装/CLI 脚本，用 bash 是正确选择（安装脚本就应该用 shell 写）。
5. **不要引入 jq 硬依赖** — 保持 jq 可选 + fallback 的设计，因为 Windows/Git Bash 环境不一定有 jq。

### 自检

1. **方案 A 真的解决了"难维护"吗？** — 解决了主要痛点（重复、模块过大、缺少测试框架）。bash 的语言限制仍在，但对于当前的代码规模（~1,600 行 hook 代码），这些限制是可忍受的。
2. **有没有遗漏的痛点？** — 可能遗漏了 AI agent 在修改 bash 代码时出错率更高这个因素。但 baton 的 hooks 代码修改频率低（v5 后趋于稳定），这个因素影响有限。
3. **方案 A 的风险？** — 如果未来 hooks 需要输出结构化 JSON（不只是 exit code + stderr），bash 会力不从心。但那时可以再局部引入 Python，而不需要现在全量重写。
4. **投入产出比合理吗？** — ~2,400 行变更来改善 ~7,900 行代码的维护体验，且大部分变更是删除重复代码和组织迁移，合理。

---

## 分析

这个案例是一个经典的 "solution-as-problem" 模式：用户感受到了维护痛点，直接跳到了"换语言"这个解决方案。但 Five Whys 追溯下来，根因是 **缺乏 bash 内部的工程实践**（模块拆分、boilerplate 消除、测试框架），而不是 bash 语言本身。

关键洞察：

1. **代码量是衡量维护性的错误指标** — 1,600 行 bash 并不"大"。真正的问题是这 1,600 行中有 ~15% 是跨文件重复的 boilerplate，最大的单文件有 444 行缺乏拆分。这些是工程问题，不是语言问题。

2. **稳定代码不值得大规模重写** — 从 commit 历史看，hooks 代码在 v5 之后几乎没有改动。对低频修改的稳定代码做语言级重写，ROI 极低。精力应该花在高频修改的组件（skills prompt 文件）上。

3. **依赖是真正的约束** — Python 重写最大的问题不是工作量，而是破坏了 baton 的核心分发假设：`curl | bash` 零依赖安装。在 Windows 上引入 Python 依赖尤其危险——这正是 `run-hook.cmd` polyglot wrapper 试图解决的问题。

4. **混合架构是逃生舱** — 如果未来确实需要更多 Python 能力，方案 C 提供了增量迁移路径，而不需要 big bang 重写。现在的决策不需要是终局决策。

## 批注区


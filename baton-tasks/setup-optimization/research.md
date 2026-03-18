# Research: setup.sh 优化分析

## Frame

- **Question**: setup.sh 1621 行，有哪些具体的优化空间？什么方向收益最大？
- **Why**: 决定是否/如何重构 setup.sh，以及优先级
- **Scope**: setup.sh 结构分析、重复模式识别、复杂度热点定位
- **Out of scope**: 实际重构实施、功能变更
- **Constraints**: 纯 POSIX shell，需要支持 macOS/Linux/Windows(MSYS)

## Orient

- **System familiarity**: deep — 本会话中深度阅读了 setup.sh 的大部分代码
- **Evidence type**: codebase-primary
- **Strategy**: 按功能区域量化行数 → 识别重复模式 → 定位复杂度热点 → 判断优化方向

## Investigation Methods

1. [CODE] 直接阅读 setup.sh 全文，逐函数分析
2. [CODE] grep 函数定义行号，计算各区域行数

## Investigation

### Move 1: 结构分析 — 按功能区域量化行数

setup.sh 1621 行，44 个函数。按功能区域划分：

| 区域 | 行号范围 | 行数 | 占比 | 内容 |
|------|---------|------|------|------|
| 头部 + 参数解析 | 1-132 | 132 | 8% | usage, set -eu, 参数循环 |
| JSON 操作 | 134-375 | 242 | 15% | jq 封装：edit, count, remove hooks, cleanup |
| 卸载路径 | 377-486 | 110 | 7% | uninstall 全流程 |
| IDE 工具函数 | 489-770 | 282 | 17% | 版本检测、IDE 检测/选择/解析、install_versioned_script, install_adapter |
| 原子操作 | 771-856 | 86 | 5% | atomic_copy, atomic_link, atomic_link_dir, resolve_skill_source_dir |
| 技能安装 | 857-955 | 99 | 6% | install_skills |
| JSON merge 工具 | 957-1145 | 189 | 12% | merge_json_with_jq, merge_nested/flat_hook_entry, normalize, remove, ensure_default, codex trust |
| configure_claude | 1147-1306 | 160 | 10% | Claude Code IDE 配置（hooks JSON 构建、settings.json merge、CLAUDE.md @import） |
| configure_factory | 1307-1312 | 6 | 0.4% | 直接调用 configure_claude |
| configure_cursor | 1313-1379 | 67 | 4% | Cursor IDE 配置 |
| configure_codex | 1380-1479 | 100 | 6% | Codex IDE 配置（hooks.json、config.toml、trust） |
| Main flow | 1481-1621 | 141 | 9% | 安装主流程 + 输出 |

**Finding**: 三大复杂度热点：[CODE] setup.sh ✅
1. **JSON 操作** (242 行, 15%) — jq 封装 + hook 清理逻辑
2. **IDE 工具函数** (282 行, 17%) — 大量是 IDE 检测/选择的 UI 逻辑
3. **JSON merge 工具** (189 行, 12%) — hook 条目的合并/删除/标准化

JSON 相关（操作 + merge + configure_claude 中的 JSON 构建）合计 ~590 行，占 **36%**。

### Move 2: 重复模式识别

**Pattern A: jq 前置检查重复** [CODE] setup.sh:138,191,225 ❌
```sh
if ! command -v jq >/dev/null 2>&1; then return 2; fi
if ! jq empty "$_file" >/dev/null 2>&1; then return 3; fi
```
这两行在 4 个函数中重复出现（json_edit_with_jq, baton_hook_count_in_json_file, json_dot_baton_path_ref_count, remove_baton_hooks_from_json_file）。

**Pattern B: jq hook 遍历逻辑重复** [CODE] setup.sh:197-220,231-253,259-292 ❌
三个函数各自定义了几乎相同的 jq 函数（`hook_command`, `baton_ref`/`dot_baton_ref`, `event_entries`），然后用不同方式遍历。这些 jq 函数应该被提取为共享的 jq 片段。

**Pattern C: cleanup_baton_json_hook_file 的 case 重复** [CODE] setup.sh:303-315,328-341,345-358 ❌
三段几乎相同的 error-handling case 语句，只有错误消息文案不同。

**Pattern D: configure_* 函数的结构重复** [CODE] setup.sh:1147-1479 ❌
`configure_claude` (160 行)、`configure_cursor` (67 行)、`configure_codex` (100 行) 都做同类事情：
1. 检查/创建 hooks JSON
2. Merge hook 条目
3. 配置 @import 或 rules

但各用不同格式（Claude 用 settings.json，Cursor 用 hooks.json，Codex 用 hooks.json + config.toml），导致难以抽象。

**Pattern E: IDE 选择 UI** [CODE] setup.sh:610-700 ❌
`parse_ide_choice` (50 行) + `choose_ides` (27 行) + `detect_ides` (17 行) = 94 行纯 UI/交互逻辑。对于一个安装脚本来说，这部分过于复杂。

### Move 3: 复杂度热点深入

**热点 1: JSON 操作 (合计 ~590 行, 36%)**

根因：baton 需要操作 3 种不同的 JSON 配置文件格式（Claude settings.json、Cursor hooks.json、Codex hooks.json），且需要处理 jq 不可用的情况。这导致每种操作都需要双路径（jq / awk fallback）。

观察：
- `merge_json_with_jq` (23 行) + `merge_nested_hook_entry` (16 行) + `merge_flat_hook_entry` (17 行) — 三个合并策略
- `normalize_nested_hook_matcher` (18 行) + `remove_single_command_hook_entry` (18 行) — 标准化和删除
- `ensure_json_default` (9 行) + `record_merge_status` (8 行) + `run_merge_and_record` (10 行) + `report_merge_result` (11 行) — merge 辅助函数

这些函数各自很小（10-25 行），但组合起来很多。而且它们的 jq filter 中有大量重复的 hook 遍历逻辑。

**热点 2: 卸载路径 (110 行)**

卸载需要清理 4 种 IDE 的配置 + skills + legacy hooks。逻辑是线性的但涵盖面广。每种 IDE 的清理路径略有不同，难以抽象。

**热点 3: configure_claude (160 行)**

这是最长的单个配置函数。它需要：
- 构建一个完整的 hooks JSON 对象（40 行的 heredoc）
- 处理新建 vs 合并（用 jq merge 9 个 hook 条目）
- 配置 CLAUDE.md @import
- 处理 workflow.md → constitution.md 迁移

## Counterexample Sweep

**Leading interpretation**: JSON 操作是最大优化点，应该首先重构。

**Disproving evidence sought**: 是否有更根本的结构性改进，使得 JSON 操作的复杂度自然消失？

**What was checked**:
- 能否用文本操作替代 jq？不能——JSON 结构复杂，awk 替代更差 [CODE] ✅
- 能否减少需要操作的 JSON 文件？不能——由 IDE 决定 [CODE] ✅
- 能否将 JSON 操作拆到独立文件？可以——但 setup.sh 需要是单文件可执行的 ❓

**Result**: JSON 操作确实是最大优化点。但"单文件可执行"约束需要确认。

**Effect on confidence**: 如果允许拆分为多文件，优化空间显著增大。如果必须单文件，优化空间在于减少重复。

## Self-Challenge

1. **最弱结论**: "configure_* 难以抽象" — 可能通过数据驱动（配置表描述每种 IDE 的差异）来统一，但 shell 脚本的数据驱动能力有限。
2. **没有调查的**: setup.sh 是否必须是单文件？是否可以 `source` 其他文件？这影响重构策略。
3. **未验证的假设**: 假设 JSON 重复是最大痛点，但实际维护中可能 configure_* 函数的逐 IDE 修改才是最常见的改动。

## Self-Review

1. 问题是"setup.sh 太长，怎么优化"。分析聚焦于结构和重复，没有偏向特定解决方案。
2. 没有忽略根本不同的方向——比如换用 Python/Node 重写、用模板引擎生成。
3. 每个发现都引用了具体行号。

## One-Sentence Summary

"In the context of setup.sh optimization, investigating 1621 lines of POSIX shell, I found JSON operations account for 36% of code with significant duplication in jq hook traversal patterns, with medium confidence, accepting uncertainty about whether the single-file constraint is hard."

## Final Conclusions

### C1: JSON 操作是最大优化点 (36%, ~590 行)
- **Confidence**: high — 行数统计 + 重复模式都指向这里
- **Evidence**: [CODE] setup.sh:134-375 (JSON 操作), 957-1145 (JSON merge), 1147-1306 (configure_claude JSON 构建)
- **Verification path**: 提取共享 jq helper 函数（hook_command, baton_ref, event_entries），量化减少的行数
- **Uncertainty**: 重构后是否仍然可读
- **Plan implication**: actionable

### C2: jq hook 遍历逻辑是最具体的重复 (~100 行可消除)
- **Confidence**: high — 三个函数各自定义相同的 jq 函数
- **Evidence**: [CODE] setup.sh:197-220, 231-253, 259-292
- **Verification path**: 将 hook_command/baton_ref/event_entries 提取为共享 jq 变量，传入每个调用
- **Uncertainty**: jq 的变量作用域是否支持这种提取
- **Plan implication**: actionable

### C3: cleanup_baton_json_hook_file 的重复 error handling (~30 行可消除)
- **Confidence**: high — 三段近乎相同的 case 语句
- **Evidence**: [CODE] setup.sh:303-315, 328-341, 345-358
- **Verification path**: 提取 `_check_jq_status` 辅助函数
- **Uncertainty**: none
- **Plan implication**: actionable

### C4: configure_* 函数抽象空间有限
- **Confidence**: medium — 每种 IDE 的配置格式和流程差异大
- **Evidence**: [CODE] setup.sh:1147-1479
- **Verification path**: 尝试数据驱动方式，评估代码是否更简还是更复杂
- **Uncertainty**: shell 数据驱动能力有限，强行抽象可能更难读
- **Plan implication**: judgment-needed

### C5: 是否拆分为多文件是关键架构决策
- **Confidence**: high — 单文件 vs 多文件决定了优化上限
- **Evidence**: [DESIGN] 当前是单文件 1621 行
- **Verification path**: 确认 setup.sh 是否有单文件分发约束
- **Uncertainty**: 不确定是否有这个约束
- **Plan implication**: judgment-needed

### C6: 预期优化效果
- **Confidence**: medium — 基于重复模式估算
- **Evidence**: 综合 C1-C3
- **Verification path**: 实施后量化
- **Uncertainty**: 实际减少量可能偏离估算
- **Plan implication**: watchlist

保守估算，不拆文件、只消除重复的优化空间约 **130-200 行**（从 1621 降到 ~1420-1490）。如果拆文件（JSON 操作独立模块），可能降到 ~1000 行以下。

## Questions for Human Judgment

**Blocks plan**:
1. setup.sh 是否必须保持单文件？还是可以 `source` 其他文件（如 `lib/json-ops.sh`）？这决定了优化上限。
    不一定保持单文件
**Can wait for implementation**:
2. configure_* 函数是否值得尝试抽象？还是当前的逐 IDE 分离已经足够清晰？
   可以尝试抽象

**Out of scope but related**:
3. 是否考虑过用其他语言（Python/Node）重写 setup.sh？这是一个更根本的方向，但会引入运行时依赖。
   如果使用node呢?

## 补充调查: Node.js 重写可行性

**Question**: 用 Node.js 重写 setup.sh 是否可行？

**Finding**: README.md 第 204 行明确声明 baton 的设计原则是 **"Zero dependencies — jq optional (falls back to awk), no Python, no Node.js"**。[CODE] README.md:204 ✅

**分析**:

| 维度 | Shell (当前) | Node.js |
|------|-------------|---------|
| 运行时依赖 | 无（POSIX shell 普遍可用）| 需要 Node.js |
| JSON 处理 | 痛苦（jq + awk fallback）| 原生，轻松 |
| 跨平台 | POSIX 兼容但 Windows 需要 MSYS/Git Bash | 原生跨平台 |
| 测试 | shell 测试较脆弱 | Jest 等成熟框架 |
| 用户群 | 所有用户都有 shell | Claude Code 用户有 Node.js，但 baton 定位不限于 Claude Code |

**核心矛盾**: baton 支持 4 种 IDE（Claude Code、Cursor、Codex、factory），其中 Claude Code 和 Codex 的用户确实有 Node.js。但 baton 的设计原则是零依赖——这不仅仅是技术决策，也是产品定位：任何环境都能用。

**三种路径**:

1. **保持 shell，拆文件优化** — 保持零依赖原则，通过 `source lib/*.sh` 拆分。预期从 1621 行降到主文件 ~600 行 + 库文件 ~800 行，总量略减但可维护性大幅提升。
2. **Node.js 重写** — 放弃零依赖原则。JSON 操作（36% 的代码）会大幅简化。但需要修改 README 的设计原则声明，且需要 package.json + 可能的 node_modules。
3. **混合方案** — 保持 shell 入口，JSON 重操作委托给 Node.js 脚本（可选，类似 jq 的可选依赖）。保持零依赖但有 Node.js 时更高效。

**结论**: 是否放弃零依赖原则是一个产品决策，不是技术决策。[HUMAN] ❓

## 批注区
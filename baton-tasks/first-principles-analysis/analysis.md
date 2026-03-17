# Baton 第一性原理分析

## 一、Baton 是什么

Baton 是一个 **AI 辅助开发的治理框架**。它通过规则注入、hook 拦截、技能路由三层机制，约束 AI coding agent（Claude Code / Cursor / Codex）按照 "先调研 → 再计划 → 人类批准 → 才能写代码" 的流程工作。

核心假设：**AI agent 有能力但缺乏纪律**。不加约束的 AI 会跳过调研直接写代码、忽视边界条件、在发现问题后继续执行而非停下来。Baton 的存在就是为了解决这个问题。

---

## 二、架构视角

### 分层结构

```
L4  Phase Skills        baton-research / plan / implement / review
L3  Extension Skills    baton-debug / baton-subagent
L2  Hooks               12 个 shell 脚本 (8 种事件)
L1  Constitution        always-loaded 不变量 (355 行)
L0  IDE Integration     dispatch.sh + adapters + setup.sh
```

### 关键架构决策

**1. Dispatch + Manifest 模式**

`dispatch.sh` 是单一入口点。它读取 `manifest.conf` 中的 `event:matcher:script` 映射，在子 shell 中执行各 hook。这种设计：
- 新增 hook 只需加一行 conf + 一个脚本，无需修改 dispatch
- 子 shell 隔离了变量状态和退出码
- `BATON_STDIN` 缓冲 stdin 一次，多个 hook 可共享访问

**2. Junction 分发**

`junction.sh` 实现了 NTFS junction → symlink → copy 的三级回退。所有项目中的 `.baton/` 和 skill 目录都是指向源仓库的 junction，不是拷贝。这保证了：
- 更新源仓库 = 所有项目即时生效
- 无版本漂移
- 但代价是 Windows 特有的复杂性（mklink /J 的引号处理、cygpath 转换）

**3. Fail-Open 设计**

每个 hook 开头都有：
```bash
trap 'echo "⚠️ ..." >&2; exit 0' HUP INT TERM
```
hook 出错时放行操作而非阻塞工作。这是一个重要的工程判断——宁可偶尔漏过一次检查，也不要因为 hook 自身的 bug 导致用户无法工作。

**4. 多 IDE 适配**

| IDE | 能力层级 | 机制 |
|-----|---------|------|
| Claude Code | 完整执行 | 8 种事件 hook，PreToolUse 可硬阻断 |
| Factory | 同 Claude Code | 共享 .claude/ 配置 |
| Cursor | 部分执行 | dispatch-cursor.sh 翻译 JSON 协议（`allow`/`block`），但缺少 post-write-tracker、completion-check 等 |
| Codex | 仅指导 | 只有 SessionStart + Stop，无硬阻断能力 |

这是一个 **渐进式降级** 策略，不是 all-or-nothing。

---

## 三、治理模型视角

### 权限棘轮

Baton 的核心创新是 **权限棘轮**（permission ratchet）：

```
无 plan → 🔒 blocked (write-lock)
有 plan, 无 GO → 🔒 blocked (annotation cycle)
有 plan + GO → ✅ allowed (within write set)
有 plan + GO + discovery → 🔒 re-blocked if Q1/Q2 triggered
```

三个只有人类能放置的标记构成权限模型的硬边界：
- `<!-- BATON:GO -->` — 授权执行
- `<!-- BATON:OVERRIDE -->` — 覆盖不变量
- `<!-- BATON:COMPLETE -->` — 确认完成（human confirms, AI may add）

**关键观察**：这些标记的权威性完全依赖 AI 的合作——hook 层面并不阻止 AI 编辑 markdown 中的这些标记（`.md` 文件 always allowed）。这是一个有意识的设计权衡：markdown 写入权限是研究和计划阶段工作的前提，而标记的约束通过规则注入（constitution.md always loaded）来执行。

### Discovery Protocol 的精妙之处

三问发现协议（Q1/Q2/Q3）是整个治理框架中最精心设计的部分：

- **Q1** 问"批准的前提还成立吗？"——如果不成立，之前的 BATON:GO 无效，因为它授权的是在特定假设下的执行
- **Q2** 问"执行计划需要改吗？"——如果需要，BATON:GO 也无效，因为它授权的是一个不再适用的计划
- **Q3** "都不是"——记录发现，继续执行

这模拟了现实工程中的 "stop work authority"——当施工条件与审批时不同，施工方有义务停工并报告，而非继续按原图纸施工。

### Evidence Model 的作用

证据标签（`[CODE]`, `[DOC]`, `[RUNTIME]`, `[HUMAN]`）+ 状态标记（✅/❌/❓）不是文档装饰，它们是 **可审计追踪的基础设施**：
- 强制 AI 区分 "我看到了"（evidence）和 "我觉得"（inference）
- `[HUMAN] ❓` 的设计尤其巧妙——人类说的话默认标记为未验证，防止 AI 盲目执行用户的事实性断言
- Challenge Model 中，挑战强度与证据保真度挂钩：runtime > code > human directive > reasoning，且反驳必须提供同等或更高保真度的证据

---

## 四、数据流视角

### Hook 信息流图

```
SessionStart ──→ phase-guide.sh ──→ 检测当前阶段 ──→ 注入指导 + using-baton context
PreToolUse ──→ write-lock.sh ──→ 检查 plan + GO ──→ block / allow (+ additionalContext)
             ──→ bash-guard.sh ──→ 解析 shell 命令 ──→ 检测文件写入模式 ──→ block / allow
PostToolUse ──→ post-write-tracker.sh ──→ 检查文件是否在 write set ──→ warn
            ──→ quality-gate.sh ──→ 检查 Self-Challenge 存在 ──→ warn
SubagentStart ──→ subagent-context.sh ──→ 注入 Todo 进度
Stop ──→ stop-guard.sh ──→ 提醒未完成项
TaskCompleted ──→ completion-check.sh ──→ 强制 Retrospective
PostToolUseFailure ──→ failure-tracker.sh ──→ 累计失败计数 ──→ 3/5 阈值警告
PreCompact ──→ pre-compact.sh ──→ 保存关键上下文
```

### plan-parser.sh：共享数据层

plan-parser.sh 提供三组原语，被所有 hook 通过 `_common.sh` 共享使用：

| 组 | 原语 | 用途 |
|----|------|------|
| 1A 发现 | `parser_find_plan`, `parser_find_research`, `parser_has_go`, `parser_project_root` | 定位 plan/research 文件 |
| 1B 段落 | `parser_todo_counts`, `parser_todo_items`, `parser_retro_valid` | 解析 Todo 和 Retrospective |
| 1C 写集 | `parser_writeset_extract`, `parser_writeset_contains` | 提取和检查 Files: 字段 |

这种设计避免了每个 hook 重复实现 plan 解析逻辑。但它也引入了一个 **隐含耦合**：所有 hook 依赖 parser 的行为语义——如果 parser 对"什么是 Todo 项"的定义变了（比如 `^- \[` 的正则），所有 hook 同时受影响。

---

## 五、阶段生命周期视角

### 状态机

phase-guide.sh 实现了一个基于优先级的状态检测：

```
FINISH        ← plan + GO + todos done        (最高优先级)
AWAITING_TODO ← plan + GO + no todos
IMPLEMENT     ← plan + GO + todos exist
ANNOTATION    ← plan + no GO
PLAN          ← research exists, no plan
RESEARCH      ← nothing exists                (最低优先级，默认)
```

**注意**：这不是显式状态转换（"从 A 转到 B"），而是 **每次从头检测**。每次 SessionStart 都重新扫描文件系统确定当前状态。这意味着：
- 状态天然与文件系统同步，无持久化状态可能过期
- 但也意味着无法检测非法状态转换（比如从 RESEARCH 直接跳到 IMPLEMENT）

### 阶段间的衔接

| 转换 | 信号 | 门控 |
|------|------|------|
| RESEARCH → PLAN | research 文件存在 + Final Conclusions | phase-guide 检查 |
| PLAN → ANNOTATION | plan 文件创建 | 自然转换 |
| ANNOTATION → IMPLEMENT | 人类添加 `BATON:GO` | 人类主动行为 |
| IMPLEMENT → FINISH | 所有 Todo [x] | parser_todo_counts |
| FINISH → COMPLETE | Retrospective + 人类确认 | completion-check 强制 |

---

## 六、Skill 设计视角

### Skill 之间的关系

```
using-baton (协调层，SessionStart 注入)
├── baton-research (RESEARCH 阶段权威)
│   ├── template-codebase.md
│   ├── template-external.md
│   ├── review-prompt-codebase.md
│   └── review-prompt-external.md
├── baton-plan (PLAN 阶段权威)
│   └── review-prompt.md
├── baton-implement (IMPLEMENT 阶段权威)
│   ├── review-prompt.md
│   └── baton-subagent (并行调度扩展)
└── baton-review (跨阶段对抗审查)

baton-debug (IMPLEMENT 时调查扩展)
```

### 每个 Skill 的设计模式

所有四个阶段 skill 共享相同的结构：

1. **Iron Law** — 不可违反的硬规则（3-5 条）
2. **Red Flags** — "如果你在想这个，停下来"表格（防御性认知检查）
3. **When to Use / NOT to use** — 明确的触发和排除条件
4. **The Process** — 编号步骤，每步有明确的输入/输出/验证
5. **Self-Challenge + Review** — 引用 shared-protocols.md 的通用协议

Red Flags 表格是一个特别有效的设计——它直接命名了 AI agent 的常见认知偏差（"这个变更很小不需要审批"、"测试通过了不需要自检"），比抽象规则更容易激活正确行为。

### baton-review 的 context: fork

`context: fork` 前端标记使 baton-review 在独立上下文中执行，看不到生成过程的推理。这是 **context isolation** 设计——审查者不应该受到创作者心理状态的影响。这模拟了现实中代码审查的原则：审查者基于产物本身做判断，而非基于作者的解释。

---

## 七、测试视角

### 测试覆盖矩阵

| 模块 | 测试文件 | CI | 跨平台 |
|------|---------|-----|--------|
| write-lock | test-write-lock.sh | ✅ | ubuntu + macos |
| phase-guide | test-phase-guide.sh | ✅ | ubuntu |
| stop-guard | test-stop-guard.sh | ✅ | ubuntu |
| bash-guard | test-bash-guard.sh | ✅ (shellcheck) | — |
| dispatch | test-dispatch.sh | — | — |
| junction | test-junction.sh | — | — |
| plan-parser | test-plan-parser.sh | — | — |
| adapters | test-adapters.sh, test-adapters-v2.sh | ✅ | ubuntu |
| setup | test-setup.sh | ✅ | ubuntu + macos |
| multi-IDE | test-multi-ide.sh | ✅ | ubuntu |
| annotation | test-annotation-protocol.sh | ✅ | ubuntu |
| constitution | test-constitution-consistency.sh | ✅ | ubuntu |
| IDE capability | test-ide-capability-consistency.sh | ✅ | ubuntu |
| CLI | test-cli.sh | ✅ | ubuntu |
| new hooks | test-new-hooks.sh | ✅ | ubuntu |

### 测试空白

- `failure-tracker.sh`, `quality-gate.sh`, `subagent-context.sh`, `pre-compact.sh` 没有独立测试文件（可能在 test-new-hooks.sh 中覆盖？）
- `dispatch.sh`, `junction.sh`, `plan-parser.sh` 有测试文件但不在 CI 中
- 开发者在 Windows 上，但 CI 只跑 ubuntu/macos——本地环境和 CI 环境不完全一致
- 没有端到端集成测试验证完整的 hook 链路

---

## 八、张力与权衡

### 1. Context 窗口成本 vs 治理完整性

constitution.md（355 行）always loaded + using-baton SKILL.md（~93 行）SessionStart 注入 ≈ 每个 session 消耗 ~450 行的治理上下文。对于简单任务，这是显著的 overhead。但如果不 always-load，规则可能在 compact 后丢失。

当前的缓解策略：
- pre-compact.sh 在压缩前保存关键上下文
- phase-guide.sh 在 SessionStart 注入阶段特定指导

### 2. 硬执行 vs 软执行

| 层面 | 硬执行 | 软执行 |
|------|--------|--------|
| 源码写入 | write-lock.sh (exit 2 block) | — |
| Shell 写入 | bash-guard.sh (exit 2 block) | — |
| BATON:GO 标记权限 | — | 仅规则指令（"AI must never add"） |
| Write set 边界 | — | post-write-tracker.sh (warning) |
| Retrospective | completion-check.sh (exit 2 block) | — |
| Self-Challenge | — | quality-gate.sh (warning) |
| 证据标签 | — | 仅技能指令 |

关键的 **执行 gap**：markdown 写入始终放行。这意味着 AI 理论上可以：
- 修改 plan.md 添加 `BATON:GO`（规则禁止，但 hook 不阻止）
- 修改 research.md 删除不利发现
- 跳过 `## 批注区`

这是一个有意识的权衡：markdown 写入是工作流程的核心需求，不能被阻断。

### 3. 通用性 vs 特化

Baton 同时支持 4 种 IDE，但能力差异显著。Codex 用户只得到 "rules + guidance"，write-lock 完全不生效。这意味着同一个 constitution.md 在不同 IDE 上的执行强度完全不同，但文档没有区分"这条规则有 hook 执行"和"这条规则仅靠 AI 自律"。

### 4. 过程严格性 vs 开发效率

对于简单任务（改个 typo），完整流程 (research → plan → annotation → GO → implement → retrospective → complete) 是过度的。Baton 通过复杂度分级（Trivial/Small/Medium/Large）和 "simple changes may skip research" 来缓解，但判断权在 AI——而 constitution 的 Core Invariant 4 说 "approved scope is a hard boundary"，这之间存在张力。

### 5. 中文元素

`## 批注区` 作为必需的文档节名是一个值得注意的设计选择。它：
- 对中文用户有天然的语义清晰度
- 但对非中文用户是一个不透明的标记
- 在 constitution 的 Artifact Model 中是硬性要求（"A document without `## 批注区` is incomplete"）

---

## 九、创新点

1. **Discovery Protocol** — 在 AI agent 领域首次看到将工程安全管理的 "stop work authority" 概念形式化为 Q1/Q2/Q3 决策树
2. **Evidence fidelity hierarchy** — Challenge Model 中 runtime > code > human > reasoning 的证据保真度排序，以及 "反驳必须提供同等或更高保真度证据" 的规则
3. **Context-isolated review** — `context: fork` 实现的生成-审查分离
4. **Capability-tiered multi-IDE** — 不是要求所有 IDE 支持完整功能，而是在每个 IDE 上提供最大可行能力
5. **Fail-open hooks** — 治理系统的异常不应阻塞被治理的工作
6. **Red Flags 认知检查表** — 直接命名 AI 的常见推理缺陷，比抽象规则更有效

---

## 十、风险与改进方向

| 风险 | 严重度 | 当前缓解 | 可能改进 |
|------|--------|---------|---------|
| Markdown 写入无法阻断关键标记 | 中 | 规则指令 | 可在 write-lock 中特化检查：如果目标是 plan.md 且变更包含 `BATON:GO`，则阻断 |
| Windows Git Bash 性能 | 低-中 | Fail-open | 可考虑 PowerShell 原生 hook 或缓存策略 |
| Context 窗口消耗 | 低 | pre-compact 保存 | 可考虑 constitution 精简或条件加载 |
| 部分 hook 无 CI 测试 | 低 | 可能在 test-new-hooks.sh 中 | 将 dispatch/junction/parser 测试加入 CI |
| plan-parser walk-up 复杂度 | 低 | 测试覆盖 | 可考虑简化发现逻辑或限制搜索深度 |
| Codex 无硬执行 | 中 | "rules + guidance" 标签 | 受限于 Codex hook API，无法从 Baton 侧改进 |

---

这是对 Baton 作为一个 **AI agent 治理系统** 的第一性原理分析。核心判断：Baton 在 AI coding agent 领域解决了一个真实且重要的问题（agent 纪律性），其治理模型设计精良（evidence-based, ratcheted authorization, fail-open enforcement），主要技术风险在于 shell 执行环境和跨 IDE 能力差异。

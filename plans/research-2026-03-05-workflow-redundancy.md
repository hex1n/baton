# Research: workflow.md / workflow-full.md / hooks 的职责与冗余分析

## 研究范围

分析 `.baton/` 目录下三层机制之间的关系：
1. **workflow-full.md** (371行, ~2953词) — 完整工作流文档
2. **workflow.md** (65行, ~724词) — 精简版工作流文档
3. **hooks/** (8个脚本) — 运行时行为控制钩子
4. **CLAUDE.md** — 当前使用 `@.baton/workflow-full.md` 引用

## 核心发现

### 1. workflow.md 与 workflow-full.md 的精确差异

两个文件**前65行完全相同**（workflow.md 的全部内容）。workflow-full.md 额外包含307行，覆盖：

| 段落 | 仅在 full 中 | 内容摘要 |
|------|-------------|----------|
| [RESEARCH] Research Phase | ✅ | 执行策略、证据标准、自审、批注区格式 |
| [PLAN] Plan Phase | ✅ | 方法分析、First Principles、批注区格式 |
| [ANNOTATION] Annotation Cycle | ✅ | 完整流程、Log格式、响应原则、回写纪律 |
| [IMPLEMENT] Implementation Phase | ✅ | 逐项执行序列、质量检查、完成流程 |

**workflow.md = workflow-full.md 的前65行（仅 Mindset + Flow + Rules + Session handoff）**

### 2. workflow.md 的设计意图

`setup.sh:177-184` 定义了关键逻辑：

```sh
# IDEs that support SessionStart hook get slim workflow; others get full
ide_has_session_start() {
    case "$1" in
        claude|factory|cursor|cline|augment|kiro|copilot) return 0 ;;
        *) return 1 ;;
    esac
}
```

`setup.sh:674-683`：
```sh
if any_has_session_start "$IDES"; then
    cp workflow.md → target   # slim
else
    cp workflow-full.md → target as workflow.md  # full
fi
```

**设计意图**：对支持 SessionStart hook 的 IDE，用 slim workflow + phase-guide.sh 的阶段性注入 = 等效于 full workflow。对不支持 hook 的 IDE（windsurf/zed/codex/roo），把 full 直接塞进规则文件。

### 3. phase-guide.sh 与 workflow-full.md 的内容重叠

phase-guide.sh（`setup.sh:5` 注释: `Guidance text intentionally duplicates workflow-full.md sections`）是一个状态机，检测当前阶段并输出**对应阶段的详细指南**：

| 状态 | 检测条件 | 输出内容 |
|------|----------|----------|
| ARCHIVE | plan + GO + 全部 todo 完成 | 归档提示 |
| AWAITING_TODO | plan + GO + 无 `## Todo` | 等待 todolist 生成 |
| IMPLEMENT | plan + GO | 逐项执行序列（~20行） |
| ANNOTATION | plan 存在, 无 GO | 完整注解响应指南（~25行） |
| PLAN | research 存在, 无 plan | 方法分析指南（~20行） |
| RESEARCH | 无文件 | 研究执行策略（~20行） |

**关键事实**：phase-guide.sh 的指南内容是 workflow-full.md 对应段落的**精简摘要**，而非完整复制。例如：
- workflow-full.md 的 [ANNOTATION] 段有完整的 Log 格式、[RESEARCH-GAP] 处理、动态复杂度调整等
- phase-guide.sh 的 ANNOTATION 输出只有核心的响应原则和 Log 记录要求

### 4. Hooks 各自的独立职责

| Hook 脚本 | 触发时机 | 能力 | 功能 |
|-----------|----------|------|------|
| **write-lock.sh** | PreToolUse (Edit/Write) | 阻断 (exit 1) | BATON:GO 写锁 — 核心执行机制 |
| **phase-guide.sh** | SessionStart | 注入信息 | 阶段检测 + 上下文指南 |
| **bash-guard.sh** | PreToolUse (Bash) | 仅警告 (exit 0) | Bash 可能写文件时的提醒 |
| **stop-guard.sh** | Stop | 仅提醒 (exit 0) | 会话结束时的进度/归档提醒 |
| **post-write-tracker.sh** | PostToolUse (Edit/Write) | 仅警告 (exit 0) | 修改文件不在 plan 中的检测 |
| **completion-check.sh** | TaskCompleted | 阻断 (exit 2) | 强制写 Retrospective |
| **pre-compact.sh** | PreCompact | 注入信息 | 上下文压缩前保存计划进度快照 |
| **subagent-context.sh** | SubagentStart | 注入信息 | 给子代理注入 plan todo 进度 |

**只有 write-lock.sh 和 completion-check.sh 能真正阻断操作**，其余都是 advisory（仅输出警告到 stderr）。

### 5. 当前项目的实际配置

**CLAUDE.md** 引用的是 `@.baton/workflow-full.md`（`CLAUDE.md:1`）

**settings.json** 注册了全部 7 个 hooks

这意味着：每次 Claude Code 会话加载时：
1. **CLAUDE.md → workflow-full.md**：完整 371 行规则进入系统 prompt（~2953 tokens）
2. **SessionStart → phase-guide.sh**：又注入了一份当前阶段的精简指南（~20行）

**信息传递存在三重冗余**：
- workflow-full.md 提供了所有阶段的所有规则（一次性全量）
- phase-guide.sh 再输出当前阶段的精简版（phase-specific）
- hooks 的实际行为控制（write-lock 等）独立于文档存在

### 6. 三层机制的分层分析

```
层次 1: 规则注入 (知道该怎么做)
  ├── workflow-full.md → CLAUDE.md @import → 系统 prompt（全量）
  └── phase-guide.sh → SessionStart hook → 阶段性精简指南

层次 2: 行为控制 (强制执行)
  ├── write-lock.sh → 阻断源代码写入
  ├── completion-check.sh → 阻断未写 retrospective 的完成
  └── git pre-commit → 阻断未批准的 git commit

层次 3: 辅助提醒 (advisory)
  ├── bash-guard.sh → Bash 写文件警告
  ├── stop-guard.sh → 停止时进度提醒
  ├── post-write-tracker.sh → 文件不在 plan 中的提醒
  ├── pre-compact.sh → 压缩前快照
  └── subagent-context.sh → 子代理上下文
```

### 7. 如果只用 workflow-full.md，hooks 还有必要吗？

**必须保留的 hooks（行为控制层，仅靠文档无法保证）**：
- **write-lock.sh**：AI 可能忽略文档中的规则直接写代码。write-lock 是硬性阻断。✅ 必需
- **completion-check.sh**：强制写 retrospective。✅ 必需
- **git pre-commit**：防止 AI 跳过 plan 直接 commit。✅ 必需

**有价值但可选的 hooks**：
- **phase-guide.sh**：当 workflow-full.md 已全量加载时，它提供的是**聚焦当前阶段的提醒**。价值在于：在长对话中 AI 可能忘记当前处于哪个阶段。但如果文档已在 prompt 中，阶段检测能力是冗余的。✅ 有价值，但 workflow-full.md 已覆盖内容
- **pre-compact.sh**：上下文压缩时保存快照。在长会话中有实际价值。✅ 有价值
- **subagent-context.sh**：子代理不继承主对话的 prompt，需要独立注入。✅ 有价值
- **stop-guard.sh**：停止时提醒归档/lessons learned。轻量有用。✅ 有价值
- **post-write-tracker.sh**：检测修改了 plan 外的文件。write-lock 只管 GO 之前，这个管 GO 之后的范围控制。✅ 有价值

**可被 workflow-full.md 完全替代的**：
- **bash-guard.sh**：仅在 plan 未解锁时对 Bash 输出写操作警告。workflow-full.md 规则已说明"no source code before BATON:GO"，且 bash-guard 从不阻断（always exit 0）。❓ 价值极低

### 8. workflow.md 的去留分析

在当前 Claude Code 配置下（CLAUDE.md 已引用 workflow-full.md），workflow.md **完全未被使用**。

workflow.md 的唯一消费者是 `setup.sh`，用于安装到目标项目时：
- 支持 SessionStart 的 IDE → 复制 slim workflow.md（搭配 phase-guide.sh 补全细节）
- 不支持 SessionStart 的 IDE → 复制 full workflow-full.md 改名为 workflow.md

**对 baton 自身的开发**，workflow.md 无作用。
**对 baton 作为工具安装到其他项目**，workflow.md 是必需的（支撑 slim + hooks 的分发策略）。

## Self-Review

1. **phase-guide.sh 的指南与 workflow-full.md 的对应段落是否严格一致？** — 我确认它们是"intentionally duplicated"但 phase-guide 是精简版。如果两者出现分歧，AI 会收到矛盾信号。这是维护风险。
2. **如果移除 phase-guide.sh，AI 行为会变差吗？** — 在 Claude Code 下（已加载 full），phase-guide 的增量价值主要是阶段提醒，而非新信息。但在新会话启动时的"定位"作用不可忽视。
3. **workflow.md 能否自动从 workflow-full.md 生成？** — 当前是手动维护两份文件（前65行相同）。如果能在 setup.sh 中 `head -65 workflow-full.md > workflow.md`，可消除维护负担和一致性风险。

## Questions for Human Judgment

1. **baton 的定位是"只给自己用"还是"作为工具安装到其他项目"？** — 这决定了 workflow.md（slim 版）是否需要继续存在。如果只自用，可以只保留 workflow-full.md。
2. **phase-guide.sh 在实际使用中，你感受到它的阶段提醒对 AI 有多大影响？** — 在已经全量加载 workflow-full.md 的情况下，SessionStart 注入的精简指南是否实际改善了 AI 的行为表现？这需要使用者的主观判断。
3. **token 预算是否是一个实际关切？** — workflow-full.md ~2953 词约占 ~3500 tokens。如果 slim + hooks 模式能节省约 2200 tokens 且行为等效，在某些场景下（如 context window 较小的模型）这是有意义的。

## Annotation Log

### Round 1 (2026-03-05)

**[NOTE] § Questions for Human Judgment #1 — 自用 vs 分发**
"baton 的设计确实是为了兼顾自用和分发两种场景"
→ 已采纳。这确认了 workflow.md 的存在理由：它是分发策略的必要组件，不应删除。
  更新了 § 8 的分析结论，明确 workflow.md 在分发场景下的必要性。
→ Result: accepted

**[NOTE] § phase-guide.sh 与 workflow-full.md 的内容重叠 — partial info 风险**
"phase-guide.sh 我担心只输出了部分信息给AI 可能导致AI在某些边界情况下忘记完整规则"
→ 这是一个合理的担忧。我做了逐阶段的精确对比，以 ANNOTATION 阶段为例：

**phase-guide.sh ANNOTATION 输出（~25行）包含的**：
- 6种批注类型列表 ✅
- Thinking Posture（每种类型的验证要求）✅
- Annotation Log 记录要求 ✅
- "human is not always right" 原则 ✅

**phase-guide.sh ANNOTATION 输出遗漏的**：
- ❌ **Write-back Discipline**（"Log alone is not enough" — 必须同时更新文档正文）
- ❌ **Annotation Methods**（in-document vs in-chat 两种方式的处理）
- ❌ **"Never rewrite or reinterpret the human's intent"**
- ❌ **Annotation Log Format**（具体的格式模板、Round 编号）
- ❌ **[RESEARCH-GAP] 完整处理流程**（5步流程，phase-guide 只说了"pause + research + return"）
- ❌ **Dynamic Complexity Adjustment**（3+ [DEEPER]/[MISSING] 时建议升级复杂度）
- ❌ **Correct/Incorrect AI behavior 示例**（Redis/null pointer 等具体案例）

**结论**：在 slim workflow + phase-guide 模式下，AI 会丢失这些规则。
如果 workflow-full.md 已全量加载（当前 Claude Code 的配置），这些规则在 prompt 中已有，phase-guide 的部分输出不会造成遗忘。
但如果未来某种配置只依赖 slim + hooks，你的担忧就是实际问题。

其他阶段也存在类似的信息丢失（已补充到正文 § 新增段落）。
→ Result: accepted，已更新文档正文

---

## Supplement: phase-guide.sh 各阶段遗漏规则清单

针对 [NOTE] #2 的深入对比。以下列出 phase-guide.sh 每个阶段输出 vs workflow-full.md 对应段落中遗漏的关键规则。

### RESEARCH 阶段
phase-guide.sh 输出（`phase-guide.sh:156-186`）包含：执行策略4步、证据标准、风险标记、批注区提醒、Self-Review、spike solutions

**遗漏**：
- ❌ "Observe-then-decide" 原则（不预定列表，根据发现决定下一步）
- ❌ "What Research Should Cover" 模板（Call chain / Risk / Unverified assumptions / If this breaks）
- ❌ Tool Usage in Research（尝试所有可用文档检索工具、记录工具使用情况）
- ❌ Questions for Human Judgment 要求
- ❌ 停止在外部依赖时使用文档检索工具检查的要求

### PLAN 阶段
phase-guide.sh 输出（`phase-guide.sh:126-152`）包含：First Principles 3步、fundamental problems 处理、Self-Review、批注区提醒

**遗漏**：
- ❌ plan.md 应包含的4要素模板（What/Why/Impact/Risks+mitigation）
- ❌ Todolist 格式要求（`## Todo` / `- [ ]` / `- [x]` 的严格格式）
- ❌ 批注区的具体格式模板

### IMPLEMENT 阶段
phase-guide.sh 输出（`phase-guide.sh:69-89`）包含：5步执行序列、3条质量检查、测试要求

**遗漏**：
- ❌ 步骤5"Re-read the modified code... compare against plan's design intent"（phase-guide 缺少 re-read 和 design intent 对比）
- ❌ 步骤6"Mark [x] only AFTER verification passes"
- ❌ "Small addition vs design direction change" 的分级处理
- ❌ Completion 流程（Retrospective 要求、归档命令、Lessons Learned）
- ❌ "Independent items can run in parallel (subagent). Long todolists (10+) should be batched"

---

## 改进方案分析

### 根本问题

phase-guide.sh 硬编码了各阶段指南的精简版，与 workflow-full.md 存在：
1. **信息丢失** — 每个阶段遗漏 3-7 条规则（见 Supplement）
2. **维护负担** — 两处内容需要手动同步（phase-guide.sh 注释已承认: `Guidance text intentionally duplicates`）
3. **分歧风险** — 更新 workflow-full.md 后忘记同步 phase-guide.sh，AI 收到矛盾信号

### 约束

- baton 同时服务自用和分发（Round 1 NOTE #1 确认）
- workflow-full.md 是唯一权威源（single source of truth）
- phase-guide.sh 的状态检测逻辑（6 种状态判定）是独立价值，不可丢弃
- 需要兼容 MINGW/Linux/macOS（setup.sh 已支持多平台）
- workflow-full.md 的段落标记 `### [RESEARCH]` / `### [PLAN]` / `### [ANNOTATION]` / `### [IMPLEMENT]` 已经是稳定的、可解析的分隔符（spike 验证: awk 提取可靠）

### 方案 A: phase-guide.sh 从 workflow-full.md 动态提取

**做法**：保留 phase-guide.sh 的状态检测逻辑，但将硬编码的指南文本替换为从 `.baton/workflow-full.md` 动态提取对应段落。

```sh
# 示例: ANNOTATION 阶段
extract_section() {
    awk -v sec="$1" -v next="$2" '
        $0 ~ "^### \\[" sec "\\]" {found=1}
        found {print}
        found && $0 ~ "^### \\[" next "\\]" {exit}
    ' "$BATON_DIR/workflow-full.md"
}
# 状态检测 → echo 状态头 + extract_section "ANNOTATION" "IMPLEMENT"
```

- ✅ 信息完整性: 100%（直接读源文件，零遗漏）
- ✅ 单一来源: workflow-full.md 改了，phase-guide 自动跟上
- ✅ 可行性: spike 已验证 awk 提取在 MINGW 上可靠
- ⚠️ 输出量变大: ANNOTATION 段 107 行 vs 当前 25 行。SessionStart 输出更多 tokens
- ⚠️ 依赖文件存在: 需要 workflow-full.md 在 `.baton/` 目录中（setup.sh 已保证始终复制）

### 方案 B: 全量加载 workflow-full.md，phase-guide.sh 仅做状态指示

**做法**：所有 IDE 配置都加载 workflow-full.md（通过 @import、rules 文件等），phase-guide.sh 不再输出指南文本，只输出 1-2 行状态指示。

```sh
# 示例
echo "📍 ANNOTATION cycle — $PLAN_NAME awaiting approval" >&2
echo "⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain" >&2
```

- ✅ 信息完整性: 100%（全量已在 prompt 中）
- ✅ 极简 phase-guide: 从 ~190 行降到 ~60 行，只做状态检测 + 1行提示
- ✅ 零维护同步问题
- ⚠️ token 成本: 每次会话固定消耗 ~3500 tokens（workflow-full.md），无论当前阶段是什么
- ⚠️ 对不支持 @import 的 IDE: 需要把 full 内容嵌入 rules 文件（setup.sh 对 cursor/windsurf/cline 已经这么做了）

### 方案 C: 混合方案 — full @import + phase-guide 精简指示 + workflow.md 自动生成

**做法**：
1. 全量加载 workflow-full.md（方案 B 的策略）
2. phase-guide.sh 只做状态检测 + 轻量提示（方案 B）
3. setup.sh 中 `head -65 workflow-full.md > workflow.md` 自动生成 slim 版，消除手动维护
4. 对不支持 @import 的 IDE，继续用 full 版嵌入 rules 文件

- ✅ 信息完整性: 100%
- ✅ 单一来源 + 自动生成 slim
- ✅ phase-guide.sh 大幅简化
- ✅ 消除 workflow.md 的手动维护
- ⚠️ slim 版的内容边界依赖 "前65行" 这个假设（如果 full 版前部被重构，需要更新截断逻辑）

### 推荐：方案 B

**理由**：

1. **当前实际配置已经是方案 B 的雏形** — CLAUDE.md 全量加载 workflow-full.md，phase-guide.sh 的指南内容实际上是冗余的。方案 B 只是把这个现状正式化。

2. **~3500 tokens 的成本可以接受** — 对 Claude Opus/Sonnet（200K context），3500 tokens 是 1.75%。这比 phase-guide.sh 精简输出节省的 ~2200 tokens 带来的**信息丢失风险**更值得承受。

3. **维护成本最低** — 只需维护 workflow-full.md 一个文件。phase-guide.sh 从 ~190 行降到 ~60 行，只负责状态检测（它真正独特的价值）。

4. **方案 A 的问题**：虽然信息完整，但每次 SessionStart 输出 70-107 行指南文本到 stderr 是过重的——这些内容已经在 prompt 中了。

5. **workflow.md 自动生成**（方案 C 的 #3）可以作为方案 B 的补充，独立添加。

---

## Supplement: 官方与社区最佳实践调研

针对 [RESEARCH-GAP] "是否可以研究一下官方或者社区里面的比较好的实践看能否给予灵感"

### 使用的工具及结果

| 工具 | 查询 | 结果 |
|------|------|------|
| WebSearch | "Claude Code hooks workflow enforcement best practices CLAUDE.md 2025 2026" | ✅ 10 条结果，含官方文档和社区文章 |
| WebSearch | "AI coding assistant workflow enforcement hooks rules system prompt patterns" | ✅ 10 条结果，含 RIPER/AB Method/TrailOfBits |
| WebSearch | "Claude Code CLAUDE.md keep it short offload to hooks rules vs enforcement" | ✅ 10 条结果，官方 <200 行建议 |
| WebFetch | addyosmani.com/blog/ai-coding-workflow/ | ✅ 多层防护模式 |
| WebFetch | dev.to — Guardrails on AI Coding Assistant | ✅ advisory vs deterministic 分层 |
| WebFetch | github.com/hesreallyhim/awesome-claude-code | ✅ RIPER/AB Method，无 write-lock 模式 |
| WebFetch | psantanna.com/claude-code-my-workflow | ❌ 页面为编译后的 JS，无有效内容 |
| WebFetch | medium.com — command hooks to keep AI on track | ❌ 403 Forbidden |
| Agent (claude-code-guide) | Claude Code hooks system best practices | ✅ 19 种 hook 事件详解，官方模式 |
| Context7 | /websites/code_claude — hooks, CLAUDE.md, rules | ✅ **"keep CLAUDE.md under 200 lines"** + CLAUDE.md vs Skills vs Rules 三层分类 |
| Context7 | /affaan-m/everything-claude-code — workflow hooks | ✅ Memory persistence hooks 模式（PreCompact→SessionStart 状态恢复） |
| Context7 | /davila7/claude-code-templates — workflow patterns | ⚠️ 无直接相关内容（通用模板项目） |

### 调研来源

| 来源 | 类型 | 关键发现 |
|------|------|----------|
| [Claude Code 官方 Hooks Guide](https://code.claude.com/docs/en/hooks-guide) | 官方文档 | CLAUDE.md 是 advisory，hooks 是 deterministic |
| [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices.md) | 官方文档 | "Offload processing to hooks and skills" |
| [Anthropic 官方博客: How to configure hooks](https://claude.com/blog/how-to-configure-hooks) | 官方 | 19种 hook 事件、prompt/agent hook 类型 |
| [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config) | 安全公司实践 | 模块化 CLAUDE.md + hooks 执法 |
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | 社区合集 | RIPER/AB Method 工作流 |
| [Addy Osmani: AI Coding Workflow](https://addyosmani.com/blog/ai-coding-workflow/) | 行业实践 | 多层防护、持久 vs 运行时规则 |
| [DEV: Guardrails on AI Coding Assistant](https://dev.to/rajeshroyal/hooks-how-to-put-guardrails-on-your-ai-coding-assistant-4gak) | 社区 | hooks = 确定性执法层 |
| [AI Coding Agents Explained](https://codeaholicguy.com/2026/01/31/ai-coding-agents-explained-rules-commands-skills-mcp-hooks/) | 社区 | Rules/Commands/Skills/MCP/Hooks 五层分类 |

### 核心发现 1: 官方的 "advisory vs deterministic" 原则

Claude Code 官方文档明确区分两层：

> **"CLAUDE.md instructions are advisory. Hooks are deterministic and guarantee the action happens."**

这正是 baton 当前架构的核心思路：workflow-full.md（advisory）+ write-lock.sh（deterministic）。官方认可这个分层。

**启发**：baton 的分层设计方向正确，但 phase-guide.sh 目前处于一个尴尬位置——它既不是 advisory（不在 CLAUDE.md 中），也不是 deterministic（不阻断任何操作），而是在 SessionStart 时注入了一份精简的 advisory 内容。这与官方推荐的"hooks 做执法，rules 做指导"模式有偏差。

### 核心发现 2: 官方建议 CLAUDE.md 保持精简

> **"A 500-line CLAUDE.md hurts more than it helps. Target under 200 lines for the root file."**
> **"Offload processing to hooks and skills. Move instructions from CLAUDE.md to skills."**
> **"If Claude still doesn't follow a rule despite having it in CLAUDE.md, the file is probably too long."**

当前 workflow-full.md 是 371 行（~2953 词）。如果通过 CLAUDE.md @import 全量加载，它本身就已超出官方建议的 200 行上限。

Context7 查询官方文档进一步确认了三层分类（`/websites/code_claude` — features-overview）：

> **CLAUDE.md**: loads every session → "always do X" rules（coding conventions, build commands）
> **`.claude/rules/`**: loads every session or when matching files opened → path-scoped guidelines
> **Skills**: load on demand → reference material, repeatable workflows
> **"keep CLAUDE.md under 200 lines, moving reference content to skills or organizing rules into `.claude/rules/` files"**

**启发**：这对方案 B（全量加载 workflow-full.md）提出了质疑。如果 CLAUDE.md 内容太长，AI 反而可能忽略其中的规则。官方更倾向于把详细指南放到 **skills**（按需加载）或 **`.claude/rules/`**（路径匹配加载）中，CLAUDE.md 只保留核心原则。

### 核心发现 3: context 压缩后的规则存活

官方文档推荐 SessionStart hook 搭配 `compact` matcher 来在上下文压缩后重新注入关键规则：

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "compact",
      "hooks": [{"type": "command", "command": "echo 'Reminder: use Bun, not npm.'"}]
    }]
  }
}
```

**启发**：baton 的 pre-compact.sh 做了类似的事（压缩前快照），但缺少**压缩后的规则重注入**。如果 workflow-full.md 被压缩掉了，当前没有机制把关键规则恢复到 context 中。phase-guide.sh 只在 SessionStart 触发一次，不会在 compact 后重新触发。

### 核心发现 4: 社区的 phased workflow 实践

**RIPER Workflow**（Tony Narlock）实现了类似 baton 的阶段分离：Research → Innovate → Plan → Execute → Review。但从 awesome-claude-code 的描述来看，它主要通过 CLAUDE.md 规则实现，没有 hooks 执法层。

**AB Method**（Ayoub Bensalah）通过 spec 驱动的工作流 + 子代理来分解大任务，思路与 baton 相近但不依赖 hooks。

**关键差异**：在 awesome-claude-code 收录的项目中，**没有发现类似 baton 的 write-lock（plan 审批门控）模式**。baton 的"BATON:GO 才解锁写代码"是相对独特的设计。

### 核心发现 4.5: Memory Persistence Hooks 模式（Context7 发现）

Context7 查询 `/affaan-m/everything-claude-code` 揭示了一个与 baton 需求高度相关的模式：

```
PreCompact → 保存当前状态（session state snapshot）
SessionEnd → 持久化会话状态
SessionStart → 加载上一次会话的 context
Stop → 评估会话模式、提取可复用 pattern
```

**启发**：baton 的 pre-compact.sh 已实现了 PreCompact 快照，但缺少**SessionStart 恢复**的配对。这个模式证实了方案 A 中"compact 重注入"的必要性——不只是 baton 的需求，而是社区已经验证的 pattern。

### 核心发现 5: Trail of Bits 的分层模式

Trail of Bits（安全公司）的 claude-code-config 代表了一种成熟的分层实践：

- **CLAUDE.md**：哲学 + 工具链配置 + 硬限制（函数长度、复杂度阈值）——精炼的核心规则
- **Hooks**：阻断危险操作（rm -rf、直接 push 到 main）——执法
- **Sandbox**：通过 `--dangerously-skip-permissions` + 容器隔离实现高吞吐

**启发**：他们的 CLAUDE.md 是"精炼但有分量"的核心规则（非百科全书式的详细流程），详细的工作流放在外部文档中。

### 对改进方案的影响

官方和社区实践给了三个新的洞察：

1. **CLAUDE.md 371 行可能太长**：官方建议 < 200 行。这削弱了方案 B（全量加载）的理由。

2. **更优的模式可能是**：CLAUDE.md 加载 slim 版（核心原则 ~65 行）+ 按阶段需要的详细规则通过 **phase-guide.sh 动态提取** workflow-full.md 的完整段落（方案 A）。这样既保持 CLAUDE.md 精简，又确保当前阶段的规则 100% 完整。

3. **缺少 compact 后重注入**：无论哪个方案，都应增加 `SessionStart` + `compact` matcher 的 hook，在上下文压缩后重新注入当前阶段的关键规则。

### 修订后的方案推荐

基于社区调研，**方案 A（动态提取）成为更优选择**，理由链：

```
官方: CLAUDE.md 应 < 200 行
  → workflow-full.md 371 行全量加载违反此建议
  → 需要把 CLAUDE.md 控制在 slim 版范围

官方: hooks 做执法，rules 做核心指导
  → slim workflow.md (~65行) 放 CLAUDE.md = 核心指导
  → write-lock.sh = 执法（已有）
  → phase-guide.sh = 阶段性详细指导（动态提取 = 100% 完整 + 单一来源）

社区: 无人实现 plan-approval gate
  → baton 的 write-lock 模式独特且有价值，应保留
  → 但指导层（phase-guide）应该升级为完整提取而非精简摘要
```

**修订推荐：方案 A + compact 重注入**
1. CLAUDE.md → @.baton/workflow.md（slim，~65 行，核心原则）
2. phase-guide.sh → 状态检测 + 从 workflow-full.md 动态提取当前阶段完整段落
3. 新增：SessionStart + compact matcher → 触发 phase-guide.sh 重新注入
4. write-lock.sh / completion-check.sh / pre-commit → 保持不变（执法层）

---

## Annotation Log

### Round 1 (2026-03-05)

**[NOTE] § Questions for Human Judgment #1 — 自用 vs 分发**
"baton 的设计确实是为了兼顾自用和分发两种场景"
→ 已采纳。这确认了 workflow.md 的存在理由：它是分发策略的必要组件，不应删除。
  更新了 § 8 的分析结论，明确 workflow.md 在分发场景下的必要性。
→ Result: accepted

**[NOTE] § phase-guide.sh 与 workflow-full.md 的内容重叠 — partial info 风险**
"phase-guide.sh 我担心只输出了部分信息给AI 可能导致AI在某些边界情况下忘记完整规则"
→ 这是一个合理的担忧。做了逐阶段精确对比，见 Supplement。
→ Result: accepted，已更新文档正文

### Round 2 (2026-03-05)

**[MISSING] § 改进方案**
"既然phase-guide.sh 各阶段确实会存在遗漏规则 你应该给出改进最佳方案"
→ 补充了 3 个方案的完整分析（A: 动态提取 / B: 全量加载+精简指示 / C: 混合），推荐方案 B。
  推荐理由：当前配置已是方案 B 雏形、token 成本可接受、维护成本最低。
→ Result: 方案已补充，awaiting human decision

### Round 3 (2026-03-05)

**[RESEARCH-GAP] § 官方与社区最佳实践**
"是否可以研究一下官方或者社区里面的比较好的实践看能否给予灵感"
→ 暂停其他工作，进行了补充研究。调研了 8 个来源（官方文档、安全公司实践、社区合集、行业博客）。
  关键发现：
  1. 官方明确 "CLAUDE.md < 200 行" + "advisory vs deterministic" 分层
  2. 当前 workflow-full.md 371 行全量加载**违反**官方建议
  3. 社区无人实现 plan-approval gate（baton 的 write-lock 独特）
  4. 缺少 compact 后重注入机制
  **影响**：基于新证据，修订推荐从方案 B 改为**方案 A + compact 重注入**。
  详见 § Supplement: 官方与社区最佳实践调研。
→ Result: 研究完成，修订了改进方案推荐

### Round 4 (2026-03-05)

**[NOTE] § Supplement: 官方与社区最佳实践调研 — 工具使用不足**
"我发现一个很大的问题 虽然你重新去研究了 但是并没有使用工具去研究"
→ 确认问题。Round 3 的研究使用了 WebSearch (3次)、WebFetch (5次,2次失败)、Agent claude-code-guide (1次)，但**遗漏了 Context7 文档检索工具**。
  按照 workflow-full.md 研究规范："try all available documentation retrieval tools" + "Record which tools were used and which returned no results"。
  补充措施：
  1. 追加了 Context7 查询（3 个 library: /websites/code_claude, /affaan-m/everything-claude-code, /davila7/claude-code-templates）
  2. 在 Supplement 中新增 "使用的工具及结果" 表格，完整记录 12 次工具调用及其结果
  3. Context7 新发现已整合：官方三层分类（CLAUDE.md/rules/skills）+ memory persistence hooks 模式
→ Result: accepted，已补充工具使用记录和新发现

---

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->
[RESEARCH-GAP]
  1.是否可以研究一下官方或者社区里面的比较好的实践看能否给予灵感

[NOTE]
  1.我发现一个很大的问题 虽然你重新去研究了 但是并没有使用工具去研究
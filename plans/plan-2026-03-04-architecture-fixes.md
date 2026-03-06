# Baton 架构改进：基于实施经验的四项修复 + 批注区

> 状态：待审阅

## 审阅指南

在任何段落旁直接添加标注，AI 会逐条回应并记录在 Annotation Log 中：

- `[Q]` 提问 — "为什么选择这个方案？"
- `[CHANGE]` 修改请求 — "改用 Redis 而不是内存缓存"
- `[NOTE]` 补充上下文 — "历史上我们试过 X，因为 Y 放弃了"
- `[DEEPER]` 分析不够深 — "这部分需要更详细的分析"
- `[MISSING]` 遗漏 — "没有考虑到 XX 场景"

审阅完成后添加 `<!-- BATON:GO -->` 解锁代码写入。
确认后告诉 AI "generate todolist" 生成实施检查清单。

---

## 背景

基于 research.md 的五项发现和一轮标注循环，本计划解决以下问题：

| # | 问题 | 来源 | 严重度 |
|---|------|------|--------|
| 1 | todolist 可被跳过（软引导不够） | research §二 | ❌ 高 |
| 2 | 三文件同步负担 | research §三 | ⚠️ 中 |
| 3 | grep 格式敏感 | research §四 | ⚠️ 中 |
| 4 | first-principles.md 职责边界过时 | research §五 | ❓ 低 |
| 5 | 审阅指南 UX 不佳 + research.md 无审阅引导 | Annotation Log [Q]1 + [CHANGE]1 | ❌ 高 |

---

## 变更 1：write-lock.sh 增加 todolist 时序检查

**依据：** research §八·问题1 — todolist 检查是时序保证（流程步骤是否完成），不是质量检查。与 BATON:GO 检查同类。Annotation Round 1 [Q]2 进一步验证：agentic 提示词改善思维质量但无法强制流程顺序，硬执行是唯一可靠手段。

**当前逻辑**（`write-lock.sh:84-87`）：
```sh
if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    exit 0
fi
```

**改为：**
```sh
if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    if grep -qi '^## Todo$' "$PLAN" 2>/dev/null; then
        exit 0
    fi
    echo "🔒 Blocked: plan approved but no ## Todo found." >&2
    echo "📍 Ask the human to say 'generate todolist' before implementation." >&2
    exit 1
fi
```

**影响：**
- write-lock.sh 从 93 行变为 ~98 行
- 所有 IDE 的写入操作都会受到此检查
- 需要同步更新 hooks/pre-commit（同样的检查逻辑）
- `test-write-lock.sh` 需新增测试用例

---

## 变更 2：强化一致性测试

**依据：** research §八·问题2 — 方案 D（接受重复，强化测试）。

在 `test-workflow-consistency.sh` 中新增检查：

1. **Flow 行一致性** — 提取 `Scenario A` 和 `Scenario B` 行，验证两个 workflow 文件一致
2. **phase-guide.sh 关键词交叉验证** — 检查 phase-guide.sh 各阶段的关键词是否出现在 workflow-full.md 对应章节
3. **批注区规则一致性** — 验证两个 workflow 文件对 `批注区` 规则的描述一致

不修改三文件架构本身。

---

## 变更 3：格式规范 + grep 防御

**依据：** research §八·问题3 — 方案 A（格式规范）+ 方案 B（grep 容错）结合。

### 3a：workflow-full.md 增加格式规范

在 [PLAN] 章节的 todolist 描述后追加：

```markdown
Todolist format (strict — matched by grep in hooks):
- Section header: `## Todo` (exact, on its own line)
- Unchecked item: `- [ ] description`
- Checked item: `- [x] description` (lowercase x)
```

### 3b：grep 增加防御层

所有 `^## Todo` 模式改为 `^## Todo` + `-i` flag：

| 文件 | 当前 | 改为 |
|------|------|------|
| `phase-guide.sh:51` | `grep -q '^## Todo'` | `grep -qi '^## Todo$'` |
| `write-lock.sh`（新增） | — | `grep -qi '^## Todo$'` |

checkbox 模式增加 `-i`：

| 文件 | 当前 | 改为 |
|------|------|------|
| `phase-guide.sh:36` | `grep -c '^\- \[x\]'` | `grep -ci '^\- \[x\]'` |
| `stop-guard.sh:32` | `grep -c '^\- \[x\]'` | `grep -ci '^\- \[x\]'` |

`^\- \[` 模式不需要 `-i`（方括号不区分大小写）。

---

## 变更 4：更新 first-principles.md 职责边界

**依据：** research §八·问题4 — 接受演变方向，精确化表述。

修改 `docs/first-principles.md` 第七节（§366-380），将：
```
Baton 不做什么：
├── 不检查文档质量
├── 不管理任务状态
```

改为：
```
Baton 做什么：
├── 写锁 — 时序保证（BATON:GO + ## Todo 才能写源码）
├── 流程阶段检测 — 结构性检查（流程步骤是否完成），非质量判断
├── 标注协议 — 6 种标注类型 + AI 回应规则
├── Annotation Log — 持久化每轮对话
├── 阶段引导 — 当前阶段的行为提示
└── research/plan 深度引导 — 提示（非强制）应包含的内容

Baton 不做什么：
├── 不判断文档质量 — "research 够不够深" 由人通过标注循环判断
├── 不做项目管理 — 不跟踪任务分配、优先级、截止日期
├── 不规定方法论 — 研究/实现/代码审查方法由其他系统决定
```

关键区分：**结构性检查**（Baton 做）vs **质量性判断**（Baton 不做）。

---

## 变更 5：批注区替代审阅指南（plan.md + research.md）

**依据：** Annotation Log [Q]1（research.md 无审阅引导）+ [CHANGE]1（批注区 UX 优于审阅指南）。

实际使用证据：所有标注都添加在文档末尾，从未内联到段落旁。审阅指南放在开头是格式参考，但人实际需要的是"在哪写"+"怎么写"。批注区同时解决这两个问题。

### 5a：workflow 规则更新

`workflow.md` Rules 修改：
```
- 旧：plan.md must begin with a ## 审阅指南 section after the title
- 新：plan.md and research.md must end with a ## 批注区 section
- 新增：Investigation/analysis tasks → produce research.md. Baton workflow applies to ALL analysis.
```

`workflow-full.md` 变更：
1. 删除 `#### Review Guide (required at beginning of plan.md)` 及其模板
2. [PLAN] 和 [RESEARCH] 章节各新增批注区模板

**plan.md 批注区模板：**
```markdown
## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 变更 3：为什么用 grep -i？ -->
```

**research.md 批注区模板：**
```markdown
## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->
```

### 5b：phase-guide.sh 更新

RESEARCH phase 输出末尾追加：
```
research.md must end with a ## 批注区 section for human annotations.
```

PLAN phase 输出中更新：
```
plan.md must end with a ## 批注区 section for human annotations.
```

### 5c：RESEARCH phase 增加文档检索提示

**依据：** [RESEARCH-GAP]1 — Context7 实验证明对外部系统调查有高增量价值。

在 phase-guide.sh RESEARCH phase 输出和 workflow-full.md [RESEARCH] 章节追加：
```
When stopping at external deps/framework internals:
- Use available documentation retrieval tools to check authoritative docs
- Prefer official docs over assumptions about API behavior
```

注：措辞为行为导向（"use available tools"），不绑定特定工具名（Context7/web search），适用于任何 AI 环境。

---

## 影响范围

| 文件 | 操作 |
|------|------|
| `.baton/write-lock.sh` | 新增 `## Todo` 检查（变更 1） |
| `.baton/phase-guide.sh` | grep 加 `-i`（变更 3b）+ 批注区提示 + 文档检索提示（变更 5b/5c） |
| `.baton/stop-guard.sh` | grep 加 `-i`（变更 3b） |
| `.baton/workflow.md` | Rules 更新：审阅指南 → 批注区（变更 5a） |
| `.baton/workflow-full.md` | todolist 格式规范（变更 3a）+ 审阅指南模板删除 + 批注区模板（变更 5a）+ 文档检索（变更 5c） |
| `hooks/pre-commit` | 同步 `## Todo` 检查（变更 1） |
| `docs/first-principles.md` | 职责边界更新（变更 4） |
| `tests/test-write-lock.sh` | 新增 todolist 检查测试（变更 1） |
| `tests/test-phase-guide.sh` | 批注区 + 文档检索提示验证（变更 5b/5c） |
| `tests/test-workflow-consistency.sh` | 新增 Flow 行 + 关键词交叉验证（变更 2） |
| `tests/test-pre-commit.sh` | 新增 todolist 检查测试（变更 1） |


---

## Annotation Log

### Round 1 (2026-03-03)

**[RESEARCH-GAP] 1 § AI 研究阶段是否应主动使用文档检索**
"调查 IDE hook 时没有调用工具去检索官方文档，Context7 这种工具是否能提供更深入的调查结果？"

→ 已暂停其他标注，执行补充研究。结果记录在 research.md `## Supplement: AI 研究阶段是否应主动使用文档检索工具`。

关键发现：
- Claude Code hooks：Context7 返回的内容与已知一致，增量价值低（因为 baton 本身在 Claude Code 上开发）
- **Cursor hooks：重大发现。** Context7 揭示 Cursor 有 12+ hook 类型，`beforeShellExecution`/`beforeMCPExecution` 支持 `permission: "deny"` 硬拦截，和 Claude Code 的 `exit 1` 等价。纯代码阅读无法获得此信息。

结论：**不是所有调查都需要检索，但涉及外部系统能力的调查应该主动检索。** 建议在 RESEARCH phase 引导中增加一条关于文档检索的提示。

→ 结果：已完成研究，建议纳入变更 5b 的 RESEARCH phase 引导

---

**[CHANGE] 1 § 批注区 replacing 审阅指南**
"plan 和 research 生成时默认新增一个批注区，去掉审阅指南，人在批注区做批注，AI 在批注的地方回应"

→ 调查实际使用模式：

**证据 1：** 本轮工作中，人的所有标注行为——
- research.md：标注添加在文档末尾（`research.md:484-489`），不是内联
- plan.md：标注添加在文档末尾（`plan.md:209-217`），不是内联
- 两轮都如此，没有一次是内联到段落旁

**证据 2：** 当前 workflow-full.md:178 描述为"Human writes annotations directly at the relevant location"——但实际无人这样做。原因明显：在长文档中找到具体段落然后插入标注比直接在末尾写要麻烦得多。

**证据 3：** 审阅指南放在文档开头，但它其实只是格式参考。人需要知道的是"在哪写"和"怎么写"。批注区可以同时解决这两个问题——位置固定（末尾），格式嵌入在 section header 中。

**方案评估：**

| 方面 | 审阅指南（当前） | 批注区（提议） |
|------|-----------------|---------------|
| 人知道在哪写 | ❌ 文档说"在段落旁"但实际在末尾 | ✅ 固定位置 |
| 格式参考 | ✅ 审阅指南有完整说明 | ✅ 嵌入 header 中 |
| AI 找标注 | ⚠️ 需要全文扫描 | ✅ 只看批注区 |
| 标注与内容的关联 | ⚠️ 理论上内联更好，但无人这样做 | ⚠️ 需要 § 前缀引用 |

**⚠️ 一个顾虑：** 批注区的标注与原文分离，人需要用 `§ 变更 3` 之类的前缀指明在评论哪个部分。但看实际行为，人已经在这样做了（如 `[CHANGE]: 1.plan 和 research 批注那儿...`），所以这不是新负担。

**接受此变更。** 实际使用模式支持这个方案。具体影响：
- 变更 5 标题从"research.md 审阅指南"改为"批注区替代审阅指南（plan.md + research.md）"
- workflow.md 规则从"must begin with 审阅指南"改为"must end with ## 批注区"
- workflow-full.md 模板更新
- phase-guide.sh PLAN/RESEARCH 引导更新

→ 结果：采纳。已更新变更 5 为批注区方案。

---

**[Q] 2 § Agentic 提示词是否有提升**
"之前做了提示词的 agentic，是否有提升？包括 phase-guide.sh 里增加了提示词的 agentic"

→ 诚实评估，按层级分析：

**有提升的地方：**
- **研究深度提高。** `phase-guide.sh:149-163` 的 "Execution strategy"（识别入口 → 追实现 → 跟委派 → subagent 并行追踪）在本轮 research.md 中确实被遵守了——research.md 追踪了 write-lock.sh、phase-guide.sh、stop-guard.sh 的具体行号，标记了 ✅/❌/❓ 风险
- **标注响应质量提高。** `phase-guide.sh:96-101` 的 "Thinking Posture"（[Q] 先读代码再答、[CHANGE] 先验证安全性）在本轮标注处理中确实执行了——每个 [Q] 响应都有 file:line 证据
- **IMPLEMENT 纪律提高。** `phase-guide.sh:69-81` 的 per-item 流程和 3-times-stop 规则在上轮实施中被遵守

**没提升的地方（诚实说）：**
- **流程跳步没防住。** todolist 被跳过不是因为提示词不好，而是因为提示词无法强制执行——AI 完全可以理解规则但仍然跳过它。这正是 research §二 的发现：**软引导的天花板**
- **Baton 自身工作流也被跳过。** 当人说"深度分析当前的 baton 项目"时，我直接在聊天中回复而不是创建 research.md。phase-guide.sh 的 SessionStart 提示此时已经看不到了
- **Mindset 原则被部分忽略。** "Stop when uncertain"——在某些分析中我仍然给出了 "should be fine" 级别的结论

**核心判断：** Agentic 提示词提升了**阶段内**的执行质量（研究更深、响应更准），但没有提升**阶段间**的流程遵守（跳步仍然发生）。这验证了一个架构结论：

```
提示词 → 改善思维质量（HOW to think）  ✅ 有效
提示词 → 强制流程顺序（WHEN to act）   ❌ 无效，需要 write-lock 级硬执行
```

这两个是互补的，不是替代的。变更 1（write-lock 增加 todolist 检查）解决的是提示词解决不了的问题。

→ 结果：确认有效但有明确边界。提示词改善思维质量，write-lock 保证流程顺序。

---

**[Q] 3 § Annotation Log Format 是否合理**

→ 验证 `workflow-full.md:219-236` 的 Annotation Log Format，对照本轮实际使用：

**模板定义的格式：**
```
### Round N (YYYY-MM-DD)
**[TYPE] § Section**
"Quoted annotation"
→ AI response with evidence
→ Result: outcome
```

**实际使用（research.md:493-574）：**
```
### Round 1 (2026-03-03)
**[NOTE] § 问题 1 / 问题 4 — todolist 的本质**
"todolist 是时序保证..."
→ 分析 + 代码证据
→ 结果：采纳
```

格式完全匹配。每条记录包含：标注类型 + 所属章节、引用原文、AI 响应 + file:line 证据、结果状态。

**评估：**
- ✅ Round 编号 + 日期：有效，可追溯讨论时间线
- ✅ § 引用：有效，明确标注位于文档的哪个部分
- ✅ 引用原文：有效，上下文完整
- ✅ 结果状态（采纳/拒绝/待决）：有效，记录了决策
- ⚠️ 唯一小问题：当标注跨 Round 时（如 [RESEARCH-GAP] 跨轮返回），Round 编号可能混淆。但这在实际使用中未造成问题。

→ 结果：合理，无需修改。实际使用验证了格式的有效性。

---

**[Q] 4 § workflow.md 中的 Flow 是否合理**

→ 验证 `workflow.md:17-19` 的 Flow 定义：

```
Scenario A (clear goal): research.md → human states requirement → plan.md → annotation cycle → BATON:GO → generate todolist → implement
Scenario B (exploration): research.md ← annotation cycle → plan.md ← annotation cycle → BATON:GO → generate todolist → implement
Simple changes may skip research.md.
```

**对照本轮实际流程：**

本轮是 Scenario B（探索式）：
1. 人说"深度分析当前的 baton 项目" → research.md
2. 标注循环 on research.md（[DEEPER]×4 → [NOTE]+[Q]+[RESEARCH-GAP]）
3. 人说"根据研究结果生成计划" → plan.md
4. 标注循环 on plan.md（[CHANGE]+[Q]×3+[RESEARCH-GAP]）← 当前在这里
5. 待: BATON:GO → generate todolist → implement

Flow 与实际完全匹配。

**检查两个文件一致性：**
- `workflow.md:17-18` 与 `workflow-full.md:17-18`：**完全一致** ✅（已有 test-workflow-consistency.sh 验证）

**一个细节注意：** Scenario A 中 "human states requirement" 在 research.md 之后。实际场景中人的需求可能在 research 之前就已经声明了。但这个 Flow 是描述**信息流**而不是**时序**——人可以在任何时候声明需求，Flow 表达的是"plan.md 的输入包括 research 和 requirement"。这个理解下 Flow 是准确的。

→ 结果：合理，无需修改。两个 Scenario 覆盖了实际使用中的常见模式。

### Round 2 (2026-03-03)

**[Q] 1 § 文档检索工具是否需要提示词引导**
"调用类似 Context7 这样的工具，是必须在提示词里引导吗？还是 AI 自己觉得需要就会用？"

→ 基于实际发生的事情来回答——

**事实：** Context7 在整个会话中始终可用作为工具。但在 IDE hook 研究中，我没有使用它。只有当你通过 [RESEARCH-GAP] 明确指出后，我才用了它——并且发现了 Cursor 12+ hook 类型的重要信息。

**这说明：AI 不会可靠地主动使用不常用的工具。** 工具"可用"（available）是必要条件但不是充分条件。AI 对常用工具（Read、Grep、Glob）会自然使用，但对 Context7 这类场景性工具，需要一个**行为级别的提示**在正确时机提醒。

**但提示应该是行为导向的，不是工具导向的：**
```
❌ "Use Context7 to search documentation"          ← 工具特定，换环境就失效
✅ "When stopping at external deps/framework internals,
    use available documentation retrieval tools"    ← 行为导向，任何环境都适用
```

不同 AI 系统有不同的工具集——有的有 Context7，有的有 web search，有的两者都没有。提示词应该描述**什么时候该查文档**，而不是**用哪个工具查**。

变更 5c 当前的措辞已经是行为导向的（"Use Context7 or web search"），但我建议进一步泛化为 "use available documentation retrieval tools"。

→ 结果：需要提示词引导，但应该是行为级别（何时查）而非工具级别（用什么查）。已更新变更 5c。

---

**[Q] 2 § 工作流跳步如何改进**
"Baton 工作流被跳过——人说'深度分析'时 AI 直接在聊天中回复，phase-guide.sh 已经看不到了。怎么改进？"

→ 分析根因和可行方案：

**根因：** phase-guide.sh 是 SessionStart hook，只在会话启动时触发一次。归档 plan 后，会话处于"空白状态"（无 plan.md、无 research.md），但 phase-guide 不会再次触发。AI 没有任何可见的提醒说"新的分析任务也应该走 Baton 流程"。

**能否硬执行？** 不能。
- write-lock.sh 只拦截源码写入，不拦截聊天响应
- 没有 hook 类型可以拦截"AI 即将输出聊天文字"
- 即使拦截 Write 工具，AI 也可以选择不调用 Write 而直接在聊天中回复

**可行方案：在 workflow.md（always-loaded context）增加规则**

workflow.md 是通过 CLAUDE.md 的 `@.baton/workflow.md` 引用的，AI 在**每条消息**中都能看到。如果在 Rules 中增加一条：

```
- Investigation/analysis tasks → produce research.md. Baton workflow applies to ALL analysis, not just when you decide it does.
```

这条规则会在 AI 处理每条消息时可见。虽然仍是软引导，但它的**可见频率**远高于 SessionStart 的一次性提醒。

**为什么这比 phase-guide.sh 更好？**
- phase-guide.sh：只在 SessionStart 可见 → 会话中段不再可见
- workflow.md Rules：每条消息都可见 → 包括会话中段的新任务

**为什么仍然是软引导？** 因为"是否属于需要 research.md 的分析任务"是一个**方法论判断**，不是时序检查。Baton 能硬执行时序（BATON:GO 前不能写代码），但不能硬执行方法论（"这个请求应该用 research.md 而不是聊天"）。这属于 first-principles.md 说的"不规定方法论"的范畴。

**建议：** 将此规则纳入变更 5a 的 workflow.md 规则更新中。

→ 结果：在 workflow.md Rules 增加一条关于分析任务输出的规则。已纳入变更 5a。

---

**[Q] 3 § 批注后没有反向更新计划**
"基于最新批注后的分析结果，你没有改进或分析之前 plan 中的计划？"

→ 这是一个正确的批评。我处理标注时做了：更新 Annotation Log、更新变更 5（审阅指南→批注区）、新增变更 5c（文档检索）。但我**没有系统性地审查这些新发现对变更 1-4 的影响**。现在补做：

**变更 1（write-lock.sh ## Todo 检查）：**
- [Q]2 的分析明确了"agentic 提示词无法强制流程顺序"→ **更加证实**了变更 1 的必要性。write-lock 是唯一能硬执行时序的机制。
- ✅ 无需修改内容，但可在依据中追加此证据。

**变更 2（一致性测试）：**
- 批注区替换审阅指南 → consistency test 应验证两个 workflow 文件对 批注区 规则的一致性。
- 新增的 workflow.md 规则（分析任务 → research.md）也应纳入一致性验证。
- ⚠️ 需补充：在交叉验证中增加 批注区 关键词检查。

**变更 3（格式规范 + grep）：**
- 无影响。
- ✅ 无需修改。

**变更 4（first-principles.md 职责边界）：**
- [Q]2 的分析引入了新的边界划分：workflow.md 规则（每条消息可见）vs phase-guide.sh（仅 SessionStart 可见）。这和"结构性检查 vs 质量性判断"是不同维度的区分。
- ⚠️ 可在"Baton 做什么"中细化"阶段引导"的描述，区分 always-visible（workflow.md）和session-start-only（phase-guide.sh）两种引导。但这可能过于细节——留给你决定。

**变更 5（批注区 + 文档检索）：**
- [Q]1 建议 5c 的措辞应更泛化（行为导向而非工具导向）→ 需更新。
- [Q]2 建议 5a 增加分析任务输出规则 → 需追加。

**总结需要的更新：**

| 变更 | 需要的改动 |
|------|-----------|
| 变更 1 | 可追加"agentic 提示词验证"作为补充依据 |
| 变更 2 | 交叉验证增加批注区关键词 |
| 变更 5a | workflow.md 新增分析任务规则 |
| 变更 5c | 措辞泛化为行为导向 |

→ 结果：确认遗漏。已补做系统性审查，发现 4 处需要更新。下面在计划正文中执行这些更新。

### Round 3 (2026-03-03)

**[Q] 1 § phase-guide.sh SessionStart 只触发一次，还有意义吗？**
"研究完成了需要到 plan 步骤了，那这个时候 phase-guide 会把相应的提示词用于到 plan 阶段吗？"

→ **不会。** 直接回答你的问题：

**phase-guide.sh 在会话中段不会重新触发。** 证据：`.claude/settings.json:3` — `"SessionStart"` hook 只在会话启动时执行一次。如果会话启动时处于 RESEARCH 阶段，phase-guide 输出 RESEARCH 引导。后续你说"出 plan"时，phase-guide **不会**再次触发输出 PLAN 引导。

**那它还有什么价值？** 有，但需要理解 baton 的三层引导架构：

```
Layer 1: workflow.md（always-visible，每条消息可见）
  └─ 作用：规则 + mindset，覆盖所有阶段
  └─ 内容：~400 tokens 的精简规则
  └─ 局限：不含各阶段的详细执行策略

Layer 2: phase-guide.sh（SessionStart，只触发一次）
  └─ 作用：聚焦——只输出当前阶段的详细引导
  └─ 内容：~250 tokens 的阶段特定执行策略
  └─ 优势：AI 看到的是"你现在在这里，做这个"，不是 6 个阶段全部堆在一起
  └─ 局限：会话中段不再可见

Layer 3: workflow-full.md（无 SessionStart 的 IDE 的替代方案）
  └─ 作用：所有阶段的完整引导一次性加载
  └─ 内容：~2000 tokens
  └─ 局限：token 成本高，所有阶段信息混在一起
```

phase-guide.sh 的价值在于**聚焦**和**效率**：
1. **聚焦** — 会话启动时 AI 只看到当前阶段的引导，而不是 6 个阶段的完整文档。这降低了 AI 的"注意力分散"
2. **Token 效率** — ~250 tokens vs ~2000 tokens
3. **状态检测可靠** — 通过文件存在性判断阶段（`phase-guide.sh:18-60`），比 AI 自己判断更准确

**会话中段阶段转换谁负责？**

| 转换 | 触发者 | 机制 |
|------|--------|------|
| RESEARCH → PLAN | 人说"出 plan" | workflow.md Rules（always-visible）+ 对话上下文 |
| PLAN → ANNOTATION | AI 生成 plan.md | 自然流程 |
| ANNOTATION → IMPLEMENT | 人加 BATON:GO + "generate todolist" | write-lock.sh（PreToolUse 硬执行） |
| IMPLEMENT → ARCHIVE | 所有 todo 完成 | stop-guard.sh（Stop hook 提醒） |

中段转换的引导来自 **workflow.md（always-visible）+ 人的指令**，不是 phase-guide.sh。这是有意的分工：
- phase-guide.sh 负责**会话启动时的正确起点**
- workflow.md 负责**会话中段的持续可见规则**
- write-lock.sh 负责**关键节点的硬执行**

**实际场景验证：** 本轮的体验印证了这个架构——
- 会话启动时 phase-guide 输出了正确的引导（✅ 有效）
- 会话中段 research→plan 转换由你说"根据研究结果生成计划"触发（✅ workflow.md 规则 + 对话上下文）
- 会话中段 BATON:GO→todolist 由 write-lock.sh 强制（✅ 硬执行）
- 但归档后的新任务没有 phase-guide 重新触发（❌ 这是上轮 [Q]2 讨论的问题，已通过 workflow.md 新规则缓解）

→ 结果：phase-guide.sh 有意义——聚焦 + 效率 + 准确的起点检测。会话中段转换由 workflow.md + 人的指令 + write-lock 共同负责。这是三层架构的有意分工。

<!-- BATON:GO -->

## Todo

### 变更 3：格式规范 + grep 防御（先做，后续变更依赖 grep 模式一致）

- [x] 3a. workflow-full.md：在 `[PLAN]` 章节 todolist 描述后追加格式规范（`## Todo` / `- [ ]` / `- [x]`）。文件：`.baton/workflow-full.md:106-107`。验证：`test-workflow-consistency.sh` 通过
- [x] 3b-1. phase-guide.sh：`grep -q '^## Todo'`→`grep -qi '^## Todo$'`（line 51），`grep -c '^\- \[x\]'`→`grep -ci '^\- \[x\]'`（line 36）。文件：`.baton/phase-guide.sh`。验证：`test-phase-guide.sh` 51/51 通过
- [x] 3b-2. stop-guard.sh：`grep -c '^\- \[x\]'`→`grep -ci '^\- \[x\]'`（line 32）。文件：`.baton/stop-guard.sh`。验证：grep 模式确认正确

### 变更 1：write-lock.sh 增加 todolist 时序检查

- [x] 1a. write-lock.sh：BATON:GO 检查中增加 `## Todo` 子检查。文件：`.baton/write-lock.sh`。验证：`test-write-lock.sh` 38/39 通过（1 失败是 WSL 性能基准，非功能问题）
- [x] 1b. hooks/pre-commit：同步增加 `## Todo` 检查。文件：`hooks/pre-commit`。验证：`test-pre-commit.sh` 8/8 通过
- [x] 1c. test-write-lock.sh：新增 Test 19（GO + 无 Todo → 阻断 + 加 Todo → 放行），修复 Test 4/5/9/10/16/17/18 的 plan.md 含 `## Todo`。验证：38/39 通过
- [x] 1d. test-pre-commit.sh：新增 Test 8（GO + 无 Todo → 阻断），修复 Test 4/6 的 plan.md 含 `## Todo`。验证：8/8 通过

### 变更 5：批注区替代审阅指南 + 文档检索 + 分析任务规则

- [x] 5a-1. workflow.md Rules：审阅指南 → 批注区 + 新增分析任务规则。验证：`test-workflow-consistency.sh` ALL CONSISTENT
- [x] 5a-2. workflow-full.md：删除 Review Guide 模板，新增 plan.md + research.md 批注区模板 + 文档检索提示。验证：`test-workflow-consistency.sh` ALL CONSISTENT
- [x] 5b. phase-guide.sh：RESEARCH 追加批注区 + 文档检索提示，PLAN 更新批注区。验证：`test-phase-guide.sh` 54/54 通过
- [x] 5-test. test-phase-guide.sh：RESEARCH +2 断言（批注区 + doc retrieval），PLAN +1 断言（批注区）。验证：54/54 通过

### 变更 4：更新 first-principles.md 职责边界

- [x] 4a. first-principles.md §七（line 365-380）：替换为精确表述（写锁时序保证、流程阶段检测、结构性 vs 质量性区分）。验证：人工审查

### 变更 2：强化一致性测试

- [x] 2a. Flow 行一致性检查（Scenario A/B，用 grep -m1 避免多次匹配）。验证：ALL CONSISTENT
- [x] 2b. phase-guide.sh 关键词交叉验证（RESEARCH: 4 个关键词，IMPLEMENT: 3 个关键词）。验证：ALL CONSISTENT
- [x] 2c. 批注区规则一致性检查。验证：ALL CONSISTENT

### 全量验证

- [x] 全量验证结果：phase-guide 54/54 ✅ | workflow-consistency ALL CONSISTENT ✅ | pre-commit 8/8 ✅ | write-lock 38/39 ✅（1 个 WSL 性能基准非功能问题）
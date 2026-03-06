# Baton 项目深度分析：基于实施经验的观察

> 日期：2026-03-03
> 范围：基于两轮实施任务（Phase 1 多 IDE 支持 + Workflow UX 改进 + Todolist 强化）的实际经验
> 方法：从执行中的失败和摩擦出发，反向追踪架构问题

---

## 一、研究范围

读取并分析了以下文件：

| 文件 | 目的 |
|------|------|
| `.baton/write-lock.sh` (93行) | 写锁 — 硬执行 |
| `.baton/phase-guide.sh` (167行) | 阶段引导 — 软引导 |
| `.baton/stop-guard.sh` (49行) | 停止提醒 — 软引导 |
| `.baton/bash-guard.sh` (38行) | Bash 警告 — 软引导 |
| `.baton/workflow.md` (49行) | 精简规则 |
| `.baton/workflow-full.md` (272行) | 完整规则 |
| `docs/first-principles.md` (512行) | 第一性原理设计 |
| `tests/test-workflow-consistency.sh` (85行) | 一致性测试 |
| 全部 10 个测试文件 | 测试覆盖 |

---

## 二、发现 1：软引导 vs 硬执行的落差

### 现象

这轮实施中，AI（我）在 BATON:GO 后直接跳过了 todolist 步骤开始实施。phase-guide.sh 在 SessionStart 时曾输出提醒，但这个提醒：

1. 只在会话启动时出现一次（SessionStart hook）
2. 是纯文字输出到 stderr，不阻断任何操作
3. AI 在会话中途不会再看到这个提醒

### 代码证据

baton 的执行层有两个硬度级别：

| 级别 | 机制 | 文件 | 效果 |
|------|------|------|------|
| **硬** | write-lock.sh `exit 1` | `write-lock.sh:81,91` | 物理阻断工具调用 |
| **软** | phase-guide.sh `cat >&2` | `phase-guide.sh:52-57` | 输出文字提醒，`exit 0` |

write-lock.sh 的拦截从未被绕过——它返回 `exit 1`（`write-lock.sh:81`）或 `exit 2`，IDE 直接阻断工具执行。

phase-guide.sh 的提醒则频繁被忽略——它始终返回 `exit 0`（`phase-guide.sh:58`），对 AI 行为无物理约束。

### 根因

`first-principles.md:110-112` 明确写到：

> 写锁的本质不是"控制 AI"，而是"保证时序"：共同理解必须先于代码修改。
> 写锁是最简单的实现：plan.md 存在且被审批 → 放行。否则 → 阻止。

但 todolist 要求目前只存在于 workflow 规则文字中（`workflow.md:34`），phase-guide.sh 只做文字提醒（`phase-guide.sh:49-60`），write-lock.sh 不检查 `## Todo`（`write-lock.sh:85-87` 只检查 BATON:GO）。

### 风险评估

- ❌ **todolist 可以被跳过**：已发生。phase-guide.sh 的 AWAITING_TODO 状态只是建议
- ✅ **write-lock 可靠**：从未被绕过
- ❓ **是否应该把 todolist 检查提升到 write-lock 层？**

  如果提升：write-lock.sh 在 BATON:GO 存在但 `## Todo` 不存在时返回 `exit 1`，物理阻断代码写入。效果：AI 无法跳过 todolist。

  风险：增加了 write-lock.sh 的复杂度。`first-principles.md:320-323` 刻意强调写锁要简单：
  > 简单 → 不容易出 bug → 可靠
  > 简单 → token 开销小

  这是一个设计权衡：**简洁 vs 可靠执行**。目前的软引导已被证明不够。

---

## 三、发现 2：三文件同步是维护负担

### 现象

每次流程变更都需要同步修改三个文件：
- `workflow.md` — AI 读的精简版（CLAUDE.md 引用）
- `workflow-full.md` — AI 读的完整版（无 SessionStart 的 IDE 使用）
- `phase-guide.sh` — SessionStart 输出的引导文字

这轮实施的 5 个变更，每个都在 3 个文件中做了对应修改（共 15 次编辑）。

### 代码证据

三文件的重叠关系：

```
workflow.md       ←→ workflow-full.md（前 49 行完全相同）
                      ↓
                  workflow-full.md（第 50-267 行是扩展内容）
                      ↓
                  phase-guide.sh（引导文字与 workflow-full.md 各阶段内容重复）
```

`phase-guide.sh:5-6` 的注释承认了这一点：
```
# NOTE: Guidance text intentionally duplicates workflow-full.md sections.
# When updating, sync both files.
```

一致性保障：
- `test-workflow-consistency.sh:14-23` — 检查 Rules/Session handoff/Parallel sessions 三个章节在 workflow.md 和 workflow-full.md 之间一致
- `test-workflow-consistency.sh:28-35` — 检查 header block（第一个 `---` 之前）一致
- `test-annotation-protocol.sh` — 检查标注类型在两个文件中都存在

但这些测试只检查**章节级别**的一致性，不检查**具体措辞**是否语义一致。例如 phase-guide.sh 的 ANNOTATION 阶段文字和 workflow-full.md 的 [ANNOTATION] 章节措辞不同但语义相同——测试不覆盖这种一致性。

### 根因

为什么需要三份？

| 文件 | 存在原因 |
|------|---------|
| `workflow.md` | 作为 always-loaded context（CLAUDE.md 引用），必须精简（~400 tokens） |
| `workflow-full.md` | 无 SessionStart 支持的 IDE（如 Cline）需要完整规则一次性加载 |
| `phase-guide.sh` | 有 SessionStart 支持的 IDE（Claude/Cursor/Factory）按阶段加载动态内容 |

三者的 token 预算不同，所以不能合并。但重叠内容导致每次修改都是 N×M 操作。

### 风险评估

- ❌ **重复内容导致同步遗漏的风险高**：已经在实施中多次需要检查是否所有文件都同步了
- ✅ **一致性测试部分覆盖**：章节标题和关键标记的一致性有测试保障
- ❓ **是否可以用生成方式减少重复？** 例如从 workflow-full.md 自动生成 workflow.md 和 phase-guide.sh 的文字部分。但这增加了构建步骤。

---

## 四、发现 3：状态机复杂度在增长

### 现象

phase-guide.sh 的状态从最初设计的 4 个（`first-principles.md:330-348`）增长到了 6 个：

```
设计文档（first-principles.md）:  4 个状态
当前 phase-guide.sh:              6 个状态

新增：
- AWAITING_TODO（BATON:GO + 无 ## Todo）
- ARCHIVE 从"完成"独立出来
```

### 代码证据

状态检测用顺序 if-else 实现（`phase-guide.sh:33-166`），每个状态用 `grep` 检查文件内容：

```sh
# State 1: ARCHIVE — grep BATON:GO + count checkboxes
grep -q '<!-- BATON:GO -->' "$PLAN"           # phase-guide.sh:34
grep -c '^\- \[' "$PLAN"                       # phase-guide.sh:35
grep -c '^\- \[x\]' "$PLAN"                   # phase-guide.sh:36

# State 2: AWAITING_TODO — grep BATON:GO + grep ^## Todo
grep -q '<!-- BATON:GO -->' "$PLAN"           # phase-guide.sh:50
grep -q '^## Todo' "$PLAN"                     # phase-guide.sh:51

# State 3: IMPLEMENT — grep BATON:GO (implicit: ## Todo exists)
grep -q '<!-- BATON:GO -->' "$PLAN"           # phase-guide.sh:63
```

脆弱点：
- `grep '^\- \[x\]'`（`phase-guide.sh:36`）假设 checkbox 格式严格为 `- [x]`。如果用 `* [x]` 或 `- [X]`，不会匹配。
- `grep '^## Todo'`（`phase-guide.sh:51`）假设章节标题精确为 `## Todo`。如果 AI 生成 `## Todolist` 或 `## TODO`，不会匹配。
- 同一个 BATON:GO grep 在 3 个 if 块中重复执行（`phase-guide.sh:34,50,63`）。

### 风险评估

- ⚠️ **格式敏感**：状态检测依赖精确的文本格式匹配，变体会导致误判
- ✅ **当前可控**：6 个状态还在可维护范围内
- ❓ **未来扩展风险**：如果继续增加状态（如 "等待 code review"、"等待 merge"），顺序 if-else 会变得难以维护

---

## 五、发现 4：第一性原理设计 vs 当前实现的偏移

### 现象

`first-principles.md` 明确定义了 Baton 的职责边界（`first-principles.md:366-380`）：

```
Baton 不做什么：
├── 不检查文档质量 — 研究够不够深由人通过标注循环判断，不由 hook 判断
├── 不管理任务状态 — 不做项目管理
```

但当前实现已经在 phase-guide.sh 中做了一些超出这个边界的事：
- `phase-guide.sh:35-36` — 计数 checkboxes（任务状态管理的雏形）
- `phase-guide.sh:51` — 检查 `## Todo` 是否存在（文档质量检查的雏形）

这不是"错误"——设计文档是 2026-03-02 的，实现是基于实际使用反馈迭代的。但值得注意这个偏移方向：**从"只保证时序"向"引导流程"演变**。

### 风险评估

- ❓ **设计哲学漂移**：需要人决定是接受这个演变方向，还是回归更纯粹的"只做写锁"理念
- `first-principles.md:141` 说 "Baton 只做一件事：确保人和 AI 在动手之前充分交换了信息"
- 但实际使用证明，纯粹的"信息交换"不够——流程引导也有必要

---

## 六、发现 5：什么确实有效

### 标注循环有效

这轮工作中标注循环被使用了 3 次：
1. `[Q]` 关于 plan 被覆盖 → 导致新增归档规则
2. `[NOTE]` 关于 todolist 是否 optional → 导致流程修订
3. `[CHANGE]` 关于审阅指南位置 → 导致移到开头

每次标注都产生了实质性的设计改进。这验证了 `first-principles.md:84-88` 的核心论点：结构化反馈比自由对话更有效。

### write-lock 可靠

write-lock.sh 在整个实施过程中从未被绕过，也从未误拦截。它的设计确实做到了 `first-principles.md:320-323` 要求的简洁和可靠。

### 测试套件保住了底线

每次修改后运行测试：
- `test-workflow-consistency.sh` 捕获了文件同步问题
- `test-phase-guide.sh` 验证了状态检测逻辑
- `test-annotation-protocol.sh` 验证了标注类型完整性

51 + ALL CONSISTENT + 25 = 全部通过，给了信心。

---

## 七、总结：关键问题排序

| # | 问题 | 严重度 | 已验证 |
|---|------|--------|--------|
| 1 | 软引导不够——todolist 被跳过 | ❌ 高（已发生） | ✅ 亲历 |
| 2 | 三文件同步负担 | ⚠️ 中（增加维护成本） | ✅ 亲历 |
| 3 | 状态机格式敏感 | ⚠️ 中（潜在误判） | ❓ 未触发但可预见 |
| 4 | 设计哲学漂移 | ❓ 需要人决定方向 | ✅ 代码证据确认 |
| 5 | 标注循环/write-lock/测试有效 | ✅ 正面确认 | ✅ 亲历 |

---

## 八、深入分析：四个架构问题

### 问题 1：是否将 todolist 检查提升到 write-lock.sh？

#### 当前状态

write-lock.sh 的判断逻辑（`write-lock.sh:77-92`）：

```
目标是 .md → 放行
无 plan.md → exit 1（阻断）
plan.md 有 BATON:GO → exit 0（放行）     ← 这里不检查 ## Todo
plan.md 无 BATON:GO → exit 1（阻断）
```

如果在 BATON:GO 检查中增加 `## Todo` 检查，变为：

```
plan.md 有 BATON:GO + 有 ## Todo → exit 0（放行）
plan.md 有 BATON:GO + 无 ## Todo → exit 1（阻断 + 提示生成 todolist）
```

代码变更量：write-lock.sh:84-87 从 3 行变为 ~8 行。

#### 核心权衡

`first-principles.md:306-323` 定义了写锁的设计哲学：

> 写锁的职责是**保证时序**，不是质量检查。

关键问题：todolist 检查是"时序保证"还是"质量检查"？

**我的判断：是时序保证。** 理由：
- "plan 审批前不能写代码"是时序保证 → write-lock 已执行此检查
- "todolist 生成前不能实施"也是时序保证 → 同类性质
- "research.md 是否够深"才是质量检查 → write-lock 不检查，正确

todolist 不是"文档是否足够好"的判断，而是"流程步骤是否完成"的判断。这和 BATON:GO 检查是同一类。

#### 风险分析

**提升的收益：**
- ✅ 物理阻断，AI 无法跳过（已证明软引导不够）
- ✅ 与 write-lock 现有职责一致（时序保证）
- ✅ 变更量小（~5 行代码）

**提升的风险：**
- ⚠️ `grep '^## Todo'` 格式敏感（见问题 3）
- ⚠️ 增加了 write-lock.sh 的判断分支
- ⚠️ 每次 Edit/Write 调用多一次 grep（性能影响可忽略，grep 本身 <1ms）

**不提升的风险：**
- ❌ todolist 继续可被跳过（已发生过）
- ❌ 软引导只在 SessionStart 时出现一次，会话中途无效

#### 结论

✅ **建议提升。** todolist 检查本质是时序保证，符合 write-lock 的职责定义。实战证明软引导不够。代码变更量小（~5 行），性能影响可忽略。

需要同步解决问题 3（格式敏感）以保证 grep 可靠。

---

### 问题 2：三文件同步如何改善？

#### 四个方案对比

**方案 A：从 workflow-full.md 自动生成 workflow.md**

```sh
# workflow.md = workflow-full.md 的前 49 行（第一个 --- 之前）
awk '/^---$/{exit} {print}' .baton/workflow-full.md > .baton/workflow.md
```

- 优点：消除 workflow.md 与 workflow-full.md 前 49 行的重复
- 缺点：workflow.md 变成构建产物，CLAUDE.md 引用的是生成文件。直接编辑 workflow.md 会被覆盖
- ❌ 不推荐：引入构建步骤增加了维护复杂度

**方案 B：CLAUDE.md 直接引用 workflow-full.md**

- 优点：消除 workflow.md
- 缺点：workflow-full.md ~272 行 ~2000 tokens，作为 always-loaded context 太重。有 SessionStart 的 IDE 不需要完整版
- ❌ 不推荐：token 成本过高

**方案 C：提取共享部分到独立文件**

```
workflow-shared.md（共享 header 49 行）
workflow.md = @workflow-shared.md
workflow-full.md = @workflow-shared.md + 扩展内容
```

- 缺点：不是所有 IDE 支持嵌套 import。CLAUDE.md 的 `@` 引用语法是 Claude Code 特有的
- ❌ 不推荐：跨 IDE 兼容性问题

**方案 D：接受重复，强化一致性测试**

当前 `test-workflow-consistency.sh` 检查的内容（`test-workflow-consistency.sh:14-35`）：
- ✅ Rules / Session handoff / Parallel sessions 三个章节完全一致
- ✅ header block（第一个 `---` 之前）完全一致
- ❌ 不检查 phase-guide.sh 引导文字与 workflow-full.md 的语义一致性

可增强：
1. 检查 phase-guide.sh 中的关键关键词是否出现在 workflow-full.md 对应章节中
2. 检查 Flow 行在两个 workflow 文件中一致
3. 在 phase-guide.sh 的注释中标注 "SYNCED with workflow-full.md §PLAN" 等，提醒开发者

- 优点：零架构变更，渐进式改善
- 缺点：不消除重复本身，只降低同步遗漏的概率

#### 数据

实际重复量：
- workflow.md ↔ workflow-full.md：49 行完全相同（已有测试覆盖）
- workflow-full.md ↔ phase-guide.sh：~60 行语义重复但措辞不同（无测试覆盖）

最大风险来自第二种重复——phase-guide.sh 和 workflow-full.md 的语义重复。但这种重复是**有意为之**的（`phase-guide.sh:5-6`），因为 phase-guide.sh 需要更精炼的措辞（输出到 stderr，需要简短）。

#### 结论

✅ **推荐方案 D。** 重复量可控（49 行精确重复 + ~60 行语义重复），消除重复的方案都引入了更多复杂度。正确的应对是强化测试，在 `test-workflow-consistency.sh` 中增加更多内容级别的检查。

---

### 问题 3：状态检测格式敏感性

#### 所有 grep 模式清单

跨 5 个脚本，共使用以下状态检测模式：

| 模式 | 含义 | 使用位置 | 敏感点 |
|------|------|---------|--------|
| `<!-- BATON:GO -->` | 审批标记 | write-lock.sh:85, phase-guide.sh:34/50/63, stop-guard.sh:28, bash-guard.sh:19, hooks/pre-commit:37 | 精确匹配，无变体风险（人类直接复制粘贴） |
| `^\- \[` | 任意 checkbox | phase-guide.sh:35, stop-guard.sh:31 | `* [` 不匹配，缩进的 `  - [` 不匹配 |
| `^\- \[x\]` | 已完成 checkbox | phase-guide.sh:36, stop-guard.sh:32 | `- [X]` 不匹配 |
| `^## Todo` | Todo 章节标题 | phase-guide.sh:51 | `## TODO`/`## Todolist` 不匹配 |

#### 风险实际有多大？

这些模式匹配的是 **AI 生成的内容**，不是人类手写的内容。AI 生成 todolist 时由 workflow 规则控制格式。

关键判断：**如果 workflow 规则明确规定格式，且 AI 始终遵守，则 grep 不需要容错。**

当前 workflow 的格式规定：
- `workflow.md:34` — "Append ## Todo only after human says 'generate todolist'" — 规定了章节名 `## Todo`
- 但没有明确规定 checkbox 格式必须是 `- [ ]` / `- [x]`

#### 具体方案

**方案 A：在 workflow 中明确格式规范**（推荐）

在 workflow-full.md 的 [PLAN] 章节追加：

```
Todolist format (strict — must match grep patterns in phase-guide.sh):
- Section header: ## Todo (exact case)
- Items: - [ ] description (dash, space, bracket, space, bracket)
- Completed: - [x] description (lowercase x)
```

- 优点：零代码变更，通过规则保证格式一致
- 格式由 AI 生成 + 规则控制 = grep 匹配可靠

**方案 B：grep 大小写不敏感**

```sh
grep -ic '^\- \[x\]' "$PLAN"    # 匹配 [x] 和 [X]
grep -i '^## todo' "$PLAN"       # 匹配 Todo、TODO、todo
```

- 优点：更鲁棒
- 缺点：可能匹配到不应匹配的内容（如文档中讨论 "## TODO design" 的段落）

#### 结论

✅ **推荐方案 A + B 结合。** 先在 workflow-full.md 中明确格式规范（方案 A），同时 grep 增加 `-i` flag 作为防御层（方案 B）。对于 `^## Todo`，可改为 `^## Todo$`（精确行匹配）避免误匹配。

---

### 问题 4：Baton 的职责边界是否需要重新定义？

#### 第一性原理 vs 实际演变

`first-principles.md:366-380` 的原始定义：

```
Baton 做什么：
├── 写锁 — plan.md + BATON:GO 才能写源码
├── 标注协议 — 6 种标注类型 + AI 回应规则
├── Annotation Log — 持久化每轮对话
├── 阶段引导 — SessionStart 提示当前该做什么
└── research/plan 深度引导 — 提示（非强制）应包含的内容

Baton 不做什么：
├── 不检查文档质量
├── 不管理任务状态
```

当前实现已超出原始定义的地方：

| 行为 | 所在文件 | 原始分类 | 实际性质 |
|------|---------|---------|---------|
| 计数 checkboxes | phase-guide.sh:35-36, stop-guard.sh:31-32 | "任务状态管理" | **流程阶段检测**（用于判断 ARCHIVE vs IMPLEMENT） |
| 检查 `## Todo` 存在 | phase-guide.sh:51 | "文档质量检查" | **流程步骤完成性检测**（todolist 是否已生成） |

#### 重新审视

原始定义中的"不检查文档质量"和"不管理任务状态"，其实际含义是：

- **不检查文档质量** = 不判断 research.md 是否"够深"、plan.md 是否"够完整"。这是正确的——深度由人通过标注循环判断。
- **不管理任务状态** = 不做项目管理（谁负责什么、截止日期等）。这也是正确的。

但 phase-guide.sh 做的事不属于以上任何一种：
- 计数 checkboxes 是判断"所有流程步骤是否完成"，不是"任务管理"
- 检查 `## Todo` 是判断"流程步骤是否执行"，不是"文档是否足够好"

#### 建议的边界重新表述

将 `first-principles.md` 的职责定义修正为：

```
Baton 做什么：
├── 写锁 — 时序保证（BATON:GO + ## Todo 才能写源码）
├── 流程阶段检测 — 检测当前处于哪个流程步骤（结构性检查，非质量判断）
├── 标注协议 — 6 种标注类型 + AI 回应规则
├── Annotation Log — 持久化每轮对话
├── 阶段引导 — 当前阶段的行为提示
└── research/plan 深度引导 — 提示（非强制）应包含的内容

Baton 不做什么：
├── 不判断文档质量 — "research 够不够深" 由人通过标注循环判断
├── 不做项目管理 — 不跟踪任务分配、优先级、截止日期
├── 不规定方法论 — 研究方法、实现方法、代码审查方法由其他系统决定
```

关键区分：
- **结构性检查**（`## Todo` 是否存在、checkboxes 是否全部完成）→ Baton 做 ✅
- **质量性判断**（research 是否够深、plan 是否够好）→ Baton 不做 ❌

#### 结论

✅ **接受演变方向，更新 first-principles.md 的职责边界表述。** 当前实现没有偏离设计精神，只是原始表述过于笼统。"结构性检查 vs 质量性判断"是更精确的边界划分。

[NOTE]:
  1.todolist 是时序保证，不是质量检查 生成计划后 人审阅通过 开始实施 但是实施是需要一个步骤的 这个步骤就是生成todolist 然后生成todolist后 由人检查todolist是否合理 这个检查是质量检查 但是todolist的生成是时序保证 因为它保证了"生成计划后 人审阅通过 开始实施"这个流程步骤的正确执行

[Q]:
  1. research 阶段的 标注位置不明确 我不知道再哪儿标注
  2. 之前修改了workflow.md 和 workflow-full.md 还有phse-guide.sh 这三个文件 是否符合之前讨论的agentic-prompts.md中的

---

## Annotation Log

### Round 1 (2026-03-03)

**[NOTE] § 问题 1 / 问题 4 — todolist 的本质**
"todolist 是时序保证，不是质量检查。生成 todolist 后由人检查是否合理——检查是质量检查，但生成是时序保证。"
→ 这个 NOTE 为问题 1 和问题 4 的分析增加了更精确的区分。完整流程的质量/时序分层：

```
plan.md 审阅通过 → BATON:GO      ← 时序保证（write-lock 执行）
生成 todolist → ## Todo 存在     ← 时序保证（应由 write-lock 执行）
人检查 todolist 是否合理         ← 质量检查（由人判断，Baton 不介入）
开始实施                         ← write-lock 放行
```

Baton 负责前两步（时序），不负责第三步（质量）。这与 first-principles.md 的设计哲学一致——Baton 保证步骤顺序，不判断内容好坏。
→ 结果：采纳。已纳入问题 1 和问题 4 的分析框架。

**[Q] 1 § research 阶段标注位置不明确**
"research 阶段我不知道在哪儿标注"

→ 调查：这和之前 plan.md 的问题一模一样。我们给 plan.md 加了 `## 审阅指南`（`workflow.md:41`），但 **research.md 没有对应的引导**。

代码证据：
- `workflow.md:41` — "plan.md must begin with a ## 审阅指南 section" — 只规定了 plan.md
- `workflow-full.md:88-89` — "In Scenario B, research.md may go through annotation cycles" — research.md 允许标注
- `phase-guide.sh:144-165` — RESEARCH phase 引导中没有提到审阅指南
- 当前这份 research.md 本身就没有审阅指南——你的标注是直接加在文档末尾的

**缺口确认：** ❌ research.md 没有审阅指南，但 Scenario B 要求 research.md 支持标注循环。人无法得知在哪标注、标注什么格式。

**修复方向：** 和 plan.md 同理，AI 生成 research.md 时也应在标题后附 `## 审阅指南`。内容略有不同：
- plan.md 的审阅指南提到 BATON:GO 和 todolist
- research.md 的审阅指南应提到"审阅完毕后告诉 AI 出 plan"

需要更新：workflow.md、workflow-full.md、phase-guide.sh 中增加 research.md 的审阅指南要求。

→ 结果：确认是缺口，需要在后续 plan 中修复

**[Q] 2 § 当前文件是否符合 agentic-prompts.md**
"之前修改了 workflow.md、workflow-full.md、phase-guide.sh，是否符合 agentic-prompts.md 的设计？"

→ 逐项验证 `docs/plans/2026-03-03-agentic-prompts.md` 的 5 个 Task：

**Task 1（workflow.md — Mindset + 标注优化）：**
- ✅ Mindset section 已添加（`workflow.md:3-11`）— 与 agentic-prompts.md:22-34 一致
- ✅ `[Q]` 已改为 "Read code first — don't answer from memory"（`workflow.md:24`）
- ✅ `[CHANGE]` 已改为 "verify safety first"（`workflow.md:25`）
- ✅ `[DEEPER]` 已改为 "your previous work was insufficient"（`workflow.md:26`）

**Task 2（phase-guide.sh — 各阶段执行策略）：**
- ✅ RESEARCH phase 已扩展（`phase-guide.sh:144-165`）— 与 agentic-prompts.md:67-84 一致
- ✅ PLAN phase 已扩展（`phase-guide.sh:118-141`）— 基于 agentic-prompts.md:98-116，后续迭代了 todolist required + 审阅指南位置
- ✅ ANNOTATION phase 已扩展（`phase-guide.sh:86-116`）— 基于 agentic-prompts.md:130-153，后续迭代了 todolist 必须步骤
- ✅ IMPLEMENT phase 已扩展（`phase-guide.sh:62-84`）— 与 agentic-prompts.md:165-182 一致

**Task 3（workflow-full.md — 同步 + 强化）：**
- ✅ Mindset section 已添加（`workflow-full.md:3-11`）
- ✅ [RESEARCH] 有 Execution Strategy（`workflow-full.md:65-71`）
- ✅ [ANNOTATION] 有 Thinking Posture（`workflow-full.md:182-196`）
- ✅ [IMPLEMENT] 有 Per-Item Execution Sequence（`workflow-full.md:244-250`）
- ✅ 审阅指南模板已添加（`workflow-full.md:109-134`）

**Task 4（测试更新）：**
- ✅ test-phase-guide.sh 已更新（51/51 passing）
- ✅ test-workflow-consistency.sh passing（ALL CONSISTENT）

**Task 5（全量验证）：**
- ✅ 所有测试通过

**差异说明：** 当前实现与 agentic-prompts.md 有以下**有意的偏离**（通过后续标注循环产生）：

| agentic-prompts.md 原始 | 当前实现 | 变更原因 |
|-------------------------|---------|---------|
| "Do NOT write todolist" | "Todolist is required" | 用户要求 todolist 是必须步骤 |
| "Human will say 'generate todolist' or add BATON:GO" | BATON:GO 先行，todolist 后行 | 用户明确 BATON:GO 是唯一审批门 |
| plan.md 末尾附审阅指南 | plan.md 开头附审阅指南 | [CHANGE] 标注，开头更显眼 |
| 无 AWAITING_TODO 状态 | phase-guide.sh 新增此状态 | todolist 必须步骤的检测需求 |

这些偏离都是通过 Baton 标注循环产生的设计迭代，符合 agentic-prompts.md 的精神（改善 AI 引导），只是具体内容随实战反馈演进了。

→ 结果：✅ 符合 agentic-prompts.md 的设计方向，有 4 处有意的迭代偏离，均有标注记录

---

## Supplement: AI 研究阶段是否应主动使用文档检索工具

> 来源：plan.md [RESEARCH-GAP] 1 — "调查 IDE hook 时没有调用工具去检索官方文档"

### 实验：Context7 检索 vs 纯代码阅读

用 Context7 分别检索 Claude Code 和 Cursor 的 hook 文档，对比之前纯代码阅读的研究深度。

#### Claude Code hooks（Context7 结果）

Context7 返回了来自 `anthropics/claude-code` 仓库的权威文档：
- Hook 类型：PreToolUse, PostToolUse, Stop, SessionStart
- 支持两种类型：`command`（执行脚本）和 `prompt`（LLM 评估）
- Matcher 支持正则过滤：`Write|Edit`, `Bash`, `.*`
- 有 timeout 配置

**对比之前的研究**：之前的 `docs/research-ide-hooks.md` 也记录了这些信息，因为 baton 本身就在 Claude Code 上开发。Context7 的结果和我们已知的一致。**增量价值：低。**

#### Cursor hooks（Context7 结果）— 重大发现

Context7 返回了来自 `cursor.com/docs/agent/hooks` 的官方文档，揭示了 Cursor 的 hook 系统远比我们之前了解的丰富：

**之前我们知道的**（来自代码和有限的文档）：
- `beforeShellExecution` — 存在，细节不确定
- 使用 `hooks.json` 配置

**Context7 揭示的完整 hook 列表**：
```
sessionStart, sessionEnd,
beforeShellExecution, afterShellExecution,
beforeMCPExecution, afterMCPExecution,
afterFileEdit,
beforeSubmitPrompt,
preCompact,
stop,
beforeTabFileRead, afterTabFileEdit
```

**关键发现**：`beforeShellExecution` 和 `beforeMCPExecution` 支持硬阻断：
```json
{
  "permission": "deny",
  "user_message": "Blocked by hook",
  "agent_message": "Explanation for the agent"
}
```

这意味着 Cursor 的 hook 支持 **`permission: "deny"` 硬拦截**，和 Claude Code 的 `exit 1` 硬拦截功能等价。但 baton 当前的 Cursor 适配器只用了 `afterFileEdit`（exit code 2 协议），没有利用 `beforeShellExecution`/`beforeMCPExecution` 的 permission deny 能力。

**增量价值：高。** 纯代码阅读无法得到这个信息，因为 Cursor 的 hook 文档不在 baton 代码库中。

### 结论：何时应该使用文档检索

| 场景 | 是否应调用检索 | 理由 |
|------|---------------|------|
| 调查外部系统能力（IDE hook、库 API、框架行为） | ✅ 是 | 代码库内没有外部系统的文档 |
| 研究到达"框架内部"停止点 | ✅ 是 | 官方文档能提供代码追踪无法获得的信息 |
| 结论为 "❓ unverified" 且与外部依赖相关 | ✅ 是 | 检索可以将 ❓ 转为 ✅ 或 ❌ |
| 分析项目内部代码逻辑 | ❌ 否 | 直接读代码更准确 |
| 调查不太知名的工具 | ⚠️ 视情况 | Context7 覆盖度取决于工具的文档质量 |

**不是所有调查都需要检索，但涉及外部系统能力的调查应该主动检索。**

建议：在 RESEARCH phase 引导中增加一条：
```
When stopping at external deps/framework internals:
- Use Context7 or web search to check authoritative documentation
- Prefer official docs over assumptions about API behavior
```

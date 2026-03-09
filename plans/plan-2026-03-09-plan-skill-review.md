# baton-plan Skill 评审分析

对照 `SKILL.md` 和 `workflow.md` 原文，逐条验证审阅者的判断。

---

## 审阅者说对了的部分

### 1. 正面评价全部准确

Plan as contract、Research derivation、Surface Scan、Direction Change Rule 这四个核心优点的评价都与实际文件吻合，没有夸大。

### 2. "对中小任务不够友好"（批评 #2）— 部分成立

`SKILL.md:30` 写 "For tasks of any complexity that involve code changes"，但主体流程确实按 Medium/Large 设计。skill 内部只有两处轻量化提示：
- `SKILL.md:32-33`："trivial changes where a 3-5 line plan summary suffices"
- `SKILL.md:104`："For Trivial/Small changes, Level 1 alone is sufficient"

审阅者说"复杂度分层不够显式、不够刚性"是对的——skill 内部没有写"Trivial 跳过 Surface Scan，Small 跳过 L2/L3"这样的显式裁剪规则。

**但审阅者遗漏了一个重要上下文**：`workflow.md:27-33` 已经有完整的复杂度分层定义（Trivial/Small/Medium/Large），且 `workflow.md:25` 明确说 Trivial/Small 可以跳过 research。skill 继承了这个框架但没有在内部重复它，这是设计选择而非遗漏。

**不过**，在 skill 内部加一份显式裁剪表仍然有价值，因为 `context: fork` 下 skill 可能看不到 workflow.md。这个建议值得采纳。

**二轮复核补充**：审阅者在二轮中确认"复杂度分层不够显式"这个批评本身仍然成立，但同意更准确的定性是"skill 内部没有自包含地复述上层裁剪规则"，而非"设计遗漏"。workflow.md 的覆盖情况被标为"条件成立"（审阅者未独立抓到 workflow.md 原文）。结论不变：加裁剪表。

### 3. "Annotation Protocol 篇幅偏长"（批评 #7）— 成立但程度被夸大

审阅者说 Self-Review、Direction Change Rule、Annotation Protocol 之间"有明显语义重叠"。实际情况：
- Self-Review（`SKILL.md:111-132`）：文档自检
- Direction Change Rule（`SKILL.md:222-231`）：方案变更后的全文同步
- Annotation Protocol（`SKILL.md:198-255`）：处理人类反馈的完整流程

Direction Change Rule 是 Annotation Protocol 的一个子规则，不是独立重复。重叠度没有审阅者说的那么大。但 Annotation Protocol 确实可以压缩——`SKILL.md:238-255` 的 Annotation Log Format 模板可以简化。

**二轮复核确认**：审阅者同意"有局部交叉，但职责并不相同"，前一版把它们说成"明显语义重叠"偏重了。Annotation Log Format 的展开程度属于可精简部分，不是核心机制本身。

---

## 审阅者说错了或混淆层级的部分

### 4. "职责过载，应拆分 core/extended"（批评 #1）— 定位判断，非缺陷

审阅者列了 12 项职责说"这不只是 plan skill"。但 baton-plan 的设计意图本来就是**计划阶段的完整执行指南**，不是"计划模板"。workflow.md 的 Phase Guidance（`workflow.md:73-76`）明确把 plan 作为一个独立阶段，skill 是该阶段的详细指导。

拆成 core/extended 会引入新的协调问题：什么时候用 core 什么时候用 extended？谁来判断？这比当前"一个 skill + workflow 层面的复杂度裁剪"更复杂，不一定更好。

**二轮复核确认**：审阅者同意这是"定位判断"而非"设计缺陷"。补充了一个限制："不是缺陷"不等于"不能优化"——如果未来使用场景变广，拆分仍可能有价值，但不应当作当前版本的硬伤。

### 5. "文件归档规则耦合过深"（批评 #6）— 归因错误

审阅者说 `mkdir -p plans && mv ...` 写死在 skill 里是过拟合。但这条规则来自 `workflow.md:42`（Action Boundary #7），是**工作流级约定**，不是 skill 自创的。skill 只是引用了上层约定。审阅者把 workflow 的决定当成了 skill 的问题。

**二轮复核**：审阅者认为反驳逻辑合理，但因未独立抓到 workflow.md 原文，给出"条件成立"评级——即如果 workflow 确有该约定，则前一版属于归因错误。置信度：中。

### 6. "不允许内部矛盾"过于绝对（批评 #4）— 混淆了两个已区分的概念

审阅者说 skill 没有区分"文档矛盾"和"待决方案分叉"。但 `SKILL.md:134-141` 已经明确处理了这个问题：

> "Present options: patching within current structure vs. fixing the root problem...
> Explicitly state: this is an architectural decision requiring human judgment.
> Don't decide for the human"

Iron Law #4（"NO INTERNAL CONTRADICTIONS"）指的是**文档 bug**（recommendation 说 A，change list 写 B），不是设计决策。`SKILL.md:134-141` 已经把"待人决策的分叉"作为独立场景处理了。审阅者要么没看到这段，要么混淆了这两个概念。

**二轮复核确认**：审阅者直接用 SKILL.md 原文验证，确认 Iron Law #4 针对的是文档内部自相矛盾，不是架构选项分叉。前一版将其理解成"所有分叉都必须在 presenting 前解决"属于误读。置信度：高。

### 7. "所有前提都必须本轮验证"过于理想化（批评 #3）— 意图被误读

`SKILL.md:124-126` 原文：

> "Every assumption the plan depends on — file locations, naming conventions, tool capabilities, project structure, API behavior — must be directly verified in this session"

审阅者把这理解成"验证所有依赖链行为"。但从给出的例子看（file locations, naming conventions, project structure），这条规则的真实意图是**防止 AI 从训练数据假设文件路径和项目结构**——这是 LLM 幻觉的高发区。

不过审阅者的建议（区分 critical premise / working assumption / blocked premise）确实能让这条规则更精确，减少 agent 过度验证的风险。**这个建议值得部分采纳**：可以明确"关键前提必须验证，非关键前提标为 assumption"。

**二轮复核确认**：审阅者同意前一版有过度解释，但也赞成改成"关键前提验证 + 显式假设"——在不改变原始防幻觉意图的前提下，让语义更可执行。置信度：高。

### 8. Todolist 门控是否"太保守"（批评 #5）

SKILL.md 已要求在正式 todolist 之前产出足够具体的 change list，并强调人类应能"read the plan and predict what the diff will look like"。批准前并非完全看不到执行轮廓，只是不命名为正式 Todo。

前一版提出"Execution Sketch"不是完全没道理，但更像风格偏好，不是文本层面的明显缺口。change list 已是执行预览，没必要再引入新概念。

**二轮复核确认**：审阅者同意"不改也说得通"。置信度：高。

---

## 总结评判

| 审阅者的 7 个批评 | 实际状态 | 值得改吗 | 二轮复核 |
|---|---|---|---|
| 1. 职责过载，应拆分 | 定位判断，非缺陷 | ❌ 不拆 | ✅ 确认 |
| 2. 中小任务不友好 | ⚠️ 成立，workflow 有分层但 skill 内没引用 | ✅ 加裁剪表 | ✅ 确认 |
| 3. "全部验证"过严 | ⚠️ 意图被误读，但措辞确实过硬 | ✅ 加 assumption 分级 | ✅ 确认 |
| 4. "矛盾"未区分两类 | ❌ 已区分（`SKILL.md:134-141`） | ❌ 不改 | ✅ 确认 |
| 5. Todolist 门控太保守 | 策略选择，change list 已是执行预览 | ❌ 不改 | ✅ 确认 |
| 6. 归档规则耦合过深 | ❌ 归因错误，来自 workflow.md | ❌ 不改 | ⚠️ 条件成立 |
| 7. Annotation Protocol 偏长 | ⚠️ 部分成立，Log Format 可简化 | 🔶 可选优化 | ✅ 确认 |

### 审阅者的 5 个改进建议

| 建议 | 判断 | 二轮复核 |
|---|---|---|
| 拆 core/extended | ❌ 引入新的协调复杂度，得不偿失 | ✅ 确认（但未来可能有价值） |
| 显式复杂度分层 | ✅ 最有价值的建议——在 skill 内加裁剪规则 | ✅ 确认 |
| 前提分级 | ✅ 值得做，从"全部验证"改为"关键验证+显式假设" | ✅ 确认 |
| 区分矛盾和分叉 | ❌ 已实现 | ✅ 确认 |
| 批准前允许 Execution Sketch | ❌ change list 已是执行预览，额外概念增加认知负担 | ✅ 确认 |

---

## 二轮复核总结

反审阅的核心价值在于区分了三种判断：
1. **文本里真的没写** — 对应 #2（裁剪表缺失）和 #3（premise 措辞过硬）
2. **文本写了，但审阅者读重了** — 对应 #4（矛盾已区分）、#7（重叠被夸大）、#3（意图被误读）
3. **文本没问题，只是审阅者不喜欢这种设计取向** — 对应 #1（拆分）、#5（门控）、#6（归档）

这三层分辨率是评审质量的核心指标。

---

## Core/Extended 拆分可行性分析

### 前提

baton-plan **没有 `context: fork`**，在主会话上下文中运行。这是分析的关键约束。

### 拆分面临的结构性问题

**问题 1：复杂度判定发生在计划过程中，不在计划之前**

workflow.md 的设计是"AI 提出复杂度，人类确认"（`workflow.md:33`）。这个判定发生在
planning 启动后，不是启动前。如果拆成两个 skill，要么先调用 core 再中途切换到
extended，要么提前猜测复杂度。两种都不自然。

**问题 2：Iron Law 必须存在于两个 skill 中**

Iron Law 是全局约束（不实现、不加 GO、不生成 todo、不留矛盾），无论 Trivial 还是
Large 都必须遵守。拆分后 core 和 extended 都必须包含 Iron Law，造成规则重复。
同理 Red Flags、Output Template、基本 Todolist Format 也需要双写。

**问题 3：Direction Change Rule 紧耦合 plan 主体**

Direction Change Rule 要求"方向变更时全文重新对齐"——直接操作 plan.md 的每个
section（recommendation、change list、Self-Review、scope）。把它拆到 extended 里，
但它操作的对象在 core 里产出，造成跨 skill 的文档操作依赖。

**问题 4：已有的替代方案更简单**

当前 SKILL.md 已有内联复杂度门控：
- `SKILL.md:77`："Step 3b: Surface Scan **(required for Medium/Large changes)**"
- `SKILL.md:104`："For Trivial/Small changes, Level 1 alone is sufficient"

加一张复杂度裁剪表就能实现"按级跳过重型步骤"的效果，不需要物理拆分文件。

### 如果非要拆，最可行的三种方案

**方案 A：按功能拆（planning vs annotation）**

| | baton-plan | baton-plan-annotation |
|---|---|---|
| 内容 | Iron Law, Steps 1-5, Plan Structure, Todolist, Red Flags, Output Template | Annotation Protocol, Direction Change Rule, Annotation Log, Pre-Exit Checklist |
| 触发时机 | 用户说"plan/出 plan" | 用户在 plan.md 上写批注后 |
| 优点 | 时间线清晰：先出 plan，再进批注 | — |
| 缺点 | Direction Change Rule 操作 plan 主体，跨 skill 依赖 | — |

最自然的切分点，因为 planning 和 annotation 发生在不同时间段。
但 Direction Change Rule 的跨文档操作是硬耦合。

**方案 B：按复杂度拆（light vs full）**

| | baton-plan-light | baton-plan-full |
|---|---|---|
| 内容 | Iron Law, Steps 1-4 (L1 only), 简化 Self-Review, Todolist, Red Flags | 完整 Steps 1-5 含 L2/L3, Surface Scan, Annotation Protocol, Pre-Exit Checklist |
| 触发条件 | Trivial/Small | Medium/Large |
| 优点 | 轻任务体验好 | — |
| 缺点 | Iron Law/Red Flags/Template 重复；复杂度中途升级要换 skill | — |

审阅者原始建议的方向。核心问题：复杂度在过程中确定，不在过程前。

**方案 C：保持一个 skill + 内联裁剪表（当前推荐）**

| | baton-plan（现有 + 裁剪表） |
|---|---|
| 内容 | 全部内容，头部加 Complexity-Based Scope 表 |
| 触发条件 | 所有计划任务 |
| 优点 | 零协调成本，零重复，复杂度中途变更无摩擦 |
| 缺点 | 文件偏长（~300 行） |

### 拆分 vs 不拆对比

| 评估维度 | 拆分 | 不拆 + 裁剪表 |
|---|---|---|
| 协调复杂度 | 高（跨 skill 依赖、复杂度中途切换） | 无 |
| 规则重复 | Iron Law/Red Flags/Template 需要双写 | 无 |
| 轻量任务体验 | 好（只看 core/light） | 好（裁剪表跳过重步骤） |
| 复杂度升级 | 要换 skill 或追加 skill | 自然流转 |
| 维护成本 | 两个文件同步维护 | 一个文件 |

### 拆分结论

**拆分在技术上可行，但收益被协调成本抵消。**

核心原因是复杂度判定发生在规划过程中而非之前，拆分后必然面临"中途切换 skill"
或"提前猜测复杂度"的问题。相比之下，一个 skill + 头部裁剪表用最低成本实现了
相同效果。

如果未来必须拆，方案 A（planning vs annotation）最自然，因为它沿时间线切分
而非沿复杂度切分，避免了"中途判断复杂度再切换 skill"的问题。

---

## 建议实际改动

经两轮验证，只有两处值得动：

### 1. 加复杂度裁剪表（在 "When to Use" 后面）

```markdown
### Complexity-Based Scope

- **Trivial**: 3-5 line summary. Skip Surface Scan, skip Self-Review template.
- **Small**: Requirements + recommendation + L1 scan. Skip alternatives comparison.
- **Medium**: Full process through L2. Skip L3 unless cross-cutting.
- **Large**: Full process including L3 + disposition table + full annotation governance.

Complexity level is proposed by AI, confirmed by human (per workflow.md).
```

### 2. 软化 "all premises verified"（`SKILL.md:124-126`）

区分关键和非关键：

```markdown
- **Are critical premises verified?** Key assumptions (file locations, naming
  conventions, project structure, API behavior) must be directly verified in
  this session. Non-critical assumptions may be stated as working assumptions
  if explicitly marked: "Assumption: [statement] — not verified this session."
```

---

## Todo

- [x] ✅ 1. 在 `SKILL.md:33` 和 `## The Process` 之间插入 `### Complexity-Based Scope` 裁剪表 | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: 裁剪表位于 "When to Use" 之后、"The Process" 之前 | Deps: none
- [x] ✅ 2. 将 `SKILL.md:124-126` 的 "Are all premises verified?" 替换为 "Are critical premises verified?" + working assumption 机制 | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: 原有防幻觉意图保留，新增 assumption 标记语法 | Deps: none

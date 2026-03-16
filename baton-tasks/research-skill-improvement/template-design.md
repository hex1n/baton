# Template Design: baton-research 双模板

## Design Principles

从第一性原理推导，好的研究模板有三个特征：

1. **因果链** — 每个节的输出是下一个节的输入，跳过任何一节会导致后续节质量下降
2. **问题驱动** — 每个节用问题引导思考，不是空标题等着填
3. **质量可检验** — 每个节有明确的"达标"判据，reviewer 可快速判断

## 社区最佳实践参考

| 来源 | 关键结构特征 | 借鉴点 |
|------|-------------|--------|
| HumanLayer FIC | "ONLY describe what exists" 规则；git commit 锚定证据；~200 行产物 | 描述优先于判断；证据锚定到具体代码版本 |
| brilliantconsultingdev | 代码库 vs 云研究**用完全不同的模板**；"CLI Commands for Verification"；"No Open Questions in Final Plan" | 不同研究类型用不同模板已有先例；可验证的结论 |
| Cline Silent Investigation | 只读探索 → 讨论 → 计划 | 探索阶段不做判断 |
| Alexandrian ADR | 一句话摘要格式："In the context of [X] facing [Y] we decided for [Z] accepting [D]" | **强制清晰的压缩函数** — 如果写不出一句话摘要，说明理解不够 |
| Rust RFC | Unresolved Questions 分三级：blocks discussion / can wait for implementation / out of scope | **分级问题**比扁平列表更有用 |
| MADR | "Confirmation" 节：如何验证这个决策被正确执行？ | 结论应包含验证路径 |
| Google Design Doc | Non-Goals 作为一等公民 | 明确排除防范围蔓延 |

---

## Template A: 代码库研究

### 认知顺序

```
这是什么系统？→ 我要调查什么？→ 我怎么调查？→ 我发现了什么？→ 我可能错了吗？→ 结论是什么？
```

### 模板

```markdown
# Research: [topic]

## Frame

- **Question**: 正在调查什么？
- **Why**: 这支持什么后续决策？
- **Scope**: 边界在哪？
- **Out of scope**: 明确排除什么？
- **Constraints**: 已知约束（仓库、平台、工具链）

## Orient

- **System familiarity**: none / partial / deep
  - If none/partial: 必须先完成 System Baseline 再进入针对性调查
  - If deep: 用 3-5 句话陈述已知认知，直接进入 Investigation Targets
- **Strategy**: 基于熟悉度，我将如何组织调查？

## System Baseline

> 仅当 familiarity = none 或 partial 时必填。
> 每个答案必须引用证据 [CODE] file:line。
> 目标：让一个不了解这个系统的人读完后能画出系统的粗略架构图。

**1. 这个系统做什么？**
（目的、领域、用户、解决的核心问题）

**2. 怎么组织的？**
（顶层目录结构、主要模块/层、模块间的职责边界）

**3. 关键抽象是什么？**
（系统依赖的核心类型/接口/概念，其他一切围绕它们构建）

**4. 数据怎么流动的？**
（主路径：输入 → 处理 → 输出。画出至少一条典型请求的生命周期）

**5. 遵循什么约定？**
（命名、错误处理、测试模式、配置模式。只记录实际观察到的，不猜测）

**达标判据**: 读完 System Baseline 后，读者能回答"如果我要改 X，最可能影响的模块是哪些？"

## Investigation Methods

使用了哪些证据获取方法？每种返回了什么？为什么足够？
（要求 ≥2 种独立方法，independence level ≥ moderate）

## Investigation

按 investigation move 组织。每个 move 记录：

### [Move N]: [名称]
- **Question**: 这个 move 解决什么不确定性？
- **What was checked**: 具体查了什么（文件、命令、路径）
- **What was found**: 发现了什么（附证据标签 + 状态）
- **What remains unresolved**: 还有什么没解决？
- **Next**: continue / switch direction / stop

当调查方向发生实质性变化时，记录：
- Previous uncertainty →
- New uncertainty →
- Why the switch →

## Cross-Move Synthesis

> 仅当使用了多个 investigation move 时需要。

- 各 move 发现之间哪里相互印证？
- 哪里存在张力？
- 什么还没解决？

## Counterexample Sweep

- **Leading interpretation**: 当前最可能的结论是什么？
- **Disproving evidence sought**: 什么证据能推翻它？
- **What was checked**: 具体搜索/验证了什么？
- **Result**: 找到反证 / 没找到 / 搜索不充分
- **Effect on confidence**: 对结论信心的影响

## Self-Challenge

> @investigation-infrastructure.md Section 2

## Review

> @investigation-infrastructure.md Section 3

## One-Sentence Summary

> 借鉴 Alexandrian ADR。如果写不出一句话，说明理解不够清晰。

"In the context of [question], investigating [scope], I found [key finding],
with [confidence level] confidence, accepting [key uncertainty]."

## Final Conclusions

每条结论必须包含：
- **Confidence**: high / medium / low + 一句话理由
- **Evidence**: 引用支持证据
- **Verification path**: 如何验证这个结论？（什么测试、什么命令、什么观察能确认或推翻它）
- **Uncertainty**: 什么还未验证
- **Plan implication**: actionable / watchlist / judgment-needed / blocked

## Questions for Human Judgment

> 借鉴 Rust RFC 三级分类，比扁平列表更有用。

**Blocks plan** — 必须在进入 plan 阶段前回答：

**Can wait for implementation** — plan 可以先做，实施时再决定：

**Out of scope but related** — 记录但不阻塞：

## 批注区

> @investigation-infrastructure.md Section 4
```

### 因果链验证

```
Frame (定义问题)
  ↓ feeds
Orient (评估起点 → 选择策略)
  ↓ feeds
System Baseline (建立全局认知，Orient 决定是否需要)
  ↓ feeds
Investigation Methods (选择证据获取方法)
  ↓ feeds
Investigation (执行调查，System Baseline 提供导航上下文)
  ↓ feeds
Cross-Move Synthesis (综合多条调查线)
  ↓ feeds
Counterexample Sweep (主动挑战结论)
  ↓ feeds
Self-Challenge + Review (自检 + 审查)
  ↓ feeds
Final Conclusions (收敛)
```

跳过 System Baseline → Investigation 缺乏导航上下文 → 陷入细节。这正是之前的失败模式。

---

## Template B: 外部研究

### 认知顺序

```
我要找什么？→ 可信信息在哪？→ 哪些源值得深入？→ 每个源说了什么？→ 它适用于我的场景吗？→ 结论是什么？
```

### 模板

```markdown
# Research: [topic]

## Frame

- **Question**: 正在调查什么？
- **Why**: 这支持什么后续决策？
- **Scope**: 边界在哪？
- **Out of scope**: 明确排除什么？
- **Target context**: 我们的具体约束（版本、平台、使用场景）— 用于后续适用性评估

## Orient

- **Domain familiarity**: none / partial / deep
  - If none/partial: 先建立 Source Landscape 再开始阅读任何源
  - If deep: 陈述已知认知 + 已知权威源，直接进入针对性调查
- **Strategy**: 基于熟悉度，我将如何组织调查？

## Source Landscape

> 必填。在阅读任何源之前，先映射可用的信息源。
> 目标：让读者知道这个领域有哪些权威信息源、我们选择了哪些、为什么。

**1. 什么是这个领域的权威源？**
列出所有已知的权威源及其类型：

| Source | Type | URL/Location | Currency | Why authoritative |
|--------|------|-------------|----------|-------------------|
| ... | official docs / source code / spec / peer-reviewed / community | ... | date/version | ... |

**2. 覆盖度评估**
- 我们的问题被权威源充分覆盖了吗？
- 哪些方面缺乏权威源，需要依赖次级源？
- 有哪些已知的信息空白？

**3. Source selection**
我将深入阅读哪些源？为什么选择这些？
（选择标准：与问题的相关性、权威性、时效性。depth > breadth）

**达标判据**: 读者能判断"如果这个研究遗漏了重要信息，最可能是因为什么源没被覆盖？"

## Investigation Methods

使用了哪些证据获取方法？每种返回了什么？为什么足够？
（要求 ≥2 种独立方法，independence level ≥ moderate）

## Source Evaluations

> 每个实际使用的源必须评估。

### [Source N]: [name]
- **Type**: primary (official docs, source code, spec) / secondary (blog, tutorial, summary)
- **Currency**: 发布/更新日期，是否匹配目标版本
- **Key claims**: 这个源的核心主张是什么？
- **Verification**: 能否用更强证据验证这些主张？（验证了→标 ✅，没验证→标 ❓）
- **Applicability**: 是否适用于我们的 Target context？有什么限制条件？
- **Trust level**: high / medium / low + 理由

## Investigation

按主题/维度组织（不是按源组织）。每个主题：

### [Topic N]: [name]
- **Question**: 这个主题要回答什么？
- **Findings**: 综合多个源的发现（标注每条 finding 的来源）
- **Primary source support**: 至少一个一手源支持？✅ / ❓
- **Cross-source consistency**: 多个源是否一致？不一致→显式记录冲突
- **Applicability to our context**: 这些 findings 在我们的场景下成立吗？

## Cross-Source Synthesis

> 仅当使用了多个源时需要。

- 各源之间哪里一致？
- 哪里存在矛盾？（具体到哪个源说了什么）
- 矛盾如何解决？（更强证据胜出，还是未解决？）

## Counterexample Sweep

- **Leading interpretation**: 当前最可能的结论是什么？
- **Disproving evidence sought**: 什么证据能推翻它？
- **What was checked**: 具体搜索了什么？（是否搜索了反面观点？）
- **Result**: 找到反证 / 没找到 / 搜索不充分
- **Effect on confidence**: 对结论信心的影响

## Self-Challenge

> @investigation-infrastructure.md Section 2

## Review

> @investigation-infrastructure.md Section 3

## One-Sentence Summary

> 借鉴 Alexandrian ADR。如果写不出一句话，说明理解不够清晰。

"In the context of [question], investigating [scope], I found [key finding],
with [confidence level] confidence, accepting [key uncertainty]."

## Final Conclusions

每条结论必须包含：
- **Confidence**: high / medium / low + 一句话理由
- **Primary source**: 至少一个一手源引用（没有→标 ❓ + 说明）
- **Applicability**: 在 Target context 下的适用性评估
- **Verification path**: 如何验证这个结论？（什么实验、什么 API 调用、什么对比能确认或推翻它）
- **Uncertainty**: 什么还未验证
- **Plan implication**: actionable / watchlist / judgment-needed / blocked

## Questions for Human Judgment

> 借鉴 Rust RFC 三级分类，比扁平列表更有用。

**Blocks plan** — 必须在进入 plan 阶段前回答：

**Can wait for implementation** — plan 可以先做，实施时再决定：

**Out of scope but related** — 记录但不阻塞：

## 批注区

> @investigation-infrastructure.md Section 4
```

### 因果链验证

```
Frame (定义问题 + Target context)
  ↓ feeds
Orient (评估领域熟悉度 → 选择策略)
  ↓ feeds
Source Landscape (映射可用信源，选择深入阅读的源)
  ↓ feeds
Investigation Methods (确定证据获取方法)
  ↓ feeds
Source Evaluations (评估每个源的可信度 + 适用性)
  ↓ feeds
Investigation (按主题综合发现，每条 finding 标注来源 + 一手源)
  ↓ feeds
Cross-Source Synthesis (综合多源，标注一致性和矛盾)
  ↓ feeds
Counterexample Sweep (主动挑战结论)
  ↓ feeds
Self-Challenge + Review (自检 + 审查)
  ↓ feeds
Final Conclusions (收敛，每条需要一手源)
```

跳过 Source Landscape → 直接读 → 容易读到次级源就当结论 → 外部研究质量低。
跳过 Source Evaluations → 不知道源的可信度 → 把 blog 当权威引用。

---

## Template C: 混合研究

当一个研究任务同时涉及代码库和外部调查时：

1. Orient 步骤判断**主要类型**（codebase-primary 或 external-primary）
2. 选择主类型的模板
3. 加一个补充节：
   - 如果主类型是代码库，加 `## External Sources` 节（简化版 Source Landscape + Source Evaluations）
   - 如果主类型是外部，加 `## Codebase Context` 节（简化版 System Baseline）
4. Final Conclusions 中两种类型的 findings 都需要满足各自的证据标准

---

## 两个模板的关键差异对比

| 维度 | 代码库模板 | 外部模板 |
|------|-----------|---------|
| 核心强制节 | System Baseline | Source Landscape + Source Evaluations |
| Investigation 组织方式 | 按 investigation move | 按主题/维度 |
| 综合节名称 | Cross-Move Synthesis | Cross-Source Synthesis |
| 结论证据要求 | [CODE] file:line 引用 | ≥1 一手源引用 |
| 达标判据焦点 | "能判断改 X 影响哪些模块" | "能判断遗漏了哪些源" |
| Frame 特有字段 | — | Target context（版本/平台/场景） |

## 共享节（两个模板相同）

- Frame（基础字段相同，外部模板多 Target context）
- Orient（评估内容不同，但格式相同）
- Investigation Methods
- Counterexample Sweep
- Self-Challenge（引用 infrastructure）
- Review（引用 infrastructure）
- One-Sentence Summary（借鉴 Alexandrian ADR，强制清晰压缩）
- Questions for Human Judgment（借鉴 Rust RFC 三级分类）
- 批注区（引用 infrastructure）

## 社区研究整合说明

从社区研究中采纳了 3 项改进，均基于成熟实践：

1. **One-Sentence Summary**（Alexandrian ADR）— 加在 Final Conclusions 前。"If you can't say it in one sentence, you don't understand it well enough." 作为结论质量的压缩测试。

2. **三级 Questions for Human Judgment**（Rust RFC）— blocks plan / can wait / out of scope。比扁平列表更有用，因为它明确了每个问题对后续阶段的阻塞程度。

3. **Verification path**（MADR Confirmation）— 每条结论加"如何验证"。防止不可证伪的结论进入 plan 阶段。代码库研究用命令/测试验证，外部研究用实验/API 调用验证。

未采纳：
- HumanLayer 的 git commit 锚定 — 有价值，但 baton 的 [CODE] file:line 证据模型已经覆盖，增量收益不大
- obra/superpowers 的 knowledge lineage tracing — 这是一个独立的方法论，不是模板特性，可以作为 investigation move 在未来迭代中加入

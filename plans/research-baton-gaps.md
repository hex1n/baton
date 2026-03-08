# Baton 缺口分析：从复盘到改进

## 参考文档

- `retrospective-2026-03-08.md`：复盘记录
- `research-plan-review.md`：GPT-5.4 对旧 plan 的审查报告
- `research.md`：第一性原理分析

## 工具清单

本研究使用：Grep、Glob、Read、subagent（Explore）。无需外部文档。

---

## 1. 缺口一览

从复盘中提取出 5 个独立可验证的缺口，每个缺口都有代码证据和失败实例。

| # | 缺口 | 复盘中的失败实例 | 当前防线 |
|---|------|-----------------|---------|
| G1 | Plan 内部一致性无检查 | 推荐切到 D，变更清单仍是 B | ❌ 无 |
| G2 | Research→Plan 追溯无强制 | 删掉 research 定义的质量评估，无反证 | ❌ 无 |
| G3 | Self-Review 不区分"风险"和"矛盾" | 把内部矛盾当"已知风险"放过 | ⚠️ 有模板但无分类 |
| G4 | 批注方向变更后无收敛步骤 | 改了推荐但没通读全文 | ⚠️ 有"更新正文"指令但无"通读"要求 |
| G5 | Todo 生成无前置一致性校验 | 在冲突版本上生成了 12 条 todo | ❌ 无 |

---

## 2. 逐项深入分析

### G1：Plan 内部一致性无检查

**失败路径**
```
批注 [Q] "还有更好的方案吗"
  → AI 新增方案 D 分析，更新推荐段
  → AI 写 Annotation Log
  → AI 更新 Self-Review
  → ❌ AI 没有更新变更清单（方案 B 的变更 4 仍在）
  → 结果：推荐 = D，变更清单 = B，Todo = D — 三处互相矛盾
```

**现有防线**
- `baton-plan/SKILL.md:167-168`："When an annotation is accepted: (1) update the document body, (2) record in Annotation Log" — 规定了要更新正文，但没有定义"正文的哪些部分需要联动更新"
- `post-write-tracker.sh` — 只在 IMPLEMENT 阶段检查文件是否在 plan 里提到，不检查 plan 本身的内容一致性
- `test-workflow-consistency.sh` — 检查 hook 算法一致性和 skill 关键词，**不检查 plan.md 内容**

**根本性追问：自动化检查是最佳方案吗？**

需要区分两类问题：

| 类型 | 例子 | Shell 脚本能检测吗？ |
|------|------|-------------------|
| **结构缺失** | plan.md 没有 Self-Review、没有批注区、research.md 没有 file:line 引用 | ✅ 能（grep 关键字） |
| **语义矛盾** | 推荐段说方案 D，变更清单描述的是方案 B | ❌ 不能（需要理解内容） |

复盘中的实际失败是**语义矛盾**。`doc-quality.sh`（plan.md 变更 4）只能做结构检查，无法捕获这次真正的错误。

**但这不意味着结构检查没用。** 结构检查能捕获的是另一类问题：AI 忘了写 Self-Review、忘了加批注区。这些在复盘中没出现，但在其他场景中可能出现。结构检查的价值是"兜底"，不是"解决本次问题"。

**真正能防御语义矛盾的是什么？**

1. **流程纪律**：方向性修改后强制通读全文（→ G4 的解法）
2. **人类审阅**：这次实际上就是 GPT-5.4 + 你自己发现的
3. **AI 自检提示**：在 skill 中加一个明确的 pre-exit check，要求 AI 自问"推荐段和变更清单是否指向同一个方案"

**结论：改进方案应该是多层的**

- **Layer 1（结构检查）**：`doc-quality.sh` 做为兜底，检查结构性缺失 → 低成本，低噪声，值得做
- **Layer 2（认知引导）**：在 baton-plan skill 中加明确的一致性自检步骤 → 直接对抗本次失败
- **Layer 3（人类审阅）**：不需要改，已经在工作

**Layer 1 是当前最佳方案吗？**
是的，作为兜底层。但它不能单独解决问题 — 必须配合 Layer 2。当前 plan.md 的方案 C 同时包含 doc-quality.sh（Layer 1）和 skills 强化（Layer 2），这个组合是正确的。

---

### G2：Research→Plan 追溯无强制

**失败路径**
```
research.md:456-459,517-520 定义方向 D = 认知缰绳 + 质量评估
  → plan 中 AI 判定 doc-quality.sh 是 "gate 思维"
  → AI 删除质量评估，只保留 skills 强化
  → ❌ 没有补出新的研究证据来支持这个收缩
  → 结果：plan 的方案 D 与 research 的方向 D 定义不匹配
```

**现有防线**
- `baton-plan/SKILL.md:36-40`："Plans MUST derive approaches from research findings — don't jump to 'how' without tracing back to 'why'" — 有要求但没有检查机制
- `phase-guide.sh:77-81`：用 research.md 的存在来判断阶段，但不检查 plan 是否引用了 research
- `test-workflow-consistency.sh`：不检查 plan→research 追溯

**根本性追问：追溯可以被自动化检查吗？**

可以做的结构检查：
- plan.md 是否包含 `research.md:` 或 `research-*.md:` 字样（证明至少引用了 research）
- plan.md 的方案分析是否引用了 file:line 格式的证据

不能做的：
- plan 引用的 research 结论是否被正确理解
- plan 是否遗漏了 research 中的关键发现
- plan 中删掉 research 内容时是否有合理理由

**这个缺口的真正性质是什么？**

这是一个**推理错误**，不是结构错误。AI 在批注循环中形成了新观点（"doc-quality.sh 是 gate 思维"），这个观点本身有一定道理，但 AI 用它来否定 research 的结论时没有走正规流程 — 应该先回 research 补充新的分析，再在 plan 中引用。

**最佳方案：流程指导 > 自动检查**

在 baton-plan skill 的批注协议中加一条规则：

> **当批注导致 plan 删除或缩减 research 中已定义的内容时：必须先在 research.md 中补出支持删除的新证据，再更新 plan。不能在 plan 中单方面否定 research 结论。**

这条规则比自动检查更有效，因为：
1. 自动检查只能验证"plan 引用了 research"，不能验证"引用是否正确"
2. 流程规则直接针对失败模式：AI 在批注中形成新观点 → 强制要求回到 research 补证据 → 确保追溯链不断

**结论：不需要新的 hook 或测试，需要在 skill 中加一条明确的规则。** `doc-quality.sh` 可以附带检查"plan 中是否存在 research 引用"作为低成本结构兜底，但核心防御是认知引导。

---

### G3：Self-Review 不区分"风险"和"矛盾"

**失败路径**
```
AI 写 Self-Review：
  "被排除的替代方案：skills-only 很诱人，但它切掉了 research 已明确提出的质量评估层"
  → AI 把这当作 "已识别风险" 记录下来
  → ❌ 没有意识到这描述的是文档的内部矛盾，不是外部不确定性
  → 结果：Self-Review 变成了心理安全阀 — 承认问题但不修复
```

**现有防线**
- `baton-plan/SKILL.md:71-78`：Self-Review 模板要求写"biggest risk"、"what could make plan wrong"、"rejected alternative" — 但这三项都指向外部不确定性，没有一项专门要求检查内部一致性
- `baton-research/SKILL.md:103-112`：类似模板，同样没有区分内部/外部

**根本性追问：Self-Review 的设计假设是什么？它对吗？**

当前假设：Self-Review 是让 AI 暴露不确定性给人类审阅的工具。

这个假设本身没错，但它遗漏了一个关键场景：**Self-Review 发现的不是"不确定性"而是"确定的错误"**。

在复盘中，AI 在 Self-Review 里写的内容实际上描述了一个可证实的内部矛盾（plan 的推荐与 research 的定义不匹配）。但因为 Self-Review 模板把所有发现都归类为"风险"，AI 把一个应该立即修复的问题当成了可以留给人类判断的不确定性。

**最佳方案：区分"风险"和"矛盾"**

在 Self-Review 模板中增加一步：

```markdown
## Self-Review
- 本文档中是否存在内部矛盾？（推荐段 vs 变更清单 vs Todo 是否指向同一方案？如果存在矛盾，这不是风险，是 bug — 修复后再呈现）
- The biggest external risk in this plan that you're least confident about
- What could make this plan completely wrong
- One alternative approach you considered but rejected, and why
```

关键改变：**把"内部矛盾检查"从"风险识别"中独立出来，并明确要求：如果发现矛盾，必须修复后再呈现给人类，而不是作为"风险"记录。**

**这比加 hook 更有效吗？**

是的。hook 不能理解语义矛盾；Self-Review 是 AI 在呈现文档前的最后一道自检。改进 Self-Review 模板直接针对失败点：AI 有能力发现矛盾（它确实发现了），但没有把发现升级为行动。修改模板让"矛盾 = 必须修复"变成显式规则。

---

### G4：批注方向变更后无收敛步骤

**失败路径**
```
批注 [Q] 触发方向变更（B → D）
  → AI 更新推荐段 ✅
  → AI 更新 Self-Review ✅
  → AI 写 Annotation Log ✅
  → ❌ AI 没有通读全文检查一致性
  → 变更清单仍保留方案 B 的内容
```

**现有防线**
- `baton-plan/SKILL.md:167-168`："When an annotation is accepted: (1) update the document body, (2) record in Annotation Log" — **这是当前最接近的规则，但它只说"更新正文"，没有说"通读全文确认所有段落一致"**
- `workflow-full.md:262-267`：描述了批注流程的完整循环，但没有"方向变更后的收敛检查"步骤

**根本性追问：需要的是"新步骤"还是"强化现有步骤"？**

观察现有批注协议的流程（workflow-full.md:259-267）：

```
1. AI 产出文档
2. 人类批注
3. AI 找到所有新批注
4. AI 响应每条批注：正确→采纳→更新正文+记录 / 有问题→解释→让人类决定
5. 记录到 Annotation Log
6. 人类审阅 AI 回应，可能追加批注 → 回到步骤 3
7. 人类满意 → BATON:GO
```

缺失的是步骤 4 和 5 之间的一个条件分支：

```
4b. 如果本轮批注导致了方向性变更（推荐方案改变、核心策略调整），
    在记录 Annotation Log 后，必须重新通读文档全文，
    逐段确认：推荐段、变更清单、Self-Review、范围外 是否全部对齐。
```

**为什么"强化现有步骤"不够？**

现有的"(1) update the document body"理论上已经涵盖了"更新所有受影响的段落"。问题是这条规则太隐含了 — 它没有区分"小修改"和"方向变更"。小修改（比如改一个文件名）确实只需要更新提到这个文件名的地方；但方向变更（比如从方案 B 切到 D）需要检查文档中**所有引用方案的地方**，这个范围远大于小修改。

**最佳方案：在批注协议中明确区分"局部修改"和"方向变更"**

在 baton-plan skill 的批注协议中加：

> **方向变更规则**：当批注导致推荐方案改变时，这不是普通的局部修改。必须：
> 1. 更新推荐段
> 2. 重写或删除变更清单中与旧方案相关的内容
> 3. 更新 Self-Review
> 4. 通读全文确认无残留的旧方案引用
> 5. 记录 Annotation Log

这比 hook 更有效，因为方向变更是语义事件，shell 脚本无法检测"推荐是否改变了"。

---

### G5：Todo 生成无前置一致性校验

**失败路径**
```
人类说 "根据方案D生成todo"
  → AI 直接按 D 的理解生成 12 条 todo
  → ❌ 没有检查 plan 正文是否一致
  → 变更清单还是方案 B 的内容
  → 结果：todo 与 plan 正文脱节
```

**现有防线**
- `baton-plan/SKILL.md:99-101`："After the human says 'generate todolist' and BATON:GO is present" — 前置条件只有 BATON:GO，无一致性校验
- `baton-implement/SKILL.md:11-20`：Iron Law 要求 BATON:GO，但同样不检查一致性

**根本性追问：Todo 生成应该有自己的前置检查，还是应该依赖前面阶段保证一致性？**

两种设计哲学：

| 哲学 | 优点 | 缺点 |
|------|------|------|
| **上游保证**：批注阶段保证一致性，Todo 生成信任 plan | 简单，职责清晰 | 如果上游失败，错误传播到 todo |
| **逐层校验**：每个阶段做自己的校验 | 冗余防御，任何一层都能挡住 | 检查逻辑重复，可能产生噪声 |

复盘证明了"上游保证"在本次失败了。但根因是 G4（批注后没有收敛步骤），不是 Todo 生成本身的问题。

**如果 G4 被修复，G5 还需要吗？**

理论上不需要 — 如果方向变更后一定会通读全文对齐，那 plan 在进入 Todo 生成时应该已经一致了。

但实际上，G4 是认知引导，AI 有可能跳过。所以 G5 作为**第二道防线**仍有价值。

**最佳方案：轻量级 pre-todo 自检**

在 baton-plan/SKILL.md 的 Todolist Format 段前加：

> **生成 Todo 前，先做一致性检查**：
> 1. 重新阅读推荐段 — 确认推荐的是哪个方案
> 2. 重新阅读变更清单 — 确认所有变更项属于同一个方案
> 3. 重新阅读 Self-Review — 确认没有未解决的内部矛盾
> 4. 三处一致后再生成 Todo

这是纯认知引导，零代码成本，零维护成本。不需要 hook — 因为 Todo 是在 plan.md 里生成的，而 plan.md 是 markdown，所有 hook 都会跳过它。

---

## 3. 改进方案汇总

### 改进矩阵

| # | 缺口 | 改进层 | 具体动作 | 涉及文件 |
|---|------|-------|---------|---------|
| G1 | Plan 内部一致性 | 结构兜底 + 认知引导 | doc-quality.sh 检查结构缺失；skill 加一致性自检步骤 | `.baton/hooks/doc-quality.sh`, `.claude/skills/baton-plan/SKILL.md` |
| G2 | Research→Plan 追溯 | 认知引导 | 在批注协议中加"删除 research 内容时必须先补反证"规则 | `.claude/skills/baton-plan/SKILL.md` |
| G3 | Self-Review 分类 | 认知引导 | 区分"内部矛盾"（必须修复）和"外部风险"（呈现给人类） | `.claude/skills/baton-plan/SKILL.md`, `.claude/skills/baton-research/SKILL.md` |
| G4 | 批注后收敛 | 认知引导 | 批注协议加"方向变更 → 通读全文"规则 | `.claude/skills/baton-plan/SKILL.md`, `.baton/workflow-full.md` |
| G5 | Pre-todo 校验 | 认知引导 | Todo 生成前加三步一致性确认 | `.claude/skills/baton-plan/SKILL.md` |

### 机制分层

```
Layer 3: 人类审阅（已存在，已被证明有效）
  ↑ 不需要改
Layer 2: 认知引导（G2 G3 G4 G5 — 改进 skill 和 workflow）
  ↑ 本次重点
Layer 1: 结构兜底（G1 — doc-quality.sh + 现有 hooks）
  ↑ plan.md 变更 4 已覆盖
```

### 与现有 plan.md 的关系

当前 plan.md（方案 C）的 5 项变更中：

- **变更 1-3**（技术债清理）：与本研究无关，独立正确
- **变更 4**（doc-quality.sh）：覆盖了 G1 的 Layer 1（结构兜底），但**没有覆盖 G2-G5 的认知引导改进**
- **变更 5**（skills 强化）：当前描述为"加退出前自检"，但**没有具体定义自检内容**。本研究给出了具体内容：
  - G1 → 一致性自检（推荐段 vs 变更清单 vs Self-Review）
  - G2 → 删除 research 内容时的反证规则
  - G3 → Self-Review 模板区分矛盾和风险
  - G4 → 方向变更后的通读规则
  - G5 → Pre-todo 三步确认

**建议**：不需要新增变更项，但变更 5 的"退出前自检"应该被细化为上述 5 条具体规则，而不是留给实现者自行决定。

---

## 4. 根本性反思：Baton 的防御模型

### 当前防御模型

```
write-lock.sh（唯一硬门控）
  ↓ 只管"有没有 BATON:GO"
phase-guide.sh（状态机引导）
  ↓ 只管"现在是什么阶段"
skills（认知缰绳）
  ↓ 引导 AI 怎么做，但不验证做得对不对
人类审阅（最终防线）
  ↓ 能发现一切，但成本最高
```

### 这次失败暴露的缝隙

write-lock.sh 正确放行了 plan.md 的修改（markdown 豁免），phase-guide.sh 正确检测到了 ANNOTATION 阶段，skills 要求了"更新正文 + 记录 Annotation Log"。但：

- write-lock 不检查 plan 内容质量
- phase-guide 不检查 plan 内部一致性
- skills 的指令被 AI 部分执行了（更新了推荐段、Self-Review、Annotation Log）但不完整（没更新变更清单）
- 最终人类审阅确实发现了问题（GPT-5.4 review + 你的重写）

**缝隙的位置**：在"skills 指令"和"人类审阅"之间。AI 有时会"部分执行"认知引导 — 做了容易的部分，漏了困难的部分。

### 最根本的追问：这个缝隙能被消除吗？

**不能完全消除。** 语义一致性是 AI 级别的判断任务，不能被降级为 shell 脚本。只要 AI 有可能犯推理错误，这个缝隙就会存在。

**但可以缩小。** 方法是把"困难的部分"变成"显式的步骤"：
- 不是"更新正文"（太隐含，AI 可能只更新容易想到的段落）
- 而是"逐段检查：推荐段、变更清单、Self-Review、范围外 — 是否全部指向同一方案"（显式枚举，更难遗漏）

这就是 G3/G4/G5 改进的核心思路：**把隐含的认知要求变成显式的清单项**。

---

## Self-Review

1. **批评者最可能挑战的点**：所有 G2-G5 改进都是认知引导（改 skill 文档），而复盘的结论正是"认知引导被 AI 部分跳过了"。凭什么改了 skill 文档 AI 就不会再跳过？
   - 回应：关键差异是从"隐含的通用指令"变成"显式的枚举清单"。AI 更容易跳过"更新正文"这种抽象指令，但更难跳过"检查推荐段、检查变更清单、检查 Self-Review"这种具体清单。不能保证 100% 遵守，但能显著提高遵守率。

2. **最弱的结论**：G2（追溯无强制）的改进方案。我提出"在 skill 中加规则"，但这条规则触发条件是"AI 意识到自己在删除 research 内容" — 而这次失败恰恰是 AI 没有意识到自己在做这件事。更好的方案可能是：在方向变更后的通读步骤（G4）中**显式要求 AI 对比 research 中的相关段落**。

3. **进一步调查可能改变什么**：如果研究更多 AI 在长上下文中的行为模式，可能发现：认知引导在上下文窗口前 50% 效力远高于后 50%。如果是这样，把关键规则放在 skill 的开头（Iron Law 部分）比放在中间（Annotation Protocol 部分）更有效。

---

## Supplement A：规则放置位置与 AI 遵守率

### 调查来源

- Stanford "Lost in the Middle" 研究（MIT TACL 2024）
- Anthropic 官方 Claude Code 文档（code.claude.com/docs/en/skills, platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices）
- superpowers 框架实现（github.com/obra/superpowers）
- 本项目 baton skills 的实际结构

### 核心发现

**1. 位置偏差确实存在**

Stanford 研究发现 LLM 注意力呈 U 形分布：开头和结尾的信息被遵循的概率高于中间。Claude 在 key-value retrieval 任务上表现接近完美，但在复杂指令遵循中仍表现出位置偏差。

Anthropic 官方文档佐证：
> "LLMs bias towards instructions that are on the peripheries of the prompt: at the very beginning (the Claude Code system message and CLAUDE.md), and at the very end (the most-recent user messages)."

**指令上限**：Claude Code 系统提示约含 50 条指令，AI 能以合理一致性遵循约 150-200 条指令。超过此阈值，遵守率下降。

**2. Baton skills 已经在利用位置偏差**

三个 baton skill 都把 Iron Law 放在 frontmatter 之后的第一位置（SKILL.md:12-18），这是正确的。但批注协议（Annotation Protocol）在文档中间偏后（baton-plan/SKILL.md:141-168），而 G4（方向变更规则）正是要加在批注协议里 — 这是遵守率最低的位置。

**3. 格式对遵守率的影响可能大于位置**

superpowers 框架的实践发现：
- **Code block** 格式的 Iron Law 比散文段落的规则遵守率更高
- **Table 格式** 的 Red Flags 比列表格式更容易被识别
- **Description 字段** 如果包含流程摘要，AI 可能只读 description 而跳过 SKILL.md 正文（superpowers/skills/writing-skills/SKILL.md 的实测结论）

**4. 重复是有效的强化手段**

Baton skills 中，关键规则出现在两个位置：
- Iron Law（开头，绝对约束）
- Red Flags 表格（中间，作为"不应该出现的想法"）

例如"不要在 research 阶段写代码"既出现在 baton-research Iron Law（SKILL.md:14-15），也出现在 Red Flags 表格（SKILL.md:144："Let me just fix this while I'm here"）。

### 对 G2-G5 规则放置的推荐

| 规则 | 推荐放置位置 | 理由 |
|------|-------------|------|
| G3 内部矛盾检查 | **Iron Law 区（开头）** | 这是最关键的规则 — "Self-Review 中的矛盾不是风险，是 bug"。放在 Iron Law 可以利用开头位置偏差。 |
| G4 方向变更 → 通读全文 | **Annotation Protocol + Red Flags 双重放置** | 放在 Annotation Protocol 是逻辑位置（批注处理流程中），但因为位于中间偏后，需要在 Red Flags 表格中重复："Let me just update the recommendation section" → "方向变更影响全文。通读全文确认一致性。" |
| G5 Pre-todo 一致性检查 | **Todolist Format 段之前** | 逻辑位置正确（生成 todo 的前置步骤），且紧接在 BATON:GO 检查之后，执行顺序自然。 |
| G2 Research 追溯 | **合并到 G4 的方向变更规则中** | 独立规则触发条件太隐含（"AI 意识到自己在删除 research 内容"）。合并到 G4 更可靠：方向变更通读时，显式要求对比 research 原文。 |

### 推荐的 Iron Law 修订

当前 baton-plan Iron Law：
```
NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
NO BATON:GO PLACED BY AI — ONLY THE HUMAN PLACES IT
NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
```

建议增加第四条：
```
NO INTERNAL CONTRADICTIONS LEFT UNRESOLVED — FIX BEFORE PRESENTING
```

这条规则直接对抗 G3 的失败模式（Self-Review 发现矛盾但不修复），并利用 Iron Law 的开头位置获得最高遵守率。

---

## Supplement B：认知引导 vs 自动检查的最佳比例

### 回应人类判断问题 1："最佳的推荐方案是什么"

**推荐比例：认知引导 80% + 结构兜底 20%。**

理由：

| 方案 | 能捕获的错误类型 | 维护成本 | 跨 IDE 兼容性 |
|------|-----------------|---------|-------------|
| 自动检查（doc-quality.sh） | 结构缺失（无 Self-Review、无批注区） | 中（shell 脚本 + 测试） | 需要 adapter |
| 认知引导（skill 改进） | 语义矛盾、方向不一致、追溯断链 | 低（纯 markdown） | 天然跨 IDE |
| 智能一致性检查器（假设） | 语义矛盾 | 高（需要 AI 调用 AI，或复杂 NLP） | 复杂 |

"智能 plan 一致性检查器"理论上最强大，但实现成本极高 — 要么用 AI 检查 AI（引入延迟和 API 成本），要么写复杂的文本分析（在 POSIX sh 里不现实）。这条路线的 ROI 在当前阶段不合理。

**实际推荐的分配**：

1. `doc-quality.sh`（plan.md 变更 4）：已在计划中，做结构兜底 → **保留，不扩大范围**
2. skill 改进（plan.md 变更 5）：细化为 G1-G5 的 5 条具体规则 → **这是主要投入**
3. 暂不做智能一致性检查器 → **未来如果 skill 改进仍不够，再考虑**

### 回应人类判断问题 2：外部 review

人类说："我偶然使用，但如果每次都需要外部 review，侧面说明 baton 不够健全。"

**这个判断完全正确。** 外部 review 是一个有效但昂贵的防线。baton 的目标应该是让内部机制（skills + hooks + 人类批注）足够健全，使外部 review 变成"可选的额外保障"而不是"必要的补救"。

本研究提出的 G1-G5 改进正是朝这个方向走的：如果 G3（Self-Review 区分矛盾和风险）和 G4（方向变更后通读全文）被正确执行，AI 应该能在呈现文档前自己发现并修复内部矛盾，不再需要外部 review 来捕获。

---

## Supplement C：批注类型与方向变更（回应 [Q] 批注）

### 问题

> 因为是人类在计划中提出的批注改变了原有方向，应该怎么做最好呢？是应该暂停 plan 重新回到 research 阶段研究呢还是什么？那这样 plan 中的批注的类型是不是有点问题呢？因为人类可能是批注的 Q 提问，但是这个问题可能会导致改变之前研究的方向。

### 这是一个真实的协议缺口

逐层分析：

**当前的批注类型系统**

| 类型 | 定义 | 触发的动作 |
|------|------|-----------|
| `[Q]` | 提问 | 回答，附 file:line 证据 |
| `[CHANGE]` | 请求修改 | 验证安全性，修改或提出替代 |
| `[NOTE]` | 补充上下文 | 纳入，解释影响 |
| `[DEEPER]` | 不够深 | 深入调查同一方向 |
| `[MISSING]` | 遗漏 | 补充 |
| `[RESEARCH-GAP]` | 需要更多研究 | **暂停当前文档，回 research 补充** |

**问题在哪？**

`[Q]` 的定义是"提问 → 回答"。但实际上，一个 [Q] 的**回答**可能导致方向变更。例如：

```
[Q] "还有更好的方案吗？"
→ AI 回答：是的，方案 D 更符合 harness 哲学
→ 结果：推荐方案从 B 变成 D（方向变更）
```

在这个流程中，`[Q]` 本身是正确的标注 — 人类确实是在提问。问题不在于标注类型错了，而在于 **AI 的响应协议没有区分"回答后方向不变"和"回答后方向改变"这两种情况**。

**更深一层：人类的 [Q] 暗含了方向挑战吗？**

回看实际的批注："还有更好的方案吗？" — 这不只是提问，它隐含了对当前方案的不满足。但人类选择了 `[Q]` 而不是 `[CHANGE]`，这可能是因为：

1. 人类不确定是否有更好的方案（所以是问，不是改）
2. 人类想让 AI 自己发现，而不是直接指定方向
3. 当前批注类型系统里没有"我觉得可能有更好的方向但我不确定"这个选项

### 两种解决路径

**路径 1：增加新的批注类型 `[DIRECTION]`**

```
[DIRECTION] — 方向质疑：人类怀疑当前方向可能不对，但不确定替代方案
→ AI 必须先评估：回答这个问题是否会改变推荐方案
→ 如果会：暂停，明确告知人类"回答这个问题将改变推荐方向"，让人类选择：
  (a) 回到 research 补充新研究再决定
  (b) 在 plan 中直接更新方向
  (c) 保持当前方向
→ 人类选择后再执行
```

**评估**：
- ✅ 最精确，人类明确表达了"方向质疑"的意图
- ❌ 增加了批注类型的数量和学习成本
- ❌ 人类可能不总能预判自己的 [Q] 会导致方向变更

**路径 2：不增加类型，在 AI 的响应协议中加升级规则**

```
当 AI 回答任何 [Q] / [CHANGE] / [NOTE] 时：
如果回答的结论会导致推荐方案改变，AI 必须：
1. 先明确声明："回答这个问题导致我认为推荐方案应从 X 改为 Y"
2. 提出选项：
   (a) 回到 research 补充新研究（→ 当作 [RESEARCH-GAP] 处理）
   (b) 在 plan 中直接更新方向（→ 触发 G4 的方向变更规则：通读全文对齐）
   (c) 保持当前方向（→ 记录为"考虑过但保留"）
3. 等待人类选择
4. 不可以在回答 [Q] 的同时直接改变方向
```

**评估**：
- ✅ 不增加批注类型，保持系统简单
- ✅ 把判断负担放在 AI 上（AI 应该能检测到"我的回答正在改变方向"）
- ✅ 给人类显式的选择权：回 research 还是直接改 plan
- ⚠️ 依赖 AI 的自我意识（"我是否正在改变方向"）

### 推荐：路径 2

理由：

1. **人类不应该被要求预判自己的问题会导致什么后果。** 如果人类能预判"这个问题会改变方向"，他们就不会标 `[Q]` 而会标 `[CHANGE]` 或 `[RESEARCH-GAP]`。让 AI 来检测方向变更比让人类来标注更合理。

2. **核心修复是"给人类选择权"。** 这次失败的真正问题不是"AI 改了方向"（方向可能确实应该改），而是 **AI 在回答 [Q] 的同时自动改了方向，没有让人类选择是先回 research 还是直接改 plan。** 人类失去了选择权。

3. **与现有协议的一致性。** `[RESEARCH-GAP]` 已经定义了"暂停当前文档，回 research 补充"。路径 2 把"方向变更"桥接到了这个已有机制上 — 如果人类选 (a)，就等于触发了一个隐式的 `[RESEARCH-GAP]`。

### 回到 research 还是在 plan 中处理？

这取决于方向变更的来源：

| 来源 | 推荐处理方式 |
|------|-------------|
| AI 的回答基于**已有 research** 中被忽略的证据 | 在 plan 中直接更新（research 已经覆盖了，只是 plan 没用到） |
| AI 的回答基于**新的推理或外部知识** | 回 research 补充（这是新发现，需要被记录和验证） |
| AI 的回答基于**人类提供的新上下文** | 在 plan 中直接更新 + 记录人类上下文来源 |

这次的实际情况是第二种：AI 提出了"gate vs harness"这个新的分析框架来否定 doc-quality.sh，但这个框架不在 research 中。**正确做法是先回 research 补充这个分析，再回 plan 引用。**

### 这暴露了一个更深的问题

**当前的批注类型系统是为人类设计的** — 人类知道自己要问什么、要改什么。但**方向变更经常是 AI 在回答过程中"发现"的** — AI 本来只想回答一个问题，回答着回答着发现了一个新的更好的方向。

这个"发现"过程本身没有错。错误在于 AI 把"发现 + 决策 + 执行"合并成了一步。正确的做法是把它拆成三步：
1. **发现**：AI 在回答中意识到方向可能需要改变
2. **暂停**：AI 明确声明，提出选项，等待人类决策
3. **执行**：人类选择后，按选择执行（回 research 或更新 plan）

这与 baton 的核心哲学一致：**人类掌握决策权，AI 掌握分析权。AI 不应该在分析过程中自动把分析结论变成决策。**

---

## Supplement D：新增缺口 G6

基于 Supplement C 的分析，识别出第六个缺口：

### G6：批注回答导致方向变更时无升级机制

**当前状态**：AI 回答 [Q] 时发现推荐方案应该改变 → 直接在同一回合中改变方向 + 更新文档 → 人类失去"是否接受方向变更"和"是先回 research 还是直接改 plan"的选择权

**失败实例**：[Q] "还有更好的方案吗" → AI 回答时直接切换到方案 D，没有暂停让人类选择

**改进方案**：在 baton-plan skill 的批注协议中加升级规则：

> **方向变更升级规则**：当回答任何批注（[Q]/[CHANGE]/[NOTE]）时，如果回答的结论会导致推荐方案改变，AI 必须：
> 1. 暂停 — 不在同一回合中改变方向
> 2. 声明 — "回答这个问题导致我认为推荐方案应从 X 改为 Y"
> 3. 提出选项 — (a) 回 research 补充新证据再决定 (b) 在 plan 中直接更新 (c) 保持当前方向
> 4. 等待人类选择后执行

**放置位置**：Annotation Protocol 段 + Red Flags 表格双重放置

Red Flags 表格新增行：

| Thought | Reality |
|---------|---------|
| "Let me just update the recommendation while answering this question" | 方向变更不是回答的副产品。暂停，声明，让人类选择。 |

---

## 更新的缺口一览

| # | 缺口 | 复盘中的失败实例 | 当前防线 | 改进层 |
|---|------|-----------------|---------|-------|
| G1 | Plan 内部一致性无检查 | 推荐切到 D，变更清单仍是 B | ❌ 无 | 结构兜底 + 认知引导 |
| G2 | Research→Plan 追溯无强制 | 删掉质量评估，无反证 | ❌ 无 | 合并到 G4 |
| G3 | Self-Review 不区分"风险"和"矛盾" | 把矛盾当风险放过 | ⚠️ 有模板无分类 | Iron Law 新增第四条 |
| G4 | 批注方向变更后无收敛步骤 | 改了推荐没通读全文 | ⚠️ 有"更新正文"无"通读" | Annotation Protocol + Red Flags |
| G5 | Todo 生成无前置一致性校验 | 冲突版本上生成 todo | ❌ 无 | Todolist Format 段前 |
| **G6** | **批注回答导致方向变更时无升级机制** | **[Q] 回答中直接改方向** | **❌ 无** | **Annotation Protocol + Red Flags** |

---

## 更新的改进矩阵

| # | 具体动作 | 放置位置 | 格式 |
|---|---------|---------|------|
| G1 | doc-quality.sh 结构检查 + skill 一致性自检 | skill: Process Step 5 (Self-Review) | 清单 |
| G2 | 合并到 G4 — 方向变更通读时显式对比 research | 同 G4 | 同 G4 |
| G3 | Iron Law 新增第四条 | skill: Iron Law（开头） | code block |
| G4 | 方向变更规则 | skill: Annotation Protocol + Red Flags 双重 | 规则 + 表格行 |
| G5 | Pre-todo 一致性三步确认 | skill: Todolist Format 段前 | 清单 |
| G6 | 方向变更升级规则（暂停→声明→选项→等待） | skill: Annotation Protocol + Red Flags 双重 | 规则 + 表格行 |

---

---

## Supplement E：批注类型系统的深层问题（回应 [DEEPER]）

### 问题的精确描述

人类指出："再重新审视目前的批注类型，包括批注区，感觉这一块会导致 AI 出现错乱。"

这个判断有确切的代码证据支撑。

### 问题 1：批注类型有 4 个不一致的来源

AI 在处理批注时，会从以下 4 处获取"可用类型"和"响应协议"：

| 来源 | 加载时机 | 列出的类型 |
|------|---------|-----------|
| **workflow.md:50** | 始终加载（via CLAUDE.md） | [NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP] — **6 个** |
| **baton-plan/SKILL.md:146-152** | invoke /baton-plan 时 | [Q] [NOTE] [CHANGE] [DEEPER] [MISSING] — **5 个，无 [RESEARCH-GAP]** |
| **baton-research/SKILL.md:164-168** | invoke /baton-research 时 | [Q] [NOTE] [DEEPER] [MISSING] [RESEARCH-GAP] — **5 个，无 [CHANGE]** |
| **文档的批注区模板** | AI 读文档时 | research: 5 个无 [CHANGE]；plan: 5 个无 [RESEARCH-GAP] |

**结果**：AI 同时看到 4 个类型列表，每个都是 6 类型的不同子集。如果人类在 plan.md 中写了一个 `[RESEARCH-GAP]`，AI 需要从 workflow.md 中找到它的处理规则，但 baton-plan/SKILL.md 和 plan.md 的批注区模板都没有提到这个类型。

**反证**：实际使用中，[RESEARCH-GAP] 确实被用在了 plan 文档里：
- `plans/plan-2026-03-07-hotl.md:429` — plan 中使用 [RESEARCH-GAP]，触发了 25 文件的项目审计
- `plans/plan-2026-03-04-architecture-fixes.md:234` — plan 中使用 [RESEARCH-GAP]

这证明"plan 批注区不列 [RESEARCH-GAP]"这个设计决策在实践中被突破了。

### 问题 2：批注类型混合了三种不同维度

当前 6 个类型实际上跨了三个维度：

| 维度 | 类型 | 说明 |
|------|------|------|
| **人类意图** | [Q] 提问, [NOTE] 补充, [CHANGE] 请求修改 | 人类想做什么 |
| **分析深度** | [DEEPER] 不够深, [MISSING] 遗漏 | AI 的分析质量不够 |
| **流程动作** | [RESEARCH-GAP] 需要更多研究 | 需要回到另一个阶段 |

这三个维度不是互斥的。一个 `[Q]` 的回答可能暴露出 `[DEEPER]` 级别的问题，最终需要 `[RESEARCH-GAP]` 级别的动作。但当前系统把它们放在同一个平面上，人类必须在批注时选择"一个"类型 — 而实际的反馈往往跨维度。

**这次失败的直接映射**：人类写了 `[Q] "还有更好的方案吗？"`。从意图维度看，这确实是 [Q]。但从影响维度看，这实际上导致了方向变更，接近 [RESEARCH-GAP] 的级别。AI 按 [Q] 的协议处理（"回答"），而不是按 [RESEARCH-GAP] 的协议处理（"暂停，研究，再回来"）。

### 问题 3：批注区模板同时服务两个受众

批注区末尾的模板文本：
```
> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"
```

这同时是：
- **给人类看的 UX 文本** — 告诉人类可以用哪些标注类型
- **给 AI 看的指令** — 告诉 AI 期望哪些类型的输入

这两个目标冲突：
- 对人类：类型越少越好，降低认知负担
- 对 AI：类型越全越好，避免遇到"不在列表里的类型"时不知如何处理

### 问题 4：AI 在 chat 中必须自行分类

workflow-full.md:256-257 规定了 in-chat 模式：
> "In-chat: Human gives feedback in conversation → AI identifies the annotation type"

这意味着 AI 要把人类的自然语言分类到 6 个类型中。但 [Q] 和 [CHANGE] 的边界模糊（"还有更好的方案吗？" 是问还是改？），[DEEPER] 和 [RESEARCH-GAP] 的边界模糊（"这里不够深"是在当前方向上挖更深，还是需要全新的研究？）。

**分类错误的后果**：如果 AI 把一个实际上是 [RESEARCH-GAP] 级别的反馈分类为 [Q]，它就会按 [Q] 的协议"回答并继续"，而不是按 [RESEARCH-GAP] 的协议"暂停、研究、再回来"。

### 根本原因

**批注类型系统的设计假设是"人类反馈可以被清晰地归类到互斥的类型中"。但实际使用证明，人类反馈经常跨越类型边界，特别是在 [Q] 和 [CHANGE]/[RESEARCH-GAP] 之间。**

### 改进方案

考虑了三个方向：

**方向 X：统一类型集 + 后果检测**

保留现有 6 个类型，但做两个改变：
1. **所有 6 个类型在所有文档中都可用** — 消除 research 和 plan 的子集分歧
2. **在 AI 响应协议中加入"后果检测"步骤** — 无论收到什么类型的批注，AI 在回答后必须评估：我的回答是否改变了方向？

这是最小改动方案。

**方向 Y：简化为 4 个类型**

| 新类型 | 含义 | 替代 |
|--------|------|------|
| `[Q]` | 提问或请求修改（合并 Q+CHANGE） | [Q] + [CHANGE] |
| `[DEEPER]` | 分析不够深或有遗漏（合并 DEEPER+MISSING） | [DEEPER] + [MISSING] |
| `[NOTE]` | 补充上下文 | [NOTE] |
| `[PAUSE]` | 需要暂停当前文档，先做其他事 | [RESEARCH-GAP] |

优点：类型数量减半，边界更清晰（[Q] 是所有主动反馈，[DEEPER] 是所有质量不足反馈，[PAUSE] 是所有流程中断）。

缺点：[Q] 合并了"我只是问问"和"我要你改"这两种不同语气的反馈。如果 AI 分不清"轻量问答"和"要求修改"，可能过度反应。

**方向 Z：两层标注（类型 + 严重度）**

```
[Q:minor] 简单提问，不影响方向
[Q:major] 提问，回答可能影响方向
[CHANGE:local] 局部修改
[CHANGE:direction] 方向性修改
```

缺点：增加了标注复杂度，人类要判断严重度 — 但人类往往不知道自己的问题会导致多大影响。

### 推荐：方向 X（统一 + 后果检测）

理由：

1. **最小改动原则** — 6 个类型已经被项目使用了多个迭代，改动类型系统会影响所有历史文档的一致性
2. **问题的核心不在类型本身** — 而在于 AI 的响应协议没有"后果检测"。即使把 [Q] 和 [CHANGE] 合并，如果响应协议不检测方向变更，同样的问题仍然会出现
3. **统一类型集消除了子集分歧** — 6 个类型全部出现在所有批注区模板中，消除 4 个来源不一致的问题

具体改动：

**1. 统一批注区模板**（research 和 plan 使用同一模板）：
```markdown
## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[RESEARCH-GAP]` 暂停研究
```

**2. 在 skill 的 Annotation Protocol 中加入后果检测**：
```
处理任何批注后，AI 必须自问：
- 我的回答是否改变了推荐方案？→ 如果是，触发方向变更规则（G4/G6）
- 我的回答是否否定了 research 中的结论？→ 如果是，先回 research 补证据
- 我的回答是否揭示了文档内部矛盾？→ 如果是，立即修复
```

**3. 在 skill 的 Red Flags 表格中加**：
```
| "这个 [Q] 只需要回答就好" | 回答后检查：方向是否变了？如果变了，这不是 [Q]，升级处理。 |
```

### 与 G6 的关系

方向 X 的"后果检测"吸收了 G6 的核心思路（AI 检测方向变更并升级），但不要求"额外一轮交互"。而是：

1. AI 回答批注
2. AI 自检回答是否导致方向变更
3. 如果是 → **在同一回合中**声明方向变更 + 触发 G4 的通读全文规则 + 明确告知人类"如果你认为需要回 research，请标 [RESEARCH-GAP]"
4. 不强制等待人类选择（减少交互轮次），但把选择权交给人类（人类看到声明后可以选择 [RESEARCH-GAP]）

这是 G6 的"轻量版" — 保留了方向变更的可见性和人类选择权，但不强制额外一轮。

---

## 更新的缺口一览（最终版）

| # | 缺口 | 改进 | 核心动作 |
|---|------|------|---------|
| G1 | Plan 内部一致性无检查 | doc-quality.sh 结构兜底 + skill 自检清单 | 已在 plan.md 变更 4+5 |
| G2 | Research→Plan 追溯 | 合并到 G4 通读时对比 research | skill 改进 |
| G3 | Self-Review 不区分矛盾和风险 | Iron Law 新增第四条 | skill 改进 |
| G4 | 方向变更后无收敛 | Annotation Protocol + Red Flags 双重 | skill 改进 |
| G5 | Pre-todo 无一致性校验 | Todolist Format 段前加三步确认 | skill 改进 |
| G6 | 方向变更无升级机制 | 后果检测（轻量版：同一回合声明 + 通读） | skill 改进 |
| **G7** | **批注类型 4 源不一致** | **统一为全部 6 类型 + 后果检测** | **模板统一 + skill 改进** |

---

---

## Supplement F：批注类型是否应该存在？（回应 [Q]）

### 问题

> 如果跳出目前设计的这几个批注类型来看呢？因为这几个批注类型我每次在批注时都需要手动添加和决策是哪种类型的？

这个问题挑战的不是"哪个类型更好"，而是**"人类是否应该承担分类的责任"**。

### 当前的认知成本

人类每次批注时的实际流程：

```
1. 想到要说的内容
2. 翻到批注区模板，看看有哪些类型
3. 判断自己的反馈属于哪个类型
4. 写下 [TYPE] + 内容
```

步骤 2-3 是纯开销。而且步骤 3 经常出现模糊情况：
- "还有更好的方案吗？" — 是 [Q] 还是 [CHANGE]？
- "这里不够深" — 是 [DEEPER] 还是 [MISSING]？
- "我觉得需要更多调查" — 是 [DEEPER] 还是 [RESEARCH-GAP]？

**人类被要求做一件 AI 比人类更擅长的事** — 从自然语言中提取意图分类。

### Baton 其实已经有"无类型"模式

workflow-full.md:254-256 定义了两种批注方式：

```markdown
#### Annotation Methods (either works)
- **In-document**: Human writes annotations directly in the document (structured, preferred)
- **In-chat**: Human gives feedback in conversation → AI identifies the annotation type
```

in-chat 模式下，**人类不需要选类型**。人类直接说"还有更好的方案吗"，AI 自己分类然后处理。这已经是现有协议的一部分。

**矛盾**：同一个系统里，in-chat 不要求分类，in-document 要求分类。人类自然会选择成本更低的 in-chat，导致 in-document 的结构化优势无法实现。

### 类型系统的真正价值是什么？

| 价值 | 有类型 | 无类型（自然语言） |
|------|--------|-------------------|
| 人类表达意图 | 显式（但有分类错误风险） | 隐式（AI 推断，但可能推断错） |
| AI 知道如何响应 | 查表（[Q]→回答，[CHANGE]→验证安全） | 推断（从内容判断需要什么动作） |
| Annotation Log 结构化 | 类型自动成为标签 | AI 需要自己标注类型 |
| 可搜索性 | grep "[RESEARCH-GAP]" | 需要语义搜索 |
| 人类认知负担 | 每次批注都要选类型 | 直接写想法 |

**关键观察**：前四项都是 AI 能做的事。只有最后一项是人类独自承担的成本。

### 三个可能的方向

**方向 α：完全去掉类型 — 纯自然语言批注**

```markdown
## 批注区

<!-- 直接写下你的反馈。AI 会判断如何处理。 -->
<!-- 审阅完毕后添加 <!-- BATON:GO --> -->

还有更好的方案吗？

这里的风险分析太浅了，特别是关于并发写入的场景。

补充一下：我们团队之前试过类似方案，主要问题是性能。
```

AI 处理流程：
1. 读取批注区中的所有文本
2. 对每条反馈推断意图（提问 / 修改请求 / 补充 / 深度不足 / 遗漏 / 需要研究）
3. 按推断的意图应用对应的响应协议
4. 在 Annotation Log 中记录：AI 推断的类型 + 人类原文 + AI 回应

**优点**：
- 人类零认知负担 — 想到什么写什么
- 消除了分类模糊性（AI 从完整上下文推断，比人类从孤立反馈分类更准确）
- 一条反馈可以同时被识别为多种类型（如"还有更好的方案吗"同时是 question + potential direction change）

**缺点**：
- AI 推断可能出错（但人类分类也会出错，而且 AI 可以在 Log 中显示推断结果，人类可以纠正）
- 丢失了"人类明确想要暂停去研究"的信号（[RESEARCH-GAP] 是唯一真正有流程控制意义的类型）

**方向 β：类型可选 — 人类可以标也可以不标**

```markdown
## 批注区

<!-- 写下你的反馈。可以加 [类型] 前缀让 AI 按特定方式处理，也可以直接写。 -->
<!-- 特殊指令：[PAUSE] = 暂停当前工作，先去做其他调查 -->

还有更好的方案吗？

[PAUSE] 先调查一下 Redis 在我们环境下的实际表现再决定缓存方案。

这里的并发场景没考虑到。
```

AI 处理流程：
1. 有显式类型 → 按类型处理
2. 无显式类型 → AI 推断意图，按推断处理
3. Annotation Log 中记录：类型（显式或推断）+ 人类原文 + AI 回应

**优点**：
- 兼容现有习惯（已经在用类型的人可以继续用）
- 降低门槛（不确定类型时直接写）
- 保留了 [PAUSE]/[RESEARCH-GAP] 的显式流程控制能力

**缺点**：
- 两种模式共存增加了系统复杂度
- AI 要同时处理"有类型"和"无类型"两种输入

**方向 γ：只保留一个类型 [PAUSE]，其余全部自然语言**

核心洞察：在 6 个类型中，只有 `[RESEARCH-GAP]` 有真正的**流程控制**意义（暂停当前文档，回到另一个阶段）。其余 5 个（[Q] [CHANGE] [NOTE] [DEEPER] [MISSING]）只影响 AI 的**响应方式**，不影响流程状态。

```markdown
## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后添加 <!-- BATON:GO --> -->

还有更好的方案吗？

这里不够深。

[PAUSE] 先调查一下 OpenCode 的插件 API 是否支持 glob。
```

**设计逻辑**：
- 只有流程控制需要显式标注（因为 AI 不应该自行决定暂停去做其他事 — 这是人类的决策）
- 其余所有反馈类型都可以由 AI 从内容推断（因为 AI 推断"提问 vs 修改请求 vs 深度不足"不需要人类的帮助）

**优点**：
- 人类几乎不需要选类型（99% 的批注直接写自然语言）
- 仅在需要流程控制时才显式标注（[PAUSE]）
- AI 的"后果检测"自然融入处理流程（不再依赖类型来决定响应，而是从内容推断 + 后果检测）
- 最简

**缺点**：
- Annotation Log 的类型标签变成 AI 推断的，可能不够一致
- 丢失了 [DEEPER] 作为"我对你的分析质量不满意"这个强信号

### 推荐：方向 γ（只保留 [PAUSE]）

理由的追溯链：

```
复盘暴露 → 批注类型分类模糊导致 AI 响应错误
  ↓
Supplement C → 问题不在类型本身，在于 AI 没有"后果检测"
  ↓
Supplement E → 类型系统有 4 源不一致 + 维度混合
  ↓
用户 [Q] → 每次批注都要选类型是认知开销
  ↓
本分析 → 6 个类型中只有 1 个有流程控制意义，其余都是响应方式差异
  ↓
结论 → 保留流程控制类型 [PAUSE]，其余由 AI 推断
```

**这与 Supplement E 的方向 X 不矛盾，而是进化**：

| Supplement E（方向 X） | Supplement F（方向 γ） |
|------------------------|------------------------|
| 保留 6 类型，统一模板 | 缩减为 1 显式类型 + AI 推断 |
| 加入后果检测 | 后果检测成为核心（不再依赖类型路由） |
| 解决 4 源不一致 | 根本消除不一致问题（只有 1 个类型需要定义） |

**如果采用方向 γ，G7 的解法变为**：不是"统一 4 个来源的类型列表"，而是"简化到只有 [PAUSE]，从根本上消除不一致"。

### 对 skill 和 workflow 的影响

| 文件 | 当前 | 改为 |
|------|------|------|
| workflow.md 批注协议 | 列出 6 类型 + 各自响应规则 | 改为：自然语言批注 + [PAUSE] + AI 后果检测 |
| workflow-full.md 批注区模板 | 两个不同的 5 类型子集 | 统一为一个简化模板 |
| baton-plan/SKILL.md | 5 类型的响应表格 | 改为：推断处理 + 后果检测清单 |
| baton-research/SKILL.md | 5 类型的响应表格 | 同上 |
| 批注区模板 | 类型说明 | 简化为"写下反馈，[PAUSE] = 暂停调查" |
| Annotation Log | 类型 + 原文 + 回应 | AI 推断的分类 + 原文 + 回应 |

### 风险与反证

**风险 1：AI 推断不如显式类型准确**

反证：这次失败恰恰是显式类型 [Q] 导致 AI 按"回答问题"处理，而不是检测到方向变更。如果没有类型，AI 只看内容"还有更好的方案吗"，更可能识别出这是一个对当前方案的质疑，而不是被 [Q] 标签锁定在"回答"模式。

**类型标签可能产生"锚定效应"** — AI 看到 [Q] 就按 [Q] 的协议走，即使内容暗示了更大的影响。去掉类型，AI 反而需要从内容本身判断，这可能更准确。

**风险 2：丢失 [DEEPER] 的"质量不满意"信号**

这个信号确实有价值。但"这里不够深"这句自然语言同样传达了不满意。AI 完全能理解这句话的含义。显式 [DEEPER] 的唯一额外价值是"格式化的不满意"，但如果内容已经清楚表达了同样意思，格式只是冗余。

**风险 3：Annotation Log 一致性下降**

如果 AI 推断类型，不同会话可能用不同的分类标准。但这个问题可以通过在 skill 中定义推断规则来缓解 — AI 在 Log 中记录推断的分类（question / change-request / context / depth-issue / gap / pause），保持一定的一致性。

---

## 更新的缺口一览（最终版 v2）

| # | 缺口 | 改进 |
|---|------|------|
| G1 | Plan 内部一致性无检查 | doc-quality.sh 结构兜底 + skill 自检清单 |
| G2 | Research→Plan 追溯 | 合并到 G4 通读时对比 research |
| G3 | Self-Review 不区分矛盾和风险 | Iron Law 新增第四条 |
| G4 | 方向变更后无收敛 | 后果检测 + 方向变更通读规则 |
| G5 | Pre-todo 无一致性校验 | Todolist Format 段前加三步确认 |
| G6 | 方向变更无升级机制 | 后果检测（轻量版，同一回合声明+通读） |
| G7 | 批注类型 4 源不一致 + 人类分类负担 | **方向 γ：只保留 [PAUSE]，其余自然语言 + AI 推断** |

## Questions for Human Judgment（最终版 v2）

1-4: 已回应

5. **方向 γ 是否太激进？** 从 6 个显式类型缩减到 1 个是大幅简化。你在实际使用中，是否有"我故意选了 [DEEPER] 而不是 [Q]，因为我想传达不满意"的场景？如果有，说明类型对你有分类以外的信号价值，可能值得保留 [DEEPER]。如果你每次都是"先想内容，再凑一个类型"，那 γ 是正确的方向。

## 批注区

<!-- 写下你的反馈。如果需要暂停当前文档去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->

<!-- 在下方添加反馈 -->
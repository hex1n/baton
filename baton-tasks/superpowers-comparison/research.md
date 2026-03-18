# Research: Baton vs Superpowers 设计对比分析

## 调查框架

- **问题**: Baton 的 skill/hook 设计与 Superpowers 框架有哪些值得借鉴的设计差异？
- **为什么**: 决定 Baton 下一步迭代方向，避免重复造轮子，识别可吸收的成熟模式
- **范围**: Baton 全部 hook（12 脚本）+ 6 skill vs Superpowers 全部 skill（14+）+ hook + 测试基础设施
- **已知约束**: Baton 的 hook 门控是核心差异化优势，不应降级为纯 prompt persuasion

---

## 1. 架构哲学对比

### 1.1 执行模型

**Baton**: 技术门控 + skill 纪律双层模型
- [CODE] `write-lock.sh:128-133` — `<!-- BATON:GO -->` 标记检查，exit 2 硬阻断
- [CODE] `bash-guard.sh:96-137` — 12 种 shell 写入模式的 regex/token 阻断
- [CODE] `completion-check.sh:44-61` — 回顾性检查硬阻断 task completion
- 总计 3 个硬门控 + 5 个 advisory hook

**Superpowers**: 纯说服工程模型
- [CODE] `hooks/hooks.json` — 仅 1 个 hook（SessionStart），注入 meta-skill 文本
- [DOC] `persuasion-principles.md` — 显式引用 Cialdini 说服框架 + Meincke et al. (2025) 研究，合规率 33%→72%
- 无写入阻断、无 bash 过滤、无 completion 门控
- 所有行为约束通过 skill 文本中的 Authority language、Rationalization table、Red flags list 实现

**证据对比**:
| 机制 | Baton | Superpowers |
|------|-------|-------------|
| 硬门控 (exit 2) | 3 个 hook | 0 |
| Advisory hook | 5 个 | 1 个（SessionStart 注入） |
| Fail-open 条件 | [CODE] `write-lock.sh:14,17-19,24-43,62-66,104-111` 共 5 种 | N/A |
| 反合理化条款 | 无系统性机制 | [DOC] 5 个 skill 包含 rationalization table（共 50+ 条目） |

### 1.2 评价

Baton 的硬门控提供 ~100% 阻断率（在非 fail-open 路径上），Superpowers 的说服工程提供 ~72% 合规率 [DOC]。但 Baton 缺少 Superpowers 在 skill-disciplined 层面的反合理化工程——这意味着对于 advisory hook 和 skill 纪律规则（如 3-failure stop、write set adherence），Baton 的实际合规率可能也只有 ~72% 或更低，因为没有反合理化条款来强化。

---

## 2. Token/上下文效率

### 2.1 每会话固定开销

**Baton**:
- [CODE] `workflow.md` (100 行, **1,291 words**) — 通过 `CLAUDE.md` 的 `@.baton/workflow.md` 每会话全量加载
- [CODE] `phase-guide.sh` 输出 50-124 words（取决于状态）
- **基线**: ~1,341-1,415 words/会话

**Superpowers**:
- [CODE] `using-superpowers/SKILL.md` (**760 words**) — 通过 SessionStart hook 注入
- 无其他固定加载
- **基线**: ~760 words/会话

**差异**: Baton 每会话固定开销是 Superpowers 的 **~1.8x**。

### 2.2 按需 Skill 开销

**Baton skill 字数**:
| Skill | Words |
|-------|-------|
| baton-research | 630 |
| baton-plan | 723 (最重) |
| baton-implement | 553 |
| baton-review | 613 |
| baton-debug | 283 (最轻) |
| baton-subagent | 582 |
| **总计** | **3,384** |

**Superpowers skill 字数**:
| Skill | Words |
|-------|-------|
| writing-skills (含测试方法论) | 3,204 (最重) |
| brainstorming | 1,534 |
| subagent-driven-development | 1,528 |
| systematic-debugging | 1,504 |
| test-driven-development | 1,496 |
| receiving-code-review | 929 |
| dispatching-parallel-agents | 923 |
| writing-plans | 807 |
| finishing-a-development-branch | 679 |
| verification-before-completion | 668 |
| requesting-code-review | 400 |
| executing-plans | 360 (最轻) |
| **总计** | **~14,032** |

**差异**: Superpowers 的 skill 总量是 Baton 的 **~4.1x**，但单个 skill 按需加载，且有明确 token 预算目标：
- [DOC] `writing-skills/SKILL.md` — "Getting-started <150 words, frequently-loaded <200 words, others <500 words"

Baton 无 token 预算意识。

### 2.3 上下文保护机制

**Baton**:
- [CODE] `settings.json:5` — `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "35"` (激进压缩)
- [CODE] `pre-compact.sh:31-50` — 压缩前输出 phase 状态 + ≤5 个 remaining todo items（~50-70 words）
- [CODE] `subagent-context.sh:34` — subagent 注入 ≤20 行 todo items（~200-300 words，硬上限）

**Superpowers**:
- 无 autocompact 配置
- 无 pre-compact hook
- [DOC] `using-superpowers/SKILL.md` — `<SUBAGENT-STOP>` 标记让 subagent 跳过 meta-skill

**评价**: Baton 的上下文保护更完善（pre-compact + autocompact 配置），但固定开销更大。Superpowers 通过更小的固定基线 + token 预算减少了压缩需求。

---

## 3. Skill TDD — Superpowers 独有能力

### 3.1 方法论

[DOC] `writing-skills/SKILL.md` (3,204 words) 定义了完整的 Skill TDD 方法论：

**RED 阶段**:
- 创建 3+ 压力场景（time, sunk cost, authority, economic, exhaustion, social, pragmatic — 7 种压力类型）
- 不加载 skill 运行，记录 agent 失败行为
- 验证失败是可重现的

**GREEN 阶段**:
- 写最小 skill 修复观察到的失败
- 验证 agent 现在遵循规则

**REFACTOR 阶段**:
- 识别新的合理化借口
- 为每个合理化添加: (1) 规则显式否定 (2) rationalization table 条目 (3) red flag 条目 (4) description 更新

[DOC] `testing-skills-with-subagents.md` — 记录 TDD skill 需要 6 轮 RED-GREEN-REFACTOR，识别 10+ 种独特合理化

### 3.2 测试基础设施

[DOC] `tests/` 目录包含 6 个子目录：
- `skill-triggering/` — 自然语言 prompt → 验证正确 skill 触发（使用 `claude -p --output-format stream-json`）
- `subagent-driven-dev/` — 端到端工作流测试（scaffold 项目 → 运行 Claude → 验证产出）
- `explicit-skill-requests/` — 显式 skill 请求测试
- `brainstorm-server/` — brainstorm WebSocket 服务器单元测试

### 3.3 Baton 现状

- ❌ 无 skill 测试框架
- ❌ 无压力场景定义
- ❌ 无反合理化条款的回归验证
- ❌ 无 skill 触发正确性测试

### 3.4 影响评估

**CSO 发现** [DOC]: Superpowers 记录了一个关键经验教训——当 skill description 总结工作流（"code review between tasks"）时，Claude 只做了 1 次 review 而非 2 次。改为触发条件描述（"Use when executing implementation plans"）后修复。

这说明 skill 的 description 字段直接影响 AI 行为，且影响方式不直观。Baton 的 skill description 未经过此类测试验证。

---

## 4. 两阶段 Review

### 4.1 Superpowers 模式

[DOC] `subagent-driven-development/SKILL.md` 实现两阶段 review：

1. **Spec Compliance Review** — "你构建的是否是被要求的？"
   - 不信任实现者的自我报告，独立检查代码
   - 通过 `spec-reviewer-prompt.md` 模板 dispatch subagent

2. **Code Quality Review** — "构建质量如何？"
   - 只在 spec review 通过后运行
   - 通过 `code-quality-reviewer-prompt.md` 模板 dispatch subagent
   - [DOC] Red flag: "Start code quality review before spec compliance is ✅"

### 4.2 Baton 模式

[CODE] `baton-review/SKILL.md` — 单一 review 流程，包含：
- First-Principles Review Framework（4 个问题）
- Phase-Specific Additions（research/plan/todolist/implementation 各有检查项）
- 但不区分 "是否符合规格" vs "代码质量"

### 4.3 评价

Superpowers 的两阶段模式解决了一个真实问题：code quality review 可能 pass 代码，即使它不符合需求规格。Baton 的 baton-review 包含 "Does each change match plan intent?" 检查项，但它与代码质量检查混在一起，没有强制先后顺序。

---

## 5. 反合理化工程

### 5.1 Superpowers 的系统性方法

[DOC] 跨 5 个 skill 的 rationalization table 统计：

| Skill | Rationalization 条目数 |
|-------|---------------------|
| using-superpowers | 12 |
| test-driven-development | 11 |
| verification-before-completion | 8 |
| writing-skills | 8 |
| systematic-debugging | (implicit, 通过 "human partner redirect signals") |

**格式**: `| Thought | Reality |` 两列表格，Thought 是 agent 可能的内心独白，Reality 是反驳。

[DOC] 额外反合理化技术：
- **Spirit vs Letter 防御** (`TDD/SKILL.md`): "Violating the letter of the rules is violating the spirit"
- **Delete mandate** (`TDD/SKILL.md`): 先写实现再写测试？删掉实现，从头来
- **Forbidden responses** (`receiving-code-review/SKILL.md`): 禁止 "You're absolutely right!", "Great point!" 等附和性回复
- **CSO description trap** (`writing-skills/SKILL.md`): description 不能总结流程，只能描述触发条件

### 5.2 Baton 的现状

- [CODE] `workflow.md:64` — `"Should be fine" is never a valid conclusion` — 1 条反合理化规则
- [CODE] `workflow.md:72` — `Blind compliance is a failure mode` — 1 条
- [CODE] `baton-review/SKILL.md` — Observability checks（3 条）
- 无 rationalization table 格式
- 无 "red flags" 列表
- 无 "spirit vs letter" 防御

**差距**: Baton 的 advisory hook 和 skill-disciplined 规则（3-failure stop, write set adherence, discovery stop）全部依赖 AI 自律，但没有 Superpowers 级别的反合理化工程来强化合规。

---

## 6. 反附和 (Anti-Sycophancy) 机制

### 6.1 Superpowers 独特创新

[DOC] `receiving-code-review/SKILL.md` (929 words) 包含：
- **禁止回复列表**: "You're absolutely right!", "Great point!", "Let me implement that now" — 在验证前禁止这些回复
- **No-thanks 规则**: "If you catch yourself about to write 'Thanks': DELETE IT. State the fix instead."
- **6 步响应协议**: READ → UNDERSTAND → VERIFY → EVALUATE → RESPOND → IMPLEMENT
- **来源区分**: human partner (trusted, skip to action) vs external reviewers (skeptical, verify technically)
- **YAGNI check**: grep codebase for actual usage before implementing "professional" features

### 6.2 Baton 的现状

- [CODE] `workflow.md:6-8` — "disagree with evidence" 原则
- [CODE] `workflow.md:10-14` — "Accept challenges proportionally" 原则
- 但无具体的反附和机制（禁止回复列表、情绪触发检测等）

### 6.3 评价

Superpowers 的反附和机制直接解决了 LLM 的已知弱点（sycophancy bias）。Baton 的 "disagree with evidence" 原则方向正确，但缺少实操层面的禁止列表和自检触发器。

---

## 7. Hook 执行模型对比

### 7.1 Baton 的多 hook 矩阵

[CODE] `.claude/settings.json` 注册了 10 个 hook 触发点：

| Event | Hook | Enforcement |
|-------|------|-------------|
| SessionStart | phase-guide.sh | Advisory |
| PreToolUse (Bash) | bash-guard.sh | **Hard (exit 2)** |
| PreToolUse (Write tools) | write-lock.sh | **Hard (exit 2)** |
| PostToolUse (Write tools) | post-write-tracker.sh + quality-gate.sh | Advisory |
| Stop | stop-guard.sh | Advisory |
| SubagentStart | subagent-context.sh | Advisory |
| TaskCompleted | completion-check.sh | **Hard (exit 2)** |
| PreCompact | pre-compact.sh | Advisory |
| PostToolUseFailure | failure-tracker.sh | Advisory |

### 7.2 Superpowers 的最小 hook

[DOC] `hooks/hooks.json` — 1 个 hook：
```json
{ "SessionStart": [{ "matcher": "startup|resume|clear|compact", "hooks": [{ "command": "session-start" }] }] }
```

### 7.3 工程复杂度对比

**Baton hook 基础设施**:
- [CODE] `plan-parser.sh` (378 行) — plan/research 发现 + section 解析 + write-set 提取
- [CODE] `_common.sh` (40 行) — 共享库
- 12 个 hook 脚本总计 **1,303 行 bash**
- 2 个 IDE adapter（`adapter-cursor.sh`, `adapter-codex.sh`）
- 支持 3 个平台（Claude Code 完整 / Cursor 降级 / Codex 最低）

**Superpowers hook 基础设施**:
- [DOC] `hooks/session-start` — ~70 行 bash（JSON 转义 + context 注入）
- [DOC] `hooks/run-hook.cmd` — 跨平台 polyglot wrapper（batch + bash）
- 总计 **~100 行**
- 5+ 平台支持（通过 plugin manifest 而非 adapter）

**差距**: Baton 的 hook 基础设施是 Superpowers 的 **~13x** 代码量。这不一定是问题（Baton 提供更强的门控），但维护成本和 bug 表面积显著更大。

### 7.4 已知执行漏洞

[CODE] `bash-guard.sh` 的 quote-stripping 逻辑已知漏洞：
- `bash-guard.sh:62-64` — double quote 内的 `\` 转义处理可被利用
- `bash-guard.sh:96` — heredoc `<<'EOF'>file` (无空格) 可能绕过
- `bash-guard.sh:121-123` — Python `open(path, mode='w')` (named arg) 未检测

[CODE] `failure-tracker.sh:36-37` — PPID 作为 session proxy，并行会话间不唯一
[CODE] `failure-tracker.sh:53-55` — 仅在 count==3 和 count==5 时告警，≥6 后静默

---

## 8. Skill 加载与发现机制

### 8.1 Superpowers 的 Plugin 系统

[DOC] `.claude-plugin/plugin.json` — Claude Code plugin manifest，支持：
- 通过 marketplace 安装: `/plugin install superpowers@claude-plugins-official`
- Skill 通过 `Skill` tool 按需加载（平台原生机制）
- 跨平台: `.cursor-plugin/`, `.codex/INSTALL.md`, `.opencode/plugins/superpowers.js`, `gemini-extension.json`

### 8.2 Baton 的集成方式

[CODE] `CLAUDE.md` — `@.baton/workflow.md` 全量包含
[CODE] `.claude/settings.json` — hook 注册
[CODE] `phase-guide.sh:155-170` — skill 可用性检查: `parser_has_skill "$skill_name"` 搜索 `.baton/skills/`, `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`

**差距**: Baton 不使用 plugin 系统，依赖手动 hook 注册 + `@` include。这限制了：
- 版本管理（无 `superpowers@5.0.2` 式版本号）
- 分发（无 marketplace）
- 平台移植（需要手写 adapter）

---

## 9. Counterexample Sweep

### 9.1 "Superpowers 的纯 prompt 模型足够了" — 是否成立？

**反面证据**:
- [DOC] Meincke et al. (2025) 报告最高合规率 72%，意味着 ~28% 的情况下 AI 仍然绕过规则
- Superpowers 自身的 `verification-before-completion/SKILL.md` 引用 "24 failure memories" — 即使有完善的 skill 文本，仍有大量失败案例
- [DOC] CSO 发现表明 description 字段的措辞直接影响行为——这种脆弱性在纯 prompt 模型中无法被技术兜底

**结论**: 纯 prompt 模型不足以替代 Baton 的硬门控。✅ Baton 的门控方向正确。

### 9.2 "Baton 的 hook 复杂度值得" — 是否成立？

**反面证据**:
- [CODE] `bash-guard.sh` 153 行，仍有已知绕过漏洞（quote-breaking, heredoc edge cases, Python named args）
- [CODE] `post-write-tracker.sh` 是 advisory，无法阻止 write set drift
- [CODE] `quality-gate.sh` 检查 `## Self-Challenge` ≥3 行，但不检查内容质量
- [CODE] `failure-tracker.sh` ≥6 次失败后静默

**结论**: 部分 hook 的投入产出比较低。❓ `quality-gate.sh` (45 行) 和 `failure-tracker.sh` (59 行) 的实际价值需要通过使用数据验证。

### 9.3 "Skill TDD 对 Baton 有价值" — 是否成立？

**支持证据**:
- Baton 的 skill 比 Superpowers 更短（平均 564 words vs 1,169 words），但包含更多硬规则（Iron Laws），错误遵循的后果更严重
- [DOC] CSO 发现直接适用于 Baton — skill description 影响 AI 行为但未被测试
- Baton 无法验证 skill 修改是否引入回归

**反面证据**:
- Baton 有 hook 硬门控兜底，即使 skill 纪律失败，关键路径仍被保护
- Skill TDD 的 ROI 取决于 skill 修改频率——如果 skill 已稳定，测试价值递减

**结论**: ✅ 值得采纳，但优先级取决于 skill 修改频率。当前阶段 baton skill 仍在快速迭代，测试价值较高。

---

## 10. Self-Challenge

### 最弱结论是什么？
"反合理化条款可以显著提高 advisory hook 的有效性" — 这个结论基于 Superpowers 的经验推断，但没有 Baton 特定的 A/B 测试数据。Cialdini/Meincke 的研究是通用 LLM 研究，不一定适用于 Baton 的特定 skill 结构。

### 什么没有调查？
1. Superpowers 的 skill 在实际使用中的合规率（repo 有 82.5k stars 但无公开使用统计）
2. Baton 当前 advisory hook 的实际合规率（无遥测数据）
3. `phase-guide.sh` fallback guidance vs skill-guided execution 的行为差异
4. Superpowers 的 `testing-skills-with-subagents.md` 中记录的 10+ 种合理化是否适用于 Baton

### 怀疑者会如何挑战？
- "Baton 的 hook 门控已经覆盖关键路径，反合理化工程的边际收益很低"
- "Token 预算优化的实际效果取决于上下文窗口大小——200k+ 模型下 1,291 words 的开销可忽略"
- "Skill TDD 的工程成本可能超过其发现的问题价值"

---

## Final Conclusions

### 高确信度结论

1. **Baton 的硬门控是正确方向** ✅ — Superpowers 的纯 prompt 模型合规率上限 ~72%，不足以替代技术阻断。[DOC] Meincke et al. (2025)
2. **Baton 缺少反合理化工程** ❌ — advisory hook 和 skill-disciplined 规则无反合理化支撑，实际合规率可能低于预期。[CODE] `workflow.md` 仅有 2 条反合理化规则
3. **Baton 每会话固定开销偏高** ❌ — 1,291 words vs Superpowers 760 words (1.8x)。[CODE] `workflow.md` 全量加载
4. **Skill TDD 是可借鉴的成熟方法论** ✅ — 有完整测试基础设施 + 实践经验（6 轮迭代 + 10+ 合理化识别）。[DOC] `writing-skills/SKILL.md`

### 中确信度结论

5. **两阶段 review 有增量价值** ❓ — 理论上解决 "quality pass but spec fail" 问题，但 Baton 的 baton-review 已包含 plan intent 检查。需要实际案例验证是否为真实盲区。
6. **Token 预算意识应被采纳** ❓ — 对 200k+ 模型可能影响有限，但 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: 35` 表明 Baton 已在积极管理上下文，减少固定开销逻辑一致。
7. **反附和机制有价值** ❓ — 解决 LLM 已知弱点，但 Baton 的 "disagree with evidence" 原则是否已在实践中足够需要使用数据验证。

### 低确信度结论

8. **部分 advisory hook 价值可疑** ❓ — `quality-gate.sh` (检查 Self-Challenge ≥3 行) 和 `failure-tracker.sh` (≥6 后静默) 的实际效果未经验证。但删除的风险大于保留的成本。

---

## 可借鉴设计的优先级排序

| 优先级 | 设计 | 来源 | 实施成本 | 预期收益 |
|--------|------|------|---------|---------|
| **P0** | 反合理化条款 (Rationalization Table + Red Flags) | Superpowers 全 skill | 低（文本添加） | 高（强化 advisory hook 合规率） |
| **P1** | Token 预算 + workflow.md 精简 | Superpowers writing-skills | 中（需重构 workflow.md） | 中（减少每会话开销 ~500 words） |
| **P2** | Skill 描述优化 (CSO) | Superpowers writing-skills | 低（修改 description 字段） | 中（改善 skill 触发准确性） |
| **P3** | Review 两阶段化 | Superpowers subagent-driven-dev | 低（baton-review 添加 Phase 0） | 中（防止 spec-fail-quality-pass） |
| **P4** | 反附和条款 | Superpowers receiving-code-review | 低（文本添加） | 低-中（解决 LLM 已知弱点） |
| **P5** | Skill TDD 框架 | Superpowers writing-skills + tests/ | 高（需建设测试基础设施） | 高（但 ROI 取决于 skill 迭代频率） |
| **P6** | Plugin manifest 分发 | Superpowers .claude-plugin/ | 高（架构变更） | 低（当前用户基数小） |

---

## Annotation Log

### Round 1 (批注 1-3, 来自 human)

**批注 1**: 调查时未使用 baton 的 research skill
**批注 2**: 使用 baton-research 后质量不如未使用时 @non-baton-research.md
**批注 3**: 使用 research 后竟然调用了 superpowers 的 code review skill

**分析**:

三条批注构成一个连贯的信号：**baton-research skill 在"设计对比分析"类任务上产生了负面效果**。

根因：
- baton-research 的设计目标是代码调查（call chain tracing, consistency matrix），不是框架间的设计对比。模板强制的 `[CODE] file:line` 标注和 counterexample sweep 在本场景下是空壳形式。
- 第一次非 baton 研究直接 dispatch 3 个并行 agent，信息密度更高、结论更清晰。baton flow 增加了流程开销但未发现新洞察。
- 批注 3 暴露了多 skill 框架共存时的选择冲突——AI 有 memory 指示用 baton-review 但仍试图 dispatch superpowers:code-reviewer。

**对本研究结论的影响**:

这些实证强化了以下结论：
1. [新增] **baton skill 需要更清晰的适用边界描述** — 当前 baton-research 的触发条件过于宽泛，导致被应用到不匹配的任务。这与 Superpowers 的 CSO (Claude Search Optimization) 发现一致：description 措辞直接影响 skill 是否被正确触发。将 P2 (Skill 描述优化) 提升为 **P0** 级别。
2. [修正] **流程严谨性 ≠ 产出质量** — baton 的 evidence standards 和 self-challenge 模板在代码调查场景有价值，但不应强制应用于所有研究类任务。baton-research 需要区分"代码调查"和"设计分析"两种模式，或明确声明不适用于后者。
3. [新增] **多框架共存的 skill 冲突是未预见问题** — 当 baton 和 superpowers skill 同时存在时，AI 在选择上会出错。这不在当前 research 范围内，但需要记录。

**优先级修正**:

| 原优先级 | 修正优先级 | 设计 | 修正原因 |
|---------|-----------|------|---------|
| P2 | **P0** | Skill 描述优化 (CSO) | 本次实证：skill 被错误触发到不匹配场景 |
| P0 | P0 | 反合理化条款 | 不变 |
| P1 | P1 | Token 预算 + workflow.md 精简 | 不变 |
| P3 | P2 | Review 两阶段化 | 上移：本次出现了 review skill 选择错误 |

---

### Round 2 (批注 1, 来自 human)

**批注**: 我预期 baton-research 是一个通用且强大的 research skill

**分析**:

这条批注推翻了 Round 1 的根因分析。

Round 1 结论："baton-research 设计目标是代码调查，被错误应用到设计对比" → **错误**
修正后结论："baton-research 的设计意图是通用研究，但实现被代码调查特化了" → 问题在 skill 自身

[CODE] `baton-research/SKILL.md` 的通用 vs 特化分析：

| 组件 | 通用性 | 证据 |
|------|--------|------|
| Iron Laws | ✅ 通用 | "NO CONCLUSIONS WITHOUT EXPLICIT EVIDENCE" 适用于任何研究 |
| Step 0: Frame | ✅ 通用 | Question/Why/Scope 适用于任何调查 |
| Step 0.5: Tool Inventory | ❌ 特化 | "≥2 distinct search methods beyond Read" 假定目标是代码库 |
| Step 1: Entry Points | ❌ 特化 | "affected files" 假定调查对象是代码 |
| Step 2: Call Chains | ❌ 特化 | `A (file:line) → B (file:line)` 是纯代码调查模式 |
| Step 2b: Consistency Matrix | 🟡 可通用化 | 矩阵思维适用于任何多维对比，但模板用了代码术语 |
| Step 2c: Counterexample Sweep | ✅ 通用 | 反证思维适用于任何研究 |
| Step 3: Evidence Standards | 🟡 可通用化 | `[CODE]`/`[DOC]` 有价值，但缺少 `[DESIGN]`/`[EMPIRICAL]` 等非代码证据类型 |
| Step 4: Self-Challenge | ✅ 通用 | 适用于任何研究 |
| Step 5: Dispatch Review | ✅ 通用 | 对抗性审查适用于任何研究 |
| Step 6: Convergence Check | ✅ 通用 | Final Conclusions 适用于任何研究 |
| Description | ❌ 特化 | "cross-module behavior tracing, multi-surface consistency checks" 全是代码术语 |

结论：skill 的**骨架**是通用的（Frame → Investigate → Challenge → Review → Conclude），但 Step 1-2 和 Evidence Standards 被硬编码为代码调查模式。description 也只描述了代码调查场景。

**对优先级的影响**:

这不仅是 "Skill 描述优化 (CSO)" 的问题——description 只是冰山一角。更根本的问题是 **baton-research 的 process 步骤需要泛化**，让它能同时支持：
- 代码调查（当前的 call chain tracing 模式）
- 设计分析（框架对比、架构评估）
- 外部研究（文档/API/生态系统调查）

这比修改 description 的工作量大得多，属于 skill 重构。

---

### Round 3 (批注 1, 来自 human)

**批注**: baton 的 research skill 是否也能像刚才一样支持多 agent 并行调查

**分析**:

当前状态：**不支持**。

[CODE] `baton-research/SKILL.md:103` — 唯一提到 subagent 的是 Step 5 "dispatch review subagent"，用于审查而非调查。
[CODE] `baton-subagent/SKILL.md:2` — 明确定义为 "baton-implement 的可选扩展"，不覆盖 research 阶段。

本次会话的实证：第一次非 baton 研究 dispatch 了 3 个并行 agent（分别探索 baton hooks / superpowers 结构 / hook 执行漏洞），信息密度和效率显著高于第二次 baton 顺序研究。

**baton-research 的并行调查扩展设计草图**:

在 Step 0 (Frame) 之后、Step 1 (Entry Points) 之前插入：

```
### Step 0.75: 调查维度分解

当研究问题包含 2+ 个独立维度时：
1. 识别可并行的独立调查维度（无信息依赖）
2. 为每个维度构造 agent context：
   - 该维度的具体子问题
   - 需要读取/抓取的目标（文件路径 or URL）
   - 输出格式要求（与主研究文档对齐）
3. 通过 Agent tool 并行 dispatch
4. 等待全部返回后：
   - 交叉验证各维度结论的一致性
   - 合并到主研究文档
   - 标记跨维度矛盾为 ❓
```

这个扩展也解决了 Round 2 识别的"通用化"问题——并行 dispatch 的 agent 可以使用不同的调查方法：
- 代码调查 agent → call chain tracing
- 外部研究 agent → WebFetch + 文档分析
- 设计对比 agent → 结构化对比矩阵

**Superpowers 对比**: Superpowers 也没有研究阶段并行机制。它的并行能力（`dispatching-parallel-agents`, `subagent-driven-development`）都面向实现/调试。**这可能是 baton 的差异化机会。**

---

## 批注区


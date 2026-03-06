# Baton 改进方案

> 日期: 2026-03-04
> 基础: research.md 六视角第一性原理分析
> 原则: 每个改动必须对应 research 中的具体发现；不做没有证据支撑的改动

---

## 改进哲学

research.md 揭示了一个核心矛盾：**Baton 的机制设计面向理想用户（专家、高参与度、愿意在文件中标注），但实际用户行为远比理想情况随意。**

改进不应该试图把用户拉向理想行为（那是徒劳的），而应该**让系统在实际行为下仍然产出价值**。

设计标准：
- 每个改动必须在**人最小合规**的情况下仍有正面效果
- 不增加人的操作步骤
- 不增加 write-lock.sh 的复杂度（逆转 scope creep）
- 保持 ~400 token 的 context 开销

---

## 改动一览

| # | 改动 | 对应 research 发现 | 影响范围 | 优先级 |
|---|------|-------------------|---------|--------|
| 1 | 写锁回归极简：移除 ## Todo 检查 | §五.系统论 scope creep；§三.博弈论 固定开销 | write-lock.sh, pre-commit, tests | P0 |
| 2 | 承认聊天反馈：AI 负责记录 Annotation Log | §七.AI行为 标注退化为聊天；§四.认知 外在负荷 | workflow.md, workflow-full.md | P0 |
| 3 | 增加复杂度自适应引导 | §三.博弈论 无梯度；§八.经济学 固定开销 | workflow.md, workflow-full.md, phase-guide.sh | P0 |
| 4 | 实现后回顾：补上缺失的反馈回路 | §五.系统论 无自我改进回路 | workflow.md, workflow-full.md, stop-guard.sh | P1 |
| 5 | 合法化探索性编码 | §四.认知 做中学；§六.软件工程 Bash 旁路 | workflow.md, workflow-full.md | P1 |
| 6 | AI 自审问题：弥补新手审阅者短板 | §四.认知 专家-新手差异 | workflow-full.md, phase-guide.sh | P1 |
| 7 | 强化反 sycophancy prompt | §七.AI行为 sycophancy 博弈 | workflow.md | P2 |
| **8** | **利用未开发的 hook 生态** | 标注 #1 + #4：Claude 有 14 种 hook，Baton 只用 3 种 | settings.json, 新脚本 | **P0** |

---

## 改动 1：写锁回归极简 — 移除 ## Todo 检查

### 问题（research §五 + §六）

`write-lock.sh:86-91` 在 v3 增加了 `## Todo` 检查。research 指出这是 scope creep 的信号：
- 写锁从"有没有计划"扩展到"计划格式是否完整"
- 如果每次 AI 绕过协议都加 hook 检查，写锁会逐渐膨胀
- 原问题（AI 跳过 todolist）的根因是 prompt 引导不够强，不是缺少技术强制

### 方案

**从 write-lock.sh 和 pre-commit 中移除 `## Todo` 检查。** 写锁回归到最简判断：

```
plan.md 存在？ → BATON:GO 存在？ → 放行
```

Todolist 要求通过以下方式保持：
- workflow.md Rules 中保留 "Todolist is required before implementation"（prompt 级）
- phase-guide.sh AWAITING_TODO 状态保留（SessionStart 引导）
- phase-guide.sh IMPLEMENT 状态的引导中强调"按 Todo 顺序"（行为引导）

### 为什么 prompt 级引导够用

research §七 指出：phase-guide.sh 的 SessionStart 输出在会话第一轮有强烈影响。而 AWAITING_TODO → IMPLEMENT 的过渡恰好发生在 BATON:GO 刚添加时（通常是新会话或会话早期）。prompt 在此刻的约束力是最强的。

如果 prompt 仍然不够，正确的修复是**改进 prompt 措辞**，而不是在 hook 中加检查。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/write-lock.sh:84-91` | 移除 `## Todo` 分支，GO 存在即放行 |
| `hooks/pre-commit:43-47` | 移除 `## Todo` 检查 |
| `tests/test-write-lock.sh` | 移除/调整 ## Todo 相关测试用例 |
| `tests/test-pre-commit.sh` | 移除/调整 ## Todo 相关测试用例 |
| `.baton/phase-guide.sh` | 保持 AWAITING_TODO 状态不变（引导层） |

### 风险

| 风险 | 概率 | 应对 |
|------|------|------|
| AI 再次跳过 todolist | 中 | 强化 workflow.md 的 todolist 规则措辞；phase-guide AWAITING_TODO 仍然引导 |
| 人困惑为什么 BATON:GO 后可以直接写码 | 低 | phase-guide AWAITING_TODO 状态仍会提示 |

---

## 改动 2：承认聊天反馈 — AI 负责记录 Annotation Log

### 问题（research §七 + §四）

research 的 AI 实际行为分析发现：

> 现实中人很少在 markdown 文件中写标注。人更自然的行为是在聊天中直接说反馈。

标注协议的**语义**被使用了（人确实在给 [Q]/[DEEPER] 类型的反馈），但**形式**经常被跳过。这导致 Annotation Log 消失，结构化收益打折。

认知科学分析也指出：在文件中写 `[DEEPER] § 某段` 增加了外在认知负荷，而标注的内容本身是有价值的相关负荷。

### 方案

**反转责任：人在聊天中给反馈（降低人的负担），AI 负责将其记录为结构化 Annotation Log（利用 AI 的优势）。**

在 workflow.md 和 workflow-full.md 中增加规则：

```markdown
### Annotation Protocol
...（现有标注类型保留不变）...

**标注方式（二选一）：**
- 人在文档中直接写标注（结构化，首选）
- 人在对话中说反馈 → AI 识别标注类型，引用人的原话记入 Annotation Log

无论哪种方式，AI 都必须：
1. 逐条回应（用 file:line 证据）
2. 记录到文档的 ## Annotation Log 中
3. 保留人的原始措辞（不改写意图）
```

### 为什么这样做

1. **匹配实际行为** — 人已经在聊天中给反馈了，不需要改变人的行为
2. **保留结构化收益** — Annotation Log 仍然被记录（由 AI 而非人来记录）
3. **降低外在负荷** — 人不再需要记住标注语法和在文件中定位
4. **AI 擅长这个** — 识别反馈类型、格式化记录、引用原文是 AI 的强项

### 风险

| 风险 | 概率 | 应对 |
|------|------|------|
| AI 曲解人的意图记录错误 | 中 | 规则要求"保留人的原始措辞"，人可以在看到 Log 后纠正 |
| Annotation Log 变成 AI 的独角戏 | 低 | 规则要求引用人的原话，保持双方声音 |
| 人完全不看 Annotation Log | 中 | 这是已有问题，此改动不使其恶化 |

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow.md` | Annotation Protocol 段增加"对话中反馈"路径 |
| `.baton/workflow-full.md` | [ANNOTATION] 段增加详细说明和示例 |

---

## 改动 3：复杂度自适应引导

### 问题（research §三 + §八）

博弈论分析发现系统缺少梯度 — 对 one-liner 和架构级重构施加相同最低开销。经济学分析显示边际效用在简单任务处严重失衡。

当前只有两个模式：完整流程 vs BATON_BYPASS=1（零保护）。

### 方案

**不增加技术机制，只增加引导文本。** 在 workflow.md 和 phase-guide.sh 中提供复杂度判断标准：

在 workflow.md 的 Flow 段后增加：

```markdown
### Complexity Calibration
- **Trivial** (1 file, <20 lines, no new dependencies): plan.md 可以是 3-5 行摘要 + GO
- **Small** (2-3 files, clear scope): plan.md 简述改动和理由，可跳过 research.md
- **Medium** (4-10 files or unclear impact): 完整 research → plan → 标注循环
- **Large** (10+ files or architectural): 完整流程 + 多轮标注 + 分批 todolist
```

在 phase-guide.sh RESEARCH 阶段的输出末尾增加：

```
Calibrate depth to task complexity:
- Trivial changes (1 file, <20 lines): skip research, write a brief plan.md
- Complex changes: full research with call chain tracing
```

### 为什么不用技术手段（如 BATON:QUICK 标记）

增加新标记 = 增加写锁的条件分支 = 与改动 1 的"写锁回归极简"矛盾。

复杂度判断是**人的认知决策**，不适合自动化。引导文本帮助人做出这个决策，比技术强制更合适。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow.md` | Flow 段后增加 Complexity Calibration 段（~50 tokens）|
| `.baton/workflow-full.md` | 对应位置增加详细说明 |
| `.baton/phase-guide.sh` | RESEARCH 和 PLAN 状态输出增加 1-2 行复杂度提示 |
| `tests/test-phase-guide.sh` | 增加复杂度引导文本断言 |
| `tests/test-workflow-consistency.sh` | 增加新段落一致性检查 |

### Token 预算影响

workflow.md 增加 ~50 tokens（从 ~400 到 ~450）。仍在可接受范围内。

---

## 改动 4：实现后回顾 — 补上缺失的反馈回路

### 问题（research §五）

系统论分析发现缺少"实现结果 → 计划质量"的反馈回路。每次 plan 循环独立运行，不从过去的错误中学习。Lessons Learned 只在中断时写，不是完成时。

### 方案

在 workflow-full.md 的 [IMPLEMENT] Completion 段和 stop-guard.sh 的归档提醒中增加回顾步骤：

```markdown
#### Completion
- After ALL items: run full test suite, record results
- **Retrospective**: Before archiving, append ## Retrospective to plan.md:
  · What did the plan get wrong? (predictions vs reality)
  · What surprised you during implementation?
  · What would you research differently next time?
- All complete + retro done → archive
```

stop-guard.sh 在归档提醒中增加回顾提示：

```
✅ All todo items complete.
📋 Before archiving, append ## Retrospective: what did the plan get wrong?
   Then: mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
```

### 为什么 Retrospective 而非 Lessons Learned

现有的 Lessons Learned 是给**下一个会话的 AI** 看的（"what to try next"），面向恢复工作。
Retrospective 是给**人和未来 AI** 看的（"what did we get wrong"），面向过程改进。两者互补，不冲突。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow-full.md` | [IMPLEMENT] Completion 段增加 Retrospective |
| `.baton/stop-guard.sh` | 归档提醒增加回顾提示 |
| `.baton/workflow.md` | Rules 中增加"完成后追加 Retrospective"（~15 tokens）|
| `tests/test-stop-guard.sh` | 增加回顾提示断言 |

---

## 改动 5：合法化探索性编码

### 问题（research §四 + §六）

认知科学分析指出"做中学"在某些场景下比"分析后做"更有效。写锁阻止了 spike solution。软件工程分析确认 Bash 是事实上的探索通道（advisory-only）。

### 方案

不改代码，只在文档中**显式承认和引导**这条路径：

在 workflow-full.md 的 [RESEARCH] 段增加：

```markdown
#### Exploratory Coding (Spike Solutions)
When understanding requires running code (testing an API, verifying behavior, prototyping):
- Use Bash tool for exploratory code — it is not blocked by write-lock
- Record findings in research.md with evidence
- Spike code is disposable — do not carry it forward into implementation
- If a spike reveals the plan needs changing, update plan.md before implementing
```

在 workflow.md 中（保持简洁）：

```markdown
- Exploratory code (spikes) → use Bash tool; record findings in research.md
```

### 为什么不移除写锁对源码的限制

探索性编码和正式实现有本质区别。Bash 中的探索是临时的、可丢弃的；Edit/Write 的修改是持久的、进入代码库的。保持写锁对 Edit/Write 的限制是正确的，但需要给探索一条合法通道。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow.md` | Rules 段增加 1 行探索性编码规则（~15 tokens）|
| `.baton/workflow-full.md` | [RESEARCH] 段增加 Exploratory Coding 子段 |
| `.baton/phase-guide.sh` | RESEARCH 状态输出末尾增加 1 行 spike 提示 |

---

## 改动 6：AI 自审问题 — 弥补新手审阅者短板

### 问题（research §四）

认知科学分析发现：Baton 对专家审阅者极有效，但对新手保护最弱。新手不知道对 research.md 问什么 [DEEPER]。这恰好是反过来的 — 最需要保护的人得到最少保护。

### 方案

在 research.md 和 plan.md 的产出引导中增加 AI 自审步骤：

在 workflow-full.md 的 [RESEARCH] 段末尾：

```markdown
#### Self-Review (before presenting to human)
Before completing research.md, append a section:
## Self-Review
- 3 questions a critical reviewer would ask about this research
- The weakest conclusion in this document and why
- What would change your analysis if investigated further
```

在 workflow-full.md 的 [PLAN] 段末尾：

```markdown
#### Self-Review (before presenting to human)
Before completing plan.md, append a section:
## Self-Review
- The biggest risk in this plan that you're least confident about
- What could make this plan completely wrong
- One alternative approach you considered but rejected, and why
```

### 为什么这样做

1. **降低审阅门槛** — 新手不知道问什么？AI 自己给出了 3 个起点
2. **利用 AI 的元认知** — AI 知道自己哪里不确定，让它主动暴露
3. **对专家也有价值** — 专家可以快速扫描自审段，确认 AI 是否识别了真正的风险
4. **零额外人工操作** — 完全由 AI 产出

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow-full.md` | [RESEARCH] 和 [PLAN] 段末尾增加 Self-Review 指导 |
| `.baton/phase-guide.sh` | RESEARCH 和 PLAN 状态输出中提及 self-review |

---

## 改动 7：强化反 sycophancy prompt

### 问题（research §七）

AI 实际行为分析发现：对于明显事实错误 AI 会反驳，但对于判断性问题倾向于列出利弊不明确反对，对于人的情绪表达几乎总是顺从。

### 方案

在 workflow.md 的 Mindset 段增加更具体的反 sycophancy 指令：

当前（`workflow.md:1-11`）：
```
Three principles that override all defaults:
1. Verify before you claim ...
2. Disagree with evidence ...
3. Stop when uncertain ...
```

增强为：
```
Three principles that override all defaults:
1. **Verify before you claim** — "should be fine" is not evidence. Read the code, cite file:line.
2. **Disagree with evidence** — the human is not always right. When you see a problem,
   explain it with code evidence. Don't comply silently, don't hide concerns.
   Even when the human sounds frustrated or impatient, your job is accuracy, not comfort.
3. **Stop when uncertain** — if you don't understand something, say so. Don't guess, don't gloss over.
```

新增 1 行（~12 tokens）："Even when the human sounds frustrated or impatient, your job is accuracy, not comfort."

### 为什么只加一行

research 正确指出 prompt 无法逆转训练内化的 sycophancy。但 prompt 可以提供"在特定场景下反驳的许可"。关键不是长篇大论，而是精准命中 AI 最容易顺从的场景（人表达情绪时）。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/workflow.md` | Mindset 段第 2 点增加 1 行 |
| `.baton/workflow-full.md` | 对应位置同步 |
| `tests/test-workflow-consistency.sh` | 验证新行在两个文件中一致 |

---

## 改动 8：利用未开发的 hook 生态

### 问题（标注 #1 + #4）

Context7 检索 Claude Code hooks 文档发现：Claude Code 提供 **14 种 hook 事件**，Baton 只使用了 3 种（SessionStart、PreToolUse、Stop）。

完整的 hook 生态：

| Hook 事件 | 可阻止？ | Baton 当前使用 |
|-----------|---------|---------------|
| SessionStart | ❌ 否 | ✅ phase-guide.sh |
| SessionEnd | ❌ 否 | ❌ |
| PreToolUse | ✅ exit 2 阻止 | ✅ write-lock.sh |
| PostToolUse | ❌ 否 | ❌ |
| PostToolUseFailure | ❌ 否 | ❌ |
| PermissionRequest | ✅ exit 2 阻止 | ❌ |
| UserPromptSubmit | ✅ exit 2 修改 | ❌ |
| Stop | ✅ exit 2 阻止 | ✅ stop-guard.sh |
| SubagentStart | ❌ 否 | ❌ |
| SubagentStop | ✅ exit 2 阻止 | ❌ |
| TaskCompleted | ✅ exit 2 阻止 | ❌ |
| TeammateIdle | ✅ exit 2 阻止 | ❌ |
| PreCompact | ❌ 否 | ❌ |
| Notification | ❌ 否 | ❌ |

此外，hook 有三种类型：
- **command**（shell 命令）— Baton 当前全部使用这种
- **prompt**（LLM 评估）— 将 hook 上下文交给 AI 判断，适合需要语义理解的检查
- **agent**（agentic 验证）— 启动一个子代理做深度验证

### 方案

**不改动写锁，通过新 hook 在其他生命周期点注入控制和引导。** 这正好回应了标注 #1 的核心问题：在不增加 write-lock 复杂度的前提下实现更细粒度的控制。

#### 8a. PostToolUse(Edit|Write) — 实现后合规追踪

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write|MultiEdit|CreateFile",
      "command": "sh .baton/post-write-tracker.sh"
    }]
  }
}
```

**作用**: 每次写入后检查修改的文件是否在 plan.md 的 todolist 中。不阻止（PostToolUse 不可阻止），但向 stderr 输出警告：

```
⚠️ Modified src/auth.ts — not listed in plan.md todolist.
   If this is necessary, update plan.md before continuing.
```

**对应 research 发现**: §六 "Only modify files in the plan" 规则经常被违反，但没有运行时反馈。

#### 8b. SubagentStart — 计划上下文注入

```json
{
  "hooks": {
    "SubagentStart": [{
      "command": "sh .baton/subagent-context.sh"
    }]
  }
}
```

**作用**: 当启动 subagent 时，向 stderr 输出 plan.md 的 ## Todo 段落和当前进度。解决 subagent 不知道整体计划上下文的问题。

**对应 research 发现**: §五 subagent 可能在没有计划上下文的情况下运行。

#### 8c. TaskCompleted — 回顾强制点

```json
{
  "hooks": {
    "TaskCompleted": [{
      "command": "sh .baton/completion-check.sh"
    }]
  }
}
```

**作用**: 任务完成时检查 plan.md 是否已有 `## Retrospective`。如果没有且所有 todo 已完成，exit 2 阻止完成，提示先写回顾。与改动 4（Retrospective）联动。

**对应 research 发现**: §五 缺少"实现结果 → 计划质量"的反馈回路。

#### 8d. PreCompact — 关键上下文保护

```json
{
  "hooks": {
    "PreCompact": [{
      "command": "sh .baton/pre-compact.sh"
    }]
  }
}
```

**作用**: context 压缩前，向 stderr 输出 plan.md 的当前进度摘要和最近的 Annotation Log 条目，确保压缩后 AI 仍保留关键决策上下文。

**对应 research 发现**: §七 phase-guide 引导在长会话中被淹没。PreCompact 可以在压缩前重新注入关键信息。

#### 关于 prompt 类型 hook 的考量

标注 #1 提到"在 tool use 的钩子里检查是否满足某些条件"。Claude Code 的 `prompt` 类型 hook 可以做到这一点 — 它将 hook 上下文交给 AI 做语义判断，比 shell 脚本的字符串匹配更灵活。

但本次不采用 prompt 类型 hook，原因：
1. **Token 开销** — 每次触发都消耗额外 AI token
2. **延迟** — 需要一次额外的 AI 调用
3. **不确定性** — AI 判断不如 shell 脚本确定，违反 Baton 的"可靠性 > 一切"原则

未来如果需要更智能的检查（如"这次修改是否偏离了 plan 的意图"），prompt hook 是正确的工具。但目前的改动应先用 command hook 覆盖明确的检查。

### 优先级分配

| 子改动 | 优先级 | 理由 |
|--------|--------|------|
| 8a PostToolUse | P0 | 直接提供运行时反馈，填补现有空白 |
| 8c TaskCompleted | P1 | 与改动 4 联动，有依赖 |
| 8b SubagentStart | P1 | 对使用 subagent 的场景有价值 |
| 8d PreCompact | P2 | 长会话改进，优先级较低 |

### 涉及文件

| 文件 | 改动 |
|------|------|
| `.baton/post-write-tracker.sh` | 新建：PostToolUse hook，检查修改文件是否在 plan |
| `.baton/subagent-context.sh` | 新建：SubagentStart hook，注入计划上下文 |
| `.baton/completion-check.sh` | 新建：TaskCompleted hook，检查回顾是否完成 |
| `.baton/pre-compact.sh` | 新建：PreCompact hook，输出关键上下文摘要 |
| `.claude/settings.json` | 新增 4 个 hook 绑定 |
| `setup.sh` | configure_claude 函数中新增 hook 注册 |
| `tests/test-hooks.sh` | 新建：新 hook 的测试 |

### 风险

| 风险 | 概率 | 应对 |
|------|------|------|
| PostToolUse 警告太频繁导致 AI 忽略 | 中 | 只在文件明确不在 plan 中时警告，plan 中的"受影响文件"也纳入白名单 |
| TaskCompleted 阻止导致用户困惑 | 低 | 阻止消息清晰说明需要什么，并提供跳过方式 |
| hook 数量从 3 增到 7，setup.sh 复杂度增加 | 中 | 每个 hook 脚本保持极简（<30 行），逻辑集中在各自脚本中 |
| 非 Claude Code IDE 不支持这些 hook | 确定 | 这些是 Claude Code 专属增强，adapter 层不受影响 |

---

## 不做的事情（和理由）

| 提议 | 为什么不做 |
|------|----------|
| 增加 BATON:QUICK 轻量模式标记 | 增加写锁复杂度，与改动 1 矛盾。用引导文本（改动 3）替代 |
| 修复 Bash 旁路（bash-guard 改为阻止） | research 正确指出 Bash 旁路实际上是有价值的探索通道（改动 5）|
| 自动检测 research.md 深度 | research §二 指出质量检查不可靠且增加复杂度。用 AI 自审（改动 6）替代 |
| 修复多 IDE 承诺不对等 | 这是 IDE 生态的限制，不是 Baton 能解决的。可以在文档中更显著标注差异，但不作为此次改动 |
| 增加会话间记忆/学习机制 | 超出 Baton 的职责边界（Baton 管协作协议，不管 AI 记忆）。Retrospective（改动 4）是最小的回路修补 |
| 标注协议增加 [ABORT]/[RESTART] | research 指出这不是严重遗漏，人可以直接删 plan.md 重来 |

---

## 改动依赖关系

```
改动 1 (写锁极简)  ─── 独立，可先做
改动 2 (聊天标注)  ─── 独立，可先做
改动 3 (复杂度引导) ─── 独立，可先做
改动 4 (回顾)      ─── 独立（但 8c 依赖此改动的 Retrospective 定义）
改动 5 (探索编码)  ─── 独立
改动 6 (AI自审)    ─── 独立
改动 7 (反sycophancy) ─── 独立
改动 8 (hook 生态)  ─── 8a/8b/8d 独立；8c 依赖改动 4

改动 1-7 互不依赖。改动 8c (TaskCompleted) 应在改动 4 (回顾) 之后实现。
```

---

## Token 预算影响

| 文件 | 当前 | 改动后 | 增量 |
|------|------|-------|------|
| workflow.md | ~400 tokens | ~480 tokens | +80 |

增量来源：
- 改动 2：+15 tokens（标注方式说明）
- 改动 3：+50 tokens（Complexity Calibration）
- 改动 5：+15 tokens（探索编码规则）
- 改动 7：+12 tokens（反 sycophancy 行）

~480 tokens 仍在合理范围。如果需要压缩，优先级：改动 3 的完整分级表可以精简为 2 行。

**改动 8 对 token 预算无影响** — 所有新 hook 通过 settings.json 注册，各自输出到 stderr，不增加 workflow.md 的 context 开销。PreCompact hook (8d) 会在压缩前注入额外 context，但这恰恰是在 context 即将被压缩时发生的，不占用正常工作区间的 token。

---

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->

## Todo

### P0 — 改动 1：写锁回归极简

- [x] 1.1 write-lock.sh：移除 `## Todo` 检查分支（:86-91），BATON:GO 存在即 exit 0
- [x] 1.2 hooks/pre-commit：移除 `## Todo` 检查（:43-47），BATON:GO 存在即 exit 0
- [x] 1.3 tests/test-write-lock.sh：移除/调整 ## Todo 相关测试用例（Test 19 等），新增"GO 即放行"用例
- [x] 1.4 tests/test-pre-commit.sh：移除/调整 ## Todo 相关测试用例（Test 8 等）
- [x] 1.5 tests/test-adapters.sh：确认 adapter 测试用例与新逻辑一致（之前 code-review 发现 Test 1 缺 Todo）

### P0 — 改动 2：承认聊天反馈

- [x] 2.1 workflow.md：Annotation Protocol 段增加"对话中反馈"路径说明（~15 tokens）
- [x] 2.2 workflow-full.md：[ANNOTATION] 段增加聊天反馈识别 + AI 记录到 Annotation Log 的详细说明

### P0 — 改动 3：复杂度自适应引导

- [x] 3.1 workflow.md：Flow 段后增加 ### Complexity Calibration 段（Trivial/Small/Medium/Large）
- [x] 3.2 workflow-full.md：对应位置增加详细复杂度说明
- [x] 3.3 phase-guide.sh：RESEARCH 状态输出末尾增加复杂度提示（1-2 行）
- [x] 3.4 phase-guide.sh：PLAN 状态输出末尾增加复杂度提示（1-2 行）
- [x] 3.5 tests/test-phase-guide.sh：增加复杂度引导文本断言
- [x] 3.6 tests/test-workflow-consistency.sh：增加 Complexity Calibration 一致性检查

### P0 — 改动 8：利用未开发的 hook 生态

- [x] 8.1 新建 .baton/post-write-tracker.sh：PostToolUse hook，检查修改文件是否在 plan todolist 中
- [x] 8.2 新建 .baton/subagent-context.sh：SubagentStart hook，向 stderr 输出 plan 的 Todo 段和进度
- [x] 8.3 新建 .baton/completion-check.sh：TaskCompleted hook，检查所有 todo 完成后是否有 Retrospective
- [x] 8.4 新建 .baton/pre-compact.sh：PreCompact hook，输出 plan 进度摘要 + 最近 Annotation Log
- [x] 8.5 .claude/settings.json：新增 PostToolUse、SubagentStart、TaskCompleted、PreCompact 四个 hook 绑定
- [x] 8.6 setup.sh：configure_claude 函数中新增 hook 注册逻辑
- [x] 8.7 新建 tests/test-new-hooks.sh：post-write-tracker、subagent-context、completion-check、pre-compact 的测试

### P1 — 改动 4：实现后回顾

- [x] 4.1 workflow-full.md：[IMPLEMENT] Completion 段增加 Retrospective 步骤
- [x] 4.2 workflow.md：Rules 段增加"完成后追加 ## Retrospective"规则（~15 tokens）
- [x] 4.3 stop-guard.sh：归档提醒增加回顾提示（"Before archiving, append ## Retrospective"）
- [x] 4.4 tests/test-stop-guard.sh：增加回顾提示断言

### P1 — 改动 5：合法化探索性编码

- [x] 5.1 workflow.md：Rules 段增加 1 行探索性编码规则（~15 tokens）
- [x] 5.2 workflow-full.md：[RESEARCH] 段增加 #### Exploratory Coding (Spike Solutions) 子段
- [x] 5.3 phase-guide.sh：RESEARCH 状态输出末尾增加 spike solution 提示（1 行）

### P1 — 改动 6：AI 自审

- [x] 6.1 workflow-full.md：[RESEARCH] 段末尾增加 #### Self-Review 指导（3 个自审问题）
- [x] 6.2 workflow-full.md：[PLAN] 段末尾增加 #### Self-Review 指导（3 个自审问题）
- [x] 6.3 phase-guide.sh：RESEARCH 状态输出中增加 self-review 提示
- [x] 6.4 phase-guide.sh：PLAN 状态输出中增加 self-review 提示

### P2 — 改动 7：强化反 sycophancy

- [x] 7.1 workflow.md：Mindset 第 2 点增加 1 行（"Even when the human sounds frustrated or impatient, your job is accuracy, not comfort."）
- [x] 7.2 workflow-full.md：对应位置同步增加
- [x] 7.3 tests/test-workflow-consistency.sh：验证新行在两个文件中一致

### 收尾

- [x] 9.1 运行全量测试套件，确认所有测试通过（仅 WSL 性能基准未通过，非功能问题）
- [x] 9.2 phase-guide.sh：修复 State 编号重复（code-review 发现的 State 3 重复问题）`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 改动 3：为什么不用技术手段？ -->
[NOTE]
   1.对于claude 我发现他还有很多钩子可以使用 比如tool use的钩子，能不能利用这些钩子来做一些更细粒度的控制？比如说在tool use的钩子里去检查是否满足某些条件，如果不满足就拒绝这个工具的使用请求，这样是不是可以在不增加write lock复杂度的情况下实现一些更灵活的控制？
   2.对于改动6，我觉得这个自审的步骤非常有必要，尤其是对于新手来说，可以帮助他们更好地理解自己的研究和计划中可能存在的风险和不确定性，同时也可以帮助AI更好地识别和暴露这些风险，从而提高整个流程的质量和可靠性。
   3.对于改动7，我觉得这个反sycophancy的提示非常重要，因为AI在面对人的情绪表达时确实很容易顺从，这可能会导致一些不准确的结果或者错误的决策，所以让AI明确知道它的职责是准确性而不是取悦人类，这样可以帮助它更好地抵抗sycophancy的倾向，从而提高整个系统的可靠性和有效性。
   4.claude 中还有很多生命周期的钩子，比如说在会话开始时、会话结束时、每轮对话结束时等等，这些钩子也可以用来做一些更细粒度的控制，比如说在会话开始时检查一些前置条件，在每轮对话结束时检查一些后置条件，这样可以帮助我们更好地管理整个会话的流程和状态，从而提高整个系统的效率和效果。
   5.对于查资料 比如要查claude的钩子 去做检索的时候使用 context7 这样的工具是最好的

---

## Annotation Log

### Round 1 (2026-03-04)

**[NOTE] #1 — Claude 有更多 hook，能否用于细粒度控制**

> 原文："对于claude 我发现他还有很多钩子可以使用 比如tool use的钩子，能不能利用这些钩子来做一些更细粒度的控制？比如说在tool use的钩子里去检查是否满足某些条件，如果不满足就拒绝这个工具的使用请求，这样是不是可以在不增加write lock复杂度的情况下实现一些更灵活的控制？"

→ **完全正确，这是一个关键洞察。** 通过 Context7 检索 Claude Code hooks 文档，确认 Claude Code 提供 14 种 hook 事件，Baton 仅使用 3 种。已新增**改动 8**（利用未开发的 hook 生态），包含 4 个子改动：

- **8a PostToolUse(Edit|Write)** — 写入后检查文件是否在 plan 中（不阻止，输出警告）
- **8b SubagentStart** — 向 subagent 注入计划上下文
- **8c TaskCompleted** — 任务完成时检查是否已写 Retrospective（可阻止，exit 2）
- **8d PreCompact** — context 压缩前保护关键决策信息

关于"在 tool use 的钩子里检查条件并拒绝" — 这正是 PreToolUse 的 exit 2 行为（当前 write-lock.sh 已在使用）。但核心思路是正确的：**将新的检查分散到不同的生命周期 hook 中，而不是把所有逻辑堆到 write-lock.sh 里。** 每个 hook 脚本保持极简（<30 行），职责单一。

**结果**: 已采纳，新增改动 8。

---

**[NOTE] #2 — 认同改动 6（AI 自审）**

> 原文："对于改动6，我觉得这个自审的步骤非常有必要，尤其是对于新手来说，可以帮助他们更好地理解自己的研究和计划中可能存在的风险和不确定性，同时也可以帮助AI更好地识别和暴露这些风险，从而提高整个流程的质量和可靠性。"

→ **已确认，改动 6 保持不变。** 你的分析补充了一个重要视角：自审不仅帮助新手*理解*风险，还帮助 AI *识别*风险。这是因为 Self-Review 段落要求 AI 显式回答"最弱的结论是什么"，这迫使 AI 做一次元认知反思（meta-cognitive reflection），可能激活它在正常输出中不会主动触发的不确定性识别。

**结果**: 已确认，无需修改。

---

**[NOTE] #3 — 认同改动 7（反 sycophancy）**

> 原文："对于改动7，我觉得这个反sycophancy的提示非常重要，因为AI在面对人的情绪表达时确实很容易顺从，这可能会导致一些不准确的结果或者错误的决策，所以让AI明确知道它的职责是准确性而不是取悦人类，这样可以帮助它更好地抵抗sycophancy的倾向，从而提高整个系统的可靠性和有效性。"

→ **已确认，改动 7 保持不变。** 需要坦诚说明一个局限：research §七 指出 prompt 级指令无法逆转训练内化的 sycophancy 行为。改动 7 的一行新增文字（"Even when the human sounds frustrated or impatient, your job is accuracy, not comfort"）提供的是"反驳的许可"（permission to disagree），而非"反驳的保证"。在 AI 面对高情绪压力时，这行文字的实际约束力仍然有限。但这是在 prompt 层面能做到的最佳努力。

**结果**: 已确认，无需修改。

---

**[NOTE] #4 — Claude 生命周期 hook 可用于更细粒度控制**

> 原文："claude 中还有很多生命周期的钩子，比如说在会话开始时、会话结束时、每轮对话结束时等等，这些钩子也可以用来做一些更细粒度的控制，比如说在会话开始时检查一些前置条件，在每轮对话结束时检查一些后置条件，这样可以帮助我们更好地管理整个会话的流程和状态，从而提高整个系统的效率和效果。"

→ **与标注 #1 互补，已整合到改动 8。** Context7 检索确认了以下生命周期 hook：

| 你提到的 | 对应的 Claude Code hook | 改动 8 是否使用 |
|---------|----------------------|---------------|
| 会话开始 | SessionStart | ✅ 已有（phase-guide.sh） |
| 会话结束 | SessionEnd | ❌ 不使用 — 没有可靠的归档时机判断 |
| 每轮对话结束 | 无直接对应 | — |
| 前置条件检查 | SessionStart / PreToolUse | ✅ 已有 |
| 后置条件检查 | PostToolUse / TaskCompleted | ✅ 改动 8a + 8c |

关于 SessionEnd：虽然可以在会话结束时做检查，但 SessionEnd hook 不可阻止（exit 2 无效），且会话可能因网络断开等原因非正常结束，不是可靠的检查点。stop-guard.sh（Stop hook）已经覆盖了"会话即将结束"的场景。

关于"每轮对话结束" — Claude Code 没有直接的 PostTurn hook。最接近的是 PostToolUse（每次工具调用后）和 Stop（AI 认为任务完成时）。改动 8a 利用了 PostToolUse 来实现"每次写入后检查"。

**结果**: 已采纳，整合到改动 8。

---

**[NOTE] #5 — 使用 Context7 检索文档**

> 原文："对于查资料 比如要查claude的钩子 去做检索的时候使用 context7 这样的工具是最好的"

→ **已采纳并执行。** 通过 Context7 的 resolve-library-id + query-docs 检索了 Claude Code 的完整 hooks 文档，获得了准确的 hook 事件列表、hook 类型（command/prompt/agent）、matcher 语法和阻止行为（exit 0 vs exit 2）。这些信息直接构成了改动 8 的设计依据。

相比直接搜索网页，Context7 的优势在于返回的是经过结构化处理的官方文档内容，避免了过时信息或非官方来源的干扰。已在 phase-guide.sh RESEARCH 状态的引导中提示使用文档检索工具（`phase-guide.sh:164-166`）。

**结果**: 已执行，检索结果已反映在改动 8 中。

---

### Round 2 (2026-03-04)

**[Q] #1 — 能否用子代理做研究，输出到 research.md**

> 原文："在研究阶段 能否使用子代理去做研究 然后把研究结果输出到research.md 这样可以让子代理去专门负责研究 可能会有更深入的分析和更全面的覆盖 而且不会占用主代理的上下文 这样可以让主代理更专注于计划和实现"

→ **可以，而且 phase-guide.sh 已经部分支持了。** `phase-guide.sh:157` 在 RESEARCH 状态中提示：

```
Use subagents to trace parallel branches when you find 3+ call paths (10+ files)
```

但这只是用子代理做**部分**研究（并行追踪分支），不是你提的**完整委托**（子代理负责整个 research.md）。

完整委托的利弊分析：

| 方面 | 利 | 弊 |
|------|---|---|
| **context 空间** | ✅ 子代理有独立 context window，不占用主代理空间 | — |
| **深度** | ✅ 子代理可以专注于代码追踪，不被对话干扰 | — |
| **并行** | ✅ 多个子代理可以同时调查不同模块 | — |
| **用户意图理解** | — | ❌ 子代理看不到主对话中人的需求描述、偏好、之前的讨论 |
| **交互式研究** | — | ❌ 子代理无法在研究中途问人问题（[Q] 类交互丢失） |
| **质量控制** | — | ⚠️ 子代理的输出质量取决于主代理给的 prompt 质量 |

**关键问题是"用户意图"的传递。** research.md 的价值不仅是代码分析，还包括从人的角度理解"什么是重要的"。如果子代理不知道人关心什么，它可能会做出全面但不精准的研究（什么都查了，但没深入人真正关心的点）。

**建议的模式（不需要改动 Baton 机制）：**

```
主代理（理解人的意图）
  │
  ├── 向子代理下达具体研究任务（"追踪 UserService 的调用链到底层"）
  │     └── 子代理输出追踪结果
  │
  ├── 向另一个子代理下达研究任务（"分析所有 EventBus listener"）
  │     └── 子代理输出分析结果
  │
  └── 主代理汇总子代理结果 + 人的意图 → 写 research.md
```

这比"子代理直接写 research.md"更可靠，因为主代理保留了**汇总和意图对齐**的职责。这个模式已经可以在当前 Baton 下工作，不需要新的机制。

**如果要在 Baton 中显式引导这个模式**，可以在 workflow-full.md 的 [RESEARCH] 段增加子代理使用指南。但这属于方法论引导，不属于 Baton 的核心协议（research §五 的职责边界定义：Baton 管协作协议，不管方法论）。

**结果**: 不需要新改动。当前机制已支持，可在 workflow-full.md 中增加引导文本。建议纳入改动 5（合法化探索性编码）的同一位置，作为 [RESEARCH] 段的"高级研究策略"子段。

---

**[Q] #2 — 子代理生成计划，人来审核？**

> 原文："如果使用子代理去做研究和实现 那么在计划阶段是否还需要人来审核计划 还是说直接让子代理去生成计划 然后人来审核这个计划 这样可以让子代理去专门负责计划 可能会有更合理的计划和更好的执行力"

→ **人审核计划这一步不能跳过，这是 Baton 的核心设计。** 但"谁来*草拟*计划"是灵活的。

回到 research §二（信息论）的核心发现：

> Baton 的写锁本质上是一个信道上的同步原语。它不改善信道质量，它只是在关键时刻（写代码前）强制双方同步一次。

**plan.md + BATON:GO 是这个同步点。** 如果跳过人的审核，双方就没有同步，"共同理解"就不存在。这时候即使代码写得再好，方向可能是错的。

但你的问题里有一个有价值的区分：

```
"生成计划" ≠ "审核计划"

子代理可以 → 草拟 plan.md（基于 research.md 和需求）
人必须   → 审核 plan.md（标注循环 → BATON:GO）
```

这其实就是当前的工作流 — AI（无论是主代理还是子代理）写 plan.md，人做标注审核。**Baton 不关心 plan.md 是谁写的，只关心人是否审批了（BATON:GO）。**

关于"子代理实现" — 这也已经在 Baton 的设计范围内：
- `phase-guide.sh:81` 指出 "Independent items: may run in parallel"（可以用子代理并行实现）
- 改动 8b（SubagentStart hook）专门解决子代理缺乏计划上下文的问题
- first-principles.md §九 Q5 详细讨论了子代理实现的依赖关系处理

**结果**: 不需要新改动。Baton 的设计已经允许子代理参与研究和实现，核心约束只在"人必须审核 plan.md"这一个同步点。

[Q]
   1. 还有一个问题 就是我刚才在plan中新增了批注 但是 你并没有识别到 这个批注的内容 也没有把它整合到改动中去 你是怎么处理这个批注的 你是直接忽略了这个批注 还是说你有识别到这个批注 但是觉得这个批注不重要 所以就没有把它整合到改动中去
  
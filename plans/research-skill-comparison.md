# Research: Baton Skills vs 社区同类 Skill 多角度对比分析

## 工具清单

| 工具 | 用途 | 结果 |
|------|------|------|
| Glob/Read | 本地 baton skills + superpowers skills | 完整读取所有 SKILL.md |
| WebSearch | 社区 skill 仓库、agentskills.io 标准、框架对比 | 10+ 搜索查询 |
| 已有研究 | `plans/research-2026-03-07-skill-ification.md` | 复用 skill 写作最佳实践 |
| 本地文件系统 | `~/.claude/plugins/cache/` 下所有 SKILL.md | 37 个 skill 文件 |

---

## 一、对比范围

### Baton 三大 Skills（本项目）

| Skill | 文件 | 行数 | 核心职责 |
|-------|------|------|---------|
| baton-research | `.claude/skills/baton-research/SKILL.md` | 227 行 | 调查型研究，产出 research.md，file:line 证据标准 |
| baton-plan | `.claude/skills/baton-plan/SKILL.md` | 206 行 | 方案提案+方案分析，产出 plan.md，人类批注→BATON:GO |
| baton-implement | `.claude/skills/baton-implement/SKILL.md` | 155 行 | 忠实执行 plan，todolist 驱动，自检+验证 |

### 社区对标 Skills

| 来源 | Skill | 版本 | 对标 baton |
|------|-------|------|-----------|
| **superpowers** (obra) | brainstorming | 4.3.1 | ≈ baton-research（探索阶段） |
| **superpowers** | writing-plans | 4.3.1 | ≈ baton-plan |
| **superpowers** | executing-plans | 4.3.1 | ≈ baton-implement |
| **superpowers** | subagent-driven-development | 4.3.1 | ≈ baton-implement（并行模式） |
| **superpowers** | test-driven-development | 4.3.1 | 无直接对标（baton 无 TDD skill） |
| **superpowers** | systematic-debugging | 4.3.1 | 无直接对标（baton 无 debug skill） |
| **superpowers** | verification-before-completion | 4.3.1 | ≈ baton-implement 的自检触发器 |
| **planning-with-files** (OthmanAdi) | planning-with-files | 2.0.0 | ≈ baton 整体流程（Manus 风格） |
| **levnikolaevich** | claude-code-skills | — | ≈ baton 整体（109 skill 编排） |
| **agentskills.io** | 跨 IDE 标准 | — | baton 的 SKILL.md 格式基础 |
| **HumanLayer RPI** (Dex Horthy) | Research-Plan-Implement | — | ≈ baton 整体流程（最接近的哲学对标） |
| **tdd-guard** (nizos) | Hook 强制 TDD | — | ≈ baton write-lock（Hook 门控思路） |
| **BMAD Method** | 21 agent 模拟 | — | ≈ baton（全流程但更重量级） |
| **Block/Goose RPI** | /research /plan /implement | — | ≈ baton 流程（原生 slash command） |
| **HULA** (Atlassian) | 学术 HITL 框架 | — | ≈ baton（学术验证的 HITL） |
| **everything-claude-code** (affaan-m) | 性能优化工作流 | — | ≈ baton（token 经济学+验证模式） |

---

## 二、核心维度对比

### 维度 1：设计哲学

| 维度 | Baton | Superpowers | planning-with-files | levnikolaevich |
|------|-------|-------------|---------------------|----------------|
| **核心理念** | 人机共识构建协议 | Agent 自主开发工作流 | 文件即工作记忆 | 全生命周期编排 |
| **人的角色** | 审阅者+批注者+审批者 | 合作伙伴（"human partner"） | 用户（被动接收） | 用户（发起者） |
| **AI 的角色** | 调查者，非执行者 | 高级开发者 | 任务执行者 | 多 agent 工蜂 |
| **控制权分布** | 人类主导：BATON:GO 门控 | AI 主导：自主决策+checkpoint | AI 主导：自动推进 | AI 全自动+质量门控 |
| **信任模型** | 低信任：每步验证 | 中信任：批次检查 | 中信任：phase 完成时检查 | 高信任：全自动流水线 |

**关键洞察**：

- ✅ Baton 是唯一将**人类批注协议**（`[Q]`, `[CHANGE]`, `[DEEPER]`, `[MISSING]`, `[RESEARCH-GAP]`）编码为一等公民的系统。Superpowers 依赖自然语言对话；planning-with-files 无结构化反馈机制。
- ✅ Baton 的 "AI 是调查者不是执行者" 定位在社区中**独一无二**。其他所有系统都假设 AI 应该尽快开始写代码。
- ❓ levnikolaevich 的 109 skill 编排系统声称覆盖全生命周期，但未验证其实际执行质量（来源仅为 GitHub README）。

### 维度 2：门控机制

| 门控类型 | Baton | Superpowers | planning-with-files |
|----------|-------|-------------|---------------------|
| **写入阻止** | write-lock.sh (exit 1) 阻止源代码写入 | 无——纯 prompt 指令 | PreToolUse hook 仅读取 plan（不阻止） |
| **审批标记** | `<!-- BATON:GO -->` HTML 注释 | 用户口头同意 | 无 |
| **审批者** | 仅人类可放置 BATON:GO | AI 自行推进，人类 checkpoint | AI 自行推进 |
| **回滚机制** | 删除 BATON:GO → 回到批注阶段 | 无结构化回滚 | 无 |
| **文件范围限制** | 只能修改 plan 中列出的文件 | 无明确限制 | 无 |
| **失败停止** | 3 次失败必须停止报告 | 3 次失败质疑架构 | 3 次失败升级用户 |
| **Hook 强制** | 是——shell hook 拦截 Edit/Write | 否——纯 prompt 纪律 | 部分——Stop hook 检查完成度 |

**关键洞察**：

- ✅ Baton 的 **write-lock.sh 是社区中唯一真正通过 exit code 阻止 AI 写入的机制**。Superpowers 的纪律完全依赖 prompt 合规性——AI "觉得应该" 遵守 TDD，但没有任何东西阻止它不遵守。
  - 证据：`write-lock.sh:91` — `grep -q '<!-- BATON:GO -->' "$PLAN"` 是唯一解锁判断
  - 对比：superpowers TDD skill (SKILL.md:33-34) — `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST` 只是 prompt 文本
- ✅ Baton 的 `<!-- BATON:GO -->` 作为 HTML 注释的设计精妙：不影响 markdown 渲染、grep 可检测、人类可用任何编辑器操作、可 git diff。社区无类似设计。
- ❌ planning-with-files 的 PreToolUse hook（`SKILL.md:7-9`）只读取 plan 头部 30 行输出到 stderr，**不阻止任何操作**。这是 advisory，不是门控。

### 维度 3：证据标准

| 方面 | Baton | Superpowers | planning-with-files |
|------|-------|-------------|---------------------|
| **引用要求** | 每个结论必须 file:line | 无 file:line 要求 | 无 |
| **标记体系** | ✅/❌/❓ 三级确认 | 无结构化标记 | 无 |
| **"should be fine" 规则** | 明确禁止——不是有效结论 | 无类似约束 | 无 |
| **反例搜索** | Counterexample Sweep 步骤 | 无 | 无 |
| **自审** | Self-Review + Questions for Human Judgment | 无结构化自审 | 无 |
| **验证标准** | 读代码实现，不只读接口 | 测试通过即可 | 无 |

**关键洞察**：

- ✅ Baton 的 **file:line 证据标准在整个社区中没有对标物**。这是 baton 最核心的差异化：
  - `baton-research/SKILL.md:124-133` — 每个 claim 需要 file:line
  - `baton-research/SKILL.md:86-91` — counterexample sweep 主动搜索反证
  - 社区最接近的是 superpowers 的 `verification-before-completion`，但它要求的是"运行验证命令"（测试/构建），不是"引用源码位置"
- ✅ Baton 的三级标记体系（✅ confirmed / ❌ problem / ❓ unverified）强制 AI 对每个结论表态确信度。社区无类似实践。

### 维度 4：工作流完整性

```
Baton:         research.md → plan.md → [批注循环] → BATON:GO → todolist → implement → retrospective
Superpowers:   brainstorm → design doc → writing-plans → executing-plans/subagent-dev → finishing-branch
planning-w-f:  task_plan.md + findings.md + progress.md → execute phases → check-complete
```

| 阶段 | Baton | Superpowers | planning-with-files |
|------|-------|-------------|---------------------|
| **探索/研究** | baton-research（深度调查） | brainstorming（对话式） | findings.md（记录发现） |
| **方案设计** | baton-plan（多方案分析） | writing-plans（执行计划） | task_plan.md（阶段列表） |
| **人类审阅** | 批注协议（结构化） | 对话（非结构化） | 无 |
| **实施** | baton-implement（忠实执行） | executing-plans / subagent-dev | 直接执行 |
| **质量检查** | 自检触发器 + completion-check | 双阶段 code review（spec + quality） | check-complete.sh |
| **回顾** | Retrospective（plan 预测 vs 实际） | 无 | 无 |
| **会话交接** | Lessons Learned + 归档 | 无 | progress.md（会话日志） |

**关键洞察**：

- ✅ Baton 的**批注循环**（annotation cycle）是唯一将人类反馈结构化编码的系统：
  - 6 种批注类型各有对应 AI 行为（`workflow-full.md:248-329`）
  - AI 必须引用代码反驳错误建议（"blind compliance is a failure mode"）
  - 如果单轮出现 3+ `[DEEPER]`/`[MISSING]`，建议升级复杂度
- ✅ Baton 的 **Retrospective** 和 **Lessons Learned** 机制在实施完成后强制反思，为下次迭代积累经验。Superpowers 无类似机制。
- ❌ Baton **缺少** superpowers 的 TDD 和 systematic-debugging 等**领域专用技能**。Baton 只有流程 skills，没有方法论 skills。
- ❌ Baton **缺少** superpowers 的 code review 双阶段模型（spec compliance → code quality）。Baton 的实施验证依赖 self-check，而非独立 reviewer agent。
- ❌ Baton **缺少** superpowers 的 git worktree 隔离和分支管理能力。

### 维度 5：反理性化设计

"反理性化" (anti-rationalization) 是让 AI 在压力下仍遵守纪律的关键。

| 技巧 | Baton | Superpowers | 备注 |
|------|-------|-------------|------|
| **Iron Law** | ✅ 3 条铁律 | ✅ 每个纪律 skill 1 条 | 形式相同，灵感可能来自同源 |
| **Red Flags 列表** | ✅ 每个 skill 6-7 条 | ✅ 每个 skill 5-12 条 | Superpowers 更详尽 |
| **Rationalization 表** | ✅ 每个 skill 4-6 条 | ✅ TDD 有 11 条，debug 8 条 | Superpowers 更全面 |
| **`<HARD-GATE>` 标签** | ❌ 无 | ✅ brainstorming 使用 | XML 标签强制阻止 |
| **`<EXTREMELY-IMPORTANT>`** | ❌ 无 | ✅ using-superpowers 使用 | 强调绝对要求 |
| **"精神 vs 字面" 封堵** | ❌ 未明确 | ✅ "Violating the letter is violating the spirit" | 封堵整类理性化 |
| **元认知触发器** | ✅ 有（3 条） | ❌ 无独立概念 | Baton 独有 |
| **Counterexample Sweep** | ✅ 有 | ❌ 无 | Baton 独有 |
| **证据标准作为反理性化** | ✅ "should be fine 不是有效结论" | ❌ 无 | Baton 独有 |

**关键洞察**：

- ✅ Baton 在**研究阶段的反理性化**设计更强（元认知触发器 + counterexample sweep + 证据标准）。这符合 baton "先理解后执行" 的哲学。
- ❌ Baton 在**实施阶段的反理性化**设计弱于 superpowers。Superpowers 的 TDD skill 有 11 条理性化反驳 + `<Good>`/`<Bad>` 内联示例 + "Delete means delete" 绝对规则。Baton 的 baton-implement 只有 4 条理性化反驳。
- ❓ 两个系统都未做过严格的 A/B 测试来验证这些反理性化措施的实际效果。Superpowers 的 writing-skills skill 描述了 TDD 风格的 skill 测试方法论（`writing-skills/SKILL.md:536-560`），但未公布量化结果。

### 维度 6：Token 效率与可扩展性

| 维度 | Baton | Superpowers | planning-with-files |
|------|-------|-------------|---------------------|
| **常驻上下文** | workflow.md (~100 行) via `@import` | using-superpowers (~100 行) 每次加载 | 无常驻 |
| **按需加载** | 3 个 SKILL.md (共 ~588 行) | 14 个 SKILL.md (共 ~3000+ 行) | 1 个 SKILL.md (~194 行) |
| **最大单 skill** | 227 行 (baton-research) | 656 行 (writing-skills) | 194 行 |
| **跨引用方式** | 无——各 skill 独立 | `REQUIRED SUB-SKILL:` + `REQUIRED BACKGROUND:` | 无 |
| **Description 质量** | "Use when" + 触发条件 + 自然语言关键词 | "Use when" + 触发条件（精简） | 长描述含 "Manus-style" |
| **Skill 数量** | 3 | 14（核心）+ 6（支持文件） | 1 |
| **描述长度** | ~150-200 字符 | ~80-120 字符 | ~200 字符 |

**关键洞察**：

- ✅ Baton 的 3 skill 设计是**极简主义**：每个 skill 对应一个清晰的工作流阶段，无重叠。总计 ~588 行按需加载。
- ❌ Baton 的 skill 之间**无跨引用机制**。Superpowers 用 `REQUIRED SUB-SKILL` 和 `REQUIRED BACKGROUND` 显式声明依赖链（如 `executing-plans → finishing-a-development-branch → using-git-worktrees`）。这允许技能链式调用。
- ✅ Baton 的 description 包含中文触发词（"出 plan"、"实施"、"开始"），提高了中文用户场景下的激活率。这是社区 skills 中罕见的**双语触发**设计。
- ❓ Superpowers 14 个核心 skill 总计 ~3000+ 行，如果全部按需加载会消耗大量 context。但其 description-only 激活模型确保只有相关 skill 被加载。

### 维度 7：IDE 适配与标准合规

| 维度 | Baton | Superpowers | 社区标准 |
|------|-------|-------------|---------|
| **IDE 支持** | 11 IDE（setup.sh 安装） | Claude Code 原生 | agentskills.io: 26+ 平台 |
| **适配方式** | Shell 适配器翻译协议 | Plugin 系统 | SKILL.md 标准格式 |
| **SKILL.md 合规** | ✅ 标准 YAML frontmatter | ✅ 标准 YAML frontmatter | name + description |
| **Hook 系统** | ✅ 8 个 shell hook | ❌ 无 hook | Stop hook (planning-with-files) |
| **跨 IDE 一致性** | 部分——opencode-plugin.mjs 与 shell hook 行为不一致 | N/A（仅 Claude Code） | agentskills.io 定义标准 |

**关键洞察**：

- ✅ Baton 是社区中**唯一通过 hook 系统在多 IDE 间强制执行工作流**的项目。11 IDE 支持通过 `setup.sh` (1524 行)，4 个协议适配器确保 write-lock 语义一致。
- ❌ agentskills.io 标准只定义了 SKILL.md 格式，**不涉及 hook 或门控机制**。Baton 的 hook 层是超越标准的创新。
- ❓ Superpowers 作为 Anthropic marketplace 官方插件，仅支持 Claude Code。其 skills 理论上可移植（标准 SKILL.md），但其工作流假设了 Claude Code 的 Agent tool 和 TodoWrite。

---

## 三、一致性矩阵：功能覆盖对比

| 能力 | Baton | Superpowers | HumanLayer RPI | tdd-guard | planning-w-f |
|------|-------|-------------|----------------|-----------|-------------|
| 研究/探索阶段 | ✅ baton-research | ✅ brainstorming | ✅ research phase | ❌ 无 | ✅ findings.md |
| 方案设计 | ✅ baton-plan | ✅ writing-plans | ✅ plan phase | ❌ 无 | ✅ task_plan.md |
| 人类结构化反馈 | ✅ 批注协议 | ❌ 仅对话 | ❌ 编辑 plan | ❌ 无 | ❌ 无 |
| 写入门控 | ✅ write-lock hook | ❌ prompt 纪律 | ❌ 自愿审阅 | ✅ hook 门控 | ❌ advisory |
| 实施执行 | ✅ baton-implement | ✅ executing-plans | ✅ implement phase | ❌ 无 | ✅ phase 执行 |
| TDD 纪律 | ❌ 无 | ✅ TDD skill | ❌ 无 | ✅ hook 强制 | ❌ 无 |
| 调试方法论 | ❌ 无 | ✅ debugging skill | ❌ 无 | ❌ 无 | ❌ 无 |
| Code Review | ❌ 无 | ✅ 双阶段 review | ❌ 无 | ❌ 无 | ❌ 无 |
| 上下文管理 | ✅ pre-compact | ❌ 无 | ✅ Dumb Zone | ❌ 无 | ✅ 2-Action |
| 证据标准 | ✅ file:line | ❌ 无 | ❌ 无 | ❌ 无 | ❌ 无 |
| 反理性化 | ✅ 中等 | ✅ 强 | ❌ 无 | ✅ 中等 | ❌ 弱 |
| 回顾/反思 | ✅ Retrospective | ❌ 无 | ❌ 无 | ❌ 无 | ❌ 无 |
| 复杂度分级 | ✅ 4 级 | ❌ 无 | ❌ 无 | ❌ 无 | ❌ 无 |
| 多 IDE 支持 | ✅ 11 IDE | ❌ Claude Code | ❌ Claude Code | ✅ Claude Code | ❌ Claude Code |
| 生产效果数据 | ❌ 无 | ❌ 无 | ✅ 32 文件/零评论 | ❌ 无 | ❌ 无 |

---

## 四、深度洞察

### 4.1 Baton 的独特价值（社区无对标）

1. **结构化人类反馈协议**：6 种批注类型 + AI 必须用证据回应 + Annotation Log 归档。这不是 "和用户聊天"，而是有格式、有规则、有归档的正式协议。社区中零对标。

2. **file:line 证据标准**：每个结论必须引用源码位置。这把 AI 的输出从 "看起来对" 提升到 "可验证"。社区最接近的是 superpowers 的 verification-before-completion，但它验证的是测试结果，不是推理过程。

3. **复杂度校准**：Trivial → Small → Medium → Large 四级，AI 提议，人类确认。这避免了对简单任务过度流程化和对复杂任务流程不足的问题。社区无对标。

4. **Hook 强制的门控**：write-lock.sh 是唯一真正通过 exit code 阻止写入的社区实现。所有其他系统依赖 prompt 纪律。

5. **Retrospective + Lessons Learned**：实施完成后强制反思 "plan 哪里错了"、"什么意外了"、"下次怎么研究"。这是跨会话学习的机制。

### 4.2 Superpowers 的优势（Baton 缺失）

1. **领域专用 Skills**：TDD (372 行)、Debugging (297 行)、Code Review 是独立的、经过反理性化测试的方法论 skills。Baton 只有流程 skills，没有 "怎么写测试"、"怎么调 bug" 的指导。

2. **Skill 链式调用**：`REQUIRED SUB-SKILL` + `REQUIRED BACKGROUND` 语法允许 skills 显式声明依赖。`brainstorming → writing-plans → executing-plans/subagent-dev → finishing-branch` 形成完整链。Baton skills 之间无显式依赖声明。

3. **Subagent 架构**：每个 task 派发独立 subagent 实施 + 两阶段 review（spec compliance → code quality）。这利用了 "fresh context per task" 避免上下文污染。Baton 在 baton-implement 中提到 subagent 并行，但无 review 架构。

4. **反理性化深度**：TDD skill 有 11 条理性化反驳、6 个 `<Good>`/`<Bad>` 内联示例、"Delete means delete" 绝对规则、"spirit vs letter" 封堵。Baton 的反理性化表更短且缺少内联代码示例。

5. **Skill 元技能**：`writing-skills` (656 行) 是 "如何写 skill" 的 skill，包含 TDD 风格的 skill 测试方法论、CSO 优化、反模式列表。Baton 无类似元技能。

### 4.3 planning-with-files 的独特之处

- **"文件即内存"**：Context Window = RAM, Filesystem = Disk。2-Action Rule（每 2 次操作保存发现）防止信息丢失。
- **3-Strike 错误协议**：与 baton 的 "3 次失败停止" 类似，但更结构化（诊断→替代方案→重新思考→升级）。
- **轻量级**：194 行单 skill，无 hook 系统，无审批机制。适合不需要人类深度参与的任务。

### 4.4 HumanLayer RPI — Baton 的最近亲（新发现）

HumanLayer 的 Research-Plan-Implement (RPI) 框架是社区中**与 baton 哲学最接近**的系统，由 Dex Horthy 创建。

| 维度 | Baton | HumanLayer RPI |
|------|-------|----------------|
| **核心流程** | research → plan → 批注循环 → implement | research → plan → implement |
| **人类门控** | BATON:GO 标记 | plan.md 人类审阅（无标记机制） |
| **上下文管理** | 批注协议 + 复杂度校准 | "无情上下文重置" + 40-60% 利用率目标 |
| **证据标准** | file:line 引用 | 压缩摘要（compacted summaries） |
| **反馈机制** | 6 种结构化批注 | 直接编辑 plan.md |
| **实施结果** | ❓ 未公布 | ✅ 32 文件跨 10 阶段变更，零 review 评论 |

**RPI 的 "Dumb Zone" 概念**：当 context 利用率超过 40% 时，agent 性能开始退化。RPI 通过 subagent 隔离将 "noisy" 操作（glob/grep/read）放在独立上下文中，只返回压缩摘要。

**关键差异**：
- ✅ RPI 有**量化的生产结果**（32 文件变更，build 通过，零 review 评论）。Baton 缺少公开的效果数据。
- ✅ RPI 的 "Dumb Zone" 上下文管理理论是 baton 缺失的维度。Baton 有 pre-compact.sh 保存进度，但没有**主动上下文预算管理**。
- ❌ RPI **没有结构化批注协议**——人类直接编辑 plan.md，无类型化反馈。
- ❌ RPI **没有 hook 强制门控**——审阅完全自愿。
- ❌ RPI **没有证据标准**——不要求 file:line 引用。

**Block/Goose 采纳 RPI**：Block（Square 母公司）的开源 AI agent Goose 将 RPI 实现为原生 slash command：`/research_codebase`, `/create_plan`, `/implement_plan`。这是 RPI 在生产环境的最大规模验证。

### 4.5 tdd-guard — Hook 门控的另一实现（新发现）

nizos/tdd-guard 通过 Claude Code hooks 自动化 TDD 强制：**如果没有失败测试，阻止实现代码写入**。支持 Jest, Vitest, pytest, PHPUnit, Go, Rust。可通过 Homebrew 安装。

**与 baton write-lock 的对比**：
- **相同点**：都通过 hook 的 exit code 阻止写入（不是 prompt 纪律）
- **不同点**：tdd-guard 检查的是"是否有失败测试"，baton 检查的是"plan.md 是否有 BATON:GO"
- **互补性**：理论上可以同时使用——baton 确保有审批的 plan，tdd-guard 确保有失败的测试

这证明了 baton 的 hook 门控思路**不是孤例**——社区中存在其他通过 hook 强制工程纪律的项目，但只有 baton 将其用于**人类审批门控**。

### 4.6 BMAD Method — 重量级对比

BMAD (Build More Architect Dreams) 使用 21 个专用 agent（Business Analyst, Product Manager, System Architect, Scrum Master, Developer, UX Designer 等）模拟完整敏捷团队。核心技术是 "document sharding"——将项目文档拆成原子级、AI 可消化的片段。

**与 baton 的关键差异**：
- BMAD 模拟**团队流程**（多角色），baton 模拟**双人协作**（人+AI）
- BMAD 依赖 agent 间协调，baton 依赖人机批注
- BMAD 更适合大型项目初始化，baton 更适合**日常开发**中的持续协作

### 4.7 社区全景统计（新发现）

| 类别 | 数量 |
|------|------|
| Anthropic 官方资源 | 3 |
| Awesome 策展列表 | 7+ |
| Skill 市场/目录 | 6（SkillsMP 聚合 40 万+ skills） |
| 完整交付流程仓库 | 4 |
| 有主见的框架 | 5+ |
| HITL 工作流系统 | 5（含 Atlassian HULA） |
| 跨工具规则系统 | 5（Cursor Rules, Windsurf, Cline, Aider, Copilot） |
| agentskills.io 采纳平台 | 26+（含 Microsoft, OpenAI, Atlassian, GitHub） |

**社区规模结论**：截至 2026 年 3 月，SkillsMP 聚合 40 万+ agent skills。agentskills.io 标准被 26+ 平台采纳。在这个生态中，baton 的独特定位是**唯一将 hook 强制门控 + 结构化人类批注 + file:line 证据标准三者结合**的系统。

### 4.8 根本哲学分歧（更新）

```
Superpowers 问：如何让 AI 自主做出高质量的工程决策？
  → 答案：TDD 纪律 + Code Review + 方法论 skills

Baton 问：如何确保 AI 的决策经过人类验证且有据可查？
  → 答案：证据标准 + 批注协议 + 门控机制

HumanLayer RPI 问：如何在有限上下文中最大化 agent 产出？
  → 答案：无情上下文重置 + subagent 隔离 + 40-60% 利用率

planning-with-files 问：如何让 AI 在长任务中不丢失上下文？
  → 答案：文件系统作为持久化记忆

BMAD 问：如何让 AI 模拟完整的敏捷团队？
  → 答案：21 角色 agent + document sharding
```

**这些问题不矛盾，而是互补的。** 社区正在从不同角度解决 AI 辅助编程的不同子问题：

| 系统 | 解决的核心问题 | 独特机制 |
|------|---------------|---------|
| Baton | 信任建立 | 人类批注 + 证据标准 + hook 门控 |
| Superpowers | 执行质量 | TDD 纪律 + 反理性化 + code review |
| HumanLayer RPI | 上下文效率 | Dumb Zone + subagent 隔离 |
| planning-with-files | 状态管理 | 文件即内存 |
| tdd-guard | TDD 强制 | Hook 门控（与 baton 同思路） |
| BMAD | 团队模拟 | 21 角色 agent 编排 |

---

## Self-Review

1. **批评者会首先质疑什么**："HumanLayer RPI 才是最接近 baton 的系统，为什么主对比仍以 superpowers 为主？" — RPI 与 baton 在哲学上最接近（research→plan→implement + 人类审阅），但 RPI 的 skill/hook 实现细节未公开（主要是方法论文章），无法做 baton-research 级别的 file:line 代码对比。Superpowers 有完整的 SKILL.md 源码，可以逐行比较。两者对标的维度不同：RPI 对标流程哲学，superpowers 对标 skill 实现。

2. **最弱的结论**：维度 5 "反理性化设计" 中对效果的判断缺少实证。所有系统都声称反理性化有效，但无量化 A/B 测试数据。RPI 有生产结果（32 文件变更），但无法归因于具体的设计选择。Superpowers 的 writing-skills 描述了 skill 测试方法论，但未公布结果。Baton 也未做过基线测试。

3. **如果进一步调查会改变什么**：
   - 深入研究 HumanLayer RPI 的 "Dumb Zone" 上下文管理——baton 是否应该引入类似的上下文预算机制
   - 测试 tdd-guard + baton write-lock 的共存兼容性——两个 hook 门控能否协同工作
   - Clone levnikolaevich 仓库，分析其 109 skill 的实际质量
   - 在 agentskills.io 标准上分析 baton 的合规度——特别是 hook 机制是否可标准化
   - 比较 Atlassian HULA 的学术 HITL 框架（~900 PRs）与 baton 的设计差异

## Questions for Human Judgment

1. **是否应该引入 superpowers 的领域 skills？** Baton 目前只有流程 skills（research/plan/implement），没有方法论 skills（TDD/debug/code review）。是否应该创建 baton 版本的这些 skills，还是直接依赖 superpowers plugin 作为补充？这决定了 baton 的定位是 "完整工作流" 还是 "核心门控+协议"。

2. **Baton 的独特价值（人类批注+证据标准+门控）是否值得向 agentskills.io 标准推广？** 当前 agentskills.io 只定义格式，不涉及门控或证据要求。如果 baton 的模式被标准化，可能改变整个社区的 AI 治理实践。这需要判断社区是否 ready 接受这种级别的 AI 约束。

3. **Superpowers 的 skill 链式调用（`REQUIRED SUB-SKILL`）是否应该被 baton 采纳？** 当前 baton skills 之间无显式依赖。引入跨引用可能让 baton skills 组合更灵活（如 baton-plan 完成后自动提示 baton-implement），但也增加了 token 消耗和复杂度。

---

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注 -->
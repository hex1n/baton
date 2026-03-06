# Plan: Baton Skill 化——将阶段指导转为 Claude Code Skills

> 基于 research-skill-conflicts.md / research-skill-conflicts-review.md / research-skill-conflicts-solution.md 的分析
> 核心思路转变：不对抗 skill 系统，加入它

## 复杂度：Medium

涉及 Baton 的架构变化（从指令注入 → skill 化），需要 spike 验证 plugin 机制，改动 4-6 文件。

## 问题回顾

Baton 和 Superpowers skills 冲突的根因：两套系统都试图拥有工作流编排权。

之前探索过的方案及其局限：

| 方案 | 核心思路 | 局限 |
|------|---------|------|
| Path C 三层防御 | 指令层分类 + 路由 + 控制点防御 | 依赖指令优先级，AI 可能不听 |
| solution.md 单编排层 | skill 分类 + phase 矩阵 + Markdown 白名单 | 仍在对抗 skill 系统，规则复杂 |
| skill-guard.sh hook 拦截 | PreToolUse 拦截 Skill tool | 硬拦截但需验证可行性，且会阻断有用 skill |
| 最简方案 | 2 个 hook 改动 + 1 条指令 | 仍在对抗 |

**所有方案的共同问题：都在跟 skill 系统对抗。**

## 新方案：Baton 自身 Skill 化

### 核心洞察

using-superpowers 说："1% chance → MUST invoke skill"。
如果 Baton 的阶段指导本身就是 skill，这条规则就从阻力变成助力——每个任务都 100% 需要 Baton 的阶段指导，所以 Baton skills 永远是"最该被调用的 skill"。

**不是对抗，是加入。不是禁止，是替代。**

### 第一性原理：哪些阶段天然适合 skill 化

| 阶段 | 本质 | 适合做 skill | 理由 |
|------|------|-------------|------|
| RESEARCH | 调查方法论 | **是** | "怎么调查代码"是可复用能力：入口点识别、调用链追踪、证据标准、文档工具清单 |
| PLAN | 决策框架 | **是** | "怎么从研究推导方案"是可教方法论：约束提取、多方案对比、风险分析 |
| ANNOTATION | 对话协议 | **否（拆分）** | 响应式协议（收到标注 → 回应），没有主动触发时机。且贯穿 research 和 plan 两个阶段 |
| IMPLEMENT | 执行纪律 | **是** | "怎么有纪律地实施变更"：自检触发、依赖排序、意外发现处理 |

**ANNOTATION 不独立成 skill，拆入 research 和 plan：**
- `baton:research` 包含研究阶段的 annotation 行为（如何处理 [DEEPER]、[MISSING]、[RESEARCH-GAP]）
- `baton:plan` 包含计划阶段的 annotation 行为（如何处理 [CHANGE]、[Q]、[NOTE]）
- 4 skill → **3 skill**，每个 skill 自包含该阶段需要的 annotation 协议

### Skill 化对 baton 质量的要求

Skill 化后 baton 不再靠权威（CLAUDE.md 优先级 + hook 硬门）压制其他 skill，必须**靠质量赢**。

每个 baton skill 必须比 superpowers 的替代品更好：

| baton skill | 必须比谁好 | baton 的实际优势 |
|-------------|-----------|----------------|
| baton:research | brainstorming | 强制 file:line 证据 + 调用链追踪 + 文档工具清单 + 自我审查。brainstorming 只做表面探索 |
| baton:plan | writing-plans | 人类批注循环 + 多方案对比 + 约束提取。writing-plans 直接跳到精确步骤，跳过 trade-off 分析 |
| baton:implement | executing-plans / subagent-driven-development | 与 plan 的 todo 绑定 + 只改计划列出的文件 + 意外发现须停下。executing-plans 允许自主扩展范围 |

**Baton 的三个竞争优势**（需在 SKILL.md 的 description 和内容中明确表述）：
1. **人类参与**——批注循环是其他 skill 没有的
2. **证据纪律**——file:line 强制引用是其他 skill 没有的
3. **范围约束**——"只改计划列出的文件"是其他 skill 没有的

**对 SKILL.md 内容的要求**：从"你必须做 X"（命令式）升级为"这样做 X 效果更好，因为..."（说服式）。skill 生态中，用户/AI 有选择权，baton 必须说清楚自己为什么更好。

### Skill 化是否削弱深度保障

**担忧**：Baton 存在的理由是 AI 靠自己做不到足够深度。如果 Baton 变成"另一个 skill"，AI 可以表面遵从但实际敷衍，深度保障就没了。

**回答**：Baton 的深度保障从来不是靠指令/skill 单独实现的，而是三层协作：

| 层 | 机制 | skill 化后 |
|----|------|-----------|
| 方法论 | SKILL.md 内容（调用链追踪、file:line、Self-Review） | **变**：从注入 → 按需加载 |
| 硬门 | write-lock.sh、completion-check.sh、pre-commit | **不变** |
| 人类审查 | 批注循环（[DEEPER] [MISSING]）、BATON:GO 手动放置 | **不变** |

即使 AI 对 baton:research 敷衍——写了浅的 research.md：
1. write-lock.sh 阻断代码写入 → 不能跳过研究直接写代码
2. 人类读到浅的研究 → 标注 [DEEPER] → AI 必须重新调查
3. 人类不放 BATON:GO → 永远进不了实施阶段

**这跟今天的 Baton 完全一样。** 今天的指令也是"软"的，AI 也可以敷衍。深度保障来自 hooks + 人类审查，不是来自指令。

**其他 skill 为什么浅？** 不是 SKILL.md 写得差，是没有 hooks 和人类审查兜底。brainstorming 产出设计文档后直接链到 writing-plans → executing-plans → 写代码。中间没有人类审阅点，没有硬门阻断。

**结论**：skill 化改变的是方法论的加载方式（注入 → 按需），不改变深度保障机制（hooks + 人类不变）。

### 架构变化

**现在：**
```
CLAUDE.md → @import workflow.md（~100 行，始终占用 context）
phase-guide.sh → 从 workflow-full.md 提取 → 注入到 session（~50-100 行/阶段）
```

**变成：**
```
CLAUDE.md → @import workflow.md（精简到 ~40-50 行，只剩硬约束）
baton:research   ← [RESEARCH] + ANNOTATION 在研究阶段的协议（按需加载）
baton:plan       ← [PLAN] + ANNOTATION 在计划阶段的协议（按需加载）
baton:implement  ← [IMPLEMENT] 阶段纪律（按需加载）
phase-guide.sh   → 极简化：输出 "📍 IMPLEMENT phase — invoke baton:implement"
```

### 文件结构

```
.baton/
├── hooks/                     ← 现有 hooks 不变
├── workflow.md                ← 精简：只留硬约束
├── workflow-full.md           ← 保留作为 skill 内容的来源/归档
└── plugin/
    ├── .claude-plugin/
    │   └── plugin.json
    └── skills/
        ├── research/
        │   └── SKILL.md       ← [RESEARCH] + ANNOTATION 研究阶段协议
        ├── plan/
        │   └── SKILL.md       ← [PLAN] + ANNOTATION 计划阶段协议
        └── implement/
            └── SKILL.md       ← [IMPLEMENT] 阶段纪律
```

### 每层冲突的解决方式

| 冲突 | 之前的解法 | skill 化解法 |
|------|-----------|-------------|
| writing-plans vs baton 计划流程 | 指令/hook 阻止 writing-plans | AI 调用 `baton:plan`（更具体），自然不选 writing-plans |
| subagent-driven-development vs baton 实施 | 指令/hook 阻止 | AI 调用 `baton:implement`，其中定义 baton 自己的实施纪律 |
| using-superpowers 无条件触发 | 更强措辞对抗 / hook 拦截 | baton skills 被 using-superpowers **主动推荐** |
| 新 skill 冲突 | 控制点防御 / 分类表 | 项目级 skill 天然优先于通用 plugin skill |

### 跨 IDE 设计

Baton 已有三级 IDE 架构（`setup.sh:215-221`）：
- **Tier A** (Claude Code/Factory): slim workflow.md + SessionStart 动态注入
- **Tier B** (Cursor/Cline/Augment/Kiro/Copilot): slim workflow.md + hooks
- **Tier C** (Windsurf/Zed/Codex/Roo): workflow-full.md 静态注入

**SKILL.md 为唯一内容源，workflow-full.md 变为构建产物：**

```
.baton/skills/                     ← 唯一内容源（手工维护）
├── research/SKILL.md
├── plan/SKILL.md
└── implement/SKILL.md

.baton/workflow.md                 ← 硬约束头部（手工维护，~40-50 行）
.baton/workflow-full.md            ← 构建产物（setup.sh 拼接 workflow.md + SKILL.md 生成）
```

**每个 IDE 层级的消费方式：**

| 层级 | 消费方式 | 变化 |
|------|---------|------|
| **Tier A (Claude Code)** | workflow.md via @import + SKILL.md via plugin 按需加载 + phase-guide.sh 提示调用 skill | **新**：plugin 注册 + phase-guide.sh 简化 |
| **Tier B (有 hooks)** | workflow.md + phase-guide.sh 从 SKILL.md 提取当前阶段内容注入 | **改**：数据源从 workflow-full.md 切到 SKILL.md |
| **Tier C (无 hooks)** | 生成的 workflow-full.md 静态注入 | **不变**（只是来源从手写变为生成） |

**SKILL.md 格式：**

```markdown
---
name: baton-research
description: Use when starting any new task that requires code investigation.
  Guides systematic research with file:line evidence, call-chain tracing,
  and structured output reviewed by human annotation cycles.
baton-phase: RESEARCH
---

### [RESEARCH] 阶段指南

[内容]
```

- `name` / `description`：Claude Code 原生字段（skill 发现和匹配）
- `baton-phase`：Baton 自定义字段（phase-guide.sh 定位当前阶段的 SKILL.md）
- `### [RESEARCH]` 标题格式：保持与现有 workflow-full.md 一致，phase-guide.sh 的 extract_section 可直接复用

**phase-guide.sh 变化：**

```
Tier A (有 skill): 输出 "📍 IMPLEMENT phase — invoke baton:implement"
Tier B (有 hooks): 从 SKILL.md 去掉 frontmatter，注入 body
Fallback:          从 workflow-full.md 提取（向后兼容）
```

**关键优势：**
1. 单一内容源——消除 workflow.md / workflow-full.md 手动同步问题
2. Claude Code 原生 skill 体验
3. 非 Claude Code IDE 无感知——消费的是生成的 workflow-full.md 或注入的 SKILL.md body
4. 渐进式迁移——workflow-full.md 作为构建产物继续存在，现有测试和 adapter 不受影响

### workflow.md 硬约束保底

在 Action Boundaries 新增第 10 条：

> 10. 进入任何阶段前，先检查是否有对应的 baton skill（baton:research / baton:plan / baton:implement）。如有，优先调用。

通过 CLAUDE.md @import 始终可见，是 skill 选择的保险丝。

### workflow.md 瘦身

移除阶段指导后，workflow.md 只保留跨阶段硬约束：

- **Mindset**（3 原则）
- **Flow**（Scenario A/B 概述）
- **Complexity Calibration**（4 级）
- **Action Boundaries**（9 条硬规则 + BATON:GO）
- **Evidence Standards**
- **File Conventions**
- **Session Handoff**

预计 ~40-50 行。阶段指导（Annotation Protocol 详细流程、Research 策略、Plan 分析方法、Implement 自检）全部移入对应 skill。

### SKILL.md 格式

```markdown
---
name: baton-research
description: Use when starting any new task that requires investigation. Guides systematic research with file:line evidence standards, call-chain tracing, and structured output.
---

[从 workflow-full.md [RESEARCH] 节提取的内容]
```

AI 根据 description 判断是否触发。Baton skills 的 description 比 superpowers 的通用 skill 更匹配项目上下文，自然优先。

## 优势

1. **零对抗**——不需要"阻断""禁止""覆盖"。Baton 是更好的 skill，不需要压制别人
2. **Context 更高效**——阶段指导从常驻 ~100 行变为按需加载。CLAUDE.md 的 context 开销降低 ~50%
3. **phase-guide.sh 极大简化**——从提取注入 50-100 行文本变为输出一行提示
4. **自然兼容 skill 生态**——Baton 成为 skill 生态的一员
5. **现有 hooks 不动**——write-lock.sh、completion-check.sh 等硬门保持不变，继续提供文件系统级保障

## 需要 Spike 验证的问题

1. **plugin 注册机制**——setup.sh 怎么让 Claude Code 发现 `.baton/plugin/`？需要验证 `--plugin-dir` 或 settings.json 注册方式
2. **项目级 skill vs plugin skill 优先级**——baton skills 是否天然优先于 superpowers 的通用 skill？
3. **phase-guide.sh 的新角色**——继续做阶段检测并提示调用哪个 baton skill，还是完全交给 AI 自行判断？
4. **skill 间互斥**——baton:plan 能否在 SKILL.md 中声明"与 writing-plans 互斥"？
5. **非 Claude Code IDE 的影响**——skill 化只适用于支持 skill 系统的 IDE。Cursor/Windsurf 等仍需 workflow-full.md 注入方式（现有 adapter 机制不变）

## 风险

1. **plugin 机制限制**：如果 Claude Code 不支持项目级 plugin 注册（只支持全局 `--plugin-dir`），setup.sh 的安装流程需要调整
   - 缓解：先做 spike 验证
2. **skill 优先级不可控**：如果 AI 仍然选择 writing-plans 而非 baton:plan
   - 缓解：在 baton skill 的 description 中加入项目名称或具体匹配词，提高相关性
   - 兜底：workflow.md 的 Action Boundaries 仍然通过 CLAUDE.md @import 始终可见，硬约束不丢失
3. **多 IDE 支持分化**：skill 化只适用于 Claude Code 生态
   - 缓解：非 skill IDE 继续使用 workflow-full.md 注入（现有机制，不受影响）

## 实施路径

### Phase 1: Spike（验证可行性）

创建最小 baton plugin，验证：
- skill 发现和加载
- skill 触发条件
- 与 superpowers skills 的共存行为

### Phase 2: 实施（Spike 通过后）

- 从 workflow-full.md 提取 3 个 SKILL.md（research / plan / implement），ANNOTATION 协议拆入 research 和 plan
- 精简 workflow.md（移除阶段指导，保留硬约束，新增 Action Boundaries #10）
- 简化 phase-guide.sh（从注入文本 → 提示调用 baton skill）
- 更新 setup.sh（plugin 注册 + SKILL.md → workflow-full.md 拼接逻辑）
- 更新测试

### Phase 3: 验证

- 在实际任务中测试（Medium 级以上）
- 观察 AI 是否自然选择 baton skills 优先于 superpowers skills
- 如果不够，调整 description 或添加兜底机制

## Self-Review

1. **最弱的假设**：AI 会因为 baton skills 更具体而优先调用它们。这取决于 Claude Code 的 skill 匹配算法，需要 spike 验证。
2. **最大的风险**：plugin 注册机制可能不支持项目级安装。如果只能全局安装，Baton 作为"每个项目独立配置"的工具就需要调整模型。
3. **如果 spike 失败**：退回 skill-guard.sh（PreToolUse 拦截 Skill tool）方案，或最简方案（Markdown 白名单 + 一条指令）。这些方案已有完整设计，可以直接实施。

## Annotation Log

### Round 1

**[NOTE] 多 IDE 兼容 + workflow.md 硬约束保底**
"1.最好这套skill可以兼容各类IDE 2.如果AI不选baton的skill，是否可以在workflow.md里加个硬约束"
→ 多 IDE：SKILL.md 作为唯一内容源，setup.sh 为非 skill IDE 拼接生成 workflow-full.md（构建产物而非手写源）
→ 硬约束：Action Boundaries 第 10 条——"进入任何阶段前，先检查是否有 baton skill，如有优先调用"
→ Plan 需更新：涉及文件增加 setup.sh 变更（SKILL.md → workflow-full.md 拼接逻辑）

**[Q] 第一性原理 + skill 质量要求**
"1.从第一性原理分析 把baton原来的各个阶段抽成skill 2.这样对baton自身的skill设计要求更高"
→ 分析：RESEARCH / PLAN / IMPLEMENT 天然适合 skill 化。ANNOTATION 是响应式协议，不适合独立 skill——应拆入 research 和 plan 中。建议 4 skill → 3 skill。
→ 质量要求：skill 化后 baton 必须靠质量赢，不能靠权威。竞争力来自三个特性：人类参与（批注循环）、证据纪律（file:line）、范围约束（只改计划列出的文件）。SKILL.md 的 description 和内容都需要明确表述这些优势。
→ 这对 skill 内容提出更高要求：从"你必须做 X"升级为"这样做 X 效果更好，因为..."
→ 深度保障问题：Baton 的深度从来不是靠指令单独保障，而是 skill（方法论）+ hooks（硬门）+ 人类（批注循环）三层协作。skill 化只改变方法论的加载方式，hooks 和人类审查不变，深度保障不变。其他 skill 浅不是因为 SKILL.md 差，是因为没有 hooks + 人类兜底。
→ 新增 plan 正文 § "Skill 化是否削弱深度保障"

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[CHANGE]` 修改请求
> 确认后在文档中添加 `<!-- BATON:GO -->` 并告诉 AI "generate todolist"
[NOTE]
>  1.最好这套skill可以兼容各类IDE
>  2.如果AI不选baton的skill，是否可以在workflow.md里加个硬约束，必须先看有没有baton的skill，再看加载的其他skill

[Q]
   1.从第一性原理分析 把baton原来的各个阶段抽成skill
   2.这样是其实对baton 自身的skill设计 要求更高 因为本意是 不信任其他skill 因为担心其实skill 设计的不好 比如研究得比较浅等等
[DEEPER]
   baton 如果要做skill 那么如何设计这个skill 让他支持各类IDE
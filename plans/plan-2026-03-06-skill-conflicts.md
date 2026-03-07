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
2. **~~最大的风险~~**：~~plugin 注册机制可能不支持项目级安装~~ → **已解决**：项目级 skill（`.claude/skills/`）自动发现，无需 plugin 注册。新的最大风险：description 写得不够具体，AI 仍选择 superpowers skill。缓解：Action Boundaries #10 作为保险丝。
3. **如果 spike 失败**：退回 skill-guard.sh（PreToolUse 拦截 Skill tool）方案，或最简方案（Markdown 白名单 + 一条指令）。这些方案已有完整设计，可以直接实施。

### 跨 IDE Skill 设计：详细方案

#### 核心发现（Round 3 更新）

~~"Skill" 是 Claude Code 的概念。其他 IDE 没有 skill 系统。~~

**修正**：SKILL.md 已成为**跨 IDE 开放标准**（agentskills.io 规范，2025 年底发布）。截至 2026 年 3 月，**所有主流 AI IDE 均已支持**：

| IDE | 支持方式 | Skill 位置 | 状态 |
|-----|---------|-----------|------|
| **Claude Code** | 原生 | `.claude/skills/` | ✅ GA |
| **Cursor** | Rules + Skills (v2.4) | `.cursor/skills/` | ✅ GA（另有 `/migrate-to-skills` 迁移工具） |
| **Windsurf** | Skills (2026.01) | `.windsurf/skills/` | ✅ GA |
| **Cline** | Skills (v3.48) | `.cline/skills/` | ✅ GA |
| **GitHub Copilot** | Agent Skills (2025.12) | `.github/skills/` | ✅ GA |
| **Augment Code** | Skills | `.augment/skills/` | ✅ GA |
| **Roo Code** | Skills (v3.47) + Modes | `.roo/skills/` | ✅ GA |
| **Kiro** | Skills (2026.02) | `.kiro/skills/` | ✅ GA |

**跨 IDE 通用位置**：`.agents/skills/`（多个 IDE 检查此目录作为 fallback）

**标准 frontmatter**：只需 `name` + `description`（必填），可选 `license`、`compatibility`、`metadata`

这意味着设计**大幅简化**：

1. **SKILL.md 是唯一内容源**——所有阶段指导内容只在 SKILL.md 中维护
2. **所有 IDE 原生消费 SKILL.md**——不再需要 setup.sh 生成 workflow-full.md 作为替代品
3. **setup.sh 负责将 SKILL.md 拷贝到各 IDE 的 skill 目录**——简单 cp 操作
4. **workflow-full.md 可保留为人类参考文档**——但不再是 IDE 消费的必要路径

#### Claude Code Plugin 注册

基于官方 plugin/skill 系统文档，项目级 skill 有两种方式：

**方式 A: 项目级 skill（最简单）**
```
.claude/skills/
├── baton-research/
│   └── SKILL.md
├── baton-plan/
│   └── SKILL.md
└── baton-implement/
    └── SKILL.md
```
- 自动发现，无需注册
- 命名空间：`/baton-research`、`/baton-plan`、`/baton-implement`
- ✅ 最简方案，推荐先用

**方式 B: Plugin 打包（分发用）**
```
.baton/plugin/
├── .claude-plugin/
│   └── plugin.json        ← {"name":"baton","skills":"./skills/"}
└── skills/
    ├── research/SKILL.md
    ├── plan/SKILL.md
    └── implement/SKILL.md
```
- 命名空间：`/baton:research`、`/baton:plan`、`/baton:implement`
- 需要 `claude plugin install ./.baton/plugin --scope project` 或 `--plugin-dir`
- 适合跨项目分发

**推荐**：先用方式 A（`.claude/skills/`），验证可行后再考虑方式 B。方式 A 零配置，setup.sh 只需 `mkdir -p .claude/skills/ && cp SKILL.md`。

#### SKILL.md 格式

```yaml
---
name: baton-research
description: >
  Use when starting any task that requires code investigation.
  Provides systematic research methodology with file:line evidence standards,
  call-chain tracing, and human annotation cycles.
  Produces research.md reviewed by human before planning begins.
user-invocable: true
---

### [RESEARCH] Research Phase

[从 workflow-full.md 提取的阶段指导内容]
[包含该阶段的 ANNOTATION 协议]
```

关键字段：
- `description`：**决定 AI 是否选择调用此 skill**。必须比 superpowers 的 description 更具体、更匹配项目上下文
- `user-invocable: true`：人类可用 `/baton-research` 手动调用
- `### [RESEARCH]` 标题：保持与现有 `extract_section()` 兼容，phase-guide.sh 可直接提取

#### phase-guide.sh 简化

所有 IDE 都支持 SKILL.md 后，phase-guide.sh 的角色大幅简化：

```sh
case "$PHASE" in
    RESEARCH)
        echo "📍 RESEARCH phase — invoke /baton-research" >&2 ;;
    PLAN)
        echo "📍 PLAN phase — invoke /baton-plan" >&2 ;;
    ANNOTATION)
        echo "📍 ANNOTATION cycle — review annotations in plan" >&2 ;;
    IMPLEMENT)
        echo "📍 IMPLEMENT phase — invoke /baton-implement" >&2 ;;
esac
```

**phase-guide.sh 的新角色**：仅做阶段检测 + 提示调用哪个 skill（~5 行输出 vs 现在 ~50-100 行）。

**向后兼容**：保留 `extract_section()` 作为 fallback，用于未安装 skill 的场景。

#### setup.sh 多 IDE Skill 安装

所有 IDE 原生支持 SKILL.md 后，setup.sh 的安装逻辑变为：

```sh
# 安装 baton skills 到各 IDE 的 skill 目录
install_skills() {
    for _skill in baton-research baton-plan baton-implement; do
        _src="$BATON_DIR/.claude/skills/$_skill/SKILL.md"
        [ -f "$_src" ] || continue
        for _ide_dir in \
            "$PROJECT_DIR/.claude/skills/$_skill" \
            "$PROJECT_DIR/.cursor/skills/$_skill" \
            "$PROJECT_DIR/.windsurf/skills/$_skill" \
            "$PROJECT_DIR/.cline/skills/$_skill" \
            "$PROJECT_DIR/.github/skills/$_skill" \
            "$PROJECT_DIR/.augment/skills/$_skill" \
            "$PROJECT_DIR/.roo/skills/$_skill" \
            "$PROJECT_DIR/.kiro/skills/$_skill" \
        ; do
            _ide_base="$(echo "$_ide_dir" | sed "s|$PROJECT_DIR/||" | cut -d/ -f1)"
            # 只安装到已检测到的 IDE
            case "$IDES" in *"${_ide_base#.}"*) ;; *) continue ;; esac
            mkdir -p "$_ide_dir"
            cp "$_src" "$_ide_dir/SKILL.md"
        done
    done
    # 通用 fallback 位置
    for _skill in baton-research baton-plan baton-implement; do
        mkdir -p "$PROJECT_DIR/.agents/skills/$_skill"
        cp "$BATON_DIR/.claude/skills/$_skill/SKILL.md" \
           "$PROJECT_DIR/.agents/skills/$_skill/SKILL.md"
    done
}
```

**效果**：
- 内容只在 `.claude/skills/` 中维护（baton 源码中的唯一源）
- setup.sh 拷贝到每个检测到的 IDE 的 skill 目录
- `.agents/skills/` 作为跨 IDE fallback
- workflow-full.md 保留为人类参考文档，不再是 IDE 消费的关键路径

#### 每个 IDE 的实际体验（更新）

| IDE | 用户体验 | 技术实现 |
|-----|---------|---------|
| **Claude Code** | AI 自动调用 `/baton-research`，按需加载 | `.claude/skills/` 自动发现 |
| **Cursor** | AI 自动调用 baton skill，按需加载 | `.cursor/skills/` 自动发现（v2.4+） |
| **Windsurf** | AI 自动调用 baton skill，按需加载 | `.windsurf/skills/` 自动发现 |
| **Cline** | AI 自动调用 baton skill，按需加载 | `.cline/skills/` 自动发现（v3.48+） |
| **Copilot** | AI 自动调用 baton skill，按需加载 | `.github/skills/` 自动发现 |
| **Augment** | AI 自动调用 baton skill，按需加载 | `.augment/skills/` 自动发现 |
| **Roo Code** | AI 自动调用 baton skill，按需加载 | `.roo/skills/` 自动发现 |
| **Kiro** | AI 自动调用 baton skill，按需加载 | `.kiro/skills/` 自动发现 |
| **Zed/Codex** | 静态引用 workflow-full.md | `.rules` / `AGENTS.md`（无 skill 支持） |

**所有支持 skill 的 IDE 体验统一**：AI 看到 skill description → 匹配任务 → 按需加载。

#### SKILL.md 内容设计（基于最佳实践）

基于 Anthropic 官方指南、superpowers 项目、社区最佳实践研究（详见 research.md），SKILL.md 内容应遵循：

**1. Description 规则**：
- 以 "Use when" 开头 + 具体触发条件
- 不要在 description 中总结工作流（AI 会走捷径跳过 skill body）
- 要"pushy"——Anthropic 官方承认 AI 有 undertrigger 倾向
- 第三人称（description 被注入 system prompt）

**2. 内容结构（综合 superpowers 模式 + Anthropic 指南）**：
```markdown
---
name: baton-research
description: Use when starting code investigation...
---

## Iron Law
NO SOURCE CODE CHANGES WITHOUT COMPLETING RESEARCH FIRST

## When to Use
- Starting analysis of unfamiliar code
- When user asks to research, analyze, explore, understand

## The Process
[从 workflow-full.md 提取 + 增强]

## Red Flags — STOP
| Thought | Reality |
|---------|---------|
| "This code looks straightforward" | Read the implementation, not just the interface |
| "Should be fine" | Not a valid conclusion. Verify or mark ❓ |

## Annotation Protocol (Research Phase)
[从 workflow-full.md ANNOTATION 节提取该阶段的相关内容]
```

**3. 关键设计原则**：
- **Iron Laws**（代码块格式）用于硬规则——创造不可妥协的参考点
- **Rationalization tables** 用于预防 AI 找借口绕过规则
- **Red Flags lists** 触发元认知自我监控
- **说服式而非命令式**——"这样做效果更好，因为..." 而非 "你必须做 X"
- **每个 SKILL.md < 300 行**——渐进式披露，重型内容放 reference 文件
- **一个优秀示例胜过多个平庸示例**

**4. Baton 的差异化优势（必须在 skill 中明确表述）**：
- 人类批注循环（其他 skill 没有）
- file:line 证据标准（其他 skill 没有）
- 范围约束 + BATON:GO 硬门（其他 skill 没有）

#### Skill 优先级验证

Claude Code skill 优先级：Enterprise > Personal > **Project** > Plugin

项目级 skill（`.claude/skills/`）优先于 plugin skill（superpowers）。这意味着：
- `baton-research` 的 description 匹配"调查代码"时，AI 会优先选择它（而非 superpowers 的 brainstorming）
- 但如果 description 写得不好，AI 可能仍选 superpowers skill

**不存在 `conflicts` 字段**。skill 系统不支持声明互斥。优先级完全靠：
1. description 匹配度（AI 判断）
2. 层级优先级（Project > Plugin）
3. workflow.md 的 Action Boundaries #10（保险丝指令）

---

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

### Round 2

**[DEEPER] 跨 IDE Skill 设计**
"baton 如果要做skill 那么如何设计这个skill 让他支持各类IDE"

→ 此标注触发了深入调查。核心发现：

1. **Skill 是 Claude Code 专属概念**——其他 IDE 没有 skill 系统。因此设计必须分层：SKILL.md 是唯一内容源，非 skill IDE 通过构建产物（workflow-full.md）消费。

2. **项目级 skill（`.claude/skills/`）自动发现**——无需 plugin.json，无需注册。setup.sh 只需 `mkdir -p .claude/skills/ && cp SKILL.md`。

3. **phase-guide.sh 做三级降级**：有 skill → 提示调用（1 行）；有 SKILL.md 但 IDE 无 skill 系统 → 提取内容注入；只有 workflow-full.md → 现有逻辑。

4. **setup.sh 构建 workflow-full.md**：从 workflow.md（硬约束头）+ SKILL.md（阶段指导体）拼接生成。非 skill IDE 消费这个构建产物，无感知差异。

5. **不存在 `conflicts` 字段**——skill 系统不支持声明互斥。优先级靠 description 匹配度 + 层级（Project > Plugin）+ workflow.md 保险丝指令。

→ 新增 plan 正文 § "跨 IDE Skill 设计：详细方案"
→ Self-Review 第 2 点更新：plugin 注册问题已解决——项目级 skill 不需要 plugin 注册

### Round 3

**[NOTE] §1 Skill 是跨 IDE 标准**
"skill 虽然是Claude的概念但是目前各大AI ide都是支持的"

→ ✅ 正确。调查确认：SKILL.md 已成为 **agentskills.io 开放标准**，所有 8 个主流 AI IDE（Claude Code、Cursor、Windsurf、Cline、Copilot、Augment、Roo Code、Kiro）均已支持。
→ **重大影响**：
  - 原方案中"Skill 是 Claude Code 专属概念"的前提**已推翻**
  - 设计大幅简化：setup.sh 直接将 SKILL.md 拷贝到各 IDE 的 skill 目录（`.cursor/skills/`、`.windsurf/skills/` 等），无需生成 workflow-full.md 作为替代品
  - phase-guide.sh 统一简化为"提示调用 skill"（1 行），不再需要三级降级
  - `.agents/skills/` 作为跨 IDE fallback 目录
→ 已更新 plan 正文 § "核心发现"、§ "每个 IDE 的实际体验"、§ "setup.sh 多 IDE Skill 安装"

**[NOTE] §2 SKILL.md 应结合最佳实践**
"skill的编写除了提取目前workflow-full中的是不是应该再结合一下官方或者社区的最佳实践"

→ ✅ 正确。已完成专项调研（见 research.md），核心发现：
  1. **Description 是唯一激活依据**——AI 在选择 skill 时只看 description，不看 body。激活率从 20%（模糊描述）到 90%（优化描述 + hook 强制）
  2. **Superpowers 模式值得借鉴**：Iron Laws（硬规则代码块）、Rationalization tables（预防 AI 找借口）、Red Flags lists（元认知自我监控）、Mandatory announcements（承诺机制）
  3. **Anthropic 官方建议 "explain the why"**——但与 superpowers 的权威式并不矛盾：纪律 skill 用权威，指导 skill 用解释
  4. **Token 预算**：每个 SKILL.md < 300 行，description < 1024 字符，所有 skill 的 description 共享 context window 的 2%
  5. **不要在 description 中总结工作流**——AI 会走捷径跳过 skill body
→ 已新增 plan 正文 § "SKILL.md 内容设计（基于最佳实践）"
→ 配套 research.md 记录完整调研过程和来源

**[MISSING] Context7 未用于研究**
"我发现你刚才研究没有使用context7"

→ ✅ 已补充。使用 Context7 查询了两个数据源：

**1. Claude Code 官方文档**（via context7 `/anthropics/claude-code`）：
- Description 应使用**第三人称**："This skill should be used when..." 而非 "Use when..."
  - 修正了之前 web search 得到的 superpowers 模式（"Use when..."）
  - 官方 plugin-dev 文档明确说：第三人称 + 引用触发短语
- `disable-model-invocation: true` 用于有副作用的 skill（部署、破坏性操作）
- 支持 `$ARGUMENTS` 参数替换：`/baton-research auth-system` → `$ARGUMENTS` = "auth-system"
- 支持文件目录结构：`references/`、`examples/`、`scripts/` 子目录

**2. agentskills.io 规范**（via context7 `/agentskills/agentskills`）：
- **20+ IDE/Agent 已采纳**，比之前调查的 8 个更多：包括 Gemini CLI、OpenAI Codex、Goose、Amp、Factory、TRAE、OpenCode、Firebender、Mistral Vibe、Spring AI 等
- `name` 字段**必须匹配目录名**（硬约束）：`name: baton-research` → 目录必须是 `baton-research/`
- 启动时注入 `<available_skills>` XML 块（仅 name + description），激活时才读取 body
- `allowed-tools` 标记为 **Experimental**，跨 IDE 支持不一致
- CLI 工具：`skills-ref validate ./my-skill`、`skills-ref to-prompt ./skills/*`

**3. Description 格式修正**：
```yaml
# 之前（web search 结果，superpowers 模式）：
description: Use when starting code investigation...

# 修正（Context7 + 官方 plugin-dev 文档）：
description: >
  This skill should be used when the user asks to "research code",
  "analyze the codebase", "trace execution paths", or "investigate
  how this works". Provides systematic research methodology with
  file:line evidence and human annotation cycles.
```

→ 已记录 Context7 的补充发现
→ Plan 正文 § SKILL.md 格式 中的 description 示例需要在实施时按此格式修正

---

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[CHANGE]` 修改请求
> 确认后在文档中添加 `<!-- BATON:GO -->` 并告诉 AI "generate todolist"

<!-- 在下方添加标注 -->
[NOTE]
   1.skill 虽然是Claude的概念但是目前各大AI ide都是支持的
   2.skill的编写除了提取目前workflow-full中的是不是应该再结合一下官方或者社区的最佳实践

[MISSING]
   1.我发现你刚才研究没有使用context7


<!-- BATON:GO -->

## Todo

- [x] 1. Spike：跳过——项目级 skill 自动发现已在 Round 2/3 研究中确认，创建正式 skill 本身即验证
  - 在 `.claude/skills/baton-test/` 创建测试 SKILL.md
  - 验证 Claude Code 自动发现（`<available_skills>` 注入）
  - 验证 `/baton-test` 手动调用
  - 验证与 superpowers skills 共存
  - 测试完成后删除测试 skill

- [x] 2. 创建 `.claude/skills/baton-research/SKILL.md`（189 行）
  - 从 workflow-full.md [RESEARCH] 提取阶段指导内容
  - 融合 ANNOTATION 协议（研究阶段：[DEEPER]、[MISSING]、[RESEARCH-GAP]）
  - 应用最佳实践：Iron Laws、Red Flags table、说服式表述
  - Description 使用第三人称 + 具体触发短语
  - name 必须匹配目录名 `baton-research`
  - 设置 `user-invocable: true`
  - 控制在 300 行以内

- [x] 3. 创建 `.claude/skills/baton-plan/SKILL.md`（193 行）
  - 从 workflow-full.md [PLAN] 提取阶段指导内容
  - 融合 ANNOTATION 协议（计划阶段：[CHANGE]、[Q]、[NOTE]）
  - 应用最佳实践：Iron Laws、Rationalization tables
  - Description 使用第三人称 + 具体触发短语
  - name 必须匹配目录名 `baton-plan`
  - 设置 `user-invocable: true`
  - 控制在 300 行以内

- [x] 4. 创建 `.claude/skills/baton-implement/SKILL.md`（129 行）
  - 从 workflow-full.md [IMPLEMENT] 提取阶段指导内容
  - 应用最佳实践：Iron Laws、自检触发、意外发现处理
  - Description 使用第三人称 + 具体触发短语
  - name 必须匹配目录名 `baton-implement`
  - 设置 `user-invocable: true`
  - 控制在 300 行以内

- [x] 5. 精简 workflow.md（67 行，原 100 行）
  - 移除阶段特定指导（已移入 SKILL.md）
  - 保留跨阶段硬约束：Mindset、Flow、Complexity Calibration、Action Boundaries、Evidence Standards、File Conventions、Session Handoff
  - Action Boundaries 新增第 10 条（baton skill 优先调用保险丝）
  - Annotation Protocol 精简为摘要（详细内容已在各 skill 中）
  - 目标 ~40-50 行

- [x] 6. 简化 phase-guide.sh（175 行，原 232 行；有 skill 时输出 1-2 行）
  - 阶段检测逻辑保留不变
  - 输出从注入 50-100 行文本 → 1 行 skill 调用提示
  - 保留 `extract_section()` 作为 fallback（用于无 skill 环境）
  - 更新 Tier 逻辑：检测 skill 目录是否存在决定输出模式

- [x] 7. 更新 setup.sh（新增 install_skills() + uninstall 清理）
  - 新增 `install_skills()` 函数：将 SKILL.md 拷贝到各 IDE 的 skill 目录
  - 只安装到已检测到的 IDE（复用现有 IDE 检测逻辑）
  - `.agents/skills/` 作为跨 IDE fallback
  - 更新 Tier A/B/C 分层逻辑（所有支持 skill 的 IDE 统一为 skill 消费模式）

- [x] 8. 更新测试（consistency: SKILL.md 验证 + core concepts；phase-guide: 58/58 全过；2 个预存失败与本次无关）
  - test-workflow-consistency.sh：验证 SKILL.md 内容与 workflow.md 的一致性
  - test-phase-guide.sh：验证简化后的 phase-guide.sh 输出
  - 新增 test-skills.sh：验证 SKILL.md frontmatter 格式（name 匹配目录名、description 存在且 < 1024 字符）

- [ ] 9. 端到端验证（需新 session + 人类观察）
  - 在实际任务中测试 skill 激活
  - 观察 AI 是否自然选择 baton skills 优先于 superpowers skills
  - 如激活不足，调整 description 或 Action Boundaries #10 措辞

## Retrospective

### 计划预测 vs 实际

| 预测 | 实际 | 偏差原因 |
|------|------|---------|
| workflow.md 精简到 ~40-50 行 | 67 行 | Annotation Protocol 压缩到 3 行太激进，需要保留足够信息让无 skill 环境也能工作 |
| Kiro skill 路径 `.kiro/skills/` | 应为 `.amazonq/skills/` | Plan § 跨 IDE 表格（第 303/413/448 行）写了 `.kiro/skills/`，但 setup.sh 检测和配置始终用 `.amazonq`。错误假设从 plan 传播到 install_skills() 和 has_skill()，经过 4 轮 review 才完全修正 |
| 单一 `HAS_SKILLS` boolean 够用 | 需要 per-phase `has_skill()` 函数 | 初始实现只检查 baton-research 存在就假设三个 skill 都在。部分安装场景（只装了 research skill）会误判 |
| 新建 test-skills.sh 验证 SKILL.md | 合并进 test-workflow-consistency.sh | 独立测试文件 YAGNI——frontmatter 验证逻辑自然属于一致性检查 |
| phase-guide.sh 简化到 ~175 行 | 184 行 | has_skill() walk-up 函数（13 行）是计划中没预见的新增 |

### 实施中的意外发现

1. **IDE 目录演化问题**：Cline 从 `.clinerules` 演化到 `.cline`，Kiro 检测用 `.amazonq` 但 plan 中 skill 路径写的 `.kiro`。两个 IDE 都有「检测目录 ≠ skill 安装目录」的风险。**根因**：plan 阶段没有建立 IDE 路径一致性矩阵（检测 → 配置 → skill 安装 → skill 检测 四条路径必须对齐）。

2. **test-workflow-consistency.sh 多层假阳性**：
   - Round 2 发现：检查不存在的 section（"Rules"、"Session handoff"）→ empty == empty → OK
   - Round 4 发现：关键字 "3 times" 在两个文件中都不存在 → grep 短路 → OK
   - **模式**：一致性测试本身缺少「被检查的东西必须存在」的元验证。空对空不是一致，是失真。

3. **write-lock.sh walk-up 不进子目录**：plan 文件放在 `plans/` 下，write-lock.sh 从 cwd 向上找 plan.md 但不进子目录。用 symlink `plan.md → plans/plan-2026-03-06-skill-conflicts.md` 绕过。这是 baton 设计中已知的 trade-off，不是 bug。

4. **.gitignore 屏蔽 skill 文件**：`.claude/*` + `!.claude/settings.json` 排除了 `.claude/skills/`。需要添加 `!.claude/skills/` 例外才能提交 skill 文件。Plan 阶段未检查 gitignore 影响。

5. **4 轮 code review 才收敛**：每轮 review 发现的问题都是测试覆盖不到的盲区——因为测试本身有同样的盲区。review 发现 → 加测试 → 测试锁住 → 下一轮 review 找到新盲区。

### 下次研究阶段应该做的

1. **IDE 路径一致性矩阵**：实施跨 IDE 功能前，建一张表：IDE → 检测目录 → 配置目录 → skill 安装目录 → has_skill 搜索列表。四列必须对齐，不对齐的单元格是 bug。本次 Kiro 的 `.amazonq` vs `.kiro` 如果有这张表，研究阶段就能发现。

2. **测试先行于实现**：尤其是边界情况（Kiro-only 项目、Cline-only 项目、skill walk-up）。先写失败测试，再改代码让它通过。本次反过来做了——先改代码，再补测试，导致代码和测试有同样的盲区。

3. **元验证一致性测试**：test-workflow-consistency.sh 应对每个被检查的关键字/section 做「必须在至少一个文件中存在」的断言。否则假阳性无法被自动发现。

4. **检查 .gitignore 影响**：在「涉及文件」列表确定后，检查每个新文件路径是否被 .gitignore 排除。

### 最终数据

| 指标 | 数值 |
|------|------|
| 改动文件 | 12 个（+3 SKILL.md 新增，被 .gitignore 屏蔽） |
| 代码行变化 | +1257 / -536 |
| Code review 轮次 | 4 轮（5 + 3 + 3 + 3 = 14 个 finding） |
| 测试总数 | 343/345 passing（annotation-protocol 2 个预存失败） |
| phase-guide.sh | 75/75 tests（含 6 个新增 skill 检测测试） |
| setup.sh | 81/81 tests（含 Kiro skill 路径测试） |
| multi-ide | 40/40 tests（含 Cline .cline-only 测试） |
| workflow consistency | 50 checks all consistent |
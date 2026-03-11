# Research: Baton 解耦方案 — 社区实践与架构选型

**复杂度**: Large
**前置**: `plans/research-2026-03-11-systemic-coupling.md`（系统级耦合现状诊断，已完成）

## Question

如何解决 Baton 当前的系统级耦合？社区和行业是否有已被验证的模式可以借鉴？哪种方案对 Baton 的具体约束最适用？

## Why It Matters

- [HUMAN] 前一轮研究已确认：Baton 的耦合是规范、运行时、分发、验证四层共同维持的架构现实，不是文案同步问题。
- [HUMAN] 前一轮批注已明确：后续设计不考虑 no-skill 的目标支持面。
- 如果不参考行业已验证的解法，下一份 plan 很可能只做"删重复内容"的局部优化，而不是解决结构根因。
- 如果选错了解耦模式（比如用 symlink 解决 authority 分工问题），会浪费实施周期。

## Scope

- 调查 AI coding agent 配置文件生态的当前实践（AGENTS.md / CLAUDE.md / .cursor/rules / 跨工具协调）
- 调查行业经典的"单源多面"模式（OpenAPI codegen / protobuf / Design Tokens / IaC / Helm-Kustomize / monorepo config / doc generation）
- 分析 Baton 当前 setup.sh 的 source→transformation→output 完整链路
- 基于以上三个维度，提出具体的解耦方案并评估适用度
- 回答：哪些耦合可以通过生成消除、哪些需要 authority 决策、哪些是不可避免的产品复杂度

## Out Of Scope

- 不提出最终实现 diff 或修改源码
- 不覆盖 Baton 与 superpowers 的 interop 问题（那是另一个研究方向）
- 不评估 Baton 是否应该存在多 IDE 支持（这是产品决策，不是技术研究）

## Known Constraints

- [CODE] 当前 `setup.sh` 几乎全是 verbatim copy，唯一的真正 transformation 是 Cursor `.mdc` 的 frontmatter 封装。[CODE] `setup.sh:978-985`
- [CODE] `workflow-full.md` 是运行时 fallback 输入，不是纯参考文档。[CODE] `.baton/hooks/phase-guide.sh:73`, `:90`, `:109`, `:127`
- [CODE] 测试套件绝大多数是"多源必须匹配"守卫，不是"source matches output"验证。[CODE] `tests/test-workflow-consistency.sh:18-30`, `:103-125`, `:166-179`
- [HUMAN] no-skill fallback 不是后续目标约束。

## Tool Inventory

- Web search: 社区实践调查（AGENTS.md 生态、CLAUDE.md 模式、跨工具协调方案、行业 single-source 模式）
- `rg -n` + `Read`: 验证 Baton 当前的 source→output 链路，分析 setup.sh 的投影机制
- Counterexample analysis: 对每个候选方案评估"为什么对 Baton 不适用"

---

## Part 1: AI Coding Agent 配置生态现状

### 1.1 碎片化格局

**Facts**:

- [DOC] AGENTS.md 于 2025-08 由 OpenAI 发布，2025-12-09 捐赠给 Linux Foundation AAIF（Agentic AI Foundation），由 Anthropic、Block、OpenAI 联合创立。截至 2026-03，60,000+ 开源项目采用。[DOC] [Linux Foundation AAIF Announcement](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation) [DOC] [agents.md](https://agents.md/)
- [DOC] 原生支持 AGENTS.md 的工具：OpenAI Codex、GitHub Copilot（2025-08-28）、Google Jules、Gemini CLI、Sourcegraph Amp、Cursor（1.6+）、VS Code、Zed、Warp、Factory、Windsurf、OpenCode。[DOC] [GitHub Copilot AGENTS.md Changelog](https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/)
- [DOC] Claude Code 是目前最大的未支持者——issue #6235 有 3,154+ upvotes，PR #29835 仍 open。[DOC] [Claude Code Issue #6235](https://github.com/anthropics/claude-code/issues/6235)
- [DOC] 每个工具有自己的格式：CLAUDE.md、AGENTS.md、.cursor/rules/*.mdc（含 YAML frontmatter）、.windsurfrules、.github/copilot-instructions.md、GEMINI.md、.clinerules/、.junie/guidelines.md、.continue/rules/。[DOC] [EveryDev.ai Fragmentation Analysis](https://www.everydev.ai/p/blog-ai-coding-agent-rules-files-fragmentation-formats-and-the-push-to-standardize)

### 1.2 社区已有的三种跨工具协调方案

**Facts**:

**方案 A — 符号链接（零工具）**:
- `ln -s AGENTS.md CLAUDE.md`，文件系统级 single source。
- [DOC] 已被 claudekit、cqframework/clinical-reasoning 使用。openai/openai-agents-python 有 PR #965 尝试但未合并。[DOC] [Kaushik Gopal: Keep AGENTS.md in sync](https://kau.sh/blog/agents-md/)
- 局限：Cursor .mdc 需要 YAML frontmatter（globs, alwaysApply），无法用 symlink 表达。

**方案 B — @import 指针（Claude Code 原生）**:
- CLAUDE.md 里只写 `@AGENTS.md`，利用 Claude Code 的递归 import 机制（最多 5 层）。
- [DOC] 这是 issue #6235 里最高票的 workaround（312+ upvotes）。OpenCode 实现了 AGENTS.md-first、CLAUDE.md-fallback 的自动发现。[DOC] [Claude Code Memory Docs](https://code.claude.com/docs/en/memory) [DOC] [OpenCode Rules Docs](https://opencode.ai/docs/rules/)
- 局限：仅 Claude Code 支持 `@import`；其他工具不读。

**方案 C — Build-step 生成（工具链驱动）**:
- [DOC] `faf-cli`：读 `.faf` YAML（IANA 注册的 `application/vnd.faf+yaml`）→ 生成 CLAUDE.md、AGENTS.md、.cursorrules、GEMINI.md。`npm i -g faf-cli && faf bi-sync --all`。[DOC] [DEV.to faf-cli Article](https://dev.to/wolfejam/define-your-project-once-generate-agentsmd-cursorrules-claudemd-geminimd-bc3)
- [DOC] `rulebook-ai`：定义 Packs（rules + memory + tools）→ `rulebook-ai project sync` → 生成 9+ 工具的规则文件。生成产物 gitignored，源文件 committed。[DOC] [rulebook-ai GitHub](https://github.com/botingw/rulebook-ai)
- [DOC] `snowdreamtech/template`：`.agent/rules/` 目录存放 80+ 规则文件 → 50+ IDE 目录通过 symlinks 连接。[DOC] [snowdreamtech/template](https://github.com/snowdreamtech/template)
- [DOC] `rule-porter`：读 `.cursor/rules/` → 转换为 AGENTS.md / CLAUDE.md / copilot-instructions.md。Cursor frontmatter 的 glob/alwaysApply 在目标格式中无法表达，以注释保留。[DOC] [rule-porter Cursor Forum](https://forum.cursor.com/t/rule-porter-convert-your-mdc-rules-to-claude-md-agents-md-or-copilot/153197)

### 1.3 Inference

社区的三种方案解决的是**不同工具读不同文件格式**的问题。Baton 的问题更深一层：**同一工具内多个内容层次之间的结构性耦合**（slim core vs phase methodology vs fallback reference）。symlink 和 faf-cli 解决不了 `workflow.md` 与 `SKILL.md` 之间的 authority 分工问题。

但有一个重要的生态信号：**AGENTS.md 已成为跨工具通用协议层**。Baton 的 `setup.sh` 对 Claude/Codex 都用 `@.baton/workflow.md` 引用——这已经接近社区最佳实践。

---

## Part 2: 行业经典"单源多面"模式

### 2.1 七种模式的适用性评估

**Facts + Inference**:

| 模式 | 核心机制 | 对 Baton 适用度 | 关键理由 |
|---|---|---|---|
| **OpenAPI codegen** | 一份 spec → CI 生成客户端 + `git diff --exit-code` 漂移检测 | 🟢 高 | CI 漂移检测机制直接可移植到 Baton 测试 |
| **Protocol Buffers** | field number 分离语义契约与表面表示 + `buf breaking` 检测 | 🟡 中 | "规则 ID"概念可借鉴，但 Baton 内容是散文不是 schema |
| **Design Tokens (Style Dictionary)** | token JSON → platform+transform+format → 多平台输出 | 🟢 **最高** | platform/transform/format 三层分离直接映射 Baton 的 IDE/注入方式/内容格式 |
| **Terraform modules** | 参数化模板 + 变量 → 多环境一致输出 + 状态漂移检测 | 🟡 中 | setup.sh 已是 de facto projector；drift 概念适用 |
| **Helm/Kustomize** | base template + per-env overlay | 🟡 中 | per-IDE overlay 模型可用于 setup.sh 重构 |
| **Monorepo 共享配置** | `extends` 继承 + 显式 override | 🟢 高 | skills-as-shared-config 映射自然；"改共享配置自动传播"的保证 |
| **Doc generation** | Markdown → 多格式渲染 | 🔴 低 | Baton 的面不是呈现差异（HTML vs PDF）而是结构差异 |

### 2.2 最匹配的两个模式详解

#### Design Tokens / Style Dictionary 模式

[DOC] Style Dictionary 架构是一个九步管线：解析 → 深度合并所有 token 源 → 对每个 platform 分别运行 transform（修改名称/值适配平台）→ resolve references → apply format（生成平台文件）。[DOC] [Style Dictionary Architecture](https://styledictionary.com/info/architecture/)

**为什么最匹配 Baton**:

Baton 的内容可以分为两种：

1. **Cross-cutting 不变量**（Action Boundaries、Evidence Standards、File Conventions、Session Handoff）：这类似 design token——同一语义内容，需要在每个 surface 以不同格式出现。Style Dictionary 的 platform+transform 直接适用。
2. **Phase-specific 方法论**（Research checklist、Plan annotation protocol、Implementation iron laws）：这不是"共享值"而是"phase-scoped 文档段"，只出现在某些 surface（SKILL.md）和 fallback 形式（workflow-full.md）。

Style Dictionary 的 collision detection（两个源定义同一 token 时报警）也直接映射 Baton 的 `test-workflow-consistency.sh` 功能。区别在于：Style Dictionary 在**生成时**检测冲突，Baton 在**测试时**检测漂移——前者是 proactive，后者是 reactive。

#### OpenAPI Codegen 的 CI 漂移检测模式

[DOC] OpenAPI 生态的标准实践：(1) 开发者只编辑 `.yaml` spec；(2) CI 运行 `openapi-generator-cli` 生成所有目标；(3) CI 运行 `git diff --exit-code`——如果任何生成文件与 committed 版本不一致，构建失败。[DOC] [OpenAPI as Single Source of Truth](https://blog.dochia.dev/blog/openapi-single-source/)

**为什么对 Baton 适用**:

这是最低成本、最高确定性的改造模式。Baton 不需要引入模板引擎或新格式——只需要：
1. 一个 shell 脚本把 canonical sources 组装成 derived outputs
2. CI 检查 `bash generate.sh && git diff --exit-code <derived-files>`

这比手工同步 + 测试守卫更可靠，因为**生成失败是阻断的，测试失败可以被跳过或误读**。

### 2.3 所有成功模式的共同结构

**Inference**:

七个模式里每一个在规模化后成功的，都分离了三个层：

1. **Source**：人类编辑，结构完整，单一 authority
2. **Projection mechanism**：transforms / templates / codegen，人类不编辑
3. **Derived outputs**：人类不编辑，从 source 再生，CI 验证 committed 状态

Baton 当前缺少第 2 层。`setup.sh` 是 de facto projector，但它从**多个 source** 读取。`tests/test-workflow-consistency.sh` 是 de facto drift detector，但它在**事后**检测，不是在**生成时**阻断。

---

## Part 3: Baton 当前的 Source→Output 链路分析

### 3.1 setup.sh 的投影机制

**Facts**:

当前 setup.sh 的所有 source → output 关系：

| Source | Transformation | Output | 类型 |
|---|---|---|---|
| `.baton/hooks/*.sh`（9 files） | verbatim copy（version-checked） | `$PROJECT/.baton/hooks/*.sh` | 原样复制 |
| `.baton/workflow.md` | verbatim copy | `$PROJECT/.baton/workflow.md` | 原样复制 |
| `.baton/workflow-full.md` | verbatim copy | `$PROJECT/.baton/workflow-full.md` | 原样复制 |
| `.claude/skills/*/SKILL.md` | verbatim copy ×3 | `$PROJECT/{.claude,.cursor,.agents}/skills/*/SKILL.md` | 原样复制 |
| `.baton/workflow.md` | **prepend MDC frontmatter** | `$PROJECT/.cursor/rules/baton.mdc` | **唯一的真正 transformation** |
| 硬编码 heredoc | 静态 JSON | `$PROJECT/.claude/settings.json` / `.cursor/hooks.json` / `.codex/hooks.json` | 内联嵌入 |
| 字符串字面量 | `printf '@.baton/workflow.md'` | `$PROJECT/CLAUDE.md` / `$PROJECT/AGENTS.md` | 指针注入 |

[CODE] 唯一的内容 transformation 是 `setup.sh:978-985`：给 `workflow.md` 加 4 行 Cursor MDC frontmatter 头。其余全是 verbatim copy 或静态嵌入。

### 3.2 测试架构：多源同步 vs 源→产物验证

**Facts**:

| 类型 | 数量 | 代表 |
|---|---|---|
| **"多源必须匹配"守卫** | ~15+ 个检查点 | `test-workflow-consistency.sh:18-30`（slim/full 共享章节一致）、`:103-125`（phase-guide 关键词 vs full）、`:166-179`（skills vs full 的 Self-Review）、`:416-432`（canonical/fallback 模型） |
| **"source matches output"验证** | **仅 1 个** | `test-setup.sh:685-693`（`diff -q` 一个 SKILL.md 文件） |

**Inference**:

测试套件压倒性地在做"多源同步"，而不是"单源投影验证"。这意味着：
- 当前架构是 **multi-source + sync**，不是 single-source + projection
- 测试维护成本与源文件数量成**乘法关系**（每加一个同步点，需要 N×M 的校验组合）
- 如果切换到 single-source + generation，大部分 sync 测试可以被一条 `git diff --exit-code` 替代

### 3.3 前一轮研究遗漏的三个精确盲点

**Facts + Inference**（补充前一轮 `research-2026-03-11-systemic-coupling.md`）:

**盲点 1: Self-Review 内容漂移无守卫**
- Self-Review 模板存在于 4 个位置：`workflow-full.md:173-186`、`workflow-full.md:255-271`、`baton-research/SKILL.md:127-143`、`baton-plan/SKILL.md:122-145`
- [CODE] `test-workflow-consistency.sh:172-178` **只检查关键词"Self-Review"是否存在**，不验证内容一致性。
- 四份模板可以各自漂移，测试不会报警。这是**静默漂移风险**，比"同步成本高"更严重。

**盲点 2: Convergence Check 在 fallback 路径中完全缺失**
- [CODE] `Convergence Check` 只存在于 `baton-research/SKILL.md:253`，`workflow-full.md` 的 `[RESEARCH]` 段里没有对应内容。
- 当 skill 不可用、fallback 触发时，AI 完全不会收到这个方法论步骤。
- 这进一步支持"no-skill fallback 不应是目标约束"——不是因为不想支持，而是因为 fallback 内容**已经落后于 skills**。

**盲点 3: Fork context 下的 authority 断裂**
- [CODE] `baton-research/SKILL.md:13` 标记 `context: fork`（以 subagent 形式运行）。
- [CODE] `baton-research/SKILL.md:218` 说跨切面规则"live in `workflow.md` Annotation Protocol and apply here too"。
- [DOC] Anthropic 官方文档明确："subagents don't inherit skills from the parent conversation"。[DOC] [Anthropic Claude Code Docs: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- 这是一个**活跃的 authority 缝隙**：SKILL.md 说"参考 workflow.md"，但在 fork 运行时 workflow.md 可能不在 context 里。

---

## Part 4: 解耦方案

### 4.1 方案概览

基于以上分析，提出两阶段方案：

| 阶段 | 目标 | 借鉴模式 | 改动范围 |
|---|---|---|---|
| **阶段一：Authority 收敛** | "多源同步"→"单源投影" | OpenAPI codegen CI + Monorepo shared config | `workflow-full.md` 降级为生成产物 + 测试重构 |
| **阶段二：Per-IDE 投影显式化** | setup.sh ad-hoc → 声明式 overlay | Style Dictionary platform model + Kustomize | setup.sh 重构 + `.agents` 定位决策 |

### 4.2 阶段一：Authority 收敛（最小改动、最大收益）

**当前状态**:
```
workflow.md ←手工同步→ workflow-full.md ←手工同步→ SKILL.md files
tests 守住同步关系（关键词级，非内容级）
```

**目标状态**:
```
workflow.md ─────── cross-cutting core（手工维护，唯一 authority）
SKILL.md files ──── phase methodology（手工维护，各自独立，per-phase authority）
workflow-full.md ── 从上面两者 **生成**（不再手工维护）
```

**具体做法**:

**1. `workflow-full.md` 降级为生成产物**

新增 `generate-full.sh`（估计 ~80 行）：
- 读取 `workflow.md` 全部内容作为 cross-cutting 段
- 从每个 `SKILL.md` 提取方法论摘要（可以是标记段落，如 `<!-- EXPORT:full -->` ... `<!-- /EXPORT -->`），拼接为对应 phase 的 fallback 正文
- 生成 `Document Authority` 段（或上移到 `workflow.md`）
- 输出完整的 `workflow-full.md`

CI 检查（借鉴 OpenAPI codegen 模式）：
```bash
bash generate-full.sh
git diff --exit-code .baton/workflow-full.md || {
    echo "FAIL: workflow-full.md is stale. Regenerate from sources."
    exit 1
}
```

**为什么这是最有价值的切口**:
- [CODE] `workflow-full.md` 是前一轮研究确认的**耦合枢纽**——同时承担 fallback source + 扩展规范 + 元信息三重角色。[CODE] `.baton/workflow-full.md:108-120`, `.baton/hooks/phase-guide.sh:73-131`
- 生成器是最简单的投影机制（concatenation + section extraction），不需要复杂模板引擎
- 消除的同步面最多：slim/full 共享章节一致、skills/full 方法论重复、Self-Review 4 处→1 处

**2. Skills 成为 phase methodology 的唯一源**

- 这已经是 frontmatter 声称的现实（"authoritative specification"）。[CODE] `.claude/skills/baton-research/SKILL.md:2`, `.claude/skills/baton-plan/SKILL.md:2`
- 但当前 `workflow-full.md` 还独立维护着一份近似的方法论正文。
- 改造后：Self-Review 模板只在 SKILL.md 里维护，`workflow-full.md` 里的版本由生成器从 SKILL.md 提取产出。
- Convergence Check 等只存在于 SKILL.md 的步骤，自然会通过生成器进入 `workflow-full.md` fallback——消除盲点 2。

**3. 测试重构**

- 删除 `test-workflow-consistency.sh` 中 slim/full 手工比对的部分（`:18-30` 共享章节一致、`:103-125` phase-guide 关键词 vs full）——这些由 `generate-full.sh` 保证
- 换成 `git diff --exit-code` 检查 committed 的 `workflow-full.md` 是否与生成结果一致
- 保留 skills 内部的概念/关键词守卫（`:166-179` skills 必须包含 Self-Review 等）——这些仍有独立价值

**4. Document Authority 元信息上移**

- [CODE] 当前 `Document Authority` 在 `workflow-full.md:116-120`，但 `workflow-full.md` 自己在层级中定位最低。
- [CODE] `tests/test-workflow-consistency.sh:502-508` 禁止 `workflow.md` 包含 `Document Authority`。
- 改造方向：把 authority 声明移到 `workflow.md`（它是最高层级文件），或移入独立的 `AUTHORITY.md`。
- 如果移到 `workflow.md`，需要调整测试中的禁止规则。

### 4.3 阶段二：Per-IDE 投影显式化

**当前状态**:
```
setup.sh 里的 per-IDE if/else 分支（ad-hoc，每个 IDE 的逻辑散布在 ~10 个函数中）
.agents/ 事实上是 universal fallback，但标注和测试说"Codex fallback"
```

**目标状态**（借鉴 Style Dictionary platform + Kustomize overlay）:
```
每个 IDE 的差异收敛为 4 个维度的声明：
  - entry: 入口文件路径和注入方式
  - skills_dir: 技能目录
  - hooks: 原生/适配器
  - workflow_inject: @import / embed+mdc
```

**具体做法**:

**1. `.agents/` 定位决策**

需要人类决策。两个选项：

| 选项 | 含义 | 影响 |
|---|---|---|
| **Codex 专属** | `has_skill()` 不再查 `.agents`；仅 Codex 安装时写入 | 简化 `_common.sh`，但需要确认 Factory AI 不依赖它 |
| **通用 fallback** | 保留当前行为，但重命名标注（测试/注释改为"universal fallback"而非"Codex fallback"） | 标注准确化，行为不变 |

当前事实：[CODE] `setup.sh:719-721` 无条件写 `.agents/skills/`；[CODE] `_common.sh:34` 让所有宿主都 fallback 到 `.agents`；但 [CODE] `test-workflow-consistency.sh:427-432` 标注说"Codex fallback"。标注与行为已脱节。

**2. Per-IDE overlay 数据驱动化**

把 `setup.sh` 的 per-IDE 分支重构为声明式数据 + 通用安装函数：

```bash
# 概念示意（不是最终实现）
declare -A IDE_ENTRY=(
    [claude]="CLAUDE.md"
    [cursor]=".cursor/rules/baton.mdc"
    [codex]="AGENTS.md"
)
declare -A IDE_INJECT=(
    [claude]="@import"      # printf '@.baton/workflow.md'
    [cursor]="embed+mdc"    # cat workflow.md with frontmatter
    [codex]="@import"       # printf '@.baton/workflow.md'
)
declare -A IDE_SKILLS=(
    [claude]=".claude/skills"
    [cursor]=".cursor/skills"
    [codex]=".agents/skills"
)
declare -A IDE_HOOKS=(
    [claude]="native"       # .claude/settings.json
    [cursor]="adapter"      # adapter-cursor.sh
    [codex]="adapter"       # adapter-codex.sh
)
```

这使得新增 IDE 支持变成"加一行声明"而不是"在 10 个函数里各加一个 if 分支"。

**3. Fork context authority 缝隙修复**

- [CODE] `baton-research/SKILL.md:13` 标记 `context: fork`，但 `:218` 引用了 `workflow.md` 的 annotation rules。
- 解决方案 A：把 cross-cutting annotation rules 的关键部分内联到 SKILL.md 的 fork 运行段，使 SKILL.md 在 fork 下自足。
- 解决方案 B：通过 subagent 配置确保 `workflow.md` 被显式注入 fork context。
- [DOC] Anthropic 官方建议：subagent 的 skills 需要显式列出，不能依赖隐式继承。[DOC] [Anthropic Claude Code Docs: Create custom subagents](https://code.claude.com/docs/en/sub-agents)

---

## Part 5: 为什么不用社区的其他方案

### 5.1 Counterexample: Symlink 方案

**Claim**: `ln -s AGENTS.md CLAUDE.md` 可以消除 Baton 的入口文件重复。

**反证**:
- Baton 的 CLAUDE.md 和 AGENTS.md 当前内容是 `@.baton/workflow.md`——已经是单行指针，不是重复正文。[CODE] `setup.sh:959-964`, `setup.sh:1051-1056`
- Baton 的核心耦合在 `workflow.md` / `workflow-full.md` / `SKILL.md` 之间，不在入口文件之间。
- Cursor 需要 `.mdc` 格式（YAML frontmatter + Markdown body），不能 symlink 到纯 Markdown。

**Result**: Symlink 不解决 Baton 的实际问题。入口文件不是耦合源。

### 5.2 Counterexample: faf-cli / rulebook-ai 全量生成

**Claim**: 用 faf-cli 或 rulebook-ai 从单一配置生成所有 IDE 文件。

**反证**:
- Baton 的内容不是"IDE 配置片段"，而是包含方法论、阶段指导、Iron Laws 的散文协议。faf-cli 的 `.faf` YAML 不是为承载散文设计的。
- rulebook-ai 的 Pack 概念（rules + memory + tools）更接近，但它的 `sync` 产出是 IDE-specific 规则文件，不是"一个 workflow 协议投影到多个面"。
- 这些工具解决的是**跨工具格式转换**，不是**单协议内多层次内容的 authority 分工**。

**Result**: 外部工具可以辅助 per-IDE 格式适配，但不能替代 Baton 内部的 authority 收敛。

### 5.3 Counterexample: 完全合并为单文件

**Claim**: 把 `workflow.md`、`workflow-full.md`、所有 SKILL.md 合并成一个大文件，消除所有耦合。

**反证**:
- [CODE] `workflow.md` 被设计为 ~400 tokens 的始终加载入口。[CODE] `.baton/workflow-full.md:117`
- Skills 按 phase 分离是有意义的——RESEARCH / PLAN / IMPLEMENT 各自有独立的方法论和 Iron Laws。
- [DOC] Anthropic 官方建议 subagent 应 focused，工具权限最小化。[DOC] [Anthropic Claude Code Docs: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- 合并后 token 开销会从 ~400 暴增到 ~4000+，影响所有会话的 context window。

**Result**: 全量合并与 Baton 的 token-efficient 设计目标矛盾。分层本身是正确的；问题是分层后的 authority 和同步机制。

---

## Findings

### 1. 行业共识：成功的多面架构都有 source → projection → derived output 三层分离

**Fact**: OpenAPI codegen、Protocol Buffers、Design Tokens、Terraform、Helm、monorepo shared config——每个在规模化后成功的模式都区分了"人类编辑的源"和"机器生成的派生产物"。没有成功的模式依赖"多个手工维护的源之间跑测试保同步"。

**Inference**: Baton 当前的"分层 authority + 强同步约束"模型是行业实践中**已知不可扩展**的模式。

**Judgment**: 阶段一应优先引入 projection 层（`generate-full.sh`），把最大的手工同步面（`workflow-full.md`）转为生成产物。

### 2. Baton 的最自然收敛方向是 `workflow.md`（cross-cutting core）+ `SKILL.md`（per-phase authority）双源

**Fact**:
- Skills frontmatter 已声称 authoritative/definitive。[CODE] `.claude/skills/baton-*/SKILL.md:2`
- `workflow-full.md` 自己把 skills 排在自己上面。[CODE] `.baton/workflow-full.md:118`
- 社区信号（Anthropic subagents、OpenAI AGENTS.md）都偏向"一个便携 repo-level context + focused skills"。

**Inference**: Authority 结构已经隐含地收敛了；缺的是把这个隐含结构变成**显式的投影机制**。

### 3. `workflow-full.md` 降级为生成产物是收益最高的切口

**Fact**:
- 它同时承担 fallback runtime source、扩展规范、Document Authority 元信息。
- 它与 `workflow.md` 有 4 个共享章节需手工同步。
- 它与 SKILL.md 有 Self-Review 等方法论内容重复但无内容级校验。
- 把它变成生成产物后，上述三类同步关系全部消除。

**Inference**: 这是单一改动消除最多同步面的切口。

### 4. 测试重构应从"多源同步守卫"转向"生成一致性检查"

**Fact**: 当前 15+ 个测试检查点中，绝大多数是"多源必须匹配"，仅 1 个是"source matches output"。

**Inference**: 引入 `generate-full.sh` 后，`git diff --exit-code` 可以替代大部分 slim/full 同步守卫——更简单、更可靠、维护成本从 O(N²) 降到 O(N)。

### 5. Per-IDE 投影显式化是第二步，不是第一步

**Fact**: setup.sh 的 per-IDE 逻辑虽然 ad-hoc，但功能正确且稳定。改造它的风险高于改造 workflow-full.md。

**Judgment**: 先做阶段一（authority 收敛），验证 generate-full.sh 模式有效后，再用同一模式推广到 setup.sh 的 per-IDE 重构。

---

## Final Conclusions

1. **结论**: 社区的跨工具协调方案（symlink、@import、faf-cli）解决的是格式碎片化，不解决 Baton 的 authority 分工问题。Baton 的问题更深一层。
   - Confidence: high
   - Evidence: `## Part 1`, `§5.1`, `§5.2`
   - Main uncertainty: AGENTS.md 生态演进可能改变跨工具协调的最佳路径
   - Implication: Baton 不能靠换用外部工具来消除内部耦合

2. **结论**: 行业共识是 source → projection → derived output 三层分离。Baton 当前缺少 projection 层。
   - Confidence: high
   - Evidence: `## Part 2` 七种模式的共同结构
   - Main uncertainty: Baton 内容是散文不是 schema，投影机制的保真度需验证
   - Implication: 引入 `generate-full.sh` 是最小成本的 projection 层

3. **结论**: `workflow-full.md` 降级为生成产物是收益最高的切口。
   - Confidence: high
   - Evidence: `## Part 3` source→output 分析 + `§4.2` 方案设计
   - Main uncertainty: fallback 正文从 SKILL.md 提取时，格式/详略转换的具体策略需要 spike 验证
   - Implication: 阶段一 plan 应以此为核心

4. **结论**: 前一轮研究有三个精确盲点：Self-Review 静默漂移、Convergence Check fallback 缺失、fork context authority 断裂。阶段一方案可同时修复前两个。
   - Confidence: high
   - Evidence: `§3.3`
   - Main uncertainty: fork context 修复需要单独决策（内联 vs 显式注入）
   - Implication: 阶段一不只是"消除维护成本"，还修复了当前未被测试覆盖的语义 gap

5. **结论**: 阶段二（per-IDE overlay 显式化 + `.agents` 定位决策）应在阶段一验证后再做。
   - Confidence: medium
   - Evidence: `§4.3`
   - Main uncertainty: 如果 Claude Code 原生支持 AGENTS.md，per-IDE 投影的前提会大幅变化
   - Implication: 阶段二的 plan 应等阶段一完成 + 生态信号更明确后再定

## Self-Review

### Internal Consistency Check

- 本文没有把行业模式当成万能药——每个模式都分析了"为什么对 Baton 适用/不适用"。
- 阶段一方案与前一轮研究的结论一致：`workflow-full.md` 是耦合枢纽 → 降级为生成产物是自然切口。
- 反例扫描排除了三个替代方案（symlink、全量生成、单文件合并），每个都有具体反证。
- 前一轮研究遗漏的三个盲点已被本轮补充并纳入方案设计。

### External Uncertainties

- 一个批判性读者会问：`generate-full.sh` 从 SKILL.md 提取方法论时，如何确保 fallback 正文的详略度适合"无 skill"场景？如果只是机械拼接，fallback 质量可能不如当前手工维护的版本。
  - 应对：需要一个 spike 验证提取策略。但即使 fallback 质量略降，考虑到 no-skill 不是目标约束，这是可接受的 tradeoff。
- 一个批判性读者会问：如果 Claude Code 很快原生支持 AGENTS.md，阶段二的前提会不会完全改变？
  - 应对：是的。这就是为什么建议阶段二等阶段一完成后再定。阶段一（authority 收敛）不受生态变化影响。
- 最弱的结论是"Design Tokens 模式最高适用度"——因为 Baton 的内容是散文，不是结构化 token。适用的是**分层理念**（platform + transform + format），不是具体工具。
- 如果继续调查，最能改变当前分析的是：对 `generate-full.sh` 做一个实际 spike（~2h），验证从 SKILL.md 提取方法论段落拼接成 workflow-full.md 的可行性和质量。

## Questions for Human Judgment

1. `generate-full.sh` 的提取策略：你倾向于 SKILL.md 里用显式标记（`<!-- EXPORT:full -->`）标注哪些段落导出到 full，还是用约定（如"Step N 标题后的第一段"）自动提取？
   → **推荐：显式标记**（见 Annotation Log Round 1）
2. `Document Authority` 元信息：上移到 `workflow.md`，还是独立成 `AUTHORITY.md`，还是保留在 generated `workflow-full.md` 里？
   → **推荐：上移到 workflow.md**（见 Annotation Log Round 1）
3. `.agents/` 定位：Codex 专属，还是通用 fallback？
   → **已决策：通用 fallback**（Round 1 人类确认）
4. Fork context 修复：内联关键 annotation rules 到 SKILL.md（使 fork 自足），还是确保 subagent 配置显式注入 `workflow.md`？
   → **推荐：内联到 SKILL.md**（见 Annotation Log Round 1）
5. 是否先做一个 spike（~2h）验证 `generate-full.sh` 的可行性，还是直接出 plan？
   → 待人类决策

---

## Part 6: 两阶段方案之外的替代方案

（Round 1 批注要求补充）

### 6.1 方案 C：彻底废除 `workflow-full.md`

**思路**：如果 no-skill 不是目标，为什么还要维护 fallback 内容？直接删掉 `workflow-full.md`，让 `phase-guide.sh` 的 fallback 走已有的硬编码摘要。

**Facts**:
- [CODE] `phase-guide.sh:73-77`, `:90-94`, `:109-113`, `:127-132` 的硬编码摘要覆盖了四个阶段，各 3-4 行。
- [CODE] 与 `workflow-full.md` 对应段落相比，硬编码摘要约为完整内容的 **10-15%**：
  - IMPLEMENT：3 行 vs ~38 行（缺 6 个 self-check 触发器、dependency ordering、unexpected discoveries 协议）
  - PLAN：3 行 vs ~73 行（缺 complexity calibration 表、plan 结构模板、archive 规则）
  - RESEARCH：4 行 vs ~84 行（缺 tool inventory 步骤、metacognitive 触发器、call-chain 输出模板）
  - ANNOTATION：3 行 vs ~85 行（缺 Round entry 格式、direction-change 处理、blind-compliance 警告）
- [CODE] `subagent-context.sh` **不注入** `workflow.md` 或 `workflow-full.md`——它只在 IMPLEMENT 阶段注入 todo 进度。[CODE] `.baton/hooks/subagent-context.sh:27-35`

**Inference**:
- 如果 no-skill 不是目标，这是**最简单的方案**——直接删文件，消除所有 slim/full/skills 同步关系。
- 但 fallback 质量会从"完整方法论"降级到"3-4 行提示"。对 medium/large 任务，这种降级在 skill 临时不可用时（IDE 配置错误、新项目未装 skills）可能导致明显的行为退化。

**Judgment**:
- 如果你确信所有目标宿主都能可靠加载 skills，这是最佳方案——零维护成本。
- 如果 skills 加载偶尔失败（新项目、IDE 切换、subagent fork），阶段一（生成 `workflow-full.md`）作为 safety net 更稳健。
- **可以分两步走**：先做阶段一（workflow-full.md 生成化），观察 fallback 实际触发频率；如果很低，后续再彻底废除。

### 6.2 方案 D：Contract-first Schema 验证

**思路**：不做生成，不做同步——定义一个"Baton phase contract"的 schema（JSON/YAML），声明每个 phase 必须包含哪些概念/段落/关键词。然后让每个 surface 独立演化，只要满足 contract 就合格。类似 Protocol Buffers 的 `buf breaking` 检测。

**Facts**:
- [CODE] `test-workflow-consistency.sh` 已经在做一种原始的 contract 验证——检查关键词存在、章节一致、概念覆盖。
- 行业实践中，`buf breaking` 对结构化 schema 很有效，但 Baton 的内容是散文，不是结构化数据。

**Inference**:
- 对于 cross-cutting 不变量（Action Boundaries 等必须完全一致的段落），contract 验证有效。
- 对于 phase methodology（Self-Review 模板等需要内容一致而不只是关键词存在），keyword-level contract **不够**——这正是当前 Self-Review 静默漂移的原因。
- 如果要做 content-level contract，就需要比较完整段落，本质上又回到了"多源同步"模式。

**Judgment**:
- Contract-first 适合作为**补充手段**（验证 skills 包含必要概念），但不能替代"生成产物替代手工同步"的核心改造。
- 当前测试里的关键词/概念守卫可以保留并强化为显式 contract；slim/full 共享章节的全文比对应该被生成机制替代。

### 6.3 方案 E：MCP Server 动态方法论

**思路**：不通过文件分发方法论，而是通过 MCP server 动态提供。IDE 查询 MCP server 获取当前 phase 的方法论，server 是 single source of truth。

**Facts**:
- [CODE] 当前 Baton 没有任何 MCP server 定义。`.claude/settings.json:3` 显式设置 `"ENABLE_CLAUDEAI_MCP_SERVERS": "false"`。
- [DOC] MCP 被 Anthropic、OpenAI、多数 IDE 支持，但各宿主支持深度不一。

**Inference**:
- 这是最"干净"的 single-source 方案——server 就是唯一的 truth。
- 但改造成本极高：需要实现 server、处理离线场景、每个 IDE 的 MCP 集成不同、Codex 对 MCP 的支持有限。
- 当前 Baton 的核心价值之一是**静态文件、零运行时依赖**——MCP 方案会彻底改变这个特性。

**Judgment**:
- 长期方向值得关注（如果 MCP 生态成熟，phase methodology 作为 MCP resource 是自然的演进方向），但当前不适合作为解耦的第一步。

### 6.4 方案 F：Literate Programming — 反转 authority 方向

**思路**：维护一个"master document"（类似 Knuth 的 WEB），包含完整的 Baton 协议。用 tangle 工具从中提取 `workflow.md`（slim 视图）、SKILL.md（per-phase 视图）、`workflow-full.md`（full 视图）。

**Inference**:
- 这与阶段一方案的方向相反：阶段一是"skills → generate full"，方案 F 是"master → generate skills + slim + full"。
- 方案 F 更彻底——消除所有手工维护的面，一切都是投影。
- 但它**违反当前 authority 结构**：skills frontmatter 已声称自己是 authoritative/definitive。如果 skills 变成生成产物，这个声称需要调整。
- 维护成本也更高：master document 会非常大（所有 phase 方法论 + cross-cutting rules + Document Authority），编辑体验差。

**Judgment**:
- 理论上最优（单一源，所有面都是投影），实践上不如阶段一方案（保持 skills 的 authority，只把 workflow-full.md 降级）。
- 如果未来 skills 数量大幅增加（10+ phases），可以重新评估。

### 6.5 方案比较矩阵

| 方案 | 消除的同步面 | 改造成本 | 风险 | 前提 |
|---|---|---|---|---|
| **阶段一：generate-full.sh** | slim/full + skills/full + Self-Review 重复 | 低（~80 行脚本 + 测试改造） | 低 | SKILL.md 加 export 标记 |
| **阶段二：per-IDE overlay** | setup.sh ad-hoc + `.agents` 模糊定位 | 中 | 中 | 阶段一完成 |
| **C：废除 workflow-full.md** | **所有** slim/full/skills 同步 | 最低（删文件 + 改 phase-guide） | 中：skill 不可用时 fallback 降级 | 确信 skills 可靠加载 |
| **D：Contract-first schema** | 不消除，改为 schema 验证 | 中 | 低 | 内容可 schema 化 |
| **E：MCP server** | **所有**文件级同步 | 高（需要 server 实现） | 高：离线、兼容性 | MCP 生态成熟 |
| **F：Literate Programming** | **所有**（一切是投影） | 高（需要 master doc + tangle 工具） | 中：master doc 编辑体验差 | 接受 skills 不再是手工维护 |

**推荐排序**：
1. **阶段一（generate-full.sh）** — 最佳 effort/reward 比，与当前 authority 结构一致
2. **C（废除 workflow-full.md）** — 如果你确信 skills 可靠，这是终极简化
3. **D（Contract-first）作为补充** — 强化现有测试，不替代生成
4. **F / E** — 远期方向，当前不建议

## Direction Reassessment After Round 2

Round 2 人类批注确认：所有目标宿主（Claude Code、Codex、Cursor）都支持 skills。这改变了推荐排序。

### 关键事实

- [CODE] 当 `has_skill` 返回 true 时，`phase-guide.sh` 完全跳过 `extract_section`，不触碰 `workflow-full.md`。fallback 路径被**整体绕过**。[CODE] `.baton/hooks/phase-guide.sh:68-70`, `:86-87`, `:102-104`, `:120-121`
- [CODE] setup.sh 为三个 IDE 都安装 skills：Claude → `.claude/skills/`、Cursor → `.cursor/skills/`、Codex → `.agents/skills/`（universal fallback）。[CODE] `setup.sh:706-720`
- [CODE] `has_skill()` 按 `.claude` → `.cursor` → `.agents` 顺序查找，向上遍历目录树。三个 IDE 都能命中。[CODE] `.baton/hooks/_common.sh:30-42`
- 因此：**在用户的所有目标 IDE 上，`workflow-full.md` 的运行时消费路径永远不会触发**。

### 推荐方向变更

原推荐排序：
1. 阶段一（generate-full.sh）
2. 方案 C（废除 workflow-full.md）

**新推荐排序**：
1. **方案 C（废除 workflow-full.md）** — 所有目标 IDE 支持 skills → workflow-full.md 无运行时消费者 → 直接废除是最简方案
2. 阶段一（generate-full.sh）降级为可选 safety net — 如果用户不确信 skills 始终可靠

理由：阶段一（generate-full.sh）本质是"把 workflow-full.md 从手工维护改为自动生成"。但如果 workflow-full.md 根本没有运行时消费者，生成它的投资回报不如直接废除。

### 方案 C 的精确影响范围

废除 `workflow-full.md` 后需要处理的文件：

| 文件 | 当前依赖 | 处理 |
|---|---|---|
| `phase-guide.sh:20` | `WORKFLOW_FULL=` 赋值 | 删除变量声明 |
| `phase-guide.sh:73,90,109,127` | `extract_section` 调用 | 删除 else 分支（或保留硬编码 fallback） |
| `_common.sh:44-64` | `extract_section()` 函数 | 删除函数（如果不再有调用者） |
| `setup.sh:1216-1219` | `cp workflow-full.md` | 删除复制 |
| `test-workflow-consistency.sh:18-30` | slim/full 共享章节一致 | 删除 |
| `test-workflow-consistency.sh:103-125` | phase-guide 关键词 vs full | 删除 |
| `test-workflow-consistency.sh:166-179` | skills vs full Self-Review | 删除 |
| `test-phase-guide.sh:62-90` | no-skill fallback 正文断言 | 删除或改为硬编码 fallback 断言 |
| `README.md:119-121` | 描述 workflow-full.md 角色 | 更新 |
| `docs/implementation-design.md:21,97-99` | 描述 workflow-full.md | 更新 |

### 保留的 safety net

即使废除 `workflow-full.md`，`phase-guide.sh` 的硬编码 fallback（3-4 行/阶段）仍然存在。这意味着：
- 如果 skills 因某种原因（新项目未装、路径解析 bug、`has_skill` 的 pwd 问题）不可用，AI 仍会收到最低限度的阶段指导
- 只是从"完整方法论 fallback"降级为"骨架 fallback"
- 考虑到 no-skill 不是目标约束，这是可接受的

### 已知风险：`has_skill()` 的 pwd 问题

[CODE] `has_skill()` 使用 `$(pwd)` 而非 `${JSON_CWD:-$(pwd)}`。[CODE] `.baton/hooks/_common.sh:32`
如果 hook 被从非项目根目录调用，可能找不到 skills。这是一个独立的 bug，应在本次改造中修复（1 行改动）。

## Annotation Log

### Round 1

**[inferred: recommendation-request] § Q1 提取策略**
"哪种最优呢?"
→ **推荐：显式标记（`<!-- EXPORT:full -->`）**。理由：
  - 约定式提取（"Step N 标题后第一段"）对 SKILL.md 结构变更脆弱——重构一次就会破坏提取
  - 显式标记让投影意图对 skill 作者可见，类似 OpenAPI 用注解控制 codegen 的输出
  - 标记本身也是文档——阅读 SKILL.md 时能看到"这段会被导出到 workflow-full.md"
  - 标记可以精确控制粒度：某些段落只适合 skill 内部（如 Iron Laws 的详细 rationale），不需要导出到 fallback
→ Consequence: 阶段一 plan 应包含在 SKILL.md 里添加 `<!-- EXPORT:full -->` 标记的步骤
→ Result: recommendation provided, awaiting human confirmation

**[inferred: recommendation-request] § Q2 Document Authority 位置**
"哪种最好呢"
→ **推荐：上移到 workflow.md**。理由：
  - Meta-governance 属于最高 authority 文件，不属于派生产物
  - `workflow.md` 当前 ~400 tokens，加 5 行 authority 声明影响极小（~420 tokens）
  - 独立 `AUTHORITY.md` 增加一个需维护的文件
  - 保留在 generated `workflow-full.md` 里意味着治理规则住在被治理的对象里——架构倒置
  - [CODE] `tests/test-workflow-consistency.sh:502-508` 当前禁止 `workflow.md` 包含 `Document Authority`——需要调整，但这正是本次改造要解决的
→ Consequence: 阶段一 plan 应包含 Document Authority 上移 + 调整对应测试守卫
→ Result: recommendation provided, awaiting human confirmation

**[confirmed: decision] § Q3 `.agents/` 定位**
"通用fallback"
→ 采纳。`.agents/` 继续作为通用 fallback surface。
→ Consequence: 测试/注释中"Codex fallback"标注需要修正为"universal fallback"。`has_skill()` 查 `.agents` 的行为保留。
→ Result: accepted

**[inferred: recommendation-request] § Q4 Fork context 修复**
"最推荐哪种呢"
→ **推荐：内联到 SKILL.md（使 fork 自足）**。理由：
  - [CODE] `subagent-context.sh` 只注入 todo 进度，不注入 `workflow.md`，且**仅在 IMPLEMENT 阶段**生效。[CODE] `.baton/hooks/subagent-context.sh:27`
  - 依赖 subagent 配置显式注入 `workflow.md` 是又一个耦合点——修复耦合不应引入新耦合
  - [DOC] Anthropic 官方建议 subagent 应 self-contained、tools/skills 显式列出。[DOC] [Anthropic Claude Code Docs: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
  - Cross-cutting annotation rules 约 10-15 行，内联成本低
  - 与 SKILL.md "authoritative specification" 自定位一致——authoritative 就应该 self-sufficient
→ Consequence: 阶段一 plan 应包含在 fork-context skills 中内联必要的 annotation rules
→ Result: recommendation provided, awaiting human confirmation

**[inferred: deeper-research] § 其他方案**
"除了上面的2阶段方案 还有其他最佳的实践推荐吗"
→ 已补充 `## Part 6: 两阶段方案之外的替代方案`，包含 4 个替代方案（废除 workflow-full.md、Contract-first schema、MCP server、Literate Programming）及比较矩阵。
→ 最值得关注的替代方案是 **方案 C（彻底废除 workflow-full.md）**——如果确信 skills 可靠加载，它比阶段一更简单。可以作为阶段一之后的自然演进。
→ Result: accepted

### Round 2

**[inferred: context / direction-change-trigger] § 目标 IDE skill 支持**
"skill 我使用claude 和codex 和 cursor 他们都是支持skill的"
→ 验证：[CODE] setup.sh 为三个 IDE 都安装 skills（`:706-720`）。`has_skill()` 按 `.claude` → `.cursor` → `.agents` 查找（`_common.sh:30-42`）。当 skill 存在时 `phase-guide.sh` 完全跳过 `workflow-full.md` fallback。
→ Consequence: **推荐方向变更**——从"阶段一（generate-full.sh）优先"改为"方案 C（废除 workflow-full.md）优先"。已新增 `## Direction Reassessment After Round 2` 详述理由和影响范围。
→ 附带发现：`has_skill()` 有 pwd vs JSON_CWD 不一致 bug（`_common.sh:32`），应在改造中修复。
→ Result: accepted, direction changed

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->
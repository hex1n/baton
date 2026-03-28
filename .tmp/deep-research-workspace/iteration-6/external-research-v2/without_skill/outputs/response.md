# Claude Code Agent Skills vs Cursor Rules: 技能/规则分发机制对比调研

## 调研目标

为 baton 的跨 IDE 适配策略提供决策依据，对比 Claude Code Agent Skills 和 Cursor Rules 在技能/规则分发机制上的架构差异。

---

## 一、格式与结构对比

### 1.1 Claude Code Agent Skills

**文件格式**: `SKILL.md`（YAML frontmatter + Markdown body）

**目录结构**:
```
skill-name/
├── SKILL.md           # 必需：元数据 + 指令
├── scripts/           # 可选：可执行脚本
├── references/        # 可选：参考文档
├── assets/            # 可选：模板、资源
└── ...
```

**Frontmatter 字段**（Claude Code 实现）:

| 字段 | 必需 | 用途 |
|------|------|------|
| `name` | 推荐 | 小写字母+数字+连字符，最长 64 字符，省略时用目录名 |
| `description` | 推荐 | 最长 1024 字符，Claude 据此判断何时激活技能 |
| `disable-model-invocation` | 否 | `true` 阻止 Claude 自动加载，仅允许手动 `/name` 调用 |
| `user-invocable` | 否 | `false` 隐藏在 `/` 菜单中，仅允许 Claude 自动调用 |
| `allowed-tools` | 否 | 限制技能激活时可用的工具集 |
| `model` | 否 | 技能激活时使用的模型 |
| `effort` | 否 | 推理努力等级 (low/medium/high/max) |
| `context` | 否 | 设为 `fork` 在子代理上下文中运行 |
| `agent` | 否 | 当 `context: fork` 时指定子代理类型 |
| `argument-hint` | 否 | 自动补全时显示的参数提示 |
| `hooks` | 否 | 绑定到技能生命周期的 hooks |

**Agent Skills 开放标准**（agentskills.io）的字段更精简：

| 字段 | 必需 | 用途 |
|------|------|------|
| `name` | 是 | 必须与父目录名匹配 |
| `description` | 是 | 描述功能和使用时机 |
| `license` | 否 | 许可证信息 |
| `compatibility` | 否 | 环境要求（最长 500 字符） |
| `metadata` | 否 | 任意键值对 |
| `allowed-tools` | 否 | 预批准工具列表（实验性） |

**关键发现**: Claude Code 在开放标准之上扩展了大量字段（`context`, `agent`, `model`, `effort`, `disable-model-invocation`, `user-invocable`, `hooks`），这些是 Claude Code 私有扩展，不在 agentskills.io 标准中。

### 1.2 Cursor Rules

**文件格式**: `.mdc`（MDC = Markdown Cursor，YAML frontmatter + Markdown body）

**目录结构**:
```
.cursor/
└── rules/
    ├── api-conventions.mdc
    ├── testing.mdc
    └── deployment.mdc
```

**Frontmatter 字段**:

| 字段 | 用途 |
|------|------|
| `description` | 规则用途描述，Agent 据此判断相关性 |
| `globs` | gitignore 风格的路径模式，控制自动附加范围 |
| `alwaysApply` | 布尔值，是否始终应用 |

**四种规则类型**（由 frontmatter 字段组合推断）:

| 类型 | 判定条件 | 行为 |
|------|----------|------|
| **Always** | `alwaysApply: true` | 始终注入每个 prompt |
| **Auto Attached** | 有 `globs` + `alwaysApply: false` | 匹配文件在上下文中时自动附加 |
| **Agent Requested** | 有 `description` + 无 globs + 无 alwaysApply | Agent 根据 description 自主判断是否加载 |
| **Manual** | 无 description + 无 globs + 无 alwaysApply | 仅通过 `@规则名` 手动引用 |

### 1.3 AGENTS.md（跨工具桥接格式）

**格式**: 纯 Markdown，无 frontmatter，无元数据

**特点**:
- 放置在项目根目录或子目录中
- 支持嵌套目录继承（子目录 AGENTS.md 扩展父级而非替换）
- 由 Linux Foundation 旗下 Agentic AI Foundation 治理
- 支持 60k+ 开源项目采用
- Cursor、Codex、Gemini CLI、Jules 等均支持

**局限**: 无任何结构化元数据，无法表达条件激活、工具限制、作用域控制等高级语义。

---

## 二、加载机制对比

### 2.1 Claude Code: 渐进式披露（Progressive Disclosure）

这是 Agent Skills 架构最重要的设计决策：

| 层级 | 加载时机 | token 成本 | 内容 |
|------|----------|-----------|------|
| **L1: 元数据** | 启动时始终加载 | ~100 tokens/skill | frontmatter 的 name + description |
| **L2: 指令** | 技能被触发时 | <5000 tokens | SKILL.md body |
| **L3: 资源** | 按需加载 | 无上限 | scripts/, references/, assets/ 中的文件 |

**加载触发条件**:
- 用户通过 `/skill-name` 主动调用
- Claude 根据 description 匹配判断自动加载
- `disable-model-invocation: true` 的技能不参与自动匹配

**上下文预算**: description 占据动态预算（上下文窗口的 2%，回退值 16,000 字符），通过 `SLASH_COMMAND_TOOL_CHAR_BUDGET` 环境变量可覆盖。

**动态上下文注入**: `` !`command` `` 语法在技能内容发送给 Claude 之前执行 shell 命令，输出替换占位符。

### 2.2 Cursor Rules: 按类型即时注入

Cursor 的加载模型更简单直接：

| 规则类型 | 注入时机 | 注入位置 |
|----------|----------|----------|
| **Always** | 每个 prompt | 模型上下文开头 |
| **Auto Attached** | 匹配文件出现在上下文中时 | 模型上下文开头 |
| **Agent Requested** | Agent 判断相关时 | 动态注入 |
| **Manual** | 用户 `@规则名` 时 | 动态注入 |

**关键区别**: Cursor 没有渐进式披露机制。Always 和 Auto Attached 规则全文注入（非先加载 description 再按需加载 body）。这意味着 Cursor 规则应保持简短，否则浪费上下文窗口。

### 2.3 对比总结

| 维度 | Claude Code Skills | Cursor Rules |
|------|-------------------|--------------|
| **元数据/内容分离** | 是（L1 描述 vs L2 指令） | 否（全文注入或不注入） |
| **上下文效率** | 高（仅加载相关技能全文） | 中（Always 规则始终占据上下文） |
| **条件激活** | description 语义匹配 | globs 路径模式 + description + alwaysApply |
| **文件级作用域** | 无（技能粒度） | 有（globs 精确到文件模式） |
| **动态内容** | 有（!`command` 预处理） | 有（@file 引用） |

---

## 三、作用域与分发机制对比

### 3.1 Claude Code Skills 的分发层级

| 层级 | 路径 | 适用范围 | 分发方式 |
|------|------|----------|----------|
| **Enterprise** | 通过 managed settings | 组织内所有用户 | 管理员通过 dashboard 部署 |
| **Personal** | `~/.claude/skills/<name>/SKILL.md` | 用户所有项目 | 用户本地安装 |
| **Project** | `.claude/skills/<name>/SKILL.md` | 仅当前项目 | git 版本控制分发 |
| **Plugin** | `<plugin>/skills/<name>/SKILL.md` | 插件启用处 | 插件市场/包管理器 |

**优先级**: Enterprise > Personal > Project（同名技能高优先级覆盖低优先级）

**Plugin 命名空间**: 使用 `plugin-name:skill-name` 格式，避免与其他层级冲突。

**Monorepo 支持**: 自动发现嵌套 `.claude/skills/` 目录（如 `packages/frontend/.claude/skills/`）。

**`--add-dir` 支持**: 额外目录中的 skills 自动加载并支持实时变更检测。

### 3.2 Cursor Rules 的分发层级

| 层级 | 位置 | 适用范围 | 分发方式 |
|------|------|----------|----------|
| **Team Rules** | 云端 Dashboard | 团队/组织所有成员 | 管理员通过 web dashboard 配置 |
| **Project Rules** | `.cursor/rules/*.mdc` | 当前项目 | git 版本控制分发 |
| **User Rules** | Cursor Settings 界面 | 用户所有项目 | IDE 设置同步 |

**优先级**: Team Rules > Project Rules > User Rules（所有适用规则合并，高优先级来源优先）

**Team Rules 特性**:
- 管理员可选择 recommend 或 require
- 支持 glob pattern 作用域限制
- 通过 MDM 或 Cursor 云端分发

### 3.3 Cursor Agent Skills 的分发层级（Cursor 2.4+）

Cursor 在 2.4 版本中加入了对 Agent Skills 标准的支持：

| 位置 | 作用域 |
|------|--------|
| `.agents/skills/` | 项目级 |
| `.cursor/skills/` | 项目级 |
| `~/.cursor/skills/` | 用户级（全局） |
| `.claude/skills/` | 向后兼容（项目级） |
| `.codex/skills/` | 向后兼容（项目级） |
| `~/.claude/skills/` | 向后兼容（用户级） |

**重要发现**: Cursor 的 Agent Skills 支持经历了波折。文档早于实现发布，社区反馈实际可用性不稳定。Cursor 2.4 正式发布了 Skills 支持，但实际的跨工具技能发现（如从 `.claude/skills/` 加载）在测试中并不总是可靠。

### 3.4 分发机制对比总结

| 维度 | Claude Code | Cursor |
|------|-------------|--------|
| **版本控制分发** | `.claude/skills/` 提交到 git | `.cursor/rules/` 提交到 git |
| **用户级分发** | `~/.claude/skills/` | Cursor Settings + `~/.cursor/skills/` |
| **组织级分发** | Managed settings (Enterprise) | Team Rules Dashboard (Team/Enterprise) |
| **包管理/市场** | Plugin system + CCPI 包管理器 | 无独立市场（Team Dashboard 作为替代） |
| **跨工具兼容** | Agent Skills 开放标准（16+ 工具采纳） | 私有 `.mdc` 格式 + 新增 Agent Skills 支持 |
| **Monorepo 支持** | 嵌套 `.claude/skills/` 自动发现 | 嵌套 `.cursor/rules/` 自动作用域 |

---

## 四、两套系统的设计哲学差异

### 4.1 Claude Code: "技能即能力"

- **粒度**: 每个 skill 是一个独立目录，包含指令+脚本+资源
- **触发**: 语义匹配（description-based）或显式调用（`/name`）
- **执行**: 可在隔离子代理中运行（`context: fork`）
- **能力模型**: 技能可以携带可执行代码、模板、参考文档
- **设计意图**: 技能是 agent 的"能力包"，类似给新员工的岗位培训手册

### 4.2 Cursor: "规则即约束"

- **粒度**: 每条 rule 是一个 `.mdc` 文件，包含文本指令
- **触发**: 路径模式匹配（globs-based）、始终激活、或 Agent 语义判断
- **执行**: 规则注入 prompt，无独立执行环境
- **能力模型**: 规则是纯文本上下文，无可执行脚本机制（在 Rules 层面）
- **设计意图**: 规则是 IDE 的"编码规范文档"，类似团队的代码风格指南

### 4.3 两者的融合趋势（2026）

Cursor 2.4 加入 Agent Skills 支持后，Cursor 实际上运行两套并行系统：

| 用途 | 推荐机制 |
|------|----------|
| 始终生效的编码规范 | Cursor Rules（`alwaysApply: true`） |
| 文件类型特定规则 | Cursor Rules（globs 匹配） |
| 按需激活的程序性工作流 | Agent Skills（SKILL.md） |
| Agent 自主判断的上下文知识 | 两者均可（Rules 的 Agent Requested 或 Skills 的 description 匹配） |

Cursor 团队在 2.4 release 中明确建议：将 "Apply Intelligently" 类型的动态规则迁移为 Skills（提供 `/migrate-to-skills` 命令），而保留有明确 `globs` 或 `alwaysApply` 的规则。

---

## 五、对 baton 跨 IDE 适配策略的影响分析

### 5.1 baton 当前架构回顾

baton 通过 adapter 层翻译不同 IDE 的 hook 协议：
- **Claude Code**: 直接使用 dispatch.sh → hook scripts（stderr 输出）
- **Cursor**: `adapter.sh` 翻译为 JSON 决策协议（`{"decision":"allow/deny"}`）
- **Codex**: `adapter.sh` 翻译为 stdout 上下文注入

每个 IDE 的 hook 能力不同，baton 已经用 capability tier 标注了这些差异。

### 5.2 分发机制适配的三个层面

#### 层面 A: Hook 分发（baton 当前核心）

这是 baton 已经解决的问题。Hook 通过 junction/symlink 机制分发，adapter 层处理协议翻译。

**当前状态**: 运作良好，但仅覆盖 Claude Code 和 Cursor 的 hook 系统。

#### 层面 B: 规则/知识分发

这是本次调研的核心问题。baton 的 constitution.md 和 phase skills 本质上是"应该在每个会话中生效的规则和知识"。

**现状**:
- Claude Code: 通过 CLAUDE.md 的 `@.baton/constitution.md` 引用加载
- Cursor: 需要等价的 `.cursor/rules/` 规则文件（或 AGENTS.md）
- Codex: 通过 adapter 在 SessionStart 注入

**问题**: baton 的治理内容（constitution、phase skills）目前只有 Claude Code 的原生加载路径，其他 IDE 需要手动维护等价物或依赖 adapter 注入。

#### 层面 C: 技能分发

如果 baton 的 phase skills 未来发展为 Agent Skills 格式，可以利用开放标准的跨工具兼容性。

### 5.3 策略选项分析

#### 选项 1: 继续当前 adapter 架构，按 IDE 维护等价配置

**做法**:
- Claude Code: `.claude/skills/` 放 baton skills, CLAUDE.md 引用 constitution
- Cursor: `.cursor/rules/` 放等价的 `.mdc` 规则，通过 adapter 处理 hooks
- Codex: adapter 层注入

**优点**: 每个 IDE 获得最原生的体验，可利用各 IDE 特有能力（如 Cursor 的 globs 作用域）
**缺点**: 维护成本随 IDE 增加线性增长，规则内容可能不同步

#### 选项 2: Agent Skills 开放标准作为统一格式

**做法**:
- 将 baton 核心治理内容打包为 Agent Skills 格式
- 放在 `.claude/skills/` 中（Cursor 2.4+ 向后兼容读取此路径）
- 利用 Agent Skills 的跨工具兼容性覆盖 16+ 工具

**优点**: 一次编写，多工具生效；符合行业趋势
**缺点**:
- 失去 Cursor Rules 的 globs 文件级作用域能力
- Agent Skills 在 Cursor 中的实际可靠性存疑（社区测试反馈不稳定）
- baton 的 hook 系统（write-lock、bash-guard 等硬门禁）无法通过 Skills 表达

#### 选项 3: 分层策略 — Skills 做知识层，Adapter 做执行层

**做法**:
- **知识层**: 将 constitution.md 和 phase 指南转为 Agent Skills 格式，放在标准位置，利用跨工具兼容性
- **执行层**: hook 系统继续使用 adapter 架构，按 IDE 翻译协议
- **补充层**: 对于 Cursor 特有能力（globs 作用域），通过自动生成 `.cursor/rules/` 中的 `.mdc` 文件来补充

**优点**:
- 知识内容（constitution、phase 指南）天然跨工具
- 执行能力（hooks）保持最大化利用各 IDE 原生能力
- 可以按需为特定 IDE 生成补充配置
**缺点**: 架构复杂度略高，需要区分"知识"和"执行"两类内容

#### 选项 4: AGENTS.md 作为最小公共格式

**做法**:
- 将 baton 治理核心放在 `AGENTS.md`，所有支持此格式的工具自动读取
- 针对 Claude Code 特有能力仍保留 `.claude/skills/` 中的高级技能

**优点**: 最广泛的工具兼容性（60k+ 项目采用），零配置
**缺点**:
- AGENTS.md 是纯 Markdown，无法表达条件激活、工具限制等高级语义
- 与 CLAUDE.md 内容重复/冲突的风险
- 无法利用渐进式披露，所有内容始终加载

### 5.4 推荐策略

**选项 3（分层策略）最符合 baton 的架构哲学**，理由如下：

1. **baton 已经是分层架构**: hooks 是执行层，constitution/phase skills 是知识层，adapter 是翻译层。这个策略是对已有架构的自然延伸而非重构。

2. **Agent Skills 标准正在成为事实标准**: 16+ 工具采纳，Anthropic 发起、Linux Foundation 下的 AGENTS.md 作为补充。押注这个方向的风险较低。

3. **Cursor 的 globs 能力有独特价值**: baton 的 write-lock 机制和 Cursor 的 globs 路径作用域有天然亲和性（限制特定路径的写入），通过自动生成 `.mdc` 规则可以充分利用。

4. **hook 执行层不可能统一**: Claude Code 的 PreToolUse/PostToolUse、Cursor 的 JSON 决策协议、Codex 的 stdout 注入——这些是根本不同的执行模型，adapter 翻译是唯一可行方案。

---

## 六、具体实施路径建议

### Phase 1: 知识层标准化

- 将 `constitution.md` 的核心内容抽取为 Agent Skills 格式
- 放在 `.claude/skills/baton-governance/SKILL.md`（Claude Code 原生 + Cursor 向后兼容）
- Phase skills（research、plan、implement、review）各自独立为技能目录

### Phase 2: Cursor 规则自动生成

- 在 `setup.sh` 中增加 Cursor 规则生成逻辑
- 从 Agent Skills 元数据自动生成等价的 `.cursor/rules/*.mdc` 文件
- 利用 Cursor 的 globs 能力为 write-lock 目标文件生成 Auto Attached 规则

### Phase 3: AGENTS.md 桥接

- 生成一个精简的 `AGENTS.md`，包含 baton 核心治理原则的摘要
- 指向完整的 `.claude/skills/` 技能目录供支持 Agent Skills 的工具深入加载
- 为不支持 Agent Skills 也不支持 CLAUDE.md 的工具提供基本保障

### Phase 4: 分发基础设施

- 考虑将 baton skills 发布为 Claude Code Plugin，利用插件市场分发
- 利用 Agent Skills 的 `compatibility` 字段标注 baton 的环境要求

---

## 七、关键数据点速查表

| 特性 | Claude Code Skills | Cursor Rules | Cursor Skills (2.4+) | AGENTS.md |
|------|-------------------|--------------|----------------------|-----------|
| **格式** | SKILL.md (YAML+MD) | .mdc (YAML+MD) | SKILL.md (YAML+MD) | 纯 Markdown |
| **渐进式披露** | 是 (3层) | 否 | 是 (3层) | 否 |
| **文件级作用域** | 否 | 是 (globs) | 否 | 否（仅目录级） |
| **可执行脚本** | 是 (scripts/) | 否 | 是 (scripts/) | 否 |
| **子代理执行** | 是 (context: fork) | 否 | 待确认 | 否 |
| **组织级分发** | Managed Settings | Team Dashboard | 无 | 无 |
| **包管理/市场** | Plugin system | 无 | 无 | 无 |
| **跨工具兼容** | 16+ 工具 | 仅 Cursor | 16+ 工具 | 60k+ 项目 |
| **条件激活** | description 语义匹配 | globs + alwaysApply + description | description 语义匹配 | 无（始终加载） |
| **开放标准** | agentskills.io | 否 | agentskills.io | agents.md (LF) |

---

## Sources

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Agent Skills - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Agent Skills Specification - agentskills.io](https://agentskills.io/specification)
- [Rules - Cursor Docs](https://cursor.com/docs/context/rules)
- [Agent Skills - Cursor Docs](https://cursor.com/docs/context/skills)
- [Cursor 2.4: Skills Release](https://cursor.com/changelog/2-4)
- [AGENTS.md - Open Format for Coding Agents](https://agents.md/)
- [.cursorrules vs CLAUDE.md vs AGENTS.md - The Prompt Shelf](https://thepromptshelf.dev/blog/cursorrules-vs-claude-md/)
- [Cursor Rules vs Agent Skills: Practical Testing - DEV Community](https://dev.to/nedcodes/cursor-rules-vs-agent-skills-i-tested-both-heres-when-each-one-actually-works-1ld)
- [Skills Support Discussion - Cursor Forum](https://forum.cursor.com/t/is-skills-supported/146837)
- [Cursor 2.4 Skills Discussion - Cursor Forum](https://forum.cursor.com/t/cursor-2-4-skills/149402)
- [Claude Agent Skills: First Principles Deep Dive](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/)
- [Inside Claude Code Skills - Mikhail Shilkov](https://mikhail.io/2025/10/claude-code-skills/)
- [Anthropic: Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [GitHub - anthropics/skills](https://github.com/anthropics/skills)
- [GitHub - agentsmd/agents.md](https://github.com/agentsmd/agents.md)
- [Provision and manage Skills for your organization - Claude Help Center](https://support.claude.com/en/articles/13119606-provision-and-manage-skills-for-your-organization)
- [Skills for enterprise - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise)

---

## 批注区

(reserved for human annotations)

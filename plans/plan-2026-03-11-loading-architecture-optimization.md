# Plan: Baton 加载架构优化 + Codex hooks + annotation 修复

**复杂度**: Medium（workflow.md 增量增强 + Annotation Protocol 三规则同步 + Codex hooks 新能力建设）

**Scope Note (Round 15)**：`Baton × superpowers interop` 已拆分为独立 follow-up plan：`plans/plan-2026-03-11-baton-superpowers-interop.md`。本计划保留并继续聚焦加载架构、Codex hooks、以及 annotation 协议修复。

## Research Source

**注意**：本任务为 Medium 复杂度，按 workflow 规则应产出独立 research.md。当前研究内联在 plan.md 中——这是流程偏差，原因是任务从 Gemini 评审回应开始，研究在批注迭代中有机演进。Change #6a（Codex hook 协议 spike）的结论已记录到独立 `research.md` 中（Gate PASS ✅）。

本轮对话中的 Gemini 评审深度分析 + 批注轮中的架构探索。

### Gemini 评审结论

- **"嵌套循环"和"工具打架"是范畴错误** — Baton 不是另一个 agent，是 instructions + gates。Host IDE 的 agentic loop 是唯一循环，Baton 为这个循环提供指令和门控
- **真正的效率问题**：指令密度、加载策略、架构不透明

### Token 足迹盘点

| 层级 | 来源 | Tokens | 加载时机 |
|------|------|--------|----------|
| Baton always-loaded | workflow.md (84 行) | ~420 | 每个 session，via CLAUDE.md @import |
| superpowers bootstrap | using-superpowers skill (113 行) | ~565 | 每个 session，via 插件 SessionStart hook |
| Baton 阶段技能 | baton-research / baton-plan / baton-implement | 860-1535/个 | 按需，进入阶段时 Skill 调用 |
| Baton fallback | workflow-full.md extract_section 提取 | ~200-400 | 按需，遗留 no-skill fallback；本计划显式不扩展该路径 |

注：superpowers 是独立插件，非 Baton 组件。但两者共存时产生 always-loaded 叠加和功能重叠。

### Baton 与 superpowers 的功能重叠

| 领域 | Baton | Superpowers | 关系 |
|------|-------|-------------|------|
| 规划 | baton-plan | writing-plans | **重叠** — CLAUDE.md 优先级 > superpowers |
| 执行 | baton-implement | executing-plans | **重叠** — 同上 |
| 研究 | baton-research | brainstorming | **部分重叠** |
| TDD | — | test-driven-development | superpowers 独有 |
| 调试 | — | systematic-debugging | superpowers 独有 |
| 代码审查 | — | requesting/receiving-code-review | superpowers 独有 |
| Git 工作流 | — | git-worktrees, finishing-branch | superpowers 独有 |
| 并行分发 | — | dispatching-parallel-agents, subagent-driven | superpowers 独有 |

重叠不导致行为冲突（优先级链已解决），但导致**推理浪费**：AI 每次操作都要同时满足两套"检查 skill"指令。

### workflow.md 各节与 skill 的覆盖关系

| workflow.md 章节 | 行数 | 被 skill 覆盖？ | 能否推迟加载？ |
|---|---|---|---|
| **Mindset** (核心身份) | 18 行 | 无 skill 包含 | **不能** — Baton 灵魂，必须 always-loaded |
| **Flow** (两条路径) | 5 行 | skill 各自描述入口条件，无整体叙述 | **不能** — 第一次交互就需要 |
| **Complexity Calibration** | 6 行 | baton-plan 有扩展版 | **不能** — 第一步就是校准复杂度 |
| **Action Boundaries** (10 条) | 16 行 | 分散在三个 skill 的 Iron Laws 中 | **部分能** — 仅规则 1/2/5/9/10 需要即时 |
| **Evidence Standards** | 6 行 | baton-research 完全覆盖（扩展为 22 行） | **能** |
| **Annotation Protocol** | 7 行 | baton-plan 有 39 行扩展版 | **能** |
| **File Conventions** | 4 行 | 三个 skill 均包含 | **能** |
| **Session Handoff** | 2 行 | baton-implement 包含 | **能** |
| **Enforcement Boundaries** | 5 行 | baton-implement 包含 | **能** |

**结论：84 行中有 ~24 行可安全推迟到 skill 加载**（被 skill 完全覆盖的章节）。保留 ~45 行核心 + 精简版 Action Boundaries + 路由声明。

### N 插件扩展性问题

当前 2 插件 always-loaded = ~985 tokens。如果未来安装 N 个插件，each 有自己的 bootstrap：

```
N × ~490 avg tokens = always-loaded 总成本
5 插件 = ~2,450 tokens
10 插件 = ~4,900 tokens

在实际工作记忆 20-50K 中占比 5-25%（不可忽视）
```

每个 bootstrap 还触发自己的"全量 skill 扫描"推理，N 个 bootstrap = N 次扫描 — 线性增长的隐性成本。

**Baton 的应对策略**（在 Baton 可控范围内）：

| 措施 | 机制 | 效果 | 限制 |
|------|------|------|------|
| 自身瘦身 | workflow.md 420→220 tokens | 降低 Baton 贡献的 always-loaded 成本 | 只控制 Baton 自己 |
| Skill 路由声明 | workflow.md 中声明领域导向路由：Phase → baton skills，非 phase → 任何可用插件 skill，不对 phase 决策做全量扫描 | AI 跳过冗余 skill 扫描，减少推理浪费；不写死插件名，新插件自动纳入 | 不能阻止其他插件注入 bootstrap |
| 三层模式示范 | 文档化"最小 bootstrap + SessionStart 补充 + on-demand skill"模式 | 供其他插件参考，长期降低生态系统 always-loaded 成本 | 依赖社区采纳 |

**Baton 无法解决的**：阻止其他插件加载 bootstrap、统一路由所有插件。这需要宿主平台提供统一插件路由/优先级管理能力。

### 批注协议改进点

本轮批注过程中暴露了一个工作流缺陷：**批注引发的新分析停留在对话中，没有及时回写到文档 body**。

当前 workflow.md 的 Annotation Protocol 规则：
> "When an annotation is accepted: (1) update the document body, (2) record in Annotation Log."

此规则只覆盖"被接受的批注"（简单采纳/拒绝），未覆盖**批注引发的新分析**（如可行性评估、方案推导、数据收集）。本轮中 N 插件分析、workflow.md 覆盖关系表、三个方案对比等分析结论在多轮对话后才更新到文档，导致文档 body 与实际认知脱节。

**修复**：在 Annotation Protocol 中增加两条规则：

1. **分析回写规则**："批注引发新分析时，分析结论必须立即更新到文档 body 的相应章节。Annotation Log 记录'做了什么分析'，文档 body 反映'分析改变了什么'。"

2. **方案重评规则**："新分析结论产生后，必须检查是否与现有 Approach Analysis / Recommendation 矛盾。如果新分析扩大了问题范围、引入了新约束、或推翻了原方案的前提假设，必须立即重评方案并更新 plan body——不等待用户指出。"

本轮的反面教材：N 插件分析和按需加载可行性已经推翻了"精准两刀"方案的前提（scope 从 2 文件局部改动扩大到加载架构重构），但 plan body 在多轮对话后才被用户催促更新。正确做法是分析结论出来的那一刻就触发方案重评。

### Codex Hook 协议调研

**配置格式**（JSON, `.codex/hooks.json`）[RUNTIME] research.md Experiment 6-10 验证：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash .baton/adapters/adapter-codex.sh phase-guide" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash .baton/adapters/adapter-codex.sh stop-guard" }
        ]
      }
    ]
  }
}
```

> ⚠️ 官方文档示例使用 TOML `config.toml` 中的 `[[hooks.session_start]]` 语法，但实测该格式 hooks **不触发** [RUNTIME] research.md Exp 1-5。源码 `codex-rs/hooks/src/engine/discovery.rs:35` 从 `hooks.json` 发现 hooks。

**协议差异**（✅ 已验证）：

| 维度 | Claude Code | Codex | 影响 |
|---|---|---|---|
| 配置文件 | `.claude/settings.json` (JSON) | `.codex/hooks.json` (JSON) ✅ | setup.sh 需生成 hooks.json |
| 事件名 | PascalCase (`SessionStart`) | PascalCase (`SessionStart`) ✅ | 一致 |
| Exit code | 0=allow, 2=block | 0=ok, 非零="failed" 但**不阻断** session ✅ | Codex hooks 纯 advisory |
| 输出协议 | stderr 直接显示给 AI | stdout 纯文本 → `additionalContext` (DeveloperInstructions) ✅ | adapter: stderr→stdout |
| 信任 | 自动 | 需 `trust_level = "trusted"` + `codex_hooks` feature flag 启用 | setup.sh post-install 引导 |

**协议行为（已实测确认）**：
1. ✅ **SessionStart**：纯文本 stdout → 注入为 `additionalContext`。JSON stdout 需要 `SessionStartCommandOutputWire` 复杂 schema（不适合 Baton）。[RUNTIME] research.md Exp 6-7
2. ✅ **Stop**：hook 触发，stdin 含 `stop_hook_active` + `last_assistant_message`。exit code 非零 = "failed" 标签但 session 正常结束。[RUNTIME] research.md Exp 8-10
3. ⚠️ **Exit code 翻译**：所有非零 exit code 被 Codex 报告为 "code 1"，无论实际值（bash/PowerShell 一致）。[RUNTIME] research.md Exp 8-10
4. ✅ **trust_level**：项目级 `.codex/hooks.json` 需项目被 trust。setup.sh 自动写入 `~/.codex/config.toml`（per-project trust entry）。
5. ✅ **Feature flag**：`codex_hooks` 为 under-development，默认 disabled。setup.sh 自动写入 `.codex/config.toml`（项目级 `[features] codex_hooks = true`）。

**adapter-codex.sh 设计（已确认）**：
```
功能：将 Baton hooks（stderr 输出）转为 Codex 协议（stdout 纯文本）
实现：运行目标 hook，将 stderr 捕获并重定向为 stdout
参数：$1 = hook 名（phase-guide | stop-guard）
设计参考：adapter-cursor.sh [CODE] adapter-cursor.sh:1-14
```

### Hook 热路径盘点

| 路径 | Hooks | 频率 | 每次命令数 | 阻断？ |
|------|-------|------|-----------|--------|
| **热路径** | write-lock + post-write-tracker | 每次代码写入 | ~17 条 | write-lock 阻断 |
| **中路径** | completion-check | 每次任务完成 | ~5 条 | 可阻断 |
| **冷路径** | phase-guide, stop-guard, subagent-context, pre-compact | 每 session 1-2 次 | ~15-20 条 | 无 |

实际延迟：Linux/Mac <50ms，Windows Git Bash ~500ms — 可接受范围。7 个 hook 中只有 1 个能阻断（write-lock），其余全是 advisory — 这是设计而非缺陷。

## Requirements

1. [HUMAN] 基于"底层逻辑冲突"分析给出改进计划
2. [分析结论] 降低指令密度，保留门控精度
3. [分析结论] 使架构自文档化，防止"两个 agent 在打架"的误读
4. [HUMAN/annotation] 考虑 N 插件扩展性 + Baton 工作流按需加载可行性
5. [HUMAN/annotation] 考虑与 superpowers 的功能重叠和 skill 路由问题
6. [HUMAN/annotation] N 插件扩展性需要具体应对策略，不只是描述问题
7. [分析结论] 批注引发新分析时，结论必须立即回写文档 body（workflow 缺陷修复）
8. [HUMAN] setup.sh 需配置 Codex 的 SessionStart + Stop hook 支持

### 跨 IDE 兼容性分析

| IDE | workflow.md 加载 | Hooks (Layer 2) | Skills (Layer 3) | 安全等级 |
|---|---|---|---|---|
| **Claude Code** | CLAUDE.md @import | ✅ 全部 hooks | ✅ .claude/skills/ | 三层完整 |
| **Factory** | 同 Claude Code | ✅ 同上 | ✅ 同上 | 三层完整 |
| **Cursor** | .cursor/rules/baton.mdc | ✅ sessionStart + preToolUse(adapter) + bash-guard + subagent-context [CODE] setup.sh:969-973,1007-1010 | ❓ .cursor/skills/ | Layer 2 可用（phase-guide.sh 已配置） |
| **Codex** | AGENTS.md @import | ⚠️ **实验性** SessionStart + Stop（v0.114.0, 2026-03-11）[DOC] [Codex Changelog](https://developers.openai.com/codex/changelog/)；**无** PreToolUse/PostToolUse/SubagentStart 等 | ❓ .agents/skills/ | Layer 2 部分可用（phase-guide 可行），硬门控(write-lock)不可用 |

**关键发现（已修正）**：
- **Cursor 实际有 sessionStart** — setup.sh:969-973 配置了 `sessionStart` + `phase-guide.sh`。此前 plan 误判为"Cursor 无 Layer 2"，实际 Layer 2 可用。
- **Codex 新增实验性 SessionStart + Stop** (v0.114.0) — 但 setup.sh 尚未为 Codex 配置 hooks，且仅覆盖 2/7 hook events（无 PreToolUse → write-lock 不可用）。
- **当前唯一阻止方案 B 的 IDE 约束**：Codex（实验性 + setup.sh 未配置）。Cursor 约束已消除。

方案 A 仍排除（无 Layer 2 补偿）。方案 B 当前因 Codex 约束暂不可行，但未来 Codex hooks 稳定 + setup.sh 更新后可重新评估。方案 D（只增不减）是当前零风险选择。

## Support Boundary

1. 本计划对 **phase-specific annotation protocol** 的支持边界定义为：`baton-plan` / `baton-research` skills 可用。
2. 现有 no-skill fallback（`workflow-full.md` + `phase-guide.sh extract_section`）保留为遗留行为，但**明确不在本次变更范围内**；本计划不会把新的 Annotation Protocol 规则扩展到该路径。
3. 因此 Annotation Protocol 的收口模型是：`workflow.md` 作为**唯一 cross-cutting 规则源**；`baton-plan` 和 `baton-research` 只追加一行引用，不复制规则正文。

### Codex User-Config Boundary

- Human-approved scope: for Codex integration only, `setup.sh` may modify user-level `~/.codex/config.toml`.
- This approval is narrow: it covers Baton-owned trust / feature-flag bootstrap only, not arbitrary user config rewrites.
- Any write to user-level Codex config must be exact-key append/update plus exact-key uninstall cleanup; do not attempt broad TOML normalization or destructive rewrites.

### Codex Test Isolation

- Because Codex install/uninstall now touches user-level config, tests must not use the real home directory.
- `tests/test-setup.sh` must redirect `HOME` to a temp directory for Codex-specific cases before invoking `setup.sh`.
- Verification for Codex uninstall must assert both:
  - Baton-owned entries are removed from the temp HOME config.
  - the real user config is never part of the test write set.

## Constraints

1. write-lock.sh 硬门控能力不能降低
2. Mindset 四原则必须 always-loaded（Baton 核心身份）
3. `extract_section` 函数依赖 `### [SECTION_NAME]` 标记 [CODE] `_common.sh:51-60`；该实现仅作为遗留 fallback 背景，不是本计划的 protocol 变更目标
4. no-skill fallback（skill → extract_section → 内联 3 行摘要）本次显式 out of scope：保持现状，不承接新的 Annotation Protocol 规则
5. 改动可独立发布
6. **workflow.md 当前不能精简** — Codex 仅有实验性 SessionStart（setup.sh 未配置），精简会导致 Codex 用户丢失未被 Layer 2 覆盖的内容。Cursor 已确认支持 sessionStart [CODE] setup.sh:969-973。未来 Codex hooks 稳定后可重评此约束 [DOC] Codex Changelog v0.114.0

## Approach Analysis

### ~~Approach A: 最小引导模式（Minimal Bootstrap）~~ — 已排除

将 workflow.md 从 84 行精简到 ~45 行。

**排除原因**：❌ 现有支持边界内仍无充分保障。Codex 的 `.agents/skills/` 仍未证实，workflow.md 仍是最低共识协议源。精简会导致缺少 phase skill 支撑的环境丢失 Evidence Standards、Annotation Protocol 等关键章节。

### Approach B: 双层加载（Tiered Loading） — 当前暂不可行，未来可重评

在方案 A 基础上用 phase-guide.sh Layer 2 填补空白。

**当前状态**：⚠️ Cursor 已确认支持 sessionStart [CODE] setup.sh:969-973（此前误判为不支持）。唯一剩余阻碍是 Codex：实验性 SessionStart (v0.114.0) + setup.sh 未配置 hooks。

**未来可行条件**：(1) Codex hooks 退出实验状态 (2) setup.sh 为 Codex 配置 SessionStart hook (3) 验证 Codex hook 协议兼容性。三个条件满足后可重新评估方案 B。

### ~~Approach C: Baton 统一路由~~ — 已排除

Baton 接管 superpowers bootstrap。

**排除原因**：❌ 跨系统依赖，每新增插件需手动更新路由表。这是平台层面的问题。

### Approach D: 增量增强（Incremental Enhancement）(recommended)

**核心思路**：workflow.md 不精简，保留完整 84 行作为跨 IDE 的通用保障。在此基础上**增加**高价值内容。

```
workflow.md 增量版 (~92 行, ~460 tokens):
├── 原有内容完整保留 (84 行, ~420 tokens) — 跨 IDE 通用保障
├── Architecture Model 子节 (~5 行, ~25 tokens) — 单循环模型 + 领域导向 skill 路由 + 文档层级内联
└── Annotation Protocol 增强 (~3 行, ~15 tokens) — 分析回写 + 方案重评 + 批注清理

附加独立改进：
├── Annotation Protocol 收口 — workflow.md 写规则正文；baton-plan / baton-research 仅加引用
└── Codex hooks 支持 — setup.sh 新增 hooks.json 配置 + adapter-codex.sh + 测试
```

| 维度 | 评估 |
|---|---|
| Token 变化 | 420 → ~460 tokens（增加 ~10%，换来架构透明 + 路由优化 + 工作流修复） |
| 跨 IDE 兼容性 | ✅ 支持边界内兼容 — workflow.md 只增不减；no-skill fallback 显式不扩范围 |
| 技术可行性 | ✅ workflow.md 追加：无冲突。Codex hooks：新能力建设，需 hooks.json 生成 + adapter + 测试。协议已实测验证 [RUNTIME] research.md |
| 风险 | workflow.md 追加：极低。Codex hooks：中低（协议已验证 ✅ + hooks.json 合并 + trust/feature-flag 引导 + 卸载 lifecycle） |
| N 插件应对 | 路由声明让 AI 跳过 phase 决策的冗余 skill 扫描；不写死插件名 |
| 防误读 | Architecture Model 显式声明单循环模型，防止 Gemini 式"工具打架"误读 |
| 工作流修复 | Annotation Protocol 增强修复"分析不回写"+ "方案不重评"+ "已处理批注不清理"；规则以 1 源 2 引用收口 |

**方案 D 与方案 A/B 的本质区别**：

- 方案 A/B 的目标是**降低 token 成本**（420→220），代价是跨 IDE 兼容性
- 方案 D 的目标是**提高每 token 价值**（增加 55 tokens 换来架构透明 + 路由 + 工作流修复），不牺牲兼容性
- 实际上 420 tokens 已经极精简（200K 上下文的 0.2%），继续压缩的边际收益远小于跨 IDE 破坏的风险

### 已排除的其他方案

**热路径 Hook 缓存**：排除原因——find_plan 首次迭代即命中，成本/收益不划算。

**删除 post-write-tracker**：排除原因——它是 write-set 纪律的最后安全网。

## Recommendation

**Approach D: 增量增强**。

1. **workflow.md 不精简，只增加**：Architecture Model（单循环声明 + 领域导向 skill 路由 + 文档层级内联）+ Annotation Protocol 增强（分析回写 + 方案重评 + 批注清理）
2. **Annotation Protocol 收口为 1 源 2 引用**：`workflow.md` 承载 3 条 cross-cutting 规则正文；`baton-plan` / `baton-research` 只加同一行引用，不复制规则正文；`workflow-full.md` 所代表的 no-skill fallback 明确 out of scope
3. **Codex hooks 支持**（新能力建设，best-effort）：setup.sh hooks.json 配置生成 + trust/feature-flag 自动配置 + adapter-codex.sh（stderr→stdout 转换）+ 测试覆盖。协议已实测验证 ✅ [RUNTIME] research.md。用户运行 setup.sh 后即可用，无需手动配置
4. 支持边界：workflow.md 改动（#1 #3）对当前支持路径兼容；Codex hooks（#3）为 best-effort 条件支持（依赖：实验性 hooks 稳定 + adapter 协议验证 + 用户 trust 配置）

**不触碰**：superpowers 插件本身（其加载成本 ~565 tokens 由插件控制，Baton 通过领域导向路由声明减少推理浪费，但不能阻止其加载）

**N 插件应对**：通过自身 bootstrap 大小控制（~475 tokens）+ 领域导向路由（不对 phase 决策做全量扫描）+ 三层模式文档化示范。阻止其他插件注入 bootstrap 需宿主平台支持。

**未来演进路径**：方案 B（双层加载 + workflow.md 精简）在 Codex hooks 稳定后可重新评估。当前 3/4 IDE 已支持 SessionStart（Claude Code、Factory、Cursor），仅 Codex 为实验性。方案 D 的 Architecture Model + Annotation Protocol 增强不受影响——无论未来是否精简，这些增量都保留。

## Surface Scan

方案 D 只增不减，影响范围极小。

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/workflow.md` | L1 | **modify** | 追加 Architecture Model (~5 行) + Annotation Protocol 增强 (~3 行)。不删除任何现有内容。~~Document Authority 已撤销~~ |
| `.baton/workflow-full.md` | L1 | skip | 现有 no-skill fallback 继续保留，但已被显式划为 out of scope；本计划不向该路径同步新的 Annotation Protocol 规则 |
| `.baton/hooks/phase-guide.sh` | L2 | skip | 不读取 workflow.md 内容，只检查 plan.md 的存在和 BATON:GO 标记 [CODE] phase-guide.sh:37-97 |
| `.baton/hooks/_common.sh` | L2 | skip | `extract_section` 只搜索 `### [` 标记 [CODE] _common.sh:51-60，不受 workflow.md 追加影响 |
| `.baton/hooks/write-lock.sh` | L2 | skip | 不读取 workflow.md，只检查 plan.md 中的 BATON:GO |
| `.baton/hooks/stop-guard.sh` | L2 | skip | 不读取 workflow.md |
| `.baton/hooks/post-write-tracker.sh` | L2 | skip | 不读取 workflow.md |
| `tests/test-phase-guide.sh` | L2 | **verify** | 运行现有测试确认无回归 |
| `research.md` | L1 | **modify** | Change #6a 的 Codex hook 协议 spike 结论必须落到独立 research.md |
| `setup.sh` | L1 | **modify** | `configure_codex()` 增加 SessionStart + Stop hook 配置（`.codex/hooks.json` JSON 格式）+ feature flag 引导 |
| `.baton/adapters/adapter-codex.sh` | L1 | **create** | Codex 输出协议适配器：stderr→stdout 转换（纯文本模式）✅ 协议已验证 |
| `tests/test-setup.sh` | L2 | **modify** | 新增 Codex hooks 配置验证用例 |
| `tests/test-adapters.sh` | L2 | **modify** | 新增 adapter-codex.sh 测试用例 |
| `tests/test-workflow-consistency.sh` | L2 | **verify** | 运行确认无回归 |
| `tests/test-annotation-protocol.sh` | L2 | **modify** | 新增 3 条规则的 drift guard |
| `docs/ide-capability-matrix.md` | L1 | **modify** | Codex 行更新：反映实验性 hooks (SessionStart, Stop) |
| `README.md` | L1 | **modify** | Codex 行 + Codex note 更新：反映 best-effort hooks 支持 |
| `setup.sh` (ide_summary) | L1 | **modify** | Codex summary 从 "rules guidance via AGENTS.md" 更新为含 hooks 描述 |
| `tests/test-ide-capability-consistency.sh` | L2 | **modify** | line 74 Codex summary 断言同步更新 |
| baton-plan SKILL.md | L2 | **modify** | Annotation Protocol (Plan Phase) 节（line 205）追加 1 行引用，指向 workflow.md 的 cross-cutting 规则源 |
| baton-research SKILL.md | L2 | **modify** | 有独立 Annotation Protocol (Research Phase) 节（line 209），追加 1 行引用，指向 workflow.md 的 cross-cutting 规则源 |
| baton-implement SKILL.md | L2 | skip | 无独立 Annotation Protocol 节 |

## Change List

| # | File | Change | Verify |
|---|------|--------|--------|
| 1 | `.baton/workflow.md` | 在 Mindset 节后追加 Architecture Model 子节（~5 行）：单循环模型声明（"Host IDE's agentic loop 是唯一控制循环，Baton 提供 instructions + gates"——不绑定具体 IDE）+ 领域导向 skill 路由（"Phase governance → baton-* skills；非 phase → 任何可用插件 skill"）。不写死插件名或 IDE 名。 | 子节存在，措辞 IDE 无关，~5 行 |
| 2 | ~~`.baton/workflow.md`~~ | ~~Document Authority 子节~~ — **已撤销**：test-workflow-consistency.sh:502-508 明确禁止 workflow.md 包含 "Document Authority"（设计守卫："meta-governance belongs in workflow-full.md"）。文档层级概念改为在 Change #1 的 Architecture Model 中用不同措辞内联表达 | N/A |
| 3 | `.baton/workflow.md` | 在现有 Annotation Protocol 节中追加 3 条规则：(a) 分析回写——批注引发新分析时结论必须立即更新文档 body (b) 方案重评——新分析结论与现有 Approach/Recommendation 矛盾时必须立即重评，不等待用户指出 (c) 批注清理——批注处理为结构化 Round 记录后，从批注区删除原始文本；Round 记录中的引用即为权威记录，批注区仅保留未处理批注 | 三条规则存在且可操作 |
| 4a | ~~`.baton/workflow-full.md`~~ | ~~头部删除~~ — **已撤销**（test-workflow-consistency.sh:18-30 共享章节一致性） | N/A |
| 4b | ~~`.baton/workflow-full.md`~~ | ~~Annotation Protocol 引用同步~~ — **已撤销**：支持边界改为 `skills required`；现有 no-skill fallback（workflow-full.md + phase-guide）显式 out of scope，本计划不向该路径扩展新规则 | N/A |
| 4c | `.claude/skills/baton-plan/SKILL.md` | Annotation Protocol (Plan Phase) 节（line 205）加同样引用 | 引用存在 |
| 4d | `.claude/skills/baton-research/SKILL.md` | Annotation Protocol (Research Phase) 节（line 209）加同样引用 | 引用存在 |
| 5 | `setup.sh` | **新能力建设**（非小改动）：`configure_codex()` 增加完整 hooks 配置。需要：(a) 新建 `.codex/hooks.json` 生成逻辑（JSON 格式，PascalCase 事件名）；`.codex/` 目录不存在时 `mkdir -p` 创建 (b) 处理 `.codex/hooks.json` 不存在（创建新文件）和已存在（合并）两种场景 (c) **自动写入 trust**：在 `~/.codex/config.toml` 中追加 per-project trust entry；`~/.codex/` 目录不存在时 `mkdir -p` 创建；`config.toml` 不存在时创建新文件，已存在时追加（查重避免重复 entry）(d) **自动写入 feature flag**：在 `.codex/config.toml`（项目级）写入 `[features] codex_hooks = true`；文件不存在时创建新文件，已存在时追加/更新 `[features]` 节 (e) **卸载 lifecycle**：清理 `.codex/hooks.json` + `.codex/config.toml` feature flag + `~/.codex/config.toml` trust entry (f) 安装后提示文案更新 | install: `.codex/hooks.json` 含正确 hooks + trust 已自动配置 + feature flag 已自动启用（目录/文件从零创建或合并均正确）；uninstall: 三处配置均被清理 |
| 6a | `research.md` | **前置 gate** ✅ **已通过**。用实际 Codex CLI v0.114.0 验证了：(1) SessionStart 纯文本 stdout → `additionalContext` ✅ (2) Stop hook 触发，exit code 不阻断 ✅ (3) 所有非零 exit code 映射为 "code 1" ✅。关键发现：`hooks.json`（JSON）是正确配置格式，TOML `config.toml` 不触发 hooks。[RUNTIME] research.md Experiments 6-10 | spike 结论已记录在 research.md ✅ |
| 6b | `.baton/adapters/adapter-codex.sh` | 基于 gate #6a 验证结论实现 ✅ 设计已确认：运行目标 hook（$1=phase-guide\|stop-guard），捕获 stderr 重定向为 stdout（纯文本），传递 exit code。设计参考 adapter-cursor.sh。 | adapter 正确转换 phase-guide.sh 和 stop-guard.sh 的 stderr→stdout |
| 7 | `tests/test-setup.sh` | 新增 Codex hooks 配置验证用例：install（hooks.json 生成 + 合并 + trust 自动配置 + feature flag 自动启用）+ uninstall（hooks.json + config.toml feature flag + 用户级 trust 三处清理）；同时同步 `--choose` 场景中的 Codex summary 断言 | Codex hooks 全 lifecycle 有测试覆盖，且 setup summary 相关断言不漂移 |
| 8 | `tests/test-adapters.sh` | 新增 adapter-codex.sh 测试用例（当前只覆盖 Cursor adapter） | adapter-codex.sh 输出格式正确 |
| 9 | `tests/test-annotation-protocol.sh` | 新增 drift guard：(a) workflow.md 包含 3 条规则关键词（"分析回写"/"方案重评"/"批注清理"）(b) baton-plan SKILL.md、baton-research SKILL.md 包含引用指向 | workflow.md 唯一源 + 2 个 phase-authoritative 引用均有覆盖 |
| 10 | `docs/ide-capability-matrix.md` | Codex 行更新：从"no hooks"改为"experimental SessionStart + Stop (v0.114.0, best-effort)" | 与 README、setup.sh 一致 |
| 11 | `README.md` | Codex 行更新 + Codex note 修订：从"no hooks / Rules guidance"改为"Rules guidance + experimental hooks (best-effort)" | 与 capability matrix 一致 |
| 12 | `setup.sh` (ide_summary) | Codex summary 更新（line 477 区域 + line 1171 区域）：反映 hooks best-effort 支持 | test-ide-capability-consistency.sh 断言通过 |
| 13 | `tests/test-ide-capability-consistency.sh` | line 74 Codex summary 断言同步更新 | 断言匹配新 summary |
| 14 | `tests/test-phase-guide.sh` + `tests/test-workflow-consistency.sh` | 无代码改动 | 运行确认现有测试全部通过 |

## Todo

- [x] ✅ Todo 1: 在 `research.md` 完成 Codex hook 协议 spike，并给出 gate 结论。
  Change: 用实际 Codex CLI (>= v0.114.0) 验证 `session_start` / `stop` 的 stdout 解析路径，以及 exit code 2 的 stderr 处理；将结论写入 `research.md`，明确是否允许继续 Change #6b / #8。
  Files: `research.md`
  Verification: `research.md` 明确记录 3 个问题的观察结果、证据来源、以及 “gate pass / gate fail” 结论。
  Dependencies: none
  Derived artifacts: none
  Files: `research.md` | Verified: **Gate PASS** — Phase 1 (Exp 1-5) TOML config 全部失败 → Phase 2 (Exp 6-10) 发现 `hooks.json` 是正确格式，hooks 成功触发。SessionStart 纯文本 stdout→additionalContext ✅，Stop 触发但不阻断 ✅，exit code 统一映射为 “code 1” ✅ | Deviations: none

- [x] ✅ Todo 2: 实现 Annotation Protocol 的“1 源 2 引用”收口。
  Change: 在 `workflow.md` 增加 3 条 cross-cutting 规则正文；在 `baton-plan` / `baton-research` 的 Annotation Protocol 段落各增加一行引用，不复制规则正文。
  Files: `.baton/workflow.md`, `.claude/skills/baton-plan/SKILL.md`, `.claude/skills/baton-research/SKILL.md`
  Verification: 逐文件复读对应段落，确认 `workflow.md` 是唯一规则正文来源，两个 SKILL 文件仅保留引用。
  Dependencies: none
  Derived artifacts: none
  Files: `.baton/workflow.md`, `.claude/skills/baton-plan/SKILL.md`, `.claude/skills/baton-research/SKILL.md` | Verified: re-read modified sections → workflow.md carries rule body, both skills only reference it | Deviations: none

- [x] ✅ Todo 3: 实现 Codex 的 setup lifecycle 和 adapter。
  Change: 基于 Todo 1 的 gate 结论（✅ PASS），在 `setup.sh` 中增加：`.codex/hooks.json` 生成/合并、`~/.codex/config.toml` trust 自动配置、`.codex/config.toml` feature flag 自动启用、卸载三处清理、summary 文案更新；新增 `.baton/adapters/adapter-codex.sh`（stderr→stdout 转换）。
  Files: `setup.sh`, `.baton/adapters/adapter-codex.sh`
  Verification: 复读 `configure_codex()`、uninstall 路径和 adapter 输出逻辑，确认它们与 Todo 1 的协议结论一致。
  Dependencies: Todo 1 ✅
  Derived artifacts: none
  Files: `setup.sh`, `.baton/adapters/adapter-codex.sh`, `tests/test-setup.sh` (B-level: assertion update), `tests/test-ide-capability-consistency.sh` (B-level: assertion update) | Verified: test-setup.sh 152/152 ✅, test-adapters.sh 3/3 ✅, test-ide-capability-consistency.sh 20/20 ✅ | Deviations: Two test files needed B-level assertion updates for the changed ide_summary text

- [x] ✅ Todo 4: 补齐测试覆盖并跑现有守卫。
  Change: 为 Codex hooks / adapter / summary / annotation drift 增加测试覆盖，并重跑现有 verify-only guards。
  Files: `tests/test-setup.sh`, `tests/test-adapters.sh`, `tests/test-annotation-protocol.sh`, `tests/test-ide-capability-consistency.sh`
  Verification: 运行 `tests/test-setup.sh`, `tests/test-adapters.sh`, `tests/test-annotation-protocol.sh`, `tests/test-ide-capability-consistency.sh`, `tests/test-phase-guide.sh`, `tests/test-workflow-consistency.sh`。
  Dependencies: Todo 2 ✅, Todo 3
  Derived artifacts: none
  Files: `tests/test-setup.sh`, `tests/test-adapters.sh`, `tests/test-annotation-protocol.sh`, `tests/test-ide-capability-consistency.sh`, `tests/test-phase-guide.sh`, `tests/test-workflow-consistency.sh` | Verified: `test-setup.sh` 174/174 ✅, `test-adapters.sh` 7/7 ✅, `test-annotation-protocol.sh` 35/35 ✅, `test-ide-capability-consistency.sh` 24/24 ✅, `test-phase-guide.sh` 76/76 ✅, `test-workflow-consistency.sh` ALL CONSISTENT ✅ | Deviations: Codex-touching setup cases required temp `HOME` isolation in the harness, including re-install paths that auto-detect Codex via `.agents/` fallback

- [x] ✅ Todo 5: 同步 Codex 的公开能力表述。
  Change: 更新 capability matrix 和 README 中对 Codex 的描述，使其与 `setup.sh` summary 和实际支持范围一致。
  Files: `docs/ide-capability-matrix.md`, `README.md`
  Verification: 复读文案，确认与 `setup.sh` 中的 Codex summary 和计划中的 best-effort/support-boundary 表述一致。
  Dependencies: Todo 3
  Derived artifacts: none
  Files: `docs/ide-capability-matrix.md`, `README.md`, `tests/test-ide-capability-consistency.sh` | Verified: README 与 capability matrix 都已同步为 “experimental SessionStart + Stop hooks / best-effort / no write-lock”，并由 `test-ide-capability-consistency.sh` 24/24 ✅ 约束防回退 | Deviations: README 的 adapters 清单同步从 “Cursor” 扩展为 “Cursor, Codex”

### Todo Execution Notes

- Todo 3 note: user-level Codex config mutation is explicitly approved, but implementation must stay Baton-owned and exact-key scoped per `Codex User-Config Boundary`.
- Todo 4 note: Codex-specific setup tests must redirect `HOME` to a temp directory and verify only that temp user config is mutated/cleaned.

## Lessons Learned

- **配置格式是 `hooks.json`（JSON），不是 `config.toml`（TOML）**——这是 Exp 1-5 全部失败的根因。官方文档用 TOML 示例容易误导，源码 `discovery.rs:35` 明确从 `hooks.json` 发现 hooks。
- `codex_hooks` feature flag 默认关闭；任何使用都必须显式启用。setup.sh 需 post-install 引导。
- Codex hooks 在 `codex exec` 和 interactive/TUI 路径**共享同一个 hook engine**（源码 `codex-rs/core/src/codex.rs` 的 `run_turn`），此前”exec 不支持 hooks”的结论是因为配置格式错误。
- SessionStart 纯文本 stdout 是最简单可靠的 adapter 设计——JSON 模式需要复杂 schema，不值得。
- Exit code 在 Codex 中不阻断 session（与 Claude Code 的 PreToolUse exit 2=block 不同）——Codex hooks 纯 advisory。
- Annotation Protocol 收口和 Codex hooks 是两条可独立推进的工作流。把它们拆开是对的，否则 Codex gate 会把纯文档协议改动一起阻塞。
- 本地 spike harness 只该作为临时 completion aid 使用；研究结论写入 `research.md` 后应立即清理。
- `.agents/` fallback 会让后续 `setup.sh` 重跑自动探测到 Codex；因此 `tests/test-setup.sh` 里凡是可能进入 Codex 路径的 case，都必须默认把 `HOME` 重定向到临时目录，不能只隔离“显式 codex”用例。

### Codex Gate Update (2026-03-11)

- **Phase 1 (Exp 1-5, 2026-03-11 AM)**: TOML `config.toml` hooks 配置全部失败。错误归因为”exec 不支持 hooks”。
- **Phase 2 (Exp 6-10, 2026-03-11 PM)**: 源码分析发现 `hooks.json` 是正确格式 → 切换后 hooks 立即触发。所有 3 个 gate 问题已回答。
- **Gate: PASS** — Codex hooks 在本地 `codex exec --enable codex_hooks` + `hooks.json` 配置下可靠工作。Todos 3-5 已解除阻塞。

## Self-Review

### Internal Consistency Check
- Recommendation（方案 D 增量增强 + Codex hooks）和 change list 一致 — Change 1+3 在 workflow.md 追加，4c+4d 同步到两个 phase-authoritative skills，5+6a+6b Codex hooks，7-14 测试/文档同步 ✅
- 撤销决策有代码证据：Document Authority 被 test-workflow-consistency.sh:502-508 禁止；workflow-full.md 头部被 :18-30 共享章节一致性测试保护 ✅
- **Annotation Protocol 已收口为 1 源 2 引用**：workflow.md (#3) 是唯一 cross-cutting 规则源；baton-plan SKILL.md (#4c) + baton-research SKILL.md (#4d) 仅保留 phase-authoritative 引用；workflow-full.md/no-skill fallback 显式 out of scope ✅
- **Codex 能力公开文档同步**：ide-capability-matrix.md (#10) + README.md (#11) + setup.sh ide_summary (#12) + test-ide-capability-consistency.sh (#13) ✅
- **adapter 协议有前置 gate** (#6a)：spike 已验证通过 ✅ [RUNTIME] research.md Exp 6-10。adapter (#6b) 和 adapter 测试 (#8) 已解除阻塞 ✅
- Surface Scan "modify/create" 文件全部出现在 change list ✅
- Surface Scan "skip" 文件都有理由 ✅
- phase-guide.sh 不读取 workflow.md 内容 [CODE] `phase-guide.sh:37-97`，追加内容不影响 ✅
- N 插件应对策略已在 Research Source 中明确 Baton 可控范围 + 不可控边界 ✅
- 批注协议改进已纳入 Change 3+4c+4d，修复"分析不回写"+ "方案不重评"+ "已处理批注不清理"三个缺陷，且避免多文件复制规则正文 ✅
- 新规则有 drift test 覆盖（Change #9, test-annotation-protocol.sh）✅
- 支持边界已显式定义：phase-specific protocol 以 skills 为准；no-skill fallback 保留但 out of scope ✅
- 跨 IDE 兼容性：workflow.md 只增不减 → 支持边界内环境不受负面影响 ✅。Codex hooks 为 best-effort 条件支持（协议已验证 ✅ [RUNTIME] research.md；trust + feature flag 由 setup.sh 自动配置 ✅）
- Codex adapter 设计已确认：stderr→stdout 转换，纯文本模式 ✅ [RUNTIME] research.md Exp 6
- **Codex hooks 复杂度已正视**：标注为"新能力建设"，包含 hooks.json 生成、合并、adapter、测试、卸载 lifecycle 5 项独立工作 ✅
- adapter-codex.sh 协议行为已验证 ✅：SessionStart 纯文本 stdout→additionalContext；Stop 触发但不阻断 [RUNTIME] research.md Exp 6-10
- trust_level + feature flag 方案明确：setup.sh 自动配置（trust → `~/.codex/config.toml` per-project，feature flag → `.codex/config.toml` 项目级），用户零感知 ✅
- 卸载 lifecycle 已纳入 Change #5：hooks.json 清理 + test-setup.sh 覆盖 uninstall 场景 ✅
- test-workflow-consistency.sh 作为 verify 项，确认无回归 ✅
- **残留冲突已清理**：Surface Scan / 技术可行性 / test 描述中的旧 Approach B 表述已修正 ✅

### External Risks
- **最大风险**（已降级）：~~adapter 协议不匹配~~ → 协议已实测验证 ✅。当前最大风险改为：Codex `codex_hooks` feature flag 在稳定前发生 breaking change（配置格式、事件名、stdout 解析路径等）。缓解：adapter 模式隔离协议差异 + hooks.json 格式独立于 adapter 逻辑
- **次大风险**：`~/.codex/config.toml` TOML 合并在边界场景下出错（已有复杂 TOML 结构时追加 trust entry）。缓解：只做追加/查重，不尝试深度合并；卸载时按写入的精确 key 清理
- **可能让计划完全失败的因素**：Codex 将 `hooks.json` 格式替换为其他配置表面（如回归到 TOML-only）。缓解：hooks.json 生成逻辑集中在 setup.sh 单一函数中，易于修改
- **排除的替代方案**：(1) Approach A/B（精简 workflow.md）— Codex 约束 + 测试契约阻止 (2) Approach C（统一路由）— 跨系统依赖 (3) 热路径缓存 — 成本/收益不划算
- **测试契约教训**：plan 的 Change #2（Document Authority）和 Change #4（workflow-full.md 头部删除）因未先读 test-workflow-consistency.sh 而提出了不可行的改动。Pre-Exit Checklist 的"Change specs grounded in reads"要求未被充分执行
- **方案 B 未来演进**：3/4 IDE 已支持 SessionStart（Cursor 此前误判为不支持）。Codex 实验性 SessionStart (v0.114.0) 是最后一块拼图。当 Codex hooks 稳定 + setup.sh 配置完成后，方案 B（workflow.md 精简 + Layer 2 补偿）变为可行，可在方案 D 基础上叠加实施（方案 D 的增量内容保留不受影响）
- **N 插件问题的局限性**：Baton 只能控制自己的 bootstrap 大小和路由声明。阻止其他插件注入 bootstrap 需要平台支持
- **支持边界选择的代价**：本计划不覆盖 no-skill fallback，因此新的 Annotation Protocol 规则不会通过 `workflow-full.md` / `phase-guide` 自动下发；这是有意收口，不是遗漏

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

## Annotation Log

### Round 1 (2026-03-11)

**[inferred: question] § Token 足迹盘点**
"还加载了 superpowers的skill吗?"
→ Inferred intent: 质疑 token 归属准确性
→ 是的，using-superpowers skill 仍在每个 session 加载（证据：本轮 system-reminder 中可见注入内容）。但这是 superpowers 插件的成本，非 Baton 组件。原文混淆了归属。
→ Result: accepted — 已修正 plan 中的 token 数据，将 Baton always-loaded 与 superpowers 分列

### Round 2 (2026-03-11)

**[inferred: depth-issue] § Baton 与 superpowers 的关系**
"baton 项目中的skill 和superpowers 里面的功能有重叠" + "skill 不是按需加载的吗 为什么会总是加载superpowers的技能呢"
→ Inferred intent: 质疑双层治理架构的合理性
→ `using-superpowers` 是引导技能（bootstrap），通过 superpowers 插件的 SessionStart hook 注入。它必须总是加载，因为它的职责是告诉 AI "检查有没有适用的 skill"——如果它不先加载，按需加载机制就没有触发器。其他 superpowers skill 确实是按需加载的。
→ 功能重叠确认：baton-plan ↔ writing-plans, baton-implement ↔ executing-plans, baton-research ↔ brainstorming（部分）。但不冲突——CLAUDE.md 优先级 > superpowers。非重叠区域（TDD、debugging、code-review、git-worktrees 等）是 superpowers 独有价值。
→ Consequence: 不改变当前 plan 方向（Baton 内部优化），但标记为独立议题——superpowers 与 Baton 的整合策略需要单独决策
→ Result: awaiting human decision — 是否纳入当前 plan 或作为独立议题

**[inferred: change-request] § Baton 接管 skill 路由**
"baton如果也通过这样的方法呢 是不是就能覆盖superpowers的技能了呢"
→ Inferred intent: 提议 Baton 通过 SessionStart hook 注入引导指令，接管 skill 路由，覆盖 superpowers
→ 技术上可行（两条路径）：(1) Baton 做统一路由（大改造，引入跨系统依赖）(2) 利用已有优先级链 + 在 workflow.md 架构声明中加路由指令（零新文件，可并入当前改进 2）
→ 行为上不冲突（优先级链已保证正确），但推理开销真实存在（~565 tokens + 全量 skill 扫描是浪费）
→ 建议：在改进 2 的 Architecture Model 中增加 skill 路由声明，最小成本解决推理浪费
→ Result: awaiting human decision — 是否将路由声明纳入改进 2

**[inferred: question] § 路径 2 能否避免 always-loaded**
"方案2 是不是能避免superpowers的技能总是加载的问题呢"
→ Inferred intent: 确认路径 2 是否彻底解决加载成本
→ 不能。路径 2 减少推理浪费（AI 跳过冗余 skill 扫描），但不能阻止 superpowers 插件通过其自己的 SessionStart hook 注入 ~565 tokens。要彻底消除加载成本，需要在 superpowers 插件侧操作（卸载/配置/替换）。
→ Result: awaiting human decision — 目标是彻底消除 565 tokens 开销，还是接受固定成本、只减少推理浪费

**[inferred: depth-issue] § 更优方案 + N 插件 + 按需加载**
"有更优的方案吗 还需要考虑如果又新增了类似的插件或者skill呢 或者让baton工作流也按需加载呢"
→ Inferred intent: 要求更根本的架构优化，不满足于精准两刀
→ 进行了完整可行性分析：workflow.md 84 行逐节对照三个 baton skill，发现 ~24 行可安全推迟（已被 skill 完全覆盖）。提出三个方案：A（最小引导）、B（双层加载）、C（统一路由）。
→ Consequence: 方向变化 — 从"精准两刀"升级为架构层面的加载策略优化。复杂度可能从 Small 升级到 Medium。
→ Result: accepted — plan 已更新为方案 B（双层加载），复杂度升级为 Medium

### Round 3 (2026-03-11)

**[inferred: gap] § N 插件扩展性缺乏解决方案**
"N 插件扩展性问题 没看到解决办法呀"
→ Inferred intent: plan 只描述了问题，没有给出 Baton 可控范围内的应对策略
→ 已在 Research Source 的 N 插件章节增加"Baton 的应对策略"表：自身瘦身（420→220 tokens）+ skill 路由声明（减少推理浪费）+ 三层模式示范（长期生态影响）。同时明确标注不可控边界：阻止其他插件注入 bootstrap 需要平台能力。
→ Result: accepted — N 插件应对策略已纳入 plan body + Self-Review + External Risks

**[inferred: gap] § 分析未回写文档的工作流缺陷**
"分析情况没有更新至plan的问题 也没看到改进的点"
→ Inferred intent: (1) 批评上一轮分析只在对话中，未更新到文档 (2) 要求将此工作流缺陷本身也作为改进点
→ 根因：workflow.md Annotation Protocol 的规则只覆盖"被接受的批注"（简单采纳/拒绝），未覆盖"批注引发的新分析"场景。本轮中可行性分析、覆盖关系表、方案对比等在多轮对话后才更新到 plan body。
→ 修复：增加 Change 2 — 在 workflow.md 的 Annotation Protocol 中加规则："批注引发新分析时，结论必须立即更新到文档 body"
→ Result: accepted — 已纳入 Requirements #7 + Change List #2 + Self-Review

**[inferred: gap] § 新分析推翻旧方案时缺乏自动重评**
"有可能分析的结论会影响之前plan里面的方案"
→ Inferred intent: 不仅是"回写文档"，更是"新分析可能推翻现有方案但 plan 没有自动触发重评"
→ 本轮反面教材：N 插件分析 + 按需加载可行性已推翻"精准两刀"的前提（scope 从局部改动扩大到架构重构），但 plan body 在多轮后才被用户催促更新
→ 修复：Change #2 增加第二条规则（方案重评）——新分析结论与现有 Approach / Recommendation 矛盾时，必须立即重评并更新，不等待用户指出
→ Result: accepted — 已合并到 Change #2 的两条规则中

**[inferred: change-request] § Skill 路由不应写死插件名**
"这里写死superpowers skills 是不是不太好呀 以后如果有新的插件也会有类似的重叠问题的呀"
→ Inferred intent: 路由声明应面向未来，不依赖具体插件名
→ 正确——写死 "superpowers skills" 犯了 Approach C（统一路由）同样的跨系统依赖问题。路由应该是领域导向的：Phase governance → baton-* skills；非 phase 关注点 → 任何可用插件 skill。新插件自动纳入"非 phase"域，无需更新路由。
→ Consequence: 影响 Approach B 附加改进中的 Skill 路由指令描述 + N 插件应对策略表 + Change #1
→ Result: accepted — 全部 3 处已更新为领域导向路由，不写死插件名

### Round 4 (2026-03-11)

**[inferred: question + constraint-discovery] § 跨 IDE 兼容性**
“方案B的改动会影响在codex 或者 cursor 等ide中的使用吗?”
→ Inferred intent: 检验方案 B 在非 Claude Code 环境下的可行性
→ 调查结果：Codex 此前无 hooks（workflow.md 是唯一协议来源），Cursor 无 SessionStart hook（无 Layer 2）。精简 workflow.md 会破坏 Codex 兼容性、降级 Cursor 体验。[CODE] setup.sh:1171, AGENTS.md:1
→ Consequence: **方向变化** — 方案 B 前提（”可以安全精简 workflow.md”）被推翻。切换到方案 D（增量增强：只增不减）。已更新 Approach Analysis、Recommendation、Surface Scan、Change List、Self-Review、External Risks 全部章节。
→ Result: accepted — 方案 B→D 完整切换

**[inferred: context + fact-check-request] § Codex 新增实验性 hooks**
“根据 2026 年 3 月 10 日发布的最新 Codex Changelog... Added an experimental hooks engine with SessionStart and Stop hook events (#13276)”
→ Inferred intent: 提供新情报 + 要求验证
→ **已验证** [DOC] [Codex Changelog](https://developers.openai.com/codex/changelog/) + [GitHub Releases](https://github.com/openai/codex/releases)：Codex CLI v0.114.0 (2026-03-11) 确认新增实验性 SessionStart + Stop hook events (#13276)
→ 影响评估：仅覆盖 2/7 hook events。**无 PreToolUse**（write-lock.sh 不可用）、无 PostToolUse、无 SubagentStart、无 TaskCompleted、无 PreCompact。phase-guide.sh（SessionStart）理论上可行，但硬门控（write-lock）仍不可用。
→ Consequence: 不改变方案 D 推荐（只增不减仍是最安全策略），但更新了跨 IDE 兼容性表和 External Risks。积极信号——Codex hooks 成熟后可重新评估精简方案。
→ Result: accepted — 跨 IDE 表已更新，External Risks 已增加 Codex hooks 条目

**[inferred: question + constraint-challenge] § Codex SessionStart → 方案 B 可行性**
"phase-guide.sh 也是配置在session start hook 里面的呀 那如果codex 也有了session start hook 了 是不是就可以支持方案B了呢"
→ Inferred intent: 挑战方案 B 的排除理由——如果 Codex 有 SessionStart，Layer 2 就能工作
→ 推理链正确：phase-guide.sh 确实运行在 SessionStart → Codex 有 SessionStart → Layer 2 理论可行。
→ **额外发现**：验证过程中发现 plan 关于 Cursor 的判断有误——setup.sh:969-973 明确为 Cursor 配置了 `sessionStart` + `phase-guide.sh`。Cursor **有** Layer 2，此前 plan 错误标注为"Cursor 无 Layer 2"。
→ 修正后的约束格局：3/4 IDE 已支持 SessionStart（Claude Code、Factory、Cursor），仅 Codex 为实验性。方案 B 唯一剩余阻碍是 Codex（实验性 + setup.sh 未配置）。
→ Consequence: 方案 B 从"已排除"降级为"当前暂不可行，未来可重评"。方案 D 仍为当前推荐（零风险），但方案 B 的未来可行性显著提升。已更新：跨 IDE 表（Cursor 行）、方案 B 排除理由、Recommendation 未来演进路径。
→ Result: accepted — 方案 B 重新评估 + Cursor 错误修正 + 未来路径声明

### Round 5 (2026-03-11)

**[inferred: gap + evidence-based-challenge] § 测试契约冲突**
“这份计划里的 workflow 重构方案会直接撞上现有测试契约... Document Authority... slim/full 边界”
→ Inferred intent: 用代码证据挑战 plan 中两项改动的可行性
→ **完全正确**。验证结果：
  (1) test-workflow-consistency.sh:502-508 明确禁止 workflow.md 包含 “Document Authority”（设计守卫：meta-governance belongs in workflow-full.md）
  (2) test-workflow-consistency.sh:18-30 要求 Mindset/Action Boundaries/File Conventions/Session Handoff 在 workflow.md 和 workflow-full.md 间保持一致。这些章节在前 121 行中，删除导致 10+ 项测试失败
→ Consequence: Change #2（Document Authority）撤销 — 文档层级概念改为在 Architecture Model 中用不同措辞内联表达。Change #4（workflow-full.md 头部删除）撤销 — 维护同步由测试自动化保障。
→ 根因：plan 未先读 test-workflow-consistency.sh 就提出改动，违反了 Pre-Exit Checklist “Change specs grounded in reads”
→ Result: accepted — Change #2 和 #4 撤销，Surface Scan + Self-Review + External Risks 已更新

**[inferred: depth-issue + complexity-challenge] § Codex hooks 复杂度低估**
“Codex hooks 这部分被写成了一个小改动，但当前代码和测试都不支持这个估算”
→ Inferred intent: 指出 Codex hooks 是新能力建设，plan 低估了工作量
→ **完全正确**。证据链：configure_codex() 仅 17 行 AGENTS.md 注入 [CODE] setup.sh:1017-1034；JSON 合并函数无 TOML 能力；test-setup.sh 不覆盖 Codex hooks；test-adapters.sh 只覆盖 Cursor
→ Consequence: Change #5 改标为”新能力建设”，明确列出 4 项独立工作（TOML 生成、合并逻辑、adapter、测试）。新增 Change #7（test-setup.sh）和 #8（test-adapters.sh）
→ Result: accepted — 复杂度定性已修正，change list 扩展为 9 项（含 2 项撤销 + 4 项新增测试）

### Round 6 (2026-03-11)

**[inferred: evidence-based-challenge] § adapter-codex.sh 协议未验证**
"adapter-codex.sh 的协议设计仍然站不住... session_start 是直接读 stdout，stop 是另一套解析路径"
→ Inferred intent: 挑战 adapter 统一 JSON 输出的设计假设
→ **接受**。docs 说 stdout 统一按 JSON 解析，但 PR #13276 实现可能对不同 event type 有不同解析路径。plan 此前将 docs 描述当作确认事实，但 docs 和实现可能不一致。
→ 修正：adapter 协议行为标注为 ❓ 未验证。Change #6 增加"需实测验证"前置条件。External Risks 最大风险改为协议不匹配。
→ Result: accepted — adapter 设计降级为"待验证"，实现前需用 Codex CLI 实测

**[inferred: gap + evidence-based-challenge] § trust_level 无可执行方案**
"trust_level 这块还是没形成可执行方案... hooks 可能写出来了但根本不生效"
→ Inferred intent: 指出 trust 的落点在用户级配置而非项目级，plan 未覆盖
→ **正确**。Codex 项目级 `.codex/config.toml` 受 trust 状态约束 [DOC] Codex config docs。setup.sh 不应自动修改用户级 `~/.codex/config.toml`。
→ 修正：Change #5 增加 trust 策略——post-install 打印引导指令，不自动写用户级配置。验收条件增加"trust 引导已打印"。
→ Result: accepted — trust 落点明确为 post-install 引导

**[inferred: internal-consistency] § 残留冲突**
"Surface Scan 仍把 Document Authority 写成要改的... 技术可行性也还在说删除 workflow-full.md 头部"
→ Inferred intent: 指出撤销后文档体内部不一致
→ **正确**。已修复：Surface Scan workflow.md 行删除 Document Authority 引用、技术可行性行更新、_common.sh skip 理由更新、test-phase-guide.sh 描述更新
→ Result: accepted — 4 处残留已清理

**[inferred: gap] § 卸载/清理 lifecycle**
"计划只覆盖 install 视角... 也应该把卸载/清理和安装后提示文案一起纳入"
→ Inferred intent: 指出 lifecycle 不完整
→ **正确**。现有 uninstall 流程 [CODE] setup.sh:369-430 有 `.claude/settings.json` + `.cursor/hooks.json` 清理，但无 `.codex/config.toml` 清理。且现有 `cleanup_baton_json_hook_file` 只处理 JSON，TOML 需新建清理函数。
→ 修正：Change #5 增加卸载 lifecycle（TOML 清理函数 + 安装后文案更新）。Change #7 test-setup.sh 增加 uninstall 验证。
→ Result: accepted — 全 lifecycle 已纳入


### Round 7 (2026-03-11)

**[inferred: internal-consistency] § 协议状态不统一**
“Codex hook 协议在文档里仍然被同时写成'已确定'和'未验证'两种状态”
→ Inferred intent: 指出同一文档中协议描述前后矛盾
→ **正确**。协议差异表（line 118）、Surface Scan adapter 描述（line 270）、Self-Review（line 301）仍用确定性语言，与后文 ❓ 标注矛盾。
→ 修正：三处全部统一降级为”待验证”——协议差异表改为 ❓ 标注、Surface Scan adapter 描述去除 “stderr → stdout JSON” 断言、Self-Review 加 ❓ 前缀。
→ Result: accepted — 全文协议状态统一为”❓ 待验证”

**[inferred: internal-consistency] § Recommendation 高估 Codex 交付**
“Recommendation 仍直接写'跨 IDE 完全兼容'... 这更像 best-effort 条件支持”
→ Inferred intent: Recommendation 措辞与实际风险/前置条件不匹配
→ **正确**。Codex hooks 有 3 个前置条件（实验性稳定 + 协议验证 + trust 配置），不能算”完全兼容”。
→ 修正：Recommendation #4 改为”workflow.md 改动完全兼容；Codex hooks 为 best-effort 条件支持”。Self-Review 跨 IDE 条目同步修正。
→ Result: accepted — 措辞降级为 best-effort

**[inferred: internal-consistency] § Annotation Log 原始文本重复**
“还残留了两段未结构化的原始 review 文本... 造成重复和歧义”
→ Inferred intent: 文档卫生——结构化响应已包含引用，原始批注块纯属重复
→ **正确**。Round 3 → Round 5 间的原始批注块（原 #1-6）和 Round 5 → Round 6 间的原始批注块已被对应 Round 的结构化记录完全覆盖。
→ 修正：两段原始批注块已删除，仅保留结构化 Round 记录。
→ Result: accepted — Annotation Log 去重完成


### Round 8 (2026-03-11)

**[inferred: gap + evidence-based-challenge] § 新规则未同步到 authoritative sources**
“Change #3 把 annotation protocol 新规则只落在 workflow.md... 不该只改 workflow.md”
→ Inferred intent: 协议规则必须在所有 authoritative sources 中一致
→ **正确**。workflow-full.md (line 72) 和 baton-plan SKILL.md (line 205) 各有独立 Annotation Protocol 节，是 phase-authoritative source。只改 workflow.md 会导致 overview 和 spec 脱节。
→ 修正：新增 Change #4b（workflow-full.md 同步）+ #4c（baton-plan SKILL.md 同步）。Surface Scan 对应更新。
→ Result: accepted — 3 条规则在所有 authoritative sources 同步

**[inferred: gap] § adapter 缺前置 gate**
“Change List 里没有独立的 research/spike/gate 来承接协议验证”
→ Inferred intent: ❓ 标注不够，需要 Change List 中有显式 gate 阻止基于错误协议实现
→ **正确**。没有 gate，实现阶段会按假设协议推进，单元测试只能验证假设格式。
→ 修正：Change #6 拆为 #6a（前置 gate：Codex CLI 实测 spike）+ #6b（基于 gate 结论实现 adapter）。#6a 未通过前 #6b 和 #8 不得开始。
→ Result: accepted — 前置 gate 已建立

**[inferred: gap] § 新规则缺 drift test**
“新增的批注清理规则没有进入 protocol drift tests”
→ Inferred intent: 协议级新规则应有 test-annotation-protocol.sh drift guard
→ **正确**。现有 drift guard 覆盖 [PAUSE]、intent inference、free-text、consequence detection，但不覆盖新增的 3 条规则。
→ 修正：新增 Change #9（test-annotation-protocol.sh 新增 3 条规则 drift guard）。Surface Scan 已更新。
→ Result: accepted — drift test 已纳入

**[inferred: internal-consistency] § 复杂度摘要过时**
“顶部复杂度摘要还是旧状态... workflow-full.md 去重”
→ 修正：更新为”workflow.md 增量增强 + Annotation Protocol 三规则同步 + Codex hooks 新能力建设”
→ Result: accepted

### Round 9 (2026-03-11)

**[inferred: change-request] § Architecture Model 不应绑定 Claude Code**
“单循环模型声明 Claude Code agentic loop 是唯一控制循环 这儿太死了 不一定是在claude code中运行”
→ **正确**。Baton 是跨 IDE 工具，声明应 IDE 无关。
→ 修正：Change #1 措辞改为 “Host IDE's agentic loop”，不写死 IDE 名。
→ Result: accepted

**[inferred: gap + evidence-based-challenge] § baton-research SKILL.md 遗漏**
“baton-research 自己就有 ## Annotation Protocol (Research Phase)（SKILL.md:209）”
→ **正确**。Surface Scan 错误标注”无独立 Annotation Protocol 节”，实际 line 209 有。
→ 修正：Surface Scan 改为 modify + 新增 Change #4d + drift test (#9) 扩展覆盖 baton-research。
→ Result: accepted — 4 个 authoritative sources 全覆盖

**[inferred: gap] § Codex 能力文档 write set 偏窄**
“README / docs / test-ide-capability-consistency.sh 没拉进来”
→ **正确**。ide-capability-matrix.md / README.md / setup.sh ide_summary / test-ide-capability-consistency.sh 均描述 Codex 为 “no hooks”，与新能力不一致。
→ 修正：新增 Change #10-13 覆盖 4 个文件。Surface Scan 已更新。
→ Result: accepted — Codex 能力公开表述面完整纳入

**[inferred: gap + process-violation] § 缺独立 research.md**
“计划自己仍然违背了 Medium 任务的 research contract”
→ **正确**。workflow.md rule 9: “Medium/Large analysis tasks produce research.md”。当前研究内联在 plan.md 中，且 Change #6a spike 结论落点不明确。
→ 修正：(1) Research Source 节增加流程偏差说明 (2) Change #6a 明确 spike 结论输出到 research.md。
→ Result: accepted — research contract 偏差已记录，后续 spike 遵循

**[inferred: internal-consistency] § 批注区未自洽**
“批注区里还留着已经在 Round 1 处理完的原始批注”
→ **正确**。按新增的”批注清理”规则，已处理批注应从批注区删除。
→ 修正：已删除 Round 1 原始批注。
→ Result: accepted

### Round 10 (2026-03-11)

**[inferred: change-request] § 收紧支持边界，移除 no-skill 路径同步**
“如果不考虑no-skill的情况呢 还有就是 Annotation Protocol 这儿要同时改3个文件 而且变更的内容都是一样的”
→ Inferred intent: 将 no-skill fallback 显式排除出支持范围，并避免在多个文件复制同一批 protocol 正文
→ **正确**。`workflow-full.md` 的同步需求只来自 no-skill fallback；若该路径不在支持边界内，就不应继续把 cross-cutting 规则摊到 fallback 文档。与此同时，`baton-plan` 和 `baton-research` 仍是各自 phase 的 authoritative spec，因此保留一行引用是合理的，但不应复制规则正文。
→ Consequence: 支持边界显式收紧为 `skills required`；Change #4b 撤销，`workflow-full.md` 从 modify 改为 skip/out-of-scope；Recommendation / Surface Scan / Change List / Self-Review / External Risks 全部同步改为“1 源 2 引用”模型。
→ Result: accepted — 规则正文唯一落在 workflow.md，phase-authoritative skills 仅保留引用


### Round 11 (2026-03-11)

**[inferred: context + evidence-based-challenge] § Codex experimental hooks 最小验证路径**
"由于该功能处于实验阶段（Experimental），根据开源社区最新的适配方案，推荐的最小验证路径如下 ... 全局 hook 配置 + 绝对路径脚本 ..."
→ Inferred intent: 提供一条新的社区适配线索，挑战当前 `research.md` 中对 Codex gate 的失败归因，并要求继续推进 Codex 部分
→ 这条反馈带来了 **两条有效新线索**：
  (1) 任何验证都不应忽略 `codex_hooks` feature flag；
  (2) 绝对路径是合理的排查方向，不能只测相对路径。
  但本轮补充实测后，结论仍然是 **gate 未通过**：
  - [RUNTIME] `codex features list` 显示 `codex_hooks` 默认关闭；
  - [RUNTIME] `codex exec --enable codex_hooks` 仍未触发 `session_start` / `stop`；
  - [RUNTIME] 再把 hook command 改成绝对路径，`codex exec` 仍未触发 hooks；
  - [RUNTIME] 本机仍无法把 interactive/TUI 路径自动化，因为 Codex 对 piped stdin 直接报 `stdin is not a terminal`。
→ Consequence: **无实现方向变更，但 gate 证据被收紧**。当前可以确认的问题不只是 feature flag / cwd；`exec` 本身仍不是可信验证路径。已将这些结果回写到 `research.md`，并在 Todo / Lessons Learned 中同步。若后续要继续推进 Codex，本计划需要基于“真实 interactive/TUI + 用户级全局配置”或上游 authoritative source 重新收口，而不是直接进入 `setup.sh` 自动化或 `adapter-codex.sh` 实现。
→ Result: accepted — `research.md` 已补充 feature flag / absolute-path experiments；`plan.md` 已同步 gate 更新

### Round 12 (2026-03-11)

**[inferred: context + evidence-based-update] § Codex hook 协议验证续——Gate PASS**
"继续 @research.md 中的codex hook验证"
→ 源码分析（`codex-rs/hooks/src/engine/discovery.rs:35`）发现 hooks 从 `hooks.json` 发现，不从 `config.toml`。用 `hooks.json` 格式重跑实验后两个 hook 都成功触发。
→ 10 个实验的完整协议验证结论：
  - 配置：`.codex/hooks.json`（JSON），不是 `.codex/config.toml`（TOML）
  - 事件名：PascalCase（`SessionStart`, `Stop`）
  - SessionStart stdout：纯文本 → `additionalContext`；JSON 需复杂 schema
  - Exit code：非零 = "failed" 标签但不阻断；统一映射为 "code 1"
  - Feature flag：`codex_hooks` 默认 disabled，需显式启用
→ Consequence: **Gate 从 FAIL 翻转为 PASS**。Todos 3-5 解除阻塞。plan body 全面更新：
  - Codex Hook 协议调研节：TOML→hooks.json，❓→✅
  - Change #5：TOML 生成→hooks.json 生成
  - Change #6a：gate PASS
  - Change #6b：adapter 设计已确认（stderr→stdout）
  - Todos 3-5：移除 Blocked 标记
  - Self-Review：❓ 未验证→✅ 已验证
  - External Risks：最大风险从"协议不匹配"降级为"feature flag breaking change"
  - Lessons Learned：根因修正（配置格式错误，非 exec 不支持 hooks）
→ Result: accepted — plan 全面更新

### Round 13 (2026-03-11)

**[inferred: change-request] § trust + feature flag 自动化**
"依赖用户启用 trust + codex_hooks feature flag 最好能做成自动 用户不感知这个配置"
→ **正确**。setup.sh 本身就是用户主动运行的安装工具，已有先例为其他 IDE 写入配置。自动配置符合"安装即可用"原则。
→ 方案：(1) trust → `~/.codex/config.toml` per-project entry 自动写入 (2) feature flag → `.codex/config.toml` 项目级 `[features] codex_hooks = true` 自动写入 (3) 卸载清理三处（hooks.json + project config.toml + user config.toml trust entry）
→ Consequence: Change #5 从 "post-install 引导" 改为 "自动配置"。影响 Change #5, #7, Todo 3, Self-Review, External Risks, Recommendation。
→ Result: accepted — plan body 已全面更新

**[inferred: gap] § 从零创建场景**
"还需要考虑 如果没有.codex目录和config.toml配置"
→ **正确**。首次安装时 `.codex/` 目录、`.codex/hooks.json`、`.codex/config.toml`、`~/.codex/`、`~/.codex/config.toml` 均可能不存在。
→ 修正：Change #5 显式列出每个文件/目录的"不存在时创建"和"已存在时合并"两种路径。
→ Result: accepted

### Round 14 (2026-03-11)

**[inferred: approval] § 接受修改用户级 Codex 配置**
"有意接受"
→ Inferred intent: 明确批准 `setup.sh` 为 Codex 集成修改用户级 `~/.codex/config.toml`，撤销此前对 product boundary 的疑问。
→ 接受这条决策，并将其写入 plan body：新增 `Codex User-Config Boundary`，把用户级配置修改定义为窄范围、Baton-owned、exact-key scoped 的已批准能力；同时补入 `Codex Test Isolation` 和 `Todo Execution Notes`，要求 Codex 相关测试把 `HOME` 重定向到 temp dir，避免触碰真实用户配置。
→ Consequence: 撤回上一轮 review 中“是否允许修改用户级配置”这条 open question。剩余需要继续盯的是测试隔离和实现细节，而不是 scope 是否允许。
→ Result: accepted — plan body 已同步边界和测试约束

### Round 15 (2026-03-11)

**[inferred: scope-correction] § superpowers 冲突未被当前计划解决**
"这个计划貌似没解决 superpowers冲突的问题"
→ **正确**。当前计划只解决 Baton 自身加载架构、Codex hooks、annotation 修复；正文也明确写了 “不触碰 superpowers 插件本身”。因此它只能减少推理浪费，不能消除双 bootstrap / 双路由问题。
→ Consequence: 按用户决策拆分 scope：当前计划保留，但标题改窄为“加载架构优化 + Codex hooks + annotation 修复”；`Baton × superpowers interop` 另立 follow-up plan 处理。
→ Result: accepted — 当前计划标题与 scope note 已更新，follow-up plan 已新增

**[inferred: change-request] § 计划拆分方式**
"当前计划保留，标题改成“加载架构优化 + Codex hooks + annotation 修复”。\n  - 新增一个 follow-up plan，专门处理 Baton × superpowers interop"
→ 接受该拆分。当前文档继续作为已收敛的实现计划；superpowers 冲突改为独立 companion plan，以免继续把两个不同问题域（加载架构 / 第三方 interop）揉在同一个 change list 里。
→ Consequence: 新计划文件 `plans/plan-2026-03-11-baton-superpowers-interop.md` 建立，后续所有 superpowers 相关批注和实现讨论应转入该文档。
→ Result: accepted — split complete

<!-- BATON:GO -->

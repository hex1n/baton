Baton vs Superpowers 深度对比分析

  ---
一、核心哲学差异

┌──────────┬─────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────────┐
│   维度   │                      Baton                      │                                     Superpowers                                      │
├──────────┼─────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────┤
│ 执行模型 │ "信任但验证" — hook 硬门控 + skill 纪律         │ "说服工程" — 纯 prompt persuasion                                                    │
├──────────┼─────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────┤
│ 核心假设 │ AI 会绕过规则，需要技术强制                     │ AI 可以被 prompt 说服遵守规则（引用 Cialdini + Meincke et al. 研究，合规率 33%→72%） │
├──────────┼─────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────┤
│ 门控机制 │ write-lock.sh 硬阻断 + bash-guard.sh 选择性阻断 │ 仅 SessionStart 注入 meta-skill，无技术阻断                                          │
├──────────┼─────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────┤
│ 失败模式 │ fail-open（hook 出错时放行，但有警告）          │ 完全依赖 skill 纪律                                                                  │
└──────────┴─────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────────┘

评价: Baton 的 hook 门控是差异化优势。Superpowers 承认 prompt persuasion 只能达到 ~72% 合规率，而 BATON:GO 门控是 100% 技术阻断。但 Baton 为此付出了显著的工程复杂度（12 个 hook 脚本 + parser 库）。

  ---
二、值得参考的 Superpowers 设计

1. Skill TDD — 技能的测试驱动开发 ⭐⭐⭐

Superpowers 做法: 把 skill 文档当代码来 TDD：
- RED: 创建 3+ 压力场景，不加载 skill 运行，记录 agent 失败行为
- GREEN: 写最小 skill 修复观察到的失败
- REFACTOR: 识别 agent 新的"合理化借口"，添加反制条款，重新测试

有完整测试基础设施：headless Claude 会话集成测试、prompt 触发测试、session transcript 分析。

Baton 现状: 无 skill 测试机制。Skill 质量依赖人工审查。

可参考程度: 🟢 高。这是 Superpowers 最有价值的创新。Baton 的 skill 更复杂（带 Iron Laws、enforcement boundaries），更需要测试验证。具体可以：
- 为每个 skill 创建压力测试场景
- 验证 "合理化绕过" 是否被有效阻止
- 回归测试 skill 修改

  ---
2. Token 感知设计 ⭐⭐⭐

Superpowers 做法:
- 只在 SessionStart 加载 using-superpowers meta-skill（<200 words）
- 所有其他 skill 通过 Skill tool 按需懒加载
- 有明确 token 预算：getting-started <150 words, 常用 skill <200 words, 其他 <500 words
- 通过 analyze-token-usage.py 追踪 token 消耗

Baton 现状:
- workflow.md 通过 CLAUDE.md 的 @.baton/workflow.md 在每个会话开始时全量加载
- phase-guide.sh 在 SessionStart 输出大段 fallback guidance
- Skill 通过 /baton-* 触发时全量加载
- 无 token 预算意识

可参考程度: 🟢 高。Baton 的 workflow.md（101 行）+ phase-guide.sh fallback guidance 每个会话都占据上下文窗口。可以：
- 精简 workflow.md 为核心规则摘要，详细规则移入 skill
- phase-guide.sh 输出精简化（当 skill 可用时减少 fallback 文本）
- 为 skill 设定 token 预算

  ---
3. 两阶段 Review 流水线 ⭐⭐

Superpowers 做法: 每次实现经过两轮独立 review：
1. Spec compliance review — "你构建的是否是被要求的？"（不信任实现者的自我报告）
2. Code quality review — "构建质量如何？"（只在 spec review 通过后运行）

每个 review 角色有专用 prompt template（spec-reviewer-prompt.md, code-quality-reviewer-prompt.md）。

Baton 现状: baton-review 是单一 review，包含 phase-specific 检查（research/plan/todolist/implementation），但不区分"是否符合规格"和"代码质量"。

可参考程度: 🟡 中。两阶段 review 能防止"代码写得好但不符合需求"的盲区。Baton 可以在 baton-review 中增加显式的 spec compliance 检查步骤，但不必拆成两个独立 subagent（增加开销）。

  ---
4. 反合理化工程 ⭐⭐

Superpowers 做法: 每个 skill 包含 "rationalization table" 列举 agent 常见借口并逐一反驳：
| "Tests after work equally" | → 反驳：事后测试往往为实现辩护而非验证正确性 |
| "This is just a simple question" | → 反驳：Questions are tasks. Check for skills. |

Baton 现状: workflow.md 有一些原则（"should be fine is never valid"），baton-review 有 observability checks，但没有系统性的反合理化条款。

可参考程度: 🟡 中。Baton 的 hook 门控已经解决了一部分问题（技术上阻止绕过），但 skill-disciplined 的规则（3-failure stop, discovery stop）仍然依赖 AI 自律，加入反合理化条款有价值。

  ---
5. 多平台抽象 ⭐⭐

Superpowers 做法: 5+ 平台支持（Claude Code, Cursor, Codex, OpenCode, Gemini CLI），通过：
- 平台特定的 plugin manifest（.claude-plugin/, .cursor-plugin/）
- 文件系统 symlink（Codex, OpenCode）
- JS 插件加载器（OpenCode）
- Gemini extension（gemini-extension.json）

Baton 现状: Claude Code 完整支持 + Cursor/Codex adapter（降级执行），但 adapter 机制是手工 shell 脚本翻译。

可参考程度: 🟡 中。如果 Baton 需要更广泛的平台支持，可以参考 Superpowers 的 plugin manifest 模式。但 Baton 的 hook 门控本身就限制了移植性（依赖 PreToolUse exit code），这是架构层面的 trade-off。

  ---
6. 可视化 Brainstorming ⭐

Superpowers 做法: 零依赖 WebSocket 服务器，支持浏览器端可视化脑暴（CSS 组件库、click event recording、live reload）。

Baton 现状: 无可视化组件。

可参考程度: 🔴 低。有趣但非核心。Baton 的设计围绕 evidence-based workflow，可视化脑暴与 Baton 的"调查者而非执行者"定位不太契合。

  ---
三、Baton 已有的优势（Superpowers 缺失的）

┌──────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────┐
│                            Baton 优势                            │                   Superpowers 缺失                   │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ BATON:GO 硬门控                                                  │ 无技术写入阻断，全靠 prompt                          │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ bash-guard.sh shell 写入拦截                                     │ 无 shell 命令过滤                                    │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ Evidence Standards ([CODE], [DOC], [RUNTIME], [HUMAN] + ✅❌❓)  │ 有 verification-before-completion 但无结构化证据标签 │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ Annotation Protocol (结构化批注区 + Round-based 日志)            │ 无正式批注协议                                       │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ Complexity Calibration (Trivial/Small/Medium/Large 显式分级)     │ 隐式分级（由 skill 选择决定）                        │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ plan-parser.sh (robust plan discovery + multi-plan handling)     │ 无 plan 发现基础设施                                 │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ Session Handoff (## Lessons Learned + pre-compact.sh 上下文保存) │ 无跨会话上下文保存机制                               │
├──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ failure-tracker.sh 累计失败计数                                  │ Escalation protocol 但无自动计数                     │
└──────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────┘

  ---
四、具体改进建议（按优先级）

P0: Skill 测试框架

参考 Superpowers 的 Skill TDD 方法论。不需要完整的 headless session 测试，但至少可以：
- 为每个 skill 创建 tests/ 目录，包含 2-3 个压力场景描述
- 记录已知的"绕过行为"和对应的反制条款
- 在 skill 修改后运行回归验证

P1: Token 预算治理

- 审计 workflow.md + phase-guide.sh 每个会话的 token 开销
- 当 skill 可用时，phase-guide.sh 应输出最小化 guidance（skill 本身包含详细指导）
- 为每个 skill 设定字数上限

P2: 反合理化条款

在 baton-implement 和 baton-debug 的 Iron Laws 下增加 rationalization table，针对：
- "这次不需要 todolist"
- "这个文件改动很小，不用在 plan 里列"
- "测试通过了就行，不需要回顾"

P3: Review 两阶段化

在 baton-review 中增加显式的 Phase 0: Spec Compliance 检查，在代码质量审查之前先验证"是否符合 plan intent"。

  ---
五、总结

Superpowers = 说服工程 + 懒加载 + 多平台 + 测试驱动 skill 开发
Baton       = 技术门控 + 证据标准 + 批注协议 + 复杂度分级

互补而非竞争的关系。

最值得借鉴: Skill TDD 方法论 和 Token 感知设计 — 它们解决的是 Baton 当前最大的两个盲区：skill 质量无法验证、上下文预算无管控。

不必借鉴: 纯 prompt persuasion 执行模型 — Baton 的 hook 门控是更强的保障，降级到纯 prompt 是退步。可视化 brainstorming — 非核心能力。

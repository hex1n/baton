# Research: HITL Workflow Tools & Frameworks for AI Coding

**Date**: 2026-03-07
**Scope**: Landscape analysis of Human-in-the-Loop (HITL) tools, frameworks, and patterns relevant to AI coding/development workflows.

---

## 1. Direct Competitors / Similar Tools

### 1.1 LangGraph (LangChain)
- **What**: Graph-based agent orchestration with first-class HITL support via `interrupt()` function.
- **HITL mechanism**: `interrupt()` pauses execution, stores state in persistence layer, waits for human input, resumes with `Command(resume=...)`. Supports compile-time interrupts (`interrupt_before`, `interrupt_after`) and runtime interrupts.
- **Patterns**: Approval workflows (approve/reject), review-and-edit (human modifies LLM output before continuing), multi-step validation.
- **Strengths**: Mature checkpoint/persistence API, visual graph design, deterministic flows. The most established framework for structured HITL agent workflows.
- **Sources**:
  - [LangGraph Interrupts Docs](https://docs.langchain.com/oss/python/langgraph/interrupts)
  - [LangChain Blog: interrupt()](https://blog.langchain.com/making-it-easier-to-build-human-in-the-loop-agents-with-interrupt/)
  - [Production-ready template](https://github.com/KirtiJha/langgraph-interrupt-workflow-template)
  - [DEV Community tutorial](https://dev.to/jamesbmour/interrupts-and-commands-in-langgraph-building-human-in-the-loop-workflows-4ngl)

### 1.2 CrewAI
- **What**: Role-based multi-agent framework with HITL via task-level and flow-level mechanisms.
- **HITL mechanism**:
  - `human_input=True` on tasks: agent pauses for console input before delivering result.
  - `@human_feedback` decorator in Flows: pauses flow, presents output, collects feedback, routes to different listeners based on outcome (approved/rejected/needs_revision).
  - Custom feedback providers for production (Slack, email, webhooks instead of console).
  - Webhooks for async/production HITL: crew pauses in "Pending Human Input" state, resumes via API endpoint.
- **Limitations**: `human_input=True` on tasks runs the tool *before* asking for human input (not before execution). Community has raised this as an issue.
- **Audit**: `human_feedback_history` accessible for audit logging (step, outcome, feedback, timestamp).
- **Sources**:
  - [CrewAI Human Feedback in Flows](https://docs.crewai.com/en/learn/human-feedback-in-flows)
  - [CrewAI HITL Guide](https://help.crewai.com/how-to-use-hitl)
  - [Community discussion on pre-execution approval](https://community.crewai.com/t/human-verification-before-tool-execution/4994)

### 1.3 HumanLayer SDK
- **What**: Open-source SDK specifically designed for human-in-the-loop in AI agent workflows. Now expanded into CodeLayer (an IDE for orchestrating AI coding agents, built on Claude Code).
- **HITL mechanism**:
  - `@hl.require_approval()` decorator: blocks function execution until human approves/denies.
  - `hl.human_as_tool()`: generic tool for agent to contact human for answers/advice/feedback.
  - OmniChannel: routes approvals via Slack, Email, Discord.
  - Granular routing to specific teams/individuals.
  - Handles long-running approval states (seconds to days).
- **Framework agnostic**: Works with any LLM and all major orchestration frameworks. Python and TypeScript/JS.
- **Sources**:
  - [HumanLayer website](https://www.humanlayer.dev/)
  - [GitHub: humanlayer/humanlayer](https://github.com/humanlayer/humanlayer)
  - [Overview article](https://www.blog.brightcoding.dev/2025/08/13/humanlayer-the-missing-bridge-between-autonomous-ai-and-human-oversight/)

### 1.4 Microsoft Agent Framework (AutoGen + Semantic Kernel merger)
- **What**: Unified framework (GA Q1 2026) merging AutoGen and Semantic Kernel. Enterprise-focused.
- **HITL mechanism**: Typed, graph-based Workflow API with checkpointing, pause/resume, and HITL flows. AutoGen's `UserProxyAgent` allows humans to review/approve/modify steps during agent collaboration.
- **Enterprise features**: Built-in observability, approvals, security, long-running durability.
- **Sources**:
  - [Microsoft Agent Framework announcement](https://devblogs.microsoft.com/foundry/introducing-microsoft-agent-framework-the-open-source-engine-for-agentic-ai-apps/)

### 1.5 OpenAI Agents SDK
- **What**: Lightweight multi-agent framework with HITL and guardrails.
- **HITL mechanism**:
  - `needsApproval` option on tools (boolean or async function). Agent pauses, returns interruptions, human calls `approve()` or `reject()`.
  - Designed to be interruptible for long periods without keeping server running.
  - Guardrails: Input guardrails, output guardrails, tool guardrails with tripwire mechanism.
- **Durable orchestration**: Integrations with Temporal, Restate, and DBOS for long-running approval workflows.
- **Sources**:
  - [OpenAI Agents SDK HITL (JS)](https://openai.github.io/openai-agents-js/guides/human-in-the-loop/)
  - [OpenAI Agents SDK Guardrails](https://openai.github.io/openai-agents-python/guardrails/)
  - [Cloudflare HITL example](https://github.com/cloudflare/agents/tree/main/openai-sdk/human-in-the-loop)

### 1.6 Structured Workflow Tools (plan.md / research.md pattern)
Several tools use a file-based planning and oversight pattern similar to Baton:
- **SDD-Pilot** ([GitHub](https://github.com/attilaszasz/sdd-pilot)): Spec-driven development with specialized AI roles. Uses `plan.md` for implementation plans and `research.md` for technology research.
- **Agent Instructions MD** ([GitHub](https://github.com/Montimage/agent-instructions-md)): Three-phase workflow (Research -> Plan -> Execute) generating `research.md` and `plan.md`. Installable as a Claude Code skill.
- **Planning With Files** ([GitHub](https://github.com/OthmanAdi/planning-with-files)): Claude Code skill using `task_plan.md`, `findings.md`, `progress.md`. "Never start without task_plan.md."
- **Claude Workflow V2** ([GitHub](https://github.com/CloudAI-X/claude-workflow-v2)): 7 specialized agents, 26 slash commands, includes plan.md-based planning.
- **Ralph Wiggum** ([GitHub](https://github.com/fstandhartinger/ralph-wiggum)): Autonomous loop with `IMPLEMENTATION_PLAN.md`, iterative self-correction.
- **Harper Reed's workflow** ([blog](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/)): `prompt_plan.md` + `todo.md` pattern.

**Key observation**: None of these enforce a human approval gate via structured protocol the way Baton does with `BATON:GO`. They rely on advisory instructions in markdown, which the AI may ignore during long sessions.

---

## 2. HITL Best Practices and Patterns

### 2.1 Approval Gates / Checkpoints
- **Pattern**: Pause execution at critical decision points; require explicit human approval before proceeding.
- **Implementation approaches**:
  - Decorator-based (`@require_approval`, `@human_feedback`)
  - Graph-based (`interrupt()` in LangGraph)
  - Compile-time (`interrupt_before=["node_name"]`)
  - File-based markers (e.g., `BATON:GO` in plan.md)
- **Best practice**: Bounded autonomy -- agents act on predictable work, humans intervene on exceptions. Over-scoping HITL creates bottlenecks; the challenge is identifying *which* decision points warrant human review.
- **Sources**: [Permit.io HITL Guide](https://www.permit.io/blog/human-in-the-loop-for-ai-agents-best-practices-frameworks-use-cases-and-demo), [Zapier HITL Patterns](https://zapier.com/blog/human-in-the-loop/)

### 2.2 Structured Feedback Mechanisms
- **Annotation-based**: Human marks up outputs with typed annotations ([NOTE], [Q], [CHANGE], [DEEPER]).
- **Outcome-based**: Approve / Reject / Needs Revision routing (CrewAI `@human_feedback`).
- **Review-and-edit**: Human modifies LLM output before it continues downstream (LangGraph pattern).
- **Best practice**: Concise, relevant feedback helps maintain task focus. Irrelevant details in feedback negatively influence subsequent executions (CrewAI docs).

### 2.3 Escalation Policies
- **Pattern**: When agents encounter ambiguity, low confidence, compliance rule hits, or failures, they escalate to humans via configured channels.
- **Triggers**: Confidence below threshold, repeated failures (Baton: "same approach fails 3x -> MUST stop"), permission boundaries, compliance rules.
- **Routing**: To specific teams/individuals based on decision type. OmniChannel (Slack, email, Discord).
- **Sources**: [OneReach HITL Agentic AI](https://onereach.ai/blog/human-in-the-loop-agentic-ai-systems/), [Moxo HITL Governance](https://www.moxo.com/blog/human-in-the-loop-ai-governance)

### 2.4 Audit Trails
- **Pattern**: Every HITL checkpoint produces contextual records: who reviewed, what decision was made, why exceptions were triggered.
- **Purpose**: Compliance (SOC 2, EU AI Act), accountability (every action has a reviewer), continuous improvement (corrections become training data).
- **Implementation**: Decision dashboards, structured logs with timestamps, feedback history APIs.
- **Sources**: [WitnessAI HITL](https://witness.ai/blog/human-in-the-loop-ai/), [Parseur HITL Guide](https://parseur.com/blog/human-in-the-loop-ai)

### 2.5 Rollback Mechanisms
- **Pattern**: Before executing irreversible actions, pause for human review. Log full decision trail for post-hoc rollback.
- **Examples**: Database changes, production deployments, file deletions, external API calls.
- **Best practice**: Any action that could lead to data loss or permanent errors needs a HITL checkpoint.
- **Git-based rollback**: Many AI coding tools rely on git as the rollback mechanism -- if the AI makes bad changes, revert the commit.

---

## 3. Open Source HITL Frameworks

| Framework | Language | HITL Mechanism | Primary Use Case |
|---|---|---|---|
| **LangGraph** | Python/JS | `interrupt()`, checkpointing | Agent orchestration with structured workflows |
| **CrewAI** | Python | `@human_feedback`, `human_input=True`, webhooks | Multi-agent teams with role-based collaboration |
| **HumanLayer** | Python/JS | `@require_approval`, `human_as_tool()` | Drop-in HITL for any agent framework |
| **OpenAI Agents SDK** | Python/JS | `needsApproval`, guardrails | Lightweight multi-agent with tool approval |
| **AutoGen** | Python | `UserProxyAgent` | Multi-agent conversations with human participant |
| **Cline** | TypeScript | Approval prompts before risky actions | AI coding in VS Code |
| **Strands Agents** | Python | Conditional branches, approval checks | Complex decision workflows |
| **Superagent** | Python | Safety-first agent execution | Guardrails around agentic AI |

**Dedicated HITL-only tools** (not full agent frameworks):
- **HumanLayer** is the only open-source project positioned specifically as a HITL middleware layer, framework-agnostic, designed to be dropped into any agent system.
- **Baton** (this project) occupies a unique niche: file-based, protocol-driven HITL specifically for AI coding workflows, enforced via markdown conventions and git hooks rather than SDK decorators.

---

## 4. How AI Coding Tools Handle Human Oversight Currently

### 4.1 Claude Code
- **Permission system**: Asks for confirmation before executing Bash commands (tool-level approval).
- **Hooks system** (v2.0+): Deterministic lifecycle hooks (PreToolUse, PostToolUse, PermissionRequest, etc.). Can auto-allow, auto-deny, or gate actions programmatically. Recommended over `--dangerously-skip-permissions`.
- **Quality gates**: Stop hooks run automated checks when Claude says it's done.
- **Allow/deny lists**: Declarative auto-approval policy in settings.json.
- **Enterprise**: Organization managed policies can restrict dangerous flags.
- **Weakness**: No structured planning/approval protocol built-in. CLAUDE.md instructions are advisory (can be ignored in long sessions). No native plan-then-approve workflow.
- **Sources**: [Claude Code Hooks Guide](https://www.morphllm.com/claude-code-hooks), [DataCamp Hooks Tutorial](https://www.datacamp.com/tutorial/claude-code-hooks)

### 4.2 Cursor
- **Auto-Run toggle**: Binary all-or-nothing. Either asks for everything or runs non-allow-listed commands automatically.
- **Preview-before-apply**: Shows diffs before applying changes.
- **Rules files**: `.cursor/rules/` for baking constraints into the file system.
- **Privacy Mode**: Zero-retention data routing.
- **Weakness**: No granular permission controls ("nothing in between" per developer feedback). Limited enterprise audit capabilities. No built-in detailed audit log of AI activities.
- **Sources**: [Cursor AI Review 2025](https://skywork.ai/blog/cursor-ai-review-2025-agent-refactors-privacy/), [Cursor Enterprise Review](https://www.superblocks.com/blog/cursor-enterprise)

### 4.3 GitHub Copilot (Agent Mode + Coding Agent)
- **Workflow approval gates**: Actions workflows don't trigger until code is reviewed and a user with write access clicks "Approve and run workflows."
- **Independent review requirement**: Developer who asked Copilot to create a PR cannot approve it.
- **Limited agent permissions**: Cannot mark PRs as "Ready for review", cannot approve or merge PRs.
- **Mission Control**: Dashboard to see running agent tasks, review progress, intervene when stalled.
- **Enterprise AI Controls** (GA Feb 2026): Agent control plane with audit log filtering by agent, API support for enterprise-wide custom agent definitions.
- **Plan mode**: Copilot CLI presents execution plan, user confirms before execution.
- **Strongest built-in oversight** of the AI coding tools surveyed.
- **Sources**: [GitHub Enterprise AI Controls](https://github.blog/changelog/2026-02-26-enterprise-ai-controls-agent-control-plane-now-generally-available/), [Copilot Coding Agent Docs](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)

### 4.4 Windsurf (now Cognition/Devin)
- **Turbo Mode**: Autonomous command execution. Major time saver but introduces risk.
- **No granular controls**: Similar to Cursor's all-or-nothing approach.
- **Oversight model**: "Treat it like a fast junior developer, not an autopilot." Review all diffs.
- **Enterprise**: FedRAMP, HIPAA, DoD certifications, but limited developer-facing oversight controls.
- **Known issues**: Security vulnerabilities (SQL injection, unvalidated input) caught only during manual audits of Cascade-written endpoints.
- **Sources**: [Windsurf Review 2026](https://www.secondtalent.com/resources/windsurf-review/), [AI Code Editors Comparison](https://www.codeant.ai/blogs/best-ai-code-editor-cursor-vs-windsurf-vs-copilot)

### 4.5 Cline
- **Approval-gated autonomy**: Requests approval before risky actions. Ties agent plans to tests.
- **In-editor traceability**: Keeps work inside the repo and editor.
- **Sources**: [Cline: Top 11 Open-Source Agents](https://cline.bot/blog/top-11-open-source-autonomous-agents-frameworks-in-2025)

---

## 5. Key Insights & Gaps

### What exists broadly:
1. **Tool-level approval** (approve this command / this function call) -- most tools do this.
2. **Framework-level HITL** (interrupt/resume in agent graphs) -- LangGraph, CrewAI, OpenAI SDK.
3. **Enterprise audit/policy** -- GitHub Copilot leads, Claude Code hooks are flexible, Cursor/Windsurf lag.

### What is rare or missing:
1. **Protocol-level oversight for AI coding** -- enforcing a research -> plan -> approve -> implement workflow as a protocol, not just advisory instructions. Baton's `BATON:GO` marker and annotation system occupy this niche.
2. **Structured disagreement mechanisms** -- most tools treat the human as the approver and the AI as the executor. Baton's principle of "disagree with evidence" (AI pushes back on human decisions with file:line citations) is uncommon.
3. **File-based, git-native HITL** -- most HITL frameworks are SDK/API-based. Using markdown files + git hooks as the enforcement layer is a distinctive approach.
4. **Complexity calibration** -- dynamically adjusting the level of oversight based on task complexity is not a standard feature in any tool surveyed.
5. **Annotation protocols** -- typed feedback ([NOTE], [Q], [CHANGE], [DEEPER], [MISSING]) with mandatory response and logging is unique to Baton among tools surveyed.

### Industry trends:
- The "80% problem" is widely recognized: AI gets 80% of the way, but the last 20% requires human oversight. Quality gates (stop hooks, test verification) are the emerging solution.
- Developer trust remains low (DeveloperWeek 2026): developers don't trust AI tools and spend significant time reworking AI-generated code.
- Regulatory pressure increasing: EU AI Act, 700+ US AI bills. HITL systems can lower risk classification.
- The market is bifurcating: lightweight advisory (CLAUDE.md, .cursor/rules) vs. deterministic enforcement (hooks, approval gates, graph-based interrupts). The trend is toward the latter.

---

## 6. Baton 现有 HITL 能力审计

### 6.1 能力映射

| HITL 概念 | Baton 实现 | 文件:行 | 评估 |
|-----------|-----------|---------|------|
| **Approval Gate** | `<!-- BATON:GO -->` write-lock | `write-lock.sh:91` — `grep -q '<!-- BATON:GO -->'` | ✅ 技术强制，不可绕过（除 BATON_BYPASS=1） |
| **Write Protection** | PreToolUse hook 拦截 Edit/Write/MultiEdit/CreateFile | `write-lock.sh:5` — hook 声明 | ✅ 覆盖所有写操作 |
| **Structured Feedback** | 6 种标注类型 (NOTE/Q/CHANGE/DEEPER/MISSING/RESEARCH-GAP) | `workflow.md:61-67` | ✅ 行业独特，比 approve/deny 更丰富 |
| **Phase Orchestration** | 4 阶段流程 RESEARCH→PLAN→ANNOTATION→IMPLEMENT | `workflow.md:14-18` | ✅ 但硬编码，不可自定义 |
| **Complexity Calibration** | 4 级复杂度 Trivial/Small/Medium/Large | `workflow.md:21-27` | ✅ 独特设计，动态调整流程深度 |
| **Scope Control** | 只能修改 plan 中列出的文件 | `workflow.md:33` | ✅ 规则强制（prompt-based，非技术强制） |
| **Escalation** | 3x 失败 → 停止并报告 | `workflow.md:34` | ✅ prompt-based 升级策略 |
| **Evidence Standard** | file:line 引用 + ✅❌❓ 状态标记 | `workflow.md:40-50` | ✅ 行业独创，确保可验证性 |
| **Session Handoff** | Lessons Learned + Annotation Log 归档 | `workflow.md:91-94` | ✅ 跨会话上下文保持 |
| **Progress Tracking** | Todo list + completion-check hook | `workflow.md:86` | ✅ 可检查的进度追踪 |
| **Stop Guard** | Stop hook 提醒未完成任务 | `stop-guard.sh` | ✅ 防止中途退出 |

### 6.2 HITL 差距分析

| 缺失能力 | 行业标准 | 影响 | 优先级 |
|----------|---------|------|--------|
| **可编程 workflow** | LangGraph 图定义 / 自定义节点 | 当前 4 阶段流程硬编码在 workflow.md 和 hooks 中 | 🔴 高 |
| **持久化 / 状态恢复** | LangGraph checkpointer | 中断后依赖文件系统 plan.md 恢复，无结构化状态 | 🟡 中 |
| **Audit trail** | 结构化日志 + 时间戳 | Annotation Log 在 markdown 中，无机器可读格式 | 🟡 中 |
| **多渠道通知** | HumanLayer Slack/Email | 当前只在 IDE 内交互，无异步通知 | 🟢 低 |
| **HITL 术语体系** | 标准 HITL 概念命名 | 自创术语（BATON:GO, 批注区），行业不可识别 | 🔴 高 |
| **API / SDK** | 可编程接口 | 只有 CLI + shell hooks，无 API | 🟡 中 |
| **指标 / 度量** | 审批率、修改率、平均审批时间 | 无任何度量数据收集 | 🟢 低 |
| **Rollback 机制** | 自动回滚到上一个 approved 状态 | 手动 git revert | 🟡 中 |
| **Per-change approval** | 逐项审批高风险变更 | BATON:GO 一旦设置，所有 todo 项无需逐一审批 | 🟡 中 |
| **Diff review gate** | 人类审阅实际代码差异 | 人类只审批 plan（意图），不审阅生成的代码（输出） | 🔴 高 |
| **自动化验证集成** | 测试/lint 自动运行 | workflow 规则说"运行测试"但无技术强制 | 🟡 中 |
| **时限/范围审批** | 审批可过期、可限定范围 | BATON:GO 永久有效直到手动移除 | 🟢 低 |
| **升级策略强制** | hook 强制升级策略 | "3x 失败→停止"仅为 prompt 规则，无 hook 强制 | 🟡 中 |

### 6.3 Baton 的独特差异化

1. **Plan-first workflow** — 没有竞品要求"先调研、再计划、再批注、最后实现"的全流程人类参与。LangGraph/HumanLayer 只有 approve/deny 单点审批。
2. **结构化反馈协议** — 6 种标注类型比简单的 approve/deny 丰富得多。这是真正的"shared understanding construction"，不只是"人类盖章"。
3. **零依赖 + IDE 无关** — 纯 shell 实现，10+ IDE 支持。竞品全部需要 Python/TS runtime。
4. **Evidence Standard** — file:line 引用 + 三状态标记（✅❌❓）是行业独创。确保 AI 的每个声明都可验证。
5. **Complexity Calibration** — 根据任务复杂度自动调整流程深度。没有竞品有这个概念。
6. **技术强制 vs 建议式** — write-lock.sh 是 deterministic enforcement，不是 advisory instructions。

### 6.4 竞品对比矩阵

| 特性 | Baton | LangGraph | HumanLayer | AG2 | OpenAI SDK |
|------|-------|-----------|------------|-----|------------|
| LLM 无关 | ✅ | ❌(LangChain) | ✅ | ✅ | ❌(OpenAI) |
| IDE 集成 | ✅ 10+ IDE | ❌ | ✅(CodeLayer) | ❌ | ❌ |
| 零依赖 | ✅ shell-only | ❌ Python | ❌ Python/TS | ❌ Python | ❌ TS |
| Plan-first workflow | ✅ | ❌ | ❌ | ❌ | ❌ |
| 结构化反馈 | ✅ 6种标注 | ❌ 自由文本 | ❌ approve/deny | ❌ | ❌ |
| Write-lock 强制 | ✅ 技术强制 | ❌ | ❌ | ❌ | ❌ |
| 多渠道通知 | ❌ | ❌ | ✅ Slack/Email | ❌ | ❌ |
| 可编程 workflow | ❌ 硬编码 | ✅ 图定义 | ✅ API | ✅ | ✅ |
| 持久化/恢复 | ❌ 文件态 | ✅ checkpoint | ✅ 平台 | ✅ | ✅ |
| Audit trail | ⚠️ plan.md | ✅ checkpoint | ✅ 平台 | ⚠️ | ⚠️ |

---

## 7. 转型路径分析

### 7.1 建议定位

> **Baton: Plan-First HITL Workflow for AI Coding Agents**
>
> 不是 approve/deny 的单点审批，而是从研究到实现的全流程人类参与。
> 不是 SDK 级的 runtime 中间件，而是 IDE 级的 workflow enforcement。

关键差异化：
- **竞品做的是 "gate"**（在执行前设一个关卡）
- **Baton 做的是 "workflow"**（定义从调研到实现的完整协作流程）

### 7.2 方案比较

| 方案 | 描述 | 优点 | 缺点 | 推荐 |
|------|------|------|------|------|
| **A: 品牌重塑** | 保持代码不变，用 HITL 术语重写文档 | 风险低，快速 | 只是换皮 | ❌ |
| **B: 概念层 + 可配置 workflow** | 引入 HITL 概念层 + workflow 可配置 + 事件系统 + 文档重写 | 实质提升 + 保持轻量 | 需要设计配置 DSL | ✅ 推荐 |
| **C: 完整 HITL 平台** | 引入 runtime、API server、GUI | 功能齐全 | 失去核心优势 | ❌ |

### 7.3 方案 B 详细说明

1. **HITL 概念层**: 将自创术语映射到标准 HITL 概念
   - `BATON:GO` → approval gate
   - 标注协议 → structured feedback protocol
   - 4 阶段流程 → workflow phases
   - 复杂度校准 → oversight calibration

2. **可配置 workflow**: `.baton/workflow.yml` 定义流程
   - 允许用户自定义阶段、跳过条件、审批策略
   - 保持默认 4 阶段流程作为 preset

3. **事件系统**: 标准化生命周期事件
   - `approval_requested`, `approval_granted`, `feedback_submitted`
   - 可对接 webhook/Slack/外部系统

4. **文档重写**: README + 文档用 HITL 术语

### 7.4 ❓ 开放问题

1. 是否要保留纯 shell 实现？还是引入 Node.js/Python 以获得更好的可编程性？
2. 是否需要 GUI？当前纯 CLI + markdown 交互足够吗？
3. 目标用户是个人开发者还是团队？这决定是否需要多人审批、角色权限等功能。
4. 是否需要与 LangGraph/CrewAI 等框架集成？还是保持独立？

---

## 批注区


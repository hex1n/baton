# AI 编码代理工具原语研究

## Step 0: 调查框架

- **Question**: Claude Code 中 TaskCreate/TaskUpdate 等工具有哪些？Codex、Cursor、FactoryAI 等平台有哪些类似或独特的工具原语？哪些对 Baton 有用？
- **Why**: 评估 Baton 可以利用的工具能力，指导后续改进方向
- **Scope**: 各平台 AI agent 可调用的工具原语（不含纯 UI 功能）
- **Out of scope**: 具体实现代码、定价、部署架构
- **System goal**: 发现 Baton 治理框架可利用的新工具原语
- **Familiarity**: partial（熟悉 Claude Code，不熟悉其他平台内部）
- **Evidence type**: external-primary
- **Strategy**: 多平台并行调研 → 分类对比 → 评估 Baton 适用性

---

## Step 1: Claude Code 完整工具清单

✅ 已通过 ToolSearch 获取完整 schema

### 任务管理

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **TaskCreate** | 创建带 subject/description/metadata 的任务 | ✅ baton-implement 已用（Claude Code only） |
| **TaskUpdate** | 更新状态(pending/in_progress/completed/deleted)、owner、依赖关系(blocks/blockedBy) | ✅ 已用 |
| **TaskList** | 列出所有任务摘要 | ❓ 未显式集成 |
| **TaskGet** | 获取单个任务完整详情 | ❓ 未显式集成 |
| **TaskOutput** | 获取后台任务/agent 输出 | ❌ 未用 |
| **TaskStop** | 停止运行中的后台任务 | ❌ 未用 |

### 计划/工作流

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **EnterPlanMode** | 进入计划模式，探索后呈现方案给用户审批 | ❌ 被 BATON:GO 替代 |
| **ExitPlanMode** | 退出计划模式，请求用户批准，含 allowedPrompts | ❌ 同上 |
| **EnterWorktree** | 创建隔离 git worktree | ❌ 未用 |
| **ExitWorktree** | 退出 worktree（保留或删除） | ❌ 未用 |

### 调度

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **CronCreate** | 用 cron 表达式调度定时/一次性 prompt | ❌ 未用 |
| **CronDelete** | 取消定时任务 | ❌ 未用 |
| **CronList** | 列出所有定时任务 | ❌ 未用 |

### 用户交互

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **AskUserQuestion** | 结构化多选/单选问题，支持 preview、multiSelect | ❓ 隐式使用（通过对话） |

### 子代理

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **Agent** | 启动专业子代理（explore/plan/general 等），支持 worktree 隔离 | ✅ 核心机制（review 隔离） |

### Web/外部

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **WebSearch** | 网页搜索 | ❌ 未集成到技能 |
| **WebFetch** | 获取并处理 URL 内容 | ❌ 未集成到技能 |

### 其他

| 工具 | 能力 | Baton 现状 |
|------|------|-----------|
| **NotebookEdit** | 编辑 Jupyter notebook | N/A |
| **Read/Write/Edit/Glob/Grep/Bash** | 基础文件/搜索/执行 | ✅ 日常使用 |

---

## Step 2: Codex CLI 工具清单

✅ 通过 GitHub 源码 + 官方文档验证

### Codex 独有 / Claude Code 缺失的原语

| 工具 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **update_plan** | 结构化计划步骤 + 状态追踪（pending/in_progress/completed），UI 渲染为 checklist | ⭐⭐⭐ 比 TaskCreate 更轻量的计划可视化 |
| **spawn_agent + wait_agent + send_input + close_agent + resume_agent** | 完整多代理编排：类型化角色(Explorer/Worker)、交互通信、生命周期管理 | ⭐⭐⭐ 比 Claude Code Agent 更精细的并行控制 |
| **spawn_agents_on_csv** | CSV 批量派发：每行一个 worker，MapReduce 模式，最大 64 并发 | ⭐⭐ 批量操作场景 |
| **exec_command + write_stdin** | 交互式 PTY：持久终端会话，部分输出，写入 stdin | ⭐⭐ 长时间运行进程交互 |
| **js_repl** | 持久 JS REPL，变量跨调用保持 | ⭐ 计算验证场景 |
| **request_permissions** | 运行时请求权限提升 | ⭐⭐ 对应 Baton 的"超出 write set"场景 |
| **request_user_input** | 结构化多选问题（类似 AskUserQuestion） | — Claude Code 已有 |
| **tool_suggest** | 主动建议安装新工具/连接器 | ⭐ 生态扩展 |
| **apply_patch** | diff 格式文件编辑（vs Claude Code 的精确字符串匹配） | ⭐⭐ 大范围编辑更鲁棒 |
| **read_file indentation mode** | 缩进感知的代码块提取 | ⭐ 代码理解 |
| **MCP 资源浏览** (list_mcp_resources/read_mcp_resource) | MCP 资源发现和读取 | ⭐ 工具生态 |

---

## Step 3: Cursor 工具清单

✅ 通过泄露 system prompt + 官方文档验证

### Cursor 独有 / 值得注意的原语

| 工具/机制 | 能力 | Baton 价值评估 |
|----------|------|---------------|
| **codebase_search** | 语义嵌入搜索（按含义找代码，非文本匹配） | ⭐⭐ 研究阶段更高效的代码发现 |
| **todo_write** | 简化任务列表 `{id, content}` | — 比 TaskCreate 更简单但功能更少 |
| **reapply** | 上次编辑通过更强模型重新应用 | ⭐ 编辑失败的自动修复 |
| **read_lints** | 直接读取 IDE linter 诊断 | ⭐⭐ 实现阶段的质量检查 |
| **fetch_rules** | 动态加载 `.cursor/rules/` 规则 | — Baton 已有 constitution + 技能 |
| **Parallel Agents + worktrees.json** | 最多 8 个并行 agent，各自独立 worktree | ⭐⭐⭐ 比 Agent tool 更系统化的并行 |
| **Cursor Automations** | 云端 agent + 事件触发（cron/GitHub/Slack/Linear/PagerDuty） | ⭐⭐⭐ 持久自动化，超越会话范围 |
| **Prompt-based hooks** | Hook 条件由 LLM 评估（自然语言，非 shell 脚本） | ⭐⭐ 更灵活的治理执行 |
| **Browser subagent** | 内置浏览器自动化（截图、导航、交互） | ⭐ 前端验证 |
| **Checkpoints** | 每次编辑前自动快照，可回退 | ⭐⭐ 比 git 更细粒度的状态保护 |
| **diff_history** | 访问近期变更历史 | ⭐ 上下文理解 |

---

## Step 4: Factory AI / 其他平台

✅ 通过官网文档 + 技术报告验证

### Factory AI (Droids)

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Missions** | 多功能项目编排：特性分解 → 里程碑 → 验证 worker | ⭐⭐⭐ 最接近 Baton 的多阶段治理 |
| **HyperCode/ByteRank** | 图 + 潜空间代码库表示 | ⭐⭐ 代码理解 |
| **DroidShield** | 提交前实时静态分析 | ⭐⭐ 安全门禁 |
| **Multi-model routing** | 不同子任务路由到不同模型 | ⭐⭐ 研究用高推理、实现用快速模型 |
| **Milestone Validation Workers** | 里程碑完成时自动验证 | ⭐⭐⭐ 形式化完成条件检查 |
| **Background Execution** | 异步进程管理 | ⭐⭐ 测试/构建并行执行 |

### Devin (Cognition)

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Interactive Planning Checkpoints** | 执行前展示计划+相关文件，等待批准 | ⭐⭐⭐ 直接对应 BATON:GO 门禁 |
| **Planner/Coder/Critic 三代理** | 对抗性审查 | ⭐⭐⭐ 对应 Baton 的分层防御模型 |
| **Playbooks** | 可重用流程模板 | — Baton 的 phase skills 已实现 |
| **Knowledge Items** | 自动召回的持久知识 | ⭐⭐ 比 memory 更智能的上下文召回 |
| **Confidence self-assessment** | 内置不确定性表达 | ⭐⭐ 对应 Baton 的 ❓ 标记 |

### Aider

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Architect/Editor 分离** | 推理模型 vs 编辑模型 | ⭐⭐⭐ 直接对应研究/计划 vs 实现的分离 |
| **Git-as-state** | 每次变更自动提交 | ⭐⭐ 审计轨迹 |
| **Repo Map** | Tree-sitter 函数签名图谱 | ⭐⭐ 上下文选择 |

### Windsurf

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Named Checkpoints + Revert** | 显式状态快照 | ⭐⭐⭐ 可回退的批准门禁 |
| **Dual Planning** | 后台战略规划 + 前台战术执行 | ⭐⭐ 计划/执行分离 |
| **`.codeiumignore`** | 文件级访问控制 | ⭐⭐ 对应 Baton 的 write set |

### GitHub Copilot

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Requester-Cannot-Self-Approve** | 请求者不能批准自己的 PR | ⭐⭐⭐ 强制独立审查 |
| **Draft PR as Approval Gate** | 人工批准前不触发 CI/CD | ⭐⭐ 批准门禁 |
| **Session Logs** | 每步操作日志 | ⭐⭐ 审计轨迹 |

### Continue.dev

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **Per-Tool Permission Gate** | 每次工具调用的批准机制 | ⭐⭐⭐ 最细粒度的权限控制 |
| **Plan Mode = Read-Only** | 模式强制只读 | ⭐⭐ 对应 Baton UNDERSTANDING/PROPOSING 只读 |

### Amazon Q

| 机制 | 能力 | Baton 价值评估 |
|------|------|---------------|
| **5 专用 Agent** | 代码生成/转换/文档/测试/审查各一个 | ⭐⭐ 角色化分工 |
| **Plan-then-Approve** | 显式人工批准门禁 | — 与 BATON:GO 同理 |

---

## Step 5: 对 Baton 最有价值的发现（按优先级）

### Tier 1: 高价值，可直接利用

| # | 发现 | 来源 | Baton 应用方向 |
|---|------|------|---------------|
| 1 | **TaskUpdate 的 blocks/blockedBy 依赖关系** | Claude Code | baton-implement 可用依赖关系表达 Todo 项间的顺序约束，而非纯序号 |
| 2 | **TaskUpdate 的 owner 字段** | Claude Code | baton-subagent 可将 owner 设为子代理名称，实现任务认领 |
| 3 | **TaskOutput 读取后台任务结果** | Claude Code | 验证阶段：启动测试为后台任务，继续其他工作，再检查结果 |
| 4 | **AskUserQuestion 的结构化 preview** | Claude Code | 计划审批可用 preview 展示方案对比，而非纯文本 |
| 5 | **CronCreate 定时健康检查** | Claude Code | 长任务定时提醒更新 Lessons Learned、检查 plan 健康度 |
| 6 | **Agent 的 worktree 隔离** | Claude Code | baton-subagent 可用 `isolation: "worktree"` 避免并行写冲突 |

### Tier 2: 高价值，需要设计适配

| # | 发现 | 来源 | Baton 应用方向 |
|---|------|------|---------------|
| 7 | **Interactive Planning Checkpoints** | Devin | 在 BATON:GO 前展示相关文件 + 影响分析，节省无效执行 |
| 8 | **Planner/Coder/Critic 三角色** | Devin | 研究/实现/审查使用不同模型配置（reasoning effort 分级） |
| 9 | **Named Checkpoints + Revert** | Windsurf | 在 APPROVED→EXECUTING 等关键状态转换时创建 git tag/commit，支持回滚 |
| 10 | **Milestone Validation Workers** | Factory | 计划中每个里程碑关联自动验证脚本，而非仅最终验证 |
| 11 | **Per-Tool Permission Gate** | Continue.dev | 用 hooks 实现基于状态的工具权限（PROPOSING 时 block Write/Edit） |

### Tier 3: 概念有价值，当前平台不直接支持

| # | 发现 | 来源 | 为什么暂时不可行 |
|---|------|------|-----------------|
| 12 | **spawn_agent + wait_agent + send_input** | Codex | Claude Code 的 Agent tool 不支持交互通信和等待 |
| 13 | **codebase_search（语义搜索）** | Cursor | 需要嵌入索引基础设施，Claude Code 无此能力 |
| 14 | **Cursor Automations（事件触发）** | Cursor | 云端持久 agent，超出 CLI 会话范围 |
| 15 | **Multi-model routing** | Factory | Claude Code 的 Agent 支持 model 参数（sonnet/opus/haiku），但粒度有限 |
| 16 | **read_lints** | Cursor | 需要 IDE LSP 集成，CLI 环境无原生 linter 接口 |

---

## Self-Challenge

### 最弱结论是什么？
Tier 2 的"需要设计适配"项目，实际工程量可能被低估。例如 "Named Checkpoints" 说起来是 git tag，但在 Baton 的文本标记体系中如何融合、何时触发、回滚语义是什么——这些都需要具体设计。

### 我没调查什么？
1. **实际用户反馈**：各平台用户对这些工具原语的真实使用频率和满意度 ❓
2. **性能开销**：TaskCreate/TaskUpdate 等工具调用的 token 消耗和延迟 ❓
3. **Gemini CLI / Windsurf CLI**：Gemini 2.5 的 CLI 工具原语未调查 ❓
4. **MCP 生态**：哪些 MCP server 提供了类似的任务管理/工作流原语 ❓

### 未验证的假设
1. ❓ 假设 Claude Code 的 Agent `isolation: "worktree"` 在 macOS 上稳定——未实际测试
2. ❓ 假设 TaskUpdate 的 blocks/blockedBy 在实际并行场景中表现良好——未测试
3. ❓ 假设 CronCreate 的 3 天过期限制对 Baton 长任务够用——需确认

---

## Final Conclusions

### One-Sentence Summary
Claude Code 已有的 Task 依赖管理、后台任务、结构化提问、定时调度、worktree 隔离等能力尚未被 Baton 充分利用；外部平台中 Devin 的交互式计划检查点、Factory 的里程碑验证、Windsurf 的命名检查点最值得借鉴。

### Actionable（可直接行动）
1. baton-implement 使用 `blocks/blockedBy` 表达 Todo 依赖
2. baton-subagent 使用 `owner` + `isolation: "worktree"`
3. 验证阶段使用 `TaskOutput` + 后台 Bash 实现异步测试
4. 计划审批使用 `AskUserQuestion` + preview 展示方案对比
5. 长任务使用 `CronCreate` 定时健康检查

### Watchlist（关注但不立即行动）
6. Codex 的多代理编排能力（spawn_agent/wait_agent/send_input）——等 Claude Code 增强
7. Cursor 的语义搜索——等 MCP 或 Claude Code 内置
8. Agent tool 的 `model` 参数用于分层 reasoning effort

### Judgment-Needed（需人工判断）
9. 是否在状态转换时自动创建 git tag（增加复杂度 vs 回滚保障）
10. 是否用 hooks 实现基于状态的工具权限（已有 write-lock，是否需要更多）
11. CronCreate 的 3 天过期是否满足需求，还是需要外部调度

---

## Questions for Human Judgment

1. **优先级**：上述 Tier 1 的 6 项，你认为哪些最值得先做？
2. **范围**：是否要把这些发现转化为一个改进计划？还是先选几个试验？
3. **平台绑定**：目前 Baton 有 "In Claude Code" 条件分支。是否要更系统地做平台适配层？
   需要
4. **Codex 兼容**：Baton 是否需要考虑 Codex CLI 的兼容性？（它的工具体系差异较大）
   需要
---

## 批注区
1. 计划审批使用 `AskUserQuestion` + preview 展示方案对比 是不是就可以去掉 BATON:GO了
2. 还需要考虑cursor 兼容

---

## 批注回应

### 批注 1: AskUserQuestion 能否替代 BATON:GO？

**结论：不能完全替代，但可以重新设计审批机制。**

当前 BATON:GO 的三个功能：
1. **审批凭证** — 人确认"可以开始执行"
2. **持久化记录** — plan.md 中的文本标记，跨会话可见
3. **防伪机制** — constitution 禁止 AI 写入，只有人能放置

AskUserQuestion 可以替代 (1)，但无法替代 (2)(3)：
- AskUserQuestion 的回答只存在于会话上下文中，不持久化到文件
- 如果 AI 基于 AskUserQuestion 回答自动写入标记，等于 AI 间接写了 BATON:GO

**三种可能的演进方向：**

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| **A: 保留 BATON:GO + 增加 AskUserQuestion** | 用 AskUserQuestion 展示方案对比，人看完后手动写 BATON:GO | 最安全，增强了信息呈现 | 仍需人手动写标记，流程没简化 |
| **B: AskUserQuestion 作为审批 + AI 记录审批结果** | 人通过 AskUserQuestion 点击 "Approve"，AI 写入 `<!-- HUMAN_APPROVED via structured prompt at 2026-03-18T10:00 -->` | 流程更流畅，结构化 | AI 代写了审批标记，防伪性降低 |
| **C: Hook 强制检查** | write-lock hook 检查 plan.md 中是否有审批标记（不管来源），AskUserQuestion 的审批回答触发 AI 写入 | 防御靠 hook 而非标记来源 | 依赖 hook 平台支持，Codex 无法执行 |

**跨平台视角：**
- Claude Code: AskUserQuestion ✅
- Cursor: 有 "Ask questions" 工具 ✅
- Codex: 有 `request_user_input` ✅ — 三平台都支持结构化提问
- 但三平台的工具名和 schema 不同，需要在技能中做条件分支或抽象

**建议：方案 A 作为默认，方案 B 作为 `BATON:OVERRIDE` 可选项。** 理由：BATON:GO 的核心价值是"人的有意识行为"（deliberate act），点击按钮比手写标记的有意识程度更低。但如果用户明确 override，可以选择更流畅的方式。

### 批注 2 + Q3/Q4: 跨平台工具适配

**现状评估：**
Baton 已有 hook 协议适配（adapter.sh 翻译退出码/JSON），但缺少 **工具原语适配**——技能中直接引用 Claude Code 工具名（TaskCreate、Agent 等），其他平台无法理解。

**三平台工具映射：**

| 功能 | Claude Code | Codex CLI | Cursor |
|------|------------|-----------|--------|
| **创建任务** | `TaskCreate` | `update_plan` (step array) | `todo_write` ({id, content}) |
| **更新任务状态** | `TaskUpdate` (status/blocks/owner) | `update_plan` (step status) | — (隐式追踪) |
| **任务依赖** | `TaskUpdate` blocks/blockedBy | — | — |
| **列出任务** | `TaskList` | — | — |
| **子代理派发** | `Agent` tool | `spawn_agent` (typed roles) | Task tool (`.cursor/agents/`) |
| **等待子代理** | — (自动等待) | `wait_agent` (timeout) | — (自动等待) |
| **子代理通信** | `SendMessage` | `send_input` (text/images) | — |
| **结构化提问** | `AskUserQuestion` (preview/multiSelect) | `request_user_input` (multiple-choice) | Ask questions tool |
| **计划模式** | `EnterPlanMode`/`ExitPlanMode` | `update_plan` | Plan Mode (Shift+Tab) |
| **worktree 隔离** | `Agent isolation:"worktree"` / `EnterWorktree` | — (sandbox 替代) | 自动 worktree (parallel agents) |
| **定时调度** | `CronCreate` (session-only, 3天过期) | — | Automations (云端, 事件触发) |
| **权限请求** | — (用户审批弹窗) | `request_permissions` | — (YOLO mode toggle) |
| **后台执行** | `Bash run_in_background` + `TaskOutput` | `exec_command` + `write_stdin` (PTY) | `run_terminal_cmd is_background` |
| **语义搜索** | — | — | `codebase_search` (embeddings) |
| **Linter 诊断** | — | — | `read_lints` |
| **Web 搜索** | `WebSearch` | web_search (model-level) | `web_search` |

**适配层设计建议：**

Baton 的技能文件应该采用 **功能描述 + 平台分支** 模式：

```markdown
<!-- 当前写法（仅 Claude Code） -->
In Claude Code, use TaskCreate at the start of execution...
Outside Claude Code, rely on immediate plan marking.

<!-- 建议写法（多平台） -->
**Progress tracking** (platform-specific):
- Claude Code: TaskCreate/TaskUpdate with blocks/blockedBy
- Codex: update_plan with step status array
- Cursor: todo_write with {id, content}
- Fallback: immediate plan.md marking (Step 2 point 5)
```

**或更好的方案：将工具映射提取到独立文件。**

```
.baton/adapters/
  codex/adapter.sh          ← 已有：hook 协议适配
  codex/tools.md            ← 新增：工具原语映射
  cursor/adapter.sh         ← 已有
  cursor/tools.md           ← 新增
```

技能文件中用功能名引用，各平台的 tools.md 解释具体工具调用方式。
SessionStart hook 加载对应平台的 tools.md 到上下文。

---

## Updated Conclusions

### Revised Actionable Items

| # | 行动 | 平台覆盖 | 依赖 |
|---|------|---------|------|
| 1 | 创建 `.baton/adapters/{platform}/tools.md` 工具映射文件 | 全平台 | 无 |
| 2 | baton-implement 改为多平台进度追踪写法 | 全平台 | #1 |
| 3 | baton-subagent 添加 Codex spawn_agent/wait_agent 映射 | Codex | #1 |
| 4 | 评估 BATON:GO 审批机制演进（方案 A/B/C） | 全平台 | 独立设计决策 |
| 5 | SessionStart hook 注入当前平台的 tools.md | 全平台 | #1 |
| 6 | 利用 TaskUpdate blocks/blockedBy 表达 Todo 依赖 | Claude Code | 无 |
| 7 | 利用 Agent `isolation:"worktree"` 隔离并行子代理 | Claude Code | 无 |
| 8 | 验证阶段用 `Bash run_in_background` + `TaskOutput` 异步测试 | Claude Code | 无 |

### Revised Watchlist

- Codex `spawn_agent`/`wait_agent`/`send_input` 的成熟度（目前标记为 experimental feature `Collab`）
- Cursor Automations 的事件触发能力（超出 CLI 会话范围）
- Claude Code 未来是否增加 `wait_agent` 或交互式子代理通信
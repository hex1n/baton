# 工具原语适配 + 审批机制改进计划

**Complexity**: Medium (cross-module, 14+ files, design decisions)
**Research**: `./research.md`

---

## Requirements

1. **BATON:GO 切换到方案 B** — 人通过结构化提问工具审批，AI 记录审批结果（人的决定）
2. **跨平台工具原语适配层** — Claude Code / Codex / Cursor 三平台（人的决定）
3. ~~充分利用已有工具能力~~ — **Deferred**: TaskUpdate dependencies, Agent worktree isolation 等记录在 tools.md 中，实际集成到技能逻辑为后续任务

---

## Step 1: First Principles Decomposition

### Problem Statement

Baton 的治理机制和工具引用硬编码了 Claude Code 假设：
1. 审批需要人手动在文件中写 GO 标记，流程摩擦大
2. 技能文件直接引用 Claude Code 工具名（TaskCreate/Agent 等），Codex/Cursor 无法理解
3. Claude Code 已有的高级工具能力（依赖管理、worktree 隔离）未被利用

### Constraints

- ✅ constitution.md 的 6 个核心不变量必须保持（特别是 #4 不超权执行）
- ✅ 现有 hook 适配器架构（adapters/codex/, adapters/cursor/）要复用
- ✅ 向后兼容：已有的 GO 标记计划文件仍能工作
- ✅ 14 个文件包含 40 处 BATON:GO 引用，变更必须一致
- ✅ Codex 只有 2/9 hooks（无 PreToolUse），不能依赖 hook 做审批检查
- ✅ 各平台结构化提问工具 schema 不同（AskUserQuestion vs request_user_input vs ask）

---

## Step 2: Derive from Validated Inputs

从研究 Final Conclusions 和批注回应导出：

### 审批机制（方案 B）

研究结论：三平台都支持结构化提问（✅ 研究 Step 4 跨平台视角）。
方案 B 核心：`人点击 Approve → AI 写入审批记录标记 → write-lock 检查该标记`。

**关键设计决策**：
- 新增标记 `BATON:APPROVED`（HTML 注释格式），AI 在人通过结构化提问确认后写入
- AI **仍不可以**写 `BATON:GO`（向后兼容，保留人手动写的选项）
- write-lock 检查两种标记：GO 或 APPROVED
- 防御模型转移：从"标记来源不可伪造"到"会话审计 + hook 执行"

### 工具适配层

研究结论：Baton 已有 hook 协议适配（adapter.sh），缺少工具原语适配（✅ 研究批注回应）。

### 工具能力增强

研究 Tier 1 中的 #1/#2/#6 直接可用（✅ 已有工具 schema 验证）。

---

## Step 3: Surface Scan

✅ 通过 `grep -rn 'BATON:GO' .baton/` 获取完整引用列表（40 处，独立验证确认）

| File | Level | Disposition | L2 consumers | Reason |
|------|-------|-------------|-------------|--------|
| `.baton/constitution.md` | L1 | modify | L2: CLAUDE.md `@`引用 → AI 上下文注入; 所有技能 Iron Law 引用 | GO 定义、权限规则、状态转换 (4 处) |
| `.baton/hooks/lib/plan-parser.sh` | L1 | modify | L2: common.sh → 所有 hook 通过 `parser_has_go` 间接依赖 | `parser_has_go` 函数 (5 处) |
| `.baton/hooks/write-lock.sh` | L1 | modify | L2: dispatch.sh PreToolUse 路由 | 核心门禁检查 + 治理标记阻止 (6 处) |
| `.baton/hooks/phase-guide.sh` | L1 | modify | L2: dispatch.sh SessionStart 路由; additionalContext 注入 | 状态检测 + 指引消息 (5 处) |
| `.baton/hooks/bash-guard.sh` | L1 | modify | L2: dispatch.sh PreToolUse 路由 | 门禁状态检查 + 消息 (2 处) |
| `.baton/hooks/subagent-context.sh` | L1 | modify | L2: dispatch.sh SubagentStart 路由 | GO 检查 (1 处) |
| `.baton/hooks/pre-compact.sh` | L1 | modify | L2: dispatch.sh PreCompact 路由 | GO 检查 + 消息 (2 处) |
| `.baton/hooks/stop-guard.sh` | L1 | modify | L2: dispatch.sh Stop 路由 | GO 检查 (1 处) |
| `.baton/hooks/completion-check.sh` | L1 | modify | L2: dispatch.sh TaskCompleted 路由 | GO 检查 (1 处) |
| `.baton/skills/baton-implement/SKILL.md` | L1 | modify | L2: .claude/skills/ junction | Iron Law + 进度追踪 + 引用 (7 处) |
| `.baton/skills/baton-plan/SKILL.md` | L1 | modify | L2: .claude/skills/ junction | Iron Law + 审批流程 (2 处) |
| `.baton/skills/baton-plan/review-prompt.md` | L1 | modify | L2: baton-review subagent dispatch | 检查项 (1 处) |
| `.baton/skills/baton-debug/SKILL.md` | L1 | modify | L2: .claude/skills/ junction | 恢复协议 (1 处) |
| `.baton/skills/using-baton/SKILL.md` | L1 | modify | L2: phase-guide.sh SessionStart 注入 | 输出合规 + 审批门禁 (2 处) |
| `.baton/skills/baton-subagent/SKILL.md` | L1 | modify | L2: .claude/skills/ junction | 添加平台派发指引 |
| `.baton/adapters/claude-code/` | — | create (dir) | — | 新目录（codex/ 和 cursor/ 已存在） |
| `.baton/adapters/claude-code/tools.md` | — | create | L2: phase-guide.sh SessionStart 注入 | 工具映射文件 |
| `.baton/adapters/codex/tools.md` | — | create | L2: phase-guide.sh SessionStart 注入 | 工具映射文件 |
| `.baton/adapters/cursor/tools.md` | — | create | L2: phase-guide.sh SessionStart 注入 | 工具映射文件 |
| `setup.sh` | L2 | modify | — | 安装 tools.md + 更新 claude-code adapter 目录 |
| `docs/ide-capability-matrix.md` | L2 | modify | — | 更新审批机制说明 |

**共 21 个文件/目录，15 modify + 4 create + 2 reference update。**

---

## Step 4: Approaches & Recommendation

### Approach A: Minimal — 仅改审批机制 + 内联平台分支

- **What**: GO → APPROVED + 在技能中内联写平台分支
- **How**: 改 constitution + hooks + skills 的引用；在每个技能文件中加平台分支
- **Trade-offs**:
  - Pro: 改动集中，不增加新文件
  - Con: 技能文件膨胀，每增加一个平台要改所有技能文件
  - Risk: 维护成本随平台数线性增长

### Approach B: 分离 — 审批改造 + 提取 tools.md 适配层

- **What**: GO → APPROVED + 新建 `adapters/{platform}/tools.md` + SessionStart 注入
- **How**: 审批逻辑改造同 A；工具引用从技能中提取到独立 tools.md 文件，SessionStart hook 按平台注入
- **Trade-offs**:
  - Pro: 技能文件保持干净，新增平台只需加 tools.md
  - Pro: 复用已有 adapters/ 目录结构
  - Con: 增加 3 个新文件 + hook 改动
  - Risk: tools.md 内容可能过时（需维护同步）

### Approach C: 最大 — 审批 + tools.md + 全面工具能力增强

- **What**: 方案 B + 立即集成 blocks/blockedBy、worktree isolation、异步测试
- **How**: 在 B 基础上同时改 baton-implement（依赖管理）、baton-subagent（worktree 隔离）
- **Trade-offs**:
  - Pro: 一次到位
  - Con: 变更面太大，审批 + 适配 + 能力增强同时进行，风险叠加
  - Risk: 未经测试的 blocks/blockedBy 和 worktree isolation 可能引入回归

### Recommendation: Approach B

**理由**：
1. 审批改造是核心需求（用户明确选择方案 B），必须做
2. tools.md 适配层复用已有 adapters/ 架构（✅ 研究证据），增量小
3. 工具能力增强（blocks/blockedBy 等）可以作为后续增量，先在 tools.md 中记录能力，不在本次改技能逻辑
4. 比 A 更可维护，比 C 更安全

---

## Detailed Design

### 1. 审批标记重设计

**旧标记**（保留兼容，人手写）:
```
GO 标记 (HTML comment format, 人手写)
```

**新标记**（AI 写入，仅在人确认后）:
```
BATON:APPROVED 标记 (HTML comment format, 含 timestamp)
```

**检测逻辑** (`parser_has_go`): 匹配 GO **或** APPROVED。函数名保持 `parser_has_go` 不变（语义为"是否已授权"）。

**write-lock 治理标记检查**:
- 阻止 AI 写入包含 `BATON:GO` 或 `BATON:OVERRIDE` 的内容（**保持不变**）
- **不阻止** AI 写入 `BATON:APPROVED`（因为这是审批记录，不是审批本身）

**审批流程**（baton-plan 技能层面）:
1. baton-plan 完成后，用平台的结构化提问工具向人展示：
   - 计划摘要（preview）
   - 选项：`Approve` / `Request Changes` / `Reject`
2. 人选择 Approve → AI 在 plan.md 末尾（批注区之前）写入 APPROVED 标记
3. 人选择其他 → 继续批注循环
4. 人仍可选择不用结构化提问，直接手写 GO 标记（高审慎模式）

**防御模型变化 + Constitution 修正提案**:

当前 constitution Defense Model 声明："Hooks enforce structure. Review enforces quality. Neither is sufficient alone." + "No single-layer failure should defeat governance."

BATON:APPROVED 路径将审批防御从 hook-enforced 降级为 convention-enforced（单层）。这与上述原则矛盾。必须在 constitution 中显式修正：

**Constitution §Permissions 修正**:
```
旧: AI must never write BATON:GO, BATON:OVERRIDE, or BATON:COMPLETE markers.
    Only the human places BATON:GO and BATON:OVERRIDE.

新: Governance markers fall into two categories:
    - **Human-only markers**: BATON:GO, BATON:OVERRIDE — AI must never write these.
      Only the human places them. Hook-enforced (write-lock blocks AI writes).
    - **Approval record markers**: BATON:APPROVED — AI writes ONLY after human
      confirms via structured approval prompt. Convention-enforced (skill rules +
      session audit). Human may always use BATON:GO instead for higher assurance.
    - AI may place BATON:COMPLETE only after human confirms completion.
```

**Constitution §States 修正**:
```
旧: APPROVED → EXECUTING: BATON:GO recorded in the plan.

新: APPROVED → EXECUTING: authorization marker recorded in the plan.
    Authorization markers: BATON:GO (human-placed) or BATON:APPROVED (AI-placed
    after human confirmation via structured approval prompt). Both unlock execution.
```

**Constitution §Defense Model 追加**:
```
追加: The BATON:APPROVED path accepts a defense downgrade for workflow fluency:
      approval enforcement shifts from hook (structural) to convention (skill rule
      + session audit). This is an explicit, documented trade-off. For maximum
      assurance, use BATON:GO (hook-enforced, unforgeable). The human chooses
      which path to use.
```

**两条路径并存**:
- **高审慎路径**: 人手写 GO 标记（hook 保护，不可伪造）
- **流畅路径**: 人点击 Approve → AI 写 APPROVED 标记（技能规则 + 审计）
- 风险接受：AI 理论上可以不经结构化提问直接写 APPROVED 标记。缓解措施：(1) constitution 规则显式禁止；(2) 会话审计可追溯；(3) 人随时可检查 plan.md；(4) 人可选择高审慎路径

### 2. tools.md 适配层

每个平台一个 `tools.md`，格式统一，位于 `.baton/adapters/{platform}/tools.md`：

**内容模板**:
```markdown
# {Platform} Tool Mapping for Baton

## Progress Tracking
- Tool: `{tool_name}`
- Create task: {example}
- Update status: {example}
- Dependencies: {example or "not supported"}

## Structured Approval
- Tool: `{tool_name}`
- Usage: {example}

## Subagent Dispatch
- Tool: `{tool_name}`
- Isolation: {example or "not supported"}
- Roles: {if applicable}

## Background Execution
- Tool: `{tool_name}`
- Run: {example}
- Check output: {example}
```

**技能文件改写**:
- 从 `In Claude Code, use TaskCreate...` 改为 `使用平台的进度追踪工具（参见 tools.md）创建任务`
- 具体工具名由 SessionStart 注入的 tools.md 提供

### 3. SessionStart 注入

phase-guide.sh 已有注入 using-baton 到 additionalContext 的逻辑。扩展为同时注入当前平台的 tools.md。

平台检测逻辑：
```bash
# 检测当前平台
# ❓ .cursor/ 和 .codex/ 目录检测可能不可靠（.cursor 可能在非 Cursor 项目中存在）
# 实现时需验证各平台的运行时信号（环境变量优先于目录检测）
_detect_platform() {
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then echo "claude-code"  # ✅ Claude Code 设置此变量
    elif [ -n "${CURSOR_SESSION_ID:-}" ]; then echo "cursor"       # ❓ 需验证 Cursor 是否设置此变量
    elif [ -n "${CODEX_SANDBOX:-}" ]; then echo "codex"            # ❓ 需验证 Codex 运行时信号
    else echo "claude-code"  # 默认回退
    fi
}
```

**APPROVED 标记格式**:
```
<!-- BATON:APPROVED 2026-03-18T10:30:00+08:00 -->
```
格式：`BATON:APPROVED` + ISO 8601 时间戳（含时区）。parser_has_go 检测只需匹配 `BATON:APPROVED` 前缀。

---

## Impact & Risks

| Risk | Mitigation |
|------|-----------|
| parser_has_go 不匹配新标记 → write-lock 永久锁定 | 测试：验证两种标记都能解锁 |
| 旧计划文件中的 GO 标记不再被识别 | 向后兼容：两种标记都检测 |
| AI 在没有人确认的情况下写 APPROVED | 技能层面强制 + constitution 规则 |
| tools.md 内容过时 | 维护规则：更新技能时同步更新 tools.md |
| Codex 无 PreToolUse hook → write-lock 不生效 | 已有限制，不在本次范围 |
| 14 个文件 40 处修改，遗漏风险 | 修改后 grep 做完整性检查 |
| SessionStart additionalContext 长度限制 | tools.md 保持精简（< 2000 字符） |

---

## Deferred Items (后续任务)

以下来自研究 Tier 1，记录在 tools.md 中但不在本次改技能逻辑：

| # | 能力 | tools.md 中记录 | 后续集成到 |
|---|------|----------------|-----------|
| 1 | TaskUpdate blocks/blockedBy 依赖管理 | ✅ Claude Code tools.md | baton-implement Todo 依赖 |
| 2 | TaskUpdate owner 任务认领 | ✅ Claude Code tools.md | baton-subagent 并行 |
| 3 | Agent isolation:"worktree" | ✅ Claude Code tools.md | baton-subagent 隔离 |
| 4 | Bash run_in_background + TaskOutput | ✅ Claude Code tools.md | baton-implement 异步验证 |
| 5 | CronCreate 定时健康检查 | ✅ Claude Code tools.md | 长任务场景 |
| 6 | Codex spawn_agent/wait_agent | ✅ Codex tools.md | baton-subagent Codex 路径 |

---

## Review Processing

### C1: BATON:APPROVED 防御降级与 constitution 矛盾
- **Status**: ✅ Accepted — 在 Detailed Design §1 中新增 constitution 修正提案，显式文档化防御降级为设计决策
- **Impact**: affects conclusions — constitution.md 现在需要 3 处具体修正（Permissions + States + Defense Model）

### C2: Constitution 修改未具体化
- **Status**: ✅ Accepted — 在 Detailed Design §1 中新增具体的修正文本（旧→新对比）

### I1: 缺少 L2 追踪
- **Status**: ✅ Accepted — Surface Scan 表格新增 L2 consumers 列

### I2: 平台检测脆弱
- **Status**: ✅ Accepted — 检测逻辑改为环境变量优先，标记 ❓ 待实现时验证

### I3: Requirement #3 范围不匹配
- **Status**: ✅ Accepted — Requirement #3 标记为 Deferred，新增 Deferred Items 章节

### I4: 缺少 claude-code/ 目录创建
- **Status**: ✅ Accepted — Surface Scan 新增 `.baton/adapters/claude-code/` 目录创建

### I5: 缺少 Todo list
- **Status**: 预期行为 — Todo list 在 approval 后由人说 "generate Todo list" 触发生成

### S1: parser_has_go 函数名误导
- **Status**: ❓ 保留为 judgment-needed — 重命名会影响所有 hook 调用点，收益不确定

### S2: APPROVED 标记格式
- **Status**: ✅ Accepted — 在 Detailed Design §3 SessionStart 注入后新增格式规范

---

## Self-Challenge

### 1. 这是最好的方案还是我想到的第一个？
Approach B 确实是研究阶段就提出的方案，但它通过 Step 4 与 A/C 对比后胜出——A 的维护成本问题是实证的（每增一个平台改所有技能），C 的风险叠加也是实证的。

### 2. 未验证的假设？
- ❓ 假设 SessionStart hook 可以注入足够长的 tools.md 内容——未测试 additionalContext 长度限制
- ❓ 假设 phase-guide.sh 可以可靠检测当前平台——需验证环境变量可用性
- ❓ 假设 AI 严格遵守"只在人确认后写 APPROVED"——技能规则，非 hook 强制

### 3. 怀疑者会先质疑什么？
**"APPROVED 标记可以被 AI 伪造"** — 确实如此。这是从 hook-enforced 到 convention-enforced 的防御降级。缓解：双路径设计（高审慎 GO 仍可用）+ constitution 明确禁止 + 会话可审计。

**"tools.md 增加了维护负担"** — 确实。但替代方案（内联分支）的维护成本更高（N平台 × M技能）。tools.md 是 N+M 而非 N×M。

---

## 批注区

<!-- Per annotation: ### [Annotation N] / Trigger / Response / Status / Impact -->


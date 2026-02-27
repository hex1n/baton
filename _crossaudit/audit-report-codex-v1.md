# Baton v2.1 技能包审计报告（Codex 视角）v1

日期：2026-02-27  
审计人：Codex CLI（GPT-5.2）  
审计范围：`skills/*/SKILL.md`、`workflow-protocol.md`、`bin/baton`、`hooks/*`、`prompts/*`、`.baton/*`

> 目标：从两个维度“系统审计（技能间矛盾/流程断点）”与“系统行为（AI 运行时会怎样）”对 Baton v2.1 做深度评估，并给出量化评分与可执行改进建议。

---

## 评分（10分制）

- 技能文件一致性：**7.5/10**
- 流程闭环（不易卡死/走偏）：**6/10**
- 运行可靠性（Claude Code + *nix hooks 齐全）：**7/10**
- 运行可用性（Windows / PowerShell 纯环境、无 bash）：**2/10**
- 总分（按实际可落地加权）：**6/10**

---

## 1) 系统审计：技能间矛盾 & 流程断点

### 1.1 硬断点：技能文档写“baton 命令=直接执行”，但 CLI 实际主要是“输出应加载的技能/提示”

**现象**
- 多个技能写法会让用户以为 `baton research/plan/slice/verify/...` 会“真正执行并产出工件”，但当前 `bin/baton` 对多数子命令只输出提示文案，并不会生成/更新对应文件内容。

**证据**
- 技能文档的“直接调用”表述：
  - `skills/plan-first-research/SKILL.md:48`（`baton research <scope>`）
  - `skills/plan-first-plan/SKILL.md:53`（`baton plan ...`）
  - `skills/annotation-cycle/SKILL.md:50`（`baton annotate <plan.md>`）
  - `skills/context-slice/SKILL.md:43`（`baton slice <plan.md>`）
  - `skills/plan-first-implement/SKILL.md:40`（`baton implement <plan.md> ...`）
  - `skills/verification-gate/SKILL.md:39`（`baton verify`）
  - `skills/code-reviewer/SKILL.md:40`（`baton review ...`）
- CLI 实际行为（仅输出“Skill: ...”，不执行工作流动作）：
  - `bin/baton:808`（`research|plan|verify|review` 仅打印 Skill 名和提示）
  - `bin/baton:829`（`slice` 只做校验后打印 “Skill: context-slice | Target: ...”）
  - `bin/baton:818`（`annotate` 同上）
  - `bin/baton:845`（`implement` 同上）

**影响**
- 造成显著“流程断点”：用户以为运行命令就会生成 `plan.md`/`## Context Slices`/`verification.md`，但实际什么都不会发生。
- 这会直接削弱技能包“可操作性”和“可自动化程度”，把流程从“系统/工具驱动”退化为“靠人记得去 cat 技能文件并手工执行”。

---

### 1.2 硬矛盾：Verification Gate 的退出条件在状态机里被弱化（可能被绕过）

**现象**
- 协议/技能将 verify 退出条件设为 `TASK-STATUS: DONE`，但 `detect_phase()` 里只要 `verification.md` 文件存在，就会把任务推进到 `review`（甚至 `done`），不强制 DONE 标记。

**证据**
- 规范定义 verify 的退出条件：`workflow-protocol.md:36`（`TASK-STATUS: DONE`）、`skills/verification-gate/SKILL.md:25`、`skills/verification-gate/SKILL.md:61`（写入 `<!-- TASK-STATUS: DONE -->`）
- 状态机实现：
  - `bin/baton:116` 起：只要 `verification.md` 存在，进入 review/done 分支（并未要求 DONE）

**影响**
- “证据式验证”的核心目标被破坏：只写了一个空/失败的 `verification.md` 也能进入 review 甚至 done。
- 对外会出现“系统显示已进入 review/done，但验证并未真正通过”的错觉，属于流程级可靠性风险。

---

### 1.3 软矛盾：Slice 在文档口径像可选，但在 gate/enforcement 中近似必选

**现象**
- 协议里 implement 入口写了 “Todo + Slices exist (or slice skipped)”（暗示 slices 可跳过），但 `detect_phase()` 会在缺少 `## Context Slices` 时把任务卡在 `slice`；而 `phase-lock` 又将 `slice` 视为锁定期，直接阻断源代码写入。
- 同时 `plan-first-implement` 文档仍保留“无 slices 的 fallback”叙述，口径不一致。

**证据**
- 协议：`workflow-protocol.md:35`（`or slice skipped`）
- 状态机：`bin/baton:151`（plan APPROVED 且有 Todo、无 Context Slices → phase `slice`）
- phase-lock：`hooks/phase-lock.sh:118`（`slice`/`approved` 阶段阻断非 `.baton/` 写入）
- implement 技能 fallback：`skills/plan-first-implement/SKILL.md:92`

**影响**
- 阅读文档会以为 slices 可选，但在 Layer1+/hooks 场景中会被系统强制，造成“理解偏差 + 卡住”。
- 建议统一口径：要么实现真正的 skip 机制/状态位（可审核、可追踪），要么删除协议中 “slice skipped” 的表达并明确 slices 是 workflow 必选门槛。

---

### 1.4 软矛盾：context-slice 要求分析并行性，但 implement 要求严格顺序执行

**现象**
- `context-slice` 要求 “Check for parallelism”，但 `plan-first-implement` 明确 “In order. Do not skip ahead.”，缺少“并行性分析的用途”解释。

**证据**
- `skills/context-slice/SKILL.md:68`（并行性检查）
- `skills/plan-first-implement/SKILL.md:120`（严格顺序）

**影响**
- 读者不清楚并行性输出用于何处（给人类排程？还是允许并发 subagents？）。
- 建议明确：默认顺序执行；并行仅在“无依赖 + 文件不重叠 + 人类批准”时允许，并定义审批/记录方式。

---

### 1.5 运行约束覆盖不全：phase-lock hook 的拦截面取决于平台工具事件模型

**现象**
- Claude 示例配置 `PreToolUse` 的 matcher 只覆盖 `Edit|Write|MultiEdit|CreateFile`，这意味着“是否能通过其他路径修改文件”取决于宿主平台的工具分类与触发机制。

**证据**
- `hooks/claude-settings.example.json:16`

**影响**
- 如果某平台存在“通过 shell/脚本修改源文件但不触发上述工具类别”的路径，理论上可能绕过锁（取决于平台实现）。
- 建议至少在治理层把“禁止用 shell 改源码绕过锁”写成硬约束，并在 review 阶段审计；同时视平台能力扩大 matcher/增加审计信号。

---

### 1.6 状态同步断点：using-baton 强依赖 `.baton/active-task`，但不主动重算 phase

**现象**
- `using-baton` 明确“不猜 phase，只读 active-task”，但 active-task 可能滞后于工件实际状态（例如你刚把 plan 从 DRAFT 改 APPROVED）。
- 当前“自动纠偏”更多依赖 `baton next`（它会调用 `detect_phase()` 并重写 active-task），但技能文本未把“刷新 phase”作为明确动作。

**证据**
- `skills/using-baton/SKILL.md:62`、`skills/using-baton/SKILL.md:109`
- `cmd_next` 会重写 `.baton/active-task`：`bin/baton:531`～`bin/baton:533`

**影响**
- AI/人类可能按照过期 phase 行动，出现“被 gate 卡住”或“指令引导错误”。
- 建议在 using-baton 中明确：每次关键工件变更后（research CONFIRMED、plan APPROVED、Todo 生成、Slices 生成、verification DONE 等）先运行一次 `baton next` 或 `baton active <id>` 以刷新 phase。

---

## 2) 系统行为视角：AI 实际运行时会怎样

### 2.1 理想路径（Claude Code + hooks 生效，Layer1/2）

1. SessionStart hook 输出当前 `Task/Phase`，并给出唯一的硬动作：先 `cat .../skills/<skill>/SKILL.md`  
   - `hooks/session-start.sh` 会根据 phase 映射 skill，并输出 REQUIRED ACTION（cat 命令）
2. 在 `research|plan|annotation|approved|slice` 阶段：phase-lock 阻断对 `.baton/` 外文件的写入  
   - `hooks/phase-lock.sh:118`
3. 进入 implement：要求 plan APPROVED + 存在 `## Todo`，否则仍阻断源写入  
   - `hooks/phase-lock.sh:139`、`hooks/phase-lock.sh:147`
4. 验证：要求真实跑命令并在 `verification.md` 记录证据，最后写 `<!-- TASK-STATUS: DONE -->`  
   - `skills/verification-gate/SKILL.md:61`
5. 评审：输出 `review.md`，并在需要时更新 `hard-constraints.md` 的 `Last-validated`  
   - `skills/code-reviewer/SKILL.md`（Stage 4）

### 2.2 hooks 不齐的平台（Cursor / Codex 等）：门禁更多依赖“纪律”而非“强制”

- 你当前 repo 根目录缺少 `AGENTS.md`（需要 `baton generate` 才会生成并注入协议/技能列表），因此在 Codex CLI 场景默认不会自动加载工作流约束提示。
- Cursor 需要 `baton generate` 生成 `.cursor/rules/baton.md` 才能把 phase-lock 规则以“自我约束”形式常驻；当前 `.cursor/rules/` 为空。

结论：在这些平台上，如果没有额外注入/规则文件，Baton 的“锁/门禁”对 AI 的约束会显著变弱。

### 2.3 Windows / PowerShell 纯环境的现实：脚本体系无法开箱运行

- `bin/baton`、`hooks/session-start.sh`、`hooks/phase-lock.sh` 都是 bash/sh 脚本。
- 当前环境里 `bash` 不在 PATH（即便 repo 存在脚本，也无法直接运行），因此：
  - CLI/Hook 执行层不可用
  - phase-lock 无法在工具层强制
  - 只能退化为“手动阅读 skills 的纪律执行”

这会把“系统行为”从“工具强制流程”退化为“文档建议流程”。

---

## 3) 优先修复建议（按收益/风险排序）

### P0（强烈建议先做）

- 修正 `detect_phase()`：只有当 `verification.md` 包含 `TASK-STATUS: DONE` 才能进入 `review` / `done` 分支，避免 verify 被绕过（`bin/baton:116`）。
- 统一 slices 是否必选的口径与机制：  
  - 要么实现真正可审计的 skip（并更新协议/门禁/状态机）；  
  - 要么删除协议中的 “slice skipped”，并在技能文档明确 workflow mode 强制 slices（`workflow-protocol.md:35`、`bin/baton:151`、`hooks/phase-lock.sh:118`、`skills/plan-first-implement/SKILL.md:92`）。

### P1（高收益体验修复）

- 修正文档口径：将各技能中 “Use `baton ...` to invoke directly” 改为更准确的描述（当前 `bin/baton` 多数命令只输出“应加载哪个 skill/目标文件”，并不执行）。
- 明确 Windows 支持策略：要求 WSL/Git-Bash，或提供 PowerShell 等价实现（否则实际可用性评分会长期偏低）。

### P2（增强一致性/可扩展性）

- 明确并行 subagent 的许可条件与记录方式，消解“并行性分析”与“顺序执行”矛盾（`skills/context-slice/SKILL.md:68`、`skills/plan-first-implement/SKILL.md:120`）。
- 扩大/补强 phase-lock 的约束覆盖：在治理层增加“禁止用 shell 绕过锁改源码”的硬约束，并在 review 阶段执行审计；平台允许时扩大 hook matcher 覆盖面（`hooks/claude-settings.example.json:16`）。

---

## 附录：审计范围清单

- 技能（8）：`skills/annotation-cycle/SKILL.md`、`skills/code-reviewer/SKILL.md`、`skills/context-slice/SKILL.md`、`skills/plan-first-implement/SKILL.md`、`skills/plan-first-plan/SKILL.md`、`skills/plan-first-research/SKILL.md`、`skills/using-baton/SKILL.md`、`skills/verification-gate/SKILL.md`
- 协议：`workflow-protocol.md`
- CLI：`bin/baton`
- Hooks：`hooks/session-start.sh`、`hooks/phase-lock.sh`、`hooks/claude-settings.example.json`
- Subagent prompts：`prompts/implementer.md`、`prompts/spec-reviewer.md`、`prompts/quality-reviewer.md`
- 项目层样板：`.baton/project-config.json`、`.baton/review-checklists.md`、`.baton/governance/hard-constraints.md`、`.baton/tasks/_task-template/*`

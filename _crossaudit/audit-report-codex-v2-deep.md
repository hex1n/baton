# Baton v2.1 深度审计报告（Codex 视角）v2（逐机制 / 逐交互点 / 逐行为预测）

日期：2026-02-27  
审计人：Codex CLI（GPT-5.2）  
审计范围：`bin/baton`、`workflow-protocol.md`、`hooks/*`、`skills/*/SKILL.md`、`prompts/*`、`tests/run-smoke-tests.sh`、`.baton/*`、`README.md`、`CHANGELOG.md`

**审计约束（为了避免被既有结论“带节奏”）：**
- 本次审计 **未阅读** 任何 `audit-report*.md` 文件（包括 `audit-report.md` / `audit-report-v2.md` / `audit-report-codex-v1.md` 等）。

---

## 0) 总结与评分（10 分制）

### 0.1 总体结论（浓缩版）

Baton v2.1 的“设计意图”非常清晰：用 **skills（流程规范）+ protocol（关系/职责单一真相）+ state machine（阶段判定）+ hooks（强制门禁）** 来让 AI 开发变得可审计、可控。`skills/*` 的写作质量高，职责划分也比 v2.0 清爽（Todo 归 `plan-first-plan`、annotations 归 `annotation-cycle`、slices 归 `context-slice`）。  
但落到“系统行为”时，有若干 **P0 级断裂点** 会让真实运行偏离设计意图：

- **门禁集成假设不自洽**：`phase-lock.sh` 要“永远允许写 `.baton/` 工件”，但示例 hook 配置没有传入目标路径，导致在锁定期可能 **连 `.baton/` 都写不了（死锁）**（`hooks/phase-lock.sh:10`、`hooks/phase-lock.sh:113`、`hooks/phase-lock.sh:120` vs `hooks/claude-settings.example.json:14`）。  
- **Quick-path 机制在协议/技能中完整存在，但 state machine 没实现**：协议要求 `.quick-path` 跳过 research gate（`workflow-protocol.md:57`），`new-task --quick` 也会把 active-phase 设为 `plan`（`bin/baton:472`～`bin/baton:479`），但 `detect_phase()` 完全不读 `.quick-path`，会把 quick-path 任务“判回 research”（`bin/baton:130`～`bin/baton:141`）。  
- **verify→review→done 的闭环被 `detect_phase()` 弱化**：只要 `verification.md` 存在就进入 review/done 分支，不要求 `TASK-STATUS: DONE`（`bin/baton:116`～`bin/baton:128` vs `workflow-protocol.md:36`、`skills/verification-gate/SKILL.md:25`）。  
- **测试脚本本身疑似不可运行**：`tests/run-smoke-tests.sh` 存在未闭合引号（例如 `tests/run-smoke-tests.sh:38`，同类问题在 `tests/run-smoke-tests.sh:317`、`tests/run-smoke-tests.sh:319`），且 `run_test()` 失败也打印同样的“通过标记”（`tests/run-smoke-tests.sh:19`～`tests/run-smoke-tests.sh:29`）。这会让“我们有 smoke tests”这一条设计意图落空。

### 0.2 评分

> 评分口径：**设计意图清晰度** 与 **实现可落地性** 分开打分；“能否在真实 AI 平台上按预期强制执行”权重最高。

- 设计意图清晰度（protocol + skills）：**9/10**
- 机制一致性（文档/协议 vs CLI/state machine/hook）：**5/10**
- 门禁强制有效性（phase-lock 实际可用）：**4/10**（高度依赖平台是否自动提供 `BATON_TARGET_PATH` / `BATON_CURRENT_ITEM`）
- 状态机闭环正确性（research→plan→…→done）：**5/10**（quick-path、verify 判定存在结构性偏差）
- 可测试性（smoke tests 可运行且能防回归）：**2/10**
- 跨平台可用性：
  - Claude Code（假设 hook 环境能提供目标路径）：**6/10**
  - Cursor（靠规则自律）：**6/10**
  - Codex/OpenCode（README 声称支持但缺少明确 bootstrap）：**3/10**（`README.md:85`～`README.md:90`、`bin/baton:81`）
  - Windows 纯 PowerShell（无 bash）：**1/10**
- 总分（按可落地加权）：**5/10**

---

## 1) 逐机制审计（Mechanism-by-Mechanism）

> 每个机制按：设计意图 → 现实实现 → 断点/偏差 → 行为预测 → 建议 修复。

### M1. 全局层（Global layer）定位与安装

**设计意图**
- Baton 有“全局层”安装到 `~/.baton/`，同时允许在仓库内直接运行（`README.md:94`～`README.md:99`、`bin/baton:22`～`bin/baton:34`、`bin/baton:174`～`bin/baton:216`）。
- 允许通过 `BATON_GLOBAL` 覆盖全局根目录用于测试（`bin/baton:22`～`bin/baton:25`，tests 也确实 `export BATON_GLOBAL=...`：`tests/run-smoke-tests.sh:15`）。

**现实实现**
- `resolve_global_root()` 优先用 `BATON_GLOBAL`，否则以 `bin/baton` 所在目录向上找 `skills/`，最后 fallback 到 `$HOME/.baton`（`bin/baton:22`～`bin/baton:34`）。
- `cmd_install()` 会 **rm -rf** 目标下的 `skills/hooks/prompts/docs/tests` 后复制（`bin/baton:188`～`bin/baton:193`），并复制 `workflow-protocol.md`（`bin/baton:195`～`bin/baton:198`）。

**断点/偏差**
- 安装会覆盖用户对 `~/.baton/*` 的任何本地修改（这是合理的，但需要在文档里更明确）。
- 安装只对 `bin/baton` 做 `chmod +x`（`bin/baton:200`～`bin/baton:202`），hooks 的可执行位依赖复制来源；`doctor` 也会提示 session-start 不可执行（`bin/baton:411`～`bin/baton:422`）。

**行为预测**
- 在 *nix：可用；在 Windows（无 bash）：全局安装脚本本身无法运行（见“平台可用性”）。

**建议**
- P1：在 `README.md` 明确“Windows 需要 WSL/Git-Bash；纯 PowerShell 不支持”。

---

### M2. Repo root 定位（resolve_repo_root）与“项目层”识别

**设计意图**
- Baton 应在任意子目录运行时识别项目根（含 `.baton/`）（`README.md:101`～`README.md:111`）。

**现实实现**
- `bin/baton` 的 `resolve_repo_root()` 只在 `.baton/` 存在且包含 `project-config.json` 或 `tasks/` 时认定为根（`bin/baton:36`～`bin/baton:47`）。
- `hooks/phase-lock.sh` 的 `resolve_repo_root()` 还接受 `.baton/governance`（`hooks/phase-lock.sh:29`～`hooks/phase-lock.sh:35`）。

**断点/偏差**
- CLI 与 hook 的“根目录判定条件”不一致：CLI 不看 governance（`bin/baton:40`～`bin/baton:41`），hook 会看（`hooks/phase-lock.sh:30`～`hooks/phase-lock.sh:33`）。这会导致某些“只初始化了 governance”的半成品项目：hook 认为是 Baton 项目、CLI 却可能不认为（虽然 `cmd_init` 正常情况下会创建 tasks，所以这属于边缘，但不是不可能）。

**行为预测**
- 如果用户手工创建 `.baton/governance` 而没建 `tasks/`：hook 开始拦截，但 CLI 的 `REPO_ROOT` 可能退化为当前目录，出现不一致行为。

**建议**
- P2：统一 repo root 判定条件（建议都以 `.baton/` 存在为主，同时允许 governance-only 形态）。

---

### M3. Layer/Mode 模型（Layer 0/1/2）与 protocol 的“单一真相”

**设计意图**
- 三层模型（`README.md:9`～`README.md:13`）+ 三种 mode（`workflow-protocol.md:7`～`workflow-protocol.md:14`）：
  - PURE STANDALONE：无 `.baton/`，输出当前目录
  - PROJECT STANDALONE：有 `.baton/` 无 active-task，输出 `.baton/scratch/`
  - WORKFLOW MODE：有 active-task，输出 `.baton/tasks/<id>/`

**现实实现**
- CLI 的 layer detection：基于 `.baton/`、`active-task`、`project-config.json`（`bin/baton:66`～`bin/baton:73`）。
- `using-baton` skill 的 mode detection 与 protocol一致（`skills/using-baton/SKILL.md:47`～`skills/using-baton/SKILL.md:57`）。

**断点/偏差**
- `cmd_new_task()` 在“没有 `.baton/` 时”会自动创建最小 `.baton/`（`bin/baton:457`～`bin/baton:460`），这会把用户从 PURE STANDALONE 拉到“某种 project context”，但 `detect_layer()` 在“有 `.baton/` 但没 project-config 且没 active-task”仍返回 0（`bin/baton:66`～`bin/baton:72`）。  
  这不一定是 bug，但语义上“Layer 0 / Project Standalone”容易混淆。

**行为预测**
- 用户以为“Layer 0=完全不创建 `.baton/`”，但 `new-task` 会创建；之后工具行为会变得更复杂（active-task、phase-lock 等）。

**建议**
- P2：文档/doctor 输出里把 “Layer 0（pure）/Layer 0（project standalone）”明确区分，或调整 layer 数字含义。

---

### M4. 平台探测（detect_platforms）与 `generate` 产物

**设计意图**
- `baton generate` 生成平台相关文件：`AGENTS.md`、Cursor rules 等（`bin/baton:676`～`bin/baton:751`、`README.md:72`）。

**现实实现**
- 平台探测依赖目录标记：`.cursor`→cursor，`.claude` 或 `$HOME/.claude`→claude-code，`.agents`→codex（`bin/baton:77`～`bin/baton:83`）。
- `cmd_generate()`：
  - 始终生成 `AGENTS.md`（`bin/baton:688`～`bin/baton:711`）
  - 仅当探测到 cursor 才生成 `.cursor/rules/baton.md`（`bin/baton:712`～`bin/baton:750`）

**断点/偏差**
- `.agents` 在本仓库不被创建，也没有脚本生成它；导致 codex 平台可能永远探测不到（`bin/baton:81`）。  
- Cursor rules 的 YAML frontmatter `globs:` 为空（`bin/baton:715`～`bin/baton:719`），语法虽可成立（null），但是否被 Cursor 接受不确定。  
- `README.md` 声称 “Codex / OpenCode: via bootstrap scripts (see hooks/)”（`README.md:85`～`README.md:90`），但 `hooks/` 里仅看到 Claude 方向的 session-start/phase-lock 与示例配置（`hooks/session-start.sh`、`hooks/phase-lock.sh`、`hooks/claude-settings.example.json`），缺少明确的 codex bootstrap。

**行为预测**
- Cursor：如果项目里没有 `.cursor`，则不会生成规则文件；即使生成了，frontmatter 可能不被识别。  
- Codex：如果依赖 `.agents` 探测，则不会生成任何“codex 专用”产物；唯一通用的是 `AGENTS.md`（这对 Codex 倒是关键）。

**建议**
- P1：把 “Codex / OpenCode 支持方式”落到可执行步骤：要么生成 `.agents/` 标记并写入 codex 规则，要么移除 detect_platforms 对 codex 的假设。  
- P1：为 `.cursor/rules/baton.md` 补上有效 `globs`（或明确该字段在 Cursor 中可省略）。

---

### M5. `init`：项目层初始化与模板工件

**设计意图**
- `baton init` 初始化 Layer2：生成 project-config、hard-constraints、review-checklists、任务模板、.gitignore，并生成平台文件（`README.md:24`～`README.md:30`、`bin/baton:218`～`bin/baton:323`）。

**现实实现**
- 会创建：`.baton/project-config.json`、`.baton/review-checklists.md`、`.baton/governance/hard-constraints.md`（仅在不存在时创建：`bin/baton:227`～`bin/baton:292`）。
- 会无条件覆盖：`.baton/tasks/_task-template/research.md`（`bin/baton:294`～`bin/baton:306`）与 `.baton/.gitignore`（`bin/baton:308`～`bin/baton:313`）。
- 最后调用 `cmd_generate`（`bin/baton:315`）。

**断点/偏差**
- 任务模板 research.md 结构非常简化（缺少 plan-first-research 所要求的大量章节）（`bin/baton:294`～`bin/baton:306` vs `skills/plan-first-research/SKILL.md:92` 起）。这会让“模板=正确结构”的设计意图被破坏：新手会从模板开始写，产物不符合 skill 的“证据/风险验证”标准。  
- 初始化创建了 `_task-template/reviews/`（`bin/baton:225`），但系统主要把 review 输出定义为 `<task>/review.md`（`README.md:110`～`README.md:111`、`bin/baton:100`）；目录 `reviews/` 看起来像历史遗留。

**行为预测**
- `new-task` 从模板复制时会带上 `reviews/` 目录（`bin/baton:462`～`bin/baton:464`），但后续流程完全不会用它，形成噪音与困惑。

**建议**
- P1：让 `_task-template/research.md` 与 `plan-first-research` 的结构一致，至少包含最关键章节（Current behavior / Execution paths / Risks 三段结构）。  
- P2：清理或解释 `reviews/` 目录的用途；否则改为不创建。

---

### M6. `detect_phase()`：9 阶段状态机（核心机制）

**设计意图**
- v2.1 通过 `detect_phase` 扩展到 9 phase（`CHANGELOG.md:10`～`CHANGELOG.md:13`、`README.md:48`～`README.md:53`），并与 protocol 的 phase 表保持一致（`workflow-protocol.md:28`～`workflow-protocol.md:38`）。

**现实实现（精确判定逻辑）**
- 终态/评审优先级：
  - 若 `verification.md` 存在且含 `TASK-STATUS: DONE`：进入 review/done 判定（`bin/baton:102`～`bin/baton:114`）
  - **若 `verification.md` 存在但不含 DONE：仍进入 review/done 判定（不符合协议）**（`bin/baton:116`～`bin/baton:128`）
- research/plan：
  - research.md 不存在：`research (not started)`（`bin/baton:131`）
  - research CONFIRMED 且 plan 不存在：`plan (ready)` 否则 `research (draft)`（`bin/baton:133`～`bin/baton:140`）
- plan APPROVED：
  - 无 `## Todo`：`approved (generating todo)`（`bin/baton:144`～`bin/baton:149`）
  - 无 `## Context Slices`：`slice`（`bin/baton:150`～`bin/baton:154`）
  - 仍有未勾选 `- [ ]`：`implement` 否则 `verify`（`bin/baton:155`～`bin/baton:161`）
- plan 未 APPROVED：若 Annotation log 中出现 `### Round` 则 `annotation`，否则 `plan (draft)`（`bin/baton:164`～`bin/baton:170`）

**断点/偏差（P0/P1）**
- P0：`verification.md` 存在就进入 review/done（`bin/baton:116`～`bin/baton:128`），直接违背 protocol 的 verify 退出条件（`workflow-protocol.md:36`）与 verification-gate skill 的 exit condition（`skills/verification-gate/SKILL.md:25`）。  
- P0：Quick-path 只在 protocol/skill/SessionStart 里存在，但 `detect_phase()` 完全不读 `.quick-path`（对比 `workflow-protocol.md:57`～`workflow-protocol.md:64`、`skills/plan-first-plan/SKILL.md:83`～`skills/plan-first-plan/SKILL.md:97`、`bin/baton:472`～`bin/baton:479`）。  
- P1：review blocking 检测是 `grep -q "BLOCKING"`（`bin/baton:105`、`bin/baton:119`），如果 review 文本里出现 “No BLOCKING issues” 也会误判（字符串匹配过宽）。  
- P1：implement/verify 的 todo 检测只匹配行首 `- [ ]`（`bin/baton:156`），若 todo 不是该格式（缩进/编号/不同 Markdown 风格）会误判直接进入 verify。

**行为预测（关键场景）**
- “verification.md 先写了草稿”会让任务直接进入 review（甚至 done），造成 **未验证即收敛**。  
- quick-path 任务只要执行 `baton next` 或 `baton active <id>`（它们会调用 detect_phase 并重写 active-task：`bin/baton:489`～`bin/baton:499`、`bin/baton:531`～`bin/baton:533`），就可能从 `plan` 被“重算”回 `research (draft)`，使 session-start/using-baton 引导错误。

**建议**
- P0：把 `bin/baton:116`～`bin/baton:128` 的分支改为：仅当 `TASK-STATUS: DONE` 才进入 review/done，否则仍停留在 `verify`。  
- P0：在 `detect_phase()` 的 research/plan 判定前加入 `.quick-path` 判断；或在 `new-task --quick` 时自动写入 `RESEARCH-STATUS: CONFIRMED`（更符合“跳过 research gate”的意图）。  
- P1：review blocking 用更严格的模式（例如 `^BLOCKING` 或 `BLOCKING:`）。  
- P1：todo 未完成检测建议限定在 `## Todo` 区间内，减少误判。

---

### M7. `active-task`：阶段“单来源”与 CLI 的相互覆盖

**设计意图**
- protocol 声称“Skills 不改 active-task；phase 由 CLI detect_phase 决定”（`workflow-protocol.md:46`～`workflow-protocol.md:47`）。

**现实实现**
- `cmd_doctor` / `cmd_active` / `cmd_next` 都会运行 `detect_phase()` 并把 active-task 写成 `<task-id> <base-phase>`（`bin/baton:425`～`bin/baton:434`、`bin/baton:489`～`bin/baton:499`、`bin/baton:531`～`bin/baton:533`）。

**断点/偏差**
- active-task 既是“状态来源”，又会被多个命令重写；而 `detect_phase()` 的偏差（quick-path、verify）会被放大成“系统共识”。  

**行为预测**
- 任何一次 `baton next` 都可能把人为设置的 phase（例如 quick-path 的 plan）覆盖掉，进而影响 phase-lock 的读数（`hooks/phase-lock.sh:44`～`hooks/phase-lock.sh:52`）。

**建议**
- P1：在 `active-task` 里增加不可变的 `mode` 或 marker（例如 quick-path 标志），避免 detect_phase 覆盖掉意图。或让 detect_phase 读 `.quick-path`。

---

### M8. SessionStart hook：上下文广播机制（交互强引导）

**设计意图**
- SessionStart 输出 “REQUIRED ACTION: cat skill file” 以强制 AI 每次开始都先读 SKILL.md（`CHANGELOG.md:37`～`CHANGELOG.md:42`、`hooks/session-start.sh:4`～`hooks/session-start.sh:9`、`hooks/session-start.sh:80`～`hooks/session-start.sh:82`）。

**现实实现**
- 只读 `.baton/active-task`，不会自己 `detect_phase()`（除非 active-task 缺 phase：`hooks/session-start.sh:25`～`hooks/session-start.sh:30`）。
- quick-path 只显示 label，不影响 phase→skill 映射（`hooks/session-start.sh:58`～`hooks/session-start.sh:60` vs `hooks/session-start.sh:40`～`hooks/session-start.sh:52`）。
- “无 active task”时列出的 standalone skills **缺少 implement/verify**（`hooks/session-start.sh:97`～`hooks/session-start.sh:103`）。

**断点/偏差**
- quick-path 被 detect_phase 覆盖回 research 时，session-start 会指导加载 research skill（虽然 label 显示 quick-path），产生混乱。
- standalone 列表缺 implement/verify，和 `README.md:75`～`README.md:82` 不一致。

**建议**
- P2：补齐 standalone skills 列表；并在 quick-path 情况下明确“若 phase 为 research 但 quick-path 存在，下一步应加载 plan-first-plan”。

---

### M9. Phase-lock hook：强制门禁（最关键机制）

**设计意图**
- 在 research/plan/annotation/approved/slice 阶段阻断源码写入，只允许 `.baton/` 工件；在 implement 之后允许源码写入，但要求 plan APPROVED + Todo（`CHANGELOG.md:30`～`CHANGELOG.md:35`、`hooks/phase-lock.sh:10`、`hooks/phase-lock.sh:118`～`hooks/phase-lock.sh:153`）。
- v2.1 还希望对 slice scope 违规做 blocking（`hooks/phase-lock.sh:74`～`hooks/phase-lock.sh:96`）。

**现实实现**
- phase-lock 依赖：
  - `.baton/active-task` 的 phase（`hooks/phase-lock.sh:44`～`hooks/phase-lock.sh:52`）
  - **目标文件路径**（CLI 参数或 `BATON_TARGET_PATH`：`hooks/phase-lock.sh:113`）
  - todo item 编号（`BATON_CURRENT_ITEM`：`hooks/phase-lock.sh:78`）
- “允许写 `.baton/`”的逻辑需要 `TARGET` 非空才触发（`hooks/phase-lock.sh:115`～`hooks/phase-lock.sh:116`）。

**断点/偏差（P0）**
- `hooks/claude-settings.example.json` 的 PreToolUse hook 没有传入目标路径（`hooks/claude-settings.example.json:14`～`hooks/claude-settings.example.json:23`）。  
  若 Claude Code 不会自动注入 `BATON_TARGET_PATH`，则在锁定期（research/plan/annotation/approved/slice）**所有写操作都会被阻断**（包括写 `.baton/tasks/<id>/research.md`、`plan.md`），因为脚本无法识别“artifact path”（`hooks/phase-lock.sh:115`～`hooks/phase-lock.sh:125`）。  
  这会把工作流变成“永远无法推进”的死锁。
- slice scope blocking 同样依赖 `BATON_CURRENT_ITEM` 与 slice header 格式（`#slice-N`）（`hooks/phase-lock.sh:83`～`hooks/phase-lock.sh:88`），缺少注入时等同于“未启用”。

**行为预测**
- 在典型“按示例配置启用 hooks”的 Claude Code 环境里，如果没有额外环境变量注入，用户会观察到：  
  - 任何写文件工具一触发就失败，错误提示类似 `Blocked during phase='plan'`，并且无法写工件推进到 APPROVED（死锁）。
- 即便目标路径有注入：scope check 只检查 “Files NOT to modify” 子段落，且是正则匹配（`hooks/phase-lock.sh:87`～`hooks/phase-lock.sh:88`），可能出现误判/漏判。

**建议**
- P0：把 “目标路径如何传入”写成**硬前置条件**：在 README/Claude 配置中显式传递（例如把 tool input 的 path 注入为 `BATON_TARGET_PATH`），或在 phase-lock 里解析 hook 提供的上下文（如果 Claude hook 有 stdin JSON）。  
- P1：scope check 用固定字符串匹配（`grep -F`）并增强 slice 区间定位（不依赖 `-A 50`）。

---

### M10. “硬约束（hard-constraints）”与治理机制

**设计意图**
- `.baton/governance/hard-constraints.md` 是不可妥协规则；plan 阶段要预读并在 risk assessment 显式对齐（`CHANGELOG.md:62`～`CHANGELOG.md:66`、`skills/plan-first-plan/SKILL.md` Phase 1 Step 3）。
- review 阶段可以更新 `Last-validated`（`skills/code-reviewer/SKILL.md:24`、`skills/code-reviewer/SKILL.md:122`～`skills/code-reviewer/SKILL.md:126`）。
- `doctor`/`constraints` 提供健康检查与可视化（`bin/baton:325`～`bin/baton:444`、`bin/baton:645`～`bin/baton:674`）。

**现实实现**
- `init` 生成 universal HC-000（`bin/baton:267`～`bin/baton:291`），并注明由 phase-lock 实施（`bin/baton:273`～`bin/baton:278`）。
- `cmd_constraints` 通过 grep “Status:.*Active/STALE/Deprecated” 分类（`bin/baton:655`～`bin/baton:669`）。
- `cmd_doctor` 的 stale 检测只匹配固定格式 `- **Status:** 📌 STALE`（`bin/baton:397`～`bin/baton:405`），对格式有要求。

**断点/偏差**
- 治理机制多为“规范/文档”，真正强制只有 phase-lock 的 HC-000；其它约束需要 review 才能发现，缺少自动化验证脚本（这是可接受的设计取舍，但要明确）。

---

### M11. Context Slices：长上下文漂移治理 + 子代理交付

**设计意图**
- 用 slices 限制上下文、强化范围边界、支持并行分析（`skills/context-slice/SKILL.md:13`～`skills/context-slice/SKILL.md:17`、`skills/context-slice/SKILL.md:68`～`skills/context-slice/SKILL.md:70`）。
- implement skill 在 slice-mode 下只给 subagent slice + constraints，不给全 plan（`skills/plan-first-implement/SKILL.md:62`～`skills/plan-first-implement/SKILL.md:74`）。

**现实实现**
- 这是“行为规范”，不由 CLI 自动生成/执行；`bin/baton slice` 只会做 `## Todo` 存在性校验然后输出提示（`bin/baton:829`～`bin/baton:844`）。
- phase-lock 的 scope check 只阻断 “NOT to modify” 列表，且依赖外部注入 item number（`hooks/phase-lock.sh:74`～`hooks/phase-lock.sh:96`）。

**断点/偏差**
- protocol 写了 “implement (or slice skipped)”（`workflow-protocol.md:35`），但 `detect_phase` 把没 slices 的状态固定为 `slice`（`bin/baton:150`～`bin/baton:154`）；同时 implement skill又提供无 slices fallback（`skills/plan-first-implement/SKILL.md:89`～`skills/plan-first-implement/SKILL.md:96`）。  
  这会让“slices 是不是硬门槛”在不同部件里给出不同答案。

---

### M12. Verification：证据化验证与回归套件（Layer2）

**设计意图**
- verification-gate 强调“必须跑真实命令并记录输出证据”（`skills/verification-gate/SKILL.md:12`～`skills/verification-gate/SKILL.md:14`）。
- 支持 scope-based regression suites（`skills/verification-gate/SKILL.md:63`～`skills/verification-gate/SKILL.md:70`）。

**现实实现**
- CLI 没有执行 verification 的实现；只提供提示（`bin/baton:808`～`bin/baton:817`）。
- state machine 对 verify 的退出条件实现不一致（见 M6）。
- `doctor` 只要 project-config 里出现字符串 `"regression"` 就认为“Regression suites configured”（`bin/baton:380`～`bin/baton:386`），即使 suites 为空也会误报。

---

### M13. Review：四阶段审查 + 约束审计

**设计意图**
- code-reviewer skill 定义 Stage 1-4，并提供 severity 分类与 subagent prompts（`skills/code-reviewer/SKILL.md:74`～`skills/code-reviewer/SKILL.md:79`、`prompts/*`）。

**现实实现**
- 主要是流程规范；CLI 不自动执行 review，只能输出提示或由 AI 执行。

---

### M14. Smoke tests：回归防线（但目前存在结构性问题）

**设计意图**
- changelog 宣称“新增 smoke tests 覆盖 phase-lock during slice 等”（`CHANGELOG.md:73`～`CHANGELOG.md:77`）。

**现实实现（基于脚本内容）**
- 脚本存在未闭合引号，bash 解析将直接失败：
  - `tests/run-smoke-tests.sh:38` 仅有一个 `"`（经实际字符计数验证）
  - 类似问题也出现在 `tests/run-smoke-tests.sh:317`、`tests/run-smoke-tests.sh:319`
- `run_test()` 无论 pass/fail 都打印同样的“成功标记”（`tests/run-smoke-tests.sh:19`～`tests/run-smoke-tests.sh:29`）。
- 脚本没有出现对 `hooks/phase-lock.sh` 的调用或断言（与注释“covers phase-lock behavior”矛盾：`tests/run-smoke-tests.sh:3`）。
- quick-path 测试只检查 active-task 文件是否含 `qp1 plan`（`tests/run-smoke-tests.sh:224`～`tests/run-smoke-tests.sh:227`），并未验证 `detect_phase()` 的行为，因此无法捕获 quick-path 在 state machine 中的缺失。

**结论**
- 当前 smoke tests 不能作为“设计意图被实现”的证据来源。

---

## 2) 逐交互点审计（Interaction Points）

### I1. Human ↔ CLI（`baton ...`）

**交互契约（设计意图）**
- 人类用 CLI：`init/new-task/next/doctor/...` 管理状态与工件位置；AI 通过 skills 执行工作（`README.md:57`～`README.md:83`、`workflow-protocol.md:46`～`workflow-protocol.md:47`）。

**风险点**
- “Layer 0 命令”在 README/skills 语义上像“可直接执行”，但 CLI 只输出提示（`bin/baton:808`～`bin/baton:817`）。
- `baton next` 会重写 active-task phase（`bin/baton:531`～`bin/baton:533`），可能覆盖 quick-path 的设计意图（见 M6/M7）。

---

### I2. Human ↔ 工件（research.md / plan.md / verification.md / review.md）

**设计意图**
- 人类确认 research（`skills/plan-first-research/SKILL.md:79`～`skills/plan-first-research/SKILL.md:90`）、批准 plan（`skills/plan-first-plan/SKILL.md:183`～`skills/plan-first-plan/SKILL.md:191`）、通过 annotations 驱动设计收敛（`skills/annotation-cycle/SKILL.md:39`～`skills/annotation-cycle/SKILL.md:46`）。

**风险点**
- `_task-template/research.md` 过于简化，可能让人类误以为“写这些就够了”（`bin/baton:294`～`bin/baton:306` vs `skills/plan-first-research/SKILL.md`）。
- `detect_phase` 对 review/done 的判定依赖于工件存在与字符串匹配（`bin/baton:102`～`bin/baton:128`），很容易因为“写了草稿文件”导致 phase 提前推进。

---

### I3. AI 主代理 ↔ Skills（加载 SKILL.md 并执行）

**设计意图**
- 强制每次先读完整 SKILL.md（`hooks/session-start.sh:80`～`hooks/session-start.sh:82`、`skills/using-baton/SKILL.md:76`）。

**风险点**
- 如果 state machine / active-task 错了（quick-path、verify），AI 会被引导加载错误 skill，出现“做对的事但在错的阶段”或“卡住”。

---

### I4. AI 平台 ↔ Hooks（SessionStart / PreToolUse）

**设计意图**
- Claude Code：SessionStart 输出指导；PreToolUse 用 phase-lock 强制门禁（`README.md:85`～`README.md:89`、`hooks/claude-settings.example.json`）。

**风险点（P0）**
- phase-lock 需要目标路径才能放行 `.baton/` 工件写入（`hooks/phase-lock.sh:115`～`hooks/phase-lock.sh:116`），示例配置未提供；若平台也不提供，将导致死锁。

---

### I5. 主代理 ↔ Subagent（context slices + prompts）

**设计意图**
- 用 `prompts/implementer.md` 等模板进行子代理实现/审查（`prompts/implementer.md:31`～`prompts/implementer.md:44`、`prompts/spec-reviewer.md:14`～`prompts/spec-reviewer.md:18`）。

**风险点**
- 这是纯流程规范；系统没有“强制把 BATON_CURRENT_ITEM 与目标路径注入 hook”的实现，导致 scope enforcement 在现实中可能缺失。

---

## 3) 逐行为预测（Behavior Predictions / 场景表）

> 这里不写“应该怎样”，只写“按当前实现会怎样”（尤其是 `detect_phase()` + `phase-lock.sh` 的组合行为）。

### S0. 纯净仓库（无 `.baton/`）

- `detect_layer()`：0（`bin/baton:66`～`bin/baton:67`）
- phase-lock：直接退出 0（不生效）（`hooks/phase-lock.sh:104`～`hooks/phase-lock.sh:105`）
- session-start：输出 “Layer 0 (no active task)”（`hooks/session-start.sh:92`～`hooks/session-start.sh:109`）
- 现实效果：完全依赖自律；不具备强制门禁。

### S1. `baton init` 后（有 `.baton/`，无 active task）

- `detect_layer()`：2（`bin/baton:71`～`bin/baton:72`）
- `baton next`：会走 “No active task”分支并列出 standalone skills（`bin/baton:508`～`bin/baton:520`）
- phase-lock：因无 active-task，退出 0（不生效）（`hooks/phase-lock.sh:110`～`hooks/phase-lock.sh:111`）

### S2. `new-task t1`（research phase）

文件：`.baton/active-task = "t1 research"`，且 task dir 存在 research.md（模板）。
- `detect_phase(t1)`：`research (draft)`（`bin/baton:131`、`bin/baton:138`～`bin/baton:140`）
- `baton next`：写/确认 research.md（`bin/baton:541`～`bin/baton:546`）
- phase-lock：research 阶段阻断源码写入（`hooks/phase-lock.sh:120`～`hooks/phase-lock.sh:125`）
- **关键：若 hook 未提供目标路径**，连写 `.baton/tasks/t1/research.md` 也可能被阻断（见 M9）。

### S3. Quick-path：`new-task qp1 --quick`

文件：`.baton/tasks/qp1/.quick-path` 存在；active-task 被写成 `qp1 plan`（`bin/baton:472`～`bin/baton:479`）。
- **一旦执行 `baton next` 或 `baton active qp1`：**
  - 会调用 `detect_phase(qp1)`（`bin/baton:489`～`bin/baton:499` / `bin/baton:531`～`bin/baton:533`）
  - detect_phase 不读 `.quick-path`，若 research.md 是 DRAFT 且 plan.md 不存在，会回到 `research (draft)`（`bin/baton:133`～`bin/baton:140`）
  - active-task 被重写为 `qp1 research`
- 结果：quick-path 只在“刚创建且不调用 next/active/doctor”时成立；否则极易被“重算”覆盖。

### S4. plan APPROVED 但无 Todo（approved phase）

- `detect_phase()`：`approved (generating todo)`（`bin/baton:144`～`bin/baton:149`）
- phase-lock：`approved` 属于锁定期，阻断源码写入（`hooks/phase-lock.sh:120`～`hooks/phase-lock.sh:126`）
- 预期：只能改 plan.md 追加 Todo（合理）。

### S5. Todo 有了但无 Context Slices（slice phase）

- `detect_phase()`：`slice`（`bin/baton:150`～`bin/baton:154`）
- phase-lock：`slice` 仍锁定（`hooks/phase-lock.sh:120`～`hooks/phase-lock.sh:126`）
- 结果：系统强迫先生成 slices（与 “slice skipped” 文案冲突：`workflow-protocol.md:35`）。

### S6. implement：Todo+Slices 且仍有未勾选项

- `detect_phase()`：`implement`（`bin/baton:155`～`bin/baton:158`）
- phase-lock：允许源码写入，但要求 plan APPROVED + Todo（`hooks/phase-lock.sh:129`～`hooks/phase-lock.sh:153`）

### S7. verify：Todo 全勾选

- `detect_phase()`：`verify`（`bin/baton:158`～`bin/baton:160`）
- 注意：这只是 phase 判定；并不保证 verification 已执行。

### S8. verification.md 存在但没有 DONE（关键偏差）

- `detect_phase()`：仍进入 `review` / `done` 分支（`bin/baton:116`～`bin/baton:128`）
- 与 protocol（`workflow-protocol.md:36`）与 verification-gate exit condition（`skills/verification-gate/SKILL.md:25`）冲突。

### S9. review blocking 判定

- 只要 `review.md` 里出现字符串 `BLOCKING`，就判定 `review (blocking issues)`（`bin/baton:105`～`bin/baton:107`、`bin/baton:119`～`bin/baton:121`）
- 易误判：例如 “No BLOCKING issues”。

### S10. phase-lock 未收到目标路径（死锁场景）

前提：WORKFLOW MODE，phase=plan/research/annotation/approved/slice。  
若 hook 调用未传参且环境中也无 `BATON_TARGET_PATH`：
- `TARGET=""`（`hooks/phase-lock.sh:113`）
- `.baton/*` 放行条件不触发（`hooks/phase-lock.sh:115`～`hooks/phase-lock.sh:116`）
- 进入锁定期直接 `exit 1`（`hooks/phase-lock.sh:120`～`hooks/phase-lock.sh:126`）
=> 任何写操作都会失败，无法推进。

### S11. Windows / PowerShell 纯环境

- `bin/baton` / `hooks/*.sh` / `tests/*.sh` 都依赖 bash/sh；若系统无 bash，将无法运行 CLI/hook/test，整体退化为“只读文档技能、自律执行”。

---

## 4) 结论：主要断点清单（按优先级）

### P0（会导致系统不可用或明显违背设计意图）
- P0-1：`phase-lock` 集成缺少“目标路径注入”说明/实现，可能造成 locked phases **写工件死锁**（`hooks/phase-lock.sh:10`、`hooks/phase-lock.sh:113`、`hooks/phase-lock.sh:120` vs `hooks/claude-settings.example.json:14`）。  
- P0-2：quick-path 在 state machine 中缺失，`baton next/active/doctor` 会覆盖 quick-path 意图（`workflow-protocol.md:57`～`workflow-protocol.md:64` vs `bin/baton:130`～`bin/baton:141`）。  
- P0-3：verification 未 DONE 也能进入 review/done，破坏“证据化验证”设计意图（`bin/baton:116`～`bin/baton:128` vs `workflow-protocol.md:36`）。  
- P0-4：smoke tests 脚本疑似无法运行（未闭合引号：`tests/run-smoke-tests.sh:38` 等），回归防线缺失。

### P1（高概率造成误用/误导/漂移）
- P1-1：Layer0 命令在 CLI 中不执行，只输出提示；但技能文本与 README 命令列表容易让人理解为“会执行”（`README.md:75`～`README.md:82` vs `bin/baton:808`～`bin/baton:817`）。  
- P1-2：Cursor rules frontmatter `globs:` 为空，兼容性不确定（`bin/baton:715`～`bin/baton:719`）。  
- P1-3：review blocking 字符串匹配过宽、todo 检测脆弱（`bin/baton:105`、`bin/baton:156`）。  
- P1-4：`init` 的 research 模板与 research skill 的结构不一致（`bin/baton:294`～`bin/baton:306` vs `skills/plan-first-research/SKILL.md:92`）。

### P2（长期维护性/一致性问题）
- P2-1：CLI 与 hook 的 repo root 判定条件不一致（`bin/baton:40`～`bin/baton:41` vs `hooks/phase-lock.sh:30`～`hooks/phase-lock.sh:33`）。  
- P2-2：`reviews/` 目录疑似历史遗留（`bin/baton:225`、`bin/baton:464` vs `README.md:110`～`README.md:111`）。  
- P2-3：并行性分析与实现顺序执行的关系未制度化（`skills/context-slice/SKILL.md:68` vs `skills/plan-first-implement/SKILL.md:118`～`skills/plan-first-implement/SKILL.md:120`）。

---

## 5) 下一步（可选）

如果你希望我“按 P0→P1”把系统补到可落地闭环，我建议按这个顺序改：

1. 修 `hooks/claude-settings.example.json` +/或 `hooks/phase-lock.sh`：确保能可靠拿到目标路径（否则门禁无法用）。  
2. 修 `bin/baton detect_phase`：实现 quick-path、修正 verify→review 的 DONE 依赖。  
3. 修 `tests/run-smoke-tests.sh`：先让它能运行，再补上 phase-lock/quick-path 回归断言。  
4. 统一文档口径：把 “baton X invoke directly” 改成与 CLI 真实行为一致，或真正实现这些命令。


# Baton v2.1 — Codex 对 Claude 审计报告（audit-report-v2.md）的交叉评审

**评审人：** Codex（GPT-5.2）  
**评审对象：** `audit-report-v2.md`（Claude 的《Baton v2.1 技能包深度审计报告》）  
**评审范围：** 以“机制→交互点→运行时行为”三层校验 Claude 结论；补齐其遗漏点；给出修订评分与修复路线图  
**日期：** 2026-02-27  

---

## 0) 结论摘要（给维护者的可执行结论）

### 0.1 Claude 报告质量评分（报告本身）

**8.3 / 10**  
优点是“机制清单 + 矛盾/断点定位 + 运行时遵从率评估 + ROI 排序建议”非常成熟；主要扣分来自 **3 个高影响遗漏/低估**：`quick-path` 未落到状态机实现、`phase-lock` 的平台集成前提未被显式验证、smoke tests 对 `phase-lock` 的“覆盖声明”与实际不一致。

### 0.2 Baton v2.1 修订综合评分（系统本身）

**6.8 / 10（设计 9.0 / 工程落地 6.0 的折中）**  
我认可 Claude 的判断：Baton 的“设计哲学与行为工程”属于一线水平；但在“运行时强制链路（CLI 状态机 + hooks 传参契约 + tests）”上存在 **会改变系统真实行为的结构性缺口**，会把多个机制降级为“仅靠模型自觉遵守的软约束”。

### 0.3 我认为必须抬到 P0 的补充项（Claude 报告未覆盖或低估）

1. **Quick-path 在协议/技能/SessionStart/CLI 创建处存在，但 `detect_phase()` 完全不读取 `.quick-path`** → `baton next/active/doctor` 会把 quick-path 任务“重算回 research”，导致引导与约束错位（见 `workflow-protocol.md:57`、`bin/baton:90`、`bin/baton:446`、`hooks/session-start.sh:40`）。  
2. **`phase-lock.sh` 依赖 `TARGET`（参数或 `BATON_TARGET_PATH`）来放行 `.baton/` 工件写入，但示例 hook 未传参** → 若平台未注入 `BATON_TARGET_PATH`，锁定期可能连 `plan.md/research.md` 都写不了（潜在“死锁型体验”）（见 `hooks/claude-settings.example.json:14`、`hooks/phase-lock.sh:13`、`hooks/phase-lock.sh:113`）。  
3. **smoke tests 声称覆盖 `phase-lock`，但脚本中没有任何对 `hooks/phase-lock.sh` 的调用或断言** → 回归保护缺失（见 `tests/run-smoke-tests.sh:3`）。  

---

## 1) Claude 报告的强项（哪些判断非常准）

下面这些结论我逐文件核对后认为 **准确且高价值**，可以直接作为修复优先级依据。

### 1.1 `detect_phase` 的 verification 判定缺失“失败态”——结论正确

`detect_phase()` 当前把“`verification.md` 存在”视为进入 `review` 分支，并且在 `review.md` 存在且不含 `BLOCKING` 时甚至会返回 `done`（即使 `verification.md` 没有 `TASK-STATUS: DONE`）——这与“验证门禁”的设计意图冲突（见 `bin/baton:90`~`bin/baton:128`）。  
Claude 将其总结为缺少 `verify-failing` 状态是对的；同时还应指出：**`review` 文件的存在会让系统提前宣布 done**，这是更危险的边界条件。

### 1.2 “slice 必须 / implement 可选 slice”矛盾——结论正确

WORKFLOW MODE 下，`detect_phase()` 在 `plan.md` 已 APPROVED 且含 `## Todo` 但无 `## Context Slices` 时强制返回 `slice`（见 `bin/baton:143`~`bin/baton:155`）。  
但 `plan-first-implement` 允许“无 slices 也能实施（只是质量降级）”（见 `skills/plan-first-implement/SKILL.md:92`~`skills/plan-first-implement/SKILL.md:96`）。  
因此 Claude 所说“implement 的 fallback 在 WORKFLOW MODE 下永远触发不了”本质成立：状态机把它变成“standalone only”。

### 1.3 `BATON_CURRENT_ITEM` 未设置导致 slice scope check 失效——结论正确

`phase-lock.sh` 的 scope enforcement 以 `BATON_CURRENT_ITEM` 为开关：变量为空则直接 `return 0`（不检查）（见 `hooks/phase-lock.sh:74`~`hooks/phase-lock.sh:98`）。  
Repo 内未找到任何地方设置 `BATON_CURRENT_ITEM`（除 `phase-lock.sh` 自身注释外），所以 Claude 将其定性为“死代码”是合理的：**该机制目前几乎不可能在真实运行时生效**。

### 1.4 `research.md` 模板多源不一致——结论正确且应视为 P0

初始化模板较短（`bin/baton:294`~`bin/baton:306`），`plan-first-research` 则定义了更严格更长的结构（见 `skills/plan-first-research/SKILL.md:92`~`skills/plan-first-research/SKILL.md:155`），而 `new-task` 在缺少模板时甚至只写入一个标题行（见 `bin/baton:446`~`bin/baton:468`）。  
Claude 的判断（“模板冲突会导致 AI 混淆、造成日常摩擦”）符合真实运行时：不同入口创建出的 research.md 形状不同，会让后续技能的 checkpoint 与 gating 判断失配。

### 1.5 `reviews/` 目录遗留与 `review.md` 路径不一致——结论正确

`init/new-task` 会创建 `.baton/tasks/<id>/reviews/`（见 `bin/baton:225`、`bin/baton:462`~`bin/baton:468`），但 `code-reviewer` 约定输出是 `.baton/tasks/<id>/review.md`（见 `skills/code-reviewer/SKILL.md:34`），`detect_phase` 也只看 `$task_dir/review.md`（见 `bin/baton:100`）。  
这属于“实现遗留/命名漂移”，不一定致命，但会误导维护者与用户，Claude 把它列为一致性问题是合理的。

---

## 2) Claude 报告的关键遗漏/需要修正之处（会改变运行时结论）

### 2.1 Quick-path：设计存在，但状态机实现缺失（Claude 仅列名未审到实现断点）

**设计意图（协议）：** quick-path 通过 `.baton/tasks/<id>/.quick-path` 让任务“跳过 research gate”（见 `workflow-protocol.md:57`~`workflow-protocol.md:64`）。  
**现状（实现）：**

- `new-task --quick` 会创建 `.quick-path` 并把 `active-task` 写为 `plan`（见 `bin/baton:446`~`bin/baton:479`）。  
- `session-start.sh` 会展示 quick-path 标签，但**技能选择仍取决于 active-task 的 phase**（见 `hooks/session-start.sh:40`~`hooks/session-start.sh:60`）。  
- 最关键：`detect_phase()` **完全不读取 `.quick-path`**（见 `bin/baton:90`~`bin/baton:170`）。`baton active` / `baton next` 会调用 `detect_phase()` 并重写 `active-task`（见 `bin/baton:482`~`bin/baton:533`），从而把 quick-path 任务重新判为 `research (not started/draft)`。

**运行时后果（行为预测）：**

1. 用户创建 quick-path 任务后，只要执行一次 `baton next` 或 `baton active <id>`，active-task 很可能被重算覆盖，quick-path 的“跳过 research gate”失效。  
2. 更隐蔽的问题是：SessionStart 仍会显示 `Mode: quick-path`，但 phase 若被重算为 research，系统会要求加载 `plan-first-research`（见 `hooks/session-start.sh:76`~`hooks/session-start.sh:83`），造成“标签与指令相互矛盾”的体验。  

这属于 **会直接改变系统行为的结构性 bug**，建议纳入修订评分与 P0 修复列表。

### 2.2 Phase-lock：可靠性强，但“平台传参契约”未被 Claude 报告充分审计

Claude 将 Phase-lock 视为最可靠约束之一，这在“脚本逻辑本身”层面成立；但其真实可靠性高度依赖 **hook 是否能把目标路径传给脚本**。

**脚本契约：** `phase-lock.sh` 只有在知道 `TARGET` 时，才能放行 `.baton/` 工件写入（见 `hooks/phase-lock.sh:13`、`hooks/phase-lock.sh:113`、`hooks/phase-lock.sh:116`）。  
**示例配置：** `hooks/claude-settings.example.json` 的 PreToolUse hook 仅执行 `sh ~/.baton/hooks/phase-lock.sh`，没有传入 `[target_path]`（见 `hooks/claude-settings.example.json:14`~`hooks/claude-settings.example.json:23`）。  

**运行时后果（行为预测）：**

- 若平台未注入 `BATON_TARGET_PATH`（或注入字段名不同），在 `research/plan/annotation/slice/approved` 等锁定期（见 `hooks/phase-lock.sh:118`~`hooks/phase-lock.sh:127`），脚本会把所有写入都视为“非工件写入”，从而**连 `.baton/tasks/<id>/plan.md` 这种工件也会被阻断**。  
- 这会把“纵深防御”变成“无法开始工作的硬阻塞”，并且用户从日志里不一定能理解原因（因为 `Target` 为空）。

这不是对 Claude 结论的否定，而是补上一条关键前提：**Phase-lock 的可靠性应按“平台是否提供 TARGET”分段评分**，并在文档/测试中显式验证。

### 2.3 smoke tests 的覆盖声明与实际不一致（会影响对工程成熟度的评分）

`tests/run-smoke-tests.sh` 顶部声称覆盖 phase-lock（见 `tests/run-smoke-tests.sh:3`），但脚本内没有任何 `phase-lock` 相关调用或断言。  
这会让“工程实现八成完成”的判断偏乐观：**最关键的强制机制缺少回归测试**，一旦 hook 平台或脚本行为变化，很难第一时间发现。

---

## 3) 逐机制复核（按 Claude 的 18 个机制逐项对照：覆盖度/实现度/运行时风险）

说明：这里的“覆盖度”是指 Claude 报告是否进行了“落到实现断点的审计”；“实现度”是指 repo 当前是否具备可运行的强制链路（而不是只有文档/意图）；“风险”面向真实 AI 运行时（会不会把机制降级为软约束或直接失效）。

| # | 机制（Claude） | 覆盖度（Claude） | 实现度（Repo） | 运行时风险 | Codex 评语（含关键证据入口） |
|---|---|---|---|---|---|
| 1 | 循环批注 | 高 | 高 | 中 | 机制本身清晰；但“确认语义”（looks good 等）仍会造成误触发（Claude 已指出），需要更结构化的确认标记。 |
| 2 | 上下文切片 | 高 | 中 | 中-高 | 状态机强制 slice（`bin/baton:150`）提升一致性，但 `BATON_CURRENT_ITEM` 未设置使“scope enforcement”失效（`hooks/phase-lock.sh:78`）。 |
| 3 | 设计-Todo 分离 | 高 | 高 | 中 | 协议+技能一致；但 `approved (generating todo)` 到 `slice` 的链路仍需要人工介入与格式正确性。 |
| 4 | 反合理化系统 | 高 | 高 | 中 | Claude 分析充分；但其效果上限受“软约束”影响：未被 hook 强制的环节依赖模型自律。 |
| 5 | 证据优先方法论 | 高 | 中 | 中 | `plan-first-research` 强，`cmd_init/new-task` 生成的 research.md 模板弱，导致证据结构不稳定（`bin/baton:294`、`bin/baton:467`）。 |
| 6 | 三层架构 + 降级 | 高 | 中 | 中 | Claude 判断正确；但降级路径与强制机制（hooks）在不同平台上的“是否生效”缺少可验证声明。 |
| 7 | 唯一责任人原则 | 中 | 中 | 低-中 | 主要体现在 `workflow-protocol.md` 的职责分配（`workflow-protocol.md:46`~`workflow-protocol.md:47`）；实现层面没有硬冲突仲裁。 |
| 8 | Phase-lock 纵深防御 | 中-高 | 中 | 高 | 逻辑强，但依赖 `TARGET/BATON_TARGET_PATH` 注入（`hooks/phase-lock.sh:113`）与 `BATON_CURRENT_ITEM`；示例 hook 未传参（`hooks/claude-settings.example.json:20`）。 |
| 9 | Protocol 单一真相源 | 高 | 中 | 中 | 多处仍出现“协议说有、实现未落地”（quick-path、回退路径）；见 `workflow-protocol.md:57` vs `bin/baton:90`。 |
| 10 | 内联检查点 | 高 | 高 | 中 | 对抗模型偏离有效；但需与 CLI/hook 的硬门禁协作，否则只提升概率。 |
| 11 | Assume-bug-first 审查法 | 高 | 中 | 中 | `code-reviewer` 有结构；但状态机对 verify/review/done 的边界处理有偏差（`bin/baton:116`）。 |
| 12 | 升级阶梯 | 中 | 中 | 中 | 主要存在于 implement skill；但与 `baton auto` 缺失相叠加会增加人工协调成本。 |
| 13 | Announce 模式 | 中 | 高 | 低 | 纯行为提示，实施成本低；Claude评价合理。 |
| 14 | “有能力但无上下文的开发者”模型 | 中 | 高 | 中 | 要求 plan 写得像“可执行 spec”；但 research 模板不统一会拖累上下文质量。 |
| 15 | Hard constraints 生命周期 | 中 | 中 | 中 | `baton init` 会生成 `.baton/governance/hard-constraints.md`（`bin/baton:244`~`bin/baton:291`），但持续校验与过期治理仍偏手工。 |
| 16 | Review routing 预加载 | 中 | 中 | 低-中 | 主要在 plan-first-plan 的提示/路由，属于“提高覆盖率”的软机制。 |
| 17 | 子代理注入协议 | 低-中 | 中 | 中 | prompts 存在（`prompts/implementer.md` 等），但触发条件与边界（何时必须用子代理）尚不硬化。 |
| 18 | Quick-path 快速通道 | 低（仅列名） | 低 | 高 | 设计与 UI 标签存在，但状态机实现缺失（`workflow-protocol.md:57` vs `bin/baton:90`）；会导致实际体验与设计意图相反。 |

---

## 4) 逐交互点复核：AI 实际运行时“会怎样”（并对 Claude 预测做修订）

### 4.1 交互点 A：`SessionStart` 注入（提示强，但不是强制）

`hooks/session-start.sh` 的输出会要求“先 cat 对应 skill 的 SKILL.md”（见 `hooks/session-start.sh:76`~`hooks/session-start.sh:83`）。  
Claude 已正确指出：这是“提示/引导”，不是平台级硬保证。若模型忽略该提示，后续仍可能跳步。

**修订点：** 若 quick-path 被 `detect_phase` 覆盖为 research，SessionStart 会出现“Mode: quick-path”但要求加载 research skill 的矛盾（见 `hooks/session-start.sh:58`~`hooks/session-start.sh:60` + `hooks/session-start.sh:40`~`hooks/session-start.sh:52`）。

### 4.2 交互点 B：`baton next`/`baton active` 的“重算并写回 active-task”

`cmd_next`/`cmd_active` 都会调用 `detect_phase()` 并把 base phase 写回 `.baton/active-task`（见 `bin/baton:482`~`bin/baton:499`、`bin/baton:507`~`bin/baton:533`）。  
这意味着：**任何 detect_phase 的偏差都会被放大为系统共识**，进一步影响 session-start、phase-lock（读取 phase）、以及人类对“当前状态”的判断。

**修订点：** 这条机制会把 quick-path bug 的影响从“创建瞬间的小瑕疵”放大为“工作流长期不稳定”。

### 4.3 交互点 C：PreToolUse Phase-lock（强制力取决于参数注入）

Claude 将 phase-lock 视为可靠是基于脚本逻辑；但真实执行依赖 hook 平台是否提供目标路径（`BATON_TARGET_PATH` 或脚本参数），否则 `.baton/` 工件的“永远允许”规则无法生效（见 `hooks/phase-lock.sh:10`~`hooks/phase-lock.sh:20` + `hooks/phase-lock.sh:113`~`hooks/phase-lock.sh:126`）。

**修订点（行为预测）：**

- 平台注入正确：research/plan 等阶段能写 `.baton/`，不能写源文件，体验符合设计。  
- 平台注入缺失：research/plan 等阶段连 `.baton/` 都写不了，系统表现为“无法推进/卡死”。  

### 4.4 交互点 D：skills 的“软约束”与“硬约束”组合

- 硬约束：phase-lock（当且仅当 hook 正常传参、且用户平台支持）。  
- 软约束：SKILL.md 的 checkpoints、rationalization 表、announce 等。

Claude 对“软约束能提升遵从率但无法完全保证”的判断成立；我补充一点：**当 CLI 状态机把 phase 引导错了（quick-path、verify/done 边界），软约束会被错误 skill 的约束覆盖**，导致“做对的事但在错的阶段”或“被错误禁止而停滞”。

---

## 5) 修订后的问题清单与路线图（融合 Claude Top5 + Codex 补充）

> 目标是让机制从“理念正确”变成“运行时确定性正确”。下面按对真实可用性的边际收益排序。

### P0（立即修，修完系统观感会明显变）

1. **补齐 quick-path 的状态机实现**：让 `detect_phase()` 读取 `.quick-path` 并跳过 research gate（或在 quick-task 时自动写入 research CONFIRMED）。（证据入口：`workflow-protocol.md:57`、`bin/baton:90`、`bin/baton:446`）  
2. **明确并固化 phase-lock 的 TARGET 传参契约**：示例 hook 要么显式传入目标路径，要么在 `TARGET` 为空时采用“安全退化”（至少放行 `.baton/`）并打印可诊断警告。（证据入口：`hooks/claude-settings.example.json:20`、`hooks/phase-lock.sh:113`）  
3. **实现 `BATON_CURRENT_ITEM` 的设置链路（或重新设计 scope enforcement）**：否则 slice scope check 永久形同虚设。（证据入口：`hooks/phase-lock.sh:78`）  
4. **统一 research.md 模板来源**：以 `plan-first-research` 的结构为准，或在 CLI 初始化时生成同构模板，避免多入口漂移。（证据入口：`bin/baton:294`、`skills/plan-first-research/SKILL.md:92`、`bin/baton:467`）  
5. **修正 verify/review/done 判定边界**：至少引入 `verify (failing)` 或“verification exists but not DONE”不应直接变成 done。（证据入口：`bin/baton:116`）  

### P1（能显著降低日常摩擦）

1. **为 phase-lock 与 quick-path 增加真实回归测试**：当前 smoke tests 未覆盖 phase-lock（`tests/run-smoke-tests.sh:3`），quick-path 也未验证 detect_phase 行为（`tests/run-smoke-tests.sh:213`~`tests/run-smoke-tests.sh:227`）。  
2. **补齐 review→fix→re-verify 的“推荐动作”映射**：即使不引入新 phase，也应在 `baton next` 的 guidance 或协议中明确“blocking 时下一步加载 implement skill”。  
3. **增加 `baton skip-slice` / `baton auto`**（Claude 已建议）：减少小任务仪式感与人工切换成本。  

### P2（治理与体验完善）

1. **清理遗留目录/命名漂移**：比如 `.baton/tasks/<id>/reviews/` 的遗留（`bin/baton:225`）以降低认知噪声。  
2. **更结构化的人类确认机制**：用显式标记替代自然语言“looks good”。  

---

## 6) 评分说明（为何我把系统总分从 7.5 下调到 6.8）

Claude 的 7.5/10 在“设计哲学权重更高”的评分模型下是自洽的；但在“AI 真实运行时确定性”权重更高时，以下三点会系统性拉低分数：

1. **状态机偏差会被写回 active-task 并放大**（quick-path、verify/done 边界）。  
2. **强制链路依赖平台隐式注入**（`BATON_TARGET_PATH`、`BATON_CURRENT_ITEM`）而 repo 内未提供可验证契约与测试。  
3. **测试未覆盖最关键的强制机制**，工程成熟度不应按“存在脚本”计分，而应按“被回归保护”计分。

因此我建议将“AI 实际遵从率”“跨平台可靠性”“工具链完备性”三个维度整体下调 0.5~1.5 分区间，并把“Quick-path 状态机缺失/phase-lock 传参契约”作为 P0 加权惩罚项，得到约 **6.8/10** 的更稳健估计。


# Baton 项目优缺点分析 — 基于 v5 Flat Install 实施会话实证

**来源**: 2026-03-21 完整会话实录（/office-hours → /plan-eng-review → /baton-plan → /baton-implement → baton-review → commit）
**方法**: 从 AI 实际执行行为、阻塞事件、时间消耗、质量拦截中提取证据。非理论推演。

---

## 一、优势（经本次会话验证）

### 1. 前置验证拦截了重大设计错误

**证据**: /office-hours 设计文档选择了 Plugin-based 方案（Approach B）。/plan-eng-review 阶段实际验证 Claude Code 的 `extraKnownMarketplaces` API，发现仅支持 `{"source": "github"}`，无本地目录注册。

**影响**: 如果跳过 eng review 直接实施 plugin 方案，会在实现中途发现不可行，浪费全部 plugin 代码。实际成本：验证花费 ~5 分钟（读 settings.json + known_marketplaces.json），避免了 ~1 小时无效实现。

**结论**: research → plan → review 的分阶段验证在本次会话中产生了真实 ROI。这不是流程形式主义 — 它救了整个任务。

### 2. Write-lock 阻止了未授权修改

**证据**: 在 BATON:GO 放置前，多次 Bash 命令（output redirection `>`、`>>`）被 bash-guard.sh 以 exit 2 阻塞。AI 被迫使用 Write/Edit 工具代替 shell 重定向。

**影响**: 防止了"先改再说"的惯性。AI 必须等待 human 放置 BATON:GO 后才能修改源码。

**结论**: 对于防止 AI 越权修改，write-lock 是有效的硬约束。

### 3. Implementation review 抓到了真实遗漏

**证据**: baton-review 发现 `test-cli.sh` 在 plan write set（Todo item 10）中列出但未被修改。该文件测试已删除的命令（`list`、`init $dir`、`update --all`、`doctor $dir`），运行时必定 fail。

**影响**: 如果没有 review，这个遗漏会在下次运行 test-full.sh 时暴露，但那时可能已经 commit + push。review 在 commit 前拦截了它。

**结论**: context-isolated review（通过 Agent 调度、reviewer 无法看到实施过程中的推理）比 self-check 更有效。reviewer 不受生成偏差影响。

### 4. Todo verification fields 保持了实施焦点

**证据**: 每个 Todo item 有明确的 Verify 字段（如 "读取确认逻辑正确"、"bash tests/test-setup.sh 通过"）。AI 在标记 ✅ 前必须执行验证命令并展示输出。

**影响**: 没有出现 "我已经检查了" 的空洞声明。每次验证都有可见的工具调用和输出。

### 5. Unexpected Discovery Protocol 正确分类了范围变更

**证据**: annotation-template.md 保留在 `.baton/` 中被识别为 B-level（adjacent integration），记录在 Implementation Notes 中，不阻塞实施。parser_has_skill 行为变更导致的测试失败也在 review 后被正确修复。

**影响**: 没有出现 "顺手改了个东西结果引入 bug" 的场景。每个超出 write set 的变更都被显式记录和分类。

---

## 二、缺点（经本次会话暴露）

### 1. 上下文消耗极大 — 会话被强制压缩

**证据**: 本次会话在实施到 Todo item 10 时触发了 context compaction。完整会话包括 /office-hours、/plan-eng-review、/baton-plan、/baton-implement 四个技能，每个技能注入数千 token 的 SKILL.md 指令。加上 constitution.md、SessionStart hook 注入的 using-baton 全文、各类 system-reminder，实际可用于任务推理的上下文被大幅压缩。

**量化**:
- constitution.md: ~3,000 tokens
- using-baton/SKILL.md: ~2,500 tokens
- baton-implement/SKILL.md: ~4,000 tokens
- baton-plan/SKILL.md: ~3,500 tokens
- SessionStart hook output: ~1,500 tokens
- 每次 system-reminder（技能列表）: ~3,000 tokens
- **总治理开销估计: ~17,500 tokens**（约占 200K 上下文的 8.75%）

**影响**: AI 在后期失去了早期设计讨论的细节（office-hours 阶段的 premise challenge、alternatives evaluation）。compaction 后依赖 summary，summary 不可避免地丢失 nuance。这意味着一个足够复杂的任务可能无法在单次会话中完成完整的 research→plan→implement→review 循环。

**根因**: 每个技能假设自己是唯一活跃的技能，独立注入完整指令。没有"已加载技能 X 的简版"机制。

### 2. Bash-guard 误阻——在 gate-open 时仍制造摩擦

**证据**: 实施阶段（BATON:GO 已在 plan.md 中），AI 执行 `echo ... > file` 形式的 Bash 命令时被 bash-guard 阻塞。原因：bash-guard 从 CWD 开始 walk-up 查找 plan.md，但实际的 plan.md 在 `baton-tasks/v5-flat-install/plan.md`，不在 CWD 或其祖先目录中。

**影响**: AI 被迫使用 Write 工具代替 shell 重定向。Write 工具对于创建完整文件是合适的，但对于 `echo "test" > /tmp/foo` 这类临时操作是不必要的摩擦。AI 学会了"绕过"而非"被保护"。

**根因**: bash-guard 的 plan discovery 机制不知道 `BATON_PLAN` 环境变量在项目级 settings.json 中设置了什么，walk-up 也无法发现 baton-tasks/ 子目录中的 plan.md。这是 hook 执行上下文与 plan 位置之间的 impedance mismatch。

### 3. 预存测试失败长期未修复——系统不强制技术债清理

**证据**: 5 个测试在 v5 变更前就失败：
- test-phase-guide.sh: 检查 guidance 文本中的 "approach"/"constraints"/"批注区" 等关键词，但 phase-guide.sh 的输出文本已在之前版本中修改
- test-constitution-consistency.sh: 检查 "Authority Model" 等章节名，但 constitution.md 已重命名为 "Authority"
- test-annotation-protocol.sh: 21 个失败，检查 "[PAUSE]"/"Annotation Log"/"infers intent" 等文本，但相关功能已重构
- test-write-lock.sh: 2 个 multi-plan edge case
- test-bash-guard.sh: 2 个 edge case

**影响**: 这些失败长期存在，使 `test-full.sh` 永远返回 exit 1。这导致 "full test suite pass" 这个完成条件实际上被绕过了——AI 和 human 都接受了 "pre-existing failures" 作为豁免。一旦 "已知失败" 成为常态，新引入的失败也更容易被误归类为 "pre-existing"。

**根因**: baton 的完成条件要求 "full test suite pass"，但没有机制区分 "baseline failures" 和 "regression failures"。也没有强制修复 baseline failures 的工作流。

### 4. Review 噪声——LOW findings 分散注意力

**证据**: baton-review 返回 1 HIGH + 3 LOW findings。HIGH（test-cli.sh 遗漏）有真实价值。但 3 个 LOW findings（BATON_PLAN env var 移除、test-adapters.sh 路径、test-bash-guard.sh 路径更新）都是不需要行动的观察。

**影响**: AI 需要阅读和评估每个 finding，决定是否需要修复。LOW findings 的 action cost 接近 HIGH findings（都需要思考和判断），但 value 接近零。在上下文窗口紧张的情况下，这些 LOW findings 消耗了宝贵的推理空间。

**改进方向**: review prompt 可以要求只报告 HIGH/MEDIUM findings，或将 LOW findings 压缩为一行摘要而非完整 finding 块。

### 5. 技能间缺乏协调——重复加载、重复提醒

**证据**:
- `/office-hours` 完成后推荐 `/plan-eng-review`，eng-review 完成后推荐 `/baton-plan`——但每个技能启动时都执行完整的 preamble check（gstack update、telemetry prompt、lake intro）
- using-baton 在 SessionStart 时注入完整内容，然后每个 phase skill 又注入自己的完整 SKILL.md
- system-reminder 中的可用技能列表（~100 个）在每次工具调用后都重复出现

**影响**: 同一条信息（如 "verify = visible output"）在 constitution.md、baton-implement/SKILL.md、using-baton/SKILL.md 中各出现一次。AI 收到三次相同指令，但每次都消耗上下文空间。

### 6. 从 research 到 commit 的端到端耗时长

**证据**: 本次会话经历了：
1. /office-hours（设计文档 + YC 流程）
2. /plan-eng-review（4 个 review section + AskUserQuestion 循环）
3. 设计文档修订（plugin → flat install pivot）
4. /baton-plan（plan artifact 生成）
5. /baton-implement（10 Todo items + review + fixes）
6. commit

对于一个"把文件从 A 目录移到 B 目录 + 重写 setup.sh"的任务，流程开销显著。

**反论**: 流程确实拦截了 plugin 方案这个重大错误。但如果任务本身没有隐藏的设计风险（如纯重构），完整流程可能是过度的。

**根因**: baton 的 sizing mechanism（Trivial/Small/Medium/Large）在本次会话中被正确评估为 Medium。但 Medium 要求的"完整流程"包括了一些在本次任务中不产生价值的步骤（如 office-hours 的 YC plea、eng-review 的 performance review section）。

### 7. baton-evolve 同模型自审盲区 — 10 轮进化 0 发现 vs Codex 1 轮 8 发现

**证据**: 在 v5 plan 的 evolve 阶段，baton-evolve 使用 baton-review 作为评估器，连续运行 10 轮迭代（evolve-iter-1 到 evolve-iter-11），每轮对 plan 进行修改并提交。10 轮结束后，plan 收敛——baton-review 报告无剩余问题。

随后使用 Codex（OpenAI）对同一 plan 进行独立审查，1 轮发现 8 个 baton-evolve 完全忽略的问题：

| 发现 | evolve 发现过？ | 严重度 |
|------|:---:|:---:|
| dispatch.sh 用 `$(pwd)` 而非 `parser_project_root`，子目录检测失效 | 否 | HIGH |
| 插件 skills 被自动命名空间化（`baton:baton-review` vs `/baton-review`），phase-guide 输出失效 | 否 | HIGH |
| 迁移阶段顺序错误：先移动再更新调用方 = 中断窗口 | 否 | HIGH |
| Cursor/Codex adapter 依赖被移走的 `.baton/hooks/` | 否 | MEDIUM |
| `BATON_HOME` vs 插件缓存两个版本权威源 | 否 | MEDIUM |
| 计划承认未验证插件机制但绕过了它 | 否 | MEDIUM |
| 测试安排太晚——应在重构前验证插件机制 | 否 | MEDIUM |
| 未评估更简单替代方案就假定插件是正确答案 | 否 | LOW |

**根因分析**:

1. **同模型盲区**: baton-evolve 和 baton-review 都由 Claude 执行。Claude 审查 Claude 的输出，共享相同的推理模式和盲区。如果 Claude 在生成 plan 时不会注意到命名空间冲突，那么 Claude 在审查 plan 时同样不会注意到。这是 fundamental 的——不是 prompt engineering 能解决的。

2. **review prompt 的结构性局限**: baton-review 的 review-prompt.md 定义了检查维度（completeness、consistency、plan contract alignment），但这些维度都是 **文档内部一致性** 检查。Codex 发现的问题大多是 **文档与外部系统的不一致**（Claude Code 插件命名空间规则、adapter 文件依赖关系、迁移时序约束）。baton-review 的 prompt 没有要求 reviewer 去验证计划中关于外部系统行为的假设。

3. **收敛 ≠ 正确**: evolve 循环的退出条件是"baton-review 报告无问题"。10 轮后确实收敛了——但收敛到的是一个 **在同模型评估框架下看起来完美、实际有 8 个盲区** 的 plan。收敛速度甚至是负信号：越快收敛，说明 reviewer 和 generator 越一致，越可能共享盲区。

**影响**: 这是 baton 治理模型中最严重的结构性缺陷。baton 的 defense model 声称三层防御（self-check + context-isolated review + human annotation），但当 self-check 和 review 都由同一模型执行时，前两层实质上退化为一层。只有 human annotation 和 cross-model review 能弥补。

**改进方向**:
- baton-evolve 的评估器应支持 cross-model review（如 Codex、Gemini）作为必选或可选层
- baton-review 的 prompt 应增加"外部系统假设验证"维度——要求 reviewer 列出 plan 中关于外部系统行为的每个假设，并标注哪些已验证、哪些未验证
- evolve 循环的退出条件应包含 "至少一次 cross-model evaluation"，而非仅靠同模型收敛

### 8. 自指悖论仍未完全解决

**证据**: 在 baton 源码仓库中开发 baton 时：
- bash-guard 从 CWD walk-up 找 plan.md，但 plan 在 baton-tasks/ 中
- v5 的 setup.sh 修改 `~/.claude/settings.json`，但当前会话的 hooks 也从 settings.json 加载——修改 settings.json 可能影响当前会话的 hook 行为
- `git rm` 无法删除通过 compat symlink 指向的文件（".baton/hooks/lib/junction.sh is beyond a symbolic link"）

**影响**: 需要额外的 workaround（`git rm -f`、使用 Write 工具代替 shell 重定向）。这些 workaround 不影响最终结果，但增加了实施复杂度。

---

## 三、综合评价

### 值得保留的

| 机制 | 本次验证 | 理由 |
|------|---------|------|
| Write-lock (bash-guard + write-lock.sh) | 阻止了未授权修改 | 硬约束有效 |
| Plan-first workflow (research → plan → GO) | 拦截了 plugin 方案错误 | 前置验证 ROI 明确 |
| Context-isolated review | 抓到 test-cli.sh 遗漏 | 消除生成偏差 |
| Todo + Verify fields | 每个 item 有可见验证 | 防止空洞声明 |
| Unexpected discovery protocol | 正确分类 B-level 变更 | 范围控制有效 |
| Retrospective requirement | 产生了非通用的 insights | wrong prediction 格式迫使反思 |

### 需要改进的

| 问题 | 严重度 | 建议 |
|------|--------|------|
| **evolve 同模型自审盲区** | **CRITICAL** | **评估器必须支持 cross-model review；退出条件包含至少一次异模型评估** |
| 上下文消耗过大 | HIGH | 技能应有"简版"模式；已加载的技能不重复注入全文 |
| 预存测试失败常态化 | HIGH | 引入 baseline failure 机制——记录已知失败，只要 regression = 0 即可 PASS |
| bash-guard 与 plan 位置 impedance mismatch | MEDIUM | bash-guard 应读取 BATON_PLAN env var + 支持 baton-tasks/ 发现 |
| review LOW findings 噪声 | MEDIUM | review prompt 只报告 HIGH/MEDIUM，LOW 压缩为一行 |
| 技能间重复加载 | MEDIUM | 引入"技能已加载"标记，跳过重复 preamble |
| 端到端流程长 | LOW | 对于明确的重构任务，允许跳过 office-hours/eng-review 中不适用的 section |
| 自指悖论 | LOW | 接受为边界情况，不值得为此增加复杂度 |

### 核心张力

Baton 的价值 = **拦截错误的概率 × 错误成本 - 流程摩擦成本**

本次会话中：
- 拦截了 1 个重大设计错误（plugin 方案，cost ~1h）
- 拦截了 1 个实施遗漏（test-cli.sh，cost ~30min debug）
- 流程摩擦成本：context compaction、bash-guard 误阻、review 噪声、多技能重复加载

净值为正。但这个净值很大程度上依赖于"任务确实存在隐藏的设计风险"。对于一个无隐藏风险的简单重构，净值可能为负。

**关键 insight 1**: baton 最大的价值不是在 implement 阶段（那里的 write-lock 更多是摩擦而非保护），而是在 research → plan 转换阶段（前置验证拦截不可行方案）。如果要优化 baton，应该强化前置验证的效率，同时降低实施阶段的摩擦。

**关键 insight 2**: baton 的 defense model 声称"self-check + context-isolated review + human annotation"三层防御，但 evolve 的实证表明：当 self-check 和 review 由同一模型执行时，前两层退化为一层。**真正有效的防御只有两层：同模型审查（抓结构/格式/一致性问题）+ 异源审查（cross-model 或 human，抓假设/盲区问题）**。10 轮同模型收敛 + 1 轮异模型发现 8 个问题——这个比例说明 cross-model review 不是"nice to have"，而是治理模型的结构性必要组件。

---

## 四、量化数据

| 指标 | 数值 |
|------|------|
| 会话技能调用次数 | 5 (/office-hours, /plan-eng-review, /baton-plan, /baton-implement, baton-review) |
| Todo items 完成 | 10 + 3 review-driven fixes = 13 |
| 代码变更 | 54 files, +566 -3,021 (net -2,455) |
| 设计方案变更 | 1 (plugin → flat install) |
| review 拦截的真实问题 | 2 (test-cli.sh 遗漏 + parser_has_skill 测试路径) |
| review LOW findings（未产生行动） | 3 |
| 预存测试失败（未修复） | 5 |
| 上下文压缩次数 | 1 (会话被截断并恢复) |
| 治理 token 开销估计 | ~17,500 tokens (~8.75% of 200K context) |

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
### [Annotation 1]
- **Trigger / 触发点**: baton-evolve 10 轮迭代 0 发现 vs Codex 1 轮 8 发现
- **Intent as understood / 理解后的意图**: evolve 的同模型自审机制存在结构性盲区，需要作为 baton 的核心缺陷记录
- **Response / 回应**: 已在正文第二章新增 §7（baton-evolve 同模型自审盲区），包含证据表、根因分析（同模型盲区 / review prompt 结构性局限 / 收敛≠正确）、改进方向。已更新综合评价的"需要改进"表（CRITICAL 级别）和"核心张力"节（新增 insight 2）。
- **Status**: ✅
- **Impact**: affects conclusions — 改变了对 baton defense model 有效性的整体评估，从"三层防御"修正为"实质两层（同模型 + 异源）"

### [Annotation 2]
- **Trigger / 触发点**: baton-evolve 感觉没有存在的必要了
- **Intent as understood / 理解后的意图**: 质疑 evolve 作为独立 skill 的存在价值
- **Response / 回应**: 同意。证据如下：

10 轮 evolve 的实际产出分类（git log 逐 commit 验证）：

| 类别 | 迭代 | 示例 |
|------|------|------|
| 内容补充（计划缺项） | iter-1, 5, 7 | 添加 evidence section、self-challenge、modified files list |
| 算术/计数错误 | iter-6, 8, 10 | event count 9→8、step reference、line counts |
| 内部一致性修复 | iter-2, 3, 4, 9 | skill discovery path、hooks.json quoting、write set |

三个结论支持废弃：

1. **单次 review 可替代**: 所有 10 轮发现都属于"文档内部一致性"——一次认真的 baton-review pass 就能全部抓到。迭代没有产生单次 review 抓不到的 finding。

2. **收敛信号是负价值**: 10 轮后收敛给人"plan 已经很完善"的错觉。实际上 Codex 1 轮就找到 8 个 evolve 完全忽略的问题。打磨后的 plan 比粗糙的 plan 更危险——polish 是 camouflage，让 human 更难质疑基本假设。

3. **ROI 为负**: 10 轮 × subagent 调度 × review prompt 解析 = 大量 token 和时间消耗。产出：修复了几个数字错误和补充了几段缺失内容。这些修复的价值远低于消耗的资源。

**建议**: 删除 baton-evolve skill。用 single-pass baton-review（已有）+ optional cross-model review（Codex /plan-eng-review 的 Step 0.5）替代。自主迭代的概念本身有价值，但需要异模型评估器才有意义——而那是 /plan-eng-review 的 Codex review 已经在做的事。

- **Status**: ✅
- **Impact**: affects conclusions — 新增"废弃 baton-evolve"作为具体建议

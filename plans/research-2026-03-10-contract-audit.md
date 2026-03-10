# Baton Core Contract Audit — 审计报告

> 基于 BatonContractAudit.md 与当前代码库（2026-03-10 snapshot）完成审计

---

## 审计目标

**名称**: Baton Core Contract Audit

**输出物**:
1. 核心契约清单 + 审计结果（本文档 §A–I）
2. 差异矩阵（§J）
3. 修复优先级排序（§K）

**最小稳定面（5 项）**: 阶段识别 · 写保护 · 批准门槛 · 注释闭环 · implement 前置条件

---

## 关键文件索引

| 角色 | 文件 |
|------|------|
| 核心协议 | `.baton/workflow.md` |
| 扩展协议 | `.baton/workflow-full.md` |
| 写锁实现 | `.baton/hooks/write-lock.sh` (v3.0) |
| 阶段检测 | `.baton/hooks/phase-guide.sh` (v5.0) |
| 公共库 | `.baton/hooks/_common.sh` |
| Hook 配置 | `.claude/settings.json` |
| Research 技能 | `.claude/skills/baton-research/SKILL.md` |
| Plan 技能 | `.claude/skills/baton-plan/SKILL.md` |
| Implement 技能 | `.claude/skills/baton-implement/SKILL.md` |
| 安装脚本 | `install.sh` (#!/bin/sh), `setup.sh` v3.0 (#!/bin/sh) |
| CLI | `bin/baton` (#!/usr/bin/env bash) |
| Cursor 适配器 | `.baton/adapters/adapter-cursor.sh` (#!/bin/sh) |
| README | `README.md` |
| 测试套件 | `tests/` (12 files, #!/bin/bash) |

---

## A. 阶段模型审计

**目标**: 确认 Baton 到底有哪些阶段，以及每阶段允许什么、禁止什么。

### 各源阶段清单对照

| 来源 | 阶段 | 数量 |
|------|------|------|
| [CODE] workflow.md:77 | RESEARCH, PLAN, ANNOTATION, IMPLEMENT | 4 |
| [CODE] workflow-full.md:106-108 | RESEARCH, PLAN, ANNOTATION, IMPLEMENT | 4 |
| [CODE] phase-guide.sh:7 | RESEARCH, PLAN, ANNOTATION, AWAITING_TODO, IMPLEMENT, ARCHIVE | 6 |
| [DOC] README.md:11-14 | research → plan → annotation → GO → todolist → implement (流程图) | 6 步骤 |
| [CODE] SKILL.md×3 | 无阶段枚举，隐式引用各自阶段 | — |

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| A1 | 阶段列表是否唯一 | ❌ **契约不明确** | workflow.md:77 声称"Four phases"，phase-guide.sh:7 实现 6 态。AWAITING_TODO 和 ARCHIVE 未被文档承认为正式阶段 |
| A2 | 各阶段进入条件是否唯一 | ✅ 一致 | phase-guide.sh 用 if-elif 链实现确定性派生：无文件→RESEARCH；有 research 无 plan→PLAN；有 plan 无 GO→ANNOTATION；GO 无 Todo→AWAITING_TODO；GO+Todo→IMPLEMENT；全完成→ARCHIVE |
| A3 | 各阶段退出条件是否唯一 | ✅ 一致 | 每个状态的退出由文件/标记变化驱动，无歧义 |
| A4 | 阶段优先级是否明确 | ❌ **实现缺失** | phase-guide.sh 用代码顺序定义优先级（ARCHIVE > AWAITING_TODO > IMPLEMENT > ANNOTATION > PLAN > RESEARCH），但文档未描述此优先级链 |
| A5 | 多条件同时满足时谁覆盖谁 | ❌ **实现缺失** | 由 phase-guide.sh if-elif 顺序隐式决定，文档未说明 |
| A6 | 阶段由文件状态派生还是标记驱动 | ✅ 一致 | 由文件存在性 + BATON:GO + todo 完成度三要素派生，phase-guide.sh 和 workflow.md Flow 节描述一致 |
| A7 | "无状态机"声明是否与实现冲突 | ❌ **矛盾** | [DOC] README.md:169 "No state machine — you know what phase you're in"；[CODE] phase-guide.sh:34-131 实现了完整的 6 态确定性状态机 |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| 到底有没有隐式状态机 | **有。** phase-guide.sh:34-131 是一个完整的确定性状态机，基于文件存在性+标记内容推导当前状态 |
| annotation 是独立阶段还是 plan 子循环 | **语义上是子循环**。[CODE] workflow-full.md:23-24 的流程图显示 annotation 是 plan→GO 之间的循环；但 [CODE] workflow.md:77 将其列为"Four phases"之一 — 定位矛盾 |
| AWAITING_TODO 是阶段还是过渡态 | **实现上是独立状态**（phase-guide.sh:52-63），**文档上不存在**。它是 GO→todolist 之间的门控态 |
| ARCHIVE 是历史状态还是活跃阶段 | **是善后动作，不是方法论阶段**。phase-guide.sh:36-49 检测全部 todo 完成后提示归档，无独立方法论指导 |

### 模块判定

> **P0 契约不明确** — "Four phases" 声明与 6 态实现不一致；"No state machine" 声明与 phase-guide.sh 实现矛盾

---

## B. 写保护契约审计

**目标**: 确认 Baton 最核心的治理能力到底如何工作。

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| B1 | 默认放行文件类型 | ✅ 一致 | [CODE] write-lock.sh:56-58 `case "$TARGET" in *.md\|*.MD\|*.markdown\|*.mdx) exit 0`；[DOC] workflow.md:36 "Markdown is always writable"；[DOC] README.md:40 同。❓ `.markdown` 在代码中有但 README 未提及（P2 级） |
| B2 | 默认阻断文件类型 | ✅ 一致 | 非 markdown + 在项目目录内 + 无 BATON:GO → 阻断 |
| B3 | 无 plan 时行为 | ✅ 一致 | [CODE] write-lock.sh:88-97 无 plan → exit 1（阻断），显示研究阶段提示。Fail-closed |
| B4 | 未批准 plan 时行为 | ✅ 一致 | [CODE] write-lock.sh:99-107 有 plan 无 GO → exit 1（阻断） |
| B5 | 异常时 fail-open/closed | ⚠️ **设计权衡** | [CODE] write-lock.sh:13-14 `trap 'exit 0' HUP INT TERM`；空 TARGET→exit 0 + 警告。正常路径 fail-closed，异常 fail-open（有可见警告）|
| B6 | markdown 放行是正式承诺 | ✅ 一致 | 三方（workflow.md:36 / write-lock.sh:55-58 / README.md:40）一致确认 |
| B7 | tests/config/docs 是否受保护 | ⚠️ **隐含限制** | 非 .md 文件一律受锁：.sh/.py/.js 测试文件、.yml/.json 配置文件都被阻断。**TDD 工作流受影响**：无法先写测试再写实现 |
| B8 | 删除/重命名文件覆盖 | ❌ **实现缺失** | [CODE] settings.json matcher: `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` — **无 Delete/Rename**。文件可在锁定状态下被删除 |
| B9 | 多文件修改逐个判断 | ✅ 一致 | PreToolUse hook 每次 invocation 处理一个文件的 `tool_input.file_path` |
| B10 | 各 IDE 写锁一致性 | ❌ **不一致** | Claude/Factory：8 hooks 直接执行 write-lock.sh；Cursor：4 hooks 通过 adapter-cursor.sh 桥接；**Codex：零 hook，无写锁** |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| "源码"精确定义 | **非 markdown + 在项目目录内的任何文件**。没有基于语言或目录的细粒度区分 |
| 是否允许先改测试 | **不允许**（除非测试是 .md）。测试文件与源码同等保护 |
| 是否允许改 CI/config | **不允许**。.yml/.json 被阻断 |
| write-lock 边界 | **Repo policy**。write-lock.sh 是项目级强制，不区分文件角色 |

### 模块判定

> B1-B6, B9: ✅ 核心写锁逻辑正确且一致
> B7: **P2** — TDD 工作流受限（可通过文档说明解决）
> B8: **P1** — 删除/重命名操作未受保护
> B10: **P0** — Codex 无写锁强制，用户可能误以为已受保护

---

## C. BATON:GO 审计

**目标**: 确认批准信号的语义绝对单一。

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| C1 | 是否只有一种合法写法 | ✅ 唯一 | [CODE] write-lock.sh:100 `grep -q '<!-- BATON:GO -->'` — 所有 hook 使用完全相同的字面量匹配，无正则变体 |
| C2 | 必须出现在哪个文件 | ✅ 明确 | [CODE] _common.sh:6-27 `resolve_plan_name()` → `$BATON_PLAN` > `ls -t plan.md plan-*.md \| head -1` > 默认 `plan.md`；`find_plan()` 向上遍历目录树 |
| C3 | 必须出现在什么位置 | ✅ 明确 | [CODE] write-lock.sh:100 `grep -q` 全文搜索。[DOC] README.md:41 "anywhere in the file"。无位置限制 |
| C4 | 多 plan 文件时如何选择 | ✅ 确定性 | [CODE] _common.sh:10 `ls -t plan.md plan-*.md \| head -1` — 按修改时间取最新；`BATON_PLAN=custom.md` 可覆盖 |
| C5 | 归档后 plan 是否有效 | ✅ 自动失效 | [CODE] _common.sh:15-27 `find_plan()` 只向上遍历，不进入 `plans/` 子目录。归档后 GO 自动失效，重新锁定 |
| C6 | GO 代表什么 | ✅ 一致 | GO 仅 gate **源码写入**（write-lock.sh:100）。todolist 生成是独立条件：需人类口头说 "generate todolist"（workflow.md:38）。GO 不自动触发 todolist |
| C7 | AI 能否自己写入 GO | ❌ **协议漏洞** | [DOC] workflow.md:37 "MUST NOT add BATON:GO yourself"；但 plan.md 是 .md 文件 → [CODE] write-lock.sh:56-58 markdown 永远放行。**技术上无法阻止 AI 写入 GO** |
| C8 | 全部文档/hook 语义一致 | ✅ 一致 | write-lock.sh:6 / workflow.md:36-37 / README.md:41-43 / baton-implement SKILL.md:14 / baton-plan SKILL.md:16 — 全部同意 GO 是人类放置的源码写入门控 |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| GO 是 approval token 还是 phase transition token | **Approval token**。它解锁写入权限，不驱动阶段转换。阶段转换由文件状态派生（phase-guide.sh） |
| "生成 todolist"在 GO 前还是后 | **GO 后**。[CODE] phase-guide.sh:52-63 AWAITING_TODO 状态：GO 存在但无 `## Todo`，提示人类说 "generate todolist" |
| plan 修改后旧 GO 是否失效 | **不失效**。write-lock.sh:100 只做 `grep -q`，无版本/hash 校验。修改 plan 内容不影响 GO 有效性 |

### 模块判定

> C1-C6, C8: ✅ GO 语义唯一明确
> C7: **P1** — AI 技术上可写入 GO（协议规则 vs 技术执行的缝隙）。严重程度低于 P0 因为 AI 被明确指令禁止，且 skill Iron Law 强化了约束
> plan 修改后 GO 不失效: **P2** — 极端场景下可能导致陈旧批准，但实际使用中 annotation 循环提供了补偿机制

---

## D. todolist / implement 前置条件审计

**目标**: 把"能实施"这件事定义清楚。

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| D1 | 何时允许生成 todolist | ✅ 一致 | workflow.md:38 "after human says 'generate todolist'"；baton-plan SKILL.md:18 Iron Law；baton-implement SKILL.md:44-46；README.md:12 流程图。全部一致：BATON:GO + 人类口头指令 |
| D2 | todolist 是否要求先有 GO | ✅ 一致 | baton-implement SKILL.md:29-33 "after BATON:GO is present"；phase-guide.sh:52-63 AWAITING_TODO 态前置 GO |
| D3 | implement 必须以 todolist 为入口 | ⚠️ **文档一致/技术不强制** | [DOC] workflow.md:38 "Todolist required"；[CODE] write-lock.sh:100 **只检查 GO，不检查 `## Todo`**。技术上有 GO 无 todolist 就能写代码 |
| D4 | 只能改 approved write set | ❌ **实现缺失** | [CODE] write-lock.sh 不检查 write set。[CODE] post-write-tracker.sh:6 "Always exit 0 — PostToolUse cannot block, this is advisory only"。写入范围约束仅靠 advisory 警告 |
| D5 | unexpected discovery 必须停下 | ❌ **实现缺失** | [CODE] baton-implement SKILL.md:192 声称 "enforced by hooks"，但**无 hook 实现此功能**。纯粹靠 skill 纪律 |
| D6 | implement 入口条件三方一致 | ✅ 一致 | workflow.md:38 / README.md:12 / baton-implement SKILL.md:29-33 / phase-guide.sh:52-63 — 全部要求 GO + Todo + 人类指令 |
| D7 | 无 todolist 能否写代码 | ❌ **技术漏洞** | [CODE] write-lock.sh:100 有 GO 即 exit 0，不检查 `## Todo`。phase-guide.sh AWAITING_TODO 只是 advisory 提示 |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| todolist 是必须的还是可选的 | **文档说必须**（workflow.md:38），**技术不强制**（write-lock 不检查 Todo）|
| write set 来源 | **文档：plan + todolist 结合**（baton-implement SKILL.md）。**技术：不检查**（post-write-tracker advisory only）|
| 小改动可否跳过 todolist | **文档未明确**。Trivial 复杂度（workflow.md:28）plan 只需 3-5 行 summary + GO，但 todolist 规则（workflow.md:38）无复杂度例外 — **矛盾** |

### 模块判定

> D1-D2, D6: ✅ 前置条件文档层面一致
> D3, D7: **P1** — todolist 存在性不被技术强制
> D4: **P1** — approved write set 不被技术强制（advisory only）
> D5: **P1** — "enforced by hooks" 声明与实际不符（baton-implement SKILL.md 误导）

---

## E. annotation 协议审计

**目标**: 确认 Baton 最有特色的人机闭环到底如何运作。

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| E1 | 输入格式是否明确 | ✅ 一致 | workflow.md:57-63 / workflow-full.md:279-310 / baton-plan SKILL.md:204-211 / README.md:26-28 — 全部一致：自由文本（默认）+ `[PAUSE]`（唯一显式标记）|
| E2 | 输出格式是否明确 | ⚠️ **隐式要求** | workflow.md:57 "records in `## Annotation Log`" 提及但未明确强制；workflow-full.md:324-345 和 baton-plan SKILL.md:242-261 有详细模板。**核心 workflow.md 对此要求不够显式** |
| E3 | 一轮批注结束条件 | ✅ 明确 | [CODE] workflow-full.md:283-292 完整流程：人类满意 → 添加 BATON:GO → 说 "generate todolist"。退出条件 = BATON:GO 放置 |
| E4 | 继续 vs 回 plan | ✅ 明确 | [CODE] baton-plan SKILL.md:228-238 Direction Change Rule：方向变化 → 全文档对齐 + 研究检查 + 通知人类。[PAUSE] → 暂停 + 补充研究 → 返回 |
| E5 | 能否直接触发实现 | ✅ 不能 | BATON:GO 是硬门控（write-lock.sh:100），只有人类能放置（workflow.md:37）。annotation 不能绕过 |
| E6 | 新事实是否强制更新 | ✅ 强制 | workflow.md:59 要求更新文档本体 + Annotation Log。baton-plan SKILL.md:221-226 自检规则：矛盾 → 立即处理 |
| E7 | 测试覆盖范围 | ⚠️ **文档测试** | test-annotation-protocol.sh 测试 8 类：标记存在性、legacy 清理、详细节覆盖、跨文件原则对齐、plan 分析完整性。**仅验证文档结构，不验证协议行为** |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| annotation 是 review loop 还是需求澄清 loop | **两者兼顾**。workflow-full.md 描述涵盖 review feedback + 方向变更 + 补充研究三种模式 |
| 何时算共享理解成立 | **无量化标准**。以人类满意度为准（放置 BATON:GO 即视为理解成立）|
| Annotation Log 规范地位 | **事实上是规范的一部分**，但 slim workflow.md 仅一笔带过。完整定义在 workflow-full.md 和 baton-plan SKILL.md |

### 模块判定

> E1, E3-E6: ✅ 核心协议一致且明确
> E2: **P2** — Annotation Log 要求在 slim workflow.md 中不够显式
> E7: **P2** — 测试只验证文档结构，不验证协议行为

---

## F. shell / runtime 契约审计

**目标**: 清掉最容易潜伏爆炸的工程风险。

### Shebang 总览

| 类别 | Shebang | 文件 | 是否有 bashism |
|------|---------|------|--------------|
| 安装器 | `#!/bin/sh` | install.sh, setup.sh | ✅ 无。`$((...))` 算术展开是 POSIX 兼容的 |
| 适配器 | `#!/bin/sh` | adapter-cursor.sh | ✅ 无。极简脚本 |
| Hooks | `#!/usr/bin/env bash` | _common.sh, write-lock.sh, phase-guide.sh, 等 8 文件 | ✅ 合理使用 bash |
| 测试 | `#!/bin/bash` | tests/*.sh | ✅ 合理（测试可以依赖 bash） |
| CLI | `#!/usr/bin/env bash` | bin/baton | ✅ 合理 |

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| F1 | shebang 反映真实依赖 | ✅ 一致 | POSIX 脚本（install.sh/setup.sh/adapter）无 bashism；bash 脚本合理使用 bash 特性。分层清晰 |
| F2 | 外部调用统一 | ✅ 一致 | [CODE] settings.json 全部用 `bash .baton/hooks/xxx.sh`；Cursor hooks.json 也用 `bash` 前缀 |
| F3 | bashism 在 sh 下执行 | ✅ 无此问题 | install.sh/setup.sh/adapter-cursor.sh 逐行检查无 `[[ ]]`/`(( ))`/arrays/process substitution/here-strings/select/function keyword |
| F4 | macOS/Linux 兼容 | ✅ 一致 | [CODE] write-lock.sh:63-64 `realpath -m` + `readlink -f` fallback + `cd && pwd` 三级降级；setup.sh 全用 `sed -i.bak`（macOS 兼容）|
| F5 | 测试与真实执行方式一致 | ✅ 一致 | 测试用 `bash` 执行脚本 vs 宿主通过 settings.json 用 `bash` 调用 — 一致 |
| F6 | 各 IDE 执行方式 | ✅ 一致 | Claude/Factory：`bash .baton/hooks/xxx.sh`；Cursor：`bash .baton/adapters/adapter-cursor.sh`（内部调用 write-lock.sh）|
| F7 | setup 生成的调用命令 | ✅ 一致 | [CODE] setup.sh 所有 IDE 的 hook 命令均使用 `bash` 前缀 |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| Bash-only 还是 POSIX | **分层设计**：安装器 POSIX（最大兼容），hooks/CLI bash（需要高级特性）。设计合理 |
| 所有调用方是否显式用 bash | **是**。settings.json 和 Cursor hooks.json 全部显式 `bash` 前缀 |
| POSIX 脚本是否清理了 bashism | **是**。install.sh/setup.sh/adapter-cursor.sh 无 bashism |

### 模块判定

> **全部通过 ✅** — Shell 兼容性设计合理，无阻断风险

---

## G. setup / install 契约审计

**目标**: 确认安装器承诺和实际行为一致。

### 各 IDE 安装产物对照

| 产物 | Claude | Factory | Cursor | Codex |
|------|--------|---------|--------|-------|
| .baton/ 目录 | ✅ | ✅ | ✅ | ✅ |
| workflow.md/full.md | ✅ | ✅ | ✅ | ✅ |
| hooks (8 个) | ✅ | ✅ | 4 个 + adapter | ❌ |
| skills (3 SKILL.md) | .claude/skills/ | .claude/skills/ | .cursor/skills/ | .agents/skills/ |
| 配置文件 | .claude/settings.json | .claude/settings.json | .cursor/hooks.json | AGENTS.md |
| 协议注入 | CLAUDE.md @import | CLAUDE.md @import | .cursor/rules/baton.mdc | AGENTS.md @import |

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| G1 | 默认安装哪些 hook | ❌ **文档过时** | [CODE] setup.sh:818-825 实际安装 **8 个** hook；[DOC] README.md:137 声称 "stop guard + 7 hooks" — 数字不匹配 |
| G2 | 不安装哪些 hook | ✅ 明确 | pre-commit 不再安装。[CODE] setup.sh:413-425 只有 legacy 移除代码 |
| G3 | pre-commit 支持面 | ✅ 已退出 | .baton/git-hooks/ 目录仅含 CLAUDE.md（memory），无可执行 hook。pre-commit 已正式废弃 |
| G4 | 各 IDE 安装产物一致性 | ✅ 合理差异 | Claude/Factory 完全一致（8 hooks）；Cursor 4 hooks + adapter（缺 PostToolUse/Stop/TaskCompleted）；Codex 零 hook — 差异已在 README 声明 |
| G5 | legacy 迁移 | ✅ 完整 | [CODE] setup.sh:1062-1077 v1→v2 迁移（.claude/write-lock.sh → .baton/hooks/）；workflow-full.md → workflow.md 引用更新 |
| G6 | 幂等性 | ✅ 通过 | [CODE] test-setup.sh:396-402 Test 11 测试重复安装；二次运行显示 "already in CLAUDE.md" + "up to date" |
| G7 | 不破坏用户配置 | ✅ 通过 | [CODE] test-setup.sh:532-542 Test 17d 验证非 baton hook 条目保留；setup.sh:248-285 基于 allowlist 移除 |
| G8 | CLI 参数与文档一致 | ✅ 一致 | setup.sh usage / bin/baton help / README.md — 三方文档一致（--ide, --choose, --uninstall） |

### 必问问题回答

| 问题 | 回答 |
|------|------|
| 单一入口还是分散安装 | **分层入口**：install.sh（全局首次）→ setup.sh（项目级）→ bin/baton init（CLI 快捷方式）。三者最终都调用 setup.sh |
| setup 是安装还是迁移工具 | **两者兼顾**。v3.0 检测已有安装并升级，同时支持全新安装 |
| 文档默认行为与脚本一致 | **基本一致**，但 hook 数量描述有偏差（8 vs "7 hooks"）|

### 模块判定

> G2-G8: ✅ 通过
> G1: **P2** — README hook 数量描述过时（8 vs "7 hooks"）

---

## H. 多宿主一致性审计

**目标**: 确认 Baton 真的是 protocol layer，而不是某个宿主特供技巧。

### 能力矩阵（实际实现 vs 文档）

| 能力 | Claude | Factory | Cursor | Codex | 文档声明 |
|------|--------|---------|--------|-------|---------|
| 写锁强制 | ✅ hook | ✅ hook | ✅ adapter | ❌ 无 | Claude/Factory/Cursor=Full, Codex=Rules |
| 阶段检测 | ✅ phase-guide | ✅ phase-guide | ✅ phase-guide | ❌ 无 | — |
| Bash 写入警告 | ✅ bash-guard | ✅ bash-guard | ✅ bash-guard | ❌ 无 | — |
| 写后漂移检测 | ✅ post-write-tracker | ✅ post-write-tracker | ❌ 无 | ❌ 无 | — |
| 停止提醒 | ✅ stop-guard | ✅ stop-guard | ❌ 无 | ❌ 无 | — |
| 子 agent 上下文 | ✅ subagent-context | ✅ subagent-context | ✅ subagent-context | ❌ 无 | — |
| 完成检查 | ✅ completion-check | ✅ completion-check | ❌ 无 | ❌ 无 | — |
| 紧凑前快照 | ✅ pre-compact | ✅ pre-compact | ✅ pre-compact | ❌ 无 | — |

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| H1 | Claude/Cursor 相同核心能力 | ⚠️ **不完全** | Cursor 缺少 3 个 hook（post-write-tracker, stop-guard, completion-check）。核心写锁有，辅助治理没有 |
| H2 | 宿主无关能力 | ✅ 明确 | workflow.md 协议规则完全宿主无关。BATON:GO 语义、markdown 放行、annotation 协议不依赖特定 IDE |
| H3 | 宿主依赖能力 | ❌ **Codex 零强制** | [CODE] setup.sh:1017-1033 Codex 无 hook 安装。全部依赖 AI 读取 AGENTS.md 规则。**无技术写锁** |
| H4 | adapter 仅做适配 | ✅ 纯翻译 | [CODE] adapter-cursor.sh:5-13 调用 write-lock.sh，只将 exit code 转换为 Cursor JSON（`{"decision":"allow/deny"}`），不修改逻辑 |
| H5 | 文档能力矩阵准确性 | ✅ 准确 | [DOC] README.md:135-140 与 [CODE] setup.sh:472-479 完全对齐（Claude=Full, Factory=Full, Cursor=Full adapter, Codex=Rules） |
| H6 | 测试覆盖宿主差异 | ✅ 覆盖 | test-multi-ide.sh 验证 IDE 检测、多 IDE 安装、hook 结构；test-ide-capability-consistency.sh 验证文档/代码/矩阵三方对齐 |

### 关键发现

**Codex 保护缺失**:
- Codex 没有 hook 机制，因此 write-lock.sh 无法执行
- 唯一保护：AI 读取 AGENTS.md 中的 workflow 规则 → 纯粹靠 AI 自律
- README.md 诚实标注为 "Rules guidance"，但用户可能不理解这意味着**零技术强制**

**Cursor 次等保护**:
- 缺少 PostToolUse（无写后漂移检测）
- 缺少 Stop hook（无停止时归档提醒）
- 缺少 TaskCompleted（无完成检查）
- 核心写锁存在，辅助治理不完整

### 模块判定

> H2, H4-H6: ✅ 通过
> H1: **P1** — Cursor 辅助治理不完整（但核心写锁有）
> H3: **P0** — Codex 零技术强制，用户可能误解保护范围

---

## I. 文档真相源审计

**目标**: 决定到底谁说了算。

### 文档权威层级（当前实际）

| 层级 | 文档 | 角色 | 加载方式 |
|------|------|------|---------|
| L1 | `.baton/workflow.md` (~400 tokens) | 活跃核心协议 | CLAUDE.md @import / .cursor/rules/ / AGENTS.md @import |
| L2 | `.baton/workflow-full.md` | 扩展参考 + fallback | phase-guide.sh 降级引用 |
| L3 | `SKILL.md` ×3 | 阶段执行指南 | 按需加载（技能调用时） |
| L4 | `README.md` | 公开介绍 | 人类阅读 |
| L5 | `setup.sh` / `bin/baton` | 安装实现 | 执行时 |

### 审计项

| # | 审计内容 | 判定 | 证据 |
|---|---------|------|------|
| I1 | README 角色 | ✅ 介绍文档 | README 无 "MUST"/"required" 等规范性语言，定位为入门介绍 + 安装指南 |
| I2 | workflow vs workflow-full | ✅ 明确 | workflow.md = 活跃核心（@import 加载）；workflow-full.md = 扩展参考。[CODE] test-workflow-consistency.sh:18-30 验证共享章节一致 |
| I3 | SKILL.md 角色 | ❌ **契约不明确** | SKILL.md 包含 "Iron Law" + 新增规则（Surface Scan, Counterexample Sweep, Consistency Matrix）**不存在于** slim workflow.md 中。这是规范扩展，不仅是"提示" |
| I4 | 测试依据 | ⚠️ **无唯一 ground truth** | [CODE] test-workflow-consistency.sh 用**一致性层级**而非单一参考：workflow.md ≈ workflow-full.md（共享节）→ SKILL.md 覆盖关键概念 → phase-guide.sh 引用关键词 |
| I5 | 归档 plans 影响 | ✅ 无影响 | plans/ 目录不被活跃代码引用。50+ 归档文件仅供人类回溯 |
| I6 | 多处定义行为 | ❌ **存在冲突** | (1) "Four phases"(workflow.md:77) vs 6 态(phase-guide.sh) (2) SKILL.md Iron Law 新增规则不在 workflow.md 中 (3) "No state machine"(README) vs 实现有状态机(phase-guide.sh) |

### SKILL.md 新增规则清单（不在 slim workflow.md 中）

| 规则 | 来源 | 类型 |
|------|------|------|
| Surface Scan（L1/L2/L3 disposition table） | baton-plan SKILL.md:88-115 | 治理规则 |
| Counterexample Sweep | baton-research SKILL.md:99-109 | 方法论规则 |
| Consistency Matrix | baton-research SKILL.md:83-97 | 方法论规则 |
| "enforced by hooks" 声明 | baton-implement SKILL.md:192 | 误导声明（实际未强制）|

### 必问问题回答

| 问题 | 回答 |
|------|------|
| Normative spec 在哪里 | **没有单一 normative spec**。workflow.md 是核心但不完整；SKILL.md 添加了实质性治理规则 |
| 哪些文档是 authoritative | L1 workflow.md + L3 SKILL.md 共同构成权威规范，但**未声明此关系** |
| 哪些文档是 explanatory | README.md（介绍）、plans/（归档）、docs/（设计参考）|

### 模块判定

> I1, I2, I5: ✅ 通过
> I3: **P0** — SKILL.md 实质性新增规则未被纳入核心协议，导致不同加载场景（有/无 skill）行为预期不同
> I4: **P1** — 无唯一 ground truth，依赖一致性测试链维护
> I6: **P0** — 多处行为定义存在矛盾（阶段数、状态机声明）

---

## J. 差异矩阵

| 审计项 | 文档声明 | 实现行为 | 测试覆盖 | 差异类型 | 优先级 |
|--------|---------|---------|---------|---------|--------|
| **A1 阶段列表** | 4 阶段 (workflow.md:77) | 6 态 (phase-guide.sh) | test-phase-guide.sh 覆盖 6 态 | **契约不明确** | **P0** |
| **A4 阶段优先级** | 未描述 | if-elif 链隐式定义 | 有测试但无文档 | **实现缺失**(文档层) | P1 |
| **A7 状态机声明** | "No state machine" (README) | phase-guide.sh 实现状态机 | — | **文档过时** | **P0** |
| **B7 测试文件受锁** | 未说明 | 非 .md 一律锁 | 有测试 | 一致(但有隐含限制) | P2 |
| **B8 删除/重命名** | 未提及 | 未覆盖 | 无测试 | **实现缺失** | P1 |
| **B10 Codex 无写锁** | README "Rules only" | 无 hook | test-multi-ide 覆盖 | **一致**(但有风险) | **P0** |
| **C7 AI 可写 GO** | "MUST NOT"(workflow.md:37) | 技术无阻止 | 无测试 | **实现缺失** | P1 |
| **D3/D7 todolist 不强制** | "required"(workflow.md:38) | write-lock 不检查 Todo | 无测试 | **实现缺失** | P1 |
| **D4 write set 不强制** | "only modify listed files" | post-write-tracker advisory | 有测试(advisory) | **实现缺失** | P1 |
| **D5 "enforced by hooks" 误导** | SKILL.md 声称 hook 强制 | 无 hook 实现 | 无测试 | **文档过时** | P1 |
| **E2 Annotation Log 要求** | slim workflow.md 一笔带过 | workflow-full.md 有详细模板 | 文档结构测试 | **契约不明确** | P2 |
| **G1 hook 数量** | "7 hooks"(README) | 8 hooks(setup.sh) | 有测试 | **文档过时** | P2 |
| **H1 Cursor 缺 3 hook** | "Full protection" | 缺 post-write/stop/completion | test-multi-ide 覆盖 | 一致(能力矩阵准确) | P1 |
| **I3 SKILL.md 新增规则** | SKILL.md 含 Iron Law + 新规则 | 按需加载，非常驻 | test-workflow-consistency | **契约不明确** | **P0** |
| **I6 多处矛盾** | 4 phases vs 6 states; no SM vs SM | — | 一致性测试存在 | **契约不明确** | **P0** |

---

## K. 修复优先级排序

### P0 — 会导致错误执行、越权写入、阶段误判

| # | 问题 | 影响 | 建议修复 |
|---|------|------|---------|
| 1 | **阶段模型不一致**（A1/A7） | 文档说 4 phases + no state machine，实现是 6 态状态机 | 选择一个真相：要么文档承认 6 态 + 状态机，要么简化 phase-guide.sh 到 4 阶段 |
| 2 | **Codex 零技术强制**（B10/H3） | 用户可能误以为 Codex 也有写锁保护 | README 显著警告 Codex 无技术强制；或开发 Codex 兼容的写锁方案 |
| 3 | **SKILL.md 实质性规则未纳入核心**（I3） | 有 skill 加载和无 skill 加载时，行为预期不同 | 在 workflow.md 中声明 SKILL.md 的规范地位；或将关键规则上提到 workflow.md |
| 4 | **多处行为定义矛盾**（I6） | 无法确定哪份文档说了算 | 建立明确的文档权威层级，消除矛盾声明 |

### P1 — 会导致用户理解错误、安装行为不一致

| # | 问题 | 影响 | 建议修复 |
|---|------|------|---------|
| 5 | **todolist 存在性不强制**（D3/D7） | 有 GO 无 todolist 可直接写代码 | 在 write-lock.sh 增加 `## Todo` 检查；或在文档承认这是 advisory |
| 6 | **approved write set 不强制**（D4） | 实现可漂移到计划外文件 | 将 post-write-tracker 从 advisory 升级为 blocking；或明确文档这是 advisory |
| 7 | **"enforced by hooks" 误导**（D5） | baton-implement SKILL.md 声称 hook 强制但实际没有 | 修正 SKILL.md:192 措辞为 "guided by skill discipline" |
| 8 | **AI 可写入 BATON:GO**（C7） | 技术上无法阻止 AI 在 plan.md 写入 GO | 可选：GO marker 使用非 markdown 格式；或接受当前协议约束 |
| 9 | **删除/重命名未受保护**（B8） | 文件可在锁定状态下被删除 | 扩展 settings.json matcher 覆盖 Delete/Rename（如 IDE 支持）|
| 10 | **阶段优先级未文档化**（A4/A5） | 开发者无法理解阶段冲突解决规则 | 在 workflow.md 或 workflow-full.md 记录优先级链 |
| 11 | **Cursor 缺少 3 个辅助 hook**（H1） | Cursor 用户无写后漂移检测、停止提醒、完成检查 | 评估 Cursor hooks.json 是否支持更多 hook 类型 |

### P2 — 命名、文案、非关键体验问题

| # | 问题 | 建议修复 |
|---|------|---------|
| 12 | README hook 数量过时（G1） | "7 hooks" → "8 hooks" |
| 13 | `.markdown` 扩展名未文档化（B1） | README 添加 `.markdown` 到允许列表描述 |
| 14 | Annotation Log 在 slim workflow.md 要求不显式（E2） | 加一句明确说明 |
| 15 | TDD 工作流受限（B7） | 文档说明 workaround（先 GO 再写测试+代码）|

---

## 审计结论

### 最小稳定面评估

| 能力 | 稳定性 | 关键问题 |
|------|--------|---------|
| **阶段识别** | ⚠️ 功能稳定但文档不一致 | 4 阶段声明 vs 6 态实现 |
| **写保护** | ✅ 核心逻辑正确 | Codex 无强制是已知设计限制 |
| **批准门槛** | ✅ BATON:GO 语义唯一明确 | AI 可写入 GO 是协议缝隙（非技术阻断）|
| **注释闭环** | ✅ 协议清晰一致 | Annotation Log 要求可更显式 |
| **implement 前置条件** | ⚠️ 文档一致但技术不完全强制 | todolist + write set 是 advisory |

### 总体评价

Baton 的核心治理机制（write-lock + BATON:GO）**在 Claude Code 和 Factory 上功能正确且可靠**。主要问题集中在：

1. **文档与实现的语义漂移**（阶段模型、状态机声明）— 需要一次性对齐
2. **技术强制与协议规则的缝隙**（todolist 不强制、write set advisory、AI 可写 GO）— 需决定是加强技术还是承认 advisory
3. **多宿主保护等级差异**（Codex 零强制、Cursor 部分缺失）— 需更清晰的用户期望管理
4. **文档权威层级未声明**（workflow.md vs SKILL.md vs README.md）— 需建立正式分层

**无阻断级别的安全漏洞**。所有 P0 都是契约清晰度问题，不是运行时故障。

---

## 批注区

# Plan: Baton v4 设计文档修正 + 剩余功能实施

> 基于：[v4 设计方案](docs/plans/2026-03-03-baton-v4-design.md) 的分析结果
> 日期：2026-03-04

## 背景

对 `docs/plans/2026-03-03-baton-v4-design.md` 和 `docs/research-ide-hooks.md` 的分析发现：

1. **设计文档存在多处自相矛盾**（数量标注、Cursor 分类、Cline 路径衔接）
2. **Phase 1 已基本实现**，设计文档未更新状态
3. **Phase 2（CLI 分发层）和 Phase 3（健康检查 + 新 IDE）尚未实施**
4. **代码层面有一个 bug**（pre-commit hook 文件名空格）

### 当前实现状态

| 设计项 | 状态 |
|--------|------|
| 多 IDE 检测 (`detect_ides`) | ✅ 已实现 |
| Cursor hook 配置 | ✅ 已实现 |
| Windsurf 原生 hook | ✅ 已实现 |
| adapter-cursor.sh | ✅ 已实现 |
| adapter-cline.sh | ✅ 已实现 |
| adapter-copilot.sh | ✅ 已实现 |
| opencode-plugin.mjs | ✅ 已实现 |
| git pre-commit hook | ✅ 已实现（有 bug） |
| workflow slim/full 策略 | ✅ 已实现 |
| adapter-windsurf.sh 废弃 | ✅ 已清理 |
| install.sh / bin/baton / projects.list | ❌ 未实施 |
| baton doctor / status | ❌ 未实施 |
| Augment / Kiro / Copilot 在 setup.sh 中配置 | ❌ 未实施 |
| Codex / Zed / Roo Code 规则注入 | ❌ 未实施 |

---

## 变更范围

本计划分两部分：**Part A** 修正文档 + 修 bug，**Part B** 规划剩余实施。

### Part A: 文档修正 + Bug 修复

#### A1. 修正 research-ide-hooks.md 数量标注

**文件**: `docs/research-ide-hooks.md`

Tier 1 标题写"7 个"但表格列了 8 行（Claude Code 和 Factory 分列）。

**修正方案**: 标题改为"8 个"，或加注"Claude Code 和 Factory 共用协议，合计 7 种独立协议"。

推荐改为 8，因为它们确实是两个独立产品，只是碰巧共享配置位置。

#### A2. 修正设计文档 §2.2 A 类数量

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

§2.2 写"A 类：exit code 2 协议（5 个工具）"但列举了 6 个。

**修正方案**:

实际情况是 Cursor 虽然支持 exit code 2，但还需要输出 JSON `{decision: "deny"}`，所以已经在 §2.3 中被归入了"薄适配器"组。应该：
- A 类标注改为"6 个"（Claude Code, Factory, Windsurf, Augment, Amazon Q/Kiro = 5 个产品，但 Factory 和 Claude Code 分列 = 6 条）
- 把 Cursor 从 A 类列表移到 B 类列表
- 或者：A 类保持 5 个（不含 Cursor），标注与列表一致

推荐：**从 A 类移除 Cursor**，因为实际实现中 Cursor 确实用了适配器。修正为：

```
A 类：exit code 2 协议（5 个）
- Claude Code, Factory, Windsurf, Augment, Amazon Q/Kiro

B 类：需要适配器（3 个）
- Cursor: {decision: "deny"/"allow"}
- Cline: {cancel: true/false}
- GitHub Copilot: {permissionDecision: "deny"/"allow"}
```

#### A3. 补充 Cline 配置路径衔接说明

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

设计中提到 Cline 配置位置是 `.clinerules/hooks/PreToolUse`，但适配器在 `.baton/adapters/adapter-cline.sh`。

**修正方案**: 查看当前 setup.sh 中 `configure_cline` 的实际实现来确定文档应如何描述。

当前实现（setup.sh `configure_cline`）：将 adapter-cline.sh 安装到 `.baton/adapters/`，将 workflow-full.md 复制到 `.clinerules/baton-workflow.md`。未创建 `.clinerules/hooks/PreToolUse`。

说明文档中 `.clinerules/hooks/PreToolUse` 路径来自 Cline 文档的理论配置，但实际 baton 采用了另一种方式。需要在设计文档中更新，反映实际实现。

#### A4. 修复 pre-commit hook 文件名空格 bug

**文件**: `.baton/git-hooks/pre-commit`

当前代码：
```sh
for f in $(git diff --cached --name-only --diff-filter=ACM); do
```

`$(...)` 扩展会在空格处 word-split。修改为：
```sh
git diff --cached --name-only -z --diff-filter=ACM | while IFS= read -r -d '' f; do
```

注意：这是 bash 语法，需要确认 shebang 是 `#!/bin/bash` 或 `#!/usr/bin/env bash`，而非 `#!/bin/sh`（POSIX sh 不支持 `read -d`）。

如果要保持 `#!/bin/sh` 兼容，可以用替代方案：
```sh
HAS_SOURCE=0
git diff --cached --name-only --diff-filter=ACM | while IFS= read -r f; do
    case "$f" in
        *.md|*.mdx|*.markdown) ;;
        *) echo "1" > "$TMPFILE"; break ;;
    esac
done
[ -s "$TMPFILE" ] && HAS_SOURCE=1
```

推荐：改用 `#!/bin/bash`（或 `#!/usr/bin/env bash`），使用 `-z` + `read -d ''` 方案。Baton 整体已依赖 bash。

#### A5. 补充 bash-guard.sh 和 stop-guard.sh 说明

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

设计文档 §1.5 目录结构列出了 `bash-guard.sh` 但全文无说明。`stop-guard.sh` 只在 Claude Code 配置中出现，未提及其他支持 Stop hook 的 IDE。

**修正方案**:
- 在 §2.4 中为 bash-guard.sh 补充一段说明（功能：PreToolUse(Bash) 时检测写入命令并警告）
- 在 Cursor / Augment / Kiro 的配置示例中添加 Stop hook（这些 IDE 都支持）
- 或者在设计文档中明确说明"stop-guard 仅配置在 Claude Code/Factory 中，其他 IDE 暂不配置"及原因

#### A6. 补充 uninstall 逻辑细节

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

当前实现（setup.sh `--uninstall`）已有完整逻辑，但设计文档未描述。

**修正方案**: 在 §1.2 CLI 命令 `baton uninstall` 处补充一句"详见 setup.sh --uninstall，清理 .baton/ 目录、各 IDE 规则文件、git pre-commit baton 段；settings.json / hooks.json 需用户手动编辑"。

#### A7. self-update 安全性

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

`git -C "$BATON_HOME" pull` 改为 `git -C "$BATON_HOME" pull --ff-only`，避免本地修改冲突。

#### A8. 更新设计文档状态

**文件**: `docs/plans/2026-03-03-baton-v4-design.md`

在 Todo 列表中标记已完成的项目（Phase 1 几乎全部完成），让文档反映当前实际进度。

### Part A14: 修复格式模板交付盲区

#### 问题分析

slim workflow.md（65 行, ~1000 tokens）只包含协议骨架，所有阶段的详细格式模板都只在 workflow-full.md（371 行, ~4000 tokens）中。问题**不只是 Annotation Log 格式**——是所有阶段的格式模板都缺失：

| 阶段 | slim workflow 有什么 | 缺失内容（只在 workflow-full.md 中） | 缺失量 |
|------|---------------------|--------------------------------------|--------|
| **RESEARCH** | "produce research.md"（1 行） | 执行策略、call chain 模板（`### [Path Name]` → `**Call chain**` → `**Risk** ✅/❌/❓`）、证据标准、Self-Review 模板、Questions for Human Judgment、批注区模板 | ~86 行 |
| **PLAN** | flow 中提及 plan.md | 内容要求（what/why/impact/risks）、方案分析格式（约束→2-3 方案→推荐）、Self-Review 模板、批注区模板、根本性问题处理 | ~69 行 |
| **ANNOTATION** | 标注类型列表（6 行） | 完整流程（7 步）、write-back discipline、标注格式示例、thinking posture、AI 回应原则（正确/错误示范）、**Annotation Log Round 格式**、RESEARCH-GAP 处理、动态复杂度调整 | ~105 行 |
| **IMPLEMENT** | 规则列表（8 行） | Per-item 执行序列（5 步，含"重读修改后代码"）、质量检查（含回环机制）、完成流程、Retrospective 格式 | ~35 行 |
| **总计** | | | **~295 行, ~3000 tokens** |

#### 问题加剧因素：计划回环 + phase-guide.sh 瞬时性

1. **计划回环**（`workflow.md:15`, `workflow-full.md:354-356`）：实现中移除 BATON:GO → 回退到批注回环。SessionStart 只触发一次，回环后 phase-guide.sh 不会重新输出阶段引导。

2. **context 压缩**：SessionStart 输出的阶段引导在压缩后丢失。slim workflow 在 system prompt 不被压缩，但它不含格式模板。

3. **结论**：当前架构假设 "slim workflow + phase-guide.sh = workflow-full.md 的等效覆盖"，但 phase-guide.sh 是瞬时的（只触发一次），导致实际覆盖 = slim workflow 水平（不含格式模板）。

#### Hook 覆盖能力调研（Context7 2026-03-05）

调查了所有主流 IDE 的 hook 事件，发现一个之前忽略的关键 hook：

| Hook 事件 | 触发时机 | IDE 支持 | 覆盖场景 |
|-----------|---------|---------|---------|
| **SessionStart** | 会话开始（一次） | Claude Code, Cursor, Cline | 初始引导 |
| **UserPromptSubmit** / **beforeSubmitPrompt** | **每次用户发消息** | Claude Code (`UserPromptSubmit`), Cursor (`beforeSubmitPrompt`), Cline (`UserPromptSubmit`) | **回环、压缩后、每轮批注** |
| **PreCompact** | context 压缩前 | Claude Code, Cursor, Cline | 压缩前保存 |
| **SubagentStart** | 子代理启动 | Claude Code, Cursor | 子代理上下文 |
| **规则文件** (workflow.md via CLAUDE.md) | 始终在 context | 所有 IDE | 所有场景 |

**关键发现**: `UserPromptSubmit` / `beforeSubmitPrompt` **每轮对话都触发**，自然覆盖回环场景——用户移除 BATON:GO 后发下一条消息时，hook 重新触发，可以检测到阶段变化并输出正确的引导。

**Cursor 完整 hook 列表更新**（从 Context7 确认 18 个事件，之前计划中只记录了 21 个但未列全名）：
sessionStart, sessionEnd, preToolUse, postToolUse, postToolUseFailure, subagentStart, subagentStop, beforeShellExecution, afterShellExecution, beforeMCPExecution, afterMCPExecution, beforeReadFile, afterFileEdit, beforeSubmitPrompt, preCompact, stop, afterAgentResponse, afterAgentThought

#### 方案对比（待人类选择）

##### 前提条件

**关键区分：各 IDE 的规则加载机制不同**

| IDE | 规则文件 | 内容 | 加载方式 | 压缩安全？ |
|-----|---------|------|---------|-----------|
| **Claude Code** | CLAUDE.md `@workflow.md` | slim | @import 自动解析 → project instructions | ✅ 不压缩 |
| **Factory** | 同 Claude Code | slim | 同上 | ✅ |
| **Cursor** | `.cursor/rules/baton.mdc` | **仅 3 行指令** | `alwaysApply:true`，但内容只是"Read .baton/workflow.md"——不嵌入实际内容 | ❌ AI 读到的内容在会话历史中，被压缩 |
| **Windsurf** | `.windsurf/rules/baton-workflow.md` | full 直接复制 | 规则文件 → 直接嵌入 | ❓ 取决于 Windsurf 规则引擎 |
| **Cline** | `.clinerules/baton-workflow.md` | full 直接复制 | 规则文件 → 直接嵌入 | ❓ 取决于 Cline 规则引擎 |

验证：当前会话是 compacted continuation，Claude Code 的 CLAUDE.md @import 内容仍完整存在。

**三种 context 载体**：

| 载体 | 生命周期 | 被压缩？ | 阶段感知？ | 适用 IDE |
|------|---------|---------|-----------|---------|
| **@import**（CLAUDE.md） | 整个会话 | ❌ | ❌ 全量 | Claude Code, Factory |
| **规则文件内嵌**（.mdc/.rules/*.md） | ❓ 取决于 IDE | ❓ | ❌ 全量 | Cursor, Windsurf, Cline 等 |
| **Hook 输出**（SessionStart/UPS） | 压缩前 | ✅ | ✅ | 支持对应 hook 的 IDE |

**关键发现**：
- **Claude Code/Factory 的 @import 是唯一确认压缩安全的载体**。其他 IDE 的规则文件是否被压缩未知。
- **Cursor 的 baton.mdc 存在严重问题**：只包含"Read .baton/workflow.md"指令（3 行），不嵌入实际内容。AI 手动读取后内容在会话历史中，会被压缩。
- **修复方向**：Cursor 的 .mdc 应该直接嵌入 workflow 内容（不是引用），使其成为 `alwaysApply:true` 的持久 context。

这意味着任何方案都需要**按 IDE 分别处理**，不能假设统一的压缩安全性。

##### Context 成本对比

| 方案 | system prompt 成本 | 每轮成本 | 10 轮会话总成本 | 覆盖阶段 | 覆盖回环 | 覆盖压缩 |
|------|-------------------|---------|---------------|---------|---------|---------|
| **A': 扩展 workflow.md（全阶段摘要）** | +640 tokens (65→~113 行) | 0 | 640 | 全部（摘要版） | ✅ | ✅ |
| **E: A' + UserPromptSubmit** | +640 tokens | +100~200/轮 | ~2640 | 全部（摘要+动态） | ✅ | ✅ |
| **G: 废弃 slim/full 拆分** | +3000 tokens (65→371 行) | 0 | 3000 | **全部（完整版）** | ✅ | ✅ |
| **H: G + 精简 phase-guide.sh** | +3000 tokens | 0 | 3000 | 全部 + 阶段提醒 | ✅ | ✅ |

（方案 B/C/D/F 因前轮分析已排除：B 回环不覆盖、C 多余冗余、D PreCompact 不必要、F 每轮 3500 tokens）

##### 方案详述

**方案 A'（原方案 A 扩展至全阶段）: 在 workflow.md 中补全阶段格式摘要**

在 slim workflow.md 中为每个阶段补充最小格式模板：

| 阶段 | 补充内容 | 预计行数 | 预计 tokens |
|------|---------|---------|-----------|
| RESEARCH | call chain 模板 + Self-Review 模板 + 批注区模板 | ~15 行 | ~200 |
| PLAN | 方案分析格式 + Self-Review 模板 + 批注区模板 | ~15 行 | ~200 |
| ANNOTATION | Round 格式 + write-back discipline | ~8 行 | ~110 |
| IMPLEMENT | 执行序列 + Retrospective 格式 | ~10 行 | ~130 |
| **合计** | | **~48 行** | **~640 tokens** |

- workflow.md: 65 → ~113 行，~1000 → ~1640 tokens
- ✅ 覆盖所有阶段，始终在 system prompt
- ✅ 零每轮成本
- ⚠️ 摘要版 ≠ 完整版。简化后可能丢失细节（如 AI 回应原则的正确/错误示范、RESEARCH-GAP 处理流程）
- ⚠️ 维护两处内容：workflow.md（摘要）+ workflow-full.md（完整），需保持同步

**方案 E（扩展至全阶段）: A' + UserPromptSubmit 动态补位**

- workflow.md 补全阶段格式摘要（同 A'）
- UserPromptSubmit hook 按当前阶段输出该阶段的详细格式提示
- ✅ 摘要 + 动态详细 = 最全覆盖
- ❌ 每轮 +100~200 tokens，10 轮 ~1000~2000 额外开销
- ⚠️ 工程量大：新建 hook 脚本 + 3 个 IDE 的 setup 配置

**方案 G: 废弃 slim/full 拆分，统一使用 workflow-full.md**

- CLAUDE.md 中 `@.baton/workflow.md` → `@.baton/workflow-full.md`
- 所有 IDE 统一加载完整版（有 SessionStart 的 IDE 通过 CLAUDE.md/@import，无 SessionStart 的通过规则文件）
- 删除 workflow.md（或保留为 workflow-full.md 的 symlink）
- workflow-full.md: 371 行, ~4000 tokens

成本分析：
- system prompt 增加 ~3000 tokens（1000 → 4000）
- 200k context: 4000/200000 = **2%**
- 128k context: 4000/128000 = **3.1%**

优劣：
- ✅ **根本解决**：所有阶段的所有格式模板始终可用，不存在盲区
- ✅ **单一来源**：消除 slim/full 同步维护问题，格式定义只有一处
- ✅ **零工程量差异**：不需要新 hook，不需要改 setup.sh（只改 CLAUDE.md 的 @import 路径）
- ✅ phase-guide.sh 保持不变（仍有价值：动态阶段检测 + mindset 提醒）
- ⚠️ system prompt +3000 tokens（2-3%），对 context 利用率有轻微影响
- ⚠️ 需要评估：slim/full 拆分是否还有除 token 节省以外的设计意图

**方案 H: G + 精简 phase-guide.sh**

- 同方案 G（统一 workflow-full.md）
- 精简 phase-guide.sh：既然完整规则已在 system prompt，phase-guide.sh 只需输出轻量的阶段提醒（当前阶段 + mindset），不再重复格式模板
- phase-guide.sh 从 ~188 行缩减到 ~60 行
- ✅ 进一步减少 SessionStart 输出的 token 量
- ⚠️ 改动范围增大（workflow-full.md + CLAUDE.md + phase-guide.sh + 测试）

**方案 I（新增）: slim workflow（@import）+ 增强 phase-guide.sh（SessionStart）+ UserPromptSubmit 阶段变化补位**

核心思路：利用两种载体的互补特性——@import 提供不被压缩的协议骨架，hook 按阶段交付格式模板。

- **workflow.md（@import）**: 保持 slim 版，协议骨架 ~1000 tokens，始终可用，不被压缩
- **phase-guide.sh（SessionStart）**: 增强——除现有阶段引导外，**追加当前阶段的格式模板**（~200-300 tokens）
- **新建 prompt-context.sh（UserPromptSubmit）**: 检测阶段是否变化，**仅在阶段变化时**重新输出新阶段的格式模板

Token 预算：

| 时间点 | 内容 | Token 成本 |
|--------|------|-----------|
| 每个会话（始终） | slim workflow.md via @import | ~1000 |
| 会话开始（一次） | phase-guide.sh 阶段引导 + 当前阶段格式模板 | ~500-600 |
| 普通轮次 | UserPromptSubmit 检测阶段未变 → 无输出 | **0** |
| 阶段变化轮次 | UserPromptSubmit 检测到变化 → 输出新阶段模板 | ~200-300 |
| 压缩后首轮 | UserPromptSubmit 检测到"尚未输出" → 重新输出 | ~200-300 |

典型 10 轮批注会话总成本：~1000 + 500 + 0×8 + 0 = **~1500 tokens**

与方案 G 对比：

| | 方案 G（全量 @import） | 方案 I（slim + 阶段感知 hook） |
|---|---|---|
| system prompt | ~4000 tokens (全阶段) | ~1000 tokens (骨架) |
| 10 轮会话总成本 | ~4000 | ~1500 |
| 阶段无关内容 | ~1200-2600 tokens 浪费 | ~0 |
| 覆盖回环 | ✅ | ✅ (UserPromptSubmit 检测变化) |
| 覆盖压缩 | ✅ (不被压缩) | ✅ (UserPromptSubmit 自愈) |
| 维护文件 | 1 个 (workflow-full.md) | 3 个 (workflow.md + phase-guide.sh + prompt-context.sh) |
| 工程量 | 最小（改 @import 路径） | 中等（新 hook + 3 IDE setup） |

方案 I 的 prompt-context.sh 阶段变化检测逻辑：
```sh
#!/bin/sh
# prompt-context.sh — 阶段变化时交付格式模板
# Hook: UserPromptSubmit
# 每轮触发，但仅在阶段变化时输出

CACHE="$PROJECT_DIR/.baton/.phase-cache"
CURRENT=$(detect_current_phase)  # 复用 phase-guide.sh 的阶段检测逻辑
LAST=$(cat "$CACHE" 2>/dev/null)

[ "$CURRENT" = "$LAST" ] && exit 0  # 阶段未变，不输出

echo "$CURRENT" > "$CACHE"
output_phase_templates "$CURRENT"   # 输出新阶段的格式模板到 stderr
exit 0
```

优劣：
- ✅ **最省 token**：只加载当前阶段的格式模板，无阶段无关浪费
- ✅ **压缩自愈**：UserPromptSubmit 在下一轮重新输出（cache 文件持久化，但 hook 检测到会话内首次输出）
- ✅ **回环覆盖**：阶段变化被检测到 → 自动输出新阶段模板
- ⚠️ **工程量中等**：新建 prompt-context.sh + setup.sh 配 3 个 IDE 的 UserPromptSubmit
- ⚠️ **压缩自愈有一轮延迟**：压缩发生后，下一轮 UserPromptSubmit 才输出（但 slim workflow 骨架始终在，不会完全失明）
- ⚠️ **维护 3 个文件**而非 1 个

#### 跨 IDE 方案对比（Round 11 更新）

考虑到各 IDE 规则加载机制不同，方案需要按 IDE 分别评估：

**方案 G 的跨 IDE 影响**（废弃 slim/full 拆分）：

| IDE | 方案 G 动作 | 效果 | 压缩安全？ |
|-----|-----------|------|-----------|
| Claude Code | `@workflow.md` → `@workflow-full.md` | ✅ 完整内容在 project instructions | ✅ 确认 |
| Factory | 同 Claude Code | ✅ | ✅ |
| Cursor | .mdc 内嵌 workflow-full.md 内容（替代当前"Read"指令） | ✅ `alwaysApply:true` 确保加载 | ❓ 需验证 Cursor 规则是否被压缩 |
| Windsurf | 已经复制 workflow-full.md → 无变化 | ✅ | ❓ |
| Cline | 已经复制 workflow-full.md → 无变化 | ✅ | ❓ |

**重要**：Cursor 当前的 baton.mdc 只有 3 行指令，需要改为直接嵌入 workflow 内容。这不论选哪个方案都需要修复（当前的引用方式意味着 Cursor 在压缩后完全失去工作流规则）。

**方案 I 的跨 IDE 影响**（slim + UserPromptSubmit）：

| IDE | UserPromptSubmit 支持？ | 效果 |
|-----|----------------------|------|
| Claude Code | ✅ `UserPromptSubmit` | 阶段感知模板交付 |
| Cursor | ✅ `beforeSubmitPrompt` | 阶段感知模板交付 |
| Cline | ✅ `UserPromptSubmit` | 阶段感知模板交付 |
| Windsurf | ❌ 不支持 | 无法覆盖，需靠规则文件内嵌 |
| 其他无 hook IDE | ❌ | 同上 |

**方案 J（新增）：按 IDE 分层策略**

不强求统一方案，按 IDE 特性选择最优载体：

| IDE | 策略 | 规则内容 | 补位 hook |
|-----|------|---------|----------|
| Claude Code | @import workflow-full.md（方案 G） | full，project instructions | SessionStart (phase-guide.sh) |
| Factory | 同 Claude Code | full | 同上 |
| Cursor | **.mdc 直接内嵌** workflow-full.md | full，alwaysApply 规则 | SessionStart + beforeSubmitPrompt（可选） |
| Windsurf | 已经直接复制 full → 无变化 | full，规则文件 | 无 SessionStart |
| Cline | 已经直接复制 full → 无变化 | full，规则文件 | UserPromptSubmit（可选补位） |

核心思路：
- 所有 IDE 统一加载 **workflow-full.md 的完整内容**
- 对支持可靠规则持久化的 IDE（Claude Code @import），直接走 @import
- 对规则持久性不确定的 IDE（Cursor .mdc），确保内容**内嵌**而非引用
- UserPromptSubmit 作为**可选增强**（不是必须），为支持的 IDE 提供阶段感知补位

实施项：
- A14a: CLAUDE.md `@workflow.md` → `@workflow-full.md`
- A14b: setup.sh `configure_cursor()` — baton.mdc 从 3 行引用改为内嵌 workflow-full.md 内容
- A14c: setup.sh `configure_claude()`/`configure_factory()` — @import 路径更新
- A14d: 验证 Windsurf/Cline 规则文件已经是 full → 无需变更
- A14e: （可选）新建 prompt-context.sh 作为 UserPromptSubmit 补位
- A14f: 运行一致性测试

优劣：
- ✅ **所有 IDE 都有完整规则**：不再有 slim/full 差异
- ✅ **Cursor .mdc 问题修复**：从引用改为内嵌，消除压缩后规则丢失
- ✅ **增量实施**：A14a-d 是必须的，A14e 是可选增强
- ⚠️ Cursor .mdc 文件会从 3 行增至 ~371 行
- ⚠️ 各 IDE 规则文件是否在压缩后保持需实际测试验证

#### 推荐：方案 J

理由：
1. **按 IDE 特性匹配**：不是一刀切，而是为每个 IDE 选择最适合的规则加载方式
2. **统一内容**：所有 IDE 都加载 workflow-full.md，消除 slim/full 分裂
3. **修复 Cursor .mdc 问题**：当前的引用方式是一个 bug（不只是优化问题），不论选哪个方案都需要修复
4. **向前兼容**：新增 IDE 时统一使用 workflow-full.md，不需要判断 slim/full
5. **UserPromptSubmit 可选**：作为增强而非必须，降低初始工程量

**等待人类选择方案后再更新 Todo。**

### Part A9: 更新 research-ide-hooks.md — 全面刷新 hook 数据

**文件**: `docs/research-ide-hooks.md`

调研结果表明研究文档已严重过时。需要全面更新：

#### Claude Code: 10 → 17 个 hook（+7 新增）

| 新增 Hook | 可阻断 | 与 baton 相关性 |
|-----------|--------|----------------|
| `UserPromptSubmit` | ✅ exit 2 阻断 | 低 — baton 不需要拦截用户输入 |
| `PermissionRequest` | ✅ JSON deny | 低 — baton 不管理权限决策 |
| `TeammateIdle` | ✅ exit 2 强制继续 | 中 — 多 agent 场景可能需要保持工作直到 todo 完成 |
| `TaskCompleted` | ✅ exit 2 阻断 | **高 — 已在用**（completion-check.sh） |
| `ConfigChange` | ✅ exit 2 / JSON block | **中 — 可检测 baton hook 配置被篡改** |
| `WorktreeCreate` | ✅ 非零 exit 失败 | 低 — baton 不管理 worktree |
| `WorktreeRemove` | ❌ 仅日志 | 低 |

**对设计文档的影响**: 需要更新 §2.4 Claude Code 配置中的 hook 列表。当前 setup.sh 已使用 `TaskCompleted`，但设计文档未提及。`ConfigChange` 值得考虑作为防篡改机制。

#### Cursor: 18 个 hook（Context7 2026-03-05 确认）

完整列表：sessionStart, sessionEnd, preToolUse, postToolUse, postToolUseFailure, subagentStart, subagentStop, beforeShellExecution, afterShellExecution, beforeMCPExecution, afterMCPExecution, beforeReadFile, afterFileEdit, **beforeSubmitPrompt**, preCompact, stop, afterAgentResponse, afterAgentThought

| 重要新增 | 可阻断 | 与 baton 相关性 |
|----------|--------|----------------|
| **`beforeSubmitPrompt`** | ✅ | **高 — 等价于 Claude Code 的 UserPromptSubmit，每轮触发，可持续注入阶段引导** |
| `subagentStart` / `subagentStop` | ✅ / ❌ | 中 — 可为 subagent 注入 plan 上下文 |
| `beforeMCPExecution` | ✅ **fail-closed** | 低 — baton 不管 MCP |
| `beforeShellExecution` | ✅ | 中 — 可用于 bash-guard 等价功能 |
| `preCompact` | ❌ | 中 — 可用于 pre-compact.sh 等价功能 |
| `afterFileEdit` | ❌ | 中 — 可用于 post-write-tracker 等价功能 |
| `stop` | ❌ 只能 followup | 中 — 与 Claude Code 的 Stop 不同，不能阻断，只能追加消息 |
| `afterAgentResponse` | ❌ | 低 — 日志/审计用 |
| `afterAgentThought` | ❌ | 低 — 日志/审计用 |

**对设计文档的影响**:
- Cursor 的 `stop` hook 不能阻断（只能追加 followup），与 Claude Code 的 `Stop`（可阻断）不同。设计文档应注明差异。
- Cursor 现在支持 `subagentStart`，可以配置 subagent-context.sh。
- Cursor 的 `preCompact` 和 `afterFileEdit` 可以分别对接 pre-compact.sh 和 post-write-tracker.sh。
- **sessionStart 存在 bug**: 社区报告 `continue: false` 被忽略，且部分版本报 "unknown hook type"。需在设计文档中注明。

#### Windsurf: 12 个 hook（数量不变，2 个新增）

- 新增 `post_cascade_response_with_transcript`（2026-02-24）— 合规审计用，与 baton 无关
- 新增 `post_setup_worktree`（2025-12）— 与 baton 无关
- **核心 hook 不变**，`pre_write_code` 仍可直接用 write-lock.sh

#### Cline: 6 → 8 个 hook

- 新增 `TaskComplete` 和 `PreCompact`（v3.38.3）
- `TaskComplete` 可用于 completion-check.sh 的 Cline 版本
- **对设计文档影响**: 可为 Cline 添加 TaskComplete hook 配置

#### Augment: 5 个（不变）

- 无新增 hook
- 设计文档描述仍然准确

#### Kiro: 5 个（不变）

- 无新增 hook
- 设计文档描述仍然准确

#### Copilot: 8 个（系统全新，2026-01 发布）

- 整个 hook 系统是 2026-01 才发布的（VS Code 1.109 Preview）
- 独特的三值决策：`deny` / `ask` / `allow`（`ask` 弹窗确认，其他工具没有）
- 支持 `SubagentStart` / `SubagentStop`
- **对设计文档影响**: 需补充 Copilot hook 的最新协议细节

#### Roo Code: 仍无 hook（但在开发中）

- PR #11579 "Feat/zoe hooks" 已合并（2026-02-18），建立 hook 基础架构
- PR #11663 "Hooks phase 1" 进行中
- 预计数周内可能发布 `PreToolUse` / `PostToolUse`
- **对设计文档影响**: 可从 Tier 2 关注列表中标注"开发中"

### Part A10: 更新设计文档 hook 覆盖策略

基于刷新后的数据，更新 §2.3 适配器架构图和 §2.4 各 IDE 配置，补充：

1. Claude Code 配置中添加 `TaskCompleted` → `completion-check.sh`（已实现但设计文档未记录）
2. Cursor 配置中添加 `subagentStart`、`preCompact`、`afterFileEdit` 的可选 hook
3. Cline 配置中添加 `TaskComplete` 的可选 hook
4. 注明 Cursor `stop` 与 Claude Code `Stop` 的行为差异
5. 注明 Cursor `sessionStart` 的已知 bug
6. 考虑 `ConfigChange` 防篡改 hook（可选，P5 优先级）

### Part A11: 修复 Cline hook 连线缺失

**文件**: `setup.sh` `configure_cline()`

**问题**: `configure_cline` 安装了 `adapter-cline.sh` 到 `.baton/adapters/`，但 Cline 的 hook 发现机制是基于文件命名约定——需要 `.clinerules/hooks/PreToolUse`（无扩展名可执行文件）才会被调用。当前 setup.sh 从未创建这个文件，导致 adapter 虽然存在但永远不会触发。

**修正方案**:
```sh
# 在 configure_cline() 中添加
mkdir -p "$PROJECT_DIR/.clinerules/hooks"
cat > "$PROJECT_DIR/.clinerules/hooks/PreToolUse" << 'HOOK'
#!/bin/sh
exec sh "$(dirname "$0")/../../.baton/adapters/adapter-cline.sh"
HOOK
chmod +x "$PROJECT_DIR/.clinerules/hooks/PreToolUse"
```

同时可添加 `TaskComplete` hook：
```sh
cat > "$PROJECT_DIR/.clinerules/hooks/TaskComplete" << 'HOOK'
#!/bin/sh
# Cline TaskComplete → completion-check adapter
exec sh "$(dirname "$0")/../../.baton/hooks/completion-check.sh"
HOOK
chmod +x "$PROJECT_DIR/.clinerules/hooks/TaskComplete"
```

### Part A12: 扩展 Cursor hook 配置

**文件**: `setup.sh` `configure_cursor()`

**问题**: Cursor 现在支持 21 个 hook 事件，但 setup.sh 只配了 2 个（sessionStart, preToolUse）。以下 hook 已在 Claude Code 中验证有效，且 Cursor 现在支持：

| Cursor hook | 对接脚本 | 是否需要适配器 |
|-------------|---------|--------------|
| `postToolUse` | post-write-tracker.sh | 需要（Cursor JSON 协议） |
| `subagentStart` | subagent-context.sh | 需要验证 stdin 格式是否兼容 |
| `preCompact` | pre-compact.sh | 需要验证 |
| `beforeShellExecution` | bash-guard.sh | 需要验证 stdin 格式 |
| `stop` | stop-guard.sh | **不能阻断**（只能追加 followup），与 Claude Code Stop 行为不同 |

**修正方案**: 在 `.cursor/hooks.json` 中扩展 hook 配置。注意：
- 每个 hook 脚本需要验证对 Cursor stdin JSON 格式的兼容性
- stop hook 在 Cursor 中不能阻断，只能返回 followup_message，需要决定是否值得配置
- 优先添加 subagentStart 和 preCompact（风险最低，stdin 格式对这两个无关紧要）

### Part A13: 扩展 Windsurf hook 配置

**文件**: `setup.sh` `configure_windsurf()`

**问题**: Windsurf 只配了 `pre_write_code`（1 个 hook），但还支持 `pre_run_command`（可对接 bash-guard）和 `post_write_code`（可对接 post-write-tracker）。

**修正方案**: 在 `.windsurf/hooks.json` 中添加：
```json
{
  "hooks": {
    "pre_write_code": [{"command": "sh .baton/hooks/write-lock.sh", "show_output": true}],
    "pre_run_command": [{"command": "sh .baton/hooks/bash-guard.sh", "show_output": true}],
    "post_write_code": [{"command": "sh .baton/hooks/post-write-tracker.sh", "show_output": true}]
  }
}
```

需验证 bash-guard.sh 和 post-write-tracker.sh 对 Windsurf stdin JSON 格式的兼容性（Windsurf 传 `{file_path, edits[]}` 而非 Claude Code 的 `{tool_input: {file_path}}`）。

### Part B: Phase 2 — CLI 分发层

#### B1. 新增 `install.sh` — 全局安装脚本

**新文件**: `install.sh`（~50 行）

功能：
1. 检测 `~/.baton/` 是否存在且为完整 git 仓库，不存在则 clone
2. 创建 `~/.baton/bin/baton` 可执行脚本（从仓库中复制）
3. 将 `~/.baton/bin` 加入 PATH（追加到 `~/.bashrc` / `~/.zshrc`，检测已有则跳过）

**平台注意**: 当前开发环境是 Windows（Git Bash），需要：
- 检测 shell profile 文件时同时考虑 `~/.bashrc`、`~/.zshrc`、`~/.bash_profile`
- Windows 上 `~/.baton` 路径实际是 `$HOME/.baton`（Git Bash 下 `$HOME` = `/c/Users/hexin`）
- 不依赖 symlink（Windows NTFS symlink 需要管理员权限），直接复制 bin/baton

#### B2. 新增 `bin/baton` — CLI 入口脚本

**新文件**: `bin/baton`（~100 行）

实现子命令路由 + 注册表管理函数：

```sh
#!/bin/sh
set -eu
BATON_HOME="${BATON_HOME:-$HOME/.baton}"
SETUP="$BATON_HOME/setup.sh"
REGISTRY="$BATON_HOME/projects.list"

# 注册表管理函数
registry_add() { ... }     # 绝对路径去重追加
registry_remove() { ... }  # 按路径移除
registry_list() { ... }    # 遍历显示版本 + IDE

# 子命令
case "${1:-help}" in
    init)        bash "$SETUP" "${2:-.}" && registry_add "${2:-.}" ;;
    update)      # --all → 遍历 registry; 否则 bash "$SETUP" "${2:-.}"
    uninstall)   bash "$SETUP" --uninstall "${2:-.}" && registry_remove "${2:-.}" ;;
    self-update) git -C "$BATON_HOME" pull --ff-only ;;
    list)        registry_list ;;
    doctor)      doctor "${2:-.}" ;;
    status)      status "${2:-.}" ;;
    help|*)      usage ;;
esac
```

注意事项：
- `self-update` 用 `--ff-only`（A7 修正）
- `baton init` 需要将相对路径转为绝对路径再写入 registry
- 自安装场景：当 `$(cd "$dir" && pwd)` == `$BATON_HOME` 时，setup.sh 内的 `cp` 操作会 source == target，需要检测并跳过

#### B3. 注册表管理

**文件**: `projects.list`（运行时创建于 `~/.baton/`）

- `registry_add`：`realpath "$dir"` → 检查去重 → 追加
- `registry_remove`：`grep -v "^$path$"` → 覆盖写回
- `registry_list`：逐行读取 → 检查路径存在 → 显示 baton 版本（从 write-lock.sh 提取 `# Version:`）+ 检测到的 IDE
- `baton update --all`：遍历 registry → 每个目录执行 `bash "$SETUP" "$dir"` → 跳过不存在路径并提示

### Part C: Phase 3 — 健康检查 + 新 IDE 支持

#### C1. `baton doctor` — 健康检查

**位置**: `bin/baton` 中的 `doctor()` 函数（或独立脚本 `lib/doctor.sh`，由 bin/baton source）

检查项（6 类）：

1. **脚本完整性**: `.baton/hooks/` 下每个脚本是否存在 + 版本是否与 `~/.baton/` 中一致
2. **IDE 配置**: 对每个 `detect_ides` 返回的 IDE，检查其 hook 配置文件是否存在且包含 baton 配置
3. **新增 IDE**: 扫描是否有新的 IDE 目录（`.cursor/`, `.windsurf/` 等）但未配置 baton
4. **规则注入**: CLAUDE.md 含 `@.baton/workflow.md`、.cursor/rules/baton.mdc 存在等
5. **git hook**: `.git/hooks/pre-commit` 是否包含 baton 段
6. **版本一致**: 项目脚本版本 vs `~/.baton/` 源脚本版本

输出格式：`✓` 通过 / `⚠` 警告 / `✗` 缺失。最终汇总 "N warnings found. Run `baton init` to auto-fix."

#### C2. `baton status` — 工作流状态

**位置**: `bin/baton` 中的 `status()` 函数

复用 phase-guide.sh 的状态检测逻辑（plan 发现 + BATON:GO 检查 + todo 计数），但输出面向人类：

```
📍 Phase: ANNOTATION
   Plan:     plan-v4-design-review.md (exists, no BATON:GO)
   Research: research-ide-hooks.md (exists)
   Todos:    0/0 (no todolist yet)
```

#### C3. 新 IDE 配置 — Augment Code

**文件**: `setup.sh` 新增 `configure_augment()`

- 检测 `.augment/` 目录存在
- 生成 `.augment/settings.json`：PreToolUse → write-lock.sh（A 类，exit code 2，无需适配器）
- SessionStart → phase-guide.sh
- 规则注入：复制 workflow.md 到 `.augment/rules/baton-workflow.md`

#### C4. 新 IDE 配置 — Amazon Q / Kiro

**文件**: `setup.sh` 新增 `configure_kiro()`

- 检测 `.amazonq/` 目录存在
- 生成 hook 配置：PreToolUse → write-lock.sh（A 类，exit code 2）
- 规则注入：复制 workflow.md 到 `.amazonq/rules/baton-workflow.md`

#### C5. 新 IDE 配置 — GitHub Copilot

**文件**: `setup.sh` 新增 `configure_copilot()`

- 检测 `.github/` 目录存在
- 生成 `.github/hooks/baton.json`：preToolUse → adapter-copilot.sh（B 类，需要 `{permissionDecision}` JSON）
- SessionStart → phase-guide.sh
- 规则注入：在 `.github/copilot-instructions.md` 中追加 workflow 引用
- adapter-copilot.sh 已存在，只需安装

#### C6. 新 IDE 配置 — Codex CLI

**文件**: `setup.sh` 新增 `configure_codex()`

- 检测 `AGENTS.md` 文件存在
- 规则注入：在 `AGENTS.md` 中追加 `@.baton/workflow.md`（去重检查）
- 无 hook 能力，完全靠规则引导 + git pre-commit

#### C7. 新 IDE 配置 — Zed AI

**文件**: `setup.sh` 新增 `configure_zed()`

- 检测 `.rules` 文件存在（Zed 的规则文件）
- 规则注入：在 `.rules` 中追加 workflow 引用
- 无 hook 能力

#### C8. 新 IDE 配置 — Roo Code

**文件**: `setup.sh` 新增 `configure_roo()`

- 检测 `.roo/` 目录存在
- 规则注入：复制 workflow-full.md 到 `.roo/rules/baton-workflow.md`
- 当前无 hook 能力（hooks 开发中，PR #11663 进行中）
- 未来可扩展：当 Roo Code 发布 hooks 后，添加 PreToolUse 配置

#### C9. 更新 `detect_ides()` — 扩展检测范围

**文件**: `setup.sh` `detect_ides()`

当前检测 5 个 IDE，需扩展到全部：

```sh
detect_ides() {
    ides=""
    [ -d "$PROJECT_DIR/.claude" ]      && ides="$ides claude"
    [ -d "$PROJECT_DIR/.cursor" ]      && ides="$ides cursor"
    [ -d "$PROJECT_DIR/.windsurf" ]    && ides="$ides windsurf"
    [ -d "$PROJECT_DIR/.factory" ]     && ides="$ides factory"
    [ -d "$PROJECT_DIR/.clinerules" ]  && ides="$ides cline"
    # 新增检测
    [ -d "$PROJECT_DIR/.augment" ]     && ides="$ides augment"
    [ -d "$PROJECT_DIR/.amazonq" ]     && ides="$ides kiro"
    [ -d "$PROJECT_DIR/.github" ]      && ides="$ides copilot"
    [ -f "$PROJECT_DIR/AGENTS.md" ]    && ides="$ides codex"
    [ -d "$PROJECT_DIR/.opencode" ]    && ides="$ides opencode"
    [ -f "$PROJECT_DIR/.rules" ]       && ides="$ides zed"
    [ -d "$PROJECT_DIR/.roo" ]         && ides="$ides roo"
    [ -z "$ides" ] && ides="claude"
    echo "$ides"
}
```

同时更新 `ide_has_session_start()`：
```sh
ide_has_session_start() {
    case "$1" in
        claude|factory|cursor|cline|augment|kiro|copilot) return 0 ;;
        *) return 1 ;;
    esac
}
```

注意 `.github/` 目录很常见（大多数项目都有），仅凭 `.github/` 存在不能确定用了 Copilot。需要更精确的检测条件，例如检测 `.github/copilot-instructions.md` 或 `.github/hooks/` 是否存在。

---

## 影响文件清单

| 文件 | 变更类型 | 内容 |
|------|---------|------|
| `docs/research-ide-hooks.md` | **重写** | 全面刷新 hook 数据：Claude Code 10→17、Cursor 补全至 21、Cline 6→8、Copilot 协议更新、Roo Code 标注开发中 |
| `docs/plans/2026-03-03-baton-v4-design.md` | 修改 | §2.2 分类修正、§2.3 架构图更新、§2.4 各 IDE 配置补充新 hook、Cline 路径、bash-guard 说明、uninstall 细节、self-update、Todo 状态更新 |
| `.baton/git-hooks/pre-commit` | 修改 | 修复文件名空格 bug |
| `tests/test-pre-commit.sh` | 修改 | 添加文件名含空格的测试用例 |

---

## Todo

### Part A: 文档修正 + Bug 修复

- [x] A1. 修正 `docs/research-ide-hooks.md` Tier 1 标题 "7 个" → "8 个"
- [x] A2. 修正 `docs/plans/2026-03-03-baton-v4-design.md` §2.2：从 A 类移除 Cursor，A 类标注改为 "5 个"，B 类标注改为 "3 个"
- [x] A3. 修正 `docs/plans/2026-03-03-baton-v4-design.md` §2.4 Cline 配置：更新为实际实现方式（adapter 安装到 `.baton/adapters/`，workflow-full 复制到 `.clinerules/`）
- [x] A4. 修复 `.baton/git-hooks/pre-commit` 文件名空格 bug：`for f in $(...)` → `git diff -z | while read -d ''`
- [x] A5. 补充 `docs/plans/2026-03-03-baton-v4-design.md`：bash-guard.sh 功能说明 + stop-guard.sh 跨 IDE 配置策略说明
- [x] A6. 补充 `docs/plans/2026-03-03-baton-v4-design.md` §1.2：uninstall 逻辑细节
- [x] A7. 修正 `docs/plans/2026-03-03-baton-v4-design.md` §1.4：`git pull` → `git pull --ff-only`
- [x] A8. 更新 `docs/plans/2026-03-03-baton-v4-design.md` Todo 列表：标记 Phase 1 已完成项
- [x] A9. 全面刷新 `docs/research-ide-hooks.md`：Claude Code 10→17、Cursor 补全至 18、Cline 6→8、Windsurf 新增注记、Roo Code 标注开发中
- [x] A10. 更新 `docs/plans/2026-03-03-baton-v4-design.md` §2.5：补充 bash-guard/stop-guard 说明（含 Cursor stop 差异）

### 格式盲区修复（方案 J：按 IDE 分层策略）

- [x] A14a. CLAUDE.md：`@.baton/workflow.md` → `@.baton/workflow-full.md`
- [x] A14b. setup.sh `configure_cursor()`：baton.mdc 从 3 行引用改为直接内嵌 workflow-full.md 内容
- [x] A14c. setup.sh `configure_claude()`/`configure_factory()`：新安装用 workflow-full.md，已有 workflow.md 自动升级
- [x] A14d. 验证 Windsurf/Cline 规则文件已是 workflow-full.md → 确认无需变更（setup.sh:398, 434）
- [x] A14f. 运行一致性测试：验证各 IDE 配置后的规则文件内容完整性（全部 371 行 workflow-full, Cursor 376 行含 YAML frontmatter）

### 代码变更

- [x] A4-test. 在 `tests/test-pre-commit.sh` 中添加文件名含空格的测试用例（Test 9 + Test 10, 10/10 passed）
- [x] A11. 修复 `setup.sh` `configure_cline()`：创建 `.clinerules/hooks/PreToolUse` 连线文件 + 添加 `TaskComplete` hook
- [x] A12. 扩展 `setup.sh` `configure_cursor()`：在 `.cursor/hooks.json` 中添加 subagentStart、preCompact hook
- [x] A13. 扩展 `setup.sh` `configure_windsurf()`：在 `.windsurf/hooks.json` 中添加 pre_run_command、post_write_code hook
- [x] A11-test. 在测试中验证 Cline hook 连线（Test 14, 31/31 passed）
- [x] A12-test. 在测试中验证 Cursor 扩展 hook（Test 15, 31/31 passed）
- [x] A13-test. 在测试中验证 Windsurf 扩展 hook（Test 16, 31/31 passed）

### Phase 2: CLI 分发层

- [x] B1. 新增 `install.sh`：全局安装脚本（clone/确认 ~/.baton → 复制 bin/baton → 加入 PATH）
- [x] B2. 新增 `bin/baton`：CLI 入口脚本（~200 行），子命令路由 + 注册表 + doctor + status
- [x] B3. 实现注册表管理：`registry_add`（去重）、`registry_remove`、`registry_list`（显示版本 + IDE）
- [x] B4. 实现 `baton update --all`：遍历 registry 批量更新，跳过不存在路径并提示
- [x] B5. 自安装场景已由 setup.sh SELF_INSTALL 逻辑处理
- [x] B-test. 编写 `tests/test-cli.sh`：CLI 子命令测试（14/14 passed）

### Phase 3: 健康检查 + 新 IDE 支持

- [x] C1. 实现 `baton doctor`：6 类检查（脚本完整性、IDE 配置、规则注入、git hook、版本一致）— 在 bin/baton 中实现
- [x] C2. 实现 `baton status`：复用 phase-guide.sh 状态检测，面向人类输出 — 在 bin/baton 中实现
- [x] C3. 新增 `configure_augment()`：`.augment/settings.json` hook + 规则注入
- [x] C4. 新增 `configure_kiro()`：`.amazonq/hooks.json` + 规则注入
- [x] C5. 新增 `configure_copilot()`：`.github/hooks/baton.json` + adapter-copilot.sh + copilot-instructions.md
- [x] C6. 新增 `configure_codex()`：AGENTS.md 规则注入
- [x] C7. 新增 `configure_zed()`：.rules 规则注入
- [x] C8. 新增 `configure_roo()`：.roo/rules/ 规则注入
- [x] C9. 扩展 `detect_ides()` + `ide_has_session_start()`：新增 7 个 IDE 检测（.github 使用 copilot-instructions.md 或 .github/hooks 目录检测）
- [x] C-test. 编写测试：新 IDE 检测 + 各 configure_* + doctor/status 输出验证（合入 test-multi-ide.sh Tests 17-22 + test-cli.sh Tests 5-9）

### Code Review 修复（2026-03-05）

- [x] R1. [CRITICAL] 修复 Copilot 检测运算符优先级 bug：`setup.sh:109-111` `A || B && C` → 用 `{ A || B; } && C` 分组，且将 `.github/hooks` 改为 `.github/hooks/baton.json` 以避免误检
- [x] R2. [IMPORTANT] `bin/baton` doctor() 补全新增 7 个 IDE 检查（augment, kiro, copilot, codex, zed, roo）
- [x] R3. [IMPORTANT] `bin/baton` registry_list() 补全新增 IDE 检测，与 setup.sh detect_ides() 保持一致
- [x] R4. [IMPORTANT] 移除 `configure_windsurf()` 中 slim workflow 死代码分支（`ide_has_session_start "windsurf"` 永远为 false）
- [x] R5. [IMPORTANT] uninstall 逻辑补全新增 IDE 产物清理（augment, kiro, copilot, roo, codex, zed）
- [x] R6. [S-8] 修复 pre-commit 拼接逻辑：`grep -v '^#!/bin/sh'` → `grep -v '^#!'`，适配新 shebang `#!/usr/bin/env bash`
- [x] R7. [S-2] `baton status` todo 匹配：`grep -ci` → `grep -c`，严格匹配小写 `[x]`
- [x] R8. 更新 `test-multi-ide.sh` run_detect_ides() 与 setup.sh detect_ides() 保持同步 + 添加 Copilot 检测 + 卸载 + 新 IDE 检测测试（Tests 23-27）
- [x] R9. 运行全部测试验证修复（pre-commit 10/10, multi-IDE 36/36, CLI 14/14 = 60/60）

---

## 影响文件清单

| 文件 | 变更类型 | 内容 |
|------|---------|------|
| `docs/research-ide-hooks.md` | **重写** | 全面刷新 hook 数据 |
| `docs/plans/2026-03-03-baton-v4-design.md` | 修改 | 分类修正、架构图更新、各 IDE 配置补充、Todo 状态更新 |
| `.baton/workflow.md` | 修改 | 补 Annotation Log 格式摘要 + 批注区模板摘要 |
| `.baton/workflow-full.md` | 修改 | 同步更新对应部分 |
| `.baton/hooks/phase-guide.sh` | 修改 | ANNOTATION/PLAN/RESEARCH 阶段补格式模板 |
| `.baton/git-hooks/pre-commit` | 修改 | 修复文件名空格 bug |
| `setup.sh` | 修改 | Cline 连线、Cursor/Windsurf hook 扩展、新增 7 个 configure_*、扩展 detect_ides |
| `install.sh` | **新增** | 全局安装脚本 |
| `bin/baton` | **新增** | CLI 入口脚本 + 注册表管理 + doctor/status |
| `tests/test-pre-commit.sh` | 修改 | 空格文件名测试 |
| `tests/test-multi-ide.sh` | 修改 | Cline 连线、Cursor/Windsurf 扩展、新 IDE 检测 |
| `tests/test-cli.sh` | **新增** | CLI 子命令测试 |
| `tests/test-doctor-status.sh` | **新增** | doctor/status 输出验证 |

---

## Annotation Log

### Round 1 (2026-03-04)

**[DEEPER] § 全局**
"今天又新增了好几个 claude 的 hooks 是否需要再重新调研一下"
→ 确认过时。派发 3 个 research agent 调研最新数据：Claude Code 10→17 hooks（+7），Cursor ~8→21（含 Tab hooks），Cline 6→8，Roo Code 开始开发 hooks。
→ 结果：采纳。新增 A9（数据刷新）和 A10（设计文档 hook 覆盖策略更新）。

### Round 2 (2026-03-04)

**[NOTE] § 方法论**
"1. 我发现你刚才研究的时候没有调用 context7"
→ 确认失误。Context7 有 `/anthropics/claude-code` 库（778 snippets），查询返回了 9 个 hook 的结构化文档。根因：派发 research agent 时未要求使用 Context7 工具。
→ 结果：记录为通用原则（见下方 [NOTE] 2）。

**[NOTE] § 方法论（续）**
"2. 改进不用写这么死，任何阶段有可用工具都应该去用"
→ 同意。之前窄化为"IDE hook 调研应 Context7 优先"。实际应是通用原则：**任何阶段有可用的 MCP 工具和数据源时都应优先使用**。
→ 结果：采纳为通用原则。

**[NOTE] § 格式**
"你最开始生成的 plan 没有按意图推导计划名，批注区格式不对"
→ **命名**：workflow 规则要求非 simple task 用 `plan-<topic>.md`。已 `mv plan.md plan-v4-design-review.md` 修正。**批注区**：对比已归档 plan 文件确认正确格式。根因：首次创建时未 read 已有 plan 文件确认规范。
→ 结果：采纳。文件已重命名，批注区格式已修正。

### Round 3 (2026-03-05)

**[DEEPER] § Todo**
"我看怎么都是修复文档，脚本相关的改动好像就一个 pre-commit 的 bug 修复，是不是还有遗漏的脚本改动没有列出来？"
→ **确认遗漏 3 项重要脚本改动**：(1) Cline hook 连线缺失——adapter 存在但 `.clinerules/hooks/PreToolUse` 未创建，adapter 永远不会被调用（bug）；(2) Cursor 只配了 2/7 hooks，现在 Cursor 2.4+ 支持 subagentStart/preCompact/postToolUse 等；(3) Windsurf 只配了 1 hook，可扩展 pre_run_command 和 post_write_code。
→ 结果：采纳。新增 A11/A12/A13 及对应测试项，代码变更从 2 项增至 8 项。

### Round 4 (2026-03-05)

**[Q] § 变更范围**
"你现在的方案有包含阶段2和阶段3的吗？"
→ **没有。** 原方案只包含 Part A（文档修正 + bug 修复 + hook 扩展），Part B 只记录了注意事项。原因是范围收敛到了"修正已发现的问题"。
→ 结果：等待人类决策。

**[NOTE] § 变更范围**
"阶段2和阶段3都需要纳入，不然 plan 不完整。设计文档修正是为了指导阶段2和3的实施"
→ 同意。Part A 文档修正的目的是让设计文档准确，以此为基础实施 Phase 2/3。已展开 Part B（CLI 分发层）和 Part C（健康检查 + 7 个新 IDE 配置）。
→ 结果：采纳。Todo 从 18 项扩至 30 项，影响文件清单扩至 10 个文件。

### Round 5 (2026-03-05)

**[Q] § 批注区格式**
"批注区的格式不对，没有第几轮讨论的了，是什么原因导致的呢"
→ `workflow-full.md:305-315` 明确定义了 Annotation Log 的 Round 分轮格式。我用了扁平表格，丢失了时间线结构。
→ 结果：采纳。Annotation Log 已从扁平表格重构为 Round 分轮格式。

### Round 6 (2026-03-05)

**[Q] § 根因分析**
"为什么是读之前归档的 plan 呢，不是读 workflow 里面的规则吗？"
→ 正确。`workflow-full.md` 是格式规范的权威来源：Annotation Log 格式在 `workflow-full.md:305-315`，批注区模板在 `workflow-full.md:192-203`，命名规则在 `workflow.md:56`。
→ 结果：采纳。修正了根因认知。

### Round 7 (2026-03-05)

**[Q] § 根因深挖**
"workflow-full.md 中明确了 Annotation Log 的 Round 分轮格式，但你最初的版本是扁平表格。是什么原因？你每一次会话不是都会携带 workflow 吗？"
→ 精确排查：每次会话通过 `CLAUDE.md → @.baton/workflow.md` 加载的是 **slim 版**（66 行）。slim 版在 `workflow.md:29,39,46` 提到"Annotation Log"和"round"，但**不包含格式模板**。`### Round N (YYYY-MM-DD)` 的具体格式只在 `workflow-full.md:305-315`。本次会话未主动 read workflow-full.md，因此没有模板参考，自行用了扁平表格。
→ **暴露产品问题**：slim workflow + phase-guide.sh 都不含格式模板。对使用 slim 版的 IDE（Claude Code），Log 格式成了盲区。
→ 结果：根因确认。

### Round 8 (2026-03-05)

**[Q] § 改进落实**
"这个问题有更好的设计实现吗？还有就是上面发现的问题，你分析后有对这些问题做改进计划吗？"
→ **设计方案**：推荐方案 C（两处都补）——slim workflow 加最小格式摘要 + phase-guide.sh 各阶段补格式提示。互为冗余，确保不遗漏。
→ **改进计划缺失确认**：分析出了问题但没有落实到 Todo。经验证 phase-guide.sh 三个阶段的具体缺失：ANNOTATION 缺 Round 格式模板、PLAN 缺批注区模板、RESEARCH 缺批注区模板。
→ 结果：采纳。新增 Part A14（6 项 Todo），影响文件清单增加 workflow.md、workflow-full.md、phase-guide.sh。总 Todo 从 30 项增至 36 项。

### Round 9 (2026-03-05)

**[Q] § A14 — Hook 覆盖**
"sessionStart hook 做得不能覆盖某些场景 那有其他hook能覆盖实现吗?"
→ 使用 Context7 查询最新 hook 文档。**关键发现**：`UserPromptSubmit`（Claude Code、Cline）/ `beforeSubmitPrompt`（Cursor）每轮对话触发，自然覆盖回环和压缩后场景。之前只考虑了已有 hook（SessionStart、PreCompact、SubagentStart），未查阅最新文档。Cursor 确认 18 个 hook 事件（之前计划中为 21 个，数据来源不同）。
→ 结果：A14 方案扩展为 6 个选项（A-F），新增方案 E（workflow.md + UserPromptSubmit）和方案 F（phase-guide 迁移到 UserPromptSubmit）。

**[Q] § A14 — 计划回环**
"我记得规则文档里面有写计划回环呀"
→ 确认。`workflow.md:15` + `workflow-full.md:354-356` 定义了计划回环：实现中移除 BATON:GO → 回退到批注回环。Round 7-8 的分析**未考虑此场景**。回环意味着同一会话可能多次进入 ANNOTATION 阶段，而 SessionStart 只触发一次。这进一步削弱了方案 B（只改 phase-guide.sh）的可行性，支持需要"每轮触发"或"始终在 context"的方案。
→ 结果：已在 A14 问题分析中补充回环因素。

**[Q] § A14 — 方案确认**
"你只是推荐了方案C 我还没确认具体是使用那个方案呢 你就帮我做决定了?"
→ 违反了 `workflow-full.md:228-229`: "Don't decide for the human"。推荐了方案 C 后直接在 Todo 中写入了 6 项实施计划，未等人类确认。
→ 结果：已撤回 A14 的 Todo 项，改为"方案待确认"。重新呈现 6 个方案（A-F），推荐方案 E，等待人类选择。

**[Q] § A14 — Context 成本**
"A14 中每轮context新增多少 预估一下"
→ 估算了 6 个方案的 context 成本。关键发现：workflow.md 通过 CLAUDE.md 加载到 system prompt，不被压缩。推荐从 E 改为 A。

**[Q] § A14 — 全阶段覆盖**
"1.但是workflow里面的规则始终不是很全 2.需要考虑所有阶段不只是标注阶段"
→ 之前分析只关注 ANNOTATION 阶段的 Annotation Log 格式盲区。实际上 **4 个阶段都有格式模板缺失**：RESEARCH 缺 ~86 行（call chain 模板、Self-Review、批注区）、PLAN 缺 ~69 行（方案分析、批注区）、ANNOTATION 缺 ~105 行（Round 格式、write-back）、IMPLEMENT 缺 ~35 行（执行序列、Retrospective）。总计 ~295 行 / ~3000 tokens 的格式模板只存在于 workflow-full.md。
→ **根因重新定位**：问题不是"Annotation Log 格式缺失"，而是"slim/full 拆分架构在 hook 瞬时性下的系统性覆盖不足"。方案 A（只补 +110 tokens 的标注格式）是打补丁；方案 G（废弃拆分，统一 workflow-full.md，+3000 tokens = 2%）从根源消除问题。
→ 结果：方案从 6 个精简为 4 个（A'/E/G/H），推荐从 A 改为 G。等待人类选择。

### Round 10 (2026-03-05)

**[Q] § A14 — 全量加载的必要性**
"你的意思是每轮会话都全量加载 workflow-full.md 吗？那岂不是每个阶段都需要引入不必要的token消耗 还有其他的最优方案吗 是否有必要每轮全量加载 每轮全量加载后如果压缩会不会又丢失格式了"
→ 回答三个子问题：
→ (1) **每轮全量加载？** 是每个会话（session），不是每轮对话（turn）。@import 在会话开始时加载为 project instructions，整个会话期间持续可用。
→ (2) **压缩会丢失吗？** 不会。CLAUDE.md @import 作为 project instructions 加载，不属于会话历史，不被 context 压缩影响。在当前 compacted continuation session 中已验证：workflow.md 内容仍完整存在。
→ (3) **不必要的 token 消耗？** 方案 G 在任一阶段有 ~1200-2600 tokens 的无关阶段内容（4 个阶段只需 1 个）。新增方案 I：slim workflow（@import 骨架）+ UserPromptSubmit（按阶段精准交付格式模板），10 轮会话 ~1500 tokens vs 方案 G 的 ~4000 tokens。
→ **两种载体的本质区别**：@import 不被压缩但不能按阶段过滤；hook 可按阶段过滤但会被压缩（UserPromptSubmit 可自愈）。最优解取决于优先简单性还是效率。
→ 结果：新增方案 I，推荐改为"取决于优先级"（简单 → G，效率 → I，折中 → A'）。等待人类选择。

### Round 11 (2026-03-05)

**[Q] § A14 — 跨 IDE 规则加载**
"你只考虑了Claude.md的文件 如果是其他IDE的呢?"
→ 之前分析只基于 Claude Code 的 CLAUDE.md @import 机制，假设所有 IDE 的规则都不被压缩。实际调查 `setup.sh` 各 IDE 配置函数后发现：
→ (1) **Claude Code/Factory**: `CLAUDE.md @import` → project instructions → ✅ 不被压缩。
→ (2) **Cursor**: `setup.sh:344-389` 的 `configure_cursor()` 创建 `.cursor/rules/baton.mdc`，但**只包含 3 行指令**（"Read .baton/workflow.md"），不嵌入实际内容。AI 手动读取后内容在会话历史中，**会被压缩** → ❌ bug。
→ (3) **Windsurf**: `setup.sh:391-428` 直接复制 workflow-full.md → 规则文件。压缩安全性取决于 Windsurf 规则引擎实现 → ❓。
→ (4) **Cline**: `setup.sh:430-437` 直接复制 workflow-full.md → 规则文件。同上 → ❓。
→ **Cursor .mdc 是一个 bug**：不论选哪个 A14 方案都需要修复——当前引用方式意味着 Cursor 在压缩后完全失去工作流规则。
→ 新增**方案 J**（按 IDE 分层策略）：所有 IDE 统一加载 workflow-full.md 完整内容，按 IDE 特性选择最优载体。推荐方案 J。
→ 结果：A14 方案扩展至 A'/E/G/H/I/J，推荐 J。等待人类选择。

### Round 12 (2026-03-05)

**[NOTE] § A14 — 方案确认**
"使用方案J"
→ 人类确认选择方案 J（按 IDE 分层策略），同时添加 `<!-- BATON:GO -->` 批准计划进入实施阶段。
→ A14 实施项：
→ - A14a: CLAUDE.md `@workflow.md` → `@workflow-full.md`
→ - A14b: setup.sh `configure_cursor()` — baton.mdc 从 3 行引用改为内嵌 workflow-full.md
→ - A14c: setup.sh `configure_claude()`/`configure_factory()` — @import 路径更新
→ - A14d: 验证 Windsurf/Cline 已是 full → 无需变更
→ - A14e:（可选）UserPromptSubmit 补位 hook
→ - A14f: 一致性测试
→ 结果：采纳。更新 A14 Todo 项，进入 IMPLEMENT 阶段。

---

## Retrospective

### 计划的准确性
- **文档修正部分（A1-A10）**：高度准确，所有修正项都是直接、可验证的变更。无意外。
- **方案 J（A14）**：是本轮最有价值的决策。原始 slim/full 二分策略存在致命盲区——Cursor .mdc 只有 3 行引用导致 workflow 内容进入对话历史后被 context compression 清除。方案 J 让每个 IDE 都以自身最优机制获得完整内容，一举解决了问题。
- **A4（pre-commit 空格 bug）**：修复使用了 process substitution `< <(git diff -z ...)`，避免了管道创建子 shell 导致变量无法传播的问题。第一次修复用了管道导致测试失败，体现了 bash 子 shell 作用域的常见陷阱。
- **Phase 2/3（B/C）**：实现量比预期大，但结构清晰。`bin/baton` 在 ~285 行纯 POSIX shell 中实现了完整的 CLI + registry + doctor + status，保持了零依赖。

### 意外发现
1. **setup.sh 的 `replace_all` + regex 陷阱**：在编辑 setup.sh 时，将 `@\.baton/workflow\.md` 替换为 ERE 模式 `(-full)?`，但忘记将对应 grep 从 BRE 升级到 ERE（需要 `-E` flag）。导致 grep pattern 在运行时静默失败。教训：批量替换包含正则的字符串时，必须同时审查所有引用该模式的命令。
2. **Windows/MSYS 兼容性**：`while read` 从管道读取在 MSYS 上行为不完全一致。CLI 测试 `baton list` 在管道模式下偶尔超时，但 `$(...)` 捕获模式正常。测试改用 `timeout` + 变量捕获解决。
3. **test-new-hooks.sh 预存 bug**：Test 4 "No plan → silent exit" 存在无限循环问题，与本次修改无关，但值得后续修复。

### 下次可以做得更好
1. **先写测试再写代码**：A4 bug fix 可以先添加 failing test，再修复。本次是修复后才补测试。
2. **分批验证**：38 个 Todo 项一次性实现，中间没有对人类做阶段性确认。对于 Medium+ 规模的变更，建议每完成一个 Part 后暂停确认。
3. **IDE 配置一致性测试应更早编写**：A14f 的一致性测试是最后才做的，但如果更早运行可以更快发现问题。

### 测试结果汇总
| 测试套件 | 结果 |
|----------|------|
| test-pre-commit.sh | 10/10 |
| test-multi-ide.sh | 31/31 |
| test-cli.sh | 14/14 |
| test-adapters-v2.sh | 10/10 |
| test-adapters.sh | 8/8 |
| test-annotation-protocol.sh | 25/25 |
| **总计** | **98/98** |

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § A2：为什么从 A 类移除 Cursor？ -->
<!-- [NOTE] #4 已处理：通用原则 — 任何阶段有可用 MCP 工具都应优先使用 -->
<!-- [DEEPER] #5 已处理：新增 A11(Cline连线bug)/A12(Cursor扩展)/A13(Windsurf扩展)，代码变更从 2 项增至 8 项 -->
<!-- [Q] #6 已回答：不包含 Phase 2/3，当前只有 Part A。等待决策是否纳入 -->
<!-- [NOTE] #7 已处理：Phase 2/3 已纳入，Part B(CLI分发) + Part C(健康检查+新IDE)，Todo 30 项 -->
<!-- [Q] Round 5 已处理：Annotation Log 从扁平表格重构为 Round 分轮格式 -->
<!-- [Q] Round 6 已处理：根因修正为"未 read workflow-full.md 中的格式定义" -->
<!-- [Q] Round 7 已处理：根因确认 — slim workflow 不含 Log 格式模板，暴露产品盲区 -->
<!-- [Q] Round 8 已处理：新增 A14（格式盲区修复），Todo 36 项 -->
<!-- [Q] Round 9 已处理：全阶段分析，根因升级为 slim/full 架构问题，推荐 G -->
<!-- [Q] Round 10 已处理：区分 @import（不压缩）vs hook（可按阶段），新增方案 I。推荐取决于简单 vs 效率优先级。待确认。 -->
<!-- [Q] Round 9 已处理：A14 扩展为全阶段覆盖分析。根因从"标注格式缺失"升级为"slim/full 架构系统性覆盖不足"。方案精简为 A'/E/G/H，推荐 G（废弃拆分，+3000 tokens=2%）。待确认。 -->
<!-- [Q] Round 11 已处理：跨 IDE 分析 — 发现 Cursor .mdc 只有引用不嵌入内容（bug）。新增方案 J（按 IDE 分层策略），推荐 J。待确认。 -->
<!-- [NOTE] Round 12 已处理：人类确认方案 J，添加 BATON:GO。A14 Todo 已更新，进入 IMPLEMENT 阶段。 -->

[NOTE]
    使用方案J

<!-- BATON:GO -->
# Plan 1: 消除 workflow.md / phase-guide.sh 冗余，符合官方最佳实践

## 背景

基于 research-workflow-redundancy.md 的分析，当前 baton 存在三个问题：

1. **CLAUDE.md 全量加载 workflow-full.md (371行) 违反官方 "<200 行" 建议** — AI 可能因内容过长而忽略规则
2. **phase-guide.sh 硬编码精简摘要，每个阶段遗漏 3-7 条规则** — slim + hooks 模式下信息丢失
3. **缺少 compact 后重注入** — 上下文压缩后关键规则可能丢失

## 基本约束（来自 research）

- baton 兼顾自用和分发（workflow.md 必须保留作为分发组件）
- workflow-full.md 是唯一权威源（single source of truth）
- phase-guide.sh 的状态检测逻辑（6种状态）有独立价值
- 需兼容 MINGW/Linux/macOS
- `### [RESEARCH]` / `### [PLAN]` / `### [ANNOTATION]` / `### [IMPLEMENT]` 是稳定可解析的分隔符（spike 已验证 awk 在 MINGW 可靠）
- 官方: "CLAUDE.md is advisory, hooks are deterministic"
- 官方: "keep CLAUDE.md under 200 lines, offload to hooks and skills"

## 推荐方案：方案 A + compact 重注入 + 多 IDE 一致性

### 架构变更

```
Before (当前):
  Claude/Factory: CLAUDE.md → @workflow-full.md (371行全量) ← 违反 <200 行
  Cursor/Augment: rules 嵌入 full + phase-guide 精简摘要 ← 重复 + 信息丢失
  Copilot:        copilot-instructions 引用 full + phase-guide 精简 ← 同上
  SessionStart → phase-guide.sh (硬编码精简摘要) ← 信息丢失
  compact 后 → 无重注入 ← 规则可能丢失

After (目标):
  所有有 SessionStart 的 IDE: rules 加载 slim (~65行) + phase-guide 动态提取当前阶段完整段落
  无 SessionStart 的 IDE:    rules 嵌入 full (不变)
  compact 后 → phase-guide.sh 重新触发 ← 规则恢复
```

### 变更 1: CLAUDE.md 回退到 slim 引用

**文件**: `CLAUDE.md`
**变更**: `@.baton/workflow-full.md` → `@.baton/workflow.md`
**理由**: workflow.md (~65行) 包含 Mindset + Flow + Complexity Calibration + Annotation Protocol + Rules + Session handoff — 这些是"always do X"级别的核心原则，符合官方对 CLAUDE.md 的定位。各阶段的详细指南交给 phase-guide.sh 按需注入。

### 变更 2: phase-guide.sh 改为动态提取

**文件**: `.baton/hooks/phase-guide.sh`
**变更**: 将 6 个阶段的硬编码 heredoc 文本替换为从 `workflow-full.md` 动态提取。

**设计**:
```sh
# 在脚本顶部定义提取函数
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_FULL="$SCRIPT_DIR/../workflow-full.md"

extract_section() {
    _sec="$1"
    _next="$2"
    if [ -n "$_next" ]; then
        awk -v sec="$_sec" -v nxt="$_next" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found && $0 ~ "^### \\[" nxt "\\]" {exit}
            found {print}
        ' "$WORKFLOW_FULL"
    else
        # 最后一个段落（IMPLEMENT）：提取到文件末尾
        awk -v sec="$_sec" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found {print}
        ' "$WORKFLOW_FULL"
    fi
}
```

每个状态的处理变为：
- **RESEARCH**: Mindset 提示行 + `extract_section "RESEARCH" "PLAN"`
- **PLAN**: Mindset 提示行 + `extract_section "PLAN" "ANNOTATION"`
- **ANNOTATION**: Mindset 提示行 + `extract_section "ANNOTATION" "IMPLEMENT"`
- **IMPLEMENT**: Mindset 提示行 + `extract_section "IMPLEMENT" ""`
- **AWAITING_TODO / ARCHIVE**: 保持当前的短提示（这两个状态不对应 workflow-full.md 段落）

**fallback**: 如果 `$WORKFLOW_FULL` 不存在，回退到当前的硬编码文本（保证健壮性）。

### 变更 3: 新增 compact 后重注入

**文件**: `.claude/settings.json`
**变更**: 在 SessionStart hooks 中增加一条 compact matcher 规则。

```json
"SessionStart": [
  {
    "matcher": "",
    "hooks": [{"type": "command", "command": "bash .baton/hooks/phase-guide.sh"}]
  },
  {
    "matcher": "compact",
    "hooks": [{"type": "command", "command": "bash .baton/hooks/phase-guide.sh"}]
  }
]
```

**效果**: 上下文压缩后，phase-guide.sh 再次触发，重新注入当前阶段的完整规则。

### 变更 4: setup.sh 中 Cursor/Augment/Copilot 规则改为 slim

**文件**: `setup.sh` 的 `configure_cursor()`, `configure_augment()`, `configure_copilot()`

当前状态（`setup.sh:415,545,630`）：这些 IDE 既嵌入/引用 workflow-full.md 到 rules，又配置了 phase-guide.sh SessionStart hook。改为动态提取后会收到重复内容。

**变更**：
- **Cursor** (`configure_cursor`): `baton.mdc` 改为嵌入 workflow.md (slim) 而非 workflow-full.md
- **Augment** (`configure_augment`): `augment/rules/baton-workflow.md` 改为复制 workflow.md (slim)
- **Copilot** (`configure_copilot`): `copilot-instructions.md` 引用改为 `.baton/workflow.md`

**不需要改的 IDE**（无 SessionStart，保持 full 嵌入）：
- Windsurf, Cline, Kiro, Codex, Zed, Roo — 不变

### 变更 5: workflow.md 重新设计为独立的核心规则文件

**文件**: `.baton/workflow.md`
**变更**: 不再是 workflow-full.md 的截断，而是**专门为 always-loaded 角色设计**的核心规则。

**设计原则**：workflow.md 的定位是"无论哪个阶段都需要的核心原则"，各阶段详细指南由 phase-guide.sh 按需注入。提示词风格应**更 agentic**——目标驱动 + 约束式 + 元认知触发，而非过程化清单。

#### 提示词风格改进方向

baton 的核心张力：workflow 的目的是限制 AI 的行动自主性（write-lock、plan-first），但应给予充分的**认知自主性**（如何思考、如何判断质量）。

改进原则：
1. **目标驱动** — 描述"达到什么状态"而非"执行什么步骤"。
   - Before: "append ## Retrospective to plan.md (what the plan got wrong...)"
   - After: "实施结束后，确保学习被记录——记录 plan 的预测与实际的差异、意外发现、下次研究的改进方向"
2. **约束式边界** — 保持行动约束（write-lock、BATON:GO），但不过度规定认知过程
   - Before: "Read code first — don't answer from memory"
   - After: "Every claim requires file:line evidence. If you can't cite evidence, you don't know it yet."
3. **元认知触发器** — 在关键决策点插入自检提示
   - "Before marking any todo item complete: re-read the code you wrote. Does it match the plan's intent, or did you drift?"
   - "Before presenting research: what would a skeptic challenge first?"
4. **明确的成功标准** — AI 知道什么算"做好了"
   - "Research is sufficient when: the human can judge your understanding's correctness by reading your document alone"
   - "A plan is ready when: it derives approaches from constraints, not from preference"

#### 具体内容设计

**保留并以 agentic 风格重写**：
- Mindset（3 原则）— 已经很好，保留 ✅
- Flow（场景 A/B）— 保留但补充意图说明：为什么先研究后计划 ✅
- Complexity Calibration — 保留，这本身就是授权 AI 判断 ✅
- Annotation Protocol — 重写为"目标 + 约束"而非"步骤清单" ✅
- Rules — 区分行动约束（保留）和操作指令（改为目标描述）✅

**新增**：
- **证据标准**：`✅/❌/❓ 标记体系`、`"should be fine" is NOT valid`、`Every claim requires file:line — no evidence = mark ❓`
- **工具使用原则**：`研究开始前清点所有可用文档检索工具。每个至少尝试一次。记录工具使用情况。`
- **阶段衔接说明**：`四个阶段（RESEARCH/PLAN/ANNOTATION/IMPLEMENT）的详细执行指南由 SessionStart hook 按需注入`
- **Todolist 格式**：`## Todo` / `- [ ]` / `- [x]`（hooks grep 匹配依赖此格式）
- **元认知检查点**：关键决策前的自检触发器

**不应包含**（交给 phase-guide 按阶段注入）：
- 各阶段详细执行策略、模板、格式示例

**目标行数**：~80-90 行（<200 行限制内）

**维护方式**：workflow.md 独立维护（不从 workflow-full.md 自动生成）。两份文件有不同职责，不是子集关系。

### 变更 6: setup.sh 更新 Claude Code 的 CLAUDE.md 引用

**文件**: `setup.sh` 的 `configure_claude()` 函数
**变更**: 新安装时写入 `@.baton/workflow.md`（而非 `@.baton/workflow-full.md`）。升级逻辑反转：`@.baton/workflow-full.md` → `@.baton/workflow.md`。

**理由**: 新的架构是 slim CLAUDE.md + phase-guide 动态提取。setup.sh 应匹配这个设计。

## 影响范围

| 文件 | 变更类型 | 影响 |
|------|----------|------|
| `CLAUDE.md` | 修改引用 (full→slim) | 仅本项目 |
| `.baton/hooks/phase-guide.sh` | 重构输出逻辑 (硬编码→动态提取) | 核心变更，影响所有使用 SessionStart 的 IDE |
| `.claude/settings.json` | 增加 compact hook | Claude Code |
| `setup.sh` — `configure_claude()` | 引用改为 slim | Claude/Factory 分发 |
| `setup.sh` — `configure_cursor()` | rules 改为 slim | Cursor 分发 |
| `setup.sh` — `configure_augment()` | rules 改为 slim | Augment 分发 |
| `setup.sh` — `configure_copilot()` | 引用改为 slim | Copilot 分发 |
| `setup.sh` — workflow 安装逻辑 | 自动生成 slim | 所有 IDE 分发 |

不需要修改的文件：
- `workflow-full.md` — 保持不变（权威源）
- `workflow.md` — 将由 setup.sh 自动生成（但当前 baton 自身的这份也需要验证一致性）
- `write-lock.sh` / `completion-check.sh` / 其他 hooks — 保持不变
- `configure_windsurf/cline/kiro/codex/zed/roo` — 不变（无 SessionStart 或不使用 phase-guide）

## 风险 + 缓解

| 风险 | 缓解策略 |
|------|----------|
| awk 提取在某些环境下失败 | fallback 到硬编码文本 + 测试覆盖 MINGW/Linux/macOS |
| workflow-full.md 段落标记被修改导致提取失败 | 提取函数检查输出是否为空，为空时 fallback + 输出警告 |
| compact matcher 导致 phase-guide 重复触发 | 无害——重复注入当前阶段信息只是冗余，不会产生错误行为 |
| slim workflow.md 在 compact 后被压缩掉 | phase-guide compact 重注入补偿（变更 3） |
| 自动生成的 workflow.md 边界不对 | 使用 `---` 分隔符而非硬编码行数（workflow-full.md 第 68 行是 `---`） |

## 范围拆分

本 plan 原本包含 7 个变更，经评估加入 workflow-full.md agentic 重写后复杂度从 Medium 升级为 Large。

**决定拆分为两个 plan**：

**Plan 1（本文档）: 结构性改进** — 变更 1-4, 6
- 消除冗余架构：slim CLAUDE.md + phase-guide 动态提取 + compact 重注入 + 多 IDE 一致性
- 不改动 workflow.md / workflow-full.md 的**内容**（仅改引用方式和提取方式）
- 实施后新架构即可正常工作

**Plan 2（后续）: 内容优化 — workflow.md + workflow-full.md agentic 重写**
- workflow.md：独立设计为 always-loaded 核心规则（~80-90行，agentic 风格）
- workflow-full.md：各阶段详细指南 agentic 重写（~371行）
- 两份文件一起优化确保风格一致
- 可利用 Plan 1 实施后的实际测试反馈指导内容方向

**理由**：结构变更和内容变更是独立关注点。先确保管道正确（Plan 1），再优化管道中流动的内容（Plan 2）。

变更 5（workflow.md 重新设计）的设计方向和 agentic 风格分析保留在本文档中，作为 Plan 2 的输入。

## 过程反思

本次研究阶段存在一个流程遗漏：在 [RESEARCH-GAP] 补充研究时，**未使用所有可用的文档检索工具**（遗漏了 Context7），违反了 workflow-full.md 的研究规范。经人工批注指出后补充了 Context7 查询，获得了两条有价值的新发现。

### 根因分析

1. **规则被淹没**：workflow-full.md 371 行全量加载，Tool Usage in Research 只是 [RESEARCH] 段落的一个子节（`workflow-full.md:126-130`），在大量规则中容易被忽略。这恰好印证了官方 "<200 行" 建议的合理性。
2. **缺少显式的第一步**：研究阶段没有"开始前先清点可用工具"的显式步骤。直接跳进了最熟悉的工具（WebSearch），没有先问"还有哪些工具可用"。
3. **无执法机制**：write-lock 能阻断代码写入，但没有 hook 能检查"研究时是否使用了所有工具"。完全依赖 advisory 规则 = 容易被忽略。

### 改进措施

**本次 plan 实施**：方案 A 的动态提取（核心结构性改进）会在 RESEARCH 阶段注入完整的 [RESEARCH] 段落，比 371 行全量更聚焦。workflow.md 重新设计后也会包含工具使用原则。

**workflow-full.md 改进**：在 [RESEARCH] Execution Strategy 中，将工具清点提升为**显式的第 0 步**：
```markdown
0. **Tool inventory**: before starting, list all available documentation retrieval tools.
   Record the list in research.md. Each tool must be attempted at least once.
```
这确保动态提取后，工具清点是 RESEARCH 阶段指南的**第一件事**，而非埋在子节中。

## Self-Review

- **最大风险**：phase-guide.sh 动态提取的 awk 逻辑在某些 shell 环境下可能有差异（特别是 awk 变量中的转义字符）。spike 在 MINGW 上验证了可行，但未覆盖 macOS 的 BSD awk。**缓解**：保留硬编码 fallback（当 workflow-full.md 不存在或提取结果为空时回退）+ 在测试中覆盖 BSD awk 兼容性。
- **什么会让这个方案完全错误**：如果 Claude Code 的 SessionStart hook 对 stderr 输出有长度限制或截断行为，100+ 行的动态提取可能无法完整传达。**缓解**：实施后需实际测试 SessionStart 输出 100+ 行的行为；如确认有截断，可改为输出到 stdout（官方文档确认 stdout 进入 AI context）或限制提取长度。
- **被拒绝的替代方案**：方案 B（全量加载 + 精简指示）— 在社区调研前是首选，但官方 "<200 行" 建议和 "offload to hooks" 原则使其不再最优。

## Annotation Log

### Round 1 (2026-03-05)

**[MISSING] § 过程反思**
"你这份计划里面没有提到你在做研究时没有遵循流程 使用可用的工具"
→ 已补充 § 过程反思 段落，记录了研究阶段遗漏 Context7 工具的教训，以及后续应遵循的规范。
→ Result: accepted

**[Q] § Self-Review — 有更好的方案吗**
"Self-Review 块的 有更好的方案吗"
→ 已增强 Self-Review 的缓解策略：
  1. awk 兼容性风险：增加"测试中覆盖 BSD awk 兼容性"
  2. SessionStart 输出截断风险：增加"可改为 stdout 输出（官方确认进入 AI context）"和"限制提取长度"两个 fallback 选项
  整体方案 A 本身仍是最优选择（官方 <200行 + 动态提取 = 精简 + 完整），Self-Review 中的风险属于实施细节层面，有明确的缓解路径。
→ Result: accepted

**[Q] § 多 IDE 支持**
"上面方案A只考虑了CLAUDE?其他IDE的有考虑吗？"
→ 确认这是一个重要遗漏。通过 `setup.sh` 逐 IDE 追踪发现：
  - Cursor (`setup.sh:415`): 嵌入 full + phase-guide → 会收到重复内容
  - Augment (`setup.sh:545`): 同上
  - Copilot (`setup.sh:630`): 引用 full + phase-guide → 同上
  已新增 **变更 4: Cursor/Augment/Copilot 规则改为 slim**，确保所有有 SessionStart 的 IDE 统一使用 slim rules + 动态 phase-guide 模式。
  无 SessionStart 的 IDE (Windsurf/Cline/Kiro/Codex/Zed/Roo) 保持 full 嵌入不变。
→ Result: accepted，新增变更 4，更新影响范围表

### Round 2 (2026-03-05)

**[Q] § 过程反思 — 根因与改进**
"只是反思吗 是什么原因导致的没遵守流程 如何改进呢"
→ 这不应该只是反思。做了根因分析：
  1. 规则被淹没（371 行中的子节）→ 方案 A 的动态提取本身就是缓解
  2. 缺少显式第一步 → 建议将工具清点提升为 RESEARCH Execution Strategy 的第 0 步
  3. 无执法机制 → 这是 advisory 规则的固有限制，但可通过结构改进（显式第一步）降低遗漏概率
  已将 § 过程反思 从简单教训扩展为根因分析 + 改进措施（短期 + 结构性）。
→ Result: accepted

### Round 3 (2026-03-05)

**[Q] § 过程反思 — 方案 A 只是短期缓解？**
"方案A只是短期缓解？"
→ 措辞有误。方案 A（动态提取）是本 plan 的核心结构性改进，不是短期缓解。原文在 § 过程反思 中的"短期"是在工具遗漏问题的上下文中误用的。已修正措辞。
→ Result: accepted，已修正

**[Q] § 变更 5 — workflow.md 是否应达到最佳状态**
"如果要slim CLAUDE.md 那 @.baton/workflow.md 里面的规则或者说是提示词是不是应该要达到最佳状态"
→ 完全正确。当前 workflow.md 是 workflow-full.md 的前 65 行截断，不是为"独立承担 CLAUDE.md 核心规则"而设计的。
  已将变更 5 从"自动截取"重新设计为"独立设计的核心规则文件"：
  - 新增：证据标准摘要、工具使用原则、阶段衔接说明、Todolist 格式
  - 不再从 workflow-full.md 自动生成（两份文件有不同职责，不是子集关系）
  - 目标 ~80-90 行，符合 <200 行限制
→ Result: accepted，变更 5 重新设计

### Round 4 (2026-03-05)

**[NOTE] § 变更 5 — workflow.md 是否应更 agentic**
"workflow.md 里面的的规则或者提示词是否应该更agentic?"
→ 好问题。分析了当前提示词风格：
  - ✅ Mindset 已经是目标驱动的（"investigator not executor"）
  - ❌ Rules 段过于过程化（14 条操作指令，如 "append ## Retrospective"、"remind to archive"）
  - ❌ 缺少元认知触发器和明确的成功标准

  baton 的核心张力：行动上需要约束（write-lock），但认知上应给予自主。
  改进方向：目标驱动（描述状态而非步骤）+ 约束式边界 + 元认知触发器 + 成功标准。
  已将 4 个 before/after 示例和具体设计方向整合到变更 5 中。
→ Result: accepted，变更 5 增加 agentic 风格设计方向

### Round 5 (2026-03-05)

**[NOTE] § 变更 5 — workflow-full.md 也应更 agentic**
"那workflow-full.md 里面的规则或者说是提示词是不是也应该要达到最佳状态 比如是否应该更agentic?"
→ 合理延伸。如果 phase-guide.sh 从 workflow-full.md 动态提取，提取源的质量直接影响效果。
  但加入 workflow-full.md 371 行的 agentic 重写会将 plan 从 Medium 升级为 Large。
  **决定**：拆分为两个 plan。
  - Plan 1（本文档）：结构性改进（变更 1-4, 6）— 先确保管道正确
  - Plan 2（后续）：内容优化（workflow.md + workflow-full.md agentic 重写）— 一起做确保一致性
  变更 5 的设计方向和 agentic 风格分析保留在本文档中，作为 Plan 2 的输入。
→ Result: accepted，新增 § 范围拆分，Plan 拆分为结构 + 内容两阶段

## Todo

- [x] 1. 变更 1: CLAUDE.md 引用从 `@.baton/workflow-full.md` 改为 `@.baton/workflow.md`
  - 文件: `CLAUDE.md`
  - 验证: 确认引用指向 workflow.md
- [x] 2. 变更 2: phase-guide.sh 改为从 workflow-full.md 动态提取
  - 文件: `.baton/hooks/phase-guide.sh`
  - 实现: 添加 extract_section 函数 + fallback 逻辑
  - 将 RESEARCH/PLAN/ANNOTATION/IMPLEMENT 四个状态的硬编码 heredoc 替换为动态提取
  - 保留 AWAITING_TODO/ARCHIVE 的短提示不变
  - 验证: `bash .baton/hooks/phase-guide.sh` 在各阶段输出完整段落；无 workflow-full.md 时 fallback 到硬编码
- [x] 3. 变更 3: settings.json 新增 compact matcher 的 SessionStart hook
  - 文件: `.claude/settings.json`
  - 验证: compact 后 phase-guide.sh 重新触发
- [x] 4. 变更 4: setup.sh 中 Cursor/Augment/Copilot 规则改为 slim
  - 文件: `setup.sh` — configure_cursor(), configure_augment(), configure_copilot()
  - Cursor: baton.mdc 嵌入 workflow.md 而非 workflow-full.md
  - Augment: 复制 workflow.md 而非 workflow-full.md
  - Copilot: copilot-instructions.md 引用改为 .baton/workflow.md
  - 验证: 各 configure 函数使用 slim 版
- [x] 5. 变更 6: setup.sh 的 configure_claude() 引用改为 slim
  - 文件: `setup.sh` — configure_claude()
  - 新安装写入 `@.baton/workflow.md`；升级逻辑反转
  - 验证: 新安装和升级都指向 workflow.md
- [x] 6. 运行测试套件验证无回归
  - 运行 tests/ 下的测试: 58/58 passed, 0 failed (ALL PASSED)
  - 验证 phase-guide.sh 在 MINGW 上动态提取正常工作
- [x] 7. 手动验证 phase-guide.sh 各阶段输出
  - 创建临时 plan.md / research.md 触发不同阶段: 6/6 阶段正确
  - 确认各阶段输出完整的 workflow-full.md 段落: ✅ 动态提取正常
  - 确认 fallback（删除 workflow-full.md 后）回退到硬编码: ✅ 正常回退

## Retrospective

- **Plan 预测 vs 实际**：plan 预测 awk 提取在 MINGW 上可能有问题，但 spike 已验证可行。实际上 awk 在 MINGW 完全正常工作。真正的"意外"是测试在 MINGW 上运行极慢（每个 awk 调用约 10-15 秒），但这是测试执行时间问题，不影响功能。
- **意外发现**：测试中两个断言（"Calibrate depth"）在新版中失败，因为动态提取从 workflow-full.md 拿到的内容和旧版硬编码文本不同。这说明旧版 phase-guide.sh 的硬编码摘要和 workflow-full.md 原文确实存在偏差——正是本次改进要解决的问题。
- **下次研究改进**：开始研究前先清点所有可用文档检索工具（本次遗漏了 Context7，被人工批注发现后才补充）。这一教训已写入 § 过程反思，并建议将工具清点作为 RESEARCH 阶段的第 0 步。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏

<!-- BATON:GO -->
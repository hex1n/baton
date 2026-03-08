# 计划：Baton 架构演进 — 以循环批注为核心，技术债清理 + Harness 基础

## 参考文档

- 研究：`research.md`（第一性原理分析 + 方向讨论 + 批注循环核心定位）

## 问题陈述

research.md 的第一性原理分析揭示了三个层次的问题：

### 技术债（阻碍任何演进）

1. **SYNCED 代码复制** — 同一逻辑（plan-name-resolution + find_plan）手工同步到 9 个文件。任何修改需同步 9 处，`test-workflow-consistency.sh` 只做静态检查不验证语义一致性。
   - 证据：write-lock.sh:62-67, phase-guide.sh:59-64, stop-guard.sh:16-21, bash-guard.sh:11-16, post-write-tracker.sh:43-48, completion-check.sh:19-24, pre-compact.sh:17-22, subagent-context.sh:17-22, pre-commit:20-26

2. **OpenCode 插件行为不一致** — 不支持 `plan-*.md` glob fallback，与所有 shell hook 行为不同。
   - 证据：opencode-plugin.mjs:12 (`process.env.BATON_PLAN || 'plan.md'`) vs write-lock.sh:64-66 (`ls -t plan.md plan-*.md`)

3. **CI 覆盖缺口** — 最大测试文件 test-multi-ide.sh (924行) 不在 CI 中运行；ci.yml:25 shellcheck 引用已删除的 `adapter-windsurf.sh`。

### 投入错位（限制发展）

- setup.sh 1524 行 (58%) 服务于 11 IDE 安装
- 真正完整体验的只有 Claude Code (7 hooks)
- Skills（认知缰绳）是最有价值的部分，但不是工程重心

### 核心认知（方向锚定）

- **循环批注是 baton 的核心** — 唯一创造人机共识的机制
- Skills/Harness 服务于循环（让 AI 产出值得批注的文档）
- write-lock 是安全网，不是核心机制

## 约束

从研究中提取的基本约束：

1. **POSIX sh 兼容** — 所有 hook 使用 `#!/bin/sh`，不能引入 bash-only 语法
2. **零外部依赖** — jq 可选，awk 回退必须保留
3. **Fail-open 设计不可改变** — 治理工具不应因自身 bug 阻止工作
4. **向后兼容** — 已安装项目升级不应破坏
5. **独立脚本可调试** — hook 需要能单独运行和测试

## 方案分析

### 方案 A：纯技术债清理

只修复 3 个已识别问题，不做架构变更。

**变更内容**：
1. 抽取 `_common.sh`，消除 SYNCED 代码复制
2. 修复 OpenCode 插件 glob fallback
3. 修复 CI 配置（加入缺失测试、移除失效 shellcheck）

**评估**：
- 可行性：✅ 低风险，明确范围
- 优点：立即提升代码质量，降低维护负担
- 缺点：不推进战略方向（循环批注 + harness）
- 影响范围：8 个 hook + 1 个 JS 插件 + ci.yml

### 方案 B：技术债清理 + Annotation Cycle 质量基础（推荐）

在方案 A 基础上，增加一个服务于循环批注的质量评估 hook。

**变更内容**：
1. （同方案 A）抽取 `_common.sh`
2. （同方案 A）修复 OpenCode 插件
3. （同方案 A）修复 CI 配置
4. 新增：PostToolUse hook 对 research.md/plan.md 做结构质量检查
   - 检查 research.md 是否有 `## Self-Review`、`## 批注区`、file:line 引用
   - 检查 plan.md 是否有 `## Self-Review`、`## 批注区`、方案分析
   - 输出缺失项到 stderr（advisory，不阻止）
   - 这直接服务于循环批注：提高进入批注循环的文档质量 → 减少人类需要指出的基础问题 → 批注聚焦于真正需要人类判断的内容

**评估**：
- 可行性：✅ 可行 — 质量检查是纯 grep/awk 操作
- 优点：既清理技术债，又迈出 harness engineering 的第一步；直接强化了循环批注的核心
- 缺点：多一个 hook 增加少量复杂度
- 影响范围：8 个 hook + 1 个 JS 插件 + ci.yml + 1 个新 hook

### 方案 C：全面架构重组

重组整个项目，skills 成为 60% 投入，setup.sh 大幅简化。

**评估**：
- 可行性：❌ 范围过大 — 涉及 11 IDE 配置重写，破坏所有已安装项目
- 优点：干净的架构
- 缺点：巨大的破坏性变更，收益不确定
- 排除原因：可以在方案 B 完成后逐步推进，不需要一步到位

### 方案 D：技术债清理 + Skills 强化（批注后修正推荐）

方案 B 的变更 4（doc-quality.sh hook）存在逻辑矛盾：用事后检查验证"AI 是否遵循了 skills"——这是 gate 思维，不是 harness 思维。Skills 已经包含 doc-quality.sh 要检查的每一项：
- Self-Review: baton-research SKILL.md:103-108, baton-plan SKILL.md:71-74
- 批注区: baton-research SKILL.md:203, baton-plan SKILL.md:192-202
- file:line evidence: baton-research SKILL.md:124

**与其事后检查 skills 是否被遵循，不如让 skills 本身更强。**

**变更内容**：
1. （同方案 A/B）抽取 `_common.sh`
2. （同方案 A/B）修复 OpenCode 插件
3. （同方案 A/B）修复 CI 配置
4. 替换变更 4：不新增 hook，而是强化 3 个 skills
   - baton-research：增加退出前的自检清单（"确认 Self-Review 已写、批注区已加、至少 3 处 file:line"）
   - baton-plan：增加退出前的自检清单（"确认 Self-Review 已写、批注区已加、方案分析已写"）
   - baton-implement：增加每个 todo 完成后的自检步骤（"重读代码，对比 plan intent"）

**评估**：
- 可行性：✅ 最简单 — 只改 markdown 文件，零代码风险
- 优点：
  - 纯 harness 思维 — 塑造过程，不做事后检查
  - 不增加系统复杂度（不新增 hook）
  - 天然跨 IDE（skills 是 markdown）
  - 直接服务循环批注：更好的 skills → 更好的文档 → 更高效的批注循环
- 缺点：依赖 AI 合规性（但这正是 harness 的本质 — 引导而非强制）

## 推荐方案 D（修正）

理由追溯到研究发现：

1. **SYNCED 复制是"定时炸弹"** (research.md § 四) — 不解决则任何新功能都在沙上建塔
2. **循环批注是核心** (research.md § 九/Round 3) — skills 直接提高进入循环的文档质量
3. **Harness 是过程塑造不是事后检查** (research.md § 九/Round 2) — 强化 skills > 新增 hook
4. 不增加系统复杂度，不增加维护负担，不增加新的 fail-open 路径

## 变更清单

### 变更 1：抽取 `_common.sh` 消除 SYNCED 代码复制

**What**: 创建 `.baton/hooks/_common.sh`，包含 `resolve_plan_name()` 和 `find_plan()` 两个函数。所有 8 个 hook + pre-commit 改为 `source` 引用。

**Why**: 9 处手工同步是最大维护风险 (research.md § 四)。消除后，plan 解析逻辑只在一处维护。

**Impact**:
- 修改：write-lock.sh, phase-guide.sh, stop-guard.sh, bash-guard.sh, post-write-tracker.sh, completion-check.sh, pre-compact.sh, subagent-context.sh
- 新增：`.baton/hooks/_common.sh`
- 修改：`.baton/git-hooks/pre-commit`（source _common.sh）
- 修改：`setup.sh`（install_versioned_script 增加 _common.sh）
- 修改：`test-workflow-consistency.sh`（验证策略从"检查 SYNCED 注释"改为"检查 source _common.sh"）

**Risk**: source 路径依赖脚本位置。缓解：`_common.sh` 使用 `$SCRIPT_DIR` 相对路径定位，与现有 phase-guide.sh:13 的 `SCRIPT_DIR` 模式一致。

**约束检查**:
- POSIX sh：✅ `source` → 改用 `.`（POSIX 标准）
- 独立可调试：⚠️ hook 不再完全独立，但 `_common.sh` 足够小（~15行），调试影响很小

### 变更 2：修复 OpenCode 插件 glob fallback

**What**: 在 `opencode-plugin.mjs` 中添加 `plan-*.md` glob fallback，与 shell hook 行为一致。

**Why**: 行为不一致导致用户困惑 (research.md § 六)。

**Impact**:
- 修改：`.baton/adapters/opencode-plugin.mjs`
- 使用 `fs.readdirSync` + filter + sort by mtime 实现等效于 `ls -t plan.md plan-*.md | head -1`

**Risk**: 低 — 独立文件，不影响 shell hook。

### 变更 3：修复 CI 配置

**What**:
- 移除 ci.yml:25 对已删除 `adapter-windsurf.sh` 的 shellcheck 引用
- 将 `test-multi-ide.sh` 加入 CI
- 将 `test-pre-commit.sh` 加入 CI

**Why**: CI 缺口意味着回归风险 (research.md § 七)。

**Impact**:
- 修改：`.github/workflows/ci.yml`

**Risk**: CI 运行时间增加。缓解：test-multi-ide.sh 可以在单 OS 上运行（不需要 matrix）。

### 变更 4：新增文档质量检查 hook

**What**: 创建 `.baton/hooks/doc-quality.sh`，作为 PostToolUse hook 在 AI 写入 research.md 或 plan.md 后检查结构完整性。

检查项：
- research.md: `## Self-Review` 存在？`## 批注区` 存在？至少 3 处 file:line 引用？
- plan.md: `## Self-Review` 存在？`## 批注区` 存在？方案分析存在？

输出格式：缺失项列表到 stderr。全部通过则静默。

**Why**: 直接服务于循环批注核心 — 提高进入批注循环的文档质量 (research.md § 九)。这是最小可行的 harness。

**Impact**:
- 新增：`.baton/hooks/doc-quality.sh`
- 修改：`.claude/settings.json`（PostToolUse 增加对 .md 文件的质量检查）
- 修改：`setup.sh`（configure_claude 增加 doc-quality hook）

**Risk**:
- 噪声风险：如果每次写 .md 都输出警告，可能造成 AI 注意力分散。缓解：仅在文档有 `##` 标题时（说明是结构化文档而非草稿）才检查；且只在文档写入完成时检查一次，不在每次编辑时重复。
- 误判风险：部分 .md 文件不是 research/plan（如 README.md）。缓解：只检查文件名匹配 `research*.md` 或 `plan*.md` 的文件。

**约束检查**:
- Fail-open：✅ advisory only，`exit 0`
- POSIX sh：✅ 纯 grep 操作
- 零依赖：✅ 不需要 jq

## Self-Review

- **最大风险**: 变更 1（_common.sh 抽取）改变了所有 hook 的运行方式。虽然逻辑不变，但 source 路径解析在不同工作目录下可能有边界情况（如 git worktree、符号链接）。需要在 test-write-lock.sh 中增加 source 路径相关测试。
- **可能完全错误的地方**: ~~变更 4（doc-quality hook）可能过早优化~~ 已替换为 skills 强化。Skills 强化的风险是依赖 AI 合规性，但这正是 harness 的本质。
- **排除的方案**: ~~考虑过用 pre-commit git hook 做文档质量检查~~ 变更 4（doc-quality.sh hook）被方案 D 替换：事后检查是 gate 思维，不如直接强化 skills。

## Todo

- [ ] 1. 创建 `_common.sh` | Files: `.baton/hooks/_common.sh` (新增) | Verify: `sh .baton/hooks/_common.sh` 可 source 且定义 resolve_plan_name + find_plan | Deps: none | Artifacts: none
- [ ] 2. 迁移 8 个 hooks 使用 `_common.sh` | Files: write-lock.sh, phase-guide.sh, stop-guard.sh, bash-guard.sh, post-write-tracker.sh, completion-check.sh, pre-compact.sh, subagent-context.sh | Verify: 每个 hook 单独运行无报错；`bash tests/test-write-lock.sh` + `bash tests/test-phase-guide.sh` + `bash tests/test-stop-guard.sh` 通过 | Deps: #1 | Artifacts: none
- [ ] 3. 迁移 pre-commit 使用 `_common.sh` | Files: `.baton/git-hooks/pre-commit` | Verify: `bash tests/test-pre-commit.sh` 通过 | Deps: #1 | Artifacts: none
- [ ] 4. 更新 setup.sh 安装 `_common.sh` | Files: `setup.sh` | Verify: `bash tests/test-setup.sh` 通过 | Deps: #1 | Artifacts: none
- [ ] 5. 更新 test-workflow-consistency.sh 验证策略 | Files: `tests/test-workflow-consistency.sh` | Verify: `bash tests/test-workflow-consistency.sh` 通过 | Deps: #2 | Artifacts: none
- [ ] 6. 修复 OpenCode 插件 glob fallback | Files: `.baton/adapters/opencode-plugin.mjs` | Verify: 手动验证 `plan-topic.md` 能被发现 | Deps: none | Artifacts: none
- [ ] 7. 修复 CI 配置 | Files: `.github/workflows/ci.yml` | Verify: ci.yml 语法正确（`yamllint` 或目视检查）；无引用已删除文件 | Deps: none | Artifacts: none
- [ ] 8. 强化 baton-research skill 自检清单 | Files: `.claude/skills/baton-research/SKILL.md` | Verify: 目视确认自检清单在 Exit Criteria 之前 | Deps: none | Artifacts: none
- [ ] 9. 强化 baton-plan skill 自检清单 | Files: `.claude/skills/baton-plan/SKILL.md` | Verify: 目视确认自检清单在输出模板之前 | Deps: none | Artifacts: none
- [ ] 10. 强化 baton-implement skill 自检步骤 | Files: `.claude/skills/baton-implement/SKILL.md` | Verify: 目视确认每个 todo 完成后有自检步骤 | Deps: none | Artifacts: none
- [ ] 11. 同步 skills 到 `.agents/skills/` fallback | Files: `.agents/skills/baton-research/SKILL.md`, `.agents/skills/baton-plan/SKILL.md`, `.agents/skills/baton-implement/SKILL.md` | Verify: diff 确认一致 | Deps: #8, #9, #10 | Artifacts: none
- [ ] 12. 运行完整测试套件 | Files: none | Verify: 所有 test-*.sh 通过 | Deps: #2, #3, #4, #5, #6, #7 | Artifacts: none

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注 -->
[Q]
   1.还有更好的方案吗

## Annotation Log

### Round 1

**[Q] § 方案选择**
"还有更好的方案吗"

-> **有。方案 B 的变更 4（doc-quality.sh）与 harness engineering 理念矛盾。**

doc-quality.sh 是事后检查（PostToolUse 验证 research.md 是否有 Self-Review），这是 gate 思维。Skills 已包含所有要检查的项：Self-Review (baton-research:103-108, baton-plan:71-74)、批注区 (baton-research:203, baton-plan:192-202)、file:line (baton-research:124)。

真正的 harness 是过程塑造：强化 skills 本身，增加退出前自检清单，让 AI 在写文档的过程中就做对，而非写完后被 hook 检查。

新增方案 D：技术债清理 + Skills 强化（不新增 hook）。推荐修正为方案 D。

-> Result: 推荐修正为方案 D

1. 这个计划需要重新研究了
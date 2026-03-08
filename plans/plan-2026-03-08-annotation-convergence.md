# 计划：Baton 循环批注基础收敛

## 参考文档

- `research.md`：研究结论已经确认三类短期问题是 SYNCED 代码复制、OpenCode `plan-*.md` 缺失、CI 覆盖缺口（research.md:332-336）
- `research.md`：项目核心已重新锚定为“循环批注”，Harness 应服务于循环，其中既包括认知缰绳，也包括质量评估（research.md:456-459,474-520）

## 复杂度判断

- **建议复杂度：Large**
- 理由：该计划会触及 10+ 文件，横跨 hooks、git hook、adapter、setup、CI、tests、skills，符合 Baton 对 Large 的定义（.baton/workflow.md:21-27）

## 问题陈述

当前代码库里，真正阻碍下一步演进的不是“大方向不清楚”，而是**基础设施与核心方向没有收敛**：

1. 计划解析逻辑被手工复制到多个脚本里，当前至少能在 `write-lock.sh`、`phase-guide.sh`、`pre-commit` 看到同类实现（.baton/hooks/write-lock.sh:61-81, .baton/hooks/phase-guide.sh:58-81, .baton/git-hooks/pre-commit:20-34），research 也已确认这是跨 9 个位置的维护风险（research.md:148-181,334）
2. OpenCode 插件只认固定 `plan.md`，而 shell 路径会回退到最新的 `plan-*.md`，行为已经分叉（.baton/adapters/opencode-plugin.mjs:12-21, .baton/hooks/write-lock.sh:61-81, research.md:270-283,335）
3. CI 仍在 lint 已删除的 `adapter-windsurf.sh`，同时没有运行与这次改动直接相关的多 IDE、pre-commit、新 hooks 测试（.github/workflows/ci.yml:10-75, research.md:287-307,336）
4. research 已把 Baton 核心定义为“循环批注”，并把 Harness 细分为认知缰绳、质量评估、连续性缰绳；因此新计划不能再落回“只修技术债”或“只谈 skills、不做质量反馈”的单边方案（research.md:456-459,474-520）

## 约束

1. **POSIX `sh` 兼容必须保留**：现有 hooks 以 `#!/bin/sh` 为前提，`write-lock.sh` 和 `phase-guide.sh` 都按该约束实现（.baton/hooks/write-lock.sh:1-14, .baton/hooks/phase-guide.sh:1-10）
2. **零外部依赖必须保留**：`write-lock.sh` 目前在有 `jq` 时使用 `jq`，没有时回退到 `awk`，说明 jq 不能变成硬依赖（.baton/hooks/write-lock.sh:32-43）
3. **Fail-open 不能被新方案破坏**：关键 hooks 明确在异常时放行而不是阻断工作（.baton/hooks/write-lock.sh:13-20, .baton/hooks/phase-guide.sh:9-10）
4. **安装与自安装路径要继续工作**：`setup.sh` 通过 `install_versioned_script`、`install_skills` 向项目复制 hooks 与 skills，新文件必须进入这套分发路径（setup.sh:703-749,762-804）
5. **计划必须仍然是实现合同**：本阶段只写 plan，不追加 `BATON:GO`，也不生成 `## Todo`（.baton/workflow.md:29-37, .agents/skills/baton-plan/SKILL.md:99-120）

## 方案分析

### 方案 A：只清理技术债

**内容**：
- 抽取 `_common.sh`
- 修复 OpenCode fallback
- 修复 CI 与测试缺口

**可行性**：✅ 高

**优点**：
- 风险最低，diff 边界清晰
- 直接解决 research 已确认的三项具体问题（research.md:332-336）

**缺点**：
- 与 research 对“循环批注是核心、Harness 要服务于循环”的结论不匹配（research.md:474-520）
- 只改善维护性，不改善进入批注循环前的文档质量反馈

### 方案 B：技术债清理 + 只强化 skills

**内容**：
- 保留方案 A
- 仅增强 `baton-research` / `baton-plan` 的退出前自检

**可行性**：✅ 高

**优点**：
- 跨 IDE 一致，且现有安装器已经把 `.claude/skills` 复制到 IDE 目录和 `.agents/skills` fallback（setup.sh:762-804）
- 对运行时行为零侵入

**缺点**：
- research 对方向 D 的定义并不只有认知缰绳，还明确包含“质量评估”自动检查（research.md:456-459,517-520）
- 对已经具备 `PostToolUse` / `post_write_code` 的通道没有任何利用，无法给文档质量即时反馈（.claude/settings.json:37-46, setup.sh:976-980,1180-1195）

### 方案 C：技术债清理 + 最小可行 Harness 基础（推荐）

**内容**：
- 保留方案 A
- 增加一个**advisory** 的 `doc-quality.sh`，只检查 `research*.md` / `plan*.md`
- 同时补强 `baton-research` / `baton-plan` 的退出前自检，并同步 `.agents/skills` fallback

**可行性**：✅ 中高

**优点**：
- 与 research 的方向一致：同时覆盖认知缰绳和质量评估，而不是二选一（research.md:456-459,517-520）
- 复用现有 PostToolUse / post_write_code 通道，无需引入新的事件模型（.claude/settings.json:37-46, setup.sh:976-980,1180-1195）
- 仍然保持 advisory + fail-open，不把质量检查升级成硬门禁

**缺点**：
- 比 skills-only 多一个 hook 与测试面
- 文档质量检查天然是启发式，存在噪声风险，需要把规则压到“低误报”

## 推荐方案

**推荐采用方案 C：技术债清理 + 最小可行 Harness 基础。**

推荐理由：

1. 它完整承接了 research 的两层结论：先解决三项已确认技术债，再把 Harness 往循环批注核心上靠（research.md:332-336,474-520）
2. 它不把 `doc-quality.sh` 当 gate，而是当质量评估 harness；这与 research 的方向 D 一致，而不是与之对立（research.md:456-459）
3. 它利用了代码库里已经存在的安装和 hook 面：Claude 的 `PostToolUse`、Windsurf 的 `post_write_code`、skills 分发到 `.agents/skills` fallback 的机制都已存在（.claude/settings.json:37-46, setup.sh:762-804,976-980,1180-1195）
4. 它仍然把范围压在一次可控的 Large 变更里，没有跳到“重写 setup 架构”或“调整 11 IDE 支持策略”的更大决策

## 变更清单

### 变更 1：抽取 `.baton/hooks/_common.sh`

**What**

创建 `.baton/hooks/_common.sh`，收敛两段共享逻辑：
- `resolve_plan_name`
- `find_plan`

由以下文件改为通过 POSIX `.` 引入，而不是继续手工复制：
- `.baton/hooks/write-lock.sh`
- `.baton/hooks/phase-guide.sh`
- `.baton/hooks/stop-guard.sh`
- `.baton/hooks/bash-guard.sh`
- `.baton/hooks/post-write-tracker.sh`
- `.baton/hooks/completion-check.sh`
- `.baton/hooks/pre-compact.sh`
- `.baton/hooks/subagent-context.sh`
- `.baton/git-hooks/pre-commit`

同时更新 `setup.sh` 的安装列表，让 `_common.sh` 被复制到目标项目（setup.sh:703-749,1404-1407）。

**Why**

这一步直接消除 research 识别出的最大维护风险：同一 plan 解析逻辑分散在多个脚本里（research.md:148-181,334）。

**Impact**

- 新增：`.baton/hooks/_common.sh`
- 修改：上述 8 个 hooks + `pre-commit`
- 修改：`setup.sh`
- 修改：`tests/test-workflow-consistency.sh`
- 修改：与 plan 解析相关的回归测试：`tests/test-write-lock.sh`、`tests/test-phase-guide.sh`、`tests/test-stop-guard.sh`、`tests/test-pre-commit.sh`

**Risks + Mitigation**

- 风险：source 路径在不同工作目录、git worktree、符号链接场景下出错
- 缓解：每个调用脚本显式计算自己的 `SCRIPT_DIR` 后再 `.` 引入；测试覆盖 `BATON_PLAN`、嵌套目录、无 plan 场景

### 变更 2：修复 OpenCode 的 plan 发现逻辑

**What**

调整 `.baton/adapters/opencode-plugin.mjs`，让它与 shell 路径保持同一顺序：
- 优先 `BATON_PLAN`
- 否则在当前目录选择最新的 `plan.md` / `plan-*.md`
- 然后按目录向上查找

**Why**

当前插件只认固定 `plan.md`，与 shell hooks 已经分叉（.baton/adapters/opencode-plugin.mjs:12-21, .baton/hooks/write-lock.sh:61-81）。

**Impact**

- 修改：`.baton/adapters/opencode-plugin.mjs`
- 修改：`tests/test-adapters.sh`，新增对 `plan-*.md` fallback 的针对性断言

**Risks + Mitigation**

- 风险：JS 的排序结果与 `ls -t` 不完全等价
- 缓解：按 `mtime` 降序排序，并在测试里覆盖“同时存在 `plan.md` 与 `plan-foo.md`”的选择逻辑

### 变更 3：修复 CI 并补齐本次改动相关回归面

**What**

- 移除 `.github/workflows/ci.yml` 中对已删除 `adapter-windsurf.sh` 的 shellcheck
- 将以下测试加入 CI：
  - `tests/test-multi-ide.sh`
  - `tests/test-pre-commit.sh`
  - `tests/test-new-hooks.sh`

**Why**

这三块正好覆盖本计划会动到的安装、pre-commit、advisory hooks 路径；继续缺失会让回归无法被 CI 捕获（.github/workflows/ci.yml:10-75, research.md:287-307）。

**Impact**

- 修改：`.github/workflows/ci.yml`

**Risks + Mitigation**

- 风险：CI 时长增加
- 缓解：优先保持单 OS 跑 `test-multi-ide.sh`，只把最相关的缺口补上，不一次性把全部未接入测试都拉进来

### 变更 4：新增最小可行的 `doc-quality.sh`

**What**

新增 `.baton/hooks/doc-quality.sh`，仅对 `research*.md` / `plan*.md` 输出 advisory 警告，不阻断写入。检查项限定为低误报的结构性规则：

- 对 `research*.md`：
  - 是否存在 `## Self-Review`
  - 是否存在 `## Questions for Human Judgment`
  - 是否存在 `## 批注区`
  - 是否至少包含基础数量的 `file:line` 证据引用
- 对 `plan*.md`：
  - 是否存在 `## Self-Review`
  - 是否存在明确的方案分析与推荐段落
  - 是否存在 `## 批注区`
  - 是否在 `## 批注区` 后继续追加正文

将该 hook 接入已有 post-write 通道：
- 本仓库的 `.claude/settings.json`
- `setup.sh` 中的 `configure_claude`
- `setup.sh` 中的 `configure_windsurf`

**Why**

research 已把“质量评估”列为 Harness 的组成部分，而当前仓库已经具备可复用的 post-write 入口（research.md:456-459,517-520; .claude/settings.json:37-46; setup.sh:976-980,1180-1195）。

**Impact**

- 新增：`.baton/hooks/doc-quality.sh`
- 修改：`.claude/settings.json`
- 修改：`setup.sh`
- 修改：`tests/test-new-hooks.sh`
- 修改：`tests/test-multi-ide.sh`

**Risks + Mitigation**

- 风险：启发式检查带来噪声，分散 AI 注意力
- 缓解：只检查 `research*.md` / `plan*.md`；只做结构性 sanity-check；默认静默，只有缺项时才输出

### 变更 5：补强技能自检并保持 fallback 一致

**What**

在以下 skills 中加入简短、可执行的退出前自检：
- `.claude/skills/baton-research/SKILL.md`
- `.claude/skills/baton-plan/SKILL.md`

并同步到：
- `.agents/skills/baton-research/SKILL.md`
- `.agents/skills/baton-plan/SKILL.md`

本次不扩展 `baton-implement`，因为当前问题集中在 research / plan 进入批注循环前的文档质量，而不是实现后阶段。

**Why**

`setup.sh` 已把 `.claude/skills` 当 canonical source，并向 `.agents/skills` fallback 复制；如果只改一侧，当前仓库与安装后的行为会分叉（setup.sh:762-804）。

**Impact**

- 修改：`.claude/skills/baton-research/SKILL.md`
- 修改：`.claude/skills/baton-plan/SKILL.md`
- 修改：`.agents/skills/baton-research/SKILL.md`
- 修改：`.agents/skills/baton-plan/SKILL.md`
- 修改：`tests/test-workflow-consistency.sh`（若需要补充对 skill 关键字的一致性检查）

**Risks + Mitigation**

- 风险：skills 变得更长，反而削弱可读性
- 缓解：只加 3-4 条退出前 checklist，不重写整份 skill

## 范围外

- 不重写 `setup.sh` 的整体架构
- 不调整 11 个 IDE 的支持策略分级
- 不修改 `write-lock.sh` 的 fail-open 与 markdown 豁免设计
- 不引入新的外部依赖或服务

## 验证策略

实施完成后，至少需要通过：

- `bash tests/test-write-lock.sh`
- `bash tests/test-phase-guide.sh`
- `bash tests/test-stop-guard.sh`
- `bash tests/test-pre-commit.sh`
- `bash tests/test-new-hooks.sh`
- `bash tests/test-adapters.sh`
- `bash tests/test-multi-ide.sh`

并补做一次目视核对：
- `.github/workflows/ci.yml` 不再引用 `adapter-windsurf.sh`
- `.claude/settings.json` 中的 post-write 配置包含 `doc-quality.sh`
- `plan.md` 与 `research.md` 最终都能在 `## 批注区` 结束

## Self-Review

- **最大风险**：`doc-quality.sh` 的规则如果写得太“格式模板化”，会让质量评估变成噪声源，而不是 harness
- **可能使本计划完全错误的前提**：如果你判断 research 里的“质量评估 harness”不该进入当前迭代，而应完全延后，那么推荐方案应退回方案 B
- **被排除的替代方案**：skills-only 很诱人，但它切掉了 research 已明确提出的质量评估层，导致计划与研究之间再次断链

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注 -->

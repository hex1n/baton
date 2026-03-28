# 执行计划: Baton Skill 插件市场

**深度**: Deep -- 这是一个在现有架构上叠加全新子系统的需求。v5 flat install 架构的分发模型、skill 发现机制、CLI 入口都需要重新审视。先前 iteration-2 的方案基于已废弃的 v4 junction 模型，需要完全重构。

**输入源**: `setup.sh`、`install.sh`、`bin/baton`、`hooks/dispatch.sh`、`hooks/manifest.conf`、`hooks/lib/plan-parser.sh`（`parser_has_skill`）、`skills/*/SKILL.md` 结构、`README.md`、`docs/first-principles.md`、`docs/stable-surface.md`、iteration-2 prior plan。

---

## Phase 1: Problem Archaeology

### 1.1 -- Five Whys

```
陈述: "添加一个插件市场，让用户可以共享和安装 skills"
Why?   → 用户创建了有用的 skills 但只能本地使用
Why?   → 分发模型是 ~/.baton/skills/ → ~/.claude/skills/ 的符号链接，
         ~/.baton/ 克隆自单一 git repo（hex1n/baton）
Why?   → v5 flat install 将 baton 源代码和 skills 绑定在同一个 git repo 中。
         所有项目共享同一份 skills，但只有 baton 仓库中打包的 skills 才能被安装
Why?   → Skill 最初被设计为 baton 治理层的实现机制，不是独立的可分发单元
Root:    Skills 已经演变为用户可感知的一等功能（用户创建了 deep-research、
         first-principles-planner、verify 等非 baton 核心 skills），但分发基础设施
         仍然将它们视为 baton 内部实现。缺乏发现、安装、版本管理的标准化机制。
```

### 1.2 -- 问题陈述

**不理想状态**: Baton skills 是可移植的 markdown 单元（含 SKILL.md 的目录），但在 baton 内置 skills 之外，没有发现、安装或版本管理机制。自定义 skills 的作者没有标准化的共享方式，想要新 skills 的用户没有搜索目录。

**受影响者**: Skill 作者（无法共享）和 skill 消费者（无法发现）。

**"解决了"意味着**: 用户可以通过简单 CLI 命令发现、安装、更新和卸载第三方 skills，skill 作者可以以最小摩擦发布，且不引入编译依赖或破坏 v5 flat install 架构。

### 1.3 -- 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|------------|
| 1 | Skills 始终是含 SKILL.md 的目录 | ✅ 事实（验证: 所有 `skills/` 下的 skill 均遵循此模式） | 方案崩溃 -- 打包模型需要重新设计 |
| 2 | v5 中 skills 只需存在于 `~/.claude/skills/` | ✅ 事实（验证: `setup.sh` 只创建 `~/.claude/skills/` 符号链接；`parser_has_skill` 最后 fallback 到 `$HOME/.claude/skills/`） | 方案不受影响 -- 简化为单目标 |
| 3 | v4 junction 机制（`atomic_junction`、`junction.sh`）已完全移除 | ✅ 事实（验证: grep `atomic_junction\|junction.sh` 在非 worktree 源码中零命中；`setup.sh` 只用 `ln -sf`） | 方案需要恢复 junction 支持 |
| 4 | "插件市场"需要集中式服务器/注册中心 | **惯例** | 方案受益 -- 更简单方式存在 |
| 5 | baton 必须保持纯 bash + markdown，零编译依赖 | ✅ 事实（设计原则: jq 可选，有 sed 回退） | 方案崩溃 -- 需要允许 npm/pip 等 |
| 6 | 用户需要一个可浏览的目录（Web UI） | **惯例** | 方案不受影响 -- CLI 发现初期足够 |
| 7 | Skill 版本管理很重要 | **未知** -- skills 目前是无版本的 markdown 文件 | 方案弱化（用户困在损坏版本上） |
| 8 | Community skills 需要与 bundled skills 隔离存储 | **约束** -- 混合存储会污染 baton 源 git 仓库 | 方案可简化但带来维护风险 |
| 9 | `baton update`（`git pull --ff-only`）是唯一的更新路径 | ✅ 事实（验证: `bin/baton` `update` 命令和 `install.sh`） | 需要额外更新路径 |

### 1.4 -- 真约束 vs 惯例

**真约束**:
- 纯 bash + markdown。无编译依赖。jq 可选（`setup.sh` 有 sed/awk fallback 模式，但当前 marketplace 的 JSON 解析可依赖 jq，因为 setup.sh 本身已依赖 jq）。✅ 验证: `setup.sh:84` 检查 `command -v jq`
- 必须在 Windows（Git Bash）、macOS、Linux 上工作
- Skills 是含 SKILL.md 的目录
- v5 架构: user-level flat install，`~/.claude/skills/` 中的符号链接指向源目录。零项目级占用
- `parser_has_skill` 从项目目录向上遍历 `.claude/.cursor/.agents/skills/`，最后检查 `~/.claude/skills/`。✅ 验证: `plan-parser.sh:204-219`
- `setup.sh` 的 `discover_skills` 只扫描 `$BATON_DIR/skills/`。✅ 验证: `setup.sh:28-35`

**惯例（可挑战的）**:
- "所有 skills 来自 baton repo" -- 第三方 skills 可来自独立 git repos
- "Skills 无版本号" -- SKILL.md frontmatter 中的 `version` 字段可启用版本追踪
- "`~/.baton/` 是唯一 skill 源" -- 一个单独的 `~/.baton/community/` 目录可存放第三方 skills
- "发现需要知道作者/repo" -- 简单索引文件可充当目录
- "`setup.sh` 只链接 `$BATON_DIR/skills/`" -- 可扩展为也链接 community skills

**Phase Gate**: 根问题清晰 -- skills 是可分发单元但缺乏分发渠道。v5 架构约束明确。可进入 Solution Design。

---

## Phase 2: Solution Reconstruction

### 2.1 -- 方案类别

#### 类别 A: Git-Based Registry（Homebrew Tap 模型）

**机制**: 一个独立 git repo 作为"注册中心" -- 包含 `index.json` 映射 skill 名称到 git repo URL + 元数据。`baton skill search` 从缓存索引搜索。`baton skill install <name>` 将 skill repo 克隆到 `~/.baton/community/<name>/`，然后 `setup.sh`（或 install 命令自身）在 `~/.claude/skills/` 创建符号链接。无需服务器。

**最佳情况**: 零基础设施成本。初次克隆后完全离线可用。Git 自然处理版本管理（tags/branches）。任何用户可 fork 注册中心创建私有目录。与 baton 的 git-based 分发模型完美对齐。

**失败情况**: 注册中心 repo 被弃用，forks 碎片化生态。Windows git clone 延迟（~2-5s/skill）。

**挑战的惯例**: 打破 "所有 skills 来自 baton repo" 和 "skills 无版本号"。

#### 类别 B: GitHub API 直接搜索（无注册中心）

**机制**: 使用 GitHub API（via `curl`）搜索带特定 topic tag（如 `baton-skill`）的 repos。安装直接克隆。完全去中心化。

**最佳情况**: 零注册中心维护。Skill 作者只需给 repo 打标签。GitHub 处理搜索、stars、描述。

**失败情况**: 每次搜索需要网络。GitHub 速率限制（未认证 60 req/hr）。绑定 GitHub。搜索质量取决于 GitHub 算法。无策展。

**挑战的惯例**: 打破 "离线优先" 能力。引入 GitHub API 运行时依赖。

#### 类别 C: 纯本地 + 手动 URL 安装（无注册中心）

**机制**: 不建注册中心。`baton skill install <git-url>` 直接从任意 git URL 克隆。发现靠 README/口碑/GitHub search。保持最小化。

**最佳情况**: 实现最简单。无注册中心维护。完全去中心化。与 baton 的极简哲学一致。

**失败情况**: 无发现机制。用户需要知道 URL。无法搜索。类似于让人直接用 `git clone` -- 几乎不算 "市场"。

**挑战的惯例**: 几乎不挑战任何惯例 -- 但也几乎不解决发现问题。

### 2.2 -- 反转测试（Leading Candidate: A）

**类别 A（Git-Based Registry）**:

| 反转问题 | 回答 |
|---------|------|
| 最坏情况？ | Registry repo 被弃用，无人提交 PR。缓解: 自动 CI 验证 SKILL.md 存在；index 内嵌于 baton repo 引导启动 |
| 相反做法？ | 类别 C（无注册中心）。优点: 更简单。但失去发现和策展。 |
| 如果失败学到什么？ | Baton 社区太小不足以支撑独立注册中心 -- 回退到 index 内嵌于 baton repo |
| 会改变 baton 的核心身份吗？ | 不会 -- baton 仍然是治理协议，marketplace 是独立子系统 |

### 2.3 -- 推荐: 类别 A（Git-Based Registry），以类别 C 为最小可行产品引导

**推理链**:

1. **根问题**: Skills 是可分发单元，缺乏分发渠道。（Phase 1）
2. **v5 架构约束**: User-level flat install。Skills 在 `~/.claude/skills/` 通过符号链接访问。`setup.sh` 用 `ln -sf`，不再用 junction。✅ 验证: `setup.sh:38-53`
3. **v5 关键变化（vs iteration-2 方案）**:
   - 不再有 per-project skill junctions -- skills 是 user-level 的
   - 不再有 `junction.sh` / `atomic_junction` -- 直接 `ln -sf`
   - `setup.sh` 的 `discover_skills` 只扫描 `$BATON_DIR/skills/` -- 需要扩展
   - Community skills 需要与 bundled skills 平等存在于 `~/.claude/skills/`
4. **两阶段实施**:
   - **Phase I (MVP)**: 类别 C -- `baton skill install <git-url>` 从任意 URL 安装。无注册中心。解决"能安装"问题。
   - **Phase II**: 类别 A -- 添加 `index.json` 注册中心，`baton skill search`。解决"能发现"问题。
5. **为什么分两阶段**: Phase I 的价值独立于注册中心是否存在。即使注册中心永远没人用，直接 URL 安装仍有价值。注册中心是加法，不是前提。
6. **与 v5 的对齐**: Community skills 存放在 `~/.baton/community/<name>/`，`setup.sh` 的 `install_skills` 扩展为也链接 community skills 到 `~/.claude/skills/`。`baton skill install` 直接创建符号链接，无需 `setup.sh` 介入。

### 2.4 -- 异议路径

如果用户的意图是"一个可浏览的 Web 市场"（带评分、截图、下载数）:

- **什么条件下合理**: 100+ skills，非技术用户，商业化意图
- **如果仍要做**: 将注册中心 `index.json` 作为数据源，GitHub Pages 生成静态站。CLI 计划不变。Web 层是附加的。

---

## Phase 3: Plan Synthesis

### 方法

基于 v5 flat install 架构的 skill 市场，实现为:

1. **Skill manifest 规范** -- SKILL.md frontmatter 增加 `version`、`author`、`repository` 字段
2. **Community skill 目录** -- `~/.baton/community/` 存放第三方 skills
3. **CLI 命令** -- `baton skill install|remove|list|search|update|publish` 在 `bin/baton` 中
4. **符号链接集成** -- community skills 像 bundled skills 一样符号链接到 `~/.claude/skills/`
5. **注册中心** -- `index.json` 初始内嵌于 baton repo，后期可迁移到独立 repo

### 步骤

| # | 步骤 | 为什么这个顺序 | 工作量 | 成功标准 |
|---|------|--------------|--------|---------|
| 1 | 定义 skill manifest 规范 -- SKILL.md frontmatter 增加 `version`、`author`、`repository` 字段 | 基础: 后续所有步骤依赖于能识别和版本化 skill | 1h | 现有 baton skills 有合法 frontmatter；规范文档定义必需/可选字段 |
| 2 | 创建 `~/.baton/community/` 目录结构 | Community skills 需要隔离存储空间 | 0.5h | 目录存在；`.gitignore` 忽略此目录 |
| 3 | 扩展 `setup.sh` 的 `discover_skills` 和 `install_skills` 以扫描 community 目录 | Community skills 必须与 bundled skills 一样被符号链接到 `~/.claude/skills/` | 2h | `setup.sh` 运行后 community skills 出现在 `~/.claude/skills/`；`parser_has_skill` 自动发现它们（无需修改 -- 已检查 `~/.claude/skills/`） |
| 4 | 实现 `baton skill install <git-url-or-name>` | 核心价值: 一条命令安装 skill | 3h | `baton skill install https://github.com/user/skill-name` 克隆到 `~/.baton/community/skill-name/`，创建 `~/.claude/skills/skill-name` 符号链接；幂等（重装则更新） |
| 5 | 实现 `baton skill remove <name>` | 用户需要清洁卸载 | 1h | 移除 `~/.baton/community/<name>/` 和 `~/.claude/skills/<name>` 符号链接；不触及 bundled skills |
| 6 | 实现 `baton skill list` | 用户需要查看已安装的 skills | 1h | 分两组列出 bundled 和 community skills，含版本和来源 |
| 7 | 创建 `marketplace/index.json` schema 和种子数据 | 注册中心格式必须先于搜索命令存在 | 1h | 合法 JSON schema；条目含 name、version、description、author、repository、tags |
| 8 | 实现 `baton skill search [query]` | 用户需要发现能力 | 2h | `baton skill search research` 找到匹配 skills；离线搜索缓存索引；无 query 列出全部 |
| 9 | 实现 `baton skill update [name]` | Community skills 需要更新路径 | 1.5h | `baton skill update` 对每个 `~/.baton/community/<name>/` 执行 `git pull`；可指定名称更新单个 |
| 10 | 修改 `baton update` 以同时刷新 community skills | `baton update` 已刷新 bundled skills；community 应一致 | 0.5h | `baton update` 在 `git pull` 后遍历 community skills |
| 11 | 实现 `baton skill publish`（辅助工具） | 作者需要低摩擦的发布路径 | 2h | 验证 SKILL.md frontmatter，生成 index entry JSON，打印提交到注册中心的说明 |
| 12 | 扩展 `baton doctor` 检查 community skills 健康度 | 诊断工具需要覆盖新子系统 | 1h | `baton doctor` 报告 community skills 数量、损坏的符号链接 |
| 13 | 测试: `tests/test-marketplace.sh` | 新子系统的回归保护 | 3h | 覆盖: install、remove、list、search、update、符号链接创建、幂等性、错误情况 |

### 优先级表

| 优先级 | 变更 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P0 | 步骤 1-4: Manifest 规范 + community 目录 + setup 扩展 + install 命令 | 6.5h | 中 -- Windows git clone 需要测试 | **高** -- 核心市场价值（能安装） |
| P1 | 步骤 5-6: Remove + list | 2h | 低 | **中** -- 完整性 |
| P1 | 步骤 7-8: Registry + search | 3h | 中 -- index 格式设计影响长期 | **高** -- 核心发现价值 |
| P2 | 步骤 9-10: Update 集成 | 2h | 低 | **中** -- 生命周期管理 |
| P2 | 步骤 11-12: Publish + doctor | 3h | 低 | **中** -- 生态系统和诊断 |
| P2 | 步骤 13: 测试 | 3h | 低 | **高** -- 回归安全 |
| **合计** | | **19.5h** | | |

### 关键设计决策

#### D1: Community skills 存储位置

```
~/.baton/
├── skills/                    # Bundled（baton repo 管理，git tracked）
│   ├── baton-research/
│   ├── baton-plan/
│   └── ...
├── community/                 # Third-party（独立 git repos，git ignored）
│   ├── my-awesome-skill/
│   │   ├── .git/
│   │   └── SKILL.md
│   └── another-skill/
│       ├── .git/
│       └── SKILL.md
└── marketplace/               # Registry index
    └── index.json

~/.claude/skills/
├── baton-research -> ~/.baton/skills/baton-research   # Bundled
├── baton-plan -> ~/.baton/skills/baton-plan           # Bundled
├── my-awesome-skill -> ~/.baton/community/my-awesome-skill  # Community
└── another-skill -> ~/.baton/community/another-skill        # Community
```

**为什么 `~/.baton/community/` 而不是 `~/.claude/skills/` 直接克隆**:
- `~/.claude/skills/` 是消费层（符号链接），不是存储层
- 隔离存储确保 `baton update`（`git pull`）不会与 community skills 冲突
- 一个 community skill 的 `.git/` 和 baton 的 `.git/` 完全独立

#### D2: 命名空间保护

- Bundled skills 使用 `baton-*` 前缀
- Community skills 禁止使用 `baton-*` 前缀（install 时验证）
- 名称冲突时 install 报错，不覆盖

#### D3: v5 符号链接模型的复用

```bash
# install 命令核心逻辑（复用 setup.sh 的 ln -sf 模式）
_src="$COMMUNITY_DIR/$_name"
_dst="$HOME/.claude/skills/$_name"
if [ -L "$_dst" ]; then
    _target="$(readlink "$_dst" 2>/dev/null || true)"
    [ "$_target" = "$_src" ] && { echo "Already installed"; return; }
    rm -f "$_dst"
fi
ln -sf "$_src" "$_dst"
```

不需要 per-project junctions -- v5 架构中 skills 是 user-level 的。所有项目自动可见。

#### D4: 注册中心 index.json schema

```json
{
  "schema_version": 1,
  "updated": "2026-03-26",
  "skills": [
    {
      "name": "example-research-helper",
      "version": "1.0.0",
      "description": "Structured research templates for API integration analysis",
      "author": "example-user",
      "repository": "https://github.com/example-user/baton-skill-research-helper",
      "tags": ["research", "api"],
      "min_baton_version": "5.0"
    }
  ]
}
```

#### D5: SKILL.md frontmatter 规范扩展

```yaml
---
name: my-awesome-skill        # 必需（已存在于大多数 skills）
description: >                 # 必需（已存在于大多数 skills）
  Does something useful.
version: 1.0.0                # 新增，可选（默认 0.0.0）
author: username              # 新增，可选
repository: https://...       # 新增，可选（community skills 推荐）
tags: [research, analysis]    # 新增，可选
---
```

向后兼容: 现有 skills 无 `version`/`author` 字段仍可正常工作。`baton skill list` 对缺失字段显示 "-"。

#### D6: setup.sh 扩展

```bash
# 在现有 install_skills() 之后添加:
install_community_skills() {
    _community="$BATON_DIR/community"
    [ -d "$_community" ] || return 0
    for _d in "$_community"/*/; do
        [ -d "$_d" ] && [ -f "$_d/SKILL.md" ] || continue
        _name="$(basename "$_d")"
        _dst="$CLAUDE_DIR/skills/$_name"
        if [ -L "$_dst" ]; then
            _target="$(readlink "$_dst" 2>/dev/null || true)"
            [ "$_target" = "$_d" ] || [ "$_target" = "${_d%/}" ] && continue
            rm -f "$_dst"
        elif [ -d "$_dst" ]; then
            echo "  ⚠ $_dst exists as directory, skipping community skill $_name"
            continue
        fi
        ln -sf "${_d%/}" "$_dst"
    done
    _count="$(ls -d "$_community"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
    [ "$_count" -gt 0 ] && echo "  ✓ $_count community skill(s) linked"
}
```

### 安全模型

| 风险 | 影响 | 可能性 | 缓解 |
|------|------|--------|------|
| 恶意 SKILL.md（注入 prompt 指令 AI 泄露数据） | 高 -- skill 内容直接进入 AI context | 中 | `baton skill audit <name>` 在安装前显示 SKILL.md 内容；策展注册中心需要 PR review |
| Windows git clone 延迟（2-5s/skill） | UX 差 | 高 | `--depth 1`；批量安装时显示进度 |
| 注册中心过时/弃用 | 生态停滞 | 中 | Index 内嵌于 baton repo 引导；CI 自动验证条目可达 |
| Skill 名称冲突（community vs bundled） | 混淆，符号链接损坏 | 低 | `baton-*` 前缀保留给 bundled；install 时强制检查 |
| jq 依赖（搜索/index 解析） | 无 jq 系统上搜索不可用 | 中 | 提供 grep/awk fallback 用于基础搜索；install（仅需 git）不依赖 jq |
| Community skill 与 baton 版本不兼容 | 安装后 skill 不工作 | 低（初期） | `min_baton_version` 字段；install 时检查并警告 |

### 成功标准

1. `baton skill install https://github.com/user/skill-name` 将 skill 克隆到 `~/.baton/community/`，符号链接到 `~/.claude/skills/`，`parser_has_skill` 可发现
2. `baton skill search research` 从缓存索引找到匹配 skills
3. `baton skill list` 分组显示 bundled 和 community skills
4. `baton skill remove <name>` 清洁移除符号链接和源目录
5. `baton update` 同时刷新 bundled 和 community skills
6. `setup.sh` 重新运行时自动链接已安装的 community skills
7. 所有操作在 Windows（Git Bash）、macOS、Linux 上工作
8. 零新编译依赖 -- 纯 bash

### 我们刻意不做的

| 被拒方案 | 原因 |
|---------|------|
| **Web 市场 UI** | 无需求证据。后续可用 `index.json` 生成 GitHub Pages 静态站，零架构变更。 |
| **npm/pip 风格包管理器** | 违反纯 bash 约束。Skills 是目录不是包。git clone 是正确的原语。 |
| **Skill 依赖**（skill A 需要 skill B） | 复杂度不合理。Skills 是自包含 markdown。需要时可加 `dependencies` frontmatter 字段。 |
| **安装时自动更新** | 危险 -- 可能破坏已工作的配置。更新应显式。 |
| **付费/商业 skills** | 超出范围。如需要，在注册中心层面实现（私有注册中心）。 |
| **评分/评论系统** | 需要服务器基础设施。初始用 GitHub stars 代替。 |
| **Per-project skill 安装**（恢复 v4 junction 模式） | 与 v5 "零项目占用" 原则矛盾。如果某项目需要特定 skills，在项目 `.claude/skills/` 中手动链接。 |

### 自检: 这个计划最可能的失败模式是什么？

**最可能失败**: 注册中心冷启动问题 -- marketplace 空空如也没有 skills 可安装，导致功能无用。

**缓解**: Phase I（URL 直接安装）完全不依赖注册中心。用户可以直接安装 GitHub 上任何含 SKILL.md 的 repo。注册中心是可选增强。baton 团队在注册中心种子中加入 3-5 个高质量社区 skills 来引导。

**次可能失败**: 安全问题 -- 恶意 SKILL.md 被安装后注入 AI context。这在所有 skill 系统中都存在（包括现有的 `~/.claude/skills/` 手动安装模式），marketplace 只是降低了攻击门槛。`baton skill audit` 命令 + 注册中心 PR review 是合理的第一层防御。

### vs iteration-2 方案的关键差异

| 维度 | iteration-2 (v4) | 本方案 (v5) |
|------|-------------------|-------------|
| 链接机制 | `atomic_junction` (junction.sh) | `ln -sf`（与 setup.sh 一致） |
| 安装粒度 | Per-project（在 `.claude/skills/` `.cursor/skills/` `.agents/skills/` 各创建 junction） | User-level（仅 `~/.claude/skills/` 一个符号链接，所有项目共享） |
| 依赖的基础设施 | `junction.sh` 的 `atomic_junction` 函数 | 标准 `ln -sf`（无额外依赖） |
| CLI 命名 | `baton marketplace ...` | `baton skill ...`（更简洁） |
| 分阶段策略 | 一次性实施 | Phase I (URL install) → Phase II (registry + search) |
| setup.sh 修改 | 在 `init_skills` 中加 community 扫描 | 在 `install_skills` 后加 `install_community_skills` |

### 分析（Phase 1-2 推理记录）

1. v5 flat install 架构从根本上简化了 marketplace 设计 -- 不再需要 per-project junction，也不再需要处理多 IDE 目录。一个符号链接解决一切。
2. `parser_has_skill` 已经检查 `~/.claude/skills/` 作为 fallback（`plan-parser.sh:218`），所以 community skills 一旦符号链接到此处，无需修改任何 hook 即可被发现。这是 v5 架构的意外红利。
3. iteration-2 方案中的 junction 代码全部废弃。v5 删除了 `junction.sh`，不应恢复。
4. `baton skill` 比 `baton marketplace` 更简洁，且为未来其他 skill 管理命令（如 `baton skill create`）留出命名空间。
5. 安全模型是 marketplace 的核心开放问题。SKILL.md 直接注入 AI context，恶意内容可以绕过所有 baton 治理机制。`baton skill audit` 是必要的最小防御。

## 批注区

# 执行计划: Baton 插件市场

**深度**: Standard — 多种可行方案，需要明确最优路径。用户需求清晰（共享/安装 skills），但实现机制存在根本性选择。

**输入来源**: 用户请求 + 代码库实地验证（✅ `setup.sh`, `junction.sh`, `phase-guide.sh`, `manifest.conf`, `dispatch.sh`, skill 目录结构）

---

## TL;DR

**根本问题**: baton 的 skill 分发是单机的（`~/.baton/` junction 到项目），没有发现-获取-安装的跨用户通道。用户想共享自己写的 skill、安装别人的 skill，当前架构不支持。

**关键洞察**: baton 是纯 bash + markdown、零编译依赖的系统。插件市场不应引入服务端或数据库——应该利用 Git 仓库作为 registry，bash 脚本作为 CLI，skill 目录结构作为包格式。这样插件市场本身就是 baton 哲学的延伸。

**推荐方案**: 基于 Git 的去中心化 registry + `baton skill` CLI 子命令。一个公共 Git 仓库（如 `baton-skills`）作为索引，每个 skill 是独立仓库或单仓子目录。`baton skill install <name>` 拉取到 `~/.baton/skills/`，现有 junction 机制自动分发到项目。

---

## 行动计划

| 优先级 | 步骤 | 工作量 | 成功标准 |
|--------|------|--------|----------|
| P1 | 定义 skill 包格式规范 | 2h | SKILL.md frontmatter 包含 `version`, `author`, `license` 字段；有 `skill.conf` 元数据文件规范文档 |
| P2 | 创建 registry 索引仓库 | 3h | `baton-skills` 仓库含 `registry.conf` 索引文件，至少注册 2 个示例 skill |
| P3 | 实现 `baton skill` CLI 子命令 | 6h | `baton skill search/install/remove/list/publish` 五个子命令可工作 |
| P4 | 集成现有 junction 分发机制 | 2h | install 后 skill 自动出现在项目的 IDE skills 目录，无需手动 setup |
| P5 | 版本管理与更新机制 | 3h | `baton skill update` 可检测并拉取新版本，锁文件记录已安装版本 |
| P6 | 文档与发布流程 | 2h | README 含完整使用指南，`baton skill publish` 可提交 PR 到 registry |
| **合计** | | **~18h** | |

### P1: Skill 包格式规范

扩展现有 SKILL.md frontmatter，增加市场所需字段：

```yaml
---
name: my-awesome-skill
version: 1.0.0
description: >
  A skill that does something useful.
author: username
license: MIT
homepage: https://github.com/user/my-skill
min-baton-version: 4.0
tags: [planning, research]
---
```

同时在 skill 目录下添加可选的 `skill.conf`：

```conf
# skill.conf — 机器可读的元数据（供 registry 索引用）
name=my-awesome-skill
version=1.0.0
author=username
repo=https://github.com/user/my-skill
checksum=sha256:abc123...
```

**为什么两个文件**: SKILL.md frontmatter 是 IDE 消费的（给 AI 读），`skill.conf` 是 CLI 消费的（给 bash 脚本 parse，避免 YAML 解析依赖）。

### P2: Registry 索引仓库

创建 `baton-skills` 公共仓库，结构如下：

```
baton-skills/
├── registry.conf          # 所有已注册 skill 的索引
├── skills/
│   ├── deep-research/
│   │   └── skill.conf     # 指向源仓库 + 版本
│   ├── tdd-workflow/
│   │   └── skill.conf
│   └── ...
└── README.md
```

`registry.conf` 格式（纯文本，bash 可直接 grep/awk）：

```conf
# name:version:repo:description
deep-research:1.2.0:https://github.com/user/deep-research:Fork-based deep research with auto-evaluation
tdd-workflow:0.5.0:https://github.com/user/tdd-workflow:Test-driven development orchestrator
```

### P3: `baton skill` CLI 子命令

在现有 `setup.sh` 旁添加 `baton` CLI 入口脚本，skill 管理作为子命令：

```bash
# baton skill search <keyword>
# 从 registry.conf 搜索匹配的 skill
baton_skill_search() {
    local keyword="$1"
    local registry="$BATON_HOME/cache/registry.conf"
    _ensure_registry_cache
    grep -i "$keyword" "$registry" | while IFS=: read -r name ver repo desc; do
        printf "  %-25s v%-8s %s\n" "$name" "$ver" "$desc"
    done
}

# baton skill install <name>
# 克隆到 ~/.baton/skills/<name>，触发 junction 重建
baton_skill_install() {
    local name="$1"
    local registry="$BATON_HOME/cache/registry.conf"
    _ensure_registry_cache
    local repo
    repo="$(grep "^${name}:" "$registry" | head -1 | cut -d: -f3-4)"
    [ -z "$repo" ] && echo "Skill '$name' not found in registry" && return 1
    git clone --depth 1 "$repo" "$BATON_HOME/skills/$name"
    echo "$name" >> "$BATON_HOME/installed.conf"
    echo "✓ Installed $name — run 'baton setup' in your project to create junctions"
}
```

### P4: 集成现有 junction 机制

✅ 已验证：`phase-guide.sh:51-67` 在每次 SessionStart 时自动为 `.baton/skills/baton-*` 创建 junction。需要扩展这个逻辑：

- 修改 `phase-guide.sh` 中的 glob 从 `baton-*` 改为 `*/`（所有 skill 目录）
- 修改 `setup.sh` 中的 `compute_skill_names()` 包含第三方 skill
- `add_gitignore()` 需动态处理新安装的第三方 skill 名称

### P5: 版本管理

在 `~/.baton/` 下维护锁文件：

```conf
# ~/.baton/installed.conf — 锁文件
# name:version:repo:install_date
deep-research:1.2.0:https://github.com/user/deep-research:2026-03-23
```

`baton skill update` 对每个已安装 skill 执行 `git -C <path> pull --ff-only`，比较版本号后报告变更。

### P6: 发布流程

`baton skill publish` 从当前目录读取 `skill.conf`，生成 registry 条目，通过 `gh pr create` 向 `baton-skills` 仓库提交 PR。

---

## 风险与缓解

| 风险 | 影响 | 可能性 | 缓解 |
|------|------|--------|------|
| Skill 安全性——恶意 SKILL.md 可注入 prompt | 高——skill 内容直接进入 AI context | 中 | Registry 需 PR review 才能合并；安装时显示 skill 内容摘要供用户确认 |
| Git 依赖——用户可能在无 Git 环境中使用 | 中——install 功能不可用 | 低 | baton 本身通过 Git clone 分发（✅ `setup.sh:69`），Git 是事实依赖 |
| Registry 中心化单点故障 | 中——仓库不可用时无法搜索/安装 | 低 | 支持多 registry（`BATON_REGISTRIES` 环境变量）；已安装 skill 不受影响 |
| 版本冲突——不同项目需要同一 skill 不同版本 | 高——junction 指向同一份 | 中 | P5 阶段引入项目级 lockfile `baton-skills.lock`；长期考虑版本化目录 `~/.baton/skills/name@version/` |

---

## 我们刻意不做的事

1. **不建 Web 服务或数据库**: baton 的核心承诺是"零编译依赖"。市场用 Git 仓库 + bash 脚本实现，保持这个承诺。Web UI 可以后续作为可选层加上去，但核心功能不依赖它。

2. **不做运行时沙箱**: Skill 是 markdown prompt，不是可执行代码。它们的"攻击面"是 prompt injection，不是代码执行。沙箱解决不了 prompt 问题——review 才能。

3. **不搞自定义包管理协议**: 不发明新的包格式或传输协议。Git clone + 纯文本索引已经够用，用户已经熟悉这个心智模型。

4. **不做 skill 依赖树**: baton skill 是独立的 markdown 文件，不存在编译时依赖。如果 skill A 建议配合 skill B 使用，在 SKILL.md 的 `description` 里说明即可，不需要依赖解析器。

---

## Self-Check

1. **我是在质疑问题本身，还是只在质疑方案?**
   是的。我问了"为什么需要市场而不是直接 Git clone"——答案是发现性（discoverability）。手动 clone 需要知道 URL，市场提供搜索和索引。问题的根源不是"安装"（Git clone 已解决），而是"发现别人做了什么有用的 skill"。

2. **我有没有发现值得打破的惯例?**
   有。现有 `phase-guide.sh` 只自动 junction `baton-*` 前缀的 skill（✅ 第 55 行的 glob 是 `"$_skill_src"/baton-*`）。这个惯例需要打破——第三方 skill 不会以 `baton-` 开头，自动 junction 应覆盖所有 skill 目录。

3. **我推荐的是不是第一个想到的方案?**
   不是。我先考虑了 npm 风格的中心化 registry、S3 存储方案、以及纯 GitHub Releases 方案。Git 仓库索引方案胜出是因为它与 baton 的"纯 bash + 零依赖"约束完美匹配，且用户已有 Git（setup.sh 依赖它）。

4. **用户读完这个计划能预测会发生什么吗?**
   能。每个 P 级步骤有具体的文件变更、代码示例和成功标准。用户可以看到新增 `baton` CLI、修改 `phase-guide.sh` 的 glob、创建 `baton-skills` 仓库等具体动作。

5. **我愿意拿钱赌这个方案吗?**
   P1-P4（基础功能）——愿意。这是自然延伸，技术风险低。最薄弱环节是 P5 的版本管理：多项目共享 `~/.baton/skills/` 下同一 skill 的不同版本是个真实的架构张力，可能需要后续迭代解决（项目级 skill 目录 vs 全局共享）。

---

## 分析（支撑推理）

### 问题考古

**五个为什么**:

- 表述: "想添加插件市场让用户共享和安装 skills"
- 为什么? → 当前 skill 只能通过手动复制或 junction 从本地 `~/.baton/` 分发
- 为什么这是问题? → 用户创建了好用的 skill 但无法让其他人发现和使用
- 为什么无法发现? → 没有索引、没有搜索、没有标准化的分发渠道
- 根源: **skill 缺乏跨用户的发现和分发机制**——"市场"是一个解决方案类别，不是问题本身

**问题陈述**: baton 用户创建的 skill 只能在本机使用，无法被其他用户发现、评估和安装。解决 = 用户可以搜索、预览、一键安装社区 skill，且安装后自动集成到现有 junction 分发流程。

### 假设审计

| # | 假设 | 类型 | 如果错了... |
|---|------|------|------------|
| 1 | Skill 是自包含的目录（SKILL.md + 可选文件） | ✅ 事实——已验证目录结构 | 计划崩溃——包格式需要重新设计 |
| 2 | 用户有 Git | ✅ 事实——`setup.sh` 用 `git clone` 安装 baton 本身 | install 机制需替代方案（curl 下载 tarball） |
| 3 | 不能引入编译依赖 | 惯例，但是核心设计约束 | 可以用 Python/Node CLI——但会破坏 baton 的差异化定位 |
| 4 | `~/.baton/skills/` 是 skill 的唯一存放位置 | 惯例 | 可以支持项目级 skill 目录，解决版本冲突问题 |
| 5 | Junction 分发足以覆盖所有 IDE | ✅ 事实——`setup.sh` 已覆盖 claude/cursor/codex/factory | 计划存活——junction 只是分发机制的一层 |

**真约束**: 纯 bash 实现、Git 可用、skill 是目录+markdown、junction 分发链已存在。
**惯例（可打破）**: `baton-*` 前缀限制、全局唯一版本、无元数据标准。

### 方案重建

**考虑过的方案类别**:

1. **Git 仓库 registry**（推荐）——索引是纯文本文件在 Git 仓库中，CLI 用 bash 实现。优势：零新依赖，与 baton 哲学一致。劣势：无 Web 搜索界面（可后加）。

2. **GitHub Releases + API**——每个 skill 是独立仓库，用 GitHub API 搜索 topic 标签。优势：无需中心 registry。劣势：依赖 `gh` CLI 或 curl + JSON 解析，搜索质量依赖 GitHub。

3. **npm/pip 风格中心化 registry**——搭建服务端。优势：丰富的搜索/排序/评分。劣势：需要服务器、需要 curl + JSON 解析、违反零依赖原则。

**反转测试（方案 1）**:
- 最坏情况: registry 仓库无人维护，skill 质量参差不齐。缓解：PR review + 社区评分机制（后续迭代）。
- 反面方案（完全去中心化，无 registry）: 用户只能靠 URL 分享。有一定价值（简单），但牺牲了发现性——这恰恰是要解决的根本问题。
- 失败时学到什么: 如果纯文本索引扩展性不够，可以迁移到 JSON/SQLite 索引，CLI 接口不变。

**推荐链**: 根本问题是发现性 → 需要索引 → 索引需要存储 → Git 仓库是 baton 生态中最自然的存储 → bash CLI 是最自然的交互方式 → junction 机制已存在，安装后自动分发。每一步都追溯到 Phase 1 的约束和根因。

## 批注区

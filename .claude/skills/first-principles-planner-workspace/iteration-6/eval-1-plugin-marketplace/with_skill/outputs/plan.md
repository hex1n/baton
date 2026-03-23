# Baton 插件市场执行计划

**深度**: Standard — 多个可行方案，且涉及分发模型、安全模型、向后兼容等交叉问题，需要完整分析。

**输入**: baton 代码库 (`C:\Users\hexin\IdeaProjects\baton`)

---

## TL;DR

**问题**: baton 的 skills 目前只能通过手工复制或 junction 从 `~/.baton/` 分发到项目，没有发现、共享、版本管理的机制。用户无法像 `npm install` 或 `brew install` 那样一键获取社区 skill。

**核心洞察**: baton 的架构已经具备了插件市场的基础设施 —— skill 就是一个包含 `SKILL.md` 的目录，`junction.sh` 已经解决了跨平台链接，`setup.sh` 已经有动态 skill 发现 (`compute_skill_names`)。真正缺失的不是"市场平台"，而是三个原语：**registry（在哪找）、resolver（取哪个版本）、installer（怎么装）**。

**推荐**: 基于 Git 仓库的去中心化 registry + `baton` CLI 子命令，不建构建中心化平台。

---

## 行动计划

| 优先级 | 变更 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| P1 | **Skill 包格式规范** — 定义 `skill.toml` 元数据文件（name, version, description, author, baton-compat, dependencies） | 2h | 低 | 高 — 是所有后续功能的基础 |
| P2 | **`baton install <source>` 命令** — 从 Git URL / GitHub shorthand 安装 skill 到 `~/.baton/skills/` | 4h | 中 — 需处理 Git sparse checkout、Windows 路径 | 高 — 核心用户流程 |
| P3 | **`baton list` / `baton search` 命令** — 本地已安装 skill 列表 + 远程 registry 搜索 | 3h | 低 | 中 — 可发现性 |
| P4 | **中心化 registry index** — 一个 Git 仓库（如 `baton-skills/registry`），包含 `index.json`，每个条目指向 skill 的 Git URL | 2h | 低 | 中 — 让 `baton search` 有数据源 |
| P5 | **`baton publish` 命令** — 验证 skill 格式合规后，提交 PR 到 registry 仓库 | 3h | 中 — 需要 GitHub API 交互 | 低 — 早期可以手动提交 |
| P6 | **版本锁定与 `baton update`** — `~/.baton/skills/<name>/` 记录 Git ref，支持 pin 版本和升级 | 3h | 中 — 版本冲突解决 | 低 — 早期用 latest 即可 |
| **合计** | | **~17h** | | |

---

## P1: Skill 包格式规范

在每个 skill 目录中增加一个 `skill.toml`（或复用 SKILL.md frontmatter）：

```toml
# ~/.baton/skills/my-awesome-skill/skill.toml
[skill]
name = "my-awesome-skill"
version = "1.0.0"
description = "Does something awesome"
author = "github-user"
license = "MIT"
baton-compat = ">=4.0"        # 对应 setup.sh 的 v4 架构
source = "https://github.com/user/baton-skill-awesome"

[skill.dependencies]          # 可选 — 大多数 skill 无依赖
# requires = ["baton-research"]  # 依赖其他 skill
```

**设计决策**: 为什么用 `skill.toml` 而不是扩展 SKILL.md frontmatter？

- SKILL.md frontmatter 是 IDE 消费的（Claude Code 解析它来决定 skill 行为），混入包管理元数据会污染关注点
- `skill.toml` 是机器可解析的（bash 里用 `grep`/`awk` 即可提取），SKILL.md frontmatter 的 YAML 解析在纯 bash 中不可靠
- 两个文件，两个职责：`SKILL.md` = IDE 接口，`skill.toml` = 包管理接口

**向后兼容**: 没有 `skill.toml` 的 skill 仍然正常工作 —— `setup.sh` 的 `compute_skill_names` 只看目录是否存在，不依赖元数据。`skill.toml` 仅在 `baton install/publish/search` 流程中被使用。

---

## P2: `baton install` 命令

核心安装流程：

```bash
# 用法
baton install github:user/repo              # 仓库根目录就是一个 skill
baton install github:user/repo/skills/foo   # 仓库内的子路径
baton install https://github.com/user/repo  # 完整 Git URL
baton install ./local-path                  # 本地路径（开发用）

# 安装过程
# 1. git clone --depth 1 到临时目录
# 2. 验证 SKILL.md 存在（必须），skill.toml 存在（推荐）
# 3. 复制到 ~/.baton/skills/<name>/
# 4. 记录来源信息到 ~/.baton/skills/<name>/.install-meta
# 5. 在当前项目中创建 junction（调用已有的 atomic_junction）
```

**关键设计点**:

- 安装目标是 `~/.baton/skills/`，**不是**项目级目录。这与 baton 现有的分发模型一致：`~/.baton` 是单一来源，项目通过 junction 引用 ✅ 验证：`setup.sh:129` 的 `create_baton_junction` 和 `setup.sh:143` 的 `create_skill_junctions` 确认了这个模型
- 安装后自动在当前项目创建 junction，复用 `phase-guide.sh:51-66` 已有的自动 junction 逻辑 ✅ 验证：`phase-guide.sh` 的 `_skill_src` / `atomic_junction` 循环
- `.install-meta` 文件记录 `source_url`、`installed_at`、`git_ref`，用于后续的 `update` 和 `uninstall`

**与 baton-* 命名空间的关系**: 现有的 `compute_skill_names`（`setup.sh:21`）扫描 `.baton/skills/*/`，不限定命名前缀。`phase-guide.sh:55` 的自动 junction 循环限定了 `baton-*` 前缀。**这是一个需要修改的地方** —— 社区 skill 不应强制使用 `baton-` 前缀，但自动 junction 需要知道哪些 skill 要链接。

解决方案：将 `phase-guide.sh:55` 的 `for _skill_dir in "$_skill_src"/baton-*` 改为 `for _skill_dir in "$_skill_src"/*/`，跳过 workspace 目录（`*-workspace`）。或者在 `skill.toml` 中声明 `auto-junction = true`。

---

## P3: `baton list` / `baton search`

```bash
baton list                    # 列出 ~/.baton/skills/ 中已安装的 skill
baton list --project          # 列出当前项目已 junction 的 skill
baton search <keyword>        # 在 registry index 中搜索
```

`baton list` 的实现很直接 — 遍历 `~/.baton/skills/*/skill.toml`，提取 name/version/description。对于没有 `skill.toml` 的 skill（内置的 baton-* 系列），从 SKILL.md frontmatter 的 `name`/`description` 字段提取。

`baton search` 需要 P4 的 registry index。实现：`curl` 下载 index.json → `jq`/`awk` 过滤 → 展示结果。

---

## P4: 中心化 Registry Index

一个独立的 Git 仓库（如 `github.com/hex1n/baton-registry`），结构：

```
baton-registry/
  index.json          # 所有已注册 skill 的元数据
  skills/
    my-skill.json     # 每个 skill 的详细信息（可选，用于丰富搜索结果）
```

`index.json` 示例：

```json
{
  "skills": [
    {
      "name": "tdd-workflow",
      "description": "Test-driven development workflow skill",
      "source": "github:user/baton-skill-tdd",
      "author": "user",
      "tags": ["testing", "tdd", "workflow"],
      "baton-compat": ">=4.0"
    }
  ]
}
```

**为什么不用中心化平台（如 npm registry）？**

- baton 是纯 bash + markdown 工具，用户群体在早期很小，运维一个 HTTP registry 服务器的成本远超收益
- Git 仓库作为 registry 的优势：免费托管、PR 即审核流程、版本历史即审计日志、离线可用（clone 后）
- 如果未来规模增长，可以在 index.json 之上加一层 HTTP API 而不改变 skill 的分发方式

---

## 不应该做的事

1. **不要构建中心化下载服务器** — baton 的哲学是零编译依赖、纯 bash。引入 HTTP 服务器破坏了这个约束。Git 仓库 + GitHub API 足够。

2. **不要在 `SKILL.md` frontmatter 中加入包管理字段** — 关注点分离。SKILL.md 是 IDE 消费的接口，skill.toml 是包管理器消费的接口。

3. **不要实现 skill 间的复杂依赖解析** — baton 的 skills 是独立的提示词文件，不是编译单元。依赖场景极少。如果出现，在 `skill.toml` 中声明 + `baton install` 时提示即可，不需要 SAT solver。

4. **不要为 P1 阶段设计权限/签名系统** — 安全审计可以在 registry PR review 中完成。等到社区规模证明需要签名时再添加。

---

## 风险与缓解

| 风险 | 可能性 | 影响 | 缓解 |
|------|--------|------|------|
| 社区 skill 质量参差不齐，低质量 skill 破坏用户体验 | 高 | 中 | Registry 采用 PR-based 提交，维护者审核后合并。安装时显示"未审核"警告 |
| Windows 上 Git sparse checkout 不可靠 | 中 | 中 | 先 full clone + copy 子目录，后续优化为 sparse checkout |
| `baton-*` 命名空间冲突 — 社区 skill 可能使用与内置 skill 相同的名称 | 低 | 高 | Registry 禁止 `baton-` 前缀（保留给内置 skill）。`baton install` 拒绝覆盖 `baton-*` 目录 |
| skill.toml 的 bash 解析在边缘情况下不可靠 | 中 | 低 | 限制 skill.toml 为平坦结构（key = "value"），不支持嵌套表。jq 可选加速 |

---

## 自查

**这个计划最可能的失败模式是什么？**

是"没人用"。插件市场的价值取决于网络效应 — 没有 skill 可装时就没有用户来装，没有用户装就没有作者来发布。P1-P2 解决的是技术基础设施，但真正的挑战是冷启动：需要 5-10 个高质量的示范 skill 预装在 registry 中。

如果我知道它会失败，我会怎么做？跳过 P4-P6，只做 P1-P2（包格式 + install 命令），然后把精力放在写几个优质社区 skill 上。技术基础设施可以在需求出现后迅速补上，但没有内容的平台是空壳。

**用户说的是"插件市场"，我是否追溯到了根问题？**

用户说"让用户可以共享和安装 skills"。"插件市场"是一个解决方案，根问题是 **skill 分发的摩擦太高**。当前流程：找到 skill 源码 → 手动 clone → 复制到 `~/.baton/skills/` → 运行 setup.sh。这个计划通过 `baton install` 把它缩短为一条命令，这直接解决了根问题。至于"市场"（发现 + 搜索），是 P3-P4 解决的次级问题 — 可以延后。

---

## 分析

### Phase 1: 问题考古

**stated problem**: "给 baton 添加一个插件市场，让用户可以共享和安装 skills"

**Five Whys**:
1. 为什么需要插件市场？→ 用户想使用别人写的 skill，但没有发现和安装的途径
2. 为什么没有途径？→ baton 的 skill 分发模型是"单一仓库 → junction 到项目"，假设所有 skill 都在 `~/.baton/skills/` 中
3. 为什么假设在 `~/.baton/`？→ baton 是单人项目，最初的设计只考虑了作者自己的 skill
4. 根问题：**baton 的 skill 分发系统没有"来源多元化"的能力** — 它只认识一个来源（`~/.baton/`），不能从其他地方获取 skill

**问题陈述**: baton 的 skill 分发模型假设所有 skill 都来自 `~/.baton/` 仓库。当用户想使用来自不同作者的 skill 时，必须手动管理文件复制。没有标准化的发现、安装、版本管理流程。解决 = 用户可以通过单条命令安装来自任意 Git 仓库的 skill，且安装后的 skill 与内置 skill 在行为上完全一致。

### 假设审计

| # | 假设 | 类型 | 如果错误... |
|---|------|------|------------|
| 1 | Skill 是自包含的目录（SKILL.md + 可选资源） | 事实 ✅ 验证：所有现有 skill 都是这个结构 | 计划成立 |
| 2 | `~/.baton/skills/` 是 skill 的规范存储位置 | 事实 ✅ 验证：`setup.sh:129-140`, `phase-guide.sh:51-66` | 计划成立 |
| 3 | Junction 机制足以将第三方 skill 链接到项目 | 事实 ✅ 验证：`junction.sh` 的 `atomic_junction` 不区分 skill 来源 | 计划成立 |
| 4 | 用户有 Git 命令行可用 | 惯例 — 可以换成 curl + tar | 计划需要 fallback |
| 5 | 每个 skill 独占一个 Git 仓库 | 惯例 — 实际上很多作者会把多个 skill 放在一个 monorepo 中 | `baton install` 需要支持子路径（见 P2） |
| 6 | 需要一个中心化的搜索/发现服务 | 惯例 — 早期可以靠 GitHub search + README 列表 | P3-P4 可以延后，不影响核心功能 |

### 真约束 vs 惯例

- **真约束**: baton 是纯 bash，不能引入编译依赖（Node.js, Python 等）。所有工具链必须在 Git Bash / macOS Terminal / Linux shell 中可用。
- **真约束**: 现有的 junction 分发模型不能被破坏 — 已安装的项目依赖 `~/.baton/ → project/.baton` 的链接结构。
- **惯例（可挑战）**: `phase-guide.sh:55` 只自动 junction `baton-*` 前缀的 skill。这是命名惯例，不是架构限制。社区 skill 不应被强制使用这个前缀。
- **惯例（可挑战）**: skill 没有版本号。目前所有 skill 跟随 baton 主仓库的 Git 历史。第三方 skill 需要独立版本管理。

### 方案类别

**方案 A: Git 仓库分发（推荐）**
- 机制：每个 skill 是一个 Git 仓库（或 monorepo 中的目录）。`baton install` = `git clone` + copy + junction。
- 优势：零基础设施成本、用户已有 Git、版本管理天然内置
- 劣势：搜索/发现需要额外的 registry index
- 挑战了什么惯例：没有中心化平台

**方案 B: npm/pip 式 HTTP registry**
- 机制：中心化 HTTP 服务，`baton install <name>` 从 registry 下载 tarball
- 优势：标准化的搜索/发现体验
- 劣势：需要运维服务器、违反 baton 的零依赖原则、早期用户规模不支撑
- 在什么条件下最好：用户量 > 1000、skill 数量 > 100

**方案 C: GitHub Releases / Archive 下载**
- 机制：skill 作者发布 GitHub Release，`baton install` 用 `curl` 下载 tarball
- 优势：不需要 Git（只需 curl），体积更小
- 劣势：丢失 Git 历史、更新机制更复杂、需要作者手动打包
- 在什么条件下最好：目标用户群体中有人没有安装 Git

推荐方案 A，因为它利用了 baton 用户一定有 Git 的事实（baton 本身通过 Git 安装），且与现有的 `ensure_baton_home`（`setup.sh:57`）中的 `git clone` 模式完全一致。

### 反转测试

方案 A（Git 仓库分发）在什么条件下最差？

1. **Git 不可用**（如企业防火墙内网环境）— 缓解：支持 `baton install ./local-path` 本地安装
2. **Monorepo 中 skill 数量很大**（100+ skill 在一个仓库中，clone 很慢）— 缓解：支持 sparse checkout 或者让作者拆分仓库
3. **版本冲突无法自动解决**（两个 skill 依赖同一个 skill 的不同版本）— 缓解：baton 的 skill 是提示词，不是代码库。真正的版本冲突概率极低。如果出现，让用户手动选择。

这些失败场景都不是高概率的，且都有合理的缓解措施。

## 批注区

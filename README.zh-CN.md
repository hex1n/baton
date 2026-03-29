# Baton Harness

[English](README.md) | [简体中文](README.zh-CN.md)

根目录入口文档规则：凡是涉及 onboarding、install/update、vendor、override
或 skill 分发的改动，都要同步更新本文件和 `README.md`。规则见 `CLAUDE.md`
和 `AGENTS.md`，改完后执行 `bash spec/bootstrap/check-root-readme-bilingual.sh`。

一个可移植的 AI 编码代理协作协议，当前仓库提供 Claude Code 参考实现。

设计来源参考 [Anthropic 关于 long-running apps 的 harness 设计](https://www.anthropic.com/engineering/harness-design-long-running-apps)。

## 结构

```text
spec/              可移植的 harness 协议定义（与具体工具无关）
.claude/skills/    Claude Code 角色技能（参考实现）
CLAUDE.md          给 Claude Code 风格宿主使用的根级治理入口
AGENTS.md          给 Codex / Cursor 风格宿主使用的根级治理入口
```

## 协议

这个协议定义了一条 AI 辅助编码任务的闭环流程。

主路径：

**Explorer** → **Specifier** → **Architect** → 人工批准 → **Verifier** → **Generator** → **Evaluator** → 人工关闭

修复回路：

- `Verifier BLOCKED` → 回到 `Architect` / `Specifier`
- `Generator BLOCKED` → 回到 `Architect` / `Specifier` / `Human`
- `Evaluator BLOCKED` → 回到 `Generator` 修复，然后重新运行 `Evaluator`

每个角色都会在 `.harness/` 中产出文件型制品，状态通过 `module-status.md` 跟踪。

## 制品语言

人类可读制品支持中英文。

- `init-harness` 接受 `--language auto|en|zh`，并把策略写入 `.harness/profile.local.yaml`
- `start-task` 接受同样的参数作为覆盖；不传时会先读 profile，再回退到中文
- 这个仓库的 bootstrap 默认语言是中文；如果你想要别的默认值，显式传 `--language en` 或 `--language auto`
- bootstrap 脚本里的 `auto` 按本机 locale 解析
- 写制品的 role skill 里的 `auto` 表示“跟随当前用户输入语言”
- `module-status.md` 保持英文，因为它是稳定的控制面

实践中有两条规则最重要：

- architecture 通过后，如果有已批准的架构决策改变了 requirements 层面的事实，必须先把 `requirements.md` 同步完，再进入 verification
- 在 `verification_check` 前或过程中，先跑 `spec/bootstrap/check-consistency.sh`

> **显示名称 → 运行时 token 映射**（给 `start-task.sh --owner` 用）：
> Explorer = `repo-explorer` / `scoped-explorer` | Specifier = `specifier` | Architect = `architect` |
> Verifier = `verification-explorer` | Generator = `generator` | Reviewer = `reviewer` |
> Evaluator = `evaluator` | Human = `human`

完整的可移植协议见 [spec/README.md](spec/README.md)。

## 快速开始

### 在新仓库里接入

```bash
# 先把 vendored harness payload 安装到目标仓库
spec/bootstrap/install-harness.sh --repo-root /path/to/repo

# 再从目标仓库内部的 vendored spec 执行 bootstrap
/path/to/repo/.vendor/baton-harness/spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter claude-code

# 开始一个任务
/path/to/repo/.vendor/baton-harness/spec/bootstrap/start-task.sh --repo-root /path/to/repo --task-id my-task
```

`init-harness` 还会把共享治理摘要物化成根目录的 `CLAUDE.md` 和 `AGENTS.md`，
这样 Claude Code、Codex、Cursor 都能看到同一套仓库级规则。

如果你在 Codex 里运行 harness，建议把 `Verifier` 和 `Evaluator` 作为隔离 sub-agent 启动，并使用 `fork_context: false`。可以直接参考 [spec/adapters/codex.md](spec/adapters/codex.md) 里的 `spawn_agent` / `wait_agent` 示例。

### 在目标仓库里安装 / 升级

推荐的外部仓库接入流程：

```bash
# 首次安装
spec/bootstrap/install-harness.sh --repo-root /path/to/repo

# 后续从当前 baton checkout 升级同一个目标仓库
spec/bootstrap/update-harness.sh --repo-root /path/to/repo
```

Windows 下请直接复用同一套 `.sh` 入口：可以在 Git Bash 里执行，也可以在
PowerShell 里通过 `bash spec/bootstrap/<command>.sh ...` 调用。Baton
不再维护单独的 `spec/bootstrap/*.ps1` 业务入口层。

安装后会出现：

- `.vendor/baton-harness/`：vendored 上游 payload
- `.harness/harness.lock.yaml`：当前安装版本的真源
- `.harness/overrides/skills/` 和 `.harness/overrides/templates/`：本地定制入口
- `.claude/skills/` 和 `.agents/`：根据 vendor + overrides 物化出来的运行时 skill 入口
- 根目录 `CLAUDE.md` 和 `AGENTS.md`：由 `init-harness` 基于共享治理模板物化

### baton 自己内部开发时的链接模式

对 baton 仓库自身，`skills/` 最好保持 canonical source，再把 `.claude/skills/` 和 `.agents/` 重建成链接：

```bash
# 用 canonical skills/ 重建 .claude/skills/ 和 .agents/
spec/bootstrap/link-skills.sh
```

这只适用于 baton 仓库自己的开发态。使用 symlink 时，link target 会写成仓库内相对路径，避免把本机绝对路径固化进仓库。`sync-skills.sh` 会根据工作区真实文件类型判断是否需要同步，而不会只相信 `.link-mode`。

### 手工复制 fallback

```bash
cp .claude/skills/baton-*.md /path/to/repo/.claude/skills/
```

正常接入请优先使用 `install-harness` / `update-harness`。手工复制只保留为低成本 fallback。

对 baton 维护者来说，根级治理规则要改 `spec/templates/root-governance.template.md`，
然后执行：

```bash
bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --force
```

## 角色技能

| Skill | Role | Gate |
|-------|------|------|
| `baton-explorer` | 代码探索（repo + scoped） | Scoped Exploration Complete |
| `baton-specifier` | 需求定义 | — |
| `baton-architect` | 技术架构 | Architecture Approved（人工） |
| `baton-verifier` | 验证路径检查 | Verification Path Check |
| `baton-generator` | 代码实现 | — |
| `baton-evaluator` | 独立评估 | Independent Review |

## 能力技能

| Skill | 用途 |
|-------|------|
| `deep-research` | 系统化调查代码、API、文档 |
| `first-principles-planner` | 基于第一性原理的策略规划 |

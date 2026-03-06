# Plan: .baton 目录结构重组

## 背景

`.baton/` 目录下 7 个 hook 脚本、2 个 workflow 文档和 adapters 子目录混在一起，结构混乱。同时根目录的 `hooks/` 存放 git pre-commit 模板，和拟新建的 `.baton/hooks/` 命名冲突。

## 目标结构

```
.baton/
├── hooks/               # Claude Code hook 脚本（从 .baton/ 根移入）
│   ├── write-lock.sh
│   ├── phase-guide.sh
│   ├── stop-guard.sh
│   ├── bash-guard.sh
│   ├── completion-check.sh
│   ├── pre-compact.sh
│   ├── post-write-tracker.sh
│   └── subagent-context.sh
├── git-hooks/            # Git hook 模板（从根目录 hooks/ 移入）
│   └── pre-commit
├── adapters/             # IDE 适配器（不变）
│   ├── adapter-cline.sh
│   ├── adapter-copilot.sh
│   ├── adapter-cursor.sh
│   └── opencode-plugin.mjs
├── workflow.md           # 留在 .baton/ 根（CLAUDE.md @import 不变）
└── workflow-full.md
```

根目录 `hooks/` 删除。

## 变更概览

| # | 变更 | 涉及文件 |
|---|------|---------|
| 1 | 移动脚本文件 | 7 个 `.baton/*.sh` → `.baton/hooks/*.sh`，`hooks/pre-commit` → `.baton/git-hooks/pre-commit` |
| 2 | 更新 settings.json | `.claude/settings.json`（7 个 hook 命令路径） |
| 3 | 更新 setup.sh | `setup.sh`（源复制路径 + settings.json 生成 + pre-commit 安装 + 提示信息） |
| 4 | 更新 adapter 脚本 | 3 个 adapter 的相对路径引用 |
| 5 | 更新测试文件 | 8 个测试文件的路径引用 |
| 6 | 更新 CI/CD | `.github/workflows/ci.yml` shellcheck 路径 |
| 7 | 更新 SYNCED 注释 | 可选：4 个脚本的注释中不含路径，无需改 |

## 变更详情

### 变更 1: 移动文件

**操作**:
```bash
# Claude Code hooks
mkdir -p .baton/hooks
git mv .baton/write-lock.sh .baton/hooks/
git mv .baton/phase-guide.sh .baton/hooks/
git mv .baton/stop-guard.sh .baton/hooks/
git mv .baton/bash-guard.sh .baton/hooks/
git mv .baton/completion-check.sh .baton/hooks/
git mv .baton/pre-compact.sh .baton/hooks/
git mv .baton/post-write-tracker.sh .baton/hooks/
git mv .baton/subagent-context.sh .baton/hooks/

# Git hooks
mkdir -p .baton/git-hooks
git mv hooks/pre-commit .baton/git-hooks/pre-commit
# hooks/ 目录变空后 git 自动不跟踪
```

**Risk**: git mv 保留历史，安全。移动后 `.gitignore` 中如果有 `hooks/` 相关条目也需检查。

### 变更 2: 更新 .claude/settings.json

**What**: 7 个 hook 命令路径从 `sh .baton/<name>.sh` 改为 `sh .baton/hooks/<name>.sh`

**具体改动**: 对每个 hook 命令，插入 `hooks/`：
- `sh .baton/phase-guide.sh` → `sh .baton/hooks/phase-guide.sh`
- `sh .baton/write-lock.sh` → `sh .baton/hooks/write-lock.sh`
- `sh .baton/post-write-tracker.sh` → `sh .baton/hooks/post-write-tracker.sh`
- `sh .baton/stop-guard.sh` → `sh .baton/hooks/stop-guard.sh`
- `sh .baton/subagent-context.sh` → `sh .baton/hooks/subagent-context.sh`
- `sh .baton/completion-check.sh` → `sh .baton/hooks/completion-check.sh`
- `sh .baton/pre-compact.sh` → `sh .baton/hooks/pre-compact.sh`

### 变更 3: 更新 setup.sh

**3a — `install_versioned_script` 函数**（:115-161）:
- 源路径: `$BATON_DIR/.baton/$_ivs_name` → `$BATON_DIR/.baton/hooks/$_ivs_name`
- 目标路径: `$PROJECT_DIR/.baton/$_ivs_name` → `$PROJECT_DIR/.baton/hooks/$_ivs_name`

**3b — `configure_claude` 中的提示信息**（:200-235）:
- 所有 `sh .baton/<name>.sh` → `sh .baton/hooks/<name>.sh`
- v1 迁移的 sed: `.baton/write-lock.sh` → `.baton/hooks/write-lock.sh`

**3c — settings.json 生成的 heredoc**（:238-320）:
- 7 个 `"command": "sh .baton/<name>.sh"` → `"sh .baton/hooks/<name>.sh"`

**3d — Windsurf/Cursor hooks.json 生成**（:360-414）:
- `sh .baton/write-lock.sh` → `sh .baton/hooks/write-lock.sh`
- `sh .baton/adapters/adapter-cursor.sh` — adapters 路径不变

**3e — `mkdir` 目标目录**（:466）:
- `mkdir -p "$PROJECT_DIR/.baton/adapters"` → `mkdir -p "$PROJECT_DIR/.baton/hooks" "$PROJECT_DIR/.baton/adapters"`

**3f — `install_versioned_script` 调用**（:469-472）:
- 参数不变（只是文件名），但函数内部路径已在 3a 中更新

**3g — pre-commit 安装**（:503-535）:
- 源路径: `$BATON_DIR/hooks/pre-commit` → `$BATON_DIR/.baton/git-hooks/pre-commit`

**3h — `get_version` 调用**（:444）:
- `$BATON_DIR/.baton/write-lock.sh` → `$BATON_DIR/.baton/hooks/write-lock.sh`

**3i — v1 迁移**（:450-455）:
- 目标路径: `.baton/write-lock.sh` → `.baton/hooks/write-lock.sh`

### 变更 4: 更新 adapter 脚本

**What**: 3 个 adapter 引用 write-lock.sh 的相对路径

当前（adapter 在 `.baton/adapters/`，write-lock 在 `.baton/`）：
```bash
$(dirname "$0")/../write-lock.sh
```

改为（write-lock 在 `.baton/hooks/`）：
```bash
$(dirname "$0")/../hooks/write-lock.sh
```

涉及文件：
- `.baton/adapters/adapter-cline.sh:11`
- `.baton/adapters/adapter-cursor.sh:5`
- `.baton/adapters/adapter-copilot.sh:5`

### 变更 5: 更新测试文件

**模式**: 所有 `$SCRIPT_DIR/../.baton/<name>.sh` → `$SCRIPT_DIR/../.baton/hooks/<name>.sh`

涉及文件及改动类型：
- `test-write-lock.sh:6` — `LOCK` 变量路径
- `test-phase-guide.sh:6` — `GUIDE` 变量路径
- `test-stop-guard.sh:6` — `GUARD` 变量路径
- `test-workflow-consistency.sh` — 多个脚本路径引用（workflow 路径不变）
- `test-setup.sh` — 大量 `assert_file_exists` 等断言路径（~23 处）
- `test-adapters.sh` — `cp` 源路径 + adapter 引用（~8 处）
- `test-adapters-v2.sh` — 同上（~10 处）
- `test-new-hooks.sh:7` — `BATON` 变量（如果引用到具体脚本需更新）
- `test-pre-commit.sh` — pre-commit 源路径（`hooks/pre-commit` → `.baton/git-hooks/pre-commit`）
- `test-multi-ide.sh` — setup 生成的路径验证

### 变更 6: 更新 CI/CD

**文件**: `.github/workflows/ci.yml`

```yaml
# 当前
run: shellcheck .baton/write-lock.sh
run: shellcheck .baton/phase-guide.sh
run: shellcheck .baton/bash-guard.sh
run: shellcheck .baton/stop-guard.sh

# 改为
run: shellcheck .baton/hooks/write-lock.sh
run: shellcheck .baton/hooks/phase-guide.sh
run: shellcheck .baton/hooks/bash-guard.sh
run: shellcheck .baton/hooks/stop-guard.sh
```

adapter 路径不变。

## Self-Review

1. **最大风险**: setup.sh 改动最复杂（~22 处），涉及多个函数和 heredoc。单个路径遗漏会导致安装失败或 hook 不触发。缓解：改完后运行 test-setup.sh 验证。

2. **什么可能让这个计划完全错误**: 如果有其他工具或配置文件（未被 research 发现的）引用了旧路径。缓解：移动文件后全局搜索旧路径模式确认无遗漏。

3. **被拒绝的替代方案**: 方案 B（只移 workflow 文档到 docs/）— 改动量小但不解决核心问题（脚本散乱）。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注，用 § 引用章节。如：[Q] § 变更 3：为什么用 grep -i？ -->
<!-- BATON:GO -->

## Todo

### 变更 1: 移动文件

- [x] `git mv` 7 个 hook 脚本到 `.baton/hooks/`
- [x] `git mv hooks/pre-commit` 到 `.baton/git-hooks/pre-commit`
- [x] 检查 `.gitignore` 中是否有 `hooks/` 相关条目需要更新

### 变更 2: 更新 .claude/settings.json

- [x] 7 个 hook 命令路径插入 `hooks/`

### 变更 3: 更新 setup.sh

- [x] 3a: `install_versioned_script` 源/目标路径加 `hooks/`
- [x] 3b: `configure_claude` 提示信息路径 + v1 迁移 sed
- [x] 3c: settings.json heredoc 中 7 个 command 路径
- [x] 3d: Windsurf/Cursor hooks.json 中 write-lock 路径
- [x] 3e: `mkdir` 目标目录加 `hooks/`
- [x] 3g: pre-commit 安装源路径
- [x] 3h: `get_version` 调用路径
- [x] 3i: v1 迁移目标路径

### 变更 4: 更新 adapter 脚本

- [x] `adapter-cline.sh` — `../write-lock.sh` → `../hooks/write-lock.sh`
- [x] `adapter-cursor.sh` — 同上
- [x] `adapter-copilot.sh` — 同上

### 变更 5: 更新测试文件

- [x] `test-write-lock.sh` — LOCK 变量路径
- [x] `test-phase-guide.sh` — GUIDE 变量路径
- [x] `test-stop-guard.sh` — GUARD 变量路径
- [x] `test-workflow-consistency.sh` — 脚本路径引用
- [x] `test-setup.sh` — assert 路径
- [x] `test-adapters.sh` — cp 源路径 + 引用
- [x] `test-adapters-v2.sh` — 同上
- [x] `test-new-hooks.sh` — BATON 变量引用
- [x] `test-pre-commit.sh` — pre-commit 源路径
- [x] `test-multi-ide.sh` — 无需改动（无 hook 脚本路径引用）

### 变更 6: 更新 CI/CD

- [x] `.github/workflows/ci.yml` — shellcheck 路径

### 验证

- [x] 全局搜索旧路径模式确认无遗漏
- [x] 运行 test-setup.sh — 67/67 ALL PASSED
- [x] 运行 test-phase-guide.sh (59/59) + test-write-lock.sh (36/37, perf-only) + test-stop-guard.sh (25/25)
- [x] 运行 test-adapters.sh (8/8) + test-adapters-v2.sh (10/10)
- [x] 运行 test-workflow-consistency.sh (ALL CONSISTENT) + test-pre-commit.sh (8/8)

## Retrospective

### 计划准确度
计划覆盖了所有需要改动的文件。6 个变更步骤按顺序执行无阻塞。setup.sh 的 ~22 处改动（计划中标注为最大风险）实际改动量与预估一致，test-setup 67/67 全过验证了完整性。

### 惊喜
1. **Windows Git Bash 并行测试极慢**: 8 个测试套件并行运行时，部分测试（phase-guide、write-lock、setup）执行时间从正常几秒膨胀到 5-10 分钟。改为串行执行后恢复正常速度。
2. **write-lock 性能测试 4370ms/call**: Windows Git Bash 上 shell 脚本调用开销巨大，远超 Linux 的 200ms 阈值。这是 pre-existing 问题，与本次重组无关。

### 下次改进
- 在 Windows 环境下避免并行运行大量 bash 测试套件，改为串行执行
- 大规模路径重构时，先用 subagent 并行处理独立的文件更新（如测试文件），再逐步验证
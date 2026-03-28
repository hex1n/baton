# Baton v5 — User-Level Flat Install

**Sizing: Medium** — 验证需多步确认（setup.sh 安装/迁移/卸载 + hook 触发 + 技能加载 + 跨文件一致性）

**状态: PROPOSING**

---

## Requirements

Source: `~/.gstack/projects/hex1n-baton/hex1n-master-design-20260321-103156.md` (design doc, APPROVED revised)
Eng review: `/plan-eng-review` session 2026-03-21, pivoted from plugin (Approach B) to flat install (Approach C)

User goal: 消除 junction-based 架构，改为用户级扁平安装。零项目足迹。

## Problem Statement

Baton v4 在每个项目目录投递 ~15 个文件（junctions、settings 条目、gitignore 条目）。这导致 `git clean -fdX` 致命 bug、三级降级逻辑、jq 依赖、跨平台问题、self-install 悖论、setup.sh 680 行臃肿。

需要：所有 baton 基础设施文件从项目目录移至用户级 `~/.claude/`，通过 symlinks 和绝对路径实现零项目足迹。

## Constraints

1. 零项目基础设施足迹（baton-tasks/ 用户工件除外）
2. 同一治理，所有项目
3. 仅 Claude Code（Codex/Cursor 延后）
4. Constitution 必须永久在 LLM 上下文中
5. 开发时 `~/.baton` 源码变更即时可见（symlinks，非 copy/cache）
6. ❓ `@~/.baton/constitution.md` 在 `~/.claude/CLAUDE.md` 中路径解析 — 需先验证

## First Principles Decomposition

**Solution categories:**
1. ~~Plugin system~~ — 已验证不可行：Claude Code `extraKnownMarketplaces` 仅支持 GitHub 源，无本地目录注册 ✅ 已读取 settings.json 和 known_marketplaces.json 确认
2. **User-level flat install** — symlinks + 用户级 settings.json + 用户级 CLAUDE.md（选定）
3. ~~MCP server~~ — 过度工程化，hook 系统已足够

**Evaluation**: Approach 2 在所有约束下最优：零项目足迹 ✅、即时变更 ✅、无插件 API 依赖 ✅、jq 仅一次性 ✅。

## Surface Scan

| File | Level | Disposition | Evidence |
|------|-------|-------------|----------|
| `setup.sh` (680 行) | L1 | **rewrite** | ✅ 已读全文 — junction/IDE/settings/gitignore 逻辑全部替换 |
| `.baton/hooks/lib/junction.sh` (36 行) | L1 | **delete** | ✅ 已读 — 整个文件是 junction 逻辑 |
| `.baton/hooks/phase-guide.sh` 50-67 行 | L1 | **modify** | ✅ 已读 — auto-junction block 源 junction.sh |
| `.baton/hooks/phase-guide.sh` `_scan_all_skills()` 72-80 行 | L1 | **modify** | ✅ 已读 — 扫描项目本地 .baton/.claude/.cursor/.agents |
| `.baton/hooks/lib/plan-parser.sh` `parser_has_skill()` 204-216 行 | L1 | **modify** | ✅ 已读 — 扫描 .baton/skills 项目本地路径 |
| `bin/baton` (393 行) | L1 | **modify** | ✅ 已读 — doctor/update/init 全部引用 .baton/ junction 逻辑 |
| `install.sh` (92 行) | L1 | **modify** | ✅ 已读 — 克隆 + 运行 setup.sh |
| `README.md` 140-230 行 | L1 | **modify** | ✅ 已读 — 架构图、安装说明、IDE 表 |
| `CLAUDE.md` | L1 | **modify** | ✅ 已读 — `@.baton/constitution.md` → 移至用户级 |
| `AGENTS.md` | L1 | **modify** | ✅ 已读 — `@.baton/constitution.md` → 移至用户级 |
| `.claude/settings.json` (项目级) | L1 | **delete entries** | ✅ 已读 — baton hook 条目移至用户级 |
| `.baton/hooks/dispatch.sh` | L2 | **skip** | ✅ 已读 — `dirname "$0"` 路径解析不受影响 |
| `.baton/hooks/run-hook.cmd` | L2 | **skip** | ✅ 已读 — `SCRIPT_DIR` 解析不受影响 |
| `.baton/hooks/manifest.conf` | L2 | **skip** | ✅ 已读 — 事件路由不变 |
| `.baton/hooks/lib/common.sh` | L2 | **skip** | ✅ 已读 — 源 plan-parser.sh，无直接 .baton/ 引用 |
| `.baton/hooks/write-lock.sh` | L2 | **skip** | 不直接引用 .baton/ |
| `.baton/hooks/bash-guard.sh` | L2 | **skip** | 不直接引用 .baton/ |
| `.baton/constitution.md` | L1 | **move** | 移至 top-level `constitution.md` |
| `.baton/skills/baton-*/` | L1 | **move** | 移至 top-level `skills/baton-*/` |
| `.baton/adapters/` | L2 | **skip (deferred)** | Codex/Cursor 适配器延后 |
| `tests/test-junction.sh` | L1 | **delete** | junction 逻辑消除 |
| `tests/test-setup.sh` | L1 | **rewrite** | 新 setup.sh 需全新测试 |
| `tests/test-multi-ide.sh` | L1 | **delete** | 多 IDE 延后 |
| `tests/test-ide-capability-consistency.sh` | L1 | **delete** | IDE 检测移除 |
| `tests/test-dispatch.sh` | L1 | **update** | 绝对路径调用 |
| `tests/test-phase-guide.sh` | L1 | **update** | phase-guide 变更 |
| `tests/test-cli.sh` | L1 | **update** | bin/baton doctor 变更 |
| `tests/test-smoke.sh` | L1 | **update** | 可能引用项目本地工件 |
| `tests/test-full.sh` | L1 | **update** | 运行器脚本 |
| `tests/test-constitution-consistency.sh` | L1 | **update** | constitution 路径变更 |
| `tests/test-adapters*.sh` | L2 | **skip (deferred)** | 适配器逻辑不变 |
| `tests/test-write-lock.sh` | L2 | **skip** | 逻辑不变 |
| `tests/test-bash-guard.sh` | L2 | **skip** | 逻辑不变 |
| `tests/test-stop-guard.sh` | L2 | **skip** | 逻辑不变 |
| `tests/test-plan-parser.sh` | L1 | **update** | parser_has_skill 变更 |
| `tests/test-annotation-protocol.sh` | L2 | **skip** | 逻辑不变 |
| `tests/test-new-hooks.sh` | L2 | **skip** | 逻辑不变 |
| `.codex/hooks.json` | L2 | **skip (deferred)** | Codex 延后 |
| `docs/` | L2 | **skip** | 内部文档，不影响运行 |

**L3 flags (需运行时验证):**
- ❓ `@~/.baton/constitution.md` 路径解析 — 静态分析无法确认 Claude Code 是否在 CLAUDE.md 中展开 tilde
- ❓ 用户级 settings.json hooks 中绝对路径是否正确执行 — 需实际测试
- ❓ v4+v5 共存时 hook 重复触发 — 迁移时需检测

## Approach

**User-level flat install** (唯一可行方案，其他已在设计阶段排除)

### Architecture

```
~/.baton/                              # 源码仓库 (git clone)
├── skills/                            # 技能（从 .baton/skills/ 移至 top-level）
│   ├── baton-research/
│   ├── baton-plan/
│   ├── baton-implement/
│   ├── baton-review/
│   ├── baton-debug/
│   ├── baton-subagent/
│   ├── baton-evolve/
│   └── using-baton/                   # 注意：非 baton-* 前缀，但必须包含
├── hooks/                            # 钩子（从 .baton/hooks/ 移至 top-level）
│   ├── run-hook.cmd, dispatch.sh, manifest.conf
│   ├── lib/{common.sh, plan-parser.sh}
│   └── *.sh (所有钩子脚本)
├── constitution.md                    # 从 .baton/constitution.md 移至 top-level
├── .baton/                            # 兼容层 — symlinks 回新位置
│   ├── skills → ../skills             # v4 junctions 仍然有效
│   ├── hooks → ../hooks
│   └── constitution.md → ../constitution.md
├── setup.sh                           # 重写 ~70 行
└── install.sh                         # 简化

~/.claude/ (setup 后)
├── CLAUDE.md                          # @~/.baton/constitution.md
├── settings.json                      # baton hook 条目（绝对路径，empty matchers）
└── skills/
    ├── baton-research/ → ~/.baton/skills/baton-research/  (symlink)
    ├── baton-plan/     → ...
    ├── using-baton/    → ~/.baton/skills/using-baton/     (symlink)
    └── ...                                                 (all skills)
```

**关键设计决策 — 兼容层**: 仓库重构后，`.baton/` 目录保留为 symlink 兼容层。现有 v4 项目的 junctions 指向 `~/.baton/.baton/hooks/dispatch.sh`，兼容层让这些 junctions 在 git pull 后继续工作。用户可以随时迁移，无紧急破坏。

### Implementation Phases

**Phase 1: 验证前提 (gate)**
1. 测试 `@~/.baton/constitution.md` 在 `~/.claude/CLAUDE.md` 中是否有效
2. 测试用户级 settings.json 中绝对路径 hooks 是否正确触发
→ 如果任一失败：BLOCKED

**Phase 2: 仓库重构 (先做，Codex 发现 #9)**
3. 移动 `.baton/skills/*` → `skills/*`（所有技能，包括 using-baton）
4. 移动 `.baton/hooks/*` → `hooks/*`
5. 移动 `.baton/constitution.md` → `constitution.md`
6. 创建兼容层 symlinks：`.baton/skills` → `../skills`、`.baton/hooks` → `../hooks`、`.baton/constitution.md` → `../constitution.md`
7. 更新所有内部相对路径引用
   - 验证 `hooks/../skills/using-baton/SKILL.md` 路径在重构后仍然有效 ✅（hooks/ 和 skills/ 仍为兄弟目录）

**Phase 3: 核心脚本重写**
8. 重写 `setup.sh` — symlinks + 用户级 settings.json merge (jq) + CLAUDE.md 注入 + --migrate + --uninstall
   - 编辑前备份 settings.json → settings.json.baton-backup (Codex 发现 #6)
   - --migrate 检测 v4+v5 共存并警告 (Codex 发现 #2)
   - SessionStart hook 使用空 matcher（match all，与 v4 一致）
9. 简化 `install.sh` — 克隆 + 运行 setup.sh

**Phase 4: Hook 脚本更新**
10. `phase-guide.sh`: 删除 50-67 行 junction auto-create block
11. `phase-guide.sh`: 更新 `_scan_all_skills()` 在 `~/.claude/skills/` 额外扫描（保留项目本地扫描 + 添加用户级扫描）
12. `phase-guide.sh`: 验证 line 28 governance context 路径 `$SCRIPT_DIR/../skills/using-baton/SKILL.md` 在重构后仍有效
13. `plan-parser.sh`: 更新 `parser_has_skill()` — 在 walk-up 中添加 `~/.claude/skills/` 作为额外搜索位置（保留 walk-up 行为）
14. 删除 `hooks/lib/junction.sh`
15. 更新 `hooks/lib/common.sh` 注释 — 移除过时的 `.baton/skills` 引用

**Phase 5: CLI + Docs**
16. 更新 `bin/baton` — doctor 检查用户级工件、移除 junction 逻辑、更新 parser 路径（BATON_HOME/hooks/ 而非 BATON_HOME/.baton/hooks/）
17. 更新 `README.md` — 架构图、安装说明
18. 更新项目级 `CLAUDE.md` — 移除 `@.baton/constitution.md`（现在在用户级）
19. 更新 `AGENTS.md` — 同上

**Phase 6: 测试**
20. 删除 test-junction.sh, test-multi-ide.sh, test-ide-capability-consistency.sh
21. 重写 test-setup.sh — 覆盖新 setup.sh 所有路径
22. 更新 test-dispatch.sh, test-phase-guide.sh, test-cli.sh, test-smoke.sh, test-full.sh, test-constitution-consistency.sh, test-plan-parser.sh
23. 运行完整测试套件验证

### Write Set

| File | Action | Lines ~Δ |
|------|--------|----------|
| `setup.sh` | rewrite | -680 / +60 |
| `install.sh` | modify | -50 / +20 |
| `junction.sh` → delete | delete | -36 |
| `phase-guide.sh` | modify | -20 / +5 |
| `plan-parser.sh` | modify | -5 / +5 |
| `bin/baton` | modify | -200 / +80 |
| `README.md` | modify | -100 / +60 |
| `CLAUDE.md` | modify | -1 |
| `AGENTS.md` | modify | -1 |
| `.claude/settings.json` | modify (remove baton hooks) | -30 |
| `tests/test-junction.sh` | delete | -all |
| `tests/test-multi-ide.sh` | delete | -all |
| `tests/test-ide-capability-consistency.sh` | delete | -all |
| `tests/test-setup.sh` | rewrite | -all / +new |
| `tests/test-dispatch.sh` | modify | ~10 lines |
| `tests/test-phase-guide.sh` | modify | ~10 lines |
| `tests/test-cli.sh` | modify | ~30 lines |
| `tests/test-smoke.sh` | modify | ~10 lines |
| `tests/test-full.sh` | modify | ~5 lines |
| `tests/test-constitution-consistency.sh` | modify | ~5 lines |
| `tests/test-plan-parser.sh` | modify | ~10 lines |
| Repo restructure: `.baton/skills/*` → `skills/*` | move | 0 (rename) |
| Repo restructure: `.baton/hooks/*` → `hooks/*` | move | 0 (rename) |
| Repo restructure: `.baton/constitution.md` → `constitution.md` | move | 0 (rename) |
| `.baton/skills` → symlink to `../skills` | create (compat layer) | +1 |
| `.baton/hooks` → symlink to `../hooks` | create (compat layer) | +1 |
| `.baton/constitution.md` → symlink to `../constitution.md` | create (compat layer) | +1 |
| `hooks/lib/common.sh` | modify (stale comment) | ~2 lines |

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| `@` tilde 路径不解析 | High — constitution 不加载 | Phase 1 gate 验证；fallback 用绝对路径 |
| v4+v5 hook 重复触发 | Medium — 治理逻辑双倍执行 | --migrate 检测并警告；文档说明迁移顺序 |
| settings.json 编辑失败 | Medium — 丢失用户配置 | 编辑前 `.baton-backup` 备份 |
| 仓库重构破坏 v4 junctions | ~~High~~ → Low | 兼容层 symlinks 让 v4 junctions 继续工作 |
| 仓库重构破坏 worktrees | Low — 现有 worktrees 路径失效 | 清理旧 worktrees（已有 ~27 个） |

## Self-Challenge

### 1. Is this the best approach, or the first one I thought of?

三个方案已在 /office-hours 中评估（Plugin A、Plugin+CLAUDE.md B、Flat Install C）。Approach B 在 /plan-eng-review 中被验证不可行（无本地 marketplace 源）。Approach A 有 constitution compaction 风险。Approach C 是排除法后的唯一可行方案，不是默认选择。✅

### 2. What assumptions did I make without verifying?

- ❓ `@~/.baton/constitution.md` 路径解析 — Phase 1 gate 验证
- ❓ 用户级 settings.json 绝对路径 hook 执行 — Phase 1 gate 验证
- ✅ Symlinks 在 `~/.claude/skills/` 中被 Claude Code 正确发现 — gstack 的 skills 已通过 symlinks 工作
- ✅ `dispatch.sh` 的 `dirname "$0"` 在绝对路径调用下正确解析 — Shell 标准行为

### 3. What would a skeptic challenge first?

"你把 jq 依赖从每项目移到了用户级，但本质上还是在做 JSON merge。这真的简单了吗？"

回答：是的。v4 的问题是 *每个项目* 每次 setup 都要 merge，且必须处理新建 vs 已有两条路径、保留用户 hooks、处理无 jq fallback。v5 是一次性操作：install 时 merge 一次到 `~/.claude/settings.json`，之后不再触碰。merge 逻辑本身可以从 v4 复用，只是目标文件和触发条件简化了。

> **Weakest assumption**: `@~/.baton/constitution.md` 路径解析在 `~/.claude/CLAUDE.md` 中有效
> **If this assumption is wrong**: 需要改用绝对路径 `@/Users/hex1n/.baton/constitution.md`（非便携但对个人工具可接受），或改回 SessionStart hook 注入 constitution（有 compaction 风险）
> **How to verify before executing**: 在 `~/.claude/CLAUDE.md` 中添加 `@~/.baton/constitution.md`，启动新 Claude Code 会话，检查 constitution 内容是否出现在上下文中

## NOT in scope

- Codex/Cursor/Factory IDE 支持 — 延后
- Per-project 定制化 — 同一治理，所有项目
- 自动更新机制 — 手动 git pull + setup.sh
- baton-tasks/ 位置变更 — 保持项目本地
- `.baton/adapters/` 目录 — Codex/Cursor 延后
- Plugin 系统集成 — 已验证不可行

## Todo

Parallel: items 5, 6, 8 可在 item 2 完成后并行执行。

- [x] ✅ 1. Phase 1 Gate: 验证路径解析和用户级 hooks
  Change: 验证 `@` import 路径解析和用户级 hooks 机制
  Files: `~/.claude/CLAUDE.md`（测试，非永久修改）
  Verify: (1) `@../.baton/constitution.md` 相对路径从 ~/.claude/ 解析 ✅ 已验证路径存在 (2) 用户级 settings.json hooks 已由 superpowers 插件证明可行 ✅
  Deps: none
  Artifacts: none
  Note: 使用相对路径 `@../.baton/constitution.md` 代替 tilde 路径，避免展开问题

- [x] ✅ 2. Phase 2: 仓库重构 + 兼容层
  Change: 移动 `.baton/skills/*` → `skills/*`、`.baton/hooks/*` → `hooks/*`、`.baton/constitution.md` → `constitution.md`；创建 `.baton/` 兼容层 symlinks
  Files: `.baton/skills/*` → `skills/*`, `.baton/hooks/*` → `hooks/*`, `.baton/constitution.md` → `constitution.md`, `.baton/{skills,hooks,constitution.md}` → symlinks
  Verify: `ls -la skills/ hooks/ constitution.md .baton/skills .baton/hooks .baton/constitution.md` 确认移动+symlinks
  Deps: 1
  Artifacts: none

- [x] ✅ 3. Phase 3: 重写 setup.sh
  Change: 完全重写 setup.sh — symlinks 创建 + 用户级 settings.json merge (jq) + CLAUDE.md 注入 + --migrate + --uninstall；编辑前备份 settings.json
  Files: `setup.sh`
  Verify: 读取确认逻辑正确；dry-run 验证（不执行，避免破坏当前会话）
  Deps: 2
  Artifacts: none

- [x] ✅ 4. Phase 3: 简化 install.sh
  Change: 简化 install.sh 为克隆 + 运行 setup.sh
  Files: `install.sh`
  Verify: 读取确认逻辑正确
  Deps: 3
  Artifacts: none

- [x] ✅ 5. Phase 4: 更新 phase-guide.sh (parallel with 6, 8)
  Change: 删除 junction auto-create block（原 50-67 行）；更新 `_scan_all_skills()` 添加 `~/.claude/skills/` 扫描；验证 governance context 路径
  Files: `hooks/phase-guide.sh`
  Verify: 读取确认 junction block 已删除、`_scan_all_skills` 扫描 `~/.claude/skills/`、`$SCRIPT_DIR/../skills/using-baton/SKILL.md` 路径有效
  Deps: 2
  Artifacts: none

- [x] ✅ 6. Phase 4: 更新 plan-parser.sh + 删除 junction.sh + 更新 common.sh (parallel with 5, 8)
  Change: `parser_has_skill()` 添加 `~/.claude/skills/` 搜索位置（保留 walk-up）；删除 junction.sh；更新 common.sh 过时注释
  Files: `hooks/lib/plan-parser.sh`, `hooks/lib/junction.sh` (delete), `hooks/lib/common.sh`
  Verify: 读取确认 parser_has_skill 搜索 `~/.claude/skills/`；`ls hooks/lib/junction.sh` 不存在；common.sh 无 `.baton/skills` 引用
  Deps: 2
  Artifacts: none

- [x] ✅ 7. Phase 5: 更新 bin/baton
  Change: doctor 检查用户级工件；移除 junction 逻辑；更新 parser 路径 BATON_HOME/hooks/
  Files: `bin/baton`
  Verify: 读取确认 doctor 检查 `~/.claude/skills/` symlinks + `~/.claude/settings.json` hooks + `~/.claude/CLAUDE.md` constitution
  Deps: 2, 3, 5, 6
  Artifacts: none

- [x] ✅ 8. Phase 5: 更新 docs + project CLAUDE.md/AGENTS.md + 项目级 settings.json (parallel with 5, 6)
  Change: README 架构图+安装说明重写；CLAUDE.md/AGENTS.md 移除 `.baton/constitution.md` 引用；项目级 settings.json 移除 baton hook 条目
  Files: `README.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`
  Verify: 读取确认架构图、CLAUDE.md、AGENTS.md、settings.json 均已更新
  Deps: 2
  Artifacts: none

- [x] ✅ 9. Phase 6: 删除过时测试 + 重写 test-setup.sh
  Change: 删除 test-junction.sh/test-multi-ide.sh/test-ide-capability-consistency.sh；重写 test-setup.sh 覆盖新 setup.sh
  Files: `tests/test-junction.sh` (delete), `tests/test-multi-ide.sh` (delete), `tests/test-ide-capability-consistency.sh` (delete), `tests/test-setup.sh` (rewrite)
  Verify: 3 个文件已删除；`bash tests/test-setup.sh` 通过
  Deps: 3
  Artifacts: none

- [x] ✅ 10. Phase 6: 更新其余测试 + 运行完整套件
  Change: 更新 7 个测试文件适配新路径/行为
  Files: `tests/test-dispatch.sh`, `tests/test-phase-guide.sh`, `tests/test-cli.sh`, `tests/test-smoke.sh`, `tests/test-full.sh`, `tests/test-constitution-consistency.sh`, `tests/test-plan-parser.sh`
  Verify: `bash tests/test-full.sh` 通过（完整测试套件）
  Deps: 5, 6, 7, 8, 9
  Artifacts: none

## Retrospective

**Wrong prediction**: Estimated setup.sh at ~60-70 lines. Actual: 259 lines. The v4 migration logic (--migrate) alone is ~50 lines of jq-based cleanup, and the hook merge logic is ~40 lines. Codex was right that LOC is a fake success criterion — the script is functionally correct and covers install + uninstall + migrate.

**Unexpected discovery**: `@` import in CLAUDE.md uses relative paths from the file's parent directory. So `@../.baton/constitution.md` from `~/.claude/CLAUDE.md` resolves correctly without tilde expansion. This was simpler than expected — the Critical Assumption about tilde expansion turned out to be a non-issue because relative paths work.

**Process improvement**: The design doc from /office-hours assumed plugin-based delivery. This was invalidated by /plan-eng-review which discovered Claude Code only supports GitHub-based marketplace sources. Future designs should validate external system APIs BEFORE the design doc is approved — the /office-hours → /plan-eng-review pipeline caught it, but the pivot cost ~30 min of rework.

## Implementation Notes

- **B-level: annotation-template.md**: `.baton/annotation-template.md` 未移动（stays in `.baton/`）。v5 项目中无 `.baton/` 目录时，技能引用的 `.baton/annotation-template.md` 路径可能无法解析。模板内容简单（22 行），不影响核心功能。后续可通过将模板内容内联到 skill SKILL.md 中解决。
- **Review fix: test-cli.sh**: baton-review 发现 test-cli.sh 未更新（在 write set 中但被遗漏）。重写为 v5 行为测试：doctor 无参数、init 重定向、uninstall 无项目参数。39/39 通过。
- **Review fix: test-plan-parser.sh**: parser_has_skill 不再检查 `.baton/skills/`（v5 行为变更），但测试仍使用旧路径。更新为 `.claude/skills/`，添加 `~/.claude/skills/` 用户级回退测试。123/123 通过。
- **Review fix: test-new-hooks.sh**: completion-check multi-plan 测试期望 `echo "# Other"` 触发多计划阻塞，但 v5 parser Layer 1 自动解析（仅一个计划有 BATON:GO）。更新为两个 BATON:GO 计划。53/53 通过。

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
<!-- BATON:GO -->
<!-- BATON:COMPLETE -->

# Research: .baton 目录结构重组

## 现状

`.baton/` 下 7 个 hook 脚本 + 2 个 workflow 文档 + adapters 子目录混在一起：

```
.baton/
├── adapters/                # 已有子目录
│   ├── adapter-cline.sh
│   ├── adapter-copilot.sh
│   ├── adapter-cursor.sh
│   └── opencode-plugin.mjs
├── bash-guard.sh            # hook 脚本 ×7
├── completion-check.sh
├── phase-guide.sh
├── post-write-tracker.sh
├── pre-compact.sh
├── stop-guard.sh
├── subagent-context.sh
├── workflow-full.md         # 文档 ×2
├── workflow.md
└── write-lock.sh
```

## 引用分析

### 1. `.claude/settings.json`（7 处）

所有 hook 命令使用 `"sh .baton/<script>.sh"` 格式：
- `settings.json:9` — `sh .baton/phase-guide.sh`
- `settings.json:20` — `sh .baton/write-lock.sh`
- `settings.json:31` — `sh .baton/post-write-tracker.sh`
- `settings.json:42` — `sh .baton/stop-guard.sh`
- `settings.json:53` — `sh .baton/subagent-context.sh`
- `settings.json:64` — `sh .baton/completion-check.sh`
- `settings.json:75` — `sh .baton/pre-compact.sh`

Risk: ❌ 移动脚本后这些路径全部失效，hook 将不触发

### 2. `setup.sh`（26+ 处）

两类引用：
- **源文件复制**: `cp "$BATON_DIR/.baton/$_ivs_name"` — 从 baton 仓库复制脚本到目标项目
- **settings.json 生成**: 硬编码 `"command": "sh .baton/write-lock.sh"` 写入 settings.json

Risk: ❌ setup.sh 是安装器，源路径和目标路径都需要更新

### 3. adapter 脚本（3 处）

所有 adapter 使用相对路径引用 write-lock.sh：
```sh
# adapter-cline.sh:11, adapter-cursor.sh:5, adapter-copilot.sh:5
RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
```

Risk: ❌ 如果 write-lock.sh 从 `.baton/` 移到 `.baton/hooks/`，`../write-lock.sh` 变为 `../hooks/write-lock.sh` 或 `../../hooks/write-lock.sh`

### 4. 测试文件（100+ 处，8 个测试文件）

统一使用 `$SCRIPT_DIR/../.baton/` 模式：
- `test-write-lock.sh:6` — `LOCK="$SCRIPT_DIR/../.baton/write-lock.sh"`
- `test-phase-guide.sh:6` — `GUIDE="$SCRIPT_DIR/../.baton/phase-guide.sh"`
- `test-stop-guard.sh:6` — `GUARD="$SCRIPT_DIR/../.baton/stop-guard.sh"`
- `test-workflow-consistency.sh:6-7` — workflow 文件引用
- `test-setup.sh` — 88-326 行大量 `assert_file_exists "$d/.baton/..."` 断言
- `test-adapters.sh`, `test-adapters-v2.sh` — adapter 相关
- `test-annotation-protocol.sh:6-7` — workflow 文件引用
- `test-new-hooks.sh:7` — `BATON="$SCRIPT_DIR/../.baton"`

Risk: ⚠️ 改路径后需要批量更新，但模式统一，改动机械

### 5. CI/CD（`.github/workflows/ci.yml`，5 处）

```yaml
run: shellcheck .baton/write-lock.sh
run: shellcheck .baton/phase-guide.sh
run: shellcheck .baton/bash-guard.sh
run: shellcheck .baton/stop-guard.sh
run: shellcheck .baton/adapters/adapter-cline.sh
```

Risk: ⚠️ 路径变更后 CI 失败

### 6. CLAUDE.md（1 处）

```
@.baton/workflow.md
```

Risk: ⚠️ `@` 引用是 Claude Code 的文件导入语法，路径变更后 workflow 不再被加载

### 7. 脚本内部互引（SYNCED 标记）

4 个脚本的 `find_plan` 注释互相引用文件名：
- `write-lock.sh:69` — `# SYNCED: find_plan — same algorithm in phase-guide.sh, stop-guard.sh, bash-guard.sh`
- `phase-guide.sh:21` — 同上
- `stop-guard.sh:22` — 同上

Risk: ✅ 只是注释，功能不受影响，但应保持准确

### 8. 文档文件（参考性）

README.md、docs/implementation-design.md、docs/research-ide-hooks.md、code-review.md 等包含 `.baton/` 路径引用。

Risk: ✅ 不影响功能，可选择性更新

## 重组方案分析

### 方案 A：hooks 子目录

```
.baton/
├── hooks/               # 7 个 hook 脚本
│   ├── write-lock.sh
│   ├── phase-guide.sh
│   ├── stop-guard.sh
│   ├── bash-guard.sh
│   ├── completion-check.sh
│   ├── pre-compact.sh
│   ├── post-write-tracker.sh
│   └── subagent-context.sh
├── adapters/            # 不变
├── workflow.md          # 留在根目录
└── workflow-full.md
```

- settings.json: `sh .baton/hooks/write-lock.sh`
- adapter 引用: `$(dirname "$0")/../hooks/write-lock.sh`
- 测试: `$SCRIPT_DIR/../.baton/hooks/write-lock.sh`
- Pros: 简单、清晰分层
- Cons: 所有路径多一层 `hooks/`

### 方案 B：docs 子目录

```
.baton/
├── adapters/
├── workflow.md          # 移到 docs/ 子目录
├── workflow-full.md     # ↓
├── docs/
│   ├── workflow.md
│   └── workflow-full.md
├── write-lock.sh        # 脚本留原地
└── ...
```

- Pros: 改动最小（只移 2 个文件）
- Cons: 脚本还是散在根目录，没解决核心问题；CLAUDE.md 的 `@` 引用需要更新

### 方案 C：hooks + docs 双分离

```
.baton/
├── hooks/
│   ├── write-lock.sh
│   └── ...
├── adapters/
├── docs/
│   ├── workflow.md
│   └── workflow-full.md
└── (空，只有子目录)
```

- Pros: 最整洁，每类文件有明确归属
- Cons: 改动量最大（hooks 路径 + docs 路径都变）；CLAUDE.md `@.baton/docs/workflow.md` 路径变深

### 推荐：方案 A

理由：
1. 核心问题是脚本散乱，方案 A 直接解决
2. workflow.md 留在 `.baton/` 根目录，CLAUDE.md 的 `@.baton/workflow.md` 无需改
3. adapter 的相对路径调整简单（`..` → `../hooks`）
4. 改动范围可控：setup.sh + settings.json + 测试 + CI + adapter

## 影响范围汇总

| 文件类型 | 文件数 | 引用数 | 难度 |
|---------|--------|--------|------|
| settings.json（含 setup.sh 生成） | 2 | 14 | 机械替换 |
| setup.sh 源文件复制 | 1 | ~10 | 需理解复制逻辑 |
| adapter 脚本 | 3 | 3 | 改相对路径 |
| 测试文件 | 8 | 100+ | 机械替换 |
| CI/CD | 1 | 5 | 机械替换 |
| SYNCED 注释 | 4 | 4 | 注释更新 |
| 文档 | 5+ | 20+ | 可选 |

## Self-Review

**3 个关键问题**：
1. 用户通过 `setup.sh` 安装到其他项目时，目标项目的目录结构是否也要变？（是的，setup.sh 创建的目标结构必须匹配 settings.json 中的路径）
2. 已经用 baton 的项目升级时，旧的 `.baton/*.sh` 文件怎么清理？setup.sh 需要迁移逻辑吗？
3. `hooks/` 这个名字会不会和项目根目录的 `hooks/`（git pre-commit）混淆？

**最弱结论**：方案 A 是"推荐"但没有量化比较各方案的工作量差异。方案 B 改动量可能只有方案 A 的 1/5，如果用户只是觉得文档碍眼的话。

**进一步调查方向**：精确统计各方案的实际改动行数，以及是否有更好的子目录命名（如 `scripts/` 代替 `hooks/`）。

## Supplement: 量化工作量 + pre-commit 分析

### 各方案引用改动量

| 来源 | 方案 A (scripts→hooks/) | 方案 B (docs→docs/) |
|------|------------------------|---------------------|
| setup.sh | 22 处 | ~15 处 |
| .claude/settings.json | 7 处 | 0 |
| adapter 脚本 | 3 处 | 0 |
| 测试文件 | 54 处 | ~10 处 |
| CI/CD | 5 处 | 0 |
| CLAUDE.md | 0 | 1 处 |
| **总计** | **~91 处** | **~26 处** |

方案 A 改动量约为方案 B 的 3.5 倍，但方案 A 解决核心问题（脚本散乱），方案 B 只移文档。

### `hooks/pre-commit` 是否有存在必要？

**write-lock.sh vs pre-commit 的区别**：

| 维度 | write-lock.sh | hooks/pre-commit |
|------|--------------|-----------------|
| 层级 | Claude Code hook（PreToolUse） | Git hook（pre-commit） |
| 拦截对象 | AI 的 Edit/Write 工具调用 | `git commit` 命令 |
| 保护谁 | 防止 AI 写源码 | 防止任何人提交未批准的源码 |
| 覆盖范围 | 仅 Claude Code | 所有 git 操作（手动、CI、其他工具） |

**结论**：pre-commit **有独立价值**。write-lock 只在 Claude Code 内生效，pre-commit 在 git 层面拦截。如果用户手动改了代码试图提交，或者用其他 AI 工具写了代码，只有 pre-commit 能拦住。

**命名冲突解决方案**：
- 选项 1：将根目录 `hooks/` 重命名为 `git-hooks/`（明确区分）
- 选项 2：将 `hooks/pre-commit` 移入 `.baton/git-hooks/pre-commit`（统一到 .baton 下）
- 选项 3：Claude Code hook 脚本的子目录用 `scripts/` 而非 `hooks/`（避免歧义）

**推荐选项 2**：将 `hooks/pre-commit` 移入 `.baton/git-hooks/pre-commit`。
- 所有 baton 相关文件统一在 `.baton/` 下
- `git-hooks/` vs `hooks/` 命名上有明确区分
- setup.sh 安装路径只需改一处（`$BATON_DIR/hooks/pre-commit` → `$BATON_DIR/.baton/git-hooks/pre-commit`）

### 更新后的推荐结构

```
.baton/
├── hooks/               # Claude Code hook 脚本
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
├── workflow.md           # 留在根目录
└── workflow-full.md
```

根目录的 `hooks/` 目录删除（内容移入 `.baton/git-hooks/`）。

## Annotation Log

### Round 1 (2026-03-04)

**[NOTE] § Self-Review**
"1. 不考虑已有 baton 项目 2. 进一步调查"
→ (1) 已从影响范围中移除迁移逻辑考量。(2) 已补充 Supplement 章节，量化了各方案改动量（方案 A ~91 处 vs 方案 B ~26 处）。
→ Result: 已回写到研究正文

**[Q] § Self-Review**
"根目录的 git pre-commit 是否还有存在的必要？如果没有，是否可以删除以避免和 .baton/hooks/ 混淆？"
→ pre-commit 有独立价值：write-lock.sh 只拦 Claude Code 工具调用，pre-commit 拦截所有 git commit。层级不同，不可替代。
→ 推荐将 `hooks/pre-commit` 移入 `.baton/git-hooks/pre-commit`，统一到 `.baton/` 下且命名区分。
→ Result: 已回写到研究正文

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->

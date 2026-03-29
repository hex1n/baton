# Scoped Map: runtime-thickness-improvements

**需求**: 实现 `docs/harness-improvement-plan.md` 中尚未落地的改进项（基于 `docs/runtime-thickness-analysis.md` gap 分析）
**领域**: harness protocol / skills 层
**Owner**: `scoped-explorer`
**状态**: `complete`

## 1. 范围

- **范围内**：改进计划 P0–P2 的全部 10 项；`check-consistency.sh` / `link-skills.sh` 的未提交修改
- **范围外**：validate-artifact.sh、validate-transition.sh、git-hooks 填充（设计上已排除）；java-backend-strict 脚本实现（优先级未到）
- **预期写入边界**：`skills/baton-explorer.md`（主要）；可选：`spec/templates/module-status.template.md`、`spec/bootstrap/start-task.sh`

## 2. 入口点

| 文件 | 行号 | 说明 |
|------|------|------|
| `skills/baton-explorer.md` | 1-11 | P0-3：frontmatter 缺 `context: fork` |
| `spec/templates/module-status.template.md` | 全文 | P1-2：无 `eval_round` 列（State Notes 方案已实现持久化） |
| `spec/bootstrap/check-consistency.sh` | 32, 104 | 已修改（harness-*.md → baton-*.md 模式），未提交 |
| `spec/bootstrap/link-skills.sh` | 50-107 | 已修改（新增 SKILL.md 子目录支持），未提交 |

## 3. 调用链

```text
用户调用 /baton-explorer
  → Claude Code 读取 frontmatter
  → 如存在 context: fork → 启动新上下文
  → skill 执行探索步骤
  → 写 .harness/scoped-map.md
  → 更新 module-status.md → specifying
```

check-consistency.sh 调用链（check-harness 时触发）：
```text
check-consistency.sh
  → 不变式 1：grep baton-*.md owner tokens → owners.txt
  → 不变式 4：skills/baton-*.md 与 .claude/skills/ .agents/ 一致
```

## 4. 现有行为

**P0-3 缺口（唯一未实现的 P0 项）**：
- `skills/baton-evaluator.md:3`：有 `context: fork` ✅
- `skills/baton-verifier.md:3`：有 `context: fork` ✅
- `skills/baton-explorer.md`：frontmatter **无** `context: fork` ❌
- Execution Guide 已有说明："Same-session execution is acceptable by default"，与加 `context: fork` 存在语义张力

**P1-2 现状**：
- `skills/baton-evaluator.md:156-157`：State Notes `Current eval round: N` + 3 轮后强制升级
- `spec/templates/module-status.template.md`：无 `eval_round` 列
- 核心行为（持久化 + 升级逻辑）已实现，仅模板列缺失

**check-consistency.sh / link-skills.sh**：
- 两文件已有本地修改，尚未 `git add`；改动正确（harness-*.md → baton-*.md，SKILL.md 子目录支持）

## 5. 现有测试

- `spec/bootstrap/check-consistency.sh`：校验 skill 文件一致性，但不校验 frontmatter 内容
- 无自动化测试覆盖 skill frontmatter 字段

## 6. 依赖 / 风险扫描

| 风险 | 说明 |
|------|------|
| `context: fork` 语义未验证 | 分析文档指出无法确认此 frontmatter 在当前 Claude Code 版本是否触发新上下文（`docs/runtime-thickness-analysis.md:166`）。改动后语义保证仍是协议层而非运行时层 |
| Scoped 模式过度隔离 | Explorer 的 `context: fork` 若全局生效，Scoped 模式对小任务可能不必要；需在 skill 内限定适用场景 |
| 模板列改动影响 start-task.sh | 若在 template 中加 `eval_round` 列，`start-task.sh` 的表头检查（不变式 3）可能需同步更新 |

## 7. 变更形态

- **这看起来像**：protocol/skill 文档补丁（无代码逻辑）
- **预计文件数**：1-3 个（`baton-explorer.md` 必改；template 和 start-task.sh 可选）
- **推荐实现深度**：浅——精准修改 frontmatter 和说明段落，不重写 skill 结构

## 8. 未决问题

- P1-2 是否需要在模板中正式加 `eval_round` 列，还是接受当前 State Notes 实现？（推荐：接受 State Notes 方案，保持向后兼容）
- Explorer 的 `context: fork` 是否应改为仅 Repo-wide 模式的推荐而非强制？

## 9. 建议

- **继续**：是
- **建议下一步（Specifier）**：
  1. 主要 AC：`skills/baton-explorer.md` frontmatter 加 `context: fork`，Execution Guide 修订说明"Repo-wide 模式强烈建议隔离；Scoped 模式可酌情省略"
  2. 次要 AC：决定 P1-2 方向（推荐接受 State Notes，标注改进计划 P1-2 已以不同机制实现）
  3. `check-consistency.sh` 和 `link-skills.sh` 的未提交修改已正确，可一并包含在本任务提交中

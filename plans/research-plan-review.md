# 对 `plan.md` 的评判

## 结论

**当前 `plan.md` 的方向基本正确，但还不能作为稳定的实施合同。**

我同意它延续了 research 里最重要的三条主线：优先清理 SYNCED 技术债、修复 OpenCode 行为不一致、补齐 CI 缺口（research.md:334-336；plan.md:121-124,147-171）。但它在“推荐方案”“变更清单”“Todo”三层之间没有收敛成一个单一方案，已经违反 Baton 对 plan 作为 contract 的要求（.agents/skills/baton-plan/SKILL.md:167-168）。

## 主要问题

### 1. ❌ 已接受“方案 D”，但正文仍保留“方案 B”的变更 4

`plan.md` 在方案分析里明确把推荐切换到“技术债清理 + Skills 强化”，并且把 `doc-quality.sh` 定义为应当被替换掉的旧思路（plan.md:90-124）。但真正进入“变更清单”后，`变更 4` 仍然是“新增文档质量检查 hook”，包含 `.baton/hooks/doc-quality.sh`、`.claude/settings.json`、`setup.sh` 的改动（plan.md:173-197）。

同一个文档里，`Self-Review` 又说“变更 4 已替换为 skills 强化”（plan.md:201-203），`Todo` 也转而安排了 3 个 skill 的强化和 `.agents/skills/` 同步（plan.md:214-217），`Annotation Log` 还明确记录“推荐修正为方案 D”（plan.md:233-244）。

这意味着实现者无法确定到底应该：
- 做 `doc-quality.sh` hook；
- 还是只做 skills 强化；
- 还是两者都做。

按照 Baton 规范，接受批注后必须“更新正文 + 记录 Annotation Log”，且正文才是 source of truth（.agents/skills/baton-plan/SKILL.md:167-168）。这一条当前没有做到。

### 2. ❌ 计划声称“从 research 推导”，但实际删掉了 research 里的“质量评估 harness”

research 对方向 D 的定义并不是“只强化 skills”。它明确把 harness 分成三类，其中第二类就是**质量评估**，包括“自动检查 research.md 是否有 file:line 证据、是否有 Self-Review”（research.md:456-459）。后面的“修正后的方向推荐”也再次把“质量评估自动检查”列为方向 D 的组成部分（research.md:517-520），Round 2 的批注回复同样写明“新增质量评估 harness”（research.md:576-579）。

但 `plan.md` 在方案 D 中直接把 `doc-quality.sh` 定性为“gate 思维，不是 harness 思维”，并将其整体替换为 skills 自检（plan.md:92-107,121-124）。这一步不是不可以做，但它**没有新的 research 证据**来解释为什么要从“skills + 质量评估”收缩成“skills only”。

所以这里的问题不是“方案 D 一定错”，而是：**plan 对 research 的追溯链断了。** 如果要保留 skills-only 版本，应该先在研究里补出新的反证；如果要忠于现有 research，变更清单就不该把质量评估完全删掉。

### 3. ⚠️ 文档结构本身仍未收敛，说明批注闭环没有真正完成

Baton workflow 要求文档必须以 `## 批注区` 结尾（.baton/workflow.md:53-56），`baton-plan` skill 的输出模板也要求 `plan.md` 以 `## 批注区` 收尾（.agents/skills/baton-plan/SKILL.md:189-202）。但当前 `plan.md` 在 `## 批注区` 之后继续追加了 `## Annotation Log` 和 `<!-- BATON:GO -->`（plan.md:220-246），已经不符合规范。

另外，workflow 规定 `## Todo` 应当在 plan 经人类批准后、并在文档收敛后再追加（.baton/workflow.md:17-18,29-33）。当前文档虽然已经有 `## Todo`（plan.md:205-218），但正文里仍然同时存在互相冲突的 B/D 混合版本（plan.md:173-197,201-217,233-244）。这说明 Todo 建立在一个尚未统一的 plan 上，合同边界仍然模糊。

## 可保留的部分

### 1. ✅ 技术债优先级基本对

research 把最值得关注的三个问题定为：SYNCED 复制、OpenCode glob 缺失、CI 覆盖缺口（research.md:332-336）。`plan.md` 也把这三项放在最前面，并给出了具体落点（plan.md:121-124,147-171）。这个排序是对的。

### 2. ✅ 约束提取大体合理

`plan.md` 提取了 POSIX sh、零外部依赖、fail-open、向后兼容、独立脚本可调试等约束（plan.md:33-42）。这些约束与 research 对 hook 设计、fail-open、jq/awk 回退、多 IDE 安装现状的分析是相容的（research.md:195-201,223-235,315-330）。

## 我的判断

**如果目标是“现在就进入实现”，我会判定这个 plan 还不合格。**

不是因为方向错，而是因为它还没有把“研究结论”收束成“唯一可执行方案”。当前版本更像一份正在收敛中的讨论稿，而不是 Baton 所要求的 contract。

更准确地说：
- `A/B` 中的技术债修复部分可信。
- `D` 的战略方向也可信。
- 但 `D` 到底是“skills-only”还是“skills + quality evaluation”，文档没有定稿。

## 建议修订方式

1. 先在正文里只保留一个版本的“变更 4”。
2. 如果选择 skills-only，就补一段新的研究证据，解释为什么 research 里的“质量评估自动检查”被推翻。
3. 如果选择 “skills + quality evaluation”，就把方案 D 改写成与 research.md:456-459,517-520 一致。
4. 让 `变更清单`、`Self-Review`、`Todo`、`Annotation Log` 四处完全一致，再谈实现。
5. 把 `## Annotation Log` 挪到 `## 批注区` 之前，确保文档最终以 `## 批注区` 结束。

## Self-Review

- **最强结论**：`plan.md` 当前存在可证实的内部冲突，这不是偏好问题，而是 contract 是否单一的问题（plan.md:90-124,173-217,233-244）。
- **最弱结论**：我不能仅凭现有 research 断言“skills-only”一定比“skills + quality evaluation”差；我只能确认当前 plan 没有把这个转向论证完整。
- **若要改变我的判断**：需要看到一版正文完全统一、并明确解释质量评估是否保留的新 plan。

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 如需我继续，可基于这份评判再出一版修订建议

<!-- 在下方添加标注 -->
